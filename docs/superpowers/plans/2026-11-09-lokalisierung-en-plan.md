# Plan: App auf Englisch lokalisieren (9.11.2026)

Grundlage: [docs/research/lokalisierung-en.md](../../research/lokalisierung-en.md) (Bestandsaufnahme). Todolino-Aufgabe "App auf Englisch lokalisieren" (Projekt 0FBD00F1-1946-42A9-BB55-BA7D2E29F36B).

Ziel: Auf einem Gerät mit Systemsprache Englisch erscheinen alle nutzersichtbaren Texte der iOS-App, der Widgets, der Live Activity, der Watch-App, der Mitteilungen und des Standortdialogs auf Englisch; Deutsch bleibt unverändert. Keine neue Sprache über de/en hinaus, keine In-App-Sprachwahl, keine Backend-Änderung in diesem Plan (Ausnahme: Webseiten, siehe Risiken).

## Entscheidungen vorab (mit Empfehlung; Nutzer bitte bestätigen, sonst gilt die Empfehlung)

| # | Frage | Empfehlung | Folge |
|---|---|---|---|
| E1 | Konvention | Klassische `Localizable.strings` behalten. Weather-Target: symbolische Schlüssel `UPPER_SNAKE` wie die vorhandenen 136; im Code `NSLocalizedString("KEY", value: "<deutsch>", comment: "...")`, in SwiftUI `Text(LocalizedStringKey("KEY"))` oder `Text(NSLocalizedString(...))`. Widgets und Watch behalten ihre Konvention. | Keine Migration; Lint-Skript prüft nur `.strings`. Annahme: String Catalog bringt bei vier Bundles und der NSE keinen Vorteil. |
| E2 | Rückfall für andere Systemsprachen | Englisch; `CFBundleLocalizations = [de, en]` und `CFBundleDevelopmentRegion` in allen fünf Plists ausdrücklich setzen und das Rückfallverhalten in L1 mit `-AppleLanguages (fr)` testen | Wirkung vor Umsetzung nachweisen (nicht belegt). |
| E3 | Glossar | Entwurf aus der Bestandsaufnahme (Abschnitt 6) gilt als Startpunkt; Wortlaut-Fragen (Look-back, Summary) in der Abnahme klären | L1 legt `docs/glossar-en.md` nicht an; das Glossar bleibt in der Bestandsaufnahme (keine zusätzliche Datei). |
| E4 | Webseiten englisch | Eigenes Backend-Paket nach dieser App-Welle, App öffnet bis dahin die deutsche Seite auch bei Englisch | Offen; Lücke im Release-Gate dokumentieren (L6). |

## Arbeitspakete

Allgemeine Regeln für alle Pakete: Deutsche Texte und deutsches Verhalten bleiben wörtlich unverändert (Schlüssel einführen, `value:` = bisheriger deutscher Text, `de.lproj` = derselbe Text). Platzhalter in beiden Dateien identisch (nummeriert `%1$@`, wenn die Reihenfolge wechseln kann). Zählformen als Formatschlüssel oder `.stringsdict`. Keine Änderungen an UI-Test-Identifiern. UI-Test-Dateien nur in L6. Jeder Worker: `docs/status.md` nicht anfassen (nur L6), stattdessen Ergebnisse im Auftragsbericht; `post_progress` mit Aufgaben-ID.

> **Status 9.11.2026: E1 bis E3 bestaetigt, Welle 1 (L1) umgesetzt** (Lint-Skript `tools/check_l10n.sh` mit Baseline, `InfoPlist.strings` de/en, Plist-Schluessel, `AppLanguage`, `LocaleFormat`, `UITestLaunch`). Abweichung: das Skript ist reines Python in Bash-Huelle (Baseline-Datei statt Allow-Liste fuer den heutigen Bestand). Details: `docs/status.md`.

> **Status 9.11.2026: L2 umgesetzt** (Radar-Screen, Zeitleiste, Ebenen, Legende, Sonne; `COMMON_*` vorhanden, L3/L4 duerfen sie verwenden; Baseline 348 -> 266; Details `docs/status.md`).

> **Status 9.11.2026: L3 umgesetzt** (Orte, Regionen, Push, Info, Webseiten-Sheet; Baseline 266 -> 102; Details `docs/status.md`).

