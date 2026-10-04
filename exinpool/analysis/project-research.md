# ExinPool (H-24) — Project Research

- Research date: 2026-10-04 (all web facts fetched on this date unless noted)
- Scope: identity/architecture, staking/redemption flow, token, incidents, key management, audits
- Read-only; no transactions, no signing. No secrets referenced.
- Note: this file was produced by a read-only child research subagent and persisted verbatim by the parent.

## 1. Identity / Architecture

### Bot identity
- Mixin bot: display name "ExinPool", identity number 7000101761, bio "ExinPool is a staking platform powered by Exin."
- `GET https://api.mixin.one/codes/791f20db-51ce-4af2-918b-7496864ab833` (public, fetched 2026-10-04) returns:
  - `type: user`, `user_id = app_id = c48136b1-c5ab-437a-a079-9df1dc748f1b`
  - `identity_number: 7000101761`, `email: 7000101761@mixin.id`
  - `code_id: 791f20db-51ce-4af2-918b-7496864ab833`, `code_url: https://mixin.one/codes/791f20db-...`
  - `created_at: 2019-02-10T11:56:58Z`; `updated_at (app): 2024-03-04T12:57:22Z`
  - `is_verified: false`, `is_scam: false`, `is_deactivated: false`
  - user object `has_safe: true`; nested app object `has_safe: false`
  - `app_number: 7000101761`; `home_uri: https://mixin.exinpool.com`; `redirect_uri: https://mixin.exinpool.com/auth`
  - `capabilities: [CONTACT, GROUP, IMMERSIVE]`; `resource_patterns: [mixin.exinpool.com, w3c.group, eiduwejdk.co, mixin.one]`
  - `creator_id: f26ab3ca-1642-4dcb-9466-0c1ef03c5069`
