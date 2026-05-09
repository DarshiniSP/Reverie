#!/bin/bash
# Local Qodo.ai Setup Script

echo "🔧 Setting up Qodo.ai for local development..."

# Check if we have the API token
if [ -z "$QODO_TOKEN" ]; then
    echo "⚠️ QODO_TOKEN environment variable not set"
    echo "Please export your Qodo.ai API token:"
    echo "export QODO_TOKEN='your-token-here'"
    echo ""
    echo "You can add this to your ~/.zshrc or ~/.bashrc for persistence"
    exit 1
fi

echo "✅ QODO_TOKEN found"

# Validate configuration files
echo "🔍 Validating configuration files..."

if [ -f ".qodo/ios-config.yml" ]; then
    echo "✅ iOS configuration found"
else
    echo "❌ iOS configuration missing"
    exit 1
fi

if [ -f ".qodo/android-config.yml" ]; then
    echo "✅ Android configuration found"
else
    echo "❌ Android configuration missing"
    exit 1
fi

# Create local analysis script
echo "📝 Creating local analysis script..."
cat > scripts/analyze-code.sh << 'EOF'
#!/bin/bash
# Local code analysis script (placeholder for Qodo CLI)

echo "🔍 Running local code analysis..."

# iOS Analysis
echo "📱 Analyzing iOS Swift code..."
find ios/iAlly -name "*.swift" -type f | wc -l | xargs echo "Swift files found:"

# Check for common issues
echo "🔍 Checking for common Swift issues..."
grep -r "TODO\|FIXME\|XXX" ios/iAlly --include="*.swift" | wc -l | xargs echo "TODO/FIXME comments:"

# Android Analysis  
echo "🤖 Analyzing Android Kotlin code..."
find android -name "*.kt" -type f | wc -l | xargs echo "Kotlin files found:"

# Check for common issues
echo "🔍 Checking for common Kotlin issues..."
grep -r "TODO\|FIXME\|XXX" android --include="*.kt" | wc -l | xargs echo "TODO/FIXME comments:"

echo "✅ Local analysis complete"
echo "ℹ️ For full Qodo analysis, check GitHub Actions at:"
echo "   https://github.com/IrigamGit/iAlly/actions"
EOF

chmod +x scripts/analyze-code.sh

echo "✅ Local setup complete!"
echo ""
echo "📋 Available commands:"
echo "  ./scripts/analyze-code.sh     - Run local code analysis"
echo "  ./scripts/verify-github-connection.sh - Verify GitHub integration"
echo ""
echo "🔗 Monitor CI/CD at: https://github.com/IrigamGit/iAlly/actions"