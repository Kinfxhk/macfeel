#!/usr/bin/env bash
# macfeel installer: put the CLI on PATH. Nothing is copied into system locations.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="${MACFEEL_BIN:-$HOME/.local/bin}"

[ -f "$HERE/bin/macfeel" ] || { echo "run this from the repo root" >&2; exit 1; }

mkdir -p "$TARGET_DIR"
ln -sf "$HERE/bin/macfeel" "$TARGET_DIR/macfeel"
chmod +x "$HERE/bin/macfeel"

echo "linked: $TARGET_DIR/macfeel -> $HERE/bin/macfeel"
case ":$PATH:" in
  *":$TARGET_DIR:"*) echo "ready: macfeel doctor" ;;
  *) echo "add this to your shell profile:"
     echo "  export PATH=\"$TARGET_DIR:\$PATH\"" ;;
esac
