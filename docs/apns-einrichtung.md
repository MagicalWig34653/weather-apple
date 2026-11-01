# APNs-Einrichtung (Betreiber-Checkliste)

Stand: 1. November 2026. Anleitung für den Betreiber; bei Apple ist nur die Capability angelegt, der APNs-Key fehlt noch. Hintergrund und geprüfte Apple-Aussagen: [research/push-benachrichtigungen.md](research/push-benachrichtigungen.md) (Abschnitte 3.5, 4, 8). Kennzeichnung wie [apple-externe-tests.md](apple-externe-tests.md): **BESTÄTIGT** = in Repo oder Apple-Quelle gelesen, **UNGEPRÜFT** = Annahme/Drittquelle. Keine Geheimnisse hier eintragen (Key-Datei, Passwörter, Tokens bleiben lokal).

Markierung: **[NUTZER]** nur der Kontoinhaber kann es tun. **[ERLEDIGT]** gebaut bzw. durchgeführt. **[BACKEND]** im Schwesterrepo (Standard: Push aus).

Erledigt: Capability/Entitlement (`aps-environment`, `time-sensitive`), App-Seite (Opt-in je Ort, Gerätetoken, Regionen, Zeitkritisch), Testmeldung (Info-Sheet, „Testmeldung senden“), Backend-Overlay `stack.push.yaml` und `setup.sh`-Wizard. Am Gerät vom Nutzer bestätigt: Push-Registrierung/Glocke. **Noch nicht** geprüft: echte Zustellung. Hinweis: Build 12 zeigt bei echten Regenmeldungen den rohen Schlüssel `RAIN_STARTS_IN`; behoben erst im nächsten Build (siehe [status.md](status.md)). Die Testmeldung ist davon nicht betroffen.

## 1. Apple Developer [NUTZER]

- [x] Capability erledigt (31.10.2026, siehe [signing.md](signing.md)): Entitlement im Projekt, per `-allowProvisioningUpdates` in Development- und Store-Profil enthalten. Ursprüngliche Anleitung (nur falls erneut nötig): App-ID `de.linolaske.showernow` (Team `J2DU2P47XW`, beides endgültig): unter Certificates, Identifiers & Profiles → Identifiers die Capability **Push Notifications** aktivieren. Provisioning-Profile danach neu erzeugen; bei automatischem Signing macht Xcode das (UNGEPRÜFT).
- [ ] **APNs-Auth-Key** anlegen: Keys → „+“ → Apple Push Notifications service (APNs). Optionen (BESTÄTIGT, Apple-Quelle in der Recherche):
  - **Team-scoped, nur Sandbox** und **team-scoped, nur Produktion**: je Umgebung begrenzbar, höchstens zwei je Umgebung; Apple empfiehlt umgebungsspezifische Keys. Sinnvoll, wenn Debug-Läufe (Sandbox) und TestFlight/App Store (Produktion) getrennte Schlüssel haben sollen.
  - **Key für beide Umgebungen** (älteres Modell, bleibt gültig): ein Key für alles; einfacher, aber größerer Schaden bei Verlust.
  - **Topic-specific**: nur einzelne App-Topics, eine Umgebung, bis 200 je Umgebung. Für eine einzelne App sinnvoll, wenn das Team später weitere Apps hat.
  - Empfehlung (ANNAHME): erst **ein Key nur Produktion** (deckt TestFlight), Sandbox-Key nur wenn Xcode-Debug-Läufe mit Push getestet werden sollen.
- [ ] `.p8` herunterladen und sicher ablegen (Passwortmanager/verschlüsselt). Dass Apple die Datei **nur einmal** zum Download anbietet, ist **UNGEPRÜFT** (verbreitete Annahme); vorsichtshalber sofort sichern. Nie ins Repo.
- [ ] **Key-ID** (10 Zeichen) notieren; steht in der Key-Liste und im Dateinamen `AuthKey_<KeyID>.p8`.
- [ ] **Team-ID** (10 Zeichen): developer.apple.com → Membership details; auch in App Store Connect unter Benutzer und Zugriff → Schlüssel/Membership. Das Repo nennt `J2DU2P47XW` (endgültig).

## 2. Secret im Swarm anlegen [NUTZER, auf dem Swarm-Manager]

