# savmSwap (SatoshiVM + Prom) — Phase-2 deep dive

**Date:** 2026-10-12 · **Chains:** Prom (chainid 227, live) · SatoshiVM (chainid 3109, unreachable/dead)
**Status:** read-only; PoC fork-verified only; **no mainnet transactions were sent**. All reads via keyless public RPCs.

---

## 1. TL;DR

| Target | Live value | Extractable by external unprivileged attacker | Why open/closed | Latent risk |
|---|---|---|---|---|
| savmSwap UniV2 factory `0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9` (Prom), **90 pairs** | **$234,906.73** (30,213.12 WPROM + 76,138.45 USDT) | **$0.00** (best-case dust paths ≤ $0.93 gross; ≈ $0.8 net of gas) | Canonical UniV2 pairs (source-verified), **no skim excess anywhere**, no public mint, factory admin gated, live pool arb-tight, LP owned by users/owners | $52.7k sits in **LP-burned** meme pools (swap-only, reachable only by memecoin holders); $29.2k LP held by memecoin owners (they can pull any time); bridged USDT/USDC are upgradeable proxies (privileged admin) |
| savmSwap factory `0x1842c9bD09bCba88b58776c7995A9A9bD220A925` (SatoshiVM) | unknown ($0 measurable) | $0 (chain unreachable) | RPC DNS is NXDOMAIN (`alpha-rpc-node-http.svmscan.io`), explorer blocked, SAVM ≈ $0.005 / ~$30k mcap / $21 daily volume | If the chain ever restarts, state unknown; SVM-side TVL recorded as 0 by DefiLlama |

**Total live extractable now: $0.00** — confidence **high** (Prom). The $234.9k that is live is *custody*, not exploitability:

| Category | USD (block 10073447, PROM $5.2549) | Composition |
|---|---:|---|
| **E-U** (external unprivileged) | **0.00** | dust only (≤ $0.93 gross per path, see §6) |
| **H-O** (holder/user-only) | **182,063.85** | main pool LP 99.851% held by one EOA `0x2bA8…` ($152,790.92) + small main-pool LPs ($48.24) + LP pools held ~100% by memecoin owner EOAs ($29,224.70) |
| **P** (privileged) | **181.77** | feeTo (`0x5559…`, team) minted protocol LP across all pairs (main pool $179.66) (+ latent $4,379.77 unminted fee, §5.6) |
| **S** (stuck/bricked) | **52,661.12** | LP burned to `0xdEaD` in 55 meme pools ($52,622.53) + LP locked inside 5 token contracts ($38.60) |

Live value is essentially unchanged from triage ($233,735.57 at PROM $5.219 on 2026-10-11 → $234,906.73 at $5.2549; ≈$233.3k at the 2026-10-12 price $5.2011).

---

## 2. What savmSwap is, and what was actually checked

savmSwap is a plain **Uniswap V2 fork** (DefiLlama `forkedFromIds: ['2197']`, registry `savmswap` → factories `svm: 0x1842…`, `prom: 0x3B73…`). The Prom deployment (Nov 2024) is a live, actively-traded 90-pair DEX whose main pool WPROM/USDT still processes swaps daily; the SatoshiVM deployment is dead with its chain.

For a UniV2 fork the complete set of unprivileged extraction surfaces is:

1. **Pair math**: k-invariant, fee-on-transfer / rebasing weirdness, `skim()` of excess balances, `sync()` manipulation, LP mint/burn verification.
2. **LP custody**: who can redeem the reserves (LP holders), farms/staking holding LP, allowances.
3. **Token surfaces**: public `mint()`/`claim()` on any pooled token (WPROM, USDT, USDC, memecoins), transfer hooks.
4. **Admin/roles**: factory `feeTo`/`feeToSetter`, `migrator`, pair ownership, token ownership.
5. **Economic**: arbitrage vs real market prices (stale pool quotes), circular routes, flash-loan viability.
6. **Ecosystem contracts**: launchpad ("V60" registries/factories/router), the meme-token vault, fee collectors.

All six were examined on-chain; every candidate path is enumerated with its gate in §6.

---

## 3. Live-state assessment (addresses · code · roles · blocks)

**Block anchors:** pair dump block **10073191**; accounting block **10073447**; final checks **10073535** (2026-10-12, Prom tip). CI PoC ran on a fork of the live tip.

