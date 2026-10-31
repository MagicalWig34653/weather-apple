# Projektstand und verbindliche Entscheidungen

Stand: 28. Oktober 2026. App-Name: ShowerNow; Bundle-ID: `de.linolaske.showernow`. Entwicklung nach geklärten Einstiegsfragen freigegeben; Reihenfolge gemäß `plan.md`.

## Produkt

Native, werbefreie Regen-App mit nachvollziehbaren Datenzeitpunkten, kurzfristiger Ortsprognose und optionalen datensparsamen Regenwarnungen. Keine verpflichtenden Benutzerkonten. Lokale Ortsnamen bleiben auf dem Gerät.

## Vereinbarte Reihenfolge

1. DWD-Datenquellen, Radar und numerische Ortsprognose technisch validieren. Produkteigenschaften bleiben bis zur Prüfung offene Annahmen.
2. Eine eigenständig nutzbare iPhone-App fertigstellen: Regenradar, animierte Zeitleiste, Ortsprognose, Standort, lokale gespeicherte Orte, Datenalter, Cache, Light/Dark Mode und Regen-Widgets.
3. Bereits die erste brauchbare iPhone-Version intern über TestFlight im Alltag testen; nicht auf alle Plattformen oder das Backend warten.
4. iPadOS und macOS sind Ziele der ersten Produktversion mit angepasster Bedienung. watchOS ergänzt kompakte Ortsprognosen und Komplikationen. Die konkrete Release-Reihenfolge bleibt abzustimmen.
5. Erst nach der nutzbaren App den zentralen Pushdienst umsetzen. Automatische Regenwarnungen bei geschlossener App hängen von diesem Schritt ab.
6. Später Unterwegs-Warnungen, Wind- und Temperaturkarten, Wolken-/Satellitenansichten, tvOS und visionOS. visionOS zunächst im Simulator evaluieren; eigene Vision Pro ist nicht vorhanden.

Widgets sollen Regenstatus und/oder Niederschlagsverlauf für einen ausgewählten Ort zeigen und direkt dorthin verlinken. Aktualität und technische Machbarkeit ohne Backend sind zu prüfen. Umfang der Watch-Radaransicht und genaue Widgetgrößen sind noch offen.

## Architektur und Datenschutz

- Swift und SwiftUI; MapKit und CoreLocation für die Apple-App.
- Karte: Direktweg zum DWD bleibt Fallback; ein eigener Radar-Cache (Backend) wird gebaut, siehe Abschnitt "Radar-Cache-Backend" (30. Oktober 2026), der den früheren Grundsatz "unabhängig vom Backend, direkt vom Anbieter" für die Standardroute ersetzt.
- Numerische Ortsprognose ohne Backend ist ein frühes Validierungsthema, noch keine bestätigte Datenkette.
- Zentraler Backend-Stack: Swift/Vapor, MariaDB, Docker Swarm; stateless Replikate, persistente Jobkoordination und Push-Outbox.
- Keine Serverregistrierung ohne aktivierte Pushabonnements.
- Für Warnungen möglichst Rasterzellreferenzen statt exakter Koordinaten, keine Ortsnamen und keine Bewegungshistorie übertragen.
- Keine Werbung, Analyse-SDKs oder verpflichtenden Konten.

## Identität und Veröffentlichung

- Lokale Zielordner heißen jeweils `weather`.
- Vorgesehene GitHub-Namen: `weather-apple` und `weather-backend`; öffentlich, sobald Zugang und Veröffentlichung möglich sind.
- Aktuelle Haupt-Bundle-ID: `de.linolaske.showernow`; App-Name: ShowerNow.
- Apple Team ID: `J2DU2P47XW`, durch bisheriges Signing bestätigt.
- App-Name und Bundle-ID werden jetzt gemeinsam geändert; technische Module/Projektname Weather und Ordner weather bleiben zulässig. Abhängige IDs für Widgets, Watch, App Groups etc. erst bei Target-Einrichtung festlegen.
- Aktueller Release-Kandidat: `0.1.0 (4)`; Build 3 ist intern nutzbar bestätigt. Der Nutzer hat die Umstellung seines aktuellen App-Store-Connect-Eintrags auf die neue Bundle-ID bestätigt.
- AGPLv3 ist angestrebt. Lizenzentscheidung und mögliche Zusatzerlaubnisse für App-Store-Veröffentlichung sind offen. Es wird deshalb noch keine endgültige Lizenz behauptet.

## Quellenhierarchie

Aktuelle ausdrückliche Nutzerentscheidungen haben Vorrang. Dieses Dokument ergänzt und aktualisiert `concept-v2.md`, insbesondere hinsichtlich Plattformen und Reihenfolge. Das ursprüngliche Konzept bleibt als unveränderte Referenz erhalten.

## Verbindliche Arbeitsweise (Nutzerentscheidung vom 28. Oktober 2026)

Möglichst kostensparsam entwickeln. Agents sind Pflicht. Sessions müssen wegwerfbar sein und das Repo ist die Source of Truth; alle relevanten Ergebnisse und Entscheidungen sind immer im Repo zu dokumentieren. Der konkrete Prozess steht in `AGENTS.md`, der fortsetzbare Arbeitsstand in `docs/status.md`.

## Entwicklungsstart und Testgeräte (28. Oktober 2026)

- Nutzerfreigabe: Plan schreiben, Einstiegsfragen klären, danach anfangen. Alle drei Einstiegsfragen sind beantwortet; der Start ist damit freigegeben.
- iPhone 17 Pro und 18 Pro, Apple Watch Ultra, Apple-Silicon-Macs; jeweils 27er-Systemversionen. Zunächst diese Mindestgeneration der Betriebssysteme vorsehen.
- Erster interner TestFlight-Build nur mit brauchbarer iPhone-App; Widgets und Watch folgen danach.
- Damalige Freigabe: Weather / de.linolaske.weather auch für TestFlight; durch die folgende ausdrückliche ShowerNow-Entscheidung überholt.
- Datenvalidierung vor größerem UI-Ausbau; Backend bleibt zurückgestellt.

## Datenvalidierung — Arbeitsbefund

Ein direkter DWD-WMS-GetFeatureInfo-Request kann25Zeitpunkte als kleine JSON-Serie liefern. Bei einem nassen Kontrollpunkt stimmen alle Werte mit dem gleichen Rohdatenlauf überein. Dies ist ein validierter Kandidat für die direkte App-Ortsprognose, noch keine endgültige Datenadapterentscheidung. Die JSON-Property entspricht dort5-Minuten-Akkumulation; fehlende Werte, Laufaktualität und weitere Orte müssen vor Produktnutzung geprüft werden. Befunde im Apple-Repo unter `docs/research/`.

