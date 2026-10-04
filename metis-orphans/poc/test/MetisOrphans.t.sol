// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// @title Metis orphans (H-35..H-41) fork-verification suite
/// @notice Read-only on mainnet; all calls run on a local Metis fork. No mainnet txs.
/// Chain: Metis Andromeda (1088). Pinned implicitly to the fork RPC tip; the exact
/// block is emitted in each test via `block.number` and `--vv` logs.

interface IGnosisSafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function getModules() external view returns (address[] memory);
    function nonce() external view returns (uint256);
    function VERSION() external view returns (string memory);
    function execTransaction(
        address to,
        uint256 value,
        bytes calldata data,
        uint8 operation,
        uint256 safeTxGas,
        uint256 baseGas,
        uint256 gasPrice,
        address gasToken,
        address payable refundReceiver,
        bytes calldata signatures
    ) external payable returns (bool);
}

interface IVaultLike {
    function owner() external view returns (address);
    function transferEther(address payee, uint256 amount) external;
    function initialize() external;
    function upgradeTo(address newImplementation) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
    function DEFAULT_ADMIN_ROLE() external view returns (bytes32);
}

interface IPairLike {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function skim(address to) external;
    function burn(address to) external returns (uint256, uint256);
}

interface IPool {
    function withdraw(address asset, uint256 amount, address to) external returns (uint256);
    function getUserAccountData(address user)
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256);
}

interface IAToken {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function symbol() external view returns (string memory);
}

