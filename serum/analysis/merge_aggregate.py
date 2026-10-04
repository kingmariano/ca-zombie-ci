#!/usr/bin/env python3
"""Merge enumerated market chunks -> openbook_markets.jsonl.gz + aggregates + tables."""
import glob, gzip, json, os, sys, time
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
CHUNK_DIR = os.environ.get("OB_CHUNK_DIR", os.path.join(HERE, "chunks"))
OUT_JSONL = os.environ.get("OB_OUT_JSONL", os.path.join(HERE, "openbook_markets.jsonl.gz"))
OUT_AGG = os.path.join(HERE, "openbook_aggregates.json")
OUT_TABLES = os.path.join(HERE, "openbook_market_tables.md")

def load_chunks():
    files = sorted(glob.glob(os.path.join(CHUNK_DIR, "n*.jsonl")))
    metas = {}
    for mf in glob.glob(os.path.join(CHUNK_DIR, "n*.meta.json")):
        name = os.path.basename(mf).replace(".meta.json", "")
        with open(mf) as f:
            metas[name] = json.load(f)
    seen = {}
    dup = 0
    bad = 0
    for fp in files:
        with open(fp) as f:
            for line in f:
                if not line.strip():
                    continue
                try:
                    r = json.loads(line)
                except Exception:
                    bad += 1
                    continue
                pk = r["pubkey"]
                if pk in seen:
                    dup += 1
                    continue
                seen[pk] = r
    return seen, metas, len(files), dup, bad

