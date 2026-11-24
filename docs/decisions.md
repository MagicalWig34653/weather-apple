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
- Apple Team ID: `J2DU2P47XW`, durch bisheriges Signing bestätigt; Team-ID und Bundle-ID sind endgültig (31.10.2026).
- App-Name und Bundle-ID werden jetzt gemeinsam geändert; technische Module/Projektname Weather und Ordner weather bleiben zulässig. Abhängige IDs für Widgets, Watch, App Groups etc. erst bei Target-Einrichtung festlegen.
- Historisch (28.10.): Kandidat `0.1.0 (4)`; Build 3 ist intern nutzbar bestätigt. Aktueller Build: [status.md](status.md). Der Nutzer hat die Umstellung seines aktuellen App-Store-Connect-Eintrags auf die neue Bundle-ID bestätigt.
- AGPLv3 ist angestrebt. Lizenzentscheidung und mögliche Zusatzerlaubnisse für App-Store-Veröffentlichung sind offen. Es wird deshalb noch keine endgültige Lizenz behauptet.

## Quellenhierarchie

Aktuelle ausdrückliche Nutzerentscheidungen haben Vorrang. Dieses Dokument ergänzt und aktualisiert `concept-v2.md`, insbesondere hinsichtlich Plattformen und Reihenfolge. Das ursprüngliche Konzept bleibt als unveränderte Referenz erhalten.

## Verbindliche Arbeitsweise (Nutzerentscheidung vom 28. Oktober 2026)

Möglichst kostensparsam entwickeln. Agents sind Pflicht. Sessions müssen wegwerfbar sein und das Repo ist die Source of Truth; alle relevanten Ergebnisse und Entscheidungen sind immer im Repo zu dokumentieren. Der konkrete Prozess steht in `AGENTS.md`, der fortsetzbare Arbeitsstand in `docs/status.md`.

### Review-Korrekturen (Nutzerauftrag vom 17. November 2026)

Die extern bereitgestellten Apple-Review-Befunde 1–6 sind nach erneuter Codeprüfung zu beheben; 7–8 nur mit kleinem Fix. Je Befund zuerst den Regressionstest schreiben, dann den minimalen Fix, jeweils in einem eigenen deutschen Commit. Unzutreffende Befunde begründet verwerfen. Während dieses Auftrags keine Builds, Tests, Test-Discovery, Lints oder Netzaufrufe und keinen Push ausführen; die Prüfung übernimmt der Aufrufer. Das schließt die sonst vor Text-/Oberflächencommits verlangte L10n-Prüfung ein: ihre Nichtausführung ausdrücklich dokumentieren. Der Abschlussbericht `BERICHT-FIXES.md` nennt je Befund Status, Commit und exakten Testbefehl; swift-testing-Namen im App-Target bei `-only-testing` mit `()` angeben. Produktumfang und Veröffentlichungsfreigaben ändern sich dadurch nicht.

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

Nutzerzustimmung zu den Empfehlungen des Push-Entwurfs: E1/E2 (31.10.), E3 bis E6 und E8 (31.10.), Kartenreihenfolge Luftdruck, Blitze, Wolken (31.10.), Regionen Version 1 nur Umkreis (1.11.), Backend-Welle 2 (Ebenen `pressure_eu`, `cloudmask_vis`, `cloudmask_vis_eu`, eigene bbox je Ebene; 1.11.). **Offen beim Nutzer: E7** (Rechtsgrundlage, Verantwortlicher/Impressum, Zoraxy-Logging ohne bzw. mit gekürzter IP, vor Livegang) sowie die Druck-Farbfläche (siehe unten).

Inhalt der zugestimmten Punkte (Empfehlung des Entwurfs, jetzt gültig):
- E3 Serverraster: Pixelraster des Ingests, ~1 km, nicht feiner.
- E4 Intensitätsquelle: Palettenfarben, HDF5 erst bei Bedarf.
- E5 Regel: nur „Regen beginnt in N Minuten“ (N = 10/20/30), Hysterese, Sperrzeit.
- E6 Aufbewahrung: 60 Tage Inaktivität, Löschung sofort bei 410 und per DELETE.
- E8 Missbrauchsschutz: Limit Abos je Installation (10), Rate-Limit am Proxy, App Attest erst bei realem Missbrauch.
- Regionen Version 1: nur Umkreis (Mittelpunkt + Radius 5/10/25 km, Auslöseanteil 1/10/25 %, bis 3 Regionen im Limit von 10); Polygone/Bundesländer später. Entwurf: [research/push-regionen.md](research/push-regionen.md).
- Sonnenkarte Welle 2: weichere Darstellung aus `vis06`-Rotkanal und sin(Sonnenhöhe), nachts Rückfall auf `cloudmask` (EUMETView lieferte nachts ca. 22:30 bis 01:30 UTC keine Bilder); Europa-Overlays mit Bildausdehnung je Ebene aus dem Manifest. App-Umsetzung steht aus (siehe status.md).
- Offen, nicht entschieden: Luftdruck als Farbfläche (nur über GRIB-Rohdaten im Backend, Aufwand 3 bis 5 Tage, [research/druck-farboverlay.md](research/druck-farboverlay.md)); Live Activities später, Critical Alerts nicht beantragen (Empfehlung, [research/live-activities-und-kritische-mitteilungen.md](research/live-activities-und-kritische-mitteilungen.md)).
- Reihenfolge weiterer Karten: bestätigt (Luftdruck, Blitze, Wolken über EUMETSAT MTG geocolour). Alternativanbieter geprüft, keiner gleichwertig für Europa (wolkenradar-quellen.md, Abschnitt 7). EUMETSAT-Klärung: siehe Eintrag unten. Quellen: [research/weitere-radarkarten.md](research/weitere-radarkarten.md), [research/wolkenradar-quellen.md](research/wolkenradar-quellen.md).
- Ebenenwahl in der App (31.10.2026 umgesetzt, Arbeitsentscheidung): genau eine aktive Ebene, Standard Regenradar; Zusatzebenen nur über den Backend-Cache (`/v1/layers/<ebene>/`), kein WMS-Fallback; 404 = Ebene ausgegraut ohne Fehlerbanner. Frischegrenzen je Ebene (Blitze 30 min, Wolken 2 h, Luftdruck Lauf 18 h) sind Startwerte. Details: [status.md](status.md).

## EUMETSAT-Klärung (31. Oktober 2026)