### 3.1 Factory & pairs
- Factory `0x3B73a7eDc9dfE4847a20BcCfEf6Eb1c90439f5C9`: `allPairsLength() = 90`; `feeTo() = feeToSetter() = 0x55594E57F80b2deCd63608A4F2802F8003633aD2` (team EOA, creator of the factory); factory source unverified, but behavior is canonical (`setFeeTo`/`setFeeToSetter` revert for outsiders; no `migrator()`).
- Pairs are **canonical `UniswapV2Pair` 0.5.16** — source verified on `promscan.io` API (`/api/v2/smart-contracts/0x1ddb…` returns `UniswapV2Pair.sol`, standard code), `factory()` of sampled pairs returns the factory; reserves/balances/LP behavior all canonical.
- 90 pairs: 1 live WPROM/USDT pool + 89 stale meme pools (all last-updated 2024-12 → 2025-10 except the main pool, which updated **2026-10-12**).

### 3.2 The only materially live pool
`0x1ddbf7113e3711ae9918f2dc14efb6b302b1e0d2` — WPROM/USDT:
- reserves `r0 = 14,630.805686554919 WPROM`, `r1 = 76,134.728318 USDT` (block 10073191); balances **equal reserves** (no excess); LP `totalSupply = 2.7833e16`; `kLast = 9.9259e32` < `k = 1.1139e33` (unminted fee exists, §5.6).
- **LP holders**: `0x2bA8968C1AE5984f049F28085f50D7Df4aD1a01e` = **99.851067%** (unlabeled EOA; an external LP — 2024-11-29 add-liquidity txs through the savmSwap router, 2025-08-01 LP moves; 21.8 PROM gas balance), feeTo = 0.117409%, ~49 small EOAs = 0.031523%.
- **Trades are live**: Swap events in the last 5,000 blocks at $5.13–5.22/WPROM (bots `0x86a70cc3…` router / `0xe3a426e5…`), i.e., the pool is actively arbitraged against market; pool marginal price $5.2037 vs market $5.2549 (0.97% below) at fork time.

### 3.3 Tokens
- **WPROM** `0x04a21a38d5e275d6023b27504beb3095dc43b0c0`: standard WETH9-style wrapper (verified; `deposit`/`withdraw`, no owner, no mint; unknown-selector calls hit the payable fallback → no-op).
- **USDT** `0x7e942605b5028e3b751dbb5ef8afc5cf85a5a7ed`: **TransparentUpgradeableProxy** (bridged, total supply ≈ 95,668.88 USDT ≈ $95.7k, 7,637 holders — note the main pool alone holds 76,134.7 of it, ~80% of supply). Proxy admin `0x8e8028f6…` (ProxyAdmin contract, owner `0x65bf3dee…`); implementation `0xe9670937…`, impl `owner() = 0xd7c6daB96Fce04C20E25288231D552cA3eF7339e`. `mint(address,uint256)` reverts for outsiders.
- **USDC** `0xd9c95e2ad330e11d7dfa58f18504049f625e955e`: same proxy stack (admin `0x8e8028f6…`, impl `0x3ee354ec…`, owner `0xd7c6daB9…`).
- **Memecoins** (gyro, FKS, Rkt, BRUV, USTC, BEEBEE, BAAI, CAT, BOB, …): all launchpad-created. Two templates: 5,796-byte (only `owner()` + `lock()` selectors; no mint) and 2,920-byte Ownable (`mint`/`burn` present but **owner-gated** — attacker simulations revert). All memecoins named here are fake/branded memes (e.g., the "USTC" token has 32 holders and no relation to Terra).

### 3.4 Ecosystem contracts (same team EOA `0x5559…`)
- 22 deployments: factory `0x3B73…`, router `0x86a70Cc3…`, 4 × `V60AddressRegistry` (verified; roles-gated; **0 balances**), meme factories, `Dummy Token`, launchpad helpers — **all hold 0 native and 0 tokens**.
- Launchpad vault `0x6Eda4EB3D0D79AA581e7Bb4bFb4E993489e7212C` (created by EOA `0xE48E17f2…`): holds 500M gyro, 250M SCTA, 250M EZMODE, 110M PROME, 41M WTHL. Its only function is `retrieve(uint256,address)` = `require(token.owner() == msg.sender); token.transfer(msg.sender, amount)` — **owner-gated** (see §6.4).
- No farms/staking/chef contracts exist for savmSwap on Prom: LP-holder scans across all 90 pairs found **no contract holding material LP** (only 5 tiny pools where the memecoin contract itself holds its own LP, $38.60 total). DefiLlama's savmSwap adapter is the plain uniswapV2 registry (factory only).

