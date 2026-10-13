# Omm (ICON) — Research Report

**Date:** 2026-10-12 · **Author:** child research session (Omm deep-dive) · **Scope:** public/open sources only; measurement-only; no transactions.
**Method:** WebSearch, WebFetch, Wayback Machine CDX, GitHub REST API (unauthenticated; rate limit hit mid-session), raw.githubusercontent.com, GitHub commit patches, api.llama.fi. No secrets/keyed endpoints used.
**Artifacts:** raw fetched pages/JSON/source copies in `research/` (index at the end). Note: `git clone` of `omm-documentation` was attempted but timed out and produced nothing (GitHub API quota also exhausted); docs recovered via Wayback instead.

**Legend:** ✅ CONFIRMED (primary source URL given) · 🟡 STRONGLY INDICATED (secondary or indirect source) · ⚠️ UNVERIFIED · ❌ NOT FOUND

---

## TL;DR

1. **Source code:** Omm v1 (money market) is an **Aave-v1-style protocol written as Java SCOREs**, in `github.com/ommfinance/openmoneymarket-contracts` (org formerly `openmoneymarket`). Mainnet deployment artifacts (`*.zip` SCOREs) sit in `ommfinance/omm-scores` (pins the contracts repo at commit `897f4d4`). v2 (liquid staking) code is the `Staking` module of the same repo.
2. **2023 exploit ✅:** Jan 21 2023, 18 txns via a malicious contract; **$1,891,477.80** drained (sICX/IUSDC/USDS/bnUSD). Root cause: `LendingPoolImpl.redeem()` accepted an **arbitrary oToken address** and used an external call's return values (`reserve`, `amountToRedeem`) without whitelisting → redeem without deposit. Fixed Feb 2023 (PR #166; commits `009bd263`, `23974eeb`): redeem now takes the **reserve address** and resolves the oToken via `LendingPoolCore.getReserveOTokenAddress()`. **The live LendingPool ABI already shows the fixed signature** (`redeem(_reserve, _amount, _waitForUnstaking)`) — deployed contracts are post-fix.
3. **Second incident ❌:** No second smart-contract exploit of Omm found. DefiLlama hacks DB has exactly one Omm entry (2023-01-21, "Redeem Logic Flaw"). A **March 2024 BALN-market event** (near-100% utilization, forced admin liquidations, oBALN repayment via OIP-23) was a market failure handled by governance, not documented as an exploit.
4. **Docs ✅:** Recovered from Wayback (2021–2024 snapshots): all contract addresses, liquidation/LTV params, interest-rate params, staking pivot, sunset.
5. **Lifecycle ✅:** Exploit (Jan 2023) → emergency halt → community recovery, users made whole (OIP-16/17) → pivot to liquid staking with sICX team (OIP-18, mid-2023) → money market permanently "discontinued", supply/borrow disabled → OIP-22 (Feb 2024) launched Omm 2.0 liquid staking → OIP-24 (Jun 5 2025) sunset; reason: ICON L1's new direction (SODAX), liquid staking no longer needed → X profile states **Omm retired January 2026**.
6. **Audits ⚠️:** SlowMist audited the original money-market contracts (PDF referenced on docs; direct URL not recoverable). 2024 docs state liquid staking contracts were "audited by ICON community developers". DefiLlama counts 2 audits but links only the docs page. Repo contains `audit/issue-1..32-fix` branches — evidence of a 32-issue internal/external review round in Feb–Apr 2023 (auditor unnamed publicly).

---

## 1. Source repositories (task 1)

### 1.1 Repos ✅

