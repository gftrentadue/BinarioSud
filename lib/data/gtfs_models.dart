/// Modelli dati 1:1 con i file GTFS del feed (solo i campi usati nell'MVP, §1.2).
///
/// Sono immutabili e privi di logica di dominio: la derivazione della "Corsa
/// aggregata", la validità per giorno e il calcolo durata vivono nel layer
/// dominio (lib/domain/).
library;

/// Direzione della relazione (convenzione §1.5).
enum Direction {
  /// `direction_id = 0` ⇒ verso Bari.
  versoBari,

  /// `direction_id = 1` ⇒ verso Modugno.
  versoModugno;

  static Direction fromGtfs(String raw) =>
      raw.trim() == '1' ? Direction.versoModugno : Direction.versoBari;
}

/// Disponibilità a **3 stati** dei campi GTFS nativi `bikes_allowed` e
/// `wheelchair_accessible`. Valori GTFS: `0` = nessuna informazione, `1` = sì,
/// `2` = no. **Non sono booleani**: "no" e "ignoto" sono distinti (§business spec
/// v2; es. FAL `wheelchair_accessible=2` = accessibilità condizionata,
/// verificata D-13 — non "non accessibile" confermato, ≠ ignoto).
enum Availability {
  unknown,
  yes,
  no;

  static Availability fromGtfs(String? raw) {
    switch (raw?.trim()) {
      case '1':
        return Availability.yes;
      case '2':
        return Availability.no;
      default:
        return Availability.unknown;
    }
  }
}

/// Operatore (`agency.txt`).
class Agency {
  final String id;
  final String name;
  final String url;
  final String timezone;
  final String? lang;

  const Agency({
    required this.id,
    required this.name,
    required this.url,
    required this.timezone,
    this.lang,
  });
}

/// Fermata/stazione (`stops.txt`).
class Stop {
  final String id;
  final String name;

  /// Coordinate: valorizzate dal feed v2 (R-03 chiusa, §6.6). Restano opzionali
  /// nel modello; non ancora usate in UI (nessuna mappa: fuori MVP).
  final double? lat;
  final double? lon;

  const Stop({
    required this.id,
    required this.name,
    this.lat,
    this.lon,
  });
}

/// Linea (`routes.txt`).
class Route {
  final String id;
  final String agencyId;
  final String? shortName;
  final String longName;
  final int routeType;

  const Route({
    required this.id,
    required this.agencyId,
    this.shortName,
    required this.longName,
    required this.routeType,
  });
}

/// Corsa (`trips.txt`).
class Trip {
  final String routeId;
  final String serviceId;
  final String id;
  final String? headsign;
  final Direction direction;

  /// Numero treno (`trip_short_name`): valorizzato per le corse TI e per alcune
  /// FAL, vuoto (→ `null`) per la maggior parte delle FAL.
  final String? shortName;

  /// Bici a bordo (`bikes_allowed`), 3 stati.
  final Availability bikes;

  /// Accessibilità in sedia a rotelle (`wheelchair_accessible`), 3 stati.
  final Availability wheelchair;

  const Trip({
    required this.routeId,
    required this.serviceId,
    required this.id,
    this.headsign,
    required this.direction,
    this.shortName,
    this.bikes = Availability.unknown,
    this.wheelchair = Availability.unknown,
  });
}

/// Orario per fermata (`stop_times.txt`).
///
/// [arrival]/[departure] sono espressi in **secondi dalla mezzanotte**: questo
/// consente di rappresentare correttamente valori ≥ 24:00:00 (corse oltre la
/// mezzanotte, RNF-05) senza ambiguità.
class StopTime {
  final String tripId;
  final int arrival;
  final int departure;
  final String stopId;
  final int stopSequence;

  const StopTime({
    required this.tripId,
    required this.arrival,
    required this.departure,
    required this.stopId,
    required this.stopSequence,
  });
}

/// Periodicità ricorrente (`calendar.txt`).
class Calendar {
  final String serviceId;

  /// Indice 0 = lunedì … 6 = domenica (allineato a `DateTime.weekday - 1`).
  final List<bool> activeDays;

  /// Finestra di validità inclusiva (`YYYYMMDD`).
  final int startDate;
  final int endDate;

  const Calendar({
    required this.serviceId,
    required this.activeDays,
    required this.startDate,
    required this.endDate,
  });
}

/// Tipo di eccezione di calendario (`calendar_dates.txt`).
enum ExceptionType {
  /// `1` = servizio aggiunto in quella data.
  added,

  /// `2` = servizio rimosso in quella data.
  removed;

  static ExceptionType fromGtfs(String raw) =>
      raw.trim() == '2' ? ExceptionType.removed : ExceptionType.added;
}

/// Eccezione di calendario (`calendar_dates.txt`).
class CalendarDate {
  final String serviceId;

  /// Data dell'eccezione (`YYYYMMDD`).
  final int date;
  final ExceptionType exceptionType;

  const CalendarDate({
    required this.serviceId,
    required this.date,
    required this.exceptionType,
  });
}

/// Fermata intermedia di una corsa (side-car JSON, non-GTFS).
class IntermediateStop {
  final String name;

  /// Orario di transito/partenza in formato `HH:MM` (così com'è nella fonte).
  final String departure;

  const IntermediateStop({required this.name, required this.departure});
}

/// Attributi estesi **non-GTFS** di una corsa TI (side-car JSON, §README v2).
///
/// Agganciati per `trip_id`. Il campo `service_pattern` dei JSON è
/// volutamente ignorato: la circolazione resta governata da
/// `calendar.txt`/`calendar_dates.txt` (unica fonte di verità).
class TripAttributes {
  final String tripId;

  /// Categoria treno (`R`, `RV`) e relativa etichetta estesa.
  final String category;
  final String categoryLabel;

  /// Binario di partenza (lettura OCR best-effort, da verificare — §README).
  final String? departurePlatform;

  final List<IntermediateStop> intermediateStops;
  final bool reservationRequired;
  final bool strikeGuaranteed;

  /// Nota di circolazione testuale dalla fonte (`service_note_raw`), se presente.
  final String? note;

  const TripAttributes({
    required this.tripId,
    required this.category,
    required this.categoryLabel,
    this.departurePlatform,
    this.intermediateStops = const [],
    this.reservationRequired = false,
    this.strikeGuaranteed = false,
    this.note,
  });
}

/// Metadati feed (`feed_info.txt`) — riferimento di versione (RF-08).
class FeedInfo {
  final String publisherName;
  final String publisherUrl;
  final String lang;
  final String feedVersion;

  /// Finestra di validità complessiva (`YYYYMMDD`), opzionale.
  final int? startDate;
  final int? endDate;

  const FeedInfo({
    required this.publisherName,
    required this.publisherUrl,
    required this.lang,
    required this.feedVersion,
    this.startDate,
    this.endDate,
  });
}
