# APNs-Einrichtung (Betreiber-Checkliste)

Stand: 31. Oktober 2026. Nur Anleitung; nichts bei Apple angelegt, im Backend-Repo nichts geändert. Hintergrund und geprüfte Apple-Aussagen: [research/push-benachrichtigungen.md](research/push-benachrichtigungen.md) (Abschnitte 3.5, 4, 8). Stil/Kennzeichnung wie [apple-externe-tests.md](apple-externe-tests.md): **BESTÄTIGT** = in Repo oder Apple-Quelle gelesen, **UNGEPRÜFT** = Annahme/Drittquelle. Keine Geheimnisse hier eintragen (Key-Datei, Passwörter, Tokens bleiben lokal).

Markierung: **[NUTZER]** nur der Kontoinhaber kann es tun. **[APP FEHLT]** in der App noch nicht gebaut (Push-Seite der App ist offen: Capability/Entitlement, Berechtigungsfluss, Token-Registrierung, Datenschutz-Einwilligung). **[BACKEND]** laut Backend-Doku vorhanden, aber standardmäßig aus.

## 1. Apple Developer [NUTZER]

- [x] Capability erledigt (31.10.2026, siehe [signing.md](signing.md)): Entitlement im Projekt, per `-allowProvisioningUpdates` in Development- und Store-Profil enthalten. Ursprüngliche Anleitung (nur falls erneut nötig): App-ID `de.linolaske.showernow` (Team `J2DU2P47XW`, beides vorläufig laut `AGENTS.md`): unter Certificates, Identifiers & Profiles → Identifiers die Capability **Push Notifications** aktivieren. Provisioning-Profile danach neu erzeugen; bei automatischem Signing macht Xcode das (UNGEPRÜFT).
- [ ] **APNs-Auth-Key** anlegen: Keys → „+“ → Apple Push Notifications service (APNs). Optionen (BESTÄTIGT, Apple-Quelle in der Recherche):
  - **Team-scoped, nur Sandbox** und **team-scoped, nur Produktion**: je Umgebung begrenzbar, höchstens zwei je Umgebung; Apple empfiehlt umgebungsspezifische Keys. Sinnvoll, wenn Debug-Läufe (Sandbox) und TestFlight/App Store (Produktion) getrennte Schlüssel haben sollen.
  - **Key für beide Umgebungen** (älteres Modell, bleibt gültig): ein Key für alles; einfacher, aber größerer Schaden bei Verlust.
  - **Topic-specific**: nur einzelne App-Topics, eine Umgebung, bis 200 je Umgebung. Für eine einzelne App sinnvoll, wenn das Team später weitere Apps hat.
  - Empfehlung (ANNAHME): erst **ein Key nur Produktion** (deckt TestFlight), Sandbox-Key nur wenn Xcode-Debug-Läufe mit Push getestet werden sollen.
- [ ] `.p8` herunterladen und sicher ablegen (Passwortmanager/verschlüsselt). Dass Apple die Datei **nur einmal** zum Download anbietet, ist **UNGEPRÜFT** (verbreitete Annahme); vorsichtshalber sofort sichern. Nie ins Repo.
- [ ] **Key-ID** (10 Zeichen) notieren; steht in der Key-Liste und im Dateinamen `AuthKey_<KeyID>.p8`.
- [ ] **Team-ID** (10 Zeichen): developer.apple.com → Membership details; auch in App Store Connect unter Benutzer und Zugriff → Schlüssel/Membership. Das Repo nennt `J2DU2P47XW` (vorläufig).

## 2. Secret im Swarm anlegen [NUTZER, auf dem Swarm-Manager]

```sh
docker secret create showernow_apns_key /pfad/zu/AuthKey_XXXXXXXXXX.p8
shred -u /pfad/zu/AuthKey_XXXXXXXXXX.p8   # nur Serverkopie; Original im Passwortmanager behalten
```

