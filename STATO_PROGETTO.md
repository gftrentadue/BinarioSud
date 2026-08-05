# STATO PROGETTO — BinarioSud (App Orari Modugno ⇄ Bari)

> File di stato persistente, da aggiornare a ogni sessione: spunta le caselle completate
> e aggiungi una riga datata nel **Log avanzamenti**. Mantienilo conciso.

## Obiettivo finale dell'MVP
App Flutter (target Android) che mostra in un'unica lista gli orari teorici dei treni della
relazione **Modugno ⇄ Bari**, aggregando i due operatori **Trenitalia** e **FAL**, consumando
un feed **GTFS statico**. Il GTFS è incluso negli asset dell'app come fallback/primo avvio
(D-07); dal 05/08/2026 l'app implementa anche **RF-07** (Fase 2): un controllo giornaliero
del manifest pubblicato dalla pipeline, con download condizionale e sostituzione atomica
della cache locale, secondo la logica §1.4. Funzionamento sempre **offline-first**: senza
rete l'app resta pienamente utilizzabile sull'ultimo feed disponibile (bundle o cache).
Fuori ambito: real-time, biglietti, account, altre tratte, iOS.

## Feed in bundle attualmente in uso
- **feed_version:** `20260618-7` (v2, completo da fonti ufficiali; patch accessibilità FAL su `20260618-6`) — supera il seed v1 `20260612-1`.
- **Volume:** 99 trips · 198 stop_times · 56 eccezioni in `calendar_dates` · 8 `service_id` namespaced.
- **Finestre validità:** FAL `20251027→20261212` (end **assunto**, D-11) · TI `20260614→20261212`.
- **Estensioni v2:** coordinate stop valorizzate · `bikes_allowed=1` (tutte) · `wheelchair_accessible` (TI=`1`=sì, **FAL=`2`=no** assunto, D-13) · `trip_short_name` (TI + FAL 129/116). Campi a **3 stati** GTFS (`0`=ignoto/`1`=sì/`2`=no), **non** booleani.
- **Asset:** 8 `.txt` in `assets/gtfs/` + side-car `assets/attributes/{ti,fal}_*_attributes.json` (4 file `.json`, no `.csv`).

## Note di contesto
- `build_gtfs.py` **non presente** nel progetto app: vive nel repo pipeline separato
  **`BinarioSudPipeline`** (github.com/gftrentadue/BinarioSudPipeline, pubblico), versionato
  a partire dal 04/08/2026.
- Side-car presenti solo in formato `.json` (la spec menziona anche `.csv`, assente — non bloccante).

## Matrice RF ↔ Stato (Fase 1)

