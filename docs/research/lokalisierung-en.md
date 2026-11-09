# Bestandsaufnahme: englische Lokalisierung (9.11.2026)

Auftrag: Nutzerentscheidung "App auf Englisch lokalisieren". Methode: nur Lesen (Repo-Stand `origin/main` d437499, Backend-Repo nur gelesen); gezählt per Skript (Regex über `Weather/`, `Shared/`, `WeatherWidgets/`, `WeatherWatch/`, `WeatherWatchWidgets/`, `WeatherNotificationService/`). Zahlen sind Näherungen (Suche nach Umlauten und deutschen Wortlisten, danach per Hand gesichtet); es wurde nichts gebaut oder ausgeführt. Umsetzungsplan: [../superpowers/plans/2026-11-09-lokalisierung-en-plan.md](../superpowers/plans/2026-11-09-lokalisierung-en-plan.md).

Kurzbefund: Die Infrastruktur für Englisch steht (en.lproj in allen vier Bundles, je vollständig gegenüber de). Die Lücke liegt im Code: Der Großteil der iOS-Oberfläche besteht aus deutschen Literalen ohne Schlüssel. Auf einem englischen Gerät bleibt sie deshalb deutsch; nur Warnungen, Temperatur-/Feuchte-Ebene, Geräte-Kopplung, Push-Texte, Widgets (teilweise) und Watch erscheinen englisch.

## 1. Ist-Zustand der Lokalisierung

