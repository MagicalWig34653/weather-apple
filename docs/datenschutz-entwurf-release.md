# Datenschutz-Entwurf für das Release (Seitentext und App-Privacy, Variante B)

Stand 7. November 2026. **ENTWURF zur Freigabe durch den Nutzer, NICHT live.** Weder `/datenschutz` im Backend noch `docs-site/content/datenschutz.md` noch App Store Connect wurden geändert. Dies ist keine Rechtsberatung; Rechtsgrundlagen, Impressum und Einordnung sind Vorschläge und vor Livegang rechtlich zu prüfen. Aussagen sind aus dem Code und den Repo-Dokumenten belegt; Unbekanntes steht in Teil C als Nutzerfrage und im Seitentext als `[ ... ]`.

Quellen (gelesen am 7.11.2026): Live-Seitenquelle `Sources/RadarCore/SitePages.swift` (Schwesterrepo, Methode `privacy`), Schwesterrepo `migrations/003, 006, 007, 010, 015`, `docs-site/content/api.md` (Push, Testmeldung, Live Activity, Kopplung, Warnungen), `PushService.swift` (Aufbewahrung), `PushMeasure.swift` (Dashboard), `docs/datenschutz-gebiets-live-activity.md`, `docs/decisions.md` beider Repos, `docs/app-store-release-checkliste.md`, `docs/superpowers/specs/2026-11-07-warnungen-design.md`, `docs/research/dwd-warnungen-weitergabe.md`, App-Code `Weather/Push/PushGateway.swift`, `Shared/Data/DWDClient.swift`.

## Empfehlungen vorab

1. **Warnungen** (Unwetter, Frost, Glatteis): **aus dem Release-Text weglassen** und erst mit dem Warn-Push als eigener Abschnitt ergänzen (Baustein in Teil E). Begründung: Der Push bleibt aus, bis der DWD geantwortet hat und der Text freigegeben ist; eine Datenschutzerklärung sollte den tatsächlichen Stand beschreiben, nicht geplante Funktionen. Die Anzeige der Warnungen in der App ruft die Aktivwarnungen ohne Ortsangabe ab (Spec §5), braucht also keinen neuen Abschnitt, nur die Quellenangabe (Abschnitt 14 unten).
2. **Rechtsgrundlage Push:** Einwilligung, Art. 6 Abs. 1 lit. a DSGVO (Opt-in, jederzeit widerrufbar). Das ist ein Vorschlag, der Betreiber entscheidet (offen als E7).
3. **App Privacy:** Variante A („Data Not Collected“) entfällt, sobald Push live ist. Variante B in Teil B. Wichtiger Prüfpunkt: Punkt-Abos speichern eine ~0,7-km-Zelle; ob das noch „Coarse Location“ ist, ist unsicher (Teil B, Punkt 2).

---

## Teil A: Vollständiger Seitentext (Vorschlag für `/datenschutz`)

Gestaltung wie bisher (Überschriften nummeriert, Du-Form). Platzhalter in eckigen Klammern.

