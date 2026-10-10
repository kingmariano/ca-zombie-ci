# H2-06 · Filecoin sub-scout — HashKing / FILLiquid (FEVM, chain 314)

**Status:** read-only research; **no mainnet transactions signed or sent**; all "proofs" are `eth_call`
simulations against live state or read-only API reads. No keys, no deployments, no writes to chain.
**Chain:** Filecoin mainnet, chain id 314 (0x13a). **Block heights:** canonical dump at **6,444,339**;
first sweep at 6,444,162–6,444,175; Sep-3 event at **6,337,055**. **FIL price:** $1.1216
(DefiLlama `coins.llama.fi`, 2026-10-10 12:50 UTC; a second read gave $1.1256 at 12:11 UTC).
**Method note:** every contract below was bound to its on-chain bytecode (`eth_getCode`), verified
sources fetched where available, otherwise decompiled with heimdall-rs (sources saved in `evidence/`).

---

## 1. TL;DR

| # | Target (contract) | Live unprivileged extractable | Why open/closed | Class |
|---|---|---|---|---|
| 1 | **FILLiquid pool** `0xFD669BDD…` | **$0** | Pool cash = **0 FIL** since 2026-09-03 sweep; `redeem()`/`borrow()` revert (no balance); accounting is phantom (claims 254,531.9 FIL that is not there) | S / H-O* |
| 2 | FILLiquid `feeReceiver` `0x7201166F…` (2,911.83 FIL) | **$0** | `transfer()`/`transferAll()` are owner-gated; sim from arbitrary addr → `Not owner` | P |
| 3 | FILLiquid `FIGStaking` `0xD44bfE45…` (1,046.03 FIL) | **$0** | `withdraw()` stranger-scoped → returns 0; `unStake()` → `Invalid staker` | H-O |
| 4 | **HashKing KingHash vault** `0xe012F395…` (9,414.20 FIL) | **$0** | `unstake` gated by nFIL burn (stranger → `ERC20: burn amount exceeds balance`); all admin paths revert; UUPS owner = weighted multisig | H-O |
| 5 | HashKing `nFIL` token `0x84B038DB…` | **$0** | `whiteListMint/Burn` vault-only (`Not allowed to touch funds`); `initialize` done, `upgradeTo` owner-only | P |
| 6 | HashKing `wFIL` `0xD9A72484…` (2,969.95 FIL) | **$0** | Plain 1:1 wrapped FIL; `totalSupply() == balance`; no privileged paths | – |
| 7 | STFIL legacy token `0x3C3501E6…` (5.54M supply) | **$0** | Token/pool hold 0 FIL; dead since 2024 incident; proxy admin = 0xc55e4097… | S / P |

**Headline (external unprivileged, live): E-U = $0.** Proven by simulation on every value-moving
path plus zero balances where cash should be. **Latent H-O custody:** HashKing's nFIL bookkeeping
covers **439,772.21 FIL** (idle 9,414.20 FIL immediately redeemable + 430,358.01 FIL recorded at
validator proxies, tied up with storage providers).

---

## 2. Headline numbers (block 6,444,339; FIL $1.1216)

| Category | Amount (FIL) | USD | What it is |
|---|---:|---:|---|
| **E-U** | **0** | **$0.00** | No path for an arbitrary address (all simulated paths revert) |
| H-O | 439,772.21 | ≈ $493,233 | HashKing nFIL holders' 1:1 redemption claim (idle 9,414.20 ≈ $10,559 + validators 430,358.01 ≈ $482,674) |
| H-O | 1,046.03 | ≈ $1,173 | FILLiquid FIG-staker dividend pool (`withdraw()` staker-scoped) |
| H-O* | 0 on-chain (phantom 254,531.90) | $0 (notional $285,474) | FIT holders — see §4; the pool cash was moved off-chain 2026-09-03; public registration process exists off-chain |
| P | 2,911.83 | ≈ $3,266 | FILLiquid feeReceiver (owner `0x6dc515…`) |
| P | (authority) | — | HashKing weighted multisig can `upgradeTo` vault+nFIL; STFIL proxy admin; FILLiquid governance/foundation contracts |
| S | 5,541,237.27 (token supply) | $0 | STFIL claim with no on-chain backing |

---

## 3. Address inventory (all bound to on-chain bytecode)

