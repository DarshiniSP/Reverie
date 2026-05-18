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
An 8-domain life framework (Health, Career, Relationships, Learning, Creativity, Finance, Home, Personal) with four entity types: Plans (domain buckets), Journeys (time-bound goals with milestones), Routines (recurring practices), and Tasks (individual work units). 

### Intelligence:
Lumina, an AI companion that runs proactively in the background every 6 hours. It analyses your task and goal history across all domains, detects patterns you would not notice yourself, and surfaces personalised nudges and a daily briefing without any user action required. It also supports conversational task capture and semantic search over your past notes.

### Reflection:
A Growth Mindset Engine that measures resilience and recovery, not just streaks. It records behavioral events (missed, rescheduled, recovered, abandoned), generates confidence-scored insights from 30-day histories, and surfaces patterns in how you actually work, not how you intended to work.

The core design principle: the gap between intention and action is not a motivation problem. It is a visibility problem.

## Demo

## System Design

Reverie is built around a local-first data model with 24 SwiftData entities as its foundation. Everything lives on device by default: Plans, Journeys, Milestones, Routines, Tasks, behavioral event logs, conversation history, and AI-generated insights. iCloud sync via CloudKit is available but opt-in.

Above that sits a service layer of 40+ specialised components, each with a single responsibility. The GrowthMindsetService records behavioral events (missed, recovered, rescheduled, abandoned) and generates eight types of confidence-scored insights from 30-day histories. The LifePatternAnalyzer tracks task completion rates by hour of day to identify energy peaks and valleys. The PIIScrubber runs on every outgoing message, stripping personal identifiers across three passes before any data reaches an external API.

The intelligence layer splits into two systems. The ProactiveIntelligenceEngine runs in the background every 6 hours via iOS Background Tasks. It reads the full SwiftData history, detects patterns the user has not noticed (a goal going quiet, a domain with no activity, a milestone approaching without preparation), scores each observation by urgency, and writes them as nudges and a daily briefing. This runs without any user action. The LuminaConversationService handles real-time conversation. Before each inference call, LuminaSystemPromptBuilder constructs a context-rich prompt from the user's active journeys, plans, routines, and preferences, so the AI responds from the user's actual data rather than a generic context.

Inference is handled by a single router that supports four providers at runtime: Claude, GPT-4o, Gemini 1.5 Pro, and Mercury-2. Switching providers requires no code change. API keys live in the iOS Keychain. If a provider is unavailable, the router falls back gracefully.

Each layer has a clear responsibility. SwiftData manages persistence. The service layer handles all analysis and behavioral logic. The inference router abstracts provider differences. SwiftUI views are purely presentational. This structure keeps each part independently changeable without affecting the others.

## Key Features

- Lumina AI companion: conversational task capture, semantic search over past notes, daily briefing generation, proactive background analysis every 6 hours
- Multi-provider inference routing: Claude, GPT-4o, Gemini 1.5 Pro, Mercury-2 switchable at runtime, with graceful fallback on provider unavailability
- Proactive nudge engine: goal drift, domain silence, energy pattern recommendations, milestone proximity, achievement nudges, surfaced without user action
- Growth Mindset Engine: behavioral event recording, 8 insight types with confidence scores, resilience and recovery tracked separately from streaks
- Complex recurrence: "every 3 days," "third Friday of the month," "weekdays only," per-instance modifications, exception dates
- 3-layer PII scrubbing: automatic before every inference call, jurisdiction-aware, user-defined custom patterns
- Local-first with optional CloudKit sync: all data on device by default
- Biometric lock: Face ID / Touch ID with 1-hour idle re-lock
- Calendar sync: EventKit integration
- Data export: full personal data ownership
- 189 UI test scenarios across 50+ automated flows

## Trade-offs and Decisions

### 1. Fixed 8 life domains vs. user-defined categories
User-defined categories sound more flexible but impose a hidden cost: users have to decide what categories matter before they start, which is cognitively expensive and leads to inconsistent organisation over time. Fixed domains remove that friction and make domain-level intelligence meaningful. You can only detect that Health has gone quiet if Health is a defined, consistent category. The trade-off is reduced flexibility for users with unusual life structures.

