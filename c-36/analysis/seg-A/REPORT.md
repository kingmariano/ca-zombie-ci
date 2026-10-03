# seg-A REPORT — ICO crowdsales / refunds / presale pools / owner-action-required

Scope: 58 segment contracts + children/backing contracts requested by parent. Read-only; all balances measured at
block **26,111,133**; eth_call simulations at blocks **26,111,188–26,111,503**. Sources: Blockscout verified
source/ABI, selector resolution (4byte), GitHub template sources (SpankChain/old-sc_auction, thec00n PresalePool),
index balance files (`aaaaaaaaaaway/forgotten-eth` → `data/balances/*`).

**Bottom line: 0 E-U candidates found.** Every value-moving path in this segment is either (a) self-service to the
recorded holder/depositor (H-O, 54 entries), (b) beneficiary/owner-only (P, 5 entries), or (c) stuck (S, 3 entries).
The only permissionless triggers found (vault `refund(address)`, `endCrowdsale()`, `updateStage()`, `distributeLostFunds()`,
`forceRefund()`) all pay only the recorded holder — none can redirect value to the caller.

## Segment summary (live ETH @ 26,111,133)

| Address | Name | Live ETH | Class | One-line reason |
|---|---|---:|---|---|
| 0x4d1886da… | SpankChain Auction | 107.53 | H-O | `withdraw()` self-only (103/105 sims OK; 2 zero-balance); auction success, unspent deposits fully backed |
| 0xf058ee35… | Presale Pool (LINO/HEALP/Bulleon) | 91.23 | H-O | `withdraw()` self-only; 64/65 OK (90.93 ETH); 0.3 ETH stuck for a contract rejecting 2300-gas send |
| 0xcc89405e… | Status Buyer | 76.60 | H-O | `withdraw()` self-only pro-rata (14/14 OK); 1.63 ETH stale `bounty` slice stuck |
| 0x48c128ea… | Presale Pool 0x48c128 | 98.48 | H-O | `withdrawAll()` self-only; 7/7 OK |
| 0xff2c689c… | Presale Pool 0xff2c68 | 50.00 | H-O | `withdrawAll()` self-only; 1/1 OK |
| 0xb9906cf5… | Presale Pool 0xb9906c | 2.50 | H-O | `withdrawAll()` self-only; 2/2 OK |
| 0xd6770aac… | Presale Pool 0xd6770a | 36.92 | H-O | `withdrawAll()` self-only; 23/23 OK |
| 0x796dbc51… | Presale Pool 0x796dbc | 35.00 | H-O | `withdrawAll()` self-only; 3/3 OK |
| 0x50c19ffd… | Presale Pool 0x50c19f | 34.31 | H-O | `withdrawAll()` self-only; 2/2 OK |
| 0x6f40d967… | Presale Pool 0x6f40d9 | 27.72 | H-O | `withdrawAll()` self-only; 283/283 OK |
| 0xe9426198… | Ambassadors Fund | 17.51 | H-O | `release(address)` requires `msg.sender==account`; 11/11 share-holders OK |
| 0x344285b2… | JustHodlIt | 18.17 | H-O | Ponzi; `withdrawAll()/withdrawDividends()` self-only; `distributeLostFunds` credits depositors only |
| 0xa812137e… | Contribution Pool | 10.61 | **P** | `withdraw()` is `onlyBeneficiary`; **no contributor refund exists** (index claim note is wrong) |
| 0xb59a226a… | Neufund EtherToken v1 | 3385.43 | H-O | WETH-style, `totalSupply == balance`; prior $0 confirmed |
| 0x0b7dc5a4… | Neufund EtherToken v2 | 375.68 | H-O | WETH-style, `totalSupply == balance`; +285.6 gap = LockedAccount v2 (229.83) + other holders |
| 0x899f9a04… | Delphi RedemptionContract | 205.84 | H-O | `redeemTokens` self-only (approve+burn); capacity 496k of 10M DEL → race |
| 0xb1e4675f… | Neufund LockedAccount v1 | 0.00 | H-O | 0 ETH; holds ETH-T claims; `unlock()` self-only; lockState=2 |
| 0xd76b5c2a… | Bancor Old ETH Token | 94.42 | H-O | `totalSupply == balance`; 10.2 ETH stuck for 2 contracts rejecting 2300-gas send (incl. BNT token) |
| 0x2956356c… | Maker W-ETH | 169.06 | H-O | WETH-style; 39/40 sample withdraws OK |
| 0xecf8f87f… | Old WETH | 1511.35 | H-O | WETH-style; `totalSupply == balance`; full-balance withdraws OK |
| 0xe0b7927c… | DigixDAO (DGD token) | 25.38 | **S** | No ETH-moving function; 25.38 ETH is unsolicited dust; mint/setOwner owner-only |
| 0xe9778e69… | NuCypher WorkLock | 103.69 | H-O | `refund()` self-only (43/48 OK); other 5 can `claim()` first (verified) → all recoverable |
| 0xbb9bc244… | The DAO (token) | 0.0006 | **S** | Token dust; unapproved `transferFrom` reverts (verified); value in WithdrawDAO |
| 0x575cb87a… | Ahoolee Token Sale | 191.11 | H-O | `refund()` self-only; fully backed (581.115−390.006); 3.86 ETH stuck for 2 contract depositors |
| 0xcd806502… | TruckHash Token Sale | 45.14 | H-O | `refund()` self-only; 27/29 OK; **31.64 ETH stuck** for a presale-pool contract (0x8798bd47) rejecting 2300-gas sends |
| 0xb3b33f59… | Jincor Token ICO | 19.06 | H-O | `refund()` self-only; 48/48 OK |
| 0x3fd30f3e… | AgroTechFarm Crowdsale | 16.69 | H-O | `refund()` self-only; state Refunding; 12/12 OK |
| 0x18777aec… | Luckchemy Crowdsale | 10.77 | H-O | `refund()` self-only; 23/23 OK; `forwardFunds` owner-gated+unmet |
| 0x9fa8fa61… | HONG | 727.97 | H-O | `refundMyIcoInvestment()` self-only; **all 43 remaining holders simulate OK**; balance == outstanding claims |
| 0xd7e011ad… | VLB Token (crowdsale) | 0.00 | H-O | value in vault 0x93519cc1 (81.14); claimRefund 55/55 |
| 0x5113309c… | Trend (TND) | 0.00 | H-O | value in vault 0x71929118 (27.23); claimRefund 33/33 |
| 0xb4f10530… | PallyCoin (PAL) | 0.00 | H-O | value in vault 0x75922986 (26.11); vault `refund(address)` bypasses PAL gate (44/44) |
| 0x943e99d9… | ForegroundTokenSale (DEAL) | 12.15 | H-O | `claimRefund()` self-only; state Refunding |
| 0xcba6f10d… | VuePayTokenSale (VUP) | 1.21 | H-O | `claimRefund()` self-only; **owner race**: `withdrawFunds()` (owner) can drain first |
| 0xf8f6e626… | PresalePool 2018 | 39.20 | H-O | `withdrawAll()` self-only; 10/10 OK |
| 0x9aca6abf… | DigiPulse Token Sale (DGT) | 100.58 | H-O | `refundEther()` self-only; 79/79 OK |
| 0x12d5b7c2… | DirectCrypt Token Presale | 81.89 | H-O | `refund()` self-only; 32/32 OK; fully backed |
| 0x3a8a9712… | QCOToken ICO | 31.45 | H-O | `requestRefund()` self-only; state Aborted; 56/56 OK |
| 0x1bb28e79… | hodlEthereum | 21.53 | H-O | `party()` self-only; 10/10 OK |
| 0x9ea80e20… | Blocklancer Token Sale | 21.66 | H-O | `refund()` self-only; 28/28 OK |
| 0xaf7aea24… | ZeroTraffic Crowdsale | 21.17 | H-O | `refund()` self-only; **`endCrowdsale()` permissionless** unlock (verified) |
| 0xe4972421… | Abyss DAICO Fund | 9.90 | H-O | `refundCrowdsaleContributor()` self-only; 13/13 OK |
| 0xe8b1b40f… | Bayesin CrowSale | 5.43 | H-O | `safeWithdrawal()` self-only; 5/5 OK |
| 0x17681500… | Confideal Campaign | 8.63 | H-O | `withdrawRefund()` self-only; stage Failure; **owner `reclaimEther()` sweep risk** |
| 0x4363b5d6… | Crowdsale 0x4363b5 | 8.48 | H-O | `releaseEthers()` self-only; 6/6 OK |
| 0xc699d906… | Crowdsale 0xc699d9 | 2.32 | H-O | `refund()` self-only; 6/6 OK |
| 0xe8205644… | Crowdsale 0xe82056 | 2.41 | H-O | `safeWithdrawal()` self-only; 9/9 OK |
| 0x6f303642… | CrowdsaleWatch | 2.00 | H-O | `safeWithdrawal()` self-only; 1/1 OK |
| 0x3091d37e… | Gateway ICO | 1.41 | H-O | `refund()` self-only; 8/8 OK |
| 0xa8df33a4… | I2 Presale | 5.80 | H-O | `safeWithdrawal()` self-only; 9/9 OK |
| 0xe117bb9d… | Mahala Coin Crowdsale | 2.95 | H-O | `refund()` self-only; 7/7 OK |
| 0xde0b79f5… | Reservation2 | 1.90 | H-O | `withdraw()` self-only; 1/1 OK |
| 0x6feaf4e8… | SingularDTV Launch | 1.02 | H-O | `withdrawContribution()` self-only (needs `sentTokens` approval); 2-step claim |
| 0xe8da050c… | Start Mining Token Sale | 5.98 | H-O | `manualRefund()` self-only; 16/16 OK |
| 0xc213f258… | Transit Finance Refund | 160.75 | **P** | claim paused; owner must `setClaim(false,0)`; PRIOR $0 confirmed |
| 0xaf5fc452… | RemovePutinBounty | 100.12 | **P** | state Initial; `cancel()` owner-only (Gnosis Safe); `redeem()` blocked |
| 0x5535a725… | PembiCoinICO | 69.24 | **P** | state Idle; `setFailed()` owner-only (EOA owner); `refund()` blocked |
| 0x93d812bf… | Circles RefundVault | 24.10 | **P** | vault Active; crowdsale `finalize()` owner-only (EOA); then vault refunds open |