| Address | Role | Live state (block 6,444,339) | Evidence |
|---|---|---|---|
| `0xFD669BDDfbb0d085135cBd92521785C39c95bA4b` | FILLiquid pool (verified `contracts/FILLiquid.sol`, solc 0.8.24) | **0 FIL**; `getStatus()` = 254,531.90 "available", utilized 0; owner `0x…dEaD` | `evidence/filliquid_pool_contract.json`, `.sol` |
| `0xA25F892cF2731ba89b88750423Fc618De0959C43` | FILLiquid static TVL reader (`getTVL()`) | returns pool `totalFILLiquidity()` (254,531.90) | live call |
| `0x87006Fb444878A69D6692Dc944D1dd418f52F053` | FIT token ("FILLiquid Trust"), verified | supply 235,933.03; managers = pool + FITStake; `mint/burn/withdraw` manager-only | `evidence/FILTrust.sol` |
| `0xB153Cb3efF3e7330DDF4962c22aA8DC63B7fa952` | FITStake farm | holds 208,537.58 FIT (users withdrawing since Oct-7), 0 FIL | live calls; transfer log |
| `0xc87FAb479B450993E8A7b498C631AdF81f3ca5B4` | FIG governance token | supply 833,341,571.14; 0 FIL | Blockscout |
| `0xD44bfE4523f1B2703DDE9C7dBc010Ad39EF668f7` | FEVM FIGStaking (dividend pool) | **1,046.034485 FIL**; `withdraw()` staker-scoped | decompile + sims |
| `0x7201166FAD30f26f27c36842209b1A35e9f6f0d3` | FILLiquid feeReceiver (protocol revenue) | **2,911.831042 FIL**; owner `0x6dc515B288Acd46102CCcf0300B4e14cC30751Ac` | decompile + sims |
| `0xfb1473ba128B9c8146C899cf9455c0037631D389` | FILLiquid "Governance" contract | 0 FIL; can `setGovernanceFactors` on pool | docs + live |
| `0xe012F3957226894B1a2a44b3ef5070417a069dC2` | **HashKing KingHash vault** (UUPS proxy) | **9,414.203551 FIL**; impl `0x73D1Ef86…`; owner = multisig `0x0AaD51Ed…` | decompile + sims |
| `0x84B038DB0fCde4fae528108603c7376695dc217f` | **nFIL** ("Node FIL") receipt token (proxy) | supply **439,772.214541**; impl `0xb9529231…`; owner = same multisig | decompile + sims |
| `0xD9A724840a46370c01a50C1E511087ab3a07FB53` | **wFIL** ("Wrapped FIL") | 2,969.948512 FIL == totalSupply (1:1) | decompile |
| 10 validator proxies (`0x780FB8AD…`, `0x08AEea27…`, `0xECffA69f…`, `0x1615870C…`, `0xD0B4f618…`, `0x9b555C2A…`, `0xAA30fB03…`, `0xf5d8Fd07…`, `0x151Cdb20…`, `0x0A051232…`) | HashKing per-SP bookkeeping (beacon `0xe48b0d6f…` → impl `0xf440b39B…`) | totalStakingFil Σ = **430,358.01**; native balances ≈ 0 (dust 2.02 FIL total) | decompile + calls |
| `0x0AaD51Ed6d3b75C7852D5D620402a6D85cd26f6e` | HashKing owner (weighted multisig + timelock) | signers: `0x26D3A7D1…`, `0x130C05Ec…`, `0x3CC5aDaB…` (3) | decompile + `signers()` |
| `0xfeB16A48dbBB0E637F68215b19B4DF5b12449676` / `0x43bf226b…` | HashKing hubPool / governance | 0 FIL; proxy-style | live |
| `0x3C3501E6c353DbaEDDFA90376975Ce7aCe4Ac7a8` | **STFIL** legacy token (EIP-1967 proxy) | supply 5,541,237.27; **0 FIL**; impl `0xf1eca87a…` (Aave-style aToken), admin `0xc55e4097…` (AccessControl proxy-admin with `upgradeTo`/`upgradeToAndCall` → P) | decompile; Blockscout |
| `0xC8E4EF1148D11F8C557f677eE3C73901CD796Bf6` / `0x8ca2fb7E86b440163666DC32186E1Dc0b74a505b` | STFIL pool / treasury | pool 0 FIL; treasury EOA 38.12 FIL | live |

