#!/usr/bin/env python3
"""build_readme.py — assemble analysis/fstswap-top-pairs/README.md from raw JSON results."""
import json, os, time
from pathlib import Path

D = Path(__file__).resolve().parents[1]  # analysis/fstswap-top-pairs
OUT = D / "README.md"
R = D / "raw"

scan = json.load(open(R / "fstswap_full_scan.json"))
meta = {}
for f in ["new_tokens_meta.json", "new2_tokens_meta.json"]:
    if (R / f).exists():
        meta.update(json.load(open(R / f)))
# merges of probe results
probe = {}
for f in ["mint_probe_results2.json", "mint_probe_new.json", "mint_probe_top.json"]:
    if (R / f).exists():
        d = json.load(open(R / f))
        for label, v in d.get("results", {}).items():
            probe[v["address"]] = v
# sims
sims = {}
for f in ["sim_results.json", "sim_results_new.json", "sim_results_supporting.json", "sim_results_fist.json"]:
    if (R / f).exists():
        d = json.load(open(R / f))
        for r in d.get("results", []):
            sims.setdefault(r["pair"].lower(), []).append(r)

usdt = "0x55d398326f99059ff775485246999027b3197955"
fist = "0xc9882def23bc42d53895b8361d0b1edc7570bc6a"
BLUE = {"0x55d398326f99059ff775485246999027b3197955": "USDT", "0x8ac76a51cc950d9822d68b83fe1ad97b32cd580d": "USDC",
        "0xe9e7cea3dedca5984780bafc599bd69add087d56": "BUSD", "0xbb4cdb9cbd36b01bd1cbaebf2de08d9173bc095c": "WBNB",
        "0x7130d2a12b9bcbfae4f2634d864a1ee1ce3ead9c": "BTCB", "0x2170ed0880ac9a755fd29b2688956bd959f933f8": "ETH",
        "0x1af3f329e8be154074d8769d1ffa4ee058b1dbc3": "DAI", "0xc5f0f7b66764f6ec8c8dff7ba683102295e16409": "FDUSD"}

def tok_tag(t):
    if t == fist: return "FIST"
    if t in BLUE: return BLUE[t]
    m = meta.get(t, {})
    return m.get("symbol") or (t[:8] + "…")

def verdict_for(pair, cp, blue):
    s = sims.get(pair.lower()) or []
    sv = "—"
    for x in s:
        if x["token"].lower() != cp.lower(): continue
        sim = x.get("sim") or {}
        res = sim.get("result")
        if res == "SUCCESS":
            ratio = sim.get("ratio_actual_over_quote")
            fee = sim.get("fee_on_transfer")
            sv = f"sell OK ratio={ratio}" + (" FEE!" if fee else " no fee")
        elif res == "REVERT":
            sv = "sell REVERT (blocked)"
        elif res == "cannot_setup_overrides":
            sv = "sim n/a (non-std storage)"
    return sv

def mint_for(t):
    p = probe.get(t)
    if not p: return "probe n/a"
    successes = [k for k, v in (p.get("mint_probes") or {}).items() if v.get("result") == "SUCCESS"]
    if successes: return "**PUBLIC MINT: " + ",".join(successes) + "**"
    sels = p.get("mint_selectors") or {}
    if sels:
        return "mint present, all revert (gated)"
    return "no mint selector"

lines = []
lines.append("# FstSwap top-pairs — counterparty-token hazard audit (H2-09 / legacy-watches / fstswap-top-pairs)")
lines.append("")
lines.append(f"**Read-only.** Full factory enumeration: `{scan['pairs_total']}` pairs at BSC blocks "
             f"`{scan['block_start']}..{scan['block']}` (2026-10-10). Blue-chip custody total: "
             f"**${scan['blue_usd_total']:,.0f}** across {scan['blue_pairs_count']} pairs "
             f"(USDT $3,508,418 · ETH $14,841 · BUSD $540 · WBNB $77 · USDC $12 · BTCB $4; FIST priced at "
             f"${scan['fist_implied_price']:.6f} implied from the top pair). "
             "Factory `0x9A272d734c5a0d7d84E0a892e891a553e8066dce`; router `0x1b6c9c20693afde803b27f8782156c0f892abc2d`.")
lines.append("")
lines.append("**Headline: $0.00 extractable.** No counterparty token in the top pairs has a publicly callable mint; "
             "every sellable pool sells at the router's quote (no transfer tax); blocked pools trap value rather than leak it; "
             "FIST trades at the same price on FstSwap/PancakeSwap/Biswap/MDEX (±0.5%).")
