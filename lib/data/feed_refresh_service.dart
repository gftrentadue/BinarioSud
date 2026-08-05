/// Refresh giornaliero del feed da rete (RF-07, logica pseudo-codificata §1.4).
///
/// Orchestratore: legge lo stato persistito, decide se contattare la rete
/// oggi, confronta la versione col manifest, scarica e sostituisce
/// atomicamente la cache solo se il download è valido. Non tocca mai la
/// cache esistente in caso di errore (invariante "l'app è sempre utilizzabile
/// finché esiste un feed in cache valido").
library;

import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'csv_parser.dart';
import 'feed_manifest.dart';
import 'settings_store.dart';

/// URL stabile della Release "latest" (alias nativo GitHub, D-08).
const _defaultManifestUrl =
    'https://github.com/gftrentadue/BinarioSudPipeline/releases/latest/download/manifest.json';

/// Esito di un tentativo di controllo/aggiornamento (§1.4).
enum RefreshOutcome {
  /// `last_check_date == oggi`: nessun contatto di rete (un controllo/giorno).
  skippedAlreadyCheckedToday,

  /// Manifest irraggiungibile o illeggibile: si continua offline con la cache.
  networkError,

  /// `schema_version` del manifest non supportata: invito ad aggiornare l'app.
  unsupportedSchema,

  /// Stessa `feed_version` già in cache: nessun download necessario.
  upToDate,

  /// Nuova `feed_version` scaricata, validata e messa in cache atomicamente.
  updated,

  /// Download, verifica integrità o validazione struttura falliti: cache
  /// precedente intatta.
  downloadFailed,
}

class FeedRefreshResult {
  final RefreshOutcome outcome;
  final String? newFeedVersion;

  const FeedRefreshResult(this.outcome, {this.newFeedVersion});
}

/// Etichetta utente per l'esito di un controllo/aggiornamento, condivisa tra
/// l'hook di debug (Info) e il pull-to-refresh manuale (RF-14).
String refreshOutcomeLabel(FeedRefreshResult? result) {
  if (result == null) return 'Refresh non configurato';
  switch (result.outcome) {
    case RefreshOutcome.skippedAlreadyCheckedToday:
      return 'Già controllato oggi';
    case RefreshOutcome.networkError:
      return 'Rete non raggiungibile o manifest illeggibile';
    case RefreshOutcome.unsupportedSchema:
      return 'Manifest con schema non supportato: aggiornare l\'app';
    case RefreshOutcome.upToDate:
      return 'Già aggiornato (nessuna nuova versione)';
    case RefreshOutcome.updated:
      return 'Aggiornato a ${result.newFeedVersion}';
    case RefreshOutcome.downloadFailed:
      return 'Download o validazione falliti: feed precedente mantenuto';
  }
}

class FeedRefreshService {
  static const supportedSchemaVersion = 2;

  final http.Client _client;
  final SettingsStore _settingsStore;
  final DateTime Function() _now;
  final Future<Directory> Function() _cacheRootProvider;
  final Uri manifestUrl;

  FeedRefreshService({
    required SettingsStore settingsStore,
    http.Client? client,
    DateTime Function()? now,
    Future<Directory> Function()? cacheRootProvider,
    Uri? manifestUrl,
  })  : _settingsStore = settingsStore,
        _client = client ?? http.Client(),
        _now = now ?? DateTime.now,
        _cacheRootProvider = cacheRootProvider ?? getApplicationSupportDirectory,
        manifestUrl = manifestUrl ?? Uri.parse(_defaultManifestUrl);

  Future<Directory> get _cacheDir async =>
      Directory('${(await _cacheRootProvider()).path}/gtfs_cache');

  Future<Directory> get _tmpDir async =>
      Directory('${(await _cacheRootProvider()).path}/gtfs_cache_tmp');

  /// Cartella cache valida esistente su disco, o `null` se assente (mai
  /// scaricato nulla). Usata al 1° avvio per scegliere bundle vs cache.
  Future<Directory?> cachedFeedDirectory() async {
    final dir = await _cacheDir;
    final feedInfo = File('${dir.path}/gtfs/feed_info.txt');
    return feedInfo.existsSync() ? dir : null;
  }

  /// Registra la versione correntemente attiva (bundle o cache) come
  /// baseline di confronto, solo se non è già nota: al primissimo avvio non
  /// è mai stato scaricato nulla dalla rete, quindi il termine di paragone
  /// per "nuova versione disponibile" è quello che l'app sta già mostrando.
  Future<void> ensureBaseline(String currentFeedVersion) async {
    final existing = await _settingsStore.loadCachedFeedVersion();
    if (existing == null) {
      await _settingsStore.saveCachedFeedVersion(currentFeedVersion);
    }
  }

  /// Esegue un controllo (e se serve un aggiornamento) secondo §1.4.
  /// `force=true` bypassa il vincolo "un controllo al giorno" (hook di
  /// debug/RF-14 futura).
  Future<FeedRefreshResult> checkForUpdate({bool force = false}) async {
    final now = _now();
    if (!force) {
      final lastCheck = await _settingsStore.loadLastCheckDate();
      if (lastCheck != null && _isSameDay(lastCheck, now)) {
        return const FeedRefreshResult(
            RefreshOutcome.skippedAlreadyCheckedToday);
      }
    }

    final FeedManifest manifest;
    try {
      final response = await _client
          .get(manifestUrl)
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        return const FeedRefreshResult(RefreshOutcome.networkError);
      }
      manifest =
          FeedManifest.fromJson(jsonDecode(response.body) as Map<String, dynamic>);
    } catch (_) {
      // Rete irraggiungibile o manifest illeggibile: si riprova al prossimo
      // avvio, `last_check_date` resta invariato (CA-4.2).
      return const FeedRefreshResult(RefreshOutcome.networkError);
    }

