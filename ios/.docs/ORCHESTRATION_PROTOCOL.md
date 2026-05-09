# SDLC ORCHESTRATION PROTOCOL
**Purpose:** Ensure consistent agent behavior and maintain documentation integrity.

> **SDLC:** [Protocol](ORCHESTRATION_PROTOCOL.md) | [PRD](PRD.md) | [System Map](SYSTEM_MAP.md) | [Test Suite](TEST_SUITE.md) | [Context](CONTEXT_BUFFER.md) | [Changelog](CHANGELOG.md)

---

## 1. THE SOURCE OF TRUTH

All project knowledge resides in the `.docs/` directory:

| File | Purpose | Update Frequency |
|------|---------|------------------|
| `PRD.md` | Business logic, requirements, implementation status | When features change |
| `SYSTEM_MAP.md` | Architecture, file structure, data flows | When structure changes |
| `TEST_SUITE.md` | Test cases, validation status, execution guide | After test runs |
| `CONTEXT_BUFFER.md` | Active memory, current state, next steps | After every task |
| `CHANGELOG.md` | Historical record of all changes | After every release/fix |
| `ORCHESTRATION_PROTOCOL.md` | This file - agent operating rules | Rarely |

---

## 2. PRE-FLIGHT CHECK (Mandatory)

**Before responding to any user request or starting a new conversation:**

1. **Read** `CONTEXT_BUFFER.md` to understand current state
2. **Summarize** what was accomplished and what's next
3. **Verify** if the requested change conflicts with `PRD.md`

**Example:**
```
User: "Add a new feature X"
Agent: [Reads CONTEXT_BUFFER] "I see we just completed gap analysis. 
       [Reads PRD Section 5] Feature X is not in the PRD. 
       Should I update PRD.md first?"
```

---

## 3. AMENDMENT RULES (Critical)

### DO NOT:
- ❌ Create new requirement files for small changes
- ❌ Create duplicate documentation (e.g., `GAP_ANALYSIS.md` when PRD exists)
- ❌ Leave findings in artifact folder without integrating to `.docs/`

### ALWAYS:
- ✅ Amend existing files using clear headers (e.g., `## Update: [Date]`)
- ✅ Update `PRD.md` FIRST before changing code if business logic changes
- ✅ Integrate ad-hoc analysis into appropriate `.docs/` file:
  - Gap Analysis → `PRD.md` Section 5
  - Test Results → `TEST_SUITE.md`
  - Architecture Changes → `SYSTEM_MAP.md`

---

## 4. POST-ACTION HEARTBEAT (Mandatory)

**Upon completion of any task, automatically update:**

1. **TEST_SUITE.md** - If tests were run or test requirements changed
2. **CONTEXT_BUFFER.md** - Always update with:
   - What was accomplished (add to Recent Accomplishments)
   - Current blockers (update Active Blockers section)
   - Specific "Next Step" for the human (update Next Steps section)
3. **CHANGELOG.md** - If code or features changed

---

## 5. MAINTENANCE MODE

**When a bug is reported:**

1. **Cross-reference** with `PRD.md` Section 5 (Implementation Status)
2. **Determine:** Is this a bug or a missing feature?
   - **Bug:** Fix code, update `CHANGELOG.md`
   - **Missing Feature:** Update `PRD.md` Section 5 first, then implement
3. **Update** `CONTEXT_BUFFER.md` with fix status

---

## 6. ARTIFACT FOLDER USAGE

**Temporary Working Documents Only:**
- Draft analysis, work-in-progress plans
- **Must be integrated** into `.docs/` before task completion
- **Never leave** important findings orphaned in artifact folder

---

## 7. VERSION CONTROL & GITHUB PROTOCOL

### Branching Strategy
- **main:** Production-ready code. Matches `CHANGELOG.md` releases.
- **feature/[name]:** New features (e.g., `feature/archive-ui`).
- **fix/[name]:** Bug fixes (e.g., `fix/tag-counter`).
- **docs/[name]:** Documentation updates (e.g., `docs/sdlc-refinement`).

### Commit Message Convention (Semantic)
Format: `type(scope): description`

- **feat:** New feature (corresponds to `Added` in Changelog)
- **fix:** Bug fix (corresponds to `Fixed` in Changelog)
- **docs:** Documentation only
- **style:** Formatting, missing semi-colons, etc.
- **refactor:** Code change that neither fixes a bug nor adds a feature
- **test:** Adding missing tests or correcting existing tests
- **chore:** Maintanance, config changes

**Example:**
`feat(archive): implement archive service UI integration`

### PR Protocol
1. **Update Docs First:** Ensure `PRD.md` matches the code changes.
2. **Pass Tests:** Run `test_suite` for the affected scope.
3. **Update Changelog:** Add entry under `[Unreleased]`.

---

## 8. DOCUMENT VERSIONING


**When updating `.docs/` files:**
- Use headers like `## Update: 2025-12-22` for major changes
- Update `**Last Updated:**` timestamp at top of file
- Increment version number in `PRD.md` if business logic changes

---

---

## 9. DEFINITION OF DONE (Crucible of Truth)

**You are NOT DONE until you have:**

1. [ ] **Updated CONTEXT_BUFFER.md:**
   - Logged the accomplishment?
   - Updated "Next Steps"?
   - Updated "Active Blockers"?
2. [ ] **Updated TEST_SUITE.md:** (If tests ran)
3. [ ] **Updated CHANGELOG.md:** (If code changed)
4. [ ] **Checked task.md:** Marked item as complete?

**CRITICAL RULE:**
> You MUST NOT call `notify_user` to signal task completion until **ALL** of the above are true.
> If you find yourself writing "I have updated X, Y, Z" in the message, **STOP** and verify you actually did it.

---

**This protocol ensures no context loss across conversations and maintains a Single Source of Truth.**
