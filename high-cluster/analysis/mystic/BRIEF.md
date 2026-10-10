# BRIEF — Mystic Finance (Flare + Plume + Citrea) — Morpho meta-vaults

Read `analysis/CONVENTIONS.md` first. This is your per-protocol brief.

## Target

Mystic = Morpho-stack lending frontend/infra ("Mystic makes it easy to build on Morpho").
Docs: https://docs.mysticfinance.xyz (Addresses page, Morpho REST API page).
Finding context: "$23.4M USD₮0 + 2.3M FXRP + 113M WFLR; $2.1M pUSD; Morpho meta-vaults; curator/oracle risk".
DefiLlama `mystic-finance-lending` (2026-10-10): Flare $28.11M, Plume $1.96M, Citrea $4.00M (Citrea extra —
check it too, but prioritize Flare). DefiLlama `mystic-finance-myplume` = $53k.

Known addresses:
- **Flare Morpho Blue singleton**: `0xF4346F5132e810f80a28487a79c7559d9797E8B0` (verified, name "Morpho").
- Flare "Mystic USDT0" token (likely a MetaMorpho vault share, `MUSDT0`): `0x0afC3D141AC0aEA5ee0d9E9d1E05Ec8240be33Cc`.
- Plume: Pool `0xCE192A6E105cD8dd97b8Dedc5B5b263B52bb6AE0`, Pool Configurator
  `0x0c8cE3082ddA7b4CaaE6866f751c7C60A7Ec6de8`, Pool Address Provider
  `0x6A5F6b4F1c7B8AFa16a941D52C4d706210E9ed2f`, Interest Rate Strategy
  `0xeD7F9Af764Cb9949b095A05f7ED78aE3A71d0697`, Leverage `0x9928b8bcC7DeA72cFb49958a14A971389fd178e6`.
  (These look like Aave-v3-style names — verify whether the Plume deployment is Morpho or an Aave fork.)

## Discovery tasks

1. Use the Mystic REST/GraphQL API (docs: `/api/mystic-morpho-rest-api.md`) to enumerate **all** vaults
   and markets per chain with their addresses, TVL, curator, oracle. Or enumerate on-chain:
   - Find all MetaMorpho vaults: Morpho Blue emits `CreateMarket`; vaults are separate ERC-4626 contracts
     with `MORPHO()`, `curator()`, `owner()`, `supplyQueue()`, `withdrawQueue()`, `allocation(Id)`.
   - Search Blockscout Flare (`/api/v2/search?q=Mystic`, `?q=Morpho`, `?q=vault`) and Plume.
2. Map each vault's markets → each market's `oracle`, `lltv`, `collateralToken`, `loanToken`, live
   `totalSupplyAssets`/`totalBorrowAssets`, and current oracle price vs market price.

## Required audit surfaces

1. **Morpho meta-vault curator risk**: `curator`/`owner`/`allocator` roles per vault; `submitCap`,
   `setSupplyQueue`, `updateWithdrawQueue`, timelocks (`timelock()`), `setFee`, `setGuardian`.
   Is any of this unprivileged? If not, classify as P with the exact role holder.
2. **Oracle risk per market**: what oracle feeds each market (Pyth? FTSO? API3? Redstone? custom adapter)?
   Check staleness, decimals, and whether the feed is manipulable (spot DEX pool vs push oracle). Any market
   with LLTV high enough + manipulable oracle = borrow-and-default extraction path.
3. **Permissionless Morpho entrypoints**: `supply`/`withdraw`/`borrow`/`repay`/`liquidate`/`accrueInterest`
   are permissionless by design. Enumerate markets where an attacker can:
   - borrow against overvalued collateral (bad oracle) and default,
   - liquidate positions at profit,
   - exploit LLTV/decimals edge cases (0-decimal tokens, rounding).
4. **Custom permissioning**: Mystic docs mention "Custom Permissioning" — find which markets/vaults are
   permissioned (deposit gating) and whether that gates the attacker or only users.
5. **pUSD / Plume**: the finding mentions $2.1M pUSD — find pUSD on Plume, what backs it, and whether the
   Mystic Plume pool exposes it. Also myPLUME ($53k) if quick.
6. **Flare specifics**: Morpho Blue on Flare was deployed ~Aug-Sep 2025; check `enableLltv`, `enableIrm`,
   `setOwner` — who is the owner of the Flare Morpho singleton (is it a timelock/Safe?).
   Check for any non-Morpho Mystic contracts on Flare (e.g. their own lending pool) — the Flare $28.1M
   must be fully attributed (vaults vs markets vs direct supply).

## Deliverable

- `analysis/mystic/REPORT.md` + evidence (vault/market table with addresses, roles, oracles, balances).
- PoC in `poc-mystic/test/`: fork Flare (public `https://flare-api.flare.network/ext/C/rpc`) and Plume
  (`https://rpc.plume.org`). Test borrow/liquidate against live markets, oracle checks, unauthorized
  curator calls. Negative results table.
- CI: `bash /home/heisenberg/CA/ci/ci-run.sh high-cluster`; your log `ci-out/poc-mystic.log`.
- Exact blocks; E-U/H-O/P/S amounts + USD; confidence; coverage statement.
