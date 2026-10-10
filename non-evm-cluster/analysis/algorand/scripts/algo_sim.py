"""Algorand algod simulate helper (read-only; allow-empty-signatures).

POST /v2/transactions/simulate with unsigned txns for gate verification.
No keys, no signing, no sending.
"""
import json
import urllib.request

from algosdk import encoding, transaction as T

ALGOD_BASES = [
    "https://mainnet-api.algonode.cloud/v2",
    "https://mainnet-api.4160.nodely.dev/v2",
]


def _signed_stub(txn):
    return {"sig": b"", "txn": txn.dictify()}


def simulate(txns, allow_empty=True, extra_budget=0):
    """txns: flat list of Transaction (single group). Returns simulation result dict."""
    body = {
        "txn-groups": [{"txns": [_signed_stub(t) for t in txns]}],
        "allow-empty-signatures": allow_empty,
    }
    if extra_budget:
        body["extra-opcode-budget"] = extra_budget
    data = encoding.msgpack_encode(body)
    if isinstance(data, str):
        import base64 as _b64
        data = _b64.b64decode(data)
    req = urllib.request.Request(
        ALGOD_BASES[0] + "/transactions/simulate",
        data=data,
        headers={"Content-Type": "application/msgpack", "User-Agent": "zombie-research/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=45) as r:
        return json.loads(r.read())


def suggested_params():
    req = urllib.request.Request(ALGOD_BASES[0] + "/transactions/params", headers={"User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        p = json.loads(r.read())
    return T.SuggestedParams(
        first=p["last-round"], last=p["last-round"] + 1000, gh=p["genesis-hash"],
        gen=p["genesis-id"], fee=p.get("min-fee", 1000), flat_fee=True,
    )


def _to_jsonable(obj):
    import base64 as _b64
    if isinstance(obj, bytes):
        return _b64.b64encode(obj).decode()
    if isinstance(obj, dict):
        return {k: _to_jsonable(v) for k, v in obj.items() if v is not None}
    if isinstance(obj, list):
        return [_to_jsonable(v) for v in obj]
    return obj


def get_json(path):
    req = urllib.request.Request(ALGOD_BASES[0] + path, headers={"User-Agent": "zombie-research/1.0"})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.loads(r.read())


def make_account_stub(address: str, amount=10_000_000_000, round_now=None):
    """Minimal dryrun Account object with rich balance (no chain state needed)."""
    return {
        "address": address,
        "amount": amount,
        "amount-without-pending-rewards": amount,
        "min-balance": 100_000,
        "apps-local-state": [],
        "apps-total-schema": {"num-uint": 0, "num-byte-slice": 0},
        "apps-total-extra-pages": 0,
        "assets": [],
        "created-apps": [],
        "created-assets": [],
        "pending-rewards": 0,
        "reward-base": 0,
        "rewards": 0,
        "round": round_now or 0,
        "status": "Offline",
        "total-apps-opted-in": 0,
        "total-assets-opted-in": 0,
        "total-box-bytes": 0,
        "total-boxes": 0,
        "total-created-apps": 0,
        "total-created-assets": 0,
    }


def dryrun(txns, accounts=None, apps=None, round_now=None, latest_ts=None):
    """POST a DryrunRequest (JSON). txns: list of Transaction (one group).

    accounts/apps: JSON objects (algod format) to inject/override ledger state.
    Returns the DryrunResponse dict.
    """
    import time as _time
    if round_now is None:
        round_now = get_json("/status")["last-round"]
    if latest_ts is None:
        latest_ts = int(_time.time())
    body = {
        "txns": [{"sig": "", "txn": _to_jsonable(t.dictify())} for t in txns],
        "accounts": accounts or [],
        "apps": apps or [],
        "protocol-version": "future",
        "round": round_now,
        "latest-timestamp": latest_ts,
        "sources": [],
    }
    req = urllib.request.Request(
        ALGOD_BASES[0] + "/teal/dryrun",
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "zombie-research/1.0"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


def dryrun_messages(resp):
    """Flatten failure messages / app call messages from a DryrunResponse."""
    out = []
    for tg in resp.get("txns", []):
        if tg.get("failure-message"):
            out.append(tg["failure-message"])
        if tg.get("txn-result", {}).get("pool-error"):
            out.append("pool-error: " + tg["txn-result"]["pool-error"])
        for ltr in tg.get("txn-result", {}).get("local-deltas", []) or []:
            pass
        for alr in tg.get("txn-result", {}).get("app-call-messages", []) or []:
            out.append("app-msg: " + str(alr))
        for gl in tg.get("txn-result", {}).get("global-delta", []) or []:
            out.append("global-delta: " + json.dumps(gl))
        for lr in tg.get("txn-result", {}).get("logs", []) or []:
            out.append("log: " + str(lr)[:120])
    return out
