# Cozy Finance v2 "Set" (CSET) residual — Optimism — live extractability analysis

**Date:** 2026-10-10 · **Chain:** Optimism (chain id 10) · **Author:** H2-03 child-subagent (zombie-hunt II)
**Status:** read-only research; no transactions signed or sent; all simulations via `eth_call`; public/keyless RPCs only.

---

## 1. TL;DR

| Target | Live unprivileged extractable (E-U) | Why |
|---|---|---|
| Cozy Set `0x17705474…` (CSET, 4,168.126922 USDC.e) | **$0.00** | Residual is already allocated to (a) CPT claim holders (live, holder-only), (b) CSET share holders (pause-gated) and (c) tiny set-owner fees (privileged). No mint of new CPT is possible: Set is PAUSED and `remainingProtection = 0` on every market. All extraction calls revert or require ownership/allowance. |
| Cozy Set `0x426713c9…` (CSET, 1,150.675622 USDC.e) | **$0.00** | Same: PAUSED; `purchase`/`deposit` revert `InvalidState()`; only CPT holders (13.94 USDC.e live) and CSET holders (1,136.73 pause-gated) can recover. |
| Other identified CSET contracts (≈$14.89 in 6 **ACTIVE** small Sets + ≈$230 in other-generation Sets + $13,446.94 Gen-1 vault) | **$0.00 material** | The ACTIVE small Sets still match the vulnerable UMA design (`InvalidPurchase()` — i.e. state gate passed — when probed without payment), but any false-YES run risks a 500–1,000 USDC UMA bond and is negative-EV post-incident; their combined balance is ~$14.89. Other generations have different ABIs/designs, no mapped permissionless path. |

**Headline: E-U = $0.00** (confidence **high** for the incident residual on Sets `0x17705474` and `0x426713c9`).
**H-O (holder-only, live now):** 2,222.419203 USDC.e = CPT claims on triggered markets, claimable immediately while paused (verified by `eth_call` from real holders).
**H-O (holder-only, pause-gated):** 3,096.270407 USDC.e = supplier fee pools + CSET share collateral + pending redemption.
**P (privileged/Cozy):** 0.112934 USDC.e (set-owner fees; `claimSetFees` → `Unauthorized()` for others). Only the manager owner can `unpause`.
**S (stuck):** $0.00.
**Total identified residual in the two incident Sets: 5,318.802544 USDC.e ≈ $5,317.33** (DefiLlama USDC.e $0.999723, 2026-10-10).

Cross-check: DefiLlama "Cozy Finance" OP Mainnet TVL = **$5,367**, matching the four 0x17aFF89b-generation USDC Sets today (4,168.126922 + 1,150.675622 + 50.000000 + 0.502501 = 5,369.31).

---

## 2. The incident (context, re-verified on-chain)

**Attack:** attacker EOA `0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB` bought protection in Cozy v2 Sets, pushed fraudulent `YES` answers into UMA Optimistic Oracle V2 (`0x255483434aba5a75dc60c1391bB162BCd9DE2882`), let the 5-day (432,000 s) liveness elapse undisputed, settled the triggers to `TRIGGERED`, and redeemed the freshly minted CPT (protection tokens) against the Sets' collateral. The trigger's `priceProposed` callback only checks `proposedPrice == 1e18` — no verification the event occurred; CPT is not snapshotted at proposal time.

**Exact on-chain records (all re-verified):**

