# InsureDAO L2 Phase-2 — Deployed-vs-Audited Source Diff & Exploitability Report

**Date:** 2026-10-13
**Scope:** Ethereum mainnet V1 deployments (the "impl" contracts) vs the Code4rena-audited Jan-2022 code and the latest InsureDAO repos.
**Rules followed:** read-only chain access; all artifacts written under `/home/heisenberg/CA/insuredao/analysis/source-diff/`; no keys/RPC secrets persisted.

---

## 1. Sources fetched

| What | Repo | Commit | Date | Notes |
|---|---|---|---|---|
| C4-audited code | `https://github.com/code-423n4/2022-01-insure` | `0c4c26cd1e4957202eb8a97d37e988f46b2f6ddc` | snapshot Jan 2022 | 10 contracts, solc 0.8.7. `repos/c4-2022-01-insure/` |
| Current pool-contracts (deployed version) | `https://github.com/InsureDAO/pool-contracts` | `33276267085214cae30470da8e90c4117c833ac8` ("Merge PR #192 misc-develop", 2022-02-22) | verified blob-identical to all on-chain verified sources | `repos/pool-contracts/` |
| pool-contracts `audit/code4rena` branch | same repo | `5a9a1b4a5a7d14e8573ca9a1162943f1760c9a28` (2022-02-07) | fixes merged during C4; useful intermediate | `versions/audit-code4rena/` |
| pool-contracts `audit/peckshield` branch | same repo | `db9a2cde...` (2022-01-04) | pre-fix | `versions/audit-peckshield/` |
| pool-contracts latest `main` | same repo | `2966a5057b32f8f8d18edd8c22c5ac731d1412c4` (2022-09-26) | V2, solc 0.8.12 | `versions/latest-main/` |
| pool-contracts latest `develop` | same repo | `5d522db8acc96cadca0101b932b7ba6cfc9cefe3` (2022-11-21) | V2, refactored tree | `versions/latest-develop/` |
| dao-contracts (PoolProxy/InsureToken/Minter) | `https://github.com/InsureDAO/dao-contracts` | deployed-era: `538bd3a` (2022-02-26); latest: `cd1d78aa...` (2022-09-05); audit branches: `audit/watchpug` `0dbabfb`, `audit-peckshield` `d74259a` | | `repos/dao-contracts/`, `versions/dao-*/` |
| Deployed verified sources | Etherscan fetch by parent | `/home/heisenberg/CA/insuredao/analysis/sources/` | impls: PoolTemplate `0x1dcd35cfff8a9b44aecc4087c7847fb7a5be56f9`, IndexTemplate `0x2b16be3cacaea56a6fbe613031c0f6b641df828e`, CDSTemplate `0x99f790ada7fa1bdc2a6b976293273ee51f10a10e`, Vault `0x131fb74c6fede6d6710ff224e07ce0ed8123f144`, Factory `0x01e6916CcFe3630364b4538d0f8C1c22E20d0F6b`, Registry `0xA035Dfd0D16F238493b374a1743B77448D9C8524`, PoolProxy `0xF4d046D8FaC6dc37b5eAFAdd34407b19De3Ba350` | `versions/deployed/` |

**Key provenance result:** every deployed verified source file is a **byte-identical blob** in `pool-contracts` at commit `3327626` (Feb 22 2022) — and unchanged through `edeff9d` (Apr 14 2022) before the Apr-19 `add prettier` reformat. `git hash-object` managed:

```
PoolTemplate.sol  33a47989f8ba74725415d659f8686f564bdf98af
IndexTemplate.sol 5d7fb1bd7de2ada5e707291850ca359541d3092d
CDSTemplate.sol   37237885f058452a6dabfcfd7cc845605d89bbae
Vault.sol         ac7805a57a5de8daffd2567cbd4e61b6c2a46381
Factory.sol       69f00d11ba43551336d27d4a1d97a351be304b2a
Registry.sol      0c8874a35cb4128da4f8e0367654393cc094ab6b
InsureDAOERC20    07840720aff84cb764d1fe3b3d08639b77745556
PoolProxy.sol     8c0d114e2d100447edcbac3ee4cf3e0274803347  (dao-contracts, Feb 22–28 window)
InsureToken.sol   41896515305e4b15522971d2f886eb6acfa699e0
LiquidityGauge     b2c031df0b40da3781ef92317b742d61638d317a
```

