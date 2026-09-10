#!/bin/bash
set -euo pipefail

readonly TARGET_NAME="iosClawMac"
readonly APP_NAME="iosClaw"
readonly SCRIPT_DIR="$(cd -- "$(dirname -- "$0")" && pwd)"
readonly REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"
readonly PROJECT_PATH="$REPO_ROOT/iosClawMac/iosClawMac.xcodeproj"
readonly SCHEME="$TARGET_NAME"
readonly DERIVED_DATA_PATH="${IOSCLAW_DERIVED_DATA:-$REPO_ROOT/.build/DerivedData}"
readonly ARTIFACT_ROOT="${IOSCLAW_UI_FEEDBACK_DIR:-$REPO_ROOT/.build/ui-feedback}"

configuration="Debug"
skip_build=false
skip_tests=false
skip_launch=false

usage() {
  cat <<'EOF'
Usage: scripts/ui-feedback-loop.sh [options]

Runs the iosClaw UI development loop: build, automated tests, and app launch.
The calling agent then performs an app-scoped visual review, so no unrelated
desktop content is captured or persisted.

Options:
  --release       Use the Release configuration (Debug is the default).
  --skip-build    Reuse an existing build.
  --skip-tests    Do not run the automated test suite.
  --skip-launch   Do not launch the app after a successful build.
  --help, -h      Show this help.

Build and test logs are written to .build/ui-feedback/. The visual-review step
is intentionally handled through iosClaw's application window, not a desktop
screenshot from the terminal.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release) configuration="Release" ;;
    --skip-build) skip_build=true ;;
    --skip-tests) skip_tests=true ;;
    --skip-launch) skip_launch=true ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 64 ;;
  esac
  shift
done

[[ -d "$PROJECT_PATH" ]] || { echo "Project not found: $PROJECT_PATH" >&2; exit 66; }
mkdir -p "$DERIVED_DATA_PATH" "$ARTIFACT_ROOT"

run_id="$(date +%Y%m%d-%H%M%S)"
run_dir="$ARTIFACT_ROOT/$run_id"
mkdir -p "$run_dir"

run_xcodebuild() {
  local requested_configuration="$1"
  shift
  xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -configuration "$requested_configuration" \
    -destination 'platform=macOS,arch=arm64' \
    -derivedDataPath "$DERIVED_DATA_PATH" \
    "$@"
}

if [[ "$skip_build" == false ]]; then
  echo "[1/4] Building ${APP_NAME} (${configuration})..."
  run_xcodebuild "$configuration" build | tee "$run_dir/build.log"
fi

if [[ "$skip_tests" == false ]]; then
  test_configuration="$configuration"
  if [[ "$configuration" == "Release" ]]; then
    # The production module intentionally omits -enable-testing. Exercise the
    # same sources through the Debug test host after validating Release above.
    test_configuration="Debug"
  fi
  echo "[2/4] Running automated tests (${test_configuration})…"
  run_xcodebuild "$test_configuration" test | tee "$run_dir/test.log"
fi

built_app="$DERIVED_DATA_PATH/Build/Products/$configuration/$APP_NAME.app"
if [[ "$skip_launch" == false ]]; then
  [[ -d "$built_app" ]] || {
    echo "Built app not found: $built_app. Remove --skip-build or build first." >&2
    exit 1
  }
  built_executable="$built_app/Contents/MacOS/$APP_NAME"
  running_pids="$(pgrep -f "$built_executable" || true)"
  if [[ -n "$running_pids" ]]; then
    echo "Stopping the previous workspace build..."
    while IFS= read -r pid; do
      kill -TERM "$pid" 2>/dev/null || true
    done <<< "$running_pids"
    for _ in {1..20}; do
      pgrep -f "$built_executable" >/dev/null 2>&1 || break
      sleep 0.1
    done
  fi
  echo "[3/4] Launching ${APP_NAME}..."
  open -n "$built_app"
fi

echo "[4/4] Ready for app-scoped visual review."

latest_link="$ARTIFACT_ROOT/latest"
rm -f "$latest_link"
ln -s "$run_id" "$latest_link"

echo "Build and test loop passed. Evidence: $run_dir"
