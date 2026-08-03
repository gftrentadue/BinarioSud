import 'package:binario_sud/data/gtfs_models.dart';
import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:binario_sud/domain/journey_builder.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsFeed feed;

  setUpAll(() async {
    feed = await GtfsRepository(bundle: FileAssetBundle()).load();
  });

  test('durata calcolata correttamente (FAL 05:44→06:03 = 19 min)', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    final j = journeys.firstWhere((j) => j.tripId == 'FAL_B_0544');
    expect(j.departureLabel, '05:44');
    expect(j.arrivalLabel, '06:03');
    expect(j.durationMinutes, 19);
  });

  test('lista ordinata per orario di partenza e fusa tra operatori', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    for (var i = 1; i < journeys.length; i++) {
      expect(journeys[i].departure >= journeys[i - 1].departure, isTrue);
    }
    final operators = journeys.map((j) => j.agencyId).toSet();
    expect(operators.containsAll({'TI', 'FAL'}), isTrue);
  });

  test('giorno feriale: corsa Lun-Ven presente, festiva (sab/dom) assente', () {
    final ids = buildJourneysForDate(feed, DateTime(2026, 6, 17)) // mer
        .map((j) => j.tripId)
        .toSet();
    expect(ids.contains('TI_19854'), isTrue); // TI_FER_LUNVEN
    expect(ids.contains('TI_19872'), isFalse); // TI_FEST_SAB
  });

  test('domenica: corsa festiva (sab/dom) presente, feriale Lun-Ven assente',
      () {
    final ids = buildJourneysForDate(feed, DateTime(2026, 6, 21)) // dom
        .map((j) => j.tripId)
        .toSet();
    expect(ids.contains('TI_19872'), isTrue); // TI_FEST_SAB
    expect(ids.contains('TI_19854'), isFalse); // TI_FER_LUNVEN
  });

  test('entrambe le direzioni presenti in un giorno feriale', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    final dirs = journeys.map((j) => j.direction).toSet();
    expect(dirs, containsAll({Direction.versoBari, Direction.versoModugno}));
  });

  test('attributi v2 propagati: numero treno e accessibilità per le corse TI',
      () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    final ti = journeys.firstWhere((j) => j.tripId == 'TI_19854');
    expect(ti.trainNumber, '19854');
    expect(ti.wheelchair, Availability.yes);
    expect(ti.bikes, Availability.yes);
  });

  test('FAL feed -7: bici ammesse (sì) ma carrozzina non accessibile (no)', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    final fal = journeys.firstWhere((j) => j.tripId == 'FAL_B_0544');
    expect(fal.bikes, Availability.yes); // bikes_allowed = 1
    expect(fal.wheelchair, Availability.no); // wheelchair_accessible = 2
  });

  test('attributi side-car agganciati per trip_id alle corse TI', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    // TI_19825 parte da Bari Centrale, binario 8, con fermata intermedia.
    final j = journeys.firstWhere((j) => j.tripId == 'TI_19825');
    expect(j.attributes, isNotNull);
    expect(j.attributes!.categoryLabel, 'Regionale');
    expect(j.attributes!.departurePlatform, '8');
    expect(j.attributes!.intermediateStops, isNotEmpty);
  });

  test('attributi side-car agganciati per trip_id anche alle corse FAL', () {
    final journeys = buildJourneysForDate(feed, DateTime(2026, 6, 17));
    // FAL_B_0544 parte da Modugno, senza binario noto, con fermate intermedie.
    final fal = journeys.firstWhere((j) => j.tripId == 'FAL_B_0544');
    expect(fal.attributes, isNotNull);
    expect(fal.attributes!.categoryLabel, 'Regionale');
    expect(fal.attributes!.departurePlatform, isNull);
    expect(fal.attributes!.intermediateStops, isNotEmpty);
  });
}
