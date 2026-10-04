# ZeroLend — zkSync Era, Blast, Manta, Abstract, Linea, X Layer, Hemi, Berachain (+base/eth empty)

## Status & shutdown evidence (sources, dates)
- **2026-02-16/17**: ZeroLend announced full wind-down ("we have made the difficult decision to wind down operations"), citing inactive chains, oracle providers **discontinuing support**, and security threats. Sources: zerolend.xyz banner "ZeroLend has Wound Down"; Coindesk 2026-02-17; Decrypt/Yahoo 2026-02-17; cryptorank news (TVL $359M → $6.6M).
- DefiLlama lending adapter **delisted** (`api.llama.fi/protocol/zerolend` → `module: null`), TVL still cached: zkSync $855,467, Blast $478,014, Manta $54,663, Abstract $32,222, Linea $13,097 (+staking $4,074, pool2 $5,692), X Layer $9,166, Hemi $2,911, Berachain $4,896, borrowed **0** on all chains (WRONG — see below).
- ZeroLend Vaults (Euler curator) adapter still live (`zerolend-vaults/index.js`): Ethereum $1,845,041, Linea $3,027, Berachain $4,896, Sonic $0.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
All pool proxies confirmed with code; addresses from `zerolend/docs.zerolend.xyz/security/deployed-addresses.md` (fetched raw) cross-checked on-chain (`ADDRESSES_PROVIDER()`, `getReservesList()`). Pool impls are Aave V3.0.2-family forks (15-field `getReserveData` with `uint16 id` decodes cleanly; `getReserveTokensAddresses` NOT present).

| chain | Pool proxy | impl | AddressesProvider | ACLAdmin / provider owner | oracle | block |
|---|---|---|---|---|---|---|
| zkSync Era (324) | 0x4d9429246EA989C9CeE203B43F6d1C7D83e3B8F8 | 0x54d6f91b… | 0x4f285Ea1… | 0x1890f9204882dfa1b8f0aeaf56ae9b2ed149d18d | 0x785765De… | 72,326,850 |
| Blast (81457) | 0xa70B0F3C2470AbBE104BdB3F3aaa9C7C54BEA7A8 | 0x3fC90e52… | 0xb0811a1F… | 0xa01afbe9… / owner 0x00000ab6ee5a6c1a7ac819b01190b020f7c6599d | 0xBE0ab675… | 41,143,294 |
| Manta (169) | 0x2f9bB73a8e98793e26Cb2F6C4ad037BDf1C6B269 | 0x8676e39b… | 0xC44827C5… | 0xd10da579… / owner 0x4dcf6a8a… | (wrong oracle addr in docs; getPriceOracle broken) | 9,687,247 |
| Linea (59144) | 0x2f9bB73a8e98793e26Cb2F6C4ad037BDf1C6B269 | 0x02276e00… | 0xC44827C5… | 0x14aad466… | 0xFF679e5B… | 32,226,099 |
| X Layer (196) | 0xfFd79D05D5dc37E221ed7d3971E75ed5930c6580 | 0xAdC1eb4e… | 0x2f7e54ff… | 0xd5381236… / owner 0x00000ab6… | 0x78Ad3d53… | 72,328,225 |
| Hemi (43111) | 0xdB7e029394a7cdbE27aBdAAf4D15e78baC34d6E8 | 0x59423CCe… | 0x9660b39d… | 0x529a149b… | 0x817A4FEd… | 5,435,905 |
| Abstract (2741) | 0x7C4baE19949D77B7259Dc4A898e64DC5c2d10b02 | 0xfc1ef22b… | 0xde15Bc70… | 0x40badb5c… | 0xFf2D78CB… | 86,680,490 |
| Base (8453) | 0x766f21277087E18967c1b10bF602d8Fe56d0c671 | 0xb3d7c6b4… | 0x5213ab39… | 0x6f5ae60d… | 0xF49Ee3EA… | 52,154,196 |
| Berachain (80094) | 0xE96Feed449e1E5442937812f97dB63874Cd7aB84 | 0x642ce49f… | 0x33B13F46… | 0x4208d11f… | 0xA249579e… | 27,041,723 |
| Ethereum LRT (1) | 0x3BC3D34C32cc98bf098D832364Df8A222bBaB4c0 | 0xd37c2308… | 0xFD856E1a… | 0x4E88E72b… | 0x1cc993f2… | 26,117,446 |

