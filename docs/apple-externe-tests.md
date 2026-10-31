# Apple-Leitfaden: externe TestFlight-Tests (und später App Store)

Stand: 30. Oktober 2026. Betreiberanleitung: Was ist bei Apple auszufüllen, damit ShowerNow (`de.linolaske.showernow`) an externe Tester geht? Geprüft gegen Apples Primärquellen (Tabelle am Ende, Abruf jeweils 30. Oktober 2026). Kein Rechtsrat.

Kennzeichnung je Aussage: **BESTÄTIGT** = in der genannten Apple-Quelle gefunden, **ANNAHME** = Erfahrung/Schlussfolgerung, nicht belegt, **UNKLAR** = nicht entscheidbar. Quellen als `[Q#]`.

Oberflächenbegriffe: Apple-Hilfe liegt hier nur auf Englisch vor. Die deutschen Bezeichnungen in App Store Connect wurden nicht geprüft; deshalb stehen die englischen Originalbegriffe da, deutsche nur als „vermutlich:“.

## Die drei wichtigsten Punkte vorab

1. **Builds 1 bis 9 sind nur intern nutzbar.** Der Uploadweg setzte `testFlightInternalTestingOnly=true` (siehe [testflight-upload.md](testflight-upload.md)). Apple: Solche Builds sind „internal“ markiert und können nur internen Gruppen zugeordnet werden (BESTÄTIGT, [Q2]). Für externe Tester braucht es einen Build, der ohne diese Option hochgeladen wurde. Ob Build 10 so hochgeladen wird, ist in `testflight-upload.md` nachzuprüfen (nicht Teil dieses Auftrags).
2. **Die URLs Datenschutz, Marketing und Support sind noch nicht live.** Stand 30. Oktober 2026 liefern `https://showernow.linolaske.de/datenschutz`, `/marketing` und `/support` HTTP 404; der Backend-Agent baut sie gerade. Vor Beta-Review prüfen, dass sie erreichbar sind (Apple verlangt „fully functional URLs“, Guideline 2.1(a), [Q15]).
3. **Datenschutzlink in der App fehlt noch.** Guideline 5.1.1(i): Link zur Datenschutzerklärung in den Metadaten **und** in der App leicht erreichbar (BESTÄTIGT, [Q15]). Die App hat einen Abschnitt „Datenschutz“ im Info-Sheet, aber keinen Link auf die Web-URL (`Weather/Views/InformationSheet.swift`, nur gelesen). Für den App Store nachziehen; für TestFlight vermutlich unkritisch (ANNAHME).

## 1. Voraussetzungen vorab

| Punkt | Stand | Quelle |
|---|---|---|
| Apple Developer Program (bezahlte Mitgliedschaft) | vorhanden (Team in `signing.md`, ohne Konto-/Zahlungsprüfung) | Repo |
| App-Eintrag in App Store Connect mit Bundle-ID `de.linolaske.showernow` | laut `signing.md` vom Nutzer umgestellt, Upload-Antworten bestätigen `name=ShowerNow`, passende Bundle-ID | Repo |
| Build hochgeladen und verarbeitet | Build 9 hochgeladen (`processing`); Verarbeitung/Installierbarkeit nicht belegt | `status.md` |
| Build nicht als „Internal Only“ hochgeladen | **offen** (siehe oben) | [Q2] |
| Rolle für Test Information | Account Holder, Admin oder App Manager | BESTÄTIGT [Q3] |
| Rolle für externe Gruppen/Tester | Account Holder, Admin oder App Manager | BESTÄTIGT [Q2] |
| Mindestens eine interne Gruppe | Pflicht, bevor eine externe Gruppe angelegt werden kann | BESTÄTIGT [Q2] |
| Provisioning: Application Identifier im Profil | Voraussetzung für TestFlight-Builds; durch `signing.md` belegt | BESTÄTIGT [Q1] |

## 2. Intern gegen extern

| | Intern | Extern |
|---|---|---|
| Wer | App-Store-Connect-Nutzer mit Zugriff auf die App, bis 100 [Q1, Q4] | Beliebige Personen ohne ASC-Konto, bis 10 000 pro App [Q1, Q2] |
| Beta App Review | nein | Ja, **erster** Build einer Gruppe/Version voller Review; spätere Builds derselben Version „might not“ [Q1, Q2] |
| Test Information | nicht nötig | Pflicht (Beschreibung, Feedback-E-Mail, Kontakt) [Q3] |
| Einladung | ASC-Nutzer | E-Mail, CSV-Import oder öffentlicher Link [Q2] |
| Build-Gültigkeit | 90 Tage ab Upload/Testbeginn [Q1] | 90 Tage [Q1] |
| „Internal Only“-Builds | möglich | nicht möglich [Q2] |

