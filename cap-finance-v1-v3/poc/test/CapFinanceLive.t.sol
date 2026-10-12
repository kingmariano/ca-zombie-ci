// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Cap Finance (Arbitrum) — live-state, read-only extraction PoC.
// All tests run against a fork; nothing is broadcast. No mainnet transactions.
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

interface IPool {
    function deposit(uint256 amount) external payable;
    function withdraw(uint256 amount) external;
    function totalSupply() external view returns (uint256);
    function getBalance(address account) external view returns (uint256);
    function openInterest() external view returns (uint256);
    function getUtilization() external view returns (uint256);
    function owner() external view returns (address);
    function setOwner(address) external;
    function setParams(uint256, uint256, uint256, uint256) external;
}

interface IRewards {
    function collectReward() external;
    function getClaimableReward() external view returns (uint256);
    function pendingReward() external view returns (uint256);
    function updateRewards(address account) external;
}

interface IPoolCAP {
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;
    function getBalance(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IV1Trading {
    struct Position {
        uint40 closeOrderId;
        uint24 productId;
        uint64 leverage;
        uint64 price;
        uint64 margin;
        address owner;
        uint88 timestamp;
        bool isLong;
    }
    function cancelPosition(uint256 positionId) external;
    function getPositions(uint256[] calldata ids) external view returns (Position[] memory);
    function releaseMargin(uint256 positionId) external;
}

interface IV2Trading {
    struct Position {
        uint64 size;
        uint64 margin;
        uint64 timestamp;
        uint64 price;
    }
    function cancelOrder(bytes32 productId, address currency, bool isLong) external;
    function getPosition(address user, address currency, bytes32 productId, bool isLong)
        external view returns (Position memory);
    function getPendingFee(address currency) external view returns (uint256);
    function releaseMargin(address user, bytes32 productId, address currency, bool isLong, bool includeFee) external;
}

interface IV3Trading {
    struct Vault {
        uint96 cap;
        uint96 balance;
        uint64 staked;
        uint80 lastCheckpointBalance;
        uint80 lastCheckpointTime;
        uint32 stakingPeriod;
        uint32 redemptionPeriod;
        uint32 maxDailyDrawdown;
    }
    function getVault() external view returns (Vault memory);
    function redeem(uint256 stakeId, uint256 amount) external;
    function settlePositions(uint256[] calldata positionIds) external;
    function liquidatePositions(uint256[] calldata positionIds) external;
    function closePosition(uint256 positionId, uint256 margin, bool releaseMargin) external;
    function getStakes(uint256[] calldata ids) external view returns (Stake[] memory);
    struct Stake {
        address owner;
        uint64 amount;
        uint32 timestamp;
    }
}

interface IV4Trade {
    function liquidateUsers() external;
    function getLiquidatableUsers() external view returns (address[] memory);
    function withdraw(uint256 amount) external;
    function deposit(uint256 amount) external;
    function getBalance(address user) external view returns (uint256);
}

interface IV4Store {
    function getBalance(address user) external view returns (uint256);
    function poolBalance() external view returns (uint256);
    function getCLPSupply() external view returns (uint256);
}

interface ITreasuryV1 {
    function sendETH(address destination, uint256 amount) external;
    function fundOracle(address destination, uint256 amount) external;
    function debitVault(address destination, uint256 amount) external;
    function vaultBalance() external view returns (uint256);
    function owner() external view returns (address);
}

contract CapFinanceLiveTest is Test {
    // ---- contracts (Arbitrum One) ----
    address constant ETH_POOL = 0xE0cCd451BB57851c1B2172c07d8b4A7c6952a54e; // v2b ETH LP pool
    address constant USDC_POOL = 0x958cc92297e6F087f41A86125BA8E121F0FbEcF2; // v2b USDC LP pool
    address constant ETH_REWARDS = 0x29163356bBAF0a3bfeE9BA5a52a5C6463114Cb5f;
    address constant USDC_REWARDS = 0x10f2f3B550d98b6E51461a83AD3FE27123391029;
    address constant CAP_ETH_REWARDS = 0x1E91F67a5aa0137aD86eEbAD64E2C2a1B6ae30E5;
    address constant CAP_USDC_REWARDS = 0xCEFFAc2522b837012B576770b6F5DD75a3F75C38;
    address constant OLD_ETH_POOL = 0xB224F2689BC0aFc5b6721a0807d07017D8CDddf8; // v2a ETH pool (stale lastBalance)
    address constant OLD_USDC_POOL = 0x07B0B00B9008798055071dde6f2d343782b35dC6; // v2a USDC pool
    address constant V1_TRADING = 0xA55Eee92a46A50A4C65908F28A0BE966D3e71633;
    address constant V2A_TRADING = 0xCAEc650502F15c1a6bFf1C2288fC8F819776B2eC;
    address constant V2B_TRADING = 0xbEd32937D8A5D1421241F52809908f1a17D75bDb;
    address constant V3_TRADING = 0x9BC357bc5b312AaCD41a84F3C687F031B8786853;
    address constant TREASURY_V1 = 0x1058AFe66BB5b79C295CCCE51016586949Bc4e8d;
    address constant TREASURY_V2 = 0x283C41b726634fBD6B72aA22741B202DB7E56aaC;
    address constant V4_TRADE = 0x08b1d6fE01660911b939e9c896Ab53aBa231F101;
    address constant V4_STORE = 0xf16033d20ADDa47Dc99eA291D0F4C4FeF2fF47af;
    address constant V4_POOL = 0x3E4CdcDC5E3F46DCe516adB428d107CE62A6D24a;
    address constant POOLCAP = 0xC8CDd2Ea6A5149ced1F2d225D16a775ee081C67D;
    address constant USDC = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;
    address constant CAP = 0x031d35296154279DC1984dCD93E392b1f946737b;

    // ---- actors ----
    address constant ATTACKER = address(0xA77ACCE5);
    address constant ETH_POOL_TOP_LP = 0x0571a89D602254aEdE82e8A1A025Abaf5069C60B; // 2.3578 / 12.3002 CLP (19.2%)
    address constant USDC_POOL_LP = 0xfeF0E7635281eF8E3B705e9C5B86e1d3B0eAb397; // 3349.71 / 10768.36 CLP (31.1%)
    address constant V3_STAKER = 0x0e79c644eC160Afe87eA8e87201C0fe35bA63E1f; // stake #28 = 0.25 ETH
    address constant V1_OWNER = 0xAD364Da879C7AaFb519d5eaf07441D79BAcAbbbb;
    address constant V1_PENDING_OWNER = 0x0C6F66c308cC47f50AF41008700FeC147e625777; // position 2096 (price==0)
    address constant V4_USER = 0xCdAc0EC25099683313ee1320ddf8759E4D625365; // balance 139.24 USDC (unbacked)

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC", string(""));
        if (bytes(rpc).length == 0) {
            rpc = vm.envOr("ARB_RPC_URL", string(""));
        }
        if (bytes(rpc).length == 0) {
            string memory ankr = vm.envOr("ANKR_API_KEY", string(""));
            if (bytes(ankr).length > 0) {
                rpc = string.concat("https://rpc.ankr.com/arbitrum/", ankr);
            } else {
                rpc = "https://arb1.arbitrum.io/rpc";
            }
        }
        uint256 forkBlock = vm.envOr("FORK_BLOCK", uint256(0));
        if (forkBlock > 0) {
            vm.createSelectFork(rpc, forkBlock);
        } else {
            vm.createSelectFork(rpc);
        }
    }

    // ------------------------------------------------------------------
    // 0. Live state summary
    // ------------------------------------------------------------------
    function test_00_live_state() public {
        emit log_named_uint("fork block", block.number);
        emit log_named_decimal_uint("Treasury v1 ETH", TREASURY_V1.balance, 18);
        emit log_named_decimal_uint("ETH pool (v2b) ETH", ETH_POOL.balance, 18);
        emit log_named_decimal_uint("USDC pool (v2b) USDC", IERC20(USDC).balanceOf(USDC_POOL), 6);
        emit log_named_decimal_uint("ETH rewards (v2b) ETH", ETH_REWARDS.balance, 18);
        emit log_named_decimal_uint("USDC rewards (v2b) USDC", IERC20(USDC).balanceOf(USDC_REWARDS), 6);
        emit log_named_decimal_uint("CAP rewards ETH", CAP_ETH_REWARDS.balance, 18);
        emit log_named_decimal_uint("CAP rewards USDC", IERC20(USDC).balanceOf(CAP_USDC_REWARDS), 6);
        emit log_named_decimal_uint("ETH pool (v2a, old) ETH", OLD_ETH_POOL.balance, 18);
        emit log_named_decimal_uint("USDC pool (v2a, old) USDC", IERC20(USDC).balanceOf(OLD_USDC_POOL), 6);
        emit log_named_decimal_uint("Trading v3 ETH", V3_TRADING.balance, 18);
        emit log_named_decimal_uint("Trading v2a ETH", V2A_TRADING.balance, 18);
        emit log_named_decimal_uint("Trading v2b ETH", V2B_TRADING.balance, 18);
        emit log_named_decimal_uint("Trading v1 ETH", V1_TRADING.balance, 18);
        emit log_named_decimal_uint("Treasury v2 ETH", TREASURY_V2.balance, 18);
        emit log_named_decimal_uint("v4 Store USDC", IERC20(USDC).balanceOf(V4_STORE), 6);
        IV3Trading.Vault memory v = IV3Trading(V3_TRADING).getVault();
        emit log_named_decimal_uint("v3 vault.balance", v.balance, 8);
        emit log_named_decimal_uint("v3 vault.staked", v.staked, 8);
    }

    // ------------------------------------------------------------------
    // 1. E-U negative: attacker with no CLP cannot withdraw from the ETH pool
    // ------------------------------------------------------------------
    function test_01_attacker_no_clp_withdraw_is_noop() public {
        uint256 before = ATTACKER.balance;
        vm.prank(ATTACKER);
        IPool(ETH_POOL).withdraw(10 ether); // no CLP -> amount=0 -> no-op, no revert
        assertEq(ATTACKER.balance, before, "attacker extracted ETH without CLP");
    }

    // ------------------------------------------------------------------
    // 2. E-U negative: deposit -> withdraw round trip yields no profit
    // ------------------------------------------------------------------
    function test_02_deposit_withdraw_roundtrip_no_profit() public {
        vm.deal(ATTACKER, 1 ether);
        vm.prank(ATTACKER);
        IPool(ETH_POOL).deposit{value: 1 ether}(0);
        assertGt(IPool(ETH_POOL).getBalance(ATTACKER), 0);
        vm.warp(block.timestamp + 1 hours + 1);
        vm.prank(ATTACKER);
        IPool(ETH_POOL).withdraw(5 ether); // capped to own share
        assertLe(ATTACKER.balance, 1 ether, "round trip produced profit");
    }

    // ------------------------------------------------------------------
    // 3. E-U negative: v1 pending position can only be cancelled by its owner/oracle
    // ------------------------------------------------------------------
    function test_03_v1_cancelPosition_outsider_is_noop() public {
        uint256[] memory ids = new uint256[](1);
        ids[0] = 2096;
        IV1Trading.Position[] memory ps = IV1Trading(V1_TRADING).getPositions(ids);
        assertEq(ps[0].price, 0, "pos 2096 not pending");
        assertEq(ps[0].owner, V1_PENDING_OWNER);
        uint256 attackerBefore = ATTACKER.balance;
        uint256 ownerBefore = V1_PENDING_OWNER.balance;
        vm.prank(ATTACKER);
        IV1Trading(V1_TRADING).cancelPosition(2096); // silently returns
        assertEq(ATTACKER.balance, attackerBefore, "attacker got ETH");
        assertEq(V1_PENDING_OWNER.balance, ownerBefore, "owner should not be refunded by outsider call");
    }

    // ------------------------------------------------------------------
    // 4. E-U negative: v2 cancelOrder is keyed by msg.sender -> revert
    // ------------------------------------------------------------------
    function test_04_v2_cancelOrder_foreign_key_reverts() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!exists"));
        IV2Trading(V2B_TRADING).cancelOrder(bytes32(uint256(1)), address(0), true);
    }

