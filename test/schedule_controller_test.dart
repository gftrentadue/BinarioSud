import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:binario_sud/data/feed_refresh_service.dart';
import 'package:binario_sud/data/gtfs_models.dart';
import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:binario_sud/data/settings_store.dart';
import 'package:binario_sud/state/schedule_controller.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'helpers.dart';

/// Store in-memory per testare la persistenza senza `shared_preferences`.
class _FakeSettingsStore implements SettingsStore {
  bool stored;
  String? cachedFeedVersion;
  DateTime? lastCheckDate;
  _FakeSettingsStore({this.stored = false});

  @override
  Future<bool> loadOnlyAccessible() async => stored;

  @override
  Future<void> saveOnlyAccessible(bool value) async => stored = value;

  @override
  Future<String?> loadCachedFeedVersion() async => cachedFeedVersion;

  @override
  Future<void> saveCachedFeedVersion(String version) async =>
      cachedFeedVersion = version;

  @override
  Future<DateTime?> loadLastCheckDate() async => lastCheckDate;

  @override
  Future<void> saveLastCheckDate(DateTime date) async => lastCheckDate = date;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Mercoledì 17/06/2026, ore 12:00 — giorno feriale, mezzogiorno.
  ScheduleController makeController({SettingsStore? settingsStore}) =>
      ScheduleController(
        repository: GtfsRepository(bundle: FileAssetBundle()),
        now: () => DateTime(2026, 6, 17, 12, 0),
        settingsStore: settingsStore,
      );

  test('init carica il feed e va in ready', () async {
    final c = makeController();
    await c.init();
    expect(c.status, FeedStatus.ready);
    expect(c.feedVersion, '20260618-7');
  });

  test('default oggi+verso Modugno: solo dir 1 e dalle 12:00 in poi (RF-04)', () async {
    final c = makeController();
    await c.init();
    final v = c.visibleJourneys;
    expect(v, isNotEmpty);
    expect(v.every((j) => j.direction == Direction.versoModugno), isTrue);
    // soglia "da adesso" = 12:00 → niente corse mattutine.
    expect(v.every((j) => j.departure >= 12 * 3600), isTrue);
  });

  test('prossima corsa = prima visibile quando il giorno è oggi (RF-11)', () async {
    final c = makeController();
    await c.init();
    expect(c.nextJourneyTripId, c.visibleJourneys.first.tripId);
  });

  test('filtro operatore FAL esclude TI (RF-12)', () async {
    final c = makeController();
    await c.init();
    c.setOperatorFilter(OperatorFilter.fal);
    expect(c.visibleJourneys.every((j) => j.agencyId == 'FAL'), isTrue);
  });

  test('verso Modugno: presenti sia FAL che TI (TI dir 1 ora nel feed v2)',
      () async {
    final c = makeController();
    await c.init();
    c.setDirection(Direction.versoModugno);
    final ops = c.visibleJourneys.map((j) => j.agencyId).toSet();
    expect(ops, containsAll({'FAL', 'TI'}));
  });

  test('cambiando giorno la soglia "da adesso" si azzera', () async {
    final c = makeController();
    await c.init();
    c.setSelectedDay(DateTime(2026, 6, 18)); // domani
    expect(c.isToday, isFalse);
    expect(c.effectiveFromTime, 0);
    // prossima corsa non evidenziata se il giorno non è oggi.
    expect(c.nextJourneyTripId, isNull);
  });

  test('hasJourneysIgnoringTime distingue stato vuoto (UC-06)', () async {
    final c = makeController();
    await c.init();
    // verso Bari di sera tardi: imposto soglia 23:30 → nessuna corsa dopo,
    // ma il giorno ne ha (quindi offribile "prima del giorno").
    c.setFromTime(23 * 3600 + 30 * 60);
    expect(c.visibleJourneys, isEmpty);
    expect(c.hasJourneysIgnoringTime, isTrue);
  });

  test('filtro accessibilità: solo corse con wheelchair=yes (RF-21)', () async {
    final c = makeController();
    await c.init();
    c.setFromTime(0); // tutta la giornata, per un confronto significativo
    final tutte = c.visibleJourneys.length;
    c.setOnlyAccessible(true);
    final accessibili = c.visibleJourneys;
    expect(accessibili, isNotEmpty);
    expect(accessibili.every((j) => j.wheelchair == Availability.yes), isTrue);
    // il feed ha corse non accessibili in questa direzione → il filtro riduce.
    expect(accessibili.length, lessThan(tutte));
  });

  test('falExcludedByAccessibilityCount segnala le FAL nascoste dal filtro (RF-21/R-10)',
      () async {
    final c = makeController();
    await c.init();
    c.setFromTime(0); // tutta la giornata
    // Senza filtro accessibilità non c'è nulla da segnalare.
    expect(c.falExcludedByAccessibilityCount, 0);
    // Le FAL hanno wheelchair=2 (assunto): col filtro attivo sono tutte escluse.
    final falVisibili =
        c.visibleJourneys.where((j) => j.agencyId == 'FAL').length;
    expect(falVisibili, greaterThan(0));
    c.setOnlyAccessible(true);
    expect(c.falExcludedByAccessibilityCount, falVisibili);
    // Nessuna FAL resta visibile (sono tutte wheelchair != yes).
    expect(c.visibleJourneys.any((j) => j.agencyId == 'FAL'), isFalse);
  });

  test('falExcludedByAccessibilityCount è 0 se il filtro operatore è solo TI',
      () async {
    final c = makeController();
    await c.init();
    c.setFromTime(0);
    c.setOnlyAccessible(true);
    c.setOperatorFilter(OperatorFilter.trenitalia);
    // Le FAL sono già escluse dall'operatore, non dall'accessibilità.
    expect(c.falExcludedByAccessibilityCount, 0);
  });

