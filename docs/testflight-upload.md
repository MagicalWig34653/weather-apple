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
