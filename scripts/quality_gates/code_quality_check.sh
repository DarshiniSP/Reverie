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
