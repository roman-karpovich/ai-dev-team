"""Nested inner function — inner does not inherit outer's cursor discipline."""


def wrapper(cursor=None):
    def inner():
        rows = client.payments().limit(200).call()
        return rows
    return inner
