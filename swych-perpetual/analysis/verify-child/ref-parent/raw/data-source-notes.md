# Data-source notes (Swych Perpetual audit)

- **Etherscan V2 (chainid=56)**: contract sources/ABIs for verified contracts worked (`getsourcecode`, `getabi`).
  Account/txlist endpoints are **not available on the free plan for BSC** ("Free API access is not supported
  for this chain") — tx history was therefore taken from GoldRush and raw RPC.
- **GoldRush (bsc-mainnet)**: balances, token holders and some tx history worked, but the pool and the LP token
  have **no log/event index** (all `log_events_by_*` and `erc20_token_transfers` queries returned empty), and
  pagination for some addresses returns empty pages. Not usable for event reconstruction of this protocol.
- **BSC public RPCs**: `https://bsc-rpc.publicnode.com` (eth_call fine; eth_getLogs 403), `https://bsc.drpc.org`
  (rate-limited), `https://bsc.blockrazor.xyz` (eth_getLogs max 25-block range). Wide-range log scans were not
  possible from this host; the CI job's keyed BSC RPC also rejects `eth_getLogs`. Position-lifecycle events could
  therefore not be enumerated (see `analysis/ci-results.md` §E).
- **Verified sources used**: Pool impl `0x81026C573A618B104E2a511e1AEF2854524AA196`, OrderManager impl
  `0xC8bA536029Ba07B8422e6fc555a5Ab8A4ece7e10`, PriceOracle `0xe4460109425EbC1CE34cAd59Ab7ce60535956BF5`,
  ProxyAdmin `0x107876b1bb5d91c4640ea7135d01b608bd0cc35a`.
- **Unverified contracts decompiled with heimdall-rs v0.9.2**: PriceReporter `0x1CB9992c13Ac8de4d14661e7d05b3DB178b70dC5`
  (raw dumps in this folder), FeeDistributor #1 `0x7c57c2F579175570E23CCc8C3C26723beD50D6b1`,
  FeeDistributor #2 `0x9baE46B159f0ce7eF40b6F3a932DFF3d5B01d3F5`.
- **Source lineage (public repos)**: `dhiraj0911/trading-contract` (Swych/RWAX deploy scripts; Arbitrum-Goerli
  constants), `level-fi/level-trading-contracts`, `level-fi/v2-trading-contracts`, `SypherFinance/sypherfinance`,
  `tintinweb/smart-contract-sanctuary-arbitrum` (PriceReporter family). Deployed selectors cross-checked against
  these; the deployed BSC PriceReporter matches the reporter-gated family, with `executeOrder`/`executeSwapOrder`/
  `postPrices` present only as internal call-constants.
