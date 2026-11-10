# Bereinigung nutzersichtbarer Texte (10.11.2026)

Auftrag: Projekt-/Entwicklerjargon, Diagnose-Text und ungenaue Datenschutzaussagen aus App-Texten entfernen. Geprüft: alle `Localizable.strings` (Weather, Widgets, Watch, Watch-Widgets), `InfoPlist.strings`, Info-Sheet, Mitteilungen, Warnungen, Fehlertexte, Intents, User-Agent. Datenschutz-Referenz: `docs/datenschutz-entwurf-release.md` Teil A (de) und A-EN (en). Alle Änderungen de und en, Schlüssel unverändert. Zeilen beziehen sich auf `Weather/Resources/de.lproj/Localizable.strings` (en gleiche Zeile).

## Fundliste (alt -> neu)

Jargon und Zwischenstand
- Z.28 `INFO_INTRO_2`: "Frühe Testversion: Prognosen können abweichen, ..." -> "Prognosen können abweichen, bitte das Datenalter beachten."
- Z.451 `INFO_PRIVACY_BETA`: "Die App ist eine frühe Testversion. ... wird keine aktuelle Aussage zugesichert." -> "Prognosen können abweichen. Bei fehlenden oder veralteten Daten gibt die App keine aktuelle Aussage."
- Z.452 `INFO_SUPPORT_FOOTER`: "Showers · frühe Testversion" -> "Showers"
- Z.189 `RADAR_SOURCE_CACHE` ("Showers-Cache", sichtbar in Quellzeile und Prognosedetails): -> "über Showers" / "via Showers"
- Z.516 `STORE_RADAR_CACHE_DOWN`: "Radar-Cache nicht erreichbar. Radar kommt direkt vom DWD." -> "Der Showers-Radar-Dienst ist gerade nicht erreichbar. Die Radarbilder kommen direkt vom DWD."
- Z.325/400 `REGION_UNSUPPORTED`, `PUSH_MSG_REGIONS_UNSUPPORTED`: "Server unterstützt noch keine Regionen." -> "Regionen sind derzeit nicht verfügbar."
- Z.504 `INTERP_LANGUAGE_UNSUPPORTED`: "... unterstützt Deutsch hier noch nicht." -> "... ist in dieser Sprache nicht verfügbar."
- Z.507 `INTERP_MODEL_NOT_READY`: "... Apple-Modell ist noch nicht bereit." -> "... wird noch vorbereitet. Bitte später erneut versuchen."
- Z.129 `LAYER_SCALE_UNKNOWN`: "... in dieser App-Version noch nicht hinterlegt ..." -> "Für diese Datenquelle gibt es keine Farbskala, daher keine Legende, nur diesen Hinweis. ..."
- Z.457 `INFO_PAST_FOOTER_UNAVAILABLE`: "vorerst" -> "derzeit"
- Z.453 `INFO_LAYER_SOURCES_NOTE`: "liefert der Showers-Server nur, wenn sie dort aktiviert sind" -> "liefert der Showers-Radar-Dienst ... Ein Direktabruf beim DWD ist dafür nicht vorgesehen."
- Z.384 `RAIN_ACTIVITY_UNAVAILABLE`: "Der Server muss sie unterstützen ..." -> "Prüfe, ob sie in den Systemeinstellungen erlaubt sind."
- `ShowerNow/0.1`, `Weather/0.1` als User-Agent (an DWD, `RadarMap`, `RadarPrefetch`, `DWDClient`) -> "Showers (native iOS rain radar)"

Test-/Betriebsfehler (Apple-Zugang, Schlüssel, Umgebung sind Betreiberinterna)
- Z.422-428 `PUSH_TEST_ENVIRONMENT`, `_APNS_503`, `_BAD_TOKEN`, `_KEY_REJECTED`, `_APNS_REJECTED`: "App-Variante (Entwicklung oder Store)", "Apple-Zugang nicht eingerichtet", "Zugangsschlüssel ... muss der Betreiber beheben" -> neutrale Meldungen ("Die Testmeldung konnte nicht zugestellt werden. Bitte später erneut versuchen." bzw. "Gerät wird neu registriert").

Diagnose (Info, Widgets)
- Z.528-534 `INFO_WIDGET_DIAG_*`: Titel "Widget-Diagnose" -> "Diagnose"; "Letzter Widget-Lauf" -> "Widget zuletzt aktualisiert"; "Datenstand im Widget" -> "Datenstand"; "Angeforderter nächster Lauf" -> "Nächste Aktualisierung angefordert"; "Live abgerufen / Aus dem Speicher" -> "neu geladen / gespeicherte Prognose".
- Watch-Widgets (de) "DWD · Gesichert" -> "DWD · Gespeichert".

Datenschutzaussagen im Info-Sheet, auf Teil A angeglichen
- `INFO_PRIVACY_1`: "... nicht an den Showers-Server übertragen" war ungenau (Regenhinweise senden eine Rasterzelle) -> Teil A Abschnitt 2/6: Orte, Namen, Einstellungen bleiben auf dem Gerät; nur bei Regenhinweisen geht eine gröbere Ortsangabe an den Radar-Dienst.
- `INFO_PRIVACY_3`: "vorgeschalteter Server sieht die IP" -> Teil A Abschnitt 3: Reverse Proxy sieht die IP und protokolliert sie befristet; "Showers-Radar-Server/Showers-Server" -> "Radar-Dienst".
- `INFO_PRIVACY_4`: "erhält der DWD weiterhin einen Kartenausschnitt um die Position" -> Teil A Abschnitt 4: abgefragter Punkt und IP sind für den DWD sichtbar.
- `INFO_PRIVACY_6`, `PUSH_PLACE_PRIVACY`, `PUSH_PLACE_CONFIRM_MESSAGE`: "Rasterzelle von etwa 1 km" -> Teil A Abschnitt 5: "Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km)".

## Geprüft, bewusst unverändert
- "Betreiber-Diagnose" (Geräte-Kopplung): entspricht Teil A Abschnitt 11, UI-Test hängt daran.
- "Testmeldung senden": echte Funktion (Teil A Abschnitt 5).
- Widget-Kind-Kennungen `ShowerNowForecast`, `ShowerNowWatchForecast`: intern, nicht sichtbar; Umbenennung würde bestehende Widgets zurücksetzen.
- Info.plist/InfoPlist.strings (Standort): unauffällig. Widgets, Watch, Intents, Warnungen, Warn-Push: kein Jargon gefunden.
- Seiten Datenschutz/Support/Impressum werden vom Backend geliefert (`SitePages.swift` im Backend): nicht Teil der App.

## Hinweis für das Backend (nicht in der App umgangen)
Falls Radar-Manifest (`attribution`/`modificationNotice`) oder Webseiten noch "Showers-Cache" oder "ShowerNow" nach außen führen, dort auf "Showers" ändern; die App zeigt Manifest-Quellenvermerke unverändert an.
