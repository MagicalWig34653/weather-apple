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

## ShowerNow Build 9: Radar-Cache-Anbindung, Upload angenommen (Xcode 27.1)

Veröffentlichter Quellencheckpoint `0c5e22ff88fa3716e6b794ce093d3c5e9f9354e3` (HEAD == `origin/main`, Arbeitsbaum sauber, `CURRENT_PROJECT_VERSION = 9`); Archiv/Export aus isolierter Kopie, Metadaten siehe [Signingnachweis](signing.md). Gleiche privaten Optionen wie Build 6 bis 8, offizieller `xcodebuild -exportArchive`-Pfad mit vorhandenem Xcode-Account. Wegen der Ablehnung von Xcode 27.2 bei Build 8 direkt mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR` gebaut.

**Genau ein Upload, 30. Oktober 2026 21:29:44 bis 21:31:14 Uhr MEZ:** **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`**. Letzter Serverzustand: **`Uploaded package is processing`**. Kein Retry, kein Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert.

| Zustand Build 9 | Beleg |
|---|---|
| Archiv und lokale IPA (Xcode 27.1) | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster und einziger Versuch) |
| Verarbeitung | Läuft laut letzter Meldung; Abschluss nicht belegt |
| Interne TestFlight-Installierbarkeit | Noch nicht bestätigt |

Hinweis: Mit Xcode 27.2 ist weiterhin kein Upload möglich (Stand Build 8); Releases bis zur Apple-Unterstützung mit Xcode 27.1 bauen.

## ShowerNow Build 10: korrigierter Datenschutztext, Upload angenommen (Xcode 27.1)

Veröffentlichter Quellencheckpoint `b106f1e7d94344e2a1128e63da67c89be8ac9a21` (HEAD == `origin/main`, Arbeitsbaum sauber, `CURRENT_PROJECT_VERSION = 10`); Inhalt gegenüber Build 9 ausschließlich die korrigierte Datenschutzaussage (`b9ce323`). Archiv/Export aus isolierter Kopie, Metadaten siehe [Signingnachweis](signing.md). Private Uploadoptionen wie Build 6 bis 9 (`testFlightInternalTestingOnly=true`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`), offizieller `xcodebuild -exportArchive`-Pfad mit vorhandenem Xcode-Account, Xcode 27.1 (27A9275) per `DEVELOPER_DIR`.

**Genau ein Upload, 30. Oktober 2026 21:49:46 bis 21:51:20 Uhr MEZ:** **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`**. Letzter Serverzustand: **`Uploaded package is processing`**. Kein Retry, kein Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert.

| Zustand Build 10 | Beleg |
|---|---|
| Archiv und lokale IPA (Xcode 27.1) | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster und einziger Versuch) |
| Verarbeitung | Läuft laut letzter Meldung; Abschluss nicht belegt |
| Interne TestFlight-Installierbarkeit | Noch nicht bestätigt |

Hinweis: Mit Xcode 27.2 ist weiterhin kein Upload möglich (Stand Build 8); Releases mit Xcode 27.1 bauen.


## ShowerNow Build 11: erster Build ohne "Internal Only", Upload angenommen (Xcode 27.1)

Veröffentlichter Quellencheckpoint `ae0f428` (Code `847e9ff` plus Buildnummer 11; HEAD == `origin/main`, Arbeitsbaum sauber). Inhalt gegenüber Build 10: Einstellung "Maximale Vergangenheit" (bis 48 h, `history.json`), Datenschutz-Link im Info-Sheet, feine Scrub-Geste und 3-h-Animationsfenster, robustere Punktprognose (Retries, Fehlerarten, letzte gültige Prognose mit Altersanzeige), Apple-Karte/Ortssuche im Datenschutztext, `project.yml` Universal. Archiv/Export aus isolierter Kopie, Metadaten siehe [Signingnachweis](signing.md).

