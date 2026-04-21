"""Reconcile bribe payouts with cursor discipline."""


def reconcile_bribe_payouts(account_id, from_ts, to_ts, cursor=None):
    rows = client.payments().limit(200).order(desc=False).call()
    return rows
