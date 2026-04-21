"""Test helper that uses .limit — should be skipped entirely."""


def helper_build_rows():
    rows = client.payments().limit(200).call()
    return rows
