# App-Store-Release-Checkliste (Stand 7.11.2026)

Reine Lesepruefung des Repos (Stand `67b1f21`) und der Live-Seiten `showernow.linolaske.de` (HTTP-Abruf 7.11.2026). Nichts in App Store Connect gesehen oder geaendert. Apple-Quellen: `apple-externe-tests.md` (Q-Liste, 31.10.); die Apple-Seite zu Required-Reason-APIs lieferte beim Abruf am 7.11. nur den Titel, die Aussagen dazu stuetzen sich auf Apple-Wissen (zu pruefen). Kein Rechtsrat.

Status: erledigt / offen / unklar. Wer: Agent oder Nutzer.

## Blocker

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Datenschutzseite deckt Push nicht ab | offen | Live `/datenschutz` (Stand 6.11.) nennt kein Regenhinweis-/Gebiets-/Live-Activity-Abo (Push-Token, Installationskennung, Zelle/Umkreis), nur Betriebsstatistik und Diagnose-Kopplung; "iPhone, iPad" ohne Watch; Reverse-Proxy-Logging "noch nicht angegeben". Entwurf liegt vor, nicht freigegeben | Nutzer (Freigabe), Agent (Text) |
| App-Privacy-Angaben (Variante B) | offen | Push speichert Geraetetoken + grobe Zelle/Umkreis serverseitig, Variante A "Data Not Collected" entfaellt (`research/push-benachrichtigungen.md` 5, `push-regionen.md`); in Connect nicht gesehen. Fuer Device ID, Coarse Location, Zweck App Functionality; Tracking nein | Nutzer |
| `PrivacyInfo.xcprivacy` in allen 5 Targets | erledigt (7.11.2026, Build 33, `b29be64`) | `find` ohne Treffer; kein Eintrag in `project.yml`. App/Extensions nutzen `UserDefaults` (App, App-Group in Widget, Live Activity, Notification Extension): Kategorie UserDefaults, Gruende CA92.1 (eigene) und 1C8F.1 (App Group). Ohne Deklaration droht ITMS-91053-Warnung bzw. Ablehnung | Agent |
| Proxy-Protokollierung / E7 Rechtsgrundlage | offen | `status.md` Nutzeraufgaben; Seite sagt "noch nicht angegeben" | Nutzer |
| Impressum | unklar | `/impressum` HTTP 404; Anschrift steht nur im Datenschutz (Abschn. 1), Support-Seite nur E-Mail. Pflicht je nach Einordnung (DDG, Anbieterkennzeichnung), Rechtspruefung offen | Nutzer |
| Build fuer Einreichung gewaehlt/verarbeitet | unklar | Builds 31/32 hochgeladen (`Upload succeeded`), Verarbeitung/Installierbarkeit nirgends geprueft (`testflight-upload.md`: "Nicht geprueft"); Zuordnung zu Gruppe/Version nie bestaetigt | Nutzer |

## Metadaten

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| App-Name | unklar | Anzeigename `Showers` (`Base.xcconfig`); Nutzer nennt ShowerNow; Verfuegbarkeit des Namens in Connect ungeprueft, Ausweichname vorgeschlagen (`status.md` Build 17) | Nutzer |
| Untertitel, Werbetext, Keywords, Beschreibung | offen | Englischer Entwurf (nicht freigegeben): [appstore-texte-en.md](appstore-texte-en.md). Nur Vorschlaege in `appstore-screenshots.md`/`apple-externe-tests.md`, teils mit altem Namen; nichts eingetragen belegt | Agent (Text final), Nutzer (Eintrag) |
| Kategorie Wetter, Altersfreigabe-Fragebogen | offen | Nur Annahme `apple-externe-tests.md` 6; kein freier Web-Zugang, keine Inhalte | Nutzer |
| Support-URL | erledigt | `/support` HTTP 200, E-Mail mail@linolaske.de | Nutzer (Eintrag in Connect) |
| Marketing-URL | erledigt | `/marketing` HTTP 200 | Nutzer |
| Datenschutz-URL | erledigt (URL), Inhalt offen | `/datenschutz` HTTP 200; in App verlinkt (`RadarBackendConfig`) | siehe Blocker |
| Copyright | offen | Nicht festgelegt | Nutzer |
| Lokalisierung de/en | App erledigt (L1 bis L6, 9.11.), Store-Texte offen | App-UI, Widgets, Live Activity, Watch, Push de/en (`check_l10n.sh --strict` Exit 0, 643 Unit + 40 UI gruen); OFFEN: englische Store-Texte (Titel, Untertitel, Beschreibung, Keywords, Werbetext) und englische Webseiten Datenschutz/Support/Impressum (Backend-Repo, E4); Muttersprachlerpruefung der Wortlautfragen | Nutzer/Agent |
| Version/Plattform | erledigt | 0.1.1 (32), iOS 27.0, iPhone+iPad, watchOS 27.0 | - |
| Preis, Verfuegbarkeit, Laender | offen | nicht dokumentiert | Nutzer |

