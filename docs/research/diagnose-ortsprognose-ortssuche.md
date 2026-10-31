# Diagnose: Ortsprognose-Fehler und Datenschutz der Ortssuche

Stand: 31.10.2026, HEAD 2477777. Rein lesende Analyse plus 42 öffentliche Punktabrufe (und 2 Indexabrufe) (Berlin-Mitte, 52.52/13.405). Kein Build, kein Simulator.

Umsetzung der Empfehlungen: siehe Abschnitt „Robuste Ortsprognose und Ortssuche-Datenschutz“ in [decisions.md](../decisions.md) (31. Oktober 2026).

## Teil 1: „Ortsprognose: Die Wetterdaten konnten nicht gelesen werden“

### Wo die Meldung entsteht (BESTÄTIGT, Code)

- Text: `DWDDataError.invalidResponse` (`Weather/Data/RainForecast.swift:74`). Anzeige als „Ortsprognose: …“ in `Weather/Views/RadarScreen.swift:471` aus `store.forecastError` (`Weather/Models/WeatherStore.swift:252`).
- `invalidResponse` entsteht beim Punktabruf nur so:
  1. HTTP 2xx, aber Body leer oder größer 2 MB (`DWDClient.swift:123`).
  2. HTTP 200 mit `ServiceException`/`ExceptionReport` und einem anderen Code als `InvalidDimensionValue`/`MissingDimensionValue` (`DWDResponse.swift:29-37`).
  3. JSON nicht dekodierbar: `Collection`/`Properties` verlangen `type`, `features[].properties.TIME`, `REFERENCE_TIME` als String (`DWDResponse.swift:80-103`). Ein HTML-/Text-Body mit HTTP 200, abgeschnittenes JSON oder fehlendes Feld landen hier. `RV_ANALYSIS` ist optional, Null ist unkritisch.
  4. `type != "FeatureCollection"` oder `numberReturned != features.count` (`DWDResponse.swift:104-107`).
  5. `TIME`/`REFERENCE_TIME` nicht per ISO8601 parsebar (`DWDResponse.swift:111-112`, `DWDRequest.swift:14-20`).
  6. Zusätzlich beim Laufindex (`DWDClient.swift:98-99`, `DWDResponse.swift:7,17`): Verzeichnislisting nicht UTF-8 oder ohne `composite_rv_…tar`-Treffer.
- Nicht `invalidResponse`: HTTP-Status außerhalb 2xx und Netzfehler/Timeout werden zu `unavailable` („nicht erreichbar“, `DWDClient.swift:119-122`); falsche Anzahl/Lücken zu `incompleteForecast`; anderer Lauf zu `mismatchedRun`; Zeitformate und Rundung (`amount`, `-0.001` zu 0) erzeugen keinen Fehler.

### Messung (BESTÄTIGT, 43 Requests, sequenziell, 0,5-0,7 s Abstand, ein Laufstand `2026-10-30T23:15Z`, URL exakt wie `DWDRequest.pointURL`)

Lauf 1 (30 Requests):

| Ergebnis | Anzahl |
|---|---|
| 200, `application/json;charset=UTF-8`, 25 Features, keine Nullwerte | 19 |
| 200, `text/xml;charset=UTF-8`, `ServiceExceptionReport` | 6 |
| 503, `text/html` | 3 |
| Verbindungsfehler (`fetch failed`) | 2 |

Lauf 2 (12 Requests): Folge `502 503 503 503 EXC 502 OK OK XML OK OK OK`, also 2 OK von 12 in Serie, danach stabil.

