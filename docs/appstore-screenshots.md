# App-Store-Screenshots (Neuaufnahme 9.11.2026, Stand Build 42)

**Dieser Abschnitt ersetzt die Dateiliste unten.** Alle Motive sind neu aufgenommen (origin/main `19ece2c`, Build 42, Debug-Simulator, ohne Signing, nur Deutsch). Die Abschnitte darunter (Stand 3.11., Build 15) bleiben als Historie, ihre Dateinamen und Motive (Hannover, Archivregen) sind überholt.

Ablage: `design/appstore-screenshots/<gerät>/<maße>/de/NN-<motiv>.png`. Alle PNG ohne Alphakanal, nativ aufgenommen (nicht skaliert), Maße mit `sips` geprüft.

| Gerät / Feld in Connect | Ordner | Maße | Dateien |
|---|---|---|---|
| iPhone 6,3" (Simulator "SN Shots iPhone Pro", iPhone 17 Pro) | `iphone/1206x2622/de/` | 1206x2622 | 01 bis 08 (Liste unten) |
| iPhone 6,9" (Simulator "SN Shots iPhone Max", 17 Pro Max) | `iphone/1320x2868/de/` | 1320x2868 | 01 bis 08 |
| iPad 13" (Simulator "SN Shots iPad 13", Pro 13" M5) | `ipad/2064x2752/de/` | 2064x2752 | 01-regenradar, 02-temperatur, 03-warnungen, 04-feuchte-wald, 05-regenradar-dunkel |
| Apple Watch Ultra (Simulator "SN Shots Watch Ultra") | `watch/422x514/de/` | 422x514 | 01-ortsliste, 02-ortsprognose |

iPhone-Motive: 01 Regenradar mit Regenband, Zeit-Pille (Vergangenheit, blau) und Farblinie; 02 Ortsdetails (Prognosekarte, Stand "vorerst kein messbarer Regen", siehe Einschränkungen); 03 Temperatur 2 m (Modell) mit Wertabfrage "Etwa 8 bis 9 °C (Modell)", Zeit-Pille in der Zukunft orange; 04 Amtliche Warnungen (Fixture, Ort Berlin, Stufe 3 und 1); 05 Relative Feuchte mit Waldebene und Wertabfrage; 06 Neue Region (Radius, Auslöser, Kartenvorschau); 07 Deine Orte mit Regionen; 08 Regenradar dunkel (einziges Dark-Motiv). Orte: Hamburg, München, Berlin (öffentliche Beispielorte, kein Standort).

## Englische Screenshots (9.11.2026, Paket L6)

Aufruf: `tools/screenshots.sh build`, dann `tools/screenshots.sh iphone-pro|iphone-max|ipad en` (Standard bleibt `de`). Das Skript startet die App mit `-AppleLanguages (en) -AppleLocale en_US` (12-h-Zeit), legt Hamburg, Munich (statt München) und Berlin an und schreibt nach `<geraet>/<maße>/en/`. Das UI-Test-Bundle `ShotsUITests` wählt die Beschriftungen per `SHOT_LANG`.

| Ordner | Motive | Stand |
|---|---|---|
| `iphone/1206x2622/en/` | 01 Regenradar, 02 Ortsdetails, 03 Temperatur, 04 Warnungen, 05 Feuchte+Wald, 06 Region, 07 Orte/Regionen, 08 Regenradar dunkel | eingecheckt (11 MB), ohne Alpha |
| `ipad/2064x2752/en/` | 01 Regenradar, 03 Temperatur, 04 Warnungen, 05 Feuchte+Wald, 08 Regenradar dunkel (Auswahl wie de) | eingecheckt (14 MB) |
| `watch/422x514/en/` | 02-ortsprognose | eingecheckt; Ortsliste en nicht aufgenommen (App öffnet zuletzt gewählten Ort) |
| `iphone/1320x2868/en/` | gleiche 8 Motive | aufgenommen und geprüft, nicht eingecheckt (12 MB, Repo-Größe); per Skript neu erzeugbar |

Watch: `WatchShotsUITests` nimmt `SHOT_LANG=en`; Orte (Hamburg, Munich, Berlin) per `places.json` in den Watch-Container, Aufnahme per `simctl io`, Alpha mit `strip-alpha.swift` entfernt. Duo-Bilder: nicht erzeugt (Simulator nicht verfügbar).

