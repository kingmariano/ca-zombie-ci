# Child-C — Web research: Blockswap / Stakehouse status 2023–2026

**Research date:** 2026-10-12. All URLs below were fetched on that date unless a Wayback capture is cited. On-chain corroboration is in `ecosystem_value.md` §4 and `reporter_activity.json` / `reporter_profiles.json`.

**Bottom line:** Blockswap/Stakehouse was *deliberately handed over to a DAO and then abandoned* between Sept 2023 and July 2024. There is no shutdown post-mortem, no hack, and no formal "sunset" announcement; the team (Blockswap Labs) declared the roadmap complete, handed all operational responsibility to the on-chain DAO (Jan–Apr 2024), deprecated all hosted services on **July 10, 2024**, and pivoted to other products (gmChat/AI). The DAO went silent after May 2024. On-chain sweep reporting — the off-chain service the withdrawal system depends on — stopped **2024-08-07**. DefiLlama marks the protocol dead as of 2025-01-01. Most product domains are now dead or squatted.

---

## 1. Timeline of the wind-down (with sources)

| Date | Event | Source |
|---|---|---|
| 2023-06-29 | RuntimeVerification delivers the **Stakehouse Withdrawals** audit (the code behind FullWithdrawals/SweepReporter/QueueFlushETHClaim). Code was in private repo `bswap-eng/Stakehouse-V2` @ commit `3e68bb7…`. | local copy `/tmp/opencode/audits/withdrawal_audit.txt`; RV publications list: https://github.com/runtimeverification/publications |
| **2023-09-08** | DAO post: **“[Notice] Completion of Blockswap Network Roadmap”** — “signals the end of the Blockswap Network roadmap”. Lists everything delivered (Stakehouse mainnet, LSD Networks, kETH, CIP…). Updated 2023-11-06. | https://gov.blockswap.network/t/notice-completion-of-blockswap-network-roadmap/510 (archived: https://web.archive.org/web/20251204132905/https://gov.blockswap.network/t/notice-completion-of-blockswap-network-roadmap/510.rss) |
| 2023-09-14…20 | Withdrawal upgrade deployed on mainnet (SweepReporter proxy 0x64f4fCFb… at block 18,172,666; FullWithdrawals proxy 0x8F6839b0… at 18,172,820; new AccountManager/SLOTRegistry/TransactionRouter impls; RageQuitAssistantDeployer 0xba459271… at 18,177,178). First sweep reported 2023-10-06 (block 18,294,390). | on-chain; `ecosystem_value.md` §4; `protocol_deployer_creates.json` |
| 2023-12-15 | DAO post referenced in roadmap thread (“dETH can be brought to Optimism…”) — last meaningful community enthusiasm. | same thread, archived RSS |
| **2024-01-31** | **Blockswap Labs handover**: “As of January 31st 2024, Labs has been entirely relieved of post-handover maintenance obligations, and the Blockswap Network is now fully decentralized and self-operational with the DAO as its continuous operational entity.” | https://blockswap.network/labs-disclaimer/ (live page, fetched 2026-10-12) |
| 2024-03-23 | DAO post: **“[Notice] Decentralized Frontends & Infra”** — publishes the dApp code (LSD-dapp, stakehouse-dapp, kETH-dapp, fren-delegation, ETL, fee-recipient-service) so the community can self-host. | https://gov.blockswap.network/t/notice-decentralized-frontends-infra/648 (archived RSS: web/20251204130518) |
| 2024-03-26/28 | **“[Notice] kETH: Full DAO-based Operations & Management”** and **“[Notice] LSD Network Protocol: Full DAO-based Operations & Upgrades”** | https://gov.blockswap.network/t/notice-keth-full-dao-based-operations-management/650 ; https://gov.blockswap.network/t/notice-lsd-network-protocol-full-dao-based-operations-upgrades/654 |
| **2024-04-03** | **“[Notice] Stakehouse: Full DAO-based Operations”** — “platform management will be coming under the full control of the DAO managed autonomous operations… with the support of protocol guardians”. On-chain this is the LSD Kontroller → `DAO()` = `0x8869A94df9200C75116A285e12E85C24179129E1` (BSNGovernor), verified by this scan. | https://gov.blockswap.network/t/notice-stakehouse-full-dao-based-operations/657 (archived RSS) |
| **2024-05-14** | Last-ever forum topics: **“RIP BSN — All the investment, time, and $ GONE”** (“RIP BSN… all the $ from investors. all the time spent building. GONE!!!”) and a “[Temperature Check] Launch new BSN DAO Token” citing “High sell pressure from investors looking to leave the project… trust and belief lost”. | https://gov.blockswap.network/t/rip-bsn-all-the-investment-time-and-gone/668 ; forum RSS lastBuildDate 2024-05-14 (archived: https://web.archive.org/web/20251204125934/https://gov.blockswap.network/latest.rss) |
| **2024-06-26** | Update to the frontends notice: **“all hosted services will be deprecated as of July 10th, 2024”**; Labs discontinues all managed user support. | https://gov.blockswap.network/t/notice-decentralized-frontends-infra/648 (archived RSS) |
| 2024-07-04 | Last `FullWithdrawalExecuted` event (block 20,234,472). | on-chain, `fullwithdrawal_executed_events.json` |
| 2024-07→09 | DefiLlama TVL collapse: $3.72M (Jul 1) → $273k (Jul) → $112k (Sep). | https://api.llama.fi/protocol/stakehouse (saved: `web_evidence/defillama_stakehouse.json`) |
| **2024-08-07** | **Last sweep report ever**: SweepReporter tx block 20,478,005, `reportSweepsPostRageQuit` (0x6184bf91), from EOA `0x59ba96dba0158b96c66d2a032f03bb5b5a03f0a0`. Nothing since (2+ years as of Oct 2026). | on-chain, `reporter_activity.json` |
| 2025-01-01 | DefiLlama `deadFrom` for the “Stakehouse” protocol. | https://api.llama.fi/protocol/stakehouse |
| 2025-02-28 | Last TVL datapoint ever ($101,495). | same |
| 2026-10-12 | Domain checks: joinstakehouse.com + lsd.joinstakehouse.com + docs.joinstakehouse.com = “Domain suspended or not configured” (BunnyCDN); dapp.getketh.com + gov.blockswap.network = DNS failure; getketh.com = now an unrelated Indonesian gambling site; stakehouse.dev = now an unrelated “StakeHouse” yield product; blockswap.network marketing site still up but links only to dead apps. | Firecrawl/DNS checks, recorded in this session |