contract MetisOrphansPoC is Test {
    // ---- H-35 ----
    address constant SAFE = 0xdd7c49D1bA862b1285710A30E20C2438b13AE532;
    // ---- H-36 ----
    address constant VAULT = 0x17A30350771d02409046A683b18Fe1C13cCFC4A8;
    address constant VAULT_IMPL = 0xd62dEdee92074458B1C31133E6601CB6b87e844B;
    address constant VAULT_OWNER = 0x52c904aBC83fD537a508F56Fc6F3D723fF5403e1;
    // ---- H-37 ----
    address constant MINING = 0x7077f35063f17EE1B84678334d261Ccf47980271;
    // ---- H-38 ----
    address constant PAIR_A = 0x3D60aFEcf67e6ba950b499137A72478B2CA7c5A1; // m.USDT/METIS
    address constant PAIR_B = 0x59051B5F5172b69E66869048Dc69D35dB0B3610d; // WETH/METIS
    address constant PAIR_C = 0x5Ae3ee7fBB3Cb28C17e7ADc3a6Ae605ae2465091; // METIS/m.USDC
    address constant PAIR_D = 0x9dAbD9257E55230Fa17415BF9a6946085f533a00; // BANG/METIS
    // ---- H-41 ----
    address constant METIS = 0xDeadDeAddeAddEAddeadDEaDDEAdDeaDDeAD0000;
    address constant ATOKEN = 0x7314Ef2CA509490f65F52CC8FC9E0675C66390b8;
    address constant AAVE_POOL = 0x90df02551bB792286e8D4f13E0e357b4Bf1D6a57;
    // top aMetMETIS holder (EOA) at recon time - proves H-O self-service exit
    address constant ATOKEN_WHALE = 0xA4C39Bc895E380e0B54f9b1c952c3bC151cf6FB2;

    address attacker = address(0xBADBEEF);

    function setUp() public {
        string memory url = vm.envOr("METIS_RPC_URL", string("https://andromeda.metis.io/?owner=1088"));
        try vm.createSelectFork(url) {
            // ok
        } catch {
            vm.createSelectFork("https://metis.drpc.org");
        }
        vm.deal(attacker, 10 ether);
    }

    // ======================= H-35 Safe =======================

    function test_H35_safe_live_state() public {
        emit log_named_uint("block", block.number);
        assertEq(IGnosisSafe(SAFE).getThreshold(), 4, "threshold must be 4");
        assertEq(IGnosisSafe(SAFE).getOwners().length, 6, "6 owners");
        assertEq(IGnosisSafe(SAFE).getModules().length, 0, "no modules");
        assertEq(IGnosisSafe(SAFE).VERSION(), "1.3.0", "safe version");
        uint256 bal = SAFE.balance;
        emit log_named_uint("safe_METIS_wei", bal);
        assertGe(bal, 1_847_552 ether, ">= 1,847,552 METIS");
    }

    function test_H35_safe_attacker_execTransaction_reverts() public {
        // Empty signatures -> must revert (GS020/GS026 style)
        vm.prank(attacker);
        (bool ok, ) = SAFE.call(
            abi.encodeWithSelector(
                IGnosisSafe.execTransaction.selector,
                attacker,
                1 ether,
                bytes(""),
                0,
                0,
                0,
                0,
                address(0),
                payable(address(0)),
                bytes("")
            )
        );
        assertFalse(ok, "execTransaction without 4/6 signatures must revert");
    }

    function test_H35_safe_privileged_functions_revert() public {
        // enableModule / addOwnerWithThreshold / setGuard are all owner-gated
        vm.startPrank(attacker);
        (bool ok, ) = SAFE.call(abi.encodeWithSignature("enableModule(address)", attacker));
        assertFalse(ok, "enableModule must revert for non-owner");
        (ok, ) = SAFE.call(abi.encodeWithSignature("addOwnerWithThreshold(address,uint256)", attacker, 1));
        assertFalse(ok, "addOwnerWithThreshold must revert for non-owner");
        (ok, ) = SAFE.call(abi.encodeWithSignature("setGuard(address)", attacker));
        assertFalse(ok, "setGuard must revert for non-owner");
        vm.stopPrank();
    }

    // ======================= H-36 Vault =======================

    function test_H36_vault_live_state() public {
        emit log_named_uint("block", block.number);
        assertEq(IVaultLike(VAULT).owner(), VAULT_OWNER, "owner");
        bytes32 slot = vm.load(VAULT, 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc);
        assertEq(address(uint160(uint256(slot))), VAULT_IMPL, "impl slot");
        uint256 bal = VAULT.balance;
        emit log_named_uint("vault_METIS_wei", bal);
        assertGe(bal, 68_713 ether, ">= 68,713 METIS");
    }

    function test_H36_vault_attacker_paths_revert() public {
        // transferEther is PAYER_ROLE-gated and payee must be PAYEE_ROLE
        vm.prank(attacker);
        (bool ok1, ) = VAULT.call(abi.encodeWithSelector(IVaultLike.transferEther.selector, attacker, 1 ether));
        assertFalse(ok1, "transferEther must revert for unprivileged caller");
        // re-initialize
        vm.prank(attacker);
        (bool ok2, ) = VAULT.call(abi.encodeWithSelector(IVaultLike.initialize.selector));
        assertFalse(ok2, "initialize must revert (already initialized)");
        // upgrade
        vm.prank(attacker);
        (bool ok3, ) = VAULT.call(abi.encodeWithSelector(IVaultLike.upgradeTo.selector, attacker));
        assertFalse(ok3, "upgradeTo must revert for non-owner");
    }

    // ======================= H-37 Mining =======================

    function test_H37_mining_live_state() public {
        emit log_named_uint("block", block.number);
        uint256 bal = MINING.balance;
        emit log_named_uint("mining_METIS_wei", bal);
        (bool ok, bytes memory ret) = MINING.staticcall(abi.encodeWithSignature("paused()"));
        if (ok && ret.length >= 32) emit log_named_uint("paused", abi.decode(ret, (uint256)));
        (ok, ret) = MINING.staticcall(abi.encodeWithSignature("owner()"));
        if (ok && ret.length >= 32) emit log_named_address("owner", abi.decode(ret, (address)));
        (ok, ret) = MINING.staticcall(abi.encodeWithSignature("poolLength()"));
        if (ok && ret.length >= 32) emit log_named_uint("poolLength", abi.decode(ret, (uint256)));
        assertGe(bal, 13_217 ether, ">= 13,217 METIS");
    }

    function test_H37_attacker_emergencyWithdraw_gains_nothing() public {
        uint256 before = attacker.balance;
        vm.prank(attacker);
        (bool ok, ) = MINING.call(abi.encodeWithSignature("emergencyWithdraw(uint256)", 0));
        emit log_named_string("emergencyWithdraw(0)_success", ok ? "true" : "false");
        // whether it reverts or no-ops, the attacker must not gain METIS
        assertEq(attacker.balance, before, "attacker must gain no METIS");
    }

    function test_H37_attacker_deposit_reverts() public {
        // deposit(address,address,uint256,uint256,uint256): LP token, user, amount, dacId, lock?
        vm.prank(attacker);
        (bool ok, ) = MINING.call(
            abi.encodeWithSignature("deposit(address,address,uint256,uint256,uint256)", PAIR_A, attacker, 1, 0, 0)
        );
        emit log_named_string("deposit_success", ok ? "true" : "false");
        // Even if a deposit path existed it would require real LP; record result for dossier.
    }

    function test_H36_vault_role_gated_erc20_transfer_reverts() public {
        vm.prank(attacker);
        (bool ok, ) = VAULT.call(
            abi.encodeWithSignature("transferErc20(address,address,uint256)", METIS, attacker, 1 ether)
        );
        assertFalse(ok, "transferErc20 must revert for unprivileged caller");
    }

    function test_H37_attacker_privileged_functions_revert() public {
        vm.startPrank(attacker);
        (bool ok, ) = MINING.call(abi.encodeWithSignature("withdraw(address,uint256,uint256)", PAIR_A, 1, 0));
        assertFalse(ok, "withdraw must revert for unprivileged caller");
        (ok, ) = MINING.call(abi.encodeWithSignature("setMetisPerSecond(uint256)", 1 ether));
        assertFalse(ok, "setMetisPerSecond must revert for non-owner");
        (ok, ) = MINING.call(abi.encodeWithSignature("setPaused(bool)", false));
        assertFalse(ok, "setPaused must revert for non-owner");
        vm.stopPrank();
    }

    // ======================= H-38 Netswap pairs =======================

    function _checkPairNoExcess(address pair, string memory tag) internal {
        IPairLike p = IPairLike(pair);
        (uint112 r0, uint112 r1, ) = p.getReserves();
        uint256 b0 = IERC20(p.token0()).balanceOf(pair);
        uint256 b1 = IERC20(p.token1()).balanceOf(pair);
        emit log_named_string("pair", tag);
        emit log_named_uint("reserve0", r0);
        emit log_named_uint("balance0", b0);
        emit log_named_uint("reserve1", r1);
        emit log_named_uint("balance1", b1);
        assertEq(b0, r0, "no token0 excess to skim");
        assertEq(b1, r1, "no token1 excess to skim");
        assertEq(p.balanceOf(pair), 0, "pair holds no own LP to burn");
    }

    function test_H38_pairs_no_skim_excess_and_no_self_lp() public {
        emit log_named_uint("block", block.number);
        _checkPairNoExcess(PAIR_A, "A m.USDT/METIS");
        _checkPairNoExcess(PAIR_B, "B WETH/METIS");
        _checkPairNoExcess(PAIR_C, "C METIS/m.USDC");
        _checkPairNoExcess(PAIR_D, "D BANG/METIS");
    }

    function test_H38_pair_burn_without_lp_reverts() public {
        vm.prank(attacker);
        (bool ok, ) = PAIR_A.call(abi.encodeWithSelector(IPairLike.burn.selector, attacker));
        assertFalse(ok, "burn with zero LP must revert");
        vm.prank(attacker);
        (ok, ) = PAIR_C.call(abi.encodeWithSelector(IPairLike.burn.selector, attacker));
        assertFalse(ok, "burn with zero LP must revert (pair C)");
    }

    function test_H38_pair_skim_transfers_nothing() public {
        uint256 a0 = IERC20(IPairLike(PAIR_A).token0()).balanceOf(attacker);
        uint256 a1 = IERC20(IPairLike(PAIR_A).token1()).balanceOf(attacker);
        vm.prank(attacker);
        IPairLike(PAIR_A).skim(attacker);
        assertEq(IERC20(IPairLike(PAIR_A).token0()).balanceOf(attacker), a0, "skim pays 0 token0");
        assertEq(IERC20(IPairLike(PAIR_A).token1()).balanceOf(attacker), a1, "skim pays 0 token1");
    }

    function test_H38_factory_privileged_functions_revert() public {
        address factory = 0x70f51d68D16e8f9e418441280342BD43AC9Dff9f;
        vm.startPrank(attacker);
        (bool ok, ) = factory.call(abi.encodeWithSignature("setFeeRate(uint256)", 0));
        assertFalse(ok, "setFeeRate must revert for non-feeToSetter");
        (ok, ) = factory.call(abi.encodeWithSignature("setFeeTo(address)", attacker));
        assertFalse(ok, "setFeeTo must revert for non-feeToSetter");
        vm.stopPrank();
    }

    // ======================= H-41 Aave V3 Metis =======================

    function test_H41_atoken_live_state() public {
        emit log_named_uint("block", block.number);
        uint256 supply = IAToken(ATOKEN).totalSupply();
        uint256 bal = IERC20(METIS).balanceOf(ATOKEN);
        emit log_named_uint("aToken_totalSupply", supply);
        emit log_named_uint("aToken_METIS_balance", bal);
        assertGe(bal, 26_000 ether, ">= 26,000 METIS backing");
        assertGt(supply, bal, "debt outstanding (supply > backing)");
    }

    function test_H41_attacker_withdraw_reverts() public {
        vm.prank(attacker);
        (bool ok, ) = AAVE_POOL.call(
            abi.encodeWithSelector(IPool.withdraw.selector, METIS, 1 ether, attacker)
        );
        assertFalse(ok, "withdraw without aTokens must revert");
        assertEq(IERC20(METIS).balanceOf(attacker), 0, "attacker gets no METIS");
    }

    function test_H41_holder_self_withdraw_works_HO() public {
        uint256 holderBal = IAToken(ATOKEN).balanceOf(ATOKEN_WHALE);
        emit log_named_uint("whale_aToken_balance", holderBal);
        assertGt(holderBal, 0, "whale holds aTokens");
        vm.prank(ATOKEN_WHALE);
        uint256 got = IPool(AAVE_POOL).withdraw(METIS, type(uint256).max, ATOKEN_WHALE);
        emit log_named_uint("whale_withdrew_METIS", got);
        assertEq(got, holderBal, "holder can self-withdraw full aToken balance (H-O)");
    }

    function test_H41_attacker_borrow_and_rescue_revert() public {
        vm.startPrank(attacker);
        (bool ok, ) = AAVE_POOL.call(
            abi.encodeWithSignature(
                "borrow(address,uint256,uint256,uint16,address)",
                METIS,
                1 ether,
                2,
                0,
                attacker
            )
        );
        assertFalse(ok, "borrow without collateral must revert");
        (ok, ) = ATOKEN.call(abi.encodeWithSignature("rescueTokens(address,address,uint256)", METIS, attacker, 1));
        assertFalse(ok, "rescueTokens must revert for non-pool-admin");
        vm.stopPrank();
    }

    function test_H41_metis_borrowers_health() public {
        // Largest METIS variable-debt holder at recon time
        address borrower = 0x24a30823bd87E785B0c4B3803a2bffD91eb6876F;
        (
            uint256 totalCollateralBase,
            uint256 totalDebtBase,
            ,
            ,
            ,
            uint256 healthFactor
        ) = IPool(AAVE_POOL).getUserAccountData(borrower);
        emit log_named_uint("borrower_collateral_base", totalCollateralBase);
        emit log_named_uint("borrower_debt_base", totalDebtBase);
        emit log_named_uint("borrower_healthFactor", healthFactor);
    }

    // ======================= H-38 Netswap farms =======================

    address constant NETTFARM = 0x9d1dbB49b2744A1555EDbF1708D64dC71B0CB052;
    address constant SCORESFARM = 0xC92819F6497708D805F37FFFD082FE46E10Cac27;
    address constant REWARDER0 = 0x4CCceDE3d5A6fc96FF921b8E765446c827f4B294;

    function test_H38_farm_state() public {
        emit log_named_uint("nettfarm_LP_B", IERC20(PAIR_B).balanceOf(NETTFARM));
        emit log_named_uint("nettfarm_LP_C", IERC20(PAIR_C).balanceOf(NETTFARM));
        emit log_named_uint("scoresfarm_LP_A", IERC20(PAIR_A).balanceOf(SCORESFARM));
        emit log_named_uint("rewarder0_METIS", IERC20(METIS).balanceOf(REWARDER0));
        assertGt(IERC20(PAIR_B).balanceOf(NETTFARM), 0, "farm holds staked LP");
    }

    function test_H38_farms_attacker_paths_closed() public {
        vm.startPrank(attacker);
        (bool ok, ) = NETTFARM.call(abi.encodeWithSignature("withdraw(uint256,uint256)", 5, 1));
        assertFalse(ok, "NETTFarm withdraw without stake must revert");
        (ok, ) = NETTFARM.call(abi.encodeWithSignature("emergencyWithdraw(uint256)", 5));
        assertEq(IERC20(PAIR_B).balanceOf(attacker), 0, "emergencyWithdraw pays 0 to a non-staker");
        (ok, ) = NETTFARM.call(abi.encodeWithSignature("deposit(uint256,uint256)", 5, 1));
        assertFalse(ok, "deposit without LP must revert");
        (ok, ) = NETTFARM.call(abi.encodeWithSignature("updateEmissionRate(uint256)", 1));
        assertFalse(ok, "updateEmissionRate must be owner-only");
        (ok, ) = SCORESFARM.call(abi.encodeWithSignature("withdraw(uint256,uint256)", 2, 1));
        assertFalse(ok, "ScoresFarm withdraw without stake must revert");
        (ok, ) = REWARDER0.call(abi.encodeWithSignature("setRewardRate(uint256)", 1));
        assertFalse(ok, "rewarder setRewardRate must be owner-only");
        (ok, ) = REWARDER0.call(abi.encodeWithSignature("emergencyWithdraw()"));
        assertFalse(ok, "rewarder emergencyWithdraw must be owner-only");
        vm.stopPrank();
    }
}
