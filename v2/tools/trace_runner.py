#!/usr/bin/env python3
"""Deterministic trace runner for the v2 VERIFY state machine (ADR-1/2/3).

Replays a trace fixture's input events through a reference implementation of
the ADR-1 run/node state machine (tables loaded as data from
v2/spec/transitions.json) and asserts the trace's expectations. No provider
calls, no side effects, stdlib only.

Usage:
  python3 v2/tools/trace_runner.py [--spec PATH] TRACE.json [...]
  python3 v2/tools/trace_runner.py --expect-fail MUTANT.json [...]

Exit 0 iff every trace passes (or, with --expect-fail, every trace fails).
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_SPEC = REPO_ROOT / "v2" / "spec" / "transitions.json"

GATING = ("CONFIRMED", "UNRESOLVED", "UNVERIFIABLE")


def body_hash(kind, node_id, attempt, payload):
    body = {"event_kind": kind, "node_id": node_id, "attempt": attempt, "payload": payload}
    return hashlib.sha256(
        json.dumps(body, sort_keys=True, separators=(",", ":")).encode()
    ).hexdigest()


class TraceError(Exception):
    pass


class Node:
    def __init__(self, spec):
        self.node_id = spec["node_id"]
        self.kind = spec["kind"]
        self.required = spec["required"]
        self.max_attempts = spec["max_attempts"]
        self.attempts = {}
        self.last_failure_class = None
        self.skipped = False

    @property
    def latest(self):
        return max(self.attempts) if self.attempts else None

    @property
    def status(self):
        if self.skipped:
            return "SKIPPED"
        if not self.attempts:
            return "PENDING"
        return self.attempts[self.latest]


class Machine:
    def __init__(self, spec):
        self.spec = spec
        self.phase = "CREATED"
        self.terminal = None
        self.release_recommendation = None
        self.cancelling = False
        self.cutoff = False
        self.corrupted = False
        self.profile = None
        self.policy_version = None
        self.retry_reserve = 0
        self.wall_clock_min = None
        self.deadlines = {}
        self.clock = 0
        self.nodes = {}
        self.adjudications = []
        self.finder_candidates = 0
        self.canonical_finding_ids = []
        self.degradations = []
        self.transitions = []
        self.node_transitions = []
        self.seen = {}  # (kind, event_id) -> body hash
        self.dispatch_effects = set()  # (node_id, attempt): at-most-once side effects
        self.dispatch_at = {}
        self.run_rows = spec["run_transitions"]
        self.attempt_rows = spec["attempt_transitions"]
        self.settled_states = set(spec["attempt_settled_states"])
        self.retry_classes = set(spec["failure_classes"]["retryable"]) | set(
            spec["failure_classes"]["corrective"]
        )
        self.ladder = spec["severity_ladder"]

    # -- helpers ---------------------------------------------------------

    def record(self, on, src, dst):
        self.transitions.append({"on": on, "from": src, "to": dst})

    def retry_allowed(self, node):
        # G_RETRY_PERMITTED, wall-budget half checked at schedule time.
        return (
            node.last_failure_class in self.retry_classes
            and node.latest < node.max_attempts
            and self.retry_reserve > 0
        )

    def node_settled(self, node):
        if node.skipped:
            return True
        if node.status in ("PENDING", "SCHEDULED", "DISPATCHED"):
            return False
        if node.status == "FAILED":
            return not self.retry_allowed(node)
        return node.status in self.settled_states

    def advance_ok_nonadj(self):
        # G_EXEC_SETTLED: started attempts must settle; required nodes must
        # settle or be skipped under cutoff; optional may stay PENDING.
        for n in self.nodes.values():
            if n.kind == "adjudicator":
                continue
            if n.attempts and not self.node_settled(n):
                return False
            if n.required and not n.attempts and not n.skipped:
                if self.cutoff:
                    self.skip(n)
                else:
                    return False
        return True

    def adj_settled(self):
        adjs = [n for n in self.nodes.values() if n.kind == "adjudicator"]
        if not adjs:
            return False
        for n in adjs:
            if not n.attempts and not n.skipped:
                if self.cutoff:
                    self.skip(n)
                else:
                    return False
            elif not self.node_settled(n):
                return False
        return True

    def skip(self, node):
        node.skipped = True
        self.degradations.append(f"node_skipped:{node.node_id}:budget_cutoff")

    # -- event application -----------------------------------------------

    def apply(self, event):
        if self.terminal:
            raise TraceError(f"event {event['event_id']} after terminal state")
        eid, kind = event["event_id"], event["event_kind"]
        payload = event.get("payload", {})
        at = event.get("at_min")
        if at is not None:
            if at < self.clock:
                raise TraceError(f"non-monotonic at_min on {eid}")
            self.clock = at
        h = body_hash(kind, event.get("node_id"), event.get("attempt"), payload)
        ident = (kind, eid)
        if ident in self.seen:
            if self.seen[ident] == h:
                return  # idempotent duplicate: no-op, no side effect (I3)
            self.corrupted = True  # conflicting body for known identity (R11)
            self.record("corruption_detected", self.phase, "FAILED")
            self.terminal = "FAILED"
            self.finalize_release()
            return
        self.seen[ident] = h

        if kind == "corruption_detected":
            self.corrupted = True
            self.record(eid, self.phase, "FAILED")
            self.terminal = "FAILED"
            self.finalize_release()
            return
        if kind == "cancel_requested":
            self.cancelling = True
        elif kind == "budget_exhausted":
            self.cutoff = True  # ADR-1 section 1.5a durable cutoff flag
            self.degradations.append("budget_exhausted:" + payload["dimension"])
        elif kind == "cancel_finalized":
            if not self.cancelling:
                raise TraceError("cancel_finalized without cancel_requested")
            if not all(self.node_settled(n) for n in self.nodes.values() if n.attempts):
                raise TraceError("cancel_finalized with unsettled attempts")
            self.record(eid, self.phase, "CANCELLED")
            self.terminal = "CANCELLED"
            self.finalize_release()
            return
        elif kind.startswith("node_"):
            self.apply_node_event(kind, event, payload)
        else:
            self.apply_run_event(eid, kind, payload)
        self.derive()

    def apply_run_event(self, eid, kind, payload):
        row = next(
            (r for r in self.run_rows if r["event"] == kind and r["from"] == self.phase),
            None,
        )
        if row is None:
            raise TraceError(f"invalid event {kind} in phase {self.phase}")
        if kind == "plan_resolved":
            self.load_plan(payload)
        dst = row["to"]
        self.record(eid, self.phase, dst)
        if dst in self.spec["terminals"]:
            self.terminal = dst
            self.finalize_release()
        else:
            self.phase = dst

    def load_plan(self, payload):
        self.profile = payload["profile"]
        self.policy_version = payload["policy_version"]
        budget = payload["budget"]
        self.retry_reserve = budget["retry_reserve"]
        self.wall_clock_min = budget["wall_clock_min"]
        self.deadlines = budget["deadlines"]
        for n in payload["nodes"]:
            self.nodes[n["node_id"]] = Node(n)

    def apply_node_event(self, kind, event, payload):
        node = self.nodes.get(event["node_id"])
        if node is None:
            raise TraceError(f"unknown node {event.get('node_id')}")
        if self.phase not in self.spec["node_event_phase_domain"][node.kind]:
            raise TraceError(f"{node.kind} event in phase {self.phase} ({node.node_id})")
        attempt = event["attempt"]
        state = node.attempts.get(attempt)
        row = next(
            (
                r
                for r in self.attempt_rows
                if r["event"] == kind and (node.attempts.get(node.latest) if node.attempts else None) in r["from"]
            ),
            None,
        ) if kind == "node_scheduled" else next(
            (r for r in self.attempt_rows if r["event"] == kind and state in r["from"]),
            None,
        )
        if row is None:
            raise TraceError(
                f"invalid {kind} for {node.node_id} attempt {attempt} in state {state}"
            )
        self.check_guards(row["guards"], node, attempt, kind, payload)

        if kind == "node_scheduled":
            if attempt != (node.latest or 0) + 1:
                raise TraceError(f"non-monotonic attempt on {node.node_id}")
            if attempt > 1:
                self.retry_reserve -= 1
        if kind == "node_dispatched":
            key = (node.node_id, attempt)
            if key not in self.dispatch_effects:
                self.dispatch_effects.add(key)  # at-most-once (I3)
            self.dispatch_at[key] = self.clock
        if kind == "node_failed":
            node.last_failure_class = payload["failure_class"]
            self.degradations.append(
                f"node_failed:{node.node_id}:{payload['failure_class']}"
            )
        if kind == "node_reconciled":
            node.last_failure_class = "transport_5xx"
            self.degradations.append(f"node_reconciled:{node.node_id}:transport_5xx")
        if kind == "node_cancelled":
            self.degradations.append(
                f"node_cancelled:{node.node_id}:{payload.get('reason', 'cancel')}"
            )
        if kind == "node_abandoned":
            self.degradations.append(f"node_abandoned:{node.node_id}")
        if kind == "node_result":
            self.consume_result(node, payload)
        node.attempts[attempt] = row["to"]

    def check_guards(self, guards, node, attempt, kind, payload):
        for g in guards:
            if g == "G_NO_CUTOFF":
                if self.cutoff or self.cancelling:
                    raise TraceError(f"{kind} on {node.node_id} after cutoff/cancel")
            elif g == "G_ATTEMPT_MONOTONIC":
                pass  # checked in apply_node_event
            elif g == "G_RETRY_PERMITTED":
                if not self.retry_allowed(node):
                    raise TraceError(f"retry not permitted on {node.node_id}")
                if self.wall_clock_min is None:
                    raise TraceError("retry before plan_resolved")
                pending_base = sum(
                    self.deadlines[n.kind]
                    for n in self.nodes.values()
                    if n.required
                    and n.node_id != node.node_id
                    and n.status in ("PENDING", "SCHEDULED", "DISPATCHED")
                )
                remaining = self.wall_clock_min - self.clock
                if remaining < self.deadlines[node.kind] + pending_base:
                    raise TraceError(
                        f"retry on {node.node_id} would consume required base budget"
                    )
            elif g == "G_WITHIN_DEADLINE":
                start = self.dispatch_at.get((node.node_id, attempt))
                if start is not None and self.clock - start > self.deadlines[node.kind]:
                    raise TraceError(
                        f"{node.node_id} attempt {attempt} exceeded deadline without timeout"
                    )
            elif g == "G_PROVEN_NON_ACCEPTANCE":
                if not payload.get("proven_non_acceptance"):
                    raise TraceError(f"node_reconciled without proof on {node.node_id}")

    def consume_result(self, node, payload):
        if node.kind == "finder":
            self.finder_candidates += len(payload.get("candidates", []))
            return  # evidence pipeline separation: candidates never reach decision
        if node.kind == "adjudicator":
            binding = payload.get("b_binding")
            if binding is None:
                raise TraceError(f"adjudicator {node.node_id} result without b_binding")
            if sorted(binding["considered_claim_ids"]) != sorted(
                binding["supplied_claim_ids"]
            ):
                raise TraceError("b_binding considered != supplied (envelope failure)")
            for adj in payload.get("adjudications", []):
                sev = adj["candidate_severity"]
                expected_level = self.ladder[sev["impact"]][sev["reachability"]]
                if sev["level"] != expected_level:
                    raise TraceError(
                        f"severity level {sev['level']} != ladder({sev['impact']},"
                        f"{sev['reachability']})={expected_level} (E7)"
                    )
                self.adjudications.append(adj)
                if adj["adjudication"] == "CONFIRMED":
                    self.canonical_finding_ids.append(adj["finding_id"])

    # -- derived transitions (machine-owned) -------------------------------

    def derive(self):
        if self.terminal:
            return
        if self.phase == "EXECUTING" and self.nodes and self.advance_ok_nonadj():
            self.record("derived:all_required_nodes_settled", "EXECUTING", "CONSOLIDATING")
            self.phase = "CONSOLIDATING"
            self.record("derived:consolidation_complete", "CONSOLIDATING", "ADJUDICATING")
            self.phase = "ADJUDICATING"
        if self.phase == "ADJUDICATING" and self.adj_settled():
            terminal = self.terminal_decision()
            self.record("derived:adjudication_settled", "ADJUDICATING", terminal)
            self.terminal = terminal
            self.finalize_release()

    def terminal_decision(self):
        # ADR-1 section 1.5, ordered. Only adjudicator output feeds rules 5-6.
        if self.corrupted:
            return "FAILED"
        if self.cancelling:
            return "CANCELLED"
        if any(n.required and n.status != "COMPLETED" for n in self.nodes.values()):
            return "INCOMPLETE"
        if self.profile == "HEAVY" and any(
            a["adjudication"] == "UNVERIFIABLE"
            and a["candidate_severity"]["level"] in ("HIGH", "CRITICAL")
            for a in self.adjudications
        ):
            return "INCOMPLETE"  # V2-SM-08
        return "COMPLETED"

    def finalize_release(self):
        if self.profile == "LIGHT":
            self.release_recommendation = "REPORT_ONLY"
        elif self.profile == "HEAVY":
            gating = any(
                a["candidate_severity"]["level"] in ("HIGH", "CRITICAL")
                and a["adjudication"] in GATING
                for a in self.adjudications
            )
            ok = self.terminal == "COMPLETED" and not gating
            self.release_recommendation = "PROCEED" if ok else "HOLD"
        else:
            self.release_recommendation = "HOLD"  # terminal before plan_resolved

    def coverage_gaps(self):
        gaps = []
        for n in self.nodes.values():
            if not n.required or n.status == "COMPLETED":
                continue
            if n.kind in ("probe", "finder"):
                gaps.append(f"{n.node_id}:no_envelope")
            elif n.kind == "adjudicator":
                gaps.append(f"{n.node_id}:no_adjudication")
        return gaps


def run_trace(trace, spec):
    machine = Machine(spec)
    if trace["initial_state"] != machine.phase:
        raise TraceError("initial_state mismatch")
    for event in trace["input_events"]:
        machine.apply(event)

    failures = []

    def check(name, expected, actual):
        if expected != actual:
            failures.append(f"{name}: expected {expected!r}, got {actual!r}")

    check("profile", trace["profile"], machine.profile)
    check("policy_version", trace["policy_version"], machine.policy_version)
    check("terminal", trace["expected_terminal"], machine.terminal)
    check(
        "release_recommendation",
        trace["expected_release_recommendation"],
        machine.release_recommendation,
    )
    check("transitions", trace["expected_transitions"], machine.transitions)
    actual_nodes = {n.node_id: n.status for n in machine.nodes.values()}
    check("node_states", trace["expected_node_states"], actual_nodes)
    check("degradations", sorted(trace["expected_degradations"]), sorted(machine.degradations))
    check(
        "coverage_gaps",
        sorted(trace["expected_coverage_gaps"]),
        sorted(machine.coverage_gaps()),
    )
    if "expected_canonical_finding_ids" in trace:
        check(
            "canonical_finding_ids",
            sorted(trace["expected_canonical_finding_ids"]),
            sorted(machine.canonical_finding_ids),
        )
    # Side effects: the runner performs none; dispatches are modelled and keyed
    # at-most-once per (node_id, attempt). Assert model consistency.
    dispatched = {
        (n.node_id, a)
        for n in machine.nodes.values()
        for a, st in n.attempts.items()
        if st in ("DISPATCHED", "COMPLETED", "FAILED", "ABANDONED")
        or (st == "CANCELLED" and (n.node_id, a) in machine.dispatch_at)
    }
    if machine.dispatch_effects != dispatched:
        failures.append("dispatch side-effect keying mismatch (duplicate dispatch?)")
    if trace.get("expected_ledger_head") is not None:
        failures.append("expected_ledger_head set but ledger hashing lands with ADR-5")
    if "forbidden_side_effects" not in trace:
        failures.append("forbidden_side_effects[] missing from fixture")
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, default=DEFAULT_SPEC)
    parser.add_argument(
        "--expect-fail",
        action="store_true",
        help="invert: every given trace must FAIL (mutant conformance)",
    )
    parser.add_argument("traces", nargs="+", type=Path)
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text())

    bad = 0
    for path in args.traces:
        trace = json.loads(path.read_text())
        try:
            failures = run_trace(trace, spec)
        except TraceError as exc:
            failures = [f"TraceError: {exc}"]
        name = trace.get("trace_id", path.name)
        if args.expect_fail:
            if failures:
                print(f"PASS (rejected as expected) {name}: {failures[0]}")
            else:
                bad += 1
                print(f"FAIL (mutant accepted!) {name}")
        elif failures:
            bad += 1
            print(f"FAIL {name}")
            for line in failures:
                print(f"  - {line}")
        else:
            print(f"PASS {name}")
    print(f"Traces: {len(args.traces) - bad} ok, {bad} not ok")
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
