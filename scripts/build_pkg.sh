#!/bin/bash
#
# Builds build/NitroBrew-<version>.pkg from a Release build.
#
# Default: ad-hoc signed app, unsigned pkg (fine for your own Macs; Gatekeeper warns on a
# double-click install of a download).
#
# For distribution, set these and the pkg is signed and notarized:
#   APP_IDENTITY="Developer ID Application: Your Name (TEAMID)"
#   PKG_IDENTITY="Developer ID Installer: Your Name (TEAMID)"
#   NOTARY_PROFILE="notary"   # saved with: xcrun notarytool store-credentials
#
set -euo pipefail

cd "$(dirname "$0")/.."
BUILD=build
APP_NAME=NitroBrew
BUNDLE_ID=com.ir77io.nitrobrewtimer

rm -rf "$BUILD/pkgroot"
mkdir -p "$BUILD"
DERIVED=$(mktemp -d)
trap 'rm -rf "$DERIVED" "$BUILD/pkgroot"' EXIT

echo "==> Building Release app (universal)"
if [[ -n "${APP_IDENTITY:-}" ]]; then
    SIGN=(CODE_SIGN_IDENTITY="$APP_IDENTITY" CODE_SIGN_STYLE=Manual OTHER_CODE_SIGN_FLAGS="--timestamp" ENABLE_HARDENED_RUNTIME=YES)
else
    SIGN=(CODE_SIGN_IDENTITY="-" CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM="")
fi
xcodebuild -project "src/$APP_NAME.xcodeproj" -scheme "$APP_NAME" -configuration Release \
    -destination "generic/platform=macOS" ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
    -derivedDataPath "$DERIVED" "${SIGN[@]}" build | tail -3

APP="$DERIVED/Build/Products/Release/$APP_NAME.app"
[[ -d "$APP" ]] || { echo "App not found at $APP"; exit 1; }
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$APP/Contents/Info.plist")

echo "==> Verifying app signature"
codesign --verify --deep --strict "$APP"

echo "==> Building pkg (version $VERSION)"
mkdir -p "$BUILD/pkgroot"
cp -R "$APP" "$BUILD/pkgroot/"
PKG="$BUILD/$APP_NAME-$VERSION.pkg"
# Always install to /Applications instead of upgrading some other copy found by bundle ID.
pkgbuild --analyze --root "$BUILD/pkgroot" "$BUILD/component.plist" >/dev/null
plutil -replace 0.BundleIsRelocatable -bool NO "$BUILD/component.plist"
plutil -replace 0.BundleIsVersionChecked -bool NO "$BUILD/component.plist"
plutil -replace 0.BundleHasStrictIdentifier -bool NO "$BUILD/component.plist"
plutil -remove 0.BundleOverwriteAction "$BUILD/component.plist" 2>/dev/null || true

PKG_ARGS=(--root "$BUILD/pkgroot" --component-plist "$BUILD/component.plist" --install-location /Applications --identifier "$BUNDLE_ID" --version "$VERSION")
if [[ -n "${PKG_IDENTITY:-}" ]]; then
    PKG_ARGS+=(--sign "$PKG_IDENTITY")
fi
pkgbuild "${PKG_ARGS[@]}" "$PKG"

if [[ -n "${NOTARY_PROFILE:-}" ]]; then
    echo "==> Notarizing"
    xcrun notarytool submit "$PKG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$PKG"
fi

echo "==> Done: $PKG"
