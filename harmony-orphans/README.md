# H-39 / H-40 — Harmony orphan balances: "ONE for BSC/Ethereum" bridge escrows + four treasury Safes

**Campaign:** zombie-hunt (deep-dive) · **Chain:** Harmony (chainid 1666600000) · **Date of work:** 2026-10-04
**Status:** read-only research; all exploit/boundary tests run on a **local Harmony fork in CI only**. No mainnet
transactions signed or sent. All state cited at Harmony block **93,624,315**. Price: **ONE = $0.00245693**
(DefiLlama, 2026-10-04; explorer `coin_price` 0.00247058).

## 1. TL;DR

| # | Target (full address) | Live extractable by unprivileged attacker | Why closed / open | Latent risk |
|---|---|---|---|---|
| H-39a | `0x5B18a4E73F9A4fe337A072516b317863Ad3046aA` — "ONE for BSC" LayerZero v1 NativeOFT, 62,531,259.468552 ONE | **$0** | `withdraw` self-only; `lzReceive` endpoint + trusted-remote gated (remote cleared, receive version BLOCK_VERSION); `sendFrom` cannot debit the contract's own escrow (`ERC20: insufficient allowance`) and outbound is blocked; owner is a single EOA | Single-EOA owner `0xAC0248…` can unfreeze/re-target the bridge; owner-key compromise = full drain |
| H-39b | `0x905582f21fB9855c809d5b8933272a292dfbB138` — "ONE for Ethereum" NativeOFT, 13,101,396.431215 ONE | **$0** | identical contract/state (same code keccak, same owner, same freeze) | same |
| H-40 A–D | `0x85049A5abed20A50d587C113F1Ef03d0Fd796453`, `0x3Ef056E3220f270f4815219Dc1cF2A1854b96d80`, `0x399b8bB5d6677B557345D4D2c7a3B1986E448bAf`, `0x59f93F30fc4B1429E2016DB36346299d80927690` — four Gnosis Safe L2 v1.3.0 multisigs, 138,066,141.773437 ONE | **$0** | Canonical Safe proxy + canonical SafeL2 v1.3.0 singleton + canonical fallback handler; no modules, no guard; `execTransaction` strictly threshold-gated (`GS020/GS021/GS026`) | Owner-key compromise only; if owner sets are lost → stuck |

**Total live extractable by an external unprivileged attacker right now: $0 (high confidence).**

Category split (block 93,624,315):

| Category | Amount (ONE) | USD @ $0.00245693 | What it is |
|---|---|---|---|
| **E-U** (external unprivileged) | **0** | **$0.00** | no permissionless extraction path found on either target class |
| **H-O** (holder/user self-service) | 0 | $0.00 | H-39 `withdraw()` works (fork-proven) but **no external address holds any internal balance**; H-40 has no user-claim surface |
| **P** (privileged/owner-only) | 138,066,141.773437 | $339,218.85 | the four Safes (3-of-5 / 2-of-4 EOA owners). The H-39 escrow is also owner-unfreezable (see §5) |
| **S** (stuck/bricked today) | 75,632,655.899767 | $185,824.14 | H-39a+b escrows: bridge frozen both directions by the owner on 2026-08-30 |
| **Total in scope** | **213,698,797.673204** | **$525,042.99** | |

## 2. What the targets actually are (resolved abbreviations)

- **H-39** is not a generic "bridge custody" contract. It is a pair of **LayerZero v1 `NativeOFT` extension**
  contracts (LZ `solidity-examples` v1) deployed on Harmony by EOA `0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C`
  ("ONE for BSC" created 2022-10-17; "ONE for Ethereum" sibling). They wrap native ONE into an internal ERC-20
  balance, lock it when bridging out (`sendFrom` → `_transfer(_from, address(this))`), and pay native out when a
  LayerZero message arrives (`lzReceive` → `_creditTo` → `_burn(address(this))` + native `call`). Both unverified on
  the explorer; code decompiled with heimdall and matched to the open-source LZ v1 NativeOFT source. The remote
  counterparts are still wired on their side: BSC ProxyOFT `0x2332137a…` holds 211,111 BEP-20 ONE and its
  `trustedRemote(116)` points back at the Harmony OFT; Ethereum 1ONE `0xD5cd84D6…` supply is 26,018,624.868 ONE.
  Gen-1 sibling OFTs on Harmony (`0xa2ba7aa1…`, `0x8da02bed…`) hold 0 and 10 ONE (negligible).
- **H-40** `0x85049A5…`, `0x3Ef056E…`, `0x399b8bB…` were read from the top-balance page; `0x59f93F3…` was resolved by
  enumerating all 330 `ProxyCreation` events of the Safe proxy factory `0xc22834581ebc8527d974f8a1c97e1bea4ef910bc`
  → `0x59f93F30fc4B1429E2016DB36346299d80927690`. All four are canonical **Gnosis Safe L2 v1.3.0** proxies holding
  native ONE; histories show team/vesting-style native payouts to EOAs (A/C/D each seeded 84,000,000 ONE in Jan 2023).

