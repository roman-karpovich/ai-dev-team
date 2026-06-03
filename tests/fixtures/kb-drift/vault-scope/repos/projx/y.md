# Repos project file (single-count proof)

This file lives under `repos/projx/`. It was scanned before the widening (via
the repos/* subdirs) and is still scanned after (via the single kb_root rglob).
The broken wikilink below flags exactly ONE C1 — a single rglob from kb_root
visits each file once, so switching the scan root from repos/* subdirs to
[kb_root] must NOT double-count it.

[[no-such-repos-note]]
