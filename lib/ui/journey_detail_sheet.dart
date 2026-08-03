/// Dettaglio corsa — bottom sheet aperto al tap su una [JourneyTile].
///
/// Mostra il riepilogo orario e, quando disponibili, gli attributi estesi
/// non-GTFS (categoria, binario, fermata intermedia, prenotazione, garanzia
/// sciopero, nota di circolazione) — presenti sia per TI sia per FAL.
library;

import 'package:flutter/material.dart';

import '../data/gtfs_models.dart';
import '../domain/journey.dart';

void showJourneyDetailSheet(BuildContext context, Journey journey) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _JourneyDetailContent(journey: journey),
  );
}

class _JourneyDetailContent extends StatelessWidget {
  final Journey journey;
  const _JourneyDetailContent({required this.journey});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final attr = journey.attributes;

    final title = journey.headsign != null
        ? 'verso ${journey.headsign}'
        : '${journey.originStopName} → ${journey.destinationStopName}';

    return SafeArea(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(
                '${journey.operatorName}'
                '${journey.trainNumber != null ? ' · treno ${journey.trainNumber}' : ''}'
                '${attr != null && attr.categoryLabel.isNotEmpty ? ' · ${attr.categoryLabel}' : ''}',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),

              // Riepilogo orario (sempre presente).
              _Row(
                label: 'Partenza',
                value: '${journey.departureLabel} · ${journey.originStopName}',
              ),
              _Row(
                label: 'Arrivo',
                value: '${journey.arrivalLabel} · ${journey.destinationStopName}',
              ),
              _Row(label: 'Durata', value: '${journey.durationMinutes} min'),

              if (attr?.departurePlatform != null) ...[
                _Row(label: 'Binario', value: attr!.departurePlatform!),
                if (!attr.platformVerified) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Indicativo: da verificare in stazione, può variare '
                    'per esigenze operative.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],

              if (attr != null && attr.intermediateStops.isNotEmpty) ...[
                const Divider(height: 32),
                Text('Fermate intermedie', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                for (final s in attr.intermediateStops)
                  _Row(label: s.name, value: s.departure),
              ],

              // Servizi a bordo / informazioni (chip).
              if (_hasBadges(journey)) ...[
                const Divider(height: 32),
                Text('Servizi e informazioni',
                    style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    // Accessibilità: 3 stati. Il `no` (FAL) è verificato
                    // (D-13, fonte FAL 2024): pedana disponibile ma
                    // condizionata a tipologia carrozzina e preavviso, mai
                    // presentato come "non accessibile" confermato. "ignoto"
                    // omesso.
                    if (journey.wheelchair == Availability.yes)
                      const _Badge(icon: Icons.accessible, label: 'Accessibile'),
                    if (journey.wheelchair == Availability.no)
                      const _Badge(
                          icon: Icons.help_outline,
                          label: 'Accessibile su richiesta',
                          negative: true),
                    if (journey.bikes == Availability.yes)
                      const _Badge(
                          icon: Icons.directions_bike, label: 'Bici a bordo'),
                    if (journey.bikes == Availability.no)
                      const _Badge(
                          icon: Icons.directions_bike,
                          label: 'Bici non ammesse',
                          negative: true),
                    if (attr?.reservationRequired == true)
                      const _Badge(
                          icon: Icons.event_seat, label: 'Prenotazione obbligatoria'),
                    if (attr?.strikeGuaranteed == true)
                      const _Badge(
                          icon: Icons.verified, label: 'Garantito in sciopero'),
                  ],
                ),
                if (journey.wheelchair == Availability.no) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Assistenza con pedana su richiesta (preavviso di almeno 24h), '
                    'disponibile solo per alcune tipologie di carrozzina: '
                    'verificare la compatibilità contattando la stazione.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],

              if (attr?.note != null) ...[
                const SizedBox(height: 16),
                Text(
                  attr!.note!,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  static bool _hasBadges(Journey j) =>
      j.wheelchair != Availability.unknown ||
      j.bikes != Availability.unknown ||
      j.attributes?.reservationRequired == true ||
      j.attributes?.strikeGuaranteed == true;
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                )),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 3,
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String label;

  /// Stato "no" esplicito (es. non accessibile): resa attenuata, non allarmante.
  final bool negative;
  const _Badge({required this.icon, required this.label, this.negative = false});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = negative ? scheme.surfaceContainerHighest : scheme.secondaryContainer;
    final fg = negative ? scheme.onSurfaceVariant : scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Text(label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: fg,
                  )),
        ],
      ),
    );
  }
}
