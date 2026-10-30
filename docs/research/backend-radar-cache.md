# Server-Cache für die Deutschland-Radarkarte (Recherche)

Stand: 30. Oktober 2026. Reine Recherche und Messung, keine Implementierung, kein Hosting gebucht, keine Codeänderung. Auslöser: Nutzer findet den Kartenabruf langsam und fragt, ob ein Server alle 5 Minuten die ganze Deutschlandkarte holt und effizient ausliefert. **Das widerspricht der bisherigen Entscheidung** ("Karte unabhängig vom eigenen Backend, Bilder grundsätzlich direkt vom Anbieter", `decisions.md`, `concept-v2.md` §Architektur); eine Umsetzung braucht eine ausdrückliche neue Nutzerentscheidung.

Kennzeichnung: **[G]** gemessen am 30.10.2026 (UTC 10:50–11:00 bzw. 29.10. für Nasslage-Vergleich), **[S]** geschätzt/gerechnet aus Messwerten, **[A]** Annahme. Insgesamt ca. 60 DWD-Requests, sequenziell. Die Stichprobe ist klein; die Tageslage war nahezu trocken (siehe Grenzen).

## 1. Messungen

Dienst wie im App-Code (`Weather/Data/DWDRequest.swift`): `https://maps.dwd.de/geoserver/ows`, Layer `dwd:Niederschlagsradar`, WMS 1.1.1, EPSG:3857, `TIME` + `DIM_REFERENCE_TIME`.

### 1a. Einzel-Tiles (256 px, PNG, curl, jeweils neue Verbindung) [G]

| Zoom/Tile | Größe | TTFB | Gesamt |
|---|---|---|---|
| z6 33/21 | 2.112 B | 0,26 s | 0,26 s |
| z7 67/42 | 2.087 B | 0,21 s | 0,21 s |
| z8 136/85 | 1.784 B | 0,31 s | 0,31 s |
| z8 137/86 | 1.807 B | 0,30 s | 0,31 s |
| z9 272/170 | 1.784 B | 0,26 s | 0,26 s |
| z9 273/171 | 1.784 B | 0,26 s | 0,26 s |

- Verbindungsaufbau (TCP+TLS) 0,08–0,10 s; Rest ist serverseitiges Rendern (0,1–0,3 s). Die App hält Verbindungen offen und spart den Aufbau.
- Tiles sind im trockenen Zustand fast leer (ca. 1,8–2,1 KB); die App-Messung früher: 32 Tiles ca. 137 KB (ca. 4,3 KB je Tile) bei Regen.
- **HTTP-Version: nur HTTP/1.1** (`HTTP/1.1 200`, Apache, `Transfer-Encoding: chunked`). Kein HTTP/2, daher kein Multiplexing; begrenzt die Parallelität pro Host zusätzlich.
- **Keine Cache-Header:** weder `Cache-Control`, `ETag`, `Last-Modified` noch `Expires`. `geowebcache-cache-result: MISS`, `geowebcache-miss-reason: not a tile layer` (Layer läuft nicht über GeoWebCache). Jede Anfrage wird neu gerendert. `Access-Control-Allow-Origin: *`.
- **Auffällig:** HTTP 200 mit XML-Fehler `InvalidDimensionValue` ("Could not find a match for 'time'") trat gelegentlich auf, auch für den aktuellen Lauf (z7/68/43 mit Referenz 10:45 Uhr) und reproduzierbar (2 von 2) für ein 1024-px-PNG des 29.10. 12:00 UTC, während 512 px und 2048 px desselben Zeitpunkts funktionierten. Ursache unbekannt (mögliche Cluster-Inkonsistenz); die App-Prüfung auf XML-Antworten bleibt wichtig, ein Server-Ingest braucht Retry.

### 1b. GetMap ganz Deutschland, ein Bild [G]

BBOX (EPSG:3857) 612257,5942074,1736584,7381298 (ca. 5,5–15,6 °O, 47,0–55,1 °N), Seitenverhältnis 1024×1311 bzw. 2048×2621.

