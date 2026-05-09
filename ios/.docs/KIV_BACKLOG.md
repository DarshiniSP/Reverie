# iAlly — KIV Backlog
> Items deferred for later. Review before each sprint cycle.
> Last updated: 2026-03-04 (Quick Notes done; Lumina Profile added to KIV)
> **Active project:** `/Users/irigamdeveloper/Projects/PAI/iAlly/ios/` (always use this, not the standalone)

---

## Item 1 — Lumina: Journey, Plan & Milestone Creation

**Goal:** Allow users to create Journeys, Plans, and Milestones entirely through Lumina chat, without touching the manual UI forms.

**Tasks:**
- Add `JOURNEY_PROPOSAL`, `PLAN_PROPOSAL`, `MILESTONE_PROPOSAL` markers to `LuminaConversationService`
- Build confirmation cards (`JourneyProposalCard`, `PlanProposalCard`, `MilestoneProposalCard`) in SwiftUI
- Add `confirmCreateJourney()`, `confirmCreatePlan()`, `confirmCreateMilestone()` handlers
- Update Lumina system prompt with new marker rules and examples
- Wire up SwiftData saves for each entity type

**Known bugs to fix at same time (observed 2026-03-02):**
- [ ] **Confirmation sends as user message** — Tapping Confirm on a `TASK_PROPOSAL` card appends
  `"✓ Task created: '...'"` as a user-role message and sends it to Lumina, triggering an
  unnecessary response. Fix: append as a local `.system` role bubble (display only, never sent
  to the model). Check `confirmCreateTask()` handler in `LuminaConversationService`.
- [ ] **Duplicate confirmation message** — The same `"✓ Task created"` text appears twice at the
  same timestamp. Likely appended to `messages` in two places (feedback path + stream path).
  Audit all call sites of `messages.append` in the confirm flow.
