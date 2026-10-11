// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// @title DeFIL (Ethereum) — Phase-2 deep-dive PoC (read-only fork tests)
/// @notice Runs against live mainnet state (latest block of the fork RPC).
///   Proves:
///   1. the custody state of the FILST/USDT LP, FILST, DFL and the Compound-fork
///      lending markets (invariants + the report's headline numbers);
///   2. every unprivileged (E-U) extraction path is closed at a precise gate
///      (share accounting / mining-NFT ownership / whitelist / accrued rewards);
///   3. the actual depositors can self-service withdraw (H-O) — the value is
///      holder-recoverable, not attacker-extractable;
///   4. the realizable exit-liquidity math of the FILST/USDT pool;
///   5. the latent mint-and-dump P&L IF a mining NFT were obtainable (none is:
///      all 1,914 units are escrowed in FILSTManage).
/// No transactions are sent to mainnet; everything runs on a local fork.
/// Exact custody numbers captured at block 26,169,800 are in analysis/eth_state.json.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IStaking {
    function property() external view returns (address);
    function superior() external view returns (address);
    function totalDeposits() external view returns (uint256);
    function accountState(address) external view returns (uint256, uint256, uint256);
    function withdraw(uint256) external returns (uint256);
    function claim(address, uint256) external returns (uint256);
}

interface IFilstManage {
    function mint(address, uint256, uint256) external;
    function totalStakedMiningNftAmount() external view returns (uint256);
    function getTotalMintedAmount() external view returns (uint256);
    function getMintFee(uint256) external view returns (uint256);
}

interface IMiningNFT {
    function balanceOf(address, uint256) external view returns (uint256);
    function setApprovalForAll(address, bool) external;
}

interface IMiningNFTManage {
    function mint(uint256) external;
}

interface IUnitroller {
    function claim(address, uint256) external returns (uint256);
    function accruedStored(address) external view returns (uint256);
}

interface ICToken {
    function getCash() external view returns (uint256);
    function redeem(uint256) external returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function swap(uint256, uint256, address, bytes calldata) external;
}

interface IMFIL {
    function mint(address, uint256) external;
}

