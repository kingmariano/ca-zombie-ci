# H-05 ViteX — Child B: deep-dive on the ViteX native contracts (DexFund / DexTrade)

Audit date: 2026-10-03 (UTC). Auditor: child-B subagent (code-level audit; chain unreachable — see
`00-endpoint-evidence.md`).

Code audited (read-only clone `/tmp/opencode/go-vite`):

- Commit `429c2442f887dbd660c3ccf27fb755a90b27a05b` — *"Merge pull request #655 from
  vitelabs/release_v2.14.0 / Release v2.14.0"*, 2024-09-26. Verified via the GitHub API that this
  is **the HEAD of `master`** (no later commits exist; the repository is abandoned at v2.14.0).
  So this is the last production code that could have run on Vite mainnet.
- Core files: `vm/contracts/contracts.go`, `contracts_dex_fund.go` (2057 lines),
  `contracts_dex_trade.go` (399), `contracts_quota.go`, `contracts_asset.go`,
  and `vm/contracts/dex/*.go` (`fund_settle.go`, `fund_helper.go`, `fund_stake.go`, `fund_mine.go`,
  `fund_dividend.go`, `fund_finish_pendings.go`, `fund_storage.go`, `matcher.go`, `calculator.go`,
  `order.go`, `trade_helper.go`), plus `vm/vm.go` for the send/receive/refund machinery.
- Unit tests run locally (read-only, no repo modifications): `go test ./vm/contracts/dex/...` → ok;
  `go test ./vm/ -run 'TestDexFund|TestDexTrade'` → ok.

Code excerpts kept in `analysis/contracts/`:

| File | Contents |
|---|---|
| `contracts/dex-01-dispatch.md` | fork-versioned dispatch table (`GetBuiltinContractMethod`) |
| `contracts/dex-02-v2-stake-callback.md` | V2 stake callbacks (incl. line 879 inverted check) + Quota entry points |
| `contracts/dex-03-rollfee-panic.md` | `RollAndGentNewDexFeesByPeriod` panic + timestamp/period roll |
| `contracts/dex-04-settle-refund.md` | settlement/refund/fee-cap math; `Withdraw` ignoring attached amount |
| `contracts/dex-05-quota-open.md` | Quota `DelegateStake` (no sender gate) and V3 staking methods |
| `contracts/dex-06-mining-dividend.md` | mining/dividend distribution and constants |
| `contracts/dex-07-gates.md` | admin/privileged gates (owner/oracle/trigger/market owner/cancel owner) |
| `contracts/dex-08-forks.md` | mainnet fork heights; which contract map is active |

---

## (a) Architecture summary

### What ViteX is, in code terms

ViteX is **not** a set of user-deployed Solidity++ contracts. It is implemented as **native
built-in contracts inside the node software** (`vm/contracts/`). A transaction to one of the
built-in addresses dispatches on `(ToAddress, 4-byte selector)` via
`GetBuiltinContractMethod()` (`contracts.go:252-285`). The fork height decides which version of the
per-address method map is active; maps are cumulative (each later fork embeds the previous map).

Final mainnet upgrade heights (`common/upgrade/upgrade_init.go`, `NewMainnetUpgradeBox`):
Seed 3,488,471 → Dex 5,442,723 → DexFee 8,013,367 → Stem 8,403,110 → Leaf 9,413,600 →
Earth 16,634,530 → DexMining 17,142,720 → DexRobot 31,305,900 → DexStableMarket 39,694,000 →
V10 77,106,666 → V11 101,320,000 → V12 116,480,000 → V13 166,869,900 → **VersionX
(= height 1,000,000,000, never reached)**. Therefore at shutdown the active map was
**`dexEnrichOrderContracts`** (`contracts.go:239-243`, selected at `contracts.go:255-259`):

- **`AgentDeposit` and `AssignedWithdraw` were never enabled on mainnet** (they require VersionX);
  `Transfer` (v1.1) was enabled.
- All other DexFund/DexTrade methods listed below were reachable.

### Contracts and roles

| Contract | Address | Role |
|---|---|---|
| DexFund | `vite_0000000000000000000000000000000000000006e82b8ba657` | escrow/ledger of user balances, order escrow, staking, mining and dividends |
| DexTrade | `vite_00000000000000000000000000000000000000079710f19dc7` | on-chain order book + matcher; emits settlement actions to DexFund |
| Quota | `vite_0000000000000000000000000000000000000003f6af7459b9` | VITE staking/quota, delegate staking, callbacks |
| Asset | `vite_000000000000000000000000000000000000000595292d996d` | token issue/transfer-ownership, `GetTokenInfo` callbacks |
| VX token | `tti_564954455820434f494e69b5` | ViteX Coin (18 decimals) |
| VITE token | `tti_564954455820434f494e6e40` | native VITE |

Privileged roles stored inside DexFund DB:

- **owner** — `DexAdminConfig`, `TradeAdminConfig`, `CommonAdminConfig`; default
  `initOwner = vite_a8a00b3a2f60f5defb221c68f79b65f3620ee874f951a825db` (overridable only by
  genesis `DexFundInfo.Owner`, `ledger/chain/genesis/account_block.go:39-40`;
  `fund_storage.go:1745-1751`).
- **timeOracle** — only sender allowed to call `NotifyTime` (`fund_storage.go:1895-1900`,
  `contracts_dex_fund.go:1378-1380`).
