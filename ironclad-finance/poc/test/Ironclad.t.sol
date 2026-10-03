// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/* ---------------------------------------------------------------------------
   Ironclad Finance (Mode) — read-only fork verification of the unprivileged
   attack surface.  All calls are simulations on a local fork; nothing is
   broadcast.  Every value-moving path is expected to revert while the Pool is
   paused (since block 21,029,938 / 2025-03-17).

   Revert reason codes (Aave v2 Errors.sol):
     "27" = CALLER_NOT_LENDING_POOL_CONFIGURATOR
     "29" = CT_CALLER_MUST_BE_LENDING_POOL
     "64" = LP_IS_PAUSED
     "76" = CALLER_NOT_EMERGENCY_ADMIN
--------------------------------------------------------------------------- */

interface IPool {
    function paused() external view returns (bool);
    function getReservesList() external view returns (address[] memory);
    function deposit(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf) external;
    function repay(address asset, uint256 amount, uint256 rateMode, address onBehalfOf) external returns (uint256);
    function swapBorrowRateMode(address asset, uint256 rateMode) external;
    function rebalanceStableBorrowRate(address asset, address user) external;
    function setUserUseReserveAsCollateral(address asset, bool useAsCollateral) external;
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
    function flashLoan(address receiverAddress, address[] calldata assets, uint256[] calldata amounts, uint256[] calldata modes, address onBehalfOf, bytes calldata params, uint16 referralCode) external;
    function finalizeTransfer(address asset, address from, address to, uint256 amount, uint256 balanceFromBefore, uint256 balanceToBefore) external;
    function setPause(bool val) external;
    function setConfiguration(address asset, uint256 configuration) external;
    function setReserveInterestRateStrategyAddress(address asset, address rateStrategyAddress) external;
    function initialize(address provider) external;
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
    function transferUnderlyingTo(address, uint256) external;
    function burn(address, address, uint256, uint256) external;
    function mint(address, uint256, uint256) external returns (bool);
    function mintToTreasury(uint256, uint256) external;
    function handleRepayment(address, uint256) external;
    function transferOnLiquidation(address, address, uint256) external;
}

interface IVDebt {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
}

interface IConfigurator {
    function setPoolPause(bool val) external;
}

interface ITimelock {
    function queueTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) external returns (bytes32);
    function executeTransaction(address target, uint256 value, string memory signature, bytes memory data, uint256 eta) external payable returns (bytes memory);
}

interface ITreasury {
    function withdrawAllReserves() external returns (bool);
    function transferToMultisig(address asset, uint256 value) external;
}

interface IManager {
    function liquidationCall(address collateralAsset, address debtAsset, address user, uint256 debtToCover, bool receiveAToken) external;
}

interface IOracle {
    function getAssetPrice(address asset) external view returns (uint256);
    function getSourceOfAsset(address asset) external view returns (address);
}

interface IRegistry {
    function getAddressesProvidersList() external view returns (address[] memory);
}

