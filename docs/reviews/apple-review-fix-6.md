# Apple-Review: Befund 6

**Bestätigt und behoben:** `RadarImageDecoder.decode()` forderte die sofortige Bilddekodierung vor dem Vergleich mit den Manifestmaßen an. Ein kleines komprimiertes Bild konnte dadurch vor seiner Ablehnung eine übergroße Pixelallokation auslösen.

Zuerst zwei XCTest-Regressionen in der bereits eingebundenen `WeatherTests/RadarBackendTests.swift` geschrieben: reine Metadatenprüfung für gültige Größen einschließlich 4096 × 4096, übergroße Kanten/Pixelzahl (16384 × 16384), Manifestabweichungen sowie fehlende, nichtnumerische, boolesche, gebrochene, unendliche und übergroße Zahlen; außerdem ein tatsächlich erzeugtes 1×1-PNG mit gültigen und abweichenden Manifestmaßen. Die Sicherheitsgrenzen werden ohne riesige Bildallokation geprüft.

Danach minimaler Fix in `Weather/Map/RadarImageOverlay.swift`: ImageIO-Quelle ohne Pixelcache öffnen, tatsächliche Metadaten vor `CGImageSourceCreateImageAtIndex` auslesen und prüfen. Feste Kanten-/Pixelgrenzen entsprechen dem bestehenden Manifestvertrag (4096 je Kante, 4096² Pixel). Der Pixelvergleich verwendet Division nach positiver, begrenzter Ganzzahlprüfung und kann daher nicht überlaufen. Nach der Dekodierung bleiben Dimensions- und Vollständigkeitsprüfung bestehen.

Statisch gelesen: Decoder, Manifestgrenzen, bestehende Tests und eigener Diff. Keine Builds, Tests, Test-Discovery, Lints, Netzaufrufe oder Push ausgeführt (Nutzerauftrag). Die Tests prüfen die reine vorgeschaltete Sicherheitsprüfung und kleine echte Bilddaten; die Reihenfolge vor der Pixeldekodierung wurde statisch beurteilt. Compiler-/ImageIO-Verhalten ist noch durch den Aufrufer zu prüfen. Commitzuordnung ergänzt der Abschlussbericht.

Ausführung durch den Aufrufer:

```sh
xcodebuild -project Weather.xcodeproj -scheme Weather \
  -destination 'platform=iOS Simulator,name=iPhone 18 Pro' \
  -derivedDataPath /tmp/weather-derived CODE_SIGNING_ALLOWED=NO \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderValidatesMetadataBeforeAllocatingPixels \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderAcceptsSmallPNGAndRejectsManifestMismatch \
  -only-testing:WeatherTests/RadarBackendTests/testDecoderChecksDimensionsAndRejectsGarbage test
```

Nächster Schritt: unabhängiges statisches Review und spätere Ausführungsprüfung durch den Aufrufer.
