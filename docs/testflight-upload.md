# Erster interner TestFlight-Upload

Stand: 28. Oktober 2026, 17:28 Uhr MEZ. Quellencheckpoint `636aa9d` ist unabhängig geprüft und veröffentlicht. Der ausdrücklich freigegebene einmalige Upload des aktuellen Radar-Archivs lief von 17:26:07 bis 17:27:44 Uhr MEZ über den vorhandenen Xcode-Account. **Apple hat den Build bei der Servervalidierung abgelehnt; er ist nicht als verarbeiteter TestFlight-Build belegt.**

- Das aktuelle Radar-Release-Archiv bestätigt `de.linolaske.weather`, Team `J2DU2P47XW`, Version `0.1.0`, Build `1` und `ITSAppUsesNonExemptEncryption=false`. Archiv-/Icon-/Signaturbelege stehen in [icon.md](icon.md).
- Die lokale `xcodebuild`-Hilfe bestätigt den vorhandenen Xcode-Account als unterstützten Zugang mit `-allowProvisioningUpdates` sowie die unten genannten Exportoptionen. Der tatsächliche Upload erreichte App Store Connect: Die App-Abfrage mit Bundle-ID-Filter `de.linolaske.weather` erhielt HTTP 200; Paket-/SPI-Analyse wurden übertragen und Apple lieferte einen konkreten Bundle-Validierungsfehler. Kein Authentifizierungsfehler trat auf.
- Private Uploadoptionen sind vorbereitet: `method=app-store-connect`, `destination=upload`, `signingStyle=automatic`, `teamID=J2DU2P47XW`, `manageAppVersionAndBuildNumber=false`, `testFlightInternalTestingOnly=true`, `uploadSymbols=true`, `stripSwiftSymbols=true`. Dieser Build ist damit ausschließlich für interne Verteilung bestimmt.
- Keine neuen Builds, gesonderten lokalen Exporte oder Tests ausgeführt; ausschließlich der autorisierte Uploadexport wurde gestartet. Keine Accounts, App-Datensätze, Rollen oder Tester geändert. Keine Zugangsdaten aus Keychain oder Browser extrahiert. Archive, Optionen und Rohlogs bleiben außerhalb des Repos.

Genau das aktuelle Radar-Archiv wurde mit dem in [testflight-readiness.md](testflight-readiness.md) dokumentierten `xcodebuild -exportArchive`-Uploadweg verwendet. Das Kommando endete mit `EXPORT FAILED`, Exitcode `70`.

## Konkreter Serverbefund und nächster Schritt

Apple-Code **`90474`**, `Invalid bundle`: Das Bundle unterstützt iPad, enthält aber in `UISupportedInterfaceOrientations` nur `UIInterfaceOrientationPortrait`, `UIInterfaceOrientationLandscapeLeft` und `UIInterfaceOrientationLandscapeRight`. Für iPad-Multitasking verlangt die Serverprüfung zusätzlich `UIInterfaceOrientationPortraitUpsideDown`, also alle vier Orientierungen. Apple-Fehlerreferenz: `USMU7WAATPMZLHJIEXUVSEQLVE`.

| Zustand | Tatsächlicher Beleg |
|---|---|
| Offizieller Account-/Uploadweg | App-Abfrage erfolgreich; Transport und Serveranalyse erreicht |
| Uploadvalidierung | Abgelehnt mit `90474`; kein erfolgreicher Abschluss |
| Apple-Buildverarbeitung | Kein abgeschlossener oder verfügbarer Build belegt |
| Interne Gruppe/TestFlight | Keine Verfügbarkeit bestätigt, keine Gruppe verändert |

Kein unveränderter Wiederholungsversuch wurde gestartet. Ein frischer Implementierungs-/Releaseauftrag muss die iPad-Orientierungen gezielt korrigieren, die resultierende Release-Plist prüfen, einen neuen geprüften Quellencheckpoint und ein neues Archiv erstellen und anschließend erneut hochladen. Die bisherige Bundle-ID, das Icon und die bestehende iPad-Unterstützung sollen dabei nicht allein zum Umgehen der Validierung geändert werden. Ob Apple Buildnummer `1` nach der Ablehnung erneut akzeptiert, ist nicht belegt; eine notwendige Erhöhung ausdrücklich nachvollziehen.

