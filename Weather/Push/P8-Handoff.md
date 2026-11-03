# P8 – Live Activity, App-Seite

Stand: 3. November 2026, integriert und nativ geprüft (siehe `docs/status.md`, Abschnitt Verifikation Backend-Vertrag). Dieses Dokument ist ein Übergabeprotokoll; Prüfaussagen unten, die Syntax-/Harness-Läufe nennen, sind überholt. Backend nur zur Vertragsprüfung gelesen, nicht verändert.

## Vertragsnachtrag (3. November 2026)

Quelle: neuer Backend-Vertrag im aktuellen Nutzerauftrag; kein erneuter Backend-/Rollout-Abgleich. Dieser Nachtrag ersetzt die frühere Aussage zur fehlenden tokenlosen Freigabe.

- Vor jedem POST/PUT mit `live_activity:true` wird das aktuelle Start-Token per Installations-PUT bestätigt. Fehlendes Token oder gescheiterte Meldung: Opt-in und ausstehende Änderung bleiben lokal erhalten, de/en-Vorbereitungsmeldung im Live-Activity-Einstellungsbereich, kein Abo-Upload mit `true`. Eine Rotation während der Meldung muss vor dem Abo-Upload neu bestätigt werden.
- `409 start_token_required`: Installations-PUT nachholen und das Abo genau einmal erneut senden. Misslingt die Nachmeldung oder der Wiederholungsversuch, bleibt das Opt-in ausstehend; `activity_full` und das bestehende Abo-Limit werden gesondert behandelt. Kein unmittelbarer weiterer Wiederholungsdurchlauf wegen dieses Fehlers.
- `503 activity_full`: Gateway überspringt die sonst für 503 geltenden Transport-Retries. Manager schaltet das betroffene Opt-in aus, synchronisiert `live_activity:false`, beendet gegebenenfalls eine lokale Activity und zeigt eine verständliche de/en-Meldung direkt im Live-Activity-Abschnitt. Spätere Syncs aktivieren das Opt-in nicht automatisch wieder. Auch der Activity-Token-Pfad behandelt diese Antwort.
- Activity-DELETE erhält ein optionales Token: `nil` bedeutet **kein Body**, niemals JSON-null. Vorhandenes gültiges Token bleibt tokenbezogen; leere/ungültige Strings werden lokal abgewiesen. Ende vor dem ersten Token und Opt-out ohne bekanntes Token geben Reservierungen beim nächsten möglichen Sync frei. Eine Ende-Meldung ohne Token löscht keine bereits bekannte neuere Activity. Fehlgeschlagene Freigaben bleiben im Speicher für einen späteren Sync.
- Reservierungen ohne Token verfallen serverseitig nach **15 Minuten**. Die lokale Acht-Stunden-Grenze gilt ausschließlich für laufende Activities und blockiert keine Reservierungsfreigabe. Kein lokaler Reservierungs-Wartetimer.

Geändert in diesem Nachtrag: `Weather/Push/PushManager.swift`, `PushGateway.swift`, `RainActivityManager.swift`, `RainActivityText.swift`, diese Übergabe, `Weather/Views/PlacePushSettingsView.swift`, `WeatherTests/PushActivityManagerTests.swift`, `PushActivityGatewayTests.swift`. `PushActivityWire.swift` bleibt unverändert. Vorhandene fremde Änderungen bleiben bestehen; keine Änderungen außerhalb der freigegebenen Pfade, keine Teilagenten, kein Commit/Push.

Prüfungen dieses Nachtrags:
- `swiftc -frontend -parse` für die sieben geänderten Swift-Dateien plus unverändertes `PushActivityWire.swift`: erfolgreich; reine Syntaxprüfung, kein Typcheck.
- `git diff --check -- Weather/Push/ Weather/Views/PlacePushSettingsView.swift WeatherTests/`: erfolgreich.
- Inzwischen nachgeholt (3.11.2026): Xcode-Builds (Weather, WeatherWatch), 409 Unit + 7 UI Tests grün. **Weiterhin nicht ausgeführt:** Gerätetests, echtes Backend/APNs. Die unten genannten älteren Harness-Ergebnisse gelten für den ursprünglichen P8-Stand.
- Tests erweitert um acht Manager-Tests (fehlendes/nicht bestätigtes Token; PUT/POST-Reihenfolge; erfolgreiche, erneut abgelehnte bzw. offline scheiternde 409-Wiederholung; gescheiterte Token-Nachmeldung; Obergrenze bei Abo-/Activity-Token-Meldung; tokenlose Freigabe) sowie zwei Gateway-Tests (DELETE ohne Body/ungültige Tokens, 503 ohne Retry). Bestehendes Fehlercode-Mapping und expliziter Fallback-Test angepasst. Weiterhin Fake-Transport und Fake-Activity-Manager, keine Zeit-/ActivityKit-Abhängigkeit dieser Tests.

