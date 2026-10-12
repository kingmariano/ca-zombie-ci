# Vessel Finance — Child-Web Research Findings

- **Investigator:** child-web subagent (web-only: DNS/HTTP/archives/web search; NO on-chain tooling used)
- **Date of all checks (unless stated):** 2026-10-12
- **Target:** Vessel Finance — zk DEX on Scroll. Contracts: VaultProxy `0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2`, admin `0x3c417EC088f19EA02Ac9853cd6c35Fb193c98Abe`, snarkVerifier `0xF33De4cA77959061a17B0866d35c850249aCed7E` (Scroll, chainId 534352).

## TL;DR
- Website is DOWN (DNS still registered; server unresponsive). App/API-docs subdomains dead (NXDOMAIN) or unreachable. `vessel.exchange` is a GoDaddy "for sale" page.
- Socials silent since 2025-01-22 (X). Discord invite dead. Medium silent since 2024-11-06. CoinGecko: 0 trading pairs. RootData lists Vessel on its "2025 Crypto Dead Projects List". No shutdown/exploit announcement exists anywhere found.
- DefiLlama still tracks it: listed 2026-07-04, last TVL datapoint 2026-10-12 (~$194k); `url` field empty; `audits: "0"`.
- Real contract source repo found: github.com/Meshee-Team/vessel-contracts (public since 2024-12-20, author `kevinyum.eth`; contains src/vault/Vault.sol, fast-withdraw + multi-chain upgrade reports; "vesselKey" user-registration code confirmed).
- No exploit, no post-mortem, no public audit report, and no bug bounty found.
- Only Scroll deployment documented; cross-chain logic exists (LayerZero) for withdrawals. "L3" was aspirational only.

## 1) Official website — dead or alive?

DNS (Google DoH, 2026-10-12):
- `vessel.finance` → A `128.140.27.139` (Hetzner); `www.vessel.finance` → same.
- `apidoc.vessel.finance` → `128.140.27.139` (same server). `app.vessel.finance` → NXDOMAIN. `docs.vessel.finance` → NXDOMAIN.
- `trade.vessel.finance` → Cloudflare `172.67.70.209, 104.26.13.200, 104.26.12.200`.
- `status.vessel.finance` → CNAME `stats.uptimerobot.com` (UptimeRobot). `vessel.fi` → lame delegation. `vessel.exchange` → serves GoDaddy parking/for-sale. `vessel.xyz/.money/.gg/.cash` exist but are unrelated parked/squatted hosts.

