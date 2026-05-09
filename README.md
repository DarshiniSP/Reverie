# iAlly
### An AI-powered second brain for people who want to live with intention — not just manage their to-do list

> *iAlly* — your intelligent ally. Not a task manager that waits to be used, but a system that actively learns your patterns, notices when your goals are drifting, and nudges you back before you even realise you have strayed.

---

## Quick Overview

**What:** A native iOS productivity app that combines task management, goal tracking, and an AI companion (Lumina) that proactively surfaces insights about how you are actually living versus how you intend to live.

**Who:** Ambitious individuals — students, professionals, anyone managing multiple long-term goals across different areas of life — who find that generic task apps help them stay busy but not necessarily grow.

**Key Idea:** Most productivity apps are reactive. iAlly is proactive. Lumina runs in the background, analyses your patterns across 8 life domains, detects goal drift, and delivers personalised nudges before small inconsistencies become long-term stagnation.

**Why it matters:** The gap between intention and action is not a motivation problem — it is a visibility problem. iAlly closes that gap.

> No subscription required to use core features. API keys are user-supplied and stored in the device Keychain. All personal data stays on your device.

---

## Why I Built This

I have always been the kind of person who keeps a lot of plates spinning — academics, dance, personal projects, long-term goals. For a while, I managed this with a combination of notes apps, reminders, and mental tracking. It worked until it did not.

What I kept running into was not a shortage of tools. It was a shortage of *feedback*. I had lists everywhere, but no system that could tell me whether I was actually moving toward anything meaningful. I would complete tasks consistently for weeks, feel productive, and then realise three months later that I had not touched something I genuinely cared about — a goal that had quietly dropped out of rotation while I stayed busy with easier, more urgent things.

I wanted something that behaved less like a whiteboard and more like a thoughtful collaborator — something that would notice the drift before I did, and say so.

Building iAlly taught me that intelligence in software is not just about the AI model you use. It is about how carefully you design the questions the system asks of your data. The hardest part of this project was not the implementation. It was figuring out what patterns were actually worth detecting.

---

## The Problem

Productivity apps solve the wrong problem.

They are excellent at capture — getting things out of your head and into a list. But they stop there. Once a task is entered, the app becomes passive. It waits. It reminds. It does not reason.

The result is a system that reflects what you *said* you would do, not what you are *actually* doing. Important goals coexist with trivial errands in the same list with no indication that one has been untouched for six weeks. Your health goals sit quietly in the same column as grocery runs. Nothing flags that your relationships domain has had zero activity in a month. No one notices that you keep completing small, easy tasks while rescheduling the one hard thing that actually matters.

Generic habit trackers do not solve this either. They track streaks, not meaning. They reward consistency without asking whether what you are being consistent about is aligned with who you are trying to become.

What was missing was a layer of *intelligence over the whole picture* — something that understood the structure of a life, not just a task list.

---

## The Solution

iAlly is a native iOS app built around three interconnected layers:

**1. Structure** — A framework for organising life across 8 domains (Health, Career, Relationships, Learning, Creativity, Finance, Home, Personal) with Plans, Journeys, and Routines that reflect how real goals actually work — not flat lists, but hierarchies with milestones, deadlines, and recurring practices.

**2. Intelligence** — Lumina, an AI companion that does not just respond to questions. It runs proactively in the background, analyses your task and goal data, detects patterns (goal drift, energy distribution, domain silence, burnout risk), and surfaces personalised nudges and a daily briefing — all grounded in your actual behaviour, not generic advice.

**3. Reflection** — A Growth Mindset Engine that tracks not just completions, but recovery. It gives credit for coming back after a miss, measures resilience across tasks and routines, and frames your data in terms of growth rather than failure.

---

## Core Features

### Life Structure: Plans, Journeys, and Routines

Tasks in iAlly do not float in a void. Every task belongs to a life domain, and domains are organised through Plans (high-level buckets per area of life), Journeys (time-bound goals with milestones), and Routines (recurring practices with streak tracking and flexible recurrence logic).

This structure was a deliberate design choice. It forces the question: *what is this task actually in service of?* Answering that question — even implicitly, through domain assignment — turns a flat checklist into a map of your life.

Routines support daily, weekly, monthly, and custom intervals, including advanced options like "third Friday of the month" or "every weekday except bank holidays." Each routine tracks its own streak, break history, and recovery count.

### Lumina — The AI Companion

Lumina is the intelligence layer of iAlly. It is conversational (you can chat with it to capture tasks, ask questions about your goals, or explore what you have been working on) but its most distinctive capability is *proactive* rather than reactive.

A background task runs every six hours. It analyses your full task and goal history to:

