# C-35 — Old chain/contract resurgences: live unprivileged-extractability deep dive

**Campaign:** zombie-hunt · **Chain:** Ethereum mainnet · **Date of work:** 2026-10-03
**Status:** read-only research. Fork-only PoC/boundary tests; **no mainnet transactions signed or sent.**
**Latest block used:** 26,108,927 (2026-10-03). All balances/state re-read at that block unless stated.

**Headline: an external, unprivileged attacker can extract ≈ $0 from every target in this finding.**
Both named contracts (HongCoin, Liquality) had their stuck funds *unblocked* by the 2026 whitehat rescues and
the money now flows **only to the original holders** (H-O). The rest of the sample (top live-ETH legacy
contracts + the previously-uncovered focus list: FoMo3D Ultra, CryptoCats, Transit, Zethr, Bingo4Beast dep2,
DailyDivs/ReadyPlayerONE, FEG fETH, F3D-family clones) is self-service custody, holder-only, privileged, or
literally stranded. The largest single unprivileged-extractable path found is **none**; the largest
*attacker-adjacent* nominal value is a ≤0.39 ETH probabilistic F3D airdrop share that is negative-EV.

---

## 1. TL;DR — verdict table

| # | Target | Chain | Live ETH (26,108,927) | E-U extractable | Class | Why closed / open | Latent risk |
|---|---|---|---:|---:|---|---|---|
| 1 | **HongCoin ICO** `0x9fa8fa61…` | eth | 727.974 | **$0** | H-O | 2026-05-27 unlock reset eligible holders' token balances; `refundMyIcoInvestment()` pays only the caller's own 2016 `weiGiven`. Attacker call reverts (`noWeiGiven`); admin overflow fn is behind the team multisig (`onlyManagementBody`) | none unprivileged; 44 remaining holders can still claim |
| 2 | **Liquality** 2018 ICO `0xf8602dfa…` | eth | 0.000 | **$0** | H-O | refund function paid the nine original contributors on 2026-05-24; contract now empty | none |
| 3 | **Liquality HTLCs** (7 contracts) | eth | 0.000 | **$0** | H-O | trigger is permissionless but the 200-byte runtime SELFDESTRUCTs to the hardcoded participant; all 7 drained on 2026-05-24 (14.1908 ETH total) | none |
| 4 | **FoMo3D Ultra** `0xab83d96d…` | eth | 466.116 | **$0** | H-O/S | unverified F3D variant: `withdraw()` pays the caller's own player vaults; ~130.9 ETH mapped to 163 players, ≈335 ETH in player-keyed round/jackpot/community pots; fresh EOA gains 0 from every no-arg value path | none unprivileged; gameplay airdrop pot 0.208 ETH |
| 5 | **CryptoCats v0/v1** `0x95080082…` | eth | 43.685 | **$0** | S/H-O | v3 changelog bug ("ETH sent in with `getCat` withdrawable by owner") never fixed here → ~34.9 ETH stranded with no credit/sweep; `pendingWithdrawals(attacker)==0`, `withdraw()` no-op | none |
| 6 | **Transit Finance Refund** `0xc213f258…` | eth | 160.746 | **$0** | P→H-O | `claimPause==true`, `claim()` reverts "Refund suspended"; `emergencyWithdraw` is executor-Safe-gated | owner can unlock claims (H-O); executor Safe can sweep while paused |
| 7 | **Zethr** `0xd48b6330…` / **Zethr Casino** `0xb9ab8eed…` | eth | 276.744 / 111.684 | **$0** | H-O/S | P3D-style `exit()`/`withdraw(address)` pay only the caller's own dividends; fresh EOA 0 successes, 0 gain | holder-only |
| 8 | **Bingo4Beast deploy 2** `0x4fb7d68e…` | eth | 84.483 | **$0** | H-O/S | "stones" F3D variant, round-mask accounting partially insolvent; `withdraw()` from fresh reverts "withdraw fail" | holder first-mover race (H-O) |
| 9 | **DailyDivs** `0xd2bfceea…` / **ReadyPlayerONE** `0x6db94325…` | eth | 109.684 / 24.539 | **$0** | H-O | `isHuman` (`tx.origin==msg.sender`) blocks contract wallets; `withdraw()` pays own dividends/vaults; fresh EOA gains 0 | EOA holders only |
| 10 | **FEG Wrapped ETH (fETH)** `0xf786c341…` | eth | 386.601 | **$0** | H-O/S | `withdraw()` is self-only (0.99 ETH/token); ~33.9 ETH surplus/fees has no redeem fn; **no Uniswap V2 pair** → no market path | none |
| 11 | F3D family: LastWinner 2,425.428 · F3D Long 1,099.453 · F3Dshort v2 136.636 · Quick 84.140 · Short 76.253 · FoMoJP 72.912 · Bingo Long 120.196 | eth | 4,015.0 total | **$0** | H-O | self-scoped vault payouts; `airdrop()/potSwap()` need keys (negative-EV) | probabilistic airdrops ≤0.39 ETH |
| 12 | Top-15 re-checks (IDEX, EtherDelta v2, zkSync Lite, Neufund v1, Unknown DEX, PoWH3D, Old WETH, Ethfinex, SingularX, Augur v1, 0x0 Rewards, GandhiJi, Token.Store, MCDEX, …) | eth | ~35,000+ | **$0** | H-O | all self-service / Merkle-claim / holder-only; see §5 and `zombie-deep/LIVE-PROFIT-PATHS.md` (byte-identical recompiles, forged calls revert) | holder-only; zkSync's owner Safe can pause (liveness) |

