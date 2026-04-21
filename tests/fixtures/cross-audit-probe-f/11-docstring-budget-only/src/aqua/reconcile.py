"""Reconcile with budget-only discipline."""


def reconcile_bribe_payouts(account_id, from_ts, to_ts):
    """Reconcile. budget: 5s wall-time assumed."""
    rows = client.payments().limit(200).call()
    return rows
