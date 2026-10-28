# Apple-Signing und Bundle-ID

Stand: 28. Oktober 2026. Aktueller geprüfter Release-Kandidat ist **ShowerNow `0.1.0 (4)`**, **`de.linolaske.showernow`**, Team **`J2DU2P47XW`**, aus veröffentlichtem Quellencheckpoint `6750d0e954de900cb8bcf6f52b3faf1fc2d769d9`. Signiertes Release-Archiv und lokaler Export erfolgreich. Genau ein interner Upload wurde um 18:17:29 Uhr MEZ mit Exit 0 angenommen; letzter Serverstand `PROCESSING`, Build-4-TestFlight-Verfügbarkeit noch offen. Build 3 ist inzwischen durch den Nutzer als intern über TestFlight nutzbar bestätigt. Historische Build-3-Nachweise bleiben unten erhalten.

## Build 4: geprüfte tatsächliche Artefakte

`ARCHIVE SUCCEEDED` und lokales `EXPORT SUCCEEDED`. Archiv und tatsächliche IPA bestätigen beide Namensfelder ShowerNow, Bundle-ID `de.linolaske.showernow`, Version `0.1.0`, Build `4`, Familie `[1,2]`, drei iPhone-/vier iPad-Orientierungen, Compliance `false` und AppIcon für beide Familien. Native Assets enthalten IconImageStack und IconGroup. Beide Apps bestehen `codesign --verify --deep --strict`.

Das tatsächliche IPA-Profil bestätigt `J2DU2P47XW.de.linolaske.showernow`, Team `J2DU2P47XW`, `get-task-allow=false` und keine Geräteliste. IPA-SHA-256: `ec9d4acf35684e7f7aed1d5561f1fa7f97fbc0354ce2586573d50d5fb46ccc28`. Alle 24 Projekt-/Konfigurations-/App-/Test-/Ressourcendateien der isolierten Archivkopie sind bytegleich zum veröffentlichten Quellencheckpoint `6750d0e`. Keine Tests wiederholt; bestehende 26 Tests, UI-Prüfungen und unabhängiges Review gelten für unveränderten Code. Keine neue physische Prüfung oder echte Modellgeneration.

## Aktueller Nachweis und klare Grenzen

Der Simulatorbuild bestätigt neue Bundle-ID, Displayname und Version/Build. Ein Projektsetting oder altes Weather-Profil belegt keine neue explizite ID. Für die neue Identität ist der spezifische `application-identifier` `J2DU2P47XW.de.linolaske.showernow` im tatsächlichen Distributionsprofil maßgeblich. Der lokale `app-store-connect`-Export ist erfolgreich; das tatsächlich eingebettete Profil bestätigt genau diesen expliziten Identifier und Team `J2DU2P47XW`, `get-task-allow=false`, ohne `ProvisionedDevices`. Die neue explizite ID wurde sofort dem Lead gemeldet. Ein bestehender ASC-App-Datensatz war für den lokalen Export nicht erforderlich.

Das nach dem gezielten Bundle-Name-Fix neu erzeugte Release-Archiv (`ARCHIVE SUCCEEDED`) und der lokale Export (`EXPORT SUCCEEDED`) bestätigen in der tatsächlichen IPA **`CFBundleName=ShowerNow` und `CFBundleDisplayName=ShowerNow`**, `de.linolaske.showernow`, `0.1.0 (3)`, `UIDeviceFamily=[1,2]`, vier iPad-/drei iPhone-Orientierungen, Compliance `false` und `CFBundleIconName=AppIcon` für beide Familien; native Assets enthalten IconImageStack und IconGroup. Beide Apps bestehen `codesign --verify --deep --strict`. Alle 24 kopierten App-/Test-/Projekt-/Konfigurationsdateien stimmen bytegleich mit der isolierten Archivquellenkopie überein. Das Development-Wildcardprofil im Archiv ist vom expliziten Distributionsprofil der IPA zu unterscheiden und kein Fehler. Bei diesem lokalen Metadatennachweis kein Upload, keine volle Unit-/UI-Suite und keine neue physische/HomeScreen-Prüfung ausgeführt. Der nachfolgende Upload ist separat belegt. IPA-SHA-256: `07a33550538cd9dadbed6ff61f2d0677d78ef47365303f69a992d6ebb32f9215`.

## ASC-Zuständigkeit und historische Identität

Der Nutzer hat bestätigt, seinen ASC-App-Datensatz auf `de.linolaske.showernow` umgestellt zu haben. Zusätzlich bestätigen die offiziellen AppsService-Antwortdaten beim Build-3-Upload `name=ShowerNow`, `bundleId=de.linolaske.showernow`, `removed=false`; eine direkte Portalabfrage wurde nicht vorgenommen. Ein neuer Datensatz wird deshalb nicht weiter als offener Blocker geführt. Apples allgemeine Einschränkung gilt bedingt: Sobald für einen konkreten ASC-Datensatz bereits ein Build hochgeladen wurde, ist dessen Bundle-ID nicht mehr editierbar. Daraus wird keine gegenteilige Aussage über die vom Nutzer beobachtete Umstellung abgeleitet. [ASC-App-Informationen](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), geprüft am 28. Oktober 2026.

