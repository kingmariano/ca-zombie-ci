# H-12 — Cega V1 (Ethereum · Arbitrum · Solana): live-state assessment & extractable-value determination

**Campaign:** zombie-hunt (H-12) · **Chains:** Ethereum, Arbitrum One, Solana mainnet · **Date of work:** 2026-10-03
**Status:** read-only research. PoC/boundary tests verified on local mainnet forks only (Ethereum + Arbitrum); Solana checks are read-only RPC state reads and `simulateTransaction`-style probes. **No mainnet transaction was ever signed or sent.** No secrets committed.

**Target:** the full live Cega V1 deployment — FCN (fixed-coupon-note) option products, LOV (leveraged-option-vault) products, the `CegaState` role/registry contract, the Cega-pushed `Oracle` contracts on Ethereum/Arbitrum, and the Cega V1 Solana vault program `3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs`.

**Question:** how much can an external, unprivileged attacker (no admin/operator/trader/service roles, no market-maker allowlist, no insider access; only public calls and own capital) drain or profit **right now**?

---

## TL;DR

| # | Surface | Chain | Live custody | Extractable by unprivileged attacker | Why closed | Latent risk |
|---|---|---|---|---|---|---|
| 1 | FCN products + `CegaState` | Ethereum | **$122,335.37** | **$0** | Every USDC-out function is role-gated (`403:TA/OA/DA`); vault shares mint/redeem `onlyOwner` (the product); permissionless settlement entrypoints revert on vault status (`500:WS`) or frozen oracle (`400:T`) | Trader/operator EOAs still live; `sendAssetsToTrade` → allowlisted MM; service admin can push oracle rounds |
| 2 | LOV products (registered + orphans/staging) | Ethereum | **$5,929.52** | **$0** | Same `LOVProduct` gates as (1) | Same role holders; queued withdrawals only trader-processable |
| 3 | LOV products | Arbitrum | **$18,985.49** | **$0** | Same `LOVProduct` gates; fork-verified | Same |
| 4 | Solana vault program `3HUeoo…WYzs` | Solana | **$473,541.02** | **$0 found** | All USDC token accounts owned by `productAuthority` PDA; every outbound instruction requires `admin`/`traderAdmin` (`has_one` on `State`); live account-substitution probes rejected (`AnchorError 3007`) | `traderAdmin`/`admin` are single keys; upgrade authority is a Squads v3 multisig; ~$10.3k queued claims under-collateralized |
| | **TOTAL** | 3 chains | **$620,791.41** | **$0.00** | | |

**Total live extractable by an external unprivileged attacker: ≈ $0.00.** Confidence: **high** for EVM (fork-verified revert of every value-moving path), **medium-high** for Solana (public IDL + binary string audit + live rejected probes; no program source, so absence of a subtle bug cannot be proven absolutely).

The value is not "gone": **$620,791.41 of USDC is still in Cega-controlled custody**, but every path that moves it requires a privileged signer (which pays users/queued withdrawals, market makers, or fees — not an arbitrary attacker). Holders have **no self-service exit** on either chain: withdrawals must be processed by the `TRADER_ADMIN` role (EVM) / `traderAdmin` key (Solana).

---

## 1. The mechanism (exact terms)

Cega V1 is a structured-products protocol that sells exotic options (FCN notes, leveraged option vaults) to market makers. The architecture:

**EVM (identical verified code on Ethereum + Arbitrum):**
- `CegaState` — OpenZeppelin `AccessControl` registry: `DEFAULT_ADMIN_ROLE`, `OPERATOR_ADMIN_ROLE`, `TRADER_ADMIN_ROLE`, `SERVICE_ADMIN_ROLE`; product registry (`products(string)`), oracle registry (`oracleAddresses(string)`), market-maker allowlist, `feeRecipient`. Holds residual USDC and can `moveAssetsToProduct` (trader-gated).
- `FCNProduct` / `LOVProduct` — hold the USDC, create per-tranche `FCNVault` ERC-20 shares (`lpCega`, 6 decimals), queue deposits and withdrawals.
- `FCNVault` — ERC-20 whose `deposit()`/`redeem()` are `onlyOwner` (= the product). `convertToAssets = shares * underlyingAmount / totalSupply` (floor). `totalAssets()` reads product accounting, **not** the token balance → direct donations cannot inflate share price.
- `Oracle` — Cega's own Chainlink-compatible aggregator (`oracleData[]`, `nextRoundId`). `addNextRoundData` = `SERVICE_ADMIN` only; `updateRoundData` = `DEFAULT_ADMIN` only.

