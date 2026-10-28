# Direkte numerische Punktabfrage des DWD-WMS

Geprüft: 28. Oktober 2026, Antwortzeitstempel etwa 15:22 UTC. Unabhängige, eng begrenzte Agent-Prüfung. Drei GetFeatureInfo-Requests; keine Last-/Verfügbarkeitsstudie.

## Ergebnis

Der offizielle WMS liefert am Layer `dwd:Niederschlagsradar` per GetFeatureInfo numerische JSON-Properties mit Zeit- und Laufbezug, nicht nur Bildfarben. Ein Intervallrequest liefert in einer Antwort 25 zeitlich getrennte Features. Damit ist ein sehr kleiner direkter Datenabruf grundsätzlich demonstriert.

Ein dritter Kontrollrequest an einer anhand der Rohdaten ausgewählten nassen Zelle liefert positive und zeitlich unterschiedliche Werte. Der Analysewert passt zur fünfminütigen Rohdaten-Akkumulation, obwohl der Layer-Abstract mm/h nennt. **Die JSON-Einheit darf deshalb nicht ungeprüft als mm/h interpretiert werden.** Ein unabhängiger Rohdatenvergleich weiterer Vorhersagezeitpunkte und die Sentinel-Semantik fehlen noch. Der Propertyname `RV_ANALYSIS` allein beweist keine Analyse-/Vorhersagesemantik.

## Primärquelle: Capabilities

