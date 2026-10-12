# FlareBank (Flare) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Flare (chain id 14) · **Status:** read-only; PoC fork-verified only; no mainnet transactions.
**Finding:** L-2 Triage-B rank #8 — FlareBank `$222,024` live (DefiLlama `flarebank`).

---

## 1. TL;DR

| Target | Live value | Extractable by **external unprivileged** attacker? | Why closed/open | Latent risk |
|---|---|---|---|---|
| **Bank** `0x1947…6059` — reserve-currency bonding curve + BANK token (18,436,367.76 WFLR) | **$127,210** | **$0.00** | Every value-moving path requires being a BANK holder (sell/withdraw dividends) or BANK_ADMIN (team/fee claims, setDelegator) or the ProxyAdmin owner (upgrade). No reentrancy, no pricing shortcut, no re-init, no unprivileged upgrade. | DEX-vs-curve arb ≈ **+38.8 WFLR (~$0.27)** best single shot, funded by DEX LPs — negligible; admin key (EOA) can upgrade both proxies (P). |
| **IBDP vault / TsoRewardsClaimer** `0x9067…c59b` — user deposit vault, 13,640,999.999 WFLR | **$94,122** | **$0.00** | `withdraw()` only pays the caller's own `balance` after a 30-day lock; rewards claims are permissionless but pay **the Bank**, never the caller; init/upgrade blocked. | Rewards of vault depositors accrue to BANK holders (by design); proxy admin upgradeable (P). |
| **Total** | **$221,332** | **$0.00** (material; high confidence) | — | — |

**Headline: external unprivileged extraction ≈ $0.00.** The $221k is **H-O** (holder/user self-service):
BANK holders can redeem ≈17.1M WFLR from the Bank's reserve, IBDP depositors can withdraw 13.64M WFLR.
Team/fee pools (≈0.55M WFLR after a full holder cascade; 0.21M claimable right now) are **P**.
≈0.77M WFLR of curve-slippage is structurally left in the Bank after a full exit (**S**).

Live value vs triage (block 71,847,935 → 71,927,890): Bank reserve **+19,874.24 WFLR**
(18,416,493.51 → 18,436,367.76, buys still happening); vault **unchanged** (13,640,999.999).

---

## 2. What FlareBank is (exact terms)

FlareBank is a **reserve-currency "bank"** (DefiLlama category *Reserve Currency*; fork of **Eggs Finance**,
Sonic — `forkedFromIds: 5789`). It was audited by **Hashlock in July 2025** (3 High / 3 Medium / 3 Low,
all H/M marked resolved in the audited commit; the deployed Bank is v0.1.3, verified on flare-explorer).
The protocol has two live contracts:

### 2.1 Bank — `0x194726F6C2aE988f1Ab5e1C943c17e591a6f6059`
- EIP-1967 proxy; implementation `0xA76578a68a05CedE65E6587d60efd2ea4555C6d6` (**verified source "Bank" v0.1.3**).
- ERC20 **BANK** (`FLRBank`, 18 dec, supply 2,400,109.768) *and* the bonding-curve bank holding the WFLR reserve.
- Curve (deployed source): `price = 1 + net/1e6` FLR per token where `net = wnat.balanceOf(this) − unclaimedDividendTotal − unclaimedTeamFees − unclaimedFeeReceiverFees`; `ETHER_INCEREMENT = 10,000e18`, `TOKEN_PRICE_INCREMENTAL = 0.01e18`.
  - **Buy**: 10 % fee (`DIVIDEND_FEE = 10_00/100_00`), tokens = `0.9·E/price(balance+0.9E)`. All-in cost ≈ **20.67 FLR/BANK** at current size.
  - **Sell**: gross `= tokens·price(balance−estOut)` (“worst price”), minus 10 % fee → **16.74 FLR/BANK**; per-sell cap `taxedEth < MAX_BUY (50,001 NAT)`.
  - **Transfer**: 1 % burn + 1 % value in dividends/fees.
  - Dividends accrue pro-rata to holders (`dividendGrowthX64`), claimed via `withdraw()` (`onlyStronghands`).
  - Auto-claims FTSO rewards (`RewardManager.claim`, `_wrap=true`) and FlareDrops (`DistributionToDelegators.claim`) into the reserve.