| Aspekt | Befund (Fakt, aus Code/Projektdateien) |
|---|---|
| Sprachen | `de`, `en` (`project.yml`: `developmentLanguage: de`, `knownRegions: [de, en, Base]`; pbxproj `developmentRegion = de`). Entwicklungssprache Deutsch. |
| String-Dateien | Klassische `Localizable.strings`, **keine** String Catalogs (`.xcstrings`), **keine** `.stringsdict`. Je Bundle: `Weather/Resources/{de,en}.lproj` (136 Schlüssel), `WeatherWidgets/Resources/{de,en}.lproj` (36), `WeatherWatch/{de,en}.lproj` (37), `WeatherWatchWidgets/{de,en}.lproj` (28). Die Notification Service Extension hat keine eigene Datei und liest die Texte aus dem Host-Bundle. |
| `InfoPlist.strings` | **Keine.** `NSLocationWhenInUseUsageDescription` steht nur deutsch in `Configuration/Info.plist` ("Dein Standort zentriert die Karte ..."). Der Anzeigename ist `$(WEATHER_DISPLAY_NAME)` (Showers, sprachneutral). Widgets-/Watch-/NSE-Plists enthalten keine Nutzertexte. |
| `CFBundleDevelopmentRegion` / `CFBundleLocalizations` | In keiner Plist gesetzt; im gebauten `Weather.app/Info.plist` (Debug-Simulator) ebenfalls nicht vorhanden. Gesetzt sind nur `developmentRegion = de`/`knownRegions` im Projekt. Das Verhalten bei Systemsprachen außerhalb de/en (z. B. Französisch) ist nicht geprüft (Hypothese: Rückfall auf die Entwicklungsregion; ohne Schlüssel in der Plist unbelegt). |
| Zwei Schlüssel-Konventionen | (a) Weather-Target: symbolische Schlüssel `UPPER_SNAKE` (`WARN_*` 66, `TEMP_*` 20, `DEVICE_LINK_*` 18, `LAYER_*` 16, `INFO_*` 8, `PUSH_*` 4, `FOREST_*` 2, `RAIN_*` 2), im Code per `NSLocalizedString("KEY", value: "<deutsch>", comment:)` (30 verschiedene Schlüssel, 34 Aufrufe) oder `String(localized: "KEY")` (2). Alle 30 Schlüssel stehen in beiden Dateien. (b) Widgets: deutscher Text als Schlüssel (`"Regen in %lld Min." = "Rain in %lld min"`), Watch: englischer Text als Schlüssel über `NSLocalizedString(key, bundle: .main, value: key)` (`WatchText`, `WatchWidgetPresentation`). |
| SwiftUI-Literale | `Text("...")`, `Button("...")`, `Label`, `Toggle`, `Picker`, `Section`, `navigationTitle`, `TextField` mit deutschem Literal: ca. 190 Stellen (Text 89, Button 31, Label 28, Picker 10, Section 9, Toggle 7, navigationTitle 8, TextField 4). Sie werden als `LocalizedStringKey` mit dem deutschen Text als Schlüssel gesucht. Weil es keinen solchen Schlüssel in `en.lproj` gibt, bleibt der deutsche Text stehen. |
| Zusammengesetzte Strings | Viele deutsche Strings entstehen per Interpolation oder `String(format:)` (31 Stellen), z. B. `"Regen in \(m) Min."`, `"Stand vor \(minutes) Min."`, `"\($0) Minuten"`. Diese lassen sich nicht über Literal-Schlüssel lösen; sie brauchen Format-Schlüssel (`%@`, `%lld`, nummerierte Platzhalter). |
| Plural | Keine `.stringsdict`, keine Pluralvarianten. Handgeschrieben: `RadarPastWindow.label`: `hours == 1 ? "1 Stunde" : "\(hours) Stunden"`. Sonst weichen die Texte mit "Min." und Zahl aus ("Regen in 1 Min."). Englisch braucht nur eine/viele-Unterscheidung. |
| Datum/Zahl/Zeit | Meist formatbasiert und damit automatisch sprach-/regionsrichtig: `.formatted(date:time:)` (13), `Text(date, format:)`, `setLocalizedDateFormatFromTemplate`. Feste Ausnahmen: `TimelineAccessibility.value(... locale: Locale(identifier: "de_DE"))` (VoiceOver-Zeitleiste, Standardparameter), `TemperatureScale.number` ersetzt `.` durch `,` nur bei `languageCode == "de"` (Zahlformat von Hand, sonst Punkt), `SolarPosition` formatiert "HH:mm" mit `en_US_POSIX` (24 h erzwungen, davor deutsches "Sonne bis"), `SunMask.regionTimeZone = Europe/Berlin` (fachlich: Radargebiet Deutschland, bewusst). Einheiten sind als Text fest (`mm/h`, `°C`, `%`, "km", "Min."); keine `Measurement`-Formatierung. Dezimalkomma in den Legenden-Bändern (`RadarLegend`: "0,1 bis unter 0,2", "7,5 bis unter 10") ist festes deutsches Format. |
| Bereits zweisprachig im Code | `RainActivityText` (de/en per `Locale.preferredLanguages.first`, 13 Fälle), `RainActivityRegionPresentation` (`german`-Schalter, vier Texte doppelt), Locale-Meldung an den Server `PushManager.currentLocale()` ("de" oder "en"), `WarnFeedStore.languageCode()` (aus `Bundle.main.preferredLocalizations`, Header `Accept-Language`). Das sind drei verschiedene Wege der Sprachbestimmung (`Locale.preferredLanguages` vs. `Bundle.main.preferredLocalizations`): Sie liefern auseinander, wenn die App-Sprache pro App umgestellt wird (iOS-Einstellung "Sprache" je App). |
| Widgets/Live Activity | Widget: `LocalizedStringResource` in `PlaceEntity` ("Regenprognose", Schlüssel im Widget-Bundle vorhanden); Live Activity: `RainActivityPresentation` (8 deutsche Literale, u. a. "Regen in", "Endet in", "Daten veraltet"), `RainLiveActivity` ("Endet in", "Stand ..."); Shared: `RainOutlook`, `RainActivityRegionPresentation`, `WidgetPresentation` (20) mit deutschen Literalen, die per `Text(...)`-Schlüssel im Widget-Bundle gesucht werden. Das Widget-Bundle hat 36 Einträge; wie viele deutsche Literale darüber hinaus fehlen, ist nicht vollständig nachgezählt (siehe Tabelle unten). |
| Watch | `WatchText`/`WatchWidgetPresentation` mit englischen Schlüsseln; deutsche Übersetzungen in `de.lproj`. Wenige verbliebene deutsche Literale. Englisch ist hier der Quelltext, Deutsch die Übersetzung (umgekehrt zum iOS-Target). |
| NSE | `WarningNotificationText` (Schlüssel `WARN_PUSH_TITLE_SEVERE/FROST/ICE`, `WARN_PUSH_BODY`) und `NotificationNameStore.body` lesen über `hostBundle.localizedString(forKey:)` aus den Host-Strings. Funktioniert mit symbolischen Schlüsseln und `.strings`; ein Wechsel auf `.xcstrings` ginge ebenfalls (Bundle-API liest kompilierte Strings), muss aber getestet werden. |
| Accessibility | 54 Stellen mit `accessibilityLabel/Hint/Value` im Code; davon 13 `accessibilityLabel("...")` und 8 `accessibilityHint("...")` mit direkten Literalen. Viele Labels sind interpoliert ("Ort auswählen: \(name)", "\(layer.title) lädt ..."). Sie gehören zur selben Übersetzungsmenge. |
| Share-Texte | Keine (`ShareLink`/`UIActivityViewController`: 0). |
| UI-Tests | `WeatherUITests/WeatherSmokeTests.swift` startet fest mit `-AppleLanguages "(de)" -AppleLocale de_DE` und fragt deutsche Labels ab (`"Datenquellen und Datenschutz"`, `"Fertig"`, `"Regenradar"`, `"Daten neu laden"`, `"Ort auswählen: ..."`, `"Umbenennen"`, `"Löschen"`). Daneben stabile Identifier (`info-row-privacy`, `forecast-details`, `radar-layer-menu`, `radar-legend-toggle`). Solange die Tests de erzwingen und die deutschen Texte unverändert bleiben, bricht nichts. Jede Änderung eines deutschen Wortlauts bricht Abfragen; ein reines Umstellen auf Schlüssel mit unverändertem deutschem Text nicht. |
| Debug/Test-Stubs | `RadarLayerUITestStub` ("Quelle: Deutscher Wetterdienst") und `WarnFeedUITestStub` (DWD-Beispielwarnungen mit `"lang": "de"`) sind Fixtures; für englische UI-Tests bräuchte der Warnstub EN-Fixtures (die Warnliste fragt `Accept-Language` und der Server liefert die Sprachfassung des DWD). |