def main():
    t0 = time.time()
    markets, metas, nfiles, dup, bad = load_chunks()
    print(f"loaded {len(markets)} unique markets from {nfiles} chunk files "
          f"(dups={dup}, bad={bad}) in {time.time()-t0:.1f}s")
    # per-nonce counts
    per_nonce = defaultdict(int)
    for r in markets.values():
        per_nonce[r["nonce"]] += 1
    meta_counts = defaultdict(int)
    for name, m in metas.items():
        n = int(name.split("_")[0][1:])
        meta_counts[n] += m["count"]
    print("per-nonce unique:", dict(sorted(per_nonce.items())))
    missing = {n: (meta_counts[n], per_nonce.get(n, 0))
               for n in meta_counts if meta_counts[n] != per_nonce.get(n, 0)}
    if missing:
        print("COUNT MISMATCH nonce: (meta_sum, merged)", missing)
    else:
        print("counts consistent: meta sums == merged per-nonce counts")

    # write sorted gz jsonl
    with gzip.open(OUT_JSONL, "wt", compresslevel=6) as g:
        for pk in sorted(markets):
            g.write(json.dumps(markets[pk], separators=(",", ":")) + "\n")
    print("wrote", OUT_JSONL, os.path.getsize(OUT_JSONL), "bytes")

    # aggregates
    mint_stats = defaultdict(lambda: {"count": 0, "amount": 0,
                                      "as_coin_count": 0, "as_pc_count": 0,
                                      "coin_amount": 0, "pc_amount": 0})
    total_coin_dep = 0
    total_pc_dep = 0
    total_coin_fees = 0
    total_pc_fees = 0
    total_referrer = 0
    nonzero_any = 0
    nonzero_coin = 0
    nonzero_pc = 0
    fee_nonzero = 0
    total_lamports = 0
    nonce_stats = defaultdict(lambda: {"count": 0, "coin_dep": 0, "pc_dep": 0,
                                       "lamports": 0, "nonzero": 0})
    top_markets = []
    for r in markets.values():
        cd, pd = r["coin_dep"], r["pc_dep"]
        total_coin_dep += cd
        total_pc_dep += pd
        total_coin_fees += r["coin_fees"]
        total_pc_fees += r["pc_fees"]
        total_referrer += r["referrer_rebates"]
        total_lamports += r["lamports"]
        if cd > 0 or pd > 0:
            nonzero_any += 1
        if cd > 0:
            nonzero_coin += 1
        if pd > 0:
            nonzero_pc += 1
        if r["fee_rate_bps"] != 0:
            fee_nonzero += 1
        ns = nonce_stats[r["nonce"]]
        ns["count"] += 1
        ns["coin_dep"] += cd
        ns["pc_dep"] += pd
        ns["lamports"] += r["lamports"]
        if cd > 0 or pd > 0:
            ns["nonzero"] += 1
        for mint, amt, side in ((r["coin_mint"], cd, "coin"), (r["pc_mint"], pd, "pc")):
            s = mint_stats[mint]
            s["count"] += 1
            s["amount"] += amt
            if side == "coin":
                s["as_coin_count"] += 1
                s["coin_amount"] += amt
            else:
                s["as_pc_count"] += 1
                s["pc_amount"] += amt
        top_markets.append((cd + pd, r))

    top_markets.sort(key=lambda t: -t[0])
    top50_by_amount = sorted(mint_stats.items(), key=lambda kv: -kv[1]["amount"])[:50]
    top50_by_count = sorted(mint_stats.items(), key=lambda kv: -kv[1]["count"])[:50]
    top100_markets = [r for _, r in top_markets[:100]]

    agg = {
        "generated_at": time.time(),
        "generated_at_utc": time.strftime("%Y-%m-%d %H:%M:%S UTC", time.gmtime()),
        "program": "srmqPvymJeFKQ4zGQed1GFppgkRHL9kaELCbyksJtPX",
        "total_markets": len(markets),
        "per_nonce_counts": {str(k): v for k, v in sorted(per_nonce.items())},
        "total_coin_deposits_raw": total_coin_dep,
        "total_pc_deposits_raw": total_pc_dep,
        "total_coin_fees_accrued_raw": total_coin_fees,
        "total_pc_fees_accrued_raw": total_pc_fees,
        "total_referrer_rebates_accrued_raw": total_referrer,
        "markets_with_any_deposit": nonzero_any,
        "markets_with_coin_dep": nonzero_coin,
        "markets_with_pc_dep": nonzero_pc,
        "markets_fee_rate_nonzero": fee_nonzero,
        "sum_market_account_lamports": total_lamports,
        "unique_mints": len(mint_stats),
        "nonce_stats": {str(k): v for k, v in sorted(nonce_stats.items())},
        "top50_mints_by_amount": [
            {"mint": m, **s} for m, s in top50_by_amount],
        "top50_mints_by_market_count": [
            {"mint": m, **s} for m, s in top50_by_count],
        "top100_markets_by_deposits": top100_markets,
    }
    with open(OUT_AGG, "w") as f:
        json.dump(agg, f, indent=1)
    print("wrote", OUT_AGG)

    # markdown tables
    with open(OUT_TABLES, "w") as f:
        f.write(f"# OpenBook v1 market enumeration — tables\n\n")
        f.write(f"Generated {agg['generated_at_utc']} (read-only RPC; finalized).\n\n")
        f.write(f"- Total initialized markets (flags=3, dataSize=388): **{len(markets):,}**\n")
        f.write(f"- Per-nonce counts: {', '.join(f'n{k}={v:,}' for k,v in sorted(per_nonce.items()))}\n")
        f.write(f"- Markets with any deposit > 0: **{nonzero_any:,}** "
                f"(coin>0: {nonzero_coin:,}, pc>0: {nonzero_pc:,})\n")
        f.write(f"- Sum market-account lamports: {total_lamports:,} "
                f"({total_lamports/1e9:,.2f} SOL)\n")
        f.write(f"- Markets with fee_rate_bps != 0: {fee_nonzero:,}\n\n")
        f.write("## Top 50 mints by total deposited amount (raw units; coin+pc vaults)\n\n")
        f.write("| # | mint | markets | total_raw | coin_amount | pc_amount |\n")
        f.write("|---|------|--------:|----------:|------------:|----------:|\n")
        for i, (m, s) in enumerate(top50_by_amount, 1):
            f.write(f"| {i} | `{m}` | {s['count']:,} | {s['amount']:,} | "
                    f"{s['coin_amount']:,} | {s['pc_amount']:,} |\n")
        f.write("\n## Top 50 mints by market count\n\n")
        f.write("| # | mint | markets | total_raw |\n|---|------|--------:|----------:|\n")
        for i, (m, s) in enumerate(top50_by_count, 1):
            f.write(f"| {i} | `{m}` | {s['count']:,} | {s['amount']:,} |\n")
        f.write("\n## Top 100 markets by (coin_dep + pc_dep) raw sum\n\n")
        f.write("| # | market | nonce | coin_mint | pc_mint | coin_dep | pc_dep | lamports |\n")
        f.write("|---|--------|------:|-----------|---------|---------:|-------:|---------:|\n")
        for i, r in enumerate(top100_markets, 1):
            f.write(f"| {i} | `{r['pubkey']}` | {r['nonce']} | `{r['coin_mint']}` | "
                    f"`{r['pc_mint']}` | {r['coin_dep']:,} | {r['pc_dep']:,} | {r['lamports']:,} |\n")
    print("wrote", OUT_TABLES)
    print(f"done in {time.time()-t0:.1f}s")

if __name__ == "__main__":
    main()