Nach EUMETSAT Data Policy (Jan. 2026, Art. 5.1, 6.1, 6.3, Annex II) sind die geplanten Wolkenlayer (`mtg_fd:rgb_geocolour`, `rgb_cloudtype`, `msg_fes:cth`, `clm`, `ir108`) Core (CC BY 4.0, „Free and Unrestricted“): Weiterverteilung abgeleiteter Bilder und Caching im Backend sind zulässig, für EUMETView-WMS ist keine Registrierung und keine Lizenzvereinbarung nötig. Pflicht: Attribution „Contains modified EUMETSAT Meteosat data 2026“ (Art. 6.3, Jahr anpassen) zusätzlich zur DWD-Quelle. Die Produktseiten-Lizenzfelder wurden nicht gelesen (nur Policy-Text); eine Rückfrage an EUMETSAT ist nicht erforderlich, nur optional zu Lastgrenzen. Details und Quellen: [research/wolkenradar-quellen.md](research/wolkenradar-quellen.md), Abschnitt 3.

## Sonnenradar (31. Oktober 2026)

Nutzerentscheidung: Start mit Weg A (Wolkenmaske plus Sonnenhöhe; Terminator/Nachtschattierung in der App gerechnet). Die Kurzfrist-Extrapolation („Sonne in 30 min“, als „Schätzung“ gekennzeichnet) ist ebenfalls gewünscht, kommt aber zuletzt, nach der Wolkenebene. Grundlage: [research/sonnenradar.md](research/sonnenradar.md). Baustein S1 (`Weather/Data/SolarPosition.swift`) ist umgesetzt, siehe [status.md](status.md).

Umsetzung Ebene „Sonne“ (31.10.2026): `RadarLayer.cloudmask` ist jetzt wählbar und heißt in der App „Sonne“ (Pfad `/v1/layers/cloudmask/` unverändert). Die App erzeugt das Overlay aus Maske und Sonnenstand der Slotzeit (`Weather/Data/SunMask.swift`), keine Extrapolation. Klassenzuordnung der Maskenfarben und Messwerte: [research/sonnenradar.md](research/sonnenradar.md) Abschnitt 6; Mischpixel gelten als unbekannt; keine „heiter“-Stufe. Die Zeitzone der Ortszeile ist fest `Europe/Berlin` (Kartengebiet liegt komplett in MEZ/MESZ); ein Ort außerhalb bräuchte eine Zeitzonenquelle (nicht vorhanden, Annahme).

## Seiten als Bottom-Sheet (31. Oktober 2026)

Nutzerwunsch: Datenschutzerklärung, Support und „Über ShowerNow“ öffnen als von unten hochfahrende Seite statt in Safari. Umsetzung `Weather/Views/SitePageSheet.swift`: SwiftUI-Sheet mit Detents medium/large, Drag-Indikator, „Fertig“ und „Im Browser öffnen“. Wahl: ephemere `WKWebView` (`nonPersistent`-Datenspeicher: keine Cookies, nichts dauerhaft gespeichert; JavaScript aus; Navigation nur auf dem eigenen Host, andere Links gehen in den Browser; Nicht-2xx und Verbindungsfehler zeigen eine Fehlerseite mit „Erneut versuchen“ und „Im Browser öffnen“) statt `SFSafariViewController`, weil dessen Website-Daten-/Cookie-Verhalten nicht von der App kontrollierbar ist. Kein Hauptoberflächen-WebView, nur Info-Seiten. Dasselbe Sheet nutzen Info-Sheet (Mitteilungen, Datenschutz-Abschnitt) und Push-Bereich; die Bestätigung vor der Systemabfrage bietet „Datenschutzerklärung lesen“ (Alerts können keine Links enthalten). Sport statt nur Radfahren: Hinweise zu Fokus und Apple Watch nennen Sport allgemein; der Fokus wird neutral beschrieben („Fokus, den du dafür nutzt“), da der Fokus-Name nicht belegt wurde.

## Welle 2 in der Oberfläche (1. November 2026)

Nutzerentscheidungen zu den Architekturfragen: (1) **Sonne:** Zeitachse bleibt die der 15-min-`cloudmask`-Slots; je Slot wird der zeitlich nächste `cloudmask_vis`-Slot (höchstens 10 min Abstand, sonst nur die Maske) zusätzlich geladen; nachts/ohne vis die bisherige Maske. (2) **Ebenen:** neu `pressure_eu` und `cloudmask_vis` (nur als Hilfe für die Sonne); Europa ist ein eigener Eintrag im Ebenenmenü (kein Zoom-Automatismus) mit `manifest.bounds` je Ebene; Sonne und Luftdruck bleiben Deutschland-Standard, Luftdruck zusätzlich „Europa“; `cloudmask_vis_eu` wird nicht eingebunden. Speicherbudget 48 MB dekodiert. (3) **Zeitzone** außerhalb Deutschlands: Gerätezeitzone, kein Geocoding. Neue Ebenen werden nur angeboten, wenn das Backend sie meldet (Manifest `available`); 404 bleibt ohne Fehlerbanner. Umsetzung und Prüfstand: [status.md](status.md) Offener Punkt 1.

## Widgets, Watch, Live Activity: Nutzerentscheidungen (3. November 2026)

Plan: [research/widgets-watch-plan.md](research/widgets-watch-plan.md). Entscheidungen des Nutzers (per Auswahl):
- E1: alles in **einem** Build (Widgets, Watch, Live Activity); Entwicklungsreihenfolge Widgets, dann Watch, dann Live Activity.
- E2: Automatic Signing darf genau die App-IDs `de.linolaske.showernow.widgets`, `.watchkitapp`, `.watchkitapp.widgets` und die App Group `group.de.linolaske.showernow` anlegen (noch nicht geschehen).
- E3: Widget-Ortsauswahl nur gespeicherte Orte.
- E4: Live Activity nur mit Push-to-Start; lokaler Start nur Fallback.
- Später: App Attest jetzt einplanen (ersetzt "erst bei Missbrauch" aus E8); Luftdruck als Farbfläche im Backend umsetzen (ersetzt "offen" oben).

## App-Icon für Build 16 (3. November 2026)