> **Status 9.11.2026: L4 umgesetzt** (Warnungen waren schon lokalisiert; Daten-/Fehlertexte, `RainOutlook`, `WeatherStore`, Einordnung samt Prompt; Baseline 102 -> 51, Rest L5; Details `docs/status.md`).

> **Status 9.11.2026: L5 umgesetzt** (Widgets, Live Activity, Intent-Texte, gemeinsame Tabelle `SharedTexts`, Push-Titel `%@`; Baseline 51 -> 0; Details `docs/status.md`).

### L1 Infrastruktur (Dateibesitz: `tools/check_l10n.sh`, `Configuration/*Info.plist`, `Weather/Resources/*/InfoPlist.strings` (neu), `project.yml`, `Weather/Resources/*/Localizable.strings` nur für Konventionstext/Kopfkommentar, kleine Hilfen in `Shared/` nur wenn nötig)

1. Lint-Skript `tools/check_l10n.sh` (Bash plus eingebettetes Python, keine neuen Abhängigkeiten): je Bundle (`Weather/Resources`, `WeatherWidgets/Resources`, `WeatherWatch`, `WeatherWatchWidgets`): Schlüsselparität de/en, Platzhalterparität (`%@`, `%d`, `%lld`, `%1$@` ...), Sonderzeichen (unmaskierte `"`), identische Texte (nur Warnung, Ausnahmeliste: Frost, Radar, Pause, `In %dm`); jeden `NSLocalizedString`-/`String(localized:)`-Schlüssel im Code gegen die `.strings`; Hartcodier-Prüfung: Swift-Literale mit Umlauten oder deutschen Wortlistenwörtern in `Text(`, `Button(`, `Label(`, `Toggle(`, `Picker(`, `Section(`, `navigationTitle(`, `TextField(`, `accessibilityLabel(`, `accessibilityHint(`, `Alert`-Titeln, Rückgabestrings in Präsentationsdateien. Allow-Liste `tools/l10n_allow.txt` (Datei:Zeile-unabhängig, per Text) für Fixtures und Debug-Stubs. Ausgabe: Zahl der offenen Treffer je Datei, Exit-Code 1 bei Verstößen; Modus `--baseline` schreibt die heutigen Treffer als Ausgangslage, sodass das Skript ab Wellen 1 bis 3 nur noch neue Treffer verbietet und am Ende (L6) mit leerer Baseline bestehen muss.
2. `InfoPlist.strings` de/en (neu) für `NSLocationWhenInUseUsageDescription` (en: "Your location centers the map and loads the rain forecast directly from the German Weather Service (DWD). There is no background location tracking."). In `project.yml` als Resource des Weather-Targets aufnehmen und das Xcode-Projekt mit `xcodegen` neu erzeugen (Xcodegen-Lauf: nur dieser Worker, siehe Build-Regel).
3. Plists: `CFBundleLocalizations` [de, en], `CFBundleDevelopmentRegion`; Verhalten für `fr` prüfen (E2). Prüfen, ob die NSE Strings des Host-Bundles weiterhin findet (Test: `Bundle.localizedString` mit en, nur als Unit-Test auf vorhandenen NSE-Logiktests aufbauen).
4. Sprachbestimmung vereinheitlichen: ein kleiner Helfer (z. B. `AppLanguage.code` in `Shared/`) auf Basis `Bundle.main.preferredLocalizations.first`; `PushManager.currentLocale()`, `RainActivityText`, `RainActivityRegionPresentation` und `WarnFeedStore.languageCode()` nutzen ihn. Das ist nur sinnvoll, wenn L5 danach dieselbe Stelle nutzt (Reihenfolge beachten); bei Zweifel nur dokumentieren statt umbauen.
5. Konvention schriftlich: kurzer Abschnitt in `docs/decisions.md` (Entscheidung E1 bis E3, Datum) und in `README.md` der Aufruf des Lint-Skripts.

Abnahme L1: Skript läuft auf dem heutigen Stand grün im Baseline-Modus und listet die Treffer je Datei in einer Zahl; `fr`-Rückfall belegt; Standort-Dialog in der englischen Simulator-Sprache englisch (Simulator-Prüfung; siehe L6). Aufwand: ca. 1 Tag; Dateien klein.

