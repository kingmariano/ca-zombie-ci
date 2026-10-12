# Child A — Adversarial audit of the live Swerve pool: can an unprivileged attacker extract value?

- **Target**: `0x329239599afB305DA0A2eC69c58F8a6697F9F88d` (Swerve "YPoolDelegator" proxy) → delegatecall
  impl `0xA5407eAE9Ba41422680e2e00537571bcC53efBfD`.
- **State block**: pinned `26,173,859`; final snapshot `26,174,168` (pool state did not change during the audit:
  every live simulation against `latest` matched the model built from block 26,173,859 to the wei).
- **Method**: full source audit → verified-source/ABI forensics (Blockscout) → bytecode opcode/selector scan →
  exact-arithmetic Python replica validated 96/96 against live `get_dy` → live end-to-end simulation of
  add/remove/swap paths on the real pool inside `eth_call` with state overrides (Tenderly gateway) → historical
  incident research. Read-only: no tx sent, no keys, no state changed.
- **Hypothesis tested**: E-U = $0 (extractable value beyond fair swap/LP outcomes).

## 0. TL;DR verdicts (every path found)

| # | Path | Verdict | Evidence (block 26,173,859 / live) |
|---|------|---------|-------------------------------------|
| 1 | `exchange`/`exchange_underlying` mispricing (rounding, Newton) | **DEAD** (dust ≤1 wei) | exact model 96/96; 2-swap roundtrips ≤0; 3-swap dust +1 wei once, non-repeatable; §3 |
| 2 | `add_liquidity` mint inflation / first-depositor | **DEAD** | live roundtrips match model to the wei; LP supply never 0; §4 |
| 3 | `remove_liquidity` / `remove_liquidity_imbalance` over-withdraw | **DEAD** | live + model; best closed cycle +$0.000123 vs ≥$0.03 gas; §4 |
| 4 | Donation/rounding **surplus** capture ($5.500886 live) | **DEAD** | only `withdraw_admin_fees` reads `balanceOf`; owner=0; §5 |
| 5 | LP-token minter powers (`transferFrom` bypass, mint/burn) | **DEAD (unreachable)** | pool never calls LP `transferFrom`/`set_minter`; §6 |
| 6 | Admin fns (fee/A/owner/kill/withdraw_admin_fees) | **DEAD** | owner=0x0, deadlines 0, all calls from attacker revert; §7 |
| 7 | Delegator upgrade / arbitrary calldata / selector collision | **DEAD** | hardcoded target, 0 SSTORE/0 CALL in proxy code; getters equivalent; §1/§7 |
| 8 | Reentrancy (incl. read-only) | **DEAD** | DAI/USDC/USDT/TUSD have no callbacks; all mutators `@nonreentrant`; §8 |
| 9 | Vyper/Curve historical vulns | **DEAD** | impl is Vyper 0.1.0b17 (not in 2023 CVE set); no ETH/ERC-777; §8 |
| 10 | Governance takeover (the actual 2023 Swerve "hack") | **DEAD since 2023-04-06** | ownership renounced to 0x0; §7 |

## 1. Identity & immutability (verified live and via verified sources)

- Proxy runtime has exactly **1 DELEGATECALL, 0 CALL, 0 SSTORE, 0 SELFDESTRUCT**; the PUSH20 constant
  `73a5407eae9ba41422680e2e00537571bc53efbfd` is present → fallback hardcodes the implementation; **there is no
  upgrade/admin function in the proxy** (verified source = Blockscout `YPoolDelegator`, solc 0.6.10, full match).
- Impl = Vyper **v0.1.0-beta.17**, full verified source matches the parent's saved `impl_0xA5407eAE.sol`
  (USE_LENDING=[F,F,F,F], TETHERED=[F,F,T,F], PRECISION_MUL=[1,1e12,1e12,1]); ABI = exactly **31 functions**,
  all 31 selectors present in the bytecode dispatcher; no fallback/extra entry points.
- The impl contract is *itself* Curve's live **sUSD pool** (its own slots: owner 0xecb4…, token 0xc25a3a3b
  `crvPlain3andSUSD`, A=256). Swerve's proxy reuses its code with Swerve's own storage. The sUSD pool's own
  admin/governance cannot touch Swerve's storage (delegatecall reads only the caller's storage).