## Screenshots und Medien

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| iPhone 1206x2622 (Pflicht) | Dateien neu (9.11., Build 42) | `design/appstore-screenshots/iphone/1206x2622/de/` 8 Motive: Radar, Ortsdetails, Temperatur, Warnungen, Feuchte+Wald, Region, Orte, Dunkel; Upload nie ausgefuehrt; Details `appstore-screenshots.md` | Nutzer (Upload) |
| iPhone 1320x2868 (optional) | Dateien neu | `iphone/1320x2868/de/`, 8 Motive wie oben | Nutzer (Upload) |
| iPad 13" 2064x2752 | Dateien neu | `ipad/2064x2752/de`, 5 Motive (Radar, Temperatur, Warnungen, Feuchte, Dunkel) | Nutzer (Upload) |
| Apple Watch 422x514 | Dateien neu | `watch/422x514/de`, 2 Bilder (Ortsliste, Ortsprognose "kein Regen"; Uhrzeit echt, nicht 9:41) | Nutzer (Upload) |
| Mac | nicht noetig | kein natives Mac-Ziel; Verfuegbarkeit "iPhone/iPad-App auf Mac" in Connect pruefen/abwaehlen | Nutzer |
| Englische Screenshots | Dateien neu (9.11.) | `iphone/1206x2622/en` 8 Motive, `ipad/2064x2752/en` 5, `watch/422x514/en` 1 (Prognose); 1320x2868 per Skript reproduzierbar (nicht eingecheckt); Regenradar-Motive ohne Regenband (Wetterlage), Warnungen-Text DWD deutsch; Upload nie ausgefuehrt; Duo en nicht moeglich | Nutzer (Upload) |
| Neue Motive (Gebiete, Live Activity, Widgets, Warnungen) | teilweise | Warnungen, Neue Region, Orte/Regionen, Temperatur, Feuchte+Wald aufgenommen; Widget und Live Activity nicht (Simulator ohne Push/Widget-Platzierung) | Nutzer/Agent mit Geraet |
| Namensstand der Bilder | erledigt | Neuaufnahme auf Build 42 (`19ece2c`) | - |
| iPhone-Duo-Screenshots (Pflicht ab April 2027) | offen | Pflicht fuer Apps mit iOS-27.1-SDK oder neuer (Showers: Simulator-SDK 27.1, Deployment 27.0); Masse Aussen 1398x2034, Innen 2007x2853 (hoch) bzw. quer vertauscht; Quelle https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications (9.11.2026); Duo-Simulator startet lokal nicht (Runtime-Pfad fehlt), siehe `research/iphone-duo.md` und `appstore-screenshots.md` | Agent (Runtime reparieren, aufnehmen), Nutzer (Upload) |
| Preview-Video / Creatives | erledigt (optional) | `preview/`, `creative/` | - |

