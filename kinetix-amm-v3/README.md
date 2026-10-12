# Kinetix AMM V3 (Base + Kava) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chains:** Kava (2222), Base (8453) · **Status:** read-only; fork-verified only; no mainnet transactions.

**Mission:** determine rigorously how much an **external unprivileged attacker** can extract live from Kinetix AMM V3 (zombie-hunt II, L2 watchlist Phase 2; triage row `kinetix-amm-v3`, triage headline $175,793).

---

## 1. TL;DR

| Target | Live custody (today, on-chain) | Extractable by unprivileged attacker (E-U) | Why closed | Latent risk |
|---|---|---|---|---|
| Kinetix AMM V3 — Kava: factory `0x2dBB…35C2`, 155 pools | **$184,266 nominal** (≈$97.7k liquid assets; rest = dead-token legs WAGMI/HOV/KAI ≈$86.5k) | **$0** | All custody code is **provably canonical Uniswap V3** (pools at the canonical CREATE2 init-code-hash addresses; factory/NFPM byte-identical to canonical Uniswap deployments); every LP position is owned by an EOA or a Gnosis Safe; third-party vaults (Steer/ICHI/Arrakis) hold the remainder; protocol fees are owner-only | If the Gnosis Safe signers are lost → $147k stuck (holder-side, not attacker). Steer/ICHI/Arrakis vault liveness is third-party |
| Kinetix AMM V3 — Base: factory `0xdDF5…7FCf`, 21 pools | $25.79 | **$0** | Same canonical bytecode; all balances are LP-owned dust | none material |
| Kinetix V3 staker `0x011C…B5AD` | $0 (0 NFTs, 0 tokens) | $0 | Upstream v3-staker source (renames only); nothing staked | none |
| Protocol fees accrued in pools | **$18.05** | $0 | `collectProtocol` is `onlyFactoryOwner` (factory owner = EOA `0xD6F5…5c4a`) → **P** category | owner-key compromise would capture $18 |

**Total live extractable now (E-U): $0 — confidence: high.**

**Total live custody now:** **$184,292** = Kava $184,266 nominal + Base $25.79. All of it is **H-O** (recoverable only by the respective LP/position/vault owners — verified: a position holder can `decreaseLiquidity`+`collect` and receives tokens; nobody else can). Only ≈$97.7k of the Kava figure is in liquid assets (stables, WKAVA, BTC, ETH, ATOM, BIFI); ≈$86.5k sits in dead/illiquid tokens (WAGMI $78.6k, HOV $1.4k, KAI $6.5k) whose only "market" is the Kinetix pools themselves.

> Note vs triage: token **amounts are essentially unchanged** since triage (the pools remain lightly active — ≈1,300 swaps per 1M blocks on the top pool, dust-level bot activity — but net balances are stable). The USD figure differs only by price source: DefiLlama's (frozen graph) feed shows $174,972 for Kava today; on-chain token amounts × market prices (incl. WAGMI/HOV/KAI legs) give $184,266. Triage's $175,793 was DefiLlama-derived; this report's numbers are **on-chain-derived**.

---

## 2. The finding as it stands: what was checked and why it is closed

Kinetix AMM V3 is a **Uniswap V3 fork** (Kava: 2023, Base: 2024). The corpus marked it dead (`deadUrl`, 0 audits). The Phase-2 question is whether any live, unprivileged extraction path remains against the residual ~$184k. Four independent lines of evidence close it:

### 2.1 Source-level: the fork is a rename of Uniswap V3 (v1.0.0 / periphery v1.3.0)

* `kinetixfi/v3-core` — token-level semantic diff of `KinetixV3Pool.sol`, `KinetixV3Factory.sol`, `KinetixV3PoolDeployer.sol` against upstream Uniswap v3-core `v1.0.0` (after comment/whitespace normalisation): **the only differences are the contract names** (`UniswapV3Pool`→`KinetixV3Pool`, etc.). Diff ratio 0.9998/0.9905/0.9786; no logic changes (`analysis/semdiff.py`, run log in `analysis/`).
* `kinetixfi/v3-staker` — `KinetixV3Staker.sol` vs upstream `UniswapV3Staker.sol`: **only `uniswap`→`kinetix` renames**.
* `kinetixfi/v3-periphery` — `NonfungiblePositionManager.sol` vs upstream `v1.3.0`: **only 3 import-path renames**.

