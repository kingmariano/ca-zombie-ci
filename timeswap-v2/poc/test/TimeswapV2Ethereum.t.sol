// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import "./TimeswapV2Interfaces.sol";

/// Timeswap V2 zombie assessment — Ethereum fork PoC (read-only simulation; no mainnet txs).
/// The largest live pair is apxETH/WETH ($51.25k). All maturities are past. Tests show:
///  - the value is held as *short* claims wrapped as ERC1155 for users (H-O),
///  - an outsider cannot collect,
///  - long-denominated protocol fees are owner-collectible but dead post-maturity (P = $0 real).
contract TimeswapV2EthereumTest is Test {
    address constant OPTION_FACTORY_V20 = 0xcf0aca5c5b7e1bF63514D362243b6c50d5761FE8;
    address constant POOL_FACTORY_V20 = 0x8E3fcda01FCA533989C3CeABdcF2A6E0A776585F;
    address constant POOL_FACTORY_V25 = 0x97509c65Ff29C268F0D283A41201Be6b4090354c;
    address constant TOKENS_V25 = 0x4aA2Bc42FcAC903E5732dFd419EEB09d97Ae287c; // v2.5 wrapper (holds apxETH/WETH shorts)

    address constant APXETH_WETH_OPTION = 0xFa0a3cf986197CF2b691459c2194f2Fb1CEC2dBa;
    address constant APXETH_WETH_POOL = 0x5d0F13171D25AF12Ed17632DbE96526e5eee18BF;
    uint256 constant AW_STRIKE = 336879543251729078828740861357450529341;
    uint256 constant AW_MATURITY = 1712577600;
    address constant APXETH = 0x9Ba021B0a9b958B5E75cE9f6dff97C7eE52cb3E6;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    // v2.0 BLUR/USDC pool (owner-gate check on the older generation)
    address constant BLUR_USDC_POOL = 0x9275b973d6DCa838B968492C8dA854315aC3957d;
    uint256 constant BLUR_STRIKE = 102084710076281539039012;
    uint256 constant BLUR_MATURITY = 1679659200;

    address attacker = address(0xA77ACC);

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))));
    }

    function test_eth_outsider_cannot_collect() public {
        ITimeswapV2Option option = ITimeswapV2Option(APXETH_WETH_OPTION);
        assertGt(option.totalPosition(AW_STRIKE, AW_MATURITY, OptionPosition.Short), 0);
        vm.prank(attacker);
        vm.expectRevert();
        option.collect(
            OptionCollectParam(AW_STRIKE, AW_MATURITY, attacker, attacker, OptionCollect.GivenShort, 1e15, "")
        );
    }

    function test_eth_shorts_are_wrapped_for_users() public {
        ITimeswapV2Option option = ITimeswapV2Option(APXETH_WETH_OPTION);
        uint256 totalShort = option.totalPosition(AW_STRIKE, AW_MATURITY, OptionPosition.Short);
        uint256 wrapped = option.positionOf(AW_STRIKE, AW_MATURITY, TOKENS_V25, OptionPosition.Short);
        assertGt(wrapped * 1000, totalShort * 999, "99.9%+ of shorts are wrapped as user ERC1155");
        // underlying option balance (the live value) is claimable by those short holders
        assertGt(IERC20(WETH).balanceOf(APXETH_WETH_OPTION), 20e18);
    }

    function test_eth_long_protocol_fee_is_dead() public {
        ITimeswapV2Option option = ITimeswapV2Option(APXETH_WETH_OPTION);
        ITimeswapV2Pool pool = ITimeswapV2Pool(APXETH_WETH_POOL);
        address owner = ITimeswapV2PoolFactory(POOL_FACTORY_V25).owner();

        (uint256 l0f, uint256 l1f, uint256 sf) = pool.protocolFeesEarned(AW_STRIKE, AW_MATURITY);
        assertEq(sf, 0, "no short protocol fees on this pool");
        assertGt(l1f, 0, "long1 protocol fees are non-zero (nominal)");

        // owner-only gate
        vm.prank(attacker);
        vm.expectRevert();
        pool.collectProtocolFees(PoolCollectProtocolFeesParam(AW_STRIKE, AW_MATURITY, attacker, attacker, attacker, 0, type(uint256).max, 0));

        // owner can move the (dead) long1 position
        vm.prank(owner);
        (uint256 l0, uint256 l1, uint256 s) = pool.collectProtocolFees(
            PoolCollectProtocolFeesParam(AW_STRIKE, AW_MATURITY, owner, owner, owner, 0, type(uint256).max, 0)
        );
        assertEq(l0, 0);
        assertEq(s, 0);
        assertEq(l1, l1f, "owner receives the long1 fee amount");
        assertGe(option.positionOf(AW_STRIKE, AW_MATURITY, owner, OptionPosition.Long1), l1);

        // but a long position cannot be converted to tokens post-maturity...
        vm.prank(owner);
        vm.expectRevert(); // alreadyMatured
        option.burn(OptionBurnParam(AW_STRIKE, AW_MATURITY, owner, owner, OptionBurn.GivenTokensAndLongs, 0, 1, ""));
        // ...and the owner holds no shorts, so collect is impossible
        assertEq(option.positionOf(AW_STRIKE, AW_MATURITY, owner, OptionPosition.Short), 0);
    }

    function test_eth_v20_pool_protocol_fee_owner_gate() public {
        ITimeswapV2Pool pool = ITimeswapV2Pool(BLUR_USDC_POOL);
        vm.prank(attacker);
        vm.expectRevert();
        pool.collectProtocolFees(PoolCollectProtocolFeesParam(BLUR_STRIKE, BLUR_MATURITY, attacker, attacker, attacker, type(uint256).max, type(uint256).max, type(uint256).max));
        // factory owner is a plain address on v2.0
        address owner = ITimeswapV2PoolFactory(POOL_FACTORY_V20).owner();
        assertTrue(owner != address(0) && owner != attacker);
    }

    function test_eth_peripheries_hold_no_funds() public {
        // v2.0 UniswapV3 periphery set (Ethereum) — refundNatives()/unwrapWrappedNatives() are permissionless
        address[7] memory periphs = [
            0x5073657C5459a6BcB66a769Ad9687D2576630f53, // UniswapV3LendGivenPrincipal
            0x28D0591275863d5d8ED33Ea30a8Ab58C351155A9, // UniswapV3BorrowGivenPrincipal
            0xADa7f8C6C0ca1Fe65fF913aC9c9810c076a75DD4, // UniswapV3CloseLendGivenPosition
            0x63A3ceafEc3C11E0aaa5E3c36431d5F4b690a4Ee, // UniswapV3CloseBorrowGivenPosition
            0x09bF6eE2797ac65E6C2DF0C642252AE37A30fCC1, // UniswapV3Withdraw
            0xb3C9e391619d8972C84be26Aa5c8BA8a5d75cb9e, // UniswapV3AddLiquidityGivenPrincipal
            0xaE16386689a68851F9C3B713bAec8989FAcA74B5  // TimeswapV2Periphery
        ];
        for (uint256 i = 0; i < periphs.length; i++) {
            assertEq(periphs[i].balance, 0, "periphery native balance");
            assertEq(IERC20(WETH).balanceOf(periphs[i]), 0, "periphery WETH balance");
        }
    }

    function test_eth_value_context() public {
        emit log_named_decimal_uint("WETH held by apxETH/WETH option", IERC20(WETH).balanceOf(APXETH_WETH_OPTION), 18);
        emit log_named_decimal_uint("apxETH held by option", IERC20(APXETH).balanceOf(APXETH_WETH_OPTION), 18);
    }
}