Weitere Limits (alle BESTÄTIGT, [Q2]): ein Build je Version gleichzeitig im Review; höchstens sechs Builds pro 24 Stunden zur Beta-Prüfung; beim öffentlichen Link frei wählbares Testerlimit 1 bis 10 000; Managed Apple Accounts aus reservierten Domains können nicht testen.

Öffentlicher Link gegen E-Mail ([Q2], BESTÄTIGT): Link „Open to Anyone“ oder „Filter by Criteria“ (Gerät/Plattform); über den Link beigetretene Tester erscheinen anonym (nur Installationen, Sitzungen, Abstürze), per E-Mail eingeladene mit Name und Adresse. Der Link lässt sich jederzeit deaktivieren. Empfehlung (ANNAHME): zuerst wenige per E-Mail, später Link mit Testerlimit.

## 3. Test Information und Beta App Review

Pfad (BESTÄTIGT, [Q3]): App öffnen, Tab TestFlight, Seitenleiste unter „Additional“ den Eintrag **Test Information**, Sprache wählen, Felder füllen. Die Angaben dürfen von den späteren App-Store-Angaben abweichen und sind jederzeit änderbar.

| Feld (englisch) | Pflicht? | Hinweis |
|---|---|---|
| Beta App Description | **Pflicht** (BESTÄTIGT [Q3]) | Text siehe unten |
| Feedback Email | **Pflicht** (BESTÄTIGT [Q3]) | Wird auch Antwortadresse der Einladungsmails |
| Invitation Experience: „App Information“ | Kontrollkästchen, vorgewählt | Zeigt Screenshots/Kategorie der zuletzt freigegebenen App-Store-Version; ohne App-Store-Version leer. Kann abgewählt werden (BESTÄTIGT [Q3]) |
| Marketing URL, Privacy Policy URL | **UNKLAR**, ob in der TestFlight-Maske vorhanden/Pflicht. Die Apple-Seite nennt nur die zwei Pflichtfelder oben. Für den App Store gilt: Privacy Policy URL Pflicht, Marketing URL optional ([Q9], [Q6]) | Trotzdem eintragen, falls das Feld erscheint |
| Beta App Review Information: Contact (Name, E-Mail, Telefon) | Apple verweist für die „TestFlight App Review information properties“ auf die App-Review-Information-Tabelle [Q3]; dort ist Contact (Name, E-Mail, Telefon im internationalen Format mit „+“) geführt [Q6]. Pflicht-Status je Feld in der Tabelle nicht eindeutig lesbar → **UNKLAR**, vorsorglich ausfüllen | Platzhalter unten |
| Notes | optional laut Tabelle, bis 4000 Bytes, beliebige Sprache [Q6]; Guideline 2.3.1(a) verlangt konkrete Beschreibungen in den Review-Notizen | Textvorschlag unten |
| Sign-in required (Demo-Konto) | **entfällt**: ShowerNow hat kein Konto [Q6: „if your app requires a login“] | Kontrollkästchen leer lassen |
| What to Test (je Build) | Pflichtdialog beim Zuordnen des Builds [Q2] | Textvorschlag unten |

Persönliche Angaben bleiben Platzhalter: Kontakt `<Vorname Nachname>`, `<E-Mail für Prüfer>`, `<Telefon im Format +49…>`, Feedback-E-Mail `<Feedback-E-Mail>`. Nichts davon ins Repo schreiben.

URLs (alle drei **im Backend in Arbeit, noch nicht deployt, 404 am 30. Oktober 2026**):

- Datenschutz: `https://showernow.linolaske.de/datenschutz`
- Marketing: `https://showernow.linolaske.de/marketing`
- Support: `https://showernow.linolaske.de/support`

Hinweis zur Support-URL (für den App Store, BESTÄTIGT [Q6]): Sie muss echte Kontaktdaten enthalten, soweit lokales Recht es verlangt (Anschrift, E-Mail, Telefon). Für ein Impressum nach deutschem Recht ist das vermutlich relevant (ANNAHME, kein Rechtsrat).

### Textvorschläge

**Beta App Description (Deutsch)**

> ShowerNow zeigt in Deutschland, wann es bei dir regnet: Radarkarte mit Zeitleiste, Regenprognose für die nächsten Stunden und gespeicherte Orte. Basis sind offene Radardaten des Deutschen Wetterdienstes (DWD). Kein Konto, keine Werbung, kein Tracking. Frühe Testversion: Funktionen und Aussehen ändern sich.

**Beta App Description (Englisch, falls eine englische Lokalisierung angelegt wird)**

> ShowerNow shows when it will rain where you are in Germany: radar map with timeline, short-term rain forecast and saved places. Based on open radar data from the German Weather Service (DWD). No account, no ads, no tracking. Early test version; features and design will change.

**Review-Notizen (Englisch, für Prüfer)**

