#!/usr/bin/env python3
"""Simulate user withdrawal (eth_call only, never sent) for sample accounts.

Usage: python3 withdraw_sim.py <chain> [n_samples]
Writes raw/withdraw_sim_<chain>.json
"""
import json
import os
import sys

from rpc import Rpc, encode_call

D = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(D, "raw")

CFG = {
    "base": dict(rpc="https://base-rpc.publicnode.com", dec=6,
                 mas=["0x8Ab178C07184ffD44F0ADfF4eA2ce6cFc33F3b86",
                      "0x72b03E85B40A745B07f3a15e7A02E66F7f8352F3",
                      "0x921dd892d67aed3d492f9ad77b30b60160b53fe1"]),
    "arb": dict(rpc="https://arbitrum-one-rpc.publicnode.com", dec=6,
                mas=["0x141269E29a770644C34e05B127AB621511f20109"]),
    "mantle": dict(rpc="https://rpc.mantle.xyz", dec=18,
                   mas=["0xECbd0788bB5a72f9dFDAc1FFeAAF9B7c2B26E456"]),
    "blast": dict(rpc="https://blast-rpc.publicnode.com", dec=18,
                  mas=["0x083267D20Dbe6C2b0A83Bd0E601dC2299eD99015",
                       "0xd6ee1fd75d11989e57B57AA6Fd75f558fBf02a5e"]),
}


def run(chain, n=6):
    cfg = CFG[chain]
    r = Rpc(cfg["rpc"])
    blk = r.block_number()
    bh = hex(blk)
    acc = json.load(open(os.path.join(RAW, f"accounts_{chain}.json")))
    agg = json.load(open(os.path.join(RAW, f"agg_{chain}.json")))
    det = acc.get("top_details", {})
    # candidates: top free balances
    cand = sorted(((a, d) for a, d in det.items() if (d.get("free") or 0) > 0),
                  key=lambda kv: -kv[1]["free"])[:n]
    # also a few random free>0 accounts outside top
    others = sorted([(a, d) for a, d in det.items() if (d.get("free") or 0) > 0],
                    key=lambda kv: kv[1]["free"])[:3]
    samples = cand + [o for o in others if o[0] not in [c[0] for c in cand]]
    out = {"chain": chain, "block": blk, "samples": []}
    unit = 10 ** cfg["dec"]
    for a, d in samples:
        owner = d.get("user")
        free_tok = (d.get("free") or 0) / 1e18
        ma = (agg.get("accounts", {}).get(a) or {}).get("ma")
        mas = [ma] if ma else cfg["mas"]
        res = {"account": a, "owner": owner, "free_token": free_tok, "ma_tried": mas,
               "tests": []}
        amt_tok = min(free_tok, 1.0)
        for m in mas:
            if amt_tok <= 0:
                continue
            data = encode_call("withdrawFromAccount_ma", [a, int(round(amt_tok * unit))])
            ok, ret = r.raw_call(m, data, frm=owner, block=bh)
            entry = {"ma": m, "amount_token": amt_tok, "ok": ok, "ret": str(ret)[:200]}
            res["tests"].append(entry)
            if ok:
                break
        out["samples"].append(res)
        print(f"[{chain}] {a} owner={owner} free={free_tok:,.4f} -> {json.dumps(res['tests'])[:220]}")
    with open(os.path.join(RAW, f"withdraw_sim_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1)
    print(f"[{chain}] withdraw sim written (block {blk})")


if __name__ == "__main__":
    chain = sys.argv[1]
    n = int(sys.argv[2]) if len(sys.argv) > 2 else 6
    run(chain, n)
