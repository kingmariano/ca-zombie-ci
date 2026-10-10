#!/usr/bin/env python3
"""Read-only NEAR helpers: mainnet RPC + nearblocks API. Keyless endpoints only.

Usage examples:
  python3 near.py account boostfarm.ref-finance.near
  python3 near.py call boostfarm.ref-finance.near get_accounts '{"from_index":0,"limit":100}'
  python3 near.py state boostfarm.ref-finance.near <b64prefix> <limit>
  python3 near.py code boostfarm.ref-finance.near out.wasm
  python3 near.py tokens boostfarm.ref-finance.near
"""
import base64
import json
import sys
import time
import urllib.request

RPC = "https://rpc.mainnet.near.org"
NB = "https://api.nearblocks.io/v1"


def _req(url, data=None, tries=6):
    last = None
    for i in range(tries):
        try:
            if data is None:
                req = urllib.request.Request(url, headers={"User-Agent": "research-readonly/1.0"})
            else:
                req = urllib.request.Request(url, data=json.dumps(data).encode(),
                                             headers={"Content-Type": "application/json",
                                                      "User-Agent": "research-readonly/1.0"})
            with urllib.request.urlopen(req, timeout=30) as r:
                raw = r.read().decode()
                return json.loads(raw)
        except Exception as e:  # noqa
            last = e
            code = getattr(e, "code", None)
            if code == 429:
                time.sleep(2 + 2 * i)
            else:
                time.sleep(1 + i)
    raise RuntimeError(f"request failed after retries: {url}: {last}")


def rpc(method, params):
    d = _req(RPC, {"jsonrpc": "2.0", "id": "r", "method": method, "params": params})
    if "error" in d:
        raise RuntimeError(json.dumps(d["error"]))
    return d["result"]


def view_account(account_id, finality="final"):
    return rpc("query", {"request_type": "view_account", "account_id": account_id, "finality": finality})


def call_function(account_id, method, args=None, finality="final"):
    args_b64 = base64.b64encode(json.dumps(args or {}).encode()).decode()
    return rpc("query", {"request_type": "call_function", "account_id": account_id,
                         "method_name": method, "args_base64": args_b64, "finality": finality})


def call_function_decoded(account_id, method, args=None, finality="final"):
    res = call_function(account_id, method, args, finality)
    raw = bytes(res.get("result", []))
    try:
        return json.loads(raw.decode())
    except Exception:
        return {"_raw_hex": raw.hex(), "logs": res.get("logs")}


def view_state(account_id, prefix_b64=None, limit=100, finality="final"):
    p = {"request_type": "view_state", "account_id": account_id, "finality": finality}
    if prefix_b64:
        p["prefix_base64"] = prefix_b64
    if limit:
        p["limit"] = limit
    return rpc("query", p)


def view_code(account_id, finality="final"):
    return rpc("query", {"request_type": "view_code", "account_id": account_id, "finality": finality})


def nb(path):
    return _req(NB + path)


def account(account_id):
    out = {}
    try:
        out["account"] = nb(f"/account/{account_id}")
    except Exception as e:
        out["account_error"] = str(e)
    try:
        out["tokens"] = nb(f"/account/{account_id}/tokens")
    except Exception as e:
        out["tokens_error"] = str(e)
    return out


def main():
    cmd = sys.argv[1]
    if cmd == "account":
        print(json.dumps(account(sys.argv[2]), indent=1))
    elif cmd == "call":
        acct, method = sys.argv[2], sys.argv[3]
        args = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        print(json.dumps(call_function_decoded(acct, method, args), indent=1)[:20000])
    elif cmd == "callraw":
        acct, method = sys.argv[2], sys.argv[3]
        args = json.loads(sys.argv[4]) if len(sys.argv) > 4 else {}
        print(json.dumps(call_function(acct, method, args), indent=1)[:20000])
    elif cmd == "state":
        lim = int(sys.argv[4]) if len(sys.argv) > 4 else 100
        prefix = sys.argv[3] if (len(sys.argv) > 3 and sys.argv[3] != "-") else None
        prefix_b64 = base64.b64encode(prefix.encode()).decode() if prefix else None
        print(json.dumps(view_state(sys.argv[2], prefix_b64, lim), indent=1)[:30000])
    elif cmd == "code":
        r = view_code(sys.argv[2])
        code = base64.b64decode(r["code_base64"])
        with open(sys.argv[3], "wb") as f:
            f.write(code)
        print(json.dumps({"account": sys.argv[2], "hash": r["hash"], "wasm_bytes": len(code),
                          "saved": sys.argv[3]}))
    elif cmd == "tokens":
        print(json.dumps(nb(f"/account/{sys.argv[2]}/tokens"), indent=1)[:20000])
    elif cmd == "acct":
        print(json.dumps(view_account(sys.argv[2]), indent=1))
    elif cmd == "nbaccount":
        print(json.dumps(nb(f"/account/{sys.argv[2]}"), indent=1)[:10000])
    else:
        raise SystemExit(f"unknown cmd {cmd}")


if __name__ == "__main__":
    main()