> No account or sign-in. Location permission is optional (when-in-use only, no background location); the map can also be used by searching a place. Radar coverage is Germany and surroundings: if you test elsewhere, search for a German city (for example Berlin) and use the timeline slider. At dry moments the radar is legitimately empty. Radar images come from our radar cache server (no location sent, no cookies); on errors the app falls back to the DWD map service. The point forecast for a place is requested directly from the DWD with a small map section around the selected position. Optional on-device text summary uses Apple Foundation Models where available and sends nothing off the device. Data source is shown in the in-app info sheet: Deutscher Wetterdienst, open data (GeoNutzV / CC BY 4.0). Contact: <E-Mail für Prüfer>.

**What to Test (je Build, Deutsch)**

> Bitte testen: Radar-Zeitleiste scrubben, Ortsprognose öffnen, Orte speichern/umbenennen/löschen, Verhalten ohne Standortfreigabe, Info-Sheet mit Quellenangabe. Rückmeldungen über TestFlight (Screenshot und Kommentar).

Hinweis zur Genauigkeit (ANNAHME): Wetter-/Radar-Apps werden gelegentlich nach Hinweisen zu Aktualität und Genauigkeit gefragt; die App zeigt das Datenalter, die Info-Sheet nennt die Quelle. Wer Warnfunktionen bewirbt, sollte keine Sicherheits- oder Unwetterzusagen machen.

## 4. App-Datenschutz („App Privacy“, Nutrition Label)

Wichtigste Quellen: Apples Definition „collect“ [Q7] und die Antwort-Maske [Q8]. Ob die Angaben für **externes TestFlight** schon ausgefüllt sein müssen, ist in den gelesenen Seiten nicht belegt (**UNKLAR**). Für den App Store sind sie Pflicht (BESTÄTIGT [Q7]: „required to submit new apps and app updates“).

### Was die App tatsächlich sendet (Repo, nur gelesen)

| Datenfluss | Inhalt | Ziel | Quelle im Repo |
|---|---|---|---|
| Radar-Ganzbilder | feste Pfade je Lauf/Slot, kein Ort, keine Cookies, keine Kennung | ShowerNow-Radar-Server | `RadarBackend.swift`, `decisions.md` |
| Radar-Fallback | Bildabfrage | DWD (`opendata.dwd.de`, `maps.dwd.de`) | `DWDRequest.swift` |
| Punktprognose | Kartenausschnitt (BBOX, 3×3 Pixel) **um die gewählte Position** | direkt DWD (`maps.dwd.de`) | `DWDRequest.swift`, `decisions.md` |
| Karte, Ortssuche | Apple MapKit | Apple | `InformationSheet.swift` |
| Standort | `NSLocationWhenInUseUsageDescription`, nur bei Nutzung, keine Hintergrundortung | bleibt auf dem Gerät, außer als Ausschnitt an den DWD (s. o.) | `Configuration/Info.plist`, `WeatherStore.swift` |
| Gespeicherte Orte | `places.json` im lokalen App-Support-Ordner | nur Gerät | `WeatherStore.swift` |
| Einordnung | Foundation Models auf dem Gerät, keine Koordinaten im Prompt | nur Gerät | `ForecastInterpretation.swift`, `decisions.md` |
| Fremdbibliotheken / Analytics / Werbung / Konto | keine (kein Paketabschnitt in `project.yml`) | – | `project.yml` |

### Apples Definition und was daraus für den DWD folgt

- „Collect“ bedeutet: Daten das Gerät verlassen **und** so übertragen werden, dass **du und/oder deine Drittpartner** darauf länger zugreifen können, als zur Echtzeit-Bearbeitung der Anfrage nötig ist (BESTÄTIGT [Q7]). Daten, die nur auf dem Gerät verarbeitet werden, sind nicht „collected“; was daraus abgeleitet und gesendet wird, ist getrennt zu bewerten (BESTÄTIGT [Q7]).
- „Third-party partners“ sind Analysetools, Werbenetze, Drittanbieter-SDKs oder andere externe Anbieter, **deren Code in die App eingebunden ist** (BESTÄTIGT [Q7]). Der DWD ist ein Datenserver, kein eingebundener Code.
- Daten, die an einen Server gehen und dort sofort nach Bearbeitung verworfen werden, müssen nicht angegeben werden (BESTÄTIGT [Q7]). Für Apple-Dienste wie MapKit ist nicht der Entwickler zur Angabe verpflichtet (BESTÄTIGT [Q7]).
- **Was ich nicht sicher entscheiden kann (UNKLAR):** Ob Apple die Übertragung der Koordinaten an einen fremden öffentlichen Datenserver (DWD), auf den ShowerNow keinen Zugriff hat, als Erhebung durch die App wertet. Nach dem Wortlaut sammelt der Betreiber hier nichts (kein Zugriff, kein Drittpartner-Code). Apple legt die Praxis aber im Review aus; es gibt in den gelesenen Seiten kein Beispiel „App ruft öffentlichen Drittserver mit Position ab“.

