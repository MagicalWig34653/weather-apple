# Security-Schnellscan Backend (Radar-Dienst, Swift/Vapor, MariaDB, Swarm)

Stand: 3. November 2026. Art: breiter, lesender Schnellscan (Zweitprüfung zu einem parallelen tiefen Audit). Methode: gezielte Suche (grep), Lesen der relevanten Quellen, Git-Historie nur auf Muster, Prüfung des unkommitteten Stands (Live-Activity). Geprüfter Stand: Backend `main` (HEAD `f359bde`) plus unkommittierte Änderungen (13 geänderte Dateien, `migrations/007_push_activity.sql`, `Sources/RadarCore/PushActivity.swift`, `Tests/RadarCoreTests/PushActivityTests.swift`).

Nicht ausgeführt: keine Builds, keine Tests, keine Netzwerk- oder Live-Prüfung, kein Abgleich gegen CVE-Datenbanken. Alle Befunde sind statisch aus dem Quelltext belegt; Laufzeitverhalten ist als solches gekennzeichnet. Keine Geheimnisse, Domains, IPs oder Nutzerpfade in diesem Bericht.

## Zählung nach Schwere

| Schwere | Anzahl | Hinweis |
|---|---|---|
| Kritisch | 0 | |
| Hoch | 0 | |
| Mittel | 2 | beide `needs_validation` (Netzpfad/Betrieb) |
| Niedrig | 6 | bestätigt statisch |
| Information | 5 | u. a. Datenschutzfragen und positive Kontrollen |

## Top 3

1. **Mittel, needs_validation: Datenbankverbindung ohne TLS.** `Sources/RadarCore/MariaRepo.swift:21` setzt `tlsConfiguration: nil`. Die Konfiguration (`Sources/RadarCore/Config.swift`, `.env.example`) kennt keine DB-TLS-Option. Die MariaDB ist laut Stack extern. Zugangsdaten, Push-Tokens und Secret-Hashes würden über das Netz im Klartext laufen, falls die Verbindung nicht isoliert ist. Konsequenz für die Schwere hängt vom Netzpfad ab, den der Betreiber bestätigen muss.
2. **Mittel, needs_validation: Ingress-Port mit Klartext-HTTP.** `deploy/swarm/stack.yaml:78` veröffentlicht `${RADAR_PORT}` im Ingress-Modus, also auf allen Swarm-Knoten. `docs-site/content/installation.md:184` beschreibt, dass der Reverse Proxy auf `http://<Knoten>:<Port>` zeigt. Das Push-Geheimnis `X-Installation-Secret` läuft damit unverschlüsselt, sobald der Port direkt oder über ein ungesichertes Teilstück erreichbar ist. Die TLS-Terminierung ist außerhalb des Repos und daher nicht belegbar.
3. **Niedrig, bestätigt: Unauthentifizierte Anfragen verbrauchen das globale Budget vor der Prüfung.** In `Sources/RadarCore/PushApi.swift:170` (`global:any`, 3000 je Minute und Replikat) und `:160` (`global:activity`) sowie `:313` (`global:put`, 600 je Minute) wird das Budget verbraucht, bevor die Installations-ID oder das Geheimnis geprüft werden. Wer das Budget ausschöpft, lässt legitime Registrierungen und Testmeldungen mit `429` scheitern. Keine Daten werden preisgegeben. Nur bei `PUSH_ENABLED=true` erreichbar, der Dienst ist standardmäßig aus.

## Alle Befunde

### Mittel

| ID | Ort | Befund | Status | Vorgeschlagene Korrektur |
|---|---|---|---|---|
| M1 | `Sources/RadarCore/MariaRepo.swift:21`; `Config.swift` | DB-Verbindung ohne TLS, keine Konfigurationsoption | needs_validation (Netzpfad) | Optionale TLS-Konfiguration mit Zertifikatsprüfung (z. B. `DB_TLS`, CA-Pfad) und Standard für externe DB; Betreiber bestätigt Netzpfad |
| M2 | `deploy/swarm/stack.yaml:78`; `docs-site/content/installation.md:184` | Ingress-Port im Klartext auf allen Knoten, Proxy-Ziel ist HTTP | needs_validation (Proxy-/Firewall-Setup) | Doku und Stack-Beispiel: Port nur aus dem Proxy-Netz erreichbar machen; Klartext-Hop nur innerhalb vertrauenswürdiger Netze; Hinweis, dass das Geheimnis nur über TLS fließen darf |

### Niedrig

