import 'package:binario_sud/data/gtfs_repository.dart';
import 'package:binario_sud/state/schedule_controller.dart';
import 'package:binario_sud/ui/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'helpers.dart';

// NB: questi sono test **funzionali** (struttura e interazioni), non di layout.
// L'overflow di pixel non è verificabile in modo affidabile in widget test: il
// font di test rende ogni glifo a larghezza fissa, gonfiando i testi rispetto
// al device reale. La verifica anti-overflow si fa a mano sul device.
void main() {
  setUpAll(() => initializeDateFormatting('it'));

  // Mercoledì 17/06/2026, ore 12:00. `_DaySelector` usa il `now` del
  // controller, quindi con giorno = oggi la chip mostra "Data".
  ScheduleController makeController() => ScheduleController(
        repository: GtfsRepository(bundle: FileAssetBundle()),
        now: () => DateTime(2026, 6, 17, 12, 0),
      );

  Future<ScheduleController> pumpScreen(WidgetTester tester) async {
    final c = makeController();
    // init() carica il feed con I/O reale (File): nei widget test va eseguito
    // in runAsync, altrimenti non si completa e la schermata resta in loading.
    await tester.runAsync(() => c.init());
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: ChangeNotifierProvider<ScheduleController>.value(
          value: c,
          child: const ScheduleScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return c;
  }

  testWidgets('struttura Opzione A: giorno in schermata, filtri nell’AppBar',
      (tester) async {
    await pumpScreen(tester);
    // Le tre chip giorno restano in schermata.
    expect(find.text('Oggi'), findsOneWidget);
    expect(find.text('Domani'), findsOneWidget);
    expect(find.text('Data'), findsOneWidget);
    // I filtri sono spostati nell'azione AppBar.
    expect(find.byTooltip('Filtri'), findsOneWidget);
    // Il pannello non è ancora aperto (nessuna sezione "Operatore").
    expect(find.text('Operatore'), findsNothing);
  });

  testWidgets('l’icona filtri nell’AppBar apre il pannello', (tester) async {
    await pumpScreen(tester);

    await tester.tap(find.byTooltip('Filtri'));
    await tester.pumpAndSettle();

    // Titolo + sezioni del bottom sheet.
    expect(find.text('Filtri'), findsOneWidget);
    expect(find.text('Operatore'), findsOneWidget);
    expect(find.text('A partire dalle'), findsOneWidget);
    expect(find.text('Servizi a bordo'), findsOneWidget);
  });

  testWidgets('il badge mostra il numero di filtri attivi', (tester) async {
    final c = await pumpScreen(tester);

    // Nessun badge quando non ci sono filtri attivi.
    expect(find.byType(Badge), findsNothing);

    c.setOperatorFilter(OperatorFilter.fal);
    c.setOnlyBikes(true);
    await tester.pumpAndSettle();

    expect(find.byType(Badge), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('RF-14: pull-to-refresh sulla lista forza un controllo',
      (tester) async {
    await pumpScreen(tester);

    // Trascina la lista verso il basso per attivare il RefreshIndicator.
    await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // Il controller di test non ha un refreshService (RF-07 disattivato in
    // questo setup): l'esito atteso è comunque "non configurato", a conferma
    // che il gesto ha chiamato `forceRefreshCheck()`.
    expect(find.text('Refresh non configurato'), findsOneWidget);
  });
}