interface IFeed {
    function latestAnswer() external view returns (int256);
    function latestTimestamp() external view returns (uint256);
    function decimals() external view returns (uint8);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract IroncladTest is Test {
    // --- core protocol ---
    address constant POOL         = 0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3;
    address constant PROVIDER     = 0xEDc83309549e36f3c7FD8c2C5C54B4c8e5FA00FC;
    address constant CONFIGURATOR = 0xc534f577c0e6c46B27fdcA6D27D132c543b0D61c;
    address constant REGISTRY     = 0x5C93B799D31d3d6a7C977f75FDB88d069565A55b;
    address constant ORACLE       = 0xE4F4F36FcBb2D53c0bAB95F5D117489579553CaA;
    address constant MANAGER      = 0x025D9d36C616946530Ff8eA32d912aBf73170947;
    address constant TIMELOCK     = 0x96bCFB86F1bFf315c13e00D850e2FAeA93CcD3e7;
    address constant TREASURY     = 0xd93E25A8B1D645b15f8c736E1419b4819Ff9e6EF;
    address constant SAFE         = 0xD4D995787D39D70F35E694dC8306D7dB863234aC;

    // --- assets ---
    address constant USDC         = 0xd988097fb8612cc24eeC14542bC03424c656005f;
    address constant WETH         = 0x4200000000000000000000000000000000000006;
    address constant MODE         = 0xDfc7C877a950e49D2610114102175A06C2e3167a;
    address constant MBTC         = 0x59889b7021243dB5B1e065385F918316cD90D46c;

    // --- tokenization ---
    address constant A_USDC  = 0xe7334Ad0e325139329E747cF2Fc24538dD564987;
    address constant V_USDC  = 0xe5415Fa763489C813694D7A79d133F0A7363310C;
    address constant A_EZETH = 0x272CfCceFbEFBe1518cd87002A8F9dfd8845A6c4;
    address constant A_MBTC  = 0xC17312076F48764d6b4D263eFdd5A30833E311DC;
    address constant A_UNIBTC = 0x0F041cf2ae959f39215EFfB50d681Df55D4d90B1;
    address constant A_WETH  = 0x9c29a8eC901DBec4fFf165cD57D4f9E03D4838f7;

    // --- feed / actors ---
    address constant WETH_FEED = 0x6F18C77EaFc61fC5F97c8485e726ad6347fB86fd;
    address constant USDC_WHALE = 0x41fce8Ebd2E05dff0488f67b48b03C73B01098b1; // holds aUSDC
    address constant VDEBT_HOLDER = 0xC4a70149330858Cd0F085E4cd81c10745c9130B1; // holds vUSDC
    address constant ATTACKER = address(0xdEaD);

    function setUp() public {
        string memory rpc = vm.envOr("MODE_RPC_URL", string("https://mainnet.mode.network"));
        vm.createSelectFork(rpc);
        emit log_named_uint("fork block", block.number);
    }

    /* 1. State snapshot */
    function test_01_state_snapshot() public {
        assertTrue(IPool(POOL).paused(), "pool must be paused");
        address[] memory reserves = IPool(POOL).getReservesList();
        assertEq(reserves.length, 11, "11 reserves");
        address[] memory providers = IRegistry(REGISTRY).getAddressesProvidersList();
        assertEq(providers.length, 1, "single market provider");
        assertEq(providers[0], PROVIDER, "provider");
        emit log_named_uint("reserves", reserves.length);
        emit log_named_uint("aUSDC underlying", IERC20(USDC).balanceOf(A_USDC));
        emit log_named_uint("aEZETH underlying", IERC20(0x2416092f143378750bb29b79eD961ab195CcEea5).balanceOf(A_EZETH));
        emit log_named_uint("aMBTC underlying", IERC20(MBTC).balanceOf(A_MBTC));
        emit log_named_uint("aMBTC totalSupply", IAToken(A_MBTC).totalSupply());
    }

    /* 2. Every value-moving Pool entry point is paused */
    function test_02_pool_value_paths_paused() public {
        address[] memory assets = new address[](1);
        assets[0] = USDC;
        uint256[] memory amounts = new uint256[](1);
        amounts[0] = 1;
        uint256[] memory modes = new uint256[](1);
        modes[0] = 0;

        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("64"));
        IPool(POOL).deposit(USDC, 1, ATTACKER, 0);

        vm.expectRevert(bytes("64"));
        IPool(POOL).withdraw(USDC, 1, ATTACKER);

        vm.expectRevert(bytes("64"));
        IPool(POOL).borrow(USDC, 1, 2, 0, ATTACKER);

        vm.expectRevert(bytes("64"));
        IPool(POOL).repay(USDC, 1, 2, ATTACKER);

        vm.expectRevert(bytes("64"));
        IPool(POOL).swapBorrowRateMode(USDC, 2);

        vm.expectRevert(bytes("64"));
        IPool(POOL).rebalanceStableBorrowRate(USDC, ATTACKER);

        vm.expectRevert(bytes("64"));
        IPool(POOL).setUserUseReserveAsCollateral(USDC, true);

        vm.expectRevert(bytes("64"));
        IPool(POOL).liquidationCall(USDC, WETH, USDC_WHALE, 1, false);

        vm.expectRevert(bytes("64"));
        IPool(POOL).flashLoan(ATTACKER, assets, amounts, modes, ATTACKER, "", 0);

        vm.expectRevert(bytes("64"));
        IPool(POOL).finalizeTransfer(USDC, ATTACKER, ATTACKER, 1, 1, 1);
        vm.stopPrank();
    }

    /* 3. aToken transfers are blocked by the paused finalizeTransfer hook */
    function test_03_atoken_transfers_blocked() public {
        uint256 bal = IAToken(A_USDC).balanceOf(USDC_WHALE);
        assertGt(bal, 0, "whale has aUSDC");

        vm.prank(USDC_WHALE);
        vm.expectRevert(bytes("64"));
        IAToken(A_USDC).transfer(ATTACKER, 1);

        vm.prank(USDC_WHALE);
        assertTrue(IAToken(A_USDC).approve(ATTACKER, 1), "approve works (harmless)");

        vm.prank(ATTACKER);
        vm.expectRevert(bytes("64"));
        IAToken(A_USDC).transferFrom(USDC_WHALE, ATTACKER, 1);
    }

