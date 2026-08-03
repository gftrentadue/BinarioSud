/// Persistenza locale delle preferenze utente (Fase 1: solo on-device, offline).
///
/// Astrazione minima così il controller resta testabile senza dipendere da
/// `shared_preferences`: i test possono iniettare un'implementazione in-memory.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Contratto di persistenza per le preferenze che sopravvivono alla sessione.
abstract class SettingsStore {
  /// Filtro "solo corse accessibili" memorizzato (RF-21). `false` se assente.
  Future<bool> loadOnlyAccessible();

  /// Salva lo stato del filtro accessibilità.
  Future<void> saveOnlyAccessible(bool value);
}

/// Implementazione basata su `shared_preferences` (storage locale del device).
class SharedPrefsSettingsStore implements SettingsStore {
  static const _kOnlyAccessible = 'filter.only_accessible';

  @override
  Future<bool> loadOnlyAccessible() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kOnlyAccessible) ?? false;
  }

  @override
  Future<void> saveOnlyAccessible(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnlyAccessible, value);
  }
}