- Live layout check: pool slots 3=A=100, 4=fee=3e6, 5=admin_fee=0, 6=owner=0, 7=token=swUSD LP,
  8=9=0 (deadlines), 10=future_A=100, 11=future_fee=3e6, 12=future_admin_fee=0, 13=future_owner=0,
  14=kill_deadline=0x5fa0fb44 (2020, expired), 15=is_killed=0.
- Forensics note (transparency): the impl bytecode contains six 4-byte constants
  (`05eb8fa6 1db7662b 1e8c3fd3 1f30ab74 2ce785a3 42d3b3c3`) not present in the verified ABI. They also occur in
  Curve's yPool implementation bytecode (different source/settings) and **all six revert when called live**
  (`cast call $IMPL 0x05eb8fa6 …` → execution reverted, same as `0xdeadbeef`). They are non-dispatched
  compiler/call-tag artifacts (e.g. method-id tags emitted into function bodies), not callable entry points.

## 2. Function inventory — every value-moving path and its gate

Impl (31): `get_virtual_price, calc_token_amount, get_dy, get_dy_underlying` = views; `add_liquidity,
exchange, exchange_underlying, remove_liquidity, remove_liquidity_imbalance` = fair ops (proven below);
`commit/apply/revert_new_parameters, commit/apply/revert_transfer_ownership, withdraw_admin_fees, kill_me,
unkill_me` = `assert msg.sender == self.owner`; owner=0x0 → **dead**. Vyper reverts with empty data (proxy
swallows revert data). Live attacker probes (from 0x1111…):
```
withdraw_admin_fees() / kill_me() / unkill_me() / commit_new_parameters() /
commit_transfer_ownership() / apply_transfer_ownership() / apply_new_parameters()  → all revert
owner() → 0x0000000000000000000000000000000000000000
```
Only outgoing transfers in the whole impl: user ops (§3/§4), plus `withdraw_admin_fees` (owner-gated). No other
function can move a coin, and no function writes `coins`/`underlying_coins`/`token` after `__init__`.

Delegator (16 getters, 0 state-changing): `A/fee/admin_fee/owner/*_deadline/future_*` read the same slots as the
Vyper impl; `coins(int128)/balances(int128)/underlying_coins(int128)` shadow the impl's equivalent getters and
read the same storage (verified values identical). `_coins/_underlying_coins/_balances(uint256)` are extra
Solidity getters. No selector collision changes semantics; no state writer exists.

## 3. Swap math: rounding directions and Newton behaviour (the headline hypothesis)

Exact integer replica (checked uint256 arithmetic, truncating DIV, 255-iter caps) of the Vyper source:
`get_dy` grid = **96/96 exact matches** to live, `get_virtual_price` exact, live end-to-end swaps 7/7 exact
(including `exchange_underlying == exchange` for all 12 pairs — coins==underlying for all 4).

- `_exchange` computes `dy = xp[j] - y` with **no `-1`** (older Curve rounding), and `get_y`/`get_D` stop at
  the ±1 tolerance. Bounded consequence: the user can receive at most **1 xp unit** more than exact math per
  swap = **1 wei** for DAI/TUSD outputs, **0 raw units** for USDC/USDT (1e12 scaling).
- Convergence stress: for dx from 1 wei to 1e24 on all 12 pairs, **0 non-convergence, 0 reverts,
  max |y_255 − y_5000| = 0**. No exploitable Newton failure.
- Live probe of the only positive case found (state-dependent 0-dx continuation):
```
# live, in one tx via probe contract (Tenderly eth_call + state override), block ~26,174,0xx:
triple(0,1,3, dx=1):  live d1=0 (USDC out), d2=1 wei TUSD, final_i=2 wei DAI  -> profit +1 wei DAI
   raw: 0->1->3->0 dx=1: live d1=0 d2=1 final_i=2 profit=1   (model d1=0 d2=1 d3=2)
```
  Repeat analysis (exact model, 10 consecutive cycles): results alternate `(0,1,2),(0,0,0),(0,0,0),(0,0,0),(0,1,2)…`
  → over 10 cycles: 10 wei in, 8 wei out = **net −2 wei**. The +1 wei single cycle is a state-parity quirk, not
  a repeatable leak. `get_dy(i,j,0)=0` for all 12 pairs at the audited state; a 200-round zero-dx walk found 0
  positive payouts.
