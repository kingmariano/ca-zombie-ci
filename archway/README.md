# C2-09 — Archway (`archway-1`): unpatched wasmvm (permissionless halt **and** sandbox-escape minting) + governance-capture economics

**Campaign:** zombie-hunt II · **Chain:** Cosmos `archway-1` · **Date of work:** 2026-10-05
**Status:** read-only research. No transactions signed or sent on any network. Evidence = public
RPC/LCD reads at pinned heights + CI artifact verification (no chain execution, no fork needed —
Cosmos has no EVM fork surface). All PoCs are local/CI-only.

**Measured heights:** 17,644,198 (initial), 17,644,323/17,644,367 (state + CI enumeration).

---

## 1. TL;DR

| # | Surface | Live unprivileged extraction | Why open / closed | Latent risk |
|---|---|---|---|---|
| 1 | **CWA-2026-006 Wasmer Singlepass sandbox escape** — store + instantiate an attacker contract | **Capability confirmed** on the deployed version. Measured on-chain extraction bound **$18,382** (hard/major assets in ARCH-connected pools + Osmosis); nominal DEX TVL reachable ≈ **$111k**; contract-held value **$162,869** if the escape permits direct fund theft (unproven) | `code_upload_access = Everybody`, `instantiate_default = Everybody`; wasmvm **v1.5.5** (hash-matched), Wasmer **4.2.2**; advisory explicitly says unmaintained lines are affected and will not be patched; Archway's latest release (v10.1.1, 2026-01-20) still pins 1.5.5 | Patched only by upgrading to wasmvm 2.2.9/2.3.5/3.0.8 (Wasmer 7). No config-only mitigation; restricting upload/instantiate raises the bar |
| 2 | **CWA-2025-001 / 002 / 007, CWA-2026-003 / 005** — chain crash / stall | **$0 direct** — liveness damage only | Same open upload; patches never applied (wasmvm 1.5.5; wasmd 0.51.0 is an EOL line with no 0.51 patch for any of them) | Any of them can halt or stall the chain; no extraction follows |
| 3 | **Governance capture** | Community pool **$36,959** immediate (gov-only); capture cost **$28.4k–$56.6k** nominal | quorum 33.4% / threshold 50% / veto 33.4%; recent turnout ≈90–100% of bonded; CP spends #52/#53 rejected; treasury not spendable; **0/9,644 contracts gov-administered** | Rational only if turnout collapses or combined with the minting primitive (free tokens → stake → vote) |
| 4 | Treasury module (x/rewards `TreasuryCollector`) | **$0** — no spend mechanism exists | Module proto: "no mechanism is available to withdraw ATM" | A future upgrade could change this |
| 5 | Foundation / vesting / grants contracts (Eco Grants, genesis-airdrop, vesting) | Not permissionlessly drainable today | Contract logic + dev/foundation admins; no bug identified | $145,020 ARCH held there is the main pool at risk under a direct-theft variant of CWA-2026-006 |

**Headline: an external unprivileged attacker can, per the vendor advisory, store + instantiate a
malicious contract on Archway today and exploit a critical Wasmer sandbox escape to mint native
ARCH / cause fund loss. The measured, swap-extractable on-chain bound is $18,382; the nominal
reachable pool value is ~$111k; $162,869 sits in wasm contracts. Independently, several
permissionless chain-halt vectors remain unpatched ($0 extraction), and governance capture can
take the $36,959 community pool at a nominal $28.4k–$56.6k cost (negative EV under normal
turnout).**

---

## 2. Total live extractable now

| Class | Amount (USD) | Confidence | Notes |
|---|---|---|---|
| **E-U** (CWA-2026-006 mint→dump, measured) | **$18,382** | capability **high**, amount **medium** | $15,925 hard/major assets in 189 pool-like contracts (Astrovault pools, Bolt markets, Balanced, Liquid Finance, PampIt) + $2,458 Osmosis ARCH-pool other-side. The CI model's all-contract figure ($19,880 hard+major, i.e. $22,337 incl. Osmosis) also counts hard assets in non-pool contracts that minting alone cannot swap out. Exploit trigger is not public; not reproduced |
| E-U (nominal pool TVL reachable) | ~$110,972 | low–medium | DefiLlama Astrovault Archway TVL; dominated by long-tail assets (secret cw20s, ujkl/uist/upasg, uandr/udec…) whose external exit markets are unverified. Priced-and-verifiable Astrovault content: $15,411 |
| E-U (direct fund theft variant) | up to $162,869 | low | Advisory says "permanent loss of user funds"; if native-code execution permits arbitrary state writes. $145,020 of that is ARCH in vesting/grants contracts |
| **capture** (gov-only) | **$36,959** | high (params/balances) / medium (passability) | Community pool only. Treasury $17,338 not spendable; no gov-administered contracts |
| **DoS** | **$0** | high | Five live permissionless halt/stall vectors; destructive, not extractive |
| Off-chain (CEX dump of minted ARCH) | unmeasured | — | Minted ARCH could be deposited to CEXs; not measurable from on-chain data |

