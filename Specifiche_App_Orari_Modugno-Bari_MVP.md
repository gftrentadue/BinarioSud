# Specifiche Funzionali e di Interfaccia — App Orari Treni Modugno ⇄ Bari (MVP)

**Versione documento:** 1.7
**Data:** 06/08/2026
**Autore:** Business Analyst
**Stato:** **Fase 2 (refresh da rete) attiva dal 05/08/2026** (D-10): RF-07 implementato e verificato su device reale, manifest `schema_version 2` con side-car via rete, RF-14 pull-to-refresh. Feed in bundle **v2 (`20260618-7`)** completo da fonti ufficiali (fallback/primo avvio, D-07). Contratto dati esteso (campi bici/accessibilità, coordinate, 8 service_id, motore festività, side-car). Accessibilità FAL a `wheelchair_accessible=2`, valore GTFS mantenuto per scelta di modellazione dopo verifica (fermata Modugno con pedana condizionata — D-13 chiusa). Decisioni chiuse: D-03, D-04, D-05, D-07, D-08, D-09, D-11, D-12, D-13; D-06 sostanzialmente chiusa. In attesa di: D-02 (a GTFS ufficiale definito). Vedi changelog in §9.3.
**Lingua sorgente dati:** italiano · **Fuso orario di riferimento:** Europe/Rome

---

## 0. Premessa e come leggere questo documento

Il sistema si compone di due deliverable distinti e disaccoppiati:

- **App mobile (deliverable PRIMARIO)** — client sottile Flutter (target MVP: Android) che consuma un feed orari statico in formato GTFS.
- **Pipeline dati (deliverable SECONDARIO, parallelo)** — script di ingestione locale che produce e pubblica il feed GTFS come file statico su hosting gratuito.

Il punto di contatto unico tra i due è il **Contratto Dati** (sezione 1): è il primo elemento da congelare, perché permette ai due workstream di procedere in parallelo. L'app deve poter essere sviluppata e testata **subito** contro un **dataset seed** (sezione 6), senza attendere la pipeline.

Ordine di lettura consigliato per i team:
- **UX / Flutter:** sezioni 1 → 2 → 3 → 4 → 5 → 6 → 8.
- **Pipeline dati:** sezioni 1 → 5 → 7 → 9.

### 0.1 Glossario essenziale

| Termine | Significato |
|---|---|
| GTFS | General Transit Feed Specification (orari statici), insieme di file `.txt` in un archivio ZIP. |
| Feed | L'archivio GTFS pubblicato (il dato consumato dall'app). |
| Manifest | Piccolo file JSON di metadati/versione, letto dall'app per decidere se scaricare un nuovo feed. |
| Corsa | Singolo viaggio di un treno su una direzione, con orari di partenza/arrivo (≈ `trip` GTFS). |
| Operatore | Trenitalia oppure FAL (Ferrovie Appulo Lucane). |
| Direzione | Modugno → Bari **oppure** Bari → Modugno. |
| Periodicità | Validità della corsa per tipo di giorno (feriale / festivo / eccezioni). |
| Seed | Dataset minimo trascritto a mano per avviare lo sviluppo app. |
| MVP | Minimum Viable Product: solo orari teorici/statici, niente real-time. |

### 0.2 Ambito (sintesi)

