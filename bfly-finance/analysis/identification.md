# BFly Finance — identification chain (H-15)

1. **DefiLlama protocol row** `bfly-finance`: name "BFly Finance", category Lending, chain **Starcoin**, audits 0, `deadUrl: true`, listed 2022-08-25. Last TVL reported: **$140,609.38** (stale since ~2024-02; the adapter has reported the same value for 973 days).
2. **DefiLlama adapter** `projects/bfly.js`:
   - `contract.call_v2` on `https://main-seed.starcoin.org`:
     - `0x4ffcc98f43ce74668264a0cf6eebe42b::STCVaultPoolA::current_stc_locked` → 14,060,938.315319777 STC
     - `0x1::PriceOracle::read(0x82e35b34096f32c42061717c06e44a59)::STCUSDOracle::STCUSD` → 10000 @ 1e6 = $0.01
   - `tvl = stc_locked/1e9 × price/1e6`. The adapter still reads the **live** chain (value unchanged for 973 days).
3. **Chain / deployment resolution:**
   - Starcoin mainnet, `chain_id = 1`, head 32,904,523 (2026-10-03). RPC is live; blocks continue.
   - Protocol admin + module account: `0x4ffcc98f43ce74668264a0cf6eebe42b` — **30 modules** (`state.list_code`), including `MarketScript`, `STCVaultPoolA`, `STCVaultPoolB`, `ETHVaultPoolA`, `Vault`, `Liquidation`, `LiquidationHelper`, `Config`, `Treasury`, `STCTreasury`, `FAI`, `Rate`, `VaultCounter`, `Admin`, `Initialize`, `InitializeScript`, oracles, and test modules.
   - Oracle account: `0x82e35b34096f32c42061717c06e44a59` (BTC/ETH/LINK/UNI/SUSHI + STCUSD feeds; updates every ~10 min, still active).
4. **Public source:** GitHub `BFlyFinance/FAI` (Move; main branch ends at "release package v1.0.1", 2022-03-01; a `liquidation-test` branch has an earlier liquidation design). **The deployed modules are a newer, unpublished build** (they contain `crack`, `LiquidationHelper`, `STCTreasury`, `STCVaultPoolB`, `ETHVaultPoolA`, event structs, and `Config::update_config` deprecated) — so the audit was performed on **on-chain bytecode**, disassembled with the exact toolchain starcoin v1.13.22 uses (`starcoinorg/move` rev `7b6ac7bb`, CI-built `move-disassembler`).
5. **Explorer/indexer:** stcscan.io API (`https://doapi.stcscan.io/v2/...`) was used to enumerate all 1,266 transactions / 2,949 unique events involving the protocol, including 72+13 vault creations, 9 historical liquidations, 340 FAI mints, and 305 FAI transfers. The on-chain RPC caps event queries to 32-block windows, so the indexer was required for the full census.
6. **DEX discovery:** the whale vault owner's account resources revealed a `TokenSwap::LiquidityToken<STC, FAI>` LP position, leading to the live Starswap pools at `0x8c109349c6bd91411d6bc962e080c4a3` — the key to the arbitrage (the p2p-only FAI transfer feed had hidden the DEX).

## Addresses

| Role | Address |
|---|---|
| Protocol admin / modules / pools / treasury | `0x4ffcc98f43ce74668264a0cf6eebe42b` |
| Oracle account (feeds + update caps) | `0x82e35b34096f32c42061717c06e44a59` |
| Starswap DEX (pairs/farms/STAR) | `0x8c109349c6bd91411d6bc962e080c4a3` |
| Bridged XUSDT (LockProxy) | `0xe52552637c5897a2d499fbf08216f73e` |
| Second, empty FAI pool token | `0xfe125d419811297dfab03c61efec0bc9::FAI::FAI` |
| Whale vault owner (largest liquidatable) | `0x0c357315f9351540114596324f41006e` |
| Largest FAI holder (3,651.68 FAI) | `0x236e3246c470de88dcf2657579d0ad60` |
