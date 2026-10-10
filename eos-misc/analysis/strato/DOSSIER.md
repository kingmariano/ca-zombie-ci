# STRATO — H2-05 deep-dive dossier

**Date:** 2026-10-10 (all reads at STRATO mainnet block **622,692**, `0x98064`; oracle timestamp 1791646203 ≈ 2026-10-10 16:50 UTC)
**Status:** read-only research; no transactions signed or sent anywhere; all calls via public endpoints (`eth_call`, `eth_getCode`, public REST APIs).
**Sources of truth:** live chain state (public RPC + explorer API + Cirrus index), DefiLlama APIs/adapters, project docs (`docs.strato.nexus`), corpus (`zombie_hunt/ZOMBIE-HUNT-II.md` L2-23 + H2-05).

---

## 1. TL;DR

| Question | Answer |
|---|---|
| What is "STRATO"? | **STRATO / "STRATO Mercata"** — a **public L1 blockchain built by BlockApps** (chain ID `123354377739506`). Not a permissioned enterprise chain; not a BlockApps private shard. Native token is **USDST**, a stablecoin. Contracts are Solidity compiled to BlockApps' **SolidVM** (no EVM bytecode). |
| The "$16M"? | **DefiLlama TVL of the `strato` protocol**: **$16,190,997** (2026-10-10), category CDP, chain "Strato". Dominated by **3,213 GOLDST (tokenized gold) ≈ $13.49M**, mostly inside the CDP vault, plus **$2.0M USDST** (savings/liquidity), SILVST, ETH, WBTC, stables. |
| Is it verifiable? | **Yes — fully.** Public keyless RPC, Etherscan-compatible explorer, and a PostgREST **Cirrus** index of all contract state. The $16.19M was reconciled line-by-line against live balances (see §4). The corpus label "unverified native-contract chain" was a **mislabel**: no public *source code* exists (SolidVM), but ABIs + state + gating behavior are all publicly readable. |
| Is the $16M reachable by an unprivileged attacker? | **No path found → $0 proven E-U** (confidence medium-high; behavioral verification, not a source audit — no source is published). 17/17 admin-function gating simulations and 8/8 "free-money" simulations from a random address reverted. |
| Verdict | **E-U $0.00 · H-O ≈ $10.64M user positions · P = whole protocol under 2-of-3 admin EOAs + function-scoped whitelist (upgradeable via `setLogicContract`) · S $0.00.** Residual risk is **key-governance (P), not permissionless extraction**. |

---

## 2. What STRATO actually is

- **Operator:** BlockApps (enterprise-blockchain vendor); product brand **STRATO Mercata**. Public docs: `docs.strato.nexus`; app: `app.strato.nexus`; explorer: `stratoscan.strato.nexus`.
- **Consensus:** PBFT; 17 validators listed in `/strato-api/eth/v1.2/metadata` (`isSynced: true`).
- **Execution:** **SolidVM** — Solidity contracts on a custom VM. `eth_getCode` returns `0x01` for contracts (no EVM bytecode to inspect); function calls use standard ABI via `eth_call`; tx `input` is empty and the explorer exposes `functionName` instead.
- **Public endpoints (all verified live, keyless):**
  - JSON-RPC: `https://noderpc.strato.nexus/rpc`, `https://app.strato.nexus/rpc` (`eth_chainId` → `0x7030addddcf2`; `net_version` → 33056204878082667)
  - Explorer API (Etherscan format, incl. `getabi`): `https://stratoscan.strato.nexus/api`
  - Cirrus (PostgREST over indexed contract state/mappings/events): `https://app.strato.nexus/cirrus/search/<table>`
  - Bloc / app backend: reads open; `strato_*` RPC namespace blocked on public nodes.
- **Economics:** native unit USDST; flat fee 0.01 USDST/tx; no gas market. Chain has been live since ~2026-04-02 (DefiLlama adapter `start`), currently ~622.7k blocks, TVL stable at ~$16M since the gold-CDP launch (late May 2026 jump $1.1M → $17.6M on DefiLlama).
- **DeFi suite (all owned by one AdminRegistry, see §5):** CDP stablecoin (USDST) with 22 collateral assets, money market (LendingPool/CollateralVault/LiquidityPool), AMM (PoolFactory + stable pools + Uniswap-v3-style PoolV3Factory), savings vault (SaveUSDSTVault), safety module, bot vault, staking (StratoStaking), lock-and-mint bridges to Ethereum/Base/Linea/Robinhood Chain/HyperEVM, tokenized metals (MetalForge → GOLDST/SILVST), prediction markets.

