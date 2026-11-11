# App-Store-Release-Checkliste (Stand 11.11.2026)

Ziel: Showers im App Store bis ca. 9.12.2026. **Die Einreichung zur Prüfung macht nur der Nutzer.** Abgleich 11.11.2026 gegen Repo-Stand `origin/main` (Build 46, Commits `d77adbf`, `dd6864d` und später), ohne App Store Connect, Geräte oder Live-Server gesehen zu haben. Aussagen zum Backend-Stand (Commit `81e86be`, gekürzte Datenschutzseite, nicht deployt) stammen aus dem Auftrag des Orchestrators; das Backend-Repo wurde nicht eingesehen. Der Live-Seitenabruf vom 7.11. ist nicht erneut geprüft. Kein Rechtsrat.

Status: erledigt / offen / unklar / nicht geprüft. Wer: **Nutzer**, **Agent** (Claude), **Deploy** (Backend-Deploy durch den Nutzer). Todolino-Karten tragen den Präfix "Release:".

## Terminleiste bis 9.12.2026 (Rückwärtsplanung, Stand 11.11.)

Prüfzeit Apple ist nicht belegt (Annahme: meist wenige Tage, bei Rückfragen länger); Puffer deshalb eine Woche.

| Bis | Meilenstein | Wer |
|---|---|---|
| 16.11. | Name "Showers" in Connect gesichert; Betreiberangaben, Proxy-Logfrist, Backup-Angaben; Hetzner-AVV | Nutzer |
| 18.11. | Backend mit gekürzter Datenschutzseite deployt (OPERATOR_*, PROXY_LOG_NOTE) | Deploy |
| 19.11. | Live-Seiten geprüft (Datenschutz, Impressum, Support) | Agent |
| 20.11. | Rechtsprüfung (Opus-Agent) ausgewertet; Entscheidung Warn-Push/APNs und Server-Flags; Berechtigungstexte und EUMETSAT geprüft | Agent, Nutzer |
| 23.11. | TestFlight-Gerätetest abgeschlossen; Bedienungshilfen-Prüfung | Nutzer, Agent |
| 25.11. | Finaler Build hochgeladen und verarbeitet; Version 0.1.1 in Connect angelegt; App-Privacy und Datenschutz-URL eingetragen | Agent, Nutzer |
| 27.11. | Altersfreigabe, Export-Compliance, Store-Texte, Screenshots, Review-Kontakt und -Hinweise in Connect | Nutzer |
| **2.12.** | **Einreichung zur Prüfung (spätestens)** | **Nutzer** |
| 2. bis 9.12. | Prüfzeit Apple, Rückfragen zügig beantworten | Nutzer |
| 9.12. | Ziel Veröffentlichung | Nutzer |

Abhängigkeit: App-Privacy in Connect erst nach Livegang der Datenschutzseite; Store-Texte und Review-Hinweise erst nach der Entscheidung zum Warn-Push.

## Blocker

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Datenschutzseite deckt Push ab | offen (Text final, nicht live) | Datenschutztext Teil A final und gekürzt laut Nutzerentscheidung 10.11. (`datenschutz-entwurf-release.md`); Backend `81e86be` ersetzt `/datenschutz` beim Deploy, laut Auftrag noch nicht deployt. Livestand 6.11. (nennt kein Push-Abo) nicht erneut abgerufen | Deploy |
| Betreiberangaben `OPERATOR_*`, `PROXY_LOG_NOTE`, Proxy-Logfrist | offen | Platzhalter im Text; Frist kürzen (Empfehlung 7 bis 14 Tage, höchstens 30), Backups, Zoraxy-Standort, Aufsichtsbehörde offen (Teil C 4b, 4d, 13, 15) | Nutzer |
| Hetzner-AVV (Art. 28 DSGVO) | offen | Teil C 4c, Nutzeraktion vor Livegang | Nutzer |
| App-Privacy-Angaben (Variante B) | offen | Teil B liegt vor (Geräte-ID, Genauer und Grober Standort, App-Funktionalität, verknüpft, kein Tracking); in Connect nicht gesehen; Proxy-IP-Logs (Teil B 10) gegen Apple-Definition ungeprüft. Eintrag erst nach Livegang der Seite | Nutzer |
| `PrivacyInfo.xcprivacy` in allen 5 Targets | erledigt (Build 33, `b29be64`; Build 34 `8eb9715` Standort ergänzt) | `datenschutz-entwurf-release.md` Teil B 9; Xcode-Privacybericht am finalen Archiv nicht erneut geprüft | Agent |
| Rechtsgrundlage Proxy-Logs (E7), Rechtsprüfung | offen | Fragenliste Teil G, Briefing `research/rechtspruefung-briefing.md` (11.11.), Prüfung nicht ausgeführt | Agent (Opus), Nutzer (Abnahme) |
| Impressum | offen, nach Deploy prüfen | Backend-Seite `/impressum` laut Todolino-Karte erstellt; am 7.11. live HTTP 404, seitdem nicht abgerufen; Pflicht-Einordnung (DDG) Teil der Rechtsprüfung | Deploy, Agent (Abruf) |
| Build für Einreichung gewählt/verarbeitet | offen | Build 46 hochgeladen ("Uploaded package is processing"), Verarbeitung/Installierbarkeit nicht geprüft; Zuordnung zur Version nie erfolgt | Nutzer |

