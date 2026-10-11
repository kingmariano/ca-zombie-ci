# JediSwap V1 (Starknet) — L2 Phase-2 deep-dive: live extractable-value determination

**Campaign:** zombie-hunt II · L2 watchlist Phase 2 · **Chain:** Starknet mainnet (SN_MAIN) · **Date of work:** 2026-10-11
**Status:** read-only research. No transactions were signed, sent or broadcast. All "attack" evidence is
`starknet_call` / `starknet_simulateTransactions` (read-only RPC) against live mainnet state, plus a byte-exact
class-hash reconstruction of the deployed code from public source. No secrets, no keyed endpoints.

**Target set:** JediSwap V1 factory proxy `0xdad44c139a476c7a17fc8141e6db680e9abc9f56fe249a105094c44382c2fd`
and **all 1,051 pair proxies** registered by it, plus the V1 router `0x041fd22b…f97023`.
**Triage value:** $825,856.29 (`l2-triage-c`, block ≈ 16229xxx).

---

## 1. TL;DR

| # | Surface | Live extractable (external unprivileged) | Why closed / open today | Latent risk |
|---|---|---|---|---|
| 1 | 1,051 pair proxies (all reserves) | **$0.00** | Faithful Uniswap-V2 port, byte-verified against source; every state-changer is reentrancy-locked and invariant-checked; no zero-supply / zero-reserve / stale-reserve pair exists; proxy upgrades are admin-gated and the admin (Argent wallet) cannot be driven by third parties (protocol blocks direct `__execute__` calls — proven by simulation) | None found for a third party; privileged admin holds an upgrade key over all pairs (P) |
| 2 | Factory proxy | **$0.00** | Holds no funds; `set_fee_to`/`set_fee_to_setter` gated by `fee_to_setter` (= admin); `fee_to = 0` (protocol fee off); `create_pair` permissionless but value-neutral | Admin can turn protocol fees on (mints LP to `fee_to`, ≤1/6 of k-growth) — privileged |
| 3 | Skim-able excess in 4 pairs | **≈ $0.000003** (zETH) + unpriced memes | `skim` uses strict `checked_sub_lt` on **both** legs → single-sided excess reverts. Unlockable by donating 1 wei to the empty side (proven), but the excess tokens are unpriced memes (TEST, LEA, STARKY) or 1.1e12 wei zETH | If any of TEST/LEA/STARKY ever gains a market, the unlock-skim (1 wei + gas) can claim it |
| 4 | V1 router | $0 (router holds 0.00101 ETH ≈ $2.53, **stuck**) | Router is stateless (no sweep); its 0.00101 ETH can only move if the admin upgrades the router (P) | P only |

**Total live extractable by an external unprivileged attacker right now: ≈ $0.00** (sub-cent; headline
`$0.00`, confidence **high**).
**Holder-recoverable (H-O): ≈ $825,881** — LP holders can still `burn` their LP (directly or via
`router.remove_liquidity`); no pause, no lock, router live.
**Privileged (P): ≈ $825,881** — a single Argent smart-wallet admin can `upgrade()` every pair proxy (and the
factory/router) to arbitrary code. Not reachable by third parties today.

---

## 2. What was actually checked (and why the answer is $0)

### 2.1 Deployed code is byte-identical to public source (class-hash proof)

The factory, all pairs and the router are **upgradeable proxies** (OpenZeppelin Cairo upgrades v0.4.0b pattern).
The implementation classes were reconstructed from public source and match the live on-chain classes **exactly**:

| Contract | Live class hash | Source | Match |
|---|---|---|---|
| Pair impl | `0x2b39bc3f4c1fd5bef8b7d21504c44e0da59cf27b350551b13d913da52e40d3b` | `jediswaplabs/JediSwap@11b4414 contracts/Pair.cairo` | ✅ |
| Factory impl | `0x2580632f25bbee45da5a1a1ef49d03a984f78dde4019069aa9f25aac06f941a` | `…/Factory.cairo` | ✅ |
| PairProxy | `0x7b5cd6a6949cc1730f89d795f2442f6ab431ea6c9a5be00685d50f97433c5eb` | `…/PairProxy.cairo` | ✅ |
| FactoryProxy | `0x26fe8ea36ec7703569cfe4693b05102940bf122647c4dbf0abc0bb919ce27bd` | `…/FactoryProxy.cairo` | ✅ |
| Router impl | `0x64e7d628b1b2aa04a35fe6610b005689e8b591058f7f92bf4eb234e67cf403b` | `…/Router.cairo` | ✅ |
| RouterProxy | `0x7197021c108b0cc57ae354f5ad02222c4b3d7344664e6dd602a0e2298595434` | `…/RouterProxy.cairo` | ✅ |

