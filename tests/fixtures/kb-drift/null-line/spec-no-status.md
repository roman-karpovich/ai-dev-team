---
title: A Spec With No Status Line
project: fixture
type: spec
created: 2026-05-31
tags: [spec, fixture]
---

# A Spec With No Status Line

C3 — a `type: spec` doc with NO frontmatter `status:` line. The scanner emits a
finding with `line: None`; the --summary render MUST drop the `:<line>` segment
(NEVER render the literal `:None`).
