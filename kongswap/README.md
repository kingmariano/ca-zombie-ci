# H-28 — KongSwap (Internet Computer) — live-state assessment & extractable-value determination

**Campaign:** zombie-hunt · **Chain:** Internet Computer Protocol (ICP) · **Date of work:** 2026-10-04
**Status:** read-only research. Only anonymous IC **query** calls and public HTTP GETs were used. No update calls, no transactions, no secrets. No mainnet state was modified.
**Finding (corpus):** H-28 KongSwap — DefiLlama last-known $2.377M, stale 182 d, 1 audit, "dead Apr-2026; canister balances; check."

**TL;DR — an external, unprivileged attacker can currently extract ≈ $0 from KongSwap.** The DEX canister is
alive and still answers queries, but it is fully wound down: **all pools are removed with zero reserves**, there are
no LP positions, and across **135 token ledgers the DEX holds only ~$13 of dust** (plus one unpriced memecoin).
The SNS DAO's **119,042.87 ICP (~$406.8k) treasury + 544.2M KONG** still exist, but they are spendable only by a
*critical* SNS proposal (≥20% of total voting power YES, ≥67% of cast YES), and the ~80M KONG needed to reach that
quorum **cannot be acquired on-chain** (all live KONG liquidity ≈ 3.7M KONG / ~$547; 24h volume $0). The dominant
41%-voting-power bloc has historically voted on treasury proposals. The remaining DEX balance is holder-recoverable
at most; nothing is attacker-extractable.

| # | Target | Live extractable (unprivileged) | Why closed today | Latent risk |
|---|---|---|---|---|
| 1 | KongSwap DEX canister `2ipq2-uqaaa-aaaar-qailq-cai` | **$0** | `pools(null)` → **0 pools** (all removed); historical pools KONG_ICP (59), ICP_ckUSDT (1), ckBTC_ICP (126) all `0/0`; 135 ledgers scanned → 4 nonzero (≈$13.4, mostly 0.155 SNEED) + 51 dead/frozen; no LP tokens | Code is closed-source and still callable; a bug in `send`/`claim`/`add_pool` would matter only if funds returned. DEX holds ~$13 |
| 2 | SNS treasury (ICP) `f39d9b22…` | **$0** | 119,042.87 ICP spendable only via critical proposal; capture requires ~80M KONG staked vs ~3.7M KONG total live liquidity | If a large KONG holder ever dumps ≥80M KONG into public markets, dormant-DAO capture becomes economically possible (Yam class) |
| 3 | SNS treasury (KONG) `oypg6-…` subaccount | **$0** | 544,236,777.56 KONG; same governance gate; token is effectively illiquid (FDV $147k, $0 volume) | Same as #2 |
| 4 | Canister cycles / controllers | **$0** | All canisters controlled by SNS root → SNS governance; no EOA controller; DEX has 119.7T cycles (~$160), not withdrawable by non-controllers | None unprivileged; SNS upgrade path is the governance path |

**Total live extractable found: ≈ $0.00 (high confidence).**
Holder-recoverable dust in the DEX: **≈ $13.40** (0.15477 SNEED @ $86.49 + 2.58 ICE + 0.81 NUA + 191,485.49 unpriced BIL + unlisted DOLR/GHOST ≈ $0.002). Governance-only: **$406,807.51 ICP + $78,832.16 KONG (nominal)**.

---

## 1. Target set and architecture (verified)

KongSwap is an ICP DEX (single-canister AMM + SNS DAO). The full canister set was reconstructed from the SNS
aggregator and cross-checked against `ic-api`:

| Role | Canister | Controller | Status / cycles | Notes |
|---|---|---|---|---|
| DEX (AMM + user balances) | `2ipq2-uqaaa-aaaar-qailq-cai` | SNS root | running · 119.7T cycles | `icrc1_name` = **"Kong Swap v0.0.21"**; module hash `6892966c…`; subnet `pzp6e-…` |
| SNS root | `ormnc-tiaaa-aaaaq-aadyq-cai` | SNS governance | running · 17.6T | registered dapps incl. DEX, frontend |
| SNS governance | `oypg6-faaaa-aaaaq-aadza-cai` | SNS root | running · 23.7T | holds treasury subaccounts |
| KONG ledger | `o7oak-iyaaa-aaaaq-aadzq-cai` | SNS root | running · 21.4T | ICRC-1; total supply 1,016,007,322 KONG |
| KONG index | `onixt-eiaaa-aaaaq-aad2q-cai` | SNS root | running · 23.6T | `get_account_transactions` (query) works |
| SNS swap | `okjrh-jqaaa-aaaaq-aad2a-cai` | SNS root | running · 20.5T | sale committed Nov-2024 |
| Frontend | `3ldz4-aiaaa-aaaar-qaina-cai` | SNS root | running · 16.7T | serves the (dead) UI + **full backend IDL in JS bundle** |
| Archive / extra dapp | `oel4p-…`, `guktk-fqaaa-aaaao-a4goa-cai` | SNS root | running | KONG archive; prediction dapp |