## Private lokale Repository-Zuordnung

Absolute lokale Repository-Pfade werden ausschließlich in der ignorierten `LOCAL_WORKSPACE.md` gespeichert. Öffentliche Dateien enthalten nur die Vorlage und GitHub-Verweise. `AGENTS.md` weist neue Sessions auf die optionale lokale Zuordnung hin. Diese Rechnerkonfiguration ist die Ausnahme zur versionierten Dokumentation; Produktentscheidungen, Prüfergebnisse und Arbeitsstände bleiben im Repo. Vor Veröffentlichung Ignore-Regel und Ausschluss aus dem Git-Index prüfen.

## App-Store-Connect-Aufteilung

Nutzer möchte benachrichtigt werden, sobald die neue explizite Bundle-ID über ein spezifisches Profil belegt ist (eine Portal-Auswahlliste gesondert prüfen). Den App-Datensatz legt der Nutzer selbst an. Kein App-Datensatz durch Agents anlegen. Registrierung/Signing-Zustand nur nach tatsächlicher Prüfung als erledigt melden; Projektkonfiguration allein ist keine Registrierung.

## Erster Implementierungsstand und App-Eintrag

Der erste native iPhone-Prototyp verwendet den direkt abgeglichenen WMS-Punktdatenweg ohne eigenes Backend. Abfragen verwenden explizite Datenläufe und exakt UTC-Zeitstempel mit Millisekunden (`.000Z`), da der Live-Dienst die kürzere Form bei Punktabfragen ablehnte. Das ist ein beobachteter Schnittstellenbefund, keine allgemeine Datumsformatannahme.

Der Hauptagent koordiniert ausschließlich; technische Arbeit wird an neue abgegrenzte Agents vergeben. Details in `team.md` und `AGENTS.md`.

Historisch wurde `de.linolaske.weather` über ein spezifisches Distributionsprofil bestätigt. Nach der Mitteilung hat der Nutzer den damaligen App-Store-Connect-App-Eintrag selbst angelegt. Der Build-2-Upload unter dieser alten ID wurde angenommen; Verarbeitung und interne Verfügbarkeit sind getrennt zu prüfen, siehe [Uploadbefund](testflight-upload.md).

## Export-Compliance des aktuellen Prototyps

`ITSAppUsesNonExemptEncryption=false` ist für den geprüften Stand gesetzt: ausschließlich systemeigene HTTPS-Verbindungen und Dateischutz, keine eigene oder fremde Kryptografieimplementierung. Apples Primärdokumentation und Codebefund wurden vor der Änderung geprüft; Quelle und Grenzen in `testflight-readiness.md`. Bei zusätzlichen SDKs oder eigener Kryptografie erneut bewerten. Dies ist keine pauschale Aussage zu sämtlichen späteren Funktionen.

## Ausgewähltes App-Icon und aktueller Release-Kandidat

Der Nutzer hat Variante B (Radar) aus dem Designcheckpoint `fd601e1` gewählt. Nur dieses vollständige native Icon-Composer-Package ist als `AppIcon.icon` im App-Target aktiv. Beide editierbaren Originalvarianten und die SVG-Kompositionen bleiben unter `design/Icon/` erhalten. Der verworfene ältere Entwurf wurde vollständig ersetzt.

Die Integration ist mit Apples Asset-Kompilierung, Bundle-Metadaten und dem damaligen signierten lokalen Release-Export belegt; Details und die Grenze der nicht möglichen Homescreen-GUI-Sichtung in [icon.md](icon.md). Der Build-2-Upload verwendet dieses Radar-Icon. Für spätere Freigaben ausschließlich passende geprüfte Archive verwenden; das unabhängige begrenzte Release-Review ist ohne offene P1-/P2-Befunde oder erkannte Uploadblocker abgeschlossen. Der geprüfte Quellencheckpoint geht dem separaten Uploadauftrag voraus.

## Packaging und erster interner Upload

Der erste Upload von `0.1.0 (1)` scheiterte mit Apple `90474`: Die tatsächliche Gerätefamilie ist `1,2`, da XcodeGen-Targetdefaults den Projektwert `1` überschreiben. Die enge Korrektur erhält diese Universal-Metadaten, ergänzt ausdrücklich alle vier iPad-Orientierungen und belässt die drei iPhone-Orientierungen; kein Fullscreen-Schalter oder Gerätefamilienwechsel zur Umgehung der Validierung. Buildnummer `2` unterscheidet den korrigierten Kandidaten eindeutig. Dies bleibt ein auf iPhone validierter Prototyp, keine eigenständige iPad-Freigabe oder angepasste iPad-Oberfläche.

Quellencheckpoint `0f48cb5` ist unabhängig geprüft und veröffentlicht. Genau ein Upload von `0.1.0 (2)` über den vorhandenen offiziellen Xcode-Account wurde am 28. Oktober 2026 erfolgreich angenommen. Der belegte Endzustand ist `PROCESSING`; abgeschlossene Verarbeitung oder interne Gruppenzuordnung sind nicht belegt. Der Upload ist nur für interne TestFlight-Verteilung bestimmt. Kein zusätzlicher API-Schlüssel wurde vorausgesetzt, keine Zugangsdaten ausgelesen und keine Tester-/Rollenänderung vorgenommen. Details in [testflight-upload.md](testflight-upload.md).

## Verbindliche Umbenennung in ShowerNow

Nutzerentscheidung vom 28. Oktober 2026: App-Name **ShowerNow**, Bundle-ID ebenfalls ändern auf **`de.linolaske.showernow`**, Team bleibt `J2DU2P47XW`; Version `0.1.0`, Build `3`. Frühere Anweisungen zum Beibehalten von `de.linolaske.weather` sind überholt. Keine Funktions-/Designänderung; Radar-Icon und Packaging bleiben erhalten.

Die alte ID bleibt ausschließlich historisch: Build 1 wurde mit `90474` abgelehnt; Build 2 wurde transportiert/angenommen (`PROCESSING`). Zusätzlich berichtet der Nutzer einen Namenskonflikt mit Weather. Kein Befund bestätigt einen nutzbaren TestFlight-Build. [Historische Uploadbefunde](testflight-upload.md).

