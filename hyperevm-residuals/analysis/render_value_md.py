#!/usr/bin/env python3
"""Render nest_value.md from nest_value.json + raw data. No RPC."""
import json
from collections import defaultdict

BASE = "/home/heisenberg/CA/hyperevm-residuals/analysis"
d = json.load(open(f"{BASE}/nest_value.json"))
raw = json.load(open(f"{BASE}/nest_value_raw.json"))
pools_api = json.load(open(f"{BASE}/nest_pools_api.json"))
llama = json.load(open(f"{BASE}/llama_latest.json"))
h = d["headline"]
c = d["categories"]

# V3-only per-token (for llama comparison)
_META = {k.lower(): v for k, v in raw["token_meta"].items()}
def dec(t):
    return (_META.get(t.lower(), {}).get("decimals")) or 18
addr2sym = {}
for s, v in d["per_token_totals"].items():
    if v.get("address"):
        addr2sym[v["address"].lower()] = s
v3 = defaultdict(float)
allv = defaultdict(float)
for r in raw["pool_rows"]:
    for k, tk in (("bal0", "token0"), ("bal1", "token1")):
        if r[tk]:
            s = addr2sym.get(r[tk].lower())
            if not s:
                continue
            amt = (r[k] or 0) / 10 ** dec(r[tk])
            allv[s] += amt
            if r["type"] == "V3":
                v3[s] += amt

def usd(x):
    return f"${x:,.2f}"

L = []
A = L.append
A("# Nest protocol on HyperEVM — exact live value held at block 47620218")
A("")
A("**Date:** 2026-10-04 · **Chain:** HyperEVM (chainid 999) · **Block:** 47620218 "
  "(2026-10-04T06:42:44Z) · **Method:** read-only `eth_call`/`eth_getBalance` at that exact block; "
  "no transactions, no signatures.")
A("")
A("This is the live-state measurement input for the H-32 headline. Every number below is an on-chain balance read; "
  "prices are DefiLlama (`coins.llama.fi/prices/current/hyperliquid:0x…`, timestamp recorded), with Nest app-snapshot "
  "prices as a labelled fallback where DefiLlama has no entry. Raw reads: `analysis/nest_value_raw.json`, "
  "`analysis/nest_value_stage3.json`, `analysis/nest_native.json`; computed totals: `analysis/nest_value.json`.")
A("")
A("## 1. Headline")
A("")
A("| # | Item | Amount | USD | Where it sits |")
A("|---|---|---|---|---|")
A(f"| **X** | **Pool token balances** (69 V3 + 3 V2) | — | **{usd(h['pool_token_balances_usd'])}** | `balanceOf(pool)` for token0/token1 of every pool |")
A(f"| | ↳ V3 pools | | {usd(c['pools']['v3_usd'])} | 69 Algebra-style CL pools |")
A(f"| | ↳ V2 pairs | | {usd(c['pools']['v2_usd'])} | 3 Solidly-style pairs |")
A(f"| | Fee vaults (collected protocol fees, 72) | — | {usd(h['fee_vaults_usd'])} | per-pool `FeesVault` contracts |")
A(f"| | Gauge token dust (NEST sitting in gauges) | — | {usd(c['gauges']['gauge_token_dust_usd'])} | gauge 0xd61e… only |")
A(f"| | Protocol NEST dust (Voter) | — | {usd(c['other']['voter_nest_usd'])} | `<2.96e-8 NEST` |")
A(f"| | Algebra community vault + factory | — | {usd(c['algebra_vault']['usd'])} | zero on all 43 measured tokens |")
A(f"| | **Subtotal, protocol-held excl. veNEST** | | **{usd(h['protocol_hold_usd_excl_venest'])}** | |")
A(f"| **Y** | **veNEST locked NEST** (separate asset class) | 1,626,144,414.87 NEST | **{usd(h['veNEST_locked_nest_usd'])}** | veNEST voting escrow 0x2f2A… |")
A(f"| | **Total measured (X + fees + Y, no double count)** | | **{usd(h['total_measured_usd'])}** | |")
A("")
A("**Informational, explicitly NOT added (claims / third-party):**")
A(f"- Gauge-staked LP: `0xd61e0416…` holds **99.5417%** of the NEST/WHYPE V2 pair LP "
  f"(147,862.758 / 148,543.483 LP). Underlying claim ≈ **{usd(d['gauge_lp_staked']['claim_usd'])}** — already inside X (pool balances); "
  "LP is a claim on those tokens, not a second asset.")