Ein Secret ist unveränderlich. Rotation: neues Secret mit neuem Namen anlegen, `APNS_KEY_SECRET` in `.env` anpassen, neu ausrollen (BESTÄTIGT, Backend-`installation.md`). Ein Key für Sandbox **und** ein anderer für Produktion (`APNS_ENV=both`) bräuchte zwei Secrets; der aktuelle Stack kennt nur eines (BESTÄTIGT: nur `APNS_KEY_FILE`). Deshalb zunächst nur eine Umgebung je Key.

## 3. Änderungen an `stack.yaml` und `.env` [NUTZER, Backend-Repo]

Stand der Backend-Dateien gelesen: `deploy/swarm/stack.yaml` verweist **nicht** auf das Secret (ein fehlendes externes Secret würde jeden Rollout scheitern lassen), `.env.example` enthält die Push-Zeilen auskommentiert. Konkrete Änderung laut `docs-site/content/installation.md` (nicht ausgeführt):

```diff
 x-radar: &radar
   environment: &environment
     ...
     TESTFLIGHT_URL: ${TESTFLIGHT_URL:-}
+    PUSH_ENABLED: ${PUSH_ENABLED:-false}
+    APNS_KEY_FILE: /run/secrets/apns_key
+    APNS_KEY_ID: ${APNS_KEY_ID:-}
+    APNS_TEAM_ID: ${APNS_TEAM_ID:-}
+    APNS_TOPIC: ${APNS_TOPIC:-}
+    APNS_ENV: ${APNS_ENV:-production}
-  secrets: [db_password]
+  secrets: [db_password, apns_key]
 ...
 secrets:
   db_password:
     external: true
     name: ${DB_PASSWORD_SECRET:-showernow_db_password}
+  apns_key:
+    external: true
+    name: ${APNS_KEY_SECRET:-showernow_apns_key}
```

`.env` (Werte nur auf dem Server; `.env` ist ungetrackt, mode 600; `update.sh` kopiert sie und schreibt nur den Image-Tag um):

```sh
PUSH_ENABLED=true
APNS_KEY_SECRET=showernow_apns_key
APNS_KEY_ID=<10 Zeichen aus Schritt 1>
APNS_TEAM_ID=<10 Zeichen>
APNS_TOPIC=de.linolaske.showernow
APNS_ENV=production      # sandbox | production | both; muss zu den registrierenden Builds passen
```

- `IMAGE_WIDTH` muss `1024` sein, sonst Startfehler bei `PUSH_ENABLED=true` (BESTÄTIGT, `installation.md`). `stack.yaml` und `.env.example` setzen `IMAGE_WIDTH` nicht; der Standardwert ist vermutlich 1024 (UNGEPRÜFT). Nicht setzen oder ausdrücklich `1024`. Beim ersten Start die Logmeldung prüfen.
- Mit `PUSH_ENABLED=true` und fehlenden `APNS_*`-Werten startet der Dienst nicht (BESTÄTIGT). Reihenfolge deshalb: Secret anlegen, dann Stack und `.env` ändern, dann ausrollen (`update.sh` bzw. `swarm-deploy.sh`; die Migration `003_push.sql` läuft über den Migrationsjob, additiv).
- Eigene Backend-Änderung ist bewusst nicht Teil dieses Repos; Diff nur als Vorlage.

## 4. Reihenfolge Sandbox und Produktion

