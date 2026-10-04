# Summer.fi (Summer.fi Pro automation — AutomationBot v1/v2) — Ethereum, Arbitrum, Base, Optimism

Auditor: child (H-5 census). All on-chain reads read-only via public RPC (`cast`, raw JSON-RPC), 2026-10-04.
Baseline blocks at start of work: ETH 26,116,895 · Arbitrum 511,521,227 · Base 52,151,169 · Optimism 157,746,454 ("latest" reads thereafter, ETH ≈26.117–26.119M).

## Status & shutdown evidence (sources, dates)
- Summer.fi front page (fetched 2026-10-04): "Summer.fi is winding down. The Summer.fi app has now been deactivated… use this app to exit all your positions and claim any outstanding rewards." (summer.fi)
- Blog 2026-07-15 "Sunsetting Summer.fi and the Labs Company" (blog.summer.fi): wind-down attributed to the 2026-07-06 Lazy Summer Protocol exploit ($6.04M, NAV manipulation in two USDC vaults); app live until Aug 31.
- Blog 2026-01-14 "Summer.fi goes all in on Lazy Summer Protocol as Summer Pro transitions to DeFi Saver": **"Summer.fi Pro's existing automation service will be discontinued at the end of the notice period (February 12, 2026)."** DefiLlama adapter hallmarks: `['2026-02-12','Summer.fi Pro sunsets']`.
- Scope note: Lazy Summer Protocol (Earn) is a **different** product from the Pro automation contracts audited here (AutomationBot v1/v2 + executors). The Pulse exploit does not touch these contracts.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
| Contract | Chain | Verified source | Proxy | Roles / authority | Notes |
|---|---|---|---|---|---|
| AutomationBot V1 `0x6E87a7A0A03E51A741075fDf4D1FCce39a4Df01b` | ETH (from 14,583,413) | ✅ Blockscout, `AutomationBot.sol` (V1, 298 lines) | No (single impl) | `execute` gated by registry `AUTOMATION_EXECUTOR` | Holds `cdpAllow` operator rights on user CDPs |
| ServiceRegistry V1 `0x9b4Ae7b164d195df9C4Da5d08Be88b2848b2EaDA` | ETH | ✅ | No | **owner()=0x0 (renounced)**; requiredDelay=1800 | `AUTOMATION_EXECUTOR=0x34B689c61aF149C3Bb904B8407abc0bfB6A622F6`; `CDP_MANAGER=0x5ef30b9986345249bc32d8928B7ee64DE9435E39`; `MCD_UTILS=0x68Ff2d96EDD4aFfcE9CBE82BF55F0B70acb483Ea` |
| AutomationExecutor V1 `0x34B689c61aF149C3Bb904B8407abc0bfB6A622F6` | ETH | ✅ `AutomationExecutor.sol` (2021) | No | `owner()=0x85f9b7408afE6CEb5E46223451f5d4b832B522dc` (Safe); `callers` whitelist; `execute`↔`auth(msg.sender)`; balance 0 | `bot()=0x6E87…` |
| AutomationBot V2 `0x5743b5606e94fb534a31e1cefb3242c8a9422e5e` | ETH (from 17,229,847) | ✅ `AutomationBot.sol` (V2, 429 lines) | No | `execute` gated by registry `AUTOMATION_EXECUTOR_V2` | ReentrancyGuard `_status` = storage slot 0 → mapping slot 2 |
| ServiceRegistry V2 `0x5E81A7515F956ab642Eb698821a449FE8fE7498e` | ETH | ✅ | No | `owner()=0x85f9b7408afE6CEb5E46223451f5d4b832B522dc` (Safe); **requiredDelay=0** | `AUTOMATION_EXECUTOR_V2=0xe145976Cba0383A44D8B46caEb36ab28fe0A9cC2`; `CDP_MANAGER=0x5ef30b99…` |
| AutomationExecutor V2 `0xe145976Cba0383A44D8B46caEb36ab28fe0A9cC2` | ETH | ✅ `AutomationExecutor.sol` (2023) | No | owner = Safe `0x85f9…` (**2-of-4 per parent fork work**); `callers[addr]` whitelist; balance 0 | `bot()=0x5743…`; `weth()=0xC02a…` |
| AutomationBot V2 `0x96D494b4544Bb7c3CB687ef7a9886Ed469e01ed8` | Base | ✅ | No | registry `0x0c1EDa5544EA63cf3d365912343161913a8f19Eb`; counter 1e10+588 | |
| AutomationBot V2 `0xE018AeA83728a037D8B6f76cCA0E8331cDAb937a` | Arbitrum | ✅ | No | registry `0x85859Ab683019a4E345D963E455B5e3Ce133Ef49`; counter 1e10+857 | |
| AutomationBot V2 `0xb2e2a088d9705cd412CE6BF94e765743Ec26b1e4` | Optimism | ✅ | No | registry `0x063E4242CD7C2421f67e21D7297c74bbDFEF7b0E`; counter 1e10+324 | |

