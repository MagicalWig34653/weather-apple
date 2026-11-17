# Übergabe Apple-Review-Fixes

Stand 17. November 2026: Alle acht Befunde bestätigt und behoben. [Abschlussbericht](../../BERICHT-FIXES.md) enthält je Befund Commit und exakten Testbefehl; Einzelübergaben: [1](apple-review-fix-1.md), [2](apple-review-fix-2.md), [3](apple-review-fix-3.md), [4](apple-review-fix-4.md), [5](apple-review-fix-5.md), [6](apple-review-fix-6.md), [7](apple-review-fix-7.md), [8](apple-review-fix-8.md).

## Umsetzung und Zuständigkeit

Frische Worker pro Ergebnis, zuerst Regressionstests, danach minimale Fixes. Geteilte Warn-/Watch-Dateien und Git-Commits wurden seriell vergeben; alle Codeworker sind fertig und haben ihren Besitz freigegeben. Ein vorbereitender Prozesscommit versionierte Auftrag und Verbote vor der Umsetzung. Zwei unabhängige statische Reviewaufträge prüften 1–4 und 5–8 einschließlich Testeinbindung, Typen/Actor-Isolation und Watch-Harness; keine konkrete Codebeanstandung. Gemeinsame Status-/Berichtsdateien liegen beim Abschluss-Dokumentationsworker, danach keine aktiven Schreibaufträge.

## Prüfung und nächster Schritt

- Tatsächlich ausgeführt: statische Quell-/Diffsichtung, Git-Status und Commitzuordnung; Ausgangsarbeitsbaum sauber.
- Nicht ausgeführt: Builds, Tests, Test-Discovery, Lints, Netzaufrufe, Watch-Harness und Push (Nutzerauftrag); auch verpflichtender L10n-Lauf aus README deshalb ausgelassen. Git-Hooks bei Commits deaktiviert, um keine verbotenen Prüfungen auszulösen.
- Offen: Kompilierung, Regressionstestläufe, ImageIO-/Watch-Laufzeit und Watch-Scene-Verhalten. Der Aufrufer führt die Befehle im Bericht aus. Keine Aussage zu Signing, Upload oder TestFlight.
- Grenze Befund 4: Neue Credentials berechtigen nicht zum Löschen einer bereits unzugänglichen alten Installation. Gültige Altzustände behalten IDs und werden ohne Duplikate migriert.