Ein lokaler Displayname und das ASC-Feld „Name“ sind getrennt. Apple beschreibt Einschränkungen für Bundle-ID-Änderungen an App-Datensätzen mit bereits zugeordnetem Upload; dies ordnet die historische Weather-Identität ein. Der Nutzer hat ausdrücklich bestätigt: „Die BundleID ist im Connecteintrag geändert.“ Der aktuelle ASC-Eintrag gilt damit für `de.linolaske.showernow` als bestätigt; ein weiterer neuer App-Datensatz ist keine Voraussetzung. Keine direkte Portalabfrage wurde durchgeführt. Die offiziellen AppsService-Antwortdaten beim nachfolgenden Build-3-Upload bestätigen ShowerNow / `de.linolaske.showernow` / `removed=false`. Agents ändern keine App-Datensätze, Rollen oder Tester. Das konkrete explizite Distributionsprofil belegt die neue ID. Das unabhängige Identity-Review ist ohne offene P1-/P2-Befunde abgeschlossen; Quellencheckpoint `2e500fc` ist veröffentlicht, und genau ein Build-3-Upload wurde erfolgreich angenommen. Letzter Serverzustand am 28. Oktober 2026 um 17:51:38 Uhr MEZ: `PROCESSING`; abgeschlossene Verarbeitung und interne Verfügbarkeit bleiben offen. [Apple: Bundle-ID ändern](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier), [ASC-App-Informationen](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), geprüft am 28. Oktober 2026.

Der lokale ShowerNow-Release-Export ist erfolgreich: Das tatsächliche eingebettete Distributionsprofil bestätigt `J2DU2P47XW.de.linolaske.showernow`, Team `J2DU2P47XW`, `get-task-allow=false` und keine Geräteliste. Die neue explizite ID ist damit belegt; der Lead wurde sofort informiert. Der passende aktuelle ASC-Eintrag ist durch den Nutzer bestätigt. Der gezielte finale Metadatenfix setzt zusätzlich `CFBundleName` auf den zentralen Anzeigenamen ShowerNow; technische Produkt-/Modulnamen bleiben Weather.

## Bestätigter Alltagstest und nächster Verbesserungsschritt

Der Nutzer bestätigt am 28. Oktober 2026: ShowerNow `0.1.0 (3)` funktioniert intern über TestFlight. Frühere Aussagen über noch unbestätigte Verfügbarkeit beschreiben den damaligen Uploadstand. Die App lädt subjektiv langsam; dies ist Nutzerfeedback, noch kein gemessener Engpass.

Freigegeben sind bedarfsgerechte Cache-/Ladeverbesserungen und eine Simulatorprüfung mit kompakterem schwebendem nativen Liquid-Glass-Zeitslider, weniger Text und klarer Zeit-/Play-/Jetzt-Bedienung. Datenalter, Messung/Vorhersage, Quellen, Fehler und Barrierefreiheit bleiben erhalten. Eine kleine optionale lokale Apple-Foundation-Models-Einordnung ist gewünscht, sofern die offizielle API-/SDK-Prüfung dies trägt. Keine neue Wetterprognose, erfundenen Zahlen oder Warnungsersatz erzeugen; deterministische Prognose und Fallback dürfen nicht auf KI warten. Backend bleibt für diesen Auftrag unverändert.

## Integrierter Verbesserungskandidat Build 4

Der nächste interne Kandidat ist `0.1.0 (4)` unter unveränderter ShowerNow-Identität. Begrenzte Speicherwiederverwendung und In-Flight-Deduplizierung adressieren belegte Abruf-/Ablaufkosten; Radarstart wartet nicht mehr auf Punktdaten. Kein zusätzlicher Diskcache oder pauschales Frame-Prefetch ohne Vorteilnachweis. Die Karte erhält zwei kompakte native Liquid-Glass-Flächen; Diagramm, Quellen und ausführliche Hinweise bleiben über Details erreichbar.

Die lokale manuelle Einordnung ist umgesetzt: Apple Foundation Models priorisiert maximal zwei zulässige, deterministisch belegte Fakten, die App rendert ausschließlich hinterlegte deutsche Sätze. Keine zusätzliche Prognose, frei erfundenen Zahlen, Scores oder Warnungen. Verfügbarkeit, deutsche Sprache, frische vollständige Daten und Ergebnisidentität werden geprüft; keine Koordinaten/Ortsnamen im Prompt, keine Persistenz, kein automatischer Startrequest. Bei nur einem Fakt wird die Generation gespart. Tatsächliche Modellgeneration auf bereiter Hardware bleibt offen. Nach unabhängigem Review folgt der bereits autorisierte Quellencheckpoint und offizielle interne Upload; keine neuen Konten-, Tester- oder Rollenänderungen.

Der unabhängige Review des integrierten Build-4-Stands ist ohne offene P1-/P2-Befunde abgeschlossen; Details in [review-build4.md](review-build4.md). Der veröffentlichte Quellencheckpoint ist die verbindliche Grundlage für das folgende signierte Archiv und den internen Upload. Archiv-/Uploadstatus wird separat belegt.

## P0 nach Alltagstest von Build 4

Aktuelles Nutzerfeedback: Build 4 lädt noch langsamer, dauerhaft unvollständiges Radar und kein erkennbares Refreshfeedback machen die App kaum bedienbar. Zuerst begrenzte echte DWD-/Overlaydiagnose samt Lade-/Abbruch-/Laufverfügbarkeitsnachweisen, dann gezielter frischer Fixauftrag. Kein weiterer TestFlight-Build vor belegter Bedienbarkeit; KI-Ausbau pausiert. Der parallel autorisierte kompaktere Timelineentwurf und Refreshfeedback bleiben UI-Arbeit, haben gegenüber funktionierendem Radar nachgeordnete Priorität. Vorherige Fixture-/UI-Grünbefunde sind keine Live-Latenzfreigabe.

## Nahezu sofortiges Laden bei begrenztem API-Budget

Neue Nutzeranforderung: möglichst nahezu sofort laden, ohne die DWD-API zu überstrapazieren. Gültige vorhandene Karten wiederverwenden, tatsächlichen Datenzeitpunkt erhalten und Aktualisierungen gezielt begrenzen. Kein pauschales Frame-Prefetch, zusätzliches Polling oder Lastverschiebung durch neue Infrastruktur. Warmer Cache kann Netzabrufe vermeiden; ein kalter Erstabruf bleibt von Netz und DWD-Verfügbarkeit abhängig. Die [begrenzte Strategieprüfung](research/near-instant-radar.md) bewertet kleine Cache-/Requestoptionen; kein neuer Cache oder Endpunktwechsel ohne konkreten nachgewiesenen Vorteil. Die laufende P0-Korrektur und Bedienbarkeitsvalidierung haben Vorrang.

