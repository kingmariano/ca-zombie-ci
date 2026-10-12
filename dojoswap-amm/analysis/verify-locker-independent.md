# Independent verification report — “Kira Liquidity Locker Test” (Injective code 1178) unstake claim

**Verifier:** independent subagent (fresh reads only; no reliance on the original finding’s computations)
**Date:** 2026-10-11/12 (UTC). All chain reads via keyless public endpoints only:
`https://injective-api.polkachu.com`, `https://injective-rest.publicnode.com`, `https://coins.llama.fi`.
**Target contract:** `inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq` (code_id 1178, label “Kira Liquidity Locker Test”, admin empty)

**Claim under test:** the locker’s `Unstake { denom: <lock_id> }` path transfers expired locked LP tokens to
`info.sender` with **no owner check** (only `enabled` and expiry are checked), so any unprivileged caller can drain
all 11 locks; the locker holds 174,717,569,558,057,606 LP of the POOR/INJ pair ≈ 99% of the pool ≈ 686 INJ (~$5.3K).

---

## 0. Verdict (summary)

| Sub-claim | Verdict | Evidence |
|---|---|---|
| code_id 1178, admin empty (immutable), label “Kira Liquidity Locker Test” | ✅ verified | contract info (both nodes) |
| Deployed wasm == on-chain record (data_hash) | ✅ verified | sha256 of downloaded code = `489efa1f…f7df6` = `code_info.data_hash` |
| Public repo source matches deployed binary | ❌ **no** — deployed binary is a *different, unpublished revision* | see §3 |
| Public repo HEAD source has no owner check in `execute_unstake` | ✅ verified (but not authoritative for deployed code) | see §3 |
| Live state: stored `enabled == true` (raw storage, not the hardcoded smart-query) | ✅ verified | raw `config` key |
| 11 locks exist; all expired; LP locks sum == locker CW20 balance | ✅ verified | smart queries + raw storage + CW20 balance |
| Locker LP share ≈ 99.0%; INJ value ≈ 686.2 INJ ≈ $5.3K | ✅ verified with fresh prices | §5 |
| Deployed bytecode behavior (execution of the actual wasm) | ✅ **verified — non-owner unstake REJECTED (`Invalid Owner`); lock owner unstake succeeds** | §7 |

**Bottom line (final):** the published source has no owner check, but the **deployed** artifact (sha256
`489efa1f…f7df6`) is a different, hardened revision that **does** gate `unstake` by the lock owner. A fresh,
unprivileged caller cannot claim any of the 11 locks. The claim is **REFUTED for the deployed contract**;
an attacker extracts **$0** from this locker; the locked LP (≈$5.3K at read time) remains claimable only by its
recorded owners.

---

## 1. Identity / on-chain record (fresh reads)

```
GET https://injective-api.polkachu.com/cosmwasm/wasm/v1/contract/inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq
-> {"address":"inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq",
    "contract_info":{"code_id":"1178",
                     "creator":"inj1nmg9qcz39vvxv99ypxcrv68ev9ahzwclgcmh7z",
                     "admin":"",
                     "label":"Kira Liquidity Locker Test",
                     "created":{"block_height":"90278818","tx_index":"0"}}}
```

```
GET https://injective-api.polkachu.com/cosmwasm/wasm/v1/code/1178   (code_info)
-> {"code_id":"1178","creator":"inj10d07y265gmmuvt4z0w9aw880jnsr700jstypyt",
    "data_hash":"489EFA1FC9CB0BDDFFB1A7A387BEAB7A3112CD7A01A12A894B99F636CC4F7DF6",
    "instantiate_permission":{"permission":"AnyOfAddresses","addresses":["inj1nmg9qcz39vvxv99ypxcrv68ev9ahzwclgcmh7z"]}}
```

- `admin` empty ⇒ no migration path; the deployed logic is final.
- `instantiate_permission` restricted to one address (irrelevant to `ExecuteMsg::Unstake`).

**Block heights at read time (UTC):** polkachu 186,888,846 @ 2026-10-11T22:40:07Z; publicnode 186,888,847 @ 22:40:07Z;
refreshed later: 186,891,347 @ 23:04:59Z; 186,892,229 @ 23:13:45Z; publicnode 186,892,462 @ 23:16:04Z.

---