**Total live extractable by an external unprivileged attacker across the sample: ≈ $0.00. Confidence: high.**
(ETH price is irrelevant at zero; CoinDesk snapshot 2026-10-01 ~$2,695/ETH is used only for context.)
**Largest H-O pools:** zkSync Lite distributor ~10,927 ETH (Merkle claimants; −263 ETH claimed in the 4 days
between 2026-09-29 and 2026-10-03), Neufund EtherToken v1 3,385 ETH, IDEX+EtherDelta ~30,900 ETH,
HongCoin 728 ETH (46 investors), Old WETH 1,511 ETH (fully backed 1:1).

---

## 2. The C-35 mechanism in exact terms

C-35 is the "decade-old contract with funds and no withdrawal path" class. Two flavours matter:

1. **Rescued but still holder-gated (HongCoin, Liquality).** Both bugs were real and were *fixed by
   permissionless-feeling whitehat transactions*, but the payout destinations are hardcoded to the original
   depositors. The rescue changed **who can trigger** the payment, never **who receives** it:
   - HongCoin: `refundMyIcoInvestment()` (selector `0xe84f7054`) requires
     `weiGiven[msg.sender] > 0` and `balances[msg.sender] <= tokensCreated` (line 385-394 of the verified
     0.3.5 source). The 2026-05-27 unlock used `mgmtIssueBountyToken(address,uint256)` with an integer
     overflow to wrap selected holders' `balances` back under the (long-dragged) `tokensCreated == 350`.
     `mgmtIssueBountyToken` is `onlyManagementBody` = the team's 2016 Gnosis `Wallet` multisig
     `0xb79Ab5993Cef2E0B714A66F3edA73b55DE812D31`; its `execute()` is `onlyowner`. An attacker cannot mint
     `weiGiven`, cannot become a holder of record, and cannot call the admin function.
   - Liquality: each swap is a 200-byte contract that computes `sha256(calldata)` and compares it with a
     hardcoded secret; on match it SELFDESTRUCTs to the hardcoded claim beneficiary, and on empty calldata
     after the hardcoded timelock it SELFDESTRUCTs to the hardcoded refund beneficiary (disassembly in
     `analysis/liquality_htlc1_disasm.txt`). **The caller is never the payee.** The Jan-2018 ICO contract's
     public refund loops over its nine recorded contributors.
2. **Never rescued, still sealed (CryptoCats, Bingo dep2, parts of Ultra/Zethr).** Value accumulated in a
   contract whose only inflow paths credit players/holders; there is no sweep, no owner escape, and the
   outsider gets nothing. These are S (nobody) or H-O (holders race), not E-U.

## 3. Live-state assessment (every address read on-chain)