**Empfehlung:** Variante A („Data Not Collected“), weil der Wortlaut sie stützt und die Datenschutzerklärung die DWD-Übertragung offen nennt (Guideline 5.1.1(i) verlangt dort die Offenlegung, [Q15]). Variante B als vorsichtige Alternative, falls kein Risiko eingegangen werden soll: Location (Precise oder Coarse, Ausschnitt 3×3 Pixel ist etwa Rasterzellgröße, ANNAHME) angeben, Zweck App Functionality, nicht mit dem Nutzer verknüpft, nicht für Tracking. Zu viel anzugeben ist vermutlich weniger riskant als zu wenig (ANNAHME). Begründung zu MapKit: Karte und Ortssuche laufen über Apple MapKit; Suchtext und Kartenausschnitt gehen an Apple, nicht an einen Server, auf den ShowerNow zugreift, und ShowerNow empfängt oder speichert sie nicht. Die Datenschutzerklärung nennt diesen Weg ausdrücklich (Abschnitt „Kartenansicht und Ortssuche (Apple)“). **Entscheidung beim Betreiber**; in `decisions.md` festhalten.

Offener Punkt, der Variante A kippen kann (UNKLAR): Der ShowerNow-Radar-Dienst führt laut Backend-Code keine Zugriffsprotokolle; der vorgeschaltete Reverse Proxy sieht die IP-Adresse, ob er protokolliert, ist offen (`decisions.md`). Werden IP-Adressen dort **gespeichert**, wäre „IP address collected“ nach [Q7] unter den passenden Datentypen (z. B. Diagnostics oder Device ID, je nach Verwendung) anzugeben. Vor der Antwort Proxy-Protokollierung klären.

### Frage für Frage (Reihenfolge laut [Q8], englische Begriffe)

| Frage / Bereich | Empfehlung | Sicherheit |
|---|---|---|
| Privacy Policy URL (Pflicht für alle Apps [Q9]) | `https://showernow.linolaske.de/datenschutz` (noch nicht live) | BESTÄTIGT, dass Pflicht |
| User Privacy Choices URL | leer lassen (optional [Q9]) | BESTÄTIGT |
| „Do you or your third-party partners collect data from this app?“ | Variante A: **No**; Variante B: Yes, siehe oben | Variante A ANNAHME/UNKLAR, s. o. |
| Data Types: Location | A: nicht ankreuzen; B: Precise/Coarse Location | UNKLAR |
| Data Types: Contact Info, Identifiers (User ID, Device ID), Purchases, Usage Data, Browsing/Search History, Sensitive Info, Financial, Health, Contacts, User Content | nicht gesammelt (App ohne Konto, ohne Analytics; Ortssuche läuft über MapKit/Apple) | ANNAHME, aus Repo abgeleitet |
| Diagnostics (Crash Data, Performance Data) | nicht ankreuzen: Die App hat kein eigenes Crash-Reporting. Von Apple über TestFlight/App Store gesammelte Absturzdaten liegen bei Apple, nicht beim Betreiber; Apple nimmt Entwickler bei Apple-Diensten aus der Angabepflicht [Q7] | ANNAHME (Aussage für „Apple frameworks or services“ belegt, ausdrückliche Nennung von TestFlight-Crashlogs nicht gefunden) |
| Verwendungszweck je Datentyp, „linked to user“, „used for tracking“ | bei Variante A entfällt; bei B: App Functionality, nicht verknüpft, nein | BESTÄTIGT als Fragenstruktur [Q7] |
| Tracking (ATT) | nein: keine Verknüpfung mit Drittdaten für Werbung, keine Weitergabe an Datenhändler [Q7]; daher keine `NSUserTrackingUsageDescription` nötig | BESTÄTIGT für Definition, ANNAHME für Anwendung |
| Third-party SDKs | keine | BESTÄTIGT durch Repo (`project.yml` ohne Pakete) |

Antworten gelten app-weit für alle Plattformen und lassen sich jederzeit ohne App-Update ändern (BESTÄTIGT [Q7], [Q8]).

## 5. Export Compliance / Verschlüsselung

