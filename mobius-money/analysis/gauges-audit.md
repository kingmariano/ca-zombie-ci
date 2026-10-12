# Mobius Money (Celo) — Gauge / Minter / VotingEscrow deep-dive (Phase 2)

Chain: Celo (42220). RPC: https://forno.celo.org (keyless, read-only). No transactions, no keys.
Related artifacts: `gauges-audit.json` (machine-readable), `gauge-claims-raw.json` (raw calls), `gauge-claimables-raw.json` (per-claimant CELO), `gauge-claimables-poomoo.json` (POOF/MOO).
Blocks cited: 79922881 (0xdAA2 storage & first RC reads), 79923216 (27-gauge live scan + token balances), 79925877 (holders), 79928392 (full-participant claimable sums). All reads on 2026-10-12.

## TL;DR

| Class | Amount | USD |
|---|---|---|
| **E-U (attacker-profitable, unprivileged)** | **$0** — no function transfers gauge tokens, LP, or CELO to an arbitrary caller | $0 |
| H-O (only stakers/LP holders recover) | 3,566.513523 CELO unclaimed rewards + staked LP + POOF/MOO positions | ~$334.9 rewards + ~$329.5k staked LP (est.) |
| S (stuck / privileged-only) | RC dust: ~5.13 CELO + ~11,038 MOO (owner-sweepable); donations to gauges (none found) | ~$3.1 (owner-only) |

Confidence: **high** for E-U = $0 on the gauge/minter/VE surfaces reviewed here. All external emission streams are dead since 2021–2022; the only live value is unclaimed CELO sitting in 10 gauges, and its entirety is attributable, per-account claimable by the account itself only (informational test: `claimable_reward(0x…dEaD, CELO) = 0`; `claim_rewards` pays only to the target address/receiver).

## Classification detail

### E-U — candidates reviewed and eliminated (attacker = any unprivileged address)
| Path | Call result / reason it is not E-U |
|---|---|
| `claim_rewards(_addr=anyone, _receiver=0)` | Source: if `_receiver != 0` then `assert _addr == msg.sender`; with `_receiver=0` tokens go to `rewards_receiver[_addr]` or `_addr`. Sim on 0xdAA2 from 0x…dEaD: succeeds, pays nothing to caller. |
| `claimable_reward_write(_addr,_token)` | Checkpoints `_addr` only; stores (never transfers). Fresh address returns 0. |
| `user_checkpoint(_addr)` | `assert msg.sender == addr or msg.sender == minter` (dev: unauthorized). |
| `kick(addr)` | Only recomputes `working_balances` (boost). No transfers; requires `ve` balance 0 or newer ve event. |
| `withdraw(_value)` | Deducts own `balanceOf[msg.sender]`; `nonreentrant`; LP is standard ERC20 (no hooks). |
| `deposit(_value,_addr)` | Credits `_addr`; LP comes from `msg.sender`; rewards go to `_addr` receiver. Cannot take LP back. |
| `transfer`/`transferFrom` | Standard; checkpoints both sides; allowance decrement; no double-spend. |
| `set_rewards`/`set_killed`/`commit/accept_transfer_ownership` | `msg.sender == admin` = GaugeProxy `0x0a3Ac12422C95F84b5bD18A6d9904d132a161C68`; GaugeProxy itself guards `set_rewards`/`set_killed` to ownership/emergency admins. |
| `GaugeProxy.accept_transfer_ownership(gauge)` | **Permissionless in GaugeProxy.vy**, but no gauge has a pending `future_admin` change (checked all 27: 22 gauges `future_admin == admin == GaugeProxy` (self, no-op); 5 gauges `future_admin == 0` (cannot accept)). No-op today. |
| Reward contract calls | `notifyRewardAmount` only `rewardsDistribution` (revert: "Caller is not RewardsDistribution contract"); `setRewardsDuration`/`updatePeriodFinish` only owner; `recoverERC20` blocks staking token ("Cannot withdraw the staking token"). `earned(gauge) == 0` for all RCs. |
| `Minter.mint`/`mint_many` | Mints only `msg.sender`'s accrued MOBI (`user_checkpoint(msg.sender)`); `mint_for` requires `toggle_approve_mint`. MOBI token `mint(address,uint256)` from 0x…dEaD reverts (minter-restricted). MOBI ≈ $0. |
| Burner `0x84c991…` | `withdrawETH()` is callable by anyone (sim from 0x…dEaD succeeds) but contract holds **0** native/tokens (CELO/MOBI/cUSD + Blockscout token list all empty). `withdrawToken([CELO])` from 0x…dEaD reverts. No value today. |

