# Weitergabe amtlicher DWD-Warnungen (CAP) per Backend, Push und App

Stand/Abruf der Quellen: 07.11.2026. Reine Recherche, keine Rechtsberatung. Die Seiten wurden über ein Abruf-Werkzeug gelesen, das Inhalte zusammenfasst. Wörtliche Zitate sind kurz und stammen aus diesen Zusammenfassungen; vor einer Veröffentlichung gegen die Originalseite prüfen.

## Fazit

**Erlaubt unter Auflagen.** Abruf von `opendata.dwd.de/weather/alerts/cap` durch ein privates oder kommerzielles Backend sowie Weitergabe an Endnutzer (Push, In-App) sind nach GeoNutzV, DWDG und CC BY 4.0 ausdrücklich vorgesehen (kommerziell eingeschlossen). Bedingungen: Quelle nennen, Warnungen unverändert und vollständig weitergeben. Wird der Inhalt verändert, gilt eine Sonderregel (siehe Auflagen). Ein ausdrückliches Verbot der Weitergabe für Dritte-Dienste wurde nicht gefunden. Ungeklärt bleibt, wie weit Kürzen für Push-Texte als "Veränderung" gilt (siehe offene Punkte).

## 1. Belegte Fakten (Primärquellen)

| Aussage | Quelle (abgerufen 07.11.2026) |
|---|---|
| Inhalte/Geodaten des DWD: Weiterverwendung "ausschließlich" unter CC BY 4.0 mit ordnungsgemäßer Quellenkennzeichnung; Quellenvermerk nötig, wenn DWD als Quelle identifizierbar ist. Gilt für "alle bereitgestellten meteorologischen Wetter- und Klimainformationen mit Ortsbezug". | https://www.dwd.de/DE/service/rechtliche_hinweise/rechtliche_hinweise_node.html |
| GeoNutzV § 2: Geodaten werden "für alle derzeit bekannten sowie für alle zukünftig bekannten Zwecke kommerzieller und nicht kommerzieller Nutzung geldleistungsfrei" bereitgestellt. Sie dürfen u. a. vervielfältigt, präsentiert, verändert, bearbeitet und an Dritte übermittelt sowie in Produkte und Anwendungen in öffentlichen Netzen eingebunden werden. | https://www.gesetze-im-internet.de/geonutzv/BJNR054700013.html |
| GeoNutzV § 3: Quellenvermerke und rechtliche Hinweise erkennbar und in optischem Zusammenhang einbinden; Veränderungen mit Veränderungshinweis im Quellenvermerk versehen "oder, sofern die geodatenhaltende Stelle dies verlangt, der beigegebene Quellenvermerk gelöscht wird". | gleiche Quelle |
| GeoNutzV § 4: Haftungsbeschränkung des Trägers der Stelle bei Fahrlässigkeit (nicht bei Verletzung von Leben, Körper, Gesundheit). | gleiche Quelle |
| DWDG § 4 Abs. 1 Nr. 3: Erstellung, Herausgabe und Verbreitung amtlicher Warnungen ist Aufgabe des DWD. | https://www.gesetze-im-internet.de/dwdg/BJNR287100998.html (Zusammenfassung des Abrufwerkzeugs) |
| DWDG § 6 Abs. 2a Nr. 2: Leistungen an die Allgemeinheit zur öffentlichen Verbreitung von Warnungen sind entgeltfrei. | gleiche Quelle |
| DWDG § 7: Verbreitung von Daten und Produkten, "insbesondere von Warnungen", nur unter Angabe der Quelle zulässig; Urheberrechtsschutz bleibt unberührt. | gleiche Quelle |
| Open-Data-FAQ: Zugang ohne Registrierung; Nutzung unter CC BY 4.0 mit Quellenvermerk; Geodaten bundesweit entgeltfrei, ausdrücklich auch für "wirtschaftlich erfolgreiche Angebote". Eine FAQ zu Warnungen oder Abrufhäufigkeit gibt es auf der Seite nicht. | https://www.dwd.de/DE/leistungen/opendata/faqs_opendata.html |
| Quellenvermerk-Vorlage: Pflicht auch bei Auszügen und geändertem Datenformat; Textform "Quelle: Deutscher Wetterdienst" oder DWD-Logo (min. 127 x 34 px bei 72 dpi), unmittelbar bei der Information. Für Veränderungen mindestens Nennung in zentralem Quellenverzeichnis/Impressum, Beispiele "Datenbasis: Deutscher Wetterdienst, eigene Elemente ergänzt". **"Wenn vom DWD ausgegebene amtliche Wetterwarnungen verändert werden, ist der beigegebene Quellvermerk zu löschen."** | https://www.dwd.de/DE/service/rechtliche_hinweise/vorlagen_quellenangabe.html |
| Datenpolitik: Weitergabe meteorologischer Informationen unter Vorbehalt geeigneter Quellenangabe; Geodaten für Deutschland nach GeoNutzV mit Quellenangabe weiterverwendbar. Einschränkung nur für Flugwetterdaten (METAR u. a.) auf Luftfahrtzwecke; nicht relevant für CAP. | https://www.dwd.de/DE/derdwd/datenpolitik.html |
| Disclaimer: keine Gewähr für Aktualität, Richtigkeit, Vollständigkeit; keine Haftung für technische Internetausfälle. Warnungen werden dort nicht gesondert behandelt. | https://www.dwd.de/DE/service/disclaimer/disclaimer_node.html |
| Verzeichnisindex `weather/alerts/cap/` enthält 12 Ordner (COMMUNEUNION_*, DISTRICT_* mit CELLS/DWD/EVENT, DIFF/STAT), keine Readme im Index. CAP-Profil 2.1.14 (15.10.2023) und Produktübersicht liegen als PDF unter `.../opendata/help/warnungen/`. Die PDF-Inhalte selbst konnten **nicht** gelesen werden. | https://opendata.dwd.de/weather/alerts/cap/ ; https://www.dwd.de/DE/leistungen/opendata/hilfe.html |

