/// Costruzione della lista di "Corse aggregate" per una data (§5).
///
/// Per ogni trip valido nel giorno richiesto (RF-05) prende la prima fermata
/// (origine) e l'ultima (destinazione) dalla sequenza stop_times, risolve
/// l'operatore via route→agency, calcola la durata e produce un [Journey].
/// La lista finale fonde i due operatori (RF-01), ordinata per ora di partenza.
library;

import '../data/gtfs_repository.dart';
import 'journey.dart';
import 'service_calendar.dart';

/// Restituisce le corse valide per [date], ordinate per orario di partenza.
List<Journey> buildJourneysForDate(GtfsFeed feed, DateTime date) {
  final journeys = <Journey>[];

  for (final trip in feed.trips) {
    final active = isServiceActive(
      trip.serviceId,
      date,
      calendars: feed.calendars,
      calendarDatesByService: feed.calendarDatesByService,
    );
    if (!active) continue;

    final stopTimes = feed.stopTimesByTrip[trip.id];
    if (stopTimes == null || stopTimes.length < 2) continue;

    final origin = stopTimes.first;
    final destination = stopTimes.last;

    final route = feed.routes[trip.routeId];
    final agency = route != null ? feed.agencies[route.agencyId] : null;

    journeys.add(Journey(
      tripId: trip.id,
      agencyId: agency?.id ?? route?.agencyId ?? '',
      operatorName: agency?.name ?? '',
      originStopName: feed.stops[origin.stopId]?.name ?? origin.stopId,
      destinationStopName:
          feed.stops[destination.stopId]?.name ?? destination.stopId,
      departure: origin.departure,
      arrival: destination.arrival,
      direction: trip.direction,
      headsign: trip.headsign,
      trainNumber: trip.shortName,
      bikes: trip.bikes,
      wheelchair: trip.wheelchair,
      attributes: feed.attributesByTrip[trip.id],
    ));
  }

  journeys.sort((a, b) => a.departure.compareTo(b.departure));
  return journeys;
}