No `emergency_withdraw` exists in the gauge source. No storage-overflow path found (Vyper 0.2.12 bounds-checks; `claim_data` packing reverts on >2^128).

### H-O — recoverable only by stakers/LP holders
- **3,566.513523 CELO** of unclaimed external rewards across 10 gauges. Full-participant enumeration (all transfer participants; 6,506 addresses; block 79928392) attributes **100 %** of each gauge's CELO balance (residual = 0 for all 10). Top claimants (verified live): 749.899186 CELO for `0xa0c5c335ecf2db900e8365e402206a6cc33b70bb` (0xc96A, bal 0 — exited, stored claim), 386.043769 for `0xa75c6a6af1757f543546be1d472d0acb1981d0db` (0xE1f9), 341.694798 for `0xa0f2e2f7b3ab58e3e52b74f08d94ae52778d46df` (0xc96A), etc. Each address recovers its own `claim_data` via `claim_rewards()` / `withdraw(_,true)`.
- **Staked LP tokens** (e.g., 66,432.15 LP on gauge 0xdAA2): withdrawable 1:1 by each staker via `withdraw()`. LP is held by the Synthetix-style reward contract; `recoverERC20` cannot take the staking token. Estimated staked value ≈ **$329,528** (under-estimate; 13 unpriced token entries, old pXXX tokens).
- POOF/MOO gauge balances (1,345.62 POOF, 1,398.05 MOO) belong to current holders + exited stakers (residual = stored `claim_data`). USD negligible (~$0.37).

### S — stuck / privileged-only
- RC dust CELO ≈ **5.1349 CELO** ($0.48) across 10 RCs; `recoverERC20(CELO,…)` as owner succeeds (eth_call), so it is owner-sweepable (Safe/EOA), otherwise stuck.
- RC dust MOO ≈ **11,038 MOO** ($2.65) in MOO-gauges' RCs (e.g., 5,438.36 in `0xca54a6cc…`), same ownership.
- Donations sent directly to gauges are permanently stuck (integral only counts balance delta during reward-contract claim calls); none found — residual is exactly 0.

## 1. Gauge implementation and exact claim mechanics

**Implementation:** Vyper 0.2.12 "Liquidity Gauge v3" (Curve fork; header "@author Mobius Finance"). Verified source on Blockscout at `0xdAA2ab880b7f3D5697e6F85e63c28b9120AA9E07` (also verified for `0xc96A…`, `0x107F…`, `0x1250…`; identical source hash, so all 27 share the code). GitHub: `mobiusAMM/mobi-dao-contracts/contracts/gauges/LiquidityGaugeV3.vy` (HTTP 200).

Constructor wires: `minter` = hardcoded via `_minter`; `crv_token` = `Minter.token()` = **MOBI** `0x73a210637f6F6B7005512677Ba6B3C96bb4AA44B`; `controller` = `Minter.controller()` = `0x7530E03056D3a8eD0323e61091ea2f17a1aC5C25`; `voting_escrow` = controller's VE = `0xd813a846aA9D572140d7ABBB4eFaC8cD786b4c0E`.

**Reward accounting (two independent systems):**
1. **MOBI emissions** — `_checkpoint()` integrates `inflation_rate × gauge_relative_weight / working_supply`. `claimable_tokens(addr)` (non-view) returns `integrate_fraction[addr] − Minter.minted(addr, gauge)`. Minted via `Minter.mint(gauge)`. `is_killed=true` sets rate=0 (12 of 27 gauges are killed; the other 15 still accrue MOBI — value ≈ $0).
2. **External rewards (CELO / POOF / MOO)** — a Synthetix-style reward contract is set via `set_rewards(reward_contract, sigs, tokens)` (admin-only). `_checkpoint_rewards` claims from it (raw_call, max once per hour: `CLAIM_FREQUENCY=3600`), then distributes: `dI = 1e18 × (balAfter − balBefore) / totalSupply`; per user `new_claimable = balanceOf[user] × (integral − integral_for[user]) / 1e18`, stored in `claim_data[user][token]` (hi128 = claimable, lo128 = claimed). `claim_rewards(_addr,_receiver)` pays stored+pending to `_receiver` (only allowed if `_addr==msg.sender`), else `rewards_receiver[_addr]`, else `_addr`.

