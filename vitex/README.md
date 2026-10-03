# H-05 · ViteX (Vite) — deep-dive

**Date:** 2026-10-03 · **Chain:** Vite (DAG ledger; native built-in contracts + Solidity++; non-EVM)
**Status:** read-only; no transactions sent; no secrets committed; verification by exhaustive
endpoint probing, archive reconstruction and source-level contract audit (no fork/PoC is possible
for a non-EVM chain with no reachable node).

**Finding as given:** DefiLlama last-known $4.94M, TVL stale 1237d, 0 audits, "dead 2025-03-01";
"DEX on a dying Vite chain; native-contract review needed."

**Sub-reports:** `analysis/child-a-liveness.md` (endpoint/chain-status hunt, 61 raw evidence
files) · `analysis/child-b-contract-audit.md` (native-contract audit, excerpts in
`analysis/contracts/`) · `analysis/00-endpoint-evidence.md`, `analysis/01-timeline.md`,
`analysis/02-ci-runs.md`.

---

## 1. TL;DR

| Target | Live extractable (unprivileged) | Why | Latent risk |
|---|---|---|---|
| ViteX DEX on Vite — DexFund `vite_…06e82b8ba657`, DexTrade `vite_…079710f19dc7` (native built-ins) | **$0** | **No Vite mainnet node is reachable by anyone.** Every official endpoint is decommissioned (DNS CNAMEs point at deleted AWS ELBs/API Gateways), no community/third-party node or RPC provider exists, and the project migrated to Solana (JEETS) in May 2025 citing node/explorer disruptions and "technical vulnerabilities". An attacker has no entry point to submit or read transactions. | If a node were ever republished: the source audit of the final mainnet code (go-vite v2.14.0) found **no unprivileged value-extraction path**; two latent *loss/liveness* defects exist (C5 stuck stake refund, C6 fee-roll panic). The ~4.94M is 2023-era **gateway-minted USDT** whose gateway operators are all gone → no redemption value even if drained. |

**Total live extractable now: $0** (confidence: **high** — ~97% that no node is reachable,
~80–85% that the chain is halted).

**Stuck/unreachable:** last-known ~$4.94M = 4,944,710.11 Vite-USDT held by DexFund at Vite
snapshot height 122,615,899 (~2023-05-13), frozen with the chain; external value ≈ $0 (gateway
IOUs, all gateways closed). Classified **S**, not extractable by anyone.

---

## 2. What ViteX is (deployment reconstruction)

ViteX is **not** a set of user Solidity++ contracts. It is implemented as **native built-in
contracts inside the Vite node software** (`go-vite`, `vm/contracts/`, last release v2.14.0,
2024-09-25; repo abandoned after that). A transaction to a built-in address dispatches on
`(ToAddress, 4-byte selector)` via `GetBuiltinContractMethod()` (`vm/contracts/contracts.go:252`),
with the active method map selected by fork height.

| Contract | Address | Role |
|---|---|---|
| DexFund | `vite_0000000000000000000000000000000000000006e82b8ba657` | user balances/escrow, order funds, staking, mining, dividends |
| DexTrade | `vite_00000000000000000000000000000000000000079710f19dc7` | on-chain order book + matcher (holds no token balances) |
| Quota | `vite_0000000000000000000000000000000000000003f6af7459b9` | VITE staking / quota / delegate-stake callbacks |
| ConsensusGroup | `vite_0000000000000000000000000000000000000004d28108e76b` | SBP governance/voting |
| Asset | `vite_000000000000000000000000000000000000000595292d996d` | token issuance / ownership |
| VX token | `tti_564954455820434f494e69b5` | ViteX Coin (mining reward / dividend token) |
| VITE token | `tti_5649544520544f4b454e6e40` | native |
| USDT (gateway) | `tti_80f3751485e4e83456059473` | gateway-minted USDT, mapped to ETH `0xdac17f…3d831ec7` / BSC `0x55d398…3197955` |

Final mainnet fork heights (`common/upgrade/upgrade_init.go`): … V12 116,480,000 → V13
166,869,900 → VersionX 1,000,000,000 (**never reached**). Therefore the active map at shutdown
was `dexEnrichOrderContracts`: `AgentDeposit` and `AssignedWithdraw` were **never enabled**;
`Transfer` (v1.1) was enabled.

Privileged roles: **owner** (`vite_a8a00b3a2f60f5defb221c68f79b65f3620ee874f951a825db` or
genesis-configured), **timeOracle** (`NotifyTime`), **periodJobTrigger** (`TriggerPeriodJob`),
**makerMiningAdmin/maintainer** (`SettleMakerMinedVx`), and per-market **market owner**
(`MarketAdminConfig`). DexFund's real balances must cover the internal liability formula
(`VerifyDexFundBalance`, `fund_verifier.go:28`).

---

## 3. Live-state assessment (what is actually reachable today)