Children/backing verified: WithdrawDAO `0xbf4ed7b2` (81,399.81 H-O), Acid `0x23ea10cc` (11,681.83 H-O/race),
Neufund LockedAccount v2 `0xea4df6f4` (229.83 ETH-T, H-O), FeeDisbursal `0x26b7deda` (0 ETH, S),
VLB/Trend/Pally vaults (81.14/27.23/26.11, H-O).

## E-U candidates

**None.** Near-misses examined and rejected:

- **HONG overflow** (`mgmtIssueBountyToken`): the May-2026 rescue mechanism is an integer overflow in an
  `onlyManagementBody` admin function (managementBodyAddress `0xb79ab599…` is a contract). Reproduced check:
  `mgmtIssueBountyToken(attacker, 2²⁵⁶−1)` from an attacker reverts (`invalid jump destination`). No public caller
  can reach it. The rescue left all 43 remaining holders unblocked and the contract exactly backed.
- **Acid burn()**: self-only (`balanceOf(msg.sender)`), SafeMath-checked, reentrancy-safe (DGD moved before ETH,
  re-entry sees balance 0). Owner has no withdraw function (only `init`). No bug — but see race below.
- **Vault `refund(address)`** (VLB/Trend/Pally): public but pays the argument address's own `deposited[]` entry.
  No parameter lets the caller redirect funds.
