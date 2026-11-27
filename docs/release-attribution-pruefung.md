# Release-Prüfung: Berechtigungstexte, Attribution, Push-Entitlement (27.11.2026)

Karte 31A623B9. Reine Prüfung: kein Build, keine Textänderung, kein Deploy. KI-gestützter Abgleich, **keine Rechtsberatung**.

**Geprüfte Stände:** App `origin/main` `08b657c`; Backend `weather-backend` `origin/main` `0dc62ff`; Build 61 (0.1.1, Quelle `3f27303`). Live-Server nur per GET gelesen (27.11., ca. 17:32 bis 17:35 MEZ). Ausgangsbericht vom 19.11.: Orchestrator `runtime/nachweise/showers-quellenabgleich/berechtigungstexte-attribution.md`.

## Prüftabelle

| Punkt | Urteil |
|---|---|
| (a) Quellzeile unter dem Slider | **Abweichung vom Muster der Pflichtformel**; ob das Kürzel genügt, ist Auslegung. Entscheidung nötig. |
| (b) `INFO_PRIVACY_3` „befristet“ | **Passt zum veröffentlichten Serverstand.** Jetzt keine Änderung. |
| (c) Jahr, OPERA, NOAA auf Backend-Seiten | **Offen:** Jahr fehlt an mehreren Stellen, OPERA/NOAA auf keiner Seite. Entscheidung nötig. |
| (d) Standort- und Mitteilungstexte | Standort und Regenhinweis **ok**. **Neu: Warnungstexte unvollständig, seit Warn-Push live ist.** Entscheidung nötig. |
| (e) `aps-environment=production`, Build 61 | **Belegt** am Signaturprotokoll des Distributions-Exports; die IPA selbst liegt nicht vor. |

### (a) Quellzeile „© EUMETSAT“

- **Fundstelle:** `Weather/Data/RadarLayer.swift:207-214` (`shortAttribution`: `.clouds, .cloudmask, .cloudmaskVis` ergibt „© EUMETSAT“), angezeigt über `RadarLayer.swift:763-769` und `Weather/Views/RadarScreen.swift:592-612` (eine Zeile). Bei sichtbarer Waldfläche hängt „ · © ESA WorldCover“ an (`Weather/Map/ForestOverlay.swift:52-56`).
- **Voller Wortlaut:** unter (i) › Datenquellen je Ebene aus dem Manifest (`Weather/Views/InformationSheet.swift:174-191`). Der Verweis darauf (`RADAR_CREDIT_HINT`) ist nur ein VoiceOver-Hinweis; die Zeile ist nicht antippbar (`allowsHitTesting(false)`).
- **Live:** `GET /v1/layers/{clouds,cloudmask,cloudmask_vis,cloudmask_vis_eu}/latest.json` je HTTP 200 mit `attribution` = „Contains modified EUMETSAT Meteosat data 2026“ (Code `Layers.swift:100`).
- **Quelle:** EUMETSAT Data Policy neu abgerufen (`https://www-cdn.eumetsat.int/files/2026-01/45173%20-%20Data_Policy.pdf`, 255.942 Byte, Last-Modified 13.01.2026, SHA-256 `fa605bea…117`), Art. 6.3: „Users are required to include the following attribution to EUMETSAT in relation to EUMETSAT Data and Products, adapted as appropriate: “[Contains modified] EUMETSAT [Meteosat/Metop] [data/product] [Year of publication or distribution]”.“
- **Urteil:** Die App enthält die Formel, aber nicht an der Karte. „adapted as appropriate“ lässt Spielraum; ob „© EUMETSAT“ plus Info-Seite genügt, ist nicht belegt. Die sichere Variante ist die Manifestzeile unter dem Slider (Jahr vom Server). Ihre Darstellung (Breite, mit Waldzusatz) ist ungeprüft.

### (b) `INFO_PRIVACY_3` gegen den Serverstand

