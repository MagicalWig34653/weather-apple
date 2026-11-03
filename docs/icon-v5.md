# App-Icon Runde 5

Stand: 3. November 2026. Drei eigenständige Entwürfe, keine Auswahl oder App-Integration. Auftrag: freie Gestaltung nach belegten professionellen Regeln; v3 gefiel dem Nutzer bereits, v2/v4 nicht. Frühere persönliche Vorgaben zu Farb- oder Elementanzahl gelten hier nicht. Ausführung durch Codex (GPT-6-basierte Agentenrolle; genaue Modellvariante in dieser Umgebung nicht verlässlich ausgewiesen), ohne Bildgenerierungsmodell und ohne Teilagenten gemäß diesem Auftrag.

Arbeitsstand und Übergabe stehen wegen der ausdrücklich beschränkten Schreibfreigabe nur hier; `status.md`, `decisions.md` und der gemeinsame Guide wurden nicht verändert. Fremde lokale Änderungen waren beim Start vorhanden und wurden nicht bearbeitet.

## Konzepte

Die [flache Übersicht](../design/Icon/v5/overview-flat.svg) zeigt die Geometrie bei 300, 120, 60 und 29 px, ohne Systemmaske oder simulierte Glaseffekte. Sie ersetzt keine Apple-Vorschau.

| Paket | Idee und Gestaltung | Bezug zum Guide / Primärquelle |
|---|---|---|
| [v5a](../design/Icon/v5/v5a.icon) – Schirm bereit | Neu gezeichnete, leicht geneigte bernsteinfarbene Schirmhaube auf Petrol, heller kräftiger Griff. Flache konkave Unterkante statt der stark gelappten v3-Haube; zwei Gruppen mit geringer Transluzenz der Haube. | Ein dominantes Regenmotiv; frontal, kräftige Formen, getrennte Farben und Tiefe (Guide 1/7/9; WWDC220/361). |
| [v5b](../design/Icon/v5/v5b.icon) – Regenfront | Asymmetrische türkisfarbene Niederschlagskontur, mintfarbene Innenzone und heller Kern auf Nachtblau. Drei ineinanderliegende Glasflächen statt konzentrischer Zielscheibe oder kleinteiliger Karte. | Überlappung hat inhaltliche Bedeutung und nutzt native Materialtiefe; Farben separat steuerbar (Guide 7/9/11; WWDC220/361). |
| [v5c](../design/Icon/v5/v5c.icon) – Schauer in Bewegung | Drei individuell gezeichnete, nach oben verjüngte Regenbahnen auf Violett; lange weiße Hauptbahn, mint- und lavendelfarbene Begleiter. Drei getrennte Gruppen. | Große, klare Formen und heller Hauptteil für Mono; Eigenständigkeit über Silhouette und Rhythmus (Guide 2/3/9; WWDC361). |

Gestalterische Präferenz: **v5a** wegen der direkten Regen-Assoziation; **v5b** bildet die Radar-Funktion am unmittelbarsten ab. Das ist eine Entwurfseinschätzung, kein Ergebnis eines Erkennungstests. v5c entwickelt die Bewegungsqualität von v3b weiter; v5a übernimmt die Schirmidee, aber nicht dessen SVG. Keine App-Funktionsliste im Motiv.

## Quellen und Abgrenzung