- **Permissionless state transitions**: ZeroTraffic `endCrowdsale()`, SingularDTV `timedTransitions/updateStage()`,
  I2 `checkGoalReached()`, DigiPulse `finalise()` — all only unlock self-refunds or no-op; none move ETH to caller.
- **AmbassadorsFund `release(IERC20,address)`**: no `msg.sender==account` check (unlike the ETH variant), but still
  pays only the payee's own share.
- **JustHodlIt `distributeLostFunds(address[])`**: permissionless; redistributes 90% of inactive deposits via
  `_profitPerShare` to all *depositors* pro-rata. A non-depositor gains nothing.

## Notable H-O races (fork-test candidates if the parent wants first-mover economics)

1. **DigixDAO Acid — 11,681.83 ETH, first-come-first-served.**
   `burn()` pays `balanceOf(msg.sender) × 193,054,178 wei` (0.193054178 ETH/DGD). Contract capacity =
   **60,510.6 DGD**, while DGD `totalSupply` = **2,000,000 DGD** → only ~3% of the supply can ever redeem.
   Burns are live (last 2026-10-01). The rate math has no overflow/rounding bug (`mul` is checked). Owner cannot
   withdraw. Whoever burns first wins; late burners revert on `address(this).balance >= _wei`. (If DGD trades below
   0.193 ETH anywhere, buying+burning is an arb — purchase-funded, not a contract exploit.)
