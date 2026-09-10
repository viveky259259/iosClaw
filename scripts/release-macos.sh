#!/bin/bash
set -euo pipefail

readonly TARGET_NAME="iosClawMac"
readonly APP_NAME="iosClaw"
readonly BUNDLE_ID="com.iosclaw.mac"

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
project_path="$repo_root/iosClawMac/iosClawMac.xcodeproj"
derived_data_path="${IOSCLAW_DERIVED_DATA:-$repo_root/.build/DerivedData}"
release_root="${IOSCLAW_RELEASE_DIR:-$repo_root/.build/releases}"
team_id="${IOSCLAW_TEAM_ID:-}"
signing_identity="${IOSCLAW_SIGNING_IDENTITY:-}"
notary_profile="${IOSCLAW_NOTARY_PROFILE:-iosclaw-notary}"
prepare_only=false

usage() {
  cat <<'EOF'
Usage: scripts/release-macos.sh [options]

Builds, tests, archives, Developer ID-signs, packages, notarizes, staples, and
verifies a universal iosClaw DMG. Public artifacts are produced only after
Apple notarization succeeds.

Options:
  --notary-profile NAME  Keychain profile created with notarytool
  --prepare-only         Build a clearly marked unnotarized DMG for local QA
  --help, -h             Show this help

Environment overrides:
  IOSCLAW_TEAM_ID          Apple Developer Team ID used for signing
  IOSCLAW_SIGNING_IDENTITY  Developer ID Application certificate SHA-1
  IOSCLAW_NOTARY_PROFILE    notarytool Keychain profile
  IOSCLAW_RELEASE_DIR       artifact output directory
  IOSCLAW_DERIVED_DATA      Xcode DerivedData directory
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --notary-profile)
      [[ $# -ge 2 ]] || { echo "--notary-profile requires a value" >&2; exit 64; }
      notary_profile="$2"
      shift
      ;;
    --prepare-only) prepare_only=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
  shift
done

[[ -d "$project_path" ]] || { echo "Project not found: $project_path" >&2; exit 66; }
[[ -n "$team_id" ]] || {
  echo "Set IOSCLAW_TEAM_ID to the Apple Developer Team ID before releasing." >&2
  exit 69
}
available_identities="$(security find-identity -v -p codesigning)"
if [[ -z "$signing_identity" ]]; then
  signing_identity="$(awk -F '"' '/Developer ID Application/ { print $2; exit }' <<<"$available_identities")"
fi
[[ -n "$signing_identity" ]] || {
  echo "Set IOSCLAW_SIGNING_IDENTITY or install a Developer ID Application certificate." >&2
  exit 69
}
grep -Fq "$signing_identity" <<<"$available_identities" || {
  echo "Developer ID signing identity is unavailable: $signing_identity" >&2
  exit 69
}

if [[ "$prepare_only" == false ]]; then
  xcrun notarytool history --keychain-profile "$notary_profile" >/dev/null 2>&1 || {
    echo "Notarization profile '$notary_profile' is not configured." >&2
    echo "Create it with: xcrun notarytool store-credentials $notary_profile" >&2
    exit 69
  }
fi

release_build_settings="$(xcodebuild \
  -project "$project_path" \
  -scheme "$TARGET_NAME" \
  -configuration Release \
  -showBuildSettings 2>/dev/null)"

build_setting() {
  local name="$1"
  awk -v setting="$name" '$1 == setting && $2 == "=" { print $3; exit }' \
    <<<"$release_build_settings"
}

version="$(build_setting MARKETING_VERSION)"
build_number="$(build_setting CURRENT_PROJECT_VERSION)"
[[ -n "$version" && -n "$build_number" ]] || {
  echo "Could not resolve release version metadata." >&2
  exit 65
}

run_id="$(date +%Y%m%d-%H%M%S)"
run_dir="$release_root/${version}-${build_number}-$run_id"
archive_path="$run_dir/iosClaw.xcarchive"
package_dir="$run_dir/package"
mkdir -p "$run_dir" "$package_dir" "$derived_data_path"

run_xcodebuild() {
  xcodebuild \
    -project "$project_path" \
    -scheme "$TARGET_NAME" \
    -derivedDataPath "$derived_data_path" \
    "$@"
}

echo "[1/6] Running safety tests..."
run_xcodebuild \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  CODE_SIGNING_ALLOWED=NO \
  test | tee "$run_dir/test.log"

echo "[2/6] Creating universal Developer ID archive..."
run_xcodebuild \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$archive_path" \
  "DEVELOPMENT_TEAM=$team_id" \
  CODE_SIGN_STYLE=Manual \
  "CODE_SIGN_IDENTITY=$signing_identity" \
  ENABLE_HARDENED_RUNTIME=YES \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  'ARCHS=arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  archive | tee "$run_dir/archive.log"

archived_app="$archive_path/Products/Applications/${APP_NAME}.app"
[[ -d "$archived_app" ]] || { echo "Archive does not contain $archived_app" >&2; exit 1; }

echo "[3/6] Verifying app identity and hardened signature..."
actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$archived_app/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$BUNDLE_ID" ]] || {
  echo "Unexpected bundle identifier: $actual_bundle_id" >&2
  exit 1
}
codesign --verify --deep --strict --verbose=2 "$archived_app"
signature_details="$(codesign -dv --verbose=4 "$archived_app" 2>&1)"
grep -Fq 'Authority=Developer ID Application:' <<<"$signature_details" || {
  echo "Archive is not signed with Developer ID Application." >&2
  exit 1
}
grep -Fq 'Runtime Version=' <<<"$signature_details" || {
  echo "Archive is missing hardened runtime." >&2
  exit 1
}
grep -Fq 'Timestamp=' <<<"$signature_details" || {
  echo "Archive is missing a secure signing timestamp." >&2
  exit 1
}

