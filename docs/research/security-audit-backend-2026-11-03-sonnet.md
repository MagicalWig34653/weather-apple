# Security-Audit Backend (tief, statisch), 3. November 2026

Umfang: Backend-Repo (Swift/Vapor, MariaDB, Swarm), Stand `main` (Commit `f359bde`) plus ungeprüfter Arbeitsbaum der Live-Activity-Änderung (`migrations/007_push_activity.sql`, `PushActivity.swift`, Änderungen an `Apns`, `Api`, `PushApi`, `PushModels`, `PushService`, `Repo`, `MariaRepo*`, `MemoryRepo+Push`, Tests, `docs-site/content/api.md`). Rein lesend: keine Anfragen an Live-Systeme, keine Exploits, keine Builds oder Tests ausgeführt (Sandbox-Anforderungen für Zielcode nicht erfüllbar), `.env` und `.p8` nicht gelesen. Pfade relativ zum Backend-Repo. "Unsicher" kennzeichnet nicht statisch belegbare Annahmen. Frühere Befunde: `docs/research/security-review-backend-2026-11-01.md`.

## Zählung

| Schwere | Anzahl | IDs |
|---|---|---|
| Kritisch | 0 | |
| Hoch | 1 | A1 |
| Mittel | 4 | A2, A3 (Rest von H1/H2), A4 (M3/M4 offen), A5 (M5/L6 offen) |
| Niedrig | 4 | A6 bis A9 |
| Informativ | 3 | I1 bis I3 |

## Top 3

1. **A1 (Hoch, Laufzeit nicht gemessen):** Die Live-Activity-Auswertung führt eine N+1-Abfrage über alle Abos mit `live_activity=true` ein, und zwar vor dem normalen Alert-Versand im selben Tick. Jeder anonym angelegte Nutzer kann das Flag ohne Token setzen. Reguläre Regenalarme können dadurch verzögert werden. Zugleich wird die seitenweise Auswertung (frühere Härtung) umgangen.
2. **A3 (Mittel):** Die Obergrenzen aus H1/H2 begrenzen den Ressourcenverbrauch, lassen sich aber von einem anonymen Angreifer füllen (`503 server_full` für alle neuen Nutzer, 60 Tage lang). Ein Besitznachweis (App Attest) fehlt weiterhin.
3. **A4/A5 (Mittel, offen aus dem Vorbericht):** Ingress-Port auf allen Schnittstellen, DB ohne TLS (`tlsConfiguration: nil`), veränderlicher Standard-Tag `edge`, keine Container-Härtung oder Ressourcenlimits.

Die AuthN/AuthZ der neuen Activity-Endpunkte ist sauber (kein IDOR, SQL und APNs-Topic/Payload ohne Injektion). Details unten.

## 1. Neue Live-Activity-Änderung

### Geprüft und unauffällig (mit Beleg)

