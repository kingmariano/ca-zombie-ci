# H-40 — Harmony Gnosis Safe L2 v1.3.0 sweep (4 treasury multisigs)

Block **93,624,315** (`0x59497fb`), chain 1666600000, RPC `https://api.harmony.one`, 2026-10-04 ~06:44 UTC.
All reads via `cast call` / `cast storage` / `cast balance` / `eth_getCode` (pinned to block) + Blockscout v2. **No tx signed or sent.**

## 1. Key results

| Safe | Address | ONE balance | Thr | Nonce | Owners | Modules | Guard | Fallback handler |
|---|---|---|---|---|---|---|---|---|
| A | 0x85049A5abed20A50d587C113F1Ef03d0Fd796453 | 42,654,070 | 3 | 13 | 5 | none | none | 0x017062a1dE2FE6b99BE3d9d37841FeD19F573804 |
| B | 0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80 | 40,421,863.773437 | 2 | 249 | 4 | none | none | same |
| C | 0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf | 30,990,103 | 3 | 11 | 5 | none | none | same |
| D | 0x59f93F30fc4B1429E2016DB36346299d80927690 | 24,000,105 | 3 | 8 | 5 | none | none | same |
| **Total** | | **138,066,141.773437 ONE** | | | 19 unique EOAs | | | |

Surprises vs the parent brief:
1. **A fallback handler IS set on all four** — the canonical CompatibilityFallbackHandler v1.3.0 (eip155 deployment). It is stored at the keccak-derived slot, not raw slot 1/2.
2. `getGuard()` / `getFallbackHandler()` **do not exist in SafeL2 v1.3.0** (selectors c9106389 / 856dfd99 absent from the singleton bytecode; added in 1.4.x). Their `0x` response is not evidence of anything.
3. `getModules()` (0xb2494df3) is absent from the singleton too; it is served by the fallback handler (which calls back into the Safe) and returned `[]` — matching `getModulesPaginated`.
4. Parent's guessed selector `0xa7e5d5f1` exists nowhere in singleton or handler (raw call → `0x`).
5. All owners are EOAs; **no owner appears in two Safes**, and none equals the OFT owner 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C.

RPC quirk (do not misread): `api.harmony.one` returns `{"result":"0x"}` for eth_calls that revert **without reason data**. Selector presence was verified against bytecode.

## 2. Code identity (task 2) — exact matches

- `proxyRuntimeCode()` on factory 0xc22834581ebc8527d974f8a1c97e1bea4ef910bc → 171 bytes, keccak `0xb89c1b3bdf2cf8827818646bce9a8f6e372885f8c55e5c07acbd307cb133b000`.
- All four Safes' code: 171 bytes, same keccak — canonical proxy, byte-identical to factory runtime.
- Singleton 0xfb1bffC9d739B8D520DaF37dF666da4C687191EA: 23,800 bytes, keccak `0x21842597390c4c6e3c1239e434a682b054bd9548eee5e9b1d6a4482731023c0f`.
- Ethereum 0x3E5c63644E683549055b9Be8653de26E0B4CD36E (block 26,117,341): 23,800 bytes, **same keccak**. safe-deployments v1.3.0 `gnosis_safe_l2.json`: codeHash `0x2184...`, Harmony chain → eip155 singleton = 0xfb1bffC9… → **exact match, no mismatch**.
- Fallback handler code: 5,492 bytes, keccak `0x03e69f7ce809e81687c69b19a7d7cca45b6d551ffdec73d9bb87178476de1abf` = registry CompatibilityFallbackHandler v1.3.0 codeHash; `NAME()` → "Default Callback Handler" (direct and via Safe fallback).

## 3. State, storage layout, owners (task 1)

v1.3.0 layout (proved on-chain): slot0 singleton · slot1 modules mapping · slot2 owners mapping · slot3 ownerCount · slot4 threshold · slot5 nonce. Guard/fallback live at hashed slots.

