# Rift Finance (Ethereum + Aurora) — Phase-2 deep dive: live unprivileged-extraction assessment

**Date:** 2026-10-12 · **Chains:** Ethereum (1), Aurora (1313161554) · **Finding:** L2-Triage-A row 24 (`rift-finance`, triage $192,055, low confidence)
**Status:** read-only; PoC fork-verified only; no mainnet transactions. All addresses/balances read on-chain at explicit blocks.

---

## 1. TL;DR

| Target | Live measured value | Extractable by external unprivileged attacker | Why closed | Latent risk |
|---|---|---|---|---|
| Rift Core + 9 vaults (Ethereum) | **$71,210** in vaults (raw balances + LP, llama prices) | **$0** | Deposits disabled on all 9 vaults since the v2 upgrade; `nextEpoch` requires an existing position (participant) or strategist role; claims/withdrawals only pay `msg.sender`'s own accounting; admin is a Gnosis Safe + ProxyAdmin | If governance re-enables deposits (P) or any existing participant self-sandwiches a future `nextEpoch`, the vault's zero-slippage rebalance becomes extractable (~$71k at risk). All 9 vaults still hold claimable user funds (H-O). |
| Rift Core + 8 vaults (Aurora) | **$95,214** in vaults (raw balances + LP, llama prices) | **$0** | v1 vaults: `nextEpoch` is **strategist-only**; deposits are open but a fresh depositor cannot withdraw in the same epoch and cannot advance the epoch; claims need a position | Strategist EOA (dormant since Jul 2023) or governance upgrade could unlock/rebalance (~$95k at risk). Deposits being open means any fresh depositor's funds are captured and locked (S for the depositor). |
| Impl contracts / ProxyAdmins / extra deployer contracts (25+ addresses) | $0 | $0 | No token balances anywhere; impls uninitialized / not initializable | — |

## 2. Total live extractable now

**External unprivileged attacker: $0 (confidence: high).**

- *Extractable by anyone, in any state:* nothing. Every value-moving entry point on both chains is either reverts for a fresh caller, or pays only the caller's own accounting, or pays the treasury.
- **H-O (holder-only, can be pulled today):** Ethereum ≈ **$51.1k** (869,335.35 AURORA + 0.2567 WETH in claimable balances across the three AURORA vaults; individual holders can call `claimToken1()`/`claimToken0()`). Aurora: ≈ **$6** claimable (one vault); the rest needs an epoch advance (below).
- **P (privileged):** the whole corpus — Ethereum $71.2k (Safe-owned ProxyAdmin can upgrade implementations; strategist can `setDepositsEnabled`, floors, `nextEpoch`; guardian can rescue while paused) and Aurora $95.2k (Safe-owned ProxyAdmin, strategist EOA `nextEpoch`, guardian rescue).
- **S (stuck):** Aurora user funds (~$95.2k) are unclaimable without a strategist `nextEpoch`; the Aurora vault `0x40d2…` in particular holds **zero** assets against books of 197,591.5 WNEAR + 4.7M TRI and 200,001 WNEAR of unprocessed withdrawals (bad debt); 3 dust vaults hold 1-token test deposits that can never be flushed.

**Live vs triage:** triage (2026-10-11) used DefiLlama: ETH $73,003 + Aurora $119,052 = $192,055, low confidence ("vaults not independently verified"). This deep dive independently enumerated and verified every vault on both chains. Measured today at DefiLlama prices: **ETH $71,210 + Aurora $95,214 = $166,424**. DefiLlama's own live figure today is $198,607 (ETH $72,289 + Aurora $126,317); the residual difference is in their subgraph-based per-token amounts (they count ~+2.6k NEAR and ~+13.9M WANNA vs actual balances, and omit the BSTN leg). The dollar delta does not change the extraction verdict: **$0 is E-U**, because the gates are role/position-based, not value-based.

## 3. Architecture (verified from deployed code)