## 2. Hartcodierte deutsche Strings außerhalb der Strings-Dateien

Zählung der Fundstellen (String-Literale mit deutschem Inhalt, Stand 9.11.2026; "K" = steht in `NSLocalizedString(... value:)` und ist bereits über Schlüssel lokalisiert, also ohne Pflicht). Gesamt ca. 416 Treffer in 34 Dateien; abzüglich Fehltreffer (Schlüsselfragmente, Kommentare, englische Seitenfälle), bereits lokalisierter K-Stellen und Fixtures verbleiben **ca. 330 zu übersetzende Fundstellen, geschätzt 270 bis 300 verschiedene Texte** (Mehrfachvorkommen, z. B. "Fertig", "Abbrechen", "Löschen", zählen einmal).

### UI-sichtbar (zu lokalisieren)

| Bereich | Datei | Fundstellen |
|---|---|---|
| Radar-Screen | `Weather/Views/RadarScreen.swift` | 46 (Header, Ebenen-Menü, Zeitleiste, Detailkarte, Sheets, VoiceOver-Text) |
| Radar-Legende, Ebenen | `Weather/Map/RadarLegend.swift` 20, `RadarLayerLegend.swift` 29 (davon 11 K), `TemperatureScale.swift` 10 (K), `PixelReadout.swift` 2 (K), `Weather/Data/RadarLayer.swift` 13 (davon 5 K) | ca. 45 offen |
| Zeitleiste/Historie | `Weather/Data/RadarHistory.swift` 1, `SolarPosition.swift` 3, `Weather/Views/TimelineScrub.swift` (VoiceOver "Messung", "Vorhersage", "Unbekannt") | ca. 8 |
| Orte, Regionen | `PlacesSheet.swift` 18, `RegionViews.swift` 32, `PlacePushSettingsView.swift` 14 | 64 |
| Info und Webseiten | `InformationSheet.swift` 30 (längere Absätze), `SitePageSheet.swift` 9 | 39 |
| Einordnung (Apple Intelligence) | `ForecastInterpretation.swift` 16 (Fehlertexte, **Prompt "auf Deutsch"**, Locale-Prüfung `de_DE`), `ForecastInterpretationSection.swift` 3 | 19 |
| Fehler-/Statusmeldungen (Daten) | `Weather/Models/WeatherStore.swift` 17, `Shared/Data/RainForecast.swift` 15, `Shared/RainOutlook.swift` 7 | 39 |
| Mitteilungen/Push | `PushManager.swift` 45 (Fehler- und Statusmeldungen für Orte/Regionen/Testmeldung), `PushGrid.swift` 5 (Stufenbeschreibung), `RainActivityText.swift` 13 (bereits de/en doppelt im Code, in Strings überführen) | 63 |
| Live Activity, Widgets, Shared-Präsentation | `Shared/RainActivityRegionPresentation.swift` 12 (teilweise de/en doppelt), `WeatherWidgets/LiveActivity/*` 10, `Logic/PlaceEntity.swift` 3, `Views/WeatherWidgetViews.swift` 5, `Views/WidgetPresentation.swift` 20 | 50 (Widget-Strings teils vorhanden, Abgleich in L5) |
| Watch | `WatchRadarView` 4, `WatchPlacesView` 3, `WatchText` 2, `WatchWidgetPresentation` 2 | Fehltreffer überwiegend: dies sind **englische** Quelltexte, kein Befund |
| Info.plist | `NSLocationWhenInUseUsageDescription` | 1 (braucht `InfoPlist.strings` de/en) |

