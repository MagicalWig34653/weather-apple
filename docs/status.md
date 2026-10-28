# Fortsetzbarer Arbeitsstand

Stand: 28. Oktober 2026. Radar-Quellencheckpoint `636aa9d` ist geprüft. Der erste echte Upload von `0.1.0 (1)` erreichte Apple, wurde aber mit `90474` wegen fehlender iPad-Orientierung abgelehnt; kein Authentifizierungsfehler und kein TestFlight-Erfolg. Der gezielte Packaging-Fix ergänzt alle vier iPad-Orientierungen und erhöht die Buildnummer auf `2`; neuer Upload und Servervalidierung bleiben offen. Der ursprüngliche Uploadbefund bleibt in [testflight-upload.md](testflight-upload.md) erhalten.

## Freigabe und Arbeitsweise

Entwicklung ist freigegeben. App zuerst, Backend nach einer nutzbaren App. Zuerst ein brauchbarer interner iPhone-TestFlight-Build, Widgets und Watch danach; größere Plattform-Roadmap in `plan.md`.

Der Hauptagent koordiniert ausschließlich. Neue abgegrenzte Aufgaben erhalten frische Agents; unabhängige Arbeit läuft mit klaren Dateizuständigkeiten parallel. Verbindliche Details stehen in `AGENTS.md` und `team.md`. Entscheidungen, Ergebnisse und nächste Schritte bleiben im Repo; Sessions dürfen keinen Chatverlauf voraussetzen.

## Repository und lokale Konfiguration

- Dieses Repo: https://github.com/MagicalWig34653/weather-apple
- Schwesterrepo: https://github.com/MagicalWig34653/weather-backend
- Private lokale Pfade ausschließlich in der ignorierten `LOCAL_WORKSPACE.md`; öffentliche Vorlage `LOCAL_WORKSPACE.example.md`.
- Die ursprünglichen Einrichtungskopien sind keine aktiven Arbeitsverzeichnisse. Fachliche Entscheidungen und Fortschritte bleiben versioniert.

## Implementierter iPhone-Prototyp

- XcodeGen-Projekt mit relativen Dateireferenzen, Swift 6, iOS 27 und zentraler vorläufiger Identität in `Configuration/Base.xcconfig`.
- Native MapKit-Radarkarte mit expliziten DWD-Datenläufen, tatsächlichen vergangenen Analyseframes, Vorhersage, Play/Pause und farblich sichtbarer Zeitgrenze.
- Direkte DWD-Punktprognose als kleine JSON-Serie; kein eigener Server und kein HDF5-Download auf dem Gerät. Datenvertrag in `data-contract.md`.
- Datenalter, fehlende Daten, Netzfehler und Messung/Vorhersage getrennt. Texte altern regelmäßig mit; alte Daten dürfen keine aktuelle Trocken-Zusage erzeugen.
- Ortssuche, Kartenpunktauswahl, lokale Ortsnamen, Speichern, Umbenennen und Löschen. Optionaler Standort nur bei Nutzung, keine Hintergrundortung.
- Swift Charts für den Niederschlagsverlauf, Detailansicht und verständliche Quellen-/Datenschutzhinweise.
- Punktprognosen/Index im Speicher, Radar-Tiles im begrenzten Memorycache. Alte Overlay-Requests werden bei Wechsel abgebrochen. Kein Festplatten-Netzwerkcache für Punktanfragen.
- Ortswechsel invalidiert alte Anfragen synchron; manueller Refresh kann auch bei identischem Datenlauf fehlgeschlagene Tiles erneut laden. Die Review-Fixes sind kompiliert; Ortsablauf und abschließende Light-/Dark-Sichtprüfung sind erfolgreich abgeschlossen. Ein frisches unabhängiges Review bestätigt beide Korrekturen ohne offene P1-/P2-Befunde.

Dies ist ein früher Prototyp, keine fertige Version 1 und noch kein TestFlight-Upload.

## Laufende Aufgaben und Zuständigkeiten

| Ergebnisaufgabe | Dateibesitz / Verantwortung | Stand |
|---|---|---|
| Packaging-Fix Build 2 | `Configuration/Info.plist`, `Configuration/Base.xcconfig`, Status/Readiness; exklusiver Release-Buildslot | Archiv/Export und frischer unabhängiger Quellen-/IPA-Metadatencheckpoint erfolgreich; separater Quellencommit für Uploadübergabe; kein Upload; Buildslot frei |
| Technische Integration | Xcode-Projekt, README, Status/Entscheidungen; ein Simulator-Testslot | Gezielter Orts-CRUD-Rerun und Light-/Dark-Sichtprüfung abgeschlossen; Radar-Icon integriert, Simulatorbuild/Launch und aktuelles Release-Archiv/Export erfolgreich; Buildslot frei; unabhängiges begrenztes Review ohne offene P1/P2 oder Uploadblocker abgeschlossen |
| Lokaler Löschflow | `PlacesSheet.swift`, dazugehöriger UI-Test | Explizite deutsche destruktive Swipe-Aktion implementiert; echter Löschablauf im Simulator erfolgreich |
| Icon-Vorschläge / Release-Integration | Originaldesign unter `design/Icon/` unverändert; Integration besitzt `Weather/Resources/Icon/`, Projekt, Icon-/Status-/Entscheidungsdoku | Beide Originalentwürfe bleiben erhalten; Radar vollständig als einzig aktives AppIcon integriert. Native Asset-, Bundle-, Signatur- und Exportbelege in [icon.md](icon.md). Homescreen-GUI nicht zugänglich; generierte Bundle-Icons visuell geprüft. Kein Upload |

