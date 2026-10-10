# BRIEF — Altura (HyperEVM) — $32.4M USD₮0 NAV vault

Read `analysis/CONVENTIONS.md` first. This is your per-protocol brief.

## Target

- **NavVault**: `0xd0ee0cf300dfb598270cd7f4d0c6e0d8f6e13f29` (HyperEVM, chain 999)
  - Verified source on Etherscan V2 (chainid=999): ContractName `NavVault`, solc 0.8.21, OZ 5.4 `AccessControl`.
  - Live reads (block 48,164,311): `asset()` = `0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb` (USD₮0, 6 dec);
    `totalAssets()` = 32,437,234.873245; `totalSupply()` = 29,636,794.853910 → share price ≈ 1.0945.
  - Finding context: "$32.4M USD₮0 NAV vault; full source reviewed; role-gated oracle/timelocks; low monitoring."
- Altura is a "liquidity manager / yield engine" — NAV-based vault shares. DefiLlama slug `altura`,
  TVL $32.4M (Hyperliquid L1). App: https://app.altura.trade. Docs site if reachable.
- Pull the FULL verified source (Etherscan V2 `contract/getsourcecode`, source is JSON with all files —
  the `SourceCode` field may be double-wrapped in braces; strip one layer if needed). Save to
  `analysis/altura/src/`. Read every external/public function.

## Required audit surfaces

1. **NAV/share math**: how `totalAssets`/share price is computed (NAV oracle? accounting var? rebasing?).
   - Deposit/withdraw share math: rounding, first-depositor inflation, donation attacks, fee-on-transfer.
   - Who can move NAV (oracle pusher / keeper / `report()`-style function)? Is any of it permissionless?
   - Check every function that increases `totalAssets` without token inflow (donation-style), and every
     path that lets an attacker mint shares cheaply or redeem expensive.
2. **Roles & gates**: enumerate `AccessControl` roles (`DEFAULT_ADMIN_ROLE`, keeper/oracle/manager roles),
   current holders of each role, any timelock. Verify each state-changing function's modifier against the
   live role holders. Note: "role-gated oracle/timelocks" was the finding's closure reason — re-verify it.
3. **Redemption gates**: can a fresh EOA withdraw? Pause/freeze? Blacklist? Withdrawal fees, caps,
   queued redemption, cooldown.
4. **Upgradeability**: check EIP-1967 slots and any proxy/delegatecall patterns; who can upgrade.
5. **Any unprivileged value-moving function**: sweep/claim/rescue/harvest/compound/rebalance that does not
   require a role; skim; emergency functions.

## Deliverable

- `analysis/altura/REPORT.md` (structure in CONVENTIONS.md §Dossier).
- PoC fork tests in `poc-altura/test/` — for every candidate path either execute extraction on a fork of
  HyperEVM state or prove the revert/gate with the live value that blocks it. Include a negative-results
  table (path → revert/gate → evidence). Prefer tests that read live balances in-test.
- CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`; your log: `ci-out/poc-altura.log`.
- Record exact block numbers for all reads; state confidence and coverage (fully audited vs screened).
- If you find a live extraction path: STOP at proof-of-concept on the fork (no mainnet tx), quantify net
  (after gas/flash fees), and write it up with the exact call sequence.