## 2. Auslegung (nicht wörtlich belegt)

- Ein Backend, das CAP-Dateien abruft und an Endnutzer pusht, ist "Übermittlung an Dritte" und "Einbindung in Anwendungen" im Sinne GeoNutzV § 2 Abs. 2; kommerzielle Nutzung ist erlaubt. Eine Pflicht zum Vertrag mit dem DWD ergibt sich aus den gelesenen Texten nicht.
- Warnungen sind nach DWDG § 7 ausdrücklich quellenpflichtig. Der Quellenvermerk gehört zur Warnung selbst, nicht nur ins Impressum.
- Die Löschregel für Warnungen bedeutet sinngemäß: Wer Warntexte verändert, darf sie nicht mehr als DWD-Quelle ausgeben, damit nicht der Eindruck einer amtlichen Warnung entsteht. Das dient Irreführungsschutz. Eigene abgeleitete Hinweise (z. B. "Frostgefahr" aus Temperaturdaten) dürfen daher nicht als "amtliche Warnung" oder mit DWD-Vermerk erscheinen.
- Vollständigkeit und Zeitnähe: Eine Suchtreffer-Zusammenfassung zu einer anderen DWD-Seite (Nutzungsbedingungen Globalstrahlungskarten, nicht selbst gelesen) enthält die Formulierung, Quellenvermerke seien bei Wetterwarnungen zu entfernen, "wenn nicht sichergestellt ist, dass diese jederzeit vollständig und unverzüglich allen Nutzern zur Verfügung gestellt werden". Das gilt für ein anderes Produkt, zeigt aber die Haltung des DWD: Warnungen sollen vollständig, aktuell und ungekürzt weitergegeben werden. Als Leitlinie übernehmen, nicht als belegte Rechtspflicht für CAP.
- Haftung: Der DWD schließt Gewähr aus, GeoNutzV § 4 begrenzt seine Haftung bei Fahrlässigkeit. Daraus folgt kein Freibrief für den App-Anbieter; Verzögerungen oder Ausfälle der eigenen Push-Kette liegen im eigenen Risiko. Deutlicher Hinweis in der App, dass die App kein Ersatz für offizielle Warnkanäle ist, ist ratsam (Auslegung, keine Rechtsberatung).

## 3. Vergleich mit etablierten Apps (nur Hinweise)

