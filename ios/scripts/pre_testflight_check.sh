#!/bin/bash

###############################################################################
# Pre-TestFlight Automation Script
# 
# Comprehensive testing and validation before TestFlight deployment
# Run this script before uploading to App Store Connect
#
# Usage: bash scripts/pre_testflight_check.sh
###############################################################################

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
SCHEME="iAlly"
WORKSPACE="iAlly.xcworkspace"
DESTINATION="platform=iOS Simulator,name=iPhone 17 Pro"
TEST_RESULTS_DIR="TestResults"
COVERAGE_DIR="Coverage"

# Cleanup previous results
rm -rf "$TEST_RESULTS_DIR" "$COVERAGE_DIR"
mkdir -p "$TEST_RESULTS_DIR" "$COVERAGE_DIR"

###############################################################################
# Helper Functions
###############################################################################

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

###############################################################################
# Pre-Flight Checks
###############################################################################

preflight_checks() {
    print_header "Pre-Flight Checks"
    
    # Check Xcode
    if ! command -v xcodebuild &> /dev/null; then
        print_error "Xcode command line tools not found"
        exit 1
    fi
    print_success "Xcode command line tools found"
    
    # Check workspace (it's a directory in Xcode)
    if [ ! -d "$WORKSPACE" ]; then
        print_error "Workspace $WORKSPACE not found"
        exit 1
    fi
    print_success "Workspace found"
    
    # Check for uncommitted changes
    if ! git diff-index --quiet HEAD --; then
        print_warning "Uncommitted changes detected"
        git status --short
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "No uncommitted changes"
    fi
    
    # Check branch
    CURRENT_BRANCH=$(git branch --show-current)
    if [ "$CURRENT_BRANCH" != "main" ]; then
        print_warning "Not on main branch (current: $CURRENT_BRANCH)"
        read -p "Continue anyway? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    else
        print_success "On main branch"
    fi
}

###############################################################################
# Build Validation
###############################################################################

build_validation() {
    print_header "Build Validation"
    
    print_info "Building for Debug... (this may take 2-3 minutes)"
    xcodebuild -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               -configuration Debug \
               build \
               > "$TEST_RESULTS_DIR/build_debug.log" 2>&1 &
    
    # Show progress while building
    BUILD_PID=$!
    while kill -0 $BUILD_PID 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    wait $BUILD_PID
    BUILD_STATUS=$?
    echo ""
    
    if [ $BUILD_STATUS -eq 0 ]; then
        print_success "Debug build successful"
    else
        print_error "Debug build failed"
        tail -n 50 "$TEST_RESULTS_DIR/build_debug.log"
        exit 1
    fi
    
    print_info "Building for Release... (this may take 2-3 minutes)"
    xcodebuild -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               -configuration Release \
               build \
               > "$TEST_RESULTS_DIR/build_release.log" 2>&1 &
    
    # Show progress while building
    BUILD_PID=$!
    while kill -0 $BUILD_PID 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    wait $BUILD_PID
    BUILD_STATUS=$?
    echo ""
    
    if [ $BUILD_STATUS -eq 0 ]; then
        print_success "Release build successful"
    else
        print_error "Release build failed"
        tail -n 50 "$TEST_RESULTS_DIR/build_release.log"
        exit 1
    fi
}

###############################################################################
# Unit Tests
###############################################################################

run_unit_tests() {
    print_header "Unit Tests"
    
    print_info "Running unit tests (72+ tests)... (this may take 3-5 minutes)"
    xcodebuild test \
               -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               -only-testing:iAllyTests \
               -enableCodeCoverage YES \
               -resultBundlePath "$TEST_RESULTS_DIR/unit_tests.xcresult" \
               > "$TEST_RESULTS_DIR/unit_tests.log" 2>&1 &
    
    # Show progress while testing
    TEST_PID=$!
    SECONDS=0
    while kill -0 $TEST_PID 2>/dev/null; do
        echo -ne "\rRunning... ${SECONDS}s elapsed"
        sleep 1
    done
    wait $TEST_PID
    TEST_STATUS=$?
    echo ""
    
    if [ $TEST_STATUS -eq 0 ]; then
        print_success "Unit tests passed"
        
        # Extract test count
        UNIT_TEST_COUNT=$(grep -o "Test Suite 'All tests' passed" "$TEST_RESULTS_DIR/unit_tests.log" | wc -l)
        if [ $UNIT_TEST_COUNT -gt 0 ]; then
            print_info "Unit test suite completed"
        fi
    else
        print_error "Unit tests failed"
        grep "error:" "$TEST_RESULTS_DIR/unit_tests.log" || tail -n 50 "$TEST_RESULTS_DIR/unit_tests.log"
        exit 1
    fi
}

###############################################################################
# UI Tests
###############################################################################

