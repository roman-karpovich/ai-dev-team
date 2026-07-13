#!/usr/bin/env python3
"""Deterministic trace runner for the v2 VERIFY state machine (ADR-1/2/3).

Replays a trace fixture's input events through a reference implementation of
the ADR-1 run/node state machine (tables loaded as data from
v2/spec/transitions.json) plus the ADR-2 evidence layer (claim registry,
control-plane-computed B input binding, machine-derived severity level,
REJECTED exclusivity coercion). No provider calls, no side effects, stdlib
only.

Usage:
  python3 v2/tools/trace_runner.py [--spec PATH] TRACE.json [...]
  python3 v2/tools/trace_runner.py --expect-fail MUTANT.json [...]

Exit 0 iff every trace passes (or, with --expect-fail, every mutant fails —
matching its `expect_failure_containing` when present).
"""

import argparse
import hashlib
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent.parent
DEFAULT_SPEC = REPO_ROOT / "v2" / "spec" / "transitions.json"

GATING = ("CONFIRMED", "UNRESOLVED", "UNVERIFIABLE")
LEDGER_FORMAT_VERSION = "v2-verify-1"
SUPPORTED_LEDGER_VERSIONS = {"v2-verify-1"}
LEDGER_GENESIS = "GENESIS/v2-verify"


def canonical(obj):
    return json.dumps(obj, sort_keys=True, separators=(",", ":"))


def sha(text):
    return hashlib.sha256(text.encode()).hexdigest()


