// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Cega V1 — live-state gate proofs (read-only fork tests; no mainnet txs).
// Proves that every value-moving path on the live Cega V1 EVM deployment is
// either role-gated or requires vault shares, and that the permissionless
// settlement calls cannot move tokens. Documents live USDC custody.
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
}

interface IFCNVault is IERC20 {
    function redeem(uint256) external returns (uint256);
    function deposit(uint256, address) external returns (uint256);
    function convertToAssets(uint256) external view returns (uint256);
    function convertToShares(uint256) external view returns (uint256);
}

struct RoundData {
    int256 answer;
    uint256 startedAt;
    uint256 updatedAt;
    uint80 answeredInRound;
}

struct FCNVaultMeta {
    uint256 vaultStart;
    uint256 tradeDate;
    uint256 tradeExpiry;
    uint256 aprBps;
    uint256 tenorInDays;
    uint256 underlyingAmount;
    uint256 currentAssetAmount;
    uint256 totalCouponPayoff;
    uint256 vaultFinalPayoff;
    uint256 queuedWithdrawalsSharesAmount;
    uint256 queuedWithdrawalsCount;
    uint256 optionBarriersCount;
    uint256 leverage;
    address vaultAddress;
    uint8 vaultStatus;
    bool isKnockedIn;
}

interface IOracle {
    function latestRoundData() external view returns (uint80, int256, uint256, uint256, uint80);
    function addNextRoundData(RoundData calldata) external;
    function updateRoundData(uint80, RoundData calldata) external;
    function decimals() external view returns (uint8);
}

interface ICegaState {
    function moveAssetsToProduct(string memory, address, uint256) external;
    function addProduct(string memory, address) external;
    function removeProduct(string memory) external;
    function addOracle(string memory, address) external;
    function setFeeRecipient(address) external;
    function updateMarketMakerPermission(address, bool) external;
    function feeRecipient() external view returns (address);
    function oracleAddresses(string memory) external view returns (address);
    function getOracleNames() external view returns (string[] memory);
    function hasRole(bytes32, address) external view returns (bool);
}

interface IProduct {
    function sendAssetsToTrade(address, address, uint256) external;
    function processWithdrawalQueue(address, uint256) external;
    function collectFees(address) external;
    function setVaultStatus(address, uint8) external;
    function setKnockInStatus(address, bool) external;
    function addToWithdrawalQueue(address, uint256) external;
    function calculateVaultFinalPayoff(address) external returns (uint256);
    function checkBarriers(address) external;
    function calculateCurrentYield(address) external;
    function sumVaultUnderlyingAmounts() external view returns (uint256);
    function queuedDepositsTotalAmount() external view returns (uint256);
    function getVaultAddresses() external view returns (address[] memory);
    function vaults(address) external view returns (FCNVaultMeta memory);
}

interface ILOVProduct is IProduct {
    function leverages(uint256)
        external
        view
        returns (bool, bool, uint256, uint256, uint256, address[] memory);
    function getVaultAddresses(uint256) external view returns (address[] memory);
    function getDepositQueueCount(uint256) external view returns (uint256);
}