A(f"- Third-party Ichi/Steer vaults: idle token balances ≈ **{usd(d['third_party_vaults']['usd'])}** at 35 vault addresses "
  "(user funds, third-party managed; excluded from protocol totals). Their in-pool positions are counted in X.")
A("")
A("## 2. Cross-check against DefiLlama “nest CL”")
A("")
A(f"- DefiLlama protocol snapshot (`llama-nest-cl.json`, `tokens`/`tokensInUsd` latest entry, **2026-10-04T03:19:23Z**): "
  f"**{usd(d['validation']['llama_total_usd'])}** (sum of 29 priced tokens).")
A(f"- On-chain at 06:42:44Z: V3-only **{usd(c['pools']['v3_usd'])}** (+0.32% vs llama, consistent within 3.4h of trading/price drift) "
  f"and all pools incl. V2 **{usd(h['pool_token_balances_usd'])}**.")
A("- The DefiLlama composition config appears to track **CL/V3 pools only**: its NEST amount 41,717,552 vs our V3-only "
  "41,716,768 (0.002% apart) while the full on-chain NEST count is 52,376,755 — the 10,659,987 difference is the "
  "NEST/WHYPE V2 pair, which llama omits.")
A("")
A("| Token | llama snapshot | on-chain V3-only | on-chain all pools | comment |")
A("|---|---|---|---|---|")
for s in ["WHYPE", "USDC", "NEST", "KHYPE", "UBTC", "UETH", "USDT0", "KNTQ"]:
    la = llama["tokens"].get(s.upper() if s.upper() in llama["tokens"] else s)
    if s == "NEST":
        cmt = "llama = V3 only (excl. V2 NEST)"
    elif s in ("KHYPE", "KNTQ"):
        cmt = "indexer composition difference (see §11)"
    else:
        cmt = "snapshot lag / active-pool drift"
    A(f"| {s} | {la if la is not None else '—'} | {v3[s]:,.4f} | {allv[s]:,.4f} | {cmt} |")
A("")
A("Where the two token amounts can be compared directly, the app-API's own per-pool `tvl0`/`tvl1` fields (same pool set) match our "
  "on-chain reads closely (worst individual-token drift ±22% on the busiest pool `0xbe512f58…`, USDC/WHYPE, while its USD value moved only "
  "+8.1% over the 3.4h window). The remaining per-token differences vs llama (KHYPE −5.0%, KNTQ +2.0%, sKNTQ −20%) are indexer composition "
  "differences: llama’s per-token split is not reproducible from the app API's own snapshot fields, but the aggregate totals agree to +0.3%. "
  "Our block-pinned on-chain reads are the authoritative measure.")
A("")
A("On-chain registration check: `Voter.poolsCounts()` returns `(55, 1, 54)` (total registered 55 = 1 V2 + 54 V3) and `v3Pools`/`v2Pools` "
  "enumeration yields exactly the 55 gauged pools. The other 17 app-API pools are factory pools not yet registered with the Voter (no gauge); "
  "they were still measured. No on-chain pool was found outside the 72-pool app list.")
A("## 3. Per-token composition of pool balances (plus fees / gauge dust)")
A("")
A("Rows sorted by pool USD. `pools` = `balanceOf(pool)` sums; `fee vaults` = collected protocol fees; "
  "`gauge dust` = NEST tokens parked in gauges. veNEST locked NEST is a separate line at the bottom.")
A("")
A("| Token | Price USD | Source | Pools amount | Pools USD | Fee vaults USD | Gauge dust USD |")
A("|---|---|---|---|---|---|---|")
for s, v in sorted(d["per_token_totals"].items(), key=lambda x: -x[1]["pools_usd"]):
    pcat = v["by_category"].get("pools", {})
    fcat = v["by_category"].get("fee_vaults", {})
    gcat = v["by_category"].get("gauge_dust", {})
    if not (pcat.get("usd", 0) or fcat.get("usd", 0) or gcat.get("usd", 0)):
        continue
    A(f"| {s} | {v['price_usd']:.10g} | {v['price_source']} | {pcat.get('amount',0):,.6f} | "
      f"{usd(pcat.get('usd',0))} | {usd(fcat.get('usd',0))} | {usd(gcat.get('usd',0))} |")
