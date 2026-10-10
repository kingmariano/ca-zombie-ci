# Nado Spot (Ink) — on-chain extraction dossier

**Status: read-only; PoC fork-verified only; no mainnet transactions. Everything in this folder is
observational. Addresses/roles/balances re-verified on-chain; exact blocks recorded below.**

- Target: **Nado** — CLOB DEX (spot + perps + money market), "off-chain sequencer + on-chain settlement".
- Chain: **Ink, chain id 57073** (public RPC `https://rpc-gel.inkonchain.com`, keyless).
- Contracts: source available at `github.com/nadohq/nado-contracts`; all nine live implementation
  contracts are verified on Blockscout and are **byte-identical to the repo sources** (keccak match,
  see `evidence-verified-contracts.json`; verified 2026-08-27 … 2026-10-08, solc 0.8.13).
- Main settlement custody: **Clearinghouse ≈ $55.87M** in tokens at 2026-10-10 prices (block 58,147,983).
- Headline: **E-U $0 proven** — no unprivileged, on-chain-only extraction path found. Direct gates are
  fork-proven closed; the only residual on-chain-risk candidate (fast-withdraw reimbursement race) cannot be
  executed without the sequencer's 3 ECDSA keys and is bounded by the ~$54k WithdrawPool buffer. Details below.
- Context: this is the H2-02 "active bounty" target — the deliverable is an honest extraction estimate for a
  responsible-disclosure/bounty track. Nothing was exploited on mainnet; all positive/negative results come
  from CI fork tests only.

---

## 1. Live state (all read-only, `cast call` / RPC at explicit blocks)

Block for roles/wiring/signer set: **58,133,941** and **58,147,617**; balances at **58,147,983**.
All nine protocol addresses are OZ **TransparentUpgradeableProxy** instances (runtime code 2,227 bytes each);
implementations are plain contracts (EIP-1967 slots, `eth_getStorageAt` verified).

| Contract (proxy) | Address | Impl | Code | Key live values |
|---|---|---|---|---|
| Quote (USDT₮0, 6dp) | `0x0200C29006150606B650577BBE7B6248F58470c1` | `0x06d886ff…` (TetherTokenOFT) | ✔ | quote product id 0 |
| Querier (FQuerier) | `0x68798229F88251b31D534733D6C4098318c9dff8` | `0xd0d380c3…` | ✔ | view helper |
| Clearinghouse | `0xD218103918C19D0A10cf35300E4CfAfbD444c5fE` | `0x5ca408f8…` | ✔ | owner `0x8e57…AD17`, endpoint = Endpoint, withdrawPool = WithdrawPool, spreads 31,469,292,683,777, insurance 1.3296e24 x18 |
| Endpoint | `0x05ec92D78ED421f3D3Ada77FFdE167106565974E` | `0x105d5b6d…` | ✔ | sequencer `0xA875966f…633A` (EOA, nonce 802,435), endpointTx `0xfebeA98e…`, nSubmissions 89,946,899 |
| OffchainExchange | `0x8373C3Aa04153aBc0cfD28901c3c971a946994ab` | `0xbc766a6d…` | ✔ | owner `0x8e57…AD17` |
| SpotEngine | `0xFcD94770B95fd9Cc67143132BB172EB17A0907fE` | `0xfa8251e3…` | ✔ | products [0,1,3,5,11,115,117,143,145,147,149,151,153,155,159] |
| PerpEngine | `0xF8599D58d1137fC56EcDd9C16ee139C8BDf96da1` | `0x397f63be…` | ✔ | owner `0x8e57…AD17` |
| Verifier | `0x9aCdC66459A323Fbb6eB77C5AA96a30234feCf17` | `0xb0dca488…` | ✔ | owner `0x8e57…AD17`; **nSigner = 3**; EIP-712 domain `("Nado","0.0.1")` (storage slots 1–2 = keccak("Nado"), keccak("0.0.1")) |
| WithdrawPool | `0x09fb495AA7859635f755E827d64c4C9A2e5b9651` | `0x7a359d56…` | ✔ | owner `0x8e57…AD17`, minIdx 89,946,969, `fees(0)` = 4,030.73 USDT₮0 |
| ProxyAdmin | `0xe099810844088f9974d105a1897d7a2b8ac608e7` | `0xd5af51a5…` | ✔ | owner (upgrade authority) `0xe95Da347a513e770664C7b1229ce64D3d8Ae88Ca` |
| ClearinghouseLiq (delegatecall impl for liquidations) | `0xD92791052f119cC3BE2704A2d2D86b7D47E1C07b` | — | ✔ | — |

