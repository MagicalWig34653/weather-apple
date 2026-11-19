# Live Activity: Gestaltungsentwürfe A, B, C (19.11.2026)

Reine Gestaltung für die Karte „Live Activities“. Kein Produktcode geändert, nichts gebaut oder getestet. Alle Tafeln zeigen dieselben **Beispieldaten** aus [beispieldaten.json](beispieldaten.json) (frei gewählt, keine Messwerte, keine echten Orte). Orts- und Gebietsname stammen aus den Vorschauen in `RainLiveActivity.swift` („Zuhause“, „Umland“, Umkreis 10 km).

Bilder: `bilder/` (PNG, 2x Pixel; Maße in Punkten: iPhone 402 × 874, Island kompakt 244 × 37 / erweitert 374 breit, Watch 40 mm = 162 × 197). Dieselben Dateien liegen unter `~/Development/orchestrator/runtime/nachweise/showers-live-activity/`.

| Datei | Inhalt |
|---|---|
| `uebersicht.png` | A, B, C untereinander; je iPhone, Island, Watch in hell und dunkel; Zustand „Regen kommt in 8 Min.“ |
| `uebersicht-gebiet.png` | dasselbe für „Gebiet: Regen läuft“ |
| `{a,b,c}-iphone-{hell,dunkel}.png` | Sperrbildschirm: ein Telefon (kommt) plus Banner aller anderen 5 Zustände |
| `{a,b,c}-island-{hell,dunkel}.png` | Dynamic Island kompakt und erweitert, alle 6 Zustände, Hintergrund hell/dunkel |
| `{a,b,c}-watch-{hell,dunkel}.png` | Watch Smart Stack (40 mm), alle 6 Zustände |

## Zustände (Beispieldaten)
Regen kommt in 8 Min. · Regen läuft · Regen endet bald (5 Min.) · Daten veraltet · Gebiet: Regen kommt in 12 Min. (bis zu 34 %) · Gebiet: Regen läuft (34 %, Stärkste Stufe 4).

## Die Entwürfe
**A, getöntes Glas, Zeitsatz als Blickfang**
- Widgetnah: Verlauf aus Zustandsfarbe über Material (wie `containerBackground` der Widgets), Zeitsatz „Regen in 8 Min.“ groß, Symbol in getönter Kachel.
- Island und Watch führen denselben Zeitsatz: kompakt „8 Min.“, Watch „Regen in / 8 Min.“ in 41 pt.
- Stärken: schnellste Lesbarkeit, geringster Umbau gegenüber heute. Schwächen: ohne Uhrzeit, bei Gebiet viele Textzeilen.

**B, ruhige Zeitachse**
- Neutrales Material, eine Achse „Jetzt“ bis Ereignis. Nur belegte Marken (Jetzt, Beginn oder Ende aus `eventDate`, Stand); kein Verlauf, keine Zwischenwerte. Ohne Ende läuft das Band offen aus („Ende nicht absehbar“), bei veraltet gestrichelt orange („Verlauf unbekannt“).
- Island kompakt zeigt die Uhrzeit („14:42“, „bis 15:11“); Watch: Uhrzeit groß, Achse klein.
- Stärken: ruhig, ehrlich bei Lücken, Uhrzeit absolut lesbar. Schwächen: weniger Blickfang, Achse trägt wenig Information; Achsenfenster 0 bis 15 Min. ist nur Positionierung der belegten Marken.

**C, Orts-/Gebietskarte**
- Kopf: Ort (Gebiet mit Chip „Umkreis 10 km“) und Statuspille. Gebiet: Ring mit Anteil („34 %“ gefüllt; „bis zu 34 %“ nur gestrichelt, weil Prognose), Stärkste Stufe. Fehlende Werte entfallen.
- Island kompakt: Gebiet zeigt Pin und „34 %“ bzw. Countdown; Watch: Status zuerst, Ring klein.
- Stärken: macht Ort/Gebiet und Anteil sichtbar, Zustand per Pille. Schwächen: dichteste Variante, auf der Watch eng; Orte ohne Gebietsdaten wirken leer.