| Address | Role / check | Value at 26,108,927 |
|---|---|---|
| `0x9fa8fa61a10ff892e4ebceb7f4e0fc684c2ce0a9` | HONG; `tokensCreated()==350`, `managementBodyAddress()==0xb79Ab5…`, `isFundLocked()==false` | 727.9738432374239 ETH |
| `0xb79Ab5993Cef2E0B714A66F3edA73b55DE812D31` | team Gnosis `Wallet` (verified); unlock caller `0x1212ce…` is owner | 0.000140 ETH |
| `0x1212ce5652b20c0a8ce493458a5c99db24ed2925` | unlock executor (EOA owner of the multisig) | 0.000140 ETH |
| `0xf8602dfa933a34d513e6e1aab3f3cc6861254d51` | Liquality 2018 ICO; refund split to 9 contributors on 2026-05-24 | 0 |
| 7 Liquality HTLCs (see notes §1.2) | runtime SELFDESTRUCTs to hardcoded beneficiaries | all 0 |
| `0xab83d96de35bad6f234178fbb6507203488e9626` | FoMo3D Ultra; `rID_==11`, `airDropPot_==0.208443270385016504`, `getTimeLeft()==0`, `activated_==true` | 466.1161820440316 ETH |
| `0x9508008227b6b3391959334604677d60169ef540` | CryptoCats v0/v1; `pendingWithdrawals(0xA11C)==0`; `withdraw()` no-op | 43.685 ETH |
| `0xc213f258f4142f53d086f9edb7a36e67eb347f63` | Transit; `claimPause()==true`, `claimStartTime()==1665151800`, owner `0x857691…`, executor `0x7e5c15…` (Gnosis Safe proxy) | 160.7458 ETH |
| `0xd48b633045af65ff636f3c6edd744748351e020d` / `0xb9ab8eed48852de901c13543042204c6c569b811` | Zethr / Zethr Casino; `withdraw(address)`/`exit()` self-scoped | 276.7442447 / 111.6839129 ETH |
| `0x4fb7d68e0116f35ade131b6535b2db1027bf7650` | Bingo4Beast dep2; `withdraw()` reverts "withdraw fail" for non-player | 84.48305737 ETH |
| `0xd2bfceeab8ffa24cdf94faa2683df63df4bcbdc8` / `0x6db943251e4126f913e9733821031791e75df713` | DailyDivs / RPO; `isHuman`+`notContract`; self-scoped withdrawals | 109.6839133 / 24.5390870 ETH |
| `0xf786c34106762ab4eeb45a51b42a62470e9d5332` | fETH; `totalSupply==352.731135584312945722`, `getPair(fETH,WETH)==0x0` | 386.6005996 ETH |
| `0x0a14b696350546110a0d8acdb86226983af9d2a0` | zkSync Lite sunset distributor; `paused()==false`, `owner()==0xE24f4870…` (Safe proxy) | 10,926.7560672 ETH |
| `0xb59a226a2b8a2f2b0512baa35cc348b6b213b671` | Neufund EtherToken v1 (100% backed per zombie-deep) | 3,385.4289228 ETH |
| `0x2a0c0dbecc7e4d658f48e01e3fa353f44050c208` / `0x8d12a197cb00d4747a1fe03395095ce2a5cc6819` | IDEX v1 / EtherDelta v2; fresh `withdraw` gains 0 | 15,729.7743 / 15,168.5747 ETH |
| `0x4d55f76ce2dbbae7b48661bef9bd144ce0c9091b` | "Unknown DEX" = EtherDelta v0.4.9 recompile (zombie-deep) | 2,479.0875147 ETH |
| `0xecf8f87f810ecf450940c9f60066b4a7a501d6a7` | Old WETH; `totalSupply == balance` to the wei (1:1 redeem) | 1,511.3469866 ETH |
| `0xdd9fd6b6f8f7ea932997992bbe67eabb3e316f3c` | Last Winner; `airDropPot_==0.3891138`, `rID_==622` | 2,425.4275639 ETH |

Full per-target table incl. 50 addresses: `analysis/balances_20261003.json`, `ci-out/scan_report.md`.

## 4. What an attacker can / cannot do

- **HongCoin:** can call `refundMyIcoInvestment()` — reverts `noWeiGiven` for anyone without a 2016
  position; can call `mgmtIssueBountyToken` — reverts (`onlyManagementBody`). Cannot manufacture `weiGiven`.
  Cost of the attempt: ~50k gas; profit: 0.
