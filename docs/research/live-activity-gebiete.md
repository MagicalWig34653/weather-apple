# Live Activities für Gebiets-Abos (Entwurf, 7.11.2026)

Nutzerwunsch: Live Activities auch für Umkreis-Abos (Zentrum + Radius, Anteil nasser Zellen), bisher nur Punkt-Abos. Reiner Entwurf, kein Produktcode. [B] = im Code/Doku gelesen, [A] = Annahme/Empfehlung. Backend-Pfade beziehen sich auf das Schwesterrepo (`Sources/RadarCore/...`, `docs-site/content/api.md`).

## 1. Punkt-Live-Activity heute (Ende-zu-Ende) [B]

- **Opt-in/Anmeldung:** App-Schalter `setLiveActivity` (`Weather/Push/PushManager.swift:477`, UI `Weather/Views/PlacePushSettingsView.swift:59`) setzt `liveActivity` am Ort und lädt das Abo mit `live_activity=true` hoch; verlangt ein gemeldetes Push-to-Start-Token (`409 start_token_required`, api.md Zeile 118; App `PushManager.swift:658-707`). Das Start-Token kommt aus `Activity<RainActivityAttributes>.pushToStartTokenUpdates` (`Weather/Push/RainActivityManager.swift:43-48`) und liegt je Installation in `push_install.la_start_token` (Migration 007).
- **Auslöser (Backend):** `PushService.evaluate` (`PushService.swift:97-225`) klassifiziert je Slot den Punkt (`classifyOrUnknown`, Zeile 135, unbekannt = -1), `PushEvaluator.step` liefert die Zwei-Läufe-Bestätigung plus 60-Minuten-Sperre (`last_sent_at`). Nur `isLA = liveActivity && kind == .point` (Zeile 146). Zweiter Startweg „es regnet schon“: Slot 0 nass in zwei Läufen (`wetSeen`, Zeilen 175-190).
- **Start:** `evaluateActivity` (`PushActivity.swift:91-113`): `reserveActivity` reserviert den Platz, danach APNs `event: start` mit `attributes-type: RainActivityAttributes`, `input-push-token`, `attributes {displayName:"", subscriptionID}` und Pflicht-Alert (`PushActivity.swift:23-47`). Topic `.push-type.liveactivity`, Start/Ende Priorität 10, Updates 5.
- **Updates:** je ausgewertetem Lauf `event: update` an das Activity-Token (Zeilen 99-104); Inhalt `PushActivityPayload.content` (Zeilen 6-21): `phase` (startsIn/raining/endsIn/dry), `eventDate`, `intensityClass` (Maximum der Klassen), `referenceTime`, `staleDate`. Datumsstrategie Swift-Referenzepoche (2001). Tatsächlich genutzt: `Shared/RainActivityAttributes.swift:31-55`.
- **Activity-Token:** App meldet es per `PUT .../activity` (`RainActivityManager.swift:68-78`); bis dahin Reservierung mit `activity_token NULL`, nach 15 min frei (A7).
- **Ende:** `dry` (kein nasser/unbekannter Slot in den nächsten 7 Slots = 30+ min sicher trocken), `endsAt` (8 h, auch ohne neue Radardaten, `expireActivities`, Zeilen 117-131), Opt-out/Abo gelöscht (`endableActivities`, `MariaRepo+Push.swift:333` mit `s.kind<>0`), 410/BadDeviceToken räumen Token auf (Zeilen 160-190). App-seitig lokaler 8-h-Timer (`RainActivityManager.swift:90-95`).
- **Hysterese:** Start nur nach Bestätigung in zwei Läufen und 60 min Sperre; Ende erst bei 30 min sicherer Trockenheit; unbekannte Pixel beenden nie. Verspätete Antworten per Tokenvergleich entschärft.
- **Slot-Regel:** Höchstens **ein** belegter Platz je Installation (PK `push_activity.subscription_id` plus Installation-Zeilenlock in `reserveActivity`/`writeActivity`; belegt = Start verworfen, `activitySlotBusy`, `PushActivity.swift:109-111`). Auf dem Gerät ebenfalls ein Activity: `observe` beendet jede weitere (`tokenTasks.isEmpty`, `RainActivityManager.swift:62`), Fallback verlangt `activities.isEmpty` (Zeile 121). Ein Activity pro Gerät/App ist also doppelt durchgesetzt.
- **Widget:** `WeatherWidgets/LiveActivity/RainLiveActivity.swift` (Lock Screen, Dynamic Island) mit `RainActivityPresentation.swift`; Ortsname lokal über `placeMappingDefaultsKey` (`PushManager.swift:850-855`), nur Orte, keine Regionen.
- **Ausdrücklich ausgeschlossen:** `live_activity:true` mit `kind:"circle"` ergibt `400 invalid_subscription` (api.md Zeile 118; Entscheidung 3.11., `docs/decisions.md` Backend „Regionen in v1 ausgeschlossen“).