Method: compile with `cairo-lang 0.10.0` + OpenZeppelin `cairo-contracts@b764660` (v0.4.0b), flags
`--dont_filter_identifiers`; compare `compute_class_hash` to `starknet_getClassHashAt`. **Program `data` and
`hints` are byte-identical** to the on-chain classes (only `debug_info`, which the sequencer strips, differs).
⇒ the source audit below is an audit of the exact deployed bytecode.

### 2.2 The pair contract is a faithful Uniswap-V2 port (nothing free)

`contracts/Pair.cairo@11b4414` (verified against the live bytecode):

- `mint`, `burn`, `swap`, `skim`, `sync` all start with `_check_and_lock()` (reentrancy lock, `_locked` storage).
- `mint`: `amount = balance − reserve` (strict, reverts if stale-low); if `totalSupply == 0` →
  `liquidity = sqrt(a0·a1) − 1000`, with `MINIMUM_LIQUIDITY = 1000` minted to address `0x1`
  (**not a contract on Starknet** — unreachable, so totalSupply can never return to 0); else
  `liquidity = min(a0·TS/r0, a1·TS/r1)` (rounds down, favours the pool). `assert liquidity > 0`.
- `burn`: `amount = liquidity·balance / totalSupply` (rounds down); asserts both legs > 0.
- `swap`: standard V2 checks — `amountOut > 0`, `amountOut < reserve` (strict), `to != token0/token1`,
  optional flash-swap callback `jediswap_call`, then `balance > reserve − amountOut` (input), and the
  **k-invariant** `(b0·1000 − a0in·3)·(b1·1000 − a1in·3) ≥ r0·r1·1e6` (0.3 % fee) with `uint256` checked math.
- `skim`: `amount_i = balance_i − reserve_i` via **`uint256_checked_sub_lt`** (strict `balance > reserve` on
  **both** legs) — stricter than V2; single-sided excess makes the call revert.
- `_update`: reserves = balances, cumulative prices, `assert balance.high == 0` (u128 cap).
- `_mint_protocol_fee`: reads `factory.get_fee_to()`; **live `fee_to = 0`** ⇒ protocol fee off; `klast` cleared.
- ERC20 (LP) is OZ v0.4.0b `ERC20` (no `permit`; standard allowance checks; `_spend_allowance` handles
  infinite allowance).

### 2.3 Live-state census (block 16229786, 2026-10-11 ~16:07 UTC; factory/proxy reads 16229540–16229806)