> # Datenschutzerklärung
>
> Für die App Showers (iPhone, iPad, Apple Watch) und den zugehörigen Radar-Dienst. Stand: [Datum Livegang].
>
> ## 1. Verantwortlicher
>
> [Name, Anschrift, E-Mail des Betreibers, wie bisher aus der Betreiberkonfiguration]
>
> ## 2. Überblick
>
> - Kein Benutzerkonto, keine Werbung, kein Tracking, keine Analyse-SDKs.
> - Wer die App nur zum Ansehen von Radar und Prognose nutzt, erzeugt auf dem Radar-Dienst keine personenbezogene Kennung: Die Radar-Anfragen enthalten keinen Ort, keine Cookies und keine Kennung (Abschnitt 3).
> - Nur wenn du Regenhinweise einschaltest, registriert die App dein Gerät auf dem Radar-Dienst, mit einer zufälligen Installationskennung, dem Gerätetoken für Mitteilungen und dem gewählten, gröber gerundeten Ort oder Gebiet (Abschnitt 5). Das ist freiwillig und jederzeit in der App widerrufbar.
> - Gespeicherte Orte mit ihren Namen und deine Einstellungen bleiben auf deinem Gerät. Der Ortsname in einer Mitteilung wird auf dem Gerät angehängt (Abschnitt 5).
> - Betriebsstatistik nur als aggregierte, personenlose Zähler; Geräte-Diagnose nur freiwillig und nur nach Freigabe des Betreibers (Abschnitte 10 und 11).
>
> ## 3. Radarkarte und Radar-Dienst
>
> Die App lädt die Radarbilder für ganz Deutschland vom Showers-Radar-Dienst. Die Anfragen enthalten keinen Ort: Es gibt feste Pfade je Radarlauf und Zeitschritt (Ganzbild für Deutschland), keine Cookies und keine Kennung.
>
> Der Radar-Dienst selbst führt keine Zugriffsprotokolle und speichert keine IP-Adressen oder Abfragedetails. Seine technischen Logs enthalten nur Lauf-Kennungen und Fehlerklassen. Das gilt auch für die Push-Schnittstelle des Dienstes. Auch die Begrenzung der Anfragezahl arbeitet ohne IP-Adresse (je Installationskennung beziehungsweise insgesamt).
>
> Dem Radar-Dienst ist ein Reverse Proxy (TLS, Weiterleitung) vorgeschaltet. Dieser sieht technisch bedingt die IP-Adresse jedes Abrufs. [Proxy-Protokollierung: Betreiberangabe, siehe Teil C Frage 1. Mögliche Fassungen: „Er protokolliert keine Zugriffe.“ oder „Er protokolliert Zugriffe ohne bzw. mit gekürzter IP-Adresse für höchstens [n] Tage zur Störungsabwehr.“]
>
> Zusätzlich zeigt die App Karten für Luftdruck, Blitze und Wolken beziehungsweise Sonne. Diese Bilder kommen ebenfalls vom Radar-Dienst, ohne Ort. Sie beruhen auf Daten des DWD und, für Wolken und Sonne, auf Satellitendaten von EUMETSAT (Abschnitt 14). Der Radar-Dienst ruft diese Daten bei den Quellen ab; dabei werden keine Nutzerdaten übermittelt.
>
> ## 4. Direktabruf beim Deutschen Wetterdienst
>
> Antwortet der Radar-Dienst nicht oder sind seine Daten älter als 20 Minuten, ruft die App die Radarbilder direkt beim Deutschen Wetterdienst (DWD) ab. Der DWD sieht dann den abgefragten Kartenausschnitt und, wie bei jeder Internetverbindung, deine IP-Adresse. Es gelten die Datenschutzhinweise des DWD.
>
> Die Punktprognose für einen Ort fragt die App direkt beim DWD ab, ebenso die Widgets und die Apple Watch für deine gespeicherten Orte. Dabei sind der abgefragte Punkt und die IP-Adresse für den DWD sichtbar. Der Radar-Dienst erhält diese Orte nicht.
>
> ## 5. Regenhinweise, Gebiete und Live Activities (optional)
>
> Wenn du in der App Regenhinweise für einen Ort oder ein Gebiet (Umkreis) einschaltest, kann dich der Radar-Dienst auch bei geschlossener App benachrichtigen („Regen beginnt in N Minuten“, „Regen erreicht dein Gebiet“). Ohne diese Funktion wird nichts davon gespeichert.
>
> **Welche Daten gespeichert werden.** Auf dem Server werden gespeichert:
>
> - eine zufällige Installationskennung und der Hash eines Geheimnisses, mit dem sich die App beim Server ausweist (das Geheimnis selbst liegt nur im Schlüsselbund deines Geräts);
> - das Gerätetoken für Apple Push-Mitteilungen (APNs), die Umgebung (Entwicklung oder Produktion) und die Sprache (Deutsch oder Englisch);
> - je Regenhinweis: bei einem Ort die Rasterzelle des Radarbildes, in der er liegt (Kantenlänge etwa 0,7 km, keine Koordinate, kein Ortsname); bei einem Gebiet der Mittelpunkt, auf einen Block von etwa 2 km gerundet, und der Radius (5, 10 oder 25 km); außerdem Schwelle, Vorlauf (10, 20 oder 30 Minuten), bei Gebieten der Mindestanteil, ob der Hinweis zeitkritisch zugestellt werden soll, ob eine Live Activity gewünscht ist, der Zustand der Regelauswertung sowie Zeitpunkte (angelegt, zuletzt gesehen, zuletzt gesendet);
> - bei eingeschalteter Live Activity der Start-Token deines Geräts und je Regenhinweis ein Activity-Token. Die Live Activity zeigt nur Zeiten, Regenklasse und bei Gebieten den Anteil nasser Fläche, keinen Ortsnamen und keine Koordinaten. Je Gerät läuft höchstens eine Live Activity gleichzeitig; ein Activity-Token wird spätestens nach acht Stunden, beim Ausschalten oder beim Löschen des Regenhinweises entfernt;
> - kurzzeitig der zu sendende Mitteilungstext in einer Warteschlange (siehe Speicherdauer).
>
> Du kannst bis zu 10 Regenhinweise je Installation anlegen, davon bis zu 3 Gebiete. Die Rasterzelle kann je nach Lage personenbezogen sein, weil sie zusammen mit der Installationskennung einem Gerät zugeordnet ist. Es wird kein Standortverlauf angelegt: gespeichert ist je Regenhinweis nur der aktuelle Wert.
>
> **Ortsnamen bleiben auf dem Gerät.** Den Namen deines Ortes oder Gebietes kennt der Server nicht. Die Mitteilung enthält eine Kennung des Regenhinweises (die der Server als Thread-Kennung mitsendet) und die Minuten; eine kleine Erweiterung der App (Notification Service Extension) hängt den Namen aus einer lokalen Tabelle auf deinem Gerät an den Text an.
>
> **Testmeldung.** In den Einstellungen kannst du eine Testmeldung auslösen. Sie geht an das Gerätetoken deiner Installation, enthält einen festen Text ohne Ort und wird nicht gespeichert (höchstens 3 je Stunde).
>
> **Empfänger Apple.** Mitteilungen und Live Activities werden über Apple Push Notification Service zugestellt. Dafür erhält Apple vom Server das Gerätetoken und den Mitteilungstext. Es gelten die Datenschutzbestimmungen von Apple.
>
> **Speicherdauer und Löschung.** Wenn du einen Regenhinweis löschst oder die Funktion ausschaltest, löscht die App die Registrierung auf dem Server; damit werden Installation, Regenhinweise, Activity-Daten und wartende Mitteilungen gelöscht. Meldet Apple ein Gerätetoken als ungültig (zum Beispiel nach Löschen der App), löscht der Server die Registrierung sofort. Registrierungen, die 60 Tage lang nicht mehr von der App gemeldet wurden, werden automatisch gelöscht. Wartende oder versendete Mitteilungen in der Warteschlange werden nach etwa 6 Stunden entfernt. [Datensicherungen: Betreiberangabe, Teil C Frage 4.]
>
> **Rechtsgrundlage.** Deine Einwilligung (Art. 6 Abs. 1 lit. a DSGVO), die du mit dem Einschalten erteilst und durch Ausschalten oder Löschen jederzeit mit Wirkung für die Zukunft widerrufen kannst. [Rechtliche Prüfung, Teil C Frage 3.]
>
> ## 6. Standort und gespeicherte Orte
>
> Der Standortzugriff ist optional und wird erst angefragt, wenn du den Standort verwenden willst. Es gibt keine Hintergrundortung und keine Standortverläufe. Der Standort verbleibt auf dem Gerät; für die Prognose wird nur der Punkt an den DWD gesendet (Abschnitt 4). Gespeicherte Orte und ihre Namen liegen lokal auf dem Gerät (auch für Widgets und Apple Watch über die App-Gruppe des Geräts). Nur wenn du für einen Ort Regenhinweise einschaltest, geht dessen Rasterzelle an den Radar-Dienst (Abschnitt 5).
>
> ## 7. Kartenansicht und Ortssuche (Apple)
>
> *(unverändert gegenüber dem bisherigen Abschnitt 6, ergänzt um die Apple Watch:)* Die Karte und die Ortssuche der App nutzen Apple MapKit. Für die Basiskarte ruft dein Gerät die Kartendaten des angezeigten Ausschnitts von Apple ab. Wenn du nach einem Ort suchst, sendet die App deinen Suchtext und einen festen Suchbereich (Deutschland, nicht dein Standort) an Apple. Dabei sieht Apple technisch bedingt deine IP-Adresse. Der Suchtext geht nicht an den Radar-Dienst und nicht an den DWD. Der Kartenhintergrund der Radarkarte auf der Apple Watch wird über Apple Karten geladen; dabei geht die Koordinate des Ortes an Apple. Die Verarbeitung durch Apple richtet sich nach den Datenschutzbestimmungen von Apple.
>
> Ein Punkt, den du per Suche, langem Druck auf die Karte oder über die Standortfunktion wählst, wird nur lokal auf dem Gerät gespeichert. An den DWD geht für die Prognose lediglich dieser Punkt. Der Radar-Dienst erhält einen Ort nur im Fall von Abschnitt 5.
>
> ## 8. Lokale Einordnung
>
> Die kurze Einordnung der Regenlage erstellt Apple Foundation Models auf dem Gerät. Dabei werden keine Koordinaten oder Ortsnamen an Dritte gesendet.
>
> ## 9. Apple Watch, Widgets und Live Activities
>
> Widgets, Apple Watch und Live Activities nutzen die gespeicherten Orte und Einstellungen auf deinem Gerät. Die Prognose für Widgets und Watch wird wie in Abschnitt 4 direkt beim DWD abgerufen. Der Server erfährt davon nichts, außer du hast Regenhinweise oder Live Activities eingeschaltet (Abschnitt 5).
>
> ## 10. Betriebsstatistik des Radar-Dienstes
>
> *(unverändert gegenüber dem bisherigen Abschnitt 8)* Der Radar-Dienst zählt für den Betrieb aggregierte, personenlose Werte: zum Beispiel Anfragen je Routengruppe und Statusklasse, Antwortzeiten in groben Klassen, Abruf- und Fehlerzähler der Datenquellen sowie Ergebnisse des Push-Versands. Es werden weder IP-Adressen noch Orte, Geräte- oder Installationskennungen gezählt. Die Zähler liegen tageweise (30 Tage) und als Stundenzähler (72 Stunden) in der Datenbank und werden danach gelöscht. Der Zugriff darauf ist nur dem Betreiber über ein geschütztes Dashboard möglich.
>
> ## 11. Betreiber-Diagnose (nur auf Freigabe des Betreibers, freiwillig)
>
> *(unverändert gegenüber dem bisherigen Abschnitt 9, ergänzt um den letzten Punkt:)* Der Betreiber kann ein Gerät zur Fehlersuche bei Regenhinweisen und Live Activities koppeln. Das ist standardmäßig aus, nur in den Einstellungen der App einschaltbar und nur möglich, solange der Betreiber dafür im Dashboard kurzzeitig (standardmäßig 5 Minuten) ein Kopplungsfenster geöffnet hat; außerhalb des Fensters zeigt die App die Funktion nicht an.
>
> - Beim Einschalten zeigt die App einen kurzen Koppelcode (10 Minuten gültig, einmal verwendbar), den der Betreiber im Dashboard eingibt und dem Gerät dabei eine eigene Bezeichnung gibt.
> - Der Code wird nur im Kopplungsfenster ausgegeben und ist nur nutzbar, wenn sich der Betreiber im Dashboard mit seinem Passkey angemeldet hat. Es wird kein Beleg von Apple (StoreKit) übertragen oder gespeichert.
> - Gespeichert werden die Zuordnung zur Push-Registrierung des Geräts, die Bezeichnung, Zeitpunkte (Kopplung, zuletzt gesehen) und ein Verlauf technischer Versandergebnisse der letzten 48 Stunden (zum Beispiel Testmitteilung zugestellt oder von Apple abgelehnt).
> - Für ein gekoppeltes Gerät sieht der Betreiber im Dashboard dessen Regenhinweise samt der gerundeten Position der Rasterzelle (Mittelpunkt, auf etwa 1 km gerundet) und die aktuelle Auswertung. Andere Geräte sind im Dashboard nicht einzeln sichtbar.
> - Die Kopplung gilt bis zum Widerruf. Du kannst sie jederzeit durch Ausschalten in der App widerrufen; dabei wird sie auf dem Server gelöscht. Der Betreiber kann sie ebenfalls entfernen. Höchstens drei Geräte können gleichzeitig gekoppelt sein.
> - Der Betreiber kann dem gekoppelten Gerät Testmeldungen und eine Test-Live-Activity senden.
>
> ## 12. Keine Debuglogs mit Personenbezug
>
> Die App protokolliert keine URLs, Standorte oder Fehler-Rohdaten. Zwischenspeicher liegen im Arbeitsspeicher beziehungsweise lokal auf dem Gerät. Der Radar-Dienst beobachtet den Push-Betrieb nur über feste, aggregierte Zähler ohne Token, Orte oder Kennungen.
>
> ## 13. Deine Rechte
>
> Dir stehen nach der Datenschutz-Grundverordnung (DSGVO) insbesondere die Rechte auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch zu (Art. 15 bis 21 DSGVO) sowie das Recht, eine erteilte Einwilligung jederzeit mit Wirkung für die Zukunft zu widerrufen. Zudem kannst du dich bei einer Datenschutz-Aufsichtsbehörde beschweren. Am einfachsten löschst du deine Daten auf dem Server selbst: Schalte alle Regenhinweise in der App aus oder lösche sie. Da die Installationskennung nur auf deinem Gerät liegt, kann der Betreiber Daten auf Anfrage nur zuordnen, wenn du die Installationskennung nennst [Hinweis zur Auskunft: Betreiber prüft, ob die App die Kennung anzeigen soll, Teil C Frage 5]. Wende dich für Anfragen an die oben genannte Stelle.
>
> ## 14. Quellen
>
> Quelle: Deutscher Wetterdienst. Die Radarbilder sind aus Rasterdaten des DWD bildlich wiedergegeben und aufbereitet. Wolken- und Sonnenkarten: Contains modified EUMETSAT Meteosat data 2026 (EUMETSAT, Jahr der Veröffentlichung der Daten; Jahr anpassen). Kartenhintergrund: Apple Karten.