### The 2026-09-03 event contracts
| Address | Role |
|---|---|
| `0x005C3c4e041Af89E7009F7ddc23D6CA34Cb28672` | executor EOA (f03825687), drained pool, forwarded, bridged out |
| `0x2F57c9e9703f6b04A711206e0CAB4eB42408987c` | "recovery coordinator" (created by executor inside a pre-set block window) |
| `0xc18787B51E8f69Aaca908AF9775Ad902051CcCF5` | "recovery worker" (created by coordinator; borrowed/paid back loops, swept) |
| `0xce16F69375520ab01377ce7b88f5ba8c48f8d666` | SquidRouterProxy (bridge out) |
| `0xE757683a51CfD002De479385c2F4C9DB10A5E8D2` | EOA receiving 23,220 FIL pre-bridge |

---

## 4. FILLiquid — reconstruction and the 2026-09-03 sweep

**Reconstruction.** The pool is the verified `FILLiquid.sol` (solc 0.8.24, CertiK/Salus audited per
docs). Key facts from source + live reads:

- `owner()` = `0x…dEaD` (renounced). `governance` = `0xfb1473ba…` — can only `setGovernanceFactors`
  (15 economic parameters; cannot mint or move funds). `foundation` = `0x7201166F…` (feeReceiver).
- LST accounting: `availableFIL() = dep + payback + interest − redeem − redeemFee − borrow − borrowFee`;
  `totalFILLiquidity() = dep + interest − redeem − redeemFee − badDebt`; `exchangeRate` = f(supply, totals, u_m).
- FIL leaves the pool only via: `redeem` (burn FIT, pay FIL), `borrow` (send to bound miner), and
  small refunds in payback paths. Gas-relevant roles: `onlyOwner` (dead) / `onlyGovernance` / miner-binding.
- FIT token: `mint/burn` only for pool and FITStake (managers); no public mint.

**Live state (block 6,444,339):** `eth_getBalance(pool) = 0 FIL` (glif + ankr + Blockscout agree),
while `availableFIL() = 254,531.900214 FIL` and FIT supply = 235,933.03. Utilization 0; no bad debt;
`collateralizedMiner` 3; `minerWithBorrows` 0; 5,590 deposits / 80 borrows lifetime.

**The sweep (tx `0x0041111742c27b6f1e6706dc8399fff0a68ec1ff387d7631edb7050bcb4fe7be`, block 6,337,055,
2026-09-03T06:47:30Z).** Balance history: pre 254,877.20017925594 FIL → post 0. One tx moved the whole
idle balance:

- Forensics: 15 `Borrow` events (Σ 252,328.428177 FIL to worker `0xc18787B5…`), 15 `Payback` events
  (Σ principals 254,877.200179 FIL, all `minerIdPayer = minerIdPayee = f03825752`), 1
  `UncollateralizingMiner`; 15 × 1 % fees (Σ 2,548.7719 FIL) paid to the **real** foundation
  `0x7201166F…`; 63 event logs; 410 internal txs.
- Worker → executor EOA 252,338.428177 FIL; executor bridged out via Squid in 14 txs (≈ 299 k FIL
  incl. its own funds) plus 23,220 FIL to EOA `0xE757683a…`; remaining dust 339.0677 FIL.
- The coordinator bytecode (creation tx `0x0041111742…`) contains professional recovery guards:
  `unauthorized executor`, `outside recovery window` (0x60B184–0x60B2B0 = blocks 6,336,900–6,337,200),
  `pool code changed`, `pool accounting changed`, `pool debit did not conserve value`,
  `unexpected recovery proceeds`, `destination receipt mismatch`, `coordinator retained FIL`, etc.
- Post-state: loans all repaid/cleared (utilized 0, bad debt 0) while the **cash is gone** — i.e. the
  sweep was executed *through* the pool's own borrow/payback machinery by an operator with control of
  miner `f03825752`, and the pool accounting was *not* written down (FIT exchange rate still 1.078831).

