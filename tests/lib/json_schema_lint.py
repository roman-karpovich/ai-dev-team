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
                          The Draft-07 tuple-form (a list) is NOT supported.
  - enum                  the instance value must equal one of the listed values.
  - additionalProperties  boolean. When false, object keys not named in
                          `properties` are a violation. When true (or absent),
                          extra keys are permitted.

Unsupported keywords (anyOf/oneOf/allOf/$ref/pattern/format/minimum/...) are
NOT silently ignored: a schema-walk pass runs before instance validation and
rejects any schema object key outside the supported allowlist with exit 2 — so
a misspelled keyword (e.g. `addtionalProperties`) fails loud instead of
disabling its gate. If a future schema needs a new keyword, extend this
validator (its `_SUPPORTED_KEYWORDS` set and self-test pins) rather than
relying on a no-op.

The schema-walk also type-checks the VALUES of value-constrained supported
keywords — a malformed value would otherwise silently misbehave under
`validate()` exactly as a misspelled key would. `additionalProperties` MUST be
a boolean (a non-boolean such as the string `"false"` would never be `is False`
and would silently disable the extra-property gate); `required` MUST be a list
(a string is iterated character-by-character); `properties` MUST be an object
AND every member subschema inside it MUST itself be an object (a non-object
member would either mis-classify as an exit-1 instance violation or, if the
instance lacks that key, emit zero diagnostics); `items` MUST be an object —
the Draft-07 tuple-form `items` (a list of per-position schemas) is NOT
implemented by `validate()` and is rejected outright rather than silently
mis-validating every array element; `enum` MUST be a non-empty list; `type`
MUST be a known type-name string. Any malformed value fails loud with exit 2.

CLI:
  python3 json_schema_lint.py <schema.json> <instance.json>
  exit 0  — instance conforms
  exit 1  — instance violates the schema (each violation printed to stdout)
  exit 2  — usage / load error (bad args, unreadable/invalid JSON,
            unsupported/misspelled schema keyword)
