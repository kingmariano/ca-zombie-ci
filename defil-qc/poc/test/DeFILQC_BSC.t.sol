// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title DeFIL — L2 Phase-2 QC-1 adversarial re-audit (BSC leg)
/// @notice Fresh counter-tests on the BSC mirror. The BSC "unverified" contracts
///   (FILSTManage / MiningNFT / MiningNFTManage) are bytecode-identical to the
///   verified ETH twins (see ci/run.sh output), so the same gates are expected —
///   these tests assert them empirically against the live BSC fork.
///   Read-only fork tests; no mainnet transactions.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
}

interface IStaking {
    function totalDeposits() external view returns (uint256);
    function accountState(address) external view returns (uint256, uint256, uint256);
    function withdraw(uint256) external returns (uint256);
    function claim(address, uint256) external returns (uint256);
}

interface IFilstManage {
    function mint(address, uint256, uint256) external;
    function totalStakedMiningNftAmount() external view returns (uint256);
    function getTotalMintedAmount() external view returns (uint256);
}

interface IMiningNFT {
    function balanceOf(address, uint256) external view returns (uint256);
    function getCurrentTokenId() external view returns (uint256);
    function getInitialTokenId() external view returns (uint256);
    function poster() external view returns (address);
}

interface IMiningNFTManage {
    function mint(uint256) external;
    function minerManage() external view returns (address);
}

interface IMinerManage {
    function whiteList(address) external view returns (bool);
    function addToWhiteList(address, string calldata, string calldata, string calldata) external;
}

interface IUnitroller {
    function claimDFL() external;
    function dflAccrued(address) external view returns (uint256);
    function dflSupplyIndex(address) external view returns (uint256);
    function dflSupplierIndex(address, address) external view returns (uint256);
    function dflMarketPercentages(uint256) external view returns (uint256);
    function markets(address) external view returns (bool, uint256);
}