A(f"| *veNEST locked NEST* | {d['per_token_totals']['NEST']['price_usd']:.10g} | defillama | 1,626,144,414.87 | "
  f"{usd(h['veNEST_locked_nest_usd'])} | — | — |")
A("")
A("## 4. Largest pools (top 15 by on-chain USD)")
A("")
A("| Pool | Type | USD (on-chain) | API tvlUSD (snapshot) |")
A("|---|---|---|---|")
for r in sorted(d["per_contract"], key=lambda x: -(x.get("usd") or 0))[:15]:
    if r.get("label", "").startswith("Nest"):
        A(f"| `{r['address']}` | {r['type']} | {usd(r['usd'])} | {usd(r.get('tvlUSD_api',0))} |")
A("")
A("Per-pool on-chain vs API differences on the biggest pools are ≤~8% and are fully explained by the ~3.4h gap between the "
  "API snapshot and the measurement block (on-chain balances of active pools move with swaps): e.g. pool `0xbe512f58…` "
  "WHYPE −6.1% / USDC +22.1% vs its API capture, while the pool's USD value moved only +8.1%.")
A("")
A("## 5. veNEST (locked NEST) detail")
A("")
A("| Field | Value | Call |")
A("|---|---|---|")
A(f"| veNEST proxy | `0x2f2Ae07e3cc3391A2E27825652BA8DcdD5412074` | |")
A(f"| `supply()` (locked NEST) | 1,626,144,414.8657568 NEST | `0x047fc9aa` |")
A(f"| `NEST.balanceOf(veNEST)` | 1,626,144,414.8657568 NEST | `0x70a08231` — **identical to supply()** |")
A(f"| `permanentTotalSupply()` | 1,464,448,156.8128357 NEST | `0x94340b05` |")
A(f"| `votingPowerTotalSupply()` | 1,547,824,024.927683 | `0xe1ba0c00` |")
A(f"| veNFT count (`totalSupply()`) | 4,043 | `0x18160ddd` |")
A(f"| NEST `totalSupply()` | 1,888,234,281.4212382 | `0x18160ddd` |")
A(f"| Locked share of supply | 86.1198% | |")
A(f"| NEST price used | $0.0171249656 (DefiLlama ts 1791094910, confidence 0.99) | |")
A("")
A("Consistency checks: NEST balances of other protocol contracts at the same block — Minter `0`; veNEST implementation `0`; "
  "`0x6652173b0cb3d96d8f0198bc49670440dec69e79` `0`; Voter `0.00000002958` NEST. NEST held by pools (52,376,755) and by veNEST "
  "(1,626,144,415) are disjoint holdings of the same token (no overlap).")
A("")
A("Independent spot cross-check: the NEST/WHYPE V2 pair held 10,663,986.69 NEST + 2,069.13 WHYPE at the block → implied "
  "NEST = 2,069.13 × $89.8495 / 10,663,986.69 = **$0.017435**, within 1.8% of the DefiLlama price.")
A("")
A("## 6. Fee vaults (collected protocol fees)")
A("")
A(f"- **{c['fee_vaults']['n_vaults']}** FeesVault contracts, exactly one per pool, all discovered via "
  "`FeesVaultFactory.getVaultForPool(pool)` (`0x705C76e29977Ed52cd93d390A7BBcC61189724C0`); each vault's `pool()` was read back and matched; "
  "every gauge's `feeVault()` equals its pool's factory vault — **0 mismatches**.")
A(f"- Total held: **{usd(c['fee_vaults']['usd'])}** in token0/token1 (already-collected protocol fees; tokens sit in the vault, outside the pool → additive).")
A("")
A("| Vault | Pool | USD |")
A("|---|---|---|")
vrows = sorted([r for r in d["per_contract"] if r.get("label", "").startswith("FeesVault") and (r.get("usd") or 0) > 1],
               key=lambda r: -(r.get("usd") or 0))[:10]
