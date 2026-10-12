# Mobius Money (Celo) — L2 Phase-2 deep-dive (zombie-hunt II)

**Date:** 2026-10-12 · **Chains:** Celo (42220) · **Status:** read-only; PoC fork-verified only; no mainnet transactions.
**Scope:** how much can an *external unprivileged attacker* extract live from Mobius Money (Curve/Nerve-fork stableswap, launched Aug-2021, governance compromised 2022-12-16, effectively a zombie).
**Blocks:** live-state @ Celo **79,898,558** (2026-10-12); CI fresh reads @ **79,926,545**; market scan @ ~79,926,039.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|
| Mobius stableswap pools (22 standard `Swap` pools + 1 paused V2 + 1 CSMM) | **≈ $0.08 total** (atUST pool $0.077 net one-shot; pUSD-v1 $0.002) | Pool code is byte-identical to the audited Nerve/Curve fork (verified at bytecode level); no permissionless mint/withdraw/admin bug; all junk-token arbs are gas-negative or acquisition-blocked | Micro-arbs may persist for bots; the pools' "value" is mostly LP-owned or unmarketable |
| BTC pools (`0x1926…`, `0xaefc…`, $118.8k DefiLlama-paper) | **$0 realizable** (paper ±$122 only if the TokenSoft "BTC" were redeemable at DL's price; at the live cross-rate ≈ $44.5k the best route is ≈ ‑$0.0002) | The out-token `0xd629eb00` (TokenSoft security-token template) has **no liquidation venue** (its pairs hold ~$3.2 & ~$0.03); the in-token `0xbe50a301` has ~$944 of CELO depth; bots are already cycling the triangle | If anything ever accepts `d629` at BTC parity, ≤ ~0.0134 oldWBTC of capacity remains for a T+ dump |
| Gauges (27, Curve-style) | **$0 without LP stake**; CELO rewards require staking LP at risk | Standard gauge mechanics; `claimable_reward(random, CELO) == 0`; gauges hold **3,566.5 CELO ≈ $336** of reward inventory (per-gauge rates/periods in `analysis/gauges-audit.*`) | leftovers are staker/H-O or stuck; no unprivileged claim |
| PoolProxy (`0x1bc2…`, Vyper) admin fees | **$0** (privileged: only `ownership_admin`, and payouts go to the proxy/burner→`receiver`) | `withdrawAdminFees()` is permissionless but pays the proxy; `burn()` is permissionless-by-EOA but pays `receiver`; caller gains nothing (fork-proven) | admin fee balances across pools ≈ **$224** are owner-takeable |
| Governance / admin | $0 (P) | All privileged control (pool owner proxy, timelock admin, gauge controller admin) converges on **EOA `0x6BE0ff2b…`** — the Dec-2022 compromised-governance actor(s) | Full admin centralization; fees/pause/A can be changed at will |

**TOTAL live extractable by an unprivileged attacker: ≈ $0.08** (±$0.08; confidence **high** that this is effectively $0).
**Same number in hidden/shared-junk terms:** the pools' junk-side balances (atUST, pUSD/pEUR/pCELO, Allbridge, dead WBTC) are structurally unacquirable — every depeg dump is bounded by the *market depth of the junk token* (≤ $1k total across all venues), and every route is gas-negative except the $0.08 atUST/pUSD one-shots.

---

## 2. Live value (what changed since triage)

Triage-B recorded **$234,206** for Mobius. That figure under-counted because the DefiLlama pair list it was built from is inaccurate for several pools (e.g. it listed `stCELO`/new-USDC addresses that hold 0, while the pools actually hold `rstCELO`/USDCet). Fresh on-chain reads with correct token identities + current prices:

| method | total |
|---|---|
| DefiLlama-priced, fresh balances, corrected token identities | **$412,887.37** |
| Realizability-adjusted (junk side + unmarketable BTC tokens haircut to 0; see `analysis/realizable.md`) | **$262,966.47** |
| Of which the two BTC pools' d629/baab "value" (no on-chain liquidation venue) | $118,821.37 (paper) |

Largest positions (fresh): $86.4k USDm/USDCet (`0xa503…`), $84.6k USDm/DAI (`0xf3f6…`), $79.9k BTC-paper (`0x1926…`), $38.9k BTC-paper (`0xaefc…`), $35.1k USDm/asUSDC (`0x63c1…`), $25.5k USDm/cUSDC (`0x0ff0…`), $21.4k USDm/cUSDT (`0xdbf2…`), $21.8k cETH/WETH (`0x74ef…`). Details: `analysis/valuation.json`, `analysis/realizable.md`.

**Ownership:** the reserves belong to LP holders (H-O). E.g. the BTC-pools' LP supply is dust-level (`0x8cd0e2f1` totalSupply = 4.0e10 wei; 37% staked in gauge `0x1A89…`), so the remaining LP wei hold the claim to those pools.

---

## 3. Mechanism / surfaces audited

1. **Code identity (decisive).** The pools are unverified on Celoscan, but the public Mobius repo `mobiusAMM/mobiusV1` ships the exact Hardhat artifacts (solc 0.6.12+commit.27d51765, optimizer 200, istanbul). Byte-level comparison of all 22 standard pools against `Swap.json` shows *only* the 24 `SwapUtils` link slots differ; all 17 distinct `SwapUtils` library instances match `SwapUtils.json` except link slots and (for some instances) an IPFS metadata hash; `MathUtils` (`0x12ff3e…`) matches `MathUtils.json` except its self-address. ⇒ **deployed code = the audited Nerve/Curve fork** (Certik audit `contracts/audits/Certik - REP-Nerve_Finance_Core_Contracts-06_04_2021.pdf`). Evidence: `analysis/bytecode-links.json`, `analysis/library-verify.json`, CI `code-verify.json`.
2. **Pool admin surface.** Owner of all standard pools = Vyper **`Mobius StableSwap Proxy` `0x1bc2…`**; its `ownership_admin` = `emergency_admin` = **EOA `0x6BE0ff2b…`** (same EOA is Timelock admin and GaugeController admin). For an unprivileged attacker: `withdrawAdminFees/setSwapFee/setAdminFee/pause/rampA` **all revert** (fork tests). All pools are non-upgradeable; libraries are non-upgradeable.
3. **LP mechanics.** Standard Curve/Nerve math (D/k invariant, `getY/getYD`, deposit fee 1% → devaddr, decaying withdraw fee). Fork round-trip `addLiquidity → removeLiquidity` is a strict loss (deposit fee); `removeLiquidity` needs LP allowance to the pool (quirk, not a bug). No mint/burn path for outsiders.
4. **Depeg / junk-token arbitrage.** Full market sweep (Ubeswap V2 882 pairs, SushiSwap Celo 257 pairs, Uniswap-V3 `getPool` grid) + exact `calculateSwap` grids for all 12 candidate pools: **total positive gross ≈ $0.098**, net after gas ≈ **$0.079** (child audit `analysis/markets.md`). Everything else is acquisition-blocked (junk has no market) or gas-negative.
5. **BTC pools (largest "value" item).** `0x1926…` pays ~1.62 `d629`-BTC per `0xbe50a301`-WBTC and `0xaefc…` pays ~1.73 per `0xbaab46e2`; but (a) the only `d629` venue is ~$3.2 of Ubeswap depth, (b) buying the WBTC side is capacity-limited to ~0.0067/0.00005 tokens, (c) at the live cross-rate (`d629 ≈ $44.5k`) the best route is ≈ break-even-to-negative, and (d) bots already cycle the triangle (Oct 7–12 activity). See `analysis/oldwbtc_arb.json` (paper grid) and child `analysis/markets.md` (live route grid, net $0).
6. **Gauges (27) / minter / veMOBI.** Gauge reward token = CELO; without staked LP nothing is claimable (`claimable_reward == 0`); gauge CELO balances ≈ $21 total. veMOBI: 0.28M MOBI locked of 792M supply. MOBI ≈ $0. (Child audit `analysis/gauges-audit.*`.)
7. **PoolProxy `burn()` path.** `burn(coin)` is callable by any EOA (`tx.origin==msg.sender`, `burner_kill=false`) and pulls the *proxy's* admin fees via `transferFrom`; proceeds are swapped via `MobiusWrapper`→`Minima` and the MOBI output is sent to the burner's `receiver`. The caller gains nothing (fork-proven; burner holds 0 tokens; proxy holds ≈ $30 of fees).
8. **Paused pool `0x81b6…`** (different 23KB code — Mobius V2-style, owner EOA `0x4ea77424…`): swaps blocked; holds 34.99 pUSD + 31.61 MobLP of stored value; its admin balances (81.2 pUSD + 91.5 MobLP) exceed stored balances → `withdrawAdminFees` would revert (admin fees bricked, S).
9. **CSMM / Mento pool `0xfa3d…`** ("SwapUSDCet", A=999999): mento-owned liquidity withdrawn Jan-2023; remaining ≈ $0.20.
10. **Permissionless calls that do nothing for the caller:** `PoolProxy.withdraw_admin_fees/withdraw_many` (pays the proxy), `burn/burn_many` (pays receiver), Minter/gauge `updatePool` paths (MOBI inflation ≈ $0), `massUpdatePools`-style calls.

---

## 4. The extractable path in exact terms (the $0.08)

Pool `0x9f4adbd0…` (USDm / atUST — Wormhole-bridged Terra UST):
- Pool marginal price of atUST ≈ **0.01461 USDm/atUST** (exact `calculateSwap(1,0,1e18)`), vs Ubeswap pair `0x752875e0…` spot **0.00300 USDm/atUST** (reserves 0.0581 USDm / 19.372 atUST, untouched since 2025-11-18).
- Optimum: buy **10.9003 atUST** for **0.0750 USDm**, swap into the pool for **0.1588 USDm** ⇒ gross **+$0.0837**, gas ~$0.006 ⇒ **net ≈ +$0.077**, one-shot. (Absolute bound, even with free atUST: dumping all 14,513.85 atUST yields only 35.47 USDm.)
- Pool `0x02db089f…` (USDm / pUSD v1): +$0.0078 gross / +$0.0016 net. All other 10 pools: ≤ 0 or gas-negative.

No other unprivileged value path exists today (see §3). The extractable total is **≈ $0.08**.

---

## 5. PoC / fork verification

Foundry project in `poc/` (vendored forge-std; forks Celo via keyless public RPCs; no secrets). Tests (`poc/test/MobiusPoC.t.sol`):

| test | purpose | result |
|---|---|---|
| `test_pool_code_matches_audited_repo_artifact` | keccak of deployed pool/library code equals verified artifacts | PASS |
| `test_admin_functions_revert_for_non_owner` | admin calls revert for unprivileged caller | PASS |
| `test_pool_proxy_admin_is_eoa_not_attacker_accessible` | proxy admins ≠ attacker; logged | PASS |
| `test_atust_dump_bounded_by_pool_balance` | even ALL atUST in ⇒ ≤ pool's USDm balance (logged 35.47) | PASS |
| `test_pusd_dump_bounded_by_pool_balance` | pUSD dump bound | PASS |
| `test_oldwbtc_to_btc_chain_not_realizable` | BTC out can't be liquidated on-chain (<0.1 USDm recoverable) | PASS |
| `test_proxy_burn_is_permissionless_but_unprofitable` | `burn()` caller gains 0 | PASS |
| `test_paused_pool_swap_reverts` | paused pool blocks swaps | PASS |
| `test_add_remove_liquidity_round_trip_is_a_loss` | LP round-trip loses (deposit fee) | PASS |
| `test_gauge_has_no_free_claim_without_stake` | `claimable_reward(random)==0` | PASS |
| `test_log_live_state` | state fingerprint (A, fee, balances, owner) | PASS |

**CI (GitHub Actions, public repo `kingmariano/ca-zombie-ci`):**
- Run 1 (initial, 11 tests, 1 fail — LP allowance bug in test): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38286430372
- Run 2 (final): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38287436523 — see `ci-log.txt`, artifacts in `ci-artifacts/`
- CI custom job: `ci/run.sh` → code verification (`ci-out/code-verify.json`: all 22 pools `CODE_IDENTICAL`), full Ubeswap market scan (882 pairs → 554 matching our tokens; `ci-out/market-scan.json`), fresh valuation (`ci-out/valuation.json`).
- Gas/prices in the money math: CELO $0.0942, 200 gwei base fee, Mobius swap ≈ 149k gas (child audit, `analysis/markets.md`).

---

## 6. Verdict and residual / latent risk

- **E-U: ≈ $0.08 live** (effectively zero; one-shot micro-arbs). Confidence **high** — the code is verified byte-for-byte, the admin surface is gated, and the market sweep is exhaustive for the venues that exist.
- **H-O: ≈ $263k** is LP/staker-owned and withdrawable by holders (pro-rata; single-sided exits pay fees). Much of the nominal $412.9k is junk-side or paper BTC that no one can realize.
- **P: ≈ $224** admin fees (owner-takeable) + full protocol control are centralized on EOA `0x6BE0ff2b…` (the address that also holds Timelock and GaugeController admin). The Dec-16-2022 governance compromise ("attacker gained control of the Mobius DAO … swap fees diverted", X @mobiusmoney; Mento CGP-69) left this key with whoever took it over.
- **S: ≈ $124** — paused pool `0x81b6…`'s admin balances exceed its stored balances, so `withdrawAdminFees` would revert (bricked), plus ≈ $0.2 CSMM dust.
- **Latent risks:** (1) if any protocol/integrator ever prices `d629`/`baab`/`be50` at BTC parity, a dump of up to ~0.0134 (be50 market depth) becomes instantly profitable (≤ ~$1k today, more if the tokens acquired liquidity); (2) the unmarketable BTC-paper ($118.8k at DL prices) keeps attracting bots to grind the triangle; (3) the centralized admin EOA can still change fees/pause (P), but cannot withdraw pool reserves.

**Blockers / caveats:** `d629` "BTC" is a TokenSoft security-token-template contract (transfer-restriction capable, `detectTransferRestriction == 0` today) with 2.4455 total supply — no bridge/redemption found; its DefiLlama price ($82.7k) overstates the live cross-rate (~$44.5k) and is not realizable. Old Wireless (Wormhole/Optics) bridge assets (`be50a301`, `baab46e2`, `1bfc26ce`, `cc82628f`) are stranded. Allbridge (`aaUSDC`/`asUSDC`) is paused. Poof (pUSD/pEUR/pCELO) is a dead zk protocol.

---

## 7. Methodology, sources, files

- Keys: none used in-folder; all reads via keyless public RPCs (`https://forno.celo.org`, `https://celo-rpc.publicnode.com`, `https://rpc.ankr.com/celo`, `https://celo.drpc.org`). No secrets written to any file.
- Sources: on-chain reads (eth_call/eth_getCode/eth_getLogs via public RPC); `celo.blockscout.com` REST (creator/creation/ABI/source); GitHub `mobiusAMM/*` (repo + shipped build artifacts); Mento `mondo.celo.org/governance/80` (Dec-2022 compromise context); DefiLlama prices (`coins.llama.fi`); X @mobiusmoney incident thread (via search).
- Files: `analysis/` (scripts + JSON evidence: `live-state.json`, `tokens.json`, `valuation.json`, `realizable.md/.json`, `markets.md/.json`, `poof-tokens.json`, `gauges-audit.*`, `bytecode-*.json`, `library-verify.json`, `oldwbtc_arb.json`); `poc/` (Foundry); `ci/` (heavy job); `ci-out/`, `ci-log.txt`, `ci-artifacts/`.
- Every headline claim cites address + block + call in the analysis JSONs; CI re-verifies code identity and live value.
