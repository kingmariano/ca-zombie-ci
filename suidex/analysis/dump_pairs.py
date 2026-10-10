#!/usr/bin/env python3
"""Dump all SuiDex V2 pairs: type args, reserves, actual balances (SUI + both tokens), LP supply."""
import json, sys, os
sys.path.insert(0, os.path.dirname(__file__))
from sui_rpc import rpc, get_object, PKG

FACTORY = "0x81c286135713b4bf2e78c548f5643766b5913dcd27a8e76469f146ab811e922d"
SUI = "0x2::sui::SUI"

def pair_type_args(type_repr):
    # "0x...::pair::Pair<A,B>" -> [A,B]
    inner = type_repr.split("<", 1)[1].rsplit(">", 1)[0]
    depth = 0; cur = ""; out = []
    for ch in inner:
        if ch == "<":
            depth += 1
        if ch == ">":
            depth -= 1
        if ch == "," and depth == 0:
            out.append(cur); cur = ""
        else:
            cur += ch
    out.append(cur)
    return [x.strip() for x in out]

def main():
    f = get_object(FACTORY)
    fields = f["data"]["content"]["fields"]
    pairs = fields["all_pairs"]
    res = {
        "factory": FACTORY,
        "factory_version": f["data"]["version"],
        "is_paused": fields["is_paused"],
        "admin": fields["admin"],
        "all_pairs_count": len(pairs),
        "pairs": [],
    }
    for p in pairs:
        o = get_object(p)
        d = o["data"]
        t = d["type"]
        j = d["content"]["fields"] if d.get("content") else {}
        entry = {
            "pair": p,
            "type": t,
            "type_args": pair_type_args(t),
            "reserve0": j.get("reserve0"),
            "reserve1": j.get("reserve1"),
            "total_supply": j.get("total_supply"),
            "name": j.get("name"),
            "balance0_json": j.get("balance0"),
            "balance1_json": j.get("balance1"),
            "version": d["version"],
            "owner": d.get("owner"),
        }
        # actual SUI balance of the pair (from its Balance<SUI> field)
        if SUI in entry["type_args"]:
            idx = entry["type_args"].index(SUI)
            entry["sui_balance_mist"] = int(entry["balance0_json"] if idx == 0 else entry["balance1_json"])
            entry["sui_reserve"] = int(entry["reserve0"] if idx == 0 else entry["reserve1"])
        else:
            entry["sui_balance_mist"] = 0
        res["pairs"].append(entry)
    with open(os.path.join(os.environ.get("SUIDEX_OUT_DIR", os.path.dirname(__file__)), "pairs_state.json"), "w") as fh:
        json.dump(res, fh, indent=1)
    sui_pairs = [e for e in res["pairs"] if int(e.get("sui_balance_mist") or 0) > 0]
    total = sum(int(e["sui_balance_mist"] or 0) for e in sui_pairs)
    print(f"pairs total={len(res['pairs'])} pairs_with_SUI={len(sui_pairs)} total_SUI_mist={total} = {total/1e9:.6f} SUI")
    for e in sui_pairs:
        print(f"  {e['pair']} {e['name']} sui={int(e['sui_balance_mist'])/1e9:.6f} r0={e['reserve0']} r1={e['reserve1']} supply={e['total_supply']} args={e['type_args']}")

if __name__ == "__main__":
    main()
