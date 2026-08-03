# BinarioSud — Contesto progetto per Claude Code

## Cos'è
App mobile **Flutter (MVP target Android)** che mostra gli orari treni della relazione
**Modugno ⇄ Bari** in entrambe le direzioni, **aggregando due operatori** (Trenitalia e
FAL) in un'unica lista. Client sottile che consuma un **feed GTFS statico**; solo orari
teorici, **niente real-time**.

## Documenti di riferimento
- **Specifica funzionale:** `Specifiche_App_Orari_Modugno-Bari_MVP.md` (v1.4) — fonte di
  verità per requisiti (RF-xx), use case (UC-xx) e decisioni (D-xx).
- **Stato di avanzamento:** `STATO_PROGETTO.md` — documento vivo, da consultare a inizio
  sessione e tenere aggiornato (vedi sotto).

## Stato attuale (Fase 1 — bundle-only)
- Il GTFS è incluso nel **bundle** ed è l'**unica fonte**: nessun refresh da rete.
  RF-07 e la logica di refresh §1.4 sono **rinviati alla Fase 2**.
- Feed in bundle: **v2, `feed_version 20260618-6`**, completo da fonti ufficiali
  (99 corse / 198 stop_times), generato da `build_gtfs.py`. Supera il vecchio seed v1.
- Contratto dati esteso: `trip_short_name`, `bikes_allowed`, `wheelchair_accessible`,
  coordinate stop valorizzate, 8 `service_id` namespaced per operatore, motore festività
  nazionali precalcolato in `calendar_dates`, più **file side-car non-GTFS** (attributi treno).

## Due deliverable distinti
1. **App Flutter** (primario) — consuma il GTFS dal bundle.
2. **Pipeline dati** (`build_gtfs.py`) — normalizza le fonti ufficiali in GTFS.
Procedono separati; il punto di contatto è il Contratto Dati (§1 della specifica).

## Fuori ambito MVP
Real-time, acquisto biglietti, account, pagamenti, notifiche, altre tratte, iOS.

## Manutenzione di STATO_PROGETTO.md (IMPORTANTE)
Dopo ogni modifica al codice o alla pipeline, **aggiorna `STATO_PROGETTO.md`**:
- spunta le checklist dei "Prossimi passi" completati;
- aggiorna la matrice RF ↔ stato se è cambiato qualcosa;
- aggiungi una riga datata nel "Log avanzamenti" (cosa è stato fatto, in breve).
Mantieni il file **conciso**: matrice sintetica e log a righe brevi. Non incollare in
chat l'intero contenuto dei file di stato.

## Punti aperti da non trattare come bug
- **D-11**: `end_date` FAL (12/12/2026) è **assunto**, non pubblicato → da riverificare.
- **D-12**: festività **locali/patronali** (Bari/Modugno) non modellate (si assume
  circolazione normale).
- **R-09**: `platform` nei side-car da OCR best-effort, non verificato.
- **D-02**: licenza dati → rilevante solo **prima di una pubblicazione**, non ora.
Già chiusi (non risegnalare come gap): R-03 (coordinate presenti), D-06 (festività
nazionali modellate nel motore festività).