/// Entità di dominio "Corsa aggregata" (§5): vista derivata che l'app mostra.
///
/// Fonde trip + stop_times (origine/destinazione) + route/agency in un'unica
/// riga lista, indipendente dall'operatore (RF-01/RF-03).
library;

import '../data/gtfs_models.dart';

class Journey {
  /// `trip_id` di origine (utile per dettaglio/dedup).
  final String tripId;

  final String agencyId;
  final String operatorName;

  final String originStopName;
  final String destinationStopName;

  /// Secondi dalla mezzanotte (gestisce ≥ 24:00:00, RNF-05).
  final int departure;
  final int arrival;

  final Direction direction;
  final String? headsign;

  /// Numero treno (`trip_short_name`), assente per molte corse FAL.
  final String? trainNumber;

  /// Bici a bordo (3 stati: sì / no / ignoto).
  final Availability bikes;

  /// Accessibilità in sedia a rotelle (3 stati: sì / no / ignoto).
  final Availability wheelchair;

  /// Attributi estesi non-GTFS (categoria, binario, fermata intermedia, …),
  /// presenti solo per le corse TI; `null` per FAL.
  final TripAttributes? attributes;

  const Journey({
    required this.tripId,
    required this.agencyId,
    required this.operatorName,
    required this.originStopName,
    required this.destinationStopName,
    required this.departure,
    required this.arrival,
    required this.direction,
    this.headsign,
    this.trainNumber,
    this.bikes = Availability.unknown,
    this.wheelchair = Availability.unknown,
    this.attributes,
  });

  /// Durata in minuti = arrivo − partenza (§5). Gestisce orari oltre mezzanotte
  /// perché entrambi sono secondi dalla mezzanotte sullo stesso asse.
  int get durationMinutes => ((arrival - departure) / 60).round();

  /// `HH:MM` dell'orario di partenza (riporta nel range 0–23 le ore ≥ 24).
  String get departureLabel => _hhmm(departure);

  /// `HH:MM` dell'orario di arrivo.
  String get arrivalLabel => _hhmm(arrival);
}

/// Formatta secondi-dalla-mezzanotte come `HH:MM` (24h). Le ore ≥ 24 sono
/// riportate nel giorno (es. 25:10 → 01:10) per la visualizzazione.
String _hhmm(int secondsFromMidnight) {
  final totalMinutes = secondsFromMidnight ~/ 60;
  final h = (totalMinutes ~/ 60) % 24;
  final m = totalMinutes % 60;
  return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
}
