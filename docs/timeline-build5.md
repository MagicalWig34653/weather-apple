# Zeitleiste am unteren Kartenrand

Stand: 28. Oktober 2026. Umsetzung und gezielte Simulatorprüfung abgeschlossen; Integration und unabhängige Abnahme des gesamten nächsten Kandidaten stehen separat an. Nach Nutzerfeedback soll die Zeitleiste deutlich weniger Höhe beanspruchen und möglichst weit unten sitzen; Apples Wetterkarte dient als funktionale Inspiration, nicht als pixelgenaue Vorlage.

## Layoutentscheidung

Die komplette bisherige untere Prognosekarte entfällt. Bei normaler Schrift steht nur eine schmale native Glasleiste mit Play/Pause, Slider, Zeitpunkt/Messung beziehungsweise Vorhersage und Jetzt über dem unteren sicheren Bereich. Der Prognosezugang liegt separat oben: So bleiben die Karte und die untere Einhandbedienung frei. Datenlauf und Datenalter stehen in den Prognosedetails; Lade-/Fehlerhinweise bleiben auf der Karte sichtbar. Ortspeicherung bleibt über den kleinen Prognosezugang erreichbar.

Bei Accessibility-Schriftgrößen stehen vollständiger Zeitpunkt und Messung/Vorhersage über der Kontrollzeile; die größere Höhe ist beabsichtigt. Die Prognosevorschau wird zum knappen Detailszugang, damit lange Sätze nicht über die Glasfläche ragen. Buttons behalten mindestens 44 Punkte Bedienfläche. Die Kartenattribution erhält weiterhin den tatsächlich gemessenen unteren Overlayabstand.

## Aktuelle Primärquellen

Am 28. Oktober 2026 geprüft:

- [Apple Wetterkarten auf dem iPhone](https://support.apple.com/guide/iphone/view-weather-maps-iph0960651f5/ios): die aktuelle iOS-27-Anleitung beschreibt die Zeitleiste am unteren Kartenrand. Keine Sichtung der Apple-Wetter-App im Simulator behauptet.
- [HIG Typography](https://developer.apple.com/design/human-interface-guidelines/typography): eingebaute Textstile und Anpassung an große Schriftgrößen; wichtige Inhalte priorisieren.
- [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility): größere Schrift und geeignete Bedienflächen.
- [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials): Liquid Glass sparsam für interaktive Bedienelemente, reguläre Variante für Lesbarkeit über Karten.
- [HIG Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders): vertraute Richtung und unmittelbare Rückmeldung. Der native Slider behält Zeit-/Phasenansage und die Spannweite als Accessibility-Hinweis.

## Prüfung und Übergabe

Der Build-4-HIG-Audit blieb auf dem eingefrorenen Quellencheckpoint. Danach besaß zunächst der P0-Datenfix, anschließend dieser UI-Auftrag exklusiv Simulator und Buildressourcen. Kein Daten-/KI-Cache, keine Projekt-/Buildnummer-, Signing- oder Backendänderung durch diesen UI-Auftrag.

## Prioritätsänderung während der Umsetzung

Neues Nutzerfeedback: Build 4 lädt subjektiv noch langsamer, Radar ist wiederholt unvollständig und Refresh zeigt zu wenig Rückmeldung. Die unabhängige Radar-Diagnose hat Vorrang vor Designbuild und Upload; dieser UI-Auftrag startet bis zur Ressourcen-/Diagnosefreigabe keinen Simulatorbuild. Zusätzlich soll der Refresh unmittelbar sichtbar starten und mit erkennbarem Erfolg beziehungsweise Fehler enden, auch bei Cachetreffern. Getrennte Radar-/Ortsprognose-Ladezustände werden mit dem Daten-/Map-Verantwortlichen abgestimmt; fertiger Zeitindex darf nicht als vollständig geladene Radarkarte ausgegeben werden. Keine Cache-/Mapänderung durch diesen UI-Auftrag.

## Refresh-Schnittstelle und ehrliche Rückmeldung

Mit dem Daten-/Map-Fix abgestimmt: `RadarLoadState` liefert ausschließlich den aktuellen Frame-/Lauf-/Reload-/Viewportkontext, offene/erfolgreiche/fehlgeschlagene angeforderte Kacheln und tatsächlich abgeschlossene DWD-Radar-Responsebytes. Die UI verwirft fremde Frame-/Lauf-/Reloadmeldungen. Die frühere dauerhaft gesetzte Fehlerflagge entfällt; sichtbare Fehler beziehen sich auf den aktuellen Kartenkontext.

Die kleine Refresh-Glaspille im Header zeigt `Radar · … MB`. Es handelt sich um empfangene Responsebodybytes des aktuellen Radar-Ladevorgangs, einschließlich Fehlerantworten; Cachetreffer, Grundkarte und Ortsprognose zählen nicht mit. Keine Streaminggeschwindigkeit, keine zusätzlichen Requests und kein Gesamtspeicher-Füllstand. Weil die vollständige sichtbare Kachelanzahl nicht zuverlässig bekannt ist, bleibt der Ring unbestimmt; kein künstliches Prozent oder 100-Prozent-Versprechen. Bei Reduce Motion ersetzt ein statisches Ladesymbol den rotierenden Indikator. Der Tap wird synchron quittiert. Ein bereits abgeschlossenes Cacheergebnis zeigt sofort ein Abschlusszeichen und `Radar · Cache`; eine kurze Tap-Sperre erfindet keine zusätzliche Netzaktivität. Der Cachehinweis verlangt explizit gezählte Cachetreffer für alle erfolgreichen Kacheln und null empfangene Radarresponsebytes, nicht bloß eine Null-Byte-Messung. Radar- und Ortsprognoseladen sind getrennt. Ein Abschlusszeichen und die Accessibility-Ansage betreffen nur die tatsächlich angeforderten Kacheln; Fehler erhalten zusätzlich einen Text und eine Erneut-versuchen-Aufforderung.

Swift-Syntaxparse und Diffprüfung ohne Fehler. Der integrierte Fix-/UI-Snapshot wurde erfolgreich kompiliert; konkrete Prüfbelege folgen unten.

Die Wiedergabe wartet auf den Abschluss der tatsächlich angeforderten aktuellen Framekacheln, statt bei langsamen Antworten im Zwei-Sekunden-Takt fortwährend neue Frames anzufordern. Ohne Requests/Callbacks oder bei dauerhaft offenen Antworten bleibt diese Wartezeit pro Frame auf zwölf Sekunden begrenzt; Offline-/Leerzustände stoppen die Animation dadurch nicht dauerhaft. Der nächste erfolgreiche Frame benötigt keine künstliche Zwölf-Sekunden-Pause.


## Tatsächlich ausgeführte UI-Prüfungen

- iPhone 18 Pro, 402 × 874 Punkte, iOS-27-Simulator, ausschließlich öffentlicher Beispielort Berlin, keine Standortfreigabe.
- Radarzeit → Vorhersage → Jetzt/Messung → Play/Pause → Details/Einordnung: erfolgreich, 16,864 s.
- Refresh-Tap: unmittelbar Lade- oder bereits abgeschlossenes Cacheergebnis; erfolgreicher Test, 7,908 s. Die Aufnahme zeigt das echte `Radar · Cache`-Ergebnis mit Abschlusszeichen. Die vollständige Kartenabdeckung wird dadurch nicht garantiert.
- Normale Schrift: erfolgreicher Test, 7,476 s; Play und Jetzt jeweils 44 × 44 Punkte, Play bei y=788. Untere Kontrollzeile, Slider und Jetzt sind getrennt bedienbar.
- Maximale Dynamic Type (`accessibility-extra-extra-extra-large`): erfolgreicher gezielter Lauf, 7,954 s. Vollständige Zeit und Messung stehen oberhalb der Bedienelemente; Play 44 × 44 Punkte, Jetzt 111,3 × 58,7 Punkte. Die kombinierte Zeitgruppe endet vor der Kontrollzeile; keine Überlagerung oder abgeschnittene Zeit. Das ursprüngliche Layoutproblem ist für diesen Bildschirm im Simulator visuell und über Frame-/Bedienassertionen geschlossen. Kein vollständiger VoiceOver-/Geräteaudit behauptet.
- Der erste AX-Testlauf scheiterte ausschließlich an einem abschließenden Debugzugriff auf einen von SwiftUI zusammengeführten Accessibility-Identifier. Der Locator wurde auf die tatsächlich exponierte kombinierte Zeitgruppe korrigiert; nur der betroffene Test wurde wiederholt. Keine Produktlayoutkorrektur dafür nötig.
- Light und Dark gesichtet: native Glasleiste, Prognosezugang, Fehlerhinweis und MapKit-Attribution bleiben lesbar/frei. Die Livequelle meldete beim normalen Vorschaulauf teilweise fehlende Kacheln; der echte Fehler wird im Bild gezeigt und nicht entfernt. Das ist keine Verfügbarkeitsgarantie.
- Nach dem gemeinsamen Retrybudget-Fix wurden auf Bitte des Datenverantwortlichen ausschließlich drei betroffene Budget-/XML-Tests ausgeführt: alle erfolgreich. Nach dem abschließenden Drei-Zeilen-Fix für die initiale Kartenzentrierung erfolgreicher inkrementeller Simulatorbuild, keine volle Testsuite oder Coldstartmatrix erneut. Der Datenverantwortliche übernimmt die letzte Coldstartsequenz separat.

Die aufgeführten UI-Ergebnisse stammen aus dem ersten gezielten Vierer-Lauf und dem notwendigen AX-Locator-Rerun; kein nachträglich behaupteter vollständiger neuer UI-Gesamtlauf. Die abschließenden Änderungen betreffen den Source-Unavailable-Animationsstopp, kB-Anzeige kleiner Datenmengen und die initiale Map-Zentrierung; sie wurden kompiliert. Die vollständige Daten-/Radarabnahme steht im [P0-Befund](performance-regression-build4.md).

## Gemessene untere Kartenfläche

Vergleich bei normaler Schrift auf demselben 402 × 874-Punkt-iPhone:

| Unterer Bereich | Build 4 | Neuer UI-Stand |
| --- | ---: | ---: |
| Gesamte unten reservierte Höhe, alle unteren Flächen plus Außenabstände und 34 pt Safe Area | ca. 243 pt | 96 pt |
| Davon neue eigentliche Glas-Kontrollleiste | – | 56 pt |
| Neue äußere Abstände | – | 6 pt |

Methode: Build-4-Audit-AX-Messung des Prognosebuttons y=647,3 pt, abzüglich 6 pt Karteninnenabstand und 10 pt äußerem oberen Abstand ergibt den Start des gesamten alten unteren Insetbereichs bei etwa y=631,3; 874−631,3≈242,7 pt. Die ursprünglichen beiden unteren Karten sind damit vollständig enthalten. Der neue Playbutton beginnt bei y=788, liegt 6 pt unter dem Glasbeginn; Glasbeginn y=782, zusätzlich 4 pt äußerer oberer Abstand → Insetbeginn y=778, also 874−778=96 pt inklusive Safe Area. Die unteren Overlays beanspruchen so ungefähr 147 pt weniger Höhe. Der separat nach oben verschobene 44-pt-Prognosezugang ist ausdrücklich keine verschwundene Oberfläche; die Zahl beschreibt den zurückgewonnenen unteren Kartenbereich, keine pauschale Nettoflächenmessung aller oberen und unteren Controls. Bei maximaler Schrift darf die adaptive Leiste höher werden.

## Sichere Vorschauen und Reproduktion

- [Vorher: Build 4 Dark](../design/UI/HIG-build4/main-dark.png)
- [Neue Leiste Dark](../design/UI/build5/after-dark.png)
- [Neue Leiste Light](../design/UI/build5/after-light.png)
- [Maximale Accessibility-Schrift](../design/UI/build5/after-maximum-dynamic-type.png)
- [Echtes Cache-Refresh-Ergebnis](../design/UI/build5/refresh-feedback.png)

App mit Berlin starten, normales Large-Schriftformat wählen und Zeit/Play/Jetzt bedienen. Prognosezugang oben öffnet Datenalter und Details. Systemdarstellung zwischen Light/Dark wechseln. Für die maximale Schrift `accessibility-extra-extra-extra-large` verwenden; Zeit und Phase müssen vollständig oberhalb der Bedienzeile stehen. Die Screenshots enthalten ausschließlich Berlin und öffentliche Kartenbeschriftungen, keine private Standort-/Ortsliste oder andere App. Reduce-Motion-Verhalten ist implementiert, hier jedoch nicht in einem eigenen finalen Settingslauf visuell abgenommen. Keine echte Apple-Intelligence-Generierung oder physische Geräteprüfung hinzugefügt.

## Slider muss immer sichtbar reagieren (Nutzeranforderung 29. Oktober 2026)

Anforderung: Bewegt der Nutzer den Zeit-Slider, ist immer eine Bewegung erkennbar, auch wenn das Radarbild des Ziel-Slots noch nicht geladen ist oder das Laden fehlschlägt.

Befund: Thumb und Zeitanzeige waren direkt an `store.selectedFrame` gebunden und liefen nicht auf Bildladung. Sichtbar ausgeblieben ist die Rückmeldung in der Karte: `RadarMap.updateUIView` entfernt beim Slotwechsel sofort das Overlay und legt ein neues an; bis Kacheln eintreffen (oder dauerhaft bei Fehlern) zeigt die Karte kein Radar und keinen Hinweis, welcher Slot gemeint ist. Zusätzlich schnitt `Int($0)` Slider-Werte ab statt zu runden, und es gab kein haptisches Feedback.

Umsetzung (nur UI, keine Prefetch-/Backend-Änderung): lokaler `scrubIndex` treibt Thumb, Zeit, Messung/Vorhersage und Accessibility-Wert unabhängig vom Netz; Pille unten auf der Karte „Radar für HH:MM lädt …“ bzw. „… nicht geladen“, solange der Ladezustand des gewählten Slots nicht erfolgreich abgeschlossen ist (altes Bild wird nicht als aktueller Stand ausgegeben); `.sensoryFeedback(.selection)` beim Slotwechsel durch Ziehen; reine Logik in `TimelineSlot` (Runden/Klemmen, Status). Test: `WeatherTests/TimelineSlotTests`.

Prüfung: gezielter Test `TimelineSlotTests` und Simulatorbuild, siehe Abschlussbericht. Nicht geprüft: visuelles Verhalten der Pille und Haptik im Simulator/Gerät, UI-Test.
