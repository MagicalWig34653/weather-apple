# App-Icon: zwei vollflächige Kartenentwürfe

Stand: 28. Oktober 2026. Nutzerkorrektur: eine vollflächige Karte ohne Rand, darüber Wolke beziehungsweise farbige Regen-/Radarflächen. Die vorherige gefaltete Karte wurde verworfen und darf nicht integriert werden. Endgültiger Name und Markenentwurf bleiben offen.

## Beurteilbare Varianten

Beide neuen Entwürfe verwenden dieselbe eigene abstrakte Kartenbasis: wenige helle Straßen, Grünflächen und ein cyanfarbener Fluss. Die Karte füllt das gesamte quadratische 1024er-Canvas bis an den Rand. Es gibt keinen aufgezeichneten Rahmen, keine gefaltete Karte und keine vorgerenderte App-Maske. Die sichtbare Rundung und Außenbeleuchtung der PNG-Vorschau kommen ausschließlich vom Apple-Werkzeug.

| Variante | Bearbeitbares Original | Default-Vorschau |
|---|---|---|
| A — Karte mit Wolke und drei Regenstrichen | [Cloud.icon](../design/Icon/Cloud.icon) | [1024-Pixel-Vorschau](../design/Icon/Previews/cloud-default.png) |
| B — Karte mit transparenten Radarflächen | [Radar.icon](../design/Icon/Radar.icon) | [1024-Pixel-Vorschau](../design/Icon/Previews/radar-default.png) |

Variante B verwendet Blau und Grün mit einem kleinen gelben Niederschlagskern. Straßen bleiben unter den transparenten Regenflächen erkennbar. Die Motive sind frei entworfen; keine echten Kartenscreenshots, Apple-Kartenkacheln, fremden Marken oder externen Bild-Assets wurden übernommen.

**Stand der Auswahl:** Der Nutzer hat Variante B (Radar) ausgewählt. Variante A bleibt als Vergleichsentwurf dokumentiert. Noch keine neue Variante in das App-Target integriert. Das ältere `Weather/Resources/Icon/AppIcon.icon` ist weiterhin der verworfene technische Ausgangsentwurf und darf nicht versehentlich verwendet werden.

## Echtes Icon-Composer-Format und Bearbeitung

Die beiden `.icon`-Verzeichnisse sind native Dokument-Packages mit `icon.json` und einer SVG-Datei unter `Assets/`. Apples `ictool` liest und rendert diese Packages erfolgreich. Es sind keine umbenannten PNG-Dateien.

Jedes Package enthält bewusst **eine** importierte skalierbare SVG-Komposition als aktiven Icon-Composer-Layer. Die SVG besitzt benannte Gruppen wie `map-base`, `cloud`, `rain` beziehungsweise `radar-outer`, `radar-rain` und `radar-core`. Diese Komponenten bleiben im Vektoreditor oder im SVG-Quelltext editierbar; sie werden nicht als separat auswählbare native Composer-Layer ausgegeben. Der reproduzierbare Generator [generate.py](../design/Icon/generate.py) enthält die getrennten eigenen Vektorbausteine und erzeugt beide Dokumente. Die reine Kartenbasis liegt zusätzlich als [map-base.svg](../design/Icon/map-base.svg) vor.

Diese Aufteilung umgeht eine beobachtete Werkzeuggrenze des vorherigen Drei-Layer-Versuchs: Mehrere getrennte SVG-Layer wurden bei wiederholten Default-/Dark-CLI-Aufrufen gelegentlich unvollständig gerendert. Für die neue Ein-Layer-Komposition wurden beide Default-Renderings wiederholt und waren jeweils byteidentisch. Eine allgemeine Garantie für andere Dokumente oder Werkzeugversionen folgt daraus nicht.

## Ausgeführte Prüfungen

Icon Composer / `ictool` 27.1 wurde direkt verwendet, ohne GUI-Automation und ohne zusätzliche kostenpflichtige Werkzeuge.