contract CegaV1EthTest is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant STATE = 0x0730AA138062D8Cc54510aa939b533ba7c30f26B;
    address constant SUPERCHARGER = 0x042021d59731d3fFA908c7c4211177137Ba362Ea;
    address constant GOFAST = 0x56F00A399151EC74cf7bE8DC38225363E84975E6;
    address constant INSANIC = 0x784e3C592A6231D92046bd73508B3aAe3A7cc815;
    address constant PUPPY = 0x2aAE28E495626F587677ca779838266DB9bD6Cd1;
    address constant L2 = 0x98b872604F36807169c096241ECD4646021de133;
    address constant STARBOARD = 0xAB8631417271Dbb928169F060880e289877Ff158;
    address constant AUTOPILOT = 0xcf81b51AecF6d88dF12Ed492b7b7f95bBc24B8Af;
    address constant CRUISE = 0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8;
    address constant GENESIS = 0x94C5D3C2fE4EF2477E562EEE7CCCF07Ee273B108;
    address constant GOFAST_VAULT = 0x5799Dab15A745b346058AFbC141C78A0dc25F8c6; // qc=2 at block 26112349
    address constant CRUISE_VAULT = 0xE12Cc7191204f73A49429616AC9b735343efeeFe;
    address constant ORACLE_BTC = 0x6579EC6cB3088543600f27C756c09676aCEC981E;
    address constant SUPERCHARGER_LOV = 0xF9B7BF3f4616209Aa9d412443Aa0f94449c63122;
    address constant SCLOV_VAULT = 0xd6d76216Fb9f5d6cAB1af27868296AF6552dB9CF;
    address constant ORPHAN_FCN = 0xf27952993b17Bd60D3C03F64d70Ec2613808344F;
    address constant ORPHAN_VAULT = 0x66dE8a2E8bb814D320612C1E199BDd366eE93ed6;

    address attacker = address(0xA77ACC0);

    function setUp() public {
        string memory rpc = vm.envOr(
            "CEGA_ETH_FORK",
            vm.envOr(
                "BLOCKPI_RPC_URL",
                vm.envOr(
                    "NODEREAL_ETH_RPC_URL",
                    vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://eth.drpc.org")))
                )
            )
        );
        uint256 blk = vm.envOr("CEGA_ETH_BLOCK", uint256(26112349));
        if (blk == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, blk);
        }
    }

    function _bal(address a) internal view returns (uint256) {
        return IERC20(USDC).balanceOf(a);
    }

    // 1. Live custody snapshot -------------------------------------------------
    function test_eth_live_custody_snapshot() public {
        emit log_named_uint("fork block", block.number);
        address[21] memory prods = [
            SUPERCHARGER, GOFAST, INSANIC, PUPPY, L2, STARBOARD, AUTOPILOT, CRUISE, GENESIS, STATE,
            SUPERCHARGER_LOV, 0xeF1CE301B311654419810c8F5DbBD7Eb595F3d96, 0xDC60989aaa5fbA0C2435D755056b41A9Ff415F13,
            0x4511E45687b0F18152A03C4FD20E61fb9B373431, 0x81468f8aB2d071f4F95862D5886fA57ad2B86b24, 0xD4Ae9ce7DE8687a74dBC092526b47902b5CaaB26,
            ORPHAN_FCN, 0xEd803C5EE534Dc4FD350F110C56E264432068b6B, 0xb032134C3f5aC77B436b95983882294711D55c7C, 0xcEA6002AE60f764EcED023787281D63Da1528992, 0x5C05bEF15fe2E4acC421C183A488B1381d45713E
        ];
        uint256 total;
        for (uint256 i = 0; i < prods.length; i++) {
            uint256 b = _bal(prods[i]);
            emit log_named_address("product", prods[i]);
            emit log_named_uint("  USDC (6dp)", b);
            total += b;
        }
        emit log_named_uint("TOTAL USDC in products+states", total);
        // The go-fast product is the largest residual holder.
        assertGt(_bal(GOFAST), 100_000e6, "go-fast should hold >100k USDC");
        assertGt(_bal(STATE), 0, "state holds residual USDC");
        assertGt(_bal(SUPERCHARGER_LOV), 1_000e6, "supercharger-lov holds >1k USDC");
    }

    // 2. Every value-moving product function is role-gated ---------------------
    function test_eth_value_movers_revert_for_unprivileged() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("403:TA"));
        IProduct(GOFAST).sendAssetsToTrade(GOFAST_VAULT, attacker, 1);

        vm.expectRevert(bytes("403:TA"));
        IProduct(GOFAST).processWithdrawalQueue(GOFAST_VAULT, 1);

        vm.expectRevert(bytes("403:TA"));
        IProduct(GOFAST).collectFees(GOFAST_VAULT);

        vm.expectRevert(bytes("403:OA"));
        IProduct(GOFAST).setVaultStatus(GOFAST_VAULT, 3);

        vm.expectRevert(bytes("403:DA"));
        IProduct(GOFAST).setKnockInStatus(GOFAST_VAULT, true);
        vm.stopPrank();
    }

    function test_eth_cegaState_value_movers_revert_for_unprivileged() public {
        vm.startPrank(attacker);
        vm.expectRevert(); // AccessControl: missing role
        ICegaState(STATE).moveAssetsToProduct("insanic", INSANIC, 1);

        vm.expectRevert();
        ICegaState(STATE).addProduct("attacker", attacker);

        vm.expectRevert();
        ICegaState(STATE).removeProduct("insanic");

        vm.expectRevert();
        ICegaState(STATE).addOracle("attacker", attacker);

        vm.expectRevert();
        ICegaState(STATE).setFeeRecipient(attacker);

        vm.expectRevert();
        ICegaState(STATE).updateMarketMakerPermission(attacker, true);
        vm.stopPrank();
    }

    // 3. Vault shares can only be minted/redeemed by the product ---------------
    function test_eth_vault_deposit_redeem_onlyOwner() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFCNVault(GOFAST_VAULT).deposit(1, attacker);

        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFCNVault(GOFAST_VAULT).redeem(1);
        vm.stopPrank();
    }

    // 4. Without shares, an attacker cannot queue a withdrawal ------------------
    function test_eth_noShares_cannot_queue_withdrawal() public {
        assertEq(IFCNVault(GOFAST_VAULT).balanceOf(attacker), 0, "attacker must own no shares");
        vm.prank(attacker);
        vm.expectRevert(); // ERC20: insufficient allowance/balance
        IProduct(GOFAST).addToWithdrawalQueue(GOFAST_VAULT, 1);
    }

    // 5. Permissionless settlement paths: metadata-only, and frozen ------------
    function test_eth_permissionless_settlement_cannot_move_funds() public {
        uint256 balBefore = _bal(GOFAST);
        uint256 attackerBefore = _bal(attacker);

        // go-fast vault is in Zombie state (8) at the pinned block -> the
        // permissionless settlement entrypoints revert on vault status.
        FCNVaultMeta memory m = IProduct(GOFAST).vaults(GOFAST_VAULT);
        emit log_named_uint("gofast vault status", m.vaultStatus);

        vm.startPrank(attacker);
        vm.expectRevert(bytes("500:WS"));
        IProduct(GOFAST).checkBarriers(GOFAST_VAULT);

        vm.expectRevert(bytes("500:WS"));
        IProduct(GOFAST).calculateCurrentYield(GOFAST_VAULT);

        vm.expectRevert(bytes("500:WS"));
        IProduct(GOFAST).calculateVaultFinalPayoff(GOFAST_VAULT);
        vm.stopPrank();

        assertEq(_bal(GOFAST), balBefore, "product balance unchanged");
        assertEq(_bal(attacker), attackerBefore, "attacker gained nothing");
    }

    function test_eth_oracle_round_push_is_admin_gated_and_frozen() public {
        // oracle rounds are pushed by Cega service admin only
        RoundData memory rd = RoundData({answer: 1, startedAt: block.timestamp, updatedAt: block.timestamp, answeredInRound: 1});
        vm.startPrank(attacker);
        vm.expectRevert(bytes("403:SA"));
        IOracle(ORACLE_BTC).addNextRoundData(rd);
        vm.expectRevert(bytes("403:DA"));
        IOracle(ORACLE_BTC).updateRoundData(0, rd);
        vm.stopPrank();

        (uint80 roundId, int256 answer,, uint256 startedAt, uint80 air) = IOracle(ORACLE_BTC).latestRoundData();
        emit log_named_uint("oracle roundId", roundId);
        emit log_named_int("oracle answer", answer);
        emit log_named_uint("oracle startedAt", startedAt);
        emit log_named_uint("now", block.timestamp);
        emit log_named_uint("answeredInRound", air);
        // The oracle is frozen: last round is far older than the 1-day staleness window,
        // so even permissionless settlement calls that reach an oracle would revert 400:T.
        assertLt(startedAt + 1 days, block.timestamp, "oracle must be stale (>1 day)");
    }

    // 6. Queue accounting (context): 2 withdrawals pending, only trader can pay --
    function test_eth_gofast_pending_withdrawals_trader_gated() public {
        FCNVaultMeta memory m = IProduct(GOFAST).vaults(GOFAST_VAULT);
        emit log_named_uint("queued withdrawal count", m.queuedWithdrawalsCount);
        emit log_named_uint("queued withdrawal shares", m.queuedWithdrawalsSharesAmount);
        emit log_named_uint("vault totalSupply", IFCNVault(GOFAST_VAULT).totalSupply());
        assertGt(m.queuedWithdrawalsCount, 0, "expected pending withdrawals on go-fast vault");
        vm.prank(attacker);
        vm.expectRevert(bytes("403:TA"));
        IProduct(GOFAST).processWithdrawalQueue(GOFAST_VAULT, 10);
    }

    // 7. Registered ETH LOV products + orphan FCN product have the same gates ----
    function test_eth_lov_and_orphan_gates() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(SUPERCHARGER_LOV).sendAssetsToTrade(SCLOV_VAULT, attacker, 1);
        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(SUPERCHARGER_LOV).processWithdrawalQueue(SCLOV_VAULT, 1);
        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(SUPERCHARGER_LOV).collectFees(SCLOV_VAULT);
        vm.expectRevert(bytes("403:TA"));
        IProduct(ORPHAN_FCN).sendAssetsToTrade(ORPHAN_VAULT, attacker, 1);
        vm.expectRevert(bytes("403:TA"));
        IProduct(ORPHAN_FCN).processWithdrawalQueue(ORPHAN_VAULT, 1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFCNVault(SCLOV_VAULT).redeem(1);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFCNVault(ORPHAN_VAULT).redeem(1);
        vm.stopPrank();

        uint256 balBefore = _bal(SUPERCHARGER_LOV);
        FCNVaultMeta memory m = ILOVProduct(SUPERCHARGER_LOV).vaults(SCLOV_VAULT);
        emit log_named_uint("supercharger-lov vault status", m.vaultStatus);
        emit log_named_uint("supercharger-lov vault underlying", m.underlyingAmount);
        vm.prank(attacker);
        vm.expectRevert(bytes("500:WS"));
        ILOVProduct(SUPERCHARGER_LOV).calculateVaultFinalPayoff(SCLOV_VAULT);
        assertEq(_bal(SUPERCHARGER_LOV), balBefore, "balance unchanged");
    }
}

