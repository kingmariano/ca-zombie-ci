# H2-05 — EOS / misc custody with key or trust risk: live extractable-value assessment

**Campaign:** zombie-hunt II (H2-05) · **Chains:** EOS (Vaulta), Plasma, TRON, Fluent, STRATO (probe) · **Date of work:** 2026-10-10
**Status:** read-only research; no transactions signed or sent on any chain; all evidence from public endpoints; CI re-verification job `ci/verify_eos.py`.
**Scope (7 targets):** WhaleEx/`whaleextrust` (EOS), CHATEAU chUSD (Plasma), DMD Finance (EOS), Vigor (EOS), JustLend V2 (TRON), STRATO ($16M claim), Vena Finance (Fluent).

**TL;DR — an external, unprivileged attacker can currently extract ≈ $0 from every target.** Every value path is either (a) gated by `require_auth` of the account whose funds move (EOSIO), (b) role/minter-gated with no permissionless mover, or (c) unreachable/unverifiable. The residual value is either key-controlled (P) or self-service-withdrawable by its holders (H-O). The one target with a genuinely suspicious decompile lead (DMD `exit(from)`/`claim(from)`) was fully decompiled and **both handlers begin with `require_auth(from)`** — an unprivileged attacker cannot pass an arbitrary `from`.

| # | Target | Chain | Live value | E-U (unprivileged) | Why closed / gate | Class of residual |
|---|---|---|---|---|---|---|
| 1 | WhaleEx / `whaleextrust` | EOS | $3.65M face (2,426,381.86 USDT + 14.8007 BTC IOUs) | **$0** (high) | trust contract has one non-value action (`clearextsym`, self-auth); token `transfer` requires `auth(from)`; `issue`/`retire` require issuer (`tokens.wal`, single key) | **P** $3.65M — single master key `EOS5GF3Uzz…` controls entire infra; IOUs ~unbacked on-chain |
| 2 | DMD Finance pools 11/12/13 | EOS | ≈$140.2k (135,410.84 USDT + 44,728.49 EOS + 75,235.91 OGX) | **$0** (high) | `exit(from)`/`claim(from)` decompiled: both start `require_auth(from)`; `init`/`harvest`/`harvest2` require `eosdmdworker`; no admin withdraw | **H-O** $140.2k self-withdraw; **P** latent via 3-of-4 owner `setcode` |
| 3 | CHATEAU chUSD | Plasma | $1,024,179.89 chUSD claims vs **$77.24 USDT0** collateral | **$0** (high) | `mint()` minter-gated; `ChateauMinting.mint/redeem/transferToCustody` all revert missing AccessControl roles for strangers (live `eth_call` sims) | **P** $77.24; holder exposure $1.02M is custodial (on-chain shortfall $1,024,102.65) |
| 4 | Vigor | EOS | $123,424.71 (PBTC/PETH/USDT/VIGOR/…) | **$0** demonstrated (conditional ≤$150) | `bailout`/`kick`/`returncol`/… all `require_auth(vigorlending)`; only `tick` permissionless (no caller value); frozen-oracle borrow path capacity-bounded | **H-O** $119,635; **P** $122,425 (DAC 4-of-7); **S** $14,002 nominal |
| 5 | JustLend V2 ("Moolah") | TRON | **$1,699,173.53** measured (sTRX $735.0k + BTC $425.8k + WTRX $326.2k + USDT $128.5k + USDD $83.7k; DefiLlama $1,698,609) | **$0** (medium) | Morpho-Blue fork: `liquidate()` whitelist-gated to 2 liquidator contracts; user flows standard self-service accounting; no empty-market asymmetry; not paused; no unguarded rescue in 105-entry ABI | **H-O** $1,699,173.53 (self-service, unpaused); **P** roles (ADMIN 1/MANAGER-OPERATOR 2/PAUSER 1 EOA) |
| 6 | STRATO / Mercata | STRATO (public L1, chain 123354377739506) | **$16,190,997.36** verified (GOLDST 3,213 ≈ $13.49M dominates; CDP CR 2.88×; debt $4.70M) | **$0** (medium-high) | 17/17 admin-function + 8/8 free-money simulations from a random address revert; SolidVM contracts readable but source unpublished | **H-O** ≈$10.64M user positions; **P** whole suite under AdminRegistry (3 admin EOAs, 60% threshold, `setLogicContract` upgrades) |
| 7 | Vena Finance | Fluent | $9,175,475.67 (aTokens) | **$0** (medium) | stock Aave-v3 fork; oracle = Pyth-Lazer signed + role-gated + 60s staleness; ACL on Timelock/Safe; `rescueTokens` onlyPoolAdmin | **H-O** $9.18M self-service withdrawals (USDnr utilization-bound) |