- [ ] **Lumina echoes past tense** — Lumina responds "Task created: Is there anything else..."
  because it receives the confirmation text as a user message (flows from bug #1).
  Fixing bug #1 eliminates this automatically.

**Dependencies:** None
**Effort:** Medium (1–2 sessions)

---

## ~~Item 2 — More Tab & Settings Cleanup~~ ✅ DONE (2026-03-02)

**Files changed:** `PAI/iAlly/ios/iAlly/Views/MoreView.swift`, `SettingsView.swift`

- ✅ Removed "Insights" duplicate — "AI Insights" is now the single analytics entry
- ✅ Renamed "Completed Tasks" → "Task History"
- ✅ Moved FAQ, About iAlly, Recommend to Friend → Settings / About section
- ✅ Removed "Siri & Voice" from More tab → moved to Settings / Integrations
- ✅ "Notification Test" wrapped in `#if DEBUG` — hidden in release/TestFlight builds
- ✅ "Demo Data" section hidden entirely once deleted (no more disabled ghost buttons)

---

## Item 3 — Architecture Refactor: Lumina as Primary Touchpoint

**Goal:** Make Lumina the single entry point for all user inputs. UI is used only for confirmation. Remove the Mac PAIService bottleneck from the critical chat path.

### Phase 1 — Expand Lumina Proposal Types *(prerequisite: Item 1)*
- Add `TASK_UPDATE`, `TASK_COMPLETE`, `TASK_DELETE` action markers
- Add Journey / Plan / Milestone proposals (same as Item 1)
- All proposal types show a confirmation card before any SwiftData write

### Phase 2 — Direct Claude API from iOS ✅ DONE (2026-03-02)
- ✅ `LuminaInferenceProvider` protocol + `InferenceProviderID` enum
- ✅ `ClaudeInferenceClient` — direct Anthropic API (SSE streaming)
- ✅ `OpenAIInferenceClient` — GPT-4o (reused for Mercury)
- ✅ `GeminiInferenceClient` — Gemini 1.5 Pro (Google GenerateContent SSE)
- ✅ `MercuryInferenceClient` — Mercury-2 (Inception Labs, OpenAI-compatible)
- ✅ `LuminaInferenceRouter` — singleton, UserDefaults-persisted provider selection
- ✅ `AIProviderSettingsView` — per-provider API key input + Test button
- ✅ `LuminaConversationService` wired to router (not PAIService)
- ✅ `SettingsView` — "Lumina AI" → AI Provider link + renamed "PAIService Memory" section
- PAIService no longer on critical inference path — memory/embeddings only

### Phase 3 — Full CRUD via Lumina
- All task/routine/journey create, edit, complete, delete flows through Lumina
- UI used only for review and confirmation
- PAIService handles memory search (Ollama embeddings + GRDB SQLite) as a background service

### Fix IP Fragility *(short-term, do first)*
- Set DHCP reservation in router for Mac's MAC address → locks IP to `192.168.0.5` permanently
- OR migrate PAIService to a cloud host — removes local Mac dependency entirely

**Dependencies:** Item 1 (Phase 1), network access
**Effort:** Large (3–5 sessions across all phases)

---

## Item 4 — Privacy & Security: Guardrails Before Cloud Inference

**Goal:** Ensure no sensitive personal data leaves the device unguarded before reaching cloud LLMs. Comply with basic data privacy principles.

### Critical Gaps Found (from code audit 2026-03-02)
| Gap | Risk | File |
|---|---|---|
| No PII scrubbing before Claude API call | Task names, personal notes, IDs sent raw to Anthropic | `ClaudeProvider.swift` |
| Auth token OFF by default | Any device on same WiFi can call PAIService | `ServerConfig.default` (authToken: nil) |
| Local network unencrypted (plain HTTP) | Conversations intercepted on WiFi | `PAIServerCommand.swift` |
| Memory DB not encrypted at rest | SQLite file readable if Mac is compromised | `MemoryDatabase.swift` |
| No data retention policy | Conversation history stored indefinitely | `MemoryConfig` (minPruneAgeHours: 168 only) |

### Tasks — Short-term (do before any public/beta release)
- [ ] **Enable auth by default**: Generate random Bearer token at PAIService first launch, store in Keychain, share to iOS via Settings QR code or copy-paste
- ✅ **PII scrubbing on iOS** — `PIIScrubber` + `PIICatalogManager` added (2026-03-02):
  - Universal: phone, email, credit card, DOB, passport, IP, street address
  - Regional: 12 jurisdictions (US/CCPA, GB, AU, IN, SG, BR, CA, ZA, DE, FR, AE, MY)
  - Remote catalog from GitHub (7-day refresh), embedded Swift constant fallback
  - `LuminaConversationService` scrubs user messages before sending to any provider
  - Settings → Privacy & Security: toggle per-pattern, custom regex, audit log
- [ ] **Add privacy notice in app**: Clearly state "Conversations are processed by [selected AI provider]" in Settings / About

### Tasks — Medium-term
- [ ] **Encrypt SQLite memory DB** using SQLCipher — prevents plaintext exposure if Mac disk is accessed
- [ ] **Add data retention controls**: User-configurable memory expiry (e.g. "keep memories for 30/90/180 days or forever")
- [ ] **Add a "What does Lumina know about me?" screen** — shows stored memories, lets user delete specific ones

### Tasks — Long-term (Phase 2 of Item 3)
- ✅ **Direct provider API from iOS** — done (Item 3 Phase 2). iPhone → provider HTTPS directly. PAIService no longer handles chat.
- [ ] **Local-only mode option** — let user toggle to Ollama-only inference (full local, nothing to cloud). Slower but fully private.

**Dependencies:** None for short-term tasks; Item 3 Phase 2 for long-term tasks
**Effort:** Short-term = Small (1 session) | Medium-term = Medium (2 sessions) | Long-term = see Item 3

---

## Item 5 — Lumina Profile (KIV — needs more design thinking)

**Goal:** A structured "About Me" profile that Lumina always knows about the user — name, family,
work context, preferences, and constraints. Always injected into the system prompt deterministically.

**Design decisions still open:**
- What fields are structured vs. free-text?
- What is the cap before context window becomes a problem? (e.g. >20 entries)
- How does the user know Lumina is using their profile in a response?
- Does profile replace or supplement PAIService memory?

**Agreed principle:** Profile is explicit + user-maintained. Not auto-captured. Not semantic retrieval.
Think ChatGPT Custom Instructions but structured by life domain (Personal / Work / Preferences / Constraints).

**Dependencies:** Quick Notes ✅ done first

---

## Completed Items

- **Quick Notes** ✅ 2026-03-04 — `LuminaNote` SwiftData model, `QuickNotesView` (list + compose + promote sheet),
  promote actions: Create Task, Add to Knowledge (with type picker), Ask Lumina (pre-fills input), Archive.
  `saveAsNote()` in QuickCaptureView now writes to SwiftData instead of `PAIMemoryBridge`.
- **Item 2 — More Tab & Settings Cleanup** ✅ 2026-03-02 — `MoreView.swift` + `SettingsView.swift` in PAI project
- **Item 3 Phase 2 — Multi-Provider Inference** ✅ 2026-03-02 — 7 new files, Claude/OpenAI/Gemini/Mercury direct from iOS
- **Item 4 Short-term PII Scrubbing** ✅ 2026-03-02 — `PIIScrubber`, `PIICatalogManager`, 12 regional catalogs, Settings UI