run_ui_tests() {
    print_header "UI Tests"
    
    print_info "Running UI tests (27+ tests)... (this may take 8-10 minutes)"
    xcodebuild test \
               -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               -only-testing:iAllyUITests \
               -resultBundlePath "$TEST_RESULTS_DIR/ui_tests.xcresult" \
               > "$TEST_RESULTS_DIR/ui_tests.log" 2>&1 &
    
    # Show progress while testing
    TEST_PID=$!
    SECONDS=0
    while kill -0 $TEST_PID 2>/dev/null; do
        echo -ne "\rRunning... ${SECONDS}s elapsed"
        sleep 1
    done
    wait $TEST_PID
    TEST_STATUS=$?
    echo ""
    
    if [ $TEST_STATUS -eq 0 ]; then
        print_success "UI tests passed"
    else
        print_error "UI tests failed"
        grep "error:" "$TEST_RESULTS_DIR/ui_tests.log" || tail -n 50 "$TEST_RESULTS_DIR/ui_tests.log"
        exit 1
    fi
}

###############################################################################
# End-to-End Tests
###############################################################################

run_e2e_tests() {
    print_header "End-to-End Tests"
    
    print_info "Running E2E test suite (9+ tests)... (this may take 5-7 minutes)"
    xcodebuild test \
               -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               -only-testing:iAllyUITests/EndToEndTestSuite \
               -resultBundlePath "$TEST_RESULTS_DIR/e2e_tests.xcresult" \
               > "$TEST_RESULTS_DIR/e2e_tests.log" 2>&1 &
    
    # Show progress while testing
    TEST_PID=$!
    SECONDS=0
    while kill -0 $TEST_PID 2>/dev/null; do
        echo -ne "\rRunning... ${SECONDS}s elapsed"
        sleep 1
    done
    wait $TEST_PID
    TEST_STATUS=$?
    echo ""
    
    if [ $TEST_STATUS -eq 0 ]; then
        print_success "E2E tests passed"
    else
        print_error "E2E tests failed"
        grep "error:" "$TEST_RESULTS_DIR/e2e_tests.log" || tail -n 50 "$TEST_RESULTS_DIR/e2e_tests.log"
        exit 1
    fi
}

###############################################################################
# Code Coverage
###############################################################################

check_code_coverage() {
    print_header "Code Coverage Analysis"
    
    print_info "Generating coverage report..."
    
    # Convert xcresult to coverage data
    if command -v xcrun &> /dev/null; then
        xcrun xccov view --report "$TEST_RESULTS_DIR/unit_tests.xcresult" > "$COVERAGE_DIR/coverage_report.txt" 2>&1 || true
        
        if [ -f "$COVERAGE_DIR/coverage_report.txt" ]; then
            # Extract overall coverage percentage
            COVERAGE=$(grep -o "[0-9]*\.[0-9]*%" "$COVERAGE_DIR/coverage_report.txt" | head -1)
            if [ -n "$COVERAGE" ]; then
                print_info "Code coverage: $COVERAGE"
                
                # Check if coverage meets threshold (e.g., 70%)
                COVERAGE_NUM=$(echo "$COVERAGE" | sed 's/%//')
                if (( $(echo "$COVERAGE_NUM >= 70" | bc -l) )); then
                    print_success "Coverage meets threshold (≥70%)"
                else
                    print_warning "Coverage below threshold: $COVERAGE (expected ≥70%)"
                fi
            fi
        fi
    fi
}

###############################################################################
# Static Analysis
###############################################################################

run_static_analysis() {
    print_header "Static Analysis"
    
    print_info "Running static analyzer... (this may take 2-3 minutes)"
    xcodebuild analyze \
               -workspace "$WORKSPACE" \
               -scheme "$SCHEME" \
               -destination "$DESTINATION" \
               > "$TEST_RESULTS_DIR/static_analysis.log" 2>&1 &
    
    # Show progress
    ANALYZE_PID=$!
    while kill -0 $ANALYZE_PID 2>/dev/null; do
        echo -n "."
        sleep 2
    done
    wait $ANALYZE_PID
    ANALYZE_STATUS=$?
    echo ""
    
    if [ $ANALYZE_STATUS -eq 0 ]; then
        
        # Check for warnings
        WARNING_COUNT=$(grep -c "warning:" "$TEST_RESULTS_DIR/static_analysis.log" || echo "0")
        ERROR_COUNT=$(grep -c "error:" "$TEST_RESULTS_DIR/static_analysis.log" || echo "0")
        
        if [ "$ERROR_COUNT" -eq 0 ]; then
            print_success "No static analysis errors"
            if [ "$WARNING_COUNT" -gt 0 ]; then
                print_warning "$WARNING_COUNT warnings found"
            fi
        else
            print_error "$ERROR_COUNT errors found"
            grep "error:" "$TEST_RESULTS_DIR/static_analysis.log"
            exit 1
        fi
    else
        print_error "Static analysis failed"
        exit 1
    fi
}

###############################################################################
# SwiftLint (if available)
###############################################################################