| Step | Tx / block | Detail |
|---|---|---|
| Deploy helpers | `0xda727747…` and `0x845043b2…`, block 156,363,353 | attacker-created contract 1 `0x9E47C805…`, contract 2 `0xeF9886f4…` |
| TX1 freeze | `0x53b454a3f552c5498994f74ae8737faa60123cac274bdd3b0383ccb226b3f2cb`, block **156,364,035** | `purchase(5, 96,596.967870)` → 958,573.194147 CPT, cost 1,280.580768; `purchase(0, 65,715.735793)` → 654,809.418152 CPT, cost 1,351.183395; then `OptimisticOracleV2.proposePrice(YES=1e18)` on both triggers (1,000 USDC bond each) |
| TX2 drain | `0x8761164b8947a0690b57896a8e7370dd69fe8e9137ce61e0b21ff08581a2ce60`, block **156,580,507** | settle (2×1,025 USDC returned) + claim loops; Set `0x17705474` → helper1 **160,776.340904 USDC** |
| TX2b drain | `0xf7a270480f9d457bddc2c8cb4f16669ef01f185cf6bda338351a71e704c79b4b`, block **156,580,507** | settle + claims; Set `0x426713c9` → helper2 **9,409.663229 USDC** |
| Sweep out | same blocks | helper1 → bridge `0xeb2d41bc…` 163,326.343700; helper2 → bridge 10,984.663268 |

**Total Set losses: 170,186.004133 USDC.e** — exactly the reported ~$170,186.
Function selectors (keccak-verified): `purchase(uint16,uint256,address)` = 0xf09b77db, `claim(uint16,uint256,address,address)` = 0x06af14f1; the receipt-decoded `Purchase`/`Claim` events match the cozy-interfaces-v2 definitions.

**Balance history (archive reads via mainnet.optimism.io, hex blocks):**

| Block | Set `0x17705474` | Set `0x426713c9` |
|---|---|---|
| 156,364,034 (pre-TX1) | 162,312.703663 | 10,013.860418 |
| 156,364,035 (post-TX1) | 164,944.467826 | 10,560.338851 |
| 156,580,506 (pre-TX2) | 164,944.467826 | 10,560.338851 |
| 156,580,507 (post-TX2) | **4,168.126922** | **1,150.675622** |
| 158,019,801 (today-1) | 4,168.126922 | 1,150.675622 |

The residual has not moved since the drain. **Blockaid/BeInCrypto's "$4,168 in the unverified Cozy Set (CSET) contract" is precisely Set `0x17705474`'s balance — and it ignored Set `0x426713c9`'s 1,150.68.**

---

## 3. Contracts (exact)

- **Set 1 ("Main"/victim, holds 4,168.126922):** `0x17705474203F7ff7ba8a940c433AB43D1F58E249`
  - CSET token = the Set contract itself (name "Cozy Set", symbol "CSET", decimals 6; supply 155,914.837419)
  - EIP-1167 clone of impl `0x17aFF89bf88B4eB56a1bCB256ff49FA1910E8410` (unverified)
  - facet/router targets seen in traces: `0x8da6E9E78EFE68e83643c03FDaec1E63c26EAA8C`, `0x0bfdC9cA8E8b30aEcaFa7BdFA1429637170dEA48`, `0xCfF72F2A3238c12336e91add2F758C5d0953e9Ad`, `0x996e0a0A3801A3F642be2c5A4745BF9d526fA668`
  - asset: USDC.e `0x7F5c764cBc14f9669B88837ca1490cCa17c31607`
  - manager `0x7eDfAd1b566657a236C8422bA6997536BC647a29`, factory `0xDebE19B57e8B7Eb6eA6EBEa67B12153E011E6447`, ptokenFactory `0x20433C2FB6CD1C9472147452183B32c3c746989E`, backstop `0xCB4c5190017CB106803d6d5225E21A06231B11ff`
  - owner = pauser `0xB471F352A61D0C7F7805b93d9d574C69Fd9644F5`
