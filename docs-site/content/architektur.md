# Architektur und Entscheidungen

Kurzfassung der aktuellen Produktentscheidungen. Maßgeblich bleibt [docs/decisions.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/decisions.md) im Repository.

## App

- Nativ mit Swift 6 und SwiftUI; MapKit und CoreLocation. Keine WebView-Hauptoberfläche.
- Zielplattformen: iPhone zuerst, danach Widgets, Apple Watch, iPad und Mac mit angepasster Bedienung; später tvOS und visionOS. Mindestgeneration zunächst die 27er-Systemversionen.
- Gemeinsamer Code wird nach tatsächlicher Mehrfachnutzung ausgelagert, kein vorsorgliches Framework-System.
- Keine Konten, keine Werbung, keine Analyse-SDKs.

## Datenweg

- **Radarkarte (Build 8):** direkt beim DWD.
- **Radarkarte (ab Build 9):** zuerst der eigene Radar-Cache; der DWD-Direktweg bleibt Fallback bei Fehler, Timeout oder Datenalter über 20 Minuten. Siehe [Radar-Cache-Backend](backend.html).
- **Punktprognose:** weiterhin direkt beim DWD, siehe [Datenvertrag](datenvertrag.html).
- Die Zeitleiste lädt gewählte und benachbarte Zeitpunkte budgetiert vor (siehe [Funktionen](funktionen.html)).

## Backend

Swift/Vapor, MariaDB, Docker Swarm; zustandslose Replikate. Der Radar-Cache läuft produktiv und ist öffentlich erreichbar; die App nutzt ihn ab Build 9 (hochgeladen, Installierbarkeit noch offen). Ein Benachrichtigungsdienst folgt später. Die Backend-Implementierung liegt in einem eigenen Repository ([weather-backend](https://github.com/MagicalWig34653/weather-backend)).

## Verbindliche Leitlinien

- Datenschutz zuerst: nur so viel Daten wie nötig, keine Standortverläufe.
- Bestätigte Fakten, Annahmen und Hypothesen werden getrennt; DWD-Produkte und Lizenzen werden an Primärquellen geprüft.
- Das Repository ist die Quelle der Wahrheit für Entscheidungen und Arbeitsstand.
