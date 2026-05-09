# Product Requirements Document (PRD) - iAlly
**Version:** 1.1
**Last Updated:** 2025-12-22

> **SDLC:** [Protocol](ORCHESTRATION_PROTOCOL.md) | [PRD](PRD.md) | [System Map](SYSTEM_MAP.md) | [Test Suite](TEST_SUITE.md) | [Context](CONTEXT_BUFFER.md) | [Changelog](CHANGELOG.md)

---

## 1. Product Overview
iAlly is an AI-powered life management and productivity assistant designed to help users organize their tasks, goals (Journeys), and routines while fostering a growth mindset through analytics.

---

## 2. Core Concepts
- **Tasks (TaskWork):** Fundamental unit of work. Can be standalone, part of a Plan, Journey, or Routine.
- **Plans (Life Domains):** High-level categories (e.g., Career, Health). Every task belongs to a Plan (or "Inbox" if unassigned).
- **Journeys (Goals):** Specific, time-bound goals with milestones (Tasks).
- **Routines:** Recurring sets of tasks.
- **Growth Mindset:** Analytics engine tracking energy, task size, and completion velocity.

---

## 3. Features

### 3.1 Task Management
- **Hierarchy:** Parent Tasks → Subtasks (Depth: 1 level).
- **Attributes:** Due Date, Priority (Energy), Size, Impact.
- **Views:** Today, Upcoming, Inbox, Custom Lists.

### 3.2 Planning & Goals
- **Life Domains:** 8 fixed domains (Health, Career, Relationships, Learning, Creativity, Finance, Home, Personal).
- **Journey Mapping:** Linking tasks to specific outcomes (e.g., "Run a Marathon" → Health).
- **User Profile:** Personalization based on user goals and historical performance.

### 3.3 Productivity & Growth Tools
- **Growth Mindset Engine:** Analyzes completion rates, energy distribution, and consistency to provide actionable insights.
- **Time Blocking:** Calendar integration for tasks.
- **Focus Timer:** Pomodoro-style timer for task execution.
- **Weekly Review:** Retrospective on completed tasks.

### 3.4 Advanced Features
- **Attachments:** Photo and document attachments on tasks/journeys.
- **Custom Views:** User-defined filtered task lists with custom criteria.
- **Offline Queue:** Operations queued when offline, synced when connection restored.
- **Archive:** Long-term storage for completed tasks (declutter active views).
- **Batch Operations:** Multi-select actions (complete, delete, reassign).
- **Natural Language Input:** Smart parsing of task descriptions ("Buy milk tomorrow at 3pm").
- **Focus Sessions:** Pomodoro timer with session tracking.
- **Search:** Full-text search across tasks, plans, and journeys.

---

## 4. Technical Constraints & Architecture
- **Data Persistence:** SwiftData (locally stored).
- **Cloud Sync:** CloudKit (shared database for future sharing features).
- **Subtask Display:** Subtasks MUST NOT appear in top-level lists (Today, Inbox, etc.) unless explicitly queried. They reside within Parent Task details.
- **Demo Data:** System must provide a robust demo state with all 8 Life Domains populated.
- **Widgets:** Home screen widgets supported for "Today's Focus" and "Growth Stats".
- **Siri/Shortcuts:** Basic NLP task addition supported via Intents.

---

## 5. Implementation Status & Gap Analysis
**Last Updated:** 2025-12-22  
**Overall Completion:** 85%

### 5.1 Fully Implemented ✅
- Task Management (CRUD, Subtasks, Hierarchy)
- Plans (8 Life Domains)
- Journeys, Routines, Time Blocking
- Focus Timer, Weekly Review
- Attachments, Custom Views, Search
- Growth Mindset Engine, Offline Queue
- CloudKit Sync, Widgets, Siri/Shortcuts
- Completed Tasks View (auto-hide approach, grouped by date, searchable)

### 5.2 Critical Gaps (Must Fix)

**Batch Operations** - Service exists, NO UI integration  
- Impact: Users cannot multi-select tasks
- Estimate: 6-8 hours

**Natural Language Parser** - Service exists, NO UI integration
- Impact: Users cannot use smart input ("Buy milk tomorrow 3pm")
- Estimate: 4-6 hours

### 5.3 Medium Priority Gaps
- User Profile screen (incomplete)
- Demo Data (only 3/8 Plans auto-created on first launch)
- Test Coverage (only 6/28 core tests run successfully)
- Widget configuration (helper exists, targets not configured)

### 5.4 Recommended Action Plan
**Phase 1 (2-3 weeks):** Integrate Archive, Batch Ops, NLP + Fix all tests (~33 hours)  
**Phase 2 (1-2 weeks):** User Profile + Widget configuration (~16 hours)  
**Phase 3 (1 week):** Polish & accessibility (~4 hours)

---

## 6. Testing Strategy

### 6.1 Official Test Suite (Core E2E Scenarios)
**Location:** `iAllyUITests/Scenarios/`

These are the **canonical** automated tests that must pass before any release:

1. **TaskManagementTests.swift** (2 tests)
   - Full task lifecycle (create, edit, complete, delete)
   - Subtask management (create, complete, delete)

2. **TodayUpcomingInboxTests.swift** (4 tests)
   - Today view filtering
   - Upcoming view date grouping
   - Inbox unorganized task logic
   - Task hierarchy validation

3. **PlanJourneyTests.swift** (18 tests)
   - Plan creation and management
   - Journey creation and milestones
   - Task-to-Plan/Journey assignment

4. **RoutineHabitTests.swift** (4 tests)
   - Routine creation
   - Recurring task generation
   - Routine completion tracking

**Total Core Tests:** 28 tests  
**Target Pass Rate:** 95%+

### 6.2 Utility Tests
**Location:** `iAllyUITests/` (root)

- **OnboardingTests.swift** - First-run experience validation
- **SmokeTests.swift** - High-level sanity checks (app launches, tabs work)
- **LinkTests.swift** - Deep link handling

### 6.3 Debug/Development Tests
- **DebugTests.swift** - Developer debugging helpers (not for CI)
- **iAllyUITestsLaunchTests.swift** - Xcode template (minimal value)

### 6.4 Test Execution Policy
- **Pre-Commit:** Run Smoke Tests (fast feedback)
- **Pre-Release:** Run all Core E2E Scenarios sequentially
- **CI/CD:** Run Core + Utility tests on every PR
- **Manual QA:** Required for UI changes not covered by automation

---

## 7. Future Roadmap
- **AI Coach:** Personalized recommendations based on Growth Mindset data.
- **Collaboration:** Share Plans/Journeys with team members via CloudKit.
- **Advanced Analytics:** Predictive insights on task completion patterns.