architectures="$(lipo -archs "$archived_app/Contents/MacOS/$APP_NAME")"
[[ "$architectures" == *arm64* && "$architectures" == *x86_64* ]] || {
  echo "Archive is not universal: $architectures" >&2
  exit 1
}

[[ -f "$archived_app/Contents/Resources/AppIcon.icns" ]] || {
  echo "Archive is missing AppIcon.icns" >&2
  exit 1
}
[[ -f "$archived_app/Contents/Resources/PrivacyInfo.xcprivacy" ]] || {
  echo "Archive is missing PrivacyInfo.xcprivacy" >&2
  exit 1
}

echo "[4/6] Packaging signed DMG..."
ditto "$archived_app" "$package_dir/${APP_NAME}.app"
ln -s /Applications "$package_dir/Applications"

if [[ "$prepare_only" == true ]]; then
  dmg_path="$run_dir/${APP_NAME}-${version}-${build_number}-UNNOTARIZED.dmg"
else
  dmg_path="$run_dir/${APP_NAME}-${version}-${build_number}.dmg"
fi

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$package_dir" \
  -format UDZO \
  -ov \
  "$dmg_path" | tee "$run_dir/dmg.log"
codesign --force --timestamp --sign "$signing_identity" "$dmg_path"
codesign --verify --verbose=2 "$dmg_path"
hdiutil verify "$dmg_path"

if [[ "$prepare_only" == false ]]; then
  echo "[5/6] Submitting to Apple notarization..."
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$notary_profile" \
    --wait \
    --output-format json | tee "$run_dir/notarization.json"

  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
else
  echo "[5/6] Skipping notarization for local package validation."
fi

echo "[6/6] Writing checksum..."
shasum -a 256 "$dmg_path" > "$dmg_path.sha256"

if [[ "$prepare_only" == true ]]; then
  echo "Prepared local QA artifact: $dmg_path"
  echo "Do not distribute it; the filename and signature have not been notarized."
else
  echo "Release artifact ready: $dmg_path"
fi
