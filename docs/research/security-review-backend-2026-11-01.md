# Security-Review Backend (statisch), 1. November 2026

Umfang: Repo `weather-backend` (Swift 6 / Vapor 4.122.3), Stand `main`, rein lesende Code- und Konfigurationsprüfung. Es gab keine Anfragen an den Produktivserver, keine Angriffs- oder Lasttests, und `.env` und APNs-Schlüssel wurden nicht gelesen. Dateien liegen unter `Sources/RadarCore/` (Kürzel: Api, PushApi, MariaRepo+Push, PushRegion, PushService, TimeUtil) und `Sources/radar/main.swift` (main).
Zeilenangaben beziehen sich auf den geprüften Stand. Als "unsicher" markiert ist, was sich statisch nicht belegen ließ.

## Zusammenfassung

Kein kritischer Befund. Besitzprüfung, SQL und Pfadparameter sind sauber. Die Schwächen liegen bei Verfügbarkeit und Ressourcenerschöpfung: Push-Registrierung ohne Gesamtlimit, serverweites Regionenbudget als Angriffshebel, Rate-Limiter vor der Authentifizierung, DB-Pool von nur 4 Verbindungen je Replikat. Das Proxy-Rate-Limit (E7/E8) steht laut Status noch aus und ist die wichtigste Gegenmaßnahme. Diese Befunde sind ohne Proxy-Limit und ohne Firewall auf dem Swarm-Port praktisch ausnutzbar.

## Befunde

### Hoch

**H1. Unbegrenzte Installationen und Abos, Ressourcenerschöpfung (PushApi.swift:36-38, 168-177; MariaRepo+Push.swift:24-38)**
- Szenario: `PUT /v1/push/installations/<neue UUID>` mit beliebigem Secret und Fake-Token legt ohne Besitznachweis eine Installation an. Begrenzt ist nur `globalRegistrationLimit` = 600 je Minute und Replikat (der Zähler liegt im Speicher), bei 2 Replikaten also etwa 1200 je Minute. Das sind rund 1,7 Mio. Installationen pro Tag, jede mit bis zu 10 Abos (`POST` mit je 60 je Minute und Installation).
- Folgen:
  - Die DB wächst unbegrenzt (Purge erst nach 60 Tagen Inaktivität, `PushService.inactivityDays`).
  - `evaluationSubscriptions` lädt nach jedem Lauf alle aktiven Abos in den Speicher (PushService.evaluate), und der Leader rechnet 25 Slots je Abo.
  - Der APNs-Versand für Fake-Tokens läuft in `BadDeviceToken` bzw. `Unregistered`.
- Fix:
  - Ein serverweites Obergrenzen-Budget für Installationen und Abos (z. B. COUNT-Prüfung, bei Überschreitung 503/429).
  - Ein Proof-of-Work, App Attest oder DeviceCheck beim Erstregistrieren, mindestens aber ein Proxy-Rate-Limit je IP.
  - Evaluation in Seiten statt `SELECT` aller Abos.
  - Neue Installationen nur mit einer Frist bis zum ersten gültigen Token-Test aktiv schalten oder nach kurzer Zeit ohne Folgeaufruf löschen.

**H2. Region-Budget als Hebel gegen alle anderen Nutzer (PushRegion.swift:9-11, 18-23; MariaRepo+Push.swift:55-62)**
- Szenario: `maxCellsServerwide` = 2 000 000, `maxCellsPerInstallation` = 8000. Ein Angreifer legt etwa 250 Installationen mit je ein bis zwei Radius-40-Regionen an (nur rund 750 Requests, weit unter dem Limit). Danach liefert der Server allen echten Nutzern `409 region_capacity`, und die Funktion ist für alle blockiert.
- Fix: H1 umsetzen. Zusätzlich darf das serverweite Budget nicht allein durch anonyme Neu-Installationen füllbar sein, etwa durch zusätzliche Bindung an eine Geräteattestierung. Alternativ den Nutzen des Budgets neu denken: Es schützt die CPU-Last, die durch H1 ohnehin entsteht. Eine Last-Obergrenze je Auswertung (Zeitbudget) wäre robuster als eine harte Sperre für Dritte. Zusätzlich die serverweite Summe aus der DB nicht je Request per GROUP BY berechnen (ist selbst teuer, siehe M2).