- **No EOA controller anywhere.** Every canister's controller is the SNS root, whose controller is SNS governance
  (KONG neurons). Upgrade authority = SNS proposal (privileged/governance path).
- **Cycles are funded for years** (DEX idle burn 26.8B cycles/day; 119.7T ≈ 12 years idle) — nothing is frozen or
  deleted; the canister answers queries normally.
- The backend source is **closed** today (`github.com/KongSwap` only hosts `documentation`,
  `prediction_resolutions`, `spl-meta`). The Sig9 audit (v2.0, 2024-10-07) reviewed the then-private repo at commit
  `43e82e9d…` and found **0 critical / 0 high**, 2 medium, 2 low, 4 info. The live Candid interface was recovered
  from the on-chain frontend asset bundle (see §4).

## 2. Live-state assessment (2026-10-04, anonymous query calls)

### 2.1 DEX pools — fully removed, zero reserves

| Query | Result |
|---|---|
| `pools(null)` | **`Ok([])` — zero pools** |
| `pools("KONG_ICP")` | pool_id **59**, `balance_0 = 0`, `balance_1 = 0` |
| `pools("ICP_ckUSDT")` | pool_id **1**, `balance_0 = 0`, `balance_1 = 0` |
| `pools("ckBTC_ICP")` | pool_id **126**, `balance_0 = 0`, `balance_1 = 0` |
| `tokens(null)` | 132 listed IC tokens, **0 LP-token entries** |
| `icrc1_name()` | `Kong Swap v0.0.21` |

The sunset completed: LPs withdrew. The KONG ledger history for the DEX account shows only outgoing transfers in
its last 100 transactions (last activity **2026-07-08**, tx id 614056; preceding 2026-04-16 and the April-2
withdrawal burst); the DEX's KONG balance is **0**.

### 2.2 DEX token balances — 135 ledgers scanned

Method: for every listed token ledger + the 8 majors, query `icrc1_balance_of(owner = DEX)` anonymously.

| Result | Count | Detail |
|---|---|---|
| Zero | 80 | includes **ICP, ckBTC, ckETH, ckUSDC, ckUSDT, CHAT, BOB, KONG, WTN, PANDA, NTN, MOTOKO** — all 0 |
| Nonzero | 4 | **SNEED 0.154773246140** ($13.39 @ GT $86.49) · BIL 191,485.49265102 (no price feed) · ICE 2.58342338 ($0.001) · NUA 0.81281994 ($0.0014) |
| Dead/frozen/not-found ledger | 51 | e.g. TENDY/CREDITs/LAB frozen; CORS/TTS not found; many "canister stopped". Nothing withdrawable |
| Unlisted but held (separate check) | — | DOLR 4.40395348 ($0.0003) · GHOST 88.05285829 ($0.0018) · ICPSwap 1e-8 — not in the DEX token list ⇒ **stuck**, not credit/withdrawable |

**Total DEX holdings ≈ $13.40 + unpriced BIL** (of which the 0.155 SNEED dominates). No LP tokens exist, so no
liquidity positions are outstanding; user token balances were withdrawn during the sunset.

### 2.3 SNS treasury (governance-controlled)

| Asset | On-chain amount | USD (2026-10-04) | Control |
|---|---|---|---|
| ICP, account `f39d9b22c382c25f832fd1d3e6ad5216249623b204a7fc5498f991f4cf2df1e1` | **119,042.86757995 ICP** | **$406,807.51** @ $3.4173 | SNS governance — critical proposal only |
| KONG, gov subaccount `…ecfd73b8…` (leading 0) | **544,236,777.557809 KONG** | $78,832 nominal (illiquid) | SNS governance — critical proposal only |

### 2.4 Governance state

- **3,708 neurons**: 1,624 NotDissolving · 300 Dissolving · 1,784 Dissolved.
- Total voting power ≈ **63.98e15** (April-2026 tallies; top-100 neurons = 61.79e15).
- Largest cluster: **`ljxsi-5du4w-…` — 7 neurons, 26.37e15 VP (41.2% of total)**, max dissolve delay
  (47,340,288 s ≈ 1.5 y), created at SNS launch. It follows other neurons on **non-critical** topics (0 and 3)
  but has **no followee on treasury topics** (manual voting).