| RF | Titolo | MoSCoW | Stato | Riferimento codice |
|---|---|---|---|---|
| RF-01 | Lista unica corse aggregate TI+FAL | MUST | ✅ IMPLEMENTATO | `domain/journey_builder.dart` (fonde trip+stop_times, sort per partenza) |
| RF-02 | Selezione direzione | MUST | ✅ IMPLEMENTATO | `ui/schedule_screen.dart` `_DirectionSelector`; `schedule_controller.setDirection` |
| RF-03 | Operatore, origine/dest, partenza/arrivo, durata | MUST | ✅ IMPLEMENTATO | `domain/journey.dart` (`durationMinutes`); `ui/journey_tile.dart` |
| RF-04 | Filtro/ordine fascia oraria (default "da adesso") | MUST | ✅ IMPLEMENTATO | `schedule_controller.effectiveFromTime`/`setFromTime`; TimePicker nel pannello `_FiltersSheet` (sezione "A partire dalle") |
| RF-05 | Validità per giorno (calendar + calendar_dates) | MUST | ✅ IMPLEMENTATO | `domain/service_calendar.dart` (`isServiceActive`, gestione exception 1/2) |
| RF-06 | Funzionamento offline | MUST | ✅ IMPLEMENTATO | `data/gtfs_repository.dart` (rootBundle); nessuna dip. di rete in `pubspec.yaml` |
| RF-07 | Refresh giornaliero (logica §1.4) | MUST | ✅ IMPLEMENTATO (Fase 2) | `data/feed_refresh_service.dart` (`FeedRefreshService.checkForUpdate`); hot-swap in `state/schedule_controller.dart` (`_backgroundRefresh`/`forceRefreshCheck`) |
| RF-08 | Data/versione dati in uso | MUST | ✅ IMPLEMENTATO | `_FreshnessFooter` + `info_sheet.dart`; `controller.feedVersion` |
| RF-09 | Stati limite | MUST | ✅ IMPLEMENTATO (per Fase 1) | `ui/empty_states.dart` (loading/error/no-journey); casi rete sono Fase 2 |
| RF-10 | Selezione giorno diverso da oggi | MUST | ✅ IMPLEMENTATO | `_DaySelector` Oggi/Domani/DatePicker; `setSelectedDay` |
| RF-11 | Evidenzia prossima corsa | SHOULD | ✅ IMPLEMENTATO | `controller.nextJourneyTripId`; `JourneyTile isNext` |
| RF-12 | Filtro operatore | SHOULD | ✅ IMPLEMENTATO | `OperatorFilter` segmented nel pannello `_FiltersSheet` |
| RF-13 | Indicatore feed oltre `feed_valid_to` | SHOULD | ✅ IMPLEMENTATO | `controller.isFeedExpired` + banner in `schedule_screen` |
| RF-19 | Attribuzione fonte + licenza | SHOULD→MUST a pubbl. | 🟡 PARZIALE (corretto per MVP) | `info_sheet.dart`: spazio predisposto, testo placeholder (D-02) |
| RF-14 | Pull-to-refresh manuale | COULD | ✅ IMPLEMENTATO | `ui/schedule_screen.dart` (`RefreshIndicator` su `_JourneyList` → `_pullToRefresh` → `controller.forceRefreshCheck()`, esito in SnackBar) |
| RF-15 | Scorciatoia "inverti direzione" | COULD | ⏭️ NON IMPLEMENTATO (scelta UX) | `controller.toggleDirection` resta disponibile ma **nessuna UI**: con sole 2 opzioni già direttamente selezionabili nel segmented, lo swap è ridondante |
| RF-16 | Fermate intermedie | COULD | ✅ IMPLEMENTATO | `journey_detail_sheet.dart` mostra `attributes.intermediateStops` (side-car) **per TI e FAL** (FAL: Bari Scalo / Bari Policlinico) |
| RF-20 | Filtro "trasporto bici" | COULD | ✅ IMPLEMENTATO | `FilterChip` "Bici" nel pannello `_FiltersSheet` → `setOnlyBikes`; predicato in `_matchesNonTimeFilters`. NB: coi dati attuali (`bikes_allowed=1` su tutte le corse) il filtro non riduce la lista |
| RF-21 | Filtro/indicatore accessibilità | COULD | ✅ IMPLEMENTATO | `FilterChip` "Accessibile" nel pannello → `setOnlyAccessible` (tiene `wheelchair=yes`), **preferenza persistente** tra sessioni (`SettingsStore`); indicatore a 3 stati nel dettaglio: FAL=`2` mostrato come **"Accessibile su richiesta"** + didascalia esplicativa (pedana condizionata, preavviso 24h, verificare compatibilità carrozzina) — dato **verificato**, D-13 chiusa (R-10/A-10). Il filtro "Accessibile" **non esclude silenziosamente** le FAL: nota in schermata col conteggio escluse (`falExcludedByAccessibilityCount` + `_AccessibilityFilterNotice`, testo aggiornato) |
| RF-22 | Numero treno (`trip_short_name`) | COULD | ✅ IMPLEMENTATO | `journey_tile` ("n. X") e `journey_detail_sheet` ("treno X") |

**Campi estesi v2 nel parser:** `bikes_allowed`/`wheelchair_accessible` modellati come enum **`Availability`**
(3 stati: `unknown`/`yes`/`no`) in `data/gtfs_models.dart` (`Trip`) e propagati in `Journey`;
`trip_short_name` come `shortName`. Side-car non-GTFS (categoria, binario, fermata intermedia,
prenotazione, garanzia sciopero, nota) in `data/attributes_parser.dart` → `GtfsFeed.attributesByTrip`,
mostrati nello sheet di dettaglio (tap su corsa). Coordinate stop in `Stop.lat/lon`
ma **non ancora usate in UI** (nessuna mappa: fuori MVP).

**Architettura filtri (UI):** in schermata restano solo **direzione** (`_DirectionSelector`)
e **giorno** (`_DaySelector`, 3 chip centrate). Operatore, orario, bici e accessibilità sono
in un **bottom sheet** (`_FiltersSheet`, Opzione A) aperto da un'**azione nell'AppBar** (icona
`tune` con **badge** del numero di filtri attivi, `controller.activeFilterCount`); applica **live**
(`ListenableBuilder` + footer "Mostra N corse") e ha "Azzera" (`controller.resetFilters`). Persistenza preferenze in
`data/settings_store.dart` (`SettingsStore` + impl `shared_preferences`), iniettata in `main.dart`;
oggi persiste solo l'accessibilità (RF-21). NB: `shared_preferences` è storage **locale**, non
intacca il requisito offline (RF-06).

## Prossimi passi

> Piano prioritizzato aggiornato il 03/08/2026 (vedi Log avanzamenti). P1 e P2 non
> hanno dipendenze tra loro e possono procedere in parallelo; P3 ha una scadenza nota;
> P4 parte solo quando si decide di avviare la Fase 2.

