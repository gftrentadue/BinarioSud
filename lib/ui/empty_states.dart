/// Stati non-lista della schermata orari (§4.4): loading, errore dati,
/// nessuna corsa nella fascia. Stati informativi, mai schermate bianche (§4.5).
library;

import 'package:flutter/material.dart';

/// Caricamento iniziale del feed dal bundle.
class LoadingState extends StatelessWidget {
  const LoadingState({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}

/// Errore di lettura/parsing del feed (distinto da "nessuna corsa", CA-6.2).
class FeedErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const FeedErrorState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              'Impossibile leggere gli orari',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'I dati inclusi nell’app non sono leggibili.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Riprova'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Nessuna corsa nella fascia/giorno (UC-06/CA-6.1). Offre l'azione
/// "mostra prima corsa del giorno" quando disponibile.
class NoJourneysState extends StatelessWidget {
  final String message;
  final VoidCallback? onShowFirstOfDay;

  const NoJourneysState({
    super.key,
    required this.message,
    this.onShowFirstOfDay,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.train_outlined,
                size: 48, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              message,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            if (onShowFirstOfDay != null) ...[
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onShowFirstOfDay,
                child: const Text('Mostra prima corsa del giorno'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
