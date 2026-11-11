# App-Store-Einreichung: Antwortvorschläge (Stand 11.11.2026)

Vorschläge zum Abschreiben durch den Nutzer. Nichts in App Store Connect eingetragen oder gesehen; Fragebögen und Masken können abweichen. Annahmen sind markiert. Kein Rechtsrat. Die Einreichung macht nur der Nutzer.

## 1. Exportcompliance (aus Code belegt)

- `ITSAppUsesNonExemptEncryption = false` in `Configuration/Info.plist` (Haupt-App) und `Configuration/WeatherWatch-Info.plist`. Die Plists von Widgets, Benachrichtigungs-Erweiterung und Watch-Widgets enthalten den Schlüssel nicht; ob Apple ihn für Erweiterungen verlangt, ist nicht geprüft.
- Verschlüsselung im Code: nur Systemverschlüsselung über `URLSession` (HTTPS) laut `testflight-readiness.md`; Zufallszahlen per `SecRandomCopyBytes` (`Weather/Push/PushGateway.swift`) und Schlüsselbund (`Weather/Push/PushKeychain.swift`). Suche nach `CryptoKit`, `CommonCrypto`, `HMAC`, `SHA256` in `Weather`, `Shared` und den Erweiterungen: Treffer nur diese beiden Push-Dateien (Zufall und Schlüsselbund), keine eigenen Algorithmen. Keine Fremdbibliotheken (kein Paketabschnitt in `project.yml`).
- Antwort, falls Connect trotzdem fragt (ANNAHME zum Wortlaut): "Verwendet die App Verschlüsselung?" Nur Standardverschlüsselung des Betriebssystems (HTTPS), von der Dokumentationspflicht ausgenommen; keine proprietären oder nicht standardisierten Algorithmen. Quelle: Apple, Complying with Encryption Export Regulations.

## 2. Altersfreigabe (Vorschlag, ANNAHME)

Der aktuelle Fragebogen wurde nicht gesehen. Nach Repo-Stand: keine Nutzerinhalte, keine Chats, keine Werbung, kein Glücksspiel, keine Gewalt, keine medizinischen Inhalte, kein freier Web-Zugang (Webansicht nur für eigene Seiten, ohne JavaScript, übrige Links öffnen extern), kein Konto, keine Käufe.

| Bereich | Antwort |
|---|---|
| Inhaltsbeschreibungen (Gewalt, Sexuelles, Horror, Glücksspiel, Alkohol/Drogen u. a.) | keine |
| Medizin/Gesundheit | keine (Wetterwarnungen sind amtliche DWD-Hinweise, keine Gesundheitsaussagen) |
| Uneingeschränkter Web-Zugang | nein |
| Nutzergenerierte Inhalte, Nachrichten, Werbung | nein |
| Käufe/Glücksspiel | nein |
| Erwartetes Ergebnis | niedrigste Stufe (4+), von Apple errechnet |

Kategorie: Wetter (ANNAHME, Kategorieliste nicht gelesen).
Content Rights: Drittinhalte vorhanden (DWD-Daten, EUMETSAT), Rechte über offene Lizenzen (GeoNutzV/CC BY 4.0) mit Quellenvermerk; Einordnung ohne Rechtsprüfung.

## 3. Review-Kontakt und Hinweise für die Prüferin (Englisch, Entwurf)

Kontaktfelder (Name, E-Mail, Telefon im internationalen Format) trägt der Nutzer selbst ein. Anmeldung nicht erforderlich: Feld "Sign-in required" leer lassen.

```
No account or sign-in is required. Showers is a native weather app for Germany (data: Deutscher Wetterdienst, DWD).

- Location permission is optional (when in use only, no background location). Without it, search for a German city (for example Berlin) and drag the timeline slider.
- Radar coverage is Germany and surroundings. Where it is dry, the radar is legitimately empty.
- Optional rain alerts, area alerts and Live Activities need our server and real rain near a saved place or region; they cannot be triggered on demand during review. Notification permission is requested only after the user turns an alert on. [If warning push is enabled: DWD weather warnings are shown as a list and on the map; the app states that it does not replace official channels.]
- Temperature, dew point and humidity layers are DWD model data and labelled as such.
- The app sends no analytics, no advertising identifiers and uses no tracking. If rain alerts are turned on, a device token, a random installation ID and a coarse grid cell of the chosen place or region are stored on our server (see privacy policy, linked in the app's info sheet).
- Privacy policy: <Datenschutz-URL>. Support: <Support-URL>.
```

Vor dem Eintrag anzupassen: Absatz zu Warn-Push je nach Entscheidung (Karte "Warn-Push/APNs-Livegang"), Platzhalter URLs. Wortlaut ohne Gewähr; Funktionen gegen den finalen Build prüfen.

## 4. Screenshot-Auswahl für Connect (nur Deutsch)

Alle Dateien liegen im Repo unter `design/appstore-screenshots/`, ohne Alphakanal, nativ aufgenommen (Build 42). Reihenfolge = empfohlene Anzeigereihenfolge.

| Connect-Feld | Ordner | Dateien in dieser Reihenfolge |
|---|---|---|
| iPhone 6,3" (Pflicht 1206x2622) | `iphone/1206x2622/de/` | 01-regenradar, 02-ortsdetails, 03-temperatur, 04-warnungen, 05-feuchte-wald, 06-region, 07-orte-regionen, 08-regenradar-dunkel |
| iPhone 6,9" (optional 1320x2868) | `iphone/1320x2868/de/` | gleiche acht |
| iPad 13" (2064x2752) | `ipad/2064x2752/de/` | 01-regenradar, 02-temperatur, 03-warnungen, 04-feuchte-wald, 05-regenradar-dunkel |
| Apple Watch (422x514) | `watch/422x514/de/` | 01-ortsliste, 02-ortsprognose |

Hinweise: Motiv 04-warnungen nur verwenden, wenn Warnungen im ausgelieferten Build/Server sichtbar sind (Entscheidung zum Warn-Push). Die Warn- und Regionenmotive entsprechen dem Build-42-Stand; bei sichtbaren UI-Änderungen danach neu aufnehmen (`tools/screenshots.sh`, Doku `appstore-screenshots.md`). Maximal zehn pro Gerät; mehr als acht sind nicht nötig.
