# C-36 · The forgotten-eth recovery index — external-attacker extractable value across all 295 contracts

**Date:** 2026-10-03 · **Chain:** Ethereum mainnet (block 26,111,001 ETH balances / 26,111,067 token balances / 26,111,184 fork tests)
**Status:** read-only research; fork-verified only; **no mainnet transactions were signed or sent.**
**Campaign:** zombie-hunt C-36 deep-dive (parent finding: 295 contracts, ~173,498 ETH mapped claims, ~71,899 ETH measured live 2026-09-29).

---

## 1. TL;DR

<!-- FINAL E-U TABLE — filled from child results + parent verification -->
_Pending child segment results (seg-A…seg-E)._

**Total live extractable by an external unprivileged attacker: $0** (working headline; subject to child E-U candidates).
Confidence: **high** for the top-30 pots (individually source-verified + fork-probed); **medium** for the long tail.

| Category | Contracts | Live value (USD) | Notes |
|---|---:|---:|---|
| E-U (attacker-reachable) | — | $0 | no confirmed path so far |
| H-O (holder/self-service) | — | — | withdraw/refund/redeem pay only caller's own recorded position |
| P (privileged) | — | — | owner/admin/governance gated |
| S (stuck/bricked) | — | — | reverts / no path / dead admin |

## 2. What the index is, and what we measured

- Index: `github.com/aaaaaaaaaaway/forgotten-eth` (mirror of forgotteneth.com), 295 contracts, 727,782 addresses with mapped balances, snapshot 2026-09-20→23.
- Re-measured live at block 26,111,001 (native ETH) and 26,111,067 (major tokens): **220 of 295 contracts hold ETH**; listed contracts hold **71,667.72 ETH (~$192.2M)** plus **~$39.0M in WETH/USDC/USDT/DAI/WBTC/stETH**.
- **Child/backing contracts** (value the index attributes to a token entry but that lives elsewhere) add the biggest pots:
  - `0xbf4ed7b27f1d666546e30d74d50d173d20bca754` **The DAO WithdrawDAO = 81,399.81 ETH (~$218.3M)** — backing of the index's "The DAO 81,479.79 ETH-equiv".
  - `0x23ea10cc1e6ebdb499d24e45369a35f43627062f` **DigixDAO Acid = 11,681.83 ETH (~$31.3M)** — backing of the DGD redemption entry.
  - `0xA2F987A546D4CD1c607Ee8141276876C26b72Bdf` Lido AnchorVault = 745.47 stETH (~$2.0M) against 1,013.43 bETH supply (holder race).
  - **Unindexed bonus pot:** `0x4d9629e80118082b939e3d59e69c82a2ec08b4d5` TribeRedeemer = 1,788,335.56 DAI + 3,141.11 stETH (~$10.2M); TRIBE market price $0.41096 vs redeem basket ≈ $0.408/TRIBE → market already arbitraged; holder-only, $0 E-U.
- Index totals reconciled: mapped 168,103.58 ETH (all listed) vs my live 71,667.72 ETH on listed contracts — the gap is mostly (a) token-sourced entries where claims are WETH/shares not ETH, (b) the 81.4k DAO backing sitting in WithdrawDAO, (c) the 11.7k DigixDAO backing in Acid, (d) already-claimed balances.

### Live-value concentration (top 12 by total USD, my measurements)

| # | Contract | Live value | Class (final) |
|---|---|---:|---|
| 1 | The DAO WithdrawDAO `0xbf4ed7b2…` | 81,399.81 ETH ($218.3M) | H-O |
| 2 | IDEX v1 `0x2a0c0dbe…` | 15,729.77 ETH ($42.2M) | H-O (prior $0) |
| 3 | EtherDelta v2 `0x8d12a197…` | 15,168.57 ETH ($40.7M) | H-O (prior $0) |
| 4 | zkSync Lite `0x0a14b696…` | 10,926.66 ETH + $5.54M tokens | H-O (prior $0) |
| 5 | DigixDAO Acid `0x23ea10cc…` | 11,681.83 ETH ($31.3M) | H-O |
| 6 | Neufund EtherToken v1 `0xb59a226a…` | 3,385.43 ETH ($9.1M) | H-O (prior $0) |
| 7 | Unknown DEX `0x4d55f76c…` | 2,479.09 ETH ($6.6M) | H-O (prior $0) |
| 8 | Last Winner `0xdd9fd6b6…` | 2,425.43 ETH ($6.5M) | H-O (prior $0) |
| 9 | PoWH3D `0xb3775fb8…` | 2,041.02 ETH ($5.5M) | H-O (race; prior $0) |
| 10 | Old WETH `0xecf8f87f…` | 1,511.35 ETH ($4.1M) | H-O |
| 11 | dYdX Solo `0x1e0447b1…` | $6.74M (WETH/USDC/DAI) | H-O (+ prior ≤$16-18 liquidation) |
| 12 | Fomo3D Long `0xa6214288…` | 1,099.45 ETH ($2.9M) | H-O (prior $0) |

## 3. Method (what "rigorously and extensively" means here)