for r in vrows:
    A(f"| `{r['address']}` | `{r.get('pool','')}` | {usd(r['usd'])} |")
A("")
A("## 7. Gauges — staked LP accounting (informational; not added)")
A("")
A("- 55 gauges from the API; `Voter.poolToGauge(pool)` (proxy `0x566bdc54…`) returns exactly those 55 addresses — **0 mismatches**.")
A("- **54 of 55 gauges have `totalSupply() == 0`** (no LP staked); their token0/token1 balances are also 0 and the gauge `TOKEN()` is the "
  "pool itself (a non-ERC20 for V3), so there is no gauge-level value to add for V3.")
A("- The only non-empty gauge is `0xd61e0416a3ce369fb1c328ecb84dfe8cea168219` (NEST/WHYPE **V2** pair `0x9aa281b2…`): "
  "`totalSupply() = 147,862.75806538455` LP vs pair `totalSupply() = 148,543.48257966977` LP → **99.5417% staked**. "
  "The staked LP is a claim on the pair's token balances already counted in X (claim value ≈ "
  f"{usd(d['gauge_lp_staked']['claim_usd'])}); it is **not** added.")
A("- The same gauge additionally holds **631,463.798 NEST** (non-LP tokens, $10,813.80) — counted under “other”.")
A("")
A("## 8. Algebra community vault / factory")
A("")
A(f"- `AlgebraCommunityVault 0x15E408A37cE4D13218202C0054B0f485E38F5768` and `AlgebraFactory 0xF77Bd082c627aA54591cF2f2EaA811fd1AB3b1F3`: "
  f"**zero balance for all 43 measured tokens**, and zero native HYPE. Nothing to add (${c['algebra_vault']['usd']:.2f}).")
A("")
A("## 9. Third-party Ichi/Steer vaults (excluded from protocol totals)")
A("")
A("35 vault addresses are advertised in the Nest app pools API (Ichi/Steer automated LP managers). Their **idle** token balances at the "
  f"block total **{usd(d['third_party_vaults']['usd'])}** (mostly WHYPE 3,100.65 = $278,591.74; KHYPE 126.91 = $11,711.81; "
  "USDT0 6,673.16 = $6,672.20; USDC 19.11; NEST 95.58 with the HYPE-composition rest). These are third-party/user funds and are not "
  "protocol-owned. Tokens those vaults have deposited into pools are inside X; only the idle portion above sits at vault addresses.")
A("")
A("## 10. Method, completeness checks, no-double-count proof")
A("")
A("1. **One explicit block** `47620218` (ts 2026-10-04T06:42:44Z) pinned for every read in stages 2–4.")
A("2. **Pools:** all 72 IDs from the authoritative app API. On-chain check: 72/72 have code; on-chain `token0()`/`token1()` match the API "
  "72/72; `balanceOf(pool)` read for both tokens (144 balanceOf calls + 144 token0/token1 calls).")
A("3. **Gauges:** `poolToGauge` for all 72 pools; 55 gauges; `TOKEN()`, `totalSupply()`, `feeVault()` read for each; token balances read for both pool "
  "tokens; LP `balanceOf(gauge)` read for the V2 pair.")
A("4. **Fee vaults:** `getVaultForPool` for all 72 pools (72 distinct vaults); `pool()` verified; token0/token1 balances read.")
A("5. **veNEST:** `supply`/`totalSupply`/`permanentTotalSupply`/`votingPowerTotalSupply` + `NEST.balanceOf` for veNEST proxy/impl/Minter/Voter/"
  "0x6652…/Algebra vaults + NEST totalSupply.")
A("6. **Algebra vault/factory** balances for all 43 measured tokens + native balances of 72 pools/55 gauges/72 vaults/core contracts "
  "(all zero native HYPE).")
A("")
A("**No double counting:** the headline adds only balances held at **disjoint addresses**: pool contracts (X) + fee-vault contracts + gauge NEST dust + "
  "Voter dust + Algebra vault. Gauge-held LP is *by construction* excluded and reported as a claim, because the LP represents the pool tokens already "
  "inside X. veNEST locked NEST is held by the veNEST contract and is reported as a separate asset class Y. The per-token table's “total” column never "
  "sums into the headline.")
