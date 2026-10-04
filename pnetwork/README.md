# H-18 · pNetwork — live-extractability deep dive (Ethereum + BSC)

**Date:** 2026-10-04 · **Chains audited:** Ethereum (block 26,117,846), BNB Chain (block 125,645,713) + sibling-chain token surface (Polygon/Arbitrum/Gnosis/Algorand/Ultra/EOS/Telos) · **Status:** read-only; PoC fork-verified only (GitHub Actions); **no mainnet transactions, no keys used.**

**Finding (corpus):** pNetwork — DefiLlama last-known **$13.10M**, stale 670 d (`deadFrom` 2024-11-29), prior hacks: 2021 pBTC-on-BSC event-log spoofing (277 BTC ≈ $13M) and 2022 pGALA leaked governance key (whitehat drain ≈ $4.3M). Corpus warned: *verify live balances first (frozen-TVL caveat)*.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why closed | Latent risk |
|---|---|---|---|
| ETH `Erc20Vault` collateral (2 vaults with balances, e.g. `0x112334f5…`) | **$0** | `pegOut`/`adminWithdraw` are `onlyPNetwork` (EOA); `initialize()` already spent; supported tokens blocked from admin withdraw | Key leak of the `PNETWORK` EOAs (`0xDffE…B132`, `0x0531…CE7`, …) — all dormant since shutdown |
| ETH/BSC pTokens (`pBTC`, `pLTC`, `pGALA`, `pPNT`, `TLOS`, …) | **$0** | `mint` is `MINTER_ROLE`/owner-gated (single EOAs); `redeem` only burns caller's own balance and relies on the **dead** off-chain relayer for any release | Leaked minter/owner key (2022-class) → unbacked mint; no on-chain release path |
| v3 `PNetworkHub` (4 deployments) | **$0** | Contracts are uninitialized/dead: `factory()/epochsManager()/interimChainNetworkId()` return 0, `isLockedDown()` reverts — optimistic mint path unreachable | If ever initialized, permissionless queue+execute mints after challenge period |
| v4 XERC20 / Adapter / PAM | **$0 (no live collateral found)** | `Adapter.settle` requires TEE ECDSA signature; `XERC20Lockbox` only releases to a caller burning its own xERC20 | TEE key compromise / owner misconfig (not observed) |
| GSN meta-tx surface on pTokens | **$0** | `acceptRelayedCall` requires an ECDSA approval from `gsnTrustedSigner` | Trusted-signer key leak |
| Outstanding user pTokens (ETH+BSC) | $0 (not self-service) | Redemption depends on the shut-down off-chain relayer network | ~**$1.5M notional stuck** (S); team-only release (P) |

**Total live extractable by an external unprivileged attacker right now: $0** (confidence: **high** for EVM; the only assumption is that no pNetwork privileged key is currently public/compromised — none of the live role-holders is a contract with a permissionless path, and no leaked key matches a live role).

---

## 2. Mechanism in exact terms

pNetwork is a lock-and-mint federation bridge. The EVM surface has three generations:

1. **v1/v2 vaults (`provable-things/ptokens-erc20-vault`).** Collateral sits in `Erc20Vault`/`EthVault` contracts on the native chain. Release path is `pegOut(address,address,uint256)` / `pegOut(...,bytes)` and `adminWithdraw(address)` — both `onlyPNetwork`, i.e. a single pNetwork relayer EOA per deployment era (`PNETWORK`). `pegIn` is permissionless (deposit only). The vault `initialize()` is a public `initializer`; all live vaults are already initialized (re-verified: `initialize` reverts).
2. **v2 pTokens (`ptokens-erc777-smart-contract`).** ERC-777 `PToken` proxies. `mint` requires `MINTER_ROLE` (granted to a single EOA, e.g. `0x0e3bde3d…` on ETH); `redeem` burns `_msgSender()`'s tokens and emits `Redeem` — the actual release is done off-chain by the (now dead) relayer. GSN meta-tx support requires a `gsnTrustedSigner` ECDSA signature.
3. **v3 `PNetworkHub` (optimistic).** Anyone may `protocolQueueOperation` (bond) and, after the challenge period, `protocolExecuteOperation` mints pTokens unless a Guardian/Sentinel cancels. On-chain the four mainnet hubs are uninitialized (all reads revert), so this path is dead. **v4** replaced it with TEE-signed `Adapter.settle` + XERC20 lockboxes; no live collateral was found for it.

The two historical hacks are therefore not repeatable permissionlessly today: 2021 required spoofed log parsing in the (fixed) Rust node; 2022 required a leaked governance key.

