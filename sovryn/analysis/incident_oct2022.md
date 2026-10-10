# Oct-2022 Sovryn exploit — reconstructed recipe & fix (research notes)

Sources: Sovryn official postmortem (2022-10-24), interim update, PR #453, rekt.news/Beosin,
Halborn, SolidityScan, forum threads; cross-checked against on-chain data (see below).

## Incident
- Date: 2022-10-04, 01:30–08:00 UTC. Attacker EOA `0xC92ebeCdA030234c10E149bEEAd6BBA61197531A`.
- Helper contracts: `0xe40151f2b79816bC00d277AddB991c4E16607D22` (first, deployed 01:30:32),
  `0xDaA2e727738f742FF1a2FCD2C6419Dc6BEfBFf6C`, `0xa893cdcb731ae8f91cb50f51f28980cdba96b0a6`,
  `0x23B2Df5d429cA8f189Fd57D5Bc4B35f5dE580731`.
- First exploit tx: `0xf5ea6266a56f4e0135b73f63050afca7146bc940ac73da8b5fade9d8031582e2`
  (block 4,689,413; top-level `attack(uint256,bytes32)`).
- Losses (final postmortem): **44.9368 RBTC + 282,351.9644 rUSDT ≈ $1.1M**.
- Recovered: 26.7610 ETH, 60.8476 BNB, 17.717 RBTC, 19,511.1505 USDT; pools refilled by
  Exchequer on 2022-10-24. Fix deployed 2022-10-24 14:14 UTC via Exchequer multisig.

## Mechanism — cross-contract reentrancy (stale iToken price window)
iToken price = (pool assets + protocol-registered outstanding loans) / iToken supply.
During a loan close the protocol **first updates its loan register** (numerator falls) and
**only afterwards transfers the principal into the pool**. Anything that mints iTokens inside
that window buys them "at a discount"; once the principal lands, price rises and the attacker
burns at a profit.

- **iUSDT leg (ERC-777 hook):** attacker borrows rUSDT (ERC-777) against WRBTC collateral,
  then calls `closeWithDeposit`. The rUSDT repayment transfer triggers the ERC-777
  `tokensToSend` hook on the attacker contract **before** the tokens move; inside the hook the
  attacker calls `iUSDT.mint` at the stale price. Observed in the replay of `0xf5ea6266...`:
  - mint 26,000 rUSDT → 22,653.5998 iUSDT at price **1.14772** (stale)
  - transfer completes; price rises to **1.19569**
  - burn 22,653.5998 iUSDT → 27,086.63 rUSDT → **≈ +1,086.6 rUSDT per cycle**, 5 cycles/tx.
- **iRBTC leg (native RBTC fallback):** `closeWithSwap` refunds excess RBTC to the borrower as
  native value; the attacker's `receive()` fires and calls `iWRBTC.mint` at the stale price.
  E.g. tx `0x6978434f...`: deposit 53.0000 WRBTC → mint 264.3780 iWRBTC at ≈0.2005; burn
  → 55.2291 WRBTC (≈0.2088) → ≈ +2.23 WRBTC/cycle.

## Capital requirement
- **No flash loan protocol** — Uniswap-V2-style **flash swaps** across three RSK pairs:
  `0x818c0A92aaE155E93419b5a7323e8e8Ae649f287` (5.34 WRBTC), `0xc9FE8e7a47eFF9f62F2684A540619D52FBcd6649`
  (1.77), `0x1Dd8665EC5f47416Ff37beB2De5CF7B095D377ad` (1.09) ≈ **8.20 WRBTC** flash capital.
- Own funds ≈ dust (≈0.03 RBTC).

## Fix (PR #453, merged 2022-10-21; deployed 2022-10-24)
1. **Global mutex guard** `globallyNonReentrant` (SharedReentrancyGuard.sol, hardcoded Mutex
   `0xba10edD6ABC7696Eae685839217BdcC42139612b`): every guarded call increments a counter and
   checks it is unchanged at exit; a nested guarded call therefore makes the **outer** call
   revert.
2. **Supply invariant** `iTokenSupplyUnchanged(loanId)` in LoanClosingsShared.sol:
   `require(previousITokenSupply == ILoanTokenModules(loanLocal.lender).totalSupply(), "loan token supply invariant check failure")`.
3. Applied to `closeWithDeposit`, `closeWithSwap`, `liquidate`, `rollover` (closing side) and
   `mint`, `burn`, `borrow`, `marginTrade`, `mintWithBTC`, `burnToBTC` (iToken side).

## On-chain verification of the fix today (this assessment)
- Active closing module `0xa3FCC9F88De9a7f0258eda6cD8d6F7D39ef6fb8d` (LoanClosingsWith):
  verified source shows `nonReentrant globallyNonReentrant iTokenSupplyUnchanged(loanId)`
  on both closers; deployed bytecode contains the Mutex address and the invariant string
  `"loan token supply invariant chec..."`.
- Same for `LoanClosingsLiquidation` `0xd01B701b...` and `LoanClosingsRollover` `0xdB4fF0a8...`.
- All live iToken logic modules (0x6c8f59D3, 0x593DB96E, 0xD0dbAe16, 0x45569950) and both
  beacon module versions (v0 Oct-2023, v1 Sep-2026) contain the Mutex address.
- **Oct-2022 logic** (iUSDT mint target at block 4,689,412 = `0x82C49eC67389B6e8c377eD1Da7816b9add4e3B1e`)
  does **not** contain the Mutex → guard absent pre-fix.
- `cast run 0xf5ea6266...` replay of the original exploit (pre-fix fork) succeeds with the
  5 mint/burn cycles above (see `oct2022_exploit_replay_local.txt`); the same call shape is
  blocked today (CI test `test_05`, `test_06`).