## 3. Live-state assessment (block 93,624,315)

**H-39** (identical for both contracts unless noted):

| Check | Value |
|---|---|
| native balance | 62,531,259.468551870330371539 ONE (BSC) / 13,101,396.431214960428021286 ONE (ETH) |
| `totalSupply()` | equals native balance exactly (wei) |
| `balanceOf(contract itself)` | equals `totalSupply()` — i.e. **100% of internal supply is escrowed at the contract address** |
| `balanceOf()` of sampled historical users / attacker | 0 |
| `owner()` | `0xAC0248e9C78774bA0ef9E71B1Ce1393a10C17E3C` (EOA, code size 0, nonce 460) |
| `trustedRemoteLookup(101)` / `(102)` | `0x` / `0x` — cleared by owner 2026-08-30 (txs `0x4f91a924…`, `0x147e891b…`) |
| LZ endpoint `getSendVersion` / `getReceiveVersion` | 65535 / 65535 (**BLOCK_VERSION**) for both OFTs |
| LZ endpoint `hasStoredPayload(101/102, …)` | false — no pending message to replay |
| `useCustomAdapterParams()` | true |
| history | 924 inbound `ReceiveFromChain` events (blocks 72,424,639 → 92,723,721; last **2026-08-11 19:54 UTC**), matched 1:1 with `Transfer(OFT→0x0)` burns; freeze on **2026-08-30 10:01 UTC** |

**H-40** (see `analysis/h40-safes.md` for the full sub-report):

| Safe | Balance (ONE) | Threshold | Nonce | Modules | Guard | Fallback handler |
|---|---|---|---|---|---|---|
| A `0x85049A5a…` | 42,654,070.000000 | 3-of-5 | 13 | none | none | `0x017062a1…` (canonical) |
| B `0x3Ef056E3…` | 40,421,863.773437 | 2-of-4 | 249 | none | none | canonical |
| C `0x399b8bB5…` | 30,990,103.000000 | 3-of-5 | 11 | none | none | canonical |
| D `0x59f93F30…` | 24,000,105.000000 | 3-of-5 | 8 | none | none | canonical |

Code identity (exact): proxy keccak `0xb89c1b3b…` = factory `proxyRuntimeCode()`; singleton keccak `0x21842597…`
= Ethereum SafeL2 v1.3.0 `0x3E5c63644E…`; handler keccak `0x03e69f7c…` = canonical CompatibilityFallbackHandler v1.3.0.
Owners: 19 unique EOAs, no overlaps, none is the OFT owner.

## 4. Exact call paths an attacker cannot complete (fork-tested)

| Attempt (as arbitrary EOA) | Live result |
|---|---|
| `withdraw(1)` on the OFT | revert `NativeOFT: Insufficient balance.` |
| `lzReceive(102, src, nonce, payload)` | revert `LzApp: invalid endpoint caller` |
| `lzReceive(...)` **even pranked as the genuine LZ endpoint** | revert `LzApp: invalid source sending contract` (trusted remote empty) |
| `sendFrom(_from = OFT, …, 1 ether)` with value | revert `ERC20: insufficient allowance` (the OFT never approved anyone; its own escrow cannot be debited) |
| `setTrustedRemote(102, …)` / any owner setter | revert `Ownable: caller is not the owner` |
| Safe `execTransaction` with 0/1/3 dummy signatures | revert `GS020` / `GS021` / `GS026` |
| Safe module/guard paths | none exist (modules empty, guard zero) |
| `deposit()` → `withdraw()` roundtrip | works (proves escrow solvency and the H-O path; net-zero for the caller) |

Costs: every closed path reverts before any value moves; there is no capital, flash-loan or gas-spend that unlocks
one. No allowance from any victim to any exploiter was found (`Approval` events: none on the OFTs).

## 5. Verdict, residual & latent risk

- **E-U = $0, high confidence.** Both target classes are closed by construction: the NativeOFT's value-moving
  functions are self-only (`withdraw`), endpoint + trusted-remote gated (`lzReceive`), or allowance/escrow gated
  (`sendFrom`), with outbound additionally blocked by LZ `BLOCK_VERSION`; the Safes are canonical and threshold-gated.
- **H-O = $0 today.** The OFT `withdraw` holder path is real and fork-proven, but no external address holds internal
  balance. The economic claimants are wrapped-ONE holders on BSC/Ethereum; their inbound redemption was frozen on
  2026-08-30 (trusted remote cleared + receive version BLOCK_VERSION) → **S** until the owner reverses.
