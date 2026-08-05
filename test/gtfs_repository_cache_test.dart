import 'dart:convert';
import 'dart:io';

import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

/// Verifica che `GtfsRepository(cacheDir: ...)` legga le tabelle GTFS da una
/// cartella su disco (simulando la cache scaricata in Fase 2, RF-07) invece
/// che dal bundle. Gli attributi estesi (side-car) seguono lo stesso
/// criterio, file per file: dalla cache se presenti lì (schema_version 2),
/// altrimenti dal bundle.
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
    // Nessuna cartella attributes in cache: gli attributi ricadono sul
    // bundle, invariati rispetto a Fase 1.
    expect(fromCache.attributesByTrip, isNotEmpty);
    expect(fromCache.attributesByTrip.length, fromBundle.attributesByTrip.length);
  });

  test('withCacheDir(null) ripristina la lettura dal bundle', () async {
    final base = GtfsRepository(bundle: FileAssetBundle());
    final restored = base.withCacheDir(null);
    final feed = await restored.load();
    expect(feed.feedInfo.feedVersion, '20260618-7');
  });

  test('attributi estesi: preferiti dalla cache quando presenti, per singolo file',
      () async {
    final tmp = await Directory.systemTemp.createTemp('binariosud_cache_test');
    addTearDown(() async {
      if (tmp.existsSync()) await tmp.delete(recursive: true);
    });

    final gtfsDir = Directory('${tmp.path}/gtfs')..createSync(recursive: true);
    const gtfsFiles = [
      'agency.txt',
      'calendar.txt',
      'calendar_dates.txt',
      'feed_info.txt',
      'routes.txt',
      'stop_times.txt',
      'stops.txt',
      'trips.txt',
    ];
    for (final name in gtfsFiles) {
      final src = File('assets/gtfs/$name');
      await src.copy('${gtfsDir.path}/$name');
    }

    // Solo un side-car pubblicato in cache: gli altri tre devono ricadere
    // sul bundle, senza buchi. Il file di cache riparte dal contenuto intero
    // del bundle (stessi treni) e altera solo `category_label` del primo, per
    // non perdere gli altri treni dello stesso file (il confronto sul bundle
    // legge tutto il file, non un singolo treno).
    final attributesDir = Directory('${tmp.path}/attributes')
      ..createSync(recursive: true);
    final bundleTiJson = await File(
            'assets/attributes/ti_bari_modugno_attributes.json')
        .readAsString();
    final bundleTiDecoded =
        jsonDecode(bundleTiJson) as Map<String, dynamic>;
    final trains = (bundleTiDecoded['trains'] as List)
        .cast<Map<String, dynamic>>();
    final firstTripId = trains.first['trip_id'] as String;
    trains.first['category_label'] = 'Regionale (da cache)';
    await File('${attributesDir.path}/ti_bari_modugno_attributes.json')
        .writeAsString(jsonEncode(bundleTiDecoded));

    final fromCache = await GtfsRepository(
      bundle: FileAssetBundle(),
      cacheDir: tmp,
    ).load();
    final fromBundle = await GtfsRepository(bundle: FileAssetBundle()).load();

    // Il side-car presente in cache vince sul bundle.
    expect(fromCache.attributesByTrip[firstTripId]?.categoryLabel,
        'Regionale (da cache)');
    // Gli altri tre file, assenti in cache, ricadono sul bundle: stesso
    // numero totale di attributi indicizzati del solo-bundle.
    expect(fromCache.attributesByTrip.length, fromBundle.attributesByTrip.length);
  });
}
