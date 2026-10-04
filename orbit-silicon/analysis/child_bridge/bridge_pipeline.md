# Silicon Network — L1/L2 bridge exit pipeline state

**Read-only assessment, 2026-10-04 ~22:42 UTC.** No transactions were sent or signed.
Pinned read blocks: **Ethereum 26,122,011** (final: 26,122,049) · **Silicon 21,251,938** (2026-10-04 22:34:27 UTC; final 21,252,068 @ 22:41:56 UTC).

## Bottom line

**EXITS ARE LIVE (classification H‑O for holders), both directions.**

1. **Every bridge leaf currently recorded on Silicon is already anchored on L1.** L2 bridge `getRoot()` == L1 AgglayerManager `lastLocalExitRoot` for rollup 10 == `0x02d6ec8c…`, which is exactly the root confirmed by the most recent Silicon verification on L1 (2026‑10‑04 11:06:59 UTC, block 26,118,583).
2. **L2→L1 claims execute successfully today:** withdrawal #2523 claimed on L1 via `claimAsset` at block 26,118,655 (2026‑10‑04 11:21:23 UTC), status `0x1`; #2522 also claimed 11:31:11 UTC.
3. **L1→L2 claims execute successfully today:** deposit #264466 claimed on L2 at block 21,237,509 (2026‑10‑04 08:48:59 UTC), status success, wrapped ORC minted.
4. **No emergency/pause state anywhere:** AgglayerManager `isEmergencyState=false`; L1 bridge `isEmergencyState=false`; L2 bridge `isEmergencyState=false` (this bridge version has no deposit-pause function).
5. **L1 GER is still being updated continuously:** 32 `UpdateL1InfoTree(V2)` events in ~24 h, latest at block 26,121,910 (2026‑10‑04 22:14:11 UTC, ≈30 min before report).
6. **Silicon-specific verification is recent, not stale:** last `verifyPessimisticTrustedAggregator(rollupID=10)` at 11:06:59 UTC today; no L2 bridge activity has occurred since 10:31:06, so there was nothing newer to verify. Historical cadence 1–13 h/verification (48 events 09‑23 → 10‑04).

**Residual risk (S only conditionally):** state anchoring is now performed by a permissioned aggregator (`0x20A53dCb…`) via pessimistic certificates; if it stopped, *future* withdrawals would stop being anchorable. Nothing is protocol-stuck at present. 9 of the last 600 withdrawals have no indexed L1 claim tx (user-side claim not done/indexed) — those remain claimable because their root is anchored and historical GERs persist.

---

## 1. Silicon rollup in the RollupManager (L1)

`chainIDToRollupID(2355)` = **rollupID 10**. RollupManager proxy `0x5132A183E9F3CB7C848b0AAC5Ae0c4f0491B7aB2` → impl **AgglayerManager `0x15cAF18dEd768e3620E0f656221Bf6B400ad2618`** (v1.0.0, verified).

| item | value |
|---|---|
| rollupContract | `0x419dcD0f72ebAFd3524b65a97ac96699C7fBebdB` ("silicon-zk") |
| chainID | 2355 |
| rollupTypeID | 14 → consensus impl `0x0D49fD0d79723e4D24AaC83f604ED2D3d5fC0f21` = **AggchainECDSAMultisig**, obsolete=false |
| rollupVerifierType | **2 = ALGateway** (enum: 0 StateTransition, 1 Pessimistic, 2 ALGateway) |
| verifier / programVKey / forkID | `0x0` / `0x0` (ALGateway verifies via gateway `0x046Bb8bb98Db4ceCbB2929542686B74b516274b3`) |
| lastBatchSequenced | **75,940** (frozen legacy counter) |
| lastVerifiedBatch | **75,940** |
| lastVerifiedBatchBeforeUpgrade | 75,940 |
| legacy pending states | 0 / 0 |
| lastLocalExitRoot (Silicon LER) | `0x02d6ec8cace61c90069033862c039c472563c051553c841cbbb9106b06e2c038` |
| lastPessimisticRoot | `0x149a5663cb7f3aa7693ce86774bb5c8d73cf9ce611159d0913b53f5f29e94307` |
| getRollupExitRoot (aggregate) | `0xf320c1726fd24912eb8d499a6daff37112a7b757d1333c2e4a1e12de043c677d` |
| isEmergencyState | **false** |
| trustedSequencer | `0x47ed9538faA1522be7abD8a8BCAEc8d9C04Ed60D` |
| rollup admin | `0xef5D7af5dbBeE845860E75cE8f8e8fE7F6e8dBF7` |
| aggregator (last verifies) | `0x20A53dCb196cD2bcc14Ece01F358f1C849aA51dE` |
| manager rollupCount / lastAggregationTimestamp | 29 / `1791152051` = 2026‑10‑04 22:14:11 UTC |

