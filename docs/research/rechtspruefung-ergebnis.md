# Rechtsprüfung Datenschutz, Impressum, Berechtigungstexte: Ergebnis (12.11.2026)

> **Keine Rechtsberatung, sondern eine KI-gestützte Plausibilitätsprüfung.** Sie ersetzt keine anwaltliche Prüfung. Die Einschätzungen beruhen auf den Repo-Texten (Stand `origin/main` 5b08b43) und den unten genannten Quellen.

Geprüft wurden Teil A, B, C und G von [datenschutz-entwurf-release.md](../datenschutz-entwurf-release.md), [decisions.md](../decisions.md) (Push, Datenschutz, Diagnose), [dwd-warnungen-weitergabe.md](dwd-warnungen-weitergabe.md), die In-App-Texte (`Weather/Resources/de.lproj/Localizable.strings`: `INFO_PRIVACY_*`, `PUSH_*`, `REGION_*`, `DEVICE_LINK_*`, `RAIN_ACTIVITY_*`) sowie die Berechtigungstexte (`NSLocationWhenInUseUsageDescription` in `Configuration/Info.plist` und `InfoPlist.strings` de/en). Das Briefing [rechtspruefung-briefing.md](rechtspruefung-briefing.md) legt die Fragenliste fest. Gegenüber Teil G ist die Frage „Englische Fassung“ entfallen, weil es keine englische Seite gibt; dafür ist „Lizenzen“ hinzugekommen.

**Nicht im Repo:** Den Impressums- und den Support-Seitentext gibt es nur im Backend (`SitePages.swift`, Schwesterrepo). Beide wurden nicht gelesen, Live-Seiten wurden nicht abgerufen. Zu Impressum und Support lassen sich deshalb nur die Anforderungen prüfen, nicht der Wortlaut.

Legende: **B** = bestätigt (Primärquelle gelesen), **A** = Annahme/Auslegung, **H** = Hypothese, ungeprüft.

## Übersicht

| # | Frage | Einschätzung | Risiko |
|---|---|---|---|
| 1 | Proxy-Logs: Dauer, Rechtsgrundlage, Text | nachbessern (vor Livegang) | hoch |
| 2 | Proxy-Logs mit Pfaden / App Privacy | nachbessern | mittel |
| 3 | Rechtsgrundlage Push/Live Activity, Hinweis vorher | nachbessern | gering |
| 4 | § 25 TDDDG (Schlüsselbund, Token, UserDefaults) | unkritisch | gering |
| 5 | Apple (APNs, MapKit), Drittland | nachbessern | gering |
| 6 | Betreiber-Diagnose | nachbessern (App-Text widerspricht der Seite) | mittel |
| 7 | Hetzner-AVV | nachbessern (AVV abschließen) | mittel |
| 8 | Impressum § 5 DDG, Anschrift | nachbessern; bei Wunsch nach Adressschutz Anwalt empfohlen | mittel |
| 9 | Datenschutzbeauftragter | unkritisch | gering |
| 10 | Direktabrufe DWD/EUMETSAT/MapKit | nachbessern (Rechtsgrundlage ergänzen) | gering |
| 11 | Rasterzelle als personenbezogenes Datum | nachbessern | gering |
| 12 | Lizenzen DWD, Warnungen, EUMETSAT | unkritisch, kleine Ergänzung | gering |

Zusätzlich gefunden: Die öffentliche Doku-Seite `docs-site/content/datenschutz.md` (GitHub Pages, Stand Build 11) beschreibt den Stand vor Push („Radar-Anfragen … keine Kennung“, Regenhinweise nur „geplant“). Sie konkurriert mit der eigentlichen Datenschutzerklärung (siehe Entscheidung E8). Die Berechtigungstexte sind unkritisch (Abschnitt „Berechtigungstexte“).

## 1. Proxy-Logs: Dauer, Rechtsgrundlage, Text Abschnitt 3

