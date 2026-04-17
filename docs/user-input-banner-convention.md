# User-input prompt banner convention

When a skill flow stops and waits for the user to make a decision, the
presentation must be visually unmissable. Users routinely return to an
active chat mid-flow, skim the latest activity, and scroll past buried
inline questions — the session then stalls for minutes to hours while
the user assumes the agent is still working.

This document is the single source of truth for the banner grammar. Every
skill's `SKILL.md` that prompts the user at a real decision fork MUST
quote this convention and apply the banner exactly as described below.

## Banner grammar

Two banner variants exist. The exact bytes matter — smoke assertions grep
the literal heading string, including the U+23F8 pause glyph (⏸).

- `## ⏸ AWAITING YOUR INPUT` — the generic banner. Use for every real
  decision fork except the HARD GATE spec-approval moment.
- `## ⏸ APPROVAL REQUIRED` — reserved for the feature-skill HARD GATE
  spec approval. There is exactly ONE of these repo-wide; adding it
  elsewhere is a drift failure caught by smoke.

## Required structure

Every banner placement MUST follow this structural form, in order:

1. A horizontal rule line — exactly `---` on its own line, immediately
   above the banner heading.
2. The banner heading — one of the two variants above, on its own line.
3. Body prose — one or more paragraphs or a list that explains the
   options the user is choosing between.
4. A trailing bold decision question on its own line, using the form
   `**…?**`. The question line is what the user answers. The smoke
   assertion `banner-trailing-bold-present-each` scans up to 15 lines
   below the banner heading for this pattern; bare banners without a
   trailing bold question fail.

The leading `---` ruler is what makes the banner visually unmissable in
rendered markdown — it creates a hard break above the heading so the
banner cannot blend into surrounding prose.

## When to apply

Apply the banner at every **real fork** in a skill flow. A real fork
means the agent genuinely cannot proceed until the user picks an
outcome. Examples:

- A/B/C multi-way selection (e.g. "investigate deeper / accept / pivot").
- Destructive confirmation (e.g. typed `discard` to delete a spec).
- HARD GATE approval (spec-approval moment — use `APPROVAL REQUIRED`).
- Binary y/n gates where the No branch blocks progress.
- Free-form text input that the next step depends on.

## When NOT to apply

Do NOT apply the banner on status updates. A status update is any
message where the flow is going to continue without the user's input —
"background agent running, waiting for notification", "spec review
passed, moving to implementation", "verify passed, moving to hand-off".
These are single-outcome notifications, not decision forks.

Slapping the banner on status updates trains the user to ignore it,
which defeats the purpose. The signal only works if it is reserved for
genuine asks. Smoke assertions explicitly check that the known
status-update sites in `skills/feature/SKILL.md` (post-audit message and
post-verify hand-off announcement) do NOT carry the banner and do NOT
carry question-framing like `Ready to proceed?` or `Proceed to Hand-off`.

Phase 0 KB-discovery prompts (sibling-confirm, `.ai-dev-team.yml` save
y/n) are explicitly OUT of scope for this convention — they fire at
most once per repo during installer-time setup, have different
ergonomics (user is fresh, attentive, running `/feature new` for the
first time), and different failure cost. They may adopt the banner
later; this convention does not retrofit them today.

## Positive example

A well-formed banner placement in a SKILL.md fork. Note the `---` ruler
immediately above the heading, the body explaining the choice, and the
trailing bold decision question.

```markdown
---

## ⏸ APPROVAL REQUIRED

The draft spec is ready for review at `<spec_path>`.

- Approve → implementation begins immediately with developer-senior.
- Reject → return to drafting with your feedback.

**Approve to proceed?**
```

The same structure applies to the generic variant:

```markdown
---

## ⏸ AWAITING YOUR INPUT

Three options for the async result follow-up:

- `investigate-deeper` — re-open the investigation with new questions.
- `accept-and-proceed` — use the current result as-is.
- `pivot` — abandon this line and start a new investigation.

**Which path?**
```

## Negative example

This is what you must NOT do — a status-update dressed up as a real
fork. The flow is about to continue without user input; there is no
decision here. Adding a banner trains the user to ignore it.

```markdown
---

## ⏸ AWAITING YOUR INPUT

Spec review passed — the spec is saved to KB. Moving to implementation.

**Ready to proceed?**
```

Why it's wrong: "Ready to proceed?" has a single outcome — the agent
proceeds regardless. The banner framing implies the user has a real
choice, so they feel obligated to answer, and when they return later
they mistake the completed status for an open prompt (or vice-versa).
The correct form is plain status prose with no banner and no question:

```markdown
Spec review passed — the spec is saved to KB. Moving to implementation.
```

## Glyph fallback

The pause glyph (U+23F8) is widely supported across modern terminals
and markdown renderers. In truly ancient terminals it may fall back to
a substitute character, but the uppercase heading + `---` ruler remain
unmissable. This convention mandates the glyph; fallback rendering is
out of scope.
