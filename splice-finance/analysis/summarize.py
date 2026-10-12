#!/usr/bin/env python3
"""Summarize state_dump.json into per-SY live value + holder distribution (deduped by SY/PT).
Read-only; uses DefiLlama prices. Writes ci-out/splice_summary.json + markdown table."""
import json, sys, urllib.request, time

def price(ids):
    try:
        url = "https://coins.llama.fi/prices/current/" + ",".join(ids)
        req = urllib.request.Request(url, headers={"User-Agent":"Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=45) as r:
            d = json.loads(r.read())
        return {k: v["price"] for k, v in d.get("coins", {}).items()}
    except Exception as e:
        print("price fetch failed:", e)
        return {}

TOKENS = {
    "blast": {
        "0x4300000000000000000000000000000000000003": "blast:0x4300000000000000000000000000000000000003",  # USDB
        "0x4300000000000000000000000000000000000004": "blast:0x4300000000000000000000000000000000000004",  # WETH
        "0x15065421cdfef93c0493d75b4883b1d236457c4b": None,  # ezETH:ETH LP dust, unpriced
        "0xc201db2c73a7583d6ec638f5a0337e4c12e8ee52": None,
    },
    "mode": {
        "0x2416092f143378750bb29b79ed961ab195cceea5": "mode:0x2416092f143378750bb29b79ed961ab195cceea5",  # ezETH
        "0x04c0599ae5a44757c0af6f9ec3b93da8976c150a": "mode:0x04c0599ae5a44757c0af6f9ec3b93da8976c150a",  # weETH.mode
        "0x028227c4dd1e5419d11bb6fa6e661920c519d4f5": "mode:0x028227c4dd1e5419d11bb6fa6e661920c519d4f5",  # weETH
        "0xe7903b1f75c534dd8159b313d92cdcfbc62cb3cd": "mode:0xe7903b1f75c534dd8159b313d92cdcfbc62cb3cd",  # wrsETH
        "0xdfc7c877a950e49d2610114102175a06c2e3167a": "mode:0xdfc7c877a950e49d2610114102175a06c2e3167a",  # MODE
        "0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34": "mode:0x5d3a1ff2b6bab83b63cd9ad0787074081a52ef34",  # USDe
        "0x211cc4dd073734da055fbf44a2b4667d5e5fe5d2": "mode:0x211cc4dd073734da055fbf44a2b4667d5e5fe5d2",  # sUSDe
    },
}

def main(path_in, path_out):
    d = json.load(open(path_in))
    out = {"chains": {}, "generated_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())}
    for chain, c in d["chains"].items():
        ids = [i for i in TOKENS.get(chain, {}).values() if i]
        px = price(ids) if ids else {}
        pr = {a: (px.get(i, 0) if i else 0) for a, i in TOKENS.get(chain, {}).items()}

        # aggregate per unique SY
        sys_ = {}
        pts = {}
        for f in c.get("factories", []):
            if "error" in f: continue
            for m in f.get("markets", []):
                sy, yt, pt = m.get("sy"), m.get("yt"), m.get("pt")
                if not sy: continue
                s = sys_.setdefault(sy, {"sy": sy, "yt": yt, "markets": [], "market_sy": 0, "market_pt": 0, "lp_supply": 0,
                                          "pt_supply": 0, "pt": pt, "factory": f["label"], "expiry": m.get("expiry")})
                s["markets"].append(m["market"])
                s["lp_supply"] += m.get("lp_supply") or 0
                s["market_sy"] += m.get("market_sy_balance") or 0
                s["market_pt"] += m.get("market_pt_balance") or 0
                s["pt_supply"] = max(s["pt_supply"], m.get("pt_supply") or 0)
                s["yt_sy"] = m.get("yt_sy_balance") or 0
                s["yt_pt"] = m.get("yt_pt_balance") or 0
                p = pts.setdefault(pt, {"pt": pt, "supply": m.get("pt_supply") or 0, "in_markets": 0})
                p["in_markets"] += m.get("market_pt_balance") or 0

        rows = []
        for sy, s in sys_.items():
            syrow = c.get("sys", {}).get(sy, {}) or {}
            u = (syrow.get("uAsset") or "").lower()
            rate = syrow.get("exchangeRate") or 0
            dec = syrow.get("assetDecimals") or 18
            scale = 10 ** dec
            supply = syrow.get("sy_supply") or 0
            other = supply - s["market_sy"] - s.get("yt_sy", 0)
            tot_asset = supply * rate / 1e18 if rate else supply
            mkt_asset = s["market_sy"] * rate / 1e18 if rate else s["market_sy"]
            yt_asset = s.get("yt_sy", 0) * rate / 1e18 if rate else s.get("yt_sy", 0)
            oth_asset = other * rate / 1e18 if rate else other
            p = pr.get(u, 0)
            pt_out = s["pt_supply"] - s["market_pt"]
            rows.append({
                "chain": chain, "sy": sy, "yt": s["yt"], "pt": s["pt"], "factory": s["factory"],
                "expiry": s["expiry"], "markets": s["markets"], "asset": u, "asset_decimals": dec,
                "exchange_rate": rate, "price_usd": p, "sy_symbol": syrow.get("symbol"),
                "sy_supply": supply, "market_sy": s["market_sy"], "yt_sy": s.get("yt_sy", 0), "other_sy": other,
                "total_asset": tot_asset, "total_usd": tot_asset / scale * p,
                "market_asset": mkt_asset, "market_usd": mkt_asset / scale * p,
                "yt_asset": yt_asset, "yt_usd": yt_asset / scale * p,
                "other_asset": oth_asset, "other_usd": oth_asset / scale * p,
                "pt_supply": s["pt_supply"], "market_pt": s["market_pt"], "pt_outside_markets": pt_out,
                "yt_pt_balance": s.get("yt_pt", 0), "lp_supply": s["lp_supply"],
                "sy_owner": syrow.get("owner"), "sy_paused": syrow.get("paused"),
                "yield_token": syrow.get("yieldToken"), "vault_totalAssets": syrow.get("vault_totalAssets"),
                "vault_totalSupply": syrow.get("vault_totalSupply"), "vault_owner": syrow.get("vault_owner"),
            })
        out["chains"][chain] = {"block": c.get("block"), "rows": rows,
                                "total_usd": sum(r["total_usd"] for r in rows)}
    total = sum(v["total_usd"] for v in out["chains"].values())
    out["total_usd_all_chains"] = total
    json.dump(out, open(path_out, "w"), indent=1)

    lines = ["| chain | SY | symbol | asset | total USD | market-held | YT-contract-held | user-wallet | PT outside markets |",
             "|---|---|---|---|---|---|---|---|---|"]
    for chain, v in out["chains"].items():
        for r in sorted(v["rows"], key=lambda x: -x["total_usd"]):
            lines.append(f"| {chain} | {r['sy'][:10]} | {r['sy_symbol']} | {r['asset'][:10]} | {r['total_usd']:,.2f} | "
                         f"{r['market_usd']:,.2f} | {r['yt_usd']:,.2f} | {r['other_usd']:,.2f} | {r['pt_outside_markets']/1e18:,.2f} |")
    lines.append(f"\n**TOTAL (deduped by SY): ${total:,.2f}**")
    md = "\n".join(lines)
    open(path_out.replace(".json", ".md"), "w").write(md)
    print(md)

if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "state_dump.json",
         sys.argv[2] if len(sys.argv) > 2 else "splice_summary.json")