### Debug, Fixtures, Logs, Tests (nicht UI)

- `Weather/Data/RadarLayerUITestStub.swift` (1), `Weather/Warnings/Feed/WarnFeedUITestStub.swift` (6 DWD-Beispieltexte): Fixtures, nicht übersetzen; für EN-UI-Tests ggf. zweite Fixture-Variante.
- Kommentare im Code sind englisch. Logger/Print mit deutschem Text: bei der Stichprobe keine identifiziert; nicht vollständig geprüft.
- `WeatherTests` (48 Dateien, 22 davon mit deutschen Wörtern in Erwartungen): bei unverändertem deutschen Verhalten kein Änderungsbedarf; neue Tests kommen in L6.

Nicht ermittelt: Texte in `Weather/Warnings/` (Subscriptions, Matching) und alle Strings, die ohne Umlaut oder gelistetes Wort deutsch sind (kurze Einzelwörter wie "Orte", "Karte", Eigennamen). Die Zahlen sind eine Untergrenze; L1 liefert die verbindliche Zählung über das Lint-Skript.

## 3. Schlüsselparität de/en

| Bundle | Schlüssel de | Schlüssel en | nur de | nur en | Platzhalter-Abweichung |
|---|---|---|---|---|---|
| Weather | 136 | 136 | 0 | 0 | 0 |
| Widgets | 36 | 36 | 0 | 0 | 0 |
| Watch | 37 | 37 | 0 | 0 | 0 |
| Watch-Widgets | 28 | 28 | 0 | 0 | 0 |

Identische Texte de = en: `WARN_TYPE_FROST` ("Frost", korrekt), Watch: `Radar`, `Pause`, `In %dm` (korrekt, Lehnwort/Kurzform). Keine unübersetzten Platzhalter. Auffällig: in `Weather` sind sieben Schlüssel nicht per Literal im Code referenziert (`RAIN_STARTS_IN`, `RAIN_REGION_STARTS_IN` kommen per Push-`loc-key`; `WARN_LEVEL_WORD_1..4`, `WARN_VALID` vermutlich über zusammengesetzte Schlüssel). Hinweis: Die App-Store-Checkliste (`docs/app-store-release-checkliste.md` Zeile "Lokalisierung de/en") nennt noch "je 31 Zeilen"; der Stand ist 136.

## 4. Was bestimmt die App-Sprache; warum das Screenshot-Experiment deutsch blieb