Value-moving functions and their gates (verified against deployed bytecode/source):

| Function | Gate | Effect |
|---|---|---|
| `FCNProduct/LOVProduct.sendAssetsToTrade(vault, receiver, amount)` | `TRADER_ADMIN` + `marketMakerAllowList[receiver]` | USDC out to a whitelisted market maker |
| `…processWithdrawalQueue(vault, n)` | `TRADER_ADMIN` | burns queued shares, pays USDC to each queued `receiver` |
| `…collectFees(vault)` | `TRADER_ADMIN` | USDC to `feeRecipient` |
| `…processDepositQueue(vault, n)` | `TRADER_ADMIN` | mints vault shares to queued depositors |
| `…setVaultStatus / setKnockInStatus / setVaultMetadata / removeVault` | `OPERATOR_ADMIN` / `DEFAULT_ADMIN` | metadata override |
| `CegaState.moveAssetsToProduct` | `TRADER_ADMIN` | USDC from state to product |
| `CegaState.addProduct/addOracle/updateMarketMakerPermission` | `OPERATOR_ADMIN` | registry |
| `FCNVault.deposit / redeem` | `Ownable` (product) | share mint/burn |
| `addToDepositQueue / addToWithdrawalQueue` | permissionless | **user funds in** / escrow shares (no value out) |
| `checkBarriers / calculateCurrentYield / calculateVaultFinalPayoff` | permissionless | metadata only (knock-in flag, coupon, payoff); **no token transfers**; require fresh oracle (`400:T`) and specific vault status (`500:WS`) |

**Solana (`cega_vault`, Anchor):** 45 instructions. All USDC custody token accounts are owned by the `productAuthority` PDA `4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT`. Outbound instructions (`processWithdrawQueue`, `sendFundsToMarketMakers`, `transferToProductUnderlyingTokenAccount`, `transferBetweenProducts`, `collectFees`, `updateUnderlyingAmount`, `transferToProgramUnderlyingTokenAccount`) all require `admin` (`FMs1U19BfkLU3cunEa3yNZU69isCLBq59HK1eiFoLmx6`) or `traderAdmin` (`AuFniTGJZEibC4tBgkdZscPmVPUbSLn6xqmAgpPJpJFm`) via Anchor `has_one` constraints on the `State` account. User instructions (`depositVault`, `addToDepositQueue`, `withdrawVault`) only move user-signed funds **in** or enqueue a claim; `withdrawVault` creates a queue node and the payout is trader-gated `processWithdrawQueue`. Permissionless instructions (`calculateCurrentYield`, `calculateVaultPayoff`, `calculationAgent`) only recalculate accounting.

There is **no bug in the share/settlement math that an outsider can reach**: the permissionless settlement entrypoints are unreachable (EVM: no vault in `Traded`/`TradeExpired` status; Solana: they only rewrite payoff counters that the trader-gated payout instruction reads), and the oracle is admin-pushed, so "settlement payout manipulation via spot reads" is not available.

---

## 2. Live-state assessment (exact addresses, blocks, balances)

### 2.1 Ethereum — block **26,112,349** (fork-verified in CI; `eth_getBalance`/`balanceOf` reads)

**Main CegaState `0x0730AA138062D8Cc54510aa939b533ba7c30f26B`** — USDC **2.294963**.
Registry (`getProductNames()` / `products(name)`) still maps all 15 products; FCN products (9), LOV products (6). Products removed from the registry are noted below.

