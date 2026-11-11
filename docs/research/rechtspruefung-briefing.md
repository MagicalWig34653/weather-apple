# Briefing: Rechtsprüfung Datenschutz und Impressum (für einen Opus-Agenten, 11.11.2026)

Auftrag an den prüfenden Agenten: Plausibilitäts- und Risikoprüfung, kein Rechtsrat. Ergebnis ist eine Liste je Frage mit Einschätzung (unkritisch / nachbessern / Anwalt empfohlen), Quelle und konkretem Textvorschlag. Nur lesend; nichts deployen, nichts in App Store Connect eintragen. Ergebnis als `docs/research/rechtspruefung-ergebnis.md`.

## Kontext

- App: Showers (Bundle `de.linolaske.showernow`), kostenlose Wetter-/Regenradar-App eines Einzelnen, nur Deutsch angeboten, Zielstart im App Store ca. 9.12.2026.
- Datenflüsse: Radar vom eigenen Server (Hetzner-vServer, Deutschland, Reverse Proxy Zoraxy); Punktprognose direkt beim DWD; Karten Apple MapKit; optional Push/Live Activity mit Gerätetoken, Installations-UUID, Rasterzelle (~0,7 km) bzw. Gebiet (~2 km); Betreiber-Diagnose (Kopplung); Warnungen des DWD (Kreisebene).
- Entscheidung Nutzer 10.11.: Datenschutztext Teil A final und gekürzt, keine englische Seite.

## Zu lesen (Repo)

1. `docs/datenschutz-entwurf-release.md` Teil A (Seitentext), Teil B (App-Privacy), Teil C (Stand der Fragen), Teil G (Fragenliste, 12 Punkte)
2. `docs/decisions.md` (Push, Datenschutz, Diagnose)
3. `docs/research/dwd-warnungen-weitergabe.md` (Lizenz Warnungen)
4. Backend-Seitentexte laut Auftraggeber nur über den Nutzer; Backend-Repo nicht voraussetzen

## Fragen (aus Teil G, priorisiert)

1. Proxy-Logs: Dauer, Rechtsgrundlage, Text Abschnitt 3 (7 bis 14 Tage empfohlen).
2. Proxy-Logs mit Pfaden (Installationskennung in der URL?): Nennung nötig, Auswirkung auf App-Privacy.
3. Rechtsgrundlage Push/Live Activity (Einwilligung oder Vertrag), Hinweis vor dem Einschalten.
4. § 25 TDDDG für Schlüsselbund/Token/UserDefaults.
5. Rolle von Apple (APNs, MapKit) und Drittlandübermittlung.
6. Betreiber-Diagnose: Einwilligung, Transparenz.
7. Hetzner-AVV: Standard-AVV ausreichend; Unterauftragsverarbeiter.
8. Impressum nach § 5 DDG bei kostenloser App eines Einzelnen; ladungsfähige Anschrift.
9. Datenschutzbeauftragter: keine Benennungspflicht?
10. Direktabrufe (DWD, EUMETSAT, MapKit): gemeinsame Verantwortung?
11. Rasterzelle als personenbezogenes Datum: Formulierung.
12. Lizenzen: DWD-Daten (GeoNutzV/CC BY 4.0), DWD-Warnungen, EUMETSAT-Attribution.

## Nicht Teil des Auftrags

Englische Fassung (nicht veröffentlicht), Änderungen am App-Code, Anlage von Store-/Signing-Ressourcen. Bestätigte Fakten, Annahmen und Hypothesen im Ergebnis unterscheiden; Primärquellen mit Abrufdatum nennen.
