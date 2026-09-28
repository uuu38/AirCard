#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Marketing version stamped into the bundle. Release CI overrides these from the
# pushed tag, while local builds keep the checked-in defaults so a plain
# `./build.sh` behaves exactly as before.
APP_VERSION="${APP_VERSION:-1.2.4}"
APP_BUILD="${APP_BUILD:-7}"

echo "==> [1/6] Building universal helper binaries (device_helper & airtraffic_host)..."
make clean
make all

APP_NAME="AirCard"
APP_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BIN_DIR="${RESOURCES_DIR}/bin"
LIB_DIR="${RESOURCES_DIR}/lib"

echo "==> [2/6] Scaffolding ${APP_NAME}.app bundle structure..."
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$BIN_DIR" "$LIB_DIR"

# Write Info.plist
cat << EOF > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleAllowMixedLocalizations</key>
    <true/>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
        <string>zh-Hant</string>
        <string>ja</string>
        <string>ko</string>
        <string>vi</string>
    </array>
    <key>CFBundleExecutable</key>
    <string>AirCard</string>
    <key>CFBundleIdentifier</key>
    <string>com.mak5er.aircard</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>AirCard</string>
    <key>CFBundleDisplayName</key>
    <string>AirCard</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${APP_BUILD}</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo "==> [3/6] Bundling universal tools & libraries..."
# Copy App Icon
if [ -f "dmg_assets/AppIcon.icns" ]; then
    cp "dmg_assets/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
fi

# Copy universal device_helper and airtraffic_host. Device discovery and log
# streaming both run through device_helper, which talks to MobileDevice.framework
# directly, so the bundle needs no libimobiledevice tooling.
cp build/device_helper "$BIN_DIR/"
cp build/airtraffic_host "$BIN_DIR/"

# Copy python backend scripts
cp apply_card_skin.py "$RESOURCES_DIR/"
cp aircard.py "$RESOURCES_DIR/"
cp aircard_backend.py "$RESOURCES_DIR/"
cp card_assets.py "$RESOURCES_DIR/"

# Install localization tables. Each Localizations/<lang>.lproj/Localizable.strings
# is copied verbatim into Contents/Resources, where Foundation resolves it
# against the user's preferred system languages at runtime. Adding a language
# means adding a folder here — no code change is required.
if [ -d "Localizations" ]; then
    for lproj in Localizations/*.lproj; do
        [ -d "$lproj" ] || continue
        cp -R "$lproj" "$RESOURCES_DIR/"
    done
fi

# The English table doubles as the key reference used by
# tools/check_localizations.py, so a bundle without it cannot be validated
# (translations would silently fall back to their keys).
if [ ! -f "${RESOURCES_DIR}/en.lproj/Localizable.strings" ]; then
    echo "ERROR: Localizations/en.lproj/Localizable.strings was not installed." >&2
    exit 1
fi

# A bundle without these cannot talk to a device at all, so fail here instead
# of shipping an app that reports "No iPhone found" for every user.
for tool in device_helper airtraffic_host; do
    if [ ! -x "${BIN_DIR}/${tool}" ]; then
        echo "ERROR: ${BIN_DIR}/${tool} is missing from the bundle." >&2
        exit 1
    fi
done

echo "==> [4/6] Compiling universal Swift binary (arm64 + x86_64)..."
if [ -z "${SWIFT_SDK:-}" ]; then
    SWIFT_SDK="$(xcrun --sdk macosx --show-sdk-path)"
    CLT_SWIFTUI_SDK="/Library/Developer/CommandLineTools/SDKs/MacOSX26.sdk"
    if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ] && [ -d "$CLT_SWIFTUI_SDK" ]; then
        SWIFT_SDK="$CLT_SWIFTUI_SDK"
    fi
fi
swiftc -sdk "$SWIFT_SDK" -O -parse-as-library -target arm64-apple-macosx14.0 AirCardApp.swift Localization.swift -o build/AirCard_arm64
swiftc -sdk "$SWIFT_SDK" -O -parse-as-library -target x86_64-apple-macosx14.0 AirCardApp.swift Localization.swift -o build/AirCard_x86_64
lipo -create -output "${MACOS_DIR}/AirCard" build/AirCard_arm64 build/AirCard_x86_64
chmod +x "${MACOS_DIR}/AirCard"

echo "==> [5/6] Setting permissions and signing ${APP_NAME}.app bundle..."
chmod -R 755 "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true
codesign --force --deep --sign - "$APP_DIR"

echo "==> [6/6] Generating styled DMG (${APP_NAME}.dmg)..."
DMG_STAGING="/tmp/aircard_dmg_staging"
rm -rf "$DMG_STAGING"
mkdir -p "$DMG_STAGING"
cp -R "$APP_DIR" "$DMG_STAGING/"

rm -f "build/${APP_NAME}.dmg"

if command -v create-dmg >/dev/null 2>&1; then
    # Headless runners have no Finder session to drive the window layout, and
    # create-dmg waits on AppleScript until it times out. --skip-jenkins keeps
    # the run non-interactive while still producing a mountable disk image.
    CREATE_DMG_CI_ARGS=()
    if [ -n "${GITHUB_ACTIONS:-}${CI:-}" ]; then
        CREATE_DMG_CI_ARGS+=(--skip-jenkins)
    fi

    create-dmg \
        "${CREATE_DMG_CI_ARGS[@]}" \
        --volname "AirCard" \
        --background "dmg_assets/background_700.png" \
        --window-pos 200 120 \
        --window-size 700 460 \
        --icon-size 110 \
        --icon "AirCard.app" 175 220 \
        --hide-extension "AirCard.app" \
        --app-drop-link 525 220 \
        --add-file "README.txt" "dmg_assets/README.txt" 350 360 \
        --filesystem APFS \
        --overwrite \
        "build/${APP_NAME}.dmg" \
        "$DMG_STAGING"
else
    ln -s /Applications "$DMG_STAGING/Applications"
    hdiutil create -volname "AirCard" -srcfolder "$DMG_STAGING" -ov -format UDZO "build/${APP_NAME}.dmg"
fi

echo "============================================================"
echo "🎉 SUCCESS: build/${APP_NAME}.dmg is ready!"
echo "    Version ${APP_VERSION} (build ${APP_BUILD})"
echo "============================================================"
