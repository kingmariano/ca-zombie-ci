# Enjin legacy CryptoItems — remaining items & holders census (C2-23)

> **Note (public-repo hygiene):** before the final public CI push, large reproducible raw dumps were
> pruned from this folder — `raw/`, `attack_window_events.json`, `nonshell_liveness.jsonl`,
> `shells_parsed.json`, `adapter_created_events.json`, `probe_tails.jsonl`. The distilled results
> (`census.json`, `probe_owners.jsonl`, verification/summary JSONs, scripts) are kept and cited.
> See `../PRUNED.md` for the exact list and how to re-fetch each item.

Deep-dive census of Enjin's legacy CryptoItems platform at Ethereum mainnet, produced during the
"zombie-hunt II" campaign after the 2026-08-25 exploit. Everything in this directory is based on
read-only on-chain calls (`eth_call` / `eth_getLogs` / Etherscan V2) and is reproducible with the
scripts in `scripts/`.

## TL;DR

- **395 shells / 395 base types** ever created on PA `0xfaafdc07907ff5120a76b34b731b278c38d6043c`
  (391 NFT-type, 4 FT-type). All of them were created **during the attack window**
  (blocks 25,834,071 – 25,834,993, 2026-08-25 18:41–21:46 UTC) by the single attacker helper
  contract `0x7083ddece38216c7741fa76c75326bea744ed321`. There are no earlier shell-creation events.