Ein authentifizierter App-Store-Connect-Browser-/Connectorzugang steht dem Uploadauftrag bislang nicht zur Verfügung. Das installierte `altool` unterstützt `--build-status`, verlangt dafür aber eine eigene passende Authentifizierung; daraus folgt weder ein vorhandener API-Key noch dessen Notwendigkeit für den Xcode-Upload. Ohne autorisierten Statuszugang bleibt die abschließende Prüfung von Verarbeitung und interner Gruppenzuordnung in App Store Connect erforderlich.

Quelle: [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/), am 28. Oktober 2026 aufgerufen; die konkret verfügbaren Optionen wurden zusätzlich an der installierten Toolhilfe geprüft.


## Korrigierter Build 2: Upload angenommen, Verarbeitung läuft

Stand: 28. Oktober 2026, 17:36 Uhr MEZ. Der unabhängig geprüfte und veröffentlichte Quellencheckpoint `0f48cb5ed3c7291d2f37ad7b3dc58c7a835e69d6` korrigiert gezielt den obigen Apple-Befund: `UISupportedInterfaceOrientations~ipad` enthält alle vier Orientierungen, die drei iPhone-Orientierungen und `UIDeviceFamily=[1,2]` bleiben erhalten. Version ist `0.1.0 (2)`; Radar-Icon, Compliance `false`, strenge Archiv-/IPA-Signaturprüfung und explizites Distributionsprofil wurden vor der Uploadfreigabe unabhängig bestätigt. Details in [testflight-readiness.md](testflight-readiness.md).

Der lesende Upload-Preflight bestätigte das aktuelle Archiv und den SHA-256 des geprüften lokalen IPA-Exports: `22d9b21e29e25952da0c96a2f727a7266b5c44df0e88c7ed3ede4babf88a4333`. Die installierte `xcodebuild`-Hilfe bestätigte die verwendeten Optionen. Nach ausdrücklicher Quellencheckpoint-/Reviewfreigabe wurde **genau ein Uploadversuch des neuen Build-2-Archivs** über den vorhandenen Xcode-Account ausgeführt, von **17:34:16 bis 17:35:36 Uhr MEZ**. Gleiche interne Uploadoptionen wie oben, insbesondere `testFlightInternalTestingOnly=true` und `manageAppVersionAndBuildNumber=false`; kein Build-1-Retry, kein Rebuild, kein zusätzlicher lokaler Export und keine neuen Tests.

`xcodebuild -exportArchive` endete mit **Exitcode 0**, **`EXPORT SUCCEEDED`** und **`Upload succeeded`**. Apples ContentDelivery-Protokoll bestätigt **`UPLOAD SUCCEEDED with no errors`**. Der letzte konkrete Serverzustand lautet **`PROCESSING`**, angezeigt als `Uploaded package is processing.` Der frühere Fehler `90474` trat in diesem korrigierten Upload nicht auf; der historische fehlgeschlagene Versuch bleibt oben dokumentiert.

| Zustand Build 2 | Tatsächlicher Beleg |
|---|---|
| Uploadannahme | Erfolgreich abgeschlossen, Exit 0; Apple bestätigt Upload ohne Fehler |
| Apple-Buildverarbeitung | `PROCESSING` am 28. Oktober 2026 um 17:35:36 Uhr MEZ; Abschluss noch nicht belegt |
| Interne TestFlight-Verfügbarkeit | Nicht bestätigt; keine Gruppe oder Tester verändert |

Die begrenzte Statusprüfung wertete den offiziellen Uploadabschluss und Apples zurückgemeldeten Verarbeitungszustand aus. In dieser Sitzung stehen keine authentifizierten App-Store-Connect-/Browser-Connectorwerkzeuge zur Verfügung; ein separater `altool`-Statusaufruf ohne bekannte passende Authentifizierung wurde nicht gestartet. Keine Zugangsdaten aus Keychain oder Browser gelesen, keine API-Schlüssel als neue Voraussetzung eingeführt und keine Accounts, Rollen, App-Datensätze, Einladungen oder Complianceformulare verändert. Private Optionen, Artefakte und Rohlogs bleiben außerhalb des Repos.

Nächster Schritt: Den vorhandenen Build `0.1.0 (2)` in App Store Connect nach abgeschlossener Verarbeitung auf tatsächliche interne TestFlight-Verfügbarkeit und Gruppenzuordnung prüfen. Erfolgreiche Uploadannahme ist hierfür der belegte Ausgangspunkt, noch kein Nachweis eines installierbaren internen Builds.

