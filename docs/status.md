# Fortsetzbarer Arbeitsstand

Stand: 28. Oktober 2026. Der geprüfte erste Implementierungsstand ist als Code-/Dokumentationscheckpoint veröffentlicht. Designcheckpoint `fd601e1` bewahrt beide geprüften Icon-Vorschläge. Variante B (Radar) ist ausgewählt und jetzt nativ integriert; aktuelles signiertes Archiv und lokaler Export sind erfolgreich. Das unabhängige begrenzte Integrationsreview bestätigt keine offenen P1-/P2-Befunde oder Uploadblocker; dieser Quellencheckpoint ist für den separaten Uploadauftrag vorbereitet. Der tatsächliche TestFlight-Upload steht aus.

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
- `git diff --check` bisher ohne Fehler. Build-/Testlogs und xcresult-Dateien bleiben außerhalb des öffentlichen Repos.

## Signing und App Store Connect

- Apple-Team durch signierten Gerätebuild bestätigt.
- Neues Release-Archiv und lokaler App-Store-Connect-Export einschließlich Radar-Icon erfolgreich; alte Artefakte vor Icon-Integration nicht für Upload verwenden. Spezifisches Distributionsprofil bestätigt die explizite ID `de.linolaske.weather`; Details in `signing.md`.
- Nutzer wurde über die ID informiert und hat den App-Store-Connect-App-Eintrag anschließend selbst angelegt. Kein App-Datensatz durch Agents erstellt.
- Begründeter Export-Compliance-Schlüssel für ausschließlich systemeigene Verschlüsselung gesetzt; Primärquelle und aktuelle Codeverwendung geprüft, Plist syntaktisch validiert.
- Bisher kein Upload und keine serverseitige TestFlight-Verarbeitung. Ein lokaler Export ist keine vollständige App-Store-Validierung.

## Nächste Schritte bis zum ersten internen iPhone-TestFlight-Build

1. Geprüften Radar-/Release-Quellencheckpoint veröffentlichen und aktuelles Archiv/IPA statt alter Artefakte für den separaten Uploadauftrag verwenden.
2. Verbleibende Release-/Metadatenanforderungen anhand [testflight-readiness.md](testflight-readiness.md) erfüllen; Homescreen-Icon auf dem physischen iPhone prüfen.
3. Kartenfehler/Retry und Bedienabläufe auf dem physischen iPhone prüfen; Datenalter und Ausfallzustände nachvollziehbar halten.
4. Den tragfähigen Release-Stand validieren und für den vorhandenen App-Store-Connect-Eintrag intern über TestFlight bereitstellen. Zugang/Verarbeitung tatsächlich prüfen, keinen Erfolg vorwegnehmen.
5. Alltagserfahrung des Nutzers und seines Vaters sammeln; keine privaten Standorte in öffentliche Fehlerberichte schreiben.

Danach Widgets/Watch und angepasste iPad-/Mac-Oberflächen gemäß Plan. Regenende-/Ereignisformulierungen, verlässliche Cache-/Energiegrenzen und breitere NoData-/Zellrandfälle bleiben weitere Qualitätsarbeit. Automatische Warnungen, Unterwegs-Ortung und zusätzliche Wetterkarten gehören nicht in diesen ersten Prototypschritt.