### 3.5 SatoshiVM side
- Chainid 3109. RPC `alpha-rpc-node-http.svmscan.io` → **DNS NXDOMAIN** (checked locally and via Google DoH); other historical endpoints dead; `svmscan.io` resolves (Cloudflare) but blocks automated access. SAVM ≈ $0.005, ~$30k mcap, $21/day volume — chain economically dead. DefiLlama `currentChainTvls.SatoshiVM = 0`.
- SVM factory `0x1842c9bD09bCba88b58776c7995A9A9bD220A925` cannot be read; any value there is unverifiable/stuck (**S/UNREACHABLE**, not counted).

---

## 4. Negative results (so they are not re-investigated)

1. **No skim-able excess on any of the 90 pairs** — `balanceOf(pair) == getReserves()` for both legs, checked twice at different blocks (10073191, 10073447) and in the fork PoC (9 top pools; attacker `skim()` moves 0).
2. **No public mint** on WPROM, USDT, USDC, FKS, BOB, gyro, Rkt, Rkt2, BRUV, USTC, BEEBEE, BAAI, CAT (simulations from an outsider revert; bytecode selector scans match).
3. **No factory admin takeover**: `setFeeTo(attacker)` and `setFeeToSetter(attacker)` revert.
4. **No farm/chef/vesting contract holding LP** (full holder scan of all pairs).
5. **No public claim on the launchpad vault** — outsider `retrieve()` reverts (gate = the token's own `owner()`).
6. **Launchpad registries/factories/router hold nothing** and are role-gated (`AccessControl`).
7. **No circular-arb route with material depth**: all other pools pair WPROM with worthless memecoins; the only real-value cross-pools are dust (WPROM/USDC $5.4; two USDT/USDC pools ~$11 combined).
8. **The main pool cannot be manipulated profitably**: a same-pool round trip loses ~0.6% (PoC: 10,000 USDT → 9,947.0 USDT back); buying 10k USDT of WPROM at the fork block had **negative** edge (−$1,098) because the trade moves the pool; the *optimal* arb size is ~260 USDT with ≈ **$0.89** gross profit (before any exit costs).

---

## 5. What an attacker can/cannot do (exact paths, preconditions, costs)

**Attacker model:** external EOA, own capital or flash loans, no roles, no insider tokens, public mempools.

### 5.1 LP withdrawal (main pool) — CLOSED (not attacker)
`pair.transferFrom(lp, attacker, …)` requires LP ownership; 99.851% of LP sits with `0x2bA8…`. Its LP allowances are **all zero** (router `0x86a70Cc3…`, team `0x5559…`, v60 router/factory: 0 at block 10073736+), so no contract can pull the position; the router can only spend on the owner's own call. (Residual USDT allowance 0x2bA8→router = 1,157.80 USDT is only spendable via the owner's own calls.) Attacker gets **$0**.

### 5.2 skim() — CLOSED
`skim(to)` transfers `balanceOf(this) − reserve`. Verified 0 for every pair → attacker gets **$0** (PoC T2).

### 5.3 Mint/claim — CLOSED
No callable mint/claim on any pooled token (PoC T4; token scans). The vault's `retrieve` is gated to `token.owner()` (PoC T5).

### 5.4 Admin — CLOSED
Factory setters revert (PoC T3). feeTo is the team EOA; protocol fee LP accrues to it (P, §5.6).

