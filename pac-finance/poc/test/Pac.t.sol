// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

/* ------------------------------------------------------------------ */
/* Minimal interfaces (ABI-exact against the live Pac Finance deploy) */
/* ------------------------------------------------------------------ */

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getPriceOracle() external view returns (address);
    function getPoolConfigurator() external view returns (address);
    function getACLManager() external view returns (address);
    function owner() external view returns (address);
}

interface IPool {
    function getReservesList() external view returns (address[] memory);
    function getConfiguration(address asset) external view returns (uint256);
    function getUserConfiguration(address user) external view returns (uint256);
    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);
    function getReserveNormalizedIncome(address asset) external view returns (uint256);
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function flashLoanSimple(address receiverAddress, address asset, uint256 amount, bytes calldata params, uint16 referralCode) external;
    function mintToTreasury(address[] calldata assets) external;
    function rescueTokens(address token, address to, uint256 amount) external;
}

interface IAaveOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function getSourceOfAsset(address asset) external view returns (address);
    function setAssetSources(address[] calldata assets, address[] calldata sources) external;
}

interface IPoolConfigurator {
    function setReservePause(address asset, bool paused) external;
}

interface IACLManager {
    function isPoolAdmin(address user) external view returns (bool);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function scaledTotalSupply() external view returns (uint256);
    function RESERVE_TREASURY_ADDRESS() external view returns (address);
    function claimYield(address recipient) external;
    function yieldDistributor() external view returns (address);
}

interface INativeYieldDistribute {
    function getPendingYield(address user) external view returns (uint256);
    function claimYield() external;
    function rescueToken(address token, address to, uint256 amount) external;
}

interface IGasRefund {
    function gasBalance(address user) external view returns (uint256);
    function claimGas() external;
}

interface IPoolAddressesProviderRegistry {
    function getAddressesProvidersList() external view returns (address[] memory);
}

