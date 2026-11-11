# Bedienungshilfen-Prüfung (Accessibility Nutrition Labels)

Stand: 11.11.2026, Build 46 plus Fixes dieser Prüfung (kein neuer Upload, keine Buildnummer-Änderung). Todolino-Karte "Release: Bedienungshilfen prüfen und Accessibility Nutrition Labels". Simulator "B15 iPhone 18 Pro" (iOS 27), Sprachen de und en. Nur Simulator und Code-Review; kein Gerätetest.

## 1. Empfehlung für App Store Connect

Nur nachweislich Geprüftes ankreuzen. Stand heute:

| Label | Empfehlung | Grund |
|---|---|---|
| VoiceOver | NICHT ankreuzen, erst nach Gerätetest (Anleitung Abschnitt 11) | Code und Audit sauber, echter VoiceOver-Lauf im Simulator nicht möglich |
| Sprachsteuerung (Voice Control) | NICHT ankreuzen, erst nach Gerätetest | Namen vorhanden und ergänzt, Sprachsteuerung selbst nur am Gerät prüfbar |
| Größerer Text | Erst nach Gerätetest ankreuzen | Simulator AXXXL ok (ein Fehler gefunden und behoben), zwei bewusste Deckelungen (Abschnitt 5) |
| Ausreichender Kontrast | NICHT ankreuzen | Messung: Akzentfarbe Cyan im Hellmodus 2,2:1 (Soll 4,5:1), Nebentexte auf Glas 2,5 bis 3,5:1; Designentscheidung nötig (Abschnitt 8) |
| Dunkle Oberfläche | Darf angekreuzt werden (App); Widgets/Watch nicht einzeln geprüft | Alle Hauptscreens dunkel im Simulator geprüft, keine Blitzflächen, Karte wird abgedunkelt |
| Nicht nur Farbe | NICHT ankreuzen | Warnstufen ok (Wort, Ziffer, Symbol, Linienmuster); Zukunft/Vergangenheit sichtbar nur Farbe plus Position, Regenfarben der Karte nur Farbe |
| Bewegung reduzieren | Erst nach Gerätetest | Alle eigenen Animationen im Code mit Reduce-Motion-Zweig; Systemübergänge (Zoom) nicht prüfbar |
| Untertitel | nicht zutreffend, leer lassen | Keine Video-/Audioinhalte |
| Audiobeschreibungen | nicht zutreffend, leer lassen | Keine Video-/Audioinhalte |

## 2. Methode

- `WeatherUITests/AccessibilityAuditTests.swift`: `performAccessibilityAudit()` auf Radar (Messung, Vorhersage, Legende, Prognosedetails), Orte, Neue Region, Regenhinweis je Ort, Info und alle sechs Unterseiten, Warnungen (Liste, Karte, Detail; Fixture), Warnungs-Einstellungen (Stub push), je de und en (insgesamt 35 Audit-Läufe). Dazu Dynamic Type AXXXL (de, en) mit Screenshots, Trefferflächen-Prüfung und Audit.
- Der Test lässt nur Funde der Typen Beschriftung, Trefferfläche, Trait, Element-Erkennung fehlschlagen. Kontrast, Dynamic Type und Textabschnitt (heuristisch) werden als INFO protokolliert und hier von Hand mit Screenshots und Pixelmessung ausgewertet. Gefilterte Falschmeldungen sind einzeln im Test benannt (`knownFalsePositive`).
- Kontrastmessung: `tools/contrast_measure.swift` (Pixelmessung aus Screenshot plus Elementrahmen, WCAG-Verhältnis); `testContrastDump` liefert Screenshots und Rahmen von 9 Screens hell und dunkel.
- Rohdaten (Screenshots) liegen nicht im Repo (Größe); sie entstehen bei jedem Lauf (`/tmp/a11y-out-dir` im Test, Verzeichnis mit Namen in der ersten Zeile).

## 3. Tabelle je Label

Status: ok = nachweislich geprüft; Einschr. = mit Einschränkung; nicht ok; Gerät = nicht prüfbar im Simulator.