- Die App setzt `ITSAppUsesNonExemptEncryption = false` in `Configuration/Info.plist` und die geprüften IPAs bestätigen es (`signing.md`).
- Apple: Mit `NO` gibt die App an, dass sie – inklusive gelinkter Fremdbibliotheken – keine oder nur von der Exportkontrolle **ausgenommene** Verschlüsselung nutzt. **Fehlt der Schlüssel, führt App Store Connect bei jedem Upload durch den Compliance-Fragebogen** (BESTÄTIGT [Q11]). Mit gesetztem Schlüssel entfällt die Frage (BESTÄTIGT [Q10], [Q11]).
- Apple verlangt eine Exportbewertung auch für Apps mit Standardalgorithmen oder Betriebssystem-Kryptografie; der Entwickler trägt die Verantwortung für die korrekte Einordnung, falsche Freistellung erzeugt Haftung (BESTÄTIGT [Q10]). ShowerNow nutzt nach Repo nur Netzwerkzugriffe über das Betriebssystem (HTTPS) und keine eigene Kryptografie. Dass das unter die Ausnahme fällt, ist die übliche Einordnung, aber **ANNAHME ohne Rechtsprüfung**.
- Frankreich: Das französische Formular ist nur nötig, wenn die App im App Store **in Frankreich** angeboten wird (BESTÄTIGT [Q16]). Bei Ausnahme-Einordnung ist das vermutlich nicht relevant; ob Beta-Tests über TestFlight in Frankreich eine Rolle spielen, ist **UNKLAR**. Bei Zweifel Frankreich in der App-Store-Verfügbarkeit weglassen (ANNAHME).

## 6. Altersfreigabe, Kategorie, Rechte, Standort, KI

- **Altersfreigabe (App Store):** Pflichtfeld, Apple errechnet den Wert aus einem Fragebogen mit Inhalten, In-App-Controls und Capabilities (BESTÄTIGT [Q12]); Apps ohne Rating können nicht veröffentlicht werden. ShowerNow hat nach Repo keinen Web-Zugang im Browsersinne (Links öffnen extern), keine Nutzerinhalte, keine Chats, keine Werbung, keine Gewalt/Glücksspiel/Medizininhalte. Erwartung: niedrigste Stufe (ANNAHME). Ob die Altersfrage vor externem TestFlight erscheint: **UNKLAR**.
- **Kategorie:** Weather (ANNAHME; Kategorieliste nicht gelesen). Zweite Kategorie optional (ANNAHME).
- **Datenrechte DWD:** Lizenzbasis laut Repo ist GeoNutzV, kompatibel zu CC BY 4.0, mit Quellenvermerk „Quelle: Deutscher Wetterdienst“ und Veränderungshinweis, an der Karte sichtbar (`decisions.md`, `docs-site/content/daten.md`). Das ist eine **dokumentierte Annahme**, keine DWD-Bestätigung, und keine Apple-Quelle. Eine „Content Rights“-Frage („enthält die App Fremdinhalte, und hast du die Rechte?“) erscheint nach meiner Erfahrung bei der App-Einreichung (ANNAHME, in den gelesenen Seiten nicht gefunden). Antwort vermutlich „Ja, Drittinhalte, Rechte durch offene Lizenz“.
- **Apple Weather / WeatherKit:** nicht genutzt. Die Pflicht zur Apple-Weather-Attribution gilt nur für WeatherKit-Daten (ANNAHME, nicht geprüft, da nicht zutreffend). Stattdessen DWD-Quellenangabe.
- **Standortnutzung:** `NSLocationWhenInUseUsageDescription` = „Dein Standort zentriert die Karte und lädt die Regenprognose direkt beim Deutschen Wetterdienst. Es gibt keine Hintergrundortung.“ Der Text nennt Zweck und Empfänger. Guideline 5.1.5 verlangt Einwilligung und direkte Relevanz (BESTÄTIGT [Q15]); ohne Standort bleibt die App über Ortssuche nutzbar (Repo-Annahme, bei Review mit abgelehnter Freigabe testen).
- **Foundation Models / Apple Intelligence:** Die optionale Einordnung läuft auf dem Gerät. Guideline 5.1.2(i) verlangt Einwilligung, wenn personenbezogene Daten an Dritte „including third-party AI“ gehen (BESTÄTIGT [Q15]); On-Device-Generierung ohne Übertragung berührt das nach Repo nicht (ANNAHME). Apple veröffentlicht „Acceptable use requirements for the Foundation Models framework“ [Q17]; Inhalt hier **nicht gelesen** → vor App-Store-Einreichung prüfen.

## 7. Beta App Review