- **periodJobTrigger** — only sender allowed to call `TriggerPeriodJob`
  (`fund_storage.go:1915-1920`, `contracts_dex_fund.go:328-330`). Note: it must be configured by the
  owner; **no default** — if unset, nobody (not even the owner) can trigger period jobs.
- **makerMiningAdmin / maintainer** — only sender allowed to call `SettleMakerMinedVx`
  (`fund_storage.go:1833-1839, 1866-1876`; `contracts_dex_fund.go:1561-1563`).
- **market owner** — per-market, set to the trade-token owner at market creation; only market owner
  can call `MarketAdminConfig` (`contracts_dex_fund.go:1263`).

### Async send/receive model (why the sender checks matter)

A block send to a built-in contract is validated at creation time by `p.DoSend()` inside
`vm.sendCall()` (`vm/vm.go:449-484`). This is the **only** place sender restrictions are enforced; a
receive executes later against a send block that the chain guarantees was created by its
`AccountAddress`. On a failing receive, the VM reverts state and creates a **refund send with the
same amount** back to the original sender (`vm/vm.go:548-575`, `doRefund` at `vm/vm.go:663-714`).
Every DexFund callback handler therefore re-checks its counterparty sender in `DoSend` (Quota for
stake callbacks, Asset for token-info callbacks, DexTrade for settlement, etc.). A caller cannot
execute a receive on behalf of another address because peer-to-peer send blocks are keyed by the
signing account, and the built-in contract addresses have no known signing keys.

### Accounting model / expected holdings

DexFund is a *bank*: the contract's real token balances must cover internal liabilities.
`VerifyDexFundBalance` (`fund_verifier.go:28-76`, exposed as RPC `dex_verifyDexBalance`,
`rpcapi/api/dex.go:895`) defines the liability structure:

```
real balance(DexFund, token) ==  Σ user Available+Locked
                              + Σ not-yet-divided dividend pools (FeesForDividend)
                              + Σ operator fee pools (OperatorFeesByPeriod)
                              + VX mine pool (GetVxMinePool)
                              + Σ maker-mining pools (per period)
                              + for VX: VxLocked + VxUnlocking
                              + for VITE: CancellingStake
```

- DexTrade holds **no** escrowed balances; it only stores the order book and writes settlement
  instructions into DexFund via 0-amount sends (`contracts_dex_trade.go:339-399`).
- VX emissions to the mine pool are structural constants: pre-normal-mining 10,000 VX/period;
  normal schedule `GetVxAmountByPeriodIndex` (`fund_mine.go:351-367`): period 0 = 10,000 VX,
  ×1.0180435 per period up to index 90 = 50,000 VX, then ×0.99810276 per period for 8 years;
  `RateForStakingMine` was 20 %, reduced to 10 % at Version12 (`fund_storage.go:131-132`);
  `rateSumForFeeMineArr` total 60 % → 55 % (V10) → 50 % (V12); maker/maintainer 20 % → 25 % → 40 %
  (`fund_storage.go:135-235`). The pool is topped up by `EndorseVx` donations
  (`contracts_dex_fund.go:1508-1520`) and drawn down by period jobs.
- Dividends: 1 % of the accumulated dividend pool is distributed per period
  (`PerPeriodDividendRate = 1000/100000`, `matcher.go:40`, `splitDividendPool` in
  `fund_settle.go:406-415`); on Earth, VITE fees are burned instead (`tryBurnVite`,
  `fund_dividend.go:209-235`).

**Live balances are unverifiable while the chain is unreachable.** The repository contains no
mainnet genesis/state snapshot (only synthetic unit-test JSON fixtures under
`vm/contracts/dex/test/`), and the last DefiLlama TVL point for ViteX is a stale 2023-08-23 value
(see `00-endpoint-evidence.md`).

---

## (b) Per-method authorization table

`Gate` = the governing check with file:line. "Any" = any external address, acting only on its own
internal DexFund balance or its own records. Legacy aliases (still registered in the cumulative
map/ABI, `abi_dex_fund.go:76-141`) are shown in parentheses.

### DexFund (`...6e82b8ba657`)

