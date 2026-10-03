# C-36 seg-E — forgotten-eth recovery index (zombie-hunt) — segment E report

**Scope:** 7 seg-E contracts (5 MasterChef clones, P4RTY DAO Vault, Last Winner) + 7 child/backing contracts from `child_extra.json` + the 37 index addresses not assigned to any segment (created `unassigned.json` here).  
**Method:** read-only `cast call/balance/logs`, Blockscout/Sourcify verified sources, WETH/event enumeration. **Blocks 26,111,147–26,111,377 (2026-10-03).** No mainnet transactions.  
**Headline: 0 E-U candidates found.** 47 × H-O, 4 × S. No fork-test request is raised. Two index mapping errors found (P4D over-mapped by ~7.63 ETH; AimBot dividends child missed, +67.46 ETH real H-O).

## 1. Segment-E contracts

| address | name | live ETH | class | one-line reason |
|---|---|---|---|---|
| `0xDd9fd6b6F8f7ea932997992bbE67EabB3e316f3C` | Last Winner | 2425.427564 | S | No working claim path. Prior zombie-deep verdict: only a probabilistic airdrop selector worth <=0.29 ETH total |
| `0x87ae4928f6582376a0489e9f70750334bbc2eb35` | ChickenChef | 0.0 | H-O | Stakers self-withdraw staked WETH via emergencyWithdraw(0) or withdraw(0,amount); no non-staker path. |
| `0x4dac3e07316d2a31baabb252d89663dee8f76f09` | GovTreasurer | 0.0 | H-O | Stakers self-withdraw via withdraw(2,amount) (works). emergencyWithdraw(2) is broken and destructive: it zeroe |
| `0x07261a6e37adbfab11e6474bca54634c7782b195` | MysteryMan | 0.0 | H-O | Stakers self-withdraw staked WETH via emergencyWithdraw(0) or withdraw(0,amount). |
| `0xb60c12d2a4069d339f49943fc45df6785b436096` | MasterStar | 0.0 | H-O | Single staker self-withdraws 3.0 WETH via emergencyWithdraw(0) or withdraw(0,amount). Extra 0.1 WETH in contra |
| `0x0de845955e2bf089012f682fe9bc81dd5f11b372` | BDPMaster | 0.0 | H-O | Stakers self-withdraw staked WETH ONLY via emergencyWithdraw(1). withdraw/deposit/claimReward are BROKEN (reve |
| `0x9465A32618a9172b3c14d82cecdCa788dE1ef878` | P4RTY DAO Vault | 0.430478 | H-O | Stakers self-withdraw accrued ETH dividends via withdraw() (requires myDividends()>0). No unstake exists; P4RT |

### 1.1 MasterChef deep dive (the 5 farms)

All five are verified, standard MasterChef forks. Staking token is **WETH** (ERC-20 held by the contract); reward tokens are project tokens (minted or transferred), **not ETH/WETH**. For each contract the live WETH balance was matched **exactly** to the sum of `userInfo(pid, staker)` after enumerating every WETH-transfer counterparty:

| contract | pool (WETH) | live WETH | stakers | Σ userInfo | note |
|---|---|---|---|---|---|
| ChickenChef | 0 | 48.20481881476927 | 7 | 48.20481881476927 | `withdraw` works; `updatePool` no-ops (reward=0); future `2**parseHalving` wrap brick (≈block 32.0M) |
| GovTreasurer | 2 | 18.99736196605838 | 21 | 18.99736196605838 | `emergencyWithdraw(2)` is a destructive no-op (pays 0, wipes claim); `withdraw(2,·)` works |
| MysteryMan | 0 | 4.0 | 2 | 4.0 |  |
| MasterStar | 0 | 3.1 | 1 | 3.0 | 0.1 WETH surplus (donation) not credited to anyone; no sweep → stuck |
| BDPMaster | 1 | 1.743 | 8 | 1.743 | `withdraw`/`deposit`/`claimReward` revert; `emergencyWithdraw(1)` works |

**Can a non-staker extract?** No. Every value-moving function is keyed on `userInfo[_pid][msg.sender]`:
- `withdraw(pid,amount)` — `require(user.amount >= amount)`, pays own WETH + own pending reward.
- `emergencyWithdraw(pid)` — pays own WETH. A crafted/oversized pid reverts (`poolInfo[_pid]` OOB) or touches `userInfo[pid][attacker]` = 0.
- `deposit(pid,amount)` — `safeTransferFrom(msg.sender,…)`; cannot inflate `user.amount` without paying WETH.
- `updatePool` / `massUpdatePools` are permissionless but only move **reward accounting** (project tokens), never WETH.
- `add`/`set`/`migrate`/`tokenConvert` cannot move pool-0 WETH: `add`/`set` are `onlyOwner` and do not touch existing stakes; MasterStar `migrate(0)` reverts because `migratePoolAddrs(0)==0`; `tokenConvert` moves only the caller's own amount.
- No owner sweep/emergency function exists on any of the five.

**Specific findings (exact calls, block 26111147):**
1. **GovTreasurer `emergencyWithdraw(uint256)` is broken and destructive** — source zeroes `user.amount`/`rewardDebt` *before* `pool.token.safeTransfer(msg.sender, user.amount)`, so it transfers **0** and destroys the position. `cast call --from 0xBd786740… emergencyWithdraw(2)` returns success, but if mined it would pay 0 and wipe the user's 18.958 WETH claim. Safe path: `cast call --from 0xBd786740… withdraw(2, 1e18)` → success.
2. **BDPMaster `withdraw`/`deposit`/`claimReward` revert** — `updatePool` → `BDP.mint(address(this), reward)` reverts with `BDPToken: cannot mint for pool` because `seedPoolAmount()==0`. Verified: `cast call --from 0x20957291… withdraw(1,0.1e18)` → revert; `claimReward(1)` → revert; `deposit(1,0)` → revert. **Funds are NOT stranded**: `emergencyWithdraw(1)` (no `updatePool`) returns success and pays the full 1.743 WETH to its 8 stakers.
3. **ChickenChef future brick** — `_chickenHalving()` computes `2 ** parseHalving`; when `parseHalving>=256` (≈block 32.0M, ~2 years away) the exponent wraps to 0, `getChickenBlockReward()` divides by zero and `updatePool` reverts, bricking `withdraw`/`deposit`. `emergencyWithdraw` stays functional. Not actionable now.
4. **P4RTY DAO Vault** — 92 `onStake` addresses; `dividendsOf()` for the 54 with non-zero balances sums to `0.43047816840578185 ETH` == contract balance exactly. `withdraw()` self-only (`onlyDivis`), CEI-safe. No sweep; owner can only manage a whitelist; `reinvestByProxy` is `onlyWhitelisted` (no whitelisted address found among sampled accounts). Buying P4RTY and staking now yields **zero past dividends** (`payoutsTo_` is set to `profitPerShare_*amount` at stake).
5. **Last Winner** — live 2,425.427564 ETH (unchanged); selectors bytecode-identical to the index snapshot; prior zombie-deep verdict (only a probabilistic airdrop ≤0.29 ETH, negative EV) stands. No new surface.

## 2. Child/backing contract re-checks

| address | name | live ETH (block 26111147) | class | prior / note |
|---|---|---|---|---|
| `0xbf4ed7b27f1d666546e30d74d50d173d20bca754` | The DAO WithdrawDAO | 81399.811926 | H-O | Live balance unchanged vs index. Prior $0 for unprivileged attacker - cited, not re-litigated. |
| `0x23ea10cc1e6ebdb499d24e45369a35f43627062f` | DigixDAO Acid | 11681.827614 | H-O | Live balance unchanged. Cited prior. |
| `0x707f9118e33a9b8998bea41dd0d46f38bb963fc8` | Lido bETH | 0.0 | H-O | H-O with race: claims (1013.43 bETH) exceed assets (745.47 stETH). Holder-only; no non-holder entry without market. Cited prior +  |
| `0xa2f987a546d4cd1c607ee8141276876c26b72bdf` | Lido AnchorVault | 0.0 | H-O | Backing contract of bETH entry; same shortfall race. No E-U. |
| `0x3dfd23a6c5e8bbcfc9581d2e864a68feb6a076d3` | Aave v1 LendingPoolCore | 926.001454 | H-O | Live balance ~unchanged. Cited prior. |
| `0x1e0447b19bb6ecfdae1e4ae1694b0c3659614e4e` | dYdX Solo Margin | 0.0 | S | Cited prior; live balance 0. No new surface. |
| `0x0a14b696350546110a0d8acdb86226983af9d2a0` | zkSync Lite L1 exit | 10775.085193 | H-O | Balance declined by ~151.6 ETH since index scan - consistent with users self-exiting; no unprivileged path. Cited prior. |

zkSync Lite L1 exit: 10,775.085 ETH now vs 10,926.66 at prior scan (−151.6 ETH of legitimate self-claims) — cited prior $0, claims self-only.

## 3. Unassigned 37 (created `unassigned.json`)

| address | name | live ETH | class | reason |
|---|---|---|---|---|
| `0x347e3513ca6d5118cb2df3bc386eade1e8f25ceb` | SAW Games Pass | 0.0 | S | NFT contract; mint ETH was withdrawn by owner (withdraw() onlyOwner). No claimable value. |
| `0xf61a285edf078536a410a5fbc28013f9660e54a8` | TradexOne | 0.47122565 | H-O | EtherDelta fork: depositors withdraw their own recorded balance via withdraw(amount)/withdrawToken(). |
| `0xe8fff15bb5e14095bfdfa8bb85d83cc900c23c56` | Afrodex | 0.4517076590505233 | H-O | EtherDelta fork: depositors withdraw their own recorded balance via withdraw(amount)/withdrawToken(). |
| `0x96a4ed03206667017777f010dea4445823acb0fc` | P4D | 1e-18 | S | Mapped 7.64 ETH is PHANTOM: contract holds 1 wei. withdrawSubdivs()/withdrawSubdivsAmount() revert (INVALID) f |
| `0xdea2bc436d38d4f8ee6f9e63b63b72a399c24e2c` | VLB / Lino | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x7c33f3d417ef65a5299998bf7bbd35921963336c` | Friend Network Token | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xd005c3dccd6e7056883dc612770021bc09837098` | Global ICO Token (GLIF) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xb8f1437c742dc042af73d5bd18c8fc985ec8e3b4` | CryptoHunt (CH) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x12c33d513d4534e6cb5dc06c56683be52a936d24` | Alttradex (ATXT) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xc49e03bdd6809fd168565b26d27d5cf72f9e9525` | Etcetera (ERA) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xda3fa12b3d41cd9948db6437f27c0c9978c55cbb` | Enkronos Token (ENK) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x6e776e93291620dac8f3dde4a0b98c42a5359293` | DeskBell (DBT) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xc86554bee96fdb3c85f85b576ed52d5e1eacc3a6` | Quintessence (QST) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xcb7f070fda083e8e5f40559376c360f0709e985c` | Deck Coin (DEK) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x5e6a22ef928d09e9159737393ca155e9eb021d54` | Tokpie (TKP) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x05711090b4d375431e841ea79e52666f623d3353` | GlobalSpy (SPY) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x2f4330e833c76860ea54f15b0195ff80a2c519c4` | BigToken (BTK) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x3448295659daad4c834e5ce1c18c4e4ef73c7f06` | WINiota (WIT) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xea864a114c648eff4f92e55b870fe1e71fd60083` | Grapevine (GVINE) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x269b4c23ddab676e2869ae72cd6ae4f24bdfea45` | IRB Tokens (IRB) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xa785ecdc8f166d0644b853f29732ae128c5d775b` | CamToken (CAM) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x8519f68a987048b879bed6afab25a0414828c236` | LINDA Token (Presale) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xfcbc3a54c5663295d075b086441ee51c32ad152c` | LINDA Token (Main Sale) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x65320b9aeac77e45369e4892da896b7a987a97f3` | Monoreto (MNR) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x79c59c24465fc3cc92e6419d4b59fdd285d874cf` | Unverified ICO Refund (79c5) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xf36358e9c7f6bf26d9cff44f95bf9521fc3feed4` | TREECHAIN NETWORK (TREECOIN) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x3adf5ee8777f471407e04a7453133477a2dc0c2c` | Lendsbay Token (LBT) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xf563549daf64f684858e863e2731f19633d1acb1` | FURT COIN (FRT) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x09b8aaa7a883e60c23c6a0635940000c6e2e7560` | Kryptopy Token (KPY) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x9527551ca444f6e5d9a0b281116586427366862a` | DigitizeCoin Presale (DTZ) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0x77b275827eb3cf1792852b128a6dbc7a699bbd91` | PallyCoin Fork (PAL2) | 0.0 | H-O | OZ RefundableCrowdsale: ETH sits in sibling RefundVault (state=Refunding). Original depositors self-claim via  |
| `0xb9ed94c6d594b2517c4296e24a8c517ff133fb6d` | Hegic V1 Call | 0.0 | H-O | LP tranche owners (ERC-721) withdraw principal via withdraw(trancheID)/withdrawWithoutHedge(trancheID). unlock |
| `0xb1236770ed9015e331c021347e005b00c8b8a01b` | Kitten Finance | 0.0 | H-O | Stakers exit own WETH via withdraw(amount)/exit() (Synthetix StakingRewards); owner renounced. |
| `0x4d9629e80118082b939e3d59e69c82a2ec08b4d5` | Tribe Redeemer | 0.0 | H-O | TRIBE holders call redeem(to, amountIn): transfer TRIBE in, receive pro-rata basket [stETH, LQTY, FOX, DAI]. r |
| `0x02c133b9fbffb8d2e8cb7b7a94c7c880b331c720` | Gro UST Compensation | 0.0 | H-O | Compensation beneficiaries claim via initialClaim(proof, amount) then claim() on a 2-year vesting schedule (en |
| `0x090D4613473dEE047c3f2706764f49E0821D256e` | Uniswap UNI Airdrop | 0.0 | H-O | UNI genesis MerkleDistributor: claim(index, account, amount, merkleProof) pays the leaf `account` (not msg.sen |
| `0x0c48250eb1f29491f1efbeec0261eb556f0973c7` | AimBot | 0.0 | H-O | AIMBOT holders claim own dividends via AimBot.claim() -> AimBotDividends.claim(msg.sender) -> pays withdrawabl |

### 3.1 Crowdsale RefundVaults (27 entries, the bulk of the unassigned set)
Every crowdsale still holds its ETH in a sibling **RefundVault** that is in **state=1 (Refunding)**, `isFinalized=true`, `goalReached=false`. Claim paths (verified source on `0x91BF99CA…` OZ RefundVault and `0x2CbC6812…` VLB vault):
- `crowdsale.claimRefund()` (public, selector `0xb5545a3c`) → `vault.refund(msg.sender)`, or
- `vault.refund(address investor)` (public, `0xfa89401a`) — pays `investor.transfer(deposited[investor])`.
A third party can trigger a refund for someone else, but **ETH always goes to the recorded depositor** — no redirect, no eligibility bypass. Total unclaimed: **115.954 ETH**. Classification H-O for all 27; the mapped amounts are real but depositor-only.

### 3.2 Notable H-O pools the index under-counted
| pool | backing | live amount | claim path (holder-only) |
|---|---|---|---|
| AimBot dividends (child of `0x0c4825…`) | `0x93314Ee69BF8F943504654f9a8ECed0071526439` | **67.4586 ETH** | `AimBot.claim()` → `AimBotDividends.claim(msg.sender)`; `withdrawDividend()` disabled; scan: 1,347/3,000 holders have positive `withdrawableDividendOf`, Σ=35.81 ETH in first 3,000 |
| Uniswap UNI airdrop | `0x090D4613…` | **12,499,565.7 UNI** | `claim(index, account, amount, proof)`; pays the leaf `account`, immutable root |
| Gro UST compensation | `0x02c133b9…` | **996,759 PWRD** (~$1M) | `initialClaim(proof, amount)` + `claim()`; `sweep` onlyOwner |
| Tribe Redeemer | `0x4d9629e8…` | stETH 3,141.1 / LQTY 59,969.7 / FOX 834,049.6 / DAI 1,788,335.6 | `redeem(to, amountIn)` — caller must transfer TRIBE in; pro-rata, `redeemBase` 24.99M |
| Lido bETH / AnchorVault | `0x707f9118…` / `0xa2f987a5…` | 745.468 stETH vs bETH supply 1,013.43 | bETH burners redeem pro-rata → ~26 % shortfall, first-mover race among bETH holders |

### 3.3 Index mapping error — P4D
`0x96a4ed03…` (P4D) is classified **S**: the mapped **7.6369 ETH is phantom**. Contract balance is **1 wei**; the only real backing is `P3D.dividendsOf(P4D)=0.0133 ETH`. `subdividendsOf()` sums to 83.7 ETH over just the top-50 holders (top holder 16.68 ETH), and `cast call --from 0xE2B9f5ca… withdrawSubdivs(false)` **reverts (invalid opcode)** because `lastContractBalance_` underflows. At most ~0.0133 ETH is physically claimable by a small-balance holder (first-mover). The 7.64 ETH should be removed from the index.

## 4. E-U candidates
**None.** No function in segment E, the children, or the unassigned 37 lets an unprivileged non-holder move contract value to itself. Near-misses examined and ruled out:
- Crowdsale `refund(investor)` is callable by anyone but pays the recorded depositor (no arbitrary recipient, `deposited` only set via owner-gated deposit).
- AimBot `updateBalance(address)` is public but only syncs dividend shares at the current `magnifiedDividendPerShare`, cancelling all past dividends — buying tokens now yields 0.
- P4D `withdrawSubdivs` is holder-only and reverts for any real claim.
- MasterChef `emergencyWithdraw`/`withdraw` are `msg.sender`-keyed; `migrate` paths are owner-configured and inert for the WETH pools.
- Merkle claims (UNI, Gro) verify proofs; payments cannot be redirected.
- Hegic `unlock(id)` is permissionless but only returns expired-option accounting to the pool.

## 5. Files
- `results.json` — 51 entries (7 seg-E + 7 children + 37 unassigned), KIT schema.
- `raw/` — saved verified sources (ChickenChef, GovTreasurer, MysteryMan, MasterStar, BDPMaster, P4RTYDaoVault, HegicCALL+HegicPool, KittenRewards, TribeRedeemer, GMerkleVestor, MerkleDistributor, AimBot+AimBotDividends, TradexOne, Afrodex, P4D, VLB crowdsale/vault, GLIF vault), Blockscout JSON, staker sets (`mc_userinfo.json`, `weth_pool_users*.json`), P4RTY stakers/dividends, AimBot holder scan, vault list.