### Mittel

**M1. Rate-Limiter vor der Authentifizierung, Schlüsseltabelle als DoS-Hebel (PushApi.swift:3-20, 100-107)**
- Szenario: Der Limiter-Schlüssel ist die UUID aus dem Pfad und wird vor der Auth gebildet. Bei 20 000 Schlüsseln (`maxKeys`) in einem 60-Sekunden-Fenster, die alle noch nicht abgelaufen sind, liefert `allow` für jeden neuen Schlüssel `false`. Ein Angreifer mit rund 330 Requests/s mit Zufalls-UUIDs bekommt damit alle neuen Registrierungen und alle Nutzer, deren Schlüssel nicht schon in der Tabelle stehen, auf `429`.
- Zudem laufen unbekannte UUIDs mit falschem Secret trotzdem durch `authenticate` (zwei DB-Roundtrips, Pool 4), siehe M2.
- Fix: Limiter zusätzlich nach Schlüssel `global:any` (Gesamtrate je Replikat) vor der UUID-Prüfung. Schlüsseltabelle mit LRU statt "alles ablehnen". IP-basiertes Limit am Proxy (E7/E8). Fehlversuche (401) gesondert und strenger zählen.

**M2. DB-Pool-Erschöpfung durch billige unauthentifizierte Anfragen (PushApi.swift:230-237; MariaRepo+Push.swift:40-45; Api.swift:139-160; Config DB_POOL_SIZE Standard 4)**
- Szenario: Jede Push-Anfrage mit gültiger UUID und Secret-Format kostet zwei Queries (UPDATE plus SELECT). `GET /v1/status` kostet etwa 8 Queries ungepuffert (`layerLatestPublished` je Ebene, kein Memo wie bei `manifestState`). Zusätzlich verursachen gültig geformte, aber nicht existierende Radar-Slot-IDs je eine DB-Abfrage ohne Negativ-Cache (Api.swift:194-197, 203-206). Mit wenigen hundert Requests/s sind die 4 Verbindungen je Replikat belegt, und Manifeste bzw. Cache-Misses der Radarkarte hängen ebenfalls.
- Fix:
  - `status()` mit `ManifestState` (5 s) memoisieren.
  - Negativ-Cache für fehlende Slots (kurze TTL).
  - Auth mit einer Query (nur SELECT; `last_seen_at` höchstens einmal pro Stunde aktualisieren).
  - Proxy-Rate-Limit.
  - Pool nach Lastmessung erhöhen.

**M3. Swarm-Ingress-Port auf allen Schnittstellen (deploy/swarm/stack.yaml, `ports: published 38090, mode: ingress`)**
- Szenario: Der Port 38090 ist im Swarm auf jedem Knoten erreichbar. Ohne Host-Firewall lässt sich der Reverse-Proxy (TLS, Rate-Limit, Header) umgehen. Das Secret `X-Installation-Secret` liefe dann im Klartext. Der Betrieb ist laut Doku "extern per Zoraxy", die Firewall-Regel ist statisch nicht prüfbar (unsicher).
- Fix: Firewall auf den Proxy-Host beschränken, oder Port-Veröffentlichung an einen internen Overlay-Netzwerkzugang (Proxy im selben Overlay) binden. In der Betriebsdoku als Pflichtschritt führen.