| Product | Address | USDC (6dp) |
|---|---|---|
| go-fast (FCN) | `0x56F00A399151EC74cf7bE8DC38225363E84975E6` | 117,940.010044 |
| cruise-control (FCN) | `0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8` | 3,166.014302 |
| supercharger (FCN) | `0x042021d59731d3fFA908c7c4211177137Ba362Ea` | 84.026086 |
| starboard (FCN) | `0xAB8631417271Dbb928169F060880e289877Ff158` | 361.704989 |
| autopilot (FCN) | `0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af` | 74.185899 |
| genesis-basket (FCN) | `0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108` | 365.766350 |
| l2 (FCN) | `0x98b872604F36807169c096241ECD4646021de133` | 182.561555 |
| insanic (FCN) | `0x784e3C592A6231D92046bd73508B3aAe3A7cc815` | 138.575232 |
| puppy (FCN) | `0x2aAE28E495626F587677ca779838266DB9bD6Cd1` | 20.231888 |
| supercharger-lov | `0xF9B7BF3f4616209Aa9d412443Aa0f94449c63122` | 3,298.059429 |
| ethereum-stakers-lov | `0xD4Ae9ce7DE8687a74dBC092526b47902b5CaaB26` | 1,436.807379 |
| l2-lov | `0x81468f8aB2d071f4F95862D5886fA57ad2B86b24` | 1,034.697551 |
| go-fast-lov | `0xeF1CE301B311654419810c8F5DbBD7Eb595F3d96` | 62.518868 |
| puppy-lov | `0x4511E45687b0F18152A03C4FD20E61fb9B373431` | 41.794983 |
| insanic-lov | `0xDC60989aaa5fbA0C2435D755056b41A9Ff415F13` | 14.118688 |
| orphan FCNProduct | `0xf27952993b17bd60d3c03f64d70ec2613808344f` | 9.447891 |
| orphan FCNProduct | `0xed803c5ee534dc4fd350f110c56e264432068b6b` | 1.000000 |
| staging FCNProduct | `0xb032134c3f5ac77b436b95983882294711d55c7c` | 3.030000 |
| staging LOVProduct | `0xcea6002ae60f764eced023787281d63da1528992` | 4.747536 |
| staging CegaState `0x5C05bEF15fe2E4acC421C183A488B1381d45713E` | | 23.299986 |
| **Ethereum total** | | **128,264.893619** |

Other Cega V1 family contracts found by deployment tracing (all with 0 USDC): CegaStates `0x33162b9c…`, `0x76c5508c…`; viewers `0x31C73c07…` (main), `0x4d90ff7a…`, `0x5f0430d0…`, `0xf613056c…`; 40+ `Oracle` contracts; 30+ additional FCNProduct/LOVProduct deployments (0 balance). Full list in `analysis/evm/census_enriched.json`.

**Vault states (FCN, all 9 products):** 33 vaults; 30 in `Zombie` (status 8), 3 in `DepositsClosed` (0). **No vault in `Traded` (3) or `TradeExpired` (4)** → `checkBarriers`, `calculateCurrentYield`, `calculateVaultFinalPayoff` revert `500:WS` for any caller, including the protocol's own. This also means settlement cannot proceed until a `setVaultStatus`/`setVaultMetadata` (operator/default admin) or a rollover is done.

**Queued withdrawals (EVM):** only one vault has queued withdrawals — go-fast vault `0x5799Dab15A745b346058AFbC141C78A0dc25F8c6`: **2 queue entries, 100,000.000000 shares of 100,006.605405 total supply (~99.99 % of the vault), both with receiver `0x5DF6a71c62895B22B73C4fd5D015526876819366`**, against 117,301.58 USDC vault accounting. All deposit queues are empty (`queuedDepositsTotalAmount == 0` for all 9 FCN products).

**Oracles:** 11 Cega `Oracle` contracts per chain, `description = "<PAIR>,Pyth"`, `decimals` 6/8/18. Last round `startedAt` values are **2025-01-01** (BTC/ETH/SOL/AVAX/ARB/OP: `1735740000`) or **2024-06-24** (`1719151200`). The staleness check in `Calculations.checkBarriers/calculateKnockInRatio` requires `block.timestamp - 1 days <= startedAt` → **every settlement path that reads an oracle reverts `400:T` today**. Rounds are pushed by `SERVICE_ADMIN_ROLE` (`addNextRoundData`) and can be rewritten by `DEFAULT_ADMIN_ROLE` (`updateRoundData`); an arbitrary caller gets `403:SA` / `403:DA` (fork-verified).

