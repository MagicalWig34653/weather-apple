# Umbenennung ShowerNow zu "Showers" (Build 17)

Stand: 3. November 2026. Nutzerentscheidung (siehe `docs/decisions.md`): Es wird nur das Optische umbenannt. Das Backend läuft weiter unter `showernow.linolaske.de` (`showers.linolaske.de` zeigt bereits aufs selbe Backend, wird von Build 17 aber nicht genutzt). Kein Redirect, keine Domain-Umstellung. Umgesetzt mit Build 17.

## Umfang

Geändert (sichtbar):
- `Configuration/Base.xcconfig`: `WEATHER_DISPLAY_NAME = Showers`. Gelesen von den vier Info.plists (App, Watch, iPhone-Widgets, Watch-Widgets) als `CFBundleDisplayName`; App-Info.plist setzt auch `CFBundleName`. `PRODUCT_NAME` bleibt `Weather*`.
- App-Texte (InformationSheet inkl. "Über Showers", PlacePushSettingsView, RegionViews, SitePageSheet, PushManager, RadarScreen, Quellenzeile "Showers-Cache" in `WeatherStore`), Watch-Titel und Fallback-Ortsname, Widget-Strings de/en, Intent-Beschreibung.
- Tests/Skripte mit sichtbarem Namen (`WeatherSmokeTests`, `RadarLayerTests`, `design/appstore-screenshots/tools/ShotsUITests.swift`, `mockup.swift`), Website `docs-site` (Titel, Marke, Fußzeile, Inhalte), README, aktuelle Anleitungen. Historische Berichte und Build-Abschnitte bleiben unverändert.
- Preview-Video lokal umbenannt in `showers-app-preview-de-886x1920.mp4` (nicht eingecheckt).

Bleibt unverändert (technisch/nicht sichtbar): Bundle-IDs `de.linolaske.showernow` (+ `.widgets`, `.watchkitapp`, ...), App-Group, Team-ID, Keychain-Service `de.linolaske.showernow.push`, URL-Schema `showernow://`, Widget-Kinds `ShowerNowForecast`/`ShowerNowWatchForecast`, DWD-User-Agent `ShowerNow/0.1`, Modul-/Ordnernamen `Weather*`, die vier URL-Konstanten in `Weather/Data/RadarBackend.swift` (Host `showernow.linolaske.de`), Docker-/GitHub-Namen, Package-Name `showernow-docs-site`.

## Entfällt

Domain-/Redirect-Paket (Basis-, Datenschutz-, Support-, Marketing-URL auf neuen Host), Backend-Texte (Seiten, Push-Titel; eigenes Repo, anderer Agent), Pages-Domain.

## Nutzerschritte (App Store Connect, nicht durch Agents)

1. Name "Showers" auf Verfügbarkeit prüfen und im Eintrag ändern; Konflikt sofort sichtbar. Ausweichnamen z. B. "Showers – Regenradar" (Name max. 30 Zeichen, Guideline 2.3.7). Der Home-Screen-Name (`CFBundleDisplayName`) ist unabhängig vom Store-Namen.
2. Untertitel (max. 30 Zeichen), Beschreibung, Keywords (100 Zeichen), Screenshots mit neuem Namen; Datenschutz-/Support-/Marketing-URL unverändert lassen.
3. TestFlight: Tester über die Umbenennung informieren; ältere Builds (<= 16) zeigen den alten Home-Screen-Namen bis zum Update.
4. Optional: Marken-Kurzrecherche (DPMA/EUIPO/WIPO, Klassen 9 und 42); Hinweis, kein Rechtsrat.

## Prüfung

Siehe `docs/status.md` (Build 17) für ausgeführte Prüfungen und Nicht-Geprüftes.
