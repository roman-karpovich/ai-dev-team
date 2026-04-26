# Confirmation Cadence

Inside an active `/feature` or `/cross-audit` flow: once the user has agreed to the direction (e.g. approved the spec, picked an option from a banner), drive the remaining steps to completion without re-asking at each intermediate step. Do NOT ask mid-flow questions like "ok to commit?", "shall I push?", "ready to open the PR?", "continue with X?", "go with Y?" — if the user already said yes to the plan, just do it and report results.

Ask only when:
- there is a real fork with distinct outcomes (A vs B vs C, or the decision is non-obvious and the user's preference matters)
- the action is destructive or irreversible outside the local repo (force-push to main, `rm -rf`, deleting remote branches, sending messages to external systems, modifying shared infra)
- something genuinely changes during execution (scope balloons, an unexpected fork appears, surprising state on disk)

Status updates during execution are fine and encouraged — just do not turn them into yes/no questions.