---

## Teil B: App-Privacy-Angaben in App Store Connect (Variante B)

Beantwortung des Fragebogens „App-Datenschutz“ für den Fall, dass Push, Gebiete und Live Activities live sind. **Kategorienamen und Definitionen sind aus Apple-Wissen, in Connect nicht gesehen und nicht gegen die aktuelle Apple-Seite geprüft.** Kein Rechtsrat.

Frage „Erfasst ihr oder Drittpartner Daten aus dieser App?“: **Ja** (Variante A „Keine Daten erfasst“ entfällt, da Gerätetoken und Zelle serverseitig gespeichert werden; Daten, die nur auf dem Gerät bleiben oder nur kurz im Speicher verarbeitet werden, zählen nicht).

| # | Datentyp (Kategorie) | Erfasst? | Mit der Identität verknüpft? | Tracking? | Zweck | Grundlage im Code |
|---|---|---|---|---|---|---|
| 1 | Kennungen > **Geräte-ID** | Ja: Gerätetoken (APNs), Installations-UUID, Start-/Activity-Token | Ja (Kennung identifiziert die Installation; konservativ „verknüpft“) | Nein | App-Funktionalität | `push_install`, `push_activity`, `la_start_token` |
| 2 | Standort > **Grober Standort** | Ja: Rasterzelle (Ort) bzw. auf ~2 km gerundeter Mittelpunkt und Radius (Gebiet) | Ja (zusammen mit Installations-UUID gespeichert) | Nein | App-Funktionalität | `push_sub.cell_x/y`, `radius_cells` |
| 3 | alle übrigen Kategorien | Nein | - | - | - | siehe unten |

