# DeFIL (FILST / DFL / eFIL) — L2 Phase-2 deep-dive

**Date:** 2026-10-11 · **Chains:** Ethereum (1) + BNB Chain (56) · **Status:** read-only research; PoC fork-verified only; **no mainnet transactions**.

**Scope question:** how much can an *external unprivileged attacker* (no owner/admin keys, no insider access) extract live from DeFIL today?

---

## 1. TL;DR

| Target (ETH unless noted) | Live value (nominal) | E-U extractable? | Why closed | Latent risk |
|---|---|---|---|---|
| FILST/USDT UNI-V2 LP `0xa2f6a219…` (99.991% staked in `0x9e08bd9a…`) | 1,396,416 FILST + 714,487.85 USDT (≈ **$1.429M**; hard USDT = $714.5K) | **$0** | `Staking.withdraw` is share-gated; no admin/sweep; only depositors can pull (H-O) | Owner-key `setPoster` → mint FILST → dump into pool (P) |
| FILST staked in `0x01aabbad…` | 374,551 FILST (≈ **$191.6K**) | **$0** | same share-gated Staking | — |
| DFL staked in `0xb685bfda…` | 52,202,775 DFL (≈ **$5.8K**) | **$0** | same share-gated Staking | — |
| FILST/EFIL + DFL/USDT + eFIL2/FILST LP stakings (`0x312c6ffe…`, `0x6b0c7d01…`, `0xefeeb899…`) | ≈ **$1.3K** | **$0** | same share-gated Staking | — |
| Lending markets (ceFIL/cmFIL/cFILST) | 38,528 EFIL + 182,289 mFIL + 3,102 FILST (≈ **$1.6K** realizable) | **$0** | holder-gated redeem; markets tiny; no borrows | stale oracle (2021 prices) — no profitable borrow path |
| MiningNFTs (1,914 units) | ~$0 (no market) | **$0** | escrowed in FILSTManage; **no withdrawal function exists** (S) | if leaked → mint FILST at 5% fee → dump (see §6) |
| BSC mirror (LP USDT + FILST + DFL) | ≈ **$0.31M** (see BSC notes) | **$0** | same Staking family; BSC FILST mint also gated | — |

### Total live extractable now (external unprivileged): **$0** — confidence **high** (ETH fully verified; BSC mirror verified by child audit).

The **$1.76M DefiLlama figure (up to ~$2.4M incl. BSC FILST)** is real *custody* but it is **holder-recoverable (H-O)**, not attacker-extractable: every path is gated by per-account share accounting, mining-NFT ownership, or an owner key. The only hard money is **$714,488 USDT** in the ETH pair (+ $139,005 USDT on BSC), redeemable pro-rata by the LP depositors.

---

## 2. What DeFIL is / the mechanism in exact terms

DeFIL (2021, Filecoin-related lending + staking; abandoned ~June 2022; docs domain now for sale) deployed:

- **FILST** "Filecoin Standard Token" (1 FILST = 1 GiB hashpower claim), minted only through `FILSTManage` against **ERC-1155 "mining NFTs"** plus a 5% DFL fee (price via `PriceConverter` spot reads).
- **DFL** governance/reward token; **eFIL/mFIL** lending-related tokens.
- A **Compound fork** (Unitroller `0x6B4F20B2…` + 3 markets) with DFL distribution.
- **Six identical `Staking` contracts** (verified solc 0.5.17; all share runtime code hash `0xd3b82811…`), each a `Redistributor` that holds user deposits (`property`) and forwards DFL/EFIL rewards from a `superior` distributor.

The live value sits in the staking contracts (user deposits) and the FILST/USDT pool.

---

## 3. Live-state assessment (block 26,169,800 pinned; latest 26,169,907)

See `analysis/eth_state.json` and `analysis/eth_audit.md` for the full dump. Key facts:

- **Pool `0xa2f6a219…`**: reserves **1,396,416.006 FILST + 714,487.847 USDT**; LP supply 0.979559; **`0x9e08bd9a` holds 0.979475 (99.9914%)**; pair balances equal reserves (no skim).
- **Staking `0x9e08bd9a`** (property = the LP): `totalDeposits` 0.979475 LP. Top depositor `0xf2ba8f66…` (EOA) holds 0.978272 LP = **99.88%** of the stake. Deposits came from ~47 addresses (2021).
- **Staking `0x01aabbad`** (property = FILST): 374,550.818 FILST staked; current top holders `0xc1b29667` 194,791 FILST and `0x6e1da46a` 153,232 FILST (both EOAs), plus the cFILST market's 3,102 FILST.
- **Staking `0xb685bfda`** (property = DFL): 52,202,774.7 DFL staked.
- **FILST**: total supply 1,959,936 (= everything ever minted through FILSTManage); owner EOA `0x557EdaaF` (no code); poster/minter = `FILSTManage`.
- **MiningNFTs**: all **1,914 units** (IDs 100001–100011) are held by `FILSTManage`; `totalStakedMiningNftAmount` = 1,914; **FILSTManage has no function to transfer ERC-1155s out** (its only mover is a DFL `transfer`, onlyOwner). New NFT minting requires an owner-managed whitelist.
- **Lending markets**: ceFIL cash 38,528 EFIL (borrows 14.37M / reserves 14.21M — legacy bad debt); cmFIL cash 182,289 mFIL (mFIL has no market); cFILST cash 3,102 FILST **auto-staked into the FilstPool** (market holds matching pool shares; sole holder `0x9a26f4d0` can redeem — verified). Oracle is a stale 2021 `SimplePriceOracle`.
- **Reward chain**: Unitroller holds 43.75M DFL; LP-staking's `PrivilegedRedistributor` has 930,674 DFL accrued for it. All claim paths require the caller's own accrued amount.
- **Bridge**: research found no public bridge contract; DeFIL's cross-chain was team-operated (multi-sig), no working public path — the ETH-vs-BSC FILST price gap ($0.5117 vs $0.1335) has not converged in years with zero cross-pool flow (`analysis/research/notes.md`).

---

## 4. What an attacker can / cannot do — exact call paths

| Attempt (from a random address) | Result (simulated on fork) |
|---|---|
| `Staking(0x9e08bd9a).withdraw(1e15)` | revert `withdraw: insufficient value` |
| `Staking(0x01aabbad).withdraw(1e18)` | revert `withdraw: insufficient value` |
| `Staking(0xb685bfda).withdraw(1e18)` | revert `withdraw: insufficient value` |
| `Staking(0x9e08bd9a).claim(attacker,1)` | revert `claim: insufficient value` |
| `PrivilegedRedistributor.claim(attacker,1)` | revert `claim: insufficient value` |
| `RewardPool.claim(attacker,1)` | revert `Insufficient value` |
| `Unitroller.claim(attacker,1e18)` | revert `insufficent value` |
| `FILSTManage.mint(attacker,100001,1)` | revert `exceed mining NFT balance` |
| `MiningNFTManage.mint(1)` | revert `sender not in whitelist` |
| `MFIL.mint(attacker,1e18)` | revert `MinterAccess: sender do not have the minter role` |
| Depositor `0xf2ba8f66.withdraw(978272219496394154)` (LP) | **succeeds** → 0.978272 LP received (H-O) |
| Depositor `0x6e1da46a.withdraw(153232.2e18)` (FILST) | **succeeds** (H-O) |
| cFILST holder `0x9a26f4d0.redeem(3,102.08e18)` | **succeeds** → 3,102.08 FILST received (H-O) |

**No unprivileged call path moves another account's deposit or minted token.** The staking contracts have no owner/admin/sweep; withdrawals compare against the caller's own `share`; claims against the caller's own `accruedAmount`; the superior distributors against the caller's accrued; and FILST minting requires NFT units that are all escrowed.

### Costs of the closed paths (why even griefing fails)
- The only public state-changing functions are `deposit/withdraw/claim/claimAll/accrue/transfer` (Staking), the NFT/DFL mint gates, and the Compound market calls. None has a surplus-transfer branch.
- `accrue()` is public but only advances an index from the superior's real accrued; rounding truncates in the contract's favour.

---

## 5. Realizable exit liquidity (honest sizing)

- The **USDT side ($714,487.85)** is the only hard asset in the ETH pool. AMM math (`analysis/exit_liquidity.json`):
  - sell 100,000 FILST → ~**$47,614** USDT
  - sell 1,396,416 FILST (the entire FILST side) → ~**$356,738** USDT
  - asymptote with infinite FILST → **$712,344** USDT (0.997 × reserve)