### Corpus provenance of the claim
- `zombie_hunt/ZOMBIE-HUNT-II.md` **L2-23**: `BDEX V3 / STRATO / RocketSwap-Anubis-class | BOT/STRATO/Anubis | $31M / $16M / (large) | gated or unverified; debunks recorded`; **H2-05**: `STRATO $16M unverified native-contract chain`.
- Origin traced to the **DefiLlama protocols list** (matches re-pulled in `raw/llama_protocols_matches.json`):
  - `STRATO` id 7862, slug `strato`, chain **Strato**, category CDP, **TVL $16,190,997.36**, url `app.strato.nexus`, twitter `strato_net`, listed 2026-05-15;
  - `STRATO Bridge` id 8626 ($1,397,710), `STRATO Odds` id 8760 ($936);
  - the sibling row entries are chains, not descriptors: `BDEX V3` = BOT Chain ($31.1M), `RocketSwap Anubis` = Anubis ($383M).
- "Unverified" was the scanner's uncertainty about a then-unknown chain name; it is **not** a gated/private network. BlockApps STRATO Mercata is public (the older "BlockApps STRATO permissioned chain" is a different product context; this deployment is the public Mercata network).

---

## 3. Where the $16.19M sits (fresh reconciliation at block 622,692)

DefiLlama `tokensInUsd` (ts 1791641915): **GOLDST $13,492,627 · USDST $2,006,289 · SILVST $214,952 · ETH $131,241 · WBTC $126,171 · USDC $123,845 · syrupUSDC $41,731 · wstETH $35,750 · rETH $9,128 · sUSDS $4,272 · USDT $4,187 · PAXG $804 = $16,190,997**.