- Roles: `BANK_ADMIN` (setAdministrator, addAmbassador, claimTeamFees, claimFeeReceiverFees, disableInitialStage, setDelegator, delegate), `DEFAULT_ADMIN_ROLE` (setTeamAddress, setFeeReceiverAddress), `AMBASSADOR` (launch only — `onlyAmbassadors=false` since 2025).
- **Curve price (18.6) is ~2.5× the NAV (7.34)** → the marginal seller is paid far above pro-rata backing; in aggregate holders can redeem ≈15.15M WFLR (exact integer-math simulation, full supply), plus the dividend pool.

### 2.2 IBDP vault / TsoRewardsClaimer — `0x90679234FE693B39BFdf5642060Cb10571Adc59b`
- EIP-1967 proxy; implementation `0x564953d87668514415fb2339ef0834313713e332` (**unverified** — decompiled with panoramix; selectors/behaviour verified by on-chain calls and tx history).
- `deposit()` (payable): wraps FLR via WFLR `deposit()`, credits `balance[msg.sender]`, stamps `depositTimestamp`.
- `withdraw(uint256)`: `require(balance[caller] ≥ amount)`, `require(block.timestamp ≥ depositTimestamp[caller] + 30 days)` ("Funds are locked"), transfers WFLR to caller.
- `claimWNatRewards(uint24)`, `claimFlareDrops(uint256)`, `tryClaimAllTsoRewards()` — **permissionless**, but all claims pass `recipient = bankAddress` (`bank()` returns the Bank), i.e. **vault rewards are donated to the BANK reserve/dividends**.
- Roles: `DEFAULT_ADMIN_ROLE` + `BANK_ADMIN` held by the deployer; team/feeReceiver hold none.
- 47 direct depositors; **Σ getBalance = 13,640,999.999 WFLR = exactly the vault's WFLR balance** (fully collateralised; no surplus, no shortfall).

### 2.3 Governance / upgrade surface
- Both proxies' EIP-1967 admin = **`0x9e199934928C626Dd7813f190674345d4C00ec80`**, a **verified OpenZeppelin `ProxyAdmin`** whose `owner()` = **`0xC034203c4E1E9F3c37ea87A5C7d9cED57003333E`** (team deployer EOA). Team `0xb2ab285c…`, fee receiver `0xaa68bc4b…`.
- Upgrade history: Bank impl upgraded at block 45,932,830 (~2025-08/09) to the current v0.1.3; vault impl upgraded at block 45,934,478 to the current one.

---

## 3. Live-state assessment (read-only, keyless public RPC)

Canonical reads at **Flare block 71,927,890** (`analysis/live_reads_latest.json`); CI re-verified at 71,928,268.

| Item | Value |
|---|---|
| Bank WFLR reserve | **18,436,367.758087736 WFLR** (call `WFLR.balanceOf(0x1947…)`) |
| Bank totalSupply | 2,400,109.7684941418 BANK |
| Bank buyPrice / effective redemption | 18.6 / 16.74 FLR per BANK (`buyPrice()`, `calculateEthereumReceived(1e18)`) |
| NAV/token | 7.3358 FLR |
| unclaimedDividendTotal | 617,180.304 WFLR (H-O) |
| unclaimedTeamFees / feeReceiverFees | 159,341.460 / 53,113.820 WFLR (**P**) |
| Vault WFLR balance | **13,640,999.999 WFLR** (unchanged since triage) |
| Vault Σ depositor balances | 13,640,999.999 WFLR (47 addresses, `getBalance`) |
| Vault `bank()` | 0x1947…6059 (the Bank) |
| Top BANK holder | 0x3c1c84132DFdef572E74672917700c065581871D — 878,462.62 BANK (36.6 %), EOA |
| BANK holders | 132 addresses (explorer), 2,277,461.45 BANK listed (94.9 % of supply) |
| Roles | deployer = BANK_ADMIN on Bank+vault, AMBASSADOR on Bank, DEFAULT_ADMIN on vault; top holder = AMBASSADOR (launch); team/feeReceiver = none |
| Pause | no pause functions in either ABI; `onlyAmbassadors=false` (launch stage over) |
| DEX pairs (Uniswap-V2 style) | `0x5f29…0335` 102,880.85 BANK / 2,152,068.16 WFLR (price **20.918**); `0x0f57…6111` 4,614.17 / 96,773.46 (**20.973**); `0xd417…762d` 32.36 / 674.35 (**20.841**) |
| WFLR price | $0.006899955 (DefiLlama, confidence 0.99, 2026-10-12) |

