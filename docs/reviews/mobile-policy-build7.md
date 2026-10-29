# Enger Review der Netzpolicy für Build 7

Stand: 28. Oktober 2026. Unabhängige Codelektüre des Policy-Diffs gegenüber `87915f8`; keine eigenen Builds, Tests, Live-DWD-Anfragen oder Uploads.

Nutzerentscheidung: „WLAN und Mobilfunk, aber nur solange Datensparmodus nicht aktiviert ist“.

## Ergebnis

Keine offenen P1-/P2-Befunde im begrenzten Diff. Freigabe der Netzpolicy für die gezielten Prüfungen und anschließende Build-7-Integration.

- Der gemeinsame Policyhelper erlaubt normale WLAN- und Mobilfunk-/Hotspotverbindungen unabhängig von `isExpensive`. `isConstrained`, inaktive App und Stromsparmodus sperren weiterhin.
- `NWPathMonitor` verwendet denselben Helper und verlangt zusätzlich einen verfügbaren Netzpfad. Es bleibt kein zweiter Ausschluss teurer Verbindungen bestehen.
- Die Prefetchsession erlaubt Mobilfunk und teure Verbindungen ausdrücklich, verbietet eingeschränkte Verbindungen und setzt `waitsForConnectivity = false`. Damit wird ein verweigerter Vorladetransport nicht allein durch eine Connectivity-Wartephase bis zur Nachfragepromotion festgehalten.
- Request-/Bytebudget, Speichergrenze, Referenz-/Frischeprüfung, Nachfragepriorität und Abbruchpfade sind durch diesen Diff unverändert.
- Zwei gezielte Policytests bilden normale und eingeschränkte WLAN-/Mobilfunkverbindungen sowie Stromsparmodus und inaktive App ab. Ihre Ausführung gehört dem Buildowner; dieser Review behauptet kein Testergebnis.
- Die zentrale Buildnummer wird auf `7` erhöht. Build 6 bleibt der bereits hochgeladene konservative Zwischenstand.

Geprüft: `RadarPrefetch.swift`, der betroffene Testdiff und `Configuration/Base.xcconfig`. Der Review ersetzt keine reale Mobilfunk-/Datensparmodusprüfung auf einem physischen Gerät.
