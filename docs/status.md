# Fortsetzbarer Arbeitsstand

Stand: 28. Oktober 2026, 18:17 Uhr MEZ, nach erfolgreicher Uploadannahme von Build 4. **ShowerNow `0.1.0 (3)`**, Bundle-ID **`de.linolaske.showernow`**, Team `J2DU2P47XW`, wurde aus dem veröffentlichten Quellencheckpoint `2e500fca7be7df05bbe21882127d574189a5a0d1` genau einmal erfolgreich hochgeladen. Uploadabschluss um 17:51:38 Uhr MEZ: Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded` und Apples `UPLOAD SUCCEEDED with no errors`. Der damalige Uploadserverzustand war **`PROCESSING`**. **Neue Nutzerbestätigung: Build 3 funktioniert intern über TestFlight und wurde im Alltag verwendet.** Dies belegt die interne Nutzbarkeit durch Nutzerfeedback; eine neue direkte ASC-Abfrage wurde nicht durchgeführt. Die offiziellen AppsService-Antwortdaten bestätigen `name=ShowerNow`, `bundleId=de.linolaske.showernow`, `removed=false`. Projekt/Module heißen technisch weiter Weather.

Historie unter `de.linolaske.weather`: Build 1 wurde mit `90474` abgelehnt; Build 2 zu Checkpoint `0f48cb5` wurde mit Exit 0 angenommen (`PROCESSING`, 17:35:36 Uhr MEZ). Zusätzlich berichtet der Nutzer einen Namenskonflikt mit Weather. Dies bestätigt keinen nutzbaren internen TestFlight-Build; [historische Uploadbefunde](testflight-upload.md) bleiben erhalten.

## Freigabe und Arbeitsweise

Entwicklung ist freigegeben. App zuerst, Backend nach einer nutzbaren App. Zuerst ein brauchbarer interner iPhone-TestFlight-Build, Widgets und Watch danach; größere Plattform-Roadmap in `plan.md`.

Der Hauptagent koordiniert ausschließlich. Neue abgegrenzte Aufgaben erhalten frische Agents; unabhängige Arbeit läuft mit klaren Dateizuständigkeiten parallel. Verbindliche Details stehen in `AGENTS.md` und `team.md`. Entscheidungen, Ergebnisse und nächste Schritte bleiben im Repo; Sessions dürfen keinen Chatverlauf voraussetzen.

## Repository und lokale Konfiguration

- Dieses Repo: https://github.com/MagicalWig34653/weather-apple
- Schwesterrepo: https://github.com/MagicalWig34653/weather-backend
- Private lokale Pfade ausschließlich in der ignorierten `LOCAL_WORKSPACE.md`; öffentliche Vorlage `LOCAL_WORKSPACE.example.md`.
- Die ursprünglichen Einrichtungskopien sind keine aktiven Arbeitsverzeichnisse. Fachliche Entscheidungen und Fortschritte bleiben versioniert.

## Implementierter iPhone-Prototyp

- XcodeGen-Projekt mit relativen Dateireferenzen, Swift 6, iOS 27 und zentraler Produktidentität in `Configuration/Base.xcconfig`.
- Native MapKit-Radarkarte mit expliziten DWD-Datenläufen, tatsächlichen vergangenen Analyseframes, Vorhersage, Play/Pause und farblich sichtbarer Zeitgrenze.
- Direkte DWD-Punktprognose als kleine JSON-Serie; kein eigener Server und kein HDF5-Download auf dem Gerät. Datenvertrag in `data-contract.md`.
- Datenalter, fehlende Daten, Netzfehler und Messung/Vorhersage getrennt. Texte altern regelmäßig mit; alte Daten dürfen keine aktuelle Trocken-Zusage erzeugen.
- Ortssuche, Kartenpunktauswahl, lokale Ortsnamen, Speichern, Umbenennen und Löschen. Optionaler Standort nur bei Nutzung, keine Hintergrundortung.
- Swift Charts für den Niederschlagsverlauf, Detailansicht und verständliche Quellen-/Datenschutzhinweise.
- Punktprognosen/Index im Speicher, Radar-Tiles im begrenzten Memorycache. Alte Overlay-Requests werden bei Wechsel abgebrochen. Kein Festplatten-Netzwerkcache für Punktanfragen.
- Ortswechsel invalidiert alte Anfragen synchron; manueller Refresh kann auch bei identischem Datenlauf fehlgeschlagene Tiles erneut laden. Die Review-Fixes sind kompiliert; Ortsablauf und abschließende Light-/Dark-Sichtprüfung sind erfolgreich abgeschlossen. Ein frisches unabhängiges Review bestätigt beide Korrekturen ohne offene P1-/P2-Befunde.

Dies ist ein früher Prototyp, keine fertige Version 1. Die interne TestFlight-Nutzbarkeit von Build 3 ist inzwischen durch den Nutzer bestätigt.

## Aktuelle Aufgabe: Alltag, Ladezeit, Glass und lokale Einordnung

Nutzerfeedback vom 28. Oktober 2026: ShowerNow funktioniert intern über TestFlight, lädt aber eher langsam. Freigegeben sind gezieltes Caching, eine konkrete Simulatorprüfung und ein kompakterer schwebender Liquid-Glass-Zeitslider mit weniger Text. Eine dezente lokale Einordnung mit Apple Foundation Models soll bei belegter Machbarkeit umgesetzt werden. Das ursprüngliche Konzept bleibt erhalten; Backendänderungen gehören nicht zu dieser Aufgabe.

Die drei Ergebnisaufgaben sind integriert: Radar-Timeline wird unabhängig von der Punktprognose veröffentlicht; parallele identische Punkt-/Tileanfragen werden zusammengeführt, vorhandene Speichergrenzen und Aktualitätsregeln bleiben erhalten. Zwei kompakte schwebende native Glasflächen ersetzen das große untere Panel. Eine manuelle lokale Einordnung in den Details priorisiert ausschließlich validierte Wetterfakten; Standardtext und Hauptprognose sind unabhängig vom Modell.

- [Performancebefund und Regressionen](performance.md): synthetische parallele Punktabfragen vorher 2, jetzt 1; Radarstart mit angehaltener Punktantwort geprüft. Kein Diskcache, kein pauschales Frame-Prefetch und keine Standort-/URLhistory.
- [UI-Umsetzung, Apple-Quellen und sichere Vorher-/Nachheraufnahmen](app-glass.md): Light/Dark und Accessibility Extra Large geprüft; Attribution bleibt frei.
- [Lokale Einordnung und Grenzen](research/foundation-models.md): echte Foundation-Models-API integriert, acht gezielte Tests bestanden. Live-Beispiel trocken/ein Fakt: Standardtext sichtbar, Modellrequest gespart. Echte Modellgeneration und konkreter Simulator-Availabilitygrund sind nicht belegt; generischer Unavailablepfad injiziert getestet.
- Integrierter iPhone-18-Pro-Simulatorstand: **26 Daten-/Logiktests, null Fehler** (18 DWD/Cache/Store, acht Einordnung). Drei UI-Flows (Datenschutz, Orts-CRUD, Radarbedienung) erfolgreich; nach KI-Integration betroffenen Radar-/Detailsflow gezielt erneut bestanden. Kein nachträglich behaupteter kompletter gemeinsamer UI-Grünlauf.
- Quellen-/Testdateien des finalen UI-Prüfsnapshots stimmen bytegleich mit dem integrierten Stand überein. Anschließender gezielter Build nach Projektaufnahme und Buildnummeränderung erfolgreich; keine redundante Wiederholung der unveränderten Tests.

**Aktueller Kandidat: ShowerNow `0.1.0 (4)`**. XcodeGen hat die neuen Einordnungs-/Testdateien ins eingecheckte Projekt aufgenommen; Version, Bundle-ID, Team, Icon und bestehende Gerätefamilien-/Orientierungsmetadaten bleiben erhalten. Gezielter Simulatorbuild mit Buildnummer 4 erfolgreich. Das gebaute Bundle bestätigt ShowerNow / `de.linolaske.showernow`, `0.1.0 (4)`, Familie `[1,2]`, drei iPhone-/vier iPad-Orientierungen und Compliance `false`. Alle 24 kopierten Quellen-/Projekt-/Konfigurations-/Ressourcendateien stimmen bytegleich überein. `plutil`, lokale Markdownlinks, `git diff --check` sowie vorläufige Text-Privacy-/Ignore-Prüfung ohne Befund; `LOCAL_WORKSPACE.md` ist ignoriert und nicht im Index. [Unabhängiges Review](review-build4.md) abgeschlossen: keine offenen P1-/P2-Befunde. Kontextwechsel/Freshness der Einordnung, gemeinsame Request-Abbrüche und UI-/Privacy-Grenzen wurden geprüft. Abschließende Diff-, Link-, Privacy-/Index- und Ignore-Prüfung ohne Befund; keine Builds oder Tests für den Quellencheckpoint wiederholt. Alle schreibenden Agents sind fertig. Veröffentlichter Quellencheckpoint: `6750d0e954de900cb8bcf6f52b3faf1fc2d769d9`. Daraus signiertes Build-4-Archiv und lokaler IPA-Export erfolgreich, Metadaten und strikte Archiv-/IPA-Signaturen korrekt, explizites Distributionsprofil bestätigt. Alle 24 kopierten Projekt-/Konfigurations-/App-/Test-/Ressourcendateien bytegleich zu diesem Commit. Genau ein autorisierter interner Upload wurde um **18:17:29 Uhr MEZ** erfolgreich angenommen: Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded` und Apples `UPLOAD SUCCEEDED with no errors`. Letzter Serverzustand **`PROCESSING`**. Die tatsächliche interne TestFlight-Verfügbarkeit von Build 4 ist noch offen; keine Gruppen oder Tester geändert. Abschlussprüfung von Diff, lokalen Links, Text-Privacy, Index und Ignore ohne Befund. Details in [signing.md](signing.md) und [testflight-upload.md](testflight-upload.md).

