# C-27 — Renegade V1: exact incident mechanism + live-state evidence

All data read-only via public RPC / Etherscan V2 / GoldRush, 2026-10-03.
Arbitrum blocks cited from the CI run `live-state.json` (see `c-27/ci-artifacts/`).

## 1. The original exploit (2026-05-10, block 461,301,926)

- Victim: Arbitrum dark-pool proxy `0x30bD8eAb29181F790D7e495786d4B96d7AfDC518`
  (custom TransparentUpgradeableProxy, EIP-1967 impl slot).
- Implementation at attack time: `0xC038933d0b33359f5C87B4B2f92Ee0DAd11EaDc5`
  (Arbitrum **Stylus** program: `eth_getCode` prefix `0xeff00000`, 19,447 bytes).
- Attacker EOA: `0x777253F28AdC29645152b7B41BE5C772A9657777`; orchestrator created by the tx:
  `0x33FB722C76D4e9fC0c86BbF10EBDeA45a4434a34`; malicious delegate logic:
  `0x67da0e9245e2a9da74ac120d8c3caac21b9884da`; helper: `0x92df7b51734d4d8f5de7676ab193ff2138cb4b5c`.
- Attack tx: `0x0e494685ace16d372066c5b4db959b58ebac6d88166c2d9d618e0e421dc0c77e`
  (gasUsed 2,688,710; ~0.000054 ETH gas; no flash loan).

Call trace (DarkNavy `trace_callTracer.json`, indices 52–54, 209–211):

```
attacker orchestrator
 ├─ CALL proxy.initialize(address×10,uint256,uint256[2],address)        selector 0x92413afe
 │   ├─ DELEGATECALL impl (Stylus 0xC038933d...)  initialize(...)
 │   │   ├─ DELEGATECALL attacker logic 0x67da0e92... init()            selector 0xe1c7392a
 │   │   │   ├─ STATICCALL helper.beneficiary()                          selector 0x38af3eed
 │   │   │   ├─ STATICCALL helper.getAssets()                            selector 0x67e4ac2c
 │   │   │   └─ 26× (balanceOf(proxy) + transfer(attacker, bal))
 │   │   └─ DELEGATECALL attacker logic init(address)                    selector 0x19ab453c
 └─ CALL proxy.updateWallet(bytes,bytes,bytes,bytes)                     selector 0x803f430a
     ├─ DELEGATECALL impl updateWallet(...)
     │   └─ DELEGATECALL attacker logic updateWallet(...)                selector 0x803f430a
```

Note on selectors: the deployment bytecode contains `0x49209d7f` and `0x401fa185`; these are the
optimizer's halved encodings of the even selectors `0x92413afe` (×2) and `0x803f430a` (×2) used with
`SHL 225` instead of `SHL 224`. The trace-confirmed selectors are 0x92413afe / 0x803f430a.

Root cause: the proxy's **OpenZeppelin v5 `Initializable` ERC-7201 slot was never set** by the
Stylus implementation line. The April-2025 Solidity→Stylus migration (upgrade at block 324,060,260 to
impl `0x4B1D056d...`, `eth_getCode` prefix `0xeff00000`) left the version counter out of sync, so the
Stylus `initialize` remained callable on the already-initialized proxy. The attacker re-initialized
with attacker-controlled config (including the executor/logic address that the implementation
delegatecalls) and then triggered the delegatecall path via `updateWallet`.

Live proof of the desync: the OZ v5 Initializable slot
`0xf0c57e16840df040f15088dc2f81fe391c3923bec73e23a9662efc9c229c6a00` on the Arbitrum proxy reads
**0x00** today (and read 0 at the attack block), while on the properly-initialized Base deployment
the same slot reads **0x01**.

### Drained assets (26 ERC-20s, ~$209K)

SYNTH 1,349.03; PENDLE 9,416.90; CRV 7,415.26; DeFAI 3,231.36; LDO 10,869.73; LPT 791.16;
WBTC 0.34658469; FTW 15,000; RDNT 8,826.97; COMP 89.157; EVA 0.503; XAI 156,877.64; HOL 3.6;
ZRO 1,372.65; ETHFI 6,445.16; WETH 10.2765; ARB 15,471.65; GRT 69,679.69; USDC 104,383.59;
BKC 0.01; AAVE 30.99; SNL 3,750; LINK 385.59; UNI 528.46; GMX 250.45; USDT0 1,892.71.

### Recovery

- 2026-05-10 16:49–16:53 UTC: the attacker EOA transfers the bulk of the tokens back to
  `0xE4a7Cc3049...` (recovery address; txs at blocks 461,422,041–461,423,204).
- ~20,025 USDC remained; on 2026-05-19 the attacker bridged it out via Circle CCTP
  (`depositForBurn` to `0xfd78ee9196...`) — consistent with the reported 10% bounty (~$190K returned).
- 2026-05-10 18:04 UTC: team freezes the proxy — `ProxyAdmin.upgradeAndCall(proxy, DarkpoolFrozen,
  "")` at block 461,440,223 (tx `0x77b64740...`). `DarkpoolFrozen` (`0x58f876aAeeCBD5a0fca8F87e1313a9188C155bcC`,
  112 bytes) reverts every call and receive with `DarkpoolFrozenError()` = `0x7be24541`.

## 2. Live state (2026-10-03; see ci-artifacts/result-c-27/ci-out/live-state.json)

