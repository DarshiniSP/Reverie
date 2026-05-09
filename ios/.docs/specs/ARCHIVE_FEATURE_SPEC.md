# Archive Feature Specification (Deep Dive)

**Status:** Draft / Proposed
**Impact:** High (Schema Change Required)
**Last Updated:** 2025-12-22

> **SDLC:** [Protocol](../ORCHESTRATION_PROTOCOL.md) | [PRD](../PRD.md) | [System Map](../SYSTEM_MAP.md)

---

## 1. Analysis of Existing Code
Current implementation in `ArchiveService.swift` is **destructive**:
```swift
// Current Logic
private func archiveTask(_ task: TaskWork) {
    recordAbandonmentEvent(task) // Save analytics
    modelContext.delete(task)    // PERMANENTLY DELETE
}
```
**Problem:** This is "Auto-Cleaning", not "Archiving". Users expect "Archive" to mean "hide from view but preserve data".

## 2. Proposed Architecture: "Soft Archive"

We need to implement a true non-destructive archive state.

### 2.1 Schema Changes
**File:** `Models/Task.swift`
- [ ] Add `var isArchived: Bool = false`
- [ ] Add `var archivedAt: Date?`

*Note: SwiftData handles lightweight migrations automatically for new properties with default values.*

### 2.2 Service Layer Updates
**File:** `Services/ArchiveService.swift`
- [ ] Rename existing `archiveTask` to `cleanupTask` (destructive).
- [ ] Add public `archive(_ task: TaskWork)`: Sets `isArchived = true`.
- [ ] Add public `unarchive(_ task: TaskWork)`: Sets `isArchived = false`.
- [ ] Add `fetchArchivedTasks() -> [TaskWork]`.

### 2.3 UI Integration (The Missing Gaps)

#### A. Task Detail View
**File:** `Views/TaskDetailView.swift`
- logic: If task is completed (`isCompleted == true`), show **"Archive"** button instead of/alongside Delete.
- action: Calls `ArchiveService.archive(task)`.

#### B. Archived Tasks List (New View)
**File:** `Views/Settings/ArchivedTasksView.swift` (New)
- list: Displays all `isArchived == true` tasks.
- action: Swipe to "Unarchive" or "Delete Permanently".

#### C. Filtering Updates
**Files:** `TodayContentView.swift`, `UpcomingContentView.swift`, `InboxContentView.swift`
- update: Predicates must now exclude archived tasks: `!task.isArchived`.

## 3. Implementation Steps

### Step 1: Model & Service (Backend)
1. Modify `TaskWork` model.
2. Refactor `ArchiveService` to support soft archive.
3. **Verify:** Unit test to ensure `archive()` creates a recoverable state.

### Step 2: Lists Logic (Protection)
1. Update `@Query` predicates in all main views (`Today`, `Upcoming`, `Inbox`) to filter out `isArchived`.
2. **Verify:** Archived tasks disappear from main views.

### Step 3: UI Integration (Frontend)
1. Create `ArchivedTasksView`.
2. Add entry point in `SettingsView`.
3. Update `TaskDetailView` with Archive action.

## 4. Test Strategy
- **Test 1:** Archive a task -> Verify it disappears from Today view.
- **Test 2:** Check Settings -> Archived Tasks -> Verify task is there.
- **Test 3:** Unarchive task -> Verify it reappears in Today view.
