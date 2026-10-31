# Regenwarnungen für Regionen (Entwurf, 31.10.2026)

Nutzerwunsch: Benachrichtigungen auch für Regionen statt nur für einzelne Orte. Reiner Entwurf, kein Produktcode. Kennzeichnung: [B] bestätigt (Code/Doku gelesen), [A] Annahme/Rechnung, [U] ungeprüft. Basis: `push-benachrichtigungen.md`, Backend `PushGrid`, `PushEvaluator`, `PushService.evaluate`, `003_push.sql`/`005`, `api.md`.

## 0. Ausgangslage [B]
- Abo = eine Rasterzelle (`cell_x` 0..1023, `cell_y` 0..1310 des Ingest-Bilds, Web-Mercator, ca. 1,1 km Mercator, real ca. 0,7 km), `threshold` 1..15, `lead_minutes` 10/20/30, `time_sensitive`. Limit 10 Abos je Installation (`409 subscription_limit`), 60 Anfragen/min je Installation, 600 Registrierungen/min global, Body max 2048 Byte.
- Auswertung (Leader, je neuem Lauf): Lauf muss ≤ 20 min alt sein; 25 Slots werden einzeln als WebP dekodiert, je Abo wird `PushIntensity.classify(image, x, y)` je Slot gelesen; reine Funktion `PushEvaluator.step(state, threshold, leadMinutes, lastSentAt, classes[25], now)`: Zustände dry, pending (Hysterese: zwei Läufe in Folge), notified (Wiederbewaffnung nach 7 trockenen Slots, also 30 min), Wiederholsperre 60 min. Meldung „Regen in N min“ nur, wenn Slot 0 trocken ist.
- Wichtig: Dekodierung (25 Bilder je Lauf) ist unabhängig von der Aboanzahl; Abos kosten nur Pixelzugriffe.

## 1. Was heißt „Region“?
| Variante | Speicherung | Vorteil | Nachteil |
|---|---|---|---|
| A Radius um Punkt (Kreis) | Mittelzelle + Radius (3 Zahlen) | winzig, kein Zellenverzeichnis, passt zu Orten, einfache UI (Preset/Ziehen) | nur rund |
| B Landkreis/PLZ-Gebiet | Menge von Zellen | amtliche Bezeichnung | Geometriedaten nötig (Lizenz, Pflege), große Maske, Bezug zu Wohnort stärker |
| C Bundesland | Bitmaske oder ID | grob, harmlos | für Alltag wenig sinnvoll (Regen irgendwo in Bayern), Grenzdaten nötig |
| D Gezeichnetes Polygon / Kartenausschnitt | Bitmaske in Bounding-Box (≤128×128 Zellen = 2 KB, oder Zeilenbereiche) | beliebige Form | Datenschutz (siehe 5), Missbrauch, Auswertungskosten, UI aufwendig |
| E „Meine Strecke“ (Linie + Puffer) | Polylinie als Zellenmaske | Sportler-Fall exakt | Bewegungsprofil (Wohn-/Arbeitsort erkennbar), Zeitbezug (wann wo) fehlt ohnehin |

Empfehlung [A]: v1 nur Radius-Kreis (A). Vorgesehen: Radius in Zellen (`radius_cells` 3..40; Presets 5/10/25 km entsprechen ca. 7/14/36 Zellen; Rechnung: Zellkante real ca. 0,69 km bei 51° N, Hypothese: [A], nicht gegen die Kartenprojektion nachgemessen). Mittelpunkt für Regionen gröber speichern (Raster 3×3 Zellen, ca. 2 km), das ist für einen Umkreis ohnehin ausreichend. Strecke/Polygon erst als v2 mit Bitmaske in separatem Feld, wenn Kreis nutzt; Bundesland/Kreis/PLZ nicht empfohlen.

## 2. Auslöselogik
- Je Slot t und Region: N = Zellenzahl im Kreis, `wetCount(t)` = Zellen mit Klasse ≥ `threshold`, `maxClass(t)`. Region „nass“ in t, wenn `wetCount ≥ max(minCells, ceil(share·N))`. Vorschlag [A]: `min_share_percent` Standard 10, wählbar 1/10/25/50; `minCells` = 3 (unterdrückt Einzelpixel/Clutter), bei N < 30 genügt 1 Zelle. Modus „irgendwo/stärkster Wert“ = share 1 %.
- Wiederverwendung: Pro Slot wird ein Pseudo-Klassenwert gebildet (`threshold` wenn nass, sonst 0). Damit läuft `PushEvaluator.step` unverändert (pending nach zwei Läufen, notified, Rearm nach 30 min trocken in der ganzen Region, Wiederholsperre 60 min). Keine zweite Zustandsmaschine, bestehende Tabellentests bleiben gültig [A].
- Meldungsarten: v1 nur „Regen erreicht die Region in ~N min“ (Beginn, Slot 0 trocken). Wenn es in der Region schon regnet, keine Meldung (wie heute am Ort). „Region wird trocken“/„regnerisch“ nicht in v1 (Wechselmeldungen erhöhen Meldungsflut).
- Hysterese: Eintritt bei Anteil ≥ p; Rearm erst, wenn Anteil < p/2 bzw. 0 Zellen ≥ Schwelle für Slots 0..6 (strenger = weniger Flattern an der Schwelle). Zusätzlich die vorhandenen zwei Läufe.
- Zusammenfassung: ein Abo = eine Meldung; ein Gerät mit Ort und überlappender Region soll nur eine Meldung je Lauf bekommen (Zusammenführung je Installation, `collapse_id` weiter je Abo, `thread-id` je Abo) — Auslieferung vorab prüfen, [U] ob nötig, sonst Paket R2b.
- Payload: weiter nur `loc-key` + Minuten (optional Anteil als Klasse 1/2/3 = „vereinzelt/verbreitet/flächig“ [A]); kein Ortsname.

