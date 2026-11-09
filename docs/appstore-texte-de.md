# App-Store-Texte Deutsch, Entwurf

**ENTWURF, NICHT FREIGEGEBEN.** Nichts in App Store Connect eingetragen. Die Texte zu Datenschutz und Warnungen gehen erst nach ausdrücklicher Nutzerfreigabe live (Warn-Push ist serverseitig aus; Datenschutztext siehe `datenschutz-entwurf-release.md`, Entwurf, nicht live). Stand 9.11.2026. Inhaltsgleich zum englischen Entwurf [appstore-texte-en.md](appstore-texte-en.md); ersetzt die überholten Textvorschläge (Build 17) in `appstore-screenshots.md`. Verlinkt aus `app-store-release-checkliste.md`. Locale "Deutsch".

Zeichen und UTF-8-Bytes mit `python3` gezählt. Grenzen: Name 30, Untertitel 30, Werbetext 170, Keywords 100 Bytes, Beschreibung 4000. Umlaute zählen 2 Bytes (relevant für Keywords).

## App-Name
`Showers` (7 Zeichen)

## Untertitel (25 Zeichen, 25 Bytes, max. 30)
`Regenradar mit Zeitleiste`

## Werbetext (156 Zeichen, 157 Bytes, max. 170)
`Sieh, wann und wo es regnet: Radar mit Zeitleiste, Prognosen für deine Orte, Temperatur- und Feuchtekarten, DWD-Warnungen, Widgets, Apple Watch. Daten: DWD.`

(Das "ü" in "für" ergibt 1 Byte Differenz; für den Werbetext zählt die Zeichenzahl.)

## Keywords (100 Zeichen, 100 Bytes, max. 100 Bytes, kommagetrennt, ohne Leerzeichen nach Komma)
`Niederschlag,Prognose,Wetter,Widget,Watch,Temperatur,Feuchte,Taupunkt,Frost,DWD,Deutschland,Unwetter`

Ohne "Showers", "Regenradar", "Zeitleiste" (Name/Untertitel). Alle Begriffe ASCII, daher Zeichen = Bytes; die Grenze ist exakt ausgereizt, jede Änderung mit Umlaut (z. B. "Glätte") kostet 2 Bytes und erfordert ein Streichen. Suchwirkung ungeprüft. Englische Keywords der EN-Locale ("precipitation", "forecast" usw.) zählen in Deutschland ebenfalls mit; Doppelungen zwischen Locales sind unnötig.

## Beschreibung (2362 Zeichen, 2374 Bytes, max. 4000)
```
Showers zeigt dir, wann und wo es in Deutschland regnet.

REGENRADAR MIT ZEITLEISTE
Wische über die Zeitleiste und sieh auf der Karte den Regen der jüngsten Vergangenheit und die kurzfristige Entwicklung. Die App zeigt, wann die Daten zuletzt aktualisiert wurden und ob du eine Messung oder eine Vorhersage siehst.

TEMPERATUR- UND FEUCHTEKARTEN
Schalte die Karte auf Temperatur, Taupunkt oder, wo verfügbar, relative Feuchte um. Diese Ebenen sind Modellwerte des Deutschen Wetterdienstes (DWD) und als solche gekennzeichnet. Tippe auf die Karte, um einen Wert abzulesen, oder lass dir mit VoiceOver den Wert in der Kartenmitte vorlesen.

WARNUNGEN DES DWD
Die Seite Warnungen listet vom Deutschen Wetterdienst herausgegebene Warnungen vor Unwetter, Frost und Glätte, gruppiert nach deinen gespeicherten Orten. Jede Warnung wird mit ihrer Quelle und dem Datenstand angezeigt. Showers ist keine amtliche Warn-App und ersetzt keine amtlichen Kanäle wie den DWD selbst, den Rundfunk oder die Behörden. Im Ernstfall folge den amtlichen Anweisungen.

DEINE ORTE UND REGIONEN
Speichere Orte und Regionen, zum Beispiel einen Umkreis um einen Punkt, und sieh für jeden eine kurzfristige Regenprognose. Deine gespeicherten Orte und ihre Namen bleiben auf deinem Gerät.

OPTIONALE REGENHINWEISE
Wenn du möchtest, schickt dir Showers eine Mitteilung, kurz bevor es an einem deiner Orte zu regnen beginnt. Das ist freiwillig und jederzeit in der App widerrufbar.

WIDGETS, LIVE ACTIVITY UND APPLE WATCH
Behalte den Regen mit Widgets und einer Live Activity im Blick und sieh kompakte Ortsprognosen auf deiner Apple Watch.

MIT DATENSCHUTZ GEDACHT
- Kein Benutzerkonto, keine Werbung, kein Tracking, keine Analyse-SDKs.
- Die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Technisch bedingt sieht der vorgeschaltete Reverse Proxy die IP-Adresse und protokolliert sie befristet.
- Gespeicherte Orte mit ihren Namen und deine Einstellungen bleiben auf deinem Gerät.

GESTALTUNG
Showers ist nativ für iPhone, iPad und Apple Watch gebaut, mit hellem und dunklem Erscheinungsbild.

DATENQUELLEN
Wetterdaten: Deutscher Wetterdienst (DWD). Die Seite Warnungen zeigt bei jeder Warnung die DWD-Quelle. Weitere Quellen und Nachweise stehen in der App unter Information.

Showers ist eine unabhängige App und steht in keiner Verbindung zum Deutschen Wetterdienst.
```

