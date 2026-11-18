# Rechtsprüfung: Entscheidungen E1 bis E9 und Endfassung der Texte (18.11.2026)

> **KI-gestützte Plausibilitätsprüfung, keine Rechtsberatung.** Auftrag Lino (Board BB266640, 18.11.): „nach bestem Gewissen“ entscheiden, nur Unvermeidbares an ihn. Grundlage: [rechtspruefung-ergebnis.md](rechtspruefung-ergebnis.md) (12.11.), Linos Entscheidungen vom 13.11. an der Karte, Repo-Stand `origin/main` eece1e9, Branches `release/build-49` (359bc84) und `origin/feature/setup-wizard` (de6527c), Backend `origin/main` 230be1a (nur gelesen). Legende: **B** = Primärquelle am 18.11.2026 gelesen, **A** = Annahme/Auslegung, **H** = ungeprüft.

## Übersicht

| # | Thema | Entscheidung | Wer | Risiko danach |
|---|---|---|---|---|
| E1 | Proxy-Logfrist | Keine Frist nötig: Zoraxy-Request-Logging ist aus (Lino 13.11.). Text: Proxy verarbeitet die IP nur für die Dauer der Anfrage. Zoraxy-Statistik ist ebenfalls aus (Lino, Antwort FC5AA218, 18.11.2026; Aussage, nicht live geprüft) | Agent | gering |
| E2 | Proxy-IP in App Privacy | Keine Angabe (IP wird nicht aufbewahrt). Statistik ist aus (Lino, Antwort FC5AA218, 18.11.2026) | Agent | gering |
| E3 | Diagnose-Text in der App | (a) korrigiert (Lino 13.11.; im Code seit 14.11.) | Lino | gering |
| E4 | Standort-Kategorie | (a) vorerst „Precise und Coarse“, später nur „Coarse“ (Lino 13.11.) | Lino | gering |
| E5 | Impressum/Anschrift | Impressum mit eigener ladungsfähiger Anschrift, E-Mail, Telefon optional (Lino) | Lino liefert Angaben | gering |
| E6 | DSA-Händlerstatus | „kein Händler“ (Lino) | Lino trägt in Connect ein | gering |
| E7 | Hetzner-AVV | Standard-AVV im Hetzner-Konto (Lino); deckt den Proxy-Server mit ab, wenn er im selben Konto läuft | nur Lino (Abschluss) | gering, sobald abgeschlossen |
| E8 | Veraltete Doku-Seite | Durch Verweis auf showers.linolaske.de/datenschutz ersetzt (Lino; Commit 2ef5447, nicht deployt) | Agent | gering |
| E9 | Anwalt | Kein Anwalt, da E1, E3, E5 und E7 erledigt sind bzw. werden (Lino) | Lino | gering bis mittel (Restrisiko) |

**Von Lino fehlt nur:** Abschluss des Hetzner-AVV (Angaben liefert der Orchestrator) und DSA-Status in Connect. Betreiberangaben (`OPERATOR_*`) sind gesetzt und die Zoraxy-Statistik ist aus (Lino, Antwort FC5AA218, 18.11.2026; Aussage, nicht live geprüft).

**Fertige Texte (alle ENTWURF bis Linos Freigabe, nichts veröffentlicht):** [Teil A Datenschutzerklärung, Teil B App Privacy, Teil H Impressum, Teil I Support](../datenschutz-entwurf-release.md); App-Strings als Vorschlag: [rechtstexte-app-aenderungen.md](rechtstexte-app-aenderungen.md); Doku-Seite: `docs-site/content/datenschutz.md`.

**Folgeaufgaben (keine Lino-Aufgaben):** Backend `SitePages.swift` auf Teil A, H, I bringen (Backend-Agent, dann Deploy durch Lino); App-Strings nach [rechtstexte-app-aenderungen.md](rechtstexte-app-aenderungen.md) mit dem nächsten Build; Setup-Wizard vor dem Merge (Vorauswahl, Text, Datenschutz-Link).

---