A("")
A("## 11. Caveats and gaps")
A("")
A("- **Prices:** 29 of 43 tokens priced by DefiLlama at block time (timestamps in `nest_value.json.price_timestamps`); the other 14 use the Nest app "
  "snapshot's own `priceUSD` (source labelled `nest_api_snapshot`, no timestamp). The fallback-priced tokens are small: the largest are QONE "
  "($46,904), ALT ($6,778), CAT ($3,141), ONEAR ($1,915), SIGNAL ($1,587), EGG ($458), USDV ($244,885 — main one: a stablecoin, plausible), "
  "bbHLP ($129), PERPME ($3); rest ≈ $0. If the fallback prices are wrong by 2×, the pool total error is ≤ ~$0.3M (~1.1%).")
A("- **Two non-standard token addresses** appear in two $0-TVL API pools: `0x9d0e8f5b25384c7310cb8c6ae32c8fbeb645d083` has **no code** "
  "(not a contract; `balanceOf` returns empty → 0) and `0x78cc152a531dbde2f3fe7001ad659fa120fa893b` has code but `decimals()`/`totalSupply()` "
  "revert (balance read as 0). Both pools show API TVL $0, so no value is omitted.")
A("- **Timing:** the API/llama snapshots are ~3.4h older than the block; per-pool token amounts differ where pools traded (documented in §4). "
  "The on-chain numbers are the exact state at the block; they drift continuously with swaps.")
A("- **NEST price** is the dominant sensitivity for Y: at $0.017125 the 1.626B locked NEST is $27.85M; at $0.010 it would be $16.26M, at $0.020 "
  "$32.52M. The V2 spot cross-check ($0.017435) agrees within 2%.")
A("- **veNEST locked NEST is user-owned**, withdrawable per lock schedule (permanent locks: 1.464B NEST). It is not protocol-owned value; "
  "it is reported as a separate headline item per the task instruction (“plus separately veNEST locked NEST = Y”).")
A("- **Pool balances include uncollected LP fees** (normal AMM TVL convention). Fee vaults hold only the portion already swept to the protocol.")
A("- **Enumeration scope:** fee vaults were enumerated per-pool via the factory getter (72/72); no orphan vaults were searched via logs. "
  "On-chain pool enumeration via the Voter only lists gauged pools (`poolsCounts() = (55, 1, 54)`; 54 V3 + 1 V2 registered), and no pool "
  "outside the 72-pool app API was found. Pools/gauges/vaults derive from the authoritative app API + on-chain cross-checks above.")
A("- **DefiLlama per-token composition** could not be reproduced exactly from the app-API snapshot fields (e.g. llama KHYPE 25,702.57 vs "
  "24,411.45 on-chain; sKNTQ 21,213 vs 26,471). Aggregate totals match (+0.3% on V3-only). All headline numbers here come from direct "
  "on-chain reads, not from llama.")
A("")
A("## 12. Files")
A("")
A("| File | Content |")
A("|---|---|")
A("| `analysis/nest_value.json` | machine-readable result: block, per_contract, per_token_totals, categories, headline, validation, prices |")
A("| `analysis/nest_value_raw.json` | stage 2 raw reads (pool/gauge/vault/core/algebra/tp/meta) |")
A("| `analysis/nest_value_stage3.json` | fee-vault balances, gauge token/LP balances, weird-token probes |")
A("| `analysis/nest_native.json` | native HYPE balances (all zero) |")
A("| `analysis/nest_prices.json` | raw DefiLlama price response (29 coins) |")
A("| `analysis/llama_latest.json` | llama snapshot latest composition |")
A("| `analysis/nest_probe1.py`, `nest_measure.py`, `nest_stage3.py`, `nest_stage4.py`, `nest_compute.py` | reproducible read + compute scripts |")
A("| `analysis/abis_src.json`, `abis_impls.json`, `abi_*.json` | Etherscan V2 ABIs used |")
A("")
open(f"{BASE}/nest_value.md", "w").write("\n".join(L) + "\n")
print("wrote nest_value.md", len("\n".join(L)), "chars")
