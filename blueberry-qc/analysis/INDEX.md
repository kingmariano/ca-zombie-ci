# analysis/ — evidence index (Blueberry)

All reads are **read-only**, from public keyless RPCs (`https://rpc.monad.xyz`, Ethereum public nodes,
`https://rpc.hyperliquid.xyz/evm`) and Etherscan V2 (verified sources/ABIs/tokentx). No keys are stored here.

| File | What it is |
|---|---|
| `vault1.vy`, `vault1-src.json`, `vault2-src.json` | Verified Yearn V3.1.0 vault source (Monad chain 143) + Etherscan responses |
| `TokenizedStrategy.sol` | Canonical Yearn TokenizedStrategy impl `0xD377919FA87120584B21279a491F82D5265A139c` (report/tend are `onlyKeepers`) |
| `CurvanceOptimizer.sol` | Verified strategy source (`0x460BBe06…`, `0xe43b232F…`), incl. BaseHealthCheck/AuctionSwapper |
| `BlueberryBank.sol`, `eth-bank-impl.sol`, `eth-bank.sol` | Ethereum V1 bank (impl `0xb96f3016…`) + Position struct/liquidate logic |
| `eth-comptroller-impl.sol` | Compound-fork Comptroller (Unitroller impl `0xffadb0bb…`) |
| `HyperVaultRouter.sol`, `HyperliquidEscrow.sol`, `hl-*.json` | HyperEVM router (impl `0x893c6e4f…`) and escrow (`LIQUIDITY_ADMIN`-gated L1 actions) |
| `RoleManager.sol`, `rolemanager.sol` | Yearn RoleManager (vault `role_manager`) — all admin paths `onlyPositionHolder` |
| `accountant.sol`, `accountant.json` | Yearn Accountant `0xf7e5c388…` (fee math only) |
| `Auction.sol`, `auction2.json` | Yearn Dutch Auction contract (permissionless `take`, 24h window, 0.5%/min decay) |
| `ausd.sol`, `ausd-src.json` | AUSD token source (Agora, Monad) |
| `monad_read.py` | Batch JSON-RPC reader used for Monad state |
| `calls-*.json`, `out-*.json` | Raw call sets and decoded responses (basic vault state, roles, strategies, markets, holders, hooks) |
| `eth-compound-markets.json`, `eth-state.json` | Ethereum market/position dumps |
| `prices.json` | DefiLlama prices used for USD figures (2026-10-11) |
| `tokentx.json` | Full vault share-transfer history used to enumerate holders |
| `deployer-txs.json` | Monad deployer tx list (deployment timeline, Safe activity) |
| `llama-adapter.js` | DefiLlama Blueberry adapter (target inventory) |

Raw live snapshots produced by CI: `../ci-out/state.json`, `../ci-artifacts/result-blueberry/ci-out/state.json`.