    // ------------------------------------------------------------------
    // 5. E-U negative: v3 settlePositions is permissionless but pays nothing
    // ------------------------------------------------------------------
    function test_05_v3_settlePositions_no_payment() public {
        uint256[] memory ids = new uint256[](2);
        ids[0] = 162;
        ids[1] = 202;
        uint256 before = ATTACKER.balance;
        vm.prank(ATTACKER);
        IV3Trading(V3_TRADING).settlePositions(ids);
        assertEq(ATTACKER.balance, before, "settlePositions paid the caller");
    }

    // ------------------------------------------------------------------
    // 6. E-U negative: v3 liquidatePositions pays the caller 0 (bounty == 0)
    // ------------------------------------------------------------------
    function test_06_v3_liquidate_pays_caller_zero() public {
        IV3Trading.Vault memory v0 = IV3Trading(V3_TRADING).getVault();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 162; // long 4x entry 3312.79 -> liquidatable below ~2650
        uint256 before = ATTACKER.balance;
        vm.prank(ATTACKER);
        IV3Trading(V3_TRADING).liquidatePositions(ids);
        assertEq(ATTACKER.balance, before, "liquidator received a bounty");
        IV3Trading.Vault memory v1 = IV3Trading(V3_TRADING).getVault();
        // any gain goes to the vault (stakers), not to the caller
        assertGe(v1.balance, v0.balance, "vault balance decreased");
    }