| Format | Breite | Größe | Zeit (TTFB≈Gesamt) | Hinweis |
|---|---|---|---|---|
| image/png (RGBA) | 1024 | 44.512 B (trocken) | 0,9–1,2 s | |
| image/png (RGBA) | 2048 | 147.342 B (trocken), 156.389 B (29.10. 12 Uhr, leichte Schauer) | 2,9–3,4 s | |
| `image/png; mode=8bit` | 1024/2048 | identisch zu RGBA (Bytegleich), wird ignoriert | | |
| image/vnd.jpeg-png8 | 1024 | 20.072 B (29.10.) | 1,4 s | 8-bit-Palette (`file`: colormap) |
| image/vnd.jpeg-png8 | 2048 | 43.075 B (trocken), 48.671 B (29.10.) | 3,2–3,4 s | |
| image/gif | 1024 | 8.982 B (trocken) | 1,0 s | |
| image/png | 512 | 16.930 B (29.10.) | 0,3 s | |

Weitere angebotene Formate laut Capabilities: geotiff(8), jpeg, tiff(8), png8, gif (auch animiert), vnd.jpeg-png(8), svg, pdf, kml. Das Rendern kostet DWD-seitig Sekunden bei 2048 px; große Bilder sind kein Lastgewinn gegenüber Tiles, wenn jeder Client sie selbst anfordert. Nur ein einziger Server-Abruf pro Slot und Lauf ist vertretbar.
Die Bilder enthalten neben Regen eine Abdeckungsmaske (weißer Hintergrund, magentafarbene Randlinie, graue Fläche außerhalb); ob diese Maske in der aktuellen App-Kachel ebenfalls erscheint beziehungsweise wie die Transparenz zu behandeln ist, wurde nicht geprüft. Das Rohdaten-Raster der Quelle hat 1 km Auflösung; 1024 px Breite über Deutschland entsprechen ca. 1,1 km/px (nativ), 2048 px ca. 0,55 km/px (2-fach überabgetastet).

### 1c. Zeitachse, Läufe, Verfügbarkeit [G]

- Capabilities (WMS 1.1.1 GetCapabilities, 2,1 MB, 13 s – nicht regelmäßig abrufen): `time` = `2026-10-27T00:00Z/2026-10-30T12:50Z/PT5M` (5-Minuten-Raster, ca. 3,5 Tage Historie), `REFERENCE_TIME` = Liste aller Läufe im 5-Minuten-Raster; `default` = aktueller Lauf. Der letzte `time`-Wert ist Referenz + 120 min (10:50 → 12:50). Der Vorhersagehorizont beträgt also 120 min = 24 Vorhersageschritte + Analyse = 25 Slots je Lauf.
- Anfrage: `TIME=<Slotzeit>` und `DIM_REFERENCE_TIME=<Lauf>` (Millisekundenformat `.000Z` nötig, siehe `data-contract.md`).
- Neuer Lauf: Index `opendata.dwd.de/weather/radar/composite/rv/` listet `composite_rv_YYYYMMDD_HHMM.tar`. Datei-Zeitstempel: Lauf 10:40 um 10:43:15, 10:45 um 10:48:14, 10:50 um 10:53:21 UTC → **Verzögerung ca. 3–3,5 Minuten** nach Nominalzeit, 5-Minuten-Takt. Der Index hielt zum Messzeitpunkt 577 Dateien (ca. 48 h).
- **Rohdaten-Tar je Lauf** [G]: 778.240 B (ca. 760 KB) mit **25 HDF5-Dateien (je ca. 30 KB), Slots +0…+120 min**, ganz Deutschland im 1-km-Raster. Download 0,26 s; Header: HTTP/2, `ETag`, `Last-Modified`, `Accept-Ranges`. Die Rohdaten sind damit deutlich kleiner und freundlicher auslieferbar als WMS-Bilder und sind dieselbe Quelle, die das Benachrichtigungs-Backend ohnehin braucht (`concept-v2.md`, zentraler DWD-Abruf).
- Vergangene Slots (App: 12 Analysen) stammen aus Frame `000` älterer Läufe und ändern sich nie mehr. Von Lauf zu Lauf ändern sich nur die 25 Vorhersage-Slots plus ein neuer Analyse-Slot, also ca. 26 neue Bilder pro 5 Minuten.

### 1d. Rechnung Timeline (37 Slots = 12 Analysen + 25 Vorhersage)

Messbasis [G] (je ein Bild): PNG RGBA 1024 px 44,5 KB; 2048 px 147–156 KB; PNG8 2048 px 43–49 KB; PNG8 1024 px 20 KB; verlustfrei WebP (lokal `cwebp -lossless -z 9 -exact` aus den PNGs) 1024 px 6,0 KB (trocken), 2048 px 9,7 KB (trocken) bzw. 12,0 KB (29.10.), 512 px 3,7 KB. PNG8-Wert und WebP sind Proxys für optimierte Auslieferung; `pngquant` stand nicht zur Verfügung, ein serverseitig optimiertes PNG liegt vermutlich nahe bei WebP bis 2-fach darüber [A].