Hinweise zu den einzelnen Punkten:

1. **Geräte-ID:** Der Server speichert kein IDFA/IDFV, sondern eine selbst erzeugte Installations-UUID plus das APNs-Token. Apple fasst auch solche geräte-/installationsbezogenen Kennungen unter „Device ID“; Vorschlag: so deklarieren.
2. **Grober vs. genauer Standort (offener Prüfpunkt):** Das Gebiet (3x3-Block ≈ 2 km, Kantenlänge) ist grob. Eine Punkt-Zelle (Kante ≈ 0,7 km, Mittelpunkt auf zwei Dezimalstellen ≈ 1 km) liegt unter der Größenordnung, die Apple für „Coarse“ nennt (nach meiner Erinnerung Fläche von mindestens ~3 km² beziehungsweise weniger als drei Dezimalstellen bei Breite/Länge; **nicht geprüft**). Empfehlung: vor dem Ausfüllen die aktuelle Apple-Definition prüfen. Ist die Auslegung unsicher, ist „Genauer Standort“ die vorsichtigere Wahl; der Nutzer entscheidet (Teil C Frage 7). Alternativ ließe sich die Punktzelle serverseitig auf 3x3 runden (Produktänderung, nicht beauftragt).
3. **Verknüpfung:** Die Daten hängen an der Installations-UUID, es gibt aber kein Konto und keine Verbindung zu Name, E-Mail oder Apple-ID. Ob „mit Identität verknüpft“ angekreuzt wird, ist Auslegungssache; wegen der dauerhaft gespeicherten Kennung (bis zu 60 Tage Inaktivität) ist „Ja, verknüpft“ die vorsichtige Angabe.
4. **Tracking:** Nein. Keine Verknüpfung mit Daten Dritter, keine Weitergabe an Datenhändler, keine Werbung, kein Tracking-Domain-Eintrag nötig.
5. **Zweck:** nur „App-Funktionalität“ (Regenhinweise, Live Activities). Nicht: Analyse, Werbung, Personalisierung, Produktentwicklung.
6. **Nicht erfasst:** Kontaktdaten, Gesundheit, Finanzen, Nutzerinhalte, Browserverlauf, Suchverlauf (der Suchtext geht an Apple MapKit, nicht an den Betreiber), Käufe, Nutzungsdaten (nur aggregierte Zähler ohne Kennung), Diagnosedaten (kein Crash-SDK; Apples eigene TestFlight-/App-Store-Berichte zählen nicht zur App), Sensible Daten, Sonstige Daten.
7. **Betreiber-Diagnose (Kopplung):** Zusätzliche Datensätze (Bezeichnung des Geräts, Zeitpunkte, 48-h-Versandverlauf) hängen an derselben Installation. Die Bezeichnung ist eine vom Betreiber vergebene Gerätebezeichnung; sie ist in den Kategorien oben mit abgedeckt (Geräte-ID, kein neuer Datentyp). Nutzerprüfung, falls die Bezeichnung personenbezogen vergeben wird.
8. **Warnungen (später):** Warngebiets-IDs (Gemeinde) sind dem Standort (grob) zuzuordnen, Kategorien voraussichtlich unverändert (Spec §5). Bei Push-Livegang erneut prüfen.
9. **Zusätzlich im Projekt (Agent-Aufgabe, nicht Teil dieses Entwurfs):** `PrivacyInfo.xcprivacy` je Target mit UserDefaults-Gründen (CA92.1, 1C8F.1), Release-Checkliste Blocker.

