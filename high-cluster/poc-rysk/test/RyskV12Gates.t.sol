// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

/// ============================================================================
/// Rysk V12 — fork PoC: closure proof of every candidate unprivileged
/// extraction path on HyperEVM (999) and Ethereum (1), against live state.
/// No transactions are broadcast anywhere: all calls run inside forks.
///
/// Result summary (see REPORT.md): every money-moving entry point is gated to
/// operator / controller / owner roles; self-service is disabled; the only
/// privileged-custody powers (operator settle/redeem, Safe upgrade) are
/// keyholder-only (P), not reachable by an external unprivileged attacker.
/// ============================================================================

struct MMOperation {
    uint8 operationType; // 0 Deposit, 1 Withdraw, 2 ConductTrade
    address user_1;
    address user_2;
    address asset_1;
    address asset_2;
    uint256 amount_1;
    uint256 amount_2;
    bytes data;
}

struct GammaAction {
    uint8 actionType; // 0 OpenVault ... 7 SettleVault, 8 Redeem
    address owner;
    address secondAddress;
    address asset;
    uint256 vaultId;
    uint256 amount;
    uint256 index;
    bytes data;
}

struct RedeemArgs {
    address receiver;
    address otoken;
    uint256 amount;
}

struct SettleArgs {
    address owner;
    uint256 vaultId;
    address to;
}

struct DepositArgs {
    address owner;
    uint256 vaultId;
    address from;
    address asset;
    uint256 index;
    uint256 amount;
}

struct MintArgs {
    address owner;
    uint256 vaultId;
    address to;
    address otoken;
    uint256 index;
    uint256 amount;
}

interface IMarginPool {
    function transferToUser(address, address, uint256) external;
    function transferToPool(address, address, uint256) external;
    function batchTransferToUser(address[] calldata, address[] calldata, uint256[] calldata) external;
    function batchTransferToPool(address[] calldata, address[] calldata, uint256[] calldata) external;
    function farm(address, address, uint256) external;
    function setFarmer(address) external;
    function owner() external view returns (address);
    function farmer() external view returns (address);
    function addressBook() external view returns (address);
    function getStoredBalance(address) external view returns (uint256);
    function initialize(address, address) external;
    function upgradeTo(address) external;
    function transferProxyOwnership(address) external;
    function proxyOwner() external view returns (address);
}

interface IMMarket {
    function operate(MMOperation[] calldata) external;
    function setOperator(address) external;
    function operator() external view returns (address);
    function owner() external view returns (address);
    function initialize() external;
}

interface IRysk {
    function ingresso_newUserPosition(bytes calldata) external;
    function ingresso_transferAsset(bytes calldata) external;
    function ingresso_OTCTrade(bytes calldata) external;
    function ingresso_OTCTradeBatch(bytes calldata) external;
    function ingresso_redeem(MMOperation[] calldata, GammaAction[] calldata) external;
    function ingresso_settle(GammaAction[] calldata) external;
    function flashLoanRedeem(address, uint256, bytes calldata) external;
    function executeOperation(address, uint256, uint256, address, bytes calldata) external returns (bool);
    function initialize() external;
    function setOperator(address) external;
    function setMarginPool(address) external;
    function setRyskSigner(address) external;
    function setSelfServiceAllowed(bool) external;
    function setMMarket(address) external;
    function operator() external view returns (address);
    function selfServiceAllowed() external view returns (bool);
    function owner() external view returns (address);
}

interface IController {
    function operate(GammaAction[] calldata) external;
    function updateVault(uint8, address, uint256, address, uint256) external;
    function setAuthorizedCaller(address, bool) external;
    function setSystemFullyPaused(bool) external;
    function setSystemPartiallyPaused(bool) external;
    function setFullPauser(address) external;
    function donate(address, uint256) external;
    function initialize(address, address, address) external;
    function authorizedCallers(address) external view returns (bool);
    function owner() external view returns (address);
}

interface IControllerLogic {
    function handleRedeem(RedeemArgs calldata, address) external;
    function handleSettle(SettleArgs calldata) external;
    function handleDepositCollateral(DepositArgs calldata) external;
    function handleMintOtoken(MintArgs calldata, uint256) external;
    function setRedeemTimePeriod(uint256) external;
    function owner() external view returns (address);
}

interface IOracle {
    function setExpiryPrice(address, uint256, uint256) external;
    function disputeExpiryPrice(address, uint256, uint256) external;
    function setStablePrice(address, uint256) external;
    function setDisputer(address) external;
    function owner() external view returns (address);
}

interface IManualPricer {
    function setExpiryPriceInOracle(uint256, uint256) external;
    function setPriceTimeValidity(uint256) external;
    function bot() external view returns (address);
    function owner() external view returns (address);
}

