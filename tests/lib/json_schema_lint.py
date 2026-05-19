#!/usr/bin/env python3
"""json_schema_lint.py — minimal pure-stdlib JSON-Schema validator.

The ai-dev-team repo forbids pip dependencies (the `jsonschema` library is not
available). This module ships a deliberately small validator covering exactly
the keyword subset the probe-envelope schema (tests/fixtures/probe-envelope.schema.json)
uses — no more. The schema FILE stays standard Draft-07 JSON so a future swap
to a real library is drop-in; only this validator is a subset.

Supported keyword subset (Draft-07 semantics for each):
  - type                  one of: object, array, string, boolean, number,
                          integer, null. JSON booleans are NOT accepted for
                          `number`/`integer`; integers ARE accepted for `number`.
  - required              list of property names that MUST be present on an object.
  - properties            per-property subschemas, applied when the key is present.
  - items                 a single subschema applied to every array element.
  - enum                  the instance value must equal one of the listed values.
  - additionalProperties  boolean. When false, object keys not named in
                          `properties` are a violation. When true (or absent),
                          extra keys are permitted.

Unsupported keywords (anyOf/oneOf/allOf/$ref/pattern/format/minimum/...) are
NOT silently ignored at the contract level — they simply do not appear in the
envelope schema. If a future schema needs them, extend this validator (and its
self-test pins) rather than relying on a no-op.

CLI:
  python3 json_schema_lint.py <schema.json> <instance.json>
  exit 0  — instance conforms
  exit 1  — instance violates the schema (each violation printed to stdout)
  exit 2  — usage / load error (bad args, unreadable/invalid JSON)
"""

import json
import sys

_TYPE_CHECKS = {
    "object": lambda v: isinstance(v, dict),
    "array": lambda v: isinstance(v, list),
    "string": lambda v: isinstance(v, str),
    "boolean": lambda v: isinstance(v, bool),
    # bool is a subclass of int in Python — exclude it explicitly.
    "number": lambda v: isinstance(v, (int, float)) and not isinstance(v, bool),
    "integer": lambda v: isinstance(v, int) and not isinstance(v, bool),
    "null": lambda v: v is None,
}


def validate(schema, instance, path="$"):
    """Return a list of human-readable violation strings (empty == valid)."""
    errors = []

    if not isinstance(schema, dict):
        errors.append(f"{path}: schema node is not an object")
        return errors

    # --- type ---
    expected_type = schema.get("type")
    if expected_type is not None:
        check = _TYPE_CHECKS.get(expected_type)
        if check is None:
            errors.append(f"{path}: unsupported type keyword '{expected_type}'")
        elif not check(instance):
            errors.append(
                f"{path}: expected type '{expected_type}', got "
                f"'{_json_type_name(instance)}'"
            )
            # A type mismatch makes deeper keyword checks meaningless.
            return errors

    # --- enum ---
    if "enum" in schema:
        if instance not in schema["enum"]:
            errors.append(
                f"{path}: value {instance!r} not in enum {schema['enum']!r}"
            )

    # --- object keywords ---
    if isinstance(instance, dict):
        required = schema.get("required", [])
        for key in required:
            if key not in instance:
                errors.append(f"{path}: missing required property '{key}'")

        properties = schema.get("properties", {})
        additional = schema.get("additionalProperties", True)
        if additional is False:
            for key in instance:
                if key not in properties:
                    errors.append(
                        f"{path}: additional property '{key}' not permitted "
                        f"(additionalProperties:false)"
                    )

        for key, subschema in properties.items():
            if key in instance:
                errors.extend(
                    validate(subschema, instance[key], f"{path}.{key}")
                )

    # --- array keywords ---
    if isinstance(instance, list):
        item_schema = schema.get("items")
        if item_schema is not None:
            for idx, element in enumerate(instance):
                errors.extend(
                    validate(item_schema, element, f"{path}[{idx}]")
                )

    return errors


def _json_type_name(value):
    if isinstance(value, bool):
        return "boolean"
    if isinstance(value, dict):
        return "object"
    if isinstance(value, list):
        return "array"
    if isinstance(value, str):
        return "string"
    if isinstance(value, int):
        return "integer"
    if isinstance(value, float):
        return "number"
    if value is None:
        return "null"
    return type(value).__name__


def _load_json(label, path):
    try:
        with open(path, "r", encoding="utf-8") as handle:
            return json.load(handle)
    except FileNotFoundError:
        print(f"error: {label} file not found: {path}", file=sys.stderr)
        sys.exit(2)
    except (OSError, json.JSONDecodeError) as exc:
        print(f"error: cannot load {label} ({path}): {exc}", file=sys.stderr)
        sys.exit(2)


def main(argv):
    if len(argv) != 3:
        print(
            "usage: json_schema_lint.py <schema.json> <instance.json>",
            file=sys.stderr,
        )
        return 2
    schema = _load_json("schema", argv[1])
    instance = _load_json("instance", argv[2])
    errors = validate(schema, instance)
    if errors:
        for err in errors:
            print(err)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
