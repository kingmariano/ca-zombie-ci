# C2-02 incident & state timeline (Base, chain 8453)

All data read live via Base RPC / Blockscout / Etherscan V2. No transactions sent.
(Recreated after an external wipe of the working folder on 2026-10-05 ~19:12; content restored from the session records, CI snapshot and the independent child review.)

## Incident (2026-10-04, blocks 52,154,795 – 52,158,062)

| Block | Event | Tx |
|---|---|---|
| 52,154,795 | attacker EOA `0x0B5126e1bc27C0de77e02e97945760A674EdB034` deploys helper proxy `0xcdFE91301356da873562EF513828a60dba1F569d` (impl `0x5d7a38144b4d17f47a22e3d0987523cd68b43310`, attacker-deployed) | `0xb4d1c2f4a0425802da69b73101f790bbab7df3aef70592eaeb1344d3d1e78692` |
| 52,156,053 | helper `initialize()` (owner = attacker EOA) | `0x122dc220f35d9b806f1bace46bf67d146001c8700b9cee141f7f04307e269ce5` |
| **52,157,298** | **owner Safe `0x6b27512a5943Ed327f6cb6C3EC1f0398229f42C4` executes `whitelist(helper, 0)`** (revoke) | `0x27cbab36ebe21754a01f964fb6c341e1d162cc413aa744df409de26d4cbd715d` |
| **52,157,342** | **owner Safe executes `whitelist(helper, 1)`** (grant) — 44 s later, valid signatures (per public reporting) | `0xed265fc80e4abe42d72d6bfd1623c89dd2d12f544d53d4ca2c9c3d0fefbf2810` |
| 52,157,377 | helper borrows 1.0 aBaswstETH | `0x0ec75c3be1f55bb08a92421796675e051993cdb6cbc38d5e33cc2b7f6ef2f491` |
| 52,157,773 | helper borrows 100 aBaswstETH | `0xa08b02678971f1dd3ada15721fd760ceb2846270e5b23a5bc6aa983bab7b459b` |
| 52,157,905 | helper borrows 182.067 aBaswstETH | `0xf1c9448c615122423c5f21aad2f690e76dfe7b9e9bfc320b1d36ef79a7a9cd7e` |
| 52,158,007 | helper borrows 500 aBaswstETH | `0x0832709749dbeddabcee648a936cac1d8456b8e0f0c45f3f0516e4ac66c0a154` |
| 52,158,036 | helper borrows 500 aBaswstETH | `0x212dc5e03214abe70b5e37ffcb22c8dd8710e82397badf8f687d9164eaec80ac` |
| 52,158,062 | helper borrows 500 aBaswstETH | `0x327e47ad60274fc3bde84ddbb054fde45b97a571fa4931be5d19a5ba5806543f` |
| — | **Total 1,783.067 aBaswstETH ≈ $6.0M** (matches public reports: Blockaid/PeckShield/CertiK/ExVul; CryptoTimes; Blockonomi; news.bitcoin.com "7 mystery signers") | |

Call path per borrow: `attacker EOA → helper.__withdraw(aBaswstETH, X)` (selector `0x9a39f8dd`) `→ vault.borrow(aBaswstETH, X, 0, 0, helper)` (selector `0xa415bcad`) `→ aBaswstETH.transfer(helper, X)`.

## Post-incident (no remediation)

| Block | Event |
|---|---|
| 52,157,981 | last incident tx (helper `cb984317` redeem) |
| 52,209,090 | copycat EOA `0x0820DC0cf398d4ee78a3dEc5ffbb5357f4586278` deploys proxy helper `0x13Fed10846B5fE35601452731d7b847adC7722a9` (impl `0x965A9a77…`) |
| 52,209,387 | copycat helper `initialize(0x0820DC0c…)` |
| 52,210,655 | copycat calls `callBorrow(aWETH, MAX)` → **reverts `!W`** (tx `0x77b5a7463d2492413de6f95c2c4e7c3f450cb6c39605330645f3540eb64b2be8`) |
| 52,210,663 | copycat retries → **reverts `!W`** (tx `0x484a982d9df3099cd467980d87f3526e4d385c31a349bd3d00363e7b860a6a89`) |
| latest | `whitelist(helper)` is **still true**; owner Safe has executed no tx since 52,157,342 |

## Vault history

