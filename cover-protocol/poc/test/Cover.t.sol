// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
    function symbol() external view returns (string memory);
}

interface ICover {
    function mint(uint256, address) external;
    function redeemClaim() external;
    function redeemNoclaim() external;
    function redeemCollateral(uint256) external;
    function claimNonce() external view returns (uint256);
    function collateral() external view returns (address);
    function claimCovToken() external view returns (address);
    function noclaimCovToken() external view returns (address);
    function expirationTimestamp() external view returns (uint48);
    function owner() external view returns (address);
}

interface IProtocol {
    function addCover(address, uint48, uint256) external returns (bool);
    function enactClaim(uint16, uint16, uint48, uint256) external returns (bool);
    function claimNonce() external view returns (uint256);
    function claimDetails(uint256) external view returns (uint16, uint16, uint48, uint48);
    function noclaimRedeemDelay() external view returns (uint256);
    function getProtocolDetails()
        external
        view
        returns (bytes32, bool, uint256, uint256, uint256, address[] memory, uint48[] memory, address[] memory, address[] memory);
}

interface IProtocolFactory {
    function getAllProtocolAddresses() external view returns (address[] memory);
    function owner() external view returns (address);
    function governance() external view returns (address);
    function claimManager() external view returns (address);
    function treasury() external view returns (address);
    function redeemFeeNumerator() external view returns (uint16);
    function redeemFeeDenominator() external view returns (uint16);
}

interface IClaimManagement {
    function decideClaim(address, uint256, uint256, bool, uint16, uint16) external;
    function validateClaim(address, uint256, uint256, bool) external;
    function fileClaim(address, bytes32, uint48) external;
    function getAllClaimsByNonce(address, uint256) external view returns (bytes memory);
    function auditor() external view returns (address);
    function governance() external view returns (address);
    function baseClaimFee() external view returns (uint256);
    function feeCurrency() external view returns (address);
}

