# C2-21 — Purrlend (HyperEVM 999 + MegaETH 4326): fresh unprivileged extractable = $0; privileged exposure = $595.54 of idle liquidity behind live admin keys

**Date:** 2026-10-09 · **Chains:** HyperEVM (chain 999), MegaETH (chain 4326) · **Status:** read-only research;
PoC fork-verified only; **no transaction was ever sent to a real chain**. All mutations below run on local
forks created by `vm.createSelectFork` against public keyless RPCs.

**Finding under review (C2-21):** “$12.2M live, role-holder key risk (Apr-2026 exploit lineage) —
`grantRole(BRIDGE)` → `mintUnbacked` (onlyBridge) — one key compromise away. Pools ~fully lent out;
idle ≈ $595; the ~$12.2M is bad-debt/claims, not idle cash.”

**Verdict in one line:** the fresh-external-unprivileged path is **$0.00** (all 13 reserves on both chains are
`paused`, every value-moving function requires `!isPaused`, and the ACL `grantRole` is protected by
`DEFAULT_ADMIN_ROLE`); the privileged path is real but its **cash ceiling is $595.54** — the only liquidity left
in the system. The nominal ~$14.5M of aToken claims has ~$0 cash behind it (≈$6.86M of it is the attacker's
own unbacked mint, and the rest is lent-out/dead debt).

---

## 1. TL;DR

| Target | Live extractable (external, unprivileged) | Why open / closed | Latent risk (privileged) |
|---|---|---|---|
| HyperEVM pool `0xb61218d3…` (9 reserves) | **$0.00** | All reserves `paused`; `supply/withdraw/borrow/repay/flashLoan/liquidationCall` all revert (`RESERVE_PAUSED`='29'); no BRIDGE holder; fresh `grantRole` reverts; idle = 0 for every reserve except 420.05 sUSDp held by the aToken | EOA `0x6056be98…` (single key, DEFAULT_ADMIN) can self-grant POOL_ADMIN+BRIDGE, unpause, and reach **$420.06** (sUSDp) + dust; the Safe (provider owner) can replace the ACLManager / pool impl |
| MegaETH pool `0x81D5D25e…` (4 reserves) | **$0.00** | Same — all reserves paused, no BRIDGE holder, fresh paths revert | EOA `0x6056be98…` and the old 2-of-3 Safe (both DEFAULT_ADMIN; Safe also provider owner) can reach **$175.48** (GLV) + dust |
| Attacker `0xd8010aca…` (Apr-2026) | **$0.00** | Roles revoked 2026-04-25; holds 5.495M phantom aUSDC + 2.100M phantom aUSDm that are **unredeemable** (aToken idle = 0) | — |
| **Total** | **$0.00 (E-U)** | | **P = $595.54** cash ceiling + control over the frozen $14.54M nominal claims |

**Total live extractable now: $0.00 (external unprivileged). Confidence: HIGH** (fork-proven: every candidate
path reverts; the mechanism and numbers are reproducible from the tests in §7).

**Privileged exposure (P): $595.54** maximum immediately-realizable cash (HyperEVM $420.06 + MegaETH $175.48),
reachable by the current DEFAULT_ADMIN holders (single EOA `0x6056be98…` on both chains; additionally the old
2-of-3 Safe on MegaETH) and by the Safe as AddressesProvider owner on both chains. Everything else privileged
actors can do (unpause, reconfigure, upgrade aToken/pool implementations, force-liquidate) manipulates
**claims without cash** — it cannot conjure the missing ~$14.5M−$0.6k of liquidity.

---

## 2. The mechanism in exact terms

Purrlend is a fork of Aave v3 core (`lib/aave-v3-core/…` in the verified source of pool impl
`0xd8c76f87…` on MegaETH; Sourcify partial match, compiler 0.8.10). The April-2026 exploit was **not** a code
bug in the usual sense — it was a privileged-role abuse enabled by the protocol's own ACL design:

1. **`mintUnbacked` is gated by the ACL `BRIDGE` role.** Verified deployed source (`Pool.sol`):

   ```solidity
   modifier onlyBridge() { _onlyBridge(); _; }
   function _onlyBridge() internal view virtual {
       require(
         IACLManager(ADDRESSES_PROVIDER.getACLManager()).isBridge(msg.sender),
         Errors.CALLER_NOT_BRIDGE          // '6'
       );
   }
   function mintUnbacked(address asset, uint256 amount, address onBehalfOf, uint16 referralCode)
       external virtual override onlyBridge { BridgeLogic.executeMintUnbacked(...); }
   ```

   `ACLManager.isBridge(x)` == `hasRole(BRIDGE_ROLE, x)`; `BRIDGE_ROLE = keccak256("BRIDGE") =
   0x08fb31c3e81624356c3314088aa971b73bcc82d22bc3e3b184b4593077ae3278`. `getRoleAdmin(BRIDGE) =
   DEFAULT_ADMIN_ROLE` on both chains (verified `eth_call`). So **any DEFAULT_ADMIN can grant BRIDGE**, and a
   BRIDGE holder can mint unbacked aTokens and hand them to any address.

2. **`executeMintUnbacked` calls `ValidationLogic.validateSupply`, which requires `!isPaused`.** Consequence:
   even a BRIDGE holder cannot mint while the reserve is paused — the privileged path must first unpause
   (`PoolConfigurator.setReservePause`, `onlyPoolAdmin`), i.e. it needs DEFAULT_ADMIN → POOL_ADMIN → unpause →
   BRIDGE. All of these grants are one `grantRole` away for the current admin holders.

3. **What actually happened (2026-04-25):** the old 2-of-3 Safe `0x4c2444d8…` (threshold 2, owners
   `0x7312F0b2…`, `0x2BceF069…`, `0xB4837962…`) executed transactions granting
   `ASSET_LISTING_ADMIN + BRIDGE + POOL_ADMIN + RISK_ADMIN + EMERGENCY_ADMIN` to attacker EOA
   `0xd8010aca201f6113160200b8a521f35be9f94c24`:
   - HyperEVM: grant at block 33,372,289 (2026-04-25 01:20 UTC), revoked at 33,394,150 (07:18 UTC).
   - MegaETH: grant at block 14,284,168 (01:39 UTC), revoked at 14,304,738 (07:22 UTC).
   The attacker then called `mintUnbacked` and drained the idle liquidity:
   - HyperEVM: **16 × `mintUnbacked(USDC, …)` totalling 4,850,000 USDC** (event sum == the live `unbacked`
     counter 4.85e12 raw, read at block 48,051,486), then 7 `borrow(…)` calls.
   - MegaETH: **4 × `mintUnbacked(USDm, 500,000e18)` = 2,000,000 USDm** (== live `unbacked` 2e24 raw, read at
     block 28,723,353), then 4 `borrow(…)` calls.
   Public reporting: $1.52M realized across both chains (DefiLlama “Access Control / Caller Impersonation”).

4. **Post-incident (same day):** the roles were revoked and a **fresh single EOA**
   `0x6056BE985DD4c50fECA34130FeDD0a35857099FD` was installed as DEFAULT_ADMIN (+RISK_ADMIN) on both chains;
   it then stripped the Safe's remaining ACL roles (on HyperEVM including DEFAULT_ADMIN; on MegaETH the Safe
   kept DEFAULT_ADMIN). The Safe nevertheless still **owns the AddressesProvider** on both chains and is the
   stored `getACLAdmin()`. All reserves were paused — and have remained paused and frozen since (reserve
   `lastUpdateTimestamp` ≈ 1,777,09x,xxx = 2026-04-25).

---

## 3. Live-state assessment (all reads 2026-10-09, explicit blocks)

### 3.1 Contracts and control

| Item | HyperEVM (999) | MegaETH (4326) |
|---|---|---|
| ACLManager | `0x507Bc877A27baEB12BE4Df42EfAA949A9A67703d` | `0x217214BbF25F02A8019d42EA315aB192540aDa13` |
| AddressesProvider | `0xf33e33B35163Ce2f46bf7150E1592839aC199124` | `0x402D38C3415Ad92a0E766e1491Dc222871B1Df7a` |
| Pool (proxy) | `0xb61218d3efE306f7579eE50D1a606d56bc222048` (impl `0x2a49c5a3…`) | `0x81D5D25ea81b72E546fC71B5bAa8B059eF0dA702` (impl `0xd8c76f87…`) |
| PoolConfigurator | `0x8cFaFcAc64a9a5CB52FC3482c3b8C855e9308767` | `0xB54407684B028ee75F012EF264644186e93e4E0E` |
| PriceOracle | `0xa55d6358c22CdFe8d469C5703621052e8Ff9EF1B` | `0x514353F18A54159ff51f477F201FbD11B5d19464` |
| Provider `owner()` | **Safe `0x4c2444d88AD61B0842Fba7CCdCb226260eBfA1bc`** | **Safe `0x4c2444d8…`** |
| `getACLAdmin()` | Safe `0x4c2444d8…` | Safe `0x4c2444d8…` |
| Live ACL holders (block 48,051,824 / 28,723,846) | DEFAULT_ADMIN + RISK_ADMIN = EOA `0x6056be98…` only | DEFAULT_ADMIN = EOA `0x6056be98…` **and** Safe; RISK_ADMIN = EOA |
| BRIDGE holders | **none** | **none** |