- **code_id vs client_id (verified):** Mixin developer docs, "Codes" — `GET /codes/:id` "Get the code information by code ID"; code types are User / Conversation / Payment / Multisig Request / Collectible (https://developers.mixin.one/docs/api/codes, fetched 2026-10-04). Therefore `791f20db-51ce-4af2-918b-7496864ab833` is the **code_id** (the identifier used in `mixin.one/codes/...` invite links), **not the client_id**. The client_id (app_id) is `c48136b1-c5ab-437a-a079-9df1dc748f1b`. ExinPool's own docs use the code URL as the bot link (https://raw.githubusercontent.com/ExinOne/exinpoolsupport/main/docs/rewards.md).

### Operator and public code
- Operator: Exin team ("powered by Exin"). GitHub org github.com/ExinOne (15 public repos as of 2026-10-04): mixin-sdk-php, laravel-mixin-sdk, webhook, webhook-samples, secret-sharing, exinpool-support, exinpoolsupport, exinone-support, poolsupport (empty), mixin (fork of MixinNetwork/mixin), mixpay-doc, mixswap-doc, php-blake3-ext, developers.exinone.com, exinearn-website.
- Repos contain only docs/websites and Mixin SDKs. **No ExinPool application-server code and no smart contracts.**
- Docs repos: `ExinOne/exinpoolsupport` (Docusaurus source for support.exinpool.com) last commit 2024-07-15; `ExinOne/exinpool-support` (Jekyll help center for exinpool.support) last commit 2026-04-11 ("update").
- Mixin showcase lists ExinPool ("ExinPool is a staking platform powered by Exin", website https://mixin.exinpool.com): https://developers.mixin.one/showcase. Mixin homepage lists ExinPool under "Trusted By" (https://mixin.one, fetched 2026-10-04).

### Contracts
- **No ExinPool smart contract found** on Mixin MVM, Ethereum, Solana or elsewhere. GitHub search for "exinpool" returns only the two docs repos. No contract address appears anywhere in the docs. User positions ("shares", queue) are recorded in ExinPool's closed-source backend; node-level staking is done by the operator directly on each chain.
- Published on-chain node addresses (https://raw.githubusercontent.com/ExinOne/exinpool-support/master/docs/en/verify/*.md; live https://exinpool.support/en/verify/):
  - ETH: `0xdfce3cb1cbd896b96578005e14adb81ec26df923` (docs link to debank.com profile)
  - DOT: `13bmM6DEQtg6v6VCrfM8qaCFjTNnGzKJuBE4xbmHFkygrfB7`, `1X8WEKBnp1tpobBeLapMhJQt8VdUgresTPjtWYjnvJapjmZ`
  - SOL: 15 addresses (5c56eBCc…, F32WqhEn…, F7LZCt3L…, etc.)
- Quick on-chain check (Ethereum block 26,117,046, 2026-10-04): `0xdfce3cb1…` is a **contract** (172 bytes bytecode, nonce 1) with balance `10,749,914,106,534,813,988 wei` (~10.75 ETH) — consistent with a staking fee/withdrawal address, not a plain EOA. Not independently proven to be the validator owner.
- DefiLlama: protocol "ExinPool", category "Liquid Staking", chain Mixin, TVL **$10,211,625** (last point 2026-10-04), `audits: "0"`, listed 2022-08-22 (https://api.llama.fi/protocol/exinpool). DefiLlama's methodology line ("coins held in the smart contracts") is misleading here — there are no smart contracts; the value is operator custody.

## 2. Staking / Redemption Flow (as documented)

Sources: https://exinpool.support/en/guides/introduction, /rewards, /reservesplan, /nodes/mixin (fetched 2026-10-04) and raw docs at https://raw.githubusercontent.com/ExinOne/exinpoolsupport/main/docs/*.

- **Deposit:** "Phase One: Node Fundraising — ExinPool collects a certain amount of tokens for on-chain staking... ExinPool will then withdraw these assets for on-chain staking operations." Users "pay for XIN and join ExinPool"; for SOL "queuing to join directly at the ExinPool bot". In practice the user transfers the asset to the ExinPool bot's Mixin account (`c48136b1-...`) and the bot credits an off-chain position. The exact memo/trace-matching mechanics are not publicly documented (gap).
- **States:** "In the queue" → "Joined but not active" → "Joined and active (My shares)". Rewards snapshotted daily 08:00 Beijing time; paid after 15:00 Beijing (frequency varies by chain; XIN since the Safe migration no longer guaranteed daily; DOT ~daily/era; SOL every 2–3 days; AXS monthly 24th–26th; ETH daily).
- **Queue:** joining waits for exits and vice versa; "Final decisions depend on queue position and share quantities." If exits pile up with no new joins, ExinPool says it "will dissolve a certain amount of sub-nodes or quantity to satisfy user liquidity."
- **Fees:** queue-cancel 1 EPC; active exit 0.2% service fee, EPC deduction supported (possibly fee-free). The "1%" in the bot intro refers to *early exit from the Mixin mainnet node*, charged by the mainnet, not ExinPool (https://exinpool.support/en/nodes/mixin; raw docs/Nodes/mixin.md).
- **Delays / reserve fund:** Reserve Fund Plan for SOL/DOT to speed joins/exits: DOT join ~2 days, exit up to 28–30 days; SOL ~3 days each way. "Due to funding limits, large transactions may still require waiting" (ReservesPlan). Reserve = ExinPool's own SOL/DOT used to take the user's place.
- **Redemption guarantee:** none on-chain and no contractual guarantee. Exit depends on queue liquidity, reserve fund size, or node dissolution; DOT exit can take up to a month. Payouts are "made to Mixin wallet" — i.e., signed and sent by ExinPool's server (closed-source; key custody undisclosed).
- **Minimums:** no minimum documented in public docs (gap).
- **Lock-up:** optional XIN lock-up earns 0.1 XIN/day extra (old docs) plus EPC (1 EPC/day per 10 XIN locked); not required for rewards.
- **Old node stats (docs last updated 2024-07-15):** 4.2678 Mixin nodes (4 self-owned + 0.2678 joint, joint run rotationally by Exin and Fox teams), 57,356 XIN staked.

## 3. Token / EPC

- **No ExinPool share or liquid-staking token found.** Searches for "ExinPool Coin", "EPC ExinPool token" return only ExinOne's EPC fee-point card.
- **EPC = ExinOne fee-point card (手续费点卡)**, a Mixin asset used to offset ExinOne fees and ExinPool node-exit fees (https://support.exinone.com/docs/Features/EPC; Mixin monthly report #52, 2023-06: EPC faucet bot 7000105001).
  - Earn channels: daily sign-in @7000105001 (0.001024 EPC/day), first ExinOne login (1 EPC), ExinPool XIN lock-up (1 EPC/day per 10 XIN), asset-score airdrops, tasks, commissions.
  - **EPC User Use Agreement** (archived 2026-04-18: https://web.archive.org/web/20260418045015/https://support.exinone.com/docs/About-Us/User-Agreement/EPC-User-Use-Agreement): "All EPCs are activity rewards, not for sale, and do not provide a transaction portal, so the platform does not promise to buy back. The platform is not responsible for the loss of user EPCs if the company closes down due to poor operation..." → EPC carries **no claim** on ExinPool assets; it is not equity, shares, or a redemption right.
- EPC is transferable between Mixin wallets (users must hold EPC in the Mixin wallet to pay ExinPool exit fees). No public asset_id / supply / mint mechanism found (gap).

## 4. Incidents Timeline

1. **2020-02-17 — FCoin collapse; ~$5M of ExinOne customer savings stuck.**
   - FCoin founder's "FCoin Truth" default: 7,000–13,000 BTC (~$67–125M) (https://www.theblock.co/news/markets/2020-02-17-cryptocurrency-exchange-fcoin-expects-to-default-on-as-much-as-125m-of-users-bitcoin-56191).
   - ExinOne (same Exin team) announced its 余币宝 savings held assets in FCoin wealth accounts; affected user assets: 70% BTC, 90% BCH, 50% ETH, 50% USDT, 5% EOS unable to withdraw; >$5M invested (BlockTempo https://www.blocktempo.com/fcoin-closed-how-to-do-as-for-investors/, Feb 2020; 163.com https://www.163.com/dy/article/F7KJ78RI05379YSJ.html, 2020-03-13).
   - PANews later confirms ExinOne issued bonds/delayed repayment (https://www.panewslab.com/zh-hant/articles/wfv8ovrf, 2023-09-25).
   - **Implication:** documented history of customer-fund loss via third-party counterparty risk and haircut/bond resolution.
2. **2020-03-21 — Joint node key loss: 10,000 XIN.**
   - Fox.ONE (now Pando), ExinPool and the SS team jointly ran a XIN node with **3-of-3 multisig** key management; the SS team failed to safeguard the key and 10,000 XIN were lost. Loss allocation: Fox.ONE 5,250 / **ExinPool 3,600** / SS 1,150 XIN (Mixin Discourse https://discuss.mixin.one/questions/D1Tg, posted 2024-09-10).
   - Community comments state users were compensated (~90%) at the time; a 2024 proposal + snapshot vote decided the use of the recovered 10,000 XIN (https://discuss.mixin.one/questions/D1wn, 2024-09-24; snapshot.org mixin-autonomous-organization.eth; recovery migration mentioned 2024-12-23).
   - **Implication:** direct evidence of node-key mismanagement in ExinPool's joint node, and that "multisig" did not prevent loss (one signer team lost its key material).
3. **2023-09-23 — Mixin Network hack (~$200M).**
   - Cloud-provider database compromise; deposits/withdrawals suspended (TechCrunch 2023-09-25 https://techcrunch.com/2023/09/25/hackers-steal-200-million-from-crypto-company-mixin; CoinDesk 2023-09-25).
   - Exin team's 2023-09-25 handling notice: **for ExinPool, only XIN supported queue join/exit; other coins temporarily unsupported**; ExinOne savings withdrawal-only, no deposits to trading account, lending paused; MixPay paused (PANews via TradingView https://www.tradingview.com/news/panews:90d52762bacdf:0/).
   - ExinOne's post-mortem page: all Mixin-wallet-based bots affected; compensation max 50% + bond tokens (founder livestream); 2023-10-09 withdrawals returned, deposits not credited until the new system (https://support.exinone.com/docs/Instructions/about923 — page currently DNS-unreachable from this session; content indexed).
   - Founder said XIN/BOX were not severely stolen; stolen assets were mainly BTC/ETH/DAI, mostly from B.watch (PANews 2023-09-25; blofin.com 2023-09-25).
   - ExinPool TVL: $16.02M (2023-09-23) → $13.30M (2023-12-31) → $16.90M (2024-12-31) (DefiLlama series). No public evidence ExinPool customer principal was stolen; operations for non-XIN queues were interrupted, and XIN reward distribution changed after the network migration.
4. **End of Oct 2023 — Mixin moves to Safe-based network.** "Mixin Network went live with a more secure, Safe-based network at the end of October 2023" (https://support.mixin.one/en/category/wallet-features-epr6vk). ExinPool docs: "Mixin node has migrated to the Safe network"; XIN rewards no longer daily/guaranteed (https://exinpool.support/en/guides/rewards).
5. **2024-09 — Joint-node XIN recovery controversy** (D1Tg/D1ii/D1wn): opposition proposals, vote-manipulation criticism ("quorum 100 XIN for 10,000 XIN"). Not a user fund-safety incident.
6. **2024–2026 — no ExinPool-specific insolvency, withdrawal freeze, hack or exit-scam evidence found.**
   - Searches (EN+CN): "ExinPool 提现/被盗/跑路/暂停", "ExinPool withdrawal suspended/scam", Reddit, Bitcointalk, Medium, X, Mixin Discourse (search API: 9 results, none reporting stuck funds). The only fund-loss events are the 2020 FCoin, 2020 joint node, and 2023 Mixin hack.
   - DefiLlama TVL still ~$10.2M with recent inflows (+9.7% 30d per the protocol page); help center updated 2026-04-11 (GitHub commit); exinpool.support live (200). The legacy web app mixin.exinpool.com is 503 and support.exinpool.com is 526 (Cloudflare) as of 2026-10-04.

## 5. Key Management Evidence

- Docs (current): "Private keys managed by core team members; Multi-signature backups; Controlled risk measures" (https://exinpool.support/en/nodes/mixin). Old docs: node private keys "managed by core team members with multi-signature backups"; "ETH, SOL, and DOT nodes are all managed using multi-signature technology" (raw docs/Nodes/mixin.md, introduction.md).
- **ExinOne/secret-sharing** (https://github.com/ExinOne/secret-sharing): Python tool implementing **Shamir's Secret Sharing** (PlaintextToHexSecretSharer), "Split private key into multisig", default 3-of-5, up to 10 shares; author `robin@exin.one`; created 2019-08-18, last push 2023-07-28. Not explicitly referenced by ExinPool docs, but it is the team's published key-backup method.
- Joint node used **3-of-3 multisig across three teams** (D1Tg) — and still lost 10,000 XIN in 2020 through one team's key mishandling.
- XIN node: on the **Mixin Safe network** post-Oct-2023. Mixin Safe is a 2-of-3 multisig + timelock product (owner/members/recovery) with an MPC-generated members key (https://github.com/MixinNetwork/safe; https://safe.mixin.one, which lists ExinPool among partners). The ExinPool bot user object reports `has_safe: true` (API, 2026-10-04).
- **Payout signing:** outgoing user transfers are signed by the ExinPool closed-source server. No public documentation of the bot's Mixin key custody. Not verifiable externally.
- **Deposit-credit attack class:** Mixin bots that credit deposits from unverified webhook payloads are exposed to fake-deposit spoofing (SlowMist documents the class: https://github.com/slowmist/knowledge-base). ExinOne's open-source SDK offers the safe pattern — `verifyPayment` (POST `https://api.mixin.one/payments`) and `readUserSnapshots` (`/snapshots`) — server-side verification against the Kernel API (https://raw.githubusercontent.com/ExinOne/mixin-sdk-php/master/config/config.php; src/Apis/Wallet.php). Note: `ExinOne/webhook` (https://github.com/ExinOne/webhook) is a **message-forwarding service** (webhook.exinwork.com, group-chat/GitHub forwarding), unrelated to payment crediting. Whether ExinPool's own server actually verifies each incoming snapshot cannot be determined (closed source).

## 6. Audits

- DefiLlama: `audits: "0"`, no audit links (https://api.llama.fi/protocol/exinpool, 2026-10-04).
- **No audit or security review of ExinPool or ExinOne found.** Searches "ExinPool audit / 审计 / 慢雾" returned no certificate or report; slowmist.com has no ExinOne/ExinPool certificate indexed; ExinPool docs never mention an audit.
- Packagist security advisories for `exinone/mixin-sdk-php`: 0 (https://packagist.org/packages/exinone/mixin-sdk-php/advisories) — not an audit of the service.
- Mixin Safe (network layer, not ExinPool) claims an "ongoing security audit process" (https://safe.mixin.one).
- **Negative result recorded explicitly.**

## 7. Open Questions / Blockers

- Is the ExinPool bot fully operational today? The web app mixin.exinpool.com returns 503 and support.exinpool.com returns 526; the docs moved to exinpool.support (live, updated 2026-04). The bot cannot be probed without a Mixin account. DefiLlama TVL activity suggests live operation, but this is unverified.
- Deposit memo/trace mechanics; whether every deposit is credited only after Kernel snapshot verification (closed source).
- Bot Mixin signing-key custody; whether payouts use Safe/multisig.
- EPC asset_id, total supply, mint authority (no public data).
- Current XIN node count and stake (docs defer to the bot); whether ExinPool nodes appear in Mixin's validator set (mixin.space blocked by Cloudflare in this session).
- Whether `0xdfce3cb1…` remains an active ETH validator withdrawal address (validator index not resolved).
- **Architectural conclusion:** because user accounting is off-chain and no user-facing contracts exist, an external unprivileged attacker has **no public-contract extraction path** against ExinPool funds. Extraction would require off-chain compromise of ExinPool/Mixin infrastructure (not unprivileged), or a protocol-level Mixin failure. This follows from absence of contracts, not from a code audit.

## 8. Sources (selected)

- https://api.mixin.one/codes/791f20db-51ce-4af2-918b-7496864ab833 — bot profile JSON (fetched 2026-10-04)
- https://developers.mixin.one/docs/api/codes — code_id semantics (fetched 2026-10-04)
- https://developers.mixin.one/showcase — ExinPool listing
- https://exinpool.support/en/guides/introduction, /rewards, /reservesplan, /nodes/mixin, /nodes/nodesinfo, /verify (fetched 2026-10-04)
- https://raw.githubusercontent.com/ExinOne/exinpoolsupport/main/docs/{introduction,rewards,ReservesPlan,Verify,nodes}.md and docs/Nodes/{mixin,ethereum,solana}.md
- https://raw.githubusercontent.com/ExinOne/exinpool-support/master/docs/{en,zh}/guides/introduction.md; /verify/*.md
- https://github.com/ExinOne/{exinpoolsupport,exinpool-support,secret-sharing,mixin-sdk-php,webhook} (repo metadata + raw files, fetched 2026-10-04)
- https://api.llama.fi/protocol/exinpool — TVL series, audits=0 (2026-10-04)
- https://support.exinone.com/docs/Features/EPC; https://web.archive.org/web/20260418045015/https://support.exinone.com/docs/About-Us/User-Agreement/EPC-User-Use-Agreement
- https://support.exinone.com/docs/Instructions/about923 (indexed content, 2023-09); https://www.tradingview.com/news/panews:90d52762bacdf:0/ (2023-09-25)
- https://discuss.mixin.one/questions/D1Tg (2024-09-10); https://discuss.mixin.one/questions/D1wn (2024-09-24)
- https://techcrunch.com/2023/09/25/hackers-steal-200-million-from-crypto-company-mixin; https://www.coindesk.com/tech/2023/09/25/mixin-network-losses-nearly-200m-in-hack
- https://www.panewslab.com/zh-hant/articles/wfv8ovrf (2023-09-25); https://www.blocktempo.com/fcoin-closed-how-to-do-as-for-investors/ (2020-02); https://www.163.com/dy/article/F7KJ78RI05379YSJ.html (2020-03-13); https://www.theblock.co/news/markets/2020-02-17-cryptocurrency-exchange-fcoin-expects-to-default-on-as-much-as-125m-of-users-bitcoin-56191
- https://support.mixin.one/en/category/wallet-features-epr6vk — Safe-based network end Oct 2023
- https://github.com/MixinNetwork/safe; https://safe.mixin.one — Mixin Safe design and partner list
- https://github.com/slowmist/knowledge-base — fake-deposit attack class
- Wayback CDX: mixin.exinpool.com captures 2022-01-21, 2022-06-26, 2023-06-15, 2023-10-04; exinpool.com 2020–2021; support.exinone.com CDX 2020–2026
