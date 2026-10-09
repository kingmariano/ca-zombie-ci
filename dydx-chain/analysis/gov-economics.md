# C2-34 — Gov economics: capturable funds vs capture cost (dYdX chain)

**Date:** 2026-10-09 · **Read window:** block 108,685,672 (07:00:53Z) → 108,685,774 (07:01:58Z),
endpoint `https://dydx-dao-api.polkachu.com`; prices same morning (~07:00–07:05Z). Raw files in
`analysis/raw/` (manifest.tsv lists every fetch). No transactions; no secrets.

## 1. Governance parameters (live)

| Param | Value | Source |
|---|---|---|
| Quorum | **0.50** | `/cosmos/gov/v1/params/tallying` |
| Threshold | 0.50 | " |
| Veto threshold | 0.334 | " |
| Voting period | 259,200 s (3 d); expedited 129,600 s | `/cosmos/gov/v1/params/voting` |
| Min deposit | 2,000 DYDX (expedited 21,000) | " |
| Quorum raise | prop 392 "Increase Governance Quorum on dYdX Chain" (passed 2026-08-03, "…to 50%") | `/cosmos/gov/v1/proposals/392` |
| Bonded tokens | **285,934,158.72494507 DYDX** (21 bonded validators) | `/cosmos/staking/v1beta1/pool` |
| Not bonded | 32,082,310.20372201 DYDX | " |
| Total supply | 1,000,000,000 DYDX (adydx 18 decimals) | `/cosmos/bank/v1beta1/supply` |
| Unbonding time | 1,814,400 s (**21 days**) | `/cosmos/staking/v1beta1/params` |

## 2. Balances of governance-relevant accounts (block ~108,685,774)

| Account (module) | Address | Holdings | USD @ 2026-10-09 |
|---|---|---|---|
| `community_treasury` | `dydx15ztc7xy42tn2ukkc0qjthkucw9ac63pgp70urn` | 79,763,439.0553226 DYDX + 6,425 uusdc + 0.01/0.07 stDYDX dust | **$10,833,534** (+ ~$0.01) |
| `rewards_treasury` | `dydx16wrau2x4tsg033xfrrdpae6kxfn9kyuerr5jjp` | 32,485,306.82903305 DYDX | **$4,412,180** |
| `insurance_fund` | `dydx1c7ptc87hkd54e3r7zjy92q29xkq7t79w64slrq` | 8,080,668.512695 USDC (no subaccount positions — subaccount 0 empty) | **$8,080,669** |
| `distribution` / community pool | `dydx1jv65s3grqf6v6jl3dp4t6c9t9rk99cd8wx2cfg` | 1,278.72 DYDX + 1,770.63 uusdc + 0.98 stDYDX (community_pool query shows dust) | **~$175** |
| `bridge` (escrow) | `dydx1zlefkpe3g0vvm9a4h0jf9000lmqutlh9jwjnsv` | 41,657,037.68206899 DYDX | $5,657,606 (escrow; see §4) |
| `megavault`, `community_vester`, `rewards_vester`, `fee_collector` | — | 0 | $0 |
| `gov` | `dydx10d07y265gmmuvt4z0w9aw880jnsr700jnmapky` | 2,000 DYDX (min deposits) + 99,860 uusdc | ~$272 |

Prices: DYDX **$0.13582** (DefiLlama `coins.llama.fi`, ts 1791528781) / $0.13544 (CoinGecko);
USDC $0.9996. CoinGecko's market-cap field ($6.59M) is inconsistent with the on-chain 1B supply and
was ignored; 24 h volume **$5,890,360** (~43.5M DYDX/day).

## 3. Which pots can governance actually spend?

dYdX routes gov spending through two gov-only internal messages:

1. **`dydxprotocol.sending.MsgSendFromModuleToAccount`** (internal; `InternalMsgSamplesGovAuth` in
   `protocol/app/msgs/internal_msgs.go`; `IsInternalMsg` in `protocol/lib/ante/internal_msg.go`) —
   sends from a named module account to any bank recipient. The only blocked sender modules are
   `bonded_tokens_pool`, `not_bonded_tokens_pool`, `subaccounts`
   (`protocol/lib/protectedaccounts/protected_accounts.go`). **Precedent:** prop 390 (passed
   2026-07-07, "dYdX Surge Program – Season 15 Distribution") sent 357,142.71 DYDX from
   `sender_module_name: community_treasury` with `authority` = the gov module account.
   → **community_treasury: spendable (proven). rewards_treasury, insurance_fund, bridge: pass the
   same guard (not protected), spendable in principle.**
2. **`cosmos.distribution.v1beta1.MsgCommunityPoolSpend`** (internal) — spends the community pool
   (negligible here).

Caveats: the insurance fund is a protocol-owned bankruptcy backstop and the bridge module holds
user-backed bridge escrow; no precedent exists for gov spending either, so "capturable in principle"
(code path) ≠ "politically passable". This report keeps them separate from the proven
community_treasury path.

## 4. Capture cost vs assets

- **Quorum cost:** 0.50 × 285,934,158.72 = **142,967,079.36 DYDX ≈ $19,417,903** at spot.
- **Liquidity reality:** 142.97M DYDX ≈ **3.29 × 24 h volume**; acquiring it would move the price
  substantially (real cost likely multiples of the spot notional). Voting also requires staking
  (self-delegation), then **21-day unbonding** before exit (plus 3-day vote) — ~24+ days of price risk.
- **Assets reachable if a proposal passed:** community treasury $10.83M + rewards treasury $4.41M +
  insurance fund $8.08M + community pool ~$0.0002M ≈ **$23.33M nominal** (≈ $28.98M if the $5.66M
  bridge escrow were also counted). 87% of the non-USDC part is DYDX: liquidating 112.25M DYDX
  (≈ 2.6 × ADV) would itself crush the price, so realizable value ≪ nominal.
- **Veto/threshold:** attacker voting alone can satisfy quorum and threshold (>50% of votes cast), but
  a 33.4% no-with-veto counter-vote kills the proposal; expedited route needs 75% yes.
- **Verdict: NEGATIVE EV** (cost ≥ $19.4M spot, realistically more, vs ≤ $23.3M nominal and less
  realizable; plus lockup and veto). Confidence: **high** on parameters, **medium** on the slippage
  estimate. This is the same conclusion as the campaign's other gov-capture entries (C2-27…C2-33).

## 5. DoS quantification (this finding's class — kept separate from theft)

- **No theft primitive** in ISA-2025-001 / ASA-2025-004: halt (liveness) only; and the vector is
  patched on dYdX (see `fork-patch-verification.md`).
- Hypothetical halt damage (if unpatched): chain stops → on-chain **70,772,323.76 USDC** (Noble
  channel-0) and all other balances freeze; ~**$38.95M** total perp open interest (dYdX indexer,
  296 markets) cannot be closed/settled; IBC transfers stall. Attacker gain: **$0**.
- Software-upgrade context: prop 395 → v9.7 (height 105,002,000, live); prop 398 → v9.8 (in voting
  at read time: ends 2026-10-11T02:23Z, plan height 109,170,000, yes 161.4M / abstain 15.5M / no 0,
  quorum met; binaries v9.8.0-9ab4e17a — source not yet public). `current_plan = null`.
