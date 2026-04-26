# Agent Claims vs Runtime — Audit Manifest

## Purpose

This document classifies `MUST`, `always`, `never`, and `do NOT` claims in `agents/*.md`
by their enforcement status at runtime. It distinguishes:

- **enforced** — backed by orchestrator hook, smoke pin, or renderer hard-stop that will
  catch violations automatically.
- **convention** — prose-only claim; no runtime gate; relies on developer discipline.
- **self-policed** — agent's own discretion; no external verifier.

## Methodology

Initial pass (v1): classify the highest-leverage claims (those most likely to mislead a
reader into overestimating enforcement coverage). Expansion is welcome — add rows as new
claims are identified.

Source discovery used:

```bash
grep -nE "MUST|always|never|do NOT" agents/*.md
```

Note: that exact case-sensitive grep currently returns no hits for `developer-senior.md`
or `investigator.md`; rows for those files are included because BACKLOG #46 Step 2
explicitly requested coverage for them, and the quoted lines are equivalent imperative
claims from the same prompt surface.

## Scope

Initial pass covers `agents/*.md` as of BACKLOG #46 (2026-04-26). Only `MUST`, `always`,
`never`, `do NOT` phrases are in scope, plus the two explicitly requested prompt-surface
exceptions noted above.

## Claims Table

| Agent | Claim (verbatim quote) | Location | Class | Backing |
|-------|------------------------|----------|-------|---------|
| cross-auditor.md | "`off`-mode probes MUST NOT be dispatched and MUST NOT produce receipts" | `agents/cross-auditor.md:43` | enforced | `check_cross_auditor_step05_probe_dispatch` smoke pin covers Step 0.5 dispatch behavior |
| cross-auditor.md | "Step 0.5 MUST emit fully-populated string triples" | `agents/cross-auditor.md:263` | enforced | `hooks/lib/render_findings.sh` hard-stops on malformed `probe_failures[]`; renderer smoke pins cover malformed input |
| cross-auditor.md | "orchestrator MUST emit all three required fields as non-empty strings" | `agents/cross-auditor.md:380` | enforced | `hooks/lib/render_findings.sh` schema hard-stop plus `check_probe_failures_schema_hard_stop` |
| cross-auditor.md | "do NOT lower `codex_reasoning_effort`" | `agents/cross-auditor.md:273` | enforced | smoke pins keep `effort: xhigh` and the `Defaults to xhigh` prompt text |
| cross-auditor.md | "**Never** read `codex.model_fast`" | `agents/cross-auditor.md:508` | enforced | smoke pins in `tests/smoke.sh` and `check_cross_audit_phase0_bans_model_fast` |
| cross-auditor.md | "`spec` mode exception: do NOT write files" | `agents/cross-auditor.md:386` | convention | none — convention only |
| developer-codex.md | "Rust: `cargo fmt` always" | `agents/developer-codex.md:75` | convention | none — convention only |
| developer-codex.md | "stage only files directly related to this step — never `git add -A`" | `agents/developer-codex.md:82` | convention | none — convention only |
| developer-codex.md | "Never call Codex with a vague prompt" | `agents/developer-codex.md:109` | self-policed | none — agent self-policed |
| developer-codex.md | "Verify each step's green capture yourself" | `agents/developer-codex.md:110` | self-policed | none — agent self-policed |
| developer-senior.md | "No giant single commits" | `agents/developer-senior.md:23` | convention | none — convention only |
| developer-senior.md | "No speculative additions" | `agents/developer-senior.md:24` | self-policed | none — agent self-policed |
| spec-compliance-checker.md | "DONE without a green capture file is always FAIL" | `agents/spec-compliance-checker.md:183` | self-policed | none — agent self-policed |
| spec-compliance-checker.md | "A green capture that doesn't match `expected_pass_pattern` is always FAIL" | `agents/spec-compliance-checker.md:184` | self-policed | none — agent self-policed |
| spec-compliance-checker.md | "never soften this, never waive" | `agents/spec-compliance-checker.md:185` | self-policed | none — agent self-policed |
| librarian.md | "Never modify source code or files outside the KB" | `agents/librarian.md:135` | self-policed | none — agent self-policed |
| librarian.md | "never overwrite a previous iter" | `agents/librarian.md:138` | convention | none — convention only |
| librarian.md | "Always confirm the KB root path before writing" | `agents/librarian.md:140` | self-policed | none — agent self-policed |
| verifier.md | "You never write or modify source code" | `agents/verifier.md:13` | self-policed | no Write/Edit tools, but Bash remains available; no external write gate |
| investigator.md | "Use it for ALL subsequent rounds" | `agents/investigator.md:67` | self-policed | none — agent self-policed |
