# Readiness: erster interner iPhone-TestFlight-Build

Stand: 28. Oktober 2026. Begrenzte Quellen-/Konfigurationsprüfung; keine Builds, Uploads, Portaländerungen oder Compliance-Antworten durch diesen Readiness-Auftrag.

## Aktuelle Einordnung

Der erste iPhone-Prototyp ist ein sinnvoller Kandidat für einen frühen internen Alltagstest, sobald die laufende QA und Icon-Integration abgeschlossen sind. Er ist keine vollständige v1. Der Nutzer hat den App-Store-Connect-App-Eintrag selbst angelegt. Explizite Bundle-ID und lokaler Distributionsweg sind in [signing.md](signing.md) belegt; daraus folgt noch kein erfolgreicher Upload.

| Schritt | Stand bei dieser Prüfung | Vor dem ersten internen Build |
|---|---|---|
| App-Eintrag, Bundle-ID und Team | Vom Nutzer angelegt; spezifisches Profil bestätigt | Im neuen Archiv dieselbe ID und dasselbe Team prüfen |
| Bedienabläufe und Refresh-Fixes | Zwölf Datentests, Info-Smoke und abschließender CRUD-Rerun grün; unabhängiges Review ohne offene P1/P2 | Finale Icon-/Release-Integration prüfen |
| App-Icon | Eigener Icon-Composer-Auftrag läuft | Finales `.icon` im App-Target integrieren, generiertes Icon im Release-Archiv prüfen |
| Version/Buildnummer | Konfiguration `0.1.0` / `1` | Eindeutigkeit für den ersten Upload prüfen; spätere Uploads kontrolliert erhöhen |
| Export-Compliance | `ITSAppUsesNonExemptEncryption=false` begründet gesetzt und Plist geprüft | Bei Änderungen an Kryptografie/SDKs erneut bewerten |
| Neues Release-Archiv | Bisheriger Export liegt vor späteren QA-/Icon-Änderungen | Den tatsächlich freizugebenden finalen Stand neu archivieren |
| Servervalidierung und Verarbeitung | Noch nicht ausgeführt | Tatsächliches Upload-/Verarbeitungsergebnis dokumentieren |
| Interne Gruppe/Tester | Nicht geprüft | Berechtigte App-Store-Connect-Nutzer und Build-Zuordnung prüfen |

Apple nennt das App-Icon ausdrücklich als Bestandteil der Uploadvalidierung. Icon Composer ist dafür ein unterstützter Weg; eine bloß im Repo liegende, nicht im Target verwendete Datei genügt nicht. [Vorbereitung der Distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html), [App-Icon in App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/).

## Unterstützter Uploadweg ohne neuen API-Schlüssel

Der bereits erfolgreich signierte lokale Export belegt einen brauchbaren Xcode-Account-/Signing-Zugang. Apples Uploaddokumentation erlaubt Xcode als Uploadwerkzeug; ein zusätzlicher App-Store-Connect-API-Schlüssel ist dafür nicht grundsätzlich nötig. Ob der vorhandene Account auch diesen konkreten Upload mit passenden Rollen ausführen kann, ist erst durch den tatsächlichen Upload bestätigt. Ein fehlender separater API-Schlüssel ist allein kein Blocker. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

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

Nach grünem CRUD-/Integrationsstand und fertig integriertem Icon einen frischen Release-Agent einsetzen: gesetzten Compliance-Schlüssel im finalen Archiv prüfen, eindeutige Buildnummer bestätigen, finalen Stand archivieren, Icon/Signatur/Identität prüfen und den autorisierten internen Upload ausführen. Ergebnis als „Upload angenommen“, „Verarbeitung abgeschlossen“ und „für interne Gruppe verfügbar“ getrennt belegen. Falls nur der letzte Portal-/Gruppenschritt nicht zugänglich ist, genau diesen verbleibenden Nutzer-Schritt nennen; lokalen Export nicht als TestFlight-Erfolg ausgeben.
