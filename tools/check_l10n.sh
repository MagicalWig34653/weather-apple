#!/bin/bash
# Lokalisierungs-Lint fuer Showers (de/en). Bash 3.2 + Python-3-Standardbibliothek, keine weiteren Abhaengigkeiten.
#
# Aufruf (aus beliebigem Verzeichnis):
#   tools/check_l10n.sh               Pruefen; Exit 1 bei Fehlern oder NEUEN Treffern gegenueber tools/l10n_baseline.txt
#   tools/check_l10n.sh --baseline    heutige Treffer als Ausgangslage nach tools/l10n_baseline.txt schreiben
#   tools/check_l10n.sh --strict      Baseline ignorieren (Abnahme L6: muss mit leerer Baseline Exit 0 liefern)
#   tools/check_l10n.sh --list        zusaetzlich alle Treffer einzeln auflisten
#
# Immer Fehler (nicht baseline-faehig): kaputte .strings, Schluesselparitaet de/en je Bundle, Platzhalterparitaet.
# Baseline-faehig (Treffer, nur neue verbieten): missing-key (Schluessel im Code ohne .strings-Eintrag),
#   hardcoded-ui (deutsches Literal in Text/Button/Label/Toggle/Picker/Section/navigationTitle/TextField/
#   accessibilityLabel/accessibilityHint/alert), hardcoded-literal (sonstige deutsche Literale in Quellcode).
# Warnung (kein Fehler): identische de/en-Texte (Ausnahmen: tools/l10n_allow.txt, Zeilen "identical:SCHLUESSEL").
# Allow-Liste tools/l10n_allow.txt: eine Zeile = exakter Literaltext (zeilenunabhaengig); optional "glob::text"
#   beschraenkt auf Dateien; "#" beginnt Kommentar. Fixtures und *UITestStub*-Dateien sind immer ausgenommen.
set -eu
ROOT=$(cd "$(dirname "$0")/.." && pwd)
if ! command -v python3 >/dev/null 2>&1; then echo "check_l10n: python3 nicht gefunden" >&2; exit 2; fi
exec python3 -I - "$ROOT" "$@" <<'PY'
import fnmatch, os, re, subprocess, sys
from collections import Counter, defaultdict

root = sys.argv[1]
args = set(sys.argv[2:])
BASELINE = os.path.join(root, "tools", "l10n_baseline.txt")
ALLOW = os.path.join(root, "tools", "l10n_allow.txt")
# Name -> (Verzeichnis, Tabelle). "Shared" ist die gemeinsame Tabelle SharedTexts.strings (Quelle Shared/, in jedem Target mit Shared-Code).
BUNDLES = {"Weather": ("Weather/Resources", "Localizable.strings"), "WeatherWidgets": ("WeatherWidgets/Resources", "Localizable.strings"),
           "WeatherWatch": ("WeatherWatch", "Localizable.strings"), "WeatherWatchWidgets": ("WeatherWatchWidgets", "Localizable.strings"),
           "Shared": ("Shared/Resources", "SharedTexts.strings")}
CODE_DIRS = ["Weather", "Shared", "WeatherWidgets", "WeatherWatch", "WeatherWatchWidgets", "WeatherNotificationService"]
SKIP_PARTS = ("Fixtures", "UITestStub", "Preview")

def rel(p): return os.path.relpath(p, root)

