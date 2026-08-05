/// Entrypoint app — Orari treni Modugno ⇄ Bari (MVP, Fase 1 bundle-only).
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'data/feed_refresh_service.dart';
import 'data/gtfs_repository.dart';
import 'data/settings_store.dart';
import 'state/schedule_controller.dart';
import 'ui/schedule_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Dati locale per DateFormat(..., 'it') usato nella UI.
  await initializeDateFormatting('it');
  runApp(const BinarioSudApp());
}

class BinarioSudApp extends StatelessWidget {
  const BinarioSudApp({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsStore = SharedPrefsSettingsStore();
    return ChangeNotifierProvider(
      create: (_) => ScheduleController(
        repository: GtfsRepository(),
        settingsStore: settingsStore,
        refreshService: FeedRefreshService(settingsStore: settingsStore),
      )..init(),
      child: MaterialApp(
        title: 'Orari Modugno ⇄ Bari',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorSchemeSeed: const Color(0xFF00695C),
          brightness: Brightness.light,
        ),
        // Locale italiana (Europe/Rome) per date e controlli (date picker).
        locale: const Locale('it'),
        supportedLocales: const [Locale('it')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const ScheduleScreen(),
      ),
    );
  }
}
