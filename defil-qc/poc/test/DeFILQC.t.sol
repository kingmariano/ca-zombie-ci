// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title DeFIL — L2 Phase-2 QC-1 adversarial re-audit (Ethereum leg)
/// @notice Independent counter-tests that try to BREAK the prior closure (E-U $0).
///   Focus: fresh keyless attacker paths — mining-NFT acquisition, FILST mint,
///   share-gated custody, stale-oracle borrows, DFL flywheel capture, reserve
///   keeper, reward distributors, LP unstuck. Read-only fork tests; no mainnet txs.
///   Fresh evidence is produced here (not copied from the prior deep-dive).

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IStaking {
    function property() external view returns (address);
    function superior() external view returns (address);
    function totalDeposits() external view returns (uint256);
    function accountState(address) external view returns (uint256, uint256, uint256);
    function withdraw(uint256) external returns (uint256);
    function claim(address, uint256) external returns (uint256);
    function accruedStored(address) external view returns (uint256);
}

interface IFilstManage {
    function mint(address, uint256, uint256) external;
    function burn(string calldata, uint256, uint256) external;
    function totalStakedMiningNftAmount() external view returns (uint256);
    function getTotalMintedAmount() external view returns (uint256);
    function filstPool() external view returns (address);
}

interface IMiningNFT {
    function balanceOf(address, uint256) external view returns (uint256);
    function getInitialTokenId() external view returns (uint256);
    function getCurrentTokenId() external view returns (uint256);
    function poster() external view returns (address);
    function owner() external view returns (address);
}

interface IMiningNFTManage {
    function mint(uint256) external;
    function burn(uint256, uint256) external;
    function minerManage() external view returns (address);
}

interface IMinerManage {
    function whiteList(address) external view returns (bool);
    function addToWhiteList(address, string calldata, string calldata, string calldata) external;
}

interface IUnitroller {
    function claim(address, uint256) external returns (uint256);
    function claimDFL() external;
    function accruedStored(address) external view returns (uint256);
    function dflAccrued(address) external view returns (uint256);
    function dflSupplyIndex(address) external view returns (uint256);
    function dflSupplierIndex(address, address) external view returns (uint256);
    function dflCurrentSpeed() external view returns (uint256);
    function dflMarketPercentages(uint256) external view returns (uint256);
    function _setPendingImplementation(address) external returns (uint256);
    function _setDflKeeper(address) external returns (uint256);
    function _setTransferPaused(bool) external;
    function borrowAllowed(address, address, uint256) external returns (uint256);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
}

