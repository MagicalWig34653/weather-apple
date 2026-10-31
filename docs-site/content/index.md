# ShowerNow

Nativer, werbefreier Regenradar für Apple-Plattformen. ShowerNow zeigt das Niederschlagsradar des Deutschen Wetterdienstes (DWD) auf einer Karte mit Zeitleiste und liefert eine kurzfristige Regenprognose für einen gewählten Ort.

> **Quelle: Deutscher Wetterdienst.** Die Radardaten werden von der App für die Darstellung verändert (Kartenausschnitt, Farbdarstellung, Zeitleiste, Zusammenfassung). Der Veränderungshinweis gehört zur Karte in der App.

## Status

Frühe, interne Beta. Es ist keine öffentliche Version und keine fertige Version 1.

- Aktueller Stand: Version `0.1.0`, **Build 11** (am 31. Oktober 2026 hochgeladen und von Apple angenommen; Verarbeitung und Installierbarkeit in TestFlight noch nicht bestätigt). Builds 1 bis 10 waren nur für interne Tester vorgesehen; Build 11 ist ohne diese Markierung hochgeladen, eine Zuordnung zu externen Testern ist noch nicht bestätigt. Vorgänger ist Build 10.
- Radarbilder kommen seit Build 9 zuerst vom eigenen Radar-Cache. Bei Fehlern oder veralteten Daten lädt die App sie direkt vom DWD; die Karte zeigt, woher die Bilder stammen. Das Cache-Backend läuft produktiv.
- Läuft auf dem **iPhone**; die App ist auf dem **iPad** kompatibel (Universal-Metadaten, noch ohne angepasste iPad-Oberfläche).
- **Geplant, noch nicht umgesetzt:** Widgets, Apple Watch, angepasste iPad- und Mac-Oberfläche, Benachrichtigungen.
- Bundle-ID (vorläufig): `de.linolaske.showernow`.
- Lizenz: AGPLv3 ist angestrebt, die endgültige Freigabe steht aus. Bis dahin ist keine Lizenz erteilt.

## Wo es weitergeht

- [Funktionen und Bedienung](funktionen.html) – was die App heute kann.
- [Datenschutz](datenschutz.html) – kein Tracking, optionaler Standort.
- [Datenquellen und Lizenz](daten.html) und der [DWD-Datenvertrag](datenvertrag.html).
- [Architektur und Entscheidungen](architektur.html), [Radar-Cache-Backend](backend.html), [Roadmap](roadmap.html).
- [Entwickler-Doku](entwickler.html) – Bauen, Testen, Arbeitsweise.

Gemessenes und Geplantes sind getrennt gekennzeichnet: Was als „geplant“ oder „Entwurf“ steht, ist noch nicht produktiv bestätigt.