**Phase change (important):** the last legacy `sequenceBatchesValidium` tx to the rollup contract was block 26,022,743 (2026‑09‑21 01:55:23 UTC, tx `0x7d789d85…`, reached batch **76,171** per its `OnSequenceBatches` log). The first pessimistic verification for rollup 10 was 2026‑09‑23 09:16:59 (block 26,039,230). The legacy batch counters were consolidated at 75,940 (`lastVerifiedBatchBeforeUpgrade`) and legacy sequencing stopped; state/exit anchoring now flows through `verifyPessimisticTrustedAggregator`. No `RollbackBatches` events exist for rollup 10 (0 found since block 26,000,000).

**Last Silicon verification on L1:** tx `0x3a051f1108d034040d4b6a1e32a254dad3da9b052a18cabe23aaa4a13bd77877`, block **26,118,583**, 2026‑10‑04 **11:06:59 UTC**, success. Method: `verifyPessimisticTrustedAggregator(rollupID=10, l1InfoTreeLeafCount=122438, newLocalExitRoot=0x02d6ec8c…, newPessimisticRoot=0x149a5663…, proof=SP1 0x0000000e5a093a2f…, aggchainData=0x)`. Rollup emitted `OnVerifyPessimisticECDSAMultisig`.
No newer rollup‑10 verification exists through block 26,122,049 (log query from 26,118,584 → latest = 0 results).

## 2. L1 GlobalExitRoot manager

`0x580bda1e7A0CFAe92Fa7F6c20A3794F169CE3CFb` → impl **AgglayerGER `0x7F1655d9d570167B2a3FfD1Ef809D3Fdd74427C5`** (v1.0.0, verified).

| item | value |
|---|---|
| getLastGlobalExitRoot | `0x7c66d83808387f9a42ee58b632ec17ce145d7250a18a0a96dec4f3a0ea30260d` |
| lastMainnetExitRoot | `0xc1325f9c0d67f9095fe8f3c9d379c2d9cc2f8a3b5e0e9f91949b1bc0d16d8748` |
| lastRollupExitRoot | `0xf320c1726fd24912eb8d499a6daff37112a7b757d1333c2e4a1e12de043c677d` (= manager `getRollupExitRoot`) |
| depositCount (L1 info-tree leaves) | 122,455 |
| rollupManager / bridgeAddress | `0x5132A183…` / `0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe` |
| relation check | `keccak256(lastMainnetExitRoot ‖ lastRollupExitRoot)` == `getLastGlobalExitRoot` ✅ |

**Update activity:** 32 `UpdateL1InfoTreeV2` events from block 26,114,800 (~24 h) to latest; last three at 20:19:35, 21:49:59 and **22:14:11 UTC** (block 26,121,910, tx `0x97f6610f…` — a rollup‑20 verify). Age of last GER update at report time: **~0.5 h**. Updates are continuous. The historical GER used by the 11:21 L1 claim (`0x825309f0…` = keccak(0x116f55a3…, 0x94106184…)) is still present in `globalExitRootMap` (nonzero) → old claims remain valid.