interface ICToken {
    function mint(uint256) external returns (uint256);
    function getCash() external view returns (uint256);
    function borrow(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IOracle {
    function getUnderlyingPrice(address) external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function skim(address) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

contract DeFILQC_BSC is Test {
    address constant FILST = 0x899e2a220CBC6eb1Ab154211353EDED74BC1e266;
    address constant EFIL = 0x22B475f3e93390b7E523873ad7073337f4E56C2c;
    address constant mFIL = 0x3C392C3FBE6ADA6049373478A4f8dD668Ab27b0C;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;

    address constant LP = 0xecf6aA34b19e31311eB92768888bdDd25aa72933;
    address constant ST_LP = 0xDE6239B3138910C68F318E799B3D332925e9929f;
    address constant ST_FILST = 0x6c753cA90bad578504314699580c8B01E067A765;
    address constant ST_DFL = 0x272257bB03a2b99978A1E6badEba7cCbA444D285;
    address constant ST_P2 = 0x6B6811a710F07b8aC430F6e172833e87C4Bd8716;

    address constant FM = 0x81dA506420364b3d960229dFc8B9315acEF22dC5;
    address constant NFT = 0xB02F118013150C7F2D4F2030E15F198E1CaA60eb;
    address constant NFTM = 0x3e3945c7e5cb7a6286b48A016d9D52B5826c3F4e;
    address constant MINER_MANAGE = 0xbE8fB7dB7425f9B1f67DC58ac31dDAFc532DEC9c;
    address constant UNIT = 0xa4bBE553CE1E77ebd7415f8ab873DC7E127238fb;
    address constant CEFIL = 0x0c6D278afc34eAC4539ee33192E28275955A1BE6;
    address constant CFILST = 0xC28207990B0EE4847e56f98b0b9F526b302A9273;
    address constant ORACLE = 0x25A520F2Ef5309bD740b65541A8932BF95f6a0a4;

    address constant ATTACKER = 0x000000000000000000000000000000000000bEEF;

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("BSC_FORK_RPC_URL", vm.envOr("BSC_RPC_URL", string("https://bsc-rpc.publicnode.com")))
        );
    }

    function test_qc_bsc_all_nft_units_escrowed() public {
        uint256 current = IMiningNFT(NFT).getCurrentTokenId();
        uint256 initial = IMiningNFT(NFT).getInitialTokenId();
        assertEq(initial, 100000);
        assertEq(current, 100012, "12 mints -> ids 100001..100012");
        uint256 sum;
        for (uint256 id = initial + 1; id <= current; id++) {
            sum += IMiningNFT(NFT).balanceOf(FM, id);
        }
        assertEq(sum, 1857, "all BSC units in FILSTManage");
        assertEq(IFilstManage(FM).totalStakedMiningNftAmount(), 1857);
        assertEq(IMiningNFT(NFT).balanceOf(NFTM, 100001), 0, "manager holds nothing");
        assertEq(IMiningNFT(NFT).poster(), NFTM);
        // supply is exactly 1857 x 1024 -> no net burns, escrow invariant holds
        assertEq(IERC20(FILST).totalSupply(), 1857 * 1024 * 1e18);
        assertEq(IFilstManage(FM).getTotalMintedAmount(), IERC20(FILST).totalSupply());
    }

    function test_qc_bsc_outsider_mint_and_whitelist_gates() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("exceed mining NFT balance"));
        IFilstManage(FM).mint(ATTACKER, 100001, 1);
        assertFalse(IMinerManage(MINER_MANAGE).whiteList(ATTACKER));
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IMinerManage(MINER_MANAGE).addToWhiteList(ATTACKER, "f0evil", "", "");
        vm.expectRevert(bytes("sender not in whitelist"));
        IMiningNFTManage(NFTM).mint(1);
        vm.stopPrank();
    }

    function test_qc_bsc_stakings_share_gated() public {
        address[4] memory st = [ST_LP, ST_FILST, ST_DFL, ST_P2];
        for (uint256 i = 0; i < st.length; i++) {
            vm.prank(ATTACKER);
            vm.expectRevert(bytes("withdraw: insufficient value"));
            IStaking(st[i]).withdraw(1);
            vm.prank(ATTACKER);
            vm.expectRevert(bytes("claim: insufficient value"));
            IStaking(st[i]).claim(ATTACKER, 1);
        }
    }

    function test_qc_bsc_lp_no_skim() public {
        (uint112 rU, uint112 rF,) = IPair(LP).getReserves(); // token0=USDT, token1=FILST
        assertEq(IERC20(FILST).balanceOf(LP), uint256(rF));
        assertEq(IERC20(USDT).balanceOf(LP), uint256(rU));
        uint256 aF = IERC20(FILST).balanceOf(ATTACKER);
        uint256 aU = IERC20(USDT).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IPair(LP).skim(ATTACKER);
        assertEq(IERC20(FILST).balanceOf(ATTACKER), aF, "skim FILST == 0");
        assertEq(IERC20(USDT).balanceOf(ATTACKER), aU, "skim USDT == 0");
        // 99.99%+ of LP is staked; float is ~25 LP (~$19)
        uint256 float = IPair(LP).totalSupply() - IPair(LP).balanceOf(ST_LP);
        assertLt(float, 30e18, "float small");
    }

    function test_qc_bsc_cfilst_collateral_only() public {
        vm.prank(ATTACKER);
        uint256 err = ICToken(CFILST).borrow(1e18);
        assertEq(err, 2, "BAD_INPUT = collateral-only market");
    }

    function test_qc_bsc_no_profitable_collateral_for_cefil_borrow() public {
        // without collateral the borrow is rejected by the comptroller (4)
        vm.prank(ATTACKER);
        uint256 err = ICToken(CEFIL).borrow(1e18);
        assertEq(err, 4, "COMPTROLLER_REJECTION without collateral");
        // the overvalued-collateral route needs mFIL, but BSC mFIL has zero supply
        assertEq(IERC20(mFIL).totalSupply(), 0, "no BSC mFIL exists");
        // the only usable collateral (FILST) is oracle-undervalued ~19x vs its pool price
        uint256 px = IOracle(ORACLE).getUnderlyingPrice(CFILST); // 7.08e15 (1e18-scaled)
        (uint112 rU, uint112 rF,) = IPair(LP).getReserves(); // token0=USDT, token1=FILST
        uint256 marketPrice = uint256(rU) * 1e18 / uint256(rF); // ~0.1339e18
        assertGt(marketPrice, px * 15, "FILST oracle undervalues collateral >15x");
        // ceFIL (the sellable-EFIL source) has collateral factor 0 anyway
        (, uint256 cfCe) = IUnitroller(UNIT).markets(CEFIL);
        assertEq(cfCe, 0, "ceFIL CF == 0");
    }

    function test_qc_bsc_claimDFL_fresh_supplier_captures_nothing() public {
        assertEq(IUnitroller(UNIT).dflMarketPercentages(0), 1e18, "100% to ceFIL");
        deal(EFIL, ATTACKER, 5_000e18);
        uint256 idxBefore = IUnitroller(UNIT).dflSupplyIndex(CEFIL);

        vm.startPrank(ATTACKER);
        IERC20(EFIL).approve(CEFIL, 5_000e18);
        uint256 err = ICToken(CEFIL).mint(5_000e18);
        assertEq(err, 0, "mint ok");
        assertGt(ICToken(CEFIL).balanceOf(ATTACKER), 0, "cTokens received");

        uint256 idxAfter = IUnitroller(UNIT).dflSupplyIndex(CEFIL);
        assertGt(idxAfter, idxBefore, "pending index accrued at mint");
        assertEq(IUnitroller(UNIT).dflSupplierIndex(CEFIL, ATTACKER), idxAfter, "entry index == current");
        assertEq(IUnitroller(UNIT).dflAccrued(ATTACKER), 0, "no historical accrual");

        IUnitroller(UNIT).claimDFL();
        uint256 got = IERC20(DFL_ADDR()).balanceOf(ATTACKER);
        assertLt(got, 1e15, "must not capture historical DFL");
        vm.stopPrank();
    }

    function DFL_ADDR() internal pure returns (address) {
        return 0x6ded0F2c886568Fb4Bb6F04f179093D3D167c9D7;
    }
}