**In ambito (MUST per l'MVP):** unica relazione Modugno ⇄ Bari in entrambe le direzioni; aggregazione dei due operatori in un'unica lista di corse; per ogni corsa operatore, stazioni origine/destinazione, orario partenza/arrivo, durata, periodicità; selezione del giorno e uso **offline**; definizione feed GTFS + manifest + dataset seed; definizione della pipeline di ingestione. **Avvio a fasi (D-10):** la **Fase 1** è **bundle-only** (GTFS nel bundle, nessun refresh da rete); il **download/refresh giornaliero** (RF-07, §1.4) è rinviato alla **Fase 2**.

**Fuori ambito (dichiarato esplicitamente):** dati in tempo reale (ritardi, binario effettivo), acquisto biglietti, altre tratte/relazioni, iOS, account utente, pagamenti, notifiche push. Questi elementi sono **evoluzione futura**, non MVP.

---

## 1. CONTRATTO DATI app ⇄ distribuzione *(da definire per primo — vincolante)*

### 1.1 Principio di disaccoppiamento

L'app **non** conosce le fonti ufficiali né la pipeline. Conosce esclusivamente:
1. un **URL del manifest** (file JSON, stabile nel tempo);
2. la **struttura del feed GTFS** descritta sotto.

La pipeline ha l'unico obbligo di **rispettare questo contratto** quando pubblica feed e manifest. Qualunque cambiamento al contratto è un *breaking change* e va versionato esplicitamente (campo `schema_version` nel manifest).

### 1.2 Struttura del feed GTFS (file e campi effettivamente usati nell'MVP)

Il feed è un archivio `gtfs.zip` contenente i seguenti file. Sono elencati **solo** i campi usati nell'MVP; campi GTFS opzionali non elencati possono essere presenti ma l'app li ignora. I campi **obbligatori per l'MVP** sono marcati ●; quelli **consigliati** ○.

**`agency.txt`** — operatori
| Campo | Oblig. | Note MVP |
|---|---|---|
| `agency_id` | ● | Identificatore stabile. Valori MVP: `TI` (Trenitalia), `FAL`. |
| `agency_name` | ● | Etichetta mostrata in UI: "Trenitalia", "Ferrovie Appulo Lucane". |
| `agency_url` | ● | URL ufficiale operatore. |
| `agency_timezone` | ● | `Europe/Rome` per entrambi. |
| `agency_lang` | ○ | `it`. |

**`stops.txt`** — fermate
| Campo | Oblig. | Note MVP |
|---|---|---|
| `stop_id` | ● | Stabile. Valori: `MOD_TI`, `MOD_FAL`, `BARI_TI`, `BARI_FAL` (vedi §1.5). |
| `stop_name` | ● | Disambiguati: "Modugno" (TI), "Modugno Città" (FAL), "Bari Centrale (Trenitalia)", "Bari Centrale (FAL)". |
| `stop_lat`, `stop_lon` | ● *(valorizzati in v2)* | Le quattro stazioni sono **fisicamente distinte** e in posizioni geografiche diverse (D-04). Coordinate reali presenti dal rilascio v2 (vedi §6.6); abilitano disambiguazione in UI e mappa futura. |

**`routes.txt`** — linee
| Campo | Oblig. | Note MVP |
|---|---|---|
| `route_id` | ● | Es. `TI_BA_TA`, `FAL_BA_MT`. |
| `agency_id` | ● | FK su `agency.txt`. |
| `route_short_name` | ○ | Sigla breve se disponibile. |
| `route_long_name` | ● | Es. "Bari–Taranto", "Bari–Matera". |
| `route_type` | ● | `2` (Rail) per entrambi gli operatori MVP. |

**`trips.txt`** — corse
| Campo | Oblig. | Note MVP |
|---|---|---|
| `route_id` | ● | FK su `routes.txt`. |
| `service_id` | ● | FK su `calendar.txt` (determina la periodicità). |
| `trip_id` | ● | Identificatore univoco. Convenzioni v2: FAL `FAL_M_HHMM`/`FAL_B_HHMM` (orario di partenza); TI `TI_<numero treno>`. |
| `trip_short_name` | ○ *(v2)* | Numero treno, dove noto: tutti i TI; per FAL solo 129 e 116. |
| `trip_headsign` | ○ | Destinazione visibile (es. "Bari Centrale"). |
| `direction_id` | ● | `0` = verso Bari, `1` = verso Modugno (convenzione fissata in §1.5). |
| `bikes_allowed` | ○ *(v2)* | `1` per tutte le corse (bici ammesse): FAL **confermato dal sito FAL**, Trenitalia documentato. Alimenta il filtro opzionale RF-20 senza file esterni. |
| `wheelchair_accessible` | ○ *(v2)* | `1` per Trenitalia (carrozza attrezzata documentata); **`2` per FAL** = valore GTFS mantenuto come scelta di modellazione **dopo verifica** (fonte FAL, aprile 2024): fermata **Modugno "con pedana"**, ma **condizionata** (assistenza solo per alcune tipologie di carrozzina, preavviso 24h, presentarsi 30 min prima); non equiparabile al `1` incondizionato TI, né a `0`/ignoto (assenza totale di informazioni) — vedi R-10, A-10, D-13 (**chiusa**). Alimenta il filtro opzionale RF-21. |

> **Valori tri-stato (non booleani).** I campi `bikes_allowed` e `wheelchair_accessible` ammettono tre valori GTFS: `0` = nessuna informazione, `1` = sì (consentito/accessibile), `2` = no (non consentito/non accessibile). L'app deve trattarli come enumerazioni a tre stati, **non** come flag vero/falso: in particolare `2` per FAL va presentato come **accessibile con assistenza su richiesta, condizionata alla tipologia di carrozzina e al preavviso** (dato verificato, D-13), non come "non accessibile" confermato in senso standard GTFS — questa lettura estesa vive solo nella UI dell'app, non nel dato GTFS in sé, che resta interpretabile da un consumer terzo secondo il significato standard (vedi RF-21).

**`stop_times.txt`** — orari per fermata
| Campo | Oblig. | Note MVP |
|---|---|---|
| `trip_id` | ● | FK su `trips.txt`. |
| `arrival_time` | ● | `HH:MM:SS`. Per l'MVP della relazione Modugno⇄Bari rilevano l'orario di **partenza dall'origine** e di **arrivo a destinazione**. |
| `departure_time` | ● | `HH:MM:SS`. Sono ammessi valori ≥ `24:00:00` (gestione standard GTFS), ma **non occorrono** nei dati reali della relazione (né in v1 né in v2): regola mantenuta per robustezza (D-05 chiusa). |
| `stop_id` | ● | FK su `stops.txt`. |
| `stop_sequence` | ● | Ordine progressivo della fermata nella corsa. |

> **Nota MVP:** per ogni corsa servono **almeno** le due fermate della relazione (origine e destinazione). Eventuali fermate intermedie possono essere presenti ma l'app, per l'MVP, mostra solo origine→destinazione e calcola la **durata** come differenza tra arrivo a destinazione e partenza dall'origine.

**`calendar.txt`** — periodicità ricorrente
| Campo | Oblig. | Note MVP |
|---|---|---|
| `service_id` | ● | **Namespaced per operatore** (v2): es. `FAL_FERIALE`, `FAL_FERIALE_NO_AGO`, `TI_FER_LUNVEN`, `TI_FER_LUNSAB`, `TI_FEST_SAB`, … (8 servizi, vedi §1.5/§4-calendario in §6.6). |
| `monday`…`sunday` | ● | `1`/`0` per ogni giorno della settimana. |
| `start_date`, `end_date` | ● | `YYYYMMDD`, finestra di validità del servizio. |

**`calendar_dates.txt`** — eccezioni (festivi infrasettimanali, soppressioni, corse aggiuntive)
| Campo | Oblig. | Note MVP |
|---|---|---|
| `service_id` | ● | FK su `calendar.txt`. |
| `date` | ● | `YYYYMMDD`. |
| `exception_type` | ● | `1` = servizio aggiunto in quella data; `2` = servizio rimosso. |

**`feed_info.txt`** — metadati feed (riferimento di versione)
| Campo | Oblig. | Note MVP |
|---|---|---|
| `feed_publisher_name` | ● | Es. "MVP Orari Modugno-Bari". |
| `feed_publisher_url` | ● | URL pubblicazione. |
| `feed_lang` | ● | `it`. |
| `feed_version` | ● | **Stringa di versione** del feed; deve combaciare con `feed_version` nel manifest (Fase 2). Formato `YYYYMMDD-N` (v1 `20260612-1`; rilascio v2 `20260618-7`). |
| `feed_start_date`, `feed_end_date` | ○ | Inviluppo di validità del feed. Le finestre **per-operatore sono indipendenti** e portate dalle `start_date`/`end_date` dei rispettivi `service_id` in `calendar.txt` (FAL `20251027`→`20261212`; TI `20260614`→`20261212`). |

### 1.3 Struttura del manifest di versione *(Fase 2 — attiva dal 05/08/2026, vedi D-10)*

File JSON pubblicato a un **URL stabile** (`.../releases/latest/download/manifest.json` su GitHub, D-08 chiusa), separato dal feed. È l'unico file letto dall'app a ogni controllo giornaliero. Un `manifest.json` seed era stato prodotto come artefatto iniziale (vedi §6.2/§6.5); in produzione l'app legge il manifest reale pubblicato dalla pipeline.

```json
{
  "schema_version": 1,
  "feed_version": "20260612-1",
  "feed_url": "https://<hosting>/gtfs/gtfs-20260612-1.zip",
  "feed_published_at": "2026-06-12T07:00:00+02:00",
  "feed_valid_from": "2026-06-09",
  "feed_valid_to": "2026-09-15",
  "feed_size_bytes": 18432,
  "feed_sha256": "<hash opzionale per verifica integrità>",
  "min_app_version": "1.0.0",
  "notes": "Nota facoltativa visibile in app, es. 'Orario estivo FAL'."
}
```

| Campo | Oblig. | Significato |
|---|---|---|
| `schema_version` | ● | Versione del **contratto** (questo manifest). Se l'app legge un valore non supportato → mostra avviso "aggiorna l'app", non scarica. |
| `feed_version` | ● | Versione del feed corrente; **chiave del confronto** con la cache. Deve coincidere con `feed_info.feed_version`. |
| `feed_url` | ● | URL assoluto dell'archivio GTFS da scaricare. **Consigliato URL versionato** (con la versione nel nome) per evitare problemi di cache CDN. |
| `feed_published_at` | ● | Timestamp ISO-8601 di pubblicazione. |
| `feed_valid_from` / `feed_valid_to` | ○ | Finestra di validità; l'app può segnalare "orario non più valido" oltre `feed_valid_to`. |
| `feed_size_bytes` | ○ | Per UX (stima download) e sanity check. |
| `feed_sha256` | ○ | Verifica integrità dopo il download. |
| `min_app_version` | ○ | Se l'app è inferiore → invito ad aggiornare. |
| `notes` | ○ | Messaggio informativo facoltativo. |

### 1.4 Logica di aggiornamento dell'app (offline-first, a fasi)

> **Fasi di rilascio (D-10).** L'MVP è partito in modalità **bundle-only** (Fase 1: il GTFS incluso nel bundle come unica fonte, nessun recupero da rete). Dal **05/08/2026** è attiva la **Fase 2** (refresh da rete), che riusa lo stesso contratto e lo stesso parser.
> - **Fase 1 — bundle-only (avvio storico):** l'app leggeva il GTFS solo dagli asset del bundle; versione dati da `feed_info.feed_version` (RF-08); funzionamento interamente offline (RF-06).
> - **Fase 2 — refresh da rete (attiva dal 05/08/2026):** si applica la logica seguente; il bundle resta come feed di **primo avvio/fallback** (D-07) quando la cache non è ancora disponibile.

**Fase 2 — pseudo-flusso refresh da rete** (descrittivo, non codice):

1. All'avvio l'app legge dalla cache locale: `cached_feed_version`, `last_check_date`, e il feed in cache.
2. Se `last_check_date == oggi` → **non** contatta la rete; usa direttamente la cache. (Garantisce "un solo controllo al giorno".)
3. Se `last_check_date < oggi`:
   1. Tenta `GET manifest.json` (timeout breve).
   2. **Se la rete fallisce** → l'app continua a funzionare **offline** con il feed in cache; `last_check_date` **non** viene aggiornato (così riprova alla prossima apertura). Mostra eventualmente un indicatore discreto "dati del <data>".
   3. **Se il manifest è leggibile:**
      - Controlla `schema_version`: se non supportata → avvisa "aggiorna l'app", usa la cache, **non** scarica.
      - Confronta `manifest.feed_version` con `cached_feed_version`:
        - **Uguali** → nessun download; aggiorna solo `last_check_date = oggi`.
        - **Diversi** → scarica `feed_url`, (opz.) verifica `feed_sha256`, valida la struttura minima, e **solo se valido** sostituisce atomicamente la cache, aggiorna `cached_feed_version` e `last_check_date = oggi`. Se il download/validazione fallisce → mantiene il feed precedente, non aggiorna `last_check_date`.
4. Primo avvio / fallback: l'app dispone **sempre** del feed nel **bundle** (decisione D-07/D-10). In **Fase 1** il bundle è l'unica fonte. In **Fase 2**, al primo avvio l'app parte dal bundle e, al primo controllo utile, se il manifest espone una `feed_version` più recente, scarica il feed reale sostituendolo.

> **Invariante:** l'app è sempre utilizzabile finché esiste un feed in cache valido, indipendentemente dalla rete. Il refresh è opportunistico e silenzioso.

> **Nota su cadenza (D-01, riguarda la Fase 2):** gli orari ufficiali cambiano ~2 volte l'anno, quindi i feed reali sono rari. In Fase 2 il controllo giornaliero del manifest resta valido (è leggero e a costo nullo: nei giorni senza nuova versione si risolve in un confronto di stringa senza download) e garantisce che un eventuale nuovo orario venga recepito entro un giorno dalla pubblicazione. In Fase 1 l'aggiornamento avviene rilasciando una nuova versione dell'app con il bundle aggiornato.

### 1.5 Convenzioni e identificatori (vincolanti per la pipeline)

- **Direzioni:** `direction_id = 0` ⇒ verso **Bari**; `direction_id = 1` ⇒ verso **Modugno**. *(Implementato in v1 e v2.)*
- **Stazioni / `stop_id`:** confermato (D-04) che **sia a Modugno sia a Bari esistono due stazioni distinte, una per operatore, in posizioni geografiche diverse**. Quattro fermate fisiche separate: `MOD_TI`, `MOD_FAL`, `BARI_TI`, `BARI_FAL`. `stop_name` disambiguati: **"Modugno"** (TI) / **"Modugno Città"** (FAL); **"Bari Centrale (Trenitalia)"** / **"Bari Centrale (FAL)"**. Coordinate `stop_lat`/`stop_lon` **valorizzate dal rilascio v2** (R-03 chiusa; valori in §6.6).
- **`trip_id` (convenzioni v2):** FAL `FAL_M_HHMM` (verso Modugno) / `FAL_B_HHMM` (verso Bari), con l'orario di partenza; Trenitalia `TI_<numero treno>`. `trip_short_name` = numero treno dove noto.
- **Modello calendario (v2 — supera il modello v1):** **8 `service_id` namespaced per operatore**, perché le regole di esercizio e di agosto differiscono tra FAL e TI:
  - **FAL:** `FAL_FERIALE` (Lun–Sab); `FAL_FERIALE_NO_AGO` (Lun–Sab ma **sospeso tutto agosto** — corse 129 e 116). FAL solo feriale (il festivo è bus sostitutivo, fuori scope).
  - **TI:** `TI_FER_LUNVEN` (Lun–Ven); `TI_FER_LUNSAB` (Lun–Sab); `TI_FEST_SAB` (Sab+Dom+festivi); `TI_SAB_GAP` (solo Sabato, salta 15/08); `TI_SAB_EXCL_AUG` (solo Sabato, salta 8 e 15/08); `TI_GIORNAL` (tutti i giorni).
- **Motore festività nazionali (v2):** le festività italiane (date fisse + Pasqua/Pasquetta da algoritmo) sono **precalcolate dentro il GTFS**: nei festivi infrasettimanali i servizi feriali vengono rimossi (`calendar_dates`, `exception_type=2`) e il festivo TI attivato (`exception_type=1`) — un festivo si comporta come una domenica. **Conseguenza per l'app:** non calcola nulla a runtime; `calendar` + `calendar_dates` restano l'**unica fonte di verità** su quando una corsa circola.
- **`feed_version`:** formato `YYYYMMDD-N`. Identico in `feed_info.txt` e (Fase 2) nel manifest. v1 `20260612-1`; **v2 `20260618-7`** (ordina dopo v1 → riconosciuto come più recente).
- **Bici e accessibilità:** nei **campi GTFS nativi** (`bikes_allowed`, `wheelchair_accessible`); attributi estesi non-GTFS nei **side-car** (vedi §5/§6.6). Valori **tri-stato** (`0` nessuna informazione / `1` sì / `2` no), non booleani. v2: `bikes_allowed=1` per tutte le corse (FAL confermato dal sito FAL); `wheelchair_accessible=1` per TI (documentato) e **`2` per FAL**, valore mantenuto dopo verifica come scelta di modellazione: fermata Modugno accessibile con pedana ma condizionata (fonte FAL 2024) — non un "non accessibile" confermato né un ignoto (R-10, A-10, **D-13 chiusa**).
- **Packaging:** in **Fase 1 (bundle)** i file GTFS sono inclusi come **`.txt` scompattati** in `assets/gtfs/`, stesso parser della Fase 2. In **Fase 2 (rete)** la distribuzione usa l'archivio versionato `gtfs-<feed_version>.zip` con URL versionato.
- **Encoding/locale:** file UTF-8, orari `HH:MM:SS` 24h, date `YYYYMMDD` nel GTFS e `YYYY-MM-DD` nel manifest.

---

## 2. Requisiti funzionali dell'app (prioritizzazione MoSCoW)

### MUST (indispensabili per l'MVP)
- **RF-01** Mostrare, in un'unica lista, le corse Modugno→Bari **e** Bari→Modugno aggregando i due operatori.
- **RF-02** Selezionare la **direzione** (verso Bari / verso Modugno).
- **RF-03** Per ogni corsa visualizzare: operatore, stazione origine/destinazione, orario di partenza, orario di arrivo, **durata**.
- **RF-04** Filtrare/ordinare le corse per **fascia oraria** (almeno: a partire da un orario; default "da adesso in poi").
- **RF-05** Determinare le corse valide **per il giorno selezionato** applicando `calendar.txt` + `calendar_dates.txt` (feriale/festivo/eccezioni). Default: **oggi**.
- **RF-10** Selezionare un **giorno diverso da oggi** (es. domani / scelta data) per consultare gli orari di quel giorno. *(Promosso a MUST su decisione D-09.)*
- **RF-06** Funzionamento **offline** sull'ultimo feed scaricato.
- **RF-07** Refresh **una volta al giorno** secondo la logica §1.4 (lettura manifest, confronto versione, download condizionale). *(**Implementato in Fase 2**, attiva dal 05/08/2026 e verificata end-to-end su device reale. In Fase 1, RF-06 e RF-08 erano comunque soddisfatti dal solo bundle.)*
- **RF-08** Indicare all'utente la **data/versione dei dati** in uso (freschezza).
- **RF-09** Gestire gli **stati limite**: nessuna corsa nella fascia, feed non aggiornato/scaduto, errore di rete, primo avvio (vedi sezione 3 e 4).

### SHOULD (alta utilità, non bloccanti)
- **RF-11** Evidenziare la **prossima corsa** rispetto all'ora corrente.
- **RF-12** Filtro per **operatore** (Trenitalia / FAL / entrambi).
- **RF-13** Indicatore visivo quando il feed è **oltre `feed_valid_to`** ("orario potenzialmente non aggiornato").
- **RF-19** Mostrare l'**attribuzione della fonte dati** (titolare del dato + licenza) nel pannello "Info dati / versione". *Per l'MVP è sufficiente **predisporre lo spazio**; diventa **MUST in caso di pubblicazione**, con testo dipendente dalla licenza effettiva (vedi D-02).*

### COULD (desiderabili, opzionali)
- **RF-14** Pull-to-refresh manuale che forza il controllo del manifest (rispettando comunque l'invariante offline).
- **RF-15** Scorciatoia "inverti direzione".
- **RF-16** Mostrare fermate intermedie quando presenti nel feed.
- **RF-20** Filtro **"trasporto bici"** basato su `bikes_allowed` (dato GTFS nativo, presente in v2).
- **RF-21** Filtro/indicatore **accessibilità** basato su `wheelchair_accessible` (nativo v2), trattando il campo come tri-stato (`0`/`1`/`2`). Per FAL il valore resta `2`, ma è **verificato** (fonte FAL, aprile 2024): la fermata Modugno è accessibile con pedana, **condizionata** a tipologia di carrozzina e preavviso di 24h. Va comunicato come **"accessibile con assistenza su richiesta — verificare la compatibilità con la propria carrozzina e contattare la stazione con anticipo"**, **non** come "non accessibile" confermato né come dato mancante. L'eventuale filtro "solo accessibili" non deve escludere silenziosamente le corse FAL senza segnalare questa condizionalità (rischio di escludere a torto utenti in carrozzina — vedi R-10, A-10, D-13 chiusa).
- **RF-22** Mostrare il **numero treno** (`trip_short_name`) dove disponibile.

### WON'T (esplicitamente fuori MVP — evoluzione futura)
- **RF-17** Real-time (ritardi, binario effettivo). 
- **RF-18** Acquisto biglietti, account, pagamenti, notifiche, altre tratte, iOS.

---

## 3. Casi d'uso / User stories con criteri di accettazione

Formato: *Come utente voglio … così da …* + criteri di accettazione (CA) in stile Given/When/Then.

### UC-01 — Primo avvio senza dati
*Come* nuovo utente *voglio* vedere subito gli orari *così da* non dover configurare nulla.
- **CA-1.1 (Given** app appena installata, strategia bundle attiva **When** apro l'app **Then** vedo le corse del feed seed senza richiedere rete.
- **CA-1.2 (Given** rete assente al primo avvio **When** apro l'app **Then** vedo comunque le corse del feed seed dal bundle (nessun errore tecnico), perché la strategia è seed-in-bundle (D-07).
- **CA-1.3 (Given** primo download riuscito **When** completa **Then** la lista corse si popola e la versione dati è mostrata.

### UC-02 — Consultare gli orari di oggi
*Come* pendolare *voglio* vedere le prossime corse verso Bari *così da* prendere il treno giusto.
- **CA-2.1 (Given** feed valido in cache **When** apro l'app **Then** vedo la lista corse di **oggi**, direzione di default, ordinata per orario, con evidenziata la prossima corsa rispetto all'ora attuale.
- **CA-2.2 (When** cambio direzione **Then** la lista si aggiorna alla direzione opposta.
- **CA-2.3** Ogni riga mostra operatore, partenza, arrivo, durata.

### UC-03 — Refresh giornaliero *(Fase 2 — attiva dal 05/08/2026, D-10)*
*Come* utente *voglio* avere orari aggiornati senza pensarci *così da* fidarmi del dato.
- **CA-3.1 (Given** `last_check_date < oggi` e **manifest con `feed_version` più recente When** apro l'app **Then** l'app scarica e applica il nuovo feed e aggiorna l'indicatore di versione.
- **CA-3.2 (Given** stessa `feed_version` del manifest **When** apro l'app **Then** nessun download; uso la cache; `last_check_date` diventa oggi.
- **CA-3.3 (Given** `last_check_date == oggi` **When** riapro l'app **Then** nessuna chiamata di rete per il manifest.
- **CA-3.4 (Given** `schema_version` non supportata nel manifest **When** controllo **Then** uso la cache e mostro invito ad aggiornare l'app; nessun download.

### UC-04 — Uso offline
*Come* utente in galleria/senza segnale *voglio* comunque vedere gli orari.
- **CA-4.1 (Given** feed in cache e **rete assente When** apro l'app **Then** vedo gli orari dalla cache, con indicatore "dati del <data>".
- **CA-4.2 (Given** rete assente al momento del refresh **When** fallisce il manifest **Then** `last_check_date` non viene aggiornato e l'app riproverà alla prossima apertura.

### UC-05 — Feed non aggiornato / scaduto
*Come* utente *voglio* sapere se sto guardando orari vecchi.
- **CA-5.1 (Given** data odierna oltre `feed_valid_to` **When** consulto **Then** vedo un avviso non bloccante "orario potenzialmente non aggiornato", ma le corse restano visibili.
- **CA-5.2 (Given** disponibile un feed più recente **When** avviene il refresh **Then** l'avviso scompare.

### UC-06 — Nessuna corsa nella fascia richiesta
*Come* utente *voglio* capire chiaramente quando non ci sono treni.
- **CA-6.1 (Given** fascia oraria/giorno senza corse (es. notte, festivo con servizio ridotto) **When** filtro **Then** vedo uno stato vuoto con messaggio chiaro ("Nessuna corsa per <giorno> dopo <ora>") e suggerimento (es. "mostra prima corsa del giorno" o "cambia giorno").
- **CA-6.2** Lo stato vuoto distingue "nessuna corsa" da "errore dati".

### UC-07 — Errore di rete durante il download del feed *(Fase 2 — attiva dal 05/08/2026, D-10)*
- **CA-7.1 (Given** manifest letto con nuova versione ma **download feed fallito When** riprovo **Then** continuo a usare il feed precedente; nessuna corruzione della cache; messaggio non bloccante.
- **CA-7.2 (Given** `feed_sha256` presente e **mismatch** dopo il download **Then** scarto il file scaricato e mantengo la cache.

### UC-08 *(MUST)* — Consultare un altro giorno
- **CA-8.1 (When** seleziono "domani" o una data **Then** la lista applica la periodicità corretta (`calendar`/`calendar_dates`) per quel giorno.

---

## 4. Specifiche di interfaccia concettuali (contenuto, gerarchia, usabilità — niente vincoli estetici)

### 4.1 Inventario schermate (MVP)
1. **Schermata orari (principale)** — unico hub dell'app.
2. **Stato vuoto / errore** — varianti contestuali della principale, non schermate separate.
3. **Dettaglio corsa** *(SHOULD/COULD)* — opzionale, per fermate intermedie.
4. **Info dati / versione** — pannello secondario (bottom sheet o pagina semplice). Ospita: data/versione del feed in uso (RF-08) e l'**attribuzione della fonte dati** (titolare + licenza, RF-19 — vedi D-02). Lo spazio va predisposto fin dall'MVP anche se il testo di licenza è ancora da definire.

> Per un MVP con bacino di decine di utenti, **una sola schermata operativa** è sufficiente. Tutto il resto è secondario.

### 4.2 Schermata orari — gerarchia delle informazioni
Dall'alto verso il basso, in ordine di priorità informativa:
1. **Selettore direzione** (Modugno → Bari / Bari → Modugno) — comando primario, sempre visibile.
2. **Contesto temporale**: **selettore giorno** (default "Oggi", con possibilità di scegliere domani / una data — controllo **MUST**, D-09) + riferimento "da adesso". Filtro fascia oraria e filtro operatore (SHOULD) accessibili ma non invadenti.
3. **Lista corse** (elemento dominante). Ogni **riga corsa** espone, in ordine di lettura:
   - **Orario di partenza** (informazione più saliente);
   - **Orario di arrivo** e **durata**;
   - **Operatore** (Trenitalia/FAL) chiaramente distinguibile (etichetta/segno; nessun vincolo cromatico imposto);
   - eventuale **destinazione/headsign**.
   - La **prossima corsa** rispetto all'ora attuale è evidenziata (SHOULD).
4. **Indicatore di freschezza dati** (data/versione del feed) — discreto, in coda o in intestazione secondaria.

### 4.3 Flussi di navigazione
- **Avvio → schermata orari** (con feed da cache o seed): zero passaggi intermedi.
- **Cambio direzione**: in-place, nessuna navigazione.
- **Cambio giorno/fascia/operatore** (SHOULD): in-place, la lista si ricalcola.
- **Tap su corsa → dettaglio** (opzionale).
- **Refresh**: automatico e silenzioso; pull-to-refresh manuale opzionale (COULD).

### 4.4 Stati limite (come si presentano in UI)
| Stato | Cosa mostra l'utente |
|---|---|
| **Primo avvio, nessun dato, offline** | Stato esplicativo + azione "Riprova" (se strategia download) **oppure** corse seed (se bundle). Mai un errore grezzo. |
| **Offline con cache** | Lista normale + badge "dati del <data>". |
| **Nessuna corsa nella fascia** | Stato vuoto dedicato con messaggio chiaro e azione (es. "mostra prima corsa del giorno"). |
| **Feed scaduto (oltre `feed_valid_to`)** | Banner non bloccante "orario potenzialmente non aggiornato"; corse comunque visibili. |
| **Errore rete in refresh** | Nessuna interruzione; eventuale toast discreto; si continua con la cache. |
| **Schema non supportato** | Invito ad aggiornare l'app; cache usata come fallback. |

### 4.5 Principi di usabilità (vincolanti a livello di contenuto)
- **Offline-first percepito**: l'app non deve "sembrare rotta" senza rete.
- **Una decisione per volta**: direzione → quando → lista.
- **Distinzione operatore sempre leggibile** (l'aggregazione dei due servizi è il valore centrale del prodotto).
- **Stati vuoti informativi**, mai schermate bianche o messaggi tecnici.

---

## 5. Modello dati logico essenziale (mappato sulle entità GTFS)

```
Agency (operatore)            -> agency.txt
  └─ ha molte Route
Route (linea)                 -> routes.txt        [agency_id, route_type=2]
  └─ ha molti Trip
Trip (corsa)                  -> trips.txt          [route_id, service_id, direction_id,
                                                     trip_short_name, bikes_allowed,
                                                     wheelchair_accessible]
  ├─ riferisce un Service (periodicità)
  └─ ha molti StopTime (=2: origine, destinazione)
StopTime (orario per fermata) -> stop_times.txt     [trip_id, stop_id, arrival/departure, stop_sequence]
  └─ riferisce uno Stop
Stop (fermata/stazione)       -> stops.txt          [stop_id, stop_name, stop_lat, stop_lon]
Service (periodicità)         -> calendar.txt + calendar_dates.txt
FeedInfo (versione)           -> feed_info.txt      [feed_version]

[layer esteso, NON-GTFS]
TripAttributes (side-car)     -> *_attributes.json/.csv  (agganciato via trip_id / numero treno)
```

**Entità di dominio per l'app (vista derivata, "Corsa aggregata"):** ottenuta unendo `trips` + `stop_times` (filtrati su origine/destinazione della relazione) + `routes`/`agency` + valutazione `service` per il giorno richiesto. Campi esposti in UI: `operatore`, `stazione_origine`, `stazione_destinazione`, `ora_partenza`, `ora_arrivo`, `durata`, `direzione`, `valida_oggi`.

**Regole di derivazione (vincolanti per l'app):**
- `durata = ora_arrivo(destinazione) − ora_partenza(origine)`; la regola `≥ 24:00:00` resta supportata ma non è esercitata dai dati reali.
- Una corsa è valida per un dato giorno se il suo `service_id` è attivo in `calendar.txt` per quel giorno della settimana **e** non è rimosso (`exception_type=2`) in `calendar_dates.txt`, **oppure** è aggiunto (`exception_type=1`) per quella data. **L'app non calcola le festività**: sono già precalcolate in `calendar_dates` (vedi §1.5).
- L'aggregazione fonde le corse dei due operatori in un'unica lista, ordinata per `ora_partenza`.

**Layer esteso (side-car, non-GTFS).** Attributi non rappresentabili nello standard GTFS sono in file affiancati (`*_attributes.json`/`.csv`), agganciati via `trip_id`/numero treno: categoria treno (Regionale / Regionale Veloce), garanzia in caso di sciopero, prenotazione obbligatoria, binario, **fermata intermedia** (Bari Villaggio del Lavoratore, esclusa dal GTFS, tenuta solo qui), nota di circolazione *verbatim* e `service_pattern` *derivato* (`_derived`, da validare). Sono **opzionali** e pensati per usi futuri dell'app; il GTFS resta autosufficiente per l'MVP.

---

## 6. Dataset: seed di sviluppo e rilascio in bundle

**Obiettivo:** un feed GTFS minimo, **valido e conforme al Contratto Dati (§1)**, trascritto a mano dagli orari ufficiali correnti dei due operatori, sufficiente a coprire tutti i casi d'uso e gli stati limite.

### 6.1 Contenuto minimo
- **`agency.txt`**: 2 righe — `TI` (Trenitalia) e `FAL`.
- **`stops.txt`**: 4 fermate — `MOD_TI`/"Modugno", `MOD_FAL`/"Modugno Città", `BARI_TI`/"Bari Centrale (Trenitalia)", `BARI_FAL`/"Bari Centrale (FAL)".
- **`routes.txt`**: 2 linee — `TI_BA_TA` ("Bari–Taranto"), `FAL_BA_MT` ("Bari–Matera").
- **`calendar.txt`**: `FERIALE` (Lun–Sab) e `FESTIVO` (Domenica, servizio ridotto). Treni che circolano anche nei festivi: modellati come due corse con stessi orari (una `FERIALE`, una `FESTIVO`) — vedi §1.5.
- **`calendar_dates.txt`**: almeno **1 eccezione** (es. una festività infrasettimanale che applica orario festivo) per testare RF-05 e la **selezione di un giorno diverso da oggi** (RF-10/UC-08): il seed deve permettere di verificare almeno un giorno feriale, un giorno festivo e una data con eccezione.
- **`trips.txt` + `stop_times.txt`**: un campione realistico che includa **obbligatoriamente**:
  - corse in **entrambe le direzioni** (`direction_id` 0 e 1);
  - corse di **entrambi gli operatori**;
  - una distribuzione su più fasce orarie (mattina/pomeriggio/sera) per testare il filtro orario e lo stato "prossima corsa";
  - **almeno una finestra senza corse** (per testare UC-06);
  - almeno **una corsa a cavallo della mezzanotte** se presente nel servizio reale (per testare il caso `≥24:00:00`); altrimenti documentarne l'assenza.
- **`feed_info.txt`**: `feed_version` valorizzata (es. `20260612-1`) coerente con il manifest seed.

### 6.2 Manifest seed
Un `manifest.json` seed è stato prodotto con `schema_version=1`, `feed_version` uguale al feed seed, `feed_size_bytes` e `feed_sha256` **reali**. In **Fase 1 (bundle-only) non viene usato**; serve per testare la logica §1.4 in **Fase 2** (casi "stessa versione" / "versione più recente" cambiando manualmente i valori). I campi `feed_url` e `feed_publisher_url` sono attualmente placeholder (`example.com`) da valorizzare alla scelta dell'hosting (D-08).

### 6.3 Quantità indicativa
Bastano ~15–30 corse complessive per coprire i casi. Il volume reale a regime resta comunque piccolo (relazione singola, due operatori), quindi le scelte di performance (§8) valgono già sul seed.

### 6.4 Provenienza e disclaimer (seed v1)
Gli orari del seed v1 erano **estratti da fonti ufficiali correnti** e marcati come tali (datati 12/06/2026), non autorevoli a regime. **Già superati dal feed v2** (§6.6), che è il feed effettivamente distribuito in bundle.

### 6.5 Realizzazione — Seed v1 (`feed_version 20260612-1`, 12/06/2026) *(superato dal rilascio v2, §6.6)*

Il seed è stato **realizzato e validato** (integrità referenziale + regole di dominio MVP), conforme al Contratto Dati §1. Costituisce la concretizzazione della §6.

**Artefatti prodotti:**
- **Dataset seed GTFS v1** — 8 file `.txt`. Contenuto: 2 `agency` (TI, FAL) · 4 `stops` · 2 `routes` (TI_BA_TA, FAL_BA_MT) · **21 `trips`** · **42 `stop_times`** (2 per corsa: origine+destinazione) · 2 servizi in `calendar` (FERIALE, FESTIVO) · 1 eccezione in `calendar_dates` (**Ferragosto 15/08/2026**: rimuove FERIALE, attiva FESTIVO) · `feed_info` con `feed_version`.
- **`manifest.json` seed** con `feed_size_bytes` e `feed_sha256` reali (uso Fase 2 — vedi §6.2).
- **Script generatore riproducibile** del feed.
- **Pacchetto bundle** — cartella `assets/gtfs/` con gli 8 `.txt` scompattati + nota di integrazione Flutter (riferimento `pubspec.yaml`, caricamento via `rootBundle`, lettura versione da `feed_info.feed_version`).

**Provenienza dei dati reali (12/06/2026):**
- **FAL** — dal manifesto in vigore dal 27/10/2025, **entrambe le direzioni**.
- **Trenitalia** — dal quadro orario programmato RFI della stazione Modugno, valido **14/12/2025–13/06/2026**, **solo pomeriggio/sera** e **solo direzione verso Bari**.

**Copertura casi d'uso:** il seed copre direzioni, due operatori, distribuzione su fasce orarie, finestre senza corse (UC-06), feriale/festivo ed eccezione di calendario (RF-05/RF-10/UC-08). Caso `≥24:00:00` **non esercitato**: nei dati reali della relazione non esistono corse a cavallo della mezzanotte (vedi D-05, chiusa).

**Punti lasciati aperti nel seed (nessuna assunzione fatta):**
1. **Coordinate `stop_lat`/`stop_lon` vuote.** Valori candidati da verificare: Bari Centrale ≈ `41.1181, 16.8700`; Modugno Città (FAL) ≈ `41.0861, 16.7789`; posizioni di `MOD_TI` e della sezione FAL a Bari **da rilevare** (R-03).
2. **Copertura Trenitalia parziale:** direzione 1 (Bari→Modugno) e fascia **mattutina** dir 0 non ancora estratte (recuperabili da RFI).
3. **Orario Trenitalia in scadenza il 13/06/2026:** i tempi TI del seed vanno **rinfrescati al cambio orario**.
4. **Manifest:** `feed_url`/`feed_publisher_url` sono placeholder `example.com` (da valorizzare con D-08).

### 6.6 Rilascio — Feed v2 (`feed_version 20260618-7`, 18/06/2026)

Feed **completo da fonti ufficiali**, che **supera il seed v1** e diventa il feed distribuito **in bundle** (Fase 1). `20260618-7` ordina dopo `20260612-1`, quindi in Fase 2 sarà riconosciuto come più recente.

**Copertura (99 corse, 198 stop_times):**

| Operatore | Direzione (`direction_id`) | Corse |
|---|---|---|
| FAL | verso Modugno (1) | 20 |
| FAL | verso Bari (0) | 20 |
| Trenitalia | Modugno → Bari (0) | 29 |
| Trenitalia | Bari → Modugno (1) | 30 |
| **Totale** | | **99** |

FAL solo feriale (festivo = bus sostitutivo, fuori scope). Per Trenitalia solo i treni che **fermano effettivamente a Modugno** (esclusi i Regionali Veloci che saltano la fermata).

**Fonti ufficiali v2:**
- **FAL** — manifesto orario "Da e per Bari" in vigore dal **27/10/2025** (feriale, due direzioni).
- **Trenitalia** — quadri orario RFI per-stazione "Partenze da Modugno" e "Partenze da Bari Centrale", validi **14/06/2026 – 12/12/2026** (pubblicati 14/06/2026).

**Finestre di validità (per-operatore, indipendenti, in `calendar`):** FAL `20251027`→`20261212`; TI `20260614`→`20261212`. Provenienza date: FAL start, TI start e TI end **documentati**; **FAL end (12/12/2026) è ASSUNTO** (nessuna scadenza pubblicata) → da riverificare (A-08/D-11).

**Coordinate stazioni (valorizzate in v2):** `BARI_FAL` 41.118585, 16.8684559 · `MOD_FAL` 41.0864698, 16.7792309 · `BARI_TI` 41.1176638, 16.8693885 · `MOD_TI` 41.0719215, 16.785155.

**Calendario — 8 `service_id` namespaced + motore festività nazionali** (vedi §1.5). Totale eccezioni in `calendar_dates`: **56** (soppressioni agosto FAL + gap estivi TI + festività nazionali sui servizi feriali). Soppressioni estive: FAL 129/116 tutto agosto; TI "solo sabato" 19877/19883/19893 e 19898 saltano il 15/08; TI 19863 salta 8 e 15/08.

**Campi GTFS estesi:** `bikes_allowed=1` su tutte le corse (FAL confermato dal sito FAL, TI documentato); `wheelchair_accessible=1` per TI (carrozza attrezzata documentata), **`2` per FAL**, valore mantenuto dopo verifica (fonte FAL, aprile 2024: fermata Modugno "con pedana", condizionata a tipologia carrozzina e preavviso 24h) come scelta di modellazione, non `0`/ignoto e non "non accessibile" confermato in senso pieno — R-10, A-10, **D-13 chiusa**. Valori tri-stato, non booleani.

**File side-car (non-GTFS):** `ti_modugno_bari_attributes.json/.csv` (29 corse) e `ti_bari_modugno_attributes.json/.csv` (30 corse) — categoria treno, garanzia sciopero, prenotazione, binario, fermata intermedia, nota di circolazione *verbatim*, `service_pattern` *derivato* (da validare). Vedi §5.

**Riproducibilità:** intero feed generato da uno script unico `build_gtfs.py` (incorpora le quattro slice e il motore festività). Pacchetto v2: 8 file `.txt`, README, generatore.

---

## 7. Specifiche della PIPELINE DI INGESTIONE (workstream parallelo)

> Workstream indipendente: il suo unico obbligo verso l'app è **produrre feed + manifest conformi al §1**. Architettura a due livelli **senza server applicativo**.

### 7.1 Fonti da ingerire (identificate e ingerite in v2)
| Operatore | Fonte ufficiale | Formato | Stato |
|---|---|---|---|
| FAL (Bari–Matera, "Modugno Città") | Manifesto orario "Da e per Bari" (in vigore dal 27/10/2025) | Manifesto/quadro orario | 🟢 Ingerita in v2 (feriale, 2 direzioni) |
| Trenitalia ("Modugno") | Quadri orario RFI per-stazione "Partenze da Modugno" e "Partenze da Bari Centrale" (val. 14/06–12/12/2026) | Quadri RFI | 🟢 Ingerita in v2 (solo treni che fermano a Modugno) |

> **Nota di realtà aggiornata (D-01).** La normalizzazione dalle fonti ufficiali (quadri RFI + manifesto FAL) **è stata realizzata** via `build_gtfs.py`, che ha prodotto il feed v2 completo: la pipeline esiste già nella sua forma essenziale (sorgenti → GTFS), incluso il motore festività. Resta valido che il **GTFS ufficiale aperto è ancora in via di definizione**: quando disponibile, potrà **semplificare/sostituire l'adapter sorgente** (GTFS→GTFS invece di quadri→GTFS), senza modificare il Contratto Dati §1.

### 7.2 Processo di normalizzazione verso GTFS
1. **Acquisizione** delle fonti per operatore (quadri RFI per-stazione; manifesto FAL).
2. **Estrazione/parsing** in una struttura tabellare intermedia (corse, fermate origine/destinazione, orari, periodicità, numero treno).
3. **Mappatura** sul modello GTFS (§1.2/§5): `stop_id`, `route_id`, `service_id` (namespaced per operatore), `direction_id`, campi `bikes_allowed`/`wheelchair_accessible` secondo §1.5.
4. **Motore festività + soppressioni estive:** calcolo automatico delle festività nazionali e applicazione delle regole di agosto, generando le eccezioni in `calendar_dates` (vedi §1.5).
5. **Composizione** dei file `.txt` (+ produzione **side-car** attributi) e packaging in `gtfs-<feed_version>.zip` (per la Fase 2; in Fase 1 i `.txt` vanno nel bundle).
6. **Generazione manifest** con `feed_version`, `feed_url`, hash, finestre di validità (Fase 2).

> **Stato:** i passi 1–5 sono realizzati e riproducibili in `build_gtfs.py` (ha prodotto v2). Il passo 6 (manifest reale con URL) è Fase 2.

### 7.3 Schedulazione
- Cadenza reale di aggiornamento dell'orario: **~2 volte l'anno** (D-01). La pipeline si esegue quindi **al cambio orario** (≈ semestrale) e **on-demand** in caso di rettifiche/eccezioni.
- Una schedulazione periodica frequente non è necessaria; resta utile un controllo manuale/periodico che il manifest pubblicato sia integro.
- Nessun processo server: lo script gira in locale e pubblica file statici.

### 7.4 Validazione del dato (gate di qualità prima della pubblicazione)
- **Conformità GTFS** (integrità referenziale: ogni FK risolve; orari ben formati; `feed_version` coerente tra `feed_info` e manifest).
- **Validatori GTFS standard** consigliati come controllo automatico.
- **Controlli di dominio MVP**: presenza di corse in entrambe le direzioni e per entrambi gli operatori; coerenza durate (arrivo > partenza); copertura periodicità feriale/festivo.
- **Regola di pubblicazione**: si pubblica **solo** se la validazione passa; altrimenti il feed precedente resta quello attivo (l'app non deve mai ricevere un feed rotto).

### 7.5 Gestione errori (fonte irraggiungibile o cambiata)
- **Fonte irraggiungibile**: la run fallisce in modo "sicuro", non pubblica nulla, segnala l'errore (log locale); il manifest **non** cambia → l'app continua sull'ultimo feed valido.
- **Fonte cambiata di formato**: il parsing fallisce la validazione → nessuna pubblicazione + alert per intervento manuale (il parsing dei PDF è il punto più fragile, vedi §9).
- **Versionamento**: ogni pubblicazione incrementa `feed_version`; si conservano gli archivi versionati per rollback.

### 7.6 Pubblicazione del feed e aggiornamento del manifest
- **Distribuzione su hosting gratuito** (Firebase Storage/Hosting **oppure** repository GitHub): si caricano `gtfs-<feed_version>.zip` e si aggiorna `manifest.json` (a URL stabile) **come ultimo passo atomico** (prima il feed, poi il manifest, per evitare che l'app legga un manifest che punta a un feed non ancora disponibile).
- Nessun database interrogabile, nessuna Cloud Function, nessun costo.

---

## 8. Requisiti non funzionali (RNF)

- **RNF-01 Freschezza dati**: il dato in app è "teorico/statico". L'orario ufficiale cambia ~2 volte l'anno (D-01): i feed reali sono rari. L'app espone sempre data/versione del feed (RF-08) e segnala il superamento di `feed_valid_to`.
- **RNF-02 Comportamento offline**: l'app **deve** funzionare interamente offline sull'ultimo feed; la rete è usata solo per il controllo/aggiornamento giornaliero (§1.4). Invariante: mai schermata inutilizzabile per assenza di rete.
- **RNF-03 Performance**: apertura e visualizzazione corse percepite come immediate; tutta l'elaborazione è locale su un dataset piccolo. Il refresh non blocca la UI (operazione in background, applicazione atomica).
- **RNF-04 Dimensione del feed scaricato**: contenuta (ordine dei KB–decine di KB per una relazione singola con due operatori). Download condizionale: si scarica solo se `feed_version` cambia (§1.4). `feed_size_bytes` nel manifest consente stima/sanity check.
- **RNF-05 Gestione fasce orarie e festivi**: corretta applicazione di `calendar`/`calendar_dates`; fuso `Europe/Rome` con ora legale/solare. Le **festività nazionali e le soppressioni estive sono precalcolate nel feed** (motore festività, §1.5): l'app **non le calcola a runtime**, legge solo il GTFS. La regola `≥24:00:00` resta supportata ma non esercitata dai dati reali.
- **RNF-06 Robustezza cache**: sostituzione **atomica** del feed; in caso di download/validazione falliti si conserva il feed precedente; nessuno stato intermedio corrotto.
- **RNF-07 Integrità**: se presente `feed_sha256`, verifica post-download; in caso di mismatch si scarta il file.
- **RNF-08 Costo**: zero costi infrastrutturali (hosting gratuito di file statici).
- **RNF-09 Compatibilità contratto**: l'app gestisce `schema_version` in modo difensivo (fallback su cache + invito ad aggiornare se non supportata).
- **RNF-10 Manutenibilità del contratto**: ogni breaking change al feed/manifest incrementa `schema_version` ed è documentato.

---

## 9. Rischi, assunzioni e domande aperte per il committente

### 9.1 Rischi
| ID | Rischio | Impatto | Mitigazione |
|---|---|---|---|
| R-01 | **GTFS ufficiale aperto ancora in via di definizione** (D-01). | Basso (la normalizzazione da fonti ufficiali è già realizzata) | Feed v2 prodotto da `build_gtfs.py` a partire dai quadri RFI + manifesto FAL (§7.1). Il GTFS ufficiale, quando disponibile, semplificherà l'adapter sorgente senza toccare il Contratto Dati. |
| R-02 | **Manutenzione ai cambi orario** (~2×/anno): i quadri RFI/manifesto FAL possono cambiare layout; estrazione da riconvalidare. | Medio (manutenzione pipeline) | Generatore riproducibile (`build_gtfs.py`); validazione pre-rilascio; revisione umana al cambio orario; fallback al feed precedente. |
| R-03 | **Identificazione stazioni/stop.** | *Risolto in v2* | Quattro `stop_id` distinti, `stop_name` disambiguati e **coordinate valorizzate** (§6.6). |
| R-04 | **Caching aggressivo dell'hosting/CDN** sul manifest/feed (Fase 2). | Medio | URL versionati per il feed; cache-control adeguato sul manifest; confronto su `feed_version`. |
| R-05 | **Licenza d'uso dei dati** non ancora nota (attribuzione, ridistribuzione, derivati, uso commerciale). | Medio (legale) | Vedi D-02 esteso (§9.3): predisporre l'attribuzione in UI (RF-19); chiudere **prima della pubblicazione**, rispettando la licenza più restrittiva tra le fonti. |
| R-06 | **Aspettativa di real-time** da parte degli utenti. | Basso | Comunicare chiaramente in UI che gli orari sono teorici (freschezza, RF-08). |
| R-07 | **`end_date` FAL (12/12/2026) assunto** (nessuna scadenza pubblicata). | Basso/Medio | Riverificare periodicamente; se errato, il feed potrebbe mostrare corse FAL oltre la validità reale (A-08/D-11). |
| R-08 | **Festività locali/patronali (Bari/Modugno) non modellate**: si assume che i treni circolino. | Basso | Da rivalutare con il committente (D-12); il motore copre solo le festività nazionali. |
| R-09 | **`platform_bari_centrale` nei side-car** da OCR best-effort. | *Chiuso (03/08/2026)* | Nessuna fonte esterna disponibile per un controllo puntuale: accettato come limite noto. UI aggiornata (`journey_detail_sheet.dart`) con didascalia "indicativo, da verificare in stazione" quando il binario non è verificato; il binario di Modugno resta mostrato senza avviso (dichiarato con certezza dalla fonte). |
| R-10 | **Accessibilità FAL marcata `wheelchair_accessible=2`**, valore mantenuto anche dopo verifica per scelta di modellazione (D-13). Rischio **asimmetrico** residuo: comunicare male la condizionalità (tipologia carrozzina, preavviso) può comunque escludere a torto utenti in carrozzina. | Basso *(da Medio, dopo verifica D-13)* | Comunicare in UI come "accessibile con assistenza su richiesta, verificare compatibilità carrozzina e contattare la stazione con preavviso" (RF-21), non come "non accessibile" né come dato mancante. Fonte: PDF FAL "e le persone con disabilità" (2024). |

### 9.2 Assunzioni
- **A-01** L'MVP riguarda **solo** la relazione Modugno⇄Bari, entrambe le direzioni, due operatori.
- **A-02** Il bacino utenza è dell'ordine delle **decine**; app non pubblicata per ora → hosting gratuito di file statici è adeguato.
- **A-03** GTFS statico è il formato interno; `calendar`/`calendar_dates` coprono feriale/festivo/eccezioni; `feed_version` è il riferimento di versione.
- **A-04** Target MVP **Android**; iOS abilitato per il futuro a costo marginale ma fuori scope.
- **A-05** Il **seed v1** era trascritto a mano e non autorevole; **superato dal feed v2** prodotto da fonti ufficiali (§6.6).
- **A-06** La pipeline gira in locale, su schedulazione **~semestrale (al cambio orario)** più on-demand, senza server applicativo.
- **A-07** Il GTFS ufficiale, una volta definito, sarà rilasciato con una **licenza open** (scenario più probabile in ambito italiano: CC BY 4.0 o IODL 2.0, sola attribuzione), ma la licenza esatta e i suoi vincoli **non sono ancora confermati** (vedi D-02).
- **A-08** L'`end_date` FAL **12/12/2026 è assunto** (nessuna scadenza pubblicata sul manifesto); da riverificare (R-07/D-11).
- **A-09** Le **festività locali/patronali** (Bari/Modugno) non sono modellate: si assume che i treni circolino normalmente (R-08/D-12).
- **A-10** L'**accessibilità FAL per-treno era non documentata**; **verificata** (ago. 2026, fonte FAL 2024): la fermata Modugno è accessibile con pedana, condizionata a tipologia carrozzina e preavviso 24h. Si mantiene `wheelchair_accessible=2` come **scelta di modellazione** (nessun valore GTFS standard rappresenta un "sì condizionato"), **non** perché il dato indichi "non accessibile" confermato. Va presentato come accessibile con assistenza su richiesta, da verificare per la carrozzina specifica (vedi R-10, RF-21, D-13 chiusa).

### 9.3 Decisioni acquisite e domande ancora aperte

**Changelog v1.1 — decisioni del committente recepite:**
- **D-01** — GTFS ufficiale **in via di definizione**; orari che cambiano ~2 volte l'anno. **Esito BA: non bloccante per l'avvio dell'app.** Pipeline da costruire in sequenza formato-agnostica (vedi §7.1 nota, §7.3, R-01). Risolve anche D-03 (frequenza aggiornamento ≈ semestrale).
- **D-04** — Confermate **due stazioni distinte per operatore** sia a Modugno sia a Bari, in posizioni geografiche diverse: quattro `stop_id` separati, distinzione vincolante (vedi §1.5).
- **D-07** — Primo avvio con **feed seed in bundle** (offline garantito) (vedi §1.4 punto 4).
- **D-09** — Selezione di un **giorno diverso da oggi** promossa a **MUST** (RF-10, UC-08, §4.2).

**Changelog v1.2:**
- **D-02** — Approfondita (vedi sotto): aggiunto requisito di attribuzione in UI (RF-19, §4.1) e promemoria licenza.

**Changelog v1.3 — realizzazione seed v1 e modalità a fasi:**
- **Seed GTFS v1** (`feed_version 20260612-1`) realizzato e validato; vedi §6.5 per artefatti, provenienza reale e punti aperti.
- **D-10 (nuova) — Avvio bundle-only a fasi.** In fase iniziale (**Fase 1**) il GTFS è incluso nel bundle ed è l'**unica fonte**; recupero da rete/hosting e manifest rinviati alla **Fase 2**. RF-06 (offline) e RF-08 (versione da `feed_info.feed_version`) restano soddisfatti dal solo bundle; **RF-07 e la logica §1.4 (passi 1–3) slittano alla Fase 2**. Estende D-07 (il bundle resta feed di primo avvio/fallback). Formato bundle: `.txt` scompattati, così lo stesso parser vale in entrambe le fasi. Vedi §1.3, §1.4, §1.5, RF-07.
- **D-05 — CHIUSA.** Nei dati reali della relazione **non esistono corse a cavallo della mezzanotte**; il caso `≥24:00:00` non è esercitato dal seed (documentato in §6.5). La regola di derivazione resta comunque nel contratto (§5) per robustezza futura.
- **D-08 — CHIUSA (04/08/2026).** Hosting scelto: **GitHub** (repo pubblico dedicato `BinarioSudPipeline`, pubblicazione via GitHub Release), non Firebase — nessuna infrastruttura/account aggiuntivo, sufficiente per il volume dati (pochi KB, check giornaliero). Vedi changelog v1.7.

**Changelog v1.4 — rilascio feed v2 (`20260618-7`):**
- **Feed v2 completo da fonti ufficiali** (99 trips, 198 stop_times), che **supera il seed v1** e diventa il feed in bundle (§6.6).
- **Contratto dati esteso:** `trip_short_name`, `bikes_allowed`, `wheelchair_accessible` in `trips.txt`; coordinate stop valorizzate; 8 `service_id` namespaced per operatore; **motore festività nazionali** che precalcola le eccezioni in `calendar_dates` (§1.2/§1.5). Aggiunti **file side-car** non-GTFS (§5).
- **Pipeline realizzata:** normalizzazione quadri RFI + manifesto FAL → GTFS via `build_gtfs.py` (§7.1/§7.2). R-01 declassato; R-02 riformulato (manutenzione ai cambi orario).
- **Nuovi requisiti app (COULD):** RF-20 filtro bici, RF-21 filtro/indicatore accessibilità, RF-22 numero treno.
- **R-03 risolta** (coordinate presenti). Nuovi rischi/assunzioni: R-07/A-08 (FAL `end_date` assunto), R-08/A-09 (festività locali non modellate), R-09 (platform OCR), A-10 (accessibilità FAL).
- **D-06 — sostanzialmente chiusa:** le festività **nazionali** e le soppressioni estive sono modellate nel feed; resta aperto solo l'aspetto **locale/patronale** → confluisce in D-12.

**Changelog v1.5 — allineamento al feed `20260618-7`:**
- **Versione feed allineata a `20260618-7`** (autorevole) in tutto il documento, superando il riferimento intermedio `20260618-6` (§1.2/§1.5/§6.6/Allegato).
- **Accessibilità FAL: `wheelchair_accessible` da `0` a `2`.** Il feed v2 marca FAL `2` come **assunzione conservativa non verificata** ("assunto non accessibile"), non più `0`/ignoto. Aggiornati §1.2, §1.5, RF-21, §6.6 e A-10; obbligo di disclosure preservato (non presentare come "non accessibile" confermato).
- **Esplicitati i valori tri-stato** (`0`/`1`/`2`, non booleani) per `bikes_allowed` e `wheelchair_accessible` (§1.2/§1.5).
- **`bikes_allowed` FAL**: precisato che il `1` è **confermato dal sito FAL** (§1.2/§6.6).
- **Nuovo rischio R-10** (rischio asimmetrico dell'accessibilità FAL marcata `2`) e **nuova domanda aperta D-13** (verifica accessibilità FAL); A-10 riscritta di conseguenza.

**Changelog v1.6 — chiusura D-13 (accessibilità FAL):**
- Reperita fonte ufficiale FAL ("FAL e le persone con disabilità", PDF, aprile 2024): fermata **Modugno "con pedana"**, condizionata (tipologia carrozzina, preavviso 24h).
- **D-13 chiusa**: dato verificato (non più assunzione) + decisione di modellazione presa (valore GTFS `2` mantenuto, testo UI reso specifico sulla condizionalità). Aggiornati §1.2, §1.5, §6.6, RF-21, R-10, A-10.
- R-10 declassato da Medio a Basso (residuo: comunicazione corretta della condizionalità in UI).

**Changelog v1.7 — chiusura D-08/D-11/D-12/R-09 e avvio Fase 2:**
- **D-08 chiusa** (04/08/2026): hosting **GitHub** (repo pubblico `BinarioSudPipeline`), `feed_url`/`feed_publisher_url` valorizzati (non più placeholder `example.com`).
- **D-11 chiusa** (03/08/2026) con nota motivata: nessuna scadenza pubblicata da FAL; `end_date` `20261212` resta un'assunzione ma coerente con il cambio orario nazionale "Orario 2027" (13/12/2026) e con la finestra TI. Da riverificare comunque al prossimo cambio orario (vedi Allegato).
- **D-12 chiusa** (03/08/2026): il committente conferma l'assunzione attuale — nessuna modellazione delle festività locali/patronali in `calendar_dates`.
- **R-09 chiusa** (03/08/2026) come limite noto accettato: nessuna fonte esterna per un controllo puntuale del binario Bari Centrale (OCR); UI aggiornata con didascalia "indicativo, da verificare in stazione" (§9.1).
- **Fase 2 (refresh da rete) attivata** (05/08/2026, D-10): RF-07 implementato secondo la logica §1.4 e verificato end-to-end su device reale con rete vera; manifest salito a `schema_version 2` (aggiunti i side-car via rete, stesso criterio cache→bundle del GTFS); RF-14 (pull-to-refresh manuale) implementato. Aggiornati §1.3, §1.4, RF-07, UC-03, UC-07.
- **Verifica periodica delle fonti orario** (06/08/2026, lavoro nel repo pipeline `BinarioSudPipeline`): né RFI né FAL pubblicano un GTFS/API aperto per questa tratta; realizzato invece un controllo periodico con revisione umana obbligatoria (nessuna pubblicazione automatica) — vedi R-01/R-02 (§9.1).

**Domande chiuse di recente:**

- **D-13 — CHIUSA (ago. 2026).** L'accessibilità in carrozzina FAL è stata verificata tramite fonte ufficiale ("FAL e le persone con disabilità", PDF, aprile 2024): la fermata **Modugno risulta "con pedana"**, ma **condizionata** — assistenza disponibile solo per *"particolari tipologie di carrozzine"*, con preavviso di almeno 24 ore e presentazione in stazione 30 minuti prima della partenza. Non è quindi né un'accessibilità incondizionata (`1` TI) né un'assenza di informazioni (`0`). **Decisione di modellazione (Domanda 2, presa dal committente in questa sessione):** si mantiene `wheelchair_accessible=2` nel GTFS (nessun valore standard rappresenta un "sì condizionato"), mentre la UI dell'app comunica esplicitamente la condizionalità reale ("accessibile con assistenza su richiesta, verificare compatibilità carrozzina e contattare la stazione con preavviso"), evitando sia il messaggio "non accessibile" sia un generico "dato assente". Questa lettura estesa resta locale all'app: un consumer GTFS terzo continuerebbe a leggere `2` secondo il significato standard.
- **D-08 — CHIUSA (04/08/2026).** Hosting: **GitHub**, repo pubblico dedicato `BinarioSudPipeline` — nessuna nuova infrastruttura/account, sufficiente per il volume dati (pochi KB, check giornaliero) via GitHub Releases.
- **D-11 — CHIUSA (03/08/2026).** `end_date` FAL `20261212` resta un'assunzione (nessuna scadenza pubblicata da FAL), verificata come ragionevole: nessun manifesto più recente del 27/10/2025 in vigore, e coerente col cambio orario nazionale "Orario 2027" (13/12/2026, coincide con la finestra TI). Da riconfermare comunque prima del cambio orario di dicembre 2026.
- **D-12 — CHIUSA (03/08/2026).** Festività locali/patronali (San Nicola/Bari, patrono Modugno): il committente conferma l'assunzione attuale (circolazione normale, nessuna modellazione in `calendar_dates`).

**Domande ancora aperte (da sottoporre al committente):**

- **D-02 — Licenza d'uso del dato (promemoria, da chiudere prima di qualunque pubblicazione).**
  *Perché conta:* "open data" non significa "uso libero senza condizioni". L'app **ridistribuisce** l'orario agli utenti e la pipeline lo **trasforma** (sorgente → GTFS, opera derivata): entrambe sono operazioni che la licenza può permettere, vincolare o vietare.
  *Le quattro condizioni da verificare:*
  1. **Attribuzione** — la maggior parte delle licenze open (es. CC BY) impone di citare la fonte. Conseguenza progettuale: l'app deve esporre titolare + licenza nel pannello "Info dati" (RF-19, §4.1). Lo spazio va predisposto già ora.
  2. **Ridistribuzione** — la licenza deve permettere di redistribuire il dato a terzi (gli utenti dell'app).
  3. **Modifica / opere derivate** — la normalizzazione verso GTFS crea un derivato: serve il permesso di trasformazione. Attenzione alle clausole **share-alike** (es. CC BY-SA), che obbligherebbero a pubblicare il feed con la *stessa* licenza.
  4. **Uso commerciale** — alcune licenze lo vietano (es. CC BY-NC). Irrilevante ora (MVP non pubblicato), dirimente in caso di futura pubblicazione/monetizzazione.
  *Avvertenze:*
  - Il caso peggiore non è una licenza restrittiva ma l'**assenza di licenza esplicita**: per default equivale a "nessun diritto concesso" → niente ridistribuzione. È il primo controllo da fare quando il GTFS ufficiale sarà definito.
  - Le fonti sono **due o tre** (Trenitalia, FAL ed eventualmente Regione Puglia come editore), potenzialmente con licenze diverse: il feed aggregato deve rispettare la **più restrittiva** tra quelle coinvolte.
  - Scenario atteso più favorevole: **CC BY 4.0 / IODL 2.0** (sola attribuzione), anche perché la pubblicazione è spinta dal Regolamento UE 1926/2017 (punti di accesso nazionali/regionali alla mobilità). Da confermare sul caso specifico; è collegata a D-01 (licenza non nota finché il GTFS non è definito).
  *Esito:* **non bloccante per l'MVP** (non pubblicato), ma da chiudere **prima della pubblicazione**. Informazioni da raccogliere a GTFS definito: (a) licenza esatta, (b) dicitura di attribuzione richiesta, (c) permessi di redistribuzione e modifica, (d) eventuali vincoli share-alike o non commerciali.

---

### Allegato — Checklist di "definizione completata" per avviare i lavori
- [x] §1 Contratto Dati validato e congelato (incluse convenzioni §1.5), esteso ai campi v2.
- [x] §6 Dataset prodotto e validato: seed v1 (`20260612-1`) → **rilascio v2 completo (`20260618-7`)** in bundle (§6.6).
- [x] Coordinate stazioni rilevate (R-03 risolta); copertura Trenitalia completata (entrambe le direzioni, mattina inclusa).
- [x] Sblocco **Fase 1 (bundle-only)**: app, UX e Flutter procedono sul bundle v2 (D-10).
- [x] Accessibilità FAL `wheelchair_accessible` (D-13) — verificata e chiusa (ago. 2026).
- [x] **Verifiche periodiche residue** — chiuse (03/08/2026): `end_date` FAL (D-11, nota motivata, da riconfermare al cambio orario di dicembre), festività locali/patronali (D-12, confermata dal committente), `platform_bari_centrale` OCR (R-09, limite noto accettato).
- [x] **Fase 2** (refresh da rete) — attiva dal 05/08/2026: D-08 chiusa (hosting GitHub), `feed_url`/`feed_publisher_url` valorizzati, RF-07 e logica §1.4 implementati e verificati su device reale; manifest `schema_version 2` con side-car via rete; RF-14 pull-to-refresh.
- [ ] **Prossimo cambio orario TI/FAL** (12/12/2026): raccogliere i nuovi quadri RFI + manifesto FAL (da metà novembre 2026) e rigenerare il feed con `build_gtfs.py` prima della scadenza.
