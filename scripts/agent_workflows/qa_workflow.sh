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
