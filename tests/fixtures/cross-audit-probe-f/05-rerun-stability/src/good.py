"""Reconcile bribe payouts — rerun-stability twin (good)."""


def reconcile_bribe_payouts(account_id, from_ts, to_ts):
    rows = client.payments().limit(200).order(desc=False).call()
    return rows