// ---------------------------------------------------------------------------
// Latent-mechanism demonstration (NOT currently exploitable: no live vault is
// in Traded status). Uses vm.prank with a live OPERATOR_ADMIN to create the
// precondition, then shows the unprivileged attacker steps of the keeper race.
// ---------------------------------------------------------------------------
contract CegaV1LatentF1Test is Test {
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant CRUISE = 0x80ec1c0da9bfBB8229A1332D40615C5bA2AbbEA8;
    address constant CRUISE_VAULT = 0xE12Cc7191204f73A49429616AC9b735343efeeFe;
    address constant OPERATOR = 0xcBc9C4dE4D77eCddc297BaF3CBc3f0fe6662B37E; // live OPERATOR_ADMIN on ETH
    address attacker = address(0xA77ACC0);

    function setUp() public {
        string memory rpc = vm.envOr(
            "CEGA_ETH_FORK",
            vm.envOr(
                "BLOCKPI_RPC_URL",
                vm.envOr(
                    "NODEREAL_ETH_RPC_URL",
                    vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://eth.drpc.org")))
                )
            )
        );
        uint256 blk = vm.envOr("CEGA_ETH_BLOCK", uint256(26112349));
        if (blk == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, blk);
        }
    }

    function test_latent_blockKnockIn_mechanism() public {
        // Setup precondition (privileged on a live protocol: the vault is Traded):
        FCNVaultMeta memory m0 = IProduct(CRUISE).vaults(CRUISE_VAULT);
        emit log_named_uint("initial status", m0.vaultStatus);
        vm.prank(OPERATOR);
        IProduct(CRUISE).setVaultStatus(CRUISE_VAULT, 3); // Traded

        // Attacker (unprivileged) front-runs the keeper's post-expiry checkBarriers:
        vm.startPrank(attacker);
        IProduct(CRUISE).calculateCurrentYield(CRUISE_VAULT); // Traded -> TradeExpired

        vm.expectRevert(bytes("500:WS")); // knock-in latch now unreachable
        IProduct(CRUISE).checkBarriers(CRUISE_VAULT);

        uint256 payoff = IProduct(CRUISE).calculateVaultFinalPayoff(CRUISE_VAULT);
        vm.stopPrank();

        FCNVaultMeta memory m1 = IProduct(CRUISE).vaults(CRUISE_VAULT);
        emit log_named_uint("post status", m1.vaultStatus);
        emit log_named_uint("isKnockedIn", m1.isKnockedIn ? 1 : 0);
        emit log_named_uint("underlyingAmount", m1.underlyingAmount);
        emit log_named_uint("vaultFinalPayoff (par + coupon)", payoff);
        emit log_named_uint("coupon", m1.totalCouponPayoff);
        // Even the latent bug does not move tokens by itself: payout is trader-gated.
        assertEq(IERC20(USDC).balanceOf(CRUISE), 3166014302, "no USDC moved by permissionless calls");
        assertFalse(m1.isKnockedIn, "knock-in never latched");
        assertEq(payoff, m1.underlyingAmount + m1.totalCouponPayoff, "100% principal + coupon");
    }
}

