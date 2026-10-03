# C-27 — Renegade V1 dark pool (Arbitrum): live extractable-value determination

**Campaign:** zombie-hunt deep-dive · **Finding:** C-27 · **Chains:** Arbitrum One (primary), Base Mainnet (related deployment), Arbitrum/Base Sepolia (testnets)
**Date of work:** 2026-10-03 · **Status:** read-only research; PoC fork-verified in public CI only; **no mainnet transactions sent**
**Live verdict:** **an external, unprivileged attacker can extract ≈ $0 today.** The historical version-desync proxy was frozen on 2026-05-10 (implementation bricked; every call reverts `DarkpoolFrozenError`), holds no priced assets, and all related deployments are either empty, initializer-gated, or privileged-only.

---

## 1. TL;DR

| # | Target (Arbitrum unless noted) | Live extractable (unprivileged) | Why closed today | Latent risk |
|---|---|---|---|---|
| 1 | Dark-pool proxy `0x30bD8eAb29181F790D7e495786d4B96d7AfDC518` | **$0** | Frozen 2026-05-10 18:04 UTC: impl = `DarkpoolFrozen` (`0x58f876aA…`); `initialize`/`updateWallet`/all calls revert `0x7be24541`; ETH + all 26 incident tokens = 0 | Residual ERC-20 approvals (22 non-zero, incl. CoW GPv2Settlement infinite approvals) — inert while frozen; owner balances currently 0 |
| 2 | Old Stylus impls (`0xC038933d…` + 11 others) | **$0** | Direct calls now fail `ProgramNeedsUpgrade(2,3)`; ETH/token balances 0 | Stylus programs can be re-activated by anyone, but hold no value |
| 3 | Direct Stylus dark pool `0xb4a96068577141749CC8859f586fE29016C935dB` (Arbitrum) | **$0** | `ProgramNeedsUpgrade(2,3)`; ETH/token balances 0 | Same as above |
| 4 | Base dark pool `0xb4a96068577141749CC8859f586fE29016C935dB` | **$0** | Live/unpaused Solidity V1, but OZ v5 init slot = 1 → `initialize(0xacad1e2c)` reverts `InvalidInitialization()`; no priced balances | If its ProxyAdmin (owner EOA `0x93566DA9…`) ever upgrades to a vulnerable impl |
| 5 | Newer proxies `0xC5D1b809…`, `0xCE7a8D45…` (Apr 2026) | **$0** | OZ init slot = 1; no priced balances | Admin-gated only |
| 6 | ProxyAdmin `0xAb6FB4aa…` | **$0** | `upgradeAndCall` reverts `OwnableUnauthorizedAccount` for outsiders; owner = team EOA | Team-key compromise would unfreeze/repoint the proxy |

**Total live extractable now: $0 (high confidence).**

---

## 2. The bug, in exact terms

Renegade's V1 dark pool on Arbitrum is a custom TransparentUpgradeableProxy. Upgrades (Etherscan
`Upgraded` events, 15 total) moved from Solidity implementations (2024-09 → 2025-01) to
**Arbitrum Stylus** implementations starting with the 2025-04-08 migration (block 324,060,260,
impl `0x4B1D056d…`, `eth_getCode` prefix `0xeff00000`). The migration left the OpenZeppelin v5
`Initializable` ERC-7201 slot (`0xf0c57e16…c6a00`) at **0** on the proxy, so the Stylus
`initialize` remained callable on an already-initialized proxy — the "version counter out of sync".

Original exploit (2026-05-10, block 461,301,926, tx `0x0e494685…`):

1. Attacker calls proxy `initialize(address×10,uint256,uint256[2],address)` (`0x92413afe`) with
   attacker-controlled addresses. The implementation **delegatecalls** the injected logic
   (`init()`), which sweeps `balanceOf(address(this))` for every token in the attacker's list.