## Metadaten

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| App-Name | unklar | Anzeigename `Showers`; Verfügbarkeit in Connect ungeprüft, Ausweichname in `status.md` (Build 17) | Nutzer |
| Untertitel, Werbetext, Keywords, Beschreibung (DE) | Entwurf fertig, nicht freigegeben | [appstore-texte-de.md](appstore-texte-de.md) (Zeichen/Bytes gezählt, Commit `dd6864d`), nichts eingetragen belegt | Nutzer (Freigabe, Eintrag); Agent bei Änderung |
| Englische Store-Texte | zurückgestellt | [appstore-texte-en.md](appstore-texte-en.md) liegt vor; App wird nur in DE angeboten, keine englische Datenschutzseite | - |
| Kategorie Wetter, Altersfreigabe | Vorschlag fertig, in Connect offen | [appstore-einreichung-antworten.md](appstore-einreichung-antworten.md) (Annahmen, Fragebogen nicht gesehen) | Nutzer |
| Support-URL, Marketing-URL | 7.11. HTTP 200, seitdem nicht erneut geprüft | Karte "Live-Seiten nach Deploy prüfen" | Nutzer (Eintrag), Agent (Abruf) |
| Datenschutz-URL | URL vorhanden, Inhalt offen | `/datenschutz` (deutsch), in App verlinkt; in Connect nach Deploy eintragen | Nutzer |
| Copyright | offen | nicht festgelegt | Nutzer |
| Lokalisierung | App de/en fertig (L1 bis L6, 9.11.); Store nur DE | englische Seiten hinter `SITE_EN_ENABLED` aus (Standard aus = 404), bleibt aus | - |
| Version/Plattform | App-Stand Build 46; Version 0.1.1 in Connect nicht angelegt | iOS 27.0, iPhone+iPad, watchOS 27.0 | Nutzer (Anlage) |
| Preis, Verfügbarkeit, Länder | offen | nicht dokumentiert | Nutzer |

## Screenshots und Medien

Zuordnung und Auswahl: [appstore-einreichung-antworten.md](appstore-einreichung-antworten.md), Details und Regenerierung [appstore-screenshots.md](appstore-screenshots.md). Upload nie ausgeführt.

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| iPhone 1206x2622 (Pflicht) | Dateien vorhanden (Build 42), nicht hochgeladen | `iphone/1206x2622/de/` 8 Motive | Nutzer |
| iPhone 1320x2868 (optional) | Dateien vorhanden | `iphone/1320x2868/de/` 8 Motive | Nutzer |
| iPad 13" 2064x2752 | Dateien vorhanden | `ipad/2064x2752/de/` 5 Motive | Nutzer |
| Apple Watch 422x514 | Dateien vorhanden | `watch/422x514/de/` 2 Bilder | Nutzer |
| Englische Screenshots | nicht nötig (nur DE) | `.../en/` liegen als Reserve im Repo | - |
| Mac | nicht nötig | kein natives Mac-Ziel; "iPhone/iPad-App auf Mac" in Connect prüfen/abwählen | Nutzer |
| Widget-/Live-Activity-Motive | fehlen | Simulator ohne Push/Widget-Platzierung; nur mit Gerät | Nutzer/Agent (optional) |
| iPhone-Duo-Screenshots | nicht blockierend für 9.12. | Pflicht ab April 2027 (`research/iphone-duo.md`); Duo-Simulator startet lokal nicht | Agent (später) |
| Preview-Video, Creatives, Kopfzeilen-Bilder | optional, nur lokal | nicht im Repo (Regenerierung in `appstore-screenshots.md`) | - |

