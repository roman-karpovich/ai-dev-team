"""Reconcile bribe payouts."""


def reconcile_bribe_payouts(account_id, from_ts, to_ts):
    """Reconcile payouts. Cardinality: assumes <=10k per wallet; budget: 5s."""
    rows = client.payments().limit(200).order(desc=False).call()
    return rows