| Variante (37 Slots) | Größe gesamt | Quelle |
|---|---|---|
| Heute: ca. 1.184 Tiles à 1,8–4,3 KB, ca. 1.184 Requests | ca. 2,1–5 MB | [S] aus 1a und `near-instant-radar.md` |
| Ganzbild PNG RGBA 1024 px roh vom DWD | ca. 1,6 MB | [S] 37 × 44,5 KB |
| Ganzbild PNG RGBA 2048 px roh vom DWD | ca. 5,4–5,8 MB | [S] |
| Ganzbild PNG8 2048 px (DWD `vnd.jpeg-png8`) | ca. 1,6–1,8 MB | [S] |
| Ganzbild WebP verlustfrei 1024 px | ca. 0,22 MB | [S] 37 × 6,0 KB |
| Ganzbild WebP verlustfrei 2048 px | ca. 0,36–0,45 MB | [S] 37 × 9,7–12 KB |
| Rohdaten HDF5 (nativ 1 km, 25 Slots + 12 Analysen) | ca. 0,78 MB + 0,36 MB = ca. 1,1 MB (gesamt, bei Download der 13 Tars; der Lauf allein 0,78 MB) | [G]/[S] |

Delta zwischen Slots wurde nicht gemessen [A: bringt bei verlustfreiem WebP wenig, da schon klein; Prognoseframes sind verschieden, nicht nur verschoben]. Grenzen: **Eine fast trockene Lage unterschätzt Regenlagen**; bei flächigem Regen wachsen PNG und WebP (grob Faktor 3–10, nicht gemessen [A]); die HDF5-Größe schwankt dagegen kaum (alle 25 Frames 30,1 ± 0,3 KB, trocken). Ein Gegenstück an einem nassen Tag fehlt und sollte gemessen werden, bevor Budgets festgelegt werden.

## 2. Lizenz und Quellen (Abruf 30.10.2026)