- XML-Form (vollständiger Auszug, kein Personenbezug): `<ServiceException code="InvalidDimensionValue" locator="time"> Could not find a match for 'time' value: '2026-10-30T23:15:00.000Z/2026-10-31T01:15:00.000Z/PT5M'`. Gleiches Phänomen wie bei GetMap (ca. 20 % XML bei gültigem Lauf, zufällig wechselnd), wiederholbar: direkt folgende Requests waren wieder gültig.
- 502/503/Verbindungsfehler traten gehäuft in einer Phase auf (vermutlich Überlast/Gateway beim DWD; Ursache ANNAHME). Rate in dieser Stichprobe: 18 von 42 Punktabrufen fehlgeschlagen (ca. 43 %): 7 XML `InvalidDimensionValue`, 8 HTTP 502/503, 3 Verbindungsfehler. Die Fehler traten stark geklumpt auf (Lauf 2 begann mit 6 Fehlern in Folge); Stichprobe klein, keine belastbare Dauerrate. Hinweis: Die Requests kamen aus Node-`fetch` ohne die App-Header/Session, daher nur indikativ.

### Bewertung der Vermutung

- TEILWEISE WIDERLEGT: Die XML-Antwort (`InvalidDimensionValue`) wird von der App **nicht** als Dekodierfehler gemeldet. `serviceError` mappt sie auf `runUnavailable` (`DWDResponse.swift:33-34`), `fetch` wiederholt bis 3 Versuche mit 0,3/0,6 s (`DWDClient.swift:125-129`, `RadarBackend.swift:174-184`); der Punktweg läuft über dieses `fetch` (`DWDClient.swift:57`). Das gilt seit Build 9 (Commit dcd5c7b). Bei 16-20 % Fehlerrate bleibt ca. 0,5-1 % Restfehler, dann aber mit der Meldung „Der angekündigte DWD-Datenlauf … noch nicht verfügbar. Bitte erneut versuchen.“, nicht „nicht gelesen“.
- Die gemessenen Fehlerformen erklären die Meldung „nicht gelesen“ deshalb nicht. Plausible, **nicht gemessene** Kandidaten (HYPOTHESE): (a) Gateway/Proxy liefert HTTP 200 mit HTML oder abgeschnittenem JSON (Punkt 3), (b) anderer ServiceException-Code (Punkt 2, z. B. Überlast), (c) leerer 200er-Body (Punkt 1). Weil `invalidResponse` alle sechs Fälle vermischt und nichts loggt (bewusst, Datenschutz), ist die Ursache des Simulatorlaufs nachträglich nicht bestimmbar.
- Zusätzliche Lücke (BESTÄTIGT): 5xx/Timeout/Netzfehler werden **nicht** wiederholt (`DWDClient.swift:119-122`), obwohl in der Messung häufig und kurzlebig. Ein einzelnes Aufflackern wird sofort als Fehler angezeigt.
- Zusätzliche Lücke (BESTÄTIGT): Bei Fehler wird die Prognose nur behalten, wenn `forecastPlaceID == place.id` (`WeatherStore.swift:251`); bei Ortswechsel ist `forecast` schon `nil` (`WeatherStore.select`, Zeile ca. 118), also leere Ansicht mit Fehlertext (`RadarScreen.swift:556`). Es gibt keinen persistenten Cache (`data-contract.md:29` sieht ihn als mögliche UI-Aufgabe vor).

### Empfehlung

1. `DWDClient.swift:114-130` (`fetch`): Wiederholung (max. 3 Versuche, 0,3/0,6 s plus Jitter) auch für HTTP 502/503/504 und `URLError` (`.timedOut`, `.networkConnectionLost`, `.cannotConnectToHost`), nicht für `.cancelled`/`.notConnectedToInternet`. Dazu `RadarRetryPolicy.shouldRetry` (`RadarBackend.swift:181`) um einen Fall `transient` erweitern, ggf. neuer `DWDDataError`-Fall statt `unavailable`.
2. `DWDResponse.swift:99-107,112`: `invalidResponse` aufteilen (z. B. `emptyBody`, `serviceException`, `malformedPayload`) mit je eigener Meldung, ohne Rohdaten zu loggen. Ein Fehlertyp reicht pro Fall; das macht den nächsten Auftritt diagnostizierbar. Außerdem Wiederholung bei `malformedPayload`/`emptyBody` (ein Versuch), da vermutlich transient.
3. `WeatherStore.swift:245-253`: Letzte gültige Prognose je Ort (im Speicher; optional `places.json`-getrennt auf Platte, nur Werte ohne Rohantwort) weiter anzeigen, mit Altersanzeige; `RadarScreen.swift:456` zeigt bereits „Ältere Prognose · bitte aktualisieren“, sofern `forecast` erhalten bleibt. Nur anzeigen, solange `!isStale` (maximal erlaubtes Alter in `RainForecast.maximumAge`).
4. Test: Transport-Stub mit Sequenz 503, 503, OK sowie 200+HTML, 200+leer, XML anderer Code (`WeatherTests`).