### 5.5 Swap-based value extraction — DUST
- **Main pool vs market (E-U candidate #1):** pool is 0.97% below market at fork time; optimal buy ≈ 260 USDT ⇒ **≈ $0.89 gross**, and realization requires selling WPROM off-chain (CEX/bridge) at market with additional cost. Net ≈ $0.8 or less. Not material.
- **Stale WPROM/USDC pool `0xbcdbf1a7…` (E-U candidate #2):** implied $10.50/WPROM vs market $5.25; depth only 10.81 USDC ⇒ optimal dump 0.43 WPROM ⇒ **$0.93 gross** (PoC T7, 933,089 USDC-units). Gas on Prom is 45 gwei ≈ $0.035/swap. Dust.
- **All other stale pools** pair WPROM with memecoins that have **no market** and no free acquisition path (no mint, no other pool, supply concentrated with owners/vault). They cannot be dumped by a generic attacker.
- **LP-burned pools (S, §5.7)**: the WPROM inside can only be swapped *out* by someone who already holds the paired memecoin — see the conditional path §6.

### 5.6 Team/protocol fees (P)
- Minted feeTo LP across all pairs: **$181.77** (main pool $179.66; the rest are slivers in meme pools, previously counted with those pools and moved to P here).
- **Unminted protocol fee** (UniV2 `_mintFee`, minted to feeTo on the next mint/burn): **$4,379.77**, of which **$4,286.52** in the main pool (`kLast` stale since the last LP event; formula `totalSupply·(√k−√kLast)/(√k+√kLast)`). This dilutes current LPs when triggered; not extractable by outsiders.

### 5.7 Custody of the rest
- **H-O ($182,063.85)**: main-pool LP holders (one EOA $152,790.92 + small LPs $48.24) and the memecoin-owner LPs ($29,224.70: FKS $17.2k, BRUV $3.2k, USTC $2.4k, BEEBEE $2.2k, BAAI $1.9k, CAT $1.5k, BOB $0.8k, …). Each can `burn()` their LP any time; nobody else can.
- **S ($52,661.12)**: 55 pools with ≥99.9% LP at `0xdEaD` (gyro $45,579.46, Rkt $4,461.77 + $1,901.19, …) + 5 pools with LP locked in the memecoin contract itself. LP position bricked; reserves remain swappable.

---

## 6. Conditional/insider paths (NOT E-U, documented for completeness)

1. **Memecoin owner dumps into its LP-burned pool** — e.g., the gyro owner (`0x036A2e88…`) can `retrieve()` 500M gyro from the vault + holds 40.27M → dumping the full 540.3M gyro extracts **4,681.39 WPROM = $24,600** from the gyro pool (of 8,673.63 WPROM = $45.6k; CPMM depth caps it) — PoC T8. This is an insider liquidating their own token position, not an unprivileged attack; the same applies to the $29.2k owner-held LP pools (owners can simply `burn`).
2. **Bridged stablecoins are upgradeable** — USDT/USDC proxies are admin-controlled (`0x8e8028f6…`, owner `0x65bf3dee…`; impl owner `0xd7c6daB9…`). The admin could upgrade to a minting implementation and drain pool value — a **privileged** trust vector (P), out of scope for E-U but relevant to anyone valuing the USDT leg.
3. **Memecoins with owner-mint** (FKS, BOB) — owner could mint and dump into their own pools; owner-gated (P), and those owners already hold the pool LP.

---

## 7. PoC / fork verification

- Project: `poc/` (Foundry, solc 0.8.24, `lib/forge-std` vendored). Fork of **Prom chainid 227** via keyless `https://rpc.prom.io` (`vm.envOr("PROM_RPC_URL", …)`); test contract = unprivileged attacker.
- **CI runs:**
  - https://github.com/kingmariano/ca-zombie-ci/actions/runs/38236858197 — **8/8 PASS** (first verification)
  - https://github.com/kingmariano/ca-zombie-ci/actions/runs/38239808803 — **8/8 PASS**, artifact `result-savmswap.zip` (artifact ID 11742781583; contains `ci-out/poc-results.json`)
  - Logs: `ci-log.txt`; summary: `ci-out/poc-results.json`.

| Test | Result | Key logged numbers |
|---|---|---|
| T1 live state | PASS | 90 pairs; main price $5.203727 vs market $5.254945; LP user 99.851%; feeTo 0.117%; `kLast`<`k` |
| T2 skim | PASS | 9 pools: `balanceOf == reserves`, attacker `skim()` moves 0 |
| T3 factory admin | PASS | `setFeeTo`/`setFeeToSetter` revert |
| T4 mint | PASS | FKS/BOB/USDT mint revert for outsider; WPROM fallback no-op |
| T5 vault | PASS | outsider `retrieve` reverts; owner retrieves 5.0e26 gyro (gate proof) |
| T6 main-pool arb | PASS | 10k USDT buy edge −$1,098; round trip 10,000 → 9,947 USDT |
| T7 stale USDC pool | PASS | implied $10.4977/WPROM; max dust profit **$0.933** at 0.43 WPROM |
| T8 burned-LP pool | PASS | LP 99.998% at `0xdEaD`; full-supply holder extracts 4,681.39 WPROM ($24,600) |

Gas context: Prom gas 45 gwei → ~$0.035 per swap; the dust paths net ≤ ~$0.8.

**Fork block note:** `vm.createSelectFork` logged `0` for the fork block (Foundry 1.8.5 / RPC quirk), but all reads matched the live reserves recorded at blocks 10073191–10073535 — the fork was at the live tip, so the tests demonstrate the state **today**, not a historical one.

**Independent verification (childA):** a separate read-only recomputation from scratch at block **10073736** reproduced the totals exactly: 90 pairs, 30,213.118074586335223614 WPROM + 76,138.447675 USDT across all pairs, **0 pairs with balance≠reserve**, main-pair LP shares 99.851067% / 0.117409%. Re-priced at $5.2549 it gives $234,905.36 vs this report's $234,906.73 (−0.0003%). Files: `childA-verify/verify.py`, `childA-verify/verify-results.json`, `childA-verify/README.md`.

---

## 8. Verdict & residual risk

**Verdict: E-U = $0.00 (high confidence).** No external unprivileged path to material value exists in the savmSwap Prom deployment today: the pair code is canonical and solvent, no excess balances exist to skim, no token is publicly mintable, admin surfaces are gated, and the single live pool is arbitraged to within ~1% of market so even the theoretical optimum is sub-$1. The triage number ($233.7k) is real but is **LP custody** — mostly one user's $152.8k LP — plus $52.7k of LP-burned (swap-only) pools and $29.2k of owner-held LP.

**Residual/latent:**
- The $52.7k in LP-burned pools becomes withdrawable value for whoever holds the paired memecoins **if a market ever appears** for them (bounded by supply vs CPMM depth, e.g., ≤$24.6k of gyro's $45.6k for a full-supply holder).
- The $29.2k owner-held LP is one transaction away from being pulled by those owners (a rug of their own pools' meme buyers).
- The bridged USDT/USDC proxy stack is upgradeable by its admin (privileged).
- SatoshiVM-side state is unverifiable while the chain is dead.

**Blockers that would change the verdict:** a public market for any paired memecoin with price < pool-implied price; a public mint on any pooled token; an unpause of a launchpad function allowing token minting; LP transfers/allowances moving the main-pool LP to a vulnerable contract; or a USDT/USDC proxy upgrade (privileged).

---

## 9. Methodology, sources, caveats, files

**Methodology:** DefiLlama registry/adapter enumeration → factory event/`allPairs` enumeration (90/90) → direct on-chain reads at pinned blocks (keyless public RPC, batched `eth_call`) → promscan.io (Blockscout API) for verified sources, holders, and tx history → role/gate simulations from outsider addresses → Foundry fork PoC on CI (8 tests) → independent verification child (`childA-verify/`).

**Sources:** on-chain (authoritative); `promscan.io` API (verified sources, holders); DefiLlama (`api.llama.fi`, `coins.llama.fi` — PROM $5.2549 @ ts 1791798779; $5.2011 @ ts 1791800583); l2-triage-b corpus (row 7).

**Caveats:**
- USD values move with PROM price (±1% = ±$2.3k); token prices for memecoins are ~0/unpriced.
- Custody classification relies on the top-holder pages (50/page) per LP token; residual dust below the first page is negligible for the totals (verified remainder arithmetic).
- `0x2bA8…` is unlabeled: H-O classification is literal (single-holder recoverable); if it is a team wallet, re-label H-O→P for that $152.8k.
- The 5,000-block swap scan and activity checks are point-in-time; the main pool remains actively traded.
- SatoshiVM side is excluded as unverifiable.

**Adjacent finding (not counted here):** the same team's second factory `0x0e2b8eE0A672AD9A0eA0434cC93557CDb5eF3f19` ("v60", DefiLlama lists it as a separate protocol with $400k, which **double-counts** factory `0x3B73…`) has 18 stale WPROM/meme pools with ≈ 7,910 WPROM (~$41.6k; biggest: WPROM/LUKAS 5,321 WPROM) — same structure, no excess, no E-U path found. The orchestrator may want it as its own row.

**Files:**
- `analysis/prom.py` — keyless RPC helper (no secrets) · `analysis/dump_pairs.py` — 90-pair dump · `analysis/pair_table.json`, `analysis/pairs_prom.json` — pair/reserve/LP/blockTimestampLast data
- `analysis/lp_holders.py`, `analysis/lp_holders.json` — per-pair LP holder custody (contract vs EOA vs burn)
- `analysis/final_accounting.py`, `analysis/final_accounting.json` — category accounting at block 10073447
- `analysis/unminted_fees.py`, `analysis/unminted_fees.json` — protocol-fee estimate
- `analysis/scan_tokens.py`, `analysis/token_selectors.json`, `analysis/token_scan.json` — mint/gate scans
- `analysis/team_deployments.json`, `analysis/team_contracts_value.json`, `analysis/team_contract_sources.json` — team contract enumeration · `analysis/src_*.json/.sol` — verified sources pulled from promscan
- `analysis/dump_factory2.py`, `analysis/pairs_factory2.json` — adjacent v60 factory dump
- `poc/foundry.toml`, `poc/test/SavmswapProm.t.sol` — PoC (8 tests)
- `ci-log.txt`, `ci-out/poc-results.json` — CI evidence · `childA-verify/` — independent recomputation
