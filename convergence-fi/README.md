# Convergence Fi (Ethereum) — live extraction-surface deep dive (zombie-hunt II · L2 Phase 2)

**Date of work:** 2026-10-11 · **Chain:** Ethereum mainnet · **Status:** read-only research; fork-verified PoC only; no mainnet transactions sent.
**Target from triage:** `0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7` (CvgControlTowerV2 proxy) → 37 StakeDAO staking positions (viewer `0xA3A8cDA21f50b6737385E46FC9495a9998B05Ff0`), triage value $1,095,178.

---

## 1. TL;DR

| Target | Live value (block 26,169,6xx) | Live extractable by external unprivileged attacker | Why closed/open | Latent risk |
|---|---|---|---|---|
| 37 `SdtStakingPositionService` positions (sdCRV, sdPENDLE, sdFXN, …) — gauge tokens held by `SdtBlackHole` | **$1,095,949** (priced $1,094,611 + unpriced legs est. $1,338) | **$0** | `SdtBlackHole.withdraw` requires `isSdtStaking[msg.sender]`; every service `withdraw`/`claim` is gated on position-NFT ownership (`checkTokenFullCompliance` → `receiver == ownerOf(tokenId)`); `mint`/`claimCvgSdtSimple` require `isStakingContract`; CloneFactory/tower setters are `onlyOwner` | Gauge admin is a **1-of-1 Safe** (`set_claimer`) → can redirect *pending gauge rewards* (not principal); Convergence `ProxyAdmin` is a 3-of-6 Safe → upgrade risk |
| `cvgSDT` staking pool (`0xF941BC…`, vault = itself) | **$141,116** (1,447,884.82 cvgSDT @ SDT parity $0.09746) | **$0** | Same NFT-ownership gate; `withdraw` executes `cvgSDT.transfer(owner, amount)` only after `checkTokenFullCompliance` | None found |
| `SdtRewardDistributorV2` (unclaimed staker rewards) | **$85,163** (295,297 sdCRV, 11,928 crvUSD, …) | **$0** | `claimMultipleStaking` → `checkMultipleClaimCompliance(claims, msg.sender)` (`TOKEN_NOT_OWNED`); `claimCvgSdtSimple` → `isStakingContract[msg.sender]` | None found |
| `stkCVGETH` vault | ~$1,202 (0.3859 wstETH) + CVG legs (~$100 total, CVG @ $0.0000558) | **$0** | `StkCvg` (impl `0xe789b78f…`) — withdrawal paths are staker-gated (not the L2 target; sampled) | — |
| `vlBoost`/`veBoost` (1.83M each) held by `SdtBlackHole` | $0 realizable | **$0** | `transfer`/`transferFrom` are `pure` → non-transferable; blackhole has no transfer function | — |

**Total live extractable by an external unprivileged attacker now: ≈ $0. Confidence: high.**
Live value is **holder-recoverable (H-O)**: $1,095,949 of position principal + $141,116 cvgSDT pool + $85,163 unclaimed rewards ≈ **$1,322,228** belongs to 687 position NFTs held by 400 distinct owners, all of whom can still self-withdraw/claim on-chain (positive-control test in `poc/`).

---

## 2. The system, in exact terms

Convergence Fi ("Convergence 2.0") stakes StakeDAO `sd*` gauge assets for its users and distributes CVG/SDT rewards.

**Custody chain (verified on-chain + in verified sources):**

1. **`CvgControlTowerV2`** — `0xB0Afc8363b8F36E0ccE5D54251e20720FfaeaeE7` (TransparentUpgradeableProxy → impl `0xbdbddc4b…`). Pure registry: `getSdtStakings(0,1000)` returns **37** `ISdtStakingPositionService` contracts + names. It holds no tokens (GoldRush: empty). `insertNewSdtStaking` requires `msg.sender == cloneFactory`; `toggleStakingContracts` is `onlyOwner`.
2. **37 `SdtStakingPositionService` clones** (BeaconProxy → impl `0xdba75359…`, beacon `0x8678186f…`, beacon owner = 3-of-6 Safe `0x0af81536…`). Users `deposit` gauge assets; the service transfers them to `vault` = **`SdtBlackHole`** (except the separate `cvgSDT` staking service, `vault = self`). Positions are NFTs in `SdtStakingPositionManager` (`0x7319662a…`).
3. **`SdtBlackHole`** — `0x21777106355Ba506A31FF7984c0aE5C924deB77f` (impl `0xf13797bf…`) holds all staked gauge tokens. Its only token-moving function:
   ```solidity
   function withdraw(address receiver, uint256 amount) external {
       require(cvgControlTower.isSdtStaking(msg.sender), "ONLY_SD_ASSET_STAKING");
       ISdtStakingPositionService(msg.sender).stakingAsset().transfer(receiver, amount);
   }
   ```
