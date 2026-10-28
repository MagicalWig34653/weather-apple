# Arbeitsanweisungen

## Zuerst lesen

1. `docs/decisions.md`: aktueller Umfang, Reihenfolge, vorläufige Kennungen.
2. `docs/concept-v2.md`: detailliertes ursprüngliches Konzept.
3. `README.md`: aktueller Repository-Status.

## Auftrag und Grenzen

Native Swift-/SwiftUI-App für iOS, iPadOS, macOS und watchOS; später tvOS und visionOS. Keine WebView-Hauptoberfläche. Geräteoberflächen gezielt anpassen. Wettermodelle und Auswertung nach Bedarf gemeinsam nutzen, aber noch keine Package-Struktur erfinden.

- Derzeit ist nur die Einrichtung der Repositories und weitere Planung freigegeben. Vorläufig keinen Anwendungscode, keine Docker-Konfiguration und keine vollständige Implementierung erzeugen. Neue ausdrückliche Nutzeraufträge können diesen Stand erweitern.
- Zentrale offene Architekturentscheidungen besprechen, statt sie stillschweigend festzulegen.
- Bestätigte Fakten, Annahmen und zu testende Hypothesen unterscheiden. DWD-Produkte, Schnittstellen, Lizenzen und Plattformverhalten vor darauf gestützten Implementierungsentscheidungen anhand aktueller Primärquellen überprüfen.
- Deutsch mit dem Nutzer kommunizieren; Codebezeichner später auf Englisch. Dokumentation im bestehenden Stil halten.
- Keine Geheimnisse, Signing-Dateien, APNs-Schlüssel, Tokens, echten Nutzerstandorte oder lokalen Zugangsdaten committen.
- Datenschutz als Produktanforderung behandeln. Keine Standortverläufe oder identifizierende Debuglogs einführen.
- Nur tatsächlich vorhandene Build-/Testbefehle dokumentieren und ausführen. Derzeit gibt es keine; keine erfolgreiche Kompilierung behaupten.
- Keine unaufgeforderten Infrastrukturkomponenten oder plattformübergreifenden Abstraktionen einführen.
- Änderungen an Produktumfang und Entscheidungen in `docs/decisions.md` nachvollziehbar festhalten. Das ursprüngliche Konzept nicht stillschweigend überschreiben.
- App-Name, Bundle-ID und Team-ID sind vorläufig; keine Signing-/Store-Ressourcen ohne den entsprechenden Arbeitsauftrag anlegen.