## Nachfolgeidentität: ShowerNow, noch kein Upload

Die obigen Versuche gehören unverändert zu `de.linolaske.weather`. Der Nutzer berichtet zusätzlich einen Namenskonflikt mit Weather; der Transport-/PROCESSING-Befund bestätigt keinen nutzbaren TestFlight-Build. Aktueller neuer Kandidat ist **ShowerNow**, `de.linolaske.showernow`, `0.1.0 (3)`, Team `J2DU2P47XW`. Der Nutzer hat die Änderung der Bundle-ID im aktuellen ASC-Eintrag auf `de.linolaske.showernow` bestätigt; ein weiterer neuer Datensatz ist keine Voraussetzung. Der finale Quellencheckpoint geht dem separaten Upload voraus. Für diese Identität wurde im Umbenennungsauftrag kein Upload ausgeführt. Aktueller Signingnachweis in [signing.md](signing.md).


## ShowerNow Build 3: passender ASC-Datensatz und Upload angenommen

Stand: 28. Oktober 2026, 17:52 Uhr MEZ. Der Nutzer hat bestätigt, die Bundle-ID im vorhandenen Connecteintrag geändert zu haben; dieser passende Datensatz wurde für den Upload freigegeben. Nach unabhängigem Identity-/Release-Review und veröffentlichtem Quellencheckpoint `2e500fca7be7df05bbe21882127d574189a5a0d1` wurde **genau ein Uploadversuch des endgültigen ShowerNow-Archivs** ausgeführt, von **17:50:14 bis 17:51:38 Uhr MEZ**. Die vorläufigen Artefakte mit noch technischem Bundle-Namen und sämtliche alten Weather-Archive wurden nicht verwendet.

Vor dem Start bestätigte die tatsächliche finale IPA den SHA-256 `07a33550538cd9dadbed6ff61f2d0677d78ef47365303f69a992d6ebb32f9215`, `CFBundleName=ShowerNow`, `CFBundleDisplayName=ShowerNow`, `de.linolaske.showernow` und `0.1.0 (3)`. Team `J2DU2P47XW`, explizites Distributionsprofil, strikte Signaturen, native Radar-Assets und korrigiertes Universal-Packaging waren unabhängig freigegeben. Technisches Projekt/Modul und Archivname bleiben Weather; daraus folgt keine alte Produktidentität.

Der offizielle `xcodebuild -exportArchive`-Upload verwendete den vorhandenen Xcode-Account und die oben dokumentierten internen Uploadoptionen, insbesondere `destination=upload`, `testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false` und `uploadSymbols=true`. Die installierte Toolhilfe bestätigte diese Optionen. Keine neuen Builds, Tests oder zusätzlichen lokalen Exporte; keine App-Datensätze, Rollen, Gruppen oder Tester verändert und keine Zugangsdaten aus Keychain oder Browser gelesen.

**Der passende App-Store-Connect-Datensatz ist durch Antwortdaten belegt:** Die offizielle AppsService-Abfrage mit Bundle-ID-Filter `de.linolaske.showernow` lieferte einen Datensatz mit `bundleId=de.linolaske.showernow`, `name=ShowerNow` und `removed=false`. Der Nachweis beruht damit auf dem Antwortinhalt, nicht allein auf HTTP 200. Im Build-3-Upload trat kein Namenskonflikt- oder Bundle-Validierungsfehler auf. Der frühere vom Nutzer berichtete Weather-Namenskonflikt und die historischen Uploadbefunde bleiben davon getrennt.

`xcodebuild` endete mit **Exitcode 0**, **`EXPORT SUCCEEDED`** und **`Upload succeeded`**. Apples ContentDelivery-Protokoll bestätigt **`UPLOAD SUCCEEDED with no errors`**. Letzter konkreter Serverzustand am 28. Oktober 2026 um **17:51:38 Uhr MEZ**: **`PROCESSING`**, `Uploaded package is processing.`

| Zustand ShowerNow Build 3 | Tatsächlicher Beleg |
|---|---|
| ASC-App-Matching | Antwortdatensatz für ShowerNow / `de.linolaske.showernow`, nicht entfernt |
| Uploadannahme | Erfolgreich, Exit 0; Apple bestätigt Upload ohne Fehler |
| Apple-Buildverarbeitung | `PROCESSING` um 17:51:38 Uhr MEZ; Abschluss nicht belegt |
| Interne TestFlight-Verfügbarkeit | Noch nicht bestätigt; keine Gruppen-/Testeränderung |

