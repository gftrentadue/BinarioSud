/// Schermata orari — hub unico dell'app (§4.1/§4.2).
///
/// Gerarchia dall'alto: selettore direzione → contesto temporale (giorno +
/// fascia oraria + operatore) → lista corse → indicatore freschezza.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/gtfs_models.dart';
import '../state/schedule_controller.dart';
import 'empty_states.dart';
import 'info_sheet.dart';
import 'journey_tile.dart';

class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Orari Modugno ⇄ Bari'),
        actions: [
          // Filtri (operatore, orario, bici, accessibilità): icona con badge
          // del numero di filtri attivi. Disponibile a feed caricato.
          if (c.status == FeedStatus.ready)
            IconButton(
              tooltip: 'Filtri',
              icon: c.activeFilterCount == 0
                  ? const Icon(Icons.tune)
                  : Badge.count(
                      count: c.activeFilterCount,
                      child: const Icon(Icons.tune),
                    ),
              onPressed: () => showFiltersSheet(context),
            ),
          IconButton(
            tooltip: 'Info dati',
            icon: const Icon(Icons.info_outline),
            onPressed: () => showInfoSheet(context),
          ),
        ],
      ),
      body: switch (c.status) {
        FeedStatus.loading => const LoadingState(),
        FeedStatus.error => FeedErrorState(onRetry: c.init),
        FeedStatus.ready => _ReadyBody(c: c),
      },
    );
  }
}

class _ReadyBody extends StatelessWidget {
  final ScheduleController c;
  const _ReadyBody({required this.c});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _DirectionSelector(),
        const _DaySelector(),
        if (c.isFeedExpired) const _ExpiredBanner(),
        if (c.falExcludedByAccessibilityCount > 0)
          _AccessibilityFilterNotice(count: c.falExcludedByAccessibilityCount),
        Expanded(child: _JourneyList(c: c)),
        _FreshnessFooter(version: c.feedVersion),
      ],
    );
  }
}

/// RF-02 — selettore direzione, comando primario sempre visibile.
class _DirectionSelector extends StatelessWidget {
  const _DirectionSelector();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Center(
        child: SegmentedButton<Direction>(
          segments: const [
            ButtonSegment(
              value: Direction.versoModugno,
              label: Text('verso Modugno'),
              icon: Icon(Icons.west),
            ),
            ButtonSegment(
              value: Direction.versoBari,
              label: Text('verso Bari'),
              icon: Icon(Icons.east),
            ),
          ],
          selected: {c.direction},
          onSelectionChanged: (s) => c.setDirection(s.first),
        ),
      ),
    );
  }
}

/// RF-10 — selettore giorno: Oggi / Domani / scelta data.
class _DaySelector extends StatelessWidget {
  const _DaySelector();

  @override
  Widget build(BuildContext context) {
    final c = context.watch<ScheduleController>();
    // "Oggi" dal clock del controller (now iniettabile), non da DateTime.now().
    final today = c.today;
    final tomorrow = today.add(const Duration(days: 1));
    final fmt = DateFormat('EEE d MMM', 'it');

    final isToday = c.isToday;
    final isTomorrow = c.selectedDay == tomorrow;
    final isOther = !isToday && !isTomorrow;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ChoiceChip(
            label: const Text('Oggi'),
            selected: isToday,
            onSelected: (_) => c.setSelectedDay(today),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Domani'),
            selected: isTomorrow,
            onSelected: (_) => c.setSelectedDay(tomorrow),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            avatar: const Icon(Icons.calendar_today, size: 16),
            label: Text(isOther ? fmt.format(c.selectedDay) : 'Data'),
            selected: isOther,
            onSelected: (_) async {
              final picked = await showDatePicker(
                context: context,
                initialDate: c.selectedDay,
                firstDate: DateTime(today.year - 1),
                lastDate: DateTime(today.year + 1),
              );
              if (picked != null) c.setSelectedDay(picked);
            },
          ),
        ],
      ),
    );
  }
}

/// Apre il pannello filtri come bottom sheet modale (Opzione A).
Future<void> showFiltersSheet(BuildContext context) {
  final c = context.read<ScheduleController>();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => _FiltersSheet(controller: c),
  );
}