- Gas: `exchange` = **153,891** gas (`cast`/`eth_estimateGas`, block 26,174,168); ~0.062 gwei gas price →
  a 3-swap dust tx ≈ **$0.03–0.09** for a best-case +1 wei ($1e-18). **Dead by ~15 orders of magnitude.**

## 4. LP math: live-validated fairness

A probe contract (solc 0.6.5, deployed via state override) executed `add_liquidity` + `remove_liquidity` on the
real pool in one `eth_call`. Live results matched the exact model **to the wei for all 6 vectors** (mint + all
four net token deltas), e.g.:
```
amt=[1e18,0,0,0]  live mint=934614809677927907  net=[-753953403345060068, 243138, 266096, 244728031863012391]
                  model mint=934614809677927907 net=[-753953403345060068, 243138, 266096, 244728031863012391]
amt=[1000e18,1000e6,1000e6,1000e18] → match (mint=3738460223176135557710), etc. 6/6 MATCH
```
The positive "par-value" nets for imbalanced deposits/withdrawals are the ordinary AMM imbalance premium
(pool is USDT-overweighted: 1 DAI buys 1.000460 USDT via `get_dy`, fee included). They are **not** free money:
- A **closed intra-pool cycle** (deposit → withdraw → swap the surplus coin back into the deficit coins through
  the same pool) was searched over 19 vectors: best residual = **+$0.000123** (vector 1000×4) before gas;
  ≥$0.04 gas (307k+276k+~2×154k ≈ 0.9M gas) → net ≈ **−$0.04**; single-coin cycles lose 0.037% (−$0.38/1000).