Erledigt: Typprüfung, Push-Tests und volle Suite laufen (siehe Status).

## Vertrag und Umsetzung

- `Shared/RainActivityAttributes.swift`: statische `displayName`/`subscriptionID`; `ContentState` mit `phase` (`startsIn`, `raining`, `endsIn`, `dry`), `eventDate: Date?`, `intensityClass: Int`, `referenceTime: Date`, `staleDate: Date?`. Standard-Codable-Datumsstrategie, **Sekunden seit 2001**. APS-Zeitstempel sind getrennt davon UNIX-Sekunden. Abgleich: Backend `Sources/RadarCore/PushActivity.swift` und `docs-site/content/api.md`, Abschnitt Live Activities; kein Rollout vorausgesetzt.
- `effectiveStaleDate`/`isStale(at:)` begrenzen die Frische zusätzlich auf Referenzzeit + 20 min. P6 muss zuerst Frische prüfen und bei veralteten Daten niemals „trocken“ zusagen; ebenso `context.isStale` beachten.
- P2 sendet `displayName: ""`. App schreibt ausschließlich eine Zuordnung Abo-ID → lokale Ort-ID in App-Group-Defaults (`RainActivityAttributes.placeMappingDefaultsKey`). P6 kann `attributes.placeID(in: UserDefaults(suiteName: SharedConfig.appGroup)!)` nutzen, Ort in `PlaceStore` lesen, sonst neutralen Titel verwenden. Nicht force-unwrappen, wenn die Suite nicht verfügbar ist. Namen/Koordinaten werden nicht ans Backend gesendet.
- `PushManager`: Opt-in je Ortsabo (Migration: aus), Capability-Prüfung, Start-/Activity-Token nur im Speicher, PUT/DELETE mit Installation-Secret, Aufräumen bei Opt-out/Ortslöschung/Reset. Ausstehende Aboänderungen/-löschungen bleiben wie bisher persistent; Activity-Token-Löschversuche nur im Speicher (Tokens werden nicht persistiert). Backend beendet abbestellte Activities auch bei Offline-Opt-out nach Synchronisation des Abo-Felds; Abo-/Installationslöschung kaskadiert.
- `SystemRainActivityManager`: Beobachter werden bereits in `PushManager.live()` eingerichtet; der App-Delegate startet die Synchronisation auch ohne aktive Szene. Bestehende Activities und `activityUpdates`, Push-to-Start- und Activity-Token-Rotation, Ende/Dismissal, lokale Obergrenze acht Stunden, höchstens eine beobachtete Activity; fremde/nicht mehr abonnierte Activities werden beendet. Expliziter lokaler Fallback über `PushManager.startLiveActivityFallback(...)`, kein automatischer Start und kein neuer Produktbutton.
- `PlacePushSettingsView`: Schalter nur bei gemeldeter Capability (bestehendes Opt-in kann weiterhin ausgeschaltet werden), Systemfreigabe beachten, de/en-Texte und Datenschutz. Keine Regionsoption.

## Quellen

Apple am 3.11.2026: https://developer.apple.com/documentation/activitykit/activity/pushtostarttoken und https://developer.apple.com/documentation/activitykit/activity/pushtokenupdates-swift.property (Token-Rotation an Server melden); API-Signaturen zusätzlich im installierten iOS-27.2-SDK geprüft. https://developer.apple.com/documentation/activitykit/starting-and-updating-live-activities-with-activitykit-push-notifications war im Browser nur als JS-Platzhalter lesbar; keine darüber hinausgehende Prüfung behauptet.

## Dateien

Neu: `Shared/RainActivityAttributes.swift`, `Weather/Push/RainActivityManager.swift`, `PushActivityWire.swift`, `RainActivityText.swift` (letztere ebenfalls unter `Weather/Push/`), diese Übergabe, `WeatherTests/RainActivityContractTests.swift`, `PushActivityGatewayTests.swift`, `PushActivityManagerTests.swift` (alle unter `WeatherTests/`). Geändert: `Weather/Push/PushGateway.swift`, `PushManager.swift`, `Weather/Views/PlacePushSettingsView.swift`. Projekt-/Widget-/Watch-Dateien und Backend nicht verändert; vorhandene fremde Änderungen bleiben bestehen.

