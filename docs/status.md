# Fortsetzbarer Arbeitsstand

Stand: 28. Oktober 2026. Aktueller Kandidat ist **ShowerNow `0.1.0 (3)`**, Bundle-ID **`de.linolaske.showernow`**, Team `J2DU2P47XW`. Umbenennung, gezielter Simulatorbuild, signiertes Release-Archiv und lokaler Export sind erfolgreich; neue explizite ID durch tatsächliches Distributionsprofil bestätigt. Noch kein Upload für die neue Identität. Der Nutzer hat die Umstellung seines ASC-App-Datensatzes auf die neue ID bestätigt (keine direkte Portalabfrage). Projekt/Module heißen technisch weiter Weather.

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

Dies ist ein früher Prototyp, keine fertige Version 1. Ein installierbarer interner ShowerNow-TestFlight-Build bleibt zu bestätigen.

## Aktuelle Aufgabe und Übergabe

- Identity-Umbenennung und unabhängiges Review sind ohne offene P1-/P2-Befunde abgeschlossen. Der Nutzer bestätigt den ASC-Datensatz auf neuer ID; kein weiterer neuer Datensatz als Blocker.
- Ergänzende tatsächliche IPA-Prüfung fand `CFBundleDisplayName=ShowerNow`, aber noch `CFBundleName=Weather`. Gezielte Korrektur in `Configuration/Info.plist`: beide Felder verwenden `WEATHER_DISPLAY_NAME`; Executable/Produktname/Swift-Modul bleiben Weather. Neues isoliertes Release-Archiv und lokaler ASC-Export sind erfolgreich; tatsächliches Archiv und IPA bestätigen beide Namen als ShowerNow, neue ID und `0.1.0 (3)`. Kein Upload.
- Metadaten-Worker änderte ausschließlich `Configuration/Info.plist`, `docs/status.md` und `docs/signing.md`; Buildslot nach Prüfung wieder frei. Keine Datenlogik-, Backend- oder Designänderung.
- Quellencheckpoint `0f48cb5` und die dortigen 12 Datentests/2 UI-Flows bleiben historische geprüfte Grundlage. Der aktuelle Quellencheckpoint enthält die freigegebene ShowerNow-Umbenennung samt finalem Bundle-Name-Nachweis; Commit/Push sind autorisiert. Upload erfolgt separat.
- Keine volle Testsuite für die reine Pliständerung. ASC-Name, Bundle-Displayname und Bundle-Name sind getrennte Felder; der lokale Fix beweist keine Lösung des berichteten ASC-Namenskonflikts, siehe [signing.md](signing.md).

## Bisherige Prüfungen dieses Schritts

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

- Aktuelle Identität: ShowerNow / `de.linolaske.showernow`, Team `J2DU2P47XW`, `0.1.0 (3)`; spezifischer neuer Profilnachweis ist in [signing.md](signing.md) festgehalten. Die alte explizite Weather-ID belegt die neue ID nicht.
- Nutzer bestätigt die Umstellung seines ASC-App-Datensatzes auf die neue ID. Keine direkte Portal-/Auswahllistenprüfung erfolgt. Apples allgemeine Bundle-ID-Änderungsbeschränkung nach einem Upload wird nur bedingt erklärt; siehe [signing.md](signing.md). ASC-Name und lokale Bundle-Namensfelder bleiben getrennt.
- Universal-Familie `[1,2]`, vier iPad-/drei iPhone-Orientierungen, Radar-AppIcon und begründetes Compliance `false` bleiben erhalten. Keine eigenständige iPad-Freigabe.
- Identity-Review ohne offene P1-/P2-Befunde und ergänzender Bundle-Name-Nachweis abgeschlossen; frischer Quellencheckpoint vor separatem Upload. Noch kein Upload von Build 3. Keine App-Datensätze, Rollen, Gruppen oder Tester durch Agents ändern.

## Nächste Schritte bis zum ersten internen iPhone-Test

1. Aktuellen Quellencheckpoint veröffentlichen; Identity-Review und ergänzender tatsächlicher Bundle-Name-Nachweis sind abgeschlossen. Neue explizite ID und Nutzerbestätigung des ASC-Match liegen vor.
2. Separaten autorisierten Uploadauftrag für das neue geprüfte ShowerNow-Archiv ausführen. Annahme, Verarbeitung und interne Verfügbarkeit getrennt belegen.
3. Nach tatsächlicher interner Verfügbarkeit auf dem physischen iPhone anhand [internal-testing.md](internal-testing.md) testen.

Danach Widgets/Watch und angepasste iPad-/Mac-Oberflächen gemäß Plan. Regenendeformulierungen, Cache-/Energiegrenzen und breitere NoData-/Zellrandfälle bleiben Qualitätsarbeit. Keine privaten Standorte öffentlich dokumentieren.
