# H-15 · BFly Finance (Starcoin) — live extraction audit

**Date:** 2026-10-03 · **Chain:** Starcoin mainnet (chain_id 1, non-EVM / Move VM) · **Status:** read-only; PoC is live-RPC + bytecode-disassembly verified; **no mainnet transactions were sent.**

> **Headline: an external unprivileged attacker can extract ~775 XUSDT (~$775) right now** by buying mispriced FAI from the live TokenSwap STC/FAI pool and using it to liquidate the protocol's 4,000,000-STC underwater whale vault. Net of 0.3 % swap fees and slippage; capital required ≈ 786 XUSDT (obtainable on-chain). In STC terms the net is **+811,059 STC** (1.9–4.8× depending on trade size). Confidence: **medium-high**.

---

## 1. TL;DR

| Target | Live value (on-chain) | Extractable by external unprivileged attacker | Why open/closed | Latent risk |
|---|---|---|---|---|
| STCVaultPoolA (lending/CDP) | 14,060,938.32 STC locked · 34,928.87 FAI debt · 189 vaults | **E-U ≈ 775 XUSDT net** (STC-holder path: +811,059 STC) | **OPEN**: FAI in the Starswap STC/FAI pool costs ~19–40 STC but liquidations redeem at **111.11 STC/FAI** (deployed `clip` formula). 31 vaults incl. a 4M-STC whale are below HF 1. | Pool re-prices as soon as anyone arbitrages; oracle price ($0.01) is 90× the last market print |
| FAI stablecoin | 34,935.88 total supply; 4,822.21 in admin treasury | FAI itself: none directly; used as the arb input | Minting FAI costs 300 STC/FAI (ccr 300 %) → mint-to-liquidate is a 63 % structural loss | If ccr is ever lowered by admin, minting becomes a direct inflation path |
| ETHVaultPoolA | 0.011012 ETH · 7.008 FAI debt | **none** — `Liquidation::clip` silently no-ops for non-STC collateral (`is_same_token<Ty1,STC>` gate) | Closed by code path | ETH stays in vaults; owners may be able to withdraw if healthy |
| Treasury (FAI) | 4,822.21 FAI | **none** — `Treasury::get_with_capability` needs a `WithdrawCapability` that was never created | Closed (capability) | Admin could create the cap via `Vault::create_treasury` (admin-gated) |
| Config / global switch | n/a | **none** — `update_config` is deprecated (aborts); signer paths assert admin | Closed | Admin can freeze/retune at will |