- Der Suchlauf lieferte keine verlässliche Dokumentation der Lizenzlage einzelner Drittapps. Gefunden wurden nur: eine Open-Source-Wetter-App (EMS-2022-Beitrag, GPL v3, Warnbenachrichtigungen ohne proprietären Push-Dienst), eine Homey-Community-App, die die öffentlichen DWD-Warn-JSONs nutzt, und eine Datenbank-Übersicht. Sie belegen nur, dass Drittanbieter-Dienste existieren, nicht ihre Rechtslage.
- bundesAPI/dwd-api (https://github.com/bundesAPI/dwd-api): inoffizielle Doku zur DWD-App-API (JSON-Warnfeeds auf S3). Lizenzabschnitt war nicht lesbar. Nur als Hinweis; diese undokumentierte App-API ist keine Open-Data-Quelle und für ein Produkt nicht zu empfehlen. Für ShowerNow bleibt CAP von opendata.dwd.de die saubere Quelle.
- NINA/BBK, WarnWetter-App wurden nicht geprüft.

## 4. Auflagen für ShowerNow (Empfehlung)

1. **Quellenvermerk direkt bei jeder Warnung** (Karte, Detail, Push-Detailansicht): "Quelle: Deutscher Wetterdienst" (optional DWD-Logo, min. 127 x 34 px). Zusätzlich im Impressum/Quellenverzeichnis: "Datenbasis: Deutscher Wetterdienst".
2. **Wortlaut nicht verändern**: `headline`, `description`, `instruction`, Stufe, Zeitraum unverändert anzeigen. Kein Umformulieren, keine automatische Zusammenfassung unter DWD-Quellenvermerk.
3. **Push-Text**: Wenn gekürzt werden muss, entweder (a) nur Ereignis/Stufe/Ort/Zeit als eigene Meldung ohne DWD-Vermerk im Push und vollständige DWD-Warnung samt Vermerk beim Öffnen, oder (b) Rückfrage beim DWD (Entwurf unten). Bis zur Klärung Variante (a); nicht als "amtliche Warnung" betiteln, wenn gekürzt.
4. **Eigene Warnungen trennen**: Selbst abgeleitete Hinweise (Frost, Glatteis, Regen) klar als "ShowerNow-Hinweis" kennzeichnen, ohne DWD-Vermerk und nicht visuell als amtliche Warnung gestalten.
5. **Aktualität**: Rücknahmen (`msgType` Cancel/Update, Ablauf `expires`) zeitnah umsetzen; veraltete Warnungen nicht weiter anzeigen. Zeitpunkt des Abrufs bzw. "Stand" anzeigen.
6. **Hinweistext** in der App: keine Gewähr für Vollständigkeit und Verzögerung; amtliche Warnungen auch über WarnWetter/NINA/Rundfunk; Notfälle 112.
7. **Abruf schonend**: Nur Diff-/Stat-Ordner nach Bedarf pollen, kein aggressives Intervall, `If-Modified-Since` nutzen. Eine ausdrückliche Rate-Limit-Vorgabe wurde nicht gefunden (siehe offene Punkte).
8. **Datenschutz**: Standort nur als Warnzelle/Landkreis ans Backend, keine Verläufe (siehe AGENTS.md).

## 5. Offene Punkte

- Ob gekürzte Push-Texte als "Veränderung" gelten und der Vermerk dann zu entfallen hat, ist nicht ausdrücklich geregelt.
- Inhalt des CAP-Profils 2.1.14 und der Produktübersicht (mögliche Nutzungs-/Verarbeitungshinweise, Abrufintervalle) nicht gelesen; PDF später per Download prüfen.
- Gibt es Last-/Abrufgrenzen für opendata.dwd.de und für Apps mit vielen Nutzern? Nicht gefunden.
- Ob der DWD vom Anbieter eine Löschung des Quellenvermerks verlangt (GeoNutzV § 3 Nr. 2), bei Veränderung, ist nur durch die Seite zur Quellenangabe bestätigt.
- Rechtliche Würdigung (Irreführung, UWG, Haftung bei Verspätung) nicht Gegenstand; juristische Prüfung vor Release empfohlen.
- Der Originalwortlaut der Seite mit der "jederzeit vollständig und unverzüglich"-Klausel wurde nicht direkt gelesen.

## 6. Entwurf E-Mail an CAP@dwd.de

Betreff: Anfrage zur Weitergabe amtlicher Warnungen (CAP, Open Data) in einer App

Sehr geehrte Damen und Herren,

wir entwickeln eine native Wetter-App für iOS und planen, die CAP-Warnungen von opendata.dwd.de (weather/alerts/cap) über ein eigenes Backend abzurufen und an Nutzer als Push-Benachrichtigung und in der App anzuzeigen. Wir möchten dies im Rahmen der Open-Data-Bedingungen (GeoNutzV, CC BY 4.0, DWDG § 7) korrekt umsetzen und bitten um Bestätigung bzw. Hinweise zu folgenden Punkten:

1. Ist die beschriebene Nutzung (Abruf durch ein Backend, Weitergabe an Endnutzer, auch kommerziell) ohne gesonderte Vereinbarung zulässig?
2. Die Warntexte (headline, description, instruction) zeigen wir unverändert mit "Quelle: Deutscher Wetterdienst" an. Push-Benachrichtigungen sind in der Länge begrenzt: Genügt es, in der Benachrichtigung nur Ereignis, Warnstufe, Region und Gültigkeit als eigene Kurzfassung ohne DWD-Quellenvermerk zu zeigen und die vollständige, unveränderte Warnung mit Quellenvermerk beim Öffnen? Oder wünschen Sie ein anderes Vorgehen?
3. Gibt es Vorgaben zur maximalen Abruffrequenz oder zur Nutzung der DIFF-/STAT-Verzeichnisse?
4. Gibt es weitere Pflichten (z. B. Logo, Hinweistexte, Umgang mit Aktualisierungen und Rücknahmen)?

Vielen Dank für Ihre Rückmeldung.

Mit freundlichen Grüßen
[Name]
[App-Name / Organisation]
[Kontakt-E-Mail]