    if (manifest.schemaVersion != supportedSchemaVersion) {
      await _settingsStore.saveLastCheckDate(now);
      return const FeedRefreshResult(RefreshOutcome.unsupportedSchema);
    }

    final cachedVersion = await _settingsStore.loadCachedFeedVersion();
    if (cachedVersion == manifest.feedVersion) {
      await _settingsStore.saveLastCheckDate(now);
      return FeedRefreshResult(RefreshOutcome.upToDate,
          newFeedVersion: manifest.feedVersion);
    }

    final ok = await _downloadAndSwap(manifest);
    if (!ok) {
      // Download/validazione falliti: cache precedente intatta,
      // `last_check_date` non aggiornato così si riprova (CA-7.1).
      return const FeedRefreshResult(RefreshOutcome.downloadFailed);
    }

    await _settingsStore.saveCachedFeedVersion(manifest.feedVersion);
    await _settingsStore.saveLastCheckDate(now);
    return FeedRefreshResult(RefreshOutcome.updated,
        newFeedVersion: manifest.feedVersion);
  }

  /// Scarica lo zip GTFS (e, se pubblicato, lo zip attributi), verifica gli
  /// hash (se presenti), li decomprime in una cartella temporanea comune,
  /// valida la struttura minima del GTFS e sostituisce atomicamente la
  /// cache. Ritorna `false` senza toccare la cache esistente se un passaggio
  /// qualsiasi fallisce; lo swap copre GTFS e attributi insieme, in un solo
  /// `rename` finale, così non possono restare disallineati.
  Future<bool> _downloadAndSwap(FeedManifest manifest) async {
    final List<int> bytes;
    try {
      final response = await _client
          .get(Uri.parse(manifest.feedUrl))
          .timeout(const Duration(seconds: 30));
      if (response.statusCode != 200) return false;
      bytes = response.bodyBytes;
    } catch (_) {
      return false;
    }

    final expectedSha = manifest.feedSha256;
    if (expectedSha != null && expectedSha.isNotEmpty) {
      final actual = sha256.convert(bytes).toString();
      if (actual.toLowerCase() != expectedSha.toLowerCase()) return false;
    }

    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return false;
    }

    // Side-car attributi estesi (schema_version 2): opzionali nel manifest,
    // ma se annunciati devono scaricare e validare correttamente, altrimenti
    // l'intero aggiornamento fallisce (non si sostituisce solo il GTFS
    // lasciando gli attributi disallineati).
    Archive? attributesArchive;
    final attributesUrl = manifest.attributesUrl;
    if (attributesUrl != null && attributesUrl.isNotEmpty) {
      final List<int> attributesBytes;
      try {
        final response = await _client
            .get(Uri.parse(attributesUrl))
            .timeout(const Duration(seconds: 30));
        if (response.statusCode != 200) return false;
        attributesBytes = response.bodyBytes;
      } catch (_) {
        return false;
      }

      final expectedAttributesSha = manifest.attributesSha256;
      if (expectedAttributesSha != null && expectedAttributesSha.isNotEmpty) {
        final actual = sha256.convert(attributesBytes).toString();
        if (actual.toLowerCase() != expectedAttributesSha.toLowerCase()) {
          return false;
        }
      }

      try {
        attributesArchive = ZipDecoder().decodeBytes(attributesBytes);
      } catch (_) {
        return false;
      }
    }

    final tmp = await _tmpDir;
    try {
      if (tmp.existsSync()) {
        await tmp.delete(recursive: true);
      }
      final tmpGtfs = Directory('${tmp.path}/gtfs');
      await tmpGtfs.create(recursive: true);
      for (final file in archive) {
        if (!file.isFile || !file.name.endsWith('.txt')) continue;
        final out = File('${tmpGtfs.path}/${file.name}');
        await out.writeAsBytes(file.content as List<int>);
      }

      // Validazione struttura minima (CA-7.1): feed_info.txt parsabile e
      // feed_version coerente col manifest, prima di sostituire la cache.
      final feedInfoFile = File('${tmpGtfs.path}/feed_info.txt');
      if (!feedInfoFile.existsSync()) return false;
      final rows = parseCsv(await feedInfoFile.readAsString());
      final parsedVersion = rows.isNotEmpty ? rows.first['feed_version'] : null;
      if (parsedVersion != manifest.feedVersion) return false;

      if (attributesArchive != null) {
        final tmpAttributes = Directory('${tmp.path}/attributes');
        await tmpAttributes.create(recursive: true);
        for (final file in attributesArchive) {
          if (!file.isFile || !file.name.endsWith('.json')) continue;
          final out = File('${tmpAttributes.path}/${file.name}');
          await out.writeAsBytes(file.content as List<int>);
        }
      }

      final cache = await _cacheDir;
      if (cache.existsSync()) {
        await cache.delete(recursive: true);
      }
      await tmp.rename(cache.path);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (tmp.existsSync()) {
        try {
          await tmp.delete(recursive: true);
        } catch (_) {
          // Best-effort: la cache resta comunque coerente (o quella
          // precedente, o quella nuova già spostata da `rename`).
        }
      }
    }
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}