1. **[APP FEHLT]** Zuerst App-Seite bauen: (Capability/Entitlement `aps-environment` ist seit 31.10.2026 vorhanden), Berechtigungsanfrage mit Erklärung, Token-Registrierung, Einwilligung/Datenschutztext. Ohne sie ist serverseitig nichts testbar.
2. **Sandbox-Test** (Xcode-Debug-Build auf echtem Gerät): `APNS_ENV=sandbox` (oder `both`) und Sandbox-fähiger Key. Das Entitlement folgt dem Profil: Development-Profil → `development` (= Sandbox) (BESTÄTIGT).
3. **Produktion/TestFlight:** `APNS_ENV=production` mit Produktions-fähigem Key. Dass TestFlight-Builds Produktionstokens erhalten, folgt aus „Distribution-Profil → `production`“, steht aber **nicht ausdrücklich** auf den gelesenen Apple-Seiten (**UNGEPRÜFT**). Beim ersten TestFlight-Test deshalb auf `400 BadDeviceToken` achten: Umgebung/Key passt nicht zum Token.
4. Token und Umgebung müssen zusammenpassen, sonst `BadDeviceToken` (BESTÄTIGT). Es ist daher wichtig, dass die App ihre Umgebung meldet (Entwurf: DEBUG → sandbox, sonst production).
5. Ob für die Push-Zustellung ein neuer TestFlight-Build mit neuem Profil nötig ist: ja zu erwarten, weil sich Entitlement/Profil ändern (ANNAHME).

## 5. Test auf echtem Gerät und Rücknahme

- Simulator genügt nicht für den Produktionsweg (UNGEPRÜFT, für Remote-Push auf Simulatoren gibt es Einschränkungen); echtes iPhone verwenden.
- [ ] Abo für einen Ort in der App aktivieren (sobald gebaut), Mitteilungen erlauben.
- [ ] Backend-Log: Registrierung angekommen, kein `BadDeviceToken`/`DeviceTokenNotForTopic`/`403`. Keine Tokens in Logs ablegen oder weitergeben.
- [ ] Auslösen: abwarten, bis Regenbeginn im Vorlauf des Ortes eintritt, oder (falls das Backend es hergibt) ein Testereignis; Ergebnis im Status festhalten.
- **Rücknahme:** `PUSH_ENABLED=false` in `.env` setzen, neu ausrollen. Der Radar-Dienst läuft unverändert weiter; die Registrierungs-API antwortet dann `404` (BESTÄTIGT, Backend-`decisions.md`). Zusätzlich: Abos in der App ausschalten; Datenlöschung (Tabellen `push_*`) ist eine eigene Betreiberentscheidung. Key bei Verdacht auf Verlust im Developer-Konto widerrufen.

## 6. Datenschutz und App-Privacy vor dem Livegang [NUTZER, teils APP FEHLT]

Mit Push speichert der Server Gerätetoken, Installations-ID, Hash des Geheimnisses und Rasterzelle (~1 km) dauerhaft. Das ändert die bisherige Aussage „keine Daten erhoben“ (Variante A, siehe `apple-externe-tests.md`).

- [ ] **Backend-`docs/decisions.md`**, Abschnitt „Pushdienst Backend“ (Änderungsbedarf `/datenschutz`): Text der Seite `/datenschutz` und der docs-site um „Regenwarnungen (optional)“ ergänzen, **vor** `PUSH_ENABLED=true` in Produktion. Beide Repos synchron halten.
- [ ] **App Store Connect → App-Privacy** auf Variante B umstellen (Gerätekennung/„Device ID“ ist Auslegung, UNGEPRÜFT; Standort: grobe Rasterzelle prüfen). Zweck App-Funktionalität, nicht für Tracking.
- [ ] Datenschutzerklärung-URL und In-App-Link zeigen auf den aktualisierten Text; **[APP FEHLT]** Info vor erster Aktivierung in der App.
- [ ] Protokollierung des Reverse Proxys (Zoraxy) klären und `PROXY_LOG_NOTE` anpassen.
- [ ] Rechtsprüfung (Rechtsgrundlage, Löschfristen: 60 Tage Inaktivität laut Entwurf). Kein Rechtsrat.
- [ ] Review Guideline 4.5.4: Push nur als optionales Opt-in, keine sensiblen Daten oder Ortsnamen im Payload (BESTÄTIGT in der Recherche).