| Label | Status | Beleg |
|---|---|---|
| VoiceOver | Gerät (Code ok) | Audit: 0 Funde zu Beschriftung (`sufficientElementDescription`), Trait, Element-Erkennung in 35 Läufen; Slider mit `accessibilityRepresentation`, Wert, Hint und Adjustable-Action (UI-Test `testTimelineSliderExposesAccessibilityValue`); Zeit-Pille Button mit Wert/Hint/Aktionen; Warnkarten je eine Zeile mit vollem Label; Details Abschnitt 7 |
| Sprachsteuerung | Gerät (Code ok, ergänzt) | Alle Bedienelemente haben Namen (Audit); Symbol-Knöpfe haben jetzt `accessibilityInputLabels` (Abschnitt 6) |
| Größerer Text | Einschr. | Screenshots AXXXL de/en für Radar, Legende, Orte, Neue Region, Info, Warnungen, Detail; Trefferflächen aller Hauptknöpfe `isHittable` und ≥ 44 pt (46/44/48 pt); Fehler Regenlegende behoben (Abschnitt 5) |
| Ausreichender Kontrast | nicht ok | Messwerte Abschnitt 8 |
| Dunkle Oberfläche | ok | Screenshots hell und dunkel, 8 Screens: Radar, Vorhersage, Legende, Orte, Warnungen, Detail, Info, Region; dunkle Texte lesbar (min. 2,55:1 nur Unterzeile, Abschnitt 8) |
| Nicht nur Farbe | Einschr. | Abschnitt 9 |
| Bewegung reduzieren | Gerät (Code ok) | Abschnitt 4 |
| Untertitel | n. z. | keine Medien |
| Audiobeschreibungen | n. z. | keine Medien |

## 4. Bewegung reduzieren (Code-Review, Simulator-Einstellung nicht nachweisbar)

Prüfung per Code, weil `ReduceMotionEnabled` per `defaults` im Simulator nicht belegt wirkt und kein UI-Test den Zustand lesen kann. Ergebnis je Stelle:

| Stelle | Verhalten mit Reduce Motion |
|---|---|
| ScreenGlow (`ScrubGlowView`) | `TimelineView` pausiert, Winkel 0, Breite 1, feste Deckkraft (0,3 / 0,8), kurze 0,2-s-Blenden; Unit-Test `orbitAngle(reduceMotion: true) == 0` |
| Pulsieren/Atmen | entfällt (feste Deckkraft) |
| Zeit-Pille, Pillen-Tint, Hinweiszeilen | `.animation(reduceMotion ? nil : ...)` |
| Slider-Daumen (Bouncy) | `nil` |
| Legende ein/aus (`bouncy`) | `nil` |
| Press-Feedback (`PressFeedbackButtonStyle`) | kein Skalieren |
| Wiedergabe der Zeitleiste | 3 s statt 2 s pro Bild |
| Warnkarte, `setVisibleMapRect` | `animated: !reduceMotion` |
| Kartenmitte bei Ortswechsel | `setRegion(animated: true)` in `RadarMap.center`: Systemanimation der Karte, folgt nicht dem Schalter (offen, Vorschlag Abschnitt 10) |
| `navigationTransition(.zoom)`, `.glassEffect(.interactive())` | Systemverhalten, nicht prüfbar; Apple ersetzt Zoomübergänge bei Reduce Motion nach Dokumentation durch Überblenden (nicht am Gerät belegt) |

Einschränkung: Das Muster `reduceMotion` im Glow wird beim Anlegen des Glow-Fensters übernommen; Umschalten während eines Scrubs wirkt erst beim nächsten Scrub.

## 5. Dynamic Type bis AXXXL

