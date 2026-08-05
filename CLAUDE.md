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

## Stato attuale (Fase 2 — refresh da rete attivo)
- Dal 05/08/2026 l'app implementa **RF-07**: un controllo giornaliero del manifest
  pubblicato dalla pipeline (§1.4), con download condizionale, verifica integrità e
  sostituzione atomica della cache locale. Il GTFS nel **bundle** resta il fallback per
  il primo avvio e per quando la cache non è (ancora) disponibile (D-07); a runtime la
  tabella GTFS può quindi venire dal bundle o dalla cache scaricata, stesso parser
  (`GtfsRepository.withCacheDir`). Funzionamento sempre **offline-first**: senza rete
  l'app resta pienamente utilizzabile sull'ultimo feed disponibile.
- Feed in bundle: **v2, `feed_version 20260618-7`** (patch accessibilità FAL su
  `20260618-6`), completo da fonti ufficiali (99 corse / 198 stop_times), generato da
  `build_gtfs.py`. Supera il vecchio seed v1.
- Contratto dati esteso: `trip_short_name`, `bikes_allowed`, `wheelchair_accessible`,
  coordinate stop valorizzate, 8 `service_id` namespaced per operatore, motore festività
  nazionali precalcolato in `calendar_dates`, più **file side-car non-GTFS** (attributi treno).

## Due deliverable distinti
1. **App Flutter** (primario) — consuma il GTFS dal bundle (fallback/primo avvio) o
   dalla cache scaricata via RF-07.
2. **Pipeline dati** (`build_gtfs.py`, repo separato `BinarioSudPipeline`) — normalizza le
   fonti ufficiali in GTFS e pubblica `gtfs-<feed_version>.zip` + `manifest.json` su GitHub
   Release (D-08).
Procedono separati; il punto di contatto è il Contratto Dati (§1 della specifica). Nota: lo
zip pubblicato dalla pipeline contiene solo gli 8 `.txt` GTFS, **non** i side-car
`assets/attributes/*.json` — questi restano sempre letti dal bundle dell'app (aggiornano solo
con una nuova versione dell'app, non col refresh RF-07); vedi "Punti aperti" sotto.

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
- **D-02**: licenza dati → rilevante solo **prima di una pubblicazione**, non ora.
- **Side-car non pubblicati dalla pipeline**: lo zip Fase 2 non include gli attributi
  estesi (categoria, binario, fermate intermedie, RF-16/RF-21) → restano sempre letti dal
  bundle. Limite noto del deliverable pipeline, non un bug dell'app; eventuale
  allineamento è un task futuro separato su `BinarioSudPipeline`.
Già chiusi (non risegnalare come gap): R-03 (coordinate presenti), D-06 (festività
nazionali modellate nel motore festività), D-11 (`end_date` FAL: assunzione motivata,
nessuna scadenza pubblicata da FAL), D-12 (festività locali/patronali: committente
conferma nessuna modellazione), D-13 (accessibilità FAL verificata), R-09 (binario
Bari Centrale da OCR: limite noto, testo UI aggiornato).