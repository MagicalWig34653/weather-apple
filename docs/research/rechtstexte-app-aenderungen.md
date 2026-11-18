# Rechtstexte: Änderungsvorschläge für App-Texte (18.11.2026)

> KI-gestützte Plausibilitätsprüfung, keine Rechtsberatung. Grundlage: [rechtspruefung-entscheidungen.md](rechtspruefung-entscheidungen.md). **Nicht umgesetzt:** Die App-Strings wurden nicht geändert, weil jede Änderung einen Build braucht und mehrere Punkte von Linos Bestätigung abhängen (Zoraxy-Statistik). Umsetzung als eigene App-Aufgabe; danach `tools/check_l10n.sh --strict`.

Gelesen: `Weather/Resources/{de,en}.lproj/Localizable.strings` auf main `eece1e9`, `release/build-49` (`359bc84`) und `origin/feature/setup-wizard` (`de6527c`), `Weather/Resources/de.lproj/InfoPlist.strings`. Bei Strings mit `NSLocalizedString(..., value:)` im Swift-Code ist der Standardwert dort mitzuändern.

| # | Schlüssel (Datei/Zweig) | Grund | Dringlichkeit |
|---|---|---|---|
| 1 | `INFO_PRIVACY_3` (main) | Sagt „befristet protokolliert“; seit 13.11. protokolliert der Proxy nicht mehr (E1) | vor Livegang, sobald Zoraxy-Statistik bestätigt aus |
| 2 | `PUSH_PLACE_CONFIRM_MESSAGE` (main) | Einwilligungsdialog nennt die Installationskennung nicht und keinen Widerruf (Art. 7 Abs. 3 Satz 3 DSGVO) | nächster Build |
| 3 | `REGION_EXPLANATION` (main) | wie 2 | nächster Build |
| 4 | `SETUP_ALERT_BODY` (setup-wizard) und Ablauf des Schritts | „nur das Gerätetoken …“ unvollständig (Installationskennung fehlt), kein Widerruf; Orte vorausgewählt, kein Bestätigungsdialog | vor Merge des Wizards |
| 5 | `SETUP_LOCATION_BODY` (setup-wizard) | „Der Standort bleibt auf dem Gerät“ stimmt nicht: Der Punkt geht für die Prognose an den DWD | vor Merge des Wizards |
| 6 | `SETUP_PLACES_PRIVACY` (setup-wizard) | Apple Watch fehlt (Orte werden an die gekoppelte Uhr übertragen, `INFO_WIDGETS_2`) | gering |
| 7 | `PUSH_INSTALLATION_ID_HINT` (main) | siezt, Rest der App duzt; kein Rechtsproblem | gering |

Unverändert lassen (geprüft, ohne Befund): `INFO_PRIVACY_1`, `_2`, `_4`, `_5`, `_6`, `INFO_PRIVACY_LOCATION`, `DEVICE_LINK_FOOTER`/`_PRIVACY` (E3 umgesetzt), `PUSH_PLACE_PRIVACY`, `REGION_PRIVACY_FOOTNOTE`, `RAIN_ACTIVITY_PRIVACY`, `RAIN_ACTIVITY_REGION_PRIVACY`, `NSLocationWhenInUseUsageDescription` (de/en), `PUSH_SENSITIVITY_*` und `PUSH_SENSITIVITY_HINT` (Build 49, ohne Datenschutzbezug), `RADAR_FORECAST_CAPTION_*`/`RADAR_DETAILS_SERVER_BEHIND` (Build 49), `SETUP_WELCOME_*`, `SETUP_ALERT_PROMPT_NOTE`, `LEGEND_RADAR_EU_HINT`, `LEGEND_RADAR_WORLD_HINT`, `INFO_LAYER_SOURCES_NOTE`, `INFO_MODEL_ICON`, `INFO_MODEL_FOREST`, `INFO_SOURCES_*`, `STORE_ATTRIBUTION`, `STORE_MODIFICATION_NOTICE`. Die Quellzeile für Regen Europa kommt aus dem Backend-Manifest (`OperaRender.attribution`: „Radardaten Europa: EUMETNET OPERA (CIRRUS), CC BY 4.0, Quelle: MeteoGate; umprojiziert und eingefärbt.“, origin/main 230be1a) und erfüllt Namensnennung, Lizenzhinweis und Änderungshinweis.

