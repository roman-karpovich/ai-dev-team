#!/usr/bin/env python3
"""parse_scorer_response.py — resilient extraction + validation of haiku-finding-scorer JSON.

The haiku-finding-scorer agent contract requires `Output only JSON`, but the
Haiku model frequently disregards this and emits preamble + Markdown-fenced
JSON. A naive ``json.loads(raw)`` fails on the preamble, triggering the
cross-auditor Step 3 whole-iteration fail-open and collapsing the 5-band
rubric to legacy {60, 90} pseudo-confidence (bypassing the anti-hallucination
cap entirely).

This helper extracts the JSON via three tiers and then validates per the
agent's I/O contract. Cross-auditor Step 3 step 4 delegates parsing to this
helper instead of doing the json.loads inline.

Tiers:
    1. raw  - json.loads(raw)
    2. fenced - extract content between ```json ... ``` (or plain ``` ... ```)
    3. brace - first '{' to last '}'

Validation rules (mirror the contract documented in
``agents/references/cross-auditor-step-3-pipeline.md`` §Step 3 step 4):
    - top level is an object with the single key ``scores``
    - ``scores`` is an object with EXACTLY one entry per expected finding ID
    - each entry has integer ``confidence`` in 0..100 and non-empty
      ``rationale``

Invocation:
    python3 parse_scorer_response.py <expected_id> [<expected_id> ...] < raw

Exit 0 on success; the validated parsed JSON is written to stdout.
Exit 1 on validation/extraction failure; a single-line failure reason is
written to stderr.
Exit 2 on usage error (no expected IDs supplied).
"""

from __future__ import annotations

import json
import re
import sys


_FENCE_RE = re.compile(r"```(?:json)?\s*\n(.*?)\n```", re.DOTALL)


def extract_json(raw: str) -> dict:
    """Return the first parseable JSON object found in *raw* via three tiers."""
    try:
        return json.loads(raw)
    except json.JSONDecodeError:
        pass

    m = _FENCE_RE.search(raw)
    if m:
        try:
            return json.loads(m.group(1))
        except json.JSONDecodeError:
            pass

    start = raw.find("{")
    end = raw.rfind("}")
    if start >= 0 and end > start:
        try:
            return json.loads(raw[start : end + 1])
        except json.JSONDecodeError:
            pass

    raise ValueError(
        "not parseable as JSON (tried raw / fenced / first-brace-to-last-brace)"
    )


def validate(parsed: object, expected_ids: list[str]) -> None:
    """Raise ValueError if *parsed* does not match the scorer I/O contract."""
    if not isinstance(parsed, dict):
        raise ValueError("top-level not an object")

    extra_top = set(parsed.keys()) - {"scores"}
    if extra_top:
        raise ValueError(f"stray top-level keys: {sorted(extra_top)}")
    if "scores" not in parsed:
        raise ValueError("missing required top-level key 'scores'")

    scores = parsed["scores"]
    if not isinstance(scores, dict):
        raise ValueError("'scores' is not an object")

    want = set(expected_ids)
    got = set(scores.keys())
    missing = want - got
    extras = got - want
    if missing:
        raise ValueError(f"missing IDs in scores: {sorted(missing)}")
    if extras:
        raise ValueError(f"unexpected IDs in scores: {sorted(extras)}")
    if len(scores) != len(expected_ids):
        raise ValueError(
            f"duplicate IDs in scores: expected {len(expected_ids)} entries, got {len(scores)}"
        )

    for fid, entry in scores.items():
        if not isinstance(entry, dict):
            raise ValueError(f"scores[{fid!r}] is not an object")
        conf = entry.get("confidence")
        if not isinstance(conf, int) or isinstance(conf, bool) or not (0 <= conf <= 100):
            raise ValueError(
                f"scores[{fid!r}].confidence must be an integer in 0..100"
            )
        rat = entry.get("rationale")
        if not isinstance(rat, str) or not rat.strip():
            raise ValueError(f"scores[{fid!r}].rationale missing or empty")


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        sys.stderr.write(
            "usage: parse_scorer_response.py <expected_id> [<expected_id> ...] < raw_response\n"
        )
        return 2

    expected_ids = argv[1:]
    raw = sys.stdin.read()

    try:
        parsed = extract_json(raw)
        validate(parsed, expected_ids)
    except ValueError as exc:
        sys.stderr.write(f"scorer-response-invalid: {exc}\n")
        return 1

    json.dump(parsed, sys.stdout)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