# ---------- Allow-Liste ----------
allow_text, allow_ident = [], set()
if os.path.exists(ALLOW):
    for line in open(ALLOW, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line.strip() or line.lstrip().startswith("#"): continue
        if line.startswith("identical:"): allow_ident.add(line[len("identical:"):].strip()); continue
        if "::" in line: g, t = line.split("::", 1)
        else: g, t = "*", line
        allow_text.append((g.strip(), t))
def allowed(path, text):
    return any(fnmatch.fnmatch(path, g) and t == text for g, t in allow_text)

# ---------- .strings ----------
STR_RE = re.compile(r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
def parse_strings(path):
    s = open(path, encoding="utf-8").read()
    s_nc = re.sub(r"/\*.*?\*/", lambda m: " " * len(m.group(0)), s, flags=re.S)
    s_nc = re.sub(r"(?m)^\s*//.*$", "", s_nc)
    entries, rest = {}, s_nc
    for m in STR_RE.finditer(s_nc):
        entries[m.group(1)] = m.group(2)
    leftover = STR_RE.sub("", s_nc).strip()
    return entries, leftover
PH_RE = re.compile(r"%(?:(\d+)\$)?[-+ 0#]*(?:\d+|\*)?(?:\.\d+)?(hh|h|ll|l|q|z|t|j)?([@dDiuUxXoOfeEgGcCsSp])")
def placeholders(v):
    v = v.replace("%%", "")
    return sorted((m.group(1) or "", (m.group(2) or "") + m.group(3)) for m in PH_RE.finditer(v))

errors, warnings = [], []
all_keys = set()
counts = Counter()
for name, (base, table) in BUNDLES.items():
    d = {}
    for lang in ("de", "en"):
        p = os.path.join(root, base, lang + ".lproj", table)
        if not os.path.exists(p):
            errors.append(("missing-file", rel(p), "Datei fehlt")); continue
        entries, leftover = parse_strings(p)
        if leftover:
            errors.append(("syntax", rel(p), "nicht lesbare Zeile(n): " + leftover[:60].replace("\n", " ")))
        d[lang] = entries
    if len(d) < 2: continue
    all_keys |= set(d["de"]) | set(d["en"])
    for k in sorted(set(d["de"]) - set(d["en"])): errors.append(("key-parity", name, "nur in de: " + k))
    for k in sorted(set(d["en"]) - set(d["de"])): errors.append(("key-parity", name, "nur in en: " + k))
    for k in sorted(set(d["de"]) & set(d["en"])):
        if placeholders(d["de"][k]) != placeholders(d["en"][k]):
            errors.append(("placeholder-parity", name, "%s: de %s / en %s" % (k, [c for _, c in placeholders(d["de"][k])], [c for _, c in placeholders(d["en"][k])])))
        if d["de"][k] == d["en"][k] and k not in allow_ident and d["de"][k] not in allow_ident and len(d["de"][k]) > 0:
            warnings.append(("identical-text", name, "%s = %r" % (k, d["de"][k])))
    counts["keys:" + name] = len(d["de"])
# InfoPlist.strings: Paritaet
ip = {}
for lang in ("de", "en"):
    p = os.path.join(root, "Weather/Resources", lang + ".lproj", "InfoPlist.strings")
    if os.path.exists(p):
        e, left = parse_strings(p); ip[lang] = e
        if left: errors.append(("syntax", rel(p), "nicht lesbare Zeile(n)"))
    else: errors.append(("missing-file", rel(p), "Datei fehlt"))
if len(ip) == 2:
    for k in sorted(set(ip["de"]) ^ set(ip["en"])): errors.append(("key-parity", "InfoPlist", k))
    for k in sorted(set(ip["de"]) & set(ip["en"])):
        if placeholders(ip["de"][k]) != placeholders(ip["en"][k]): errors.append(("placeholder-parity", "InfoPlist", k))
for lang in ("de", "en"):
    p = os.path.join(root, "Weather/Resources", lang + ".lproj", "InfoPlist.strings")
    if os.path.exists(p) and subprocess.run(["plutil", "-lint", p], capture_output=True).returncode not in (0,) and os.path.exists("/usr/bin/plutil"):
        errors.append(("syntax", rel(p), "plutil -lint fehlgeschlagen"))
for name, table in BUNDLES.values():
    for lang in ("de", "en"):
        p = os.path.join(root, name, lang + ".lproj", table)
        if os.path.exists(p) and os.path.exists("/usr/bin/plutil") and subprocess.run(["plutil", "-lint", p], capture_output=True).returncode != 0:
            errors.append(("syntax", rel(p), "plutil -lint fehlgeschlagen"))

# ---------- Swift-Quellen ----------
UI_CALL = re.compile(r"(?:\bText|\bButton|\bLabel|\bToggle|\bPicker|\bSection|\bTextField|\bSecureField|\bLink|\bMenu|\bnavigationTitle|\baccessibilityLabel|\baccessibilityHint|\baccessibilityValue|\balert|\bconfirmationDialog|\bnavigationSubtitle|\bContentUnavailableView|\bGroupBox|\bDisclosureGroup)\s*\(\s*$")
UMLAUT = re.compile(r"[äöüÄÖÜß]")
WORDS = set("""der die das und oder nicht kein keine keinen mit wird werden ist sind bei von zum zur dein deine deinen
regen wetter ort orte warnung warnungen fehler stufe karte mitteilung mitteilungen fertig abbrechen löschen einstellungen
quelle daten stand heute morgen gestern jetzt minuten stunden min std sonne ebene zeitleiste messung vorhersage rückblick
modell hinweis hinweise umkreis höchstens aktuell aktueller standort laden lädt verfügbar noch wieder bitte versuche
kann können nur eine einen einem keiner gerät geräte aus ein an aktiv ohne netz veraltet speichern umbenennen
""".split())
WORD_RE = re.compile(r"[A-Za-zÄÖÜäöüß]+")
def is_german(text):
    t = re.sub(r"\\\([^)]*\)", " ", text)
    if UMLAUT.search(t): return True
    words = [w.lower() for w in WORD_RE.findall(t)]
    hits = [w for w in words if w in WORDS]
    # ein Wort reicht nur bei eindeutig deutschen Woertern; Einzelwoerter wie "an"/"aus"/"ein"/"min" brauchen Kontext
    strong = [w for w in hits if w not in ("an", "aus", "ein", "min", "std", "stand", "ort", "region", "karte", "daten", "sonne", "modell", "regen")]
    if strong: return True
    return len(hits) >= 2 or (len(hits) == 1 and len(words) == 1 and hits[0] in ("regen", "orte", "karte", "daten", "sonne", "modell", "ort"))

def tokenize(src):
    """Liefert (offset, line, text, kind) fuer jedes String-Literal; Kommentare ueberspringen."""
    i, n, line, out = 0, len(src), 1, []
    while i < n:
        c = src[i]
        if c == "\n": line += 1; i += 1; continue
        if src.startswith("//", i):
            j = src.find("\n", i); i = n if j < 0 else j; continue
        if src.startswith("/*", i):
            j = src.find("*/", i + 2); j = n if j < 0 else j + 2
            line += src.count("\n", i, j); i = j; continue
        if src.startswith('"""', i):
            j = src.find('"""', i + 3); j = n if j < 0 else j
            out.append((i, line, src[i + 3:j], "multi")); line += src.count("\n", i, j + 3); i = j + 3; continue
        if c == '"':
            j, depth = i + 1, 0
            buf = []
            while j < n:
                ch = src[j]
                if ch == "\\" and j + 1 < n:
                    if src[j + 1] == "(": depth += 1
                    buf.append(src[j:j + 2]); j += 2; continue
                if depth and ch == ")": depth -= 1
                if ch == '"' and not depth: break
                if ch == "\n" and not depth: break
                buf.append(ch); j += 1
            out.append((i, line, "".join(buf), "single")); i = j + 1; continue
        i += 1
    return out

findings = []   # (category, file, line, text)
code_keys = []
KEY_CALLS = re.compile(r'(?:NSLocalizedString|String\s*\(\s*localized:|LocalizedStringKey|LocalizedStringResource)\s*\(?\s*$')
for d in CODE_DIRS:
    for dirpath, dirs, files in os.walk(os.path.join(root, d)):
        for f in files:
            if not f.endswith(".swift"): continue
            p = os.path.join(dirpath, f); r = rel(p)
            if any(s in r for s in SKIP_PARTS): continue
            src = open(p, encoding="utf-8").read()
            for off, line, text, kind in tokenize(src):
                before = src[max(0, off - 90):off]
                tail = before.rstrip()
                if KEY_CALLS.search(tail):
                    # Schluesselargument: symbolische Schluessel pruefen; deutscher Klartext als Schluessel ist ein UI-Treffer
                    if re.fullmatch(r"[A-Z][A-Z0-9_]+", text): code_keys.append((r, line, text))
                    elif is_german(text) and not allowed(r, text): findings.append(("hardcoded-ui", r, line, text))
                    continue
                if re.search(r"(?:value|comment|table|defaultValue)\s*:\s*$", tail): continue
                if re.search(r"accessibilityIdentifier\s*\(\s*$|identifier\s*:\s*$|Logger|os_log|print\s*\(\s*$|fatalError|assert", tail[-60:]): continue
                if not is_german(text): continue
                if allowed(r, text): continue
                cat = "hardcoded-ui" if UI_CALL.search(tail) else "hardcoded-literal"
                findings.append((cat, r, line, text))
for r, line, k in code_keys:
    if k not in all_keys:
        findings.append(("missing-key", r, line, k))

# ---------- Baseline ----------
def ident(f): return "%s\t%s\t%s" % (f[0], f[1], f[3].replace("\t", " ").replace("\n", "\\n"))
cur = Counter(ident(f) for f in findings)
if "--baseline" in args:
    with open(BASELINE, "w", encoding="utf-8") as fh:
        fh.write("# Ausgangslage tools/check_l10n.sh (Kategorie<TAB>Datei<TAB>Text); zeilenunabhaengig, mit Anzahl bei Wiederholung.\n")
        fh.write("# Neu erzeugen: tools/check_l10n.sh --baseline. Ziel (L6): leer.\n")
        for k in sorted(cur): fh.write("%s\t%d\n" % (k, cur[k]) if cur[k] > 1 else "%s\n" % k)
    print("Baseline geschrieben: %s (%d Treffer, %d Eintraege)" % (rel(BASELINE), sum(cur.values()), len(cur)))
base = Counter()
if "--strict" not in args and os.path.exists(BASELINE):
    for line in open(BASELINE, encoding="utf-8"):
        line = line.rstrip("\n")
        if not line or line.startswith("#"): continue
        parts = line.split("\t")
        if len(parts) == 4: base["\t".join(parts[:3])] += int(parts[3])
        else: base[line] += 1
new = Counter()
for k, v in cur.items():
    if v > base.get(k, 0): new[k] = v - base.get(k, 0)
gone = sum(max(0, v - cur.get(k, 0)) for k, v in base.items())

# ---------- Ausgabe ----------
print("== check_l10n: Lokalisierungs-Lint ==")
for k in sorted(counts): print("  Schluessel %-34s %d" % (k.split(":", 1)[1], counts[k]))
by_cat = Counter(f[0] for f in findings)
print("\nTreffer je Kategorie (heutiger Stand%s):" % ("" if "--strict" not in args else ", strict"))
for cat in ("missing-key", "hardcoded-ui", "hardcoded-literal"): print("  %-18s %d" % (cat, by_cat.get(cat, 0)))
print("  %-18s %d   (Fehler)" % ("Paritaet/Syntax", len(errors)))
print("  %-18s %d   (Warnung)" % ("identical-text", len(warnings)))
print("  gesamt Treffer     %d   Baseline %d   neu %d   erledigt %d" % (sum(cur.values()), sum(base.values()), sum(new.values()), gone))
per_file = defaultdict(Counter)
for f in findings: per_file[f[1]][f[0]] += 1
print("\nTreffer je Datei:")
for fn in sorted(per_file, key=lambda x: (-sum(per_file[x].values()), x)):
    c = per_file[fn]
    print("  %4d  %-62s ui=%d literal=%d key=%d" % (sum(c.values()), fn, c["hardcoded-ui"], c["hardcoded-literal"], c["missing-key"]))
if errors:
    print("\nFEHLER:")
    for e in errors: print("  [%s] %s: %s" % e)
if warnings:
    print("\nWarnungen:")
    for w in warnings: print("  [%s] %s: %s" % w)
if new or "--list" in args:
    print("\n%s:" % ("NEUE Treffer" if new else "Alle Treffer"))
    remaining = Counter(new) if new and "--list" not in args else None
    for f in sorted(findings, key=lambda x: (x[1], x[2])):
        k = ident(f)
        if remaining is not None:
            if remaining.get(k, 0) <= 0: continue
            remaining[k] -= 1
        print("  %s:%d [%s] %s" % (f[1], f[2], f[0], f[3][:90]))
if errors or new:
    print("\nErgebnis: FEHLER (Exit 1)"); sys.exit(1)
print("\nErgebnis: OK (Exit 0)")
PY
