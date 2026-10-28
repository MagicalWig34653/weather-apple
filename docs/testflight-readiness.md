# Readiness: erster interner iPhone-TestFlight-Build

Stand: 28. Oktober 2026. Aktualisiert nach dem ersten abgewiesenen Upload und dem gezielten Packaging-Fix für Build `2`. Ursprünglicher Serverbefund in [testflight-upload.md](testflight-upload.md); keine Portaländerungen oder zusätzlichen Compliance-Antworten.

## Aktuelle Einordnung

Der erste iPhone-Prototyp ist ein sinnvoller Kandidat für einen frühen internen Alltagstest, nach abgeschlossener QA, Radar-Icon-Integration und unabhängigem Release-Review. Er ist keine vollständige v1. Der Nutzer hat den App-Store-Connect-App-Eintrag selbst angelegt. Explizite Bundle-ID und lokaler Distributionsweg sind in [signing.md](signing.md) belegt; daraus folgt noch kein erfolgreicher Upload.

| Schritt | Stand bei dieser Prüfung | Vor dem ersten internen Build |
|---|---|---|
| App-Eintrag, Bundle-ID und Team | Vom Nutzer angelegt; spezifisches Profil bestätigt | Im aktuellen Radar-Archiv und Export bestätigt |
| Bedienabläufe und Refresh-Fixes | Zwölf Datentests, Info-Smoke und abschließender CRUD-Rerun grün; unabhängiges Review ohne offene P1/P2 | Unabhängiges Release-Review ohne offene P1/P2 oder erkannte Uploadblocker abgeschlossen |
| App-Icon | Gewähltes Radar-`.icon` als einziges natives AppIcon integriert; Archiv-/Export-Assets und PNG geprüft | Homescreen auf physischem iPhone prüfen; Simulator-GUI nicht gesichtet |
| Version/Buildnummer | Neuer Kandidat `0.1.0` / `2`; Build `1` wurde serverseitig abgelehnt | Nur neues Archiv verwenden; neuer Upload bleibt offen |
| Export-Compliance | `ITSAppUsesNonExemptEncryption=false` begründet gesetzt und Plist geprüft | Bei Änderungen an Kryptografie/SDKs erneut bewerten |
| Neues Release-Archiv | Build `2` nach Packaging-Fix erfolgreich archiviert/lokal exportiert; IPA-Metadaten, Signaturen und explizites Profil geprüft | Frischer unabhängiger Quellen-/Metadatencheckpoint erfolgreich; separater Upload und Servervalidierung offen |
| Servervalidierung und Verarbeitung | Build `1`: Apple `90474`, fehlendes PortraitUpsideDown für iPad-Multitasking; keine abgeschlossene Verarbeitung | Build `2` nach Quellencheckpoint separat hochladen; Annahme und Verarbeitung getrennt belegen |
| Interne Gruppe/Tester | Nicht geprüft | Berechtigte App-Store-Connect-Nutzer und Build-Zuordnung prüfen |

Apple nennt das App-Icon ausdrücklich als Bestandteil der Uploadvalidierung. Icon Composer ist dafür ein unterstützter Weg; eine bloß im Repo liegende, nicht im Target verwendete Datei genügt nicht. [Vorbereitung der Distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html), [App-Icon in App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/).

## Unterstützter Uploadweg ohne neuen API-Schlüssel

Der bereits erfolgreich signierte lokale Export belegt einen brauchbaren Xcode-Account-/Signing-Zugang. Apples Uploaddokumentation erlaubt Xcode als Uploadwerkzeug; ein zusätzlicher App-Store-Connect-API-Schlüssel ist dafür nicht grundsätzlich nötig. Der erste tatsächliche Versuch erreichte App-Abfrage (HTTP 200), Transport und Apple-Servervalidierung ohne Authentifizierungsfehler; er scheiterte am Bundle mit `90474`, nicht am Login. Ein fehlender separater API-Schlüssel ist allein kein Blocker. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

Die lokale Hilfe des installierten `xcodebuild` bestätigt:

- `destination=upload` anstelle des bisher verwendeten `destination=export`.
- `method=app-store-connect`, automatische Signierung und `-allowProvisioningUpdates`.
- `testFlightInternalTestingOnly=true` für einen absichtlich nur intern verteilbaren Build. Dieser konkrete Build kann anschließend nicht extern oder im App Store verteilt werden; spätere Builds können anders konfiguriert werden.

Vorgeschlagene Exportoptionen für einen nach QA freigegebenen internen Build:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>signingStyle</key><string>automatic</string>
    <key>teamID</key><string>J2DU2P47XW</string>
    <key>manageAppVersionAndBuildNumber</key><false/>
    <key>testFlightInternalTestingOnly</key><true/>
    <key>uploadSymbols</key><true/>
    <key>stripSwiftSymbols</key><true/>
</dict></plist>
```

Späterer ausführender Release-Agent nutzt eigene lokale Archiv-/Exportpfade und den abgestimmten Buildslot. Das folgende Kommando ist eine Vorbereitung, kein bereits ausgeführter Upload:

```sh
xcodebuild -exportArchive \
  -archivePath "$WEATHER_ARCHIVE_PATH" \
  -exportPath "$WEATHER_EXPORT_PATH" \
  -exportOptionsPlist "$WEATHER_EXPORT_OPTIONS_PATH" \
  -allowProvisioningUpdates
