#!/usr/bin/env python3
"""Build l2-triage-b/README.md from analysis/final_table.json + llama_meta.json + ci-out/results.json."""
import json, os, datetime

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
rows = json.load(open(os.path.join(ROOT, "analysis/final_table.json")))
meta = json.load(open(os.path.join(ROOT, "analysis/llama_meta.json")))
plan = json.load(open(os.path.join(ROOT, "ci/plan.json")))
res = json.load(open(os.path.join(ROOT, "ci-out/results.json")))
split = json.load(open(os.path.join(ROOT, "../ci/L2-SPLIT-B.json")))
stale = {r["protocol"].lower(): r for r in split}

CI_RUN = "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38131461859"
CI_RUN_DEEP = "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38134363405"
DATE = "2026-10-11"

funded = [r for r in rows if r["status"].startswith("LIVE")]
drained = [r for r in rows if r["status"].startswith("DRAINED")]
unreach = [r for r in rows if r["status"].startswith("UNREACHABLE")]
live_total = sum(r["onchain_usd"] for r in funded)

def fmt(x):
    return f"${x:,.0f}" if x else "$0"

def fmt2(x):
    return f"${x:,.2f}" if x else "$0"

out = []
w = out.append

w(f"# L-2 Phase-1 triage — Triage-B (alt-EVMs / L2s)")
w("")
w(f"**Date:** {DATE} · **Scope:** 29 watchlist rows (alt-EVM / L2 zombie candidates) · "
  f"**Status:** read-only custody screen; no transactions, no vulnerability analysis; "
  f"all balances read via keyless public RPCs at the blocks below.")
w("")
w(f"**CI runs (heavy enumeration):** full screen — {CI_RUN} · deep pass (all-pair scans) — {CI_RUN_DEEP}")
w("")
w("## 1. What this is")
w("")
w("Phase-1 of the L-2 sweep: for each of the 29 rows in `ci/L2-SPLIT-B.json` (whose `funds` column is months "
  "old), determine **what is live on-chain today**. For every row we resolved the protocol's core custody "
  "contracts from the *current* DefiLlama registry/adapter definitions (`registries/uniswapV2.js`, "
  "`uniswapV3.js`, `compound.js`, `sumTokens.js`, `liquity.js`, and `projects/*`), then read live balances "
  "directly (`eth_call` / `eth_getLogs` / `eth_getBalance`) at the latest block of each chain. "
  "Token amounts are valued with DefiLlama `coins.llama.fi` prices (same price source DefiLlama uses for TVL).")
w("")
w("Method per contract class:")
w("")
w("- **AMM V2 factories** — `allPairsLength()` + `allPairs(i)` + `token0/token1/balanceOf` of every pair "
  "(full pair list; capped at 800 + last 200 with a note if a factory is bigger).")
w("- **CL (UniV3/Algebra) factories** — pool-created events via chunked `eth_getLogs` (Etherscan V2 logs as "
  "fallback where a public RPC caps ranges), then `balanceOf(token0/1)` per pool.")
w("- **Compound forks** — `getAllMarkets()` + per-market `underlying()`/`balanceOf`/`totalBorrows`.")
w("- **Vaults / pools / staking** — explicit `balanceOf(token, owner)` sets from the registry definitions; "
  "LP tokens resolved pro-rata against pair reserves.")
w("- **Pendle-style (Splice)** — market-creation logs, then per SY: `assetInfo()`, direct uAsset balance, "
  "and the claim value `totalSupply × exchangeRate`.")
w("")
w("## 2. TL;DR — live vs watchlist")
w("")
w(f"- **{len(funded)} of 29 rows are LIVE-FUNDED** on-chain today: **{fmt(live_total)}** of verified, "
  f"directly-read custody value (excluding rows where DefiLlama overstates; see notes).")