- Only a cross-venue sale at external par would realize the premium — that is precisely the pool's fair quoted
  swap price (explicitly excluded by the mission's benchmark), not a contract defect.

## 5. The $5.500886 surplus is unreachable

Live `balanceOf(pool)` − `balances[i]` (block 26,174,168): DAI +0.318878, USDC +1.474250, USDT +1.920717,
TUSD +1.787042 → **$5.500886** total (donations/rounding). The *only* code in the entire impl that reads
`balanceOf` is `withdraw_admin_fees()` (owner-gated). Live test: injecting a +1000 DAI donation via state
override leaves `get_dy(0,1,1e18)` **bit-identical** (`0xf409c`) — virtual balances govern all user math.
`withdraw_admin_fees()` from any attacker address reverts (owner=0). Surplus is effectively burned.

## 6. LP token (`swUSD` 0x77c6…, Vyper 0.2.4) — dangerous capability without a reachable path

Live evidence:
```
LP.set_minter(0x1111…) from POOL   -> SUCCESS      # pool IS the minter
LP.set_minter(0x1111…) from ATT    -> revert
LP.mint(ATT,1) from POOL -> SUCCESS; from ATT -> revert
LP.transferFrom(gauge,ATT,1) from POOL -> SUCCESS  # minter bypass confirmed (no allowance needed)
LP.transferFrom(gauge,ATT,1) from ATT  -> revert
LP.burnFrom(ATT,1) from POOL -> revert (ATT has 0 LP → underflow; minter assert passed)
```
`transferFrom`/`burnFrom` bypasses exist only when `msg.sender == minter == pool`. The impl's LP interactions
are exclusively `totalSupply()`, `mint(msg.sender, mint_amount)` (add) and `burnFrom(msg.sender, …)` (removes) —
the verified source, ABI and selector scan confirm **no `transfer`/`transferFrom`/`set_minter` call on the LP**
(and the lending-only `approve/mint/redeem` branches are dead under USE_LENDING=[F×4]). Therefore an attacker
cannot make the pool move or burn LP it does not own; minter can never change (only the pool could call
`set_minter`, and it never does). `remove_liquidity(0, zeros)` succeeds (no-op, 0 transferred).
Gauge holds 274,199.69 of 284,914.26 LP; its `withdraw` is bounded by caller balance (no unprivileged drain).

## 7. Admin/governance surface — the one real historical attack, now dead

- The March 2023 "Swerve hack" headline ($1.3M) was a **failed governance attack**: an attacker assembled
  ~348k+102k veSWRV votes against the ~495k/571k needed to pass an Aragon proposal handing pool control to
  them (Halborn / The Block / smartcontractshacking). It never executed.
- Ownership of the pool was afterwards **renounced to 0x0 (2023-04-06)** — verified live — after which every
  privileged function reverts for every caller, including via the old Curve-style admin proxy:
```
proxy(0x2638d268).withdraw_admin_fees(pool)        from ATT -> revert
proxy.apply_transfer_ownership(pool) / apply_new_parameters(pool) from ATT -> revert
proxy.commit_transfer_ownership(pool,ATT) / kill_me(pool) / unkill_me(pool) from ATT -> "Access denied"
```
  (Note: the proxy's own ungated wrappers die on the pool's owner=0 gate; the proxy's own 30,408 USDT is a
  separate, admin-gated contract, not attacker-reachable and not pool value.)
- `kill_deadline` expired in Nov 2020 and `is_killed=0`; `kill_me` is owner-gated anyway. No DoS-with-profit path.

## 8. Historical vulnerability classes checked

- **Vyper reentrancy-lock bug (CVE-2023-39363, July 2023)**: affects 0.2.15/0.2.16/0.3.0 only; impl is
  **0.1.0b17** → not affected (and there is no untrusted callback here regardless).
- **Read-only reentrancy / `get_virtual_price` manipulation**: requires a callback during `remove_liquidity`
  (native ETH raw_call or ERC-777). All four coins are plain ERC-20s (no hooks); pool ETH balance = 0 → no
  callback surface, nobody can enter mid-withdrawal. All five mutators use `@nonreentrant('lock')`.
- **Curve v1 "no `-1`" rounding / Newton non-convergence**: bounded to ≤1 wei (§3).
- **Harvest/Value-DeFi-style oracle exploits** targeted external protocols using the pool as a swap venue; the
  pool's own quotes were fair. Nothing here lets the pool itself be drained.
- **Donation/`withdraw_admin_fees` sweeps**: dead (§5). **First-depositor dust**: LP supply is 2.849e23 and only
  LP holders can burn, so supply can never be pushed to 0 with balances left (verified: burn paths pass
  `msg.sender`, and a full proportional exit zeroes balances exactly). **Fake-token/approvals**: coin set is
  fixed; reachable code contains no `approve` (lending-only) → the pool has no outstanding allowances.
  **Selector collisions**: proxy getters are the same functions with the same storage; all `uint256`-index
  variants revert (not in ABI) — no alternate semantics.

## 9. Limitations / residual uncertainty

- The six non-dispatched 4-byte constants (§1) remain unidentified; all callable tests and the verified ABI
  indicate no hidden entry point. Confidence deduction ≤1%.
- Pinned reads at 26,173,859 were taken while that block was near the head (publicnode now rejects historical
  reads); later live simulations used `latest` (26,173,9xx–26,174,168) and matched the pinned state exactly.
- No Foundry mainnet fork was run (per constraints); instead a 6/6-exact live `eth_call` replay of the
  LP roundtrips and 7/7 swaps was used, which is equivalent for value-flow purposes.
- MEV/sandwiching and cross-venue stablecoin arbitrage at the pool's own quoted prices are excluded by the
  mission benchmark (fair swap outcomes).

## 10. Bottom line

No unprivileged value-extraction path was found beyond rounding dust: worst realizable leak is a
state-dependent +1 wei DAI ($1e-18) cycle that is net-negative when repeated and costs ~$0.03–0.09 in gas;
the $5.500886 donation surplus is frozen behind the renounced owner; LP ops were live-validated fair to the
wei; the proxy is immutable (no upgrade path, hardcoded implementation); the LP minter capability is
unreachable; the only historical value attack (2023 governance) is closed by owner=0x0.

**E-U on pool = $0 (confidence: high)**
