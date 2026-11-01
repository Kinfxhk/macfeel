#!/usr/bin/env python3
"""macfeel ui — a local, dependency-free control panel for the tweak table.

Binds 127.0.0.1 only. Reads state with `defaults read`, writes through bin/macfeel so the
GUI and the CLI can never disagree about what a tweak means or how it is typed.
"""
import argparse
import json
import subprocess
import sys
import threading
import webbrowser
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BIN = ROOT / "bin" / "macfeel"
TWEAKS = ROOT / "lib" / "tweaks.conf"
NOTES = ROOT / "lib" / "notes.conf"
HTML = ROOT / "lib" / "ui.html"

GROUPS = [
    ("win", "Shape", "窗口形狀與動畫"),
    ("kbd", "Keyboard", "鍵盤與輸入"),
    ("dock", "Dock", "Dock 與 Space"),
    ("spaces", "Dock", "Dock 與 Space"),
    ("finder", "Finder", "檔案管理"),
    ("shot", "Screenshots", "截圖"),
    ("ptr", "Pointer", "滑鼠與觸控板"),
    ("menubar", "Chrome", "選單列與全螢幕"),
    ("chrome", "Chrome", "選單列與全螢幕"),
]


def group_of(tid: str):
    prefix = tid.split(".")[0]
    for p, name, subtitle in GROUPS:
        if p == prefix:
            return name, subtitle
    return "Other", "其他"


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


def load_notes():
    notes = {}
    if NOTES.exists():
        for line in NOTES.read_text(encoding="utf-8").splitlines():
            if not line.strip() or line.startswith("#"):
                continue
            tid, _, text = line.partition("\t")
            notes[tid] = text
    return notes


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


def state():
    tweaks = load_tweaks()
    notes = load_notes()
    macos = subprocess.run(["sw_vers", "-productVersion"], capture_output=True, text=True).stdout.strip()
    sip = subprocess.run(["csrutil", "status"], capture_output=True, text=True).stdout.strip()
    items = []
    for t in tweaks:
        cur = read_default(t["domain"], t["key"])
        want = expand(t["value"])
        if cur is None:
            st = "unset"
        elif norm(cur) == norm(want):
            st = "sync"
        else:
            st = "drift"
        group, subtitle = group_of(t["id"])
        items.append({**t, "current": cur, "want": want, "state": st,
                      "note": notes.get(t["id"], ""), "group": group, "groupSubtitle": subtitle})
    order = []
    for _, name, sub in GROUPS:
        if name not in [g["name"] for g in order]:
            order.append({"name": name, "subtitle": sub})
    return {"version": (ROOT / "VERSION").read_text().strip() if (ROOT / "VERSION").exists() else "0.1.0",
            "macos": macos, "sip": sip, "items": items, "groups": order}


def run_cli(args, timeout=120):
    p = subprocess.run([str(BIN)] + args, capture_output=True, text=True, timeout=timeout)
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

    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self._send(200, HTML.read_text(encoding="utf-8"), "text/html; charset=utf-8")
        elif self.path == "/api/state":
            self._send(200, json.dumps(state(), ensure_ascii=False))
        else:
            self._send(404, json.dumps({"error": "not found"}))

    def do_POST(self):
        length = int(self.headers.get("Content-Length") or 0)
        body = json.loads(self.rfile.read(length) or b"{}")
        try:
            if self.path == "/api/apply":
                profile = body.get("profile", "linux")
                args = ["apply", profile] + (["--dry-run"] if body.get("dry") else [])
                res = run_cli(args, timeout=180)
            elif self.path == "/api/restore":
                res = run_cli(["restore"], timeout=180)
            elif self.path == "/api/toggle":
                tid = body.get("id", "")
                t = next((x for x in load_tweaks() if x["id"] == tid), None)
                if not t:
                    self._send(400, json.dumps({"error": "unknown tweak"})); return
                cur = read_default(t["domain"], t["key"])
                synced = cur is not None and norm(cur) == norm(expand(t["value"]))
                res = run_cli(["set", tid, "--unset"] if synced else ["set", tid], timeout=30)
            else:
                self._send(404, json.dumps({"error": "not found"})); return
            self._send(200, json.dumps({**res, "state": state()}, ensure_ascii=False))
        except subprocess.TimeoutExpired:
            self._send(504, json.dumps({"error": "command timed out"}))
        except Exception as exc:  # never leave the page hanging
            self._send(500, json.dumps({"error": str(exc)}))


def main():
    ap = argparse.ArgumentParser(description="macfeel control panel")
    ap.add_argument("--port", type=int, default=8765)
    ap.add_argument("--no-open", action="store_true")
    args = ap.parse_args()

    httpd = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    url = f"http://127.0.0.1:{args.port}/"
    print(f"macfeel ui → {url}   (Ctrl+C 停止)")
    if not args.no_open:
        threading.Timer(0.6, lambda: webbrowser.open(url)).start()
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped")


if __name__ == "__main__":
    main()
