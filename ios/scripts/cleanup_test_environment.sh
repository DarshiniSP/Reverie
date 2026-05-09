#!/bin/bash

###############################################################################
# Cleanup Script for iAlly Testing
# 
# Cleans up Xcode build artifacts, simulators, and caches
# Run before testing to ensure clean state
#
# Usage: bash scripts/cleanup_test_environment.sh
###############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

print_header "🧹 iAlly Test Environment Cleanup"

# 1. Kill all simulators
print_info "Killing all simulator instances..."
pkill -9 Simulator 2>/dev/null || true
xcrun simctl shutdown all 2>/dev/null || true
print_success "All simulators killed"

# 2. Clean Xcode build folder
print_info "Cleaning Xcode build folder..."
if xcodebuild clean -workspace iAlly.xcworkspace -scheme iAlly > /dev/null 2>&1; then
    print_success "Build folder cleaned"
else
    print_error "Failed to clean build folder"
fi

# 3. Delete derived data
print_info "Deleting derived data..."
DERIVED_DATA_PATH=$(xcodebuild -workspace iAlly.xcworkspace -scheme iAlly -showBuildSettings 2>/dev/null | grep -m 1 "BUILD_DIR" | sed 's/[ ]*BUILD_DIR = //g' | sed 's/\/Build\/Products//g' || echo "$HOME/Library/Developer/Xcode/DerivedData")

if [ -d "$DERIVED_DATA_PATH" ]; then
    # Find iAlly derived data
    IALLY_DERIVED=$(find "$HOME/Library/Developer/Xcode/DerivedData" -maxdepth 1 -name "iAlly-*" -type d 2>/dev/null)
    if [ -n "$IALLY_DERIVED" ]; then
        rm -rf "$IALLY_DERIVED"
        print_success "Derived data deleted: $(basename "$IALLY_DERIVED")"
    else
        print_info "No iAlly derived data found"
    fi
else
    print_info "Derived data path not found"
fi

# 4. Clear module cache
print_info "Clearing module cache..."
rm -rf ~/Library/Developer/Xcode/DerivedData/ModuleCache.noindex 2>/dev/null || true
rm -rf ~/Library/Caches/com.apple.dt.Xcode 2>/dev/null || true
print_success "Module cache cleared"

# 5. Reset simulator content and settings
print_info "Resetting test simulator..."
# Boot the simulator we'll use for testing
SIMULATOR_ID=$(xcrun simctl list devices available | grep "iPhone 17 Pro" | grep -v "Max" | head -1 | sed 's/.*(\([-A-F0-9]*\)).*/\1/')

if [ -n "$SIMULATOR_ID" ]; then
    xcrun simctl shutdown "$SIMULATOR_ID" 2>/dev/null || true
    xcrun simctl erase "$SIMULATOR_ID" 2>/dev/null || true
    print_success "Simulator reset: iPhone 17 Pro"
else
    print_info "Simulator not found, will be booted on demand"
fi

# 6. Clear test results
print_info "Clearing previous test results..."
rm -rf TestResults 2>/dev/null || true
rm -rf Coverage 2>/dev/null || true
mkdir -p TestResults Coverage
print_success "Test results cleared"

# 7. Clear SPM cache
print_info "Clearing Swift Package Manager cache..."
rm -rf ~/Library/Caches/org.swift.swiftpm 2>/dev/null || true
print_success "SPM cache cleared"

# 8. Clean build artifacts
print_info "Removing build artifacts..."
rm -rf build 2>/dev/null || true
rm -rf .build 2>/dev/null || true
print_success "Build artifacts removed"

print_header "✨ Cleanup Complete"
echo ""
print_success "Environment is clean and ready for testing!"
echo ""
print_info "You can now run:"
echo "  • bash scripts/pre_testflight_check.sh"
echo "  • bash scripts/quick_test.sh"
echo "  • Or build/test in Xcode"
echo ""