**M4. DB-Verbindung ohne TLS (MariaRepo.swift:19 `tlsConfiguration: nil`)**
- Szenario: Die DB ist laut Stack extern. Passwort, Gerätetokens, Secret-Hashes und alle Abos laufen unverschlüsselt über das Netz, sofern DB und Swarm nicht auf demselben Host oder in einem privaten Netz liegen (unsicher, hängt vom Betrieb ab).
- Fix: `DB_TLS` (verify-full) als Option, Standard "an", sobald die DB nicht lokal ist. Wenn privates Netz: in der Betriebsdoku vermerken.

**M5. Mutierbare Image-Tags und Auto-Ausführung gezogener Skripte (stack.yaml `RADAR_IMAGE_TAG:-edge`; update.sh `--pull-scripts`; CI-Workflows)**
- Szenario: Der Standard-Tag `edge` ist veränderlich; ein kompromittiertes GitHub-Konto oder eine Registry-Übernahme würde über `git pull` auf dem Manager und `docker stack deploy` Code als Root-Nutzer des Managers ausführen. Es gibt weder Image-Signatur noch Digest-Pinning.
- Fix: Tag per Digest (`@sha256:`) oder `sha-<commit>` setzen (update.sh löst `edge` bereits auf `sha-` auf, gut); cosign-Signatur plus Verifikation optional; Branch-Schutz und 2FA für den GitHub-Account, `deploy`-Branch schreibgeschützt für Menschen.

### Niedrig

**L1. Nicht-kanonische Slot-IDs (TimeUtil.swift:40-49; Api.swift:109-128)**
- `Int("+1")` ist gültig, ebenso kann `calendar.date(from:)` nicht-kalenderkonforme Werte normalisieren (Letzteres unsicher). Dadurch führen mehrere URL-Varianten zum selben Slot. Das erzeugt Cache-Schlüssel-Vervielfachung im LRU und doppelte immutable-Antworten im CDN/Proxy-Cache, und es verbreitert den DB-Zugriff aus M2.
- Fix: `TimeUtil.toID(date) == id` nach dem Parsen erzwingen und nur 5-Minuten-Raster im Aufbewahrungsfenster zulassen.

**L2. Kein Eigentumsnachweis für Gerätetokens (PushApi.swift:putInstallation)**
- Wer ein fremdes Token kennt, kann es unter eigener Installation registrieren und der Gerätebesitzer bekäme Pushes. Tokens sind nicht ratbar, daher nur theoretisch. Gegenseite: `410 Unregistered` löscht serverseitig alle Installationen mit diesem Token (`deleteInstallations(token:env:)`).
- Fix: Optional: Token pro (token, env) eindeutig machen und bei neuem Besitzer die alte Installation löschen.

**L3. `BadDeviceToken` löscht die Installation nicht (PushService.swift, dispatch)**
- Veraltete oder falsche Tokens bleiben bis zum Inaktivitäts-Purge (60 Tage) bestehen und verursachen weiter Versandversuche je Auslösung. Bewusst gewählt wegen möglicher Umgebungsverwechslung, aber ohne Zähler.
- Fix: Zähler für aufeinanderfolgende `BadDeviceToken` je Installation; ab z. B. 3 löschen oder deaktivieren.

**L4. Informationsabfluss über `/v1/status` (Api.swift:155)**
- Öffentlich: `revision` (12 Zeichen Commit), aktivierte Ebenen, Push an/aus, `now`. Hilft beim Fingerprinting, kein Geheimnis.
- Fix: `revision` nur bei Bedarf ausliefern; als bewusste Entscheidung dokumentieren.

**L5. Fehlertexte der Testmeldung (PushApi.swift sendTest)**
- Nach erfolgreicher Authentifizierung nennt die Antwort APNs-Gründe (`InvalidProviderToken` usw.) und die Umgebung. Das ist für den Besitzer gedacht und enthält weder Token noch Schlüssel. Ein unbedingt nötiger Detailgrad ist es nur zum Debuggen.
- Fix: Optional: nur Kategorie zurückgeben, Details ins Log.