    /* 4. aToken mint/burn/underlying paths are onlyLendingPool */
    function test_04_atoken_only_pool_paths_blocked() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).transferUnderlyingTo(ATTACKER, 1);

        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).burn(USDC_WHALE, ATTACKER, 1, 1e27);

        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).mint(ATTACKER, 1, 1e27);

        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).mintToTreasury(1, 1e27);

        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).handleRepayment(ATTACKER, 1);

        vm.expectRevert(bytes("29"));
        IAToken(A_USDC).transferOnLiquidation(USDC_WHALE, ATTACKER, 1);
        vm.stopPrank();
    }

    /* 5. Admin / upgrade paths are gated */
    function test_05_admin_paths_blocked() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("27"));
        IPool(POOL).setPause(false);

        vm.expectRevert(bytes("27"));
        IPool(POOL).setConfiguration(USDC, 0);

        vm.expectRevert(bytes("27"));
        IPool(POOL).setReserveInterestRateStrategyAddress(USDC, ATTACKER);

        vm.expectRevert("Contract instance has already been initialized");
        IPool(POOL).initialize(PROVIDER);

        vm.expectRevert(bytes("76"));
        IConfigurator(CONFIGURATOR).setPoolPause(false);

        // proxy upgrade: caller is not the immutable ADMIN (Provider/Configurator)
        vm.expectRevert();
        (bool ok1, ) = POOL.call(abi.encodeWithSignature("upgradeTo(address)", ATTACKER));
        ok1;

        vm.expectRevert();
        (bool ok2, ) = A_USDC.call(abi.encodeWithSignature("upgradeTo(address)", ATTACKER));
        ok2;
        vm.stopPrank();
    }

    /* 6. Timelock + Treasury are privileged */
    function test_06_timelock_treasury_blocked() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert("Timelock::queueTransaction: Call must come from admin.");
        ITimelock(TIMELOCK).queueTransaction(ATTACKER, 0, "", "", block.timestamp + 2 days);

        vm.expectRevert("Timelock::executeTransaction: Call must come from admin.");
        ITimelock(TIMELOCK).executeTransaction(ATTACKER, 0, "", "", block.timestamp);

        // public treasury function still routes through the paused Pool
        vm.expectRevert(bytes("64"));
        ITreasury(TREASURY).withdrawAllReserves();

        vm.expectRevert("Ownable: caller is not the owner");
        ITreasury(TREASURY).transferToMultisig(USDC, 1);
        vm.stopPrank();
    }

    /* 7. Collateral manager direct call + debt token transfer + MODE feed */
    function test_07_misc_paths_blocked() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IManager(MANAGER).liquidationCall(USDC, WETH, USDC_WHALE, 1, false);

        vm.expectRevert("TRANSFER_NOT_SUPPORTED");
        IVDebt(V_USDC).transfer(ATTACKER, 1);
        vm.stopPrank();

        vm.expectRevert("dAPI name not set");
        IOracle(ORACLE).getAssetPrice(MODE);
    }

    /* 8. Latent risk: the oracle feeds used by the Pool are stale */
    function test_08_oracle_staleness_latent() public {
        address src = IOracle(ORACLE).getSourceOfAsset(WETH);
        assertEq(src, WETH_FEED, "weth feed");
        uint256 ts = IFeed(src).latestTimestamp();
        assertLt(ts, block.timestamp, "feed timestamp in past");
        uint256 ageDays = (block.timestamp - ts) / 1 days;
        assertGt(ageDays, 30, "WETH feed is >30d stale");
        emit log_named_uint("WETH feed age (days)", ageDays);
        emit log_named_int("WETH feed answer (1e8)", IFeed(src).latestAnswer());
    }

    /* 9. Frozen available liquidity (aToken-held underlying) */
    function test_09_available_liquidity_snapshot() public {
        uint256 ez = IERC20(0x2416092f143378750bb29b79eD961ab195CcEea5).balanceOf(A_EZETH);
        uint256 uni = IERC20(0x6B2a01A5f79dEb4c2f3c0eDa7b01DF456FbD726a).balanceOf(A_UNIBTC);
        uint256 mbtc = IERC20(MBTC).balanceOf(A_MBTC);
        uint256 wethBal = IERC20(WETH).balanceOf(A_WETH);
        emit log_named_uint("ezETH available (wei)", ez);
        emit log_named_uint("uniBTC available", uni);
        emit log_named_uint("M-BTC available", mbtc);
        emit log_named_uint("WETH available", wethBal);
        assertGt(ez, 38e18, "~38.79 ezETH available");
        assertGt(uni, 9.9e6, "~0.0992 uniBTC available");
    }

    /* 10. M-BTC market is insolvent: issuer burned the aToken's backing */
    function test_10_mbtc_market_insolvent() public {
        uint256 bal = IERC20(MBTC).balanceOf(A_MBTC);
        uint256 supply = IAToken(A_MBTC).totalSupply();
        uint256 tokenSupply = IERC20(MBTC).totalSupply();
        emit log_named_uint("aMBTC underlying", bal);
        emit log_named_uint("aMBTC totalSupply", supply);
        emit log_named_uint("M-BTC token totalSupply", tokenSupply);
        // aToken claims >30 M-BTC but holds ~0.002, and the token itself only has ~0.55 supply
        assertLt(bal, supply / 1000, "backing is <0.1% of claims");
        assertLt(tokenSupply, supply / 50, "token supply << aToken claims");
    }
}