w(f"- **{len(drained)} rows are DRAINED / effectively $0** (contracts exist but hold < $1k).")
w(f"- **{len(unreach)} row UNREACHABLE** — Kleva Farm (adapter data source dead, custody addresses not re-derivable); two chain-level targets (Canto for LeetSwap, SatoshiVM for savmSwap) are dead and excluded from those rows' totals.")
w("- **0 rows ALREADY-COVERED** — no prior report in the corpus covers these 29.")
w("- DefiLlama's *current* TVL is fresh (updated today) for 27/29 rows, but for several rows the number is "
  "**not reproducible on-chain** (carried-forward from failing adapters): most notably **LuigiSwap** "
  "(DL $337k vs live ~$0.6k) and **Pala** (DL $401k vs market-priced live ~$42k; DL uses the protocol's own "
  "internal oracle, which prices Orbit-bridge assets far above market).")
w("")
w("## 3. Per-row results (sorted by live $ desc)")
w("")
w("| # | Protocol | Chain(s) | Status | Conf | Live $ (on-chain) | DefiLlama today | Watchlist (stale) | Key custody contracts (chain: address) | Blocks |")
w("|---|---|---|---|---|---|---|---|---|---|")
plan_by_slug = {p["slug"]: p for p in plan["protocols"]}
def key_addr(t):
    for k in ("factory", "comptroller", "trove_manager", "master", "viewer"):
        if k in t:
            return t[k]
    if t.get("owners"):
        return t["owners"][0]
    if t.get("pairs"):
        return t["pairs"][0][1]
    if t.get("holders"):
        return t["holders"][0]
    if t.get("addresses"):
        return t["addresses"][0]
    return None
for i, r in enumerate(rows, 1):
    st = stale.get(r["name"].lower(), {})
    ev = []
    p = plan_by_slug.get(r["slug"], {})
    for t in p.get("targets", [])[:2]:
        a = key_addr(t)
        if a:
            ev.append(f"{t['chain']}: `{a}`")
    for t in r["targets"][:3]:
        bits = t["label"]
        if t.get("pairs"):
            bits += f" ({t['pairs']} pairs)"
        if t.get("pools"):
            bits += f" ({t['pools']} pools)"
        if t.get("markets"):
            bits += f" ({t['markets']} mkts)"
        ev.append(bits)
    evs = "; ".join(ev)[:210]
    dl = fmt(r["defillama_usd"]) + ("" if r["defillama_fresh"] else " ⚠stale")
    blk = ", ".join(f"{c}:{b}" for c, b in sorted((r.get("blocks") or {}).items()) if b)[:80]
    w(f"| {i} | {r['name']} | {','.join(r['chains'])} | **{r['status']}** | {r.get('confidence','?')} | {fmt(r['onchain_usd'])} | {dl} | "
      f"{st.get('funds','—')} | {evs} | {blk} |")
w("")
w("Notes on classification:")
w("")
w("- `LIVE-FUNDED` = on-chain custody ≥ $1k today (all listed contracts read at the recorded blocks).")
w("- `DRAINED` = contracts exist but hold < $1k of priced assets (or only junk/airdrop tokens).")
w("- `UNREACHABLE` = no working public RPC / indexer for the chain, or no custody contract could be resolved.")
w("- `(partial)` = some chains/targets failed and were skipped (e.g. dead chain in a multi-chain protocol); "
  "the live $ covers the reachable part.")
