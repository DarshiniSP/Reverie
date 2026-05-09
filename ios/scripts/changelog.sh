#!/bin/bash
# Changelog Generator for iAlly
# Generates formatted changelogs from git commits between versions

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Emoji categorization
FEATURE_EMOJI="✨"
FIX_EMOJI="🐛"
BREAKING_EMOJI="💥"
DOCS_EMOJI="📝"
STYLE_EMOJI="💄"
REFACTOR_EMOJI="♻️"
PERF_EMOJI="⚡"
TEST_EMOJI="✅"
BUILD_EMOJI="🔧"
CI_EMOJI="👷"
CHORE_EMOJI="🔨"

log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Get last git tag
get_last_tag() {
    git describe --tags --abbrev=0 2>/dev/null || echo ""
}

# Get all tags sorted by version
get_all_tags() {
    git tag -l "v*" --sort=-version:refname
}

# Categorize commit message
categorize_commit() {
    local message="$1"
    local emoji=""
    local category=""
    
    # Check conventional commit format
    if [[ "$message" =~ ^feat(\(.*\))?:\ .+ ]]; then
        emoji="$FEATURE_EMOJI"
        category="Features"
    elif [[ "$message" =~ ^fix(\(.*\))?:\ .+ ]]; then
        emoji="$FIX_EMOJI"
        category="Bug Fixes"
    elif [[ "$message" =~ ^docs(\(.*\))?:\ .+ ]]; then
        emoji="$DOCS_EMOJI"
        category="Documentation"
    elif [[ "$message" =~ ^style(\(.*\))?:\ .+ ]]; then
        emoji="$STYLE_EMOJI"
        category="Styling"
    elif [[ "$message" =~ ^refactor(\(.*\))?:\ .+ ]]; then
        emoji="$REFACTOR_EMOJI"
        category="Code Refactoring"
    elif [[ "$message" =~ ^perf(\(.*\))?:\ .+ ]]; then
        emoji="$PERF_EMOJI"
        category="Performance"
    elif [[ "$message" =~ ^test(\(.*\))?:\ .+ ]]; then
        emoji="$TEST_EMOJI"
        category="Tests"
    elif [[ "$message" =~ ^build(\(.*\))?:\ .+ ]]; then
        emoji="$BUILD_EMOJI"
        category="Build System"
    elif [[ "$message" =~ ^ci(\(.*\))?:\ .+ ]]; then
        emoji="$CI_EMOJI"
        category="CI/CD"
    elif [[ "$message" =~ ^chore(\(.*\))?:\ .+ ]]; then
        emoji="$CHORE_EMOJI"
        category="Chores"
    else
        # Default categorization based on keywords
        if echo "$message" | grep -iq "add\|new\|implement\|feature"; then
            emoji="$FEATURE_EMOJI"
            category="Features"
        elif echo "$message" | grep -iq "fix\|bug\|issue\|resolve"; then
            emoji="$FIX_EMOJI"
            category="Bug Fixes"
        elif echo "$message" | grep -iq "update\|change\|modify"; then
            emoji="$REFACTOR_EMOJI"
            category="Changes"
        elif echo "$message" | grep -iq "improve\|enhance\|optimize"; then
            emoji="$PERF_EMOJI"
            category="Improvements"
        else
            emoji="$CHORE_EMOJI"
            category="Other"
        fi
    fi
    
    echo "${emoji}|${category}"
}

# Generate changelog for a range
generate_changelog_range() {
    local from="$1"
    local to="${2:-HEAD}"
    local format="${3:-markdown}"
    
    local commits
    if [[ -z "$from" ]]; then
        commits=$(git log --pretty=format:"%s|%h|%an|%ar" --no-merges "$to")
    else
        commits=$(git log --pretty=format:"%s|%h|%an|%ar" --no-merges "$from..$to")
    fi
    
    if [[ -z "$commits" ]]; then
        echo "No commits found in range"
        return
    fi
    
    # Group commits by category
    declare -A categories
    
    while IFS= read -r line; do
        local message=$(echo "$line" | cut -d'|' -f1)
        local hash=$(echo "$line" | cut -d'|' -f2)
        local author=$(echo "$line" | cut -d'|' -f3)
        local date=$(echo "$line" | cut -d'|' -f4)
        
        # Skip certain commits
        if echo "$message" | grep -iq "\[skip ci\]\|Merge \|bump version"; then
            continue
        fi
        
        local cat_info=$(categorize_commit "$message")
        local emoji=$(echo "$cat_info" | cut -d'|' -f1)
        local category=$(echo "$cat_info" | cut -d'|' -f2)
        
        # Clean up commit message
        message=$(echo "$message" | sed 's/^[a-z]*(\(.*\)): //' | sed 's/^[a-z]*: //')
        
        local entry="${emoji} ${message} ([${hash}](https://github.com/IrigamGit/iAlly/commit/${hash}))"
        
        if [[ -z "${categories[$category]:-}" ]]; then
            categories[$category]="$entry"
        else
            categories[$category]="${categories[$category]}"$'\n'"$entry"
        fi
    done <<< "$commits"
    
    # Output formatted changelog
    if [[ "$format" == "markdown" ]]; then
        generate_markdown_changelog categories
    elif [[ "$format" == "plain" ]]; then
        generate_plain_changelog categories
    elif [[ "$format" == "appstore" ]]; then
        generate_appstore_changelog categories
    fi
}

