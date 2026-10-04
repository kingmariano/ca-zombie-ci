# LogX — Telos, zkLink Nova, Linea, Mode, Manta, Mantle, Fuse (+ V2 on 19 chains)

## Status & shutdown evidence (sources, dates)
- DefiLlama slugs `logx-v1` (TVL $1,241.56 at pull) and `logx-v2` (TVL $41.19), both `listed:false`; V1 hallmark "2024-09-10 v1 is deprecated" (DefiLlama adapter `projects/logx/index.js`).
- Adapter sources fetched 2026-10-04 from raw.githubusercontent.com/DefiLlama/DefiLlama-Adapters (v1 vault list, v2 "HypCollateral" list).
- Live vaults still hold real value on zkLink/Telos etc. (below), contradicting the $1.2K DefiLlama figure.

## Contracts (address, chain, code?, verified?, proxy?, roles/owner/paused, block)
V1 vaults = GMX-V1-fork `Vault` (USDL perp), verified source on Linea via Etherscan V2 (ContractName `Vault`, solc 0.8.19):
- zkLink Nova `0x75940cDa18F14D1F97562fc2A6dBCe31CBe03870` (block 0x7f85c8): gov `0x9Aa1a34f09fC301418A7a5bDb1B323d8E62fd025`; usdl `0x74304F09C4b3E38A22b30E1DE64C858E9Ed2e9Fa`; priceFeed `0x79558f228605eD03cD4856277B08216A50A8a704`; utils `0x9C218236fa8a4Eb5fa09c3290aa216f26B73fF1B`
- Telos `0x082321F9939373b02Ad54ea214BF6e822531e679` (block 0x1d5597f0): gov `0x3b74E7651EB12Ca680D9b6278699E4482cCD70B1`
- Linea `0xc5f444d25d5013c395f70398350d2969ef0f6aa0` (block 0x1ebba75) / Mode `0x34b83A3759ba4c9F99c339604181bf6bBdED4E79`, `0x082321F9939373b02Ad54ea214BF6e822531e679` (block 0x2b5b8ea) / Mantle `0x7A74Dd56Ba2FB26101A7f2bC9b167A93bA5e1353` (block 0x60c7ab2) / Fuse `0x082321F9939373b02Ad54ea214BF6e822531e679` (block 0x2a5a0dc): gov `0x818484227ABF04550c6c242B6119B7c94d2E72b3`
- Manta `0x53c6decad02cB6C535a7078B686650c951aD6Af5` (block 0x93d03c); Kroma `0xC5f444D25D5013C395F70398350d2969eF0F6AA0` — no working Kroma RPC found in bounded pass (rpc.kroma.network dead).
- Live gates on every checked V1 vault: `ceaseLPActivity()=false`, `ceaseTradingActivity()=false`, `inManagerMode()=true`, `inPrivateLiquidationMode()=false`, `isInitialized()=true`.
V2 "HypCollateral" contracts per adapter (all `wrappedToken()`-style wrappers, code 2882 bytes on EVM chains; owner `0xc8bC853C09DdbbBD4f5B07E711e5a63C22b1e8F6` on Mantle/Op/Sonic/Taiko/Blast).