/// RF-12 operatore · RF-04 orario · RF-20 bici · RF-21 accessibilità.
/// Applica **live**: ogni cambiamento aggiorna subito la lista sottostante e
/// il conteggio "Mostra N corse" in fondo al pannello.
class _FiltersSheet extends StatelessWidget {
  final ScheduleController controller;
  const _FiltersSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // ListenableBuilder: il bottom sheet vive in un context separato dalla
    // schermata, quindi ci agganciamo direttamente al controller per il "live".
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final c = controller;
        final count = c.visibleJourneys.length;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text('Filtri', style: theme.textTheme.titleLarge),
                    const Spacer(),
                    TextButton(
                      onPressed:
                          c.activeFilterCount == 0 ? null : c.resetFilters,
                      child: const Text('Azzera'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _FilterSectionLabel('Operatore'),
                SegmentedButton<OperatorFilter>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                        value: OperatorFilter.tutti, label: Text('Tutti')),
                    ButtonSegment(
                        value: OperatorFilter.trenitalia, label: Text('TI')),
                    ButtonSegment(
                        value: OperatorFilter.fal, label: Text('FAL')),
                  ],
                  selected: {c.operatorFilter},
                  onSelectionChanged: (s) => c.setOperatorFilter(s.first),
                ),
                const SizedBox(height: 16),
                _FilterSectionLabel('A partire dalle'),
                Wrap(
                  spacing: 8,
                  children: [
                    ChoiceChip(
                      label: const Text('Da adesso'),
                      selected: c.fromTimeOverride == null,
                      onSelected: (_) => c.setFromTime(null),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(c.fromTimeOverride == null
                          ? 'Scegli orario'
                          : _fmtSeconds(c.fromTimeOverride!)),
                      onPressed: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (picked != null) {
                          c.setFromTime(picked.hour * 3600 + picked.minute * 60);
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _FilterSectionLabel('Servizi a bordo'),
                Wrap(
                  spacing: 8,
                  children: [
                    // RF-20 — solo corse con trasporto bici.
                    FilterChip(
                      avatar: const Icon(Icons.directions_bike, size: 18),
                      label: const Text('Bici'),
                      selected: c.onlyBikes,
                      onSelected: c.setOnlyBikes,
                    ),
                    // RF-21 — solo corse accessibili (preferenza persistente).
                    FilterChip(
                      avatar: const Icon(Icons.accessible, size: 18),
                      label: const Text('Accessibile'),
                      selected: c.onlyAccessible,
                      onSelected: c.setOnlyAccessible,
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(count == 0
                        ? 'Nessuna corsa'
                        : 'Mostra $count cors${count == 1 ? 'a' : 'e'}'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FilterSectionLabel extends StatelessWidget {
  final String text;
  const _FilterSectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: theme.textTheme.labelMedium
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
    );
  }
}

/// Formatta secondi-dalla-mezzanotte come `HH:MM`.
String _fmtSeconds(int secondsFromMidnight) {
  final m = secondsFromMidnight ~/ 60;
  return '${(m ~/ 60).toString().padLeft(2, '0')}:'
      '${(m % 60).toString().padLeft(2, '0')}';
}

class _JourneyList extends StatelessWidget {
  final ScheduleController c;
  const _JourneyList({required this.c});

  @override
  Widget build(BuildContext context) {
    final journeys = c.visibleJourneys;

    if (journeys.isEmpty) {
      final dayLabel = c.isToday
          ? 'oggi'
          : DateFormat('d MMM', 'it').format(c.selectedDay);
      // Distinzione UC-06: filtro orario vs giorno proprio senza corse.
      if (c.hasJourneysIgnoringTime) {
        return NoJourneysState(
          message: 'Nessuna corsa $dayLabel dopo l’orario selezionato.',
          onShowFirstOfDay: () => c.setFromTime(0),
        );
      }
      return NoJourneysState(
        message: 'Nessuna corsa $dayLabel in questa direzione.',
      );
    }

    final nextId = c.nextJourneyTripId;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: journeys.length,
      itemBuilder: (_, i) {
        final j = journeys[i];
        return JourneyTile(journey: j, isNext: j.tripId == nextId);
      },
    );
  }
}

/// RF-13 / CA-5.1 — banner non bloccante quando il feed è oltre validità.
class _ExpiredBanner extends StatelessWidget {
  const _ExpiredBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Orario potenzialmente non aggiornato.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// RF-21 / R-10 — quando il filtro "Accessibile" è attivo e nasconde corse
/// FAL, lo segnala esplicitamente: l'accessibilità FAL è un dato **assunto**
/// (non verificato), quindi le corse non vanno escluse silenziosamente.
class _AccessibilityFilterNotice extends StatelessWidget {
  final int count;
  const _AccessibilityFilterNotice({required this.count});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cors = count == 1 ? 'corsa FAL esclusa' : 'corse FAL escluse';
    return Container(
      width: double.infinity,
      color: scheme.surfaceContainerHighest,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '$count $cors: accessibilità non verificata, da confermare con l’operatore.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

/// RF-08 — indicatore di freschezza dati (discreto, in coda).
class _FreshnessFooter extends StatelessWidget {
  final String version;
  const _FreshnessFooter({required this.version});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        child: Text(
          'Dati versione $version · orari teorici',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
