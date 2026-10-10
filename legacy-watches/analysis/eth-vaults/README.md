# H2-09 deep-dive: **eth-vaults** group (Universe XYZ, Unslashed, JPEG'd, Mangrove)

Read-only analysis. All state read via public keyless RPCs and `eth_call` simulations only (no
transactions signed/sent). Blocks: **Ethereum 26161752–26162391**, **Blast 41414903**,
**Arbitrum 513528345** (Oct 2026). USD = DefiLlama `coins.llama.fi` unless noted.

Group headline: **no external-unprivileged (E-U) extraction found in any of the four protocols —
$0 proven.** One *new* finding: Unslashed custody is ~$2.6M larger than DefiLlama shows, sitting
frozen in a withdrawal contract. Mangrove's $4.19M "TVL" is **unbacked offer notional** (makers hold ~$17).

Raw dumps: `eth-vaults_unslashed.json`, `eth-vaults_universe-xyz.json`, `eth-vaults_jpegd.json`,
`eth-vaults_mangrove.json` (full live-offer dump).

---

## 1. Unslashed — report $4.03M / DefiLlama $3.70M — verdict: **E-U $0 (proven), H-O $3.70M, S $2.64M**

Unslashed staking = Enzyme fund + audited *Unslashed-Enzyme Bridge* (ChainSecurity 2021-05-12,
Avantgarde Finance) + an operator-driven withdrawal contract.

### Contracts (Ethereum)
| Role | Address | Notes |
|---|---|---|
| Fund "USF Fund I" (vault proxy) | `0x86fb84e92c1eedc245987d28a42e123202bd6701` | VaultLib `0x891dee…`, ComptrollerProxy `0xba4f4c8b…` (impl `0x03f7f3b8…`), FundDeployer `0x4f1c53f0…`, owner Safe `0xf5bE8b4C…` |
| Bridge proxy (EnzymeBridge) | `0xf465f01baa66e758ddc785497b52e42d42dd970a` | impl `0xf7583e62…` (unverified), ProxyAdmin `0x631c8209…` |
| Withdrawal contract | `0x6be7741d288066e9b38eebe0536340962486c8f8` | impl `0xd4f70e2d…`, admin = Timelock `0xbe91e407…` (2-day delay; Safe `0x659839c9…`) |
| USF token | `0xe0e05c43c097b0982db6c9d626c4eb9e95c3b9ce` | DefiLlama's "protocol address" is just the gov token |
| Investor/basket | `0x3b6c03b232f87aee2ea6561ec7bf080a7710d667` | bridge's whitelisted `investor`; holds 0.09 ETH dust |
| Enzyme fee reserve | `0xb7460593bd222e24a2bf4393aa6416bd373995e0` | 2.786 ENZF + 0.0798 stETH (Enzyme's, not Unslashed's) |

### Live state
- Vault holds **1483.749 stETH + 1.0895 WETH** (≈$3.70M); `calcGav()` = 1484.446 ETH;
  gross share value 1.168683; `sharesAreFreelyTransferable()` = **false**; shares action timelock 24 h.
- ENZF shares: totalSupply 1270.187; **bridge holds 1267.4008 (99.78 %)**, fee reserve 2.786.
- Bridge views: `getBalanceInEth()` = **2540.472 ETH** = vault share value + stETH held by the
  withdrawal contract (formula reverse-engineered from bytecode at 0x041a; matches on-chain within rebase).
  `totalWithdrawnBalance()` = 1010.390.
- **Withdrawal contract holds 1059.525 stETH ≈ $2.64M — NOT counted in DefiLlama's $3.70M.**

### Checks (all via `eth_call` simulations)
- (a) **Outsider cannot redeem**: `redeemSharesInKind(1 wei)` from a random address on the
  ComptrollerProxy → `ERC20: burn amount exceeds balance` (shares are burned from `msg.sender`; source
  `ComptrollerLib.__redeemSharesSetup` confirms `canonicalSender = msg.sender`). Same call **from the
  bridge** (share owner) → **succeeds** (payout arrays returned). `transferFrom` of the bridge's shares
  by an outsider → `Rule evaluated to false: ALLOWED_SHARES_TRANSFER_RECIPIENTS`.
