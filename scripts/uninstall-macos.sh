#!/bin/bash
set -euo pipefail

readonly APP_NAME="iosClaw"
readonly LEGACY_APP_NAME="iosClawMac"
readonly BUNDLE_ID="com.iosclaw.mac"
readonly TARGET_APP="/Applications/${APP_NAME}.app"

usage() {
  cat <<'EOF'
Usage: scripts/uninstall-macos.sh

Moves /Applications/iosClaw.app and any legacy iosClawMac.app to the current
user's Trash, then
permanently removes iosClaw-owned Mac data, Keychain encryption keys, and this
app's macOS privacy permissions. It never removes developer certificates or
private signing keys.
EOF
}

case "${1:-}" in
  "") ;;
  --help|-h) usage; exit 0 ;;
  *) usage >&2; exit 64 ;;
esac

/usr/bin/pkill -x "$APP_NAME" 2>/dev/null || true
/usr/bin/pkill -x "$LEGACY_APP_NAME" 2>/dev/null || true

trash_dir="$HOME/.Trash"
mkdir -p "$trash_dir"
timestamp="$(date +%Y%m%d-%H%M%S)"
app_was_removed=false

move_app_to_trash() {
  local installed_app="$1"
  local installed_name="$2"
  [[ -e "$installed_app" ]] || return 0
  local trash_app="$trash_dir/${installed_name}-${timestamp}.app"
  if [[ -w /Applications ]]; then
    mv "$installed_app" "$trash_app"
  else
    sudo mv "$installed_app" "$trash_app"
  fi
  echo "Moved app to Trash: $trash_app"
  app_was_removed=true
}

move_app_to_trash "$TARGET_APP" "$APP_NAME"
move_app_to_trash "/Applications/${LEGACY_APP_NAME}.app" "$LEGACY_APP_NAME"

data_paths=(
  "$HOME/Library/Application Support/iosClaw"
  "$HOME/Library/Caches/$BUNDLE_ID"
  "$HOME/Library/Logs/iosClaw"
  "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
  "$HOME/.iosclaw"
)

for path in "${data_paths[@]}"; do
  [[ -e "$path" ]] || continue
  rm -rf "$path"
done

/usr/bin/defaults delete "$BUNDLE_ID" 2>/dev/null || true
/usr/bin/security delete-generic-password -s "$BUNDLE_ID" 2>/dev/null || true
/usr/bin/tccutil reset All "$BUNDLE_ID" 2>/dev/null || true

if [[ "$app_was_removed" == false ]]; then
  echo "The app was not installed; cleared its remaining local state."
fi
echo "Removed all iosClaw-owned local data, Keychain keys, and privacy permissions."