- **Set 3 ("Rabbithole", holds 1,150.675622):** `0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8` (same impl/manager; owner/pauser `0xbb83D92c8D2b1523b6Be79C822c20865D70321cC`)
- **Set 2:** `0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9` — 0 USDC.e, supply 0 (drained; CPT `0x1F626C96…` and `0xcFA3560c…`)
- **Set 4:** `0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276` — 0 USDC.e, supply 0 (drained; CPT `0x658CeBAD…`)
- **CPT (Cozy PToken) contracts holding the unclaimed claims:**
  - market 5 (Aave v2) `0xC1304c0Db0bb2001e11E5c45ecb4F3D0e7158655` — supply 10,436.945579; top holder `0x18AA2A4aB4af7058f536173df904f649455306ac` (10,075.128256)
  - market 0 (Curve) `0xFa1c5663aCeC49aD17422d2E846eA113534a8abf` — supply 11,736.214561; top holder `0x349A01774f22f51ffD46270b48F1FDC85ac9131f` (10,000.000000)
  - Set3 market 0 (Rabbithole) `0x2086DcfB21761183ed0b20812F61F0984096AF99` — supply 112.997194; top holder `0xcD01A3acED67e266be21117376C7025B384Cd4d7` (111.844016)
- **UMA triggers:** `0xeB6613FAC35fED17c276e3FE45D67Da67685f1eF` ("Did Aave v2 get hacked?", TRIGGERED), `0xaCD105FEEa362D5c27CAAbA0B45F53D91B92dE27` ("Did Curve get hacked?", TRIGGERED), `0x41701936CD5F4B8F5284dB0C68f0c2B9dF3B1618` ("Did Rabbithole Quests get hacked?", TRIGGERED). Same UMATrigger code (verified source), `bondAmount` 500/500/1,000, `proposalDisputeWindow` 432,000 s, oracle = OptimisticOracleV2 `0x25548343…`.

---

## 4. Residual decomposition (why nothing is E-U)

**Set `0x17705474` — 4,168.126922 USDC.e at block 158,019,927:**
| Component | Amount (USDC.e) | Owner | Status |
|---|---|---|---|
| Triggered-market CPT claims (mkt0 1,166.682325 + mkt5 1,041.793765) | 2,208.476090 | CPT holders (EOAs; helper dust 1.823296 CPT) | **LIVE** — `claim()` works while paused; verified 998.178784 (H5) / 994.087419 (H0) |
| Supplier fee pools (`totalPurchasesFees` 1,683.196833 + `totalSalesFees` 154.597129) | 1,837.793962 | CSET holders (dripped via `dripSupplierFees()`, callable by anyone but pays suppliers) | pause-gated (redeem reverts) |
| CSET share collateral (`totalCollateralAvailable`) | 120.901199 | CSET holders | pause-gated |
| Pending redemption (`assetsPendingRedemption`) | 0.842737 | one redeemer | pause-gated |
| Set-owner fees (`accruedSetOwnerFees`) | 0.112934 | Cozy set owner | P — `claimSetFees` → `Unauthorized()` |
| **Sum** | **4,168.126922** | | |

**Set `0x426713c9` — 1,150.675622:** CPT claims 13.943113 (LIVE; H3 claim sim = 13.800818) + CSET share collateral 1,136.732509 (pause-gated).

**The "claim path" is exactly:** `claim(uint16 marketId, uint256 ptokens, address receiver, address owner)` (selector 0x06af14f1). It burns CPT and pays pro-rata protection from Set collateral; `previewClaim` quotes it. Third-party claims require the CPT owner's approval — a fresh caller gets `panic 0x11` (allowance underflow). No approval exists from any holder toward the attacker or any helper (checked 0x9E47C805, 0xeF9886f4, attacker EOA).

---

## 5. Can the attack be repeated on the residual? (answers to the task's sub-questions)

**(a) Does the residual require CPT supply to burn against?** Yes. Every USDC.e payout from the Set goes through `claim()` (burns CPT) or holder redemption/fee paths. There is no privileged or permissionless "sweep". The two triggered markets still have 22,173.160140 CPT outstanding (worth exactly the 2,208.476090 activeProtection), but those CPT are held by EOAs (99%+ by two addresses). Even the attacker's own helpers left only 1.823296 CPT dust (~0.18 USDC) because payout rounds down.