**Roles (both EVM chains, verified via `hasRole` at the latest block):** still held by multiple Cega EOAs (not renounced):

| Role | Ethereum holders (current) | Arbitrum holders (current) |
|---|---|---|
| DEFAULT_ADMIN | `0xea3d63a3…` (contract), `0xcbc9c4de…` (EOA) | `0x2315f08c…` (contract) |
| OPERATOR_ADMIN | `0xcbc9c4de…`, `0x8dbd0f1a…`, `0xbc3dc5f3…`, `0x1c835759…`, `0x96ee4064…`, `0xe159e055…` (all EOAs) | `0xcbc9c4de…`, `0x96ee4064…`, `0xbc3dc5f3…`, `0x1c835759…`, `0xdd987700…` |
| TRADER_ADMIN | `0xd97feae2…`, `0x0e7b7141…`, `0xcbc9c4de…`, `0x02dde5a4…`, `0x28c26a83…`, `0xbc3dc5f3…`, `0x96ee4064…`, `0x9cda3932…`, `0x03797bf1…` (contract) | `0x9cda3932…`, `0x0e7b7141…`, `0x4cc92636…`, `0x1c835759…`, `0xe9c5819f…` (contract) |
| SERVICE_ADMIN | `0xf45c3d1e…`, `0x0e7b7141…`, `0xd97feae2…`, `0xcbc9c4de…` | `0xcbc9c4de…`, `0xbc3dc5f3…`, `0x0e7b7141…`, `0xf45c3d1e…` |

**Non-proxy:** all checked contracts are direct deployments (no EIP-1967 slots); the code is immutable, but roles are mutable by admins.

### 2.2 Arbitrum One — block **511,324,457**

**CegaState `0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed`** — USDC **0.930732**. Registry: 10 LOV products.

| Product | Address | USDC |
|---|---|---|
| l2-lov | `0x4919e2554C690Fe2696DC17cCaB3D5f71Bc7a550` | 9,356.569396 |
| cruise-control-lov | `0x3408632Ee5F99A2a0dE7cF0b29BA888A5967066d` | 6,431.999596 |
| ethereum-stakers-lov | `0x1B4Dc3476dB1E19DbDDcdA5440b23ED4FcC61Bee` | 705.129138 |
| go-fast-lov | `0x0299A5B8D523ebccF5501177c35C0958774FdB38` | 589.559572 |
| autopilot-lov | `0xdBe523D41b06138EaEBD3A81c0711F6DCab4726d` | 530.195137 |
| supercharger-lov | `0x41A42A2206C9eB29d9e0486c94321618B309f6Ba` | 485.155870 |
| genesis-basket-lov | `0x52f02F642eC91e19A614d23fF3da7ADe66326b64` | 377.765931 |
| insanic-lov | `0x3d0651F87fBCEB64aCa72aFa78112DCc6622cDee` | 202.980743 |
| starboard-lov | `0x03F48C289Eed2Fa712a67C4BA87769e7bC4213aD` | 171.285998 |
| puppy-lov | `0x6A9201Db9222cFb5164cfb8F192903270f8a6e93` | 129.897864 |
| orphan LOVProduct | `0x692926af4744e14ed32bf7717c5cb4aaa0025aca` | 4.018987 |
| **Arbitrum total** | | **18,985.488964** |

Arbitrum LOV vaults (22 across puppy-lov leverages 1–5 + orphan product): all `DepositsClosed` (status 0) at the pinned read; queued withdrawals 0 on the vaults sampled by the fork tests; one vault per leverage holds the residual balances. Full per-vault dump: `analysis/evm/` (child census) and `analysis/vaults_quick.json`.

### 2.3 Solana — program `3HUeooitcfKX1TSCx2xEpg2W31n6Qfmizu7nnbaEWYzs` (programdata `28qdJRKpfu1VGBbrSk7MEhdQV2fnfLyRNC4vsv6rVtQc`, last deploy slot 317,515,655 ≈ Jan 2025)

