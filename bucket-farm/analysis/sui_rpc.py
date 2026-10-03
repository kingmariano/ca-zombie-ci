#!/usr/bin/env python3
"""Minimal Sui JSON-RPC client (read-only) with endpoint rotation.
Usage: python3 sui_rpc.py <method> [params-json]
       python3 sui_rpc.py --batch <file.json>   # [{"method":..,"params":..}]
"""
import json, sys, time, urllib.request, os

def _load_env():
    p = "/home/heisenberg/CA/.env"
    env = {}
    try:
        for line in open(p):
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip('"').strip("'")
    except Exception:
        pass
    return env

_ENV = _load_env()
_ANKR = _ENV.get("ANKR_API_KEY", "")

ENDPOINTS = [
    "https://sui-mainnet-endpoint.blockvision.org",
    "https://sui.blockpi.network/v1/rpc/public",
    "https://sui.api.onfinality.io/public",
    "https://sui-mainnet.nodeinfra.com",
    "https://sui-rpc.publicnode.com",
]
if _ANKR:
    ENDPOINTS.insert(0, f"https://rpc.ankr.com/sui/{_ANKR}")

_rot = [0]

def rpc(method, params=None, endpoint=None, retries=6, quiet=False):
    payload = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params or []}).encode()
    eps = [endpoint] if endpoint else ENDPOINTS
    last = None
    for attempt in range(retries):
        ep = eps[attempt % len(eps)] if not endpoint else endpoint
        try:
            req = urllib.request.Request(ep, data=payload, headers={
                "Content-Type": "application/json", "User-Agent": "zombie-research/1.0"})
            with urllib.request.urlopen(req, timeout=45) as r:
                d = json.loads(r.read().decode())
            if "result" in d:
                return d["result"]
            last = d.get("error")
            if isinstance(last, dict) and last.get("code") == -32601:
                continue
        except Exception as e:
            last = str(e)
        time.sleep(1.5 + attempt * 0.8)
    raise RuntimeError(f"{method} failed: {last}")

def batch(calls, chunk=4):
    """Sequential-ish batch with rotation; returns list of results."""
    out = []
    i = 0
    while i < len(calls):
        sub = calls[i:i+chunk]
        payload = [{"jsonrpc": "2.0", "id": j, "method": m, "params": p} for j, (m, p) in enumerate(sub)]
        got = None
        for attempt in range(8):
            ep = ENDPOINTS[(_rot[0] + attempt) % len(ENDPOINTS)]
            try:
                req = urllib.request.Request(ep, data=json.dumps(payload).encode(), headers={
                    "Content-Type": "application/json", "User-Agent": "zombie-research/1.0"})
                with urllib.request.urlopen(req, timeout=60) as r:
                    d = json.loads(r.read().decode())
                byid = {x["id"]: x for x in d}
                got = [byid.get(j, {}).get("result", {"error": byid.get(j, {}).get("error")}) for j in range(len(sub))]
                break
            except Exception as e:
                got = [{"error": str(e)}] * len(sub)
            time.sleep(2.0 + attempt)
        _rot[0] += 1
        out.extend(got)
        i += chunk
        time.sleep(0.5)
    return out

if __name__ == "__main__":
    if sys.argv[1] == "--batch":
        calls = json.load(open(sys.argv[2]))
        res = batch([(c["method"], c.get("params", [])) for c in calls])
        print(json.dumps(res, indent=1))
    else:
        method = sys.argv[1]
        params = json.loads(sys.argv[2]) if len(sys.argv) > 2 else []
        print(json.dumps(rpc(method, params), indent=1))