- Maßgeblich ist die Systemsprache (oder die iOS-Einstellung "Sprache" für die App), aufgelöst gegen die vorhandenen `.lproj` (de, en). Es gibt keine In-App-Sprachwahl und keinen Code, der `AppleLanguages` setzt (außer den UI-Tests, die `(de)` erzwingen).
- `-AppleLanguages "(en)"` wirkt auf `Bundle.main.preferredLocalizations` und damit auf alle Schlüssel mit en-Eintrag (Warnungen, Temperaturlegende, Geräte-Kopplung, Info-Zeilen). Das wirkt also, nur die Texte im Code ohne Schlüssel sind das Problem. Das Screenshot-Experiment blieb "fast alles deutsch" aus genau diesem Grund (Befund aus Code: rund 330 Fundstellen ohne en-Eintrag; das Experiment selbst wurde hier nicht wiederholt). Dokumentiert in `docs/appstore-screenshots.md` ("Englisch nicht erzeugt").
- Zusätzlich deutsch bleibt: Standortabfrage-Dialog (kein `InfoPlist.strings`), der Prompt der Apple Intelligence ("auf Deutsch"), VoiceOver-Zeitleiste (`de_DE`) und die Legendenbänder (Dezimalkomma).
- Offene Frage (Entscheidung nötig, Architekturentscheidung): Ob die Entwicklungsregion in den Plists als `CFBundleDevelopmentRegion` und `CFBundleLocalizations` ausdrücklich gesetzt werden soll und welche Sprache bei anderen Systemsprachen (Französisch, usw.) gelten soll. Empfehlung: ausdrücklich `CFBundleLocalizations = [de, en]` setzen und Rückfall auf Englisch prüfen (Annahme: bessere Erfahrung für Nicht-Deutsche; nicht getestet).

## 5. Server-Texte (Backend nur gelesen, `Sources/RadarCore/`)

| Thema | Befund |
|---|---|
| Regen-Push | Nutzt `loc-key` `RAIN_STARTS_IN`/`RAIN_REGION_STARTS_IN` mit `loc-args` (Minuten); der Text entsteht auf dem Gerät aus `Localizable.strings` (en vorhanden). Kein Serverwerk nötig. |
| Warn-Push | `WarnPayload.swift`: `title-loc-key` `WARN_PUSH_TITLE_SEVERE/FROST/ICE`, `loc-key` `WARN_PUSH_BODY`, mit deutschem Rückfalltext im Payload; die Schlüssel stehen in der App (de/en). Ohne App-Strings greift der deutsche Rückfall (die NSE ersetzt ihn lokal). Kein Serverwerk nötig. |
| Testmeldung, Live-Activity-Test | `PushIntensity.testPayload` und `PushActivity` wählen Text nach `locale` der Installation (`de`/`en`): bereits zweisprachig. Die App meldet nur "de" oder "en" (`PushManager.currentLocale()`, Server akzeptiert nur diese zwei Werte; `PushApi`: 400 sonst). |
| DWD-Warntexte | `WarnApi.active` liest `Accept-Language` (erster Tag, `en` sonst `de`) und liefert die CAP-Fassung der Sprache (`lang` de/en, `Vary: Accept-Language`). Die App sendet den Header aus `Bundle.main.preferredLocalizations`. Wenn zu einer Warnung keine EN-Fassung vorliegt, ist unbelegt, was die App zeigt (nicht geprüft). |
| Ebenen-Titel | `Layers.swift`: Serverseitige `title` sind deutsch ("Luftdruck (Isobaren, ICON)", "Blitzdichte (NowCastMIX)" usw.). Die App benutzt diese Titel nicht direkt: `RadarLayer` hat eigene Titel im Code (`title`, `spokenName`, `frameCaption`), deshalb genügt die App-seitige Lokalisierung. Ob die Manifest-Titel irgendwo in der UI erscheinen, ist per Stichprobe nicht gefunden, aber nicht lückenlos geprüft. |
| Fehlertexte | Server liefert Fehlercodes (`invalid_installation` usw.); die Texte entstehen in der App (`PushManager`, ca. 45 Fälle). |
| Webseiten | `LandingPage.swift` ist zweisprachig (`/` de, `/en`, `hreflang`, Sprachumschalter, `og:locale`). **`SitePages.swift` (Datenschutz, Support, Impressum, Marketing) ist nur deutsch** (`<html lang="de">`). Der englische Datenschutztext liegt im Entwurf (`docs/datenschutz-entwurf-release.md` Teil A-EN), ist aber nicht auf der Seite. Die App öffnet `/datenschutz`, `/support`, `/marketing` in `SitePageSheet` ohne Sprachwahl. Für eine englische App ist das eine inhaltliche Lücke (rechtlich zu entscheiden: englische Datenschutzerklärung ist beschlossen, "Nutzerentscheidung 7.11."; Umsetzung auf der Seite offen). |
| Docs-Site | `docs-site/` ist Betreiberdokumentation, deutsch; nicht Teil der App. |

