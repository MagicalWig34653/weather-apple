# Kompakte Kartenbedienung mit Liquid Glass

Stand: 28. Oktober 2026. Umsetzung und gezielte Prüfung abgeschlossen.

## Entscheidung und Umsetzung

Nutzerfeedback: Der interne ShowerNow-TestFlight-Build funktioniert; die untere Bedienung soll einfacher, textärmer und schwebend werden. Das vorherige durchgehende Panel nahm auf dem iPhone-18-Pro-Simulator ungefähr ein Drittel der Ansicht ein. Zwei schwebende native Glasflächen ersetzen es: kompakte Ortsprognose mit Detailzugang und darunter Wiedergabe, Zeitpunkt, Messung/Vorhersage, Jetzt und Zeitschieber. Das Diagramm und die ausführliche Prognoseerklärung bleiben in den Details. DWD-Datenstand und Datenalter stehen einmal an der Prognose; Fehler bleiben sichtbar. Kartenattribution wird weiterhin über den gemessenen unteren Kartenabstand freigehalten.

Die Steuerung behält native Slider-Accessibility, beschriftete Buttons und mindestens 44-Punkt-Touchflächen. Bei Accessibility-Schriftgrößen stehen Zeitpunkt und Messung/Vorhersage untereinander. Keine Animation zusätzlich eingeführt; bestehendes Reduce-Motion-Verhalten bleibt erhalten.

## Verifizierte Apple-APIs

Am 28. Oktober 2026 anhand aktueller Apple-Dokumentation geprüft:

- [Liquid Glass für eigene Views](https://developer.apple.com/documentation/swiftui/applying-liquid-glass-to-custom-views): `glassEffect` nach Layout-/Padding-Modifikatoren; `regular` für größere Kontrollflächen, abgerundete Rechtecke als Form.
- [glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:)): natives Liquid Glass statt einer Material-Nachbildung.
- [GlassEffectContainer](https://developer.apple.com/documentation/swiftui/glasseffectcontainer): gemeinsame Darstellung mehrerer Glasformen. Die zwei unteren Flächen teilen einen Container.

Der Simulatorbuild mit dem installierten iOS-27.1-SDK hat die verwendeten APIs kompiliert. Keine Annahme über zusätzliche iOS-27-spezifische APIs nötig.

## Prüfstand

- Ausgangsbuild und erster UI-Build aus isolierten Quellenkopien erfolgreich.
- Vorheraufnahme der aktiven ShowerNow-ID auf iPhone 18 Pro erstellt; öffentlicher Beispielort Berlin.
- Drei UI-Flows erfolgreich: Datenschutznavigation (10,9 s), Orts-CRUD einschließlich Persistenz (40,1 s), Radarzeit/Play/Pause/Jetzt/Details (14,9 s). Nach Integration der Einordnung wurde nur der betroffene Radar-/Detailsflow gezielt erneut ausgeführt: erfolgreich, 15,5 s; die Standard-Einordnung war im Detail sichtbar.
- Integrierter Simulatorbuild erfolgreich; 26 Daten-/Logiktests mit null Fehlern (18 DWD, 8 Einordnung). Ein zuvor erkannter Swift-Actor-Compilerfehler im neuen KI-Code wurde vor diesem erfolgreichen Lauf behoben.
- Light/Dark sowie Accessibility Extra Large visuell geprüft. Vergrößerte Symbole und abgeschnittener Fehlertext aus der ersten Accessibility-Sichtung wurden korrigiert; finale Sichtung zeigt vollständig lesbaren Fehlertext und bedienbare Timeline. Das größere Panel bei Accessibility-Schrift ist beabsichtigt. Keine vollständige VoiceOver-Geräteabnahme behauptet.
- Der Live-DWD-Abruf meldete teilweise fehlende Radarkacheln; der Hinweis bleibt sichtbar. Keine Verfügbarkeitsgarantie aus den Screenshots ableiten.
- Die trockene Live-Prognose enthält nur einen Einordnungsfakt: Standardtext ohne Modellanforderung. Echte Apple-Modellgenerierung und modellbereite Hardware wurden nicht geprüft; Availability-/Fehlerfallbacks sind injiziert getestet.
- Keine Cache-, Modell-, Projekt-, Signing- oder Buildnummeränderung durch diesen Auftrag.

## Reproduzierbare Sichtprüfung

1. App auf iPhone 18 Pro mit iOS 27 starten; ausschließlich den öffentlichen Beispielort Berlin verwenden, Standortfreigabe nicht erteilen.
2. Nach Datenabruf Ort, Fehlerhinweis, freien Kartenbereich, Apple-Attribution und beide schwebenden Bedienflächen prüfen. Slider vorwärts bewegen, Jetzt sowie Play/Pause betätigen.
3. Prognose antippen: Diagramm, Datenlauf und Einordnung bleiben erreichbar. Quellen und Datenschutz über die Informationstaste öffnen.
4. Systemdarstellung Light/Dark wechseln; anschließend Schriftgröße Accessibility Extra Large prüfen und wieder auf Large zurückstellen.

Sichere Simulatoraufnahmen ohne private Orte liegen unter [design/UI](../design/UI/): [Vorher Dark](../design/UI/before-dark.png), [Nachher Light](../design/UI/after-light.png), [Nachher Dark](../design/UI/after-dark.png) und [Accessibility](../design/UI/after-accessibility.png). Keine Standortfreigabe oder Ortshistorie gespeichert; öffentliche Kartenbeschriftungen sind Teil der Darstellung.