**Live gauge state examples (blocks 79922881 / 79923216):**
- `reward_data` slot 20 of `0xdAA2` = `0x00000000000000006a363f70c8b86c28a0026ea72b7624fa3c912ad77f1d5fe0` → reward contract `0xC8B86C28A0026eA72b7624FA3C912ad77F1D5fe0`, last_claim `1781940080` = 2026-06-20T07:21:20Z.
- `reward_sigs` slot 22 of `0xdAA2` = `0xa694fc3a2e1a7d4d3d18b912…` → `stake(uint256)`, `withdraw(uint256)`, `getReward()`.
- Gauge admin: 22 of 27 gauges have `admin() == future_admin()` = GaugeProxy `0x0a3Ac12422C95F84b5bD18A6d9904d132a161C68`; five (`0x1A648004…`, `0x1250D6dd…`, `0xE965Dd2B…`, `0x73fDa872…`, `0x4E3E91b6…`) have `admin() = 0x6c0dFba3bcdb224278474E8d524F19c6BB55850` (EOA) with `future_admin = 0`. No pending ownership transfer anywhere.
- `Minter.minted` bookkeeping: all RCs' `userRewardPerTokenPaid(gauge) == rewardPerTokenStored` and `rewards(gauge)==0` → **earned(gauge)=0**, i.e., nothing left to claim from any RC.

**All external streams are dead:** periodFinish ranges 1636659238 (2021-11-11) … 1648918407 (2022-04-02); `rewardRate` only mattered historically.

## 2. Live per-gauge table (block ~79923216–79928392)

| Gauge | killed | ext. reward tokens | RC | periodFinish | unclaimed (all claimants) | staked LP | claimable USD |
|---|---|---|---|---|---|---|---|
| 0xdAA2ab88… | K | CELO | 0xc8b86c28… | 2021-11-26 | 203.349468 CELO | 66,432.15 | 19.07 |
| 0xD38e76E1… | K | – | – | – | – | 16.63 | 0 |
| 0x1A8938a3… | K | – | – | – | – | 0.0000000149 | 0 |
| 0xd1B3C05F… | – | CELO | 0x0c7136ff… | 2021-11-26 | 61.760609 CELO | 22,494.71 | 5.79 |
| 0xe2d60956… | – | – | – | – | – | 20,508.89 | 0 |
| 0x52517feb… | K | CELO | 0x3804da7a… | 2021-11-26 | 1.650613 CELO | 353.54 | 0.15 |
| 0x27D9Bfa5… | – | CELO | 0xedd2c938… | 2022-03-02 | 740.435469 CELO | 33,787.15 | 69.45 |
| 0x1A648004… | – | – | – | – | – | 0 | 0 |
| 0x1250D6dd… | K | POOF+MOO | 0x92e51588… | 2021-11-11 | 0.326 POOF + 0.450 MOO | 28.29 | ~0 |
| 0xCF34F4ec… | K | POOF+MOO | 0x31ccb9dc… | 2021-11-23 | 255.24 POOF + 277.36 MOO | 2,225.07 | 0.072 |
| 0x5489b2F0… | K | POOF+MOO | 0xb6a5059a… | 2021-11-23 | 526.70 POOF + 564.12 MOO | 2,800.97 | 0.147 |
| 0x2459BDb5… | K | POOF+MOO | 0xe8b28664… | 2021-11-23 | 31.38 POOF + 87.75 MOO | 890.98 | 0.022 |
| 0xF2ae5c2D… | – | – | – | – | – | 516.30 | 0 |
| 0xc96AeeaF… | – | CELO | 0x764771ed… | 2022-03-02 | 1,466.799170 CELO | 6,392.09 | 137.59 |
| 0x487c30CB… | – | CELO | 0x0757c02b… | 2022-01-01 | 281.665342 CELO | 12.45 | 26.42 |
| 0x127b524c… | – | CELO | 0x66d65753… | 2022-01-01 | 250.850744 CELO | 0.438 | 23.53 |
| 0x0A125D47… | – | CELO | 0xbcb4029f… | 2022-03-02 | 51.251857 CELO | 4,547.89 | 4.81 |
| 0xE1f9D952… | – | CELO | 0x78c5a63b… | 2022-03-02 | 486.982813 CELO | 83,314.56 | 45.68 |
| 0xE965Dd2B… | – | – | – | – | – | 0 | 0 |
| 0x73fDa872… | – | – | – | – | – | 0 | 0 |
| 0x4E3E91b6… | – | – | – | – | – | 0 | 0 |
| 0xE7195E65… | K | POOF+MOO | 0xca54a6cc… | 2022-02-17 | 17.89 POOF + 24.20 MOO | 2,629.47 | 0.006 |
| 0xD0d57a66… | K | POOF+MOO | 0x64d996b7… | 2022-02-17 | 414.79 POOF + 378.94 MOO | 3,366.98 | 0.100 |
| 0xCAEd243d… | K | POOF+MOO | 0xc99cda8f… | 2022-02-17 | 99.30 POOF + 65.23 MOO | 3,991.01 | 0.018 |
| 0x107F9440… | K | CELO | 0x84282839… | 2022-03-02 | 21.767439 CELO | 7,273.19 | 2.04 |
| 0x7ed927E6… | – | – | – | – | – | 92.00 | 0 |
| 0x70AE7265… | – | – | – | – | – | 189.92 | 0 |