- Safe `0x4c2444d8…`: threshold **2**, owners `0x7312F0b280f4Bbaa47fC6485809f1C5Cc629d7bB`,
  `0x2BceF069eAEA664397A28F99b0DE5D4A4f78E23E`, `0xB4837962855A1594E7ADe6B87dAA3E8F4a34baeD` (same on both
  chains). Safe nonce 30 (H) / 4 (M).
- EOA `0x6056be98…`: no code, nonce 8 (H) / 4 (M); can `grantRole` on both chains (verified by `eth_call`
  simulation and in the fork tests). This is the single key behind DEFAULT_ADMIN on both chains.
- Deployer `0xD730Ad41…` (EOA) renounced all roles in 2026 — not a live privilege.

### 3.2 Reserves, pause flags, claims and idle liquidity

All reserves on both chains have `isActive=true, isFrozen=false, borrowingEnabled=true, **isPaused=true**`
(config bit 60; decoded from `Pool.getConfiguration`). Flash loans: enabled but paused-blocked.

| Chain / reserve | aToken supply (claims, nominal) | Debt (receivables) | **Idle cash in aToken** | `unbacked` counter |
|---|---|---|---|---|
| H WHYPE | 8,791.66 | 13,732.10 | 0.00008 | 0 |
| H wstHYPE | 5,217.93 | 8,706.07 | 0 | 0 |
| H kHYPE | 2,417.18 | 3,408.80 | 0 | 0 |
| H UBTC | 6.511 | 11.564 | 0 | 0 |
| H UETH | 98.88 | 175.68 | 0 | 0 |
| H USDC | 7,578,751.72 | 3,305,957.23 | **0** | **4,850,000** |
| H USD₮0 | 1,024,963.59 | 1,241,448.61 | 0 | 0 |
| H USDH | 839,227.23 | 1,024,991.35 | 0.00235 | 0 |
| H sUSDp | 420.05 | 0 | **420.054151257482857455** | 0 |
| M WETH | 62.91 | 83.88 | 0 | 0 |
| M USDm | 2,401,987.55 | 471,963.37 | 0 | **2,000,000** |
| M USD₮0 | 328,844.31 | 386,639.98 | 0 | 0 |
| M GLV | 175.48 | 0 | **175.478672274128016422** | 0 |

**Idle cash totals (the only liquidity any withdraw can pull): HyperEVM $420.06 + MegaETH $175.48 =
$595.54** (USDH/WHYPE dust adds <$0.01). Nominal claims total **$14,538,706**; outstanding debts
**$10,258,665**; protocol-side `unbacked` **$6,858,916**. Prices: DefiLlama, 2026-10-09 (HYPE $85.29,
wstHYPE $87.30, kHYPE $87.48, BTC $82,372, ETH $2,491.7, stables ≈ $1.00; sUSDp and GLV valued at $1.00).

**Where the claims sit:** the incident attacker still holds **5,495,291 aUSDC** and **2,100,054 aUSDm**
(nominal ≈ $7.60M) — the unbacked mint plus a small extra — and is also the largest debtor
(e.g. 807,621 vUSDC, 384,254 vUSDT0, 349,756 vUSDH, 5,487.8 vwstHYPE on HyperEVM; 124,194 vUSDm,
268,394 vUSDT0, 83.88 vWETH on MegaETH). The attacker's aTokens are **phantom claims**: the aUSDC contract
holds **0 USDC**, the aUSDm contract holds **0 USDm**, so they cannot be redeemed even if unpaused
(fork-proven). Legitimate user claims ≈ $14.54M − $7.60M ≈ **$6.93M nominal**, also unredeemable today
(zero idle) and largely backed by dead/attacker debt.

