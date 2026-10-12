use anchor_lang::prelude::*;

declare_id!("ArmN3Av2boBg8pkkeCK9UuCN9zSUVc2UQg1qR2sKwm8d");

/// The maximum number of positions a vault could have. This dictates the space required for
/// the CLP Vault. There is a separate constant for limiting active positions. These are
/// separate because the max active positions will start at 1 for v1.0.0 of the protocol.
pub const MAX_POSITIONS: usize = 5;

/// The maximum number of active positions the CLP Vault could have on the underlying valut at a
/// single time.
pub const MAX_ACTIVE_POSITIONS: usize = MAX_POSITIONS;

#[derive(Clone, Copy, Default, AnchorDeserialize, AnchorSerialize)]
#[repr(C)]
pub struct SwapCache {
    pub source_status: SourceState,
    pub cache_state: CacheState,
    _padding1: [u8; 6],
}
#[derive(Clone, Copy, Debug, Default, AnchorDeserialize, AnchorSerialize)]
#[repr(u8)]
pub enum SourceState {
    #[default]
    Default,
    SourceIsA,
    SourceIsB,
}
#[derive(Clone, Copy, Debug, Default, AnchorDeserialize, AnchorSerialize)]
#[repr(u8)]
pub enum CacheState {
    #[default]
    Default,
    Ready,
    Consumed,
}

#[derive(Clone, Copy, Default, AnchorDeserialize, AnchorSerialize)]
#[repr(C)]
pub struct VaultPosition {
    /// The underlying CLP position.
    pub position_key: Pubkey,
    /// The address of the lower TickArray
    pub lower_tick: i32,
    _padding0: [u8; 12],
    /// The address of the upper TickArray
    pub upper_tick: i32,
    _padding1: [u8; 12],
    _reserve: [u8; 32],
    _reserve1: [u8; 32],
    _reserve2: [u8; 32],
    _reserve3: [u8; 32],
    _reserve4: [u8; 32],
    _reserve5: [u8; 32],
    _reserve6: [u8; 32],
    _reserve7: [u8; 32],
}

#[derive(Clone, Copy, AnchorDeserialize, AnchorSerialize)]
#[repr(u8)]
pub enum StrategyType {
    /// Used for a brand volatile pair that has a brand new coin with no history,
    PriceDiscovery,
    /// Used for a pair like PSY/HXRO
    VolatilePair,
    /// Used for a pair like USDC-USDT
    StablePair,
    /// Used for a pair like SOL-jitoSOL
    StableSlowlyDiverging,
}

#[derive(Clone, Copy, AnchorDeserialize, AnchorSerialize)]
pub struct TokenRatio {
    /// The amount of token a required for the initial deposit
    pub token_a: u64,
    /// The amount of token b required for the initial deposit
    pub token_b: u64,
}

#[derive(Clone, Copy, AnchorDeserialize, AnchorSerialize)]
#[repr(C)]
pub struct VaultRatioCache {
    /// Total amount of tokenA managed by the vault
    pub total_token_a: u64,
    /// Total amount of tokenB managed by the vault
    pub total_token_b: u64,
    /// The total supply of vault LP tokens
    pub lp_supply: u64,
    /// The Unix timestamp for when the cache was last updated
    pub cached_at: i64,
}

#[derive(Clone, Copy, Default, AnchorDeserialize, AnchorSerialize)]
#[repr(C)]
pub struct SwapEventCache {
    pub source_before: u64,
    pub dest_before: u64,
    pub source_after: u64,
    pub dest_after: u64
}

#[account(zero_copy)]
#[repr(C)]
pub struct ClpVault {
    pub bump_seed: u8,
    pub features_enabled: u8,
    pub swap_cache: SwapCache,
    _padding0: [u8; 6],
    /// A nonce to allow more than one CLP Vault with the same trading pair for the same admin
    pub nonce: u16,
    _padding1: [u8; 14],
    /// The address of the concentrated liquidity pool. E.g. Orca Whirlpool address
    pub clp: Pubkey,
    /// The SPL token Mint address for the LP tokens
    pub lp_mint: Pubkey,
    pub lp_mint_bump: u8,
    _padding2: [u8; 15],
    /// SPL token Mint A of the trading pair
    pub token_mint_a: Pubkey,
    /// An SPL token Account for staging A tokens
    pub token_vault_a: Pubkey,
    /// SPL Token mint B of the trading pair
    pub token_mint_b: Pubkey,
    /// An SPL token Account for staging B tokens
    pub token_vault_b: Pubkey,
    /// A percentage of the trading fees and rewards taken by the CLP Vault
    pub performance_fee: u32,
    _padding3: [u8; 12],
    /// A fee percentage taken upon withdrawing
    pub withdrawal_fee: u32,
    _padding4: [u8; 12],
    /// A percentage of the performance_fee that gets paid to the market_maker.
    pub market_making_fee: u32,
    _padding5: [u8; 12],
    /// The strategy that is enlisted by the vault
    pub strategy: StrategyType,
    _padding6: [u8; 15],
    /// The key that has the ability to adjust positions and rebalance
    pub market_making_key: Pubkey,
    /// The key that has the ability to change the market_making_key and strategy.
    pub admin_key: Pubkey,
    /// The key that must be the owner of SPL Token Accounts that receive fees
    pub fee_owner: Pubkey,
    /// The number of active Positions the vault has on the CLP
    pub num_active_positions: u8,
    _padding7: [u8; 15],
    /// The TokenAccount owned by the ClpVault that controls the PositionBundle
    pub position_bundle_token_account: Pubkey,
    /// The mint address of the whirlpool PositionBundle
    pub position_bundle_mint: Pubkey,
    /// The Whirlpool PositionBundle account
    pub position_bundle: Pubkey,
    /// A slice of the active position information
    pub positions: [VaultPosition; MAX_POSITIONS],
    /// The initial amount of tokenA to tokenB required per LP token when there is 0 liquidity on
    ///  positions or in the reserve. This is only used for the inital deposit into the vault. 
    ///  Without this, the vault would have no basis for calculating the amount of tokenA & tokenB
    ///  required to mint 1 LP token.
    pub initial_token_ratio: TokenRatio,
    /// A key indicating the primary StakePool for the vault. This is used as reference for UIs.
    pub stake_pool: Pubkey,

    pub ratio_cache: VaultRatioCache,

    pub swap_event_cache: SwapEventCache,

    _reserved0: [u8; 416],
    // added to give 16 bit spacing incase u128's are required in the future
    _reserved1: [u8; 512],
}