# Generate markdown format
generate_markdown_changelog() {
    local -n cats=$1
    
    # Define category order
    local ordered_categories=("Features" "Bug Fixes" "Performance" "Improvements" "Changes" "Code Refactoring" "Documentation" "Tests" "CI/CD" "Build System" "Styling" "Chores" "Other")
    
    for category in "${ordered_categories[@]}"; do
        if [[ -n "${cats[$category]:-}" ]]; then
            echo ""
            echo "### $category"
            echo ""
            echo "${cats[$category]}"
        fi
    done
}

# Generate plain text format
generate_plain_changelog() {
    local -n cats=$1
    
    local ordered_categories=("Features" "Bug Fixes" "Performance" "Improvements" "Changes" "Code Refactoring" "Documentation" "Tests" "CI/CD" "Build System" "Styling" "Chores" "Other")
    
    for category in "${ordered_categories[@]}"; do
        if [[ -n "${cats[$category]:-}" ]]; then
            echo ""
            echo "$category:"
            echo "${cats[$category]}" | sed 's/\[\([^]]*\)\]([^)]*)/\1/g' | sed 's/^/  - /'
        fi
    done
}

# Generate App Store format (no markdown, emoji-only)
generate_appstore_changelog() {
    local -n cats=$1
    
    # Prioritize user-facing changes
    local ordered_categories=("Features" "Bug Fixes" "Improvements" "Performance" "Changes")
    
    for category in "${ordered_categories[@]}"; do
        if [[ -n "${cats[$category]:-}" ]]; then
            echo "${cats[$category]}" | sed 's/\[\([^]]*\)\]([^)]*)//' | head -n 10
        fi
    done | head -n 20  # App Store has character limits
}

# Generate full changelog for all versions
generate_full_changelog() {
    local format="${1:-markdown}"
    
    log_info "Generating full changelog..."
    
    if [[ "$format" == "markdown" ]]; then
        echo "# Changelog"
        echo ""
        echo "All notable changes to iAlly will be documented in this file."
        echo ""
    fi
    
    local tags=($(get_all_tags))
    
    if [[ ${#tags[@]} -eq 0 ]]; then
        log_error "No tags found in repository"
        return 1
    fi
    
    for i in "${!tags[@]}"; do
        local current_tag="${tags[$i]}"
        local next_tag="${tags[$((i+1))]:-}"
        
        local version="${current_tag#v}"
        local date=$(git log -1 --format=%ai "$current_tag" | cut -d' ' -f1)
        
        if [[ "$format" == "markdown" ]]; then
            echo "## [$version] - $date"
        else
            echo ""
            echo "Version $version ($date):"
        fi
        
        if [[ -n "$next_tag" ]]; then
            generate_changelog_range "$next_tag" "$current_tag" "$format"
        else
            generate_changelog_range "" "$current_tag" "$format"
        fi
        
        echo ""
    done
}

# Generate changelog since last tag
generate_unreleased_changelog() {
    local format="${1:-markdown}"
    local last_tag=$(get_last_tag)
    
    if [[ -z "$last_tag" ]]; then
        log_info "No previous tags found, showing all commits"
        last_tag=""
    else
        log_info "Generating changelog since $last_tag..."
    fi
    
    if [[ "$format" == "markdown" ]]; then
        echo "## [Unreleased]"
    else
        echo "Unreleased Changes:"
    fi
    
    generate_changelog_range "$last_tag" "HEAD" "$format"
}

# Main
main() {
    local command="${1:-unreleased}"
    local format="${2:-markdown}"
    
    case "$command" in
        unreleased|next)
            generate_unreleased_changelog "$format"
            ;;
        
        full|all)
            generate_full_changelog "$format"
            ;;
        
        range)
            if [[ $# -lt 3 ]]; then
                log_error "Usage: $0 range FROM TO [format]"
                exit 1
            fi
            local from="$2"
            local to="$3"
            local range_format="${4:-markdown}"
            generate_changelog_range "$from" "$to" "$range_format"
            ;;
        
        save)
            local output_file="${2:-CHANGELOG.md}"
            generate_full_changelog "markdown" > "$output_file"
            log_success "Saved changelog to $output_file"
            ;;
        
        help|--help|-h)
            echo "iAlly Changelog Generator"
            echo ""
            echo "Usage: $0 [command] [options]"
            echo ""
            echo "Commands:"
            echo "  unreleased [format]        Generate changelog for unreleased changes"
            echo "  full [format]              Generate full changelog for all versions"
            echo "  range FROM TO [format]     Generate changelog between two refs"
            echo "  save [filename]            Save full changelog to file (default: CHANGELOG.md)"
            echo "  help                       Show this help message"
            echo ""
            echo "Formats:"
            echo "  markdown     Markdown format with links (default)"
            echo "  plain        Plain text format"
            echo "  appstore     App Store format (emoji only, limited)"
            echo ""
            echo "Examples:"
            echo "  $0 unreleased              # Show unreleased changes"
            echo "  $0 full                    # Show all versions"
            echo "  $0 range v1.0.0 v1.1.0     # Show changes between versions"
            echo "  $0 unreleased appstore     # App Store format"
            echo "  $0 save                    # Save to CHANGELOG.md"
            ;;
        
        *)
            log_error "Unknown command: $command"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
