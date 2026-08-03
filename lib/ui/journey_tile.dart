/// Riga corsa nella lista orari (§4.2/§4.5).
///
/// Espone in ordine di lettura: orario di partenza (saliente), arrivo+durata,
/// operatore distinguibile, headsign. La "prossima corsa" è evidenziata (RF-11).
library;

import 'package:flutter/material.dart';

import '../data/gtfs_models.dart';
import '../domain/journey.dart';
import 'journey_detail_sheet.dart';

class JourneyTile extends StatelessWidget {
  final Journey journey;
  final bool isNext;

  const JourneyTile({
    super.key,
    required this.journey,
    this.isNext = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      color: isNext ? scheme.primaryContainer : scheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isNext
            ? BorderSide(color: scheme.primary, width: 1.5)
            : BorderSide.none,
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => showJourneyDetailSheet(context, journey),
        child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Orario di partenza: informazione più saliente.
            // Il badge "PROSSIMA" vive qui (non nel rigo dell'operatore) per
            // non competere in larghezza con nomi operatore lunghi.
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNext) ...[
                  _NextBadge(color: scheme.primary),
                  const SizedBox(height: 2),
                ],
                Text(
                  journey.departureLabel,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'arr. ${journey.arrivalLabel}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            // Durata + operatore + destinazione.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Chip operatore + numero treno (quando presente) allineati a
                  // sinistra; restano entro la larghezza della colonna (Expanded).
                  Row(
                    children: [
                      Flexible(child: _OperatorChip(name: journey.operatorName)),
                      if (journey.trainNumber != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'n. ${journey.trainNumber}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                      if (journey.attributes?.departurePlatform != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          'bin. ${journey.attributes!.departurePlatform}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (journey.headsign != null)
                    Text(
                      'verso ${journey.headsign}',
                      style: theme.textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  if (journey.wheelchair == Availability.yes ||
                      journey.bikes == Availability.yes) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (journey.wheelchair == Availability.yes)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: Icon(Icons.accessible,
                                size: 16, color: scheme.onSurfaceVariant),
                          ),
                        if (journey.bikes == Availability.yes)
                          Icon(Icons.directions_bike,
                              size: 16, color: scheme.onSurfaceVariant),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Durata.
            Row(
              children: [
                Icon(Icons.schedule,
                    size: 16, color: scheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  '${journey.durationMinutes} min',
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

/// Etichetta operatore sempre leggibile (§4.5). Nessun vincolo cromatico
/// imposto dalle specifiche: usiamo un chip neutro con il nome.
class _OperatorChip extends StatelessWidget {
  final String name;
  const _OperatorChip({required this.name});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: scheme.onSecondaryContainer,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _NextBadge extends StatelessWidget {
  final Color color;
  const _NextBadge({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'PROSSIMA',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
