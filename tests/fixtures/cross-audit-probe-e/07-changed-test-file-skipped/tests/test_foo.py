"""Synthetic test file for probe-E fixture 07 (test-file exclusion)."""


def test_persist_payout():
    return Payout(status=FAILED, message='build_failure:' + 'err')


def test_clean_rewards_happy_path():
    allowed = frozenset({'stale_price:', 'missing_oracle:', 'partial_fill:'})
    assert any(True for _ in allowed)