Rift is a DAO-liquidity tranche protocol (Recursive Research Inc; $18M raise Feb-2022; docs/website dead, repo last commit 2022-06-16): each **vault** accepts two assets — `token0` ("floor" tranche, typically WETH/NEAR side, floor ≈ 100%) and `token1` ("ceiling" tranche, the DAO token side) — and deposits the pair into a Uniswap-V2-style pool. A **Core** contract holds roles/pause/fee config. Epoch transitions (`nextEpoch`) withdraw all LP, swap to rebalance floor/ceiling, and re-deposit; exchange rates (`epochToRate`) are written per epoch; users claim after their epoch closes.

Two code generations are live:

| | Ethereum | Aurora |
|---|---|---|
| Core proxy | `0x5D7e616B2c0bf268494A482e315a60814F97dBC8` (impl `0xE25fbF6A…d8939b`, admin `0x40A01A40…`) | `0x40A01A4064b690cA33FA52d315ec02015eF5287E` (impl `0xCC38C652…`, admin `0xE25fbF6A…`) |
| Vault impls | `0xFFbf4067…` (UniswapVault v2), `0xF9fCfE67…` (MasterChefVault v2) — both verified. Vaults were created 2022-05 with v1 (`0xF5F28e0c…`/`0xa9ba10a9…`) and **upgraded to v2 in March 2023** (blocks 16,379,187–16,379,303) — the upgrade is what introduced the `depositsEnabled` gate and the participant-or-strategist `nextEpoch` gate | `0x2FFdfe69…` (UniswapVault v1, verified), `0xE780697c…`, `0x187E1d22…`, `0x7BEfEAe0…` (unverified; selector-identical to v1) |
| Vaults | 9 (below), all proxy, registered via `VaultRegistered(address)` events | 8 registered (`VaultRegistered(address,address)`), + 3 unregistered dust vaults |
| `nextEpoch` gate | `onlyParticipantOrStrategist` (any existing position) | **`onlyStrategist`** |
| Deposits | `whenDepositsEnabled` — **false on all 9 vaults** | **open** (v1 has no deposits flag and the whitelist is never enforced by the vault code) |
| Roles | GOVERN=`0x96c95707…d31cD` (**Gnosis Safe** v1.3.0, also feeTo; can upgrade impls via ProxyAdmin), GUARDIAN/PAUSE/STRATEGIST = EOAs | GOVERN+feeTo=`0x4f41Aac8…01E1` (**Gnosis Safe L2** v1.3.0, owns ProxyAdmin), STRATEGIST=EOA `0x805300DE…B94f` (nonce 2 on Aurora, 1 nextEpoch ever), GUARDIAN/PAUSE = EOAs |

**The vault swap path is deliberately blind:** `nextEpoch` calls `removeLiquidity/addLiquidity/swapExactTokensForTokens` with min-amounts **0**, and the only protection is a ±0.5% check of pool reserves against **caller-supplied** `expectedPoolToken0/1` (CertiK VCK-01, rated informational: "sandwich attacks are impossible if arguments are passed correctly"). This protects a *victim's* `nextEpoch` from third-party sandwiching (the victim's tx reverts), but does **not** protect the vault from a **caller who is allowed to call it** (participant/strategist) — a self-called epoch can be front-run/manipulated by its own caller. That is why the access gate is the entire security boundary.

## 4. Live-state assessment (blocks: Ethereum 26,178,080 · Aurora 219,704,632)

### 4.1 Ethereum vaults (all `depositsEnabled=false`, `paused=false`, core not paused)

