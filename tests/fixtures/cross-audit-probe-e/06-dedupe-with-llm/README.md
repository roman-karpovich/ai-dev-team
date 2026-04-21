# Fixture 06 — dedupe-with-llm

Per spec §3.6 Bullet 1 iter-6 X26 / iter-7 X29 carve-out: this fixture exercises `hooks/lib/dedupe_findings.sh merge_pair` post-X23 behaviour, NOT the probe-E detector.

- `input.json` — a two-finding dedupe input (claude first, probe:E second, same E-fingerprint).
- `expected-dedupe.json` — canonical byte-exact expected output after X23 probe-primary swap + extended carried-field list (`provisional_id`, `canonical_payload`, `blocking`, `fingerprint_anchors`).
- `expected-findings.json` / `expected-receipt-metadata.json` — sentinel empties; fixture 06 does NOT run the probe detector.