Koordinatoren führen keine technischen Änderungen aus. Abgeschlossene Detailbefunde stehen in den verlinkten Dokumenten; weitere Aufgaben erst mit klarer Dateizuständigkeit beginnen.

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
- Packaging-Fix nach Apple-Ablehnung `90474`: neues signiertes Release-Archiv und lokaler `app-store-connect`-Export erfolgreich (`ARCHIVE SUCCEEDED`, `EXPORT SUCCEEDED`), Automatic Signing aus isolierter Quellenkopie. Archiv und tatsächliche IPA bestätigen `0.1.0 (2)`, `UIDeviceFamily=[1,2]`, vier explizite iPad-Orientierungen, unveränderte drei iPhone-Orientierungen, Compliance `false` und natives `AppIcon` (IconImageStack/IconGroup). Beide App-Signaturen bestehen `codesign --verify --deep --strict`; IPA-Profil ist explizit `J2DU2P47XW.de.linolaske.weather`, `get-task-allow=false`, ohne Geräteliste. Quellenkopie bytegleich für Konfiguration, Projekt und App-/Testquellen. `plutil` erfolgreich; keine volle Unit-/UI-Suite für diesen Plist-/Buildnummerfix wiederholt. iPad-kompatible Metadaten, auf iPhone validierter Prototyp; keine eigenständige iPad-Freigabe. Neuer Upload und Apple-Servervalidierung bleiben offen.
- Frischer unabhängiger Build-2-Checkpoint bestätigt IPA-Prüfsumme, bytegleiche `Info.plist`/`Base.xcconfig` zur Archivquellenkopie und sämtliche genannten Archiv-/IPA-Metadaten, native Icon-Assets, strikte Signaturen und das Distributionsprofil; keine offenen P1/P2 im begrenzten Konfigurationsreview. Keine neuen Builds, Exporte oder Tests.
- `git diff --check` bisher ohne Fehler. Build-/Testlogs und xcresult-Dateien bleiben außerhalb des öffentlichen Repos.

## Signing und App Store Connect

- Apple-Team durch signierten Gerätebuild bestätigt.
- Neues Release-Archiv und lokaler App-Store-Connect-Export einschließlich Radar-Icon erfolgreich; alte Artefakte vor Icon-Integration nicht für Upload verwenden. Spezifisches Distributionsprofil bestätigt die explizite ID `de.linolaske.weather`; Details in `signing.md`.
- Nutzer wurde über die ID informiert und hat den App-Store-Connect-App-Eintrag anschließend selbst angelegt. Kein App-Datensatz durch Agents erstellt.
- Begründeter Export-Compliance-Schlüssel für ausschließlich systemeigene Verschlüsselung gesetzt; Primärquelle und aktuelle Codeverwendung geprüft, Plist syntaktisch validiert.
- Erster tatsächlicher Upload `0.1.0 (1)` serverseitig mit `90474` abgelehnt: iPad-Multitasking verlangt alle vier Orientierungen. App-Abfrage HTTP 200; kein Authentifizierungsfehler. Kein erfolgreicher Upload, keine abgeschlossene Verarbeitung oder interne Verfügbarkeit belegt; [Originalbefund](testflight-upload.md).
- Packaging-Fix: `UISupportedInterfaceOrientations~ipad` enthält explizit alle vier Orientierungen, iPhone behält die bisherigen drei. Buildnummer `2` trennt den neuen Kandidaten vom abgewiesenen Build `1`. Tatsächliches Weather-Target ist in Debug/Release `TARGETED_DEVICE_FAMILY=1,2`; die XcodeGen-Targetdefaults überschreiben den Projektwert `1`. Bestehende Universal-Unterstützung bleibt erhalten, ohne Fullscreen-/Multitasking-Umgehung; angepasste iPad-Oberfläche bleibt spätere Arbeit.

## Nächste Schritte bis zum ersten internen iPhone-TestFlight-Build

1. Unabhängig geprüften Packaging-Fix für Build `2` als Quellencheckpoint veröffentlichen; ausschließlich dessen neues Archiv für den getrennten Uploadauftrag verwenden. Build `1` nicht unverändert erneut versuchen.
2. Verbleibende Release-/Metadatenanforderungen anhand [testflight-readiness.md](testflight-readiness.md) erfüllen; Homescreen-Icon auf dem physischen iPhone prüfen.
3. Kartenfehler/Retry und Bedienabläufe auf dem physischen iPhone prüfen; Datenalter und Ausfallzustände nachvollziehbar halten.
4. Den tragfähigen Release-Stand validieren und für den vorhandenen App-Store-Connect-Eintrag intern über TestFlight bereitstellen. Zugang/Verarbeitung tatsächlich prüfen, keinen Erfolg vorwegnehmen.
5. Alltagserfahrung des Nutzers und seines Vaters sammeln; keine privaten Standorte in öffentliche Fehlerberichte schreiben.

Danach Widgets/Watch und angepasste iPad-/Mac-Oberflächen gemäß Plan. Regenende-/Ereignisformulierungen, verlässliche Cache-/Energiegrenzen und breitere NoData-/Zellrandfälle bleiben weitere Qualitätsarbeit. Automatische Warnungen, Unterwegs-Ortung und zusätzliche Wetterkarten gehören nicht in diesen ersten Prototypschritt.