**Fast-withdraw signer set (Verifier):** 3 Schnorr pubkeys (slots 0–2) + 3 ECDSA signers
`0xfA20f1094994fBf42c694440265FB9D4F112Ed47`, `0x688e28402F9E0ff676B58F318a70f78BBfed177a`,
`0x2ae37842EE9300C32a410F479ade36e3330D475a` — **all EOAs with nonce 0 and zero balance** (provisioned
signing keys, never used to send a transaction).

**Token balances held (block 58,147,983; prices DefiLlama + Yahoo close 2026-10-10):**

| Token | Clearinghouse | USD | WithdrawPool |
|---|---:|---:|---:|
| USDT₮0 (6dp) | 34,641,430.397922 | $34,608,506 | 54,047.534407 |
| kBTC (8dp) | 112.77265934 | $9,351,857 | 0 |
| WETH (18dp) | 1,900.683721786471796036 | $4,762,463 | 0 |
| USDC (6dp) | 2,371,052.734244 | $2,370,343 | 4.10 |
| XAUt0 (6dp) | 116.408732 | $486,270 | 0 |
| wSPYx | 1,365.571957 | $1,063,193 | 0 |
| wQQQx | 1,130.980006 | $849,671 | 0 |
| wGOOGLx | 1,310.743726 | $460,936 | 0 |
| wMETAx | 561.114669 | $403,256 | 0 |
| wNVDAx | 1,651.052091 | $378,553 | 0 |
| wAAPLx | 1,118.895915 | $376,665 | 0 |
| wTSLAx | 784.103096 | $300,076 | 0 |
| wMSFTx | 465.123964 | $248,874 | 0 |
| wAMZNx | 788.481062 | $206,921 | 0 |
| **total** | | **$55,867,585** | **$54,000** |

Internal state: `numSubaccounts` = 107,324; `nSubmissions` = 89,946,899 (block 58,133,941);
`insurance` = 1.3296e24 x18 (≈ $1.3296M, protocol-owned); `slowModeFees` = 1,174.81 (tokens held by the
Endpoint, no sweep function — owner-recoverable only via implementation upgrade); one slow-mode tx pending
(idx 135,270, `executableAt` 2026-10-13T15:34:01Z, sender `0xC7Ac…8869`, 97 bytes).
X_ACCOUNT quote balance −3,439.47 x18; FEES_ACCOUNT +1,525.30 x18; N_ACCOUNT +1,554,066.28 x18
(NLP-pool counterparty mirror).

## 2. Mechanism (deployed code — verified source matches repo exactly)

**Who can move value on-chain:**

1. `Endpoint.depositCollateral` / `depositCollateralWithReferral` — **permissionless**; takes tokens from
   `msg.sender` via `transferFrom`, credits a queued slow-mode `DepositCollateral` (credited on-chain after
   the 3-day queue delay, or earlier by the sequencer).
2. `Endpoint.submitSlowModeTransaction` — **permissionless**; $1 fee (`getSlowModeFee = 1e6` USDT₮0), 3-day
   `SLOW_MODE_TX_DELAY`, ≤256-byte payload for non-owner. Owner-only types (`WithdrawInsurance`, `Delist…`,
   `DumpFees`, `RebalanceXWithdraw`, NLP admin, `UpdateTierFeeRates`, `UpdateBuilder`) revert for non-owner.
3. `Endpoint.executeSlowModeTransaction` — **permissionless** crank of the queue head; each entry is executed
   with an 8M-gas budget inside try/catch (faulty entries are skipped, queue cannot be bricked; gas-cost
   asymmetry analyzed in-source).
4. `Endpoint.submitTransactionsChecked` — **sequencer only** (`msg.sender == sequencer`, live
   `0xA875966f…633A`); requires a Schnorr aggregated signature over the batch (`verifier.requireValidSignature`,
   >half of the 3 registered pubkeys). All user transactions (withdraw, transfer, order match, liquidation,
   NLP mint/burn, link signer, …) are only reachable through this path.
