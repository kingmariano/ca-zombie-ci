"""Shared helpers for Cega V1 EVM tombstone census. READ-ONLY.

- Etherscan V2 API (chainid 1 / 42161)
- JSON-RPC batch calls (public RPCs)
No secrets are ever written to disk or printed.
"""
import json
import os
import time
import urllib.parse
import urllib.request

ETHERSCAN = "https://api.etherscan.io/v2/api"
APIKEY = os.environ.get("ETHERSCANV2_API_KEY", "")
RPC = {
    1: os.environ.get("CEGA_ETH_RPC") or "https://ethereum-rpc.publicnode.com",
    42161: os.environ.get("CEGA_ARB_RPC") or "https://arb1.arbitrum.io/rpc",
}
USDC = {
    1: "0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48",
    42161: "0xaf88d065e77c8cC2239327C5EDb3A432268e5831",
}
USDC_E_ARB = "0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8"

_last_es = [0.0]


def _http(url, timeout=60):
    req = urllib.request.Request(url, headers={"User-Agent": "cega-tombstone/1.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return r.read().decode()


def etherscan(chainid, params, retries=4):
    """Call Etherscan V2, return parsed JSON. Rate-limited to ~5 req/s."""
    q = dict(params)
    q["chainid"] = str(chainid)
    q["apikey"] = APIKEY
    url = ETHERSCAN + "?" + urllib.parse.urlencode(q)
    for attempt in range(retries):
        dt = time.time() - _last_es[0]
        if dt < 0.22:
            time.sleep(0.22 - dt)
        try:
            _last_es[0] = time.time()
            data = json.loads(_http(url))
        except Exception as e:
            if attempt == retries - 1:
                raise
            time.sleep(1.5 * (attempt + 1))
            continue
        msg = data.get("message", "")
        if data.get("status") == "0" and msg in ("NOTOK",):
            # transient throttling often comes back as NOTOK/result string
            res = str(data.get("result", ""))
            if "Max rate limit" in res or "rate limit" in res.lower():
                time.sleep(1.2 * (attempt + 1))
                continue
        return data
    return data


def es_getabi(chainid, address):
    r = etherscan(chainid, {"module": "contract", "action": "getsourcecode", "address": address})
    res = r.get("result")
    if isinstance(res, list) and res:
        return res[0]
    return {}


def es_getcreation(chainid, addresses):
    """addresses: list; returns list of creation dicts."""
    out = []
    for i in range(0, len(addresses), 5):
        chunk = addresses[i : i + 5]
        r = etherscan(
            chainid,
            {"module": "contract", "action": "getcontractcreation", "contractaddresses": ",".join(chunk)},
        )
        res = r.get("result")
        if isinstance(res, list):
            out.extend(res)
    return out


def es_txlist(chainid, address, offset=10000, page=1, sort="asc"):
    r = etherscan(
        chainid,
        {
            "module": "account",
            "action": "txlist",
            "address": address,
            "startblock": 0,
            "endblock": 99999999,
            "page": page,
            "offset": offset,
            "sort": sort,
        },
    )
    res = r.get("result")
    if isinstance(res, list):
        return res
    return []


def es_getlogs(chainid, address, topic0, from_block=0, to_block="latest", topic1=None, topic2=None):
    """Auto-paginate by block range if 1000-result cap is hit."""
    out = []
    lo = from_block

    def one(fb, tb, t1=None, t2=None):
        p = {
            "module": "logs",
            "action": "getLogs",
            "address": address,
            "fromBlock": fb,
            "toBlock": tb,
            "topic0": topic0,
        }
        if t1:
            p["topic1"] = t1
            p["topic0_1_opr"] = "and"
        if t2:
            p["topic2"] = t2
            p["topic0_2_opr"] = "and"
        return etherscan(chainid, p)

    cur_from = lo
    # binary-split pagination
    ranges = [(cur_from, to_block if isinstance(to_block, int) else None)]
    # resolve latest block first if needed
    if ranges[0][1] is None:
        latest = int(rpc(chainid, "eth_blockNumber", []), 16)
        ranges = [(cur_from, latest)]
    stack = ranges
    while stack:
        fb, tb = stack.pop()
        r = one(fb, tb, topic1, topic2)
        res = r.get("result")
        if not isinstance(res, list):
            if "No records found" in str(res):
                continue
            # transient; small sleep and retry once
            time.sleep(1.0)
            res = one(fb, tb, topic1, topic2).get("result")
            if not isinstance(res, list):
                if "No records found" in str(res):
                    continue
                raise RuntimeError(f"getLogs failed {address} {topic0} {fb}-{tb}: {r.get('message')} {res}")
        if len(res) >= 1000 and fb < tb:
            mid = (fb + tb) // 2
            stack.append((fb, mid))
            stack.append((mid + 1, tb))
        else:
            out.extend(res)
    return out


_rpc_id = [0]


def rpc(chainid, method, params, retries=5):
    """Single JSON-RPC call against public RPC (with retries/UA)."""
    _rpc_id[0] += 1
    body = json.dumps({"jsonrpc": "2.0", "id": _rpc_id[0], "method": method, "params": params}).encode()
    for attempt in range(retries):
        try:
            req = urllib.request.Request(
                RPC[chainid],
                data=body,
                headers={"Content-Type": "application/json", "User-Agent": "cega-tombstone/1.0"},
            )
            with urllib.request.urlopen(req, timeout=60) as r:
                data = json.loads(r.read().decode())
            if "error" in data:
                raise RuntimeError(f"rpc {method}: {data['error']}")
            return data["result"]
        except Exception:
            if attempt == retries - 1:
                raise
            time.sleep(1.0 * (attempt + 1))


def rpc_batch(chainid, calls, chunk=5, retries=3):
    """calls: list of (method, params). Returns list of results (None on per-call error)."""
    results = []
    for i in range(0, len(calls), chunk):
        part = calls[i : i + chunk]
        payload = [
            {"jsonrpc": "2.0", "id": i + j, "method": m, "params": p} for j, (m, p) in enumerate(part)
        ]
        body = json.dumps(payload).encode()
        data = None
        for attempt in range(retries):
            try:
                req = urllib.request.Request(
                    RPC[chainid],
                    data=body,
                    headers={"Content-Type": "application/json", "User-Agent": "cega-tombstone/1.0"},
                )
                with urllib.request.urlopen(req, timeout=120) as r:
                    data = json.loads(r.read().decode())
                if not isinstance(data, list):
                    raise RuntimeError(f"batch rpc non-list response: {str(data)[:200]}")
                break
            except Exception:
                if attempt == retries - 1:
                    raise
                time.sleep(1.0 * (attempt + 1))
        by_id = {d["id"]: d for d in data}
        for j in range(len(part)):
            d = by_id.get(i + j, {})
            if "error" in d:
                results.append(None)
            else:
                results.append(d.get("result"))
    return results


def eth_call(chainid, to, data, block="latest"):
    return rpc(chainid, "eth_call", [{"to": to, "data": data}, block])


def selector(sig):
    """Compute 4-byte selector using cast if available."""
    import subprocess

    return subprocess.check_output(["cast", "sig", sig], text=True).strip()


def word(hexstr, i):
    """Extract i-th 32-byte word from 0x-hex."""
    h = hexstr[2:] if hexstr.startswith("0x") else hexstr
    return h[64 * i : 64 * (i + 1)]


def dec_words(hexstr, n):
    """Decode n uint256 words."""
    return [int(word(hexstr, i) or "0", 16) for i in range(n)]


def dec_address(hexstr, i):
    return "0x" + word(hexstr, i)[24:]


def save_json(path, obj):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        json.dump(obj, f, indent=2)
    print(f"wrote {path}")
