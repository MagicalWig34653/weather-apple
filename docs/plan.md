# Entwicklungsplan

Stand: 28. Oktober 2026. Nach Klärung der drei Einstiegsfragen ist der Beginn freigegeben.

## Verbindlicher Rahmen

- Kostenbewusst und in kleinen überprüfbaren Schritten arbeiten. Für jeden Arbeitsauftrag abgegrenzte Agent-Unterstützung oder unabhängige Agent-Prüfung nutzen.
- Repo ist Source of Truth. Status, Entscheidungen, Quellen, Prüfungen und offene Fragen fortlaufend persistieren; jede Session muss ohne Chatverlauf fortsetzbar sein.
- Swift/SwiftUI, MapKit und CoreLocation. Keine Konten, Werbung oder Analyse-SDKs. Karte unabhängig vom eigenen Backend.
- Zielgeräte: iPhone 17 Pro und 18 Pro, Apple Watch Ultra und Apple-Silicon-Macs; Betriebssysteme jeweils 27er-Versionen. Zunächst keine ältere Systemunterstützung. Konkrete iPad-Testhardware noch nicht benannt; Simulatorprüfung vorsehen.
- Erster interner TestFlight-Build: brauchbare iPhone-App. Widgets und Watch direkt danach ergänzen; keine Voraussetzung für den ersten Build.
- Verbindliche aktuelle Identität: ShowerNow, Haupt-Bundle-ID `de.linolaske.showernow`, Team `J2DU2P47XW`, aktueller Kandidat `0.1.0 (5)`. Technisches Projekt/Module und Ordner dürfen Weather/weather bleiben. Frühere Freigaben der Weather-Identität sind überholt. Der Nutzer hat die neue Bundle-ID im aktuellen App-Store-Connect-Eintrag bestätigt. Build 3 ist inzwischen durch den Nutzer als intern über TestFlight funktionsfähig bestätigt. Build 4 wurde intern verwendet und führte zu kritischem Nutzerfeedback. Die gezielten P0-/Timelinekorrekturen für Build 5 sind unabhängig geprüft; signierter Release folgt separat.

## Aktueller Verbesserungsschritt nach dem ersten Alltagstest

Der Nutzer bestätigt die interne TestFlight-Nutzbarkeit von Build 3 und berichtet langsames Laden. Die gezielten Cache-/Ladeverbesserungen, kompakte native Glass-Zeitleiste und optionale lokale Foundation-Models-Einordnung sind integriert und im Simulator geprüft; Belege und Grenzen stehen in `status.md` sowie den dort verlinkten Fachbefunden. Erst nach Integration und unabhängigem Review einen neuen internen Kandidaten erstellen. Backend und Originalkonzept bleiben unverändert. Dateibesitz und Prüfressourcen stehen in `status.md`.

## 1. Datenkette validieren — bisheriger Arbeitsschritt

Offizielle DWD-Karten- und Rohdatenprodukte recherchieren: Erreichbarkeit, Zeitauflösung, Prognosehorizont, räumliche Abdeckung, Projektion, Dateiformate, Nutzungsbedingungen und Attribution. Quellen und Abrufdatum unter docs/research/ dokumentieren.

Einen realen Datenlauf reproduzierbar untersuchen: Messung und Prognose eindeutig zuordnen, mehrere Zellen einschließlich fehlender Daten auswerten. Downloadgröße, Entpackgröße, Laufzeit und Speicherbedarf erfassen. Messungen am Entwicklungs-Mac nicht als iPhone-Messung ausgeben. Kleine technische Validierung darf Code enthalten; keine vollständige Infrastruktur vorwegnehmen.

**Abnahme:** getestete Radarquelle und dokumentierter direkter Datenweg für Ortsprognose oder eine begründete Entscheidungsvorlage. Keine fertigen Karten-/Prognosefähigkeiten allein aus Produktnamen ableiten. Ist die lokale numerische Auswertung unverhältnismäßig, den Nutzer mit konkreten Befunden zwischen reduziertem ersten Umfang und vorgezogener Punkt-API entscheiden lassen; Backend nicht stillschweigend vorziehen.

## 2. Native iPhone-App durchgängig aufbauen

Reproduzierbares Xcode-Projekt mit vorläufigen Kennungen, zentral konfigurierbaren Identitätswerten und dokumentiertem Buildbefehl. Zunächst ein durchgängiger Pfad vom Datenabruf bis zur Karte, dann schrittweise vervollständigen:

