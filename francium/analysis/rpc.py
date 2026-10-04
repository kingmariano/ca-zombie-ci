#!/usr/bin/env python3
"""Minimal Solana JSON-RPC client for read-only Francium analysis.

Uses public RPC by default (no secrets). Supports single + batch calls with retry.
"""
import json, sys, time, urllib.request, os

RPC = os.environ.get("SOL_RPC", "https://api.mainnet-beta.solana.com")

def rpc_call(method, params, url=RPC, retries=5, timeout=40):
    body = json.dumps({"jsonrpc": "2.0", "id": 1, "method": method, "params": params}).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 francium-audit"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read())
            if "error" in out:
                raise RuntimeError(out["error"])
            return out.get("result")
        except Exception as e:  # noqa
            last = e
            time.sleep(1.5 * (i + 1))
    raise RuntimeError(f"{method} failed after {retries}: {last}")

def batch(calls, url=RPC, retries=4, timeout=60):
    """calls: list of (method, params). Returns list of results (or {'error':...})."""
    payload = [{"jsonrpc": "2.0", "id": i, "method": m, "params": p} for i, (m, p) in enumerate(calls)]
    body = json.dumps(payload).encode()
    last = None
    for i in range(retries):
        try:
            req = urllib.request.Request(url, data=body, headers={"Content-Type": "application/json", "User-Agent": "Mozilla/5.0 francium-audit"})
            with urllib.request.urlopen(req, timeout=timeout) as r:
                out = json.loads(r.read())
            if isinstance(out, dict) and "error" in out:
                raise RuntimeError(out["error"])
            res = [None] * len(calls)
            for item in out:
                res[item["id"]] = item.get("result", {"error": item.get("error")})
            return res
        except Exception as e:  # noqa
            last = e
            time.sleep(2 * (i + 1))
    raise RuntimeError(f"batch failed after {retries}: {last}")

def get_program_accounts(program, filters=None, data_slice=None, encoding="base64", url=RPC):
    opts = {"encoding": encoding}
    if filters:
        opts["filters"] = filters
    if data_slice:
        opts["dataSlice"] = data_slice
    return rpc_call("getProgramAccounts", [program, opts], url=url)

def main():
    cmd = sys.argv[1]
    if cmd == "slot":
        print(rpc_call("getSlot", []))
    elif cmd == "epoch":
        print(json.dumps(rpc_call("getEpochInfo", []), indent=1))
    elif cmd == "acct":
        enc = sys.argv[3] if len(sys.argv) > 3 else "jsonParsed"
        print(json.dumps(rpc_call("getAccountInfo", [sys.argv[2], {"encoding": enc}]), indent=1))
    elif cmd == "gpa-count":
        res = get_program_accounts(sys.argv[2], data_slice={"offset": 0, "length": 0})
        sizes = {}
        for a in res:
            s = a["account"].get("space", len(a["account"].get("data", [""])[0]))
            sizes[s] = sizes.get(s, 0) + 1
        print(json.dumps({"program": sys.argv[2], "total": len(res), "sizes": sizes}, indent=1))
    elif cmd == "gpa-dump":
        out = sys.argv[3]
        res = get_program_accounts(sys.argv[2], data_slice={"offset": 0, "length": 0})
        with open(out, "w") as f:
            json.dump(res, f)
        print(f"wrote {len(res)} accounts to {out}")
    else:
        raise SystemExit("unknown cmd")

if __name__ == "__main__":
    main()