- (b) All 4 mutating bridge functions are gated: `309166fc`/`4c5d8bd2` = *"only investor"*;
  `2c15377c`/`d296cb1d` = *"only registry"* (`0x10a6354f…`, the team's upgradeable ops/ProxyAdmin).
  Impersonation tests: `d296cb1d` only succeeds from `0x10a6354f…`.
- (c) Leftovers: bridge 0 stETH/0 ETH, USF 0, timelock 0, investor 0.09 ETH dust. All value is in the
  vault + withdrawal contract.
- (d) No shutdown; owner = Safe `0xf5bE…`; the vault is share-owner-scoped (Enzyme).

### The $2.64M frozen pot
`0x6be7741d…` was funded Dec 2024 with 1010.39 stETH redeemed out of the vault via
`d296cb1d` (ops, timelock + ProxyAdmin hot-swapping impls; multiSend txs decoded).
`userWithdrawal()` (`0xbd68b8ca`) is gated by `registry[msg.sender]` (mapping slot 5) — **empty for
everyone now** (incl. the last withdrawer `0x551f6dd1…`), so **no one can withdraw**; all other mutating
functions revert `Caller is not the admin`. Last user withdrawal: 2024-12-24 (0.1858 stETH).

**Verdict:** E-U **$0**; H-O **$3.70M** (bridge-mediated, ops-executed redemptions); **S/stuck $2.64M**
(operator-recoverable only). Total custody ≈ **$6.34M**. Confidence **high**.

---

## 2. Universe XYZ — report $3.33M / DefiLlama $3.24M — verdict: **E-U $0, H-O $3.24M**

- Farm = BarnBridge-style `Staking` `0x2d615795a8bdb804541C69798F13331126BA0c09` (weekly epochs).
  Holds users' deposits: **18,428.37 AAVE ($3.18M)**, 1,271.42 LINK, 3,634.91 SUSHI, 2,480.02 BOND,
  1,881.19 SNX, 46.47 COMP, 23.52 ILV ≈ **$3.24M** (verified on-chain; matches DefiLlama).
- `withdraw(token,amount)` requires `balances[msg.sender] >= amount` → holder-scoped
  (random caller → `Staking: balance too small`). `emergencyWithdraw` requires caller's balance > 0
  (+10 epochs) → holder-scoped. `manualEpochInit` is public but moves no tokens.
- Reward farms (YieldFarm/YieldFarmLP, XYZ token `0x618679df…`) pay only per-caller epoch stake;
  no unguarded claim found. **XYZ is near-worthless**: Sushi XYZ/USDC pair = 32.25M XYZ / $4,069 →
  **$0.000126** (no DefiLlama price).
- **Verdict:** users' stakes remain withdrawable by stakers (H-O); E-U **$0**. Confidence high.

---

## 3. JPEG'd — report $572k / DefiLlama $567k — verdict: **E-U $0, H-O ~$35k**

- Where the money is: **not** protocol-owned. DefiLlama's $529k is the ETH side of the pETH/ETH Curve
  pool `0x1c5f80b6…` (212.156 WETH + 174.059 pETH) — **third-party LP liquidity**, not JPEG'd custody.
  The rest is NFT collateral in vaults (~$35k) + tiny PUSd.
- **Zero debt everywhere**: all 16 PUSd vaults `totalPositions=0`; the only open positions are
  BAYC_PETH (1 BAYC, id 6582) and PUDGY_PETH (3 Pudgy, ids 6322/1808/215) — all `debtPrincipal=0`,
  `isLiquidatable=false`. `totalDebtAmount()=0` for all vaults.
- `liquidate()` is external but `_liquidate` does `_checkRole(LIQUIDATOR_ROLE, msg.sender)` —
  role granted only to two ops addresses (`0xdca76348…`, `0xbaa11401…`) → **not permissionless (P)**.
  (Moot anyway: nothing is liquidatable.)
- `repurchase`/`closePosition` are position-owner scoped; oracle (`nftValueProvider`) irrelevant with
  no debt. PUSd `0x466a756e…0a54`: supply 7,000, ~$0.97 on its Curve pool (~$7k total).
- **Verdict:** E-U **$0**; H-O ~$35k (owners can close their zero-debt positions). Confidence high.

---

## 4. Mangrove — report $4.19M / DefiLlama $4.24M — verdict: **E-U ≈ $0; TVL is unbacked notional**

Chains: **Blast + Arbitrum** (no live Polygon deployment). Mgv Blast `0xb1a49C54192Ea59B233200eA38aB56650Dfb448C`,
reader `0x26fD9643…`; reader `0x7E108d7C…` on Arbitrum. 6 markets / ~35 live offers enumerated
(`eth-vaults_mangrove.json`).

**Key finding:** DefiLlama's adapter sums each offer's `gives` — i.e. *promised* liquidity. Mangrove
requires no token backing to post an offer (only a gas provision). The dominant maker
`0xac1ce7f65c2312b828260d959d2b95b7f5ff480e` currently holds **~$17 total** (0.0064 WETH, 0.397 USDB,
0.197 USDe, 6,773 BLAST) while its offers promise ~$4.2M. Offers were last repriced **2024-10-04**
(USDB/USDe) and **2025-04-01** (BLAST/WETH); no takes on the main USDB/USDe lists since 2024-11 (last WETH/BLAST take 2025-04-01); 0 `OfferFail` events.

Offer-by-offer (vs real Thruster CL pool prices, read on-chain):

| Offers | Face value | Offer price | Market (pool) | Takeable? |
|---|---|---|---|---|
| (USDe→USDB) ids 29–34 | 2,091,000 USDe | 1.0026–1.0052 USDB/USDe | 1.00407 USDB/USDe | only ids 29–31 (598k) below pool; edge 0.05–0.15 % < slippage ≈0.5 % → **~$0** |
| (WETH→BLAST) ids 1–6 | 14.86 WETH | 602k–648k BLAST/WETH | 71.06M BLAST/WETH | nominal **+$35k**, but maker cannot source WETH (would need ~180M BLAST) → takes **fail**, bounty 0.00000225 ETH/offer |
| (USDB→USDe) ids 37–42 | 2,096,293 USDB | 1.0–1.0027 USDe/USDB | 0.99595 USDe/USDB | loss for taker → untakeable |
| (BLAST→WETH/USDB) | 10M BLAST / 305k BLAST | 3.8e-6–5.3e-6 WETH/BLAST; 0.018–0.020 USDB/BLAST | BLAST ≈ $0.000035 | asks 10–25× market → untakeable |
| Morpho vault token ↔ WETH | ~14 WETH-equiv | near vault share value | fair | no edge |

- Provision bounties for failing takes: `getProvision` = 6.75e12 / 2.25e12 wei (sub-cent). The Mgv's
  5.61 ETH balance is accumulated maker provisions/fees, not user funds.
- Arbitrum: 10 USDT0/USDC offers ≈ 38,728 USDT0 at 1.0003–1.0012 (fair), maker `0xd77ab271…`.

**Verdict:** E-U ≈ **$0** (the headline $4.19M is offer notional, not custody; maker inventory ~$17).
Confidence high for Blast.

---

## Evidence index
- `eth-vaults_unslashed.json` — addresses, blocks, share-holder table, guard/simulation results.
- `eth-vaults_universe-xyz.json` — staking balances, guards, XYZ price derivation.
- `eth-vaults_jpegd.json` — vault/position/debt/oracle/role data, "where is the money".
- `eth-vaults_mangrove.json` — full live-offer dump (both chains) + mispricing analysis + pool prices.
- Source refs: Enzyme ComptrollerLib (Etherscan verified), BarnBridge-style Staking (verified),
  NFTVault v0.8.4 (verified), Mangrove `MgvReader.sol`/`TickLib.sol` (mangrove-core develop),
  ChainSecurity Unslashed-Enzyme Bridge audit (2021-05-12).

## CI
- `ci/steps/vaults_mangrove_offers.py` — re-enumerates Mangrove offers on Blast + Arbitrum with
  public RPCs (no keys), recomputes prices/provisions, writes `ci-out/vaults_mangrove_offers.json`.
  Run via the parent's serialized `ci/run.sh`.