## Vorheriger abgeschlossener Schritt und Übergabe

- Identity-Review und finaler Bundle-Name-Nachweis sind abgeschlossen, ohne offene P1-/P2-Befunde. Tatsächliche finale IPA: beide Namensfelder ShowerNow, neue ID und `0.1.0 (3)`; alle 24 kopierten Quellen-/Projekt-/Konfigurationsdateien bytegleich. Details in [signing.md](signing.md).
- Quellencheckpoint `2e500fc` ist veröffentlicht und Grundlage des erfolgreichen offiziellen Build-3-Uploads. Kein Namenskonflikt- oder Bundle-Validierungsfehler im aktuellen Upload. Alle Versuche und die unveränderte Weather-Historie stehen in [testflight-upload.md](testflight-upload.md).
- Zwölf Datentests und zwei UI-Flows waren am funktionalen Prototyp grün. Für Identity-/Metadatenänderungen wurden Simulatorbuild und Archiv-/IPA-Metadaten geprüft; keine volle Unit-/UI-Suite erneut ausgeführt. Der Uploadauftrag startete keine neuen Builds, Tests oder zusätzlichen lokalen Exporte.
- Keine App-Datensätze, Rollen, Gruppen, Tester oder Einladungen durch Agents verändert. Kein weiterer unterstützter authentifizierter Statuszugang verfügbar; kein Wiederholungsupload und kein fortlaufendes Polling.
- Abschluss dieses Schritts: ausschließlich Dokumentation abgeglichen; Diff-, Link-, Index-/Privacy- und Ignore-Prüfung, keine neuen Builds/Tests/Exporte/Uploads.

