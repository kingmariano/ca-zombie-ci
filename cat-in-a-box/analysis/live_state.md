# Cat in a Box — live state assessment (Ethereum)

Read-only. All values read via `eth_call` at **block 26,176,576** (CI, 2026-10-12) and
26,176,056 (local pass). Prices: DefiLlama 2026-10-12 — stETH $2,542.62, WETH $2,543.86,
wstETH $3,166.75 (1.2461 stETH).

## 1. Architecture (all verified from verified source on Etherscan)

| Contract | Address | Role |
|---|---|---|
| `boxsteth` (boxETH) | `0x7690202e2C2297bcD03664e31116d1dFfE7e3B73` | synthetic ERC20 ("Cat-in-a-Box Ether"), mint = `ADMIN_ROLE` only |
| `catinaboxcdp` (v1) | `0x7f0a0c7149a46bf943ccd412da687144b49c6014` | stETH collateral → boxETH minter (LTV 99%), `stabilisePeg` redemption |
| `catinaboxcdp1point1` (v1.1) | `0x6ffd098e92b606b2947b89a08911c00ca06890fa` | same, plus 0.25% minting fee; yield paid to borrowers by debt weight |
| `psmstart` (PSM) | `0x24146D1B3339Cf76b455dC42e71Ea5Cdff4aE0d7` | boxETH→stETH at par, `CONVERTER_ROLE` only |
| `feeSplitStaking` | `0x320c871b6f7721083604FfdD8070E64c1d3c5d7C` | boxFEE staking, boxETH rewards, boxETH→stETH `trade` (`CONVERTER_ROLE`) |
| `feeSplitToken` (boxFEE) | `0xE4B91fAf8810F8895772E7cA065D4CB889120f94` | Solmate-style ERC4626 over boxETH |
| `catinaboxcdp` (abandoned) | `0x1e63d4e8bee70e26cffee2fcd50f71870c50dc50` | empty (223 wei stETH, no deposits/debt) |
| 5 unverified contracts (2024) | `0xe12bceb3…`, `0x797ed331…`, `0x39980c30…`, `0x646f46cd…`, `0x932705a4…` | no value ($0 / $0.71 / $25.63 USDC) |

Markets (all boxETH pairs on Ethereum):
- UniV3 **boxETH/WETH 0.05%** `0x287139599f1B5849f12Cf18244A74F595da9936D` — **live**: 5.3624 boxETH + 5.4108 WETH, spot 0.9947 WETH/boxETH
- UniV3 **boxETH/wstETH 1%** `0x703a177fcb4def281d180d3619a5edbae67ec7b5` — **live**: 4.3957 boxETH + 3.5199 wstETH, spot ≈ 0.9978 stETH/boxETH
- UniV3 boxETH/WETH 1% `0x53a26afD…` — dead (liquidity 0, 4 wei)
- boxFEE markets: UniV2 `0x10E557e5…` (dust), UniV3 `0x2582959B…` (liquidity 0), `0x4107a134…` (dust), `0x102b0e3f…` (liquidity 0) — **no tradeable boxFEE liquidity**

## 2. Live custody (block 26,176,576)

| Holder | stETH | boxETH | USD (stETH) |
|---|---|---|---|
| CDP v1 | 83.723447 | 0 | $212,877 |
| CDP v1.1 | 427.783573 | 0 | $1,087,690 |
| PSM | 2.169523 | 0.661913 | $5,516 |
| feeSplitStaking | 2.106570 | 1.469417 | $5,356 |
| boxFEE vault (assets) | — | 248.305217 | — |
| UniV3 0.05% pool | — | 5.362443 | — |
| UniV3 wstETH 1% pool | — | 4.395744 | — |
| **Total stETH custody** | **515.783** | | **$1,311,440** |

boxETH notional in protocol contracts/vaults+pools: 260.19 boxETH (~$662k at par).

CDP internal accounting:
- v1: `totaldeposits` 83.5279, `totalDebt` 7.6626, `unclaimed` 3.8087, ltv 9900, idleFee 10, 119 actors / 63 live positions
- v1.1: `totaldeposits` 427.5218, `totalDebt` 294.3687, `unclaimed` 4.5766, ltv 9900, idleFee 10, mintingFee 25 (0.25%), 63 actors / 30 live positions
- Sum of per-depositor `deposited` = 79.7192 (v1) / 422.9452 (v1.1); sum of `debt` matches totalDebt exactly.

## 3. Roles / ownership (verified via RoleGranted/RoleRevoked logs + `hasRole`)

