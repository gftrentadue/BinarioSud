/// Pannello "Info dati / versione" (§4.1) — bottom sheet secondario.
///
/// Ospita la versione/validità del feed (RF-08) e lo SPAZIO per l'attribuzione
/// della fonte dati (RF-19): nell'MVP non pubblicato il testo di licenza è
/// ancora da definire (D-02), quindi è predisposto come placeholder.
library;

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/feed_refresh_service.dart';
import '../state/schedule_controller.dart';

void showInfoSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => const _InfoSheetContent(),
  );
}

class _InfoSheetContent extends StatelessWidget {
  const _InfoSheetContent();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Info dati', style: theme.textTheme.titleLarge),
            const SizedBox(height: 16),
            _Row(label: 'Versione dati', value: c.feedVersion),
            if (c.isFeedExpired)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'Orario potenzialmente non aggiornato.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.error,
                  ),
                ),
              ),
            const Divider(height: 32),
            Text('Fonte dati', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            // RF-19: spazio attribuzione fonte (titolare + licenza).
            // Testo definitivo da inserire a licenza nota (D-02).
            Text(
              'Orari teorici trascritti da fonti ufficiali correnti '
              '(Trenitalia, Ferrovie Appulo Lucane). Non in tempo reale.\n'
              'Attribuzione e licenza: da definire prima della pubblicazione.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            if (kDebugMode) ...[
              const Divider(height: 32),
              OutlinedButton(
                onPressed: () => _forceRefresh(context),
                child: const Text('Controlla aggiornamenti ora (debug)'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Hook di sviluppo (RF-07): forza un controllo del manifest bypassando il
  // vincolo "un controllo al giorno", per provare la catena
  // scarica→valida→sostituisce senza aspettare una vera nuova pubblicazione.
  // Non compare in build di release (kDebugMode).
  Future<void> _forceRefresh(BuildContext context) async {
    final controller = context.read<ScheduleController>();
    final messenger = ScaffoldMessenger.of(context);
    final result = await controller.forceRefreshCheck();
    messenger.showSnackBar(SnackBar(content: Text(_outcomeLabel(result))));
  }

  String _outcomeLabel(FeedRefreshResult? result) {
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
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.textTheme.bodyMedium),
          Text(
            value.isEmpty ? '—' : value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