- **Liquality HTLCs:** can call them with empty calldata — the tx succeeds and pays the hardcoded original
  participant (fork-proven); profit: 0. ICO contract: empty; nothing to call.
- **FoMo3D Ultra:** can call `withdraw()`, `airdrop()`, `potSwap()`, `activate()` and 4 unmapped
  selectors from a fresh EOA — 0 ETH delta, contract balance unchanged (fork-proven). To touch the pots one
  must buy keys (ETH in, negative-EV) and win a game-theoretic race; an outsider with no keys gets nothing.
- **CryptoCats:** `pendingWithdrawals(attacker)==0`; `withdraw()` moves nothing. The 34.9 ETH `getCat`
  inflow has no credit path at all (v3 fixed it by crediting the owner; v0/v1 has no sweep).
- **Transit:** `claim()` reverts "Refund suspended" (`claimPause==true`); `emergencyWithdraw` reverts for
  non-executor. Only the owner EOA (`setClaim`) / executor Safe can move the 160.75 ETH.
- **Zethr / Zethr Casino / DailyDivs / RPO / F3D clones:** `withdraw`/`exit` paths pay only the caller's own
  recorded balances; fresh EOA = 0. `isHuman` additionally blocks contract wallets.
- **FEG:** `withdraw(1)` reverts "invalid amt" for a zero balance; there is no DEX pair to acquire fETH
  below NAV, so the ~33.9 ETH over-backing is unreachable (S) rather than an arb.
- **Bingo dep2:** `withdraw()` reverts "withdraw fail" for non-players; the insolvency is a holder race.
- **Top-15:** identical shape — byte-identical recompiles (zombie-deep) show per-address ledgers; forged
  withdraw/trade calls revert; Merkle distributors pay only the leaf claimant.

Costs: all attacker attempts are gas-only and revert/no-op, so net ≤ 0. No flash loans or capital can open a
path because no function credits the caller from another account's balance.

## 5. PoC / fork verification

Foundry project `poc/` (vendored `lib/forge-std`), suite `test/C35Sweep.t.sol`, **14/14 tests PASS**.

| test | proves |
|---|---|
| `test_01_live_balances_snapshot` | balances at fork block; HONG/Ultra/zkSync/Transit funded |
| `test_02_hongcoin_attacker_paths_revert` | fresh EOA: refund reverts, admin fn reverts |
| `test_03_hongcoin_holder_refund_open_HO` | eligible holder `0x30d1f875…` gains exactly 0.07 ETH (H-O) |
| `test_04_liquality_htlc_permissionless_but_pays_beneficiary` | replica of HTLC_1 runtime: caller triggers, 6.674 ETH goes to hardcoded beneficiary, caller +0; all 7 live HTLCs + ICO are 0 |
| `test_05_ultra_fresh_attacker_no_gain` | 8 selectors from fresh EOA; 0 gain, contract delta 0; pot/timeLeft recorded |
| `test_06_fomo3d_long_fresh_attacker_no_gain` | same for F3D Long |
| `test_07_cryptocats_pending_and_withdraw_zero` | `pendingWithdrawals==0`, withdraw no-op |
| `test_08_transit_claims_paused_executor_gated` | claim + emergencyWithdraw both revert |
| `test_09_zethr_fresh_attacker_no_gain` | Zethr + Casino: 0 successes, 0 gain, balances unchanged |
| `test_10_dailydivs_rpo_fresh_attacker_no_gain` | DailyDivs reverts; RPO no-ops; 0 gain |
| `test_11_feg_no_market_and_self_only_withdraw` | `getPair==0`, withdraw reverts |
| `test_12_bingo2_withdraw_reverts_for_fresh` | withdraw reverts, balance unchanged |
| `test_13_zksync_authority_state` | `paused==false`, owner = Safe proxy, 10,926 ETH |
| `test_14_legacy_dex_fresh_withdraw_no_gain` | IDEX / EtherDelta v2 / Unknown DEX: 0 gain, balances unchanged |