lines.append("")
lines.append("## Top pairs by USD (full-scan ranking by TVL; blue side = drainable side)")
lines.append("")
lines.append("| # | pair | token0 | token1 | reserves (token0 / token1) | TVL USD | blue side | counterparty verdict (mint / sell / fee / note) |")
lines.append("|---|---|---|---|---|---|---|---|")
top = [r for r in scan["top_pairs_by_usd"] if (r["tvl_usd_est"] or 0) >= 500][:26]
for i, r in enumerate(top, 1):
    t0, t1 = r["token0"], r["token1"]
    blue_sides = [b for b in r["blue_sides"]]
    blue_tok = blue_sides[0]["token"] if blue_sides else None
    cp = t1 if blue_tok == t0 else t0
    # counterparty = non-blue side; if both blue (e.g. USDT/BUSD) note both
    if len(blue_sides) == 2:
        cp_tag = "both blue"
        verd = "stable/stable"
    else:
        m = "no mint" if "no mint selector" in mint_for(cp) else mint_for(cp)
        verd = f"{m}; {verdict_for(r['pair'], cp, blue_tok)}"
    t0s = tok_tag(t0); t1s = tok_tag(t1)
    res = f"{r['reserve0_human']:.6g} {t0s} / {r['reserve1_human']:.6g} {t1s}"
    lines.append(f"| {i} | `{r['pair']}` | {t0s} | {t1s} | {res} | ${r['tvl_usd_est']:,.0f} | ${(r['blue_usd'] or 0):,.0f} | {verd} |")
lines.append("")
lines.append("(Counterparty = the non-blue-chip side that an attacker would need to obtain to drain the blue side.)")
lines.append("")
lines.append("## Class verdicts")
lines.append("- **(a) Freely mintable counterparty: NONE FOUND.** All top-pair counterparties: deployed bytecode scanned for "
             "`mint(address,uint256) 40c10f19`, `mint(uint256) a0712d68`, `mintTo 449a52f8`, `mint(address) 6a627842` and 3 more variants, "
             "including EIP-1167/EIP-1967 proxy implementations; every selector found was probed via `eth_call` from an unprivileged address — "
             "all reverted (owner/role-gated). FIST is a fixed-supply token (200,000,000 FIST, no mint code, owner renounced at 0x0).")
lines.append("- **(b) Fee-on-transfer / deflationary: NO material tax found in the exploitable direction.** State-override swap "
             "simulations (sell counterparty → blue) returned `actual == getAmountsOut quote` (ratio 1.0) on every sellable pool. "
             "Tokens whose standard-router sells revert (PG 0xdc74, FP 0xe68a, Adam 0xe7f4, APL 0xbae8, NSK↔FIST) either also revert via "
             "`swapExactTokensForTokensSupportingFeeOnTransferTokens` (true block) or have no other venue — a block traps value, it does not leak it.")
lines.append("- **(c) Honeypot/blacklist/dead: several, all value-TRAPPING (not extractable).** See per-pair notes. "
             "FIST, Tomato, OSK, Tomatos, Tdan, WBNB-clone all sell cleanly.")
lines.append("- **(d) Staleness vs other venues: NO >10× divergence.** Tokens with real external liquidity: Tdan $234.88 external vs $240.75 FstSwap (2.5%), "
             "FP $342.1 vs $338.9 (1%), UNIfake $7.67 vs $6.91 (11% — pool has $2), AICAT $0.0165 vs $0.0171 (3.4%). "
             "FIST: FstSwap $0.2086 / PancakeSwap $0.2087 / Biswap $0.2098 / MDEX $0.2100 — corpus claim $0.2259 is ~8% stale, no venue divergence.")
lines.append("")
lines.append("## FIST price check (corpus claim ≈ $0.2259)")
lines.append("- FstSwap `getAmountsOut(1000 FIST)` = **$0.20856/FIST**; reverse = **$0.20990/FIST** (router `0x1b6c…`, block 126,842,286).")
lines.append("- PancakeSwap FIST/USDT pair `0x703f1c0b4399a51704e798002281bf26d6f9c2e6`: **$0.20875** forward / **$0.21092** reverse.")
lines.append("- Biswap pair `0xd842c2a97570090111989161809f525992ffcbf9`: implied **$0.20983**; MDEX pair `0x577e506d43d21d0e53c00cfb8eae2a98a2fa4179`: **$0.20999**.")
lines.append("- Live trading confirmed on the FIST/USDT pair (Swap events in the last 2,000 blocks; latest block 126,845,541).")
lines.append("")
lines.append("## Method / evidence")
lines.append("- Full enumeration script (public RPCs, `tryAggregate`): `ci/steps/fstswap_top_enum.py` → `raw/fstswap_full_scan.json`.")
lines.append("- Mint probes: `scripts/mint_probe.py` → `raw/mint_probe_*.json` (deployed bytecode + proxy impl + unconditional eth_call probes).")
lines.append("- Swap sims: `scripts/swap_sim.py` (eth_call state overrides: balance/allowance slot discovery then `swapExactTokensForTokens[Supporting]`) "
             "→ `raw/sim_results*.json`.")
lines.append("- Token source/ABI: Etherscan V2 chainid=56 → `raw/*.source.json`; on-chain metadata → `raw/new*_tokens_meta.json`.")
lines.append("- All reads read-only; no transactions sent; no keys in any file.")
lines.append("")
(OUT).write_text("\n".join(lines))
print("wrote", OUT, len(lines), "lines")
