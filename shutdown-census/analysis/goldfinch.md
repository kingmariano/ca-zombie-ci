# Goldfinch — Ethereum

## Status & shutdown evidence (sources, dates)
- **GIP-87 "Maintenance Mode of Goldfinch Operations and Wind-Down Goldfinch Prime"**, posted 2026-06-12 on gov.goldfinch.finance (topic /t/gip-87.../2202). Stops new development/growth; keeps legacy app alive to "collect repayments"; creates a US trust for legacy recoveries (trustee Ted Gavin). Prime was fully redeemed (post #13, 2026-07-07; no new deposits; Prime contract paused).
- DefiLlama adapter `projects/goldfinch/index.js` explicitly skips the *borrowed* metric after **2026-06-01**: "protocol is insolvent/ winding down" citing GIP-87.
- On-chain: SeniorPool implementation was upgraded on **2026-09-15 18:53 UTC (block 26004942)** by the protocol owner multisig `0xBEb28978B2c755155f20fd3d09Cb37e300A6981f` (Safe execTransaction → MultiSend at `0x40a2accb…`, tx `0xc67bf64ade1f06db975c8c33c24092bbb76f112d78ebefab4a25192255673715`). The batch: USDC 500 → FIDU/USDC Curve LP; `FIDU.unpause()`; `SeniorPool.upgradeToAndCall(0x656cc68d…, da13e908-initdata)`. The init data consumed a one-time flag (slot 0xc9) and burned FIDU from a hard-coded list of ~24 addresses (FIDU `Transfer(from,0x0)` logs), emitting custom event `0xfe9efcfc…`. **New implementation `0x656cc68d76c7dea07b477ffd26f6c9766d154e5e` is NOT verified (Etherscan/Sourcify), superset of the old SeniorPool ABI (45 old selectors + 2 new).**

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
All reads at Ethereum block **26117051** (unless noted) via NodeReal RPC; code checks also at 26116895 publicnode.

| Address | Role | Code/Verified | Proxy | Owner / admin | paused |
|---|---|---|---|---|---|
| 0x8481a6EbAf5c7DABc3F7e09e44A89531fd31F822 | SeniorPool | live; proxy verified EIP173Proxy (custom impl slot) | impl `0x656cc68d76c7dea07b477ffd26f6c9766d154e5e` **unverified** (was `0x3612…`, verified source recovered) | owner=`0xBEb28978B2c755155f20fd3d09Cb37e300A6981f` (Safe multisig) | `paused()=false`, `usdcAvailable()=0`, `currentEpoch.endsAt=1792087643`, `sharePrice=0.944448e18`, `sharesOutstanding≈3.6425e25`, `totalLoansOutstanding=51,571,695.008 USDC`, `totalWritedowns=17,095,606.385` |
| 0xd20508E1E971b80EE172c73517905bfFfcBD87f9 | GFFactory | live verified `GoldfinchFactory` (impl `0x7954d6…`) | EIP173 | owner same Safe | n/a |
| 0x57686612C601Cb5213b01AA8e80AfEb24BBd01df | PoolTokens (LP NFT) | live verified `PoolTokens` (impl `0x412d7d…`) | EIP173 | owner same Safe | n/a |
| 0x6a445E9F40e0b97c92d0b8a3366cEF1d67F700BF | FIDU (correct address; brief's `…66Ebd332` was wrong) | live verified (proxy, 1826-byte code) | EIP173 | config-bound | was unpaused in same Sep-2026 tx |
| 0xdab396cCF3d84Cf2D07C4454e10C8A6F5b008D2b | GFI | live verified immutable ERC20 | no | n/a | n/a |
| 0xE2da0Cf4DCEe902F74D4949145Ea2eC24F0718a4 | TreasuryReserve | live | proxy | Safe | n/a |
| 0x71cfF40A44051C6e6311413A728EE7633dDC901a | SeniorPoolStrategy | live | – | – | – |
| 0x9a16a929Edc11d2691Cb5fBC2BeE2545878ae79b | TranchedPool impl repository | live EIP173 | impl `0x84b43e…` | Safe | – |
| 0xc84D4a45d1d7EB307BBDeA94b282bEE9892bd523 | WithdrawalRequestToken (ERC721) | live | – | – | totalMinted=1005 |
| 0x84AC02474c4656C88d4e08FCA63ff73070787C3d | Go (KYC) | live | – | – | – |

**All 32 TranchedPools are EIP-1167 minimal clones** (45-byte code), impl variants: 13× `0x187E45EbAf88f63Ebf0319dEae51DF8955423869` (MigratedTranchedPool), 8× `0xdc694367a9b32768b6d3b5df34f062a7d29c9230` (TranchedPool, verified source read), 8× `0xcd123dd7b07e164bf1b33fc639a8f7a04c3370`, 3× `0x38dd72b21cbb6023b9818060c541d2ce7d4d10`. Factories/versions differ; all use the same GoldfinchConfig and each has its own admin (config admin).

TranchedPool source (impl `0xdc6943…`, verified) gating:
- `withdraw/withdrawMax` → `_withdraw`: `require(isApprovedOrOwner(msg.sender,tokenId))`, `require(goOnlyIdTypes(msg.sender,…))` (KYC), `require(currentTime() > lockedUntil)`, `amount ≤ redeemable`; USDC paid to `msg.sender`. **Holder+KYC only.**
- `assess()` permissionless → pulls borrower payment from the CreditLine into the pool's tranche accounting; funds stay for LP holders. `pay(amount)` pulls from msg.sender; `emergencyShutdown()` onlyAdmin sweeps to reserve (privileged). No path pays the caller.

## Live balances (token, amount, USD, price source, block)
USDC `0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`, price $1.000 (fixUSD stables), block **26117051**:

| Holder | USDC | USD |
|---|---|---|
| SeniorPool 0x8481…F822 | 1,783,983.897112 | $1,783,983.90 |
| 32 TranchedPools (sum; per-address in raw) | 174,759.637707 | $174,759.64 |
| CallableLoan 0x032f7299… | 2,240.538803 | $2,240.54 |
| **Total SP+TP+CL (DefiLlama base)** | **1,960,984.073622** | **$1,960,984.07** |
| TreasuryReserve 0xE2da0C… | 3,133.921174 | $3,133.92 |
| V1 legacy Pool 0xB01b315e… | 120.000000 | $120.00 |
| FIDU/USDC Curve LP 0x80aa1a80… | 18,465.315807 | $18,465.32 (LP; not protocol-owned) |

Largest TPs: 0x759f097f… 58,188.32; 0xd09a5712… 29,946.73; 0x00c27fc7… 19,309.43. Raw: `raw/goldfinch_usdc_balances.json`.

## Permissionless paths examined (path → gates → live values → verdict)
1. **SeniorPool.withdraw(uint256) / withdrawInFidu(uint256)** → selector 0x2e1a7d4d/0x58031d12 → `onlyZapper` (ZAPPER_ROLE, owner-managed). Non-holder caller reverts. NOT permissionless.
2. **SeniorPool.redeem(uint256 tokenId)** → permissionless, but `pool.withdrawMax(tokenId)` reverts unless the SeniorPool itself owns the PoolToken (`isApprovedOrOwner(SeniorPool, tokenId)`), and value is credited to SeniorPool/FIDU holders, not caller. No caller payout.
3. **SeniorPool.invest(pool)** → permissionless but only deploys pool USDC into a valid pool via strategy; cannot direct funds to caller.
4. **SeniorPool.requestWithdrawal/addToWithdrawalRequest/cancelWithdrawalRequest/claimWithdrawalRequest** → require `goSeniorPool(msg.sender)` (KYC) or NFT ownership (`ownerOf(tokenId)==msg.sender`); payouts only to the request NFT owner. **Holder-only (H-O).** 1.784M USDC sits in the pool with `usdcAvailable()=0`, i.e. fully earmarked to the current withdrawal epoch; only request-NFT holders can claim, minus withdraw fee.
5. **TranchedPool.assess()** (permissionless, whenNotPaused) → borrower CreditLine payments move into pool; LP redemptions still KYC+NFT-gated. **No caller payout.**
6. **TranchedPool.pay()** → caller pays; no payout.
7. **TranchedPool.emergencyShutdown()** → `onlyAdmin`, sweeps pool+credit-line USDC to reserve. Privileged (P).
8. **New SeniorPool impl selectors** `0x0bc35e98` (no-arg view → returns 1/true; benign) and `0xda13e908` (6+ arg, one-time flag-consumption, `address(this)==0x8481…` check, burns FIDU from supplied addresses, writes slot 0x1cf=1, uses FIDU/USDC Curve LP) — disassembled, no permissionless outflow surfaced; it was executed once atomically inside `upgradeToAndCall` (owner-only entry) and its guard flag (slot 0xc9) is consumed. The 3rd extracted selector `0x6aac2c5b` is not in the dispatcher (coincidental bytes in a comparison/interface check).
9. **Goldfinch Prime** `0xCBbd935861542d94a168cAC3B523f6450a69ECF4` (per GIP-87 post #13): paused, ~$300 of unclaimed redemptions; `withdraw()` callable by the original redeemer (holder-only frontend-less claim). Not part of DefiLlama $1.96M base.
10. **FIDU** is a live ERC20; `sharesOutstanding` ≈ 3.64e25 vs `sharePrice` 0.944 → implied ~$34.4M vs only $1.78M idle USDC + $51.6M loans outstanding − $17.1M writedowns (~$36M net). The gap to cash is loan recovery risk, not an extraction path.

## Approvals / user-side residual risk
- FIDU holders must be Go/KYC-listed to request withdrawal; USDC approvals to SeniorPool still work. The Sep-2026 migration burned FIDU for a hard-coded list of addresses inside an owner multisig tx (their choice, executed for them).
- No residual approval path found that lets a third party pull a user's USDC into themselves on the live SeniorPool/TranchedPool code (the old GIP-85 test-contract bug was a different, non-public 2020 deployment `0x0689aa22…`, already neutered).

## Classification: **H-O** — $1,960,984.07 — confidence **medium-high** — what would change it
- Holder/user-only recoverability: SeniorPool withdrawal queue (KYC + request-NFT), TranchedPool KYC+NFT withdrawals; no unprivileged extraction path found on verified code (and archetype checks on the unverified SeniorPool delta).
- **E-U: $0.**
- Would change: verified source of `0x656cc68d…` revealing a new permissionless payout/claim with a live flag, or discovery that request-NFT ownership/KYC can be bypassed. Fork-test candidate: `withdraw`/`claimWithdrawalRequest` variant calls against the new impl; `assess()` on TPs is harmless.
- Secondary risk: if the wind-down stops processing, funds become **S/P** (KYC list frozen, owner-multisig-controlled claims) rather than H-O.

## Raw evidence index (files in analysis/raw/)
- `goldfinch_etherscan_seniorpool.json`, `..._seniorpool_impl.json` (old verified SeniorPool source/ABI), `..._seniorpool_live_impl.json` (unverified marker), `..._gffactory.json`, `..._gffactory_impl.json`, `..._pooltokens.json`, `..._pooltokens_impl.json`, `..._tp_sample.json`, `..._tp_impl.json`, `..._config.json`, `..._v1pool.json`, `..._tprepo.json`
- `goldfinch_factory_logs.json` (32 PoolCreated + 1 CallableLoanCreated + 12 CreditLineCreated + 16 BorrowerCreated)
- `goldfinch_usdc_balances.json` (all balanceOf reads, block 26117051)
- `goldfinch_code_probe.json` (EIP-1167 impl clustering)
- `goldfinch_sp_impl_upgrades.json` (7 ProxyImplementationUpdated events; last = block 26004942)
- Local analysis artifacts (not in analysis/): `newimpl.hex`, `SeniorPool.sol` (old impl 0x3612…), `TranchedPool.sol`, `ConfigOptions.sol`, selector diff 48 vs 45 (new: 0x0bc35e98, 0xda13e908).