- Nutzerentscheidung ("nimm erstmal d2"): Das App-Icon ab Build 16 ist `design/Icon/eigenentwurf-dark/d2.icon` (Eigenentwurf des Nutzers mit Dark-Variante "Nachtradar"; Dark-Werte Kern 1.00/0.36/0.12, gelbe Zone 0.66/0.48/0.16, Band 0.10/0.50/0.50, Front 0.07/0.30/0.37). Vorbehalt: "erstmal", spätere Änderung möglich.
- Übernommen nach `Weather/Resources/Icon/AppIcon.icon` (Ordnername unverändert, `supported-platforms` circles watchOS + squares shared wie zuvor). Vorheriges Icon (Build 15, Kartenmotiv) archiviert in `design/Icon/archiv/AppIcon-build15.icon`.
- Verworfen bzw. zurückgestellt: Dark-Alternativen d1, d3, d4; Entwürfe v3 und v5 (kein Entwurf erreichte das Niveau des Eigenentwurfs). Details: [icon-eigenentwurf.md](icon-eigenentwurf.md).

## Umbenennung zu "Showers" (3. November 2026)

- Nutzerentscheidung: Die App heißt ab Build 17 "Showers". Nutzerzitat: "Es reicht, wenn das Optische umbenannt wird. Das Backend kann meinetwegen noch über showernow.linolaske.de laufen. showers.linolaske.de ist aber auch schon aktiv und zeigt aufs selbe Backend." Den Connect-Eintrag (Name, Metadaten) ändert der Nutzer.
- Umfang Build 17: nur sichtbare Namen und Texte, Home-Screen-Name "Showers". Keine Domain-Umstellung (URL-Konstanten in `RadarBackend.swift` bleiben auf `showernow.linolaske.de`), kein Redirect.
- Unverändert: Bundle-ID `de.linolaske.showernow` samt `.widgets`/`.watchkitapp`, Team-ID, App-Group, Keychain-Service, URL-Schema `showernow://`, Widget-Kinds, DWD-User-Agent, Modul/Ordner `Weather`, Repo- und Image-Namen.
- Inventar und Nutzerschritte: [rename-showers-plan.md](rename-showers-plan.md). Offen: Verfügbarkeit des Namens in Connect (Ausweichen z. B. "Showers – Regenradar").

## App-Symbol-Auswahl (4. November 2026)

- Nutzerauftrag: "Mach mal in Build 17 eine Option, dass man selber das Icon wählen kann, also zwischen allen Vorschlägen, die bis jetzt waren, inkl. des alten." Build 17 war bereits hochgeladen, daher Umsetzung in Build 18.
- Umfang: Standard bleibt d2 (Nachtradar, `AppIcon`); 16 Alternativen (Build-15-Icon "Karte", Eigenentwurf final, v2a-c, v3a-d, v4a-d, v5a-c). d1, d3, d4 sind bewusst nicht enthalten. Einstieg: Info-Sheet, Abschnitt "App-Symbol". Die Apple Watch behält das Standard-Symbol (watchOS kennt keine alternativen App-Symbole); das System zeigt bei jedem Wechsel einen Hinweis, der sich nicht unterdrücken lässt. Details, Quellen, Prüfungen: [icon-auswahl.md](icon-auswahl.md).

## Ort im Regen-Push-Text (Vorschlag, 7. November 2026, offen, nichts umgesetzt)

Nutzerwunsch: "Regen beginnt in 3 Minuten · Holzschlag". Befund: Text entsteht auf dem Gerät aus `RAIN_STARTS_IN` / `RAIN_REGION_STARTS_IN` (`Weather/Resources/*.lproj/Localizable.strings`); das Backend (`PushEvaluator.payload`, `Sources/RadarCore/PushIntensity.swift`) sendet nur `loc-key`, `loc-args` (Minuten) und `thread-id` (Abo-ID). Weder App noch Server kennen ein Label im Abo; Orte werden nur als Koordinatenraster-Zelle, Gebiete als Geometrie gespeichert. Der Name kann daher nicht ohne neue Komponente in den Text.
- Variante A (empfohlen, keine Datenschutzänderung): Notification Service Extension (`mutable-content: 1` im Payload, Server-Änderung minimal). Die Extension liest `thread-id` -> Name aus einer App-Group-Tabelle (`group.de.linolaske.showernow`, schreibt die App beim Anlegen/Umbenennen) und hängt " · Name" an. Ohne Eintrag bleibt der Text unverändert. Name verlässt das Gerät nie. Erfordert neues Target, eigene App-ID und Provisioning-Profil (Signing-Ressource, braucht ausdrücklichen Auftrag) und Budget von 30 s/24 MB der Extension.
- Variante B (Datenschutzänderung, nicht live ohne Nutzerentscheidung): optionales Label im Abo auf dem Server speichern und als zusätzliches `loc-arg` senden. Betrifft Migration, API-Vertrag, Datenschutztexte und App Privacy (Ortsname plus Abo-ID erhöht Identifizierbarkeit).
- Offen: Nutzerentscheidung A oder B; Deploy erst nach Umsetzung. Todolino-Aufgabe `BCC685B3-32EE-4D29-A3BA-081E15ADE982`.

## 7.11.2026: Ort im Regen-Push per Notification Service Extension (Variante A, umgesetzt)

Nutzerentscheidung "A, Signing freigegeben". Target `WeatherNotificationService` (Build 32); Name wird lokal im App-Group-Speicher pro Abo-ID gehalten und als " · Name" an den Push-Text gehängt. Server kennt den Namen nie; Backend setzt nur `mutable-content: 1` für Orts- und Gebiets-Alerts. Keine Datenschutzänderung.

## 7.11.2026: Warnungen (Unwetter, Frost, Glatteis), Entscheidungen

Nutzer hat die Spezifikation `docs/superpowers/specs/2026-11-07-warnungen-design.md` freigegeben und alle Empfehlungen aus §9 bestätigt:
- Unwetter allgemein = Gewitter, Sturm, Stark-/Dauerregen, Schnee, Tauwetter. Hitze, UV, Nebel nicht in v1.
- Standardstufen Push: Unwetter ab 3, Frost ab 1, Glätte ab 2 (je Typ einstellbar).
- Entwarnung nie als Push, nur in der App.
- Update-Pushes nur bei Verschärfung (höhere Stufe, anderer Typ) oder deutlich früherem Beginn (> 1 h).
- Zeitkritisch nur bei Stufe 4 plus Nutzerschalter.
- Rückfrage an `CAP@dwd.de` (Weitergabe als Push mit Quellenangabe) ist eine **Nutzeraufgabe**. Push (`warnings_push`, `WARN_PUSH_ENABLED`) bleibt aus, bis der DWD geantwortet hat **und** der Datenschutztext freigegeben ist. Anzeige in der App (`warnings`) hängt davon nicht ab.
- Vertrag (W0) liegt im Backend: `docs-site/content/api.md` "Amtliche Warnungen" mit Fixtures `docs/fixtures/warnings/`. Warn-Abos verwenden die Pfade `/v1/push/installations/<uuid>/warn-subscriptions` (Spec 3.5 angepasst). Plan: `docs/superpowers/plans/2026-11-07-warnungen-plan.md`.

