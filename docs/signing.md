# Apple-Signing und Bundle-ID

Stand: 28. Oktober 2026. Tatsächlich ausgeführte lokale Builds; kein Upload und kein App-Store-Connect-App-Datensatz durch Agents.

## Bestätigter aktueller Zustand

- Release-Archivierung mit automatischem Signing und `-allowProvisioningUpdates` erfolgreich (`ARCHIVE SUCCEEDED`).
- Lokaler Export mit Methode `app-store-connect`, `signingStyle=automatic` und ausdrücklich `destination=export` erfolgreich (`EXPORT SUCCEEDED`).
- Exportierte IPA trägt Bundle-ID **`de.linolaske.weather`**.
- Das eingebettete Distributionsprofil enthält **`J2DU2P47XW.de.linolaske.weather` als expliziten `application-identifier`** und bestätigt Team `J2DU2P47XW`.
- Im exportierten Profil ist `get-task-allow=false`; es enthält keine Liste registrierter Testgeräte. Dies entspricht dem geprüften App-Store-Distributionsweg.
- Sowohl Archiv-App als auch exportierte IPA-App bestanden `codesign --verify --deep --strict`.
- Damit ist die explizite App-ID über den Build-/Exportweg nachgewiesen. Der frühere Development-Build verwendete nur `J2DU2P47XW.*`; dieser ältere Wildcard-Befund ist durch den spezifischen Distributionsnachweis ergänzt.

**Die explizite ID ist jetzt belegt; die tatsächliche Sichtbarkeit im Bundle-ID-Auswahlfeld von App Store Connect wurde nicht direkt geprüft.** Dafür war in dieser Umgebung kein authentifizierter Browser-/Portalzugang verfügbar. Der Nutzer kann nun bei der App-Anlage `de.linolaske.weather` auswählen beziehungsweise die Sichtbarkeit prüfen. Keine Auswahlverfügbarkeit allein aus einer Projektdatei oder dem früheren Wildcard-Profil behaupten.

## Zuständigkeit und verbleibende Schritte

1. Nutzer wurde über den erfolgreichen expliziten Build-/Exportnachweis informiert.
2. Nutzer hat bestätigt, dass er den App-Datensatz in App Store Connect selbst angelegt hat; kein Agent hat einen Datensatz erstellt.
3. Die App vor TestFlight weiter vervollständigen: insbesondere App-Icon, erforderliche Store-/Datenschutzinformationen und realen Gerätetest prüfen. Der aktuelle lokale Export ist noch kein geprüfter TestFlight-Upload und keine vollständige Store-Validierung.
4. Erst anschließend einen autorisierten Upload durchführen. Es wurde bislang nichts hochgeladen.

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

Die Quellen erklären den unterstützten Ablauf. Der konkrete Erfolg dieses Projekts wurde anhand des erzeugten Archivs, Exportergebnisses und eingebetteten Profils festgestellt. Eine direkte App-Store-Connect-Portalabfrage wurde nicht durchgeführt.