## Datenfluesse und Compliance

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Exportcompliance | erledigt | `ITSAppUsesNonExemptEncryption=false` in `Configuration/Info.plist` (nur Haupt-App geprueft; Extensions/Watch-Plists nicht einzeln geprueft) | Agent (Gegenprobe) |
| Push-Entitlement production | erledigt, ungesichert fuer 31/32 | Datei: `development`, Export setzt `production` (Builds 12/13 am IPA belegt); 31/32: IPA-Paketpruefung nicht ausgefuehrt | Agent |
| APNs-Key/Backend-Push live | unklar | `apns-einrichtung.md`, Backend-Deploy `mutable-content`/Gebiets-Live-Activity noch Nutzeraufgabe | Nutzer |
| Berechtigungstext Standort | erledigt | `NSLocationWhenInUseUsageDescription` nennt Zweck/DWD, nur de | Agent (en pruefen) |
| Mitteilungs-Berechtigung | unklar | Bestaetigungsdialog vor Systemabfrage laut `decisions.md`; Wortlaut nicht geprueft | Agent |
| Live Activities | erledigt | `NSSupportsLiveActivities` true | - |
| Quellenangaben DWD (CC BY / GeoNutzV) | erledigt | Quelle/Aenderungshinweis in Karte, Info-Sheet, Seite Abschn. 12; Lizenzeinordnung ohne Rechtspruefung | Nutzer (Rechtspruefung) |
| EUMETSAT | unklar | Link "EUMETSAT / EUMETView" im Info-Sheet bei Wolken; Nutzungsbedingungen/Namensnennung nicht dokumentiert geprueft | Agent |
| Kartendaten | erledigt | Apple MapKit, kein OSM; Apple-Datenschutz in Seite Abschn. 6 | - |
| Datenschutzlink in der App | erledigt | Info-Sheet (5.1.1(i)) | - |
| Teilen, Kopplung (Diagnose) | erledigt (Text) | Seite Abschn. 9; Kopplung nur bei offenem Fenster | - |

## Review und Betrieb

| Punkt | Status | Beleg | Wer |
|---|---|---|---|
| Review-Hinweise, Kontakt, Telefon | offen | Textvorschlag vorhanden (`apple-externe-tests.md` 3), Kontaktfelder Platzhalter; kein Demo-Konto noetig | Nutzer |
| Hinweis fuer Prueferin: Push/Live Activity brauchen Backend und echten Regen | offen | nicht formuliert; Funktionen ohne Regen schwer pruefbar (Guideline 2.1) | Agent (Text) |
| Guideline 4.2 (Minimum Functionality) | geringes Risiko | native Radar, Prognose, Widgets, Watch, Push | - |
| Guideline 5.1.1/5.1.5 | offen | haengt an Datenschutzseite und App Privacy | siehe Blocker |
| Barrierefreiheit | unklar | VoiceOver-Aktion Slider, Dynamic Type bis AXXXL im Simulator geprueft; Geraet, Dark/iPad/VoiceOver real nicht | Nutzer |
| Crash-/Leistungsfreiheit am Geraet | unklar | Nur Simulator/Tests (484 Unit, 12-13 UI); flaky UI-Test; Glow/Watch-Dekoder/Akku am Geraet ungeprueft | Nutzer |
| Watch-App | unklar | eingebettet; Hardware/Krone/Komplikationen ungeprueft | Nutzer |
| Mac | nicht zutreffend | nur falls Auslieferung als iPhone-App auf Mac gewuenscht | Nutzer |
| Externe TestFlight-Pruefung | unklar | Build 13 eingereicht 1./2.11., Ausgang unbekannt | Nutzer |
| App-Store-Version 0.1.1 in Connect anlegen | offen | `status.md` | Nutzer |
| README-Stand | offen | nennt Build 12 und Produktname Showers/ShowerNow uneinheitlich | Agent |

## Reihenfolge

1. ~~Agent: `PrivacyInfo.xcprivacy` (5 Targets) und neuer Build mit Paket-/Entitlement-Pruefung~~ erledigt mit Build 33.
2. Nutzer: Datenschutztext freigeben, Proxy-Logging und Impressum klaeren; Seite live schalten; danach App Privacy (Variante B) in Connect.
3. Nutzer: Name, Kategorie, Altersfreigabe, Copyright, Preis, Review-Kontakt; Agent liefert finale Texte (de/en) und Neu-Screenshots.
4. Nutzer: Geraetetest (iPhone, Watch, echte Regenmeldung, Live Activity), Build waehlen, einreichen.

## Nicht geprueft

App Store Connect (Masken, Build-Status, Namensverfuegbarkeit, Altersfragebogen), IPA-Inhalte von Build 31/32, Apple-Seite Required Reason (nur Titel abrufbar), aktuelle Review Guidelines (Stand 31.10. aus `apple-externe-tests.md`), Geraet, Rechtsfragen.