- Radar: Kopfzeile stapelt (Ort über Ebene), Ebenenmenü nur Symbol (Beschriftung bleibt für VoiceOver), Karte "Prognosedetails", Zeit-Pille 2-zeilig, Slider unverändert 44 pt; alles `isHittable`.
- Legende Regenradar: Fehler. Das Panel hatte `fixedSize(horizontal: true)`, bei AXXXL lief es links aus dem Bild (Titel und Farbfelder abgeschnitten, Prognosekarte wurde mit eingequetscht). Behoben: ab Bedienungshilfen-Größen feste Breite 260 pt wie bei der Ebenen-Legende (Text bricht um, Zeilen scrollen). Nachher-Screenshot geprüft: Titel umbricht, alle Zeilen vollständig und scrollbar; das Panel überdeckt bei AXXXL die Prognosekarte (Legende ist ein Overlay, schließt mit der Palette).
- Orte, Neue Region, Info, Warnungen, Warnungsdetail: Standard-Listen/Formulare skalieren und brechen um; Warnkarten stapeln das Symbol über den Text.
- Bewusste Deckelung: Quellenzeile auf der Karte bis `xxxLarge` (damit sie nicht die Karte füllt), Warnungs-Kopfzeile Statusnotizen bis `accessibility1`; Navigationsleisten-Knöpfe ("Fertig") skalieren nach Systemregeln begrenzt. Audit meldet das als "Dynamic Type teilweise nicht unterstützt".
- Audit-Heuristik "Text clipped": 40 Meldungen auf Systemlisten/Formularen (Footer, Zeilentitel); in den gesichteten AXXXL-Screenshots (Radar, Legende, Orte, Neue Region, Info, Warnungen) kein abgeschnittener Text außer dem Legendenfehler. Als Falschmeldung der Heuristik gewertet (sie bewertet die Größe 100 Prozent), außer den drei oben.

## 6. Sprachsteuerung

Sichtbares Symbol und Name der Bedienelemente; neu ergänzte `accessibilityInputLabels` (de/en als Schlüssel `VC_*`, `PLACES_ALERT_FOR`):

| Element | Label (VoiceOver) | Zusätzliche Sprachnamen |
|---|---|---|
| Ortungs-Pfeil | Aktuellen Standort verwenden | Standort, Ortung |
| Palette | Legende [Ebene] | Legende, Farbskala |
| Info | Datenquellen und Datenschutz | Info, Datenschutz |
| Warndreieck | Amtliche Warnungen | Warnungen |
| Lesezeichen | Ausgewählten Ort speichern oder umbenennen | Ort speichern, Lesezeichen |
| Fadenkreuz | Wert in Kartenmitte vorlesen | Wert vorlesen |
| Ortsknopf | Ort auswählen: Name | Ortsname, Ort auswählen, Orte |
| Ebenenmenü | Kartenebene wählen | aktive Ebene, Kartenebene |
| Zeit-Pille | Animation abspielen/pausieren | Abspielen/Pause, Uhrzeit der Pille |
| Glocke je Ort | Regenhinweis für [Ort] (vorher nur "Regenhinweis", mehrfach gleich) | Regenhinweis |
| Karte/Liste (Warnungen), Fertig, Schalter, Listen | Systemtexte | nicht nötig |

Echte Spracherkennung ("Tippe Info") nur am Gerät prüfbar.

## 7. VoiceOver (Code-Review plus Audit)

- Zeit-Slider: nativer `Slider` als Repräsentation, Label "Radarzeitpunkt", Wert "[Tag,] hh:mm, Messung/Vorhersage", Hint mit Zeitspanne, Adjustable-Action ±1 Slot.
- Zeit-Pille: ein Element (Button), Wert wie Slider, Aktionen "Zur aktuellen Zeit springen" und Abspielen/Pause, Hint erklärt Tippen und Halten.
- Karte: Label "[Ebene] für [Ort]", Hint "Lange drücken", Aktion "Wert in Kartenmitte vorlesen"; Marker/Overlays erzeugen keine eigenen Elemente (Karte als eine Einheit; Warnkarte hat Linienmuster-Hinweis).
- Warnkarten: `children: .ignore`, ein Label (Stufe, Typ, Zeitraum, Quelle), Button-Trait; Gruppenüberschriften als Header.
- Legendenzeilen: je ein Element mit gesprochenem Label ("0,1 bis unter 0,2 Millimeter pro Stunde").
- Orte: Auswahl der Orte jetzt als `isSelected`-Trait (vorher Häkchen als Bild "checkmark" vorgelesen); Glocke mit Ortsname.
- Reihenfolge: Standardfolge (Kopf, Prognose, Seitenknöpfe, Pille, Slider); nicht am Gerät geprüft.
- Elemente ohne Label: keine gefunden (Audit).
- Widgets: Diagrammbalken ausgeblendet, Texte als Zeilen; Live Activity kombiniert; Watch: Radar mit Adjustable-Action und Label, Widget-Text als ein Element. Nur Code-Review, nicht im Simulator geprüft.