V2 executor callers (all verified `callers(x)==true` on-chain AND `codesize==0`, i.e. keeper EOAs), block ~26.117M: `0x2424603ab18ea644b1fdd68d63654aa592b77069`, `0x27649ae2492219f63c563f9a90a5b2e5d6418637`, `0x5b62216aaeda2ad1c992c5e6234d4e4c2fe81c89`, `0x76a5e3558398ab0f0d3be9c630dd3235c6d2202f`, `0xbac64e6f64883f63c2cd74759d14ef12cb13fb00`, `0xc64bc5cd9ac2e12adc0f0af685aa0eef2eaba231`, `0xcab038a707b04eedafc6922f75dd45a6deb288a4`, `0xd75c57da2eb09c9145adefcc1f036ec44edd6f3a`, `0xed2d4a7d808b1637338586f1068b94626dfaa1a9`, `0xec4497a2a66a4f2eee29aa677a8d51be77cb2c04`, `0x0af242d219cdb668f60505b7c3be57d03894d20f` (11 EOAs; parent counts 12 live callers).

## Live balances (token, amount, USD, price source, block)
- **The Summer contracts custody no user tokens.** Executors hold 0 native + no ERC-20 custody; bots are pure authorization/config contracts. Live value is user collateral inside **external** positions (Maker CDPs via V1; Aave/Spark/Morpho "DPM" positions via V2) over which Summer holds automation rights.
- DefiLlama (parent-supplied, 2026-10-04): Ethereum **$18.11M**, Arbitrum **$276.6K**, Base **$1.0K**, Optimism **$1.1K** → ≈ **$18.39M**. Adapter method (`projects/summer-fi/{automation-v1,automation-v2}.js`, fetched): V1 = Maker CDP collateral from `McdMonitorV2.getVaultInfo` for CDPs with live TriggerAdded−TriggerRemoved; V2 = `getUserReserveData`/Morpho collateral for positions with live triggers; `doublecounted: true`.
- On-chain verification of the authority-bearing state (my reads):
  - **V1 ETH: 737 live trigger records** (scanned slot keccak(id,0) over ids 1..3217; nonzero). Events: 3217 TriggerAdded / 1018 TriggerRemoved — difference explained by V1 `execute()` clearing one-shot triggers **without** emitting TriggerRemoved, so only the storage scan is authoritative. Each live CDP still has `cdpAllow(cdpId, bot)` (granted by `addTrigger`, `AutomationBot.sol` V1 L182-185).
  - **V2 ETH: 383 live trigger records** (slot-2 scan of ids 1e10+1..1e10+1119, raw `summerfi_eth_v2_active2.json`). Top command addresses: `0xac728f8248f8cad0e0f10a2a4e648981eda095a4` (62), `0x34b4632482dc19f5b7e7ddd69f2b90a08e3754f0` (54), `0xb12ab11954028df47d4a7b252c623e9f0b7d2e1b` (30), `0xf8a2d2307b586a7720d5ba9271668c7ed15250ff` (28), `0xa870edf71e88847cf8f292555c9da6de26ba3470` (26) `0xdc1c84aac43f21f103e9bd0b091a1b5cc6433554` (24), `0x739838d896b50703968e43876f2d43885c9ff8ad` (24), `0x4a13b02ef24b2906a33e48e8f0aaf343c5316327` (24), …; continuous flag: 161 true / 222 false.
  - **V2 Arbitrum: 183 live trigger records** (command rows: `0xef5d52581e541c4802e144d642fd38e09b5aa8d0` 70, `0xada42d0f5fc52285880d1914319e5ece0dcbd464` 53, `0x3da7a8edab8465438ac0f5b542f111f12188a2cd` 36, `0xa870edf7…` 15, `0xcd903afa4378e8fc96a6f50bf2a46130e4f33065` 8, `0xc45601e97847018752c85ebbb848a6cf86d68def` 1).
  - **V2 Base: live-trigger scan NOT completed** (Base RPC returned malformed batch; 588 added events known). **V2 OP: NOT completed** (mainnet.optimism.io rejected batches with HTTP 413; 324 added events known). Do not cite Base/OP active counts — open item.
