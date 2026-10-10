#!/usr/bin/env python3
"""Dump all state keys/values of a NEAR account (read-only). Prefix-based recursive pagination.

nearcore >= some version requires prefix_base64 in query view_state.
"""
import base64
import json
import sys
import time
import urllib.request

RPC = "https://rpc.mainnet.near.org"
LIM = 2000


def rpc(method, params, tries=6):
    last = None
    for i in range(tries):
        try:
            req = urllib.request.Request(RPC, data=json.dumps({"jsonrpc": "2.0", "id": "r", "method": method, "params": params}).encode(),
                                         headers={"Content-Type": "application/json"})
            with urllib.request.urlopen(req, timeout=60) as r:
                d = json.loads(r.read())
            if "error" in d:
                raise RuntimeError(json.dumps(d["error"])[:300])
            return d["result"]
        except Exception as e:
            last = e
            time.sleep(1 + i)
    raise RuntimeError(str(last))


def fetch(account, prefix_b64):
    return rpc("query", {"request_type": "view_state", "account_id": account, "finality": "final",
                         "prefix_base64": prefix_b64, "limit": LIM})


def main():
    acct, outfile = sys.argv[1], sys.argv[2]
    tld = int(sys.argv[3]) if len(sys.argv) > 3 else 8
    out = {}
    queue = [b""]
    bh = None
    calls = 0
    while queue:
        pref = queue.pop(0)
        b64 = base64.b64encode(pref).decode()
        res = fetch(acct, b64)
        calls += 1
        bh = res.get("block_height")
        vals = res["values"]
        if len(vals) == LIM and len(pref) < tld:
            # split into 256 children
            for b in range(256):
                queue.append(pref + bytes([b]))
            continue
        if len(vals) >= LIM:
            print(f"WARN truncated at prefix {pref.hex()} (depth cap)", file=sys.stderr)
        for e in vals:
            k = base64.b64decode(e["key"])
            out[e["key"]] = {"k_hex": k.hex(), "k_utf8": k.decode("utf-8", "replace"), "v_b64": e["value"]}
    dump = {"account": acct, "block_height": bh, "calls": calls, "count": len(out), "kv": list(out.values())}
    with open(outfile, "w") as f:
        json.dump(dump, f, indent=1)
    print(f"account={acct} block={bh} keys={len(out)} calls={calls} saved={outfile}")


if __name__ == "__main__":
    main()
