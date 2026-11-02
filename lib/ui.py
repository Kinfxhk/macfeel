#!/usr/bin/env python3
"""macfeel ui — a local, dependency-free control panel for the tweak table.

Binds 127.0.0.1 only. Reads state with `defaults read`, writes through bin/macfeel so the
GUI and the CLI can never disagree about what a tweak means or how it is typed.

Every user-facing string comes from lib/i18n/*.tsv; the panel can switch language without a
restart (it re-fetches /api/state?lang=…).
"""
import argparse
import json
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import parse_qs, urlparse

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "bin" / "macfeel"
TWEAKS = ROOT / "lib" / "tweaks.conf"
I18N = ROOT / "lib" / "i18n"
HTML = ROOT / "lib" / "ui.html"

LANGS = ["en", "zh_Hant", "zh_Hans"]
LANG_LABEL = {"en": "English", "zh_Hant": "繁體中文", "zh_Hans": "简体中文"}
COL = {"en": 1, "zh_Hant": 2, "zh_Hans": 3}   # index after the key column

GROUPS = [
    ("win", "Shape"),
    ("kbd", "Keyboard"),
    ("dock", "Dock"),
    ("spaces", "Dock"),
    ("finder", "Finder"),
    ("shot", "Screenshots"),
    ("ptr", "Pointer"),
    ("menubar", "Chrome"),
    ("chrome", "Chrome"),
]
GROUP_LABEL = {
    "Shape":       {"en": "Shape and motion",              "zh_Hant": "視窗形狀與動畫",  "zh_Hans": "窗口形状与动画"},
    "Keyboard":    {"en": "Keyboard",                      "zh_Hant": "鍵盤",            "zh_Hans": "键盘"},
    "Dock":        {"en": "Dock",                          "zh_Hant": "Dock",            "zh_Hans": "Dock"},
    "Finder":      {"en": "Finder",                        "zh_Hant": "Finder",          "zh_Hans": "Finder"},
    "Screenshots": {"en": "Screenshots",                   "zh_Hant": "截圖",            "zh_Hans": "截图"},
    "Pointer":     {"en": "Pointer",                       "zh_Hant": "滑鼠與觸控板",    "zh_Hans": "鼠标与触控板"},
    "Chrome":      {"en": "Menu bar",                      "zh_Hant": "選單列",          "zh_Hans": "菜单栏"},
}


def load_tsv(path: Path):
    """id/key -> {lang: text}"""
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        out[parts[0]] = {"en": parts[1], "zh_Hant": parts[2], "zh_Hans": parts[3]}
    return out


DESC = load_tsv(I18N / "desc.tsv")
NOTES = load_tsv(I18N / "notes.tsv")
UI = load_tsv(I18N / "ui.tsv")
_SNAPSHOT_TAKEN = False


def t(key: str, lang: str, **kw) -> str:
    entry = UI.get(key)
    text = (entry or {}).get(lang) or (entry or {}).get("en") or key
    for k, v in kw.items():
        text = text.replace("{" + k + "}", str(v))
    return text


def group_of(tid: str) -> str:
    prefix = tid.split(".")[0]
    for p, name in GROUPS:
        if p == prefix:
            return name
    return "Other"


def load_tweaks():
    rows = []
    for line in TWEAKS.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 8:
            continue
        tid, profiles, domain, key, typ, value, needs, desc = parts
        rows.append(dict(id=tid, profiles=profiles.split(","), domain=domain, key=key,
                         type=typ, value=value, needs=needs, desc=desc))
    return rows


def read_default(domain: str, key: str):
    try:
        out = subprocess.run(["defaults", "read", domain, key], capture_output=True, text=True, timeout=10)
    except Exception:
        return None
    if out.returncode != 0:
        return None
    return out.stdout.strip()


def norm(v):
    if v is None:
        return None
    if v in ("true", "TRUE", "1"):
        return "1"
    if v in ("false", "FALSE", "0"):
        return "0"
    try:
        return f"{float(v):.6f}"
    except ValueError:
        return v


