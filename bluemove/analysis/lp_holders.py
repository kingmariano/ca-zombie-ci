#!/usr/bin/env python3
"""Aggregate LP (LSP) coin holders for given pools."""
import json, sys, time
from sui import gql

PKG_V1 = "0xb24b6789e088b876afabca733bed2299fbc9e2d6369be4d1acfa17d8145454d9"

def lp_holders(t0, t1, max_pages=200):
    typ = f"0x2::coin::Coin<{PKG_V1}::swap::LSP<{t0},{t1}>>"
    q = """query($t: String!, $after: String) {
      objects(first: 50, after: $after, filter: {type: $t}) {
        pageInfo { hasNextPage endCursor }
        nodes { address asMoveObject { contents { json } owner { __typename ... on AddressOwner { address { address } } } } }
      }
    }"""
    owners, total, n, cursor = {}, 0, 0, None
    for _ in range(max_pages):
        d = gql(q, {"t": typ, "after": cursor})["objects"]
        for nd in d["nodes"]:
            n += 1
            j = (nd.get("asMoveObject") or {}).get("contents", {}).get("json") or {}
            bal = int(j.get("balance") or 0)
            total += bal
            o = ((nd.get("asMoveObject") or {}).get("owner") or {})
            addr = (o.get("address") or {}).get("address") if o.get("__typename") == "AddressOwner" else o.get("__typename", "?")
            owners[addr] = owners.get(addr, 0) + bal
        pi = d["pageInfo"]
        if not pi["hasNextPage"]:
            break
        cursor = pi["endCursor"]
        time.sleep(0.03)
    return {"n_coins": n, "total": total, "owners": owners}

if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else "top"
    pools = json.load(open("pools_parsed.json"))
    if arg == "top":
        SUI = "0x0000000000000000000000000000000000000000000000000000000000000002::sui::SUI"
        def sui_res(p):
            v = 0
            if p["t0"] == SUI: v += p["reserve_x"]
            if p["t1"] == SUI: v += p["reserve_y"]
            return v
        sel = sorted(pools, key=sui_res, reverse=True)[:5]
    else:
        addrs = arg.split(",")
        sel = [p for p in pools if p["addr"] in addrs]
    for p in sel:
        r = lp_holders(p["t0"], p["t1"])
        top = sorted(r["owners"].items(), key=lambda kv: -kv[1])[:6]
        pct_zero = (r["owners"].get("0x" + "0" * 64, 0) / r["total"] * 100) if r["total"] else 0
        print(f"\npool {p['addr'][:18]} S={p['lsp_supply']:,} r=({p['reserve_x']},{p['reserve_y']}) T=({p['token_x']},{p['token_y']})")
        print(f"  LP coins={r['n_coins']} total={r['total']:,}  zero-addr share={pct_zero:.3f}%")
        for a, b in top:
            print(f"    {b:>25,}  {(b/r['total']*100 if r['total'] else 0):8.4f}%  {a}")