K = `is_killed()==true` (MOBI emissions stopped). Full exact wei values, claimant lists, and RC fields are in `gauges-audit.json` / `gauge-claimables-raw.json`.

## 3. Minter (task 3)

- **Minter** `0x5F0200CA03196D5b817E2044a0Bb0D837e0A7823` — verified source: Curve "Token Minter" fork (Vyper ^0.2.4). `token()` = MOBI `0x73a2…`, `controller()` = `0x7530…` (checked live).
- `mint(gauge_addr)` / `mint_many` call `LiquidityGauge(gauge).user_checkpoint(msg.sender)` and mint `integrate_fraction(user) − minted[user][gauge]` to **msg.sender only**; `mint_for` requires `allowed_to_mint_for[msg.sender][_for]` (toggle_approve_mint). Assert `controller.gauge_types(gauge) >= 0` (all 27 gauges return 0).
- **Mint-guard test:** `MOBI.mint(0x…dEaD, 1e18)` simulated from 0x…dEaD at block ~79924000 reverts → MOBI's `minter()` is the Minter contract `0x5F02…` and is the only minter. MOBI `admin()` = `0x6c0dFba3bcdb224278474E8d524F19c6BB55850` (EOA, no code).
- **Value:** MOBI has no DefiLlama feed. DexScreener Ubeswap MOBI/CELO pool (0x0B81CF47C8F97275d14C006E537D5101b6C87300): $0.000003453, liquidity $1,415 (2026-10-12) → FDV ≈ $2.7k. **Mint abuse extracts ≈ $0.** Gauge `inflation_rate()` is still non-zero on the 15 un-killed gauges, but that only inflates MOBI and is capped by the same integrate_fraction accounting; no path mints to an attacker beyond their own accrual.

## 4. VotingEscrow (task 4)

- `0xd813a846aA9D572140d7ABBB4eFaC8cD786b4c0E` — verified Curve "Voting Escrow" fork (veMOBI). Live: `totalSupply()` = 277,458.493571829369924860 veMOBI; `supply()` = `balanceOf(MOBI→VE)` = **66,407,864.730943943602645442 MOBI** (exact equality → nothing extra/donated). `CELO balance = 0`; Blockscout token-balances lists only MOBI (no other assets).
- `admin()` = `0x6c0dFba3bcdb224278474E8d524F19c6BB55850` (EOA); `future_admin` = 0; `smart_wallet_checker` = 0; `epoch` = 18273.
- Withdrawal logic is stock Curve VE (`withdraw()` asserts unlock time passed; `deposit_for`, `create_lock`, `increase_amount`, `increase_unlock_time` as usual). Admin has no power to seize locks; no unclaimed assets beyond locked MOBI (`supply()` == MOBI balance exactly).

## 5. Other contracts (task 5)

