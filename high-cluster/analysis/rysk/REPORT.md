# Rysk V12 — Deep-Dive Dossier (H2-02 high-cluster)

**Status: read-only investigation. No mainnet transaction was ever signed or sent. All PoC execution ran on
forks of live chain state inside GitHub Actions CI. No secrets in this folder.**

- Target: **Rysk V12** — on-chain covered calls / cash-secured puts with RFQ auction.
- Chains: **HyperEVM (chain id 999)** and **Ethereum mainnet (chain id 1)**.
- Live value (snapshot 2026-10-10, blocks HYPE 48,180,034 / ETH 26,162,991): **≈ $36.62M** across the
  MarginPools + MMarkets, plus **≈ $0.76M** accumulated protocol fees in the fee-recipient Safe.
- DefiLlama `rysk-v12` ($35.25M at `2026-10-10T05:48Z`): **reconciled** — the brief's $15.7M only counted
  stablecoin balances; the remainder is non-stable collateral (WHYPE/kHYPE/UBTC/UETH/USOL/wstHYPE on
  HyperEVM; WBTC/WETH/wstETH/rETH/XAUt on Ethereum) plus MMarket balances. Same contracts, same sums.
- Source: **verified on Etherscan V2 for both chains** (proxies + implementations). The finding's
  "unverified source" claim is wrong. Evidence: `evidence/contract-inventory.json`, `sources/`.
- Owner: **Gnosis Safe 1.4.1, 3-of-5**, `0xAFE32eB89391DFd5900F98857f009477e4423Db4`, same 5 signers on
  both chains, no modules (guard storage slots 6–10 read zero on both chains), nonces 133 (HYPE) / 9 (ETH).
  Signers (public info): `0xAb855506f89DbeB7923fcF45f6585A3A9dBB4251`, `0xa0e5aF7b60BFc291E67B447eEA487555BbCeA835`,
  `0x92D97F86aFa95D16405e7210ab55581bB3BD1276`, `0x030E9cBD88258eAEc2AAc0FE550F1fF8622376F2`,
  `0xd390F33c230C202Ce2A3721F012eCDd8a8470415`.
- Headline: **E-U = $0** (high confidence). No unprivileged extraction path exists today. The pools are
  fully custody-gated to a hot operator EOA + a 3-of-5 Safe (P), and user self-service is disabled.

---

## 1. Contracts, roles, upgrade paths (live reads)

All addresses below were re-verified on-chain at the snapshot blocks. Every proxy's implementation was read
from storage and its source pulled from Etherscan V2 (chainid 999 / 1). Full machine-readable table:
`evidence/contract-inventory.json`.

### HyperEVM (999)

| Contract | Address | Kind / impl | Owner / role gates |
|---|---|---|---|
| MarginPool | `0x24a44f1dc25540c62c1196FfC297dFC951C91aB4` | ZOS `OwnedUpgradeabilityProxy` → `0x14907e5f…` `MarginPool` (verified) | proxy owner = AddressBook; `owner()` = Safe; `farmer()` = 0x0 |
| Rysk (RFQ processor) | `0x8C8bcb6D2c0E31c5789253EcC8431cA6209B4E35` | `TransparentUpgradeableProxy` → `0x19f1e313…` `RyskHype` (verified) | admin = `0x88960cff…` (OZ ProxyAdmin, owner = Safe); `owner()` = Safe; `operator()` = `0x65802CC3…` (EOA); `selfServiceAllowed()` = **false** |
| MMarket | `0x691a5fc3a81a144e36c6C4fBCa1fC82843c80d0d` | `TransparentUpgradeableProxy` → `0x3d9cb5d2…` `MMarket` (verified) | admin = `0x1b2ba667…` (ProxyAdmin, owner = Safe); `operator()` = Rysk (only caller of `operate()`) |
| AddressBook | `0xFfCE2d20e0f68dcEDbCE657175684845f9593f34` | verified, `owner()` = Safe | holds controller/factory/oracle/whitelist/calculator pointers; owns MarginPool + Controller proxies |
| Controller (Gamma) | `0x84d84e481B49B8Bc5a55f17AaF8181c21A29B212` | ZOS proxy → `0x50ccab84…` `Controller` (verified) | `owner()` = Safe; `fullPauser`/`partialPauser` = Safe; not paused; `authorizedCallers` = **{Rysk only}** (1 event ever) |
| ControllerLogic | `0x577b846A95711015769452F7f29d8054Cf087964` | ZOS proxy → `0xeb2c85f5…` `ControllerLogic` (verified) | `owner()` = Safe; `redeemTimePeriod` = 3600 s |
| Oracle | `0x664aD80F6891cD663228Dc9d1510a6A5Db57e815` | verified | owner + disputer = Safe; expiry prices from ManualPricers |
| Whitelist | `0xD11429254441eefe066c40C54170b54179521Ba0` | verified | owner = Safe |
| OtokenFactory | `0xD3feD88E2A1723802873e0BB74AB198D01644e18` | verified | product whitelist owner-gated; auto-whitelists created oTokens |
| MarginCalculator | `0x9219Ad4BfE15D2a65D96E935aA75f645AA6B9f22` | verified (view-only) | — |
| ManualPricers (HYPE/UBTC/UETH/kHYPE/wstHYPE/USOL) | `0x2f79DaA7…`, `0x3B82edD0…`, `0x921233d4…`, `0x97303114…`, `0x17a5527f…`, `0x47a818cF…` | all verified `ManualPricer` | owner = Safe; **bot = operator EOA** on all |