- **P = 138.07M ONE (Safes) + latent full-drain of the 75.63M ONE escrow** if the single EOA owner `0xAC0248…`
  is compromised (owner can re-enable the bridge, point the trusted remote at a contract it controls, credit an
  arbitrary internal balance via a real LZ message and `withdraw`). This is privileged, not E-U. Medium confidence
  that the mechanism remains live (endpoint/ULN still deployed and the bridge worked until 2026-08).
- **S = 75,632,655.899767 ONE ≈ $185,824** — frozen bridge escrow; only the owner can unfreeze.
- Blockers to any future extraction: single-EOA owner gate on H-39; threshold EOA keys on H-40; Harmony mainnet
  shutdown/migration context (2026) that motivated the freeze.

## 6. PoC / fork verification

- Project: `poc/` (Foundry, solc 0.8.24) · tests: `poc/test/HarmonyOrphans.t.sol` — **11 tests, 11/11 PASS**.
- CI (public repo `kingmariano/ca-zombie-ci`), fork of Harmony mainnet at block **93,624,315**:
  - **Final green runs: https://github.com/kingmariano/ca-zombie-ci/actions/runs/37188265963** (artifact
    `result-harmony-orphans`, ID 11298366376), https://github.com/kingmariano/ca-zombie-ci/actions/runs/37190077676
    and the full-docs sync run https://github.com/kingmariano/ca-zombie-ci/actions/runs/37190500939
    (all 11/11 PASS; the last one contains this README on the branch).
  - Earlier runs: 37184680782 (compile-only failure, invalid checksum literal — fixed), 37187906688 (10/11;
    test-side `OutOfFunds` bug — fixed).
- Key assertions: exact balances of all six targets; `totalSupply == native balance == balanceOf(self)` on both
  OFTs; empty trusted remotes; `withdraw`/`lzReceive`/`sendFrom`/owner-setter reverts with exact strings; Safe
  thresholds/nonces/modules/guard/fallback + canonical code hashes; `GS020` on unsigned `execTransaction`.
- Raw snapshot from the CI job: `ci-artifacts/result-harmony-orphans/ci-out/state.txt`; full log `ci-log.txt`.

## 7. Methodology & sources

- Blockscout Harmony API (`/api/v2/addresses`, `/logs`, `/transactions`, factory `ProxyCreation` enumeration);
  Harmony JSON-RPC `https://api.harmony.one` (`eth_call`, `eth_getCode`, `eth_getStorageAt`, `eth_getLogs`);
  Ethereum `https://ethereum-rpc.publicnode.com` for canonical Safe code hashes; DefiLlama for ONE/USD.
- H-39 bytecode decompiled with heimdall-rs v0.9.2 (`analysis/heimdall-oneforbsc/`) and matched to the LayerZero v1
  `NativeOFT` extension source (`contracts/token/oft/v1/NativeOFT.sol` in LZ `solidity-examples`).
- H-40 sub-report by a child subagent, independently spot-verified by the parent (`analysis/h40-safes.md`,
  `analysis/h40-state.json`).

**Caveats:** (1) "Stuck" for the H-39 escrow is a statement about *today's* frozen state — the owner can reverse it
and wrapped-ONE holders on BSC/Ethereum may then redeem (their claims are not quantified here). (2) Safe owner-key
liveness cannot be read on-chain; if keys are lost, the corresponding Safe is S rather than P. (3) Balances are
point-in-time at block 93,624,315 and drift test-loudly in CI. (4) The remote BSC/Ethereum counterpart contracts
were not re-audited; the Harmony-side E-U verdict does not depend on them.

## 8. Files index

```
harmony-orphans/
├── README.md                      # this report
├── summary.json                   # machine-readable summary (E-U/H-O/P/S)
├── analysis/
│   ├── H39-dossier.md             # full H-39 dossier (mechanism, state, paths, family/remotes, evidence)
│   ├── H40-dossier.md             # full H-40 dossier
│   ├── h39-family.json            # owner's bridge family: gen-1/2 OFTs, historical remotes, BSC/ETH counterparts
│   ├── h40-safes.md / h40-state.json / h40_state_raw.txt   # child sub-report + raw data
│   ├── heimdall-oneforbsc/        # decompiled NativeOFT source + ABI
│   ├── oft_logs.json              # 3,000 newest OFT event logs
│   ├── settr_hist_*.json, txs_*.json, top_balances_*.json, safe_factory_proxies.json, ...
├── poc/                           # Foundry project (forge-std vendored); tests fork Harmony in CI
├── ci/run.sh                      # probes RPC, exports HARMONY_RPC_URL, snapshots state to ci-out/
├── ci-log.txt                     # workflow log of the final run
└── ci-artifacts/                  # downloaded CI artifacts (state snapshot)
```