- **Detect goal drift** — Flags when journeys have had no supporting task activity recently, signalling that important goals are being crowded out by daily urgency
- **Surface energy patterns** — Identifies whether you are consistently avoiding high-energy work and suggests when to schedule it based on your historical completion patterns
- **Catch domain silence** — Alerts you when a life area (Health, Relationships) has had zero activity over a meaningful period
- **Track milestone proximity** — Reminds you when a journey is close to completion and nudges you to finish rather than plateau
- **Generate a daily briefing** — A morning card summarising your key focus for the day, active insights, and personalised nudges grounded in recent data

Lumina supports multiple inference providers — Claude (Anthropic), GPT-4o, Google Gemini, and Mercury-2 — selectable at runtime. API keys are stored in the iOS Keychain and never leave the device in plaintext.

### Growth Mindset Engine

Most productivity apps measure success in completions. iAlly measures it in resilience.

The Growth Mindset Engine tracks a richer picture: how often you miss tasks and routines, how quickly you recover when you do, whether you tend to gravitate toward easy small tasks while deferring harder ones, and how your energy distribution across high, medium, and low effort work shifts over time.

A task completed late — after being overdue — earns a recovery point. A routine streak broken and then rebuilt counts as growth, not failure. This framing was a deliberate values decision: the system should reinforce coming back, not punish stopping.

### Privacy and Security

iAlly handles data that is genuinely personal — daily routines, life goals, reflections. Several decisions were made specifically around this:

- All task, goal, and routine data is stored locally using SwiftData with optional iCloud sync. Nothing is sent to a server by default.
- A **PII Scrubber** strips personally identifiable information from any data sent to AI providers — names, locations, and other sensitive content are redacted before inference calls are made.
- Biometric authentication (Face ID / Touch ID) locks the app, with a one-hour idle re-lock to prevent casual shoulder-surfing.
- Monthly token budget caps prevent unexpected API spend, with visible usage tracking in-app.

---

## Design Thinking & Key Decisions

**Why 8 fixed life domains rather than user-defined categories?**
Early thinking pointed toward full flexibility — let users define their own domains. But this creates a hidden cost: users have to decide what categories matter to them before they start using the app, which is cognitively expensive and leads to inconsistent organisation. Fixed domains remove that friction. They also enable Lumina to reason meaningfully about domain balance — it can only detect that Health has been neglected if it knows what Health is. The tradeoff is reduced flexibility for users with unusual life structures, which I accept as a reasonable constraint.

**Why proactive intelligence over a better search or filter?**
Most productivity apps invest in helping users find things. iAlly invests in surfacing things users did not know they needed to see. These are different problems. Search requires intention — you have to know what to look for. Proactive nudges work precisely when you do not. The background engine was the hardest feature to get right because it required careful calibration: too many nudges and they become noise, too few and the system feels inert. I spent significant time on the threshold logic for each nudge type.

**Why a resilience-based Growth Mindset Engine rather than a standard streak tracker?**
Streak trackers punish interruption. A dancer who misses three days of practice and then practises every day for a month has their streak reset to 11 days — the system erases the month to emphasise the gap. This is the opposite of a growth mindset. iAlly's engine tracks streak breaks and recoveries separately, giving weight to the recovery as a positive signal. The design principle: the system should model how a good coach thinks, not how a scoreboard thinks.

**Why a PII Scrubber rather than simply advising users not to enter sensitive data?**
Because users cannot consistently self-censor when entering tasks and notes. Telling someone "don't write personal details" is not a privacy strategy — it is placing a burden on the user that the system should carry. The scrubber runs automatically before any data leaves the device for inference, so privacy is structural rather than advisory.

**Why support multiple AI providers?**
Single-provider dependency creates fragility. If a provider changes pricing, degrades quality, or becomes unavailable, the app breaks for every user. An inference router that supports Claude, GPT-4o, Gemini, and Mercury-2 keeps iAlly resilient and allows users to choose based on cost, speed, or personal preference. The architecture makes adding new providers straightforward.

---

## Iteration & Development

**v1 — Core task structure:** Tasks, Plans, and the 8-domain framework. Validated that structured life organisation across domains was more useful than flat lists. No intelligence layer yet.

**v2 — Journeys and Routines:** Added goal tracking with milestones and recurring practices with streak logic. The app started to feel like a life management system rather than just a task manager. This was when the structure-first principle became clear: intelligence without structure produces noise; structure without intelligence produces a more organised whiteboard.

**v3 — Lumina (Capture and Knowledge):** Added the conversational AI layer — chat-based task capture, semantic memory search, and knowledge note-taking indexed for future retrieval. Addressed the core capture friction: getting things into the system quickly without breaking context.

**v4 — Proactive Intelligence and Personal Security:** The most significant iteration. Added the background intelligence engine, daily briefing, Growth Mindset analytics, PII scrubbing, biometric lock, and token budget management. This version answered the original question the project was built around: can software notice what you are missing before you do?

---

## Challenges & What I Learned