- Exact per-token amounts were not recomputed in the time-box; DefiLlama figures remain the value reference (flagged as not independently re-summed).

## Permissionless paths examined (path → gates → live values → verdict)
1. `AutomationExecutor.execute(...)` (V2) ← `executor/not-authorized`: `auth(msg.sender)` requires `callers[msg.sender]`; owner = 2-of-4 Safe `0x85f9…`. All 11 checked callers are EOAs (codesize 0). **Attacker call reverts `executor/not-authorized` — parent-verified fork test.** Verdict: dead end (P-gated).
2. `AutomationBot.execute(...)` (V2) ← `bot/not-executor`: `auth` requires `msg.sender == registry.getRegisteredService("AUTOMATION_EXECUTOR_V2")` = `0xe145976…`. **Attacker call reverts `bot/not-executor` — parent-verified.** Verdict: dead end.
3. `AutomationBot.addRecord(...)` (V2): callable by anyone but requires `ISecurityAdapter(adapter).canCall(triggerData, msg.sender)`; without the victim position's authorization the call reverts `bot/no-permissions`. An attacker can only add triggers for positions they already control. Verdict: no extraction.
4. `AutomationBot.clearLock()` (V2, anyone): resets `lockCount`; at worst a griefing DoS of a concurrent `addTriggers` transaction (atomic revert, no fund movement). Verdict: no value.
5. V1 `AutomationBot.execute(...)`: `auth` requires registry `AUTOMATION_EXECUTOR` = `0x34B689…`; that executor's `execute` again requires `callers[msg.sender]` (owner = Safe `0x85f9…`). V1 registry owner is renounced (`0x0`), so the executor address is frozen. Verdict: both gates privileged; no unprivileged route found.
6. V1 `addTrigger`/`removeTrigger`/`grantApproval`/`removeApproval`: `onlyDelegate` → must be delegatecalled by the CDP owner's DSProxy; attacker cannot reach them (`address(this) != self` fails for direct calls).
7. ServiceRegistry V2 `addNamedService/removeNamedService` (owner Safe, **delay 0 — no timelock**): privilege can instantly rotate executor/commands. This is a governance risk (P), not attacker-reachable.
8. Not covered in time-box (flagged for parent): command-level validation of attacker-supplied `executionData` reachable **through a whitelisted keeper** (e.g. swap target/callee fields in stop-loss/take-profit commands). This is P-scenario (keeper key compromise), not E-U, and does not change the E-U verdict.
9. Negative result recorded: V2 inherited-`ReentrancyGuard` storage-offset trap — mapping is at slot 2; a naive slot-1 scan yields all-zero and a false "no triggers". Corrected scan used slot 2 (verified against `getTriggerRecord(10000000003)` returning hash `0xc409f99d…` / command `0x65127D52…`).