**Measured live USDC custody: $473,541.02**

| Bucket | USDC |
|---|---|
| Active product token accounts (6: cruise-control-2, go-fast-2, supercharger, insanic-2, genesis-basket-test, alick-demo) | 179,979.06 |
| Inactive product token accounts (17) | 85,493.69 |
| Program USDC account `BTStJZTJvscGRive34P6ShujjqK4GBBRs93bg1Y4B7Y4` (PDA of `productAuthority`) | 208,068.26 |
| **Total program-controlled** | **473,541.02** |

All token accounts are owned by `productAuthority` PDA `4nhbsUdKEwVQXuYDotgdQHoMWW83GvjXENwLsf9QrRJT` (verified via `getMultipleAccounts` — e.g. `BTStJZTJ…` holds `208068.264372` USDC, owner `4nhbsUdK…`). Largest product: genesis-basket-2 (`45eBn7xc…`) 82,669.62; largest active: cruise-control-2 78,147.66.

**Queues:** 10,841.15 USDC queued across 8 vaults / 13 nodes; notable under-collateralized cases: cruise-control-test vault#0 claim 10,000.00 vs 0.002055 held; starboard vault#0 claim 821.42 vs 556.89 held (shortfall ≈ $10,264.53). 33 of the last 36 `processWithdrawQueue` calls failed inside the SPL burn/transfer with "insufficient funds"; one succeeded paying 28,604.65 USDC to a user. Deposit queue: 1.00 USDC (admin's own).

**Governance:** program is upgradeable; upgrade authority `5d8d3PSxKDb6knunoweZ8jZYoDmgEEGMVJdqJBTgjvRx` is a **Squads v3 multisig vault PDA** (program `SMPLecH534NA9acpos4G6x7uf3LWbCAwZQE9e8ZekMu`; last upgrade 2025-01-31 via `ExecuteTransaction`). `State` (`3nFsMoYY…`) admin/traderAdmin are single keypairs (above). No unprivileged upgrade path.

**Source/IDL:** program source not public; public Anchor IDL at `github.com/cega-fi/cega-sdk-sol` (`src/idl/cega_vault.json`, saved). Binary strings cross-checked all 45 instruction names and validation errors (`MissingRequiredSignature`, `InvalidVaultAdmin`, `InvalidTraderAdmin`, `Reciever token account mismatch`, `InvalidUserUnderlyingAccountOwner`, …). On-chain IDL account absent. A deployed-vs-IDL schema drift (OptionBarrier 367 B vs 332 B) means the program is newer than the 2024 SDK; this is the main reason Solana confidence is medium-high rather than absolute.

---

## 3. What an attacker can and cannot do (exact call paths)