**Abweichung zu Build 1 bis 10:** Der Upload wurde ohne `testFlightInternalTestingOnly` vorbereitet; tatsächlich benutzter Wert `false`. Die weiteren Optionen blieben (`destination=upload`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`, automatische Signierung, Xcode 27.1 per `DEVELOPER_DIR`). Wirkung der Option laut Hilfe von `xcodebuild`: bei `true` keine Verteilung extern oder im App Store; Quelle für die Zuordnungsregel siehe Signingnachweis.

**Genau ein Upload, 31. Oktober 2026 von 04:55:25 bis 04:57:12 Uhr MEZ:** **Exit 0**, **`EXPORT SUCCEEDED`**, **`Upload succeeded`**. Letzter Serverzustand: **`Uploaded package is processing`**. Kein Retry, kein Polling; keine App-Datensätze, Tester, Gruppen, Rollen oder Konten verändert, keine Gruppenzuordnung, keine Beta-App-Prüfung eingereicht.

| Zustand Build 11 | Beleg |
|---|---|
| Archiv und lokale IPA (Xcode 27.1) | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster und einziger Versuch) |
| Verarbeitung | Läuft laut letzter Meldung; Abschluss nicht belegt |
| Installierbarkeit / externe Zuordenbarkeit | Nicht bestätigt |

Der Nutzer muss Build 11 nach der Verarbeitung in App Store Connect einer externen Gruppe zuordnen und die Testinformationen ausfüllen (siehe [apple-externe-tests.md](apple-externe-tests.md)). Voraussetzung im Betrieb: Das Backend auf dem Swarm muss auf `sha-e80b6b8` (oder neuer) aktualisiert sein, sonst zeigt die App "Historie nicht verfügbar" und der Datenschutz-Link führt auf eine 404-Seite.

## ShowerNow Build 12: Upload angenommen (Xcode 27.1)

Veröffentlichter Quellencheckpoint `de280c1` (`CURRENT_PROJECT_VERSION = 12`), Archiv/Export aus isolierter `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`. Vorher: volle Tests (266 Unit, 7 UI) ohne Fehler. Optionen wie Build 11 (`testFlightInternalTestingOnly=false`, `destination=upload`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`, automatische Signierung; belegt in der geschriebenen `ExportOptions.plist`).

**Genau ein Upload, 31. Oktober 2026 von 21:15:02 bis 21:16:17 Uhr MEZ:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Keine Delivery-UUID in der Ausgabe. Entitlements der exportierten App: `aps-environment=production`, `com.apple.developer.usernotifications.time-sensitive=true`, `get-task-allow=false`. IPA-SHA-256 `ee0705154d72c339bcea375d67e02dd1b9d7a85e2ff82383bfaa9b10ef439ad1`.

| Zustand Build 12 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 |
| Verarbeitung / externe Zuordenbarkeit | Nicht geprüft |

Der Nutzer muss Build 12 nach der Verarbeitung in App Store Connect einer externen Gruppe zuordnen.

## ShowerNow Build 13: Upload angenommen (Xcode 27.1)