Raw diffs: `diffs/diff-c4-to-deployed-<Contract>.diff`, `diffs/diff-repo3327626-to-deployed-<Contract>.diff` (all empty → deployed == committed), `diffs/diff-auditbranch-to-deployed-*.diff`, `diffs/diff-latestmain-to-deployed-*.diff`, `diffs/diff-dao-*-to-deployed-PoolProxy.diff`.

---

## 2. Diff summary — what changed between the C4-audited code and the deployed V1

The Feb-2022 code contains the fixes for **all 14 C4 Highs** plus the medium findings that were fixed. Nothing in the diff removes a security check; the changes are fixes, gas refactors, and one new accounting model for index credit allocation.

### 2.1 Fixes explicitly visible in the diff
| C4 issue | Fix in deployed code |
|---|---|
| H-01 tokens burned via `utilize()` with zero keeper/controller | `Vault.utilize()` now `require(address(controller) != address(0))` and uses `controller.utilizeAmount()` capped by `available()` (Vault.sol:381-403) |
| H-02 `unlock()` multiple times | `_unlock()` now does `insurances[_id].status = false;` (PoolTemplate.sol:359-377) |
| H-03/H-04 market creation stole initial depositor's approved tokens | `Factory.createMarket` calls `market.initialize(msg.sender, ...)` (Factory.sol:219); `_depositor` is the caller; `_references[4]` removed (PoolTemplate.sol:174-212) |
| H-05 `withdrawRedundant` backdoor | rewritten: only transfers balance in excess of `balance` accounting (Vault.sol:523-549) |
| H-08 index `compensate()` precision-loss revert | `compensate` now takes shortage from CDS and re-reads `vault.underlyingValue()`; no `_value + _cds` assumption (IndexTemplate.sol:436-467) |
| H-09 controller migration drain | `setController` requires the new controller `valueAll()` not decreased (Vault.sol:556-567) |
| H-11 wrong `resume()` deduction math | `_liquidation()` corrected: `_deductionFromIndex = _debt * _totalCredit / _totalLiquidity`, per-index `_redeemAmount = _deductionFromIndex * _shareOfIndex / 1e6` (PoolTemplate.sol:783-822) |
| H-12 index LP could resume a locked pool | `IndexTemplate.resume()` requires `locked` and all pools in `Trading` (IndexTemplate.sol:471-485) |
| H-13 `withdrawCredit()` after `applyCover()` | `PoolTemplate.withdrawCredit` requires `marketStatus == Trading` (PoolTemplate.sol:456-464) |
| H-10 (admin can drain via Registry/Factory) | acknowledged by sponsor; `onlyMarket` design retained (privileged — see §4) |
| M-01 `repayDebt` DOS | `repayDebt` clamps payment to the debt (Vault.sol:275-288) |
| M-03 signature replay | `applyCover` requires `_incidentTimestamp < block.timestamp`; merkle leaf now binds `_loss`: `(target, insured, loss)` (PoolTemplate.sol:690-699, 606-653) |
| M-02 repeated `applyCover` | still owner-gated but deployed requires `not paused` removal + timestamp check |
| M-06/M-07/M-08 | partial/economic fixes — new credit-allocation model + per-market params |