## Datenflüsse und Compliance

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Exportcompliance | Antworten aus Code belegt | `ITSAppUsesNonExemptEncryption=false` in `Configuration/Info.plist` und `WeatherWatch-Info.plist`; Plists von Widgets, Benachrichtigungs-Erweiterung, Watch-Widgets ohne Schlüssel (Auswirkung nicht geprüft); im Code `URLSession`/HTTPS, `SecRandomCopyBytes` und Schlüsselbund (`Weather/Push/`), kein CryptoKit/CommonCrypto; Details in `appstore-einreichung-antworten.md` | Agent (belegt), Nutzer (Eintrag falls gefragt) |
| Push-Entitlement production | für Build 31 bis 46 IPA-Paketprüfung nicht ausgeführt | Datei `development`, Export setzt `production` (Builds 12/13 am IPA belegt); `testflight-upload.md` für spätere Builds prüfen | Agent (finaler Build) |
| APNs-Key/Backend-Push live, Warn-Push | offen, Entscheidung nötig | `apns-einrichtung.md`; Warn-Push serverseitig aus | Nutzer |
| Taupunkt/Feuchte/Server-Flags | offen | Entscheidungen 8.11. (`decisions.md`): Taupunkt zuerst, Feuchte per Flag; Betriebszustand nicht geprüft | Nutzer (Deploy) |
| Berechtigungstext Standort | de erledigt, en nicht geprüft | `NSLocationWhenInUseUsageDescription` | Agent |
| Mitteilungs-Berechtigung | unklar | Bestätigungsdialog vor Systemabfrage laut `decisions.md`, Wortlaut nicht geprüft | Agent |
| Live Activities | erledigt | `NSSupportsLiveActivities` true | - |
| Quellenangaben DWD (CC BY / GeoNutzV) | erledigt (ohne Rechtsprüfung) | Karte, Info-Sheet, Seite | Nutzer (Rechtsprüfung) |
| EUMETSAT | unklar | Link im Info-Sheet; Namensnennung "Contains modified EUMETSAT Meteosat data" mit Jahr offen (Teil C 12) | Agent |
| Kartendaten, Datenschutzlink in App, Teilen/Kopplung | erledigt (Text) | Apple MapKit; Info-Sheet; Seite Abschn. 9 | - |

## Review und Betrieb

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Review-Kontakt, Telefon | offen | Kontaktfelder Platzhalter; kein Demo-Konto nötig | Nutzer |
| Hinweise für Prüfer (Push/Live Activity brauchen Backend und echten Regen, Warnungen) | Entwurf fertig | [appstore-einreichung-antworten.md](appstore-einreichung-antworten.md); an Warn-Push-Entscheidung anpassen | Agent (Entwurf), Nutzer (Eintrag) |
| Guideline 4.2 | geringes Risiko (Einschätzung) | native Radar, Prognose, Widgets, Watch, Push | - |
| Guideline 5.1.1/5.1.5 | offen | hängt an Datenschutzseite und App Privacy | siehe Blocker |
| Bedienungshilfen / Accessibility Nutrition Labels | freiwillig, nur Belegtes ankreuzen | Simulator-Prüfung 11.11. (`docs/research/bedienungshilfen-pruefung.md`): Audit de/en, AXXXL, Dunkel, Kontrast gemessen. Ankreuzbar: Dunkle Oberfläche. Nach Gerätetest (Anleitung in der Datei): VoiceOver, Sprachsteuerung, Größerer Text, Bewegung reduzieren. Nicht ok: Ausreichender Kontrast, Nicht nur Farbe (Vorschläge V1 bis V3, Nutzerentscheidung). Untertitel/Audiobeschreibungen leer | Agent (Prüfplan), Nutzer (Gerät, Eintrag) |
| Crash-/Leistungsfreiheit am Gerät | nicht geprüft | 649 Unit und 40 UI im Simulator (Stand Build 46); Akku, Glow, Watch am Gerät ungeprüft | Nutzer |
| Watch-App | nicht geprüft | Hardware/Krone/Komplikationen | Nutzer |
| TestFlight extern | unklar | Build 13 eingereicht 1./2.11., Ausgang unbekannt; Voraussetzung für die App-Store-Einreichung nicht belegt | Nutzer |
| README-Stand | offen | nennt Build 12 | Agent |

## Reihenfolge

1. Nutzer: Name sichern, Betreiberangaben, Logfrist, Hetzner-AVV (bis 16.11.).
2. Deploy der Datenschutzseite, danach Live-Prüfung, Rechtsprüfung, Warn-Push-Entscheidung (bis 20.11.).
3. Gerätetest, Bedienungshilfen, finaler Build (bis 25.11.).
4. Connect-Eingaben (Privacy, Texte, Screenshots, Altersfreigabe, Review-Hinweise, Build wählen) bis 27.11.
5. Einreichung durch den Nutzer spätestens 2.12.

## Nicht geprüft

App Store Connect (Masken, Build-Status, Namensverfügbarkeit, Altersfragebogen, aktuelle Kategorien), Live-Seiten seit 7.11., Backend-Repo, IPA-Inhalte ab Build 31, Apple-Seite Required Reason (nur Titel abrufbar), aktuelle Review Guidelines (Stand 31.10. aus `apple-externe-tests.md`), Gerät, Rechtsfragen.