**L6. Container-Härtung (Dockerfile, stack.yaml)**
- Gut: Nutzer `radar` (UID 10001), keine Shell, kein Home, nur Port 8080, Basis Ubuntu noble ohne Compiler.
- Fehlt: `read_only: true` mit tmpfs, `cap_drop: [ALL]`, `no-new-privileges` (Swarm-Unterstützung je Docker-Version, unsicher), Memory/CPU-Limits stehen standardmäßig auf 0 (unbegrenzt, `RADAR_CPU_LIMIT:-0`, `RADAR_MEMORY_LIMIT:-0`). Basisimages nicht per Digest gepinnt.
- Fix: Limits mit sinnvollen Standardwerten, `cap_drop`/`read_only` erproben, Basisimages per Digest.

**L7. Langsame Verbindungen (main.swift:179-198)**
- Keine App-seitigen Timeouts für Header- und Body-Lesen sichtbar (Vapor/NIO-Standard, nicht im Code konfiguriert; unsicher). Slowloris gegen Replikate ist ohne Proxy-Timeouts möglich.
- Fix: Timeouts am Proxy (Zoraxy) setzen; Vapor `connectionTimeout`/`requestDecompression` nur bei Bedarf.

**L8. Fehlende HTTP-Härtungs-Header (Api.swift)**
- Push- und JSON-Antworten setzen `nosniff` und `no-store`; HTML-Seiten haben CSP und `Referrer-Policy`. HSTS, `X-Frame-Options` usw. liegen beim Proxy (nicht im Repo prüfbar). CORS wird nicht gesetzt (richtig für eine native App).

**L9. Test-/Entwicklungsvorgaben (compose.yaml)**
- Standardpasswörter `dev-only`/`dev-root-only` nur für lokale Entwicklung, Ports an `127.0.0.1` gebunden. Unkritisch, solange nie produktiv verwendet.

## Geprüft und unauffällig

