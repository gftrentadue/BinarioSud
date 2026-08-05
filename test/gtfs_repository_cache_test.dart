import 'dart:io';

import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Verifica che `GtfsRepository(cacheDir: ...)` legga le tabelle GTFS da una
/// cartella su disco (simulando la cache scaricata in Fase 2, RF-07) invece
/// che dal bundle, mentre gli attributi estesi (side-car) restano letti dal
/// bundle in entrambi i casi (la pipeline non li pubblica ancora, vedi
/// STATO_PROGETTO.md).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('GtfsRepository legge da cacheDir quando presente', () async {
    final tmp = await Directory.systemTemp.createTemp('binariosud_cache_test');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    final gtfsDir = Directory('${tmp.path}/gtfs')..createSync(recursive: true);
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
    for (final name in files) {
      final src = File('assets/gtfs/$name');
      await src.copy('${gtfsDir.path}/$name');
    }

    final fromBundle = await GtfsRepository(bundle: FileAssetBundle()).load();
    final fromCache = await GtfsRepository(
      bundle: FileAssetBundle(),
      cacheDir: tmp,
    ).load();

    expect(fromCache.feedInfo.feedVersion, fromBundle.feedInfo.feedVersion);
    expect(fromCache.trips.length, fromBundle.trips.length);
    expect(fromCache.stopTimesByTrip.length, fromBundle.stopTimesByTrip.length);
    // Side-car sempre dal bundle: presenti anche quando le tabelle GTFS
    // vengono dalla cache di rete.
    expect(fromCache.attributesByTrip, isNotEmpty);
    expect(fromCache.attributesByTrip.length, fromBundle.attributesByTrip.length);
  });

  test('withCacheDir(null) ripristina la lettura dal bundle', () async {
    final base = GtfsRepository(bundle: FileAssetBundle());
    final restored = base.withCacheDir(null);
    final feed = await restored.load();
    expect(feed.feedInfo.feedVersion, '20260618-7');
  });
}