**Befund.** Teil A Abschnitt 3 sagt nur, der Proxy protokolliere die IP-Adresse „befristet“. Art. 13 Abs. 2 lit. a DSGVO verlangt aber die Speicherdauer oder die Kriterien dafür (B, Gesetzestext). „Befristet“ nennt weder das eine noch das andere. Die tatsächliche Rotation ist größenbasiert und reicht laut Teil C bis rund 14 Monate. Für Betrieb und Missbrauchsabwehr lässt sich das kaum als erforderlich begründen (Art. 5 Abs. 1 lit. c und e DSGVO). Üblich und in der Rechtsprechung für Störungsbeseitigung anerkannt sind etwa 7 Tage (A; BGH III ZR 391/13 zu Zugangsanbietern, aus Kenntnis, nicht abgerufen). IP-Adressen sind personenbezogen (A; EuGH C-582/14 „Breyer“, aus Kenntnis). Art. 6 Abs. 1 lit. f als Rechtsgrundlage ist plausibel. Den nach Art. 21 Abs. 4 gesondert nötigen Hinweis auf das Widerspruchsrecht enthält Abschnitt 8 bereits.

**Risiko: hoch**, falls die Seite mit der jetzigen Rotation und ohne Frist live geht. Das ist der greifbarste Verstoß im Text, nämlich eine fehlende Pflichtangabe zusammen mit einer unverhältnismäßigen Frist.

**Quellen.** DSGVO Art. 5, 6, 13, 21: https://eur-lex.europa.eu/legal-content/DE/TXT/?uri=CELEX:32016R0679 (Wortlaut aus Kenntnis, am 12.11.2026 nicht abgerufen).

**Textänderung** (erst nachdem die Frist am Zoraxy umgestellt ist):
- Vorher: „Technisch bedingt sieht er die IP-Adresse jedes Abrufs und protokolliert sie befristet.“
- Nachher: „Technisch bedingt sieht er die IP-Adresse jedes Abrufs und protokolliert sie zusammen mit Zeitpunkt, Adresse der Anfrage und Statuscode. Die Protokolle werden nach 7 Tagen automatisch gelöscht.“ (Statt 7 kann eine andere Zahl stehen, siehe Entscheidung E1.)
- `INFO_PRIVACY_3` in der App („befristet protokolliert“) kann bleiben, wenn die Seite die Frist nennt. Besser wäre beim nächsten Build „… und nach 7 Tagen löscht“.

## 2. Proxy-Logs mit Pfaden (Installationskennung) und App Privacy

**Befund.** Push-Aufrufe gehen über denselben Proxy und tragen die Installationskennung im Pfad (`/v1/push/installations/<uuid>/…`, laut `decisions.md`). Protokolliert Zoraxy Pfade, liegen IP, Zeitpunkt und Installationskennung zusammen im Log. Ob Zoraxy Pfade protokolliert, ließ sich nicht belegen (H). Zum Logformat fand die Suche keine Doku; der Logging-Teil von Zoraxy ist im README als „Looking for Maintainer“ markiert. Bei Apple gilt: Eine IP-Adresse, die länger gespeichert wird, als die Anfrage zu bedienen dauert, ist „collected“. Apple verlangt dann eine Angabe „based on how you use IP address, such as precise location, coarse location, device ID, or diagnostics“ (B). Daten, die nach Datenschutzrecht personenbezogen sind, gelten bei Apple als „linked“ (B). Teil B Punkt 10 führt die Proxy-Logs bislang bewusst nicht auf. Das ist nach der Apple-Definition nicht haltbar, solange der Proxy IPs speichert.

**Risiko: mittel.** Eine unvollständige App-Privacy-Angabe kann zu Nachfragen in der App-Prüfung oder später zur Beanstandung führen. Die Seite muss zudem nennen, dass Pfade die Installationskennung enthalten können.

**Quelle.** Apple, App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/ (abgerufen 12.11.2026). Zoraxy-Repo: https://github.com/tobychui/zoraxy (nur Suchtreffer, 12.11.2026).

**Textänderung.**
- Teil A Abschnitt 3, an den neuen Satz aus Frage 1 anhängen: „Bei Regenhinweisen enthält die Adresse der Anfrage deine Installationskennung (Abschnitt 5); auch sie steht dann im Protokoll.“ (Nur nötig, wenn Zoraxy Pfade protokolliert; sonst weglassen.)
- Teil B, neue Zeile (Variante, solange IPs gespeichert werden): „Diagnose > Sonstige Diagnosedaten | Ja: IP-Adresse und Anfrage im Proxy-Protokoll (7 Tage) | Ja | Nein | App-Funktionalität (Betrieb, Sicherheit)“. Entfällt, wenn der Proxy keine IP oder nur gekürzte IPs speichert (Entscheidung E2).

## 3. Rechtsgrundlage Push/Live Activity; Hinweis vor dem Einschalten

