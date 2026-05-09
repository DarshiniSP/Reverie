# Changelog - iAlly
**Format:** Keep a Changelog  
**Versioning:** Semantic Versioning

> **SDLC:** [Protocol](ORCHESTRATION_PROTOCOL.md) | [PRD](PRD.md) | [System Map](SYSTEM_MAP.md) | [Test Suite](TEST_SUITE.md) | [Context](CONTEXT_BUFFER.md) | [Changelog](CHANGELOG.md)

---

## [Unreleased]

### Added (2025-12-23)
- **Comprehensive Test Suite:** Created 4 new test files (CompletedTasksTests, AnalyticsTests, SettingsTests, AdvancedFeaturesTests) adding 22 new tests. Total: 50 tests with 100% pass rate.
- **Test Coverage:** Achieved 95% automated coverage. All core features, analytics, settings, and advanced features now fully automated.
- **Manual Testing Guide:** Created detailed manual testing procedures for remaining 5% edge cases.

### Added (2025-12-22)
- **SDLC Protocol:** Established `.docs/` directory with 6 core documents (ORCHESTRATION_PROTOCOL, PRD, SYSTEM_MAP, TEST_SUITE, CONTEXT_BUFFER, CHANGELOG).
- **Documentation Consolidation:** Merged 90+ scattered files from `/Projects/iAlly/Docs/` into unified SDLC structure.
- **Root Cleanup:** Organized 89 scattered files (.log, .txt, .md) into `.archive/` subdirectories.
- **Gap Analysis:** Added Section 5 to PRD.md documenting implementation status (85% complete) and critical gaps.
- **Test Suite Definition:** Clarified official 28-test suite in `Scenarios/` folder with execution guidelines.
- **Navigation:** Added "Related Documents" header to all SDLC docs for easy navigation.
- **Archive Feature:** Implemented "Soft Archive" allowing users to archive/unarchive tasks instead of permanently deleting them. Added `ArchivedTasksView` and `Archive` button in Task Detail.

### Changed (2025-12-23)
- **Archive Feature:** Refactored from manual archive to auto-hide approach. Completed tasks are now automatically hidden from active views (no manual archiving needed).
- **Completed Tasks:** Added dedicated "Completed Tasks" view under More > Analytics to see all completed tasks grouped by date.

### Removed (2025-12-23)
- **Manual Archive:** Removed `isArchived` property from Task model, Archive button from Task Detail, Archived Tasks view from Settings, and all archive/unarchive methods from ArchiveService.

### Fixed (2025-12-22)
- **Archive Feature:** Archived tasks now properly hidden from Plan and Journey detail views.
- **Weekly Review:** Fixed trend number display (removed double backslash typo).

### Changed (2025-12-22)
- **Subtask Logic:** Updated `TodayContentView`, `UpcomingContentView`, and `InboxContentView` to hide subtasks from top-level lists.
- **Data Seeder:** Added 5 new demo Plans to cover all 8 Life Domains (Relationships, Creativity, Finance, Home, Personal).
- **UI:** Removed duplicate "Done" button from `TagSelectionView`.
- **UI:** Added Time Picker support to `TaskDetailView`'s due date section.

### Fixed (2025-12-22)
- Fixed bug where only "Career" Life Domain was selectable in pickers.
- Fixed inconsistent DatePicker appearance between Add and Edit screens.
- Fixed subtask display hierarchy (subtasks now only visible under parent tasks).

---

## Version History

### [1.0.0] - Pre-SDLC (Before 2025-12-22)
- Initial app implementation
- Core features: Tasks, Plans, Journeys, Routines
- Growth Mindset Engine, Time Blocking, Focus Timer
- Attachments, Custom Views, Search
- CloudKit Sync, Widgets, Siri/Shortcuts

---

## Notes
- All changes after 2025-12-22 follow the SDLC Orchestration Protocol
- See `.docs/PRD.md` Section 5 for current implementation status
- See `.docs/CONTEXT_BUFFER.md` for active work and next steps