2. Attacker calls proxy `updateWallet(bytes,bytes,bytes,bytes)` (`0x803f430a`); the implementation
   again delegatecalls the attacker-controlled executor from proxy context.

Result: 26 ERC-20 balances transferred from the proxy to the attacker (~$209K; 104,383.59 USDC,
10.2765 WETH, 0.34658469 WBTC, …). ~$190K was returned same-day; ~20,025 USDC (the 10% bounty) was
bridged out via Circle CCTP on 2026-05-19.

Same-day fix: `ProxyAdmin.upgradeAndCall(proxy, DarkpoolFrozen 0x58f876aA…, "")` at block
461,440,223. The frozen implementation (112 bytes) is:

```solidity
contract DarkpoolFrozen {
    error DarkpoolFrozenError();
    fallback() external payable { revert DarkpoolFrozenError(); }
    receive()  external payable { revert DarkpoolFrozenError(); }
}
```

**The exact original path is closed**: both entrypoint selectors revert `0x7be24541`, and the proxy
has no other callable logic.

---

## 3. Live-state assessment (final CI run: Arbitrum block 511,181,492; Base block 52,103,998; 2026-10-03)

### 3.1 Arbitrum proxy `0x30bD8eAb29181F790D7e495786d4B96d7AfDC518`

| Check | Result |
|---|---|
| `eth_getCode` | present (custom proxy, 1,904 bytes) |
| EIP-1967 impl slot `0x360894a1…` | `0x58f876aAeeCBD5a0fca8F87e1313a9188C155bcC` (codehash `0x1eab163f…44e315`) |
| EIP-1967 admin slot `0xb5312768…` | `0xAb6FB4aa6C5B04c7f6BAD72317d12b329dD5AB2d` (ProxyAdmin with `upgradeAndCall`) |
| OZ v5 init slot `0xf0c57e16…` | **0** (the desync that enabled the attack) |
| `initialize(0x92413afe)` / `updateWallet(0x803f430a)` / `owner()` / `admin()` | all revert `DarkpoolFrozenError()` = `0x7be24541` |
| ETH balance | 0 |
| 26 incident-token balances | all 0 |
| Other positions | 87 unpriced spam airdrops (ERC-20/NFT), immovable (no callable logic) |
| `upgradeTo(address)` from outsider | delegates to frozen impl → `0x7be24541`; from admin → `ProxyDeniedAdminAccess()` (`0xd2b576ec`) — upgrades only via ProxyAdmin |
| ProxyAdmin owner | `0xf4c75938e590D9095939001E17C67ad86F243D8a` (EOA); `upgradeAndCall` from outsider reverts `OwnableUnauthorizedAccount` (`0x118cdaa7`) |

### 3.2 Residual approvals to the frozen proxy

Sampling the first 1,000 `Approval` events (topic2 = proxy) yields 55 (token, owner) pairs; **22 are
still non-zero**, including the canonical **CoW Protocol GPv2Settlement** `0x9008d19f58…` with
near-infinite allowances on ARB, CRV, LDO, LPT, WBTC, RDNT, COMP, XAI, ETHFI, GRT, AAVE, LINK
(plus USDC/WETH/WBTC allowances from other holders). All sampled owners currently hold **0** of the
allowed tokens, and — critically — the frozen proxy cannot execute `transferFrom` at all. These are
latent only (would matter if the admin ever points the proxy at a malicious/vulnerable impl).

### 3.3 Family enumeration

- **Old Stylus implementations (12)**: `0x4B1D056d…`, `0xC98d8930…`, `0xC8b26584…`, `0xB5c19bBa…`,
  `0xC038933d…`, `0x113eb054…`, `0x88A2e092…`, `0x557E4B0b…`, `0x33F71C7e…`, `0xB2B0D4ea…`,
  `0xEE271FAe…`, `0x92B5f6dA…` — all ETH/token balances 0; direct calls now fail
  `ProgramNeedsUpgrade(2,3)`.