## 2. Was für Gebiete fehlt

### Datenmodell Abo
- Backend: **keine Schemaänderung nötig** [B]: `push_sub.live_activity`, `kind`, `radius_cells`, `min_share` existieren (Migrationen 006/007), `push_activity` hängt nur an `subscription_id`. Nötig sind Code-Änderungen: Validierung (`PushApi.swift`, 400 für circle+LA aufheben), `isLA`-Filter (`PushService.swift:146`), `evaluateActivity` (`PushActivity.swift:105`, `kind == .point`), `activityTargets`/`endableActivities`/Eignung (`MariaRepo+Push.swift:333,352`: `kind<>0`, `kind==0`). Neue Capability `live_activity_regions` in `GET /v1/status`, damit neue Apps keinen 400 an alte Server senden (gleiches Muster wie `regions`).
- App: `RegionPushSettings` (`PushManager.swift:78-98`) bekommt `liveActivity` + `liveActivityDirty` (Decode mit Default, wie bei Orten Zeilen 57-67), `PushSubscriptionRequest` setzt `liveActivity`, Schalter in `RegionViews.swift`; Aufrufstellen, die nur `state.places` prüfen, müssen Regionen einbeziehen (Zeilen ~467, 583, 611, 659-707, `persist` 850-855 für die Namenszuordnung).

### Auslöser mit Anteil
- Heute liefert `PushRegion.pseudoClass` (`PushRegion.swift:77-90`) nur binär `threshold` oder `0` und bricht beim Erreichen der Mindestzahl ab. Für die Activity braucht man je Slot zusätzlich: Zahl nasser Zellen (Anteil in % der geclippten Zellen), Maximalklasse, Anteil unbekannter Zellen. Neue Funktion `PushRegion.slotStats` (ohne Abbruch, nur für LA-Regionen) und eine `classMap`-Variante, die „unbekannt" (halbtransparent) unterscheidet (`PushRegion.swift:95-111` kennt das nicht; Punktpfad hat `classifyOrUnknown`).
- Auslöser bleibt die bestehende Regionenlogik (Anteil ≥ `min_share`, mindestens 3 Zellen bzw. 1 bei < 30 Zellen), damit Alert und Activity konsistent sind; Start über denselben Automaten (`PushEvaluator.step` mit Pseudo-Klassen), Zwei-Läufe-Bestätigung, 60-min-Sperre, Ende 30 min sicher unter Anteil. Unsicherheit: Ist der Anteil unbekannter Zellen so groß, dass der Auslöser nicht sicher entscheidbar ist, zählt der Slot wie beim Punkt als „unbekannt" (verlängert, beendet nie).
- Rechenlast [A]: LA-Regionen sind durch `PUSH_MAX_ACTIVITY_SUBSCRIPTIONS` (5 000) und 3 Regionen/Installation begrenzt; zusätzlich je Slot ein Durchlauf über die Scheibe (r ≤ 40, ≤ ~5 000 Zellen); Messung mit `PushRegionBenchmark` einplanen.

### Inhalt der Activity
Vorschlag, additiv zu `ContentState` (alle neuen Felder optional, damit alte Widgets/Payloads weiter dekodieren; Swift-Codable nutzt für Optionals `decodeIfPresent`):
- `wetSharePercent: Int?` aktueller Anteil nasser Zellen (Slot 0), `peakSharePercent: Int?` höchster Anteil in den nächsten ~60 min, `intensityClass` = Maximalklasse im Gebiet (statt Punktklasse), `eventDate`/`phase` wie bisher aus dem Pseudo-Verlauf (nächster Regenbeginn bzw. voraussichtliches Ende).
- Attributes: `regionRadiusKm: Int?` (nil = Punkt). Radius ist beim Abo ohnehin gespeichert (`radius_cells`), kein Ort. `displayName` bleibt leer, Name lokal über Abo-ID.
- Widget-UI: Lock Screen „Umkreis 10 km", Headline „Regen beginnt in 12 min" oder „Regen im Gebiet", Zeile „34 % der Fläche nass, bis Klasse 4", Anteilsbalken; Dynamic Island compact: Symbol + Countdown, expanded: Anteil. `RainActivityPresentation.swift` und `RainLiveActivity.swift` (160 Zeilen) bekommen eine Gebietsvariante, `Shared/RainActivityAttributes.swift` wird zum Vertrag (Contract-first).
- Payload-Größe: aktuell < 300 Byte, Limit 4 096 (`PushActivity.swift:25`); mit 3 neuen Feldern < 400 Byte, unkritisch.

