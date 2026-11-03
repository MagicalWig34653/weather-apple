# App-Store-Screenshots (Stand 3.11.2026)

Erzeugt aus Build-15-Quellstand (Debug, Simulator, ohne Signing). Ablage: `design/appstore-screenshots/<plattform>/<maße>/<sprache>/NN-<motiv>.png` (Reihenfolge: 01 Radar, 02 Orte, 03 Wolken, 04 Radar dunkel, 05 Orte dunkel; iPhone 1206x2622 ebenfalls neu aufgenommen); Hilfsdateien in `design/appstore-screenshots/tools/`. Rohbilder nicht nachbearbeitet (außer Entfernen des Alphakanals bei Watch); Kopfzeilen-Varianten separat; alle Bilder sind echte App-Ausgaben mit Live-Daten.

## Warum 1320x2868 abgelehnt wurde und welche Datei wohin gehört

Ursache (belegt): Die Dateien waren formal gültig (PNG, RGB, kein Alphakanal), aber 6,9"-Maße. Das Feld "6,1"- oder 6,3"-iPhone-Displays" akzeptiert laut Anzeige in App Store Connect nur 1179x2556, 2556x1179, 1206x2622, 2622x1206 (Meldung des Nutzers, 3.11.2026). Die Apple-Seite führt 1320x2868 (auch 1260x2736, 1290x2796) unter "Dynamic Island (large display)", ein eigenes Größenfeld. Hinweis: Welches Feld die Oberfläche anbietet, ist durch die Apple-Seite (Labels, keine Zollangaben) nicht eindeutig belegt; die Zuordnung 6,9" = Dynamic Island large ist Schluss aus den Maßen.