---

## 3. The bug(s) in exact terms

### 3.1 Deployed stack (verified)

- Node `application_version`: app `archway` **v10.1.0**, commit `f56aca02…`, SDK v0.50.10,
  wasmd **v0.51.0** (Archway fork of 0.50.2), **wasmvm v1.5.5** (sum
  `h1:XlZI3xO5iUhiBqMiyzsrWEfUtk5gcBMNYIdHnsTB+NI=`), ibc-go v8.7.0, cometbft v0.38.17.
- `sum.golang.org` for wasmvm v1.5.5 returns the **same hash**; the Go module zip sha256 is
  `669a4752ff88402db67985ef95f8b2e63185a4d4d673df6d4b514d6eae71909e`. The binary was built
  against genuine upstream wasmvm 1.5.5 — not a fork.
- Inside that hash-matched artifact: `libwasmvm/src/memory.rs` has the **unfixed**
  `ptr: data.as_ptr()` for empty slices (CWA-2025-001 fix absent); `Cargo.lock` pins
  cosmwasm-vm **v1.5.8** (lacks the CWA-2025-002 gas charges — those land in v1.5.10) and
  Wasmer **4.2.2**.
- For comparison, wasmvm v1.5.8 (2025-02-04) pins cosmwasm-vm v1.5.10 (gas fix) and contains
  the memory.rs null fix; **Wasmer is still 4.2.2** there — the Wasmer 7 upgrade only ships
  in wasmvm 2.2.9/2.3.5/3.0.8 (2026-09-28).
- `code_upload_access = Everybody`, `instantiate_default_permission = Everybody` (h 17,644,367).
  889 codes by 91 distinct creators; 8,232–9,644 contract instances enumerated across the two CI
  runs (code 31, the EvolvNFT factory, returns pagination-unstable counts of 3,600–5,000+;
  the union of both runs is 9,644). Permissionless upload is in active use.

### 3.2 CWA-2026-006 — critical, fund loss (disclosed 2026-09-28)

"A code generation defect in the Wasmer Singlepass compiler, which wasmvm embeds to execute
CosmWasm contracts, allows a specially crafted contract to escape the WebAssembly execution
boundary and run controlled native instructions inside the node process. On an affected chain
this permits **unauthorized minting of native tokens and permanent loss of user funds**.
Exploitation requires an attacker to store and instantiate a contract they control… reachable
by any ordinary funded account, with no governance action, privileged address, validator key
or collusion." Affected: wasmvm ≤2.2.8/≤2.3.4/≤3.0.7 **and** "versions outside the maintained
lines are affected and will not be patched" → **1.5.5/Wasmer 4.2.2 is affected**.
"There is no configuration only mitigation."

The natural extraction is mint ARCH → swap into every ARCH-connected pool. Measured pool
content: $13.0k USDC, $1.37k AKT, $0.63k APLANQ, $0.26k BTSG, plus small majors in Astrovault
pools; $2.46k USDC/OSMO in Osmosis ARCH pools; ~$0.5k in Bolt/Balanced/Liquid. Total measured
$18.4k. DefiLlama values the Astrovault pools at $110,972, but the difference is long-tail
assets with unverified exit markets. If the escape permits direct state manipulation, the
$162.9k held in wasm contracts (led by three "Eco Grants" contracts with 67.5M ARCH each,
`genesis-airdrop` 32.7M, `vesting` contracts ~46M) is exposed.

### 3.3 CWA-2025-001 / 002 / 007 / 2026-003 / 005 — permissionless DoS