**Total live E-U found: $0.00** (all 7 targets; the only conditional exception is Vigor's frozen-oracle borrow path, bounded to ≤~$150 net, low-medium confidence and not demonstrated). Per-target confidences: high for WhaleEx/DMD/CHATEAU/Vigor auth gates, medium-high for STRATO (behavioral verification, no source published), medium for JustLend V2 and Vena (surface passes). Total holder-recoverable (H-O) across targets ≈ **$21.78M**.

---

## 1. WhaleEx / `whaleextrust` (EOS) — E-U $0, P $3.65M

[full dossier: `analysis/whaleex/DOSSIER.md`]

- Live balances (EOS head **524,644,740**, 2026-10-10T11:57:10Z, `https://eos.greymass.com`): `whaleextrust` holds **2,426,381.86411885 USDT** and **14.80068211 BTC** on `tokens.wal` (exchange IOUs; face ≈ $3,652,071.86 at BTC $82,817). Plus 48 other tokens (WAL 718.8M, etc. ≈ $0).
- Contract audit: `whaleextrust` WASM (sha256 `e1f01c19…ea8b`) has **one action** `clearextsym(account)` whose handler is `require_auth(account)` + deletes `extsymbolref` rows — **no token movement**. Token contract `tokens.wal` (sha256 `a8667849…e5a4`, byte-identical to `whaleextoken`) is an eosio.token fork: `transfer` → `require_auth(from)`; `issue`/`retire`/`recreate` → `require_auth(stat.issuer)`; `close` → owner; blacklist → issuer.
- Key structure: `whaleextrust` owner = active = **one key** `EOS58SzHx…`; `tokens.wal`/`whaleextoken`/`whaleexdebit`/`whaleexgate4`/`whaleexgate5`/`namebid.wal`/`tianshu.eos`/`eosdefiproxy` all share owner key `EOS5GF3Uzz…` → single point of failure (key-compromise exposure, not E-U).
- Backing: `tokens.wal` account holds only 216.52 USDT + 0.100001 BTC real; the IOUs are custodial claims on off-chain reserves. Exchange dormant since 2025-08-17.
- **E-U $0 (high)**; P $3.65M face (single-key spendable/burnable); H-O $0; S $0.

## 2. DMD Finance (EOS) — E-U $0, H-O $140.2k

[full dossier: `analysis/dmd/DOSSIER.md`]

- Pools `eosdmdpool11` (44,728.4875 EOS), `eosdmdpool12` (**135,410.8398 USDT, real tethertether**), `eosdmdpool13` (75,235.9113 OGX) ≈ **$140,207** total; `stakepool.total_staked` equals the contract balances exactly (no shortfall).
- Permissions: active = `self@eosio.code` only (no keys); owner = threshold 22 = **3-of-4** (`eosdefiadmin` 20 + any 2 of `eosnationftw`/`itokenpocket`/`slowmistiobp`).
- Decompiled WASM (pinned sha256 `d878289a…0dbb` etc.): ABI `init/claim/exit/harvest/harvest2`; `exit(from)` and `claim(from)` handlers both begin **`local.get 1; require_auth`** (require_auth(from)); `init`/`harvest`/`harvest2` require **`eosdmdworker`** (single-key admin); deposits credited only via genuine token-transfer notifications from whitelisted token contracts. Payout inline transfer sends **to the authenticated `from`**, and the stake row is removed (`db_remove_i64`) — no double-withdraw.
- **E-U $0 (high)**; H-O $140.2k (users `exit(from)` their own stake; pools dormant since 2024-07-19); P $140.2k latent (owner 3-of-4 `setcode`); S $0.

## 3. CHATEAU chUSD (Plasma, chain 9745) — E-U $0

[full dossier: `analysis/plasma_fluent/DOSSIER.md`]

- Pin: Plasma block **34,691,115**; RPC `https://rpc.plasma.to`. chUSD token `0x22222215d4EdC5510d23D0886133E7ece7F5fdC1` (verified), `ChateauMinting` `0xEA6709C29d4D4B5162d8C55D0c28C5CED6cd7296` (unverified; ABI reconstructed + sims), USDT0 `0xB8CE59FC…F625ebb`, owner Safe 2-of-3 `0x478F78c4…`.
- Live: `chUSD.totalSupply` = 1,024,692.236 chUSD ≈ $1,024,179.89; collateral = **77.307860 USDT0 ($77.24)**; on-chain shortfall **$1,024,102.65 (99.99%)**. Lifetime flows show $431,243.65 USDT0 in / $431,166.34 out — issuance was never fully on-chain-collateralized (custodial settlement).
- Gates (live `eth_call` from unprivileged addresses): `redeem(order,sig)` reverts missing `REDEEMER_ROLE`; `mint(order,route,sig)` reverts missing `MINTER_ROLE`; `transferToCustody` missing role (Safe holds it); no sweep/rescue selector in the 42-selector dispatch; chUSD `mint` only by minter; `burnFrom` needs allowance.
- **E-U $0 (high)**; H-O $0 (redemption is operator-submitted); P $77.24; holder/trust exposure $1.02M nominal (unbacked on-chain). Last activity 2026-09-08.

## 4. Vigor (EOS) — E-U $0 (≤$150 conditional)

[full dossier: `analysis/vigor/DOSSIER.md`]

- Pin: EOS head **524,653,327** (2026-10-10T13:08:44Z). Contracts: `vigorlending` ($113,233.53 physical), `vigorstaking` ($10,191.17), `vigortoken11` (VIGOR), `vig111111111` (VIG), `vigoraclehub`, `dactoken1111`/`daccustodia1`/`dacauth11111` (DAC authority).
- Auth map (decompiled WASM, sha256 `63e8641f…`): `bailout`/`bailoutup`/`kick`/`returncol`/`returnins`/`cleanbailout`/`doupdate`/`setconfig`/… all `require_auth(vigorlending)` (P); `assetout`/`acctstake`/`deleteacnt` self-auth; `liquidate` self-or-contract; only `tick` is permissionless (cron trigger, no caller value); `openaccount` permissionless after `memberreg`. Empirical: all 11 bailouts + 2 kicks since 2026-08-25 executed with `[vigorlending@active]`.
- Live books: H-O **$119,635** (user claims covered by physical tokens: PBTC 98.4%, PETH 95.7%, USDT 91.9%, VIG/VIGOR 100%; staking withdrawals proven on-chain); S ≈ **$14,002** nominal (EOS claims 0.05% backed); P = $122,425 (DAC 4-of-7 authority).
- Conditional E-U: oracle frozen at 2025-04-03 (EOS 7.8×, VIG 22.7×, VIGOR 7.2× overvalued) + permissionless accounts + self-borrows → bounded by pool availability to **≤ ~$150 net** (low-medium confidence; cannot dry-run). No auth bypass found.
- **E-U $0 demonstrated** (conditional ≤$150); H-O $119,635; P $122,425; S $14,002.

## 7. Vena Finance (Fluent, chain 25363) — E-U $0

[full dossier: `analysis/plasma_fluent/DOSSIER.md`]

- Pin: Fluent block **17,863,118**; RPC `https://rpc.fluent.xyz`. Pool proxy `0xD6E69976…4013` (impl "Pool", Aave v3 fork), provider `0xf5569e98…`, ACL `0x18797a36…`, oracle `0xC3Be4DDD…`.
- Live custody in aTokens: 545,341.40 USDnr + 8,457,557.20 sUSDnr + dust WETH = **$9,175,475.67** (matches DefiLlama ≈$9.18M).
- Gates: oracle = Pyth-Lazer adapters (`updatePrices` onlyRole + signature verify + 60s staleness; no forgeable path); ACL roles held by TimelockController `0x2799ea13…` / emergency Safe; `rescueTokens` onlyPoolAdmin; stock Aave v3 surface, no custom value mover.
- **E-U $0 (medium** — fork not byte-diffed vs upstream); H-O $9.18M (self-service withdrawals; USDnr liquidity utilization-bound); P $0; S $0.

## 5. JustLend V2 ("Moolah", TRON) — E-U $0

[full dossier: `analysis/tron/DOSSIER.md`]

- Core `MoolahProxy` `TDH4dhmVQQNc1ZNudJwWzBcs2h6ahhWrpp` (impl `TKEiKtSaqUboeBmZxcSp8Z2CJUDGk4BT3a`, name "Moolah"; Morpho-Blue fork, 9 markets, all LLTV 80%, one oracle `TUDXEUA6…`, one IRM `TSsuwbvU…`; created 2026-04-07; source unverified). Reads at blocks 86,991,072–86,991,223.
- Located value: **$1,699,173.53** = sTRX $735,009.59 + BTC $425,764.98 + WTRX $326,185.28 + USDT $128,543.75 + USDD $83,669.92; ≈ DefiLlama TVL $1,698,609.42 (Δ0.03%); borrows $515,216 ≈ DefiLlama $515,329.63. Core `paused()=false`; fee 10%; roles: ADMIN 1 EOA, MANAGER/OPERATOR 2, PAUSER 1; feeRecipient `TMzGb5Ma…`.
- Key gate: `getLiquidationWhitelist(bytes32)` on live market `55e29973…c1a4` returns exactly two addresses — `TKX8nUY8…Wa6` (LiquidatorProxy) and `TGDuQaH…qJi` (PublicLiquidatorProxy) → **liquidations (the only path to others' principal) are whitelist-gated**; user flows are standard Morpho self-service accounting; no empty-market asymmetry; no unguarded rescue in the 105-entry ABI.
- **E-U $0 (medium)**; H-O $1,699,173.53 (self-service, unpaused); P = roles; S $0. Blockers: source unverified/partial ABI; oracle unaudited; PublicLiquidatorProxy permissionless lane unreviewed; no per-position health enumeration.

## 6. STRATO / Mercata — E-U $0

[full dossier: `analysis/strato/DOSSIER.md`]

- STRATO = **BlockApps "STRATO Mercata" public L1** (chain id **123354377739506**, Solidity-on-SolidVM; RPC `https://noderpc.strato.nexus/rpc`; explorer + Cirrus PostgREST index; 17 validators). The corpus "unverified native-contract chain" was a mislabel — behavior is fully readable; only *source* is unpublished. Reads at block **622,692**.
- The "$16M": DefiLlama `strato` TVL **$16,190,997.36** (category CDP), dominated by **3,213 GOLDST (tokenized gold) ≈ $13.49M** in the CDP vault; reconciled line-by-line (CDP vault ≈$13.62M incl. 3,134.63 GOLDST = $13.12M; SaveVault $1.71M; PSM $91k; debt $4.70M; CDP global CR 2.88×; oracle fresh).
- Unprivileged-path evidence: **17/17 admin-function gating simulations** revert (`"Only an admin or a whitelisted account…"` for mint/pause/upgrade/rescue) and **8/8 "free-money" simulations** revert (`Insufficient collateral`, `SM:not holder`, `Minting…disabled`, `asset missing`, `unsupported`).
- **E-U $0 (medium-high)**; H-O ≈$10,641,260 user positions (SaveVault $1.71M + CDP net equity $8.92M + CollateralVault/SafetyModule); P = whole suite under AdminRegistry `0x…100c` (3 admin EOAs, 60% threshold, `setLogicContract` upgrades; whitelisted price-bot/bridge/guardian EOAs); S $0. Blockers: unpublished source, key-governance tail risk, operator-gated bridge exits.

---

## Methodology, evidence & caveats

**Coverage.** EOS: full — every WhaleEx-related account found (13-account sweep) and every DMD pool (11/12/13) had its WASM decompiled and every action's authorization mapped; Vigor had all 25 ABI actions mapped. Plasma/Fluent: full per dossier (contracts, roles, live `eth_call` gate proofs). TRON: full delegated audit (Morpho accounting + liquidation-whitelist proof + located balances; medium confidence). STRATO: full delegated behavioral audit (17+8 live gate simulations, line-by-line TVL reconciliation; medium-high confidence, source unpublished).

- EOS reads via public `https://eos.greymass.com` (chain-native API) + Hyperion history; TRON/Plasma/Fluent/STRATO via public endpoints (per-child dossiers). Prices: CoinGecko/DefiLlama at 2026-10-10 (BTC $82,817, EOS $0.103867, OGX $0.00200586, USDT $1).
- EOSIO has no public dry-run endpoint; negative results are proven by (a) decompiled authorization maps on **pinned WASM hashes** and (b) the EOSIO protocol rule that `require_auth(X)` forces the transaction to carry `X@active|owner`. CI job `ci/run.sh` re-verifies **65/65 facts** (58 EOS: balances, permissions, code hashes, auth patterns; 7 Plasma/Fluent: chUSD supply/collateral/minter + Vena aToken balances) from public endpoints — runs: 38064813864, 38056256559, 38056143181, 38056003865, 38055808301, 38054029072 (all success; latest head in `ci-log.txt`, artifacts in `ci-artifacts/`).
- Caveats: WhaleEx IOUs are unbacked on-chain and the exchange is dormant → face value ≠ realizable value; DMD pools dormant 2+ years, reward tokens ≈ $0; H-O amounts assume `exit`/withdrawals remain callable (traced structurally, not state-simulated); Vigor's conditional frozen-oracle borrow is capacity-bounded and not demonstrated; JustLend V2 (medium) and STRATO (medium-high) rest on behavioral verification with unpublished sources — a source-level audit could still change those verdicts; STRATO's whole suite is upgradeable via `setLogicContract` under 3 admin EOAs (60% threshold) and the bridges have operator-gated exits (key-governance tail risk, P).
- **Incident note (data integrity):** at ~16:27 local the folder root (`README.md`, `summary.json`, `ci/`, `ci-out/`, `ci-log.txt`, `ci-artifacts/`) and the `analysis/{whaleex,dmd,plasma_fluent,vigor}` dirs were unexpectedly deleted by an unidentified process (the two active child sessions' dirs survived). Everything was recovered byte-for-byte from the public CI branch (`kingmariano/ca-zombie-ci@eos-misc`, last pushed state) and the final TRON/STRATO child outputs were preserved; no secrets were affected. Root cause not determined.
- Read-only; no transactions were signed or sent on any chain. No secrets in this folder.