## 2. Deployed artifact verification (byte-level)

```
GET /cosmwasm/wasm/v1/code/1178  ->  .data (base64)  ->  code1178.wasm (202,211 bytes)
sha256(code1178.wasm) = 489efa1fc9cb0bdfffb1a7a387beab7a3112cd7a01a12a894b99f636cc4f7df6
code_info.data_hash   = 489EFA1FC9CB0BDDFFB1A7A387BEAB7A3112CD7A01A12A894B99F636CC4F7DF6
```
✅ The bytes I analysed (strings, disassembly, VM run) are exactly the bytes recorded on chain.

- Exports (wasm-tools objdump): `instantiate`, `execute`, `query`, `allocate`, `deallocate`,
  `requires_staking`, `requires_iterator`, `interface_version_8` (CosmWasm 1.x interface).
- Built with `cosmwasm-std-1.4.1`, `cw-storage-plus-0.16.0` (paths embedded in the binary).
- App-specific strings embedded in the binary include:
  `config`, `lp_map`, `src/contract.rs`, `lock_liquidity_pool`, `lp_owner`, `lp_denom`, `lp_amount`, `locktime`,
  `execute_unstake`, `lp_id`, `check_owner`, `update_config`, `update_fee_address`, `receive`, `extend`, `unstake`,
  `extend_by`, `lock`, `fee_address`, `fees_percentage`, `enabled`, `get_config`, `get_liquidities`, `get_liquidity`,
  error strings `Unauthorized`, `Invalid Owner`, `Invalid ID`, `Locktime. Send Unstake Fee`, `Disabled`,
  `Fee Payment Failed`, `Payment Failed`, `LP Not found`, `Already Locked`, `Locked Period Wrong`,
  `InvalidCw20Token`, `InvalidCw721Token`, `Insufficient`, `ArithmeticErr`, plus `sha2-0.10.8` sources.

- `execute` = function #98 in the generated WAT (everything inlined); a small deserializer (#92) matches the
  message variant names `unstake` / `extend` / `update_fee_address`. The `check_owner` attribute string is referenced
  only once in the execute function (line 30194 of the WAT), in the update-config region — **not** in the region
  around the `execute_unstake` attributes (lines ~32763–32904). Static call-tracing showed config loads (`call 53`)
  and a token-transfer builder (`call 94`) around the receive/lock-extend region and later. Because block reordering
  in optimised wasm makes hand data-flow analysis error-prone, the decisive test is the local VM execution in §7.

---

## 3. Source review — and a critical discrepancy

Public source: `https://github.com/Marinovs/liquidity-locker` (codeload tarball; commit history via GitHub API).
All 5 commits:

```
57480665241dbd3d63b47cf2040c81c39aa9666a 2024-02-07 changed lp map; now every lp has his own id   (HEAD)
e62b2a44d383b0d2f8b6971d0e793e55d460362d 2024-02-01 added more locking period option
90556379b5f112c33d7d58785b05d7f14c58d098 2024-01-29 hotfix on lock liquidity amount
3023e05a3eed0502ff1d6a086b776202dcf7ba4c 2024-01-13 Create README.md
61a0a800977dc1291c8408c5cebd11a0cf9990ef 2024-01-13 push
```

`src/contract.rs` at HEAD, `execute_unstake` (lines 177–214): loads the LP entry by id, loads CONFIG,
errors if `!enabled`, errors if `current_time < lp.locktime`, then builds
`transfer_token_message(lp.denom, "cw20", lp.amount, info.sender.clone())` and removes the entry.
**There is no comparison of `info.sender` against `lp.owner` or the config owner** — the locked tokens go to
whoever calls. (`check_owner` exists but is used only by `execute_update_config`; `InvalidOwner` is used only in the
“extend existing lock” receive path.) So for the **public HEAD source**, the claim’s mechanism is exactly right.
Also note: `query_config` (lines 225–232) **hardcodes** `enabled: true` and `fees_percentage: 1` in its response —
the smart query `get_config` can therefore never show `enabled=false`; only raw storage is authoritative (checked in §4).