| Address | What it is | Evidence |
|---|---|---|
| `0x4ea77424da100ac856ece3ddfabd8b528570ca0d` | **EOA** (no code) | `eth_getCode` = `0x`; `owner()` of pool `0x81b6a3d9f725ab5d706d9e552b128bc5bb0b58a1` (paused; its LP `0x57f00817…` is the underlying of gauge `0x1250…`) |
| `0x6c0d6Fba3bcdb224278474E8d524F19c6BB55850` | **EOA** (no code) | VE admin, MOBI token admin, `devaddr` on several pools (from live-state swap storage) |
| `0x84c991aF33B6D1F14D65E50d37828FD9F744625a` | **Contract, 1,774 bytes, UNVERIFIED** (owner `0x6BE0fF2BED16a50169f941DafEf6be050182f88c`, an EOA) | selectors: `transfer`, `transferFrom`, `withdrawToken(address[])`, `withdrawETH()`, `owner/renounce/transferOwnership`, `0x89afcb44`; balances: native 0, CELO 0, MOBI 0, cUSD 0, Blockscout token list empty; `withdrawETH()` callable by anyone (sim from 0x…dEaD returns success) but holds nothing; `withdrawToken([CELO])` from 0x…dEaD reverts "transfer value exceeded balance of sender"; `transfer(0x…dEaD,1)` returns true (no-op on 0 balance) |
| GaugeProxy `0x0a3Ac12422C95F84b5bD18A6d9904d132a161C68` | Gauge admin contract (source `mobiusAMM/mobi-dao-contracts/contracts/GaugeProxy.vy`); `ownership_admin` = Timelock `0x7d9Af9dF33D6CAB895B4cF3422D790cbE98B48c8`, `emergency_admin` = Safe `0x16E319d8…` (4 owners, `getOwners()` returned `0xE35E97…, 0x59A6Ab…, 0xB811Ad…, 0xc59cd8…`) | `accept_transfer_ownership(gauge)` has no access check (quirk) but no gauge has a pending future_admin |
| Reward-contract owners | mostly Safe `0x16E319d8dAFeF25AAcec0dF0f1E349819D36993c`; MOO-gauges' RCs owner `0x313bc86d…` (owner `0xd7f77169d5E6a32C5044052F9a49eb94697b25ED`, EOA). `rewardsDistribution` for some = Safe `0xc77b8e88…` / `0x3b0b4c99…` | live getters; `recoverERC20(CELO,1)` eth_call as owner succeeds; staking token blocked |

## 6. Evidence / reproduction

Raw calls live in `gauge-claims-raw.json` (gauge_calls, reward_contract_calls, token_balances), `gauge-claimables-raw.json` (CELO per participant), `gauge-claimables-poomoo.json` (POOF/MOO per holder), `rc_poomoo_balances_tmp.json`, `lp_supplies_tmp.json`.

Key commands (read-only; cast + keyless RPC):
```
cast call 0xdAA2… "claimable_reward(address,address)(uint256)" 0x…dEaD 0x471EcE…   # 0
cast call 0xdAA2… "claim_rewards(address,address)" 0x…dEaD 0x…dEaD --from 0x…dEaD  # ok, no payout
cast call 0xdAA2… "is_killed()(bool)"                                               # true
cast storage 0xdAA2… 20   # reward_data → 0xC8B86C28… + ts 1781940080
cast storage 0xdAA2… 22   # reward_sigs → stake/withdraw/getReward
cast call 0xC8B86C28… "recoverERC20(address,uint256)" <LP> 1 --from 0x16E319d8…    # revert: Cannot withdraw the staking token
cast call 0x84c991… "withdrawETH()" --from 0x…dEaD                                  # succeeds (0 balance)
```
Source of truth for accounting: verified Vyper source `LiquidityGaugeV3` (`_checkpoint_rewards`) + Curve `Minter`/`VotingEscrow` sources.

## 7. Caveats / confidence

1. E-U = $0 is supported by source-level enumeration of every external function plus live simulations (fresh address claims 0, RC guards revert). The reward contracts themselves are unverified bytecode; the important behaviours were exercised on-chain via eth_call (guards/earned=0) and match the standard Synthetix StakingRewards ABI (all 29 selectors identified).
2. CELO claimable sums were measured at block 79928392 vs gauge balances at 79923216 — per-gauge residual is 0 within dust (differences ≪ 0.000001 CELO).
3. POOF/MOO residual (gauge balance − current-holder claimable) is the aggregate stored `claim_data` of exited stakers; no attacker path reaches it (same `_checkpoint_rewards` machinery proven for CELO where full participant enumeration closed the books to zero).
4. LP valuation is a lower bound (unpriced legacy tokens modelled at $0); prices from DefiLlama/DexScreener on 2026-10-12.
5. Not in scope of this child task: pool/swap-level bugs, MOBI token economics beyond mint-guard, claims of already-withdrawn historical rewards.
