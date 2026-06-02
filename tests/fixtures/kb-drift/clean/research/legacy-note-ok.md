---
title: A Legacy Research-Note Under a research/ Dir Segment
type: research-note
status: OPEN
created: 2026-06-02
tags: [research-note, fixture]
---

# A Legacy Research-Note Under a research/ Dir Segment

C5-R is type-scoped on the exact string `type: research`, NEVER on the
`research/` path. This note is `type: research-note` (a distinct, intentional
type spelling) with an off-enum `status: OPEN` and lives under a `research/`-
named DIRECTORY segment. A directory-segment path-scope bug — not merely a
substring one — would FP it; the clean-dir-zero assertion catches that.
