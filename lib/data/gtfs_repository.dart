/// Caricamento del feed GTFS: dal bundle dell'app (Fase 1, D-10: bundle-only)
/// oppure, se presente, dalla cache scaricata in Fase 2 (RF-07).
///
/// Stesso parser per entrambe le sorgenti: cambia solo da dove arrivano le
/// stringhe degli 8 file `.txt`. Gli attributi estesi non-GTFS (side-car,
/// `assets/attributes/`) sono **sempre** letti dal bundle: la pipeline non li
/// pubblica ancora nello zip Fase 2 (vedi STATO_PROGETTO.md), quindi
/// aggiornano solo con una nuova versione dell'app.
library;

import 'dart:io';

import 'package:flutter/services.dart' show rootBundle, AssetBundle;

import 'attributes_parser.dart';
import 'csv_parser.dart';
import 'gtfs_models.dart';

/// Contenitore in memoria del feed, con indici per accesso rapido.
class GtfsFeed {
  final Map<String, Agency> agencies;
  final Map<String, Stop> stops;
  final Map<String, Route> routes;
  final List<Trip> trips;

  /// `stop_times` raggruppati per `trip_id`, ordinati per `stop_sequence`.
  final Map<String, List<StopTime>> stopTimesByTrip;
  final Map<String, Calendar> calendars;

  /// Eccezioni raggruppate per `service_id`.
  final Map<String, List<CalendarDate>> calendarDatesByService;
  final FeedInfo feedInfo;

  /// Attributi estesi non-GTFS, indicizzati per `trip_id` (side-car JSON).
  /// Presenti sia per le corse TI sia per le corse FAL (side-car estesi a
  /// FAL il 25/06/2026, vedi STATO_PROGETTO.md).
  final Map<String, TripAttributes> attributesByTrip;

  const GtfsFeed({
    required this.agencies,
    required this.stops,
    required this.routes,
    required this.trips,
    required this.stopTimesByTrip,
    required this.calendars,
    required this.calendarDatesByService,
    required this.feedInfo,
    this.attributesByTrip = const {},
  });
}

/// Carica e parsa il feed GTFS.
class GtfsRepository {
  static const _basePath = 'assets/gtfs';
  static const _attributesPath = 'assets/attributes';

  final AssetBundle _bundle;

  /// Cartella cache scaricata (Fase 2, RF-07). Se presente, le tabelle GTFS
  /// vengono lette da qui (`<cacheDir>/gtfs/*.txt`) invece che dal bundle; gli
  /// attributi estesi restano comunque letti dal bundle (vedi doc di libreria).
  final Directory? _cacheDir;

  GtfsRepository({AssetBundle? bundle, Directory? cacheDir})
      : _bundle = bundle ?? rootBundle,
        _cacheDir = cacheDir;

  /// Nuova istanza che riusa lo stesso bundle (per gli attributi estesi,
  /// sempre letti da lì) ma legge le tabelle GTFS da [cacheDir] (Fase 2,
  /// RF-07). `cacheDir` nullo ripristina la lettura dal solo bundle.
  GtfsRepository withCacheDir(Directory? cacheDir) =>
      GtfsRepository(bundle: _bundle, cacheDir: cacheDir);