### Ethereum (1)

| Contract | Address | Kind / impl | Owner / role gates |
|---|---|---|---|
| MarginPool | `0x684404F2AEBAD87a6803F13741B1d638Bfe2C671` | ZOS proxy → `0xf76f4685…` `MarginPool` | proxy owner = AddressBook; `owner()` = Safe; `farmer()` = 0x0 |
| Rysk | `0x7A3dDEac7A0AE6dfA9391C764499A3564F3c2AAd` | Transparent proxy → `0xeedb8840…` `Rysk` | ProxyAdmin `0x08d371d4…` (owner = Safe); `operator()` = same EOA; `selfServiceAllowed()` = **false** |
| MMarket | `0xc01c9EF5de5862354adD9501a29e8765cFF01c32` | Transparent proxy → `0x5491530e…` `MMarket` | ProxyAdmin `0xb2e959ac…` (owner = Safe); operator = Rysk |
| AddressBook | `0x65852e9cf13D1a3F330BE2B95b2c1B4396d562E7` | verified | owner = Safe |
| Controller | `0xb293323Daf4E5F1313F7804FE58818f633747d0D` | ZOS proxy → `0x4f918d0e…` `Controller` | authorizedCallers = **{Rysk only}** |
| ControllerLogic | `0xC64453119e2728e956F0815447efB1E1eB30Df2d` | ZOS proxy → `0x5fac977c…` `ControllerLogic` | owner = Safe |
| Oracle | `0xC11A4767D83Fb2ab643CFc30288A7eE9690009A7` | verified | owner + disputer = Safe |
| Whitelist / Factory / Calculator | `0x6F878AF4…` / `0x73ec54AB…` / `0x6C02B404…` | verified | whitelist owner = Safe |
| ManualPricers (WETH/WBTC/wstETH/rETH/weETH) | `0xb82E16f6…`, `0x001635b6…`, `0x4c95101F…`, `0x34498508…`, `0xad7bA54A…` | verified `ManualPricer` | bot = same operator EOA |

### Upgrade paths (all P — Safe only)

- MarginPool / Controller / ControllerLogic on both chains: ZOS proxy owner = **AddressBook**; the only
  upgrade entry is `AddressBook.updateImpl(id, impl)` → `proxy.upgradeTo(impl)`, `onlyOwner` = Safe. A
  non-owner call reverts `Ownable: caller is not the owner` (proven).
- Rysk + MMarket (both chains): `TransparentUpgradeableProxy` admin = a `ProxyAdmin` contract whose
  `owner()` = Safe. Non-admin `upgradeTo` reverts (proven).
- No EIP-1967 free slots; no uninitialized re-init (`Contract instance has already been initialized` /
  `InvalidInitialization()` on every proxy — proven).