  test('filtro bici: solo corse con bikes=yes (RF-20)', () async {
    final c = makeController();
    await c.init();
    c.setFromTime(0);
    c.setOnlyBikes(true);
    final v = c.visibleJourneys;
    expect(v, isNotEmpty);
    expect(v.every((j) => j.bikes == Availability.yes), isTrue);
  });

  test('filtri combinati e reset tornano alla lista piena', () async {
    final c = makeController();
    await c.init();
    c.setFromTime(0);
    final piena = c.visibleJourneys.length;
    c.setOnlyAccessible(true);
    c.setOnlyBikes(true);
    expect(c.visibleJourneys.length, lessThanOrEqualTo(piena));
    // reset
    c.setOnlyAccessible(false);
    c.setOnlyBikes(false);
    expect(c.visibleJourneys.length, piena);
  });

  test('accessibilità persistita: init la ripristina (RF-21)', () async {
    final c = makeController(settingsStore: _FakeSettingsStore(stored: true));
    await c.init();
    expect(c.onlyAccessible, isTrue);
  });

  test('setOnlyAccessible salva la preferenza nello store', () async {
    final store = _FakeSettingsStore();
    final c = makeController(settingsStore: store);
    await c.init();
    c.setOnlyAccessible(true);
    expect(store.stored, isTrue);
    c.setOnlyAccessible(false);
    expect(store.stored, isFalse);
  });

  test('activeFilterCount conta i filtri del pannello', () async {
    final c = makeController();
    await c.init();
    expect(c.activeFilterCount, 0);
    c.setOperatorFilter(OperatorFilter.fal);
    c.setOnlyBikes(true);
    c.setOnlyAccessible(true);
    c.setFromTime(13 * 3600);
    expect(c.activeFilterCount, 4);
  });

  test('resetFilters azzera filtri e persistenza, non direzione/giorno',
      () async {
    final store = _FakeSettingsStore(stored: true);
    final c = makeController(settingsStore: store);
    await c.init(); // accessibilità ripristinata = 1 filtro attivo
    c.setDirection(Direction.versoBari);
    c.setOperatorFilter(OperatorFilter.fal);
    c.setOnlyBikes(true);
    c.setFromTime(13 * 3600);
    c.resetFilters();
    expect(c.activeFilterCount, 0);
    expect(store.stored, isFalse);
    // direzione (fuori dal pannello) resta invariata.
    expect(c.direction, Direction.versoBari);
  });

  group('RF-07 refresh da rete', () {
    // Zip "reale": stessi 8 file GTFS del bundle di test, con feed_version
    // sostituita in feed_info.txt. Servono tutti (non solo feed_info.txt)
    // perché il hot-swap ricarica l'intero feed con GtfsRepository.load().
    List<int> buildZip(String feedVersion) {
      const files = [
        'agency.txt',
        'calendar.txt',
        'calendar_dates.txt',
        'feed_info.txt',
        'routes.txt',
        'stop_times.txt',
        'stops.txt',
        'trips.txt',
      ];
      final archive = Archive();
      for (final name in files) {
        var content = File('assets/gtfs/$name').readAsStringSync();
        if (name == 'feed_info.txt') {
          content = content.replaceFirst('20260618-7', feedVersion);
        }
        final bytes = utf8.encode(content);
        archive.addFile(ArchiveFile(name, bytes.length, bytes));
      }
      return ZipEncoder().encode(archive);
    }

    test('forceRefreshCheck ricarica il feed a caldo quando trova una nuova versione',
        () async {
      final tmp =
          await Directory.systemTemp.createTemp('binariosud_hotswap_test');
      addTearDown(() async {
        if (tmp.existsSync()) await tmp.delete(recursive: true);
      });

      final manifestUrl = Uri.parse('https://example.test/manifest.json');
      final zipUrl = Uri.parse('https://example.test/gtfs.zip');
      final zipBytes = buildZip('20260701-1');
      final sha = sha256.convert(zipBytes).toString();

      // Segna "già controllato oggi" così il refresh automatico e silenzioso
      // lanciato da init() fa skip (senza rete): il test guida un solo
      // controllo, deterministico, tramite forceRefreshCheck (force=true).
      final settingsStore = _FakeSettingsStore()
        ..lastCheckDate = DateTime(2026, 6, 17);
      final refreshService = FeedRefreshService(
        settingsStore: settingsStore,
        client: MockClient((req) async {
          if (req.url == zipUrl) return http.Response.bytes(zipBytes, 200);
          return http.Response(
            jsonEncode({
              'schema_version': 2,
              'feed_version': '20260701-1',
              'feed_url': zipUrl.toString(),
              'feed_published_at': '2026-07-01T00:00:00+02:00',
              'feed_sha256': sha,
            }),
            200,
          );
        }),
        now: () => DateTime(2026, 6, 17, 12, 0),
        cacheRootProvider: () async => tmp,
        manifestUrl: manifestUrl,
      );

      final c = ScheduleController(
        repository: GtfsRepository(bundle: FileAssetBundle()),
        now: () => DateTime(2026, 6, 17, 12, 0),
        settingsStore: settingsStore,
        refreshService: refreshService,
      );

      await c.init();
      expect(c.feedVersion, '20260618-7'); // feed iniziale dal bundle

      final result = await c.forceRefreshCheck();

      expect(result?.outcome, RefreshOutcome.updated);
      expect(c.feedVersion, '20260701-1'); // hot-swap avvenuto
    });
  });
}