### L2 Radar-Screen, Header, Zeitleiste, Ebenen, Legende (Dateibesitz: `Weather/Views/RadarScreen.swift`, `TimelineScrub.swift`, `Weather/Map/RadarLegend.swift`, `RadarLayerLegend.swift`, `TemperatureScale.swift`, `PixelReadout.swift`, `Weather/Data/RadarLayer.swift`, `RadarHistory.swift`, `SolarPosition.swift`, `Weather/Resources/{de,en}.lproj/Localizable.strings` Abschnitt `RADAR_*`, `LEGEND_*`, `TIMELINE_*`)

Umfang: ca. 100 Texte (RadarScreen 46, Legende/Ebenen ca. 45, Zeitleiste/Historie/Sonne ca. 8), darunter ca. 25 Accessibility-Labels/Hints (z. B. "Ort auswählen: \(name)", "\(layer.title) lädt ..."). Legendenbänder "0,1 bis unter 0,2" auf Locale-Zahlen (`FormatStyle` mit Dezimaltrenner) und "bis unter" = "to under"/"up to under": englische Fassung der Bänder festlegen ("0.1 to under 0.2" oder "0.1 – <0.2", Wortlaut in Abnahme). VoiceOver der Zeitleiste: `de_DE` durch `Locale.current`; `TemperatureScale.number` ohne `languageCode == "de"`-Sonderfall (Locale-Zahlformat). `SolarPosition` "Sonne bis/ab" (3) und `HH:mm`-Format durch `Date.FormatStyle` mit Systemzeit. Ebenentitel und Bildunterschriften ("Rückblick", "Modell", "Messung") ebenfalls.
Abhängigkeit: L1 (Skript, Konvention). Konflikt mit L3/L4 vermeiden: `RadarScreen.swift` gehört ausschließlich L2 (enthält Ort-speichern-Sheet, "Abbrechen", "Fertig": gemeinsame Schlüssel `COMMON_DONE`, `COMMON_CANCEL`, `COMMON_DELETE`, `COMMON_OPEN_SETTINGS` legt L2 an; L3 verwendet sie danach).
Tests: Unit-Tests für `TimelineAccessibility.value` mit `en_US`/`en_GB`, `TemperatureScale` (Dezimaltrenner, Minus U+2212), `RadarPastWindow.label` (1/mehrere). Aufwand: 1,5 bis 2 Tage.

### L3 Sheets: Orte, Details, Info, Mitteilungen/Regionen (Dateibesitz: `Weather/Views/PlacesSheet.swift`, `InformationSheet.swift`, `SitePageSheet.swift`, `PlacePushSettingsView.swift`, `RegionViews.swift`, `Weather/Push/PushManager.swift` (nur Texte), `PushGrid.swift`, `Weather/Push/RainActivityText.swift`, `Weather/Resources/*/Localizable.strings` Abschnitte `PLACES_*`, `INFO_*` (Erweiterung), `PUSH_*`, `REGION_*`)

Umfang: ca. 175 Texte: PlacesSheet 18, RegionViews 32, PlacePushSettingsView 14, InformationSheet 30 (lange Datenschutz- und Quellenabsätze; Lizenz-/Namensnennung unverändert übernehmen), SitePageSheet 9, PushManager 45 (Fehlertexte; mehrfach identisch: Schlüssel teilen), PushGrid 5, RainActivityText 13 (von Inline-`german ?` auf Schlüssel). Zähltexte "höchstens N Orte/Regionen/Hinweise", "\($0) Minuten", "Stand vor N Min." als Formatschlüssel. Alert-/Dialogtexte gemeinsam prüfen (Länge in Buttons).
Abhängigkeit: L1 und die gemeinsamen Schlüssel aus L2 (`COMMON_*`). Reihenfolge innerhalb: Info-Sheet zuletzt (längste Texte, Rechtstexte, Nutzer-Review).
Tests: Unit-Tests für `PushManager`-Fehlertexte (bestehende deutsche Erwartungen bleiben, neue Variante mit englischem Bundle über die vorhandene Test-Bundle-Auflösung); UI-Test-Identifier unverändert. Aufwand: 3 bis 4 Tage.

### L4 Warnungen und Einordnung (Dateibesitz: `Weather/Warnings/**`, `Weather/Views/WarningsListView.swift`, `WarningDetailView.swift`, `WarnSettingsView.swift`, `Weather/Intelligence/ForecastInterpretation.swift`, `ForecastInterpretationSection.swift`, `Weather/Models/WeatherStore.swift` (nur Texte), `Shared/Data/RainForecast.swift`, `Shared/RainOutlook.swift`)