Einschränkungen: Das Regenband des Archivs (`SHOT_RAIN_POS` 0.84) liegt wetterabhängig nicht mehr im Bild, das Radarmotiv zeigt aktuell keinen Regen (bei echtem Regen oder passender Position neu aufnehmen). Die Warnungen-Fixture zeigt den DWD-Text deutsch, Oberfläche und Quellenvermerk englisch. Die iPad-Statusleiste zeigt Datum/Wochentag in der Simulator-Systemsprache ("Montag 9. Nov."). Zeit-Pille und Wertabfrage nutzen Locale-Formate (4:32 PM, "About 2 to 3 °C (model)").

## Reproduktion

```sh
export DEVELOPER_DIR=/Users/linolaske/Downloads/Xcode.app    # Xcode 27.1
tools/screenshots.sh build                                    # App bauen (Debug, Simulator, ohne Signing)
tools/screenshots.sh iphone-pro | iphone-max | ipad           # Simulator zurücksetzen, Orte anlegen, alle Motive aufnehmen, nach design/appstore-screenshots/ kopieren
```

- Statusleiste: `simctl status_bar override --time 9:41 --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3` (nur iPhone/iPad). Der Watch-Simulator lässt die Zeit nicht überschreiben; die Watch-Bilder zeigen die echte Uhrzeit (07:25/07:28).
- UI-Test-Bundle: `design/appstore-screenshots/tools/ShotsUITests.swift` (Test `testScene`, Szenen radar, details, temp, humidity, warnings, regionnew; Umgebung `TEST_RUNNER_SHOT_*`). Das Skript ändert keinen Produktcode.
- Regenradar: Live-Daten des Showers-Servers mit `-radarPastHours 48`; Position `SHOT_RAIN_POS` (Standard 0.84) wählt ein Archivbild mit Regen. Ob und wo Regen liegt, hängt vom Aufnahmetag ab; vor jeder Neuaufnahme mit `testSweep` prüfen. Die Server-Bilder sind echte DWD-Daten (Archiv), keine erfundenen Werte.
- Warnungen: Debug-Stub `-UITestWarnings fixture` (Beispielwarnungen, Ort muss "Berlin" heißen). Die Texte sind Testdaten, in den Bildern aber nicht als solche gekennzeichnet.
- Watch: `xcodebuild -scheme WeatherWatch` für den Watch-Simulator bauen und installieren, die iPhone-App auf dem gekoppelten "SN Shots iPhone Max" starten (Orte werden per WatchConnectivity synchronisiert), dann `WatchShotsUITests` (`design/appstore-screenshots/tools/project-watch.yml`) halten und per `xcrun simctl io <watch> screenshot` aufnehmen. Alphakanal danach mit `tools/strip-alpha.swift` entfernen.

## Einschränkungen (ehrlich)

- **Nur Deutsch.** Die englische Oberfläche ist nicht vollständig lokalisiert (Radar-Screen, Sheets, Warnungen, Accessibility-Beschriftungen stehen im Code deutsch; `Localizable.strings` hat je 144 Zeilen). Beim Test mit `-AppleLanguages "(en)"` blieben Menüs, Banner und Ebenenname deutsch, nur Kartenbeschriftung und Zeitformat wechselten. Englische Store-Screenshots wären gemischtsprachig und wurden nicht erzeugt (Lücke für Entwicklung, nicht für Screenshots).
- **Keine Widget-/Live-Activity-Motive.** Beides lässt sich per `simctl`/UI-Test nicht ohne Weiteres platzieren (Widget-Galerie nur per Geste, Live Activity braucht Push-Registrierung und Server-Abo; die Simulator-Installation hat keine APNs-Anbindung, ein echtes Abo auf dem Produktionsserver wurde bewusst nicht angelegt). Der Live-Activity-Schalter erscheint nur bei einer bestehenden Region und ist deshalb nicht abgebildet. Stattdessen: 06 Neue Region und 07 Orte/Regionen.
- **Ortsdetails (02) zeigt "Vorerst kein messbarer Regen"**: zum Aufnahmezeitpunkt war in Hamburg, München, Leipzig, Kiel und Bremerhaven keine Regenprognose vorhanden. Das Bild ist echt, aber wenig aussagekräftig; bei Regenlage am Aufnahmetag neu aufnehmen (`SHOT_PLACE`).
- **Temperatur/Feuchte ohne geöffnete Legende:** Das Legendenpanel (Skala plus Hinweistexte, Wald-Schalter) läuft auf iPhone 17 Pro und Pro Max (Simulator iOS 27.0) mit seinem Text unten aus dem Glaspanel heraus und überlagert Zeit-Pille und Quellzeile. Das ist ein App-Layoutfehler (nicht behoben, nicht Teil dieses Auftrags), deshalb zeigen 03 und 05 stattdessen die Wertabfrage; die Skala ist dadurch nicht sichtbar. Die Feuchte-Ebene des Live-Servers bietet nur "Feuchte (relativ)", kein Taupunkt-Eintrag.
- Das Warnungen-Sheet (04) füllt auf dem iPhone nicht die ganze Höhe (Sheet-Höhe nach Inhalt); auf dem iPad ist es ein kleines Fenster. Auf dem iPad sind Ortsdetails, Region und Orte wegen kleiner Sheets nicht verwendet.
- Zeitleistenfarbe: Zeit-Pille ist bei Messung grau/blau, in der Zukunft orange; 01 zeigt Vergangenheit (Messung), 03 und 05 Zukunft.
- Nicht hochgeladen, keine Connect-Aktion; Upload macht der Nutzer.