## 3. Live-state assessment (verified, latest blocks)

### Ethereum (block 26,117,846)
- **Vault set:** 42 candidates enumerated (Blockscout name search + pNetwork deployer txlists `0x629aE98C…`, `0x789e39e4…`, `0x26e76220…`, `0xb0cf1453…`, `0xd24f0164…`). Only 4 implement `getSupportedTokens()`; only **2 hold priced collateral**:
  - `0x112334f50Cb6efcff4e35Ae51A022dBE41a48135` — `PNETWORK()=0xDffE7AC6B538B4A7Fd81c98C5fba0415d63fB132`. Holds: **DAI 5,921.19**, **BAT 44,982.04**, **ZRX 24,989.36**, **LRC 46,235.70**, **PNK 79,961.50**, **UNI 158.01**, MKR 0.1842, BAL 66.38, SNX 44.01, YFI 0.00347, UMA 1,597.29, COMP 0.0595, LINK 2.82, PNT 27,978.25, PTERIA 950,000.08 (unpriced). **≈$17.0k** priced (excluding PTERIA/spam).
  - `0xa55d3a3fE645E1f47f11C13B157e3767c7Fda913` — `PNETWORK()=0x053183A456B45E726010A39607C5AB562C497CE7`. Holds LINK 12.685, PNT 1,980.19, NCDT 0.010025 (**≈$181**).
  - `0xab83bd…` (LOTTO/BTSG dust), `0xadcdb2…` (empty); the v2-generation vaults `0xe01a9c36…/0xfbc34797…/0x3f22c568…/0xd331e3eb…/0x34d08551…` are **empty and already initialized**.
- **pToken supplies (raw):** pBTC 8.9183, pLTC 303.699, pFTM 8.137, pOATH 1.211, pDOGE 149,158.97, pIQ 2,664,830, TLOS 11,553,720, ethPNT 16,360,012, pSEEDS 971,967, pWSB 454,521,392, pEOS 171.76, pVAI 35.14, …
- **Role holders:** `MINTER_ROLE` for pBTC/pOATH/pFTM granted to **single EOA `0x0e3bde3d39ded57813f0d0727e574d16d675938b`** (RoleGranted @ blocks 14,320,559 / 14,584,085 / 14,622,605). Owners: `0x26e76220…` (pTokens Deployer 2), `0x789e39e4…`, `0xa8110626…` — all EOAs, no contract-mediated mint path.
- **v3 hubs** `0x09D28674…`, `0x26b9EF42…`, `0x8ABED515…`, `0x142Ef283…`: all reads revert/zero → dead.
- **pNetwork EOAs** hold negligible balances (checked USDT/USDC/GALA/PNT/UOS/WETH/TLOS).

### BNB Chain (block 125,645,713)
- 15 pTokens enumerated (pBTC 0.2691, pGALA 94,234,582, pPNT 19,325,888, pEFX 72,873,496, pOPEN 13,945,308, pANRX 13,939,258, pKEYS 16,801,070, pCGG 6,708,774, TLOS 6,499,210, pZMT 2,906,292, pBIST 2,903,095, pOPIUM 83,740, pTERIA 325, pBTC, pLUXO 36,995).
- Proxy admins: `0xA626Ec238A80B5C400E3BF77E046F83A17910786` (pGALA/pPNT/pEFX/pBTC/pKEYS), `0xdeac338B…` (TLOS) — contracts; owners are EOAs (`0x2161Ba04…`, `0x03Ec7B0e…`). Unprivileged `mint` reverts (fork-proved).
- **No BSC vault holds collateral** — BSC hosts pTokens; collateral lives on native chains (BTC wallet, ETH vaults). pNetwork EOAs on BSC hold <1.1 BNB and no stablecoins.

### Frozen-TVL reconciliation
DefiLlama's last snapshot ($13.10M; BSC $6.42M / ETH $3.46M / Ultra $3.13M / Algorand $81k) came from the pNetwork Grafana (`pnetwork.watch/api/...`, `tvl_dist` grouped by host chain, last update 2024-11-29) — it is the **host-side value of minted pTokens**, not collateral location. Live EVM collateral found today is ~$17k; outstanding EVM pTokens ≈ $1.5M notional. The bulk of the 2024 figure (BTC/LTC collateral, Ultra/Algorand claims) is not locatable as live EVM-extractable value. **Frozen-TVL caveat confirmed.**

## 4. What an attacker can/cannot do

