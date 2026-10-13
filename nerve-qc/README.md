# QC-5 — Nerve (BSC) adversarial re-audit

**Verdict: closure stands — $0 fresh-attacker E-U (high).**
The prior L2 deep-dive conclusion (E-U $0 / high; funded metapools paused; ~$10.41 drainable across 8 unpaused metapools) is **independently reproduced and survives every counter-test we could construct**. The prior's drain bound was, if anything, conservative in the attacker's favour: most of that $10.41 sits behind dead 2021 Ruler "RC" certificates that cannot be acquired, so the realistically extractable amount is ≈ $0.03–2.5, and no route to the $705.7k admin piles or the paused pools was found.

Fresh block: **127,426,224 – 127,437,000** (2026-10-13). All tests fork-only, read-only; nothing signed or broadcast.

---

## 1. What was re-verified (all 14 QC tests pass — `poc/test/NerveQC.t.sol`)

| # | Test | Result |
|---|------|--------|
| qc1 | Fresh state of all 17 pool/metapool contracts (paused, owner, internal/admin) | ✅ funded metas paused=1; owners = 2-of-3 Safe |
| qc2 | All value-moving entry points on funded metas revert `Pausable: paused` (swap, swapUnderlying, addLiquidity, removeLiquidityOneToken, removeLiquidityImbalance) | ✅ |
| qc3 | Proportional `removeLiquidity` still allowed while paused — **fair** (internal share only, admin untouched), executed for real | ✅ |
| qc4 | `withdrawAdminFees`, pause/unpause, fee setters, `transferOwnership`, `initializeMetaSwap` all revert for a non-owner on every clone | ✅ |
| qc5 | Extraction bound on the 8 unpaused clones: Σ LP3-out for all internal0 = **10.381892022701008814 LP3** — byte-for-byte the prior figure | ✅ |
| qc6 | Upper-bound accounting of the strongest unpaused adversary (manipulated base price) | ✅ |
| qc6b | **Real manipulation**: burn 7,030 LP3 (~$7,050) on the 3pool via `removeLiquidityImbalance` → vprice moves **136 wei** (~1.4e-14 relative) | ✅ manipulation economically impossible |
| qc7 | **Conditional**: fork-only owner unpause of USTMETA+FUSDTMETA → classic round trips **lose** at today's reserves (66.99→63.17 LP3; 27.01→26.91 LP3); outputs always < internal reserves | ✅ |
| qc8 | All three impl contracts (0xf642f2a6, 0xfa97adb5, 0xfcc3976e) hold **zero** tokens | ✅ |
| qc9 | MasterMind farm: 11 pools, standard MasterChef; outsider `withdraw(0,0)`/`emergencyWithdraw(0)` move nothing; add/set owner-only | ✅ |
| qc10 | 3 **previously-unknown clones** (found in QC) are empty, owned by Safe, not re-initializable | ✅ |
| qc11 | Base 3pool remains fair (100k USDT round trip loses) | ✅ |
| qc12 | Swap outputs always stay strictly below internal reserves — admin balances not swappable | ✅ |
| qc13 | **Strongest adversarial test**: `vm.store` the metapool's cached `baseVirtualPrice` (slot 219, verified) to a 2× inflated value. The *view* then says the pool would pay 0.755 LP3 for all internal rUSD (> internal1 0.3977), but the **executed swap reverts on SafeMath underflow** — the 135.3 LP3 admin balance on E7 is structurally unreachable | ✅ admin safe even under worst-case cache |

## 2. Complete pool re-enumeration (mandate item b)

Every address that **ever touched** any Nerve base LP was enumerated by adaptive `eth_getLogs` over the full chain history (Ankr 10k-result / range caps handled by bisection):

* LP3: 180,332 transfers → 7,593 unique addresses
* BTC-pool LP: 16,572 transfers → 1,235
* ETH-pool LP: 18,307 transfers → 1,319
* **8,574 unique addresses** checked with `eth_getCode`; 600 contracts; **every contract referencing any of the three Nerve MetaSwap impls** was inspected.

Result: the prior's 11 clones **plus 3 previously-unknown clones**:
* `0x877A8437e76443cFCaCD05D21C3793070637d82f` (impl f642f2a6)
* `0xCB922e4A5370020ACf2D0E29754e0a995Dec5B27` (impl f642f2a6)
* `0xf873Ec132F38eFb86bd071234b4316878b48Fa97` (impl f642f2a6)

All three are **empty** (0 internal/admin balances, 0 LP supply), owner = Safe, unpaused, not re-initializable → **no value missed**. Any value-bearing metapool must hold a base LP, so this sweep is complete for the value-bearing surface.

Also discovered: the farm holds 11 LPs including the UST-meta and fUSDT-meta LP tokens; the remaining farm LPs are PCS pairs and xNRV (a 1:1 NRV wrapper, `enter/leave` only, no owner function, no outsider drain found).

