/// Modello del manifest di versione (contratto §1.3, Fase 2 — RF-07).
///
/// File JSON pubblicato dalla pipeline a un URL stabile; è l'unico file letto
/// dall'app a ogni controllo giornaliero. Nessuna logica qui: solo dati.
library;

/// Manifest di versione del feed pubblicato dalla pipeline.
class FeedManifest {
  final int schemaVersion;
  final String feedVersion;
  final String feedUrl;
  final DateTime feedPublishedAt;

  /// Finestra di validità (`YYYY-MM-DD`), opzionale.
  final String? feedValidFrom;
  final String? feedValidTo;

  final int? feedSizeBytes;
  final String? feedSha256;
  final String? minAppVersion;
  final String? notes;

  /// Side-car attributi estesi (schema_version 2), stesso pattern dei campi
  /// `feed_*`: URL dello zip, dimensione e hash per la verifica integrità.
  final String? attributesUrl;
  final int? attributesSizeBytes;
  final String? attributesSha256;

  const FeedManifest({
    required this.schemaVersion,
    required this.feedVersion,
    required this.feedUrl,
    required this.feedPublishedAt,
    this.feedValidFrom,
    this.feedValidTo,
    this.feedSizeBytes,
    this.feedSha256,
    this.minAppVersion,
    this.notes,
    this.attributesUrl,
    this.attributesSizeBytes,
    this.attributesSha256,
  });

  factory FeedManifest.fromJson(Map<String, dynamic> json) {
    return FeedManifest(
      schemaVersion: json['schema_version'] as int,
      feedVersion: json['feed_version'] as String,
      feedUrl: json['feed_url'] as String,
      feedPublishedAt: DateTime.parse(json['feed_published_at'] as String),
      feedValidFrom: json['feed_valid_from'] as String?,
      feedValidTo: json['feed_valid_to'] as String?,
      feedSizeBytes: json['feed_size_bytes'] as int?,
      feedSha256: json['feed_sha256'] as String?,
      minAppVersion: json['min_app_version'] as String?,
      notes: json['notes'] as String?,
      attributesUrl: json['attributes_url'] as String?,
      attributesSizeBytes: json['attributes_size_bytes'] as int?,
      attributesSha256: json['attributes_sha256'] as String?,
    );
  }
}
