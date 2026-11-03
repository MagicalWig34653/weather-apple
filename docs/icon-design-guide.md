# Icon-Design-Leitfaden (ShowerNow)

Stand: 3. November 2026. Anlass: Der Nutzer lehnt v2a bis v2c ab ("sprechen mich alle nicht an") und verlangt professionelle Designmethodik. Dieser Leitfaden fasst Primärquellen zusammen, bewertet v2 und begründet v3 (`design/Icon/v3/`). Das produktive `Weather/Resources/Icon/AppIcon.icon` ist unverändert.

Kennzeichnung: **[Apple]** = aus Apples HIG/WWDC-Transkripten belegt; **[Praxis]** = Fremdquelle/Konvention; **[Annahme]** = eigene Ableitung, nicht belegt.

## 1. Regelwerk

1. **Ein Konzept, ein dominantes Symbol.** Eine Kernidee mit minimaler Formenzahl; Microsoft: höchstens zwei Metaphern, besser eine. Lesbar ohne Namen darunter ("wäre der Zweck klar, wenn es die einzige App wäre?"). [Apple HIG, WWDC17, Microsoft]
2. **Silhouette zuerst.** Das Motiv muss als einfarbige Form erkennbar sein (Test: schwarz-weiß, Augen zukneifen, 29 pt). Keine extremen Dick-Dünn-Gegensätze. [WWDC17, Microsoft, Praxis]
3. **Figur-Grund-Kontrast.** Weiß/Hell auf gesättigtem Grund; mittlerer Helligkeitsabstand zählt mehr als Farbton. Mindestens ein Element weiß oder sehr hell (für Mono/Tinted: "mindestens ein Element weiß, meist das markanteste"). [WWDC17, WWDC25-361]
4. **Wenige, kräftige Farben.** Grund (Verlauf aus einem Farbton) + eine Primärfarbe + höchstens ein Akzent. Der Akzent trägt die Aussage ("jetzt", Regen). Gelb auf Blau ist komplementär und stark. [WWDC17 "bold, distinct colors", Microsoft Palettenlogik, Praxis]
5. **Weiche Verläufe, Licht von oben.** Grund als sanfter Hell-Dunkel-Verlauf (oben heller), keine Verläufe in den Vordergrundformen; System-Gradienten statt reinem Weiß/Schwarz. [WWDC25-220]
6. **Keine Details, die kleiner als etwa 8 bis 10 % der Icon-Höhe sind.** Keine dünnen Linien, keine spitzen Ecken; runde Ecken und kräftige Strichstärken. [HIG, WWDC25-220]
7. **Flach und frontal zeichnen, System macht die Tiefe.** Keine eigenen Schatten, Glanzlichter, Bevel, Glow oder Blur; keine 3D-Perspektive. Tiefe entsteht über Ebenen (bis zu vier Gruppen), gefüllte überlappende Formen und Transparenz. [HIG, WWDC25-220/361]
8. **Quadratische, unmaskierte, vollflächige Ebenen; Motiv zentriert.** Hintergrund per Fill (Volltonfarbe/Verlauf) in Icon Composer, nicht als Bild; Vektor (SVG), Text in Kurven; bei Watch rund beschnitten (1088er-Canvas), Motiv mittig. [HIG, WWDC25-361]
9. **Ebenen nach Farbe und Tiefe trennen**, damit Dark/Tinted über einen einzigen Fill umgestellt werden können. Dark: Farben des Default beibehalten, gedämpfter; Tinted: monochrom, Kontrast prüfen. Kernmerkmale in allen Darstellungen gleich. [WWDC25-361, HIG]
10. **Optische Korrektur statt reiner Geometrie.** Kreise größer als Quadrate wirken gleich groß (Kreis ca. 5 bis 8 % überstehen lassen), Schwerpunkt statt Bounding-Box zentrieren, Hakenformen (Schirmgriff) optisch ausrichten. [Praxis/Keyline-Konvention; Prozentwerte = Annahme]
11. **Kategorie kennen, dann abheben.** Wetter-Apps nutzen Sonne/Wolke/Tropfen und viel Blau; wer nur das wiederholt, ist austauschbar. Eigenständigkeit über eine unerwartete, aber funktionsnahe Form und die Akzentfarbe. [WWDC17 "be unique"]
12. **Test in allen Größen und im Kontext.** 1024, 120, 60, 29 px; Home-Screen neben anderen Icons, Ordner, Settings; Default, Dark, Tinted/Clear. Squint-Test. Details verschwinden, Silhouette bleibt. [WWDC17, Praxis]
13. **Prozess:** Skizzieren (Papier, viele Ideen) -> 3 bis 4 klar verschiedene Konzepte -> schwarz-weiß Silhouette prüfen -> Farbe -> klein testen -> verwerfen/iterieren; Ergebnis zeigen, ohne zu erklären, und fragen "was ist das?". Kein ständiges Redesign: Linie über die Zeit verfeinern. [WWDC17, Praxis]