## 1. `INFO_PRIVACY_3`

```diff
-"INFO_PRIVACY_3" = "… Ihm ist ein Reverse Proxy vorgeschaltet, der technisch bedingt die IP-Adresse jedes Abrufs sieht und sie befristet protokolliert; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. …";
+"INFO_PRIVACY_3" = "… Ihm ist ein Reverse Proxy vorgeschaltet, der technisch bedingt die IP-Adresse jedes Abrufs sieht, sie aber nicht protokolliert; die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung. …";
```
en:
```diff
-… it technically sees the IP address of every request and logs it for a limited time. …
+… it technically sees the IP address of every request but does not log it. …
```
Der Rest des Strings bleibt. Gilt erst, wenn Request-Logging und Statistik in Zoraxy aus sind.

## 2. `PUSH_PLACE_CONFIRM_MESSAGE`

```diff
-"PUSH_PLACE_CONFIRM_MESSAGE" = "Showers meldet dir per Mitteilung, wenn es bei %@ bald zu regnen beginnt. Dafür gehen an den Showers-Server: das Gerätetoken, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Danach fragt iOS, ob Mitteilungen erlaubt sind.";
+"PUSH_PLACE_CONFIRM_MESSAGE" = "Showers meldet dir per Mitteilung, wenn es bei %@ bald zu regnen beginnt. Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Mit „Weiter“ willigst du ein. Ausschalten widerruft das jederzeit und löscht die Daten auf dem Server. Danach fragt iOS, ob Mitteilungen erlaubt sind.";
```
en:
```diff
-"… the device token, the radar grid cell (edge length about 0.7 km, no coordinates), threshold and lead time; no account. iOS then asks whether notifications are allowed.";
+"… the device token, a random installation ID, the radar grid cell (edge length about 0.7 km, no coordinates), threshold and lead time; no account. By tapping “Continue” you consent. Turning it off withdraws consent at any time and deletes the data on the server. iOS then asks whether notifications are allowed.";
```
Der Knopftitel `PUSH_CONTINUE` heißt de „Weiter“, en „Continue“ (geprüft).

## 3. `REGION_EXPLANATION`

```diff
-"REGION_EXPLANATION" = "Showers meldet dir per Mitteilung, wenn Regen diese Region erreicht. Dafür gehen an den Showers-Server: das Gerätetoken, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km, keine Koordinaten), der Radius, Schwelle, Auslöseanteil und Vorlaufzeit; kein Konto, kein Name. Danach fragt iOS, ob Mitteilungen erlaubt sind.";
+"REGION_EXPLANATION" = "Showers meldet dir per Mitteilung, wenn Regen diese Region erreicht. Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, der Mittelpunkt gröber als eine Rasterzelle (etwa 2 km, keine Koordinaten), der Radius, Schwelle, Auslöseanteil und Vorlaufzeit; kein Konto, kein Name. Mit „Weiter“ willigst du ein. Ausschalten widerruft das jederzeit und löscht die Daten auf dem Server. Danach fragt iOS, ob Mitteilungen erlaubt sind.";
```
en: dieselben zwei Ergänzungen wie in 2.

## 4. `SETUP_ALERT_BODY` (Branch `feature/setup-wizard`)

