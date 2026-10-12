# Dojoswap AMM (Injective) — L2 Phase-2 deep dive

**Date:** 2026-10-12 · **Chain:** Injective (Cosmos SDK + CosmWasm) · **Status:** read-only; no transactions;
PoC runs locally/CI in a CosmWasm VM only.

**Scope:** `dojoswap-amm` (L-2 triage row: LIVE-FUNDED, triage value $491,454.09).
Question: how much can an **external unprivileged attacker** extract live, today?

---

## 1. TL;DR

| Target | Live value (priced) | Extractable by unprivileged attacker (E-U) | Why closed/open |
|---|---|---|---|
| Dojoswap factory + 982 pairs (`inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk`) | **$321,276.59** | **$0 from contract bugs** | Terraswap-style pair code 290 (matches published source): exact-funds native checks, CW20 sender allow-list, sender-gated LP burn; pair admin = factory, factory owner-only `MigratePair`; no unguarded execute path found |
| One residual mispricing: USDT/USDC pool (old pair code 307) | $10,686.92 | **$9.26 net** (simulation-verified; $9.95 pre-fee bound) | Pool is 9.0% imbalanced (5,117.73 USDT vs 5,575.98 USDC); no trade since 2026-10-06; buy USDC with USDT → sell USDC ≈1:1. All other 985 pools have <$0.5 residual arb; large pools are arbed within seconds by live bots |
| "Kira Liquidity Locker Test" (code 1178) holding 99% of the POOR/INJ pool LP | $5,297.74 (+POOR) | **$0** | Deployed wasm is a **hardened revision** (not the public source): non-owner `unstake` on an expired lock reverts `Invalid Owner`; the lock owner unstakes successfully (proved by executing the deployed bytecode). Locks are holder-only (H-O) |
| Burned-LP pools (≥95% LP in "Dojoswap Burn Address" contract) | $78,276.41 | $0 | LP claims permanently stuck; reserves remain swap-reachable only by token holders/arb (no free entry) |
| Fee collector EOA (`inj18xg2xfhv36v4z7dr3ldqnm43fzukqgsafyyg63`) | $1,837.20 | $0 (P) | Plain account; only its key can spend |

### Total live extractable now (E-U): **$9.26** (confidence: medium-high)

The honest answer for this zombie AMM is a near-zero E-U: the pair math and access control are intact, the
factory is owner-gated, and the third-party locker that *looked* vulnerable in its published source is patched
on-chain. The only live unprivileged extraction is one stale 9% stablecoin imbalance worth ~$10.

---

## 2. Correction to the triage number (value changed)

Triage row: **$491,454.09**. Corrected live value: **$321,276.59** (priced denoms only).

Root cause: the Phase-1 shortlist described "2.12 peggy-WBTC". WBTC on Injective (`peggy0x2260FAC5…`)
has **8 decimals**; the on-chain total is **0.0212 WBTC ≈ $1.76K**, not 2.12 WBTC (≈$176K). DefiLlama returns
`decimals: 8` for `injective:peggy0x2260…`, and the pool itself is balanced at that scale (0.02044 WBTC vs
217.94 INJ ≈ $1.7K/$1.7K). The $491K figure inflated WBTC by 100×. Everything else (31,868.7 INJ, 53,749.9
USDT, 4.695 WETH, 5,621.4 USDC) matches.

Composition (2026-10-11, blocks 186,884,341–186,892,462):

| Denom | Amount | USD |
|---|---|---|
| INJ | 31,868.70 | $246,004 |
| peggy USDT | 53,749.88 | $53,699 |
| peggy WETH | 4.6951 | $11,862 |
| peggy USDC | 5,621.36 | $5,619 |
| peggy WBTC | 0.02117 | $1,763 |
| ATOM/TIA/DUEL/other priced | — | $2,330 |
| **Total** | | **$321,276.59** |
| Unpriced CW20s (meme tokens etc.) | ~10²⁵–10²⁹ units | ≈ $0 (no market) |

---

## 3. Live-state assessment (all read-only)

**Factory** `inj1pc2vxcmnyzawnwkf03n2ggvt997avtuwagqngk` — code_id **1063**, admin **inj12qy3algm6e0zdpv8zxvauzquumuvd39ccdcdjt** (EOA), label "Dojoswap Deployment".
Config: `{owner: inj12qy3…, pair_code_id: 290, token_code_id: 292}`.

