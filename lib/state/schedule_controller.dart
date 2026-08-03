/// Stato della schermata orari (provider/ChangeNotifier).
///
/// Tiene il feed caricato dal bundle e i filtri utente (direzione, giorno,
/// fascia oraria, operatore), espone la lista corse visibili già filtrata e
/// ordinata, la "prossima corsa" (RF-11) e i metadati di freschezza (RF-08/13).
///
/// Tutta l'elaborazione è locale e sincrona su un dataset piccolo (RNF-03).
library;

import 'package:flutter/foundation.dart';

import '../data/gtfs_models.dart';
import '../data/gtfs_repository.dart';
import '../data/settings_store.dart';
import '../domain/journey.dart';
import '../domain/journey_builder.dart';
import '../domain/service_calendar.dart';

/// Stato di caricamento del feed (UC-01, RF-09).
enum FeedStatus { loading, ready, error }

/// Filtro per operatore (RF-12).
enum OperatorFilter { tutti, trenitalia, fal }

class ScheduleController extends ChangeNotifier {
  final GtfsRepository _repository;

  /// Sorgente dell'ora corrente (iniettabile per i test).
  final DateTime Function() _now;

  /// Persistenza preferenze (opzionale): se `null` i filtri restano in-memory
  /// (utile nei test). In produzione si inietta `SharedPrefsSettingsStore`.
  final SettingsStore? _settingsStore;

  ScheduleController({
    required GtfsRepository repository,
    DateTime Function()? now,
    SettingsStore? settingsStore,
  })  : _repository = repository,
        _now = now ?? DateTime.now,
        _settingsStore = settingsStore;

  // --- Stato feed ---
  FeedStatus _status = FeedStatus.loading;
  FeedStatus get status => _status;

  Object? _error;
  Object? get error => _error;

  GtfsFeed? _feed;

  // --- Filtri ---
  Direction _direction = Direction.versoModugno;
  Direction get direction => _direction;

  /// Giorno selezionato, normalizzato a mezzanotte (RF-10).
  late DateTime _selectedDay = _today();

  DateTime get selectedDay => _selectedDay;

  /// Fascia oraria: soglia minima di partenza in secondi-dalla-mezzanotte
  /// (RF-04). `null` ⇒ usa il default "da adesso" se il giorno è oggi.
  int? _fromTimeOverride;

  /// Soglia oraria scelta esplicitamente (`null` = default "da adesso").
  int? get fromTimeOverride => _fromTimeOverride;

  OperatorFilter _operatorFilter = OperatorFilter.tutti;
  OperatorFilter get operatorFilter => _operatorFilter;

  /// Filtro "solo corse con trasporto bici" (RF-20).
  bool _onlyBikes = false;
  bool get onlyBikes => _onlyBikes;

  /// Filtro "solo corse accessibili in sedia a rotelle" (RF-21).
  bool _onlyAccessible = false;
  bool get onlyAccessible => _onlyAccessible;

  // --- Ciclo di vita ---
  Future<void> init() async {
    _status = FeedStatus.loading;
    notifyListeners();
    // Ripristina le preferenze persistite (RF-21: accessibilità "sticky").
    if (_settingsStore != null) {
      _onlyAccessible = await _settingsStore.loadOnlyAccessible();
    }
    try {
      _feed = await _repository.load();
      _status = FeedStatus.ready;
    } catch (e) {
      _error = e;
      _status = FeedStatus.error;
    }
    notifyListeners();
  }

  // --- Comandi UI ---
  void setDirection(Direction d) {
    if (_direction == d) return;
    _direction = d;
    notifyListeners();
  }

  /// Inverte la direzione corrente (RF-15, COULD).
  void toggleDirection() {
    _direction = _direction == Direction.versoBari
        ? Direction.versoModugno
        : Direction.versoBari;
    notifyListeners();
  }

  void setSelectedDay(DateTime day) {
    final normalized = DateTime(day.year, day.month, day.day);
    if (_selectedDay == normalized) return;
    _selectedDay = normalized;
    // Cambiando giorno la fascia "da adesso" non ha più senso: si riparte
    // dall'inizio della giornata finché l'utente non imposta un orario.
    _fromTimeOverride = null;
    notifyListeners();
  }

  /// Imposta una soglia oraria minima (RF-04). `null` ripristina il default.
  void setFromTime(int? secondsFromMidnight) {
    _fromTimeOverride = secondsFromMidnight;
    notifyListeners();
  }

  void setOperatorFilter(OperatorFilter f) {
    if (_operatorFilter == f) return;
    _operatorFilter = f;
    notifyListeners();
  }

  void setOnlyBikes(bool value) {
    if (_onlyBikes == value) return;
    _onlyBikes = value;
    notifyListeners();
  }

  void setOnlyAccessible(bool value) {
    if (_onlyAccessible == value) return;
    _onlyAccessible = value;
    // Persistito tra le sessioni (preferenza utente stabile).
    _settingsStore?.saveOnlyAccessible(value);
    notifyListeners();
  }