---

## Teil C: Fragen, die nur der Nutzer beantworten kann

| # | Frage | Warum / Stand |
|---|---|---|
| 1 | **Reverse Proxy (Zoraxy): Wird protokolliert? Mit voller, gekürzter oder ohne IP? Wie lange?** | Im Repo nicht belegt; Seite sagt heute „noch nicht angegeben“. Davon hängt der Satz in Abschnitt 3 ab. Empfehlung: ohne IP-Protokoll oder höchstens kurz, dann ist eine Fassung ohne Aufbewahrungsdauer möglich. |
| 2 | **Verantwortlicher und Impressum:** Name, Anschrift, E-Mail (aus `OPERATOR_*`), Pflicht zu Impressum? `/impressum` liefert 404. | Rechtliche Einordnung offen (E7). |
| 3 | **Rechtsgrundlage bestätigen:** Einwilligung Art. 6 Abs. 1 lit. a für Push/Live Activity; für die technische Verarbeitung der IP am Proxy üblicherweise berechtigtes Interesse lit. f. | Vorschlag, keine Rechtsprüfung. |
| 4 | **Datensicherungen:** Sichert ihr die Datenbank (Rhythmus, Aufbewahrung)? Wo wird gehostet (Land/Anbieter, Auftragsverarbeitung)? | Im Repo nicht belegt; erscheint nicht im Text, bis beantwortet. |
| 5 | **Auskunft:** Soll die App die Installationskennung anzeigen (Auskunft/Löschung auf Anfrage), oder genügt „in der App ausschalten“? | Ohne Kennung kann der Betreiber nichts zuordnen. |
| 6 | **Speicherdauer bestätigen:** 60 Tage Inaktivität, Outbox 6 h, Zähler 30 Tage/72 Stunden, Kopplung bis Widerruf, 48-h-Verlauf. | Aus dem Code übernommen (E6 entschieden). |
| 7 | **App Privacy:** Punkt-Zelle als „Coarse“ oder „Precise Location“ deklarieren? Verknüpft ja/nein? | Teil B Punkt 2 und 3. Evtl. in Connect gegen aktuelle Apple-Definition prüfen. |
| 8 | **Englische Fassung:** Soll `/datenschutz` auch auf Englisch erscheinen? | Heute nur deutsch; Info-Sheet ist de/en. |
| 9 | **Warnungen:** Weglassen bis Warn-Push (Empfehlung) oder als „geplant“ ausweisen? | Teil E. |
| 10 | **Dashboard-Einsicht:** Ist die Aussage in Abschnitt 11 (Betreiber sieht die gerundete Position der Rasterzelle eines gekoppelten Geräts) so gewollt veröffentlicht? | Belegt in `PushMeasure.swift`/`dashboard-api.md`; bislang nicht im Live-Text. |
| 11 | **EUMETSAT-Jahr in der Quellenangabe** und Wortlaut der Attribution. | Policy-Text gelesen, Wortlaut „Contains modified EUMETSAT Meteosat data [Jahr]“; Jahr anpassen. |

