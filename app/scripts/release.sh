#!/bin/bash
# Archive macfeel and upload it to App Store Connect (TestFlight).
#
# STATUS: not yet exercised end to end. Everything up to `xcodebuild archive`
# has been run successfully (unsigned); the signing/export/upload steps need the
# Apple ID signed into Xcode, or an App Store Connect API key.
#
#   TEAM_ID=XXXXXXXXXX ./scripts/release.sh            # uses Xcode's account
#   TEAM_ID=XXXXXXXXXX ASC_KEY_PATH=... ASC_KEY_ID=... ASC_ISSUER_ID=... ./scripts/release.sh
#
# Optional: VERSION=1.0.1 BUILD=2
set -euo pipefail
cd "$(dirname "$0")/.."

: "${TEAM_ID:?set TEAM_ID (developer.apple.com/account -> Membership details)}"
VERSION=${VERSION:-1.0.0}
BUILD=${BUILD:-1}
DERIVED=${DERIVED:-build/DerivedData}
ARCHIVE=build/macfeel.xcarchive
EXPORT=build/export

echo "== regenerate project =="
xcodegen generate

echo "== archive $VERSION ($BUILD) =="
rm -rf "$ARCHIVE" "$EXPORT"
xcodebuild archive \
  -project macfeel.xcodeproj \
  -scheme macfeel \
  -configuration Release \
  -archivePath "$ARCHIVE" \
  -derivedDataPath "$DERIVED" \
  -allowProvisioningUpdates \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  MARKETING_VERSION="$VERSION" \
  CURRENT_PROJECT_VERSION="$BUILD"

echo "== export options =="
mkdir -p build
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>$TEAM_ID</string>
	<key>uploadSymbols</key><true/>
	<key>stripSwiftSymbols</key><true/>
</dict>
</plist>
PLIST

echo "== export + upload =="
if [ -n "${ASC_KEY_PATH:-}" ]; then
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath "$EXPORT" \
    -allowProvisioningUpdates \
    -authenticationKeyPath "$ASC_KEY_PATH" \
    -authenticationKeyID "${ASC_KEY_ID:?}" \
    -authenticationKeyIssuerID "${ASC_ISSUER_ID:?}"
else
  xcodebuild -exportArchive \
    -archivePath "$ARCHIVE" \
    -exportOptionsPlist build/ExportOptions.plist \
    -exportPath "$EXPORT" \
    -allowProvisioningUpdates
fi

echo
echo "Uploaded. Next: App Store Connect -> TestFlight -> add the build to a group."
echo "Internal testers (up to 100 App Store Connect users) need no App Review."