**Interpretation & classification (honest):** on-chain, this is an operator-executed wind-down/“recovery”:
hardcoded executor check, pre-computed block window, invariant checks on pool code/accounting, fees paid
to the real foundation, and a public FILLiquid process instructing **“FIT holders can register their FIT
amount and staking wallet address … Once verified, users will withdraw their FIT from the Farm”** (X/Twitter
snippets, Oct-2026; FIT farm withdrawals visible on-chain since 2026-10-07). We cannot cryptographically
prove authorization, but the pattern is far from opportunistic. What is certain for this campaign:

1. **Unprivileged attackers have no path** to this machinery (executor is hardcoded; window is closed;
   pool holds no cash; borrow needs a bound miner + collateral + cash).
2. **FIT holders have no on-chain redemption anymore.** Simulated `redeem(1 FIT)` from the largest real
   holder (`0xD48CF590…`, 7,875 FIT) and from FITStake (208,537 FIT) both revert at the payout transfer
   (empty revert data) because the pool balance is 0. Any residual value depends on the off-chain
   registration process — outside on-chain measurement (S*, notional $285 k, on-chain $0).

---

## 5. HashKing — reconstruction

**KingHash vault `0xe012F395…`** (UUPS proxy; impl `0x73D1Ef86…`; admin slot empty; owner = multisig):