---

## 2. What actually happened (narrative)

1. **No hack, no exploit found.** Searches for “Blockswap/Stakehouse hack/exploit/rekt” return only unrelated results (the name collides with *Steakhouse Financial*, a different vault curator with its own 2025 phishing incident — do not confuse them). The protocol has 5 published audits (Solidified, Halborn, Certora formal verification, 2× Runtime Verification incl. the withdrawals audit) listed at https://www.blockswap.network/security and https://github.com/stakehouse-dev/Audits. **Uncertainty: absence of a public exploit report is not proof no incident occurred; but no on-chain evidence of a drain was seen either — the 64.3 ETH has sat in AccountManager undisturbed.**
2. **The wind-down was planned**: roadmap-completion notice (Sept 2023) → Labs handover (Jan 31, 2024) → “full DAO-based operations” notices (Mar–Apr 2024) → hosted-services deprecation (July 10, 2024). The withdrawal system's off-chain dependency (sweep reporting, signed by the designated verifier) was part of the “managed services” that were discontinued; the DAO never picked them up.
3. **The DAO is inert**: on-chain BSNGovernor still exists (0x8869A94d…), but Snapshot `blockswapdao.eth` has no proposal after 2024-03-24 (https://hub.snapshot.org/graphql, space `blockswapdao.eth`), the forum died 2024-05-14, and the forum domain no longer resolves. No treasury action related to the stuck ETH is visible.
4. **The team moved on**: Blockswap Labs is alive at https://blockswaplabs.com/ but now promotes “gmChat” (AI crypto copilot), restaking, MEV/PBS, ZK compute — Stakehouse is not a focus. (Their site still counts “36+ products” shipped.)
5. **The token is dead**: BSN price ~$0.00035, market cap ~$0, liquidity gone (https://tokeninsight.com/zh/coins/blockswap-network-bsn/historical ; https://www.kucoin.com/price/BSN). The DAO was given 53% of BSN supply at launch (roadmap post).

---

## 3. Sweep reporter / off-chain signer — direct answer

* **Is anyone still running the sweep reporter? No.** The last SweepReporter transaction is from **2024-08-07** (`reporter_activity.json`). The 1,931 `SweepReported` events span 2023-10-06 → 2024-08-07 with a final burst in June 2024 (740 events) and 25 in the last week (`sweepreported_monthly.json`).
* **Who ran it:** a handful of EOAs submitted the reports — `0xb0e83c2d71a991017e0116d58c5765abc57384af` (54 of the last 100 txs), `0x59ba96dba0158b96c66d2a032f03bb5b5a03f0a0` (the final 5 reports, now dormant), `0x1a31c94f97c649bc2a8adbceb54d1f4a075be4b1`, plus some node runners. Two of these EOAs still transact in 2026 (unrelated DeFi activity), so the humans are alive — they just stopped reporting.
* **The signer `0x9785f8e50229ebd2b3788452abc31d1942394e0c`** (DepositRouter/designated verifier): it **has never sent a single transaction** on mainnet (Etherscan txlist: "No transactions found"; balance 0; no code). It is still registered as verifier on-chain — `isDesignatedVerifier(0x9785f8e5…) = true` on both `FullWithdrawals` and `SweepReporter` at block 26179033. Signing happens off-chain, so on-chain inactivity does not prove the key is lost; but the *service* that would use it (DepositRouter) is dead per the July 2024 deprecation notice, and **no signed report has been usable since Aug 2024**.
* **Consequence for stuck funds:** `FullWithdrawals.reportFinalSweepAndWithdraw` and `RageQuitAssistant.executeFullWithdrawal` both require the verifier's EIP-712 signature. Without a live reporter/signer, any knot that hasn't completed the final-sweep path cannot move its ETH out of the AccountManager. This is the most plausible explanation for the 64.3 ETH residue (the last knot(s) never got their final report).

---

## 4. Product surface status (all checked 2026-10-12)

| URL | Status |
|---|---|
| https://www.blockswap.network/ | **Live** (static marketing; still advertises Stakehouse, kETH, LSD app, CIP; all app links dead) |
| https://blockswap.network/labs-disclaimer/ | **Live** (the Jan 31 2024 handover text) |
| https://blockswaplabs.com/ | **Live** (Labs pivoted to AI/restaking/MEV) |
| https://joinstakehouse.com/ | **Dead** — BunnyCDN “Domain suspended or not configured” |
| https://lsd.joinstakehouse.com/ | **Dead** — same |
| https://docs.joinstakehouse.com/ | **Dead** — same |
| https://dapp.getketh.com/ | **Dead** — DNS does not resolve |
| https://gov.blockswap.network/ | **Dead** — DNS does not resolve (content only via Wayback) |
| https://getketh.com/ | **Squatted** — now an unrelated Indonesian gambling site |
| https://stakehouse.dev/ | **Unrelated** — now a different “StakeHouse” yield product (first seen ~2026; Wayback capture Jan 2025 shows the change: https://web.archive.org/web/20250123014031/https://www.stakehouse.dev/) |
| Hosted subgraphs (`api.thegraph.com/subgraphs/name/stakehouse-dev/*`, `bsn-eng/*`) | **Dead** — The Graph hosted service is fully retired (301s); Stakehouse never migrated to the decentralized network. The ETL repo (https://github.com/stakehouse-dev/stakehouse-etl) can self-host but nothing runs it publicly. |
| npm `@blockswaplab/stakehouse-contract-interfaces` | Frozen at v1.0.20, published **2023-10-23** (https://registry.npmjs.org/@blockswaplab%2Fstakehouse-contract-interfaces). Used by this scan for claim semantics. |

---

## 5. GitHub activity (last commits, from clones fetched 2026-10-12)

| Repo | Last commit |
|---|---|
| stakehouse-dev/contract-deployments | 2024-04-02 |
| stakehouse-dev/deployable-giant-pool | 2024-04-11 |
| stakehouse-dev/stakehouse-dapp | 2024-03-23 |
| stakehouse-dev/stakehouse-etl | 2024-01-31 |
| stakehouse-dev/stakehouse-solidity-api | 2023-10-23 |
| stakehouse-dev/stakehouse-contract-interfaces | 2023-10-20 |
| stakehouse-dev/lsd-contracts | 2023-04-24 |
| The withdrawals code repo `bswap-eng/Stakehouse-V2` | **private** (never public; audit frozen at commit `3e68bb7…`) |

No commits to any public Stakehouse repo after **April 2024**.

---

## 6. Public discussion of stuck funds

* The only public “where did it go” thread found is **“RIP BSN”** (2024-05-14) on the (now dead) DAO forum: https://gov.blockswap.network/t/rip-bsn-all-the-investment-time-and-gone/668 (archived). It is an investor grievance post, not a technical stuck-funds thread.
* The “[Temperature Check] Launch new BSN DAO Token” (2024-04-23) explicitly describes loss of trust and exit pressure.
* **No public discussion specific to the 64.3 ETH / unclaimed sweep funds was found** (searches on Reddit, X, forums returned nothing relevant). Uncertainty: X/Twitter is not reliably searchable today; the @blockswap_team account could not be read (login wall; only a 2025-03 Wayback capture exists and renders empty).
* DefiLlama (an independent third party) marks the protocol **dead from 2025-01-01** and stopped tracking it — the clearest public "this project is over" signal: https://defillama.com/protocol/stakehouse (data: https://api.llama.fi/protocol/stakehouse).

---

## 7. Verification notes / uncertainty

* Wayback machine was the source for forum evidence (gov.blockswap.network no longer resolves). Captures used: `20251204125934` (latest.rss), `20251204130518` (frontends notice), `20251204132905` (roadmap notice), `20251204130418` (Stakehouse DAO ops notice). Raw RSS saved in `web_evidence/`.
* The “July 10th, 2024 deprecation” refers to *hosted services* (frontends/APIs), not the smart contracts; the contracts remain on-chain and callable, which is why the on-chain value table in `ecosystem_value.md` still shows live balances.
* Firecrawl/DNS checks are point-in-time (2026-10-12); domain states can change. The getketh.com gambling-site replacement is recorded because it strongly indicates the project abandoned the domain.
* Blockswap Labs' site (blockswaplabs.com) does not mention Stakehouse prominently anymore; this is interpretation from the fetched page (navigation: ETH Staking, Restaking, MEV & PBS, ZK Verifiable Compute, Autonomous Intents, gmChat).
* No evidence was found of an exploit, exit scam, or law-enforcement action. The wind-down looks like an orderly-but-abandoned handover to an inactive DAO.
