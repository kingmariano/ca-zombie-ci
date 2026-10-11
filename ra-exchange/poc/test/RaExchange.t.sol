// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/* ------------------------------------------------------------------ */
/* Minimal interfaces (ABI-exact for the deployed Ra Exchange stack)   */
/* ------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface IClPool {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function fee() external view returns (uint24);
    function currentFee() external view returns (uint24);
    function slot0()
        external
        view
        returns (uint160 sqrtPriceX96, int24 tick, uint16 a, uint16 b, uint16 c, uint8 feeProtocol, bool unlocked);
    function liquidity() external view returns (uint128);
    function protocolFees() external view returns (uint128, uint128);
    function nfpManager() external view returns (address);
    function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested)
        external
        returns (uint128, uint128);
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested)
        external
        returns (uint128, uint128);
    function burn(int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256, uint256);
    function burn(uint256 index, int24 tickLower, int24 tickUpper, uint128 amount) external returns (uint256, uint256);
    function mint(address recipient, uint256 index, int24 tickLower, int24 tickUpper, uint128 amount, bytes calldata data)
        external
        returns (uint256, uint256);
    function swap(address recipient, bool zeroForOne, int256 amountSpecified, uint160 sqrtPriceLimitX96, bytes calldata data)
        external
        returns (int256, int256);
    function flash(address recipient, uint256 amount0, uint256 amount1, bytes calldata data) external;
    function initialize(uint160 sqrtPriceX96) external;
}

interface INFP {
    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }
    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }
    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    function ownerOf(uint256) external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );
    function collect(CollectParams calldata params) external payable returns (uint256, uint256);
    function decreaseLiquidity(DecreaseLiquidityParams calldata params) external payable returns (uint256, uint256);
    function increaseLiquidity(IncreaseLiquidityParams calldata params) external payable returns (uint128, uint256, uint256);
    function burn(uint256 tokenId) external payable;
    function getReward(uint256 tokenId, address[] calldata tokens) external;
}

interface IPair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint256, uint256, uint256);
    function getAmountOut(uint256 amountIn, address tokenIn) external view returns (uint256);
    function swap(uint256 amount0Out, uint256 amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;
    function claimFees() external returns (uint256, uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function stable() external view returns (bool);
}

interface IFeeCollector {
    function collectProtocolFees(address pool) external;
    function treasury() external view returns (address);
    function isTokenLive() external view returns (bool);
}

interface IFeeDistributor {
    function getReward(uint256 tokenId, address[] calldata tokens) external;
    function getPeriodReward(uint256 period, uint256 tokenId, address token) external;
    function earned(address token, uint256 tokenId) external view returns (uint256);
}

interface IVotingEscrow {
    function createLock(uint256 value, uint256 lockDuration) external returns (uint256);
    function ownerOf(uint256 tokenId) external view returns (address);
    function totalSupply() external view returns (uint256);
}

interface IVoter {
    function vote(uint256 tokenId, address[] calldata pools, uint256[] calldata weights) external;
    function totalWeight() external view returns (uint256);
    function gauges(address pool) external view returns (address);
}

/* ------------------------------------------------------------------ */
/* Attacker helper: can call pool callbacks and pay what is owed       */
/* ------------------------------------------------------------------ */
contract Attacker {
    function onSwapCallback(int256 amount0Delta, int256 amount1Delta, address pool) external {
        if (amount0Delta > 0) IERC20(IClPool(pool).token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(IClPool(pool).token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function ramsesV2SwapCallback(int256 amount0Delta, int256 amount1Delta, bytes calldata) external {
        if (amount0Delta > 0) IERC20(IClPool(msg.sender).token0()).transfer(msg.sender, uint256(amount0Delta));
        if (amount1Delta > 0) IERC20(IClPool(msg.sender).token1()).transfer(msg.sender, uint256(amount1Delta));
    }

    function ramsesV2MintCallback(uint256 amount0Owed, uint256 amount1Owed, bytes calldata) external {
        if (amount0Owed > 0) IERC20(IClPool(msg.sender).token0()).transfer(msg.sender, amount0Owed);
        if (amount1Owed > 0) IERC20(IClPool(msg.sender).token1()).transfer(msg.sender, amount1Owed);
    }

    // repays nothing -> should always revert the pool's F0/F1 check
    function ramsesV2FlashCallback(uint256, uint256, bytes calldata) external {}

    function approveToken(address token, address spender) external {
        IERC20(token).approve(spender, type(uint256).max);
    }
}

/// @dev repays the flash loan + fee from a pre-funded balance (proves no profit for attacker)
contract FlashRepayer {
    function ramsesV2FlashCallback(uint256 fee0, uint256 fee1, bytes calldata data) external {
        uint256 borrow0 = data.length == 32 ? abi.decode(data, (uint256)) : 0;
        address pool = msg.sender;
        if (borrow0 + fee0 > 0) IERC20(IClPool(pool).token0()).transfer(pool, borrow0 + fee0);
        if (fee1 > 0) IERC20(IClPool(pool).token1()).transfer(pool, fee1);
    }
}

/* ------------------------------------------------------------------ */
/* Tests                                                               */
/* ------------------------------------------------------------------ */
contract RaExchangeTest is Test {
    // ---- live addresses (Fraxtal mainnet, read-only fork) ----
    address constant CL_FACTORY = 0xAAA32926fcE6bE95ea2c51cB4Fcb60836D320C42;
    address constant PAIR_FACTORY = 0xAAA16c016BF556fcD620328f0759252E29b1AB57;
    address constant NFP = 0xAAA78E8C4241990B4ce159E105dA08129345946A;
    address constant FEE_COLLECTOR = 0xAAA2A49958a443Dc9d19FdDEe873B5D1d6e84A2f;
    address constant TREASURY = 0xAAA29803885d86E8A07773c3C049FD4ef7a8FA9c; // protocol treasury / factory owner (GnosisSafe)
    address constant NFT_OWNER_SAFE = 0xC4EB45d80DC1F079045E75D5d55de8eD1c1090E6; // holds the 3 value NFTs (GnosisSafe 3/5)
    address constant VOTER = 0xAAAf3D9CDD3602d117c67D80eEC37a160C8d9869;
    address constant VE = 0xAAAEa1fB9f3DE3F70E89f37B69Ab11B47eb9Ce6F;
    address constant RA = 0xAAA9FB3a08C13BA97Ae0F518B3AfA5C4a81498Fc;
    address constant XTOKEN = 0xAAAE58986b24e422740C8F22B3efB80BCbD68159;
    address constant LEGACY_GAUGE_A = 0xA939c7bf57FccaC34d60938412aF6CA2CA246ca0;

    // big CL pools (99%+ of live value)
    address constant POOL_A = 0x45A51ed99e94C2B3584386009C0Cccc5A7957A84; // frxUSD/frxETH 0.025%
    address constant POOL_B = 0x52992f0ca147F25cBA0B727F281848220F6d4c24; // axlUSDC/frxUSD 0.01%
    address constant POOL_C = 0x7767861F3638Dd69aD131F15efF75E7c886F89b1; // frxETH/frxETH 0.015%

    uint256 constant NFT_A = 1086; // 98.8% of POOL_A liquidity, owner = team Safe
    uint256 constant NFT_B = 36; // 99.5% of POOL_B liquidity
    uint256 constant NFT_C = 38; // 97% of POOL_C liquidity
    int24 constant A_LOWER = -84125;
    int24 constant A_UPPER = -78245;
    int24 constant B_LOWER = 276322;
    int24 constant B_UPPER = 276328;
    int24 constant C_LOWER = -50;
    int24 constant C_UPPER = 50;

    // biggest crAMM pair (frxUSD/frxETH volatile)
    address constant PAIR_A = 0xaa08c24A76a1Ad5DE28BC56B23413D13B8Be6Eeb;

    address constant FRXUSD = 0xFc00000000000000000000000000000000000001;
    address constant FRXETH = 0xFC00000000000000000000000000000000000006;
    address constant AXLUSDC = 0xEB466342C4d449BC9f53A865D5Cb90586f405215;
    address constant FRXETH2 = 0xEcc68d0451E20292406967Fe7C04280E5238Ac7D;

    uint160 constant MIN_SQRT_RATIO = 4295128739;
    uint160 constant MAX_SQRT_RATIO = 1461446703485210103287273052203988822378723970342;

    Attacker atk;
    address attacker;

    function setUp() public {
        string memory rpc = vm.envOr("FRAXTAL_RPC_URL", string("https://rpc.frax.com"));
        vm.createSelectFork(rpc);
        attacker = makeAddr("attacker");
        atk = new Attacker();
        vm.deal(attacker, 100 ether);
        vm.deal(address(atk), 100 ether);
    }

    /* ---------------- state snapshot ---------------- */

    function test_state_snapshot_live_facts() public view {
        // the value positions are owned by the team multisig (3/5)
        assertEq(INFP(NFP).ownerOf(NFT_A), NFT_OWNER_SAFE, "NFT_A owner");
        assertEq(INFP(NFP).ownerOf(NFT_B), NFT_OWNER_SAFE, "NFT_B owner");
        assertEq(INFP(NFP).ownerOf(NFT_C), NFT_OWNER_SAFE, "NFT_C owner");
        assertEq(INFP(NFP).balanceOf(NFT_OWNER_SAFE), 3, "Safe holds 3 NFTs");

        // pools hold the value
        assertGt(IClPool(POOL_A).liquidity(), 1e22, "pool A liquidity");
        assertGt(IClPool(POOL_B).liquidity(), 1e21, "pool B liquidity");
        assertGt(IClPool(POOL_C).liquidity(), 1e22, "pool C liquidity");
        assertEq(IClPool(POOL_A).fee(), 250);
        assertEq(IClPool(POOL_B).fee(), 100);
        assertEq(IClPool(POOL_C).fee(), 150);

        // governance/emissions layer inert
        assertEq(IERC20(RA).totalSupply(), 0, "RA supply 0");
        assertEq(IVotingEscrow(VE).totalSupply(), 0, "ve supply 0");
        assertEq(IERC20(XTOKEN).totalSupply(), 0, "xToken supply 0");
        assertEq(IVoter(VOTER).totalWeight(), 0, "voter weight 0");
        assertEq(IFeeCollector(FEE_COLLECTOR).isTokenLive(), false, "feeCollector not live");

        // no staked CL NFTs in the pool-A gauge
        address gaugeA = IVoter(VOTER).gauges(POOL_A);
        assertEq(INFP(NFP).balanceOf(gaugeA), 0, "no staked CL NFTs");
    }

    /* ---------------- candidate E-U paths, all expected closed ---------------- */

    function test_attacker_cannot_touch_team_positions() public {
        vm.startPrank(attacker);
        INFP.CollectParams memory cp = INFP.CollectParams(NFT_A, attacker, type(uint128).max, type(uint128).max);
        vm.expectRevert(bytes("!APPROVED"));
        INFP(NFP).collect(cp);

        INFP.DecreaseLiquidityParams memory dp = INFP.DecreaseLiquidityParams(NFT_A, 1e18, 0, 0, block.timestamp + 1);
        vm.expectRevert(bytes("!APPROVED"));
        INFP(NFP).decreaseLiquidity(dp);

        vm.expectRevert(bytes("!APPROVED"));
        INFP(NFP).burn(NFT_A);

        address[] memory toks = new address[](1);
        toks[0] = FRXUSD;
        vm.expectRevert();
        INFP(NFP).getReward(NFT_A, toks);
        vm.stopPrank();
    }

    function test_pool_direct_collect_zero_and_burn_reverts() public {
        vm.prank(attacker);
        (uint128 a0, uint128 a1) = IClPool(POOL_A).collect(attacker, A_LOWER, A_UPPER, type(uint128).max, type(uint128).max);
        assertEq(a0, 0, "attacker position empty t0");
        assertEq(a1, 0, "attacker position empty t1");

        vm.prank(attacker);
        vm.expectRevert();
        IClPool(POOL_A).burn(NFT_A, A_LOWER, A_UPPER, 1e18);
    }

    function test_collectProtocol_requires_feeCollector() public {
        vm.prank(attacker);
        vm.expectRevert();
        IClPool(POOL_A).collectProtocol(attacker, type(uint128).max, type(uint128).max);
    }

    function test_feeCollector_routes_protocol_fees_to_treasury_only() public {
        // permissionless trigger, but funds must go to the team treasury
        uint256 t0Before = IERC20(FRXUSD).balanceOf(TREASURY);
        uint256 t1Before = IERC20(FRXETH).balanceOf(TREASURY);
        uint256 a0Before = IERC20(FRXUSD).balanceOf(attacker);
        uint256 a1Before = IERC20(FRXETH).balanceOf(attacker);

        vm.prank(attacker);
        IFeeCollector(FEE_COLLECTOR).collectProtocolFees(POOL_A);

        uint256 t0Gain = IERC20(FRXUSD).balanceOf(TREASURY) - t0Before;
        uint256 t1Gain = IERC20(FRXETH).balanceOf(TREASURY) - t1Before;
        assertGt(t0Gain + t1Gain, 0, "treasury received protocol fees");
        assertEq(IERC20(FRXUSD).balanceOf(attacker), a0Before, "attacker got nothing t0");
        assertEq(IERC20(FRXETH).balanceOf(attacker), a1Before, "attacker got nothing t1");
    }

    function test_pair_skim_yields_zero_and_roundtrip_loses() public {
        uint256 a0 = IERC20(FRXUSD).balanceOf(PAIR_A);
        uint256 a1 = IERC20(FRXETH).balanceOf(PAIR_A);
        (uint256 r0, uint256 r1,) = IPair(PAIR_A).getReserves();
        assertEq(a0, r0, "no excess token0");
        assertEq(a1, r1, "no excess token1");

        vm.prank(attacker);
        IPair(PAIR_A).skim(attacker);
        assertEq(IERC20(FRXUSD).balanceOf(attacker), 0, "skim gave nothing t0");
        assertEq(IERC20(FRXETH).balanceOf(attacker), 0, "skim gave nothing t1");

        // round-trip frxUSD -> frxETH -> frxUSD
        uint256 start = 1000e18;
        deal(FRXUSD, address(atk), start);
        uint256 out1 = _pairSwap(address(atk), PAIR_A, FRXUSD, start);
        uint256 back = _pairSwap(address(atk), PAIR_A, FRXETH, out1);
        assertLt(back, start, "round trip must lose (fees)");
        assertEq(IERC20(FRXUSD).balanceOf(address(atk)), back);
    }

    function test_cl_pool_roundtrip_loses() public {
        deal(FRXUSD, address(atk), 10_000e18);
        uint256 start = 10_000e18;
        uint256 out1 = _clSwap(address(atk), POOL_A, FRXUSD, start);
        uint256 back = _clSwap(address(atk), POOL_A, FRXETH, out1);
        assertLt(back, start, "CL round trip must lose");
    }

    function test_flash_without_repayment_reverts() public {
        uint256 bal = IERC20(FRXUSD).balanceOf(POOL_A);
        vm.prank(address(atk));
        vm.expectRevert(bytes("F0"));
        IClPool(POOL_A).flash(address(atk), bal / 1000, 0, "");
    }

    function test_flash_with_repayment_net_loses_fee() public {
        uint256 bal = IERC20(FRXUSD).balanceOf(POOL_A);
        uint256 borrow = bal / 1000;
        uint24 curFee = IClPool(POOL_A).currentFee(); // live fee (states.fee), not initialFee
        uint256 fee = (borrow * curFee + 1e6 - 1) / 1e6; // mulDivRoundingUp(borrow, curFee, 1e6)
        FlashRepayer rep = new FlashRepayer();
        deal(FRXUSD, address(rep), borrow + fee);
        uint256 before = IERC20(FRXUSD).balanceOf(address(rep));
        vm.prank(address(rep));
        IClPool(POOL_A).flash(address(rep), borrow, 0, abi.encode(borrow));
        uint256 afterBal = IERC20(FRXUSD).balanceOf(address(rep));
        assertEq(before - afterBal, fee, "attacker pays exactly the flash fee, no profit");
    }

    function test_initialize_already_initialized_reverts() public {
        (uint160 sqrtP,,,,,,) = IClPool(POOL_A).slot0();
        vm.prank(attacker);
        vm.expectRevert(bytes("AI"));
        IClPool(POOL_A).initialize(sqrtP);
    }

    function test_governance_layer_inert() public {
        // cannot create a veNFT: RA has zero supply
        vm.prank(attacker);
        vm.expectRevert();
        IVotingEscrow(VE).createLock(1e18, 4 * 365 days);

        // cannot vote with a non-existent veNFT
        address[] memory pools = new address[](1);
        pools[0] = POOL_A;
        uint256[] memory weights = new uint256[](1);
        weights[0] = 1;
        vm.prank(attacker);
        vm.expectRevert();
        IVoter(VOTER).vote(1, pools, weights);

        // fee distributor claim for a non-existent veNFT reverts
        address[] memory toks = new address[](1);
        toks[0] = FRXUSD;
        vm.prank(attacker);
        vm.expectRevert();
        IFeeDistributor(0x8E73cF029Befd464f54C6E1499006686961530Ff).getReward(1, toks);

        // legacy gauge: attacker cannot withdraw staked LP
        (bool ok,) = LEGACY_GAUGE_A.call(abi.encodeWithSignature("withdraw(uint256)", 1e18));
        assertFalse(ok, "attacker withdraw must revert");
    }

    /* ---------------- positive control: owner (H-O) can withdraw ---------------- */

    function test_owner_can_withdraw_HO() public {
        uint256 before0 = IERC20(FRXUSD).balanceOf(NFT_OWNER_SAFE);
        uint256 before1 = IERC20(FRXETH).balanceOf(NFT_OWNER_SAFE);

        vm.startPrank(NFT_OWNER_SAFE);
        INFP.DecreaseLiquidityParams memory dp =
            INFP.DecreaseLiquidityParams(NFT_A, 1e18, 0, 0, block.timestamp + 1);
        (uint256 am0, uint256 am1) = INFP(NFP).decreaseLiquidity(dp);
        INFP.CollectParams memory cp = INFP.CollectParams(NFT_A, NFT_OWNER_SAFE, type(uint128).max, type(uint128).max);
        INFP(NFP).collect(cp);
        vm.stopPrank();

        uint256 gain0 = IERC20(FRXUSD).balanceOf(NFT_OWNER_SAFE) - before0;
        uint256 gain1 = IERC20(FRXETH).balanceOf(NFT_OWNER_SAFE) - before1;
        assertGt(gain0 + gain1, 0, "owner receives tokens");
        // tiny amount (1e18 liquidity out of 2.36e22)
        assertGt(am0 + am1, 0, "burn returned amounts");
    }

    /* ---------------- donation dead-end ---------------- */

    function test_donation_to_team_position_is_not_recoverable() public {
        // attacker adds liquidity under the (NFP, tokenId) pool-position key
        deal(FRXUSD, address(atk), 100e18);
        deal(FRXETH, address(atk), 0.04e18);
        vm.startPrank(address(atk));
        IERC20(FRXUSD).approve(POOL_A, type(uint256).max);
        IERC20(FRXETH).approve(POOL_A, type(uint256).max);
        IClPool(POOL_A).mint(NFP, NFT_A, A_LOWER, A_UPPER, 1e15, "");
        vm.stopPrank();

        // the NFP manager is unaware; the attacker's own key is empty
        vm.prank(attacker);
        (uint128 c0, uint128 c1) = IClPool(POOL_A).collect(attacker, A_LOWER, A_UPPER, type(uint128).max, type(uint128).max);
        assertEq(c0 + c1, 0, "donation not recoverable by attacker");
    }

    /* ---------------- helpers ---------------- */

    function _pairSwap(address who, address pair, address tokenIn, uint256 amountIn) internal returns (uint256 out) {
        address t0 = IPair(pair).token0();
        bool zeroForOne = tokenIn == t0;
        out = IPair(pair).getAmountOut(amountIn, tokenIn);
        vm.prank(who);
        IERC20(tokenIn).transfer(pair, amountIn);
        vm.prank(who);
        if (zeroForOne) {
            IPair(pair).swap(0, out, who, "");
        } else {
            IPair(pair).swap(out, 0, who, "");
        }
    }

    function _clSwap(address who, address pool, address tokenIn, uint256 amountIn) internal returns (uint256 out) {
        address t0 = IClPool(pool).token0();
        bool zeroForOne = tokenIn == t0;
        uint160 limit = zeroForOne ? MIN_SQRT_RATIO + 1 : MAX_SQRT_RATIO - 1;
        vm.prank(who);
        (int256 a0, int256 a1) = IClPool(pool).swap(who, zeroForOne, int256(amountIn), limit, "");
        out = zeroForOne ? uint256(-a1) : uint256(-a0);
    }
}