## E1 Proxy-Logfrist

**Entscheidung.** Keine Frist im Text, weil der Proxy für die Showers-Domains nichts mehr protokolliert. Teil A Abschnitt 3: „verarbeitet technisch bedingt deine IP-Adresse, aber nur für die Dauer der Anfrage: Für den Showers-Dienst führt er keine Zugriffsprotokolle und keine Statistik mit IP-Adressen.“ Rechtsgrundlage weiterhin Art. 6 Abs. 1 lit. f DSGVO.

**Begründung.** Lino hat am 13.11. das Request-Logging für die Domain abgeschaltet (Kommentar an der Karte). Zoraxy hat dafür je Proxy-Regel getrennte Schalter: `DisableLogging` („Disable logging of reverse proxy requests“) und `DisableStatisticCollection` („Disable statistic collection for this endpoint“) (B: https://raw.githubusercontent.com/tobychui/zoraxy/main/src/mod/dynamicproxy/typedef.go). Das Statistikmodul zählt je Tag unter anderem `RequestClientIp` und `RequestURL` und speichert die Tageszusammenfassung in seiner Datenbank (B: https://raw.githubusercontent.com/tobychui/zoraxy/main/src/mod/statistic/statistic.go; eine Löschfrist ist dort nicht erkennbar, H). Bei Push-Aufrufen enthält die URL die Installationskennung (`decisions.md`). Ist nur das Logging aus, die Statistik aber an, stimmt der Satz „keine Statistik mit IP-Adressen“ nicht. Im Backend selbst werden keine IP-Adressen verarbeitet: kein Treffer für `X-Forwarded-For`, `X-Real-IP`, `remoteAddress` o. Ä. in `Sources/` (B, Code gelesen); Ratenbegrenzung je Installation bzw. global ohne IP (`Config.swift`, `PushRateLimits`; B). Speicherbegrenzung (Art. 5 Abs. 1 lit. e DSGVO) ist mit „keine Speicherung“ erfüllt (A).

**Risiko.** Gering; Statistik aus laut Lino (Antwort FC5AA218, 18.11.2026), nicht live geprüft. Nicht geprüft: tatsächliche Zoraxy-Konfiguration, Zoraxy-Fehler- und Systemlogs (können IPs bei TLS-Fehlern enthalten, H).

**Wirkung auf Texte.** Teil A Abschnitt 3 und 8 (Widerspruch bezieht sich auf Abschnitte 3 und 4); `INFO_PRIVACY_3` („befristet protokolliert“ → „nicht protokolliert“, Vorschlag 1); Backend: `PROXY_LOG_NOTE` leer lassen.

## E2 Proxy-IP in App Privacy

**Entscheidung.** Keine Angabe für die IP-Adresse in App Store Connect (Teil B Hinweis 10).

**Begründung.** Apple: „if an authentication token or IP address is sent on a server call and not retained, or if data is sent to your servers then immediately discarded after servicing the request, you do not need to disclose this“ (B: https://developer.apple.com/app-store/app-privacy-details/, 18.11.2026). Nur gespeicherte IP-Adressen sind „based on how you use IP address“ zu deklarieren (B, ebenda).

**Risiko.** Gering (E1 erfüllt, Lino, Antwort FC5AA218, 18.11.2026).

**Wirkung.** Teil B Zeile 3 und Hinweis 10.

## E3 Diagnose-Text und E4 Standort-Kategorie (Lino, 13.11.)

E3 (a): `DEVICE_LINK_FOOTER`/`DEVICE_LINK_PRIVACY` nennen die auf etwa 1 km gerundete Position (am 18.11. im Code geprüft, B). E4 (a): Manifest und Teil B behalten „Precise und Coarse“; nach Apples Definition (Precise = mindestens drei Dezimalstellen, B) wäre „Coarse“ genau, „Precise“ übererfüllt. Umstellung später in einem eigenen Build zusammen mit Connect.

## E5 Impressum und Anschrift (Lino: eigene ladungsfähige Anschrift)

**Entscheidung.** Impressum nach Teil H mit `[OPERATOR_NAME]`, `[OPERATOR_ADDRESS]` (Straße, Hausnummer, PLZ, Ort, kein Postfach), `[OPERATOR_EMAIL]`; Telefon `[OPERATOR_PHONE]` optional. Kein „Verantwortlich für den Inhalt“ (kein journalistisch-redaktionelles Angebot, A). Keine Angaben zu Verbraucherstreitbeilegung oder OS-Plattform (kostenlose App, kein entgeltlicher Vertrag; A).

**Begründung.** § 5 Abs. 1 DDG: „Namen und die Anschrift, unter der sie niedergelassen sind“ und „Angaben, die eine schnelle elektronische Kontaktaufnahme und eine unmittelbare Kommunikation mit ihnen ermöglichen, einschließlich der Adresse für die elektronische Post“ (B: https://www.gesetze-im-internet.de/ddg/__5.html). Ob eine kostenlose App eines Einzelnen „geschäftsmäßig“ ist, bleibt offen; das Impressum ist die vorsichtige Wahl (A). Art. 13 Abs. 1 lit. a DSGVO verlangt Name und Kontaktdaten des Verantwortlichen ohnehin (A, Gesetzestext aus Kenntnis). Neben der E-Mail verlangt der EuGH einen zweiten schnellen Weg; ein Kontaktformular oder Telefon auf Anfrage kann genügen (A, EuGH C-298/07 aus Kenntnis, nicht abgerufen). Die Support-Seite verweist zusätzlich auf GitHub. Eine Telefonnummer senkt das Restrisiko, ist aber keine Pflicht (A).

**Risiko.** Gering mit vollständigen Angaben. Ohne Angaben zeigt das Backend den Warnhinweis `missingNotice`, das wäre ein offensichtlicher Mangel (B, `SitePages.swift`).

**Wirkung.** Teil A Abschnitt 1, Teil H, Teil I.

## E6 DSA-Händlerstatus (Lino: „kein Händler“)

**Begründung.** Apple: Der Entwickler muss selbst einschätzen, ob er „trader“ ist; Faktoren sind u. a. Einnahmen (In-App-Käufe, Bezahl- oder Werbe-Apps), Werbung für eigene Produkte, Umsatzsteuer-Registrierung und Entwicklung „in a professional or business capacity“; ein Hobby-Entwickler ohne Kommerzialisierungsabsicht „may not be considered a trader“. Nicht-Händler geben keine Kontaktdaten an; EU-Verbraucher werden informiert, dass Verbraucherrechte nicht gelten (B: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/). Showers ist kostenlos, ohne Werbung und Käufe (B, Code).

**Risiko.** Gering. Restrisiko (A): Wird die App als Referenz für eine berufliche Tätigkeit als Entwickler beworben oder später monetarisiert, Status neu bewerten.

**Wirkung.** Keine Textänderung; Eintrag in Connect durch Lino.

## E7 Hetzner-AVV (Lino: Standard-AVV)

**Entscheidung.** Standard-AVV im Hetzner-Kundenkonto. Vorschlag für Anlage 1 (Auswahl beim Abschluss): Datenarten „IP-Adressen/Verbindungsdaten“, „Geräte- und Installationskennungen (Push-Token)“, „Standortdaten (grob, Rasterzelle)“; Betroffene „Nutzer der App“ (A, Kategorienliste im Konto nicht gesehen).

**Begründung.** Hetzner: AVV „direkt in deinem Kundenaccount abschließen“ (accounts.hetzner.com/account/dpa), Einverständnis per Checkbox, vorher Datenarten und Betroffenenkategorien festlegen; keine individuellen AVV; Vorlage https://www.hetzner.com/AV/DPA_de.pdf (B, Suchtreffer-Auszüge von https://docs.hetzner.com/de/general/company-and-policy/data-protection-at-hetzner/, Seite nicht vollständig abgerufen). Der AVV kommt laut AGB nicht automatisch zustande (B nach Prüfung 12.11.). Art. 28 Abs. 3 DSGVO verlangt einen Vertrag (A).

**Risiko.** Mittel bis zum Abschluss, danach gering. Teil A Abschnitt 7 nimmt an, dass auch der Proxy bei Hetzner in Deutschland läuft (A, `decisions.md` nennt Docker Swarm und Hetzner-vServer); Bestätigung durch Lino mit der Frage an der Karte.

**Wirkung.** Teil A Abschnitt 7 (Proxy ergänzt).

## E8 Veraltete Doku-Seite (Lino: Verweis)

Umgesetzt im Branch: `docs-site/content/datenschutz.md` enthält nur noch Verweise auf `/datenschutz`, `/impressum`, `/support` (Commit 2ef5447). **Nicht deployt:** Änderungen unter `docs-site/` lösen beim Push auf `main` den Pages-Deploy aus; der Branch wird nicht nach main gemergt, bis Lino freigibt. Risiko danach gering (keine zwei widersprüchlichen öffentlichen Aussagen).

## E9 Anwaltliche Prüfung (Lino: kein Anwalt, wenn Proxy/Diagnose/Impressum/AVV erledigt)

Stand 18.11.: Diagnose erledigt (E3), Proxy erledigt (E1, Lino, Antwort FC5AA218, 18.11.2026), Betreiberangaben gesetzt; offen nur der Hetzner-AVV. Danach Restrisiko gering bis mittel (A): Die Texte beruhen auf Code-Lesen, nicht auf Laufzeitmessung; die Rechtsfragen sind KI-Auslegung. Kein Anwalt nötig nach Linos Vorgabe.

---

## Teil C bis G des Entwurfs: Entscheidungen

| Punkt | Entscheidung | Begründung / Quelle |
|---|---|---|
| C 4b Backups | Kein Satz im Text | Entscheidung 10.11.; Löschung in Backups folgt deren Rotation (A) |
| C 4c/4d AVV, Proxy-Ort | siehe E7 | Lino |
| C 5b Installationskennung in der App | erledigt | Commit `f45cfe8` (B) |
| C 12 EUMETSAT-Jahr | „2026“, jährlich anpassen | EUMETSAT Data Policy (Prüfung 12.11.) |
| C 13/14 Proxy | siehe E1, E2 | |
| C 15 Aufsichtsbehörde | allgemeiner Hinweis genügt | Art. 13 Abs. 2 lit. d verlangt das Beschwerderecht, keine bestimmte Behörde (A) |
| D Abweichungen zur Live-Seite | Teil A ersetzt die Live-Fassung vollständig; Backend-Aufgabe | `SitePages.swift` origin/main 230be1a gelesen (B): Live-Text sagt noch „protokolliert sie befristet“ |
| E Warnungen | unverändert vorbereitet, nicht im Release-Text | Warn-Push aus bis DWD-Antwort (`decisions.md`) |
| F Plausibilität | übernommen; R1 bis R9 bleiben gültig | |
| G 1, 2 | siehe E1, E2 | |
| G 3 Push-Rechtsgrundlage | Einwilligung (lit. a) bleibt; Dialoge um Installationskennung und Widerruf ergänzen | Art. 7 Abs. 3 Satz 3 DSGVO (A); Vorschläge 2 bis 4 |
| G 4 § 25 TDDDG | Ausnahme Abs. 2 Nr. 2 greift; ein Satz in Teil A Abschnitt 4 zur Transparenz | Prüfung 12.11. (B Gesetzestext) |
| G 5 Apple/Drittland | Standardvertragsklauseln nennen (Teil A Abschnitt 5) | Apple Privacy Policy (Prüfung 12.11., B) |
| G 6 Diagnose | Einwilligung passt; Text korrigiert (E3) | |
| G 7 Hetzner | siehe E7 | |
| G 8 Impressum | siehe E5 | |
| G 9 Datenschutzbeauftragter | keine Benennungspflicht, keine Angabe | § 38 BDSG (Prüfung 12.11., B) |
| G 10 Direktabrufe | Rechtsgrundlage lit. b/f in Teil A Abschnitt 4 ergänzt | EuGH C-40/17 (A, aus Kenntnis) |
| G 11 Englische Fassung | keine englische Datenschutzseite; Teil A-EN nicht weiterpflegen | Backend `SitePagesEN.swift`: „There is no English privacy page: the app is offered in Germany only“ (B); App-Verfügbarkeit in Connect auf Deutschland beschränken (Lino, beim Einreichen). Wird die App später in weiteren Ländern angeboten, Teil A übersetzen |
| G 12 Rasterzelle | als personenbezogenes Datum behandeln (Teil A Abschnitt 5) | Art. 4 Nr. 1 und 5 DSGVO (A) |

## Änderungen seit 12.11. mit Datenschutzbezug

| Änderung | Befund | Wirkung |
|---|---|---|
| `radar_eu` (OPERA) | Gesamtbilder je Zeitpunkt vom Showers-Dienst (`/v1/layers/<id>/`), kein Ort, kein Direktabruf aus der App (B: `RadarLayer.swift`, `allowedHosts` nur `maps.dwd.de`, `view.eumetsat.int`). Backend holt OPERA-Daten über MeteoGate (B: `OperaRender.swift`). OPERA-Komposits stehen unter CC BY 4.0, Namensnennung verlangt (B: https://eumetnet.github.io/openradardata-documentation/ORD_HVD_summary/); ein fester Wortlaut für die Namensnennung wurde nicht gefunden (H) | Teil A Abschnitt 3 („Regen in Deutschland und Europa“) und 9; Impressum Teil H |
| `radar_world` (NOAA RRQPE) | nicht im Backend, nicht live (B: Kommentar `RadarLayer.swift`) | vorbereitete Zeile in Teil A und H; Lizenz NOAA nicht geprüft (H: US-Behördendaten meist gemeinfrei) |
| Setup-Wizard (`feature/setup-wizard`) | `SETUP_LOCATION_BODY` sagt „Der Standort bleibt auf dem Gerät“ (falsch, Punkt geht an DWD); `SETUP_ALERT_BODY` ohne Installationskennung und Widerruf; Wizard wählt Orte vor und ruft `push.enable` ohne Bestätigungsdialog (B, Code gelesen) | Vorschläge 4 bis 6 in [rechtstexte-app-aenderungen.md](rechtstexte-app-aenderungen.md); vor dem Merge beheben |
| „Daten veraltet“ / Prognose-Takt (Build 49) | Punktprognose bei geöffneter App etwa im 5-Minuten-Raster mit kurzen Wiederholungen beim DWD (B: `ForecastRefreshPolicy.swift`); keine neue Datenart, kein neuer Empfänger | Teil A Abschnitt 4: „bei geöffneter App regelmäßig neu“ |
| Build 47/48/49-Texte (Empfindlichkeit, Kartenwahl, Quellzeile) | ohne Datenschutzbezug | keine |
| Attribution (OPERA, NOAA, ESA WorldCover, DWD, EUMETSAT, BKG) | App zeigt die Quellzeilen unter „Datenquellen“ aus dem Manifest bzw. `INFO_MODEL_*`, `INFO_SOURCES_*` (B) | Teil A Abschnitt 9 und Teil H angeglichen |

## Nicht geprüft

Live-Seiten (`/datenschutz`, `/impressum`, `/support`) nicht abgerufen; tatsächliche Zoraxy-Konfiguration, Zoraxy-Fehlerlogs und alte Logdateien; Hetzner-Konto, AVV-Formular und Kategorienliste; App Store Connect (Formular, DSA, Verfügbarkeit); NOAA-Lizenz; Laufzeitverhalten (keine Builds, keine Tests, keine Netzmitschnitte). EuGH- und DSGVO-Fundstellen mit „aus Kenntnis“ wurden nicht abgerufen. Verwendet am 18.11.2026: 3 Websuchen, 6 Abrufe.
