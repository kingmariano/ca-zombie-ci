# Narwhalswap (BSC) — Zombie-Hunt II / L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** BNB Smart Chain (56) · **Live block of record:** 127,222,666 (state dump) · 127,227,511 (fork PoC runs)
**Status:** read-only; PoC fork-verified only; no mainnet transactions. Folder: `/home/heisenberg/CA/narwhalswap/`.

---

## 1. TL;DR

| Target | Live custody (block 127.2M) | Extractable by an unprivileged outsider | Why closed / open | Latent risk |
|---|---|---|---|---|
| Narwhalswap factory + 96 pairs | **$226,772 hard-asset reserves** (≈ $365k if the NAR side is scored at pool price) | **$0.00** | V2 pair math intact; no balance/reserve excess (7 dust positions ≈ <$0.001); every LP claim needs LP tokens; NAR/THUGS both carry transfer taxes that make round-trips lose 10–56% | — |
| NAR/WBNB pair `0xb6b0ba4e…` (top pair) | 5,444,067.42 NAR + 181.4527 WBNB ($134,901 hard side; $269,802 both sides at pool price $0.0248) | **$0.00** | 80.38% of the LP sits in `NLPLock` (onlyOwner = team EOA); the rest is farm-staked or EOA-held; the NAR side is only sellable into a 181-WBNB pool, and NAR charges 5% per transfer | **P:** team `NLPLock.withdraw()` can pull 145.86 WBNB ($108,438) + 4.376M NAR |
| WBNB/THUGS pair `0x40ff83ac…` | 84.5312 WBNB + 4,302.49 THUGS ($62,845 hard side) | **$0.00** | 93% of LP = one dormant EOA; the pair is **not whitelisted** in the THUGS token → the token burns 5–50% on every buy/sell; a fork round-trip cost 55.9% | H-O/S: dormant EOA key |
| WBNB/BUSD pair `0x5ec32c21…` | 13.472 WBNB + 10,069.6 BUSD ($20,090) | **$0.00** | 81.1% of LP staked in the gen-1 V1 farm (stakers' claims), 11.8% EOA, 4.2% in farm V2 | — |
| Farms (V1/V2/V3/tier/Dividend, 15 contracts) | LP 3,832.93 + 231.53 + 36.83; NAR reward pots **1,695,618 NAR** (farm V2 pot $5,074; total $42,016 at pool price) | **$0.00** | All value-moving entry points require the caller's own `_balances`/rNLP (or `nard`) — fork-proven gates; `seize()` is team-only; `buffRateReporter` victim condition is unreachable on live state; `updateBuffRate` reverts for zero/old accounts (griefing only) | **P:** team `seize()` sweeps all non-LP farm tokens (NAR pots); NAR `mint` cap leaves 284,832 NAR mintable by the team |
| `NarwhalCollecter` (factory `feeTo`) | 0.0552 WBNB + LP in 38 pairs ≈ **$55 total** | **$0.00** | `convert()` is permissionless but pays the caller nothing: it burns the *Collecter's own* fee-LP and locks proceeds as NAR/BNB LP (“store in this forever”); threshold 0.1 WBNB | Sandwichable dust (≤ $1 theoretical) |

**Total live extractable by an external unprivileged attacker: $0.00 (high confidence).**
Dust exception: 7 of 96 pairs carry un-owned fee/reflection accrual (largest: 10.55M PBANK) worth **< $0.001 realizable**; `skim` pays it to the caller and nothing else.

---

## 2. Scope and what was checked

Target = every live value-bearing surface of the Narwhalswap protocol on BSC:

1. **Factory** `0xB9fA84912FF2383a617d8b433E926Adf0Dd3FEa1` — source-verified `NarwhalswapFactory` (Sourcify runtime match, solc 0.6.12) — 96 pairs, `feeTo = 0x7f8a46ec…`, `feeToSetter = 0xb104AE8b…` (team EOA).
2. **All 96 pairs** — token0/token1, reserves, LP supply, live balances, full excess scan, codehash uniformity.
3. **NAR token** `0xa1303E6199b319A891b79685f0537D289af1FC83` — verified `NarToken`; mint gated by 3 minters/team; 2.5% burn + 2.5% reward fee per transfer; `_openTransfer = true`.
4. **Farms**: NarwhalReward V1 ×2 (`0x186be2a9…`, `0xbb38f755…`), NarwhalRewardV2 ×2 (`0x1D227F7e…`, `0x6dA9Ee0c…`), NarwhalRewardV3 ×2 (`0xbe858122…`, `0x268a2c1a…`), tier farms (`0x3dfb186e…`, `0xe6e0646b…`, `0xaaa6ddb2…` …), DividendV2/V3 ×3 (`0xb85a8c26…`, `0xc8e70639…`, `0xf7a36c87…`) — full state + accounting audit.
5. **`NarwhalCollecter`** `0x7f8a46EC48442d9EBF28fBC1144A83f8BC53F7e9` (feeTo) — verified `NarwhalCollecter`; `convert(token0,token1)` audited and fork-executed.
6. **`NLPLock`** `0x07f1B50D5ae24eC41aA7269d65a5e23e8401542A` — the 80.4% NAR/WBNB LP locker; verified `NLPLock`.
7. **THUGS token** `0xE10e9822A5de22F8761919310DDA35CD997d63c0` (verified `ThugsToken`) — dynamic burn curve, TWAP source, whitelist state; both its markets (Narwhal pair + BSCSwap pair `0x71c1B630…`, 3,688 WBNB).
8. **Router/aggregator suite** (NarwhalRouter `0xe85c6ab5…`, NarwhalSwap aggregators, V3 routing suite) — stateless; pull from `msg.sender`, pay `msg.sender`; owners can only sweep dust.
9. **Adjacent contracts** mapped by child audit: 44 `FryingDutchMan` servicers (all 0 BNB, no principal), The Grand Banks family (small residuals), NarCard/NarNft (no native value), SmartChef (634 NAR).

---

## 3. Why the attacker gets $0 — mechanism by mechanism

### 3.1 Pair math is intact; there is no free balance to skim
Standard Uniswap-V2 pair code (`NarwhalswapPair`, verified inside the factory bundle). Every state-changing pair function (`mint`/`burn`/`swap`/`sync`) syncs reserves to the *actual* balances, so a pair can only carry excess if someone transferred tokens to it directly or a reflection token accrues value to it without a sync.

Full scan of all 96 pairs at block 127,222,666: **7 positions with excess**, all dust:
- `0xc2b0fec1…` PBANK/WBNB: 10,548,636 PBANK (the whole WBNB side of that pair is **0.00163 WBNB ≈ $1.22**; the excess realizes ~1e-8 WBNB),
- 4 HYPR pairs: 0.0007–0.0018 HYPR each (HYPR ≈ $0.18 ⇒ ≈ $0.0006 total),
- COM/WBNB: 0.0111 COM (pair WBNB side = 4.78e-7 WBNB),
- KTN/WBNB: 12,119 units ≈ 1e-5 KTN.
Total realizable < **$0.001**. `skim()` on the three funded pairs pays exactly **0 wei** (fork-verified). The dead pair `0x9b7b76fb…` (token without code, zero reserves) is inert.

### 3.2 Nobody can take the pools' WBNB without giving equal value
The three funded pairs' hard sides are only reachable by either (a) burning LP tokens (LP-gated), or (b) swapping the paired token in:
- **NAR/WBNB**: buying NAR requires selling WBNB, and the NAR token itself takes 5% (2.5 % burn + 2.5 % reward) on every transfer — fork round trip of 1 WBNB returned **0.8976 WBNB (−10.24 %)** before even considering market risk (test `test_nar_pair_roundtrip_is_a_loss`).
- **WBNB/THUGS**: the Narwhal pair is **not whitelisted** in the `ThugsToken` transfer hook, so the token burns a dynamic 5–50 % slice on every buy *and* sell. Live TWAP = 50.24 tokens/BNB ⇒ burn = **33.49 %**; fork round trip of 0.5 WBNB returned 0.2206 WBNB (**−55.9 %**) (`test_thugs_burn_tax_on_narwhal_pair`).
- **WBNB/BUSD**: fair-value stable swap; the 0.3 % fee makes any flash-arb negative; pool-implied 747.4 BUSD/WBNB vs market 743.1 (0.6 % apart) — below fee + gas.

### 3.3 LP claims are strictly LP-gated — and 80.4 % of the biggest pool's LP is the team's
`pair.burn(to)` redeems pro-rata to whoever holds LP. LP distribution of the top pair (verified by direct `balanceOf`/holder scan):
- `NLPLock` **20,099.44 LP (80.383 %)** — `withdraw()` is `onlyOwner` and reverts for anyone else (`Ownable: caller is not the owner`, fork-proven); owner = `0xb104AE8b…` (team). Unlock time (2020-11-11) passed years ago. ⇒ **P** (145.86 WBNB = $108,438 + 4.376M NAR), not E-U.
- Farm-staked: 2,243.79 (V2) + 1,291.98 (V3) + 297.16 (V1) LP; EOA `0x242fb607` 560.90 LP; remaining ≈ 511 LP across small EOAs. ⇒ H-O.
- WBNB/THUGS LP: 93 % held by EOA `0x4d710603238427ae805b980bab8261624f5260c7` (vintage 2020-21, nonce 1,577). ⇒ H-O (or S if the key is lost).
- WBNB/BUSD LP: 81.1 % in the V1 farm, 11.8 % EOA `0xa9d5f138`, 4.2 % farm V2. ⇒ H-O.

### 3.4 Farm accounting has bugs — but none reachable for profit
- **`buffRateReporter(account)`** pays the caller a +10 % power boost only if `maxBuffRate < victim.currentBuffrate`. Verified on live state for **all 20 stakers**: the condition is false for every one of them (their buffrates never exceed their segment max), so the branch is dead. Call is a no-op for an attacker (`test_farm_buffRate_loops_are_broken_gates_only`).
- **`updateBuffRate(account)`** loops `for (uint8 i = 0; i < daysCalculate; i++)` over `(now − timeStamp)/1 days`. For any fresh account (timeStamp = 0 ⇒ ~20,700 days) or any account staked >255 days ago, the `uint8` counter overflows at i = 255 → revert. Griefing only; no value moves.
- **Withdrawals** require both the farm's `_balances[msg.sender]` and `rnlp.balanceOf(msg.sender)` (and an rNLP allowance to the farm). Fork-proven: a non-staker reverts; a live staker with 233.89 LP but 0 allowance reverts; the staker with max allowance withdraws normally (H-O, needs one `approve` if never given).
- **Reward pots are ≈ fully allocated**: farm V2_narwbnb's 204,706.95 NAR pot is 99.2 % claimable by the current rNLP holders (`earned()` summed over the full holder table = 203,081.26 NAR). A new staker accrues from staking time only (reward rate is now dust: 4.04e8 wei/s ≈ 0.0000000004 NAR/s).
- `seize()` is `onlyGovernance` (team) on all farms → **P**.

### 3.5 `NarwhalCollecter.convert()` is permissionless but pays nobody
`convert(token0,token1)` burns the **Collecter's own** fee-LP for the pair, swaps the proceeds to WBNB and (over threshold 0.1 WBNB) mints NAR/BNB LP **to itself, locked forever** (the NAR pair is explicitly excluded). Fork-executed: the caller's WBNB/NAR deltas are **exactly 0**; the Collecter's WBNB moves 0.05523 → 0.06048 (still below threshold). Total Collecter value ≈ **$55** (0.0552 WBNB + $13.66 of LP in 38 pairs) — and it is not payable to anyone.

### 3.6 Token-side gates
- **NAR `mint`**: `require(_minters[msg.sender] || _teamWallet == msg.sender)` — an outsider reverts `!minter`. Remaining mintable under `_maxSupply` (21M − supply 13.863M − burn 6.852M) = **284,832 NAR**; the two farm minters only mint the dust `_initReward` (≤ 2.44e14 wei) inside `checkHalve`, to the farm — never to the caller.
- **rNLP `mint`**: `minter` = the farm ⇒ outsider reverts `!minter` (fork-proven).
- **THUGS**: no public mint (whole supply 650,510; 67.7 % already at `0x…dEaD`).
- **BUSD/USDT/WBNB/BTCB**: canonical contracts.

### 3.7 Prior incidents check
No live exploit path was found; historical notes (dead BSCSwap launch pair still holding 185,306 THUGS + 3,688 WBNB; THUGS dynamic burn curve) concern the THUGS token's own economy, not Narwhalswap custody. `migrateToGrandV2` is hard-gated to `block.number < 7,076,050` (long past) — dead. No other migration path exists.

---

## 4. Live-state assessment (addresses, roles, balances — block 127,222,666 unless noted)

| Contract | Address | State that matters |
|---|---|---|
| Factory | `0xB9fA84912FF2383a617d8b433E926Adf0Dd3FEa1` | code 10,705 B; `allPairsLength()` = **96**; `feeTo` = Collecter; `feeToSetter` = `0xb104AE8b…` |
| NAR/WBNB pair | `0xb6b0ba4e208ab93602be7a81f1400a7c7daad1f2` | 5,444,067.42 NAR + 181.4527 WBNB; LP 25,004.55; excess 0 |
| WBNB/THUGS pair | `0x40ff83ac2890dd5469f5eca2c17dcaf10ee09957` | 84.5312 WBNB + 4,302.49 THUGS; LP 273.568 |
| WBNB/BUSD pair | `0x5ec32c21c9a6215d239f2bd0df22d7632b4717c3` | 13.472 WBNB + 10,069.6 BUSD; LP 285.471 |
| BTCB/NAR pair | `0x6658cd8591285775fd31d525fc2b0f3b1dde9b47` | 0.0396849 BTCB + 128,606 NAR; LP 44.358 |
| feeTo / NarwhalCollecter | `0x7f8a46EC48442d9EBF28fBC1144A83f8BC53F7e9` | 0.0552 WBNB; LP in 38 pairs ≈ $13.66; `threshold` = 0.1 WBNB; `owner` = team |
| NLPLock | `0x07f1B50D5ae24eC41aA7269d65a5e23e8401542A` | 20,099.44 NLP (80.383 % of pool); `owner` = team; `unlockTime` = 1,605,109,215 (2020-11-11) |
| NAR token | `0xA1303E6199b319A891b79685f0537D289af1FC83` | supply 13,862,957.889; `_openTransfer` true; burn pool `0x7777…7777` holds 11,098,868.48; minters = farms ×2 + team |
| farm V1 NAR/WBNB | `0x186be2a9f0e9c92b880bbd3ec1f35f422f0d8835` | holds 297.1567 LP (staked 296.1557; **1.001 LP unaccounted ⇒ S**); NAR 0.57; `_emergencyStop` = true; strategy live |
| farm V1 WBNB/BUSD | `0xbb38f7551025a433f36590be85271110212655de` | holds 231.532 LP (81.1 % of the pool, fully staked); NAR ≈ 0; `_emergencyStop` = true |
| farm V2 NAR/WBNB | `0x1D227F7e283D653a60F94d2350CAB7a49bB85C6f` | 2,243.792 LP staked; **NAR pot 204,706.95** (99.2 % claimed by stakers); `_powerStrategy` live |
| farm V2 WBNB/BUSD | `0x6dA9Ee0c0571b63e38950D1e12e835D5343f601B` | 11.944 LP staked; NAR pot 46,039.76 |
| farm V3 NAR/WBNB | `0xbe85812237741d75f81aebf1d9af52d544542168` | 1,291.98 LP staked; NAR pot 19,694.0; `_periodFinish` 2026-10-13 (still re-arming) |
| farm V3 BTCB/NAR | `0x268a2c1acbeee3b74616b9fe3f07c1bf80841e5d` | 36.8345 LP (**83 % of the BTCB/NAR pool**); NAR 5,176.73 |
| tier farms | `0x3dfb186e…`, `0xe6e0646b…`, `0xaaa6ddb2…` | NAR pots 8,113.73 / 3,769.51 / 73,665.16 (no LP) |
| Dividend V3 #2 | `0xf7a36c87c3a8909949638120f23cd721bf572032` | holds 1,333,817.14 NAR; 987,741 NAR staked; receipts token `0x4bbb2750…`; `setUser/setStake` gated to `SetUser` (`onlyOwner`) |
| THUGS token | `0xE10e9822A5de22F8761919310DDA35CD997d63c0` | not paused; Narwhal pair whitelisted = false; BSCSwap pair whitelisted = **false**; TWAP 50.24 tok/BNB ⇒ burn 33.49 % |

**USD basis:** WBNB $743.449, BUSD $1.00043, USDT $0.99920, BTCB $82,832.20 (DefiLlama, 2026-10-12), NAR pool-implied $0.024779 (circular; flagged). Hard-asset reserves across all pairs = **$226,772**; with the NAR side scored at pool price the notional is **$364,953** (the NAR half is not realizable — total exit liquidity for all NAR is the pool's 181.45 WBNB).

**Accounting split (pair reserves + farm pots):**
- **E-U = $0.00** (dust < $0.001).
- **H-O ≈ $118,335 hard side**: WBNB/THUGS $62,845 (EOA) + NAR/WBNB non-locker side $26,463 + WBNB/BUSD $20,090 (stakers/EOA) + BTCB/NAR $3,287 (V3 farm stakers) + other pairs ≈ $5,640; plus NAR-denominated claims: farm pots 1,695,618 NAR ($42,016 at pool price, exit-limited); H-O + pots = $160,351 and DIV stakers' 987,741 NAR.
- **P = $108,438 (locker's WBNB side) + 4.376M NAR ($108,438 at pool price)**; plus team-only `seize()` over all farm pots (NAR), `setFeeTo`, and a 284,832-NAR mint allowance. A full team exit (burn locker LP + dump NAR) nets ≈ $129k in WBNB terms.
- **S ≈ $56**: 1.001 unaccounted LP in farm V1 (≈ $0.8), MINIMUM_LIQUIDITY 1,000 wei LP per pair, the <$0.001 skim dust, and the Collecter's by-design-locked NAR/BNB LP (≈ $55 transformable by anyone but payable to nobody). Plus 11.1M NAR parked at `0x7777…7777` (EOA, never outbound) — P if the team holds that key, S if destroyed; not counted above.

---

## 5. What an attacker can and cannot do (exact call paths)

| Call | Precondition | Result |
|---|---|---|
| `pair.skim(attacker)` on the 3 funded pairs | none | pays **0 wei** (no excess) — verified |
| `pair.skim(attacker)` on PBANK/WBNB | none | pays 9.49M PBANK dust (token takes ~10 % itself); **no WBNB** |
| `pair.swap(...)` on any pair | supplying the paired token + fee | fair AMM swap; NAR path loses 5 % tax, THUGS path loses 5–50 % burn; fork-verified losses |
| `pair.burn(attacker)` | owning LP of that pair | pays pro-rata, **LP-gated**; NAR side is taxed 5 % |
| `NLPLock.withdraw()` | `msg.sender == 0xb104AE8b…` | reverts for anyone else (fork-proven) |
| `farmV2.withdraw(1e18)` / `emergencyWithdraw()` | farm `_balances ≥ amount` + rNLP + allowance | non-staker reverts; zero-balance `emergencyWithdraw` reverts `Cannot withdraw 0` |
| `farm.getReward()` | accrued `earned()` must be > 0 | non-staker receives 0 (fork-proven) |
| `farm.seize(NAR, x)` | `msg.sender == _governance` | reverts `not governance` |
| `farm.buffRateReporter(victim)` | live victim with `buffrate > maxBuffRate` | **no such victim exists** (all 20 stakers checked); no-op |
| `farm.updateBuffRate(x)` | none | reverts (uint8 loop overflow) for fresh/old accounts — griefing only |
| `NarwhalCollecter.convert(GOLD,WBNB)` | none | permissionless, but **caller receives nothing** (fork-proven); Collecter value self-locks |
| `NarwhalCollecter.convert(NAR,WBNB)` | — | reverts `NarwhalswapCollector: This is NAR pair` |
| `nar.mint(attacker, x)` / `rnlp.mint(attacker, x)` | minter/teamWallet | reverts `!minter` |
| `factory.setFeeTo(attacker)` | `msg.sender == feeToSetter` | reverts `Narwhalswap: FORBIDDEN` |
| flash-loan-style round trips | capital | all unprofitable: NAR 5 % tax/two legs, THUGS 33.49 % burn/two legs, stables inside fee band |

---

## 6. Fork PoC / verification

**Implementation integrity (CI job `ci/integrity.py`):** the deployed pair implementation is *proven* to be the Sourcify-verified `NarwhalswapPair` source: recompiling the verified `NarwhalswapFactory.sol` bundle (solc 0.6.12, optimizer 200, evm=istanbul) reproduces a pair creation code that differs from the on-chain code **only** in the 51-byte IPFS metadata block; splicing the on-chain metadata in yields
`keccak256(creationCode) = 0x8a30072f74333632d4cca8ddbfc623703398716ee4a6a93f48d4fc610b5b4cf4 = factory.pairCodeHash()` exactly, and the spliced runtime's sha256 equals the on-chain runtime's (`9c1dc30c92ab6bdbf1ec710407bd38001c11ab44d5fcf4662dbb22a622f56890`). All 96 pairs also share one byte-identical 8,701-byte runtime. ⇒ the tested behaviour generalises to every pair.

- Project: `poc/` (Foundry, vendored forge-std). Tests: `poc/test/Narwhal.t.sol` — **13/13 PASS** (local run, block 127,227,511; CI re-run linked below).
- Custom CI job `ci/run.sh` → `ci/live_state.py` re-scans the factory, all 96 pairs (reserve/balance/excess), the farm family and the locker **inside CI** and writes `ci-out/live-state.json` (artifact `result-narwhalswap`).

Key fork numbers (from the local green run):
| Test | Evidence |
|---|---|
| `test_skim_excess_is_dust_only` | 7/96 excess positions; total WBNB excess 0; top-3 skim pays 0; PBANK skim pays dust only |
| `test_nar_pair_roundtrip_is_a_loss` | quoted 29,749.21 NAR → received 28,261.75 (5 % tax) → round trip 1.0000 → 0.8976 WBNB (−10.24 %) |
| `test_thugs_burn_tax_on_narwhal_pair` | buy 0.5 WBNB → 16.775 THUGS after 33.49 % burn; full round trip → 0.2206 WBNB (−55.9 %) |
| `test_nlp_locker_withdraw_is_only_owner` | 20,099.44 LP locked; `withdraw()` reverts for non-owner |
| `test_farm_v2_withdraw_requires_stake_and_rnlp` | non-staker reverts; `emergencyWithdraw` reverts; `getReward` pays 0; `seize` reverts |
| `test_farm_v2_staker_withdraw_needs_rnlp_approval` | 233.89-LP staker with 0 allowance reverts; max-allowance staker withdraws 1 LP (H-O path works) |
| `test_farm_buffRate_loops_are_broken_gates_only` | `buffRateReporter` no-op; `updateBuffRate` reverts (V2 and V1) |
| `test_collecter_convert_permissionless_but_pays_nobody` | caller deltas 0; Collecter WBNB 0.05523 → 0.06048 |
| `test_div_v3_2_withdraw_gate`, `test_nar_mint_gate_and_cap`, `test_rnlp_mint_gate`, `test_factory_state_and_setFeeTo_gate`, `test_live_numbers_snapshot` | gates + live numbers |

**CI verification (green):**
- **Run 2 — SUCCESS: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38269314749** (final: CI-side live scan + pair-bytecode proof + `forge test -vvv` 13/13).
  - CI live scan at block **127,233,623**: 95/96 pairs read (1 dead pair `0x9b7b76fb…` skipped, codeless token), **exactly the same 7 dust-excess pairs**, factory/locker/farms/Collecter values identical to this report; locker LP 20,099.44; farm V2 pot 204,706.95 NAR; V1 farms `_emergencyStop = true`.
  - CI integrity: `keccak(spliced creationCode) == pairCodeHash == 0x8a30072f…` → **match: True** (`ci-out/integrity.json`).
  - `forge test -vvv`: **13 passed, 0 failed** (132 s).
- Run 1 (https://github.com/kingmariano/ca-zombie-ci/actions/runs/38266409649) failed in the *custom scan script* (a `None` balance on the dead pair — fixed; the forge suite itself was unaffected). Kept for the record.
- Artifacts: `result-narwhalswap` (ci-out/live-state.json, ci-out/integrity.json, forge logs) — copied to `ci-artifacts/`.

---

## 7. Verdict and residual/latent risk

**E-U = $0.00 (high confidence).** Every value-bearing surface is either balance/ownership-gated (pairs by LP, farms by staked balances + rNLP/nard receipts, token mints by minters) or economically self-defeating (5 % NAR tax, 5–50 % THUGS burn, 0.3 % AMM fees). The permissionless entry points that do exist (`convert`, `skim`, `updateBuffRate`, `buffRateReporter`, `getReward`, `emergencyWithdraw`) move either nothing, dust, or the caller's own funds — all fork-verified.

**Latent (privileged) risk — not attacker-reachable:**
- **Team locker (P, $108,438 hard side)**: `0xb104AE8b…` can withdraw 20,099.44 NAR/WBNB LP at any time and dump 4.376M NAR into the now-thin pool (net ≈ $129k WBNB-equivalent). This is ~80 % of the top pair.
- **Team `seize()` (P)**: sweep any non-LP token from all farms — the 1.70M-NAR reward pots ($42,016 at pool price).
- **Team mint (P)**: 284,832 NAR remaining under the cap; `setRate`/`setTeamWallet`/`setRewardPool`/`addMinter` are team-only.
- **THUGS TWAP manipulation (weakness, not extraction)**: the burn % derives from the BSCSwap pair's 10-minute TWAP and can be pushed to the 0.5 % floor with a ≥600 s manipulation; the Narwhal↔BSCSwap price gap is only ~1.3 %, so max round-trip edge ≈ +0.3 % minus slippage — no material extraction from the Narwhal pool.
- **rNLP allowance UX trap**: most stakers never approved the farm, so their `withdraw` reverts until they `approve` (holder action, H-O).

**Blockers / things that would change the verdict:** (a) the team EOA moving the locker LP or dumping NAR (P→ realized); (b) a future NAR/THUGS listing creating real exit liquidity (would make the NAR/THUGS sides arb-able only to the extent of genuine market price differences); (c) any NAR/THUGS contract upgrade — both are immutable, non-upgradeable; (d) discovery that a live key controls one of the dormant LP whales (`0x4d7106032384…` 254.4 THUGS-LP ≈ $58.5k; `0x242fb607…` 560.9 NLP ≈ $7.4k) — that value is H-O for that key holder, still not E-U.

---

## 8. Methodology, sources, caveats

**Method.** Corpus review (`zombie_hunt/FINDINGS.md`, L2 triage row) → verify deployed reality via public BSC RPC (no keyed endpoints in any artefact) → Sourcify source retrieval (`NarwhalswapFactory`, `NarwhalCollecter`, `NarToken`, `NarwhalReward*`, `Rnlp`, `NarwhalPower`, `ThugsToken`, `NLPLock`, `SetUser`) → full live-state dumps (`analysis/state-dump.json` all 96 pairs at block 127,222,666; `analysis/farm-family-state.json`) → holder/flow analysis (`analysis/holders/`, GoldRush + direct reads, sums reconciled to supply) → Foundry fork PoC (13 tests) → CI re-run + CI-side live re-scan.

**Sources:** BSC public RPC (publicnode/1rpc/bnbchain dataseeds), Sourcify, DefiLlama prices, GoldRush (holder discovery only; all balances re-read directly), BSCScan (ecosystem discovery), corpus files.

**Caveats.**
- NAR prices are circular (pool-implied); NAR-denominated USD figures are notional. Hard-asset totals are the conservative basis.
- The PBANK/HYPR/COM "excess" arises from reflection/fee tokens accruing to stale pairs; values move block-to-block but stay dust (token prices near zero).
- Key-possession (team EOA `0xb104AE8b…`, dormant LP EOA `0x4d710603238427ae805b980bab8261624f5260c7`, `0x7777…7777`) cannot be verified on-chain; classification P/S there is a behavioral assumption, disclosed.
- CI-side state scan runs at CI time (fresh block); any drift in reserve values does not change any gate.
- Local PoC ran at fork blocks 127,223,797–127,227,511; CI re-runs at its own head.

**Files index.**
```
narwhalswap/
├── README.md                  ← this file
├── summary.json               ← machine-readable summary
├── analysis/
│   ├── bsc.py, dump_state.py, dump_collecter.py, dump_farms.py, dump_family.py,
│   │   analyze_pairs.py, value_collecter.py, final_valuation.py
│   ├── state-dump.json (96 pairs @127,222,666), farm-family-state.json,
│   │   collecter-state.json, valuation.json, pairs-analysis.json
│   ├── sources/ (Sourcify verified .sol + bundles for factory/pair/NAR/Collecter/
│   │   farms/rNLP/locker/THUGS/SetUser)
│   ├── holders/ (holder tables + rNLP/farm reads + reconciliation)
│   └── ecosystem/ (full Narwhalswap contract discovery + verdicts)
├── poc/ (foundry project, 13 tests, vendored forge-std)  ci/ (live_state.py, run.sh)
├── ci-out/  ci-log.txt  ci-artifacts/
└── PRUNED-RAW.md (note on deleted bulky raw dumps)
```
