# C2-29 — LikeCoin (likecoin-mainnet-2) governance capture: cost vs proceeds, live

**Date:** 2026-10-09 · **Chain:** likecoin-mainnet-2 (Cosmos SDK **v0.46.16** via the `likecoin/cosmos-sdk v0.46.16-dual-prefix` fork, ibc-go v6.3.0, CometBFT v0.34.29, app `LikeApp v4.2.0`)
**Status:** read-only research; **no transactions signed or sent**; no fork PoC possible for Cosmos gov — the path is verified by live LCD state + exact-version source analysis + a reproducible CI evidence run.
**Corpus claim under test:** *C2-29 · LikeCoin | capture cost "> CP", CP $135k | uneconomic.*

---

## TL;DR

| Target | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| Community pool (`x/distribution`, 79,981,046.28 LIKE) | **≈ $2.58k realizable** (CI runs: $2,577–$2,587; nominal $118.1k at the v3 LIKE price; corpus's $135k used ≈$0.001688/LIKE) | **Capture (open, social-gated):** a 100,000-LIKE min deposit (~$111 to acquire on Osmosis; refunded on pass/reject, burned only on veto) + a 7-day vote. The **3 bonded validators** (Civic Liker 212.4M, Oldcat 203.6M, Yasu 196.2M) hold 100% of the 612.24M bonded power and are the entire gate | The CP is the last v2 asset; any future inflow re-arms the same path |
| Solo-quorum capture (buy 40% of bonded) | **$0 — impossible, not just expensive** | Needs **408,156,948.77 LIKE** (attacker's own stake raises the denominator). Total **liquid float is only 241.45M LIKE**, and total AMM inventory is **2.67M LIKE (153× short)**. No CEX lists v2 LIKE. Veto-proof (2/3) needs 1.224B > total supply | — |
| Distribution-module extra balance (26,712,763.38 LIKE) | **$0 via any standard proposal** | SDK v0.46.16 `DistributeFromFeePool` caps CP spends at the fee-pool DecCoins accounting (`SafeSub`) — the extra sits in the module account but is unreachable via `CommunityPoolSpendProposal`; software-upgrade-only (P) | A malicious upgrade binary could reach it (validators must adopt) — and it is still worthless v2 |
| IBC escrows (11,163,090.31 LIKE: Osmosis 10.91M, cosmoshub-4 255k, rest dust) | **$0** | Escrow accounts unlock only via IBC packet burns on the counterparty chain; no gov spend path | Upgrade-only (P); v2 value bounded by the same ~$2.6k of exit liquidity |
| Staking pools (612.24M bonded + 496.15M unbonded) | **$0** | Staking escrow, not proposal-spendable | Upgrade-only (P) |
| **v3 treasury multisig** (Base/OP/ETH/Unichain 2-of-3 `0x3aFaEA…`) | **Not v2-gov-controlled** (context) | Holds **262,852,138 v3 LIKE ≈ $382k** at $0.001454; controlled by the 2-of-3 guardians Safe, not by v2 governance | Key/multisig risk only |

## Total live extractable now

**≈ $2,580 (range $2,577–$2,587 across the two CI runs; hard-bounded by the total AMM counterpart ≈$2,624).** Confidence: **high** on state, params, cost and liquidity (all read live; SDK source checked; CI-reproduced); **medium** that v2 LIKE is no longer convertible to v3 (official announcement + app copy, but the migration app URL is still served); **medium-low** on the pass probability (3-validator social gate, no precedent of a hostile CP spend passing).

Categories: **E-U = $0** (no unprivileged direct path). **capture ≈ $2,577** (conditional on the 3 bonded validators passing a hostile CP spend; ~$111 refundable deposit). **P = $0 realizable** (software-upgrade-only extra module balance 26.71M LIKE + escrows 11.16M LIKE + 1.108B staked LIKE — all v2 tokens with no exit liquidity; nominal marks ≈$39k but not realizable). **H-O = $0** (holders' v2 is worthless; their only recovery is the same ~$2.6k of pool liquidity counted above). **S = $0** (chain live, nothing bricked).

**The corpus's "uneconomic" verdict is CONFIRMED — with two corrections:** (1) the prize is not $135k but **~$2.6k realizable** (v2 LIKE migration closed 2026-02-02 and v2 exit liquidity is dead); (2) the solo-quorum route is not merely expensive — it is **arithmetically impossible** on public markets (408.16M LIKE needed vs 241.45M total liquid supply and 2.67M AMM inventory). The only live path is the deposit + 3-validator vote.

---

## 1. The mechanism in exact terms

**Governance can move the community pool to any address; capture = the cost of a passing proposal.**

1. **Gov params** (reconstructed from the chain's own genesis + every `ParameterChangeProposal`; the live `/cosmos/gov/*/params` route is not served by the public LCD — HTTP 501 — so the reconstruction is documented and verifiable):

   | Param | Value | Source |
   |---|---|---|
   | `quorum` | **0.40** | genesis `tally_params`; never changed |
   | `threshold` / `veto_threshold` | **0.50 / 0.334** | genesis `tally_params`; never changed |
   | `min_deposit` | **100,000 LIKE** (1e14 nanolike) | prop 8 (2021-09) |
   | `max_deposit_period` | 14 days | prop 8 |
   | `voting_period` | **7 days** | prop 18 (2021-10), from 14d |
   | `burn_vote_veto` | true (deposit refunded on pass/reject, burned only on veto) | SDK v0.46 |
   | unbonding / community tax / inflation | 21 days / 0.02 / **0%** (prop 90, Jun-2025) | live reads |

   No expedited-proposal mechanism exists in SDK v0.46.

2. **The payout handler** — Cosmos SDK **v0.46.16** (exact version pinned by `likecoin-chain v4.2.0 go.mod`, replaced by `likecoin/cosmos-sdk v0.46.16-dual-prefix`; the fork's `x/distribution/keeper/fee_pool.go` contains the `SafeSub` check):
   - `CommunityPoolSpendProposal` (legacy gov content; the chain predates `MsgCommunityPoolSpend`) → `DistributeFromFeePool(ctx, amount, recipient)`.
   - `DistributeFromFeePool` does `feePool.CommunityPool.SafeSub(amount)` **first** (reverts if the spend exceeds the fee-pool accounting) and then `SendCoinsFromModuleToAccount(distribution → recipient)`.
   - Recipient is attacker-controlled; there is **no allowlist, timelock or spend limit** beyond the pool accounting. A proposal may carry multiple spend messages; execution is automatic at tally.

3. **What is spendable** (live, h 27,049,046, 2026-10-08T17:50:42Z):

   | Denom | Fee-pool accounting (= CP) | Distribution module balance | **Spend cap** | Nominal |
   |---|---|---|---|---|
   | nanolike | **79,981,046.277329568** | 106,693,809.659596853 | **79,981,046.28 LIKE** | $118.1k @ $0.0014767 (v3 price); $135k @ corpus $0.001688 |

   The extra **26,712,763.38 LIKE** in the distribution module is **not** spendable via CP spend (the `SafeSub` check). No other denom is in the pool.

4. **Historical precedent:** ~25 community-pool spends passed over the chain's life (props 24, 26–28, 31, 33, 35, 37, 40, 42–43, 45, 47–50, 53, 56–58, 60–61, 63, 66, 76, 78), including 20M LIKE (prop 47) and 15M LIKE (prop 53); the only rejection (prop 51) was followed by a corrected passing proposal (53). Turnout on routine proposals was 60–100% of bonded with Yes ≈ 97–100%. **But the chain is now in wind-down**: proposal 99 (Oct-2025) obsoleted v2 governance in favour of Snapshot and kicked off the v3 token migration; **there have been no proposals since** (last id 99; none in voting/deposit today).

---

## 2. Live-state assessment (all read live at h 27,049,046 unless stated)

| Item | Value | Where |
|---|---|---|
| Latest block | **27,049,046** (2026-10-08T17:50:42Z) | `blocks/latest` |
| Bonded tokens | **612,235,423.154764050 LIKE** | `staking/pool` |
| Not-bonded (unbonding + unbonded validators) | 496,147,229.922912378 LIKE | `staking/pool` |
| Supply | 1,467,694,529.009444021 LIKE (+ 10 dust IBC denoms) | `bank/supply` |
| Community pool | 79,981,046.277329568 LIKE | `distribution/community_pool` |
| Distribution module | 106,693,809.659596853 LIKE | module balance |
| Bonded validators | **3** — Civic Liker 212,397,484.82 · Oldcat 203,589,620.28 · Yasu 196,248,318.05 | `staking/validators` |
| All validators | 131 (128 unbonded, incl. Oursky 209.4M, UD 197.0M) | `staking/validators` |
| Gov module / fee_collector / likenft / mint / nft / transfer | **empty** | module balances |
| IBC escrows (LIKE) | channel-3 Osmosis 10,906,576.04 · channel-5 cosmoshub-4 255,038.61 · ch-0 1,390.27 · ch-1 65 · ch-4 20.4 | derived escrow addresses (ADR-028), balances read |
| Liquid float (supply − bonded − not-bonded − distribution − escrows) | **241,454,975.96 LIKE** | computed |
| Upgrade plan | none pending | `upgrade/current_plan` |
| Chain activity | 0 txs in sampled recent blocks (latest 5 sampled); only dust `MsgSend`s in the recent tx feed | `blocks`, `txs` |

**Market (the extraction bottleneck):**
- **v2 LIKE (the CP's token) is dead.** The official migration article: *"Migration period: 2025.11.03 – 2026.02.02 … Starting February 3, 2026, users will no longer be able to upgrade, and v2 tokens will lose all value."* The migration app's own copy confirms: *"The migration of LikeCoin officially spanned from November 3, 2025, to February 2, 2026"*; the app is on Base (v3 token `0x1ee5dd1794c28f559f94d2cc642bae62dc3be5cf`, 1.5B supply, treasury 262.85M).
- **Venues:** CoinGecko's LIKE entry (`likecoin-2`) now tracks the **v3 Base token only** — $0.001454–0.001477, mcap $1.8M, **24h volume $59.92**, tickers only Uniswap-V4-Base. **No CEX lists v2 LIKE.** The only v2 market is Osmosis (all 3,656 pools scanned; 9 LIKE pools, 3 meaningful):

  | Pool | Type | LIKE | Counterpart | USD |
  |---|---|---|---|---|
  | 555 | gamm | 1,521,946.98 | 768.06 ATOM | $1,503.59 |
  | 553 | gamm | 772,992.26 | 21,664.26 OSMO | $749.33 |
  | 1242 | gamm | 378,534.59 | 365.20 USDC | $371.33 |
  | 559/2567/551/552/554/1132 | gamm/stableswap | ~122 | AKT/HAVA/allXRP/uflix dust | ~$0.12 |
  | **Total** | | **2,673,595.45 LIKE** | | **$2,624.4** |

- IBC escrows show v2 LIKE was only ever bridged in size to Osmosis (10.91M) and Cosmos Hub (255k — no AMM on the Hub); Sifchain/Juno/Terra/etc. escrows are dust. So the v2 exit surface is fully captured by the Osmosis pools above.

---

## 3. What an attacker can and cannot do

**Path A — deposit + validator vote (the only live path).**
1. Acquire **100,000 LIKE** on Osmosis (buying it from pool 553 costs **≈$111**, fee-aware constant-product) — or reuse holdings.
2. Submit a `CommunityPoolSpendProposal` (recipient = attacker, amount = 79,981,046.28 LIKE), paying the 100,000-LIKE deposit (100% of min_deposit → straight to voting).
3. The **3 bonded validators** vote. Quorum is 40% of 612.24M = **244.9M LIKE of votes** — any one of the three validators voting (or abstaining) alone exceeds it; their combined 612.24M is 100% of the bonded set.
4. Yes > 50% of non-abstain and veto < 33.4% → passes → the spend executes automatically at tally; payout lands in 7 days.
5. Dump 79.98M LIKE into pools 555/553/1242 → **≈$2,577–2,587** max (the pools' counterparts, fee-aware); the CP amount is ~30× the pools' combined LIKE inventory, so the dump saturates them.

Cost: **≈$111 (refundable on pass or reject; burned only on veto)** + negligible gas. Downside if validators say No: gas + temporarily locked deposit. **The gate is entirely social: three identifiable community validators (Civic Liker, Oldcat, Yasu).** Historically routine CP spends passed with automated Yes; hostile airdrop-spam proposals (79/82/83) were vetoed.

**Path B — solo quorum (buy 40% of bonded).**
- Requirement: X ≥ q/(1−q)·B₀ = **408,156,948.77 LIKE** (the attacker's own stake raises the denominator).
- **Not executable at any price:** total liquid float is 241.45M LIKE (1.7× short even if every liquid holder sold), total AMM inventory is 2.67M LIKE (**153× short**), no CEX/OTC market exists. Veto-proof (2/3 of bonded) needs 1.224B LIKE > total supply.
- **Verdict: impossible and uneconomic.**

**Path C — software upgrade.** A malicious binary could move the distribution extra (26.71M), the IBC escrows (11.16M) and the staking pools (1.108B) — but requires validator adoption (P), and every v2 token still exits through the same ~$2.6k of liquidity, so the realizable incremental value is ≈ $0.

---

## 4. Verification (CI + live reads; no fork)

Cosmos governance cannot be fork-tested with Foundry; verification is instead:
- **Exact-version source check:** `likecoin-chain v4.2.0` pins `cosmos-sdk v0.46.16` with `replace => likecoin/cosmos-sdk v0.46.16-dual-prefix`; the fork's `x/distribution/keeper/fee_pool.go` contains the `SafeSub` cap (fetched and quoted in `analysis/raw/likecoin_sdk_fee_pool.go`, `sdk_fee_pool.go`).
- **Gov params:** genesis `tally_params` (quorum 0.4 / threshold 0.5 / veto 0.334) + props 8 & 18 decoded from the live proposals feed (the LCD returns 501 for `/cosmos/gov/*/params`); no other gov-subspace change ever passed.
- **Escrow addresses:** ADR-028 derivation (`sha256("ics20-1" + 0x00 + "transfer/channel-N")[:20]`, bech32 `like`), balances read per channel.
- **Reproducible CI job:** `ci/run.sh` → `ci/evidence.py` (pulls all raw state incl. Osmosis pools and prices) + `analysis/model.py` (recomputes the model) on the public runner; artifacts in `ci-artifacts/result-likecoin/`.

CI runs (both succeeded; artifacts in `ci-artifacts/result-likecoin/`):
- https://github.com/kingmariano/ca-zombie-ci/actions/runs/37947704314 (first evidence run)
- https://github.com/kingmariano/ca-zombie-ci/actions/runs/37948694975 (final run; ci-out/ + ci-log.txt reflect this one)

Key CI outputs (final run, h 27,049,046):
```
bonded LIKE:              612,235,423.15
CP accounting LIKE:       79,981,046.28 | nominal USD: 118,119.78
dist extra (unreachable): 26,712,763.38 | escrows: 11,163,090.31
bonded validators:        3 of 131
solo-quorum stake LIKE:   408,156,948.77 | USD: 602,785.42 (not executable)
dex LIKE inventory:       2,673,595.45 | ratio: 152.7x
min-deposit acquisition USD: 111.57 (refundable; burned only on veto)
CP realizable dump USD:   2,577.16
veto-proof stake LIKE:    1,224,470,846.31 (> supply)
solo quorum feasible:     False
```

---

## 5. Verdict, residual and latent risk

- **Classification: capture (not a contract E-U exploit).** Realizable prize **≈ $2.6k**; cost of the only live route **≈$111 refundable** + the 3-validator social gate. **"Uneconomic" confirmed** — and stronger than the corpus stated: the solo-quorum route is impossible (408.16M LIKE needed vs 241.45M total liquid supply / 2.67M AMM inventory), and the prize itself has collapsed to ~2% of its nominal mark because v2→v3 migration closed on 2026-02-02.
- **Corpus corrections:** CP "≈$135k" is a nominal mark at ≈$0.001688/LIKE — **realizable is $2.6k** (the v2 token has no conversion and ~$2.6k of exit liquidity). "> CP" is right but understated: solo capture is infeasible, not just unprofitable. The distribution module holds 26.71M LIKE beyond the CP that no CP spend can touch.
- **Residual/latent:** the chain is a live zombie (3 validators, ~0 user txs, governance dormant since Oct-2025, v3 governance moved to Snapshot). The CP keeps a tiny accrual from the 2% community tax; any hostile proposal still needs the 3 validators' votes. The bigger untouched asset is **off this chain**: the v3 treasury multisig (262.85M v3 LIKE ≈ $382k, 2-of-3 guardians) — key/multisig risk, not v2 governance.
- **Blockers (why it is not more):** migration closed → v2 tokens are unconvertible; the AMM exit surface is ~$2.6k; solo quorum > entire liquid supply; CP spend capped at the fee-pool accounting.

## 6. Methodology, sources, caveats

- **State:** public LCD `https://mainnet-node.like.co` (also its `/rpc/`), Osmosis LCD `https://lcd.osmosis.zone`, DefiLlama/CoinGecko prices, Base public RPC — all read 2026-10-08/09 (heights recorded in `ci-out/raw/`). The like.co LCD does not serve `/cosmos/gov/*/params` (HTTP 501) or per-validator delegations (404); gov params were reconstructed from genesis + all passed parameter-change proposals, and delegation-level breakdown was not available (validators vote their full bonded stake regardless).
- **Caveats:** (1) USD figures move with LIKE v3 ($0.00145–0.00148), OSMO ($0.0340), ATOM ($1.879); exact values in `ci-out/model.json`. (2) "v2 unconvertible" rests on the official announcement and the app's own copy (the migration URL still resolves); if the operator were to honour late migrations for a captured CP address, the nominal ($118k) would apply — but that is an off-chain courtesy, not an unprivileged on-chain path, and the CP (module-held) has no key to attest with. (3) Pass probability is a judgment, not a measurement: no hostile CP spend has ever been attempted here; three identifiable validators are the gate. (4) The dump model assumes single-block sale into the live pools; a patient seller cannot do better because the CP is 30× the pools' inventory. (5) Delegator-level concentration of the 3 validators was not readable from the public LCD; it does not change the arithmetic (the attacker still needs 408M LIKE to vote solo).
- **Files:** `analysis/model.py` (model), `analysis/out/model.{json,md}`, `analysis/raw/` (raw LCD/price/genesis/SDK pulls incl. `genesis_rpc.json`, `proposals_all_v1.json`, `osmosis_all_pools.json`, `escrow_balances.json`, `likecoin_sdk_fee_pool.go`), `ci/evidence.py` + `ci/run.sh` (CI job), `ci-out/` (CI artifacts), `ci-log.txt`, `ci-artifacts/`, `summary.json`.

*Note: this is measurement-only research for loss-sizing and disclosure; no signing or broadcast tooling is provided.*
