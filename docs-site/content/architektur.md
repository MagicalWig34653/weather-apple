# Architektur und Entscheidungen

Kurzfassung der aktuellen Produktentscheidungen. Maßgeblich bleibt [docs/decisions.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/decisions.md) im Repository.

## App

- Nativ mit Swift 6 und SwiftUI; MapKit und CoreLocation. Keine WebView-Hauptoberfläche.
- Zielplattformen: iPhone zuerst, danach Widgets, Apple Watch, iPad und Mac mit angepasster Bedienung; später tvOS und visionOS. Mindestgeneration zunächst die 27er-Systemversionen.
- Gemeinsamer Code wird nach tatsächlicher Mehrfachnutzung ausgelagert, kein vorsorgliches Framework-System.
- Keine Konten, keine Werbung, keine Analyse-SDKs.

## Datenweg

- **Standard heute:** Direktweg zum DWD (Karte und Punktprognose), siehe [Datenvertrag](datenvertrag.html).
- **Entschieden, in Entwicklung:** ein eigener Radar-Cache als Standardroute der Karte, der DWD-Direktweg bleibt Fallback bei Fehler, Timeout oder Datenalter über 20 Minuten. Siehe [Radar-Cache-Backend](backend.html).
- Die Zeitleiste lädt gewählte und benachbarte Zeitpunkte budgetiert vor (siehe [Funktionen](funktionen.html)).

## Backend (geplant)

Swift/Vapor, MariaDB, Docker Swarm; zustandslose Replikate. Zuerst der Radar-Cache, später ein Benachrichtigungsdienst. Die Backend-Implementierung folgt nach der nutzbaren App und liegt in einem eigenen Repository ([weather-backend](https://github.com/MagicalWig34653/weather-backend)).

## Verbindliche Leitlinien

- Datenschutz zuerst: nur so viel Daten wie nötig, keine Standortverläufe.
- Bestätigte Fakten, Annahmen und Hypothesen werden getrennt; DWD-Produkte und Lizenzen werden an Primärquellen geprüft.
- Das Repository ist die Quelle der Wahrheit für Entscheidungen und Arbeitsstand.
