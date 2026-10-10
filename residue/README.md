# H2-03 — Fresh-incident residue with live approvals/allowances: live-state assessment & extractable-value determination

**Campaign:** zombie-hunt II (H2-03) · **Chains:** Polygon, Base, Optimism, BSC · **Date of work:** 2026-10-10
**Status:** read-only research; all execution on local forks only (PoC in public CI); **no mainnet transaction was ever sent**. All on-chain reads at explicit block numbers (below). No secrets in this folder.

**Scope (the six H2-03 items):**

| # | Target | Chain | Corpus lead |
|---|---|---|---|
| 1 | Nimiq HTLC handlers (OpenGSN combined handlers) | Polygon | 0 balance but unlimited USDT allowance live; "any future inflow drainable" |
| 2 | Base vault sibling `0x416Ec2cA…` | Base | 4.51M AERO + 1.32M VIRTUAL + 161.8k USDT + 1.689 cbBTC + more; whitelist path closed |
| 3 | Cozy Finance v2 Sets (CSET) | Optimism | 4,168.13 USDC.e residual; UMA oracle-claim path |
| 4 | SKYDAO controller | BSC | 29,774.225 USDT residue; `sellToken` reverts for non-token callers |
| 5 | FIST token contract | BSC | 152,672 USDT held; no rescue ABI |
| 6 | MSN token contract | BSC | 3,762 USDT held; no rescue ABI |

---

## 1. TL;DR

| # | Target | Live extractable now (external, unprivileged) | Why closed / open | Latent risk |
|---|---|---|---|---|
| 1 | Nimiq H1 `0x0cFD862b…`, H2 `0xF615bD7E…` (Polygon) | **$0.00** (high) | **Remediated 2026-09-17 18:26/18:27 UTC**: owner zeroed `relayHub` on both handlers (txs `0xf42a363a…`, `0x22570a38…`). `execute()`/`preRelayedCall()` are `onlyRelayHub` → unreachable; `relayWithoutGsn()` reverts (call to `address(0)`); `deposits == 0` on every token → **no open HTLCs**; handler-held excess is owner-only. The Sep-16-2026 incident technique is fork-reproduced (pre-fix block). | **HIGH latent:** victim allowances still **unlimited** (USDC→H1, USDC.e/USDT→H2). **One owner `setRelayHub(hub)` call re-arms the exact drain** for any future inflow — fork-proven. 989 wallets still have allowances; 969 of them still hold dust balances (Σ ≈ $4.03 today). |
| 2 | Base sibling `0x416Ec2cA…` | **$0.00** (high) | `borrow`/`withdraw`/`repay` all revert `!W` for fresh callers; the C2-02 attacker helper is **not** whitelisted here; the sibling's 92-address whitelist is 100% contract accounts, all gated (C2-02 enumeration, re-verified at latest block). | Owner Safe 3-of-7 (`borrow` owner-exempt — eth_call-proven) and ProxyAdmin (upgrade) — **P ≈ $5.31M**, not fresh. |
| 3 | Cozy Sets `0x17705474…` + `0x426713c9…` (OP) | **$0.00** (high) | All Sets **PAUSED**; `purchase`/`deposit` revert `InvalidState()`; `remainingProtection == 0` on the incident markets; residual is already allocated to CPT holders (`claim()` works while paused — H-O) and CSET share holders (pause-gated). A repeat false-YES UMA run costs a 500–1,000 USDC bond + 5-day liveness and pays **existing** CPT holders, not the attacker → negative EV. | If Cozy ever unpauses **and** market state allowed `purchase`, the class re-opens (≤ $1,150 on Set 3) — judged very unlikely. |
| 4 | SKYDAO controller `0xEe5fDff6…` (BSC) | **$0.00** (high) | All 43 public selectors probed from a fresh EOA on a fork: **no path moves the standing USDT balance**; the only USDT-transferring functions distribute *fresh flow* to fixed config addresses and are gated to the token/pair; sells are additionally bricked (pair holds 1 wei SKYDAO → every sell reverts). | Owner EOA paths tested moved $0; **S (stuck)** for the whole residue. |
| 5 | FIST `0xc9882def…` (BSC) | **$0.00** (high) | `FistToken` is a bare BEP20+Ownable (16 selectors), **zero external calls**, no USDT interface/rescue; `owner() == 0` (renounced); not upgradeable. | None — mathematically stuck. |
| 6 | MSN `0xd8b3ef86…` (BSC) | **$0.00** (high) | Same class: no USDT interface, no low-level calls, no rescue; `owner() == 0`. | None — stuck. |