## 7.11.2026: Warngebiete auf Kreisebene (Lizenz)

Nutzerentscheidung: Warnzellen-Geometrie und Zuordnung auf Kreisebene (DWD-Layer `Warngebiete_Kreise`, einheitlich © GeoBasis-DE / BKG) statt Gemeinde, um die gemischten Rechte der Typ-7-Zellen zu vermeiden. Server/Feed: `DISTRICT_*`. Quellenvermerk im Info-Sheet. Genauigkeit gröber (ganzer Kreis); Gemeindeebene nur nach DWD-Klärung oder eigenem Aufbau aus VG250. Details `research/warnzellen-geometrie.md`.

## 7.11.2026: Warn-Push-Text (W6), konservative Variante

Konflikt: Spec (NSE ergänzt „Quelle: DWD, ausgegeben HH:MM“, DWD-Text unverändert) gegen Rechtsrecherche (`research/dwd-warnungen-weitergabe.md`: bis zur Klärung eigene Kurzmeldung ohne DWD-Vermerk, nicht als „amtliche Warnung“ betiteln). Entscheidung: Rechtsrecherche gilt. Die NSE ersetzt bei `type=warning` Titel und Body durch eine eigene Kurzmeldung (Typ, Stufe, „Tippen für Details.“), Ortsname im `subtitle`; Frost und Glätte erscheinen als „Hinweis“. Die volle, unveränderte DWD-Warnung mit Vermerk steht in der Warnansicht (W5). Das Backend sendet DWD-Headline und gekürzten Text mit „Quelle: DWD“ im Alert; das bleibt unverändert und gilt nur als Fallback, wenn die NSE nicht läuft (Fehler, Timeout, Strings fehlen). Empfohlene Backend-Änderung vor `WARN_PUSH_ENABLED`: Alert als `loc-key` mit Typ/Stufe senden oder die DWD-Headline nicht als Titel setzen, sonst sieht der Nutzer bei NSE-Ausfall gekürzten DWD-Text. Die Planvorgabe `WarningNotificationText.body(original:sentISO:…)` entfällt. Offene Rückfrage an den DWD (E-Mail-Entwurf) bleibt.

## 8.11.2026: Temperatur-/Feuchtekarte, App-Umsetzung P2

Nutzerentscheidungen (verbindlich): Taupunkt zuerst, relative Feuchte per Server-Flag zuschaltbar (App zeigt nur Ebenen, deren Manifest der Server liefert); Quelle im Betrieb zuerst WMS (nur Temperatur), ICON-D2 später; Wald nur bei Temperatur und Feuchte (P5); Feuchte-Wörter erst nach belegten Schwellen, bis dahin nur Zahlen; Anzeige durchgehend als Modellwert gekennzeichnet; Barrierefreiheit nicht nur über Farbe. Umgesetzt in P2: Ebenen `temperature`, `dewpoint`, `humidity` (`isOfferedWhenUnavailable == false`, wie `pressureEU`), optionale Manifestfelder `source`/`scale`, Hinweistexte (de/en), Legendenbild nur bei `source == wms`; unbekannte oder noch nicht hinterlegte Skala: nur Hinweistext, kein erratenes Raster. Beschriftung "Modell"/"Modellvorhersage", keine Feuchte-Wörter, kein "gefühlt".

## 8.11.2026: Temperatur-/Feuchtekarte, App-Umsetzung P5

Native Legende aus der gebündelten Skalentabelle `Weather/Resources/scales-v1.json` (Kopie aus dem Backend-Vertrag, Test vergleicht mit der Fixture): Schema 1, lückenlose Bänder, gültige Hex-Farben, Skala muss zur Ebene passen (`t2m`→Temperatur, `td`→Taupunkt, `rh`→relative Feuchte) und `source == icon_d2`; sonst Hinweistext (fail-closed). Wertabfrage lokal aus dem angezeigten Bild (Antippen oder Knopf/VoiceOver-Aktion "Wert in Kartenmitte vorlesen"), Ausgabe "Etwa 7 bis 8 °C (Modell)", kein Netz, kein Standort. Wald: Bundle-Bild, Schalter nur bei Temperatur/Feuchte, Standard aus, gemerkt in UserDefaults; Quellzeile nennt "© ESA WorldCover project 2021 / Contains modified Copernicus Sentinel data (2021) …" samt Veränderungshinweis nur bei eingeblendetem Wald. Umschalter Taupunkt/relative Feuchte im Legendenpanel nur, wenn der Server beide Ebenen liefert. Spec-Quellzeile bleibt im Dokument "(2020/2021)"; verbindlich ist der Wortlaut aus `docs/research/wald-ebene.md` ("(2021)"). Datenschutztexte unverändert.

- 8.11.2026 Warnungen-Seite: Nutzerentscheidung gruppiert nach Ort mit Karten in Stufenfarbe; nur ein sichtbarer Filter (Meine Orte | Alle), Liste/Karte als Symbol in der Navigationsleiste; Datenstand und Haftungshinweis als Fussnoten statt Karten. Auflagen (DWD-Text unveraendert, Quellzeile je Warnung, ehrliche Zustaende) bleiben.

## 8.11.2026: Temperatur-/Feuchtekarte P6 (Quellenseite, Datenschutz)

Das Info-Sheet nennt DWD ICON-D2/ICON-EU und, bei vorhandener Waldebene, ESA WorldCover. **Datenschutztexte bleiben unveraendert:** keine neuen Datenfluesse (Bilder nur vom Showers-Server ohne Ortsbezug, Wertabfrage lokal, Wald-Schalter nur auf dem Geraet, Waldbild gebuendelt).

- 8.11.2026: Beruehrbare Hauptansicht-Elemente nutzen `glassControl` (Liquid Glass interactive); Sheets oeffnen per Zoom aus dem Knopf; Zeitleisten-Daumen ist eine Glas-Pille. Keine Material-Hintergruende mehr fuer schwebende Pillen.