## 8. Kontrast (Pixelmessung, WCAG)

Mindestwert 4,5:1 normaler Text, 3:1 großer Text/Bedienelemente. Hellmodus ("hell"), Dunkelmodus ("dunkel"). Werte aus `tools/contrast_measure.swift`; Hintergrund = Median des Rings um das Element (Glas über Karte schwankt, daher Richtwert).

| Element | hell | dunkel | Bewertung |
|---|---|---|---|
| Zeit-Pille (Uhrzeit, Titel) | 18,0 | 7,6 | ok |
| Ortsname "Berlin" im Ortsknopf | 18,4 | 4,4 | dunkel knapp unter 4,5 (Titel, fett 17 pt, großer Text-Grenze 3:1 gilt nicht) |
| Unterzeile "Regenradar" im Ortsknopf (`.secondary`) | 3,0 | 2,55 | nicht ok |
| Quellzeile auf der Karte (`.secondary`, Glas) | 2,9 bis 3,0 | 3,3 bis 3,5 | nicht ok |
| Prognosekarte "Vorerst kein messbarer Regen" | 16,2 | 4,3 | dunkel knapp unter 4,5 |
| Legende Regenskala (Werte) | 19,0 | 5,3 bis 6,1 | ok |
| Warnstufen-Chips Stufe 1/3 (Text) | 18 bis 20 | 9,6 bis 12,8 | ok |
| Warnkarte Text/Quellzeile (`.secondary` auf Tönung) | 3,25 bis 3,35 | 4,1 bis 5,0 | hell nicht ok, dunkel teils |
| Stand der Daten, Hinweis "Kein Ersatz..." (`.secondary`) | 3,1 bis 3,4 | 5,9 | hell nicht ok (Systemfarbe) |
| Systemfußzeilen in Formularen (`.secondary`) | 3,3 | 5,9 | hell nicht ok (Systemfarbe) |
| Akzentfarbe `.tint(.cyan)`: "Fertig", Links, "Region hinzufügen", "Standort verwenden" | 1,9 bis 2,2 | 8,1 bis 9,7 | hell nicht ok |
| Karten-Warnknopf (Rot auf Glas, Stufe 3) | 5,1 | 3,2 bis 3,3 | dunkel nicht ok |
| Zähler im Warnknopf (weiß auf Rot) | 5,0 | 5,0 | ok |
| Erhöhter Kontrast (Simulator) | Screenshots `hc-*`: Glas deutlich heller/umrandet, Texte lesbar | gleich | System-Anpassung greift; keine eigene Nachmessung |

Die Pixelwerte sind mit dem Audit-Befund "Contrast failed/nearly passed" konsistent (Quellzeile, Unterzeile, Fertig, Datenschutzerklärung, Legendenwerte).

Fazit: Mit der Akzentfarbe im Hellmodus und den `.secondary`-Texten auf Glas ist "Ausreichender Kontrast" nicht belegt. Behebung ändert das Aussehen und ist daher nur Vorschlag (Abschnitt 10).

## 9. Nicht nur Farbe