| Role | Holders (live) |
|---|---|
| boxETH `ADMIN_ROLE` (mint) | CDP v1 `0x7f0a…`, CDP v1.1 `0x6ffd098e…` — **no other holder** (deployer + Safe revoked 2023) |
| CDP v1 `ADMIN_ROLE` | Gnosis Safe `0x98e6475C01D018Ae78c02ef48738f687538226Af` (3-of-5; all owners EOAs). Only `setFee` |
| CDP v1.1 `ADMIN_ROLE` | same Safe. Only `setFee`, `setMintingFee`, `setIncentivesModule`, `setFeeSplitAddress`, `setpsm` |
| PSM `CONVERTER_ROLE` | Safe + deployer EOA `0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e` (role granted 2023, never revoked) |
| feeSplit `CONVERTER_ROLE` | Safe + deployer EOA + `0xe8fF7D752Adc76F93EEaF0B1BE855d99c6ec9938` + `0x66F576C1eDa4044A01bF68A78564F39bA3BbF65b` |
| PSM `DEFAULT_ADMIN_ROLE` | Safe |
| boxETH `ADMIN_ROLE` admin | `ADMIN_ROLE` itself (self-administered by the two CDPs) |

**No admin/role function can move the 515.8 stETH of CDP collateral.** Admin functions only
set fee parameters / pointers. Collateral leaves a CDP only via user `withdraw`, `stabilisePeg`
(debt-capped redemption), `liquidate` (self, sends to PSM) and the auto-repay `fetch` path
(flag-enabled depositors, sends to PSM).

## 4. The only permissionless value-out path: `stabilisePeg`

```solidity
function stabilisePeg(uint256 amount, address _depositor) external sync() fetch(_depositor) {
    uint256 maxRedeemable = debt[_depositor] / 4;          // per-call cap
    if (amount > maxRedeemable) amount = maxRedeemable;
    uint256 redemptionFrictionfee = amount/10 - amount/10*debt[_depositor]/deposited[_depositor];
    synthetic.safeTransferFrom(msg.sender, psm, redemptionFrictionfee); // fee paid in boxETH
    synthetic.burnFrom(msg.sender, amount);                             // attacker's boxETH burned
    deposited[_depositor] -= amount; debt[_depositor] -= amount;
    totalDebt -= amount; totaldeposits -= amount;
    collateral.safeTransfer(msg.sender, amount);                        // stETH out
}
```
- Callable by anyone; the **cap over all calls = the sum of depositors' debts** = 302.0313 boxETH
  (v1 7.6626 + v1.1 294.3687) ⇒ gross ceiling **302.03 stETH ≈ $767,950** *if boxETH were free*.
- Fork-proven (T7): 301.555 stETH extracted by looping all debt-holders with `vm.deal`ed boxETH.
- Friction fee = `10% × (1 − debt/deposited)` of the amount; best live victim ratios give
  0.19%–1.10% (v1.1) and ≥5% (v1).
- The attacker must supply boxETH. Market reality (fork-measured):
  | buy (WETH) | boxETH out | avg price | stETH redeemed | net |
  |---|---|---|---|---|
  | 0.5 | 0.4636 | 1.0784 | 0.4591 | **−0.0409 stETH** |
  | 2.0 | 1.4709 | 1.3597 | 1.4564 | **−0.5436 stETH** |
  | 5.0 | 2.6003 | 1.9229 | 2.5746 | **−2.4254 stETH** |
  | 0.01 | 0.010042 | ~0.9958 | 0.010022 | +0.000022 stETH (2.17M gas) |
  | 0.05 | 0.050084 | ~0.9984 | 0.049979 | −0.0000206 stETH |
- Mint-and-redeem (T4): deposit 3.0002 → mint 2.9552 → redeem 2.9260 stETH; walk-away −0.0742,
  even with hypothetical par repayment −0.0439 stETH.

## 5. Other surfaces checked

- `PSM.trade` / `PSM.synthToFeeToken` / `feeSplit.trade`: revert for unprivileged callers
  ("AccessControl: account … is missing role 0x9b67f1cd…") — T5 + direct `cast call`.
- `CDP.withdraw` / `mint` / `repay` / `liquidate` / `poke`: self-only effects (T9).
- `unclaimed` (3.81 + 4.58 stETH): only payable to the depositors whose points were credited;
  a third party cannot redirect (T10: Σ owing of top-6 v1 depositors 2.316 ≤ unclaimed 3.809).
- Yield sniping: pending excess is ≤ 0.236 stETH (v1.1) / 0.185 stETH (v1) and the sync runs
  before any weight increase in the attacker's own tx; the 0.5% v1.1 mint fee alone exceeds
  the capturable yield. Not profitable.
- boxFEE vault: `deposit` mints shares **1:1** (and returns 0), while `redeem` pays at NAV
  0.10627 boxETH/share → any entry is an immediate ~89% loss (T6). No boxFEE market exists
  to buy shares cheaply.
- boxETH `burnFrom` bug: `require(allowance(account,msg.sender) - amount >= 0)` but the
  allowance is never decremented → an approved spender can burn the approver's balance
  repeatedly. Griefing only (the burner receives nothing).
- Abandoned CDP0 and the five 2024 contracts: no value.