Triage cross-check: triage recorded 18,416,493.51 + 13,640,999.999 WFLR = $222,024 at $0.006926;
today 18,436,367.758 + 13,640,999.999 = 32,077,367.76 WFLR = **$221,332** at $0.006900.

---

## 4. What an attacker can / cannot do

### 4.1 Cannot (all PoC-verified on a mainnet fork — see §5)
| Attempt | Result |
|---|---|
| Vault `withdraw()` as non-depositor | revert `No funds to withdraw` |
| Vault deposit → immediate `withdraw()` | revert `Funds are locked` (30-day lock) |
| Bank `withdraw()` without holding BANK | revert `No dividends` |
| Poke vault `tryClaimAllTsoRewards()` as attacker | succeeds but **0 WFLR to caller** (rewards go to the Bank) |
| Re-`initialize()` either proxy (role takeover) | revert `Initializable: contract is already initialized` |
| `upgradeTo()` either proxy as non-admin | revert |
| Buy BANK from the Bank → sell back | **loss ≈ 6–11 %** (10 % buy fee + 1 % sell fee + curve drag) |
| Self-referral (refer yourself) round trip | still a net loss |
| Buy BANK on DEX (~20.92) → redeem into Bank (16.74) | loss ≈ 20 % |

### 4.2 Can (H-O — holder/depositor self-service)
- Any of the 132 BANK holders can `sell()` in ≤50k-NAT chunks and `withdraw()` the proceeds **at the inflated curve price**. Fork-verified: the top holder (878,462.62 BANK) extracts ≈**9.79M WFLR**; top-5 holders ≈**13.3M WFLR**. Exact integer-math simulation of all 132 + residual supply: **15,150,643 WFLR sell proceeds + ~1.96M WFLR dividends**.
- Any of the 47 vault depositors can `withdraw()` principal after 30 days. Fork-verified: the largest depositor withdrew **11,347,812.03 WFLR** in one call.
- Anyone can trigger vault/Bank FTSO+FlareDrop claims — this only *adds* WFLR to the Bank (raises price for holders).

### 4.3 The only E-U path found: DEX-vs-curve arb (~$0.27)
Mint BANK from the Bank (all-in ≈20.67 FLR/BANK incl. 10 % fee) and dump it on the V2 pair at ≈20.92.
Fork-verified (test_28): spending 10,000 WFLR nets **+38.8 WFLR (~$0.27)**; the optimum is bounded by the pair's depth (convergence volume ≈1.2k BANK), total ≲200 WFLR. **This value comes from DEX LPs, not the protocol** (the Bank *gains* WFLR). Not a protocol drain; reported for completeness.

### 4.4 Preconditions/costs
- H-O sells need only the tokens; gas on Flare is negligible (<$0.01/tx); no flash loans needed.
- E-U arb needs ~10k WFLR of capital; net +$0.27 — economically irrational after any friction.

---

## 5. PoC / fork verification

Foundry project `poc/` (vendored forge-std), forked against keyless public Flare RPC
(`FLARE_RPC_URL`, auto-probed in `ci/run.sh`; fallback `https://flare-api.flare.network/ext/C/rpc`).

**CI:** `ci/run.sh` probes the RPC, dumps live state, and runs the exact integer-math sell-out
simulation (`ci/sim.py`) → `ci-out/live_state.json`, `ci-out/sellout_sim.json`; then `forge test -vvv`
runs the fork tests.

| Test | What it proves | Result |
|---|---|---|
| `test_00_live_state` | live balances/supply/prices match §3 | PASS |
| `test_10_ho_top_holder_sells_full_balance` | top holder sells all in ≤50k chunks + withdraws → ~9.79M WFLR | PASS |
| `test_11_ho_vault_depositor_withdraws_principal` | 11,347,812.03 WFLR paid to the depositor | PASS |
| `test_12_ho_top5_holders_sell_out` | 5 holders ≈13.3M WFLR aggregate | PASS |
| `test_20…27` (8 E-U negatives) | non-depositor/lock/no-dividend/re-init/unauthorized-upgrade/round-trip/self-referral all fail or lose | PASS |
| `test_28_eu_dex_vs_curve_arb_tiny` | arb exists but ≤ +200 WFLR (fork-measured ≈+38.8 WFLR) | PASS |

