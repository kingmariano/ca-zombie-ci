# H2-06 — Non-EVM custody watches deep dive (Stader HBARX · VeChain StarGate · Arkadiko · HashKing/FILLiquid · Virtue)

**Date:** 2026-10-10 · **Chains:** Hedera, VeChain, Stacks, Filecoin (FEVM), IOTA (Rebased MoveVM)
**Status:** read-only; no transactions signed or sent on any network; all proofs are chain-native
read-only simulations (eth_call / Thor `accounts/*` / Hiro call-read / Filecoin eth_call / IOTA view/dry-run)
plus CI-run probe suites. No secrets; keyless public endpoints only.

*(skeleton — final numbers filled from per-chain dossiers)*

## 1. Headline

| Chain | Target | Live custody measured | Class | **E-U (headline)** | Conf. |
|---|---|---:|---|---:|---|
| Hedera | Stader HBARX | 411,519,289 HBAR ≈ $37.91M | H-O (+P overhang) | **$0.00** | high |
| VeChain | StarGate | TBD | TBD | **TBD** | TBD |
| Stacks | Arkadiko Swap v2 | TBD | TBD | **TBD** | TBD |
| Filecoin | HashKing / FILLiquid | TBD | TBD | **TBD** | TBD |
| IOTA | Virtue | TBD | TBD | **TBD** | TBD |
| **Total** | | | | **TBD** | |

## 2. Method (all chains)

- Read-only access per chain (Hedera mirror+Hashio, VeChain Thor REST, Stacks Hiro API,
  Filecoin glif RPC, IOTA Rebased RPC); every claim cited with address + height + call.
- Contract reconstruction from verified source (Sourcify/GitHub) or bytecode; live roles,
  balances, pause/upgrade state read at recorded heights.
- Per-path adversarial audit: only public, unprivileged call paths counted as E-U; value that
  holders/users can self-serve is H-O; privileged-only is P; bricked is S.
- Proof by chain-native read-only simulation (eth_call / clause simulation / call-read / dry-run);
  no mainnet transactions.

## 3. Per-chain findings

### Hedera — Stader HBARX (details: `analysis/hedera/DOSSIER.md`)
TBD summary.

### VeChain — StarGate (details: `analysis/vechain/DOSSIER.md`)
TBD.

### Stacks — Arkadiko Swap v2 (details: `analysis/stacks/DOSSIER.md`)
TBD.

### Filecoin — HashKing / FILLiquid (details: `analysis/filecoin/DOSSIER.md`)
TBD.

### IOTA — Virtue (details: `analysis/iota/DOSSIER.md`)
TBD.

## 4. Totals

TBD.

## 5. CI evidence

- Hedera probe run 1 (23/23 PASS): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38049734864
- Final combined run: TBD.

## 6. Coverage & caveats

TBD.

## 7. Files

TBD.