## Tatsächlich ausgeführte Prüfungen

- `swiftc -frontend -parse` für alle zehn geänderten/neuen Swift-Dateien: erfolgreich; reine Syntaxprüfung, kein iOS-Typcheck.
- `git diff --check`: erfolgreich.
- Temporärer macOS-SwiftPM-Harness außerhalb des Repos, Swift 6.4.2: **86 Tests, 0 Fehler**, darunter alle **21 neuen Tests** (6 ContentState/Mapping/Token-Format, 5 Gateway, 10 PushManager) und 65 vorhandene Push-/Regionen-Tests. Befehl: `swift test --disable-sandbox --package-path /tmp/weather-p8-harness --skip PushRegionWireTests.testPushLocKeysResolveInGermanAndEnglish` (Modulcaches unter /tmp).
- Grenzen des Harness: Shared-Modell, Gateway, Grid, Wire-Helfer und Texte unverändert kopiert. PushManager-Kopie ohne Observation-Dekoratoren, UIKit-/UserNotifications-Systemadapter, `live()` und App-Delegate; Synchronisations-/Zustandslogik unverändert. ActivityKit durch `RainActivityManaging` und Fake ersetzt. Radar-Konfiguration nur für `example.invalid` ersetzt; vorhandene `RadarRetryPolicy` herauskopiert (benötigter DWD-Fehlertyp gestubbt). Vorhandene Push-Grid-Tests wegen UI-Legendenabhängigkeit nicht aufgenommen. Ein vorhandener Bundle-Sprachressourcentest scheiterte zuerst am fehlenden App-Bundle im Harness und wurde dort ausdrücklich ausgenommen; keine Produktänderung dafür. Anfangs fehlende Harness-Abhängigkeiten wurden ergänzt. Keine Netzabfragen an den Pushdienst, nur Fake-Transport.
- Neue Tests: P2-Decodierung mit Standardepoch, alle Phasen/Null-Felder/Frische/4-KB-Grenze, IDs-Zuordnung, Token-Grenzen; Feld fehlt/null/Token, Activity-Pfade/Header/DELETE-Body und Fehlercodes; Capability-Gate, Rotation und Offline-Retry, alte bzw. tokenlose Ende-Meldung gegen neue Tokens, verspätetes Token nach Opt-out, Ende/DELETE/Starttoken-null beim Abschalten, persistent ausstehendes Opt-out ohne Capability, 409-Konflikte, Ortslöschung/Reset, Migration, Systemverbot und ausschließlich expliziter Fallback.

## Offen und nächste Schritte

1. Erledigt (3.11.2026): `xcodegen generate`, iOS-/Watch-Build und volle XCTest-/UI-Suite grün. Weiterhin ungeprüft: App-Delegate-Hintergrundpfad und ActivityKit-Laufzeit am Gerät, Signing/Archiv/Upload.
2. Erledigt (P6 Teil 2, `WeatherWidgets/LiveActivity/`): `ActivityConfiguration(for: RainActivityAttributes.self)` im Widget-Bundle, Sperrbildschirm/Island, Countdown nur für sinnvolle `eventDate`, Datenalter und veralteten Zustand; lokale Ortsauflösung wie oben, neutraler Titel bei fehlender Zuordnung. Typkonformität zu ActivityAttributes nur auf iOS, nicht watchOS/macOS. Kein Region-Abo. API: `RainActivityAttributes.Phase`, `RainActivityAttributes.ContentState(phase:eventDate:intensityClass:referenceTime:staleDate:)`; optionaler Event-/Stale-Zeitpunkt, restliche Felder erforderlich.
3. Gerätetests: echtes Push-to-Start (einschließlich Hintergrundstart), APNs-Token-Rotation, Dismissal, Offline-Wiederanlauf, Systemfreigabe, Anzeige und Acht-Stunden-Ende. Backend P2 ist laut Auftrag noch nicht ausgerollt. Lokale Timer laufen bei suspendierter App nicht zuverlässig; OS/Backend begrenzen die Laufzeit. Wird eine serverseitig reservierte Activity vor dem ersten Activity-Token beendet, erfolgt nun eine tokenlose Freigabe gemäß Vertragsnachtrag; bei fehlender Verbindung verfällt die Reservierung serverseitig nach 15 Minuten. Opt-out/-Löschung wird dennoch persistent über die bestehende Abo-/Installationssynchronisation verarbeitet.
4. Status ist in `docs/status.md` fortgeschrieben; `docs/decisions.md` bei Bedarf. Kein Commit/Push, keine neuen Signing-Ressourcen.
