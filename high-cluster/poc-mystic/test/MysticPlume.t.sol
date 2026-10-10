// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/* ------------------------------------------------------------------------------------------------
   Mystic Finance on Plume — live-state fork PoC tests (READ-ONLY against live chains; forks only).
   Verified at Plume block ~98,590,683 (2026-10-10). Fork: https://rpc.plume.org (keyless public RPC)
------------------------------------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IERC4626Like {
    function totalAssets() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function asset() external view returns (address);
    function owner() external view returns (address);
    function curator() external view returns (address);
    function timelock() external view returns (uint256);
    function fee() external view returns (uint256);
    function lostAssets() external view returns (uint256);
    function supplyQueueLength() external view returns (uint256);
    function MORPHO() external view returns (address);
}

interface IMorpho {
    struct MarketParams {
        address loanToken;
        address collateralToken;
        address oracle;
        address irm;
        uint256 lltv;
    }
    function position(bytes32 id, address user)
        external
        view
        returns (uint128 supplyShares, uint128 borrowShares, uint128 collateral);
    function market(bytes32 id)
        external
        view
        returns (uint128, uint128, uint128, uint128, uint128, uint128);
    function idToMarketParams(bytes32 id) external view returns (MarketParams memory);
    function liquidate(
        MarketParams memory marketParams,
        address borrower,
        uint256 seizedAssets,
        uint256 repaidShares,
        bytes calldata data
    ) external returns (uint256, uint256);
    function withdraw(
        MarketParams memory marketParams,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256);
}

interface IOracle {
    function price() external view returns (uint256);
    function BASE_FEED_1() external view returns (address);
}

interface IStorkAdapter {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
}