## iPhone Duo

Pflichtmaße (Quelle: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications, abgerufen 9.11.2026; Details in `docs/research/iphone-duo.md`): Außendisplay 1398x2034 (hoch) / 2034x1398 (quer), Innendisplay 2007x2853 (hoch) / 2853x2007 (quer). Pflicht ab April 2027 für Apps, die mit dem iOS-27.1-SDK oder neuer gebaut werden; Showers baut mit dem Simulator-SDK 27.1 (Xcode 27.1, `iphonesimulator27.1`), Deployment Target 27.0, die Pflicht gilt also voraussichtlich.

**Keine Duo-Screenshots erzeugt (9.11.2026):** `xcrun simctl list devicetypes` listet "iPhone Duo" (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`), es existieren vier Geräte (drei "iPhone Duo", ein "ShowerNow Duo") auf der Runtime iOS 27.1 (24A94232). Der Start scheitert mit "The iOS 27.1 simulator runtime is not available. runtime path not found" (Xcode 27.1 und 27.2, Disk-Image als "Ready" gelistet); ein neues Duo-Gerät auf iOS 27.0 ist "Incompatible device". Es wurden bewusst keine skalierten Bilder erzeugt. Nächster Schritt: iOS-27.1-Simulator-Runtime in Xcode neu laden/reparieren, dann Außen- und Innendisplay aufnehmen und die Layoutprüfung nachholen (Prüfpunkte in `docs/research/iphone-duo.md`).

---

## Historie (Stand 3.11.2026, überholt)

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

**Erzeugt (alle echte Screenshots + Icon, Skript `tools/creative.swift`):** `creative/header-21x9.png` (3840x1646), `creative/suche-3x2.png` (3000x2000), `creative/universal-16x9.png` (5244x2950, PNG, kann Header und Suche zugleich) - alle RGB ohne Alphakanal, mit `sips` geprüft; Inhalt in mittiger 3:2-Zone (Sicherheitsabstand geschätzt, Apple-Vorlage nicht eingesehen). Text: "Showers / Regenradar mit Zeitleiste / Regen im Blick, für deine Orte". Mockup `preview/mockup-suche-und-header.png` (schematisch, kein Apple-Original, `tools/mockup.swift`).

**App-Vorschau (886x1920, für die Suche, falls kein Creative-Asset):** `preview/showers-app-preview-de-886x1920.mp4`: H.264 High L4.0, 886x1920, 30 fps, 17,97 s, ca. 8,4 Mbit/s (Ziel laut Apple 10 bis 12 Mbit/s; VBR darunter), AAC-Stereo 48 kHz (Stille, stumm gedacht), 19 MB. Inhalt: Radar-Zeitleiste von 06:10 bis 15:35 am 2.11. (Archivregen, Banner "kein Regen" widerspricht wie bei den Screenshots), Aufnahme per `simctl io recordVideo` auf iPhone 17 Pro (1206x2622), UI-Test `testPreviewTour` (`tools/ShotsUITests.swift`, Regler langsam ziehen), per ffmpeg skaliert/zugeschnitten und 4x verlangsamt (Mischbilder), je 1 s bzw. 1,5 s Standbild vorn/hinten. Stichprobenframes angesehen. Poster-Frame: `preview/poster-frame-5s.png` (Bild bei 5 s = Connect-Standard, Regenband über Hannover um ca. 08:40), in Connect auswählbar. Das Video ist nicht für die Header-/Suchformate (21:9, 3:2) zugeschnitten.

**Reihenfolge der ersten Screenshots (Suche, Hochformat):** 01 Regenradar, 02 Orte, 03 Wolken (Dunkelvarianten danach), unverändert.

**Textvorschläge (Stand 4.11.2026, Name "Showers", Build 17; nur Vorschlag, Nutzer trägt selbst ein; keine Live Activity, da Backend-Rollout aussteht; Längen mit `wc -m`/`wc -c`):**
- Untertitel (max. 30 Zeichen): `Regenradar mit Zeitleiste` (25 Zeichen) oder `Regen im Blick, für deine Orte` (30 Zeichen, 31 Bytes).
- Werbetext (max. 170 Zeichen): `Sieh im Regenradar, wann es regnet: Zeitleiste, Prognose für deine Orte und Regionen, Regenhinweis per Push, Widgets und Apple Watch. Daten vom DWD.` (148 Zeichen). Hinweis: Push hängt vom Backend ab, Watch-Radarkarte ist Vorschau; Wortlaut bei Bedarf entschärfen.
- Schlüsselwörter (max. 100 Bytes, kein Leerzeichen nach Komma, ohne "Showers"): `Niederschlag,Prognose,Wetter,Schauer,Regenhinweis,Regenvorhersage,Widget,Wolken,Satellit,Radarkarte` (99 Zeichen = 99 Bytes). Untertitelwörter (Regenradar, Zeitleiste) nicht wiederholt.
- Beschreibung, Kopf: `Showers zeigt dir, wann und wo es regnet. Das Regenradar mit Zeitleiste zeigt Messung und kurzfristige Entwicklung auf der Karte; Wolken sind als Satellitenebene zuschaltbar. Speichere Orte und Regionen für die Ortsprognose, lass dir per Push einen Regenhinweis senden und behalte den Regen mit Widgets und der Apple Watch (Radarkarte als Vorschau) im Blick. Datenquelle ist der Deutsche Wetterdienst.`

**Nicht geprüft:** Upload der Creative-Assets/des Videos in Connect, Preview-Tool, Safe Area gegen Apple-Vorlage, Review-Annahme; ob Creative-Assets in Connect für diese App schon sichtbar sind (iOS-27-Mindestversion, Build-Zuordnung unklar); Videoqualität auf dem Gerät; Mockup ist nicht Apples Darstellung. Hinweis: PNG/MP4 (zus. ca. 60 MB) nicht committen ohne Entscheidung.

## Umbenennung ShowerNow -> Showers (4.11.2026)

Prüfung aller Dateien per Vision-Texterkennung (Skript nur lokal) und Sichtprüfung; Neuaufnahme mit Build 17 (Debug, Simulator, gleiche Abläufe wie unten, Orte Hannover/Hamburg/München, 9:41). Der alte Name stand in der Quellenzeile der Karte ("Showers-Cache" statt "ShowerNow-Cache"), im iPad-Titel und im Watch-Titel sowie in allen Creatives.

| Datei(en) | Alter Name sichtbar | Maßnahme |
|---|---|---|
| iphone/1206x2622 und 1320x2868: `de` und `de-kopfzeile` 01-regenradar, 03-wolken, 04-regenradar-dunkel | ja (Quellenzeile) | neu |
| iphone/1206x2622 und 1320x2868: 02-orte, 05-orte-dunkel, 07-ortsprognose (nur 1320) | nein | unverändert |
| ipad/2064x2752 `de` und `de-kopfzeile` 01 bis 04 | ja (Titelleiste, Quellenzeile) | neu (Orte nur Titelleiste) |
| watch/422x514/de/01-ortsliste | ja (Titel) | neu |
| watch/422x514/de/02-ortsprognose | nein | unverändert |
| creative/header-21x9, suche-3x2, universal-16x9, preview/mockup-suche-und-header | ja ("ShowerNow") | neu (`tools/creative.swift`, `tools/mockup.swift`, Icon `tools/assets/AppIcon-1024.png`) |
| preview/showers-app-preview-de-886x1920.mp4, poster-frame-5s.png | ja (Quellenzeile) | neu (13,57 s, 886x1920, H.264 High, 30 fps, 10 MB; Zeitleiste 08:40 bis 14:05 am 2.11.; Aufnahme per `simctl io recordVideo`, ffmpeg: Ausschnitt 4x verlangsamt, 1 s/1,5 s Standbild vorn/hinten) |

Regen: Am 3.11.2026 abends lag in Deutschland laut `latest.json` kein Regen vor (nur Einzelpixel); Radarmotive zeigen weiter den Archivregen vom 2.11. (Zeitleiste "Mo. 2. Nov."; Banner "Vorerst kein messbarer Regen" passt nicht zum Bild). Alle neuen Dateien RGB ohne Alphakanal, Maße mit `sips` geprüft. Hinweis Reproduktion: Das Derived-Data-Verzeichnis des UI-Test-Bundles darf kein altes `Weather.app` enthalten (der Test installierte sonst Build 15); frisch anlegen oder vorher löschen.

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
- **Info-Sheet** nicht verwendet: Der Text beginnt mit "Showers · frühe Testversion" (Produktentscheidung vor Store-Einsatz).
- **Englisch (9.11.2026, Paket L6):** erzeugt, siehe Abschnitt "Englische Screenshots".
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

## Icon-Aktualisierung (4.11.2026)

Anlass: Die Store-Creatives zeigten noch das alte Icon (Build-15-Karte). Standard-Icon der App ist seit Build 16 d2 (`Weather/Resources/Icon/AppIcon.icon`).

| Datei | Icon sichtbar | Maßnahme |
|---|---|---|
| creative/header-21x9 (3840x1646), suche-3x2 (3000x2000), universal-16x9 (5244x2950) | ja | neu mit neuem Icon (RGB, ohne Alpha, `sips` geprüft) |
| preview/mockup-suche-und-header (2400x1500) | ja (zweimal) | neu |
| iphone/*, ipad/*, watch/* Screenshots (de, de-kopfzeile) | nein (Karte, Orte-Sheet, Wolken; Info-Sheet nicht abgebildet) | unverändert |
| preview/poster-frame-5s.png, App-Vorschau-Video (Kartenansicht) | nein (Poster per Sichtprüfung; Video zeigt nur Kartenansicht laut Ablauf, Stichproben nicht erneut gesehen) | unverändert, keine Neuaufnahme nötig |

Icon-Quelle: `tools/assets/AppIcon-1024.png` (ictool, Rendition Default, 1024 px, mit Alpha-Rundung; Befehl: `ictool Weather/Resources/Icon/AppIcon.icon --export-image --output-file ... --platform iOS --rendition Default --width 1024 --height 1024 --scale 1`). `creative.swift`/`mockup.swift` zeichnen das Icon jetzt ohne eigenen Rundungs-Clip und ohne schwarzen Unterbau (sonst dunkler Rand). Eingaben der Creatives: `iphone/1320x2868/de/01-regenradar.png` und `02-orte.png`.

Store-Icon der App-Seite in Connect (1024): kommt aus dem hochgeladenen Build, nicht aus Dateien hier. Build 16 und 17 enthalten laut `testflight-upload.md` `AppIcon.icon` (d2, Build 16: "Icon d2"; `Assets.car` in App und Watch-App vorhanden). Nicht einzeln geprüft: ob das Icon im Connect-Build 17 tatsächlich d2 darstellt (Anzeige erst nach Verarbeitung sichtbar). Der Nutzer muss in Connect die drei neuen Creatives (Header, Suche, universal) hochladen bzw. ersetzen; Screenshots und Video bleiben.

## Icon-Aktualisierung 2 (6.11.2026, neues Standard-Icon V4B Sektor 90° mit Verlauf)

Standard-Icon ist jetzt `Weather/Resources/Icon/AppIcon.icon` (Radar-Ringe mit Sektor und Wolke, Nutzerfassung). `tools/assets/AppIcon-1024.png` neu per ictool aus diesem Paket gerendert (Rendition Default, 1024 px, Alpha-Rundung; Befehl wie oben). Neu erzeugt mit unveränderten Skripten (`creative.swift`, `mockup.swift`; Texte "Showers" / "Regenradar mit Zeitleiste" / "Regen im Blick, für deine Orte"): `creative/header-21x9` (3840x1646), `suche-3x2` (3000x2000), `universal-16x9` (5244x2950), `preview/mockup-suche-und-header` (2400x1500); alle RGB ohne Alpha (`sips`), Stichproben (Suche, Mockup, universal) angesehen. Unverändert: alle Screenshots (iphone/ipad/watch: Karte, Orte, Wolken, Prognose zeigen das Icon nicht; Wiedererkennung per Sicht, keine Texterkennung), `poster-frame-5s.png` und App-Vorschau-Video (nur Kartenansicht, nicht erneut gesehen). Hinweis: Die Quellenzeile der Karte in den Creatives zeigt weiter "Showers-Cache" (Build-17-Aufnahme). Nicht geprüft: Upload in Connect; Creatives dort ersetzen. PNGs weiter nicht committet.