## Build 5 nach P0-Schlussreview

Die kritische Build-4-Nutzerrückmeldung bleibt maßgeblich. Die begrenzten Daten-/Map-/Refreshkorrekturen und kompakte Timeline sind nach gezielten Nachweisen und frischem Schlussreview für eine interne Build-5-Testversion freigegeben, ohne offene P1/P2 im geprüften Fixdiff. Identität bleibt ShowerNow / `de.linolaske.showernow`, Team `J2DU2P47XW`, Version `0.1.0`, Build `5`. Kalte Ladezeit bleibt variabel; keine Instant- oder DWD-Verfügbarkeitsgarantie. Kein Diskcache, Prefetch oder KI-Ausbau in diesem Kandidaten. Archiv/Upload erst aus veröffentlichtem Quellencheckpoint; physischer Alltagstest erforderlich.


## Neuer Auftrag: ausgewählter Slot und abwechselnde Timeline-Nachbarn

Nutzerentscheidung vom 28. Oktober 2026 nach funktionierendem Geräteversuch: etwa 100 KB je Slot; jetzt bei dem ausgewählten Slot beginnen und unsichtbar abwechselnd nach links/rechts über die Zeitleiste vorladen, mit maximal 50 MB Cache. Diese Freigabe ersetzt die vorherigen Prefetch-Non-Goals für den neuen Kandidaten; die Build-5-Beschreibung bleibt historisch korrekt.

Umsetzungsumfang: harter RAM-Bildcache von **50.000.000 Byte validierter PNG-Nutzdaten**, kein Diskcache und kein blindes Auffüllen. Der Wert ist ein Bilddatenbudget, keine Obergrenze des gesamten App-Arbeitsspeichers. Reihenfolge: ausgewählter Index, Index − 1, Index + 1, Index − 2, Index + 2 usw.; am Rand nur vorhandene Nachbarn. Sichtbare Nachfrage zuerst vollständig bedienen, dann im Leerlauf schrittweise wärmen. Benutzeraktion hat Vorrang; alte Prefetchgenerationen bei Ort, Zoom oder Framewechsel abbrechen. Nur aktive App, Low-Data-/Low-Power-Schutz, deduplizierte Schlüssel und appseitiges Requestbudget mit gedrosseltem Startabstand sowie Fehlerpause. Ziel sind nach und nach alle geeigneten Slots, soweit Budget, Quelle und Nutzung dies erlauben; keine Garantie vollständiger Vorwärmung.

Kein zusätzliches periodisches Polling, kein Backend-/Rendererumbau, kein KI-Ausbau und keine neue Einstellungsseite. Referenzlauf-/Frame-/Tileidentität, tatsächliche historische Analysezeiten, 20-Minuten-Aktualitätsgrenze, negative Fehlerkeys pro Reloadrevision, begrenzte Dimensionretries und korrekter Vorgängerlauf-Fallback bleiben verbindlich. Abbrüche sind keine Quellfehler. Der Refreshring beschreibt nur sichtbaren Bedarf; echte Prefetch-Responsebytes müssen bei einem angezeigten Radar-Gesamtvolumen mitgezählt und dessen Umfang ehrlich bezeichnet werden. Ein kleiner Datentransfer allein belegt keine geringe Serverlast.

Build 6 bleibt Version `0.1.0` und unveränderte ShowerNow-Identität. Vor Veröffentlichung: deterministische Tests, gezielte Integration, frisches unabhängiges P0-/Fair-Use-Review und geprüfter Quellencheckpoint. Keine DWD-Livelastmatrix zur Demonstration. Interner Upload und öffentliche Quellenpushes sind autorisiert; Serverannahme und Installierbarkeit getrennt berichten. [Auftrags-/Quellenstand](timeline-prefetch.md).

Umgesetzte appseitige Schutzwerte für Build 6: eine Sekunde Leerlauf, eine spekulative Netzoperation, mindestens 500 ms Startabstand, höchstens 120 Vorladeversuche und eine Stopgrenze von 8.000.000 empfangenen Vorladebytes je festem 60-Sekunden-Fenster. Die einzelne bereits gestartete Antwort kann diese Transferstopgrenze überschreiten; der 50.000.000-Byte-RAM-Bildcache bleibt hart. Budget über Kontextwechsel erhalten, 120 Sekunden Pause bei Quellfehlern, keine Prefetchretries. Dies sind keine veröffentlichten DWD-Kontingente. Die Frischeprüfung betrifft den aktuellen Timeline-Quelllauf; historische Analyseframes dürfen ihre ältere tatsächliche Referenz behalten. Der begrenzte unabhängige Review ist ohne offene P1/P2 abgeschlossen; 16 neue Tests und die einmalige vollständige 57-Test-Logiksuite sind erfolgreich. Details, Testhostgrenze und Warmzeitgrenzen im [Integrationsnachweis](prefetch-integration.md).

Quellencheckpoint für diesen Umfang: `87915f8a6c8eda891cc094a46554cfe8200d908d`, auf `origin/main` veröffentlicht. Der getrennte Build-6-Release läuft aus genau diesem unveränderten Stand; Archiv-/IPA-Prüfung und das Ergebnis des einen autorisierten Uploads werden separat in [Signing](signing.md) und [Uploadnachweis](testflight-upload.md) belegt. Bisher kein belegtes Build-6-Uploadresultat oder Installierbarkeitsnachweis.

## Präzisierung der Netzpräferenz: WLAN und Mobilfunk

Neue verbindliche Nutzerantwort: „WLAN und Mobilfunk, aber nur solange Datensparmodus nicht aktiviert ist“. Für den endgültigen nächsten Beta-Stand sind normale WLAN- und Mobilfunknetze zum budgetierten Vorladen freigegeben; `isExpensive` allein sperrt nicht. `isConstrained`/Datensparmodus, Stromsparmodus und inaktive App bleiben Sperrgründe. Alle bestehenden Request-/Bytebudgets, Cachegrenzen, Nachfragepriorität und Quellenpausen bleiben bestehen.

Build 6 aus Quellencheckpoint `87915f8a6c8eda891cc094a46554cfe8200d908d` befindet sich bereits im einmaligen Upload und bleibt als konservativer Zwischenstand unverändert. Der gezielte Policyfix erhält Buildnummer 7; Prüfungen, veröffentlichter Quellencheckpoint und tatsächliches Releaseergebnis sind separat nachzuweisen. Kein Abbruch oder Wiederholungsupload von Build 6 und keine vorweggenommene Build-7-Erfolgsmeldung.

