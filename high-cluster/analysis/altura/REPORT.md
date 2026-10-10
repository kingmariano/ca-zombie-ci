# H2-02 — Altura (HyperEVM) — NavVault / NavOracle — Dossier

**Status: read-only; PoC fork-verified only; no mainnet transactions.** This dossier audits the live
NavVault (`0xd0Ee0CF300DFB598270cd7F4D0c6E0D8F6e13f29`, HyperEVM chain 999) and its NavOracle
(`0x314A79618d86309e91aa972CAfd143ffca80AE8F`). All state was read at explicit blocks (see §1), all
execution happened on local forks pinned at block **48,164,864** inside GitHub Actions CI. No tx was
signed or sent to any live network.

**Headline: E-U = $0** (no unprivileged extraction path; the only value physically inside the vault is
**8 micro-USD₮0**, of which fee rounding caps any payout at **7 micro-USD₮0 ≈ $0.000007**, and only to a
party that already paid NAV for shares — a fresh attacker's round-trip is *net-negative*). The $32.4M NAV
is a book claim on the operator: redeemable via queue→claim **only when the operator funds liquidity**,
which today it has not (vault balance: 8 units; ~$11.67M already queued and waiting).

---

## 1. Live-state table (verified on-chain)

Read block: **48,164,864** (2026-10-10 ~11:32 UTC), core values re-checked across blocks
48,164,862–48,164,866 (identical). Deploy: NavOracle block 22,282,400, NavVault block 22,290,174. RPC:
keyless `https://rpc.hyperliquid.xyz/evm`; explorer: Etherscan V2 `chainid=999`.

| Item | Address / Value | Evidence |
|---|---|---|
| NavVault | `0xd0Ee0CF300DFB598270cd7F4D0c6E0D8F6e13f29` | `eth_getCode` = 14,626 bytes; verified source solc 0.8.21 (optimizer 200, evm=paris); Etherscan `Proxy=0`; EIP-1967 impl/admin/beacon slots = 0x00 |
| NavOracle | `0x314A79618d86309e91aa972CAfd143ffca80AE8F` | code 2,646 bytes; verified source solc 0.8.21; EIP-1967 slots 0x00 |
| asset | `0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb` = USD₮0, 6 dec | `asset()`, `decimals()`; token is a `TransparentUpgradeableProxy` (impl `0xf555a12bffaef20cc201a74ae6513cb4aadb34b9`) |
| oracle pps | `1.094492929356520704e18` | `NavOracle.pricePerShare()` |
| `totalAssets()` | 32,437,234.873245 USD₮0 | `= supply × pps / 1e6` |
| `totalSupply()` | 29,636,794,853,910 raw AVLT | `totalSupply()` |
| **vault USD₮0 balance** | **8 micro-units ($0.000008)** | `USD₮0.balanceOf(vault)` |
| escrowed shares (queued) | 10,662,103,820,489 raw = **35.98% of supply**, ≈ **$11,669,587** | `AVLT.balanceOf(vault)` |
| `accruedExitFeesAssets` | 26,911.525034 (book only) | live read |
| `exitFeeBps` | 10 bps (constructor set 1; changed once at block 25,627,240) | live + `ExitFeeBpsUpdated` |
| `epochSeconds` | 259,200 (3d; constructor set 86,400; changed at block 25,627,523) | live + `EpochSecondsUpdated` |
| `maxAllowedStaleness` | 86,400 (1d; = oracle cap 86,400) | live reads |
| `nextRequestId` | 5,256 (5,255 requests so far; queued shares above) | live read |
| `cumulativeDeposits/Withdrawals` | 77,722,333.13 / 46,300,912.45 (USD₮0) | live read |
| `paused()` / oracle `paused()` | false / false | live reads |
| `pendingOracle` / oracle history | 0x0; `OracleChanged` events: 0 | live + logs |
| `liquidityRecipient` | `0xFC45cF9323A3057899bc681Bcb7F781f87660ADf` | live |
| `maxPpsMoveBps` (oracle) | **0 — no move cap** (never changed; 1 `OracleConfigured` event at deploy) | live + logs |

### Roles (all RoleGranted/RoleRevoked events enumerated via Etherscan V2; no extra holders)

| Role | Contract | Holder | Notes |
|---|---|---|---|
| DEFAULT_ADMIN_ROLE | vault + oracle | `0x2Ae5173dcd5B5c29DcEAC77ee767f01D2bF0F832` | **Gnosis Safe v1.3.0, threshold 2 of 3 EOA owners** (`0xF1497e…`, `0x20B25B…`, `0xBCCaE5…`), no modules, nonce 4 |
| OPERATOR_ROLE | vault | Safe + `0x03987D5FA639023904378614537aC4FAFE1f8813` (EOA) | can `moveAssets`, fee ≤200bps, staleness ≤ oracle cap |
| GUARDIAN_ROLE | vault | `0xfF0C2fBA221cBC1011b294E3803851EE9dF009ef` (EOA) | pause/unpause only |
| REPORTER_ROLE | oracle | `0xc55e3De9085732317eFcfd729d254B8bff7f7Ad2` (EOA) | only writer of NAV/pps |
| GUARDIAN_ROLE | oracle | `0x03987D5F…` (EOA) | pause oracle |

History: initial admin `0xbf33…8ef6e` and initial reporter `0x12f8…d967` (deployer) were **revoked**
(blocks 36,227,384 / 33,251,080/86); admin was moved to the Safe. Reporter changed once (12f8 → c55e at
block 33,227,012). No timelock contract; the only timelock is the vault's 1-day oracle-swap timelock.

### Where the money is (screened, 200 USD₮0 transfers of vault + 141 of liquidityRecipient)

Pattern: deposits accumulate → operator `moveAssets()` to `liquidityRecipient` → 70 onward transfers
(e.g. 125,000 USD₮0 each; strategy/bridge path) to `0xbd151bef567dabf712a811402a27839768a13d70`
(off-vault strategy path) → instant exits are **JIT-funded**: e.g. blocks 45,970,318–319: EOA
`0xFA9573D1…7271` transfers $1.10 in; one block later the vault self-transfers gross $1.099999 and pays
net $1.098899 out (all on-chain ERC20 liquidity in this vault is micro-scale; the $32.4M NAV sits
off-vault). The vault itself is kept at dust (~8 micro).

## 2. Mechanism (verified deployed source, `analysis/altura/src/contracts/`)

**NAV/share accounting is 100% oracle-driven; balances never enter the math.**
- `totalAssets() = supply × ppsScaled / scale` where `ppsScaled = pps1e18 / 10^(18−dec)` (`_oraclePpsScaled`).
- `convertToShares/Assets` use `Math.mulDiv` with `pps` and explicit rounding; deposits round shares
  **down**, mints and withdraws round shares/assets **up**, redeems round **down** — every direction
  favours the vault.
- `_readPps1e18()` requires pps ≠ 0, `block.timestamp ≤ ts + maxAllowedStaleness`, `oracle.isValid()`.

**NavOracle** (`reportNav(pps, ts)`, REPORTER-only, whenNotPaused):
- Constructor cap: `ts ≥ block.timestamp − maxStaleness` (86,400s). **No upper bound on ts** and
  **`maxPpsMoveBps = 0` (no per-report move cap)** — but only the single reporter EOA can call it.
- Live cadence: `NavReported` every ~300s (5 min); sampled moves ≤ 4.75e-6 relative; pps 1.0 → 1.0945
  since Dec 2025 (~0.033%/day yield accrual).

**Money flows:** deposit/mint (whenNotPaused, nonReentrant) → shares. Instant `withdraw/redeem` burns
`gross = net + fee` worth of shares via OZ `_withdraw(caller, address(this), owner, gross, shares)`
(self-transfer of gross, then net to receiver), retains the fee, books it to `accruedExitFeesAssets`.
Queue (`queueWithdrawal`, no oracle read) escrows shares at the vault via self-allowance; `claimWithdrawal`
pays `convertToAssets(escrow)` **with no fee** to the request's receiver, but requires
`USD₮0.balanceOf(vault) ≥ payout` (`InsufficientLiquidity`) and a fresh oracle; `cancelWithdrawal` returns
the exact escrow. `moveAssets` (operator → liquidityRecipient) requires
`balance ≥ amount + accruedExitFeesAssets`. `sweepExitFees`/`rescueToken` are admin-only (asset cannot be
rescued). `pause/unpause` guardian-only. Oracle swap: admin queues, 1-day `ORACLE_TIMELOCK` before
`executeOracleUpdate` (never used). **No proxy/delegatecall in NavVault; not upgradeable.**

## 3. Attacker model — candidate paths, each closed with live values

| # | Candidate unprivileged path | Result | Gate that blocks it (live value) |
|---|---|---|---|
| 1 | Mint/redeem/trade against manipulated pps | **Reverts** | `reportNav` REPORTER-only (`AccessControlUnauthorizedAccount`); fork-proven. No move cap ⇒ a key-holder could, but that is P |
| 2 | Withdraw/redeem more than the vault holds | **Reverts** | vault USD₮0 balance = 8 micro; fork-proven (`B3`, `C`) |
| 3 | Drain the vault's whole balance via fees rounding | **Impossible** | fee `ceil` makes `gross > balance` for the full amount; max net = 7 of 8 micro; fork-proven (`B1/B2`) |
| 4 | Fresh-attacker deposit→extract round trip | **Net-negative** | 9 micro in → 7 micro out (floor mint + fee); fork-proven (`B1`) |
| 5 | Steal queued escrow (`withdraw(owner=vault)` / `redeem`) | **Reverts** | vault never approves anyone ⇒ `ERC20InsufficientAllowance`; fork-proven (`D`) |
| 6 | Claim someone else's withdrawal request | **Reverts** | `NotOwner` (real request #5255, owner `0xc427…e7D`); fork-proven (`D2`) |
| 7 | Donation / first-depositor inflation | **No vector** | `totalAssets` never reads balances; donation leaves NAV & quote unchanged; dust deposits mint 0 shares; fork-proven (`E`, `K`) |
| 8 | Any sweep/harvest/rescue/move without a role (16 entrypoints) | **Reverts** | `AccessControlUnauthorizedAccount` on each; fork-proven (`G`) |
| 9 | Upgrade / delegatecall takeover | **None** | no proxy, EIP-1967 slots zero, source has no delegatecall (`A`) |
| 10 | Reentrancy via asset token | **None** | every value path `nonReentrant`; USD₮0 is a standard OFT (200 sampled transfers exact, no fee-on-transfer) |
| 11 | Even admin/operator extracting today | **Reverts** | `moveAssets`/`sweepExitFees` → `InsufficientLiquidity` (8 micro vs 26,911 booked fees); fork-proven (`H2`) |
| 12 | JIT yield-sniping around `NavReported` | **Not executable today** | needs (a) reporter tx visibility/ordering and (b) exit liquidity; both absent. Fork *simulation* of the accounting only (`J`): +1% report minus 10bps fee ≈ +0.9% — conditional, not live |

**Costs:** none of the closed paths reach a state where gas/fees matter — they revert before transfer.
The only reachable payouts (7 micro) are below any conceivable gas cost.

## 4. PoC — fork tests (`poc-altura/test/NavVault.t.sol`)

Pinned fork: block **48,164,864**; RPC `vm.envOr("HYPEREVM_RPC_URL", https://rpc.hyperliquid.xyz/evm)`;
live amounts read in-test where possible (one deliberate `assertEq(balance, 8)` because the fork block is
pinned; value verified stable across ±2 blocks).

| Test | Proves |
|---|---|
| `test_A_liveState_snapshot` | Every live value in §1; roles; 2-of-3 Safe; EIP-1967 zero |
| `test_B1_freshAttacker_roundTrip_isNetNegative` | 9 micro in → 7 micro out; vault balance never fully drained |
| `test_B2_vaultCannotBeFullyDrained_feeRounding` | `withdraw(vaultBalance)` reverts; a holder can pull at most `deposit − ceil(fee)`; vault never fully drained |
| `test_B3_redeem_boundedByVaultLiquidity_afterOperatorMovesFunds` | Operator moves deposits out (live pattern); redeeming a $1M position then reverts against remaining liquidity |
| `test_C_realQueuedRequest_cannotClaim_untilFunded` | Real open request #5255 (~$101): `InsufficientLiquidity`; after JIT funding: pays **full NAV, no fee**, then closed |
| `test_C2_claim_revertsWhenOracleStale` | Claim reverts `OracleStale` after >1 day without a report, even with liquidity |
| `test_D_stealEscrowShares_isClosed` | Escrow cannot be burned via `owner=vault` |
| `test_D2_claimForeignRequest_reverts` | `NotOwner` on a foreign request |
| `test_D3_queueCancel_roundTrip_neutral` | Cancel returns exactly the escrowed shares; double-cancel reverts |
| `test_E_donation_doesNotInflateNAV` | `fundLiquidity` donation leaves `totalAssets` and quotes unchanged |
| `test_F_rounding_directions` | floor/ceil rounding favours the vault |
| `test_G_allPrivilegedEntrypoints_revertForAttacker` | 16 vault + 2 oracle entrypoints revert for an attacker |
| `test_H1_adminCaps_andOracleTimelock` | staleness ≤ oracle cap; fee ≤ 200 bps; oracle swap 1-day timelocked |
| `test_H2_adminSweepAndMoveAssets_blockedByLiquidity` | Even privileged ops revert `InsufficientLiquidity` today |
| `test_I_staleOracle_blocksMoneyFlows_butEscrowSurvives` | Stale oracle blocks deposit/withdraw/redeem; queue/cancel still work |
| `test_J_conditional_JITyieldSniping_requiresReporterAndLiquidity` | Conditional MEV accounting only (clearly labelled, not an exploit) |
| `test_K_dust_deposits_mintZeroShares` | No free shares from dust |

**CI runs (GitHub Actions, `kingmariano/ca-zombie-ci`):**
- **Final (all green): https://github.com/kingmariano/ca-zombie-ci/actions/runs/38053290770** —
  `poc-altura`: **17 passed / 0 failed / 0 skipped** (fork pinned at block 48,164,864).
- Earlier iterations (kept for the record): 38051081661 & 38051503558 (compile fixes — checksum
  casing / tuple arity), 38052575273 (compiled; 8/17 passed — the 9 failures were test-funding only:
  the live JIT funder EOA holds ~$2.55 at the pinned block; fixed by a fork-only `vm.store` of the
  USD₮0 balance slot 51). Details in `analysis/altura/ci.txt`.

## 5. Verdict

Price source: DefiLlama `hyperevm:0xB8CE59FC…5ebb` = **$0.999068** (ts 1,791,632,878, confidence 0.99);
figures below use the $1 peg with the depegged number in parentheses.

| Category | Amount | Detail |
|---|---|---|
| **E-U** | **$0** (formal dust ceiling **7 micro-USD₮0 ≈ $0.000007**) | Every candidate path is role-gated, allowance-gated, liquidity-gated or rounding-closed. The only unprivileged payouts possible are bounded by the vault's own 8 micro-units, minus the ceil fee; a *fresh* attacker is net-negative (pays 9, gets 7). |
| **H-O** | **$32,437,234.87 nominal** ($32,407,017 ×0.999068) — of which **$11,669,587** already queued | Queue→claim pays full NAV with **no exit fee**, but only when the operator funds liquidity JIT; today the vault holds 8 micro ⇒ self-service value executable today = $0.000008. The remainder is a book claim on the operator. |
| **P** | all roles + **$26,911.53 accrued fees** (book, unsweepable today) + strategy assets outside the vault | admin = 2/3 Safe (vault+oracle), operator = EOA 0398 + Safe, guardian EOAs, reporter = single EOA c55e. Reporter can move pps arbitrarily (no move cap) but cannot move vault funds without liquidity; oracle swap timelocked 1 day. |
| **S** | **$0** | Nothing is bricked: queue/cancel work even while the oracle is stale. (If the operator never funds liquidity, H-O drifts toward S — operational, not contract-level.) |

Confidence: **high** for E-U on the audited contracts (all gates proven on a pinned fork + live reads);
**medium** on the H-O/operator dependency ("when will liquidity be funded") since that is operational
behavior — the JIT-funding pattern is directly observed on-chain (26 micro-batch fundings from
`0xFA9573…`, $1–4 each), but not contractually enforceable.

What would change the verdict: (a) a key compromise/malicious majority of the 2/3 Safe or the reporter
EOA while liquidity is present would flip value into P (reporter could inflate pps and drain funded
liquidity instantly); (b) the operator funding the vault would make the H-O queue path live and create a
JIT-sniping surface around reports (no move cap, ~5-minute cadence, tiny moves); (c) any hidden off-vault
Altura contract holding the strategy assets with a permissionless entrypoint (not checked — out of scope).

### Coverage

- **Fully audited (source read line-by-line, all external/public functions enumerated and tested):**
  NavVault, NavOracle — complete verified sources pulled from Etherscan V2 and saved under
  `analysis/altura/src/contracts/`.
- **Screened (spot-checked, not exhaustively audited):** USD₮0 token (proxy, upgradeable by its admin;
  standard OFT behavior; no fee-on-transfer observed in 200 transfers), Gnosis Safe admin (2/3, no
  modules), vault counterparties, 341 USD₮0 transfers.
- **Not checked / unreachable:** the off-chain NAV computation feeding the reporter; the strategy wallets /
  HyperCore positions where the backing $32.4M actually sits (destinations like
  `0xbd151bef567dabf712a811402a27839768a13d70`); other Altura/app contracts; secondary markets for AVLT
  shares; reporter key management (HSM/multisig); HyperEVM mempool/ordering behavior for the JIT scenario;
  USD₮0 implementation internals beyond observed behavior.

## 6. Files index

| Path | Content |
|---|---|
| `analysis/altura/BRIEF.md` | given brief |
| `analysis/altura/REPORT.md` | this dossier |
| `analysis/altura/ci.txt` | CI run URL + result summary |
| `analysis/altura/src/contracts/NavVault.sol`, `NavOracle.sol` (+ OZ deps) | full verified sources |
| `analysis/altura/raw/abi.json`, `raw/oracle_abi.json` | ABIs |
| `analysis/altura/raw/live_state_48164864.txt`, `roles_*.txt`, `oracle_state_*.txt`, `safe_*.txt` | call transcripts (exact values, block-tagged) |
| `analysis/altura/raw/role_logs.json`, `nav_reported_logs.json`, `nav_history_recent.json`, `vault_admin_events.json` | event-level history |
| `analysis/altura/raw/vault_usdt0_txs.json`, `lqr_usdt0_txs.json`, `vault_txlist.json`, `vault_counterparties.json` | flow evidence |
| `analysis/altura/raw/live_evidence.json` | consolidated machine-readable evidence |
| `poc-altura/test/NavVault.t.sol` | 17 fork tests (CI) |

## 7. Methodology & caveats

Method: (1) pulled verified sources via Etherscan V2 `chainid=999` (SourceCode was double-braced; stripped
one layer); (2) enumerated all roles via `RoleGranted/RoleRevoked` logs, then `hasRole` at the pinned
block; (3) read all state at explicit blocks on the keyless public RPC, re-checked ±2 blocks for
stability; (4) sampled 341 USD₮0 transfers to reconstruct flow behavior; (5) exercised every
attacker-reachable function on a pinned fork in CI; (6) classified value strictly.

Caveats: (a) the public HyperEVM RPC served slightly inconsistent oracle *timestamps* across replicas for
the same historical block (pps/balances stable; `updatedAt` varied by ≤1,200s) — assertions avoid the
mutable timestamp; (b) token-flow sampling (341 transfers) is representative, not exhaustive; (c) fork
tests impersonate the live reporter/owners with `vm.prank` only where the test explicitly simulates
privileged behavior (clearly labelled, e.g. `test_J`), never to claim an unprivileged path; (d) USD
figures use the stated price source/time.