  Future<GtfsFeed> load() async {
    final files = await Future.wait([
      _read('agency.txt'),
      _read('stops.txt'),
      _read('routes.txt'),
      _read('trips.txt'),
      _read('stop_times.txt'),
      _read('calendar.txt'),
      _read('calendar_dates.txt'),
      _read('feed_info.txt'),
    ]);

    // Side-car JSON con attributi estesi (tolleranti all'assenza dei file).
    final attributeFiles = await Future.wait([
      _readAttributes('ti_bari_modugno_attributes.json'),
      _readAttributes('ti_modugno_bari_attributes.json'),
      _readAttributes('fal_bari_modugno_attributes.json'),
      _readAttributes('fal_modugno_bari_attributes.json'),
    ]);

    final agencies = <String, Agency>{};
    for (final r in parseCsv(files[0])) {
      final a = Agency(
        id: r['agency_id']!,
        name: r['agency_name'] ?? '',
        url: r['agency_url'] ?? '',
        timezone: r['agency_timezone'] ?? 'Europe/Rome',
        lang: _nullIfEmpty(r['agency_lang']),
      );
      agencies[a.id] = a;
    }

    final stops = <String, Stop>{};
    for (final r in parseCsv(files[1])) {
      final s = Stop(
        id: r['stop_id']!,
        name: r['stop_name'] ?? '',
        lat: _parseDouble(r['stop_lat']),
        lon: _parseDouble(r['stop_lon']),
      );
      stops[s.id] = s;
    }

    final routes = <String, Route>{};
    for (final r in parseCsv(files[2])) {
      final route = Route(
        id: r['route_id']!,
        agencyId: r['agency_id'] ?? '',
        shortName: _nullIfEmpty(r['route_short_name']),
        longName: r['route_long_name'] ?? '',
        routeType: int.tryParse(r['route_type'] ?? '') ?? 2,
      );
      routes[route.id] = route;
    }

    final trips = <Trip>[];
    for (final r in parseCsv(files[3])) {
      trips.add(Trip(
        routeId: r['route_id'] ?? '',
        serviceId: r['service_id'] ?? '',
        id: r['trip_id']!,
        headsign: _nullIfEmpty(r['trip_headsign']),
        direction: Direction.fromGtfs(r['direction_id'] ?? '0'),
        shortName: _nullIfEmpty(r['trip_short_name']),
        bikes: Availability.fromGtfs(r['bikes_allowed']),
        wheelchair: Availability.fromGtfs(r['wheelchair_accessible']),
      ));
    }

    final stopTimesByTrip = <String, List<StopTime>>{};
    for (final r in parseCsv(files[4])) {
      final st = StopTime(
        tripId: r['trip_id']!,
        arrival: parseGtfsTime(r['arrival_time'] ?? '') ?? 0,
        departure: parseGtfsTime(r['departure_time'] ?? '') ?? 0,
        stopId: r['stop_id'] ?? '',
        stopSequence: int.tryParse(r['stop_sequence'] ?? '') ?? 0,
      );
      stopTimesByTrip.putIfAbsent(st.tripId, () => []).add(st);
    }
    for (final list in stopTimesByTrip.values) {
      list.sort((a, b) => a.stopSequence.compareTo(b.stopSequence));
    }

    final calendars = <String, Calendar>{};
    for (final r in parseCsv(files[5])) {
      final c = Calendar(
        serviceId: r['service_id']!,
        activeDays: [
          r['monday'] == '1',
          r['tuesday'] == '1',
          r['wednesday'] == '1',
          r['thursday'] == '1',
          r['friday'] == '1',
          r['saturday'] == '1',
          r['sunday'] == '1',
        ],
        startDate: int.tryParse(r['start_date'] ?? '') ?? 0,
        endDate: int.tryParse(r['end_date'] ?? '') ?? 99999999,
      );
      calendars[c.serviceId] = c;
    }

    final calendarDatesByService = <String, List<CalendarDate>>{};
    for (final r in parseCsv(files[6])) {
      final cd = CalendarDate(
        serviceId: r['service_id']!,
        date: int.tryParse(r['date'] ?? '') ?? 0,
        exceptionType: ExceptionType.fromGtfs(r['exception_type'] ?? '1'),
      );
      calendarDatesByService.putIfAbsent(cd.serviceId, () => []).add(cd);
    }

    final attributesByTrip = <String, TripAttributes>{};
    for (final content in attributeFiles) {
      attributesByTrip.addAll(parseAttributes(content));
    }

    final feedRows = parseCsv(files[7]);
    final fr = feedRows.isNotEmpty ? feedRows.first : <String, String>{};
    final feedInfo = FeedInfo(
      publisherName: fr['feed_publisher_name'] ?? '',
      publisherUrl: fr['feed_publisher_url'] ?? '',
      lang: fr['feed_lang'] ?? 'it',
      feedVersion: fr['feed_version'] ?? '',
      startDate: int.tryParse(fr['feed_start_date'] ?? ''),
      endDate: int.tryParse(fr['feed_end_date'] ?? ''),
    );

    return GtfsFeed(
      agencies: agencies,
      stops: stops,
      routes: routes,
      trips: trips,
      stopTimesByTrip: stopTimesByTrip,
      calendars: calendars,
      calendarDatesByService: calendarDatesByService,
      feedInfo: feedInfo,
      attributesByTrip: attributesByTrip,
    );
  }

  Future<String> _read(String name) {
    final cacheDir = _cacheDir;
    if (cacheDir != null) {
      return File('${cacheDir.path}/gtfs/$name').readAsString();
    }
    return _bundle.loadString('$_basePath/$name');
  }

  /// Legge un side-car JSON; ritorna stringa vuota se il file manca (gli
  /// attributi sono opzionali e non devono mai bloccare il caricamento feed).
  Future<String> _readAttributes(String name) async {
    try {
      return await _bundle.loadString('$_attributesPath/$name');
    } catch (_) {
      return '';
    }
  }
}

String? _nullIfEmpty(String? v) =>
    (v == null || v.trim().isEmpty) ? null : v.trim();

double? _parseDouble(String? v) {
  if (v == null || v.trim().isEmpty) return null;
  return double.tryParse(v.trim());
}