interface IBPool {
    function isFinalized() external view returns (bool);
    function isPublicSwap() external view returns (bool);
    function exitPool(uint256, uint256[] calldata) external;
    function swapExactAmountIn(address, uint256, address, uint256, uint256) external returns (uint256, uint256);
    function getBalance(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function getController() external view returns (address);
}

interface IBlacksmith {
    function withdraw(address, uint256) external;
    function emergencyWithdraw(address) external;
    function miners(address, address) external view returns (uint256, uint256, uint256);
    function collectDust(address) external;
    function cover() external view returns (address);
    function weeklyTotal() external view returns (uint256);
    function totalWeight() external view returns (uint256);
}

interface IBonusRewards {
    struct User {
        uint256 amount;
        uint256[] rewardsWriteoffs;
    }
    function withdraw(address, uint256) external;
    function emergencyWithdraw(address[] calldata) external;
    function getUser(address, address) external view returns (User memory, uint256[] memory);
    function collectDust(address, address, uint256) external;
    function paused() external view returns (bool);
}

interface ICoverRouter {
    function removeLiquidity(address, address, uint256) external;
    function rollover(address, uint48) external;
}

interface ICoverFeeReceiver {
    function collect(IERC20, uint256) external;
    function owner() external view returns (address);
}

contract CoverProtocolTest is Test {
    // ---- pinned state ----
    uint256 constant BLOCK = 26_171_719;
    string RPC;

    address constant FACTORY = 0xedfC81Bf63527337cD2193925f9C0cF2D537AccA;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant YDAI = 0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01;
    address constant CM = 0xd33F2e0173Fd0aE2A64B208A7BD16bcdc68bC862;
    address constant ROUTER = 0x5b63C3C6b259dfd3966F32514318d91A92dcf175;
    address constant FEE_RECEIVER = 0xe0632311772d362F49b5118c40d5251C44bC8b2E;
    address constant DEV_SAFE = 0x15957f0CA310d35b2E73fB5070Ce44A5B0141AB1;
    address constant GOV_SAFE = 0xc698645B5C5b662B52a5A5C092804F23e3F5B4C5;
    address constant AUDITOR_SAFE = 0x7ebA9C735F8C1fE0670be69edf61dBFBBB3C76E4;
    address constant BR = 0x8FC8551dd5E2Dc5d2B04f2957E543D7d53a79f1e;
    address constant BS = 0xE0B94a7BB45dD905c79bB1992C9879f40F1CAeD5;
    address constant COVER_OLD = 0x5D8d9F5b96f4438195BE9b99eee6118Ed4304286;

    // RAI
    address constant RAI_PROTOCOL = 0x30f74143721c29950C45D32f31fc1F096721b1A9;
    address constant RAI_COVER = 0x3072Abd64ADb81D963D97B7e4af214854c84FB1C;
    address constant RAI_NOCLAIM = 0xeaFe4d66424d9289Df9434401dc56DAAF9e96af8;
    address constant RAI_CLAIM = 0x5E8B19Aca3AC1690fe6A646d74567219f90E7fA3;
    address constant RAI_POOL = 0x53e6728366d8518E69867ee15fa990708c0d8cD6;
    // YEARN (claim 36/100 accepted)
    address constant YEARN_COVER = 0x7544CF3Fe1D4E9Ab91cF196E98e4FAc1B5d6Bf52;
    address constant YEARN_NOCLAIM = 0x034655E8808f6dD8715CB2D58CfA94a15D6e1835;
    address constant YEARN_CLAIM = 0x95F2b40fD723Da8E2937776920EAB91aBF87aa54;
    address constant YEARN_NOCLAIM_HOLDER = 0x2edfd0C529528B01b40E569dd42Fb033f6B0e79a;
    address constant YEARN_CLAIM_HOLDER = 0xa43c01f5106cE315DB2Fb726028Cc75b0Ad1Ddc7;
    // CREAM pool staked in Blacksmith
    address constant CREAM_POOL = 0xa36c6F854ef17238a6Bdef7eEc3B5aF371006C16;
    // DEFIDOLLAR cover (yDAI collateral) + its pool, whose BPT is held by an EOA
    address constant DEFIDOLLAR_COVER = 0xa68Ea788acA6Ba773c0451770100886F8e32BD13;
    address constant DEFIDOLLAR_NOCLAIM = 0xFc17eAfAcD3f0D3a6794575FDDcb3612918CAc3c;
    address constant DEFIDOLLAR_POOL = 0x2e46D8D54b606eBe1E8F653a265Ef8b1638E64Cb;
    // staker with live records in both BR (970k BPT RAI) and BS (184.4k BPT CREAM)
    address constant STAKER = 0xd628c49563e79faac8a7f73B34E6755E48227d44;
    // EOA holding 100 BPT of the DEFIDOLLAR pool
    address constant BPT_EOA = 0x2f80E5163A7A774038753593010173322eA6f9fe;

    address constant ATTACKER = address(0xDeadBeef);

    IERC20 dai = IERC20(DAI);
    IERC20 ydai = IERC20(YDAI);
    IProtocolFactory factory = IProtocolFactory(FACTORY);
    IClaimManagement cm = IClaimManagement(CM);

    function setUp() public {
        // Prefer archive-capable keyed RPCs (CI injects them); fall back to the probed fork RPC.
        string memory rpc = vm.envOr("NODEREAL_ETH_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("BLOCKPI_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("FORK_RPC_URL", string(""));
        if (bytes(rpc).length == 0) rpc = vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"));
        RPC = rpc;
        vm.createSelectFork(RPC, BLOCK);
    }

    // ---------------------------------------------------------------- state
    function test_live_state() public {
        address[] memory protos = factory.getAllProtocolAddresses();
        assertEq(protos.length, 39, "protocol count");
        uint256 daiSum;
        uint256 ydaiSum;
        uint256 covers;
        for (uint256 i; i < protos.length; i++) {
            (, , , , , , , address[] memory allCovers, ) = IProtocol(protos[i]).getProtocolDetails();
            covers += allCovers.length;
            for (uint256 j; j < allCovers.length; j++) {
                address col = ICover(allCovers[j]).collateral();
                uint256 bal = IERC20(col).balanceOf(allCovers[j]);
                if (col == DAI) daiSum += bal;
                else ydaiSum += bal;
            }
        }
        assertEq(covers, 55, "cover count");
        assertEq(daiSum, 332464224005125394320477, "DAI total");
        assertEq(ydaiSum, 154253000409585771812484, "yDAI total");
        assertEq(factory.owner(), DEV_SAFE, "factory owner");
        assertEq(factory.governance(), GOV_SAFE, "governance");
        assertEq(factory.claimManager(), CM, "claimManager");
        assertEq(cm.auditor(), AUDITOR_SAFE, "auditor");
        assertEq(factory.redeemFeeNumerator(), 10);
        assertEq(factory.redeemFeeDenominator(), 10000);
        assertEq(IBlacksmith(BS).cover(), COVER_OLD, "blacksmith cover token");
        assertEq(IBonusRewards(BR).paused(), false, "BR not paused");
        assertEq(IBlacksmith(BS).weeklyTotal(), 654e18, "COVER/week");
    }

    /// Every cover's collateral exactly equals the redeemable entitlement of the outstanding covTokens.
    function test_accounting_exact_no_excess() public {
        address[] memory protos = factory.getAllProtocolAddresses();
        uint256 totalChecked;
        for (uint256 i; i < protos.length; i++) {
            IProtocol p = IProtocol(protos[i]);
            (, , uint256 protoNonce, , , , , address[] memory allCovers, ) = p.getProtocolDetails();
            for (uint256 j; j < allCovers.length; j++) {
                ICover c = ICover(allCovers[j]);
                uint256 bal = IERC20(c.collateral()).balanceOf(allCovers[j]);
                uint256 clSup = IERC20(c.claimCovToken()).totalSupply();
                uint256 nlSup = IERC20(c.noclaimCovToken()).totalSupply();
                if (bal == 0 && clSup == 0 && nlSup == 0) continue;
                uint256 entitlement = nlSup; // no claim accepted: NOCLAIM redeems 1:1
                uint256 cNonce = c.claimNonce();
                if (protoNonce > cNonce) {
                    (uint16 num, uint16 den, uint48 incident, ) = p.claimDetails(cNonce);
                    if (incident > c.expirationTimestamp()) {
                        entitlement = nlSup;
                    } else {
                        entitlement = (clSup * num) / den + (nlSup * (den - num)) / den;
                    }
                }
                uint256 diff = bal > entitlement ? bal - entitlement : entitlement - bal;
                assertLe(diff, 1e6, "collateral != entitlement");
                totalChecked++;
            }
        }
        assertEq(totalChecked, 54, "covers with live state");
    }

    // ------------------------------------------------------- E-U negative proofs
    function test_outsider_cannot_mint() public {
        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        ICover(RAI_COVER).mint(1e18, ATTACKER);
    }

    function test_outsider_cannot_redeemCollateral_expired() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: cover expired");
        ICover(RAI_COVER).redeemCollateral(1e18);
    }

    function test_outsider_cannot_addCover_expired_ts() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: invalid expiration date");
        IProtocol(RAI_PROTOCOL).addCover(DAI, 1619740800, 1e18);
    }

