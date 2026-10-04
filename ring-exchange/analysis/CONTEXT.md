# H-31 Ring Exchange — shared context for child subagents

Read `/home/heisenberg/CA/ci/SUBAGENT-BRIEF.md` rules: read-only on mainnet (no sends), no secrets in files,
write ONLY inside your assigned subfolder of `/home/heisenberg/CA/ring-exchange/analysis/`, no further children.

## What Ring is (verified so far)

Ring Protocol on HyperEVM (chainid 999, RPC https://rpc.hyperliquid.xyz/evm, latest ~block 47,615,000).
Docs: https://docs.ring.exchange (sections: contracts/v2, contracts/v4). Repos: github.com/RingProtocol
(few-v2-core, few-periphery, few-factory, audits, RingV4JitHook, FewV4ShellHook, RingFallbackHook,
RingShareLiqHook, ring-v4-aggregator-hook-audit).

Two-layer design: "Few Protocol" = 1:1 wrapper factory (FewFactory) that mints `fw<TOKEN>` wrappers for any
ERC-20; "Ring Swap" = Uniswap-v2 fork whose pairs trade the WRAPPED tokens, not the originals.

### Verified addresses (HyperEVM)
- Core (Fei-style AccessControl): 0x1cda28aD2915356EB618518b1bDD3f462aeF3803 — init() already called
  (block 8,621,134); deployer 0xa3142fdc… renounced gov; current governor = Timelock 0x03709dfd8145b618af0e06b48dd76258d8ef2e2f;
  minters = 0x9336D0C82299Da0ab178271792954ADFD6f10fD7 (EOA) and 0xc38f2fd561d748ce74a5f9ce09b89d2cf421fb56 (contract).
- SwapV2Factory: 0x4AfC2e4cA0844ad153B090dc32e207c1DD74a8E4 (5 pairs only; feeTo=0, feeToSetter=EOA 0x9336…)
- SwapV2Router: 0x701D1d675415efA2d2429fB122ccC6dD4FCcA959 (verified source in analysis/src/router)
- FewFactory: 0x6B65ed7315274eB9EF06A48132EB04D808700b86 (5 wrapped tokens; paused=false; permissionless createToken)
- FewETHWrapper: 0x068B60ECbC934b0a0dde20FdFf0dE925b97B971F (verified; holds 0 WHYPE, 0 native)
- UniversalRouter: 0xE65081EFa5ad4A196B1Df768716c337e6AB140E9 (verified, v0.8.26, Uniswap v4-periphery based; holds 0)
- Permit2: 0x000000000022D473030F116dDEE9F6B43aC78BA3

### Wrapped tokens (all verified FewWrappedToken v0.6.6; wrap/unwrap 1:1)
| token | address | underlying | supply | underlying held by wrapper |
|---|---|---|---|---|
| fwWHYPE | 0x9e1148bC3665a9f7C35F313d89c0432c34928AEf | WHYPE 0x5555…5555 | 1,185,181.23 | 20,181.23 |
| fwUETH | 0x0C47cbbEDE5d8c6f9614cF770C26c3315205C397 | UETH 0xBe6727B535545C67d5cAa73dEa54865B92CF7907 | 28,709.47 | 1,109.47 |
| fwUSDC | 0xd2646b9B02859416D8cBc759F85f0676f6E19974 | USDC 0xb88339CB7199b77E23DB6E890353E22632Ba630f | 10,000,000.0 | 0.000052 |
| fwUSD₮0 | 0x7576dd9a2775bFd789616d9eA7A2af21d06782D0 | USDT0 0xB8CE59FC3717ada4C02eaDF9682A9e934F625ebb | 10,000,000.01 | 0.014862 |
| fwUSDH | 0x09D21E89EF332347eb3E1E496f1265a600e364C1 | USDH 0x111111a1a0667d36bD57c0A9f569b98057111111 | 10,000,600.43 | 6,004.29 |

The ~27,600 fwUETH / 1,165,000 fwWHYPE / 10M of each fw-stable were minted UNBACKED by the minter EOA
0x9336D0C8… (Mint events; e.g. fwWHYPE mints at blocks 0xb92410, 0xce1e96, 0xdeb779, 0x13c9a7d, 0x1d4da4b).
Recipients: the EOA itself and EOA 0x4f0aa5900b8292273b2f9a178d5468f8048bb9a9 (holds 136,238.7 of the
150,002.9 LP of pair fwUETH/fwWHYPE; the 0x9336 EOA holds the other 13,764.1).

### Pairs (all verified SwapV2Pair v0.5.16; standard Uni v2 math, 0.3% fee, feeTo=0)
| pair | address | reserves (latest) | LP supply | nominal USD |
|---|---|---|---|---|
| fwUETH/fwWHYPE | 0x0185E8e8B7FDf22638ecB2D781b3EA7E8AA2452a | ~28,419.5 fwUETH + ~851,037.6 fwWHYPE | 150,002.86 | ~$152.5M (GT) |
| fwUSDH/fwUSDC | 0xabEd9A9aDe03a80ED98f903Eb9db62DE55C9DDF3 | 4,999,967 fwUSDH + 5,000,048 fwUSDC | 5,000,000 | ~$10M |
| fwUSDH/fwUSD₮0 | 0xf37f1e83BEb55F1b88AF9A8Df1a746e79C222150 | 4,990,080 fwUSDH + 4,989,943 fwUSD₮0 | 4,990,000 | ~$10M |
| fwUSD₮0/fwUSDC | 0x8868a630dD13A954D3f8B186508EF6c733BE959F | 4,990,050 fwUSD₮0 + 4,989,952 fwUSDC | 4,990,000 | ~$10M |
| fwUSD₮0/fwWHYPE | 0xf3760B19f1Baa2bFcf6Bd6e5d174e129c80aeD17 | 7.35 fwUSD₮0 + 0.083 fwWHYPE | 769.76 | ~$7 |

Prices (DefiLlama, 2026-10-04): WHYPE $89.73, UETH $2,691.51, USDC $1.0000, USDT0 $0.9998, USDH $0.9996.
Pool[1] spot 29.9456 fwWHYPE/fwUETH vs market 29.9952 → ~0.17% rich; no obvious arbitrage (0.3% fee).

### Key open questions (E-U extraction)
1. Can an unprivileged attacker mint fw tokens? (MINTER_ROLE holders above). Launchpad contract 0xc38f2fd5
   has MINTER_ROLE, is unverified, ~10.5 KB, only 2 lifetime txs, holds nothing. Selectors seen:
   mint(0x40c10f19), createToken(0xc21ab7f9), unwrapTo(0x5dbd6059), setThreshold(0x960bfe04, Ownable-gated),
   threshold()=1e19, MAX_THRESHOLD()=1e21, TOTAL_SUPPLY()=1e27, creators(address), uniswapRouter()=0xcdCC42Ec0ECB7B5F9e4A5FE1Df99EeB1BDf46a00,
   weth()=WHYPE. "RingLaunchpad - SlowMist Audit Report.pdf" is in RingProtocol/audits.
2. Do Ring's Uniswap-v4 hooks on HyperEVM hold funds with permissionless drains?
3. Does the custom UniversalRouter / FewETHWrapper / v2 router allow stealing user approvals/funds?
4. Are fw tokens trading at a discount on any other HyperEVM venue (buy cheap → unwrap for full backing)?
5. Any farms/staking contracts holding fw tokens or LP (candidates for reward-accounting bugs)?

## Tooling notes
- Etherscan V2 works for chain 999: `https://api.etherscan.io/v2/api?chainid=999&module=...&apikey=$ETHERSCANV2_API_KEY`
  (source: module=contract&action=getsourcecode; logs: module=logs&action=getLogs). Key in /home/heisenberg/CA/.env.
- HyperEVM RPC rate-limits; batch small, add sleeps, retry; public alt: try `https://hyperliquid.drpc.org` etc.
- GeckoTerminal: network slug `hyperevm`, Ring dex id `ring-exchange-hyperevm`; pool endpoint
  `https://api.geckoterminal.com/api/v2/networks/hyperevm/pools/<addr>`.
- DefiLlama prices: `https://coins.llama.fi/prices/current/hyperevm:<addr>`; protocols `https://api.llama.fi/protocol/<slug>`.
- Do NOT print .env values. Do NOT send transactions. No `cast send`.