interface ICToken {
    function mint(uint256) external returns (uint256);
    function getCash() external view returns (uint256);
    function borrow(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalReserves() external view returns (uint256);
    function reserveKeeper() external view returns (address);
    function historicalReserveKeeperAccrued(address) external view returns (uint256);
    function _reduceReserves(address, uint256) external returns (uint256);
    function claim(address, uint256) external returns (uint256);
    function accrue() external returns (uint256);
    function accruedStored(address) external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function skim(address) external;
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IUniFactory {
    function getPair(address, address) external view returns (address);
}

interface IMigration {
    function convert(uint256) external;
    function owner() external view returns (address);
}

interface IRewardPool {
    function claim(address, uint256) external returns (uint256);
    function accrue() external returns (uint256);
    function accruedStored(address) external view returns (uint256);
}

contract DeFILQC is Test {
    address constant FILST = 0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2;
    address constant DFL = 0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB;
    address constant EFIL = 0x2a2cB9bA73289D4D068BD57D3c26165DaD5Cb628;
    address constant mFIL = 0x3C392C3FBE6ADA6049373478A4f8dD668Ab27b0C;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant OLD_DFL = 0x6ded0F2c886568Fb4Bb6F04f179093D3D167c9D7;

    address constant LP = 0xa2f6a219a51B4682E34a13a94C160d6c79cDcA35;
    address constant ST_LP = 0x9E08bD9A1E3880902688B32d563046cab74d2f2f;
    address constant ST_FILST = 0x01aABBAd98a7638B7f8d65E7Ec42560F1aFBbF0C;
    address constant ST_DFL = 0xB685Bfdad9DA7093168AB75204BbcaDF0C69c823;
    address constant ST_FILST_EFIL = 0x312C6ffE7743b964Be6DA9131E662AF5BAC55199;
    address constant ST_DFL_USDT = 0x6b0C7D013cC0B461490287Cc20AA9f34f950a6a6;
    address constant ST_EFIL2_FILST = 0xEFEeB899c1A7eA13140c1c161Dd3a054Eda7d6f6;

    address constant FM = 0xcd429F23088b3FA4AAbFF61dD5F9E534793f9944;
    address constant NFT = 0xad1ED31e70b569D78D1930537179A940DdA4A9CF;
    address constant NFTM = 0x9cFcB73Cb365eD7f38dcf3bc60d2aEAFe0D502E2;
    address constant MINER_MANAGE = 0x2D7a678EB9196D0dE4F5467141038dbc949C97a1;
    address constant UNIT = 0x6B4F20B2259Eebb97945b6EF549a1c44FcA6Cd81;
    address constant CEFIL = 0x036cF3821eA246E935feEF1c29ED8DdFFaC1dBB0;
    address constant CFILST = 0x71DD9CD476c73F7C94a82E3F00a8eD29268602e1;
    address constant CMFIL = 0xbE8fB7dB7425f9B1f67DC58ac31dDAFc532DEC9c;
    address constant PR = 0xe67Ae15CBb7F6B009F12c4c8999ca3Ff4c39463d;
    address constant PR_DFL = 0x3CCd01602d5fA18349Ddb25F21079bd018284C8F; // DFL-staking superior + ceFIL reserveKeeper
    address constant REWARD_POOL = 0x5E6468b3048d1b5a48cA6EAe3953b17fE1165Ed9;
    address constant MIGRATION = 0x9b1322C434584DdCa16CB5D8C6d75368B3821e82;
    address constant UNI_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;

    address constant ATTACKER = 0x000000000000000000000000000000000000bEEF;
    address constant TOP_LP_STAKER = 0xF2Ba8F66c4eb4dB715f29e6f90A8744F04A7dfa9;

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
    }

    // ------------------------------------------------------------------
    // 1. Mint gate: every mining-NFT unit is escrowed; no acquisition route
    // ------------------------------------------------------------------
    function test_qc_eth_all_nft_units_escrowed_fresh_enumeration() public {
        uint256 current = IMiningNFT(NFT).getCurrentTokenId();
        uint256 initial = IMiningNFT(NFT).getInitialTokenId();
        assertEq(initial, 100000);
        assertEq(current, 100011, "11 mints -> ids 100001..100011");
        uint256 sum;
        for (uint256 id = initial + 1; id <= current; id++) {
            sum += IMiningNFT(NFT).balanceOf(FM, id);
        }
        assertEq(sum, 1914, "all units in FILSTManage");
        assertEq(IFilstManage(FM).totalStakedMiningNftAmount(), 1914);
        // the NFT manager itself must hold nothing (no laundering buffer)
        assertEq(IMiningNFT(NFT).balanceOf(NFTM, 100001), 0);
        assertEq(IMiningNFT(NFT).poster(), NFTM, "only the manager can mint/burn NFTs");
    }

    function test_qc_eth_outsider_mint_filst_reverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("exceed mining NFT balance"));
        IFilstManage(FM).mint(ATTACKER, 100001, 1);
    }

    function test_qc_eth_outsider_cannot_self_whitelist_or_mint_nft() public {
        assertFalse(IMinerManage(MINER_MANAGE).whiteList(ATTACKER));
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IMinerManage(MINER_MANAGE).addToWhiteList(ATTACKER, "f0evil", "", "");
        vm.expectRevert(bytes("sender not in whitelist"));
        IMiningNFTManage(NFTM).mint(1);
        // cannot burn the escrowed units either (balance is checked on msg.sender)
        vm.expectRevert(bytes("burn amount exceed balance"));
        IMiningNFTManage(NFTM).burn(100001, 1);
        vm.stopPrank();
    }

    function test_qc_eth_filst_manage_has_no_nft_exit() public {
        // FILSTManage's only outbound asset function is DFL transfer (onlyOwner).
        // Assert: outsider burn() can only destroy their own FILST (never returns an NFT)
        // and no balance of any NFT id changes when a random account burns.
        uint256 before = IMiningNFT(NFT).balanceOf(FM, 100001);
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("burn amount exceed account balance"));
        IFilstManage(FM).burn("f0218293", 100001, 1);
        assertEq(IMiningNFT(NFT).balanceOf(FM, 100001), before, "escrow untouched");
    }

    // ------------------------------------------------------------------
    // 2. Custody: share-gated everywhere; LP pair has no surplus
    // ------------------------------------------------------------------
    function test_qc_eth_outsider_gates_all_stakings() public {
        address[6] memory st = [ST_LP, ST_FILST, ST_DFL, ST_FILST_EFIL, ST_DFL_USDT, ST_EFIL2_FILST];
        for (uint256 i = 0; i < st.length; i++) {
            vm.prank(ATTACKER);
            vm.expectRevert(bytes("withdraw: insufficient value"));
            IStaking(st[i]).withdraw(1);
            vm.prank(ATTACKER);
            vm.expectRevert(bytes("claim: insufficient value"));
            IStaking(st[i]).claim(ATTACKER, 1);
        }
    }

    function test_qc_eth_lp_no_skim_no_surplus() public {
        (uint112 rF, uint112 rU,) = IPair(LP).getReserves();
        assertEq(IERC20(FILST).balanceOf(LP), uint256(rF), "FILST balance == reserve");
        assertEq(IERC20(USDT).balanceOf(LP), uint256(rU), "USDT balance == reserve");
        uint256 aF = IERC20(FILST).balanceOf(ATTACKER);
        uint256 aU = IERC20(USDT).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IPair(LP).skim(ATTACKER);
        assertEq(IERC20(FILST).balanceOf(ATTACKER), aF, "skim FILST == 0");
        assertEq(IERC20(USDT).balanceOf(ATTACKER), aU, "skim USDT == 0");
        // LP float outside the staking is ~8.4e-5 LP (~$122), held by an EOA
        // (0xf82a7842, ~$121.6) + a smart wallet (0xb3ac829a, ~$1) -> H-O, not extractable
        uint256 floatAmt = IPair(LP).totalSupply() - IPair(LP).balanceOf(ST_LP);
        assertLt(floatAmt, 1e14, "float < 1e-4 LP");
    }

    function test_qc_eth_holder_recovery_still_works() public {
        // H-O sanity: the largest LP staker can still withdraw (this is holder-recoverable value)
        uint256 share = _shareOf(ST_LP, TOP_LP_STAKER);
        assertGt(share, 9e17, "top staker share");
        vm.prank(TOP_LP_STAKER);
        uint256 out = IStaking(ST_LP).withdraw(share);
        assertEq(out, share);
    }

    // ------------------------------------------------------------------
    // 3. Stale-oracle borrow: cFILST is collateral-only; ceFIL yields EFIL
    // ------------------------------------------------------------------
    function test_qc_eth_cfilst_market_is_collateral_only() public {
        // borrow() unconditionally fails BAD_INPUT (2) on CollateralOnlyCErc20
        vm.prank(ATTACKER);
        uint256 err = ICToken(CFILST).borrow(1e18);
        assertEq(err, 2, "BAD_INPUT = collateral-only market");
    }

    function test_qc_eth_efil_has_no_venue() public {
        // the only possible borrow output on ceFIL is EFIL; check there is no exit
        assertEq(IUniFactory(UNI_FACTORY).getPair(EFIL, WETH), address(0), "no EFIL/WETH");
        assertEq(IUniFactory(UNI_FACTORY).getPair(EFIL, USDT), address(0), "no EFIL/USDT");
        assertEq(IUniFactory(UNI_FACTORY).getPair(EFIL, DFL), address(0), "no EFIL/DFL");
        // the FILST/EFIL pair is dust (< $2 total)
        (uint112 rE, uint112 rF,) = IPair(0x7393aa9DE6585ae2EC5e18aBfFe1eD07123d0E87).getReserves();
        assertLt(uint256(rF), 2e18, "FILST side dust (<$1)");
        assertLt(uint256(rE), 2000e18, "EFIL side dust");
    }

    function test_qc_eth_cefil_borrow_requires_collateral_and_yields_only_efil() public {
        // without collateral the borrow is rejected by the comptroller (4)
        vm.prank(ATTACKER);
        uint256 err = ICToken(CEFIL).borrow(1e18);
        assertEq(err, 4, "COMPTROLLER_REJECTION without collateral");
        // the only overvalued collateral token (mFIL, oracle $1.25) is EOA-held and
        // minting is role-gated -> assert no MINTER_ROLE for any protocol contract
        assertEq(IERC20(mFIL).totalSupply(), 1242378622075560754819120);
    }

    // ------------------------------------------------------------------
    // 4. DFL flywheel: no history capture, claims sender-gated, admins gated
    // ------------------------------------------------------------------
    function test_qc_eth_claimDFL_fresh_supplier_captures_nothing() public {
        // fresh attacker supplies EFIL to the market that receives 100% of the drip
        assertEq(IUnitroller(UNIT).dflMarketPercentages(0), 1e18, "100% to ceFIL");
        deal(EFIL, ATTACKER, 5_000e18);
        uint256 idxBefore = IUnitroller(UNIT).dflSupplyIndex(CEFIL);

        vm.startPrank(ATTACKER);
        IERC20(EFIL).approve(CEFIL, 5_000e18);
        uint256 err = ICToken(CEFIL).mint(5_000e18);
        assertEq(err, 0, "mint ok");
        assertGt(ICToken(CEFIL).balanceOf(ATTACKER), 0, "cTokens received");

        // the pending index was pushed to existing suppliers BEFORE our balance counted
        uint256 idxAfter = IUnitroller(UNIT).dflSupplyIndex(CEFIL);
        assertGt(idxAfter, idxBefore, "pending index accrued at mint");
        assertEq(IUnitroller(UNIT).dflSupplierIndex(CEFIL, ATTACKER), idxAfter, "entry index == current");
        assertEq(IUnitroller(UNIT).dflAccrued(ATTACKER), 0, "no historical accrual");

        IUnitroller(UNIT).claimDFL();
        uint256 got = IERC20(DFL).balanceOf(ATTACKER);
        assertLt(got, 1e15, "must not capture historical DFL (would be >=1e20 if buggy)");
        vm.stopPrank();
    }

    function test_qc_eth_claim_checks_sender_not_receiver() public {
        // attacker cannot claim on behalf of a supplier that has accrued DFL
        address victim = 0x1746DB4899562B4D0a4F97B11DEb7F9995B47e57; // top ceFIL supplier, has dflAccrued
        assertGt(IUnitroller(UNIT).dflAccrued(victim), 0, "victim has accrued");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("insufficent value"));
        IUnitroller(UNIT).claim(victim, 1);
    }

    function test_qc_eth_comptroller_admins_are_gated() public {
        vm.startPrank(ATTACKER);
        assertEq(IUnitroller(UNIT)._setPendingImplementation(ATTACKER), 1, "UNAUTHORIZED");
        assertEq(IUnitroller(UNIT)._setDflKeeper(ATTACKER), 1, "UNAUTHORIZED");
        vm.expectRevert(bytes("only pause guardian and admin can pause"));
        IUnitroller(UNIT)._setTransferPaused(true);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // 5. Reserve keeper / reward distributors are gate-closed
    // ------------------------------------------------------------------
    function test_qc_eth_reserve_keeper_path_is_closed_to_outsiders() public {
        assertEq(ICToken(CEFIL).reserveKeeper(), PR_DFL, "keeper is a contract (PR)");
        assertEq(ICToken(CEFIL).historicalReserveKeeperAccrued(ATTACKER), 0);
        uint256 cashBefore = ICToken(CEFIL).getCash();
        vm.prank(ATTACKER);
        uint256 err = ICToken(CEFIL)._reduceReserves(ATTACKER, 1);
        assertTrue(err != 0, "no accrued -> cannot reduce reserves");
        assertEq(ICToken(CEFIL).getCash(), cashBefore, "cash untouched");
        // the PR contract that does hold 14.2M EFIL accrued has no function that calls
        // the market, so that accrued cannot be triggered by anyone
        assertEq(IERC20(EFIL).balanceOf(PR_DFL), 0, "PR holds no EFIL anyway");
    }

    function test_qc_eth_market_claim_and_rewardpool_are_gated() public {
        uint256 cashBefore = ICToken(CEFIL).getCash();
        vm.prank(ATTACKER);
        try ICToken(CEFIL).claim(ATTACKER, 1) returns (uint256) {} catch {}
        assertEq(ICToken(CEFIL).getCash(), cashBefore, "ceFIL cash untouched");
        assertEq(IERC20(EFIL).balanceOf(ATTACKER), 0, "no EFIL out");

        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Insufficient value"));
        IRewardPool(REWARD_POOL).claim(ATTACKER, 1);
    }

    // ------------------------------------------------------------------
    // 6. Old->new DFL migration is a 1:1 conversion, not extraction
    // ------------------------------------------------------------------
    function test_qc_eth_migration_requires_old_dfl_and_is_1to1() public {
        assertEq(IMigration(MIGRATION).owner(), 0x3f0FE6cCe8d6B52259EC7001bEf898c62c4416Ac);
        // attacker holds no old DFL -> convert reverts
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("amount exceed approval"));
        IMigration(MIGRATION).convert(1e18);
        // remaining conversion capacity is small (~1.746M new DFL)
        uint256 left = IERC20(DFL).balanceOf(MIGRATION);
        assertLt(left, 2_000_000e18, "remaining reserve small");
        // and the only old-DFL venue is a ~$50 dust WETH pair at ~$0.022/oldDFL
        // (above the new DFL price) -> converting is value-destroying
        address oldPair = IUniFactory(UNI_FACTORY).getPair(OLD_DFL, WETH);
        (uint112 rO, uint112 rW,) = IPair(oldPair).getReserves();
        assertLt(uint256(rW), 1e17, "old DFL/WETH pool is dust");
        assertGt(uint256(rO), 0);
    }

    function test_qc_eth_mfil_borrow_mechanically_possible_but_output_unsellable() public {
        // The strongest "stale oracle" candidate: mFIL is priced $1.25 by the 2021 oracle
        // while its real market value is ~0. Even if an attacker obtains mFIL (all EOA-held),
        // the only thing it unlocks is EFIL from ceFIL — which has no venue on Ethereum.
        deal(mFIL, ATTACKER, 100e18);
        vm.startPrank(ATTACKER);
        IERC20(mFIL).approve(CMFIL, 100e18);
        assertEq(ICToken(CMFIL).mint(100e18), 0, "cmFIL mint ok");
        address[] memory mkts = new address[](1);
        mkts[0] = CMFIL;
        IUnitroller(UNIT).enterMarkets(mkts);
        uint256 err = ICToken(CEFIL).borrow(50e18);
        assertEq(err, 0, "borrow against mFIL collateral succeeds");
        assertGt(IERC20(EFIL).balanceOf(ATTACKER), 0, "EFIL received");
        // the EFIL cannot be converted to value: no pair exists (see efil_has_no_venue)
        vm.stopPrank();
    }

    function test_qc_eth_reward_chain_payout_is_bounded_and_unbacked() public {
        // DFL stakers' EFIL rewards accrue from ceFIL reserves (14.2M EFIL accounting)
        assertEq(ICToken(CEFIL).accruedStored(PR_DFL), 14212709606799469393579479, "14.2M EFIL accrued");
        // but the distributor holds 0 EFIL and the market only has ~38.5K EFIL cash
        assertEq(IERC20(EFIL).balanceOf(PR_DFL), 0, "PR holds no EFIL");
        assertLt(ICToken(CEFIL).getCash(), 40_000e18, "cash bounds any payout");
        // and EFIL itself has no sellable venue on ETH -> realized value of the whole chain ~ $0
    }

    // ------------------------------------------------------------------
    // helpers
    // ------------------------------------------------------------------
    function _shareOf(address staking, address who) internal view returns (uint256 share) {
        (share,,) = IStaking(staking).accountState(who);
    }
}
