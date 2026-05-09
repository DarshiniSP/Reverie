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