- **App:** `Weather/Resources/{de,en}.lproj/Localizable.strings:452`: Dienst ohne Zugriffsprotokolle; der Reverse Proxy sieht die IP-Adresse und „befristet protokolliert“ sie („logs it for a limited time“). Im Archiv Build 61 identisch zu `main`.
- **Backend-Code:** `Sources/RadarCore/SitePages.swift:147` „… protokolliert sie befristet“; `:168` nennt „Protokolle des Reverse Proxys“ beim Widerspruchsrecht. `LandingPage.swift:152,207` und `README.md:71`: der Dienst selbst führt keine Zugriffsprotokolle.
- **Live:** `GET /datenschutz` (HTTP 200) enthält denselben Satz. Dahinter steht kein Zusatz, `PROXY_LOG_NOTE` (`SitePages.swift:129`) erscheint also nicht.
- **Gegenstand:** Auf dem nicht gemergten Branch `origin/docs/rechtstexte-final` (`b5af1cb`) steht als Betreiberaussage (13.11. und 18.11., E1 in `docs/research/rechtspruefung-entscheidungen.md`), dass Zoraxy-Request-Log und -Statistik aus sind. Von außen ist das nicht prüfbar; die Proxy-Konfiguration wurde nicht gelesen.
- **Urteil:** App und veröffentlichte Erklärung stimmen überein. Eine App-Änderung allein würde beide auseinanderlaufen lassen. Stimmt die Betreiberaussage, beschreibt der heutige Text mehr Protokollierung als stattfindet. `INFO_PRIVACY_3`, `docs/appstore-texte-de.md:47` und `-en.md:45` zusammen mit der Veröffentlichung der neuen Datenschutzfassung ändern.

### (c) Jahr, OPERA, NOAA auf den Backend-Seiten

| Seite | Fundstelle (`Sources/RadarCore/`) | Jahr | Live |
|---|---|---|---|
| Datenschutz de | `SitePages.swift:172` | 2026, fest verdrahtet (Pflege zum 1.1.2027) | `/datenschutz` 200, mit Jahr |
| Rechtliches/Impressum de | `SitePages.swift:259` | **fehlt** | `/impressum` 200, ohne Jahr |
| Impressum en | `SitePagesEN.swift:94` | **fehlt** | `/en/imprint` 404 (`SITE_EN_ENABLED` aus) |
| Landingpage de | `LandingPage.swift:162,167` | **fehlt** | `/` 200, ohne Jahr |
| Landingpage en | `LandingPage.swift:217,222` | **fehlt** | `/en` 200, ohne Jahr |

- **OPERA/NOAA:** `git grep` in `SitePages.swift`, `SitePagesEN.swift`, `LandingPage.swift` ohne Treffer für OPERA/EUMETNET/NOAA, ebenso keine in den abgerufenen Live-Seiten. Eine englische Datenschutzseite gibt es nicht (`SitePages.swift:11-13`).
- **Neu gegenüber 19.11.:** Beide Ebenen sind live. `layers/radar_eu` und `layers/radar_world` liefern HTTP 200 mit eigener Attribution („Radardaten Europa: EUMETNET OPERA (CIRRUS), CC BY 4.0, Quelle: MeteoGate; …“ bzw. „Quelle: NOAA, von Showers verarbeitet; …“). In der App stehen diese Zeilen unter (i) › Datenquellen.
- **Urteil:** Das fehlende Jahr weicht vom Muster in Art. 6.3 ab. Ob die Webseiten OPERA und NOAA nennen müssen, solange sie deren Daten nicht selbst zeigen, ist nicht belegt (auf Bildschirmfotos nicht geprüft); als vollständige Quellenliste im Impressum empfohlen. Nebenbefund: `SitePages.swift:146` nennt Karten „für ganz Deutschland“ und weder Regen Europa noch Welt; das gehört zur neuen Datenschutzfassung auf dem Rechtstexte-Branch.

### (d) Mitteilungs- und Standorttexte

