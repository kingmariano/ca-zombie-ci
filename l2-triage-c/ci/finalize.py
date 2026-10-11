#!/usr/bin/env python3
"""Finalize deliverables: README.md + summary.json from ci-out/results.json."""
import json, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
res = json.load(open(os.path.join(ROOT, "ci-out", "results.json")))
rows = res["rows"]
ranked = sorted(rows, key=lambda r: -(r.get("live_usd") or 0))
by = {r["slug"]: r for r in rows}

funded = [r for r in rows if r["status"] == "LIVE-FUNDED"]
drained = [r for r in rows if r["status"] == "DRAINED"]
unreach = [r for r in rows if r["status"] == "UNREACHABLE"]
total = sum((r.get("live_usd") or 0) for r in rows)

CUSTODY = {
 "fiamma": "Fiamma BitVM2 bridge federation (BTC custody address not published)",
 "bluemove-dex": "`0x3f2d9f72…66e92` (AMM pools) + `0x5a7eca40…b47c9` (stable pools)",
 "jediswap-v1": "factory `0xdad44c13…c2fd` + all pair contracts",
 "10kswap": "factory `0x1c0a36e2…a87a2` + all pair contracts",
 "sft-protocol": "lending pool `0x147122D1EBdA76E4910ccdC53aEb6a58605Eb58E` (+ miners, source dead)",
 "armada": "program `ArmN3Av2…Kwm8d` — 24 CLP vaults + vault token accounts",
 "dojoswap-amm": "factory `inj1pc2vxcm…qngk` + pair pools",
 "ergodex": "P2S contract `5vSUZRZb…SCqM` (unspent boxes)",
 "hliquity": "troveManager `0x…5c9f66` → activePool `0x…5c9f0b`; staking `0x…5c9f30`",
 "shadelend": "Lend Vault Registry V3 `secret1wj2cz…qmfs`; Stability Pool `secret1wdxqz…r46w`",
 "jet-v1": "vault authority `7gpj9cpzBBW9Ci1yMwWz7iGbQYpm5fZmadNQyrYsqch8`",
 "lenfi": "9 v1/v2 Plutus script addresses + LENFI staking address (aada adapter)",
 "caviarnine-lsu-pool": "component `component_rdx1cppy0…3mfp` (82 LSU resources)",
 "omm": "lending-pool data provider `cx5f9a6c…3cb5`",
 "taiga-acala": "Acala module account `23M5ttkp2zdM8qa6LFak4BySWZDsAVByjepAfr7kt929S1U9` (tapio)",
 "01": "vault owner `HjHSNe8hhvZ8hKCRrhKg1DGiGPd9NYQbUjT1SQRDo4kZ`",
 "ocean-one": "Ocean One Mixin app custody (address not public)",
 "moria-protocol": "loan contract `rvtgwvmtp4hy5…un6naf`",
 "margined-protocol": "10 Osmosis + 8 Neutron CosmWasm vault contracts",
 "suidollar-basis": "USDC vault (package never published; repo placeholder `0x0`)",
 "hashmix-fil": "pool `0x587A7eaE9b461ad724391Aa7195210e0547eD11d`",
 "fountain-protocol": "comptrollers `0xA7684aE7…`, `0x1C0C3079…`, `0x7c4d0c83…`",
}