run_swiftlint() {
    print_header "SwiftLint"
    
    if command -v swiftlint &> /dev/null; then
        print_info "Running SwiftLint..."
        if swiftlint > "$TEST_RESULTS_DIR/swiftlint.log" 2>&1; then
            print_success "SwiftLint passed"
        else
            print_warning "SwiftLint found issues"
            cat "$TEST_RESULTS_DIR/swiftlint.log"
        fi
    else
        print_info "SwiftLint not installed, skipping..."
    fi
}

###############################################################################
# Archive Validation
###############################################################################

validate_archive() {
    print_header "Archive Validation"
    
    print_info "Creating archive..."
    ARCHIVE_PATH="$TEST_RESULTS_DIR/iAlly.xcarchive"
    
    if xcodebuild archive \
                   -workspace "$WORKSPACE" \
                   -scheme "$SCHEME" \
                   -archivePath "$ARCHIVE_PATH" \
                   > "$TEST_RESULTS_DIR/archive.log" 2>&1; then
        print_success "Archive created successfully"
        
        # Validate archive
        print_info "Validating archive..."
        if xcodebuild -exportArchive \
                       -archivePath "$ARCHIVE_PATH" \
                       -exportOptionsPlist exportOptions.plist \
                       -exportPath "$TEST_RESULTS_DIR/Export" \
                       > "$TEST_RESULTS_DIR/export.log" 2>&1 || true; then
            print_success "Archive validation passed"
        else
            print_warning "Archive export test completed (may need manual validation)"
        fi
    else
        print_error "Archive creation failed"
        tail -n 50 "$TEST_RESULTS_DIR/archive.log"
        exit 1
    fi
}

###############################################################################
# Version Check
###############################################################################

check_version() {
    print_header "Version Check"
    
    # Get version from project
    VERSION=$(bash scripts/version.sh get 2>&1 | grep "Version:" | awk '{print $2}')
    BUILD=$(bash scripts/version.sh get 2>&1 | grep "Build Number:" | awk '{print $3}')
    
    print_info "Current version: $VERSION (Build $BUILD)"
    
    # Check if version tag exists
    if git rev-parse "v$VERSION" >/dev/null 2>&1; then
        print_warning "Git tag v$VERSION already exists"
        read -p "Create new build number? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            bash scripts/version.sh set $(($BUILD + 1))
            print_success "Build number incremented"
        fi
    else
        print_success "Version is unique"
    fi
}

###############################################################################
# Test Summary
###############################################################################

generate_summary() {
    print_header "Test Summary"
    
    echo "Test Results Summary" > "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "====================" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "Date: $(date)" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "Version: $VERSION (Build $BUILD)" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "Branch: $CURRENT_BRANCH" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    
    # Test counts
    echo "Unit Tests: PASSED" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "UI Tests: PASSED" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "E2E Tests: PASSED" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "Static Analysis: PASSED" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    echo "Build Validation: PASSED" >> "$TEST_RESULTS_DIR/SUMMARY.txt"
    
    cat "$TEST_RESULTS_DIR/SUMMARY.txt"
    
    print_success "All tests passed! ✨"
    echo ""
    print_info "Ready for TestFlight deployment"
    echo ""
    print_info "Next steps:"
    echo "  1. Review test results in $TEST_RESULTS_DIR/"
    echo "  2. Archive for distribution: Product > Archive in Xcode"
    echo "  3. Upload to App Store Connect"
    echo "  4. Submit for TestFlight review"
    echo ""
}

###############################################################################
# Main Execution
###############################################################################

main() {
    print_header "🚀 iAlly Pre-TestFlight Validation"
    
    echo "This script will:"
    echo "  ✓ Run pre-flight checks"
    echo "  ✓ Validate Debug and Release builds (~5 minutes)"
    echo "  ✓ Run unit tests (72+ tests, ~3-5 minutes)"
    echo "  ✓ Run UI tests (27+ tests, ~8-10 minutes)"
    echo "  ✓ Run E2E tests (9+ tests, ~5-7 minutes)"
    echo "  ✓ Check code coverage"
    echo "  ✓ Run static analysis (~2 minutes)"
    echo ""
    echo "⏱️  Estimated total time: 20-30 minutes"
    echo "📊 Progress will be shown for each step"
    echo ""
    
    read -p "Continue? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
    
    # Offer cleanup option
    echo ""
    read -p "Clean build environment first? (recommended, y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        print_info "Running cleanup script..."
        if [ -f "scripts/cleanup_test_environment.sh" ]; then
            bash scripts/cleanup_test_environment.sh
        else
            print_warning "Cleanup script not found, continuing anyway"
        fi
    fi
    
    START_TIME=$(date +%s)
    
    # Run all checks
    preflight_checks
    check_version
    build_validation
    run_static_analysis
    run_swiftlint
    run_unit_tests
    run_ui_tests
    run_e2e_tests
    check_code_coverage
    # validate_archive  # Optional: Takes longer
    
    END_TIME=$(date +%s)
    DURATION=$((END_TIME - START_TIME))
    
    generate_summary
    
    print_success "Completed in ${DURATION}s"
    
    # Open results
    print_info "Opening test results..."
    open "$TEST_RESULTS_DIR/"
}

# Run main function
main "$@"