- **Direct Stylus dark pool** `0xb4a96068…` (Arbitrum) — `ProgramNeedsUpgrade(2,3)`, balances 0.
- **May-2025 Stylus suite** (22 contracts deployed by `0x812922c3…`, blocks 334.93M–335.05M) — all
  Stylus, balances 0.
- **Newer Solidity proxies (Apr 2026)** `0xC5D1b809…` (impl `0x11d3dfd0…`) and `0xCE7a8D45…`
  (impl `0x90c3f277…`) — OZ init slot = 1, unpaused, hold 1 wei of a spam token each.
- **Base dark pool** `0xb4a96068…` — live Solidity V1 (impl `0xBBcCf203…`), ProxyAdmin
  `0x2009A49d…` (owner EOA `0x93566DA9…`), OZ init slot = 1, `paused() = false`,
  `initialize(0xacad1e2c)` reverts `InvalidInitialization()` (`0xf92ee8a9`, fork-verified).
  ETH/WETH/USDC = 0; 939 unpriced spam airdrops.
- **Testnets** — Arbitrum Sepolia `0x9af58f1F…` (Stylus impl `0xCC31569F…`, OZ slot 0, calls revert
  empty, no value) and Base Sepolia `0x653C9539…` (OZ slot 1). No monetary value.

---

## 4. What an attacker can/cannot do

**Cannot:**
- Call `initialize`/`updateWallet`/any function on the Arbitrum proxy: every call reverts
  `DarkpoolFrozenError()` — no code path reaches state mutation.
- Upgrade the proxy: `upgradeAndCall` is `Ownable`-gated to the team EOA via ProxyAdmin.
- Pull the residual allowances: the proxy can never call `transferFrom`.
- Drain the Base dark pool via re-initialization: OZ v5 version = 1 → `InvalidInitialization()`.
- Find value in any impl/child contract: all measured zero (ETH + the 26 tokens + broader GoldRush
  scans).

**Could (latent, not extractable now):**
- If the team EOA `0xf4c75938…` (or Base admin EOA `0x93566DA9…`) ever upgrades to a
  vulnerable/malicious implementation, the residual allowances and any future deposits become
  drainable — the fork counterfactual test (`test_04`) shows the same `initialize → updateWallet`
  delegatecall path drains seeded balances the moment the proxy points at a vulnerable profile.
- The old Stylus programs can be re-activated (permissionless activation), but hold nothing.

Costs: zero capital required for any attempted path; the only historical cost was gas (~0.000054 ETH).
No flash loans needed. All candidate paths today revert before doing work.

---

## 5. PoC / fork verification

Project: `poc/` (Foundry, vendored forge-std from `c-20`). Run via the campaign CI helper
(`bash ci/ci-run.sh c-27`). All tests fork live chains read-only; `test_04` mutates only local fork
state (`vm.store`/`vm.etch`) to simulate the pre-freeze implementation.

| Test | What it proves | Result |
|---|---|---|
| `test_01_live_impl_is_darkpool_frozen` | EIP-1967 slot → `0x58f876aA…`; codehash `0x1eab163f…` | PASS |
| `test_02_original_exploit_entrypoints_revert` | original `0x92413afe` + `0x803f430a` and generic getters all revert `0x7be24541`; proxy rejects ETH | PASS |
| `test_03_live_balances_are_zero` | proxy + 4 impl accounts hold 0 of all 26 incident tokens and 0 ETH | PASS |
| `test_04_counterfactual_unfreeze_path_reopens_drain` | local-only: re-pointing impl + etching the vulnerable surface drains 100,000 USDC + 10 WETH + 1 WBTC → **freeze is the gate** | PASS |
| `test_base_initializer_is_consumed` | Base OZ init slot = 1; `initialize(0xacad1e2c)` reverts `InvalidInitialization()` `0xf92ee8a9` | PASS |
| `test_base_balances` | Base dark pool WETH/USDC/ETH = 0 | PASS |