**No Vite mainnet RPC/node is reachable.** Verified 2026-10-03 from two independent networks
(author host + GitHub Actions Azure runner, run 37132690689) and from 9+ check-host.net countries:

| Endpoint | DNS | Result |
|---|---|---|
| `node.vite.net` (official node) | CNAME → `vitenode-837259984.us-east-1.elb.amazonaws.com` → **NXDOMAIN** | dead (ELB deleted) |
| `bootnodes.vite.net/bootmainnet.json` (P2P seed list) | CNAME → deleted API Gateway `d-5j0jymw5ua` | dead — cannot bootstrap |
| `vitex.vite.net`, `gateway.vite.net`, `crosschain.vite.net`, `buidl.vite.net`, `stats.vite.net`, `reward.vite.net`, `static.vite.net` | NXDOMAIN | dead |
| `config.vite.net`, `api.vite.net` | CNAME → deleted API Gateway hosts | dead |
| `biforst.vite.net` (ViteConnect) | CNAME → deleted ELB | dead |
| `vitescan.io` (official explorer) | A=47.240.225.75 | TCP timeout from 9+ countries; ports 80/443/48132 |
| `vitex.net`, `api.vitex.net` | Cloudflare REFUSED (zone removed) | dead |
| `vitex.network` (migrated DEX site) | 200 | static 2023-06-21 Nuxt build; API base `vitex.vite.net/api` dead |
| `vite.net`, `explorer.vite.net` (GitHub Pages) | 200 | SPA shells whose JS hardcodes the dead node/ViteX endpoints |
| `mainnet.viteview.xyz` (3rd-party) | 200 | static SPA; node `node.vite.net`; POST rejected |
| `vitcscan.com` (3rd-party) | 502 | origin down |
| `vitetxs.de`, `viteexplorer.eu`, `vite.io`, `vite.wiki` | NXDOMAIN / repurposed | dead |
| `148.70.30.139:48132`, `132.232.60.116:8001` (app-config test nodes) | IP | timeouts |
| RPC providers (NOWNodes, Ankr, GetBlock, dRPC, Chainstack, Tatum, PublicNode, BlockPI, OnFinality, Pocket, Alchemy) | — | **none support the Vite chain** |

Community/private nodes: every public repo (wallets, explorers, SDKs, staking tools, rosetta-vite)
hardcodes the dead official endpoints; CT + DNS brute force + passive DNS found no alternative.
The official Zendesk help center is deactivated.

Chain-status evidence: Feb 2025 server outage/partial recovery; Binance delisted VITE 2025-02-24;
Vite Labs closed its gateway 2025-03-10; 2025-03-27 statement: funds lost to DWF market-making +
delisting, all roadmap canceled, network maintained "only until it can no longer support it";
2025-05-22 migration to Solana JEETS citing "node and explorer disruptions" and "technical
vulnerabilities"; MEXC 2025-05-30: "instability issues on the VITE mainnet, which often cause
network disruptions"; r/vitelabs "Vite is dead… nowhere to send it" (Jul 2025); CoinGecko delisted
VITE and VX. The JEETS claim page (archived 2025-10-03) declares a Vite-network snapshot moment of
**2025-11-11 00:00 UTC** and "No live checks" — i.e. not even the migration team was querying a
public node. No public snapshot height survives anywhere.

---

## 4. What an attacker can / cannot do

- **Cannot** read or write the Vite ledger: no reachable node, no bootnode list, no explorer API,
  no provider. There is no transaction relay, so no call path can be constructed today.
- **Cannot** forge privileged senders: `SettleOrders` is DexTrade-pinned, stake/token-info
  callbacks are Quota/Asset-pinned at send creation, owner/oracle/trigger/admin checks are stored
  in DexFund (`child-b-contract-audit.md` §b).
- **Cannot** debit another user: all fund debits use the sender's own internal account; the two
  agent flows require a per-market grant recorded against the grantor's own address.
- **Cannot** redeem the gateway assets: Vite-USDT/ETH/BTC were gateway IOUs; Vite Gateway closed
  2025-03-10; VGATE's domain now redirects to an unrelated gambling site; other operators dead.
- **Could not profit even if a node reappeared** without solving gateway redemption, and the
  source audit found no unprivileged extraction bug to exploit in the first place.

---

## 5. PoC / verification

Non-EVM chain, no reachable node → no fork/PoC possible. Verification is by:

1. **Endpoint/liveness proof** — DNS (Google DoH, certspotter, crt.sh), HTTP/TCP probes from two
   networks, check-host.net global checks, Wayback/archive.today, GitHub-wide code search,
   provider chain lists. ~60 hostnames/IPs; all dead. CI run 1 (success):
   https://github.com/kingmariano/ca-zombie-ci/actions/runs/37132690689
   (final repeat run URL in `analysis/02-ci-runs.md`).