## 3. Backend
Datenmodell (Migration `006_push_region.sql`, rückwärtskompatibel, [A]):
- `ALTER TABLE push_sub ADD COLUMN kind TINYINT UNSIGNED NOT NULL DEFAULT 0` (0 Ort, 1 Kreis), `radius_cells TINYINT UNSIGNED NULL`, `min_share TINYINT UNSIGNED NULL`. Mittelzelle bleibt `cell_x/cell_y`, Index `idx_push_sub_cell` bleibt. Spätere Maske: `region_mask VARBINARY(2048) NULL` (Bounding-Box + Bitmaske/Bereiche), erst bei v2.
- Es entsteht keine Zellenliste; Zellen werden zur Auswertung aus Mittelpunkt/Radius berechnet (Scanline je Zeile, vorab pro Radius cachebar).
API (abwärtskompatibel): zusätzliche optionale Felder im Abo: `kind` (`"point"` Standard | `"circle"`), `radius_cells`, `min_share_percent`. Fehlen sie, gilt Ort wie bisher. `GET`-Liste liefert die Felder zusätzlich. `PUT` ersetzt weiter alle Felder. Unbekannte Felder alter Backends: [U] ob ignoriert oder `400`; daher Fähigkeitsprüfung nötig (z. B. Feld `features` in einer vorhandenen Antwort oder bewusst `400` abfangen und Region nicht anbieten).
Limits [A]: höchstens 3 Regionen je Installation (innerhalb der 10 Abos), Gesamtzellen je Installation ≤ 8 000, Radius ≤ 40 Zellen (ca. 28 km → 5 000 Zellen), serverweites Budget „Summe Regionszellen ≤ 2 000 000“ → danach `409 region_capacity` (Schutz der Auswertungszeit). Bestehende Rate-Limits (60/min, 600/min) reichen; Zellenzahl pro Anfrage wird begrenzt, nicht die Frequenz.
Kosten je Lauf (Rechnung [A], nicht gemessen): Zellen ≈ π·r²: 7 Zellen → ca. 150, 14 → ca. 600, 36 → ca. 4 100. Szenario 1 000 Installationen × 3 Regionen × 1 500 Zellen × 25 Slots = 112 Mio. Zugriffe. Mit einem je Slot einmalig berechneten Klassenbild (1,34 Mio. Pixel, transparente Pixel schnell als 0; höchstens 25 × 1,34 Mio. = 33 Mio. `classify`-Aufrufe zu je grob 30 ns ≈ 1 s) und Klassenzugriff ≈ 1–3 ns ergibt sich ein Auswerteaufwand von grob 1–2 s je Lauf, bei Lauftakt 5 min vertretbar; Worst Case 2 Mio. Zellen × 25 = 50 Mio. (ca. 0,2 s Lookups). Dekodierung der 25 WebP bleibt der Fixanteil. Empfehlung: Prüfung per kleiner Messung mit einem vorhandenen Slot im Paket R2 (Benchmark-Test), bevor Limits finalisiert werden. Komplexität: O(Σ Zellen·25) je Lauf, nicht von der Aboanzahl der Orte abhängig; Optimierung: Summen-Tabelle (Integralbild je Slot) liefert `wetCount` für ein Rechteck in O(1) — für Kreise kein Muss.

