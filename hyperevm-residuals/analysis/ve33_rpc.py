#!/usr/bin/env python3
"""Light multi-endpoint JSON-RPC client for HyperEVM (chainid 999), read-only.
Throttled + endpoint fallback to avoid public-RPC rate limits."""
import json, time, urllib.request, itertools

ENDPOINTS = [
    "https://rpc.hyperliquid.xyz/evm",
    "https://hyperliquid.drpc.org",
]
_ids = itertools.count(1)

def _post(url, payload, timeout=60):
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode(),
        headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0"})
    with urllib.request.urlopen(req, timeout=timeout) as r:
        return json.loads(r.read())

def rpc(method, params):
    last = None
    for attempt in range(6):
        url = ENDPOINTS[attempt % len(ENDPOINTS)]
        try:
            out = _post(url, {"jsonrpc": "2.0", "id": next(_ids), "method": method, "params": params})
            if isinstance(out, dict) and "result" in out:
                return out["result"]
            last = out.get("error") if isinstance(out, dict) else out
        except Exception as e:
            last = str(e)
        time.sleep(1.0 + attempt)
    raise RuntimeError(f"rpc failed {method}: {last}")

def batch(calls, chunk=15, sleep=0.12):
    """calls: list of (method, params). Returns results list (None on per-call error)."""
    res = []
    for i in range(0, len(calls), chunk):
        part = calls[i:i + chunk]
        time.sleep(sleep)
        payload = [{"jsonrpc": "2.0", "id": next(_ids), "method": m, "params": p} for m, p in part]
        got = None
        for attempt in range(6):
            url = ENDPOINTS[attempt % len(ENDPOINTS)]
            try:
                out = _post(url, payload)
                if isinstance(out, dict):
                    raise RuntimeError(f"batch error: {out.get('error')}")
                byid = {o["id"]: o for o in out if isinstance(o, dict)}
                got = [(byid.get(o["id"], {}) or {}).get("result") for o in payload]
                break
            except Exception:
                time.sleep(1.2 + attempt)
        if got is None:
            # per-call fallback
            got = []
            for m, p in part:
                try:
                    got.append(rpc(m, p))
                except Exception:
                    got.append(None)
        res.extend(got)
    return res
