#!/usr/bin/env python3
"""Compute token metadata + prices + arbitrage cycles from a pairs_fresh.json artifact
(written by full_scan.py) without re-scanning the chain. Read-only; keyless public RPC."""
import json, os, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import full_scan as fs

def main():
    artifact, outdir = sys.argv[1], sys.argv[2]
    os.makedirs(outdir, exist_ok=True)
    data = json.load(open(artifact))
    pairs, blk = data["pairs"], data.get("block")
    toks = set()
    for pa, d in pairs.items():
        if d.get("b0"): toks.add(d["token0"])
        if d.get("b1"): toks.add(d["token1"])
    print(f"[artifact] block={blk} pairs={len(pairs)} tokens={len(toks)}")
    meta = fs.token_meta(sorted(toks))
    px = fs.prices(list(meta.keys()))
    from collections import defaultdict
    totals = defaultdict(lambda: {"raw": 0, "usd": 0.0})
    for pa, d in pairs.items():
        for tok, bal in ((d["token0"], d.get("b0")), (d["token1"], d.get("b1"))):
            if tok and bal:
                dec = meta.get(tok, {}).get("decimals", 18)
                totals[tok]["raw"] += bal
                totals[tok]["usd"] += bal / (10 ** dec) * px.get(tok, 0)
    tot_rows = [{"token": t, "symbol": meta.get(t, {}).get("symbol"), "decimals": meta.get(t, {}).get("decimals"),
                 "amount": v["raw"] / (10 ** meta.get(t, {}).get("decimals", 18)), "usd": v["usd"],
                 "price": px.get(t, 0)} for t, v in totals.items()]
    tot_rows.sort(key=lambda x: -x["usd"])
    cycles, explored = fs.build_cycles(pairs, meta, px)
    json.dump({"block": blk, "prices": px, "cycles": cycles[:200], "explored": explored},
              open(os.path.join(outdir, "arb_cycles.json"), "w"), indent=1)
    excess = sum(1 for d in pairs.values() if (d.get("excess0") or 0) > 0 or (d.get("excess1") or 0) > 0)
    onesided = sum(1 for d in pairs.values() if (d.get("r0") == 0 and (d.get("b1") or 0) > 0) or (d.get("r1") == 0 and (d.get("b0") or 0) > 0))
    summary = {"block": blk, "rpc": fs.RPC, "pairs_count": len(pairs), "tokens": len(meta),
               "excess_pairs": excess, "one_sided_pairs": onesided,
               "total_usd_balances": sum(r["usd"] for r in tot_rows),
               "top_tokens": tot_rows[:25], "top_cycles": cycles[:25], "explored": explored}
    json.dump(summary, open(os.path.join(outdir, "scan_summary.json"), "w"), indent=1)
    print(json.dumps({"block": blk, "excess_pairs": excess, "one_sided": onesided,
                      "total_usd": summary["total_usd_balances"], "cycles": len(cycles),
                      "top3": cycles[:3]}, indent=1))

if __name__ == "__main__":
    main()