**(b) Can a fresh attacker run the same false-oracle attack again?**
- The UMA assertion path itself is still open: `proposePrice` is permissionless, the 0xb634BF77 request is `settled=false` (live), bond ≈ 500–1,000 USDC, liveness 432,000 s. A YES proposal freezes the market (same callback flaw).
- But the payout requires NEW CPT: `purchase` and `deposit` both revert `InvalidState()` (0xbaf3f0f7) on these Sets — they were **PAUSED at block 156,595,428** (tx `0xc74f6feb…`, from Cozy-side `0xa5C07599…` calling `manager.pause()`, ~8.3 h after the drain), and remain `setState() == 1 (PAUSED)`.
- Even if unpaused, Set1 cannot mint CPT: `remainingProtection() = 0` on **all** markets (leverage 2.5987 × 120.90 collateral − 132,496 outstanding coverage ⇒ negative). Only Set3 has spare capacity (1,122.789396) but its market 0 is TRIGGERED; purchase on a triggered market is (almost certainly) blocked.
- Therefore a fresh attack on these Sets today cannot reach the residual. It would only convert *other people's* CPT into claims.
- Residual UMA-level issue: a speculator could still propose YES on the open, unsettled requests (e.g., "Was Uniswap v3 hacked?" trigger `0xb634BF77`, request timestamp 1,683,500,396, settled=false) and collect the bond refund + ~25 USDC reward if undisputed. That is a **different** target (UMA/OOv2), it is destructive, and post-incident Cozy watches these exact queries — a dispute costs the proposer the 500–1,000 USDC bond. Negative EV; not counted.

**(c) Days and capital:** 5 days (432,000 s) and ~500–1,000 USDC refundable bond (+final fee) per assertion. Bond is returned at settlement (observed payouts 1,025 per 1,000 posted in TX2) plus 25 USDC reward, unless disputed.

**(d) Is payout bounded by Set collateral?** Yes. The attacker's coverage size does not set the payout — observed: 162,312.703663 face coverage yielded 160,776.340904 (decay-adjusted; the Set drained to exactly its residual), and any oversubscribed claims pay pro-rata from available collateral. The residual (4,168.13 / 1,150.68) is the ceiling on anything claimable from these Sets, and it is already owned by the parties above.

---

## 6. Live-state evidence (block 158,019,927 state; 158,020,077 simulations)

| Call (read-only) | Result |
|---|---|
| `Set1.claim(5, 10000e6, H5, H5)` from H5 | **998178784** (998.178784 USDC) — claims work while paused |
| `Set1.claim(0, 10000e6, H0, H0)` from H0 | **994087419** (994.087419 USDC) |
| `Set3.claim(0, 111844016, H3, H3)` from H3 | **13800818** (13.800818 USDC) |
| `Set1.claim(5, 10000e6, PROBE, H5)` from PROBE | revert `panic 0x11` (allowance) — no third-party theft |
| `Set1.purchase(1, 1e6, PROBE)` / `Set3.purchase(0, 1e6, PROBE)` | revert `InvalidState()` 0xbaf3f0f7 |
| `Set3.deposit(1e6, PROBE)` | revert `InvalidState()` 0xbaf3f0f7 |
| `Set1.redeem(1e6, H, H)` from CSET holder | revert `0x59818bce` (pause-gated redemption) |
| `Set1.claimSetFees(PROBE, PROBE)` / `claimCozyFees(PROBE)` | revert `Unauthorized()` 0x82b42900 |
| `Set1.dripSupplierFees()` from PROBE | succeeds (pays suppliers, not caller) |
| `previewClaim(5, 10000e6)` / `previewClaim(0, 10000e6)` / `previewClaim(Set3-0, 1000e6)` | 998.178784 / 994.087419 / 123.393444 |
| USDC.e balances: Set1 4,168.126922 · Set3 1,150.675622 · Set2 0 · Set4 0 | `setState()=1` on all four |
| CPT supplies: 10,436.945579 / 11,736.214561 / 112.997194 | helper dust 0.894327 / 0.928969 / 1.015470 |
| UMA `getRequest` (Aave trigger) | settled=true, bond 500,000,000, liveness 432,000, settle payout 1,025,000,000 |
| UMA `getRequest` (Uniswap v3 trigger 0xb634BF77) | settled=**false** — still proposable |

