#!/usr/bin/env bash
# probe_h.sh — Probe H — typosquatting detector.
#
# stdin envelope:
#   {
#     "diff": {"added_lines": {"<relpath>": [lineno, ...], ...}},
#     "changed_python_files": ["<relpath>", ...],
#     "changed_yaml_files": ["<relpath>", ...],
#     "repo_root": "<abs-or-relative-path>",
#     "audit_slug": "<slug>",
#     "base_ref": "<ref>",
#     "mode": "off|shadow|warn|block"
#   }
#
# stdout:
#   {
#     "findings": [{provisional_id, sources, severity, title, file,
#                    description, fix, fingerprint_anchors, canonical_payload}, ...],
#     "receipt_metadata": {probe_id, probe_version, trigger_input_hash,
#                           scope_files_read, skipped_files, emitted_at,
#                           degraded_mode, eligible_reason}
#   }
#
# Radaro AI-Assisted Development Policy v1.3 §8.2 calls out typosquatting
# as a dependency-layer supply-chain risk class.
#
# Determinism seam: when PROBE_H_FAKE_NOW env var is set, receipt_metadata's
# emitted_at uses that value verbatim (for fixtures + smoke). Otherwise uses
# current UTC ISO-8601 with trailing "Z".
#
# Per-file parse error → skip the file, append its relpath to skipped_files,
# continue with other files. Whole-probe uncaught exception → exit non-zero
# with stderr diagnostic; orchestrator fails-open.
#
# python3 stdlib only.

set -euo pipefail

STDIN_PAYLOAD=$(cat)
PROBE_H_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

STDIN_PAYLOAD="$STDIN_PAYLOAD" PROBE_H_SCRIPT_DIR="$PROBE_H_SCRIPT_DIR" python3 <<'PY'
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone


PROBE_ID = "H"
PROBE_VERSION = "h.1.0"

LOCKFILE_NAMES = frozenset({
    "requirements.txt",
    "Pipfile.lock",
    "package-lock.json",
    "yarn.lock",
    "pnpm-lock.yaml",
    "Cargo.lock",
    "go.sum",
})

RE_REQUIREMENTS = re.compile(
    r"^([A-Za-z0-9_.-]+)(?:\[[^\]]*\])?\s*==\s*([0-9]+)(?:[.+\s!;#]|$)"
)
RE_YARN_ENTRY = re.compile(r'^"?([A-Za-z0-9@_.-][A-Za-z0-9@/_.-]*)@')
RE_YARN_VERSION = re.compile(r'^\s+version\s+"([^"]+)"')
RE_PNPM_PACKAGE = re.compile(r"^\s{2}/([^/@][^@:\s]*|@[^/]+/[^@:\s]+)@([^:\s]+):")
RE_GO_SUM = re.compile(r"^(\S+)\s+v([0-9]+(?:\.[0-9A-Za-z_.-]+)*)")
RE_CARGO_NAME = re.compile(r'^name\s*=\s*"([^"]+)"')
RE_CARGO_VERSION = re.compile(r'^version\s*=\s*"([^"]+)"')


def die(msg, code=2):
    sys.stderr.write(f"probe_h.sh: {msg}\n")
    sys.exit(code)


def emitted_at_now():
    emitted_at = os.environ.get("PROBE_H_FAKE_NOW")
    if not emitted_at:
        emitted_at = datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")
    return emitted_at


def emit(findings, trigger_input_hash, scope_files_read, skipped_files,
         eligible_reason):
    receipt_metadata = {
        "probe_id": PROBE_ID,
        "probe_version": PROBE_VERSION,
        "trigger_input_hash": trigger_input_hash,
        "scope_files_read": scope_files_read,
        "skipped_files": skipped_files,
        "emitted_at": emitted_at_now(),
        "degraded_mode": False,
        "eligible_reason": eligible_reason,
    }
    out = {"findings": findings, "receipt_metadata": receipt_metadata}
    sys.stdout.write(
        json.dumps(out, sort_keys=True, separators=(",", ":"), ensure_ascii=False)
        + "\n"
    )


def to_relpath(repo_root, abs_path):
    rel = os.path.relpath(abs_path, repo_root)
    rel = rel.replace(os.sep, "/")
    root = repo_root.replace(os.sep, "/").rstrip("/")
    if root in ("", "."):
        return rel
    return root + "/" + rel


def has_changed_lockfile(changed_python_files, changed_yaml_files):
    for rel in changed_python_files + changed_yaml_files:
        if os.path.basename(str(rel)) in LOCKFILE_NAMES:
            return True
    return False


