#!/bin/bash

###############################################################################
# Quick Test Runner
# 
# Fast test execution for development
# Usage: bash scripts/quick_test.sh [unit|ui|e2e|all]
###############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
SCHEME="iAlly"
WORKSPACE="iAlly.xcworkspace"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

run_unit_tests() {
    print_info "Running unit tests (72 tests, ~3-5 min)..."
    
    if xcodebuild test \
                   -workspace "$WORKSPACE" \
                   -scheme "$SCHEME" \
                   -destination "$DESTINATION" \
                   -only-testing:iAllyTests \
                   2>&1 | tee unit_test.log | grep -E "(Test Suite|Test Case|passed|failed)"; then
        print_success "Unit tests passed!"
        return 0
    else
        print_error "Unit tests failed!"
        echo "See unit_test.log for details"
        return 1
    fi
}

run_ui_tests() {
    print_info "Running UI tests (27 tests, ~8-10 min)..."
    
    if xcodebuild test \
                   -workspace "$WORKSPACE" \
                   -scheme "$SCHEME" \
                   -destination "$DESTINATION" \
                   -only-testing:iAllyUITests \
                   2>&1 | tee ui_test.log | grep -E "(Test Suite|Test Case|passed|failed)"; then
        print_success "UI tests passed!"
        return 0
    else
        print_error "UI tests failed!"
        echo "See ui_test.log for details"
        return 1
    fi
}

run_e2e_tests() {
    print_info "Running E2E tests (9 tests, ~5-7 min)..."
    
    if xcodebuild test \
                   -workspace "$WORKSPACE" \
                   -scheme "$SCHEME" \
                   -destination "$DESTINATION" \
                   -only-testing:iAllyUITests/EndToEndTestSuite \
                   2>&1 | tee e2e_test.log | grep -E "(Test Suite|Test Case|passed|failed)"; then
        print_success "E2E tests passed!"
        return 0
    else
        print_error "E2E tests failed!"
        echo "See e2e_test.log for details"
        return 1
    fi
}

run_all_tests() {
    print_info "Running all tests (108+ tests, ~15-20 min)..."
    
    local failed=0
    
    run_unit_tests || failed=1
    run_ui_tests || failed=1
    run_e2e_tests || failed=1
    
    if [ $failed -eq 0 ]; then
        print_success "All tests passed! 🎉"
        return 0
    else
        print_error "Some tests failed"
        return 1
    fi
}

show_usage() {
    echo "Usage: bash scripts/quick_test.sh [unit|ui|e2e|all]"
    echo ""
    echo "Options:"
    echo "  unit  - Run unit tests only (~3-5 min, 72 tests)"
    echo "  ui    - Run UI tests only (~8-10 min, 27 tests)"
    echo "  e2e   - Run E2E tests only (~5-7 min, 9 tests)"
    echo "  all   - Run all tests (~15-20 min, 108+ tests)"
    echo ""
    echo "Examples:"
    echo "  bash scripts/quick_test.sh unit"
    echo "  bash scripts/quick_test.sh e2e"
    echo "  bash scripts/quick_test.sh all"
}

main() {
    local test_type="${1:-all}"
    
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  🧪 iAlly Quick Test Runner${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
    
    case "$test_type" in
        unit)
            run_unit_tests
            ;;
        ui)
            run_ui_tests
            ;;
        e2e)
            run_e2e_tests
            ;;
        all)
            run_all_tests
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            print_error "Unknown test type: $test_type"
            echo ""
            show_usage
            exit 1
            ;;
    esac
}

main "$@"