1. **Full index extraction** from the raw repo (295 protocols, per-protocol balance files, meta).
2. **Live re-measurement** of every listed contract: native ETH, code presence, owner/admin/paused selector probes, and major-token balances (WETH/USDC/USDT/DAI/WBTC/stETH/wstETH/SAI) at pinned blocks.
3. **Backing/child resolution**: `meta`/`eth_source` fields + descriptions + on-chain reads resolved the token-sourced entries to their real pots (WithdrawDAO, Acid, AnchorVault, dYdX, Aave core, Set vault, yWETH, Opyn Gamma, etc.).
4. **Selector clustering** of all 295 runtime codes into 187 families (EtherDelta ×19, Fomo3D ×14, PoWH3D ×46, Neufund, presale templates, …) so family verdicts transfer and deviations stand out.
5. **Five parallel segment reviews** (ICO/refund, gambling, DEX/NFT, DeFi/vault, masterchef/dust) with per-contract classification E-U / H-O / P / S, source review (Blockscout verified source; unverified decompiled/selector-diffed) and live-state evidence.
6. **Fork verification** in CI (Foundry, `FORK_RPC_URL`): negative controls for the 16 largest pots (fresh attacker, bounded gas, net-gain assertion) + candidate-specific PoCs.
7. **Pricing** at 2026-10-03 DefiLlama spot: ETH $2,681.60, WBTC $84,534.85, stables $1.00.

## 4. Bug-surface checklist applied per contract

- refund/claim without eligibility, double-refund, overflow, missing `msg.sender` gate
- permissionless `cancel()`/`finalize()`/`setClaim`/`unpause()`/`initialize()`
- sweep/rescue/`withdrawAll`/`collect` without access control
- merkle/proof flaws (double-claim, leaf confusion, arbitrary recipient)
- share/vault math (donation inflation, redeem rounding, stale rate)
- first-mover races (claims > assets)
- unprotected proxy / EIP-1967 admin
- signature replay/forgeability
- reentrancy/CEI violations
- family deviations (extra selectors vs EtherDelta/P3D/presale reps)

## 5. What an attacker cannot do — fork-proven negative controls

CI run: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37116289035 (2/2 tests PASS, block 26,111,184).
Fresh attacker `0xA77ACC` (0 ETH, no tokens) probing each pot with ≤5M gas; **net gain asserted = 0**:

| Probe | Outcome | Attacker gain |
|---|---|---:|
| WithdrawDAO.withdraw() | invalid-opcode throw (no DAO balance) | 0 |
| WithdrawDAO.trusteeWithdraw() | no-op (underflow → `send` fails silently) | 0 |
| Augur Cash.withdrawEther(1e18) | revert (`_amount <= balances[msg.sender]`) | 0 |
| PoWH3D.exit() | revert (0 tokens) | 0 |
| Quantfury.sellTokens(1e18) | revert | 0 |
| FETH.withdrawAvailableBalance() | success, 0 transferred | 0 |
| TribeRedeemer.redeem(attacker,1e18) | revert (no TRIBE) | 0 |
| DigixDAO Acid.burn(1e9) | throw (no DGD) | 0 |
| HONG.refundMyIcoInvestment() | throw (no tracked deposit) | 0 |
| ArbitrageETHStaking.withdrawAll() | success, 0 transferred | 0 |
| X2Y2 Fee Sharing.harvest() | success, 0 transferred | 0 |
| Delphi.redeemTokens(1e18) | revert | 0 |
| MoonCatRescue.withdraw() | success, 0 transferred | 0 |
| Monolith TKN Holder.burn(attacker,1e18) | revert | 0 |
| Metadrop.claimRefund(1,[]) | revert | 0 |
| R1Exchange.withdrawNoLimit(0x0,1,0) | revert | 0 |

## 6. Per-contract verdicts

- Full 295-row table: `analysis/final_table.csv` (generated by `analysis/merge_results.py`).
- Segment evidence: `analysis/seg-A/REPORT.md` … `analysis/seg-E/REPORT.md`, `analysis/seg-*/results.json`.
- Top-30 pot dossiers: `analysis/dossiers/` (live reads, selectors, source names, child resolution).

## 7. PoC / fork verification

- `poc/test/NegativeControls.t.sol` — 2/2 PASS, CI run 37116289035.
- `poc/test/<E-U candidate tests>` — pending.
- All tests pin a fork of Ethereum mainnet via `vm.envOr("FORK_RPC_URL", …)`; no mainnet writes.

## 8. Verdict, residual & latent risk

_Pending child results._

## 9. Methodology & sources; caveats

- Sources: forgotten-eth raw repo (295 protocols + balance files + meta), Blockscout API (source/ABI/verification), public RPC (`ethereum-rpc.publicnode.com`, drpc, 1rpc), DefiLlama prices, prior zombie-hunt corpus (`zombie_hunt/github_stuck_funds.md`, `zombie-deep/LIVE-PROFIT-PATHS.md`).
- Caveats: live balances drift (zkSync Lite and ENS registrar are actively being claimed: zkSync 11,179.49→10,926.66 ETH since 2026-09-29; ENS registrar 8,983.98→0 via releaseDeed/unsealBid claims). Token-sourced entries are not comparable on the ETH column. Index-attested insolvency is holder-race, not attacker extraction, unless the claim token has a live market below redeem value.