w("")
w("## 4. Rows where DefiLlama and on-chain disagree (important)")
w("")
w("| Protocol | DefiLlama today | Live on-chain | Explanation |")
w("|---|---|---|---|")
EXPLAIN = {
 "Orbit Protocol": "DL counts deposits (cash + borrows); on-chain **cash** is $93.7k with $519k borrows outstanding. Markets are flagged `isInsolvent` in DL's own registry. Custody = cash.",
 "ReactorFusion": "Same metric gap: DL counts deposits; on-chain cash is $78.8k (zkSync Era) + $0.4k (Telos), with $114k borrowed. Custody = cash.",
 "LeetSwap": "Full pair scans (incl. all 4,498 Base pairs) give $49k; DL per-chain values are ~2x the directly-read balances on opBNB/Manta and not reproducible on Base ($232 live vs DL $76.8k). DL likely stale/double-counting.",
 "Pala": "DL values the pools with the protocol's **internal viewer oracle** (prices at/above par); the market prices of Orbit-bridge assets are far below (oUSDT $0.11, oUSDC $0.30). Market-priced custody = $41.7k; token amounts are recorded in results.json.",
 "LuigiSwap": "Pools hold 0.6 WBNB live (verified with `cast` on the top pair); DL $285k (opBNB) not reproducible — carried-forward from a failing adapter.",
 "SatoshiCoreSwap": "DL timestamp frozen at 2023-10-12; all 19 pairs hold ~$0 (only junk tokens).",
 "Prism DEX": "Shut down 2026-09-09 (DL hallmark); pools empty on-chain.",
 "Kleva Farm": "DL frozen since 2025-03-28; adapter source (`kleva.io/static/data.json`) dead; custody addresses not re-derivable (probe of the one known vault = $0).",
 "Nile CL": "DL includes $206k of the **RUSTY memecoin** (996M tokens) at DL's internal price; our priced-token total excludes it (amounts recorded).",
 "Mobius Money": "DL includes a stale `BTC` entry (~$116k) that is not present on-chain; CUSD/DAI/etc. match exactly.",
 "savmSwap": "DL WPROM amount (45,708) is stale vs on-chain 30,165; USDT matches ($76.4k).",
 "AbstraDEX": "DL WOKB (3,421) is ~2x the directly-read on-chain balance (1,706); same ~2x pattern as LeetSwap opBNB/Manta (DL adapter artefact).",
 "LFGSwap EthereumPoW": "All 1,581 pairs scanned: VVXEN 23.7T tokens ($115k) + USDT/WETHW; DL shows 58.4T VVXEN ($290k) — stale.",
}
disagreements = []
for r in rows:
    dl = r["defillama_usd"]
    oc = r["onchain_usd"]
    if dl > 1.5 * max(oc, 1000) and dl > 20000:
        disagreements.append((r["name"], fmt(dl), fmt(oc), EXPLAIN.get(r["name"], "DL number not reproducible from the on-chain contracts in the current adapter definition")))
for d in disagreements:
    w(f"| {d[0]} | {d[1]} | {d[2]} | {d[3]} |")
if not disagreements:
    w("| — | — | — | — |")
w("")
w("Also note: **Kleva Farm** (DL $784k) and **SatoshiCoreSwap** (DL $349k) have *frozen* DefiLlama "
  "timestamps (2025-03-28 and 2023-10-12) — the watchlist's own `stale` column flags them; on-chain results above "
  "supersede them. Kleva's adapter data source (`kleva.io/static/data.json`) is dead, so its vault addresses "
  "could not be re-derived (marked UNREACHABLE/unknown in the table).")
w("")
w("## 5. Phase-2 shortlist (funded, not covered)")
w("")
w("| Rank | Protocol | Chain(s) | Live $ | One-line reason |")
w("|---|---|---|---|---|")
for i, r in enumerate(funded, 1):
    note = {
        "luigiswap": "",
    }.get(r["slug"], "")
    if r["slug"] == "powercity-flex-protocol":
        note = "Liquity fork with HEX collateral + FLEX farms live on Pulse; custody verified (TroveManager/ActivePool)"
    elif r["slug"] == "ra-exchange":
        note = "largest live CL+stableswap DEX on Fraxtal; all pools still funded"
    elif r["slug"] == "splice-finance":
        note = "Pendle-style PT/SY markets live on Mode+Blast; SY claims verified (supply × exchangeRate)"
    elif r["slug"] == "nile-legacy":
        note = "Linea V2 AMM + staking still funded; cAMM stable pools included"
    elif r["slug"] == "abstradex":
        note = "UniV2 fork with live pools on X Layer (dominant) + Morph/Cronos zkEVM/Zeta"
    elif r["slug"] == "reactorfusion":
        note = "Compound fork on zkSync Era + Telos; cash verified, large borrows outstanding"
    elif r["slug"] == "orbit-protocol":
        note = "Compound fork on Blast flagged insolvent by DefiLlama; cash vs borrows measured"
    else:
        note = "live custody verified on-chain at recorded blocks"
    w(f"| {i} | {r['name']} | {','.join(r['chains'])} | {fmt(r['onchain_usd'])} | {note} |")