## 6. Qualitätsfragen

### Glossar (Entwurf, Fachbegriffe und Wortlaut; Annahmen markiert)

| Deutsch (heute) | Englisch (Vorschlag) | Hinweis |
|---|---|---|
| Showers | Showers | Eigenname, nie übersetzen |
| Regenradar | Rain radar | Ebenenname; "Radar" allein bleibt "Radar" |
| Ebene / Kartenebene | Layer / map layer | In der Ebenenauswahl "Layer" (Annahme: wie in Apple Karten, "Map type" wäre falsch, da mehrere Ebenen genau eine Auswahl) |
| Wolken, Blitze, Luftdruck | Clouds, Lightning, Pressure | "Isobaren" = "isobars" |
| Sonne (Ebene) | Sun / Daylight | Bezieht sich auf Tag/Nacht aus Satellit und Sonnenstand; Vorschlag "Sun" |
| Modellprognose | Model forecast | Ausdrücklich "model forecast, not a measurement" (Messwert = "measurement") |
| Messung / Vorhersage / Rückblick | Measurement / Forecast / Look-back | "Rückblick" = Satellit/Modell-Rückblick, kein Wetterbericht: "Look-back" oder "Past analysis" (Wortlaut vom Nutzer abnehmen) |
| Warnung (amtlich) | Warning (official) | "Wetterwarnung" = "Weather warning" |
| Stufe 1 bis 4 | Level 1 to 4 | DWD: Wetterwarnung, Markante, Unwetterwarnung, Extreme Unwetterwarnung = "Weather warning", "Marked weather warning", "Severe weather warning", "Extreme severe weather warning" (englische DWD-Bezeichnungen vor Übernahme gegen die DWD-Seite prüfen, nicht geprüft) |
| Mitteilungen | Notifications | iOS-Begriff |
| Regenhinweis | Rain alert | Schon so in den en-Strings |
| Zeitkritisch | Time Sensitive | iOS-Begriff (exakt Apple-Schreibweise) |
| Ort / Orte | Place / Places | Nicht "Location", das ist der Standort |
| Standort / Aktueller Standort | Location / Current Location | Systembegriff |
| Region / Umkreis (Gebiet) | Area | In en-Strings schon "area" ("Rain reaches your area") |
| Landkreis | District | Warngebiete: "districts and independent cities" |
| Live Activity | Live Activity | Apple-Begriff, in beiden Sprachen gleich |
| Systemeinstellungen | Settings | Systemlabel |
| Datenschutzerklärung | Privacy Policy | |
| Zeitleiste | Timeline | |
| Einordnung | Summary / Interpretation | Apple Intelligence: "Local summary"; Wortlaut abstimmen |
| Ohne Netz / Daten veraltet | Offline / Data out of date | |

Hinweis: Das Du ("Dein Standort ...") wird in Englisch zu "your"; sonstige Tonlage ruhig, sachlich, ohne Ausrufezeichen. Der Ton der bestehenden en-Strings (Bestandsmenge 136 plus Watch/Widgets) ist der Maßstab.

### Formatierung