- **AuthN der Endpunkte.** `PUT/DELETE /v1/push/subscriptions/<sub>/activity` löst nur den Besitzer auf und schreibt den Pfad auf `installations/<owner>/subscriptions/<sub>/activity` um (`Sources/RadarCore/PushApi.swift:157-167`). Danach läuft die Anfrage durch dieselben Limits (`:168-176`) und `authenticated(...)` (`:216`, Funktion bei `:293-304`). Das Geheimnis wird per SHA-256 in SQL verglichen (`MariaRepo+Push.swift:47-59`). Ohne gültiges Secret gibt es `401`, die Fehlversuche werden pro Installation gezählt (`f:`-Schlüssel).
- **AuthZ/IDOR.** Im geschachtelten Pfad prüft der Handler zusätzlich `target.installationID == installID` (`PushApi.swift:217`). Das ergibt `404` für fremde Abos. `writeActivity` bindet jede Abfrage an den aus der DB gelesenen Besitzer (`MariaRepo+Push.swift:285-300`). Ein Angreifer mit eigener Installation kann weder fremde Activity-Zeilen lesen noch ändern. Das Token wird nie ausgeliefert.
- **`live_activity_start_token`.** Es wird erst nach erfolgreichem `upsertInstallation` gesetzt (`PushApi.swift:325-333`). Dort wird das Secret bei bestehender Installation per `FOR UPDATE` geprüft (`MariaRepo+Push.swift:34-37`). Ein falsches Secret ergibt `.forbidden` und schreibt nichts. Typ- und Formatprüfung: Hex, 32 bis 200 Zeichen, gerade Länge, kleingeschrieben (`validToken`, `:120-125`). `null` löscht, fehlendes Feld lässt es unverändert.
- **SQL-Injection.** Alle neuen Werte sind Bind-Parameter. Interpoliert werden nur Konstanten (`subColumns`, `dateOut`) und ein `Int`-Limit (`MariaRepo+Push.swift:262-282`). Die Migration ist statisch und idempotent (`migrations/007_push_activity.sql`). Der Fremdschlüssel `fk_push_activity_sub ... ON DELETE CASCADE` räumt beim Löschen des Abos oder der Installation auf.
- **APNs-Topic und Payload.** Das Topic ist `config.push.topic + ".push-type.liveactivity"`, nur aus Betreiberkonfiguration (`Apns.swift:~131-137`). Das Token fließt in die URL, ist aber durch `validToken` auf `[0-9a-f]` beschränkt, daher keine Pfad- oder Header-Injektion. Die Payload besteht aus Zahlen, festen Strings und der serverseitig erzeugten Abo-UUID (`PushActivity.swift:22-35`). Der Alert-Text ist statisch, der Content-State auf 4096 Byte begrenzt. `collapse-id` hat 45 Byte (Limit 64).
- **Replay, Rotation, Deadline.** Token-Rotation verlängert `ends_at` nicht (`writeActivity` aktualisiert nur `activity_token`). Eine abgelaufene Activity ist nicht re-registrierbar (`.notEligible`). 410-Antworten löschen nur das passende Token (`matchingToken`, rotationssicher). Eine parallele Reservierung wird durch `FOR UPDATE` auf die Installationszeile serialisiert, höchstens eine Activity je Installation.
- **Geheimnisse in Logs.** Alle Logzeilen enthalten nur Zähler, Apple-Reason-Strings (auf 64 Zeichen gekürzt) und `type(of: error)` (`Sources/radar/main.swift:148-157`). Keine Tokens, Pfade oder Secrets. Unsicher: das Log-Level der MySQL-Bibliothek (`Logger(label: "radar.db")`, `MariaRepo.swift:26`). Im Produktionsmodus ist es voraussichtlich `notice`, ein Debug-Level würde Bind-Werte (Tokens, Secret-Hashes) protokollieren. Dies ist nicht belegt.

### Befunde

**A1. Hoch (unter Vorbehalt): Live-Activity-Auswertung ist N+1 über alle Opt-in-Abos, läuft vor dem Alert-Versand und umgeht die seitenweise Auswertung**
- Belege:
  - `PushService.swift:73,111,126,132-134`: `activityWork` sammelt alle Abos mit `liveActivity` aus allen Seiten im Speicher. Die frühere Härtung begrenzte den Speicher bewusst auf eine Seite. Danach ruft `evaluateActivity` je Abo `repo.activityTarget` auf (`PushActivity.swift:43`).
  - `MariaRepo+Push.swift:262-275`: `activityTarget` kostet 3 Abfragen (Abo, Installation, Activity), `activityTargets` (`:276-282`) ruft sie zusätzlich je Treffer auf.
  - `PushService.swift:50` und `PushActivity.swift:58-74`: `expireActivities` läuft bei jedem 15-s-Tick (`main.swift:157`) und blättert durch alle Abos mit `enabled=1 AND live_activity=1 AND kind=0` (auch ohne Activity). Je Seite à 50 sind das etwa 150 Abfragen plus `acquireLeader`. Das passiert vor `evaluate` und `dispatch`.
