# C2-31 Nolus — capture cost vs proceeds model

Inputs (all live reads 2026-10-09; see `params.md`, raw JSON in `raw/`):

- bonded B0 = 212,518,285.80 NLS; gov quorum q = 33.4%, threshold 50%, veto 33.4%; voting 3 days; unbonding 21 days
- NLS spot P = $0.00364916 (CoinGecko); MEXC mid ~$0.003674
- all-venue 24h volume = $62,403; MEXC ask book = 2.158M NLS total (1.85M within 2× mid); MEXC bids = $1,926
- empirical hostile-proposal opposition (prop 295): NoWithVeto = 162,331,398 NLS

## 1. Capture cost — standard corrections

| Model | NLS needed | USD at spot | Notes |
|---|---|---|---|
| Campaign claim (33.4% × bonded) | 70.98M | $259k | ignores own stake in quorum denominator |
| **Quorum floor (own stake corrected)**: A ≥ B0·q/(1−q) | **106.58M** | **$389k** | attacker votes alone; their stake also raises the denominator |
| Threshold vs 80% turnout No | 170.01M | $620k | Yes > 50% of votes cast |
| **Veto survival vs empirical NWV bloc**: A ≥ 2×162.33M | **324.66M** | **$1,185k** | NWV share must stay ≤ 33.4%; 324.66M = 35% of total supply |
| All validators NWV at 80% turnout | 347.46M | $1,241k | worst realistic case |

Float-depth correction (decisive):

- The entire visible MEXC ask book is **2.158M NLS**; the whole market does **$62.4k/day**.
  Buying 106.6M NLS (floor) = 49× the visible book; at 20% of all daily volume it takes ~31 days,
  at 100% ~6.2 days — while the attacker's own buying pumps the price (market makers replenish higher).
- Stress cases: 3× spot → $1.17M (floor) / $3.6M (veto case); 10× → $3.9M / $11.8M.
- There is no lending/derivative market for NLS (no money-market lists it; the Solana Metis swap tree
  includes NLS for swaps only) ⇒ no leverage/flash-loan path; the attacker must buy spot and bond.

**Conclusion: the "capital-heavy $272k" claim is wrong twice over** — the quorum-only floor is $389k
(not $272k), and any realistic opposed vote requires $0.62M–$1.19M+, before float-depth slippage.

## 2. What a passing proposal can pay

Directly payable (single proposal, no malicious code):

- **Community pool**: 240,000,000.95 NLS (~$875.8k nominal) + **$0.05 dust**. No other module-account pot
  is spendable (fee pool is delegator rewards; staking pools are bookkeeping; vestings/wasm empty).

Reachable only via a malicious-code migration (1-2 proposals; see §4):

- **treasury contract** 152,008,181.07 NLS (~$554.7k nominal) + $2.6 dust
- **LPP vaults** (Solana Metis, carried on Nolus): $97.1k USDC + $14.1k SOL + $6.4k cbBTC + $0.8k WETH
  = **$118.3k** (the only meaningfully liquid pot)
- reserves/leasers/oracles/profits: ~$0.03

Nominal gov-movable total: **$1.55M**; liquid total: **$118.3k**; NLS in pots: **392.0M (42% of supply)**.

Not directly gov-movable: IBC escrow (user funds; only a software upgrade could touch them), Solana-side
open positions (~$228k per DefiLlama 2026-10-04) — only via `remote_lease` migration + relayer
(unverified, low-medium confidence), Osmosis/Neutron ICA positions (markets sunset, ~$0).

## 3. Proceeds realization (the other half of the trap)

- Immediate market sale of the CP's 240M NLS recovers ~**$1.9k** (MEXC bid depth).
- Slow-sale scenarios for 392.0M NLS (42% of supply) into a $62.4k/day market:
  avg $0.0015 → $588k; avg $0.001 → $392k; avg $0.0005 → $196k — all assume the price does not
  collapse further while the overhang is distributed (optimistic).
- The attacker's own purchased stake (106.6M–324.7M NLS) needs the same exit: add 21-day unbonding
  plus months of selling into the same collapsing market.

## 4. Net result

**Capital path** (buy votes on market):

| Scenario | Cost | Liquid proceeds | Net vs liquid only |
|---|---|---|---|
| Quorum floor at spot | $389k | $118k | **−$271k** |
| Empirical veto survival at spot | $1,185k | $118k | **−$1,067k** |
| Floor with 3× slippage | $1,167k | $118k | **−$1,048k** |

Adding optimistic slow-sale NLS proceeds ($196k–$588k nominal) still leaves the floor case at best
around break-even *before* slippage, and the realistic opposed-vote case deeply negative. **The capital
capture is uneconomic.**

**Deception path** (no stake purchase; pass proposals validators approve as routine):

- Step 1: `MsgUpdateParams(wasm)` → open `code_upload_access` (gov authority; verified in chain code).
- attacker stores malicious code implementing `migrate` (drain bank balance via BankMsg::Send) and
  self-reporting the expected release/storage strings;
- Step 2 (or same bundle): `MsgPinCodes` + `MsgSudoContract(Admin, migrate_contracts with explicit code_id)` for
  treasury + LPPs → drains 152.0M NLS + $118.3k.
- Capital cost ≈ 200 NLS deposit (~$0.73) per proposal + social engineering (bundleable). Proceeds: $118.3k liquid +
  NLS nominal $1.43M (slow-sale $200–600k optimistic).
- Constraint: validators must vote Yes on proposals that are visibly non-team. Empirically every
  migration/pin passed 100% Yes (99/100 proposals passed); the single hostile proposal drew 162.3M NWV.
  So success depends on validator diligence — mechanics proven, deception success unprovable here.

**Classification**: E-U $0; the value is governance-only (capture). Capital capture unprofitable
(high confidence). Governance-integrity risk (deception path) is real but bounded by market depth;
worst-case realizable ≈ $0.1–0.6M, not the nominal $1.55M.