contract CegaV1ArbTest is Test {
    address constant USDC = 0xaf88d065e77c8cC2239327C5EDb3A432268e5831;
    address constant STATE = 0xc809B7F21250B1ce0a61b7Fb645AEf5CE7c1B5ed;
    address constant PUPPY_LOV = 0x6A9201Db9222cFb5164cfb8F192903270f8a6e93;
    address constant LOV_VAULT = 0x9b562a38082DF153C863D01f1dADa59DdaD15F81;

    address attacker = address(0xA77ACC0);

    function setUp() public {
        string memory rpc = vm.envOr(
            "CEGA_ARB_FORK", vm.envOr("ARB_RPC_URL", string("https://arb1.arbitrum.io/rpc"))
        );
        uint256 blk = vm.envOr("CEGA_ARB_BLOCK", uint256(0));
        if (blk == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, blk);
        }
    }

    function test_arb_live_custody_snapshot() public {
        emit log_named_uint("fork block", block.number);
        emit log_named_uint("puppy-lov USDC", IERC20(USDC).balanceOf(PUPPY_LOV));
        emit log_named_uint("arb state USDC", IERC20(USDC).balanceOf(STATE));
        assertGt(IERC20(USDC).balanceOf(PUPPY_LOV), 0, "puppy-lov holds USDC");
    }

    function test_arb_value_movers_revert_for_unprivileged() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(PUPPY_LOV).sendAssetsToTrade(LOV_VAULT, attacker, 1);

        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(PUPPY_LOV).processWithdrawalQueue(LOV_VAULT, 1);

        vm.expectRevert(bytes("403:TA"));
        ILOVProduct(PUPPY_LOV).collectFees(LOV_VAULT);

        vm.expectRevert(bytes("403:OA"));
        ILOVProduct(PUPPY_LOV).setVaultStatus(LOV_VAULT, 3);
        vm.stopPrank();
    }

    function test_arb_state_movement_reverts_for_unprivileged() public {
        vm.prank(attacker);
        vm.expectRevert();
        ICegaState(STATE).moveAssetsToProduct("puppy-lov", LOV_VAULT, 1);
    }

    function test_arb_vault_redeem_onlyOwner_and_noShares_queue() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        IFCNVault(LOV_VAULT).redeem(1);

        vm.expectRevert();
        ILOVProduct(PUPPY_LOV).addToWithdrawalQueue(LOV_VAULT, 1);
        vm.stopPrank();
    }

    function test_arb_permissionless_settlement_cannot_move_funds() public {
        uint256 balBefore = IERC20(USDC).balanceOf(PUPPY_LOV);
        FCNVaultMeta memory m = ILOVProduct(PUPPY_LOV).vaults(LOV_VAULT);
        emit log_named_uint("puppy-lov vault status", m.vaultStatus);
        // Vault is DepositsClosed(0) -> settlement entrypoints revert on status.
        vm.startPrank(attacker);
        vm.expectRevert(bytes("500:WS"));
        ILOVProduct(PUPPY_LOV).checkBarriers(LOV_VAULT);
        vm.expectRevert(bytes("500:WS"));
        ILOVProduct(PUPPY_LOV).calculateVaultFinalPayoff(LOV_VAULT);
        vm.stopPrank();
        assertEq(IERC20(USDC).balanceOf(PUPPY_LOV), balBefore, "balance unchanged");
    }
}