    // ------------------------------------------------------------------
    // 7. E-U negative: rewards are pro-rata to CLP; no CLP -> 0
    // ------------------------------------------------------------------
    function test_07_rewards_collect_without_clp_zero() public {
        uint256 b0 = ATTACKER.balance;
        uint256 u0 = IERC20(USDC).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        IRewards(ETH_REWARDS).collectReward();
        vm.prank(ATTACKER);
        IRewards(USDC_REWARDS).collectReward();
        vm.prank(ATTACKER);
        IRewards(CAP_ETH_REWARDS).collectReward();
        vm.prank(ATTACKER);
        IRewards(CAP_USDC_REWARDS).collectReward();
        assertEq(ATTACKER.balance, b0, "attacker collected ETH rewards without CLP");
        assertEq(IERC20(USDC).balanceOf(ATTACKER), u0, "attacker collected USDC rewards without CLP");
    }

    // ------------------------------------------------------------------
    // 8. H-O positive: top ETH-pool LP can withdraw their pro-rata share
    // ------------------------------------------------------------------
    function test_08_eth_pool_top_lp_can_withdraw() public {
        uint256 clp = IPool(ETH_POOL).getBalance(ETH_POOL_TOP_LP);
        uint256 supply = IPool(ETH_POOL).totalSupply();
        uint256 poolBal = ETH_POOL.balance;
        uint256 expected = clp * poolBal / supply; // fee == 0
        assertGt(expected, 5 ether, "top LP share too small");
        uint256 before = ETH_POOL_TOP_LP.balance;
        vm.prank(ETH_POOL_TOP_LP);
        IPool(ETH_POOL).withdraw(20 ether); // capped at own share
        uint256 got = ETH_POOL_TOP_LP.balance - before;
        assertApproxEqRel(got, expected, 0.01e18, "LP payout != pro-rata share");
        emit log_named_decimal_uint("top LP withdrew ETH", got, 18);
    }