- Created block 26,107,572 by `0x4fF634EF57c2497C6cf9Eb415e326C5D8fc8c104` (also created sibling `0x416Ec2cA…`).
- Ownership: `0x4fF634EF…` → `0xC7320789606b2ebe6CBAC97AB33B36A2e3c78174` (37,994,612) → Safe `0x6b27512a…` (38,166,336).
- Impl upgrades: `0x6Ba0A6A2…` (26,107,572) → `0xe90fAf38…` (39,790,481) → `0xBae563E6…` (44,541,671) → `0x06b0d5a7…` (44,888,886) → `0x209d85f0…` (45,628,440, current; unverified).
- ProxyAdmin: `0x490ca969b43B1Ab869B5959A7b3919Cc2c37C4e6` (Aave BGD ProxyAdmin, solc 0.8.14) owned by Safe `0x47a60e3D6121B216cD22984df5976a41e15baF77` (3-of-8).

## Whitelisted borrowers (independent child enumeration, triple-RPC verified)

**The vault whitelist holds 33 addresses — not 2.** Setter history: 14 direct calls by owner#1 `0x4fF634EF…` (13 grants + 1 revoke) + 24 owner-Safe exec setter calls (23 grants + the helper 0→1 pair). Only 2 addresses revoked (`0xd84636a8…`, `0x8b060ca3…`, now false).

| Bucket | Count | Detail |
|---|---|---|
| Attacker helper | 1 | `0xcdFE9130…` — contract, `__withdraw` owner-gated to `0x0B5126e1…`; ProxyAdmin `0x3065d790…` owned by same EOA |
| EOA | 1 | `0x3E68796A3A43a0a6a2B40Bc9ABF8e372e7a7Ff36` — user; 1,440 direct borrows historically; key = borrower capability |
| Protocol account contracts | 31 | TransparentUpgradeableProxy accounts (12 impls); every nonpayable function probed from fresh → `Ownable`/`!G` (owner/guard-gated). One fresh-executable fn (`255617e7()`) only STATICCALLs a read-only contract. No third-party-triggerable borrow/withdraw. |
| Copycat helper | 0 (false) | `0x13Fed…` — attempts reverted `!W` |

Whitelist (all `true`): `0x3e68796a…` (EOA), `0xda9884fd`, `0xc23cffaa`, `0x0d0e3190`, `0xe83cd757`, `0x891694e3`, `0xdf8be1e6`, `0x92aafa6b`, `0x30b685d8`, `0x3683a176`, `0x59193d6b`, `0x97db2260`, `0xcdfe9130` (helper), `0xffe4d54c`, `0x9ce3cac9`, `0x158c7575`, `0x34a05bb8`, `0xd4714c07`, `0xcfa6b29a`, `0x09a7c55b`, `0x41616242`, `0x6bc6c940`, `0x8bcdb937`, `0xf5773fb7`, `0xf8478d00`, `0x122e7bec`, `0x6ebb1dae`, `0xea49bec3`, `0x2afbb576`, `0x4d192577`, `0xe2e6bcd5`, `0x31fdc043`, `0xb4ec1fea`.
Full addresses and evidence: `analysis/whitelist_verified.json`, `analysis/independent_freshpath_review.md` §c.

**Sibling whitelist: 92 contracts, 0 EOAs** (same account family; 12 impls, all fresh-probed gated); `0x92aafa6b…`/`0x30b685d8…` are whitelisted on both vaults.

**Owner-Safe exemption (privileged):** `vault.borrow` called by the owner Safe `0x6b27512a…` succeeds *without being whitelisted* (fresh → `!W`). The 3-of-7 Safe can therefore borrow directly; `withdraw` from the Safe still reverts `!WWE`. Same exemption on the sibling.

## Live state measurements (aWETH bound moves with ETH price)

| Block | aWETH balance | max additional borrow | USD | ETH price |
|---|---|---|---|---|
| 52,213,000 (pinned local) | 11,761.285370638167 | 8,300.486481076223 | $22,424,649.21 | $2,701.61 |
| 52,214,619 (CI #1 dump) | 11,761.302822883363 | 8,289.798958759297 | $22,325,983.56 | $2,693.19 |
| 52,215,826 (CI #2 fork) | 11,761.315821863511 | 8,296.719736902052 | $22,389,599 | $2,698.61 |
| 52,218,505 (post-wipe re-measure) | 11,761.344615865677 | 8,308.908767478480 | $22,503,802.81 | $2,708.39 |

At every block: `whitelist(helper)=true`, `whitelist(0x3e68…)=true`, helper aWETH = 0, Aave HF ≈ 3.39–3.41; bounded by Aave `finalizeTransfer` (`HealthFactorLowerThanLiquidationThreshold()`, `0x6679996d`).

Full-equity route (CI #2 fork, block 52,215,826): 11,736.315821863511 aWETH taken, gross $31,671,722.81, repaid $7,760,536.88 → **net $23,911,185.93**.