| Information | Alternative ohne Farbe? |
|---|---|
| Warnstufe | Ja: Wort ("Stufe 3: Unwetterwarnung"), Ziffer, Symbol je Stufe, Rahmenstärke; Karte: Linienmuster (gepunktet, gestrichelt, lang gestrichelt, durchgezogen) mit Erklärtext |
| Zukunft orange / Vergangenheit blau (Pille, Glow, Slider-Linie) | Teilweise: Marke "Jetzt" am Slider (2x6 pt Strich), Daumenposition, Uhrzeit mit Tag; die Pille zeigt Messung/Vorhersage nicht als Text (nur VoiceOver) |
| Regenintensität auf der Karte | Nur Farbe auf der Karte; Legende mit Zahlenstufen (mm/h), Wert-Auslesen für Temperatur |
| Temperatur/Feuchte | Legendenzeilen mit Zahlen; Karte Farbe; "Wert in Kartenmitte vorlesen" liefert den Zahlenwert |
| Warnknopf (Farbe + Zähler) | Zähler und Symbol je Stufe, Label/Wert "N Warnungen, höchste Stufe X" |
| Fehler/Hinweise (orange) | Symbol (Dreieck, WLAN) plus Text |

## 10. Nur Vorschläge (ändern das Aussehen; Nutzerentscheidung)

