#!/usr/bin/env python3
"""Pull Minswap V1 (type 'Minswap') metrics with USD currency; save; rank by liquidity_currency."""
import json, urllib.request, time, sys

def pull(protocols, pages=3, limit=100, currency="usd"):
    url = "https://api-mainnet-prod.minswap.org/v1/pools/metrics"
    out = []
    search_after = None
    for p in range(pages):
        body = {"sort_field": "liquidity", "protocols": protocols, "limit": limit}
        if currency: body["currency"] = currency
        if search_after: body["search_after"] = search_after
        import subprocess
        for i in range(5):
            try:
                cp = subprocess.run(["curl","-s","--max-time","60","-X","POST",url,
                    "-H","Content-Type: application/json","-H","User-Agent: Mozilla/5.0 lab",
                    "-d",json.dumps(body)], capture_output=True, text=True, timeout=70)
                d = json.loads(cp.stdout)
                break
            except Exception as e:
                print("retry", i, e, file=sys.stderr); time.sleep(2*(i+1))
        else:
            raise SystemExit("fail")
        out.extend(d["pool_metrics"])
        search_after = d.get("search_after")
        print(f"page {p+1}: {len(d['pool_metrics'])} pools, cum {len(out)}")
        time.sleep(0.5)
    return {"currency": currency, "protocols": protocols, "search_after": search_after, "pool_metrics": out}

d = pull(["Minswap"], pages=3)
json.dump(d, open("minswap_v1_usd_top300.json", "w"), indent=1)
pm = d["pool_metrics"]
pm_sorted = sorted(pm, key=lambda p: -(p.get("liquidity_currency") or 0))
print("\nTop 10 V1 by liquidity_currency (USD):")
for p in pm_sorted[:10]:
    a, b = p["asset_a"], p["asset_b"]
    va = a.get("is_verified"); vb = b.get("is_verified")
    print(f"  ${p['liquidity_currency']:>14,.2f}  A={a.get('metadata',{}).get('ticker') or a['currency_symbol'][:8]} (v={va}) B={b.get('metadata',{}).get('ticker') or b['currency_symbol'][:8]} (v={vb})")
    print(f"      liqA={p['liquidity_a']} ({p['liquidity_a_currency']:.2f} USD) liqB={p['liquidity_b']} ({p['liquidity_b_currency']:.2f} USD) lp={p['lp_asset']['currency_symbol'][:8]}.{p['lp_asset']['token_name'][:20]} vol24h=${p.get('volume_24h') or 0:,.0f} pending={p['pending_order_info']['total']}")
tot = sum(p.get("liquidity_currency") or 0 for p in pm)
both_ver = sum(p.get("liquidity_currency") or 0 for p in pm if p["asset_a"].get("is_verified") and p["asset_b"].get("is_verified"))
print(f"\nTop-{len(pm)} census totals: nominal ${tot:,.2f}; both-verified ${both_ver:,.2f}")
