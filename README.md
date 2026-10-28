# Weather — Apple-App

Planungsrepository für eine native, datensparsame Regen-App. Arbeitsname und technische Kennungen sind vorläufig.

Native Swift-/SwiftUI-App für iOS, iPadOS, macOS und watchOS; später tvOS und visionOS. Keine WebView-Hauptoberfläche. Geräteoberflächen gezielt anpassen. Wettermodelle und Auswertung nach Bedarf gemeinsam nutzen, aber noch keine Package-Struktur erfinden.

## Status

Dieses Repository enthält bewusst zunächst Dokumentation, keinen Anwendungscode und keine Build- oder Deployment-Konfiguration. Es ist noch kein ausführbares Projekt. Die nächste Arbeit ist die gemeinsame Konzeption und die Validierung der DWD-Datenkette.

## Einstieg

- [Aktuelle Entscheidungen und Roadmap](docs/decisions.md)
- [Ursprüngliches Konzept v2](docs/concept-v2.md)
- [Arbeitsanweisungen für Coding-Agenten](AGENTS.md)
- [Claude-Code-Einstieg](CLAUDE.md)

Die Apple-App wird zuerst entwickelt und intern über TestFlight erprobt. Der Pushdienst folgt danach. Geplantes Schwesterrepository: `weather-backend`.

## Lizenz

Open Source unter AGPLv3 ist vorgesehen. Die endgültige Lizenzfreigabe und die Vereinbarkeit mit der vorgesehenen App-Store-Veröffentlichung stehen noch aus. Derzeit ist keine Lizenz erteilt; insbesondere bedeutet ein öffentliches Repository allein keine Nutzungserlaubnis.