**Discrepancy (important):** I checked every public commit (msg.rs/contract.rs/state.rs/util.rs/error.rs and
Cargo files). None of them contain the strings `extend`, `extend_by`, `update_fee_address`, `Insufficient`,
`ArithmeticErr`, nor the `sha2` dependency — yet all of these are present in the deployed binary. The deployed
lock ids are 64-hex strings (consistent with `sha2` use), whereas HEAD generates ids as
`"{owner}-{denom}-{time:x}"`. Public GitHub code search for `"Locktime. Send Unstake Fee"` matches only this repo;
no public repo contains the deployed revision. Conclusion: **the deployed contract was built from an unpublished
revision of this codebase; the public repo source cannot by itself prove or disprove the deployed behaviour.**
(The parent session’s PoC in `poc/locker-poc` compiles the vendored HEAD source under `cw-multi-test`; that is a
source-level PoC, not a test of the deployed binary — this report treats it accordingly.)

---

## 4. Live state snapshot

Raw storage (authoritative; plain key `config`, `Map` entries keyed `\x00\x06lp_map + <id>`):

```json
// key "config"
{"owner":"inj1nmg9qcz39vvxv99ypxcrv68ev9ahzwclgcmh7z",
 "creator":"inj1nmg9qcz39vvxv99ypxcrv68ev9ahzwclgcmh7z",
 "fees_percentage":1,
 "fee_address":"inj1nmg9qcz39vvxv99ypxcrv68ev9ahzwclgcmh7z",
 "enabled":true}
```
✅ Stored `enabled == true` (cross-checked on both nodes). The smart-query `enabled:true` is hardcoded in the code
(§3) and is not evidence by itself.

All 11 `LP_MAP` entries (`get_liquidities` smart query, cross-checked against raw storage for each key):

| # | id (short) | owner | denom (token) | locktime (UTC) | expired | amount |
|---|---|---|---|---|---|---|
| 1 | `1810816b…aab1` | inj1agh8nnckx… | inj1nssppa3… (KIRA/INJ LP) | 2025-04-14 19:24:16 | 545 d | 9,900,000,000,000 |
| 2 | `2852677a…3d3b` | inj18xsczx27… | inj1nj2gnkk… (POOR/INJ LP) | 2024-11-17 15:39:25 | 693 d | 990,000,000,977,606 |
| 3 | `3717c066…5de7` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:43:51 | 693 d | 990,000,000,000,000 |
| 4 | `43847a55…7d92` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:41:40 | 693 d | 1,980,000,000,000,000 |
| 5 | `44c78926…ff0d` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:38:00 | 693 d | 19,800,000,000,000,000 |
| 6 | `84c02bc8…7f1f` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:40:04 | 693 d | 9,900,000,000,000,000 |
| 7 | `85d46a08…6bdb7` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:36:54 | 693 d | 49,500,000,000,000,000 |
| 8 | `9f097176…3a60` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:38:33 | 693 d | 8,910,000,000,000,000 |
| 9 | `c3bc7ca5…27ec` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:41:08 | 693 d | 4,950,000,000,000,000 |
| 10 | `df1109db…7b61` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:36:03 | 693 d | 76,707,569,557,080,000 |
| 11 | `f1625bb6…2715` | inj18xsczx27… | POOR/INJ LP | 2024-11-17 15:42:10 | 693 d | 990,000,000,000,000 |

- All locktimes are far below chain time (2026-10-11T22:40Z … 23:16Z): every lock is expired.
- **Sum of the 10 POOR/INJ LP locks = 174,717,569,558,057,606.** Locker CW20 balance of the LP token
  (`inj1nj2gnkkphk370n2086n27m6ryj5sjlsuxthla8`, query `{"balance":{"address":"inj1kmu…"}}`) =
  **174,717,569,558,057,606** on both nodes — **exact match** ⇒ nothing has been unstaked/claimed.
- The 11th lock is a **different** dojoswap LP token (`inj1nssppa309t2pty5agwrmrjqx9md9764ntesce6`, KIRA/INJ pair);
  the locker’s balance of it (9,900,000,000,000) also equals its lock amount exactly. (Minor claim imprecision: only
  10 of the 11 locks are POOR/INJ LP.)