- **CWA-2025-001** (GHSA-23qp-3c2m-xx6w): malicious contract crashes the chain; fix is the
  missing null-ptr-for-empty-slices change in `libwasmvm/src/memory.rs` (deployed copy
  unfixed). CWE-476. The precise trigger is not public; not reproduced here.
- **CWA-2025-002** (GHSA-mx2j-7cmv-353c): malicious contract slows block production because
  host calls and memory reads are not gas-metered; the deployed cosmwasm-vm v1.5.8 lacks
  `charge_host_call_gas` / `read_region_*_cost` (verified in source; present in v1.5.10).
- **CWA-2025-007**: unbounded reply recursion → stack overflow → node crash; wasmd ≤0.54.2
  affected, patch line starts at 0.54.3 — Archway's 0.51.0 has no patch. Mechanism is public.
- **CWA-2026-003**: attacker-caused block-production delays; wasmd ≤0.54.7 affected.
- **CWA-2026-005**: large numbers of Wasm locals stall the chain; unmaintained lines affected.

**Does a halt enable value extraction?** No measurable path found: Archway has no liquidation
windows that pay the attacker, the IBC transfer escrow module account is empty ($0), no bridge
escrow is exposed, and all staking/unbonding flows simply freeze. A halt is purely destructive
(it could, however, mask the CWA-2026-006 exploitation). See §6.

### 3.4 Governance capture

