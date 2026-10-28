# Readiness: erster interner iPhone-TestFlight-Build

Stand: 28. Oktober 2026. Aktueller Kandidat: **ShowerNow `0.1.0 (3)`**, `de.linolaske.showernow`, Team `J2DU2P47XW`. Neue Nutzerentscheidung ersetzt die vorläufige Weather-Identität. Historische Uploadbefunde bleiben in [testflight-upload.md](testflight-upload.md).

## Aktuelle Einordnung

Der frühe iPhone-Prototyp hat 12 grüne Datentests und 2 grüne UI-Flows aus den bisherigen gezielten QA-Läufen, ein natives Radar-Icon und korrigierte Universal-Metadaten. Diese Testergebnisse stammen vom funktionalen Prototyp. Für die Umbenennung wurden Simulatorbuild und Metadaten geprüft; keine volle Unit-/UI-Suite erneut ausgeführt.

| Schritt | Aktueller Stand | Noch erforderlich |
|---|---|---|
| Produktidentität | ShowerNow / `de.linolaske.showernow`, `0.1.0 (3)` und beide IPA-Namensfelder bestätigt; Identity-Review ohne offene P1/P2 | Kein weiterer Metadatenfix für diesen Upload nötig |
| Bundle-ID/Signing | Neue explizite ID durch tatsächliches spezifisches Distributionsprofil belegt | Nachweis in [signing.md](signing.md); kein zusätzliches Signing-Gate |
| Aktueller ASC-App-Datensatz | Nutzerbestätigung und offizielle AppsService-Antwort: ShowerNow / neue ID / `removed=false` | Kein weiterer neuer Datensatz erforderlich |
| Review/Checkpoint | Aktueller Quellencheckpoint `2e500fc` veröffentlicht; Identity-Review grün | Kein weiterer Quellencheckpoint für diesen Upload nötig |
| Icon/Packaging | Radar-AppIcon, Universal-Familie `[1,2]`, vier iPad-/drei iPhone-Orientierungen bleiben erhalten | Neue IPA-Metadaten/Signaturen und native Assets geprüft; Homescreen auf physischem iPhone prüfen |
| Export-Compliance | Begründetes `ITSAppUsesNonExemptEncryption=false` bleibt erhalten | Bei Kryptografie-/SDK-Änderung erneut bewerten |
| Upload/TestFlight | Genau ein Build-3-Upload erfolgreich angenommen; letzter Zustand `PROCESSING` (17:51:38 Uhr MEZ) | Verarbeitung und interne Verfügbarkeit in ASC prüfen |

Historisch: Build 1 unter `de.linolaske.weather` wurde mit `90474` abgelehnt; Build 2 wurde angenommen (`PROCESSING`). Nutzer meldet zusätzlich Weather-Namenskonflikt. Dies belegt keinen nutzbaren TestFlight-Build.

Apple nennt das App-Icon ausdrücklich als Bestandteil der Uploadvalidierung. Icon Composer ist dafür ein unterstützter Weg; eine bloß im Repo liegende, nicht im Target verwendete Datei genügt nicht. [Vorbereitung der Distribution](https://help.apple.com/xcode/mac/current/en.lproj/dev91fe7130a.html), [App-Icon in App Store Connect](https://developer.apple.com/help/app-store-connect/manage-app-information/add-an-app-icon/).

## Unterstützter Uploadweg ohne neuen API-Schlüssel

Der bereits erfolgreich signierte lokale Export belegt einen brauchbaren Xcode-Account-/Signing-Zugang. Apples Uploaddokumentation erlaubt Xcode als Uploadwerkzeug; ein zusätzlicher App-Store-Connect-API-Schlüssel ist dafür nicht grundsätzlich nötig. Der erste tatsächliche Versuch erreichte App-Abfrage (HTTP 200), Transport und Apple-Servervalidierung ohne Authentifizierungsfehler; er scheiterte am Bundle mit `90474`, nicht am Login. Ein fehlender separater API-Schlüssel ist allein kein Blocker. [Apple: Upload builds](https://developer.apple.com/help/app-store-connect/manage-builds/upload-builds/).

Die lokale Hilfe des installierten `xcodebuild` bestätigt:

- `destination=upload` anstelle des bisher verwendeten `destination=export`.
- `method=app-store-connect`, automatische Signierung und `-allowProvisioningUpdates`.
- `testFlightInternalTestingOnly=true` für einen absichtlich nur intern verteilbaren Build. Dieser konkrete Build kann anschließend nicht extern oder im App Store verteilt werden; spätere Builds können anders konfiguriert werden.

Beim erfolgreichen internen Upload verwendete Exportoptionen:

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

Für künftige Releases nutzt der ausführende Release-Agent eigene lokale Archiv-/Exportpfade und den abgestimmten Buildslot. Das folgende Kommando zeigt den beim dokumentierten Upload verwendeten Weg; lokale Pfade bleiben privat:

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

Der lokale Displayname ShowerNow, `CFBundleName` und das ASC-Feld Name sind getrennt. Apple beschreibt Einschränkungen für die Bundle-ID eines ASC-Eintrags mit bereits zugeordnetem Upload; dies betrifft die historische Einordnung. Der Nutzer bestätigt die geänderte Bundle-ID im aktuellen Connecteintrag; dieser gilt für `de.linolaske.showernow` als bestätigt. Kein weiterer neuer App-Datensatz wird verlangt. Keine direkte Portalabfrage wurde durchgeführt; beim nachfolgenden Build-3-Upload bestätigen die offiziellen AppsService-Antwortdaten den Namen ShowerNow, die neue ID und `removed=false`. [Apple: Bundle-ID ändern](https://developer.apple.com/documentation/xcode/changing-the-bundle-identifier), [ASC-App-Informationen](https://developer.apple.com/help/app-store-connect/reference/app-information/app-information), geprüft am 28. Oktober 2026.

## Konkreter nächster Schritt

Quellencheckpoint `2e500fc`, Identity-/Metadatenreview und genau ein offizieller Build-3-Upload sind abgeschlossen. Der Upload wurde mit Exit 0 und Apples `UPLOAD SUCCEEDED with no errors` angenommen; kein Namenskonflikt-/Validierungsfehler. Letzter Serverzustand am 28. Oktober 2026 um 17:51:38 Uhr MEZ ist `PROCESSING`, siehe [Uploadbefund](testflight-upload.md).

Der Nutzer prüft in App Store Connect **ShowerNow → TestFlight** Build **`0.1.0 (3)`**. Erst wenn Apple ihn als fertig verarbeitet anzeigt, vorhandenen internen Testern zuordnen; diese benötigen ASC-Appzugriff. Keine Gruppen, Tester, Rollen oder Einladungen wurden geändert. Kein weiterer unterstützter authentifizierter Statuszugang verfügbar; kein erneuter Upload erforderlich. Danach [physischer iPhone-Test](internal-testing.md).