- Szenario: Der Angreifer legt anonym Installationen an (`PUT`, kein Besitznachweis) und je Installation bis zu 10 Ortsabos mit `"live_activity": true` (`POST`). Ein Start-Token oder Activity-Token ist dafür nicht nötig (`PushApi.swift:127-148`). Bei z. B. 20 000 Abos fallen je Tick etwa 60 000 Abfragen an, bei der Grenze von 400 000 Abos etwa 1,2 Mio. Der Leader hält die Lease (sie wird je Seite verlängert) und kommt erst danach zu `evaluate` und `dispatch`. Dadurch werden alle regulären Regen-Alerts verzögert oder verhungern. Zusätzlich verbraucht jede Radar-Auswertung denselben Aufwand erneut und der Speicher wächst mit der Zahl der Opt-in-Abos. Ohne Angreifer tritt derselbe Effekt allein durch viele echte Nutzer mit aktivierter Live Activity auf, nur später.
- Unsicher: Die Laufzeit pro Abfrage wurde nicht gemessen. Die Einstufung "Hoch" gilt, wenn 10 000 oder mehr Opt-in-Abos zu Ticks über etwa 15 s führen (bei etwa 1 ms je Abfrage ab etwa 5000 Abos). Mit Pool 4 je Replikat konkurriert das zusätzlich mit der öffentlichen API.
- Behebung:
  - `expireActivities` darf nur Zeilen aus `push_activity` mit abgelaufenem `ends_at` oder Opt-out per JOIN laden (eine Abfrage mit allen nötigen Spalten, kein Aufruf von `activityTarget` je Zeile). Die Bedingung `s.live_activity=1 AND s.enabled=1` ohne Activity-Zeile gehört nicht in diese Schleife.
  - `evaluateActivity` je Seite innerhalb der Auswertungsschleife ausführen, mit einer Sammelabfrage (`WHERE subscription_id IN (...)`, JOIN auf `push_install`), und nur für Abos, die einen Start (`notify`) auslösen oder eine Activity-Zeile besitzen. Dafür `activityWork` verwerfen.
  - Activity-Versand getrennt vom Alert-Versand (eigene Zeitbudgets, Alerts zuerst), damit er den Alert-Pfad nie blockiert.
  - Zusätzlich `PUSH_MAX_ACTIVITY_SUBSCRIPTIONS` oder die Bedingung, dass `live_activity=true` erst mit vorhandenem Start-Token zulässig ist (`la_start_token IS NOT NULL`).
  - Index `push_sub(live_activity, enabled)` oder eine gefilterte Abfrage, damit nicht die ganze Tabelle gelesen wird.
- Regressionstest: Ein Test mit z. B. 5000 Opt-in-Abos, der die Abfragezahl pro Tick prüft und dass `dispatch` im selben Tick läuft.

**A6. Niedrig: Kurzer Activity-Pfad fragt die DB vor der Authentifizierung und räumt vor `global:any` ein**
- Beleg: `PushApi.swift:157-167`. Zuerst `global:activity` (3000/min und Replikat), dann `activityTarget` (bei unbekannter UUID 1 Abfrage, bei bekannter 3), erst danach `global:any` und das Limit je Installation. Das widerspricht der früheren Empfehlung M2 "keine unauthentifizierten Mehrfach-Abfragen".
- Szenario: Zufalls-UUIDs ergeben 3000 Abfragen/min je Replikat bei Pool 4, aber ohne Treffer nur je 1 Abfrage. Wirkung gering, aber vermeidbar. Die UUID ist 122 Bit zufällig, die 404/401-Unterscheidung ist daher kein praktikables Existenz-Orakel (siehe I1).
- Behebung: Den Besitzer-Lookup auf eine Abfrage beschränken (`SELECT install_id FROM push_sub WHERE id=?`, nicht `activityTarget`), den Negativfall mit einem kurzen Negativ-Cache beantworten und `global:any` vor dem Lookup zählen.

**A7. Niedrig: Reservierung ohne Token ist für den Besitzer nicht löschbar, und eine unklare Startantwort blockiert acht Stunden**
- Beleg: `DELETE` verlangt ein passendes Token (`PushApi.swift:218-223`, `deleteActivity(..., matchingToken:)` löscht mit `activity_token=?`). Eine Reservierung hat `activity_token=NULL` und ist per API nicht entfernbar. `.retry` auf Start behält die Reservierung bewusst (`PushActivity.swift:100-103`).
- Szenario: Nach einem transienten APNs-Fehler (`429/5xx`) bleibt die Installation bis zu 8 Stunden ohne neue Live Activity (`ends_at`). Nur Selbstschaden, keine Grenzverletzung. Dazu passt: Das Ende wird bei fehlendem Token ebenfalls erst durch `expireActivities` erledigt.
- Behebung: Bewusst dokumentieren oder `DELETE` ohne Token zulassen, wenn `activity_token IS NULL`. Optional Reservierungen ohne Token nach z. B. 15 Minuten freigeben.

**A8. Niedrig: `BadDeviceToken` auf das Start-Token löscht das Start-Token nicht**
- Beleg: `PushActivity.swift:104-106`. Bei `.badToken/.rejected` für `.start` wird nur die Reservierung gelöscht, `la_start_token` bleibt. Es folgt bei jeder weiteren Benachrichtigung ein neuer Startversuch (bis zum Inaktivitäts-Purge nach 60 Tagen). Begrenzt durch den Alert-Zustandsautomaten, daher gering.
- Behebung: Bei `badToken` für `.start` ebenfalls `clearLiveActivityStartToken(matchingToken:)` aufrufen (wie bei `410`) oder einen Fehlerzähler führen.

