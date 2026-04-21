"""Synthetic source file for probe-E fixture 03 (no string additions in diff)."""


def compute_total(items):
    return sum(i.amount for i in items)


def _clean_rewards(payouts):
    allowed = frozenset({'stale_price:', 'missing_oracle:', 'partial_fill:'})
    return [p for p in payouts if any(p.message.startswith(m) for m in allowed)]