**Pairs:** 982 in the factory registry; all 982 pool queries succeeded. Two extra pairs use an **older pair code
307** (created directly by the factory before the code upgrade): `inj18sf663n6zlh6unevsdv4vrfeqdkc0ze2ktu3aj`
(WETH/INJ, $926) and `inj1qca7g560grtpwfvp8fal8f6gd7aumz6vx923es` (USDT/USDC, $10,687). Two code-290 pairs are
orphans not in the factory (dust: $0 and $11). Every pair's CosmWasm admin is the factory contract, so the
factory owner can `MigratePair` any of them (P).

**Deployed code vs published source:**
- Pair **code 290** = `dojoswap-pair 0.2.0`; execute variants exactly `receive/provide_liquidity/swap` — matches
  `dojo-trading/dojoswap-contracts-public` (Terraswap fork). The pair has **no admin/withdraw entry point**.
- Pair **code 307** (2 pairs) additionally has **`admin_configure`** (removed in the repo's later commit
  "applied audit fixes"). Guard: `info.sender == FEE_COLLECTOR` (hardcoded EOA `inj18xg2xfh…`); it rewrites
  `asset_infos` while keeping the LP token → privileged (P) capability to strand/redirect pool assets. 0.3%
  commission unchanged (verified by simulation).
- Factory **code 1063** has **three execute variants that are NOT in the published source**:
  `set_whitelist`, `admin_withdraw_denom`, `admin_withdraw_token` (confirmed against the official
  `InjectiveLabs/injective-lists` registry and by string analysis of the deployed wasm). The factory holds only
  dust (87 denoms, ~$0), so the impact is negligible; the query interface is unchanged. **Executing the deployed
  factory wasm shows all three are owner-gated** (`unauthorized` for a non-owner caller), so this is a **source
  coverage caveat**, not a live E-U path. `analysis/factory-guard-check.txt`.
- Token **code 292** = cw20-base 1.1.2 (LP tokens instantiated with `admin: None` → immutable).

**Live activity:** aggregator bots still route these pools (e.g. INJ/USDT pool: 1,321 txs, last 2026-10-11
21:34 UTC, via the "Choice Exchange" aggregator `inj18hllkv88dp3jnpjamgslp5ez6u8az3q4s0lkxf`; WETH/USDT: 125
txs; ninja/INJ: 79; NONJA/INJ: 12; dINJ/INJ: 3). 68 CW20-backed orderbook markets are Active; for the tokens
tested (NONJA, DOJO, SHROOM, COKE) the pool price sits **inside the orderbook spread** → no persistent
mispricing.

**LP custody split (by value):** $243,000.18 in pools with live LP holders (EOAs and sender-gated contracts:
Dojoswap staking code 317, merkle-airdrop code 583 [owner-gated `withdraw`], PampIt market code 1038, RYU vault
code 1057); $78,276.41 in pools with ≥95% of LP held by the immutable "Dojoswap Burn Address" contract
`inj1wu0cs0zl38pfss54df6t7hq82k3lgmcdex2uwn` (code 292, admin empty) → those LP claims are unredeemable forever.

**Fee collector** `inj18xg2xfhv36v4z7dr3ldqnm43fzukqgsafyyg63` (EOA, not a contract): 147.32 INJ + 586.78 USDT +
0.0171 WETH + 0.000177 WBTC + small IBC/DUEL/meme balances ≈ **$1,837.20** (half of all historical swap
commissions).

---

## 4. The bug hunt: what was checked and what closed each path

