import 'package:binario_sud/data/csv_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsv', () {
    test('mappa header→valore e salta righe vuote', () {
      const csv = 'a,b,c\n1,2,3\n\n4,5,6\n';
      final rows = parseCsv(csv);
      expect(rows, hasLength(2));
      expect(rows.first, {'a': '1', 'b': '2', 'c': '3'});
      expect(rows.last['c'], '6');
    });

    test('campi finali mancanti diventano stringa vuota (coordinate vuote)', () {
      const csv = 'stop_id,stop_name,stop_lat,stop_lon\nMOD_TI,Modugno,,';
      final rows = parseCsv(csv);
      expect(rows.first['stop_lat'], '');
      expect(rows.first['stop_lon'], '');
    });

    test('gestisce CRLF e BOM', () {
      const csv = '﻿a,b\r\n1,2\r\n';
      final rows = parseCsv(csv);
      expect(rows.first, {'a': '1', 'b': '2'});
    });

    test('campi quotati con virgola interna', () {
      const csv = 'id,name\n1,"Bari, Centrale"';
      final rows = parseCsv(csv);
      expect(rows.first['name'], 'Bari, Centrale');
    });
  });

  group('parseGtfsTime', () {
    test('HH:MM:SS standard', () {
      expect(parseGtfsTime('05:44:00'), 5 * 3600 + 44 * 60);
      expect(parseGtfsTime('20:32:00'), 20 * 3600 + 32 * 60);
    });

    test('ore >= 24 (oltre mezzanotte, RNF-05)', () {
      expect(parseGtfsTime('25:10:00'), 25 * 3600 + 10 * 60);
    });

    test('vuoto o malformato → null', () {
      expect(parseGtfsTime(''), isNull);
      expect(parseGtfsTime('abc'), isNull);
    });
  });
}