Anti-Patterns: Text/Schrift, Fotos, Screenshots/UI-Nachbau, Schatten-/Glow-/Glas-Spielerei im Artwork, Hairlines, mehr als etwa 3 Farben, abstrakte Formen ohne Bedeutung, versteckte Kanten, Apple-Hardware-Nachbauten, Schwarz als Watch-Hintergrund, gemalte Maske/Rundung. [HIG, WWDC17]

## 2. Checkliste (vor jeder Vorlage abhaken)

- [ ] Ein Satz beschreibt das Motiv; es gibt genau ein dominantes Element
- [ ] Silhouette in Schwarz-Weiß bei 29 px erkennbar
- [ ] Höchstens 3 Farben (Grund, Primär, Akzent); Akzent trägt die Bedeutung
- [ ] Kleinstes Element über 8 % der Höhe, keine Linien unter 6 %
- [ ] Hell/Dunkel-Abstand Motiv zu Grund deutlich (Squint-Test)
- [ ] Keine Effekte im Artwork, keine Maske, keine Schrift
- [ ] Schwerpunkt mittig, Motiv innerhalb etwa 12 bis 88 % der Fläche
- [ ] Dark: Motiv bleibt lesbar; Tinted: mindestens ein heller Hauptteil
- [ ] 120/60/29 px angesehen; neben typischen Nachbar-Icons geprüft
- [ ] Nicht verwechselbar mit Apple Wetter (Sonne/Wolke auf Blau) oder Kategorie-Klischee
- [ ] Rückfrage bei 3 Personen ohne Erklärung: "Wofür ist die App?"

## 3. Was wir bisher falsch gemacht haben (v2a bis v2c)

- **Zuerst gerendert, nicht entworfen.** Es gab keine Skizzen- und Silhouettenphase; drei Varianten desselben Gedankens ("Standardmotiv in Blau"), keine Auswahl aus klar verschiedenen Konzepten.
- **v2a (Scheiben):** drei konzentrische Kreise lesen sich als Zielscheibe/Aufnahme/Fokus, nicht als Regen; kein Charakter, keine Hell-Dunkel-Struktur im Motiv (Weiß 30 % Transparenz = matt, kein klarer Kontrast).
- **v2b (Wolke + gelber Tropfen):** genau das Kategorie-Klischee (Apple Wetter, Dutzende Apps). Wolke aus Kreisen und Balken wirkt wie Clipart; Proportionen zufällig (Tropfen klein gegenüber Wolke, schief im Raum, Wolke nach links oben verschoben ohne Grund), Gelb als einziger Akzent ohne Bezug zur Aussage. Kein Bezug zur Funktion "Radar + Zeit".
- **v2c (Tropfen + Ring):** generisches Wassertropfen-Symbol; weißer Tropfen in 25 %-weißem Ring ohne Kontrast; im Dark-Rendering verschwindet der Tropfen (Ebene auf `fill: automatic`, keine per-Appearance-Behandlung).
- **Alle:** Grund ist ein beliebiges Standardblau mit flachem Verlauf ohne Lichtlogik; Motive nicht optisch zentriert/ausgemessen; Dark nur automatisch, nicht gestaltet (`fill-specializations` für den Hintergrund wurden von `ictool` nicht angewendet, siehe `icon-v2.md`); kein Test neben Nachbar-Icons; keine Wettbewerbsanalyse.

## 4. Quellen (abgerufen 3.11.2026)