| Method (final) | Params | Who may call | Gate / evidence |
|---|---|---|---|
| `Deposit` (`DexFundUserDeposit`) | — | any | `DoSend` amount>0 (`contracts_dex_fund.go:42-47`); credits sender only (`:49-61`) |
| `Withdraw` (`DexFundUserWithdraw`) | tokenId, amount | any | `DoSend` amount>0 (`:83-93`); `ReduceAccount(sender)` (`:104`); ignores attached send amount (**see C8**) |
| `OpenNewMarket` (`DexFundNewMarket`) | tradeToken, quoteToken | any | must own trade token + registered quote token (`fund_helper.go:27-68`); 10,000 VITE fee from caller (`fund_helper.go:70-124`) |
| `PlaceOrder` (`DexFundNewOrder`) | trade/quote token, side, type, price, qty | any | locks sender's own internal funds (`fund_helper.go:270-323, 420-466`); market must exist/valid and not stopped (`:330-339`) |
| `PlaceAgentOrder` (`DexFundNewAgentOrder`) | principal, order… | any | `IsMarketGrantedToAgent(principal, sender, market)` (`fund_helper.go:337-339`); locks principal's funds (`contracts_dex_fund.go:1709`) |
| `CancelOrderBySendHash` | sendHash, principal, tokens | any | `CheckCancelAgentOrder` → owner or granted agent (`fund_helper.go:493-507`; `contracts_dex_fund.go:1851-1862`) |
| `StakeForMining` (`DexFundPledgeForVx`) | actionType, amount | any | own VITE, min 134 (`contracts_dex_fund.go:423-453`; `dex/fund_stake.go:16-135`) |
| `StakeForVIP` (`DexFundPledgeForVip`) | actionType | any | own VITE, fixed 10,000 (`contracts_dex_fund.go:489-497`) |
| `StakeForSVIP` (`DexFundPledgeForSuperVip`) | actionType | any | own VITE, fixed 1,000,000 (`contracts_dex_fund.go:533-541`) |
| `StakeForPrincipalSVIP` | principal | any | principal ≠ self (`:563-575`); payer keeps cancel right (`fund_stake.go:85`) |
| `CancelStakeById` | id (bytes32) | any | `DoCancelStakeV2` requires `info.Address == sender` (`fund_stake.go:82-89`) |
| `DelegateStakeCallback`, `CancelDelegateStakeCallback`, `StakeForQuotaWithCallbackCallback`, `CancelQuotaStakingWithCallbackCallback` | callback params | **Quota only** | `DoSend` sender == AddressQuota (`contracts_dex_fund.go:648-652, 730-734, 816-820, 917-921`) |
| `GetTokenInfoCallback` | token info | **Asset only** | `DoSend` sender == AddressAsset (`:1025-1029`) |
| `SettleOrders` (`DexFundSettleOrders`) | serialized `SettleActions` | **DexTrade only** | `DoSend` sender == AddressDexTrade (`:255-259`); payload re-checked (`:264-271`) |
| `TriggerPeriodJob` (`DexFundPeriodJob`) | periodId, bizType | **periodJobTrigger only** | `ValidTriggerAddress` (`:328-330`) |
| `NotifyTime` | timestamp | **timeOracle only** | `ValidTimeOracle` (`:1378-1380`); timestamp must increase (`fund_storage.go:2168-2183`) |
| `SettleMakerMinedVx` | serialized actions | **makerMiningAdmin only** | `IsMakerMiningAdmin` (`:1561-1563`); period/page sequencing (`:1574-1579`) |
| `DexAdminConfig` (`DexFundOwnerConfig`) | config | **owner only** | `IsOwner` (`:1102`; `fund_storage.go:1745-1751`) |
| `TradeAdminConfig` (`DexFundOwnerConfigTrade`) | config | **owner only** | `IsOwner` (`:1156`) |
| `MarketAdminConfig` (`DexFundMarketOwnerConfig`) | rates/stop | **market owner only** | `marketInfo.Owner == sender` (`:1263`) |
| `CommonAdminConfig` | stable-market/threshold | **owner only** | `IsOwner` (`:1891`) |
| `TransferTokenOwnership` (`DexFundTransferTokenOwner`) | token, newOwner | **token owner** | direct check (`:1325-1332`) or Asset callback check (origin == on-chain owner, `fund_helper.go:233-248`) |
| `CreateNewInviter` (`DexFundNewInviter`) | — | any | own fee 1,000/100 VITE, once (`:1414-1434`) |
| `BindInviteCode` | code | any | once, valid code (`:1464-1486`) |
| `EndorseVx` | (sends VX) | any | own VX amount>0 → mine pool donation (`:1508-1520`) |
| `LockVxForDividend` | action, amount | any | own VX, ≥1 VX (`:1736-1771`; `fund_storage.go:898-938`) |
| `SwitchConfig` | type, enable | any | self flag only (`:1793-1815`) |
| `ConfigMarketAgents` (`DexFundConfigMarketsAgent`) | action, agent, tokens | any | grants are stored **keyed to the caller as principal** (`fund_storage.go:2296-2316, 2343-2358`) — cannot grant over another user's funds |
| `Transfer` (v1.1) | target, token, amount | any | own internal balance → target (`:1954-1964`) |
| `AgentDeposit`, `AssignedWithdraw` | — | — | **not reachable on mainnet** (require VersionX, height 1e9; `contracts.go:245-250, 255-256`) |

### DexTrade (`...79710f19dc7`)

| Method | Params | Who may call | Gate |
|---|---|---|---|
| `PlaceOrder` (`DexTradeNewOrder`) | bytes (serialized order) | **DexFund only** | `DoSend` sender == AddressDexFund (`contracts_dex_trade.go:42-48`) |
| `SyncNewMarket` (`DexTradeNotifyNewMarket`) | bytes (market) | **DexFund only** | sender check (`:125-131`) |
| `InnerCancelOrderBySendHash` | sendHash, owner | **DexFund only** | sender check (`:247-253`); owner is re-checked downstream (`:255-262`) |
| `CancelOrder` (`DexTradeCancelOrder`) | orderId | any | receive checks caller == order owner or agent (`:99-103`, `:308-337`) |
| `CancelOrderByTransactionHash` | sendHash | any | owner check after hash→orderId (`:217-225`, `:308-337`) |
| `ClearExpiredOrders` | ≤200 orderIds | any | **disabled after V1.1** (`:170-173`, `IsVersion11DeprecateClearingExpiredOrder`); pre-V1.1 it only refunded owners (`:28-75`) |

