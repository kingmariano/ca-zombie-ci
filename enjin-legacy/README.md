# C2-23 — Enjin legacy CryptoItems (Ethereum): live extractability after the Aug-25-2026 adapter takeover

**Campaign:** zombie-hunt II · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-09
**Status:** read-only research; all PoCs fork-verified only (local + GitHub Actions). No mainnet transactions were signed or sent.
**Targets:** platform adapter (PA) `0xfaaFDc07907ff5120a76b34b731b278c38d6043C`; eternal-storage Adapter `0x4E643a25a64952895f553f20252861258727174e`; Managed proxy templates `0x13fA4b9a6C2F2604C919f96F456e3B50E968b157` (NFT) / `0x268C039A3127D3107c014F0DC6c390A53e6dB27f` (FT).
**Latest state block:** `26,152,522` (2026-10-09 ~05:40 UTC) unless stated; incident block `25,834,071`; lock block `25,835,670`; PA-mitigation block `25,853,511`.

## TL;DR

| # | Question | Answer | Why |
|---|---|---|---|
| 1 | Can a **new external unprivileged attacker** take over the platform manager today? | **No** | The slot-collision route (`initialize(uint256)` → `pendingManager`) is replaced by a revert stub (`"locked"`); `acceptManager()` needs a non-zero `pendingManager` (0); `transferManager`/`updateContract` are manager-only (manager = attacker contract). |
| 2 | Can a new attacker reuse the attacker's **still-registered malicious adapter**? | **No** | Both steal selectors are gated `require(msg.sender == 0x7083Ddec…)` → `"only pwn"`; the attack contract's own write functions are `owner`-gated to the attacker EOA. |
| 3 | Can a new attacker **register/deploy** a crafted adapter? | **No** | `updateContract` is manager-only (`"Sender is not manager."`); PA's `deployAdapter` (0x33d332ab) was **zeroed by Enjin at block 25,853,511** (`"Function does not exist."`). |
| 4 | Can a new attacker move items through the **gateways**? | **No** | PA routes `0x41c1df0e` / `0xf95d7da3` were zeroed by Enjin at block 25,853,511; direct module calls and forged-shell calls revert. |
| 5 | Can anyone **melt** remaining items (holder redemption)? | **No — frozen** | The Adapter was **globally locked by Enjin at block 25,835,670** (tx `0xe7f2d0a3…`); proven: the same holder+item melt sim succeeds at block 25,834,070 and reverts at latest. |
| 6 | Is the residual value reachable by the original attacker / operators? | **Privileged-only** | Manager of the Adapter = Enjin contract `0xE5cb0C8E…` (`globalUnlock`/`releaseERC20`); PA manager EOA `0x1421d753…` can repoint routes. |

**Total live extractable by an external unprivileged attacker now: $0** (confidence: **high**).
Residual locked in the Adapter reserve: **3,272,608.45 ENJ ≈ $100,880.56** (DefiLlama ENJ $0.030826 at 2026-10-09), currently **frozen (S)** and releasable only by the privileged Adapter manager (**P**). If the operator unlocks *and* re-enables the gateways without dealing with the compromised templates, the original attacker's contract (still the templates' manager, malicious adapter still registered) could resume stealing — new attackers still could not.

---

## 1. The platform, exactly

```
                        PA 0xfaaFDc07…043C  (facade; hardcoded manager selectors + routed table)
                        ├─ hardcoded: getManager 0xd5009584, acceptManager 0x48ff15b3,
                        │              pendingManager 0x7457bbf7, removeManager 0x8d0a3a08,
                        │              transferManager 0xba0e930a, delegates(bytes4) 0xa0a2daf0
                        ├─ routed (key = keccak(selector‖0‖uint256(2)) → impl, delegatecall):
                        │     0x684811e5  ERC-1155 reads/approval (balanceOf …)
                        │     0x68ee930e  CryptoItemsAdapters: 0x33d332ab deployAdapter,
                        │                 0x41c1df0e NFT gateway, 0xf95d7da3 FT gateway, 0xddeadbb6 getAdapter
                        │     0x1b73f458  CryptoItemsUsers (21 selectors incl. 0xf6089e12 melt)
                        │     0x553f1e22  melt dispatcher, 0xd257ea24 / 0xc6bc3e5f / 0x9a67aef2 melt sub-modules
                        │     0x04866013  updateContract(address,string,string)  (manager-only mutator)
                        └─ slot6 = Adapter 0x4E643a25…174e

                        Adapter 0x4E643a25…174e  (eternal storage)
                        ├─ item ledger + per-item config (meltValue etc.) + ENJ reserve
                        ├─ reserve now: 3,272,608.45 ENJ  (was 9,852,235.68 pre-incident)
                        ├─ manager: 0xE5cb0C8E160C5aC4669D1dfD689Df01bA9eea3eB (Enjin contract)
                        └─ isGlobalLocked() == true since block 25,835,670

                        Managed proxy templates 0x13fA…b157 (NFT) / 0x268C…d27f (FT)
                        ├─ slot0 manager, slot1 pendingManager, slot2 delegates mapping
                        ├─ fallback → delegates[msg.sig] (delegatecall); native mgmt selectors shadow the table
                        └─ per-base-type "shell" contracts (all 395 were created by the attacker's sweep)
```