## Teil 2: Datenschutz der Ortssuche

### Genutzte Dienste und Datenflüsse (BESTÄTIGT, Code)

| Funktion | Dienst | Daten | Beleg |
|---|---|---|---|
| Ortssuche | `MKLocalSearch` (Apple) | Suchtext, feste Suchregion (Mitte Deutschland 51.1/10.4, nicht der Nutzerstandort), IP | `PlacesSheet.swift:115-120` |
| Treffer wählen | lokal | Koordinate und Name aus dem Treffer, gespeichert nur lokal | `PlacesSheet.swift:64-68`, `WeatherStore.swift:393-402` |
| Karte | `MKMapView` (Apple Basiskarte) | angezeigter Kartenausschnitt (Kacheln), IP; Standardkonfiguration, POIs aus | `RadarMap.swift:20-24` |
| Kartenpunkt (langer Druck) | nur Gestenumrechnung, kein Dienst, kein Reverse-Geocoding; Name fest „Kartenpunkt“ | Koordinate lokal | `RadarMap.swift:29-31,282-285`, `WeatherStore.swift:127` |
| Aktueller Standort | `CLLocationManager`, Name fest „Aktueller Standort“, kein `CLGeocoder` | Koordinate lokal | `WeatherStore.swift:62,377-385` |
| Punktprognose | DWD `maps.dwd.de` GetFeatureInfo | Koordinate (Box ±0,005° um den Punkt), IP | `DWDRequest.swift:5,22-36` |
| Radarbilder | ShowerNow-Radar-Server, Fallback DWD | ohne Ortsbezug bzw. Kartenausschnitt | `RadarBackend.swift:6`, `DWDRequest.swift:39-54` |

- Es gibt keinen `CLGeocoder`, kein `MKReverseGeocodingRequest`, keinen `MKLocalSearchCompleter`, keinen eigenen Such- oder Geocoding-Dienst (grep über `Weather/`). Suchtext geht nur an Apple, nie an DWD oder Radar-Dienst. Koordinaten gehen an den DWD (Punktprognose) und bei Direktweg indirekt als Kartenkachel-Box; der Radar-Dienst erhält keinen Ort.
- Apple-Seite im Detail (was Apple speichert, ob Kartenkacheln pseudonym abgerufen werden): ANNAHME / nicht geprüft, hier nur Primärquellen von Apple heranzuziehen.

### Lücken in den Texten

- `Weather/Views/InformationSheet.swift:20` („Karte und Ortssuche: Apple MapKit“) und `:25` („Karten und Suchanfragen werden von Apple verarbeitet … IP-Adresse“) sowie `PlacesSheet.swift:81` („Die Suche verwendet Apple-Kartendienste“) nennen Apple bereits. Der In-App-Text ist hier ausreichend; er sagt aber nicht, **was** an Apple geht (Suchtext, Kartenausschnitt) und dass ShowerNow dort nichts speichert/einsieht (ANNAHME, siehe unten).
- `docs-site/content/datenschutz.md` (Z. 5-14) und die Backend-Seite `/datenschutz` (`SitePages.swift` Z. 113-139, Abschnitte 4-5) erwähnen Apple **nur** für die lokale KI-Einordnung (Z. 136). **Keine Nennung** der Apple-Ortssuche und der Apple-Karten (Kacheln). Das ist die eigentliche Lücke: Die verlinkte Datenschutzerklärung (`RadarBackendConfig.privacyPolicyURL`, `RadarBackend.swift:16`) ist unvollständig gegenüber der App.
- Kleine Unschärfe: Die Seiten sagen „Standort … für die Prognose wird nur der Punkt an den DWD gesendet“, ohne Hinweis, dass eine gesuchte Adresse zuvor als Suchtext an Apple ging.

