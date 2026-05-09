# Walkthrough: Soft Archive Feature

## 1. Overview
We have replaced the destructive "Auto-Delete" logic with a true "Soft Archive" feature.
- **Old Behavior:** `ArchiveService.archiveTask` -> Permanent Deletion.
- **New Behavior:** `ArchiveService.archive` -> Sets `isArchived = true`.

## 2. Changes Made
- **Model:** Added `isArchived` to `TaskWork`.
- **Service:** Refactored `ArchiveService` to support archive/unarchive.
- **UI:**
  - Added **Archive Button** to `TaskDetailView` (visible when task is completed).
  - created **Archived Tasks** list in `SettingsView`.
  - Filtered archived tasks from `Today`, `Upcoming`, and `Inbox`.

## 3. Verification Steps (Automated)
We created a new E2E test: `iAllyUITests/Scenarios/ArchiveFeatureTests.swift`

### Test Case: `testSoftArchiveLifecycle`
1. **Setup:** Launch app with clean state.
2. **Action:** Create a task "Task to Archive".
3. **Action:** Mark task as **Complete**.
4. **Action:** Tap **Archive** button in Task Detail.
5. **Verify:** Task disappears from Inbox.
6. **Action:** Navigate to **Settings > Archived Tasks**.
7. **Verify:** Task appears in list.
8. **Action:** Swipe right to **Restore**.
9. **Verify:** Task reappears in Inbox.

## 4. Manual Verification Guide
1. Create a task.
2. Open it and check the toolbar (only Trash and Checkmark visible).
3. Complete the task (swipe or tap circle).
4. Open it again -> **Archive Icon** (box with arrow) should appear.
5. Tap Archive. It closes.
6. Check Today/Inbox -> Task is gone.
7. Go to Settings -> Archived Tasks.
8. Validate "Task to Archive" is listed with "Archived today" text.
9. Swipe right -> Restore.
10. Check Inbox -> Task is back.
