import 'package:binario_sud/data/gtfs_models.dart';
import 'package:binario_sud/domain/journey.dart';
import 'package:binario_sud/ui/journey_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Regressione: chip operatore lungo + badge "PROSSIMA" non devono causare
  // un RenderFlex overflow su schermi stretti (vedi journey_tile.dart).
  testWidgets('JourneyTile non va in overflow con operatore lungo + PROSSIMA',
      (tester) async {
    const journey = Journey(
      tripId: 'FAL_D1_1600',
      agencyId: 'FAL',
      operatorName: 'Ferrovie Appulo Lucane',
      originStopName: 'Bari Centrale (FAL)',
      destinationStopName: 'Modugno Città',
      departure: 16 * 3600,
      arrival: 16 * 3600 + 22 * 60,
      direction: Direction.versoModugno,
      headsign: 'Modugno Città',
    );

    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 360, // larghezza tipica di uno smartphone
          child: JourneyTile(journey: journey, isNext: true),
        ),
      ),
    ));

    // Un eventuale overflow in fase di layout fa fallire il test con
    // un'eccezione catturata da tester.takeException().
    expect(tester.takeException(), isNull);
    expect(find.text('PROSSIMA'), findsOneWidget);
    expect(find.text('16:00'), findsOneWidget);
  });
}