| ID | Ort | Befund | Vorgeschlagene Korrektur |
|---|---|---|---|
| L1 | `Sources/RadarCore/PushApi.swift:160`, `:170`, `:313` | Globale Budgets werden vor Authentifizierung verbraucht; Flood blockiert legitime Push-Registrierung (nur bei aktivem Push). Budget ist je Replikat, nicht gemeinsam | Budget pro Installations-ID vor der globalen Zählung, oder Ratenbegrenzung am Proxy (Hinweis in den Betriebsnotizen); Dokumentieren, dass die Grenze je Replikat gilt |
| L2 | `Sources/RadarCore/PushApi.swift:163` | Kurzroute `/v1/push/subscriptions/<sub>/activity`: Unbekannte Subscription-ID gibt `404`, bekannte gibt `401` (nach Auth-Versuch). Existenz-Orakel für Subscription-UUIDs ohne Geheimnis. UUIDs sind zufällig, daher praktisch gering | Einheitliche Antwort (z. B. `401` für beide Fälle) |
| L3 | `deploy/swarm/update.sh:152`, `deploy/swarm/setup.sh:496` (sourcing); `setup.sh:413`, `:434-436` (Schreiben) | `.env` wird als Shell-Code gesourct; `write_env` schreibt Werte ohne Quoting, u. a. aus den übernommenen `OPERATOR_*`- und `PROXY_LOG_NOTE`-Werten. Eingaben mit `$(...)` oder Backticks würden beim nächsten Deploy ausgeführt. Nur Betreiber-Eingaben, daher gering. `.env.example` nennt die Einschränkung, die Skripte prüfen sie nicht | Werte beim Schreiben korrekt quoten (`printf %q`) oder beim Lesen wie `env_value` in `lib.sh` als Schlüssel-Wert-Paare parsen, nicht sourcen |
| L4 | `Sources/RadarCore/Hashing.swift:4`; `PushApi.swift:301`, `:324`; `migrations/003_push.sql:3` | Installations-Geheimnis wird unsalzt als SHA-256 gespeichert. Der Server prüft nur Länge (32–128) und Zeichensatz, nicht Entropie. Bei DB-Leck und schwachem Client-Geheimnis ist Offline-Raten möglich | Serverseitiger Pepper (HMAC) oder Mindest-Entropie-Vorgabe in der App; kein Blocker, da Client-Geheimnis zufällig erzeugt werden soll |
| L5 | `docs-site/content/seiten.md:9-11`; `docs/status.md` (Zeile 20 im Arbeitsstand) | Produktivdomain in einem öffentlichen Repository. `AGENTS.md` des Backends (Abschnitt Auftrag und Grenzen) verbietet echte Domains im öffentlichen Repo | Domain durch Platzhalter ersetzen oder Konfigurationswert verwenden; Regelverstoß dokumentieren |
| L6 | `Dockerfile:1`, `:10`; `compose.yaml:8`; `.github/workflows/ci.yml:22`; `.env.example:8`; `deploy/swarm/stack.yaml:9` | Images nicht per Digest gepinnt (`swift:6.2-noble`, `ubuntu:noble`, `mariadb:12.3`). Produktiv-Standard ist das bewegliche Tag `edge` | Digests pinnen; für Produktion ein festes `sha-`-Tag als Standard. Actions sind bereits per SHA gepinnt (positiv) |

### Information

| ID | Ort | Befund |
|---|---|---|
| I1 | `Sources/RadarCore/MariaRepo+Push.swift` (`install_*`-Tabellen), `migrations/003_push.sql:4`, `migrations/007_push_activity.sql` | Push-Token, Live-Activity-Start-Token und Activity-Token liegen im Klartext in der DB. Zusätzlich speichert ein Abo die Rasterzelle (`cell_x`, `cell_y`) des Nutzers. Das ist ein Standortbezug, kein Verlauf. Datenschutzprüfung durch den Betreiber nötig (Produktanforderung laut AGENTS: keine Standortverläufe). Verschlüsselung at rest oder Begründung dokumentieren |
| I2 | `Sources/RadarCore/PushApi.swift:55` (Kommentar) | Der Kommentar behauptet „No coordinates“, gespeichert wird aber eine Rasterzelle. Die Aussage ist unpräzise und sollte an I1 angeglichen werden |
| I3 | Abhängigkeiten (`Package.resolved`, `Package.swift`, `docs-site/package.json`) | Versionen fixiert (u. a. vapor 4.122.3, swift-nio 2.104.0, async-http-client 1.36.2, mysql-nio 1.9.2, swift-crypto 3.15.1, marked 15.0.12 exakt). Abgleich mit Sicherheitsberatungen nicht durchgeführt (kein Netzzugriff in diesem Lauf). Vor einem Release nachholen |
| I4 | `Tests/RadarCoreTests/PushTests.swift:709`; `deploy/swarm/setup.sh:155` | Schlüsselmarker nur als Testplatzhalter (`…SECRET`) bzw. Prüfstring. Kein echter Schlüssel gefunden. Git-Historie: keine `.env`-, `.p8`-, `.pem`- oder `.key`-Datei getrackt (nur `.env.example`). Die fünf Marker-Treffer der Historie stammen aus genau diesen Dateien. Inhalt nicht weiter untersucht |
| I5 | `Sources/radar/main.swift` (Logger-Aufrufe, Zeilen 42–155) | Logs enthalten nur Zähler, Run-IDs, Fehlertypen und APNs-Gründe. Keine Token, Koordinaten oder Geheimnisse gefunden (positiv) |