| Safe | slot0 | slot1 | slot2 | slot3 | slot4 | slot5 | guard slot 0x4a20…c34c8 | fallback slot 0x6c9a…918d5 |
|---|---|---|---|---|---|---|---|---|
| A | 0x…fb1bffc9…191ea | 0 | 0 | 5 | 3 | 13 (0xd) | 0 | 0x017062a1…573804 |
| B | same | 0 | 0 | 4 | 2 | 249 (0xf9) | 0 | same |
| C | same | 0 | 0 | 5 | 3 | 11 (0xb) | 0 | same |
| D | same | 0 | 0 | 5 | 3 | 8 | 0 | same |

Sentinel proofs (Safe A): `modules[0x1]` key `0xcc69885f…8792f` = `0x1` (empty list); `owners[0x1]` key `0xe90b7bce…7c2e0` = `0x4e4B14D9…` (list head). `getModulesPaginated(0x1,100)` = `([], 0x1)` on all four.

Owners (all `eth_getCode` = `0x`, i.e. EOAs; balance ONE in parentheses):
- A: 0x4e4B14D9E67A4d5fbB9CDc812927822bd0593F07 (100), 0x010afBb46a1b9535e367d7c0EF9626CaB7C7f455 (899.9178677), 0x76c0e19F8DDBd00C8d40006474b97a92d7138197 (999.9845037), 0xbBE3e1d26d01768720637f9c76A26EdC7Ea35cD7 (999.89351962), 0xad7c1a92eEE50666E3f8b19Ca1d99111faE79850 (999.9009853)
- B: 0xE48ec5A7468f155B0aBbE3BF910aA835B18aA7b4 (28.839), 0x26a4F6418b77650808D3F83e7e8A8f3B7f7C8B8c (23.627), 0xc4093E4bFA5f1af9000376D84dABe6a93A121fA1 (29.908), 0x938E64c866203C8da6C160B82b5B634B821be88a (19.983)
- C: 0x0Ff2196e14F51C11c20251A9BD34398665E624d8 (99.99), 0xDEED0a305a10d86D1dd13F6cfAE9Cf471a93cf1E (10,014.82), 0x4A0A8AE158D04F5c91483afe262DeF73C5E20b80 (99.98), 0x5e5F6A3FdfD7a5E4E9Bf5b7ca192bC3cB4A445DC (99.91), 0x1AEA0FFE6B2ffE73B764515CEE1D933685CEBb25 (99.92)
- D: 0xb042BA53d0F59EeE6C236143311eC31aBeA3AE98 (100), 0x9d75C2E7dBb55Ce3155d0Ab9d9c6672B11444C7F (103.64), 0xF647CC574E360E2a7F9A0358FA5ea767781DfeA9 (99.99), 0x1E34cB671cBC63eF43E907BaeA790F143146eACe (99.97), 0x0568ED3553b1df6da1B57e252aBa35ab68f1DD3c (100)

## 4. History & role (task 3)

Top-level history (Blockscout, complete: last page had no `next_page_params`): A 16 txs (13 `execTransaction`, 3 inflows); B 214 (211 exec + 3 inflows; nonce 249); C 14 (11 + 3); D 11 (8 + 3). `token-balances` = `[]` for all four.

