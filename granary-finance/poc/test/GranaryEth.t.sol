// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20, IAToken, ILendingPool, IAaveOracle} from "../src/Interfaces.sol";

/// @title Granary Finance (Aave V2 fork) — live extraction gate tests, Ethereum mainnet.
/// @notice Read-only fork tests. No mainnet transactions. Run on CI forks.
/// Findings tested:
///  1. ETH pool is live (not paused), the largest underwater position is liquidatable per the pool (HF<1).
///  2. Liquidating it to underlying reverts: the WBTC aToken holds 0 WBTC (error '45' = not enough liquidity).
///  3. Liquidating with receiveAToken=true succeeds but yields aWBTC claims worth ~0 (no cash, no debt backing);
///     redeeming them reverts, borrowing against them reverts. => no extraction.
contract GranaryEthTest is Test {
    ILendingPool constant pool = ILendingPool(0xB702cE183b4E1Faa574834715E5D4a6378D0eEd3);
    IAaveOracle constant oracle = IAaveOracle(0x9546F673eF71Ff666ae66d01Fd6E7C6Dae5a9995);
    IERC20 constant WBTC = IERC20(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    IERC20 constant WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20 constant USDC = IERC20(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    IAToken constant aWBTC = IAToken(0x272CfCceFbEFBe1518cd87002A8F9dfd8845A6c4);
    IAToken constant aWETH = IAToken(0x58254000eE8127288387b04ce70292B56098D55C);
    // largest underwater borrower on Ethereum (HF ~0.56 at audit time): WBTC collateral vs USDC/WETH/DAI/USDT debt
    address constant WHALE = 0x50E4832C4fcb244f195e9376523add869A3505A7;

    /// @dev decode require(false, "msg") revert reasons
    function _reason(bytes memory r) internal pure returns (string memory) {
        if (r.length < 4) return "";
        bytes4 sel;
        assembly { sel := mload(add(r, 0x20)) }
        if (sel != 0x08c379a0) return "";
        bytes memory payload = new bytes(r.length - 4);
        for (uint256 i = 0; i < payload.length; i++) payload[i] = r[i + 4];
        return abi.decode(payload, (string));
    }

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
    }

    function test_eth_pool_live_and_whale_liquidatable() public {
        assertFalse(pool.paused(), "pool paused");
        // oracle prices are live (fresh chainlink USD feeds)
        assertGt(oracle.getAssetPrice(address(WBTC)), 0);
        (, , , , , uint256 hf) = pool.getUserAccountData(WHALE);
        emit log_named_uint("whale HF (wad)", hf);
        assertLt(hf, 1e18, "whale not liquidatable");
        assertGt(hf, 0, "whale HF zero");
    }

    function test_eth_liquidation_to_underlying_reverts_no_cash() public {
        // The WBTC reserve has no cash at all: aToken holds 0 WBTC while holding 0.68 WBTC of claims.
        assertEq(WBTC.balanceOf(address(aWBTC)), 0, "aWBTC unexpectedly funded");

        vm.deal(address(this), 100 ether);
        WETH.deposit{value: 10 ether}();
        WETH.approve(address(pool), type(uint256).max);

        // 1 WETH of debt -> would seize ~0.0317 WBTC at 10500 bonus; blocked by zero WBTC liquidity.
        try pool.liquidationCall(address(WBTC), address(WETH), WHALE, 1 ether, false) {
            fail();
        } catch (bytes memory reason) {
            assertEq(_reason(reason), "45"); // LPCM_NOT_ENOUGH_LIQUIDITY_TO_LIQUIDATE
        }
    }

    function test_eth_liquidation_to_atoken_is_worthless() public {
        vm.deal(address(this), 100 ether);
        WETH.deposit{value: 10 ether}();
        WETH.approve(address(pool), type(uint256).max);

        uint256 before_ = aWBTC.balanceOf(address(this));
        // receiveAToken = true skips the liquidity check and succeeds
        pool.liquidationCall(address(WBTC), address(WETH), WHALE, 1 ether, true);
        uint256 got = aWBTC.balanceOf(address(this)) - before_;
        emit log_named_uint("aWBTC seized", got);
        assertGt(got, 0, "no aWBTC seized");

        // 1) backing per aWBTC ~ 0: (cash + debt)/totalSupply
        uint256 cash = WBTC.balanceOf(address(aWBTC));
        (uint256 cfg, , , , , , , , , address vDebt, , ) = pool.getReserveData(address(WBTC));
        cfg; // silence
        uint256 debt = IERC20(vDebt).totalSupply();
        uint256 supply = aWBTC.totalSupply();
        emit log_named_uint("aWBTC backing numerator (cash+debt)", cash + debt);
        emit log_named_uint("aWBTC totalSupply", supply);
        assertLt((cash + debt) * 1e6, supply, "unexpectedly backed");

        // 2) redeeming the seized aWBTC reverts (no underlying in the pool)
        vm.expectRevert();
        pool.withdraw(address(WBTC), got, address(this));

        // 3) borrowing USDC against the seized aWBTC also reverts (USDC reserve has 0 cash)
        vm.expectRevert();
        pool.borrow(address(USDC), 100e6, 2, 0, address(this));
    }

    function test_eth_all_reserve_cash_is_dust() public view {
        // pool-wide: every reserve's underlying balance held by its aToken is ~0 -> nothing to seize/borrow
        assertLt(WBTC.balanceOf(address(aWBTC)), 1e4); // < 0.0001 WBTC
        assertLt(WETH.balanceOf(address(aWETH)), 1e12); // < 0.000001 WETH
        assertLt(USDC.balanceOf(0x02CD18c03b5b3f250d2B29C87949CDAB4Ee11488), 1e6); // < 1 USDC
    }
}