**Befund.** Die Einwilligung nach Art. 6 Abs. 1 lit. a ist vertretbar und passt zum Opt-in je Ort. Lit. b (Nutzungsverhältnis) wäre ebenfalls denkbar und würde Nachweis- und Freiwilligkeitsfragen vermeiden (A). Ein Wechsel ist nicht nötig, wenn die Einwilligung sauber eingeholt wird. Die App zeigt vor der Systemabfrage einen Bestätigungsdialog mit „Datenschutzerklärung lesen“ (`PUSH_PLACE_CONFIRM_MESSAGE`, `REGION_EXPLANATION`). Das ist eine gute Basis. Zwei Lücken: (a) Der Dialog nennt die Installationskennung nicht, obwohl sie übertragen wird (die Fußnote `PUSH_PLACE_PRIVACY` nennt sie). (b) Ein Hinweis auf den Widerruf vor der Einwilligung fehlt. Art. 7 Abs. 3 Satz 3 DSGVO verlangt ihn. Apple 5.1.1(ii) verlangt Einwilligung und einen leicht zugänglichen Widerruf (B). 4.5.4 betrifft nur Werbe-Push und ist nicht einschlägig (B). Für Live Activities nennt `RAIN_ACTIVITY_PRIVACY` die zusätzlichen Token; das ist ausreichend.

**Risiko: gering.** Die Textlücke betrifft App-Code und braucht einen Build.

**Quelle.** App Review Guidelines 5.1.1, 5.1.2, 4.5.4: https://developer.apple.com/app-store/review/guidelines/ (abgerufen 12.11.2026). DSGVO Art. 7 (s. o.).

**Textänderung (App, nächster Build).**
- `PUSH_PLACE_CONFIRM_MESSAGE` vorher: „… Dafür gehen an den Showers-Server: das Gerätetoken, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km, keine Koordinaten), Schwelle und Vorlaufzeit; kein Konto. Danach fragt iOS, ob Mitteilungen erlaubt sind.“
- Nachher: „… Dafür gehen an den Showers-Server: das Gerätetoken, eine zufällige Installationskennung, die Rasterzelle des Radarbildes (Kantenlänge etwa 0,7 km), Schwelle und Vorlaufzeit; kein Konto. Mit „Weiter“ willigst du ein. Du kannst das jederzeit ausschalten, dann werden die Daten auf dem Server gelöscht. Danach fragt iOS, ob Mitteilungen erlaubt sind.“
- `REGION_EXPLANATION`: dieselben zwei Ergänzungen, also „eine zufällige Installationskennung“ und den Satz zum Widerruf.

## 4. § 25 TDDDG (Schlüsselbund, APNs-Token, UserDefaults)

**Befund.** Nach § 25 Abs. 2 Nr. 2 TDDDG ist keine Einwilligung nötig, wenn Speichern oder Zugreifen unbedingt erforderlich ist, damit der Anbieter einen ausdrücklich gewünschten digitalen Dienst bereitstellen kann (B). Gespeicherte Orte und Einstellungen in UserDefaults, die Installationskennung mit Geheimnis im Schlüsselbund und das Abrufen des APNs-Tokens geschehen nur, damit Funktionen laufen, die der Nutzer selbst einschaltet. Sie dienen keinem Dritt- oder Analysezweck. Die Ausnahme greift daher plausibel (A). Die DSK legt Nr. 2 eng aus; Push-Token behandelt ihre Orientierungshilfe nach dem Suchergebnis nicht ausdrücklich (H, PDF nicht durchsucht). Die Erklärung muss § 25 nicht nennen. Ein Satz dazu erhöht nur die Transparenz.

**Risiko: gering.**

**Quelle.** § 25 TDDDG: https://www.gesetze-im-internet.de/ttdsg/__25.html (abgerufen 12.11.2026). DSK, OH Digitale Dienste: https://datenschutzkonferenz-online.de/media/oh/OH_Digitale_Dienste.pdf (nur Suchtreffer, 12.11.2026).

**Textänderung (optional).** In Teil A Abschnitt 4 nach „… liegen nur lokal auf deinem Gerät (auch für Widgets und Apple Watch).“ einfügen: „Die App speichert auf deinem Gerät nur, was für die von dir genutzten Funktionen unbedingt erforderlich ist (§ 25 Abs. 2 Nr. 2 TDDDG): Orte, Einstellungen und bei Regenhinweisen die Installationskennung samt Geheimnis im Schlüsselbund.“

