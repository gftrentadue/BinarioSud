# STATO PROGETTO — BinarioSud (App Orari Modugno ⇄ Bari)

> File di stato persistente, da aggiornare a ogni sessione: spunta le caselle completate
> e aggiungi una riga datata nel **Log avanzamenti**. Mantienilo conciso.

## Obiettivo finale dell'MVP
App Flutter (target Android) che mostra in un'unica lista gli orari teorici dei treni della
relazione **Modugno ⇄ Bari**, aggregando i due operatori **Trenitalia** e **FAL**, consumando
un feed **GTFS statico**. L'MVP è in **Fase 1 "bundle-only"** (D-10): il GTFS è incluso negli
asset dell'app ed è l'unica fonte, funzionamento interamente **offline**, nessun refresh da rete
(RF-07 e logica §1.4 rinviati alla Fase 2). Fuori ambito: real-time, biglietti, account, altre tratte, iOS.

## Feed in bundle attualmente in uso
- **feed_version:** `20260618-7` (v2, completo da fonti ufficiali; patch accessibilità FAL su `20260618-6`) — supera il seed v1 `20260612-1`.
- **Volume:** 99 trips · 198 stop_times · 56 eccezioni in `calendar_dates` · 8 `service_id` namespaced.
- **Finestre validità:** FAL `20251027→20261212` (end **assunto**, D-11) · TI `20260614→20261212`.
- **Estensioni v2:** coordinate stop valorizzate · `bikes_allowed=1` (tutte) · `wheelchair_accessible` (TI=`1`=sì, **FAL=`2`=no** assunto, D-13) · `trip_short_name` (TI + FAL 129/116). Campi a **3 stati** GTFS (`0`=ignoto/`1`=sì/`2`=no), **non** booleani.
- **Asset:** 8 `.txt` in `assets/gtfs/` + side-car `assets/attributes/{ti,fal}_*_attributes.json` (4 file `.json`, no `.csv`).

## Note di contesto
- Repository **non inizializzato a git** (nessuna cronologia versioni).
- `build_gtfs.py` **non presente** nel progetto app (vive nel workstream pipeline, separato).
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
| RF-07 | Refresh giornaliero (logica §1.4) | MUST | ⏸️ NON-PERTINENTE-FASE-1 | rinviato a Fase 2 (D-10) |
| RF-08 | Data/versione dati in uso | MUST | ✅ IMPLEMENTATO | `_FreshnessFooter` + `info_sheet.dart`; `controller.feedVersion` |
| RF-09 | Stati limite | MUST | ✅ IMPLEMENTATO (per Fase 1) | `ui/empty_states.dart` (loading/error/no-journey); casi rete sono Fase 2 |
| RF-10 | Selezione giorno diverso da oggi | MUST | ✅ IMPLEMENTATO | `_DaySelector` Oggi/Domani/DatePicker; `setSelectedDay` |
| RF-11 | Evidenzia prossima corsa | SHOULD | ✅ IMPLEMENTATO | `controller.nextJourneyTripId`; `JourneyTile isNext` |
| RF-12 | Filtro operatore | SHOULD | ✅ IMPLEMENTATO | `OperatorFilter` segmented nel pannello `_FiltersSheet` |
| RF-13 | Indicatore feed oltre `feed_valid_to` | SHOULD | ✅ IMPLEMENTATO | `controller.isFeedExpired` + banner in `schedule_screen` |
| RF-19 | Attribuzione fonte + licenza | SHOULD→MUST a pubbl. | 🟡 PARZIALE (corretto per MVP) | `info_sheet.dart`: spazio predisposto, testo placeholder (D-02) |
| RF-14 | Pull-to-refresh manuale | COULD | ⏸️ NON-PERTINENTE-FASE-1 | dipende dal refresh (Fase 2) |
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

### P4 — Fase 2 (refresh di rete): solo quando si decide di avviarla
- [ ] **D-08** scelta hosting (Firebase vs GitHub) — sblocca il resto della Fase 2.
- [ ] **RF-07** + manifest reale (§1.4) — dipende da D-08.
- [ ] **RF-14** pull-to-refresh manuale — dipende da RF-07.
- [ ] **D-02** licenza dati, poi testo definitivo RF-19 in `info_sheet.dart` — rilevante solo prima di una pubblicazione pubblica.

## Decisioni aperte (solo D-xx da chiudere)
- **D-02** — Licenza d'uso del dato: non bloccante per MVP non pubblicato; da chiudere **prima della pubblicazione** (impatta testo RF-19).
- **D-08** — Hosting (Firebase vs GitHub): rinviata alla Fase 2.
- **D-11** — **CHIUSA (03/08/2026).** `end_date` FAL `20261212` resta un'assunzione (nessuna scadenza pubblicata da FAL), ma verificata come ragionevole: nessun manifesto più recente del 27/10/2025 in vigore, e il cambio orario ferroviario nazionale "Orario 2027" entra in vigore il 13/12/2026 (coerente con la finestra TI, già `20261212`). Nessuna modifica ai dati; riverificare comunque prima del cambio orario di dicembre 2026 (vedi P3).
- **D-12** — **CHIUSA (03/08/2026).** Festività locali/patronali (San Nicola/Bari, patrono Modugno): committente conferma l'assunzione attuale (circolazione normale, nessuna modellazione in `calendar_dates`).
- **D-13** — **CHIUSA (03/08/2026).** Accessibilità carrozzina FAL verificata (fonte: PDF FAL "e le persone con disabilità", aprile 2024): fermata Modugno "con pedana", condizionata (tipologia carrozzina, preavviso 24h). Valore GTFS `wheelchair_accessible=2` mantenuto per scelta di modellazione (nessun valore standard rappresenta un "sì condizionato"); testo UI da rendere specifico sulla condizionalità.

> Già chiuse (non rilevare come gap): R-03 (coordinate presenti), D-06 (festività nazionali nel motore festività), D-11/D-12/D-13 (vedi sopra), R-09 (binario Bari Centrale da OCR: chiusa come limite noto, testo UI aggiornato).

## Log avanzamenti
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
