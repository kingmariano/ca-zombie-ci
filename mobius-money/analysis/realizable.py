#!/usr/bin/env python3
"""Realizability-adjusted valuation of Mobius pools.
Uses analysis/valuation.json (fresh balances + DefiLlama) and applies a per-token
realizability factor based on live on-chain markets (analysis/markets.md, child audit).
Output: analysis/realizable.md + analysis/realizable.json
"""
import json, os

HERE = os.path.dirname(os.path.abspath(__file__))
V = json.load(open(os.path.join(HERE, "valuation.json")))

# token -> (factor, note)
FACT = {
    "0x765de816845861e75a25fca122bb6898b8b1282a": (1.0, "USDm (Mento, redeemable)"),
    "0x90ca507a5d4458a4c6c6249d186b6dcb02a5bccd": (1.0, "DAI (Celo)"),
    "0x2a3684e9dc20b857375ea04235f2f7edbe818fa7": (1.0, "USDCet (Optics) live Ubeswap mkt"),
    "0x37f750b7cc259a2f741af45294f6a16572cf5cad": (1.0, "USDC (Wormhole/portal)"),
    "0x93db49be12b864019da9cb147ba75cdc0506190e": (1.0, "cUSDC (Mento-listed)"),
    "0xcfffe0c89a779c09df3df5624f54cdf7ef5fdd5d": (1.0, "cUSDT (Mento-listed)"),
    "0xd8763cba276a3738e6de85b4b3bf5fded6d6ca73": (1.0, "EURm (Mento)"),
    "0x471ece3750da237f93b8e339c536989b8978a438": (1.0, "CELO (native)"),
    "0xe919f65739c26a42616b7b8eedc6b5524d1e3ac4": (1.0, "WETH"),
    "0x122013fd7df1c6f636a5bb8f03108e876548b455": (1.0, "WETH (Optics)"),
    "0x2def4285787d58a2f811af24755a8150622f4361": (0.7, "cETH (Optics 'Wrapped Ethereum') - thin mkt"),
    "0x1bfc26ce035c368503fae319cc2596716428ca44": (0.5, "USDC (Optics v2) - thin/dead mkt"),
    "0xcc82628f6a8defa1e2b0ad7ed448bef3647f7941": (0.5, "USDC (variant) - thin/dead mkt"),
    "0xef4229c8c3250c675f21bcefa42f58efbff6002a": (0.5, "USDC (variant) - thin/dead mkt"),
    "0xdc5762753043327d74e0a538199c1488fc1f44cf": (0.5, "rstCELO (Staked Celo rebased; redeemability unverified)"),
    "0xed193c4e69f591e42398ef54dea65aa1bb02835c": (0.0, "atUST (dead Terra claim; mkt $0.06 depth)"),
    "0xb4aa2986622249b1f45eb93f28cfca2b2606d809": (0.0, "pUSD v1 (Poof zk, dead)"),
    "0xeadf4a7168a82d30ba0619e64d5bcf5b30b45226": (0.0, "pUSD v2 (Poof zk, dead)"),
    "0x56072d4832642db29225da12d6fd1290e4744682": (0.0, "pEUR v1 (Poof zk, dead)"),
    "0xd8761dd6c7cb54febd33add699f5e4440b62e01b": (0.0, "pEUR v2 (Poof zk, no market)"),
    "0xe74abf23e1fdf7acbec2f3a30a772ef77f1601e1": (0.0, "pCELO v1 (Poof zk, dead)"),
    "0x301a61d01a63c8d670c2b8a43f37d12ef181f997": (0.0, "pCELO v2 (Poof zk, dead)"),
    "0xb70e0a782b058bfdb0d109a3599bec1f19328e36": (0.0, "aaUSDC (Allbridge - paused; no mkt)"),
    "0xcd7d7ff64746c1909e44db8e95331f9316478817": (0.0, "asUSDC (Allbridge - paused; no mkt)"),
    "0xd629eb00deced2a080b7ec630ef6ac117e614f1b": (0.0, "BTC18 TokenSoft - no liquidation venue; cross-rate mark ~$44.5k is thin/stale"),
    "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b": (0.0, "WBTC2 (Optics) - no liquidation venue"),
    "0xbe50a3013a1c94768a1abb78c3cb79ab28fc1ace": (0.0, "oldWBTC (Optics) - no liquidation venue"),
    "0x73a210637f6f6b7005512677ba6b3c96bb4aa44b": (0.0, "MOBI - ~$0"),
}

rows = []
tot_dl = 0.0
tot_real = 0.0
tot_btc_paper_dl = 0.0
for p, e in V["pools"].items():
    dl = e["total_usd_priced"]
    real = 0.0
    det = []
    for t in e["tokens"]:
        f, note = FACT.get(t["token"].lower(), (0.0, "unmapped -> 0"))
        v = t.get("usd")
        if v is None:
            v = 0.0
        real += v * f
        if v and f != 1.0:
            det.append(f"{t['symbol']} {t['amount']:.6g} (${v:,.2f} x{f}) {note}")
        elif f == 1.0 and v:
            det.append(f"{t['symbol']} {t['amount']:.6g} (${v:,.2f})")
        if t["token"].lower() in ("0xd629eb00deced2a080b7ec630ef6ac117e614f1b", "0xbaab46e28388d2779e6e31fd00cf0e5ad95e327b"):
            tot_btc_paper_dl += (v or 0)
    rows.append({"pool": p, "dl_usd": dl, "realizable_usd": round(real, 2), "paused": e["paused"],
                 "detail": det})
    tot_dl += dl
    tot_real += real

rows.sort(key=lambda r: -r["dl_usd"])
with open(os.path.join(HERE, "realizable.json"), "w") as f:
    json.dump({"totals": {"dl_usd": round(tot_dl, 2), "realizable_usd": round(tot_real, 2),
                          "btc_paper_dl_usd": round(tot_btc_paper_dl, 2)}, "pools": rows}, f, indent=1)

lines = ["# Mobius pools — DefiLlama-priced vs realizability-adjusted value",
         "",
         f"- **DL-priced total (fresh balances, correct token ids): ${tot_dl:,.2f}**",
         f"- **Realizability-adjusted total: ${tot_real:,.2f}** (junk-side & BTC-token sides haircut to 0; see FACT table in script)",
         f"- Of the DL total, **${tot_btc_paper_dl:,.2f}** is the two BTC pools' d629/baab sides (no on-chain liquidation venue; paper only).",
         "",
         "| pool | paused | DL USD | realizable USD | detail |",
         "|---|---|---|---|---|"]
for r in rows:
    lines.append(f"| `{r['pool']}` | {r['paused']} | {r['dl_usd']:,.2f} | {r['realizable_usd']:,.2f} | {'; '.join(r['detail'])[:220]} |")
open(os.path.join(HERE, "realizable.md"), "w").write("\n".join(lines) + "\n")
print("\n".join(lines[:12]))
print("...")
print(f"TOTALS: DL=${tot_dl:,.2f}  realizable=${tot_real:,.2f}  btc_paper=${tot_btc_paper_dl:,.2f}")