- Radar als Hauptansicht mit hochziehbarer Ortsprognose; das ist der initiale UI-Ansatz, kein unveränderliches Design.
- Transparenter Radar-Layer, Animation, Play/Pause, Zeitleiste und sichtbare Grenze zwischen Messung und Prognose.
- Niederschlagsverlauf, erwarteter Beginn/Ende und Intensität nur im durch Daten gedeckten Umfang; Unsicherheit sichtbar machen.
- Ortssuche, lokale Orte und lokale Namen; Standortberechtigung erst bei Bedarf, keine Hintergrundortung in diesem Schritt.
- Datenalter, Lade-/Fehlerzustände, veralteter Cache und keine Daten sauber unterscheiden. Keine ungerechtfertigte Aussage „trocken“ bei fehlenden Daten.
- Light/Dark Mode, VoiceOver, Dynamic Type und einhändige Bedienung berücksichtigen.

**Abnahme:** ohne eigenes Backend im Alltag nutzbar, Kernpfade im iPhone-Simulator geprüft; gezielte Tests für Parser, Zeitlogik, Projektion, Cache und Fehlerfälle. Keine Tests nur zum Spiegeln einfacher UI-Implementierung.

## 3. Erster interner TestFlight-Build

Team/Signing lokal prüfen; keine Schlüssel oder Profile committen. Interne Verteilung unter der bestätigten ShowerNow-Identität vorbereiten, reale Verfügbarkeit von Zugang und App-Store-Connect-Rechten prüfen. Buildnummer, Datenschutz-/Quellenhinweise, bekannte Grenzen und kurze Testanleitung dokumentieren. Erforderliche Erklärungen nicht ungeprüft beantworten.

**Abnahme:** Archive-/Validierungsergebnis und interner TestFlight-Status dokumentiert. Wenn Zugang fehlt, genau den verbleibenden manuellen Schritt dokumentieren. Alltagstest durch Nutzer und Vater; Regenereignisse, Datenalter und Bedienprobleme ohne private Standortdaten im öffentlichen Repo auswerten.

## 4. Widgets, Watch sowie iPad und Mac

Nach dem ersten iPhone-Build Widgets und Watch ergänzen. Kleine/mittlere Regen-Widgets mit Ortsauswahl, Datenalter und Deep Link; Aktualisierung unter realen Systembedingungen prüfen. Watch zuerst kompakte Ortsprognose und Komplikationen; Radar und unabhängiger Datenabruf nach technischer Bewertung konkretisieren.

iPad und Mac erhalten passende Navigation, Fenster-/Tastaturbedienung und Kartenlayouts. Gemeinsamen Code anhand tatsächlicher Mehrfachnutzung auslagern; kein vorsorgliches Framework-System.

**Abnahme je Plattform:** reproduzierbarer Build, gezielte Simulator-/Geräteprüfung und dokumentierte Grenzen. Hintergrundaktualisierung nicht als garantiert darstellen.

## 5. Qualität im Alltag und danach Pushbackend

Beobachtete Probleme priorisieren, Abrufvolumen/Cache/Energieverbrauch verbessern und Prognoseabweichungen nachvollziehbar erfassen. Erst nach einer nutzbaren App den zentralen Pushdienst implementieren. Dafür gilt der separate Backend-Plan.

- Folgeaufgabe (vorgemerkt, nicht umgesetzt): Adaptiver Poll-Takt für `latest.json`: statt starr 60 s kurz vor dem erwarteten Erscheinen eines neuen Laufs (ca. 3–3,5 min nach Nominalzeit im 5-min-Raster) etwa alle 10 s nachfragen, bis der neue Lauf da ist, sonst selten. Websocket bewusst nicht (Akku/Hintergrund/Zustand), SSE nur falls später zeitkritische Live-Warnungen nötig; Benachrichtigungen über APNs.

## 6. Spätere Erweiterungen

Unterwegs-Warnungen nach stabilem Push, Wind-/Temperaturkarten, Wolken-/Satellitenansichten, tvOS sowie visionOS im Simulator. Kein Blocker für erste TestFlight-Versionen.

## Arbeitsabschluss und Fortsetzung

Pro Schritt Änderungen und Prüfergebnisse in docs/status.md festhalten, relevante Entscheidungen in docs/decisions.md und Forschungsergebnisse mit Primärquellen unter docs/research/. Kleine Commits und Pushes erhalten den fortsetzbaren Stand. Umfangreiche Prüfungen nur bei konkretem Anlass wiederholen. Keine geschätzten Zeit-/Kostenversprechen ohne Messgrundlage.