contract DeFILTest is Test {
    // ---- checksummed mainnet addresses ----
    address constant FILST = 0x7346aD4c8cD1886Ff6D16072bCeA5DFC0bc24Ca2;
    address constant DFL = 0x09ce2B746C32528B7d864A1e3979Bd97d2f095AB;
    address constant MFIL = 0x3C392C3FBE6ADA6049373478A4f8dD668Ab27b0C;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    address constant LP_FILST_USDT = 0xa2f6a219a51B4682E34a13a94C160d6c79cDcA35;
    address constant STAKING_LP = 0x9E08bD9A1E3880902688B32d563046cab74d2f2f;
    address constant STAKING_FILST = 0x01aABBAd98a7638B7f8d65E7Ec42560F1aFBbF0C;
    address constant STAKING_DFL = 0xB685Bfdad9DA7093168AB75204BbcaDF0C69c823;
    address constant STAKING_FILST_EFIL = 0x312C6ffE7743b964Be6DA9131E662AF5BAC55199;

    address constant FILST_MANAGE = 0xcd429F23088b3FA4AAbFF61dD5F9E534793f9944;
    address constant MINING_NFT = 0xad1ED31e70b569D78D1930537179A940DdA4A9CF;
    address constant MINING_NFT_MANAGE = 0x9cFcB73Cb365eD7f38dcf3bc60d2aEAFe0D502E2;
    address constant UNITROLLER = 0x6B4F20B2259Eebb97945b6EF549a1c44FcA6Cd81;
    address constant C_FILST = 0x71DD9CD476c73F7C94a82E3F00a8eD29268602e1;
    address constant PRIV_REDIST = 0xe67Ae15CBb7F6B009F12c4c8999ca3Ff4c39463d;
    address constant REWARD_POOL = 0x5E6468b3048d1b5a48cA6EAe3953b17fE1165Ed9;
    address constant DFL_USDT_PAIR = 0xd372a3221021Df72eDa38f77117d3A95f057e163;

    // ---- actors (public chain data) ----
    address constant TOP_LP_STAKER = 0xF2Ba8F66c4eb4dB715f29e6f90A8744F04A7dfa9; // ~99.9% of staked LP (EOA)
    address constant FILST_STAKER_A = 0xc1b296679262088Bc4195DA56fcf9694E96F0Ec6;
    address constant FILST_STAKER_B = 0x6E1DA46a0859980b8Db484279caE267946b55b27;
    address constant CFILST_HOLDER = 0x9A26F4D07A28afED9E1A93656C98b1377Edeac32; // sole cFILST holder
    address constant ATTACKER = 0x000000000000000000000000000000000000bEEF;

    uint256 constant MINING_NFT_STAKED = 1914;

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")))
        );
    }

    // ------------------------------------------------------------------
    // 0. Live custody assertions (invariants that define the report)
    // ------------------------------------------------------------------
    function test_state_custody_live() public {
        (uint112 rF, uint112 rU,) = IPair(LP_FILST_USDT).getReserves();
        uint256 lpSupply = IERC20(LP_FILST_USDT).totalSupply();
        uint256 lpStaked = IERC20(LP_FILST_USDT).balanceOf(STAKING_LP);

        // pair accounting is exact (no skim opportunity)
        assertEq(IERC20(FILST).balanceOf(LP_FILST_USDT), uint256(rF), "pair FILST == reserve");
        assertEq(IERC20(USDT).balanceOf(LP_FILST_USDT), uint256(rU), "pair USDT == reserve");
        // the frozen headline numbers (see analysis/eth_state.json)
        assertGt(uint256(rF), 1_390_000e18, "FILST reserve");
        assertLt(uint256(rF), 1_400_000e18, "FILST reserve");
        assertGt(uint256(rU), 700_000e6, "USDT reserve");
        assertLt(uint256(rU), 730_000e6, "USDT reserve");
        // the staking holds ~all LP and its books match exactly
        assertEq(lpStaked, IStaking(STAKING_LP).totalDeposits(), "LP staked == totalDeposits");
        assertGt(lpStaked * 10_000 / lpSupply, 9_990, "staking share > 99.9%");
        assertEq(IStaking(STAKING_LP).property(), LP_FILST_USDT, "property");
        // FILST supply is fully accounted by the mint manager
        assertEq(IERC20(FILST).totalSupply(), IFilstManage(FILST_MANAGE).getTotalMintedAmount(), "minted == supply");
        assertEq(IFilstManage(FILST_MANAGE).totalStakedMiningNftAmount(), MINING_NFT_STAKED, "NFTs staked");
        // staked FILST / DFL are present
        assertGt(IStaking(STAKING_FILST).totalDeposits(), 300_000e18, "FILST staked");
        assertGt(IStaking(STAKING_DFL).totalDeposits(), 50_000_000e18, "DFL staked");
    }

    // ------------------------------------------------------------------
    // 1. E-U gate: no outsider withdrawal of the staked LP / FILST / DFL
    // ------------------------------------------------------------------
    function test_outsider_cannot_withdraw_staked_lp() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("withdraw: insufficient value"));
        IStaking(STAKING_LP).withdraw(1e15);
    }

    function test_outsider_cannot_withdraw_staked_filst() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("withdraw: insufficient value"));
        IStaking(STAKING_FILST).withdraw(1e18);
    }

    function test_outsider_cannot_withdraw_staked_dfl() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("withdraw: insufficient value"));
        IStaking(STAKING_DFL).withdraw(1e18);
    }

    function test_outsider_has_zero_shares_everywhere() public {
        (uint256 s1,,) = IStaking(STAKING_LP).accountState(ATTACKER);
        (uint256 s2,,) = IStaking(STAKING_FILST).accountState(ATTACKER);
        (uint256 s3,,) = IStaking(STAKING_DFL).accountState(ATTACKER);
        (uint256 s4,,) = IStaking(STAKING_FILST_EFIL).accountState(ATTACKER);
        assertEq(s1 + s2 + s3 + s4, 0, "attacker shares");
    }

    // ------------------------------------------------------------------
    // 2. E-U gate: reward claims are accrued-gated (outsiders get nothing)
    // ------------------------------------------------------------------
    function test_outsider_cannot_claim_staking_rewards() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("claim: insufficient value"));
        IStaking(STAKING_LP).claim(ATTACKER, 1);
    }

    function test_outsider_cannot_claim_from_privileged_redistributor() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("claim: insufficient value"));
        IUnitroller(PRIV_REDIST).claim(ATTACKER, 1);
    }

    function test_outsider_cannot_claim_from_reward_pool() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Insufficient value"));
        IUnitroller(REWARD_POOL).claim(ATTACKER, 1);
    }

    function test_outsider_cannot_claim_dfl_from_unitroller() public {
        assertGt(IERC20(DFL).balanceOf(UNITROLLER), 40_000_000e18, "unitroller DFL");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("insufficent value"));
        IUnitroller(UNITROLLER).claim(ATTACKER, 1e18);
        assertEq(IUnitroller(UNITROLLER).accruedStored(ATTACKER), 0, "attacker accrued");
    }

    // ------------------------------------------------------------------
    // 3. E-U gate: FILST mint requires a mining NFT; all 1,914 are escrowed
    // ------------------------------------------------------------------
    function test_all_mining_nfts_are_escrowed_in_filstmanage() public {
        uint256[11] memory ids = [
            uint256(100001), 100002, 100003, 100004, 100005, 100006,
            100007, 100008, 100009, 100010, 100011
        ];
        uint256 sum;
        for (uint256 i = 0; i < ids.length; i++) {
            sum += IMiningNFT(MINING_NFT).balanceOf(FILST_MANAGE, ids[i]);
        }
        assertEq(sum, MINING_NFT_STAKED, "all NFT units in FILSTManage");
        assertEq(IFilstManage(FILST_MANAGE).totalStakedMiningNftAmount(), MINING_NFT_STAKED, "bookkeeping");
    }

    function test_outsider_cannot_mint_filst() public {
        assertEq(IMiningNFT(MINING_NFT).balanceOf(ATTACKER, 100001), 0, "no NFT");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("exceed mining NFT balance"));
        IFilstManage(FILST_MANAGE).mint(ATTACKER, 100001, 1);
    }

    function test_outsider_cannot_mint_new_mining_nft() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("sender not in whitelist"));
        IMiningNFTManage(MINING_NFT_MANAGE).mint(1);
    }

    function test_outsider_cannot_mint_mfil() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("MinterAccess: sender do not have the minter role"));
        IMFIL(MFIL).mint(ATTACKER, 1e18);
    }

    // ------------------------------------------------------------------
    // 4. H-O proof: the actual depositors can self-service withdraw
    // ------------------------------------------------------------------
    function test_HO_top_lp_staker_can_withdraw_entire_stake() public {
        uint256 lpStaked = IERC20(LP_FILST_USDT).balanceOf(STAKING_LP);
        (uint256 share,,) = IStaking(STAKING_LP).accountState(TOP_LP_STAKER);
        assertGt(share, lpStaked * 9 / 10, "top staker holds > 90% of the stake");
        uint256 before = IERC20(LP_FILST_USDT).balanceOf(TOP_LP_STAKER);
        vm.prank(TOP_LP_STAKER);
        uint256 out = IStaking(STAKING_LP).withdraw(share);
        assertEq(out, share, "withdraw amount");
        assertEq(IERC20(LP_FILST_USDT).balanceOf(TOP_LP_STAKER) - before, share, "LP received");
        assertEq(IERC20(LP_FILST_USDT).balanceOf(STAKING_LP), lpStaked - share, "staking LP left");
    }

    function test_HO_filst_staker_can_withdraw_entire_stake() public {
        (uint256 shareA,,) = IStaking(STAKING_FILST).accountState(FILST_STAKER_A);
        (uint256 shareB,,) = IStaking(STAKING_FILST).accountState(FILST_STAKER_B);
        address who = shareA >= shareB ? FILST_STAKER_A : FILST_STAKER_B;
        uint256 share = shareA >= shareB ? shareA : shareB;
        assertGt(share, 1_000e18, "a large FILST staker still exists");
        uint256 before = IERC20(FILST).balanceOf(who);
        vm.prank(who);
        uint256 out = IStaking(STAKING_FILST).withdraw(share);
        assertEq(out, share, "withdraw amount");
        assertEq(IERC20(FILST).balanceOf(who) - before, share, "FILST received");
    }

    function test_HO_cfilst_holder_can_redeem_market_cash() public {
        // cFILST market auto-stakes deposits into the FilstPool; its cash is
        // backed 1:1 by pool shares. The holder can redeem (H-O).
        uint256 bal = ICToken(C_FILST).balanceOf(CFILST_HOLDER);
        assertGt(bal, 3_000e18, "cFILST balance");
        assertEq(ICToken(C_FILST).getCash(), ICToken(C_FILST).totalSupply(), "market cash == cToken supply (1:1)");
        uint256 before = IERC20(FILST).balanceOf(CFILST_HOLDER);
        vm.prank(CFILST_HOLDER);
        uint256 err = ICToken(C_FILST).redeem(bal);
        assertEq(err, 0, "redeem error code");
        assertEq(IERC20(FILST).balanceOf(CFILST_HOLDER) - before, bal, "FILST received");
    }

    // ------------------------------------------------------------------
    // 5. Exit liquidity: what the pool can actually pay for FILST
    // ------------------------------------------------------------------
    function _amountOut(uint256 rF, uint256 rU, uint256 amountIn) internal pure returns (uint256) {
        uint256 amountInWithFee = amountIn * 997;
        return (amountInWithFee * rU) / (rF * 1000 + amountInWithFee);
    }

    function test_exit_liquidity_math() public {
        (uint112 rF, uint112 rU,) = IPair(LP_FILST_USDT).getReserves();
        uint256 out100k = _amountOut(rF, rU, 100_000e18);
        uint256 outFull = _amountOut(rF, rU, uint256(rF)); // sell the whole FILST side
        uint256 outHuge = _amountOut(rF, rU, 100_000_000e18);
        uint256 asymptote = uint256(rU) * 997 / 1000;
        emit log_named_uint("USDT out for 100k FILST", out100k);
        emit log_named_uint("USDT out for full FILST side", outFull);
        emit log_named_uint("USDT out for 100M FILST", outHuge);
        emit log_named_uint("asymptote (0.997 * USDT reserve)", asymptote);
        assertGt(out100k, 45_000e6);
        assertLt(out100k, 50_000e6);
        assertGt(outFull, 340_000e6);
        assertLt(outFull, 375_000e6);
        assertGt(outHuge, 690_000e6);
        assertLt(outHuge, asymptote);
    }

    // ------------------------------------------------------------------
    // 6. Latent risk: mint-and-dump IF a mining NFT were obtainable
    //    (it is not — this test fabricates one via vm.store to quantify)
    // ------------------------------------------------------------------
    function _forceERC1155Balance(address nft, address account, uint256 id, uint256 amount) internal {
        for (uint256 slot = 0; slot < 10; slot++) {
            // mapping(uint256 => mapping(address => uint256)) at base slot `slot`
            bytes32 loc = keccak256(abi.encode(account, keccak256(abi.encode(id, slot))));
            bytes32 old = vm.load(nft, loc);
            vm.store(nft, loc, bytes32(amount));
            if (IMiningNFT(nft).balanceOf(account, id) == amount) return;
            vm.store(nft, loc, old);
        }
        revert("erc1155 slot not found");
    }

    function test_latent_mint_and_dump_if_nft_were_obtainable() public {
        // fabricate the missing precondition: one mining-NFT unit + operator approval
        _forceERC1155Balance(MINING_NFT, ATTACKER, 100001, 1);
        assertEq(IMiningNFT(MINING_NFT).balanceOf(ATTACKER, 100001), 1, "fabricated NFT");
        vm.prank(ATTACKER);
        IMiningNFT(MINING_NFT).setApprovalForAll(FILST_MANAGE, true);

        uint256 filstAmount = 1024e18; // 1 NFT unit = 1024 FILST
        uint256 fee = IFilstManage(FILST_MANAGE).getMintFee(filstAmount);
        assertGt(fee, 0, "fee");

        // fund the DFL fee from the Unitroller whale (holds ~43.75M DFL)
        vm.prank(UNITROLLER);
        IERC20(DFL).transfer(ATTACKER, fee);
        vm.prank(ATTACKER);
        IERC20(DFL).approve(FILST_MANAGE, fee);

        uint256 balBefore = IERC20(FILST).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IFilstManage(FILST_MANAGE).mint(ATTACKER, 100001, 1);
        uint256 minted = IERC20(FILST).balanceOf(ATTACKER) - balBefore;
        assertEq(minted, filstAmount, "minted");

        // dump into the FILST/USDT pool
        (uint112 rF, uint112 rU,) = IPair(LP_FILST_USDT).getReserves();
        uint256 out = _amountOut(rF, rU, minted);
        uint256 usdtBefore = IERC20(USDT).balanceOf(ATTACKER);
        vm.startPrank(ATTACKER);
        IERC20(FILST).transfer(LP_FILST_USDT, minted);
        IPair(LP_FILST_USDT).swap(0, out, ATTACKER, "");
        vm.stopPrank();
        uint256 usdtOut = IERC20(USDT).balanceOf(ATTACKER) - usdtBefore;
        assertEq(usdtOut, out, "USDT out");

        // fee value in USDT at the live DFL/USDT price
        (uint112 dflR, uint112 usdtR,) = IPair(DFL_USDT_PAIR).getReserves();
        uint256 feeUsd = fee * uint256(usdtR) / uint256(dflR);
        emit log_named_uint("minted FILST (wei)", minted);
        emit log_named_uint("DFL fee paid (wei)", fee);
        emit log_named_uint("fee in USDT (1e6)", feeUsd);
        emit log_named_uint("USDT out (1e6)", usdtOut);
        assertGt(usdtOut, feeUsd, "profitable if NFT obtainable");
    }

    // ------------------------------------------------------------------
    // 7. Mining NFT escrow cannot be pulled back by anyone
    // ------------------------------------------------------------------
    function test_filstmanage_escrow_holds_all_units() public {
        // FILSTManage's only token-moving function is DFL `transfer` (onlyOwner);
        // there is no function that transfers the escrowed ERC-1155s out.
        assertEq(IMiningNFT(MINING_NFT).balanceOf(FILST_MANAGE, 100001), 13);
        assertEq(IMiningNFT(MINING_NFT).balanceOf(FILST_MANAGE, 100004), 403);
        assertEq(IMiningNFT(MINING_NFT).balanceOf(FILST_MANAGE, 100006), 465);
    }
}