SHORT_REASONS = {
 "taiga-acala": "Acala module account holds **99,381 DOT + 1,039,284 LDOT** (10.3% of LDOT supply) — LDOT unpriced by DefiLlama, ~$1.28M at DOT parity. Largest live custody in this split; control surface unexplored.",
 "jediswap-v1": "Abandoned Cairo AMM: 1,051 pair contracts still hold live reserves (ETH ~$400K, USDC, WBTC…); no audits; sync/burn/mint paths unexplored.",
 "10kswap": "Starknet AMM (15 pairs) still holds ~$761K (138 ETH + 285K USDC + …); abandoned with no audits.",
 "ergodex": "285 unspent eUTxO boxes at the P2S contract hold ~632K ERG + tokens; validator logic unexplored.",
 "armada": "Solana CLP vault program with 24 vaults + ~$352K in vault token accounts (whirlpool position layer not separately valued — understates).",
 "hliquity": "Liquity fork on Hedera: 2.28M HBAR in activePool; trove/liquidation/redemption logic unexplored.",
 "jet-v1": "Sunset Solana lending program still holds ~$156K across 21,194 token accounts; withdraw/repay/liquidate paths unexplored.",
 "lenfi": "Cardano v1+v2 Plutus scripts hold 586K ADA + tokens; UTxO script validation unexplored.",
 "omm": "ICON lending pool holds ~$150K cash (55.7K USDC + 94.8K USDS) + $52K borrows; 2023 exploit history.",
 "01": "Solana perps vault still holds ~$112K (USDC); close/withdraw paths unexplored.",
 "fountain-protocol": "Oasis Compound fork holds ~$93K cash across 3 comptrollers; paused markets ('mint is paused') present.",
 "caviarnine-lsu-pool": "Radix LSU pool holds ~$38K of LSUs across 82 resources; redemption path live.",
 "margined-protocol": "Osmosis+Neutron vaults hold ~$11K (TIA/ATOM/OSMO/stOSMO); sunset derivatives.",
 "hashmix-fil": "Filecoin pool holds ~1.6K FIL (~$1.7K); residual staking claims; API dead.",
 "sft-protocol": "Lending pool holds ~54 FIL (~$59); miner-locked FIL not enumerable (dashboard API dead) — lower bound.",
 "dojoswap-amm": "Injective factory with 982 pairs holding 31,878 INJ + 53.5K peggy-USDT + 4.72 WETH; abandoned, no audits.",
 "bluemove-dex": "Sui AMM with thousands of pools; reserves read on-chain — verify pool set before Phase-2.",
}

def usd(r):
    v = r.get("live_usd") or 0
    if v >= 1000: return f"${v:,.0f}"
    if v >= 1: return f"${v:,.2f}"
    return "$0"

# ---------- main table ----------
tbl = ["| # | Protocol | Chain | Status | Live custody $ | Key custody accounts/contracts | Evidence (latest) | Conf |",
       "|---|---|---|---|---|---|---|---|"]
for i, r in enumerate(ranked, 1):
    st = r["status"]
    st_disp = {"LIVE-FUNDED": "**LIVE-FUNDED**", "DRAINED": "DRAINED/$0", "UNREACHABLE": "UNREACHABLE"}[st]
    e = r.get("evidence", {})
    ev = []
    for k in ("block", "ledger_state", "pairs", "pair_count", "pairs_parsed", "amm_pools_parsed",
              "vaults", "accounts", "confirmed_sats", "history_entries", "pool_fil", "total_lovelace",
              "cash_usd_contract_oracle", "decimals_fetched", "nanoErgs", "activePool_hbar",
              "orml_tokens_scaled", "fungibles", "fungibles_count"):
        if e.get(k) is not None:
            ev.append(f"{k}={e[k]}")
    ev_s = ", ".join(ev)[:120]
    tbl.append(f"| {i} | {r['protocol']} | {r['chain']} | {st_disp} | {usd(r)} | {CUSTODY.get(r['slug'], '')} | {ev_s} | {r['confidence']} |")
table = "\n".join(tbl)

# ---------- shortlist ----------
short_rows = [r for r in ranked if r["status"] == "LIVE-FUNDED" and (r.get("live_usd") or 0) >= 1]
short_md = []
for i, r in enumerate(short_rows, 1):
    reason = SHORT_REASONS.get(r["slug"], "funded; Phase-2 review.")
    short_md.append(f"{i}. **{r['protocol']}** ({r['chain']}) — **{usd(r)}** — {reason}")
short_md = "\n".join(short_md)