interface IWhitelist {
    function whitelistCollateral(address) external;
    function whitelistProduct(address, address, address, bool) external;
    function whitelistOtoken(address) external;
    function blacklistCollateral(address) external;
    function isWhitelistedCollateral(address) external view returns (bool);
}

interface IOtokenFactory {
    function createOtoken(address, address, address, uint256, uint256, bool, bool) external returns (address);
}

interface IOtoken {
    function mintOtoken(address, uint256) external;
    function burnOtoken(address, uint256) external;
}

interface IAddressBook {
    function owner() external view returns (address);
    function setOracle(address) external;
    function updateImpl(bytes32, address) external;
    function getController() external view returns (address);
}

interface ISafe {
    function getThreshold() external view returns (uint256);
    function getOwners() external view returns (address[] memory);
    function getModulesPaginated(address, uint256) external view returns (address[] memory, address);
    function nonce() external view returns (uint256);
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

/// @notice shared helpers + substring assertions
abstract contract RyskBaseTest is Test {
    address internal constant ATTACKER = address(0x000000000000000000000000000000000000dEaD);
    address internal constant SAFE = 0xAFE32eB89391DFd5900F98857f009477e4423Db4;
    address internal constant OPERATOR = 0x65802CC308aeA8bb913882696c2df6bF23Ff9e48;
    address internal constant RYSK_SIGNER = 0xea1913BF76F544f420a84F3d3fF0d087Cf80C396;

    /// @dev call as ATTACKER; must revert; returns the revert reason (empty if none)
    function _mustRevert(address target, bytes memory data, string memory label) internal returns (string memory reason) {
        vm.prank(ATTACKER);
        (bool ok, bytes memory ret) = target.call(data);
        if (ok) {
            emit log_named_string("EXPLOITABLE - call succeeded", label);
            fail();
        }
        reason = _decodeReason(ret);
        emit log_named_string(string.concat("revert[", label, "]"), reason);
    }

    function _mustRevertAs(address caller, address target, bytes memory data, string memory label)
        internal
        returns (string memory reason)
    {
        vm.prank(caller);
        (bool ok, bytes memory ret) = target.call(data);
        if (ok) {
            emit log_named_string("EXPLOITABLE - call succeeded", label);
            fail();
        }
        reason = _decodeReason(ret);
        emit log_named_string(string.concat("revert[", label, "]"), reason);
    }

    function _decodeReason(bytes memory ret) internal pure returns (string memory) {
        if (ret.length < 68) return "<no reason string>";
        bytes4 sel;
        assembly {
            sel := mload(add(ret, 0x20))
        }
        if (sel != 0x08c379a0) return "<non-string revert>";
        bytes memory data = new bytes(ret.length - 4);
        for (uint256 i = 0; i < data.length; i++) {
            data[i] = ret[i + 4];
        }
        return abi.decode(data, (string));
    }

    function _contains(string memory haystack, string memory needle) internal pure returns (bool) {
        bytes memory h = bytes(haystack);
        bytes memory n = bytes(needle);
        if (n.length == 0 || h.length < n.length) return n.length == 0;
        for (uint256 i = 0; i <= h.length - n.length; i++) {
            bool matchFound = true;
            for (uint256 j = 0; j < n.length; j++) {
                if (h[i + j] != n[j]) {
                    matchFound = false;
                    break;
                }
            }
            if (matchFound) return true;
        }
        return false;
    }

    function _assertReason(string memory reason, string memory expected, string memory label) internal {
        if (!_contains(reason, expected)) {
            emit log_named_string("unexpected revert reason for", label);
            fail();
        }
    }
}

/// ============================================================================
/// HyperEVM (999)
/// ============================================================================
contract RyskHyperEVMGatesTest is RyskBaseTest {
    address internal constant MP = 0x24a44f1dc25540c62c1196FfC297dFC951C91aB4; // MarginPool
    address internal constant RYSK = 0x8C8bcb6D2c0E31c5789253EcC8431cA6209B4E35; // Rysk (RyskHype impl)
    address internal constant MM = 0x691a5fc3a81a144e36c6C4fBCa1fC82843c80d0d; // MMarket
    address internal constant CONTROLLER = 0x84d84e481B49B8Bc5a55f17AaF8181c21A29B212;
    address internal constant CTL_LOGIC = 0x577b846A95711015769452F7f29d8054Cf087964;
    address internal constant ORACLE = 0x664aD80F6891cD663228Dc9d1510a6A5Db57e815;
    address internal constant HYPE_PRICER = 0x2f79DaA7cA3D868a1CEF33841a964b3F19C76451;
    address internal constant WHITELIST = 0xD11429254441eefe066c40C54170b54179521Ba0;
    address internal constant ADDRESS_BOOK = 0xFfCE2d20e0f68dcEDbCE657175684845f9593f34;
    address internal constant FACTORY = 0xD3feD88E2A1723802873e0BB74AB198D01644e18;
    address internal constant USDC = 0xb88339CB7199b77E23DB6E890353E22632Ba630f;
    address internal constant WHYPE = 0x5555555555555555555555555555555555555555;
    address internal constant KHYPE = 0xfD739d4e423301CE9385c1fb8850539D657C296D;
    address internal constant STHYPE = 0xfFaa4a3D97fE9107Cef8a3F48c069F577Ff76cC1;
    address internal constant SAMPLE_OTOKEN = 0x954816c08f8cBa89200d7ccD0844b678bE40eb97;

    function setUp() public {
        vm.createSelectFork(vm.envOr("HYPEREVM_RPC_URL", string("https://rpc.hyperliquid.xyz/evm")));
        emit log_named_uint("HYPEREVM fork block", block.number);
        emit log_named_uint("chainid", block.chainid);
    }

    function test_01_live_state_roles_gates() public {
        assertEq(block.chainid, 999, "fork chain");
        assertEq(IRysk(RYSK).operator(), OPERATOR, "operator is hot EOA");
        assertFalse(IRysk(RYSK).selfServiceAllowed(), "self service must be disabled");
        assertTrue(IController(CONTROLLER).authorizedCallers(RYSK), "Rysk is authorized caller");
        assertFalse(IController(CONTROLLER).authorizedCallers(OPERATOR), "operator is NOT authorized caller");
        assertFalse(IController(CONTROLLER).authorizedCallers(ATTACKER), "attacker is NOT authorized caller");
        assertEq(IMarginPool(MP).farmer(), address(0), "no farmer set");
        assertEq(IAddressBook(ADDRESS_BOOK).owner(), SAFE, "addressbook owner = safe");
        assertEq(IMarginPool(MP).proxyOwner(), ADDRESS_BOOK, "MarginPool proxy owner = AddressBook");
        assertEq(IController(CONTROLLER).owner(), SAFE, "controller owner = safe");
        assertEq(IRysk(RYSK).owner(), SAFE, "Rysk owner = safe");
        assertEq(IMMarket(MM).owner(), SAFE, "MMarket owner = safe");
        assertEq(IMMarket(MM).operator(), RYSK, "MMarket operator = Rysk");

        ISafe s = ISafe(SAFE);
        assertEq(s.getThreshold(), 3, "safe threshold 3");
        assertEq(s.getOwners().length, 5, "safe 3-of-5");
        (address[] memory mods, ) = s.getModulesPaginated(address(1), 10);
        emit log_named_uint("safe modules count", mods.length);
        for (uint256 i = 0; i < mods.length; i++) emit log_named_address("module", mods[i]);

        // live balances — non-zero, non-trivial
        uint256 usdcBal = IERC20(USDC).balanceOf(MP);
        uint256 whypeBal = IERC20(WHYPE).balanceOf(MP);
        uint256 khypeBal = IERC20(KHYPE).balanceOf(MP);
        emit log_named_decimal_uint("MarginPool USDC", usdcBal, 6);
        emit log_named_decimal_uint("MarginPool WHYPE", whypeBal, 18);
        emit log_named_decimal_uint("MarginPool kHYPE", khypeBal, 18);
        assertGt(usdcBal, 1_000_000e6, "USDC balance");
        assertGt(whypeBal, 1_000e18, "WHYPE balance");
        assertGt(khypeBal, 1_000e18, "kHYPE balance");
    }

    function test_02_attacker_cannot_move_marginpool_funds() public {
        string memory r;
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.transferToUser, (USDC, ATTACKER, 1)), "transferToUser");
        _assertReason(r, "Sender is not Controller", "transferToUser");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.transferToPool, (USDC, ATTACKER, 1)), "transferToPool");
        _assertReason(r, "Sender is not Controller", "transferToPool");
        address[] memory a = new address[](1);
        a[0] = USDC;
        address[] memory u = new address[](1);
        u[0] = ATTACKER;
        uint256[] memory am = new uint256[](1);
        am[0] = 1;
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.batchTransferToUser, (a, u, am)), "batchTransferToUser");
        _assertReason(r, "Sender is not Controller", "batchTransferToUser");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.batchTransferToPool, (a, u, am)), "batchTransferToPool");
        _assertReason(r, "Sender is not Controller", "batchTransferToPool");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.farm, (USDC, ATTACKER, 1)), "farm");
        _assertReason(r, "Sender is not farmer", "farm");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.setFarmer, (ATTACKER)), "setFarmer");
        _assertReason(r, "not the owner", "setFarmer");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.upgradeTo, (ATTACKER)), "proxy.upgradeTo");
        _assertReason(r, "", "proxy.upgradeTo");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.transferProxyOwnership, (ATTACKER)), "transferProxyOwnership");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.initialize, (ADDRESS_BOOK, ATTACKER)), "re-initialize");
    }

    function test_03_attacker_cannot_operate_mmarket() public {
        MMOperation[] memory ops = new MMOperation[](0);
        string memory r = _mustRevert(MM, abi.encodeCall(IMMarket.operate, (ops)), "MMarket.operate");
        _assertReason(r, "bad operator", "MMarket.operate");
        // direct token move via craft: operate with withdrawal of someone else's balance also blocked by same gate
        r = _mustRevert(MM, abi.encodeCall(IMMarket.setOperator, (ATTACKER)), "MMarket.setOperator");
        // OZ v5 Ownable reverts with OwnableUnauthorizedAccount() custom error (confirmed in trace)
        r = _mustRevert(MM, abi.encodeCall(IMMarket.initialize, ()), "MMarket.initialize");
    }

    function test_04_attacker_cannot_call_rysk_operator_paths() public {
        string memory r;
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_newUserPosition, (hex"")), "ingresso_newUserPosition");
        _assertReason(r, "bad operator", "ingresso_newUserPosition");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_transferAsset, (hex"")), "ingresso_transferAsset");
        _assertReason(r, "bad operator", "ingresso_transferAsset");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_OTCTrade, (hex"")), "ingresso_OTCTrade");
        _assertReason(r, "bad operator", "ingresso_OTCTrade");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_OTCTradeBatch, (hex"")), "ingresso_OTCTradeBatch");
        _assertReason(r, "bad operator", "ingresso_OTCTradeBatch");
        MMOperation[] memory ops = new MMOperation[](0);
        GammaAction[] memory acts = new GammaAction[](0);
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_redeem, (ops, acts)), "ingresso_redeem");
        _assertReason(r, "bad operator", "ingresso_redeem");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_settle, (acts)), "ingresso_settle");
        _assertReason(r, "bad operator", "ingresso_settle");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.flashLoanRedeem, (USDC, 1, hex"")), "flashLoanRedeem");
        _assertReason(r, "bad operator", "flashLoanRedeem");
        r = _mustRevert(
            RYSK,
            abi.encodeCall(IRysk.executeOperation, (USDC, 1, 0, ATTACKER, hex"")),
            "executeOperation(fake flash loan caller)"
        );
        _assertReason(r, "not flashLoanPool", "executeOperation");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setOperator, (ATTACKER)), "setOperator");
        // OZ v5 Ownable: OwnableUnauthorizedAccount() custom error (no string)
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setMarginPool, (ATTACKER)), "setMarginPool");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setRyskSigner, (ATTACKER)), "setRyskSigner");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setSelfServiceAllowed, (true)), "setSelfServiceAllowed");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.initialize, ()), "re-initialize Rysk");
    }

    function test_05_attacker_cannot_call_gamma_controller() public {
        GammaAction[] memory acts = new GammaAction[](0);
        string memory r = _mustRevert(CONTROLLER, abi.encodeCall(IController.operate, (acts)), "Controller.operate");
        _assertReason(r, "C6", "Controller.operate");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.updateVault, (0, ATTACKER, 1, USDC, 1)), "updateVault");
        _assertReason(r, "C42", "updateVault");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.setAuthorizedCaller, (ATTACKER, true)), "setAuthorizedCaller");
        _assertReason(r, "not the owner", "setAuthorizedCaller");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.setSystemFullyPaused, (true)), "setSystemFullyPaused");
        _assertReason(r, "C1", "setSystemFullyPaused");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.donate, (USDC, 1)), "donate");
        _assertReason(r, "not the owner", "donate");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.initialize, (ADDRESS_BOOK, ATTACKER, ATTACKER)), "re-init controller");
    }

    function test_06_attacker_cannot_call_controller_logic() public {
        string memory r;
        r = _mustRevert(
            CTL_LOGIC,
            abi.encodeCall(IControllerLogic.handleRedeem, (RedeemArgs(ATTACKER, USDC, 1), ATTACKER)),
            "handleRedeem"
        );
        _assertReason(r, "Sender is not Controller", "handleRedeem");
        r = _mustRevert(CTL_LOGIC, abi.encodeCall(IControllerLogic.handleSettle, (SettleArgs(ATTACKER, 1, ATTACKER))), "handleSettle");
        _assertReason(r, "Sender is not Controller", "handleSettle");
        r = _mustRevert(
            CTL_LOGIC,
            abi.encodeCall(IControllerLogic.handleDepositCollateral, (DepositArgs(ATTACKER, 1, ATTACKER, USDC, 0, 1))),
            "handleDepositCollateral"
        );
        _assertReason(r, "Sender is not Controller", "handleDepositCollateral");
        r = _mustRevert(
            CTL_LOGIC,
            abi.encodeCall(IControllerLogic.handleMintOtoken, (MintArgs(ATTACKER, 1, ATTACKER, USDC, 0, 1), 2)),
            "handleMintOtoken"
        );
        _assertReason(r, "Sender is not Controller", "handleMintOtoken");
        r = _mustRevert(CTL_LOGIC, abi.encodeCall(IControllerLogic.setRedeemTimePeriod, (1)), "setRedeemTimePeriod");
        _assertReason(r, "not the owner", "setRedeemTimePeriod");
    }

    function test_07_attacker_cannot_set_oracle_prices() public {
        string memory r = _mustRevert(ORACLE, abi.encodeCall(IOracle.setExpiryPrice, (WHYPE, block.timestamp, 1e8)), "setExpiryPrice");
        _assertReason(r, "not authorized to set expiry price", "setExpiryPrice");
        r = _mustRevert(ORACLE, abi.encodeCall(IOracle.disputeExpiryPrice, (WHYPE, block.timestamp, 1e8)), "disputeExpiryPrice");
        _assertReason(r, "not the disputer", "disputeExpiryPrice");
        r = _mustRevert(ORACLE, abi.encodeCall(IOracle.setStablePrice, (USDC, 1)), "setStablePrice");
        _assertReason(r, "not the owner", "setStablePrice");
        r = _mustRevert(HYPE_PRICER, abi.encodeCall(IManualPricer.setExpiryPriceInOracle, (block.timestamp, 1e8)), "pricer.setExpiryPriceInOracle");
        _assertReason(r, "unauthorized sender", "pricer.setExpiryPriceInOracle");
        r = _mustRevert(HYPE_PRICER, abi.encodeCall(IManualPricer.setPriceTimeValidity, (1)), "pricer.setPriceTimeValidity");
        _assertReason(r, "not the owner", "pricer.setPriceTimeValidity");
        assertEq(IManualPricer(HYPE_PRICER).bot(), OPERATOR, "pricer bot is the operator EOA");
    }

    function test_08_attacker_cannot_config_whitelist_factory_otoken() public {
        string memory r = _mustRevert(WHITELIST, abi.encodeCall(IWhitelist.whitelistCollateral, (ATTACKER)), "whitelistCollateral");
        _assertReason(r, "not the owner", "whitelistCollateral");
        r = _mustRevert(WHITELIST, abi.encodeCall(IWhitelist.whitelistOtoken, (ATTACKER)), "whitelistOtoken");
        _assertReason(r, "not OtokenFactory", "whitelistOtoken");
        // factory only creates products the owner already whitelisted; minting still requires controller
        r = _mustRevert(
            FACTORY,
            abi.encodeCall(IOtokenFactory.createOtoken, (ATTACKER, USDC, USDC, 1e8, block.timestamp + 30 days, false, true)),
            "factory.createOtoken(random product)"
        );
        _assertReason(r, "Unsupported Product", "createOtoken");
        r = _mustRevert(SAMPLE_OTOKEN, abi.encodeCall(IOtoken.mintOtoken, (ATTACKER, 1)), "otoken.mintOtoken");
        _assertReason(r, "Only Controller can mint", "mintOtoken");
        r = _mustRevert(SAMPLE_OTOKEN, abi.encodeCall(IOtoken.burnOtoken, (ATTACKER, 1)), "otoken.burnOtoken");
        _assertReason(r, "Only Controller can burn", "burnOtoken");
    }

    function test_09_stored_balances_and_sthype_excess() public {
        // tracked balances: stored == actual for whitelisted collateral
        uint256 storedUsdc = IMarginPool(MP).getStoredBalance(USDC);
        uint256 actualUsdc = IERC20(USDC).balanceOf(MP);
        assertEq(storedUsdc, actualUsdc, "USDC stored == actual");
        // stHYPE was delisted; the pool holds 647.07 stHYPE that is NOT tracked (stored=0):
        // unreachable for users; recoverable only via owner-set farmer (P) - farmer is 0 today
        uint256 storedSt = IMarginPool(MP).getStoredBalance(STHYPE);
        uint256 actualSt = IERC20(STHYPE).balanceOf(MP);
        emit log_named_decimal_uint("stHYPE stored (pool ledger)", storedSt, 18);
        emit log_named_decimal_uint("stHYPE actual (pool balance)", actualSt, 18);
        assertEq(storedSt, 0, "stHYPE untracked");
        assertGt(actualSt, 0, "stHYPE excess exists");
        assertFalse(IWhitelist(WHITELIST).isWhitelistedCollateral(STHYPE), "stHYPE delisted");
    }

    function test_10_upgrade_paths_are_owner_only() public {
        // TransparentUpgradeableProxy (Rysk): non-admin upgrade falls through and reverts
        string memory r = _mustRevert(RYSK, abi.encodeWithSignature("upgradeTo(address)", ATTACKER), "Rysk upgradeTo");
        r = _mustRevert(RYSK, abi.encodeWithSignature("upgradeToAndCall(address,bytes)", ATTACKER, hex""), "Rysk upgradeToAndCall");
        r = _mustRevert(MM, abi.encodeWithSignature("upgradeTo(address)", ATTACKER), "MMarket upgradeTo");
        // AddressBook is the proxy owner of MarginPool / Controller / ControllerLogic; upgrades onlyOwner (Safe)
        r = _mustRevert(
            ADDRESS_BOOK,
            abi.encodeCall(IAddressBook.updateImpl, (keccak256("MARGIN_POOL"), ATTACKER)),
            "AddressBook.updateImpl(MARGIN_POOL)"
        );
        _assertReason(r, "not the owner", "updateImpl");
        r = _mustRevert(
            ADDRESS_BOOK,
            abi.encodeCall(IAddressBook.updateImpl, (keccak256("CONTROLLER"), ATTACKER)),
            "AddressBook.updateImpl(CONTROLLER)"
        );
        _assertReason(r, "not the owner", "updateImpl");
        r = _mustRevert(ADDRESS_BOOK, abi.encodeCall(IAddressBook.setOracle, (ATTACKER)), "AddressBook.setOracle");
        _assertReason(r, "not the owner", "setOracle");
    }

    function test_11_operator_branch_is_privileged_only() public {
        // The operator address is a single hot EOA; for it, ingresso_settle skips the
        // owner==receiver check entirely (verified source). Demonstrate that the gate
        // opens for the operator (business-level revert only) while it slams shut on
        // everyone else. Impersonation happens only inside the fork.
        GammaAction[] memory acts = new GammaAction[](1);
        acts[0] = GammaAction(7, ATTACKER, ATTACKER, address(0), 1, 1e8, 0, hex"");
        vm.prank(OPERATOR);
        (bool ok, bytes memory ret) = RYSK.call(abi.encodeCall(IRysk.ingresso_settle, (acts)));
        string memory reason = ok ? "<success>" : _decodeReason(ret);
        emit log_named_string("operator ingresso_settle outcome", reason);
        assertFalse(_contains(reason, "bad operator"), "operator must pass the operator gate");
        // and the same payload from an arbitrary address is rejected at the gate
        string memory r2 = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_settle, (acts)), "attacker ingresso_settle");
        _assertReason(r2, "bad operator", "attacker settle");
    }
}

