import 'package:binario_sud/data/attributes_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseAttributes mappa per trip_id e normalizza il binario', () {
    const json = '''
{
  "meta": {"operator": "Trenitalia"},
  "trains": [
    {
      "train_number": "19825",
      "trip_id": "TI_19825",
      "category": "R",
      "category_label": "Regionale",
      "platform_bari_centrale": "8",
      "intermediate_stops": [
        {"name": "Bari Villaggio del Lavoratore", "departure": "05:36"}
      ],
      "reservation_required": false,
      "strike_guaranteed": true,
      "service_note_raw": "NON CIRCOLA NEI GIORNI FESTIVI",
      "service_pattern": {"code": "MON_SAT", "_derived": true}
    }
  ]
}
''';
    final attrs = parseAttributes(json);
    expect(attrs.containsKey('TI_19825'), isTrue);

    final a = attrs['TI_19825']!;
    expect(a.category, 'R');
    expect(a.categoryLabel, 'Regionale');
    expect(a.departurePlatform, '8');
    expect(a.platformVerified, isFalse);
    expect(a.strikeGuaranteed, isTrue);
    expect(a.reservationRequired, isFalse);
    expect(a.note, 'NON CIRCOLA NEI GIORNI FESTIVI');
    expect(a.intermediateStops.single.name, 'Bari Villaggio del Lavoratore');
    expect(a.intermediateStops.single.departure, '05:36');
  });

  test('parseAttributes usa platform_modugno quando partenza da Modugno', () {
    const json = '''
{"trains": [{"trip_id": "TI_19826", "category": "R", "category_label": "Regionale", "platform_modugno": "1"}]}
''';
    expect(parseAttributes(json)['TI_19826']!.departurePlatform, '1');
    expect(parseAttributes(json)['TI_19826']!.platformVerified, isTrue);
  });

  test('parseAttributes tollera input vuoto o malformato', () {
    expect(parseAttributes(''), isEmpty);
    expect(parseAttributes('{"meta": {}}'), isEmpty);
    expect(parseAttributes('[]'), isEmpty);
  });
}