- Critical-proposal rule (confirmed by docs + on-chain proposal params): **≥20% of total VP YES and ≥67% of cast
  YES** (`minimum_yes_proportion_of_total = 2000 bp`, `minimum_yes_proportion_of_exercised = 6700 bp`).
- Proposal history: 363 proposals. Treasury transfers 350/352/353/358/359 **executed** (yes 24.7–43.9e15);
  354/355/356 **rejected** (no 26.0–43.5e15); the Doxa-foundation takeover motions **362/363 rejected 2026-04-06**
  (no ≈ 27.26e15). **No proposals in the last 30 days**; frontend `kongswap.io` now returns **HTTP 530**; DefiLlama
  `deadFrom 2026-04-06`.

### 2.5 Governance-capture feasibility (the only remaining real value)

To pass a critical treasury transfer alone, an attacker must control `VP ≥ 0.2 × (total + VP)` ⇒ **VP ≥ 16.0e15**,
i.e. **~80.0M KONG staked at max dissolve delay (2× bonus)**. Live on-chain KONG liquidity (GeckoTerminal +
ICPSwap API, 2026-10-04):

- Deepest pool: ICPSwap **KONG/ICP `ye4fx-gqaaa-aaaag-qnara-cai` = 3,672,809 KONG + 88.96 ICP ($840.60)**.
- All other KONG pools: 7.9k–18.4k KONG each; **total across all pools ≈ 3.74M KONG (~$547)**; venue reserves
  $1,741 total; **24h volume $0**. The GeckoTerminal "KongSwap KONG/ICP $81,557" pool is **stale** — the real
  KongSwap pool 59 is `0/0`.
- No CEX order book. **80M KONG is not purchasable on-chain** (sweeping every pool yields <5% of the requirement),
  so the capture path requires off-market OTC accumulation — not a permissionless extraction path. The 41%-VP
  incumbent bloc has historically voted on treasury proposals (yes on 350/352/353/358/359, no on 354/355/356).

## 3. What an attacker can / cannot do (exact paths)

The full backend interface (recovered from the frontend bundle, see §4) is:
`add_liquidity(_amounts/_async)`, `add_pool`, `add_token`, `check_pools`, `claim(nat64)`, `claims(text)`,
`get_user`, `icrc10/21/28`, `pools(opt text)`, `remove_liquidity(_amounts/_async)`, `requests(opt nat64)`,
**`send({token, to_address, amount})`**, `swap(_amounts/_async)`, `tokens(opt text)`, `update_token`,
`user_balances(text)`, `validate_add_liquidity/remove_liquidity`.

- **Withdrawals (`send`)** are caller-keyed: the args carry only `{token, to_address, amount}` — no `from` field —
  so a caller can only debit their own internal balance. (Read-only constraint: not exercised; and the DEX holds
  ~$13, so any hypothetical auth bug is capped at ~$13.)
- **`claim(claim_id)`** sends to the claim's stored `to_address`; caller cannot redirect it. No funded claims remain
  (DEX balances ≈ 0).
- **`swap` / `remove_liquidity`** operate on pools — **there are none**, so they cannot move value.
- **`add_pool` / `add_token` / `update_token` are permissionless**, but with zero pools and zero reserves a
  self-created pool can only risk the attacker's own tokens.
- **Queries** (`pools`, `tokens`, `user_balances`, `claims`, `requests`, `swap_amounts`, …) are read-only and move
  nothing.
- **Upgrade/drain via controllers**: impossible for an unprivileged attacker — all canisters are SNS-root-controlled;
  only an SNS proposal (critical) can upgrade the DEX or move treasury funds, and the capture path is closed by
  liquidity (§2.5).

## 4. Evidence & verification

- **CI job (read-only, anonymous query calls):**
  `https://github.com/kingmariano/ca-zombie-ci/actions/runs/37184406945` — **success**.
  - `ci/run.sh` → `ci/icp_audit.py` (pip-installs `ic-py`; queries IC directly).
  - 5/5 audit sections passed (`CORE_OK: True`); 94 query calls OK, 51 expected errors (dead/frozen ledgers).
  - Artifacts: `ci-out/live_state.json`, `ci-out/SUMMARY.txt` (also in `ci-artifacts/result-kongswap/ci-out/`).
- **Live queries reproduced locally** at 2026-10-04 ~06:30–07:55 UTC via `https://ic0.app`; raw JSON in `analysis/`.
- **Full backend IDL** extracted from the on-chain frontend bundle
  `https://3ldz4-aiaaa-aaaar-qaina-cai.icp0.io/_app/immutable/chunks/DVO0zRfs.js` → `analysis/kong_idl_raw.js`.
