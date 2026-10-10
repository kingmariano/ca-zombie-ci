# Sources — Cozy Finance v2 Set (CSET) residual, Optimism

## On-chain / API endpoints (all public, read-only)
- Optimism public RPC — https://optimism-rpc.publicnode.com (latest-state `eth_call`, `eth_getCode`, `cast call`)
- Optimism archive RPC — https://mainnet.optimism.io (historical `eth_call`; hex block params)
- Optimism dRPC — https://optimism.drpc.org (historical `eth_getTransactionReceipt` — incident receipts)
- Blockscout Optimism (now `explorer.optimism.io`) — https://explorer.optimism.io/api/v2/... (addresses, tokens, holders, logs, internal txs, smart-contract metadata)
- 4byte directory — https://www.4byte.directory/api/v1/signatures/ (custom-error selector names)
- DefiLlama price — https://coins.llama.fi/prices/current/optimism:0x7F5c764cBc14f9669B88837ca1490cCa17c31607 (USDC.e = $0.999723)
- DefiLlama protocol — https://api.llama.fi/protocol/cozy-finance (OP Mainnet TVL $5,367)
- DexScreener — https://api.dexscreener.com/latest/dex/tokens/{CPT|CSET} (0 pairs)

## Key on-chain objects (Optimism)
- Set 1 (4,168.126922 USDC.e): https://explorer.optimism.io/address/0x17705474203F7ff7ba8a940c433AB43D1F58E249
- Set 2 (emptied): https://explorer.optimism.io/address/0x1a684C688AcA00944B22B9380219c7bBbC3B7fB9
- Set 3 (1,150.675622 USDC.e): https://explorer.optimism.io/address/0x426713c9E9522Bd840b8506BC14a3fE761A5fBd8
- Set 4 (emptied): https://explorer.optimism.io/address/0xfB8b6E5b35b70324701adE10dafbdEFb8D0EB276
- USDC.e: https://explorer.optimism.io/address/0x7F5c764cBc14f9669B88837ca1490cCa17c31607
- UMA OOv2: https://explorer.optimism.io/address/0x255483434aba5a75dc60c1391bB162BCd9DE2882
- Attack TX1 (freeze): https://optimistic.etherscan.io/tx/0x53b454a3f552c5498994f74ae8737faa60123cac274bdd3b0383ccb226b3f2cb (block 156,364,035)
- Attack TX2 (drain Set1): https://optimistic.etherscan.io/tx/0x8761164b8947a0690b57896a8e7370dd69fe8e9137ce61e0b21ff08581a2ce60 (block 156,580,507)
- Attack TX2b (drain Set3): https://optimistic.etherscan.io/tx/0xf7a270480f9d457bddc2c8cb4f16669ef01f185cf6bda338351a71e704c79b4b (block 156,580,507)
- Pause tx: https://explorer.optimism.io/tx/0xc74f6feb6b8125d7ae54f4b9a14ad6fda89355e414bfcb87259877476608aa19 (block 156,595,428)
- Attacker EOA: https://explorer.optimism.io/address/0x003FE7359A4E03C85Ac2f521eC699ED84C7c5ccB

## Code references
- Cozy interfaces v2 (ISet, IPToken, IUMATrigger): https://github.com/Cozy-Finance/cozy-interfaces-v2
- Cozy UMATrigger (verified source on OP, mirrored): https://github.com/Cozy-Finance/cozy-triggers-v2/blob/main/src/UMATrigger.sol
- DeFiHackLabs PoC: https://github.com/SunWeb3Sec/DeFiHackLabs/blob/main/src/test/2026-09/CozyFinance_exp.sol
- evm-hack-registry write-up: https://github.com/sanbir/evm-hack-registry/blob/main/2026-09-CozyFinance_exp/CozyFinance_exp.md
- crypto.training reproduction: https://crypto.training/hacks/2026-09-cozyfinance/

## Incident press / socials
- BeInCrypto/OneBullEx article (Blockaid; "Cozy Set (CSET) … still holds about $4,168 in USDC.e"): https://www.onebullex.com/news/articles/blockaid-flags-second-cozy-finance-exploit-as-attacker-drains-170-000-in-13-minutes-4
- Yahoo Finance: https://finance.yahoo.com/markets/crypto/articles/cozy-finance-exploit-drains-170-091109362.html
- crypto-economy.com: https://crypto-economy.com/cozy-finance-suffers-second-exploit/
- Cozy Finance X post (incident): https://x.com/cozyfinance/status/2097085271867118062
- Cozy website notice (UMA integrations removed; "disaster-loss payouts temporarily unavailable" — app-level, not reflected in the v2 Set on-chain state): https://www.cozy.finance/
- SlowMist alert: https://x.com/SlowMist_Team/status/2096881310237426062