### 2.2 Behavioral / API changes (non-fix)
- **Per-market parameters**: `getLockup/getWithdrawable/getGrace/getMinDate/getFeeRate(address(this))` are now keyed by the market, not the user, in Pool/Index/CDS templates.
- **`redeem(_id, _loss, proof)`**: loss is supplied by the claimant and bound in the merkle leaf; payout = `min(_loss * numerator/denominator, insurance.amount)`, always paid to `insurance.insured`. New `agent` field can also redeem (payout still to insured). `transferInsurance()` removed.
- **`insure(_amount, _maxCost, _span, _target, _for, _agent)`**: anyone may insure for any `_for` (payer is `msg.sender`); premium/fee split to market + `parameters.getOwner()`.
- **`applyBounty(_amount, _contributor, _ids)`**: new `onlyOwner` function (reporting admin via PoolProxy) paying a bounty via `vault.borrowValue` and unlocking policies; runs `_liquidation()`.
- **`registerIndex(uint256)`**: new public function on PoolTemplate (see §3.2).
- **IndexTemplate credit engine rewritten** (`withdrawable()`, `_adjustAlloc()`, `_totalFixedCredits`, `_freeableCredits`) — M-08/WP fixes, no value path to a caller.
- **PoolProxy**: added `pool_apply_bounty`, `defund(_to,_amount)`; everything remains admin-gated (`withdraw_admin_fee`/`distribute` are permissionless triggers whose proceeds go to configured distributors, not the caller).
- **`InsureDAOERC20`**: external `_mint`/`_burn` remain internal-only; `initializeToken` internal; zero-value transfers allowed; `transferFrom` skips allowance decrement only for `type(uint256).max`; `_beforeTokenTransfer` hook trims pending withdrawal requests.