def expand(v: str) -> str:
    return str(Path(v).expanduser()) if v.startswith("~") else v


def detect_lang() -> str:
    try:
        loc = subprocess.run(["defaults", "read", "-g", "AppleLocale"],
                             capture_output=True, text=True, timeout=5).stdout.strip()
    except Exception:
        loc = ""
    loc = loc or ""
    if "Hans" in loc or loc.startswith(("zh_CN", "zh_SG")):
        return "zh_Hans"
    if loc.startswith("zh"):
        return "zh_Hant"
    return "en"


PRESET_ALIAS = {
    "light": "light",
    "standard": "standard,light",
    "hardcore": "hardcore,standard,light",
    "chrome": "chrome,light",
    "linux": "hardcore,standard,light",
    "minimal": "light",
}
PRESET_ORDER = ["light", "standard", "hardcore"]


def preset_count(profile, tweaks):
    wanted = set(PRESET_ALIAS.get(profile, profile).split(","))
    return sum(1 for tw in tweaks if wanted & set(tw["profiles"]))


def load_ranges():
    """id -> {min, max, step} for the numeric tweaks that get a slider."""
    path = ROOT / "lib" / "ranges.conf"
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 4:
            continue
        out[parts[0]] = {"min": parts[1], "max": parts[2], "step": parts[3]}
    return out


def load_speed():
    """level -> {tweak id: value}, straight from lib/speed.conf."""
    path = ROOT / "lib" / "speed.conf"
    out = {}
    if not path.exists():
        return out
    for line in path.read_text(encoding="utf-8").splitlines():
        if not line.strip() or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        out.setdefault(parts[0], {})[parts[1]] = parts[2]
    return out


