/// Persistenza locale delle preferenze utente e dello stato di refresh (RF-07).
///
/// Astrazione minima così il controller resta testabile senza dipendere da
/// `shared_preferences`: i test possono iniettare un'implementazione in-memory.
library;

import 'package:shared_preferences/shared_preferences.dart';

/// Contratto di persistenza per le preferenze e lo stato che sopravvivono
/// alla sessione.
abstract class SettingsStore {
  /// Filtro "solo corse accessibili" memorizzato (RF-21). `false` se assente.
  Future<bool> loadOnlyAccessible();

  /// Salva lo stato del filtro accessibilità.
  Future<void> saveOnlyAccessible(bool value);

  /// `feed_version` dell'ultimo feed scaricato e messo in cache (RF-07,
  /// §1.4). `null` se non è mai stato scaricato nulla dalla rete.
  Future<String?> loadCachedFeedVersion();

  /// Salva la `feed_version` del feed appena messo in cache.
  Future<void> saveCachedFeedVersion(String version);

  /// Data (normalizzata a mezzanotte) dell'ultimo controllo del manifest
  /// riuscito (RF-07, §1.4: "un solo controllo al giorno"). `null` se non è
  /// mai stato fatto un controllo.
  Future<DateTime?> loadLastCheckDate();

  /// Salva la data dell'ultimo controllo del manifest riuscito.
  Future<void> saveLastCheckDate(DateTime date);
}

/// Implementazione basata su `shared_preferences` (storage locale del device).
class SharedPrefsSettingsStore implements SettingsStore {
  static const _kOnlyAccessible = 'filter.only_accessible';
  static const _kCachedFeedVersion = 'refresh.cached_feed_version';
  static const _kLastCheckDate = 'refresh.last_check_date';

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

  @override
  Future<String?> loadCachedFeedVersion() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCachedFeedVersion);
  }

  @override
  Future<void> saveCachedFeedVersion(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kCachedFeedVersion, version);
  }

  @override
  Future<DateTime?> loadLastCheckDate() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kLastCheckDate);
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  @override
  Future<void> saveLastCheckDate(DateTime date) async {
    final prefs = await SharedPreferences.getInstance();
    final normalized = DateTime(date.year, date.month, date.day);
    await prefs.setString(_kLastCheckDate, normalized.toIso8601String());
  }
}
