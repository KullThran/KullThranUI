#!/usr/bin/env python3
"""Locale audit for KullThranUI.

Fails (exit 1) when:
  * a string used through the locale layer (L["..."], LText("..."), LTextFmt,
    and the local wrappers that index the locale table) has no entry in one of
    the nine translated locales, or still shows the English text there;
  * a translated locale contains Spanish text that belongs to esES;
  * a translation changes the format placeholders (%s, %d, ...) of its key;
  * user-facing text is written straight into the code instead of going
    through the locale layer: SetText/AddLine/print/Print/... calls and
    label/desc/title/tooltip fields with a literal that has no translation;
  * Spanish text appears in code outside the Locales folder.

Usage: python3 tests/locale_check.py [root] [--json report.json]
Exceptions live in tests/locale_check_allow.json, each with a reason.
"""
import json
import os
import re
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

LOCALES = ["esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW"]
NON_LATIN = {"ruRU", "koKR", "zhCN", "zhTW"}

LUA_DUMP = r'''
local root, out = arg[1], arg[2]
local toc = assert(io.open(root .. "/KullThranUI/KullThranUI.toc")):read("*a")
local ns, env = {}, setmetatable({}, { __index = _G })
for line in toc:gmatch("[^\r\n]+") do
    local file = line:match("^(Locales[\\/].-%.lua)%s*$")
    if file then
        file = file:gsub("\\", "/")
        local handle = assert(io.open(root .. "/KullThranUI/" .. file))
        local source = handle:read("*a"):gsub("^\239\187\191", "")
        handle:close()
        local chunk = assert(loadstring(source, file))
        setfenv(chunk, env)
        chunk("KullThranUI", ns)
    end
end
local function esc(s) return (s:gsub("\\", "\\\\"):gsub("\n", "\\n"):gsub("\r", "\\r"):gsub("\t", "\\t")) end
local handle = assert(io.open(out, "w"))
for _, code in ipairs({ "enUS", "esES", "deDE", "frFR", "itIT", "ptBR", "ruRU", "koKR", "zhCN", "zhTW" }) do
    for k, v in pairs(ns.Locales[code]) do
        if type(k) == "string" and type(v) == "string" then
            handle:write(code, "\t", esc(k), "\t", esc(v), "\n")
        end
    end
end
handle:close()
'''


def unescape(text):
    out, i = [], 0
    while i < len(text):
        c = text[i]
        if c == "\\" and i + 1 < len(text):
            out.append({"n": "\n", "r": "\r", "t": "\t", "\\": "\\"}.get(text[i + 1], text[i + 1]))
            i += 2
        else:
            out.append(c)
            i += 1
    return "".join(out)


