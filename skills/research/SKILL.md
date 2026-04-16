---
name: research
description: "Research-note driver. Create, continue, conclude, or archive KB research notes (incident-investigation, math-model, competitive-analysis, exploration). Notes live at <kb>/repos/<project>/research/."
argument-hint: "new <title> | continue [path] | status [--all] | conclude [path] | archive [path]"
---

# Research Skill

Research notes are free-form exploration documents. Unlike `/feature`, there is no implementation checklist and no audit — just KB-backed notes that persist across sessions. This skill is the driver for creating and managing them; the Librarian handles the actual writes.

## Modes

Parse `$ARGUMENTS`:

| Input | Mode | Action |
|-------|------|--------|
| `new <title>` | **New** | Ask subtype → create note → report path |
| `continue [path]` | **Continue** | Resume an existing note (bare path also works) |
| `status [--all]` | **Status** | List ACTIVE notes (default) or everything with `--all` |
| `conclude [path]` | **Conclude** | Append conclusion block; flip `status: CONCLUDED` |
| `archive [path]` | **Archive** | Flip `status: ARCHIVED`; soft — reverse by editing frontmatter |

---

## Phase 0: KB Discovery (all modes)

Identical to `/feature` Phase 0 — re-use the same config chain and legacy fallback:

1. Determine `project` and `kb_path` via config before using legacy discovery.
2. Read `.ai-dev-team.local.yml` first; it overrides `.ai-dev-team.yml`.
3. Read `.ai-dev-team.yml` second. Fallback anchor: `.ai-dev-team.yml → memory → sibling heuristic → ask`.
4. Supported config shape is shared with `/feature` — see `skills/feature/SKILL.md`.
5. `per-field resolution: local → shared → memory → sibling → ask, continue on per-file parse error`.
6. On parse error / missing field → warn once, continue down the chain. Do not abort the session.
7. When config is valid, skip confirmation and do not write to memory.
8. Fallback to memory (`reference_kb_<project>.md`), then sibling directory containing "knowledge", then ask.
9. After legacy discovery succeeds and `.ai-dev-team.yml` is absent, prompt: **"Save `kb_path` and `project` to `.ai-dev-team.yml` so future sessions skip discovery? [Y/n]"**. Same behaviour as `/feature`.

---

## New: Create a research note

### Step 1 — Subtype

Ask the user:

> **Subtype?** (default: `exploration`)
> 1. `incident-investigation` — facts-first analysis of a production incident before a postmortem
> 2. `math-model` — formulas, derivations, modeling spreadsheets
> 3. `competitive-analysis` — market / vendor / protocol comparison
> 4. `exploration` — open-ended investigation without a clear destination

Accept the number or the slug. Default if user just hits enter.

### Step 2 — Slug

Compute slug:

```
<YYYY-MM-DD>-<lowercased-title with spaces → hyphens, stripped of punctuation>
```

Truncate the title portion to ~50 chars. If the resulting file already exists, append `-2`, `-3`, … until unique.

### Step 3 — Create the note

Target path: `<kb_path>/repos/<project>/research/<slug>.md`. Create the `research/` directory if missing.

Use the template from `references/research-template.md`. Frontmatter:

```yaml
---
title: <the given title>
project: <project>
type: research
subtype: <selected subtype>
status: ACTIVE
created: YYYY-MM-DD
tags: [research, <project>, <subtype>]
---
```

Write a stub Context paragraph if the user supplied any framing along with the title; otherwise leave it blank with a `<!-- context here -->` hint.

Spawn **Librarian** only if you need to update MOC indexes afterward.

### Step 4 — Report

> Research note created at `<path>` (subtype `<subtype>`, status `ACTIVE`).
> Open it and start writing.

---

## Continue mode

1. Run Phase 0.
2. Read the note. Inspect `status`:
   - `ACTIVE` → print the Notes section's tail and ask what to work on.
   - `CONCLUDED` or `ARCHIVED` → report state and ask: "Reopen? (flips status back to ACTIVE)". On yes, flip and continue.
3. Never edit existing sections silently — always append new sub-sections with a date header.

---

## Status mode

1. Run Phase 0.
2. Glob `<kb_path>/repos/*/research/*.md`. Parse frontmatter.
3. Default filter: only `status: ACTIVE`. `--all` lifts the filter.
4. Print:

```
| Note | Project | Subtype | Status | Updated |
|------|---------|---------|--------|---------|
| ... | ... | exploration | ACTIVE | 2026-04-17 |
```

---

## Conclude mode

1. Run Phase 0, read the note.
2. If already `CONCLUDED`: ask whether to overwrite the conclusion or append another block.
3. Prompt the user for a brief conclusion / decision / follow-up (multi-line accepted).
4. Append:

```markdown
## Conclusion (YYYY-MM-DD)

<user text>

### Follow-up
- [ ] <derived follow-up items, if any>
```

5. Flip frontmatter `status: CONCLUDED`.
6. Report: > Note concluded. To turn it into a feature: `/feature new <title> --from-investigation <note-path>`.

---

## Archive mode

1. Run Phase 0, read the note.
2. Flip frontmatter `status: ARCHIVED`. Do not delete. Do not prompt — archive is cheap and reversible.
3. Report: > Note archived. Resurrect any time with `/research continue <path>`.

---

## Rules

- **Research notes live only in KB.** No source repo artefacts.
- **Frontmatter is the state machine.** Status transitions happen only in frontmatter; body sections are append-only.
- **Never delete.** Archive instead.
- **Default subtype is `exploration`.** Other subtypes are more specialised.
- **Bridging to feature**: a research note can seed a feature spec via `/feature new <title> --from-investigation <note-path>` — structure it with a `## Recommended Approach` and `## Risk Register` section if you intend to bridge.