On-chain holder accounting (Cirrus `BlockApps-Token-_balances`, values priced with the chain's own oracle, `raw/value_table.json`):

| Holder | Address | Main contents | Value |
|---|---|---|---|
| CDP vault | `0x…1013` | 3,134.6331 **GOLDST** ($4,184.44 ea) = $13.12M; SILVST 2,613.00 = $158.9k; ETH 50.817 = $127.3k; WBTC 0.9435 = $78.1k; syrupUSDC 34,962 = ~$38.5k; wstETH 11.449; USDTEMP 32,040 = $32k; BETHTEMP 9.285; rETH 3.122; PAXG 0.192 | **≈ $13.62M** |
| SaveUSDSTVault | `0x2255…46ed` | `totalAssets` = 1,706,189.05 USDST | $1,706,189 |
| StratoNativeBridge custody vault | `0xdb96…318f` | STRATO 2,131,645.48 ≈ $1.93M + USDST 25,217.75 + tiny GOLDST/SILVST (bridge-locked; counted in DefiLlama's separate Bridge protocol $1.40M) | ≈ $1.97M |
| DirectMintPSM | `0xb1ef…86f3` | USDC 89,179.76 + USDT 2,065.88 | $91,246 |
| CollateralVault | `0x…1003` | GOLDST 2.15, SILVST 33.44, + dust | $11,093 |
| SafetyModule | `0x…1015` | 2,274.84 USDST | $2,275 |
| LiquidityPool / botExecutor | `0x…1004` / `0x3f5c…2dfb` | 323.14 USDST / ~$5.6k mixed | $5,874 |

**Debt side:** CDP `totalDebtAll` = **4,699,119.41 USDST** (GOLDST-backed 4,564,577.74); lending pool scaled debt ≈ 4,299 USDST; USDST `totalSupply` = **4,973,804.68**. Global CDP collateral ratio ≈ **2.88×** (gold basis). Collateral params (GOLDST): min ratio 150%, liquidation ratio 155%, unit scale 1.0, debt ceiling 10,000,000 USDST, not paused.

**Oracle (0x…1002, admin/whitelist-pushed), fresh at block 622,692:** GOLDST $4,184.44 · SILVST $60.82 · USDST $1.00 · ETH $2,505.91 · WBTC $82,784.81 (timestamps 1791646203–63). DefiLlama cross-check: GOLDST $4,199.10 (conf 1), SILVST $60.83, USDST $0.9991. No anomaly, no staleness for the valued assets.

---

## 4. Governance, roles and upgradeability

- **Owner of every core contract = AdminRegistry `0x000000000000000000000000000000000000100c`** (self-owned; `defaultVotingThresholdBps = 6000` i.e. 60%).
- **Admins (3, all EOAs — `eth_getCode` = `0x`):** `0x7630b673862a2807583834908f10192e00c58b00`, `0x292dd9591f506845ef05a9f3b8116e641cbcb4bb` (= bridge guardian), `0xf1ba16a6cfb2a17fb34ad477eaaf0c76eac64f14`. → **2-of-3 EOA threshold controls all upgrades and params.**
- **Function-scoped whitelist (143 entries on 0x100c, `raw/cirrus_whitelist_100c.json`)** grants non-admin access narrowly, e.g.:
  - oracle `setAssetPrice/setAssetPrices/setExchangeRates/setRebaseFactors` only to **EOAs `0x523fef37…`, `0x96714c4a…`** (price bots);
  - MercataBridge deposit/confirm/finalise only to operator `0x882f3d3a…` (+ guardian for aborts); NativeBridge operator `0x882f3d3a…`, guardian `0x292dd959…`;
  - token `mint/burn` only to system modules (bridge `0x…1008`, CDP engine `0x…1011`, PSM, MetalForge `0x1cc5…`, factories). USDST minters: `0x…1008`, `0x…1011`, PSM, contract `0x390ba7f7…`.
- **Upgradeability:** every contract exposes `setLogicContract(address)` (owner-only). AdminRegistry logic impl `0x52c1abf47bc20109180c0789e811e077ac35dfda`.
- **Pauses:** none active (USDST `paused=false`; LendingPool `paused=false`; PSM mint/burn unpaused; CDP `globalPaused=false`; bridge deposits/withdrawals unpaused; SaveVault/Vault unpaused).
- Other privileged roles: `botExecutor` `0x3f5c7de3…` (EOA, Vault bot), `treasurer`/MetalForge modules.

---

## 5. What an attacker can/cannot do — exact tests (all read-only `eth_call`, sender = random `0x1111…1111`)

**17/17 admin-surface simulations reverted** (`raw/gating_tests_randomsender.json`):

| Attempt | Result |
|---|---|
| `USDST.mint(att,1e18)`, `GOLDST.mint(...)` | revert: *Only an admin or a whitelisted account…* |
| `USDST.setLogicContract/pause/transferOwnership` | revert (admin) |
| `Oracle.setAssetPrice(GOLDST,1e18)` | revert (admin/whitelist) |
| `PSM.pauseMint()` / `setMintEnabled` | revert (admin) |
| `CDPEngine.setPausedGlobal(true)`; `CDPReserve.transferTo(att,1e18)` | revert (admin) / *Reserve: not engine* |
| `LendingPool.pause()`, `PoolFactory.updatePoolImplementation()`, `Staking.setParams(0,0,0,0)`, `SaveVault.setPerSecondSavingsRate(2e18)`, `VaultBot.setBotExecutor(att)` | revert (admin) |
| `MercataBridge.confirmWithdrawal(742,'x')` | revert (admin/whitelist) |
| `NativeBridge.confirmDeposit(1,att,1e18)` | revert: *SNB: not bridge operator* |
| `AdminRegistry.addAdmin(att)` | revert (admin/whitelist) |

**8/8 "free-money" simulations reverted from zero-position callers** (`raw/freemoney_sims.json`): `LendingPool.borrow` → *Insufficient collateral*; `withdrawCollateral` → *Insufficient collateral*; `SaveVault.redeem` → *redeem exceeds max*; `Staking.unstake` → *operator missing*; `SafetyModule.redeem` → *not holder*; `PSM.mint` → *Minting for this token is disabled*; `CDPEngine.mint(GOLDST,1e18)` → *insufficient collateral*; `MercataBridge.requestWithdrawal` → *asset missing*.

**Interpretation:** every value-moving privileged function is gated by (a) the AdminRegistry 2-of-3 admin vote/whitelist, (b) a system contract, or (c) operator roles; the permissionless user flows (deposit/borrow/repay/liquidate/redeem/unstake/swap/bridge-request) all require the caller's own collateral/positions and are standard by design. The oracle is fresh and admin/whitelist-pushed; the CDP is 2.88× overcollateralized; lending badDebt = 0.

**Caveats on the $0 E-U conclusion:** contract *source code is not published* (SolidVM; explorer serves ABIs, not sources), so this is **behavioral** verification (state + gating + ABI surface), not a line-level audit — a logic bug outside the tested call paths cannot be fully excluded. Even if one existed, exfiltration off STRATO depends on operator-confirmed bridges or on-chain DEX exit liquidity.

---

## 6. Classification (amounts at block 622,692)

| Class | Amount (USD) | Notes |
|---|---|---|
| **E-U** (external unprivileged) | **$0.00** | No path found; all privileged ops revert for random callers; free-money sims revert; oracle/CDP healthy. Confidence: medium-high (behavioral, no source). |
| **H-O** (holder-only) | **≈ $10,643,000** | SaveVault redeemable $1,706,189 + CDP net equity (collateral $13.62M − debt $4.70M = **$8,921,703**) + CollateralVault $11,093 + SafetyModule $2,275. Excludes overlapping bridge custody (≈$1.97M, bridge users' claims) and staking (954,505.39 STRATO ≈ $0.86M, tracked separately by DefiLlama; priced vs the Ethereum ERC-20). |
| **P** (privileged) | **whole protocol — TVL $16,190,997 (+ bridge $1,397,710)** | AdminRegistry `0x…100c` = 3 admin EOAs @60% threshold; every contract upgradeable via `setLogicContract`; oracle, mints, pauses, bridges, fee/param control. Whitelisted EOAs: price bots `0x523fef37…`/`0x96714c4a…`, bridge operator `0x882f3d3a…`, guardian `0x292dd959…`, bot exec `0x3f5c7de3…`. |
| **S** (stuck) | **$0.00** | No material stuck funds identified; dust only (DUMMY 2,450.4 in bridge custody; USDTEMP/BETHTEMP are test tokens). |

**Latent risk (single sentence):** the entire $16.2M suite (and $1.4M bridge) is one compromised key away via the 3-admin EOA set (2-of-3) or via the whitelisted price-updater EOA (oracle manipulation → CDP mint/liquidations); both are **P/trust risk, not permissionless extraction**.

---

## 7. Everything tried / negative results (so it is not re-investigated)

1. **Corpus trace:** grep found STRATO only in `ZOMBIE-HUNT-II.md` (L2-23, H2-05, master index) + tracker; provenance resolved to DefiLlama `strato` id 7862 (see §2).
2. **DefiLlama:** `protocol/strato`, `protocol/strato-bridge`, full `protocols` list matched; `hacks: []`, `raises: []`, `audits: 0`; `coins.llama.fi` prices cross-checked. Adapters `projects/strato/index.js` + `strato-bridge/index.js` fetched (methodology + every contract address).
3. **Web/docs:** found STRATOSCAN + docs confirming public RPC/chain IDs; no incident/exploit reports found.
4. **RPC probes:** chainId/net_version/blockNumber/metadata on two independent public nodes — identical, synced.
5. **Explorer API:** getsourcecode **not supported** (ABI-only; `getabi` works for all core contracts — saved in `raw/abis/`); `txlist`/`balance` used; proxy JSON-RPC works.
6. **Cirrus:** storage of AdminRegistry, token metadata, holders' balances, admin/whitelist mappings — all keyed queries succeeded (public, anonymous).
7. **Bloc:** root requires auth for some routes (401); public reads not needed — Cirrus covered state.
8. **Gating + free-money simulations:** 25 read-only `eth_call` simulations, all negative (§5).
9. **Negative/artifacts:** `eth_getCode` returns only `0x01` for contracts (SolidVM) — bytecode-level review impossible; `getsourcecode` unsupported; some `cast` calldata for array args needed the single-asset variant (array encoding caveat) — single-asset gating proved the oracle gate.

## 8. Files index (this folder)

- `fetch_evidence.py` — reproducible read-only fetch script (all endpoints public/keyless).
- `raw/rpc_probes.json`, `raw/snapshot_block.json` — chain identity + block 622,692.
- `raw/llama_protocol_strato.json`, `raw/llama_protocol_strato_bridge.json`, `raw/llama_protocols_matches.json`, `raw/llama_prices_strato.json` — DefiLlama evidence.
- `raw/adapter_strato.js`, `raw/adapter_strato_bridge.js` — DefiLlama methodology/addresses.
- `raw/state_components.json`, `raw/cdp_params.json`, `raw/oracle_reads.json` — live protocol state.
- `raw/cirrus_holder_balances.json`, `raw/cirrus_token_meta_full.json`, `raw/value_table.json` — value reconciliation.
- `raw/cirrus_admins_100c.json`, `raw/cirrus_whitelist_100c.json`, `raw/code_types.json` — governance/roles.
- `raw/gating_tests_randomsender.json`, `raw/freemoney_sims.json` — the 25 permissionless-path tests.
- `raw/abis/*.json` — ABIs for all core contracts (explorer API).
- `state.json` — machine-readable summary.

**Caveats:** point-in-time reads (block 622,692); USD values use the chain's own oracle + DefiLlama prices; tokenized-metal (GOLDST/SILVST) valuation ultimately relies on issuer/Mercata custody and redemption, and GOLDST is largely chain-native (DefiLlama's confidence 1 pricing + on-chain oracle agree within ~0.4%). No mainnet state was modified in any way.
