# AI Dev Team — Overview and Principles

## Why this exists

AI-assisted development without structure degrades quickly: context is lost between sessions, one model misses bugs another would catch, and it's unclear what's been done or why decisions were made.

The AI dev team solves three problems:

1. **Context loss** — all context lives in the Knowledge Base (KB), not in the agent's memory. New session: read the KB and pick up exactly where you left off.
2. **Single-model blind spots** — audits always run two independent models in parallel (Claude + Codex). They find different problems and together surface false positives.
3. **Diffuse responsibility** — each role does one concrete thing and doesn't overlap with others.

---

## Team roles

| Role | Model | Responsibility |
|------|-------|----------------|
| **Lead** | user's session | Orchestrates the team, makes decisions, communicates with the developer |
| **Librarian** | Claude Sonnet | Manages the KB: search on request, create documents with correct format, update MOC indexes |
| **Developer Senior** | Claude Opus | Complex tasks: new abstractions, Soroban/contracts, ambiguous scope, security-sensitive code |
| **Developer Middle** | Claude Sonnet | Clear scope following existing patterns: new endpoint, tests, function by example |
| **Developer Codex** | GPT-5.4 xhigh | **Default.** Saves Claude tokens (corporate subscription). Quality comparable to Senior given a clear spec. Reads files directly by path. |
| **Auditor** | Claude Opus + Codex | Parallel review: two modes × two vendors = 4 independent perspectives |
| **Verifier** | Claude Haiku | Runs tests, checks for regressions. Never writes code. |

### Choosing a developer

```
Codex           ← default; spec is explicit and file paths are listed
Developer Middle ← Codex overhead not worth it (small in-session edit)
Developer Senior ← wide codebase exploration needed, or ambiguous scope
```

The more detailed the spec (with explicit file paths), the closer Codex performs to Senior quality.

### KB access division

- **Only Librarian creates new KB documents** and updates MOC indexes
- Other agents **read KB directly** via known paths
- Developer **updates the spec checklist directly** during implementation
- Auditor writes findings directly to KB (two output files per audit)

---

## KB structure

Each project has its own subfolder under `repos/`.

```
KB (Obsidian vault):
└── repos/
    └── <project>/
        ├── design/
        │   └── YYYY-MM-DD-<slug>.md               ← feature spec
        ├── security/
        │   ├── YYYY-MM-DD-<slug>-findings.md       ← findings (accumulates across iterations)
        │   └── YYYY-MM-DD-<slug>-workdoc-iterN.md  ← per-iteration work log (new file each time)
        ├── postmortems/
        │   └── YYYY-MM-DD-<slug>.md               ← incident postmortems
        └── research/
            └── YYYY-MM-DD-<slug>.md               ← investigations, models, exploratory work
```

**design/spec** — living document: Context, Current State, Design, Implementation Checklist, Branch, Verification, Log.

**findings.md** — accumulates across audit iterations. Statuses: `OPEN / FIXED / ACCEPTED / DEFERRED / INVALID`.

**workdoc-iterN.md** — auditor's working draft for a specific iteration. New file each time — previous iterations preserved for reference but not auto-loaded into context.

**research/** — free-form with YAML frontmatter. Subtypes: `incident-investigation`, `math-model`, `competitive-analysis`, `exploration`. Statuses: `ACTIVE / CONCLUDED / ARCHIVED`. Use when: too early for a postmortem (still investigating), no clear spec yet (mathematical model, competitive analysis), purely exploratory work.

---

## Workflow: feature lifecycle

```
Phase 1 — Planning
  [Lead] searches KB for relevant context ──────────→ KB context summary
         reads codebase ──────────────────────────→ codebase summary
         writes spec draft → saves to KB/repos/<project>/design/
         if needed: [Librarian] updates MOC
  ──── STOP: developer approves the spec ────

Phase 2 — Implementation
  [Developer*] reads spec → feature branch → implements per checklist
               updates checklist directly → small logical commits

  * Codex by default; Senior/Middle if wide exploration or ambiguous scope needed

Phase 3 — Verification
  [Verifier] cargo test / pytest / npm test → pass/fail report
  FAIL → back to Developer; PASS → continue

Phase 4 — Audit (parallel)
  [Auditor-logic]    ──────────────  [Auditor-security]
  (Claude + Codex)                   (Claude + Codex)
  4 independent perspectives → saves to KB:
    repos/<project>/security/<slug>-findings.md       (merge)
    repos/<project>/security/<slug>-workdoc-iterN.md  (new file)
  ──── STOP: developer decides fix / accept / defer per finding ────

Phase 5 — Fix
  [Developer*] applies selected fixes → commits to same branch

Phase 6 — Re-audit (diff only)
  Repeat Phase 4; findings.md updated, workdoc-iter(N+1).md created

Phase 7 — Hand-off
  [Lead] presents commit list → on confirmation: git push + gh pr create
```

---

## Git conventions for developers

- Work in a **feature branch**: `feature/YYYY-MM-DD-<slug>` (or as specified in spec)
- Base branch is `master` unless spec says otherwise (confirm with user if unclear)
- **Small logical commits** — one commit per checklist step
- Commit messages: concise, imperative mood. No "Co-authored-by" lines.
- Push and PR — user (Lead) only

---

## Iteration and changes

Since all context lives in KB, any change is just resuming from the right point:

- **Don't like the design** → edit spec in Obsidian → Lead rewrites the relevant sections → approve → Developer continues
- **Don't like a specific step** → tell Lead: "rework step 3, need X" → Developer spawns only for that step
- **New session** → `/feature continue KB/repos/<project>/design/<spec>.md` → agent reads spec, knows status, continues without context recovery

**Two mandatory manual checkpoints:**
1. After Phase 1 — approve the spec (no code is written without approval)
2. After Phase 4 — fix/accept/defer each finding

---

## Dual-model audit: why it matters

A single model systematically misses certain classes of problems. Two vendors in parallel:

| Confidence | Condition | Action |
|------------|-----------|--------|
| **HIGH** | both Claude and Codex found it | definitely fix |
| **REVIEW** | only one found it | verify manually — possible false positive |

Two audit modes run as two parallel agents:
- `logic` — correctness, edge cases, conventions, performance
- `security` — fund loss, key handling, tx signing, overflow, slippage, MEV

4 independent perspectives on every feature.

---

## KB discovery

Agents find the KB automatically:

1. Check memory for a known KB path for the current project
2. Search for a sibling directory with "knowledge" in the name (next to the project)
3. **Always confirm with the developer** before using
4. If not found — ask where to create one (Obsidian vault format)

After confirmation the path is saved to memory — not asked again in future sessions.
