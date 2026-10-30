# GitHub-Pages-Dokumentation

Öffentliche Seite: `https://magicalwig34653.github.io/weather-apple/` (Projekt-Pages, alle Links relativ, daher kein Basis-Pfad nötig).

## Aufbau

- Generator: `docs-site/build.mjs` (Node, nur Abhängigkeit `marked`), Stil `docs-site/style.css`; Stack und Look folgen der Seite des Schwesterprojekts Todo.
- Kuratierte Seiten: `docs-site/content/*.md` (Start, Funktionen, Datenschutz, Datenquellen, Architektur, Radar-Cache, Roadmap, Entwickler).
- Direkt eingebunden: `docs/data-contract.md` (Seite „DWD-Datenvertrag“) und der Abschnitt „Projekt öffnen und prüfen“ aus `README.md`. Links auf nicht veröffentlichte `docs/`-Dateien zeigen auf GitHub.
- Bewusst nicht veröffentlicht: Status, Uploadprotokolle, Signing, Reviews, Entscheidungsdetails mit Kennungen. Die kuratierten Seiten fassen `decisions.md` und `plan.md` zusammen; bei Entscheidungsänderungen die Seiten `architektur`, `backend`, `roadmap` nachziehen.
- Radar-Cache: Backend produktiv beschrieben; App-Anbindung (Build 9) als „in Arbeit“ gekennzeichnet, bis sie geprüft und ausgeliefert ist. Benachrichtigungsdienst bleibt als Plan/Entwurf.

## Lokaler Build

```sh
cd docs-site && npm ci && node build.mjs   # Ausgabe: docs-site/dist
```

`node_modules/` und `dist/` sind per `.gitignore` ausgeschlossen.

## Deployment

`.github/workflows/pages.yml` baut bei Push auf `main` (Pfade `docs-site/**`, `docs/data-contract.md`, `README.md`, Workflow) und veröffentlicht mit `actions/deploy-pages`. Actions sind auf Commit-SHAs gepinnt, Berechtigungen minimal (`contents: read`, `pages: write`, `id-token: write`).

Einmalig nötig: in den Repository-Einstellungen unter Pages die Quelle „GitHub Actions“ wählen (oder per API `build_type=workflow` setzen).

## Prüfungen vor Änderungen

Lokal bauen, interne Links prüfen, keine privaten Pfade, Domains, IPs, Tokens oder Standorte in `docs-site/` (Suche vor dem Commit).