5. `WithdrawPool.submitFastWithdrawal(idx, txn, signatures)` — **permissionless caller**, but pays only against
   `Verifier.requireValidTxSignatures(txn, idx, signatures)` which requires **nSignatures == nSigner (all 3
   provisioned ECDSA keys)** over EIP-712 domain `("Nado","0.0.1", chainid, WithdrawPool's Verifier)`, plus
   `idx > minIdx` and `!markedIdxs[idx]` (replay protection). Payout goes to the `sendTo`/owner encoded in the
   signed blob; a third-party caller pays the fee themselves.
6. `Clearinghouse.*` — `onlyEndpoint`; `WithdrawPool.submitWithdrawal` — `onlyClearinghouse`;
   `SpotEngine.updateBalance/updatePrice` — `canApplyDeltas` (endpoint/clearinghouse/offchainExchange) /
   clearinghouse-only; `OffchainExchange` mutators — `onlyEndpoint`.
7. User-signed transactions (`EndpointTx.validateSignedTx`): per-owner nonce (`nonces[address]++`), EIP-712
   digest over the tx-type struct, domain `("Nado","0.0.1", chainid, **Endpoint proxy**)`, signer must be the
   subaccount owner or the linked signer. `WithdrawCollateralV2` binds `sendTo`; linked signers are rejected
   when `sendTo != 0`. OZ `ECDSA` (low-s enforced, no malleability) + EIP-2098 compact signatures.
8. `Verifier.initializeV2` — permissionless but constant-parameter EIP-712 backfill; cannot alter the domain
   (`txSignatureDigest` unchanged after a call attempt in the PoC).

**Design flow of value:** users deposit to the Clearinghouse, balances live in SpotEngine (normalized x18);
withdrawals route Clearinghouse → WithdrawPool → recipient. Fast withdrawals are advances from the
WithdrawPool's hot balance, later reimbursed by the sequencer processing the user's signed
`WithdrawCollateral` at the same `idx` (which leaves the reimbursed tokens in the pool because the idx is
already `markedIdxs`).

## 3. Attacker model — exact call paths and live gating values

External unprivileged attacker = no owner/sequencer/signer keys, no whitelist; only public contracts + own capital.

