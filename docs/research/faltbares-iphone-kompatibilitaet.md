# Faltbares iPhone (iPhone Duo): Kompatibilität für ShowerNow

Stand: 3.11.2026. Recherche ohne Repo-Änderung/Build. Kennzeichnung: **[belegt]** = Apple-Primärquelle, **[sekundär]** = nur Drittseiten, **[Annahme]** = Hypothese.

## 1. Gerät

- **Name: iPhone Duo** [belegt]. Vorgestellt 9.9.2026 ("Surprise and Shine", sekundär BGR/NPR), Vorbestellung 16.10., Verkauf 23.10.2026 (weitere Märkte 30.10.). Quelle: https://www.apple.com/uk/newsroom/2026/09/apple-unveils-iphone-duo/
- Betriebssystem: iOS 27, ausgeliefert mit **iOS 27.1** [belegt, gleiche Quelle].
- Displays [belegt]: Innen 7,6" (7,58" als Rechteck), Außen 5,4" (5,36"), beide Super Retina XDR, ProMotion, Always On. "Both displays share the same aspect ratio". Dynamic Island verläuft **vertikal** an der Seite beider Displays und erweitert sich für Live Activities.
- Faltmechanik [belegt]: Scharnier aus über 100 Teilen, Magnete zum Schließen; zugeklappt nutzbar über das Außendisplay, aufgeklappt Innendisplay. Unter-Display-Kamera innen [sekundär BGR].
- Pixelgrößen (aus App-Store-Connect-Screenshotspezifikation, belegt): Außen 1398 x 2034, Innen 2007 x 2853 (Hoch; Quer vertauscht). Seitenverhältnis ca. 0,687 (alle Displays gleich; passt rechnerisch). **Scale/Punktgröße nicht in Primärquelle gefunden**; [Annahme] 3x ergäbe ca. 466 x 678 pt bzw. 669 x 951 pt: im Simulator verifizieren.
- Neue Software auf Duo (iOS 27.1) [belegt]: Split View (erstmals iPhone, auch zwei Fenster derselben App), StandBy auf beiden Displays (neue Kalender-/Wetter-Faces), zwei Home-Screen-Seiten aufgeklappt mit Today View links.

## 2. Vorgaben für Entwickler

Hauptquelle: Apple Tech Talk "Prepare your app for iPhone Duo", https://developer.apple.com/videos/play/tech-talks/111461/ [belegt].