Token/pair identity:
```
LP token inj1nj2gnkk…: {"name":"dojoswap liquidity token","symbol":"uLP","decimals":6,
                        "total_supply":"176482597834073977"}; minter = inj1859sjey6v43cz40rtj8scka5xng2vn5c37j6f5
LP token contract info: code_id 292, admin "", label "lp"
Pair inj1859sjey6…: code_id 290, admin inj1pc2vxcm…, label "pair";
  {"pair":{... "asset_infos":[{"native_token":{"denom":"inj"}},{"native_token":{"denom":"factory/inj18xsczx27lanjt40y9v79q0v57d76j2s8ctj85x/POOR"}}],
           "liquidity_token":"inj1nj2gnkkphk370n2086n27m6ryj5sjlsuxthla8", "asset_decimals":[18,6]}}
  {"pool":{"assets":[inj 693163562115585105066, POOR 45345856250708], "total_share":"176482597834073977"}}
```
⇒ LP minter == pair (LP cannot be faked); pair’s `liquidity_token` == LP token.

---

## 5. Value math (fresh)

- Locker share = 174,717,569,558,057,606 / 176,482,597,834,073,977 = **0.9899988537245138 (98.999885%)**
  (unaccounted 1.000115% of supply).
- Floor pro-rata withdrawal from the pool:
  - INJ: `693163562115585105066 * bal // supply` = **686.231131938030100801 INJ**
  - POOR: `45345856250708 * bal // supply` = **44,892,345.709357 POOR**
- INJ price `https://coins.llama.fi/prices/current/injective:inj` = **$7.746812213929037** (ts 1791758387)
  ⇒ **≈ $5,316.10** for the INJ leg (+ POOR, not priced here). Claim said ~686 INJ / ~$5.3K @ $7.72 → matches.
- 11th (KIRA/INJ) lock adds ≈ 17,440.05 KIRA + 0.007560 INJ (the locker holds 2 `inj` native besides).

---

## 6. Falsification attempts (checklist)

**(a) Other contracts/guards blocking a caller?** None found. The locker contract itself is the only gate for the
transfer; its `admin` is empty (no migration), it has no other execution entry that would need to run first, and no
global wasm pause module exists on Injective. The only subsequent step needed to realise value is the LP-token
withdrawal from the pair, which is permissionless for LP holders (§6e).

**(b) `enabled == false`?** No — raw storage says `true` (§4). (And even the deployed source’s smart query would
always claim `true`, which is why the raw read matters.)

**(c) Locks already claimed?** No — for both LP tokens the locker’s balance equals the exact sum of the locks, and
all 11 entries are still present in `LP_MAP`.

**(d) Correct LP token (not a fake)?** Yes — LP token code 292, admin empty; its `minter` is the pair
`inj1859sjey6v43cz40rtj8scka5xng2vn5c37j6f5`, and the pair’s `liquidity_token` points back to it. The raw LP_MAP
entries’ `denom` fields match this token.

**(e) Is the pair a standard terraswap-style pair whose LP holders can withdraw?** Yes, to the extent verifiable:
- Public source `dojo-trading/dojoswap-contracts-public`, `contracts/dojoswap_pair/src/contract.rs`:
  `receive_cw20` for `Cw20HookMsg::WithdrawLiquidity` requires `info.sender == config.liquidity_token`
  (`Unauthorized` otherwise), then `withdraw_liquidity` refunds pro-rata (`amount * share_ratio`) to the hook
  `sender` (the original LP holder) and burns the LP amount; LP token is a thin cw20-base wrapper
  (`contracts/dojoswap_token` imports `cw20_base::contract::execute`) whose `Send` invokes the hook normally.
- On chain: pair code 290’s wasm contains `withdraw_liquidity`, `Unauthorized`, `liquidity_token`,
  `asset_infos`, `provide_liquidity`, `swap`; LP token code 292 contains the standard cw20 message set
  (`transfer`, `send`, `burn`, `mint`…).
- ⚠️ Not verified: byte-exact build reproduction of pair code 290 from the public repo (no docker/build of
  `dojoswap_pair` was performed here), so the source review is the mapping, not a hash match.

---

## 7. Behavioural verification of the deployed binary (local CosmWasm VM)

### 7.1 Deployed wasm executed against the **real on-chain storage snapshot** (this verifier)