**Total live extractable now (external, unprivileged): $0.00 — confidence HIGH.**
Categories: **E-U $0.00** · **H-O $5,318.69** (Cozy CPT claims; +$13,446.94 in an older-generation Cozy vault) · **P ≈ $5,312,145.28** (Base sibling $5,312,113.68 + Nimiq owner excess $31.49 + Cozy set fees $0.11) · **S $186,073.68** (SKYDAO + FIST + MSN).

The single most important correction to the corpus: the Nimiq "any future inflow drainable" claim is **not live today** — it became conditional on one owner action on 2026-09-17. The unlimited allowances remain, and the PoC proves the re-arm is one transaction.

---

## 2. The Nimiq bug and the Sep-16-2026 incident (item 1)

### 2.1 The bug, in exact terms

`ERC20PermitHTLCHandler` `0x0cFD862bE942846Cebad797d7c1BC6e47714959b` and `ERC20MetaHTLCHandler`
`0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f` (Polygon, verified, solc 0.8.17, direct deployments)
collapse the three OpenGSN dApp roles (recipient + paymaster + forwarder) into one contract
(`BaseCombinedGsnHandler`). The critical deployed code (identical on both):

```solidity
function execute(ForwardRequest calldata request, bytes32 domainSeparator, bytes32 requestTypeHash,
                 bytes calldata suffixData, bytes calldata signature)
    public override payable onlyRelayHub returns (bool success, bytes memory ret)
{
    (request, domainSeparator, requestTypeHash, suffixData, signature); // all discarded
    bytes4 methodId = GsnUtils.getMethodSig(request.data);
    (OpenRequestData memory openRequestData, CloseRequestData memory closeRequestData,
     FeeInformation memory feeInformation) = decodeRequestDataPrivate(methodId, request.from, request.data, 0);
    nonces[request.from] = nonces[request.from] + 1;          // incremented, never compared
    if (methodId == this.open.selector || methodId == this.openWithPermit.selector) {
        openPrivate(request.from, openRequestData);           // transferFrom(request.from, handler, amount)
    } else {
        closePrivate(closeRequestData, feeInformation);       // token.transfer(target, amount)
    }
    success = true; ret = "";
}
```

- **No signature check, no nonce check, no business checks** (`checkOpen`/`checkRedeem`/`checkRefund`
  are never called on this path). Authentication lives only in the **paymaster hook**
  `preRelayedCall()`, which the relay can simply not invoke by naming its own `relayData.paymaster`
  while setting `relayData.forwarder = handler`.