## Approvals / user-side residual risk
- **737 Maker CDPs (V1)** still grant `cdpAllow(cdpId, AutomationBot V1)`; the executor keeper path (Safe-controlled EOAs) could operate them if ever invoked. Users can revoke directly in Maker (`CdpManager.cdpAllow(cdpId, 0x6E87…, 0)`); no Summer UI needed.
- **566 live V2 triggers (383 ETH + 183 Arb, Base/OP unmeasured)** mean the automation authorization installed by users at trigger-add time remains active post-shutdown. Anyone using the deactivated app should remove triggers/revoke to eliminate the privileged-keeper path. The app banner provides the exit UI.
- No token approvals to Summer executors were found on executors themselves (no balances/allowances drawn at rest).

## Classification: P — ≈$18.39M (DefiLlama: ETH $18.11M + Arb $276.6K + Base $1.0K + OP $1.1K) — confidence: high that E-U = $0; medium on exact live value (Base/OP trigger scans incomplete; DefiLlama not re-summed) — what would change it
- **E-U $0.** Both entry chains to user funds are gated: `executor/not-authorized` (keeper whitelist, all EOAs, owner 2-of-4 Safe) and `bot/not-executor` (registry executor), parent-verified by revert on fork. Live trigger counts (383 ETH / 183 Arb / 737 V1 CDPs) are real but only reachable by the Safe/keeper set → **P**.
- H-O overlays: the underlying collateral is in Maker/Aave/Spark/Morpho, self-custodial — holders can exit independently (H-O for those users).
- Would change verdict: (a) any live caller found to be a permissionless contract (none among 11 checked), (b) Safe/keeper key compromise (P→attacker), (c) a command-level flaw that lets a keeper route value out (still P), (d) a V2 `addRecord`/adapter bypass making `canCall` return true for an attacker (none found).

## Raw evidence index (files in /home/heisenberg/CA/shutdown-census/analysis/raw/)
- Bot sources/ABIs: `summerfi_eth_autobotv1_blockscout.json` (+`summerfi_eth_autobotv1_source.sol`), `summerfi_eth_autobotv2_blockscout.json` (+`summerfi_eth_autobotv2_source.sol`), `summerfi_eth_mcdmonitorv2_blockscout.json` (+`summerfi_eth_mcdmonitorv2_source.sol`), `summerfi_op_autobotv2_blockscout.json`, `summerfi_autobotv2_0x96d4…json`, `summerfi_autobotv2_0xe018…json`
- Registry/executors: `summerfi_eth_serviceregistry_source.sol`, `summerfi_eth_executor_source.sol`, `summerfi_eth_v1executor_source.sol` (+ Blockscout JSONs)
- Trigger state: `summerfi_eth_v1_active_triggers.json` (737), `summerfi_eth_v1_active_trigger_cdpids.json` (partial, aborted), `summerfi_eth_v2_active2.json` (383 + command words), `summerfi_arb_v2_active2.json` (183), invalid legacy scan `summerfi_eth_v2_active_triggers.json` (slot-1 bug — do not use)
- Events: `summerfi_eth_v2_triggeradded_logs.json` (1000), `summerfi_eth_v2_triggerremoved_logs.json` (736), `summerfi_eth_v2_added_full.json` (120 incremental), `summerfi_eth_v1_added_full.json` (3217), `summerfi_eth_v1_removed_full.json` (1018), `summerfi_eth_executor_calleradded_logs.json`, `summerfi_eth_executor_callerremoved_logs.json`
- Scripts: `scan2_summerfi.py`, `fetch_logs2.py`, `fetch_summerfi_logs.py`, `scan_summerfi_triggers.py`
- DefiLlama: `summerfi_defillama_adapter.js`, `summerfi_dl_automation-v1.js`, `summerfi_dl_automation-v2.js`