- **Module hashes / controllers / cycles** from `ic-api` + SNS aggregator (`analysis/sns_root_ormnc.json`).
- **KONG ledger history** for the DEX account via the KONG index (`get_account_transactions`, query) — last 100 txs
  are outflows, latest 2026-07-08.
- **Audit**: Sig9 report (public, `KongSwap/documentation`) → `analysis/sig9_audit.txt`.

## 5. Verdict, residual/latent risk, blockers

**E-U (external unprivileged): $0.00 — high confidence.** No live permissionless extraction path: the AMM is empty,
no LP tokens, DEX holdings are ~$13 of dust, treasury and canister upgrades are governance-gated, and governance
capture is not purchasable with public liquidity.

- **H-O (holder-recoverable): ≈ $13.40** — the DEX dust (mostly 0.1548 SNEED) is the only thing a user could
  plausibly still withdraw via `send`; it is not attacker-extractable.
- **P (governance-only): $406,807.51 ICP + $78,832.16 KONG nominal.** Spendable only by a passing critical SNS
  proposal. The team/`ljxsi` bloc (41.2% VP) has actively voted on treasury proposals.
- **S (stuck): ~$0.002** — unlisted DOLR/GHOST/ICPSwap dust (cannot be credited/withdrawn) plus unknown balances in
  51 dead/frozen ledgers (unreadable; stuck by definition).

**Latent risks / what would change the verdict:**
1. A large holder (e.g. a dissolved neuron or the treasury itself via a passed proposal) dumping **≥80M KONG** into
   the public market would re-open the Yam-class governance-capture path against the $406.8k ICP treasury. Today
   the entire live market holds <4M KONG with $0 volume.
2. If the `ljxsi` bloc (or other large voters) stopped voting on critical proposals, a 20%-VP quorum alone could
   pass a transfer — but that still requires acquiring 80M KONG, which is the binding constraint.
3. The closed-source backend is still callable; if any funds were ever re-deposited (pools re-created, airdrops,
   accidental transfers), `send`/`claim`/pool-math authorization should be re-audited. At current balances the
   impact is negligible.

**Blockers encountered:** (a) read-only rule → update methods (`send`, `claim`, `swap`) were not exercised, so
caller-keying is established from the interface + audit, not by execution; (b) backend WASM/source is closed
(SNS upgrade proposals contain the WASM blob but it is not served by the aggregator API); (c) 51 token ledgers are
frozen/stopped/not-found, so their balances are unreadable (and unwithdrawable); (d) ICP has no block height —
state is timestamped (2026-10-04 UTC).

## 6. Methodology & sources

- Anonymous IC query calls (`query_endpoint`) to the DEX and each token ledger; read_state for module hashes /
  controllers; `ic-api.internetcomputer.org` for canister metadata; `sns-api.internetcomputer.org` for SNS,
  neurons, proposals; GeckoTerminal + ICPSwap public API for KONG pool depth; DefiLlama/CoinGecko for prices.
- Corpus inputs re-verified: DefiLlama `protocol/kongswap` (deadFrom 2026-04-06, last TVL $2.377M),
  Sig9 audit PDF, KongSwap whitepaper, `dfinity/sns-kongswap-adaptor` (KongSwap API types), on-chain frontend
  bundle (IDL).
- **No update calls, no signed messages, no transactions.**

### Files index

| File | Content |
|---|---|
| `README.md` | this report |
| `summary.json` | machine-readable summary |
| `analysis/sns_root_ormnc.json` | full SNS snapshot (canisters, cycles, treasury, tokenomics) |
| `analysis/live_tokens.json`, `tokens_ic.json` | 132 listed tokens |
| `analysis/dex_balances_raw.json` | 135-ledger DEX balance scan (local run) |
| `analysis/kong_idl_raw.js` | recovered backend Candid IDL |
| `analysis/sig9_audit.txt`, `sig9_audit.pdf` | audit report (0 crit/0 high) |
| `analysis/kong_market_depth.md` | KONG venue depth + capture-cost analysis |
| `analysis/sns_proposals_recent.json`, `prop362.json` | proposal history/tallies |
| `analysis/neurons_top100.json`, `sns_neurons_raw.json` | neuron/voting-power data |
| `analysis/kong_whitepaper.md`, `kong_types.rs`, `kong_api.rs` | project docs/interface references |
| `ci/run.sh`, `ci/icp_audit.py` | CI job (read-only audit) |
| `ci-out/live_state.json`, `ci-out/SUMMARY.txt` | CI evidence (same files in `ci-artifacts/result-kongswap/`) |
| `ci-log.txt` | full CI log |