Quellen (abgerufen 3.11.2026): [Screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications), [Asset best practices](https://developer.apple.com/app-store/asset-best-practices/).

Spezifikation (Auszug): 1 bis 10 Screenshots je Größe, PNG/JPEG, "can't include alpha channels or transparencies"; Farbraum nicht angegeben (verwendet: sRGB/Display P3 aus Simulator). Pflicht: mindestens ein Screenshot für iPhone mit Dynamic Island (medium) = 1179x2556 oder 1206x2622; iPad 13" (2064x2752 oder 2048x2732) falls iPad-App; Watch (gleiche Größe über alle Sprachen). 6,9" (Dynamic Island large) ist nicht Pflicht; fehlt es, ist Face ID large (1284x2778/1242x2688) Pflicht. Fehlende Größen werden aus Nachbargrößen herunterskaliert, wenn die UI konsistent ist.

| Feld in App Store Connect | Ordner / Dateien | Maße | Alpha | Geprüft (sips) |
|---|---|---|---|---|
| iPhone 6,1"/6,3" (Pflicht) | `iphone/1206x2622/de/` 01-regenradar, 02-orte, 03-wolken, 04-regenradar-dunkel, 05-orte-dunkel; Kopfzeilen: `iphone/1206x2622/de-kopfzeile/` (gleiche Namen) | 1206x2622 | nein | ja |
| iPhone 6,9" (optional, separates Feld) | `iphone/1320x2868/de/` (+ 07-ortsprognose) und `de-kopfzeile/` | 1320x2868 | nein | ja |
| iPad 13" | `ipad/2064x2752/de/` 01-regenradar, 02-orte, 03-wolken, 04-regenradar-dunkel; `de-kopfzeile/` | 2064x2752 | nein | ja |
| Apple Watch Ultra 3/4 | `watch/422x514/de/` 01-ortsliste, 02-ortsprognose | 422x514 | nein | ja (Upload nicht getestet) |
| Mac | keine (kein natives Mac-Ziel) | - | - | - |

Alle Dateien nur per Maßprüfung (`sips -g pixelWidth -g pixelHeight -g hasAlpha`) kontrolliert; der Upload selbst wurde nicht ausgeführt. 1179x2556 (iPhone 16/15) wurde nicht erzeugt: 1206x2622 deckt dasselbe Feld ab.

Aufnahmen: iPhone 17 Pro (1206x2622) und 17 Pro Max (1320x2868), iOS 27.0 Simulator, nativ aufgenommen, nicht skaliert; iPad Pro 13" M5 2064x2752; Watch Ultra 4 422x514.

## Kopfzeilen-Varianten (Ordner `de-kopfzeile`)

Kurze Überschrift plus Untertitel über dem unverzerrten Screenshot (Apple: "short phrase that enhances your visual rather than describes it"). Skript `tools/headline.swift` (CoreGraphics/AppKit, Systemschrift SF, lokal, Ausgabe exakt in Zielmaß, RGB ohne Alpha). Texte nur zu dem, was das Bild zeigt:

| Datei | Kopfzeile / Untertitel |
|---|---|
| 01-regenradar | Regen im Blick / Radar mit Zeitleiste |
| 02-orte | Deine Orte / Orte und Regionen speichern |
| 03-wolken | Wolken im Blick / Satellitenbild als Ebene |
| 04-regenradar-dunkel | Dunkelmodus / Regenradar bei Nacht |
| 05-orte-dunkel | Deine Orte / Im Dunkelmodus |

Reproduktion: `swiftc -O design/appstore-screenshots/tools/headline.swift -o headline; ./headline <roh.png> <aus.png> <breite> <hoehe> "Kopfzeile" "Untertitel" [light|dark]`. Watch: keine Kopfzeilen (422x514 zu klein, Text würde unleserlich). Nicht erstellt: Kopfzeilen zu Widgets/Live Activity/Watch (Bilder fehlen).

Qualität: Radar, Orte und Dunkel-Radar gut lesbar (Kopfzeile auch klein erkennbar); Wolken (Nachtbild, wenig Kontrast) nur brauchbar; Radar-Motive tragen ein Banner "Vorerst kein messbarer Regen erwartet" und Archivdatum "Mo. 2. Nov." (siehe unten). Eine Neuaufnahme bei echtem aktuellem Regen (und tagsüber für Wolken/Sonne) wäre sinnvoll, vor allem damit Banner und Radarbild zusammenpassen.

## Hinweise zu Suchergebnissen (nur aus der Best-Practices-Seite)

- Bis zu 3 Screenshots (je nach Ausrichtung) und bis zu 3 App-Vorschauen erscheinen in Suchergebnissen: die ersten drei Motive sind entscheidend. Empfohlene Reihenfolge: 1 Regenradar, 2 Orte, 3 Wolken (Dunkel-Varianten danach).
- Zweck der App auf einen Blick klar machen; Text kurz, lokalisiert; lesbar auch verkleinert, Kernelement mittig (Sicherheitsbereich). Keine Preise, URLs, Auszeichnungen.
- Hochformat ist für iPhone der Normalfall (hier alles Hochformat); eine App-Vorschau (Video, Ton aus gedacht, starker Einstieg) ist optional und nicht erzeugt (Feld nach Nutzeranzeige: 886x1920 / 1920x886).
- Ob ein eigenes "Suchergebnis-Creative" existiert, nennt die Seite; Fallback: Screenshots/Vorschauen erscheinen. Nicht geprüft: die Vorschau in App Store Connect ("Preview tool").

## Product-Page-Header und Suchergebnisse (3.11.2026)

Quellen (abgerufen 3.11.2026): [Asset best practices](https://developer.apple.com/app-store/asset-best-practices/), [Creative assets specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/creative-assets-specifications), [App preview specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications), [Manage your App Store assets](https://developer.apple.com/help/app-store-connect/manage-app-information/manage-your-app-store-assets), [App information](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), [Platform version information](https://developer.apple.com/help/app-store-connect/reference/app-information/platform-version-information). Korrektur zum Abschnitt "Hinweise zu Suchergebnissen" oben: Es gibt eigene Bild-/Video-Assets für beide Bereiche ("creative assets"), nicht nur Screenshots.

**Was Apple sagt (wörtlich bzw. nahe am Wortlaut):**
- Header: "When someone lands on your product page, the first thing they'll notice is your header. Use video or images to express your brand, seasonal offerings, exciting new content, and more."
- Suche: "Your search result asset is the first thing people experience when they find your app or game through the Search tab". Ohne dieses Asset: "If you choose to not use a search result creative asset, your In-App Events, app previews, and screenshots will appear." Bis zu drei Screenshots (je nach Ausrichtung) und bis zu drei App-Vorschauen erscheinen in der Suche.
- Creative assets sind optional, getrennt von Screenshots/App-Vorschauen, "available for iOS and iPadOS apps and games running iOS 27 or iPadOS 27 or later" (Manage-Seite). Hochladen in App Store Connect über Asset Library (eigene Einreichung, Review gegen die letzte App-Version, ohne neue App-Version); Zuordnung unter Product Page Information > Tab "Header and Search Results". Ein "universal creative asset" kann für Header und Suche zugleich dienen, sonst je ein eigenes Asset.
- Safe Area: "keeping key aspects of your art within the safe area defined in each template" (Figma/Photoshop/Pixelmator/Sketch-Vorlagen; die Vorlagen waren per Skript nicht abrufbar, Safe Area daher nicht eingesehen). Text kurz, lokalisiert; "Preview tool in App Store Connect"; Videos: Poster-Frame wählen, nahtlos loopen, stumm gedacht.

**Maße (Creative-assets-Seite):** Bilder ohne Alphakanal. Header: 21:9 = 3840x1646 (jpg/png) oder 16:9 = 5244x2950 (png). Suche: 3:2 = 1920x1280 bis 3840x2560 (jpg/png) oder 16:9 = 5244x2950 (png). Video Header 21:9 3840x1646, Suche 3:2 1920x1280 bis 3840x2560, jeweils 30 oder 60 fps, 5 bis 30 s, .mov/.m4v/.mp4, stumm, Endlosschleife. Wie viele Assets je Bereich und ob je Sprache, nennen die Seiten nicht.

**Was der Nutzer selbst einträgt:** Name (2 bis 30 Zeichen), Untertitel (höchstens 30 Zeichen), Werbetext (höchstens 170 Zeichen), Schlüsselwörter (höchstens 100 Bytes), Beschreibung (4000 Zeichen); App-Icon kommt aus dem Build. Icon, Name und Untertitel erscheinen im Suchergebnis und im Header-Bereich neben/unter dem Asset (Aufbau laut Apple-Seite nicht im Detail beschrieben).

**Erzeugt (alle echte Screenshots + Icon, Skript `tools/creative.swift`):** `creative/header-21x9.png` (3840x1646), `creative/suche-3x2.png` (3000x2000), `creative/universal-16x9.png` (5244x2950, PNG, kann Header und Suche zugleich) - alle RGB ohne Alphakanal, mit `sips` geprüft; Inhalt in mittiger 3:2-Zone (Sicherheitsabstand geschätzt, Apple-Vorlage nicht eingesehen). Text: "ShowerNow / Regenradar mit Zeitleiste / Regen im Blick, für deine Orte". Mockup `preview/mockup-suche-und-header.png` (schematisch, kein Apple-Original, `tools/mockup.swift`).

**App-Vorschau (886x1920, für die Suche, falls kein Creative-Asset):** `preview/showernow-app-preview-de-886x1920.mp4`: H.264 High L4.0, 886x1920, 30 fps, 17,97 s, ca. 8,4 Mbit/s (Ziel laut Apple 10 bis 12 Mbit/s; VBR darunter), AAC-Stereo 48 kHz (Stille, stumm gedacht), 19 MB. Inhalt: Radar-Zeitleiste von 06:10 bis 15:35 am 2.11. (Archivregen, Banner "kein Regen" widerspricht wie bei den Screenshots), Aufnahme per `simctl io recordVideo` auf iPhone 17 Pro (1206x2622), UI-Test `testPreviewTour` (`tools/ShotsUITests.swift`, Regler langsam ziehen), per ffmpeg skaliert/zugeschnitten und 4x verlangsamt (Mischbilder), je 1 s bzw. 1,5 s Standbild vorn/hinten. Stichprobenframes angesehen. Poster-Frame: `preview/poster-frame-5s.png` (Bild bei 5 s = Connect-Standard, Regenband über Hannover um ca. 08:40), in Connect auswählbar. Das Video ist nicht für die Header-/Suchformate (21:9, 3:2) zugeschnitten.

**Reihenfolge der ersten Screenshots (Suche, Hochformat):** 01 Regenradar, 02 Orte, 03 Wolken (Dunkelvarianten danach), unverändert.

**Textvorschläge (nur Vorschlag; Nutzer trägt sie selbst ein; nur Funktionen aus Build 15, keine Live Activity, keine Duo-Optimierung):**
- Untertitel (30): `Regenradar mit Zeitleiste` (25) oder `Regen im Blick, für deine Orte` (30).
- Werbetext (170): `Sieh im Regenradar, wann der Regen kommt: mit Zeitleiste, Prognose für deine Orte, Regenhinweis per Push, Widgets und Apple Watch.` (130)
- Schlüsselwörter (100 Bytes, ohne Leerzeichen nach Komma): `Niederschlag,Prognose,Wetter,Schauer,Regenhinweis,Regenvorhersage,Widget,Gewitter,Wolken,Satellit` (97). Name und Untertitelwörter nicht wiederholen. Offen: "Gewitter" nur, wenn die Blitz-Ebene verfügbar bleibt.
- Beschreibung, Kopf: `ShowerNow zeigt dir, wann und wo es regnet. Das Regenradar mit Zeitleiste zeigt Messung und kurzfristige Entwicklung auf der Karte; Wolken sind als Satellitenebene zuschaltbar. Speichere Orte und Regionen für die Ortsprognose, lass dir per Push einen Regenhinweis senden und behalte den Regen mit Widgets und der Apple Watch im Blick. Datenquelle ist der Deutsche Wetterdienst.` Vor Einreichung gegen den dann tatsächlichen Funktionsumfang prüfen (Watch/Widgets erst nach Gerätetest bewerben).

**Nicht geprüft:** Upload der Creative-Assets/des Videos in Connect, Preview-Tool, Safe Area gegen Apple-Vorlage, Review-Annahme; ob Creative-Assets in Connect für diese App schon sichtbar sind (iOS-27-Mindestversion, Build-Zuordnung unklar); Videoqualität auf dem Gerät; Mockup ist nicht Apples Darstellung. Hinweis: PNG/MP4 (zus. ca. 60 MB) nicht committen ohne Entscheidung.

## Motive (alle Deutsch, Orte Hannover/Hamburg/München, Standort nie verwendet)

| Datei | Inhalt | Urteil |
|---|---|---|
| iphone/*/de/01-regenradar | Radar mit Regenband über Niedersachsen, Zeitleiste, Quelle | gut |
| iphone/*/de/03-wolken | Ebene Wolken (Satellit) | brauchbar (Nachtbild, wirkt dunkel) |
| iphone/1320x2868/de/07-ortsprognose | Ortsprognose-Sheet | schwach (aktuell trocken, leerer Graph) |
| iphone/*/de/02-orte | Orte-Sheet hell | gut |
| iphone/*/de/04-regenradar-dunkel | wie 01, Dark Mode | gut |
| iphone/*/de/05-orte-dunkel | Orte dunkel | gut |
| ipad/2064x2752/de/01-regenradar, 04-regenradar-dunkel | Radar hell/dunkel | gut |
| ipad/2064x2752/de/03-wolken | Wolken (Satellit, Nacht) | brauchbar |
| ipad/2064x2752/de/02-orte | Orte-Sheet | gut |
| watch/422x514/de/01-ortsliste, 02-ortsprognose | Ortsliste, Prognose (trocken, DWD-Stand) | ordentlich; Uhrzeit zeigt reale Zeit |

Bekannte Einschränkungen der Motive:
- **Regen aus dem Archiv:** Am 3.11.2026 abends war in Deutschland kein Regen. Radarbilder zeigen deshalb die gemessene Lage vom 2.11. (ca. 10-11 Uhr, über `history.json`, Einstellung "Maximale Vergangenheit" 48 Stunden). Die Zeitleiste zeigt das Datum "Mo. 2. Nov."; der Banner oben ("Vorerst kein messbarer Regen") bezieht sich auf jetzt und widerspricht dem Bild optisch. Vor Veröffentlichung besser bei echtem aktuellem Regen neu aufnehmen (gleiche Befehle) oder bewusst so lassen.
- **Ebene Sonne, Blitze, Luftdruck nicht aufgenommen:** abends bzw. Winterhalbjahr ist die Sonnenebene dunkel, keine Blitze, Luftdruck war "nicht aktuell" (Backend). Tagsüber und bei Gewitter neu aufnehmen (`testLayer`, `SHOT_LAYER=Sonne|Blitze`).
- **Info-Sheet** nicht verwendet: Der Text beginnt mit "ShowerNow · frühe Testversion" (Produktentscheidung vor Store-Einsatz).
- **Englisch nicht erzeugt:** Die iOS-Oberfläche ist (noch) nur deutsch, `Localizable.strings` gibt es nur für Push-Texte und die Watch. Englische Screenshots wären identisch deutsch.
- **Widgets/Komplikationen nicht aufgenommen:** Hinzufügen zu Home-/Zifferblatt im Simulator ist nicht sinnvoll automatisierbar.
- **Watch:** Die WCSession-Zustellung funktioniert im Simulator nicht (Watch-App per `simctl install` statt Companion-Installation, `isWatchAppInstalled` unwahr). Die Ortsliste wurde deshalb durch Kopieren der `places.json` der iPhone-App in den Watch-Container (Debug-Fallback `SharedFallback`) eingespielt; dasselbe Ortsformat wie von der Übertragung. Das Bild ist trotzdem echte App-Oberfläche.

## Mac

Nicht erzeugt, nicht erforderlich. Das Projekt hat nur die Plattformen iOS und watchOS (`LSRequiresIPhoneOS`, keine Mac-Plattform in `project.yml`). Xcode bietet für Scheme `Weather` nur das Ziel "My Mac (Designed for iPad/iPhone)"; ein natives Mac-Ziel scheitert ("macOS platform doesn't match Weather.app's supported platforms"). Eine iPhone/iPad-App auf dem Mac nutzt in App Store Connect die iPhone-/iPad-Screenshots; die Mac-Größen (16:10) gelten nur für native Mac-Apps. Ein Lauf als "Designed for iPad" würde einen signierten Build auf dem echten Mac erfordern (Simulator-Build läuft nicht) und wurde nicht ausgeführt. Falls später eine native Mac-App (Mac Catalyst/AppKit) kommt: 2880x1800 per `screencapture -l <windowid>`.

## Reproduktion

Voraussetzungen: Xcode 27.2, `xcodegen`, Laufzeiten iOS 27.0 und watchOS 27.2 (iOS 27.2 fehlt; Geräte "18 Pro" lassen sich daher nicht anlegen, 17 Pro Max reicht für 6,9"). Eigene Simulatoren mit Präfix "SN Shots" verwenden.

```sh
# Geräte (einmalig); iPad M5 (12GB) liefert 2064x2752
xcrun simctl create "SN Shots iPhone Max" com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro-Max com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl create "SN Shots iPad 13" com.apple.CoreSimulator.SimDeviceType.iPad-Pro-13-inch-M5-12GB com.apple.CoreSimulator.SimRuntime.iOS-27-0
xcrun simctl create "SN Shots Watch Ultra" com.apple.CoreSimulator.SimDeviceType.Apple-Watch-Ultra-4-49mm com.apple.CoreSimulator.SimRuntime.watchOS-27-2
# App bauen (Simulator, ohne Signing) und installieren
xcodebuild -scheme Weather -destination "generic/platform=iOS Simulator" -derivedDataPath <dd> CODE_SIGNING_ALLOWED=NO build
xcrun simctl boot <udid>; xcrun simctl status_bar <udid> override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl install <udid> <dd>/Build/Products/Debug-iphonesimulator/Weather.app
xcrun simctl spawn <udid> defaults write de.linolaske.showernow radarPastHours -int 48   # Archivregen, siehe Einschränkungen
# UI-Test-Bundle (nicht Teil von Weather.xcodeproj): tools/project.yml + tools/ShotsUITests.swift in ein Scratch-Verzeichnis kopieren, xcodegen generate
# Orte anlegen (je Stadt, Ortssuche + Lesezeichen): TEST_RUNNER_SHOT_CITY=Hannover tools/run-test.sh <udid> testAddPlace <dd2> <log>
# Motive: testRain (SHOT_POS=0.30 = Mo 2.11. ~09:15 bei 48 h), testLayer (SHOT_LAYER=Wolken, SHOT_POS=0.02), testPlaces, testSheets (Prognose)
#   Ausgabe nach TEST_RUNNER_SHOT_DIR, Name TEST_RUNNER_SHOT_NAME; Dark Mode: xcrun simctl ui <udid> appearance dark
# Watch: Orte nach <watch-container>/Library/Application Support/SharedFallback/places.json kopieren, Watch-App (Weather.app/Watch/WeatherWatch.app) installieren;
#   tools/project-watch.yml + WatchShotsUITests.swift öffnen den Ort; währenddessen xcrun simctl io <watch-udid> screenshot <datei>
swift design/appstore-screenshots/tools/strip-alpha.swift <png>   # nur falls Alphakanal vorhanden
```

Der Zeitregler-Wert `SHOT_POS` ist abhängig vom Zeitpunkt (Anteil an der 48-h-Spanne); Werte bei Neuaufnahme mit `testSweep` (`SHOT_POS=0.2,0.3,...`, Dateiname enthält den Zeitregler-Wert) prüfen.

## Empfehlung zur Ablage

26 MB PNG (Stand jetzt): nicht committen, sondern lokal belassen oder über Git LFS/außerhalb des Repos ablegen; die Skripte unter `tools/` und diese Datei genügen zur Reproduktion. Commit nur nach Entscheidung des Nutzers.

## Lücken / offen

- Mac: keine (siehe oben). Englisch: keine. Widgets, Komplikationen, Live Activity: keine.
- Regen aktuell statt Archiv; Sonne/Blitze/Luftdruck tagsüber/bei Gewitter.
- Duo gesondert (anderer Auftrag). Geräterahmen nicht erstellt.
