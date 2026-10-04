# Avon MegaVault — MegaETH

## Status & shutdown evidence (sources, dates)
- DefiLlama `protocol/avon-megavault` (retrieved 2026-10-04): currentChainTvls **MegaETH $11,390.72**. Methodology from `registries/erc4626.js` (retrieved 2026-10-04): `'avon': "TVL is the underlying USDm managed by MegaVault, measured via the ERC4626 totalAssets() value"`, vault `0x2eA493384F42d7Ea78564F3EF4C86986eAB4a890`.
- No shutdown announcement found for Avon in the bounded pass (task context: census bucket "MegaETH $11.4K").

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
Reads via `https://mainnet.megaeth.com/rpc` at **block 28303717** (2026-10-04).

| Address | Role | Code | Owner | Notes |
|---|---|---|---|---|
| 0x2eA493384F42d7Ea78564F3EF4C86986eAB4a890 | MegaVault (ERC-4626) | live, 44,047-byte code (verified status not checked) | `owner()=0x566eCaE8fCBbE0D0355f4a33E4BB6a82E5FAFEe1` | `name()="USDm Yield"`, `symbol()="USDmY"`, `asset()=0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7` (USDm), `paused()` reverts (no standard pausable) |
| 0xFAfDdbb3FC7688494971a79cc65DCa3EF82079E7 | USDm (underlying) | not probed | – | 18 decimals expected |

## Live balances (token, amount, USD, price source, block)
- `totalAssets() = 11,339,110,892,131,772,783,148` (≈ **11,339.11 USDm**) and `totalSupply() = 11,339,110,364,912,097,079,649` shares at block **28303717** → **share price ≈ 1.0000000** (no in-kind donation/skew visible). USDm assumed $1.00 (stable; DefiLlama TVL $11,390.72 confirms).
- Live value held: **≈ $11,390.72** (DefiLlama) / $11,339.11 (on-chain totalAssets; small oracle/риск difference).

## Permissionless paths examined (path → gates → live values → verdict)
1. **ERC-4626 `deposit`/`mint`/`withdraw`/`redeem`** — standard depositor paths; an external attacker depositing only gains pro-rata shares; `totalAssets == totalSupply` at read time, so no obvious donation/inflation rounding edge. Withdrawal gating not examined (no `paused()`; unknown receiver whitelist/queue).
2. **Donation/inflation attack** — classic ERC-4626 first-depositor inflation would require the vault to be near-empty/rounding-vulnerable; here totalAssets ≈ totalSupply and the vault is small but non-empty. **No evidence of exploitability in this bounded pass.**
3. **Owner function `processReport()`/strategy accounting** (per DefiLlama methodology note for the sibling vault family) — not probed for this vault; owner `0x566e…` is an EOA/small contract. Privileged path unverified.
4. **No pause/unpause surface found** (`paused()` reverts).

## Approvals / user-side residual risk
- Depositors must call `withdraw`/`redeem` themselves; no third-party acceleration path identified. Any USDm approval given to the vault is only spendable via `deposit` semantics.

## Classification: **H-O** — $11,390.72 — confidence **low-medium** — what would change it
- Depositors can (presumably) redeem their own shares; no unprivileged extraction beyond a depositor's own funds identified.
- **E-U: $0.**
- Would change: verified source shows a permissionless `processReport`/donation/mint flaw, a redeem-gating bug, or if `totalAssets` is manipulable by an unprivileged caller (e.g. strategy accrual callable publicly). Bounded pass did not check owner privileges or withdraw gating.
- **Status note: bounded identification/balance pass only — restart/time interruption limited depth.**

## Raw evidence index (files in analysis/raw/)
- `avon_reads.txt` (block 28303717 reads), DefiLlama `api.llama.fi/protocol/avon-megavault` + `registries/erc4626.js`.