    // ------------------------------------------------------------------
    // 9. H-O positive: USDC-pool LP can withdraw their pro-rata share
    // ------------------------------------------------------------------
    function test_09_usdc_pool_lp_can_withdraw() public {
        uint256 clp = IPool(USDC_POOL).getBalance(USDC_POOL_LP);
        uint256 supply = IPool(USDC_POOL).totalSupply();
        uint256 poolBal = IERC20(USDC).balanceOf(USDC_POOL) * 1e12; // 18-dec
        uint256 expected = clp * poolBal / supply / 1e12; // USDC raw
        assertGt(expected, 1000e6, "LP share too small");
        uint256 before = IERC20(USDC).balanceOf(USDC_POOL_LP);
        vm.prank(USDC_POOL_LP);
        IPool(USDC_POOL).withdraw(10_000e18);
        uint256 got = IERC20(USDC).balanceOf(USDC_POOL_LP) - before;
        assertApproxEqRel(got, expected, 0.01e18, "LP payout != pro-rata share");
        emit log_named_decimal_uint("LP withdrew USDC", got, 6);
    }

    // ------------------------------------------------------------------
    // 10. H-O positive: external v3 staker can redeem after the cooldown
    // ------------------------------------------------------------------
    function test_10_v3_staker_can_redeem() public {
        IV3Trading.Vault memory v = IV3Trading(V3_TRADING).getVault();
        uint256[] memory ids = new uint256[](1);
        ids[0] = 28;
        IV3Trading.Stake[] memory st = IV3Trading(V3_TRADING).getStakes(ids);
        assertEq(st[0].owner, V3_STAKER);
        uint256 amount = st[0].amount; // 8 dec
        uint256 expected = amount * uint256(v.balance) / uint256(v.staked) * 1e10;
        uint256 before = V3_STAKER.balance;
        vm.prank(V3_STAKER);
        IV3Trading(V3_TRADING).redeem(28, amount);
        uint256 got = V3_STAKER.balance - before;
        assertApproxEqRel(got, expected, 0.01e18, "staker payout != pro-rata vault share");
        emit log_named_decimal_uint("staker redeemed ETH", got, 18);
    }