Params (abci decode): quorum **0.334**, threshold **0.5**, veto **0.334**, voting **7 d**,
min deposit **5,000 ARCH**, expedited proposals unusable (min-deposit denom `"stake"`).
Bonded **221,867,913 ARCH ($85,004)**. To pass a CP spend: quorum-only needs **74,103,883 ARCH
($28,391)**; beating full turnout needs **110,933,957 ($42,502)**; veto-proof needs
**147,764,030 ($56,613)**. The only immediate prize is the community pool **96,464,698 ARCH
($36,959)** — the treasury has no spend path, and **0 of 9,644** contracts are gov-administered
(Astrovault/Eris/Liquid/Balanced are dev-administered). Recent turnout is 200–250M ARCH
(≈90–100% of bonded); both historical CP spends were rejected (#52: no 191.0M vs yes 188.4M;
#53: no 180.5M vs yes 48.4M). On-chain ARCH float in pools is only ~9.8M, so the 74M–148M
ARCH required cannot be acquired on-chain without extreme price impact; CEX/OTC accumulation
is required but unmeasurable. Capture is therefore **not a reliable standalone profit path**;
it becomes rational combined with the free minting primitive.

---

## 4. Live-state assessment (all reads public, heights recorded)

| Item | Value | Source |
|---|---|---|
| Node app / wasmvm | v10.1.0 / **v1.5.5** (sum match) | `/cosmos/base/tendermint/v1beta1/node_info` h 17,644,367 |
| Wasm params | upload Everybody, instantiate default Everybody | `/cosmwasm/wasm/v1/codes/params` |
| Codes / contracts | 889 / 9,644 union (8,232 in the final run; code-31 EvolvNFT pagination varies; 9,531 with balances) | full enumeration in `ci-out/` |
| Bonded / not-bonded / supply | 221,867,913.393 / 270,057,400.329 / 1,178,684,426.923 ARCH | `/cosmos/staking/v1beta1/pool`, supply |
| Community pool | 96,464,698.230 ARCH = $36,959 | `/cosmos/distribution/v1beta1/community_pool` |
| Distribution module (CP+fee pool) | 115,302,678.954 ARCH | module balances |
| Treasury (`x/rewards` TreasuryCollector) | 45,253,663.343 ARCH = $17,338 — **no spend path** | module balances + proto comment |
| Gov module / gov-administered contracts | `archway10d07y265gmmuvt4z0w9aw880jnsr700j0f0puy` / **0** | `/cosmos/auth/v1beta1/module_accounts`; enumeration |
| IBC transfer escrow | **0** | module balances |
| Validators | 18 bonded; largest DELIGHT 39.93M (18.0%) | staking validators |
| Contract-held value | **$162,869** ($145,020 ARCH; $15,925 USDC/USDT; $3,949 majors) | bank balances of all contracts |
| Astrovault | 429 contracts, dev admin `archway1d78gwz…`; pools priced at $15,411; DefiLlama TVL $110,972 | enumeration + DefiLlama |
| Osmosis ARCH pools | GAMM 1061/1063/1375 (1375 holds 6.70M ARCH + 2,422.85 USDC); CL 1160/1298/1419/3097/3108/3111 | Osmosis LCD scan |
| ARCH price | $0.00038313 (DefiLlama) / $0.00036736 (CoinGecko) | price feeds at query time |
| Chain liveness | block 17,644,323 @ 2026-10-05T16:03:52Z; no pending upgrade | LCD |

Full data: `ci-out/core_state.json`, `ci-out/contract_infos.json`,
`ci-out/contract_balances.json`, `ci-out/top_contracts.csv`, `ci-out/model.json`,
`ci-out/module_balances.json`, `ci-out/osmosis_pools.json`, `ci-out/node_evidence.json`.

---

## 5. What an attacker can / cannot do

**Can (permissionless, funded account only):**
1. `MsgStoreCode` a crafted Wasm (upload is Everybody) and `MsgInstantiateContract` it
   (instantiate default Everybody) — the delivery path for all advisories above.
2. Trigger a chain halt/stall via CWA-2025-001/002/007/2026-003/005 (cost: gas only;
   block limit 300M gas).
3. Trigger CWA-2026-006 to mint native ARCH / cause fund loss. Per the advisory, no
   governance, validator key or collusion is needed. The published outcome is minting;
   a direct-theft variant would put contract-held funds at risk.
4. Capture governance with capital: buy/acquire ≥74.1M ARCH, delegate/stake, submit a
   `MsgCommunityPoolSpend`, vote yes (7-day window, 21-day unbonding). CP spends have been
   rejected before; turnout is high.
5. Sell minted ARCH into Archway pools (measured $15.9k hard/major), IBC-transfer to Osmosis
   (measured $2.5k), or attempt CEX deposits (unmeasured).

**Cannot (verified):**
- Migrate/drain Astrovault, Eris, Liquid Finance, Balanced contracts via governance — their
  admin is a dev multisig, not the gov module (0/9,644 gov-administered).
- Spend the treasury module's 45.25M ARCH — no message path exists in v10.1.0.
- Extract value from a chain halt — no liquidations/bridge escrow that pay the attacker;
  IBC transfer escrow is empty.
- Take bonded/unbonding stake via governance — only a validator-adopted software upgrade
  could rewrite state, which is not autonomous.
- Drain foundation/vesting/grants contracts through any identified permissionless path.

---

## 6. PoC / verification (CI)

All heavy work ran on GitHub Actions (`github.com/kingmariano/ca-zombie-ci`), read-only:

| Run | URL | Purpose | Result |
|---|---|---|---|
| 1 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37338418163 | first full enumeration (codes→contracts→infos→balances, gov, Osmosis) | success; artifacts in `ci-artifacts/result-archway/` |
| 2 | https://github.com/kingmariano/ca-zombie-ci/actions/runs/37343115254 | final: + wasmvm artifact verification + fixed gov decode/model | **success**; artifacts in `ci-artifacts/result-archway-run2/`; log `ci-log.txt` |

Run 2's wasmvm checks (also in `ci-out/wasmvm_artifact_check.txt`): v1.5.5 module zip
sha256 `669a4752…` — CWA-2025-001 fix **False**; v1.5.8 zip sha256 `9745c2ac…` — fix **True**;
Go smoke tests linking each prebuilt `libwasmvm.x86_64.so` print **"1.5.5"** and **"1.5.8"**.
Run 2's model (CoinGecko price $0.00036736): community pool $35,437; quorum $27,223;
hard+major in all contracts $19,880; wasm contract total value $156,868.

**wasmvm artifact verification** (`ci/wasmvm_poc.sh`, output `ci-out/wasmvm_artifact_check.txt`):
- downloads the exact Go module zips for v1.5.5 and v1.5.8 (sha256 recorded), verifies the
  live node's `build_deps` hash against `sum.golang.org`;
- prints the Rust pins (`cosmwasm-vm` v1.5.8 vs v1.5.10; Wasmer 4.2.2 in both) and whether
  the CWA-2025-001 memory.rs fix is present (absent in 1.5.5, present in 1.5.8);
- builds two tiny Go programs that link the prebuilt `libwasmvm.x86_64.so` from each module
  and calls `wasmvm.LibwasmvmVersion()` → prints **"1.5.5"** and **"1.5.8"** respectively.

**Not reproduced:** the CWA-2025-001/002/006 crafted-contract triggers are not public ("more
detail will be added once chains had a chance to upgrade"), so no crash/mint PoC exists in
this work. The claims rest on the vendor advisories + the exact deployed-artifact match. No
chain interaction beyond public reads; nothing was uploaded or executed on archway-1.

---

## 7. Verdict & residual risk

- **E-U (theft) — capability CRITICAL, live:** wasmvm 1.5.5 + open upload/instantiate +
  CWA-2026-006 (disclosed 2026-09-28, no Archway release fixes it, no emergency governance
  action since). Measured extraction bound **$18,382**; nominal **~$111k**; **$162,869**
  contract-held exposure in the direct-theft variant. Confidence: capability high; exact
  amount medium (private exploit).
- **DoS — live:** five unpatched permissionless halt/stall vectors; $0 extraction. A halt is
  purely destructive for Archway (no forced-exit/liquidation/bridge value path found).
- **Capture — marginal:** CP $36,959 vs $28.4k–$56.6k nominal capture cost, with high
  historical turnout, dev-administered protocols, and no on-chain float. Negative EV unless
  turnout collapses or the attacker uses the minting primitive.
- **Latent risk:** the chain's entire exposure disappears only with a coordinated upgrade to
  wasmvm ≥2.2.9/3.0.8; the 1.5 line will never be patched. Until then, any funded account can
  deliver the exploit. Restricting upload/instantiate would raise the bar but not neutralize
  already-stored contracts (none attacker-owned identified today).

**Blockers to immediate exploitation:** the CWA-2026-006 trigger is not public; a working
crafted contract is required. No other blocker exists — upload, instantiate and execution are
all open.

---

## 8. Methodology & sources

- Public Cosmos LCD/RPC (`api.mainnet.archway.io`, `rpc.mainnet.archway.io`, plus 3
  independent LCDs for node evidence), Osmosis LCD, `sum.golang.org`, `proxy.golang.org`,
  DefiLlama/CoinGecko price APIs, CosmWasm advisories repo + GHSA/OSV, wasmvm/cosmwasm/wasmd
  sources and tags, Archway v10.1.0 source.
- Full contract census: 889 codes → 9,644 contracts → `contract_info` (label/admin) → bank
  balances; denom-trace resolution for IBC denoms; USD valuation for stablecoins and major
  assets; long-tail assets reported unpriced.
- Every claim carries an address/param and a block height; no transactions were signed or sent.
- CI: two GitHub Actions runs (URLs above), artifacts downloaded to `ci-artifacts/`.

**Caveats & limitations**
- The CWA-2026-006 exploit is not public; "extractable" for that path is an advisory-based
  bound, not a demonstrated end-to-end extraction. The measured $18,382 is what the pools
  actually hold; realizable USD for long-tail assets is likely lower.
- USD values are point-in-time (2026-10-05, ARCH $0.000367–$0.000383); re-verify before acting.
- CEX liquidity (for both capture accumulation and minted-ARCH dumping) is not measurable here.
- The 9,644-contract census includes 5,000 EvolvNFT instances; governance/ownership findings
  are based on on-chain `contract_info`, not source review of every contract.
- This is informational security research; no audit of Archway, Astrovault, Bolt or any
  listed protocol was performed beyond the checks documented.

**Files index**
```
archway/
├── README.md                      # this report
├── summary.json                   # machine-readable summary
├── analysis/
│   ├── version-evidence.md        # node/go.mod/sum.golang.org/artifact evidence
│   ├── advisory-analysis.md       # CWA → deployed-version mapping
│   ├── gov-capture-model.md       # params, pools, cost model, turnout
│   ├── gov_params_abci_decoded.json
│   ├── node_info.json, codes_all.json, code_contracts.json, contract_infos.json,
│   │   key_contract_balances.json, proposals_v1.json, ibc_channels.json, cg_price.json …
├── ci/
│   ├── run.sh                     # heavy job entry
│   ├── enumerate.py               # full chain census + core state
│   ├── model.py                   # economics model
│   └── wasmvm_poc.sh              # artifact hash/pins/linked-lib verification
├── ci-out/                        # CI results (core_state, balances, model, logs)
├── ci-artifacts/                  # downloaded run artifacts
└── ci-log.txt                     # CI log
```
