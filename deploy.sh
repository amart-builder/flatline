#!/bin/bash
set -euo pipefail

# Flatline iOS Deploy Script (adapted from etherealos/deploy.sh)
# Usage:
#   ./deploy.sh device     — Build & install directly to connected iPhone
#   ./deploy.sh testflight — Archive, export IPA, upload to App Store Connect
#   ./deploy.sh archive    — Just archive (no export/upload)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="${PROJECT_DIR:-$SCRIPT_DIR}"
PROJECT="Flatline.xcodeproj"
SCHEME="Flatline"
BUNDLE_ID="${BUNDLE_ID:-com.alexmartin.flatline}"
TEAM_ID="${TEAM_ID:-59SU2PWL49}"
ARCHIVE_PATH="${ARCHIVE_PATH:-/tmp/Flatline.xcarchive}"
EXPORT_DIR="${EXPORT_DIR:-/tmp/flatline-export}"
DERIVED_DATA="${DERIVED_DATA:-/tmp/flatline-derived}"
KEYCHAIN="${KEYCHAIN:-login.keychain-db}"

cd "$PROJECT_DIR"

# ── Helpers ──────────────────────────────────────────────────────

red()   { printf "\033[31m%s\033[0m\n" "$*"; }
green() { printf "\033[32m%s\033[0m\n" "$*"; }
blue()  { printf "\033[34m%s\033[0m\n" "$*"; }

step() { blue "▸ $*"; }
ok()   { green "✓ $*"; }
fail() { red "✗ $*"; exit 1; }

unlock_keychain() {
    step "Unlocking keychain..."
    security unlock-keychain -p "" "$HOME/Library/Keychains/$KEYCHAIN" 2>/dev/null || true
    security set-key-partition-list -S "apple-tool:,apple:,codesign:" -s -k "" \
        "$HOME/Library/Keychains/$KEYCHAIN" 2>/dev/null || true
    ok "Keychain unlocked"
}

resolve_deps() {
    step "Resolving Swift Package dependencies..."
    xcodebuild -resolvePackageDependencies \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        2>&1 | tail -5
    ok "Dependencies resolved"
}

device_id() {
    # Model names are multi-token, so parse the JSON instead of columns.
    local json="/tmp/flatline-devices.json"
    xcrun devicectl list devices --json-output "$json" >/dev/null 2>&1 || return 0
    /usr/bin/python3 - "$json" << 'PY'
import json, sys
data = json.load(open(sys.argv[1]))
for device in data.get("result", {}).get("devices", []):
    props = device.get("deviceProperties", {})
    conn = device.get("connectionProperties", {})
    if "iPhone" in (device.get("hardwareProperties", {}).get("deviceType") or "") \
       and conn.get("tunnelState") not in (None, "unavailable"):
        print(device.get("identifier", ""))
        break
PY
}

# ── Commands ─────────────────────────────────────────────────────

cmd_device() {
    step "Building & installing to connected iPhone..."
    unlock_keychain

    local DEVICE_ID
    DEVICE_ID=$(device_id)
    if [[ -z "$DEVICE_ID" ]]; then
        fail "No available iPhone found. Connect via USB (or same network), unlock it, and trust this Mac."
    fi
    ok "Found device: $DEVICE_ID"

    resolve_deps

    step "Building for device..."
    xcodebuild build \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -destination "id=$DEVICE_ID" \
        -derivedDataPath "$DERIVED_DATA" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        CODE_SIGN_STYLE=Automatic \
        OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
        2>&1 | tail -20
    ok "Build succeeded"

    local APP="$DERIVED_DATA/Build/Products/Debug-iphoneos/Flatline.app"
    [[ -d "$APP" ]] || fail "Built app not found at $APP"

    step "Installing to device..."
    xcrun devicectl device install app --device "$DEVICE_ID" "$APP" 2>&1 | tail -3
    ok "Installed. Launching..."
    xcrun devicectl device process launch --device "$DEVICE_ID" "$BUNDLE_ID" 2>&1 | tail -2 || true
    ok "Done — Flatline is on the phone."
}

cmd_archive() {
    step "Archiving..."
    unlock_keychain
    resolve_deps

    rm -rf "$ARCHIVE_PATH"

    xcodebuild archive \
        -project "$PROJECT" \
        -scheme "$SCHEME" \
        -archivePath "$ARCHIVE_PATH" \
        -destination "generic/platform=iOS" \
        -allowProvisioningUpdates \
        DEVELOPMENT_TEAM="$TEAM_ID" \
        CODE_SIGN_STYLE=Automatic \
        OTHER_CODE_SIGN_FLAGS="--keychain $KEYCHAIN" \
        2>&1 | tail -30

    if [[ -d "$ARCHIVE_PATH" ]]; then
        ok "Archive created: $ARCHIVE_PATH"
    else
        fail "Archive failed — check output above"
    fi
}

cmd_testflight() {
    cmd_archive

    step "Creating export options..."
    cat > /tmp/FlatlineExportOptions.plist << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>app-store-connect</string>
    <key>teamID</key>
    <string>${TEAM_ID}</string>
    <key>destination</key>
    <string>upload</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>uploadSymbols</key>
    <true/>
    <key>manageAppVersionAndBuildNumber</key>
    <true/>
</dict>
</plist>
PLIST
    ok "Export options written"

    step "Exporting + uploading IPA..."
    rm -rf "$EXPORT_DIR"
    mkdir -p "$EXPORT_DIR"

    xcodebuild -exportArchive \
        -archivePath "$ARCHIVE_PATH" \
        -exportPath "$EXPORT_DIR" \
        -exportOptionsPlist /tmp/FlatlineExportOptions.plist \
        -allowProvisioningUpdates \
        2>&1 | tail -20

    ok "Upload handled by exportArchive (destination=upload). Check App Store Connect."
}

# ── Entrypoint ───────────────────────────────────────────────────

ACTION="${1:-help}"

case "$ACTION" in
    device)     cmd_device ;;
    archive)    cmd_archive ;;
    testflight) cmd_testflight ;;
    *)
        echo "Flatline Deploy Script"
        echo ""
        echo "Usage: ./deploy.sh <command>"
        echo ""
        echo "Commands:"
        echo "  device      Build & install to connected iPhone"
        echo "  archive     Create .xcarchive only"
        echo "  testflight  Archive → Export → Upload to TestFlight"
        ;;
esac
