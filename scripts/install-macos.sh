#!/bin/bash
set -euo pipefail

readonly TARGET_NAME="iosClawMac"
readonly APP_NAME="iosClaw"
readonly LEGACY_APP_NAME="iosClawMac"
readonly BUNDLE_ID="com.iosclaw.mac"
readonly TARGET_APP="/Applications/${APP_NAME}.app"

usage() {
  cat <<'EOF'
Usage: scripts/install-macos.sh [--debug|--release]

Builds iosClaw, verifies its signature, and installs it at
/Applications/iosClaw.app. The default configuration is Release; use
--debug for a local contributor build. Release builds require your own
Developer ID signing setup.

If an existing iosClaw.app or legacy iosClawMac.app is installed, it is moved to
~/Library/Application Support/iosClaw/install-backups before replacement.

Release overrides:
  IOSCLAW_TEAM_ID          Apple Developer Team ID
  IOSCLAW_SIGNING_IDENTITY Developer ID Application identity (optional)
EOF
}

configuration="Release"
case "${1:-}" in
  "") ;;
  --debug) configuration="Debug" ;;
  --release) ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

script_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
project_path="$repo_root/iosClawMac/iosClawMac.xcodeproj"
derived_data_path="${IOSCLAW_DERIVED_DATA:-$repo_root/.build/DerivedData}"
built_app="$derived_data_path/Build/Products/$configuration/${APP_NAME}.app"
backup_dir="${IOSCLAW_BACKUP_DIR:-$HOME/Library/Application Support/iosClaw/install-backups}"
build_overrides=()

if [[ "$configuration" == "Release" ]]; then
  [[ -n "${IOSCLAW_TEAM_ID:-}" ]] || {
    echo "Release installs require IOSCLAW_TEAM_ID; use --debug for a local contributor build." >&2
    exit 69
  }
  build_overrides+=("DEVELOPMENT_TEAM=${IOSCLAW_TEAM_ID}")
  if [[ -n "${IOSCLAW_SIGNING_IDENTITY:-}" ]]; then
    build_overrides+=("CODE_SIGN_IDENTITY=${IOSCLAW_SIGNING_IDENTITY}")
  fi
fi

[[ -d "$project_path" ]] || { echo "Project not found: $project_path" >&2; exit 66; }

mkdir -p "$derived_data_path" "$backup_dir"

echo "Building ${configuration}..."
if ((${#build_overrides[@]})); then
  xcodebuild \
    -project "$project_path" \
    -scheme "$TARGET_NAME" \
    -configuration "$configuration" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived_data_path" \
    "${build_overrides[@]}" \
    build
else
  xcodebuild \
    -project "$project_path" \
    -scheme "$TARGET_NAME" \
    -configuration "$configuration" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$derived_data_path" \
    build
fi

[[ -d "$built_app" ]] || { echo "Build did not produce $built_app" >&2; exit 1; }

actual_bundle_id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$built_app/Contents/Info.plist")"
[[ "$actual_bundle_id" == "$BUNDLE_ID" ]] || {
  echo "Refusing to install unexpected bundle ID: $actual_bundle_id" >&2
  exit 1
}

codesign --verify --deep --strict "$built_app"

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/iosclaw-install.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
staged_app="$staging_dir/${APP_NAME}.app"
ditto "$built_app" "$staged_app"

run_as_admin() {
  if [[ -w /Applications ]]; then
    "$@"
  else
    sudo "$@"
  fi
}

if pgrep -x "$APP_NAME" >/dev/null 2>&1 || pgrep -x "$LEGACY_APP_NAME" >/dev/null 2>&1; then
  echo "Closing the running $APP_NAME before replacement..."
  pkill -TERM -x "$APP_NAME" 2>/dev/null || true
  pkill -TERM -x "$LEGACY_APP_NAME" 2>/dev/null || true
  for _ in {1..20}; do
    if ! pgrep -x "$APP_NAME" >/dev/null 2>&1 && ! pgrep -x "$LEGACY_APP_NAME" >/dev/null 2>&1; then
      break
    fi
    sleep 0.1
  done
  if pgrep -x "$APP_NAME" >/dev/null 2>&1 || pgrep -x "$LEGACY_APP_NAME" >/dev/null 2>&1; then
    echo "$APP_NAME is still running; close it and run the installer again." >&2
    exit 1
  fi
fi

backup_existing_app() {
  local existing_app="$1"
  local existing_name="$2"
  local timestamp
  local backup_app
  [[ -e "$existing_app" ]] || return 0
  timestamp="$(date +%Y%m%d-%H%M%S)"
  backup_app="$backup_dir/${existing_name}-${timestamp}.app"
  echo "Backing up the existing app to $backup_app"
  run_as_admin mv "$existing_app" "$backup_app"
}

backup_existing_app "$TARGET_APP" "$APP_NAME"
backup_existing_app "/Applications/${LEGACY_APP_NAME}.app" "$LEGACY_APP_NAME"

if ! run_as_admin ditto "$staged_app" "$TARGET_APP"; then
  echo "Installation failed. The previous app, if any, remains in $backup_dir." >&2
  exit 1
fi

codesign --verify --deep --strict "$TARGET_APP"
echo "Installed $TARGET_APP ($configuration)."