    // ------------------------------------------------------------------
    // 11. P (privileged): v1 treasury owner can move the non-vault ETH
    // ------------------------------------------------------------------
    function test_11_treasury_owner_can_send_eth() public {
        assertEq(ITreasuryV1(TREASURY_V1).owner(), V1_OWNER);
        uint256 before = ATTACKER.balance;
        vm.prank(V1_OWNER);
        ITreasuryV1(TREASURY_V1).sendETH(ATTACKER, 40 ether);
        assertEq(ATTACKER.balance, before + 40 ether, "owner could not withdraw");
    }

    // ------------------------------------------------------------------
    // 12. E-U negative (bug documented): v2a old pool uses a stale
    //     `lastBalance` -> new depositors are heavily diluted
    // ------------------------------------------------------------------
    function test_12_old_pool_stale_lastBalance_penalizes_depositor() public {
        vm.deal(ATTACKER, 0.1 ether);
        vm.prank(ATTACKER);
        IPool(OLD_ETH_POOL).deposit{value: 0.1 ether}(0);
        uint256 clp = IPool(OLD_ETH_POOL).getBalance(ATTACKER);
        uint256 supply = IPool(OLD_ETH_POOL).totalSupply();
        uint256 claim = clp * OLD_ETH_POOL.balance / supply;
        emit log_named_decimal_uint("deposited", 0.1 ether, 18);
        emit log_named_decimal_uint("claimable after deposit", claim, 18);
        assertLt(claim, 0.01 ether, "expected severe dilution from stale lastBalance");
    }

    // ------------------------------------------------------------------
    // 13. v4 (Store/CLP) is insolvent: liquidations and withdrawals revert
    // ------------------------------------------------------------------
    function test_13_v4_insolvent() public {
        address[] memory users = IV4Trade(V4_TRADE).getLiquidatableUsers();
        emit log_named_uint("v4 liquidatable users", users.length);
        assertGt(users.length, 0, "expected liquidatable users");
        // liquidation cannot even run: Store holds only dust, treasury fee transfer reverts
        vm.prank(ATTACKER);
        vm.expectRevert();
        IV4Trade(V4_TRADE).liquidateUsers();

        // a user with a 139.24 USDC accounting balance cannot withdraw it
        uint256 acct = IV4Store(V4_STORE).getBalance(V4_USER);
        assertGt(acct, 100e6, "expected unbacked user balance");
        assertLt(IERC20(USDC).balanceOf(V4_STORE), 0.05e6, "Store unexpectedly funded");
        vm.prank(V4_USER);
        vm.expectRevert();
        IV4Trade(V4_TRADE).withdraw(acct);
    }

    // ------------------------------------------------------------------
    // 14. E-U negative: admin gates are enforced
    // ------------------------------------------------------------------
    function test_14_admin_gates() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes("!owner"));
        IPool(ETH_POOL).setOwner(ATTACKER);
        vm.expectRevert(bytes("!owner"));
        IPool(ETH_POOL).setParams(0, 0, 0, 10_000);
        vm.expectRevert(bytes("!oracle"));
        ITreasuryV1(TREASURY_V1).fundOracle(ATTACKER, 1 ether);
        vm.expectRevert(bytes("!trading"));
        ITreasuryV1(TREASURY_V1).debitVault(ATTACKER, 1 ether);
        vm.stopPrank();
    }

    // ------------------------------------------------------------------
    // 15. E-U negative: v2 trading ETH is stuck (oracle/owner gated)
    // ------------------------------------------------------------------
    function test_15_v2_trading_stuck() public {
        // releaseMargin is onlyOwner; attacker cannot release others' margins
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!owner"));
        IV2Trading(V2B_TRADING).releaseMargin(ATTACKER, bytes32(uint256(1)), address(0), true, false);
        // the oracle path is an EOA that has been inactive since Oct 2023
        assertGt(V2B_TRADING.balance, 1 ether);
        uint256 before = ATTACKER.balance;
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("!exists"));
        IV2Trading(V2B_TRADING).cancelOrder(bytes32(uint256(2)), address(0), true);
        assertEq(ATTACKER.balance, before);
    }

    receive() external payable {}
}
