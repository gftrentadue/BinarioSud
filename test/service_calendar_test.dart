import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:binario_sud/domain/service_calendar.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late GtfsFeed feed;

  setUpAll(() async {
    feed = await GtfsRepository(bundle: FileAssetBundle()).load();
  });

  bool active(String serviceId, DateTime date) => isServiceActive(
        serviceId,
        date,
        calendars: feed.calendars,
        calendarDatesByService: feed.calendarDatesByService,
      );

  test('FAL_FERIALE attivo in un mercoledì feriale, non di domenica', () {
    expect(active('FAL_FERIALE', DateTime(2026, 6, 17)), isTrue); // mer
    expect(active('FAL_FERIALE', DateTime(2026, 6, 21)), isFalse); // dom
  });

  test('TI_FEST_SAB attivo di domenica, non in giorno feriale', () {
    expect(active('TI_FEST_SAB', DateTime(2026, 6, 21)), isTrue); // dom
    expect(active('TI_FEST_SAB', DateTime(2026, 6, 17)), isFalse); // mer
  });

  test('Ferragosto 15/08/2026: FAL_FERIALE rimosso, festivo (TI_FEST_SAB) attivo',
      () {
    final ferragosto = DateTime(2026, 8, 15); // sabato
    // calendar_dates rimuove FAL_FERIALE in questa data (eccezione type 2).
    expect(active('FAL_FERIALE', ferragosto), isFalse);
    // TI_FEST_SAB (sab+dom) non è tra le rimozioni → resta attivo.
    expect(active('TI_FEST_SAB', ferragosto), isTrue);
  });

  test('fuori finestra di validità → non attivo', () {
    // FAL_FERIALE parte dal 27/10/2025: una data precedente è fuori finestra.
    expect(active('FAL_FERIALE', DateTime(2025, 1, 1)), isFalse);
  });
}
