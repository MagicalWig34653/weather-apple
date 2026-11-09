# iPhone Duo (faltbares iPhone): Recherchestand

Abrufdatum aller Quellen: 9.11.2026. Nur Belegtes ist als "Belegt" markiert; Eigenes ist "Annahme" oder "Offen".

## Quellen

- Übersicht: https://developer.apple.com/iphone-duo/
- Vorbereitung ("Three steps"): https://developer.apple.com/iphone-duo/prepare/
- Dokumentation: https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo (per einfachem Abruf nur Titel lesbar, Inhalt wird per JavaScript geladen: nicht gelesen)
- Screenshot-Vorgaben: https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications
- App-Preview-Vorgaben: https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications
- Auf der Übersicht verlinkt, hier NICHT gelesen: Videos (Tech Talks 111466 Design, 111461 Prepare, 111462 Raise the bar, 111463 adaptive Layouts, 111464 Displays/Szenen, 111465 Kamera), Human Interface Guidelines "Designing for iPhone Duo" (https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo), Group-Lab-Replays, Q&A-Foren (SwiftUI, UIKit, Photos & Camera), News "Prepare and submit your apps for iPhone Duo". Keine Transkripte verfügbar, daher keine belegten Angaben zu Punktgrößen, Size Classes innen/außen, Szenen/Multi-Display oder Kamera.

## Gerät und Displays (belegt)

- Außendisplay: 1398 x 2034 px (hoch). Innendisplay: 2007 x 2853 px (hoch); Seitenverhältnis ca. 1,45:1 (laut App-Preview-Seite).
- Aufgeklappt füllt die App das Innendisplay, zugeklappt kehrt sie auf das Außendisplay zurück; Apps mit iOS-27-SDK ändern dabei dynamisch ihre Größe.
- Eine iPhone-App kann "jede Kombination von Size Classes" haben (auch durch iPhone Mirroring mit frei skalierbarem Fenster). Auf dem Innendisplay soll die App wie eine natürliche Erweiterung ihres iPad-Layouts wirken.
- Die Geräteausrichtung sagt nichts über die App-Form aus.
- Weitere Hardwaredetails (Punktgrößen, Scale, Preis, Marktstart) sind in den gelesenen Quellen nicht enthalten und werden nicht geführt. Gerüchte bewusst weggelassen.

## App Store: Screenshots und Previews (belegt)

| Anzeige | Hoch | Quer |
|---|---|---|
| Außendisplay | 1398 x 2034 | 2034 x 1398 |
| Innendisplay | 2007 x 2853 | 2853 x 2007 |

- Pflicht ab April 2027 für jede App, die mit iOS 27.1 SDK oder neuer gebaut wird.
- Mit Duo-Screenshots zeigt die Produktseite ein Badge "Made for iPhone Duo" (Wortlaut der Quelle: Hinweis, dass die App für iPhone Duo gemacht ist).
- Zur Pflichtfrage nicht belegt: ob beide Displays Pflicht sind oder je Anzeige eine Größe reicht (Offen).
- App Previews: gleiche Standardmaße wie andere iPhones, 886 x 1920 (hoch) bzw. 1920 x 886 (quer); Duo-Gerätemaße nur zur Referenz, keine eigenen Previews nötig.

## Verhalten je SDK (belegt)

- iOS-26-SDK oder älter: App läuft, passt sich aber nicht an. Aufgeklappt mittig in üblicher Größe mit Leerraum ringsum; zugeklappt links von Statusbereich und Kamera.
- iOS-27-SDK: App füllt den größten Teil des Innendisplays, umgeht aber den Statusbereich am rechten Rand.
- iOS-27.1-SDK oder neuer: Edge-to-Edge auf beiden Displays; Toolbars und Tab-Bars erscheinen vertikal unter dem Statusbereich. Vor dem Release mit diesem SDK prüfen, dass Inhalte sich an vertikale Leisten anpassen.
- Showers baut aktuell mit Xcode 27.2 (lokal verifiziert). Das SDK-Verhalten gilt, sobald das Basis-SDK 27.1 oder neuer ist; ob unser Build bereits als "27.1 SDK" zählt, ist daher wahrscheinlich ja, aber nicht separat geprüft (Annahme).

## Fix-Muster aus Apple "prepare" (belegt) und Prüfpunkte für Showers