```

Der Uploadauftrag darf keinen neuen App-Datensatz anlegen, keine unbekannten Kontodaten auslesen und keine Zugangsdaten im Repo speichern. Bei einem realen Authentifizierungs- oder Rollenfehler dessen konkrete Ursache melden, statt weitere Zugangsmethoden blind zu probieren. Verarbeitung, mögliche Apple-Rückmeldungen und anschließende Build-Zuordnung sind getrennte Zustände. [Apple: Beta-Distribution mit Xcode](https://developer.apple.com/documentation/xcode/distributing-your-app-for-beta-testing-and-releases).

## Export-Compliance: konkrete Codeevidenz statt pauschaler Antwort

Geprüfter Code verwendet HTTPS über Apples `URLSession`, Apple-Karten-/Standortdienste und den systemeigenen Dateischutz für lokale Orte. Es gibt keine externen Swift-Pakete, eigene Kryptografie, CryptoKit-, CommonCrypto- oder Security-Schlüsselimplementierung im aktuellen App-Code. Der Klartext-HTTP-Verweis im Plist-DOCTYPE ist keine Netzwerkverbindung der App.

Apples aktuelle Dokumentation nennt Betriebssystemverschlüsselung, insbesondere HTTPS mit `URLSession`, typischerweise als von der Dokumentationspflicht ausgenommen. `ITSAppUsesNonExemptEncryption=false` bedeutet **keine nicht ausgenommene Verschlüsselung**, nicht „keine Verschlüsselung“. Für den tatsächlich geprüften aktuellen Code ist dieser Wert deshalb technisch begründet; der Schlüssel wurde anschließend mit dieser Quelle ergänzt und die Plist syntaktisch geprüft. Bei späteren Kryptografie-/SDK-Änderungen erneut prüfen. Die Ergänzung erfolgte in einem getrennten Konfigurationsschritt; keine Portalfragen wurden beantwortet. [Apple: Complying with Encryption Export Regulations](https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations), [Bedeutung des Schlüssels](https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption).

Datenschutz-/Required-Reason-Angaben ebenfalls nicht aus einem Muster ungeprüft übernehmen. Die Standort-Nutzungsbeschreibung ist vorhanden. Es sind keine Werbe-/Analyse-SDKs oder eigene Trackingdomänen eingebunden. Beim finalen Archiv den Xcode-Privacybericht und mögliche konkrete Hinweise prüfen; keine vorsorglich erfundenen API-Gründe deklarieren. [Apple: Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files), [Required Reason APIs](https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api).

## Interne Tester und tatsächliche Freigabe

Interne Tester sind App-Store-Connect-Nutzer mit Zugriff auf die App. Der Vater ist daher nur dann ein interner Tester, wenn diese Voraussetzung erfüllt ist. Ein normaler TestFlight-Nutzer ohne diesen Kontozugriff gehört zur externen Testgruppe; für diesen Weg gelten zusätzliche Angaben und Beta-Review. Nicht ungefragt Benutzer anlegen oder Einladungen versenden. Der erste Auftrag bleibt interne Verteilung. [Apple: Add internal testers](https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers/), [zusätzliche Testinformationen für externe Tests](https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information/).

Nach erfolgreicher Verarbeitung muss der konkrete Build der internen Gruppe zugeordnet und eine knappe Testanleitung hinterlegt werden. Geeigneter Inhalt: Radar/Zeitleiste, Ort wählen/speichern/umbenennen/löschen, Netzfehler/Retry und Datenalter im Alltag prüfen. Keine privaten Koordinaten in öffentliche Fehlerberichte schreiben. Die physische iPhone-Prüfung kann gerade mit diesem ersten internen Build erfolgen; ein vorgeschalteter öffentlicher App-Store-Release ist dafür nicht nötig.

## Bekannte Prototypgrenzen, keine künstlichen Erstbuild-Blocker

Gelegentliche transparent gemeldete Kachelfehler, breitere NoData-/Zellrandfalltests, Energie-/Cachemessungen und präzisere Regenendeformulierungen bleiben Qualitätsarbeit. Der korrigierte Retry und der Kernablauf müssen vor Upload funktionieren; verbleibende Grenzen gehören in die Testhinweise. Widgets, Watch, angepasste iPad-/Mac-Oberflächen, Backend und automatische Regenwarnungen sind keine Voraussetzung dieses ersten internen iPhone-Builds.

Die vorläufige Identität ist ausdrücklich auch für TestFlight freigegeben. Wichtig für die geplante spätere Umbenennung: Nach dem ersten Upload lässt sich die Bundle-ID im bestehenden App-Store-Connect-Eintrag nicht einfach austauschen. Eine andere Bundle-ID verlangt einen entsprechend neuen App-Eintrag; Displayname und endgültige Markenentscheidung sind davon zu unterscheiden. [Apple: Distribution vorbereiten](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html).

## Konkreter nächster Auftrag

Build `1` wurde wegen unvollständiger iPad-Orientierungen abgelehnt. Der minimale Fix erhält die tatsächlich konfigurierte Gerätefamilie `1,2`, ergänzt `UISupportedInterfaceOrientations~ipad` vollständig und erhöht die Buildnummer auf `2`. Der Projektwert `TARGETED_DEVICE_FAMILY=1` wurde im generierten Projekt durch XcodeGen-Targetdefaults `1,2` überschrieben; kein Gerätefamilienwechsel oder `UIRequiresFullScreen` zur Validierungsumgehung.

Neues Release-Archiv und lokaler `destination=export`-Export mit Automatic Signing sind erfolgreich. Assertions an der tatsächlichen IPA bestätigen `0.1.0 (2)`, `UIDeviceFamily=[1,2]`, alle vier iPad-Orientierungen, unveränderte drei iPhone-Orientierungen, Compliance `false` und `CFBundleIconName=AppIcon` für beide Gerätefamilien; native Assets enthalten IconImageStack/IconGroup. Archiv-/IPA-App bestehen `codesign --verify --deep --strict`. Das Distributionsprofil enthält die explizite ID `J2DU2P47XW.de.linolaske.weather`, `get-task-allow=false` und keine Geräteliste. Quellenkopiegleichheit und `plutil` geprüft; keine volle Unit-/UI-Suite für den reinen Packaging-Fix wiederholt. iPad-kompatible Metadaten, auf iPhone validierter Prototyp; keine eigenständige iPad-Freigabe.

Der frische unabhängige Checkpoint bestätigt zusätzlich die IPA-Prüfsumme und bytegleiche `Info.plist`/`Base.xcconfig` zur Archivquellenkopie; keine offenen P1/P2 im begrenzten Konfigurationsreview. Keine Builds, Exporte oder Tests dafür wiederholt.

Nach Veröffentlichung des neuen Quellencheckpoints führt ein separater Release-Agent den autorisierten internen Upload mit dem neuen Archiv `0.1.0 (2)` aus. „Upload angenommen“, „Verarbeitung abgeschlossen“ und „für interne Gruppe verfügbar“ bleiben getrennt zu belegen. Lokaler Export ist keine Apple-Serverfreigabe.