Build 6 wurde um 20:01:53 Uhr MEZ von Apple angenommen (`PROCESSING`); die eng begrenzte Netzpolicykorrektur verwendet deshalb Buildnummer 7. Installierbarkeit von Build 6 ist dadurch nicht belegt.

## Zeit-Slider (29. Oktober 2026, Nutzeranforderung)

Die Slider-Bewegung muss immer erkennbar sein, auch wenn der Radarslot nicht geladen ist oder das Laden fehlgeschlagen ist. Thumb und Zeitangabe folgen dem Finger netzunabhängig (`scrubIndex`). Eine ehrliche Statuspille nennt den Zustand des angezeigten Slots („lädt“ / „nicht geladen“); ein altes Bild gilt nie als Stand des gewählten Slots. Leichte Auswahl-Haptik pro Slotwechsel. Keine Änderung an Prefetch, Budgets oder Backend. Umsetzung für Build 7 (`TimelineSlot`, `TimelineSlotTests`).

## Build 8: vollständiges Timeline-Vorladen (30. Oktober 2026)

Nutzerfeedback zu Build 7: Die Zeitleiste wird nicht komplett vorgeladen. Entscheidung: Koordinaten des sichtbaren Ausschnitts gelten für alle Timeline-Slots; drei parallele Prefetch-Requests, 250 ms Abstand, 240 Requests je 60-s-Fenster (Bytestopp unverändert 8.000.000), Quellfehlerstopp nach drei aufeinanderfolgenden Fehlern. **Ersetzt** die Build-6/7-Vorsichtswerte (eine Netzoperation, 500 ms, 120 Requests je Fenster, Stopp bei erstem Fehler). Unverändert: 50-MB-RAM-Cap, kein Diskcache, Datensparmodus/Low Power/inaktive App sperren, Abbruch bei Ort-/Zoom-/Framewechsel, 120-s-Pause je Referenzlauf. Begründung und Rechnung in [timeline-prefetch.md](timeline-prefetch.md). Version `0.1.0`, Build `8`.

## Radar-Cache-Backend (Nutzerentscheidungen vom 30. Oktober 2026)

