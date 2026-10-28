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
- Karte unabhängig vom eigenen Backend; Bilder grundsätzlich direkt vom Anbieter.
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