---

## Teil D: Abweichungen zum jetzigen Live-Text (Stand `SitePages.swift`, 7.11.2026)

| Live | Entwurf | Grund |
|---|---|---|
| „Für die App Showers (iPhone, iPad)“ | + Apple Watch | Watch-App vorhanden |
| Überblick: „Der Radar-Dienst setzt keine Cookies und vergibt keine Kennung.“ | eingeschränkt auf „nur ansehen“; Push mit Installationskennung | Push vergibt UUID, Token, Zelle |
| Überblick: „Gespeicherte Orte und Einstellungen bleiben auf deinem Gerät.“ | zusätzlich Ausnahme Rasterzelle bei Regenhinweisen | Datenänderung durch Push |
| Abschnitt 3 | zusätzlich Push-Schnittstelle (kein Zugriffsprotokoll im Dienst), Ebenen Luftdruck/Blitze/Wolken/Sonne, EUMETSAT | Push-API im selben Dienst; Zusatzebenen live |
| Abschnitt 4 | + Widgets und Watch rufen Prognose beim DWD ab | `Shared/Data/DWDClient.swift` |
| Abschnitt 5 „Standort und gespeicherte Orte“ (alt) | neuer Abschnitt 5 „Regenhinweise, Gebiete, Live Activities“ (alle Daten, Empfänger Apple, Speicherdauer, Rechtsgrundlage); alter Abschnitt wird 6 | Hauptänderung |
| Abschnitt 6 Apple-Karte | + Apple Watch Kartenhintergrund (Koordinate an Apple); Satz „Radar-Dienst erhält keinen Ort“ mit Ausnahme Abschnitt 5 | App-Build 16; Status 4.11. |
| - | neu: Abschnitt 9 Watch/Widgets/Live Activities | Funktionen vorhanden |
| Abschnitt 9 alt (Betreiber-Diagnose) = 11 neu | + Dashboard sieht gerundete Zelle des gekoppelten Geräts; Test-Live-Activity | `PushMeasure.swift`, `api.md` |
| Abschnitt 10 alt = 12 neu | + Push nur über feste Zähler | Beobachtungsdesign (`PushObserver`) |
| Abschnitt 11 alt = 13 neu | + Widerruf der Einwilligung, Löschung durch Ausschalten, Hinweis zur Zuordnung | Art. 7 Abs. 3 DSGVO, kein Konto |
| Abschnitt 12 alt = 14 neu | + EUMETSAT-Attribution, Apple Karten | EUMETSAT-Klärung 31.10. |
| Warnungen | nicht enthalten | Empfehlung, Teil E |