### Textvorschlag (Zusatzabsatz, Deutsch)

> **Kartenansicht und Ortssuche (Apple).** Die Karte und die Ortssuche der App nutzen Apple MapKit. Für die Basiskarte lädt dein Gerät Kartenkacheln für den angezeigten Ausschnitt direkt von Apple. Wenn du nach einem Ort suchst, sendet die App deinen Suchtext und einen festen Suchbereich (Deutschland) an Apple. Dabei sieht Apple technisch bedingt deine IP-Adresse. ShowerNow selbst erhält und speichert diese Suchanfragen nicht und gibt sie nicht weiter. Es gelten die Datenschutzhinweise von Apple. Ein per Suche, langem Druck auf die Karte oder Standortfunktion gewählter Punkt wird nur lokal gespeichert; an den DWD geht für die Prognose lediglich dieser Punkt.

Annahmen im Absatz: (1) Kartenkacheln werden von Apple-Servern geladen (Verhalten von `MKMapView`, nicht im Repo belegt); (2) „erhält ShowerNow nicht“ gilt, solange kein eigener Proxy dazwischen liegt (im Code kein Proxy für Suche/Karte). Zusätzlich zu prüfen: ob Apple die Daten laut eigener Dokumentation pseudonym behandelt, bevor der Satz zu Apples Verarbeitung ergänzt wird. Keine Rechtsberatung; Betreiber-Freigabe nötig.

### Auswirkung auf die App-Privacy-Antwort

Stand: Variante A „Data Not Collected“ empfohlen (`docs/apple-externe-tests.md:112`), Variante B (Location angeben) als vorsichtige Alternative.

- Der Befund ändert die Empfehlung **nicht**: Laut dortiger Apple-Definition [Q7] muss bei Apple-Diensten wie MapKit nicht der Entwickler Angaben machen (`apple-externe-tests.md:108`); Suchtext und Kartenausschnitt gehen an Apple, nicht an einen Server, auf den ShowerNow zugreift. Es kommt kein neuer Datentyp hinzu, weil ShowerNow Suchtext und Koordinaten weder empfängt noch speichert.
- Was sich ändert: (1) Die Datenschutzerklärung (Website/Backend-Seite) muss um den obigen Absatz ergänzt werden, damit sie mit der App und der Privacy-Antwort konsistent ist (Guideline 5.1.1(i), Offenlegung). (2) Die Begründung in `apple-externe-tests.md` sollte „Suchtext und Karte laufen über Apple MapKit“ ausdrücklich aufnehmen. (3) Die offene Frage zur Proxy-Protokollierung der IP bleibt der eigentliche Kipppunkt für A (`apple-externe-tests.md:114`), nicht die Ortssuche.
- Die Bewertung bleibt UNKLAR, soweit Apple die Praxis im Review auslegt; Entscheidung beim Betreiber.

## Nicht geprüft

- Kein Build, kein Test, kein Simulator; die Meldung wurde nicht reproduziert (nur Fehlerformen gemessen).
- Keine Messung über längere Zeit/Tageszeiten; keine Messung mit anderen Orten, anderem Laufstand oder Mobilfunk.
- Apples Dokumentation zu MapKit-/MKLocalSearch-Datenverarbeitung nicht gelesen; Kachelabruf als Annahme.
- Keine Prüfung von Info.plist/Privacy-Manifest (keine `.xcprivacy` im Repo gefunden; ob eines nötig ist, nicht geprüft).
- Backend-Seite nur im Quellcode gelesen, nicht live abgerufen.