- Apple, Human Interface Guidelines "App icons" (Änderungsprotokoll: 28.10.2026 Icon-Formate, 8.6.2026 Liquid Glass): <https://developer.apple.com/design/human-interface-guidelines/app-icons> (Volltext gelesen)
- Apple, WWDC25 "Say hello to the new look of app icons" (220): <https://developer.apple.com/videos/play/wwdc2025/220/> (Zusammenfassung des Transkripts)
- Apple, WWDC25 "Create icons with Icon Composer" (361): <https://developer.apple.com/videos/play/wwdc2025/361/> (Zusammenfassung des Transkripts)
- Apple, WWDC17 "App Icon Design" (822): <https://developer.apple.com/videos/play/wwdc2017/822/> (Prozess, Metapher, Test; ältere Visuals, Prinzipien weiter gültig)
- Microsoft, "Design guidelines for Windows app icons" (Metapher, Silhouette, Palette, Verlaufswinkel 120 Grad): <https://learn.microsoft.com/en-us/windows/apps/design/iconography/app-icon-design> (Fremdplattform, nur Prinzipien)
- Zweitquellen/Praxis (nicht im Volltext, vorsichtig): Create with Swift "Crafting Liquid Glass app icons with Icon Composer" <https://www.createwithswift.com/crafting-liquid-glass-app-icons-with-icon-composer/>; Cieden "Icon grids and keylines" <https://cieden.com/book/sub-atomic/iconography/icon-grids-and-keylines>; Medium "The Squint Test"; Carrot-Weather-Entwicklerseite <http://www.meetcarrot.com/weather/v5.html> (Icons bewusst für kleinste Größen gebaut).
- Nicht gefunden: eine WWDC26-Session zu App-Icons (die HIG-Seite wurde 8.6.2026 und 28.10.2026 überarbeitet, Inhalt siehe oben). Goldener Schnitt/Kreisraster: kein belastbarer Beleg für App-Icons; Apples Raster liegt als Vorlage in den Design Resources (nicht geladen, nur Verweis in HIG/WWDC25). Konkrete Prozentwerte (8 %, 12 bis 88 %, optischer Überstand) sind Annahmen.

Kategorie in Worten: Apple Wetter setzt auf eine große Wolke/Sonne in Verlauf-Blau mit Glaseffekt; Carrot Weather auf ein Charaktermotiv mit Persönlichkeit und viele Alternativen; Dark Sky hatte ein eigenständiges Symbol (nicht belegt). Gemeinsam: ein Motiv, großer Kontrast, wenig Detail.

## 5. v3: Konzepte (Pakete `design/Icon/v3/v3a..v3d.icon`)

Generator `design/Icon/v3/generate_v3.py`, Render `render.sh`, Tafel `make_overview.py` (Pillow). Vorschauen `design/Icon/v3/previews/` (Default, Dark, Tinted 1024; 120/60/29), Übersicht `previews/overview.png`. Jedes Paket: 1 bis 2 Gruppen, 3 Farben, kein Text.

| Konzept | Idee | Farben | Bewertung |
|---|---|---|---|
| v3a Zeitring | Weißer Ring = Zeitachse, gelber Sektor = Radar-Sweep/nächstes Regenfenster | Blau, Weiß, Gelb | Funktionsnah und eigenständig, klare Silhouette; liest sich aber auch als Timer/Stoppuhr. Sektor bei 29 px klein, aber sichtbar |
| v3b Regenstriche | Drei große schräge Kapseln = Regen ohne Wolke/Tropfen | Blau, Weiß, Gelb, Hellblau | Sehr klar bei 29 px, eigene Handschrift; wirkt wie Eq/Slashes, "Wetter" nur durch Kontext |
| v3c Sonne + Zelle | Gelber Kreis überlappt großen weißen Kreis (Sonne/Wolke, Regenzelle) | Blau, Gelb, Weiß | Minimal, stark im Kontrast, Apple-nah (überlappende Formen); zu generisch/nah an Apple Wetter, Mastercard-Anmutung |
| v3d Schirm | Ein großer gelber Schirm, weißer Griff, leicht geneigt | Teal/Blau, Gelb, Weiß | Stärkste Lesbarkeit und Charakter ("brauche ich einen Schirm?"), eindeutig Regen, nicht Radar; Klischee-Grad mittel |