- Prüft (BESTÄTIGT [Q1], [Q2], [Q15]): Beta-Builds und Metadaten gegen die App Review Guidelines; Guideline 2.2: Betas müssen für öffentliche Verteilung gedacht sein und die Richtlinien einhalten; TestFlight-Versionen dürfen nicht gegen Vergütung verteilt werden.
- Relevante Guidelines für eine Wetter-/Radar-App (Wortlaut in [Q15], Einschätzung ANNAHME):
  - 2.1 App Completeness: keine Platzhalter, funktionierende URLs, Test auf dem Gerät. Gefahr: 404 bei Datenschutz-/Support-URL.
  - 2.3.1(a): konkrete Review-Notizen; Radar nur Deutschland erwähnen, sonst wirkt die App außerhalb leer.
  - 4.2 Minimum Functionality: Kritik möglich, wenn die App „nicht nützlich, einzigartig oder app-artig“ wirkt. ShowerNow hat native Karte, Zeitleiste, Orte, Cache: gutes Gegenargument; in den Notizen nennen.
  - 5.1.1(i) Datenschutzerklärung benennt Datenerhebung und Weitergabe; 5.1.2 Nutzung/Weitergabe nur mit Einwilligung; 5.1.5 Standort nur bei Relevanz mit Einwilligung.
  - Genauigkeitshinweise: eine ausdrückliche Wetter-Genauigkeitsregel habe ich in den Guidelines nicht gefunden (Stichwort „weather“ ohne Treffer). 1.4.1 betrifft Medizin-Apps, nicht Wetter. Vorsichtshalber keine Sicherheitsversprechen.
- **Dauer:** In den gelesenen Apple-Seiten nicht angegeben → **UNKLAR**. Erfahrung (ANNAHME): meist Stunden bis wenige Tage.
- **Bei Ablehnung** (BESTÄTIGT [Q2]): Build-Status „Rejected“; Gründe in der Seitenleiste unter General im Eintrag **App Review**; Widerspruch über Kontakt zu TestFlight App Review; Metadaten/Notizen nachbessern, ggf. neuen Build zuordnen. Bei Zulassung erhalten Admins eine E-Mail [Q2].

## 8. Gruppe, Builds, Tester

Reihenfolge (BESTÄTIGT [Q2], [Q4]; Schaltflächen englisch, deutsche Namen nicht geprüft):

1. Interne Gruppe anlegen (Voraussetzung für externe Gruppe), Betreiber eintragen, Build intern installieren und kurz testen.
2. TestFlight → Seitenleiste „External Testing“ → **+** → Gruppenname → Create.
3. Test Information ausfüllen (Abschnitt 3), App Privacy ggf. vorbereiten (Abschnitt 4).
4. In der Gruppe **Add Builds**: Plattform und Version wählen, Build wählen, Add; im Dialog „What to Test“ ausfüllen, optional „Automatically notify testers“. Danach **Submit Review** (oder **Start Testing**, wenn bereits freigegeben). Nur Builds ohne „Internal Only“ erscheinen sinnvoll.
5. Auf Freigabe warten (Admins bekommen E-Mail). Ohne „Automatically notify“ danach unter Builds → Plattform → Version → **Notify Testers**.
6. Tester einladen: in der Gruppe **+** neben Testers (E-Mail, bestehende Tester oder CSV) oder **Create Public Link** (Open to Anyone / Filter by Criteria, optional Tester Limit 1 bis 10 000).
7. Tester installieren die kostenlose TestFlight-App, nehmen die Einladung an, geben Feedback in TestFlight [Q1].

Build-Ablauf: Ein Build ist 90 Tage testbar und danach nicht mehr verfügbar (BESTÄTIGT [Q1]). Frühzeitig neuen Build nachziehen; „Expire Build“ beendet das Testen vorzeitig [Q1, Q5]. Tipp von Apple: Insight-Karten oben in der Gruppe zeigen ablaufende oder inkompatible Builds [Q2].

## Screenshots

- **Braucht externes TestFlight Screenshots? Nein.** Die Test-Information-Seite nennt nur Beta App Description und Feedback Email als Pflicht; Screenshots/Kategorie in der Einladung stammen optional aus der letzten freigegebenen App-Store-Version (BESTÄTIGT [Q3]). Ohne App-Store-Version bleibt das leer.
- **Für den App Store (BESTÄTIGT [Q13]):** mindestens 1, höchstens 10 Screenshots je Gerätegröße, `.jpeg`/`.jpg`/`.png`, ohne Alphakanal/Transparenz. Pflichtgrößen: iPhone mit Dynamic Island (medium display), iPad 13-inch, **wenn die App auf iPad läuft**. ShowerNow läuft laut geprüften IPAs als Universal-App (`UIDeviceFamily [1,2]`, `signing.md`), also iPhone **und** iPad. Hinweis: `project.yml` nennt im Basisabschnitt `TARGETED_DEVICE_FAMILY: '1'`, die Projektdatei und die IPAs führen `1,2`. Das sollte der Release-Zuständige abgleichen.
- **Pixelgrößen (Hochformat, Querformat vertauscht; [Q13]):**
  - iPhone medium display (z. B. 17 Pro, 16): 1179×2556 oder 1206×2622.
  - iPhone large display (z. B. Pro Max): 1260×2736, 1290×2796 oder 1320×2868.
  - iPad 13": 2064×2752 oder 2048×2732.
