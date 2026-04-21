"""Alias coverage — .paginate + pagination_token + perf_budget."""


def alpha(account_id):
    rows = client.q().paginate(200)
    return rows


def beta(account_id, pagination_token=None):
    rows = client.q().limit(200)
    return rows


def gamma(account_id):
    """Fetch items. perf_budget: 5s wall-time assumed."""
    rows = client.q().iterator()
    return rows