- [x] **RF-20** Filtro "solo corse con bici" (`FilterChip` in `_FilterBar` + predicato `_matchesNonTimeFilters`). NB: no-op coi dati attuali (`bikes_allowed=1` ovunque).
- [x] **RF-21** Filtro accessibilità (`FilterChip` "Accessibile", tiene `wheelchair=yes`).
- [x] **RF-15** Chiuso come **non implementato per scelta UX**: con sole 2 direzioni già selezionabili direttamente, lo swap è ridondante. `toggleDirection` resta nel controller per eventuale riuso.
- [x] **Qualità** Copertura test estesa ai filtri (controller: bici/accessibilità/`activeFilterCount`/`resetFilters`/persistenza) e nuovo `schedule_screen_test.dart` (struttura Opzione A, apertura pannello, badge). **43 test totali** (aggiornato dopo l'estensione side-car FAL del 25/06). NB: l'anti-overflow di layout **non** è coperto da widget test (font di test gonfia i testi → falsi overflow); verifica a mano sul device → vedi P1.
- [x] **Igiene repo** Git inizializzato e progetto versionato (branch `master`, 3 commit). `.gitignore` adeguato a VS Code (versionati `launch.json`/`tasks.json`, ignorati file macchina-specifici); `.claude/settings.local.json` rimosso dal tracking e ignorato. Branch principale `master` (anche `init.defaultBranch` globale = `master`). _Aperto:_ nessun remote configurato → vedi P1.

### P1 — Chiusura Fase 1 (basso sforzo, nessuna dipendenza)
- [x] Verifica manuale anti-overflow su device reale (layout non coperto da widget test).
- [x] Configurare un remote Git (GitHub) — già presente (`origin` → `github.com/gftrentadue/binario_sud.git`); il documento risultava disallineato, ora corretto.
- [x] CI minima (GitHub Actions): `.github/workflows/ci.yml`, `flutter analyze` + `flutter test` su push/PR verso `master`/`develop`.

### P2 — Verifiche dati in sospeso — **CHIUSO** (03/08/2026)
- [x] **D-13** accessibilità FAL — chiusa (03/08/2026): dato verificato (fermata Modugno "con pedana", condizionata) + decisione di modellazione presa (GTFS invariato, testo UI aggiornato in `journey_detail_sheet.dart`/`schedule_screen.dart`).
- [x] **D-11** `end_date` FAL assunto — chiusa (03/08/2026) con nota motivata: nessuna scadenza pubblicata da FAL (verificato sul sito ufficiale), assunzione ritenuta ragionevole (coerente col cambio orario nazionale del 13/12/2026 e con la finestra TI); nessuna modifica ai dati.
- [x] **R-09** `platform_bari_centrale` da OCR — chiusa (03/08/2026) come limite noto accettato: nessuna fonte esterna disponibile per un controllo puntuale; testo UI aggiornato per chiarire che il binario da Bari Centrale è indicativo e soggetto a variazione operativa (il binario da Modugno resta mostrato senza avviso, essendo dichiarato con certezza dalla fonte).
- [x] **D-12** festività locali/patronali — chiusa (03/08/2026): committente conferma l'assunzione attuale (circolazione normale, nessuna modellazione).

### P3 — Cambio orario 12/12/2026 (scadenza nota: sia FAL sia TI)
- [ ] Programmare la raccolta dei nuovi quadri RFI + manifesto FAL (indicativamente da metà novembre 2026).
- [ ] Rigenerare il feed con `build_gtfs.py` (nuovo `feed_version`, nuove finestre di validità) prima del 12/12/2026, per evitare il banner RF-13 su tutte le corse.

### P4 — Fase 2 (refresh di rete): avviata il 04/08/2026
- [x] **D-08** scelta hosting — **GitHub** (repo pipeline pubblico dedicato `BinarioSudPipeline`; feed_url via `raw`/Release, non serve account/infra aggiuntiva).
- [x] Repo pipeline creato e versionato; CI di pubblicazione pronta: `.github/workflows/publish.yml` (trigger manuale) genera GTFS, crea `dist/gtfs-<versione>.zip` + `dist/manifest.json` (`scripts/package_release.py`, contratto §1.3) e pubblica una GitHub Release (tag = `feed_version`) con i due asset; l'app leggerà sempre `.../releases/latest/download/manifest.json` (URL stabile, alias nativo di GitHub). Pubblicazione atomica (Release creata in bozza, poi resa pubblica solo a upload completato). **Prima pubblicazione reale eseguita e verificata il 04/08/2026**: Release `20260618-7` pubblicata, `.../releases/latest/download/manifest.json` raggiungibile e valido (feed_url, date di validità, size, sha256 tutti corretti).
- [x] Corretto `feed_publisher_url` in `feed_info.txt` (era placeholder `example.com`) → URL reale del repo pipeline.
- [ ] Lo **scraping automatico giornaliero** dai portali RFI/FAL (obiettivo del committente) è **rimandato**: `build_gtfs.py` oggi genera da dati trascritti a mano nel codice, non contatta alcuna fonte esterna — task futuro dedicato, fuori da questo step.
- [x] **RF-07** + consumo manifest lato app (§1.4) — implementato il 05/08/2026 (vedi Log avanzamenti).
- [x] **Manifest schema_version 2 + side-car via rete** — implementato il 05/08/2026 (vedi Log avanzamenti): la pipeline ora pubblica anche `attributes-<feed_version>.zip`; l'app lo scarica, verifica e usa con lo stesso criterio di precedenza cache→bundle già in uso per il GTFS. Chiude il punto aperto precedente (side-car non più bloccati sul bundle).
- [x] **RF-14** pull-to-refresh manuale — implementato il 05/08/2026 (vedi Log avanzamenti): `RefreshIndicator` sulla lista corse, riusa `controller.forceRefreshCheck()` (già esistente per l'hook di debug).
- [ ] **D-02** licenza dati, poi testo definitivo RF-19 in `info_sheet.dart` — rilevante solo prima di una pubblicazione pubblica.

## Decisioni aperte (solo D-xx da chiudere)
- **D-02** — Licenza d'uso del dato: non bloccante per MVP non pubblicato; da chiudere **prima della pubblicazione** (impatta testo RF-19).
- **D-08** — **CHIUSA (04/08/2026).** Hosting: **GitHub** (repo pubblico dedicato `BinarioSudPipeline`), non Firebase — nessuna nuova infrastruttura/account da creare, riusa il repo già collegato al progetto; sufficiente per il volume dati (pochi KB, check giornaliero) via GitHub Releases.
- **D-11** — **CHIUSA (03/08/2026).** `end_date` FAL `20261212` resta un'assunzione (nessuna scadenza pubblicata da FAL), ma verificata come ragionevole: nessun manifesto più recente del 27/10/2025 in vigore, e il cambio orario ferroviario nazionale "Orario 2027" entra in vigore il 13/12/2026 (coerente con la finestra TI, già `20261212`). Nessuna modifica ai dati; riverificare comunque prima del cambio orario di dicembre 2026 (vedi P3).
- **D-12** — **CHIUSA (03/08/2026).** Festività locali/patronali (San Nicola/Bari, patrono Modugno): committente conferma l'assunzione attuale (circolazione normale, nessuna modellazione in `calendar_dates`).
- **D-13** — **CHIUSA (03/08/2026).** Accessibilità carrozzina FAL verificata (fonte: PDF FAL "e le persone con disabilità", aprile 2024): fermata Modugno "con pedana", condizionata (tipologia carrozzina, preavviso 24h). Valore GTFS `wheelchair_accessible=2` mantenuto per scelta di modellazione (nessun valore standard rappresenta un "sì condizionato"); testo UI da rendere specifico sulla condizionalità.

> Già chiuse (non rilevare come gap): R-03 (coordinate presenti), D-06 (festività nazionali nel motore festività), D-11/D-12/D-13 (vedi sopra), R-09 (binario Bari Centrale da OCR: chiusa come limite noto, testo UI aggiornato).

## Log avanzamenti
- **2026-08-05** — **Rimosso il pulsante debug "Controlla aggiornamenti ora"** dal
  pannello Info (`ui/info_sheet.dart`): ridondante rispetto al pull-to-refresh (RF-14),
  che chiama lo stesso `controller.forceRefreshCheck()` e mostra lo stesso esito in
  SnackBar. Rimossi anche `_forceRefresh` e gli import ora inutilizzati
  (`kDebugMode`, `data/feed_refresh_service.dart`). `ScheduleController.forceRefreshCheck()`
  resta invariato, ancora usato dal pull-to-refresh.
- **2026-08-05** — **Consumo dei side-car via rete (manifest schema_version 2).** La
  pipeline sorella `BinarioSudPipeline` ora pubblica, oltre a `gtfs-<feed_version>.zip`,
  anche `attributes-<feed_version>.zip` (i 4 side-car JSON, stesso schema `{meta,
  trains[]}` già gestito da `attributes_parser.dart`, invariato) referenziato nel manifest
  con 3 nuovi campi (`attributes_url`/`attributes_size_bytes`/`attributes_sha256`),
  `schema_version` salito a 2. Aggiornamenti lato app: `data/feed_manifest.dart` legge i 3
  nuovi campi (nullable, stesso pattern dei `feed_*`); `FeedRefreshService
  .supportedSchemaVersion` 1→2 (i manifest schema 1 ora sono `unsupportedSchema`);
  `_downloadAndSwap` scarica anche lo zip attributi quando `attributes_url` è presente nel
  manifest, ne verifica lo sha256 ed estrae i `.json` in `<cache>/attributes/`, nella
  **stessa** cartella temporanea del GTFS — un solo `rename` finale rende lo swap atomico
  per entrambi insieme (un hash attributi errato fa fallire l'intero aggiornamento, non
  lascia GTFS nuovo con attributi vecchi/mancanti). `data/gtfs_repository.dart`:
  `_readAttributes` ora preferisce, file per file, `<cacheDir>/attributes/*.json` se
  presente, altrimenti ricade sul bundle — stesso criterio già usato per le tabelle GTFS,
  così una cache scaricata prima di questo cambio (senza cartella `attributes/`) continua a
  funzionare senza buchi. Non toccato `attributes_parser.dart` (formato invariato). +1 file
  di test nuovo (`feed_manifest_test.dart`), test estesi in `feed_refresh_service_test.dart`
  (schema 1 ora rifiutato, download/verifica/estrazione attributi, hash attributi errato →
  `downloadFailed` con cache precedente intatta) e `gtfs_repository_cache_test.dart`
  (side-car preferito dalla cache quando presente, fallback al bundle file per file quando
  assente). Chiude la nota "Aperto" residua di RF-07/P4 (side-car non pubblicati dalla
  pipeline) — non ancora rilanciati `flutter analyze`/`flutter test` in sessione, da fare
  prima del commit.
- **2026-08-05** — **RF-14 implementato** (pull-to-refresh manuale). Lista corse
  (`_JourneyList` in `ui/schedule_screen.dart`) avvolta in un `RefreshIndicator`: il gesto
  chiama `_pullToRefresh` → `controller.forceRefreshCheck()` (bypassa il vincolo "un
  controllo al giorno" di RF-07, come già l'hook di debug) e mostra l'esito in una SnackBar.
  Estratta la mappatura `RefreshOutcome → testo` in una funzione condivisa
  `refreshOutcomeLabel()` in `data/feed_refresh_service.dart`, riusata sia da `info_sheet.dart`
  (hook debug) sia dal nuovo pull-to-refresh, eliminando la duplicazione. Pull-to-refresh
  disponibile solo quando la lista non è vuota (stati vuoti non sono scrollabili): scelta
  minimale, coerente con la priorità COULD del requisito. +1 widget test
  (`schedule_screen_test.dart`: trascinamento della lista → SnackBar "Refresh non
  configurato", a conferma del collegamento al gesto senza richiedere un `refreshService`
  reale nel controller di test). **56/56 test verdi**, `flutter analyze` pulito (verificato
  dall'utente). **Verificato anche a mano su device reale**: trascinando la lista corse
  verso il basso il pull-to-refresh funziona correttamente.
- **2026-08-05** — **RF-07 implementato** (refresh giornaliero da rete, §1.4). Nuove dipendenze:
  `http`, `archive`, `path_provider`, `crypto`. Nuovi file: `data/feed_manifest.dart` (modello
  manifest §1.3), `data/feed_refresh_service.dart` (`FeedRefreshService`: controllo "una volta
  al giorno", confronto `feed_version`, download zip, verifica `feed_sha256`, validazione
  struttura minima, sostituzione atomica della cache — mai corrompe la cache esistente in caso
  di errore, CA-7.1/CA-4.2). `data/gtfs_repository.dart` esteso con `cacheDir` opzionale
  (`withCacheDir`): le tabelle GTFS possono venire dal bundle o dalla cache scaricata, stesso
  parser; gli attributi estesi (side-car) restano **sempre** dal bundle (vedi nota P4 sotto).
  `data/settings_store.dart` esteso con `cached_feed_version`/`last_check_date` persistiti.
  `state/schedule_controller.dart`: al 1° avvio sceglie cache-se-presente/bundle, poi lancia il
  controllo in background senza bloccare la UI (RNF-03); se trova una versione più recente
  valida la applica **a caldo** nella sessione corrente (hot-swap, decisione confermata in
  sessione), non solo al prossimo avvio. Aggiunto `forceRefreshCheck()` (bypassa il vincolo
  "un controllo al giorno") con un pulsante visibile solo in `kDebugMode` nel pannello Info,
  per provare la catena scarica→valida→sostituisce senza aspettare una vera nuova pubblicazione
  (le release reali sono manuali e rare, ~2 volte/anno). **Verificato contro il manifest reale
  pubblicato** (fetch diretto dell'URL stabile durante la pianificazione): struttura conforme al
  contratto §1.3. **Scoperta**: ispezionato `scripts/package_release.py` nella pipeline — lo zip
  pubblicato contiene solo gli 8 `.txt` GTFS, non i side-car; annotato come nota aperta non
  bloccante in P4. +3 file di test nuovi/estesi (`feed_refresh_service_test.dart`,
  `gtfs_repository_cache_test.dart`, gruppo RF-07 in `schedule_controller_test.dart`) con
  `http.testing.MockClient` e cartelle temporanee reali, copertura dei casi CA-3.1/3.2/3.3/3.4,
  CA-4.2, CA-7.1. **55/55 test verdi**, `flutter analyze` pulito (ultima esecuzione fatta in
  sessione prima di questa nota — da questo punto in poi i comandi `flutter` li esegue
  l'utente). Verifica end-to-end su device reale: vedi riga successiva.
- **2026-08-05** — **RF-07 verificato end-to-end su device reale con rete vera.** Aggiunto il
  permesso `android.permission.INTERNET` in `android/app/src/main/AndroidManifest.xml`
  (mancava: non serviva in Fase 1 offline-only; senza, il refresh avrebbe fallito in
  silenzio in build di release — in debug era già presente via
  `android/app/src/debug/AndroidManifest.xml`). L'utente ha pubblicato una nuova Release
  reale (`20260805-1`, bump di `feed_version` in `build_gtfs.py`, stessi dati) su
  `BinarioSudPipeline` col workflow `publish.yml`; il bundle app resta a `20260618-7`
  (invariato, vedi sezione sopra). Avviata l'app su device, toccato "Controlla
  aggiornamenti ora (debug)": SnackBar **"Aggiornato a 20260805-1"** — confermata l'intera
  catena reale GET manifest→confronto versione→download zip→verifica `feed_sha256`→
  decomprimi→valida struttura→sostituzione atomica della cache→hot-swap in sessione, contro
  la vera Release GitHub (non solo contro `MockClient` nei test). Confermati anche i due
  controlli facoltativi: riga "Versione dati" nel pannello Info aggiornata a `20260805-1`
  subito dopo l'hot-swap; riavviando l'app riparte dalla cache appena scaricata (non più dal
  bundle) e un secondo tap sul pulsante debug mostra "Già aggiornato" (nessun ri-download).
  RF-07 considerato chiuso anche lato verifica manuale, non solo test automatici.
- **2026-08-04** — **Prima pubblicazione reale verificata**: eseguito il workflow `publish.yml` su `BinarioSudPipeline`. Release `20260618-7` pubblicata con i 2 asset attesi; `.../releases/latest/download/manifest.json` raggiungibile in anonimo e con contenuto valido (feed_url/date validità/size/sha256 coerenti coi dati generati). Meccanismo D-08 confermato funzionante end-to-end. Prossimo passo: RF-07 lato app Flutter.
- **2026-08-04** — **Avviata Fase 2 (P4)**. **D-08 chiusa**: hosting su GitHub. Creato repo pubblico dedicato `BinarioSudPipeline` (separato dall'app, coerente con la distinzione "due deliverable" già in uso) e versionato `build_gtfs.py` + output `assets/gtfs/*.txt`. Aggiunta CI di pubblicazione (`.github/workflows/publish.yml`, trigger manuale): rigenera il GTFS, lo impacchetta in `dist/gtfs-<feed_version>.zip` con `scripts/package_release.py`, genera `dist/manifest.json` conforme al contratto §1.3 (schema_version, feed_url, feed_published_at, feed_valid_from/to, feed_size_bytes, feed_sha256), e pubblica una GitHub Release (tag=`feed_version`, due asset) in modo atomico (bozza → upload → pubblicazione) così l'app potrà sempre leggere un unico URL stabile (`.../releases/latest/download/manifest.json`). Corretto anche `feed_publisher_url` in `feed_info.txt` (era placeholder). Nota emersa in sessione: l'obiettivo di verifica/aggiornamento **automatico giornaliero dai portali** RFI/FAL non è coperto da `build_gtfs.py` (i dati sono trascritti a mano nel codice, nessuno scraping reale) — rimandato a task dedicato futuro, deciso col committente. Prossimo passo: prima esecuzione reale della pubblicazione, poi implementare il consumo del manifest lato app Flutter (RF-07).
- **2026-08-03** — **P2 chiuso**: chiusi gli ultimi 3 punti (D-11, R-09, D-12) dopo verifica esterna e decisioni col committente. **D-11**: ricerca web sul sito ufficiale FAL (sezione comunicazioni di servizio e quadri orario) non ha trovato una scadenza pubblicata; confermato che il cambio orario nazionale "Orario 2027" parte il 13/12/2026, coerente con l'assunzione `20261212` già in uso — chiusa con nota motivata, nessuna modifica ai dati. **R-09**: non è stato possibile accedere al PDF sorgente RFI originale né a un quadro live per un controllo puntuale del binario; chiusa come limite noto accettato (il binario da grandi stazioni è comunque soggetto a variazione operativa). Aggiunto in `data/gtfs_models.dart`/`data/attributes_parser.dart` il campo `TripAttributes.platformVerified` (distingue `platform_bari_centrale`, OCR non verificato, da `platform_modugno`, dichiarato con certezza dalla fonte); `ui/journey_detail_sheet.dart` mostra ora una didascalia "Indicativo: da verificare in stazione..." solo quando il binario non è verificato. **D-12**: il committente conferma l'assunzione attuale (nessuna modellazione delle festività locali/patronali). +2 asserzioni test (`attributes_parser_test.dart`, `journey_builder_test.dart`). `flutter analyze` pulito, **43/43 test verdi**.
- **2026-08-03** — **D-13 chiusa**: verifica online dell'accessibilità carrozzina FAL tramite fonte ufficiale ([PDF FAL "e le persone con disabilità"](https://ferrovieappulolucane.it/wp-content/uploads/2024/04/fal-persone_disabilita.pdf), aprile 2024) — fermata Modugno "con pedana", condizionata (tipologia carrozzina, preavviso 24h). Decisione di modellazione presa in sessione (ruolo committente): GTFS `wheelchair_accessible=2` **invariato** per FAL (nessun valore standard rappresenta un "sì condizionato"); testo UI **aggiornato** di conseguenza in `journey_detail_sheet.dart` (badge "Accessibile su richiesta" + didascalia esplicativa) e `schedule_screen.dart` (`_AccessibilityFilterNotice`), sostituendo il generico "da verificare/assunto" con la condizionalità reale. Aggiornati anche i commenti in `schedule_controller.dart` e `gtfs_models.dart`. Aggiornata `Specifiche_App_Orari_Modugno-Bari_MVP.md` a v1.6 (§1.2/§1.5/§6.6/RF-21/R-10/A-10/D-13 + changelog v1.6). `flutter analyze` pulito, **43/43 test verdi** (nessun test asseriva il testo letterale, nessuna modifica necessaria alla suite).
- **2026-08-03** — Verifica manuale anti-overflow su device reale completata (nessun overflow di layout riscontrato). Con questo si chiude la Fase 1 di P1.
- **2026-08-03** — CI minima aggiunta: `.github/workflows/ci.yml` (`flutter analyze` + `flutter test` su push/PR verso `master`/`develop`, `subosito/flutter-action@v2` canale stable). Verificato in locale prima del commit: analyze pulito, **43/43 test verdi**. Corretta anche la voce "remote Git" in P1: il remote `origin` risultava già configurato (disallineamento nel documento, non nel repo).
- **2026-08-03** — Pianificazione: sezione "Prossimi passi" riorganizzata in piano prioritizzato (P1 chiusura Fase 1, P2 verifiche dati, P3 cambio orario 12/12/2026, P4 Fase 2), da analisi esterna. Corretto anche il conteggio test nella voce "Qualità" (41→43, allineato al log del 25/06). Nessuna modifica al codice.
- **2026-06-25** — Fermate intermedie estese a **FAL** (coerenza con TI, RF-16). Aggiunti i due side-car `assets/attributes/fal_{bari_modugno,modugno_bari}_attributes.json` (fonte: manifesto FAL 27/10/2025) e registrati nel loader `gtfs_repository.dart`. Verifica dati: join `trip_id` **1:1 con le 40 corse FAL del GTFS** (0 orfani, 0 mancanti), estremi orari coincidenti col GTFS, fermate intermedie (Bari Scalo / Bari Policlinico) temporalmente monotone su tutte le 40 corse. Parser e UI già operatore-agnostici, nessuna modifica. Aggiornato `journey_builder_test.dart` (il vecchio test "FAL senza side-car" ora asserisce la presenza degli attributi). **43/43 test verdi**. NB: resa UI da verificare su device prima del commit.
- **2026-06-24** — Verifica conformità alla spec v1.5 + correzioni RF-21 (accessibilità FAL). (1) Dettaglio corsa: badge FAL da **"Non accessibile"** → **"Accessibilità da verificare"** (icona `help_outline`), per non presentare come confermato un dato assunto non verificato (R-10/A-10/D-13). (2) Filtro "Accessibile" non esclude più **silenziosamente** le corse FAL: nuovo `ScheduleController.falExcludedByAccessibilityCount` + nota `_AccessibilityFilterNotice` in schermata col conteggio. (3) Corretto commento obsoleto coordinate in `gtfs_models.dart` (valorizzate in v2, R-03 chiusa). +2 test controller. `flutter analyze` pulito, **43/43 test verdi**. NB: modifiche UI da verificare su device prima del commit.
- **2026-06-19** — Ricognizione iniziale stato progetto (no codice applicativo). Confermato feed v2 in bundle (`20260618-6`), parser/UI leggono i campi estesi v2. Core Fase 1 (RF-01→13) implementato; gap residui su RF-20/21 (filtri assenti), RF-15 (UI mancante), RF-19 (testo licenza placeholder). Repo senza git; `build_gtfs.py` non nel progetto. Creato questo file di stato.
- **2026-06-19** — Integrati i side-car JSON: nuovo `attributes_parser.dart` + `GtfsFeed.attributesByTrip`, `Journey.attributes`; tile resa tappabile con nuovo `journey_detail_sheet.dart` (categoria, binario, fermata intermedia, prenotazione, garanzia sciopero, nota); binario mostrato in linea nella tile. `service_pattern` ignorato di proposito (circolazione governata dal calendario). RF-16 chiuso.
- **2026-06-24** — Aggiunto `test/schedule_screen_test.dart` (3 widget test funzionali: struttura Opzione A con giorno in schermata e filtri nell'AppBar, apertura del bottom sheet dall'icona, badge col conteggio filtri attivi). Note tecniche: feed caricato in `tester.runAsync` (I/O reale `File`); clock reale perché `_DaySelector` usa `DateTime.now()`. L'overflow di layout non è asseribile in widget test (font di test a larghezza fissa). **41 test totali, verdi**; `flutter analyze` pulito.
- **2026-06-24** — Allineato `_DaySelector` al clock del controller: esposto `ScheduleController.today` e rimosso l'uso diretto di `DateTime.now()` (incl. `firstDate`/`lastDate` del date picker). Il selettore giorno ora è pienamente testabile con `now` iniettato; comportamento invariato in produzione. Test schermata reso deterministico (clock fisso 2026-06-17). 41 test verdi, analyze pulito.
- **2026-06-24** — Refactor UI filtri (Opzione A): spostati operatore, orario, bici e accessibilità in un bottom sheet `_FiltersSheet` aperto da un'azione AppBar (icona `tune` + badge `activeFilterCount`); applica **live** (`ListenableBuilder`), "Azzera" (`resetFilters`), footer "Mostra N corse". In schermata restano solo direzione e giorno (3 chip centrate; recuperato ~30% di spazio ed eliminato l'overflow della riga giorno). Aggiunta persistenza preferenze: nuovo `data/settings_store.dart` (`SettingsStore` + `SharedPrefsSettingsStore`), dip. `shared_preferences` (storage locale, RF-06 invariato), iniettata in `main.dart`; oggi persiste solo l'accessibilità (RF-21). +4 test controller. `flutter analyze` pulito, **38/38 test verdi**.
- **2026-06-24** — RF-20 e RF-21 chiusi: aggiunti due `FilterChip` ("Bici"/"Accessibile") in `_FilterBar` collegati a `setOnlyBikes`/`setOnlyAccessible`. Refactor del controller: estratto predicato condiviso `_matchesNonTimeFilters` (direzione+operatore+bici+accessibilità), eliminata la duplicazione dello switch operatore tra `visibleJourneys` e `hasJourneysIgnoringTime`. Filtro accessibilità tiene `wheelchair=yes`; filtro bici è no-op coi dati attuali (`bikes_allowed=1` su tutte le 99 corse). +3 test controller. `flutter analyze` pulito, **34/34 test verdi**.
- **2026-06-24** — RF-15: prima implementato (icona swap), poi **rimossa la UI su decisione UX** (con 2 sole direzioni già selezionabili lo swap è ridondante); `toggleDirection` resta nel controller. Mantenuta la correzione del test `schedule_controller_test.dart`: il test "default" attendeva `versoBari` mentre il controller ha default `versoModugno` (intento corretto), ora allineato a `versoModugno`/dir 1. `flutter analyze` pulito, **31/31 test verdi**.
- **2026-06-22** — Igiene repo: git inizializzato (branch `master`), `.gitignore` configurato per VS Code (versionati `launch.json`/`tasks.json`, ignorati file utente/estensioni + `.history/`/`*.vsix`). Rimosso `.claude/settings.local.json` dal tracking (conteneva path assoluti macchina-specifici) e aggiunto al `.gitignore`. `pubspec.lock` lasciato versionato (corretto per app). Branch principale confermato `master` (impostato anche `init.defaultBranch` globale = `master`); nessun branch `main` esistente. Aperto opzionale: nessun remote.
- **2026-06-24** — Ritocchi UI parte fissa in alto (`ui/schedule_screen.dart`): direzione di default ora **verso Modugno** (`schedule_controller`) e segmenti invertiti (Modugno a sinistra, Bari a destra); pulsante selettore orario (RF-04) spostato da `_FilterBar` accanto al selettore giorno in `_DaySelector` (nota: posizionamento poi superato nello stesso giorno dal refactor "Opzione A" più sotto, che sposta il selettore orario nel bottom sheet `_FiltersSheet`); le tre fasce (direzione/giorno+orario/operatore) ora **centrate** (`Center`/`MainAxisAlignment.center`). `flutter analyze` pulito.
- **2026-06-19** — Bump feed a `20260618-7` (patch accessibilità FAL). Rifattorizzati `bikes_allowed`/`wheelchair_accessible` da `bool` a enum **`Availability`** a 3 stati (`unknown`/`yes`/`no`): FAL ora `wheelchair=2` reso esplicitamente "Non accessibile" nello sheet (prima collassato con "ignoto"). Aperta D-13. Test 31/31 verdi, `flutter analyze` pulito.