## Was ist neu (erste Version, 346 Zeichen, 350 Bytes)
```
Erste Veröffentlichung von Showers.

- Regenradar für Deutschland mit animierter Zeitleiste
- Prognosen für deine gespeicherten Orte und Regionen
- Temperatur- und Feuchtekarten (Modellwerte)
- Amtliche DWD-Warnungen vor Unwetter, Frost und Glätte, mit Quellenangabe
- Widgets, Live Activity und Apple Watch
- Optionale Regenhinweise (freiwillig)
```

## URLs und Kategorie (Hinweise)
- Support-URL `https://showers.linolaske.de/support` (laut Checkliste HTTP 200, E-Mail mail@linolaske.de), Marketing-URL `https://showers.linolaske.de/marketing`, Datenschutz-URL `https://showers.linolaske.de/datenschutz` (deutsche Fassung vorhanden; Erreichbarkeit und Zertifikat nicht von mir geprüft).
- Kategorie: Wetter (Annahme laut `apple-externe-tests.md`). Altersfreigabe-Fragebogen, Copyright, Preis: Nutzeraufgaben, nicht Teil dieses Entwurfs.
- Quellenangabe: "Deutscher Wetterdienst (DWD)" steht im Text. ESA WorldCover (Waldebene) steht nicht im Store-Text; die Pflichtangabe liegt in der App-Quellzeile bei eingeblendetem Wald und im Info-Sheet, der Text verweist darauf ("in der App unter Information").

## Belege und Grenzen der Aussagen
- Funktionsumfang laut `status.md`/`decisions.md`: Radar mit Zeitleiste, Temperatur/Taupunkt/Feuchte (Modellwerte; relative Feuchte nur, wenn der Server die Ebene liefert, daher "wo verfügbar"), Wertabfrage per Tippen/VoiceOver, Warnungen-Seite (Unwetter, Frost, Glätte; nach Ort gruppiert; Quelle je Warnung), Orte und Regionen (Umkreis), Regenhinweise (Opt-in), Widgets, Live Activity, Watch.
- Absichtlich NICHT behauptet: Warn-Push (serverseitig aus), "amtliche Warn-App", Gefühlstemperatur, "schwül", Watch-Radarkarte, Mac, Abdeckung außerhalb Deutschlands.
- Datenschutzzeilen wortgleich zu `datenschutz-entwurf-release.md` Teil A, Abschnitt 2 "Überblick": "Kein Benutzerkonto, keine Werbung, kein Tracking, keine Analyse-SDKs." und "Gespeicherte Orte mit ihren Namen und deine Einstellungen bleiben auf deinem Gerät." sowie vom zweiten Punkt der vollständige Satzteil "Die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. Technisch bedingt sieht der vorgeschaltete Reverse Proxy die IP-Adresse und protokolliert sie befristet." (nur der einleitende Bedingungssatz "Wer die App nur zum Ansehen ... nutzt" entfällt). Die Aussage "keine Kennung" wird bewusst nie ohne den Proxy-Satz verwendet, weil der Reverse Proxy die IP-Adresse protokolliert. "freiwillig und jederzeit in der App widerrufbar" stammt aus dem dritten Punkt. Freigabe des Datenschutztextes steht aus.
- Live Activity und Regenhinweise hängen am Backend-Rollout (Checkliste "APNs-Key/Backend-Push live: unklar"); vor Einreichung gegen den tatsächlichen Stand prüfen.

## Offene Punkte
1. Zusatzebenen Luftdruck, Blitze, Wolken/Sonne existieren laut `status.md` und Code (`RadarLayer.swift`) weiterhin, sind aber wie im englischen Entwurf nicht beworben (Schwerpunkt Regen, Temperatur/Feuchte). Ob sie ergänzt werden sollen, ist eine Nutzerentscheidung; die EUMETSAT-Quellenangabe wäre dann im Text nötig. Die alte Aussage "Wolken als Satellitenebene" ist bewusst entfernt.
2. Der Satz zum Reverse-Proxy-Logging ist im Datenschutz-Entwurf noch mit einem Hinweis zur Verkürzung der Aufbewahrung (14 bis 30 Tage) versehen; Wortlaut vor Freigabe gegen den Endtext des Datenschutzes abgleichen.
3. Muttersprachliche/redaktionelle Prüfung der Texte, Wortlaut "Live Activity" (Apple-Begriff, unübersetzt) und "Regenhinweise" vs. "Mitteilungen".
4. Eintrag in App Store Connect durch den Nutzer nach Freigabe.