## 5. Rolle von Apple (APNs, MapKit) und Drittlandübermittlung

**Befund.** Für Nutzer im EWR ist nach Apples Datenschutzrichtlinie Apple Distribution International Ltd. (Irland) verantwortlich. Übermittlungen aus dem EWR stützt Apple auf EU-Standardvertragsklauseln; das Data Privacy Framework erwähnt Apple dort nicht (B). Eine DPF-Zertifizierung von Apple ließ sich nicht bestätigen (H). Bei MapKit handelt Apple als eigener Verantwortlicher; Abschnitt 4 sagt das. Bei APNs ist die Rolle offen: eigener Verantwortlicher nach dem Developer Program License Agreement oder Auftragsverarbeiter (A). Für den Text genügt es, Apple als Empfänger zu nennen. Art. 13 Abs. 1 lit. f verlangt bei Drittlandübermittlung aber einen Hinweis auf die Garantie. Abschnitt 5 nennt nur „außerhalb der EU, insbesondere in den USA“. Apple 5.1.1(i) verlangt außerdem, dass die Erklärung „all uses“ und Dritte nennt; das ist erfüllt.

**Risiko: gering.**

**Quelle.** Apple Privacy Policy: https://www.apple.com/legal/privacy/en-ww/ (abgerufen 12.11.2026).

**Textänderung** (Teil A Abschnitt 5, Absatz „Apple“):
- Vorher: „Dabei können Daten an Server von Apple außerhalb der EU, insbesondere in den USA, übermittelt werden. Es gelten die Datenschutzbestimmungen von Apple.“
- Nachher: „Dabei können Daten an Server von Apple außerhalb der EU, insbesondere in den USA, übermittelt werden. Apple stützt solche Übermittlungen nach eigenen Angaben auf EU-Standardvertragsklauseln (Art. 46 Abs. 2 lit. c DSGVO). Es gelten die Datenschutzbestimmungen von Apple.“

## 6. Betreiber-Diagnose: Einwilligung, Transparenz

**Befund.** Die Einwilligung passt: Die Kopplung ist freiwillig, standardmäßig aus und jederzeit widerrufbar. Die Rechtsgrundlage ist auch dann nicht falsch, wenn praktisch nur Geräte des Betreibers gekoppelt werden; dann fallen keine Daten Dritter an. Abschnitt 6 der Seite ist transparent, einschließlich der Position auf etwa 1 km. **Die In-App-Texte widersprechen der Seite aber:** `DEVICE_LINK_FOOTER` und `DEVICE_LINK_PRIVACY` sagen „keine Standortdaten“. Für ein gekoppeltes Gerät sieht der Betreiber jedoch Regenhinweise mit Position (Teil D, `PushMeasure.swift`). Die App informiert damit falsch, und zwar unmittelbar an der Stelle, an der eingewilligt wird. Eine so eingeholte Einwilligung ist nicht „in informierter Weise“ abgegeben (Art. 4 Nr. 11 DSGVO, A).

**Risiko: mittel.** Der Fehler ist eindeutig, steckt aber im App-Code und braucht Build 47.

**Quelle.** DSGVO Art. 4 Nr. 11, Art. 7 (s. o.). Apple 5.1.1(ii), „purpose strings clearly and completely“ (s. o.).

**Textänderung (App, nächster Build).**
- `DEVICE_LINK_FOOTER`: „… Verlauf technischer Zustellergebnisse der letzten 48 Stunden, keine Standortdaten.“ wird zu „… Verlauf technischer Zustellergebnisse der letzten 48 Stunden. Solange das Gerät gekoppelt ist, sieht der Betreiber seine Regenhinweise mit der auf etwa 1 km gerundeten Position.“
- `DEVICE_LINK_PRIVACY`: „…, dauerhaft bis zum Widerruf; keine Standortdaten.“ wird zu „…, dauerhaft bis zum Widerruf. Während der Kopplung sieht der Betreiber die Regenhinweise dieses Geräts mit der auf etwa 1 km gerundeten Position.“
- Die englischen Texte entsprechend anpassen.

## 7. Hetzner: AVV, Unterauftragsverarbeiter

