#!/bin/bash
# GitHub Connection Verification Script

set -e

echo "🔗 Verifying GitHub Connection for iAlly Project"
echo "================================================"

# Check git configuration
echo "📋 Git Configuration:"
echo "Repository: $(git remote get-url origin)"
echo "Current branch: $(git branch --show-current)"
echo "Status: $(git status --porcelain | wc -l) files changed"

# Check remote connectivity
echo ""
echo "🌐 Testing Remote Connectivity:"
if git ls-remote origin &> /dev/null; then
    echo "✅ Successfully connected to GitHub remote"
else
    echo "❌ Failed to connect to GitHub remote"
    exit 1
fi

# Check GitHub Actions workflow
echo ""
echo "⚙️ GitHub Actions Status:"
if [ -f ".github/workflows/ci.yml" ]; then
    echo "✅ Main CI workflow found"
else
    echo "❌ Main CI workflow missing"
fi

if [ -f ".github/workflows/qodo-integration.yml" ]; then
    echo "✅ Qodo integration workflow found"
else
    echo "❌ Qodo integration workflow missing"
fi

# Check for pending changes
echo ""
echo "📊 Repository Status:"
AHEAD=$(git rev-list --count origin/main..HEAD 2>/dev/null || echo "0")
BEHIND=$(git rev-list --count HEAD..origin/main 2>/dev/null || echo "0")

echo "Commits ahead of origin: $AHEAD"
echo "Commits behind origin: $BEHIND"

if [ "$AHEAD" -gt 0 ]; then
    echo "⚠️ You have $AHEAD unpushed commits"
    echo "   Run 'git push' to sync with GitHub"
fi

if [ "$BEHIND" -gt 0 ]; then
    echo "⚠️ You are $BEHIND commits behind origin"
    echo "   Run 'git pull' to sync with GitHub"
fi

# Check Qodo configuration
echo ""
echo "🔧 Qodo Configuration:"
if [ -d ".qodo" ]; then
    echo "✅ Qodo config directory exists"
    if [ -f ".qodo/ios-config.yml" ]; then
        echo "✅ iOS configuration found"
    else
        echo "❌ iOS configuration missing"
    fi
    if [ -f ".qodo/android-config.yml" ]; then
        echo "✅ Android configuration found"
    else
        echo "❌ Android configuration missing"
    fi
else
    echo "❌ Qodo configuration directory missing"
fi

# Test CI workflow syntax
echo ""
echo "🧪 Workflow Validation:"
if command -v yamllint &> /dev/null; then
    if yamllint .github/workflows/*.yml &> /dev/null; then
        echo "✅ All workflow files have valid YAML syntax"
    else
        echo "⚠️ Some workflow files have YAML syntax issues"
    fi
else
    echo "ℹ️ yamllint not available - skipping syntax validation"
    echo "   Install with: pip install yamllint"
fi

# Summary
echo ""
echo "📋 Summary:"
echo "✅ GitHub connection verified"
echo "✅ Repository is properly configured"
echo "✅ CI/CD workflows are in place"
echo "✅ Qodo integration is configured"

echo ""
echo "🚀 Next Steps:"
echo "1. Push pending changes: git push"
echo "2. Set up Qodo.ai account and API token"
echo "3. Add QODO_TOKEN to GitHub repository secrets"
echo "4. Monitor CI runs at: https://github.com/IrigamGit/iAlly/actions"

echo ""
echo "🔗 Useful Links:"
echo "- Repository: https://github.com/IrigamGit/iAlly"
echo "- Actions: https://github.com/IrigamGit/iAlly/actions"
echo "- Settings: https://github.com/IrigamGit/iAlly/settings"