Am 3.11.2026 erneut gelesen: Transkripte [WWDC25-220](https://developer.apple.com/videos/play/wwdc2025/220/) und [WWDC25-361](https://developer.apple.com/videos/play/wwdc2025/361/). Sie belegen vereinfachtes flaches Artwork, kräftige gerundete Konturen, Systemmaterial statt eingebrannter Effekte, weiche Hintergrundverläufe, getrennte Farben/Ebenen und Prüfung verschiedener Darstellungen. Session 361 beschreibt maximal vier Gruppen, weiße Hauptformen für Mono und optische Anpassungen für Watch.

Die aktuelle [Apple HIG „App icons“](https://developer.apple.com/design/human-interface-guidelines/app-icons) wurde aufgerufen; der Volltext war hier wegen JavaScript bzw. nicht abrufbarer Markdown-Antwort nicht erneut lesbar. HIG-Aussagen deshalb nur nach dem bestehenden [Guide](icon-design-guide.md), nicht als neu vollständig verifiziert ausgegeben.

**Keine verbindlichen Apple-Regeln:** maximal drei Farben, mindestens 8–10 % Elementgröße, pauschales Verbot von Vordergrundverläufen oder Kategorie-Symbolen. Diese Einschränkungen des bisherigen Guides sind teils Praxisannahmen und werden nicht zum Auftrag erhoben. Konkret sind Palette, Neigung, Kurven und Materialwerte dieser Entwürfe eigene Designentscheidungen. Die Radarfarben sind keine DWD-Messskala; die Konturen zeigen keine echten Daten oder Nutzerorte.

## Technik und tatsächliche Prüfungen

- `generate_v5.py` erfolgreich ausgeführt: drei native Verzeichnispakete mit `icon.json`, insgesamt acht separat editierbare SVG-Assets; zwei/drei/drei Gruppen, 1024er-Canvas, Hintergrund-Fills als Verläufe. Quellen enthalten keine Systemmaske, Rasterbilder, Schatten, Glanzlichter oder Blur.
- `validate.py`: JSON/XML, vorhandene Asset-Referenzen, Canvas und Gruppenanzahl geprüft; [validation.json](../design/Icon/v5/validation.json). Diese Strukturprüfung ist keine Apple-Schemavalidierung.
- Paketformat (korrigiert, siehe „Rendering“): nur `fill-specializations` (default/dark/tinted), kein Basis-`fill`. Die erste Gruppe ist wie in v3 die vorderste.
- `ictool --help` funktioniert. In der Codex-Sandbox scheiterte `ictool` (Exit 255); die Renderings entstanden später in einer anderen Sitzung (siehe „Rendering“).
- Keine lokalen Python-Rasterbibliotheken Pillow/CairoSVG vorhanden; keine Abhängigkeiten installiert. Flache SVG-Übersicht ist rein aus den Paketquellen abgeleitet.

**Nicht geprüft:** visuelle v5-Kleinansichten, tatsächliche Dark-/Mono-Farben, Clear, GUI-Öffnen, Materialanimation, Watch-Rundmaske, Wallpaper/Homescreen, Gerät, Nutzererkennungstest, `actool` oder App-Build. Die v3-Übersicht wurde vor dem Entwurf angesehen. Keine Änderungen am produktiven Icon, Projekt, App-Code oder v4; kein Build, Commit oder Push.

## Reproduktion und Handarbeit

Im Repository ausführen:

```sh
python3 design/Icon/v5/generate_v5.py
python3 design/Icon/v5/validate.py
zsh design/Icon/v5/render.sh
# Einzelentwurf: zsh design/Icon/v5/render.sh v5a
```

`render.sh` verwendet das `ictool` des aktiven Xcode, rendert sequenziell Default/Dark/TintedDark bei 1024 px und Default bei 120/60/29 px und stoppt bei Fehlern. Ausgabe ausschließlich unter `design/Icon/v5/previews/`. Generator erneut auszuführen überschreibt die erzeugten JSON-/SVG-Dateien; Änderungen deshalb in den Generator übernehmen.

Nächster Schritt: Pakete in Icon Composer öffnen, Spezial-Fills gegebenenfalls in dessen GUI neu speichern und alle sechs Darstellungen kontrollieren. Danach Schirmgriff und Neigung optisch abgleichen, Konturabstände von v5b in klein prüfen, Regenbahnen von v5c auf Verwechslung mit einem abstrakten Logo testen. Materialwerte am Bildschirm feinjustieren; Watch-Kreis und echte Wallpaper testen. Vor Auswahl unbeschrifteten Erkennungstest durchführen. Keine dieser Handprüfungen wird hier als erledigt behauptet.

## Rendering (3.11.2026, ictool Xcode 27.2, iOS)

`zsh design/Icon/v5/render.sh` lief erfolgreich; Ausgaben in `design/Icon/v5/previews/` (Default/Dark/Tinted 1024 px, Default 120/60/29; Namensschema wie v4: `v5a-default.png`, `-dark`, `-tinted`, `-default-120`). Alle Entwürfe wurden mit dem Read-Werkzeug gesichtet (keine Gerätetests).

**Paketformat-Korrektur:** Die Pakete enthielten Basis-`fill` (Root und Ebene) neben `fill-specializations` und `mono`-Einträge. Pixeltest vor der Korrektur (v5a): Dark-Hintergrund = System-Dunkelgrund (22/23/22), Ebenenfarbe unverändert. Nach der Korrektur in `generate_v5.py` (Basis-`fill` entfernt, `mono` -> `tinted` mit `extended-gray`, `opacity-specializations` ergänzt; `validate.py` angepasst): Dark zeigt eigene Hintergrundverläufe und Ebenenfarben, Tinted eigene Grauwerte. Motiv und Geometrie unverändert.

**Bewertung (eigene Sichtung):**
- **v5a Schirm:** klare Silhouette, bei 29 px als Schirm lesbar (Haube amber, Griff weiß). Dark gut (hell auf dunklem Petrol). Tinted: Haube und Griff nahezu gleiche Farbe, die Trennung entsteht nur über die Fuge; lesbar, aber flacher. Nähe zu v3d (gleiche Idee), formal ruhiger.
- **v5b Regenfront:** Default stimmig (drei Stufen, heller Kern), bei 120/60 px noch erkennbar, bei 29 px nur ein Fleck mit hellem Punkt (Funktion nicht lesbar). Tinted: drei fast gleiche Grautöne, Staffelung kaum sichtbar, flach. Schwächster Kandidat in Klein- und Tinted-Ansicht.
- **v5c Regenbahnen:** stärkste Lesbarkeit bei 29 px, kräftiger Kontrast in allen Modi; Dark und Tinted tragen. Nähe zu v3b (bekanntes „Slashes“-Risiko, Wetterbezug nur über Kontext).
- Rendering-Auffälligkeiten: keine fehlenden Ebenen oder Rendering-Fehler; in allen Modi sind alle Ebenen vorhanden. Der dünne Glasrand der Systemmaske ist sichtbar, kein Problem des Pakets.

**Übersicht aller Runden:** `design/Icon/overview/all-icons.png` und `index.html`, siehe [Leitfaden Abschnitt 9](icon-design-guide.md).