**Befund.** Hetzner bietet den AVV im Kundenkonto an; laut AGB kommt er „nicht automatisch“ zustande (B, nach der Suchzusammenfassung der AGB). Der Standard-AVV mit TOM-Anlage ist für einen vServer der übliche und ausreichende Weg (A). Die Unterauftragsverarbeiter stehen im AVV beziehungsweise im Kundenkonto; eine öffentliche Liste wurde nicht gefunden (H). Die Erklärung muss Hetzner als Empfänger nennen; das ist erfüllt. Sitz und Anschrift sind nach Art. 13 Abs. 1 lit. e nicht nötig, „Empfänger oder Kategorien“ genügt (A). Offen ist, ob Zoraxy auf demselben Hetzner-Server läuft (Teil C 4d). Läuft er woanders, braucht es einen weiteren Empfänger oder AVV.

**Risiko: mittel**, solange kein AVV abgeschlossen ist (Art. 28 Abs. 3 DSGVO). Danach gering.

**Quelle.** Hetzner AGB: https://www.hetzner.com/de/rechtliches/agb (Suchtreffer, 12.11.2026). TOM: https://docs.hetzner.com/de/general/others/technical-and-organizational-measures/ (Suchtreffer, 12.11.2026).

**Textänderung.** Keine. Abschnitt 7 ist korrekt, sobald der AVV geschlossen ist. Er darf erst danach live gehen.

## 8. Impressum (§ 5 DDG), Verantwortlicher, ladungsfähige Anschrift

**Befund.** § 5 DDG gilt für „geschäftsmäßige, in der Regel gegen Entgelt angebotene“ digitale Dienste und verlangt Name, Anschrift der Niederlassung und E-Mail (B). Ob eine kostenlose App eines Einzelnen ohne Erwerbszweck darunter fällt, ist umstritten (A). Eine öffentlich im App Store angebotene, dauerhaft betriebene App wird oft vorsichtig als geschäftsmäßig eingeordnet. Davon unabhängig gilt Folgendes:
- Art. 13 Abs. 1 lit. a DSGVO verlangt in der Datenschutzerklärung Name und Kontaktdaten des Verantwortlichen. Die Platzhalter `OPERATOR_*` müssen also in jedem Fall gefüllt werden.
- Apple 1.5 verlangt in der App und auf der Support-URL einen einfachen Kontaktweg (B).
- Für den EU-Vertrieb muss jeder Entwickler in App Store Connect seinen Händlerstatus nach dem Digital Services Act erklären. Als „trader“ zeigt Apple Anschrift (bei Einzelpersonen auch ein Postfach), Telefon und E-Mail auf der Produktseite. Als Nicht-Händler sind keine Angaben nötig, dann entfallen aber Verbraucherrechte (B).
- Eine Verlinkung von Datenschutzerklärung und Support-Seite aus der App gilt als „unmittelbar erreichbar“ (A).

Eine Postfachadresse genügt im Impressum nach herrschender Meinung nicht, wohl aber eine c/o- oder Impressums-Service-Anschrift mit Zustellmöglichkeit (A). Der Wortlaut von `/impressum` und `/support` ist nicht im Repo und wurde nicht geprüft.

**Risiko: mittel.** Ein fehlendes oder unvollständiges Impressum kann abgemahnt werden; bei einer kostenlosen Hobby-App ist das praktisch eher selten. Mit vollständigem Impressum (Name, ladungsfähige Anschrift, E-Mail) gering.

**Quelle.** § 5 DDG: https://www.gesetze-im-internet.de/ddg/__5.html (abgerufen 12.11.2026). Apple DSA: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/ (abgerufen 12.11.2026). Guidelines 1.5 (s. o.).

**Einzufügender Wortlaut `/impressum`** (Platzhalter bleiben, nichts erfunden):
„Angaben gemäß § 5 DDG: [OPERATOR_NAME], [OPERATOR_ADDRESS (ladungsfähige Anschrift, kein Postfach)]. Kontakt: E-Mail [OPERATOR_EMAIL]. Verantwortlich für den Inhalt: [OPERATOR_NAME], Anschrift wie oben.“ Telefon ist nach § 5 DDG nicht zwingend, wenn die E-Mail schnell beantwortet wird (A). Ob das Impressum nötig ist und ob eine c/o-Anschrift reicht, ist die Ermessensfrage E5.

## 9. Datenschutzbeauftragter

**Befund.** § 38 Abs. 1 BDSG verlangt einen Datenschutzbeauftragten erst ab in der Regel 20 Personen, die ständig mit automatisierter Verarbeitung befasst sind, oder bei DSFA-Pflicht beziehungsweise Datenhandel (B). Art. 37 Abs. 1 lit. b und c DSGVO (umfangreiche regelmäßige Überwachung als Kerntätigkeit, besondere Kategorien) trifft nicht zu (A). Eine Benennungspflicht besteht nicht, die Erklärung braucht keine DSB-Angabe.