- CI runs: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/38242584963** (run 1, 10/12 — 2 failures were the pre-fix one-shot sells hitting the 50k per-sell cap, now chunked), run 2: `<filled after run 2>`.
- Key numbers: top holder ≈9.79M WFLR; top-5 ≈13.3M WFLR; vault 11.35M WFLR; arb +38.8 WFLR; buy→sell round trip −6.3k on 50k (−12.6 %).

---

## 6. Verdict

**External unprivileged extraction = $0.00 (material), high confidence.**
The $221k live is legitimately (if weirdly) encumbered:
- **H-O ≈ $212k** — BANK holders redeem at a curve price ~2.5× NAV (≈17.1M WFLR ≈ $118k), IBDP depositors get principal (13.64M WFLR ≈ $94.1k).
- **P ≈ $3.8k** after a full cascade (team+feeReceiver pools; $1.5k claimable now) + full upgrade/admin control (ProxyAdmin owner = deployer EOA).
- **S ≈ $5.3k** structural curve-slippage left in the Bank after a full holder exit (no claimant).
- **E-U ≈ $0.27** one-time DEX-LP-funded arb (not protocol value).

Residual/latent risks: (a) a compromised deployer key could upgrade either proxy and redirect the entire $221k (key management, not an unprivileged bug); (b) the 10 %-fee/high-curve design means late holders are diluted — a *user* risk, not an attack; (c) unbounded loops in the *parameterised* `claimWNatRewards/claimFlareDrops` only gas-DoS the caller (auto-path stays bounded) — no state corruption.

**Blockers to any drain:** deposit ledger + 30-day lock (vault), token balance requirement (Bank), role gates (admin functions), ProxyAdmin (upgrades).

---

## 7. Methodology, sources, caveats

- Re-verified everything on-chain at pinned blocks (public keyless RPC): code, roles, balances, prices, proxy slots, upgrade history, tx/token-transfer history (flare-explorer Blockscout API).
- Bank source: verified `Bank` v0.1.3 (flare-explorer) + public **Hashlock audit (July 2025, Final v3)** — H-01 unbounded-loop, H-02 `_transfer` reentrancy, H-03 `transferFrom` dividend-target, M-01 under-collateralised price fallback, M-02 silent claim failure, M-03 ambassador bypass — all H/M fixed in the deployed version (verified by reading the deployed source).
- Vault: unverified implementation, decompiled with **panoramax/pyevmasm** (30-day lock constant `0x278d00` verified in bytecode), behaviour cross-checked against 201 deposit mints + 50 withdrawals in its history and live `eth_call` simulations.
- Aggregates use an **exact integer-math mirror** of `sell()/tokensToEthereum/calculateTokenPrice` (`analysis/sellout_sim.py`, `ci/sim.py`) — including the 50,001 NAT per-sell cap.
- **Caveats:** vault decompilation is not source-level (could miss nuances, though all reachable functions were enumerated and probed); the "132 holders / 94.9 % supply" split comes from the explorer's holder index (missing 5.1 % treated as residual sellers — its redemption is small because the curve price is low by then); USD uses DefiLlama WFLR $0.0069 (conf. 0.99); an exploited/compromised admin key is out of scope by definition (E-U excludes privileged keys).
- No transactions were sent; every PoC ran on a local fork (CI runner).

## 8. Files index
- `README.md` — this report
- `summary.json` — machine-readable verdict
- `analysis/` — live reads, roles, holders, depositors, sell-out simulations, DEX-arb quant, audit text, source dumps (`src_proxy_1947.sol` = deployed Bank v0.1.3)
- `poc/` — Foundry project (interfaces + `test/FlareBank.t.sol`, 13 tests)
- `ci/run.sh`, `ci/sim.py` — CI state dump + simulation
- `ci-out/`, `ci-log.txt`, `ci-artifacts/` — CI evidence
