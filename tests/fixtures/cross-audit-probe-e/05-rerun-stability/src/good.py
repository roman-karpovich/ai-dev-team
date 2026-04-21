"""Synthetic source file for probe-E fixture 05 — syntactically valid twin."""


def _persist_payout(reward, err):
    return Payout(status=FAILED, message='build_failure:' + err)


def _clean_rewards(payouts):
    allowed = frozenset({'stale_price:', 'missing_oracle:', 'partial_fill:'})
    return [p for p in payouts if any(p.message.startswith(m) for m in allowed)]