### 2.2 On-chain cryptographic provenance (the strongest proof)

* **All 155 Kava pools and all 21 Base pools sit exactly at the CREATE2 addresses computed from the *canonical Uniswap V3 pool init code hash*** `0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54`. Address = `keccak256(0xff ‖ factory ‖ keccak256(abi.encode(t0,t1,fee)) ‖ initHash)[12:]` matches every single pool. Because the address is a function of the *creation code hash*, this pins the deployed pool bytecode to canonical Uniswap V3 — **no backdoor, no modified math, no hidden entry point is possible** (proof: `analysis/create2-check.txt`, re-run in CI `ci-out/create2-proof.txt`, and in `poc/test/KinetixFork.t.sol`).
* **Factory bytecode**: Kava factory runtime code is byte-identical to the canonical Uniswap V3 factory on Ethereum mainnet (`0x1F98…F984`) after normalising the single embedded self-address literal (49072 hex chars both, identical tails incl. metadata `a164736f6c6343000706000a`). Same for the Base factory.
* **NFPM bytecode**: Kava NFPM `0x8dB0…6a54` runtime code is **byte-identical to the canonical Uniswap v1.3.0 NFPM on Ethereum** (`0xC36442b4a4522E871399CD717aBDD847Ab11FE88`) after normalising its three immutables (`factory`, `WETH9`, `tokenDescriptor`) — 24,384 bytes both.

Consequence: the AMM pool contract, the position manager and the factory cannot contain any Kinetix-specific logic — they are the battle-tested Uniswap contracts.

### 2.3 Full custody enumeration (who actually owns the money)

