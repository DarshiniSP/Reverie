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