Die begrenzte Statusprüfung wertete den offiziellen Uploadabschluss und den zurückgemeldeten Verarbeitungszustand aus. Ein authentifizierter separater Status-/Browserzugang stand diesem Auftrag nicht zur Verfügung; kein zusätzlicher API-Schlüssel oder undokumentierter Tokenzugriff wurde eingeführt. Kein Wiederholungsupload. Private Artefakte, Uploadoptionen und Rohlogs bleiben außerhalb des Repos.

Nächster Schritt: ShowerNow `0.1.0 (3)` nach abgeschlossener Verarbeitung in App Store Connect auf tatsächliche interne TestFlight-Verfügbarkeit und bestehende Gruppenzuordnung prüfen. Uploadannahme und passender App-Datensatz sind belegt; ein installierbarer interner Build bleibt gesondert zu bestätigen.


## ShowerNow Build 4: geprüfter Kandidat und einmaliger interner Upload

Stand: 28. Oktober 2026, 18:17 Uhr MEZ. Quellencheckpoint `6750d0e954de900cb8bcf6f52b3faf1fc2d769d9` ist veröffentlicht und unabhängig ohne offene P1-/P2-Befunde geprüft. Darauf basieren das neue signierte Build-4-Archiv und der lokale IPA-Export; alle 24 Projekt-/Konfigurations-/App-/Test-/Ressourcendateien sind bytegleich. Reale Archiv-/IPA-Metadaten und strikte Signaturen sowie das explizite Distributionsprofil sind geprüft, siehe [signing.md](signing.md). Der lokale IPA-SHA-256 lautet `ec9d4acf35684e7f7aed1d5561f1fa7f97fbc0354ce2586573d50d5fb46ccc28`.

Genau ein autorisierter Upload des neuen Archivs wurde über den vorhandenen offiziellen Xcode-Account gestartet. Die installierte Toolhilfe bestätigt die Optionen: `destination=upload`, `testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`, automatische Signierung und Team `J2DU2P47XW`. Keine App-Datensätze, Rollen, Gruppen oder Tester verändert; keine Zugangsdaten extrahiert. Tests für unveränderten Code nicht wiederholt. Der Uploadexport lief von **18:16:03 bis 18:17:29 Uhr MEZ** und endete mit **Exitcode 0**, **`EXPORT SUCCEEDED`** und **`Upload succeeded`**. Apples offizielles ContentDelivery-Protokoll bestätigt **`UPLOAD SUCCEEDED with no errors`**. Letzter konkreter Zustand: **`PROCESSING`**, `Uploaded package is processing.` Kein Wiederholungsupload und keine separate fortlaufende Statusabfrage.

| Zustand Build 4 | Tatsächlicher Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich; Metadaten, strikte Signaturen, Profil und Quellenbytegleichheit geprüft |
| Uploadannahme | Erfolgreich, Exit 0; Apple bestätigt Upload ohne Fehler |
| Verarbeitung | `PROCESSING` um 18:17:29 Uhr MEZ; Abschluss nicht belegt |
| Interne TestFlight-Verfügbarkeit | Für Build 4 noch offen; keine Gruppen-/Testeränderungen |

Build 3 funktioniert inzwischen laut Nutzer intern über TestFlight. Dies ist kein Nachweis für die neue Build-4-Verarbeitung. Nächster Schritt: Build `0.1.0 (4)` nach Verarbeitung im bestehenden ShowerNow-TestFlight-Eintrag auf Installierbarkeit prüfen und im Alltag Radar-Nachladen, Zeitslider und optionale Einordnung testen. Echte lokale Modellgeneration bleibt ungeprüft. Private Artefakte, Optionen und Rohlogs bleiben außerhalb des Repos.


## ShowerNow Build 5: P0-Korrekturen, geprüfter Release

Quellencheckpoint `c4748931c14ce9bf79a7f6e97e024a27da3c27a8` ist veröffentlicht und im begrenzten P0-Schlussreview ohne offene P1/P2 freigegeben. Build 5 korrigiert insbesondere automatische Netzwerk-Wiederanfragen fehlgeschlagener Tilekeys, ungültige Bildantworten, klebrige Radarwarnungen und fehlendes Refreshfeedback; kompakte Timeline und gezielter Maximal-Dynamic-Type-Fix sind enthalten. Die [Test- und Messgrenzen](reviews/p0-build5.md) bleiben ausdrücklich erhalten: variable kalte Ladezeit, keine Instant-Garantie und physischer Alltagstest offen.

