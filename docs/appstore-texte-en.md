# App-Store-Texte Englisch (Großbritannien), Entwurf

**ENTWURF, NICHT FREIGEGEBEN.** Nichts in App Store Connect eingetragen. Die Texte zu Datenschutz und Warnungen gehen erst nach ausdrücklicher Nutzerfreigabe live (Warn-Push ist serverseitig aus; Datenschutztext siehe `datenschutz-entwurf-release.md`, Entwurf, nicht live). Deutsche Gegenstücke: `appstore-screenshots.md` (Abschnitt "Textvorschläge", Stand 4.11.). Stand 9.11.2026. Vorlage für die Locale "English (U.K.)"; britische Schreibung ("centre", "labelled"). Muttersprachlerprüfung offen. Verlinkt aus `app-store-release-checkliste.md`.

Zeichenzahlen mit `python3` gezählt (Zeichen und UTF-8-Bytes; alle Texte reines ASCII, daher gleich). Grenzen: Name 30, Untertitel 30, Werbetext 170, Keywords 100 Bytes, Beschreibung 4000.

## App-Name
`Showers` (7 Zeichen)

## Untertitel (26 Zeichen, 26 Bytes, max. 30)
`Rain radar with a timeline`

## Werbetext (159 Zeichen, 159 Bytes, max. 170)
`See when and where it rains: radar with a timeline, forecasts for your places, temperature and humidity maps, DWD warnings, widgets and Apple Watch. Data: DWD.`

## Keywords (98 Zeichen, 98 Bytes, max. 100, kommagetrennt, ohne Leerzeichen nach Komma)
`precipitation,forecast,weather,widget,watch,temperature,humidity,dew point,frost,DWD,Germany,storm`

Ohne "Showers", "rain", "radar", "timeline" (Name/Untertitel). "dew point" enthält ein Leerzeichen innerhalb eines Begriffs; bei Bedarf durch "dewpoint" ersetzen. Suchwirkung ungeprüft.

## Beschreibung (2092 Zeichen, 2092 Bytes, max. 4000)
```
Showers shows you when and where it rains in Germany.

RAIN RADAR WITH A TIMELINE
Scrub through the timeline to see the recent past and the short-term development of rain on the map. The app shows when the data was last updated and whether you are looking at a measurement or a forecast.

TEMPERATURE AND HUMIDITY MAPS
Switch the map to temperature, dew point or, where available, relative humidity. These layers are model values from the Deutscher Wetterdienst (DWD) and are labelled as such. Tap the map to read a value, or let VoiceOver read the value at the centre of the map.

WARNINGS FROM THE DWD
The Warnings page lists warnings issued by the Deutscher Wetterdienst for storms, frost and ice, grouped by your saved places. Each warning is shown with its source and the time of the data. Showers is not an official warning app and does not replace official channels such as the DWD itself, radio, or the authorities. In an emergency, follow official instructions.

YOUR PLACES AND REGIONS
Save places and regions, such as a circle around a point, and see a short-term rain forecast for each one. Your saved places and their names stay on your device.

OPTIONAL RAIN ALERTS
If you like, Showers can send a notification when rain is about to start at one of your places. This is voluntary and can be revoked in the app at any time.

WIDGETS, LIVE ACTIVITY AND APPLE WATCH
Keep an eye on the rain with widgets and a Live Activity, and check compact place forecasts on your Apple Watch.

DESIGNED FOR PRIVACY
- No user account, no advertising, no tracking, no analytics SDKs.
- Radar requests contain no location, no cookies and no identifier.
- Saved places with their names and your settings stay on your device.

DESIGN
Showers is built natively for iPhone, iPad and Apple Watch, with a light and a dark appearance.

DATA SOURCES
Weather data: Deutscher Wetterdienst (DWD). The Warnings page shows the DWD source with each warning. Further sources and credits are listed in the app under Information.

Showers is an independent app and is not affiliated with the Deutscher Wetterdienst.
```

