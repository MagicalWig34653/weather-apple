# Agent-Koordination für Weather

Stand und Quellenabruf: 28. Oktober 2026. Recherche mit der Skill **OpenAI Docs** und tatsächlich geöffneten offiziellen OpenAI-/Anthropic-Primärquellen. Es wurde keine universell beste Strategie festgestellt; der folgende Ablauf passt zu den Nutzerentscheidungen und dem kleinen Projekt.

## Verbindliche Nutzerentscheidungen

- Der Hauptagent koordiniert ausschließlich. Auch Implementierung, Build, Tests, Recherche und Dokumentationsänderungen werden delegiert.
- Für jede neue abgegrenzte Aufgabe wird ein neuer Agent gestartet. Ein abgeschlossenes Agent-Arbeitsverhältnis wird nicht für eine andere Aufgabe wiederverwendet.
- Unabhängige Aufgaben sollen parallel laufen; Kostenbewusstsein bleibt verbindlich.
- Sessions sind wegwerfbar. Das Repo ist Source of Truth; private lokale Pfade bleiben ausschließlich in der ignorierten lokalen Workspace-Datei.

„Neue Aufgabe“ bedeutet hier ein überprüfbares Arbeitsergebnis, etwa „DWD-Zeitformat korrigieren und Regressionstest ergänzen“, nicht jeder einzelne Shell-Befehl. Diese Auslegung vermeidet unnötige Starts und wahrt die fachliche Zusammengehörigkeit. Präzisierungen innerhalb einer noch laufenden Aufgabe dürfen dem zuständigen Agent mitgeteilt werden.

## Was die Quellen tatsächlich unterstützen

1. OpenAI empfiehlt Multi-Agent-Arbeit für konkrete unabhängige Teilaufgaben und getrennten Kontext. Gemeinsame veränderliche Ressourcen oder strikt voneinander abhängige Schritte sprechen gegen parallele Ausführung. Subagents können den Tokenverbrauch erhöhen; die Dokumentation nennt drei gleichzeitige Subagents als sinnvollen Ausgangspunkt. [OpenAI: Multi-agent](https://developers.openai.com/api/docs/guides/responses-multi-agent)
2. Für Kosten zählen Root und Subagents einschließlich Wiederholungen, Eingaben, Ausgaben und Werkzeugnutzung zusammen. Wiederverwendeter Kontext kann Caching erlauben, garantiert aber weder einen Treffer noch niedrigere Gesamtkosten. Maßstab ist die gesamte erledigte Aufgabe. [OpenAI: Observability and usage](https://developers.openai.com/api/docs/guides/agents-api/observability)
3. Anthropic beschreibt als erprobten Ansatz kleine inkrementelle Aufgaben, nachvollziehbare Git-Stände, persistente Fortschrittsnotizen und Prüfung tatsächlichen Endnutzerverhaltens. Frischer Kontext allein ersetzt diese Übergabe nicht. Der Artikel bezeichnet die optimale generelle Agent-Architektur ausdrücklich als offene Frage. [Anthropic: Effective harnesses for long-running agents](https://www.anthropic.com/research/effective-harnesses-for-long-running-agents)

Die ausschließliche Koordinatorrolle und ein neuer Agent je Aufgabe sind **Nutzervorgaben**, keine von diesen Quellen bewiesenen universellen Qualitäts- oder Kostengarantien.

## Empfohlener Ablauf für dieses Repo

1. **Ein Auftrag, ein Verantwortlicher:** Der Koordinator formuliert Ergebnis, Abnahmekriterien, erlaubte Dateien, Abhängigkeiten und ausdrücklich ausgeschlossene Arbeiten. Für neue Aufgaben einen frischen Agent starten.
2. **Kontext knapp übergeben:** Repo, relevante Dokumente und benötigte Befunde verlinken; keine vollständigen Chatverläufe oder Rohlogs kopieren. Wo technisch sinnvoll, frischen Kontext statt vollständiger Historienvererbung verwenden. Aktuelle Nutzerentscheidungen müssen trotzdem im Briefing und Repo zugänglich sein.
3. **Zunächst bis zu drei produktive Aufgaben parallel:** Beispielsweise Datenkorrektur, UI-Tests und Signing-Prüfung. Die Zahl ist eine Startregel, keine Plattformgrenze. Nur bei nachweisbar unabhängiger Zusatzarbeit erhöhen. Keine künstliche Beschäftigung eines ganzen dauerhaften Teams.
4. **Schreibzuständigkeiten trennen:** Im gemeinsamen Checkout eindeutige Datei-/Verzeichnisbesitzer vergeben. Derselbe Projektgenerator, Simulator und Signing-Vorgang haben jeweils nur einen aktiven Verantwortlichen. Bei überlappenden größeren Änderungen eigene Worktrees mit anschließend zugewiesener Integration einsetzen.
5. **Abhängige Schritte nacheinander:** Erst stabile Änderungen übergeben, dann den Integrations-/Build-Agent starten. Keine parallelen Änderungen während desselben Builds und keine mehrfachen identischen Prüfungen ohne neue Änderung oder offenen Befund.
6. **Kurze belegbare Übergabe:** Geänderte Dateien, ausgeführte Prüfungen samt Ergebnis, offene Grenzen und nächster Schritt. Nicht ausgeführte Prüfungen benennen. Diese Ergebnisse im Repo festhalten; der flüchtige Agent-Chat ist kein Ersatz.
7. **Integration ebenfalls delegieren:** Ein neuer Integrations-Agent erhält die abgegebenen Ergebnisse, führt erforderliche Builds/Tests aus und dokumentiert den Stand. Ein unabhängiger Review-Agent prüft risikorelevante Änderungen gezielt; kein pauschales zweites Vollreview jeder Kleinigkeit.
8. **Abschluss anhand der Abnahme:** Der Koordinator gleicht die Berichte ab und weist Widersprüche oder neue Fehler als neue begrenzte Aufgaben zu. Er meldet nur belegten Erfolg; „Build erfolgreich“ bedeutet weder „fachlich validiert“ noch „in TestFlight verfügbar“.

## Minimale dauerhafte Übergabe

Die vorhandenen Dokumente reichen grundsätzlich: `docs/decisions.md` für Verbindliches, `docs/status.md` für aktuellen Stand/Prüfungen/nächste Aufgaben und `docs/research/` für konkrete Untersuchungen. Ein im Status geführter kurzer Abschnitt mit aktiven Aufgaben und Dateibesitzern verhindert Konflikte; keine große neue Verwaltungsinfrastruktur und keine Sammlung vollständiger Sessionprotokolle nötig.

Die derzeitigen `AGENTS.md`-Regeln fordern nur mindestens einen delegierten Teilauftrag und erlauben dem Hauptagent noch selbstständige Integration. Sie müssen durch eine separat beauftragte Dokumentationsaufgabe an die neueren verbindlichen Nutzerentscheidungen angepasst werden. Diese Recherche ändert sie bewusst nicht.