---

## (c) Candidate extraction paths, exact preconditions and gates

For the whole section: "extraction" means an unprivileged address ending up with more real value
than it put in, at the expense of DexFund/DexTrade or another user.

### C1 — Withdraw/Transfer self-dealing → **no path found (properly gated)**

- `Withdraw` reduces *the sender's own* internal account and only succeeds if `Available >= amount`
  (`fund_storage.go:886-896`); the outgoing send is `ToAddress: sendBlock.AccountAddress`.
- `Transfer` reduces the sender and credits `param.Target` (`contracts_dex_fund.go:1954-1964`).
- `AgentDeposit` credits the attached token amount (backed by the VM crediting DexFund's real
  balance) to a beneficiary of the sender's choice.
- No method lets a caller name another user's account as the debit side except the two
  agent flows (`PlaceAgentOrder`, `CancelOrderBySendHash`), both gated by an explicit principal
  grant stored per (principal, market) (`fund_storage.go:2343-2358`) and by the owner/agent check
  at cancel (`contracts_dex_trade.go:325-327`).

### C2 — Forging a privileged sender (DexTrade / Quota / Asset / owner) → **no path found**

- Receives trust `sendBlock.AccountAddress`, but send blocks are created either by the signing
  account (RPC/tx) or by contract code; contract-created sends always carry the contract's own
  address (`vm/vm.go:449-484`, `doSendBlockList` `:840-867`). The built-in addresses are fixed
  constants derived from no known private keys; the owner is a hardcoded address
  (`fund_storage.go:247`) or genesis-configured.
- Callbacks to DexFund are sent **to the original sender** by Quota (`contracts_quota.go:266-276`)
  and Asset (`contracts_asset.go:471-480`), so an attacker calling Quota/Asset directly only
  receives callbacks *at the attacker's own address*, never at DexFund.
- Every DexFund callback handler re-checks the sender in `DoSend` (table above), and a bad selector
  on a built-in contract is rejected at send creation (`vm/vm.go:453-456, 474-477`) — so a user
  contract cannot deliver arbitrary data to DexFund under a privileged method.

### C3 — Injecting settlement actions (`SettleOrders`) → **no path found**

- `SettleOrders` requires sender == DexTrade at send creation (`contracts_dex_fund.go:257`), and
  `DoSettleFund` in the receive accepts whatever the (trusted) DexTrade computed. Users cannot call
  DexTrade `PlaceOrder` (sender == DexFund, `contracts_dex_trade.go:43`); order bytes are built by
  `DexFund.DoPlaceOrder` from validated params (`fund_helper.go:270-323`).
- All settlement amounts are derived by `matcher.go` from order fields that DexFund itself wrote,
  and each per-tx settle is balanced by construction (`handleTxFundSettle`,
  `matcher.go:312-347`): seller gives `tx.Quantity`, buyer pays `tx.Amount + fees`, the fee only
  ever moves to the fee pools.

### C4 — Over-credit through matching / rounding / refund math → **no exploitable path found**

The relevant bounds (all verified by reading `matcher.go` and `calculator.go`):

- Buy-side amount is hard-capped at the remaining locked amount
  (`calculateOrderAmount`, `matcher.go:483-489`).
- Buy-side fees are capped cumulatively against `LockedBuyFee` and the executed fee totals are
  maintained (`calculateExecutedFee`, `matcher.go:607-635`; used at `:597-605`). Hence
  `handleRefund`'s refund (`LockedBuyFee − executed fees`, `:255-274`) cannot go negative; the
  important `big.Int.Bytes()`-truncates-sign pitfall (`SubBigIntAbs`, `calculator.go:13-15`) is
  therefore not reachable with fees > locked.
- Cancel/refund uses `order.Amount − ExecutedAmount` / `order.Quantity − ExecutedQuantity`; both
  are non-negative by the caps above. Fully executed / cancelled orders are deleted from the book
  and cannot be settled twice (`:243-253`, `:402-407`); FOK and market-threshold failures discard
  the fill set before saving (`:144-163`, `:199-241`).
- Dust rules mark an order fully executed only when the residual is below one quote unit
  (`IsOrderDust…`, `:533-565`); counterparties are debited exactly the executed amount.
- The tolerated "exceed" path in `DoSettleFund` (post-DexFee fork it logs + clamps `Locked` to nil
  instead of panicking, `fund_settle.go:39-57`) can only reduce a user's own locked to 0; it cannot
  create Available out of nothing (`ReleaseLocked` credits only `actualSub`, `:48-57`).
- Self-trades move the attacker's own funds between its own accounts and pay fees; wash trading
  can farm mine/dividend shares (see C10) but cannot extract principal.

### C5 — Confirmed code defect (fund loss/stuck, **not** attacker profit): inverted refund check in the V2 (Earth) stake callback

`vm/contracts/contracts_dex_fund.go:876-895`:

```go
} else {   // stake failed -> Quota refunded the VITE back to DexFund
    switch info.StakeType {
    case dex.StakeForMining:
        if bytes.Equal(info.Amount, sendBlock.Amount.Bytes()) {     // <-- line 879, inverted
            return handleDexReceiveErr(..., dex.InvalidAmountForStakeCallbackErr, sendBlock)
        }
    ...
    dex.DepositAccount(db, address, ledger.ViteTokenId, sendBlock.Amount)
    dex.DeleteDelegateStakeInfo(db, param.Id.Bytes())
}
```