**Designing proactive nudges without creating noise.** The first version of the intelligence engine generated too many nudges — every detected pattern surfaced immediately. The result was alert fatigue within days. I had to rethink the problem: not "what can I detect?" but "what is worth surfacing, and when?" Each nudge type now has its own threshold logic, cooldown period, and urgency scoring. The lesson was that the hardest part of building intelligent software is not the detection — it is the prioritisation.

**The inference router had to be more than a switch statement.** Supporting multiple AI providers sounds straightforward — swap the endpoint and adjust the payload format. In practice, each provider has different rate limits, context window constraints, streaming protocols, and error behaviours. The router had to handle fallback gracefully, manage token budgets per provider, and present a consistent interface to the rest of the app regardless of which backend was in use. This was a deeper architectural problem than it first appeared.

**SwiftData and CloudKit sync revealed cascading edge cases.** Offline queue operations that looked correct in isolation caused data conflicts when replayed during sync. Handling these edge cases — especially cascade deletes across related entities (Journey → Milestones → Tasks) — required careful reasoning about the order of operations and conflict resolution strategy. The lesson: distributed data systems are hard even at small scale, and the edge cases only appear when you stress the sync layer under realistic conditions.

**Calibrating the Growth Mindset metrics required values decisions, not just engineering decisions.** Deciding how much weight to give to a recovery versus a fresh streak, or how many missed days constitute a meaningful break versus normal variation, required reasoning about what the system was trying to reinforce. These were not technical questions. They required stepping back and asking: what kind of relationship with one's goals is this system trying to cultivate? That was an unexpectedly philosophical dimension of what I had assumed was a data problem.

---

## What I Learned

- Intelligence requires structure. Proactive insights are only useful if the underlying data is organised around meaningful categories — domain-blind analysis produces generic observations.
- Simplicity and power are not opposites, but they require deliberate trade-off decisions at every step. Every feature added was weighed against whether it made the core experience clearer or noisier.
- Privacy should be structural, not advisory. Building PII scrubbing into the data pipeline rather than relying on user discipline was the right call — and it required treating privacy as an engineering constraint from the start, not a feature added at the end.
- The hardest design problems are about what to leave out. The backlog for iAlly is long. Every decision not to implement something was as deliberate as every decision to build it.

---

## Future Directions

**Shared accountability mode:** An opt-in feature where users can share selected journey progress with a trusted person — a mentor, accountability partner, or friend — without exposing the full task log. Privacy-preserving progress sharing rather than full transparency.

**On-device inference:** As Apple Silicon in iOS becomes capable enough for small language models, replacing cloud inference with fully local models for at least the lighter Lumina tasks (task categorisation, nudge generation) would eliminate API dependency entirely and further strengthen the privacy guarantee.

**Adaptive nudge learning:** Currently, nudge thresholds are fixed. A more sophisticated version would learn from user behaviour — which nudges get acted on, which get dismissed — and adjust its sensitivity per user over time.

**Cross-app integration layer:** Many users already have data in Apple Health, Apple Calendar, and Apple Notes. An integration layer that pulls signals from these sources into iAlly's intelligence engine would give Lumina a richer picture of the user's life without requiring manual re-entry.

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI Framework | SwiftUI |
| Data Persistence | SwiftData (Apple's modern ORM with typed queries) |
| Cloud Sync | CloudKit (optional iCloud sync) |
| AI Inference | Claude API (Anthropic), OpenAI GPT-4o, Google Gemini 1.5 Pro, Mercury-2 — runtime-selectable |
| Semantic Memory | PAIService (local macOS server: Ollama + GRDB SQLite for vector search) |
| Background Processing | BackgroundTasks (BGAppRefreshTask — proactive intelligence engine) |
| Home Screen Widgets | WidgetKit (small, medium, large) |
| Siri Integration | AppIntents (task capture, daily briefing, routine completion) |
| Calendar Sync | EventKit |
| Biometric Auth | LocalAuthentication (Face ID / Touch ID) |
| Security | iOS Keychain (API key storage), custom PII Scrubber |
| State Management | Swift Observation framework + Combine (SSE streaming) |
| Architecture | MVVM with service layer (40+ singleton services, 24 SwiftData entities) |
| Testing | XCTest UI automation (189 test files, 50+ automated scenarios) |

No third-party dependencies. All intelligence runs either on-device or through user-supplied API keys.

---

## Demo

> *Screenshots and a walkthrough video will be added here.*

**Key screens to show:**
1. Today view with Daily Briefing card — Lumina's morning intelligence summary
2. Journey detail with milestone progression
3. Lumina chat — conversational task capture and semantic search
4. Growth Mindset analytics — resilience scoring, energy distribution, streak recovery
5. Proactive nudge — goal drift detection in context

---

*Built by Darshini S P — because the gap between intention and action deserved a smarter solution than another to-do list.*