Nicht in den Entwurf übernommen, weil nicht belegt: Hosting-Ort, Backups, Proxy-Logging.

---

## Teil E: Baustein „Warnungen“ (erst bei Livegang des Warn-Push, nicht Teil des Release-Texts)

Bereit zum Einfügen, sobald `warnings_push` aktiviert wird (nach DWD-Antwort und Freigabe):

> **Amtliche Warnungen (optional).** Wenn du Warnungen vor Unwetter, Frost oder Glatteis einschaltest, speichert der Server zusätzlich die Warngebiets-Kennungen (Gemeinden) deiner Orte und Gebiete, die gewünschten Warnarten und die Mindeststufe, jeweils mit deiner Installationskennung. Koordinaten und Ortsnamen speichert der Server dafür nicht; die Zuordnung deines Ortes zu einer Gemeinde geschieht auf deinem Gerät. Die aktuellen Warnungen ruft die App ohne Ortsangabe ab. Löschung wie bei Regenhinweisen (Abmeldung, ungültiges Token, 60 Tage Inaktivität). Quelle der Warnungen: Deutscher Wetterdienst. Die App ersetzt keine offiziellen Warnkanäle; im Notfall wähle 112.

Hinweis: Die Kombination aus Regenhinweis-Zelle und Warngemeinde derselben Installation ist ein etwas genaueres Merkmal (Spec §5); die Kategorien in App Privacy bleiben voraussichtlich Geräte-ID und grober Standort.

## Nicht geprüft

Ob die Live-Seite exakt dem Quellcode entspricht (nur Quellcode gelesen, Seite nicht abgerufen); App Store Connect; aktuelle Apple-Definitionen zu Coarse/Precise Location und „linked to identity“; rechtliche Würdigung; ob Widgets Apple-Karten nutzen (nur Watch belegt); Verhalten des Reverse Proxys; Sprachliche Passung in EN.