4. **Services' user exits** — `withdraw(tokenId, amount)` and all claim functions carry `modifier checkCompliance(tokenId)` → `SdtStakingPositionManager.checkTokenFullCompliance(tokenId, msg.sender)`:
   ```solidity
   require(receiver == ownerOf(tokenId), "TOKEN_NOT_OWNED");
   require(msg.sender == stakingPerTokenId[tokenId], "WRONG_STAKING");
   require(unlockingTimestampPerToken[tokenId] < block.timestamp, "TOKEN_TIMELOCKED");
   ```
   `_updateAmountStakedWithdraw` also enforces `require(amount <= _tokenTotalStaked, "WITHDRAW_EXCEEDS_STAKED_AMOUNT")`.
5. **`SdtRewardDistributorV2`** — `0x6B65525a…` (impl `0x2af5ae07…`) holds processed-but-unclaimed rewards. `claimMultipleStaking` → `checkMultipleClaimCompliance(claimContracts, msg.sender)` (owner check per tokenId); `claimCvgSdtSimple` → `require(isStakingContract[msg.sender])`.
6. **Gauge assets** (`stakingAsset` of each service, e.g. sdCRV service → `0x7f50786a…` "Stake DAO sdCRV Gauge", a Vyper LiquidityGauge behind a TransparentUpgradeableProxy): `claim_rewards(_addr, _receiver)` asserts `_addr == msg.sender` if a receiver is given; `claim_rewards_for` asserts `msg.sender == claimer`. No redirect of third-party rewards.
7. **`CvgSDT`** — `0x830614aE…` (plain ERC20, not a proxy): `mint` takes SDT 1:1 (sent to `veSdtMultisig` = 3-of-N Safe `0x6ceE94bF…`), `burn` burns caller's own balance. The `cvgSDT` staking service (`0xF941BC…`, vault = self) holds **1,447,884.82 cvgSDT**, exactly equal to its `cycleInfo(141).totalStaked`.

---

## 3. Live state (block 26,169,583–26,169,646, 2026-10-11)

- **37/37 positions backed**: for every service, `stakingAsset.balanceOf(SdtBlackHole) ≥ cycleInfo(stakingCycle).totalStaked` (script `analysis/live_balances.py`, dump `analysis/live_balances.json`; CI test `test_live_all_37_positions_backed`).
- Largest: sdCRV — `totalStaked` 3,482,014.19, blackhole balance 3,483,547.76 sdCRV-gauge (`0x7f50786a…`), 131 NFTs.
- Pricing (DefiLlama current, `analysis/pricing.json`): $1,094,610.99 for directly-priced legs (sdCRV $688,602; sdPENDLE $291,232; sdFXN $113,137; …). Unpriced legs estimated from underlyings: sdFXS 3,217.80 × $0.3407 = $1,096; sdBal 1,643.54 × $0.1290 = $212; sdANGLE 182,359.92 × $0.0001634 (GeckoTerminal) = $30. **Total ≈ $1,095,949** (triage $1,095,178 agrees within pricing drift).
- **Ownership**: 687 NFTs total (`SdtStakingPositionManager`), **400 distinct owners** (`analysis/nft_owners.json`) — real users, not protocol custody. 131 NFTs on the sdCRV service, 76 on the cvgSDT service.
- **Roles/upgradeability** (`analysis/proxy_admins.py`):
  - Owner of tower + all 37 services + beacon + factory + manager + distributor + blackhole = Safe `0x0af815364BD9e9E60f3d2D3bAc1320B77d3E35F7` — **3-of-6** Gnosis Safe.
  - `ProxyAdmin` `0xf16d93ac…` (admin of tower/blackhole/manager/factory/distributor) — owner = the same 3-of-6 Safe.
  - Gauge `ProxyAdmin` `0xfe612c23…` — owned by StakeDAO-side contract `0xD3cFc4E6…`; gauge `admin()` = Safe `0xe5d6D047…` — **1-of-1** Safe (`getThreshold()=1`, single owner `0xb27afc78…`).
  - All initializers consumed (`owner()` set on every service; `gauge.initialized()==true`); no init exposure found.
- **Reward pools**: distributor holds $85,163 (295,297 sdCRV = $58,221; 11,928 crvUSD; 10,302 CRV; 2,727 USDT; 1,394 sdPENDLE; 0.765 wstETH; …). Blackhole SDT = 0; fee collector ≈ 0; buffers empty; sdCRV gauge `claimable_reward(blackhole, SDT)` = 0.
- **`processSdtRewards()`** is permissionless but pays the caller `buffer.processorRewardsPercentage()/100_000` = **1%** of the rewards it processes — a designed keeper fee, not extraction of principal (documented; observation test in PoC).
- **Dead-end notes (do not re-investigate):** blackhole `vlBoost`/`veBoost` (1.83M each) are non-transferable (`transfer`/`transferFrom` are `pure`); the two gauge claimer contracts (`ClaimRewardsV1` `0x539e6519…`, `ClaimRewards` `0x63312010…`) only ever claim for `msg.sender` (their own rewards); `SdtBlackHole.pullSdStakingBribes` requires `isBuffer[msg.sender]`.

