> **SUPERSEDED (kept for provenance):** this is the parent's quick source-level pass. It assumed a
> mid-2024 v2.5.x base; the child subagent's `fork-diff.md` established the true base (Dec-2023–Mar-2024,
> package v4.2.3, 94/109 files byte-identical) and bytecode-verified 17/17 deployed Mode contracts.
> Use `fork-diff.md` as the authoritative diff; the bottom-line conclusion (no fork-introduced extraction
> path) is identical in both.

# Fork-vs-canonical diff (parent quick pass)

**Purpose:** verify that Splice's Pendle-V2 fork introduces no semantic change that could create an
unprivileged extraction path. Method: fetch canonical `pendle-core-v2-public` files at commit
`f813e95df662ea108f3eba589efe5031f314c3bf` (2024-06-13, the era of Splice's deployment) and diff against
`github.com/splice-finance/contracts-public` (cloned at `/tmp/opencode/splice-contracts`).
Read-only; no keys; public sources only.

| File | Diff lines (non-comment) | Material changes |
|---|---|---|
| `core/StandardizedYield/SYBase.sol` | **0** | none — byte-identical modulo whitespace |
| `core/StandardizedYield/implementations/PendleERC4626SY.sol` | 0 (trailing `}`) | none |
| `core/StandardizedYield/PYIndex.sol` | **0** | none |
| `core/Market/MarketMathCore.sol` | **0** | none (AMM math identical) |
| `core/Market/v3/PendleMarketV3.sol` | 10 | cosmetic only: `PendleERC20`→`PendleERC20Permit`, `NAME/SYMBOL` = "Splice Market"/"SPLICE-LPT" |
| `core/YieldContracts/PendleYieldToken.sol` | 6 | cosmetic only: `PendleERC20`→`PendleERC20Permit` |
| `core/YieldContracts/InterestManagerYT.sol` | **0** | none |
| `core/YieldContracts/PendlePrincipalToken.sol` | 6 | cosmetic only: `PendleERC20`→`PendleERC20Permit` |
| `core/YieldContracts/PendleYieldContractFactory.sol` | 0 (trailing `}`) | none |
| `core/RewardManager/RewardManagerAbstract.sol`, `RewardManager.sol` | 0 | none |
| `router/ActionMiscV3.sol` (May-2024 commit `24e108be`) | 4 | revert-string → custom-error refactor only (`redeemDueInterestAndRewards`/`redeemRewards` still pay `user`) |
| `router/base/ActionBase.sol` (same commit) | 12 | revert-string → custom-error refactor only |
| `router/ActionSwapYTV3.sol` (same commit) | 6 | revert-string → custom-error refactor only |
| `router/ActionSwapPTV3.sol`, `router/base/CallbackHelper.sol` | 0 | none |
| `router/PendleRouterV3.sol` | n/a | not present at canonical path in May-2024; Splice's file is a diamond-proxy wrapper (their own) — no accounting logic |

Reproduce:
```
SHA=f813e95df662ea108f3eba589efe5031f314c3bf
curl -s https://raw.githubusercontent.com/pendle-finance/pendle-core-v2-public/$SHA/contracts/core/Market/MarketMathCore.sol \
  | diff - <(cat splice-contracts/src/core/Market/MarketMathCore.sol)
```

**Router note:** at the May-2024 canonical commit `24e108bee3ccaf6abcf4a007b97d4666a55743ef` the action
contracts differ only by revert-string→custom-error refactors; all payout receivers are still the
user-supplied `user`/`receiver`. No redirection.

**Conclusion:** the fork's core accounting/AMM/reward contracts are semantically identical to canonical
Pendle V2. The only modifications are the ERC20Permit base (permit support) and naming. No fork-introduced
extraction surface. Custom components are limited to (a) `PendleERC4626SY`-derived SYs with a supply cap
(verified identical to canonical `PendleERC4626SY` + `supplyCap` guard), (b) Mode L2 SY wrappers that
redeem 1:1 in the underlying (`PendleEzETHL2SY`, `SpliceWeETHL2SY`, `SpliceWrsETHL2SY`), and (c) the
backing ERC4626 vaults (analysed in `vaults.md`).

Limitation: this compares *source repos*; the deployed market/YT/SY bytecode was validated functionally
(live `readState`/`_storage`/`burn`/`skim`/`redeemPY` behaviour matches, plus 15/15 fork tests in `poc/`).