## Live balances (token, amount, USD, price source, block)
V1 (raw on-chain `balanceOf`):
- zkLink USDT (Nova Tether, 6dp) `0x2f8a25...9059`: **2,416.673546** → $2,416.67 (USDT≈$1.00; DefiLlama USDT arb $0.99991 2026-10-04) — block 0x7f85c8
- Telos USDC (6dp) `0x8d97ce...611b`: **1,203.929416** → $1,203.93 (@$1.000004, coins.llama.fi) — block 0x1d5597f0
- Manta wUSDM (18dp) `0xbdad407f...fb07`: **33.472194609719345** → ≈$33.47 at $1.00 conservative (DefiLlama has no wUSDM price; yield-bearing USDM wrapper) — block 0x93d03c
- Linea USDC `0x176211...e1ff`: 1.114290 → $1.11; Mode USDC `0xd98809...005f`: 1.022980 + Mode `0xf0f161...e2ed`: 0.671475 → ≈$1.69; Mantle USDT `0x201eba...56ae`: 0.666924 → $0.67; Fuse USDT `0x68c973...04cd`: 0.6208 → $0.62. Manta USDC `0x305e88d8...` returned 0/rate-limited.
- V1 subtotal ≈ **$3,625** (DefiLlama lists only $1,241 — adapter misses zkLink/Telos likely due to RPC/price gaps).
V2 (sum of `wrappedToken` balances): Base USDC $8.21; Sonic USDC $21.51; Arbitrum USDC $0.52 + USDT $1.55; Optimism $0.25+$0.80; Mode $0.10+$0.66; Manta USDC $1.20 + wUSDM $0.20; Taiko $0.24; Scroll $0.22+$0.23; Polygon $0.20+$0.20; Abstract $4.52 (token 0x84a7... assumed 6dp); ApeChain 0.238 (18dp); BOB 0.197+0.004; Sei $0.04; Blast/Linea 0. **V2 subtotal ≈ $41.4** — cross-checks DefiLlama v2 TVL $41.19.
Combined live ≈ **$3,666**.

## Permissionless paths examined (path → gates → live values → verdict; include reverts/negative results)
1. `buyUSDL`/`sellUSDL` are permissionless *only if* `inManagerMode=false`; live `inManagerMode=true` on zkLink, Telos, Linea, Mode, Mantle, Fuse → gated by `isManager[msg.sender]` (tested `0xdead` = false). **No public LP mint/redeem path.**
2. `liquidatePosition(bytes32,address)` is permissionless when `inPrivateLiquidationMode=false` (live false on all checked). But the vault's `priceFeed.getMin/MaxPriceOfToken` reverts: eth_call simulation of `liquidatePosition` for **all 23 open zkLink position keys reverted `PriceFeed: current price data not available!`** (23/23, block 0x7f85c8). Oracle is dead → no trading, funding, liquidation, PnL or collateral path can execute. Full simulation log: `analysis/raw/logx_zklink_positions.json` (23 keys, accounts, sizes, avgPrice, sim result).
3. `increasePosition`/`decreasePosition` self-call (`msg.sender == account`) is allowed by `_validateOrderManager`, but every path calls the same dead price feed → reverts.
4. `withdrawFees(token,receiver)` + `setGov`/`setTokenConfig`/`setFees` are `_onlyGov()` → privileged. `directPoolDeposit` is permissionless but only adds tokens in.
5. `_transferIn` uses real `balanceOf`, so donations do not create a withdrawal claim; `_decreasePoolAmount` is capped by internal `poolAmounts` (< live balance due to unaccounted deposits/fees).
→ **E-U $0** on all measured vaults. Funds are recoverable only by gov/manager (P), otherwise stuck (S) while the feed is dead.

## Approvals / user-side residual risk
No user approvals needed for any working path (all reverts). USDL holders cannot self-redeem (`sellUSDL` manager-gated). Vault allowances not enumerated (bounded pass).

## Classification: P — ~$3,625 (V1) + ~$41 (V2) — confidence high (E-U=$0 high on zkLink; medium on remaining chains by contract-family inference) — what would change it
- Would change to E-U if any chain's `priceFeed` is live while another token's oracle is stale/mispriced and a manager remains public, or if a keeper/manager key is public. Parent should fork-test `getMinPriceOfToken` on Telos/Linea/Mode/Mantle/Fuse if desired; zkLink is confirmed dead.
- Would change to S (practical) for holders while feed dead; P flag reflects live gov addresses `0x9Aa1…`, `0x3b74…`, `0x8184…` being able to call `withdrawFees` and restore feeds via `setPriceFeed`.

## Raw evidence index (files in analysis/)
- raw/logx_v1_scan.jsonl, logx_v1_scan2.jsonl, logx_v1_scan3.jsonl (balances + blocks)
- raw/logx_v2_scan.jsonl, logx_v2_scan2.jsonl, logx_v2_scan3.jsonl, logx_v2_scan4.jsonl
- raw/logx_zklink_positions.json (23 positions + liquidation simulations)
- raw/es_linea_v1.json (verified Vault source/ABI via Etherscan V2, chainid 59144)