### 3.3 Oracle freshness (no mispricing path)

Frozen pool, but the oracles are still updated and match the market: HyperEVM WHYPE $85.37, USDC $0.99984,
USD₮0 $0.99918, UBTC $82,366; MegaETH WETH $2,488.8, USDm $1.00872, USD₮0 $0.99915. No stale-price or
rounding path exists — and liquidations are pause-blocked anyway.

---

## 4. What an attacker can / cannot do (exact call paths)

**Cannot (all fork-proven to revert at blocks 48.0M / 28.7M):**
- `ACLManager.grantRole(BRIDGE, attacker)` from a fresh address → reverts
  `AccessControl: account … is missing role 0x00…00` (BRIDGE's admin is DEFAULT_ADMIN).
- `Pool.mintUnbacked(...)` from a fresh address → reverts `CALLER_NOT_BRIDGE` ('6') — the modifier runs
  before the paused check.
- `supply` / `withdraw` / `borrow` / `repay` / `flashLoan` / `liquidationCall` from any address →
  reverts `RESERVE_PAUSED` ('29') on every reserve (repay included: `validateRepay` requires `!isPaused`,
  so the pool is fully frozen, not just gated).
- The incident attacker cannot withdraw their phantom aUSDC: paused → '29'; even after an admin unpauses,
  the withdraw reverts because the aToken holds 0 USDC (Panic 0x11 / transfer failure).
- No unprotected initializer: the Pool proxy is initialized (`VersionedInitializable`), the ACLManager is a
  non-upgradeable 3,639-byte contract, the AddressesProvider is `Ownable` with owner = Safe
  (`setACLManager` from a fresh address reverts `Ownable: caller is not the owner`).

**Can (privileged only):**
- DEFAULT_ADMIN `0x6056be98…` (single key): `grantRole(POOL_ADMIN, self)` + `grantRole(BRIDGE, self)` →
  `PoolConfigurator.setReservePause(asset,false)` → `Pool.mintUnbacked(asset, amount, self, 0)` →
  `withdraw` against whatever idle exists. Fork-verified: minting 1,000,000 USDC succeeds (aUSDC balance
  credited) but withdrawing it reverts — **the mint creates claims, not cash**. The reachable cash is the
  idle table above: $420.06 (H sUSDp) + $175.48 (M GLV) + dust. sUSDp/GLV have `unbackedMintCap=0`, so the
  practical cash route is `PoolConfigurator.updateAToken(asset, maliciousImpl, "")` (or
  `setUnbackedMintCap`) — still bounded by the same idle.
- Safe `0x4c2444d8…` (2-of-3) as AddressesProvider owner on **both** chains: `setACLManager(newAcl)` →
  full ACL takeover → same mint path; or `setPoolImpl(malicious)` / `setPriceOracle` /
  `setPoolConfiguratorImpl`. Fork-verified that `setACLManager` executes from the Safe. This is authority
  over the whole frozen system (unpause, reconfigure, destroy/redirect claims) but not new cash.
- MegaETH Safe additionally holds DEFAULT_ADMIN → can grant BRIDGE directly (fork-verified).

**Costs:** none of the above is capital-gated; gas only. There is no flash-loan/depth requirement because
there is no liquidity to extract.

---

## 5. Category split (exact amounts)

| Category | Amount | Basis |
|---|---|---|
| **E-U** (external unprivileged) | **$0.00** | All reserves paused; every value function reverts; no BRIDGE holder; fresh `grantRole` reverts; zero idle for a fresh attacker to take even if something opened |
| **H-O** (holder/user self-service) | **$0.00 currently withdrawable** | User withdrawals require unpause AND liquidity; idle = $595.54 total and debtors (mostly the attacker) don't repay (repay is paused too). Nominal user claims ≈ $6.93M are latent, not extractable |
| **P** (privileged) | **$595.54 cash ceiling** | DEFAULT_ADMIN EOA (both chains) + Safe (provider owner both chains; DEFAULT_ADMIN MegaETH). Unpause+mint/upgrade paths are one key (EOA) or two keys (Safe) away. Authority also covers the frozen $14.54M nominal claims (no cash behind them) |
| **S** (stuck/bricked) | **$0.00** | Nothing is irreversibly bricked: the pause is admin-reversible. The $6.86M unbacked phantom is *unredeemable*, not recoverable, by anyone |

---

## 6. Why the headline is $0 (and why the finding is still worth a monitor)

The corpus claim “$12.2M live” is a nominal-claims figure. On-chain reality:
- **Claims ≠ cash.** aToken supply is a claim on pool assets; the pool's assets are idle ($595.54) + debts
  ($10.26M). The debts are largely the attacker's own unpaid borrows (bad debt) and cannot be collected by
  anyone without the debtors' cooperation — and `repay` is itself pause-blocked.
- **The privileged path is live but capped by liquidity.** `mintUnbacked` mints claims; cashing them needs
  idle liquidity, of which $595.54 exists. The 2026 exploit succeeded only because ~$1.5M was idle at the
  time; that liquidity is gone.
- **The unprivileged path is closed twice over:** no roles for a fresh address, and a full pause on every
  reserve. Even the ACL `grantRole` is standard OZ `AccessControl` with `DEFAULT_ADMIN` as role admin — no
  missing `onlyRole`, no self-grant, no unprotected initializer.

**Residual / latent risk (monitor):**
1. **Single-key admin.** `0x6056be98…` (EOA) holds DEFAULT_ADMIN on both chains. Its compromise = $595.54
   immediate + full destructive control of the frozen system (could unpause and let claimants race the
   $595, or destroy/redirect claims). The old 2-of-3 Safe still owns the provider on both chains and keeps
   DEFAULT_ADMIN on MegaETH — 2 keys to the same authority.
2. **Tripwire:** if the team ever unpauses (or funds the pool, or re-enables reserves), the unbacked-mint
   primitive re-arms for the current admin keys, and any new idle liquidity becomes immediately drainable.
   Monitor `Pool.getConfiguration(asset)` bit 60 (paused) and `hasRole(BRIDGE, *)`.
3. The attacker's $7.6M phantom aTokens and the ~$6.9M user claims stay worthless unless someone
   recapitalizes the pools; any recapitalization is instantly exposed to the admin keys.

---

## 7. PoC / fork verification

**Project:** `poc/` (Foundry; vendored forge-std). **Tests:** `poc/test/PurrlendForkTest.t.sol` —
**11/11 PASS** on local forks of HyperEVM and MegaETH via public RPCs. Tests are read-only against mainnet;
all state changes occur inside `vm.createSelectFork` forks.

| Test | What it proves |
|---|---|
| `test_H_live_roles_no_bridge_holder` | HyperEVM: DEFAULT_ADMIN = EOA only; Safe has no ACL role; nobody holds BRIDGE; `getRoleAdmin(BRIDGE)=0x00` |
| `test_H_all_reserves_paused` | All 9 HyperEVM reserves have `isPaused=true` (config bit 60) |
| `test_H_fresh_unprivileged_paths_all_revert` | fresh `grantRole`, `mintUnbacked`, `supply`, `borrow`, `repay`, `flashLoan`, `liquidationCall`, and even the attacker's `withdraw` all revert ('6' / '29' / AccessControl) |
| `test_H_privileged_bound_is_idle_liquidity_only` | EOA self-grants POOL_ADMIN+BRIDGE → unpause → mint 1M aUSDC succeeds → withdraw reverts (0 idle); asserts idle aUSDC=0, aSUSDp=420.054151257482857455 |
| `test_H_provider_owner_can_replace_acl_manager` | Safe (provider owner) can execute `setACLManager` — full takeover primitive |
| `test_M_live_roles_no_bridge_holder` | MegaETH: DEFAULT_ADMIN = EOA + Safe; no BRIDGE holder |
| `test_M_all_reserves_paused` | All 4 MegaETH reserves paused |
| `test_M_fresh_unprivileged_paths_all_revert` | same revert set as HyperEVM |
| `test_M_privileged_bound_is_idle_liquidity_only` | mint 100k aUSDm succeeds, withdraw reverts; idle aUSDm=0, aGLV=175.478672274128016422 |
| `test_M_safe_default_admin_can_mint_bridge` | MegaETH Safe can grant BRIDGE (2-of-3 key path) |
| `test_phantom_claims_of_incident_attacker_are_unredeemable` | attacker holds >5M aUSDC but the aUSDC contract holds 0 USDC; withdraw fails even after unpause |

**Key fork numbers:** HyperEVM idle $420.06 (sUSDp) / MegaETH idle $175.48 (GLV) → **P = $595.54**;
E-U = $0.00. No gas/swap costs arise because there is no extractable path.

**CI runs (GitHub Actions, public repo `kingmariano/ca-zombie-ci`, branch `purrlend`):**
- run 1 (11/11 PASS): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37886852494

---

## 8. Verdict

- **E-U: $0.00 — confidence HIGH.** Closed by (a) per-reserve pause on all 13 reserves (all value functions
  check it, including repay), (b) no live BRIDGE/POOL_ADMIN holder, (c) OZ AccessControl gating on
  `grantRole` with `DEFAULT_ADMIN` as admin, (d) no unprotected initializer/proxy takeover from outside.
- **P: $595.54 cash ceiling — confidence HIGH**; controlled by EOA `0x6056be98…` (single key, both chains)
  and Safe `0x4c2444d8…` (2-of-3; provider owner both chains; DEFAULT_ADMIN on MegaETH). The same keys hold
  destructive/upgrade authority over the frozen $14.54M nominal claims.
- **H-O: $0.00 withdrawable; ~$6.93M nominal user claims latent** (require unpause + liquidity).
- **S: $0.00** (nothing permanently bricked; phantom unbacked claims are unredeemable by design of the theft).

**Blockers to anything more:** pool-wide pause (admin-reversible), zero idle liquidity, zero role for
fresh addresses, zero secondary market for the aTokens.

---

## 9. Methodology, sources, caveats, files

**Method:** contract discovery via the deployer EOA's CREATE nonces (`cast compute-address`) and GoldRush;
full ACL event history reconstructed from every tx touching each ACL (HyperEVM: 35 txs incl. deploy,
`analysis/hyper_acl_receipts.json`; MegaETH: Blockscout log pagination + role history); live state read at
explicit blocks with `cast`; deployed source pulled from Sourcify partial match (pool impl) and Blockscout
(ACLManager); oracle prices compared to DefiLlama; fork tests in Foundry against public RPCs. No keyed
endpoint was written into any file in this folder (public endpoints only).

**Sources:** HyperEVM RPC `https://rpc.hyperliquid.xyz/evm`; MegaETH RPC `https://mainnet.megaeth.com/rpc`;
Blockscout MCP (chain 4326); GoldRush (chains 999/4326); Sourcify (chain 4326, `0xD8C76f87…`); DefiLlama
prices; public reporting of the Apr-25-2026 incident (DefiLlama hacks DB; startupfortune; ourcryptotalk).

**Caveats:**
- Snapshot at HyperEVM block 48,051,486 / MegaETH 28,723,353 (roles at 48,051,824 / 28,723,846); state can
  change if the admin keys act (see tripwire).
- sUSDp and GLV are valued at $1.00 (no DefiLlama feed); USDT0-MegaETH priced at the HyperEVM USDT0 price.
  These affect the idle total by <$1.
- The `unbacked` counter (4.85M USDC + 2M USDm) vs the attacker's aToken balances (5.495M aUSDC + 2.100M
  aUSDm) differ by ~$0.75M; the delta is aToken balance that is not part of the unbacked mint (likely
  supplied/backed aTokens held by the attacker). Both figures are reported.
- All numbers are point-in-time; re-verify before acting. This is informational research, not an audit.

**Files index:**
```
purrlend/
├── README.md                        # this file
├── summary.json                     # machine-readable summary
├── analysis/
│   ├── role_graph.json              # full ACL role history + live holders + Safe/EOA details (both chains)
│   ├── incident_mechanics.json      # Apr-2026 mintUnbacked/borrow evidence, per-chain
│   ├── live_state_raw.json          # all 13 reserves: aSupply, debt, idle, unbacked (raw reads)
│   ├── reserve_config_decoded.json  # decoded config bits (paused/frozen/LTV/caps)
│   ├── value_table.json             # USD valuation of claims/debt/idle/unbacked + prices
│   ├── hyper_acl_receipts.json      # receipts+inputs of all 35 txs touching the HyperEVM ACL
│   └── repro.sh                     # reproducible public-RPC read commands
├── poc/                             # Foundry project (11 fork tests, all passing)
│   ├── foundry.toml
│   ├── lib/forge-std
│   ├── src/Interfaces.sol
│   └── test/PurrlendForkTest.t.sol
└── ci-log.txt / ci-artifacts/       # CI run logs/artifacts (after `ci-run.sh purrlend`)
```