- 8.11.2026: Nutzerfeedback zu Build 38 (Menues erscheinen "aus dem Nichts"): Zoom-Uebergang bleibt fuer **Warnungen und Meine Orte** (Nutzer: funktioniert sehr gut, unveraendert). **Info und Prognosedetails** oeffnen wieder als normales Sheet von unten (Option b): Ursache des fehlenden Zoom-Ursprungs nicht belegbar (gleiches Muster wie Warnungen), Animation im Simulator nicht beurteilbar; zudem ignoriert Zoom die Details-Detents `.medium/.large`. Uebrige Glas-Aenderungen bleiben.
- 8.11.2026: Build 40 (Nutzer: Zoom bei Warnungen nur mit Warnung, Info nie): Sheet-Zoom wieder fuer Orte, Warnungen und Info; Ursache war die Lage der Glasknoepfe im `GlassEffectContainer`. Gemeinsame Huelle `glassSheetSource`; Container nur noch um die Legende. Details bleiben von unten. Zeitleiste: dezentere Slot-Haptik, markanter Schlag bei "Jetzt", Farblinie buendig zur Spur, Zeitanzeige gegenueber dem Daumen.
- 8.11.2026: Build 41 (Nutzerfeedback zu Build 40): Zeit steht als ruhige, zentrierte Glas-Pille ueber Quellzeile und Zeitleistenkarte (Reihenfolge: Pille, Quellzeile, Karte); Zukunft orange, Vergangenheit blau getoent (Farben wie die Linie), dunkle Unterlage fuer Kontrast (>= 6:1 gemessen). Die seitlich springende Zeitanzeige entfaellt. Der fruehere Entscheid "keine Bubble" bleibt bestehen (keine Bubble am Finger); die stehende Pille ersetzt die Zeitzeile in der Karte. Play-Knopf entfernt: Tippen auf die Pille startet/pausiert (Symbol play/pause), langes Druecken (0,4 s, leichte Haptik) springt auf Jetzt; VoiceOver-Aktionen "Zur aktuellen Zeit springen" und "Animation abspielen/pausieren". Karte nur noch Slider (Padding 3 pt vertikal); Farblinie jetzt 4 pt unter der Spur (vorher ca. 18 pt), bündig zur Spur. UI-Tests umgestellt; Flaky-Ursache (Live-Radar, Vergleich frueher Positionen mit wandernder Zeit) durch Warten auf Slider-Wert und feste Pille entschaerft.
- 8.11.2026: Build 42: Abbruch eines Warnungen-Abrufs (Pull-to-Refresh/Task-Abbruch) ist kein Fehler und zeigt kein Banner; der Abruf laeuft in eigenem Task. Echte Fehler bleiben sichtbar (Banner mit Daten und Stand, ohne Daten "Erneut versuchen").
- 9.11.2026: Build 43: Zeit-Pille folgt dem Farbschema (hell: weisse Unterlage, dunkler Text, Kontrast >= 4,5:1, gemessen ca. 18:1; dunkel unveraendert >= 6:1). Legendenpanel der Luftfeldebenen ist auf den Raum zwischen Header und Zeit-Pille begrenzt und scrollt darin.

## 9.11.2026: Englische Lokalisierung, Konvention (E1 bis E3 bestätigt)

Nutzerentscheidung: Die App wird vollständig auf Englisch lokalisiert (Plan `docs/superpowers/plans/2026-11-09-lokalisierung-en-plan.md`). Bestätigt: **E1** klassische `.strings` mit symbolischen Schlüsseln bleiben (kein String Catalog); **E2** Englisch ist Rückfall für alle anderen Systemsprachen (`CFBundleLocalizations = [de, en]`, `CFBundleDevelopmentRegion = en` in allen fünf Plists; deutsche Texte bleiben Entwicklungs-/`value:`-Text im Code); **E3** das Glossar der Bestandsaufnahme (`docs/research/lokalisierung-en.md`, Abschnitt 6) ist Startpunkt, Wortlautfragen (Look-back, Summary) klärt die Abnahme. E4 (englische Webseiten) bleibt getrennt offen. Die aktive Sprache bestimmt allein `AppLanguage.code` (`Shared/AppLanguage.swift`, `Bundle.main.preferredLocalizations`); Push-Locale, `Accept-Language` und Live-Activity-Texte nutzen sie. Prüfung: `tools/check_l10n.sh` (Aufruf im README).

## 9.11.2026: Englische Lokalisierung abgeschlossen (L6)

