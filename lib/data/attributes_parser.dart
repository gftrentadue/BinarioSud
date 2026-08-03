/// Parser dei side-car JSON con gli attributi estesi non-GTFS (§README v2).
///
/// I file per direzione/operatore (`ti_*`, `fal_*_attributes.json`)
/// hanno la stessa forma: `{ "meta": {...}, "trains": [ {...} ] }`. Ogni treno è
/// agganciato per `trip_id`. Il campo `service_pattern` è ignorato di proposito
/// (la circolazione è governata dal calendario GTFS).
library;

import 'dart:convert';

import 'gtfs_models.dart';

/// Estrae gli attributi da un singolo file JSON, indicizzati per `trip_id`.
///
/// Robusto verso campi assenti: ritorna mappa vuota se il JSON non ha `trains`.
Map<String, TripAttributes> parseAttributes(String content) {
  final result = <String, TripAttributes>{};
  if (content.trim().isEmpty) return result;

  final dynamic decoded = jsonDecode(content);
  if (decoded is! Map || decoded['trains'] is! List) return result;

  for (final dynamic raw in decoded['trains'] as List) {
    if (raw is! Map) continue;
    final tripId = raw['trip_id'] as String?;
    if (tripId == null || tripId.isEmpty) continue;

    // Il binario di partenza ha nome diverso a seconda della stazione d'origine.
    // Da Bari Centrale è OCR non verificato (R-09); da Modugno è dichiarato
    // con certezza dalla fonte, quindi non serve la stessa cautela in UI.
    final platform = (raw['platform_bari_centrale'] ?? raw['platform_modugno'])
        as String?;
    final platformVerified = raw['platform_bari_centrale'] == null;

    final stops = <IntermediateStop>[];
    final dynamic rawStops = raw['intermediate_stops'];
    if (rawStops is List) {
      for (final dynamic s in rawStops) {
        if (s is! Map) continue;
        final name = s['name'] as String?;
        if (name == null || name.isEmpty) continue;
        stops.add(IntermediateStop(
          name: name,
          departure: (s['departure'] as String?) ?? '',
        ));
      }
    }

    result[tripId] = TripAttributes(
      tripId: tripId,
      category: (raw['category'] as String?) ?? '',
      categoryLabel: (raw['category_label'] as String?) ?? '',
      departurePlatform: _nullIfEmpty(platform),
      platformVerified: platformVerified,
      intermediateStops: stops,
      reservationRequired: raw['reservation_required'] == true,
      strikeGuaranteed: raw['strike_guaranteed'] == true,
      note: _nullIfEmpty(raw['service_note_raw'] as String?),
    );
  }
  return result;
}

String? _nullIfEmpty(String? v) =>
    (v == null || v.trim().isEmpty) ? null : v.trim();
