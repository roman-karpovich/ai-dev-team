# Publish: post audit findings as a PR review

Full recipe for the `publish` decision invoked inside `/cross-audit` Phase 3, or standalone via `/cross-audit publish <slug> <ids>`. Publish exports findings to GitHub as one **review** (`event: "COMMENT"`) that bundles inline comments + a body-level comment in a single `POST /repos/<owner>/<repo>/pulls/<N>/reviews` call.

Publish is orthogonal to the status state machine — it does NOT flip OPEN→FIXED. A finding can be both fixed in-repo and published to the PR.

---

## 1. Runtime context (preamble)

- **cwd**: publish runs in the caller's cwd. The cross-auditor's isolated worktree is typically gone by publish time — do NOT assume it exists, and do NOT `git ls-tree` or otherwise read the worktree. Caller cwd is not assumed to be a clone of `pr_repo`.
- **KB reads only**: all routing metadata (`pr_files`, `pr_head_oid`, `pr_url`, `pr_repo`) comes from the findings doc frontmatter resolved from `audit_slug`. Publish reads findings content + `pr_files` from KB; that is the single source of truth.
- **All gh api calls pass --repo <pr_repo> AND --include**: `--repo` decouples the call from cwd; `--include` captures the HTTP status line + response headers so the failure matrix (below) can deterministically branch on status + `X-RateLimit-Remaining`. A plain `gh api` without `--include` cannot distinguish the rate-limit and permission-denied 403 cases.
- **Response parser**: `--include` output is `HTTP/<ver> <code>\n<header lines>\n\n<json body>`. Parse:
  - Status code from the status line (`HTTP/2 200` / `HTTP/2 422` / `HTTP/2 403` / etc.).
  - Headers via case-insensitive name match. For `X-RateLimit-Remaining`: `awk 'tolower($1)=="x-ratelimit-remaining:"{print $2}'`.
  - Body: everything after the first blank line; parse as JSON.
- **Entry points** (two):
  1. Inside the live Phase 3 decision loop, after the cross-auditor completes.
  2. Standalone: `/cross-audit publish <slug> <ids>` against an existing findings doc. Same recipe; resolve findings via `<slug>`.
- **Force-push preflight**: before POSTing the review:
  ```
  current_head=$(gh pr view <N> --repo <pr_repo> --json headRefOid -q '.headRefOid')
  ```
  Compare against findings frontmatter `pr_head_oid`. If different, hard-stop with remediation "PR force-pushed since audit; re-run `/cross-audit pr <N>` to refresh." Bypass: `--force-publish-stale` records the stale OID into `head_oid_at_publish` in the `published_to` record (audit trail), lets the publish proceed.
- **Response-injection seam** (for tests): env var `CROSS_AUDIT_PUBLISH_STUB_RESPONSE=<path1>[:<path2>[:<path3>...]]` — colon-separated ordered list of stubbed `--include` output files. On the N-th would-be POST inside a single publish invocation, read the N-th path as the response instead of issuing a real network call; the `--include` parser runs against the file contents verbatim. Running out of paths (publish makes more POSTs than stubs supplied) aborts with a test-config error before touching the network. Extra paths are ignored. The seam supports multi-POST sequences (e.g. 422 → body-only retry 2xx) so the failure-matrix scenarios are exercisable without GitHub credentials or live network.

---

### Public-output hygiene (R8)

Finding bodies posted via this flow are public artifacts in third-party repos. R8 applies — describe issues in repo-internal terms (file paths inside `<pr_repo>`, behaviours, tests). See R8 in `skills/feature/references/code-quality-rules.md` (the cross-audit publish carve-out is documented in §3 of the canonical rule).

---

## 2. Request payload (single POST)

The entire publish is one POST to `/repos/<owner>/<repo>/pulls/<N>/reviews`:

```
gh api --include --repo <pr_repo> \
  "repos/<pr_repo>/pulls/<N>/reviews" \
  --method POST --input -
```

Stdin is the JSON request body. Shape:

```json
{
  "event": "COMMENT",
  "body": "Cross-audit findings (ai-dev-team). Inline below; findings routed here are either on lines outside the diff or in files where inline commenting is unsupported (pure rename, binary, submodule, parser ambiguity).\n\n### [X3 HIGH] <title>\n\n<description>\n\nFix: <fix>",
  "comments": [
    {"path": "src/foo.rs", "line": 42, "side": "RIGHT", "body": "**[X1 HIGH] <title>**\n\n<description>\n\nFix: <fix>"},
    {"path": "src/baz.rs", "line": 95, "side": "RIGHT", "body": "**[X2 HIGH] <title>**\n\n<description>\n\nFix: <fix>"}
  ]
}
```

