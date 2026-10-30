# Roadmap

Reihenfolge laut Entwicklungsplan ([docs/plan.md](https://github.com/MagicalWig34653/weather-apple/blob/main/docs/plan.md)). Es gibt keine Termin- oder Aufwandszusagen.

| Schritt | Inhalt | Stand |
|---|---|---|
| 1. Datenkette validieren | DWD-Radar, Punktprognose, Lizenz, Aktualität | erledigt für den Prototyp, siehe [Datenvertrag](datenvertrag.html) |
| 2. iPhone-App | Radar, Zeitleiste, Ortsprognose, Orte, Datenalter, Cache, Light/Dark | Prototyp in interner Beta (Build 9, Vorgänger Build 8) |
| 3. Interner TestFlight | Alltagstest, Rückmeldungen | läuft |
| 4. Radar-Cache-Backend anbinden | App nutzt Cache, DWD als Fallback | Backend läuft produktiv; Build 9 ist hochgeladen, Installierbarkeit und Gerätetest offen |
| 5. Widgets, Watch, iPad, Mac | Regen-Widgets, kompakte Watch-Prognose, angepasste Oberflächen | geplant |
| 6. Benachrichtigungen | Regenwarnungen mit datensparsamem Push | Entwurf, nach der nutzbaren App |
| 7. Später | Unterwegs-Warnungen, Wind-/Temperaturkarten, Wolken/Satellit, tvOS, visionOS (zuerst Simulator) | Ideen |

Vorgemerkt, nicht umgesetzt: ein adaptiver Abfragetakt für den Radar-Lauf. Er fragt kurz vor dem erwarteten neuen Lauf häufiger nach und sonst seltener, statt starr alle 60 Sekunden. Ein Websocket ist bewusst nicht vorgesehen.

Offen: Lizenzfreigabe (AGPLv3 angestrebt), Umfang der Watch-Radaransicht, genaue Widgetgrößen, vollständige Gerätetests (Energie, Accessibility). Regenwarnungen per Push (APNs) sollen später auf derselben Datenbasis aufsetzen.