Notes: `paused()` on the Pool reverts on all chains (fork predates pool-level pause) — pause state lives in each reserve's config bit 60. Sources not all verified on explorers (impl addresses from docs, code present). Provider owner/ACL admin are live EOAs/multisigs (listed above), not renounced.

## Live balances (token, amount, USD, price source, block)
Measurement = `underlying.balanceOf(aTokenAddress)` (Aave V3 holds liquidity in aToken contracts) + `aToken`/debt `totalSupply` read via `getReserveData` at pinned block; prices `coins.llama.fi/prices/current/{chain}:{addr}` (~2026-10-04, ts≈1791100310). Raw: `raw/zerolend_stage2_*.json`, `raw/zl_analysis.txt`.

| chain | measured pool liquidity USD (priced) | debt outstanding (debt-token totalSupply, nominal) | reserve pause/freeze state |
|---|---|---|---|
| zkSync Era | **~$854,294** (USDC.e 94,555.9; WETH 188.52; USDT 20,137.2; LUSD 2,087.1; WBTC 0.6402; DAI 8,905.8; ZK 4,589,631; USDC 33,519.0; USN 987.1; +dust) | ~$344.8K (USDC.e 94,054.9; WETH 54.68; USDT 48,083.5; DAI 17,594.6; LUSD 10,006.6; ZK 140,018.7; USDC 22,359.2; …) | top reserves **PAUSED** (bit60=1: USDC.e, WETH, USDT, WBTC, DAI, ZK, USDC…); some frozen (ONEZ, LUSD, M-BTC, USN) |
| Blast | **~$477,858** (USDB 116,652.7; WETH 126.27; ezETH 7.139; weETH 0.436) | ~$93.7K (USDB 36,181.0; WETH 15.23; ezETH 5.76) | all reserves **PAUSED** |
| Manta | **~$54.7K** (wUSDM 29,162.7 tokens unpriced by DefiLlama≈$1 → ~$31.5K; MANTA 171,404.8×$0.0724=$12.4K; USDT 4,550.2; STONE 1.99×$2,877=$5.7K; TIA 436.9; unk 0.1055) | debt tokens non-zero, incl. **stale-marked positions**: TIA 394,517; STONE 1,458.8; USDT 29,921; WETH 125.23; MANTA 43,940; wUSDM 5,152.4 — nominal marks unreliable (oracle feeds dead, see below) | not paused; frozen: TIA, wUSDM, MANTA; unfrozen: STONE, USDT, WETH |
| X Layer | **~$9,190** priced (WOKB 55.15×$120.9=$6.7K; WETH 0.4934; USDC 2,597.5 unpriced; WBTC 0.0107; USDT 285.0) **+ 499,943 USDz tokens (“ZAI Stablecoin (OFT)”, 18d, unpriced by DefiLlama — if $1 then +~$0.5M; reserve frozen+paused+ltv0)** | ~$74.8K nominal (WOKB 409.99; WETH 8.859; USDC 1,659.4; USDT 1,350.8; DAI 198.7; USDz 56,003.6; WBTC 0.0002) | all reserves **PAUSED**; USDz frozen |
| Hemi | **~$2,912** (USDC.e 1,540.6; WETH 0.3595; USDT 254.1; rsETH 0.0239 — oracle reads fail for all) | ~$1.8K (USDC.e 1,739.9; WETH 0.0045; USDT 40.4; BTC dust) | not paused; rsETH frozen; oracle calls revert (dead feeds) |
| Abstract | **~$32,217** (WETH 10.79=$29.0K; USDC.e 1,374.4; USDT 674.8; PENGU 120,957=$1.1K) | ~$6.2K (USDC.e 1,905.9; WETH 1.289; USDT 557.3; PENGU 25,515) | all reserves **FROZEN** (no new supply/borrow) |
| Berachain | **~$845** (USDC.e 678.5; WBERA 243.4=$55; WETH 0.0047; BUSD 11.4; others dust) | ~$844 (WBERA 3,690.7 only meaningful) | not paused/frozen; oracles stale (BUSD/NECT ~928h) or aggregator-composites |
| Linea | **$0 pool liquidity** (all 20 reserves zero; DefiLlama $13K is staking $4.1K + pool2 $5.7K, not the pool) | none detected in pool | n/a |
| Base | **$0** | $0 | n/a |
| Ethereum LRT pool | **$0** (all 12 reserves zero) | $0 | n/a |

