#!/bin/bash
# Version Management Script for iAlly
# Usage: ./scripts/version.sh [major|minor|patch|get|set BUILD_NUMBER]

set -euo pipefail

PROJECT_FILE="iAlly/iAlly.xcodeproj/project.pbxproj"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get current version
get_version() {
    /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" \
        "iAlly/iAlly/Info.plist" 2>/dev/null || echo "1.0.0"
}

# Get current build number
get_build_number() {
    grep -m 1 "CURRENT_PROJECT_VERSION = " "$PROJECT_FILE" | \
        sed 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/'
}

# Set version in project file
set_version() {
    local new_version="$1"
    log_info "Setting version to $new_version..."
    
    # Update all occurrences of MARKETING_VERSION
    sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $new_version;/g" "$PROJECT_FILE"
    
    log_success "Version set to $new_version"
}

# Set build number in project file
set_build_number() {
    local new_build="$1"
    log_info "Setting build number to $new_build..."
    
    # Update all occurrences of CURRENT_PROJECT_VERSION
    sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $new_build;/g" "$PROJECT_FILE"
    
    log_success "Build number set to $new_build"
}

# Increment version
bump_version() {
    local bump_type="$1"
    local current_version
    current_version=$(get_version)
    
    # Split version into components
    IFS='.' read -r major minor patch <<< "$current_version"
    
    case "$bump_type" in
        major)
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        minor)
            minor=$((minor + 1))
            patch=0
            ;;
        patch)
            patch=$((patch + 1))
            ;;
        *)
            log_error "Invalid bump type: $bump_type"
            exit 1
            ;;
    esac
    
    local new_version="$major.$minor.$patch"
    set_version "$new_version"
    
    # Auto-increment build number
    local current_build
    current_build=$(get_build_number)
    local new_build=$((current_build + 1))
    set_build_number "$new_build"
    
    echo "$new_version"
}

# Generate changelog from git commits
generate_changelog() {
    local since="${1:-}"
    
    if [[ -z "$since" ]]; then
        # Get last tag
        since=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    fi
    
    if [[ -z "$since" ]]; then
        log_warning "No previous tag found, showing all commits"
        git log --pretty=format:"- %s (%h)" --no-merges
    else
        log_info "Generating changelog since $since..."
        git log "$since"..HEAD --pretty=format:"- %s (%h)" --no-merges
    fi
}

# Create git tag for release
create_release_tag() {
    local version="$1"
    local message="${2:-Release v$version}"
    
    log_info "Creating git tag v$version..."
    
    # Check if tag already exists
    if git rev-parse "v$version" >/dev/null 2>&1; then
        log_error "Tag v$version already exists"
        exit 1
    fi
    
    git tag -a "v$version" -m "$message"
    log_success "Created tag v$version"
}

# Display current version info
show_version_info() {
    local version
    local build
    version=$(get_version)
    build=$(get_build_number)
    
    echo ""
    echo "╔══════════════════════════════════════╗"
    echo "║      iAlly Version Information       ║"
    echo "╠══════════════════════════════════════╣"
    echo "║ Version:      $version                    ║"
    echo "║ Build Number: $build                       ║"
    echo "╚══════════════════════════════════════╝"
    echo ""
}

# Validate semantic version format
validate_version() {
    local version="$1"
    if [[ ! "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        log_error "Invalid version format: $version (expected: X.Y.Z)"
        exit 1
    fi
}

# Main command handler
main() {
    local command="${1:-get}"
    
    case "$command" in
        get|info)
            show_version_info
            ;;
        
        major|minor|patch)
            local new_version
            new_version=$(bump_version "$command")
            local new_build
            new_build=$(get_build_number)
            
            log_success "Bumped $command version to $new_version (build $new_build)"
            show_version_info
            
            log_warning "Don't forget to commit these changes:"
            echo "  git add $PROJECT_FILE"
            echo "  git commit -m 'Bump version to $new_version ($new_build)'"
            ;;
        
        set)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 set BUILD_NUMBER"
                exit 1
            fi
            local new_build="$2"
            if [[ ! "$new_build" =~ ^[0-9]+$ ]]; then
                log_error "Build number must be a positive integer"
                exit 1
            fi
            set_build_number "$new_build"
            show_version_info
            ;;
        
        set-version)
            if [[ $# -lt 2 ]]; then
                log_error "Usage: $0 set-version X.Y.Z"
                exit 1
            fi
            local new_version="$2"
            validate_version "$new_version"
            set_version "$new_version"
            show_version_info
            ;;
        
        changelog)
            local since="${2:-}"
            generate_changelog "$since"
            ;;
        
        tag)
            local version
            version=$(get_version)
            local message="${2:-Release v$version}"
            create_release_tag "$version" "$message"
            ;;
        
        help|--help|-h)
            echo "iAlly Version Management Script"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  get                   Show current version and build number (default)"
            echo "  major                 Bump major version (X.0.0)"
            echo "  minor                 Bump minor version (0.X.0)"
            echo "  patch                 Bump patch version (0.0.X)"
            echo "  set BUILD_NUMBER      Set specific build number"
            echo "  set-version X.Y.Z     Set specific version"
            echo "  changelog [since]     Generate changelog from git commits"
            echo "  tag [message]         Create git tag for current version"
            echo "  help                  Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 get                # Show current version"
            echo "  $0 patch              # Bump patch version (1.0.0 → 1.0.1)"
            echo "  $0 minor              # Bump minor version (1.0.0 → 1.1.0)"
            echo "  $0 major              # Bump major version (1.0.0 → 2.0.0)"
            echo "  $0 set 42             # Set build number to 42"
            echo "  $0 set-version 2.5.3  # Set version to 2.5.3"
            echo "  $0 changelog v1.0.0   # Show changes since v1.0.0"
            echo "  $0 tag 'Release 1.0'  # Create git tag"
            ;;
        
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
