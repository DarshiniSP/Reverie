//
//  iAllyApp.swift
//  iAlly
//
//  Created by Irigam Developer on 7/12/25.
//

import SwiftUI
import SwiftData
import UserNotifications
import BackgroundTasks


@main
struct ReverieApp: App {
    // P4-A: UIApplicationDelegate for APNs token registration and silent push handling
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @ObservedObject private var notificationManager = NotificationManager.shared
    @State private var biometricAuth = BiometricAuthManager.shared
    @Environment(\.scenePhase) private var scenePhase
    // Note: Offline queue disabled - See docs/guides/KNOWN_ISSUES.md for details
    
    init() {
        // Firebase removed for Phase 1 - focus on local-first solo productivity
        // Load test data IMMEDIATELY if requested (before any views render)
        // Data will be loaded synchronously in the container setup if -LoadTestData flag is present

        // Handle forced onboarding for UI tests (Reset only once at launch)
        if ProcessInfo.processInfo.arguments.contains("-UITest_ForceOnboarding") {
            UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        }
        // Skip onboarding for standard UI tests that want to test the main app
        if ProcessInfo.processInfo.arguments.contains("-UITest_SkipOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }

        // Phase 3: Register background task handler BEFORE app finishes launching
        // Must be called before the app delegate's applicationDidFinishLaunching
        if FeatureFlags.proactiveIntelligenceEnabled {
            ProactiveIntelligenceEngine.registerBackgroundTask()
        }
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            TaskWork.self,
            Plan.self,
            Journey.self,
            Milestone.self,
            FocusSession.self,
            Routine.self,
            MindsetEvent.self,
            GrowthInsight.self,
            Tag.self,
            TimeBlock.self,
            // Removed from Phase 1: SharedItem, Comment, ActivityLog (social features)
            Attachment.self,
            CustomView.self,
            // Removed from Phase 1: Expense, ContactGroup, UserProfile, FriendConnection (social features)
            OfflineOperation.self,
            // Phase 2: Lumina Knowledge Layer
            Knowledge.self,
            // Quick Notes scratchpad
            LuminaNote.self,
            // GAP 1: Offline memory event queue
            PendingMemoryEvent.self,
            // GAP 3: Persistent Lumina conversation history
            LuminaSession.self,
            PersistedLuminaMessage.self,
            // On-device memory store — mirrors PAI server events for offline Lumina memory
            LocalMemoryItem.self,
            // Reusable checklist templates
            ChecklistTemplate.self,
            // Standalone checklists (groceries, travel, exams, etc.)
            Checklist.self,
            // Countdown events: exams, NS ORD, PSLE, personal deadlines
            CountdownEvent.self
        ])

        // If the app is launched for UI tests and requests an in-memory store,
        // use an in-memory ModelConfiguration to isolate tests from persistent data.
        let env = ProcessInfo.processInfo.environment
        let args = ProcessInfo.processInfo.arguments
        let isUnitTesting = env["XCTestConfigurationFilePath"] != nil
        let useInMemory = env["UITEST_IN_MEMORY"] == "1" || args.contains("-UITest_ResetState") || isUnitTesting

#if DEBUG
        print("DEBUG: iAllyApp init - isUnitTesting: \(isUnitTesting), useInMemory: \(useInMemory)")
#endif