| Surface | Result |
|---|---|
| k-invariant / fee accounting (`compute_swap`, commission rounding) | Standard Terraswap; fees stay in pool except half → fee collector. No exploit |
| LP mint/burn (`provide_liquidity`, `withdraw_liquidity`) | Locked `MINIMUM_LIQUIDITY_AMOUNT=1000` to the pair prevents the "empty supply takeover"; `share=min(...)` ratio math; LP burn only via `withdraw_liquidity` (sender = LP token contract) |
| `receive_cw20` authorization | Only the pool's own CW20 contracts may call; `withdraw_liquidity` requires `info.sender == liquidity_token`. Phantom-deposit requires controlling a pool's CW20 (none of the valuable pools' tokens are attacker-controlled; several are immutable `admin=""`) |
| Native funds spoofing | `assert_sent_native_token_balance` requires exact funds match |
| Factory gating | `update_config` / `admin_config` / `add_native_token_decimals` / `migrate_pair` are owner-only; `create_pair` permissionless (no value at stake). **Verified by executing the deployed factory wasm**: `migrate_pair` / `admin_withdraw_denom` / `set_whitelist` from a non-owner all revert `unauthorized`, while the owner's `migrate_pair` emits `WasmMsg::Migrate` (see `analysis/factory-guard-check.txt`) |
| Zero-side / zero-supply pools | 94 pools have one zero side with `total_share=0`; every one holds exactly 2 wei INJ dust and nothing else. No value |
| Cross-pool mispricing | Only DOJO has ≥2 meaningful pools (prices within 2%); all other multi-pool tokens are dust |
| Live orderbook arb | Pool prices inside spread for tokens with active markets |
| **Locker (code 1178)** — 99% of POOR/INJ LP | **Refuted for the deployed code** (see §5) |
| dINJ/INJ pool ($65,517) | dINJ is a team-issued IOU (minter was an EOA, now removed; no redemption contract). Pool price 1.068 INJ/dINJ; only entry is buying dINJ from the same pool → no fresh-attacker arb. Admin of the dINJ token = factory owner EOA → P (migrate + mint) |
| 3rd-party LP holders (PampIt market/vault, merkle airdrops) | PampIt round-trip simulation: 1 INJ → 9,187.5 KOGA → 0.9788 INJ (≈2% loss) — no arb. Airdrop `withdraw` is owner-gated. P/S |
| **Residual mispricing (USDT/USDC, code-307 pair)** | **OPEN — $9.26 net** (see §6) |

---

## 5. The locker lead and its refutation (why this matters)

A third-party contract labelled **"Kira Liquidity Locker Test"** (`inj1kmu3lhsxz0h49kq342frpnpq6qmpz7pv65zwlq`,
code 1178, admin empty) holds 174,717,569,558,057,606 LP = **99.0%** of the Dojoswap POOR/INJ pair
`inj1859sjey6v43cz40rtj8scka5xng2vn5c37j6f5` ($5,351 pool; 693.16 INJ + POOR), across **11 locks, all expired**
(locktimes Nov 2024 / Apr 2025). The public source (`Marinovs/liquidity-locker`, v1.0) has
`execute_unstake()` that transfers the locked LP to `info.sender` **with no owner check** — a clean
"anyone can claim expired locks" bug (demonstrated by `poc/locker-poc`, 3/3 tests pass).

**But the deployed bytecode is a different, hardened revision** (sha256 `489efa1f…f7df6` ≠ any public commit;
official registry lists extra `update_fee_address`/`extend` variants). Executing the **exact deployed wasm** in
cosmwasm-vm (`poc/wasm-harness`) shows:

```
lock OK (locktime=2592000) -> 99,000 LP locked, owner=lp_owner
*** UNSTAKE BY NON-OWNER (expired lock) REJECTED BY CONTRACT: Invalid Owner
positive control: lock owner unstake SUCCEEDED -> Cw20 Transfer{recipient: lp_owner, amount: 99000}
```

So the locks are **H-O** for their owners (the POOR team address and a KIRA pool owner); E-U = **$0**.
Had this not been tested against the deployed artifact, the report would have claimed ~$5.3K E-U incorrectly.

---

## 6. The one live E-U path: USDT/USDC imbalance ($9.26 net)

Pair `inj1qca7g560grtpwfvp8fal8f6gd7aumz6vx923es` (old pair code 307), reserves **5,117.73 USDT** vs
**5,575.98 USDC** (implied 1.0895 USDC per USDT vs market ≈0.9994). LP: 5.25e9 units (top holder = the factory
owner EOA). Last trade: 2026-10-06 — the imbalance has persisted ≥5 days (bots ignore this small pool).

Path (all permissionless): send USDT → receive USDC at the pool price; sell USDC for USDT ≈1:1 (orderbook
USDC/USDT or another AMM). Constant-product optimum (buy USDC to move pool to market price): pay 217.75 USDT,
receive 226.88 USDC → **≈$9.26 net** (live simulation: `return_amount` = 226,882,670 USDC-raw,
`commission_amount` = 682,697). The pre-fee constant-product bound is $9.95; the extraction is bounded by the
pool's small size.

**Exact call path** (read-only simulation verified at height 186,884,655; no transaction sent):

```
MsgExecuteContract {
  sender: <attacker>, contract: inj1qca7g560grtpwfvp8fal8f6gd7aumz6vx923es,
  funds: [{denom: "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7", amount: "217750000"}],
  msg: {"swap": {"offer_asset": {"info": {"native_token": {"denom":
        "peggy0xdAC17F958D2ee523a2206206994597C13D831ec7"}}, "amount": "217750000"},
        "max_spread": "0.1", "to": null, "deadline": null}}
}
```
then sell the received USDC (`peggy0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48`) for USDT on the Injective
orderbook or another venue. Preconditions: none (no allowlist, no role); cost: gas (~$0.01) + taker fee.

All other pools: computed residual arb < $0.50 each (script `analysis/residual_arb.py`).

---

## 7. PoC / verification

| Artifact | What it proves | Result |
|---|---|---|
| `poc/locker-poc` (cw-multitest, vendored Marinovs source) | The *published* locker source lets any caller unstake an expired lock | **3/3 tests pass** (attacker claims 99,000 LP; owner-path negative control) — historical, NOT the deployed code |
| `poc/wasm-harness` (cosmwasm-vm 1.5, **deployed wasm** `deployed-locker-1178.wasm`) | Deployed code 1178 gates `unstake` by owner | non-owner → `Invalid Owner`; owner → success (CW20 Transfer to owner) |
| `poc/wasm-harness` (bin `factory_check`, **deployed factory wasm** `deployed-factory-1063.wasm`) | Deployed factory code 1063 gates `migrate_pair` / `admin_withdraw_denom` / `set_whitelist` by owner | non-owner → `unauthorized` (all 3); owner `migrate_pair` → `WasmMsg::Migrate` (P path confirmed) |
| `analysis/enumerate.py` | Full 982-pair live snapshot (pools, LP supply, balances) | 982/982 read, 0 errors; heights 186,884,341→186,884,655 |
| `analysis/residual_arb.py` | Residual mispricing across all pools | only the USDT/USDC pool > $0.5 |
| `analysis/verify-locker-independent.md` | Independent subagent verification of the locker claim (fresh reads, raw-storage snapshot, hash checks) | deployed ≠ public source; behavior test completed with the harness above |
| `ci/run.sh` | Reproducible builds (dojoswap + locker), historical PoC, deployed-wasm harness, live re-enumeration | **CI run 1: https://github.com/kingmariano/ca-zombie-ci/actions/runs/38184454300** (success, 104 min) — deployed-locker harness: non-owner `Invalid Owner`, owner success; locker-poc 3/3; live enumeration 982/982 pools at heights 186,894,522→186,904,049; locker scan $5,297.74 (H-O). Run 2 (lean, incl. factory guard check): see `summary.json` |

**CI results in detail (run 38184454300):**
- `locker-deployed-harness.log`: `*** UNSTAKE BY NON-OWNER REJECTED BY CONTRACT: Invalid Owner`; positive control owner unstake succeeded with the CW20 Transfer — the decisive result reproduced on the CI runner.
- `locker-poc.log`: 3/3 tests pass (published Marinovs source, historical).
- `enum.log`: 982/982 pools read, 0 errors; factory vs code-290 set diff 2/2 (the old-code-307 and orphan pairs, as documented).
- `build-dojoswap.log` + `artifact_hashes.txt`: the published repo (commit `5e6ce5b5`, 2024-10-13) builds with `workspace-optimizer:0.15.0`, but the resulting wasm hashes **do not match** the deployed 2023-era code (e.g. built pair `9b7a2b94…` vs deployed `a380f24f…`; built factory `486e8d7f…` vs deployed `392fec8c…`). Deployed↔source equivalence therefore rests on **interface, variant list and behavior checks** (plus the deployed-wasm executions above), not on bytecode reproduction.
- `build-locker.log`: the locker reproducible build **failed** (`rust-optimizer:0.12.6` ships rustc 1.60; `time-core 0.1.2` needs ≥1.67). This does not affect the conclusion: the deployed locker is already known to be an unpublished revision, and the decisive test runs the **deployed** wasm.

Block citations for the headline: pool state at height 186,884,655 (2026-10-11T22:1xZ); locker state
186,888,846–186,892,462; deployed locker wasm sha256 `489efa1fc9cb0bdffb1a7a387beab7a3112cd7a01a12a894b99f636cc4f7df6`.

---

## 8. Categories and verdict

| Category | USD | Detail |
|---|---|---|
| **E-U** (external unprivileged) | **$9.26** | residual USDT/USDC arb (net at optimal size; $9.95 pre-fee bound). Confidence medium-high: mechanism fully verified, persistence not guaranteed (any bot may take it) |
| **H-O** (holder-only) | **$248,297.92** | LP holders of live-LP pools ($243,000.18) + locker lock owners ($5,297.74). Token holders of burned-LP pools can additionally sell into pools (≈$78,276 not counted here) |
| **P** (privileged) | **$321,276.59** (+$1,837.20) | factory owner EOA `inj12qy3…` can `MigratePair` every pair to a drainer (admin = factory contract) and drain all reserves; same EOA admins the dINJ token (mint/migrate) and 2 code-307 pairs' assets can be rewritten by the fee-collector EOA. Fee collector EOA holds $1,837.20 |
| **S** (stuck) | **$78,276.41** | LP claims in pools with ≥95% LP in the immutable burn-address contract are unredeemable by anyone (reserves still swap-reachable) |

**Verdict:** Dojoswap AMM is a clean-but-abandoned Terraswap fork whose custody (~$321K priced) is protected by
correct pair math and owner-gated administration. An unprivileged attacker can extract only ≈$10 today. The
main live risks are privileged (factory-owner migration key, fee-collector key) and the main value is
holder-recoverable (LP holders, lock owners).

**Residual/latent risks:** (1) factory owner key can drain all pairs (single EOA); (2) code-307 pairs expose
`admin_configure` to the fee-collector EOA; (3) if a pool asset's CW20 admin migrates its token to a lying
implementation, that pool's other side can be drained (none observed today); (4) any new mispricing is
arbitrageable by anyone (bots are active).

**Blockers/caveats:** the published factory source does not cover the deployed factory's 3 extra variants
(dust-only impact); Injective LCDs occasionally return stale/absent metadata (peggy decimals, some IBC denoms),
so all decimals used here were cross-checked against pool balance symmetry and DefiLlama.

---

## 9. Methodology & sources

- Live reads: keyless public LCDs (`injective-api.polkachu.com`, `injective-rest.publicnode.com`), public
  Injective exchange module, DefiLlama prices, CoinGecko (stale, not relied upon), official
  `InjectiveLabs/injective-lists` wasm registry, Injective tx search.
- Source: `dojo-trading/dojoswap-contracts-public` (pair/factory/token/staking/router/launchpad),
  `Marinovs/liquidity-locker`, deployed wasm bytecode (downloaded from chain and executed locally).
- Scripts and raw dumps: `analysis/` (enumeration, valuation, residual arb, LP-holder scan, locker scan,
  wasm trace). Independent verification: `analysis/verify-locker-independent.md`.
- No transactions were signed or sent; all heavy jobs run on GitHub Actions (public CI) or in a local
  CosmWasm VM; no secrets are present in this folder.

### Files index

```
dojoswap-amm/
├── README.md                      (this file)
├── summary.json                   (machine-readable)
├── analysis/                      enumeration, valuation, residual arb, LP scans, locker scan, wasm trace,
│                                  verify-locker-independent.md, raw JSON dumps
├── poc/locker-poc/                cw-multitest PoC of the published-source locker flaw (historical)
├── poc/wasm-harness/              decisive test of the DEPLOYED locker wasm (cosmwasm-vm)
├── ci/run.sh                      CI: reproducible builds + PoCs + live re-enumeration
├── ci-out/                        CI outputs (uploaded as artifacts)
└── ci-log.txt                     CI run log (written by ci-run.sh)
```