w("")
w("## 5b. Evidence detail for the top-10 funded rows")
w("")
for r in funded[:10]:
    w(f"**{r['name']}** — live {fmt(r['onchain_usd'])} at blocks " +
      ", ".join(f"{c} #{b}" for c, b in sorted((r.get('blocks') or {}).items()) if b) + ":")
    for t in r["targets"][:3]:
        tops = t.get("top_assets") or []
        top_s = "; ".join(f"`{a['token'][:12]}`… {a['amount']:,.4g} = {fmt(a['usd'])}" for a in tops)
        extra = ""
        if t.get("pairs"):
            extra = f", {t['pairs']} pairs"
        if t.get("pools"):
            extra = f", {t['pools']} pools"
        if t.get("markets"):
            extra = f", {t['markets']} markets"
        w(f"  - {t['label']} [{t['chain']}]{extra}: {top_s}")
    w("")
w("## 6. Unreachable / dead")
w("")
for r in unreach:
    errs = "; ".join(f"{e['chain']}: {str(e['error'])[:110]}" for e in r["errors"][:3])
    if not errs:
        errs = ("custody addresses could not be re-derived: the adapter's data source "
                "(kleva.io/static/data.json) is dead and the protocol has no public registry entry; "
                "the single probe address held $0. DefiLlama's $784k is frozen since 2025-03-28.")
    w(f"- **{r['name']}** ({','.join(r['chains'])}): {errs}")
w("")
w("Chain-level failures inside otherwise-live rows (excluded from their totals):")
for r in rows:
    for e in r.get("errors", []):
        w(f"- {r['name']} · {e['chain']}: {str(e['error'])[:130]}")
w("")
w("## 7. Methodology, caveats, limitations")
w("")
w("- **Read-only.** No transactions were signed or sent. All data comes from `eth_call`, `eth_getLogs`, "
  "`eth_getBalance`, `eth_getCode` on keyless public RPCs and DefiLlama's public price API.")
w("- **Blocks.** Every chain's latest block at read time is recorded per row in the table and in "
  "`ci-out/results.json` (per-contract detail incl. token amounts and the exact contract address each balance "
  "was read from).")
w("- **Pricing.** USD values use DefiLlama token prices. Obscure tokens without a price contribute $0 "
  "(amounts still recorded). Stablecoin depegs are reflected at market (e.g. Orbit-bridge oUSDT/oUSDC on Kaia).")
w("- **Double counting.** For protocols with staking/farm contracts, LP-token deposits are valued pro-rata at "
  "pair reserves; the per-row total adds staking on top of pool reserves only where the registry reports them "
  "as separate categories (matching DefiLlama's split). Pool reserves themselves are counted once.")
w("- **Coverage.** Custody contracts come from the *current* public adapter/registry definitions. If a team "
  "deployed unlisted contracts (or migrated without updating DefiLlama), those are not counted; "
  "Phase-2 should re-derive from events where material.")
w("- **Not a security assessment.** No exploitability, admin-key or governance analysis was performed here.")
w("")
w("## 8. Files")
w("")
w("- `ci/plan.json` — the exact target set: 29 protocols, 59 targets, per-chain keyless RPCs.")
w("- `ci/enumerate.py` — the enumeration engine (run on GitHub Actions).")
w("- `ci/run.sh` — CI entrypoint; run URL above.")
w("- `ci-out/results.json` — full per-target evidence (contracts, counts, token amounts, USD, blocks, errors).")
w("- `ci-out/summary.csv` — flat per-target CSV.")
w("- `analysis/llama_meta.json` — DefiLlama protocol metadata/current TVL/freshness at screen time.")
w("- `analysis/final_table.json` — classified per-row results used for this README.")
w("- `analysis/report.py`, `analysis/build_readme.py`, `analysis/make_summary.py` — classification/table generators.")
w("- `analysis/merge_deep.py`, `analysis/lfgswap_missing_pairs.json` — deep-pass merge + local top-up of the last 203 LFGSwap pairs.")
w("- `ci-log-full.txt`, `ci-log-deep.txt` — downloaded GitHub Actions logs for both runs.")
w("- `summary.json` — machine-readable summary for the orchestrator.")
w("")

open(os.path.join(ROOT, "README.md"), "w").write("\n".join(out))
print("README.md written:", len("\n".join(out)), "bytes")