```diff
-"SETUP_ALERT_BODY" = "Wir melden dir, wenn an deinem Ort Regen beginnt. Dafür gehen an den Showers-Server nur das Gerätetoken, die Rasterzelle des Radarbildes (etwa 0,7 km Kantenlänge) sowie Schwelle und Vorlaufzeit. Kein genauer Standort, kein Ortsname, kein Konto.";
+"SETUP_ALERT_BODY" = "Wir melden dir, wenn an deinem Ort Regen beginnt. Dafür gehen an den Showers-Server das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (etwa 0,7 km Kantenlänge) sowie Schwelle und Vorlaufzeit. Kein genauer Standort, kein Ortsname, kein Konto. Du kannst das jederzeit ausschalten; dann werden die Daten auf dem Server gelöscht.";
```
en:
```diff
-"We tell you when rain is about to start at your place. Only the device token, the radar grid cell (about 0.7 km wide) and threshold and lead time go to the Showers server. No exact location, no place name, no account.";
+"We tell you when rain is about to start at your place. The device token, a random installation ID, the radar grid cell (about 0.7 km wide) and threshold and lead time go to the Showers server. No exact location, no place name, no account. You can turn this off at any time; the data on the server is then deleted.";
```
**Befund im Code (gelesen, `Weather/Setup/SetupWizardView.swift` auf `de6527c`):** Der Wizard ruft `push.enable` direkt auf, ohne den Bestätigungsdialog aus 2, und wählt bis zu drei gespeicherte Orte vorab aus (`prepareStep`, `selectedAlertPlaces`). Damit ist `SETUP_ALERT_BODY` die einzige Einwilligungsinformation und muss vollständig sein. Zusätzlich vor dem Merge des Wizards (App-Aufgabe, nicht Text): (a) Orte **nicht** vorauswählen oder den Knopf auf diesem Schritt eindeutig benennen, etwa „Regenhinweise einschalten“ statt „Weiter“; eine vorausgewählte Auswahl gilt nach EuGH C-673/17 „Planet49“ nicht als Einwilligung (Annahme zur Übertragbarkeit, Urteil aus Kenntnis zitiert, nicht abgerufen). (b) Einen Link „Datenschutzerklärung lesen“ (`PUSH_READ_PRIVACY`) auf diesem Schritt anbieten. Risiko ohne (a): mittel. Der Titel „Regenwarnung“ (`SETUP_ALERT_TITLE`) weicht vom sonst üblichen „Regenhinweis“ ab; „Warnung“ kann mit amtlichen DWD-Warnungen verwechselt werden. Vorschlag: „Regenhinweis“ / „Rain alert“ (en bleibt).

## 5. `SETUP_LOCATION_BODY` (Branch `feature/setup-wizard`)

```diff
-"SETUP_LOCATION_BODY" = "Für Karte und Prognose an deinem Ort. Der Standort bleibt auf dem Gerät. Showers fragt nur nach dem Standort, während die App geöffnet ist.";
+"SETUP_LOCATION_BODY" = "Für Karte und Prognose an deinem Ort. Für die Prognose geht nur der Punkt an den Deutschen Wetterdienst, nicht an Showers. Showers fragt nur nach dem Standort, während die App geöffnet ist.";
```
en:
```diff
-"For the map and forecast at your place. Your location stays on the device. Showers only asks for it while the app is open.";
+"For the map and forecast at your place. For the forecast, only the point goes to the German Weather Service (DWD), not to Showers. Showers only asks for it while the app is open.";
```

## 6. `SETUP_PLACES_PRIVACY` (Branch `feature/setup-wizard`)

```diff
-"SETUP_PLACES_PRIVACY" = "Orte bleiben auf diesem Gerät. Die Suche nutzt Apple-Kartendienste.";
+"SETUP_PLACES_PRIVACY" = "Orte bleiben auf diesem Gerät und deiner Apple Watch. Die Suche nutzt Apple-Kartendienste.";
```
en: `"Places stay on this device and your Apple Watch. Search uses Apple Maps services."`

## 7. `PUSH_INSTALLATION_ID_HINT`

```diff
-"PUSH_INSTALLATION_ID_HINT" = "Nennen Sie diese Kennung bei einer Auskunftsanfrage.";
+"PUSH_INSTALLATION_ID_HINT" = "Nenne diese Kennung bei einer Auskunftsanfrage.";
```
en: `"Please state this ID when you make an access request."` bleibt.

## Nicht geprüft

Laufzeitdarstellung (Abschneiden langer Texte in Dialogen, Dynamic Type); vom Wizard-Code nur der Regenhinweis-Schritt gelesen. Keine Builds, keine Tests.