- Payable `stakeFil()` (in) / `repayment()` (in); `unstake(uint256)` (selector `0xcebbfa44`, and a
  variant `0xc3178389`) burns the caller's **nFIL** and pays the same amount in FIL from the vault's
  idle balance (verified: 2026-01-03 tx `0x70daa198…` burned 126,200.723 nFIL and paid
  126,200.72300550129 FIL to the caller; positive simulation 2026-10-10 from a real nFIL holder:
  `unstake(1 FIL)` / `unstake(1,000 FIL)` succeed, `unstake(10,000 FIL)` reverts
  `Address: insufficient balance` — payouts are bounded by the vault's idle FIL, currently 9,414.20).
- Admin: `upgradeTo`, `upgradeToAndCall`, `transferOwnership`, `renounceOwnership`, `setGovernance`,
  `setHubPool` (owner); `addBeneficiary`/`delBeneficiary`/`setTotalPoolFilLimit` (owner **and**
  governance = multisig); `depositFil` / `claimRewards` / `0x88f9184f` gated to hubPool/beneficiary set.
  All simulated from an arbitrary address → reverts (`Ownable: caller is not the owner`,
  `caller is not allow`, `invalid beneficiary`, `caller is not hubpool`).
- `initialize(address)` already consumed (`Initializable: contract is already initialized`).
- Last activity 2026-01-03; balance frozen at 9,414.203551 FIL.

**nFIL `0x84B038DB…`** (proxy; impl `0xb9529231…`): ERC-20 "Node FIL", supply 439,772.214541. Mint and
burn are *only* callable by `liquidStakingContractAddress` (the vault): `whiteListMint/whiteListBurn`
guards reproduced in decompile and by simulation. `initialize` consumed; `upgradeTo`/`setLiquidStaking`
owner-only (same multisig). No public mint, no allowance bypass.

**wFIL `0xD9A72484…`:** plain wrapped FIL — `deposit()` payable credits the sender, `withdraw(uint256)`
debits the sender, `totalSupply()` returns `address(this).balance`. Supply == balance == 2,969.948512
(1:1 solvency by construction). No owner, no mint. Actively used (deposits on 2026-10-10 verified).

**Bookkeeping reconciliation (solvency):** nFIL supply 439,772.2145 ≈ vault idle 9,414.2036 +
validators Σ`totalStakingFil` 430,358.01. The validators are beacon proxies (beacon `0xe48b0d6f…`,
impl `0xf440b39B…`) whose fund-moving functions (`withdrawBalanceFil`, `depositFil`, reward split) all
require caller == owner **and** == governance of the validator; their own balances are dust.

---

## 6. Path-by-path audit (all simulations at block ≈ 6,444,339–6,444,430; raw log in `evidence/negatives_output.txt`)

| Contract | Path | Gate (live) | Sim from arbitrary address | Verdict |
|---|---|---|---|---|
| FILLiquid pool | `deposit()` | payable, mints FIT | n/a (inbound) | – |
| FILLiquid pool | `redeem()` | burns caller FIT from **0-balance** pool | real FIT holder → revert at payout (empty revert) | **$0 / S** |
| FILLiquid pool | `borrow()` | bound miner + collateral + pool cash | no miner bound to random attacker; pool cash 0 | **$0** |
| FILLiquid pool | `withdraw4Payback`/`directPayback` | caller's own family / own msg.value | refund-only semantics; no pool cash | $0 |
| FILLiquid pool | `liquidate()` | same-family caller only | cannot touch other families | $0 |
| FILLiquid pool | `collateralizingMiner()` | miner owner or signed owner proof | requires real miner control; no cash to borrow | $0 |
| FILLiquid pool | `uncollateralizingMiner()` | family owner, zero debt | releases own miner | $0 |
| FILLiquid pool | `setOwner` (owner dead) / `setGovernanceFactors` (governance) | not unprivileged | revert | P |
| FILLiquid feeReceiver | `transfer`, `transferAll` | owner `0x6dc515…` | `Not owner` | P ($3,266) |
| FILLiquid FIGStaking | `withdraw()` | staker-scoped math | returns 0 (no revert, no payout) | H-O ($1,173) |
| FILLiquid FIGStaking | `unStake()` | staker records | `Invalid staker` | H-O |
| FITStake farm | FIT staking/unstaking | user-scoped; no FIL held | 0 FIL in contract | $0 |
| HashKing vault | `unstake` (`0xcebbfa44`, `0xc3178389`) | burns caller nFIL | stranger → `ERC20: burn amount exceeds balance`; **positive:** real nFIL holder (181,795 nFIL) → `unstake(1 FIL)` and `unstake(1,000 FIL)` **succeed**; `unstake(10,000 FIL)` → `Address: insufficient balance` (idle = 9,414.20 FIL) | H-O ($10,559 idle live) |
| HashKing vault | `upgradeTo`/`upgradeToAndCall` | weighted multisig | `Ownable: caller is not the owner` | P |
| HashKing vault | `initialize(address)` | consumed | `already initialized` | closed |
| HashKing vault | admin setters (`setGovernance`, `setHubPool`, `setTotalPoolFilLimit`, `add/delBeneficiary`, `0x427e5241`) | owner / owner+governance | `caller is not allow` / `not the owner` | P |
| HashKing vault | `depositFil`, `claimRewards`, `0x88f9184f` | hubPool/beneficiary | `invalid beneficiary` / `caller is not hubpool` | P |
| nFIL | `whiteListMint`/`whiteListBurn` | vault only | `Not allowed to touch funds` | closed |
| nFIL | `upgradeTo`/`setLiquidStaking`/`initialize` | multisig / consumed | owner revert / already initialized | P |
| wFIL | all | ERC-20 + 1:1 wrapper | no privileged path exists | closed |
| STFIL | token transfer only; pool redeem | STFIL pool has 0 FIL | dead token | $0 |

---

## 7. Negative results (do not re-investigate)

- **No live drain path on FILLiquid**: pool cash 0 across three independent sources; every value-moving
  entry point either requires privileged roles, a bound miner, or fails on zero balance.
- **No upgrade takeover**: both UUPS proxies already initialized; owner = multisig.
- **No hidden mint**: FIT, nFIL, wFIL mint authorities verified (manager/vault/none). FIG token is a
  governance token with no FIL backing.
- **STFIL legacy is dead**: token contract + its Aave-style pool hold 0 FIL; only its treasury EOA has
  38.12 FIL; supply 5.54 M unbacked. (This is the asset of the Apr-2024 stfil.io incident, not part of
  HashKing/FILLiquid.)
- **FILLiquid static TVL ($285 k on DefiLlama) is phantom** — it reads `totalFILLiquidity()`, which was
  not written down after the Sep-3 sweep. Treat FILLiquid TVL feeds as stale.
- Attack simulation from arbitrary addresses on every "write" selector of the HashKing vault, nFIL and
  the pool — no path succeeded (see table §6).

---

## 8. Reconciliation with campaign H2-06 (“12,358.8 FIL ≈ $13.1 k”)

The campaign figure matches the **two HashKing contract native balances** only:
9,414.203551 (vault) + 2,969.948512 (wFIL) = **12,384.152063 FIL** today (the wFIL leg moves a few FIL
per week, so a measurement ≈ 12,358.8 FIL predates the latest deposits). It **excludes the 430,358.01 FIL
recorded at the ten HashKing validator proxies**, which is the bulk of HashKing's real book (DefiLlama’s
$496 k HashKing TVL agrees with 442,742.16 FIL total tracked). The campaign’s “upgradeable proxies”
leads check out but resolve to **multisig-owned UUPS** (not attacker-open), and FILLiquid’s 254.5 k FIL
pool balance was already swept off Filecoin on 2026-09-03, before this campaign sweep.