## 4. App
- Erstellung: im Ort-Einstellungsbildschirm Abo-Art „Ort / Umkreis“; Umkreis: Presets 5/10/25 km und Regler/Ziehgriff auf der Karte (MapKit-Kreis, vorhandene `RadarMap`; [B] MapKit wird in `Weather/Map/` verwendet). Zeigt Kreis um den gespeicherten Ort, Mittelpunkt wird vor dem Senden auf das 3×3-Raster gerundet (Kreis zeigt die gerundete Lage).
- Bearbeitung: Radius, Anteil (Wenig/Mittel/Viel = 1/10/25 %), Schwelle, Vorlauf, Zeitkritisch wie bisher. Anzeige: Kreis als Overlay in Orteliste/Karte, Kurztext „Umkreis 10 km, ab 10 % der Fläche“.
- Einstellungen: Regionen zählen im 10er-Abolimit; Fehlermeldungen für `subscription_limit`/`region_capacity`. Info-Sheet „Datenschutz“ um Region ergänzen (Mittelpunkt auf ca. 2 km gerundet, Radius).
- Rechnen lokal: Radius km → Zellen aus Breitengrad (cos φ); `PushGrid.swift` erhält Funktion für Umkreis.

## 5. Datenschutz
- Heute: Token + Installations-ID + ~1-km-Zelle je Ort [B]. Kreis ändert die Art der Daten nicht (Mittelzelle + Radius), sofern der Mittelpunkt gröber (3×3) gespeichert wird, sinkt die Genauigkeit sogar. Radius allein ist nicht personenbezogen.
- Polygon/Strecke (v2) wäre qualitativ anders: Zellenmenge ist ein Bewegungsbereich (Heimat/Arbeit/Trainingsstrecke), identifizierender als ein Punkt. Daher nicht in v1; falls v2: Größe begrenzen (Bounding-Box ≤ 128 Zellen), keine Rohkoordinaten, Hinweis in App und Datenschutztext, Entscheidung durch Nutzer.
- App Privacy: Kategorien unverändert (Device ID, Coarse Location, Zweck App Functionality, verknüpft) [A, unverändert zu `push-benachrichtigungen.md` §5]; Datenschutztext: Abschnitt „Regenwarnungen“ um „Umkreis (Mittelpunkt auf ca. 2 km gerundet, Radius)“ ergänzen. Löschfristen unverändert (410, 60 Tage ohne `last_seen`, `DELETE`, Cascade auf Abos/Outbox).
- Missbrauch: Limits aus 3. Gesamtzellen je Installation und serverweit; kein Auslesen fremder Daten (Secret-Hash wie bisher); Umkreise erlauben keine Abfrage von Wetter anderer, nur Meldung „kommt“ [A].

## 6. Pakete (Dateibesitz, Reihenfolge)
| Paket | Inhalt | Besitz | nach |
|---|---|---|---|
| R0 | Entscheidungen E1–E5 in `decisions.md` | Docs | – |
| R1 | Migration 006, `PushSubscription`/`Input` um `kind`, `radiusCells`, `minShare`, Repo (Memory/Maria) | Backend `Push*`-Modelle, `Repo*+Push` | R0 |
| R2 | Reine Funktion Kreis→Zellen, Aggregation `wetCount` je Slot, Anbindung `PushService.evaluate`, Benchmark | Backend `PushEvaluator`/`PushService`, neue `PushRegion.swift` | R1 |
| R3 | API-Validierung, Limits (`region_capacity`), `api.md`, Datenschutzseite | Backend `PushApi`, `docs-site` | R1 |
| R4 | App: `PushGateway`-Felder, `PushGrid` Umkreis, `PushManager` | App `Weather/Push/*` | R3 (Vertrag) |
| R5 | App: Karten-UI, Presets, Texte (de/en), Info-Sheet | App `Weather/Views`, `Weather/Map` | R4 |
Tests ohne echtes APNs: Tabellentests der Aggregation (Anteil, minCells, Rand bei Bild/Kante, Hysterese), Kreis-Zellenzahl pro Radius, Repo-Vertragstests Memory/MariaDB, Vapor-Tests für Felder/Limits (Rückwärtskompatibilität: Abo ohne `kind`), App mit `URLProtocol`-Mock und Fake-Notification-Center, `FakeApnsSender` wie vorhanden.

## 7. Entscheidungen für den Nutzer (mit Empfehlung)
1. Regionsform v1: nur Umkreis (Kreis) — Empfehlung ja; Strecke/Polygon später, Bundesland/PLZ nein.
2. Radius-Presets 5/10/25 km, Maximum ca. 28 km — Empfehlung ja.
3. Auslöser: Anteil der Fläche (1/10/25 %, Standard 10 %, mindestens 3 Zellen) statt nur Maximum — Empfehlung ja.
4. Mittelpunkt gröber speichern (3×3 Zellen, ca. 2 km) — Empfehlung ja (Datensparsamkeit).
5. Limits: 3 Regionen je Installation, Gesamtzellen 8 000, serverweit 2 Mio. — Empfehlung ja, nach Messung in R2 bestätigen.
6. Meldung „Region trocken/regnerisch“ als zweite Art — Empfehlung später.
7. Mehrere Abos desselben Geräts zusammenfassen (eine Meldung) — Empfehlung prüfen in R2b, erst nach nutzbarem Basis-Release.
