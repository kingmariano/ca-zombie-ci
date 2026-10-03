# C-35 raw analysis notes

All reads at Ethereum mainnet block **26,108,927** (2026-10-03) unless a different block is stated.
Read-only: `eth_getBalance`, `eth_getCode`, `eth_call`, Etherscan V2, OpenChain 4byte. No transactions.

## 1. C-35 named targets

### 1.1 HongCoin 2016 ICO — `0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9`

| item | value |
|---|---|
| live ETH (26,108,927) | **727.9738432374239** |
| code | 10,451 B, verified source `hong_source.sol` (solc 0.3.5) |
| `tokensCreated()` | 350 |
| `managementBodyAddress()` | `0xb79Ab5993Cef2E0B714A66F3edA73b55DE812D31` — Gnosis `Wallet` multisig (verified source `hong_ms.sol`); unlock caller `0x1212ce5652b20c0a8ce493458a5c99db24ed2925` is an owner (`isOwner == true`) |
| `extraBalanceWallet()` | `0x034Cf4F8e828195C353A03aE00Ddcf137C424a05` |
| `isFundLocked()` | false (refunds enabled) |
| bug | `refundMyIcoInvestment()` requires `balances[msg.sender] <= tokensCreated`; decades of partial refunds dragged `tokensCreated` to 356, blocking large holders |
| whitehat unlock | 0xflorent disclosed `mgmtIssueBountyToken(address,uint256)` overflow path; team executed 41 unlock txs on **2026-05-27** (executor `0x1212ce…` → multisig `0xb79Ab5…` → HONG), resetting eligible holders' balances |
| current state | 46 eligible addresses (~905 ETH) can call `refundMyIcoInvestment()` (`0xe84f7054`); attacker call reverts (`throw`/INVALID) |
| evidence | `hong_unlock_txs.json` (52 txs from block 25,194,974), rentry.co/hongcoin-recovery-1873, tweet 2061070356564091258 |
| category | **H-O** (holder-only); **E-U $0** |

Holder dry-run: `eth_call refundMyIcoInvestment()` from `0x30d1f87561af86d5ab7b9ec04e65607fab61833d` returns success; from a fresh address reverts.
Fork test `test_03` executed it on a fork: holder gained exactly 0.07 ETH; HONG balance decreased.
Attacker `mgmtIssueBountyToken` reverts (onlyManagementBody); `refundMyIcoInvestment` reverts (no weiGiven).
The overflow cannot mint `weiGiven` for an attacker, and the admin function is behind the multisig (`execute` is `onlyowner`).

### 1.2 Liquality 2018 ICO + atomic-swap HTLCs (rescue 2026-05-24)

- Whitehat wallet (0xflorent): `0x0671DFFBC0A33C61B12585Bbd1b75B6fBDC45D2e`; txs at blocks **25,164,688–25,164,702** (`florent_wallet_txs.json`).
- Failed Jan-2018 ICO: `0xf8602dfa933a34d513e6e1aab3f3cc6861254d51` (5.141 ETH refunded; balance now 0; selector `0x2c2e312a`).
- 7 Liquality HTLC contracts (balance now all 0):

| # | contract | pre-rescue payout (Etherscan internal tx) |
|---|---|---|
| 1 | `0x65f8e16da4c980983391b737c38f4483d8a7cc63` | 6.67451218427928 ETH → `0x3a712cc4…` |
| 2 | `0x597f71db673813ad3a88414b1c16cdb42815f27e` | 6.4285922052 ETH → `0x3a712cc4…` |
| 3 | `0x623b7424cd449afa11f30fcdb1d13b2a70be3b7c` | 0.33162843973248 ETH → `0x3a712cc4…` |
| 4 | `0x491ef9d4f7de298bd211c18d7a814db61e2fbc40` | 0.2346399678843 ETH → `0x3a712cc4…` |
| 5 | `0x6fee36e265ccc282f2b27f384191121efbb05ca1` | 0.19895547185088 ETH → `0x3a712cc4…` |
| 6 | `0x8618c63a8be97825851b1b4269aeb4c66300f6d2` | 0.176665320216 ETH → `0x3a712cc4…` |
| 7 | `0xce6e31f8fcb9d458861a8d1ac95f4d33a797c1b6` | 0.14585361714 ETH → `0x3a712cc4…` |
| | total | **14.19084720630294 ETH** (all to `0x3a712cc47aeb0f20a7c9de157c05d74b11f172f5`) |

- The Jan-2018 ICO refund split 5.141 ETH to nine contributors (0.65 + 0.90101258 + 0.5 + 0.06 + 0.25 + 2.0 + 0.08 + 0.5 + 0.2), matching the tweet. Evidence: `liquality_rescue_internals.json`.