**Method.** The storage snapshot was copied **raw from chain** — the `config` key plus all 11 `lp_map` entries
(`locker-storage-hex.json`; `Map` keys = `u16be(len("lp_map"))‖"lp_map"‖id`) — so execution used the **actual live
locks**, not synthetic state. Env time = chain time (2026-10-11T22:40:07Z), contract addr = the locker, funds = `[]`,
sender = a fresh unprivileged Injective address (`inj1r3xsl82…`, generated for this test). LP-token smart queries
(`balance`/`token_info`/`minter`) were mocked with the real on-chain values.
Full log: `.verify-scratch/vmharness/vm-results.log`.

| # | scenario | sender | env time | lock | Raw contract result |
|---|---|---|---|---|---|
| 1 | expired, unprivileged | `inj1r3xsl82rluavmfy5usexy8s203f3etesap0qqy` (fresh) | 2026-10-11 | real lock `df1109…7b61` (expired) | `{"error":"Invalid Owner"}` |
| 2 | expired, contract owner/creator | `inj1nmg9qcz…` | 2026-10-11 | `df1109…7b61` | `{"error":"Invalid Owner"}` |
| 3 | expired, lock owner | `inj18xsczx27…` (recorded owner) | 2026-10-11 | `df1109…7b61` | **OK** — 1 msg: LP-token `transfer` of `76707569557080000` to `inj18xsczx27…`; attrs `execute_unstake`, `lp_id`, `amount` |
| 4 | bogus lock id | fresh | 2026-10-11 | `deadbeef` | `{"error":"LP Not found"}` |
| 5 | before locktime, lock owner | `inj18xsczx27…` | 2025-01-01 | `df1109…7b61` | `{"error":"Locktime. Send Unstake Fee"}` |
| 6 | before locktime, unprivileged | fresh | 2025-01-01 | `df1109…7b61` | `{"error":"Locktime. Send Unstake Fee"}` (locktime check precedes the owner check) |
| 7 | stored config disabled, lock owner | `inj18xsczx27…` | 2026-10-11 | `df1109…7b61` | `{"error":"Disabled"}` |
| 8 | expired, unprivileged | fresh | 2026-10-11 | real KIRA/INJ lock `1810816b…aab1` | `{"error":"Invalid Owner"}` |
| 9 | expired, lock owner | `inj1agh8nnckx…` (recorded owner) | 2026-10-11 | `1810816b…aab1` | **OK** — 1 msg: LP-token `transfer` of `9900000000000` to `inj1agh8nnckx…` |

Decoded example (scenario 3): the only returned message is
`{"wasm":{"execute":{"contract_addr":"inj1nj2gnkkphk370n2086n27m6ryj5sjlsuxthla8","msg":"<base64 {\"transfer\":{\"recipient\":\"inj18xsczx27lanjt40y9v79q0v57d76j2s8ctj85x\",\"amount\":\"76707569557080000\"}}>","funds":[]}}}`
— the LP goes **to the recorded owner**, not to the caller.

### 7.2 Second harness (`poc/wasm-harness`, parent-built), synthetic instantiate→lock→unstake state

**Result output (raw).** Completed on 2026-10-12 with an equivalent behavioural harness
(`poc/wasm-harness`, run by the parent agent; same deployed wasm, sha256 `489efa1f…f7df6`, executed inside
`cosmwasm-vm 1.5.11` with a clean instantiate → lock → unstake flow):

```
wasm loaded + validated by cosmwasm-vm; capabilities: {"staking", "iterator"}
instantiate OK: attrs=[]
lock OK with locktime=2592000: attrs=[action=lock_liquidity_pool, lp_owner=lp_owner_111…, lp_amount=100000]
locks: [{"amount":"99000","denom":"lp_token_contract","id":"c0741e87…fa047",
         "locktime":1574389419,"owner":"lp_owner_111…"}]
*** UNSTAKE BY NON-OWNER (expired lock) REJECTED BY CONTRACT: Invalid Owner
positive control: lock owner unstake SUCCEEDED: attrs=[action=execute_unstake, lp_id=c0741e87…fa047, amount=99000]
   msg: {"wasm":{"execute":{"contract_addr":"lp_token_contract",
         "msg":"<base64 Cw20ExecuteMsg::Transfer{recipient: lp_owner, amount: 99000}>","funds":[]}}}
```