        // Configure storage: in-memory for tests, CloudKit for production
        let modelConfiguration: ModelConfiguration
        if useInMemory {
            modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        } else {
            // Enable CloudKit sync with automatic database
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false,
                groupContainer: .identifier(AppConfig.appGroupIdentifier),
                cloudKitDatabase: FeatureFlags.cloudKitEnabled ? .automatic : .none
            )
        }

        // Helper: create container and perform post-init setup.
        // mainContext is @MainActor-isolated; the App stored-property initializer
        // always runs on the main thread, so assumeIsolated is safe here.
        func makeContainer(config: ModelConfiguration) throws -> ModelContainer {
            let container = try ModelContainer(for: schema, configurations: [config])
            // Perform post-init setup synchronously so tests start with a fully-seeded DB.
            // ⚠️ OFFLINE QUEUE DISABLED - See KNOWN_ISSUES.md
            MainActor.assumeIsolated {
                if !useInMemory {
                    Self.createDefaultTagsIfNeeded(in: container.mainContext)
                }
            }
            return container
        }

        do {
            let container = try makeContainer(config: modelConfiguration)
#if DEBUG
            print("DEBUG: ModelContainer created successfully")
#endif
            return container
        } catch {
            // Store is corrupted or incompatible after a schema change.
            // Attempt recovery: delete the on-disk store files and retry once.
#if DEBUG
            print("DEBUG: ModelContainer init failed (\(error)). Attempting store reset...")
#endif
            if !useInMemory {
                if let appSupportURL = FileManager.default
                    .urls(for: .applicationSupportDirectory, in: .userDomainMask).first {
                    for suffix in ["", ".wal", ".shm"] {
                        let url = appSupportURL.appendingPathComponent("default.store\(suffix)")
                        try? FileManager.default.removeItem(at: url)
                    }
                }
                let recoveryConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    groupContainer: .identifier(AppConfig.appGroupIdentifier),
                    cloudKitDatabase: .none
                )
                if let recovered = try? makeContainer(config: recoveryConfig) {
#if DEBUG
                    print("DEBUG: ModelContainer recovered after store reset")
#endif
                    return recovered
                }
#if DEBUG
                print("DEBUG: Recovery also failed. Falling back to in-memory store.")
#endif
            }
            // Last resort: in-memory store so the app never hard-crashes on launch.
            let fallbackConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            do {
                let fallback = try ModelContainer(for: schema, configurations: [fallbackConfig])
#if DEBUG
                print("DEBUG: Running with in-memory fallback store — data will not persist this session")
#endif
                return fallback
            } catch {
                fatalError("iAlly: Cannot create even an in-memory ModelContainer — the app cannot start. Error: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            // Phase 1: No authentication required - direct to main app
            if hasCompletedOnboarding {
                ZStack {
                    MainTabView()

                    // Phase 4: Biometric lock overlay
                    if !biometricAuth.isUnlocked {
                        LockScreenView()
                            .transition(.opacity)
                            .zIndex(999)
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    biometricAuth.handleScenePhase(newPhase)
                }
                // ⚠️ OFFLINE QUEUE DISABLED - See KNOWN_ISSUES.md
                .onOpenURL { url in
                    handleDeepLink(url)
                }
                .task {
                        // Start real CloudKit sync monitoring
                        CloudSyncManager.shared.startMonitoring()
                        // Skip notifications during UI tests AND Unit tests
                        let isUITesting = ProcessInfo.processInfo.arguments.contains("-UITest_ResetState")
                        let isUnitTesting = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
                        
                        if isUnitTesting { return }

                        let forceOnboarding = ProcessInfo.processInfo.arguments.contains("-UITest_ForceOnboarding")

                        if isUITesting {
                            // Automatically skip onboarding for standard UI tests (unless forced)
                            if !forceOnboarding {
                                hasCompletedOnboarding = true
                            }
                        }
                        // MOVED TO INIT: if forceOnboarding { hasCompletedOnboarding = false }

                        if !isUITesting {
                            // Load PII pattern catalog (bundled fallback + silent remote refresh)
                            await PIICatalogManager.shared.loadCatalog()

                            // Setup notifications on app launch
                            await notificationManager.checkAuthorizationStatus()
                            notificationManager.setupNotificationCategories()
                            
                            // Request permission if not determined
                            if notificationManager.authorizationStatus == .notDetermined {
                                _ = await notificationManager.requestAuthorization()
                            }
                            
                            // Setup daily review reminder
                            if notificationManager.isAuthorized {
                                await notificationManager.scheduleDailyReviewReminder()
                                // Weekly Resilience report — fires every Sunday at 7 PM
                                await notificationManager.scheduleWeeklyResilienceReport()
                            }

                            // P4-A: Register for remote (silent) push notifications so
                            // PAIService can wake the app for background intelligence cycles.
                            UIApplication.shared.registerForRemoteNotifications()

                            // Phase 3: Schedule and run proactive intelligence
                            if FeatureFlags.proactiveIntelligenceEnabled {
                                // GAP 6 FIX: Give the engine a reference to the container
                                // so the static BGTask handler can create its own context.
                                ProactiveIntelligenceEngine.shared.modelContainer = sharedModelContainer
                                // GAP 1: Give PAIMemoryBridge a ModelContext for the offline queue
                                PAIMemoryBridge.shared.modelContext = sharedModelContainer.mainContext
                                // On-device memory: give LocalMemoryService the same context
                                LocalMemoryService.shared.modelContext = sharedModelContainer.mainContext
                                // P2-A: Schedule recurring Sunday 8pm weekly reflection notification
                                await WeeklyReflectionService.shared.scheduleWeeklyReflection()
                                // Schedule the next background refresh
                                ProactiveIntelligenceEngine.scheduleBackgroundRefresh()
                                // Run the intelligence cycle if not yet run today
                                await ProactiveIntelligenceEngine.shared.runIfNeeded(
                                    context: sharedModelContainer.mainContext
                                )
                            }
                        }

                        if !isUITesting {
                            // Generate tasks from active routines
                            await RoutineManager.shared.generateTasksFromRoutines(context: sharedModelContainer.mainContext)

                            // Process any pending Siri Shortcut tasks
                            _ = ShortcutManager.shared.processPendingShortcutTaskWork(in: sharedModelContainer.mainContext)
                        }
                    }
            } else {
                OnboardingView(isCompleted: $hasCompletedOnboarding)
                    .task { CloudSyncManager.shared.startMonitoring() }
            }
        }
        .modelContainer(sharedModelContainer)
    }
    
    // MARK: - Deep Link Handling
    
    private static func createDefaultTagsIfNeeded(in context: ModelContext) {
        // Check if tags already exist
        let descriptor = FetchDescriptor<Tag>()
        if let existingTags = try? context.fetch(descriptor), !existingTags.isEmpty {
            return // Tags already exist
        }
        
        // Create default tags
        TagManager.shared.createDefaultTags(in: context)
        try? context.save()
    }
    
    private func handleDeepLink(_ url: URL) {
        // Handle deep links from widgets and Siri Shortcuts
        // Format: iAlly://today, iAlly://task/created, etc.
#if DEBUG
        print("Deep link opened: \(url)")
#endif
        
        // Process any pending shortcut tasks
        _ = ShortcutManager.shared.processPendingShortcutTaskWork(in: sharedModelContainer.mainContext)
    }
}