```sh
docker secret create showernow_apns_key /pfad/zu/AuthKey_XXXXXXXXXX.p8
shred -u /pfad/zu/AuthKey_XXXXXXXXXX.p8   # nur Serverkopie; Original im Passwortmanager behalten
```

Der Assistent `deploy/swarm/setup.sh` kann das Secret ebenfalls anlegen (Abschnitt „Push“, fragt den Pfad der `.p8`-Datei). Ein Secret ist unveränderlich. Rotation: neues Secret mit neuem Namen anlegen, `APNS_KEY_SECRET` in `.env` anpassen, `update.sh --force`. Es gibt nur **einen** Key je Betrieb: `APNS_ENV=both` verlangt einen Key, der für beide Umgebungen gilt; bei umgebungsspezifischen Keys also eine Umgebung wählen (BESTÄTIGT, Backend `installation.md`).

## 3. Stack und `.env` [NUTZER, Backend]

Kein manueller Diff mehr (BESTÄTIGT, Backend `deploy/swarm/stack.yaml` und `stack.push.yaml`, `docs-site/content/installation.md`): `stack.yaml` reicht `PUSH_ENABLED` (Standard `false`), `APNS_KEY_FILE`, `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_TOPIC`, `APNS_ENV` durch. Das externe Secret hängt nur im Overlay `stack.push.yaml`, das `swarm-deploy.sh` bei `PUSH_ENABLED=true` zusätzlich einbindet; `update.sh`/`swarm-deploy.sh` prüfen vor dem Rollout, dass Secret und die drei APNS-Werte vorhanden sind, und brechen sonst ab. Vorgehen:

1. Neuinstallation: `deploy/swarm/setup.sh` (fragt Key-ID, Team-ID, Topic, Umgebung, Secret-Name, `.p8`-Pfad). Bestehende Installation: Werte in `.env` setzen, dann `deploy/swarm/update.sh --pull-scripts --force`.
2. `.env` (ungetrackt, Modus 600):

```sh
PUSH_ENABLED=true
APNS_KEY_SECRET=showernow_apns_key
APNS_KEY_ID=<10 Zeichen aus Schritt 1>
APNS_TEAM_ID=J2DU2P47XW
APNS_TOPIC=de.linolaske.showernow
APNS_ENV=production      # sandbox | production | both; muss zu den registrierenden Builds passen
```

- `APNS_ENV` und Key: TestFlight/App Store melden `production`, Xcode-Debug-Läufe `sandbox`. Meldungen einer nicht erlaubten Umgebung verwirft das Backend, die Testmeldung antwortet `409` (`environment_not_allowed`). Der Dienst prüft den Key beim Start nicht gegen Apple; Fehlbedienung zeigt sich erst zur Laufzeit (`apns_bad_device_token`, `apns_key_rejected`).
- `IMAGE_WIDTH` muss `1024` sein (Startfehler sonst). Mit `PUSH_ENABLED=true` und fehlenden `APNS_*`-Werten startet der Dienst nicht. Migrationen 003 bis 006 laufen über den Migrationsjob; 005 (`time_sensitive`) und 006 (Regionen) brauchen ALTER-Recht für den DB-Benutzer.
- Prüfen: `GET /v1/status` listet bei aktivem Push `capabilities` (mit `regions` ab Backend `34e6416`). Das Verhalten eines fehlenden Secrets im echten Swarm ist laut Backend-Doku nicht gegen einen Swarm geprüft.

## 4. Reihenfolge Sandbox und Produktion

1. **[ERLEDIGT]** App-Seite gebaut (Entitlement, Erklärung vor der Systemabfrage, Token-Registrierung, Datenschutztext im Sheet); ab Build 12 in TestFlight.
2. **Sandbox-Test** (Xcode-Debug-Build auf echtem Gerät): `APNS_ENV=sandbox` (oder `both`) und Sandbox-fähiger Key. Das Entitlement folgt dem Profil: Development-Profil → `development` (= Sandbox) (BESTÄTIGT).
3. **Produktion/TestFlight:** `APNS_ENV=production` mit Produktions-fähigem Key. Dass TestFlight-Builds Produktionstokens erhalten, folgt aus „Distribution-Profil → `production`“, steht aber **nicht ausdrücklich** auf den gelesenen Apple-Seiten (**UNGEPRÜFT**). Beim ersten TestFlight-Test deshalb auf `400 BadDeviceToken` achten: Umgebung/Key passt nicht zum Token.
4. Token und Umgebung müssen zusammenpassen, sonst `BadDeviceToken` (BESTÄTIGT). Die App meldet ihre Umgebung selbst (Debug → `sandbox`, Release → `production`); das Backend erlaubt je Betrieb die Menge aus `APNS_ENV`.
5. Ob für die Push-Zustellung ein neuer TestFlight-Build mit neuem Profil nötig ist: ja zu erwarten, weil sich Entitlement/Profil ändern (ANNAHME).