**Interpretation.** Both independent VM runs agree. The **deployed** code 1178 is *not* the published Marinovs
source: it is a hardened revision that (a) checks the CW20 balance during lock, (b) adds an `extend` message, and
(c) **gates `unstake` by the lock owner** — a non-owner caller on an expired lock gets `Invalid Owner`, while the
true lock owner unstakes successfully and receives the LP. The published-source vulnerability therefore **does not
exist in the deployed contract**. The 11 live locks (tested directly in §7.1) are recoverable only by their recorded
owners; an arbitrary attacker extracts $0.

---

## 8. What could not be verified / contradictions / uncertainties

1. **Deployed source is unpublished** — the deployed binary is *not* built from any public commit of
   `Marinovs/liquidity-locker` (extra message variants `extend`/`update_fee_address`, `sha2` use, extra error
   variants). Public-source review is therefore only indicative; the deployed wasm is the ground truth and was
   exercised directly (§7). The original finding’s step “read src/contract.rs” is correct for HEAD but does not
   prove the deployed build.
2. **Smart-query trap:** `get_config` hardcodes `enabled: true`/`fees_percentage: 1`; anyone relying on the smart
   query alone for the enabled state could be misled. Raw storage was used instead.
3. **Historical tx enumeration inconclusive:** the public nodes accept `message.action`/`tx.height` queries but
   return 0 for `wasm._contract_address=…`, so I could not list past `unstake` calls. This does not affect the
   conclusion because the current on-chain balances prove none of the current locks has been claimed.
4. **Pair build not hash-matched** (see §6e). The withdrawal path was validated by public source + on-chain
   minter/pair consistency, not by rebuilding code 290.
5. **VM vs chain nuance:** the local VM run proves what the contract returns for the transaction; on-chain execution
   additionally requires the tx to be accepted by the chain (standard execute message, no special permissions) and
   the transfer to succeed (locker holds the tokens — verified).
6. Minor claim imprecision: the 11th lock is a KIRA/INJ LP token, not POOR/INJ; it is still expired and belongs
   to its owner (recoverable only by that owner, per §7).

---

## 9. Explicit statement

**The claim is REFUTED for the deployed contract.** Executing the exact deployed bytecode (sha256
`489efa1f…f7df6`, verified against the chain's `data_hash`) shows that `Unstake` on an expired lock by a
non-owner caller reverts with `Invalid Owner`, while the true lock owner's `Unstake` succeeds and receives the
locked LP. The published Marinovs source lacks that check, but the deployed revision adds it (along with a
CW20-balance check at lock time and an `extend` message). Therefore **no unprivileged, non-owner caller can receive
the LP today**; an attacker extracts **$0** from this locker; the locked LP remains recoverable only by its
recorded owners.

---

## Appendix A — exact commands / URLs used (all public, keyless)

```bash
# contract & code
curl -s https://injective-api.polkachu.com/cosmwasm/wasm/v1/contract/inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq
curl -s https://injective-api.polkachu.com/cosmwasm/wasm/v1/code/1178 -o code1178.json
jq -r .data code1178.json | base64 -d > code1178.wasm && sha256sum code1178.wasm
# last block (heights recorded): /cosmos/base/tendermint/v1beta1/blocks/latest
# smart queries (base64 of {"get_config":{}} / {"get_liquidities":{}} …):
curl -s "…/cosmwasm/wasm/v1/contract/<addr>/smart/<b64>"
# raw storage (Map keys = u16be(len("lp_map")) ‖ "lp_map" ‖ id):
curl -s "…/cosmwasm/wasm/v1/contract/<addr>/raw/<urlencoded-b64>"
# LP token: {"balance":{"address":…}}, {"token_info":{}}, {"minter":{}}
# pair: {"pair":{}}, {"pool":{}}
# price: curl -s https://coins.llama.fi/prices/current/injective:inj
# source: codeload.github.com/Marinovs/liquidity-locker/tar.gz/refs/heads/main (+ api.github.com commits)
# wasm tooling: wasm-tools 1.261.0 (bytecodealliance prebuilt release)
# deployed-wasm execution: local cosmwasm-vm 1.5.11 harness (.verify-scratch/vmharness, offline, no chain writes;
#  ran the deployed wasm against the real raw storage snapshot, log in vmharness/vm-results.log)
```

Raw artifacts kept in `dojoswap-amm/.verify-scratch/` (`code1178.wasm`, `code1178.wat`, `locker-storage*.json`,
`raw-config.bin`, `raw-lpmap-*.bin`, harness project).
