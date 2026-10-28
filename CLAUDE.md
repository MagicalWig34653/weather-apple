# Claude Code

Lies vor der Arbeit die gemeinsamen Repository-Anweisungen:

@AGENTS.md

Die aktuellen Produktentscheidungen stehen in `docs/decisions.md`, Plan und Arbeitsstand in `docs/plan.md` und `docs/status.md`.

Die Apple-App besitzt ein Xcode-Projekt. Vorhandene Build-/Testbefehle stehen im `README.md`; der tatsächlich geprüfte Stand steht in `docs/status.md`.

Verbindlich: Hauptagent und technischer Lead koordinieren ausschließlich; jede neue Ergebnisaufgabe erhält einen frischen ausführenden Agent. Unabhängige Aufgaben mit getrenntem Dateibesitz parallel bearbeiten, zunächst höchstens drei produktive Worker. Der Ablauf steht in `docs/team.md`.

Möglichst kostensparsam arbeiten. Sessions müssen wegwerfbar sein; das Repo ist Source of Truth. Relevante Ergebnisse, Prüfungen und nächste Schritte gemäß `AGENTS.md` fortlaufend im zugewiesenen Repo-Dokument festhalten. Private lokale Pfade ausschließlich in der ignorierten `LOCAL_WORKSPACE.md` belassen.