| Text | Fundstelle (de und en) | Urteil |
|---|---|---|
| Standort-Zweckstring | `Weather/Resources/{de,en}.lproj/InfoPlist.strings:2`, `Configuration/Info.plist:15` | ok. Im Archiv Build 61 in beiden Sprachen vorhanden; nur `NSLocationWhenInUseUsageDescription`. Eingebettete Extensions und Watch-App ohne Usage-Schlüssel |
| Standort im Wizard | `SETUP_LOCATION_BODY`, `Localizable.strings:622` | ok |
| Regenhinweis je Ort, Region, Wizard | `PUSH_PLACE_CONFIRM_MESSAGE:378`, `REGION_EXPLANATION:328`, `SETUP_ALERT_CONFIRM_MESSAGE:603` | ok. Installationskennung, Einwilligung, Widerruf und Löschung stehen in allen drei; der Befund vom 19.11. ist erledigt |
| Neu seit Build 61 (auf `main`) | `PUSH_MSG_NO_ANSWER`, `SETUP_WORKING` | ohne Datenschutzaussage |
| **Warnungen, Dialog** | `WARN_CONFIRM_MESSAGE:46`, Anzeige `Weather/Views/WarnSettingsView.swift:34-42` | **Lücke:** keine Angabe zu Daten, Einwilligung, Widerruf |
| **Warnungen, Fußnote** | `WARN_FOOTER:61` | **Zu eng:** „erhält nur Kennungen der betroffenen Landkreise“. Gesendet werden unter der Installationskennung auch Warnarten, Mindeststufe und die Einstellung für zeitkritische Mitteilungen; die Registrierung nutzt das Gerätetoken |
| **Info-Seite Datenschutz** | `INFO_PRIVACY_1:450`; `INFO_PRIVACY_1` bis `_6` | **Lücke:** gröbere Ortsangabe „nur“ bei Regenhinweisen; Warnungen kommen in diesen Absätzen nicht vor |

- **Auslöser:** `GET /v1/status` (27.11. 17:34 MEZ) meldet `capabilities` mit `warnings` und `warnings_push`. Mit `warnings_push` zeigt die App den Schalter (`Weather/Warnings/Subscriptions/WarnSettingsPresentation.swift:15-17`). Die Live-Datenschutzseite enthält den Absatz „Amtliche Warnungen (optional)“. Am 19.11. war der Punkt nur bedingt offen.
- **Datenumfang aus dem Code:** `WarnGateway.swift:12-19` (`warncell_ids`, `types`, `min_severity`, `enabled`, `time_sensitive`). Beim Ausschalten ist die Sollmenge leer (`WarnManager.swift:168-170`), die Abos werden per DELETE entfernt; bis zum Erfolg bleiben die IDs lokal vorgemerkt.
- **Kleinigkeiten ohne Entscheidungsbedarf für das Release:** `PUSH_INSTALLATION_ID_HINT` siezt; „Installations-Kennung“ in `REGION_PRIVACY_FOOTNOTE`. `docs/appstore-einreichung-antworten.md:25` (Content Rights) nennt OPERA/NOAA noch nicht; vor der Einreichung ergänzen.
- `sh tools/check_l10n.sh --strict`: Exit 0.

### (e) Push-Entitlement Build 61

- **Archiv** (`runtime/nachweise/showers-61/Showers61.xcarchive`, nur gelesen): `codesign -d --entitlements - --xml` zeigt `aps-environment=development`, `get-task-allow=true` (Development-Signatur, bei Archiven erwartet). `codesign --verify --deep --strict` ok. Quelle: `Configuration/Weather.entitlements:5-6`, `project.yml:49`.
- **Distributions-Export:** Das Xcode-Protokoll des Uploads (`upload-61.log`, Zeile 2) nennt das Paket `Weather_2026-11-27_05-48-04.829.xcdistributionlogs`; es lag noch im Temp-Ordner. `IDEDistributionPipeline.log`, Zeilen 1658-1665, ergibt für `de.linolaske.showernow`: **`aps-environment=production`**, `beta-reports-active=1`, `get-task-allow=0`, `time-sensitive=1`, App Group. Danach signiert `codesign --entitlements` das Paket `Payload/Weather.app` (ab Zeile 1704).
- **Upload:** `Info.plist` des Archivs: Build 61, `destination=upload`, `uploadEvent.state=success` (27.11. 04:50:06Z).
- **Gesichert:** unveränderte Kopie in `runtime/nachweise/showers-quellenabgleich/build61-export/` (SHA-256 `873160b9…570`, `cmp` identisch). Nur lokal, nicht im Repo.
- **Grenze:** `destination=upload` legt keine IPA ab. Belegt ist die Signaturvorgabe des Exports, kein `codesign`-Auslesen der IPA oder des von Apple ausgelieferten TestFlight-Pakets. Die Extensions und die Watch-App haben im Archiv kein `aps-environment`.
- **Für künftige Uploads:** dieses Protokoll direkt nach dem Upload in den Build-Nachweisordner kopieren.

## Umsetzung nach Antwort auf Frage 9B360945 (27.11.2026, Lino: „Alle drei wie vorgeschlagen umsetzen“)