- Runtime (200–201 B) disassembled (`liquality_htlc1_disasm.txt`): sha256 of 32-byte calldata compared to a hardcoded secret → SELFDESTRUCT to hardcoded **claim beneficiary**; empty calldata + `block.timestamp > 0x6156d13c` → SELFDESTRUCT to hardcoded **refund beneficiary**. The caller is never the payee.
- Fork test `test_04`: replica of HTLC_1 runtime pays the hardcoded beneficiary 6.674 ETH, caller gains 0. All seven live contracts have 0 balance.
- Category: **H-O** (per-swap participant); **E-U $0**. No unprivileged path existed even pre-rescue — the trigger is permissionless but always pays the participant.

## 2. Focus contracts (not covered by zombie-deep)

### 2.1 FoMo3D Ultra — `0xab83d96de35bad6f234178fbb6507203488e9626` (466.116 ETH)
- Unverified, 22,888 B. Selector dispatch (72 PUSH4) matches F3D-family getters: `withdraw()`, `getPlayerVaults`, `getCurrentRoundInfo`, `round_`, `plyr_`, `airDropPot_`, `getTimeLeft`, `getBuyPrice`, `activate`, `iXKeys`, etc.
- Live: `rID_ = 11`, `airDropPot_ = 0.208443270385016504 ETH`, `getTimeLeft() = 0`, `activated_ = true`.
- forgotten-eth maps **130.90 ETH** to 163 per-holder balances (coverage 28.06%); the remaining ≈335 ETH sits in round/jackpot/community pots keyed to players (round `getCurrentRoundInfo` shows a large pot field; `getPlayerVaults(1)` shows 116.18 ETH for player 1).
- Fork test `test_05`: fresh EOA calling `withdraw/airdrop/potSwap/activate` + 4 unknown selectors gains **0**; contract balance unchanged.
- Category: **H-O / S** (players' vaults + pots); **E-U $0**.

### 2.2 CryptoCats v0/v1 — `0x9508008227b6b3391959334604677d60169ef540` (43.685 ETH)
- Unverified 12,006 B; selector scan maps the full v3-era API: `withdraw()`, `pendingWithdrawals(address)`, `getCat`, `buyCat`, `offerCatForSale`, `releaseCats`, `migrateCatOwnersFromPreviousContract`, `previousContractAddress`, …
- v3 changelog: "Bug fix to make ETH value sent in with `getCat` function withdrawable by contract owner." v0/v1 never got it → ~34.9 ETH of `getCat` ETH accumulated with **no credit and no sweep**.
- Fork test `test_07`: `pendingWithdrawals(attacker) == 0`; `withdraw()` is a no-op; contract balance unchanged.
- Category: **S** for the 34.9 ETH gap; mapped 8.81 ETH = **H-O**; **E-U $0**.

### 2.3 Transit Finance Refund — `0xc213f258f4142f53d086f9edb7a36e67eb347f63` (160.746 ETH)
- Verified. `claimPause() == true`, `claimStartTime() == 1665151800`, `owner() == 0x8576910497930B79A97A24DE1Acb0333399D0C55`, `executor() == 0x7e5c1595c4FE46Dc5b917A0597dc6008D498510b` (Gnosis Safe proxy, 345 B).
- `claim()` reverts "Refund suspended"; `emergencyWithdraw` is `onlyExecutor` and requires `claimPause` (so the executor Safe can sweep the 160.75 ETH while paused). `setRefunder` is `onlyExecutor`.
- Fork test `test_08`: attacker claim + emergencyWithdraw both revert.
- Category: **P** (owner unlocks claims / executor Safe sweep); after unlock = H-O; **E-U $0**.

### 2.4 Zethr + Zethr Casino — `0xd48b…` (276.744) / `0xb9ab…` (111.684)
- Verified P3D-style (`exit()`, `withdraw(address)` pays caller's own dividends/referrals, `sell()`, `reinvest()`, bankroll/dividend-rate bookkeeping).
- Fork test `test_09`: fresh attacker calls `withdraw()/withdraw(address)/exit()` on both; 0 successes, 0 ETH gained, balances unchanged.
- The +137/+38 ETH "gaps" vs the index are unmapped bankroll/`currentEthInvested`/mask accounting, not attacker-reachable.
- Category: **H-O** (holders) + **S** (unmapped bankroll); **E-U $0**.

### 2.5 Bingo4Beast deploy 2 — `0x4fb7d68e0116f35ade131b6535b2db1027bf7650` (84.483 ETH)
- Unverified 23,974 B. Selectors: `withdraw()`, `getGameInfo()`, `getStonePrice()`, `buyStone(uint256)`, `game_`, `player_`, `gID_`, `getTimeLeft`, `activate` — a F3D-"stones" variant with round-mask accounting.
- Index: "partially insolvent: round-mask accounting that exceeds the contract's actual balance" (519 holders).
- Fork test `test_12`: `withdraw()` from a fresh address reverts "withdraw fail"; balance unchanged.
- Category: **H-O race** (players, first-mover) / **S**; **E-U $0**.

### 2.6 DailyDivs / ReadyPlayerONE — `0xd2bf…` (109.684) / `0x6db9…` (24.539)
- Verified P3D/F3D forks with `isHuman` (`tx.origin == msg.sender`) and `notContract` modifiers; `withdraw()` pays caller's own dividends/vaults.
- Fork test `test_10`: DailyDivs withdraw reverts; RPO withdraw/airdrop/potSwap succeed as no-ops; attacker gains 0; balances unchanged.
- Category: **H-O** (EOA holders only — contract wallets are bricked by `isHuman`); **E-U $0**.

### 2.7 FEG Wrapped ETH (fETH) — `0xf786c34106762ab4eeb45a51b42a62470e9d5332` (386.601 ETH)
- Verified fETH (solc 0.8.3). `totalSupply = 352.731135584312945722`; contract holds 386.601 ETH → over-backed by ~33.87 ETH.
- `withdraw(amt)` requires `balanceOf(msg.sender) >= amt`, pays `amt - 1%` ETH to the caller; `feesAccrued` (incl. the surplus) has **no redeem function**.
- **No Uniswap V2 fETH/WETH pair** (`getPair == 0`), so there is no market path to buy fETH below NAV and drain the surplus. Fork test `test_11`.
- Category: **H-O** (holders redeem 0.99 ETH/token) + **S** (~37 ETH surplus/fees); **E-U $0**.

### 2.8 FoMo3D Ultra clones / F3D-family
`LastWinner 0xdd9f…` (2,425.428, `airDropPot_ = 0.389`, `rID_ = 622`, timeLeft 0), `FoMo3Dshort_v2` (136.636), `Fomo3D_Quick` (84.140), `Fomo3D_Short` (76.253), `FoMoJP` (72.912), `Bingo4Beast Long` (120.196), `Fomo3D Long` (1,099.453). All share the F3D pattern: `withdraw()` pays the caller's own vaults; `airdrop()`/`potSwap()` require keys (gameplay). Fresh-attacker probes: 0 gain (`test_05`, `test_06`, `test_10`). Probabilistic airdrop shares ≤0.389 ETH, negative-EV. Category: **H-O**; **E-U $0**.

## 3. Top-15 live-ETH re-check (block 26,108,927)

| target | live ETH (2026-10-03) | prior (2026-09-29) | verdict | basis |
|---|---:|---:|---|---|
| IDEX v1 | 15,729.774 | 15,740.917 | H-O self-withdraw | zombie-deep + `test_14` fresh withdraw 0 gain |
| EtherDelta v2 | 15,168.575 | 15,168.725 | H-O | zombie-deep + `test_14` |
| zkSync Lite distributor | 10,926.756 | 11,189.818 | H-O (Merkle claimants) | zombie-deep root/authority work + `test_13` (paused=false, owner Safe) |
| Neufund EtherToken v1 | 3,385.429 | 3,385.429 | H-O | zombie-deep v1 fully backed |
| Unknown DEX 0x4d55 | 2,479.088 | 2,479.088 | H-O | zombie-deep recompile, forged calls revert + `test_14` |
| Last Winner 0xdd9f | 2,425.428 | 2,425.428 | H-O / probabilistic | §2.8 |
| PoWH3D | 2,041.018 | 2,042.524 | H-O (race) | zombie-deep |
| Old WETH | 1,511.347 | 1,512.069 | H-O | `totalSupply == balance` (fully backed) |
| Fomo3D Long | 1,099.453 | 1,100.102 | H-O | §2.8 + `test_06` |
| Ethfinex WrapperLockEth | 929.510 | 929.612 | H-O self-withdraw | zombie-deep |
| SingularX | 854.996 | 854.996 | H-O | zombie-deep EtherDelta fork |
| Augur v1 (delegator) | 762.065 | 762.065 | H-O (per-user claim paths) | forgotten-eth claim paths; proxy verified `Delegator` |
| 0x0 Rewards | 735.856 | 735.864 | H-O (Merkle, 70,687 recipients) | root/claim-only source `OxODashboardClaim` |
| HongCoin | 727.974 | 727.974 | H-O (46 investors) | §1.1 |
| GandhiJi | 658.881 | 658.881 | H-O | zombie-deep P3D clone |

Other re-checked: Aave v1 core 926.004 (holder-only tail, zombie-deep), FEG 386.601, Celer 382.975 (operator/owner), Rook 359.124, Neufund v2 375.679, SingularX Fund 385.424, MCDEX 555.235 (self-settle), OpenGSN 11.892.

## 4. Verdict

No live unprivileged-extractable path was found in any of the 50 targets. **Total E-U = $0** (ETH ≈ $2,695 at CoinDesk snapshot on 2026-10-01 — irrelevant since zero). The largest H-O pools are zkSync Lite (~10,927 ETH, actively claimed: −263 ETH in 4 days), Neufund v1 (3,385), IDEX/EtherDelta (~30,900 combined), and HongCoin (728, holder-only).