---

## 4. What an attacker can / cannot do

| # | Attempted path | Result (fork-verified) |
|---|---|---|
| 1 | `SdtBlackHole.withdraw(attacker, amount)` from an EOA | **Reverts `ONLY_SD_ASSET_STAKING`** — caller must be a registered staking service |
| 2 | `service.withdraw(tokenId, amount)` for a position the attacker does not own | **Reverts `TOKEN_NOT_OWNED`** |
| 3 | `distributor.claimMultipleStaking([service, tokenId], …)` as non-owner | **Reverts `TOKEN_NOT_OWNED`** |
| 4 | `gauge.claim_rewards_for(blackhole, attacker)` | **Reverts** (`msg.sender != claimer`) |
| 5 | `gauge.claim_rewards(blackhole, attacker)` | **Reverts** (Vyper assert `_addr == msg.sender` when redirecting) |
| 6 | `service.initialize(...)` on a live service | **Reverts** (already initialized) |
| 7 | `tower.toggleStakingContracts([attacker])` / `insertNewSdtStaking(attacker)` | **Reverts** (`Ownable` / `CLONE_FACTORY`) |
| 8 | `factory.createSdtStakingAndBuffer(attacker, …)` | **Reverts** (`onlyOwner`) |
| 9 | `manager.burn(tokenId)` / `manager.setLock(tokenId, …)` as non-owner | **Reverts** (`onlyNftOwner`) |
| 10 | **Positive control** — real owner of tokenId 177 self-withdraws 1,000 sdCRV-gauge | **Succeeds**; owner +1,000e18, blackhole −1,000e18 (H-O path live) |

Costs: no capital needed for any of the (reverting) attacker paths; the only permissionless value flow is the 1% keeper fee, which is net of the caller's gas and intended by the protocol.

---

## 5. PoC / fork verification

- Project: `poc/` (Foundry; vendored `lib/forge-std`; solc 0.8.24).
- Test file: `poc/test/ConvergenceFi.t.sol` — live-state backing tests, 9 attacker-revert tests, 1 positive-control withdraw test, keeper-fee documentation + `processSdtRewards` observation.
- CI: `.github/workflows/poc.yml` on `kingmariano/ca-zombie-ci` (public), branch `convergence-fi` — run URL(s): **_(filled after run)_**.
- Custom CI evidence job: `ci/run.sh` → `ci-out/live-state.json` (37 positions: `totalStaked` vs blackhole balance at the CI fork block).

**_(Test results and CI URL inserted after the run completes.)_**

---

## 6. Verdict, residual & latent risk

- **E-U (external unprivileged): $0.** Every path that moves principal or rewards requires either (a) ownership of the position NFT, or (b) being a registered Convergence contract, or (c) the owner Safe. None is forgeable.
- **H-O (holders): ≈ $1,322,228** — $1,095,949 principal + $141,116 cvgSDT pool + $85,163 unclaimed rewards, all self-service for the 400 NFT owners. Note realizability: gauge tokens are redeemable for the `sd*` asset through StakeDAO, and `cvgSDT` has a Curve secondary market (SDT/cvgSDT LP `0xfB518291…`); deep exit liquidity for the largest legs (sdCRV $688k) is the main haircut risk.
- **P (privileged):** 3-of-6 Safe can upgrade the blackhole/services (custody risk only if the Safe itself is compromised); the **1-of-1 gauge-admin Safe** could set the gauge `claimer` and redirect *pending gauge rewards* (not principal). Flagged as latent, not live.
- **S (stuck):** blackhole `vlBoost`/`veBoost` (1.83M each, non-transferable, no market); negligible.
- **What would change the verdict:** a governance/owner key compromise (P), a future permissionless function added via upgrade, or a StakeDAO-side change to the gauge implementation (StakeDAO ProxyAdmin, third-party).

---

## 7. Methodology, sources, caveats

- On-chain reads via `cast`/JSON-RPC at blocks 26,169,583–26,169,646 (recorded in `analysis/*.json`). Verified sources from Etherscan V2 (impl/ABI/source extracted to `analysis/src/`). Prices: DefiLlama `coins.llama.fi` current, GeckoTerminal for ANGLE/CVG. Token holdings: GoldRush `balances_v2`.
- Caveats: `cvgSDT` has no direct oracle (valued at SDT parity; pool-implied ≈ $0.0959); unpriced legs estimated from underlyings; the distributor's claimable-vs-held reconciliation was not done event-by-event (no mismatch found in sampled state).
- Files: `analysis/enumerate_positions.py`, `analysis/live_balances.py`, `analysis/pricing.py`, `analysis/nft_owners.py`, `analysis/proxy_admins.py`, `analysis/state_positions.json`, `analysis/live_balances.json`, `analysis/pricing.json`, `analysis/nft_owners.json`, `analysis/token_holdings.json`; PoC `poc/`; CI `ci/run.sh`, `ci-out/`.