2. **Delphi RedemptionContract — 205.84 ETH.** Fixed rate 2410 DEL/ETH; capacity ≈ 496,074 DEL vs 10,000,000 DEL
   supply → first-come-first-served. `redeemTokens` self-only (needs DEL approval). No owner withdrawal path.
3. **VuePay — 1.21 ETH owner/contributor race.** `allowRefund=1` and `minCapReached=1` simultaneously;
   `claimRefund()` (contributors) and `withdrawFunds()` (owner, requires `minCapReached`) draw from the same
   balance. Contributors win only if they claim before the owner sweeps.
4. **Confideal — 8.2 ETH.** Refunds are live in stage Failure, but owner `reclaimEther()` (`onlyOwner`) can sweep
   the whole balance at any time and brick refunds. Owner has not acted.
5. **PallyCoin PAL gate is bypassable** — the crowdsale's `claimRefund()` requires full PAL (9 holders fail), but
   the vault's public `refund(address)` paid 44/44 in simulation. Index's "2.7 ETH locked" is not a hard lock.

## Stuck / effectively lost (S components, no non-holder gain)

| Where | Amount | Why |
|---|---:|---|
| TruckHash Token Sale | **31.64 ETH** | owed to presale-pool contract `0x8798bd47…` (3678-byte pool) whose fallback cannot accept the 2300-gas `transfer`; `refund()` reverts. The pool is not in this index. |
| Bancor Old ETH Token | **10.20 ETH** | held by 2 contracts that reject 2300-gas sends: BNT token `0x1f573d6f…` (5.2) and `0xd42433a8…` (5.0) |
| Ahoolee Token Sale | **3.86 ETH** | two contract depositors (`0x1522900b…` 3.46, `0x4d955701…` 0.40) reject 2300-gas `send` |
| StatusBuyer | **1.63 ETH** | stale `bounty` storage: `buy()` already ran (and never clears the variable), so `withdraw()` subtracts it from the pool forever |
| Presale Pool LINO/HEALP/Bulleon | **0.30 ETH** | contract `0x1522900b…` rejects 2300-gas `send`; `retry(address)` requires `gateway.isWhitelisted()` and currently reverts |
| DigixDAO DGD token | **25.38 ETH** | no ETH-moving function exists on the token contract |

## Owner-action-required (state + exact transition the owner must execute)

- **Transit `0xc213f258`** — `claimPause()=true`, `claimStartTime=0x63403338`. Owner EOA `0x85769104…` must call
  `setClaim(false, 0)`; then `claim()` pays `refundAsset[msg.sender]`. Live 160.75 ETH, but the index only maps
  0.1122 ETH to a claimant ledger — the rest of the balance is unattributed. PRIOR $0 confirmed (no unprivileged path).
- **RemovePutinBounty `0xaf5fc452`** — state Initial. `cancel()` is `isOwner` where owner is a minimal proxy
  (`0x7ac476a3…`) delegating to Gnosis Safe 1.3.0 singleton `0xd9db270c…` (verified by disassembly: DELEGATECALL,
  `execTransaction` 0x6a761202 present). `cancelNoWinner()` requires state executed. `redeem()` needs cancelled.
  No permissionless unlock now.
- **PembiCoinICO `0x5535a725`** — state Idle. `setFailed()` `onlyOwner` (EOA `0xa977aadc…`); then `refund()` pays
  `amounts[msg.sender]`. If the owner key is lost, 69.24 ETH is stuck.
- **Circles RefundVault `0x93d812bf`** — vault state Active. Crowdsale `0x61db4c9d…` `finalize()` is `onlyOwner`
  (EOA `0xc928ea49…`); it calls `vault.enableRefunds()`. Afterwards vault `refund(address)` is public but pays the
  depositor. No permissionless unlock now.

## HONG deep-dive (parent-requested)

- Live 727.973843 ETH; state: `isFundLocked=0`, `isFundReleased=1` (failed ICO, Case D), `tokensCreated=350`,
  `bountyTokensCreated=52,716`.
- All-time inflow 3,936.4844 ETH − all-time successful `evRefund` 3,208.5106 ETH = **727.9738 ETH = live balance
  exactly**. No surplus, no shortfall.