- **Cannot** call `pegOut`/`adminWithdraw` on any vault (onlyPNetwork) — fork test `test_EU_vault_pegOut_reverts_for_unprivileged` (revert; balances unchanged).
- **Cannot** `initialize()` any live vault to hijack `PNETWORK` — already initialized (`test_EU_vault_initialize_already_spent`).
- **Cannot** mint pTokens (`MINTER_ROLE` EOAs) — fork tests on ETH pBTC and BSC pGALA.
- **Cannot** burn foreign pTokens (`redeem` burns `_msgSender()` only) — fork test.
- **Cannot** use the v3 optimistic mint — hubs are dead (`test_EU_v3_hub_is_dead`).
- **Cannot** abuse GSN: `acceptRelayedCall` needs the trusted signer's ECDSA approval.
- **Could only** profit by obtaining one of the privileged EOAs' keys (minter, owner/proxy admin, `PNETWORK`, TEE signer). None of these keys is public in the repos' current heads; historical leak was the 2022 pGALA proxy-admin key (patched by redeploy).
- Deposits (`pegIn`) remain callable but are loss-making (they lock the attacker's own funds with no working release path).

## 5. PoC / fork verification

`poc/` Foundry project (vendored forge-std). CI: **https://github.com/kingmariano/ca-zombie-ci/actions/runs/37189482964 — 9/9 PASS** (run 2026-10-04, branch `pnetwork`, ETH fork `ethereum-rpc.publicnode.com`, BSC fork via `BSC_RPC_URL`).

| Test | Result |
|---|---|
| `test_EU_vault_pegOut_reverts_for_unprivileged` | PASS |
| `test_P_vault_pegOut_allowed_for_PNETWORK_EOA` (1 wei, fork only) | PASS |
| `test_EU_vault_adminWithdraw_reverts_for_unprivileged` | PASS |
| `test_EU_vault_initialize_already_spent` | PASS |
| `test_EU_ptoken_mint_reverts_for_unprivileged` (ETH pBTC) | PASS |
| `test_EU_ptoken_redeem_cannot_burn_foreign_balance` | PASS |
| `test_EU_v3_hub_is_dead` | PASS |
| `test_EU_bsc_ptoken_mint_reverts_for_unprivileged` (BSC pGALA) | PASS |
| `test_P_bsc_ptoken_owner_is_eoa` | PASS |

Gas: all tests ≤ 87k gas; total 1.47 s.

## 6. Verdict

- **E-U = $0** (high confidence). No permissionless path releases collateral or mints backed value; all release/mint authorities are single EOAs or dead code.
- **H-O = $0.** No self-service withdrawal exists on-chain (`redeem` only burns; release is off-chain).
- **P ≈ $17k** priced vault collateral (plus 950k unpriced PTERIA) + BTC/LTC multisig collateral (out of EVM scope) + all pToken mint/upgrade authority — team-only.
- **S ≈ $1.5M notional** of outstanding EVM pTokens (pBTC $757k, pGALA $255k, TLOS $297k, pPNT $26k, pDOGE $14k, pLTC $21k, …) — unredeemable while the relayer network is shut down; team-only in practice.
- **Residual/latent risk:** a key leak of any live role-holder re-opens the 2022-class exploit; the v3 optimistic design (if ever initialized) would be permissionlessly mintable when actors are inactive; BSC pToken proxy admins are contracts controlled by EOAs.

## 7. Methodology, caveats, files

- Enumerated targets from the pTokens dapp asset registry, Blockscout v2 name search, Etherscan V2 `getcontractcreation`/`txlist`/`getsourcecode`/`getLogs`, pNetwork GitHub repos (`ptokens-erc20-vault`, `ptokens-erc777-smart-contract`, `pnetwork-v3-monorepo`, `pnetwork-v4`, `ptokens-core`), DefiLlama adapter history, and public post-mortems (Halborn, SlowMist, Benzinga, Telos).
- Balances read directly via `eth_call` at the stated blocks; USD at DefiLlama current prices (BTC $84,931, PNT $0.00133, GALA $0.00271, TLOS $0.01645) — spot prices, not Nov-2024 values.
- **Caveats:** (i) long-tail tokens in vaults are partly unpriced/spam; (ii) S is a notional figure with medium confidence (prices/decimals of dead tokens); (iii) UTXO-chain collateral (BTC/LTC) and EOSIO/Algorand-side contracts were out of scope; (iv) no leaked-key exploitation attempted (forbidden); classification assumes no live role-holder key is currently public.
- Files: `README.md`, `summary.json`, `analysis/` (raw state dumps + scripts), `poc/` (Foundry tests), `ci-log.txt`, `ci-artifacts/`.