Umfang: Warnungen sind bereits zu rund 66 Schlüsseln lokalisiert; zu prüfen und zu ergänzen sind Rest-Literale (nicht gezählt; Skript aus L1 liefert die Zahl). Einordnung: englischer Prompt, `Locale`-abhängige Unterstützungsprüfung (heute fest `de_DE`), englische Faktentexte und Fehlertexte (19 Texte). Fehler-/Statusmeldungen der Daten: WeatherStore 17, RainForecast 15, RainOutlook 7 (39 Texte). Prüfen: Warnliste bei fehlender EN-Fassung einer Warnung (Anzeige DWD-Text in Deutsch? Hinweistext), Datumsformate "heute/morgen/gestern" vorhanden.
Abhängigkeit: L1. Gemeinsame Dateien mit L5: `Shared/RainOutlook.swift` und `Shared/Data/RainForecast.swift` gehören L4; L5 verwendet sie nur lesend (Widgets und Live Activity sprechen Text aus `RainOutlook`).
Tests: bestehende `WarnFeedTests` auf Sprachwechsel erweitern, Apple-Intelligence-Prompt als reiner Textbaustein-Test (ohne Gerätemodell). Aufwand: 2 bis 2,5 Tage.

### L5 Widgets, Watch, Live Activity, NSE (Dateibesitz: `WeatherWidgets/**`, `WeatherWatch/**`, `WeatherWatchWidgets/**`, `WeatherNotificationService/**`, `Shared/RainActivityRegionPresentation.swift`, `Shared/NotificationNameStore.swift`, `Shared/WarningNotificationText.swift`, `Shared/RainActivityAttributes.swift`; deren `Localizable.strings`)

Umfang: ca. 50 Texte (Widget-Präsentation 20, Live Activity 10, Place-Entity 3, Widget-Views 5, Region-Präsentation 12), Abgleich mit den vorhandenen 36 Widget-Einträgen (viele sind schon da, die fehlenden werden ergänzt), Watch-Rest (wenige). Live-Activity-Texte "Regen in"/"Endet in" laufen über `Text(...)` in der Widget-Extension: Format-Schlüssel mit nummerierten Platzhaltern. Widget-Galerie: Anzeigename/Beschreibung/Parameter ("Zeigt die Prognose für einen in Showers gespeicherten Ort.") lokalisieren. NSE: Test, dass `WARN_PUSH_*` und `RAIN_*` im Host-Bundle bei Systemsprache en englisch aufgelöst werden.
Abhängigkeit: L1 (Sprachhelfer), L4 für `Shared/RainOutlook.swift` (Texte sind dort bereits mit L4 geklärt; L5 wartet nicht, sondern übernimmt die Schlüssel nach L4-Merge).
Tests: bestehende Widget-/Präsentationstests mit englischem Locale; Timeline-Vorschauen manuell. Aufwand: 2 bis 2,5 Tage.

### L6 Tests, Screenshots auf Englisch, Doku, Abnahme (Dateibesitz: `WeatherUITests/**`, `WeatherTests/Localization*` (neu), `tools/screenshots.sh`, `docs/status.md`, `docs/appstore-screenshots.md`, `docs/app-store-release-checkliste.md`, `docs/decisions.md`, `README.md`)