| # | Vorschlag | Vorher | Nachher | Aufwand | Empfehlung |
|---|---|---|---|---|---|
| V1 | Akzentfarbe hell abdunkeln (nur Hellmodus, `.tint` adaptiv, z. B. #007A94; Kontrast auf Weiß 2,2 -> 5,0) | Cyan #00C0E8 (Knöpfe, Links, Toggles) | Dunkleres Türkis hell, dunkel unverändert | klein (1 Stelle, aber sichtbare Farbänderung der ganzen App) | Empfohlen, wenn "Ausreichender Kontrast" gewünscht |
| V2 | Nebentexte auf Glas/Gruppen: `.secondary` -> `.primary` mit 0,75 Deckkraft oder eigene Farbe (Quellzeile, Unterzeile, Warnkarten-Fließtext) | grau, 2,5 bis 3,4 | dunkler, >= 4,5 | klein bis mittel | Empfohlen für die 4 Radar-Texte (Unterzeile, Quellzeile, Prognosekarte dunkel, Ortsname dunkel) |
| V3 | Pille: Wort "Vorhersage"/"Messung" klein unter der Uhrzeit oder Symbol (Sonne/Uhr) | nur Farbton | Text oder Symbol zusätzlich | mittel (Pillenhöhe/Layout, UI-Tests) | Empfohlen für "Nicht nur Farbe" |
| V4 | Karte: Regenskala ist Daten-Farbe (DWD), nicht änderbar; Hinweis in der App-Beschreibung statt Änderung | - | - | - | Label "Nicht nur Farbe" erst ankreuzen, wenn V3 umgesetzt und die Kartenfarben als datenbedingt akzeptiert werden (Apple lässt Ausnahmen für reine Datenvisualisierung nur mit Textalternative zu; Zahlenwerte per Wert-Auslesen vorhanden) |
| V5 | Kartenmitte: `setRegion(animated:)` nur bei ausgeschalteter Reduce Motion animieren | System-Karte animiert immer | ohne Animation | klein, kein Optikwechsel im Normalfall | Wäre ohne Rückfrage umsetzbar; hier nicht gemacht, weil Karten-Re-Centering getestet werden muss (nächste Runde) |

Mockups: kein Bild im Repo (Größe). Das Vorher-Bild entspricht `normal-light-radar`/`normal-light-orte` der Läufe; das Nachher ergibt sich direkt aus den genannten Farbwerten (Hex und Kontrastverhältnis in der Tabelle).

## 11. Testanleitung für Lino (Gerät, TestFlight-Build)

Vor jedem Test: Einstellungen laden, Zeit nehmen; Ergebnis (ok, Problem + Screen) notieren.

### VoiceOver (Einstellungen > Bedienungshilfen > VoiceOver)
1. App öffnen. Wischen von oben links: Ortsname, Ebenenmenü, Prognose, Lesezeichen, Standort, Legende, Warnungen, Info, Zeit-Pille, Slider. Kommt jedes Element mit sinnvollem Namen (kein "Schaltfläche" allein)?
2. Slider fokussieren, mit Wischen nach oben/unten einstellen: Zeit und "Messung/Vorhersage" werden angesagt, Karte wechselt.
3. Zeit-Pille: Doppeltippen = Abspielen/Pause; Rotor-Aktionen: "Zur aktuellen Zeit springen".
4. Ort wechseln: Ortsname doppeltippen, Ort wählen; die Auswahl wird als "ausgewählt" gelesen; die Glocke heißt "Regenhinweis für [Ort]".
5. Ortssuche: Suchfeld, Ergebnis wählen; Neue Region anlegen, Regler und Umkreis bedienbar.
6. Warnungen öffnen: Eine Karte = ein Fokus; Stufe, Typ, Zeitraum, Quelle werden vorgelesen; Detail öffnen und lesen.
7. Info öffnen und alle Unterseiten durchgehen; Mitteilungen-Einstellungen: Schalter und Hinweise.
8. Eine Fehlstelle: Karte lange gedrückt halten ("Lange drücken") und Ort speichern.

### Sprachsteuerung (Einstellungen > Bedienungshilfen > Sprachsteuerung, Sprache Deutsch und Englisch)
1. "Zeige Namen": prüfen, dass Symbol-Knöpfe Namen tragen.
2. "Tippe Info", "Tippe Standort", "Tippe Legende", "Tippe Warnungen", "Tippe Lesezeichen".
3. "Tippe Abspielen" / "Tippe Pause" für die Zeit-Pille (oder die Uhrzeit nennen).
4. "Tippe Orte", Ort sprechen; "Tippe Fertig".
5. In Orte: "Tippe Regenhinweis" (mehrere Orte: Ortsname nennen).
6. Slider: "Zeige Zahlen", Slider antippen oder "Erhöhen"/"Verringern" sagen.
7. Neue Region: Namenfeld per Sprache füllen.

### Größerer Text (Einstellungen > Anzeige > Textgröße > Bedienungshilfen: größte Stufe)
1. Radar: Kopf, Prognosekarte, Zeit-Pille, Slider sichtbar und bedienbar?
2. Legende öffnen (Palette): Titel und Farbfelder vollständig sichtbar, Zeilen scrollen.
3. Orte, Neue Region, Info, Warnungen, Warnungsdetail: nichts abgeschnitten, nichts überlappt.
4. Quellzeile auf der Karte bleibt kleiner (bewusst); lesbar?
5. Ebenenmenü (nur Symbol) bedienbar.
6. Zurück auf normale Größe: Layout wie vorher.

### Bewegung reduzieren (Einstellungen > Bedienungshilfen > Bewegung > Bewegung reduzieren)
1. Slider ziehen: Rand-Leuchten ruhig (kein Wandern, kein Pulsieren)?
2. Zeit-Pille tippen: Abspielen, keine Federbewegung an Knöpfen.
3. Ort wechseln: Karte springt oder bewegt sich nur kurz (Hinweis: Systemanimation der Karte).
4. Sheets öffnen (Info, Orte, Warnungen): Überblenden statt Zoom?
5. Legende ein/aus: ohne Federeffekt.
6. Zusätzlich: Transparenz reduzieren und Kontrast erhöhen einschalten, alle Hauptscreens hell und dunkel ansehen.

## 12. Behoben in dieser Prüfung

- Regenlegende bei AXXXL: Breite 260 pt, Textumbruch (`RadarLegend.swift`).
- Voice-Control-Namen für alle Symbol-Knöpfe (`RadarScreen.swift`, `PlacesSheet.swift`; Schlüssel `VC_*` in de/en).
- Glocke je Ort mit Ortsnamen; Auswahl-Trait und Häkchen ausgeblendet in der Orteliste.
- Neue Testklasse `AccessibilityAuditTests` und `tools/contrast_measure.swift`.

## 13. Nicht geprüft

VoiceOver und Sprachsteuerung am Gerät, Reduce-Motion-Zustand zur Laufzeit, Zoom-Übergänge mit Reduce Motion, Widgets und Watch im Simulator (nur Code), echte Reduktion der Transparenz (Einstellung nicht nachweisbar im Simulator), Querformat/iPad.