/// ============================================================================
/// Ethereum (1)
/// ============================================================================
contract RyskEthereumGatesTest is RyskBaseTest {
    address internal constant MP = 0x684404F2AEBAD87a6803F13741B1d638Bfe2C671;
    address internal constant RYSK = 0x7A3dDEac7A0AE6dfA9391C764499A3564F3c2AAd;
    address internal constant MM = 0xc01c9EF5de5862354adD9501a29e8765cFF01c32;
    address internal constant CONTROLLER = 0xb293323Daf4E5F1313F7804FE58818f633747d0D;
    address internal constant CTL_LOGIC = 0xC64453119e2728e956F0815447efB1E1eB30Df2d;
    address internal constant ORACLE = 0xC11A4767D83Fb2ab643CFc30288A7eE9690009A7;
    address internal constant WETH_PRICER = 0xb82E16f64fe7bD03cd11eEAD4947FDD65A12cD86;
    address internal constant WHITELIST = 0x6F878AF459A2EBFeE13bc2b047Cc240D5e08540D;
    address internal constant ADDRESS_BOOK = 0x65852e9cf13D1a3F330BE2B95b2c1B4396d562E7;
    address internal constant FACTORY = 0x73ec54AB513055e211e09A0F9CE9758332088f24;
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address internal constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address internal constant SAMPLE_OTOKEN = 0xeD74d48ca89790a1CF59F4e54Aa8aE75a9779089;

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        emit log_named_uint("ETHEREUM fork block", block.number);
        emit log_named_uint("chainid", block.chainid);
    }

    function test_01_live_state_roles_gates() public {
        assertEq(block.chainid, 1, "fork chain");
        assertEq(IRysk(RYSK).operator(), OPERATOR, "operator is hot EOA");
        assertFalse(IRysk(RYSK).selfServiceAllowed(), "self service must be disabled");
        assertTrue(IController(CONTROLLER).authorizedCallers(RYSK), "Rysk is authorized caller");
        assertFalse(IController(CONTROLLER).authorizedCallers(ATTACKER), "attacker is NOT authorized caller");
        assertEq(IMarginPool(MP).farmer(), address(0), "no farmer set");
        assertEq(IAddressBook(ADDRESS_BOOK).owner(), SAFE, "addressbook owner = safe");
        assertEq(IMarginPool(MP).proxyOwner(), ADDRESS_BOOK, "MarginPool proxy owner = AddressBook");
        assertEq(IMMarket(MM).operator(), RYSK, "MMarket operator = Rysk");

        ISafe s = ISafe(SAFE);
        assertEq(s.getThreshold(), 3, "safe threshold 3");
        assertEq(s.getOwners().length, 5, "safe 3-of-5");

        uint256 usdcBal = IERC20(USDC).balanceOf(MP);
        uint256 wbtcBal = IERC20(WBTC).balanceOf(MP);
        emit log_named_decimal_uint("MarginPool USDC", usdcBal, 6);
        emit log_named_decimal_uint("MarginPool WBTC", wbtcBal, 8);
        assertGt(usdcBal, 100_000e6, "USDC balance");
        assertGt(wbtcBal, 1e8, "WBTC balance");
    }

    function test_02_attacker_cannot_move_marginpool_funds() public {
        string memory r = _mustRevert(MP, abi.encodeCall(IMarginPool.transferToUser, (USDC, ATTACKER, 1)), "transferToUser");
        _assertReason(r, "Sender is not Controller", "transferToUser");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.farm, (USDC, ATTACKER, 1)), "farm");
        _assertReason(r, "Sender is not farmer", "farm");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.setFarmer, (ATTACKER)), "setFarmer");
        _assertReason(r, "not the owner", "setFarmer");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.upgradeTo, (ATTACKER)), "proxy.upgradeTo");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.transferProxyOwnership, (ATTACKER)), "transferProxyOwnership");
        r = _mustRevert(MP, abi.encodeCall(IMarginPool.initialize, (ADDRESS_BOOK, ATTACKER)), "re-initialize");
    }

    function test_03_attacker_cannot_operate_mmarket() public {
        MMOperation[] memory ops = new MMOperation[](0);
        string memory r = _mustRevert(MM, abi.encodeCall(IMMarket.operate, (ops)), "MMarket.operate");
        _assertReason(r, "bad operator", "MMarket.operate");
        r = _mustRevert(MM, abi.encodeCall(IMMarket.setOperator, (ATTACKER)), "MMarket.setOperator");
    }

    function test_04_attacker_cannot_call_rysk_operator_paths() public {
        string memory r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_newUserPosition, (hex"")), "ingresso_newUserPosition");
        _assertReason(r, "bad operator", "ingresso_newUserPosition");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_transferAsset, (hex"")), "ingresso_transferAsset");
        _assertReason(r, "bad operator", "ingresso_transferAsset");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_OTCTrade, (hex"")), "ingresso_OTCTrade");
        _assertReason(r, "bad operator", "ingresso_OTCTrade");
        MMOperation[] memory ops = new MMOperation[](0);
        GammaAction[] memory acts = new GammaAction[](0);
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_redeem, (ops, acts)), "ingresso_redeem");
        _assertReason(r, "bad operator", "ingresso_redeem");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_settle, (acts)), "ingresso_settle");
        _assertReason(r, "bad operator", "ingresso_settle");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.flashLoanRedeem, (USDC, 1, hex"")), "flashLoanRedeem");
        _assertReason(r, "bad operator", "flashLoanRedeem");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.executeOperation, (USDC, 1, 0, ATTACKER, hex"")), "executeOperation");
        _assertReason(r, "not flashLoanPool", "executeOperation");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setOperator, (ATTACKER)), "setOperator");
        r = _mustRevert(RYSK, abi.encodeCall(IRysk.setSelfServiceAllowed, (true)), "setSelfServiceAllowed");
    }

    function test_05_attacker_cannot_call_gamma_controller() public {
        GammaAction[] memory acts = new GammaAction[](0);
        string memory r = _mustRevert(CONTROLLER, abi.encodeCall(IController.operate, (acts)), "Controller.operate");
        _assertReason(r, "C6", "Controller.operate");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.updateVault, (0, ATTACKER, 1, USDC, 1)), "updateVault");
        _assertReason(r, "C42", "updateVault");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.setAuthorizedCaller, (ATTACKER, true)), "setAuthorizedCaller");
        _assertReason(r, "not the owner", "setAuthorizedCaller");
        r = _mustRevert(CONTROLLER, abi.encodeCall(IController.donate, (USDC, 1)), "donate");
        _assertReason(r, "not the owner", "donate");
    }

    function test_06_attacker_cannot_call_controller_logic() public {
        string memory r = _mustRevert(
            CTL_LOGIC,
            abi.encodeCall(IControllerLogic.handleRedeem, (RedeemArgs(ATTACKER, USDC, 1), ATTACKER)),
            "handleRedeem"
        );
        _assertReason(r, "Sender is not Controller", "handleRedeem");
        r = _mustRevert(CTL_LOGIC, abi.encodeCall(IControllerLogic.handleSettle, (SettleArgs(ATTACKER, 1, ATTACKER))), "handleSettle");
        _assertReason(r, "Sender is not Controller", "handleSettle");
    }

    function test_07_attacker_cannot_set_oracle_prices() public {
        string memory r = _mustRevert(ORACLE, abi.encodeCall(IOracle.setExpiryPrice, (WETH, block.timestamp, 1e8)), "setExpiryPrice");
        _assertReason(r, "not authorized to set expiry price", "setExpiryPrice");
        r = _mustRevert(ORACLE, abi.encodeCall(IOracle.disputeExpiryPrice, (WETH, block.timestamp, 1e8)), "disputeExpiryPrice");
        _assertReason(r, "not the disputer", "disputeExpiryPrice");
        r = _mustRevert(WETH_PRICER, abi.encodeCall(IManualPricer.setExpiryPriceInOracle, (block.timestamp, 1e8)), "pricer.setExpiryPriceInOracle");
        _assertReason(r, "unauthorized sender", "pricer.setExpiryPriceInOracle");
        assertEq(IManualPricer(WETH_PRICER).bot(), OPERATOR, "pricer bot is the operator EOA");
    }

    function test_08_attacker_cannot_config_whitelist_factory_otoken() public {
        string memory r = _mustRevert(WHITELIST, abi.encodeCall(IWhitelist.whitelistCollateral, (ATTACKER)), "whitelistCollateral");
        _assertReason(r, "not the owner", "whitelistCollateral");
        r = _mustRevert(WHITELIST, abi.encodeCall(IWhitelist.whitelistOtoken, (ATTACKER)), "whitelistOtoken");
        _assertReason(r, "not OtokenFactory", "whitelistOtoken");
        r = _mustRevert(
            FACTORY,
            abi.encodeCall(IOtokenFactory.createOtoken, (ATTACKER, USDC, USDC, 1e8, block.timestamp + 30 days, false, true)),
            "factory.createOtoken(random product)"
        );
        _assertReason(r, "Unsupported Product", "createOtoken");
        r = _mustRevert(SAMPLE_OTOKEN, abi.encodeCall(IOtoken.mintOtoken, (ATTACKER, 1)), "otoken.mintOtoken");
        _assertReason(r, "Only Controller can mint", "mintOtoken");
    }

    function test_09_upgrade_paths_are_owner_only() public {
        string memory r = _mustRevert(RYSK, abi.encodeWithSignature("upgradeTo(address)", ATTACKER), "Rysk upgradeTo");
        r = _mustRevert(MM, abi.encodeWithSignature("upgradeTo(address)", ATTACKER), "MMarket upgradeTo");
        r = _mustRevert(
            ADDRESS_BOOK,
            abi.encodeCall(IAddressBook.updateImpl, (keccak256("MARGIN_POOL"), ATTACKER)),
            "AddressBook.updateImpl(MARGIN_POOL)"
        );
        _assertReason(r, "not the owner", "updateImpl");
        r = _mustRevert(ADDRESS_BOOK, abi.encodeCall(IAddressBook.setOracle, (ATTACKER)), "AddressBook.setOracle");
        _assertReason(r, "not the owner", "setOracle");
    }

    function test_10_operator_branch_is_privileged_only() public {
        GammaAction[] memory acts = new GammaAction[](1);
        acts[0] = GammaAction(7, ATTACKER, ATTACKER, address(0), 1, 1e8, 0, hex"");
        vm.prank(OPERATOR);
        (bool ok, bytes memory ret) = RYSK.call(abi.encodeCall(IRysk.ingresso_settle, (acts)));
        string memory reason = ok ? "<success>" : _decodeReason(ret);
        emit log_named_string("operator ingresso_settle outcome", reason);
        assertFalse(_contains(reason, "bad operator"), "operator must pass the operator gate");
        string memory r2 = _mustRevert(RYSK, abi.encodeCall(IRysk.ingresso_settle, (acts)), "attacker ingresso_settle");
        _assertReason(r2, "bad operator", "attacker settle");
    }
}