- DWD Open Data Seite, https://www.dwd.de/DE/leistungen/opendata/opendata.html: Daten weitgehend kostenfrei; "für diesen Dienst Service- und Verfügbarkeitslevel nicht zugesichert"; für Prozesse mit Integritäts-/Kontinuitätsanspruch Verweis auf kostenpflichtigen gesicherten Zugang.
- DWD FAQ Open Data, https://www.dwd.de/DE/leistungen/opendata/faqs_opendata.html: Weiterverwendung "entsprechend der Creative Commons BY 4.0 – Lizenz", Quellenangabe Pflicht; "Bereitstellungsentgelte" nur für individuelle Zusammenstellungen/Auslieferungen durch den DWD. **Mirroring/Caching, Abfragehäufigkeit, Rate-Limits und Verfügbarkeit sind dort nicht erwähnt.** Newsletter für Änderungen an den Geodiensten (WMS/WFS) existiert.
- DWD Rechtliche Hinweise, https://www.dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise_node.html: Geodaten (alle meteorologischen Informationen mit Ortsbezug) dürfen unter CC BY 4.0 "unter Beigabe eines Quellenvermerks weiterverwendet werden".
- Vorgaben Quellenvermerk, https://www.dwd.de/DE/service/rechtliche_hinweise/vorlagen_quellenangabe.html: Pflicht auch bei Auszügen oder geändertem Datenformat; Textform **"Quelle: Deutscher Wetterdienst"**; Logo als Quellenvermerk ausreichend; bei Bearbeitung Veränderungshinweis, z. B. **"Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben"**; unmittelbar an der verwendeten Information platzieren. Warnungen dürfen nicht verändert unter DWD-Quellenvermerk laufen (hier nicht betroffen).
- GeoNutzV, https://www.gesetze-im-internet.de/geonutzv/__2.html und `__3.html`: Geodaten und Geodatendienste kostenfrei für kommerzielle und nichtkommerzielle Zwecke; Vervielfältigen, Verändern und "an Dritte übermitteln" ausdrücklich erlaubt (§2); Quellenvermerke müssen erkennbar bleiben, Veränderungen mit Veränderungshinweis (§3).
- DWD-Anleitung WMS-Einbindung (https://www.dwd.de/DE/wetter/warnungen_aktuell/objekt_einbindung/einbindung_karten_geodienste.pdf?__blob=publicationFile&v=14): Refresh nicht unter 5 Minuten, keine Verfügbarkeitszusage. Das PDF war beim heutigen Abruf nicht als Text lesbar; die Aussage stammt aus `near-instant-radar.md` (Abruf 28.10.), heute nicht erneut verifiziert.

Bewertung: **Zwischenspeichern und Weiterverteilen ist nach CC BY 4.0 / GeoNutzV rechtlich gedeckt**, sofern Quellenvermerk und Veränderungshinweis in der App sichtbar bleiben (die App zeigt bereits Quellen; Text prüfen). Ein einmaliger Abruf je 5-Minuten-Lauf entspricht der DWD-Empfehlung. **Offen:** keine veröffentlichte Aussage zu Mirroring oder zu Lastgrenzen; empfohlen ist eine kurze schriftliche Anfrage an den DWD-Kundenservice (Zweck, Takt, Spiegelung) und Anmeldung beim Geodienste-Newsletter. Kein Rechtsrat.

## 3. Design-Vorschlag (nur Konzept)

Gemeinsame Ingest-Pipeline (Server): alle 5 Minuten den Index prüfen (Last-Modified-/ETag-basiert), neues `composite_rv_*.tar` laden (ca. 0,78 MB, 1 Request), HDF5 validieren (Lauf-ID, 25 Slots, Altersgrenze), Slots rendern, ablegen, Manifest umschalten. Gleiche Pipeline speist Regenwarnungen und Punktprognosen des Benachrichtigungsbackends (`concept-v2.md` §Rohdaten zentral einmal abrufen). Variante v0 ohne eigenen Renderer: pro Lauf 26 WMS-GetMap-Bilder (ca. 26 × 1–3 s DWD-Rechenzeit, alle 5 min) mit DWD-Darstellung abrufen; schlechter als Rohdatenweg wegen Rendering-Last beim DWD und gelegentlicher `InvalidDimensionValue`-Antworten, aber ohne eigene Palette (DWD-Legende bleibt identisch).

| Kriterium | (A) Tiles je Slot hinter CDN | (B) Ganzbild je Slot / Bündel je Lauf | (C) Hybrid |
|---|---|---|---|
| Client-Requests | ca. 1.184 (wie heute, aber CDN, HTTP/2) | 1 Manifest + bis 37 Dateien, oder 1 Bündel; nach dem ersten Mal nur ca. 26 neue je Lauf | wie B, Tiles nur für Zoom über nativer 1-km-Auflösung |
| Bytes (37 Slots) | ca. 2–5 MB [S] | ca. 0,2–0,5 MB WebP [S] | wie B |
| Aufwärmzeit | durch Requestzahl dominiert, ca. 20–60 s [A] | Sekunden [A] | wie B |
| Serverlast je Lauf | ca. 230 Tiles (z5–9) × 26 Slots = ca. 6.000 Dateien rendern [S] | 26 Bilder | B + optionale Tiles |
| Speicher je Lauf | ca. 6.000 × ca. 1–4 KB = ca. 6–25 MB [S] | ca. 0,3–0,5 MB | |
| Client-Aufwand | geringste Änderung (nur Basis-URL) | neuer Renderer: ein georeferenziertes Bild je Slot als Overlay; Interpolation/Pixel-Look prüfen | höchster |
| Kosten-Größenordnung [A] | Hosting+CDN grob 5–20 €/Monat | gleiche Größenordnung, weniger Egress | |

Kosten nur als grobe Spanne [A]: Auslieferung etwa 0,4 MB je vollständigem Timeline-Laden; bei z. B. 10.000 Ladevorgängen/Tag ca. 4 GB/Tag, ca. 120 GB/Monat; bei CDN-Preisen zwischen kostenlos (Anbieter ohne Egress-Gebühr) und ca. 0,01–0,09 €/GB entspricht das 0–10 €/Monat plus kleine VM/Objektspeicher. Keine Anbieterprüfung durchgeführt.

Datenschutz: Gesamtkarte erfordert keinen Ortsbezug im Request (fester Pfad pro Lauf/Slot); ein viewportabhängiges Tile-Muster würde dagegen den betrachteten Kartenausschnitt verraten, ein Ganzbild nicht. Weiter nötig: keine Zugriffsprotokolle mit IP oder nur sehr kurz, EU-Hosting, keine Cookies/IDs. Das ist ein Vorteil von (B) gegenüber (A) und gegenüber dem heutigen DWD-Direktabruf (dort sieht der DWD Ausschnitt und IP).

Ausfallverhalten: App versucht zuerst den Cache (Manifest mit Lauf-ID und Zeitstempel), bei Timeout, Fehler oder zu altem Lauf (> 20 min, bestehende Regel) fällt sie auf den heutigen direkten DWD-Weg zurück; Datenalter bleibt sichtbar. Cache-Fehler dürfen den Direktpfad nicht blockieren (Karte "unabhängig vom Backend" bleibt erhalten).

Unveränderliche URLs: `/radar/v1/{referenzlauf}/{slot}.webp`; `Cache-Control: public, max-age=31536000, immutable`; nur `/radar/v1/latest.json` (Lauf-ID, Slotliste, Erzeugungszeit, Quellenvermerk) mit kurzer TTL (ca. 30–60 s) und Revalidierung. Vergangene Analyse-Slots tragen dieselbe URL über mehrere Läufe und bleiben im Client-Cache.

### Empfehlung

**(B), gestuft:** Erstens Ingest über die HDF5-Tars (gemeinsam mit dem Benachrichtigungsbackend), zweitens ein vorgerendertes Ganzbild je Slot in ca. 1024–1400 px Breite (nahe nativer 1-km-Auflösung) als verlustfreies WebP/PNG8 mit unveränderlichen URLs hinter einem CDN, drittens Client-Umstellung mit Fallback auf den DWD-Direktweg. Begründung: Die Quelle ist nativ 1 km; Tiles in Zoom 8–9 liefern keine zusätzliche Information, nur 1.184 Requests statt ca. 40. Bytes sinken um Faktor ca. 10, Requests um Faktor ca. 30, der DWD sieht ein Abruf je Lauf statt Last pro Nutzer, kein Ortsbezug im Request. (A) ist der kleinste Eingriff in die App, verbessert aber hauptsächlich Latenz und Host (HTTP/2), nicht die Requestzahl; (C) erst, falls Nutzer Tiles bei hohem Zoom vermissen. Zur Risikoreduzierung vor Entscheidung: ein Prototyp-Vergleich auf einem Regentag (gleiche Szene: Tiles vs. Ganzbild) und Sichtprüfung der Bildqualität/Palette auf iPhone.

Zum Zeitpunkt der Entscheidung besteht noch kein Backend-Code (Schwesterrepo nur Dokumentation: Konzept, Plan, Entscheidungen, Status; Stack vorgesehen Swift/Vapor, MariaDB, Docker Swarm; DWD-Lizenzprüfung dort als offen vermerkt). Eine Kartenauslieferung aus Objektspeicher plus CDN braucht diesen Stack nicht und kann unabhängig vom Push-Dienst starten; der Ingest-Job sollte aber dessen Pipeline werden.

## 4. Entscheidungen für den Nutzer

1. Soll die Produktentscheidung "Karte direkt vom Anbieter" für einen optionalen Server-Cache mit DWD-Fallback geändert werden (Eintrag in `decisions.md`)?
2. Hosting: eigener Server/Docker Swarm (bestehender Stack) oder Objektspeicher plus CDN eines Anbieters; Region (EU) und Logging-Regel.
3. Budget-Obergrenze pro Monat und Abrechnungsform (keine Buchung ohne Auftrag).
4. Lizenzfreigabe: CC BY 4.0 / GeoNutzV als ausreichend ansehen oder schriftliche Bestätigung des DWD zu Spiegelung und Takt einholen; Wortlaut Quellenvermerk und Veränderungshinweis ("Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben") in der App festlegen.
5. Darstellung: DWD-Palette beibehalten oder eigene Palette (nur bei Rohdaten-Rendering möglich).

## 5. Offene Fragen und nicht geprüfte Punkte

- Nasslage: Größen von WebP/PNG8/HDF5 bei flächigem Regen nicht gemessen; kein Delta-Test; `pngquant` nicht vorhanden.
- Ursache der intermittierenden `InvalidDimensionValue`-Antworten und der 1024-px-Fehlschläge unklar.
- DWD-Anleitung PDF (Refresh 5 min) heute nicht neu gelesen; Mirroring/Rate-Limit nicht dokumentiert.
- Ob die weiße/graue Abdeckungsmaske in den WMS-Bildern im App-Kachelpfad ebenso erscheint, nicht geprüft; bei Eigenrendering aus HDF5 (Nodata/Undetect-Regeln aus `data-contract.md`) entsprechend umzusetzen.
- Kosten, Latenz und CDN-Eigenschaften nicht gegen Anbieter gemessen; Aufwärmzeiten in der Tabelle sind Annahmen.
- Es wurde weder gebaut noch simuliert; keine Änderung an App, Backend, `status.md`.