**Total live extractable now (E-U): ~775 XUSDT (≈$775; XUSDT is the Starcoin-bridged USDT).** In STC: +811,059 STC (≈$90 at the last market print $0.00011112; ≈$8,111 at the protocol's own $0.01 oracle price, which is not realizable externally).

## 2. The mechanism, in exact terms

The deployed protocol is a Maker-style CDP system (FAI is minted against STC at `ccr = 30000` = 300 %). All logic was verified from **on-chain Move bytecode** (`analysis/disasm/`, fetched with `state.list_code`, disassembled with the exact starcoinorg/move toolchain used by starcoin v1.13.22):

- **Borrow capacity** (`LiquidationHelper::cal_max_borrow`): `max_borrow = collateral × price × 1e4 / ccr` → at ccr = 3, **300 STC of collateral buys 1 FAI**.
- **Liquidation seizure** (`Liquidation::clip` → `STCVaultPoolA::crack` → `Vault::rearrange`, both `public(friend)`):
  `collateral_seized = cover × 1e8 / (price_value × (100 − penalty))` → at price_value = 10000, penalty = 10, **1 FAI repaid seizes 111.111 STC**.
- **Liquidation gate**: `health_factor_by_address = collateral_usd / (1.5 × (debt + fee))`; liquidatable when ≤ 1e18. 31 vaults qualify today, including whale vault `0x0c357315f9351540114596324f41006e` (id 10041, debt 33,472.93 FAI + 3,779.43 fee, collateral 4,000,000 STC, HF 0.7158).

On its own, minting FAI to liquidate is a structural loss (300 STC locked vs 111.11 STC seized). **The open path is a live DEX mispricing:** the Starswap `TokenSwapPair<STC, FAI>` at `0x8c109349c6bd91411d6bc962e080c4a3` holds **410,813.79 STC / 21,413.90 FAI → FAI costs only 19.18 STC at spot** (rising with slippage; marginal cost still < 111 STC for the first ~10,800 FAI). The 305 FAI transfers seen in explorer data are all `peer_to_peer_v2`; DEX swaps are not in that feed, which is why the pool was missed initially. The DEX global freeze switch is **off**, the poundage is **3/1000 (0.3 %)**, and the pool traded as recently as 2026-10-01.

## 3. The attack (exact, net of costs)

Full cycle, all calls permissionless, atomic-able in one Move script:

1. **XUSDT → STC** on the STC/XUSDT pool (`0x8c10…`, 3,889,384 STC / 4,520.87 XUSDT): spend **786.34 XUSDT** → **574,795 STC**.
2. **STC → FAI** on the STC/FAI pool: 574,795 STC → **12,472.68 FAI** (0.3 % fee + slippage included).
3. **Liquidate** whale vault via `MarketScript::liquidation(whale, cover=12,472.68 FAI)`:
   cover ≤ half of debt+fee (18,626.2 ✓), seizure **1,385,854 STC** ≤ whale collateral 4,000,000 ✓, HF < 1 ✓.
4. **STC → XUSDT** back through the STC/XUSDT pool → **1,561.44 XUSDT**.

**Net profit = 775.10 XUSDT (1.9857×).** With existing STC instead of XUSDT: net **+811,059 STC**, sellable for **778.14 XUSDT**. Smaller trades earn higher multiples (e.g. 10,000 STC → +46,375 STC, 4.6×). A second cycle is not profitable — after the trade the pool price is ~110 STC/FAI, at the break-even.

All quotes were reproduced **on-chain** with `TokenSwapLibrary::get_amount_out` (e.g. 410,813.791 STC → 10,690.866 FAI exact) and match the local constant-product model. The clip formula was independently calibrated against the protocol's own 9 historical `ClipEvent`s (July 2022): all imply a then-price of $0.0398–0.0407, tightly consistent.

## 4. Live-state assessment (all values read at Starcoin head **32,904,523**, 2026-10-03)

| Contract | Address | State |
|---|---|---|
| Admin / all modules | `0x4ffcc98f43ce74668264a0cf6eebe42b` | 30 modules; global switch **OFF** (`get_global_switch = false`) |
| STC pool | `…::STCVaultPoolA` | `stc_amount = 14,060,938.315319777 STC`, `current_fai_supply = 34,928.867248789 FAI`, `vault_count = 189` |
| ETH pool | `…::ETHVaultPoolA` | `eth_amount = 0.01101153 ETH`, `fai_supply = 7.008 FAI` |
| FAI | `…::FAI::FAI` | supply 34,935.875723197 FAI; treasury holds 4,822.212531853 FAI |
| Oracle | `0x82e35b34096f32c42061717c06e44a59` | `STCUSD = 10000/1e6 = $0.01`; bot updates it every ~10 min (last update today). Requires the oracle account's key — not attacker-reachable |
| STC/FAI pool | `0x8c109349c6bd91411d6bc962e080c4a3::TokenSwap::TokenSwapPair<STC, FAI>` | 410,813.79 STC / 21,413.90 FAI; last activity 2026-09-17; freeze off |
| STC/XUSDT pool | same DEX | 3,889,384.28 STC / 4,520.87 XUSDT; last activity 2026-10-01 |

Vault census: the entire 34,928.87 FAI principal debt is attributable to 158 STC vaults recovered from explorer events + account state; **31 of them are liquidatable** (collateral 4,051,161 STC; debt+fee 37,718 FAI). The remaining ~9.8M STC of pool collateral sits in debt-free vaults (not liquidatable, not attacker-reachable). Market reference: STC last print **$0.00011112** (CoinGecko/Coinbase/TradingView, ~$6/day volume; Gate.io delisted). The protocol's own oracle says $0.01 — **90× above market** — so vault health is inflated, not deflated.

## 5. What an attacker can / cannot do

**Can:**
- Buy FAI at 19–40 STC from the live pool (0.3 % fee) and liquidate any of the 31 underwater vaults via the public `MarketScript::liquidation` entry.
- Seize 111.11 STC per FAI repaid (up to the vault's collateral and half-debt cap), then sell STC back into the STC/XUSDT pool.
- Net ~775 XUSDT with ~786 XUSDT capital; or +811,059 STC with pre-held STC. No keys, roles, whitelist or insider access required.

**Cannot (verified from bytecode + live state):**
- Call `crack`/`Vault::rearrange` directly (`public(friend)` only); the clip ratio is enforced.
- Write config: `Config::update_config` is **deprecated and aborts**; `update_config_sign`/`set_global_switch` assert the admin address.
- Drain the treasury: `Treasury::get_with_capability` requires a `WithdrawCapability`; `create_treasury` is admin-gated and **no shared capability resource was ever created** at the admin address (`Treasury::Vault<FAI>` holds 4,822 FAI, permanently locked).
- Use lock products: `lock_*` needs `VaultPoolConfigExtension` (absent) → always aborts; `STCTreasury`/`STCVaultPoolB` are uninitialized.
- Liquidate ETH vaults: `Liquidation::clip` gates the transfer on `is_same_token<Ty1, STC>` — the ETH path is a silent no-op.
- Profit by minting FAI: 300 STC locked per FAI vs 111.11 seized (63 % loss), price-independent.
- Withdraw another user's healthy collateral, or the whale owner's own unhealthy collateral (HF 0.716 < 1 → `withdraw` aborts).

## 6. PoC / verification

- `poc/verify_bfly.py` — live read-only verification: re-reads all state, re-derives the economics from the deployed formulas, discovers the DEX pools, and computes the exact full-cycle profit with integer AMM math. Run in CI (`ci/run.sh` step 2).
- `analysis/disasm/*.txt` — full disassembly of all 30 deployed modules (CI-built `move-disassembler` at starcoin's pinned rev `7b6ac7bb`).
- `analysis/independent-review.md` — independent subagent re-audit; **falsified the initial "no extraction" hypothesis and reproduced the same exploit (+811,070 STC)**, and separately confirmed the dead paths.
- `analysis/arb_opt2.py`, `arb_full_cycle.py`, `dex_quote.py` — exact optimization and on-chain quote checks; `analysis/explorer/` — 1,266 BFly txs / 2,949 events (incl. 9 historical liquidations used to calibrate the clip formula).

**CI runs (public repo `kingmariano/ca-zombie-ci`):**
- **`37138697284` — FINAL (success): disassembly of all 30 modules + live arbitrage verification (net 775.10 XUSDT; 31 liquidatable vaults; pools quoted on-chain)**
- `37136137184` — disassembly + baseline live verification (pre-DEX discovery)
- `37133323542` — first successful disassembly of all 30 modules

CI artifacts: `ci-artifacts/result-bfly-finance/ci-out/` (disasm/, verification.json, verification.md, logs/); full log in `ci-log.txt`.

**Limitations:** Starcoin has no EVM-style fork framework; the PoC is therefore *live view-call + exact bytecode-model* rather than a forked state transition. Signer-arg dry-runs are unsupported by the node's `contract.call_v2` (verified), so the state-changing call sequence is proven by (a) the disassembled bytecode, (b) live view functions (`info`, `health_factor_by_address`, `get_amount_out`, `get_reserves`), and (c) the protocol's own historical liquidation events. No transaction was sent.

## 7. Verdict, residual risk, blockers

**E-U = ~775 XUSDT net today (medium-high confidence).** The value exists because a live DEX pool misprices FAI ~2.7× below the protocol's own liquidation redemption rate; the opportunity is real but **self-extinguishing**: any arbitrageur (or the whale's owner) re-prices the pool. The whale owner could also self-liquidate to recover part of their own collateral. Nothing privileged is required.

- **H-O (holder-only):** 10,009,777 STC of collateral in healthy vaults is withdrawable by its owners (≈$1,112 at market; ≈$100,098 at the protocol oracle price).
- **P (privileged):** admin can freeze/retune; the 4,822 FAI treasury has no withdraw capability and is effectively burned; no admin path takes user collateral.
- **S (stuck):** ETH pool 0.011012 ETH (liquidation no-op) and the whale's residual collateral after the arb (~2.6M STC) remain in an unhealthy vault (owner cannot withdraw; further seizure requires FAI that the arb consumes).
- **Blockers/caveats:** XUSDT is a bridged token assumed ≈USDT (if discounted, the STC-denominated result still holds); the pool state can change between read and execution; public mempool allows copy-trading (no active searchers observed); thin external STC liquidity means the STC-denominated profit is best realized through the pool itself.

## 8. Methodology & sources

- DefiLlama `api.llama.fi/protocol/bfly-finance` + adapter `projects/bfly.js` (identifies Starcoin + `STCVaultPoolA::current_stc_locked` + `0x1::STCUSDOracle`).
- Starcoin RPC `https://main-seed.starcoin.org` (`state.list_code`, `contract.get_resource`, `contract.call_v2`, `contract.resolve_function`, `node.info`) — head block recorded above.
- GitHub `BFlyFinance/FAI` (source for the earlier versions; deployed v1.0.x differs and was audited from bytecode), `starcoinorg/move` @ `7b6ac7bb` (disassembler), `starcoinorg/starcoin` v1.13.22 (RPC semantics).
- stcscan.io API (`doapi.stcscan.io/v2/...`) for the full transaction/event census.
- CoinGecko for the STC market reference.

**Files:** `README.md`, `summary.json`, `poc/verify_bfly.py`, `ci/run.sh`, `analysis/{bfly_modules.json, abi.json, all_vaults2.json, vault_state.json, independent-review.md, disasm/, explorer/, *.py}`, `ci-artifacts/`, `ci-log.txt`.