| Repo | URL | Content | Matches deployed? |
|---|---|---|---|
| **openmoneymarket-contracts** | https://github.com/ommfinance/openmoneymarket-contracts (old org: `openmoneymarket/...`) | **Java SCORE sources** for all contracts: LendingPool, LendingPoolCore, LiquidationManager, PriceOracle, LendingPoolDataProvider, Staking, FeeProvider, FeeDistribution, RewardDistribution, libs/AddressProvider, libs/Score (interfaces) | **YES — primary source of the deployed contracts** |
| **omm-scores** | https://github.com/ommfinance/omm-scores | `mainnet/*.zip` deployed SCORE artifacts (`lendingPool.zip`, `lendingPoolCore.zip`, `liquidation-manager.zip`, `priceOracle.zip`, `delegation.zip`, `daoFund.zip`, `governance.zip`, `ommToken.zip`, `o-token.zip`, `d-token.zip`, `feeProvider.zip`, `lending-pool-data-provider.zip`, `stakedLP.zip`, `address-provider.zip`, `workerToken.zip`) + `dummy/` test SCOREs; submodule pin `openmoneymarket-contracts @ 897f4d4eac00b0376ec466c29d03ded6ff7102fb` | YES — build/deploy artifacts |
| **openmoneymarket-mono** | https://github.com/ommfinance/openmoneymarket-mono | "openmoneymarket mono repo" (Python; tooling) | Ancillary |
| **omm-liquidation-bot** | https://github.com/ommfinance/omm-liquidation-bot | Python liquidation bot (updated Dec 8 2022) | Ancillary |
| **office frontends** | https://github.com/ommfinance/openmoneymarket-frontend · https://github.com/ommfinance/omm-liquid-staking-frontend | App UIs (v1 markets / v2 staking) | Ancillary |
| **omm-documentation** | https://github.com/ommfinance/omm-documentation | Docs site source (HTML, MIT; updated Jan 14 2025) | Ancillary |

*GitHub API note: repo meta says default branch `main`; org name was renamed `openmoneymarket` → `ommfinance` (README badges still reference openmoneymarket; both resolve).*

### 1.2 Deployed contracts ↔ live ABI check ✅ (strongest mapping evidence)

The live on-chain ABI (captured in this workspace, `analysis/scoreapi_*.json`) matches the **post-fix** source:

- Live `lendingPool` (`cxcb455f…53c0d`) exposes `redeem(Address _reserve, int _amount, bool _waitForUnstaking)` — exactly the fixed signature from commit `23974eeb`. The vulnerable signature was `redeem(Address _oToken, ...)`.
- Live `lendingPoolCore` (`cxfb312bb…ea94`) exposes `getReserveOTokenAddress(Address _reserve)` — the function the fix calls to resolve reserves.
- Live `AddressProvider` (`cx6a6613…2e5b6`) maps `staking → cx43e2eec79eb76293c298f2b17aec06097be606e0`, matching the `Staking` module (its live ABI has `updatePreps`/`updateValidPreps`, seen in the source's `StakingImpl.java`).

Conclusion: the live money-market contracts correspond to **v1.2.6+ (post-exploit fix)**, not the pre-exploit v1.2.x code. Exact SCORE version per contract can be verified on-chain via the SCORE metadata/audit endpoint (`/api/v3/contracts/{addr}` in the ICON JSON-RPC, `getScoreStatus` in `scoreapi`) — recommended follow-up.

### 1.3 Key source files & raw URLs ✅

Raw URL pattern: `https://raw.githubusercontent.com/ommfinance/openmoneymarket-contracts/main/<path>`

| Contract | Source file (main branch) |
|---|---|
| LendingPool | `core-contracts/LendingPool/src/main/java/finance/omm/score/core/lendingpool/LendingPoolImpl.java` · `AbstractLendingPool.java` |
| LendingPoolCore | `core-contracts/LendingPoolCore/src/main/java/finance/omm/score/core/lendingpoolcore/LendingPoolCoreImpl.java` · `AbstractLendingPoolCore.java` · `reservedata/AbstractReserve.java` · `userreserve/AbstractUserReserve.java` |
| LiquidationManager | `core-contracts/LiquidationManager/src/main/java/finance/omm/score/core/liquidation/manager/LiquidationManagerImpl.java` |
| PriceOracle | `core-contracts/PriceOracle/src/main/java/finance/omm/score/core/oracle/PriceOracleImpl.java` (+ `oracle/token/sICXToken.java`) |
| DataProvider | `core-contracts/LendingPoolDataProvider/src/main/java/finance/omm/score/core/lendingPoolDataProvider/LendingPoolDataProviderImpl.java` |
| Staking (v2) | `core-contracts/Staking/src/main/java/finance/omm/score/staking/StakingImpl.java` |
| Rewards | `core-contracts/RewardDistribution/.../db/UserClaimedRewards.java` (+ `RewardDistribution` module; legacy: `legacy/LegacyRewards.java`) |
| FeeProvider | `core-contracts/FeeProvider/src/main/java/finance/omm/score/FeeProviderImpl.java` |
| AddressProvider | `libs/AddressProvider/src/main/java/finance/omm/libs/address/AddressProvider.java` (+ `Authorization.java`, `Contracts.java`) |
| Interfaces | `libs/Score/src/main/java/finance/omm/core/score/interfaces/*.java` |

### 1.4 The vulnerable vs fixed `redeem` (exact snippets)

**Vulnerable (commit `66544f43`, Jan 19 2023 — file saved locally as `research/LendingPoolImpl_PRE-FIX_66544f43.java`):**

```java
@External
public void redeem(Address _oToken, BigInteger _amount, @Optional boolean _waitForUnstaking) {
    checkAndEnableFeeSharing();
    Address caller = Context.getCaller();
    Map<String, Object> redeemParams = call(Map.class, _oToken, "redeem", caller, _amount); // ← arbitrary address called
    Address reserve = (Address) redeemParams.get("reserve");          // ← attacker-controlled value
    BigInteger amount = (BigInteger) redeemParams.get("amountToRedeem"); // ← attacker-controlled value
    redeemUnderlying(reserve, caller, _oToken, amount, _waitForUnstaking);
}
```

**Fixed (commit `23974eeb`, Feb 8 2023; PR #166 "redeem-bug-fix" merged as `1c34e29b`, Feb 20 2023):**

```java
@External
public void redeem(Address _reserve, BigInteger _amount, @Optional boolean _waitForUnstaking) {
    checkAndEnableFeeSharing();
    Address caller = Context.getCaller();
    Address oToken = call(Address.class, Contracts.LENDING_POOL_CORE, "getReserveOTokenAddress", _reserve);
    if (oToken == null) {
        throw LendingPoolException.reserveNotValid(TAG + " " + _reserve.toString() + " is not valid");
    }
    Map<String, Object> redeemParams = call(Map.class, oToken, "redeem", caller, _amount);
    ...
}
```
Companion commit `009bd263` added `ReserveNotValid(3)` to `LendingPoolException`.

- Patch URLs: https://github.com/ommfinance/openmoneymarket-contracts/commit/23974eeb.patch · https://github.com/ommfinance/openmoneymarket-contracts/commit/009bd263.patch (both saved in `research/`).
- Compare `getReserveOTokenAddress` fixed core impl (line 319 of current `LendingPoolCoreImpl.java`): resolves `reserve.oTokenAddress.at(prefix)` from the whitelisted reserve DB.

---

## 2. The 2023-01-21 exploit (task 2)

### 2.1 What happened ✅
Sources: Omm's own **exploit postmortem** (forum.omm.finance/t/omm-exploit-postmortem-january-2023/266, Jan 23 2023, archived: https://web.archive.org/web/20230531205512/https://forum.omm.finance/t/omm-exploit-postmortem-january-2023/266) and Smart Contract Hacking summary (https://smartcontractshacking.com/hacks/omm-hack-2023).

- **Timeline:** Jan 21 2023, 07:06:37 UTC — attacker deployed malicious contract `cx1b2de6436be55a2d83b0978d2fb6a4423686165e`; exploited over **18 transactions**.
- **Loss:** **$1,891,477.80** — 6,743,265 sICX / 599,704 IUSDC / 342,898 USDS / 264,111 bnUSD. ≈20% of protocol net value ($9.68M pre-exploit).
- **Attack:** injected a malicious contract through the `redeem` path (see 1.4); withdrew collateral that wasn't theirs; then supplied stolen USDS as collateral to borrow sICX. Profit realized via **Balanced** swaps (deviating bnUSD/stablecoins from $1 peg) and **Orbit Bridge** (IUSDC to Ethereum/Polygon).
- **Attacker wallets (ICON):** main `hxc35cffe7c582cb313820fa6838dd357027ad3d07`; IUSDC `hx51f13e69…`, `hxc308be82…`, `hx2cb7cfad…`, `hxd5271567…`; ICX `hx800acdc3…`, `hxff440439…`, `hxd5271567…`, `hx9736efa2…`, `hx12a83824…`, `hxd66ce835…`, `hxae7e22a2…`, `hx51f13e69…`. Exchanges suspected: XGO `hxe5327aad…`, Bybit `hx6b91c8de…`, OKX `hx85532472…`.
- **ETH/Polygon receiving USDC via Orbit:** `0x00082ff22852c7d3eaa157abe343f9b8e64cfd85`, `0x7e4d6232c47789df03d5849675438605c6efa60e`, `0x3b074b585864884035409a091aafd1e3749e152a`, `0x49fedf6ff59c5f35ce53e6a31738cf84172eab55`, `0x517dfb8643363e3bbb034d6ce59b99ef13dd22d6`, `0xA28408FD24cA1BE5e666e30eEcA59Cf8cdeBa448`.
- **DefiLlama hacks DB ✅:** single entry `1670716800`-adjacent `1674259200` (2023-01-21) `Omm`, `$1,891,000`, technique **"Redeem Logic Flaw"** (api.llama.fi/hacks, saved as `research/defillama_hacks.json`). DefiLlama protocol `deadUrl: true`, `audits: "2"`, `twitter: ommfinance` (api.llama.fi/protocol/omm).

### 2.2 Response & recovery ✅
- Markets deactivated; stablecoin reserve rates set to 0; Balanced halted; Orbit halted IUSDC bridge; Stably disabled USDS issuance/redemption (tweet 1616875440169418752); exchanges contacted; legal advice sought.
- **Recovery Fund:** `hx6d36daba20cf74d54ff6e863f7f6e0a2653ed8aa` (ICON) and `0x0Bb7e89613d6520856D4DE6fF97E65D1329A0497` (ETH). Recovered: 2,741,431 sICX + 242,460 IUSDC (frozen by Orbit). White-hat bounty offer (10%) expired; DOJ notification threatened after 48h.
- Feb 3 2023 update: 100% of "recoverable amount" (~$1M) secured; **OIP-16** (protocol fees + POL → Recovery Fund); plan to "make everyone whole" via 50% of DAO Fund OMM + 50% future fees (**OIP-17**). Per later official docs: "All funds were restored thanks to the community's support, so no loss was borne by Omm users."
- Relaunch: repay/withdraw functionality restored within a month; supply/borrow permanently disabled afterwards.
- Exploit-fix PR: #166 (`1c34e29b`, merged 2023-02-20); "redeem-bug-fix". Fix live (see 1.2).

### 2.3 Second incident? ❌ (no second exploit found)
- DefiLlama hacks DB: only the 2023-01-21 Omm entry. No 2023–2024 second Omm exploit.
- **March 2024 BALN-market event (governance, not an exploit ✅):** "BALN Market Discussion" (Mar 5 2024, archived https://web.archive.org/web/20240414140121/https://forum.omm.finance/t/baln-market-discussion/309) — BALN market at ~100% utilization because BALN borrowers didn't repay; proposal to **liquidate those borrowers** and distribute 38,170 sICX pro rata to oBALN depositors (41,516 BALN initial deposits; BALN $0.2941, sICX $0.3620). Enacted via **OIP-23 "Repaying oBALN holders"** (Mar 7 2024, archived https://web.archive.org/web/20240414134015/https://forum.omm.finance/t/oip-23-repaying-obaln-holders/311). Corroborating code commits: `206aa8b2` "chore: new method for liquidation added" (2024-03-08), `9113f464` "chore: redeem on baln market is closed" (2024-03-12), merge `a34d6e1f` "development/liquidation_by_admin" (2024-03-25). ⚠️ Whether this was triggered by an external exploit of BALN itself is not established by these sources; the forum frames it as non-repayment/high utilization.
- **OIP-24 context (Jun 2025):** "USDS and IUSDC have gone through bankruptcy and hacks, and thus will be valued at $0 for distribution" — issuer/ecosystem events, not an Omm exploit. ⚠️ details of those events not investigated here.
- **Orbit Bridge hack (New Year 2024, ~$81M):** affected the ICON ecosystem and Omm's earlier bridge route, but it is Orbit's incident, not Omm's. ⚠️ (not verified in this session; out of scope).

### 2.4 Official communications ✅/⚠️
- Incident tweet (2023): https://twitter.com/ommfinance/status/1617327827216658432 ⚠️ (X login wall; referenced by Smart Contract Hacking).
- First exploit-proposal discussion tweet: https://x.com/ommfinance/status/1618818849490751494 ⚠️ (login wall).
- Postmortem forum thread ✅ (archived, full text saved in `research/omm_postmortem_2023.md`).
- No independent security-firm post-mortem found (❌): no Rekt/BlockSec/CertiK write-up located in searches.

---

## 3. Docs recovery (task 3)

Wayback CDX enumeration: `http://web.archive.org/cdx/search/cdx?url=docs.omm.finance*&output=text&fl=original,timestamp,statuscode&collapse=urlkey&limit=300` (saved `research/wayback_docs_urls.txt`, 108 URLs).

### 3.1 Smart-contracts page — money market (2022-08-16) ✅
Archived: https://web.archive.org/web/20220816013519/https://docs.omm.finance/technical-info/smart-contracts (raw HTML saved `research/sc_2022.html`).
- "The Omm **start** contracts have been audited by **SlowMist**: *Omm | Slowmist security audit.pdf* 969KB PDF" (file link not recoverable — see §5).
- Addresses listed (identical to the 2023/2024 versions for money market): OMM `cx1a29259a…830a`; OMMWT `cx718eb47b…8211`; oTokens oBALN `cx0b33a9e5…84a9`, obnUSD `cx333b95b…cde5`, oICX `cx0fb973aa…f0d9`, oIUSDC `cxa8efd072…0013`, oOMM `cx0a075eb7…9324`, oUSDS `cx1837c2a9…dd5f`; dTokens dBALN `cx3dd0f6f2…55f3`, dbnUSD `cx440d7bf3…8c80`, dICX `cxdd660884…ef0`, dIUSDC `cxb31005e7…2b69`, dOMM `cx07e2ae66…94ee`, dUSDS `cx4729aa82…0429`; Address Provider `cx6a661302…e5b6`; Boosted OMM `cxeaff5a10…7921`; DAO Fund Manager `cx48a83a6f…f896`; Delegation `cx841f29ec…afe5`; Fee Provider `cx4f3c2edf…b4fb`; Governance Manager `cx8190de91…4838`; Lending Pool `cxcb455f26…53c0d`; Lending Pool Core `cxfb312bbd…ea94`; Lending Pool Data Provider `cx5f9a6ca1…3cb5`; Liquidation Manager `cx533d7609…976c`; Price Oracle `cx189f0387…2dbe`; Reward Distribution Controller `cx4f2d730a…ef6f`; Staked LP `cx015c7f88…0cb6`.

*(2023 copy — https://web.archive.org/web/20230924210841/https://docs.omm.finance/money-markets/technical-info/smart-contracts — is identical except "start"→"smart" and heading "Money markets (discontinued)" in nav.)*

### 3.2 Liquidation rules ✅
Archived: https://web.archive.org/web/20230924212121/https://docs.omm.finance/money-markets/technical-info/liquidation
- Liquidation when below liquidation threshold; post-liquidation loan reset to Max LTV; **10% bonus** for liquidators; bad-debt auction; origination fee deducted from collateral.
- **Parameters (examples):** BALN LTV 0 / threshold 0.325; OMM LTV 0 / threshold 0.325; bnUSD, ICX, IUSDC, USDS LTV 0.5 / threshold 0.65.

### 3.3 Interest-rate model ✅
Archived: https://web.archive.org/web/20230924194141/https://docs.omm.finance/money-markets/technical-info/interest-rate
- Kinked model, Uoptimal 0.8 for all six assets; R0/Rslope1/Rslope2: stables (bnUSD, IUSDC, USDS) 0.02/0.06/2; volatile (BALN, ICX, OMM) 0/0.08/4. Utilization capped at 90% (no new borrows, redemption still allowed).

### 3.4 Staking / rewards / governance pages ⚠️
- Requested slugs `/lending`, `/staking`, `/rewards`, `/governance` do **not** exist as such; historic structure: `/technical-info/*`, `/user-guide/claim-rewards` (2021-09-25), `/money-markets/user-guide/governance` (2023-09-24), `/liquid-staking/governance` (2023-09-24), `/participate-governance` (2024-04-20).
- **Liquid-staking mechanics** are in the 2023 docs set: `/liquid-staking/stake-unstake`, `/vote-validators`, `/lock-omm`, `/governance` (all captured 2023-09-24; see `wayback_docs_urls.txt` for URLs). Summary from the pivot page: stake ICX → sICX; 10% staking-reward fee (50% DAO fund / 40% validators by vote / 10% sICX team); bOMM votes on validators; sICX holders can override delegation.
- `/protocol-details` (2024-04-20 capture) failed to render (Wayback returned 404 wrapper) ❌.

### 3.5 Pivot + 2024 addresses ✅
- **"About the liquid staking pivot"** (2023-09-24): https://web.archive.org/web/20230924212658/https://docs.omm.finance/reference/liquid-staking-pivot — full length text saved in notes; key: "Omm is no longer a money market"; $1.9M hack; all funds restored; **"you can no longer supply or borrow assets"**; OIP-17 compensation; OIP-18 merger with the sICX team; Omm 2.0 launched mid-2023; OMM inflation halted at v2.
- **Smart contracts (2024-04-20)** ✅: https://web.archive.org/web/20240420045923/https://docs.omm.finance/smart-contracts — "The Omm smart contracts were audited by **ICON community developers prior to the liquid staking release**." Addresses: Address Provider `cx6a661302…e5b6`; bOMM `cxeaff5a10…7921`; Delegation `cx841f29ec…afe5`; DEX `cxa0af3165c08318e988cb30993b3048335b94af6c`; Fee Distribution `cx553b05df18e9d7c00d8bf4675e579cbbb23c4b30`; Lending Pool Core `cxfb312bbd…ea94`; OMM Token `cx1a29259a…830a`; DAO Fund Manager `cx48a83a6f…f896`; Governance Manager `cx8190de91…4838`; sICX `cx2609b924e33ef00b648a409245c7ea394c467824`; **Staking `cx43e2eec79eb76293c298f2b17aec06097be606e0`** (= live AddressProvider `staking`).

---

## 4. Governance, ownership, shutdown (task 4)

### 4.1 Governance artifacts ✅
- **Governance Manager** `cx8190de91c8831f382dcabdbc87968448380c4838`; **DAO Fund Manager** `cx48a83a6fbdaa205a060514fd23ad6871c070f896`; **Boosted OMM (bOMM)** `cxeaff5a10cb72bf85965b8b4af3e708ab772b7921`.
- Composition/ownership of each contract is set through `AddressProvider` (`cx6a661302…e5b6`) and its owner/`Contracts` map (`libs/AddressProvider/Authorization.java`). ❌ The current owner address (EOA vs multisig vs DAO) was **not determined here** — that is an on-chain `owner()` / governance-manager query (recommended for the main session).
- **Live staking admin surface ⚠️ (security-relevant):** `StakingImpl` exposes `setEmergencyManager(Address)`, `getEmergencyManager`, `toggleStakingOn`, `setSicxAddress(Address)`, `setFeePercentage(BigInteger)`, `setBlockHeightWeek(BigInteger)`, `updatePreps`/`updateValidPreps` (plus `FundTransfer`/`TokenTransfer` eventlogs). Single-admin emergency + fee controls on the live `cx43e2ee…` contract; verify owner and emergency manager on-chain.
- OIP list (forum topics, archived): OIP-16 (fees/POL → Recovery Fund), OIP-17 (50% DAO OMM + 50% future fees to restore losses), OIP-18 (merge with sICX team → liquid staking), OIP-19 (inflation halt phase 1), OIP-20 (BALN reserve IR change, Dec 2023), OIP-21 (DAO fees → BALN market, Feb 2024), OIP-22 (launch Omm 2.0 liquid staking, Feb 2024), OIP-23 (repay oBALN, Mar 2024), OIP-24 (sunset, Jun 2025). URLs in `research/wayback_forum_urls.txt`.

### 4.2 Shutdown ✅
- **"Sunsetting Omm Discussion"** (May 20 2025; archived https://web.archive.org/web/20250623191052/https://forum.omm.finance/t/sunsetting-omm-discussion/318): "Based on the **new direction by the ICON Foundation**, Omm's liquid staking service won't be needed in the foreseeable future as **ICON L1 shuts down**"; propose distributing 136,518 sICX DAO-fund fees to bOMM holders; unlock bOMM; unwind money market (bnUSD depositors at 100% utilization); "please withdraw [money market funds] as soon as possible". References ICON tweet: https://x.com/poweredbyicx/status/1919409437900406848 ⚠️ (X login wall).
- **OIP-24 "Sunsetting Omm"** (Jun 5 2025; archived https://web.archive.org/web/20250623174827/https://forum.omm.finance/t/oip-24-sunsetting-omm/320): (1) distribute all DAO-fund sICX (**141,759 sICX**) to bOMM holders by balance; (2) allow bOMM unlock; (3) money-market users (ICX, bnUSD, OMM markets) get **~75% of remaining value pro rata** on [total supply − total borrow].
  - Follow-up post (Jun 5 2025): USDS & IUSDC valued **$0** (issuer "'bankruptcy and hacks'"); one user `hxbffc0dd3982a8cc3b6154a58fe7fa3336e102559` borrowed $20K+ bnUSD against USDS causing discrepancy; user net balances $90,306 vs market $67,212 (≈75%); ~**960 users**; $67,212 in sICX+OMM to be distributed.
- **Retirement:** X profile (via search snippets; direct fetch login-walled) 🟡: bio reads "Liquid staking on the ICON blockchain. Home of $sICX. **Omm was retired in January 2026**, and this account is no longer monitored."; another post: "Reminder: Omm will go offline at the end of 2025. ICON's transition to **SODAX** removes any need for a liquid staking product. If you locked up OMM…" (unlock instructions).
- **Rescue/withdrawal contract:** ⚠️ No separate "rescue" contract found. v1 users were directed to the app (repay/withdraw only) until sunset; OIP-24 proposes pro-rata **distributions** (mechanism/claim contract not documented publicly in recovered sources; ❌ execution status not verified here — check sICX/OMM transfers from DAO Fund on-chain).

---

## 5. Audits (task 5)

| Audit | Status | Evidence |
|---|---|---|
| **SlowMist — money market (pre-launch)** | ✅ documented / ❌ PDF unrecoverable | Docs (2022 & 2023): "The Omm smart contracts have been audited by SlowMist: *Omm \| Slowmist security audit.pdf* (969KB)". Links: 20220816013519 & 20230924210841 captures of `/technical-info/smart-contracts`. The GitBook file link is a signed `3383002474-files.gitbook.io` URL; CDX queries for PDFs on that host and on docs.omm.finance returned **no captures**. SlowMist cert page fetch (`slowmist.com/en/security-audit-certificate.html?id=…`) rendered JS-only and project attribution could not be confirmed ⚠️. No findings text recovered — any findings "still relevant" cannot be quoted from public sources; the **redeem-validation class of bug is the one that mattered** and is fixed on-chain (see §1.4/2.1). |
| **ICON community developers — liquid staking (v2)** | ✅ documented (not a firm) | 2024 docs: "The Omm smart contracts were audited by ICON community developers prior to the liquid staking release." |
| **DefiLlama "2 audits"** | 🟡 | api.llama.fi/protocol/omm: `"audits":"2"`, `audit_links":["https://docs.omm.finance/technical-info/smart-contracts"]` (only one link). Likely counts SlowMist + community review; **⚠️ the second audit's identity/PDF is unverified.** |
| **Repo audit-remediation branches (Feb–Apr 2023)** | ✅ present in repo | Branches `audit/issue-1-fix` … `audit/issue-32-fix`, `169-code-review`, `170-code-review` (branch list from GitHub API). Indicates a ≥32-issue review round on the post-exploit codebase; **auditor firm not named in accessible public metadata** ⚠️. |

---

## 6. Could not find / dead ends ❌

- SlowMist audit **PDF file** and certificate attribution (GitBook signed URL; SlowMist site renders via JS; no Wayback capture found).
- Identity of a possible **second audit firm**.
- Legacy doc slugs `/lending`, `/staking`, `/rewards`, `/governance` (never existed; docs use different structure — see §3).
- 2024 `/protocol-details` capture (Wayback returned a failure page).
- X/Twitter thread contents (`status/1617327827216658432`, `status/1618818849490751494`, profile bio) — login wall; only search snippets available.
- Independent (non-Omm) post-mortem of the exploit (no Rekt/security-firm write-up found).
- Current contract owner/emergency-manager addresses and OIP-24 distribution execution — on-chain checks (out of scope here; recommended for main session).
- GitHub API rate limit (60 req/h unauthenticated) was exhausted mid-research; `omm-documentation` clone timed out. Docs covered via Wayback instead.

---

## 7. Security-review leads for the main session (from this research)

1. **Live LendingPool redeem is patched** (`_reserve` param + `getReserveOTokenAddress`); the historical bug class (unvalidated external-call-derived reserve) was the root cause of the $1.9M loss — verify no analogous unvalidated-address paths remain in `LiquidationManager`, `LendingPoolDataProvider`, and fee-share calls (`FeeProvider`, `FeeDistribution`).
2. **Staking `cx43e2ee…` admin surface:** `setEmergencyManager`, `toggleStakingOn`, `setFeePercentage`, `setSicxAddress`, `updatePreps/updateValidPreps` — check owner/emergency-manager and whether admin can redirect funds (FundTransfer/TokenTransfer eventlogs).
3. **BALN market closed for redeem (Mar 2024 commit `9113f464`) and liquidation-by-admin code (2024-03-25 merge `a34d6e1f`)** — confirm live flags/state (`toggleLiquidation` etc., see `scoreapi_liquidationManager.json`).
4. **Residual user funds:** OIP-24 says ~$67K in sICX+OMM owed to ~960 money-market users; USDS/IUSDC reserves (valued $0) may still hold tokens — interesting for on-chain balance measurement.
5. **Trust timeline:** all contracts are upgradeable JRSC/deployable SCOREs controlled via AddressProvider/governance — the deployed bytecode hash per contract should be compared with the repo builds (v1.2.6+ tags) for exact provenance.

---

## 8. Artifact index (`/home/heisenberg/CA/omm/analysis/research/`)

| File | Content |
|---|---|
| `omm_postmortem_2023.md` | Full text of official exploit postmortem (Wayback) |
| `LendingPoolImpl_PRE-FIX_66544f43.java` | Vulnerable `LendingPoolImpl` (pre-exploit) |
| `LendingPoolImpl_POST-FIX_main.java`, `AbstractLendingPoolCore_main.java`, `LendingPoolCoreImpl_main.java`, `StakingImpl_main.java`, `PriceOracleImpl_main.java` | Current source copies (main branch) |
| `LendingPoolCoreImpl_PRE-FIX.java` | Pre-exploit core copy (66544f43) |
| `patch_23974eeb.patch`, `patch_009bd263.patch` | Fix diffs |
| `commit_23974eeb.json`, `commit_009bd263.json`, `commits_all.json`, `commits_jan-feb-2023.json` | Git history evidence |
| `tree_omm-scores.json`, `tree_contracts_main.json`, `repo_contracts_meta.json` | Repo structure |
| `defillama_omm.json`, `defillama_hacks.json` | DefiLlama API evidence |
| `wayback_docs_urls.txt`, `wayback_forum_urls.txt` | CDX enumerations |
| `raw_smartcontracts_page.html`, `sc_2022.html`, `sc2024b.html`, `ti_2022.html`, `raw_baln309.html`, `slowmist_cert.html` | Archived docs/pages raw HTML |

**Primary URLs (all verified live/archive at time of research):** postmortem `web.archive.org/web/20230531205512/https://forum.omm.finance/t/omm-exploit-postmortem-january-2023/266`; fix `github.com/ommfinance/openmoneymarket-contracts/commit/23974eeb`; source `github.com/ommfinance/openmoneymarket-contracts`; deploy artifacts `github.com/ommfinance/omm-scores`; pivot docs `web.archive.org/web/20230924212658/https://docs.omm.finance/reference/liquid-staking-pivot`; sunset `forum.omm.finance/t/oip-24-sunsetting-omm/320` (archived 20250623174827); hack recap `smartcontractshacking.com/hacks/omm-hack-2023`.