def load_locales(root):
    lua = os.environ.get("LUA", "lua5.1")
    with tempfile.TemporaryDirectory() as tmp:
        script = os.path.join(tmp, "dump.lua")
        dump = os.path.join(tmp, "dump.tsv")
        with open(script, "w", encoding="utf-8") as handle:
            handle.write(LUA_DUMP)
        subprocess.run([lua, script, root, dump], check=True)
        tables = {code: {} for code in ["enUS"] + LOCALES}
        with open(dump, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                code, key, value = line.rstrip("\n").split("\t", 2)
                tables[code][unescape(key)] = unescape(value)
    return tables


def expand(base, rel):
    path = os.path.normpath(os.path.join(base, rel))
    if not os.path.exists(path):
        return []
    if path.endswith(".lua"):
        return [path]
    if path.endswith(".xml"):
        found = []
        with open(path, encoding="utf-8", errors="replace") as handle:
            text = handle.read()
        for match in re.finditer(r'<(?:Script|Include)\s+file\s*=\s*"([^"]+)"', text):
            found.extend(expand(os.path.dirname(path), match.group(1).replace("\\", "/")))
        return found
    return []


def shipped_files(root):
    files, seen = [], set()
    for folder in sorted(os.listdir(root)):
        path = os.path.join(root, folder)
        if not folder.startswith("KullThranUI") or not os.path.isdir(path):
            continue
        for name in sorted(os.listdir(path)):
            if not name.endswith(".toc"):
                continue
            with open(os.path.join(path, name), encoding="utf-8", errors="replace") as handle:
                for line in handle:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    for found in expand(path, line.replace("\\", "/")):
                        if found not in seen:
                            seen.add(found)
                            files.append(found)
    return [f for f in files if "/Libraries/" not in f.replace("\\", "/") and "/Locales/" not in f.replace("\\", "/")]


LOCALE_TABLES = {"L", "locale", "Locale", "loc", "LOC", "LL", "localeTable"}
BASE_WRAPPERS = {"LText", "LTextFmt"}
SINK_METHODS = {"SetText", "AddLine", "AddDoubleLine", "SetFormattedText", "Print", "AddMessage",
                "SetTitle", "SetLabel", "SetButtonText", "SetPlaceholderText"}
SINK_FUNCS = {"print", "KT_PerfPrint", "message"}
FIELD_SINKS = {"name", "desc", "title", "label", "text", "tooltip", "tooltipText", "tooltipTitle",
               "header", "subtitle", "description", "hint", "button1", "button2", "button3",
               "emptyText", "summary", "caption", "heading", "helpText"}
SPANISH = re.compile(
    r"[ñÑ¿¡]|\b(?:[Mm]ódulo|[Nn]ingún|[Ee]stá|[Tt]ambién|[Dd]espués|[Aa]ún|[Cc]onfiguración|[Pp]osición|"
    r"[Oo]pciones|[Aa]ctivad[oa]|[Dd]esactivad[oa]|ACTIVADO|DESACTIVADO|[Bb]arras|[Ii]conos|[Úú]ltimo|"
    r"[Rr]atón|[Vv]entana|[Cc]argad[oa]|[Rr]eintentar|[Ee]stilos|[Ff]alló|[Pp]ulsa|[Aa]segúrate|"
    r"[Cc]onflictivos|[Cc]apturado|[Ii]nyectando|[Ll]ímite|[Aa]lcanzado|[Dd]etectado|[Pp]érdida|[Ss]in anchor|"
    r"[Nn]o se pudo|[Nn]o hay|[Nn]o se encontró|[Mm]azmorra|[Jj]efes?|[Tt]iempo restante|[Mm]uertes|[Ff]uerzas enemigas)\b")
FORMAT = re.compile(r"%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?([sdifgxXcq%])")
TOKEN_NOISE = re.compile(r"\|c[0-9a-fA-F]{8}|\|r|\|T[^|]*\|t|\|A[^|]*\|a|\|n|%(?:\d+\$)?[-+ #0]*\d*(?:\.\d+)?[sdifgxXcq%]|\n")


def natural_text(text):
    if re.fullmatch(r"Interface[\\/].*", text) or re.fullmatch(r"[A-Za-z0-9_.:/\\-]+", text) and re.search(r"[_./\\:]", text):
        return False
    if re.fullmatch(r"[a-z][A-Za-z0-9]*", text):  # identifiers and option keys
        return False
    if re.fullmatch(r"[A-Z0-9_]+", text) and "_" in text:  # constants
        return False
    words = re.findall(r"[^\W\d_]{2,}", TOKEN_NOISE.sub(" ", text))
    if not words:
        return False
    return not (len(words) == 1 and len(words[0]) < 3)


def placeholders(text):
    return sorted(m.group(1) for m in FORMAT.finditer(text) if m.group(1) != "%")


def scan(files, root):
    from locale_lex import lex
    used, sinks, fields, spanish = {}, [], [], []
    for path in files:
        with open(path, encoding="utf-8", errors="replace") as handle:
            tokens = lex(handle.read())
        rel = os.path.relpath(path, root).replace("\\", "/")
        wrappers = set(BASE_WRAPPERS)
        for i, tok in enumerate(tokens):
            if tok[1] != "function":
                continue
            j, name = i + 1, None
            while j < len(tokens) and tokens[j][1] != "(" and tokens[j][0] in ("name", "op"):
                if tokens[j][0] == "name":
                    name = tokens[j][1]
                j += 1
            if not name or j + 1 >= len(tokens) or tokens[j + 1][0] != "name":
                continue
            param = tokens[j + 1][1]
            body = tokens[j + 2:j + 60]
            for k in range(1, len(body) - 2):
                indexed = (body[k][1] == "[" and body[k - 1][0] == "name" and body[k - 1][1] in LOCALE_TABLES
                           and body[k + 1][:2] == ("name", param) and body[k + 2][1] == "]")
                wrapped = body[k][0] == "name" and body[k][1] in wrappers and body[k + 1][1] == "(" and body[k + 2][:2] == ("name", param)
                if indexed or wrapped:
                    wrappers.add(name)
                    break
        for i, tok in enumerate(tokens):
            if tok[0] != "str":
                continue
            text, line = tok[1], tok[2]
            p1 = tokens[i - 1] if i > 0 else ("", "", 0)
            p2 = tokens[i - 2] if i > 1 else ("", "", 0)
            p3 = tokens[i - 3] if i > 2 else ("", "", 0)
            nx = tokens[i + 1] if i + 1 < len(tokens) else ("", "", 0)
            where = "%s:%d" % (rel, line)
            if (p1[1] == "[" and p2[0] == "name" and p2[1] in LOCALE_TABLES and nx[1] == "]") or \
               (p1[1] == "(" and p2[0] == "name" and p2[1] in wrappers) or \
               (p1[0] == "name" and p1[1] in wrappers and p2[1] != "function"):
                used.setdefault(text, []).append(where)
                continue
            if SPANISH.search(text):
                spanish.append((where, text))
            if not natural_text(text):
                continue
            sink = None
            if p1[1] == "=" and p2[0] == "name" and p2[1] in FIELD_SINKS and p3[1] in ("{", ",", ";"):
                fields.append((where, p2[1], text))
                continue
            k, depth = i - 1, 0
            while k >= 0 and tokens[k][2] == line:
                if tokens[k][1] == ")":
                    depth += 1
                elif tokens[k][1] == "(":
                    if depth == 0:
                        callee = tokens[k - 1] if k > 0 else ("", "", 0)
                        before = tokens[k - 2] if k > 1 else ("", "", 0)
                        if callee[0] == "name" and ((callee[1] in SINK_METHODS and before[1] in (":", ".")) or callee[1] in SINK_FUNCS):
                            sink = callee[1]
                        break
                    depth -= 1
                k -= 1
            if sink:
                sinks.append((where, sink, text))
    return used, sinks, fields, spanish


def main():
    args = sys.argv[1:]
    report_path = None
    if "--json" in args:
        report_path = args[args.index("--json") + 1]
        del args[args.index("--json"):args.index("--json") + 2]
    root = os.path.abspath(args[0] if args else os.path.join(HERE, ".."))
    allow_path = os.path.join(HERE, "locale_check_allow.json")
    allow = {}
    if os.path.exists(allow_path):
        with open(allow_path, encoding="utf-8") as handle:
            allow = json.load(handle)
    same_ok = set(allow.get("sameAsEnglish", {}).get("keys", []))
    same_ok_loc = {(e["key"], e["locale"]) for e in allow.get("sameAsEnglish", {}).get("perLocale", [])}
    data_files = set(allow.get("dataFiles", {}).get("files", []))
    code_ok = {(e["file"], e["text"]) for e in allow.get("codeText", {}).get("entries", [])}
    code_ok_files = set(allow.get("codeText", {}).get("files", []))
    spanish_ok = {(e["file"], e["text"]) for e in allow.get("spanishInCode", {}).get("entries", [])}
    brand = re.compile(allow.get("sameAsEnglish", {}).get("tokens", "(?!)"))

    tables = load_locales(root)
    files = shipped_files(root)
    used, sinks, fields, spanish = scan(files, root)

    problems = {"missing": [], "english": [], "spanish": [], "format": [], "hardcoded": [], "spanishCode": []}

    def same_allowed(key, english):
        if key in same_ok:
            return True
        stripped = brand.sub(" ", TOKEN_NOISE.sub(" ", english))
        return not re.search(r"[^\W\d_]{3,}", stripped)

    for key, where in sorted(used.items()):
        english = tables["enUS"].get(key, key)
        if english == key and re.fullmatch(r"[A-Z][A-Z0-9]*(?:_[A-Z0-9]+)+", key):
            problems["missing"].append({"key": key, "locale": "enUS", "at": where[0]})
        if SPANISH.search(english):
            problems["spanish"].append({"key": key, "locale": "enUS", "value": english, "at": where[0]})
        for code in LOCALES:
            value = tables[code].get(key)
            if value is None:
                problems["missing"].append({"key": key, "locale": code, "at": where[0]})
                continue
            if value == english and code != "esES" or (code == "esES" and value == english and not SPANISH.search(key)):
                if not same_allowed(key, english) and (key, code) not in same_ok_loc:
                    problems["english"].append({"key": key, "locale": code, "at": where[0]})
                    continue
            es = tables["esES"].get(key)
            if code != "esES" and (re.search(r"[ñ¿¡]", value) or (es and value == es and es != english and (code in NON_LATIN or (code not in ("ptBR", "itIT") and SPANISH.search(value))))):
                problems["spanish"].append({"key": key, "locale": code, "value": value, "at": where[0]})
            if placeholders(value) != placeholders(english):
                problems["format"].append({"key": key, "locale": code, "value": value, "at": where[0]})

    def translated(text):
        return text in tables["deDE"] and all(text in tables[c] for c in LOCALES)

    for where, sink, text in sinks:
        rel = where.rsplit(":", 1)[0]
        if rel in code_ok_files or (rel, text) in code_ok:
            continue
        problems["hardcoded"].append({"at": where, "via": sink, "text": text})
    for where, field, text in fields:
        rel = where.rsplit(":", 1)[0]
        if rel in data_files or rel in code_ok_files or (rel, text) in code_ok or translated(text):
            continue
        problems["hardcoded"].append({"at": where, "via": "field " + field, "text": text})
    for where, text in spanish:
        rel = where.rsplit(":", 1)[0]
        if (rel, text) not in spanish_ok:
            problems["spanishCode"].append({"at": where, "text": text})

    total = sum(len(v) for v in problems.values())
    if report_path:
        with open(report_path, "w", encoding="utf-8") as handle:
            json.dump({"usedKeys": len(used), "files": len(files), "problems": problems}, handle, ensure_ascii=False, indent=1)
    labels = {
        "missing": "missing translation", "english": "still English", "spanish": "Spanish in another locale",
        "format": "placeholder mismatch", "hardcoded": "hardcoded UI text", "spanishCode": "Spanish text in code",
    }
    for kind, items in problems.items():
        for item in items[:400]:
            detail = item.get("key") or item.get("text")
            print("%-26s %-6s %s  %s" % (labels[kind], item.get("locale", ""), item["at"], json.dumps(detail, ensure_ascii=False)))
        if len(items) > 400:
            print("%-26s ... and %d more" % (labels[kind], len(items) - 400))
    print("locale check: %d keys in %d files, %d problems (%s)" % (
        len(used), len(files), total, ", ".join("%s %d" % (k, len(v)) for k, v in problems.items())))
    return 1 if total else 0


if __name__ == "__main__":
    sys.exit(main())
