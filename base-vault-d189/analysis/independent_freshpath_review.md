# C2-02 independent fresh-path review (zombie-hunt II)

Target: Base credit vault `0xD1895f2019c2152FC2b9022D57f19198c4CFCABC` (TransparentUpgradeableProxy, impl `0x209d85f0ed5393f8f772d46bf889c251132a68bb`) and sibling `0x416Ec2cA21a38CbCFeAcD6a14532B3F348356d23` (impl `0x67ed441b2444e055376F4acaBddA969F8926e4EA`).
Method: read-only. All functions enumerated from bytecode with `evmole` + `heimdall`, then every nonpayable entry point was `eth_call`-tested from a fresh address (`0x2222…2222`) at latest Base block; whitelist reconstructed from on-chain getters + full Blockscout tx history + `debug_traceTransaction`/execTransaction payload decoding; all state reads cross-checked on 3 independent RPCs. No transactions signed/sent.

## Verdict

**Fresh unprivileged extractable path: NONE FOUND (vault and sibling). Confidence: high (0.9).**
Only privileged paths remain: owner-Safe exemption (3-of-7 Safe can `borrow` without being whitelisted) and the original attacker's still-whitelisted, owner-gated helper. Any attacker-controlled (non-fresh) residual is bounded by Aave HF (~8,300 aWETH per prior measurement).

## (b) Function tests from a fresh address

Vault impl (via proxy) — 24 selectors, all nonpayable tested:

| fn | result from fresh |
|---|---|
| borrow 0xa415bcad, withdraw 0x69328dec, repay 0x573ade81 | revert `!W` (whitelist gate on msg.sender; receiver irrelevant) |
| supply 0x617ba037 | reverts SafeERC20 (pulls caller's own tokens; never pays out) |
| `__setWhitelist__` 0x38edc837, 4abb8b6f, 6b711cc9, 76309d0e, 698442db, d2b2de5b, renounceOwnership, transferOwnership | revert `Ownable: caller is not the owner` |
| initialize 0xc4d66de8 | reverts "already initialized" |
| pool/minToken/aToken/debtToken/getUserReserveData/getReserveConfigurationData/minHealth/whitelist/supplyAmount/borrowAmount/owner | view, return data only |
| empty calldata | returns 0x (no-op, no receive/fallback value path) |
| proxy admin()/implementation()/upgradeTo/changeAdmin | revert for non-admin (transparent-proxy check) |

Helper impl `0xcdFE…` (proxy `0xcdfe9130…`), 8 selectors: `4cf8513b`=vault() view; `__withdraw` 0x9a39f8dd, `cb984317`, `__redeem` 0xdebd4ffc, renounce/transferOwnership → **all revert `!O2` from fresh**; `initialize` → already initialized; `owner()` = attacker EOA. (Prior PoC had not tested `cb984317`/`__redeem`; both are owner-gated.)

Sibling impl — 27 selectors: borrow/withdraw/repay → `!W`; all extra fns (`_claimReward` 0xa11c7f55, 47646117, 66905f39, 95d45261, adf9e92b, setters) → `Ownable`; supply → revert; proxy initialize → revert. **Direct call to the sibling implementation `initialize(address,address)` succeeds (impl storage is uninitialized), but impl storage is isolated from the proxy and holds no funds — not exploitable, hygiene note only.**

Whitelisted account contracts (31 on vault, 92 on sibling; 12 distinct impls: 5e50, 331e, 355d, 6fd5, 5556, f972, be56, d600, 8f3e, d8d3, a1f5, c9a1, dc96, cc31, e37a): every nonpayable function of every impl was probed from fresh. All revert `Ownable`/`!G` (custom guard) except `255617e7()` which executes but only performs a STATICCALL to `0xc6a2db66` (read-only, no state/fund movement). `3e2a111d`/`47e45bf7` revert instantly with no subcalls even from the account owner with dummy args (parameter-validated). No account function lets an unprivileged caller make the account call `vault.borrow`/`withdraw` or move its assets.

## (c) Whitelist enumeration

Vault current whitelist = **33 addresses** (vs 2 previously known): 1 EOA `0x3e68796a…`, attacker helper `0xcdfe9130…`, and 31 contracts of the protocol account family. Full setter history: 14 direct calls by owner#1 `0x4ff634ef…` (13 grants + 1 revoke) and 24 owner-Safe exec calls (23 grants + helper 0→1 at blocks 52,157,298/52,157,342). The 2 Safe txs whose traces timed out were decoded from execTransaction payloads: a sibling `minToken` set and a sibling `borrow` — no missing whitelist writes. Revoked and now false: `0xd84636a8…`, `0x8b060ca3…`. Current vault whitelist addresses (all `whitelist()==1`, triple-RPC verified):
`0x3e68796a…` (EOA), `0xda9884fd`, `0xc23cffaa`, `0x0d0e3190`, `0xe83cd757`, `0x891694e3`, `0xdf8be1e6`, `0x92aafa6b`, `0x30b685d8`, `0x3683a176`, `0x59193d6b`, `0x97db2260`, `0xcdfe9130` (helper), `0xffe4d54c`, `0x9ce3cac9`, `0x158c7575`, `0x34a05bb8`, `0xd4714c07`, `0xcfa6b29a`, `0x09a7c55b`, `0x41616242`, `0x6bc6c940`, `0x8bcdb937`, `0xf5773fb7`, `0xf8478d00`, `0x122e7bec`, `0x6ebb1dae`, `0xea49bec3`, `0x2afbb576`, `0x4d192577`, `0xe2e6bcd5`, `0x31fdc043`, `0xb4ec1fea`.
Only `0x3e68796a…` is an EOA (a user; its borrow capability is its own). All others are TransparentUpgradeableProxy accounts whose public entry points are owner/`!G`-gated; their owners are EOAs/Safes (`0xffb7192a…`, `0xc79b3e6d…` 3-of-N Safe, etc.), i.e. no third-party-triggerable account.

Sibling current whitelist = **92 contracts, 0 EOAs**, all the same account family (12 impls, all fresh-probed gated). Sibling setter history: 68 grants by owner#1 + 48 exec setter calls by the owner Safe, incl. revokes. `92aafa6b`/`30b685d8` are whitelisted on both vaults.

## (d) Bypass angles checked

- Owner exemption: `vault.borrow` from owner Safe `0x6b27512a…` returns OK while fresh → `!W`; same on sibling. **Privileged (3-of-7 Safe), not fresh.** `withdraw` from the Safe still reverts `!WWE`; `__setWhitelist__` from Safe works (owner).
- Safes: all three (vault owner, vault ProxyAdmin owner, account-family ProxyAdmin owner) are threshold 3, `getModules()` = empty, `getGuard()` reverts (no modules/guards). No module-triggered execution path.
- ProxyAdmins `0x490ca969…`/`0x0c1ddeb3…`: `upgrade`/`upgradeAndCall` from fresh revert (Ownable by Safes).
- Storage: impl writes only slots 0/0x33/0x65–0x6c; no collision with EIP-1967 impl/admin slots (`0x3608…`, `0xb531…` verified).
- Allowances/Aave: `aWETH`/`aBaswstETH` allowance from vault to helper/EOA/fresh = 0; variableDebtWETH `borrowAllowance(vault, X)` = 0 for helper/fresh/Safe/wl-EOA (no credit delegation).
- Borrow callback: trace of a whitelisted `borrow` shows vault → `aToken.transfer` only; aToken internals are `finalizeTransfer` + rewards-controller + oracle STATICCALLs. No callback to the receiver, no reentrancy hook.
- `initialize` on both proxies and both impls reverts (sibling impl excepted, harmless).

## (e) Confidence & caveats

Confidence 0.9 that no fresh unprivileged path exists. Residual uncertainty: (i) two Safe txs required payload decoding instead of tracing (both resolved, not whitelist writes); (ii) Blockscout internal-tx indexing is incomplete, so enumeration relied on decoding all 258 owner-Safe execTransaction payloads plus all direct vault/sibling txs — complete for msg.sender=owner writes; (iii) a fresh caller could still *donate* collateral (`supply`) or *repay* the vault's debt, which only benefits the vault. The whitelist count is much larger than the 2 addresses previously known; every newly found whitelisted contract was individually classified and probed.

Evidence files: `analysis/matrix_results.json`, `matrix_out.txt`, `vault_call_traces.json`, `safe_owner_txs.json`, `sibling_txs.json`, `sibling_setters.json`, `sibling_wl_current.json`, `sibling_wl_class.json`, `sibling_newimpl_reps.json`, `whitelist_verified.json`, `code_*.hex`.