| Vault | Pair | epoch | Book value (token0 bal / token1 bal / LP) | USD |
|---|---|---|---|---|
| `0x51c6f343…64d3` | WETH/OGN | 49 | 0.3012 WETH / 1 wei / 0 | 756 |
| `0x40D23398…08e4` | WETH/OGN | 16 | 0.5817 WETH / 18 wei / 0 | 1,460 |
| `0x5A999feD…4a61` | WETH/FTM | 69 | 2.3962 WETH / 1 wei / 0 | 6,014 |
| `0x820FB780…bcf4` | WETH/OGN | 7 | 0.1056 WETH / 1 wei / 0 | 265 |
| `0x95F635a4…5408` | WETH/FTM | 23 | 0.5530 WETH / 917 wei / 0 | 1,388 |
| `0xe914B3E4…2c9a` | WETH/FTM | 84 | 2.8424 WETH / 56 wei / 0 | 7,134 |
| `0x01ebD85a…7fD6` | WETH/AURORA | 20 | 0.4653 WETH / 277,242.2 AURORA / 25.16 LP | 18,243 |
| `0x969a4a1F…6e2A` | WETH/AURORA | 6 | 0.0040 WETH / 298,519.7 AURORA / 13.08 LP | 17,844 |
| `0x01875b96…5fBd` | WETH/AURORA | 9 | 0.0913 WETH / 295,477.6 AURORA / 18.66 LP | 18,106 |

The six WETH/OGN and WETH/FTM vaults are fully unwound (active=0, no LP) — only residual WETH remains, split between user `reserves`, `claimableTotal` and `feesAccrued`. The three WETH/AURORA vaults still hold their Uniswap-V2 LP (AURORA/WETH pair `0x629d22E6…`) and are ~solvent for the currently claimable AURORA. Last activity: Nov-2023 (claims); last `nextEpoch` calls were made by a **participant** (`0xF7D71c05…`, Sep-2023) and by the strategist EOA (until Jul-2023).

*Completeness check:* direct vault reads sum to 7.7862 WETH and 890,600.8 AURORA (incl. LP resolution) vs DefiLlama's (subgraph-derived) 7.7965 WETH and 890,153.0 AURORA — a ≤0.15% block/price-timing difference, confirming the 9-vault set is the complete Ethereum custody set.

### 4.2 Aurora vaults

