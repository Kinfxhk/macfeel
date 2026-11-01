#!/usr/bin/env python3
"""Per-key restore for macfeel.

`defaults import` replaces a domain wholesale, which is wrong here: the global domain is
shared with every app, and importing an old export silently rolls back unrelated settings
some other app wrote in the meantime. This walks the tweak table instead and restores only
the keys macfeel owns — writing the snapshot value when the key was there, deleting it when
the snapshot did not have it.
"""
import plistlib
import subprocess
import sys
from pathlib import Path


def load_rows(conf: Path):
    rows = []
    for line in conf.read_text(encoding="utf-8").splitlines():
        if not line or line.startswith("#"):
            continue
        parts = line.split("\t")
        if len(parts) != 8:
            continue
        tid, profiles, domain, key, typ, value, needs, desc = parts
        rows.append((tid, domain, key, typ, value))
    return rows


def snapshot_value(snap: Path, domain: str, key: str):
    name = "NSGlobalDomain" if domain == "-g" else domain
    path = snap / f"{name}.plist"
    if not path.exists():
        return (False, None)
    with path.open("rb") as f:
        data = plistlib.load(f)
    if key in data:
        return (True, data[key])
    return (False, None)


def main() -> int:
    if len(sys.argv) != 3:
        print("usage: restore.py <snapshot-dir> <tweaks.conf>", file=sys.stderr)
        return 2
    snap = Path(sys.argv[1])
    rows = load_rows(Path(sys.argv[2]))
    if not snap.is_dir():
        print(f"no such snapshot: {snap}", file=sys.stderr)
        return 1

    changed = 0
    for tid, domain, key, typ, value in rows:
        present, saved = snapshot_value(snap, domain, key)
        if present:
            if isinstance(saved, bool):
                cmd = ["defaults", "write", domain, key, "-bool", "true" if saved else "false"]
            elif isinstance(saved, int):
                cmd = ["defaults", "write", domain, key, "-int", str(saved)]
            elif isinstance(saved, float):
                cmd = ["defaults", "write", domain, key, "-float", repr(saved)]
            else:
                cmd = ["defaults", "write", domain, key, "-string", str(saved)]
        else:
            cmd = ["defaults", "delete", domain, key]
        res = subprocess.run(cmd, capture_output=True, text=True)
        if res.returncode == 0:
            changed += 1
            what = "deleted" if not present else f"{key}={saved}"
            print(f"  restored {tid:<22} {what}")
        elif "does not exist" in (res.stderr or ""):
            pass  # already absent, nothing to undo
        else:
            print(f"  FAILED   {tid:<22} {(res.stderr or '').strip()}", file=sys.stderr)
    print(f"restored {changed} keys from {snap}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