### Positive Kontrollen (bestätigt)

- **SQL:** Alle Werte laufen über Platzhalter (`?`). Dynamische Teile sind Konstanten oder Ganzzahlen (`max(1, limit)`). `DROP TABLE` mit fester Tabellenliste nur im Test-Helfer (`MariaRepo.swift`, `dropAllForTests`).
- **Eingaben:** Slot-Routen prüfen IDs strikt (`TimeUtil.fromID`), Layer-Routen gegen den Katalog (`Api.swift:129-150`). Push: UUID-Prüfung (`canonicalUUID`), Geheimnis-Zeichensatz und Länge (`validSecret`), Token-Format (`validToken`), Body-Grenze 2 KB (`PushGrid.maxBodyBytes`) plus 4 KB auf der Catch-all-Route. Subscription-Eingaben werden gegen feste Wertebereiche geprüft (`validInput`).
- **Autorisierung:** Alle schreibenden Push-Routen prüfen das Installations-Geheimnis vor dem Zugriff. Die Activity-Route prüft zusätzlich, dass die Subscription zur authentifizierten Installation gehört (`target.installationID == installID`, `PushApi.swift` Aktivitätszweig). Fehlversuche werden pro Installation gezählt.
- **HTML:** Seiten escapen Operator-Eingaben (`SitePages.escape`, `multiline`, `mailLink`).
- **Container:** Läuft als Nutzer `radar` (UID 10001, `Dockerfile:19`).
- **Compose:** Entwicklungsdienste sind an `127.0.0.1` gebunden; Entwicklungspasswörter sind offensichtliche Platzhalter.
- **CI:** Top-Level `contents: read`; `packages: write` nur beim Veröffentlichen; kein `pull_request_target`; keine untrusted `${{ github.event… }}`-Werte in `run:`-Blöcken; Actions per SHA gepinnt.
- **Secrets:** DB-Passwort und APNs-Schlüssel als Swarm-Secret (`_FILE`), nicht als Umgebungswert. Test-DB-Zugang nur in CI-Umgebung.

## Unkommittierter Stand (Live-Activity)

Geprüft: `migrations/007_push_activity.sql`, `PushActivity.swift`, `PushApi.swift` (Aktivitätszweig), `MariaRepo+Push.swift`, `main.swift`.

- Keine Token- oder Koordinaten-Logs (I5).
- Neue Tokens werden über `validToken` geprüft, bevor sie gespeichert werden.
- Ownership wird vor jeder Änderung geprüft (L2 ist die einzige Auffälligkeit der Kurzroute).
- Neue Felder `la_start_token` und `activity_token` sind Klartext (I1).
- Kein Fund, der über I1 hinausgeht.

## Empfohlene Reihenfolge

1. M1 und M2 mit dem Betreiber klären (Netzpfad, Proxy, Firewall). Bis dahin: DB-Verbindung nur in isoliertem Netz, Ingress-Port nicht öffentlich.
2. L1 (Budget vor Auth) und L2 (einheitliche Antwort) im Backend beheben, mit Regressionstests in `PushTests.swift`.
3. L3 (`.env` quoten/parsen) und L5 (Domain entfernen) als kleine Änderungen.
4. L4 und I1 als Entscheidung dokumentieren (Pepper, Verschlüsselung at rest, Datenschutztext).
5. Digests pinnen (L6) und Abhängigkeiten vor dem Release gegen Sicherheitsberatungen prüfen (I3).

## Grenzen

- Nicht geprüft: tatsächlicher Netzpfad zur DB, TLS am Proxy, Firewall-Regeln, Verhalten im echten Swarm, Laufzeitverhalten der Rate-Limits über mehrere Replikate.
- Die Rate-Limits sind je Replikat im Speicher. Bei `RADAR_REPLICAS=2` gelten sie effektiv doppelt. Das ist im Code dokumentiert.
- Der tiefe, parallele Audit deckt Befunde dieses Schnellscans möglicherweise anders ab. Dieser Bericht ersetzt ihn nicht.