HTTP reachability (2026-10-12):
- `https://vessel.finance` and `https://www.vessel.finance`: Connection timed out from all check-host nodes (HU/IR/SE, DE/PL/US). Reports: https://check-host.net/check-report/50878eb1k732 and https://check-host.net/check-report/50879a0ak9ad. Jina reader: "Failed to goto https://vessel.finance: TimeoutError: page.goto: Timeout 15000ms exceeded". Hetzner origin appears offline.
- `https://trade.vessel.finance` (app): HTTP 522 (Cloudflare "origin unreachable") from Brazil and Netherlands nodes (report https://check-host.net/check-report/508799fdk6f). Proxy fetch of `https://trade.vessel.finance/login` returned 403 page: "Restricted Access to Our Services … Due to global regulatory compliance regarding digital currency transactions, we regret to inform you that our services are currently unavailable in your region. If you believe this restriction has been applied in error, please contact our support team…" → app offline or hard geo-blocked.
- `https://apidoc.vessel.finance`: DNS alive on same Hetzner IP, Jina timed out → down.
- `status.vessel.finance`: currently ERR_SSL_PROTOCOL_ERROR; last Wayback capture 2025-03-21 (UptimeRobot page).

`vessel.exchange`: redirects to https://forsale.godaddy.com/forsale/vessel.exchange — "vessel.exchange is for sale … USD $2,988" (fetched 2026-10-12). Not the official domain (docs/CoinGecko link to vessel.finance).

Archives (web.archive.org CDX, 2026-10-12):
- `vessel.finance` root: 84 captures, 2018-08-09 → 2026-02-11. Last 2026 captures: `20260117221748`, `20260211091957` (both 200). Snapshot https://web.archive.org/web/20260211091957/https://vessel.finance/ — title "Vessel", meta "Vessel Landing Page" (Nuxt SPA shell; no body text in archived HTML).
- `trade.vessel.finance` last capture 2026-03-21/22 (https://web.archive.org/web/20260321225105/https://trade.vessel.finance/, 200); `testnet.trade` last 2026-04-11; `apidoc` last 2026-06-12 (200); `status` last 2025-03-21; main-host last archived activity 2026-05-14.

DefiLlama (API https://api.llama.fi/protocol/vessel-finance, 2026-10-12): name "Vessel Finance", slug `vessel-finance`, chains ["Scroll"], category Dexs, `url` "" (empty), twitter `VesselFinance`, `audits` "0", `listedAt` 1783127394 = 2026-07-04T01:09:54Z, latest TVL 2026-10-12T14:48:11Z = $194,067 (last 5 daily: $191,786 / $192,505 / $193,274 / $194,725 / $194,067). Description: "Vessel is a zero-knowledge-powered decentralized exchange combining a limit order book with an AMM (VAELOB), built by the founders of Scroll."

## 2) GitHub — source repo, deploy scripts, circuits

- Not the right org: github.com/VesselFinance (repos Vessel-home, Vessel-dApp, Vessel-documentation, Vessel-v1-contract; commits Feb–Apr 2022 by machin3boy, gradytucker, yuriderozan; Vessel Yellowpaper / Vessel.sol) — a different, early 2022 project. Oddity: all four repos show `updated_at` 2025-11-04T04:37:0xZ but no commits after 2022.
- The real codebase: https://github.com/Meshee-Team/vessel-contracts — "Vessel smart contracts". Created 2024-12-20T05:17:34Z; 2 commits only: "Initial commit" `f797d324` and "init commit" `be63bb87` (2024-12-20T05:27:16Z), both by `kevinyum.eth` (public commit email `ywk248248@gmail.com`).
  - Layout: `src/vault/` (Vault.sol, logic/UserApiLogic.sol, logic/ManagerApiLogic.sol, logic/MessageQueueLogic.sol, logic/MultiChainLogic.sol, generic/Storage.sol, Configuration.sol), `src/{affiliate,interface,misc}`, `script/`, `upgrade-reports/{2024-10-25-fast-withdraw, 2024-12-10-multi-chain}`, `test/integration`.
  - "vesselKey" confirmed in Vault.sol, Storage.sol, UserApiLogic.sol, MessageQueueLogic.sol, tests.
  - Vault.sol comment: "Only operator can commit SNARK proof to update on-chain state" — matches the operator/SNARK architecture under investigation.
  - README config: `OPERATOR_ADDRESSES` "eligible to manage tokens and users, and commit SNARK proofs"; `ADMIN_ADDRESS` "eligible to upgrade the vault and SNARK verifier"; `ENABLE_MULTISIG_ADMIN`/`SAFE_TX_SERVICE_URL`; `RELEASE_TAG` "GitHub release tag identifying the circuit release"; `GITHUB_TOKEN` "used to download the circuit release containing SNARK verifier bytecode" → circuits are distributed via a GitHub release; no public Vessel circuit repo located.
  - Exit LPs / fast withdraw: `script/prod-register-exit-manager.ts` hardcodes `exitManagerAddress = '0x9ee825d20db28393b49840c78707159777dfb38b'` and registers it as Exit Manager on the Vault (admin tx). Other scripts: prod-register-operator.ts, prod-update-snark-verifier.ts, prod-v3-deploy-new.ts, prod-v3-configure-lz-portal.ts.
  - Multi-chain: `.config.example.json` shows `"SUB_CHAIN_CNT": 2` with `LOGIC_CHAIN_ID`/`PRIMARY_LOGIC_CHAIN_ID`; `prod-v3-configure-lz-portal.ts` + `.gitmodules` (LayerZero-Labs/devtools) → cross-chain messaging used for fast withdraw. upgrade-reports/2024-12-10-multi-chain/ contains bytecode-size, gas profiles, storage layouts.
  - Deployed-source match: the public snapshot (2024-12-20) post-dates the 2024-10-25 fast-withdraw and 2024-12-10 multi-chain upgrades and includes their reports; structure/comments consistent with the deployed VaultProxy. Exact bytecode/commit parity NOT verified here (web-only). Confidence repo = codebase: high; parity: unverified.
  - Third-party address↔app confirmations: https://raw.githubusercontent.com/LedgerHQ/web3allowlist/master/dapps/trade.vessel.finance/dapp-allowlist.json → {"name":"Vessel","domain":"trade.vessel.finance","chains":{"scroll":[{"address":"0x6126e927627b8d9eb9adb9faadc47b76f94b6ba2"}]}}; also 0xtorch/datasource ABI DB (chain 534352, "TransparentUpgradeableProxy").
- Name sightings elsewhere (NOT Vessel deployments): `Solid-Money/solid-ui` (FastWithdrawManager ABI + hooks) and `Zelana-Labs/zelana` ("Zero Knowledge Solana, high speed privacy"; Rust `core/src/sequencer/bridge/fast_withdrawals.rs` defines FastWithdrawManager). No "vessel" strings in either; lineage unproven.

## 3) Socials, docs, announcements

- X https://x.com/VesselFinance (scraped 2026-10-12): 5,588 followers; latest posts 2025-01-22 ("Vessel x Scroll Session 2", https://x.com/VesselFinance/status/1882145810877690023), then 2025-01-17 and 2025-01-01 ("🎉 Happy New Year from Vessel Finance! … What's Coming for Vessel in 2025…"); pinned post 2024-08-08. No posts since 2025-01-22; no shutdown/migration/pause/hack announcement on X.
- Discord: https://discord.gg/vesselfinance → Discord API {"message": "Unknown Invite", "code": 10006} (2026-10-12). Dead.
- Telegram: https://t.me/vesselfinance resolves to a contact page (no public web preview; activity unverifiable via web).
- Medium https://medium.com/@vessel_finance: latest post 2024-11-06 ("VAELOB: Why Choose LP Strategy?"); posts Jun–Nov 2024 only.
- GitBook (LIVE, stale): https://vesselfinance.gitbook.io/vessel — community updates only Q1–Q3 2024. Key pages: smart-contract-deployments.md (Scroll-only), introducing-vessel.md ("…gradually evolving into a comprehensive Layer 3 network for DeFi"), technical-deep-dive/contract.md ("Vessel's contract acts as a secure vault … moved only under the constraints of valid SNARK proofs"; "Since Vessel open-sources its circuit repository, anyone can generate the SNARK verifier and compare its bytecode with the on-chain verifier").
- Linktree https://linktr.ee/vesselfinance: live (2026-10-12); links to trade app (dead), X, Discord (dead), GitBook, Medium, CoinGecko.
- CoinGecko https://www.coingecko.com/en/exchanges/vessel-finance: API shows year_established 2024, country Singapore, trust_score 0 (rank 1246), coins 0, pairs 0, volume 0 — no active markets.
- RootData: Vessel page https://www.rootdata.com/projects/detail/Vessel?k=MTE5MDU%3D shows a "2025 Crypto Dead Projects List" banner ("Updated Dec 30, 2025" per index snippet); list page https://www.rootdata.com/archives/detail/2025%20Crypto%20Dead%20Projects%20List?k=MjIyMTk2 ("Created Jun 5, 2025") snippet reads "Vessel. All-in-one ZK Exchange". RootData method article: https://x.com/i/article/2089696340540563830 (projects deemed dead on long website unavailability / >6-month social silence). Direct page fetches hit CAPTCHA; evidence from search snippets — confidence medium-high.
- No news/blog/Mirror post announcing shutdown, migration, or hack found.

## 4) Security incidents & audits

- No exploit/hack/post-mortem/"rekt" found for Vessel Finance (searches incl. "Vessel Finance exploit/hack/post-mortem/drained"; rekt.news). Nothing on rekt.news.
- No public audit found: DefiLlama audits "0"; no audit page in docs; no audits dir in the repo; no engagements found on Trail of Bits / Zellic / Veridise / Code4rena / Sherlock / Hacken / CertiK / OtterSec sites via search. No public bug bounty found.
- No known public vulnerability of this exact vault architecture surfaced. Caveat: absence of evidence ≠ proof (an audit may have been private; the repo going public 2024-12-20 could be audit-related — unverified).
- Related reference (different codebase): FastWithdrawManager custom errors seen in a sibling implementation ABI: `FastWithdrawManager__Paused`, `ERC20TransferFailed`, `InsufficientAmountOut`.

## 5) Other deployments / own L2–L3 / bridge UI

- Official docs list ONLY Scroll mainnet (GitBook smart-contract-deployments, live 2026-10-12): Vault `0x54e661Cf6B2aDC335d5201751F4C216AA25b63df`; VaultProxy `0x6126E927627b8d9eb9aDb9faadC47B76F94B6bA2`; ProxyAdmin `0x6251b4291ae357e63D9665dC2ABcD958e7CEe742`; VesselOwner `0x3c417EC088f19EA02Ac9853cd6c35Fb193c98Abe`.
- DefiLlama chains: ["Scroll"] only. Ledger allowlist: only the Scroll address. No second-chain VaultProxy found in public sources.
- Cross-chain logic is for withdrawals/bridging (MultiChainLogic.sol, SUB_CHAIN_CNT config, LayerZero portal) — not evidence of other-chain vault deployments.
- "L3" never shipped as far as the web shows: ambition only (GitBook; Q3-2024 Scuccinct/SP1 partnership note: "integrating SP1 to deliver a more agile, high-performance app rollup solution … toward our goal of becoming the comprehensive DeFi layer 3"). No launch announcement, no chain listing, no bridge UI beyond the dead trade app.
- Limitation: bytecode-level search across other chains was out of scope (web-only task).

## 6) Team and "founders of Scroll" claim

- Media claim (Gate Learn, last updated 2026-04-06, https://www.gate.com/learn/articles/what-is-vessel-finance-all-you-need-to-know-about-vessel/4172): "Vessel was created by the founders of the Scroll L2 network, Sandy Peng and Ye Zhang… mainnet launch in August 2024… $10 million seed… Sequoia Capital, Avalanche Foundation, and Algorand Foundation…" (Treat as marketing; same article contains an implausible "5 trillion VESSEL tokens on BSC" passage.)
- Funding (better sourced): $10M seed, 2024-08-08 — official X post https://x.com/VesselFinance/status/1821471653936898165 ("…secured $10M in seed round…"); DropsTab https://dropstab.com/coins/vessel lists investors: Sequoia Capital, Avalanche Foundation, Folius Ventures, IMO Ventures, Incuba Alpha, Algorand Foundation, Scroll itself, and angel Sandy Peng (Scroll co-founder as investor/angel — the "founded by Scroll founders" framing conflates investors with builders). Binance Square: https://www.binance.com/en/square/post/11891865276369. Mainnet-live announcement by Scroll: https://x.com/Scroll_ZKP/status/1822930865795596494 (Aug 2024).
- Actual operator identity found: `kevinyum.eth` (contracts repo author, 2024-12-20). GitHub search for "kevinyum" ambiguous; no public tie to Scroll found.
- Org github.com/Meshee-Team: 2 repos — vessel-contracts and poseidon-cross-platform (Go C-bindings for the Poseidon ZK hash over BN254; Jan 2024) — consistent with a ZK dev group. No public "Meshee" website found.
- No news of founders abandoning the project; abandonment is circumstantial (site/app down, socials silent since 2025-01, dead lists).
- Disambiguation: unrelated "Vessel" entities exist (Montreal fintech Vessel/Inovia, Hive wallet, maritime). Do not conflate.

## Confidence summary
- Website/app dead: high (DNS + multi-node HTTP checks + Jina timeouts; no root captures after 2026-02-11).
- Social silence / no public shutdown statement: high (X last post 2025-01-22; Discord API 404).
- RootData dead-list membership: medium-high (search snippets; pages CAPTCHA-walled).
- Contract repo = deployed codebase: high; exact bytecode parity: unverified.
- No exploit/audit found: medium (search absence, not proof).
- Scroll-only deployments: medium-high (official docs); cannot rule out undocumented deployments.

## Limitations
- No on-chain queries (task rules); DNS/HTTP/archives/search only.
- X data via scrape (may omit replies); Telegram history not web-verifiable.
- RootData/GitHub anonymous scraping intermittently blocked; some evidence from search snippets.
- Wayback SPA shells contain no readable body text; archived UI could not be rendered.
- Bytecode comparison and cross-chain bytecode search out of scope.

## Parent addendum (on-chain cross-checks of child claims, 2026-10-12)
- `0x9ee825d20db28393b49840c78707159777dfb38b` (exit manager hardcoded in the public repo's scripts): **no code, zero balance on Scroll; NOT registered as exit manager** on the live vault (`isExitManager=false`). It belongs to an undeployed v3 codebase.
- Live exit manager on the vault is `0x5bef2A1fCf34911e0Eb7b02376d1aB1c85cecfAc` (registered by governance tx at Nov-28-2024 through the Safe→executor path; verified on-chain).
- The deployed implementation `0x8804201FD6C0aBBcB62C158e51978893aA47785c` was deployed 2024-11-28 by the deployer EOA and is explorer-verified with `is_changed_bytecode=false`.