contract PacFinanceLiveAuditTest is Test {
    /* --------------------------- addresses --------------------------- */
    address constant PROVIDER = 0x688B5fd3C3E3724b4De08C4BCB3A755F9b579c9a;
    address constant POOL = 0xd2499b3c8611E36ca89A70Fda2A72C49eE19eAa8;
    address constant ORACLE = 0xAf77325317F109ee21459AFeEDE51b16C231e6b1;
    address constant CONFIGURATOR = 0xCc24504b36A022D8DEF8E65f3cD3F4899E79FcFc;
    address constant ACL = 0xfE1D7B882b4E7A91eD76b2a47AeA0085D4543E21;
    address constant REGISTRY = 0xdb3CeAA3ff702242B9aAAE63e4Ba673Ef7a2517d;
    address constant PROVIDER_OWNER = 0x17816E9A858b161c3E37016D139cf618056CaCD4;

    address constant WETH = 0x4300000000000000000000000000000000000004;
    address constant USDB = 0x4300000000000000000000000000000000000003;
    address constant FWWETH = 0x66714DB8F3397c767d0A602458B5b4E3C0FE7dd1;
    address constant FWUSDB = 0x866f2C06B83Df2ed7Ca9C2D044940E7CD55a06d6;
    address constant RING = 0x9BE8a40C9cf00fe33fd84EAeDaA5C4fe3f04CbC3;
    address constant OETH = 0x0872b71EFC37CB8DdE22B2118De3d800427fdba0;
    address constant OUSDB = 0x9aECEdCD6A82d26F2f86D331B17a1C1676442A87;
    address constant EZETH = 0x2416092f143378750bb29b79eD961ab195CcEea5;
    address constant SLPUSDB = 0x56e0f6DF03883611C9762e78d4091E39aD9c420E;
    address constant SLPWETH = 0x3D4621fa5ff784dfB2fcDFd5B293224167F239db;
    address constant TLP = 0x12c69BFA3fb3CbA75a1DEFA6e976B87E233fc7df;
    address constant WBTC = 0xF7bc58b8D8f97ADC129cfC4c9f45Ce3C0E1D2692;
    address constant WRSETH = 0xe7903B1F75C534Dd8159b313d92cDCfbC62cB3Cd;
    address constant DETH = 0x1Da40C742F32bBEe81694051c0eE07485fC630f6;
    address constant DUSD = 0x1A3D9B2fa5c6522c8c071dC07125cE55dF90b253;

    address constant AWETH = 0x63749b03bdB4e86E5aAF7E5a723bF993DBf0c1c5;
    address constant AUSDB = 0xc7206216F28C23B2Da6537d296e789CFB81b31Ef;
    address constant ADETH = 0x97257A7c033773d54dFe83bFcdce056af8321ae2;
    address constant AUSDB_TREASURY_DIST = 0xAd49EE1956704F1ec97CE7A9850A3608Bf0bECc3; // NativeYieldDistribute (USDB)
    address constant AWETH_TREASURY_DIST = 0x5eBe2de08276048A601646eb8FB911e0B47C4396; // NativeYieldDistribute (WETH)
    address constant GAS_REFUND = 0xBCD03b012a8457824ECbBA36E559401dB7B35EF0;

    // verified live holders / users (checked at Blast block 41,114,238+)
    address constant DETH_HOLDER = 0xC6358878Cc8a4153c043d8789Bfc35ec1c64fa64; // 691.75 aDETH
    address constant WRSETH_HOLDER = 0x20e7A8C5D11d8c2F58b8147591285B870bbA98AC; // 0.2959 awrsETH, no debt
    address constant USDB_HOLDER = 0x3D3eb99C278C7A50d8cf5fE7eBF0AD69066Fb7d1; // 0.16 aUSDB, no debt
    address constant OUSDB_ONLY_USER = 0xd1d0E893f9a7AFf8204C3cBd49D6A2B14e71ea9c; // oUSDB-only portfolio
    address constant MIXED_USER = 0x35eFf7A71bd445149d75307DcbB663d63f5e08eA; // USDB collateral + oUSDB debt
    address constant BIG_MIXED_BORROWER = 0x644E230916734E0d3bFd54627bB1D11ea17D7dD9; // 6.04M scaled oUSDB debt + DETH
    address constant GAS_USER = 0xA22B1a3D2aE3719fcE4411cc84243EA6A2166460;

    IPool pool = IPool(POOL);
    IAaveOracle oracle = IAaveOracle(ORACLE);
    IAToken aUSDB = IAToken(AUSDB);
    IAToken aWETH = IAToken(AWETH);
    IAToken aDETH = IAToken(ADETH);
    INativeYieldDistribute nydUSDB = INativeYieldDistribute(AUSDB_TREASURY_DIST);
    IGasRefund gasRefund = IGasRefund(GAS_REFUND);

    function setUp() public {
        string memory url = vm.envOr("BLAST_RPC_URL", string(""));
        if (bytes(url).length > 0) {
            vm.createSelectFork(url);
            emit log_named_uint("fork block", block.number);
            return;
        }
        try vm.createSelectFork("https://blast-rpc.publicnode.com") {
            emit log_named_uint("fork block", block.number);
            return;
        } catch {}
        vm.createSelectFork("https://rpc.blast.io");
        emit log_named_uint("fork block", block.number);
    }

    /* ------------------------------------------------------------------ */
    /* 1. deployment is live, one pool only                                */
    /* ------------------------------------------------------------------ */
    function test_01_provider_and_reserves_live() public {
        IPoolAddressesProvider provider = IPoolAddressesProvider(PROVIDER);
        assertEq(provider.getPool(), POOL, "pool mismatch");
        assertEq(provider.getPriceOracle(), ORACLE, "oracle mismatch");
        assertEq(provider.getPoolConfigurator(), CONFIGURATOR, "configurator mismatch");
        assertEq(provider.getACLManager(), ACL, "acl mismatch");

        address[] memory reserves = pool.getReservesList();
        assertEq(reserves.length, 15, "15 reserves expected");
        emit log_named_uint("reserves", reserves.length);

        // single provider in registry -> single deployment
        address[] memory providers =
            IPoolAddressesProviderRegistry(REGISTRY).getAddressesProvidersList();
        assertEq(providers.length, 1, "one provider");
        assertEq(providers[0], PROVIDER, "provider is the audited one");
    }

    /* ------------------------------------------------------------------ */
    /* 2. oracle is bricked for every asset except oUSDB                   */
    /* ------------------------------------------------------------------ */
    function test_02_oracle_reverts_for_all_but_ousdb() public {
        address[14] memory broken = [
            WETH, USDB, FWWETH, FWUSDB, RING, OETH, EZETH, SLPUSDB,
            SLPWETH, TLP, WBTC, WRSETH, DETH, DUSD
        ];
        for (uint256 i = 0; i < broken.length; i++) {
            vm.expectRevert();
            oracle.getAssetPrice(broken[i]);
        }
        // only oUSDB returns a price: 0.20163 USD (8 decimals), based on a stale
        // exchange rate (2.016e14) times a constant 1e8 "USDB" feed.
        assertEq(oracle.getAssetPrice(OUSDB), 20163, "oUSDB price");
        emit log_named_uint("oUSDB oracle price (1e8)", oracle.getAssetPrice(OUSDB));
        assertEq(
            oracle.getSourceOfAsset(OUSDB),
            0x6996D76d47123D0B7E8ebBC48F6CD728FE4341D7,
            "oUSDB source"
        );
    }

    /* ------------------------------------------------------------------ */
    /* 3. DETH market is paused+frozen: nothing can move                    */
    /* ------------------------------------------------------------------ */
    function test_03_deth_market_fully_locked() public {
        uint256 cfg = pool.getConfiguration(DETH);
        bool frozen = ((cfg >> 57) & 1) == 1;
        bool paused = ((cfg >> 60) & 1) == 1;
        assertTrue(frozen, "DETH frozen");
        assertTrue(paused, "DETH paused");

        // flash loan on DETH reverts RESERVE_PAUSED ("29")
        vm.expectRevert(bytes("29"));
        pool.flashLoanSimple(address(this), DETH, 1, "", 0);

        // the largest DETH holder cannot withdraw: RESERVE_PAUSED
        uint256 bal = aDETH.balanceOf(DETH_HOLDER);
        assertGt(bal, 100e18, "holder has DETH");
        vm.prank(DETH_HOLDER);
        vm.expectRevert(bytes("29"));
        pool.withdraw(DETH, 1e18, DETH_HOLDER);

        // DETH cash sits in the aToken but is unreachable while paused
        uint256 cash = IERC20(DETH).balanceOf(ADETH);
        emit log_named_uint("DETH cash locked in aDETH", cash);
        assertGt(cash, 1000e18, "DETH cash > 1000");
    }

    /* ------------------------------------------------------------------ */
    /* 4. H-O: unpaused markets allow holders to self-withdraw              */
    /* ------------------------------------------------------------------ */
    function test_04_holder_withdrawals_work() public {
        // wrsETH holder (collateral enabled, no debt) withdraws 0.01
        uint256 before = IERC20(WRSETH).balanceOf(WRSETH_HOLDER);
        vm.prank(WRSETH_HOLDER);
        pool.withdraw(WRSETH, 0.01e18, WRSETH_HOLDER);
        assertEq(IERC20(WRSETH).balanceOf(WRSETH_HOLDER), before + 0.01e18, "wrsETH withdrawn");

        // USDB holder withdraws 0.01 (cash = ~19 USDB)
        uint256 beforeU = IERC20(USDB).balanceOf(USDB_HOLDER);
        vm.prank(USDB_HOLDER);
        pool.withdraw(USDB, 0.01e18, USDB_HOLDER);
        assertEq(IERC20(USDB).balanceOf(USDB_HOLDER), beforeU + 0.01e18, "USDB withdrawn");
    }

    /* ------------------------------------------------------------------ */
    /* 5. liquidations are impossible: HF calc needs broken prices          */
    /* ------------------------------------------------------------------ */
    function test_05_liquidations_bricked() public {
        // any user with a non-oUSDB position cannot even be priced
        vm.expectRevert();
        pool.getUserAccountData(MIXED_USER);
        vm.expectRevert();
        pool.getUserAccountData(BIG_MIXED_BORROWER);

        // liquidation call on such a user reverts in the oracle
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        pool.liquidationCall(USDB, OUSDB, MIXED_USER, 1e18, false);

        // the only fully-priceable portfolio (oUSDB-only) is healthy -> HF check
        (, , , , , uint256 hf) = pool.getUserAccountData(OUSDB_ONLY_USER);
        assertGt(hf, 1e18, "oUSDB-only user healthy");
        vm.prank(address(0xBEEF));
        vm.expectRevert(bytes("45")); // HEALTH_FACTOR_NOT_BELOW_THRESHOLD
        pool.liquidationCall(OUSDB, OUSDB, OUSDB_ONLY_USER, 1e18, false);
    }

    /* ------------------------------------------------------------------ */
    /* 6. borrow paths are dead (oracle or zero liquidity)                  */
    /* ------------------------------------------------------------------ */
    function test_06_borrow_paths_dead() public {
        // borrowing USDB needs the (broken) USDB price
        vm.prank(OUSDB_ONLY_USER);
        vm.expectRevert();
        pool.borrow(USDB, 1e18, 2, 0, OUSDB_ONLY_USER);

        // borrowing oUSDB against oUSDB collateral is priceable but the
        // market has no liquidity left (cash < 1e-6 oUSDB)
        uint256 cash = IERC20(OUSDB).balanceOf(0xce7c5A6a86206b68A746615C1F6b473EdB6470B3);
        assertLt(cash, 1e12, "no oUSDB liquidity");
        vm.prank(OUSDB_ONLY_USER);
        vm.expectRevert();
        pool.borrow(OUSDB, 1e18, 2, 0, OUSDB_ONLY_USER);
    }

    /* ------------------------------------------------------------------ */
    /* 7. mintToTreasury is permissionless but pays only the treasury       */
    /* ------------------------------------------------------------------ */
    function test_07_mintToTreasury_permissionless_no_profit() public {
        address treasury = aUSDB.RESERVE_TREASURY_ADDRESS();
        uint256 tBefore = aUSDB.balanceOf(treasury);
        address attacker = address(0xA11CE);
        address[] memory assets = new address[](1);
        assets[0] = USDB;
        vm.prank(attacker);
        pool.mintToTreasury(assets);
        uint256 tAfter = aUSDB.balanceOf(treasury);
        assertGe(tAfter, tBefore, "treasury aToken minted");
        assertEq(IERC20(USDB).balanceOf(attacker), 0, "attacker gets nothing");
        assertEq(aUSDB.balanceOf(attacker), 0, "attacker gets no aToken");
        emit log_named_uint("treasury aUSDB delta", tAfter - tBefore);
    }

    /* ------------------------------------------------------------------ */
    /* 8. NativeYieldDistribute: claims are per-user, attacker gets 0       */
    /* ------------------------------------------------------------------ */
    function test_08_native_yield_claim_is_user_only() public {
        address attacker = address(0xBAD);
        vm.prank(attacker);
        nydUSDB.claimYield();
        assertEq(IERC20(USDB).balanceOf(attacker), 0, "attacker claims 0");

        // a real historic supplier has pending yield (H-O)
        uint256 pending = nydUSDB.getPendingYield(USDB_HOLDER);
        emit log_named_uint("pending yield of holder (USDB)", pending);
        assertGt(pending, 0, "holder has pending yield");
        uint256 before = IERC20(USDB).balanceOf(USDB_HOLDER);
        vm.prank(USDB_HOLDER);
        nydUSDB.claimYield();
        uint256 got = IERC20(USDB).balanceOf(USDB_HOLDER) - before;
        emit log_named_uint("claimed", got);
        assertGt(got, 0, "holder claimed");
        assertApproxEqRel(got, pending, 0.01e18, "claim matches pending");
    }

    /* ------------------------------------------------------------------ */
    /* 9. GasRefund: user-only claim (H-O)                                  */
    /* ------------------------------------------------------------------ */
    function test_09_gasrefund_user_only() public {
        uint256 bal = gasRefund.gasBalance(GAS_USER);
        assertGt(bal, 0, "user has refund");
        uint256 before = GAS_USER.balance;
        vm.prank(GAS_USER);
        gasRefund.claimGas();
        assertEq(GAS_USER.balance, before + bal, "user got refund");
        assertEq(gasRefund.gasBalance(GAS_USER), 0, "refund zeroed");

        address attacker = address(0xCAFE);
        vm.prank(attacker);
        gasRefund.claimGas();
        assertEq(attacker.balance, 0, "attacker gets 0");
    }

    /* ------------------------------------------------------------------ */
    /* 10. admin surfaces are gated                                         */
    /* ------------------------------------------------------------------ */
    function test_10_admin_surfaces_gated() public {
        address attacker = address(0xDEAD);
        vm.startPrank(attacker);

        vm.expectRevert(bytes("3")); // CALLER_NOT_RISK_OR_POOL_ADMIN
        IPoolConfigurator(CONFIGURATOR).setReservePause(DETH, false);

        vm.expectRevert(bytes("1"));
        pool.rescueTokens(USDB, attacker, 1);

        vm.expectRevert(bytes("1"));
        aUSDB.claimYield(attacker);

        vm.expectRevert(bytes("5")); // CALLER_NOT_ASSET_LISTING_OR_POOL_ADMIN
        address[] memory a = new address[](1);
        a[0] = USDB;
        address[] memory s = new address[](1);
        s[0] = address(1);
        oracle.setAssetSources(a, s);

        vm.expectRevert("Ownable: caller is not the owner");
        nydUSDB.rescueToken(USDB, attacker, 1);
        vm.stopPrank();

        // owner of the provider is an EOA -> no permissionless admin path
        assertEq(IPoolAddressesProvider(PROVIDER).owner(), PROVIDER_OWNER, "provider owner");
        assertEq(PROVIDER_OWNER.code.length, 0, "owner is EOA");
    }

    /* ------------------------------------------------------------------ */
    /* 11. headline accounting: value is claims, not cash                   */
    /* ------------------------------------------------------------------ */
    function test_11_claims_vs_cash() public {
        uint256 usdbCash = IERC20(USDB).balanceOf(AUSDB);
        uint256 usdbClaims = aUSDB.totalSupply();
        emit log_named_uint("aUSDB cash", usdbCash);
        emit log_named_uint("aUSDB totalSupply (claims)", usdbClaims);
        assertLt(usdbCash, usdbClaims / 10000, "USDB cash < 0.01% of claims");

        uint256 wethCash = IERC20(WETH).balanceOf(AWETH);
        uint256 wethClaims = aWETH.totalSupply();
        emit log_named_uint("aWETH cash", wethCash);
        emit log_named_uint("aWETH totalSupply (claims)", wethClaims);
        assertLt(wethCash, wethClaims / 1000000, "WETH cash < 0.0001% of claims");

        // yield pots held for users (H-O)
        emit log_named_uint("NYD USDB pot", IERC20(USDB).balanceOf(AUSDB_TREASURY_DIST));
        emit log_named_uint("NYD WETH pot", IERC20(WETH).balanceOf(AWETH_TREASURY_DIST));
        emit log_named_uint("GasRefund ETH pot", GAS_REFUND.balance);
    }
}