## 3. L2 GlobalExitRoot manager (Silicon)

`0xa40D5f56745a118D0906a34E69aeC8C0Db1cB8fA`, scope name **"PolygonZkEVMGlobalExitRootL2"**, EIP‑1967 impl slot = `0x0200143fa295ee4dffef22ee2616c2e008d81688` (428 B impl; selectors: `0x01fd9044 lastRollupExitRoot()`, `0x257b3632 globalExitRootMap(bytes32)`, `0x33d6247d updateExitRoot(bytes32)`, `0xa3c573eb bridgeAddress()`).

| item | value |
|---|---|
| lastRollupExitRoot | `0x02d6ec8cace61c90069033862c039c472563c051553c841cbbb9106b06e2c038` (= Silicon LER) |
| bridgeAddress | `0x2a3DD3EB832aF982ec71669E178424b10Dca2EDe` (L2 bridge) |
| `lastGlobalExitRoot` / `lastLocalExitRoot` / `getLastGlobalExitRoot` | **do not exist on this contract/version (revert)** — the task’s expected getters are from other GER versions |

**How L1 GERs reach L2 / claims:**
- `AgglayerBridge._updateGlobalExitRoot()` calls `globalExitRootManager.updateExitRoot(getRoot())`; it runs after `bridgeAsset`/`bridgeMessage` when the user sets `forceUpdateGlobalExitRoot`, and via the public `updateGlobalExitRoot()` (impl source lines ~430/539/1078‑1089).
- Claims read `globalExitRootManager.globalExitRootMap(keccak256(mainnetExitRoot ‖ rollupExitRoot))` and revert if zero (impl `_verifyLeaf`, line ~925). GER keys are injected into the L2 map as they are received from L1.
- **Live proof:** the L1→L2 deposit #264466 GER = keccak(`0x116f55a3…`, `0x5051da2b…`) = `0x7b4e2de840e9c1586345ef9fb8522a6f2c9998c40858d7005d2b728dc27487ad` is present in the **L2** `globalExitRootMap` (nonzero, same value as in the L1 map). The claim tx `0xa415a14f…` (block 21,237,509, 08:48:59 UTC) made an internal call to the GER (`0x257b3632`) and then minted wrapped ORC (`0x40c10f19` to the depositor).
- The GER’s `lastRollupExitRoot` equals the LER created by the 11:06:59 UTC L1 verification ⇒ the L2 GER was updated after that verification, confirming the injection path is alive within the last ~11.5 h.

## 4. Scope bridge API (Silicon)

`GET https://api-scope.silicon.network/bridges/withdrawals` and `/bridges/deposits` (page/limit work; `limit=100` accepted).

**Withdrawals (L2→L1): total 2,513** (API count; latest index 2523 = 2026‑10‑04 10:31:06, HANDY 101,898).
- last 7 days: **31**; last 24 h: **3** (indices 2521–2523, all with `l1TxHash`).
- `l1TxHash` present: **91/100** most recent, **591/600** fetched (back to 2026‑03‑28). 9 without indexed L1 claim tx: indices 2449 (09‑15), 2456, 2457 (09‑17), 2460 (09‑19), 2463 (09‑21), 2466 (09‑23), 2475 (09‑25), 2498 (09‑29, ETH), 2516 (10‑02, 3,586,352 ORC). Not indexed as claimed = user-side claim pending/lag; roots are anchored so they are claimable.
- last 7 d tokens (count, sum): ETH 8 / 4.1122 · USDT 8 / 9,281.55 · HANDY 7 / 698,732.05 · ORC 3 / 4,392,054.21 · GALA 3 / ~0 · WBTC 1 / 0.5718 · MATIC 1 / 1,791.41.

**Deposits (L1→L2): total 1,967** (latest 2026‑10‑04 08:36:59, ORC 200,000).
- last 7 days: **12**; last 24 h: **1**; all 400 most recent have both `l1TxHash` (L1 deposit) and `l2TxHash` (L2 claim).