2. **Archived-state reconstruction** — DefiLlama adapter history (last real TVL update 2023-08-23,
   100% USDT), the community worker `vite-info-api.xvite.workers.dev` (frozen JSON,
   snapshotHeight 122,615,899, updateTimestamp 2023-05-13), migration/airdrop posts, gateway
   profiles.
3. **Source-level native-contract audit** — go-vite v2.14.0 (`vm/contracts/*`, `vm/contracts/dex/*`,
   `vm/vm.go`), with unit tests run locally (`go test ./vm/contracts/dex/...` → ok). No
   unprivileged extraction path found. Two latent non-theft defects confirmed by code reading
   (and re-verified by the parent):
   - **C5** `contracts_dex_fund.go:879` — inverted equality check in the V2 stake-failure callback
     (stuck VITE, no attacker gain; very low reachability).
   - **C6** `dex/fund_storage.go:1157` — `RollAndGentNewDexFeesByPeriod` panic if the previous
     period's fee record was deleted; any trader can trigger a trading freeze once the state
     precondition exists (DoS only).

### Negative results (dead ends — do not re-investigate)

| Path tried | Result |
|---|---|
| Official node/RPC/WS, testnet, bootnodes, stats, config/api/gateway/crosschain | DNS-dead or deleted AWS targets |
| Official + third-party explorers (vitescan.io, viteview.xyz, vitcscan, vitetxs.de, viteexplorer.eu) | timeouts / 502 / static SPA with dead node |
| `vitex.network` migrated site | static 2023 build; dead API base; no `api./node.` subdomains |
| RPC providers and chain indexes (Alchemy, Ankr, GoldRush, chainid.network, …) | no Vite support |
| Community repos/SDKs/wallets/rosetta | all hardcode dead official endpoints |
| Gateway operators (Vite Gateway, VGATE, XGate, Kivigate, ViNo, ExperimentDAO) | all shut down |
| JEETS claim site / tweets | jeets.ai NXDOMAIN; announcement tweet deleted; JEETS itself ~$5K FDV, $0 volume |
| go-vite issues/PRs for an exploitable DEX bug | historical fixes only (#481, #492, #609); issue #608 affects a VersionX-only method |

### Cross-chain note (out of scope for H-05)

The VITE ERC20 `0x1b793e49237758dbd8b752afc9eb4b329d5da016` (Ethereum) and BEP20 are separate
deployments; the ViteX DEX and its escrow exist only on the Vite chain. The 4.94M was Vite-chain
USDT, not an ERC20 balance.

---

## 6. Verdict & residual risk

**Verdict: E-U = $0 · H-O = $0 (no reachable chain) · P = $0 · S ≈ last-known $4.94M Vite-USDT
(frozen/unreachable, gateway IOUs).** Confidence: high for "no reachable node and no public
extraction path" (~97%); medium-high for "chain halted" (~80–85%, inferred from infrastructure
decommissioning + migration + community reports; no direct node probe is possible).

Residual/latent risk: if a Vite node is ever republished, DexFund would again be callable with its
2023-era balances. The code audit found no unprivileged extraction bug in v2.14.0; the main
monitoring priorities would be the C6 fee-roll panic, the C5 stuck-refund path, `VerifyDexFundBalance`
drift, and the configured admin addresses. Even then, the gateway-asset redemption problem caps
real extractable value at ≈ $0 unless a gateway is revived.

Blockers: no node, no explorer, no bootnode seed, no gateway, delisted/migrated tokens, abandoned
chain.

---

## 7. Methodology, caveats, files

**Methodology:** DNS (Google DoH, certspotter, crt.sh, passive DNS), HTTP/TCP probes from two
networks, check-host.net global checks, Wayback/archive.today/Common Crawl, GitHub code/commit/
issue search, provider chain lists, DefiLlama API + historical adapter source, community API
snapshot, migration/airdrop announcements (fxtwitter capture of the official tweet), and a
source-level audit of the go-vite native contracts with unit tests.

**Caveats:** absence of a public node cannot 100% exclude an IP-only/regional node (CN vantage not
tested); "halted" is inferred, not directly observed; the $4.94M is a 2023 reading with no 2024+
verification; the JEETS 2025-11-11 snapshot date implies the migration team had *some* chain data
but provides no public proof of live production; the audit is manual (no formal verification/fuzzing
of the matcher arithmetic).

**Files index:**
- `README.md` — this report
- `summary.json` — machine-readable headline
- `analysis/00-endpoint-evidence.md` — consolidated endpoint evidence
- `analysis/01-timeline.md` — dated evidence timeline
- `analysis/02-ci-runs.md` — CI runs and results
- `analysis/child-a-liveness.md` + 61 `child-a-*` raw files — liveness/endpoint hunt
- `analysis/child-b-contract-audit.md` + `analysis/contracts/` — native-contract audit
- `analysis/raw/` — DefiLlama JSON, old adapter source, community API snapshot, tweet capture
- `ci/run.sh`, `ci-out/`, `ci-artifacts/`, `ci-log.txt` — CI job and artifacts