1. Unit-Test `LocalizationParityTests`: lädt `en.lproj`/`de.lproj` der Test-Host-App und prüft, dass jeder Schlüssel in beiden Sprachen existiert und die Platzhalter übereinstimmen (ergänzt das Shell-Lint im Xcode-Lauf).
2. Pseudolokalisierung: Test-/Debug-Lauf mit `-NSDoubleLocalizedStrings YES` und `-AppleTextDirection YES -NSForceRightToLeftWritingDirection YES` (Layout-Test, Texte um 100 % länger und RTL; kein Release-Inhalt). Das ist eine Prüfung, keine Auslieferung.
3. UI-Tests: Bestehende Tests laufen unverändert mit `(de)`. Neu: `WeatherEnglishSmokeTests` mit `-AppleLanguages "(en)" -AppleLocale en_US`, je Hauptscreen (Radar, Ebenen-Menü, Orte, Details, Info-Sheet, Warnungen, Mitteilungseinstellungen eines Ortes, Regionen) ein Satz englischer Schlüsselwörter ("Done", "Places", "Rain radar", "Notifications", "Official warnings" usw.) und zusätzlich der Negativtest "kein deutsches Schlüsselwort sichtbar" (z. B. `Fertig`, `Abbrechen`, `Orte`, `Regenradar` existieren nicht). Identifier unverändert nutzen.
4. Screenshots Englisch: `tools/screenshots.sh` um `LANG=en` erweitern (Ausgabe `design/appstore-screenshots/<plattform>/<maße>/en/`), Sprache `(en)`/`en_US`, Uhrzeit-/Datumsanzeige 12 h möglich; Watch zusätzlich. Bei Mehrdeutigkeit der Archivregen-Motive bestehende Einschränkungen übernehmen.
5. Doku: `docs/status.md` (Ergebnis, Prüfungen, nicht ausgeführte Prüfungen), `docs/appstore-screenshots.md` (Englisch erzeugt), `docs/app-store-release-checkliste.md` (Zeilen "Lokalisierung de/en" und "Englische Screenshots"; veralteter Hinweis "je 31 Zeilen"), `docs/decisions.md`.
6. Release-Gate dokumentieren: englische Store-Texte (Titel, Untertitel, Beschreibung, Keywords) und englische Webseiten sind **nicht** Teil dieses Plans (E4) und vor der englischen Store-Lokalisierung nötig.
Aufwand: 2 bis 3 Tage, davon die Screenshots ca. 0,5 Tage.

## Reihenfolge und Wellen

Regel Build/Simulator: Höchstens ein Agent führt gleichzeitig `xcodebuild`/Simulator aus (gemeinsame Build- und Simulatorressourcen, siehe `docs/team.md`). Textliche Arbeit (Strings, Schlüssel einführen) darf parallel erfolgen, solange die Dateien getrennt sind.

| Welle | Pakete | Parallel? | Build/Simulator |
|---|---|---|---|
| 0 | E1 bis E4 vom Nutzer bestätigen | | |
| 1 | L1 | allein (Fundament, xcodegen, Skript, Plist) | L1 baut einmal |
| 2 | L2, L3, L4 (höchstens drei Worker) | ja, getrennte Dateien; `COMMON_*`-Schlüssel legt L2 zuerst an (kleiner Vorab-Commit in Welle 2, L3 rebased darauf) | Textarbeit parallel; Build/Test reihum, ein Agent zur Zeit; jeder Worker liefert einen Commit in eigenem Worktree, Strings-Dateien gemeinsam: pro Paket eigener Abschnitt (`/* L2: ... */`) und Rebase vor Push |
| 3 | L5 | allein oder parallel zu Ende Welle 2, wenn `Shared/RainOutlook.swift` (L4) gemerged ist | Build durch einen Agenten |
| 4 | L6 | allein, nach Merge von L2 bis L5 | einziger Build-/Simulator-Agent |

Engpässe: Alle Pakete bearbeiten `Weather/Resources/{de,en}.lproj/Localizable.strings`. Konfliktvermeidung: Jeder Worker fügt nur einen eigenen Abschnitt mit Kommentarkopf an und sortiert nichts um; L1 legt die leeren Abschnittsköpfe vorab an.

## Aufwand (Strings)

| Bereich | Neue Texte (Schätzung) | Anmerkung |
|---|---|---|
| L2 | ca. 100 (davon ca. 25 Accessibility) | 17 der heutigen Funde sind schon als Schlüssel vorhanden (`NSLocalizedString`) |
| L3 | ca. 175 (30 Info-Sheet, davon lange Absätze) | Dopplungen in Fehlertexten bündeln |
| L4 | ca. 60 plus Rest-Literale aus L1-Zählung | |
| L5 | ca. 50 minus vorhandene Widget-Schlüssel | |
| Gesamt | ca. 330 Fundstellen, ca. 270 bis 300 verschiedene Texte; entspricht grob dem Doppelten des heutigen Bestands (136 plus 36 plus 37 plus 28) | Untergrenze, siehe Bestandsaufnahme Abschnitt 2 |

Gesamtaufwand grob 11 bis 14 Arbeitstage Agentenarbeit, verteilt auf die Wellen (Wandzeit durch Parallelität ca. 5 bis 6 Tage). Das sind Schätzungen, keine Messwerte.

## Tests und Abnahme