- The hub (`0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d`, OpenGSN RelayHub 2.2.0, not deprecated)
  calls `paymaster.preRelayedCall` (attacker's evil paymaster returns `("", false)`), then
  `forwarder.execute` — with the handler's own authentication skipped. Gas price 0 → charge 0.
- Two sinks: (a) **forged `open`** drains any wallet that has a live allowance to the handler
  (the liquidity wallet's unlimited approvals made it the big pot); (b) **forged `redeem`/`refund`**
  pays out any open HTLC to an arbitrary target (no secret/recipient/timeout checks on this path).
- Relay setup cost: **1 POL stake** (refundable after the 1,000-block unstake delay) + gas.

### 2.2 The incident (verified timeline)

- Victim (Nimiq swap-liquidity wallet): `0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773`.
- Attacker EOA (EIP-7702): `0x2258491525C21f334c5a2dc22CE55e55023FC45D`.
- Setup tx `0xb067efae73637f3564f58af7f6027afc497e81e47624b0048636085c678858c0`
  (block 93,930,784, 2026-09-16 23:26:49 UTC) — stake 1 POL, evil paymaster, forged opens.
- Exploit tx `0xb2ca76dfbfe571742b4b66465b777ab1e06988a8632be1631bef9654cc64d169`
  (block 93,930,854, 23:28 UTC) — redeem to a CREATE2 recipient with `secret = 0x01`.
- Taken: **26,130.641710 USDC + 24,332.489269 USDT + 0.661117 USDC.e ≈ $50,463** (exactly the
  victim's balances; re-verified on-chain at block 93,922,656).

### 2.3 Live state today (block 95,284,982)

| Check | H1 `0x0cFD862b…` (USDC) | H2 `0xF615bD7E…` (USDT/USDC.e) |
|---|---|---|
| `getHubAddr()` | **`0x0000000000000000000000000000000000000000`** | **`0x0000000000000000000000000000000000000000`** |
| `owner()` | `0xDB88bf6328D4778bd8Ce653ADf51E079b5bF9DDA` (EOA) | same |
| `deposits(token)` | 0 (USDC) | 0 / 0 (USDC.e / USDT) |
| token balance (excess) | 11.250690 USDC | 18.116704 USDC.e + 2.126549 USDT |
| `htlcs` open (8,171 ids checked) | **0 open** | **0 open** |
| last Open/Redeem event | 2026-09-16 23:28 UTC (the exploit) | 2026-09-16 23:28 UTC |

**Remediation:** owner `setRelayHub(address(0))`:
- H2: tx `0xf42a363a9bebcc266642eaaa8bcd920ae22f098c4b1ff9b568a6189654dbd0cf`, block 93,976,364 (2026-09-17 18:26 UTC).
- H1: tx `0x22570a382b21efa372bec4dbccc9faf62fafb338900bacefc8d0ccf74db03252`, block 93,976,404 (2026-09-17 18:27 UTC).

**Victim allowances still live (unlimited, `type(uint256).max`-scale):**

| Token | Spender | Allowance (raw) | Victim balance |
|---|---|---|---|
| USDC `0x3c499c54…` | H1 | 115,792,089,237,316,195,423,570,985,008,687,907,853,269,984,665,640,564,039,457,584,007,473,231,025,853 | 0 |
| USDC.e `0x2791Bca1…` | H2 | …007,745,969,807,966 | 0 |
| USDT `0xc2132D05…` | H2 | …007,796,917,401,439 | 0 |

**Other family deployments** (all deployed by the same owner EOA; all checked):

| Contract | Version | `getHubAddr()` | Verdict |
|---|---|---|---|
| `0x98E69a69…` | erc20meta.handler | 0 | closed |
| `0x3157d422…` | erc20permit.handler | 0 | closed |
| `0xfAbBed81…` | erc20meta.uniswap | 0 | closed |
| `0xe4491D94…` | erc20meta.handler | 0 | closed |
| `0x3c870b03…` | erc20meta.handler | 0 | closed |
| `0x4b766A07…` (Feb-2023 prototype) | erc20meta.handler | **0x6C28AfC1… (live)** | **not exploitable**: its `execute()` performs full EIP-712 verification + nonce (fork test: forged `verify` reverts `Base: signature mismatch`); zero balances, zero approvals ever |

**Allowance census (full event enumeration):** 1,512 approvals to H1 (USDC) + 6,099 to H2
(3,535 USDC.e + 2,564 USDT) → 989 distinct (handler, token, owner) pairs; **969 still have
allowance > 0 AND balance > 0, totalling only 4.034181 units (≈ $4.03)** — the residue is dust;
the big balances were swept after the incident. All of them are **inert today** (see below).

### 2.4 What an attacker can and cannot do

- **Cannot** (today): call `execute`/`preRelayedCall` (onlyRelayHub, hub is `0x0`); use
  `relayWithoutGsn` (full signature verification, and it reverts on `relayHub.calculateCharge`
  against `address(0)`); use `open`/`openWithPermit`/`redeem`/`refund` to spend someone else's
  allowance (they act on `msg.sender`'s own funds/HTLCs only); withdraw the handler excess
  (`withdrawToken` is onlyOwner); exploit the other five family deployments (hub zeroed, or
  signature-verified as in `0x4b766A07`).
- **Could do until 2026-09-17 18:26 UTC** (fork-reproduced): register as a relay for 1 POL,
  deploy an evil paymaster, forge relayed `open`s and `redeem`s — drain the victim (and any other
  allowance holder) and steal open HTLCs.
- **Could do after one owner `setRelayHub(hub)` call** (fork-proven, latent): the identical drain
  against any future inflow to the victim wallet or any of the 969 allowance-holding wallets.
- Owner-side value: `withdrawToken` can take the excess **$31.49** (P). `withdrawRelayHubDeposit`
  is dead while `relayHub == 0`.

### 2.5 PoC / fork verification

`poc/test/NimiqH203.t.sol` — **7 tests, 7/7 PASS**. Two run modes:

- **Local (archive RPC, historical fork at block 93,930,000, pre-attack):** the end-to-end
  reproduction drains the victim's real pre-attack balances — **24,332.489269 USDT +
  26,130.641710 USDC** — through the **real RelayHub**, exactly as in the Sep-16 incident.
- **CI (public GitHub Actions, latest block):** the provider set injected in CI has no archive
  access (all keys are tip-only or expired), so the suite reconstructs the identical attack at the
  latest block — it performs the single owner `setRelayHub(hub)` flip (the only state difference
  from 2026-09-16), injects the exact drained amounts onto the **still-live allowances**, and runs
  the same unprivileged full-hub exploit. Both modes pass 7/7.

| Test | Proves |
|---|---|
| `test_reconstructed_fullRelayExploit_drainsVictim` | End-to-end: a fresh EOA (1 POL refundable stake + gas), through the **real RelayHub**, drains the victim's full **24,332.489269 USDT + 26,130.641710 USDC** (historical fork: the real pre-attack balances; CI: reconstructed) |
| `test_forgedRedeem_stealsOpenHTLC` | A forged relayed `redeem` redirects an open HTLC to the attacker (no secret/recipient checks) — uses the live allowance/balance of a real user wallet (`0x7845…`, 0.055022 USDC) |
| `test_latest_hubZeroed_and_executeReverts` | `getHubAddr() == 0`; `execute` reverts `Base: illegal msg.sender` even when called from the real hub address; `relayWithoutGsn` reverts |
| `test_latest_fullRelayPath_cannotMoveFunds` | Full relay path at latest block: hub returns `false` / `Base: illegal msg.sender`; **no funds move** |
| `test_latest_reArm_byOwner_reopensDrain` | One owner `setRelayHub(hub)` re-arms the identical drain; 5,000 USDT future inflow fully captured |
| `test_latest_victimAllowances_stillUnlimited` | The three allowances remain `> 1e70`; victim balances 0 |
| `test_otherFamilyDeployments_closed` | Five deployments hub-zeroed; the Feb-2023 prototype with live hub enforces signatures (`Base: signature mismatch`) |

CI runs (public repo `kingmariano/ca-zombie-ci`): **7/7 PASS** at pinned Polygon block 95,291,408 —
<https://github.com/kingmariano/ca-zombie-ci/actions/runs/38059644991> (full run history in
`ci-links.md` / `ci-log.txt`). The CI selector (`ci/run.sh`) picks a working RPC and pins a shallow
recent block (tip − 48) because load-balanced public endpoints occasionally miss the newest block
hash and prune state beyond ~128 blocks. Gas: the relay path uses ≈ 0.9–2.4M gas per drain; relay
stake 1 POL (refundable).

---

## 3. Base vault sibling (item 2) — see `analysis/base-sibling/findings.md`

Block 52,424,899: AERO 4,508,069.47 ($4,029,114) + VIRTUAL 1,319,234.04 ($968,962) + USDT
161,813.10 ($161,690) + cbBTC 1.689 ($139,821) + WETH 4.416 ($11,023) + USDC 1,503 ($1,503) =
**$5,312,113.68**. Fresh callers: `borrow`/`withdraw`/`repay` → `!W`; the C2-02 attacker helper is
not whitelisted on this sibling; owner Safe `borrow` is owner-exempt (P). **E-U $0 (high); P $5.31M.**

## 4. Cozy Finance v2 Sets (item 3) — see `analysis/cozy/findings.md`

Sets `0x17705474203F7ff7ba8a940c433AB43D1F58E249` (**4,168.126922 USDC.e**) and
`0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8` (**1,150.675622 USDC.e**), both PAUSED since block
156,595,428. Residual is allocated to CPT holders (H-O: 2,222.42 claimable now via `claim()` while
paused; 3,096.27 pause-gated CSET shares) and $0.11 set fees (P). Repeat false-YES UMA attack:
technically open (bond 500–1,000 USDC, 5-day liveness, refundable) but pays **existing** CPT
holders and is negative-EV — **E-U $0 (high)**. An older-generation Cozy vault holds an additional
$13,446.94 (H-O, different ABI).

## 5. BSC trio (items 4–6) — see `analysis/bsc-trio/findings.md`

| Target | Address | Balance (block 126,834,398) | Verdict |
|---|---|---|---|
| SKYDAO controller | `0xEe5fDff6364dDe0A3C66dD38A4303cDd3D10730c` | 29,774.225000 USDT | **S (stuck)** — 43/43 selectors probed, no path moves the residue; sells bricked (pair holds 1 wei SKYDAO) |
| FIST token | `0xc9882def23bc42d53895b8361d0b1edc7570bc6a` | 152,672.621512 USDT | **S** — bare BEP20, owner renounced, no external calls |
| MSN token | `0xd8b3ef86afce18edba91fed481abe22f173597c1` | 3,762.282749 USDT | **S** — same class |

Total stuck ≈ **186,209.129261 USDT ≈ $186,073.68** (USDT $0.99927). E-U $0 (high).

---

## 6. Verdict and residual/latent risk

- **Today an external unprivileged attacker can extract $0.00** across all six items (high confidence).
- **Latent (Nimiq):** the victim's unlimited allowances + 969 allowance-holding wallets survive;
  one owner `setRelayHub(0x6C28AfC1…)` call re-arms a fork-proven drain. Remediation: revoke the
  victim allowances and (defence in depth) never re-point the handlers at a hub; if the handlers
  are retired, `renounceOwnership`/zero the allowances is not possible for users' own approvals —
  the wallets themselves must `approve(handler, 0)`.
- **Latent (Base sibling):** none for fresh callers; owner/ProxyAdmin hold the value (P).
- **Latent (Cozy):** unpause + open capacity would be required to re-open the class; negligible.
- **Blockers that keep funds stuck (S):** FIST/MSN have no call that can move USDT; SKYDAO's
  sell path is bricked by the 1-wei pair balance and its USDT-moving functions only distribute
  fresh flow to fixed recipients.
- **Token-side risks not counted as extractable:** USDT/USDC blacklists; none observed in use.

## 7. Methodology & sources

- Full `Approval`/`Open`/`Redeem`/`Refund` event enumeration via Etherscan V2 (`chainid=137`);
  current-state reads via Multicall3 batched `eth_call` against keyless public Polygon RPC
  (block 95,284,982); per-handler `deposits`/`htlcs`/`hub`/`owner` reads via `cast`.
- Verified sources fetched from Etherscan V2 and stored under `analysis/nimiq/sources/`
  (both handlers, the Feb-2023 prototype, the RelayHub 2.2.0 and StakeManager).
- Incident context: Verichains "NIMIQ HACK ANALYSIS" (2026-09-25) and SlowMist incident index
  (attacker/victim/tx addresses cross-checked on-chain).
- Prices: DefiLlama `coins.llama.fi` at 2026-10-10 (~$0.89 AERO, ~$0.73 VIRTUAL, BTC ~$82.8k,
  ETH ~$2,496, stables ≈ $1).
- Child subagents (Cozy, BSC trio) produced their own evidence files under `analysis/cozy/` and
  `analysis/bsc-trio/`; their raw logs are gzipped (`.json.gz`) to keep the public CI repo small.

## 8. Caveats & limitations

1. **Archive dependence:** the historical reproduction at block 93,930,000 requires an archive
   RPC; it was run locally (Ankr/Infura archive endpoints). The CI suite is archive-free and
   reconstructs the incident at the latest block (documented in `ci-links.md`).
2. **Not enumerated:** handler-family contracts deployed by keys other than the Nimiq owner EOA
   `0xDB88bf63…` were not exhaustively searched by code hash; the corpus and Verichains name only
   H1/H2 as the vulnerable HTLC handlers, and all 8 owner deployments were checked.
3. The 969 live allowance pairs are dust (Σ $4.03); they were enumerated from approval events
   (permit events included); tokens with non-standard Approval events (none observed) could be missed.
4. Cozy Set logic is unverified; semantics were inferred from `cozy-interfaces-v2`, the incident
   traces and the child's simulations (see `analysis/cozy/findings.md` §caveats).
5. SKYDAO controller is unverified; the child's conclusion is disassembly + exhaustive selector
   probing + fork traces, with residual decompiler-level risk (mitigated).
6. USD figures are point-in-time (2026-10-10); the volatility of AERO/VIRTUAL moves the P total.

## 9. Files index

```
residue/
├── README.md                     (this file)
├── summary.json                  (machine-readable)
├── ci-links.md                   (CI run URLs)
├── scan_polygon_nimiq.py         (keyless state scan)
├── enumerate_nimiq.py            (Open/Redeem/Refund enumeration)
├── enumerate_approvals.py        (approval enumeration)
├── process_nimiq.py              (live allowance/HTLC state processor)
├── analysis/
│   ├── nimiq/                    (state dumps, logs/*.json.gz, verified sources, opengsn ABIs)
│   ├── base-sibling/findings.md
│   ├── cozy/                     (findings.md, evidence.json, sources.md)
│   └── bsc-trio/                 (findings.md, evidence.json, sources.md, raw/, logs/)
└── poc/                          (Foundry: src/NimiqH203.sol, test/NimiqH203.t.sol, vendored forge-std)
```