The platform is Enjin's legacy ERC-1155 "Crypto Items" economy: items are backed by ENJ at mint time and can be melted to redeem the backing from the Adapter reserve. Item transfers route through per-item shells; the shells look up their implementation per selector in the shared templates' `delegates` tables.

## 2. The exploit, exactly (reproduced end-to-end on a fork)

1. **Storage-slot collision.** Templates route `initialize(uint256)` (0xfe4b84df) to the item-adapter implementations `0x24591e79…` (NFT) / `0x75512f84…` (FT). Those implementations keep their own layout (`slot1 = _ownerOf`, `slot2 = _totalSupply`) and have an unauthenticated `initialize(uint256)` whose guard `require(_totalSupply == 0)` reads the proxy's slot2 (mapping base = 0 → always passes). Calling `NFT_TEMPLATE.initialize(1)` therefore writes **the caller's address into the proxy's slot1 = `pendingManager`**.
2. **Takeover.** The caller then invokes native `acceptManager()`: `require(msg.sender == pendingManager)` → `manager = msg.sender`. At the incident the displaced pending manager was Enjin's in-flight handover target `0xE5cb0C8E…`.
3. **Route poisoning.** As manager, `updateContract(address,string,string)` (0x61455567) rewrites the shared table: attacker registered `stealNFT(address,address,uint256)` (0x6453dcf6) → their adapter `0x99294e5e…` on the NFT template and `transferFrom(address,address,uint256)` (0x23b872dd) → the same adapter on the FT template; also replaced `initialize` and `acceptManager` with revert stubs (`0x73497e1c…`, `0x6561d8a6…`) to lock out competitors.
4. **Shell abuse.** `PA.deployAdapter(baseType,…)` lazily creates a shell (permissionless); calling `shell.stealNFT(victim, attacker, id)` makes the shell DELEGATECALL the attacker's adapter, which calls the PA NFT gateway `0x41c1df0e(operator, victim, attacker, id)` **as the shell** — satisfying `require(getAdapter(baseType) == msg.sender)` — and reassigns the ledger owner with **no approval from the victim**.
5. **Melt.** `PA.melt([id],[1])` burns the item and releases its ENJ backing from the Adapter reserve to the new "owner".

**Incident numbers (verified on-chain):** the headline tx `0xd4a382da03c99ce3084661b913b50b525a4b283f66f510bcf1040152830b2a7e` (block 25,834,071) moved 5,238,353 ENJ (5,231,353 net to the attacker + 7,000 creator fees); across the whole 2-day campaign the reserve paid the attacker contract **6,453,855.47 ENJ** (500 log entries, blocks 25,834,071–25,834,440, Etherscan logs). The attacker swept 15,163 item ids from ~4,603 addresses (census, partial window); 60 of their 714 txs failed; the attack contract `0x7083Ddec…` still **owns** (owner = `0x5ec1BA78…`, now 0 ENJ / 0.000128 ETH) and remains the templates' manager.

## 3. Enjin's response (this is what closes the class)

| Block | Action | Evidence |
|---|---|---|
| 25,835,670 | **`globalLock()` on the Adapter** — EOA `0x0c49daa5…` calls `lockStorage()` (0x12371416) on the Adapter's manager contract `0xE5cb0C8E…`, which calls `Adapter.globalLock()` (0x8e1f81bb) | tx `0xe7f2d0a3b90250adcbba7f0a82900d20510ba5584a47aa8aafe9869a25e81c27`; Adapter event `0xd8d7d71f…(true)`; `isGlobalLocked()` false at 25,835,000 / true at 25,835,670 |
| 25,853,511 | **`updateContract(address(0), …)` on PA** zeroing `deployAdapter` (0x33d332ab), `transferFungiblesFromAdapter` (0xf95d7da3), `transferNonFungiblesFromAdapter` (0x41c1df0e), `setApprovalForAllAdapter` (0xfed9dc6a) | tx `0x2d92aed4d9a7147ba6588e329b25a9ffcb66278bf939eeaf534d7697cf60a57e`; 4 `UpdateContract` events with new=0; all four selectors now revert `"Function does not exist."` for every caller |