Every `comments[]` entry has exactly four keys: `path`, `line`, `side` (always `"RIGHT"` — PR head side), `body`. The top-level `event` is always `"COMMENT"` (informational review — no approval, no changes-requested). Body comments are prepended to `body` as `### [Xn SEV] <title>` blocks, one per finding routed to the body bucket.

---

## 3. Recipe

### (1) Hunk-header classifier

Parse the output of:

```
gh pr diff <N> --repo <pr_repo>
```

For each `@@ -a,b +c,d @@` hunk header on a file F, the set of addressable new-side lines is `{c, c+1, ..., c+d-1}` intersected with the `+` and context lines in the hunk. Collect across the whole diff into `addressable_lines[(path, new_line)]`. If a finding's `file:line` is in the set → inline comment. Otherwise → body bucket.

### (2) File-metadata routing (from frontmatter `pr_files`)

Before hunk-header lookup, classify by file metadata. Look up the finding's filename in `pr_files` (keyed by `filename`):

| Predicate | Route | Notes |
|-----------|-------|-------|
| `status == "renamed" && patch_present == false` | body | Pure rename; no line changes to anchor on. |
| `status == "renamed" && patch_present == true`  | regular (rule 1) | Rename-with-edits — hunk-header logic applies. |
| `patch_present == false && status not in {removed, renamed} && is_submodule == false` | body | Binary file. |
| `is_submodule == true` | body | Submodule pointer bump; no line diffs. |
| filename absent from `pr_files` | body + warning | Should only happen when findings doc was hand-edited. |

Additionally: if rule (1) hits a per-file parser ambiguity while walking hunks for file F (malformed hunk header, missing anchor, etc.), route ALL findings for F to body. Never guess line positions.

### (3) Diff-truncation handling

If the `gh pr diff` output contains GitHub's truncation sentinel (e.g. `diff too large`), short-circuit rules (1) and (2): route ALL findings to body, set `truncated: true` on the resulting `published_to` record, surface a warning. Per-file routing is skipped entirely under truncation — there is no reliable way to classify addressability from a partial diff.

### (4) Exact POST call

See §2. Exactly one `gh api --include --repo <pr_repo>` call per publish (modulo the 422-degrade retry — see failure matrix below).

### (5) Status-filter

- `publish` / `publish all` (no explicit IDs): filter findings to `status in {OPEN, REOPENED}` only. Skip FIXED / VERIFIED / ACCEPTED / DEFERRED / INVALID.
- `publish <ids>` with explicit IDs: publish those IDs regardless of status. If any named ID has status `ACCEPTED` / `DEFERRED` / `INVALID`, warn once and require a single re-confirm (y/N) for the whole call. Do not re-confirm per ID.

### (6) `published_to:` record

On any 2xx (first-try or 422-degrade retry), append one YAML record to the findings frontmatter `published_to:` list:

```yaml
published_to:
  - pr: https://github.com/roman-karpovich/ai-dev-team/pull/472
    timestamp: 2026-04-17T14:30:00Z
    finding_ids: [X1, X2, X3]
    review_id: 2847392011           # body.id from the reviews POST response
    truncated: false                # true only if §3.3 truncation short-circuit fired
    head_oid_at_publish: 1a2b3c4d5e6f7890abcdef1234567890abcdef12
    degraded_to_body: false         # true only when the 422-degrade retry produced this 2xx
```

Every record has all seven fields — no optional fields. Consumers read them unconditionally.

**Duplicate-ID guard**: reject publishing an ID for a `pr:` URL where that same ID already appears in any `published_to` record for that URL. Override: `--republish <ids>` forces a re-post and adds a new record (same payload rules apply).

### (7) Failure matrix (deterministic)

All branches key off the status line + headers captured by `--include`. No heuristic body-parsing.

