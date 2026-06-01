# N3 sibling-dangling source

A genuine same-dir dangling §-pointer: the sibling `sib.md` is present but its
heading `Gone` was deleted. The source-relative resolution keeps this class
flagged — a real intra-KB dangling heading must NOT be silently suppressed.

see `sib.md` §Gone