Messungen und Empfehlung: [research/backend-radar-cache.md](research/backend-radar-cache.md). Umsetzung und Details im [Backend-Repo](https://github.com/MagicalWig34653/weather-backend/blob/main/docs/decisions.md).

- Ein Radar-Cache-Backend wird gebaut. Die App behält den DWD-Direktweg als Fallback (bei Fehler, Timeout oder Datenalter über 20 Minuten); der Cache ersetzt "Karte unabhängig vom Backend" als Standardroute. Er ist zugleich die Ingest-Basis für spätere Benachrichtigungen.
- Betrieb auf dem vorhandenen Docker Swarm des Nutzers mit MariaDB 12.3; Reverse Proxy (Zoraxy) reicht nur durch und cached nicht, deshalb liegt der Cache im Stack (LRU je Replikat, ETag/304, `immutable`). Stateless Replikate, keine Cookies/Sticky Sessions. Ein Redis ist nicht vorgesehen.
- Format: ein Ganzbild je Slot (1024 x 1311 px, EPSG:3857, DWD-Palette), verlustfreies WebP; Vertrag `GET /v1/radar/latest.json` und `GET /v1/radar/<run>/<slot>.webp` (siehe Backend-README). Client-Anbindung folgt als Build 9 (separater Auftrag), nicht Teil dieser Entscheidung.
- Annahme: CC BY 4.0 und GeoNutzV genügen für Zwischenspeichern und Weitergabe, mit Quellenvermerk "Quelle: Deutscher Wetterdienst" und Veränderungshinweis; die App muss beides an der Karte sichtbar halten. Eine schriftliche DWD-Bestätigung zu Spiegelung und Takt bleibt optional und offen.
- Neue Messung (30. Oktober 2026, Backend-Arbeit): Etwa jede dritte WMS-GetMap-Antwort des DWD ist ein HTTP-200 mit XML-Fehler `InvalidDimensionValue`, auch für veröffentlichte Läufe, und wechselt bei Wiederholung zufällig. Auch der App-Direktweg sollte Wiederholungen bei XML-Antworten vorsehen (zu prüfen in Build 9).
- Backend-Sprache (Nutzerentscheidung 30. Oktober 2026): Der Radar-Cache ist Swift/Vapor/MariaDB (wie ursprünglich geplant); die Python-Stufe 1 ist ersetzt. HTTP-Vertrag und Verhalten sind unverändert, die App ist nicht betroffen. Details im Backend-Repo, docs/decisions.md.

## Build 9: Backend zuerst, DWD als Fallback (30. Oktober 2026)

Auftrag des Nutzers: Die App lädt Radarbilder vom produktiven Radar-Cache (`https://showernow.linolaske.de`, zentrale Konstante `RadarBackendConfig`) und fällt nur bei Fehler oder veralteten Daten auf den DWD-Direktweg zurück. Gründe und Messung: [research/backend-radar-cache.md](research/backend-radar-cache.md).

- Frischegrenze 20 Minuten (Alter von `reference_time`, wie `RainForecast.maximumAge`); `latest.json` wird beim Start/Aktivwerden und danach bei sichtbarer App geprüft (ETag, 304; ab Build-12-Kandidat adaptiver Takt statt starr 60 s, siehe Abschnitt „Adaptiver Poll-Takt“), nicht im Hintergrund.
- Fehler, 404, Timeout, ungültiges oder unbekanntes Schema, veraltete Daten: Fallback ohne Nutzeraktion. Liefert der Cache gar keine Bilder, bleibt die App 5 Minuten beim DWD-Weg. Quelle wird ehrlich angezeigt („ShowerNow-Cache“ bzw. „direkt vom DWD“), dazu Quellenvermerk und Veränderungshinweis aus dem Manifest.
- Der DWD-Tile-Prefetch (3 Worker, 240/min) läuft nur auf dem Fallbackweg; Backend-Prefetch: 4 parallele Requests, abwechselnd links/rechts, gleicher 50-MB-RAM-Cache, gesperrt bei Datensparmodus, Low Power, inaktiver App (Nachfrage für den sichtbaren Slot bleibt erlaubt).
- DWD-Direktweg: bis zu 3 Versuche (Backoff 0,3/0,6 s mit ±25 % Jitter) nur bei HTTP-200-`InvalidDimensionValue`; Retrybudget der sichtbaren Nachfrage je (Referenzzeit, Reload-Revision) von 4 über 48 (erster Build-9-Stand, ersetzt) auf 160 angehoben: Bei etwa einem Drittel `InvalidDimensionValue` und 32 sichtbaren Kacheln fallen rund 14 Retries je neu angezeigtem Frame an, 48 reichten nur für etwa 3 Frames. Jede Kachel behält höchstens 2 Retries (3 Versuche). Die 240 Requests/min gelten nur für den Prefetch; Nachfrage-Retries haben diesen eigenen Deckel. Der Prefetch-Worker prüft nach dem Backoff Cache, Fehlerstand und Abbruch erneut und stellt dann keinen weiteren Request. Punktprognose bleibt direkt beim DWD.
- Datenschutz: Die App kontaktiert nun den ShowerNow-Radar-Server (kein Ort, keine Cookies, kein identifizierender Header). Die Datenschutztexte der App sind angepasst.
- Datenschutzformulierung präzisiert (30./31. Oktober 2026): Belegt ist nur, dass der Radar-Dienst selbst keine Zugriffsprotokolle führt (Backend-Repo `Sources/radar/main.swift:68` „No access logs (no IPs, no paths)“, `Api.swift:54`). Der vorgeschaltete Reverse Proxy (Zoraxy, außerhalb des Repos) sieht technisch die IP-Adresse jedes Abrufs; ob er protokolliert, ist offen und liegt beim Betreiber. Texte sagen daher nur Belegtes. „Kein Ort“ gilt für Radar-Ganzbilder (feste Pfade je Lauf/Slot); die Punktprognose bleibt direkt beim DWD (unverändert).
- Buildnummer 9.

## Einstellung „Maximale Vergangenheit“ und Datenschutz-Link (Build-11-Kandidat, 30. Oktober 2026)

- Nutzerwunsch: bis zu 48 Stunden Vergangenheit. Der Nutzer wählt im Info-Sheet („Über ShowerNow“, Abschnitt „Maximale Vergangenheit“) 1, 2, 6, 12, 24 oder 48 Stunden; Standard 2 Stunden; lokal in UserDefaults (`radarPastHours`), kein Netz, keine Übertragung. Hinweis in der App: „Mehr Vergangenheit lädt mehr Bilder (Datenvolumen)“.
- Backend-Vertrag (additiv, siehe `data-contract.md`): `latest.json` unverändert; neu `history.json` (nur Analyse-Slots, `path` opak). Die App lädt `history.json` nur, wenn die Auswahl mehr Vergangenheit verlangt, als `latest.json` abdeckt (Toleranz ein Schritt), mit ETag, und nur bei neuem Lauf (oder bei Auswahländerung/manueller Aktualisierung, falls bisher keine Historie vorliegt). Timeline = Historien-Slots (ab Referenzzeit minus Auswahl) + `latest.json`, nach Zeit dedupliziert (latest gewinnt), aufsteigend. Gewählter Zeitpunkt bleibt über `RadarTimelineSelection` erhalten.
- Fehler/404/ungültig/andere Bildgeometrie: bisherige Vergangenheit aus `latest.json` (ca. 1 h), dezenter Hinweis „Historie nicht verfügbar“ (Quellenzeile, Info-Sheet). Kurzer Netzfehler behält die zuletzt gültige Historie. Liefert der Server weniger (`history_hours` < Auswahl), sind größere Stufen deaktiviert und der Server-Wert wird genannt; die gespeicherte Auswahl bleibt.
- DWD-Direktweg bleibt bei ca. 1 Stunde (12 Analysen), unabhängig von der Einstellung; Info-Sheet sagt das ehrlich, Stufen über 1 h sind dort deaktiviert. Keine zusätzlichen Kachel-Requests.
- Zeitleiste: bei Zeitpunkten an anderem Kalendertag zeigt die Zeitanzeige zusätzlich Tag/Datum (Mehrdeutigkeit bei 48 h).
- Datenschutz-Link: `RadarBackendConfig.privacyPolicyURL` (`https://showernow.linolaske.de/datenschutz`) als antippbarer Link „Datenschutzerklärung“ im Datenschutz-Abschnitt des Info-Sheets (Guideline 5.1.1(i)); öffnet im Browser, kein Netzwerkvorlauf. Bewusst KEIN Support-/Marketing-Link in der App: die Seiten sind noch nicht als live belegt; Nachrüsten, sobald erreichbar.
- Projekt: `project.yml` setzt `TARGETED_DEVICE_FAMILY` jetzt `'1,2'` (bisher `'1'` auf Projektebene; die Targets erbten ohnehin xcodegens iOS-Standard `1,2`, daher unverändertes Verhalten). Orientierungen stehen in `Configuration/Info.plist`.

## Feines Scrubben und Animationsfenster (Build-11-Kandidat, 30. Oktober 2026)

- Nutzerwunsch: Zeitleiste beim Ziehen feiner steuern, wenn man den Finger nach oben zieht (wie Apples Video-/Musik-Zeitleisten). Der SwiftUI-`Slider` erlaubt das nicht; ersetzt durch `TimelineScrubSlider` (Drag-Geste, Kapsel-Spur, Glas-Thumb, Zonenstreifen unverändert). VoiceOver/XCUI sehen weiter einen nativen Slider über `accessibilityRepresentation` (adjustable, Hinweis nennt die Geste).
- Stufen nach vertikalem Abstand des Fingers vom Sliderband (Punkte jenseits der 44-pt-Höhe): normal 1:1 (unter 40), halbe Geschwindigkeit ab 40, Viertel ab 90, Feinsteuerung (Faktor 0,1) ab 150. Schwellen wachsen mit Dynamic Type (`ScaledMetric`); Rückweg mit 10 pt Hysterese. Berechnung relativ: nur die Fingerbewegung seit dem letzten Ereignis wird mit dem aktuellen Faktor verrechnet, daher springt der Thumb bei Stufenwechsel nicht. Berührung nahe dem Thumb (22 pt) behält den Slot, sonst springt er zur Berührungsstelle wie beim Systemslider. Anzeige: kleine Pille mit „Halbe Geschwindigkeit“ / „Viertel-Geschwindigkeit“ / „Feinsteuerung“ über der Zeitleiste, leichte Impact-Haptik bei Stufenwechsel. Werte sind Startwerte; Feintuning am Gerät offen.
- Animationsfenster: Wiedergabe läuft von (Referenzzeit minus min(gewählte Vergangenheit, 3 h)) bis zum Vorhersageende (`PlaybackWindow.maximumPast`), danach Schleife an den Fensteranfang. Grund: Bei bis zu 48 h (ca. 600 Slots) wäre eine Schleife bei 2 s je Bild über 20 Minuten lang und würde Kacheln für Zeiten laden, die kaum jemand abspielt; 3 h zeigen den Regenzug sinnvoll. Der Slider bleibt über die gesamte gewählte Vergangenheit bedienbar; Start der Wiedergabe vor dem Fenster springt zum Fensteranfang.

## Robuste Ortsprognose und Ortssuche-Datenschutz (Build-11-Kandidat, 31. Oktober 2026)

Anlass: Nebenbefund „Ortsprognose: Die Wetterdaten konnten nicht gelesen werden“; Diagnose in [research/diagnose-ortsprognose-ortssuche.md](research/diagnose-ortsprognose-ortssuche.md) (Messung: gehäuft HTTP 502/503, Verbindungsfehler und XML-`InvalidDimensionValue` beim Punktabruf). Entscheidungen des ausführenden Agents (Nutzer nachts nicht erreichbar, bitte bei Gelegenheit bestätigen):

- Wiederholung: `DWDClient.fetch` (Laufindex und Punktabruf) macht höchstens 3 Requests je Aufruf (Backoff 0,3/0,6 s, je ±25 % Jitter, `RadarRetryPolicy`) bei XML `InvalidDimensionValue`, HTTP 502/503/504 und transienten `URLError` (`timedOut`, `networkConnectionLost`, `cannotConnectToHost`, `dnsLookupFailed`). Keine Wiederholung bei 4xx, `cancelled` (bleibt `CancellationError`), `notConnectedToInternet`, `dataNotAllowed` (Datensparmodus) oder fehlerhaftem Inhalt (leer, kein JSON, anderer Servicefehler): ein Wiederholen ändert dort vermutlich nichts, und die Last bleibt begrenzt.
- Fehlerarten: `invalidResponse` bleibt nur für nicht validierbare Bilder/Nicht-HTTP. Neu: `emptyBody`, `oversizedBody` (über 2 MB), `malformedPayload` (kein gültiges JSON/Pflichtfelder fehlen, auch HTML vom Gateway), `unexpectedPayload` (falscher Typ/Anzahl), `invalidTimeFormat`, `serviceFailure` (anderer ServiceException-Code). Jede Meldung beginnt mit „Die Wetterdaten konnten nicht gelesen werden“ plus kurzer Klammer; Rohdaten werden weder geloggt noch angezeigt.
- Letzte gültige Prognose: je Ort im Speicher (`WeatherStore`, höchstens 10 Orte, zuletzt genutzte bleiben; kein Diskcache, kein Verlauf). Bei Aktualisierungsfehler bleibt die Prognose des gewählten Orts stehen, Ortswechsel zeigt den passenden Eintrag oder keine Prognose, nie die eines anderen Orts. Anzeige: Kopfzeile „Ältere Prognose (Stand vor X Min.) · bitte aktualisieren“, im Detailblatt orangefarbener Hinweis „Aktualisierung fehlgeschlagen. Letzte gültige Prognose, Stand vor X Min.“ plus unveränderter Fehlertext in der Statusmeldung. Das Alter ist das des DWD-Laufs (`referenceTime`).
- Frischegrenze unverändert 20 Minuten (`RainForecast.maximumAge`): Danach liefert `summary` nur „Prognosedaten sind veraltet“, nie eine Trocken-Zusage; mit Fehler zeigt die Kopfzeile nie die Regen-/Trockenaussage.
- Datenschutz: `docs-site/content/datenschutz.md` erhält den Abschnitt „Kartenansicht und Ortssuche (Apple)“ im Wortlaut der Backend-Seite; der In-App-Satz (`InformationSheet.swift`) nennt jetzt, dass Suchtext und fester Suchbereich (Deutschland, nicht der Standort) an Apple gehen, nie an Radar-Dienst oder DWD, und Apples Datenschutzbestimmungen gelten. Die Backend-Seite `/datenschutz` liegt im Schwesterrepo und ist dort anzugleichen (nicht Teil dieses Auftrags). Die App-Privacy-Empfehlung (Variante A) bleibt unverändert; die Begründung in [apple-externe-tests.md](apple-externe-tests.md) nennt MapKit jetzt ausdrücklich.

## Adaptiver Poll-Takt für `latest.json` (Build-12-Kandidat, 31. Oktober 2026)

Anlass: Messung des Backend-Teams: Raster 5 min (UTC, Vielfache von 300 s ab Unix-Epoche), neuer Lauf erscheint etwa 3 bis 3,5 min nach der Nominalzeit N. Starr 60 s zeigt den Lauf im Mittel 30 s zu spät. Umsetzung: `RadarPollSchedule` (`Weather/Data/RadarPollSchedule.swift`, rein, injizierbare Zufallsquelle, Uhr als Argument), Schleife `WeatherStore.runRadarPolling` (aufgerufen aus `WeatherApp`, nur bei `scenePhase == .active`, Abbruch beim Verlassen).

Regeln (Fenster für N = [N + 165 s, N + 300 s], also erwartet N + 180 s, minus 15 s, plus 120 s):
- Fenster und `latest.referenceTime < N`: Abstand 10 s ± 2 s Jitter (gleichverteilt, damit Clients nicht synchron anfragen). Höchstens 14 Fensterrequests je 5 min.
- Lauf für N da (`referenceTime >= N`): Ruhetakt 60 s ± 2 s, der Schlaf wird aber auf den Beginn des nächsten Fensters gekürzt (mindestens 1 s).
- Fenster vorbei ohne neuen Lauf: Backoff 20 s, 30 s, danach 60 s (jeweils ± 2 s), ebenfalls bis zum nächsten Fenster gekürzt; Zähler startet je Fenster neu.
- Low Power Mode oder Low Data Mode/kein Netz (`RadarPathGate`): nur Ruhetakt 60 s, kein 10-s-Fenster.
- Fehler (`.fallback` aus `latest()`: Timeout, 5xx, ungültig, 404, veraltet): zusätzlich mindestens 20 s, 30 s, dann 60 s je aufeinanderfolgendem Fehler, auch im Fenster; Erfolg setzt zurück. Keine Schleife ohne Wartezeit.
- Alle Requests mit ETag/`If-None-Match` (304 billig), keine Hintergrundabfragen (bestehende Regel), Historie-Prüfung weiter nur bei neuem Lauf, Fallback/20-Minuten-Frischegrenze/Zeitpunkt-Erhalt unverändert (nur `pollRadar` liefert zusätzlich ein Ergebnis).

Last je aktivem Client (Simulation in `RadarPollScheduleTests.testExpectedLoadPerActiveClient`, 2 h, ohne Jitter): Lauf erscheint N + 180 s: 1,4 Requests/min; N + 195 s: 1,6/min; N + 210 s: 2,0/min; Lauf erscheint nie (Backend steht): 3,6/min; eingeschränkt (Low Power/Data): 1,0/min. Heute 1,0/min. Erwartung im Betrieb also etwa 1,4 bis 2,0/min (Faktor 1,4 bis 2), überwiegend 304 (wenige hundert Byte); Mehrlast steckt im 15-s-Vorlauf und den Fensterpolls bis zur Ankunft. Nutzen: neuer Lauf erscheint typisch binnen ca. 5 s nach Veröffentlichung statt im Mittel nach 30 s. Begründung gegen kürzere Abstände: 14 Requests je Fenster sind die Obergrenze, die der Auftrag vorgab; Websocket/SSE bewusst nicht (Akku, Hintergrund, Zustand).

Offen: am Gerät nicht erprobt; Fenster-Lage (+180 s, −15 s/+120 s) beruht auf der Messung des Backend-Teams und sollte nach einigen Tagen gegen echte `generated_at`-Werte geprüft werden; bei höherer Aktivenzahl Serverlast beobachten.

**Support- und Über-Links im Info-Sheet (31. Oktober 2026, Kandidat Build 12):** Neben „Datenschutzerklärung“ zwei weitere `Link`-Zeilen „Support“ (`https://showernow.linolaske.de/support`) und „Über ShowerNow“ (`https://showernow.linolaske.de/marketing`), zentral als `RadarBackendConfig.supportURL`/`marketingURL`. Begründung: App-Store-Connect-Testinformationen und Pages verweisen auf diese Seiten; die Links öffnen nur den Browser, die App ist nicht vom Netz oder von der Seitenverfügbarkeit abhängig. Gleiche Gestaltung und Accessibility-Hinweise wie der Datenschutz-Link; Test `SiteLinkTests` sichert https und Radar-Host.

## Nutzerentscheidungen und offene Punkte (31. Oktober 2026)

Entschieden:
- Team-ID `J2DU2P47XW` und Bundle-ID `de.linolaske.showernow` sind endgültig (E9; die frühere Vorläufigkeit entfällt).
- Push-Benachrichtigungen für Orte sind freigegeben (E1/E2): Opt-in je Ort per Server-Push (APNs); lokale Mitteilungen höchstens als Zusatz. Entwurf: [research/push-benachrichtigungen.md](research/push-benachrichtigungen.md).
- Regenradar-Legende (aufklappbare DWD-Farblegende in mm/h) ist umgesetzt (Commit `141d38b`); die Datenmengenanzeige oben rechts wurde entfernt.

Am 31. Oktober 2026 vom Nutzer gemäß Empfehlung des Entwurfs zugestimmt: E3 bis E6 und E8 (Details unten) sowie die Kartenreihenfolge Luftdruck, Blitze, Wolken. E7 (Rechtsgrundlage, Impressum, Zoraxy-Logging) klärt der Nutzer selbst und bleibt offen.

Noch NICHT entschieden bzw. offen (Empfehlung des Entwurfs in Klammern):
- E3 Serverraster: Pixelraster des Ingests, ~1 km, nicht feiner (Alternative 3x3 gröber).
- E4 Intensitätsquelle: Palettenfarben, HDF5 erst bei Bedarf.
- E5 Regel: nur „Regen beginnt in N Minuten“ (N = 10/20/30), Hysterese, Sperrzeit.
- E6 Aufbewahrung: 60 Tage Inaktivität, Löschung sofort bei 410 und per DELETE.
- E7 Rechtsgrundlage, Verantwortlicher/Impressum, Zoraxy-Logging (Einwilligung; Zoraxy ohne IP-Zugriffslog oder gekürzt; vor Livegang klären).
- E8 Missbrauchsschutz: Limit Subs je Install (10), Rate-Limit am Proxy, App Attest erst bei realem Missbrauch.
- Reihenfolge weiterer Karten: bestätigt (Luftdruck, Blitze, Wolken über EUMETSAT MTG geocolour). Alternativanbieter geprüft, keiner gleichwertig für Europa (wolkenradar-quellen.md, Abschnitt 7). EUMETSAT-Klärung: siehe Eintrag unten. Quellen: [research/weitere-radarkarten.md](research/weitere-radarkarten.md), [research/wolkenradar-quellen.md](research/wolkenradar-quellen.md).

## EUMETSAT-Klärung (31. Oktober 2026)

Nach EUMETSAT Data Policy (Jan. 2026, Art. 5.1, 6.1, 6.3, Annex II) sind die geplanten Wolkenlayer (`mtg_fd:rgb_geocolour`, `rgb_cloudtype`, `msg_fes:cth`, `clm`, `ir108`) Core (CC BY 4.0, „Free and Unrestricted“): Weiterverteilung abgeleiteter Bilder und Caching im Backend sind zulässig, für EUMETView-WMS ist keine Registrierung und keine Lizenzvereinbarung nötig. Pflicht: Attribution „Contains modified EUMETSAT Meteosat data 2026“ (Art. 6.3, Jahr anpassen) zusätzlich zur DWD-Quelle. Die Produktseiten-Lizenzfelder wurden nicht gelesen (nur Policy-Text); eine Rückfrage an EUMETSAT ist nicht erforderlich, nur optional zu Lastgrenzen. Details und Quellen: [research/wolkenradar-quellen.md](research/wolkenradar-quellen.md), Abschnitt 3.

## Sonnenradar (31. Oktober 2026)

Nutzerentscheidung: Start mit Weg A (Wolkenmaske plus Sonnenhöhe; Terminator/Nachtschattierung in der App gerechnet). Die Kurzfrist-Extrapolation („Sonne in 30 min“, als „Schätzung“ gekennzeichnet) ist ebenfalls gewünscht, kommt aber zuletzt, nach der Wolkenebene. Grundlage: [research/sonnenradar.md](research/sonnenradar.md). Baustein S1 (`Weather/Data/SolarPosition.swift`) ist umgesetzt, siehe [status.md](status.md).