App-Oberflaeche, Widgets, Live Activity, Watch und Push-Texte liegen in de/en vor (`tools/check_l10n.sh --strict` Exit 0, kein Build-Phasen-Check, sondern Aufruf vor Commits). Englische Store-Screenshots (iPhone 6,3", iPad, Watch teilweise) erzeugt. Offen und vor der englischen Store-Lokalisierung noetig: englische Store-Texte und englische Webseiten (E4, Backend-Repo). Details `docs/status.md`.

## 19.11.2026: Dritte Regenkarte Welt (NOAA RRQPE) in der App

Grundlage: Entscheidungen Lino 17.11.2026 (Backend `docs/decisions.md`, Ebene `radar_world`, PR #2): 2048 px, 24 h Verlauf, Hinweis fest eingeblendet, eigener Eintrag in der Kartenwahl nach Europa, Push „Regen beginnt“ für Welt ausgeschlossen. Quelle NOAA Enterprise Rainfall Rate (RRQPE, Blend), öffentlich über NODD (`noaa-enterprise-rainrate-pds`), frei nutzbar; Nennung „NOAA“ nur als Text, kein Logo, keine Billigung, veränderte Daten nicht als Original ausgeben (Backend-Recherche `docs/research/rrqpe-welt.md`).

- **Kartenwahl:** natives Untermenü Regen › Deutschland (DWD) / Europa (OPERA) / Welt (NOAA). Ohne Backend-Meldung bleibt Welt als „Welt (NOAA) (bald)“ sichtbar, aber nicht wählbar (bestehendes Verhalten, pragmatisch beibehalten: kein leerer Eintrag, kein Fehler für eine Ebene, die der Server nicht anbietet).
- **Quelle:** kurze Quellzeile „NOAA“ unter dem Slider; volle Angabe aus dem Manifest unter (i) › Datenquellen („Quelle: NOAA, von Showers verarbeitet; aus Satellitendaten geschätzt, ungenauer“ plus Veränderungshinweis). Zeitbeschriftung „Schätzung“, nie „Messung“ oder „Vorhersage“.
- **Schätzhinweis fest eingeblendet**, solange Welt aktiv ist: „Schätzung aus Satellitendaten, ungenauer als Radar. Keine Vorhersage.“ (en: „Estimated from satellite data, less accurate than radar. No forecast.“), ohne Billigungswortlaut (`RadarWorldNotice`).
- **Abdeckung:** Kartenmitte nördlich 70° N oder südlich 60° S: Hinweis „Hier gibt es keine Werte: Die Weltkarte reicht nur von 60° S bis 70° N.“; zwischen 60° N und 70° N: „Nördlich von 60° N sind die Schätzwerte eingeschränkt und blasser dargestellt.“ Maßgeblich ist die Kartenmitte (auf 0,1° gerundet).
- **Fehlende Daten ohne stillen Rückfall:** Verliert die aktive Weltkarte ihre Daten (404, veraltet, nicht lesbar, nicht erreichbar ohne frische Daten), bleibt Welt gewählt (`RadarLayer.staysActiveWhenUnavailable`), die Karte zeigt kein Bild und genau EINEN Hinweis oben mit Grund („Regen Welt ist derzeit nicht verfügbar. Die Karte zeigt deshalb keinen Regen.“ bzw. veraltet/nicht erreichbar/nicht lesbar). Die Status-Pille über der Zeitachse entfällt für Welt (sonst doppelt); die Zeitachse bleibt als leere Leiste („Keine Zeiten für Regenradar Welt“). Der nächste Abruf (Polling oder „Daten neu laden“) bringt Bild, Zeitachse und Quellzeile zurück. Europa und die übrigen Ebenen behalten ihren bisherigen stillen Rückfall auf das Deutschland-Radar (unverändert, nicht Teil dieses Auftrags).
- **Nicht umgesetzt (offen):** Farbskala in der Legende für Welt (und Europa); die Legende zeigt nur Titel und Hinweistext, obwohl das Backend die DWD-Klassen nutzt.

## 19.11.2026: Nacharbeit Weltkarte (Reviewkommentar Lino 10:31 und Nachtrag)

- **Legenden bleiben unverändert** (Welt, Europa, Deutschland): kein Farbskalen-Ausbau. Beleg: `git diff 54b6a64` auf `RadarLayerLegend.swift`/`RadarLegend.swift` leer, `LEGEND_*`-Texte de/en identisch.
- **Kartenname:** sichtbar „Regenradar Welt“ (en „Rain radar world“, wie vor der Nacharbeit); Lino hatte kurz „Regen Welt“ gewählt und das am 19.11. zurückgenommen („Regenradar sollte von der Breite passen“). VoiceOver-Name unverändert „Regenradar Welt, aus Satellitendaten geschätzt, ungenauer“. Menüeintrag bleibt „Welt (NOAA)“. Die Hinweistexte nennen die Karten wie die Kapsel: „Regenradar Welt ist derzeit nicht verfügbar …“ / „Regenradar Welt: keine aktuellen Daten …“, Europa „Regenradar Europa …“ (en „Rain radar world …“, „Rain radar Europe …“); das ersetzt die Fassung „Regen Welt …“ aus dem Eintrag der Weltkarte oben. Breite: mit der Systemschrift 15 pt halbfett (macOS-Messung als Näherung für iOS `.subheadline`) ist „Regenradar Welt“ 119 pt breit, „Regenradar Europa“ 137 pt und „Feuchte (Taupunkt)“ 140 pt (beide schon ausgeliefert); en „Rain radar world“ 117 pt, „Rain radar Europe“ 127 pt. Die Kapsel verkleinert sonst bis 0,7 und kürzt am Ende.
- **Europa bleibt bei fehlenden Daten gewählt** (`radar_eu` 404, veraltet, nicht lesbar, nicht erreichbar ohne frische Daten), wie die Weltkarte: genau ein Hinweis oben (`radar-eu-note-unavailable`, „Regenradar Europa ist derzeit nicht verfügbar. Die Karte zeigt deshalb keinen Regen.“ bzw. veraltet/nicht erreichbar/nicht lesbar), keine Pille über der Zeitachse, die Zeitachse bleibt als leere Leiste; der nächste erfolgreiche Abruf bringt Bild und Quellzeile zurück, ohne dass die Ebene wechselt. Kein Schätz- oder Abdeckungshinweis für Europa. Luftdruck Europa und die übrigen Ebenen behalten den stillen Rückfall. Hinweislogik jetzt in `RainLayerNotice` (vorher `RadarWorldNotice`).


## 20.11.2026: Historie 48/72 h in der App (Karte C2AC381D, Entscheidungen des ausführenden Agents, zur Bestätigung durch Lino)

- **72 h in der bestehenden Einstellung:** `RadarPastWindow.options` = 1, 2, 6, 12, 24, 48, 72 (Standard bleibt 2 h); 72 ist ausgegraut, solange der Server weniger meldet. Kleinste Änderung an der vorhandenen Einstellung.
- ~~Backend-Ebenen ohne Einstellung~~ (überholt am 20.11.2026, siehe unten: Lino-Vorgabe, die Einstellung gilt für alle Karten).
- **Prefetch-Fenster höchstens 61 Slots** (statt aller Slots bei Radar/Blitze/Luftdruck); `prefetchSlotLimit` einzelner Ebenen (13/19/25) bleibt kleiner und gilt weiter.
- **Lücken sichtbar:** Löcher kommen aus den tatsächlichen Slots, das Anfangsstück aus `history.gaps`; Hinweiszeile im oberen Stapel statt unten (die untere Zeile würde Apples Rechtslink verdecken); keine Platzhalter, keine Interpolation. Wiedergabe unverändert.

## 20.11.2026: Nacharbeit Historie, eine Einstellung für alle Karten (Vorgabe Lino; Umsetzungsentscheidungen zur Bestätigung)

- **Vorgabe Lino:** „Maximale Vergangenheit“ gilt für ALLE Karten mit Vergangenheit (Radar DE, Europa, Welt, Blitze, Wolken, Wolkenmaske, Luftdruck, Temperatur, Taupunkt, Feuchte). Zeitleiste und Regler zeigen höchstens die gewählte Vergangenheit; die frühere Antwort „nur Deutschland-Radar“ ist überholt.
- **Umsetzung (kleinste Änderung):** `RadarLayerManifest.timeline(at:pastHours:)` kappt Slots (und die Backend-Kopie für Overlay und Prefetch) auf `Bezugszeit − Wahl`; `RadarLayerStore.setPastHours` baut alle Ebenen neu und behält den gewählten Zeitpunkt, sonst der älteste Slot. `WeatherStore.setPastHours` reicht die Wahl durch. Die Vorhersage der Modellebenen bleibt unberührt.
- **Standard 2 h gilt damit auch für Backend-Ebenen (zu bestätigen):** Blitze, Wolken, Luftdruck usw. zeigen ohne Änderung der Einstellung nur 2 h Vergangenheit statt ihres vollen Manifests.
- **Ausgrauen je aktiver Karte:** 48/72 h sind ausgegraut, solange die aktive Karte weniger meldet (`history.hours`, sonst `history_hours`, sonst tatsächliche Spanne; nie geraten). Neuer Fußtext (Entwurf) `INFO_PAST_FOOTER_ALL`/`_LAYER`.
- **Lücken begrenzt auf die Wahl:** Liefert die Quelle weniger als gewählt (Blitze ca. 24 h, Modellebenen seit Deploy, OPERA-Ausweichbucket), steht am ältesten gezeigten Slot „Davor fehlen Daten“ mit der Spanne ab Fensterbeginn (48 h und 72 h unterscheiden sich). Keine Platzhalter, keine Interpolation.
- **Abspielfenster unverändert 3 h (offene Frage):** `min(Einstellung, 3 h)`, nicht geändert, weil nicht nötig.
- **Helligkeit (0,45 nicht angehoben, keine Prüfung abgeschaltet):** Messung je Ebene mit festen Daten (Stubs, ein echtes OPERA-Bild) im Dunkelmodus: Oberfläche 0,395; Blitze, Welt, Sonne, Luftdruck, Europa (echt 0,415, Stub 0,444) unter 0,45. Temperatur 0,642, Wolken 0,648, Taupunkt und Feuchte 0,475 darüber, weil ihr Datenbild die ganze Karte hell färbt (Abdeckung 100 %, Farbhelligkeit 0,62 bis 0,78). **Zu bestätigen:** Die Oberfläche (Karte und App-Chrome ohne Datenebene) wird als eigene Prüfung „OBERFLAECHE“ gegen 0,45 geprüft; für diese vier Ebenen gilt am Gesamtbild die benannte Regressionsgrenze 0,70. Alle anderen Ebenen bleiben bei 0,45. Im Integrationstest mit echten Regendaten werden die Regenebenen nur gemessen (0,42 bis 0,49 je nach Slot), die Blitze- und Luftdruckebene mit 0,45 geprüft.
- **Echtes Europa-Bild als Testfixture** (`WeatherUITests/Fixtures/radar_eu-real-20261120T0455Z.webp`, EUMETNET OPERA, CC BY 4.0, von Showers umprojiziert und eingefärbt): Quelle MeteoGate; zu bestätigen, dass es im Repo bleiben darf.

## 20.11.2026: Review 43beb95, Standardfenster aus dem Backend und Kontrast der Bedienelemente (Entscheidungen zur Bestätigung durch Lino)

- **Standardfenster statt fester 2 h:** Ohne gespeicherte Nutzerwahl gilt je Karte das Serverfenster: Ebenenmanifest `history.hours` (sonst `history_hours`, sonst die tatsächliche Spanne), Deutschland-Radar `history.json` (`history.hours`, nur wenn der `history`-Block vorhanden ist; ohne Block bleibt es bei 2 h wie bisher). Die Zeitleiste reicht so beim ersten Öffnen (frische Installation) bis zum ältesten vorhandenen Zeitpunkt; was fehlt, steht als „Davor fehlen Daten“ am ältesten Slot (aus dem `history`-Block, nicht aus dem Fenster geraten).
- **„Nie gewählt“ gegen „2 h gewählt“:** `radarPastHours` ist jetzt eine optionale Wahl (`WeatherStore.pastChoice`, `RadarPastWindow.choice`). **Migration:** Build 50/52 schreiben `radarPastHours` nur, wenn der Nutzer in der Einstellung einen Schritt antippt (`setPastHours`); der Schlüssel fehlt bei Neuinstallation und bei Nutzern, die nie gewählt haben. Ein gespeicherter gültiger Schritt (1, 2, 6, 12, 24, 48, 72) gilt daher als ausdrückliche Wahl (auch 2 h) und hat Vorrang vor dem Backendfenster; ein fehlender, unlesbarer oder unbekannter Wert (z. B. 5, 0, Text) gilt als „nie gewählt“ und bleibt unverändert im Speicher (kein Umschreiben, kein stilles Anlegen beim Start). Ein Nutzer von Build 50/52, der 2 h bewusst gewählt hat, behält 2 h; ein Nutzer, der nie gewählt hat, bekommt das Serverfenster. **Zur Bestätigung:** es gibt keine Möglichkeit, einen zufällig gespeicherten Wert aus Build 50/52 von einer bewussten Wahl zu unterscheiden, weil der Schlüssel dort nie ohne Auswahl gesetzt wurde.
- **Zeile „Standard (n Stunden)“ in der Einstellung** (`usePastDefault`): löscht die Wahl, die Karten zeigen wieder ihr Serverfenster (nichts gespeichert). Neue Texte `INFO_PAST_DEFAULT` de „Standard (%@)“ / en „Default (%@)“ (Entwurf). Der Haken steht bei „Standard“, solange keine Wahl gespeichert ist.
- **Altbackend unverändert:** Manifest ohne `history`/`past_slots` zeigt die tatsächlich vorhandene Spanne (radar_eu 3 h, radar_world 24 h), ohne Standard-Kappung und ohne Hinweis; DE-Radar ohne Block bleibt bei 2 h; ohne `history.json` die letzte Stunde.
- **Prefetch und Wiedergabe:** Prefetch bleibt auf das 61er-Fenster um die Auswahl begrenzt (Test unverändert grün), Abspielfenster bleibt 3 h und wächst nicht mit dem Serverfenster (`playbackPastHours`). Abbruch-Fix 18c6c93 und Lückenhinweise unverändert.
- **Kontrast der Bedienelemente (Dunkelmodus, helle Datenebenen):** Direkte Messung im Bildausschnitt am Element (WCAG-Kontrastverhältnis, Schwellen 4,5:1 Text, 3:1 Symbole/Bedienelemente; Methode im Kopf von `LayerContrastUITests`): Auf Temperatur, Wolken, Taupunkt, Feuchte lagen weiße Beschriftungen auf dem klaren Glas bei 2,4 bis 3,7:1. **Abhilfe (klein, vorhandenes Glas):** `readableGlass` tönt das Glas hinter Bedienelementen im Dunkelmodus nur bei diesen vier Ebenen mit schwarzem Tint 0,45 (`RadarLayer.coversMapBrightly`, `brightLayerScrim`); der Credit-Hintergrund wird dort dichter (0,75). Ergebnis 6,3 bis 11,8:1. Hell-Modus braucht keine Abhilfe. Helligkeitsgrenze 0,45 (Oberfläche) und Regressionsgrenze 0,70 unverändert; der Kontrastnachweis ergänzt sie.
- **Bestehender, nicht geänderter Befund:** Ort-Untertitel („Regenradar“, sekundäre Schrift) und die Regler-Spur liegen schon auf der Oberfläche ohne Datenebene unter der Schwelle (dunkel 2,52 bzw. 2,02, hell 3,02 bzw. 2,02); auf den hellen Ebenen sind sie nach der Abhilfe nicht schlechter (2,9 bis 3,0 bzw. 2,8 bis 4,3). Eigene Entscheidung nötig, ob sie angehoben werden sollen.
- **Folgeauftrag Kontrast in der geänderten Ansicht (20.11.2026, `ce94532`; zur Bestätigung durch Lino):** Der oben „nicht geänderte Befund“ ist behoben und alle Elemente liegen in allen Ebenen hell und dunkel auf den Zielwerten (4,5:1 Text, 3:1 Symbole/Spur/Linien; Nachweis `showers-history.json` `kontrast_alle_ebenen_review3`). Abhilfen, jeweils kleinste im vorhandenen Stil, kein neues Material, kein Layout: (1) Ort-Untertitel `.primary.opacity(0.85)` statt `.secondary`; (2) leere Reglerspur Weiß 0,75 (dunkel) / Schwarz 0,6 (hell); (3) Linienfarben der Zeitlinie je Modus (`ScreenGlow.lineColor`), Glow unverändert; (4) im Dunkelmodus Mindest-Tint 0,35 (`darkGlassFloor`, Parameter `floor` in `readableGlass`/`glassControl`) nur für Ort-Kapsel, Regenleiste, Ebenen-Menükapsel, Hinweiszeilen und Reglerkarte; Credit-Hintergrund 0,6 (0,75 auf hellen Datenebenen). Symbolknöpfe und Zeitstempel unverändert. Testböden (2,5/2,0) entfernt; der Test prüft die Zielwerte. Helligkeitsgrenzen 0,45/0,70 unverändert und grün. **Zur Bestätigung:** die Anhebung ändert das Aussehen leicht (dunklere Glaskapseln im Dunkelmodus, kräftigere Spur, dunkleres „Regenradar“).
- **Produktionsabnahme (read-only):** Fixture-Tests aus den Manifesten vom 20.11.2026 09:53 UTC (`WeatherTests/Fixtures/produktion-20261120`, `ProductionManifestTests`): alle neun Ebenen und `history.json` werden angenommen; ein Hinweis „Davor fehlen Daten“ nur am ältesten Slot; Modellkarten mit 6 von 72 past_slots werden nicht als vollständig dargestellt. Die Fixture-Dateien sind Rohdaten der öffentlichen Manifeste (nur Metadaten, keine Bilder).

## 21.11.2026: Ladebalken am Aktualisierungshinweis (Karte 205C818F, Entscheidungen des ausfuehrenden Agents, zur Bestaetigung)

- **Messbar nur mit Gesamtumfang:** Prozent und Fuellstand nur, wenn jeder Abruf des Ladevorgangs ein `Content-Length` meldet; sonst durchlaufender Balken ohne Zahl; keine geschaetzten Werte. DWD-Index und Punktabfrage melden keinen Umfang, im Echtbetrieb ist der Balken daher durchlaufend.
- **Prozent ersetzt den Ladekreis** (Breite; sonst bricht der Hinweistext um). Bei Accessibility-Schriftgroessen kein Prozenttext (Hoehe), nur Fuellstand und gesprochener Wert. Offene Frage fuer Lino: ist das so gewuenscht oder soll der Prozenttext dort auf Kosten der Hoehe erscheinen?
- **Radar-Anteil unmessbar:** solange Radar mitlaedt (z. B. „Daten neu laden“) laeuft der Balken durchlaufend, auch wenn die Prognose allein messbar waere.

## 23.11.2026: Prognose-Pille "Server hinterher", Kurztext (Entscheidung Brain, Option 3; Karte 205C818F)

- **Entscheidung:** Der sichtbare Ruhetext der Prognose-Pille im Zustand "Server hinterher" wird "Noch kein neuerer Stand" / "No newer data yet" (einzeilig bei Schrift L, auch SE 3). Der volle Satz bleibt gesprochene Beschriftung und Text im Detailblatt. Grund: der 8-pt-Innenabstand machte den bisherigen zweizeiligen Text 54 pt hoch und die Pille sprang beim Laden um 6 pt; die Zusage "keine Höhenänderung" gilt damit bei L wieder ohne Ausnahme. Bei Accessibility-Größen bleibt der Text "Prognosedetails", dort ist die Pillenhöhe in allen Zuständen gleich gemessen.

## 24.11.2026: Roter Strich der Zeitleiste bleibt, Legendenzeile statt Entfernen (Karte 49689DCF, TestFlight-Rueckmeldung "Was ist das fuer ein Strich?")

- **Entscheidung (Lino):** Der rote Strich ist eine echte Datenluecke und bleibt; nichts wird versteckt oder erfunden. Wo keine Luecke am angezeigten Slot anliegt (dort nennt `radar-gap-note` sie schon) und nicht abgespielt wird, erklaert eine Zeile im oberen Hinweisstapel den Strich: `radar-gap-legend`, de "Roter Strich: Hier fehlen Daten." / en "Red mark: data is missing here." (ein neutraler Text fuer alle Ebenen). Bei Accessibility-Schriftgroessen steht sie wie die anderen Hinweise im Prognose-Detailblatt. Die Marke bleibt `accessibilityHidden`, VoiceOver-Wert des Reglers unveraendert.

