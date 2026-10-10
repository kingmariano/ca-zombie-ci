# WhaleEx / `whaleextrust` (EOS) — H2-05 dossier

Read date: 2026-10-10. Chain: EOS (Vaulta) mainnet, chain_id `aca376f2...0e906`.
EOS head block at final read: **524,644,740** (2026-10-10T11:57:10Z). All reads read-only via public `https://eos.greymass.com` and Hyperion (`https://eos.hyperion.eosrio.io`); no transactions signed or sent.

## What it is

`whaleextrust` (created 2018-07-15, code last updated 2025-04-18) is the WhaleEx exchange "trust" contract account. It holds the exchange's EOS-chain token balances. WhaleEx (whaleex.com) was an EOS-based DEX/exchange; activity on these accounts stopped in **Aug 2025** (whaleextrust last action 2025-08-15; tokens.wal last action 2025-08-17). Dormant since.

## Live balances (verified at head block above)

| token (contract) | amount | USD @ 2026-10-10 | backing |
|---|---|---|---|
| USDT (`tokens.wal`) | 2,426,381.86411885 | $2,426,381.86 | exchange IOU — `tokens.wal` holds only 216.52 USDT real (`tethertether`) |
| BTC (`tokens.wal`) | 14.80068211 | $1,225,690 @ BTC $82,817 | exchange IOU — real BTC held by `tokens.wal` account: 0.100001 BTC (`eosiorealbtc`) + 0.00007724 (`tokens.wal`) |
| WAL (`whaleextoken`) | 718,772,298.73 | $0 (no market) | — |
| EBTC (`whaleextoken`) | 1,033,110 | $0 (no market) | — |
| ~48 other tokens (CPM 3.54B, INSUR 362M, …) | — | $0 | dead/illiquid |
| EOS liquid | 10.0441 | $1.04 | — |

Face total of the two priced IOUs: **$3,652,071.86** (matches the corpus "$3.70M"). The token contract `tokens.wal` itself holds only ~$216 USDT + 0.1 BTC of real backing, `whaleexgate5` 61.30 USDT, `tianshu.eos` 1,074.05 USDT — so the IOUs are **custodial claims on off-chain exchange reserves**, not redeemable against on-chain collateral.

## Key / permission structure (live)

- `whaleextrust`: **owner = active = the same single key** `EOS58SzHxGtcxNyWhKGmEuhDhiN8spS8re5CA9XN3rghNowkFZWaL`; no eosio.code on active; extra `staking` permission delegated to `eosdefiproxy@eosio.code`.
- `tokens.wal` (token contract; **byte-identical** to `whaleextoken`, sha256 `a8667849…e5a4`): owner single key `EOS5GF3Uzzrm99skHn1JyxkBzs4bRNcmQzd3buj7rrB1eRw1qv4Ec`; active = key `EOS6JrUS7…` + eosio.code for `namebid.wal`, `tianshu.eos`, `tokens.wal`, `whaleexdebit`, `whaleexgate4`, `whaleexgate5`.
- **The same owner key `EOS5GF3Uzz…` is owner of the entire WhaleEx EOS infrastructure**: `tokens.wal`, `whaleextoken`, `whaleexdebit`, `whaleexgate2`, `whaleexgate3`, `whaleexgate4`, `whaleexgate5`, `whaleexadmin`, `namebid.wal`, `tianshu.eos`, `eosdefiproxy`, `miner1.wal` (13-account sweep in `whaleex_accounts_sweep.jsonl`; active keys differ per account, some multi-key, but the single owner key can rotate them). One key compromise = full control (issue/retire/transfer/setcode).

## Contract authorization audit (decompiled WASM, pinned hashes)

### `whaleextrust` (sha256 `e1f01c19…ea8b`, code_hash from chain identical, 3,386 bytes)
- ABI: no actions declared; single table `extsymbolref`.
- `apply` dispatch (decoded names): only action **`clearextsym` (0x44546babb9c7a400)**; everything else asserts code 8000000000000000000; `eosio::onerror` rejected (assert 8000000000000000001).
- `clearextsym(account)` → func 31: first instructions `local.get 0; i64.load; call 4` = **`require_auth(account)`**, then deletes that account's `extsymbolref` rows. **No token movement, no inline actions.**

