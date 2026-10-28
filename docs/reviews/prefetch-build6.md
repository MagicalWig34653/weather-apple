# Unabhängiger Review des Timeline-Prefetchs

Stand: 28. Oktober 2026. Lesender Review des Build-6-Arbeitsbaums gegen Build-5-Quellen `c474893`. Umfang: RAM-Cache, Scheduler, MapKit-Nachfrageintegration und Radarfeedback. Keine eigenen Builds, Tests, Simulatoraktionen oder DWD-Bildanfragen. **Abschließender Codebefund: alle vier gefundenen P2-Grenzen sind korrigiert; keine offenen P1/P2 im geprüften Diff. Für kontrollierte Integration und Tests freigegeben.**

## Befunde vor Korrektur

1. **Framewechsel beendet den Transport vor möglicher Promotion.** `RadarMap.updateUIView` ruft vor dem Overlaywechsel `prefetcher.cancel()` auf. Der Flight entfernt und cancelt dabei den einzigen spekulativen Transport, solange der neue Foreground-Subscriber noch nicht existiert. Wählt der Nutzer genau den gerade vorgeladenen Frame, kann dessen späteres `loadTile` den bereits entfernten Request nicht mehr übernehmen und startet erneut. Der isolierte Test `join` vor `cancel` bildet diese Reihenfolge nicht ab. Begrenzte Korrektur: zielgebundene Übergabe an den tatsächlich neu gewählten Frame mit endlicher Reserve, andere überholte Requests weiterhin abbrechen.
2. **Späte promovierte Fehler können die neue Refreshrevision vergiften.** Der Promoted-Callback liest beim Abschluss `progress.snapshot.reloadRevision`. Beim Refresh desselben Frames bleibt das Overlay erhalten und sein Tracker bekommt bereits die neue Revision. Ein Fehler des vorher gestarteten Requests wird dadurch unter der neuen Revision im Fehlerregister gespeichert. Die Revision muss bereits bei `loadTile` erfasst werden, wie im normalen Transportpfad.
3. **Frische kann während der Budgetpause ablaufen.** Die 20-Minuten-Prüfung findet vor der bis zu 60 Sekunden langen Budgetpause statt. Danach wird ohne erneute Frischeprüfung ein Request gestartet. Der Guard muss unmittelbar nach dem Warten und vor der Budget-/Transportfreigabe erneut greifen.

4. **Mehrere promovierte Subscriber zählen denselben Body mehrfach.** Jeder promotete MapKit-Callback ruft `progress.received` auf. Zwei Nachfragecallbacks desselben Overlays für denselben einzigen Transport verdoppeln dadurch den angezeigten Nachfrage-Download. Die Transportantwort muss je Overlaykontext einmal abgerechnet werden; reine Cachetreffer bleiben netzfrei.

Alle vier Befunde sind eng begrenzte Ablaufgrenzen; keine Notwendigkeit für einen Renderer-, Backend- oder Diskcacheumbau. Die Implementierung ist für Änderungen zuständig. Korrekturen und gezielte Nachweise sind bei Abschluss abzugleichen.

## Bereits gelesener Vertrag

Der Cache prüft gültige PNGs vor Einfügung und verwaltet gespeicherte komprimierte PNG-Nutzdaten unter einer lockgeschützten harten Grenze von 50.000.000 Byte; Systembilder, Metadaten und laufende Responses sind ausdrücklich kein gesamtes App-RAM-Limit. Die Reihenfolge beginnt beim ausgewählten Index und wechselt links/rechts; historische Frames verwenden ihre eigene Analyse-Referenz.

Das appseitige Vorladebudget bleibt über Kontextwechsel bestehen: eine Sekunde Leerlauf, ein spekulativer Transport, mindestens 500 ms Abstand, 120 Requests und 8.000.000 empfangene Bytes je festem 60-Sekunden-Fenster. Das Bytebudget ist eine Stopgrenze nach vollständiger Antwort und kann um eine einzelne Antwort überschritten werden; die 50-MB-Cachegrenze bleibt hart. Keine veröffentlichten DWD-Kontingente werden daraus abgeleitet. Quellfehler stoppen den Sweep mit 120 Sekunden laufgebundener Pause; keine geplante Retry-/Polling-Schleife. Inaktive Szene, Low Data, teure Verbindung und Low Power sperren optionales Vorladen.

Die Coverage besteht aus beobachteten deduplizierten MapKit-Tilekoordinaten, einschließlich möglichem Pufferbedarf; sie ist keine exakt vermessene sichtbare Tilemenge. 32 Tiles × 37 Slots bedeuten rechnerisch 1.184 Requests und bei 120/min ungefähr zehn Minuten Mindestbudgetzeit. Neue Fünf-Minuten-Läufe, Nutzung und Frische können eine vollständige Vorwärmung verhindern. Es gibt kein Versprechen, alle Slots rasch zu füllen.

## Abnahmegrenze

Kontrollierte Tests und Integration erfolgen durch den zuständigen Buildowner. Bestehende P0-Fehlerkeys, Abbruchsemantik, PNG-Prüfung, Dimensionretrybudget und Frische bleiben verbindlich. Dieser Review behauptet keine bestandenen Tests, keinen neuen Geschwindigkeitsbeleg und keinen Upload.

## Zwischenprüfung der ersten Korrekturen

Target-aware Handoff vor dem Frameabbruch, maximal zwei Sekunden Reserve und sofortiges Aufheben bei unpassendem Folgescrub, Orts-/Viewportwechsel oder inaktiver Szene sind nachgelesen. Bestehende Nachfrage-Subscriber werden beim Aufheben der Reserve erhalten. Erfolgreiche validierte Responses gelangen vor Entfernung des Flight-Slots in den harten RAM-Cache. Die Fehlerrevision wird nun beim Nachfragebeginn erfasst; die Frische-/Policyprüfung greift erneut nach der Budgetpause. Dabei betrifft die 20-Minuten-Grenze ausdrücklich den aktuellen Timeline-Quelllauf, während ein zulässiger historischer Analyseframe seine tatsächliche ältere Referenz behält. Die Byteabrechnung ist ebenfalls korrigiert: alle Subscriber einer Antwort erhalten dieselbe Transport-ID. Der Tracker zählt diese ID je passendem Viewportkontext genau einmal und leert die Menge beim Kontextreset; die separate Prefetchabrechnung erfolgt einmal vor dem Callback-Fanout. Kein Testlauf durch den Reviewer.

## Abschließende Übergabe

Die fertigen Handoff-/Revisions-/Frische-/Bytekorrekturen wurden gezielt erneut gelesen; keine weiteren P1-/P2-Befunde im begrenzten Cache-/Scheduler-/Map-/Feedbackdiff. `git diff --check` ist erfolgreich. Produktionscode blieb vollständig im Besitz des Implementierers; der Review verändert nur dieses Dokument. Keine neuen Standort-/URLlogs, Diskpersistenz oder zusätzliche Dienste im geprüften Diff. Freigabe für den eingefrorenen Integrations-/Testlauf, danach Test- und Metadatennachweise gesondert dokumentieren. Appseitiges Pacing ist ein Schutzmechanismus, keine Zusage zur DWD-Kapazität oder vollständigen Vorwärmung.
