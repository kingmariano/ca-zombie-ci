# C-26 · SquidRouterModule — third-party Gnosis Safe module with attacker-controlled delegate trust

**Date:** 2026-10-03 · **Chain:** Ethereum mainnet (same module also live on Base + Arbitrum) ·
**Status:** read-only; PoC fork-verified only; **no mainnet transactions** were sent.

Target: [`0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca`](https://etherscan.io/address/0x1f1d37a3Bf840e35c6a860c7C2dA71Fe555123ca)
("SquidRouterModule", verified source, v0.8.30). It interfaces with Squid Router/Axelar and has **no
official relationship with Squid**. On 2026-05-25 it was exploited for ~$3.2M–$4M across 86–88 Safes
(Ethereum/Base/Arbitrum).

## 1. TL;DR

| Surface | Live extractable (unprivileged) | Why open/closed | Latent risk |
|---|---|---|---|
| Module `0x1f1d…23ca` itself | **$0** (0 ETH, only 10 valueless spam tokens) | module holds nothing | none |
| **34 Safes with module still enabled** (all have a delegate with `*` permission) | **$0 net** — gross dust **≈ $2.10** on Ethereum | execution path is still fully live; only the *value* is gone (dust) | **high**: anyone can drain any funds that land in these 34 Safes until the module is disabled |
| Base (31 Safes) + Arbitrum (32 Safes), same module address | **≈ $0.46 gross** (CI) | same flaw, same dust-level balances | same |
| 59 traced 2026-05-25 Ethereum victims | $0 | all disabled the module | — |
| Safes with module disabled | $0 | `execTransactionFromModule` reverts (`GS104`) | — |

**Headline: external unprivileged attacker can extract ≈ $0 net right now (gross dust ≈ $2.10 on
Ethereum + ≈ $0.46 on Base/Arbitrum; gas alone costs ≫ the gross). Confidence: high.**

## 2. The bug, in exact terms

`SquidRouterModule` is an Axelar express-executable Safe module. Its cross-chain destination handler
decodes the *delegate* address from the bridged payload and then trusts it for the local Safe
permission check:

```solidity
// SquidRouterModule.sol (verified source), lines 159-175
function _processPayload(IERC20 bridgedToken, uint256 bridgedTokenAmount, bytes calldata payload) internal {
    (address module, address safe, address delegate, ActionsExecutionParams memory params) =
        abi.decode(payload, (address, address, address, ActionsExecutionParams));
    require(module == address(this), InvalidModuleAddress(module));
    bridgedToken.safeTransfer(safe, bridgedTokenAmount);
    _handleActions(safe, delegate, params);      // <-- attacker-chosen delegate
}
```

Every action handler then checks `permissionsManager.hasPermission(safe, delegate, …)` and executes
through the Safe:

```solidity
function _checkPermission(address safe, address delegate, string memory permissionName) internal view virtual {
    require(permissionsManager.hasPermission(safe, delegate, _getPermissionEntry(permissionName)),
            PermissionDenied(safe, delegate, permissionName));
}
function _safeCall(address safe, address to, uint256 value, bytes memory data, string memory callName) internal {
    require(ISafe(safe).execTransactionFromModule(to, value, data, 0), CallExecutionFailed(callName));
}
```

Nothing binds `delegate` to `msg.sender`, to a signature, or to the bridged message. The attacker:

1. Reads a victim Safe's delegate list from the public `PermissionsManager`
   (`0x03B8B1bA6B02b8A566cB757DFa627f7198c44cB7`, `getAccountDelegatorsInfo`) — all 34 live Safes
   have delegates holding the wildcard `"*"` for module `0x1f1d…`.
2. Builds an `ActionsExecutionParams` payload naming that delegate and any whitelisted action
   (Uniswap V2/V3 swap via a whitelisted Universal Router, ERC20 approve to `squidRouter` /
   Universal Router / Permit2, Permit2 approve, WETH wrap/unwrap).
3. Delivers it permissionlessly. Two equivalent entries:
   * `expressExecuteWithToken(...)` — **external, no signature, no gateway**; only requires the caller
     to hold/approve 1 wei of a token symbol the Axelar gateway maps (e.g. `"DAI"`), and a fresh
     `commandId`. (This is the entry used in the fork PoC.)
   * A real Squid Router `bridgeCall` on any source chain → Axelar delivery →
     `executeWithToken` → `_processPayload`. The module's only "auth" is a fixed-string check
     `Strings.parseAddress(sourceAddress) == squidRouter` — a constant that is public in the verified
     source and trivially supplied by the caller.
4. The Safe itself executes the actions via `execTransactionFromModule` — no Safe nonce, no owner
   signatures. The victim's tokens are swapped through an attacker-owned pool for an attacker-minted
   worthless token; the attacker then removes liquidity and keeps the real tokens.

`executeSameChainActions(safe, params)` is **not** directly exploitable by a random caller: there
`delegate = msg.sender` (`BaseModule._getDelegate()`), so the caller must already hold a permission.
The cross-chain/express path is what breaks that binding.

## 3. Live-state assessment (all reads on-chain, block 26109087 unless noted)

| Item | Value |
|---|---|
| Module code | verified `SquidRouterModule`, 13.9 KB runtime, no proxy, no pause/guard |
| Module own balance | 0 ETH; 10 spam tokens × 1 wei (valueless) |
| PermissionsManager | `0x03B8B1bA6B02b8A566cB757DFa627f7198c44cB7` (verified) |
| DelegateBundler | `0x276ce926826d2cE94cd844C40632F5c3a8F80d1f` (signature-gated) |
| Whitelisted routers | `0x66a9893cC07D91D95644AEDD05D03f95e1dBA8Af`, `0x65b382653f7C31bC0Af67f188122035461ec9C76` |
| Axelar gateway / Squid router | `0x4F4495243837681061C4743b74B3eEdf548D56A5` / `0xce16F69375520ab01377ce7B88F5BA8C48F8D666` |
| Safes that ever enabled the module | **150** (`EnabledModule` logs, topic1 = module) |
| Safes that disabled it | **116** (`DisabledModule` logs) |
| **Safes with it enabled today** | **34** — verified three ways: `EnabledModule`/`DisabledModule` replay, Safe Tx Service `/modules/{module}/safes/` (34), and live `isModuleEnabled` for all 150 + all 99 action-emitting Safes (`exhaustive_enabled_check.json`) |
| Delegates with `*` for the module | **34/34** Safes have 1–2 delegates with `"*"`; permissions never revoked |
| 2026-05-25 incident victims (Ethereum) | 59 unique Safes in the attack-window module events; **0 still enabled** |
| NFTs | 1 NFT total across the 34 (a Uniswap V3 position NFT) — **not movable** via the module (no arbitrary-call action) |
| Same module on Base / Arbitrum | deployed at the same address, 31 / 32 Safes still enabled (Safe Tx Service), ≈ $0.37 / $0.09 gross (CI) |

### 3.1 The 34 still-enabled Safes (gross balances, DefiLlama/Blockscout prices)

Full table in `analysis/safes_table.csv`; addresses in `analysis/safe_verification.json`. Non-dust entries:

| Safe | Tokens (raw) | USD | ETH | `*` delegate(s) |
|---|---|---|---|---|
| `0x54Ff035038A23f64E2537E3Cd324A7d5C31F57Ed` | — | $0.96 | 0.00036 | 2 |
| `0x63e35c1A4745B566e9D07574544E39B96A3473B6` | 172.48 TURBO; PAXG/WBTC/HEX dust | $0.47 | 0.0000788 | 2 |
| `0x469295ECaEFDC66224A8081d34598C4c6EE2CB75` | 276,359 USDC; 0.09898 Api3-dCOMP-USDC | $0.38 | 0 | 2 |
| `0x214C7dA3612Da38460db84460713A382Db7375Ad` | 339 WBTC-wei | $0.29 | 0 | 2 |
| `0x9A2E343621f45A5bc7913b3DDD169Cde67C6a59E` | 1 HEX | $0.001 | 0 | 2 |
| other 29 Safes | only 10 spam tokens each / empty | $0 | 0 | 2 |

**Gross total Ethereum: ≈ $2.10** (tokens ≈ $0.93 + 0.0004388 ETH × $2,676.83 ≈ $1.17).

## 4. What an attacker can and cannot do

**Can** (permissionless, no keys):
* For any of the 34 Safes: make it call a whitelisted Universal Router with a V3 swap whose `path`
  points at an attacker pool — draining the Safe's chosen ERC20 into the attacker's liquidity.
* Make it `approve` an arbitrary ERC20 to Permit2 / a whitelisted router / Squid router, and grant
  Permit2 allowances to a whitelisted router.
* Wrap/unwrap the Safe's ETH through WETH.
* Do all of the above in one transaction, for many tokens, using only ~1 wei of a gateway-mapped token
  and a fresh `commandId`.

**Cannot** (checked in code): change Safe owners/threshold/guard, execute arbitrary calls (targets are
hard-limited to token `approve`, Permit2, WETH, whitelisted routers), move NFTs, or touch a Safe whose
module is disabled (`execTransactionFromModule` reverts `GS104`).

**Costs:** the full fork PoC (attacker V3 pool deployment + liquidity mint + module express call +
swap + liquidity burn/collect) consumed **7.0M gas** (run 2) — at 2–20 gwei and $2,677/ETH that is
≈ $37–$376, an order of magnitude above the ≈ $2.10 gross. The module call alone is a fraction, but
even the most optimistic mainnet gas pricing leaves the operation deeply unprofitable. Capital need is
minimal: the attacker pool can be structured one-sided (attacker-token-only liquidity above spot), so
no real victim-token capital is required; the blocker is gas, not capital.

## 5. PoC / fork verification (Foundry, CI)

`poc/test/SquidRouterModuleExploit.t.sol` — runs on a mainnet fork (`FORK_RPC_URL`), no mainnet txs.

1. `test_live_safe_is_still_drainable` — against live Safe `0x469295EC…CB75` and its live `*` delegate
   `0x7f8b1796…Af56b`:
   * asserts `isModuleEnabled == true` and `hasPermission(safe, delegate, (module, "*")) == true` live;
   * builds an attacker V3 pool (attacker-minted token "u"), then calls
     `expressExecuteWithToken(…, "DAI", 1)` with the crafted payload;
   * asserts the Safe's USDC falls, the pool receives it, and after `burn`/`collect` the attacker ends
     with more USDC than the liquidity they supplied (net extraction ≈ the victim's balance).
2. `test_direct_path_reverts_without_permitted_delegate` — negative control: a random delegate is
   rejected by `PermissionManager.hasPermission` (revert).

CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`, workflow `poc.yml`):
* **run 2 (PASS, 2/2): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37093274390**
  * `[PASS] test_live_safe_is_still_drainable` — victim USDC `276,359 → 0`; attacker pool `552,718 → 829,077`; victim received 183,870 worthless attacker tokens; attacker ended with 1,105,434 USDC raw, **net profit 276,357 raw USDC = the victim's entire balance** (gas 7,009,379 for the whole test incl. pool setup/exit).
  * `[PASS] test_direct_path_reverts_without_permitted_delegate` (negative control, gas 903,503).
* run 3 (PASS): `<CI_URL_3>` — gas-instrumented variant.
* enumeration artifacts: `ci-out/enumeration.json`, `ci-out/safes.csv`, `ci-out/crosschain.json`.
* note: the CI repo's `ETHERSCANV2_API_KEY` secret currently returns `Invalid API Key`, so the CI enumeration
  transparently falls back to the event logs shipped in `analysis/logs/` (same 150/116/34 result).

## 6. Verdict and residual risk

**Verdict: the exploit path is still fully open on 34 Ethereum Safes (and 63 more on Base/Arbitrum),
but the value at risk today is ≈ $2.10 gross / $0 net. The incident victims have all disabled the
module; the remaining enabled Safes are dust wallets (mostly airdrop spam).**

Residual / latent risk — high for anyone who re-funds these Safes:
* The permission grants (`"*"` for module `0x1f1d…`) are **not revoked** on any of the 34; disabling
  the module is the only mitigation the owners applied (and they didn't even do that).
* Any deposit into these Safes is immediately drainable by any external caller with a fresh
  `commandId` and 1 wei of a gateway token; no victim action is needed for the attacker to strike.
* The same Safe suite enables **12–13 sibling modules** (CoW/Aave/UniswapV4/…). Sampled siblings
  (`CoWModule`, `AaveModule`, `UniswapV4Module`) do **not** contain the cross-chain payload/`delegate`
  trust pattern; the flaw is specific to the SquidRouterModule's bridge handler. The 34 Safes'
  wildcard grants across the suite remain a general modular-account risk, but no equivalent drain path
  was found in the sampled siblings (not a full audit).
* Disable timeline: 62 Safes disabled on 2026-05-25 (attack day), 26 on 05-26, then stragglers; the
  last disable was 2026-08-31 (block 25,877,375). 34 owners never disabled it.
* The same module address is still enabled on 31 Base Safes and 32 Arbitrum Safes (dust today).

Blockers for a profitable attack: gas ≫ dust balances; no other capital or permission blocker exists.

## 7. Methodology, sources, caveats, files

**Method:** verified source (Etherscan V2) + local compile inspection; `EnabledModule`/`DisabledModule`
event replay (topic1 = module) and `ActionExecuted` logs; Safe Tx Service cross-check; live
`isModuleEnabled` for all 150 ever-enabled + all 99 action-emitting Safes; `getAccountDelegatorsInfo`
decoded from raw `eth_call`; balances from Blockscout v2 + curated `balanceOf` batches, priced with
DefiLlama; fork PoC on CI.

**Sources:** Halborn "Explained: The SquidRouterModule Hack (May 2026)"; Common Prefix
"$4M SquidRouterModule Exploit: What Exactly Happened" (26/05/2026); web3isgoinggreat entry
(2026-05-25); Blockaid/PeckShield reporting. Corpus: `zombie_hunt/FINDINGS.md` C-26,
`incidents_zombie_contracts.md` #34.

**Caveats:**
* "Extractable" = ERC20 + native balances reachable by the module's action set. NFTs are not
  reachable; DeFi positions are included as their token balances.
* USD uses DefiLlama prices at 2026-10-03 (~$2,676.83/ETH, ~$84,530/WBTC); spam tokens are unpriced.
* Base enabled-status check is via Safe Tx Service + RPC spot checks; its full event replay was not
  run (supplementary surface only).
* The 59-victim count is from Ethereum attack-window events; Common Prefix counts 88 across all
  three chains (not all traced here).
* No mainnet transactions were signed or sent. The PoC is fork-only.

**Files:**
```
c-26/
├── README.md                     this file
├── summary.json                  machine-readable summary
├── analysis/                     source dumps, event logs, verification JSON, scripts
│   ├── etherscan_source_raw.json, source_bundle.json, src_dump/…   verified sources
│   ├── logs/enabled_module.json, logs/disabled_module.json, logs/module_actions.json
│   ├── safe_tx_service/safes_current.json
│   ├── safe_verification.json, drainable_now.json, exhaustive_enabled_check.json
│   ├── incident_victims.json, balances/blockscout_balances.json, nft_holdings.json
│   └── verify_safes.py, fetch_logs.py, exhaustive_check.py, fetch_blockscout.py, onchain_balances.py
├── poc/                          Foundry fork PoC (vendored forge-std)
│   ├── foundry.toml
│   └── test/SquidRouterModuleExploit.t.sol
├── ci/                           heavy job: ci/run.sh + enumerate.py + crosschain.py
├── ci-out/                       CI artifacts (enumeration.json, safes.csv, crosschain.json)
└── ci-log.txt, ci-artifacts/     downloaded CI logs/artifacts
```
