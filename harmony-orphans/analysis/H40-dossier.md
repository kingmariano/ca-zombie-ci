# H-40 dossier — four Harmony Gnosis Safe L2 v1.3.0 treasury multisigs

**Status:** read-only research. All reads via `cast call` / `cast storage` / `cast balance` / `eth_getCode` +
Blockscout v2; no tx signed or sent. Fork-verified in CI (`poc/test/HarmonyOrphans.t.sol`, 11/11 PASS, run 37188265963).
**Block of record:** Harmony 93,624,315 (2026-10-04). Price: ONE = $0.00245693 (DefiLlama, 2026-10-04).
Detailed sub-report (with raw evidence): `analysis/h40-safes.md`, `analysis/h40-state.json`, `analysis/h40_state_raw.txt`.

## 1. Resolution of the abbreviated addresses (H-40 lead `0x85049A5…`, `0x3Ef056E…`, `0x399b8bB…`, `0x59f93F3…`)

The first three were in the Blockscout top-balance page; the fourth was resolved by enumerating all
`ProxyCreation(address,address)` events of the Safe proxy factory `0xc22834581ebc8527d974f8a1c97e1bea4ef910bc`
(330 proxies) and matching the `0x59f93F3` prefix:

| # | Full address | ONE balance | Threshold | Nonce |
|---|---|---|---|---|
| A | `0x85049A5abed20A50d587C113F1Ef03d0Fd796453` | 42,654,070.000000 | 3-of-5 | 13 |
| B | `0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80` | 40,421,863.773437 | 2-of-4 | 249 |
| C | `0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf` | 30,990,103.000000 | 3-of-5 | 11 |
| D | `0x59f93F30fc4B1429E2016DB36346299d80927690` | 24,000,105.000000 | 3-of-5 | 8 |
| | **Total** | **138,066,141.773437 ONE ≈ $339,219** | | |

All four are canonical Gnosis **Safe L2 v1.3.0** proxies (`VERSION()` = "1.3.0"), all created by the same factory.

## 2. Code identity (no backdoor — exact matches against Ethereum / safe-deployments)

| Component | Harmony code keccak | Canonical reference | Match |
|---|---|---|---|
| Safe proxy (171 B) | `0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000` | factory `proxyRuntimeCode()` (same keccak) | yes |
| SafeL2 singleton (23,800 B) at `0xfb1bffC9d739B8D520DaF37dF666da4C687191EA` | `0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f` | Ethereum `0x3E5c63644E683549055b9Be8653de26E0B4CD36E` (block 26,117,341) | yes |
| CompatibilityFallbackHandler v1.3.0 at `0x017062a1dE2FE6b99BE3d9d37841FeD19F573804` | `0x03e69f7ce809e81687c69b19a7d7cca45b6d551ffdec73d9bb87178476de1abf` | Ethereum same address | yes |

## 3. Live state (block 93,624,315)

- Storage slots (v1.3.0 layout): slot0 = singleton, slot1 = modules (0), slot2 = owners (0), slot3 = ownerCount (5/4/5/5),
  slot4 = threshold (3/2/3/3), slot5 = nonce (13/249/11/8).
- `getModulesPaginated(0x1,100)` = `([], 0x1)` on all four (no modules). `enableModule` never called (history).
- Guard slot `0x4a204f62…c34c8` = 0 on all four (no guard).
- Fallback-handler slot `0x6c9a6c4a…918d5` = `0x017062a1dE2FE6b99BE3d9d37841FeD19F573804` on all four
  (canonical handler, set by `setup()`; handler executes via `call`, exposes EIP-1271 + receiver callbacks,
  cannot move Safe funds).
- `getGuard()` / `getFallbackHandler()` do not exist in v1.3.0 (they are 1.4.x); the Harmony RPC returns `0x`
  for empty reverts — use the hashed slots/registry, as done here.
- Owners: 19 unique EOAs (code size 0), **no owner appears in two Safes**, and the "ONE for BSC"/"ONE for Ethereum"
  OFT owner `0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C` is in none of them.
- No HRC20/HRC721 token balances (`token-balances` = `[]`).

## 4. History / role

Complete top-level histories: A 16 txs (13 exec), B 214 (211 exec; nonce 249), C 14 (11 exec), D 11 (8 exec).
Funding: A, C, D each seeded **84,000,000 ONE** on 2023-01-11 by EOA `0x61E1F047b24FadBb8e1618F810f9b9732609Ef6d`;
B was funded by two sibling canonical Safes (`0x6dDe2a1A…`, `0xB3d6a5…` — both now hold 0) plus smaller inflows.
All value movements are plain native transfers to EOA counterparties (team/vesting-style payouts); the only
self-targeted execTransactions were `addOwnerWithThreshold`/`removeOwner`. No `enableModule`, `setGuard`,
`setFallbackHandler` or delegatecall/multiSend calls were ever made. Counterparties carry no public tags.
**Role: private/ecosystem native-ONE treasury & payout multisigs** — not exchange or bridge custody.

## 5. Unprivileged attack surface (fork-tested)

| Path | Result |
|---|---|
| `execTransaction` from arbitrary EOA, empty sigs | revert `GS020` |
| 65 zero bytes (1 sig) | revert `GS020` (needs ≥ threshold×65) |
| 195 zero bytes (3 sigs) | revert `GS021` |
| 195 bytes with r=1,s=1,v=27 | revert `GS026` (signer not owner) |
| Modules / guard / delegatecall entry points | none exist |
| Fallback handler call-context functions | EIP-1271/receiver only — cannot move funds |

## 6. Verdict

- **E-U: $0 (high confidence).** No permissionless path: canonical Safe v1.3.0 + canonical proxy + canonical handler,
  no modules, no guard, threshold signatures strictly enforced.
- **P: 138,066,141.773437 ONE ≈ $339,219** — recoverable only by the multisig owners (3-of-5 / 2-of-4 EOA keys).
- **S: $0.** (If any owner set is permanently lost, the corresponding Safe becomes S; key liveness cannot be
  determined from chain data alone — caveat, not a finding.)
- Lead (negative): sibling Safes `0x6dDe2a1Ab12402ee9Ca2e6BA8d9620bD624Ca245` and `0xB3d6a512947B192e49C1cD42f7472A3C4CfBC682`
  distributed all funds and hold 0 ONE today.

## 7. Files

`analysis/h40-safes.md` (full sub-report), `analysis/h40-state.json` (machine-readable), `analysis/h40_state_raw.txt`
(raw outputs), `analysis/h40_txs_{A,B,C,D}.json`, `analysis/h40_itxs_*.json`, `analysis/safe_factory_proxies.json`
(all 330 factory proxies used to resolve `0x59f93F3…`).
