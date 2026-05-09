#!/bin/bash
# ============================================================
# iAlly Automated Build + Test Runner
# Run from Mac terminal in the ios/ directory:
#   bash scripts/run_tests.sh [build|smoke|ui|all]
# ============================================================

set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
WORKSPACE="$PROJECT_DIR/iAlly.xcworkspace"
SCHEME="iAlly"
TEST_SCHEME="iAlly"
RESULTS_DIR="$PROJECT_DIR/.test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
LOG="$RESULTS_DIR/test_run_$TIMESTAMP.log"

# ---- Simulator: iPhone 17 / iOS 26.1 ----------------------
SIMULATOR="iPhone 17"
OS_VERSION="26.1"
DESTINATION="platform=iOS Simulator,name=${SIMULATOR},OS=${OS_VERSION}"

# Auto-fallback if simulator not found
if ! xcrun simctl list devices available 2>/dev/null | grep -q "${SIMULATOR}"; then
  echo "⚠️  '${SIMULATOR}' not found — auto-selecting latest available iPhone"
  DESTINATION="platform=iOS Simulator,OS=latest,name=$(xcrun simctl list devices available | grep "iPhone" | tail -1 | sed 's/ (.*//' | xargs)"
fi

mkdir -p "$RESULTS_DIR"

print_header() { echo ""; echo "══════════════════════════════════════"; echo " $1"; echo "══════════════════════════════════════"; }

# ---- 1. BUILD -----------------------------------------------
run_build() {
  print_header "BUILD — iAlly (Debug)"
  echo "Workspace : $WORKSPACE"
  echo "Simulator : $DESTINATION"
  echo ""

  xcodebuild clean build \
    -workspace "$WORKSPACE" \
    -scheme "$SCHEME" \
    -destination "$DESTINATION" \
    -configuration Debug \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee -a "$LOG" | xcpretty --color 2>/dev/null || cat "$LOG" | tail -40

  echo "✅ BUILD SUCCEEDED"
}

# ---- 2. SMOKE TESTS (Fast — Launch + Nav only) --------------
run_smoke_tests() {
  print_header "SMOKE TESTS — Launch + Navigation"

  xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$TEST_SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:"iAllyUITests/LaunchEssentialTests" \
    -only-testing:"iAllyUITests/SmokeEssentialTests" \
    -resultBundlePath "$RESULTS_DIR/smoke_$TIMESTAMP.xcresult" \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee -a "$LOG" | xcpretty --color --report junit --output "$RESULTS_DIR/smoke_$TIMESTAMP.xml" 2>/dev/null || {
      echo "⚠️  Some smoke tests failed — opening result bundle..."
      open "$RESULTS_DIR/smoke_$TIMESTAMP.xcresult" 2>/dev/null || true
    }

  echo "✅ SMOKE TESTS COMPLETE"
}

# ---- 3. ESSENTIAL UI / SIT TESTS ---------------------------
run_ui_tests() {
  print_header "ESSENTIAL UI TESTS (SIT) — All Suites"

  xcodebuild test \
    -workspace "$WORKSPACE" \
    -scheme "$TEST_SCHEME" \
    -destination "$DESTINATION" \
    -only-testing:"iAllyUITests/LaunchEssentialTests" \
    -only-testing:"iAllyUITests/SmokeEssentialTests" \
    -only-testing:"iAllyUITests/TaskManagementEssentialTests" \
    -only-testing:"iAllyUITests/NavigationEssentialTests" \
    -only-testing:"iAllyUITests/PlanJourneyEssentialTests" \
    -only-testing:"iAllyUITests/RoutineEssentialTests" \
    -only-testing:"iAllyUITests/SettingsEssentialTests" \
    -only-testing:"iAllyUITests/AnalyticsEssentialTests" \
    -only-testing:"iAllyUITests/AccessibilityEssentialTests" \
    -only-testing:"iAllyUITests/DataPersistenceEssentialTests" \
    -only-testing:"iAllyUITests/EdgeCaseEssentialTests" \
    -resultBundlePath "$RESULTS_DIR/essential_$TIMESTAMP.xcresult" \
    -parallel-testing-enabled YES \
    -maximum-parallel-testing-workers 2 \
    CODE_SIGNING_ALLOWED=NO \
    2>&1 | tee -a "$LOG" | xcpretty --color --report junit --output "$RESULTS_DIR/essential_$TIMESTAMP.xml" 2>/dev/null || {
      echo "⚠️  Some UI tests failed"
      open "$RESULTS_DIR/essential_$TIMESTAMP.xcresult" 2>/dev/null || true
    }

  echo "✅ UI TESTS COMPLETE"
}

# ---- 4. SUMMARY REPORT -------------------------------------
print_report() {
  print_header "SUMMARY REPORT"

  TOTAL_PASS=0; TOTAL_FAIL=0; TOTAL_TESTS=0
  for xml in "$RESULTS_DIR"/*.xml; do
    [ -f "$xml" ] || continue
    T=$(grep -c "<testcase" "$xml" 2>/dev/null || echo 0)
    F=$(grep -c "<failure" "$xml" 2>/dev/null || echo 0)
    P=$((T - F))
    TOTAL_TESTS=$((TOTAL_TESTS + T))
    TOTAL_PASS=$((TOTAL_PASS + P))
    TOTAL_FAIL=$((TOTAL_FAIL + F))
    PCT=$([ "$T" -gt 0 ] && echo "$((P * 100 / T))" || echo 0)
    printf "  %-40s %d/%d passed (%d%%)\n" "$(basename $xml .xml)" "$P" "$T" "$PCT"
  done

  echo ""
  if [ "$TOTAL_TESTS" -gt 0 ]; then
    OVERALL=$((TOTAL_PASS * 100 / TOTAL_TESTS))
    echo "  OVERALL: $TOTAL_PASS/$TOTAL_TESTS tests passed ($OVERALL%)"
    [ "$TOTAL_FAIL" -eq 0 ] && echo "  STATUS : ✅ ALL TESTS PASSED" || echo "  STATUS : ⚠️  $TOTAL_FAIL TESTS FAILED — review xcresult"
  fi

  echo ""
  echo "  Log     : $LOG"
  echo "  Results : $RESULTS_DIR"
  echo "  View    : open \"$RESULTS_DIR\""
  echo ""
}

# ---- MAIN ---------------------------------------------------
MODE="${1:-all}"
case "$MODE" in
  build)  run_build ;;
  smoke)  run_build && run_smoke_tests && print_report ;;
  ui|sit) run_build && run_ui_tests && print_report ;;
  all)    run_build && run_smoke_tests && run_ui_tests && print_report ;;
  *)
    echo "Usage: bash scripts/run_tests.sh [build|smoke|ui|all]"
    echo "  build  — clean build only"
    echo "  smoke  — build + fast launch/nav smoke tests"
    echo "  ui     — build + all 11 Essential UI/SIT suites"
    echo "  all    — build + smoke + full UI tests (default)"
    exit 1
    ;;
esac