Signiertes Archiv und lokaler IPA-Export erfolgreich; 24 Projekt-/Konfigurations-/App-/Test-/Ressourcendateien bytegleich zu diesem Commit. Tatsächliche IPA-Metadaten, beide strikten Signaturen, natives Icon und explizites Profil sind geprüft, siehe [signing.md](signing.md). IPA-SHA-256: `1faaacd552a2b432aebea46eea48d9c595f63c013c9cfa7d49731a820de95b11`.

Genau ein autorisierter interner Upload dieses Archivs wurde um **19:13:02 Uhr MEZ** über den vorhandenen offiziellen Xcode-Account gestartet. Optionen unverändert: `testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false`, automatische Signierung, Team `J2DU2P47XW`. Keine Live-Matrix oder Featureänderung im Releaseauftrag; keine App-Datensätze, Rollen, Gruppen, Tester oder Einladungen verändert und keine Zugangsdaten extrahiert. Der Upload endete um **19:14:17 Uhr MEZ** mit **Exit 0**, **`EXPORT SUCCEEDED`** und **`Upload succeeded`**. Apples offizielles ContentDelivery-Protokoll bestätigt **`UPLOAD SUCCEEDED with no errors`**; letzter Serverstand **`PROCESSING`**. Genau ein Versuch, kein Retry oder fortlaufendes Polling. Tatsächliche interne Installierbarkeit von Build 5 bleibt nach Verarbeitung zu prüfen.


Nach dem Start wurde ein einmaliger vollständiger `WeatherTests`-Logiklauf gegen exakt denselben Quellencommit zusätzlich beauftragt, da die PNG-Prüfung gemeinsame Fixtures betrifft. Zu diesem Zeitpunkt hatte der Upload bereits Serveranalyse-/Completiontransfer erreicht; er wurde nicht blind abgebrochen oder wiederholt. Der getrennte Runner verwendet eine eigene Quellenkopie/DerivedData und ändert den Appcode nicht. Der Lauf endete um **19:14:21 Uhr MEZ** mit `TEST SUCCEEDED`, Exit 0: **41 Tests, null Fehler, 2,760 s** (33 DWD/Map, acht Einordnung). Dies ist nun ein tatsächlicher gemeinsamer Grünlauf der aktuellen Logikquellen; keine UI-Suite erneut ausgeführt. Quellen und hochgeladene App sind unverändert. Erfolgreiche Uploadannahme und grüner Logiklauf ersetzen weiterhin keinen physischen Alltagstest oder eine garantierte kalte Ladezeit.


## ShowerNow Build 6: budgetiertes Timeline-Vorladen, Upload angenommen

Veröffentlichter Quellencheckpoint `87915f8a6c8eda891cc094a46554cfe8200d908d`, unabhängiger [Review ohne offene P1/P2](reviews/prefetch-build6.md) und [Integration](prefetch-integration.md): 16 gezielte Prefetchtests sowie der abschließende gemeinsame Logiklauf mit 57 Tests und null Fehlern. Diese Läufe sind keine addierbare Zahl unterschiedlicher Tests. Kein weiterer Testlauf oder Live-DWD-Fanout im Releaseauftrag.

Das neue signierte Archiv und der lokale IPA-Export wurden aus einer isolierten Kopie genau dieses veröffentlichten Commits erstellt. 26 getrackte App-/Test-/Projekt-/Konfigurations-/Ressourcendateien einschließlich Schemen und nativer Iconquellen sind bytegleich. Beide tatsächlichen Apps bestehen die strikte Signaturprüfung. Die IPA bestätigt ShowerNow in beiden Namensfeldern, `de.linolaske.showernow`, `0.1.0 (6)`, Familie `[1,2]`, drei iPhone-/vier iPad-Orientierungen, Compliance `false`, native Radar-Assets und das explizite Distributionsprofil mit Team `J2DU2P47XW`. SHA-256: `1fda7478cb765b2e9298227ba101683aa5e521af9446f60db9f69a39f7761555`. [Signingnachweis](signing.md).