- **5xx / network failure before any 2xx** → no `published_to` write. Surface the status line + body verbatim. Publish exits non-zero.
- **Any 422 from the reviews POST** → treat as "one or more inline comments are un-postable." Degrade ALL inline comments to the body bucket in one pass (prepend each as `### [Xn SEV] <title>` block into `body`; `comments: []`). Retry ONCE as a body-only review (also `gh api --include --repo`). If the retry returns 2xx → write `published_to` record with `degraded_to_body: true`; surface one warning listing the finding IDs that were intended inline. If the retry is non-2xx (5xx, 4xx, etc.) → no `published_to` write; surface BOTH the original 422 AND the retry error (neither is swallowed). Publish exits non-zero on retry failure.
- **403 with header `X-RateLimit-Remaining: 0`** → rate-limit branch. Abort publish. Surface the `gh api rate_limit` reset time. No `published_to` write.
- **403 with header absent OR value ≠ 0** → permission-denied branch. Abort publish. Remediation: "Token lacks `pull_requests: write` on `<pr_repo>` — run `gh auth refresh -s repo` or use a token with write scope." No `published_to` write.
- **2xx on first try** → write `published_to` record with `degraded_to_body: false`.

The "absent OR value ≠ 0" predicate is canonical (spec X26). Do not reword; tests grep for it verbatim.

---

## 4. Test-fixture contract (no-network goldens)

Fixtures under `tests/fixtures/pr-aware-cross-audit/` provide the canonical request / record / error artifacts. `tests/smoke.sh` verifies both shape and content of each golden; publish implementers MUST match them byte-for-byte.

### Routing goldens (X28 — request vs record are split artifacts)

- **A1** — normal diff + `publish all` (default filter → OPEN/REOPENED only):
  - request body → `expected-request-normal-publish-all.json`
  - post-2xx record → `expected-published-to-record-normal.json` (`finding_ids: [X1, X2, X3]`, `truncated: false`, `degraded_to_body: false`)
- **A2** — normal diff + explicit `publish X1..X8` post-reconfirm (full set including ACCEPTED / DEFERRED / INVALID / FIXED / VERIFIED IDs):
  - request body → `expected-request-normal-explicit-all.json`
  - post-2xx record → `expected-published-to-record-normal-explicit-all.json` (`finding_ids: [X1..X8]`, `truncated: false`, `degraded_to_body: false`)
- **B** — truncated diff + `publish all`:
  - request body → `expected-request-truncated.json` (all findings in `body`, `comments: []`)
  - post-2xx record → `expected-published-to-record-truncated.json` (`truncated: true`, `degraded_to_body: false`)

### Failure-matrix goldens (X29/X34 — via `CROSS_AUDIT_PUBLISH_STUB_RESPONSE`)

- **D1** — 422 → body-only retry 2xx:
  - stubs: `CROSS_AUDIT_PUBLISH_STUB_RESPONSE=sample-response-422-include.txt:sample-response-422-retry-2xx-include.txt`
  - retry request body → `expected-retry-request-422.json` (each finding prepended as `### [Xn SEV]` block, `comments: []`)
  - post-retry record → `expected-published-to-record-422-degraded.json` (`degraded_to_body: true`, `truncated: false`)
- **D2** — 403 rate-limit abort:
  - stub: `sample-response-403-ratelimited-include.txt` (`HTTP/2 403`, `x-ratelimit-remaining: 0`, reset header present)
  - expected stderr: `expected-error-403-ratelimited.txt` (contains `rate_limit` and reset time)
  - post-state: no `published_to` write; publish exit non-zero.
- **D3** — 403 permission-denied abort:
  - stub: `sample-response-403-permission-include.txt` (`HTTP/2 403`, header absent OR value ≠ 0)
  - expected stderr: `expected-error-403-permission.txt` (contains the `pull_requests: write` remediation)
  - post-state: no `published_to` write; publish exit non-zero.
- **D4** — 422 → body-only retry 5xx (retry also fails):
  - stubs: `CROSS_AUDIT_PUBLISH_STUB_RESPONSE=sample-response-422-include.txt:sample-response-5xx-include.txt`
  - expected stderr: `expected-error-422-retry-failed.txt` — must cite BOTH the original 422 body excerpt AND the 5xx retry body excerpt. Both errors are surfaced; neither is swallowed.
  - post-state: no `published_to` write; publish exit non-zero.

---

## 5. Standalone entry point

`/cross-audit publish <slug> <ids>` resolves the findings doc from `<slug>` (normally `<kb>/repos/<project>/security/<slug>-findings.md`), reads `pr_number` / `pr_repo` / `pr_url` / `pr_head_oid` / `pr_files` from frontmatter, and executes this recipe. Caller cwd is not assumed to be a clone of `pr_repo` — `--repo <pr_repo>` on every `gh api` call keeps this working. `--republish <ids>` and `--force-publish-stale` flags apply the same way as in the Phase 3 loop.
