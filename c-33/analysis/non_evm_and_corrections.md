# C-33 — corpus corrections and non-EVM / non-cToken ports (document-only)

All facts below were re-verified on-chain where an EVM exists (block numbers in `ci-out/scan.json`);
the rest cite the primary repos/docs.

## A. Corpus corrections (Compound-v2 lineage claims that do NOT hold)

| Corpus claim | Verified reality | Evidence |
|---|---|---|
| Starlay is part of the Compound-v2 empty-market lineage | **Aave v2 fork** | `github.com/starlay-finance/starlay-protocol` tree: `contracts/protocol/lendingpool/LendingPoolConfigurator.sol`, `contracts/interfaces/ILendingPoolAddressesProvider.sol`, `markets/starlay/reservesConfigs.ts` — Aave layout, not cTokens |
| Geist (Fantom) | **Aave fork** | Geist docs/academic analyses: "core protocol is based on AAVE" |
| Valas (BSC) | **Aave v2 fork** | `valas-finance/valas-protocol` README: "Core protocol based on Aave Protocol v2" |
| Voltage (Fuse) | **Aave fork** | docs.voltage.finance: "This lending feature is a fork of the trusted and audited Aave Protocol" |
| Ironclad (Mode) | **Aave fork, bricked** | DefiLlama adapter `ironclad/index.js` uses Aave-style provider; corpus verified provider reverts |
| Onyx "markets still live (no pause found)" | **Closed**: every market `mintGuardianPaused=true`, `borrowGuardianPaused=true`, `collateralFactor=0` | Ethereum block 26,109,165 (2026-10-03): `markets(oXCN)=true,0`; pause reads true; scanner output |
| Scream "no pause checks in the cToken" | **Paused per-market**; only two unpaused markets (`scFBTC`, `scFETH`) are phantom listings with **no contract code** | Fantom: `mintGuardianPaused(scUSDC/scDAI/scWFTM/scLINK)=true`; `eth_getCode(scFBTC)=0x` |
| Tectonic post-hack | **All markets mint+borrow paused** (guardian containment) | Cronos: tUSDC `0xb3bbf1be947b245aef26e3b6a9d777d7703f4c8e` and tCRO `0xeadf7c01da7e93fdb5f16b0aa9ee85f978e89e95` both true for mint+borrow |

These corrections matter: the campaign's "surviving unfixed forks" list is smaller than the corpus
suggested, and the largest suspected pools (Tectonic ~$20M, Ionic ~$21.6M, Scream ~$1.24M, Onyx
~$31.7k) are closed by pause/CF=0/phantom-market facts, not by patched math.

## B. Non-EVM ports (no test)

| Port | Chain | Status | Evidence |
|---|---|---|---|
| zkLend | Starknet (Cairo) | **Dead**: Feb-11-2025 empty-market + accumulator manipulation (~$9.6M); protocol shut down 2025 | SlowMist/Halborn post-mortems; The Defiant "zkLend shuts down" |
| ABEL Finance | Aptos (Move) | Live but small (~$218k TVL, DefiLlama 2026-10-03); flagged Compound-v2 fork (`forkedFromIds=114`) | DefiLlama protocol metadata + `abelfinance/index.js` |
| Other Move lending (NAVI, Suilend, Scallop, Echelon, Aptin, Echo, Aries) | Sui/Aptos | Not classified as Compound-v2 forks by DefiLlama; no cToken-equivalent empty-market evidence reviewed | DefiLlama `forkedFromIds` absent |

No Move toolchain scan was run (mission scope: document-only). If ABEL's Move market module copies the
`exchange_rate = (cash + borrows - reserves) / total_supply` + truncating redeem pattern, the same class
could apply; it was not measured here.

## C. Resupply (Ethereum) — custom share-market, class already realized

- 2025-06-26: donation attack on a newly deployed crvUSD vault; ~$9.56M; attacker donated to inflate
  the vault exchange rate then borrowed. Sources: Halborn "Explained: The Resupply Hack", Olympix
  post-mortem, Rekt.
- Current deployment (2026-10-03) is not cToken-based: DefiLlama adapter reads "Pair" contracts via
  `getAllPairAddresses()` on `0x10101010E0C3171D894B71B3400668aF311e7D94` (LendingOps), TVL ~$54M.
- Not measured here (different accounting; post-hack redeployment). Treat as latent class risk pending
  a dedicated share-market review.

## D. Two rules proven by the fork tests (addendum)

1. **T=0 rule.** The borrow attack requires `totalSupply == 0`. A market with even 1 wei of supply
   held by someone else is not exploitable: the attacker can mint their own wei but can never burn
   the other holder's, so `redeemUnderlying(cashNow−1)` either leaves them with zero collateral
   (comptroller returns INSUFFICIENT_SHORTFALL — captured in the OCP/BSC trace) or recovers only part
   of the donation (net ≤ CF×cash0/2, dust). This closes Paxo, OCP and every `tinySupply` market.
2. **Protocol borrow-rule rule.** Even a T=0 market with CF>0 and open mint needs the protocol to
   allow a borrow large enough to matter. Midas Capital's risk engine enforces
   `minBorrowEth() = 143.919681304257721877` (contract `0xf656D243a23A0987329ac6522292f4104A7388e1`)
   while the fMIMO-3 comptroller holds only $5.86 of unpaused cash; `borrowWithinLimits` rejected the
   fork-test borrow (`Failure(…, 16, 18)`, return 1018). Closed.

Final verdict: **$0 live extractable**; the class remains a latent deployment risk for new listings.