- **Surveyed 9,230 ownerOf slots** (every shell's first 25 items + ~10 tail indices on 227 large shells).
  **Only one shelled base type still has live items: "Envoy Badge"** (`0x0f1f62c38fa21da98bdcfb2f06e8a20dba979791`):
  **55 of 61 items live, 6 melted long before the attack**; 55 distinct owners, all EOA, all verified.
- **Beyond shells: 863 live NFT items in 35 base types that have NO shell** (discovered via
  TransferSingle events of the last 3M blocks; ids then checked with `PA.ownerOf`), plus
  **34 live FT balances** in non-shell FT types. These items were outside the attacker's shell-based sweep.
- **FT (fungible) base types are fully drained**: the 4 FT item types were swept in the very first
  attack transaction (block 25,834,071, tx `0xd4a382da…`): 43 victim addresses' balances moved to the
  attacker helper and then burned to `0x0`. Sampled victim + helper balances verified = 0 at latest.
- Attack sweep (TransferSingle logs inside the attack window, fully re-scanned in small chunks):
  **~20k+ victim item movements** across **~50 shelled base types**, 4,000+ victim addresses,
  destinations only the attacker helper `0x7083ddece3…` and the zero address.

Pinned state blocks: see `meta.artifactBlocks` in `census.json` (all within block 26,152,529 – 26,152,693;
the chain has emitted no PA/Adapter events after the attack freeze at block 25,835,670).

## Live triples usable for a fork test (holder melt)

All of the following were verified at the stated block with `shell.ownerOf == PA.ownerOf == owner`
and `PA.balanceOf(owner,id) == 1` (see `live_verification.json`, `nonshell_verification.json`).

Envoy Badge shell `0x0f1f62c38fa21da98bdcfb2f06e8a20dba979791`, base type
`0x6080000000000849000000000000000000000000000000000000000000000000`
(eblock 26152685):

| idx | instanceId (baseType \| idx) | owner |
|-----|------------------------------|-------|
| 2 | 43648189888285219791758562213502959110711528811875759294532057304950080798722 | 0xbbc52f6551053f1bce454b4b622cc67069f70a69 |
| 3 | …98723 | 0x063fd26d4b3a91786a9e74de2419aa9e2ad13f18 |
| 4 | …98724 | 0x3e0206d18172c12380ea6b3fbd897c0a9535a499 |
| 5 | …98725 | 0x52fadfa28eff856fc187ddd26fb6f72098dd1193 |
| 6 | …98726 | 0x05c5c4459a90873e192fe74914de18e4e7206281 |

Non-shell examples (verified at block 26152693):

| baseType | instanceId | owner |
|----------|------------|-------|
| 0x30800000000006b800…00 | 21937173156288430632721206634314990090071847980793920680089227073388529319944 | 0xcd7c9dfdb4e0dafe74d163e0284367f6311070b2 |
| 0x30800000000006b800…00 | …9320022 | 0xcf6b821709383bb798c60be0a4724a3879ef24d4 |
| 0x30800000000006dd00…00 | …06297112 | 0xb814f14996dd967a04e858ebe36120784ced4e36 (EIP-7702 delegated EOA) |
| 0x78800000000003c400…00 | 54503698254283605850111634215677806713947227223009518742805956560804005286576 | 0xffbee68c1693e16b007bbf9be75cbf27e4bd6326 |

A ready `cast` verification transcript is in `cast_evidence.txt` (e.g.
`cast call --rpc-url "$RPC" --block 26152685 0x0f1f62… "ownerOf(uint256)(address)" <id>`).
Cross-checked on BlockPI, NodeReal and publicnode — identical results.

## Method

1. **Enumeration (full census, not sampled).** Etherscan V2 `getLogs` on PA with
   `topic0=0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad`,
   `fromBlock=0, toBlock=latest, offset=1000` → 395 logs < 1000 so one page is complete
   (`adapter_created_events.json`, raw pages in `raw/adapter_created_page_1.json`).
   topics = [topic0, baseType (indexed), deployer (indexed)], data = shell address.
   NFT-type ⇔ bit 247 of baseType set.
2. **Shell state (all 395).** `eth_call totalSupply()` at pinned block; for all 391 NFT shells
   `ownerOf(baseType | i)` for i = 1..min(N,25); for shells with N > 25 additionally ~10 spread
   tail indices in [26..N] (227 shells); Envoy Badge scanned fully 1..61. Batched ≤ 10 calls,
   alternating env RPCs (BlockPI/Nodereal). Raw results: `probe_totalSupply.json`,
   `probe_owners.jsonl`, `probe_tails.jsonl`, `envoy_full_scan.json`.
   - Item-id convention verified on-chain: `itemId = baseType | idx`, idx 1..N; idx 0 and N+1 revert
     `CryptoItemsAdapters: owner query for nonexistent token`.
   - Item owner markers: `0x0000deaddeaddeaddeaddeaddeaddeaddead0000` = melt marker (post-melt owner),
     `0x000000000000000000000000000000000000dead` = legacy burn, `0x0` = none.
3. **Cross-validation.** `PA.ownerOf(id)` (independent facade contract) returns exactly the same owner
   as the shells; `PA.balanceOf(owner,id) == 1` for every live triple, and `balanceOf(meltMarker,id) == 0`.
   Shell type routing inspected via `delegates(bytes4)` on the templates: currently points to the
   legitimate 2021 Enjin implementations `0x24591e792a404e5bd48ac0f694339d807b02cfd2` (NFT) and
   `0x75512f843d8d22593d7256708ef80a22b97baf5e` (FT).
4. **TransferSingle scan.** Etherscan `getLogs` on PA, `topic0=0xc3d58168…0f62`, last 3,000,000 blocks
   (23,152,527 → 26,152,527), chunked by block windows because Etherscan caps each query at 10k rows.
   The attack window 25,833,777–25,840,026 was re-scanned in 250-block chunks and the three >10k
   chunks recursively down to ~25-block chunks (raw pages `raw/ft_ts_*.json`, `raw/ft_ts_fix_*.json`,
   `raw/ft_ts_fine_*.json`; merged `attack_window_events_fine.json`). Results: `ft_events_filtered.json`,
   `attack_window_events.json`.
5. **Non-shell liveness.** All 3,846 distinct item ids seen in pre-attack events whose base type has
   no shell were checked with `PA.ownerOf` (NFT-style) or `PA.balanceOf(lastTo,id)` (FT-style):
   `nonshell_liveness.jsonl`, `nonshell_summary.json`; 9 samples re-verified in `nonshell_verification.json`.

## Counts (full census vs sampled)

| Metric | Value | Coverage |
|--------|-------|----------|
| Shells ever created | 395 (391 NFT, 4 FT) | **full** (event scan from genesis) |
| Shell base types | 395 unique; 1 deployer; all created in the attack window | **full** |
| NFT item instances minted ever (sum of totalSupply) | 92,245 | full via totalSupply |
| ownerOf slots individually probed | 7,354 (first 25) + 1,840 (tails) + 36 (Envoy tail) ≈ 9,230 | sampled (228 shells have N>25; ~10 tail indices each) |
| Live shelled items found | **55** (Envoy Badge only; 55/61 of that type) | within sampled slots |
| Melted (melt/burn marker) in probed slots | 7,288 + 1,836 + 6 Envoy melts = 9,130 | — |
| Legacy-burn (`0x…dead`) in probed slots | 49 | — |
| Live non-shell NFT items (ids seen in last 3M blocks) | 863 across 35 base types, 48 owners | partial (only ids transferred in-window) |
| Live non-shell FT balances | 34 ids | partial (same window) |
| Attack-window swept item movements | see `census.json → attack` (final numbers after the fine scan) | full for attack window [25,833,777 – 25,840,026] |

Ownership distribution highlights:
- Envoy Badge: 55 live items, 55 distinct EOAs, each holds exactly 1 (balances = 1).
- Non-shell live items are concentrated: `0x4bcb52af…` holds 273, `0x701e13e8…` 210, `0xb814f149…` 103,
  `0x0000b81c6c9ac6…` 71 (EOA), then a long tail. Top two non-shell base types by live items:
  `0x7080000000000890…` (401 ids in-window) and `0x7080000000000592…` (349 ids in-window).

## FT section (4 fungible shell types)

| name | shell | baseType | totalSupply() | sweep |
|------|-------|----------|---------------|-------|
| The Monolith | 0x68e2098057c9341e1e7fb466bc05810ddc20bb35 | 0x7000…0002 | 0 | tx 0xd4a382da… block 25,834,071 |
| The Horn | 0xfe3f74463d360e84d6736094d9b10a519b9e7722 | 0x7000…0003 | 0 | same tx |
| Frozen Enjin (500 ENJ) | 0xff1727d2566b5da1ef031d7287e149ef9321363a | 0x7000…0105 | 0xffffffffffffffff (sentinel) | same tx (41 victim legs) |
| Aethelborn Amulet | 0xb2fe1351fd667e9a3c5fffa7f7c5a259f9ce9b73 | 0x7800…0010 | 2000 | same tx (3 victim legs) |

All 92 FT TransferSingle events of the sweep occur in the single first attack tx; every leg is
`victim → attacker helper` followed by `helper → 0x0`. 43 distinct victims (46 legs; values include
1995, 89, 5, 4, 2, 1…). Current balances verified 0 for all sampled victims and the helper
(`scripts` + `census.json → ft[].currentHolderCheck`). Holders cannot be enumerated from state —
event tracking was required, exactly as noted in the task.

## Attack sweep (why shells matter)

- The attacker's helper contract `0x7083ddece38216c7741fa76c75326bea744ed321` created all 395 shells
  (selector `0x33d332ab`) and performed the sweep between blocks 25,834,071 and 25,835,670
  (last Adapter event = freeze/pause `topic0 0xd8d7d71f…` with data `1` at block 25,835,670).
- Sweep pattern per NFT: `victim → helper` then `helper → 0x0`, after which `ownerOf` for that
  instance returns the melt marker `0x0000dead…`. All swept ids belong to shelled base types;
  non-shell base types were not touched.
- The fine re-scan results are stored in `census.json → attack` (`distinctSweptItemIds`,
  `sweptBaseTypes`, `distinctVictimAddresses`, `toCounts`).
- Envoy Badge is the single shelled type with survivors (55/61). Its 6 melt-marked items were melted
  long before the attack (no Envoy TransferSingle events in the capture window except one burn at
  block 23,263,604). Envoy badges appear to have been of no interest to the sweep (unbacked badges),
  but the census only proves the state, not the attacker's motives.

## Limitations

- Owner scanning of shells with N > 25 covers first 25 + ~10 spread tail indices; the remaining
  interior indices are not individually enumerated (228 shells affected). Tail sampling found no
  additional live items, and existing event history shows no post-attack Transfers, so residual risk
  of missed live items is small but non-zero.
- TransferSingle coverage is limited to the last 3,000,000 blocks for events outside the attack window
  (≈2025-09 → 2026-10). Items whose last movement predates that window are not discoverable this way
  (applies only to the non-shell extension; the shell census uses direct state reads).
- The census reports the melt marker (`0x0000dead…`) as "not live" but cannot date individual melts:
  the `probedFirst25ItemsSweptInAttack` counter intersects probed ids with attack-window events to separate
  attack melts from older melts for the sampled slots.
- `totalSupply()` for the two "Frozen"/"Amulet" FT types is a sentinel/absolute value that does not
  equal current circulating supply (actual balances are all 0).
- Everything is measured at the pinned blocks listed in `census.json → meta.artifactBlocks`; there was
  no chain activity affecting these contracts after the freeze.

## Exact commands (rerun me)

Etherscan V2 (key stays in env, never written to files):
```bash
set -a; source /path/to/.env    # ETHERSCANV2_API_KEY, BLOCKPI_RPC_URL, NODEREAL_ETH_RPC_URL
python3 scripts/fetch_adapter_created.py       # 395 shell-creation logs -> raw/adapter_created_all.json
python3 scripts/parse_shells.py                # -> shells_parsed.json
python3 scripts/probe_shells.py                # totalSupply + first-25 ownerOf -> probe_*.json
python3 scripts/probe_tails.py                 # tail indices 
python3 scripts/scan_ft_transfers.py           # last 3M-block TransferSingle scan
python3 scripts/scan_attack_window.py          # attack window 250-block chunks
python3 scripts/scan_attack_hot.py             # recursive fine scan of hottest chunks
python3 scripts/check_nonshell.py              # liveness of non-shell ids
python3 scripts/verify_live.py                 # Envoy full scan + 55-triple verification
python3 scripts/build_census.py                # -> census.json
```

Raw Etherscan call (template):
```
https://api.etherscan.io/v2/api?chainid=1&module=logs&action=getLogs
  &fromBlock=0&toBlock=latest&address=0xfaafdc07907ff5120a76b34b731b278c38d6043c
  &topic0=0xf5d46ba34659b65cffb502ef745b2bc248a71051e48eaf9d62bfa59def02afad
  &page=1&offset=1000&apikey=$ETHERSCANV2_API_KEY
```

RPC probe (template, any public endpoint works):
```bash
cast call --rpc-url "$RPC" --block 26152685 \
  0x0f1f62c38fa21da98bdcfb2f06e8a20dba979791 "ownerOf(uint256)(address)" \
  43648189888285219791758562213502959110711528811875759294532057304950080798722
# -> 0xbBC52f6551053F1bCe454b4B622cc67069f70a69
```

## File index

| file | content |
|------|---------|
| `census.json` | machine-readable census (shells + owners + live triples + attack + FT + verification) |
| `adapter_created_events.json` | all 395 shell-creation events (decoded + raw logs) |
| `shells_parsed.json` | decoded shell list |
| `probe_totalSupply.json` | totalSupply per shell at block 26,152,529 |
| `probe_owners.jsonl` | first-25 owner scans per NFT shell |
| `probe_tails.jsonl` | tail samples for N>25 shells |
| `envoy_full_scan.json` | full 61-item Envoy Badge scan |
| `live_verification.json` | 55/55 Envoy live triples (shell+PA+balance+code) |
| `nonshell_liveness.jsonl` / `nonshell_summary.json` | 3,846 non-shell ids, 863+34 live |
| `nonshell_verification.json` | 9/9 non-shell samples cross-checked |
| `ft_events_filtered.json` | 92 FT sweep events |
| `attack_window_events.json` / `attack_window_events_fine.json` | attack-window TransferSingle logs |
| `cast_evidence.txt` | cast transcript for a live Envoy item |
| `raw/` | raw Etherscan JSON pages (shell creation, TransferSingle scans) |
| `scripts/` | every script used (idempotent, resumable) |