Total measured pool liquidity ≈ **$1.40M** (excl. X Layer USDz unpriced; matches DefiLlama chain sums). DefiLlama `borrowed=0` is false: ~$520K nominal debt across era/blast/xlayer/abstract/hemi + Manta.

## Permissionless paths examined (path → gates → live values → verdict)
Deployed fork matches Aave V3.0.2 validation logic (upstream v1.17.2 source fetched: `ValidationLogic.sol`); reserve `paused` bit = config bit 60, verified = 1 for major reserves (e.g. era USDC.e config raw decodes ltv=8000, active=1, frozen=0, borrowEnabled=1, **paused=1**).
1. **supply / borrow / flashLoan**: `validateSupply`, `validateBorrow`, `validateFlashloan` all `require(!isPaused)`. Paused reserves (era top, all Blast, all X Layer, most xlayer) → **blocked**. No stale-oracle borrow can be initiated on paused reserves. Verdict: no path.
2. **withdraw / redeem aTokens**: `validateWithdraw` also `require(!isPaused)` in this fork → **suppliers cannot withdraw while paused** (funds bricked; admin unpause required). This is the dominant state: ~$1.37M of the $1.40M sits in paused/frozen reserves. Verdict: **S/P**, not H-O.
3. **liquidationCall**: `validateLiquidationCall` `require(!paused)`. Stale feeds (era 31–35 days old: USDC.e 757h, USDT 842h; Blast 323h; Manta 356 days) are NOT exploitable via liquidations while paused. **Residual candidate**: Manta unfrozen reserves (STONE/USDT/WETH) have dead/bogus oracles — a mispriced borrow/liquidation there is not blocked by pause; value small (~$4.5K USDT + $5.7K STONE). Flag for fork-test: `supply(STONE) → borrow(USDT)` with Manta oracle; only if the STONE feed returns a wrong non-reverting price.
4. **repay**: paused too (borrowers cannot repay while paused) — no profit path.
5. **mintToTreasury / updateInterestRates**: treasury-directed accounting only; `accruedToTreasury` minted to treasury; no attacker value. `unbacked` = 0 on main reserves (era USDC.e unbacked 0; only ~1,313 USDC was shown under the older mis-decoded slot earlier — final 15-field read = 0).
6. **Donation / inflation**: N/A to Aave V3 scaled balances (index-based positions; direct token donations do not change any redeemable claim).
7. **rescueTokens / setReserveInterestRateStrategyAddress / setAssetOracle / config changes**: not present as permissionless; Aave V3.0.2 family — admin/ACL-gated (P). Provider owner/ACL admin are live addresses on each chain.
8. **Linea staking/pool2 (~$4.1K + $5.7K)** and **Ethereum staking contracts**: NOT examined on-chain (time-boxed); mark unverified/out-of-scope this pass.

