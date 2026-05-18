# Reverie
A proactive AI productivity system for students who want to live with intention, not just manage a to-do list

## Problem
Most productivity apps solve the wrong problem. They are excellent at capture, getting things out of your head and into a list. But they stop there. Once a task is entered, the system becomes passive. It waits. It reminds. It does not reason.
The result is a system that reflects what you said you would do, not what you are actually doing. Important goals sit quietly alongside grocery runs with no signal that one has been untouched for six weeks. Your health goals coexist with assignment deadlines in the same list. Nothing flags that your relationships domain has had zero activity this month. No one notices that you keep completing small, easy tasks while rescheduling the one hard thing that actually matters.
Generic habit trackers do not solve this either. They track streaks, not meaning. They reward consistency without asking whether what you are being consistent about is aligned with who you are trying to become.
What is missing is a layer of intelligence over the whole picture, something that understands the structure of a life, not just a task list.

## Solution
Reverie is a native iOS app built around three interconnected layers:

### Structure: 
An 8-domain life framework (Health, Career, Relationships, Learning, Creativity, Finance, Home, Personal) with four entity types: Plans (domain-level buckets that group related goals and give your work a sense of direction), Journeys (time-bound goals broken into milestones, designed for things that take months rather than days), Routines (recurring practices that auto-generate tasks on a schedule so you never have to re-enter them), and Tasks (individual work units that carry metadata like priority, energy cost, size, and due date). Tasks can exist independently or as part of larger structures like routines, journeys, and plans, allowing the system to understand both isolated actions and long-term behavioural patterns across life domains.

### Intelligence:
Lumina is an AI companion that runs periodically in the background. It identifies behavioural patterns across your activity that may not be immediately visible, and generates personalised nudges and a daily briefing. It also supports conversational task capture and semantic search across past notes.

### Reflection:
A Growth Mindset Engine that focuses on resilience and recovery rather than streaks. It logs behavioural events such as missed, rescheduled, recovered, and abandoned actions, and generates confidence-scored insights based on 30-day behavioural history. It surfaces patterns in how you actually work, rather than how you intended to work.

Reverie is built on the idea that people often struggle not because they lack motivation, but because they lack clear visibility into their own behaviour.

## Demo

## System Design

Reverie is built on a local-first data model using 24 SwiftData entities as its foundation. All core data is stored on device by default, including Plans, Journeys, Milestones, Routines, Tasks, behavioural event logs, conversation history, and AI-generated insights. CloudKit sync is available as an optional extension for users who want cross-device continuity.

The system is organised into a service-oriented architecture with over 40 specialised components, each responsible for a single domain of logic. The GrowthMindsetService processes behavioural events such as missed, rescheduled, recovered, and abandoned actions, and computes confidence-scored insights from rolling 30-day histories. The LifePatternAnalyzer aggregates completion data by time of day to identify behavioural energy patterns. The PIIScrubber operates as a mandatory pre-inference pipeline that removes sensitive identifiers through multiple passes before any data is sent to external APIs.

The intelligence layer is split into two execution paths. The ProactiveIntelligenceEngine runs on iOS Background Tasks every six hours, processing the full local dataset to detect behavioural anomalies such as inactive goals, neglected domains, and unprepared milestones. Each observation is scored by urgency and persisted as structured nudges and daily briefings without requiring user interaction.The LuminaConversationService handles real-time interactions. Before each model call, the LuminaSystemPromptBuilder composes a context-aware prompt from the user’s active plans, journeys, routines, and preferences, ensuring responses are grounded in personal state rather than generic context.

Inference is abstracted through a unified routing layer that supports multiple providers at runtime, including Claude, GPT-4o, Gemini 1.5 Pro, and Mercury-2. The router handles dynamic provider selection, API key management via iOS Keychain, and automatic fallback in the event of rate limits or service failure.

Each subsystem is strictly decoupled. SwiftData handles persistence, the service layer encapsulates all behavioural and analytical logic, the inference router abstracts external model dependencies, and SwiftUI is responsible purely for presentation. This separation ensures that each layer can evolve independently without cascading changes across the system.

## Key Features

* Lumina AI companion with conversational task capture and daily briefings
* Multi-provider AI routing with graceful fallback across models
* Proactive nudge engine based on behavioural patterns and lifecycle signals
* Growth Mindset Engine with resilience and recovery tracking
* Complex recurrence system with flexible scheduling rules and exceptions
* On-device PII scrubbing before external API calls
* Full data export and ownership
* 189 UI test scenarios across automated flows