## 3. Konflikte
- **Mehrere Abos, ein Platz:** Installation und App erlauben nur eine Activity (siehe 1). Mehrere LA-Abos (Punkte und Gebiete) konkurrieren; heute gewinnt wer zuerst bestätigt, der andere Start geht verloren (Sperre bleibt 60 min, `PushActivity.swift:109`). Mit Gebieten wird das häufiger: ein Gebiet ist bei Regen im Umkreis früher nass als ein Punkt darin.
- **Priorität Punkt vs. Gebiet:** Optionen: (a) First come, first served (heutiges Verhalten, keine Verdrängung, kein Risiko für doppelte Starts), (b) Punkt hat Vorrang: Regel „Gebiet-Activity wird beendet, wenn ein Punkt-Start ansteht" (Verdrängung, braucht Ende + Neustart in einem Tick, Doppel-Alert-Risiko, mehr Zustände), (c) mehrere parallele Activities (iOS erlaubt mehrere pro App; Vertrag, Reservierung und App-Guard müssten umgebaut werden: PK `subscription_id` bleibt, Installation-Limit wird N, `tokenTasks.isEmpty` entfällt, Lock-Screen-Platz wird knapp).
- **Alert-Konsistenz:** Der gemeinsame Zeitstempel `last_sent_at` verhindert Doppel-Starts je Abo, nicht über Abos hinweg; Abos ohne Activity melden weiter den normalen Alert.
- **Alte Apps:** Sie senden nie `live_activity:true` für Regionen; ohne Capability-Gating gibt es keine Regression.

