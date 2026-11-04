#!/bin/bash
# Build macfeel.app — a real macOS bundle, ad-hoc signed, no Xcode project needed.
#
#   ./build.sh              # build/macfeel.app (Developer ID / unsandboxed variant)
#   ./build.sh --sandbox    # same binary, App Sandbox + temporary exception entitlements
#   ./build.sh --run        # build, then launch
#   ./build.sh --test       # build, then run --selftest and --plan
#
# xcrun is licence-gated on this machine, so the toolchain is called directly;
# swap TOOLCHAIN for `xcrun` once `sudo xcodebuild -license accept` has run and
# you want the normal Xcode flow.
set -euo pipefail
cd "$(dirname "$0")"

TC=/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin
SDK=/Applications/Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/SDKs/MacOSX.sdk
TARGET=arm64-apple-macos14.0
APP=build/macfeel.app
MODE=direct
RUN=0
TEST=0

for arg in "$@"; do
  case "$arg" in
    --sandbox) MODE=sandbox ;;
    --run) RUN=1 ;;
    --test) TEST=1 ;;
  esac
done

echo "== compile =="
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
"$TC/swiftc" -sdk "$SDK" -target "$TARGET" -swift-version 5 -O \
  -o "$APP/Contents/MacOS/macfeel" \
  Sources/main.swift Sources/App.swift Sources/Model.swift Sources/Backend.swift \
  Sources/Engine.swift Sources/Theme.swift Sources/Views.swift

echo "== resources =="
# The tweak tables stay in lib/ so the CLI and the app can never disagree.
cp ../lib/tweaks.conf ../lib/defaults.conf ../lib/ranges.conf ../lib/notes.conf "$APP/Contents/Resources/"
cp ../lib/i18n/ui.tsv "$APP/Contents/Resources/"

echo "== bundle =="
cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key><string>macfeel</string>
	<key>CFBundleDisplayName</key><string>macfeel</string>
	<key>CFBundleExecutable</key><string>macfeel</string>
	<key>CFBundleIdentifier</key><string>com.kinfxhk.macfeel</string>
	<key>CFBundleIconFile</key><string>AppIcon</string>
	<key>CFBundlePackageType</key><string>APPL</string>
	<key>CFBundleShortVersionString</key><string>1.0.0</string>
	<key>CFBundleVersion</key><string>1</string>
	<key>LSMinimumSystemVersion</key><string>14.0</string>
	<key>LSApplicationCategoryType</key><string>public.app-category.utilities</string>
	<key>NSHumanReadableCopyright</key><string>MIT licence · github.com/Kinfxhk/macfeel</string>
	<key>NSPrincipalClass</key><string>NSApplication</string>
	<key>NSSupportsAutomaticTermination</key><false/>
	<key>NSSupportsSuddenTermination</key><false/>
</dict>
</plist>
PLIST
printf 'APPL????' > "$APP/Contents/PkgInfo"
if [ -f Assets/AppIcon.icns ]; then cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"; fi

if [ "$MODE" = sandbox ]; then
  echo "== sign (sandbox + temporary exception) =="
  codesign -s - -f --entitlements sandbox.entitlements "$APP"
else
  echo "== sign (ad-hoc, unsandboxed) =="
  codesign -s - -f "$APP"
fi
codesign -d --entitlements - "$APP" 2>&1 | sed -n '1,20p' || true

if [ "$TEST" = 1 ]; then
  echo
  echo "== selftest =="
  "$APP/Contents/MacOS/macfeel" --selftest || true
  echo
  echo "== plan standard =="
  "$APP/Contents/MacOS/macfeel" --plan standard
fi

if [ "$RUN" = 1 ]; then
  echo "== launch =="
  open "$APP"
fi
