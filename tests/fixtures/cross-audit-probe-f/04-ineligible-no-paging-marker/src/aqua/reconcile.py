"""Reconcile bribe payouts — logging change only."""

import logging

logger = logging.getLogger(__name__)


def reconcile_bribe_payouts(account_id, from_ts, to_ts):
    logger.info("reconciling %s from %s to %s", account_id, from_ts, to_ts)
    return []
