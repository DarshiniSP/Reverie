# iAlly AI Coding Instructions

## Project Context
iAlly is a **local-first, privacy-focused productivity app** for iOS 17.0+. It helps users organize tasks, plans, journeys, and routines without requiring an account or internet connection.
- **Stack:** SwiftUI, SwiftData, Observation Framework.
- **Philosophy:** "Your data, your device." No backend servers; optional CloudKit sync.
- **Status:** Phase 1 (MVP). Firebase has been removed.

## Architecture & Patterns

### 1. Data Layer (SwiftData)
- **Models:** Defined in `iAlly/Models/` using the `@Model` macro (e.g., `Task`, `Plan`, `Journey`).
- **Persistence:** Local-only by default. **Do not** add `userId` fields to models (single-user architecture).
- **Relationships:** Use explicit relationships (e.g., `Plan` has many `Tasks`).
- **Migration:** SwiftData handles simple migrations automatically.

### 2. MVVM + Observation
- **ViewModels:** Use `@Observable` (Swift 6+).
- **Flow:** View -> ViewModel (Business Logic) -> Service/ModelContext -> Persistence.
- **Services:** Singleton services in `iAlly/Services/` (e.g., `RoutineManager`, `NotificationManager`) handle cross-cutting concerns.

### 3. Design System
**ALWAYS** use the centralized design tokens in `iAlly/DesignSystem.swift`. Do not hardcode colors or fonts.
- **Colors:** `DSColors.canvasPrimary`, `DSColors.accentPrimary`, `DSColors.textSecondary`.
- **Fonts:** `DSFonts.title(28)`, `DSFonts.body(17)`.
- **Components:** Use `PrimaryButtonStyle`, `SecondaryButtonStyle`, `NavBarModifier`.

## Critical Workflows

### Testing (Strict Policy)
We support **iOS 17 and iOS 18**. Tests must pass on both.
- **Unit Tests:** Parallel execution **ENABLED**.
- **UI Tests:** Parallel execution **DISABLED** (to prevent flakiness).
- **UI Test Isolation:** App uses in-memory SwiftData when launched with `UITEST_IN_MEMORY` argument.

**Run Tests Locally:**
```bash
# Unit Tests (iOS 17)
xcodebuild -workspace iAlly.xcworkspace -scheme iAlly -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing iAllyTests -parallel-testing-enabled YES test | xcpretty --simple

# UI Tests (iOS 17)
xcodebuild -workspace iAlly.xcworkspace -scheme iAlly -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing iAllyUITests -parallel-testing-enabled NO test | xcpretty --simple
```

### Accessibility & UI Testing
- **Identifiers:** Every interactive element MUST have an `.accessibilityIdentifier` (e.g., `addItemButton`, `saveItemButton`).
- **Lists:** Dynamic rows should have predictable IDs (e.g., `item-<timestamp>`).

## Common Tasks

### Adding a New Feature
1. **Model:** Define `@Model` in `iAlly/Models/`.
2. **Service:** Add logic to a Service or Manager if complex.
3. **ViewModel:** Create an `@Observable` class to bridge View and Data.
4. **View:** Build using `DesignSystem` components.
5. **Test:** Add Unit Tests for logic and UI Tests for critical flows.

### Debugging
- **CI Scripts:** Use `scripts/ci_summary.sh` to check build status.
- **Logs:** Check `build_output.txt` or `test_result.json` for failures.

## Key Files
- `docs/00_Master_Product_Dev_Guide.md`: Source of truth for product & dev.
- `iAlly/DesignSystem.swift`: UI tokens.
- `docs/07_Testing_Policy.md`: Detailed testing commands.