* **NFPM positions (Kava):** all 1,670 position NFTs enumerated on-chain (`tokenByIndex` → `ownerOf` + `positions()`), 203 active (liquidity>0 or fees owed). **674 of 675 unique owners are EOAs**; the single contract owner is a **Gnosis Safe** `0x7D5CEA2e…A7f38` which owns 4 positions in the WAGMI/WKAVA pool — including the dominant position #511 (liquidity 15,663,710,217,888,675,764,825,981; range −86000..−9400) worth **$147,262** of the $163,222 attributed to NFPM positions. Only the Safe's signers can move it (H-O).
* **Non-NFPM ("direct-minted") pool positions:** all 48 funded pools' `Mint` events were scanned; 34 pool↔minter pairs, **all identified by `name()`**: 23 **Steer Protocol** vaults (`STEER_UNIV3_VAULT_*`), 4 **ICHI** vaults, 1 **Arrakis-style** vault (`xUSDT-WKAVA`, `withdraw`/`deposit`/`rebalance` interface), and 5 tiny Kinetix "x" vaults incl. `Kinetix USDt/WKAVA LP` (KFIALMLP). Value in these ≈$21.0k (mostly the Steer vault in the WAGMI pool, ≈$17.8k); withdrawals are share-gated by the vault contracts (tested: attacker without shares cannot `withdraw` from the Arrakis vault — reverts).
* **Staker:** holds **0** NFTs and 0 tokens; no deposits (checked tokenIds incl. #511; deployed staker is an older 4-word-deposit variant, empty).
* **Migrator / router / descriptor:** 0 balances; stateless.
* **Protocol fees:** `slot0.feeProtocol = 0x44` on the pools (25 % of swap fees to the protocol). Accrued protocol fees across all 155 pools ≈ **$18.05** — collectable **only** by the factory owner EOA `0xD6F5c0737026E0E662E514eE0e08cCE6B2Bf5c4a` (`collectProtocol` is `onlyFactoryOwner`). Factory owner has no other powers over LP funds (`setOwner`, `enableFeeAmount` only).

### 2.4 Attacker-path tests on a fork (see §5)

As an unprivileged attacker, every candidate path either reverts or returns zero, and pool/attacker balances are unchanged. Conversely, a legitimate position owner can self-withdraw (H-O proven).

---

## 3. Live-state assessment (all reads at latest block, 2026-10-12)

| Chain | Block | Contract | Address | State |
|---|---|---|---|---|
| Kava | 22,995,949 | V3 factory | `0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2` | owner = EOA `0xD6F5c073…5c4a` (no code); fee tiers 100/500/3000/10000; 155 pools created (last at block 19,839,616) |
| Kava | " | NFPM | `0x8dB08eD2b460643974C64BE42087903470Df6a54` | totalSupply 1670; factory() = 0x2dBB…; canonical bytecode |
| Kava | " | Staker | `0x011C835aBF4BCeD2ECb51C466E157f467F6dB5AD` | 0 NFTs, 0 tokens; upstream source |
| Kava | " | Migrator | `0xE071871805be750C4AdCDae13De3742AeC7ea36d` | 0 balances |
| Kava | " | SwapRouter02 | `0xc8f22018D3c5f5A4101fB1448d5E5CcdDA4f123e` | stateless (17 gwei dust) |
| Kava | 22,995,9xx | Top pool (WAGMI/WKAVA 1 %) | `0xc81Fde7F51e432EA173e87BB3d0c5670fC7b7FF9` | 1,272,160 WKAVA + 175.4M WAGMI; protocolFees = 18,298.7 WAGMI + 70.34 WKAVA; feeProtocol 0x44; ~1,370 swaps in the last 1M blocks (lightly active, bot-scale) |
| Kava | " | 2nd pool (KAI/WKAVA 1 %) | `0x8dC4A3df6AE668E3CD2D813D5A3B4dD6f9c8135C` | 106,697 WKAVA + 53.1M KAI |
| Kava | " | USDt/WKAVA 0.05 % | `0x91098391cD135A95f775752F8cBf59286729a948` | 531.57 USDt + 7,201 WKAVA; 81 NFPM positions + Steer/ICHI/Arrakis vaults |
| Kava | " | 155 pools total | — | sum of token balances × market prices = **$184,266.26** |
| Base | 52,524,402 | V3 factory | `0xdDF5a3259a88Ab79D5530eB3eB14c1C92CD97FCf` | owner = same EOA; 21 pools; all at canonical CREATE2 addresses |
| Base | " | 21 pools | — | **$25.79** (WETH/AERO/USDbC dust; largest pool $15.93) |

Valuation method: token balances read directly via `eth_call` at latest block; prices at 2026-10-12 (KAVA $0.0680, ETH $2,509.7, BTC $82,379, ATOM $1.8387, BIFI $66.71, HOV $0.0000345, WAGMI $0.000448 (GeckoTerminal — only market is this pool), KAI $0.000122; stables $1). Full per-pool table: `analysis/kava-pool-balances.json`, `analysis/value-attribution.json`, `ci-out/valuation.json`.

**Attribution of the Kava $184,266:** NFPM positions $163,222 (Safe $147,262; EOAs $15,960) · third-party/Kinetix vault positions ≈$21,026 · protocol fees $18.05.

---

## 4. What an attacker can / cannot do (exact call paths)

Preconditions for all of the below: no keys, no privileges, only public contracts + attacker capital. Flash loans exist on Kava (e.g. via pools themselves) but are irrelevant because there is no mis-priced or unguarded state to exploit.

**Cannot (verified to revert / no-op):**

1. `pool.collect(attacker, tickLower, tickUpper, MAX, MAX)` — the pool credits `positions[msg.sender]`; an attacker has no pool position → returns `(0,0)`, no transfer. (Position 511's range −86000..−9400 tested.)
2. `pool.collectProtocol(attacker, MAX, MAX)` — `onlyFactoryOwner` → revert.
3. `pool.setFeeProtocol(...)` — `onlyFactoryOwner` → revert.
4. `NFPM.decreaseLiquidity/de collect/burn/transferFrom` on any position the attacker doesn't own — ERC721 `_isApprovedOrOwner` → revert ("Not approved"). Tested on position #511 (owned by the Safe).
5. `staker.unstakeToken/claimReward` — nothing is staked; staker holds no value; `deposits[tokenId].owner == 0`.
6. `factory.setOwner` / `enableFeeAmount` — owner-only → revert.
7. Vault shares: attacker without shares cannot withdraw from the Arrakis vault in the USDt/WKAVA pool (tested → revert).
8. Swaps/flash loans: canonical Uniswap V3 semantics — no free money; fees must be paid; there is no external protocol consuming these pools as an oracle that would pay for manipulation.

**Can (all H-O / P, not attacker extraction):**

1. Position owners: `decreaseLiquidity` + `collect` → tokens (proven in test #5 with position #849: the owner receives USDt+WKAVA).
2. Factory owner (EOA): `collectProtocol` on any pool → up to $18.05 total (P).
3. Gnosis Safe signers: withdraw position #511 ($147,262 nominal).
4. Steer/ICHI/Arrakis vault depositors: withdraw their vault shares (subject to those contracts' liveness).

**Costs if anything were extractable:** n/a (nothing is). Gas on Kava ≈ negligible; no flash-loan fee would matter.

---

## 5. PoC / fork verification

Foundry project: `poc/` (forge-std vendored; solc 0.8.24). Tests fork **live Kava and Base** via public RPCs (`vm.createSelectFork`; no transactions sent).

| # | Test | What it proves |
|---|---|---|
| 1 | `test_kava_live_state` | factory owner is EOA; NFPM/staker wiring; top pool balances; protocol fees present |
| 2 | `test_kava_create2_canonical_all_pools` | **all 155 Kava pools at canonical Uniswap V3 CREATE2 addresses** + `factory.getPool` agrees |
| 3 | `test_base_create2_canonical_all_pools` | all 21 Base pools canonical |
| 4 | `test_kava_attacker_cannot_take_lp_value` | attacker `collect` → (0,0); `collectProtocol`/`decreaseLiquidity`/`collect`/`transferFrom` revert; balances unchanged |
| 5 | `test_kava_holder_self_service_works` | position owner can `decreaseLiquidity`+`collect` and receives tokens (**H-O**) |
| 6 | `test_kava_protocol_fees_owner_only` | attacker can't; factory owner can collect protocol fees (**P**) |
| 7 | `test_kava_staker_empty` | staker owns 0 NFTs; deposit entry empty |
| 8 | `test_kava_thirdparty_vault_attacker_withdraw_reverts` | Arrakis vault: attacker without shares cannot withdraw |

Heavy CI job (`ci/run.sh`) additionally re-derives, from live RPCs: the CREATE2 proof for all 176 pools, the factory/NFPM bytecode-provenance proofs, and the live valuation (`ci-out/`).

**CI run(s):** see `ci-log.txt` / `ci-artifacts/` — run URL(s) recorded in `summary.json` and below.

- Run URL: *(filled by CI run — see summary.json)*
- Result: *(tests x/y PASS — filled after run)*

---

## 6. Verdict, residual & latent risk

* **E-U (external unprivileged extractable): $0.00 — high confidence.** The residual value is held in canonical Uniswap V3 pools; every claim on it is either an LP position owned by an EOA/Safe, a share in a third-party vault, or (for $18) the protocol fee slot of the factory owner. None of these can be moved by an unprivileged caller.
* **H-O: $184,292 nominal** (Kava $184,266 + Base $25.79): owner-only recovery. ≈$97.7k in liquid assets; ≈$86.5k in dead-token legs (WAGMI/HOV/KAI) whose exit liquidity is the same dormant pools.
* **P: $18.05** (protocol fees, factory-owner EOA).
* **S: $0** identified (no bricked custody found). Caveats: (a) if the Gnosis Safe `0x7D5C…` signers are gone, $147k is effectively frozen (holder-side, not attacker); (b) Steer/ICHI/Arrakis vaults' withdrawal liveness was not fully proven (third-party contracts; the Arrakis withdrawal gate was verified to reject non-holders).
* **Latent risk:** none found for a future attacker unless someone revives trading. A *new* swap volume would accrue more protocol fees to the owner EOA (P) but LP funds remain protected by canonical code. The one thing that would change the verdict: evidence that the deployed pool/NFPM bytecode differs from canonical Uniswap (it does not — proven) or a drainable third-party vault (separate finding if so).

**Blockers/uncertainties encountered:** Kava has no working block-explorer API for third-party tools (Kavascan 403 / Routescan unsupported), so deployment archaeology was done via events + CREATE2 math; the old Kava subgraph (`kava-graph-node.metavault.trade`) is DNS-dead, so DefiLlama's Kava figure is graph-frozen (amounts confirmed on-chain instead). Two token prices (WAGMI, KAI) come from GeckoTerminal/CoinGecko with the caveat that WAGMI's only market is the pool itself.

---

## 7. Methodology & sources

* Corpus: `zombie_hunt/FINDINGS.md` (row Kinetix AMM V3), `zombie_hunt/non_llama_and_directories.md`, L2 triage `l2-triage-a/` (adapter + manual evidence), DefiLlama protocol API (`kinetix-amm-v3`), DefiLlama/CoinGecko/GeckoTerminal prices.
* Kinetix sources: `github.com/kinetixfi/v3-core`, `v3-periphery`, `v3-staker`, `v3-subgraph` (subgraph.yaml gives the canonical Kava factory + start block), `v3-deploy-scripts` (deployment state).
* On-chain: Kava (`https://kava-evm-rpc.publicnode.com`, `https://rpc.ankr.com/kava_evm`), Base (`https://base-rpc.publicnode.com`), Ethereum (`https://ethereum-rpc.publicnode.com`). Reads only — `eth_call`, `eth_getCode`, `eth_getLogs`. No keys, no transactions.
* Enumeration: factory `PoolCreated` logs (155 Kava pools, full history 6.29M→23.0M); NFPM `tokenByIndex`→`ownerOf`→`positions()` (1,670 positions); pool `Mint` logs for all 48 funded pools (34 direct-minter pairs); `balanceOf` for every pool's tokens; `protocolFees()` for all 155 pools.
* Provenance: token-level source diffs (`analysis/semdiff.py`), CREATE2 init-hash check (all 176 pools), factory/NFPM bytecode normalised comparisons vs canonical Ethereum deployments.

**Caveats / limitations:** (1) third-party vault internals (Steer/ICHI) were not fully audited — they are out of this finding's scope; the Kinetix-owned x-vaults hold <$2 and their custom withdraw path was not exercised (no material value). (2) Token prices for dead tokens are illiquid estimates; the report gives both nominal and liquid values. (3) Kinetix AMM V1/V2, perps and airdrop contracts are **separate** findings (V2 is a different DefiLlama protocol row) and were not audited here. (4) The deployed Kava staker is an older 4-word-deposit variant than the repo HEAD; it is empty, so this is noted, not material.

**Files index**

```
kinetix-amm-v3/
├── README.md                     ← this file
├── summary.json                  ← machine-readable summary
├── analysis/
│   ├── kava-pools.csv            ← all 155 pools (token0,token1,fee,tickSpacing,pool,block)
│   ├── kava-poolcreated-logs.json← raw PoolCreated logs (provenance)
│   ├── kava-pool-balances.json   ← balances + slot0/liquidity/feeProtocol for all pools
│   ├── kava-pools-valued.json    ← per-pool USD (first-pass prices)
│   ├── kava-nfpm-positions.json  ← all 1,670 positions (owner, ticks, liquidity, owed)
│   ├── kava-direct-minters.json  ← 34 non-NFPM minters with identities (Steer/ICHI/Arrakis/Kinetix)
│   ├── value-attribution.json    ← per-pool: pool USD vs NFPM-attributed vs residual
│   ├── base-pools-raw.json       ← 21 Base pools with balances
│   ├── create2-check.txt         ← full CREATE2 provenance check (155 Kava)
│   └── semdiff.py                ← token-level Solidity diff tool used for source provenance
├── poc/                          ← Foundry project (foundry.toml, test/KinetixFork.t.sol, lib/forge-std)
├── ci/run.sh                     ← heavy CI job (create2 + bytecode + valuation proofs → ci-out/)
├── ci-out/                       ← CI-produced proof files (after run)
└── ci-log.txt / ci-artifacts/    ← CI logs/artifacts (after run)
```