Iterationen (jeweils mindestens eine): v3a Scheibe mit Sektor wirkte als Tortendiagramm -> Ring + Sektor; v3b Striche nach links schwer -> Abstände/Breite angepasst; v3c gleich große Kreise ohne Hierarchie -> Sonne kleiner, Zelle dominant; v3d erst Balken (als Equalizer/Barcode gelesen, verworfen), dann Schirm mit dünnem Griff (zu dünn), dann kräftiger Griff.

**Technische Fallen:** In `icon.json` ist die **erste Gruppe die oberste Ebene** (zuerst gelistet = vorn); ein verdeckter Sektor sah wie "Ebene fehlt" aus. Verlauf als `{"linear-gradient":[c1,c2],"orientation":{...}}` im Fill funktioniert in `ictool`. `fill-specializations` (Dark) werden weiterhin nicht sichtbar angewendet: Dark zeigt automatisch Schwarz mit dem Verlauf als Motivfarbe, wo Weiß als Ebenenfarbe stand; gelbe Elemente bleiben gelb. Tinted-Beispiel mit `--tint-color 0.58 --tint-strength 0.8` wirkt grünlich (nur Beispiel).

## 6. Empfehlung (ehrlich)

Nach Checkliste liegt **v3d (Schirm)** vorn: ein dominantes Symbol, drei Farben, Silhouette bei 29 px lesbar, Akzent trägt die Aussage, eindeutig "Regen", nicht das Wolke/Tropfen-Klischee, funktionsnah ("Schirm nötig?"). Zweite Wahl **v3b** (für Radar-/Zeit-Anmutung) oder **v3a** (Funktionsbezug Zeitleiste).

**Professionellen Anspruch erreicht keiner der Entwürfe vollständig.** Es sind geometrisch generierte Formen ohne Handarbeit. Ein Designer bzw. Handarbeit im Icon Composer müsste leisten: (1) Silhouette von Hand zeichnen (Schirmwölbung, Zackenabstand, Griffkurve, Spitze/Stock oben), optisch zentrieren; (2) bewusste Farbwahl und Paletten-Tests auf echten Wallpapern, Dark-/Tinted-Fills pro Ebene; (3) Glasparameter feinjustieren (Specular, Translucency, Schatten pro Gruppe) in der GUI; (4) Tests auf Gerät, neben Nachbar-Icons, Watch-Rundmaske; (5) Nutzerumfrage ohne Erklärung.

**Was der Nutzer selbst im Icon Composer anpassen kann** (Datei z. B. `design/Icon/v3/v3d.icon` öffnen): Hintergrund-Fill (Volltonfarbe/Verlauf, Verlaufsrichtung) im Fill-Bereich; pro Ebene Fill/Opacity/Blend-Mode je Darstellung (Dark, Mono) über das Plus bei Hover; Gruppen-Parameter Specular, Translucency, Shadow (neutral/chromatisch), Liquid Glass je Ebene ein/aus; Ebenenposition/-größe (Motiv skalieren/verschieben, optisch zentrieren); Ebenenreihenfolge (oben = vorn). Die Formen selbst sind SVGs unter `v3d.icon/Assets/` (`canopy.svg`, `handle.svg`) und können in einem Vektorprogramm überarbeitet und ersetzt werden; im JSON entsprechen die Fill-/Gruppenwerte `icon.json`.

## 7. Nicht geprüft

Icon-Composer-GUI-Ansicht, Clear-Darstellungen, `actool`-Kompilierung der v3-Pakete im Gesamtbuild, Homescreen/Gerät/Watch-Rundmaske, handgestaltete Dark/Tinted-Fills (ictool ignoriert `fill-specializations` sichtbar), Kontrastmessung, Nutzerumfrage, Apples Design-Resources-Raster-Vorlagen, WWDC26-Material.

## 8. Runde 4 (3.11.2026): Recherche-Ergänzung und v4

Auftrag: v3 "schon gut"; v4 ohne Nutzervorgaben (weniger Farben/Elemente/kleine Elemente gelten nicht mehr), maßgeblich nur belegte Profiregeln. Pakete: `design/Icon/v4/v4a..v4d.icon`, Generator `generate_v4.py`, Render `render.sh`, Tafeln `make_overview.py` (Pillow nötig), `previews/overview.png`, `previews/overview-v3-v4.png`.

