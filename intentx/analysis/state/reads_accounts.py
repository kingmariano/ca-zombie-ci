#!/usr/bin/env python3
"""Full partyA/partyB balance reads per chain + reconciliation.

Usage: python3 reads_accounts.py <chain> [topN]
Writes raw/accounts_<chain>.json
Read-only.
"""
import json
import os
import sys

from rpc import Rpc

BASE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(BASE, "raw")

CFG = {
    "base": dict(rpc="https://base-rpc.publicnode.com",
                 diamond="0x91Cf2D8Ed503EC52768999aA6D8DBeA6e52dbe43", dec=6),
    "arb": dict(rpc="https://arb1.arbitrum.io/rpc",
                diamond="0x8F06459f184553e5d04F07F868720BDaCAB39395", dec=6),
    "mantle": dict(rpc="https://rpc.mantle.xyz",
                   diamond="0x2Ecc7da3Cc98d341F987C85c3D9FC198570838B5", dec=18),
    "blast": dict(rpc="https://blast-rpc.publicnode.com",
                  diamond="0x3d17f073cCb9c3764F105550B0BCF9550477D266", dec=18),
}


def chunks(seq, n):
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def run(chain, top_n=50):
    cfg = CFG[chain]
    r = Rpc(cfg["rpc"])
    blk = r.block_number()
    bh = hex(blk)
    agg = json.load(open(os.path.join(RAW, f"agg_{chain}.json")))
    seen = {}
    for a in list(agg["accounts"].keys()) + list(agg["deposits"].keys()) + list(agg["withdrawals"].keys()):
        seen[a] = True
    accts = sorted(seen)
    print(f"[{chain}] block {blk}: {len(accts)} partyA accounts to read")
    out = {"chain": chain, "block": blk, "diamond": cfg["diamond"],
           "accounts_total": len(accts), "dec": cfg["dec"]}

    # Pass 1: free balance + allocated balance for ALL accounts
    free = {}
    alloc = {}
    for i, batch in enumerate(chunks(accts, 100)):
        calls = []
        for a in batch:
            calls.append(("balanceOf", [a], cfg["diamond"]))
            calls.append(("allocatedBalanceOfPartyA", [a], cfg["diamond"]))
        res = r.batch_call(calls, bh)
        for j, a in enumerate(batch):
            free[a] = res[2 * j][0] if res[2 * j] else None
            alloc[a] = res[2 * j + 1][0] if res[2 * j + 1] else None
        if (i + 1) % 10 == 0:
            print(f"  pass1 {i+1} batches, {min((i+1)*100, len(accts))}/{len(accts)}", flush=True)
    out["free_total"] = sum(v for v in free.values() if v)
    out["allocated_total"] = sum(v for v in alloc.values() if v)
    print(f"[{chain}] sum free={out['free_total']/10**cfg['dec']:,.6f} allocated={out['allocated_total']/10**cfg['dec']:,.6f}")

    # Top accounts by deposit
    dep = agg["deposits"]
    top = sorted(dep.items(), key=lambda kv: -kv[1]["deposit_units"])[:top_n]
    top_accts = [a for a, _ in top]
    # include accounts with largest live free+alloc in top set too
    live_sorted = sorted(accts, key=lambda a: -((free.get(a) or 0) + (alloc.get(a) or 0)))
    top_live = live_sorted[:top_n]
    detail_set = list(dict.fromkeys(top_accts + top_live))

    details = {}
    for batch in chunks(detail_set, 25):
        calls = []
        for a in batch:
            calls += [
                ("balanceInfoOfPartyA", [a], cfg["diamond"]),
                ("partyAStats", [a], cfg["diamond"]),
                ("isPartyALiquidated", [a], cfg["diamond"]),
                ("isSuspended", [a], cfg["diamond"]),
                ("withdrawCooldownOf", [a], cfg["diamond"]),
                ("nonceOfPartyA", [a], cfg["diamond"]),
                ("quotesLength", [a], cfg["diamond"]),
                ("partyAPositionsCount", [a], cfg["diamond"]),
            ]
        res = r.batch_call(calls, bh)
        for j, a in enumerate(batch):
            base = 8 * j
            det = {}
            bi = res[base]
            if bi:
                det["balance_info"] = {
                    "allocated": bi[0], "locked_cva": bi[1], "locked_lf": bi[2],
                    "locked_partyAmm": bi[3], "locked_partyBmm": bi[4],
                    "pending_cva": bi[5], "pending_lf": bi[6],
                    "pending_partyAmm": bi[7], "pending_partyBmm": bi[8]}
            st = res[base + 1]
            if st:
                det["stats"] = {
                    "is_liquidated": st[0], "allocated": st[1], "locked_cva": st[2],
                    "locked_lf": st[3], "locked_partyAmm": st[4], "locked_partyBmm": st[5],
                    "pending_cva": st[6], "pending_lf": st[7], "pending_partyAmm": st[8],
                    "pending_partyBmm": st[9], "positions_count": st[10],
                    "pending_quotes_count": st[11], "nonce": st[12], "quote_ids_count": st[13]}
            det["is_liquidated"] = res[base + 2][0] if res[base + 2] else None
            det["is_suspended"] = res[base + 3][0] if res[base + 3] else None
            det["withdraw_cooldown"] = res[base + 4][0] if res[base + 4] else None
            det["nonce"] = res[base + 5][0] if res[base + 5] else None
            det["quotes_length"] = res[base + 6][0] if res[base + 6] else None
            det["positions_count"] = res[base + 7][0] if res[base + 7] else None
            det["free"] = free.get(a)
            det["deposit_units"] = dep.get(a, {}).get("deposit_units", 0)
            det["withdraw_units"] = agg["withdrawals"].get(a, {}).get("withdraw_units", 0)
            det["user"] = (agg["accounts"].get(a) or {}).get("user") or (dep.get(a) or {}).get("user")
            det["name"] = (agg["accounts"].get(a) or {}).get("name")
            details[a] = det
    out["top_details"] = details

    # Pass 2: partyB allocations per partyA (only accounts with allocated > 0)
    partybs = agg["partyB_registered"]
    out["partyB_registered"] = partybs
    nonzero = [a for a in accts if (alloc.get(a) or 0) > 0]
    print(f"[{chain}] {len(nonzero)} accounts with allocated>0; reading per-partyB allocations")
    pb_alloc = {}
    pb_errors = 0
    for batch in chunks(nonzero, 10):
        calls = [("allocatedBalanceOfPartyBs", [a, partybs], cfg["diamond"]) for a in batch]
        res = r.batch_call(calls, bh)
        for a, v in zip(batch, res):
            if v is None:
                pb_errors += 1
                continue
            vals = v[0] if (isinstance(v, (list, tuple)) and len(v) == 1 and isinstance(v[0], (list, tuple))) else v
            for pb, val in zip(partybs, vals):
                if val:
                    pb_alloc.setdefault(pb, {})[a] = val
    out["partyB_allocations"] = {pb: {"total": sum(d.values()), "per_partyA": d}
                                 for pb, d in pb_alloc.items()}
    out["partyB_alloc_errors"] = pb_errors
    tot_pb = sum(d["total"] for d in out["partyB_allocations"].values())
    out["partyB_allocated_total"] = tot_pb
    print(f"[{chain}] partyB allocated total={tot_pb/10**cfg['dec']:,.6f} (errors {pb_errors})")

    # partyB status
    status = {}
    for pb in partybs:
        calls = [("isPartyB", [pb], cfg["diamond"]),
                 ("getPartyBEmergencyStatus", [pb], cfg["diamond"]),
                 ("balanceInfoOfCrossPartyB", [pb], cfg["diamond"]),
                 ("isCrossPartyB", [pb], cfg["diamond"]),
                 ("balanceOfReserveVault", [pb], cfg["diamond"]),
                 ("partyBLiquidationTimestamp", [pb, "0x0000000000000000000000000000000000000000"], cfg["diamond"])]
        res = r.batch_call(calls, bh)
        st = {"isPartyB": res[0][0] if res[0] else None,
              "emergency": res[1][0] if res[1] else None,
              "cross_info": list(res[2]) if res[2] else None,
              "is_cross": res[3][0] if res[3] else None,
              "reserve_vault": res[4][0] if res[4] else None,
              "liq_ts_zero": res[5][0] if res[5] else None}
        status[pb] = st
    out["partyB_status"] = status

    # diamond balance
    coll = agg["collateral"]
    v = r.eth_call("balanceOf", [cfg["diamond"]], coll, bh)
    out["diamond_collateral_balance"] = v[0] if v else None
    out["diamond_native_balance"] = r.get_balance(cfg["diamond"], bh)

    with open(os.path.join(RAW, f"accounts_{chain}.json"), "w") as f:
        json.dump(out, f, indent=1, default=lambda o: "0x" + o.hex() if isinstance(o, bytes) else str(o))
    print(f"[{chain}] accounts written")


if __name__ == "__main__":
    chain = sys.argv[1]
    topn = int(sys.argv[2]) if len(sys.argv) > 2 else 50
    run(chain, topn)