| Metric | Value |
|---|---|
| Pairs registered (`get_num_of_pairs`, `get_all_pairs`) | **1,051** (matches triage) |
| Pairs with non-zero reserves | 1,039 |
| Pairs with `totalSupply == 0` **and** balances > 0 (mint-and-drain class) | **0** |
| Pairs with one zero reserve (free-drain-swap class) | **0** |
| Pairs with balance < reserve (stale-low, revert-only) | **0** |
| Pairs with balance > reserve (skim excess) | **4** (all single-sided; see §1 #3) |
| Pairs holding their own LP (burn-claimable by anyone) | **0** |
| Pairs whose raw `_locked` storage ≠ 0 (bricked) | 0/120 sampled locally, full sweep in CI |
| Pairs whose raw `_factory` storage ≠ factory | 0/120 sampled locally, full sweep in CI |
| Pair implementations / admins | **1,051 × same impl `0x2b39bc3f…`, same admin `0x284a1ad6…`** |
| Pair proxy class | 1,051 × `0x7b5cd6a6…` |
| Factory `fee_to` / `fee_to_setter` | `0` / `0x284a1ad6382cffc520d8f711cf9519ccf43b3c105b89ef081cbe1a625322410` |

**Value (DefiLlama, 2026-10-11):** my independent re-read gives **$825,881.12** (priced legs) — within 0.03 % of
the triage's $825,856.29. Top legs: **160.55 ETH ≈ $402.2K**, 270,165.6 USDC ≈ $270.1K, 72,267.6 USDT ≈ $72.2K,
39,523.6 DAI ≈ $39.5K, 0.2423 WBTC ≈ $20.1K, 3.105 wstETH ≈ $9.7K, 78,569.7 STRK ≈ $9.2K, plus ~760
unpriced meme/scam-token legs (fake "STRK", SPIST, DRAB, STARKY, YAD, …). **Live value has not materially
changed since triage.**

Top pairs: ETH/USDC `0x4d0390b7…c19db6a` ($467.5K), ETH/USDT `0x45e7131d…3fb7dd6` ($88.9K),
ETH/WBTC `0x7e2a13b4…da63138` ($57.3K), `0x5801bdad…35bd19b` ($47.0K), `0x260e9836…e86b45c` ($35.0K).

### 2.4 The admin key: Argent v0.3.1, and why it is not third-party reachable

- Admin of the factory, **all 1,051 pairs** and the router: `0x284a1ad6382cffc520d8f711cf9519ccf43b3c105b89ef081cbe1a625322410`
  = **ArgentAccount v0.3.1** (class `0x29927c8af6bccf3f6fda035981e765a7bdbf18a2dc0d630494f8758aa908e2b`),
  owner `0x31f794696921bd6d9824f05e3d8c3ec0fa05fb1e359ccd2fd706580da6c2051` (EOA), guardian `0`.
- OZ v0.4.0b `Proxy.assert_only_admin` = `assert admin == caller`; `upgrade()`/`set_admin()` therefore require
  the admin contract to be the caller.
- **The "anyone can call `account.__execute__`" class is closed at the protocol level**: the Starknet sequencer's
  `call_contract` syscall rejects direct calls to the `__execute__` selector
  (`maybe_block_direct_execute_call` → panic `'Invalid argument'`). Proven live (read-only simulation):
  - control — admin as sender, `__execute__([factory.get_admin()])` → **SUCCESS**;
  - attack — third-party account calling `admin.__execute__([factory.upgrade(impl)])` → **REVERT**
    `argent/multicall-failed … 'Invalid argument'` (protocol block, not an account assert).
- `execute_from_outside` requires the owner's ECDSA signature over the Argent message hash ⇒ key required.
- ⇒ **upgrade-to-drain is privileged (P), not E-U.** (Same conclusion for the router/factory.)

### 2.5 Attempted drains (read-only simulations on the top pairs) — all revert

| Attempt | Call path | Result |
|---|---|---|
| Free swap (take `reserve0−1` of token0, pay nothing) | `pair.swap(r0−1, 0, attacker, 0, [])` | **REVERT** (input/k assert, impl `0x2b39bc3f…`) |
| Take `≥ reserve` out | `pair.swap(r0, 0, attacker, 0, [])` | **REVERT** (`insufficient liquidity`) |
| Skim with no excess | `pair.skim(attacker)` | **REVERT** (`checked_sub_lt`) |
| Burn with zero LP | `pair.burn(attacker)` | **REVERT** (`insufficient liquidity burned`) |
| `sync()` | `pair.sync()` | SUCCESS — harmless (reserves := balances) |
| Skim single-sided excess directly | `pair.skim(attacker)` on `0x239ea23c…` | **REVERT** (strict sub on the empty leg) |
| **Unlock-skim**: donate 1 wei of the empty-side token, then skim | `token.transfer(pair, 1)` + `pair.skim(attacker)` | **SUCCESS** — proven on 3 pairs: claims 1.478e29 STARKY / 1.1e21 TEST / 0.0448 LEA (all unpriced) and returns the 1 wei |

The only extraction primitive found anywhere is the unlock-skim of four single-sided dust donations; priced
value ≈ **$0.0000028** (1.111e12 wei zETH in `0x646c9602…` — needs 1 wei of that pair's JEDI-P counter-token,
an SPIST/GAET LP), everything else unpriced meme tokens (TEST, LEA, STARKY).

---

## 3. What an attacker can / cannot do (exact terms)

**Cannot (E-U):**
1. Drain any pair: no mint-against-donated-balances (0 pairs with `totalSupply==0` + balances), no zero-reserve
   free swap (0 pairs), no invariant bypass (checked math; verified bytecode), no reentrancy (per-pair lock),
   no self-held LP to burn (0 pairs).
2. Upgrade any proxy: admin-gated; the admin is an Argent account whose `__execute__` cannot be invoked by third
   parties (protocol block) and whose `execute_from_outside` needs the owner key.
3. Turn on protocol fees: `set_fee_to`/`set_fee_to_setter` are `fee_to_setter`-gated (= admin).
4. Pull users' LP: LP transfers/allowances are standard OZ ERC20; no permit, no signature surface.

**Can (but value ≈ $0 or requires own capital):**
1. Unlock-skim the four dust donations (1 wei + gas) — claims unpriced memes / $0.0000028 zETH.
2. Swap normally (0.3 % fee) — the pools are live; that is trading, not extraction.
3. Grief with `sync()` (sets reserves := balances; no value moved) — noted as a nuisance, not a drain.
4. Add/remove liquidity freely (the pools are not paused).

**Costs:** every candidate path is ≤ ~50–80 K L2 gas on Starknet; flash loans are unnecessary (no capital path
exists). The unlock-skim needs 1 wei of the empty-side token plus gas; net value ≈ −gas.

---

## 4. Verdict, residual & latent risk

- **E-U now: $0.00** (sub-cent dust only), confidence **high** — the deployed code is byte-verified, the whole
  pair set was enumerated at a single block, and every candidate class is empty or reverts live.
- **H-O ≈ $825,881**: LP holders can exit via `pair.burn` (transfer LP to the pair, call `burn`) or
  `router.remove_liquidity` (`0x041fd22b…`, verified source, live). No pause/lock; docs still guide users
  through it. Caveat: a pair whose *underlying token* contract is broken/paused would revert on exit
  (not enumerated token-by-token).
- **P ≈ $825,881**: one Argent wallet admin can `upgrade()` all 1,051 pair proxies + factory + router. That is
  the dominant tail risk (team-controlled; key-loss would turn it into S).
- **S ≈ $2.53**: router ETH `1,010,301,040,000,001 wei` (0.00101 ETH) has no sweep path (router is stateless);
  plus 1,000 wei of `MINIMUM_LIQUIDITY` per pair at unreachable address `0x1`.
- **Latent**: (a) if TEST/LEA/STARKY ever become tradable, the unlock-skim turns them into a (tiny) live path;
  (b) if the Argent owner key is compromised, P becomes E-U for the whole TVL; (c) `fee_to` could be switched
  on by the admin (protocol fee mints LP to `fee_to`).

---

## 5. Verification / evidence

| Evidence | File |
|---|---|
| Full pair census (reserves, totalSupply, balances, tokens) @ block 16229786 | `analysis/pair_state.json` |
| Anomaly scan (zero-supply / zero-reserve / stale / excess) | `analysis/pair_state.json.anomalies`, `analysis/storage_sample120.json` |
| Proxy state of all 1,051 pairs (impl + admin uniformity) | `analysis/pair_proxy_state.json`, `analysis/pair_class_hash.json` |
| Factory/pair/router proxy probes | `analysis/probe_proxy.json`, `analysis/impl_meta.json` |
| Deployed class ABIs + decoded programs | `analysis/abi_*.json`, `analysis/prog_*.json`, `analysis/class_*.json` |
| USD valuation + skim-excess valuation | `analysis/valuation.json`, `analysis/skim_excess.json`, `analysis/prices_llama.json` |
| Simulations (admin `__execute__` control/blocked; drains; unlock-skim) | `analysis/sim_admin_execute.py`, `analysis/sim_pair_calls.json`, `analysis/sim_drain_attempts.json`, `ci-out/ci_sims.json` |
| Class-hash proof (compile @11b4414 → match 6/6) | `ci/classhash.sh`, `ci/classhash_check.py`, `ci-out/classhash_results.txt` |
| CI run (fresh re-verification + storage sweep + sims + compile) | see `ci-log.txt` / CI run URL below |

**CI:** https://github.com/kingmariano/ca-zombie-ci/actions/runs/38156008686 — job: full re-read of factory + 1,051 pairs + raw `_locked`/`_factory`
sweep + live simulations + class-hash reconstruction (results in `ci-out/`, log in `ci-log.txt`).

---

## 6. Methodology & sources; caveats

- Read-only: `starknet_call`, `starknet_getStorageAt`, `starknet_getClass*`, `starknet_simulateTransactions`
  (public keyless RPCs: cartridge, drpc). No tx signed/sent.
- Source: `github.com/jediswaplabs/JediSwap` @ `11b4414` ("upgrade to proxy pattern", 2022-11-23);
  OpenZeppelin `cairo-contracts@b764660` (v0.4.0b); docs `docs.jediswap.xyz` (V1 factory/router addresses).
- Prices: DefiLlama coins API at 2026-10-11 ~16:20 UTC (ETH $2,505.14).
- Caveats: (1) LP-holder distribution was not enumerated (no free Starknet holder index) — H-O assumes standard
  LP redemption, which is proven at the contract level; (2) ~760 token legs are unpriced (meme/scam) — they add
  unknown but likely ~$0 value; (3) orphan PairProxy deployments (outside the factory registry) were not
  enumerated — they are self-administered and out of scope; (4) historical block numbers are cited per file.

## 7. Files index

```
jediswap-v1/
├── README.md                  # this file
├── summary.json               # machine-readable summary
├── analysis/                  # state dumps, scripts, evidence (sn.py, enumerate.py, phase3.py, valuation.py, sims)
├── ci/                        # CI heavy job: ci_verify.py, ci_sims.py, classhash.sh, classhash_check.py, run.sh
├── ci-out/                    # CI outputs (ci_verify.json, ci_sims.json, classhash_results.txt)
└── ci-log.txt / ci-artifacts/ # downloaded after the CI run
```
