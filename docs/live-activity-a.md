# Live Activity, Entwurf A (getöntes Glas)

Stand: 20. November 2026, Branch `feature/live-activity-a` (aus `077ce7c`, Build-53-Linie; keine Buildnummer, nicht archiviert, nicht in `main`). Todolino-Karte "Live Activities" (ACA39B84). Gestaltung: Branch `design/live-activity-entwuerfe` (`design/live-activity/`, Entscheidung Lino 19.11.: A; auf der Watch nur die kompakte Karte im Smart Stack).

## Primärquelle Watch (gelesen 20.11.2026)
- Apple-Dokumentation `ActivityFamily` (`developer.apple.com/documentation/widgetkit/activityfamily`, per Dokumentations-JSON gelesen): "A family that defines the Live Activity's size." `small`: "A size family of a Live Activity on watchOS." `medium`: "A size family of a Live Activity on iOS and macOS." Text: "If you want to opt in to customize the rendering for a Live Activity for the watchOS Smart Stack, use the `supplementalActivityFamilies` family modifier."; die Familie wird in der Ansicht über die Umgebung (`activityFamily`) gelesen.
- SDK 27.2 (`WidgetKit.swiftinterface`): `ActivityFamily` (`small`, `medium`), `WidgetConfiguration.supplementalActivityFamilies(_:)` und `EnvironmentValues.activityFamily` sind ab iOS 18 verfügbar, für watchOS als `unavailable` markiert. Die Watch-Karte entsteht also in der iOS-Widget-Erweiterung (`WeatherWidgets`), nicht in einem Watch-Target. Eine Watch-Erweiterung bekommt dafür nichts.
- Nicht belegt: wie die Karte auf echter Hardware gerendert und in der Höhe begrenzt wird, ob `Text(timerInterval:)` dort identisch zählt. Annahme, zu prüfen auf einer gekoppelten Uhr.

## Bestand gegen Entwurf
| Fläche | Bestand (Build 53) | Entwurf A / jetzt |
|---|---|---|
| Sperrbildschirm | Symbol links, Überschrift + Timer, Detail, schwarzer Tint 55 % | Ortszeile + "Stand", ein großer Zeitsatz ("Regen in 8:30", Zahl getönt), Symbol in getönter Kachel, Zustandsverlauf über dem Systemhintergrund |
| Island kompakt/minimal | Symbol, Timer oder Kurztext | unverändert (Symbol + Timer, "Veraltet", "34 %") |
| Island erweitert | Symbol / Timer / Überschrift getrennt | Zeile Symbol + Ort links, "Stand" rechts, darunter derselbe Zeitsatz wie auf dem Sperrbildschirm, Gebietszeilen |
| Watch | keine eigene Fassung (System-Standard) | `supplementalActivityFamilies([.small])`: kompakte Karte `RainWatchCardView` |

Logik (rein, getestet): `RainActivityPresentation` bekommt `tone` (Regen, trocken, veraltet), `hero` (Countdown mit kleinem Label oder ein Satz), `heroDetail`, `watchTitle`, `watchShareText`; `RainActivityRegionPresentation` die Kurztexte "34 % nass" / "bis zu 34 % nass". Veraltet zählt nie herunter und liest sich nie als trocken (Grenze genau 20 Minuten). Neue Texte (de/en): nur `REGION_ACTIVITY_SHARE_NOW_SHORT`, `REGION_ACTIVITY_SHARE_PEAK_SHORT` in `SharedTexts`; alle anderen Texte sind vorhanden.

Dateien: `WeatherWidgets/LiveActivity/RainActivityCards.swift` (Ansichten ohne ActivityKit, daher in Unit-Tests rendern), `RainLiveActivity.swift` (Konfiguration), `RainActivityPresentation.swift`, `Shared/RainActivityRegionPresentation.swift`; Tests `RainActivityPresentationTests`, `LiveActivityImageTests`; `project.yml`: `WeatherWidgets/LiveActivity` (ohne `RainLiveActivity.swift`) im Test-Target.

## Entscheidungen zur Bestätigung (von mir getroffen, Lino bitte bestätigen)
1. **Timer statt feste Minuten.** Countdown bleibt `Text(timerInterval:)` ("8:30", Systemuhr). Der Entwurf zeigte "8 Min." als Text; ein statischer Minutentext wäre bis zum nächsten Push falsch, und dass die Ansicht in einer Live Activity von selbst neu gerechnet wird, ist nicht belegt (nur die Textstile der Systemuhr tun das). Alternative, nicht ausprobiert: `Text(date, style: .relative)`.
2. **Gebietszustand auf der Watch:** nur Name (ohne "Umkreis 10 km", fehlt der Name, steht der Umkreis) und unter "Stand" die Kurzzeile "bis zu 34 % nass" bzw. "34 % nass". Kein Balken, keine "Stärkste Stufe" auf der Watch.
3. **Quellzeile:** nur "Stand HH:MM", kein "DWD" (Breite; auf dem iPhone-Sperrbildschirm ebenso nicht). Die Komplikation zeigt "DWD · Stand". Ob für Live Activities eine Quellennennung verlangt ist, ist hier nicht geprüft.
4. **Kartengröße:** System bestimmt die Höhe. Eigene Obergrenze per Test: Ort höchstens 125 pt, Gebiet 140 pt (Entwurf ca. 102 pt) bei 150 pt Breite. Gegen Xcode-Vorschau/Uhr nicht geprüft.
5. Nicht umgesetzt (Entwurf B/C): Uhrzeit des Ereignisses, Intensität für Orte, Mehrfach-Activity.

## Prüfung (20.11.2026)
Siehe `status.md` (Eintrag Live Activity A). Kurz: Unit-Tests 14/14 für die Logik (12 zuvor rot), Bildtests 4/4, volle `WeatherTests` 744 grün, `check_l10n --strict` Exit 0. Echte Live Activity im Simulator (Island, Sperrbildschirm, hell/dunkel, Accessibility 5) über den Debug-Hook `-UITestLiveActivity`. Nicht geprüft: Watch-Smart-Stack auf echter Uhr oder gekoppeltem Simulator, Push-to-Start/Remote-Updates, echtes Gerät. Bilder liegen im Orchestrator-Nachweis `showers-live-activity-impl/`, nicht im Repo.