**Risiko: gering.**

**Quelle.** § 38 BDSG: https://www.gesetze-im-internet.de/bdsg_2018/__38.html (abgerufen 12.11.2026).

**Textänderung.** Keine.

## 10. Direktabrufe (DWD, EUMETSAT, MapKit): gemeinsame Verantwortung?

**Befund.** Nach EuGH C-40/17 „Fashion ID“ kann gemeinsam verantwortlich sein, wer eine Übermittlung an Dritte technisch auslöst. Die gemeinsame Verantwortung beschränkt sich dann auf die Erhebungs- und Übermittlungsphase (A, aus Kenntnis). Die App löst die Abrufe beim DWD, bei EUMETSAT und bei Apple aus. Für diese Phase ist der Betreiber daher mindestens selbst Verantwortlicher; eine gemeinsame Verantwortung ist nicht ausgeschlossen. Anders als bei einem Like-Button dienen die Abrufe aber unmittelbar der vom Nutzer gewünschten Funktion. Die Gegenstellen sind Behörden beziehungsweise eine zwischenstaatliche Organisation und Apple als Plattform; es gibt keinen Werbe- oder Profilzweck (A). Ein Vertrag nach Art. 26 mit dem DWD oder mit Apple ist praktisch nicht erreichbar und nach unserer Einschätzung nicht nötig. Eine Lücke gibt es aber: Teil A Abschnitt 4 nennt für die Auslösung dieser Abrufe keine Rechtsgrundlage (Art. 13 Abs. 1 lit. c).

**Risiko: gering.**

**Quelle.** EuGH C-40/17: https://curia.europa.eu/juris/liste.jsf?num=C-40/17 (aus Kenntnis, nicht abgerufen).

**Textänderung** (Teil A Abschnitt 4, ans Ende des zweiten Absatzes): „Rechtsgrundlage für diese von deinem Gerät ausgelösten Abrufe ist die Bereitstellung der von dir genutzten Funktion (Art. 6 Abs. 1 lit. b DSGVO) beziehungsweise unser berechtigtes Interesse an einer funktionsfähigen App (Art. 6 Abs. 1 lit. f DSGVO).“

## 11. Rasterzelle als personenbezogenes Datum; Apple Precise/Coarse

**Befund.** Zelle, Installationskennung und Token gehören zum selben Gerät und sind damit pseudonyme personenbezogene Daten (Art. 4 Nr. 1 und 5, ErwG 26 DSGVO, A). Teil A formuliert schon „kann … zugeordnet und damit personenbezogen sein“. Das ist vertretbar, aber unnötig weich. „Keine Koordinate“ stimmt formal, die Zelle lässt sich aber auf etwa 0,7 km in eine Koordinate zurückrechnen; das Dashboard tut das. **Apple-Definition (B):** „Precise Location“ heißt Auflösung von mindestens drei Dezimalstellen bei Breite und Länge, also etwa 110 m. Alles Gröbere ist „Coarse Location“. Eine 0,7-km-Zelle und die 2-km-Gebiete sind nach dieser Definition **beide „Coarse“**. Teil B 2a und das Privacy Manifest seit Build 34 deklarieren mit „Precise“ mehr als nötig. Das ist kein Prüfungsrisiko, wirkt im Store-Label aber unnötig abschreckend. „Linked“ ist nach Apples Hinweis zu personenbezogenen Daten richtig (B).

**Risiko: gering.**

**Quelle.** Apple App Privacy Details (s. o.).

**Textänderung** (Teil A Abschnitt 5):
- Vorher: „(Kantenlänge etwa 0,7 km, keine Koordinate, kein Ortsname)“ und „Die Rasterzelle kann zusammen mit der Installationskennung einem Gerät zugeordnet und damit personenbezogen sein; ein Standortverlauf entsteht nicht.“
- Nachher: „(Kantenlänge etwa 0,7 km, keine genaue Koordinate, kein Ortsname)“ und „Zusammen mit der Installationskennung ist die Rasterzelle einem Gerät zugeordnet; wir behandeln sie deshalb als personenbezogenes Datum. Gespeichert wird nur der aktuelle Wert, ein Standortverlauf entsteht nicht.“
- Teil B 2a: siehe Entscheidung E4.