## Trade-offs and Decisions

### 1. Fixed 8 life domains vs. user-defined categories
User-defined categories sound more flexible but impose a hidden cost: users have to decide what categories matter before they start, which is cognitively expensive and often leads to inconsistent organisation. Fixed domains remove that friction and make domain-level intelligence meaningful. You can only detect that Health has gone quiet if Health is a defined, consistent category. The trade-off is reduced flexibility for users with unusual life structures.

### 2. Resilience metrics over streak tracking
Standard streak tracking penalises recovery. A user who breaks a 10-day streak and rebuilds for 30 days should feel progress, not loss. The Growth Mindset Engine separates currentStreak from recoveryCount, streakBreakCount, and resilienceScore, and weights recovery as a positive signal.The trade-off is that tracking three separate numbers (streak, recovery count, resilience score) instead of one makes the interface harder to read at a glance. A plain streak counter tells you one thing immediately. This tells you something more accurate, but you have to look at it for a moment longer to understand where you stand.

### 3. Structural privacy vs. user self-censorship
Users cannot consistently self-censor when talking to an AI. Telling someone "do not write personal details" places a burden the system should carry. The PII scrubber runs before every inference call and removes sensitive identifiers automatically. This adds a small latency overhead on every message but is a non-negotiable design principle. For users who are still skeptical: the scrubber runs entirely on-device, before any network call is made. Nothing reaches the inference provider until it has already passed through the filter. The inference log in the developer settings shows exactly what was sent, so you can verify for yourself that no raw personal data left the device.

### 4. Multi-provider inference routing
Single-provider dependency creates fragility: rate limits, outages, and model deprecations are real risks. Supporting four providers with graceful fallback increases resilience and gives users choice based on cost or preference. The trade-off is a more complex inference layer and four separate integration surfaces to maintain.

## Shortcomings

### 1. No server-side infrastructure
The proactive engine decides when to nudge you (for example, reminding you that a goal has gone untouched for several days) based on fixed numbers that were set by hand during development. There is no way to know whether those numbers are actually right for most people, because the app does not collect or compare data across users. If the thresholds are off, the only way to fix them is to rewrite that part of the system with a backend that can learn from real usage patterns.

### 2. Offline AI fallback is limited
When network is unavailable, Lumina falls back to pre-composed responses rather than on-device inference. Local semantic search over notes works offline, but full conversational responses and briefing generation require connectivity.

### 3. Nudge threshold calibration is static and uniform
Each nudge type has a fixed trigger point (for example, flag a goal as drifting after a set number of inactive days). Ideally, that number would adjust per user over time. If you consistently ignore a certain type of nudge, the app should learn that and back off. Right now it does not. The thresholds are the same for everyone and do not change based on your behaviour.

## Future Directions

### 1. Adaptive nudge calibration
Nudge thresholds should learn from user behaviour, tracking which nudges get acted on and which get dismissed, and adjust sensitivity per user over time. This requires a feedback signal the current build does not have.

### 2. Shared accountability mode
An opt-in feature where users share selected journey progress with a trusted person, a mentor or accountability partner, without exposing the full task log. Privacy-preserving progress sharing rather than full transparency.

### 3. HealthKit integration
Pulling physiological signals (sleep, activity, HRV) into the energy pattern analysis would ground scheduling recommendations in actual physical state, not just inferred patterns from task history.

### 4. Backend analytics infrastructure
A server layer would enable nudge threshold optimisation across users, model quality evaluation, and longitudinal product analytics, while keeping all personal data local on device.

### 5. ML-based completion prediction
The current prediction logic is rule-based (task size, due date presence, historical category rates). A trained model on longitudinal user behaviour would produce more accurate and personalised estimates.

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData (24 entities) |
| Cloud Sync | CloudKit (optional iCloud sync) |
| AI Inference | Claude (Anthropic), GPT-4o (OpenAI), Gemini 1.5 Pro (Google), Mercury-2, runtime-selectable |
| Background Processing | BackgroundTasks (BGAppRefreshTask) |
| Home Screen Widgets | WidgetKit |
| Siri Integration | AppIntents |
| Calendar Sync | EventKit |
| Biometric Auth | LocalAuthentication (Face ID / Touch ID) |
| Security | iOS Keychain, 3-layer PII Scrubber |
| State Management | Swift Observation + Combine (SSE streaming) |
| Architecture | MVVM with service layer |
| Testing | XCTest UI automation (189 test files) |

No third-party dependencies.



































