# Starcoin flash-liquidity scan (H-15 follow-up)

- RPC: https://main-seed.starcoin.org
- addresses scanned: 20; modules scanned: **673**
- modules with flash/hot-potato/callback/skim/loan/lend/borrow/margin identifiers: **94**

## Per-address module counts

- framework_0x1 (0x00000000000000000000000000000001): 85 modules; 11 with matches
- starswap_dex (0x8c109349c6bd91411d6bc962e080c4a3): 52 modules; 6 with matches
- bfly (0x4ffcc98f43ce74668264a0cf6eebe42b): 30 modules; 8 with matches
- bfly_oracle (0x82e35b34096f32c42061717c06e44a59): 5 modules; 0 with matches
- bridge_lockproxy_xusdt_xeth (0xe52552637c5897a2d499fbf08216f73e): 34 modules; 10 with matches
- fai2_issuer (0xfe125d419811297dfab03c61efec0bc9): 19 modules; 5 with matches
- wen_issuer (0xbf60b00855c92fe725296a436101c8c6): 8 modules; 3 with matches
- bxusdt_issuer (0x9350502a3af6c617e9a42fa9e306a385): 1 modules; 0 with matches
- kiko_issuer (0x8355417c88d969f656935244641256ad): 55 modules; 1 with matches
- aww_issuer (0x49142e24bf3b34b323b3bd339e2434e3): 6 modules; 2 with matches
- token_STC (0x00000000000000000000000000000001): 85 modules; 11 with matches
- token_STAR (0x8c109349c6bd91411d6bc962e080c4a3): 52 modules; 6 with matches
- token_STAR> (0x8c109349c6bd91411d6bc962e080c4a3): 52 modules; 6 with matches
- token_BX_USDT (0x9350502a3af6c617e9a42fa9e306a385): 1 modules; 0 with matches
- token_AptosKIKO (0x8355417c88d969f656935244641256ad): 55 modules; 1 with matches
- token_XUSDT (0xe52552637c5897a2d499fbf08216f73e): 34 modules; 10 with matches
- token_AWW (0x49142e24bf3b34b323b3bd339e2434e3): 6 modules; 2 with matches
- token_FAI (0x4ffcc98f43ce74668264a0cf6eebe42b): 30 modules; 8 with matches
- token_KikoCatBox (0x8355417c88d969f656935244641256ad): 55 modules; 1 with matches
- token_WEN (0xbf60b00855c92fe725296a436101c8c6): 8 modules; 3 with matches

## External call targets (BFly / Starswap)

- BFly external calls beyond 0x1 and itself: **0**
- Starswap external calls beyond 0x1 and itself: **0**

## Identifier matches (if any)