**6/6 PASS.** CI runs (public repo `kingmariano/ca-zombie-ci`):

- Final passing run: `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37092580451`
- Iteration run (2 tests fixed after it): `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37092086515`

Artifacts: `ci-artifacts/result-c-27-run2/ci-out/live-state.json` (final run, machine-readable live snapshot from CI; block 511,181,492 / 52,103,998).

---

## 6. Verdict, residual & latent risk

- **E-U (external unprivileged extractable): $0.** No call path exists; all candidate contracts are
  frozen, empty, or properly initialized.
- **H-O (holder-only recoverable): $0.** The dark pool held user deposits, but they were drained and
  mostly returned in 2026-05; nothing remains for holders to withdraw.
- **P (privileged): the team can upgrade/freeze via ProxyAdmin** — `0xAb6FB4aa…` on Arbitrum (owner
  EOA `0xf4c75938…`), `0x2009A49d…` on Base (owner EOA `0x93566DA9…`). This is also the main residual
  risk channel (key compromise → unfreeze/repoint).
- **S (stuck): 87 unpriced spam airdrops** in the frozen Arbitrum proxy; immovable, no market value.
- **Latent risk notes:** (a) 22 non-zero ERC-20 approvals remain pointed at the frozen proxy,
  including CoW GPv2Settlement infinite approvals — currently inert and with zero owner balances;
  (b) old Stylus programs are reactivatable by anyone but hold no value; (c) the Base dark pool is
  live and unpaused — its only protection is the correctly consumed OZ initializer.

Blockers that make the historical path fail today: frozen implementation (all calls revert),
admin-gated upgrades (`OwnableUnauthorizedAccount`), zero balances, consumed OZ initializer on the
Base sibling.

---

## 7. Methodology & sources; caveats; files

**Method:** Etherscan V2 (Arbitrum) for upgrade history, creation, token transfers, approvals;
public/private RPC (`eth_call`, `eth_getStorageAt`, `eth_getCode`, `eth_getLogs`) for live state and
revert selectors; GoldRush for balance enumeration; DarkNavy trace artifacts + DeFiHackLabs PoC for
the exact original call path; `renegade-fi` GitHub (renegade, renegade-contracts, renegade-docs,
typescript-sdk) for the contract family and deployment addresses; Foundry fork tests in public CI.

**Caveats:** (1) The 2025-04 Stylus implementations are WASM and cannot be executed by revm — the
counterfactual test uses a minimal shim (etched on the fork only) that reproduces the documented
initialize/updateWallet delegatecall surface; the historical drain itself is evidenced by the
on-chain trace and the attacker's token transfers. (2) Public Arbitrum RPC is non-archive, so the
attack block cannot be replayed directly; live-state assertions are at the latest block. (3) The
allowance sample is capped at the first 1,000 `Approval` events returned by Etherscan — more pairs
may exist beyond the cap; all sampled current allowances are capped by owners' (zero) balances.
(4) Spam-token valuations are not attempted (no price feed); they are immovable while frozen.

**Files index:**

```
c-27/
├── README.md                          # this deliverable
├── summary.json                       # machine-readable summary
├── analysis/
│   ├── incident_mechanism_and_live_state.md
│   ├── upgrade_history.json           # 15 proxy upgrades + migration notes
│   ├── family_contracts.json          # family enumeration (Arbitrum/Base)
│   ├── proxy_allowances.json          # 22 current non-zero allowances to the frozen proxy
│   ├── proxy_allowance_exposure.json  # owner balances for each allowance
│   └── renegade-contracts/            # pulled Solidity sources (Darkpool.sol, proxies, V2)
├── poc/                               # Foundry project (6 tests)
├── ci/run.sh                          # CI live-state snapshot job
├── ci-out/live-state.json             # generated snapshot (also in ci-artifacts)
├── ci-log.txt                         # CI log (fetched by helper)
└── ci-artifacts/                      # CI artifacts
```