---

## 9. Verdict

- **External unprivileged extraction live, today: $0 (high confidence).**
- **HashKing (KingHash)**: closed to attackers; 439,772.21 FIL is an H-O claim of nFIL holders
  (9,414.20 FIL idle redeemable; 430,358.01 FIL contingent on HashKing’s SP/validator releases —
  unverifiable on-chain). Upgrade authority = 3-signer weighted multisig (P).
- **FILLiquid**: the pool is empty; FIT redemption is dead **on-chain** (phantom accounting), 254,877.20 FIL
  was moved off Filecoin on 2026-09-03 by an executor-gated “recovery” workflow and bridged out via Squid;
  a public FIT-holder registration process suggests off-chain handling (not measurable here). Protocol
  revenue (2,911.83 FIL) remains owner-gated. FIG dividend pool (1,046.03 FIL) is staker-gated.
- **What would change the verdict:** new FIL entering the FILLiquid pool triggers fresh `redeem`/`borrow`
  testing (borrow-side latent risk), HashKing idle liquidity rising above 0 changes H-O depth, and any
  observed `Upgraded` event from a non-multisig address on either proxy.

**Confidence:** E-U=$0: **high** (triple-source zero balances + successful failure-mode simulations on
every path). Classification of the Sep-3 sweep as operator wind-down: **medium-high** (on-chain pattern
+ registration process; no signed authorization visible on-chain). The 430,358 FIL validator claim:
**medium** (bookkeeping verified; underlying SP custody is off-chain).

---

## 10. Coverage & caveats

**Audited (source/decompile + live simulation):** FILLiquid pool, FIT token, feeReceiver, FIGStaking,
FitStake (balance/roles), HashKing vault impl + proxy, nFIL impl + proxy, wFIL, validator beacon/impl,
STFIL token geometry, recovery coordinator/worker call graph.
**Screened (balances/roles only):** FIG token, HashKing hubPool/governance/multisig internals (signer
list + guard reverts), the ten validators (views only), Squid bridge destination (out of scope), BSC-side
HashKing deployments (out of scope for this Filecoin sub-scout).
**Not measurable:** off-chain/CEX custody after the bridge; FITHolder registration outcomes; HashKing-SP
loan terms; any archive-block state on public endpoints (archive reads rejected upstream).

**Caveats:** both public RPCs were cross-checked for balances; Blockscout’s `/smart-contracts` endpoint
returns unrelated "verified twin" data for some unverified addresses (e.g. `PoolInfoUtils`), so
decompilation was used and is saved in `evidence/`. The Sep-3 “recovery” contracts are unverified;
their behavior is inferred from call traces + embedded strings. USD values use FIL $1.1216–$1.1256 as
timestamped in `evidence/final_state.json`.

---

## 11. Reproduce

```bash
# canonical state dump (read-only)
python3 scripts/capture_state.py --out evidence/final_state.json
# negative-path proofs (eth_call simulations; nothing is sent)
bash scripts/negative_proofs.sh            # requires foundry cast
# per-target evidence
ls evidence/   # raw RPC reads, verified sources, decompiled contracts, recorded outputs
```

**Files index (selected):** `evidence/final_state.json` (canonical dump @6,444,339),
`evidence/FILLiquid.sol` + `filliquid_pool_contract.json` (verified pool),
`evidence/FILTrust.sol` (verified FIT), `evidence/output_hk/decompiled.sol` (vault impl),
`evidence/output_nfil_impl/decompiled.sol` (nFIL), `evidence/output_wfil/decompiled.sol`,
`evidence/output_validator_impl/decompiled.sol`, `evidence/output_feeReceiver/decompiled.sol`,
`evidence/output_figstake/decompiled.sol`, `evidence/output_stfil_impl/decompiled.sol`,
`evidence/coordinator_creation_bytecode.txt` + `coordinator_strings.txt`,
`evidence/negatives_output.txt` (verbatim closure proofs).