**Cannot (all fork-verified on Ethereum/Arbitrum; CI run 13/13 PASS):**
- `FCNProduct/LOVProduct.sendAssetsToTrade` from an arbitrary EOA → reverts `403:TA`.
- `processWithdrawalQueue` / `collectFees` / `processDepositQueue` → `403:TA`.
- `setVaultStatus` → `403:OA`; `setKnockInStatus` → `403:DA`.
- `CegaState.moveAssetsToProduct` / `addProduct` / `removeProduct` / `addOracle` / `setFeeRecipient` / `updateMarketMakerPermission` → OpenZeppelin `AccessControl` revert.
- `FCNVault.deposit` / `redeem` from a non-owner → `Ownable: caller is not the owner` (only the product contract can mint/burn shares).
- `addToWithdrawalQueue` without owning shares → ERC-20 allowance/balance revert (no way to escrow someone else's shares; USDC has no transfer hooks, no reentrancy surface; all queue functions are `nonReentrant`).
- Permissionless `checkBarriers` / `calculateCurrentYield` / `calculateVaultFinalPayoff` on live vaults → `500:WS` (no vault in a callable status); on any vault that did become callable, they only write metadata and move no tokens (test asserts balances unchanged).
- `Oracle.addNextRoundData` → `403:SA`; `Oracle.updateRoundData` → `403:DA`.
- Solana: `processWithdrawQueue` with substituted/malicious accounts → rejected at account validation (`AnchorError 3007 AccountOwnedByWrongProgram`, custom 0x1) — live probe tx `2Ymr1DvC…` (slot 450,167,597); no instruction takes a user-supplied token account as the USDC source.
- Solana: no permissionless instruction transfers USDC out; `withdrawVault` only appends a queue node.

**Could only with privileged roles (not E-U):** a `TRADER_ADMIN` EOA could `sendAssetsToTrade` up to `currentAssetAmount` to any allowlisted market maker, `processWithdrawalQueue` to any queued receiver, or `collectFees` to `feeRecipient`; the Solana `traderAdmin` key could move the full $473.5k custody (e.g. `sendFundsToMarketMakers`, `transferToProductUnderlyingTokenAccount`). These are trust assumptions on Cega's keys, not attacker-reachable paths.

**Costs:** zero — there is no candidate path to price.

---

## 4. PoC / fork verification (CI)

- **Foundry project:** `poc/` (`foundry.toml`, `test/CegaV1.t.sol`).
- **CI run:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/37132657691 — **13/13 tests PASS** (8 Ethereum at pinned block 26,112,349; 5 Arbitrum at latest), Foundry 1.8.4, `forge test -vvv`.
- Ethereum tests: live custody snapshot (total 122,335.371308 in FCN+state at the pinned block); value movers revert for attacker; CegaState movers revert; vault deposit/redeem onlyOwner; no-shares queue reverts; permissionless settlement reverts `500:WS` and moves nothing; oracle push is `403:SA`/`403:DA` and is stale; go-fast pending withdrawals are trader-gated.
- Arbitrum tests: custody snapshot (puppy-lov 129.897864, state 0.930732); value movers revert; state mover reverts; vault redeem onlyOwner + no-shares queue reverts; permissionless settlement reverts `500:WS`.
- Solana probes (read-only, by the child subagent, saved raw): account-substitution calls to `ProcessWithdrawQueue` rejected with `AnchorError 3007`; full evidence in `analysis/solana/raw_pwq_fail.json`, `raw_pwq_admin_fail.json`, `tx_activity_100.json`.
- CI artifacts: `ci-artifacts/result-cega-v1/` (state snapshot + Solana logs); `ci-out/state_snapshot.json`.

Gas is irrelevant (no successful extraction path); the tests above are negative proofs and cost only fork RPC calls.

---

## 5. Verdict, residual/latent risk, blockers

**Verdict: external unprivileged attacker can extract ≈ $0.00 live.** High confidence on Ethereum/Arbitrum (every value-moving selector reverts for an arbitrary caller; vault shares are not freely mintable/redeemable; oracles are admin-pushed and frozen; permissionless settlement is metadata-only and currently uncallable). Medium-high confidence on Solana (all custody is PDA-owned; every outbound instruction is `has_one`-gated; live substitution probes rejected; residual uncertainty is the un-published program source / IDL drift).

**Residual value & classification** (see `summary.json`):
- **E-U = $0.00**
- **H-O = $0.00** — no self-service withdrawal on either chain: EVM withdrawals are `TRADER_ADMIN`-processed; Solana `withdrawVault` only enqueues and payout is `traderAdmin`-gated.
- **P = $620,791.41** — all program-controlled USDC (EVM $147,250.38 + Solana $473,541.02), moveable only with admin/trader/service signatures. In practice most of this is owed to vault holders and is paid out through the trader-processed withdrawal queues; it is **not** attacker-extractable.
- **S = $0.00 assets**, with a caveat: ~$10,264.53 of Solana queued claims are under-collateralized (cruise-control-test 10,000.00 vs 0.002055 held; starboard 821.42 vs 556.89 held) and cannot be paid from their own product accounts (they could only be topped up by privileged `transferBetweenProducts`).

**Latent risks (not currently exploitable):**
- Cega's EVM admin/trader EOAs are still live and unrenounced; the oracle can be re-opened by a service-admin round push, which would make settlement callable again. A malicious/compromised trader key can redirect product USDC to any allowlisted market maker.
- The Solana upgrade authority is a Squads v3 multisig; a compromised quorum could upgrade the program and drain $473.5k.
- The go-fast vault's ~$117.3k is queued to receiver `0x5DF6a71c…` pending trader processing (99.99 % of the vault) — a single privileged call settles it.
- Solana under-collateralized queues (above) will keep failing until topped up.

**Blockers encountered:** public RPCs do not serve archive state for the pinned Ethereum block (used BlockPi/NodeReal/dRPC archive endpoints); Arbitrum public RPCs serve no archive state at all, so the Arbitrum fork is latest-state and its test asserts gates rather than pinned balances; the Solana program has no public source and no on-chain IDL, so the instruction audit relies on the public 2024 IDL + binary strings + live probes (documented above).

---

## 6. Methodology & sources

- Deployment discovery: DefiLlama adapter `projects/cega/index.js` (product/state/viewer addresses, Solana program ID) → verified-source fetch via Etherscan V2 → creator tracing (`getcontractcreation` + `txlist`) → 101 ETH + 47 ARB Cega-family contracts (`analysis/evm/census_enriched.json`).
- Verified sources for `CegaState`, `FCNProduct`, `LOVProduct`, `FCNVault`, `Calculations`, `LOVCalculations`, `Oracle`, `CegaViewer` extracted to `analysis/src/`.
- Live state: `cast call` at explicit blocks (ETH 26,112,349; ARB 511,324,457); Solana via `getProgramAccounts`/`getMultipleAccounts`/`getSignaturesForAddress`/`getTransaction` (read-only).
- Roles: `RoleGranted`/`RoleRevoked` logs (Etherscan V2 `getLogs`) + current `hasRole` checks (`analysis/registry_events.py`, `registry_events.json`).
- Oracles: registry enumeration + `latestRoundData()` + verified `Oracle` source (admin-gated push).
- Fork PoC: Foundry 1.7.1 locally / 1.8.4 in CI; tests in `poc/test/CegaV1.t.sol`; run URL above.
- Solana: public IDL (`cega-fi/cega-sdk-sol`), binary string extraction, live simulation probes; details in `analysis/solana/SUMMARY.md`.
- Prices: DefiLlama `coins.llama.fi` USDC ≈ $0.99996 (2026-10-03); USD figures use $1.00 (differences < 0.01 %).

**Caveats & limitations:**
1. Solana program source is not public; the audit is IDL + binary + probe based. A deeply hidden instruction-validation bug cannot be ruled out absolutely. This is the main uncertainty.
2. The Arbitrum fork used latest state (no archive RPC available); Ethereum is pinned and reproducible.
3. EVM totals are as of block 26,112,349 (ETH) and a 2026-10-03 read (ARB); custody can change if privileged actors process queues. The gates (role checks) are code-level and do not change.
4. `underlyingAmount` counters are not custody; all headline numbers are measured token balances.
5. Cega V2 (separate finding) was not audited; some census addresses may belong to V2/staging — balances are counted regardless, and the gate analysis for `LOVProduct`/`FCNProduct` types applies to them equally.

---

## 7. Files index

| Path | Content |
|---|---|
| `README.md` | this deliverable |
| `summary.json` | machine-readable summary |
| `poc/test/CegaV1.t.sol` | 13 fork tests (gates + custody snapshot) |
| `ci/run.sh`, `ci-out/state_snapshot.json` | CI heavy job + snapshot artifact |
| `ci-log.txt`, `ci-artifacts/` | full CI log + downloaded artifacts |
| `analysis/src/` | extracted verified Solidity sources |
| `analysis/sources/` | Etherscan source/ABI JSON |
| `analysis/evm/` | deployment census, enriched balances, scripts |
| `analysis/solana/` | full Solana state, IDL, probe evidence, `SUMMARY.md` |
| `analysis/registry_events.*`, `analysis/vaults_quick.*` | role events, quick vault census |
| `analysis/codeaudit/`, `analysis/docs/` | child code-audit + docs/incident research |