Apple-Muster: (1) Layout nicht per `userInterfaceIdiom == .phone/.pad` wählen; (2) "regular width" nicht mit iPad gleichsetzen; (3) keine festen Gerätegrößen wie `bounds.height == 844`; (4) Full-Bleed-Medien mit `.scaleAspectFill` / `.aspectRatio(contentMode: .fill)` prüfen (Fit vs. Fill per Size Class oder Seitenverhältnis, oder Fokuspunkt); (5) nicht per Orientierung entscheiden (`UIDevice.current.orientation`, `statusBarOrientation`, `interfaceOrientation`), stattdessen Breite/Höhe des verfügbaren Raums (`GeometryReader`, `bounds`); (6) feste Orientierungen und Gerätannahmen vermeiden.

Grep-Ergebnis im Repo am 9.11.2026 (Quellcode, ohne `build/`):

- `userInterfaceIdiom`: ein Treffer, `Weather/Views/ScreenGlow.swift` Zeile ca. 135 (`ScreenGlowPresenter.cornerRadius`: Eckenradius des Scrub-Glows nach Idiom `.pad` und Safe-Area-oben). Auf Duo falsch/ungenau möglich (Innendisplay ist iPhone-Idiom, aber breit; Eckenradius unbekannt). Prüfen; ist rein kosmetisch (Glow-Form).
- `horizontalSizeClass`, `UIScreen.main.bounds`, `scaleAspectFill`: keine Treffer in Swift. `.scaledToFill` im Quellcode ebenfalls kein Treffer (nur Muster-Suche, nicht jede Fill-Variante, z. B. Karten/Radar-Bildebenen, geprüft; Offen).
- Orientierung: `Configuration/Info.plist` erlaubt iPhone Hochformat plus beide Querformate (ohne Upside-down), iPad alle vier; Universal (`TARGETED_DEVICE_FAMILY` 1,2 in `project.yml`). Keine feste Hochformat-Sperre, gut. Keine Layout-Entscheidung per `UIDevice.orientation` gefunden (grep nur auf die oben genannten Muster plus `UIInterfaceOrientation`; `statusBarOrientation`/`interfaceOrientation` nicht gesondert gesucht, Offen).

Zu prüfen (ungeprüft, nur als Fragen; Annahme, dass Duo-Simulator nötig ist):

- `RadarScreen.swift`: Header, Glaskreise (Buttons), Zeitleiste/Pille, Legendenpanel und Sheets. Werden Abstände/Ränder aus Safe Area und verfügbarem Platz abgeleitet? Verhalten bei sehr breitem Innendisplay (ca. 1,45:1) und bei vertikalen Toolbars unter dem Statusbereich (27.1 SDK)? Bleiben Sheets (Detents, Breite) auf dem Innendisplay sinnvoll, ggf. wie auf iPad?
- Warnansicht (gruppiert nach Ort, Stufenkarten, Filter): Breite der Karten, Lesbarkeit bei Breite statt Hochformat.
- Eigene Tab-/Toolbars: Inhalte müssen vertikale Leisten (27.1) vertragen.
- Widgets, Live Activity, Watch-App: vermutlich nicht betroffen (eigene Plattform/Rahmen), ungeprüft.
- `ScreenGlow`: siehe oben, Eckenradius-Heuristik.
- UI-Tests/Screenshot-Tooling (`design/appstore-screenshots/tools/ShotsUITests.swift`) nutzt feste Gerätegrößen? Nicht geprüft.

## Testen

- Belegt (Apple): iPhone-Duo-Simulator in Xcode 27.1 ist der beste Weg für das native Erlebnis; zusätzlich der skalierbare iOS-Simulator im Device Hub und iPhone Mirroring (macOS 27) mit extremen Fenstergrößen.
- Lokal (9.11.2026): Xcode 27.2 (Build 27B52). `xcrun simctl list devicetypes` listet den Typ `iPhone Duo` (`com.apple.CoreSimulator.SimDeviceType.iPhone-Duo`). Nur aufgelistet, kein Simulator gestartet, keine Runtime-Verfügbarkeit (`simctl list runtimes`) geprüft (Offen).

## Offene Fragen

- Sind Screenshots für beide Displays Pflicht oder genügt eines? Ist der Stichtag April 2027 an das Einreichungs-SDK gekoppelt (ja laut Quelle) und gilt er für Updates?
- Inhalte der Videos/HIG zu Size Classes innen/außen, Szenen- und Multi-Display-Verhalten und Kamera (Showers nutzt keine Kamera): nachlesen, falls relevant.
- Zählt das lokale Xcode 27.2 schon als "27.1 SDK oder neuer"? (Annahme ja.)
- Reicht ein Layout nach Platz (Size Class) auf Radar/Warnungen oder ist eine eigene Innendisplay-Variante nötig?

## Verknüpfung

- Release-Checkliste: `docs/app-store-release-checkliste.md` (Verweis auf dieses Dokument dort noch ergänzen).
- Screenshot-Anleitung: `docs/appstore-screenshots.md`.
