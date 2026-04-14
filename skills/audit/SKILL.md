---
name: audit
description: Iterative security & logic audit with fix cycle
argument-hint: "<description of what to audit | path to existing audit doc>"
---

Iterative audit workflow. Runs as a loop: audit -> human decides per finding -> fix selected -> re-audit -> ...

## Argument parsing

- If $ARGUMENTS is a path to an existing file (`docs/audit/*.md`), this is a **re-audit** of a previous document.
- Otherwise, $ARGUMENTS is a textual description of what to audit (files, feature area, contract name, etc.).

## Paths

- Audit docs: `docs/audit/YYYY-MM-DD-<slug>-audit.md`

---

## First invocation (no existing audit doc)

1. Parse $ARGUMENTS as a description of the audit scope.
2. Identify all relevant source files. Read them thoroughly.
3. Perform a systematic review covering:
   - **Storage compatibility**: enum variant ordering, key collisions, storage layout changes affecting deployed contracts.
   - **Access control**: role checks on every write path, auth requirements, privilege escalation vectors.
   - **Logic correctness**: loop invariants, counter consistency, edge cases (empty inputs, duplicates, boundary values, overflow).
   - **Event integrity**: events match actual state changes, no missing/extra emissions.
   - **Resource exhaustion**: unbounded loops, unbounded storage growth, missing input size limits.
   - **Upgrade safety**: upgrade flow correctness, emergency mode bypass, initialization race conditions.
   - **Dependency interactions**: changes to shared crates and their impact on other contracts in the workspace.
4. Create `docs/audit/` if missing.
5. Write the audit document with this structure:

```markdown
# Audit: <scope description>
- Date: YYYY-MM-DD
- Status: IN PROGRESS
- Iteration: 1

## Scope
<files and areas reviewed>

## Summary table
| ID | Severity | Description | Status |
|----|----------|-------------|--------|

## Findings

### [F-001] <title>
- **Severity**: CRITICAL / MEDIUM / LOW
- **File**: path:line
- **Description**: ...
- **Impact**: ...
- **Fix**: concrete fix suggestion
- **Status**: OPEN

### [F-002] ...

## Verified correct
<explicitly reviewed-and-approved logic>
```

6. Present findings to the human. Show:
   - Audit doc path
   - Count by severity
   - List of all findings with IDs for easy reference
7. Stop. **Do NOT fix anything automatically.** Wait for the human to decide what to do with each finding.

---

## Finding statuses

The human controls the disposition of each finding. Valid statuses:

| Status | Meaning | Set by |
|--------|---------|--------|
| `OPEN` | Needs decision | audit (default) |
| `FIXED (date)` | Code change applied | after fix |
| `VERIFIED (date)` | Fix confirmed correct on re-audit | re-audit |
| `ACCEPTED` | Known issue, intentionally kept as-is | human decision |
| `DEFERRED` | Will address later, not now | human decision |
| `REOPENED` | Fix was incomplete/wrong on re-audit | re-audit |

---

## Fix phase

**Only fix what the human explicitly asks to fix.** The human will say something like:
- "fix F-001 and F-003"
- "fix all critical"
- "fix F-002, accept F-004, defer F-005"

1. Parse the human's instructions. For each finding:
   - **fix <ID>**: apply the fix from the audit doc, update status to `FIXED (YYYY-MM-DD)`
   - **accept <ID>**: update status to `ACCEPTED`, add human's rationale if given
   - **defer <ID>**: update status to `DEFERRED`, add note if given
2. For findings being fixed:
   - Read the referenced file.
   - Apply the fix as described in the audit doc.
   - Add tests if the fix requires them.
3. Run the test suite. If tests fail, fix until green.
4. Update the audit document with all status changes.
5. Output summary: what was fixed, accepted, deferred. Test results. Remaining OPEN items.
6. Stop. Wait for further instructions.

---

## Re-audit (existing audit doc passed as argument)

1. Read the audit document at the given path.
2. Note the current iteration number. Increment it.
3. Re-read all source files in scope (they may have changed since last audit).
4. For each `FIXED` finding: verify the fix is correct and complete.
   - If the fix is good, change Status to `VERIFIED (YYYY-MM-DD)`.
   - If the fix is incomplete or wrong, change Status to `REOPENED` with a note.
   - If the fix introduced new issues, add new findings.
5. Leave `ACCEPTED` and `DEFERRED` findings as-is (don't re-open them).
6. Check for any NEW issues not covered by previous findings. Add them as new [F-NNN] entries.
7. Update the document:
   - Increment `Iteration: N`
   - Update the summary table
   - If no OPEN or REOPENED findings remain: set `Status: COMPLETE`
8. Present the delta to the human:
   - Newly verified findings
   - Reopened findings (with explanation)
   - New findings
9. Stop. If there are open/reopened findings, wait for human instructions. If all resolved, report completion.

---

## Cycle

The expected flow is:
```
/audit <description>                    -> initial audit, creates doc
  human: "fix F-001, F-003.            -> selective fix
          accept F-002.
          defer F-004."
/audit <doc path>                       -> re-audit: verify fixes, find new issues
  human: "fix F-005, accept F-006"      -> next round
/audit <doc path>                       -> re-audit again
  ...                                   -> repeat until Status: COMPLETE
```