Funding (native inflows):
- A: 84,000,000 ONE from EOA 0x61E1F047b24FadBb8e1618F810f9b9732609Ef6d @36466229 (2023-01-11) + 3 ONE from same @36466056 + 100 from 0xF2422db03401dB382b7eC30f02446d1aB5B23B55 @36169841. (+14,003.97 internal from 0x6C3dC93E… @36463464)
- C: 84,000,000 from 0x61E1… @36466252 + 5 ONE @36466079 + 100 from 0x8B7f208CA557dD9c8140C171324572720193469c @36172478 + ~20,000,003 internal from EOA 0x0bcF358aBd14EA55f2976d7C46Fc33EB93D8D64f @36464009/36464283/36464464
- D: 84,000,000 from 0x61E1… @36466273 + 7 ONE @36466090 + 100 from 0x8B7f208C… @36172484 + ~15,000,003 internal from EOA 0x84Cb1EC3dE853C10726A1f1C231Dd1c86daEa9D1 @36464712/36464843
- B: funded by **sibling Safes** — internal 133,000,000 ONE from 0x6dDe2a1Ab12402ee9Ca2e6BA8d9620bD624Ca245 (7 xfers 2025-09→2026-07) and 54,500,000 ONE from 0xB3D6a512947B192e49C1cD42f7472A3C4CfBC682 (10 xfers 2024-08→2026-01); both are also canonical SafeL2 v1.3.0 proxies (proxy code keccak matches, slot0 = 0xfb1b…, identical 6 owners, threshold 3). Plus 429,553.26 ONE from 0x83163DA8… @68398466 and 51,000 ONE from 0xD473C7Cc… @45173988/61795637.

Inner calls (decoded from `decoded_input`): **all value movements are plain native ONE transfers to EOAs** — B → 0x83163DA8/0x69eCAfba/0x84Fd56E1 (and others); A → 0x010afB (owner) + 0xFA0A9d2A41cB0f9af3969D7BAc3dEC31ae0373F1; C → 0xDEED0a (owner); D → 0x9d75C2 (owner). Self-targeted execTransactions are only `addOwnerWithThreshold` (A@36251701, C@36257119, D@36384604, B@56664524, B@65124257) and `removeOwner` (B@56664910, B@56664920, B@65124372) — owner churn. **No `enableModule`, `setGuard`, `setFallbackHandler` or delegatecall/multiSend calls ever.**
Counterparties carry **no names or public tags** (no Binance/Harmony labels); 0x61E1… is an EOA. Handler was set at creation by `setup()`.

**Role:** private/ecosystem **native-ONE treasury & payout multisigs** (team/vesting/ops), not an exchange or bridge deposit address: no tokens, no deposit-memo patterns, payouts to individual EOAs.

## 5. Owner overlap (task 4)

All pairwise intersections **empty** (19 unique owner EOAs). OFT owner 0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C is **not** an owner of any of A–D.

## 6. Unprivileged attack surface (task 5)

- Modules: none (`getModulesPaginated` = `([], 0x1)`; `modules[0x1] = 0x1` sentinel). Guard: unset (slot 0x4a20… = 0).
- Fallback handler: canonical CompatibilityFallbackHandler v1.3.0, invoked via `call` (not delegatecall) from the Safe fallback — exposes EIP-1271 `isValidSignature`, `getMessageHash`, `getModules`, `simulate` (always-revert helper), ERC-721/1155/777 receiver callbacks. It cannot move Safe funds.
- `execTransaction` from random EOA 0x1111…1111 (eth_call only): empty sigs → `GS020`; 65 zero bytes → `GS020`; 195 zero bytes (3×65) → `GS021`; 195 bytes with r=1,s=1,v=27 → `GS026`. v1.3.0 requires ≥ threshold×65 signature bytes and each recovered signer to be an owner.
- Conclusion: **no unprivileged path to move funds**; control is 3-of-5 / 2-of-4 EOA keys. Only non-owner-callable surface is the handler's call-context functions (EIP-1271 validation is the notable trust surface for external integrators).

## 7. Artifacts

`analysis/h40-state.json` (machine-readable), `analysis/h40_state_raw.txt` (raw cast outputs), `analysis/h40_txs_{A,B,C,D}.json` + `h40_txs_B_p*.json` (top-level txs), `analysis/h40_itxs_*.json` (internal txs), `analysis/h40_safe_l2_deployments.json` (safe-deployments registry entry), `analysis/h40_queries.sh` (reproducible read script).