## Was ist neu (erste Version, 321 Zeichen, 321 Bytes)
```
First release of Showers.

- Rain radar for Germany with an animated timeline
- Forecasts for your saved places and regions
- Temperature and humidity maps (model values)
- Official DWD warnings for storms, frost and ice, shown with their source
- Widgets, Live Activity and Apple Watch
- Optional rain alerts (voluntary)
```

## URLs und Kategorie (Hinweise)
- Support-URL `https://showers.linolaske.de/support` (laut Checkliste HTTP 200, E-Mail mail@linolaske.de), Marketing-URL `https://showers.linolaske.de/marketing`, Datenschutz-URL `https://showers.linolaske.de/datenschutz`. Englische Webseitenfassungen (Datenschutz/Support/Impressum) fehlen laut Checkliste noch (Backend-Repo, E4); bis dahin zeigen die URLs deutschen Inhalt.
- Kategorie: Wetter (Annahme laut `apple-externe-tests.md`). Altersfreigabe-Fragebogen, Copyright, Preis: Nutzeraufgaben, nicht Teil dieses Entwurfs.
- Quellenangabe: "Deutscher Wetterdienst (DWD)" steht im Text. ESA WorldCover (Waldebene) steht nicht im Store-Text; die Pflichtangabe liegt in der App-Quellzeile bei eingeblendetem Wald und im Info-Sheet, der Text verweist darauf ("listed in the app under Information").

## Belege und Grenzen der Aussagen
- Funktionsumfang laut `status.md`/`decisions.md`: Radar mit Zeitleiste, Temperatur/Taupunkt/Feuchte (Modellwerte; relative Feuchte nur, wenn der Server die Ebene liefert, daher "where available"), Wertabfrage per Tippen/VoiceOver, Warnungen-Seite (Unwetter, Frost, Glätte; nach Ort gruppiert; Quelle je Warnung), Orte und Regionen (Umkreis), Regen-Push (Opt-in), Widgets, Live Activity, Watch.
- Absichtlich NICHT behauptet: Warn-Push (serverseitig aus, wartet auf DWD-Antwort und Datenschutzfreigabe), "amtliche Warn-App", Gefühlstemperatur, Feuchte-Wörter, Watch-Radarkarte, Mac, Abdeckung außerhalb Deutschlands.
- Datenschutzzeilen aus `datenschutz-entwurf-release.md` Teil A-EN, Abschnitt 2 "Overview": "No user account, no advertising, no tracking, no analytics SDKs." und "Saved places with their names and your settings stay on your device." wortgleich; "Radar requests contain no location, no cookies and no identifier." ist ein Teilsatz des zweiten Aufzählungspunkts (der dort zusätzlich die IP-Protokollierung des Reverse Proxy nennt, siehe Abschnitt 3). "voluntary and can be revoked in the app at any time" ist dem dritten Punkt entnommen. Nichts Neues behauptet; Freigabe des Datenschutztextes steht aus, Teilsatz-Kürzung ggf. vor Freigabe prüfen.
- Live Activity und Regen-Push hängen am Backend-Rollout (Checkliste "APNs-Key/Backend-Push live: unklar"); vor Einreichung gegen den tatsächlichen Stand prüfen. Dynamic Type wird bewusst nicht beworben (nur indirekt belegt).

## Abweichungen der deutschen Texte (nur Hinweis, nicht geändert)
Die deutschen Vorschläge (Stand 4.11., Build 17) sind veraltet:
- Werbetext und Beschreibung nennen weder Temperatur-/Feuchtekarte (ab Build 37) noch die Warnungen-Seite (Unwetter/Frost/Glätte) noch Live Activity (der Vorschlag schloss sie ausdrücklich aus).
- Die Beschreibung nennt Wolken/Satellit als Ebene und "Regenhinweis per Push" ohne Opt-in-Hinweis; "Watch (Radarkarte als Vorschau)" ist nicht mehr belegt.
- Keywords (99 Bytes) enthalten weder Temperatur noch Taupunkt/Frost; "Satellit"/"Wolken" passen nicht mehr zum Schwerpunkt.
- Der Untertitel "Regen im Blick, für deine Orte" liegt mit 30 Zeichen exakt am Limit.
Vorschlag: deutsche Fassung parallel zu dieser neu fassen (separater Auftrag).