### Hot keys (P)

- `operator` EOA `0x65802CC308aeA8bb913882696c2df6bF23Ff9e48` (nonce 65,026 HYPE): only relayer of
  `ingresso_*`; bot on every ManualPricer. For the operator, `ingresso_settle` **skips the
  owner/receiver checks** (verified source, fork-demonstrated: gate opens for operator, `bad operator`
  for everyone else), so it can settle any expired vault with payout to any receiver; `ingresso_redeem`
  lets it force-redeem any user's oTokens (payout forced back to that user).
- `ryskSigner` EOA `0xea1913BF76F544f420a84F3d3fF0d087Cf80C396`: signs OTC trades that move internal
  MMarket balances between arbitrary users (relayed by the operator).
- `feeRecipient` Safe `0xFb69f38Eae27705720Eb4AABB04be9edbec5B555`: **2-of-3** (three of the same five
  V12 signers); holds accumulated fees ≈ $0.76M (HYPE: 624,362.24 USDC + 9,669.87 USD₮0; ETH:
  108,927.45 USDC + 24,426.57 USDT). Separate from the pools' TVL.

## 2. Mechanism (from verified deployed code)

- **MarginPool** (Opyn Gamma origin, `MarginPool.sol`): custody vault. Every balance change is gated by
  `onlyController` (`AddressBook.getController()` **or** `getControllerLogic()`); `farm()` is `onlyFarmer`
  (excess-only) but `farmer == 0x0`; `setFarmer` is `onlyOwner`. `getStoredBalance` is the pool's internal
  ledger; for every whitelisted collateral, stored == actual token balance (verified), except the delisted
  stHYPE excess below.
- **Controller** (`Controller.sol`): `operate()` requires `authorizedCallers[msg.sender]` (error `C6`);
  vault mutations go through `ControllerLogic` (`updateVault` is gated `msg.sender == controllerLogic`);
  `settleVault`/`redeem` also require the controller call path. Live `authorizedCallers` set = {Rysk} on
  both chains; the only two `AuthorizedCallerUpdated` events ever emitted on Ethereum set Rysk true and an
  unrelated EOA (`0xbb5c…`) false; HyperEVM emitted exactly one (Rysk true). The controller's only direct
  transaction history senders are deploy/admin setup calls from `0xbb5c…` (no external `operate` callers
  besides Rysk, which calls it internally).
