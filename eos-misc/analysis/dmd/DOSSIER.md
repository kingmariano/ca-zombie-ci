# DMD Finance (EOS) — H2-05 dossier

Read date: 2026-10-10. Chain: EOS (Vaulta) mainnet, chain_id `aca376f2...0e906`.
EOS head block at final read: **524,644,740** (2026-10-10T11:57:10Z); CI re-verify head 524,645,678 (12:04:59Z).
All reads read-only via public `https://eos.greymass.com`; no transactions signed or sent.

## Contracts (from DefiLlama adapter `projects/dmd/index.js`, verified on-chain)

| account | created | token held (live) | USD | code sha256 |
|---|---|---|---|---|
| `eosdmdpool11` | 2020-09-03 | 44,728.4875 EOS | $4,645.5 @ $0.103867 | `80d2195e…629b` |
| `eosdmdpool12` | 2020-09-04 | 135,410.8398 USDT (tethertether, real USDT) | $135,410.84 | `d878289a…0dbb` |
| `eosdmdpool13` | 2020-09-04 | 75,235.9113 OGX (+2,000.1001 CCC, 68 DION dust) | $150.9 @ OGX $0.002006 | `4f9527b7…1858` |

Prices: EOS $0.103867 (CoinGecko 2026-10-10), OGX $0.00200586, USDT $1. DMD/CCC/DION reward tokens have no live price → $0.
Total real value ≈ **$140,207** (matches the corpus "~$140k").

## Permissions (live)

- **active**: no keys, single account permission `self@eosio.code` (threshold 1) — the contract can only act as itself through its own code.
- **owner**: threshold **22**; accounts/weights: `eosdefiadmin`=20, `eosnationftw`=1, `itokenpocket`=1, `slowmistiobp`=1 → effectively **3-of-4** (admin + any two of the other three). Owner can `setcode` (upgrade). No keys.
- `eosdmdworker` (the in-contract admin role): single key `EOS7PUT9cj…` on owner and active (P risk).

## Actions / ABI

`init, claim(from:name), exit(from:name), harvest(nonce:uint32), harvest2(nonce:uint32,count:uint32)`.
Tables: `stakepool`, `distribution`, `userstake {user, staked:asset, claimed:asset, unclaimed:asset}`.

## Authorization map — proven from decompiled WASM (wasm-decompile, pinned hashes)

Dispatch constants in `apply` (decoded EOSIO names): `init=8421045207927095296`, `claim=4921564679018381312`, `exit=6295346183808221184`, `harvest=7615504932250058752`, `harvest2=7615504932283613184`.

| action | handler | gate (first instructions) | WAT evidence |
|---|---|---|---|
| `exit(from)` | func 27 (table[3]) | `local.get 1` → `call 14` (**require_auth(from)**) then stake/accounting + inline transfer to `from` | eosdmdpool12.wat L1129–1136; dcmp `f_sb` builds transfer `{from=pool, to=b(=from), quantity=stake}`, `f_xb` removes the stake row via `env_db_remove_i64` |
| `claim(from)` | func 25 (table[6]) | `local.get 1` → `call 14` (**require_auth(from)**) then reward accounting | eosdmdpool12.wat L1011–1016 |
| `init` | func 23 | dynamic `require_auth` on struct name; data `eosdmdworker` | dcmp L1140+ |
| `harvest` | func 28 (table[4]) | builds name from data offset 1232 = **"eosdmdworker"** → `require_auth` | eosdmdpool12.wat L1140–1226 |
| `harvest2` | func 30 (table[5]) | same **eosdmdworker** `require_auth` | eosdmdpool12.wat L1333–1423 |
| token `transfer` notification | deposit credit | only accepted when `code` ∈ {tethertether, eosio.token, organixtoken} and action == `transfer` (notification path in `apply`) | dcmp apply B_s block |

Table pinning: `(elem (i32.const 0) func 103 23 32 27 28 30 25)` → exit uses table index 3 = func 27, claim uses index 6 = func 25 (both `(type 1) (param i32 i64)` handlers starting with `require_auth(param)`).

**No admin/withdraw action exists.** The only way to move pooled principal other than user `exit` is an owner-multisig `setcode`/`setabi` (3-of-4).

## Verdict

- **E-U = $0.00** (high confidence). No unauthenticated value mover: every action that touches value is gated by `require_auth(from)` (exit/claim) or `require_auth(eosdmdworker)` (init/harvest/harvest2); deposits can only be credited via genuine token-transfer notifications from whitelisted token contracts. An unprivileged attacker cannot pass an arbitrary `from`: EOSIO enforces that the transaction carries `from@active|owner` — the chain rejects otherwise.
- **H-O = $140,207.34** — each staker can self-withdraw via `exit(from)` (lock period long expired; `stakepool.epoch=1599183000` + 1-week duration; last pool activity 2024-07-19). Sums: 135,410.84 USDT + 44,728.49 EOS + 75,235.91 OGX + dust. `userstake` census: pool11 187 users Σ=44,728.4875 EOS; pool12 33 users Σ=135,410.8398 USDT; pool13 4 users Σ=75,235.9113 OGX — each exactly equal to the contract balance (no shortfall).
- **P = $140,207.34 latent** — owner 3-of-4 (`eosdefiadmin`+2) can replace code and seize everything; `eosdmdworker` single key can drive init/harvest.
- **S = $0** (dust DMD/CCC/DION counted at $0).

## Caveats

- No public EOSIO dry-run exists, so the negative result is proven statically (decompiled auth map + pinned code hashes) plus the EOSIO protocol rule for `require_auth`; the internal accounting of `exit` (remove-then-pay) was traced structurally but not state-simulated.
- Pools dormant since 2024-07-19; `userstake` rows for 100+ accounts; totals equal contract balances exactly (no shortfall).
- OGX/CCC/DION priced ≈ $0; USD totals use 2026-10-10 prices.

## Evidence files

- `eosdmdpool1{1,2,3}.wasm/.wat/.dcmp`, `eosdmdpool12_abi.json` — pinned binaries + decompiles.
- CI re-verification: `ci/verify_eos.py` (38/38 checks locally), `ci-out/eos-misc-verify.json`.