## 5. Test auf echtem Gerät und Rücknahme

- Simulator genügt nicht (kaum Remote-Token); echtes iPhone mit einem TestFlight- oder Debug-Build verwenden.
- [ ] In der App für einen Ort die Glocke aktivieren, Mitteilungen erlauben (Gerätetoken wird registriert).
- [ ] **Testablauf mit Testmeldung:** Info-Sheet → Abschnitt Mitteilungen → „Testmeldung senden“ (sichtbar bei mindestens einem aktiven Ort, erlaubten Mitteilungen und Gerätetoken; Limit 3 pro Stunde). Die Meldung kommt über `POST /v1/push/installations/<uuid>/test` und zeigt fertigen Text. Fehlerzeilen der App: `environment_not_allowed` (APNS_ENV passt nicht zum Build), `apns_bad_device_token`/`apns_key_rejected` (Umgebung bzw. Key), `apns_unavailable`, `token_unregistered` (Neuregistrierung), `test_rate_limited`.
- [ ] Backend-Log: kein `BadDeviceToken`/`DeviceTokenNotForTopic`/`403`. Keine Tokens in Logs ablegen oder weitergeben.
- [ ] Echter Regenalarm: abwarten, bis Regenbeginn im Vorlauf des Ortes eintritt. Erst mit dem Build nach Build 12 wird der Text lokalisiert angezeigt (`Localizable.strings`); Ergebnis in [status.md](status.md) festhalten.
- **Rücknahme:** `PUSH_ENABLED=false` in `.env` setzen, neu ausrollen. Der Radar-Dienst läuft weiter; die Registrierungs-API antwortet dann `404`, `capabilities` ist leer (BESTÄTIGT, Backend-Doku). Zusätzlich Abos in der App ausschalten; Datenlöschung (Tabellen `push_*`) ist eine eigene Betreiberentscheidung. Key bei Verdacht auf Verlust im Developer-Konto widerrufen.

## 6. Datenschutz und App-Privacy vor dem Livegang [NUTZER]

Mit Push speichert der Server Gerätetoken, Installations-ID, Hash des Geheimnisses und Rasterzelle (~1 km) dauerhaft. Das ändert die bisherige Aussage „keine Daten erhoben“ (Variante A, siehe `apple-externe-tests.md`).

- [ ] **Backend-`docs/decisions.md`**, Abschnitt „Pushdienst Backend“ (Änderungsbedarf `/datenschutz`): Text der Seite `/datenschutz` und der docs-site um „Regenwarnungen (optional)“ ergänzen, **vor** `PUSH_ENABLED=true` in Produktion. Beide Repos synchron halten.
- [ ] **App Store Connect → App-Privacy** auf Variante B umstellen (Gerätekennung/„Device ID“ ist Auslegung, UNGEPRÜFT; Standort: grobe Rasterzelle prüfen). Zweck App-Funktionalität, nicht für Tracking.
- [ ] Datenschutzerklärung-URL und In-App-Link zeigen auf den aktualisierten Text; Info vor erster Aktivierung ist in der App vorhanden (Erklärtext, Sheet mit Datenschutzerklärung); Textstand der Seite `/datenschutz` ist offen (Backend-Doku).
- [ ] Protokollierung des Reverse Proxys (Zoraxy) klären und `PROXY_LOG_NOTE` anpassen.
- [ ] Rechtsprüfung (Rechtsgrundlage, Löschfristen: 60 Tage Inaktivität laut Entwurf). Kein Rechtsrat.
- [ ] Review Guideline 4.5.4: Push nur als optionales Opt-in, keine sensiblen Daten oder Ortsnamen im Payload (BESTÄTIGT in der Recherche).