    function test_outsider_cannot_redeemClaim_no_claim() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: no claim accepted");
        ICover(RAI_COVER).redeemClaim();
    }

    function test_outsider_cannot_redeemNoclaim_without_tokens() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: low covToken balance");
        ICover(RAI_COVER).redeemNoclaim();
    }

    function test_outsider_cannot_decideClaim() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER_CM: !auditor");
        cm.decideClaim(RAI_PROTOCOL, 0, 0, true, 1, 1);
    }

    function test_outsider_cannot_validateClaim() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER_CC: !governance");
        cm.validateClaim(RAI_PROTOCOL, 0, 0, true);
    }

    function test_outsider_cannot_enactClaim() public {
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: caller not claimManager");
        IProtocol(RAI_PROTOCOL).enactClaim(1, 1, uint48(block.timestamp), 0);
    }

    function test_outsider_cannot_upgrade_cover_proxy() public {
        vm.prank(ATTACKER);
        (bool ok, ) = RAI_COVER.call(abi.encodeWithSignature("upgradeTo(address)", ATTACKER));
        assertFalse(ok, "upgradeTo must fail for non-admin");
    }

    function test_cover_proxy_cannot_be_reinitialized() public {
        vm.prank(ATTACKER);
        (bool ok, ) = RAI_COVER.call(
            abi.encodeWithSignature("initialize(address,address,bytes)", address(0xBEEF), ATTACKER, bytes(""))
        );
        assertFalse(ok, "re-init must fail");
    }

    // ------------------------------------------------------------- H-O proofs
    function test_yearly_noclaim_holder_redeems_64pct() public {
        uint256 bal = IERC20(YEARN_NOCLAIM).balanceOf(YEARN_NOCLAIM_HOLDER);
        assertGt(bal, 1000e18);
        uint256 before = dai.balanceOf(YEARN_NOCLAIM_HOLDER);
        uint256 treasuryBefore = dai.balanceOf(factory.treasury());
        vm.prank(YEARN_NOCLAIM_HOLDER);
        ICover(YEARN_COVER).redeemNoclaim();
        uint256 got = dai.balanceOf(YEARN_NOCLAIM_HOLDER) - before;
        // 64% payout, minus 0.1% fee
        assertApproxEqAbs(got, (bal * 64 / 100) * 9990 / 10000, 1e6, "noclaim payout net");
        assertApproxEqAbs(dai.balanceOf(factory.treasury()) - treasuryBefore, (bal * 64 / 100) / 1000, 1e6, "fee");
        assertEq(IERC20(YEARN_NOCLAIM).balanceOf(YEARN_NOCLAIM_HOLDER), 0);
    }

    function test_yearly_claim_holder_redeems_36pct() public {
        uint256 bal = IERC20(YEARN_CLAIM).balanceOf(YEARN_CLAIM_HOLDER);
        assertGt(bal, 1000e18);
        uint256 before = dai.balanceOf(YEARN_CLAIM_HOLDER);
        vm.prank(YEARN_CLAIM_HOLDER);
        ICover(YEARN_COVER).redeemClaim();
        uint256 got = dai.balanceOf(YEARN_CLAIM_HOLDER) - before;
        assertApproxEqAbs(got, (bal * 36 / 100) * 9990 / 10000, 1e6, "claim payout net");
    }

    function test_bpt_holder_exit_and_redeem() public {
        IBPool pool = IBPool(DEFIDOLLAR_POOL);
        assertTrue(pool.isFinalized());
        assertTrue(pool.isPublicSwap());
        uint256 bpt = pool.balanceOf(BPT_EOA);
        assertGt(bpt, 0);
        uint256[] memory minOut = new uint256[](2);
        vm.prank(BPT_EOA);
        pool.exitPool(bpt, minOut);
        uint256 cov = IERC20(DEFIDOLLAR_NOCLAIM).balanceOf(BPT_EOA);
        assertGt(cov, 0);
        uint256 before = ydai.balanceOf(BPT_EOA);
        vm.prank(BPT_EOA);
        ICover(DEFIDOLLAR_COVER).redeemNoclaim();
        uint256 got = ydai.balanceOf(BPT_EOA) - before;
        assertApproxEqAbs(got, cov * 9990 / 10000, 1e6, "redeem ~1:1 yDAI net");
    }

    function test_bonusrewards_staker_can_withdraw() public {
        (IBonusRewards.User memory user, ) = IBonusRewards(BR).getUser(RAI_POOL, STAKER);
        assertApproxEqAbs(user.amount, 970000e18, 1e15, "staker record");
        uint256 before = IERC20(RAI_POOL).balanceOf(STAKER);
        vm.prank(STAKER);
        IBonusRewards(BR).withdraw(RAI_POOL, 1000e18);
        assertEq(IERC20(RAI_POOL).balanceOf(STAKER) - before, 1000e18, "withdrew BPT");
    }

    function test_blacksmith_staker_emergencyWithdraw_works() public {
        (uint256 amt, , ) = IBlacksmith(BS).miners(CREAM_POOL, STAKER);
        assertGt(amt, 100000e18, "staker record");
        // regular withdraw is bricked: COVER minting rights were moved to a new Blacksmith,
        // so claiming rewards reverts; emergencyWithdraw (no rewards) is the live path.
        vm.prank(STAKER);
        vm.expectRevert("$COVER: caller not migrator or Blacksmith");
        IBlacksmith(BS).withdraw(CREAM_POOL, 1000e18);
        uint256 before = IERC20(CREAM_POOL).balanceOf(STAKER);
        vm.prank(STAKER);
        IBlacksmith(BS).emergencyWithdraw(CREAM_POOL);
        assertEq(IERC20(CREAM_POOL).balanceOf(STAKER) - before, amt, "recovered full stake");
    }

    function test_blacksmith_outsider_cannot_withdraw_or_dust() public {
        vm.prank(ATTACKER);
        vm.expectRevert("Blacksmith: insufficient balance");
        IBlacksmith(BS).emergencyWithdraw(CREAM_POOL);
        vm.prank(ATTACKER);
        vm.expectRevert("Blacksmith: lpToken, not allowed");
        IBlacksmith(BS).collectDust(CREAM_POOL);
    }

    /// Orphaned BPT in BonusRewards (contract holds the LP, no live user records): nobody can move it.
    function test_orphaned_bpt_in_bonusrewards_is_stuck() public {
        address P88 = 0x448244AC36D67096e436EE82039b432126F79B7f;
        assertGt(IERC20(P88).balanceOf(BR), 9000e18, "BR holds the BPT");
        (IBonusRewards.User memory u, ) = IBonusRewards(BR).getUser(P88, 0x1C051112075FeAEe33BCDBe0984C2BB0DB53CF47);
        assertEq(u.amount, 0, "depositor record is zero");
        // owner cannot sweep pool LP tokens either
        vm.prank(DEV_SAFE);
        vm.expectRevert("BonusRewards: lpToken, not allowed");
        IBonusRewards(BR).collectDust(P88, P88, 0);
    }

    // --------------------------------------------- market path: buy => loss
    function test_pool_buy_then_redeem_is_a_loss() public {
        address aDAI = 0x028171bCA77440897B824Ca71D1c56caC55b68A3;
        vm.prank(aDAI);
        dai.transfer(ATTACKER, 100e18);
        // buy 100 DAI worth of NOCLAIM from the public RAI pool
        vm.startPrank(ATTACKER);
        dai.approve(RAI_POOL, 100e18);
        IBPool pool = IBPool(RAI_POOL);
        (uint256 out, ) = pool.swapExactAmountIn(DAI, 100e18, RAI_NOCLAIM, 0, type(uint256).max);
        uint256 before = dai.balanceOf(ATTACKER);
        ICover(RAI_COVER).redeemNoclaim();
        uint256 back = dai.balanceOf(ATTACKER) - before;
        vm.stopPrank();
        assertGt(out, 0);
        assertLt(back, 100e18, "buy+redeem must lose money");
    }

    // ------------------------------------------------------- router / rollover
    function test_router_has_no_residuals_and_cannot_sweep() public {
        assertEq(dai.balanceOf(ROUTER), 0, "router DAI");
        assertEq(IERC20(RAI_NOCLAIM).balanceOf(ROUTER), 0, "router noclaim");
        assertEq(IERC20(RAI_POOL).balanceOf(ROUTER), 0, "router BPT");
        vm.prank(ATTACKER);
        vm.expectRevert("CoverRouter: insufficient BPT");
        ICoverRouter(ROUTER).removeLiquidity(RAI_NOCLAIM, DAI, 1e18);
    }

    function test_rollover_is_dead() public {
        vm.prank(ATTACKER);
        vm.expectRevert("CoverRouter: new timestamp is not active");
        ICoverRouter(ROUTER).rollover(RAI_COVER, uint48(block.timestamp + 365 days));
    }

    function test_fee_receiver_owner_gated() public {
        assertEq(ICoverFeeReceiver(FEE_RECEIVER).owner(), DEV_SAFE);
        vm.prank(ATTACKER);
        vm.expectRevert("Ownable: caller is not the owner");
        ICoverFeeReceiver(FEE_RECEIVER).collect(dai, 1e18);
    }

    // ------------------------- claim path: filing is harmless, decision is gated
    function test_claim_filing_permissionless_but_decision_gated() public {
        // fund attacker with DAI by borrowing from the aDAI contract
        address aDAI = 0x028171bCA77440897B824Ca71D1c56caC55b68A3;
        vm.prank(aDAI);
        dai.transfer(ATTACKER, 100e18);
        vm.startPrank(ATTACKER);
        dai.approve(CM, 50e18);
        cm.fileClaim(RAI_PROTOCOL, bytes32("RAI"), uint48(block.timestamp - 1 hours));
        vm.stopPrank();
        // a claim now exists but only the auditor can decide it
        vm.prank(ATTACKER);
        vm.expectRevert("COVER_CM: !auditor");
        cm.decideClaim(RAI_PROTOCOL, 0, 0, true, 1, 1);
        // and only governance can validate it
        vm.prank(ATTACKER);
        vm.expectRevert("COVER_CC: !governance");
        cm.validateClaim(RAI_PROTOCOL, 0, 0, true);
    }

    /// Even a fully-colluding claimManager cannot redirect expired covers' collateral to CLAIM tokens:
    /// an incident today is after the 2021 expiry, so redeemClaim reverts and NOCLAIM still gets 1:1.
    function test_malicious_claim_cannot_drain_to_claim_buyer() public {
        vm.createSelectFork(RPC, BLOCK); // fresh fork
        vm.prank(CM); // simulate the claimManager accepting a 100% claim with a today-incident
        IProtocol(RAI_PROTOCOL).enactClaim(1, 1, uint48(block.timestamp), 0);
        assertEq(IProtocol(RAI_PROTOCOL).claimNonce(), 1);
        vm.prank(ATTACKER);
        vm.expectRevert("COVER: cover expired before incident");
        ICover(RAI_COVER).redeemClaim();
        // NOCLAIM holder still gets exactly 1:1 (minus fee) - the rightful bearer
        uint256 bal = IERC20(RAI_NOCLAIM).balanceOf(0x5D8291E10Ba43e527fd9433A33D1F64Ee3cD4223);
        assertGt(bal, 0);
        uint256 before = dai.balanceOf(0x5D8291E10Ba43e527fd9433A33D1F64Ee3cD4223);
        vm.prank(0x5D8291E10Ba43e527fd9433A33D1F64Ee3cD4223);
        ICover(RAI_COVER).redeemNoclaim();
        assertApproxEqAbs(dai.balanceOf(0x5D8291E10Ba43e527fd9433A33D1F64Ee3cD4223) - before, bal * 9990 / 10000, 2, "noclaim 1:1 net");
    }
}