### 2.3 Deployed vs latest repo (V2)
Latest `main`/`develop` are the V2 branch (solc 0.8.12, `implementations/PoolTemplate.sol`, `Controller`, `openDeposit`, new premium model, MarketTemplate/ReserveTemplate in develop). These are **not deployed on Ethereum V1**; V2 addresses live on Arbitrum/Optimism/Goerli (see parent's `multichain.json`). Diffs saved; no V1 security conclusion depends on them.

---

## 3. Exploitability of the changes

Legend: **E-U** = unprivileged value extraction possible for a fresh attacker (no roles, no keys, no legacy positions).

### 3.1 The changed functions on PoolTemplate/IndexTemplate/CDSTemplate/Vault — verdicts
| Contract | Function (deployed) | Change | New E-U? | Reasoning |
|---|---|---|---|---|
| PoolTemplate | `initialize` | `_depositor` from Factory = `msg.sender` | No | Fixes H-03/H-04; `initialize` cannot be front-run (clone created+initialized in same tx) |
| PoolTemplate | `deposit`/`_depositFrom` | refactor of same checks | No | Same math and paused/Trading gates |
| PoolTemplate | `requestWithdraw`/`withdraw` | per-market lockup, reorder, `_availableBalance` | No | Same economic limits; rounding unchanged (burn iToken, pay `amount*originalLiquidity/supply`, ≤ available) |
| PoolTemplate | `unlockBatch`/`unlock`/`_unlock` | status=false fix, Trading gate | No | Fix |
| PoolTemplate | **`registerIndex`** | new | **Conditional** | See §3.2 — requires a listed market; only affects future premiums or enables a conditional freeze |
| PoolTemplate | `allocateCredit`/`withdrawCredit` | `_index.exist` + Trading gate | No | Strictly more restrictive than audited (`isListed`); no direct transfer to caller except accrued premium |
| PoolTemplate | `insure` | `_for`,`_agent`, per-market fee | No | Attacker pays premium; payout/rights go to `_for` (and `agent` cannot redirect payout) |
| PoolTemplate | `redeem` | `_loss` in merkle leaf | No | Leaf binds loss; payout only to `insured` |
| PoolTemplate | `applyCover` | timestamp check; no paused check | No | `onlyOwner` (=PoolProxy; reporting admin only) |
| PoolTemplate | **`applyBounty`** | new | No (privileged) | `onlyOwner`; a malicious reporting admin can pay bounties (by design) but a fresh attacker cannot call it |
| PoolTemplate | `resume`/`_liquidation` | H-11 rewrite | No | Public caller gets nothing; amounts derived from debt/credit; see §3.2 for DoS variant |
| IndexTemplate | `deposit`/`withdraw`/`withdrawable`/`_adjustAlloc` | rewrite | No | Caller receives only own pro-rata share; new algorithm is conservative (reserves `max(_maxLockedCredits, lockedLev)`) |
| IndexTemplate | `compensate` | H-08 fix + shortage flow | No | `require(allocPoints[msg.sender] != 0)` — only pools assigned by `set()` (onlyOwner) can call |
| IndexTemplate | `resume` | H-12 fix + `adjustAlloc` | No | Locks/window logic; no funds to caller |
| IndexTemplate | `set`/`setLeverage` | onlyOwner | No | Privileged |
| CDSTemplate | `initialize`/`deposit`/`fund`/`requestWithdraw`/`withdraw` | refactor | No | Standard ERC4626-like share math; `fund` is a donation |
| CDSTemplate | **`compensate`** | refactor | **E-U (pre-existing, still live)** | See §3.3 — **drain of the entire CDS by any listed market** |
| CDSTemplate | `defund(_to,_amount)` | onlyOwner + arbitrary `_to` | No | Privileged |
| Vault | `addValueBatch`/`withdrawValue`/`transferValue`/`offsetDebt` | `_divRoundUp` (round-up, floors *user* payouts) | No | Rounding now favors the vault; only edge DoS (tiny withdrawals revert when `price/attribution > 1`) |
| Vault | `borrowValue` | zero guard | No | `onlyMarket` |
| Vault | `repayDebt` | M-01 fix | No | Public, pays on behalf |
| Vault | `utilize` | H-01/H-09 fix | No | Requires controller != 0 (currently `0x0` on the live vault → dead) |
| Vault | `withdrawRedundant` | H-05 fix | No | `onlyOwner` (PoolProxy) |
| Vault | `setController` | value check | No | `onlyOwner` |
| Factory | `createMarket` | `initialize(msg.sender,...)` | No (fix) | Removes the H-03/H-04 theft; `_createClone` zero check |
| Registry | all | cosmetic | No | — |
| InsureDAOERC20 | `transferFrom`/`_transfer`/`_mint`/`_burn` | gas/refactor | No | No public mint/burn; `initializeToken` internal; `_beforeTokenTransfer` override only adjusts withdrawal requests |

**No new unprivileged extraction path was introduced by the audited→deployed diff.** The one high-impact path found (§3.3) is present in both versions (the C4 code has the identical `isListed`-only check in `CDSTemplate.compensate`) and was not reported/fixed in either audit.

### 3.2 `registerIndex` — conditional dilution + conditional freeze (new surface, not a drain)
`PoolTemplate.sol:382-415`: anyone that `registry.isListed(msg.sender)` (i.e., any Factory-created market — see §3.3 for how a fresh attacker gets one) can:
- append itself to `indexList` when `_index == indexList.length` (any pool with < `parameters.getMaxList()` = 10 indices), or
- replace `indexList[_index]` if the incumbent has `credit == 0`.

Then `allocateCredit(any)` (no capital requirements — credit is virtual, `PoolTemplate.sol:418-449`).

Consequences:
1. **Future-premium dilution/claim**: once the pool receives any `insure()` premium, the fake index accrues `rewardPerCredit` and can `withdrawCredit()` → `vault.transferAttribution(_pending, fakeIndex)`. Historical premiums are NOT claimable (rewardDebt is set at registration with the current rate); only premiums paid after allocation are captured. **PoC needs a future `insure()`** (dead protocol → currently worthless).
2. **Conditional freeze (DoS)**: while the fake index is in `indexList`, `resume()` — which calls `IIndexTemplate(indexList[i]).adjustAlloc()` for every entry — **reverts** (a PoolTemplate clone has no `adjustAlloc`/`compensate`). A pool that ever enters `Payingout` (reporting-admin `applyCover`) then cannot `resume()`; LPs cannot withdraw in `Payingout` (`withdraw` requires `Trading`). Requires a future incident.
3. Current state: all 25 pools are `Trading`; `indexList[0]` holds a real index with credit > 0 — no slot 0 takeover today, but **slots 1–9 are appendable right now on most pools**.

The audited version let any listed market become an index by calling `allocateCredit` directly (`indicies[msg.sender].exist = true; indexList.push(...)`), so the dilution primitive is not new; `registerIndex` adds slot bookkeeping (net more restrictive).

### 3.3 **E-U FOUND (live, pre-existing): `CDSTemplate.compensate` lets any listed market drain the entire CDS**

**Code** (`impl_cds/CDSTemplate.sol:243-265`, deployed at CDS clone `0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439` → impl `0x99f790ada7fa1bdc2a6b976293273ee51f10a10e`):
```solidity
function compensate(uint256 _amount) external override returns (uint256 _compensated) {
    require(registry.isListed(msg.sender), "ERROR:UNREGISTERED");   // <-- ONLY access check
    uint256 _available = vault.underlyingValue(address(this));
    uint256 _crowdAttribution = crowdPool;
    _compensated = _available >= _amount ? _amount : _available;
    _attributionLoss = vault.transferValue(_compensated, msg.sender); // <-- value to CALLER
    ...
    crowdPool -= _crowdPoolLoss; surplusPool -= (_attributionLoss - _crowdPoolLoss);
}
```
There is **no check that the caller is a pool whose cover was applied, that it has debt, or that it needs compensation**. `Vault.transferValue` (`vault/Vault.sol:199-221`) simply moves vault attribution from the CDS to `msg.sender`.

**Attacker preconditions (all currently satisfied):**
- Factory `0x01e6916CcFe3630364b4538d0f8C1c22E20d0F6b` has the PoolTemplate template `0x1dcd35...` approved with `templates = (approval=true, isOpen=true, allowDuplicate=false)` → **anyone can create a listed market**.
- `reflist[0x1dcd][0][any]` = (slot0: zero-address wildcard true), `[1]` USDC, `[2]` Registry, `[3]` Parameters are approved; `conditionlist[0]` = `1e9` → minimum initial deposit **1,000 USDC** (recoverable).
- CDS `0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439`: `crowdPool = 59,793,841,027` (≈ $59,793.84 USDC), `vault.attributions(CDS) = 59,793,841,027`, `underlyingValue = 59,793,841,027`, `paused = false`.
- Vault `0x131fb74C6fEdE6D6710FF224E07cE0eD8123f144` (USDC): `available() = balance() = 122,292,300,439`, `totalDebt = 0`, `controller = 0x0` (so no utilization loss), `totalAttributions = 122,292,300,439`.

**Concrete call sequence (fresh EOA, no roles):**
1. `USDC.approve(vault, 1e9)` and hold ≥ 1,000 USDC.
2. `Factory.createMarket(PoolTemplate, "", [1e9,1e9], [0x...dead, USDC, Registry, Parameters])` → creates clone `M`, registers it in the Registry (`supportMarket`), transfers 1,000 USDC from the attacker into the vault with `attributions[M] += 1e9`, mints 1e9 LP of `M` to the attacker.
3. `CDSTemplate(0x86c82).compensate(59793841027)` called **from `M`** → passes `isListed(M)`, `_attributionLoss = 59,793,841,027` attribution moved from CDS to `M`; CDS `crowdPool → 0`.
4. Wait the 14-day lockup (`getLockup(M) = 1,209,600`); `M.requestWithdraw(1e9)` was already possible; then `M.withdraw(1e9)` → `_retVal = 1e9 * originalLiquidity()/supply = 60,793,841,027`; `Vault.withdrawValue` burns M's attributions and transfers **60,793,841,027 USDC (~$60,793.84)** to the attacker.
5. Net profit ≈ **$59,793.84** minus gas (the 1,000 USDC deposit is returned). Extends to any CDS clone with value.

**Verdict:** E-U **YES** — currently live, no privileges, no legacy positions. **Not introduced by the Feb/Mar-2022 changes** (identical check in `repos/c4-2022-01-insure/contracts/CDSTemplate.sol` and in `audit/code4rena`), so it is a post-audit latent bug rather than a regression. Severity: High (direct theft of CDS depositor funds). A secondary variant exists for `IndexTemplate.compensate` but it is protected by `allocPoints` (onlyOwner-set).

### 3.4 Other paths checked and rejected
- `Vault.utilize/user withdrawRedundant/setController/setKeeper`: owner-gated; live vault controller is `0x0` so `utilize` reverts.
- `PoolProxy.withdraw_admin_fee/distribute`: permissionless, but proceeds go to PoolProxy's distributor accounting (configured by admins) — not to the caller.
- `PoolTemplate.allocateCredit` premium claim without a registered slot: impossible (`_index.exist` required); with a slot (§3.2) needs future premiums.
- `PoolTemplate.redeem`: payout bound to merkle leaf `(target, insured, loss)` and sent to `insured`; `agent` cannot redirect.
- `InsureDAOERC20`: no public mint/burn; `_beforeTokenTransfer` cannot mint.
- H-06 (first-depositor rounding) is still present in `worth()` but requires a **victim depositor after the attacker seeds a fresh pool**; no current pool has a tiny supply with meaningful value, and it is not introduced by the diff.
- Index `_adjustAlloc` rewrite: no caller-profitable path found; division-by-zero cases are unreachable per state invariants.

---

## 4. INSURE token + Minter analysis (permissionless mint paths)

**Addresses (Ethereum):** INSURE `0xd83AE04c9eD29d6D3E6Bf720C71bc7BeB424393E`; Minter `0x76E8B82EA3450fA598E5e164c7E28af172deBDC0`; GaugeController `0x297ea2afcE594149Cd31a9b11AdBAe82fa1Ddd04` (31 gauges); Ownership `0x56246e83F3148B05Ce2D90B44fbb4e9fa9EAF5bb` (owner `0x79F5Dc19BC96ec1DB776d39535BDe169e67E33f4`).

| Function | Who can call | Where do tokens go | Notes |
|---|---|---|---|
| `InsureToken.mint(_to,_value)` | only `minter` (0x76E8…) | `_to` | `_mint` also enforces `total_supply ≤ _available_supply()` (emission schedule) |
| `InsureToken.emergency_mint(_amount,_to)` | only `minter` | `_to` | `emergency_minted += _amount` **before** `_mint` → the supply check becomes `total_supply ≤ base + emergency_minted`, i.e. emergency mints are not capped by the schedule |
| `Minter.mint(gauge)` / `mint_many` | **permissionless** | `msg.sender` | Mints only `integrate_fraction(caller) - minted[caller][gauge]`; caller must hold a position in a registered gauge; no one else's rewards are touched |
| `Minter.mint_for(gauge,_for)` | caller approved via `toggle_approve_mint` | `_for` | `allowed_to_mint_for[caller][_for]` can only be set by `_for`; tokens go to `_for` |
| `Minter.toggle_approve_mint(x)` | **permissionless** | — | `msg.sender` grants `x` the right to mint **for msg.sender** (self-approval, harmless) |
| `Minter.emergency_mint(amount)` | only `emergency_module` | `emergency_module` | **`emergency_module() = 0x0` on-chain → uncallable** |
| `Minter.set_emergency_mint_module` | onlyOwner (Ownership) | — | Would be needed first; currently not set |
| `Minter.set ...` / `InsureToken.set_rate/set_minter/set_name` | onlyOwner | — | Privileged |
| `InsureToken.update_mining_parameters()` | permissionless | no mint | only advances epoch/rate |
| `LiquidityGauge.deposit/withdraw/kick/claimable_tokens` | mixed | — | `withdraw` only own balance; `kick` only adjusts boost; no LP theft; INSURE accrual per user |

**Verdict:** there is **no unprivileged path that mints INSURE to an attacker without providing gauge stake**, and emission goes to the staker's own address. The emergency-mint path is **dead** (`emergency_module = 0x0`), and even if enabled it mints to the module, not the caller. INSURE has **no DEX market** (DexScreener returns 0 pairs for the token; `total_supply ≈ 148.5M`, `emergency_minted = 0`) → price effectively **$0**. Not worth pursuing as a value target.

---

## 5. Deployed-bytecode vs verified-source selector check

Method: `cast code` on each deployed implementation, extract the compiler dispatcher (`DUP1 PUSH4 <sel> EQ JUMPI`, plus the `PUSH3`/`PUSH2` optimization used for leading-zero selectors), compare against the verified ABI (from the Etherscan metadata) and against `cast sig` of every source function.

| Contract | Address | ABI functions | Dispatched in bytecode | Extras in bytecode (not in ABI) |
|---|---|---|---|---|
| PoolTemplate | `0x1dcd35cfff8a9b44aecc4087c7847fb7a5be56f9` | 56 | **56/56** | none |
| IndexTemplate | `0x2b16be3cacaea56a6fbe613031c0f6b641df828e` | 42 | **42/42** | none |
| CDSTemplate | `0x99f790ada7fa1bdc2a6b976293273ee51f10a10e` | 32 | **32/32** | none |
| Vault | `0x131fb74c6fede6d6710ff224e07ce0ed8123f144` | 33 | **33/33** | none |

**No selector exists in any deployed bytecode that is absent from the verified source. No red flags.**

Stronger check for PoolTemplate: recompiled the verified source set with solc 0.8.10 (optimizer 200, evm london) — compiled runtime is **20,570/20,613 bytes identical** to the on-chain code; the only difference is the 32-byte IPFS **metadata hash** (`f52efaf9…` on-chain vs `47d68f9d…` local — expected, depends on source-unit naming/whitespace). This confirms the deployed bytecode was compiled from the verified source with the stated settings.

Artifacts: `selector-check-PoolTemplate.json`, `IndexTemplate_bytecode.hex`, `CDSTemplate_bytecode.hex`, `Vault_deployed_bytecode.hex`, `deployed_PoolTemplate_bytecode.hex` (bytecode only).

---

## 6. Bottom line

1. **Deployed = committed code**: the Ethereum V1 verified sources are byte-identical to `InsureDAO/pool-contracts@3327626` (Feb 22, 2022) and compile-match the on-chain bytecode (modulo metadata hash). All C4 H-01…H-13 fixes are present in the deployed code.
2. **No new unprivileged extraction path was introduced by the audited→deployed change set.** The changes are fixes + refactors + the new `registerIndex`/`applyBounty`/`_liquidation` surfaces, none of which gives a fresh attacker value.
3. **One live E-U finding (pre-existing, both audited and deployed): `CDSTemplate.compensate()` is callable by any registered market and transfers the CDS's entire value to that caller.** With the PoolTemplate template `0x1dcd…` being `isOpen=true` and refs approved, a fresh EOA can create a listed market for a recoverable 1,000 USDC, call `compensate(59,793,841,027)` on CDS `0x86c82…`, and after the 14-day lockup withdraw ≈ $60,794 USDC (≈ $59,794 net theft from CDS depositors). The vault has the liquidity ($122,292 available). **This should be the parent's primary actionable finding.**
4. Secondary conditional issue: `registerIndex` lets a listed market claim an index slot (append is currently possible on most pools) → future-premium dilution, and a freeze of any pool that enters `Payingout` (`resume()` reverts on the fake index). No immediate value extraction.
5. **INSURE mintability: no unprivileged capture.** `mint`/`emergency_mint` are minter-only; Minter's permissionless `mint()` pays only the caller's own gauge emissions; `emergency_module = 0x0` makes emergency minting unreachable; INSURE has no DEX market (~$0).
6. **Blockers/limits**: no write/transactions were performed (all exploit paths are code+state-derived, not executed); the bytecode compile-match was done with a local solc-0.8.10 build (metadata hash differs); `PoolProxy` reporting-admin keys (`0x54bE2f27…`) and Ownership owner (`0x79F5Dc19…`) were not attributed to organizations — treat as trusted-role risks only.