def find_lockfiles(repo_root):
    lockfiles = []
    for root, _dirs, files in os.walk(repo_root):
        for name in sorted(files):
            if name in LOCKFILE_NAMES:
                abs_path = os.path.join(root, name)
                lockfiles.append((to_relpath(repo_root, abs_path), abs_path, name))
    lockfiles.sort(key=lambda item: item[0])
    return lockfiles


def load_corpus():
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT", "")
    if plugin_root:
        corpus_path = os.path.join(plugin_root, "hooks", "lib",
                                   "freshness_corpus.json")
    else:
        corpus_path = os.path.join(
            os.environ.get("PROBE_H_SCRIPT_DIR", "."),
            "freshness_corpus.json"
        )
    try:
        with open(corpus_path, "r", encoding="utf-8") as fh:
            corpus = json.load(fh)
    except (IOError, OSError, json.JSONDecodeError) as exc:
        die(f"failed to load freshness corpus at {corpus_path}: {exc}")
    if not isinstance(corpus, dict):
        die("freshness corpus must be a JSON object")
    return corpus


def parse_requirements(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        for line in fh:
            match = RE_REQUIREMENTS.search(line.strip())
            if match:
                parsed.append(("pypi", match.group(1).lower(), match.group(2)))
    return parsed


def parse_pipfile_lock(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)
    for section in ("default", "develop"):
        packages = data.get(section) or {}
        if not isinstance(packages, dict):
            continue
        for package, meta in packages.items():
            if not isinstance(meta, dict):
                continue
            version = meta.get("version")
            if isinstance(version, str) and version.startswith("=="):
                parsed.append(("pypi", package.lower(), version[2:]))
    return parsed


def parse_package_lock(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        data = json.load(fh)

    packages = data.get("packages") or {}
    if isinstance(packages, dict):
        root = packages.get("") or {}
        if isinstance(root, dict):
            dependencies = root.get("dependencies") or {}
            if isinstance(dependencies, dict):
                for package, version in dependencies.items():
                    if isinstance(version, str):
                        parsed.append(("npm", package, version))

    dependencies = data.get("dependencies") or {}
    if isinstance(dependencies, dict):
        for package, meta in dependencies.items():
            if isinstance(meta, dict) and isinstance(meta.get("version"), str):
                parsed.append(("npm", package, meta["version"]))
    return parsed


def parse_yarn_lock(abs_path):
    parsed = []
    current_package = None
    with open(abs_path, "r", encoding="utf-8") as fh:
        for raw_line in fh:
            line = raw_line.rstrip("\n")
            if line and not line.startswith((" ", "\t")):
                match = RE_YARN_ENTRY.search(line)
                current_package = None
                if match:
                    current_package = match.group(1)
                    if current_package.startswith("@") and "@" in current_package[1:]:
                        current_package = current_package.rsplit("@", 1)[0]
                    elif "@" in current_package:
                        current_package = current_package.split("@", 1)[0]
            elif current_package:
                version_match = RE_YARN_VERSION.search(line)
                if version_match:
                    parsed.append(("npm", current_package, version_match.group(1)))
                    current_package = None
    return parsed


def parse_pnpm_lock(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        for line in fh:
            match = RE_PNPM_PACKAGE.search(line.rstrip("\n"))
            if match:
                parsed.append(("npm", match.group(1), match.group(2)))
    return parsed


def parse_cargo_lock(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        content = fh.read()
    for block in content.split("[[package]]"):
        name = None
        version = None
        for raw_line in block.splitlines():
            line = raw_line.strip()
            name_match = RE_CARGO_NAME.search(line)
            if name_match:
                name = name_match.group(1)
                continue
            version_match = RE_CARGO_VERSION.search(line)
            if version_match:
                version = version_match.group(1)
        if name and version:
            parsed.append(("cargo", name, version))
    return parsed


def parse_go_sum(abs_path):
    parsed = []
    with open(abs_path, "r", encoding="utf-8") as fh:
        for line in fh:
            match = RE_GO_SUM.search(line.strip())
            if match:
                parsed.append(("go", match.group(1), match.group(2)))
    return parsed


def parse_lockfile(abs_path, name):
    if name == "requirements.txt":
        return parse_requirements(abs_path)
    if name == "Pipfile.lock":
        return parse_pipfile_lock(abs_path)
    if name == "package-lock.json":
        return parse_package_lock(abs_path)
    if name == "yarn.lock":
        return parse_yarn_lock(abs_path)
    if name == "pnpm-lock.yaml":
        return parse_pnpm_lock(abs_path)
    if name == "Cargo.lock":
        return parse_cargo_lock(abs_path)
    if name == "go.sum":
        return parse_go_sum(abs_path)
    return []


def levenshtein(a, b):
    if len(a) < len(b):
        a, b = b, a
    if not b:
        return len(a)
    prev = list(range(len(b) + 1))
    for i, ca in enumerate(a):
        curr = [i + 1]
        for j, cb in enumerate(b):
            cost = 0 if ca == cb else 1
            curr.append(min(curr[-1] + 1, prev[j + 1] + 1, prev[j] + cost))
        prev = curr
    return prev[-1]


raw = os.environ.get("STDIN_PAYLOAD", "")
trigger_input_hash = hashlib.sha256(raw.encode("utf-8")).hexdigest()

try:
    payload = json.loads(raw)
except json.JSONDecodeError as exc:
    die(f"stdin is not valid JSON: {exc}")

if not isinstance(payload, dict):
    die("stdin JSON must be an object")

repo_root = payload.get("repo_root") or "."
mode = payload.get("mode") or "shadow"
changed_python_files = payload.get("changed_python_files") or []
changed_yaml_files = payload.get("changed_yaml_files") or []
audit_slug = payload.get("audit_slug")
base_ref = payload.get("base_ref")

if not isinstance(changed_python_files, list):
    die("changed_python_files must be a list")
if not isinstance(changed_yaml_files, list):
    die("changed_yaml_files must be a list")

_ = (audit_slug, base_ref)

lockfiles = find_lockfiles(repo_root) if os.path.isdir(repo_root) else []
diff = payload.get("diff") or {}
added_lines = diff.get("added_lines") or {}
if isinstance(added_lines, dict) and added_lines:
    diff_keys = set(added_lines.keys())
    lockfiles = [
        (rel, abs_path, name)
        for (rel, abs_path, name) in lockfiles
        if os.path.relpath(abs_path, repo_root).replace(os.sep, "/") in diff_keys
    ]
if mode == "off" or (
        not lockfiles and not has_changed_lockfile(changed_python_files,
                                                   changed_yaml_files)):
    emit([], trigger_input_hash, [], [], "no lockfile changes in diff")
    sys.exit(0)

corpus = load_corpus()
scope_files_read = []
skipped_files = []
findings = []
seen_findings = set()
all_pinned = []

for rel, abs_path, name in lockfiles:
    try:
        pinned = parse_lockfile(abs_path, name)
    except (IOError, OSError, json.JSONDecodeError, UnicodeDecodeError, ValueError):
        skipped_files.append(rel)
        continue
    scope_files_read.append(rel)
    all_pinned.extend(pinned)
    for ecosystem, pinned_name, _version in pinned:
        ecosystem_packages = corpus.get(ecosystem) or {}
        if not isinstance(ecosystem_packages, dict):
            continue
        canonical_names_lower = {k.lower() for k in ecosystem_packages}
        if pinned_name.lower() in canonical_names_lower:
            continue
        key = (ecosystem, pinned_name, rel)
        if key in seen_findings:
            continue
        for canonical_name in ecosystem_packages:
            if len(canonical_name) < 4:
                continue
            distance = levenshtein(pinned_name.lower(), canonical_name.lower())
            if 1 <= distance <= 2:
                seen_findings.add(key)
                findings.append({
                    "provisional_id": f"h-{ecosystem}-{pinned_name}",
                    "sources": [f"probe:{PROBE_ID}"],
                    "severity": "HIGH",
                    "title": (
                        f"Lockfile pins '{pinned_name}' looks like typosquat "
                        f"of '{canonical_name}'"
                    ),
                    "file": rel,
                    "description": (
                        f"Pinned package name '{pinned_name}' "
                        f"(ecosystem={ecosystem}) is Levenshtein distance "
                        f"{distance} from canonical popular package "
                        f"'{canonical_name}'. Typosquatting risk per "
                        "Radaro AI-Assisted Development Policy v1.3 §8.2."
                    ),
                    "fix": (
                        f"Verify '{pinned_name}' is the package you actually "
                        f"intended to install. If it should be '{canonical_name}', "
                        f"remove '{pinned_name}' and pin '{canonical_name}' instead."
                    ),
                    "fingerprint_anchors": {
                        "pinned_name": pinned_name,
                        "canonical_name": canonical_name,
                        "ecosystem": ecosystem,
                    },
                    "canonical_payload": {
                        "distance": distance,
                        "ecosystem": ecosystem,
                    },
                })
                break

eligible_reason = (
    f"scanned {len(scope_files_read)} lockfile(s); "
    f"{len(all_pinned)} pinned packages; {len(findings)} findings"
)
emit(findings, trigger_input_hash, scope_files_read, skipped_files,
     eligible_reason)
PY