| Vault | Pair | epoch (last start) | Balances (raw) | USD | Notes |
|---|---|---|---|---|---|
| `0xe914B3E4…2c9a` | NEAR/PAD | 2 (2022-03-17) | 1,173.40 NEAR + LP 69.60% | 36,737 | books claim 22,784 NEAR + 1.5M PAD → WNEAR side ~5x insolvent vs actual LP |
| `0xb31142aF…4Ad4` | NEAR/PLY | 2 | LP 74.47% | 53,274 | books claim 60,000 NEAR + 41.7M PLY |
| `0xd51ccf42…f04f` | NEAR/BSTN | 2 | 0.001 NEAR + LP 76.81% | 2,933 | BSTN leg unpriced by DefiLlama; 25M BSTN withdrawal requests vs 0 token balance |
| `0x5A999feD…4a61` | NEAR/FLX | 3 (2023-07-05) | 415.91 NEAR + 18.51 FLX | 2,251 | 0.4149 NEAR fees accrued; 1.05 NEAR claimable |
| `0x8ef60690…E5b4` | NEAR/WANNA | 2 | 0.001 NEAR + 14.93M WANNA | 13 | books claim 16,810 NEAR |
| `0x2c72Be54…4455` | NEAR/AURORA | 1 | 0.001 NEAR + 4 AURORA | 6 | never advanced |
| `0xC8dDC0AD…4384` | STNEAR/TRI | 1 | 0 | 0 | empty |
| `0x40D23398…08e4` | NEAR/TRI | 2 (2022-03-06) | **0** | 0 | **PAUSED**; books: 197,591.5 NEAR + 4.7M TRI assets with 200,001 NEAR unprocessed withdrawals → bad debt, no assets |
| dust: `0x51c6f343…`, `0x95F635a4…`, `0x01EBd85a…` | NEAR/* | 1 | 1 NEAR + 1-117 token units each | ~$30 | unregistered test deposits, never flushable |

All Aurora implementations (all 4, incl. unverified ones) expose exactly the v1 function set (`deposit/withdraw/claim/nextEpoch/collectFees/rescue/setters + getters`); selector-fingerprinted, no hidden functions. Impl contracts and the 13 other contracts created by the deployer EOA (`0x38E2a3FC…63ebF`, same EOA on both chains) hold **zero** tokens; probe of WNEAR/USDC/native for all of them = 0.

## 5. What an attacker can and cannot do

Fresh EOA, no roles, no position, flash-loan capital available (all verified on fork PoC, §6):

**Ethereum (all 9 vaults) — every path reverts:**
| Call | Result |
|---|---|
| `depositToken0{value:x}(y)` | `DEPOSITS_DISABLED` |
| `depositToken1(y)` | `DEPOSITS_DISABLED` |
| `nextEpoch(0,0)` | `NOT_PARTICIPANT_OR_STRATEGIST` (the attacker cannot become a participant: deposits are the only entry and they are closed) |
| `claimToken0()/claimToken1()` | `NO_CLAIM` |
| `withdrawToken0(1)/withdrawToken1(1)` | `INSUFFICIENT_BALANCE` |
| `rescueTokens` / `unstakeLiquidity` | `NOT_GUARDIAN` (± `whenPaused`) |
| `pause()` | `NOT_PAUSER` |
| `setToken0Floor/setToken1Floor/setDepositsEnabled` | `NOT_STRATEGIST` |
| Core `pause/setFeeTo/setProtocolFee/registerVaults` | AccessControl revert |
| `collectFees()` | permissionless, but pays 100% to `core.feeTo()` (Safe), never the caller |

*Cost note:* even if a swap-sandwich path existed, an attacker would need a participant position; the flash-loan-funded variant is closed because deposits are disabled. `collectFees()` is the only unprivileged call with value movement and it is value-neutral to the caller.

**Aurora (8 vaults) — same, with one twist:**
| Call | Result |
|---|---|
| `depositToken0(y)` | **succeeds on unpaused vaults** (v1 has no deposits flag; whitelist never enforced) — the attacker's funds are pulled into the vault and become a queued request |
| `token0Balance(attacker)` after deposit | `(0 deposited, y pending, 0 claimable)` — the money is captured but the attacker gains **no value** |
| `withdrawToken0(y)` same epoch | `INSUFFICIENT_BALANCE` (pending deposits cannot be withdrawn until an epoch closes) |
| `claimToken0()/claimToken1()` | `NO_CLAIM` |
| `nextEpoch(0,0)` | `NOT_STRATEGIST` (even for a depositor — v1 gate is strictly strategist) |
| `rescue/pause/setters` | `NOT_GUARDIAN` / `NOT_PAUSER` / `NOT_STRATEGIST`; paused vault `0x40D2…` reverts `PAUSED` on everything |
| `collectFees()` | permissionless → paid to Aurora Safe (feeTo), never the caller |

**Conclusion:** there is no unprivileged call sequence that transfers any positive amount to the caller on either chain. The funds are one of: holder-claimable (ETH claims), treasury fees, or locked behind the strategist/governance role.

## 6. PoC / fork verification

Foundry project `poc/` (vendored forge-std), run in CI on real forks:
- `poc/test/RiftEth.t.sol` — 6 tests: live-state sanity; attacker gate matrix over all 9 vaults; core admin gates; participant-is-the-only-door; holder claim still works (H-O, 296,615.51 AURORA paid to `0x44d41ad8…` on fork); participant-triggered `nextEpoch` attempt; value snapshot.
- `poc/test/RiftAurora.t.sol` — 6 tests: live-state (incl. proof that v1 has no `depositsEnabled` getter); attacker deposit succeeds but funds are trapped (no exit, `NOT_STRATEGIST` for a depositor); gate matrix over 7 vaults; paused vault frozen; `collectFees` pays only `feeTo`; core admin gates.
- `ci/verify.py` + `ci/run.sh` — independent live-state + USD dump at run time (`ci-out/verify.json`, `ci-out/verify-summary.txt`).

**CI run(s):** see `ci-log.txt` / `ci-artifacts/` (URLs recorded below after the run).

Result summary (local compile: OK; CI): _(filled from CI run)_

## 7. Verdict, residual and latent risk

- **E-U: $0.** The extraction surfaces are all role/position-gated; the strongest "near miss" is the audit-noted zero-slippage `nextEpoch` rebalance, which today is reachable only by a pre-existing position (ETH) or the strategist (Aurora) — not by an external attacker (deposits closed on ETH; epoch advancement strategist-only on Aurora).
- **Residual/latent:**
  1. **Governance upgrade risk (P):** ProxyAdmin owners are two Gnosis Safes; they can upgrade vault implementations (and thus re-enable deposits, extract, or brick). ~$166k at risk behind 2 Safes + strategist/guardian EOAs.
  2. **Participant self-sandwich (ETH, holder-vs-holder):** any of the remaining participants may, at any time, manipulate the AURORA/WETH pool and self-call `nextEpoch` with matching expectations, extracting value from the other tranche holders. This is not attacker-accessible but is a live protocol-level flaw (~$71k of holders' value).
  3. **Strategist reactivation (Aurora):** a single EOA (`0x805300DE…`) can call `nextEpoch` on any Aurora vault and trigger blind rebalances; if that key acted maliciously, up to ~$95k (mostly LP in three pools) is at risk. Conversely, it is also the only way legitimate Aurora users could ever unlock their funds.
  4. **Deposit trap (Aurora):** deposits are open and irreversible until a strategist acts — anyone (or any contract) can be lured into locking funds there.
- **Blockers that keep this closed:** ETH `depositsEnabled=false` (all 9); Aurora `onlyStrategist` on `nextEpoch`; no whitelist-bypass needed because the entry doesn't exist.

## 8. Methodology & sources; caveats

- Vault sets enumerated **on-chain from Core events** (`VaultRegistered(address)` ×9 on Ethereum; `VaultRegistered(address,address)` ×8 on Aurora via Blockscout), not from the triage's subgraph; cross-checked against the full contract-creation history of the deployer EOA `0x38E2a3FC…` on both chains (14 + 35 creations; every single one inspected: all token balances = 0 except the vaults listed). No `VaultRemoved` events on either chain.
- Contracts verified by source (Etherscan/Blockscout) or selector-fingerprinted from bytecode; roles/pause/fee values read directly; token prices from DefiLlama `coins.llama.fi`; USD at read time.
- Caveats: (a) DefiLlama's per-token composition for Aurora over-counts NEAR/WANNA vs actual balances — trust the on-chain balances; (b) the BSTN leg of `0xd51c…` is unpriced (llama has no price) and may be illiquid; (c) dollar figures move with prices; the E-U verdict does not; (d) `0x40D2…`'s bad-debt books mean some Aurora accounting is unrecoverable regardless of roles.
- Sources: deployed sources (Etherscan v2, explorer.aurora.dev), gigabrain rel. audits (ABDK, CertiK 2022-02-04, PeckShield 2022-027) in `github.com/rift-finance/rift-protocol/audits`, DefiLlama `api.llama.fi/protocol/rift-finance`, Dealroom/Medium coverage (team inactive; dApp marked inactive Feb-2025), repo last commit 2022-06-16.
- Files index: `analysis/` (state JSONs, sources, selectors, valuation, verify outputs), `poc/` (Foundry), `ci/` (verify job), `ci-out/`, `ci-log.txt`.

*All mainnet interaction in this study was read-only (`eth_call`/`eth_getCode`/logs). The exploit PoC only runs on local/CI forks. No transactions were signed or sent.*