### 2. Proactive intelligence over better search and filter
Search requires you to know what you are looking for. The core problem this app addresses, goal drift and domain neglect, happens precisely when users do not know what to look for. Investing in proactive detection produces higher value than making manual discovery easier. The trade-off is that nudge calibration is genuinely hard; threshold logic requires careful tuning to avoid alert fatigue, and the right threshold varies by user.

### 3. Resilience metrics over streak tracking
Standard streak tracking penalises recovery. A user who breaks a 10-day streak and rebuilds for 30 days should feel progress, not loss. The Growth Mindset Engine separates currentStreak from recoveryCount, streakBreakCount, and resilienceScore, and weights recovery as a positive signal. The trade-off is more complex metrics storage and a less immediately legible interface than a streak counter.

### 4. Structural privacy vs. user self-censorship
Users cannot consistently self-censor when talking to an AI. Telling someone "do not write personal details" places a burden the system should carry. The PII scrubber runs before every inference call and removes sensitive identifiers automatically. This adds a small latency overhead on every message but is a non-negotiable design principle.

### 5. Multi-provider inference routing
Single-provider dependency creates fragility: rate limits, outages, and model deprecations are real risks. Supporting four providers with graceful fallback increases resilience and gives users choice based on cost or preference. The trade-off is a more complex inference layer and four separate integration surfaces to maintain.

### 6. Local-first data model
Personal productivity data is inherently sensitive. CloudKit sync is available but opt-in. The trade-off is that cross-device syncing requires the user to enable it explicitly rather than being seamless by default.

### 7. TaskWork as the primary entity name instead of Task
Swift's structured concurrency uses Task as a first-class type in the standard library. Naming the data model entity TaskWork avoids namespace collision. No clean alternative given the language constraints.

## Shortcomings

### 1. No server-side infrastructure
The proactive engine's nudge thresholds are static, calibrated by hand rather than learned from what actually produces behaviour change. There is no way to know whether a given nudge type is useful across users, because there is no aggregation layer. Improving calibration requires rebuilding it on a backend.

### 2. Offline AI fallback is limited
When network is unavailable, Lumina falls back to pre-composed responses rather than on-device inference. Local semantic search over notes works offline, but full conversational responses and briefing generation require connectivity.

### 3. Nudge threshold calibration is static and uniform
Each nudge type has hardcoded thresholds (for example, "goal drift after N days"). These should adapt per user based on behavioral feedback. If a user consistently dismisses goal drift nudges, the threshold should increase. Currently they do not.

### 4. Offline sync queue is disabled in the current build
The OfflineOperationQueue architecture for handling CloudKit sync conflicts exists but is not active. Editing data across devices in poor connectivity may produce conflicts.

### 5. No collaborative or social layer
Accountability partners, shared journeys, and social commitment mechanisms are well-documented drivers of follow-through. Reverie is entirely solo.

## Future Directions

### 6. On-device inference
As Apple Silicon in iOS matures, moving inference fully on-device would eliminate network dependency, reduce latency, and strengthen the privacy model with no user-facing trade-off.

### 7. Adaptive nudge calibration
Nudge thresholds should learn from user behaviour, tracking which nudges get acted on and which get dismissed, and adjust sensitivity per user over time. This requires a feedback signal the current build does not have.

### 8. Shared accountability mode
An opt-in feature where users share selected journey progress with a trusted person, a mentor or accountability partner, without exposing the full task log. Privacy-preserving progress sharing rather than full transparency.

### 9. HealthKit integration
Pulling physiological signals (sleep, activity, HRV) into the energy pattern analysis would ground scheduling recommendations in actual physical state, not just inferred patterns from task history.

### 10. Backend analytics infrastructure
A server layer would enable nudge threshold optimisation across users, model quality evaluation, and longitudinal product analytics, while keeping all personal data local on device.

### 11. ML-based completion prediction
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



