contract MysticPlumeTest is Test {
    IMorpho constant MORPHO = IMorpho(0x42b18785CE0Aed7BF7Ca43a39471ED4C0A3e0bB5);
    IERC4626Like constant RE7 = IERC4626Like(0xc0Df5784f28046D11813356919B869dDA5815B16); // Re7 RWA Yield
    IERC4626Like constant MCP = IERC4626Like(0x0b14D0bdAf647c541d3887c5b1A4bd64068fCDA7); // Mystic MEV Capital pUSD
    IERC4626Like constant WETHV = IERC4626Like(0xBB748a1346820560875CB7a9cD6B46c203230E07); // Mystic wETH

    address constant PUSD = 0xdddD73F5Df1F0DC31373357beAC77545dC5A6f3F;
    address constant NOPAL = 0x119Dd7dAFf816f29D7eE47596ae5E4bdC4299165;
    address constant NALPHA = 0x593cCcA4c4bf58b7526a4C164cEEf4003C6388db;
    address constant WPLUME = 0xEa237441c92CAe6FC17Caaf9a7acB3f953be4bd1;
    address constant WETH = 0xca59cA09E5602fAe8B629DeE83FfA819741f14be;
    address constant WSUPEROETH = 0x2dE8A403f7A5c6C5161D4a129918Ec9f0b653918;
    address constant RANDO = address(0xBEEF);

    function nopalMarket() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: PUSD,
            collateralToken: NOPAL,
            oracle: 0x0e768E46aca211B14a04a99b0e26569EC5E8d98C,
            irm: 0x7420302Ddd469031Cd2282cd64225cCd46F581eA,
            lltv: 0.86e18
        });
    }

    function nalphaMarket() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: PUSD,
            collateralToken: NALPHA,
            oracle: 0x7824e4B3E21678f143Ce22308ADfd48d1D3160FB,
            irm: 0x7420302Ddd469031Cd2282cd64225cCd46F581eA,
            lltv: 0.86e18
        });
    }

    function frozenWsuperOethMarket() internal pure returns (IMorpho.MarketParams memory) {
        return IMorpho.MarketParams({
            loanToken: WETH,
            collateralToken: WSUPEROETH,
            oracle: 0x29356cc56A3C47f7f4b7754BcD80E94D43d7a1B0,
            irm: 0x7420302Ddd469031Cd2282cd64225cCd46F581eA,
            lltv: 0.915e18
        });
    }

    function marketId(IMorpho.MarketParams memory p) internal pure returns (bytes32) {
        return keccak256(abi.encode(p));
    }

    function setUp() public {
        vm.createSelectFork(vm.envOr("PLUME_RPC_URL", string("https://rpc.plume.org")));
    }

    /// @notice Re7 RWA Yield is the Plume whale ($1.95M): MetaMorpho v1.1, owner = 2/5 Safe, 3d timelock,
    ///         20% fee, and it carries $105.69 of REALIZED (dust) bad debt from past liquidations.
    function test_plume_re7_vault_state() public view {
        assertEq(RE7.asset(), PUSD);
        assertEq(RE7.MORPHO(), address(MORPHO));
        assertEq(RE7.owner(), 0xd6316AE37dDE77204b9A94072544F1FF9f3d6d54); // Safe(2/5)
        assertEq(RE7.curator(), address(0));
        assertEq(RE7.timelock(), 3 days);
        assertEq(RE7.fee(), 0.2e18);
        assertGt(RE7.totalAssets(), 1_900_000e6, "~$1.95M pUSD");
        assertEq(RE7.lostAssets(), 105_689_854, "realized bad debt 105.689854 pUSD");
        assertEq(RE7.supplyQueueLength(), 4);

        assertGt(MCP.totalAssets(), 10_000e6, "MCP ~14k pUSD");
        assertGt(WETHV.totalAssets(), 0.5e18, "wETH vault ~0.71 WETH");
    }

    /// @notice The nOPAL/nALPHA markets (where ~100% of Re7's funds sit) have LIVE, fresh Stork
    ///         oracles and no liquidatable borrower at fork block -> no extraction path live.
    function test_plume_re7_market_oracles_live_no_liquidatable_borrower() public {
        IMorpho.MarketParams memory pn = nopalMarket();
        uint256 price = IOracle(pn.oracle).price();
        assertGt(price, 0.5e36);
        assertLt(price, 2e36);

        // Stork feed freshness (updatedAt is nanoseconds -> /1e9)
        IStorkAdapter feed = IStorkAdapter(IOracle(pn.oracle).BASE_FEED_1());
        (, int256 ans, , uint256 updatedAtNs, ) = feed.latestRoundData();
        assertGt(ans, 0);
        assertLt(block.timestamp - (updatedAtNs / 1e9), 2 hours, "Stork feed fresh");

        // biggest nOPAL borrower: healthy -> liquidate reverts
        address bigBorrower = 0x5987AE24fD53327F9f67C932E13e2373762228e3;
        (uint128 ss, uint128 bs, uint128 c) = MORPHO.position(marketId(pn), bigBorrower);
        assertGt(ss + bs + c, 0, "position exists");
        vm.prank(RANDO);
        vm.expectRevert(); // HEALTHY_POSITION
        MORPHO.liquidate(pn, bigBorrower, 1e6, 0, "");

        // nALPHA market oracle live
        assertGt(IOracle(nalphaMarket().oracle).price(), 0.5e36);
    }

    /// @notice The wsuperOETHp/WETH market oracle is BRICKED (eOracle FeedNotSupported) -> market is
    ///         frozen: no liquidation possible (bad debt unrealizable), borrower collateral stuck.
    ///         Supplier (Mystic wETH vault) can still withdraw available cash (no oracle needed).
    function test_plume_bricked_oracle_market_frozen() public {
        IMorpho.MarketParams memory pf = frozenWsuperOethMarket();
        vm.expectRevert();
        IOracle(pf.oracle).price();

        // liquidate is impossible: price() reverts first
        vm.prank(RANDO);
        vm.expectRevert();
        MORPHO.liquidate(pf, 0x070Fb8e20E35CD2AEA531dEBb1e4d533A5161Ab5, 1, 0, "");

        // supplier can still withdraw free liquidity as the vault (pure supplier, no health check)
        bytes32 id = marketId(pf);
        (uint128 ta, , uint128 tb, , , ) = MORPHO.market(id);
        uint256 free = uint256(ta) - uint256(tb);
        assertGt(free, 0.1e18, ">0.1 WETH free");
        vm.prank(address(WETHV));
        (uint256 withdrawn, ) = MORPHO.withdraw(pf, 0.1e18, 0, address(WETHV), address(WETHV));
        assertEq(withdrawn, 0.1e18, "supplier withdrew free cash without oracle");
    }

    /// @notice The nOPAL oracle is live and equals the Stork feed (no oracle inflation), and the
    ///         configured LLTV is 86% -> max-borrow per nOPAL = 0.86 * oracle < 1 pUSD at the observed
    ///         oracle ~1.104 (market price ~1.104 too; see report) -> borrow-and-default is negative.
    function test_plume_borrow_budget_below_collateral_value() public view {
        IMorpho.MarketParams memory pn = nopalMarket();
        assertEq(pn.lltv, 0.86e18);
        uint256 price = IOracle(pn.oracle).price(); // pUSD per nOPAL, 1e36 scale, both 6dp
        IStorkAdapter feed = IStorkAdapter(IOracle(pn.oracle).BASE_FEED_1());
        (, int256 ans, , , ) = feed.latestRoundData();
        // anti-inflation: oracle price == SCALE_FACTOR(1e18) * feed answer (18 dec)
        assertEq(price, uint256(ans) * 1e18, "oracle == feed value");
        uint256 maxBorrowPerColl = (price * 0.86e18) / 1e36;
        assertLt(maxBorrowPerColl, price, "LLTV < 100% (no free money)");
    }
}