### `tokens.wal` / `whaleextoken` (standard eosio.token fork + blacklist/recreate/retire; sha256 `a8667849…e5a4`)
- `transfer(from,to,quantity,memo)`: first statement **`require_auth(from)`** (dcmp: `env_require_auth(b);` inside `ZN5eosio5token8transfer…`).
- `issue`: `require_auth(stat.issuer)`; `retire`: `require_auth(stat.issuer)` (retire can burn from any account, issuer-only); `recreate`: `require_auth(existing stat issuer)`; `close`: `require_auth(owner)`; `addblacklist`/`rmblacklist`: `require_auth(issuer)`.
- Stat: USDT supply 2,537,116.65971396, issuer `tokens.wal`; BTC supply 14.94248742, issuer `tokens.wal`. (USDT supply > whaleextrust's balance → other holders exist.)

### Gateways (checked for permissionless value movers)
- `whaleexgate5` (deposit/withdraw processor, 136,048 bytes): systematic sweep of all 23 action-handler functions in its dispatch table — 20/23 carry `require_auth` (the other three are trivial helpers: 50-byte no-op, memset-like, and an internal multi-purpose routine; none is an action that moves value). Value-moving handlers (`retire`, `fillwithdraw`, `redowithdraw`, `replwithdraw`, …) begin with `require_auth` of the account field in the action data (e.g., `retire` handler WAT func 150: `i64.load offset=112; call 44 (require_auth)` before building the inline `retire`); admin bypasses use `has_auth("miner1.wal")` / `has_auth("whaleexgate2")` — exchange admin accounts, not attacker-reachable. Gate5 holds 0.0016 EOS + 61.30 USDT and **cannot move `whaleextrust` funds (no authority over it)**.
- `whaleexgate4` (255 KB deposit gateway) and `whaleexdebit` (loan book) hold no meaningful value; neither is granted authority on `whaleextrust`.
- `whaleextrust` grants no `eosio.code` to any contract on its `active`/`owner`; its only delegation is `staking` → `eosdefiproxy@eosio.code` (staking-scoped custom permission; cannot satisfy `require_auth(whaleextrust)` for `eosio.token::transfer`, which requires active/owner).
- `eosdefiproxy` (CPU/REX proxy) audit note: its `pretransfer`/`claim`/`sellrex` paths use `has_auth("whaleexadmin")` / `has_auth("whaleexgate2")` admin bypasses and otherwise `require_auth` of the user; it only moves **staking/REX resources**, and `whaleextrust` has **0 staked EOS / 0 REX** (`rex_balance=0.0000 REX`, `staked=0`), so it cannot move the token balances. **Full-history scan (all 10,000 cached Hyperion actions for `whaleextrust`): zero `linkauth` actions ever** — so no permission link exists that would let `eosdefiproxy` (or anyone) use the `staking` permission to satisfy `require_auth(whaleextrust)` on `tokens.wal::transfer`. History also shows `updateauth` on 2023-11-29 (owner → `PUB_K1_82gaF2r4…`) and 2025-02-16 (owner+active → current `PUB_K1_58SzHx…`), i.e. an operator key rotation in Feb 2025; the current single key has controlled the account since then.

## Verdict

- **E-U = $0.00** (high confidence). No external unprivileged path moves any `whaleextrust` value: the trust contract has a single non-value action (`clearextsym`, self-auth only); the token contracts require `from`'s active/owner authority for `transfer`; the issuer-only `retire`/`issue` require `tokens.wal`'s authority (single key + WhaleEx gate contracts). No on-chain collateral to redeem against the IOUs.
- **P = $3,652,071.86 face** — movable/burnable only by (a) `whaleextrust`'s single owner/active key, and (b) `tokens.wal`'s owner key `EOS5GF3Uzz…` (shared across the whole infrastructure) / its `eosio.code` delegates. **Key-compromise exposure**, not an E-U path.
- **H-O = $0** — the trust contract exposes no user self-service withdrawal; depositors' claims are off-chain against the (dormant) exchange.
- **S = $0** — nothing bricked; value is key-controlled.

## Residual risk / caveats

- The $3.65M is **face value of unbacked exchange IOUs**; realizable value depends on the defunct exchange honoring withdrawals (no on-chain claim). Treat as a key-compromise exposure of uncertain recoverable value.
- `tokens.wal` USDT/BTC could be **burned** (issuer `retire`) or minted by the owner-key holder — an integrity risk for any downstream holder, but not attacker-extractable.
- EOSIO has no public dry-run; gates proven statically + by protocol `require_auth` semantics.

## Evidence files (analysis/whaleex/)

`whaleextrust.{wasm,wat}`, `whaleextrust_raw.json`, `tokens.wal.{wasm,wat,dcmp}`, `whaleextoken.{wasm,wat}`, `whaleexgate4/5`, `whaleexdebit`, `eosdefiproxy` binaries + raw code/ABI; `whaleextrust_tokens.json` (48-token dump). CI: `ci/verify_eos.py`, `ci-out/eos-misc-verify.json`.
