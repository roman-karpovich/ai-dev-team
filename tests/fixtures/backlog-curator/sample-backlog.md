# BACKLOG — sample (backlog-curator targeted-case fixture)

Minimal targeted-case fixture for `tests/backlog_archive.py` classification.
Every `### N.` block + table row below is an EXPLICIT distinct case (spec §3.2.1).

## Active priorities (post-convergence test)

### P0 — five-column Status=col-4

| # | Item | Axis | Status | Rationale |
|---|------|------|--------|-----------|
| ~~**9**~~ | candidate-similar topic (CAND row) | code-quality × verification | **✅ DONE 2026-04-12 — PR #91** | Struck done row, title-similar to `### 9` block → candidate hint likely-same-item. Discussion started 2026-04-01. |
| ~~**30**~~ | networking retry backoff tuning | rollout-isolation | **✅ DONE 2026-04-15 — PR #92** | Struck done row, title DISsimilar to `### 30` block → candidate hint likely-collision. |
| ~~**40a**~~ | suffix sub-item alpha | process-truthfulness | **✅ DONE 2026-04-20 — PR #93** | Letter-suffix struck row, indexed #40a, NOT coalesced into #40. |
| ~~**40b**~~ | suffix sub-item beta | process-truthfulness | **✅ DONE 2026-04-22 — PR #94** | Letter-suffix struck row, indexed #40b. |
| **80** | non-struck closed item | audit-coverage | **✅ CLOSED 2026-04-30 — done** | Non-struck row carrying a `✅` (rule-1 STRUCK-ONLY contract) → FLAGGED, NOT archived; stays in BACKLOG. The `--dry-run` FLAGGED section lists `#80`. |
| **41** | genuinely open priority | rule-enforcement | **P1 queued** | Open row with no done-marker glyph, stays in BACKLOG; never flagged. |

### P2 — four-column, misparse-vector OPEN rows that MUST stay safe

These rows carry content pipes (an escaped `\|`, a double-escaped `\\|`, an
inline-code-span pipe) AND a leading `✅` in a cell. Pre-fix, a naive column
parse inflated their apparent arity and re-keyed a non-Status cell as the Status
cell → the OPEN row was mis-archived (data loss, audit X1/X4/X6). Struck-only
done-detection reads NO cell to decide done-ness, so they are INERT by
construction: each is FLAGGED (`✅` present, not struck) and never archived.

| # | Item | Status | Reason |
|---|------|--------|--------|
| **42** | deferred open four-col item | **P2 deferred** | Open row in a 4-col table with no done-marker glyph; neither archived nor flagged. |
| **81** | escaped-pipe open four-col item | P2 queued | ✅ RESOLVED 2026-05-31 \| extra note — escaped `\|` content pipe, MUST stay OPEN. |
| **82** | double-escaped open four-col item | P2 queued | ✅ RESOLVED 2026-05-31 \\| extra note — double-escaped `\\|` content pipe, MUST stay OPEN. |
| **83** | code-span open four-col item | P2 queued | ✅ see `a | b` inline-code-span pipe — MUST stay OPEN. |

## P3: Low impact / nice-to-have

### 5. Open standalone item

OPEN_MARKER_5 — not struck, no own-status-done line, no done-row match. MUST stay OPEN.

This block contains a prose `✅ RESOLVED` mention and a `DISCARDED` draft note inside an OPEN block (the #59/#77 exclusion) → MUST NOT classify done.

### 9. Candidate-similar topic block

CAND_BLOCK_9 — not struck, no own-status line. Its number matches the done table row `~~**9**~~` whose item-cell is title-similar (shared distinctive token "candidate") → CANDIDATE, hint likely-same-item. Archived ONLY when approved via `--archive-candidates 9`.

### ~~12. Struck done block~~ ✅ DONE (2026-04-17)

STRUCK_DONE_MARKER_12 — struck `### ~~` header → AUTO-DONE, archived unconditionally. Date bucket 2026-04 from the header date.

### 20. Own-status mid-line block

**Axis:** foo × bar. **Status: ✅ DONE (2026-04-18) — PR #99** OWNSTATUS_DONE_MARKER_20

This body line carries the bold field `**Status: ✅` MID-LINE (after `**Axis:**`), not at line start → AUTO-DONE. Date bucket 2026-04 from the status-field date.

### 30. Collision block — unrelated topic

COLLISION_BLOCK_30 — not struck, no own-status line. Its number matches the done table row `~~**30**~~` whose item-cell is title-DISsimilar (networking refactor vs this topic) → CANDIDATE, hint likely-collision. MUST stay OPEN when NOT in `--archive-candidates`; the struck row #30 archives separately regardless.

### 50. FP-guard open block

FP_GUARD_50 — open block whose body contains a struck SUB-bullet and a prose example, but NO own-status-line and NO done-row match. Body-wide `✅ DONE` present must NOT classify done.

- ~~**Cx — foo.**~~ ✅ DONE (2026-04-27, PR #64)

Prose example, preserving items with `~~…~~ ✅ DONE` so the literal marker is in body text but not an own-status field. MUST stay OPEN.

## Completed

DONE backlog items moved out to dated archives — full prose preserved.

### Completed specs

See `design/` for completed specs with `status: VERIFIED`.