- **Xcode 27.1+** nötig; Simulator über **Device Hub**; Knöpfe zum Öffnen/Schließen/Drehen/Falten.
- **Simulator-Gerätetyp: `iPhone Duo`** (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`), lokal in Xcode 27.2 (27B52) per `xcrun simctl list devicetypes` bestätigt. Lokal ist **noch kein Gerät dieses Typs angelegt** (`simctl list devices available` zeigt keines); Laufzeit iOS 27.2 vorhanden.
- **Größenklassen** [belegt]: Außendisplay wie normales iPhone (Hochformat compact x regular; Quer compact x compact). Innendisplay: **regular x regular**. Innendisplay ignoriert `supportedInterfaceOrientations`, also Layout nach Size Class statt Orientierung. SwiftUI `horizontalSizeClass`/`verticalSizeClass`.
- **Zuklappen/Aufklappen** ändert die Fenstergröße: App muss live umlayouten.
- **SDK-Verhalten** [belegt]: Alte SDK: App läuft, vertraute Größe/Seitenverhältnis (außen: Platz links von Statusleiste/Kamera). iOS-27-SDK: Inhalt reicht links neben Statusleiste. **iOS-27.1-SDK**: bis zum Bildschirmrand, Standard-Navigations-/Toolbar-Buttons werden vertikal unter der Statusleiste angeordnet.
- **Safe Area asymmetrisch**: nicht mit festen Werten, `safeAreaInsets` je Seite nutzen. `UIScreen.main` ersetzen (`traitCollection.displayScale`, `windowScene.screen`); zwei Displays.
- **Neue APIs (iOS 27.1)**: `ReservedRegion` (SwiftUI) / `UIViewReservedRegion` (UIKit) für eigene Leisten außerhalb der Safe Area. Konzentrische Ecken: `ConcentricRectangle` / `UICornerConfiguration`.
- **TabView**: Standard-Tabs auf beiden Displays; Sidebar auf Innendisplay per `.defaultTabBarPlacement(.sidebar)`. Sheets sind innen zentriert.
- **Info.plist**: `UIRequiresFullScreen` wird weiter beachtet, App wird beim Öffnen/Schließen trotzdem skaliert [belegt]. Weitere Schlüssel (Multitasking-Opt-in) in Primärquelle nicht genannt; **offen**. Split View: App ziehen, auf beiden Seiten testen [belegt].
- **Live Activities/Dynamic Island/Widgets**: Apple-Newsroom bestätigt vertikale Dynamic Island mit Live-Activity-Erweiterung und Widgets/Today View. Entwicklerdetails (Layouts, Limits) **nicht in Primärquelle gefunden**; Xcode-27.1-Release-Notes waren per Fetch leer. [sekundär, unverifiziert] Hinweis auf Bug: Dynamic-Island-Live-Activities falsch dimensioniert bei `EmptyView`-Konfiguration mit `isDynamicIslandLimitedInWidth` (iOS 27.x); selbst prüfen.
- Kamera-/Falt-APIs: keine Primärquelle gefunden; für ShowerNow irrelevant.

## 3. App Store Connect

Quelle: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/ [belegt]

| Display | Hoch | Quer |
|---|---|---|
| Außen | 1398 x 2034 | 2034 x 1398 |
| Innen | 2007 x 2853 | 2853 x 2007 |

- Aktuell **optional**; **ab April 2027 Pflicht** für Apps mit iOS-27.1-SDK oder neuer. Mit Duo-Screenshots zeigt die Produktseite ein "Optimized for iPhone Duo"-Hinweis (Badge). PNG/JPEG ohne Alpha (sekundär).

## 4. Checkliste ShowerNow (SwiftUI, MapKit, Widgets, Live Activity, Watch)

1. Duo-Simulator (Gerät anlegen, iOS 27.2) starten; App in Außen/Innen, Auf-/Zuklappen, Drehen, Split View links/rechts prüfen (kein Zustandsverlust, Radar-Karte, Zeitleiste).
2. Layout nach Size Class: Innendisplay regular x regular (iPad-ähnlich, Sidebar/Zwei-Spalten erwägen); keine festen Breiten/`UIScreen.main`/Orientierungsannahmen (im Code suchen).
3. Mit iOS-27.1-SDK bauen: Navigationsleisten/Toolbars vertikal, Safe Area asymmetrisch; Overlays auf der Karte (Zeitleiste, Buttons, Attribution) gegen Safe Area/ReservedRegion prüfen.
4. MapKit: Kamera/Region bleibt beim Fold-Resize stabil; Kartenüberlagerungen und Rechtetext nicht abgeschnitten.
5. Live Activity: Kompakt/Minimal/Expanded in vertikaler Dynamic Island; Bug-Hinweis `isDynamicIslandLimitedInWidth` prüfen; Sperrbildschirm-Layout.
6. Widgets: Größen auf Außen-Home-Screen, Today View, StandBy-Wetter-Faces; Timelines laufen auch bei Größenwechsel.
7. `UIRequiresFullScreen` in `Configuration/Info.plist` prüfen: nicht setzen (wäre Skalierung; Multitasking/Split View soll möglich sein). Orientierungen auf Innendisplay wirkungslos.
8. Watch: unverändert (kein Duo-Bezug gefunden).
9. App Store: Screenshots Duo (außen + innen) spätestens bis April 2027 vorbereiten; optional früher für Badge.
10. Offen: Scale/Punktgrößen, Multitasking-Plist-Schlüssel, Widget-/Live-Activity-Regeln aus Apple-Dokumentation nachlesen (Release Notes Xcode/iOS 27.1 waren nicht abrufbar).

## 5. Lokale Prüfung (3.11.2026, Simulator)

Gerät: `ShowerNow Duo`, UDID `4D5A834D-9196-476B-A076-4315134D36A6`, Typ `iPhone-Duo`, Laufzeit `iOS 27.1 (24A94425)`, Xcode 27.2. `simctl create`/`boot` erfolgreich; Schema Weather mit `-destination id=<UDID>` und `CODE_SIGNING_ALLOWED=NO` gebaut (BUILD SUCCEEDED, ohne Änderung der `simctl runtime match`-Zuordnung), installiert und gestartet.

**Gemessen (Außendisplay, nicht geschätzt):**
- Zwei Displays (`simctl io enumerate`): Display 1 "LCD" 1398x2034 px, Display 3 "LCD-1" 2007x2853 px (Innendisplay).
- Außendisplay per Mess-App (UIScreen/UIWindow): Bounds 466x678 pt, Scale 3,0 (nativeScale 3,0), Safe Area oben 0, links 0, unten 34, rechts 84 pt. Size Classes compact x regular (hSC=1 compact, vSC=2 regular), Standard-Dynamic-Type L. Die vertikale Dynamic Island steht also am rechten Rand (84 pt Inset), nicht oben.
- Innendisplay: siehe unten (gemessen).

**Gemessen (Innendisplay, 3.11.2026 abends, Nutzer hatte im Device Hub aufgeklappt; beide Displays zeigten sich als aktiv):**
- `simctl io enumerate`: Display-Klasse 0 mit 2007x2853 px (Innen) und 1398x2034 px (Außen) gleichzeitig "On"; `simctl io <udid> screenshot --display=3` liefert das Innendisplay als **2853x2007 px, Querformat gedreht** (ohne `--display` Fehler "Invalid argument"; `--display=1` = Außen). Mess-App (`x.probe`, per `simctl launch`): Bounds **951x669 pt**, Scale 3,0 (nativeScale 3,0), Safe Area **oben 0, links 0, unten 34, rechts 84 pt** (Island rechts), Size Classes **regular x regular** (hSC=2, vSC=2), Dynamic Type L. Die Safe-Area-Layoutfläche ist 867x635 pt.
- `XCUIScreen.screens` liefert beide Displays (Index 1 = Innen); dessen PNG hat Framebuffer-Orientierung (2006x2852, Hochformat, gegenüber der Anzeige um 90 Grad gedreht; `sips -r 90` richtet es aus). `XCUIApplication.frame` meldet 669x951, die Elementframes aber Querformat-Koordinaten (bis x=847, y=627): in Tests auf dem Innendisplay Elementframes statt `app.frame` verwenden.
- Orientierung: `XCUIDevice.shared.orientation = .portrait` änderte auch innen nichts (Bild identisch bis auf Uhrzeit). Das Innendisplay lief in dieser Sitzung durchgehend 951x669 pt; Hochformat 669x951 wurde nicht beobachtet (Drehen wäre ein Device-Hub-Knopf, vom Nutzer zu bedienen).
- Getesteter Stand: App aus der Scratchpad-Kopie des Quelltexts (älter als Repo-HEAD; `RadarScreen.swift` unterscheidet sich nur in einem Alert-Text, Layoutcode identisch; das Info-Sheet zeigt noch den alten Satz "Noch keine Widgets oder Watch-App").

**Sichtbefund Innendisplay (Screenshots im Scratchpad `duo-inner/`, nicht im Repo):**
- Radar: Header-Pille, Ebenenwahl, Prognosekarte (ca. 850 pt breit), Hinweisbanner und Zeitleiste (ca. 845 pt) laufen über die gesamte Breite bis zum 84-pt-Streifen der Island; nichts wird abgeschnitten, nichts überlappt die Island (Uhrzeit/Netz im freien rechten Streifen), Buttonleiste rechts bündig mit den Karten. Bedienbar, aber ungewohnt breit (Prognosekarte als langer Balken mit Text links, Lesezeichen weit rechts, Zeitleiste mit sehr langem Schieberegler). Quellenzeile sitzt mittig über der Zeitleiste; Apple-"Karten"-Logo und "Rechtl. Informationen" links sind frei.
- Prognose-Sheet, Info-Sheet und Ortsliste ("Deine Orte"): zentrierte Formularblätter, ca. 650 pt breit (Ortsliste und Info-Sheet volle Höhe, Prognose etwa 58 Prozent der Höhe), um die Bildschirmmitte zentriert (nicht um die Safe-Area-Mitte), ohne Berührung der Island. Inhalte, "Fertig" und Suchfeld sauber; Ortsliste leer (nur Regionen/Standort, keine gespeicherten Orte). Prognose-Chart wirkt wegen "Vorerst kein messbarer Regen" leer (Datenlage, nicht Layout).
- Dynamic Type AccessibilityXXXL innen: Header zentriert und sehr groß, Ebenenwahl nur noch Symbol, Prognosekarte "Prognosedetails", Zeitleiste gestapelt (Uhrzeit/"Messung" über Regler). Die Quellenzeile ("Quelle: Deutscher Wetterdienst · ShowerNow-Cache") umbricht auf zwei große Zeilen, läuft fast über die volle Breite und über die Buttonleiste rechts und den Stadtmarker; Hauptsteuerung bleibt bedienbar. Prognose-Sheet bei AXXXL: Titel zweizeilig, Chart wird in 58 Prozent Höhe abgeschnitten (scrollbar nicht geprüft). Das deckt sich mit dem Befund am Außendisplay.
- Diagnose-Hinweis: Das Prognose-Sheet blieb beim ersten Tour-Lauf offen, weil `swipeDown` es auf dem Innendisplay nicht schließt ("Fertig" tippen); danach war die Ortsliste nicht "hittable". Kein App-Fehler, aber Testhinweis.

**Innendisplay im Hochformat (3.11.2026 ca. 20:15 bis 20:25, Nutzer hatte im Device Hub hochformatig aufgeklappt; Screenshots Scratchpad `duo-inner-portrait/`, nicht im Repo):**
- Gemessen (Mess-App): Bounds **669x951 pt**, Scale 3,0, Safe Area **oben 82, links 0, unten 34, rechts 0 pt**, Size Classes **regular x regular**, Layoutfläche 669x835 pt. Die Island liegt im Hochformat also oben (82 pt), nicht rechts. `simctl io --display=3` liefert 2007x2853 (Hochformat), das XCUIScreen-PNG (Index 1) 2006x2852 ohne Drehung nötig.
- Radar (L und XL): Header-Pille, Ebenenwahl, Prognosekarte, Buttonleiste und Zeitleiste sitzen unter der Island (Header ab ca. 135 pt); nichts überlappt, nichts abgeschnitten, alle Karten laufen über die volle Breite (ca. 640 pt), Zeitleiste unten über dem 34-pt-Inset. Karte läuft hinter Island/Statusleiste durch. Dank Hochformat wirkt es wie ein großes iPhone/iPad, die Querformat-Länge der Karten entfällt.
- AccessibilityXXXL Radar: Header-Pille groß und mittig, Ebenenwahl nur Symbol und unter der Pille (kein Überlappen), Prognosekarte "Prognosedetails", Quellenzeile zweizeilig und sehr groß mit halbtransparentem Hintergrund, aber keine Überlappung mit der Buttonleiste (anders als außen), Zeitleiste gestapelt ("20:10", "Messung", Regler, "Jetzt"). Buttonleiste rechts bleibt bedienbar; Info-Button etc. nicht verdeckt. Zeitleiste und Quellenzeile nehmen zusammen ca. 25 Prozent der Höhe ein.
- Prognose-Sheet: unten verankert, volle Breite abzüglich Rand (ca. 650 pt), ca. 58 Prozent Höhe, Grabber, Titel "Berlin", "Fertig". Bei AXXXL: Überschrift zweizeilig, Diagramm wird unten abgeschnitten (Achsenbeschriftung nur halb sichtbar, Sheet scrollbar nicht geprüft); Sonnenzeile nicht sichtbar. Info-Sheet und Ortsliste (L): große Sheets ab y = 82 pt (unter der Island, nicht überlappend) mit voller Höhe, Inhalte vollständig; Info-Sheet zeigt noch "Noch keine Widgets oder Watch-App" (Scratchpad-Stand). AXXXL: Texte umbrechen sauber, Titel "Über ShowerNow" klein, Inhalt scrollbar; keine Abschneidung der Überschriften.
- Befund Ortsliste bei AXXXL: Das schwebende Suchfeld ("Stadt, Adresse oder Ort") unten überlagert Listeninhalt ("Aktuellen Standort verwenden" ist darunter teilweise verdeckt), solange nicht gescrollt ist; auf dem Innendisplay (hoch, XL) nicht der Fall. Allgemeines Thema großer Schrift, nicht Duo-spezifisch.
- Gespeicherter Ort (Berlin über Lesezeichen gespeichert, in der Test-App; danach Daten durch Neuinstallation zurückgesetzt): Ortsliste mit "Gespeicherte Orte", Haken und Glocke; Push-Einstellung pro Ort ("Regenhinweis", nur angesehen, Schalter aus, nichts aktiviert): Titel, Erläuterungen, Zustellungsarten (Zeitkritisch, Apple Watch, Sport), Datenschutzblock und "Datenschutzerklärung" sauber, Zurück-Pfeil links, ohne Abschneidung. AXXXL: Texte umbrechen, Sheet scrollbar, "Zeitkritisch"-Zeile am unteren Rand angeschnitten (Scrollen nötig). Keine Berührung der Island. Test-Hinweis: XCUITest-Wischen zum Löschen der Zeile funktionierte nicht automatisch.
- Fazit Hochformat innen: Keine Defekte, die Island liegt oben im 82-pt-Safe-Area-Streifen. Die Vorschläge in Abschnitt 6 (Kartenbreite begrenzen) sind im Hochformat weitgehend unnötig (Breite ca. 669 pt wie ein iPad/großes iPhone); sie betreffen vor allem das Querformat 951x669 pt.

**Halb geöffnet / Zwischenhaltung (3.11.2026 ca. 20:40 bis 20:55, Versuch, nicht beobachtet):**
- Auftrag: Nutzer klappt im Device Hub halb auf; Mess-App (`x.probe`) wurde alle ca. 20 s neu gestartet und gemessen (23 Messungen über ca. 9 Minuten, dazu `simctl io enumerate`).
- Ergebnis: Durchgehend unverändert Bounds **951x669 pt**, Scale 3,0, Safe Area oben 0, links 0, unten 34, rechts 84 pt, Size Classes regular x regular, Layoutfläche 867x635 pt; `enumerate` unverändert (Display 1: 1398x2034, Display 3: 2007x2853, beide "Landscape Left"). Screenshot Display 3 = 2853x2007 (volles Innendisplay, Mess-App, Island rechts); Display 1 (außen) war schwarz. Es trat also **kein** Zustand ein, der sich vom bekannten Voll-Quer-Zustand unterscheidet; ein "halb geöffnet"-Layout (z. B. Tabletop/Flex-Modus, geteilte Fläche) wurde nicht gemessen, daher keine Bewertung von Radar, Sheets, XL/AXXXL und keine Vorher/Nachher-Differenz.
- Mögliche Gründe (nicht belegt): Device Hub hat die Zwischenhaltung nicht an das Gerät weitergegeben, der Nutzer war noch nicht fertig, oder das Gerätemodell kennt keinen Zwischenzustand mit eigener Layoutfläche. Wiederholung nur mit Hinweis des Nutzers, wann die Haltung steht.
- Messskript: Scratchpad `measure.sh` (terminate, launch `x.probe`, letzte Zeile aus `<Container>/tmp/probe.txt`).

**Sichtbefund Außendisplay (Screenshots im Scratchpad, nicht im Repo):**
- Radar mit Zeitleiste, Header, Prognosekarte, Buttonleiste: Inhalt endet bei x = 382 pt (Safe Area); Karte läuft unter der Island durch. Uhrzeit/Netzsymbol der Island liegen im 84-pt-Streifen rechts, keine Überlappung mit Bedienelementen, nichts abgeschnitten. Zeitleiste sitzt im unteren Bereich, über dem 34-pt-Inset.
- Info-Sheet ("Über ShowerNow") und Prognose-Sheet: Sheet reicht bis zum rechten Rand, Inhalt und "Fertig" bleiben links der Safe Area; die Island liegt über dem leeren rechten Sheet-Rand. Kein Inhalt verdeckt.
- Dynamic Type XXL: Layout unverändert plausibel. AccessibilityXXXL: Ebenenwahl schrumpft auf Symbol (ohne Text "Regenradar"), Prognosekarte umbricht ("Prognose-details"), die Quellenzeile `radar-attribution` (RadarScreen.swift:69-75) wird dreizeilig und überdeckt Buttonleiste und Ortsmarker; Zeitleiste einspaltig und groß, aber bedienbar. Das ist eine allgemeine Schwäche bei größter Schrift (nicht Duo-spezifisch), hier aber auf dem schmalen 382-pt-Streifen deutlich sichtbar.

**Nicht geprüft (und warum):**
- Auf-/Zuklappen als Ablauf (Layout-Wechsel live, MapKit-Region und Zustand beim Fold-Resize): nur Endzustände gesehen; keine Fold-Steuerung per `simctl`, Bedienung nur manuell im Device Hub.
- Querformat außen: Orientierung per XCUITest wirkungslos; Außendisplay-Abschalten crasht SpringBoard (nicht wiederholt). (Innen-Hochformat inzwischen geprüft, siehe oben.)
- Layer-Menü (Menü-Tap im Screenshot nicht sichtbar), Prognose-Chart mit echten Daten (Backend lieferte "Prognose nicht verfügbar"/kein Regen).
- Split View / Mehrfenster, Live-Activity-Optik in der vertikalen Island, Widgets/StandBy: nicht geprüft.
- Die bestehenden UI-Tests nicht auf dem Duo ausgeführt; nur eine Tour-Methode `testDuoTour` in der Scratchpad-Kopie (Repo unverändert).

## 6. Vorschläge für Build 16 (nicht angewendet)

Stand der Belege: beide Displays gesehen. Nichts ist defekt oder überdeckt; die Vorschläge sind kosmetische Verbesserungen für das regular x regular Innendisplay (951x669 pt) und gelten gleichermaßen für iPad. Zeilen gelten für `Weather/Views/RadarScreen.swift` im Repo-HEAD (`c5201c4`).

1. **Karten und Zeitleiste auf großen Displays begrenzen (optional, Designentscheidung).** `header`, `forecastCard` und `statusMessage` (Zeile 84-92) liegen im Overlay-`VStack` (ab Zeile 83) mit `.padding(.horizontal, 16)` (Zeile 118) und sind innen ca. 850 pt breit; die Buttonleiste (HStack ab Zeile 93) muss rechts bleiben, daher nur die drei Karten begrenzen, nicht den ganzen VStack:
   `+    @Environment(\.horizontalSizeClass) private var hSize` (bei den anderen `@Environment`/`@State` oben im Struct)
   `-                header`
   `-                forecastCard`
   `-                if let message = statusMessage { ... }` (Zeilen 84-92)
   `+                VStack(spacing: 10) {`
   `+                    header`
   `+                    forecastCard`
   `+                    if let message = statusMessage { ...unverändert... }`
   `+                }`
   `+                .frame(maxWidth: hSize == .regular ? 560 : .infinity, alignment: .leading)`
   (die äußere `VStack(spacing: 10)` darf dafür nur noch den Wrapper und den `HStack` mit Buttonleiste enthalten; Wrapper mit `.frame(maxWidth: .infinity, alignment: .leading)` umgeben). Wirkung: Karten ca. 560 pt links, Buttonleiste rechts; auf iPhone (compact) unverändert. Erst entscheiden, wenn der Nutzer das Bild sieht (`duo-inner/tour/rb-*`-Aufnahmen im Scratchpad).
2. **Zeitleiste begrenzen (optional).** `safeAreaInset(edge: .bottom)` Zeile 121-127: statt voller Breite zentriert begrenzen:
   `             timeline`
   `+                .frame(maxWidth: hSize == .regular ? 720 : .infinity)`
   `+                .frame(maxWidth: .infinity)`
   `                 .padding(.horizontal, 12)`
   (Reihenfolge so, dass die Begrenzung vor dem Zentrieren steht; `onGeometryChange` bleibt für `mapBottomInset` an `timeline` unverändert.)
3. **Quellenzeile bei großer Schrift (belegt auf beiden Displays, allgemeines iPhone-Thema).** `Text(line)` Zeile 69-75: Zeile begrenzen, damit sie bei AccessibilityXXXL nicht über Buttonleiste und Marker läuft:
   `                         .multilineTextAlignment(.center)`
   `+                        .lineLimit(2)`
   `+                        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)`
   (Quellenangabe bleibt lesbar; Pflichtangabe darf nicht entfallen, daher kein `.hidden`.)
4. **Sheets: kein Eingriff.** Zentrierte Formularblätter (ca. 650 pt) auf dem Innendisplay sauber; `presentationDetents` bleiben (RadarScreen.swift, SitePageSheet.swift).
5. **Safe Area/Island: kein Eingriff.** Rechts 84 pt Inset wird von allen Overlays eingehalten (außen und innen); `ReservedRegion` wird nicht gebraucht, solange keine Leiste außerhalb der Safe Area geplant ist.
6. **Live Activity (`WeatherWidgets/LiveActivity/RainLiveActivity.swift:44`, `frame(maxWidth: 48)`)**, Widgets/StandBy: weiterhin ungesehen; Hinweis auf `isDynamicIslandLimitedInWidth`-Bug (sekundär).
7. `Configuration/Info.plist`: `UIRequiresFullScreen` nicht setzen (ist nicht gesetzt). Orientierungen bleiben; das Innendisplay ignoriert sie ohnehin.
8. **Test-Hinweise (nur Testcode, nicht geändert):** `app.buttons["forecast-details"]` ist auf dem Duo mehrdeutig, besser `app.buttons.matching(identifier:).firstMatch`; Sheets über "Fertig" statt `swipeDown` schließen; `app.frame` ist auf dem Innendisplay vertauscht (669x951), Elementframes sind Querformat.
9. Für die Build-16-Abnahme: Duo-Screenshots für App Store Connect (außen 1398x2034, innen 2007x2853; Pflicht ab April 2027) und `simctl io <udid> screenshot --display=<id>` mit `enumerate` ermitteln; Innen liefert 2853x2007 gedreht.