- framework_0x1::Collection: ['borrow', 'borrow_collection']
- framework_0x1::Collection2: ['borrow', 'borrow_collection', 'borrow_mut']
- framework_0x1::Config: ['borrow_mut']
- framework_0x1::IdentifierNFT: ['borrow']
- framework_0x1::NFT: ['borrow_body', 'borrow_body_mut_with_cap']
- framework_0x1::Option: ['borrow', 'borrow_mut', 'borrow_with_default']
- framework_0x1::PackageTxnManager: ['borrow']
- framework_0x1::Signer: ['borrow_address']
- framework_0x1::StdlibUpgradeScripts: ['borrow', 'borrow_collection']
- framework_0x1::U256: ['sub_noborrow']
- framework_0x1::Vector: ['borrow', 'borrow_mut']
- starswap_dex::TokenSwapConfig: ['borrow', 'borrow_mut']
- starswap_dex::TokenSwapFarm: ['borrow']
- starswap_dex::TokenSwapSyrup: ['borrow']
- starswap_dex::TokenSwapSyrupMultiplierPool: ['borrow', 'borrow_mut']
- starswap_dex::TokenSwapVestarMinter: ['borrow']
- starswap_dex::YieldFarmingV3: ['borrow', 'borrow_mut']
- bfly::ETHVaultPoolA: ['BorrowEvent', 'borrow_event', 'borrow_fai', 'borrower', 'collateral_amount', 'max_borrow']
- bfly::Liquidation: ['cal_max_borrow']
- bfly::LiquidationHelper: ['cal_max_borrow', 'max_borrow', 'min_collateral', 'min_collateral_v2']
- bfly::MarketScript: ['borrow', 'borrow_fai', 'borrow_fai_from_eth_pool', 'lock_borrow']
- bfly::STCVaultPoolA: ['BorrowEvent', 'borrow_event', 'borrow_fai', 'borrower', 'collateral_amount', 'max_borrow']
- bfly::STCVaultPoolB: ['borrow', 'lock_borrow']
- bfly::U256: ['borrow', 'borrow_mut']
- bfly::Vault: ['borrow', 'borrow_fai', 'borrow_mut', 'cal_max_borrow', 'lock_borrow', 'max_borrow']
- bridge_lockproxy_xusdt_xeth::Bit: ['borrow']
- bridge_lockproxy_xusdt_xeth::Bytes: ['borrow']
- bridge_lockproxy_xusdt_xeth::CrossChainData: ['borrow']
- bridge_lockproxy_xusdt_xeth::CrossChainLibrary: ['borrow', 'borrow_mut']
- bridge_lockproxy_xusdt_xeth::EthStateVerifier: ['borrow']
- bridge_lockproxy_xusdt_xeth::MerkleProofStructuredHash: ['borrow']
- bridge_lockproxy_xusdt_xeth::RLP: ['borrow']
- bridge_lockproxy_xusdt_xeth::SMTProofs: ['borrow']
- bridge_lockproxy_xusdt_xeth::SMTUtils: ['borrow']
- bridge_lockproxy_xusdt_xeth::StarcoinVerifier: ['borrow']
- fai2_issuer::Liquidation: ['cal_max_borrow', 'max_borrow', 'min_collateral']
- fai2_issuer::MarketScript: ['borrow_fai']
- fai2_issuer::STCVaultPoolA: ['borrow_fai', 'max_borrow']
- fai2_issuer::U256: ['borrow', 'borrow_mut']
- fai2_issuer::Vault: ['borrow_fai', 'cal_max_borrow', 'max_borrow']
- wen_issuer::InitializeV1: ['STCLendingPoolV2']
- wen_issuer::LendingPoolV2: ['AddCollateralEvent', 'BorrowEvent', 'LendingPoolV2', 'LiquidateCollateralEvent', 'PoolMinBorrow', 'RemoveCollateralEvent', 'TotalBorrow', 'TotalCollateral', 'add_collateral', 'assert_total_borrow', 'assert_total_collateral', 'borrow', 'borrow_events', 'borrow_info', 'borrow_opening_fee', 'collateral', 'collateral_info', 'do_borrow', 'do_remove_collateral', 'get_min_borrow', 'init_min_borrow', 'min_borrow', 'remove_collateral', 'set_min_borrow']
- wen_issuer::STCLendingPoolV2: ['LendingPoolV2', 'STCLendingPoolV2', 'add_collateral', 'borrow', 'borrow_info', 'collateral_info', 'get_min_borrow', 'init_min_borrow', 'remove_collateral', 'set_min_borrow']
- kiko_issuer::AvatarKikoCard: ['borrow']
- aww_issuer::ARM: ['borrow_body_mut_with_cap']
- aww_issuer::ARMMarket: ['borrow']
- token_STC::Collection: ['borrow', 'borrow_collection']
- token_STC::Collection2: ['borrow', 'borrow_collection', 'borrow_mut']
- token_STC::Config: ['borrow_mut']
- token_STC::IdentifierNFT: ['borrow']
- token_STC::NFT: ['borrow_body', 'borrow_body_mut_with_cap']
- token_STC::Option: ['borrow', 'borrow_mut', 'borrow_with_default']
- token_STC::PackageTxnManager: ['borrow']
- token_STC::Signer: ['borrow_address']
- token_STC::StdlibUpgradeScripts: ['borrow', 'borrow_collection']
- token_STC::U256: ['sub_noborrow']
- token_STC::Vector: ['borrow', 'borrow_mut']
- token_STAR::TokenSwapConfig: ['borrow', 'borrow_mut']
- token_STAR::TokenSwapFarm: ['borrow']
- token_STAR::TokenSwapSyrup: ['borrow']
- token_STAR::TokenSwapSyrupMultiplierPool: ['borrow', 'borrow_mut']
- token_STAR::TokenSwapVestarMinter: ['borrow']
- token_STAR::YieldFarmingV3: ['borrow', 'borrow_mut']
- token_STAR>::TokenSwapConfig: ['borrow', 'borrow_mut']
- token_STAR>::TokenSwapFarm: ['borrow']
- token_STAR>::TokenSwapSyrup: ['borrow']
- token_STAR>::TokenSwapSyrupMultiplierPool: ['borrow', 'borrow_mut']
- token_STAR>::TokenSwapVestarMinter: ['borrow']
- token_STAR>::YieldFarmingV3: ['borrow', 'borrow_mut']
- token_AptosKIKO::AvatarKikoCard: ['borrow']
- token_XUSDT::Bit: ['borrow']
- token_XUSDT::Bytes: ['borrow']
- token_XUSDT::CrossChainData: ['borrow']
- token_XUSDT::CrossChainLibrary: ['borrow', 'borrow_mut']
- token_XUSDT::EthStateVerifier: ['borrow']
- token_XUSDT::MerkleProofStructuredHash: ['borrow']
- token_XUSDT::RLP: ['borrow']
- token_XUSDT::SMTProofs: ['borrow']
- token_XUSDT::SMTUtils: ['borrow']
- token_XUSDT::StarcoinVerifier: ['borrow']
- token_AWW::ARM: ['borrow_body_mut_with_cap']
- token_AWW::ARMMarket: ['borrow']
- token_FAI::ETHVaultPoolA: ['BorrowEvent', 'borrow_event', 'borrow_fai', 'borrower', 'collateral_amount', 'max_borrow']
- token_FAI::Liquidation: ['cal_max_borrow']
- token_FAI::LiquidationHelper: ['cal_max_borrow', 'max_borrow', 'min_collateral', 'min_collateral_v2']
- token_FAI::MarketScript: ['borrow', 'borrow_fai', 'borrow_fai_from_eth_pool', 'lock_borrow']
- token_FAI::STCVaultPoolA: ['BorrowEvent', 'borrow_event', 'borrow_fai', 'borrower', 'collateral_amount', 'max_borrow']
- token_FAI::STCVaultPoolB: ['borrow', 'lock_borrow']
- token_FAI::U256: ['borrow', 'borrow_mut']
- token_FAI::Vault: ['borrow', 'borrow_fai', 'borrow_mut', 'cal_max_borrow', 'lock_borrow', 'max_borrow']
- token_KikoCatBox::AvatarKikoCard: ['borrow']
- token_WEN::InitializeV1: ['STCLendingPoolV2']
- token_WEN::LendingPoolV2: ['AddCollateralEvent', 'BorrowEvent', 'LendingPoolV2', 'LiquidateCollateralEvent', 'PoolMinBorrow', 'RemoveCollateralEvent', 'TotalBorrow', 'TotalCollateral', 'add_collateral', 'assert_total_borrow', 'assert_total_collateral', 'borrow', 'borrow_events', 'borrow_info', 'borrow_opening_fee', 'collateral', 'collateral_info', 'do_borrow', 'do_remove_collateral', 'get_min_borrow', 'init_min_borrow', 'min_borrow', 'remove_collateral', 'set_min_borrow']
- token_WEN::STCLendingPoolV2: ['LendingPoolV2', 'STCLendingPoolV2', 'add_collateral', 'borrow', 'borrow_info', 'collateral_info', 'get_min_borrow', 'init_min_borrow', 'remove_collateral', 'set_min_borrow']

## Verdict

- No flash-loan, flash-swap, hot-potato, skim/sync or callback facility exists in any scanned Starcoin module.
- Move has no dynamic dispatch/arbitrary-callee callback, so the EVM `flashLoan+onFlashLoan` pattern is not expressible; no Move equivalent (hot potato) is present either.
- BFly's own borrow paths all require pre-existing collateral in a per-user `Vault` resource and a health check; no uncollateralized/atomic borrow exists.
- The XUSDT→STC→FAI→liquidate→STC→XUSDT cycle therefore **cannot be made capital-free**: the ~786 XUSDT (or ~575k STC) input must be owned upfront; only gas is unavoidable otherwise.