[Offizielle DWD-WMS-Capabilities](https://maps.dwd.de/geoserver/ows?service=WMS&version=1.3.0&request=GetCapabilities). Ausgewertet wurde der vom koordinierenden Agent bereits heruntergeladene Snapshot; SHA-256 `69d2058d04b06deee1218dbc6fd237805c4bb1c422426dd1db9ecb09c02926eb`.

- Exakter Name im geprüften Capabilities-Dokument: `Niederschlagsradar`; Requests mit Namespace `dwd:Niederschlagsradar` waren erfolgreich.
- `queryable="1"`.
- Abstract bezeichnet den Layer als Radar und Vorhersage, Alias des RV-Produkts, mit 1-km-Auflösung, fünfminütiger Auflösung und mm/h. Das ist eine Anbieterbeschreibung; die Einheit der zurückgegebenen Property wurde noch nicht gegen Rohdaten verifiziert.
- Dimension `time`: `2026-10-25T00:00:00.000Z/2026-10-28T15:55:00.000Z/PT5M`.
- Dimension `REFERENCE_TIME`: explizite Liste von Laufzeitpunkten; Default `2026-10-28T13:55:00.000Z`.
- GetFeatureInfo wirbt unter anderem `application/json`, `text/plain` und GML aus.

## Reproduzierbare Live-Abfragen

Gemeinsame Parameter:

```text
SERVICE=WMS
VERSION=1.3.0
REQUEST=GetFeatureInfo
LAYERS=dwd:Niederschlagsradar
QUERY_LAYERS=dwd:Niederschlagsradar
STYLES=
CRS=EPSG:4326
WIDTH=3
HEIGHT=3
I=1
J=1
FORMAT=image/png
INFO_FORMAT=application/json
DIM_REFERENCE_TIME=2026-10-28T13:55:00.000Z
```

Die Bounding Box folgt hier WMS 1.3 mit EPSG:4326 in Breite/Länge. Die Wahl eines kleinen symmetrischen 3×3-Ausschnitts vermeidet einen versehentlichen Bildeckpunkt. Der exakte Zuordnungsfehler zur nativen RV-Zelle ist noch nicht gemessen.

1. [Einzelzeitpunkt am öffentlichen Beispielpunkt Berlin](https://maps.dwd.de/geoserver/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=dwd%3ANiederschlagsradar&QUERY_LAYERS=dwd%3ANiederschlagsradar&STYLES=&CRS=EPSG%3A4326&BBOX=52.49%2C13.39%2C52.51%2C13.41&WIDTH=3&HEIGHT=3&I=1&J=1&FORMAT=image%2Fpng&INFO_FORMAT=application%2Fjson&TIME=2026-10-28T14%3A00%3A00.000Z&DIM_REFERENCE_TIME=2026-10-28T13%3A55%3A00.000Z): BBOX `52.49,13.39,52.51,13.41`, TIME `2026-10-28T14:00:00.000Z`. HTTP 200, 331 Antwortbytes, etwa 0.19 s nach aufgebauter Erreichbarkeit. Ein Feature mit `RV_ANALYSIS=-9.999999310821295E-4`, `TIME=2026-10-28T14:00:00Z`, `REFERENCE_TIME=2026-10-28T13:55:00Z`.
2. [Zwei-Stunden-Intervall am öffentlichen Beispielpunkt Hamburg](https://maps.dwd.de/geoserver/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=dwd%3ANiederschlagsradar&QUERY_LAYERS=dwd%3ANiederschlagsradar&STYLES=&CRS=EPSG%3A4326&BBOX=53.54%2C9.98%2C53.56%2C10.00&WIDTH=3&HEIGHT=3&I=1&J=1&FORMAT=image%2Fpng&INFO_FORMAT=application%2Fjson&TIME=2026-10-28T13%3A55%3A00.000Z%2F2026-10-28T15%3A55%3A00.000Z%2FPT5M&DIM_REFERENCE_TIME=2026-10-28T13%3A55%3A00.000Z): BBOX `53.54,9.98,53.56,10.00`, TIME `2026-10-28T13:55:00.000Z/2026-10-28T15:55:00.000Z/PT5M`. HTTP 200, 5012 Antwortbytes, etwa 2.77 s. `numberReturned=25`, jeweils fünf Minuten Abstand mit derselben Referenzzeit. Alle 25 Features hatten ebenfalls `RV_ANALYSIS=-9.999999310821295E-4`.

3. [Nasse Kontrollzelle aus dem RV-Rohdatenlauf 15:15 UTC](https://maps.dwd.de/geoserver/ows?SERVICE=WMS&VERSION=1.3.0&REQUEST=GetFeatureInfo&LAYERS=dwd%3ANiederschlagsradar&QUERY_LAYERS=dwd%3ANiederschlagsradar&STYLES=&CRS=EPSG%3A4326&BBOX=53.550119%2C6.730872%2C53.570119%2C6.750872&WIDTH=3&HEIGHT=3&I=1&J=1&FORMAT=image%2Fpng&INFO_FORMAT=application%2Fjson&TIME=2026-10-28T15%3A15%3A00.000Z%2F2026-10-28T17%3A15%3A00.000Z%2FPT5M&DIM_REFERENCE_TIME=2026-10-28T15%3A15%3A00.000Z): BBOX `53.550119,6.730872,53.570119,6.750872`, TIME `2026-10-28T15:15:00.000Z/2026-10-28T17:15:00.000Z/PT5M`, DIM_REFERENCE_TIME `2026-10-28T15:15:00.000Z`. HTTP 200, 5004 Antwortbytes, etwa 3.44 s, 25 Features. Werte: 15:15 → `1.873999834060669`, 15:20 → `1.3149998188018799`, 15:25 → etwa `-0.001`. Die Zelle wurde vom koordinierenden Agent im HDF5-Analyseraster als row297/col320 mit Rohwert1875 bestimmt; aus gain≈0.001 und offset≈−0.001 folgt **1.874 mm/5min**. Der WMS-Wert stimmt damit überein; eine Interpretation dieses Zahlenwerts als mm/h würde im Vergleich um Faktor12 abweichen. Die Koordinate wurde anhand der Rohdatenprojektion abgeleitet; eine unabhängige Kontrolle der exakten Zellzuordnung bleibt ausstehend. Die 25 Features tragen durchgehend REFERENCE_TIME15:15 und verschiedene gültige Zeiten bis17:15.

Die ersten beiden Beispiele sind allgemein gewählte Stadtpunkte, keine Nutzerstandorte. Requests begrenzten Verbindungsaufbau auf fünf und Gesamtdauer auf zwanzig Sekunden. Ein vorheriger Capabilities-Abruf war langsam; Einzelmessungen sind keine Zusage für App-Antwortzeiten. Historische Beispiel-URLs können später außerhalb der Datenaufbewahrung liegen.

Die unveränderte JSON-Antwort des nassen Kontrollpunkts ist als [Fixture](wms-wet-point-response.json) archiviert; die Quelle und vollständigen Requestparameter stehen oben.

## Interpretation und offene Validierung

- **Bestätigt:** JSON-Ausgabe, numerische Property, explizite gültige Zeiten und Referenzzeiten, 25 Features in einem Intervallrequest und sehr kleines Antwortvolumen. Ein nasser Kontrollpunkt zeigt einen positiven Analysewert, der zur Rohdaten-Akkumulation passt, und davon abweichende Werte zu zukünftigen Gültigkeitszeiten.
- **Plausible Hypothese:** Der leicht negative Wert könnte durch ungefilterte Transformation eines Undetect-Rohwerts entstehen. Die separat untersuchte HDF5-Datei hat gain≈0.001, offset≈−0.001 und undetect=0. Diese Rohdateneigenschaft beweist die WMS-Abbildung nicht.
- **Offen:** Liefert `RV_ANALYSIS` für zukünftige Gültigkeitszeiten tatsächlich die korrekten Nowcast-Zellen? Mit nassem Kontrollpunkt und Rohdatenvergleich für 0/+5/+60/+120 Minuten prüfen. Ein Einheitentest muss insbesondere mm/5min (ACRR im Rohprodukt) gegen die beworbenen mm/h des Layers unterscheiden.
- **Offen:** Sentinelwerte für NoData und Undetect, außerhalb der Abdeckung sowie Verhalten bei nicht vorhandenem Lauf/Zeitpunkt. Fehlende oder negative Werte vorerst ausschließlich als unbekannt behandeln.
- **Offen:** Liefert `DIM_REFERENCE_TIME` zuverlässig genau den gewählten Lauf oder können Ersatz-/Nearest-Matches auftreten? Antwort-Referenzzeit immer kontrollieren.
- **Aktualitätsrisiko:** Default-Laufzeit 13:55 UTC im Capabilities-Snapshot gegenüber Antwortzeit etwa15:22 UTC war rund87 Minuten alt. Der dritte Request konnte trotzdem gezielt den neueren Lauf15:15 abfragen. Capabilities können also gegenüber den tatsächlich abfragbaren Läufen zurückliegen; Ursache/Cacheverhalten ist ungeprüft. Datenalter und verbleibender Horizont aus der Antwort berechnen, nicht allein aus dem Capabilities-Default.
- **Nächster günstiger Schritt:** Den positiven Kontrollpunkt zu +5/+60/+120 Minuten mit dem bereits geladenen Rohdatenlauf vergleichen und die WMS-Sentinel-/Einheitensemantik anhand weiterer DWD-Quellen absichern. Erst danach den Produktdatenweg und die Transformation festlegen. Die direkte Punktserie ist technisch nachgewiesen; vollständige fachliche Validierung und Geräteprüfung stehen aus.

## Ergänzung: Rohdatenvergleich abgeschlossen

Nach Fertigstellung der unabhängigen Abfrageprüfung hat die koordinierende Instanz alle25WMS-Werte mit dem vorhandenen RV-Lauf für Pixel297/320 verglichen: durchgehend Übereinstimmung zu `raw * gain + offset` mit absoluter Toleranz1e-6, auch +5/+60/+120Minuten. Siehe `wms-raw-comparison.json` und die vierte Stichprobe in `rv-sample.json`. Damit ist die oben zunächst offene Forecast-Wertezuordnung für diesen einen Kontrollpunkt bestätigt. Allgemeine Georeferenzierung, NoData und weitere Zellen bleiben offen.