| Attempted path | Gate (live) | Result |
|---|---|---|
| `WithdrawPool.submitFastWithdrawal` to drain pool ($54k) | `requireValidTxSignatures` → live nSigner=3, positional ECDSA over digest bound to chain 57073 + Verifier address | reverts `not enough signatures` (0–2 sigs) / `invalid signature` (any non-provisioned key; even the victim's own valid signature) |
| Replay a fast withdrawal at same/other idx | `markedIdxs[idx]` + `idx > minIdx` + idx inside signed digest | reverts `Withdrawal already submitted` / `idx too small`; failed attempts do not consume the idx |
| Forge user withdrawal from a victim subaccount | `Verifier.validateSignature`: `recovered == owner || linkedSigner`, recovered≠0 | reverts `IS`; digest differs per chain, per contract, per type, per `sendTo` (fork-proven) |
| Replay a user signature across chain/contract/type | domain separator `(Nado,0.0.1,chainid,Endpoint)` + distinct typehashes + per-owner nonce | fork-proven digest inequality; OZ low-s kills malleated variants |
| Call `Clearinghouse.withdrawCollateral` directly | `onlyEndpoint` | reverts `SequencerGated: caller is not the endpoint` |
| Call `WithdrawPool.submitWithdrawal` directly | `require(msg.sender == clearinghouse)` | reverts |
| Call `SpotEngine.updateBalance/updatePrice` | `canApplyDeltas` / clearinghouse-only | reverts `U` |
| Call `Endpoint.submitTransactionsChecked` (include own txs) | `require(msg.sender == sequencer)` + Schnorr quorum | reverts; Schnorr path un-forgeable without keys (fork-tested with random e/s) |
| `submitTransactionsCheckedWithGasLimit` (permissionless twin) | always ends in `verifier.revertGasInfo(...)` → unconditional revert | no state can persist |
| Slow-mode withdrawal of someone else's collateral | `validateSender(txn.sender, queueSender)` — queue sender = submitter, subaccount owner = `bytes20(txn.sender)` | entry executes and is **skipped**; victim's balance, Clearinghouse and WithdrawPool token balances unchanged (fork-proven) |
| Slow-mode owner-only types as non-owner | `require(sender == owner())` | reverts |
| Call `Endpoint.processSlowModeTransaction` directly | `require(msg.sender == address(this))` | reverts |
| Free withdrawal via `rebalanceXWithdraw` (X_ACCOUNT) | owner-only slow-mode type | reverts for non-owner |
| Deposit then withdraw more than deposited | `getHealth ≥ 0` + engine debit | impossible; attacker only donates |

**Costs:** slow-mode enqueue $1.00 (USDT₮0); gas on Ink is cheap (sub-cent). No flash-loan surface found on the
deposit/withdraw path (balances are net-collateral gated; borrowing a spot asset outside risk system returns
`-INF` health in `getHealth`, blocking withdrawal).

### Residual candidate (screened, NOT executed, NOT counted in E-U)

**Fast-withdraw / slow-withdraw race on reimbursement.** A user with on-chain balance B can request a fast
withdrawal (pool pays B instantly against the 3-of-3 sequencer signature), while *permissionlessly* withdrawing
the same B through the slow-mode queue (3-day delay, `executeSlowModeTransaction` is un-permissioned). If the
slow-mode entry executes before the sequencer's reimbursement tx (which uses the pre-signed idx), the
reimbursement debits an already-empty balance, reverts, and the pool's advance is never repaid: attacker nets
+1×B of pool liquidity. Executing this requires (a) the sequencer to grant the fast withdrawal and (b) its
settlement to lose a race it normally wins in minutes — both off-chain. We cannot execute the fast leg
(needs the 3 ECDSA keys; impossible outside the sequencer). Bounded by WithdrawPool liquidity ≈ **$54.0k**
today. Confidence an attacker can force it: **low**. What would change it: observing the sequencer's actual
fast-withdraw policy/settlement latency, or a batch revert caused by such a race.

## 4. PoC (fork tests — Ink mainnet state, CI only)

`poc-nado/test/NadoFork.t.sol` (14 tests) + `poc-nado/src/Nado.sol` interfaces. All tests execute against a
fork of Ink via the keyless public RPC; no transaction is ever sent to mainnet.

**CI result: 14 passed / 0 failed / 0 skipped** — fork block **58,149,246**, chainid 57073.
Run: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38065395750
Earlier iterations (kept for transparency): 38064256027 (compile: reserved keyword `after`),
38064470718 (compile: stack-too-deep), 38064953258 (9/5 — fixed an ABI-encoding bug in the *test's* signed-tx
blob and a test-wallet fee funding gap; see note below).

Live values logged by the passing run: `live_nSigner: 3`; Clearinghouse USDT₮0 = 34,640,889.762823 ($34.6M);
WithdrawPool USDT₮0 = 54,047.534407; `slow_txs_processed: 1` (the E2E withdrawal);
`initializeV2_callable: no (already done)`.

Key assertions (all on live code/live state):

- live wiring/roles/signers; Clearinghouse USDT₮0 > $25M, WithdrawPool < $5M; `nSigner` counted = 3; signers
  are EOAs;
- fast-withdraw digest equals locally reconstructed EIP-712 `(Nado,0.0.1,57073,Verifier)` digest; differs per
  chain/contract/idx/payload;
- `requireValidTxSignatures` reverts with 0/1/2/3 signatures unless they are the 3 provisioned ECDSA keys;
  the subaccount owner's own signature is rejected; failed attempts do not consume the idx (`markedIdxs`);
- `markedIdxs`/`minIdx` replay gates revert (`Withdrawal already submitted` / `idx too small`);
- `validateSignature`: owner ok; wrong subaccount `IS`; linked-signer ok; high-s malleated `ECDSA: invalid
  signature 's' value`; cross-chain digest `IS`; V1/V2 and `sendTo` digest separation;
- `Clearinghouse.withdrawCollateral`, `WithdrawPool.submitWithdrawal`, `SpotEngine.updateBalance/updatePrice`,
  `Endpoint.submitTransactionsChecked`, `processSlowModeTransaction`: all revert unprivileged (`SequencerGated:
  caller is not the endpoint` / `U` / bare requires); gas-probe twin always reverts; Schnorr gate un-forgeable
  with random (e,s);
- **end-to-end slow-mode round trip**: deposit $10 → credited after 3 days → withdraw $4 → recipient paid
  exactly $4, Clearinghouse −$4, spot balance debited (proves the self-service H-O path on live code);
- **third-party slow-mode withdrawal**: attacker pays the fee, entry is consumed and skipped; victim's token
  and spot balances unchanged (proves the isolation gate).

Encoding note (discovered while writing the PoC): `SignedWithdrawCollateral` (V1) is a **dynamic** struct, so
the transaction body must carry the standard ABI outer offset word (`0x20`) before the struct payload —
verified against the live Verifier (`computeDigest(2, body)` succeeds only with the prefix; the V2 struct is
fully static and is decoded inline). This is a wire-format detail of the protocol SDK, not a vulnerability.


## 5. Verdict

| Category | Amount (live) | USD | Basis |
|---|---|---|---|
| **E-U** | **0** (paths proven closed; residual race ≤ $54.0k, low confidence, not counted) | **$0** | fork-proven reverts + live gating values; fast-withdraw needs all 3 sequencer ECDSA keys |
| **H-O** | ≈ Clearinghouse holdings − insurance ≈ 54.5M | **≈ $54.5M** | users' collateral withdrawable by owners via sequencer settlement or permissionless 3-day slow mode (E2E PoC) |
| **P** | insurance 1.3296e24 x18; owner-only surfaces (`withdrawInsurance`, `removeLiquidity`, `setWithdrawPool`, upgrades via ProxyAdmin owner `0xe95D…88Ca`) | **≈ $1.33M** + control | live state + source |
| **S** | none proven; Endpoint slow-mode fees $1,174.81 have no sweep function (owner-upgrade only) | $0 (≈$1.17k upgrade-only) | source review |

**Confidence:** high for the enumerated on-chain surfaces (each negative was executed against live code on a
fork; every address/role gate re-read live). **Medium** for the overall E-U claim because the fast-withdraw
*reimbursement race* depends on off-chain sequencer behavior we could not execute, and because per-account
liquidatability/health was not enumerated.

**What would change the verdict:** (1) evidence the sequencer grants fast withdrawals that stay unreimbursed
for >3 days (race becomes executable); (2) compromise of any of the 3 ECDSA signer keys or the ProxyAdmin
owner; (3) a bug in the sequencer-gated transaction surface (`EndpointTx.processTransactionImpl` — we could
not execute signed user txs because inclusion requires the sequencer Schnorr key, so this surface was
reviewed statically against the verified deployed source only).

**Coverage:** **screened** (not fully audited). Fully audited: the permissionless on-chain entrypoints and all
signature-gating primitives (fork-executed). Screened: sequencer-only transaction processing (`matchOrders`,
liquidations, ticks, price updates, NLP ops), `ClearinghouseLiq` delegatecall body, perp funding/interest math.
**Not checked:** full enumeration of 107,324 subaccounts (health/liquidatability screen); `OffchainExchange`
order-fill accounting details (`filledAmounts`, builder fees) beyond gating; `Airdrop.sol` (not deployed on
Ink per the live set); FQuerier source (only ABI); sequencer API/off-chain policies; multi-chain deployments
of the same codebase; governance/multisig composition of `0x8e57…AD17` / `0xe95D…88Ca`.

## 6. Files & methodology

- `REPORT.md` — this dossier.
- `evidence-live-state.json` — roles, wiring, signers, state, token balances + USD at recorded blocks.
- `evidence-verified-contracts.json` — Blockscout verification metadata + keccak of source vs repo files.
- `evidence-token-balances-raw.json` — raw on-chain balances for all 15 spot products.
- `ci.txt` — CI run URL(s) and result summary.
- `poc-nado/src/Nado.sol`, `poc-nado/test/NadoFork.t.sol` — fork PoC (run in GitHub Actions only).

Methodology: live reads via keyless public RPC (`cast`) at recorded blocks; Blockscout `/api/v2` for
verification + token metadata; DefiLlama and Yahoo Finance for prices (2026-10-10); repo clone of
`nadohq/nado-contracts` diffed against verified deployed sources; PoC as Foundry fork tests executed in CI.
Caveats: token balances are the settlement-layer holdings — the user/protocol split is derived, not
enumerated per subaccount; USD for xStocks uses underlying equity quotes.