| Check | Value |
|---|---|
| Arbitrum block (final CI run) | 511,181,492 |
| EIP-1967 impl slot | `0x58f876aAeeCBD5a0fca8F87e1313a9188C155bcC` (DarkpoolFrozen) |
| impl codehash | `0x1eab163f1f897929be0389a77f1f4b52a3aa3dd2b328f6f0abf3f55f1944e315` |
| EIP-1967 admin slot | `0xAb6FB4aa6C5B04c7f6BAD72317d12b329dD5AB2d` (ProxyAdmin, `upgradeAndCall`) |
| ProxyAdmin owner | `0xf4c75938e590D9095939001E17C67ad86F243D8a` (EOA) |
| ProxyAdmin.upgradeAndCall from outsider | reverts `OwnableUnauthorizedAccount` (`0x118cdaa7`) |
| `initialize(0x92413afe)` live | reverts `DarkpoolFrozenError()` `0x7be24541` |
| `updateWallet(0x803f430a)` live | reverts `DarkpoolFrozenError()` `0x7be24541` |
| `owner()`, `admin()`, `implementation()` live | all revert `0x7be24541` |
| ETH balance | 0 |
| Balances of the 26 incident tokens | all 0 |
| Other token positions | 87 unpriced spam airdrops (immovable: no callable logic) |
| Residual approvals *to* the proxy (sample: first 1000 Approval events) | 22 non-zero allowances, incl. CoW GPv2Settlement `0x9008d19f...` infinite approvals on 12 tokens — but every owner's current balance in those tokens is 0, and the frozen proxy cannot execute `transferFrom` |

### Related contracts (all zero value)

- Old Stylus impls (`0x4b1d056d...`, `0xc98d8930...`, `0xc8b26584...`, `0xb5c19bba...`, `0xc038933d...`,
  `0x113eb054...`, `0x88a2e092...`, `0x557e4b0b...`, `0x33f71c7e...`, `0xb2b0d4ea...`,
  `0xee271fae...`, `0x92b5f6da...`): ETH 0, incident-token balances 0. Direct calls to the Stylus
  programs currently fail with `ProgramNeedsUpgrade(2,3)` (Stylus version bump).
- Direct Stylus darkpool on Arbitrum `0xb4a96068577141749CC8859f586fE29016C935dB` (same address as the
  Base proxy, but a Stylus program on Arbitrum): `ProgramNeedsUpgrade(2,3)`, ETH 0, token balances 0.
- May-2025 Stylus suite on Arbitrum (22 contracts deployed by `0x812922c3...`): all Stylus programs,
  ETH/token balances 0.
- Newer Solidity proxies (Apr 2026) `0xC5D1b809...` (impl `0x11d3dfd0...`) and `0xCE7a8D45...`
  (impl `0x90c3f277...`): OZ v5 init slot = 1, unpaused, owners `0xa6F018BB...` / `0x8C8534B7...`,
  hold only 1 wei VEXIL spam each.

### Base mainnet (other deployment flagged by docs/SDK)

| Check | Value |
|---|---|
| Base darkpool | `0xb4a96068577141749CC8859f586fE29016C935dB` (TransparentUpgradeableProxy, codehash `0x21654677...`) |
| Impl | `0xBBcCf2034970634f597d8139c3939EA782C7a0a4` (Solidity V1, 24,275 bytes) |
| ProxyAdmin | `0x2009A49dbF1AA4D7dDFf4a1F4ec07cdF7620ECc8`; owner EOA `0x93566DA988915201Fc2F90Af9d623e4B5cC5236A` |
| OZ v5 init slot | **0x01** |
| `initialize(0xacad1e2c)` (deployed V1 selector) | reverts `InvalidInitialization()` = `0xf92ee8a9` (fork-verified) |
| paused | false (live but initializer-gated) |
| ETH / WETH / USDC | 0 / 0 / 0 (939 unpriced spam airdrops only) |
| Getters | hasher `0x5dd0E86d...`, verifier `0xeA1160b7...`, transferExecutor `0xDAe0693A...`, permit2 canonical, feeRecipient `0x6aFc17c6...` |

### Testnets (no monetary value)

- Arbitrum Sepolia `0x9af58f1F...`: custom proxy, impl `0xCC31569F...` (Stylus, 19,447 bytes),
  OZ slot 0, ETH 0, calls revert empty (Stylus program inactive) — same desync profile, no value.
- Base Sepolia `0x653C9539...`: proxy, impl `0xB2840c81...`, OZ slot 1, ETH 0.

## 3. Why $0 is extractable today

1. The only proxy with the historical version-desync was bricked on 2026-05-10: its live
   implementation has no functions at all — `fallback()`/`receive()` revert `DarkpoolFrozenError()`.
   There is no call path from an unprivileged caller into any logic.
2. All upgrades require the ProxyAdmin `0xAb6FB4aa...` (`OwnableUnauthorizedAccount` otherwise),
   whose owner is the team EOA.
3. Every candidate family contract holds zero priced value; the only tokens in the proxy are
   unpriced spam, and they are immovable while frozen.
4. The Base deployment is live but its OZ v5 initializer version is 1, so `initialize` reverts
   `InvalidInitialization()`. Its initializer was consumed in the proxy constructor at deployment.
5. Residual approvals to the frozen proxy are inert (the proxy cannot execute `transferFrom`), and
   the allowance owners currently hold zero of the allowed tokens (sampled).

Counterfactual (fork-only, `test_04`): re-pointing the proxy at a vulnerable implementation profile
with `vm.store` + etching a shim makes the same `initialize → updateWallet` delegatecall path drain
seeded balances (100,000 USDC + 10 WETH + 1 WBTC). The freeze is exactly the gate.