Heavy scan (CI job `ci/run.sh` → `ci/scan.py`): 50-target balance+code snapshot, PUSH4 selector extraction,
signature mapping + OpenChain lookups, value-out selector flags, F3D-family raw state, fETH pair check.
Artifacts: `ci-out/scan_report.json`, `ci-out/scan_report.md`, `ci-out/liquidity_check.json`.

**CI runs:**
- run 1: `<pending>`

## 6. Verdict and residual risk

**Verdict: E-U ≈ $0 (high confidence).** No external unprivileged extraction path was found in the two named
contracts or in the 50-contract sample. The rescues did not leave a public drain behind; the unblocked value
is H-O. Latent/privileged risk that remains (not E-U):

- **zkSync Lite (~10,927 ETH):** owner Safe can pause claims (liveness risk); proof verifier still unaudited.
- **Transit (160.75 ETH):** a single owner EOA (`0x857691…`) controls `setClaim`; the executor Safe can
  `emergencyWithdraw` while paused. Key compromise would be theft — privileged, not permissionless.
- **IDEX / EtherDelta / Unknown DEX (~33,377 ETH):** admins can redirect fee accounts / relay signatures;
  per-address ledgers remain solvent for the ETH side. Non-ETH token solvency was not exhaustively audited.
- **Bingo dep2 / PoWH3D / Zethr (~410+ ETH "holes"):** index-attested over-claims mean late holders eat the
  shortfall (H-O first-mover races), not attacker profit.
- **FoMo3D Ultra (~335 ETH unmapped):** player-keyed pots on unverified code; a future player-side bug
  cannot be excluded without a full decompile, but no outsider path exists today.
- **CryptoCats 34.9 ETH / FEG ~37 ETH / Zethr bankroll:** stranded (S); no sweep exists.

Blockers to any E-U conclusion: none material — every candidate path was exercised on a fork and either
reverted or paid only the recorded holder. The unverified contracts (Ultra, CryptoCats, Bingo dep2,
LastWinner) were assessed via selector dispatch + live-call boundary tests, not source review; that is the
main residual uncertainty, and it is bounded by the fresh-attacker fork probes.

## 7. Methodology, sources, caveats, files

**Method:** corpus triage (FINDINGS C-35, `github_stuck_funds.md` §1.1/§1.3/§6, `zombie-deep` conclusions),
web/primary-source recovery of the two rescue incidents (thirdweb blog, CoinDesk, 0xflorent X threads,
rentry eligible-address list), exact on-chain re-verification (Etherscan V2, public RPC, OpenChain 4byte),
selector extraction from live bytecode, fork boundary tests via Foundry on GitHub Actions.

**Sources:** thirdweb "Whitehat Researcher Recovers $2M…" (2026-06-02); CoinDesk (2026-06-01); X threads
`2061070356564091258` and `2058526763370594329`; rentry.co/hongcoin-recovery-1873;
forgotteneth.com + `q84c6tsm95-create/forgotten-eth` mirror; `zombie-deep/LIVE-PROFIT-PATHS.md`;
`zombie_hunt/github_stuck_funds.md`; Etherscan V2 (`hong_unlock_txs.json`, `florent_wallet_txs.json`,
`liquality_rescue_internals.json`).

**Caveats:** (1) E-U is a statement about paths *found and exercised*, not a formal proof over unverified
bytecode; (2) balances move (zkSync −263 ETH in 4 days, IDEX −11 ETH) — the snapshot block is recorded;
(3) USD is 0 regardless of ETH price; (4) no mainnet transaction was attempted, and none should be.

**Files:** `README.md` (this), `summary.json`, `analysis/notes.md`, `analysis/balances_20261003.json`,
`analysis/hong_source.sol` + `hong_ms.sol` + `hong_unlock_txs.json`, `analysis/florent_wallet_txs.json` +
`liquality_rescue_internals.json` + `liquality_htlc1_disasm.txt`, `analysis/ultra_balances.json` +
`ultra_raw_state.json`, `analysis/selector_to_sig.json` + `unknown_selector_lookup.json`,
`analysis/{sel_extract,sel_report,batch_balances,fetch_sources,build_selectors}.py`,
`poc/` (Foundry, 14 tests), `ci/run.sh` + `ci/scan.py`, `ci-out/`, `ci-log.txt`, `ci-artifacts/`.