- Intent (compare the V1 handler at `:693-695` and the cancel handler at `:938`) is
  `!bytes.Equal(...)` → error; equality is the *normal* refund case.
- In the normal failure case the refund send from Quota carries exactly `info.Amount`
  (`vm/vm.go:663-714` preserves the original amount; Quota packs the refund callback in
  `contracts_quota.go:373-380`), so the check triggers the error branch: the user's staked VITE is
  never credited to their DexFund balance, the `DelegateStakeInfo` stays in `StakeSubmitted` and
  cannot be cancelled (`DoCancelStakeV2` requires `StakeConfirmed`, `fund_stake.go:82-89`).
- Worsening detail: the compensating refund created by `doRefund` from DexFund back to Quota is a
  `SendCall` with **empty data**; `sendCall` rejects sends to a built-in contract whose selector
  does not resolve to a registered method (`vm/vm.go:453-456`), so `doSendBlockList` fails and the
  receive is put into `retry` (`vm/vm.go:558-572`). Either way the user's VITE is stuck/uncredited
  — a loss, never an attacker profit.
- Reachability: the failure branch requires Quota's `MethodStakeV3.DoReceive` to fail; it has no
  business validation, returns no error, does not consume quota (`GetReceiveQuota = 0`), and
  `callDepth` is 512 — panics (unrecovered by the refund path) are the realistic failure mode.
  So this is a latent defect with **very low reachability**, preserved in upstream `master` (also
  present in the current GitHub `master` file).
- History (verified by fetching the file at each commit): the V2 callback was added by
  `27857977ac` (2019-11-01) with `bytes.Equal` in **both** the delegate and cancel handlers;
  `062dc9ee74` (2019-11-14) only converted the resulting `panic` into an error; the "hotfix dex
  mining stake" commit `f24e0e0e49` (2019-12-06) corrected the **cancel** handler to
  `!bytes.Equal` but **missed the delegate handler**, which is still inverted at HEAD
  (`contracts_dex_fund.go:879`).

### C6 — Confirmed defect (liveness/DoS, **not** theft): `RollAndGentNewDexFeesByPeriod` panic

`vm/contracts/dex/fund_storage.go:1152-1158`:

```go
func RollAndGentNewDexFeesByPeriod(db, periodId) (rolled *DexFeesByPeriod) {
    formerId := GetDexFeesLastPeriodIdForRoll(db)
    if formerId > 0 {
        if formerDexFeesByPeriod, ok := GetDexFeesByPeriodId(db, formerId); !ok {
            panic(NoDexFeesFoundForValidPeriodErr)      // <-- line 1157
        }
```

- The fee record for the current period is created lazily (`SettleFeesWithTokenId`,
  `fund_settle.go:86-90`, or the daily oracle roll `SetDexTimestamp` → `doRollPeriod`,
  `fund_storage.go:2168-2189`). Period records are **deleted** once both the dividend and mine
  period jobs ran (`MarkDexFeesFinishDividend`/`MarkDexFeesFinishMine`,
  `fund_storage.go:1143-1197`).
- If the last rolled period's record has been deleted and no subsequent roll has happened, the
  next fee settlement (any trade in any market, or a new-market fee) panics. The panic is caught by
  the block generator (`ledger/generator/generator.go:108-120`) and converted into a failed receive
  — every retry panics the same way, so **DEX settlement/trading is bricked** until the state is
  fixed out-of-band.
- Preconditions require privileged sequencing (period jobs + daily oracle roll), but the trigger
  transaction itself can be sent by **any unprivileged trader** once the state exists. No value is
  extracted; this is an availability risk worth flagging for any "if-chain-live" assessment.

### C7 — Historic, owner-refund-only: public `ClearExpiredOrders` (pre-V1.1)

Before V1.1 anyone could submit up to 200 expired (30-day-old) order IDs of one market;
`filterTimeout` cancels them and refunds them **to the order owner** (`matcher.go:660-677`,
`trade_helper.go:28-75`, `contracts_dex_trade.go:170-190`). No third party can redirect the refund,
and after V1.1 the method returns `InvalidOperationErr` (`contracts_dex_trade.go:171-173`).

### C8 — User-error loss: `Withdraw` ignores the attached send amount

`MethodDexFundWithdraw.DoReceive` never looks at `sendBlock.Amount`/`sendBlock.TokenId`
(`contracts_dex_fund.go:95-126`); the VM still credits DexFund's real balance with whatever the
caller attached (`vm/vm.go:548`). A caller that attaches tokens to a `Withdraw` transaction donates
them to the contract (no internal liability is created). Loss for the careless caller; no
extraction.

### C9 — Not reachable on mainnet: `AssignedWithdraw` panic (GitHub issue #608)

