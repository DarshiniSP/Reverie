#!/bin/bash
# scripts/agent_workflows/setup_agents.sh
# Setup script for Multi-Agent SDLC configuration

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

log_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

log_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

log_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Create directory structure
create_directories() {
    log_info "📁 Creating Multi-Agent SDLC directory structure..."
    
    # Agent-specific directories
    mkdir -p docs/agents/{pm,architect,designer,qa,release}
    mkdir -p docs/logic
    mkdir -p scripts/agent_workflows
    mkdir -p scripts/build
    mkdir -p scripts/quality_gates
    mkdir -p logs/{build,tests,agents}
    mkdir -p .kiro/workflows
    
    # Platform-specific CI directories
    mkdir -p ios/ci_scripts
    mkdir -p android/ci_scripts
    
    log_success "Directory structure created"
}

# Create agent workflow scripts
create_agent_scripts() {
    log_info "🎭 Creating agent workflow scripts..."
    
    # PM Agent Script
    cat > scripts/agent_workflows/pm_workflow.sh << 'EOF'
#!/bin/bash
# Product Manager Agent Workflow

echo "🎩 Activating Product Manager Agent..."
echo "======================================"

# Check current tasks
if [[ -f "docs/agents/pm/task.md" ]]; then
    echo "📋 Current Tasks:"
    grep -E "\[.*\]" docs/agents/pm/task.md | head -10
else
    echo "📋 No current tasks found. Creating task template..."
    cp docs/agents/pm/task_template.md docs/agents/pm/task.md 2>/dev/null || echo "Template not found"
fi

echo ""
echo "Available PM Commands:"
echo "1. Create new feature task"
echo "2. Update task priorities" 
echo "3. Review feature backlog"
echo "4. Generate user stories"
echo "5. Check implementation status"

echo ""
echo "Usage: Describe your feature request and I'll break it down into tasks"
EOF

    # Architect Agent Script
    cat > scripts/agent_workflows/architect_workflow.sh << 'EOF'
#!/bin/bash
# Architect Agent Workflow

echo "📐 Activating Architect Agent..."
echo "==============================="

# Check cross-platform parity
echo "🔍 Checking cross-platform parity..."
if [[ -f "scripts/quality_gates/cross_platform_parity.sh" ]]; then
    ./scripts/quality_gates/cross_platform_parity.sh --summary
else
    echo "⚠️  Cross-platform parity check not available"
fi

echo ""
echo "📊 Implementation Status:"
echo "iOS Files: $(find ios/iAlly -name "*.swift" | wc -l) Swift files"
echo "Android Files: $(find android -name "*.kt" | wc -l) Kotlin files"

echo ""
echo "Available Architect Commands:"
echo "1. Create implementation plan"
echo "2. Update database schema"
echo "3. Check platform parity"
echo "4. Review technical debt"
echo "5. Design cross-platform logic"

echo ""
echo "Usage: Provide feature requirements and I'll create technical implementation plan"
EOF

    # Developer Agent Scripts
    cat > scripts/agent_workflows/ios_developer_workflow.sh << 'EOF'
#!/bin/bash
# iOS Developer Agent Workflow

echo "🍎 Activating iOS Developer Agent..."
echo "==================================="

cd ios 2>/dev/null || { echo "❌ iOS directory not found"; exit 1; }

# Check iOS project status
echo "📱 iOS Project Status:"
if [[ -f "iAlly.xcworkspace/contents.xcworkspacedata" ]]; then
    echo "✅ Xcode workspace found"
    
    # Get version info
    VERSION=$(grep -m 1 "MARKETING_VERSION = " iAlly.xcodeproj/project.pbxproj | sed 's/.*MARKETING_VERSION = \([0-9.]*\);/\1/' || echo "Unknown")
    BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " iAlly.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/' || echo "Unknown")
    echo "   Version: $VERSION ($BUILD)"
else
    echo "❌ Xcode workspace not found"
fi

# Check test status
if [[ -f "run_tests.sh" ]]; then
    echo "✅ Test runner available"
else
    echo "⚠️  Test runner not found"
fi

cd ..

echo ""
echo "Available iOS Developer Commands:"
echo "1. Build iOS project"
echo "2. Run iOS tests"
echo "3. Update implementation progress"
echo "4. Check code quality"
echo "5. Generate iOS documentation"

echo ""
echo "Usage: Provide implementation plan and I'll develop iOS features"
EOF

    cat > scripts/agent_workflows/android_developer_workflow.sh << 'EOF'
#!/bin/bash
# Android Developer Agent Workflow

echo "🤖 Activating Android Developer Agent..."
echo "======================================="

cd android 2>/dev/null || { echo "❌ Android directory not found"; exit 1; }

# Check Android project status
echo "📱 Android Project Status:"
if [[ -f "app/build.gradle.kts" ]]; then
    echo "✅ Android project found"
    
    # Get version info
    VERSION_NAME=$(grep "versionName" app/build.gradle.kts | sed 's/.*versionName = "\([^"]*\)".*/\1/' || echo "Unknown")
    VERSION_CODE=$(grep "versionCode" app/build.gradle.kts | sed 's/.*versionCode = \([0-9]*\).*/\1/' || echo "Unknown")
    echo "   Version: $VERSION_NAME ($VERSION_CODE)"
else
    echo "❌ Android project not found"
fi

# Check Gradle wrapper
if [[ -f "gradlew" ]]; then
    echo "✅ Gradle wrapper available"
    chmod +x gradlew
else
    echo "❌ Gradle wrapper not found"
fi

cd ..

echo ""
echo "Available Android Developer Commands:"
echo "1. Build Android project"
echo "2. Run Android tests"
echo "3. Check iOS parity"
echo "4. Update implementation progress"
echo "5. Generate Android documentation"

echo ""
echo "Usage: Provide implementation plan and I'll develop Android features"
EOF

    # QA Agent Script
    cat > scripts/agent_workflows/qa_workflow.sh << 'EOF'
#!/bin/bash
# QA Engineer Agent Workflow

echo "🕵️‍♀️ Activating QA Engineer Agent..."
echo "=================================="

# Check test status
echo "🧪 Test Status Overview:"

# iOS Tests
if [[ -f "ios/run_tests.sh" ]]; then
    echo "✅ iOS test runner available"
    echo "   Last test results: $(ls -t ios/TestResults*.xcresult 2>/dev/null | head -1 || echo "No recent results")"
else
    echo "⚠️  iOS test runner not found"
fi

# Android Tests
if [[ -f "android/gradlew" ]]; then
    echo "✅ Android test runner available"
    echo "   Test reports: $(ls -t android/app/build/reports/tests 2>/dev/null | head -1 || echo "No recent results")"
else
    echo "⚠️  Android test runner not found"
fi

# Check for test documentation
if [[ -f "docs/agents/qa/walkthrough.md" ]]; then
    echo "✅ QA walkthrough documentation found"
else
    echo "📝 Creating QA walkthrough template..."
fi

echo ""
echo "Available QA Commands:"
echo "1. Run full test suite"
echo "2. Execute manual walkthrough"
echo "3. Generate test report"
echo "4. Check code coverage"
echo "5. Verify cross-platform parity"

echo ""
echo "Usage: Provide feature to test and I'll execute comprehensive QA verification"
EOF

    # Release Manager Script
    cat > scripts/agent_workflows/release_workflow.sh << 'EOF'
#!/bin/bash
# Release Manager Agent Workflow

echo "🚀 Activating Release Manager Agent..."
echo "====================================="

# Check version status
echo "📊 Version Status:"

# iOS Version
if [[ -f "ios/iAlly.xcodeproj/project.pbxproj" ]]; then
    IOS_VERSION=$(grep -m 1 "MARKETING_VERSION = " ios/iAlly.xcodeproj/project.pbxproj | sed 's/.*MARKETING_VERSION = \([0-9.]*\);/\1/' || echo "Unknown")
    IOS_BUILD=$(grep -m 1 "CURRENT_PROJECT_VERSION = " ios/iAlly.xcodeproj/project.pbxproj | sed 's/.*CURRENT_PROJECT_VERSION = \([0-9]*\);/\1/' || echo "Unknown")
    echo "   iOS: $IOS_VERSION ($IOS_BUILD)"
else
    echo "   iOS: Not found"
fi

# Android Version
if [[ -f "android/app/build.gradle.kts" ]]; then
    ANDROID_VERSION=$(grep "versionName" android/app/build.gradle.kts | sed 's/.*versionName = "\([^"]*\)".*/\1/' || echo "Unknown")
    ANDROID_BUILD=$(grep "versionCode" android/app/build.gradle.kts | sed 's/.*versionCode = \([0-9]*\).*/\1/' || echo "Unknown")
    echo "   Android: $ANDROID_VERSION ($ANDROID_BUILD)"
else
    echo "   Android: Not found"
fi

# Check CI status
echo ""
echo "🔄 CI/CD Status:"
if [[ -f ".github/workflows/ci.yml" ]]; then
    echo "✅ GitHub Actions CI configured"
else
    echo "⚠️  GitHub Actions CI not found"
fi

if [[ -f ".github/workflows/qodo-integration.yml" ]]; then
    echo "✅ Qodo.ai integration configured"
else
    echo "⚠️  Qodo.ai integration not found"
fi

echo ""
echo "Available Release Manager Commands:"
echo "1. Bump version numbers"
echo "2. Generate changelog"
echo "3. Deploy to TestFlight"
echo "4. Deploy to Play Store"
echo "5. Create release tags"
echo "6. Check deployment readiness"

echo ""
echo "Usage: Specify release type and I'll orchestrate the deployment process"
EOF

    # Make all scripts executable
    chmod +x scripts/agent_workflows/*.sh
    
    log_success "Agent workflow scripts created"
}

# Create artifact templates
create_templates() {
    log_info "📄 Creating artifact templates..."
    
    # PM Task Template
    cat > docs/agents/pm/task_template.md << 'EOF'
# Feature: [FEATURE_NAME]
**Created:** [DATE]
**Priority:** [High/Medium/Low]
**Estimated Effort:** [TIME_ESTIMATE]

## User Stories
- [ ] As a [USER_TYPE], I want [FUNCTIONALITY], so that [BENEFIT]
- [ ] As a [USER_TYPE], I want [FUNCTIONALITY], so that [BENEFIT]

## Acceptance Criteria
- [ ] [SPECIFIC_REQUIREMENT]
- [ ] [SPECIFIC_REQUIREMENT]

## Definition of Done
- [ ] iOS implementation complete
- [ ] Android implementation complete
- [ ] Tests passing (>85%)
- [ ] Cross-platform parity verified
- [ ] Documentation updated

## Progress Tracking
- [ ] Planning Phase Complete
- [ ] Architecture Design Complete
- [ ] UI/UX Design Complete
- [ ] iOS Development Complete
- [ ] Android Development Complete
- [ ] QA Verification Complete
- [ ] Release Ready

## Notes
[Additional context, dependencies, or considerations]
EOF

    # Architect Implementation Plan Template
    cat > docs/agents/architect/implementation_plan_template.md << 'EOF'
# Implementation Plan: [FEATURE_NAME]
**Created:** [DATE]
**Architect:** [AGENT_NAME]

## Technical Overview
[High-level description of the technical approach]

## iOS Implementation
### Components Affected
- [ ] Models: [LIST_MODELS]
- [ ] Views: [LIST_VIEWS]
- [ ] Services: [LIST_SERVICES]
- [ ] Repositories: [LIST_REPOSITORIES]

### Technical Details
[Specific iOS implementation details]

## Android Implementation
### Components Affected
- [ ] Entities: [LIST_ENTITIES]
- [ ] Screens: [LIST_SCREENS]
- [ ] Services: [LIST_SERVICES]
- [ ] Repositories: [LIST_REPOSITORIES]

### Technical Details
[Specific Android implementation details]

## Shared Logic
### Business Rules
[Document shared business logic in docs/logic/]

### Data Models
[Cross-platform data model specifications]

## Database Changes
- [ ] Schema modifications needed: [YES/NO]
- [ ] Migration required: [YES/NO]
- [ ] Breaking changes: [YES/NO]

## Dependencies
- [ ] External libraries needed
- [ ] Platform-specific requirements
- [ ] Third-party integrations

## Risk Assessment
### Technical Risks
- [RISK_1]: [MITIGATION_STRATEGY]
- [RISK_2]: [MITIGATION_STRATEGY]

### Cross-Platform Risks
- [PARITY_RISK]: [MITIGATION_STRATEGY]

## Verification Plan
### iOS Testing
- [ ] Unit tests for [COMPONENTS]
- [ ] UI tests for [FLOWS]
- [ ] Integration tests for [SERVICES]

### Android Testing
- [ ] Unit tests for [COMPONENTS]
- [ ] UI tests for [FLOWS]
- [ ] Integration tests for [SERVICES]

### Cross-Platform Testing
- [ ] Feature parity verification
- [ ] Data consistency checks
- [ ] UI/UX consistency validation
EOF

    # QA Walkthrough Template
    cat > docs/agents/qa/walkthrough_template.md << 'EOF'
# QA Walkthrough: [FEATURE_NAME]
**Date:** [DATE]
**QA Engineer:** [AGENT_NAME]
**Build Version:** iOS [VERSION] / Android [VERSION]

## Test Environment
- **iOS Device/Simulator:** [DEVICE_INFO]
- **Android Device/Emulator:** [DEVICE_INFO]
- **Test Data:** [DEMO_DATA/PRODUCTION_DATA]

## Feature Verification

### iOS Testing
#### Functional Tests
- [ ] [TEST_CASE_1]: [PASS/FAIL] - [NOTES]
- [ ] [TEST_CASE_2]: [PASS/FAIL] - [NOTES]

#### UI/UX Tests
- [ ] Visual consistency: [PASS/FAIL]
- [ ] Accessibility: [PASS/FAIL]
- [ ] Performance: [PASS/FAIL]

### Android Testing
#### Functional Tests
- [ ] [TEST_CASE_1]: [PASS/FAIL] - [NOTES]
- [ ] [TEST_CASE_2]: [PASS/FAIL] - [NOTES]

#### UI/UX Tests
- [ ] Visual consistency: [PASS/FAIL]
- [ ] Accessibility: [PASS/FAIL]
- [ ] Performance: [PASS/FAIL]

### Cross-Platform Parity
- [ ] Feature behavior identical: [PASS/FAIL]
- [ ] Data synchronization: [PASS/FAIL]
- [ ] UI consistency: [PASS/FAIL]

## Issues Found
### Critical Issues
- [ISSUE_1]: [DESCRIPTION] - [REPRODUCTION_STEPS]

### Minor Issues
- [ISSUE_2]: [DESCRIPTION] - [REPRODUCTION_STEPS]

## Test Results Summary
- **Total Tests:** [NUMBER]
- **Passed:** [NUMBER]
- **Failed:** [NUMBER]
- **Pass Rate:** [PERCENTAGE]

## Recommendations
- [RECOMMENDATION_1]
- [RECOMMENDATION_2]

## Sign-off
- [ ] Feature ready for release
- [ ] Requires additional development
- [ ] Requires design changes
EOF

    log_success "Artifact templates created"
}

# Create quality gate scripts
create_quality_gates() {
    log_info "🔍 Creating quality gate scripts..."
    
    # Cross-platform parity check
    cat > scripts/quality_gates/cross_platform_parity.sh << 'EOF'
#!/bin/bash
# Cross-platform parity check

SUMMARY_MODE=${1:-""}

if [[ "$SUMMARY_MODE" == "--summary" ]]; then
    echo "🔍 Cross-Platform Parity Summary:"
    echo "================================="
else
    echo "🔍 Checking cross-platform parity..."
fi

# Check if shared logic documentation exists
LOGIC_DIR="docs/logic"
if [[ ! -d "$LOGIC_DIR" ]]; then
    echo "❌ Shared logic documentation missing: $LOGIC_DIR"
    if [[ "$SUMMARY_MODE" != "--summary" ]]; then
        exit 1
    fi
else
    echo "✅ Shared logic documentation found"
fi

# Check design system consistency
if [[ "$SUMMARY_MODE" != "--summary" ]]; then
    echo "🎨 Checking design system consistency..."
fi

IOS_DESIGN="ios/iAlly/DesignSystem.swift"
ANDROID_THEME="android/app/src/main/java/com/irigaminnovations/ially/ui/theme/Theme.kt"

if [[ -f "$IOS_DESIGN" ]]; then
    echo "✅ iOS design system found"
else
    echo "⚠️  iOS design system not found: $IOS_DESIGN"
fi

if [[ -f "$ANDROID_THEME" ]]; then
    echo "✅ Android theme found"
else
    echo "⚠️  Android theme not found: $ANDROID_THEME"
fi

# Check feature parity
if [[ "$SUMMARY_MODE" != "--summary" ]]; then
    echo "📊 Checking feature parity..."
fi

IOS_FILES=$(find ios/iAlly -name "*.swift" | wc -l)
ANDROID_FILES=$(find android -name "*.kt" | wc -l)

echo "📊 Implementation Status:"
echo "   iOS Swift files: $IOS_FILES"
echo "   Android Kotlin files: $ANDROID_FILES"

if [[ $ANDROID_FILES -lt 10 ]]; then
    echo "ℹ️  Android implementation in early scaffolding phase"
fi

if [[ "$SUMMARY_MODE" != "--summary" ]]; then
    echo "✅ Cross-platform parity check completed!"
fi
EOF

    # Code quality check
    cat > scripts/quality_gates/code_quality_check.sh << 'EOF'
#!/bin/bash
# Code quality check

echo "🔍 Running code quality checks..."

# Run Qodo.ai analysis if available
if command -v qodo &> /dev/null; then
    echo "🤖 Running Qodo.ai analysis..."
    qodo "Analyze code quality and suggest improvements" || echo "Qodo analysis completed with warnings"
else
    echo "⚠️  Qodo CLI not available"
fi

# Check iOS code quality
if [[ -d "ios" ]]; then
    echo "🍎 Checking iOS code quality..."
    cd ios
    
    # Run SwiftLint if available
    if command -v swiftlint &> /dev/null; then
        swiftlint || echo "SwiftLint found issues"
    else
        echo "⚠️  SwiftLint not installed"
    fi
    
    cd ..
fi

# Check Android code quality
if [[ -d "android" ]]; then
    echo "🤖 Checking Android code quality..."
    cd android
    
    # Run Detekt if configured
    if [[ -f "gradlew" ]]; then
        ./gradlew detekt 2>/dev/null || echo "Detekt not configured or found issues"
    fi
    
    cd ..
fi

echo "✅ Code quality check completed!"
EOF

    chmod +x scripts/quality_gates/*.sh
    
    log_success "Quality gate scripts created"
}

# Create initial artifacts
create_initial_artifacts() {
    log_info "📋 Creating initial artifacts..."
    
    # Create initial task file
    if [[ ! -f "docs/agents/pm/task.md" ]]; then
        cat > docs/agents/pm/task.md << 'EOF'
# iAlly Development Tasks

## Current Sprint: iOS Bug Fixes & Android Planning

### High Priority iOS Bugs
- [ ] Fix duplicate Done buttons in Tag Selection (2 min)
- [ ] Fix tag counter logic (15 min)
- [ ] Add time picker to TaskDetailView (5 min)
- [ ] Complete demo data reset for Life Domain picker

### Android Implementation Planning
- [ ] Create Room entity models
- [ ] Implement basic UI screens
- [ ] Setup service layer
- [ ] Create test infrastructure

## Completed Recently
- [x] Subtask hierarchy display with progress tracking
- [x] Test suite consolidation (44% reduction)
- [x] Subtask feature implementation
- [x] Life Domain picker code fixes
EOF
    fi
    
    # Create feature backlog
    cat > docs/agents/pm/feature_backlog.md << 'EOF'
# iAlly Feature Backlog

## Phase 1: iOS Core Features (Current)
- [x] Task management with subtasks
- [x] Plans, journeys, and routines
- [x] Growth mindset tracking
- [x] Analytics and insights
- [ ] Widget implementation
- [ ] Siri Shortcuts implementation

## Phase 2: iOS Advanced Features
- [ ] CloudKit sync enablement
- [ ] Offline queue re-enablement
- [ ] Advanced analytics
- [ ] AI-powered insights
- [ ] Calendar integration
- [ ] Advanced notifications

## Phase 3: Android Implementation
- [ ] Entity models and Room database
- [ ] UI implementation (all screens)
- [ ] Service layer implementation
- [ ] Testing infrastructure
- [ ] Feature parity with iOS
- [ ] Platform-specific integrations

## Phase 4: Cross-Platform Features
- [ ] Shared backend (optional)
- [ ] Cross-platform sync
- [ ] Advanced AI features
- [ ] Social features (future consideration)
- [ ] Enterprise features
EOF

    log_success "Initial artifacts created"
}

# Main setup function
main() {
    log_info "🚀 Setting up Multi-Agent SDLC for iAlly..."
    
    # Check if we're in the right directory
    if [[ ! -f "ios/iAlly.xcworkspace/contents.xcworkspacedata" ]] || [[ ! -f "android/app/build.gradle.kts" ]]; then
        log_error "Please run this script from the iAlly project root directory"
        exit 1
    fi
    
    create_directories
    create_agent_scripts
    create_templates
    create_quality_gates
    create_initial_artifacts
    
    # Make build scripts executable
    chmod +x scripts/build/*.sh
    
    log_success "🎉 Multi-Agent SDLC setup completed!"
    
    echo ""
    log_info "📋 Next Steps:"
    echo "1. Review the agent workflow scripts in scripts/agent_workflows/"
    echo "2. Try activating an agent: ./scripts/agent_workflows/pm_workflow.sh"
    echo "3. Test the build system: ./scripts/build/build_all.sh"
    echo "4. Read the adoption plan: docs/MULTI_AGENT_SDLC_ADOPTION_PLAN.md"
    echo ""
    log_info "🎭 Available Agents:"
    echo "- PM Agent: ./scripts/agent_workflows/pm_workflow.sh"
    echo "- Architect Agent: ./scripts/agent_workflows/architect_workflow.sh"
    echo "- iOS Developer: ./scripts/agent_workflows/ios_developer_workflow.sh"
    echo "- Android Developer: ./scripts/agent_workflows/android_developer_workflow.sh"
    echo "- QA Engineer: ./scripts/agent_workflows/qa_workflow.sh"
    echo "- Release Manager: ./scripts/agent_workflows/release_workflow.sh"
}

# Run main function
main "$@"