  /// Azzera tutti i filtri del pannello, riportandoli al default.
  void resetFilters() {
    _operatorFilter = OperatorFilter.tutti;
    _onlyBikes = false;
    _fromTimeOverride = null;
    if (_onlyAccessible) {
      _onlyAccessible = false;
      _settingsStore?.saveOnlyAccessible(false);
    }
    notifyListeners();
  }

  /// Numero di filtri attivi rispetto al default (per il badge "Filtri").
  /// La direzione e il giorno non contano: non sono nel pannello filtri.
  int get activeFilterCount {
    var n = 0;
    if (_operatorFilter != OperatorFilter.tutti) n++;
    if (_onlyBikes) n++;
    if (_onlyAccessible) n++;
    if (_fromTimeOverride != null) n++;
    return n;
  }

  // --- Derivati ---

  /// "Oggi" secondo il clock del controller (normalizzato a mezzanotte).
  /// Esposto alla UI così il selettore giorno usa lo stesso `now` iniettato.
  DateTime get today => _today();

  /// Vero se il giorno selezionato è oggi.
  bool get isToday => _selectedDay == _today();

  /// Soglia oraria effettiva applicata alla lista (RF-04).
  /// Default: ora corrente se il giorno è oggi, altrimenti inizio giornata.
  int get effectiveFromTime {
    if (_fromTimeOverride != null) return _fromTimeOverride!;
    if (isToday) {
      final n = _now();
      return n.hour * 3600 + n.minute * 60 + n.second;
    }
    return 0;
  }

  /// Versione dei dati in uso (RF-08).
  String get feedVersion => _feed?.feedInfo.feedVersion ?? '';

  /// Vero se la data odierna supera `feed_end_date` (RF-13/CA-5.1).
  bool get isFeedExpired {
    final end = _feed?.feedInfo.endDate;
    if (end == null) return false;
    return dateToInt(_now()) > end;
  }

  /// Tutte le corse del giorno selezionato, già fuse e ordinate.
  List<Journey> get _journeysOfDay =>
      _feed == null ? const [] : buildJourneysForDate(_feed!, _selectedDay);

  /// Filtri indipendenti dalla fascia oraria: direzione + operatore +
  /// bici (RF-20) + accessibilità (RF-21). Condiviso da `visibleJourneys` e
  /// `hasJourneysIgnoringTime` così l'insieme di base resta coerente.
  bool _matchesNonTimeFilters(Journey j) {
    if (j.direction != _direction) return false;
    switch (_operatorFilter) {
      case OperatorFilter.trenitalia:
        if (j.agencyId != 'TI') return false;
      case OperatorFilter.fal:
        if (j.agencyId != 'FAL') return false;
      case OperatorFilter.tutti:
        break;
    }
    if (_onlyBikes && j.bikes != Availability.yes) return false;
    if (_onlyAccessible && j.wheelchair != Availability.yes) return false;
    return true;
  }

  /// Corse visibili dopo i filtri direzione + operatore + bici + accessibilità
  /// + fascia oraria.
  List<Journey> get visibleJourneys {
    final from = effectiveFromTime;
    return _journeysOfDay
        .where((j) => _matchesNonTimeFilters(j) && j.departure >= from)
        .toList();
  }

  /// Vero se esiste almeno una corsa che soddisfa i filtri **ignorando** la
  /// soglia oraria. Serve a distinguere "nessuna corsa dopo l'orario" (offri
  /// 'prima del giorno') da "nessuna corsa proprio" (UC-06).
  bool get hasJourneysIgnoringTime =>
      _journeysOfDay.any(_matchesNonTimeFilters);

  /// Numero di corse **FAL** escluse dalla vista *solo* a causa del filtro
  /// accessibilità (RF-21/R-10): corse che passerebbero direzione, operatore,
  /// bici e fascia oraria ma hanno `wheelchair != yes`. Serve a segnalare in UI
  /// l'esclusione, evitando di scartare silenziosamente un dato **assunto**
  /// (FAL `2` non verificato), col rischio di escludere a torto utenti in
  /// carrozzina. Vale `0` se il filtro non è attivo.
  int get falExcludedByAccessibilityCount {
    if (!_onlyAccessible) return 0;
    if (_operatorFilter == OperatorFilter.trenitalia) return 0;
    final from = effectiveFromTime;
    return _journeysOfDay.where((j) {
      if (j.agencyId != 'FAL') return false;
      if (j.wheelchair == Availability.yes) return false;
      if (j.direction != _direction) return false;
      if (_onlyBikes && j.bikes != Availability.yes) return false;
      return j.departure >= from;
    }).length;
  }

  /// `trip_id` della prossima corsa rispetto all'ora corrente (RF-11):
  /// la prima corsa visibile se il giorno è oggi. `null` se nessuna o se il
  /// giorno non è oggi (l'evidenziazione "prossima" ha senso solo per oggi).
  String? get nextJourneyTripId {
    if (!isToday) return null;
    final list = visibleJourneys;
    return list.isEmpty ? null : list.first.tripId;
  }

  DateTime _today() {
    final n = _now();
    return DateTime(n.year, n.month, n.day);
  }
}
