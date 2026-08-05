import 'package:binario_sud/data/feed_manifest.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('FeedManifest.fromJson legge i campi attributes_* (schema_version 2)',
      () {
    final manifest = FeedManifest.fromJson({
      'schema_version': 2,
      'feed_version': '20260805-1',
      'feed_url': 'https://example.test/gtfs-20260805-1.zip',
      'feed_published_at': '2026-08-05T00:00:00+02:00',
      'feed_sha256': 'abc123',
      'feed_size_bytes': 4126,
      'attributes_url': 'https://example.test/attributes-20260805-1.zip',
      'attributes_sha256': 'def456',
      'attributes_size_bytes': 7921,
    });

    expect(manifest.attributesUrl,
        'https://example.test/attributes-20260805-1.zip');
    expect(manifest.attributesSha256, 'def456');
    expect(manifest.attributesSizeBytes, 7921);
  });

  test('FeedManifest.fromJson tollera l\'assenza dei campi attributes_*', () {
    final manifest = FeedManifest.fromJson({
      'schema_version': 2,
      'feed_version': '20260805-1',
      'feed_url': 'https://example.test/gtfs-20260805-1.zip',
      'feed_published_at': '2026-08-05T00:00:00+02:00',
    });

    expect(manifest.attributesUrl, isNull);
    expect(manifest.attributesSha256, isNull);
    expect(manifest.attributesSizeBytes, isNull);
  });
}