### ZeroLend Vaults (Euler curator; `zerolend-vaults` adapter)
- Ethereum Euler vaults: `0xc42d337861878baa4dc820d9e6b6c667c2b57e8a`, `0x1ab9e92cfde84f38868753d30ffc43f812b803c5`, `0xc364fd9637fe562a2d5a1cbc7d1ab7f32be900ef`; Linea: `0x14efcc1ae56e2ff75204ef2fb0de43378d0beada`, `0x085f80df643307e04f23281f6fdbfaa13865e852`, `0x9ac2f0a564b7396a8692e1558d23a12d5a2abb1f`; Berachain (6 vaults): `0x28C96C7028451454729750171BD3Bb95D7261B5a` … (full list in `raw/zerolend_vaults_adapter.js`); curator multisigs `0x54061E18cd88D2de9af3D3D7FDF05472253B29E0`, `0x4E88E72bd81C7EA394cB410296d99987c3A242fE`, `0x1f906603A027E686b43Fab7f395C11228EbE8ff4`.
- **Not measured on-chain in this pass** (time-boxed). EVK mechanics: deposits/withdrawals are permissionless (`Vault.withdraw/deposit` subject to EVC account status and hook), the curator/owner can change caps/hooks/interest model but **cannot seize a healthy depositor's principal**; a liquidity shortage (borrows outstanding) can delay but not re-route withdrawals. No unprivileged seize path identified from architecture. DefiLlama Ethereum $1.85M unverified; **confidence low** — parent should measure `totalAssets()`/`totalSupply()` and hook/caps if this matters.

## Approvals / user-side residual risk
- User aToken balances are claims on paused reserves; withdraw blocked until an admin unpauses (owner addresses live, e.g. era 0x1890f920…, blast/xlayer 0x00000ab6…). Debt-token holders conversely cannot repay while paused.
- No protocol-held user allowances identified as live extraction vectors in the pool contracts.
- X Layer pool holds 499,943 `USDz` ("ZAI Stablecoin (OFT)") with no reliable price (DefiLlama returns none); reserve paused/frozen — value unverified.

## Classification: S (stuck, paused-reserve suppliers) + H-O (small unpaused pools) — measured $1.40M priced (+ ~$0.5M X Layer USDz unpriced; + Euler vaults $1.85M unverified) — E-U $0 proven — confidence medium
- **S/P ~$1.37M**: zkSync top reserves, Blast, X Layer (incl. USDz) — all actions blocked by `paused`; only pool admin (live but private keys unknown) can unpause.
- **S/frozen ~$32K**: Abstract (frozen, no withdraw-free guarantee), Manta frozen reserves.
- **H-O ~$3–55K**: Manta unfrozen (STONE/USDT/WETH) and Hemi — funds withdrawable only if liquidity available and oracle/preconditions allow; oracles dead there.
- **E-U $0 proven.** Candidate for fork test (only remaining plausibility): Manta unfrozen reserves with dead oracles (borrow/liquidate at wrong price, up to ~$10K), and IF the parent finds the paused bit is ignored by ZeroLend's exact ValidationLogic fork (upstream says it is not), stale-oracle borrow/liquidation could reach $500K+. What would change the verdict: a reserve observed with `paused=0 AND frozen=0 AND borrowingEnabled=1 AND stale/ manipulable oracle AND liquidity>0`; or admin unpausing (turns S→H-O).
- **What would change it**: parent fork-test `withdraw()` on era USDC.e aToken holder (expect RESERVE_PAUSED revert), `supply/borrow` on Manta STONE/USDT (oracle misprice), and Euler vault `withdraw` on Ethereum.

## Raw evidence index (files in analysis/)
- `raw/zerolend_stage1.json` — pool state, reserves lists, oracles per chain (first pass)
- `raw/zerolend_stage2_<chain>.json` — getReserveData (15-field), aToken addresses, `underlying.balanceOf(aToken)`, debt token totalSupply, config bit decode, oracle `latestRoundData` (era/blast/manta/linea/xlayer/hemi/abstract/base/berachain/eth_lrt)
- `raw/zl_analysis.txt` — per-reserve liquidity/debt/USD/price + pause/frozen/borrow flags + oracle feed ages
- `raw/zl_docs_deployed_addresses.md`, `raw/zl_dep_*.md` — official/ZeroLend deployment docs
- `raw/zerolend_vaults_adapter.js` — Euler curator adapter (vault + multisig addresses, hallmarks)
- `raw/zerolend_adapter.js` — (404; lending adapter delisted upstream)
