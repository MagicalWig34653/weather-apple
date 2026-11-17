# Übergabe Apple-Review-Fixes

## Auftrag und Zuständigkeit

Stand 17. November 2026: Auftrag und Ausführungsverbote sind in [Status](../status.md) und [Entscheidungen](../decisions.md) versioniert. Befunde und konkrete Dateibesitzer folgen nach Abschluss der Code-Bestandsaufnahme durch die Lead-Koordination. Noch kein Befund ist umgesetzt.

Der vorbereitende Dokumentationsworker besitzt ausschließlich diese Übergabe, `docs/status.md` und `docs/decisions.md`; nach seinem Commit sind diese Dateien für die nächste ausdrücklich zugewiesene Dokumentations-/Integrationsaufgabe frei. Fixworker erhalten exklusive Quelldateien, Testdateien und eigene Übergabedokumente. Gemeinsamer Git-Index und Commitrecht werden einzeln vergeben.

## Prüfung und nächster Schritt

- Tatsächlich ausgeführt: statische Lektüre der Projektvorgaben; `git status --short` vor Änderungen war leer; statische Diff-Sichtung der Auftragsdokumentation.
- Nicht ausgeführt: Builds, Tests, Test-Discovery, Lint, Netzaufrufe und Push; ausdrückliches Nutzerverbot.
- Nächster Schritt: Befunde erneut am Code bewerten, getrennte Fixaufträge vergeben und Regressionstests vor Produktionsänderungen schreiben. Die spätere Ausführung der dokumentierten Prüfkommandos bleibt beim Aufrufer.
