# Cut-spec hard-fail policy

Canonical home for the cut-spec hard-fail contract, the cut-spec registry, the
error-message template, the cut-PR author checklist, and the
forward/retroactive distinction.

Source: BACKLOG #56 (`removed-cli-flag-hard-fail`); investigator round-2
mission audit 2026-04-28 promoted this from latent backlog to P0 after the
multi-GH-account cut PR silently dropped a user's config key. MISSION rule
#12 points here for the contract; this doc is the canonical store.

## 1. Policy

When a cut spec removes a user-facing CLI flag or YAML config key, the cut PR
MUST add detection-with-error prose at the relevant parsing surface (the
applicable `skills/<name>/SKILL.md` Argument Parsing / Flags / Modes block,
or `docs/kb-discovery.md` for YAML config keys). Detection lives for ONE
minor cycle: the cut PR ships removal + detection together, and the next
minor's housekeeping removes the detection clause entirely (a one-line entry
in that minor's bump-version PR, or a small follow-up cleanup PR).

The detection is prose instructing Claude to hard-stop with the canonical
error message rather than silently ignoring the input. YAML parsers' "warn
once and continue" tolerance for unknown keys is the default behavior; the
removed-key clause is an explicit override that names the removed key and
points the reader at the cut spec.

## 2. Error message contract

Every detection clause MUST emit the canonical error line in the form:

```
ERROR: <key-or-flag> was removed in cut spec design/<slug>.md. Read that spec for the migration path.
```

The placeholders `<key-or-flag>` and `<slug>` are angle-bracketed in this
document and stay angle-bracketed here — concrete values appear only in the
detection clauses at the parsing surfaces and in the smoke pins that assert
those clauses byte-for-byte.

The line has THREE load-bearing voice anchors and smoke pins MUST assert all
three:

1. `ERROR: ` prefix — matches the shell-level convention used by
   `hooks/lib/cross_audit_resolve_range.sh` and the Phase 0.5 preflight prose
   in `skills/cross-audit/SKILL.md`. Distinct from the warning prefix
   (`⚠ `) reserved for non-blocking issues.
2. `was removed in cut spec design/<slug>.md` middle — binds the message to
   a specific cut spec by slug; the reader navigates from the error to the
   canonical migration narrative.
3. `. Read that spec for the migration path.` remediation suffix — names
   the recovery action (read the cut spec); matches the Phase 0.5 preflight
   voice.

Smoke pins MUST grep the entire line byte-for-byte. Partial-substring
assertions are forbidden because they let voice drift slip through (a
`WARN:` swap, a remediation-suffix drop, or a slug typo would not be caught
by a substring assertion that only inspects the middle).

One line per error; no emoji; no leading bullet character; no trailing
ellipsis. The line is identical in tone whether the parsing surface is a
SKILL.md flag block or a `docs/kb-discovery.md` config-key clause.

## 3. Cut-spec registry

Every cut spec that removes a user-facing CLI flag or YAML config key gets a
row keyed by SLUG and CATEGORY-LABEL. The registry deliberately does NOT
quote the removed-item literal — readers follow the slug to the cut spec for
the canonical literal form. This keeps the registry stable as cut specs are
restated and prevents the policy doc from accumulating retired literals
that would collide with absence guards in the smoke harness.

Schema:

```
| Cut-spec slug | Category | Detection added (cycle) | Removal due (cycle) | State |
```

Categories are generic labels: `CLI flag`, `Config key`, `Config block + CLI flag`.

State machine: `detection-active` → `detection-due-for-removal` → `removed-completely`.

Seed rows for the four cuts shipped 2026-04-26..2026-04-27 (PRs #62/#63/#64/#65):

| Cut-spec slug                        | Category                    | Detection added (cycle) | Removal due (cycle) | State            |
|--------------------------------------|-----------------------------|-------------------------|---------------------|------------------|
| 2026-04-26-cut-probe-downgrade       | CLI flag                    | 1.13.0                  | 1.14.0              | detection-active |
| 2026-04-27-cut-from-investigation    | CLI flag                    | 1.13.0                  | 1.14.0              | detection-active |
| 2026-04-27-cut-codex-fast            | Config key                  | 1.13.0                  | 1.14.0              | detection-active |
| 2026-04-27-cut-multi-gh-account      | Config block + CLI flag     | 1.13.0                  | 1.14.0              | detection-active |

## 4. Cut-PR author checklist

Before merging a cut PR that removes a user-facing CLI flag or YAML config
key, the author works through the following:

- Did you add detection prose at the parsing surface that names the
  canonical error message in the exact form from §2? The detection clause
  belongs in the SKILL.md `Flags` / Argument Parsing block or in
  `docs/kb-discovery.md` for YAML config keys.
- Did you update the registry (§3) with a new row containing your cut
  spec's slug and category-label? Mark the row `detection-active` and set
  `Removal due` to the next minor cycle.
- Did you add a smoke pin asserting the canonical line byte-for-byte at the
  parsing surface? The pin asserts the FULL line (all three voice anchors),
  not a substring.
- Did you flag the next-minor housekeeping removal (a follow-up entry in
  the BACKLOG or in the next minor's bump-version PR description) so the
  detection clause is removed when its cycle ends?
- Did you avoid leaking the retired literal into `docs/cut-spec-policy.md`?
  The policy doc stays placeholder-only; concrete literals belong only at
  the parsing surface and in the smoke pin that asserts that surface.

## 5. Forward / retroactive distinction

Detection clauses come in two flavors:

- **Forward**: a future cut PR ships removal + detection together; the
  detection clause lives one minor cycle and is removed in the following
  minor's housekeeping. This is the steady-state pattern the policy
  enforces from now on.
- **Retroactive**: detection prose added after-the-fact for a cut that
  shipped without detection. The four seed-row cuts in §3 fall in this
  category; their detection clauses landed with BACKLOG #56 (this spec) on
  the 1.13.0 cycle and are due for removal on 1.14.0.

The retroactive batch landing with this spec is small and bounded: 5
canonical hard-fail clauses across 3 parsing surfaces for 4 cut specs (one
of those cuts removed both a config block and a CLI flag, which is why the
clause count exceeds the cut count). The exact distribution and the
removed-item literals live at the parsing surfaces themselves and in the
cut specs that the registry rows point to — this section deliberately does
not enumerate them inline so the policy doc stays placeholder-only.

When the 1.14.0 housekeeping PR removes the detection clauses, it MUST also
remove the corresponding smoke pins and update the registry rows from
`detection-active` to `removed-completely` (the intermediate
`detection-due-for-removal` state is a courtesy marker for cuts that need
extra attention before removal).
