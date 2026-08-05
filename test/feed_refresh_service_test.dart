import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:binario_sud/data/feed_refresh_service.dart';
import 'package:binario_sud/data/settings_store.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Store in-memory (stesso pattern di schedule_controller_test.dart).
class _FakeSettingsStore implements SettingsStore {
  String? cachedFeedVersion;
  DateTime? lastCheckDate;

  @override
  Future<bool> loadOnlyAccessible() async => false;

  @override
  Future<void> saveOnlyAccessible(bool value) async {}

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

final _manifestUrl = Uri.parse('https://example.test/manifest.json');
final _zipUrl = Uri.parse('https://example.test/gtfs.zip');

List<int> _buildZip(String feedVersion) {
  final content =
      'feed_publisher_name,feed_publisher_url,feed_lang,feed_version,feed_start_date,feed_end_date\n'
      'Test,https://example.com,it,$feedVersion,20260701,20261231\n';
  final bytes = utf8.encode(content);
  final archive = Archive()
    ..addFile(ArchiveFile('feed_info.txt', bytes.length, bytes));
  return ZipEncoder().encode(archive);
}

String _manifestJson({
  required String feedVersion,
  int schemaVersion = 1,
  String? feedUrl,
  String? sha256Hex,
}) =>
    jsonEncode({
      'schema_version': schemaVersion,
      'feed_version': feedVersion,
      'feed_url': feedUrl ?? _zipUrl.toString(),
      'feed_published_at': '2026-07-01T00:00:00+02:00',
      'feed_sha256': ?sha256Hex,
    });

void main() {
  late Directory tmpRoot;
  late _FakeSettingsStore settingsStore;
  final clock = DateTime(2026, 7, 1, 10, 0);

  setUp(() async {
    tmpRoot = await Directory.systemTemp.createTemp('binariosud_refresh_test');
    settingsStore = _FakeSettingsStore();
  });

  tearDown(() async {
    if (tmpRoot.existsSync()) await tmpRoot.delete(recursive: true);
  });

  FeedRefreshService makeService(
    Future<http.Response> Function(http.Request) handler,
  ) =>
      FeedRefreshService(
        settingsStore: settingsStore,
        client: MockClient((req) => handler(req)),
        now: () => clock,
        cacheRootProvider: () async => tmpRoot,
        manifestUrl: _manifestUrl,
      );

  test('già controllato oggi: skip senza contattare la rete (CA-3.3)', () async {
    settingsStore.lastCheckDate = clock;
    final service = makeService((req) => throw StateError('no network expected'));
    final result = await service.checkForUpdate();
    expect(result.outcome, RefreshOutcome.skippedAlreadyCheckedToday);
  });

  test('manifest irraggiungibile: networkError, last_check_date invariato (CA-4.2)',
      () async {
    final service = makeService((req) => throw const SocketException('down'));
    final result = await service.checkForUpdate();
    expect(result.outcome, RefreshOutcome.networkError);
    expect(settingsStore.lastCheckDate, isNull);
  });

  test('schema_version non supportata: unsupportedSchema, aggiorna check (CA-3.4)',
      () async {
    final service = makeService((req) async {
      return http.Response(
        _manifestJson(feedVersion: '20260701-1', schemaVersion: 99),
        200,
      );
    });
    final result = await service.checkForUpdate();
    expect(result.outcome, RefreshOutcome.unsupportedSchema);
    expect(settingsStore.lastCheckDate, clock);
  });

  test('stessa feed_version: upToDate, nessun download (CA-3.2)', () async {
    settingsStore.cachedFeedVersion = '20260618-7';
    final service = makeService((req) async {
      if (req.url == _zipUrl) {
        throw StateError('non deve scaricare lo zip se già aggiornato');
      }
      return http.Response(_manifestJson(feedVersion: '20260618-7'), 200);
    });
    final result = await service.checkForUpdate();
    expect(result.outcome, RefreshOutcome.upToDate);
    expect(settingsStore.lastCheckDate, clock);
  });

  test('nuova feed_version valida: scarica, valida hash e struttura, sostituisce la cache (CA-3.1)',
      () async {
    settingsStore.cachedFeedVersion = '20260618-7';
    final zipBytes = _buildZip('20260701-1');
    final sha = sha256.convert(zipBytes).toString();

    final service = makeService((req) async {
      if (req.url == _zipUrl) {
        return http.Response.bytes(zipBytes, 200);
      }
      return http.Response(
        _manifestJson(feedVersion: '20260701-1', sha256Hex: sha),
        200,
      );
    });

    expect(await service.cachedFeedDirectory(), isNull);

    final result = await service.checkForUpdate();

    expect(result.outcome, RefreshOutcome.updated);
    expect(result.newFeedVersion, '20260701-1');
    expect(settingsStore.cachedFeedVersion, '20260701-1');
    expect(settingsStore.lastCheckDate, clock);

    final cacheDir = await service.cachedFeedDirectory();
    expect(cacheDir, isNotNull);
    final content = await File('${cacheDir!.path}/gtfs/feed_info.txt').readAsString();
    expect(content, contains('20260701-1'));
  });

  test('hash non corrispondente: downloadFailed, cache precedente intatta (CA-7.1)',
      () async {
    settingsStore.cachedFeedVersion = '20260618-7';
    final zipBytes = _buildZip('20260701-1');

    final service = makeService((req) async {
      if (req.url == _zipUrl) {
        return http.Response.bytes(zipBytes, 200);
      }
      return http.Response(
        _manifestJson(
          feedVersion: '20260701-1',
          sha256Hex: 'deadbeef' * 8,
        ),
        200,
      );
    });

    final result = await service.checkForUpdate();

    expect(result.outcome, RefreshOutcome.downloadFailed);
    expect(settingsStore.lastCheckDate, isNull);
    expect(settingsStore.cachedFeedVersion, '20260618-7');
    expect(await service.cachedFeedDirectory(), isNull);
  });

  test('feed_version nello zip diversa dal manifest: downloadFailed (validazione struttura)',
      () async {
    settingsStore.cachedFeedVersion = '20260618-7';
    // Lo zip dichiara una versione diversa da quella annunciata nel manifest.
    final zipBytes = _buildZip('20260702-1');
    final sha = sha256.convert(zipBytes).toString();

    final service = makeService((req) async {
      if (req.url == _zipUrl) {
        return http.Response.bytes(zipBytes, 200);
      }
      return http.Response(
        _manifestJson(feedVersion: '20260701-1', sha256Hex: sha),
        200,
      );
    });

    final result = await service.checkForUpdate();
    expect(result.outcome, RefreshOutcome.downloadFailed);
    expect(settingsStore.lastCheckDate, isNull);
  });

  test('force=true bypassa il vincolo "un controllo al giorno"', () async {
    settingsStore.lastCheckDate = clock;
    settingsStore.cachedFeedVersion = '20260618-7';
    var calls = 0;
    final service = makeService((req) async {
      calls++;
      return http.Response(_manifestJson(feedVersion: '20260618-7'), 200);
    });
    final result = await service.checkForUpdate(force: true);
    expect(result.outcome, RefreshOutcome.upToDate);
    expect(calls, 1);
  });

  test('ensureBaseline imposta la versione attiva solo se non già nota', () async {
    final service = makeService((req) => throw StateError('no network expected'));
    await service.ensureBaseline('20260618-7');
    expect(settingsStore.cachedFeedVersion, '20260618-7');
    await service.ensureBaseline('99999999-1');
    expect(settingsStore.cachedFeedVersion, '20260618-7');
  });
}