## Bisherige Prüfungen des Prototyps und der Release-Schritte

Die folgenden Nachweise gehören zu den jeweils genannten Schritten; damalige Angaben „kein Upload“ beschreiben den Stand der lokalen Prüfung vor dem später dokumentierten Upload.

- Datenkern und Testquellen mit Swift 6 typgeprüft.
- Simulator-Build der ersten integrierten App erfolgreich.
- Zwölf Datentests einschließlich UTC-/Millisekunden-Regressionsprüfung erfolgreich, null Fehler.
- UI-Smoke für Quellen-/Datenschutznavigation erfolgreich.
- Orts-CRUD-Smoke nach gezielten Korrekturen erfolgreich: echte Kartenpunktauswahl auf freier Fläche, Speichern, Umbenennen, Auswahl, Persistenz nach Relaunch und Löschen. Der abschließende gezielte Lauf bestand mit null Fehlern in 41.4 Sekunden. Insgesamt sind zwölf Datentests und beide UI-Smokes grün; die Ergebnisse stammen aus dem Gesamtlauf und den jeweils notwendigen gezielten Wiederholungen, nicht aus einem nachträglich erfundenen vollständigen Grünlauf.
- Begrenzte Liveprüfung nach Zeitformatfix: expliziter Lauf 15:45 UTC am öffentlichen Beispielpunkt Berlin, 37 Radarzeiten und HTTP-200-JSON mit 25 Samples. Die frühere Referenzzeit ohne Millisekunden lieferte eine WMS-Fehlermeldung; exaktes `.000Z` ist jetzt getestet.
- Sichtprüfung im iPhone-18-Pro-Simulator in Light und Dark Mode: MapKit-Karte, Radarüberlagerung, Zeitleiste und zunächst frische Ortsprognose sichtbar. Bei der abschließenden Sichtprüfung waren Teil-Kachelfehler und eine vorübergehend fehlende Ortsprognose sichtbar; diese werden transparent gemeldet und bleiben eine bekannte Live-Grenze. Keine Verfügbarkeitsgarantie daraus ableiten. MapKit-Attribution ist oberhalb des Prognosepanels sichtbar.
- Lokaler Xcode-Dateikoordinationshänger vor Buildbeginn durch temporäre Kopie relativer Quellen umgangen; keine globalen Dienste geändert. Details und Befehle in `build-and-test.md`.
- Unabhängiges abschließendes Review: Ortsrequest-Race und Radar-Reload korrekt behoben; keine offenen P1-/P2-Befunde oder erkannten Geheimnis-/Pfadlecks.
- App-Checkpoint `42e46bf`: ausschließlich geprüfter Code und Dokumentation; Icon-Artefakte waren ausgeschlossen. Separater Designcheckpoint: zwei native `.icon`-Packages, Generator und Vorschauen unter `design/Icon/`, dokumentiert in [icon.md](icon.md). Vorhandene Renderprüfungen übernommen; für die Veröffentlichung nur Datei-/Indexprüfung und `git diff --check`, keine neuen Renderings, Builds oder Tests. Der damalige verworfene Altentwurf unter `Weather/Resources/Icon/` wurde im anschließenden Integrationsschritt vollständig durch das ausgewählte Radar-Package ersetzt; private lokale Dateien bleiben ausgeschlossen.
- Aktuelle Radar-Integration: `actool` verarbeitet das einzige native `AppIcon.icon`; Export-Assets enthalten IconImageStack, IconGroup und Kartenvektor. Simulatorbuild/Installation/Launch erfolgreich. Archivierung und lokaler ASC-Export erneut erfolgreich, beide Signaturen streng geprüft; explizites Distributionsprofil, Identität `0.1.0` / `1` und Compliance-Schlüssel bestätigt. Bundle-Icons visuell korrekt; echte Homescreen-Sichtprüfung wegen fehlender Simulator-GUI nicht abgeschlossen. Details in [icon.md](icon.md). Keine erneute Datentest-/UI-Suite für die reine Ressourcenänderung.
- Frisches unabhängiges Release-Review bestätigt Quellenkopiegleichheit, native Icon-Metadaten/PNG, Archiv-/Export-Signaturen, explizites Profil, Version `0.1.0` / Build `1` und Compliance-Schlüssel; keine offenen P1-/P2-Befunde oder erkannten Uploadblocker. Homescreen-GUI weiterhin nicht gesichtet.
- Packaging-Fix nach Apple-Ablehnung `90474`: neues signiertes Release-Archiv und lokaler `app-store-connect`-Export erfolgreich (`ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`), Automatic Signing aus isolierter Quellenkopie. Archiv und tatsächliche IPA bestätigen `0.1.0 (2)`, `UIDeviceFamily=[1,2]`, vier explizite iPad-Orientierungen, unveränderte drei iPhone-Orientierungen, Compliance `false` und natives `AppIcon` (IconImageStack/IconGroup). Beide App-Signaturen bestehen `codesign --verify --deep --strict`; IPA-Profil ist explizit `J2DU2P47XW.de.linolaske.weather`, `get-task-allow=false`, ohne Geräteliste. Quellenkopie bytegleich für Konfiguration, Projekt und App-/Testquellen. `plutil` erfolgreich; keine volle Unit-/UI-Suite für diesen Plist-/Buildnummerfix wiederholt. iPad-kompatible Metadaten, auf iPhone validierter Prototyp; keine eigenständige iPad-Freigabe. Der anschließende Build-2-Upload wurde ohne Validierungsfehler angenommen; Verarbeitung bleibt offen.
- Frischer unabhängiger Build-2-Checkpoint bestätigt IPA-Prüfsumme, bytegleiche `Info.plist`/`Base.xcconfig` zur Archivquellenkopie und sämtliche genannten Archiv-/IPA-Metadaten, native Icon-Assets, strikte Signaturen und das Distributionsprofil; keine offenen P1/P2 im begrenzten Konfigurationsreview. Keine neuen Builds, Exporte oder Tests.
- ShowerNow-Identityfix: Simulatorbuild, `ARCHIVE SUCCEEDED` und lokaler `EXPORT SUCCEEDED`. Archiv und tatsächliche IPA bestätigen `de.linolaske.showernow`, Displayname ShowerNow, `0.1.0 (3)`, Familie `[1,2]`, vier iPad-/drei iPhone-Orientierungen, Compliance `false`, AppIcon für beide Familien und native IconImageStack/IconGroup-Assets. Beide Signaturen bestehen `codesign --verify --deep --strict`. Exportprofil explizit `J2DU2P47XW.de.linolaske.showernow`, `get-task-allow=false`, ohne Geräteliste; neue ID sofort dem Lead gemeldet. 21 versionierte App-/Test-/Projekt-/Konfigurationsdateien mit isolierter Archivquellenkopie bytegleich. Keine Installation/Launch- oder volle Unit-/UI-Wiederholung, kein neuer Upload.
- Quellencheckpoint: lokale Markdownlinks in README/docs auflösbar, Buildanleitung ohne alte aktive Launch-ID; scoped `git diff --check` sowie Index-/Privacy-/Ignore-Prüfung ohne Befund. Keine neuen Builds, Exporte oder Tests für den Checkpoint.
- `git diff --check` bisher ohne Fehler. Build-/Testlogs und xcresult-Dateien bleiben außerhalb des öffentlichen Repos.