def body_hash(kind, node_id, attempt, payload):
    return sha(canonical(
        {"event_kind": kind, "node_id": node_id, "attempt": attempt, "payload": payload}
    ))


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
        self.snapshot_id = None
        self.run_id = None
        self.claims = {}  # claim_id -> claim record (registry, ADR-2)
        self.proposals = set()  # model-proposed observations awaiting re-read
        self.adjudications = []
        self.candidate_dispositions = []
        self.canonical_finding_ids = []
        self.degradations = []
        self.transitions = []
        self.node_transitions = []
        self.side_effect_kinds = set()
        self.seen = {}
        self.dispatch_effects = set()
        self.dispatch_at = {}
        self.ledger = []      # ADR-5 hash-chained records
        self.ledger_seal = None
        self.no_seal = False  # set when the source journal is corrupt/unsupported
        self.audit_chain = []  # post-terminal / recovery audit records
        self.block_code = None
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

    def record_node(self, node, attempt, on, dst):
        self.node_transitions.append(
            {"node_id": node.node_id, "attempt": attempt, "on": on, "to": dst}
        )

    def retry_fully_permitted(self, node):
        """Complete N7 predicate — used by BOTH the schedule guard and the
        settled derivation (a FAILED node with no permissible retry is settled).
        Includes the cutoff/cancel flags: after cutoff a retryable failure is
        settled, never stuck unretryable-yet-unsettled (liveness)."""
        if self.cutoff or self.cancelling:
            return False
        if node.last_failure_class not in self.retry_classes:
            return False
        if node.latest >= node.max_attempts or self.retry_reserve < 1:
            return False
        if self.wall_clock_min is None:
            return False
        pending_base = sum(
            self.deadlines[n.kind]
            for n in self.nodes.values()
            if n.required
            and n.node_id != node.node_id
            and n.status in ("PENDING", "SCHEDULED", "DISPATCHED")
        )
        return self.wall_clock_min - self.clock >= self.deadlines[node.kind] + pending_base

    def node_settled(self, node):
        if node.skipped:
            return True
        if node.status in ("PENDING", "SCHEDULED", "DISPATCHED"):
            return False
        if node.status == "FAILED":
            return not self.retry_fully_permitted(node)
        return node.status in self.settled_states

    def advance_ok_nonadj(self):
        ok = True
        for n in self.nodes.values():
            if n.kind == "adjudicator":
                continue
            if n.attempts and not self.node_settled(n):
                ok = False
                continue
            if not n.attempts and not n.skipped:
                if self.cutoff:
                    self.skip(n)  # ADR-1 1.5a: EVERY unstarted node, optional too
                elif n.required:
                    ok = False
        return ok

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
        # N9: machine-generated PENDING -> SKIPPED under cutoff (journaled).
        node.skipped = True
        self.record_node(node, 0, "node_skipped", "SKIPPED")
        self.degradations.append(f"node_skipped:{node.node_id}:budget_cutoff")

    # -- ADR-2 evidence layer (control-plane side) --------------------------

    def register_claims(self, claim_list, producer):
        for c in claim_list:
            for field in ("claim_id", "claim_class", "subject", "asserted_value"):
                if field not in c:
                    raise TraceError(f"claim missing {field}")
            cid = c["claim_id"]
            if cid in self.claims:
                raise TraceError(f"duplicate claim_id {cid}")
            if producer == "CONTROL_PLANE" and cid.startswith("cp-"):
                if c.get("snapshot_id") != self.snapshot_id:
                    raise TraceError(f"re-read claim {cid} not bound to run snapshot")
            # ADR-5 §1.6 claim-field lift (enforced for EVERY claim, not only cp-):
            # bind to the containing ledger record + run inputs + trust domain.
            created_at_seq = len(self.ledger) - 1
            record_refs = self.ledger[-1]["artifact_refs"] if self.ledger else []
            if any(r not in record_refs for r in c.get("artifact_refs", [])):
                raise TraceError(f"claim {cid} refs bytes its record did not commit")
            self.claims[cid] = {
                "relationship": "supports", **c, "producer": producer,
                "created_at_seq": created_at_seq,
                "snapshot_id": c.get("snapshot_id", self.snapshot_id),
                "execution_manifest_id": "em:" + (self.run_id or "?"),
                "trust_domain": {"name": producer,
                                 "instance": f"{producer}:{self.run_id}",
                                 "shared_dependencies": []},
            }

    # B adjudicates on the SEMANTIC claim content, not bookkeeping metadata
    # (created_at_seq, trust_domain, manifest ids). The binding pins that
    # content set; lift metadata is enforced separately at registration.
    B_PROJECTION = ("claim_id", "claim_class", "subject", "asserted_value",
                    "relationship", "producer")

    def b_input(self):
        supplied = sorted(self.claims)
        proj = [{k: self.claims[c][k] for k in self.B_PROJECTION} for c in supplied]
        return supplied, sha(canonical(proj))

    # -- ADR-5 ledger (append-only, corruption-evident) --------------------

    CORE_FIELDS = ("format_version", "seq", "prev_hash", "kind", "event_id",
                   "body_digest", "artifact_refs")

    def ledger_append(self, kind, event_id, body_digest, artifact_refs=None):
        seq = len(self.ledger)
        prev = self.ledger[-1]["record_hash"] if self.ledger else LEDGER_GENESIS
        rec = {"format_version": LEDGER_FORMAT_VERSION, "seq": seq, "prev_hash": prev,
               "kind": kind, "event_id": event_id, "body_digest": body_digest,
               "artifact_refs": artifact_refs or []}
        rec["record_hash"] = sha(canonical({k: rec[k] for k in self.CORE_FIELDS}))
        self.ledger.append(rec)

    def verify_chain(self):
        prev = LEDGER_GENESIS
        for i, rec in enumerate(self.ledger):
            if rec["seq"] != i or rec["prev_hash"] != prev:
                return False
            if rec["format_version"] not in SUPPORTED_LEDGER_VERSIONS:
                return False
            core = {k: rec[k] for k in self.CORE_FIELDS}
            if rec["record_hash"] != sha(canonical(core)):
                return False
            prev = rec["record_hash"]
        return True

    def seal(self):
        # ADR-5 §1.2: the seal is a real appended record + a persisted sidecar,
        # created immediately at terminal (idempotent). run_id binds it to the run.
        # A corrupt/unsupported SOURCE journal is never sealed (self.no_seal).
        if (self.ledger_seal is None and self.terminal is not None
                and self.ledger and not self.no_seal):
            head_hash = self.ledger[-1]["record_hash"]
            self.ledger_append("terminal_seal", "seal",
                               sha(canonical({"run_id": self.run_id, "head_hash": head_hash})))
            seal_rec = self.ledger[-1]
            self.ledger_seal = {"run_id": self.run_id, "terminal_seq": seal_rec["seq"],
                                "head_hash": seal_rec["record_hash"]}

    def audit_append(self, kind, payload):
        # Separate hash-chained post-terminal/recovery audit trail (ADR-5): it
        # is NOT the sealed run ledger, but it is corruption-evident on its own.
        seq = len(self.audit_chain)
        prev = self.audit_chain[-1]["record_hash"] if self.audit_chain else "AUDIT-GENESIS/v2-verify"
        rec = {"seq": seq, "prev_hash": prev, "kind": kind,
               "digest": sha(canonical(payload))}
        rec["record_hash"] = sha(canonical(rec))
        self.audit_chain.append(rec)

    def audit_head(self):
        return self.audit_chain[-1]["record_hash"] if self.audit_chain else None

    # -- event application -----------------------------------------------

    def apply(self, event):
        eid, kind = event["event_id"], event["event_kind"]
        payload = event.get("payload", {})
        if self.terminal:
            # Post-terminal: only a late result for a settled attempt is allowed;
            # it is journaled as inadmissible, never accepted (ADR-1 1.6).
            if kind == "late_result_rejected":
                # ADR-1 §1.6 / ADR-5: journaled to a SEPARATE post-terminal audit
                # chain (the main ledger is sealed); inadmissible, never accepted.
                self.audit_append(kind, {"node_id": event["node_id"], "attempt": event["attempt"]})
                self.degradations.append(
                    f"late_result_rejected:{event['node_id']}:{event['attempt']}"
                )
                return
            raise TraceError(f"event {eid} after terminal state")
        # Identity/idempotency FIRST: an exact duplicate is a total no-op —
        # it must not advance even the virtual clock (ADR-1 I3).
        h = body_hash(kind, event.get("node_id"), event.get("attempt"), payload)
        ident = (kind, eid)
        if ident in self.seen:
            if self.seen[ident] == h:
                return
            self.corrupted = True
            self.record("corruption_detected", self.phase, "FAILED")
            self.terminal = "FAILED"
            self.finalize_release()
            return
        self.seen[ident] = h
        at = event.get("at_min")
        if at is not None:
            if at < self.clock:
                raise TraceError(f"non-monotonic at_min on {eid}")
            self.clock = at

        if kind == "__tamper_ledger__":
            # TEST-ONLY fault injection (NOT a production event, ADR-5 §3):
            # flip a stored record's hash so verify_chain() must catch it.
            self.ledger[payload["seq"]]["record_hash"] = "TAMPERED"
            return
        if kind == "journal_resume":
            # ADR-5 §1.4 / §1.3: verify the SOURCE journal BEFORE trusting or
            # appending anything. A corrupt/unsupported source is NEVER modified —
            # not even sealed; the recovery outcome goes to the audit chain.
            if payload["format_version"] not in SUPPORTED_LEDGER_VERSIONS:
                self.no_seal = True  # never rewrite/seal an unsupported source
                self.audit_append("recovery_blocked", {"reason": "SCHEMA_VERSION",
                                                       "found_version": payload["format_version"]})
                self.record(eid, self.phase, "BLOCKED")
                self.terminal = "BLOCKED"
                self.block_code = "SCHEMA_VERSION"
                self.finalize_release()
                return
            if not self.verify_chain():
                self.no_seal = True  # never rewrite/seal a corrupt source
                self.audit_append("recovery_corruption", {"reason": "CHAIN_BROKEN"})
                self.corrupted = True
                self.record("corruption_detected", self.phase, "FAILED")
                self.terminal = "FAILED"
                self.finalize_release()
                return
            self.ledger_append(kind, eid, h, payload.get("artifact_refs"))
            return
        # Every real event is journaled (ADR-5 §1.1). The ledger is the
        # transport-of-record; downstream reads it, never the raw stream.
        self.ledger_append(kind, eid, h, payload.get("artifact_refs"))

        if kind == "corruption_detected":
            self.corrupted = True
            self.record(eid, self.phase, "FAILED")
            self.terminal = "FAILED"
            self.finalize_release()
            return
        if kind == "cancel_requested":
            self.cancelling = True
        elif kind == "claims_reread":
            # Control-plane re-read receipt: the ONLY path by which an
            # observation becomes machine-produced (ADR-2 1.2). Never taken
            # from a model envelope.
            if self.phase not in ("EXECUTING", "CONSOLIDATING"):
                raise TraceError(f"claims_reread in phase {self.phase}")
            for c in payload["claims"]:
                if not c["claim_id"].startswith("cp-"):
                    raise TraceError("control-plane claim without cp- prefix")
                if c["claim_class"] == "artifact_observation":
                    # Provenance: a re-read observation exists only as the
                    # verification of a finder-proposed locator (ADR-2 1.2).
                    ref = c.get("reread_of")
                    if ref is None or ref not in self.proposals:
                        raise TraceError(
                            f"cp observation {c['claim_id']} without a pending proposal"
                        )
                    if self.claims[ref]["subject"] != c["subject"]:
                        raise TraceError(
                            f"reread subject mismatch: {c['claim_id']} vs proposal {ref}"
                        )
                    self.proposals.discard(ref)
            self.register_claims(payload["claims"], "CONTROL_PLANE")
        elif kind == "budget_exhausted":
            if (
                payload["dimension"] == "wall_clock"
                and self.wall_clock_min is not None
                and self.clock < self.wall_clock_min
            ):
                raise TraceError("premature wall_clock exhaustion")
            self.cutoff = True  # ADR-1 1.5a durable cutoff flag (R9b)
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
        if kind == "snapshot_sealed":
            self.snapshot_id = payload["snapshot_id"]
            self.run_id = "run:" + payload["snapshot_id"]
            self.register_claims(
                [{"claim_id": "mc-snapshot", "claim_class": "snapshot_binding",
                  "subject": "run", "asserted_value": payload["snapshot_id"]}],
                "CONTROL_PLANE",
            )
        if kind == "plan_resolved":
            self.load_plan(payload)
            self.register_claims(
                [{"claim_id": "mc-policy", "claim_class": "policy_resolution",
                  "subject": "run", "asserted_value": payload["policy_version"]}],
                "CONTROL_PLANE",
            )
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
        from_state = (
            node.attempts.get(node.latest) if kind == "node_scheduled" and node.attempts
            else node.attempts.get(attempt)
        ) if kind == "node_scheduled" else node.attempts.get(attempt)
        row = next(
            (
                r
                for r in self.attempt_rows
                if r["event"] == kind and from_state in r["from"]
            ),
            None,
        )
        if row is None:
            raise TraceError(
                f"invalid {kind} for {node.node_id} attempt {attempt} in state {from_state}"
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
                self.side_effect_kinds.add("provider_dispatch")
            self.dispatch_at[key] = self.clock
        if kind == "node_failed":
            node.last_failure_class = payload["failure_class"]
            self.degradations.append(
                f"node_failed:{node.node_id}:{payload['failure_class']}"
            )
        if kind == "node_reconciled":
            # N8: proven non-acceptance -> FAILED(transport_5xx), N7-eligible.
            node.last_failure_class = "transport_5xx"
            self.degradations.append(f"node_reconciled:{node.node_id}:transport_5xx")
        if kind == "node_cancelled":
            self.degradations.append(
                f"node_cancelled:{node.node_id}:{payload.get('reason', 'cancel')}"
            )
        if kind == "node_abandoned":
            self.degradations.append(f"node_abandoned:{node.node_id}")
        to_state = row["to"]
        on = kind
        if kind == "node_result":
            derived_fail = self.consume_result(node, payload)
            if derived_fail is not None:
                # Machine validation, replaying the JOURNALED node_result envelope,
                # DERIVES an integrity failure (ADR-2 §1.4). The attempt is an
                # explicit N4 node_failed (not a silent N3->FAILED), recorded in the
                # transition log as a deterministic consequence of the journaled
                # result — reconstructible on replay, so it needs no separate record.
                node.last_failure_class = derived_fail
                self.degradations.append(f"node_failed:{node.node_id}:{derived_fail}")
                to_state = "FAILED"
                on = "node_failed"  # N4, machine-derived from the journaled result
        node.attempts[attempt] = to_state
        self.record_node(node, attempt, on, to_state)

    def check_guards(self, guards, node, attempt, kind, payload):
        for g in guards:
            if g == "G_NO_CUTOFF":
                if self.cutoff or self.cancelling:
                    raise TraceError(f"{kind} on {node.node_id} after cutoff/cancel")
            elif g == "G_ATTEMPT_MONOTONIC":
                pass  # checked in apply_node_event
            elif g == "G_RETRY_PERMITTED":
                if not self.retry_fully_permitted(node):
                    raise TraceError(f"retry not permitted on {node.node_id}")
            elif g == "G_WITHIN_DEADLINE":
                start = self.dispatch_at.get((node.node_id, attempt))
                if start is not None and self.clock - start > self.deadlines[node.kind]:
                    raise TraceError(
                        f"{node.node_id} attempt {attempt} result past deadline"
                    )
            elif g == "G_PROVEN_NON_ACCEPTANCE":
                if not payload.get("proven_non_acceptance"):
                    raise TraceError(f"node_reconciled without proof on {node.node_id}")

    def consume_result(self, node, payload):
        if node.kind == "probe":
            return
        if node.kind == "finder":
            for cand in payload.get("candidates", []):
                self.register_claims(cand.get("claims", []), "MODEL_CONTEXT")
                for c in cand.get("claims", []):
                    if c["claim_class"] == "artifact_observation":
                        self.proposals.add(c["claim_id"])
            return
        # adjudicator: verify B binding against control-plane-computed input.
        binding = payload.get("b_binding")
        if binding is None:
            raise TraceError(f"adjudicator {node.node_id} result without b_binding")
        supplied, input_hash = self.b_input()
        # A binding that references a stale/wrong claim set is an envelope-level
        # integrity failure DERIVED by machine validation (ADR-2 §1.4) -> the
        # attempt FAILS with stale_binding. Not a trusted supplied label.
        if sorted(binding["supplied_claim_ids"]) != supplied:
            return "stale_binding"
        if binding["input_claim_set_hash"] != input_hash:
            return "stale_binding"
        if sorted(binding["considered_claim_ids"]) != supplied:
            raise TraceError("b_binding considered != supplied (envelope failure)")
        for adj in payload.get("adjudications", []):
            sev = adj["candidate_severity"]
            if "level" in sev:
                raise TraceError("model-supplied severity level (E7)")
            for cid in adj.get("observation_claim_ids", []) + adj.get(
                "rationale_claim_ids", []
            ):
                if cid not in self.claims:
                    raise TraceError(f"adjudication cites unknown claim {cid}")
            verdict = adj["adjudication"]
            if verdict == "REJECTED":
                verdict = self.check_rejection(adj)
            if verdict == "CONFIRMED" and not any(
                self.claims[o]["producer"] == "CONTROL_PLANE"
                and self.claims[o]["claim_class"]
                in ("artifact_observation", "command_execution")
                for o in adj.get("observation_claim_ids", [])
            ):
                raise TraceError(
                    f"CONFIRMED {adj['finding_id']} without an admissible machine observation (E3)"
                )
            entry = {
                "finding_id": adj["finding_id"],
                "adjudication": verdict,
                "level": self.ladder[sev["impact"]][sev["reachability"]],
            }
            self.adjudications.append(entry)
            if verdict == "CONFIRMED":
                self.canonical_finding_ids.append(adj["finding_id"])
            else:
                coerced = verdict != adj["adjudication"]
                self.candidate_dispositions.append({
                    "finding_id": adj["finding_id"],
                    "adjudication": verdict,
                    "reason_code": (
                        "rejected_without_mechanical_contradiction"
                        if coerced
                        else adj.get("reason_code", "insufficient_evidence")
                    ),
                    "rationale_claim_ids": adj.get("rationale_claim_ids", []),
                })

    def check_rejection(self, adj):
        """ADR-2 1.5: REJECTED needs a machine-verified exclusive contradiction;
        otherwise the verdict is coerced to UNRESOLVED (journaled)."""
        cid = adj.get("contradiction_claim_id")
        contradiction = self.claims.get(cid) if cid else None
        ok = (
            contradiction is not None
            and contradiction["producer"] == "CONTROL_PLANE"
            and contradiction["claim_class"] in ("artifact_observation", "command_execution")
            and contradiction.get("relationship") == "contradicts"
            and contradiction.get("snapshot_id") == self.snapshot_id
            and any(
                self.claims[o]["claim_class"] == contradiction["claim_class"]
                and self.claims[o]["subject"] == contradiction["subject"]
                and self.claims[o]["asserted_value"] != contradiction["asserted_value"]
                for o in adj.get("observation_claim_ids", [])
                if o in self.claims
            )
        )
        if ok:
            return "REJECTED"
        self.degradations.append(f"verdict_coerced:{adj['finding_id']}:UNRESOLVED")
        return "UNRESOLVED"

    # -- derived transitions (machine-owned) -------------------------------

    def derive(self):
        if self.terminal:
            return
        if self.phase == "EXECUTING" and self.nodes and self.advance_ok_nonadj():
            self.record("derived:all_required_nodes_settled", "EXECUTING", "CONSOLIDATING")
            self.phase = "CONSOLIDATING"
        if self.phase == "CONSOLIDATING" and (not self.proposals or self.cutoff):
            # Consolidation holds until every model proposal has a control-plane
            # re-read (arrival-order independence); cutoff releases the hold —
            # the run terminates INCOMPLETE anyway.
            self.record("derived:consolidation_complete", "CONSOLIDATING", "ADJUDICATING")
            self.phase = "ADJUDICATING"
        if self.phase == "ADJUDICATING" and self.adj_settled():
            terminal = self.terminal_decision()
            self.record("derived:adjudication_settled", "ADJUDICATING", terminal)
            self.terminal = terminal
            self.finalize_release()

    def terminal_decision(self):
        if self.corrupted:
            return "FAILED"
        if self.cancelling:
            return "CANCELLED"
        if any(n.required and n.status != "COMPLETED" for n in self.nodes.values()):
            return "INCOMPLETE"
        if self.cutoff:
            return "INCOMPLETE"  # budget exhaustion NEVER -> COMPLETED, even if
            # every in-flight required node settles successfully afterwards
        if self.profile == "HEAVY" and any(
            a["adjudication"] == "UNVERIFIABLE" and a["level"] in ("HIGH", "CRITICAL")
            for a in self.adjudications
        ):
            return "INCOMPLETE"  # V2-SM-08
        return "COMPLETED"

    def finalize_release(self):
        if self.profile == "LIGHT":
            self.release_recommendation = "REPORT_ONLY"
        elif self.profile == "HEAVY":
            gating = any(
                a["level"] in ("HIGH", "CRITICAL") and a["adjudication"] in GATING
                for a in self.adjudications
            )
            ok = self.terminal == "COMPLETED" and not gating
            self.release_recommendation = "PROCEED" if ok else "HOLD"
        else:
            self.release_recommendation = "HOLD"
        self.seal()  # ADR-5 §1.2: seal immediately at terminal (idempotent)

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
    machine.seal()

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
    if "expected_candidate_dispositions" in trace:
        def keyfn(d):
            return (d["finding_id"], d["adjudication"])
        check(
            "candidate_dispositions",
            sorted(trace["expected_candidate_dispositions"], key=keyfn),
            sorted(machine.candidate_dispositions, key=keyfn),
        )
    if "expected_attempt_transitions" in trace:
        check(
            "attempt_transitions",
            trace["expected_attempt_transitions"],
            machine.node_transitions,
        )
    forbidden = set(trace.get("forbidden_side_effects", []))
    if "forbidden_side_effects" not in trace:
        failures.append("forbidden_side_effects[] missing from fixture")
    elif machine.side_effect_kinds & forbidden:
        failures.append(
            f"forbidden side effects occurred: {sorted(machine.side_effect_kinds & forbidden)}"
        )
    dispatched = {
        (n.node_id, a)
        for n in machine.nodes.values()
        for a in n.attempts
        if (n.node_id, a) in machine.dispatch_at
    }
    if machine.dispatch_effects != dispatched:
        failures.append("dispatch side-effect keying mismatch (duplicate dispatch?)")
    # ADR-5 ledger integrity: a standing check on every trace (structural, not
    # an opaque hardcoded hash — verify_chain recomputes the chain).
    if "expected_ledger_length" in trace:
        check("ledger_length", trace["expected_ledger_length"], len(machine.ledger))
    if "expected_ledger_intact" in trace:
        # A run that ended FAILED on corruption legitimately has a broken chain.
        check("ledger_intact", trace["expected_ledger_intact"], machine.verify_chain())
    if "expected_ledger_sealed" in trace:
        check("ledger_sealed", trace["expected_ledger_sealed"], machine.ledger_seal is not None)
    if "expected_ledger_head" in trace:
        # Independently computed known-answer (the fixture generator recomputes
        # the chain from the ADR-5 spec, not from this runner's code path).
        head = machine.ledger_seal["head_hash"] if machine.ledger_seal else None
        check("ledger_head", trace["expected_ledger_head"], head)
    if "expected_block_code" in trace:
        check("block_code", trace["expected_block_code"], machine.block_code)
    if "expected_audit_length" in trace:
        check("audit_length", trace["expected_audit_length"], len(machine.audit_chain))
    return failures


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, default=DEFAULT_SPEC)
    parser.add_argument(
        "--expect-fail",
        action="store_true",
        help="invert: every given trace must FAIL, matching its expect_failure_containing",
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
            want = trace.get("expect_failure_containing")
            if not failures:
                bad += 1
                print(f"FAIL (mutant accepted!) {name}")
            elif want and not any(want in f for f in failures):
                bad += 1
                print(f"FAIL (wrong rejection) {name}: wanted {want!r}, got {failures[0]!r}")
            else:
                print(f"PASS (rejected as expected) {name}: {failures[0]}")
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
