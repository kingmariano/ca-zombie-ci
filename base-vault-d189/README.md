# C2-02 — Unnamed Base credit vault `0xD1895f20…`: live-state assessment & extractable-value determination

**Campaign:** zombie-hunt II (C2-02) · **Chain:** Base (8453) · **Date of work:** 2026-10-05
**Status:** read-only research; all PoC/boundary tests fork-only (Foundry on Base forks, local + GitHub Actions). **No mainnet transactions were signed or sent.**
**Target:** vault `0xD1895f2019c2152FC2b9022D57f19198c4CFCABC` (impl `0x209d85f0ed5393f8f772d46bf889c251132a68bb`) — the Oct-4-2026 "$6M Base vault" incident target (1,783.067 aBaswstETH drained; publicly reported by Blockaid/PeckShield/CertiK/ExVul, no protocol has claimed it).

> Recovery note: the working folder was externally wiped on 2026-10-05 ~19:12 during the run (an independent child subagent working in the folder recovered the evidence it held from the CI snapshot). All deliverables here were restored/re-verified afterwards; the on-chain state was re-measured at a fresh block (`analysis/live_state_final.json`).

---

## TL;DR

| # | Surface | Live extractable now | Why open/closed | Confidence |
|---|---|---|---|---|
| 1 | **Fresh external unprivileged attacker** (any EOA/contract, no keys, no whitelist) | **$0** | Every value-moving entry point is whitelist- or owner-gated: `borrow`/`repay` → `!W`, `withdraw` → `!WWE` (everyone), helper `__withdraw`/`cb984317`/`__redeem` → `!O2`, owner setters/proxy upgrade → `Ownable`. A real copycat EOA tried the exact borrow path twice on 2026-10-05 and reverted `!W`. Independently re-verified by the child agent across all 24 vault / 8 helper / 27 sibling / 31 account-contract selectors. | **high (0.9)** |
| 2 | **Original attacker's residual capability** — helper `0xcdFE9130…` is *still whitelisted* | **$22.39–22.50M** zero-capital, **$23.91M** net with the full-equity route (borrow→inject→repay→borrow) | `whitelist(helper)==true`, `minHealth()==0`; helper `__withdraw` is owner-gated to the attacker EOA `0x0B5126e1…`, who also owns the helper's ProxyAdmin (can upgrade it to call any whitelisted vault function). Bound = Aave `finalizeTransfer` HF≥1. | **high** |
| 3 | **Privileged: owner Safe `0x6b27512a…` (3-of-7)** | same **$22.4–23.9M** at will | **The Safe is exempt from the borrow whitelist** — `vault.borrow` from the Safe succeeds directly (verified). It can also `whitelist(addr,1)`, `transferOwnership`, owner-withdraw (`76309d0e`, verified live). This is exactly how the Oct-4 incident was executed (Safe txs at blocks 52,157,298/342). | **high** |
| 4 | **Privileged: ProxyAdmin Safe `0x47a60e3D…` (3-of-8)** | full **$31.85M** Aave position + logic | Aave BGD `ProxyAdmin.upgrade(proxy,impl)`/`upgradeAndCall` is owner-gated; owner is a 3-of-8 Safe. | **high** |
| 5 | **Other live whitelisted borrowers** — 33-address vault whitelist: the helper + EOA `0x3E68796A…` + **31 protocol account contracts** (12 impls) | up to the same **$22.4–23.9M** (non-additive; shared HF bound) if any owner key/account is compromised | The 31 account contracts are owner/`!G`-gated (individually probed); the EOA is a user whose key carries borrower capability. Key-custody risk, not a fresh path. Sibling whitelist: 92 contracts, 0 EOAs. | **high** |
| 6 | **Holder/user-only recovery (H-O)** | **$0** | `withdraw()` reverts `!WWE` for *every* caller including the owner Safe and whitelisted addresses; no share token / redemption path found. | medium-high |
| 7 | **Sibling vault `0x416Ec2cA…`** (same owner Safe; holds ≈**$7.0M** directly: AERO $3.84M, VIRTUAL $1.11M, ZEN $0.58M, cbLTC $0.23M, USDT $0.16M, cbADA $0.15M, cbBTC $0.14M, EURC $0.09M, …) | **$0 found** | `whitelist(helper/copycat)==false`; `borrow`/`withdraw` revert `!W` for fresh callers; 92 whitelisted accounts all gated; dormant since block 46.58M. (Hygiene note: the sibling *impl*'s `initialize(address,address)` is callable but impl storage is isolated and holds no funds.) | medium-high |

**Total live extractable by a fresh external unprivileged attacker: $0 (high confidence, 0.9).**
**Live exposure that remains open today: ≈$22.4–22.5M (zero-capital) / $23.91M net (full-equity) to the already-whitelisted attacker helper, and equivalent amounts to the owner-Safe privileged role. This is residual/privileged, not fresh-unprivileged.**

---

## 1. What the target is

The vault is an **Aave-v3-style credit façade** on Base, deployed 2025 (block 26,107,572, creator `0x4fF634EF…`) and upgraded five times (last impl upgrade block 45,628,440). It is a `TransparentUpgradeableProxy`; implementation `0x209d85f0…` is **unverified** (heimdall/evmole decompilation + behavioural traces used throughout). It holds its own Aave v3 position and lends the resulting **aTokens** to whitelisted borrowers.

Decompiled/selector-verified interface (all live-verified):

| Selector | Function | Gate (live) |
|---|---|---|
| `0x617ba037` | `supply(address,uint256,address,uint16)` | **open**, but pulls the *caller's* tokens (no payout) |
| `0x69328dec` | `withdraw(address,uint256,address)` | `!WWE` — reverts for everyone (fresh, whitelisted, even the owner) |
| `0xa415bcad` | `borrow(address,uint256,uint256,uint16,address)` | `whitelist[msg.sender]` **or owner** else `!W` |
| `0x573ade81` | `repay(address,uint256,uint256,address)` | `whitelist[msg.sender]` else `!W`; repays **from the vault's own token balance** |
| `0x38edc837` | whitelist setter `(address,uint256)` | `owner` else `Ownable: caller is not the owner` |
| `0xd2b2de5b`, `0x6b711cc9`, `0x76309d0e`, `0x4abb8b6f`, `0x698442db` | owner setters / owner Aave-withdraw / clear / complex | `owner` |
| `0xc4d66de8` | `initialize(address pool)` | already initialized |
| views | `owner`, `pool`, `minHealth`, `whitelist`, `minToken`, `aToken`, `debtToken`, `getUserReserveData`, `getReserveConfigurationData`, `supplyAmount`, `borrowAmount` | — |

The `borrow` path is: `whitelistedCaller → vault.borrow(asset, amount, 0, 0, receiver) → aToken.transfer(receiver, amount)`. There is **no callback to the receiver** (aToken transfers call only Aave's `finalizeTransfer` + rewards/oracle STATICCALLs), so no reentrancy surface for a non-whitelisted party.

## 2. Incident summary (Oct-4-2026) — how the whitelist was obtained

- 52,154,795 — attacker EOA `0x0B5126e1bc27C0de77e02e97945760A674EdB034` deploys helper proxy `0xcdFE91301356da873562EF513828a60dba1F569d` (impl `0x5d7a3814…`, also attacker-deployed; helper ProxyAdmin `0x3065d790…` owned by the same EOA).
- 52,156,053 — helper `initialize()`.
- **52,157,298 — owner Safe executes `whitelist(helper, 0)`** (tx `0x27cbab36…`, revoke).
- **52,157,342 — owner Safe executes `whitelist(helper, 1)`** (tx `0xed265fc8…`, grant) — 44 s later.
- 52,157,377 → 52,158,062 — six `helper.__withdraw` borrows, totalling **1,783.067 aBaswstETH** to the helper: `0x0ec75c3b…` (1.0), `0xa08b0267…` (100), `0xf1c9448c…` (182.067), `0x08327097…` (500), `0x212dc5e0…` (500), `0x327e47ad…` (500).
- Public reporting (CryptoTimes, Blockonomi, news.bitcoin.com, ExVul): ~$6M lost; both Safe transactions carried **valid signatures**; analysts attribute it to compromised signer keys or a manipulated approval path. No timelock between whitelisting and borrowing.
- The independent child decoded all 258 owner-Safe `execTransaction` payloads: the setter history is 14 direct owner#1 calls + 24 Safe exec calls (23 grants + the helper revoke/grant pair); nothing else touches the whitelist.

**The incident is a privileged-path compromise + missing timelock, not a code bug.** The attacker's helper was never de-whitelisted afterwards.

## 3. Live-state assessment (block 52,213,000; re-verified at 52,214,619, 52,215,826 and re-measured at 52,218,505)

| Check | Value |
|---|---|
| Vault code / impl | proxy `0xD1895f20…`, impl `0x209d85f0…` (unverified, 9,091 bytes) |
| Vault owner | Safe `0x6b27512a5943Ed327f6cb6C3EC1f0398229f42C4` — **3-of-7**, `getModulesPaginated=[]`, guard slot 0 |
| ProxyAdmin `0x490ca969…` owner | Safe `0x47a60e3D6121B216cD22984df5976a41e15baF77` — **3-of-8**, no modules/guard |
| `minHealth()` / `minToken(WETH)` | `0` / `10e18` |
| `whitelist(attacker helper)` | **true** (unrevoked) |
| Vault whitelist size | **33 addresses** (helper + EOA `0x3E68796A…` + 31 protocol account contracts; 12 impls; only 2 ever revoked) |
| Sibling whitelist size | 92 contracts, 0 EOAs |
| `whitelist(copycat helper 0x13Fed… )` | false |
| `whitelist(attacker EOA)` | false; **owner Safe is exempt from the gate** (`borrow` from Safe → OK) |
| Vault aWETH balance | **11,761.285370638167 aWETH** at 52,213,000 (11,761.344615865677 at 52,218,505) (+0.000665 awstETH dust) |
| Vault Aave position | collateral **$31,774,368.63**, debt **$7,760,266.23**, aggregate LT 82.99 %, WETH LT 83.00 %, **HF 3.398** (52,213,000) |
| Debt composition | USDC 7,249,4xx + cbBTC 2.36946197 + EURC 275,766.87 (variable debt) |
| aTokens held | aWETH only (material); all other Aave reserves 0 |
| Helper state | proxy `0xcdFE9130…` → impl `0x5d7a3814…`; owner `0x0B5126e1…`; initialized; holds no aWETH |
| Copycat attempt | EOA `0x0820DC0c…` deployed proxy `0x13Fed10846B5…` (impl `0x965A9a77…`) and called `callBorrow(aWETH, MAX)` at blocks 52,210,655 / 52,210,663 → both **reverted `!W`** |
| Vault upgrades | `0x6Ba0A6A2…` → `0xe90fAf38…` → `0xBae563E6…` → `0x06b0d5a7…` → `0x209d85f0…` (last at 45,628,440) |

**Latest re-check at block 52,218,505** (`analysis/live_state_final.json`): `whitelist(helper)=true`, `whitelist(0x3E68…)=true`, helper aWETH balance 0 (no drain in progress), aWETH 11,761.344615865677, Aave collateral $31,854,363.37 / debt $7,760,965.12 / HF 3.4067, max additional borrow **8,308.908767478480 aWETH = $22,503,802.81** (ETH $2,708.39). Nothing has been revoked since the incident.

## 4. What a fresh unprivileged attacker can and cannot do

Every candidate path was tested at the pinned block via `eth_call`/`debug_traceCall`, reproduced in Foundry fork tests, and independently re-probed by the child agent across all selectors:

| Attempt (fresh caller) | Result |
|---|---|
| `vault.borrow(aWETH, x, 0, 0, fresh)` | revert `!W` |
| `vault.borrow(aWETH, x, 0, 0, helper)` (whitelisted receiver) | revert `!W` → **gate is on `msg.sender`** |
| `vault.withdraw(WETH/aWETH, x, fresh)` | revert `!W` |
| `vault.repay(...)` | revert `!W` |
| `vault.supply(WETH, x, fresh, 0)` | revert `SafeERC20: low-level call failed` (needs the caller's own tokens; no payout path) |
| `helper.__withdraw` / `cb984317` / `__redeem` | revert `!O2` (not owner) |
| `helper.initialize()` / `vault.initialize(pool)` / sibling impl `initialize` | `already initialized` (sibling impl is isolated — harmless hygiene note) |
| `vault.transferOwnership/renounceOwnership`; all owner setters | `Ownable: caller is not the owner` |
| `ProxyAdmin.upgrade(proxy, impl)` / `upgradeAndCall` / `changeProxyAdmin` (both ProxyAdmins) | `Ownable: caller is not the owner` |
| Proxy `admin()` / `implementation()` | revert (non-admin) |
| All three Safes' modules/guards | none (no module attack surface) |
| Borrow-callback / reentrancy | none — only `aToken.transfer` (Aave `finalizeTransfer`); no receiver callback |
| Storage collision (impl writes slots 0/0x33/0x65–0x6c vs EIP-1967 slots) | none |
| Allowances / Aave `borrowAllowance` (vault→helper/fresh/Safe/whitelisted EOA) | 0 — no credit delegation |
| 31 whitelisted protocol account contracts (all public fns, 12 impls) | `Ownable`/`!G`; one read-only `255617e7()` STATICCALLs; no third-party-triggerable borrow/withdraw |
| Sibling `0x416Ec2cA…` borrow/withdraw from fresh/helper; extra fns | revert `!W` / `Ownable`; `whitelist(helper/copycat)==false` |

**Conclusion: fresh external unprivileged extraction is $0. The only ways in are a whitelist entry / owner role (privileged), the owner-Safe exemption, or one of the 33 already-whitelisted addresses' keys/owners (residual/key-custody).**

## 5. Residual capability — exact maximum (the headline exposure)

The still-whitelisted helper can move value up to **Aave's own health bound**. Each borrow is an `aToken.transfer` out of the vault; Aave's `finalizeTransfer` reverts with `HealthFactorLowerThanLiquidationThreshold()` (`0x6679996d`) when the transfer would push the vault's HF below 1.

**Zero-capital bound (fork-proven, CI-verified; moves with the ETH price):**

| Block | aWETH balance | max additional borrow | USD (oracle) |
|---|---|---|---|
| 52,213,000 (local, pinned) | 11,761.285370638167 | **8,300.486481076223 aWETH** | **$22,424,649.21** (ETH $2,701.61) |
| 52,214,619 (CI run #1 state dump) | 11,761.302822883363 | **8,289.798958759297 aWETH** | **$22,325,983.56** (ETH $2,693.19) |
| 52,215,826 (CI run #2, fork) | 11,761.315821863511 | **8,296.719736902052 aWETH** | **$22,389,599** (ETH $2,698.61) |
| 52,218,505 (post-wipe re-measure) | 11,761.344615865677 | **8,308.908767478480 aWETH** | **$22,503,802.81** (ETH $2,708.39) |

The boundary is exact to 0.001 aWETH (binary search; the next wei fails with `0x6679996d`). Closed form: `max = aWETH_balance − debt_usd / LT_WETH / price` (LT_WETH = 8,300 bps; the empirical result matches theory to <1% in the fork test). The vault keeps ≈3,450 aWETH as collateral for the debt at HF=1. Costs: gas only — a full `__withdraw` borrow costs ≈0.42–0.48M gas (fork-measured), i.e. cents on Base; no flash loan or external capital is needed for the zero-capital route.

**Full-equity bound (fork-proven, `test_residual_full_equity_path`):** the helper is whitelisted for `repay` too, and the vault's `repay()` consumes the token balance **held by the vault**. A two-stage route therefore unlocks the whole net equity:

1. borrow the ~8,300 aWETH (no capital needed);
2. redeem/swap part of it and transfer the debt tokens (USDC + cbBTC + EURC, ≈$7.76M) **directly to the vault** (plain ERC-20 transfer; `supply` also works as a donation);
3. as the whitelisted helper call `vault.repay(asset, debt, 2, vault)` → the vault's Aave debt is cleared (verified: all three debt tokens → 0, pool account debt → 0);
4. borrow the remaining ~3,460 aWETH (no debt → no HF bound).

Fork result (CI run #2, fork block 52,215,826): **11,736.315821863511 aWETH taken of 11,761.315821863511 (25 aWETH left), gross $31,671,722.81, repaid $7,760,536.88 (USDC $7,249,425.12 + cbBTC $202,142.49 + EURC $308,969.27) → net $23,911,185.93.** Swap spread on the ~$7.8M conversion (~0.1–0.3%) is not modelled and is economically negligible versus the ~$1.5M gain over the zero-capital route. The attacker can also upgrade the helper (they own its ProxyAdmin) to script any whitelisted call sequence.

**Other whitelisted addresses:** EOA `0x3E68796A…` can borrow to the same bound (verified live). The 31 protocol account contracts are owner-gated (no third-party trigger), but their owners could borrow if compromised. All of these share the same non-additive HF bound — the total extractable across the whole whitelist is bounded by the vault's net equity (~$23.9M).

## 6. Privileged paths (P)

- **Owner Safe `0x6b27512a…` (3-of-7)** is **exempt from the borrow whitelist** (verified: `vault.borrow` from the Safe succeeds) and can `whitelist(any,1)`; `transferOwnership`; owner-withdraw `76309d0e(asset, amount)` (verified live: `76309d0e(WETH, 1e18)` from the Safe succeeds and pulls from the vault's Aave position; it reverts for non-owner callers); `698442db`. This is precisely the class of path the Oct-4 incident used (revoke+re-grant with valid signatures).
- **ProxyAdmin Safe `0x47a60e3D…` (3-of-8)** can `upgrade(vault, newImpl)` — full control of the vault's $31.85M Aave position and of all logic (including making `withdraw` payable to anyone).
- No timelock on either path.

## 7. H-O / S

- **H-O = $0**: `withdraw()` reverts `!WWE` for *all* callers (fresh, whitelisted EOA, helper, and the owner Safe itself). No share token or redemption function was found; `supply()` gives the vault the tokens with no observable claim. Users therefore have no self-service recovery; recovery is owner-mediated.
- **S = $0**: funds are not bricked — the owner Safe, the attacker helper and the other whitelisted addresses can still move value.

## 8. PoC / fork verification

Foundry project `poc/` (forge-std vendored). Run: `BASE_RPC_URL=<base rpc> forge test`.

**15 tests, 15 PASS** (CI fork block 52,215,826; also run locally on Base forks):

| Test | Proves |
|---|---|
| `test_state_live` | whitelist/owner/minHealth/minToken/balances as reported |
| `test_fresh_direct_borrow_reverts` / `..._with_whitelisted_receiver_reverts` | `!W` gate on `msg.sender` |
| `test_fresh_withdraw_and_repay_revert`, `test_fresh_supply_cannot_move_vault_funds` | all other entry points closed |
| `test_fresh_helper_functions_revert`, `test_fresh_vault_owner_functions_revert`, `test_fresh_proxy_upgrade_reverts` | helper/owner/proxy all gated |
| `test_attacker_residual_path_works` | helper `__withdraw` still moves aWETH live |
| `test_residual_max_borrow_boundary` | exact HF bound + `0x6679996d` + theory match |
| `test_residual_full_equity_path` | borrow→inject→repay→borrow drains the net equity (net $23.91M) |
| `test_whitelist_revocation_closes_residual` | owner `whitelist(helper,0)` closes the path (`!W` after) |
| `test_privileged_safes` | 3-of-7 owner Safe, 3-of-8 ProxyAdmin Safe, no modules, helper admin = attacker EOA |
| `test_sibling_no_fresh_path` | sibling funds + `!W` gates |
| `test_copycat_helper_not_whitelisted` | real-world copycat reverted |

**Independent child verification** (`analysis/independent_freshpath_review.md`, 53 lines): all 24 vault, 8 helper, 27 sibling selectors and all 12 whitelisted-account impls probed from a fresh address on 3 RPCs; fresh-path verdict NONE FOUND, confidence 0.9; found the 33-address vault whitelist / 92-address sibling whitelist and the owner-Safe borrow exemption; checked storage collisions, allowances, Aave `borrowAllowance`, reentrancy/callbacks, ProxyAdmins, Safe modules/guards.

CI runs (public repo `kingmariano/ca-zombie-ci`):
- Run #1 (14/14 PASS, first suite): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37343140462
- **Run #2 (15/15 PASS incl. full-equity test): https://github.com/kingmariano/ca-zombie-ci/actions/runs/37347998019**
- Run #3 (re-validation after the folder wipe; restored artifacts): see `ci-links.md`
- Independent state dumps: `ci-artifacts/result-base-vault-d189/ci-out/state.json` (run #2: max 8,296.719572667618 aWETH = $22,389,598.79 at block 52,215,770, `next_fail_revert_prefix = 0x6679996d`, fresh paths `REVERT:!W`); `analysis/live_state_final.json` (post-wipe: max 8,308.908767478480 aWETH = $22,503,802.81 at block 52,218,505).

## 9. Verdict and residual/latent risk

- **Fresh external unprivileged extractable: $0 (high confidence, 0.9).** The whitelist is a hard gate; a real copycat attempt failed on-chain on Oct 5; every selector was re-probed independently.
- **Live unrevoked exposure: ≈$22.4–22.5M zero-capital / $23.91M net (full-equity) to the original attacker's helper** — simply because `whitelist(helper)` was never set back to 0 after the incident. The helper's `__withdraw` is owner-gated to the attacker EOA and the helper's ProxyAdmin is attacker-owned, so the capability is fully under the attacker's control.
- **Privileged equivalents:** owner Safe 3-of-7 (borrow-exempt + whitelist) and ProxyAdmin Safe 3-of-8 (upgrade → $31.85M position) — both demonstrated as attack-relevant by the incident itself. No timelock.
- **Key-custody surface:** 33 whitelisted addresses (helper + 1 EOA + 31 gated account contracts; sibling: 92). Any owner-key compromise converts to the same (non-additive) $23.9M bound.
- **Remediation (one call):** owner Safe → `whitelist(0xcdFE9130…, 0)` and prune the whitelist (33 entries, incl. `0x3E68796A…`); then move the Aave position out and/or upgrade to an implementation with a timelock and no standing borrower whitelist. Until then the exposure is live.
- **Latent risk:** a re-whitelisting of any address (or a Safe-key compromise, as happened) re-opens the full amount; the `!WWE` withdraw block also means legitimate users have no exit independent of the owner.

## 10. Methodology, sources, caveats

- **Method:** live `eth_call`/`debug_traceCall`/`debug_traceTransaction` at pinned Base blocks (52,213,000 / 52,214,619 / 52,215,826 / 52,218,505); storage-slot reads for proxy admin/impl; heimdall + evmole decompilation/selector extraction; Blockscout v2 API pagination for incident/tx/caller enumeration; Etherscan V2 for source/ABI; owner-Safe `execTransaction` payload decoding for the full whitelist setter history; public reporting for incident corroboration.
- **Sources:** CryptoTimes 2026-10-04 "Base Vault Hack: $6M…"; Blockonomi; news.bitcoin.com "7 Mystery Signers"; CryptoTicker 2026-10-05 (08:52/08:53 UTC Safe sequence); ExVul X post (1,783.067 aBaswstETH across six outflows).
- **Caveats:** the impl is unverified — analysis is decompilation + behaviour, not source review; USD figures move with the ETH price (the bound is aWETH-denominated — $22.33–22.50M across blocks); the full-equity test models the debt-token injection with `deal()` (production: swap + direct transfer, spread ~0.1–0.3%); the vault has no public attribution; "H-O" is inferred from the absence of a working withdraw/share path; the working folder was externally wiped mid-run and restored (state re-measured afterwards).
- **Files:** `summary.json`, `ci-links.md`, `analysis/state_measurement.json`, `analysis/live_state_final.json`, `analysis/ci_run2_state.json`, `analysis/incident_timeline.md`, `analysis/whitelist_verified.json`, `analysis/independent_freshpath_review.md` (independent child review), `analysis/vault_impl_decompiled.sol`, `analysis/vault_caller_enum.txt`, `analysis/matrix_results.json` + `analysis/account_probes.json`, `poc/test/BaseVaultD189.t.sol`, `poc/foundry.toml`, `ci/run.sh`, `ci-log.txt`, `ci-artifacts/`.