Genau ein autorisierter interner Upload wurde am **28. Oktober 2026 um 20:00:32 Uhr MEZ** gestartet und um **20:01:53 Uhr MEZ** angenommen. Offizieller `xcodebuild -exportArchive`-Pfad mit vorhandenem Xcode-Account, automatischer Signierung, `testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false` und `uploadSymbols=true`. **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`** und Apples ContentDelivery-Bestätigung **`UPLOAD SUCCEEDED with no errors`**. Letzter konkreter Serverzustand: **`PROCESSING`**. Kein Abbruch, Retry oder fortlaufendes Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert und keine Zugangsdaten extrahiert.

| Zustand Build 6 | Tatsächlicher Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich; Metadaten, Signaturen, explizites Profil und Quellenbytegleichheit geprüft |
| Uploadannahme | Erfolgreich, Exit 0; Apple bestätigt Upload ohne Fehler |
| Verarbeitung | `PROCESSING` um 20:01:53 Uhr MEZ; Abschluss nicht belegt |
| Interne TestFlight-Installierbarkeit | Noch nicht bestätigt |

Build 6 enthält die zunächst konservative Prefetch-Netzpolicy: teure Verbindungen einschließlich üblichen Mobilfunks werden ausgeschlossen. Die danach präzisierte Nutzerentscheidung erlaubt normales WLAN und Mobilfunk bei weiterhin gesperrtem Low Data Mode. Diese Änderung wird separat als Build 7 umgesetzt; sie wird dem bereits hochgeladenen Build 6 nicht rückwirkend zugeschrieben. Private Artefakte, Optionen und Rohlogs bleiben außerhalb des Repos.


## ShowerNow Build 7: Mobilfunk-Prefetch und Slider-Feedback, Upload angenommen

Veröffentlichter Quellencheckpoint `1c093ddceee12d0e434030d7f18cb72b2235aa94` (Build-7-Code `a9289fb` plus Dokumentation). Archiv und lokaler Export aus isolierter Kopie genau dieses Commits; Metadaten, Signaturen, Profil und Bytegleichheit siehe [Signingnachweis](signing.md).

Genau ein autorisierter interner Upload am **30. Oktober 2026 von 06:31:30 bis 06:33:03 Uhr MEZ**: offizieller `xcodebuild -exportArchive`-Pfad mit vorhandenem Xcode-Account, automatischer Signierung und denselben privaten Optionen wie Build 6 (`testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`). **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`**. Letzter Serverzustand: **`Uploaded package is processing`**. Kein Retry, kein Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert.

| Zustand Build 7 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 |
| Verarbeitung | Läuft laut letzter Meldung; Abschluss nicht belegt |
| Interne TestFlight-Installierbarkeit | Noch nicht bestätigt |


## ShowerNow Build 8: vollständiges Timeline-Vorladen, Upload angenommen (Xcode 27.1)

Veröffentlichter Quellencheckpoint `cdd5735af73938e80a7a9acd3b2ea079534d946b`; Archiv/Export aus isolierter Kopie, Metadaten siehe [Signingnachweis](signing.md). Gleiche privaten Optionen wie Build 6/7 (`testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`), offizieller `xcodebuild -exportArchive`-Pfad mit vorhandenem Xcode-Account.

1. **Versuch 1, Xcode 27.2 (27B52), 30. Oktober 2026 11:47:36 bis 11:49:00 Uhr MEZ:** Exit 70, `EXPORT FAILED`, Apple-Meldung `Unsupported SDK or Xcode version` (die App wurde mit einem von App Store Connect nicht unterstützten SDK/Xcode gebaut; Release Candidates oder Release erforderlich). Klar nicht angenommen; Ursache eindeutig die Xcode-Version, kein Signing-, Netz-, Konto- oder Buildnummernproblem.
2. **Versuch 2 (einziger Retry), Xcode 27.1 (27A9275) per `DEVELOPER_DIR`, Neuarchivierung aus derselben Quellenkopie, 11:49:50 bis 11:50:53 Uhr MEZ:** **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`**. Letzter Serverzustand: **`Uploaded package is processing`**. Kein weiterer Retry, kein Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert.

| Zustand Build 8 | Beleg |
|---|---|
| Archiv und lokale IPA (Xcode 27.1) | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (zweiter Versuch) |
| Verarbeitung | Läuft laut letzter Meldung; Abschluss nicht belegt |
| Interne TestFlight-Installierbarkeit | Noch nicht bestätigt |

Hinweis: Mit Xcode 27.2 ist derzeit kein Upload möglich; bis Apple 27.2 akzeptiert, Releases mit Xcode 27.1 bauen.
