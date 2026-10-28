# Entwicklungsplan

Stand: 28. Oktober 2026. Nach Klärung der drei Einstiegsfragen ist der Beginn freigegeben.

## Verbindlicher Rahmen

- Kostenbewusst und in kleinen überprüfbaren Schritten arbeiten. Für jeden Arbeitsauftrag abgegrenzte Agent-Unterstützung oder unabhängige Agent-Prüfung nutzen.
- Repo ist Source of Truth. Status, Entscheidungen, Quellen, Prüfungen und offene Fragen fortlaufend persistieren; jede Session muss ohne Chatverlauf fortsetzbar sein.
- Swift/SwiftUI, MapKit und CoreLocation. Keine Konten, Werbung oder Analyse-SDKs. Karte unabhängig vom eigenen Backend.
- Zielgeräte: iPhone 17 Pro und 18 Pro, Apple Watch Ultra und Apple-Silicon-Macs; Betriebssysteme jeweils 27er-Versionen. Zunächst keine ältere Systemunterstützung. Konkrete iPad-Testhardware noch nicht benannt; Simulatorprüfung vorsehen.
- Erster interner TestFlight-Build: brauchbare iPhone-App. Widgets und Watch direkt danach ergänzen; keine Voraussetzung für den ersten Build.
- Name Weather und Haupt-Bundle-ID de.linolaske.weather dürfen auch für den ersten TestFlight-Eintrag verwendet werden. Team J2DU2P47XW vor Signing bestätigen. Endgültige Umbenennung später explizit planen.

## 1. Datenkette validieren — aktueller Arbeitsschritt

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

Team/Signing lokal prüfen; keine Schlüssel oder Profile committen. Interne Verteilung unter vorläufiger Identität vorbereiten, reale Verfügbarkeit von Zugang und App-Store-Connect-Rechten prüfen. Buildnummer, Datenschutz-/Quellenhinweise, bekannte Grenzen und kurze Testanleitung dokumentieren. Erforderliche Erklärungen nicht ungeprüft beantworten.

**Abnahme:** Archive-/Validierungsergebnis und interner TestFlight-Status dokumentiert. Wenn Zugang fehlt, genau den verbleibenden manuellen Schritt dokumentieren. Alltagstest durch Nutzer und Vater; Regenereignisse, Datenalter und Bedienprobleme ohne private Standortdaten im öffentlichen Repo auswerten.

## 4. Widgets, Watch sowie iPad und Mac

Nach dem ersten iPhone-Build Widgets und Watch ergänzen. Kleine/mittlere Regen-Widgets mit Ortsauswahl, Datenalter und Deep Link; Aktualisierung unter realen Systembedingungen prüfen. Watch zuerst kompakte Ortsprognose und Komplikationen; Radar und unabhängiger Datenabruf nach technischer Bewertung konkretisieren.

iPad und Mac erhalten passende Navigation, Fenster-/Tastaturbedienung und Kartenlayouts. Gemeinsamen Code anhand tatsächlicher Mehrfachnutzung auslagern; kein vorsorgliches Framework-System.

**Abnahme je Plattform:** reproduzierbarer Build, gezielte Simulator-/Geräteprüfung und dokumentierte Grenzen. Hintergrundaktualisierung nicht als garantiert darstellen.

## 5. Qualität im Alltag und danach Pushbackend

Beobachtete Probleme priorisieren, Abrufvolumen/Cache/Energieverbrauch verbessern und Prognoseabweichungen nachvollziehbar erfassen. Erst nach einer nutzbaren App den zentralen Pushdienst implementieren. Dafür gilt der separate Backend-Plan.

## 6. Spätere Erweiterungen

Unterwegs-Warnungen nach stabilem Push, Wind-/Temperaturkarten, Wolken-/Satellitenansichten, tvOS sowie visionOS im Simulator. Kein Blocker für erste TestFlight-Versionen.

## Arbeitsabschluss und Fortsetzung

Pro Schritt Änderungen und Prüfergebnisse in docs/status.md festhalten, relevante Entscheidungen in docs/decisions.md und Forschungsergebnisse mit Primärquellen unter docs/research/. Kleine Commits und Pushes erhalten den fortsetzbaren Stand. Umfangreiche Prüfungen nur bei konkretem Anlass wiederholen. Keine geschätzten Zeit-/Kostenversprechen ohne Messgrundlage.