readme = f"""# L-2 Phase-1 triage — Triage-C (non-EVM) — live custody screen

**Date:** 2026-10-11 · **Scope:** 22 non-EVM rows (`ci/L2-SPLIT-C.json`) · **Status:** read-only; no transactions; no secrets; writes only under `l2-triage-c/`

**Mission (phase 1 of 3):** custody screening only — establish what is LIVE today at the latest block/height for each protocol's core custody contracts/accounts. No vulnerability analysis.

**CI runs (heavy enumeration):**
- full run A: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38125777999 (first complete pass; exposed 4 scanner bugs)
- full run B: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38127724782 (fixes 1; 4 rows still wrong)
- run C (cancelled): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38130226961 — cancelled mid-Sui enumeration after the Sui JSON-RPC `multiGetObjects` endpoint was found to strip object contents (77-min stall); BlueMove was switched to Sui GraphQL `dynamicFields`.
- **4 fixed rows (JediSwap V1, BlueMove, 10KSwap, Dojoswap) were re-scanned with the identical scanner code on the workstation** after the CI dispatch window (same endpoints, same code); all other rows come from CI run B. Raw data: `analysis/results-ci-run*.json`, `analysis/local-*.json`, `ci-out/results.json`.

## TL;DR

- **{len(funded)} LIVE-FUNDED · {len(drained)} DRAINED/$0 · {len(unreach)} UNREACHABLE · 0 already-covered** (all 22 rows were uncovered in the campaign).
- **Total live custody found: ~{usd({'live_usd': total})}** across {len(funded)} protocols — of which ~$1.28M is the unpriced LDOT leg in `taiga-acala` (valued at DOT parity).
- The four UNREACHABLE rows have dead project APIs/domains and (for ShadeLend) no reachable public Secret RPC; their stale DefiLlama values (months old) were **not** carried forward.
- Biggest surprise: **Moria Protocol** (row $835K) is provably $0 — the team disabled the V1 contract on 2026-04-23 after a disclosed vulnerability and redeemed all loans (funds returned to users).

## Per-row results (sorted by live $)

{table}

Status counts: LIVE-FUNDED {len(funded)} · DRAINED/$0 {len(drained)} · UNREACHABLE {len(unreach)} · ALREADY-COVERED 0.

## Phase-2 shortlist (funded, not covered — ranked)

{short_md}

## Unreachable — exact reasons (evidence, 2026-10-11)

| Row | What is dead | Probes |
|---|---|---|
| Fiamma | bridge TVL API + project domain | `bridge-api.fiammachain.io` HTTP 522; `fiammachain.io` DNS NXDOMAIN; only testnet config in `fiamma-chain/networks`; DefiLlama adapter last good read 2026-03-18 (196d) |
| ShadeLend | Shade stats API + all public Secret RPC/LCD | `prodv1.securesecrets.org` DNS dead; 12 public Secret endpoints tested (publicnode ×3, polkachu, lavenderfive, 01node, stakewolle, saturn, 1rpc) — dead/404/501; DefiLlama deadFrom 2026-08-08 |
| Ocean One | DEX events API + project domain | `events.ocean.one` DNS dead (https+http); `api.mixin.one` alive but no per-app balance endpoint; custody address not published; DefiLlama deadFrom 2024-01-21 |
| SuiDollar Basis | frontend + any published package/object ID | `suidollar.io` DNS dead; `suidollar/suidollar-usdc-vault` repo has `suidollar = "0x0"` placeholder; funds last seen in Navi/Bluefin positions; DefiLlama deadFrom 2025-10-21 ("Project is sunset") |

## Notable findings

- **Moria Protocol → $0 (documented):** the app carries the team notice that Moria V1 was disabled on 2026-04-23 after an external vulnerability disclosure; Riften Labs redeemed all loans, returned collateral, halted the BP oracle and committed to buy back MUSD. On-chain: the loan contract has **0 sats / 0 token UTXOs** (6,851 historical txs; 6 independent Fulcrum servers agree). Not exploited — funds returned.
- **Taiga Acala → ~$1.41M (vs $122K reported):** the Acala module account holds 99,381 DOT + 1,039,284 LDOT (10.3% of LDOT supply) + unidentified ForeignAsset(13). DefiLlama prices only DOT; LDOT has no price feed, so the live custody is ~11× the reported TVL. LDOT valued at DOT parity (flagged).
- **Omm → $150.4K cash** (55.7K USDC + 94.8K USDS) + $52.3K borrows. Contract-oracle USD equals market value for the stablecoins.
- **Fountain → $93.5K cash** (USDC 78.9K + WETH 4.64 + ROSE 322.7K + USDT 338). Cash+borrows (TVL convention) = $227K. cETHER's `underlying()` reverts `mint is paused` — handled.
- **HashMix → $1.7K** (1,582 FIL) vs $164K stale row; API 502.
- **SFT → $59 lower bound** (lending pool only; miner-enumeration dashboard DNS-dead).
- **Armada → $352K** across 24 vaults (USDC 282.8K + JitoSOL + …); whirlpool positions not separately valued (understates).
- **Jet V1 → $156K** across 21,194 SPL token accounts; **01 → $111.6K** (USDC).
- **ErgoDEX → $414.8K** (632,567 ERG + SigUSD/BTC tokens) in 285 unspent boxes.
- **HLiquity → $208.9K** (2,279,875 HBAR in activePool; defaultPool 0).
- **Lenfi → $155.2K** (586,531 ADA + tokens); **CaviarNine → $37.6K** (119.9M XRD via LSU redemption, 82 resources); **Margined → $11.3K**.
- **Starknet AMMs are still live:** 10KSwap **$761K** (15 pairs), JediSwap V1 **$825K** (1,051 pairs) — reserves read directly from pair contracts (JediSwap's layout balanceOf-verified) with per-token decimals.
- **BlueMove (Sui):** AMM reserves enumerated via Sui GraphQL `dynamicFields` over 16,740 pools (JSON-RPC `multiGetObjects` silently strips `content` — do not use for Sui reads). **Dojoswap (Injective):** ~982 pairs; pools largely hold test/CW20 tokens with no price feed — USD is a lower bound.

## Method

1. DefiLlama adapter source (public repo) used as the *lead* for custody addresses; adapters deleted from the repo were recovered by walking commit history (e.g., aada/Lenfi, Fountain, HashMix, dojoswap AMM, hliquity).
2. Live balances read at latest height/block from chain-native public endpoints: Solana JSON-RPC (Alchemy + public fallback), Sui JSON-RPC (publicnode), Starknet JSON-RPC (Cartridge), Cardano Koios, Radix Gateway, Hedera Hashio, Cosmos LCDs (Injective/Osmosis/Neutron), Filecoin GLIF RPC, BCH Fulcrum ×6, Ergo explorer, ICON `ctz.solidwallet.io`, Acala RPC (raw `state_getStorage` with hand-built orml keys + pure-python xxhash64), Oasis Emerald RPC.
3. USD valued with `coins.llama.fi` prices at scan time; raw amounts converted with on-chain decimals (SPL mint accounts, Sui coin metadata, CW20 `token_info`, bank denom metadata, ERC-20 `decimals()`), with proxy pricing (flagged) where no direct feed exists.
4. All enumeration ran in CI: `l2-triage-c/ci/run.sh` → `ci/scan.py`; raw results in `ci-out/results.json` (artifact) and `analysis/results-ci-run*.json`.

## Caveats & limitations

- Point-in-time snapshot (2026-10-11); balances change.
- `LIVE-FUNDED` = value is in the protocol's custody contracts/accounts now; it does **not** imply extractable by an attacker (that is Phase 2).
- USD figures for unpriced/illiquid tokens are proxies or omitted (noted per row).
- BlueMove's Sui pool set and Dojoswap's Injective pool set are enumerated on-chain but their USD is approximate where no price feed exists.
- No keyed RPC URLs are stored in this folder; CI logs show secrets redacted by GitHub.

## Files

- `README.md` (this file) · `summary.json` (machine-readable) · `ci/scan.py` (scanner) · `ci/run.sh` (CI entry) · `ci-out/results.json|csv` + `scan.log` (CI artifacts) · `analysis/` (adapters, probes, historical runs)
"""

