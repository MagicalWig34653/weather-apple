# DWD-Datenvalidierung — erster realer Lauf

Abruf/Prüfung: 28. Oktober 2026. Reale Abrufe, kein vollständiger Machbarkeitsnachweis für iOS.

## Primärquellen

- WMS-Metadaten: https://maps.dwd.de/geoserver/dwd/wms?service=WMS&request=GetCapabilities&version=1.3.0
- RV-Verzeichnis: https://opendata.dwd.de/weather/radar/composite/rv/
- Aktueller Lauf: https://opendata.dwd.de/weather/radar/composite/rv/composite_rv_LATEST.tar
- RV-Produktbeschreibung: https://www.dwd.de/DE/leistungen/radarprodukte/radarkomposit_rv_hdf5.pdf?__blob=publicationFile&v=3

Die PDF wurde in der Suche gefunden, der direkte Abruf im Webtool lieferte403. Produktdetails unten wurden aus dem realen Archiv ausgelesen, nicht ausschließlich aus einem Suchauszug übernommen. Vollständige Lizenz-/Attributionsprüfung steht noch aus.

## Direkt bestätigte Rohdatenbefunde

- Erfolgreicher Abruf des RV-Laufs2026-10-28 15:15UTC: 3921920Bytes, SHA256 `4176fe903034b4df16e9f6a6ffa380946becc19110d2e479364f894592ef8087`.
- 25 HDF5-Dateien, Vorlauf0 bis120Minuten in5-Minuten-Schritten; HDF5-Dateigrößen zusammen 3898055Bytes.
- Rasterform1200Zeilen ×1100Spalten, uint32; ODIM-quantity ACRR.
- Analyseintervall15:10–15:15UTC. Jede Datei enthält eigene Intervallzeiten; nicht bloß aus dem Namen ableiten.
- gain≈0.001 und offset≈−0.001. Sonderwerte undetect=0 und nodata=4294967295 vor der linearen Umrechnung behandeln. Fehlende Werte nicht als trocken ausgeben.
- Projektion und Zellweite stehen im HDF5-Header. Geographische Zuordnung, Orientierung und Randfälle sind noch nicht unabhängig validiert.
- Vier feste Pixelindizes pro Frame ausgelesen; Ergebnisse und Metadaten in `rv-sample.json`. Dies sind keine Nutzerstandorte und noch keine validierten Ortsprognosen.

## Aufwand und Grenzen

Der lokale Python-Forschungsdurchlauf brauchte 0.787s; gemeldeter Prozess-Spitzenspeicher 396607488Bytes einschließlich Python/HDF5-Laufzeit. Der Wert ist kein isolierter Parserbedarf und keine Aussage über Swift oder iPhone-Energieverbrauch. Ein Lauf reicht nicht als allgemeine Bandbreitenmessung. Keine Datenarchive oder virtuellen Umgebungen ins Repo aufnehmen.

Der direkte WMS-Metadatenabruf dauerte bei diesem Versuch63.5s, der RV-Download3.2s. Keine Verfügbarkeitsgarantie daraus ableiten; künftig begrenzte Abrufe und geeignete Fehlerzustände vorsehen.

## Reproduktion

Voraussetzung: `uv` und Python3.13. Keine App-Laufzeitabhängigkeit von Python vorgesehen.

```sh
curl --fail --max-time 30 --output /tmp/weather-rv.tar 'https://opendata.dwd.de/weather/radar/composite/rv/composite_rv_LATEST.tar'
uv run tools/inspect_rv.py /tmp/weather-rv.tar --output /tmp/weather-rv-report.json
```

LATEST ändert sich regelmäßig. Der committed Bericht identifiziert den untersuchten Lauf über Dateinamen und SHA256. Historische DWD-Verfügbarkeit ist nicht garantiert. Das Skript prüft Forschungsdaten, ist kein gehärteter App-Parser.

Python3.15 versuchte für h5py einen lokalen Source-Build, der ohne HDF5-Buildumgebung scheiterte. Daher für dieses Forschungstool Python3.13 mit verfügbarem Wheel verwenden; keine unnötigen Systempakete installieren.

## Günstigerer Kandidat und nächste Entscheidung

Der unabhängige Agent prüft WMS-Punktabfragen und eine25-Punkte-Serie: siehe `wms-point-query.md`. Erst Einheiten, Vorhersage-/Analysebezug und NoData-Semantik gegen Rohdaten bestätigen, danach zwischen direkter Punktabfrage und lokalem HDF5-Auswerten entscheiden. WMS könnte den HDF5-Bedarf auf dem Gerät vermeiden; dies ist noch eine Hypothese.

Noch offen: Georeferenzierung, mehrere trockene/nasse/fehlende Zellen, historische Animation plus Prognose, Quellenhinweise und Lizenz, iPhone-Laufzeit/Energie, Widget-Aktualität. Phase1 ist begonnen, noch nicht abgeschlossen.

## Nachfolgender Rohdatenabgleich im selben Schritt

Alle25Zeitpunkte der archivierten WMS-Serie wurden ohne weitere Netzabrufe mit Pixel297/320 des gleichen RV-Laufs verglichen. Ergebnis: alle Werte stimmen mit `raw * gain + offset` innerhalb1e-6 überein, einschließlich +5/+60/+120Minuten. Bericht: `wms-raw-comparison.json`; Rohwertstichproben in `rv-sample.json`. Die nasse Analysezelle liefert1.874mm im5-Minuten-Intervall. Die JSON-Property ist hier Akkumulation, keine unmittelbar in mm/h interpretierbare Rate. Undetect-Zeitpunkte liefern in diesem Vergleich den ungefiltert skalierten negativen Wert; NoData ist damit nicht geprüft.

Dieser Vergleich bestätigt die kleine direkte WMS-Serie für einen nassen Kontrollpunkt. Weitere Orte, Randfälle, NoData, Laufaktualität und Darstellung sind noch zu validieren. Ein neuer Backend-Zwang ergibt sich aus dem Befund nicht.