- `refundMyIcoInvestment()` requires `weiGiven[msg.sender]>0`, `balances<=tokensCreated`, `!isFundLocked`; pays
  the caller's tracked `weiGiven`. All 43 remaining holders were simulated at block 26,111,193: **43/43 succeed**
  (their balances were reset to 1–200 by the rescue's overflow calls, unblocking the cap).
- The rescue (0xflorent, May 2026): 41 `evMgmtIssueBountyToken` calls with `_amount ≈ 2²⁵⁶ − X` wrapped each
  blocked holder's balance down, exploiting `bountyTokensCreated + _amount > maxBountyTokens` overflow in an
  admin-only function. That path is **not** reachable by an attacker (managementBody = contract `0xb79ab599…`).
- **What remains extractable and by whom: exactly 727.97 ETH, by the 43 original investors, each their own
  `weiGiven`, self-service, no race (100% backed).** No E-U.

## The DAO / WithdrawDAO (parent-requested)

- WithdrawDAO `0xbf4ed7b2` = **81,399.81 ETH**. Source (verified): `withdraw()` pays `mainDAO.balanceOf(msg.sender)`
  only, after `transferFrom(msg.sender, this, balance)`. **Independent abuse check:** `transferFrom(WithdrawDAO,
  attacker, 1)` with zero allowance reverts (`invalid jump destination`) → DAO token allowance is enforced; no
  non-holder path. `withdraw()` from a 0-balance address reverts. `trusteeWithdraw()` computes
  `(81,399.8e18 + 1.1457e25) − 1.1538e25` → negative → wraps → `send` of a huge value fails silently (eth_call
  returns success, no ETH moves). Holders must `approve(WithdrawDAO, balance)` first.
- **Other funded DAO-related contracts found (outside segment):**
  - `0x755cdba6ae4f479f7164792b318b2a06c759833b` **ExtraBalDaoWithdraw = 852.60 ETH live** (was 115k ETH in 2017).
    Disassembly shows the same self-only pattern: `withdraw()` reads `mainDAO.balanceOf(msg.sender)` (token
    `0x5c40ef6f…`), `transferFrom` + send; `clawback()` is trustee-only and the trustee is the White Hat Group's
    Gnosis-era multisig `0xda4a4626…` (selectors addOwner/confirm/execute → multisig). → H-O, not in this segment.
  - `0x807640a13483f8ac783c557fcdf27be11ea4ac7a` (TheDaoExtraBalance) = 0 ETH.
  - DarkDAO children `0x304a554a…` and `0xd4fe7bc3…` = 0 ETH (same bytecode as the DAO token, drained long ago).
- Index scan (2026-09-19) showed 81,479.79 ETH; ~80 ETH withdrawn since.

## Neufund +285.6 ETH gap (parent-requested)

`EtherToken v2` live 375.67913018062393 == `totalSupply` exactly (100% backed). The index "mapped" 90.05 counts
only directly-withdrawable holder balances; the gap is: **LockedAccount v2 holds 229.834 ETH-T** (tracked under the
Neufund LockedAccount entry) plus other holder wallets (e.g. `0xba6Db501…` 54.18, `0x045100Be…` 45.16). Every unit
is withdrawable only by its holder via `withdraw()`; `withdrawPrivate` has the balance check; `reclaim` cannot take
ETH. v1 same: `totalSupply == balance` (3,385.4289). Both prior $0 verdicts confirmed.

## Blockers / discrepancies for the parent

1. **Contribution Pool `0xa812137e`**: index says `withdraw()` returns "the full deposit" to contributors. Verified
   source contradicts this — `withdraw()` is `onlyBeneficiary` (EOA `0x4f84b365…`) and there is **no refund
   function**. Classified **P**. The mapped 10.61 ETH is not contributor-claimable.
2. **TruckHash**: 31.64 ETH (70% of balance) is owed to a presale-pool contract outside the index
   (`0x8798bd47…`); its recovery depends on that pool's own logic. Flag for a separate look.
3. **Presale Pool LINO/HEALP/Bulleon**: 0.3 ETH stuck on contract `0x1522900b…`; `retry()` is gateway-whitelist
   gated and currently reverts.
4. **DigixDAO/Delphi races**: if the parent wants to quantify extractable-by-anyone via market purchase, DGD/DEL
   liquidity and price must be checked externally (not verified here; no market data source in scope).
5. Parent's own `build_results.py`/`digest.py` were found in seg-A; left untouched. `results.json` here is the
   child's final artifact (65 entries: 58 segment + 7 children/related).