### Neue belegte Erkenntnisse (Quellen abgerufen 3.11.2026)

1. **Tiefe = Opazitätsvariation + überlappende gefüllte Formen** in Vordergrundebenen; Ebenen deckend importieren und Transparenz erst im Icon Composer setzen. [Apple HIG App icons, Änderungsprotokoll 8.6.2026/28.10.2026] <https://developer.apple.com/design/human-interface-guidelines/app-icons.md>
2. **Scharfe Kanten in Vordergrundebenen, keine weichen/ausgefransten Ränder** (sonst stimmen System-Specular und -Schatten nicht): ein "Sweep mit weichen Rändern" ist deshalb falsch; Verlauf nur gestuft (mehrere scharf begrenzte, teiltransparente Keile). [HIG, ebd.]
3. **Hintergrund:** einfacher Voll- oder Verlaufsfill im Composer, "bestehe gut gegen Systembeleuchtung"; importierte Hintergründe vollflächig und deckend. [HIG, ebd.]
4. **WWDC26-Lab "Icon Composer for Beginners" (Session 8012)** existiert (im v3-Stand als "nicht gefunden" geführt): iOS-27-Rendering mit schärferem Specular (Optionen automatic/inside/outside), Refraktions-Regler, **reduzierte Translucency** (wird beim Öffnen alter Dateien nicht automatisch angepasst, pro Icon prüfen), Blend-Modes inkl. plus lighter/darker, "automatic gradients" aus einer Markenfarbe; häufigste Fehler: **zu viel Komplexität** (Refraktion reagiert auf Anzahl/Größe/Überlappung der Formen) und **Kleingrößen nicht prüfen**; überlappende Formen als getrennte Ebenen schneiden, damit eine hinter der anderen liegt. <https://developer.apple.com/videos/play/wwdc2026/8012/> (Zusammenfassung der Seite; automatisches Transkript)
5. **Tinted/Mono:** Ein Grau-Annotation-Satz trägt Clear und alle Tint-Modi; tiefe Dunkelwerte + helle Lichter für Dynamik; **ein Teil des Vordergrunds weiß/nahezu weiß**; auch helle Tints bedenken; Clear-Glas ist fest (reagiert nicht auf den Transparenzregler). [WWDC26 8012; WWDC25-361-Notizen <https://wwdcnotes.com/documentation/wwdc25-361-create-icons-with-icon-composer/>]
6. **Praxis (Fremdquelle, 16.7.2025):** Monochrom-Helligkeit wird aus den Default-Farben abgeleitet und kann zu dunkel/grau ausfallen -> pro Ebene eigenen Mono-Fill setzen; SVG-Export aus Affinity enthielt ein Artboard-`rect`, das den Glas-Glanz verhinderte (SVG im Editor prüfen); Glas und Blur schließen sich je Ebene aus; Hintergrund in den Dokumenteinstellungen statt als Ebene spart Ebenen. <https://fatbobman.com/en/posts/icon-composer-tackling-challenges/>
7. **Ebenenlimit:** Apple nennt bis zu 4 Gruppen (Tiefenstufen) [WWDC25-361]; Drittquelle nennt "4 Ebenen"; unsere v4-Pakete nutzen 3 Gruppen mit bis zu 3 Ebenen je Gruppe und werden von ictool 27.2 ohne Warnung gerendert (Limit in der GUI nicht geprüft).
8. **Dateiformat (Fremdquelle, kein Apple-Schema):** Specialization-Arrays `<attr>-specializations` mit `appearance` = (ohne)/`light`/`dark`/`tinted`; Beispiel-`icon.json` aus Dritt-Repo <https://github.com/peterpoliwoda/icon-composer-template> (Fixtures, Zugriff 3.11.2026); Beschreibung <https://peterpoliwoda.me/untitled-2/>.
9. **Wetter-Konventionen / Palette:** keine belastbare Primärquelle zur Icon-Gestaltung von Apple Wetter, Carrot, Dark Sky, Weather Strip gefunden (Suchen lieferten nur Produkt-/Firmengeschichte). Verbale Einordnung bleibt Annahme: Kategorie = Sonne/Wolke/Tropfen auf Blau; Abhebung über Silhouette und Akzent. "Reiche" Paletten und Bézier-Handwerk (Knotenzahl, glatte vs. Eckknoten): keine Apple-Vorgabe gefunden; eigene Praxis (Kubische Segmente mit tangentenstetigen Anschlüssen, Spitzen per Konturrundung statt Spitzecke) ist Annahme.

### Technischer Befund: Dark/Tinted-Fills (belegt durch Tests in ictool 27.2 und actool)

- **Ursache der "ignorierten" Dark-Fills in v2/v3:** Die Pakete enthielten neben `fill-specializations` zusätzlich ein Top-Level-`"fill"` bzw. ein Ebenen-`"fill"`. Dann ignoriert ictool die Specializations (Dark zeigt System-Dunkelgrund 23/23/23 bzw. die Standardfarbe). **Ohne Basis-`fill`**, nur mit `fill-specializations: [{"value":X},{"appearance":"dark","value":Y},{"appearance":"tinted","value":Z}]`, wirken Dark-Hintergrund (Verlauf), Dark-Ebenenfarbe und Tinted-Grauwert pro Ebene sichtbar (Pixeltest Hintergrund/Ebene: grün/gelb wie gesetzt). `opacity-specializations` werden mitgeführt.
- `actool` (Xcode 27.2) kompiliert das Test-Paket (nur Specializations) ebenfalls; im Katalog stehen `UIAppearanceDark`/`ISAppearanceTintable`-Icon-Images. Für das **v3-artige Paket mit Basis-`fill`** lieferte `assetutil` nur Default-Farbe plus `system-dark`-Gradient, keine eigene Dark-Farbe. Nicht geprüft: pixelgenaue Dark-Rendition aus `Assets.car` auf Gerät/Simulator.
- ictool-Option `--design-generation 26|27` existiert (Vergleich 26/27 nicht durchgeführt).
- Konsequenz für das Produktions-Icon: Bei Übernahme eines v4-Entwurfs `icon.json` unverändert verwenden (kein Basis-`fill` ergänzen). Das aktuelle `AppIcon.icon` enthält vermutlich ebenfalls Basis-Fills; Dark dort nur als Systemvorgabe.

### Die Konzepte (alle: Hintergrundverlauf, 3 Gruppen, getrennte Ebenen mit Opazität, handgesetzte Dark- und Tinted-Fills)

| Konzept | Idee | Konstruktion | Farben |
|---|---|---|---|
| v4a Schirm (aus v3d veredelt) | Gewölbter Schirm, 3 Bahnen, runde Spitzen, Griff hinter dem Dach, Regentropfen als Hinterebene | Rippen/Saum kubisch bzw. quadratisch; Spitzenrundung per Rundkontur; Griff-Stroke; Tropfen kubisch mit konkaven Flanken | Cyan->Blau, Amber (+Orange für Seitenbahnen), Weiß, Hellblau |
| v4b Radar + Wolke (aus v3a) | Radarscope: gestufte Ringscheiben, weißer Sweep aus 3 gestuften Keilen, Regenecho als amberne Wolke, weißer Ortspunkt | Keile als Kreissektoren (scharfe Kanten, statt weichem Rand gestufte Deckkraft); Echo kubisch mit 3 Lappen | Blau, Weiß, Amber |
| v4c Regenwolke | Zwei Wolken (hinten blass, vorn weiß glasig), drei Tropfen vorn | Wolkenkontur aus Hand-Kubiksegmenten mit Kerben; Tropfen kubisch | Violett-Indigo, Weiß, Hellblau, Amber |
| v4d Tropfen-Pin | Großer Tropfen mit Ort-Loch, zwei Wellenscheiben dahinter | Tropfenkurve kubisch + Kreisbogen; Rundung der Spitze quadratisch | Türkis->Blau, Weiß, Tiefblau |

Iterationen: v4a (1) Schirm zu flach und Griff vor dem Dach, Ferrule abgelöst -> höhere Kuppel, Halbbreite/Scheitel parametrisiert, Griff in die hintere Gruppe; (2) Hinterwolke wirkte als Fleck -> verworfen. v4b (1) gelb/amber Sweep auf Blau mischte grau, Zelle verdeckte den Sweep -> weißer gestufter Sweep, Zelle als amberne Form; (2) "organisches" Echo aus Catmull-Rom-Punkten wirkte wie Plektrum/Quadrat -> verworfen, Lappenform behalten; ein verschachtelter Kern (Wolke in Wolke) -> verworfen. v4c (1) rechter Lappen mit "Ohr" -> rundere Schulter. v4d (1) gelber Ort-Kreis in weißem Tropfen las sich als Spiegelei -> Loch in Tiefblau, Amber entfernt.

### Empfehlung

Reihenfolge gegen die Checkliste (Abschnitt 2) und die Runde-4-Quellen: **1. v4d Tropfen-Pin** (ein dominantes Symbol, Silhouette bei 29 px klar, hohe Hell-Dunkel-Trennung, saubere Tiefe aus Wellen + Glas; liest sich als Regen plus Ort; verletzt aber die frühere Regel "mindestens ein Akzent" - nur zwei Farbtöne, bei Bedarf Welle in Amber testen). **2. v4a Schirm** (Favoritenlinie v3d, deutlich reicher und handwerklich besser, aber mehr Elemente; Kleingrößen: Tropfen verschwinden bei 29 px, Schirm bleibt lesbar). v4b hat die beste Funktionsmetapher (Radar), ist aber bei 29 px am wenigsten lesbar und der Sweep wird dort zur Kerbe; v4c ist am nächsten am Kategorie-Klischee (Apple-Wetter-Nähe), handwerklich solide. Ehrlich: Kein Entwurf ersetzt Designerarbeit; Bewertung ist meine eigene Sichtung, **keine Nutzer-/Gerätetests**.

### Weiterhin Handarbeit im Icon Composer (Dateien/Parameter)

- Specular je Gruppe (automatic/inside/outside), Refraktion, Blur, Translucency (reduziert in iOS 27, pro Icon prüfen; v4 setzt `translucency.value` nur grob, z. B. 0,25 bis 0,5 in den Hinter-/Wolkenebenen), Schatten neutral/chromatisch: `v4?.icon/icon.json` -> `groups[].specular|shadow|translucency` bzw. in der GUI.
- Blend-Mode (plus lighter) für Ringscheiben (v4b, v4d) ausprobieren; derzeit nur Normal + Opazität.
- Feinzeichnung der Silhouetten im Vektorprogramm (Knoten glätten, Kerben der Wolke, Rippenabstände): `Assets/*.svg` ersetzen; Formen sind aus Generatorcode, nicht von Hand gezeichnet.
- Mono/Tinted: Grauwerte in `fill-specializations` (appearance `tinted`) auf Gerät/Wallpaper abstimmen; Dark-Farben gegen Systemicons prüfen.
- Watch-Rundmaske, Clear-Darstellungen, Gerät/Home-Screen-Nachbarschaft, 3-Personen-Test.

### Nicht geprüft (Runde 4)

Icon-Composer-GUI (Ebenenlimit, Vorschau), Clear-Rendition, Gerät/Simulator/Watch, `actool`-Gesamtbuild der v4-Pakete (nur Testpaket kompiliert), Dark aus `Assets.car` pixelgenau, `--design-generation 26`-Vergleich, Kontrastmessung, Nutzerumfrage, Weather-Konkurrenzbilder (bewusst nicht kopiert).

## 9. Gesamtübersicht aller Entwürfe (3.11.2026)

`design/Icon/overview/`: `all-icons.png` (4800 px, alle Icons aktuell/v2-v5: Default groß, Dark/Tinted klein, Größenvergleich 120/60/29, Dark-Streifen) und `index.html` (eine Datei, Bilder 512 px als base64, Umschalter Default/Dark/Tinted, Klick-Vergrößerung, Homescreen-Simulation hell/dunkel/getönt). Beides erzeugt von `build_overview.py` (Pillow nötig, nicht im Repo installiert). Vorschauen: `current/previews/` (produktives Icon, `current/render.sh`), v2 bis v5 je `previews/`. v5 wurde jetzt gerendert; Dark-Regel aus Abschnitt 8 bestätigt (v5-Pakete mussten dafür auf reine Specializations umgestellt werden, siehe [icon-v5.md](icon-v5.md)).