Non-USDC items inside the Sets are spam/phishing airdrops (`www.base1.cfd`, `op-claim.com`), no value.

---

## 7. Classification

- **E-U = $0.00** (high confidence) for the CSET residual in `0x17705474` and `0x426713c9`.
- **H-O = 5,318.689610 USDC.e** total, of which **2,222.419203 is live now** (CPT claims — holder only) and 3,096.270407 is holder-owned but currently blocked by the Cozy pause (redeem reverts; `dripSupplierFees` still pays suppliers).
- **P = 0.112934 USDC.e** (set-owner fees; privileged).
- **S = $0.00**.
- **Additional identified CSET contracts (not the incident target):** same-generation `0x09947441…` 50.000000 (PAUSED), `0xCd1889f7…` 0.502501 (PAUSED); other-generation/impl Sets with USDC.e: `0xcC5C3F31…` **13,446.938850** (Dec-2022 Gen-1 vault; a holder withdrew 87,409.00 in block 102,675,849, remaining shares redeemable → H-O), `0x14c0AFB6…` 113.484092, `0x288A668d…` 80.677288, `0x47fE1C30…` 10.507298, `0x46fdF205…` 10.051154, `0x372893DA…` 6.606850†, `0x03ba90c6…` 5.755156†, `0x05585408…` 2.071946†, `0x6A11F7C7…` 1.443562, `0xf2E9B879…` 0.302825†, `0x1cfD6c46…` 0.100003†, `0x339a9931…` 0.050003† († = `setState()==0` ACTIVE).
  - For the ACTIVE small Sets the same UMA-trigger design exists (verified on `0x372893DA`: UMATrigger, "Did Uniswap get hacked?", bond 1,000, 5-day liveness) and `purchase` passes the state gate (`InvalidPurchase()` when unpaid). Combined ceiling ≈ **14.89 USDC.e**, but any run risks a 500–1,000 USDC bond against post-incident monitoring → E-U contribution considered **$0 material** (technical tail documented).

**What would change the verdict:** (1) Cozy unpauses — for Set3, if `purchase` on a TRIGGERED market turned out to be allowed (the current `InvalidState()` cannot be attributed solely to the market state because the Set is also paused), an attacker could buy up to 1,122.79 face at ~4% and claim up to ~1,150.68 → E-U flips to ≈$1.1k. This is the key tripwire; almost all implementations check market state, so I rate it very unlikely. (2) Any CPT/CSET holder granting an approval to an unprivileged spender (none today). (3) A permissionless unpause/upgrade path (none found; clones are immutable). (4) Cozy injecting fresh collateral → remainingProtection>0 while unpaused (Set1) reopening mint+purchase.

**Blockers/uncertainties:** the Set implementation is unverified (selectors inferred from traces + interfaces repo); `0x59818bce` (redemption pause error) and `0x25062e25` are unnamed custom errors; exact pause-vs-market-state ordering for `purchase` on triggered markets could not be isolated while all Sets are paused; Blockscout search pagination is broken, so the CSET enumeration is complete for the manager/factory lineage and DL-recognized TVL but not guaranteed exhaustive for older/other-generation Sets.

---

## 8. Evidence files

- `live_state_final.json` — frozen-state snapshot + all `eth_call` simulation results (blocks 158,019,927 / 158,020,077).
- `probe_live.json` — full probe battery (block 158,018,981; 637 calls, 226 OK, rest expected reverts).
- `sets_probe2.json`, `all_sets.json` — Set universe probes.
- `decode_tx.py`, `probe_live.py`, `final_snapshot.py`, `enumerate_sets.py`, `extract_sets.py` — scripts (public RPCs only).
- `evidence.json` — machine-readable summary.
- `sources.md` — URLs.