Die Namensfelder sind getrennt: ASC **Name** ist die Store-Metadatenangabe und muss Apples Anforderung eines eindeutigen App-Namens erfüllen; `CFBundleDisplayName` bezeichnet den Gerätenamen, `CFBundleName` den kurzen, ebenfalls potenziell sichtbaren Bundle-Namen. Die bisherige tatsächliche IPA hatte Displayname ShowerNow, aber Bundle-Name Weather. Der gezielte Plist-Fix bindet nun beide Namen an `WEATHER_DISPLAY_NAME`; Executable, Produktname und Swift-Modul bleiben Weather. Der lokale Fix allein belegt keine ASC-Namensverfügbarkeit. Im nachfolgenden Build-3-Upload ist der passende ASC-Name durch Antwortdaten belegt; kein Namenskonflikt- oder Bundle-Validierungsfehler trat auf. [Apple: App Review 2.3.7](https://developer.apple.com/app-store/review/guidelines/#accurate-metadata), [Bundle-Namen](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/CoreFoundationKeys.html), [Geräte-/Store-Namen](https://developer.apple.com/library/archive/qa/qa1892/_index.html), geprüft am 28. Oktober 2026.

Historisch belegt ist das explizite alte Profil `J2DU2P47XW.de.linolaske.weather`. Build `0.1.0 (1)` wurde mit `90474` abgelehnt. Build `0.1.0 (2)` zu `0f48cb5` wurde am 28. Oktober 2026 einmal ohne Transport-/Validierungsfehler angenommen; letzter Serverstatus `PROCESSING`. Zusätzlich berichtet der Nutzer einen Namenskonflikt mit Weather. Dies ist kein Nachweis eines nutzbaren TestFlight-Builds. [Unveränderte Uploadbefunde](testflight-upload.md).

Das bisherige Identity-Review ist ohne offene P1-/P2-Befunde abgeschlossen. Der ergänzende Bundle-Name-Nachweis ist abgeschlossen. Der nachfolgende autorisierte Upload aus Quellencheckpoint `2e500fc` wurde erfolgreich angenommen (Exit 0, `EXPORT SUCCEEDED`, Apple: `UPLOAD SUCCEEDED with no errors`); letzter Zustand `PROCESSING`. [Uploadbefund](testflight-upload.md). Keine Accounts, App-Datensätze, Rollen, Gruppen oder Tester werden in diesem Auftrag geändert. Physische Prüfung danach gemäß [internal-testing.md](internal-testing.md).

## Ausgeführter Weg

Für die signierte Archivierung wurden Release-Konfiguration, Ziel `generic/platform=iOS`, automatische Signierung und `-allowProvisioningUpdates` verwendet. Der lokale Export nutzte folgende Optionen:

```xml
<dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>export</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>J2DU2P47XW</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>uploadSymbols</key><false/>
    <key>stripSwiftSymbols</key><true/>
</dict>
```

Das Beispiel zeigt den Optionsinhalt; für eine Wiederholung in eine vollständige lokale Plist einbetten. Archiv und Export wurden aus einer isolierten temporären Quellenkopie mit ausschließlich relativen Projektverweisen erstellt. Dies umging den zuvor beobachteten `NSFileCoordinator`-Hänger beim Lesen des ursprünglichen Projektordners. Es wurden keine globalen Dienste geändert. Build mit dem Simulator-Verantwortlichen abgestimmt; eigene DerivedData und keine Simulatoränderungen.

Profile, Zertifikate, Signaturschlüssel, IPA, Archive, persönliche Kontodaten und rohe Buildlogs bleiben außerhalb des Repos. Keine Capabilities wurden nur zum Erzwingen einer expliziten ID eingeschaltet, keine Signing-Ressourcen widerrufen und keine Zugangsdaten aus Keychain oder Browser extrahiert. Ein separater API-Schlüssel war für diesen erfolgreichen Buildweg nicht erforderlich.

## Quellen und Aussagegrenzen

- [Apple: Signing & Capabilities workflow](https://help.apple.com/xcode/mac/current/en.lproj/dev60b6fbbc7.html) beschreibt automatische Signing-Verwaltung.
- [Apple: Distribution signing options](https://help.apple.com/xcode/mac/current/en.lproj/devff5ececf8.html) beschreibt automatisch verwaltete Distributionszertifikate und -profile.
- [Apple: Upload an app to App Store Connect](https://help.apple.com/xcode/mac/current/en.lproj/dev442d7f2ca.html) unterscheidet lokalen Export und Upload.
- Die lokale Hilfe von `xcodebuild` bestätigt, dass `-allowProvisioningUpdates` für automatisch signierte Targets App-IDs, Profile und Zertifikate erstellen beziehungsweise aktualisieren kann.

Die Quellen erklären den unterstützten Ablauf. Der konkrete Erfolg dieses Projekts wurde anhand des erzeugten Archivs, Exportergebnisses und eingebetteten Profils festgestellt. Eine direkte App-Store-Connect-Portalabfrage wurde nicht durchgeführt; das aktuelle ASC-Matching ist durch offizielle Upload-Antwortdaten belegt.
