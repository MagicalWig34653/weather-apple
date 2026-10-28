# Apple-HIG-Prüfung: ShowerNow Build 4

Stand: 28. Oktober 2026. Unabhängiger, auf Prüfung begrenzter Audit von **0.1.0 (4)**, Quellencommit [`6750d0e`](https://github.com/MagicalWig34653/weather-apple/commit/6750d0e954de900cb8bcf6f52b3faf1fc2d769d9). Alle Zeilen beziehen sich auf diesen eingefrorenen Commit; parallel entstehende spätere UI-Änderungen gehören nicht zum Audit. Keine Implementierung, Kontenänderung oder Releaseentscheidung durch den Audit. Keine allgemeine HIG-Konformitäts- oder App-Review-Garantie.

## Ergebnis und Prioritäten

**Ein bestätigter P2-Bedien-/Lesbarkeitsfehler bei maximaler Dynamic-Type-Größe.** Zwei weitere Empfehlungen und eine offene Touchflächenprüfung sind getrennt aufgeführt. P2 bezeichnet hier eine relevante Einschränkung einer unterstützten Bedienform, P3 eine Verbesserung; daraus folgt keine Aussage über Apples App-Review-Entscheidung. Kein P1-Befund.

### 1. P2 — Prognose und Zeitleiste überlagern sich bei maximaler Schrift

**Bestätigter visueller Fehler.** Auf iPhone 18 Pro, iOS 27, `accessibility-extra-extra-extra-large`, läuft der mehrzeilige Prognosetext über seine Glasfläche hinaus; Datenalter überlagert die folgende Zeitsteuerung. Zeitpunkt und „Messung“ werden abgeschnitten, schon der kurze Beispielname Berlin wird verkürzt. Zwei zeitlich getrennte Aufnahmen zeigten denselben Zustand. [Beleg](../../design/UI/HIG-build4/maximum-dynamic-type.png).

Betroffen: `Weather/Views/RadarScreen.swift:140` (Timeline), `:205` (Prognosekarte), `:109` (Header). Die untere Safe-Area-Kombination kann die stark gewachsene intrinsische Texthöhe nicht sinnvoll aufnehmen. Die frühere Prüfung nur bis Accessibility Extra Large deckte diese größte Kategorie nicht ab.

Apple fordert, Layout und Lesbarkeit für alle Schriftgrößen zu prüfen und Trunkierung möglichst zu vermeiden. [HIG Typography, Supporting Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography#Supporting-Dynamic-Type), [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

Empfehlung für einen Folgeauftrag: bei Accessibility-Größen ein eigenes vertikales bzw. scrollbar erreichbares kompaktes Steuerlayout verwenden; wichtigste Zeit-/Prognosetexte vollständig halten und die Glasflächen aus der tatsächlichen Inhaltshöhe ableiten. Nicht lediglich Schriftgröße begrenzen. Danach auch den größten Systemwert mit Fehlerbanner prüfen.

### 2. P3 — Radarfarben haben keine sichtbare Intensitätserklärung

**Beobachtung und daraus abgeleitete Empfehlung, kein nachgewiesener Bedienausfall.** Die Karte zeigt mehrere DWD-Farben, aber weder Hauptansicht noch Informationsansicht erklären die Farbstufen oder ihre Einheit. Der Messung-/Vorhersage-Streifen erklärt Zeitarten, nicht Radarintensität. Menschen ohne Radarerfahrung können die Farben deshalb nicht eindeutig zuordnen. [Hauptansicht](../../design/UI/HIG-build4/main-light.png).

Betroffen: `Weather/Views/RadarScreen.swift:21`, `Weather/Views/InformationSheet.swift:13`, `Weather/Map/RadarMap.swift:56`. Apples Infografik-/Chart-Leitlinien empfehlen Kontext und bei bedeutungstragenden Farben eine Erklärung; Accessibility verlangt ergänzende Information statt alleiniger Farbcodierung. Die Übertragung dieses Prinzips auf das Radar ist eine Audit-Empfehlung. [HIG Charts](https://developer.apple.com/design/human-interface-guidelines/charts), [HIG Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility).

Empfehlung: eine kleine aufrufbare, anhand des tatsächlichen DWD-Styles verifizierte Legende mit Text/Einheit anbieten, ohne die Karte dauerhaft mit zusätzlichem Text zu füllen. Keine unbestätigten Farbschwellen erfinden. Die bestehende textuelle Ortsprognose ist bereits eine hilfreiche Alternative für den ausgewählten Punkt.

### 3. P3 — Die Zeitmarkierung im Detaildiagramm erklärt sich visuell nicht

**Konkrete HIG-Empfehlung.** `RainChart` zeichnet eine aktuelle Zeitlinie, gibt ihr aber keine sichtbare „Jetzt“-Beschriftung; auch der Messung-/Vorhersage-Kontext der Karte fehlt in diesem Detaildiagramm. Die Erklärung darunter nennt Einheit und fehlende Werte, aber nicht diese Zeitmarkierung. [Detailansicht](../../design/UI/HIG-build4/details.png).

Betroffen: `Weather/Views/RadarScreen.swift:287`, `:308`. Eine interne `.value("Jetzt", ...)` ist keine sichtbare Annotation. Apple empfiehlt verständliche Titel, Labels und Kontext, damit Menschen die Aussage eines Diagramms vor dessen genauer Untersuchung erfassen. [HIG Charts](https://developer.apple.com/design/human-interface-guidelines/charts).

Empfehlung: die relevante Zeitreferenz sichtbar und für Assistenztechnik verständlich beschriften; Messung/Vorhersage nur passend zum tatsächlichen Datenvertrag kennzeichnen. Der vorhandene Prognose-Hauptsatz und die mm/h-Erklärung entsprechen bereits dem empfohlenen Kontextprinzip.

### 4. Offene Verifikation — AX-Rahmen mehrerer Buttons kleiner als ihre Layoutflächen

**Gemessener Accessibility-Baum, noch kein bestätigter kleiner Touchbereich.** Der frische XCTest-Baum meldet bei Standardtext Standort ungefähr 19,7×19,3 pt, Information 20×20 pt, Play 14×15,7 pt und Jetzt 36,7×18 pt. Der Quellcode legt dafür 44-/46-pt-Frames fest. Andere Elemente, etwa Bookmark (44×44) und Refresh (46×46), melden bereits die volle Fläche.

Betroffen: `Weather/Views/RadarScreen.swift:44`, `:47`, `:143`, `:162`, jeweils mit Plain-Button-Styling. AX-Rahmen allein beweisen nicht die effektive Touchregion; es wurden keine systematischen Randtaps oder automatischen Hit-Region-Audits ausgeführt. Deshalb **kein als bestätigt ausgegebener Touchziel-Verstoß**.

Apple nennt für iOS 44×44 pt als Standardziel und 28×28 pt als Minimum. [HIG Accessibility, Mobility](https://developer.apple.com/design/human-interface-guidelines/accessibility). Empfehlung: reale Randtaps innerhalb der vorgesehenen 44-/46-pt-Fläche und Accessibility Inspector prüfen; nur bei bestätigter Lücke die Hitregion korrigieren.

## Tatsächlich geprüft und positiv beobachtet

- Bereits vorhandenen Build-4-Simulatorbuild installiert, tatsächliche Bundle-Version 4 überprüft; kein neuer Appcode entwickelt. Eigene visuelle Sichtung in Light/Dark, Standardgröße Large und größter Accessibility-Größe. [Light](../../design/UI/HIG-build4/main-light.png), [Dark](../../design/UI/HIG-build4/main-dark.png).
- Increase Contrast aktiviert und nach Relaunch gesichtet: native Glasflächen werden deutlich opaker, Text bleibt in der Standardgröße lesbar. [Beleg](../../design/UI/HIG-build4/increase-contrast.png). Keine gemessene WCAG-Kontrastquote und keine allgemeine Kontrastfreigabe aus PNGs abgeleitet.
- Native reguläre Glasflächen liegen überwiegend auf der funktionalen Kartenebene; keine freien Glas-Dekorationen im Diagramm. Dies passt zur Materialhierarchie. [HIG Materials](https://developer.apple.com/design/human-interface-guidelines/materials).
- Apple-Logo/Legal-Link bleiben in der Standardhauptansicht frei. Zentraler Pin ist erkennbar; vertraute MapKit-Karte und Suchzugang sind vorhanden. [HIG Maps](https://developer.apple.com/design/human-interface-guidelines/maps).
- Horizontaler nativer Zeitslider mit chronologisch aufsteigenden Endzeiten, sichtbarem gewähltem Zeitpunkt und textlicher Messung-/Vorhersageanzeige; Farbe ist hier nicht der einzige Hinweis. [HIG Sliders](https://developer.apple.com/design/human-interface-guidelines/sliders).
- Eigene Navigation zu Diagramm/Einordnung, Rückkehr sowie Ortssheet und Suchfeld gesichtet. Ortssuche Berlin lieferte laut erfasstem Accessibility-Baum einen Berlin-Ergebniseintrag. [Orte](../../design/UI/HIG-build4/places.png). Native Suchfeld-Platzhalter erklärt Stadt/Adresse/Ort. [HIG Searching](https://developer.apple.com/design/human-interface-guidelines/searching).
- Der Livefehler „Radar unvollständig. Bitte aktualisieren.“ ist bei Standardgröße lesbar und handlungsorientiert; DWD-Zeit und Datenalter sichtbar. Die reale Provider-Kachelstörung selbst ist kein HIG-Verstoß.
- Quellprüfung: Animation startet nur manuell, Pause ist vorhanden, Öffnen eines Sheets/Hintergrundwechsel stoppt sie. Reduce-Motion-Environment verlangsamt den Framewechsel. Dies ist ein Codebefund, keine Laufzeitprüfung von Reduce Motion. [HIG Motion](https://developer.apple.com/design/human-interface-guidelines/motion).

## Prüfmethode, Grenzen und Übergabe

Aktuelle offizielle Apple-HIG-Seiten am 28. Oktober 2026 aufgerufen. Da der Webreader Apples verlinkten Markdown-Content-Type nicht verarbeitet, wurden die offiziellen `.md`-Varianten derselben Seiten direkt per HTTPS gelesen. Keine Sekundärquelle als Richtliniengrundlage.

Ein einzelner temporärer XCTest-Navigationslauf in einer isolierten Build-4-Kopie gewann die eigenen Screenshots und Accessibility-Bäume. Er endete nach 21,686 Sekunden mit einer fehlgeschlagenen Audit-Assertion: Der Audit erwartete nach aktivierter Suche einen weiterhin vorhandenen „Fertig“-Button. Die systemseitige Suchoberfläche erfüllte diese Annahme nicht; der Baum zeigte trotzdem das Berlin-Suchergebnis. Dies wird ausdrücklich nicht als bewiesener Appfehler oder erfolgreicher kompletter UI-Test gewertet. Keine bestehende Testsuite erneut ausgeführt. Keine temporären Audit-Teständerungen im Repository.

Offen: echte VoiceOver-Navigation/-Reihenfolge/-Ansagen und Audio Graphs, Full Keyboard Access/Switch Control, automatischer Accessibility-/Hitregion-/Kontrastaudit, physisches iPhone bei wechselndem Licht, Reduce Transparency und Reduce Motion zur Laufzeit, weitere Displaygrößen/Orientierungen und vollständiger Schriftgrößen-Matrixlauf. Kein Test auf bereitstehender Apple-Intelligence-Hardware. Vollständige gespeicherte-Orte-CRUD-Prüfung für diesen Audit nicht wiederholt.

Alle versionierten Audit-Screenshots zeigen ausschließlich die ShowerNow-App mit öffentlichem Beispielort Berlin beziehungsweise dessen öffentliche Kartenbeschriftungen. Keine privaten Orte, Standortberechtigung oder fremden Apps aufgenommen. Nach Prüfung System auf Large/Dark/Increase Contrast aus zurückgestellt. Simulatorressource freigegeben. Befunde zuerst an den Nutzer geben; Änderungen benötigen den entsprechenden Folgeauftrag. Keine Commit-/Push-/Accountaktion durch diesen Audit.