- **Skalierung (BESTÄTIGT [Q13]):** Ist die Oberfläche über Größen und Sprachen hinweg konsistent, genügt die höchste benötigte Auflösung, kleinere werden automatisch skaliert. Fehlen Screenshots einer Größe, werden passende größere skaliert (Rückfallkette in [Q13]). Praktisch: iPhone 1206×2622 oder 1320×2868 und iPad 2064×2752 liefern; ob Apple beim Hochladen trotzdem eine zusätzliche Größe verlangt, zeigt die Maske (UNKLAR).
- **Neu in der Tabelle (UNKLAR in der Auswirkung):** [Q13] vermerkt unter „iPhone Duo“: „Starting in April 2027, screenshots will be required for any app using the iOS 27.1 SDK or later.“ Die Builds nutzen `iphoneos27.1` (`signing.md`). Ob und wie das ShowerNow betrifft (Sondergröße nur für faltbares Gerät?), vor der App-Store-Einreichung in Apples Hinweis zu iPhone Duo klären.
- **App-Vorschauvideos sind optional** (BESTÄTIGT [Q13], [Q14]): bis zu drei je Gerätegröße und Sprache, 15 bis 30 Sekunden, bis 500 MB, Hoch- oder Querformat, nur Bildschirmaufnahmen der App (Guideline 2.3.4, [Q15]).
- **Inhaltliche Regeln (BESTÄTIGT [Q15]):** Screenshots zeigen die App in Benutzung, nicht nur Titelbild/Splash (2.3.3); irreführendes Marketing ist Entfernungsgrund (2.3.1).
- **Erzeugung für ShowerNow (Vorgehensweise, ANNAHME aus Xcode-Erfahrung, Befehle vor Nutzung prüfen):**
  - Simulator mit passendem Gerätetyp (iPhone der Klasse 1206×2622 oder 1320×2868; iPad 13-inch) wählen, Bildschirmaufnahme per `xcrun simctl io <Gerät> screenshot <Datei>.png`; danach Pixelmaße kontrollieren (`sips -g pixelWidth -g pixelHeight <Datei>`). Statusleiste über `xcrun simctl status_bar` vereinheitlichen. Ein Simulatorstandort kann per `xcrun simctl location` gesetzt werden; nur öffentliche Orte verwenden (z. B. Großstadtzentrum), keine privaten.
  - Realistische Inhalte: echter Regen im Radar (Wetterlage abwarten; keine eingefärbten oder gefälschten Radarbilder), nicht leerer Himmel; sinnvolle Orte; keine Namen privater Adressen in der Orte-Liste; Light und Dark mindestens je ein Motiv; DWD-Quellenangabe sichtbar lassen.
  - Die vorhandenen Entwicklungs-Screenshots aus Prüfläufen liegen nur lokal im Arbeitsverzeichnis des Agenten, sind **nicht store-tauglich** (kaum Regen, falsche Größen, nicht zur Veröffentlichung gedacht) und werden nicht ins Repo übernommen.
- **Vorschlag 5 bis 6 Motive:**
  1. Radarkarte mit sichtbarem Regenfeld und Quellenangabe.
  2. Zeitleiste/Scrubben (Slider mit Zeitmarke).
  3. Ortsprognose mit Diagramm.
  4. Lokale Einordnung (Foundation Models, falls verfügbar; sonst weglassen).
  5. Orte-Liste mit öffentlichen Beispielorten.
  6. Info-Sheet mit Quellen und Datenschutz (zeigt Offenheit und Lizenz).

## 9. Ausblick App Store (nicht Teil der aktuellen Aufgabe)

Zusätzlich zu TestFlight (BESTÄTIGT [Q6], [Q9], [Q13]): Screenshots (Pflichtgrößen oben), Description (Pflicht, bis 4000 Zeichen), Keywords (Pflicht, bis 100 Bytes), Support URL (Pflicht, mit Kontaktdaten), Marketing URL (optional), Promotional Text (optional, 170 Zeichen), Copyright (Pflicht, Jahr plus Rechteinhaber), Version Release Settings, Privacy Policy URL, App Privacy, Altersfreigabe, Kategorie, App Review Information mit Kontakt. Preis und Verfügbarkeit (Länder, Frankreich siehe Abschnitt 5): Maske nicht gelesen (UNKLAR). Wetterdaten-Attribution: DWD-Quellenvermerk in App und Beschreibung; WeatherKit-Attribution entfällt, da nicht genutzt. Außerdem: Datenschutzlink in der App (Abschnitt „Die drei wichtigsten Punkte“), Foundation-Models-Richtlinien prüfen.

## 10. Checkliste