- The staked **FILST (374,551)** is only realizable by selling into this same pool (~$150.7K at full size, competing with the LP holders' own FILST).
- Therefore: nominal ETH TVL ≈ $1.63M, but **hard, redeemable money ≈ $714.5K (ETH) + $139.0K (BSC)**; the FILST/DFL/EFIL/mFIL legs are pool-implied or unsellable (no market/bridge).

---

## 6. Latent / privileged risks (not E-U today)

1. **Owner-key compromise (dominant).** FILST owner EOA `0x557EdaaF` can `setPoster()` to an arbitrary contract, which can then `FILST.mint()` **without NFT or fee** → dump into the pool → drain up to ~$714K USDT. Same key owns eFIL/mFIL and the `MiningNFTManage`/`MinerManage` whitelist, and is admin of the RewardPool proxy and the Unitroller.
2. **Mining-NFT leak.** If any mNFT unit escaped FILSTManage (it cannot today — no withdrawal function), the holder could mint FILST at a 5% DFL fee (236,008 DFL per 1,024 FILST ≈ $26.4 at spot) and dump it for ~$522/unit (verified in the PoC by fabricating the NFT). Scaling is bounded by DFL supply/liquidity (~125.8M DFL total; the DFL/USDT pool has only ~$946).
3. **Stale oracle** (`SimplePriceOracle`, 2021 prices: FILST $0.0061, EFIL $1.00, mFIL $1.25) — could matter for the lending markets, but borrowable cash is ~$1.6K and no borrows exist.

---

## 7. PoC / fork verification

- **Project:** `poc/` (Foundry, solc 0.8.24, vendored forge-std). Tests in `poc/test/DeFIL.t.sol`, pinned fork block **26,169,800**.
- **What it proves:** the custody numbers above; 10 outsider gates revert with exact messages; 3 holder-recovery paths succeed (LP staker, FILST staker, cFILST holder); the AMM exit-liquidity bounds; and the latent mint-and-dump P&L if an NFT were fabricated (`vm.store`).
- **CI:** GitHub Actions on `kingmariano/ca-zombie-ci` (public) — see `ci-log.txt` / `ci-artifacts/` and the run URL below.
  - Run: `https://github.com/kingmariano/ca-zombie-ci/actions/runs/…` (filled after run)
  - Result: **x/y tests PASS** (filled after run)

---

## 8. Verdict

**External unprivileged extractable, live: $0 (high confidence).** DeFIL is a dead-but-funded custody shell: the money is real and still there, but it is locked behind per-depositor share accounting (H-O) and an NFT-escrow mint gate; no public function lets a stranger move it. The realistic threats are key-compromise (owner EOA) and the (currently impossible) escape of a mining NFT — both privileged/latent, not E-U. Note also that the "value" is mostly pool-implied: only **$714.5K (ETH) + $139.0K (BSC)** is hard stablecoin; the rest is FILST/DFL/eFIL with no exit venue.

**Blockers for any future E-U path:** (a) FILSTManage has no NFT withdrawal — the 1,914 units are permanently escrowed; (b) all six staking instances are the same audited-by-construction Compound-style code with no admin surface; (c) no public FILST bridge between chains; (d) DFL/EFIL reward tokens are worth ~nothing.

---

## 9. Methodology, sources, caveats, files

**Method:** direct `eth_call`/`eth_getLogs` reads at pinned block; Etherscan V2 verified sources; GoldRush holder lists; bytecode hash comparison; read-only call simulations; Foundry fork tests on CI. No transactions; no secrets in this folder.

**Sources:** see `analysis/research/sources.json` (web) and `analysis/eth_state.json` (on-chain). Key verified sources: `Staking` (0.5.17), `FILSTManage`, `FILST`, `PriceConverter`, `FilstMarketCErc20Delegate`, `RewardPool`, `PrivilegedRedistributor`.

**Caveats:**
- FILST/DFL/EFIL prices are **pool-implied** (no oracle/market); DefiLlama prices FILST from the ETH pool only.
- The BSC leg was verified by a child audit (`analysis/bsc/`); DefiLlama omits the BSC FILST leg.
- `0x312c6ffe` is unverified on Etherscan but bytecode-identical to the verified `Staking` (hash `0xd3b82811…`).
- The mining-NFT escrow conclusion assumes the deployed FILSTManage bytecode matches its verified source (it does; ABI/selector set cross-checked).
- E-U = $0 does not mean "safe": a single owner key controls the mint; that is a privileged (P) risk, reported separately.

**Files index:**
```
defil/
├── README.md                     (this file)
├── summary.json                  (machine-readable)
├── analysis/
│   ├── eth_state.json            (pinned live state + gates)
│   ├── eth_audit.md              (contract-by-contract audit)
│   ├── eth_inventory.py/.json    (multicall inventory of 62 protocol contracts)
│   ├── research/notes.md         (web/corpus research)
│   ├── research/sources.json
│   └── bsc/                      (child audit: BSC state, bytecode, notes)
├── poc/                          (Foundry: foundry.toml, test/DeFIL.t.sol, lib/forge-std)
├── ci/run.sh                     (evidence dump job)
├── ci-out/                       (CI artifacts: state.json, exit_liquidity.json)
└── ci-log.txt / ci-artifacts/    (CI run log + artifacts)
```