The global lock freezes all transfers **and** melts (my bisection: the same holder melt sim succeeds at 25,834,440 and fails from 25,835,670 on). The PA route zeroing removes the shell factory and both gateways even for the compromised manager. Net effect: **the attacker's manager rights became useless, but so did legitimate holder transfers and redemptions.**

## 4. Live-state assessment (block 26,152,522 unless stated)

| Check | Value | How |
|---|---|---|
| NFT/FT template manager | `0x7083Ddec…` (attacker contract; owner `0x5ec1BA78…`) | `getManager()` / `owner()` |
| pendingManager (slot1) | `0` | `vm.load` |
| `initialize(1)` via templates | revert `locked` | fork test 02 |
| `acceptManager()` / `transferManager` / `updateContract` (templates) | revert `Managed: Sender must be the new manager` / `Managed: only manager` / `Sender is not manager.` | fork test 02 |
| Malicious adapter registrations | NFT `0x6453dcf6`→`0x99294e5e…`; FT `0x23b872dd`→`0x99294e5e…` — **still present** | `delegates(bytes4)` |
| Calling them via shells | revert `only pwn` | fork test 03 |
| PA `deployAdapter` / gateways | revert `Function does not exist.` | fork test 04, CI probes |
| Adapter direct writes (`0x95760fb9`, `0x7843e5dd`) | revert (not approved) | fork test 04 |
| `isGlobalLocked()` | **true** (since 25,835,670) | fork tests 04/07 |
| Holder melt (live item, real EOA holder) | **reverts now; succeeded at 25,834,070** | fork test 07 |
| Adapter reserve | **3,272,608.45 ENJ** ($100,880.56 @ $0.030826) | `balanceOf` |
| Platform activity | **0 logs from PA in the last 100,000 blocks** | `eth_getLogs` scan |
| Census | 395 shells (391 NFT / 4 FT), all attacker-created; 92,245 NFT instances minted ever; **≥952 live items found in sampled classes** (55 shelled + 863 non-shell NFT + 34 FT balances; 4,603 swept victims) | `analysis/census/` |

## 5. What an attacker can / cannot do

**Can (unprivileged, today):** nothing that moves an item or releases ENJ. Every formerly-open call path was exercised in `poc/test/EnjinLegacy.t.sol` and reverts at a named gate (§7). The only unprivileged write still possible on the templates is calling the attacker's inert installer through a shell (`test_06`) — it writes shell-local storage and grants nothing.

**Cannot:**
1. Take over manager (locked stub + zero pendingManager).
2. Reuse the still-registered malicious adapter (caller-gated to the attacker contract, whose own functions are `owner`-gated).
3. Register or deploy any adapter (manager-only + PA route zeroed).
4. Move items through the gateways (routes zeroed; direct module calls fail; shell forgery fails the `getAdapter==msg.sender` check).
5. Melt any item (Adapter globally locked; even owners revert).
6. Write the Adapter ledger or release reserve ENJ directly (approved-caller gate; random calls revert).

**Privileged / operator (P):** the Adapter manager `0xE5cb0C8E…` can `globalUnlock()` and `releaseERC20()`; the PA manager EOA `0x1421d753…` can repoint any routed selector (that is how the mitigation was done). Both are Enjin-controlled.

**Latent (worth monitoring):** the templates' manager is permanently the attacker contract (the lock stubs cannot be undone), and the malicious adapter registrations persist. If the operator unlocks the Adapter **and** re-enables the PA gateways without first dealing with the compromised tables, the **original attacker** (only them — "only pwn") could resume stealing; legitimate transfers would also resume, and holders could melt.

## 6. Value categories

| Category | USD | Note |
|---|---|---|
| **E-U — external unprivileged attacker** | **$0** | all paths closed (7 fork tests + two independent audits) |
| **H-O — holder self-service** | **$0 today** | frozen by the global lock; redeemability pre-lock proven (`test_07a`). If the operator unlocks, holders can melt their items (up to the reserve) |
| **P — privileged/operator** | **$100,880.56** | the reserve itself; releasable by the Adapter manager (`globalUnlock` + `releaseERC20`); PA manager can repoint routes |
| **S — stuck/bricked** | **$0** (strict) | not bricked: the manager can unlock; currently frozen for everyone unprivileged |

## 7. PoC / fork verification

`poc/` (Foundry, solc 0.8.24, vendored `lib/forge-std`), `poc/test/EnjinLegacy.t.sol`, `poc/src/MaliciousShellLogic.sol`:

| Test | What it proves | Result |
|---|---|---|
| `test_01_historical_repro_fresh_attacker` | Fork @25,834,070: a **fresh zero-privilege attacker** does the whole chain — `initialize(1)` → `acceptManager` → `updateContract` → shell deploy → unauthorized `stealNFT` → `melt` and receives **3,000,000 ENJ** (gas 721,843). Harness validated against the real incident. | PASS |
| `test_02_takeover_closed_at_latest` | `initialize` → `"locked"`; `acceptManager` → guard revert; `transferManager`/`updateContract` → manager-only; manager still attacker, pending=0. | PASS |
| `test_03_malicious_adapter_reuse_closed_at_latest` | NFT `stealNFT` and FT `transferFrom` routes still point to `0x99294e5e…` but revert `"only pwn"`; attack contract `owner()` = attacker EOA; `sweep()` reverts. | PASS |
| `test_04_direct_paths_closed_at_latest` | `isGlobalLocked()==true`; PA gateways and `deployAdapter` revert `"Function does not exist."`; direct Adapter ledger write + reserve release revert; melt by non-owner reverts. | PASS |
| `test_05_residual_state_snapshot` | manager/owner/reserve/attacker balances printed and asserted (reserve 3.2726M ENJ; attacker wallets empty). | PASS |
| `test_06_shell_installer_is_inert_at_latest` | the residual installer can be invoked through a shell but writes only shell storage; a subsequent melt still fails. | PASS |
| `test_07a_holder_melt_was_live_pre_incident` | a live holder + live item melt **succeeds** at block 25,834,070 (pays the item's backing). | PASS |
| `test_07b_holder_melt_frozen_at_latest` | the same holder+item melt **reverts** at latest (Adapter globally locked). | PASS |

CI runs (GitHub Actions, public `kingmariano/ca-zombie-ci`): see `ci-links.md` / `summary.json` — `ci/run.sh` re-captures the live state (manager, reserve, registrations, revert probes) into `ci-out/live_state.json`; `forge test -vvv` runs all 7 tests.

## 8. Verdict and residual risk

* **Verdict:** the class is closed. An external unprivileged attacker can extract **$0** today: the takeover is locked, the residual malicious adapter is caller-gated, the PA adapter entry points are zeroed, and the Adapter is globally locked. The residual 3,272,608.45 ENJ ($100,880.56) is frozen and only the Enjin-controlled Adapter manager can release it. Confidence: **high** (fork-proven closures + independent delegate-table and PA/Adapter audits).
* **Residual/latent:** (i) the templates remain under the attacker contract's manager control forever — do not re-enable gateways without replacing the templates; (ii) the PA manager EOA is a single key (`0x1421d753…`) that can repoint selectors — key-compromise risk; (iii) the Adapter manager contract `0xE5cb0C8E…` can unlock/release — operator discretion.
* **Blockers for attackers:** global lock, zeroed routes, `only pwn`/manager/owner gates, approved-caller gate on the Adapter.

## 9. Methodology, sources, caveats, files

* **Method:** incident tx + full callTracer trace (`eth.drpc.org`); receipt logs; Etherscan V2 logs/txlist (full-range, paginated); archive `eth_call` simulations for melt/gateway/registration probes at exact blocks; `debug_traceCall` (callTracer/prestate) diffs to locate the melt freeze; heimdall decompilation/disassembly; independent child audits of (a) the full `delegates` tables and (b) the PA/Adapter module surface; Foundry fork tests (local + CI).
* **Sources:** SlowMist TI alert; yinhui1984 "Enjin CryptoItems Attack Analysis" (mechanism + reference PoC); oculr report `0xd4a382da…`; cryptotimes/KuCoin/Gate/CoinNess coverage (all linked in `analysis/incident/incident_summary.md`).
* **Caveats:** USD uses DefiLlama ENJ $0.030826 at 2026-10-09 (the incident figure ~$142k was at ~$0.0275); the census covers 395 shells fully for first-25 indices + ~10 tail samples per large shell (863 live non-shell items found in the scanned window; older history <3M blocks not fully covered); "live" means owner ∉ {0, melt/legacy burn markers} at block 26,152,522. Read-only: no mainnet transactions; CI artifacts are public; no secrets in this folder.
* **Files:**
```
enjin-legacy/
├── README.md                  # this file
├── summary.json               # machine-readable summary
├── analysis/
│   ├── PRUNED.md              # what raw explorer dumps were pruned before the public CI push (reproducible)
│   ├── incident/              # incident/mitigation tx JSONs, decoded logs, key-call trace, disasm of 0x99294e5e
│   ├── census/                # shell census, live triples/owners, attack-window sweep stats (child 1)
│   ├── delegates/             # full routing-table history + current table + audit.md (child 2)
│   └── pa/                    # PA dispatch model, selector list, module decompiles, audit.md (child 3)
├── poc/                       # Foundry: 7 tests (all PASS), src/MaliciousShellLogic.sol
├── ci/run.sh                  # live-state evidence job (ci-out/live_state.json)
├── ci-out/                    # CI artifacts
└── ci-log.txt / ci-artifacts/ # downloaded CI logs/artifacts
```