Auftrag f-b8496a5a. Stand gegen `origin/main` `2455dd0`; Umsetzung im Commit dieses Eintrags (App-Texte kommen mit dem nächsten Build, kein Upload).

| Vorschlag (Bericht 19.11.) | Stand |
|---|---|
| V1 Dialoge Regenhinweis/Region (Installationskennung, Widerruf) | **erledigt**: Wizard in `main` (Merge `cff4960`); `SetupPlanTests.testAllConsentTextsMentionInstallationIDAndWithdrawal` grün |
| V2 „keine genaue Koordinate“ | **offen**: wartet auf die Rechtsprüfung (Entwurf Teil G 12), nicht Teil der Antwort |
| V3 Quellzeile Satellit | **erledigt**: `RadarLayer.displayShortAttribution` zeigt für Wolken, Wolkenmaske und Sonne die Manifestzeile („Contains modified EUMETSAT Meteosat data 2026“, Jahr vom Server); `shortAttribution` bleibt nur Rückfallname |
| V4 Links/Lizenz in (i) › Datenquellen | **offen**: kein Link auf CC BY 4.0, Data Policy, MeteoGate, NODD in `InformationSheet.swift`; nicht Teil der Antwort |
| V5 Backend-Seiten (Jahr, OPERA, NOAA) | **Backend-Repo**, Stand siehe Kartennotiz (Branch/PR, kein Deploy) |
| V6 Quellenzeilen englisch | **offen**: Layer-Manifeste ohne `Accept-Language` (nur `WarnFeedStore.swift:104` setzt ihn) |
| V7 Standort-Zweckstring | **offen, optional**: Ist-Text korrekt, nicht gewünscht |
| V8 Kleinkram | `WARN_CONFIRM_MESSAGE` **erledigt**; `INFO_PRIVACY_3` bleibt bis zur neuen Datenschutzseite (Frage); **offen**: `PUSH_INSTALLATION_ID_HINT` siezt, „Installations-Kennung“ (`REGION_PRIVACY_FOOTNOTE` de), „centre/center“ gemischt (en), Content-Rights-Antwort ohne OPERA/NOAA (`docs/appstore-einreichung-antworten.md:25`) |
| V9 Entitlement des finalen Pakets | Build 61: `aps-environment=production` im Signaturprotokoll des Exports belegt (Abschnitt (e)); die IPA selbst liegt nicht vor |

**Geändert (App):** `WARN_CONFIRM_MESSAGE`, `WARN_FOOTER`, `INFO_PRIVACY_1` (de/en, Wortlaut der Frage; Swift-Rückfallwert `InformationSheet.swift` mitgeführt), `RadarLayer.swift` (`isEUMETSATSatellite`, `displayShortAttribution`), UI-Test-Stub liefert für `clouds`/`cloudmask` die echte EUMETSAT-Zeile.
**Tests:** `WarnPrivacyTextTests` (4, Unit) und `WarnPrivacyTextUITests` (7: Warnungsseite und Dialog de/en hell/dunkel, Quellzeile Wolken hell/dunkel, Sonne hell). Rot vor der Änderung (Unit 9 Fehlschläge, UI 7 Fehlschläge), danach grün; Bilder angesehen: Dialog vollständig sichtbar, Zeile 282 pt breit auf 402 pt, hell und dunkel lesbar (liegt über Kartenbeschriftung, wie die bisherigen Zeilen).

## Offene Entscheidung

Eine Frage an der Karte: `9B360945-149F-44D9-8930-63C0B8A0458C`, mit Wortlaut de/en. Empfehlung: Warnungstexte, Quellzeile (Manifestzeile mit Jahr) und Backend-Seiten wie vorgeschlagen ändern; `INFO_PRIVACY_3` erst mit der neuen Datenschutzseite. Umgesetzt ist nichts.

## Nicht geprüft

Reverse-Proxy-Konfiguration; IPA beziehungsweise TestFlight-Paket; Darstellung der vorgeschlagenen Texte (Gerät, Simulator, hell/dunkel); NOAA-, OPERA- und DWD-Bedingungen nicht neu abgerufen (Stand 19.11.); Bildschirmfotos der Landingpage; kein Build, kein Testlauf; kein unabhängiges Gegenlesen (reine Dokumentation).