## 12. Lizenzen: DWD (GeoNutzV/CC BY 4.0), DWD-Warnungen, EUMETSAT

**Befund.**
- DWD verlangt „Quelle: Deutscher Wetterdienst“ direkt bei der Information. Für veränderte Daten nennt der DWD Formulierungen wie „Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben“. Veränderte amtliche Warnungen dürfen den Quellenvermerk nicht tragen (B).
- Die App folgt dem (`STORE_ATTRIBUTION`, `STORE_MODIFICATION_NOTICE`, `INFO_MODEL_ICON`, `WARN_SOURCE_ISSUED` bei unveränderter Warnung). Die Warn-Kurzmeldung ohne Vermerk (decisions.md 7.11.) entspricht der DWD-Regel. Die Rückfrage an CAP@dwd.de bleibt offen, Warn-Push ist aus.
- EUMETSAT Data Policy (Jan. 2026): Core-Daten stehen unter CC BY 4.0, Pflichtattribution „[Contains modified] EUMETSAT [Satellit/Daten] [Jahr]“ (B). „Contains modified EUMETSAT Meteosat data 2026“ passt. Das Jahr muss jährlich angepasst werden; die App übernimmt die Attribution aus dem Backend-Manifest, deren Inhalt hier nicht geprüft wurde.
- CC BY 4.0 verlangt außerdem einen Hinweis auf die Lizenz (A, Lizenztext Abschnitt 3a, aus Kenntnis). Teil A Abschnitt 9 nennt die Lizenz nicht.

**Risiko: gering.**

**Quellen.** DWD-Vorlage Quellenangabe: https://www.dwd.de/DE/service/rechtliche_hinweise/vorlagen_quellenangabe.html (abgerufen 12.11.2026). EUMETSAT Data Policy 2026: https://www-cdn.eumetsat.int/files/2026-01/45173%20-%20Data_Policy.pdf (Suchtreffer, 12.11.2026). Weitere DWD-Quellen in [dwd-warnungen-weitergabe.md](dwd-warnungen-weitergabe.md).