- **ControllerLogic** (`ControllerLogic.sol`, Rysk's Opyn fork): all `handle*` are `onlyController`.
  `handleRedeem` burns from its caller and pays `receiver`; `handleSettle` pays the vault's pro-rata
  collateral + strike share to `_args.to`. Type-2 (physically settled) vaults use per-oToken
  `RedemptionBalances` with a canonical-balance approach; settlement/redeem require expiry (type-2 settle
  additionally waits `redeemTimePeriod` = 3600 s) and finalized oracle prices.
- **Rysk / RyskHype** (`RyskHype.sol` ≈ `Rysk.sol`): RFQ settlement processor.
  - `ingresso_newUserPosition` (fixed direction: taker writes, maker pays premium), `ingresso_transferAsset`,
    `ingresso_OTCTrade`, `ingresso_OTCTradeBatch`, `flashLoanRedeem` — all `_checkOperator()` unconditionally.
  - EIP-712 digests bind every economic field (asset/strike/expiry/price/quantity/maker/taker/
    collateralAsset/collateralAmount/gasFee/collateral chainId); global `isDigestUsed` replay map;
    `SignatureChecker` (ECDSA + ERC-1271). The `fee` field in the packed payload is **not covered by any
    signature** (taken from the maker's MMarket balance to `feeRecipient`), and the signed `validUntil` is
    **not enforced on-chain** — both are only safe because the operator backend constructs/relays payloads
    (see caveats).
  - `ingresso_redeem` / `ingresso_settle` are the only user-facing branches, and they are live-blocked by
    `selfServiceAllowed == false` on both chains; for a non-operator caller they revert `bad operator`.
    Even when enabled, redeem forces `withdraw.user == redeem receiver`, and settle forces
    `owner == msg.sender` + `receiver == owner` for non-operators.
  - `executeOperation` (flash-loan callback) requires `msg.sender == flashLoanPool` **and**
    `initiator == Rysk`; only the operator can start a flash loan.
  - `getOrDeployOtoken` auto-approves the oToken to MMarket; the approval is spendable only by MMarket's
    operator (Rysk).
- **MMarket** (`MMarket.sol`): internal-balance ledger; single external mutator `operate()` gated
  `_checkOperator()` (operator = Rysk). `transferBetweenUsers` is the OTC/trade primitive; deposit pulls
  tokens in with `safeTransferFrom`; withdraw pushes out; negative balances revert (checked math).
- **Oracle / ManualPricers**: expiry prices are pushed by the operator EOA (`bot`) through
  `ManualPricer.setExpiryPriceInOracle` (`onlyBot`, deviation-capped vs previous price), which forwards to
  `Oracle.setExpiryPrice` (`msg.sender == assetPricer`). `disputeExpiryPrice` = disputer (Safe).
- **Whitelist / factory**: collateral and products are owner-gated (`whitelistCollateral`,
  `whitelistProduct` = `onlyOwner`; `whitelistOtoken` = `onlyFactory`). `factory.createOtoken` is
  callable by anyone but requires an already-whitelisted product and auto-whitelists the new oToken;
  minting still requires the controller path, which only Rysk can drive.

## 3. Attacker model — candidate paths, gates, live blockers

"External unprivileged attacker": random address, no keys/allowances/roles, may use own capital/flash
loans, may copy any public calldata.

| # | Candidate path | Gate hit | Live blocker proven | Result |
|---|---|---|---|---|
| 1 | `MarginPool.transferToUser/transferToPool/batch*` | `onlyController` | caller ∉ {Controller, ControllerLogic} | reverts `MarginPool: Sender is not Controller` |
| 2 | `MarginPool.farm` (take excess) | `onlyFarmer` | `farmer() == 0x0` | reverts `Sender is not farmer` |
| 3 | `MarginPool.setFarmer` → farm | `onlyOwner` | Safe | reverts `Ownable: caller is not the owner` |
| 4 | Proxy `upgradeTo` / `transferProxyOwnership` (MarginPool) | ZOS `onlyProxyOwner` | AddressBook (which only Safe drives) | reverts (no reason) |
| 5 | `MMarket.operate` (withdraw anyone's internal balance) | `_checkOperator` | operator = Rysk only | reverts `bad operator` |
| 6 | `MMarket.setOperator` | Ownable (OZ v5) | Safe | reverts `OwnableUnauthorizedAccount()` |
| 7 | `Rysk.ingresso_newUserPosition` (crafted quote/confirmation) | `_checkOperator` | operator EOA only | reverts `bad operator` |
| 8 | `Rysk.ingresso_transferAsset` (move balances) | `_checkOperator` + user signature | same | reverts `bad operator` |
| 9 | `Rysk.ingresso_OTCTrade(Batch)` (ryskSigner-signed moves) | `_checkOperator` | same | reverts `bad operator` |
| 10 | `Rysk.ingresso_redeem` (steal oToken payouts) | `if(!selfServiceAllowed) _checkOperator()`; live **false** | operator only; also user==receiver constraint | reverts `bad operator` |
| 11 | `Rysk.ingresso_settle` (redirect vault payouts) | same; live **false** | operator only | reverts `bad operator` (operator branch demonstrated open in fork) |
| 12 | `Rysk.flashLoanRedeem` | `_checkOperator` + repay path | operator only | reverts `bad operator` |
| 13 | `Rysk.executeOperation` fake callback | `msg.sender == flashLoanPool && initiator == Rysk` | attacker is neither | reverts `Caller is not flashLoanPool` |
| 14 | `Controller.operate` (drive vault actions directly) | `authorizedCallers[msg.sender]` (`C6`) | set = {Rysk} | reverts `C6` |
| 15 | `Controller.updateVault` | `msg.sender == controllerLogic` (`C42`) | — | reverts `C42` |
| 16 | `ControllerLogic.handleRedeem/handleSettle/handleDepositCollateral/handleMintOtoken` | `onlyController` | — | reverts `ControllerLogic: Sender is not Controller` |
| 17 | `Oracle.setExpiryPrice` / `disputeExpiryPrice` / `setStablePrice` | pricer / disputer / owner | Safe + ManualPricers | reverts `not authorized…` / `not the disputer` / owner |
| 18 | `ManualPricer.setExpiryPriceInOracle` | `onlyBot` | operator EOA | reverts `ManualPricer: unauthorized sender` |
| 19 | `Whitelist.whitelistCollateral/Product/Otoken` | owner / factory | Safe / factory | reverts `not the owner` / `not OtokenFactory` |
| 20 | `OtokenFactory.createOtoken` for a non-whitelisted product | product whitelist (`onlyOwner` set) | reverts `Unsupported Product` | closed |
| 21 | `Otoken.mintOtoken/burnOtoken` | `msg.sender == controller || controllerLogic` | attacker is neither | reverts `Only Controller can mint/burn` |
| 22 | Re-initialize any proxy (re-init takeover) | `initializer` already consumed | all 6 proxies tested | reverts `already initialized` / `InvalidInitialization()` |
| 23 | `AddressBook.updateImpl/set*` (swap impls) | `onlyOwner` | Safe | reverts `not the owner` |

All 23 rows were first screened with read-only `eth_call --from 0x…dEaD` against live state (17 sims per
chain: `evidence/call-sims-hyperevm.txt`, `evidence/call-sims-ethereum.txt`) and then re-proven inside
forks in CI (`poc-rysk/test/RyskV12Gates.t.sol`, 21 tests).

Costs: no path leaves the gate, so no gas/loan cost applies. Every money-moving function is reached only
by `0x65802CC3…` (operator), the Rysk contract (which is itself operator-gated), the Safe, or their
governed proxies.

### Privileged powers (out of E-U scope, quantified as P)

- **Safe (3-of-5)**: upgrades everything, swaps oracle/pricers/whitelist, sets pausers, `donate`, changes
  fee/operator/signer — i.e. full control of the $36.6M + fees at any time, plus margin-pool `farmer`/
  `setFarmer` to sweep excess.
- **Operator EOA alone** (not the Safe): can settle **any expired vault to any receiver** and force-redeem
  any user's oTokens to that same user; can push expiry prices (deviation-capped); cannot touch unexpired
  vault collateral or bearer MMarket balances (those need user signatures for transfers).
- **Operator + ryskSigner**: can move any internal MMarket balances between users (OTC trades).
- Operator key liveness: if the operator stops, users cannot self-withdraw (`selfServiceAllowed=false`) —
  recovery depends on the operator or the Safe flipping the toggle.

## 4. Live state snapshot (exact amounts, blocks, USD)

Snapshot: HyperEVM block **48,180,034**, Ethereum block **26,162,991**; DefiLlama prices timestamp
≈ `2026-10-10 16:40 UTC`. Machine-readable: `evidence/live-state.json`, `evidence/valuation.json`.
The pools are actively trading (balances moved during this investigation; e.g. HYPE USDC 10.31M → 10.80M
inside ~4 h, ETH USDC 1.91M → 2.37M) — amounts are block-scoped.

| Chain | Holder | Token | Amount | Price | USD |
|---|---|---|---|---|---|
| HyperEVM | MarginPool | USDC | 10,799,125.000030 | $0.99972 | $10,795,815 |
| HyperEVM | MarginPool | USD₮0 | 3,446,022.500105 | $0.99909 | $3,443,079 |
| HyperEVM | MarginPool | WHYPE | 72,900.000000000000000001 | $86.07 | $6,274,697 |
| HyperEVM | MarginPool | kHYPE | 37,800.000000000000672152 | $88.32 | $3,338,603 |
| HyperEVM | MarginPool | UBTC | 20.375 | $82,949.11 | $1,690,088 |
| HyperEVM | MarginPool | UETH | 384.5 | $2,506.09 | $963,592 |
| HyperEVM | MarginPool | USOL | 990 | $110.37 | $109,269 |
| HyperEVM | MarginPool | wstHYPE | 625.000000000000017674 | $86.76 | $54,227 |
| HyperEVM | MarginPool | stHYPE (excess, untracked) | 647.076906710084669832 | $86.10 | $55,715 |
| HyperEVM | MarginPool | PURR | 40,000 | $0.1231 | $4,924 |
| HyperEVM | MarginPool | UPUMP / PT-kHYPE dust | 0.000001 / 0.000000000000000002 | — | ~$0 |
| HyperEVM | MMarket | USDC / USD₮0 | 433,443.425160 / 154,232.075405 | — | $587,411 |
| Ethereum | MarginPool | USDC | 2,369,950 | $0.99972 | $2,369,223 |
| Ethereum | MarginPool | USDT | 1,358,190 | $0.99920 | $1,357,043 |
| Ethereum | MarginPool | WBTC | 17.05 | $82,826.34 | $1,412,189 |
| Ethereum | MarginPool | WETH | 748 | $2,506.71 | $1,875,015 |
| Ethereum | MarginPool | wstETH | 658.000000000000000094 | $3,121.97 | $2,054,258 |
| Ethereum | MarginPool | rETH | 2.000000000000000001 | $2,934.28 | $5,869 |
| Ethereum | MarginPool | XAUt | 25 | $4,182.61 | $104,565 |
| Ethereum | MarginPool | weETH dust | 3 wei | — | ~$0 |
| Ethereum | MMarket | USDC / USDT | 59,896.493252 / 60,627.520851 | — | $120,454 |
| **Total** | | | | | **≈ $36,616,000** |
| HYPE+ETH | feeRecipient Safe (fees, separate) | USDC/USDT/USD₮0 | 624,362.24 / 108,927.45 / 9,669.87 / 24,426.57 | — | ≈ $758,000 |

- Wholesale reconciliation vs DefiLlama `rysk-v12` ($35,253,552 at `2026-10-10T05:48Z`): our arithmetic
  reproduces the chain split (Hyperliquid ≈ $26.5M, Ethereum ≈ $8.7M) exactly at those prices; the delta
  is price/time drift plus this snapshot's deposits.
- MarginPool ledger check: stored == actual for every whitelisted collateral (USDC/…/XAUt), except
  **stHYPE** (stored 0, actual 647.077…, delisted from the whitelist) → excess, unreachable while
  `farmer == 0`.

## 5. PoC (forks in CI)

Project: `poc-rysk/` (foundry, solc 0.8.24). Test file: `poc-rysk/test/RyskV12Gates.t.sol` — 21 tests
in two suites, one per chain; each suite forks the live chain (`HYPEREVM_RPC_URL` or the CI-selected
Ethereum `FORK_RPC_URL`), reads live roles/balances and executes every candidate call from a random
attacker address. No broadcast; state mutated only in-fork.

Log: `ci-out/poc-rysk.log` (artifact `result-high-cluster`).

**CI runs (GitHub Actions, repo `kingmariano/ca-zombie-ci`)**

| Run | URL | Result |
|---|---|---|
| 1 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38065780081 | compile fail — two test-constant literals missing EIP-55 checksum (fixed) |
| 2 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38066077677 | compiled; 21 tests ran; 17 pass / 4 "fail" — the 4 were over-strict reason-string asserts against OZ v5 `OwnableUnauthorizedAccount()` custom errors; every revert occurred as required (fixed asserts) |
| 3 (final) | https://github.com/kingmariano/ca-zombie-ci/actions/runs/38066632187 | **poc-rysk exit=0 — 21/21 passed, 0 failed** |

Final run (fork blocks HyperEVM **48,181,953** / Ethereum **26,163,148**):

- Suite `RyskHyperEVMGatesTest`: **11/11 pass**.
- Suite `RyskEthereumGatesTest`: **10/10 pass**.
- Fork-block values from the run log: MarginPool USDC 10,799,125.000030, WHYPE 73,200.000000000000000001,
  kHYPE 37,800.000000000000672152; `stHYPE stored=0 vs actual 647.077719753299613378`;
  operator `ingresso_settle` reaches business error `C35` (gate opens for operator only), attacker gets
  `bad operator`. Full log: `evidence/ci-poc-rysk-run3.log` (and `ci-out/poc-rysk.log` in the artifact).
- Representative trace evidence (run 2, unchanged gates): `operate([])` → `bad operator`;
  `MarginPool.transferToUser` → `Sender is not Controller`; `Controller.operate` → `C6`;
  `MMarket.setOperator` → `OwnableUnauthorizedAccount(0x…dEaD)`; `MMarket.initialize` →
  `InvalidInitialization()`; `ingresso_settle` from attacker → `bad operator`, from operator →
  business-level `C35` (gate opens only for the operator); live balances logged from the fork.
- Negative results are the deliverable: every candidate path either **reverts at its gate** or requires a
  privileged key. No positive extraction was found, and none was suppressed.

## 6. Verdict — E-U / H-O / P / S

**E-U (external unprivileged) = $0. Confidence: high.**
Every value-moving entry point on both chains is closure-proven: 23 gate classes checked live and on
forks, with exact live values blocking each (operator = one EOA; authorizedCallers = {Rysk}; testers/pausers
= Safe; farmer = 0; selfServiceAllowed = false; all proxies already initialized; whitelist/factory/oracle
owner-gated). Signature schemes bind all economic fields; replay is blocked by a global digest map; no
unauthenticated callback path exists.

**H-O (holder/user-only recoverable) = ≈ $36.6M economically user/MM-owned, but $0 self-serviceable today.**
The pools' funds are user/MM claims (option writers' collateral + premiums + MM balances). However
`selfServiceAllowed == false` on both chains: users can withdraw/settle/redeem **only** through payloads
the operator EOA relays. The owner can arm user self-service by flipping that flag (P action; would move
the currently-blocked paths to user-signed self-service, not to attackers).

**P (privileged/keyholder) = effectively all live value, with two tiers.**

- Safe 3-of-5: upgrade/drain at will (all cores) — $36.6M + $0.76M fees.
- Operator EOA alone: full control of all **expired** positions — every settled vault payout can be
  redirected to any receiver, and any user's oTokens can be force-redeemed (to that user). This is the
  single hottest key in the system and custodies the whole book as series expire.
- Operator + ryskSigner: arbitrary internal-balance moves between users.
- Pricer bot (same operator EOA): expiry prices within a deviation cap vs previous price; disputer = Safe.

**S (stuck)**: stHYPE excess 647.076906710084669832 (≈ $55.7K at $86.10) — delisted, stored balance 0,
`farmer == 0`; not settleable by users, not farmable until the owner sets a farmer (which converts it to
P). Plus dust: 1 wei WHYPE, 1e-6 UPUMP, 2 wei PT-kHYPE, 3 wei weETH (≈ $0).

**What would change the verdict** (re-test triggers): `setSelfServiceAllowed(true)`; any new
`setAuthorizedCaller`, operator/signer rotation, or proxy upgrade; a verified-source ≠ deployed-bytecode
mismatch (not checked by recompilation here — see caveats); compromise of the operator EOA / ryskSigner /
3 Safe keys (key compromise is P, not E-U); a new MarginPool/MMarket instance appearing outside the docs
list (none found).

**Other Rysk products (screened, not part of the E-U headline):**

- **Rysk Premium** (DefiLlama `rysk-premium`, ≈ $87.7K): separate MarginPools
  (`0x2f74fb34…` HYPE, `0xeBBF9472…` ETH) + vault registries (`0x425ffAB7…`, `0x12a86ae1…`); owners are
  distinct Safe proxies (`0x8fe95984…`, `0x88a8a923…`). Live vault balances ≈ 993.999 kHYPE + 2,029.70
  USDC (matches Llama). Screened only (shape/ownership); not audited line-by-line.
- **Rysk V1** on Arbitrum (≈ $193.6K, DefiLlama `rysk-v1`): different chain/product, out of brief scope;
  not investigated.
- **Fee Safe** `0xFb69f38E…` (2-of-3): ≈ $0.76M accumulated fees — P.

## 7. Coverage and what was NOT checked

**Fully audited** (verified source read line-by-line + live gate proof + fork execution): MarginPool,
MMarket, Rysk/RyskHype (incl. packed Parser and EIP-712 digests), Controller, ControllerLogic, AddressBook,
Whitelist, OtokenFactory, Otoken mint/burn gates, Oracle, ManualPricer, all proxy/upgrade paths, all
operator/controller/owner role wiring, full collateral-token enumeration (whitelist state + transfer
history + stored-vs-actual ledger reconciliation), fee wallets, authorized-caller history (event scan +
tx-history sender scan).

**Screened** (structure/roles/balance-sized, not line-by-line): MarginCalculator math (view-only, and
reachable only through operator-relayed flows), Otoken ERC-20/permit internals, Parser assembly offset
arithmetic (validated behaviorally through deployed sims and fork tests, not formally), Rysk Premium
(≈ $87.7K), Hyperlend/Aave/Uniswap integration contracts.

**NOT checked:** off-chain RFQ backend behaviour (whether it can be induced to relay stale/odd payloads —
in particular the unsigned `fee` field and unenforced `validUntil`; both were noted as off-chain-dependent
residuals, not on-chain exploit paths); identities/hygiene of the 5 Safe signers and the two hot EOAs;
historical (pre-current) implementations and authorization states; per-user MMarket balance enumeration
(requires indexing; only aggregate token balances were verified); valuation of every option series held
by MMarket (claims, not additive value); Rysk V1 on Arbitrum; the claim that no other Rysk deployments
exist beyond docs + DefiLlama (searched: docs, Llama chain split, owner Safe nonce, token-transfer
counterparties — none found).

**Caveats:** amounts are block-scoped (pools trade continuously); USD uses DefiLlama spot prices (one
stale/missing price noted: UPUMP/PT-kHYPE dust unpriced, immaterial); deployed-bytecode-vs-source
equivalence assumed from Etherscan verification (no local recompilation hash-compare); fork tests assume
public RPC state fidelity at the selected block.

## 8. Files index / methodology

| File | Content |
|---|---|
| `REPORT.md` | this dossier |
| `BRIEF.md` | parent brief |
| `ci.txt` | CI run URLs + fork blocks + results |
| `evidence/live-state.json` | all roles/addresses/balances re-read at pinned blocks |
| `evidence/valuation.json` | balance × DefiLlama price table + totals |
| `evidence/prices-initial.json`, `evidence/prices-final.json` | raw DefiLlama price responses (two timestamps) |
| `evidence/contract-inventory.json` | full contract/impl/proxy/role inventory (both chains) |
| `evidence/call-sims-hyperevm.txt`, `evidence/call-sims-ethereum.txt` | 17 read-only attacker `eth_call` sims per chain with exact revert reasons |
| `evidence/ci-poc-rysk-run2.log`, `evidence/ci-poc-rysk-run3.log` | CI fork-test logs (run 2 with 4 over-strict asserts; run 3 final green) |
| `sources/*.sol` | key verified sources copied from Etherscan V2 (RyskHype, Rysk, MMarket, MarginPool, Controller, ControllerLogic, Parser, Actions, ManualPricer, Whitelist, Oracle, Otoken, OtokenFactory, AddressBook, OwnedUpgradeabilityProxy) |
| `../../poc-rysk/test/RyskV12Gates.t.sol` | 21 fork tests (HyperEVM + Ethereum) |
| `../../ci-out/poc-rysk.log` / `ci-artifacts/…` | CI output (uploaded artifact `result-high-cluster`) |

Method: (1) docs + DefiLlama chain split → contract short-list; (2) Etherscan V2 `getsourcecode` for every
proxy/impl on chainid 999 and 1 (all verified); (3) storage-slot reads for proxy/impl/admin; (4) role
reads on proxies; (5) event scans (`AuthorizedCallerUpdated`, whitelist events) + tx-history sender scans
for hidden role-holders; (6) full collateral enumeration + `getStoredBalance` vs `balanceOf` reconciliation;
(7) read-only `eth_call --from 0x…dEaD` simulations of every candidate attack; (8) fork PoC with the same
calls executed from an attacker address, plus operator-branch demonstration; (9) CI in GitHub Actions
(only place forge compiles/tests run).