Quellencheckpoint `f1310e8` (`CURRENT_PROJECT_VERSION = 13`, Code `f5d9e96`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`; vorher `WeatherTests` 315 Tests ohne Fehler. Optionen wie Build 12. **Genau ein Upload, 1. November 2026 von 20:45:43 bis 20:47:04 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Entitlements: `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`; `Localizable.strings` de/en enthalten; IPA-SHA-256 `75ca540ec0712c17d4767f91893cc49e03cfdef2b8666ffc145e2eb3d07976aa`.

| Zustand Build 13 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 |
| Verarbeitung / Installierbarkeit / externe Zuordnung | Nicht geprüft |

## ShowerNow Build 14: Upload angenommen (Xcode 27.1)

Quellencheckpoint `4328f80` (`CURRENT_PROJECT_VERSION = 14`, Basis `1974cd1` mit Codex-Fixes `7b4d8df`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`; vorher `WeatherTests` 321 Tests ohne Fehler. Optionen wie Build 13 (`testFlightInternalTestingOnly=false`). **Genau ein Upload, 2. November 2026 von 13:46:18 bis 13:47:42 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Entitlements: `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`; `codesign --verify --strict --deep` ok; CFBundleVersion 14; `Localizable.strings` de/en enthalten; SHA-256 der lokal exportierten IPA (gleiches Archiv) `d7ec8960ce2deb21d866d6a830beec61be307d92ddd2e543e3bc2e4233d84d0e`. Build 13 liegt in der externen Prüfung; Build 14 wurde keiner Gruppe zugeordnet und nicht eingereicht.

| Zustand Build 14 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## ShowerNow Build 15: Upload angenommen (Xcode 27.1), erster Build mit Watch-App, Widgets und Live Activity

Quellencheckpoint `3a32f41` (`CURRENT_PROJECT_VERSION = 15`; Feature `c2f52b3`, Buildnummer `f3b19f1`, Docs `eab7f7f`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher 3.11.2026: `WeatherTests` 410 und `WeatherUITests` 7 Tests, 0 Fehler. Für Tests unter Xcode 27.1 fehlte die passende iOS-Runtime (SDK 27.1 erwartet 24A94232); lokal `xcrun simctl runtime match set iphoneos27.1 24A434` gesetzt (rücknehmbar mit `match unset`) und ein eigenes Simulatorgerät "B15 iPhone 18 Pro" auf iOS 27.0 angelegt (Maschinen-Einstellung, nicht Repo). Optionen wie Build 14 (`testFlightInternalTestingOnly=false`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`).

**Erster Exportversuch (Upload-Plist, 19:01 bis 19:02) lud nichts hoch:** Die Apple-Validierung lehnte das Paket ab (Exit 70): fehlendes `CFBundleIconName`/Icons der Watch-App und unsignierte Handoff-`.md`-Dateien in den Bundles. Behebung in `3a32f41` (`project.yml`: `**/*.md` aus allen Targets ausgeschlossen, `AppIcon.icon` und `ASSETCATALOG_COMPILER_APPICON_NAME` für die Watch-App, `CFBundleIconName` in `WeatherWatch-Info.plist`). Danach neues Archiv und **genau ein erfolgreicher Upload, 3. November 2026 von 19:07:06 bis 19:09:02 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`.

Paketprüfung (lokal exportierte IPA aus demselben Archiv, SHA-256 `e9fcaef3eb3896b29a342c149f0340135d94ff870259d0077bf03e7be33c65bc`):

| Bundle | Bundle-ID | CFBundleVersion / MinOS | Entitlements |
|---|---|---|---|
| App | `de.linolaske.showernow` | 15 / 27.0 | App Group, `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false` |
| Widgets (`PlugIns/WeatherWidgets.appex`) | `de.linolaske.showernow.widgets` | 15 / 27.0 | App Group, `get-task-allow=false` |
| Watch-App (`Watch/WeatherWatch.app`) | `de.linolaske.showernow.watchkitapp` | 15 / 27.0, `WKCompanionAppBundleIdentifier=de.linolaske.showernow`, `CFBundleIconName=AppIcon` | App Group, `get-task-allow=false` |
| Watch-Widgets (in der Watch-App) | `de.linolaske.showernow.watchkitapp.widgets` | 15 / 27.0 | App Group, `get-task-allow=false` |

App Group überall `group.de.linolaske.showernow`; `NSSupportsLiveActivities=true`, URL-Schema `showernow`, `ITSAppUsesNonExemptEncryption=false`; `de.lproj`/`en.lproj` in allen vier Bundles; `codesign --verify --deep --strict` je Bundle ok; keine `.md`-Dateien im Paket.

Portal: Die vier freigegebenen Ressourcen (App-IDs `.widgets`, `.watchkitapp`, `.watchkitapp.widgets`, App Group) wurden nur über Automatic Signing verwendet; die Logs zeigen Team-Provisioning-Profile für alle vier Bundle-IDs. Ob Xcode sie neu angelegt oder vorgefunden hat, ist aus den Logs nicht ablesbar. Sonst keine Signing-/Store-Änderungen; Build keiner Gruppe zugeordnet, nicht eingereicht.

| Zustand Build 15 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (zweiter Exportversuch; erster scheiterte in der Validierung ohne Upload) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |
| Gerätelauf (iPhone, Watch), Widgets, Komplikationen, Live Activity, Push | Nicht geprüft |

## ShowerNow Build 16: Upload angenommen (Xcode 27.1), Watch-Radarkarte, Icon d2

Quellencheckpoint `69c1f87` (`CURRENT_PROJECT_VERSION = 16`; Code `5392783`, `cd132dd`, `2b4ce87`, Doku `69c1f87`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher 3.11.2026: `Weather`-Schema 417 Tests (410 Unit + 7 UI), 0 Fehler, iPhone-Simulator iOS 27.0; `WeatherWatch`-Build (watchOS 27.0 Simulator) erfolgreich. Optionen wie Build 15 (`testFlightInternalTestingOnly=false`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`).

**Genau ein Upload, 3. November 2026 von 22:49:33 bis 22:55:23 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokal exportierte IPA aus demselben Archiv, SHA-256 `1ad856e589db2c237db885db766c802ac4242a15076df215a68ae065a7432405`): vier Bundles (App `de.linolaske.showernow`, Widgets `.widgets`, Watch-App `.watchkitapp` mit `WKCompanionAppBundleIdentifier=de.linolaske.showernow` und `CFBundleIconName=AppIcon`, Watch-Widgets `.watchkitapp.widgets`), `CFBundleVersion` überall 16; App Group `group.de.linolaske.showernow` überall; `aps-environment=production` und `time-sensitive=true` nur in der App; `get-task-allow=false`; `NSSupportsLiveActivities=true`, `ITSAppUsesNonExemptEncryption=false`; `de.lproj`/`en.lproj` in allen vier; `codesign --verify --deep --strict` je Bundle ok; keine `.md` im Paket; `Assets.car` in App und Watch-App vorhanden (Inhalt des Watch-Icons d2 nicht einzeln geprüft).

| Zustand Build 16 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Watch-Hardware, Krone, Dekoder-Laufzeit, Duo-Innendisplay | Nicht geprüft |

## Showers Build 17: Upload angenommen (Xcode 27.1), Umbenennung

Quellencheckpoint `84d40c2` (`CURRENT_PROJECT_VERSION = 17`; Code `3bd5e3c`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher: `Weather`-Schema 417 Tests (410 Unit + 7 UI), 0 Fehler; `WeatherWatch`-Build erfolgreich. Optionen wie Build 16. Die IPA heißt nun `Showers.ipa` (Anzeigename), Bundle-IDs unverändert.

**Genau ein Upload, 3. November 2026 von 23:11:10 bis 23:14:50 Uhr** (`destination=upload`, nach vorherigem lokalem Export zur Paketprüfung): Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `ad36fd33af4598d5237653447d3e871d50f4b5af9ff490897bfe2ca456fb7f88`): vier Bundles (`de.linolaske.showernow`, `.widgets`, `.watchkitapp` mit `WKCompanionAppBundleIdentifier=de.linolaske.showernow` und `CFBundleIconName=AppIcon`, `.watchkitapp.widgets`); `CFBundleDisplayName` überall `Showers`; `CFBundleVersion` 17, Version 0.1.0; App Group `group.de.linolaske.showernow` überall; `aps-environment=production` und `time-sensitive` nur in der App; `get-task-allow=false` (App); `NSSupportsLiveActivities=true`, `ITSAppUsesNonExemptEncryption=false`; `de.lproj`/`en.lproj` in allen vier; `codesign --verify --deep --strict` je Bundle ok; keine `.md` im Paket.

| Zustand Build 17 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Watch-Hardware, Anzeige des Namens auf Hardware | Nicht geprüft |


## Showers Build 18: Upload angenommen (Xcode 27.1), App-Symbol-Auswahl

Quellencheckpoint `ee78b43` (`CURRENT_PROJECT_VERSION = 18`; Feature `52f50da`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 (27A9275) per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher: `Weather`-Schema 416 Unit-Tests, 0 Fehler; UI-Tests siehe [icon-auswahl.md](icon-auswahl.md); `WeatherWatch`-Build erfolgreich. Optionen wie Build 17 (`testFlightInternalTestingOnly=false`, `manageAppVersionAndBuildNumber=false`, `uploadSymbols=true`).

**Genau ein Upload, 4. November 2026 von 11:00:14 bis 11:02:27 Uhr** (`destination=upload`, nach vorherigem lokalem Export zur Paketprüfung): Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `08e48d1509d70a57f4372a95972c087acad9713952d867b89432161d3d3055ee`): vier Bundles (`de.linolaske.showernow`, `.widgets`, `.watchkitapp`, `.watchkitapp.widgets`); `CFBundleDisplayName` überall `Showers`; `CFBundleVersion` überall 18; `codesign --verify --deep --strict` je Bundle ok; `aps-environment=production`, `time-sensitive`, `get-task-allow=false`, App Group in der App; keine `.md` im Paket. App-`Info.plist`: je 16 `CFBundleAlternateIcons` in `CFBundleIcons` und `CFBundleIcons~ipad`, primär `AppIcon`; `Assets.car` der App enthält alle 16 Alternativen. Watch-App: nur `CFBundleIconName=AppIcon`, keine `Alt`-Renditionen in ihrem `Assets.car`.

**Paketgröße:** IPA Build 17 (`10e7ef9`, gleiche Exportoptionen, lokal) 8.409.378 Byte; Build 18 87.749.697 Byte (+79,3 MB). Ursache: `Assets.car` der App wächst von etwa 4,6 MB auf 85,4 MB; jedes Alternativ-Icon bringt etwa 4,5 bis 6,8 MB vorgerenderte Renditionen (alle Größen und Darstellungen). Die tatsächliche App-Store-Downloadgröße (App Thinning) wurde nicht gemessen.

| Zustand Build 18 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Alert-Verhalten auf Hardware, Dark/Tinted der Alternativen | Nicht geprüft |


## Showers Build 19: Upload angenommen (Xcode 27.1), V4B-Varianten in der App-Symbol-Auswahl

Quellencheckpoint `236c4f8` (`CURRENT_PROJECT_VERSION = 19`), Archiv/Export aus `git archive`-Kopie mit Xcode 27.1 per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher: 416 Unit-Tests, 0 Fehler; UI-Tests siehe [icon-auswahl.md](icon-auswahl.md). Optionen wie Build 18.

**Genau ein Upload, 4. November 2026 von 14:36:31 bis 14:39:00 Uhr** (nach lokalem Export zur Paketprüfung): Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA, SHA-256 `f1e10e40ac034fee67777e7a69cf14bc56081cc1903931183aa8a61f5511009b`): vier Bundles, `CFBundleDisplayName` überall `Showers`, `CFBundleVersion` überall 19, `codesign --verify --deep --strict` je Bundle ok; `aps-environment=production`, `time-sensitive`, `get-task-allow=false`, App Group in der App; keine `.md` im Paket. App-`Info.plist`: je 19 `CFBundleAlternateIcons` in `CFBundleIcons` und `CFBundleIcons~ipad`, primär `AppIcon`; `Assets.car` enthält `AltV4B`, `AltV4BEigen`, `AltV4BS90`, `AltV4BS90V`. Watch-App: nur `CFBundleIconName=AppIcon`, keine `Alt`-Renditionen.

**Paketgröße:** IPA Build 19 107.082.362 Byte (Build 18: 87.749.697; +19,3 MB für drei zusätzliche Alternativen, je etwa 6,4 MB). App-Store-Downloadgröße (App Thinning) nicht gemessen.

| Zustand Build 19 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Dark/Tinted der Alternativen auf Hardware | Nicht geprüft |


## Showers Build 20: Upload angenommen (Xcode 27.1), neues Standard-Symbol

Quellencheckpoint `3cf089f` (`CURRENT_PROJECT_VERSION = 20`), Archiv/Export aus `git archive`-Kopie (unter `/private/tmp`) mit Xcode 27.1 per `DEVELOPER_DIR`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher 6.11.2026 (iPhone-18-Pro-Simulator, Xcode 27.2): `WeatherTests` 416 Tests, `WeatherUITests` 9 Tests, 0 Fehler; `testTimelineAtMaximumDynamicTypeKeepsControlsSeparate` einzeln wiederholt: grün. Optionen wie Build 19.

Hinweis: Der erste lokale Export scheiterte mit `Copy failed` (Exit 70), weil `xcodebuild` das Homebrew-`rsync` (`/opt/homebrew/bin`) statt `/usr/bin/rsync` fand (`--extended-attributes: unknown option`). Abhilfe: `PATH=/usr/bin:/bin:/usr/sbin:/sbin` setzen; danach Export erfolgreich.

**Genau ein Upload, 6. November 2026 von 08:57:36 bis 09:00:49 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `37af226cb38819c1df9859c92823aba3eb4a87f2278d4e37d1001e69493f2539`): vier Bundles, `CFBundleDisplayName` überall `Showers`, `CFBundleVersion` überall 20, `codesign --verify --deep --strict` je Bundle ok; `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, App Group `group.de.linolaske.showernow`; keine `.md` im Paket. App-`Info.plist`: je 20 `CFBundleAlternateIcons` in `CFBundleIcons` und `CFBundleIcons~ipad`, primär `AppIcon`; `Assets.car` enthält `AltNachtradar`.

**Paketgröße:** IPA Build 20 114.203.666 Byte (Build 19: 107.082.362). App-Store-Downloadgröße nicht gemessen.

| Zustand Build 20 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Darstellung des neuen Standard-Symbols auf Hardware (Default/Dark/Tinted) | Nicht geprüft |


## Showers Build 21: Upload angenommen (Xcode 27.1), neues Symbol einziges Symbol

Quellencheckpoint `db12a49` (`CURRENT_PROJECT_VERSION = 21`, Inhalt = `5a5fc06` ohne Alternativ-Icons), Archiv/Export aus `git archive`-Kopie (unter `/private/tmp`) mit Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin` (rsync-Workaround), Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher 6.11.2026 (iPhone-18-Pro-Simulator, Xcode 27.2): `WeatherTests` 410 Tests, `WeatherUITests` 7 Tests, 0 Fehler (kein flaky Fehlschlag). Optionen wie Build 20.

**Genau ein Upload, 6. November 2026 von 09:37:31 bis 09:39:57 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `747a3d084e09003589fac13ddd08a4ccba0377caa4c43ec6a4e7ec1165c297cf`, 9.717.002 Byte; Build 20: 114.203.666): vier Bundles mit `CFBundleVersion` 21, `codesign --verify --deep --strict` je Bundle ok; keine `CFBundleAlternateIcons`, kein `AltNachtradar` in `Assets.car`; `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, App Group `group.de.linolaske.showernow`; keine `.md` im Paket.

| Zustand Build 21 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät, Darstellung des Symbols auf Hardware (Default/Dark/Tinted) | Nicht geprüft |


## Showers Build 22: Upload angenommen (Xcode 27.1), WP14 Geräte-Opt-in

Quellencheckpoint `a749644` (`CURRENT_PROJECT_VERSION = 22`, enthält WP14 `feef966`), Archiv/Export aus `git archive`-Kopie (`/private/tmp/showers-b22`) mit Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, Automatic Signing mit `-allowProvisioningUpdates`, Team `J2DU2P47XW`. Vorher 6.11.2026 (iPhone-18-Pro-Simulator, Xcode 27.2, `CODE_SIGNING_ALLOWED=NO`): `WeatherTests` 445 Tests, `WeatherUITests` 8 Tests, 0 Fehler (kein flaky Fehlschlag). Optionen wie Build 21.

**Genau ein Upload, 6. November 2026 von 15:53:43 bis 15:56:11 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `41bd0dd07c5aef514288421beb82bed53b4647bd692890c54e762c6ad9143c42`, 9.808.659 Byte): vier Bundles mit `CFBundleVersion` 22, `codesign --verify --deep --strict` je Bundle ok; keine `CFBundleAlternateIcons`; `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, App Group `group.de.linolaske.showernow`; `DEVICE_LINK_*` in `de.lproj` und `en.lproj` enthalten; `-UITestBuildChannel` nicht im Release-Binary (strings/grep: 0 Treffer); keine `.md` im Paket.

| Zustand Build 22 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft; keiner Gruppe zugeordnet, nicht eingereicht |
| Gerät: Positivfall der Kopplung (Code anzeigen, im Dashboard einlösen), TestFlight meldet `Sandbox` (Spike V1) | Nicht geprüft, nur am TestFlight-Gerät möglich |

## Showers Build 23 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint `898fc88` (`MARKETING_VERSION = 0.1.1`, `CURRENT_PROJECT_VERSION = 23` in `Configuration/Base.xcconfig`, gilt für alle vier Targets; keine hartkodierten Versionstexte gefunden). Verfahren wie Build 22 (`git archive`-Kopie `/private/tmp/showers-b23`, Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, Automatic Signing, Team `J2DU2P47XW`). Vorher 6.11.2026 (iPhone-18-Pro-Simulator, `CODE_SIGNING_ALLOWED=NO`): `WeatherTests` 445, `WeatherUITests` 8 Tests, 0 Fehler (kein flaky Fehlschlag).

**Genau ein Upload, 6. November 2026 von 16:09:23 bis 16:13:16 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry; keine Validierungsfehler durch die Versionsänderung.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `d8095794bd1a3045aea9b7f54d4c3f28f2e23f51a3d7ddf87c7532e86f2ffe40`, 9.808.669 Byte): vier Bundles mit `CFBundleShortVersionString` 0.1.1 und `CFBundleVersion` 23; `codesign --verify --deep --strict` je Bundle ok; keine `CFBundleAlternateIcons`; `aps-environment=production`, `time-sensitive`, `get-task-allow=false`, App Group `group.de.linolaske.showernow`; `-UITestBuildChannel` im Paket 0 Treffer; keine `.md`.

Hinweis: Die neue Version 0.1.1 beginnt einen neuen Versions-Zug in TestFlight; die App-Store-Version muss in App Store Connect separat angelegt werden.

| Zustand Build 23 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 24 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint `bd3199f` (`CURRENT_PROJECT_VERSION = 24`, Basis `df408dd`: Kopplungsfenster-Modell `de96f8f`, Info-Sheet mit Unterseiten). Verfahren wie Build 23 (`git archive`-Kopie `/private/tmp/showers-b24`, Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, Automatic Signing, Team `J2DU2P47XW`). Vorher 6.11.2026 (iPhone-18-Pro-Simulator, `CODE_SIGNING_ALLOWED=NO`): Volllauf 442 Unit + 10 UI-Tests, dabei 1 Fehlschlag in `ForecastResilienceTests.testPlaceSwitchShowsMatchingEntryAndNeverForeignForecast` (Test und `Shared` seit Build 23 unverändert, vermutlich zeitabhängig flaky, Ursache nicht untersucht); danach 3x einzeln und 2x `WeatherTests` komplett (442) grün, UI-Tests im Volllauf 10 grün.

**Genau ein Upload, 6. November 2026 von 18:28:26 bis 18:30:33 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry.

Paketprüfung (lokale IPA aus demselben Archiv, SHA-256 `feea0742334ad294c437661e5d49de3ac952d17da64c3a214848113ddbdfcb1f`, 9.837.065 Byte): vier Bundles mit `CFBundleShortVersionString` 0.1.1 und `CFBundleVersion` 24; `codesign --verify --deep --strict` je Bundle ok; `aps-environment=production`, `time-sensitive=true`, `get-task-allow=false`, App Group `group.de.linolaske.showernow`; keine `.md`, keine `CFBundleAlternateIcons`; `-UITestBuildChannel`, `-UITestDeviceLinkWindow` und `AppTransaction` im Paket je 0 Treffer; `INFO_*` (8 Schlüssel) und `DEVICE_LINK_*` (18) in `de.lproj` und `en.lproj` enthalten.

| Zustand Build 24 | Beleg |
|---|---|
| Archiv und lokale IPA | Erfolgreich, geprüft |
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |
| Gerät: Kopplungsfenster-Verhalten auf TestFlight-Gerät | Nicht geprüft |

## Showers Build 26 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 26“ (`CURRENT_PROJECT_VERSION = 26`, Basis `5ef03f3`). Verfahren wie Build 25 (`git archive`-Kopie `/private/tmp/showers-b26`, Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, Automatic Signing, Team `J2DU2P47XW`). Vorher 6.11.2026 (iPhone-18-Pro-Simulator, `CODE_SIGNING_ALLOWED=NO`): `WeatherTests` grün.

**Genau ein Upload, 6. November 2026 von 21:10:10 bis 21:12:29 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 26 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |


## Showers Build 27 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 27“ (`2ec8239`, `CURRENT_PROJECT_VERSION = 27`). Verfahren wie Build 26 (`git archive`-Kopie `/private/tmp/showers-b27`, Xcode 27.1 per `DEVELOPER_DIR`, `PATH=/usr/bin:/bin:/usr/sbin:/sbin`, Automatic Signing, Team `J2DU2P47XW`). Tests (450 Unit, 13 UI) zuvor auf dem Inhaltsstand grün.

**Genau ein Upload, 6. November 2026 von 21:31:48 bis 21:33:52 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 27 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |


## Showers Build 28 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 28“ (`4902dbd`, Basis `9dc940a`). Verfahren wie Build 27 (`git archive`-Kopie `/private/tmp/showers-b28`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Tests (451 Unit, 13 UI) zuvor auf `9dc940a` grün.

**Genau ein Upload, 7. November 2026 von 00:10:22 bis 00:12:21 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 28 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 29 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 29“ (`d0cf060`, Basis `70dc2bd`). Verfahren wie Build 28 (`git archive`-Kopie `/private/tmp/showers-b29`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`, Optionen wie Build 28). Inhalt: Uhrzeit beim Scrubben nur noch einmal sichtbar (Bubble), feste Zeile ausgeblendet mit reserviertem Platz. Tests (451 Unit, 13 UI) zuvor auf `70dc2bd` grün.

**Genau ein Upload, 7. November 2026 von 00:27:33 bis 00:30:06 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Verarbeitung / Installierbarkeit / Zuordnung und lokale IPA-Paketprüfung nicht geprüft.

## Showers Build 30 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 30“ (`1252e34`, Basis `0557ede`). Verfahren wie Build 29 (`git archive`-Kopie `/private/tmp/showers-b30`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Archiv `CFBundleVersion` 30 vor Upload geprüft. Inhalt: Stufe „Sehr leicht“ (Klasse 1); „Jetzt“-Button und Scrub-Bubble entfernt, Zeit dauerhaft als tippbare Zeile über dem Regler; Glow Vergangenheit sehr dezent, Zukunft dynamischer mit mehr Farbtönen. Tests (452 Unit, 13 UI) zuvor auf `0557ede` grün.

**Genau ein Upload, 7. November 2026 von 01:03:20 bis 01:05:04 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 30 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 31 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 31“ (`6552d1a`, Basis `9f0e1e1`). Verfahren wie Build 30 (`git archive`-Kopie `/private/tmp/showers-b31`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Archiv `CFBundleVersion` 31 in allen vier Bundles (App, Watch, Widget, Watch-Widget) vor Upload geprüft. Inhalt: Live Activity für Gebiets-Abos (Schalter erscheint nur, wenn der Server `live_activity_regions` meldet, also erst nach Backend-Deploy sha-9f47e32); Punkt vor Gebiet; Widget mit „x % der Fläche nass“ + Stärkste Stufe. Tests (478 Unit, 13 UI) zuvor auf `ff2b714` grün.

**Genau ein Upload, 7. November 2026 von 01:46:06 bis 01:48:14 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 31 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 32 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 32“ (`323f35d`, Basis `9fb9fcd`). Verfahren wie Build 31 (`git archive`-Kopie `/private/tmp/showers-b32`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`, `-allowProvisioningUpdates` legte das Profil der neuen Extension `de.linolaske.showernow.notificationservice` an). Archiv `CFBundleVersion` 32 in allen fünf Bundles; Extension eingebettet, Signatur ok. Inhalt: Notification Service Extension (Ort im Regen-Push).

**Genau ein Upload, 7. November 2026 von 10:32 bis 10:34 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, letzter Serverzustand `Uploaded package is processing`. Kein Retry. Lokale IPA-Paketprüfung nicht ausgeführt.

| Zustand Build 32 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 33 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: `b29be64` (Privacy Manifests in allen fünf Targets, `CURRENT_PROJECT_VERSION = 33`). Verfahren wie Build 32 (`git archive`-Kopie `/private/tmp/showers-b33`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Vorab lokaler Export (`destination=export`) und IPA-Prüfung: CFBundleVersion 33 und `PrivacyInfo.xcprivacy` in allen fünf Bundles, `aps-environment=production` in der App, `codesign --verify --deep --strict` ok.

**Genau ein Upload, 7. November 2026 von 12:55 bis 12:58 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`, `Uploaded package is processing`. Kein Retry.

| Zustand Build 33 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 35 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 35“ (`f34b36b`, `CURRENT_PROJECT_VERSION = 35`; Inhalt gegenüber Build 34: Anzeige der Installationskennung im Info-Sheet unter Mitteilungen, `f45cfe8`/`c0be7e4`). Verfahren wie Build 33/34 (`git archive`-Kopie `/private/tmp/showers-b35`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Vorab lokaler Export (`destination=export`) und IPA-Prüfung: CFBundleVersion 35 und `PrivacyInfo.xcprivacy` in allen fünf Bundles, `aps-environment=production` in der App, `codesign --verify --deep --strict` ok.

**Genau ein Upload, 7. November 2026 von 15:49 bis 15:51 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`. Kein Retry.

| Zustand Build 35 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |

## Showers Build 36 (0.1.1): Upload angenommen (Xcode 27.1)

Quellencheckpoint: Commit „chore: Buildnummer 36“ (`c6f2ba8`, `CURRENT_PROJECT_VERSION = 36`; Inhalt gegenüber Build 35: Warnungen W3 bis W6, Installationskennung; Warn-Push bleibt serverseitig aus). Verfahren wie Build 35 (`git archive`-Kopie `/private/tmp/showers-b36`, Xcode 27.1 per `DEVELOPER_DIR`, PATH-Workaround, Automatic Signing, Team `J2DU2P47XW`). Vorab: `Weather`-Schema 569 Unit- und 22 UI-Tests, 0 Fehler; lokaler Export (`destination=export`) und IPA-Prüfung: CFBundleVersion 36 und `PrivacyInfo.xcprivacy` in allen fünf Bundles, `aps-environment=production` in der App, `codesign --verify --deep --strict` je Bundle ok, `WarnGeometry.bin` im App-Bundle, `WARN_PUSH_*` in de/en.

**Genau ein Upload, 7. November 2026 von 16:43 bis 16:46 Uhr:** Exit 0, `EXPORT SUCCEEDED`, `Upload succeeded`. Kein Retry.

| Zustand Build 36 | Beleg |
|---|---|
| Uploadannahme | Erfolgreich, Exit 0 (erster Versuch) |
| Verarbeitung / Installierbarkeit / Zuordnung | Nicht geprüft |