- Datum/Uhrzeit: Systemformate nutzen (`.formatted`, `Text(date, format:)`), sodass 12/24 h der Region des Geräts folgt. Offen bleibt `SolarPosition` ("HH:mm" fest, 24 h) und VoiceOver-Zeitleiste (`de_DE` fest): durch `Locale.current` ersetzen. Zeitzone: Radargebiet = Deutschland, Anzeige in der Gerätezeitzone ist beabsichtigt zu prüfen (`SunMask.regionTimeZone` nur für Sonnenstand).
- Zahlen: Dezimaltrenner (Legende "7,5") soll aus `Locale` kommen (`Decimal`/`FormatStyle`), nicht aus String-Ersetzung nur für "de". Das betrifft `RadarLegend` (feste Strings), `TemperatureScale.number`, `PushGrid` (mm/h), Warn-Text "-1 °C" (kommt vom DWD).
- Einheiten: °C, mm/h, km/h, km, % bleiben (App ist Deutschland-bezogen; kein Wechsel auf °F/in/h geplant). Leerzeichen vor °C: deutsch "5 °C" vs. englisch "5°C": Entscheidung nötig (Vorschlag: `Measurement`/`FormatStyle` mit Locale nutzen oder "5 °C" beibehalten).
- Plural: "1 Stunde / 2 Stunden", "Regen in 1 Min.": Englisch "1 hour / 2 hours". Empfehlung `.stringsdict` oder Format mit Variantenschlüsseln nur für die wenigen Zähltexte (`RadarPastWindow.label`, "\($0) Minuten" in den Einstellungen "5, 10, 15 Minuten", "Höchstens N Orte/Regionen", "N Min."). Mit Abkürzung "min" entfällt der Plural.
- Textlänge: Englisch ist meist 10 bis 25 % kürzer; Risiko nur bei einzelnen Wörtern ("Notifications" länger als "Hinweise", "Time Sensitive" vs "Zeitkritisch"), kompakten Pillen und Widgets (kleinste Größe), Watch. Prüfpunkte im Plan: Dynamic Type bis Accessibility XXXL (vorhandener UI-Test fährt dies auf de), Pille der Zeitleiste, Legendenknöpfe.
- Accessibility: Alle Labels/Hints (54 Stellen) lokalisieren; VoiceOver-Aussprache ("Etwa 12 Grad Celsius, Modellwert" = "About 12 degrees Celsius, model value"); `accessibilityLabel` mit Interpolation braucht Format-Schlüssel mit nummerierten Platzhaltern.
- Rechts-/Quellentexte: DWD-Namensnennung, Lizenzhinweise (CC BY 4.0) und Änderungsvermerke in Info-Sheet: Pflichtangaben dürfen nicht verkürzt übersetzt werden; Wortlaut der Nennung ("Quelle: Deutscher Wetterdienst", "Source: Deutscher Wetterdienst") laut Lizenz beibehalten; vor Übernahme mit `docs/research/dwd-warnungen-weitergabe.md` abgleichen (Warntext bleibt unverändert).
- Apple Intelligence: Prompt und Fakten sind deutsch, Fehlerpfad prüft `de_DE`. Für Englisch braucht es englischen Prompt, `Locale`-abhängige Unterstützungsprüfung und englische Faktentexte (`ForecastInterpretation` Zeilen 11 bis 14); Unit-Tests nutzen deutsche Fakten.
- App-Store: `docs/apple-externe-tests.md` hat englische Beta-Beschreibung und Review-Notizen als Entwurf. Noch zu erstellen: englischer Store-Titel/Untertitel/Keywords/Beschreibung, englische Screenshots (heute nur `de`), englische Datenschutz-URL (siehe Abschnitt 5). Nicht in diesem Auftrag umgesetzt.

## Offene Entscheidungen (für den Nutzer)

1. **Konvention:** `.strings` mit symbolischen Schlüsseln beibehalten (Empfehlung, kein Migrationsrisiko, NSE funktioniert unverändert) oder String Catalog (`.xcstrings`) einführen (Apple-Standard, Xcode-Extraktion, aber Migration der vier Bundles und Test der NSE-Auflösung).
2. **Rückfallsprache** für Systemsprachen außer de/en: Englisch (Empfehlung) oder Deutsch.
3. **Wortlaut kritischer Begriffe** (Look-back, Layer, Einordnung/Summary, DWD-Warnstufen auf Englisch).
4. **Webseiten** (`/datenschutz`, `/support`, `/impressum`): englische Fassung im Backend als eigenes Backend-Paket nötig; erst abzustimmen.

## Quellen

Repo-Stand `d437499` (Dateien wie genannt); Backend `Sources/RadarCore/{WarnApi,WarnPayload,PushIntensity,PushActivity,PushApi,Layers,LandingPage,SitePages}.swift`; `docs/appstore-screenshots.md`, `docs/apple-externe-tests.md`, `docs/datenschutz-entwurf-release.md`, `docs/app-store-release-checkliste.md`. Apple-Plattformverhalten (Rückfall der Entwicklungsregion, `.xcstrings` in Extensions) ist hier nicht gegen Primärquellen geprüft; vor Umsetzung in L1 prüfen.