- Ergänzender Bundle-Name-Fix: neues isoliertes Release-Archiv und lokaler ASC-Export erfolgreich. Archiv und tatsächliche IPA haben `CFBundleName=ShowerNow`, `CFBundleDisplayName=ShowerNow`, Executable Weather, neue ID und `0.1.0 (3)`. Familie `[1,2]`, iPhone-/iPad-Orientierungen 3/4, Compliance `false`, natives Radar-AppIcon, beide strikten Signaturen und explizites IPA-Profil bestätigt; alle 24 kopierten Quellen-/Projekt-/Konfigurationsdateien bytegleich. `plutil` und `git diff --check` erfolgreich. Keine volle Testsuite, kein Upload. Aktuelle IPA-Prüfsumme in [signing.md](signing.md).

## Signing und App Store Connect

- Zuletzt signiert und hochgeladen: ShowerNow / `de.linolaske.showernow`, Team `J2DU2P47XW`, `0.1.0 (3)`; explizites IPA-Profil `J2DU2P47XW.de.linolaske.showernow`, beide strikten Signaturen und native Radar-Assets bestätigt. [Signingnachweis](signing.md).
- Nutzerbestätigung des passenden ASC-Eintrags wird durch die offiziellen AppsService-Antwortdaten im Upload ergänzt: ShowerNow / neue ID / nicht entfernt. Kein Namenskonflikt im Build-3-Upload.
- Universal-Familie `[1,2]`, vier iPad-/drei iPhone-Orientierungen und Compliance `false` bleiben erhalten. Keine eigenständige iPad-Freigabe.
- Build 3 wurde angenommen; interne TestFlight-Nutzbarkeit ist jetzt durch den Nutzer bestätigt. Keine direkte neue ASC- oder Gruppenabfrage.

## Nächste Schritte nach bestätigtem internen iPhone-Test

1. Aus dem veröffentlichten geprüften Build-4-Quellencheckpoint signiertes Archiv erzeugen, tatsächliche IPA-/Signing-/Metadaten prüfen und über den vorhandenen autorisierten offiziellen Weg intern hochladen. Keine Tester-/Rollenänderungen.
2. Uploadannahme und Verarbeitung getrennt dokumentieren; keine interne Verfügbarkeit ohne Beleg behaupten.
3. Auf physischem iPhone Nachladen und Regenereignisse ohne private Standortlogs beobachten; echte lokale Einordnung nur auf modellbereitem Gerät prüfen.

Widgets/Watch, Push und angepasste iPad-/Mac-Oberflächen folgen gemäß Plan. Bekannte Provider-Kachelfehler und zeitweise fehlende Punktprognosen bleiben transparent; keine privaten Standorte öffentlich dokumentieren.