| Prüfung | Wer | Inhalt | Ergebnis nötig |
|---|---|---|---|
| `tools/check_l10n.sh` | L1 bis L6 | Parität, Platzhalter, Hartcodierung; am Ende ohne Baseline | Exit 0 |
| Unit-Tests (`xcodebuild test`, Befehle laut `README.md`) | je Paket | bestehende 609 bleiben grün; neue Sprach-Tests | grün |
| UI-Suite de (25 Tests) | L6 | unverändert, `(de)` | grün |
| UI-Test en je Hauptscreen | L6 | englische Schlüsselwörter, Negativtest auf deutsche Wörter | grün |
| Pseudolokalisierung/Doppelte Strings | L6 | Layout: Abschneiden, Zeilenumbrüche, Dynamic Type XXXL | Sichtprüfung/Screenshots |
| Sprachrückfall `fr` | L1 | App startet mit `-AppleLanguages (fr)`; Ergebnis dokumentieren | belegt |
| Standortdialog, Mitteilungstexte (Regen, Warnung) | L1/L5 | `InfoPlist.strings`, NSE auflösen | belegt (Simulator), Gerät **nicht** prüfbar im Plan |
| Screenshots en | L6 | iPhone (zwei Größen), iPad, Watch | vorhanden, gesichtet |

Nicht Bestandteil und nicht als erfolgreich zu melden: Gerätetests (Mitteilungen, Live Activity, Widgets auf Hardware), Prüfung durch Muttersprachler, englische Store-Texte, englische Webseiten.

## Risiken

1. **Zwei Konventionen bleiben** (symbolisch im Weather-Target, Literal-Schlüssel in Widgets, englisch in Watch): Verwechslungsgefahr. Maßnahme: Lint-Skript und Kurzabschnitt in `docs/decisions.md`.
2. **SwiftUI-Literal als Schlüssel:** `Text("Fertig")` sucht den Schlüssel "Fertig"; ein neuer Schlüssel `COMMON_DONE` erfordert `Text(LocalizedStringKey("COMMON_DONE"))` oder `NSLocalizedString`. Wer Literale stehen lässt, behält den Fehler. Das Lint-Skript soll das erkennen.
3. **UI-Tests hängen am deutschen Wortlaut:** Änderungen am Wortlaut brechen ca. 86 Abfragen. Maßnahme: deutsche Texte nicht ändern; Tests bleiben `(de)`.
4. **Zusammengesetzte Texte und Plural:** Wortstellung im Englischen weicht ab; nummerierte Platzhalter und Formatschlüssel nötig; Pluralregeln für wenige Zähltexte.
5. **Apple Intelligence:** Prompt und Fakten deutsch, Gerätesprache nicht fest an App-Sprache; Test ohne Gerätemodell nur textuell möglich. Verhalten bei en-Gerät ohne Modell nicht prüfbar.
6. **Webseiten deutsch** (Datenschutz, Support, Impressum): englische Nutzer landen auf deutscher Seite; rechtliche Abstimmung (englische Fassung existiert als Entwurf `docs/datenschutz-entwurf-release.md` Teil A-EN) und Backend-Paket nötig.
7. **Sprachbestimmung uneinheitlich** (`Locale.preferredLanguages` vs. `Bundle.main.preferredLocalizations`): bei App-Sprache anders als Systemsprache sendet die App möglicherweise "de" an den Server, zeigt aber Englisch. L1 vereinheitlicht.
8. **Rechtstexte und Quellenhinweise** im Info-Sheet (DWD, CC BY 4.0, Änderungsvermerke, Warntext unverändert): keine freie Übersetzung ohne Nutzerabnahme.
9. **Textlängen** in Pillen, Widgets (klein), Watch, Alert-Buttons; Prüfung über Pseudolokalisierung.
10. **Parallelität auf `Localizable.strings`:** Merge-Konflikte; Abschnittsregel und Rebase vor Push.
11. **Build 43 / parallele Arbeit im Repo:** Pakete arbeiten in eigenen Worktrees von `origin/main`, nicht im gemeinsamen Arbeitsverzeichnis.

## Empfehlung

Reihenfolge: L1 (klein, schafft Lint und Rückfall-Nachweis), dann L2, L3 und L4 parallel (getrennte Dateien, aber nur ein Build-Agent zugleich), danach L5, zuletzt L6 mit englischem UI-Test und Screenshots. Reihenfolge nach Sichtbarkeit innerhalb der Welle: L2 (Hauptscreen) vor L3 vor L4. Annahme: Der Nutzer bestätigt E1 bis E3 vor Welle 1; E4 (Webseiten) wird getrennt entschieden und blockiert die App-Arbeit nicht.
