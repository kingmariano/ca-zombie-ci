# Cat in a Box (Ethereum) — live extraction assessment

**Date:** 2026-10-12 · **Chain:** Ethereum mainnet · **Status:** read-only; PoC fork-verified only;
no mainnet transactions sent.

**Triage lead (L2-Triage-A #22):** "Cat in a Box", $214,034 live (`0x7f0a…` CDP + `0x24146d…` PSM).
**This report corrects and extends the triage:** the same protocol also operates a **v1.1 CDP**
(`0x6ffd098e…`, 427.78 stETH) and a **feeSplitStaking** contract (2.11 stETH) that the DefiLlama
adapter and the triage row missed. Total live stETH custody today is **515.78 stETH ≈ $1.31M**.

---

## 1. TL;DR

| Target | Live value (2026-10-12) | Extractable by external unprivileged attacker | Why |
|---|---|---|---|
| CDP v1 `0x7f0a0c71…` | 83.72 stETH ($212.9k) | **$0** | Collateral locked for depositors (H-O); only permissionless exit is `stabilisePeg` (redeem boxETH → stETH), capped at Σ debt = 7.66 boxETH, and boxETH buys cost ≥1.08 WETH/unit for any size >0.4 boxETH |
| CDP v1.1 `0x6ffd098e…` | 427.78 stETH ($1.088M) | **$0** | Same: Σ debt = 294.37 boxETH is the hard cap; acquiring 294 boxETH is impossible/at a loss (pool depth 9.76 boxETH total, avg buy price 1.08–1.92 WETH for 0.46–2.6 boxETH) |
| PSM `0x24146d…` | 2.17 stETH + 0.66 boxETH | **$0** | `trade()` = `CONVERTER_ROLE` only (Safe 3/5 + deployer EOA); reverts for outsiders |
| feeSplitStaking `0x320c87…` | 2.11 stETH + 1.47 boxETH | **$0** | `trade()` = `CONVERTER_ROLE` only (Safe + 3 EOAs); reverts for outsiders |
| boxFEE vault `0xE4B91f…` | 248.31 boxETH | **$0** | ERC4626 with 1:1 deposits / NAV (0.1063 boxETH/share) withdrawals — entry is an 89% loss; no boxFEE market exists |
| boxETH pools (UniV3 ×2) | 9.76 boxETH | **$0** | boxETH trades at ~par (0.9947–0.9978 stETH); redemption friction (0.19%–9.6%) plus price impact makes every round trip negative |

**Total live extractable now (E-U): $0.00 — confidence high.**
The gross ceiling of the one permissionless path (if boxETH were free) is **302.03 stETH ≈ $767,950**;
the theoretical best-case arbitrage measured on a fork is **+0.000022 stETH (~$0.06) for 2.17M gas**
(T2b), i.e. deeply negative net of gas. Honest "$0 with proof".

**Latent risk:** the `stabilisePeg` redemption is live, permissionless and hard-capped only by
outstanding debt. If boxETH is ever obtainable below ~1/(1+friction fee) — e.g. a large holder dumps
into the thin pools, or a new boxETH market appears — up to ~$750k of stETH becomes extractable
with no owner action required. The thin 0.05% pool (5.36 boxETH) is the only obstacle.

---

## 2. The protocol, in exact terms

Cat in a Box is a **stETH-collateralised CDP** protocol that mints **boxETH** ("Cat-in-a-Box
Ether"), a stETH-pegged synthetic, plus a peg-stability module and a fee-staking module.
All six core contracts are verified on Etherscan and were re-read at block 26,176,576.

| Contract | Address | Key mechanics |
|---|---|---|
| `boxsteth` (boxETH) | `0x7690202e2C2297bcD03664e31116d1dFfE7e3B73` | ERC20; `mint` = `ADMIN_ROLE` (only the two CDPs); public `burn`; broken `burnFrom` (allowance never decremented) |
| `catinaboxcdp` v1 | `0x7f0a0c7149a46bf943ccd412da687144b49c6014` | `deposit`/`withdraw`/`mint`/`repay`/`liquidate`/`setRepayFlag`/`stabilisePeg`/`poke`; ltv 9900; no minting fee; yield split by (deposited−debt) points |
| `catinaboxcdp1point1` v1.1 | `0x6ffd098e92b606b2947b89a08911c00ca06890fa` | same + 0.25% minting fee (2× charged to debt); yield split by **debt** weight (borrowers get all yield) |
| `psmstart` (PSM) | `0x24146D1B3339Cf76b455dC42e71Ea5Cdff4aE0d7` | `trade(amount)`: burn boxETH from caller → send stETH at par; `CONVERTER_ROLE` |
| `feeSplitStaking` | `0x320c871b6f7721083604FfdD8070E64c1d3c5d7C` | permissionless `deposit`/`withdraw` of boxFEE; boxETH rewards; `trade` boxETH→stETH at par (`CONVERTER_ROLE`) |
| `feeSplitToken` (boxFEE) | `0xE4B91fAf8810F8895772E7cA065D4CB889120f94` | Solmate ERC4626 over boxETH; **deposit mints shares 1:1**, redeem pays NAV |

Value-moving paths that pay `msg.sender`:

1. **`stabilisePeg(amount, _depositor)` — permissionless.** Burns `amount` of the *caller's* boxETH
   (plus a friction fee `10%·(1−debt/deposited)` paid in boxETH to the PSM), and transfers `amount`
   stETH from `_depositor`'s collateral; reduces that depositor's `deposited` and `debt` equally.
   Per call `amount ≤ debt[_depositor]/4`; across calls the total is bounded by the depositor's debt.
2. `withdraw` / `mint` / `repay` / `liquidate` / `poke` — self-service only (or no-op triggers).
3. `PSM.trade`, `PSM.synthToFeeToken`, `feeSplitStaking.trade` — `CONVERTER_ROLE` only.
4. `boxFEE.deposit/mint/withdraw/redeem` — standard ERC4626 (deposit side mispriced 1:1).

There is **no admin function that can move CDP collateral**; the admin surface is fee/pointer
settings only (`setFee`, `setMintingFee`, `setIncentivesModule`, `setFeeSplitAddress`, `setpsm`).

---

## 3. Live-state assessment (block 26,176,576, 2026-10-12)

### Custody

| Holder | stETH | boxETH | USD |
|---|---|---|---|
| CDP v1 | 83.723447 | — | $212,877 |
| CDP v1.1 | 427.783573 | — | $1,087,690 |
| PSM | 2.169523 | 0.661913 | $5,516 |
| feeSplitStaking | 2.106570 | 1.469417 | $5,356 |
| boxFEE vault | — | 248.305217 | (backs 2,336.49 shares) |
| UniV3 boxETH/WETH 0.05% | — | 5.362443 | — |
| UniV3 boxETH/wstETH 1% | — | 4.395744 | — |
| **Total** | **515.783** | | **$1,311,440** |

stETH $2,542.62 / WETH $2,543.86 (DefiLlama, 2026-10-12). CDP internals: v1 `totaldeposits`
83.5279, `totalDebt` 7.6626, `unclaimed` 3.8087; v1.1 `totaldeposits` 427.5218, `totalDebt`
294.3687, `unclaimed` 4.5766, `mintingFee` 25. Sum of per-depositor balances matches the totals
(119/63 actors enumerated from events; see `analysis/cdp_positions.json`, `cdp11_positions.json`).

### Roles (verified from RoleGranted/RoleRevoked logs + `hasRole` at block 26,176,056)

- **boxETH `ADMIN_ROLE` (mint right):** only CDP v1 and CDP v1.1. The deployer EOA and the Safe had
  it in 2023 and were revoked. → boxETH cannot be minted except against deposited stETH.
- **CDP `ADMIN_ROLE`:** Gnosis Safe `0x98e6475C01D018Ae78c02ef48738f687538226Af`, 3-of-5, all
  owners EOAs. Fee/pointer setters only.
- **PSM + feeSplit `CONVERTER_ROLE`:** the Safe, the original deployer EOA
  `0x56C40ade4C96800b13E20A71Ff60c4005F0bCF8e` (never revoked), plus two Safe-owner EOAs on
  feeSplit. These can redeem boxETH for the PSM/feeSplit stETH at par — privileged (P), and only
  the PSM/feeSplit balances (4.28 stETH, $10.9k) are reachable this way.

### Markets

- UniV3 boxETH/WETH 0.05% `0x28713959…`: 5.362 boxETH / 5.411 WETH, spot **0.9947** WETH/boxETH,
  liquidity 1.658e19 (concentrated — buying 0.46 boxETH costs an average 1.078 WETH; 2.60 boxETH
  costs 1.923 WETH/boxETH).
- UniV3 boxETH/wstETH 1% `0x703a177f…`: 4.396 boxETH / 3.520 wstETH, spot ≈ **0.9978** stETH/boxETH.
- UniV3 boxETH/WETH 1% `0x53a26afD…` and all four boxFEE pools: **dead** (liquidity 0 / dust).

---

## 4. What an attacker can and cannot do

**Can (proven on fork):**
- Call `stabilisePeg` against any of the ~45 live borrowers and receive their stETH, up to their debt,
  by burning their own boxETH — at a friction fee of 0.19%–1.10% (v1.1 best cases) or ≥5% (v1).
- Redeem every last unit of debt: **301.56 stETH** extracted in T7 with `vm.deal`ed boxETH
  (Σ debt 302.03 stETH; rounding leaves ~0.003 stETH of dust debt).
- Trigger sync/fetch accounting for any depositor (`poke`) — but `unclaimed` can only be credited
  to the depositor it belongs to (T10).

**Cannot (each proven by revert or by measured net loss):**
- Buy boxETH cheaply enough to profit: the only live pools price boxETH at ~par, and the size-dependent
  price impact makes the round trip negative at every size that matters (0.5→5 WETH buys: −$104 to
  −$6,167; the only positive point is a 0.01 WETH buy at **+0.000022 stETH gross** which costs
  2.17M gas — i.e. a net loss at any realistic gas price).
- Mint boxETH to redeem it: the v1.1 charges 0.5% (2×0.25%) minting fee; the cycle loses
  0.044–0.074 stETH even assuming par repayment (T4). The v1 (no minting fee) cannot create value
  either — minted boxETH is collateralised 1:1 by the attacker's own deposit.
- Pull collateral from other depositors: `withdraw`/`liquidate` are self-only (T9).
- Use the PSM or feeSplitStaking exits: `CONVERTER_ROLE` reverts for outsiders (T5).
- Exploit the yield accounting: weight changes always pass through a `fetch` for that account, so a
  stale-points over-claim is impossible; the pending excess is only 0.185/0.236 stETH and the mint
  fee to capture it exceeds the yield.
- Drain the boxFEE vault: no free shares, and 1:1 deposits vs NAV exits lose 89% (T6).

---

## 5. PoC / fork verification

- Project: `poc/` (Foundry 0.8.24, vendored forge-std). Test: `poc/test/CatInABox.t.sol`.
- CI: **11/11 PASS** — https://github.com/kingmariano/ca-zombie-ci/actions/runs/38254742771
  (branch `cat-in-a-box`, full final folder state; earlier runs 38253777281 and 38253195487 also passed).
- Fork: Ethereum mainnet at latest block (CI run read block 26,176,576; state dump in
  `ci-out/live-state.txt` / `ci-artifacts/result-cat-in-a-box/ci-out/live-state.txt`).

| Test | What it proves | Key numbers |
|---|---|---|
| T1 | live custody/debt/roles at fork block | 83.72 + 427.78 + 2.17 + 2.11 stETH; debt 7.66 + 294.37 |
| T2 | buy boxETH → `stabilisePeg` is unprofitable | 0.5/2/5 WETH buys → net **−0.041 / −0.544 / −2.425 stETH** (avg buy 1.078/1.360/1.923 WETH) |
| T2b | best-case tiny arb | 0.01 WETH → **+0.000022 stETH** gross, 2,173,316 gas; 0.05 WETH → −0.000021 stETH |
| T3 | wstETH-pool variant (1% fee) | −0.646 stETH on a 2 WETH round trip |
| T4 | mint→redeem→repay cycle | walk-away **−0.0742 stETH**; par-repay case **−0.0439 stETH** |
| T5 | role-gated exits revert | `PSM.trade` / `feeSplit.trade` / `PSM.synthToFeeToken` revert for outsiders; role holders asserted |
| T6 | boxFEE vault 1:1 deposit vs NAV redeem | 1 boxETH in → 0.10666 boxETH out (−89.3%) |
| T7 | gross cap = Σ debt | **301.555 stETH** extracted with free boxETH; both CDPs' debt ≈ 0 after |
| T8 | `stabilisePeg` per-call cap | debt 6.096 → 4.572 (−25%) |
| T9 | third-party withdrawals impossible | non-depositor and over-LTV withdrawals revert |
| T10 | yield cannot be redirected | Σ owing (top-6 v1 depositors) 2.316 ≤ unclaimed 3.809 stETH |

Reproduce: `bash ci/ci-run.sh cat-in-a-box` (or `FORK_RPC_URL=<rpc> forge test -vv` in `poc/`).

---

## 6. Verdict and residual risk

**E-U $0.00 (high confidence).** The protocol is a properly-collateralised CDP whose only
permissionless value-out path (`stabilisePeg`) is a Liquity-style redemption that requires the
attacker to bring boxETH, and the boxETH market is priced at ~par with negligible depth. Every
tested extraction route is either role-gated or net-negative. An honest zero.

Category totals (block 26,176,576):

| Category | USD | Notes |
|---|---|---|
| **E-U** | **$0** | no profitable unprivileged path; theoretical gross ceiling 302.03 stETH needs boxETH at ≤1/(1+fee) |
| **H-O** | **~$524k** | depositors' withdrawable collateral: 71.98 stETH (v1) + 125.60 stETH (v1.1) = 197.58 stETH now, up to +8.39 stETH `unclaimed` once fetched; plus 248.31 boxETH in the boxFEE vault redeemable by its 2,336.49 shares (holders include EOAs, the Safe and feeSplitStaking) |
| **P** | **~$10.9k** | PSM 2.1695 + feeSplit 2.1066 stETH, redeemable at par only by the Safe 3/5 / deployer EOA / 2 owner EOAs |
| **S** | ~$0 | abandoned CDP0 (223 wei), dead pools dust, five 2024 unverified contracts ($26 total) |

Residual/latent risk:
1. **Redemption overhang (main latent risk).** 302 stETH of redeemable debt vs 9.76 boxETH of pool
   liquidity. Any event that puts boxETH in an attacker's hands below ~0.99–0.995 (a dump into the
   thin pools, a new market, an OTC deal with an airdropped holder) converts directly into up to
   ~$750k of extraction. The v1.1 fee floor is 0.19% at the best borrower.
2. **Yield-farming the sole-borrower position** (v1.1 pays 100% of stETH yield to borrowers by debt
   weight): a borrower who redeems out all other debt captures ~12.8 stETH/yr, but cannot exit
   (repaying needs ~300 boxETH the market cannot supply) — the position traps ~$760k of capital.
   Not a live extraction; noted as a design hazard.
3. **Privileged keys.** The 3-of-5 Safe and the deployer EOA retain CONVERTER roles (can sweep
   $10.9k) and fee/pointer settings on v1.1. If the Safe owners are unreachable the PSM/feeSplit
   stETH becomes stranded (S), not stolen.
4. **boxFEE vault mispricing** (1:1 deposit, NAV redeem) and the **boxETH `burnFrom` allowance bug**
   (allowance never decremented → repeat-burn griefing by an approved spender) are holder harms /
   DoS, not attacker extraction.
5. Triage gap: DefiLlama's adapter tracks only 2 addresses, missing the v1.1 CDP (427.78 stETH).
   Any monitoring of this protocol must include `0x6ffd098e…` and the feeSplitStaking.

---

## 7. Methodology, sources, caveats

- Read-only: `eth_call`/`eth_getLogs` at pinned blocks; Foundry fork tests in CI; no mainnet tx.
- Sources of truth: verified Etherscan V2 sources (all six contracts + boxFEE vault), event
  enumeration (`_deposit`/`_mint`/`_withdrawal`/`_repay`/`_stabilisePeg`, `RoleGranted`/
  `RoleRevoked`, ERC20 `Transfer`), direct `balanceOf`/storage reads, UniV3 factory/slot0/reserves,
  DefiLlama prices. Corpus leads re-verified on-chain (the triage row's addresses are correct but
  incomplete).
- Caveats: (a) event-log enumeration of boxETH/boxFEE holders was truncated by the explorer's
  1,000-log page limit — holder lists in `analysis/` are marked unreliable; all relied-upon balances
  were re-read with direct `balanceOf`. (b) USD values use DefiLlama spot prices at 2026-10-12; ETH
  moves change the USD figures proportionally. (c) The v1.1 `totalPoints`-based yield model was
  reviewed analytically, not fuzzed. (d) Gas prices are not modelled beyond the measured gas of
  T2b; at any realistic gas price the +$0.06 theoretical arb is negative.
- Files: `analysis/live_state.md` (state + roles), `analysis/cdp_positions.json`,
  `analysis/cdp11_positions.json`, `analysis/src/` (deployed sources: cdp, cdp11, psmstart, synth,
  feestaking, boxfee), `analysis/read_positions.py` (multicall enumerator), `poc/` (tests),
  `ci/run.sh` (state dump), `ci-log.txt`, `ci-artifacts/`, `ci-out/`.
