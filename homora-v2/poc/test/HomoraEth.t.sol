// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// Homora V2 — Ethereum current bank (0xba5eBAf3…) sanity checks.
/// The ETH bank uses an AggregatorOracle over Band + Chainlink feeds (no spot
/// Uniswap prices), so the AVAX-style inflation bug is NOT present here.

interface IBank {
    function nextPositionId() external view returns (uint256);
    function oracle() external view returns (address);
    function whitelistedSpells(address s) external view returns (bool);
    function whitelistedTokens(address t) external view returns (bool);
    function getCollateralETHValue(uint256 id) external view returns (uint256);
    function getBorrowETHValue(uint256 id) external view returns (uint256);
    function bankStatus() external view returns (uint256);
    function allowContractCalls() external view returns (bool);
}

interface IOracle {
    function source() external view returns (address);
}

interface IAggregator {
    function getETHPx(address token) external view returns (uint256);
    function primarySourceCount(address token) external view returns (uint256);
}

contract HomoraEthTest is Test {
    address constant BANK = 0xba5eBAf3fc1Fcca67147050Bf80462393814E54B;
    address constant ORACLE = 0xD0b461581774Eb196281DD36E22dF586851cd568;
    address constant CORE = 0x6be987c6d72e25F02f6f061F94417d83a6Aa13fC;
    address constant AGG = 0x636478DcecA0308ec6b39e3ab1e6b9EBF00Cd01c;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant CURVE_SPELL = 0x8b947D8448CFFb89EF07A6922b74fBAbac219795;
    uint256 constant TWO112 = 5192296858534827628530496329220096;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
    }

    function test_eth_oracle_healthy_and_no_contract_calls() public {
        assertEq(IOracle(ORACLE).source(), CORE, "proxy oracle source");
        // WETH is the numeraire: px ~= 2^112 (1 ETH per ETH), from Band+Chainlink
        uint256 pxWeth = IAggregator(AGG).getETHPx(WETH);
        emit log_named_uint("WETH px", pxWeth);
        assertGt(pxWeth, TWO112 * 9 / 10, "WETH px sane lower");
        assertLt(pxWeth, TWO112 * 11 / 10, "WETH px sane upper");
        assertEq(IAggregator(AGG).primarySourceCount(WETH), 2, "two independent sources");
        uint256 pxDai = IAggregator(AGG).getETHPx(DAI);
        emit log_named_uint("DAI px", pxDai);
        assertGt(pxDai, 1e29, "DAI px sane lower");
        assertLt(pxDai, 1e32, "DAI px sane upper");

        assertTrue(IBank(BANK).whitelistedTokens(WETH), "WETH whitelisted");
        assertTrue(IBank(BANK).whitelistedSpells(CURVE_SPELL), "curve spell whitelisted");
        assertEq(IBank(BANK).bankStatus(), 3, "borrow+repay enabled");
        assertEq(IBank(BANK).allowContractCalls(), false, "contracts blocked");
        emit log_named_uint("nextPositionId", IBank(BANK).nextPositionId());
    }

    /// Sample positions with debt on the current bank: none should be
    /// liquidatable at the healthy Band/Chainlink prices.
    function test_eth_sample_not_liquidatable() public {
        uint256[8] memory ids = [uint256(1), 2, 3, 4, 5, 6, 7, 8];
        for (uint256 i = 0; i < ids.length; i++) {
            try IBank(BANK).getCollateralETHValue(ids[i]) returns (uint256 cv) {
                try IBank(BANK).getBorrowETHValue(ids[i]) returns (uint256 bv) {
                    emit log_named_uint(string.concat("pos", vm.toString(ids[i]), " coll"), cv);
                    emit log_named_uint(string.concat("pos", vm.toString(ids[i]), " borrow"), bv);
                    if (bv > 0) assertGe(cv, bv, "sample position liquidatable");
                } catch {}
            } catch {}
        }
    }
}
