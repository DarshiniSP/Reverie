#!/bin/bash
# scripts/agent_workflows/master_workflow.sh
# Master Agent Workflow Control for iAlly Multi-Agent SDLC

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Clear screen and show header
clear
echo -e "${BLUE}🎭 iAlly Multi-Agent SDLC Master Control${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Show current project status
echo -e "${CYAN}📊 Current Project Status:${NC}"
echo -e "   iOS: ${GREEN}✅ Production Ready${NC} (4 critical bugs fixed)"
echo -e "   Android: ${YELLOW}🏗️ Early Scaffolding${NC} (~10 Kotlin files)"
echo -e "   Test Pass Rate: ${GREEN}78%${NC} (56/72 tests)"
echo ""

# Show available agents
echo -e "${PURPLE}🎭 Available Specialized Agents:${NC}"
echo -e "   ${GREEN}1.${NC} 🎩 Product Manager     - Feature planning, user stories, priorities"
echo -e "   ${GREEN}2.${NC} 📐 Architect           - Technical design, cross-platform planning"
echo -e "   ${GREEN}3.${NC} 🎨 Designer            - UI/UX design, design system, accessibility"
echo -e "   ${GREEN}4.${NC} 🍎 iOS Developer       - Swift/SwiftUI implementation, iOS features"
echo -e "   ${GREEN}5.${NC} 🤖 Android Developer   - Kotlin/Compose implementation, Android porting"
echo -e "   ${GREEN}6.${NC} 🕵️‍♀️ QA Engineer        - Testing, verification, quality assurance"
echo -e "   ${GREEN}7.${NC} 🚀 Release Manager     - Version management, deployment coordination"
echo ""

# Show current priorities
echo -e "${YELLOW}🎯 Current Priority Tasks:${NC}"
echo -e "   ${RED}iOS Bugs:${NC} Test reliability improvements (accessibility ID mismatches)"
echo -e "   ${BLUE}Android:${NC} Room entities, UI screens, service layer implementation"
echo ""

# Show quality gates status
echo -e "${CYAN}🔍 Quality Gates Status:${NC}"
if [[ -f "scripts/quality_gates/cross_platform_parity.sh" ]]; then
    echo -e "   ✅ Cross-platform parity check available"
else
    echo -e "   ❌ Cross-platform parity check missing"
fi

if [[ -f "scripts/quality_gates/code_quality_check.sh" ]]; then
    echo -e "   ✅ Code quality check available"
else
    echo -e "   ❌ Code quality check missing"
fi
echo ""

# Agent selection prompt
echo -e "${GREEN}Select an agent to activate (1-7), or 'q' to quit:${NC}"
read -p "Choice: " choice

case $choice in
    1)
        echo -e "${GREEN}🎩 Activating Product Manager Agent...${NC}"
        ./scripts/agent_workflows/pm_workflow.sh
        ;;
    2)
        echo -e "${GREEN}📐 Activating Architect Agent...${NC}"
        ./scripts/agent_workflows/architect_workflow.sh
        ;;
    3)
        echo -e "${GREEN}🎨 Activating Designer Agent...${NC}"
        ./scripts/agent_workflows/designer_workflow.sh
        ;;
    4)
        echo -e "${GREEN}🍎 Activating iOS Developer Agent...${NC}"
        ./scripts/agent_workflows/ios_developer_workflow.sh
        ;;
    5)
        echo -e "${GREEN}🤖 Activating Android Developer Agent...${NC}"
        ./scripts/agent_workflows/android_developer_workflow.sh
        ;;
    6)
        echo -e "${GREEN}🕵️‍♀️ Activating QA Engineer Agent...${NC}"
        ./scripts/agent_workflows/qa_workflow.sh
        ;;
    7)
        echo -e "${GREEN}🚀 Activating Release Manager Agent...${NC}"
        ./scripts/agent_workflows/release_workflow.sh
        ;;
    q|Q)
        echo -e "${BLUE}👋 Goodbye! Happy coding with Multi-Agent SDLC!${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}❌ Invalid selection. Please choose 1-7 or 'q' to quit.${NC}"
        echo ""
        echo -e "${YELLOW}💡 Tip: Each agent has specialized knowledge and tools for their domain.${NC}"
        echo -e "${YELLOW}   Follow the Golden Workflow: PM → Architect → Designer → Developer → QA → Release${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}🎯 Remember the Multi-Agent SDLC Principles:${NC}"
echo -e "   1. Always activate the appropriate agent for the task"
echo -e "   2. Follow the Golden Workflow for new features"
echo -e "   3. Run quality gates before committing changes"
echo -e "   4. Maintain cross-platform parity between iOS and Android"
echo -e "   5. Document decisions in agent artifacts"
echo ""
echo -e "${GREEN}✨ Agent activation complete! Follow the agent's guidance for best results.${NC}"