## Belegt (RainActivityPresentation / RainActivityRegionPresentation, origin/main)
Phasen startsIn (mit/ohne Countdown), raining („Ende nicht absehbar“), endsIn („Endet in“), dry (nicht dargestellt, da die Activity dann endet), veraltet („Daten veraltet“, „Keine verlässliche Aussage“, orange, kein Countdown). Gebiet: Umkreis, Anteil jetzt/bis zu, Stärkste Stufe samt Wort, Balken nur bei „jetzt“, kompakter Text „34 %“. Quellzeile: auf iPhone wie heute „Stand HH:MM“; auf der Watch wäre „DWD · Stand HH:MM“ wie in `WatchRainWidgetView`, im Entwurf nur „Stand“ (Platz). Texte sagen „Regen“, nie „Warnung“.

## Neu gegenüber der App (gekennzeichnet, nichts davon im Code)
- **Uhrzeit des Ereignisses** (aus `eventDate`, vorhanden, bisher nur als Countdown): Entwurf B, Teile von C („Beginn um 14:42 Uhr“, „Ende um 15:11 Uhr“), Watch.
- **Intensität am Ort** („Intensität Stufe 2 (sehr leicht)“, aus `intensityClass`, vorhanden, bisher nur für Gebiete angezeigt): Entwurf C.
- **Statik statt Timer:** „8 Min.“ ist Text. Die App nutzt `Text(timerInterval:)`, das „7:59“ zählt. Minutenanzeige wäre eine Änderung am Countdown.
- Watch: gekürzte Texte („bis zu 34 % nass“, „Fläche nass“), Watch-B ohne Anteil. Eigene Smart-Stack-Kartenfassung (`supplementalActivityFamilies`) gibt es in der App noch nicht.
- **Fehlt:** Zustand mit Beginn und Ende gleichzeitig (Dauer) ist im Modell nicht vorhanden (nur ein `eventDate`); `dry` hat keine Darstellung (Activity endet).

## Offene Fragen für Lino
1. Countdown als laufender Timer (heute) oder als „8 Min.“ in Minutenschritten (A-Blickfang)?
2. Uhrzeit des Ereignisses zusätzlich zeigen (B, C) oder nur relative Zeit?
3. Intensität am Ort anzeigen (C) oder weiter nur für Gebiete?
4. Watch-Smart-Stack: eigene kompakte Fassung bauen oder System-Spiegelung des iPhone-Layouts lassen? Kartengröße und Kopfzeile bitte gegen Xcode-Preview/Gerät prüfen.
5. „DWD“ auf der Watch-Karte (wie Komplikation) oder nur „Stand“?
6. Es läuft nur eine Activity je Gerät: soll Ortswechsel/mehrere Orte (erster Wunsch) berücksichtigt werden? Nicht dargestellt, da keine Mehrfach-Activity vorgesehen (docs/research/live-activity-gebiete.md).

## Technik und Grenzen
Erzeugt mit `render/render.py` (nur Stdlib, liest `beispieldaten.json`) und `render/snap.swift` (WKWebView-Snapshot offscreen, kein Fenster). Aufruf: `python3 render/render.py <ordner>` und `snap <w> <h> 1 in.html out.png`. Symbole sind nachgezeichnet (keine SF Symbols), Schrift ist die Systemschrift SF. Dynamic-Island-, Watch- und Lock-Screen-Maße sind Erfahrungswerte; Glas ist per CSS-Blur nachgebildet. Nicht geprüft: echtes Gerät, ActivityKit, Simulator, Dynamic Type, Bedienungshilfen, Reduzierte Transparenz, Kontrastwerte rechnerisch. Die hell-Variante der Watch ist nur ein Vergleich: watchOS kennt kein Hell/Dunkel.