Vorbereitung
- [ ] Build 10 (oder neuer) **ohne** „Internal Only“ hochgeladen und in App Store Connect verarbeitet
- [ ] Eigener interner Test auf dem Gerät erfolgreich
- [ ] `https://showernow.linolaske.de/datenschutz` erreichbar (nicht 404)
- [ ] `https://showernow.linolaske.de/marketing` erreichbar
- [ ] `https://showernow.linolaske.de/support` erreichbar (Kontaktdaten im Impressum-Sinn geklärt)
- [ ] Proxy-Protokollierung der IP-Adressen geklärt (beeinflusst App-Privacy-Antwort)

TestFlight-Maske
- [ ] Interne Gruppe vorhanden
- [ ] Test Information: Beta App Description gesetzt
- [ ] Test Information: Feedback Email `<Feedback-E-Mail>` gesetzt
- [ ] Review-Kontakt `<Vorname Nachname>`, `<E-Mail für Prüfer>`, `<Telefon +49…>` gesetzt
- [ ] Review-Notizen eingefügt, „Sign-in required“ leer
- [ ] Marketing-/Privacy-URL eingetragen, falls Felder vorhanden
- [ ] Externe Gruppe angelegt, Build hinzugefügt, What to Test ausgefüllt
- [ ] Submit Review ausgelöst, Freigabe-E-Mail abgewartet
- [ ] Tester per E-Mail oder öffentlichem Link (mit Testerlimit) eingeladen
- [ ] Ablaufdatum (90 Tage) des Builds notiert

Datenschutz und Recht
- [ ] App-Privacy-Variante A oder B entschieden und in `decisions.md` festgehalten
- [ ] Export Compliance: Schlüssel `false` im hochgeladenen Build bestätigt
- [ ] Frankreich in der Verfügbarkeit bewusst entschieden
- [ ] Datenschutzlink in der App ergänzt (vor App Store)

App Store (später)
- [ ] Screenshots 5 bis 6 Motive für iPhone und iPad, echter Regen, Light/Dark
- [ ] Altersfreigabe-Fragebogen, Kategorie, Copyright, Beschreibung, Keywords
- [ ] Foundation-Models-Richtlinien gelesen, iPhone-Duo-Hinweis (April 2027) geklärt

## Was ich nicht prüfen konnte

- Kein Zugang zu App Store Connect: tatsächliche Masken, deutsche Beschriftungen und Pflichtmarkierungen der TestFlight-Maske (Marketing URL, Privacy Policy URL, Kontaktfelder) nicht gesehen.
- Dauer der Beta-Prüfung: keine Apple-Angabe gefunden.
- Ob App Privacy und Altersfreigabe vor externem TestFlight ausgefüllt sein müssen: nicht belegt.
- Apples Auslegung zu Koordinaten an den DWD: nicht belegbar; Entscheidung A/B offen.
- Rechtliche Einordnung (Exportkontrolle, Impressum, DWD-Lizenz): kein Rechtsrat.
- Foundation-Models-Nutzungsbedingungen, App-Store-Kategorieliste, Preis/Verfügbarkeit-Masken: nicht gelesen.
- Backend-URLs: am 30. Oktober 2026 noch 404.

## Quellen (Abruf jeweils 30. Oktober 2026)

| ID | Seite | URL |
|---|---|---|
| Q1 | TestFlight Overview | https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview |
| Q2 | Invite external testers | https://developer.apple.com/help/app-store-connect/test-a-beta-version/invite-external-testers |
| Q3 | Provide test information | https://developer.apple.com/help/app-store-connect/test-a-beta-version/provide-test-information |
| Q4 | Add internal testers | https://developer.apple.com/help/app-store-connect/test-a-beta-version/add-internal-testers |
| Q5 | Stop testing a build | https://developer.apple.com/help/app-store-connect/test-a-beta-version/stop-testing-a-build |
| Q6 | Platform version information (inkl. App Review information) | https://developer.apple.com/help/app-store-connect/reference/app-review-information |
| Q7 | App privacy details on the App Store | https://developer.apple.com/app-store/app-privacy-details/ |
| Q8 | Manage app privacy | https://developer.apple.com/help/app-store-connect/manage-app-information/manage-app-privacy |
| Q9 | App privacy (Referenz) | https://developer.apple.com/help/app-store-connect/reference/app-information/app-privacy |
| Q10 | Overview of export compliance | https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance |
| Q11 | ITSAppUsesNonExemptEncryption | https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption |
| Q12 | Age ratings values and definitions | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions |
| Q13 | Screenshot specifications | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications |
| Q14 | App preview specifications | https://developer.apple.com/help/app-store-connect/reference/app-preview-specifications |
| Q15 | App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Q16 | Export compliance documentation for encryption | https://developer.apple.com/help/app-store-connect/reference/app-information/export-compliance-documentation-for-encryption |
| Q17 | Acceptable use requirements for the Foundation Models framework (nur Existenz geprüft, nicht gelesen) | https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/ |

Hinweis: Q5 wurde abgerufen, die 90-Tage-Aussage stammt aus Q1.