**Bridge contracts pinned @ ETH 26,122,011 / Silicon 21,251,938:**

| | L1 bridge | L2 bridge |
|---|---|---|
| address / impl | `0x2a3DD3EB…` / AgglayerBridge `0x66E0120e…` | `0x2a3DD3EB…` / impl `0x5ac4182A1dd41AeEf465E40B82fd326BF66AB82C` |
| networkID | 0 | 10 |
| globalExitRootManager | `0x580bda1e…` | `0xa40D5f56…` |
| depositCount / lastUpdated | 264,477 / 264,477 | 2,524 / **2,524** |
| getRoot | — | `0x02d6ec8c…` (= last verified LER) |
| isEmergencyState | **false** | **false** |

## 5. Block numbers used

- Ethereum: 26,121,948 (first state read), 26,119,910 (last GER update), 26,118,583 (last Silicon verify), 26,118,655/26,118,704 (claims), 26,118,655 (receipt), 26,122,011 (pinned final reads), 26,122,049 (report close).
- Silicon: 21,251,938 (pinned), 21,237,509 (L2 claim), 21,239,294 (latest withdrawal), 21,252,068 @ 22:41:56 UTC (report close).

## 6. Confidence & caveats

- **High confidence**: all recorded withdrawals are anchored (L2 bridge root == L1 stored LER); claims succeeded on-chain in both directions on 2026‑10‑04; no emergency state; GER updates hourly on L1; aggregator active (other rollups verified at 22:14 today).
- **Medium confidence**: the exact migration mechanics (legacy counters consolidated at 75,940 after sequencing reached 76,171 on 09‑21); no rollback events found, and the full LER was re‑anchored. Also: the scope API’s missing `l1TxHash` entries are an index/user-claim signal, not proof of a stuck leaf.
- **Forward-looking risk (S-risk)**: continued exit anchoring depends on the permissioned aggregator `0x20A53dCb…` and the Agglayer gateway; if they stop before the 2026‑12‑31 forced-exit deadline, only *newly created* L2 leaves would become un-anchorable. Watch for new `verifyPessimisticTrustedAggregator(rollupID=10)` events after any new withdrawal.
- Do **not** read `lastBatchSequenced=75940` as “no recent anchoring” — post-migration anchoring is via `lastLocalExitRoot`/`lastPessimisticRoot` and periodic pessimistic verifications.

## 7. Evidence files (all in this directory)

`final_state_pinned.txt`, `manager_state.txt` · `read_final_state.sh`, `read_manager.sh` · `rollupmanager_blockscout.json`, `agglayer_manager_impl_blockscout.json`, `agglayer_manager_impl.sol`, `l1_ger_blockscout.json`, `agglayer_ger_impl_blockscout.json`, `silicon_rollup_proxy_blockscout.json`, `aggchain_ecdsa_multisig_impl_blockscout.json` · `mgr_silicon_verify_logs.json` (48 events), `mgr_silicon_verify_after_11106.json` (0), `tx_last_silicon_verify.json`, `tx_last_sequence.json`, `tx_last_sequence_logs.json`, `tx_verify_pessimistic.json`, `ger_updates_24h.json`, `ger_recent_logs.json`, `mgr_recent_txs.json`, `rollup_recent_txs.json`, `rollup_recent_logs.json`, `mgr_silicon_rollback_logs.json` · `tx_claim_2523.json`, `tx_claim_2522.json` · `l2_withdraw_tx.json`, `l2_claim_deposit_tx.json`, `l2_claim_deposit_itxs.json`, `l2_claim_deposit_events.json` · `l2ger_code.txt`, `l2ger_impl_code.txt`, `l2bridge_impl_code.txt`, `l2_ger_scope.json`, `l2ger_txs.json`, `l2ger_events.json` · `wd_p1..6.json`, `dp_p1..4.json`, `l2bridge_txs_p1..6.json`, `l2bridge_txs.json`.