A node crash/panic was reported when `AssignedWithdraw` targets a contract address
(vitelabs/go-vite issue #608, 2022-06-09, still open). `AssignedWithdraw` (and `AgentDeposit`)
require the **VersionX** contract map (`contracts.go:245-256`), whose mainnet height is 1e9 —
never reached. So this issue cannot be triggered on mainnet; it documents a real code-path bug in
the unreleased feature only.

### C10 — Economic/design capture (no contract bug, bounded by design): mine/dividend share farming

- An attacker can be the **market owner** of a market for a token they issued
  (`OpenNewMarket` requires trade-token ownership, `fund_helper.go:44-52`) and set the operator fee
  rate up to `MaxOperatorFeeRate = 0.002` (`fund_market_admin`, `contracts_dex_fund.go:1270-1281`;
  max in `matcher.go:38`). Operator fees flow back to the market owner via the period job
  (`fund_dividend.go:143-192`).
- Self-trading then recycles the operator fee (≤0.2 %) to the attacker while paying the base fee
  (0.2 % on quote) into the dividend pool and earning a share of the fixed VX emission
  (`DoMineVxForFee`, `fund_mine.go:15-136`). The invite bonus (5 % inviter + 2.5 % invitee,
  `matcher.go:42-43`, `fund_settle.go:154-171`) further increases the mine weight of the sysbil
  trader at other users' expense within the **fixed** per-period emission.
- This does not mint value beyond the emission schedule and everyone can observe it on-chain; it
  is an economic design property of ViteX mining, not a missing authorization or accounting bug.
  Fixing it would require governance (fee/mining parameters), not a patch.

### Raw materials for an extraction attempt that are gated

| Idea | Gate that stops it |
|---|---|
| Fake a `SettleOrders` payload with an inflated `IncAvailable` | sender must be DexTrade (`contracts_dex_fund.go:257`); DexTrade only creates settles from orders whose bytes came from DexFund (`contracts_dex_trade.go:43`) |
| Get Quota to send `DelegateStakeCallback` to DexFund with attacker-chosen `StakeAddress/Amount` | Quota sends callbacks to the request's **sender**; only a DexFund-signed/-created send gets a DexFund callback (`contracts_quota.go:266-276`) |
| Get Asset to send `GetTokenInfoCallback` to DexFund with a fake owner | same sender rule (`contracts_asset.go:471-480`) |
| Impersonate owner via `DexAdminConfig`/`TradeAdminConfig`/`CommonAdminConfig` | `IsOwner` against stored/hardcoded owner (`contracts_dex_fund.go:1102, 1156, 1891`) |
| Self-appoint as `periodJobTrigger` to run dividend/mine jobs | owner-only config; `ValidTriggerAddress` requires the pre-configured address (`:1109-1111`, `fund_storage.go:1915`) |
| Cancel a victim's order with `CancelOrder`/`CancelOrderByTransactionHash` | caller must equal `order.Address` or `order.Agent` (`contracts_dex_trade.go:325-327`) |
| Cancel a victim's stake with `CancelStakeById` | `info.Address == sender` (`fund_stake.go:82-89`) |
| Withdraw someone else's balance | every fund debit uses `sendBlock.AccountAddress` (`contracts_dex_fund.go:104, 1858, 1957, 2038`) |
| Grant self as agent on a victim's market | grants are keyed by the caller as principal (`fund_storage.go:2296-2358`) |
| Transfer token ownership of a victim's token | on-chain owner check direct or via Asset callback origin (`contracts_dex_fund.go:1325-1332`, `fund_helper.go:233-248`) |

---

## (d) Negative results (paths that are properly gated)

Summarised from the table and candidate analysis:

1. **Direct balance theft** — no method debits an account other than the sender's, except the two
   agent paths, which require an explicit per-market grant and are additionally bounded to the
   grantor's own funds (`contracts_dex_fund.go:1709`, `fund_helper.go:337-339`).
2. **Privileged-sender forgery** — all fund-moving "callback" methods are sender-pinned to
   Quota/Asset/DexTrade in `DoSend`; built-in addresses have no known keys; callbacks are looped
   back to the sender by design.
3. **Settlement injection / double settlement** — `SettleOrders` is DexTrade-only; the matcher
   deletes finished/cancelled orders and applies per-tx balanced debits/credits; FOK and
   market-threshold cancel paths discard fills before commit.
4. **Withdrawal over-payment** — `ReduceAccount` enforces `Available >= amount`; the VM’s
   `sendCall` requires the contract’s real balance, and the internal accounting is intended to be
   1:1 (`VerifyDexFundBalance`).
5. **Cancel/refund mismatch** — refunds equal locked minus executed, non-negative under the fee cap
   (`matcher.go:255-274, 483-489, 607-635`).
6. **VIP/super-VIP/cancel-stake duplicate accounting** (the areas called out at
   `contracts_dex_fund.go:668-688` and `:845-872`) — concurrent duplicate staking is a known race
   and is handled: the later callback increments `StakedTimes`, records the stake id and
   immediately issues `DoRawCancelStakeV2` for the duplicate (`:844-856`, `:857-872`); the cancel
   callback decrements and removes the matching id (`:953-989`). All amounts come from the stored
   `DelegateStakeInfo`, not from the callback payload, so a caller cannot inflate them. No
   double-credit path found.
7. **T+7 finish-pending jobs** — `DoFinishVxUnlock`/`DoFinishCancelMiningStake` decrement exactly
   the scheduled `VxUnlocking`/`CancellingStake` they credit; a mismatch errors without state
   change (`fund_finish_pendings.go:12-113`, `fund_storage.go:928-959`).
8. **Mining/dividend over-distribution** — `DivideByProportion` caps cumulative payouts at the
   distributable amount and marks the pool finished (`fund_dividend.go:194-207`); the VX mine pool
   is reduced by exactly what is paid plus dust returns (`fund_mine.go:15-136, 272-321`); only the
   trigger address can run the jobs.
9. **Invite-code abuse** — one code per inviter, one binding per invitee, fee charged from the
   caller (`contracts_dex_fund.go:1414-1486`). Bonus rates only re-weight a fixed emission pool.
10. **VX lock/unlock** — locking transfers Available→VxLocked with balance check; unlocking requires
    locked ≥ amount and enforces the 10 VX dust threshold for the remainder; the unlock is credited
    only after 7 periods (`fund_storage.go:898-938`, `fund_finish_pendings.go:12-61`).

---

## (e) Verdict — latent (if-chain-live) extractability

**No unprivileged value-extraction path was found in the final mainnet code.** For every
value-bearing entry point, the debit side is the caller's own internal account, or the call is
sender-pinned to a keyless built-in contract that only acts on pre-validated state; the two
agent-delegation flows require an explicit grant recorded against the grantor's own address.
Settlement, order intake and callbacks cross-check the sender at block creation time and the
amounts are derived from DexFund-written state, with conservative caps and balanced per-trade
debits/credits.

Confidence:

- **High** that the administrative methods (owner/market-owner/oracle/trigger/admin) are correctly
  gated and not reachable by an unprivileged address. These are simple, uniform checks and the
  dispatch path is well understood.
- **Medium-high** that the account/balance methods (`Deposit`, `Withdraw`, `Transfer`,
  `AgentDeposit`, staking callbacks, cancel) cannot be abused for profit. The checks are explicit
  and the write paths were traced; the residual uncertainty is the `big.Int` byte-encoding idiom
  (`AddBigInt`/`SubBigIntAbs` reinterpret negative `.Bytes()` as positive) — no reachable
  negative result was found in the public paths, but this idiom is fragile and a full coverage
  proof (or fuzzing) was out of scope.
- **Medium** for the matching engine and mining/dividend math: the invariants were checked by
  reading and by the project’s unit tests, but there is **no formal verification, no audit of the
  native contracts, and no ability to validate against live chain state**. The matching code
  carries a `//TODO add assertion for order calculation correctness` (`matcher.go:165`), and the
  DexFee hard fork comment (`common/upgrade/face.go:117-121`) records a real production incident
  caused by a wrongly placed order — evidence that this code class has produced state corruption
  before.

The two concrete latent defects found are **loss/liveness bugs, not theft**:

- **C5** (V2 stake-refund inversion, `contracts_dex_fund.go:879`): if a Quota stake receive ever
  fails, the refund path does not credit the user and can jam in `retry`; stuck funds, no attacker
  gain. Near-unreachable trigger.
- **C6** (`RollAndGentNewDexFeesByPeriod` panic, `fund_storage.go:1157`): once the state
  precondition exists (period records deleted by the privileged jobs/oracle), **any trader** can
  trigger a deterministic panic that blocks fee settlement (all trading) until out-of-band
  intervention.

Expected holdings if a snapshot were available: DexFund holds the sum of all user
Available+Locked, the un-distributed dividend pools, operator fee pools, the VX mine pool, maker
mining pools, VX locked/unlocking and VITE cancelling-stake (the `dex_verifyDexBalance` formula
above). The last third-party TVL observation for ViteX is a stale 2023-08-23 DefiLlama value of
$4.94 M (carried forward, not a live figure; see `00-endpoint-evidence.md`). DexTrade holds no
token balances. Those amounts **cannot be verified while the chain is unreachable** and no
mainnet state is present in the repository.

---

## (f) Sources

Code (all from `vitelabs/go-vite`, HEAD `429c2442f887dbd660c3ccf27fb755a90b27a05b`, v2.14.0,
2024-09-26; confirmed as latest `master` via GitHub commits API):

- `vm/contracts/contracts.go:101-150, 201-250, 252-285` — dispatch maps and fork selection.
- `vm/contracts/contracts_dex_fund.go` — method handlers; key lines: 42-61 (deposit), 83-126
  (withdraw), 160-195 (new market), 217-233 (place order), 255-298 (settle), 320-400 (period job),
  423-497 (mining/VIP stake), 563-585 (principal SVIP), 607-626 (cancel by id), 648-708 & 730-794
  (V1 callbacks), 816-1003 (V2 callbacks; **879 inverted check**, 938 correct polarity), 1092-1124
  (DexAdminConfig), 1147-1224 (TradeAdminConfig), 1246-1291 (MarketAdminConfig), 1317-1347
  (transfer ownership), 1369-1388 (NotifyTime), 1508-1520 (EndorseVx), 1555-1612 (SettleMakerMinedVx),
  1736-1771 (LockVxForDividend), 1851-1862 (CancelOrderBySendHash), 1954-1964 (Transfer).
- `vm/contracts/contracts_dex_trade.go:42-48` (order intake), `94-103` + `308-337` (cancel owner),
  `165-190` (clear expired), `192-263` (cancel by hash), `339-399` (settle builder).
- `vm/contracts/contracts_quota.go:221-277` (DelegateStake), `365-452` (StakeWithCallback),
  `454-542` (CancelStakeWithCallback).
- `vm/contracts/contracts_asset.go:411-481` (GetTokenInfo + callback to sender).
- `vm/contracts/dex/fund_settle.go:16-75` (DoSettleFund), `154-221` (`settleUserFees`),
  `308-396` (`DoSettleVxFunds`); `vm/contracts/dex/fund_dividend.go:194-207` (`DivideByProportion`).
- `vm/contracts/dex/matcher.go:36-46` (rates), `144-253` (match/failed paths), `255-274` (refund),
  `312-347` (per-tx settle), `409-531` (amount/fee calc), `597-635` (fee cap), `644-677`
  (price/timeout).
- `vm/contracts/dex/fund_helper.go:270-323` (place order), `325-403` (order render/fee rate),
  `420-507` (lock funds, agent cancel check).
- `vm/contracts/dex/fund_stake.go:16-135` (stake request/cancel), `150-268` (stake bookkeeping).
- `vm/contracts/dex/fund_mine.go:15-136` (mine fees), `138-218` (mine staking), `272-367`
  (VX amount schedule).
- `vm/contracts/dex/fund_dividend.go:14-141` (dividend), `194-207` (DivideByProportion),
  `209-235` (burn).
- `vm/contracts/dex/fund_finish_pendings.go:12-113` (T+7 unlock/cancel).
- `vm/contracts/dex/fund_storage.go` — constants 94-135, codec helpers; gates 1745-1751 (owner),
  1833-1839 (maker mining admin), 1882-1933 (stop/time oracle/trigger), `RollAndGent` 1152-1179
  (**panic 1157**), timestamp/roll 2159-2197, share tables 2371-2440, agent grants 2296-2358.
- `vm/contracts/dex/fund_verifier.go:28-76` (liability formula); `rpcapi/api/dex.go:895`
  (`VerifyDexBalance`).
- `vm/vm.go:449-499` (send gating), `521-575` (receive/refund), `663-714` (refund amounts),
  `840-867` (send list).
- `common/upgrade/upgrade_init.go` (mainnet heights), `common/upgrade/face.go:102-125` (DexFee fork
  incident note) and 149-192 (fork predicates).
- Tests: `vm/contracts/dex/matcher_test.go` (fee-cap expectations), `vm/contracts/dex/fund_helper_test.go`
  (`DivideByProportion`, price), `vm/contracts_dex_fund_test.go`, `vm/contracts_dex_trade_test.go`.
  Executed locally: both suites pass.

External:

- GitHub API, `vitelabs/go-vite` commits: HEAD of master = `429c2442…` (v2.14.0, 2024-09-26); no
  later commits. `https://api.github.com/repos/vitelabs/go-vite/commits?per_page=10`.
- Commit history for the callback bug: `27857977ac` (2019-11-01, "support
  delegateStakeCallbackV2", introduced both V2 handlers with `bytes.Equal`), `062dc9ee74`
  (2019-11-14, "fix bug for stake callback", panic→error only), `f24e0e0e49` (2019-12-06,
  "hotfix dex mining stake", fixed the cancel-side polarity only). The delegate-side inversion
  survives in current `master`.
- GitHub issue #608, "panic when calling AssignedWithdraw with contractAddress as withdraw
  address" (2022-06-09, open) — `AssignedWithdraw` requires VersionX (never active on mainnet).
- GitHub issue #653, "Bizar situation on ViteX Exchange, bid and ask price the same for Vinu"
  (2024-05-25, open) — market UI/matching oddity, no funds-loss evidence.
- GitHub issue #651, "cancel staking for Quota at any time" (2023-07-30) — feature request; T+7
  schedule is what shipped.
- DefiLlama `protocol/vitex`: last TVL change 2023-08-23; **0 audits** recorded for ViteX
  (see `00-endpoint-evidence.md`).
- PeckShield audits `Audit-Report-VITE-ERC20-v1.0.pdf` and `Audit-Report-VITE-BEP20-v1.0.pdf`
  (April 2021, `vite.org/audit/`) cover the **Ethereum/BSC bridge token contracts only**, not the
  ViteX native contracts.
- Vite Labs wind-down / VITE→JEETS migration: cited in `00-endpoint-evidence.md` (Binance
  delisting 2025-02-24; gateway closure 2025-03-10; migration announcement 2025-05-21).

---

## Appendix — what an attacker would need that does not exist

1. A private key for DexFund/DexTrade/Quota/Asset or for the owner/oracle/trigger addresses.
2. A way to make a built-in contract send to DexFund while spoofing its `AccountAddress` (the VM
   always uses the executing contract's address).
3. A way to call `SettleOrders` on DexFund without being DexTrade, or to feed DexTrade order bytes
   that were not produced by DexFund.
4. A bug in matching arithmetic that creates value out of nothing — not found in this pass, but not
   formally excluded (no audit, no fuzzing of `calculateOrderAndTx*`).

If the chain were restored, the highest-*severity* monitoring priorities would be:
(1) the `RollAndGentNewDexFeesByPeriod` panic precondition (any fee-settlement failure = trading
freeze), (2) the V2 stake refund path (stuck VITE), (3) `VerifyDexFundBalance` drift (would reveal
any accounting bug in matching/mining), and (4) the configured admin addresses (owner/oracle/
trigger/maintainer) since they remain the only privileged actors.