- **Besitzprüfung/IDOR:** Alle Abo-Operationen laufen über `authenticated(...)`, und jede SQL-Operation ist an `install_id` gebunden (`WHERE id=? AND install_id=?`, MariaRepo+Push.swift:94, 104, 111, 117). Fremde Abo-IDs ergeben `404`/`401`. Geheimnis: SHA-256-Hash gespeichert, 32-128 Zeichen aus eng gefasstem Zeichensatz, Vergleich in SQL; kein Unterschied zwischen "unbekannte Installation" und "falsches Secret" (jeweils `401`). Die Registrierung ist race-sicher (`INSERT IGNORE` plus `FOR UPDATE`).
- **Eingabevalidierung:** Zellen im Bereich, Schwellen, Vorlaufzeiten aus Whitelist, Radius 3-40, Anteile aus Whitelist, Locale `de|en`, Token als Hex 32-200 Zeichen, UUIDs kanonisch (36 Byte); Body 4 kB (Vapor) und 2 kB (Code); Abos je Installation 10, Regionen 3, Zellbudget 8000 je Installation. Der Server sieht nur grob gerundete Mittelpunkte (3 x 3 Zellen), keine Koordinaten.
- **SQL-Injection:** Alle Werte per Bind-Parameter. Interpolation nur bei konstanten Spaltenlisten und einem `Int`-Limit (`LIMIT \(max(1, limit))`). Migrationen sind statisch, additiv und idempotent (`IF NOT EXISTS`).
- **SSRF/Path Traversal:** Upstream-URLs entstehen nur aus Config (`WMS_URL`, `EUMETSAT_WMS_URL`, nur Betreiber) und fest einkodierten Konstanten. Nutzerwerte (Ebenen-ID, Run-/Slot-ID) werden gegen `LayerCatalog` bzw. `TimeUtil.fromID` geprüft und dienen nur als DB-Schlüssel; kein Dateisystemzugriff. Download-Obergrenze 8 MB je Upstream-Antwort. APNs-Host fest (`api.push.apple.com`, `api.sandbox.push.apple.com`).
- **Geheimnisse:** `.gitignore` deckt `.env`, `.env.*`, `*.p8`, `*.pem`, `*.key`, `LOCAL_WORKSPACE.md` ab; keine solche Datei im Index. Im gesamten Git-Verlauf (32 Commits) kein PEM-/Token-Fund außer Prüfcode und ein Test-Platzhalter (`-----BEGIN PRIVATE KEY-----SECRET`). Der APNs-Schlüssel wird nur als Swarm-Secret (Overlay) als Datei gemountet; das Image enthält ihn nicht (Dockerfile kopiert nur Binary und `migrations`; `.dockerignore` schließt `.env*` aus). DB-Passwort per Swarm-Secret.
- **Logging:** Keine Zugriffslogs, keine IPs, keine Pfade, keine Koordinaten, keine Tokens. Pushlogs enthalten nur Zähler und Apple-Reasons. Fehler an Clients ohne Details (`503 unavailable`). Ob Vapors Standard-`ErrorMiddleware` bei Abbrüchen (z. B. 413) Pfade protokolliert, ist statisch nicht belegt (unsicher; Pfad enthielte höchstens die Pseudonym-UUID).
- **XSS in öffentlichen Seiten:** Betreibertexte werden escaped, Links nur `https`, CSP `default-src 'none'`, `frame-ancestors 'none'`.
- **APNs:** ES256-JWT, Cache 40 Minuten (innerhalb Apples Vorgaben), Invalidierung bei 403; `410` löscht die Installation(en); `429`/`5xx` mit Backoff und Ablaufzeit; Ablauf (`apns-expiration`) gesetzt; Payload serverseitig erzeugt (keine Nutzerstrings, nur UUID und Zahlen). Testmeldung auf 3/h je Installation begrenzt (je Replikat).
- **Abhängigkeiten:** `Package.resolved` fest eingecheckt; Vapor 4.122.3, swift-nio 2.104.0, async-http-client 1.36.2, swift-nio-ssl 2.37.5, swift-crypto 3.15.1 wirken aktuell. Eine Schwachstellenabfrage (z. B. GitHub Advisory) wurde nicht ausgeführt, da offline-statisch. Kein Dependabot/Audit in CI.
- **CI/Lieferkette:** GitHub Actions per Commit-SHA gepinnt, `permissions: contents: read` als Standard, Schreibrechte nur dort, wo nötig (`packages: write`, `contents: write` im Deploy-Branch-Job).
- **Admin/Debug:** Keine Admin- oder Debug-Endpunkte. Nur `/healthz`, `/v1/status`, öffentliche Seiten, Radar-/Ebenen-Routen und die Push-API. Unbekannte Pfade: `404` ohne Details, `Server`-Header unterdrückt.
- **Container:** Nicht-Root-Nutzer, keine Shell-Anmeldung.

## Empfohlene Reihenfolge

1. Proxy-Rate-Limit (E7/E8) und Firewall auf Port 38090 (M3).
2. Gesamtgrenzen für Installationen/Abos plus Registrierungsschutz (H1, H2).
3. Limiter-Umbau (M1) und billige Auth, `status()`-Memo, Negativ-Cache (M2).
4. DB-TLS-Option (M4), Image-Digest-Pinning (M5), Rest nach Bedarf.

## Nicht geprüft

Laufende Produktivkonfiguration (`.env`, Proxy, Firewall, Zoraxy-Header/TLS), echte Lastgrenzen, Verhalten von Vapor-Logging unter Fehlern, bekannte CVEs der Abhängigkeiten, Datenbankrechte des Anwendungs-Users, die Skripte `setup.sh`/`update.sh` im Detail (nur Stichproben auf Dateirechte und Secret-Umgang: `.env` mit Modus 600, Secret per `docker secret create`).