**A9. Niedrig: `docker-publish` läuft ohne CI-Gate**
- Beleg: `.github/workflows/docker-publish.yml` startet bei `push` auf `main` unabhängig von `ci.yml` (kein `needs`, kein `workflow_run`). Ein Commit mit rotem Test wird als `edge` und `sha-<commit>` veröffentlicht, `update.sh` löst `edge` auf das neueste `sha-` auf.
- Behebung: `workflow_run` mit Bedingung `conclusion == 'success'` oder die Tests im Publish-Workflow als Vorstufe. Branch-Schutz mit erforderlichen Statusprüfungen.

**I1 (informativ):** Der kurze Activity-Pfad unterscheidet `404` (Abo unbekannt) und `401` (Secret falsch). Das ist ein Existenz-Orakel für Abo-UUIDs, aber nicht ratbar (UUID v4). Die Dokumentation (`api.md:119`) beschreibt das Verhalten korrekt.

**I2 (informativ):** Kennt jemand eine Abo-ID (sie wird nur dem Besitzer geliefert), kann er über den kurzen Pfad mit falschem Secret den Fehlversuchszähler der Besitzer-Installation hochtreiben (`f:`-Schlüssel, 10 je Minute) und deren authentifizierte Aufrufe kurz mit `429` sperren. Das ist dieselbe Wirkung wie bei bekannter Installations-UUID; ein praktischer Angriffsweg besteht nur nach Leck der ID.

**I3 (informativ):** Ein authentifizierter Besitzer kann ein beliebiges gültig geformtes Hex-Token als Activity-Token registrieren (kein Bindung an Gerät oder App). Der Versand läuft dann mit dem Provider-Token des Betreibers zu diesem Token, höchstens eine Activity je Installation und nur Inhalte des Betreibers. Das entspricht dem Verhalten beim Gerätetoken (früher L2), kein neuer Hebel.

## 2. Verifikation der früheren Härtung (Commit `89731b8`)

| Befund | Greift im Code? | Beleg und Rest |
|---|---|---|
| H1 Obergrenzen | Ja, mit Rest A3 | Installationen: `Config.swift:39,170` (100 000), COUNT in der Transaktion `MariaRepo+Push.swift:27-33`, `503 server_full` (`PushApi.swift:339`), Parität im `MemoryRepo+Push.swift:53`. Abos: `MariaRepo+Push.swift:103`. Seitenweise Auswertung: `PushService.swift:80-125` (jetzt durch A1 teilweise umgangen). |
| H2 Regionenbudget | Ja, mit Rest A3 | Budget 50 Mio. Zellen (`PushRegion.swift:12`), 30-s-Memo (`MariaRepo+Push.swift:82-92`, Invalidierung bei Löschen und Änderung). Kein GROUP BY je Request. |
| M1 Limiter | Ja | `PushApi.swift:3-52`: `global:`-Schlüssel in eigener, nie verdrängter Tabelle, Verdrängung des ältesten Zehntels statt Ablehnung, Gesamtrate `global:any` vor der UUID-Prüfung (`:170`), Fehlversuche `f:` (Limit 10) strenger. Zählungen sind je Replikat im Speicher (bei 2 Replikaten doppelt). |
| M2 DB-Pool | Ja | Auth mit einer Abfrage und `last_seen_at` höchstens stündlich (`MariaRepo+Push.swift:47-59`), `/v1/status` mit 5-s-Memo (`Api.swift:160-161`), Negativ-Cache für fehlende Slots (`Api.swift:17-68`, TTL 10 s). Pool-Größe weiterhin 4 (`stack.yaml DB_POOL_SIZE`). |

Neue Schwachstelle gegenüber dieser Härtung: A1 (N+1 und unbegrenzter Speicher in der Auswertung) und A6 (Abfrage vor `global:any`).

**A3. Mittel: Rest von H1/H2, Kapazität lässt sich anonym füllen**
- Belege: `PushApi.swift:313-340`, `MariaRepo+Push.swift:27-33,103`, `PushService.swift:inactivityDays=60`.
- Szenario: `PUT /installations/<UUID>` braucht keinen Besitznachweis. Mit `globalRegistrationLimit` 600/min und Replikat (bei 2 Replikaten etwa 1200/min) sind 100 000 Installationen in etwa 1,5 bis 3 Stunden erreicht, mit je 10 Abos auch das Abo-Limit (400 000). Danach liefert der Server allen echten neuen Nutzern `503 server_full`, und die Zeilen bleiben bis zu 60 Tage bestehen (Purge nur nach Inaktivität). Dauerhaft kann ein Angreifer mit etwa 10 Anfragen/s auch `global:put` auf `429` halten und so neue Registrierungen blockieren.
- Behebung (beschränkte Schritte vor App Attest): Installationen ohne Abo nach z. B. 24 Stunden löschen, Installationen mit Abo-Anzahl 0 beim Zählen für die Obergrenze nicht berücksichtigen oder getrennt begrenzen, Proxy-Rate-Limit je IP, App Attest/DeviceCheck für die Erstregistrierung.