**Textänderung** (Teil A Abschnitt 9):
- Vorher: „Quelle: Deutscher Wetterdienst. Die Radarbilder sind aus Rasterdaten des DWD bildlich wiedergegeben und aufbereitet.“
- Nachher: „Quelle: Deutscher Wetterdienst (Lizenz CC BY 4.0, https://creativecommons.org/licenses/by/4.0/deed.de). Datenbasis: Deutscher Wetterdienst, Rasterdaten bildlich wiedergegeben. Warngebiete: © GeoBasis-DE / BKG (Daten modifiziert).“ (Den BKG-Teil nur aufnehmen, wenn die Warnanzeige im Release enthalten ist.)

## Berechtigungstexte

- `NSLocationWhenInUseUsageDescription` (de: „Dein Standort zentriert die Karte und lädt die Regenprognose direkt beim Deutschen Wetterdienst. Es gibt keine Hintergrundortung.“; en gleichwertig): nennt Zweck und Empfänger und ist nur „When In Use“. Das entspricht Apple 5.1.1(ii) „clearly and completely“. **Unkritisch.**
- Für Mitteilungen gibt es keinen Info.plist-Text. Den Hinweis vorher liefert der App-Dialog (Frage 3).
- `PUSH_INSTALLATION_ID_HINT` siezt („Nennen Sie …“), die übrige App duzt. Das ist kein Rechtsproblem; Vorschlag für den nächsten Build: „Nenne diese Kennung bei einer Auskunftsanfrage.“

## Direkte Korrekturen in dieser Prüfung

1. `docs/datenschutz-entwurf-release.md` Teil B Punkt 2: Die geprüfte Apple-Definition (Precise ab drei Dezimalstellen) ist ergänzt und auf dieses Ergebnis verwiesen. Zuvor stand dort „nach meiner Erinnerung … nicht geprüft“. Die Einstufung selbst ist unverändert; sie ist Entscheidung E4.

Sonst wurde nichts geändert: kein App-Code, keine Strings, keine Betreiberangaben.

## Offene Entscheidungen für Lino

Jeweils mit Empfehlung zuerst.

- **E1 Proxy-Logfrist** (vor Livegang, blockierend): (a) zeitbasiert 7 Tage löschen; (b) 14 Tage; (c) 30 Tage; (d) Logging am Proxy ganz ohne IP. Danach Abschnitt 3 mit der konkreten Zahl. Kosten: keine.
- **E2 Proxy-IP in App Privacy:** (a) IP am Proxy nicht oder nur gekürzt speichern, dann ist keine Angabe nötig; (b) IP 7 Tage speichern und „Sonstige Diagnosedaten, verknüpft, App-Funktionalität“ deklarieren. Vorher prüfen, ob Zoraxy Pfade und IPs protokolliert und ob sich das abschalten lässt (Nutzeraktion, Konfiguration ansehen).
- **E3 Diagnose-Text in der App** (Widerspruch „keine Standortdaten“): (a) mit Build 47 korrigieren, bis dahin keine fremden Geräte koppeln; (b) bis zur Korrektur die Kopplung nur für eigene Geräte nutzen und den Text später ändern. Kosten: keine.
- **E4 Standort-Kategorie Ortszelle:** (a) für den 9.12. „Precise und Coarse“ lassen, weil das sicher und konsistent mit dem Manifest ist, und später auf nur „Coarse“ umstellen; (b) sofort nur „Coarse“ (Manifest ändern, Build 47). Nach Apples Definition ist (b) korrekt, (a) übererfüllt.
- **E5 Impressum und Anschrift:** (a) Impressum mit eigener ladungsfähiger Anschrift; (b) c/o- oder Impressums-Service-Anschrift (Kosten etwa wenige Euro im Monat, Anbieter nicht geprüft); (c) kein Impressum mit der Begründung, die App sei nicht geschäftsmäßig, dann nur der Verantwortliche in der Datenschutzerklärung (höchstes Risiko); (d) Anwalt fragen (Kosten). Empfehlung (a) oder (b). Unabhängig davon: OPERATOR_NAME/ADDRESS/EMAIL eintragen (Pflicht nach Art. 13).
- **E6 DSA-Händlerstatus in App Store Connect:** (a) „kein Händler“ (kostenlos, ohne Erwerbszweck, keine Kontaktangaben öffentlich); (b) „Händler“ mit öffentlicher Anschrift, Telefon und E-Mail. Die Einordnung muss Lino selbst treffen, Apple prüft sie nicht.
- **E7 Hetzner-AVV:** (a) Standard-AVV im Kundenkonto vor Livegang abschließen und klären, ob Zoraxy auf demselben Server läuft; (b) nur mit Anwaltsprüfung (Kosten). Der Standard-AVV genügt nach unserer Einschätzung.
- **E8 Veraltete Doku-Seite `docs-site/content/datenschutz.md`** (GitHub Pages, Stand Build 11, ohne Push): (a) durch einen kurzen Verweis auf showers.linolaske.de/datenschutz ersetzen; (b) auf den Stand von Teil A bringen (doppelte Pflege); (c) unverändert lassen (widersprüchliche öffentliche Aussagen).
- **E9 Anwaltliche Prüfung insgesamt:** (a) nicht vor dem Start, wenn E1, E3, E5 und E7 umgesetzt sind (Restrisiko gering bis mittel); (b) einmalige Pauschalprüfung von Datenschutzerklärung und Impressum (Kosten, typischerweise dreistellig, nicht recherchiert).

## Entscheidungen von Lino (Board, 14.11.2026)

- **E3 (a):** Diagnose-Text mit Build 47 korrigieren. Umgesetzt im Quelltext (`DEVICE_LINK_FOOTER`, `DEVICE_LINK_PRIVACY`, de/en: Betreiber sieht Regenhinweise gekoppelter Geräte mit auf etwa 1 km gerundeter Position); Build 47 und Upload stehen aus.
- **E4 (a):** App Privacy vorerst „Precise und Coarse“ belassen, Manifest unverändert; später nur „Coarse“.

## Nicht geprüft

Wortlaut von `/impressum` und `/support` (Backend-Repo), Live-Seiten, tatsächliche Zoraxy-Konfiguration (Felder, Pfade, Rotation), Hetzner-Kundenkonto und AVV-Text, DPF-Liste (dataprivacyframework.gov nicht abgerufen), DSK-Orientierungshilfe im Volltext, EUMETSAT-Policy-PDF im Volltext (nur Suchtreffer), Backend-Manifest-Attribution, App Store Connect. DSGVO-, BGH- und EuGH-Fundstellen sind aus Kenntnis zitiert und nicht abgerufen. Verwendet wurden 6 Websuchen und 7 Abrufe von Primärquellen am 12.11.2026.