- JSON der beiden nativen Dokumente und SVG-XML syntaktisch geprüft.
- Eigene Vektorquellen füllen das 1024 × 1024-Canvas; keine vorgerenderte Squircle-Maske.
- Beide Varianten als iOS Default, Dark und TintedDark mit 1024 × 1024 Pixeln gerendert; Exit-Code 0 und korrekte PNG-Abmessungen.
- Beide Varianten zusätzlich mit 60 × 60 Pixeln gerendert.
- Alle acht Vorschauen visuell geprüft. Wolke/Regen und Radarflächen bleiben vorhanden; in der Kleinansicht ist Wolke/Regen schneller als Einzelmotiv erkennbar, während die Radarvariante den App-Fokus direkter zeigt. Die Beispiel-Tönung reduziert den Kontrast der Flächen; sie ist kein final annotierter Dark-/Mono-Entwurf.
- Default-Renderings je Variante wiederholt: jeweils byteidentisch, keine fehlenden Motivteile.
- Strukturierte lokale Prüfergebnisse: [validation.json](../design/Icon/validation.json).
- `git diff --check` ohne Fehler. Keine App-Builds, Signing-Schritte oder Uploads durch diesen Designauftrag.

Die automatische Dark-Rendition bleibt bei diesen Quellen farblich nahe am Default. Das wird ausdrücklich als aktueller Entwurfsstand behandelt; eine separat gestaltete dunkle Palette ist noch nicht behauptet.

## Reproduktion

Im Repository-Verzeichnis ausführen. Der Werkzeugpfad wird aus dem aktiven Xcode ermittelt; keine rechnerbezogenen Projektpfade werden benötigt.

```sh
python3 design/Icon/generate.py
icon_tool="$(xcode-select -p)/../Applications/Icon Composer.app/Contents/Executables/ictool"
"$icon_tool" design/Icon/Cloud.icon \
  --export-image --output-file design/Icon/Previews/cloud-default.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
"$icon_tool" design/Icon/Radar.icon \
  --export-image --output-file design/Icon/Previews/radar-default.png \
  --platform iOS --rendition Default --width 1024 --height 1024 --scale 1
```

Für Dark `--rendition Dark` verwenden. Für die dokumentierte Beispiel-Tönung `--rendition TintedDark --tint-color 0.52 --tint-strength 0.8`; Kleinansicht mit `--width 60 --height 60`. Vorschauen sind abgeleitete Artefakte; die SVG- und `.icon`-Quellen bleiben maßgeblich.

## Übergabe an Integration

Das vom Nutzer ausgewählte Package `Radar.icon` vollständig als `Weather/Resources/Icon/AppIcon.icon` übernehmen; nur ein aktives App-Icon-Package im App-Target verwenden. Der App-Icon-Name muss zum Dateinamen passen: `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon`. Die Entwurfsvarianten unter `design/` liegen absichtlich außerhalb der App-Quellen und sollen nicht zusätzlich ins App-Bundle gelangen.

Der Integrations-Agent besitzt Projektgenerator und Buildslot. Er muss die tatsächliche `.icon`-/Asset-Verarbeitung, das fertige App-Bundle und den nächsten Release-Export prüfen. Die gültige Dokument-/Renderprüfung hier ersetzt keinen App-Build oder App-Store-Uploadnachweis. Projekt- und Buildsettings wurden in diesem Auftrag nicht geändert.

## Primärquellen

Am 28. Oktober 2026 erneut geprüft:

- [Apple: Creating your app icon using Icon Composer](https://developer.apple.com/documentation/xcode/creating-your-app-icon-using-icon-composer)
- [Apple: Icon Composer](https://developer.apple.com/icon-composer/)

Apple beschreibt den Import organisierter Artwork-Layer, die Anpassung verschiedener Darstellungsmodi und die direkte Xcode-Integration des Icon-Dateityps. Die konkrete JSON-Struktur wurde anhand der mitgelieferten Werkzeuge und des vorhandenen geprüften Template-Aufbaus verwendet; sie wird nicht als dauerhaft öffentliche Schema-API behauptet.