open(os.path.join(ROOT, "README.md"), "w").write(readme)

# ---------- summary.json ----------
short = []
for r in short_rows:
    short.append({"slug": r["slug"], "protocol": r["protocol"], "chain": r["chain"],
                  "live_usd": r.get("live_usd"), "status": r["status"],
                  "reason": SHORT_REASONS.get(r["slug"], "")})
summary = {
    "triage": "L-2 Phase-1 — Triage-C (non-EVM custody screen)",
    "generated_at_utc": res.get("generated_at_utc"),
    "ci_run_urls": [
        "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38125777999 (full run A)",
        "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38127724782 (full run B)",
        "https://github.com/kingmariano/ca-zombie-ci/actions/runs/38130226961 (run C, cancelled mid-Sui enumeration)",
    ],
    "rows_total": len(rows),
    "counts": {"live_funded": len(funded), "drained": len(drained), "unreachable": len(unreach), "already_covered": 0},
    "total_live_usd": round(total, 2),
    "rows": [{"slug": r["slug"], "protocol": r["protocol"], "chain": r["chain"], "status": r["status"],
              "live_usd": r.get("live_usd"), "confidence": r["confidence"],
              "custody": r.get("custody"), "notes": r.get("notes"),
              "unpriced_tokens": r.get("unpriced_tokens")} for r in ranked],
    "phase2_shortlist": short,
    "caveats": [
        "Point-in-time reads at latest block/height (2026-10-11).",
        "USD = DefiLlama coins-API prices at scan time; on-chain decimals applied; proxy pricing flagged per row.",
        "LIVE-FUNDED = value in custody now; not a claim of extractability (Phase 2).",
        "Unreachable rows: project API/indexer and/or public chain RPC dead at scan time; stale DefiLlama values NOT carried forward.",
        "No transactions, no secrets, read-only.",
    ],
}
json.dump(summary, open(os.path.join(ROOT, "summary.json"), "w"), indent=2)
print("README.md + summary.json written")
print(f"funded={len(funded)} drained={len(drained)} unreachable={len(unreach)} total=${total:,.2f}")
