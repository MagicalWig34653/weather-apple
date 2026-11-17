# Einrichtung beim ersten Start (Setup-Wizard)

Stand: 17.11.2026, von Lino freigegeben. Leitplanken aus `concept-v2.md`: Die App ist ohne jede Berechtigung voll nutzbar, erweiterte Rechte gibt es nur mit verständlicher Erklärung, und ohne Push-Abo wird nichts beim Server registriert.

## Entscheidungen (Lino, 17.11.)

1. Die Regenwarnung wird direkt im Wizard angeboten (Schritt 4), nicht nur als Tipp.
2. Bestehende TestFlight-Nutzer sehen den Wizard auch, aber nur mit den noch offenen Schritten.
3. Gestaltung im Glas-Stil der App (`app-glass.md`), ohne eigene Illustration.

## Grundsätze

- Höchstens 5 Bildschirme, jeder mit „Später“. „Überspringen“ führt mit einem Tippen direkt zum Radar.
- Die Systemabfrage kommt erst, nachdem man auf „Weiter“ getippt hat. Vorher erklärt ein eigener Bildschirm, wofür das Recht dient und was nicht passiert.
- Der Knopf vor der Systemabfrage heißt „Weiter“, nicht „Erlauben“ (App-Review-Richtlinie 5.1.1: kein vorgetäuschtes Einverständnis, immer ein Ausweg).
- Schritte, die schon entschieden sind, fallen weg. Ist der Standort zum Beispiel bereits erlaubt oder abgelehnt, kommt dieser Schritt nicht.

## Ablauf

| # | Bildschirm | Inhalt | Systemabfrage |
|---|---|---|---|
| 1 | Willkommen | Was Showers kann: Radar, Prognose für den Ort, Regenwarnung. Dazu „Kein Konto, kein Tracking“ und die Quellen DWD und EUMETNET OPERA. | – |
| 2 | Standort | „Für Karte und Prognose an deinem Ort. Der Standort bleibt auf dem Gerät.“ Alternativ „Lieber einen Ort suchen“. | Nur bei Nutzung, niemals „Immer“ |
| 3 | Orte | Erster gespeicherter Ort: der Standort als Vorschlag oder über die Suche. 1–3 Orte, freiwillig. | – |
| 4 | Regenwarnung | „Wir melden, wenn an deinem Ort Regen beginnt.“ Ehrlich, was an den Server geht: Rasterzelle und Geräte-Token, kein genauer Standort. Bisher nur für Deutschland. Danach Auswahl der Orte. | Mitteilungen |
| 5 | Fertig | Tipps ohne Abfrage: Widget hinzufügen, Live-Aktivität, Watch, DWD-Warnungen. Dann zum Radar. | – |

## Ablehnung und später

- Wer ablehnt, landet trotzdem in einer voll nutzbaren App. Der bestehende Hinweistext (`STORE_LOCATION_DENIED`) bleibt.
- Im Infobereich (`InformationSheet`) kommt ein Abschnitt „Einrichtung“ dazu. Er zeigt den Stand je Berechtigung, enthält „In iOS-Einstellungen öffnen“ und kann den Wizard erneut starten.
- Liegt ein Ort außerhalb Deutschlands, wird das Radar dort mit OPERA CIRRUS angezeigt. Ein Hinweis erklärt, dass der Push dort noch nicht geht.

## Technik

- Ein bildschirmfüllendes Fenster in SwiftUI (`fullScreenCover`). Ein gespeicherter Wert `setupVersion` merkt sich, dass die Einrichtung durchlaufen ist. Kommen später Schritte dazu, zeigt eine höhere Version nur den neuen Schritt.
- Die Schrittfolge ist eine reine Funktion aus Berechtigungsstand und `setupVersion`. Dafür gibt es Unit-Tests je Kombination, dazu einen UI-Test mit einem Startargument, das die Einrichtung zurücksetzt.
- Bestehende Abfragen nutzen: `WeatherStore.requestLocation()` und `PushManager.requestAuthorization()`.
- Deutsch und Englisch, VoiceOver und Dynamic Type von Anfang an. Keine Statistik über Abbrüche (Datenschutz).
- Die Watch bekommt keinen eigenen Wizard, sie übernimmt den Stand vom iPhone.