## 4. Datenschutz
- Keine neuen Standortdaten: Server hat Zentrum (3x3-Zellen ≈ 2 km), Radius und Anteil bereits im Regionen-Abo. Die Activity trägt nur Abo-ID, aggregierte Zahlen (Anteil, Klasse, Zeiten) und leeren Anzeigenamen. Kein Name, keine Koordinaten, keine Verläufe, keine zusätzlichen Logs (nur aggregierte Zähler wie bisher).
- Zusätzlich gespeichert: Activity-Token je LA-Region-Abo (Gerätekennung, wie bei Punkten, Kaskadenlöschung, 8 h). APNs sieht Inhalt (Aggregate) und Token wie bisher.
- Datenschutztext/App-Privacy: Live-Activity-Abschnitt ist offen („Freigabe vor Livegang", `docs/decisions.md`); Gebiete nur um einen Satz ergänzen, keine eigenmächtige Rechtsänderung.

## 5. Aufwand, Reihenfolge, Risiken

| WP | Inhalt | Dateibesitz | Aufwand [A] |
|---|---|---|---|
| WP0 | Vertrag einfrieren: neue ContentState/Attributes-Felder, Capability-Name, Fixtures, Payloadbeispiele | Backend `docs-site/content/api.md`, `docs/fixtures/`; App `Shared/RainActivityAttributes.swift` (nur Felder) | 0,5 Tag |
| WP1 Backend | `slotStats`/unknown-classMap, `PushActivityPayload.content` Gebietsvariante, Aufhebung der circle-Sperre in `PushApi.swift`, `PushService.swift`, `PushActivity.swift`, `MariaRepo+Push.swift`, `MemoryRepo+Push.swift`, `PushObserver.swift` (Trigger/Skip-Gründe), Tests (`PushActivityTests`, `PushTests`, Nebenläufigkeit, Benchmark), Doku | Backend `Sources/RadarCore/Push*`, `Tests/`, `docs-site`, `docs/decisions.md` | 2 bis 3 Tage |
| WP2 Dashboard | Insights/Push-Seite: Auslöser- und Skip-Zähler für Gebiets-LA, aktive Activities nach Art | Backend `dashboard/src/routes/push`, `InsightsRepoSource+Push.swift`, Fixtures | 0,5 Tag, nach WP1-Observer |
| WP3 App-Modell | `RegionPushSettings.liveActivity(+Dirty)`, Request, Sync, Fehler/Platz-Meldungen, Mapping für Regionsnamen, Tests | App `Weather/Push/PushManager.swift`, `WeatherTests/PushTests.swift` (derzeit lokal geändert, vorher klären) | 1 bis 1,5 Tage |
| WP4 App-UI/Widget | Schalter in `RegionViews.swift`, Widget-Gebietsdarstellung, Previews | App `Weather/Views/RegionViews.swift`, `WeatherWidgets/LiveActivity/*`, `Shared/` | 1 bis 1,5 Tage |

Reihenfolge: WP0, dann WP1 und WP3/WP4 parallel (getrennter Dateibesitz, gegen Fixtures), WP2 nach WP1, danach Backend-Deployment (additiv, Capability aus), Aktivierung, neuer App-Build, Geräteprüfung.
Migration: **keine Schemamigration**; Rollout abwärtskompatibel (altes Backend lehnt circle+LA mit 400 ab, deshalb Capability-Gating in der App). **Neuer App-Build nötig** (Widget-Extension und Shared-Attributes ändern sich; nächster Build nach 29), TestFlight-Prüfung am echten Gerät (Push-to-Start nicht im Simulator belegbar).
Risiken: (1) Slot-Konflikte und Nutzererwartung (siehe 3); (2) Flattern am Schwellwert des Anteils, deshalb Hysterese wie beim Alert; (3) unbekannte/halbtransparente Pixel bei Gebieten (Annahme Alpha 16..127 unverifiziert, `decisions.md`); (4) Rechenlast pro Lauf; (5) Wortwahl „Anteil nasser Zellen" ist nutzerfern, besser „x % der Fläche"; (6) Datenschutztext noch nicht freigegeben; (7) Activity-Budget 200 Sendungen/8 s je Tick bleibt gemeinsam mit Punkten.

## 6. Entwurfsvarianten

- **A (Empfehlung): Gebiet wie Punkt, plus Anteil.** Gleiche Phasen, Start/Ende über Pseudo-Klassen, ein Platz, first come first served. ContentState +`wetSharePercent`, `peakSharePercent`, Attributes +`regionRadiusKm`. Kleinster Umfang (siehe WP-Tabelle ca. 5 bis 7 Tage), wenig Zustände, kein neues Konfliktrisiko.
- **B: A plus Prognoseverlauf.** Zusätzlich ein kompaktes Array der Anteile der nächsten 12 Slots (≈ 12 Byte) und Mini-Balkendiagramm im Lock Screen. + Mehr Aussagekraft; − Mehr Widget-UI, größerer Test- und Designaufwand (+1 bis 2 Tage); als Ausbaustufe nach A möglich, Feld additiv.
- **C: Mehrere parallele Activities (Punkt und Gebiet) oder Priorisierung mit Verdrängung.** Löst den Platzkonflikt, ändert aber Vertrag (Installation-Limit N), App-Guard, Lock-Screen-Verhalten und die Reservierungs-/Concurrency-Tests (Review Runde 3). + Nutzer sieht beides; − hoher Aufwand (+3 bis 5 Tage), neue Fehlerklasse (Doppelstart, Verdrängung), noch kein Bedarf belegt.

Empfehlung: **A**, mit Vertragsfeldern so geschnitten, dass B additiv folgen kann; C erst, wenn Nutzer den Platzkonflikt tatsächlich erleben.

## Fragen an den Nutzer
1. Variante A (Empfehlung) oder B gleich mit Verlaufsbalken?
2. Platzkonflikt: first come first served (Empfehlung) oder Punkt hat Vorrang vor Gebiet? Oder Gebiet hat Vorrang, weil es früher Regen im Umfeld zeigt?
3. Auslöser der Activity: derselbe Anteil wie beim Alert (1/10/25 %, Empfehlung) oder eigener Schwellwert?
4. Anzeige: „x % der Fläche nass" (Empfehlung) plus Maximalklasse, oder reduziert nur Countdown wie bei Punkten?
5. Darf je Installation weiterhin nur eine Activity laufen, auch wenn mehrere Gebiete/Orte das Opt-in haben (Empfehlung: ja, in der UI klar sagen)?
6. Soll der Datenschutztext vor dem Livegang um den Satz „Live Activities auch für Gebiete" ergänzt werden (Freigabe nötig)?

## Nicht geprüft
Nichts gebaut oder getestet; Aufwände sind Schätzungen. Apple-Verhalten (mehrere Activities, Push-to-Start-Budgets) wurde hier nicht neu gegen Primärquellen geprüft; vor Variante C anhand der ActivityKit-Dokumentation zu verifizieren.
