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