## 3. Konfiguration und Deployment

**A4. Mittel (unverändert aus M3/M4): Port und DB-Transport**
- `deploy/swarm/stack.yaml:75-80`: Port 38090 im Modus `ingress` auf jedem Swarm-Knoten. Eine Firewall ist statisch nicht prüfbar (unsicher). Ohne sie ist der Reverse Proxy (TLS, Rate-Limit) umgehbar, und `X-Installation-Secret` läuft im Klartext.
- `Sources/RadarCore/MariaRepo.swift:21`: `tlsConfiguration: nil`. Die DB ist laut Stack extern, Passwort, Tokens und Secret-Hashes laufen unverschlüsselt, sofern kein privates Netz besteht (unsicher). Behebung: `DB_TLS` mit Verifikation, Firewall-Pflicht dokumentieren oder Port nur an das Proxy-Overlay binden.

**A5. Mittel (unverändert aus M5/L6): Lieferkette und Container-Härtung**
- `stack.yaml:12` Standard-Tag `RADAR_IMAGE_TAG:-edge` (veränderlich). `update.sh` löst `edge` auf `sha-<commit>` auf (`lib.sh find_newest_sha_tag`, geprüft per Digest, gut), `setup.sh` empfiehlt einen festen Tag. Aber Standardwert und Mutabilität bleiben, kein cosign, kein Digest-Pinning. `update.sh --pull-scripts` führt per `git pull --ff-only` neue Skripte aus der `deploy`-Branch aus.
- `Dockerfile:10`: `ubuntu:noble` und `swift:6.2-noble` ohne Digest. `stack.yaml:85-86`: CPU- und Speicherlimits standardmäßig `0`. Kein `read_only`, kein `cap_drop`, kein `no-new-privileges` (Swarm-Unterstützung unsicher).
- Positiv: Nicht-Root-Nutzer (UID 10001), keine Shell, keine Compiler im Laufzeit-Image, Secrets (`db_password`, `apns_key`) als Swarm-Secrets und Dateien (`stack.yaml:67`, `stack.push.yaml`), `.env` Modus 600 (`setup.sh:407-447`), `.gitignore` und `.dockerignore` schließen `.env*`, `*.p8`, `*.pem` aus, `git ls-files` enthält nur `.env.example`. `.env.example` enthält nur Platzhalter. Die Skripte parsen `.env` nicht per `source` (`setup.sh:74`), außer `update.sh:152`, wo die Datei vom Betreiber stammt.
- CI: Alle Actions sind per Commit-SHA gepinnt, `permissions: contents: read` als Standard, Schreibrechte nur in den Jobs, die sie brauchen, keine PR-Trigger mit Secrets, keine `${{ }}`-Interpolation von Nutzereingaben in `run:`. Siehe A9 für das fehlende Gate.

Nicht geprüft (statisch nicht möglich): laufende Produktivkonfiguration, Proxy, Firewall, Zoraxy-Header/TLS, DB-Rechte des Anwendungsnutzers (die Migration 007 braucht `ALTER` und `CREATE`; laut Dokumentation dem Migrationsnutzer, der Laufzeitnutzer benötigt weiterhin nur DML, aber das ist in `stack.yaml` nicht getrennt, der gleiche `DB_USER` wird für `serve` und `migrate` genutzt), bekannte CVEs der Abhängigkeiten (keine Abfrage), Tests (nicht ausgeführt), Laufzeitmessungen zu A1.

## Empfohlene Reihenfolge

1. A1 beheben, bevor 007 ausgerollt wird (Sammelabfrage, Auswertung je Seite, Activity-Versand getrennt und nachrangig).
2. Start-Token-Pflicht oder Obergrenze für `live_activity=true`.
3. A3: Registrierungsschutz (Bereinigung leerer Installationen, Proxy-Limit, später App Attest).
4. A4/A5 gemäß Vorbericht (Firewall, DB-TLS, Digest-Pinning, Limits).
5. A6 bis A9 bei Gelegenheit.