"""

import json
import sys

# Keywords this subset validator implements. A schema object key NOT in this
# allowlist (an unsupported keyword, or a typo like `requird`) is rejected with
# exit 2 by _walk_schema — a misspelled keyword must fail loud, not no-op.
_SUPPORTED_KEYWORDS = frozenset({
    "$schema", "$comment", "$id", "title", "description",
    "type", "required", "properties", "items", "enum",
    "additionalProperties",
})

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


def _json_equal(a, b):
    """JSON-type-aware equality for enum membership — recursive.

    Python `==` collapses `True == 1` / `False == 0` because `bool` is an `int`
    subclass — Draft-07 treats JSON `true` and `1` as distinct values. A match
    requires the same JSON type (bool kept distinct from int/float) AND equal
    values. For containers the comparison recurses element-wise rather than
    delegating to Python `==`, which would re-collapse `bool`/`int` at every
    nesting level (e.g. `[1] == [True]` is True under bare `==`): a list-valued
    or dict-valued enum member is only equal when every nested scalar also
    passes this type-aware test.
    """
    a_bool = isinstance(a, bool)
    b_bool = isinstance(b, bool)
    if a_bool != b_bool:
        return False
    if a_bool:  # both bool
        return a == b
    # Lists: equal length AND element-wise type-aware equality. Checked before
    # the int/float branch — neither operand is a bool here, but a list is
    # never an int/float so order does not matter; explicit for clarity.
    if isinstance(a, list) and isinstance(b, list):
        return len(a) == len(b) and all(
            _json_equal(x, y) for x, y in zip(a, b)
        )
    if isinstance(a, list) or isinstance(b, list):
        return False
    # Dicts: equal key set AND per-key type-aware equality.
    if isinstance(a, dict) and isinstance(b, dict):
        return a.keys() == b.keys() and all(
            _json_equal(a[k], b[k]) for k in a
        )
    if isinstance(a, dict) or isinstance(b, dict):
        return False
    # Scalars (neither is bool here): distinguish remaining JSON types.
    if isinstance(a, (int, float)) and isinstance(b, (int, float)):
        return a == b
    return type(a) == type(b) and a == b


def _bad_value(path, key, observed, expected):
    """Print an exit-2 diagnostic for a malformed keyword value and exit."""
    print(
        f"error: schema keyword '{key}' at {path} must be {expected}, got "
        f"'{_json_type_name(observed)}'",
        file=sys.stderr,
    )
    sys.exit(2)


def _walk_schema(schema, path="$"):
    """Reject any schema object key outside the supported-keyword allowlist,
    and type-check the VALUES of value-constrained supported keywords.

    Exits 2 (usage / contract error) naming the offending key and its path so a
    misspelled keyword OR a malformed keyword value fails loud rather than
    being silently no-op'd (a non-boolean `additionalProperties` would never be
    `is False` and would silently disable the extra-property gate).
    """
    if isinstance(schema, dict):
        for key in schema:
            if key not in _SUPPORTED_KEYWORDS:
                print(
                    f"error: unsupported schema keyword '{key}' at {path} "
                    f"(allowed: {', '.join(sorted(_SUPPORTED_KEYWORDS))})",
                    file=sys.stderr,
                )
                sys.exit(2)
        # Type-check the values of value-constrained supported keywords. A
        # malformed value silently misbehaves under validate() — the same
        # "silent gate disable" class as a misspelled key.
        if "additionalProperties" in schema and not isinstance(
            schema["additionalProperties"], bool
        ):
            _bad_value(path, "additionalProperties",
                       schema["additionalProperties"], "a boolean")
        if "required" in schema and not isinstance(schema["required"], list):
            _bad_value(path, "required", schema["required"], "a list")
        if "properties" in schema:
            if not isinstance(schema["properties"], dict):
                _bad_value(path, "properties", schema["properties"],
                           "an object")
            # Each member subschema must itself be an object — a non-object
            # member (e.g. the string "NOT-A-SCHEMA") is malformed schema
            # usage: validate() would either mis-classify it as an exit-1
            # instance violation or, if the instance lacks that key, emit
            # ZERO diagnostics. It must fail loud with exit 2 here.
            for prop, subschema in schema["properties"].items():
                if not isinstance(subschema, dict):
                    _bad_value(f"{path}.properties.{prop}",
                               "properties", subschema, "an object")
        if "items" in schema:
            # validate() implements only the SINGLE-subschema `items` form
            # (one schema applied to every element); it does NOT implement
            # Draft-07 tuple-form `items` (a list of per-position schemas).
            # A tuple-form list is therefore rejected outright with exit 2
            # rather than silently mis-validating every array element — the
            # minimal fix consistent with this validator's documented subset.
            if not isinstance(schema["items"], dict):
                _bad_value(path, "items", schema["items"], "an object")
        if "enum" in schema:
            enum_value = schema["enum"]
            if not isinstance(enum_value, list) or not enum_value:
                _bad_value(path, "enum", enum_value, "a non-empty list")
        if "type" in schema:
            type_value = schema["type"]
            if not isinstance(type_value, str) or type_value not in _TYPE_CHECKS:
                print(
                    f"error: schema keyword 'type' at {path} must be one of "
                    f"{', '.join(sorted(_TYPE_CHECKS))}, got {type_value!r}",
                    file=sys.stderr,
                )
                sys.exit(2)
        for key, value in schema.items():
            if key == "properties" and isinstance(value, dict):
                for prop, subschema in value.items():
                    _walk_schema(subschema, f"{path}.properties.{prop}")
            elif key == "items":
                _walk_schema(value, f"{path}.items")
    elif isinstance(schema, list):
        for idx, element in enumerate(schema):
            _walk_schema(element, f"{path}[{idx}]")


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
        if not any(_json_equal(instance, member) for member in schema["enum"]):
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
    # Schema-walk validation pass — reject misspelled/unsupported keywords
    # (exit 2) before any instance validation.
    _walk_schema(schema)
    errors = validate(schema, instance)
    if errors:
        for err in errors:
            print(err)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