def state(lang: str = "en"):
    lang = lang if lang in LANGS else "en"
    ranges = load_ranges()
    tweaks = load_tweaks()
    macos = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip()
    sip = subprocess.run(["csrutil", "status"], capture_output=True, text=True).stdout.strip()
    items = []
    for tw in tweaks:
        cur = read_default(tw["domain"], tw["key"])
        want = expand(tw["value"])
        if cur is None:
            st = "unset"
        elif norm(cur) == norm(want):
            st = "sync"
        else:
            st = "drift"
        g = group_of(tw["id"])
        items.append({
            **tw,
            "current": cur, "want": want, "state": st, "group": g,
            "groupSubtitle": GROUP_LABEL.get(g, {}).get(lang, g),
            "desc": DESC.get(tw["id"], {}).get(lang) or DESC.get(tw["id"], {}).get("en") or tw["desc"],
            "note": NOTES.get(tw["id"], {}).get(lang) or NOTES.get(tw["id"], {}).get("en") or "",
            "range": ranges.get(tw["id"]),
            "needsLabel": ("" if tw["needs"] in ("-", "") else
                           (UI.get(f"needs.{tw['needs']}", {}).get(lang)
                            or UI.get(f"needs.{tw['needs']}", {}).get("en") or "")),
        })
    groups, seen = [], set()
    for _, name in GROUPS:
        if name in seen:
            continue
        seen.add(name)
        groups.append({"name": name, "subtitle": GROUP_LABEL.get(name, {}).get(lang, name)})
    return {
        "version": (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").exists() else "0.1.0",
        "macos": macos, "sip": sip, "lang": lang, "langs": LANGS,
        "langLabels": LANG_LABEL,
        "ui": {k: (v.get(lang) or v.get("en")) for k, v in UI.items()},
        "items": items, "groups": groups, "speed": load_speed(),
        "presets": [{"id": pid, "count": preset_count(pid, tweaks)} for pid in PRESET_ORDER],
    }


def run_cli(args, timeout=120, lang=None):
    env = None
    if lang:
        import os
        env = {**os.environ, "MACFEEL_LANG": lang}
    p = subprocess.run([str(BIN)] + args, capture_output=True, text=True, timeout=timeout, env=env)
    return {"code": p.returncode, "out": (p.stdout or "") + (p.stderr or "")}


class Handler(BaseHTTPRequestHandler):
    server_version = "macfeel-ui"

    def log_message(self, fmt, *args):  # keep the terminal readable
        sys.stderr.write("  %s\n" % (fmt % args))

    def _send(self, code, body, ctype="application/json; charset=utf-8"):
        data = body.encode("utf-8") if isinstance(body, str) else body
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(data)))
        self.send_header("Cache-Control", "no-store")
        self.end_headers()
        self.wfile.write(data)

    def _lang(self, query=None, body=None):
        lang = self.server.default_lang
        if query:
            lang = parse_qs(query).get("lang", [lang])[0]
        if body:
            lang = body.get("lang", lang)
        return lang if lang in LANGS else "en"

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path in ("/", "/index.html"):
            self._send(200, HTML.read_text(encoding="utf-8"), "text/html; charset=utf-8")
        elif parsed.path == "/api/state":
            self._send(200, json.dumps(state(self._lang(parsed.query)), ensure_ascii=False))
        else:
            self._send(404, json.dumps({"error": "not found"}))

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        lang = self._lang(body=body)
        try:
            if self.path == "/api/apply":
                profile = body.get("profile", "linux")
                args = ["apply", profile] + (["--dry-run"] if body.get("dry") else [])
                res = run_cli(args, timeout=180, lang=lang)
            elif self.path == "/api/restore":
                res = run_cli(["restore"], timeout=180, lang=lang)
            elif self.path == "/api/set":
                tid = body.get("id", "")
                raw = body.get("value", "")
                rng = load_ranges().get(tid)
                tw = next((x for x in load_tweaks() if x["id"] == tid), None)
                if not tw:
                    self._send(400, json.dumps({"error": "unknown tweak"})); return
                if not rng:
                    self._send(400, json.dumps({"error": "not an adjustable tweak"})); return
                try:
                    num = float(raw)
                except (TypeError, ValueError):
                    self._send(400, json.dumps({"error": "value must be a number"})); return
                lo, hi = float(rng["min"]), float(rng["max"])
                if not (lo <= num <= hi):
                    self._send(400, json.dumps({"error": f"value must be between {lo} and {hi}"})); return
                global _SNAPSHOT_TAKEN
                if not _SNAPSHOT_TAKEN:
                    run_cli(["snapshot"], timeout=60, lang=lang)
                    _SNAPSHOT_TAKEN = True
                text = ("%g" % num) if tw["type"] == "float" else str(int(num))
                res = run_cli(["set", tid, text], timeout=30, lang=lang)
            elif self.path == "/api/toggle":
                tid = body.get("id", "")
                tw = next((x for x in load_tweaks() if x["id"] == tid), None)
                if not tw:
                    self._send(400, json.dumps({"error": "unknown tweak"})); return
                cur = read_default(tw["domain"], tw["key"])
                synced = cur is not None and norm(cur) == norm(expand(tw["value"]))
                res = run_cli(["set", tid, "--unset"] if synced else ["set", tid], timeout=30, lang=lang)
            else:
                self._send(404, json.dumps({"error": "not found"})); return
            self._send(200, json.dumps({**res, "state": state(lang)}, ensure_ascii=False))
        except subprocess.TimeoutExpired:
            self._send(504, json.dumps({"error": "command timed out"}))
        except Exception as exc:  # never leave the page hanging
            self._send(500, json.dumps({"error": str(exc)}))


def main():
    ap = argparse.ArgumentParser(description="macfeel control panel")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--lang", default=None, help="en | zh_Hant | zh_Hans")
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    httpd = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    httpd.default_lang = args.lang if args.lang in LANGS else detect_lang()
    url = f"http://127.0.0.1:{args.port}/"
    print(f"macfeel ui → {url}   (lang {httpd.default_lang}, Ctrl+C 停止)")
    if not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