## 3. Live activity observation (new — not E-U)

An unknown third-party address `0xD42fCe65B9cE5deD9d3a4EcaA20955BAB52DaA19` ran ~30 direct swaps against the unpaused EXTRA7 pool in blocks 123,863,402–123,864,984 (Aug–Sep 2026), alternating rUSD↔LP3 with matched sizes:

* LP3 legs net **exactly 0** (same amounts in/out, 11 pairs);
* rUSD legs net ≈ +0.0015 rUSD per cycle (dust; ≈ $0.00008 at the measured rUSD market price);
* session P&L ≈ flat/negative after gas.

This shows the pool is still "live" but extracts nothing material. rUSD market price measured from the PCS rUSD/BUSD pair ≈ **$0.0544**, which is within ~7% of the pool's own implied pricing (≈$0.058) — i.e., no standing mispricing for a fresh attacker either.

## 4. Value accounting (fresh, block 127,426,224)

| Bucket | Value | Class |
|---|---|---|
| Admin fees, all pools (owner-only) | **$705,709** | P (2-of-3 Safe) |
| — 3pool admin | $240,218 | |
| — fUSDT-meta admin (fUSDT $159,739 + LP3 $191,414) | $351,154 | |
| — UST-meta admin | $59,884 | |
| — BTC pool admin | $31,812 | |
| — ETH pool admin | $22,497 | |
| — EXTRA7 admin (missed by prior, +$144) | $144 | |
| Internal reserves, holders | $607,061 | H-O |
| Farm LP3 (user-staked) | $303,460 | H-O |
| **Fresh-attacker E-U ceiling** | **≤ $10.41 (LP3 side) + $2.44 (E7 rUSD) + $0.04 (E6 fUSDT)** | — |
| Realistic fresh-attacker extraction | **≈ $0** (E0–E5 token0s are dead Ruler certs — unacquirable) | **E-U** |

LP3 NAV = $1.00249 (3pool internal value / supply). Prices: BUSD 0.99996, USDT 0.99906, USDC 0.99963, BTCB $82,828.53, ETH $2,500.12, UST $0.00916, fUSDT $1.00 (assumption; BSC market dust), rUSD $0.05445 (PCS).

**Corrections to prior:** P $705,696 → **$705,709** (adds EXTRA7's owner-only admin); the prior's "8 unpaused metapools" mixes 3 impls (6× f642f2a6, E6/E7 on fa97adb5); 3 additional empty clones existed but were value-free. The fUSDT component of P ($159,739) is only realizable if fUSDT redeems at $1 — if fUSDT ≈ $0, P falls to ≈ **$546k** (note for triage, not E-U).

## 5. Conditional paths (key-gated / holder-only — never E-U)

| # | Path | Precondition | Value |
|---|------|--------------|-------|
| C1 | Unpause funded metapools → reactivates the Nov-2021 MetaSwap pricing bug | **2-of-3 Safe signatures** (0xD94A…, v1.2.0) | Ceiling = internal reserves $455 (UST-meta $269 + fUSDT-meta $185); plain round trips currently **lose**, so ≈ $0 today; any future reserve inflow restores exploitability |
| C2 | `withdrawAdminFees()` | 2-of-3 Safe signatures | **$705,709** (fUSDT caveat above) |
| C3 | Proportional `removeLiquidity` while paused (allowed, fair) | hold metapool LP | H-O internal reserves ($455) + base internals ($606,603) + farm LP3 ($303,460) |
| C4 | Buy metapool LP at market discount, redeem | market liquidity | USTMETA-LP PCS pair quotes 81% below NAV but has **dust liquidity** (1.21 LP) → not actionable |
| C5 | Safe signer key compromise | off-chain keys | = C1+C2; no on-chain evidence |

## 6. Residual uncertainty

1. A clone that **never touched a base LP** could exist but would be empty by construction (no value); the sweep covers every value-bearing pool.
2. fUSDT's true redemption value affects P, not E-U.
3. 2-of-3 Safe key compromise is not verifiable from on-chain data alone — hence conditional.

## 7. Reproduce

```
cd poc && BSC_RPC_URL=<bsc-archive-rpc> forge test -vv     # 14/14 pass
python3 analysis/fingerprint.py                            # fresh state of all pools
python3 analysis/valuation.py                              # consolidated USD numbers
bash /home/heisenberg/CA/ci/ci-run.sh nerve-qc             # CI: branch nerve-qc + artifacts
```

Key evidence files: `analysis/fingerprint.json`, `analysis/clones_full2.json` (complete clone sweep), `analysis/lp_transfer_addrs.json` (full holder universe), `analysis/valuation.json`, `analysis/bot_activity.json`, `ci-artifacts/` (CI logs).
