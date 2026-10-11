// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IWrapLike, IERC20Like, TokenInfo, MultisigConfig, RequestInfo} from "../src/Enosys.sol";

/// Enosys Bridge (Flare Finance "Wrap") — Ethereum custody ends.
/// Fork tests: (a) prove every fund-releasing path is gated to validator
/// quorum / timelocked admin, (b) quantify the privileged drain path.
/// Read-only research; no mainnet transactions are ever sent.
contract EnosysBridgeTest is Test {
    // ---- Ethereum custody contracts (WrapDepositRedeem, byte-identical 10537B) ----
    IWrapLike constant BRIDGE_A = IWrapLike(0x8936761F2903ED1aF2B269E6fa3a79ebb0162C51); // ETH<->Songbird
    IWrapLike constant BRIDGE_B = IWrapLike(0x37aca97A99d1B4260a5E9821d0Ef14947fB68970); // ETH<->Flare

    // ---- tokens ----
    IERC20Like constant USDT = IERC20Like(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    IERC20Like constant WETH = IERC20Like(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    IERC20Like constant QNT  = IERC20Like(0x4a220E6096B25EADb88358cb44068A3248254675);
    address constant EX_USDT = 0x1a7b46656B2b8b29B1694229e122d066020503D0; // Songbird mirror of USDT
    address constant E_USDT = 0x96B41289D90444B8adD57e6F265DB5aE8651DF29; // Flare mirror of USDT

    // ---- live role holders (verified at block 26,171,961) ----
    address constant ADMIN_ETH = 0x4352A8DDD60762E1b0B0fE154B176C79E0af5E88; // OZ TimelockController, 4-day delay
    address constant WEAK_ETH = 0x3223f88BEaF7a0EE4E9F149913709b3b61be4668; // GnosisSafeProxy 2-of-3
    address constant PAUSE_A = 0xB6872c7190203B453750b694faE0e6CC794d7A73; // EOA

    // ---- active validators (live, verified via validatorInfo + Add/RemoveSigner logs) ----
    address constant A1 = 0x4370b2b6cEBE373Ebbe84e2E0EEC5761af651E41; // committee 1
    address constant A2 = 0xE027978fFBFFA3C35B20328efb13d7001F69F84c; // committee 2
    address constant A_REMOVED = 0x8AE8cbbb85B8B83D146Be42987aEEc0835fC466f; // removed 2025
    address constant B1 = 0x90bc0578Ec8966Fc868E46f76220eb14D004c136; // committee 1
    address constant B2 = 0x600BF80C72A4E32354cEf106cD9ddF04737dcA96; // committee 2
    address constant B3 = 0xB0e09f188c2eaDE40C5a94967bc4fBfA7E831AA5; // committee 2

    address constant ATTACKER = address(0xA11CE);
    address constant FEE_RECIPIENT_A1 = 0x4eC38Cf39bA033b994db0B8c86F999fda6EB0A8D;

    bytes32 constant DEFAULT_ADMIN = bytes32(0);
    bytes32 constant PAUSE_ROLE = keccak256("PAUSE");
    bytes32 constant WEAK_ADMIN_ROLE = keccak256("WEAK_ADMIN");

    uint8 constant ST_UNINIT = 0;
    uint8 constant ST_REMOVED = 1;
    uint8 constant ST_C1 = 2;
    uint8 constant ST_C2 = 3;

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com"));
        forkBlock = vm.createSelectFork(rpc);
        vm.deal(ATTACKER, 10 ether);
    }

    // ---------------------------------------------------------------- helpers

    function _recentBlockhash() internal view returns (bytes32 bh, uint256 bn) {
        bn = block.number - 1;
        bh = blockhash(bn);
    }

    function _hash(
        uint256 id,
        address mirrorToken,
        uint256 amount,
        address to
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(id, mirrorToken, amount, to));
    }

    function _slot8(IWrapLike b) internal view returns (uint8 q1, uint8 q2, uint8 s1, uint8 s2) {
        uint256 v = uint256(vm.load(address(b), bytes32(uint256(8))));
        q1 = uint8(v & 0xff);
        q2 = uint8((v >> 8) & 0xff);
        s1 = uint8((v >> 16) & 0xff);
        s2 = uint8((v >> 24) & 0xff);
    }

    // ---------------------------------------------------------------- live state

    function test_eth8936_live_state() public view {
        assertEq(BRIDGE_A.paused(), false, "not paused");
        assertEq(BRIDGE_A.migratedContract(), address(0), "not migrated");
        assertEq(BRIDGE_A.validatorFeeBPS(), 250, "2.5% validator fee");
        (uint8 q1, uint8 q2, uint8 s1, uint8 s2) = _slot8(BRIDGE_A);
        assertEq(q1, 1, "quorum c1 = 1");
        assertEq(q2, 1, "quorum c2 = 1");
        assertEq(s1, 2, "committee1 size");
        assertEq(s2, 4, "committee2 size");
        // active set = 1 + 1 after 2025 removals
        (uint8 st, ) = BRIDGE_A.validatorInfo(A1);
        assertEq(uint256(st), uint256(ST_C1), "A1 active c1");
        (st, ) = BRIDGE_A.validatorInfo(A2);
        assertEq(uint256(st), uint256(ST_C2), "A2 active c2");
        (st, ) = BRIDGE_A.validatorInfo(A_REMOVED);
        assertEq(uint256(st), uint256(ST_REMOVED), "removed validator cannot sign");
        assertEq(BRIDGE_A.mirrorTokens(EX_USDT), address(USDT), "exUSDT -> USDT mapping");
        assertGt(USDT.balanceOf(address(BRIDGE_A)), 100_000e6, "USDT custody live");
        assertGt(WETH.balanceOf(address(BRIDGE_A)), 10 ether, "WETH custody live");
        assertLe(BRIDGE_A.nextExecutionIndex(), BRIDGE_A.depositIndex(), "executions <= deposits");
        assertEq(BRIDGE_A.getRoleMemberCount(WEAK_ADMIN_ROLE), 1, "single weak-admin");
    }

    function test_eth37ac_live_state() public view {
        assertEq(BRIDGE_B.paused(), false);
        assertEq(BRIDGE_B.validatorFeeBPS(), 250);
        (uint8 q1, uint8 q2, uint8 s1, uint8 s2) = _slot8(BRIDGE_B);
        assertEq(q1, 1);
        assertEq(q2, 1);
        assertEq(s1, 2);
        assertEq(s2, 5);
        (uint8 st, ) = BRIDGE_B.validatorInfo(B1);
        assertEq(uint256(st), uint256(ST_C1), "B1 active c1");
        (st, ) = BRIDGE_B.validatorInfo(B2);
        assertEq(uint256(st), uint256(ST_C2), "B2 active c2");
        (st, ) = BRIDGE_B.validatorInfo(B3);
        assertEq(uint256(st), uint256(ST_C2), "B3 active c2");
        assertEq(BRIDGE_B.mirrorTokens(E_USDT), address(USDT), "eUSDT -> USDT");
        assertGt(USDT.balanceOf(address(BRIDGE_B)), 40_000e6);
        assertGt(WETH.balanceOf(address(BRIDGE_B)), 20 ether);
        assertGt(QNT.balanceOf(address(BRIDGE_B)), 600e18);
    }

    // ---------------------------------------------------------------- E-U gates

    function test_attacker_cannot_approve_execute() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        assertTrue(bh != bytes32(0), "fork must serve recent blockhash");

        uint256 id = BRIDGE_A.nextExecutionIndex();
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(IWrapLike.SignerNotActive.selector, ATTACKER));
        BRIDGE_A.approveExecute(id, EX_USDT, 1e6, ATTACKER, bh, bn);

        RequestInfo[] memory reqs = new RequestInfo[](1);
        reqs[0] = RequestInfo(id, EX_USDT, 1e6, ATTACKER);
        vm.prank(ATTACKER);
        vm.expectRevert(abi.encodeWithSelector(IWrapLike.SignerNotActive.selector, ATTACKER));
        BRIDGE_A.batchApproveExecute(reqs, bh, bn);
    }

    function test_removed_validator_cannot_approve() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 id = BRIDGE_A.nextExecutionIndex();
        vm.prank(A_REMOVED);
        vm.expectRevert(abi.encodeWithSelector(IWrapLike.SignerNotActive.selector, A_REMOVED));
        BRIDGE_A.approveExecute(id, EX_USDT, 1e6, ATTACKER, bh, bn);
    }

    function test_old_blockhash_rejected() public {
        // blockhash(block.number-300) == 0 -> InvalidBlockHash, even for a validator
        uint256 id = BRIDGE_A.nextExecutionIndex();
        vm.prank(A1);
        vm.expectRevert(IWrapLike.InvalidBlockHash.selector);
        BRIDGE_A.approveExecute(id, EX_USDT, 1e6, ATTACKER, bytes32(0), block.number - 300);
    }

    function test_attacker_cannot_admin() public {
        // OZ 4.7 AccessControl reverts with a string using lowercase hex formatting
        string memory a = "0x00000000000000000000000000000000000a11ce";
        string memory missingWeak = string.concat(
            "AccessControl: account ",
            a,
            " is missing role ",
            vm.toString(WEAK_ADMIN_ROLE)
        );
        string memory missingAdmin = string.concat(
            "AccessControl: account ",
            a,
            " is missing role ",
            vm.toString(DEFAULT_ADMIN)
        );
        string memory missingPause = string.concat(
            "AccessControl: account ",
            a,
            " is missing role ",
            vm.toString(PAUSE_ROLE)
        );
        TokenInfo memory ti = TokenInfo(1e6, 1e6, 1e6);

        vm.startPrank(ATTACKER);
        vm.expectRevert(bytes(missingPause));
        BRIDGE_A.pause();

        vm.expectRevert(bytes(missingWeak));
        BRIDGE_A.unpause();

        vm.expectRevert(bytes(missingWeak));
        BRIDGE_A.configureToken(address(USDT), ti);

        vm.expectRevert(bytes(missingAdmin));
        BRIDGE_A.addToken(address(USDT), address(USDT), ti);

        vm.expectRevert(bytes(missingAdmin));
        BRIDGE_A.configureMultisig(MultisigConfig(1, 1));

        vm.expectRevert(bytes(missingAdmin));
        BRIDGE_A.addValidator(ATTACKER, true, ATTACKER);

        vm.expectRevert(bytes(missingWeak));
        BRIDGE_A.removeValidator(A1);

        vm.expectRevert(bytes(missingAdmin));
        BRIDGE_A.forceSetNextExecutionIndex(type(uint256).max);

        // migrate requires paused first (modifier order: isPaused -> notMigrated -> admin)
        vm.expectRevert(IWrapLike.ContractNotPaused.selector);
        BRIDGE_A.migrate(ATTACKER);
        vm.stopPrank();
    }

    function test_no_user_withdrawal_function() public {
        // The custody contracts expose no user refund/withdraw path.
        vm.startPrank(ATTACKER);
        (bool ok, ) = address(BRIDGE_A).call(abi.encodeWithSignature("withdraw(uint256)", 0));
        assertFalse(ok, "no withdraw()");
        (ok, ) = address(BRIDGE_A).call(abi.encodeWithSignature("refund(uint256)", 0));
        assertFalse(ok, "no refund()");
        (ok, ) = address(BRIDGE_A).call(abi.encodeWithSignature("redeem(uint256)", 0));
        assertFalse(ok, "no redeem()");
        vm.stopPrank();
    }

    // ---------------------------------------------------------------- quorum math

    function test_single_validator_cannot_execute() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 id = BRIDGE_A.nextExecutionIndex();
        uint256 amount = USDT.balanceOf(address(BRIDGE_A));
        uint256 bridgeBefore = amount;
        uint256 attackerBefore = USDT.balanceOf(ATTACKER);

        // committee-1 key alone: quorum 1-of-2 AND 1-of-4 -> needs a c2 key too
        vm.prank(A1);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);

        (, uint16 cnt) = BRIDGE_A.attesters(_hash(id, EX_USDT, amount, ATTACKER));
        assertEq(cnt, 1, "only 1 attester");
        assertEq(USDT.balanceOf(ATTACKER), attackerBefore, "no funds moved");
        assertEq(USDT.balanceOf(address(BRIDGE_A)), bridgeBefore, "bridge balance intact");
        assertEq(BRIDGE_A.nextExecutionIndex(), id, "not executed");

        // duplicate approval from the same signer does not double count
        vm.prank(A1);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);
        (, cnt) = BRIDGE_A.attesters(_hash(id, EX_USDT, amount, ATTACKER));
        assertEq(cnt, 1, "dup approval ignored");
    }

    /// P-scenario quantification: 2 compromised validator keys (1 per committee)
    /// drain the whole custody. Not an unprivileged path; proves the P ceiling.
    function test_two_validators_drain_eth8936_and_replay_is_noop() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 id = BRIDGE_A.nextExecutionIndex();
        uint256 amount = USDT.balanceOf(address(BRIDGE_A));
        uint256 attackerBefore = USDT.balanceOf(ATTACKER);

        vm.prank(A1);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);
        vm.prank(A2);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);

        uint256 fee = (amount * 250) / 10_000;
        assertEq(USDT.balanceOf(ATTACKER), attackerBefore + amount - fee, "drain net of 2.5% fee");
        // the fee share stays in the contract until claimValidatorFees
        assertEq(USDT.balanceOf(address(BRIDGE_A)), fee, "only validator fees remain");
        assertEq(BRIDGE_A.nextExecutionIndex(), id + 1, "id consumed");

        // replay of the executed request is a no-op (id < nextExecutionIndex)
        vm.prank(A1);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);
        vm.prank(A2);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, ATTACKER, bh, bn);
        assertEq(USDT.balanceOf(ATTACKER), attackerBefore + amount - fee, "no double spend");

        // accrued validator fees are claimable, but only by the fee recipient
        uint256 expUsdtFee = BRIDGE_A.feeBalance(address(USDT), 4);
        uint256 recBefore = USDT.balanceOf(FEE_RECIPIENT_A1);
        uint256 attackerAfterDrain = USDT.balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        BRIDGE_A.claimValidatorFees(A1);
        assertEq(USDT.balanceOf(FEE_RECIPIENT_A1), recBefore + expUsdtFee, "fees -> feeRecipient, not caller");
        assertEq(USDT.balanceOf(ATTACKER), attackerAfterDrain, "caller gains nothing");
    }

    function test_two_of_three_validators_drain_eth37ac() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 id = BRIDGE_B.nextExecutionIndex();
        uint256 amount = USDT.balanceOf(address(BRIDGE_B));
        uint256 attackerBefore = USDT.balanceOf(ATTACKER);

        vm.prank(B1);
        BRIDGE_B.approveExecute(id, E_USDT, amount, ATTACKER, bh, bn);
        vm.prank(B2);
        BRIDGE_B.approveExecute(id, E_USDT, amount, ATTACKER, bh, bn);

        uint256 fee = (amount * 250) / 10_000;
        assertEq(USDT.balanceOf(ATTACKER), attackerBefore + amount - fee, "drain net of fee");
        assertEq(USDT.balanceOf(address(BRIDGE_B)), fee, "only validator fees remain");
    }

    // ---------------------------------------------------------------- unprivileged actions that exist

    function test_deposit_is_permissionless_but_only_moves_funds_in() public {
        uint256 amount = 1 ether;
        deal(address(WETH), ATTACKER, amount);
        uint256 bridgeBefore = WETH.balanceOf(address(BRIDGE_A));
        uint256 idBefore = BRIDGE_A.depositIndex();

        vm.startPrank(ATTACKER);
        WETH.approve(address(BRIDGE_A), amount);
        uint256 id = BRIDGE_A.deposit(address(WETH), amount, ATTACKER);
        vm.stopPrank();

        assertEq(id, idBefore, "sequential id");
        assertEq(BRIDGE_A.depositIndex(), idBefore + 1, "deposit counted");
        assertEq(WETH.balanceOf(address(BRIDGE_A)), bridgeBefore + amount, "funds moved IN only");
        assertEq(WETH.balanceOf(ATTACKER), 0, "attacker paid");
    }

    // ---------------------------------------------------------------- structural checks

    /// No proxy / no upgrade path: EIP-1967 slots are zero and both custody
    /// contracts carry the same immutable 10,537-byte bytecode.
    function test_no_proxy_and_immutable_code() public view {
        bytes32 implSlot = 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
        bytes32 adminSlot = 0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
        bytes32 beaconSlot = 0xa3f0ad74e5423aebfd80d3ef4346578335a9a72aeaee59ff6cb3582b35133d50;
        for (uint256 i = 0; i < 2; i++) {
            address b = i == 0 ? address(BRIDGE_A) : address(BRIDGE_B);
            assertEq(uint256(vm.load(b, implSlot)), 0, "no implementation slot");
            assertEq(uint256(vm.load(b, adminSlot)), 0, "no proxy admin slot");
            assertEq(uint256(vm.load(b, beaconSlot)), 0, "no beacon slot");
            assertEq(b.code.length, 10537, "immutable bytecode size");
        }
    }

    /// The custody contracts never approve any spender: no residual allowances
    /// on the canonical routers / Permit2 / 1inch.
    function test_no_token_allowances_granted() public view {
        address[5] memory spenders = [
            0x000000000022D473030F116dDEE9F6B43aC78BA3, // Permit2
            0x1111111254EEB25477B68fb85Ed929f73A960582, // 1inch
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D, // UniV2 router
            0xE592427A0AEce92De3Edee1F18E0157C05861564, // UniV3 router
            0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F // Sushi router
        ];
        for (uint256 i = 0; i < spenders.length; i++) {
            assertEq(USDT.allowance(address(BRIDGE_A), spenders[i]), 0, "A USDT allowance");
            assertEq(WETH.allowance(address(BRIDGE_A), spenders[i]), 0, "A WETH allowance");
            assertEq(USDT.allowance(address(BRIDGE_B), spenders[i]), 0, "B USDT allowance");
            assertEq(WETH.allowance(address(BRIDGE_B), spenders[i]), 0, "B WETH allowance");
            assertEq(QNT.allowance(address(BRIDGE_B), spenders[i]), 0, "B QNT allowance");
        }
    }

    /// Admin structure live on mainnet: DEFAULT_ADMIN is a 4-day TimelockController,
    /// WEAK_ADMIN is a 2-of-3 Gnosis Safe, PAUSE is a single EOA.
    function test_admin_roles_are_timelocked_and_safe() public view {
        (bool ok, bytes memory ret) = ADMIN_ETH.staticcall(abi.encodeWithSignature("getMinDelay()"));
        assertTrue(ok, "admin is a contract with getMinDelay");
        assertEq(abi.decode(ret, (uint256)), 345600, "4-day timelock delay");
        (ok, ret) = WEAK_ETH.staticcall(abi.encodeWithSignature("getThreshold()"));
        assertTrue(ok, "weak admin is a Safe");
        assertEq(abi.decode(ret, (uint256)), 2, "Safe threshold 2");
        assertEq(PAUSE_A.code.length, 0, "pause key is an EOA");
    }

    // ---------------------------------------------------------------- negative paths

    /// A quorum cannot execute an unregistered mirror token: mirrorTokens[mirror]
    /// is zero, so onExecute hits address(0) and SafeERC20 reverts.
    function test_unregistered_mirror_token_execution_reverts() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 id = BRIDGE_A.nextExecutionIndex();
        address fakeMirror = address(0xF00D);
        vm.prank(A1);
        BRIDGE_A.approveExecute(id, fakeMirror, 1e6, ATTACKER, bh, bn);
        vm.prank(A2);
        vm.expectRevert();
        BRIDGE_A.approveExecute(id, fakeMirror, 1e6, ATTACKER, bh, bn);
    }

    /// Execution of an already-accepted request is permissionless (tryApprove
    /// returns early for Accepted requests, before the signer check). Funds can
    /// only ever go to the quorum-approved `to`, so the pusher gains nothing —
    /// but any third party can advance the queue.
    function test_accepted_request_can_be_pushed_by_anyone() public {
        (bytes32 bh, uint256 bn) = _recentBlockhash();
        uint256 n = BRIDGE_A.nextExecutionIndex();
        address recipient = address(0xBEEF);
        uint256 amt2 = 500e6;

        // validators accept the out-of-order request n+1 first
        vm.prank(A1);
        BRIDGE_A.approveExecute(n + 1, EX_USDT, amt2, recipient, bh, bn);
        vm.prank(A2);
        BRIDGE_A.approveExecute(n + 1, EX_USDT, amt2, recipient, bh, bn);

        // then the current request n, which executes and advances the index
        vm.prank(A1);
        BRIDGE_A.approveExecute(n, EX_USDT, 1000e6, ATTACKER, bh, bn);
        vm.prank(A2);
        BRIDGE_A.approveExecute(n, EX_USDT, 1000e6, ATTACKER, bh, bn);
        assertEq(BRIDGE_A.nextExecutionIndex(), n + 1);

        // the attacker is not a signer, yet pushes n+1
        uint256 before = USDT.balanceOf(recipient);
        vm.prank(ATTACKER);
        BRIDGE_A.approveExecute(n + 1, EX_USDT, amt2, recipient, bh, bn);
        uint256 fee = (amt2 * 250) / 10_000;
        assertEq(USDT.balanceOf(recipient), before + amt2 - fee, "goes to approved recipient");
        assertEq(BRIDGE_A.nextExecutionIndex(), n + 2);
    }

    /// Even the DEFAULT_ADMIN cannot lower nextExecutionIndex, so executed ids
    /// can never be replayed through the admin surface.
    function test_force_set_next_index_cannot_lower() public {
        uint256 next = BRIDGE_A.nextExecutionIndex();
        vm.prank(ADMIN_ETH);
        vm.expectRevert(IWrapLike.InvalidNextExecutionIndex.selector);
        BRIDGE_A.forceSetNextExecutionIndex(next - 1);
    }

    /// P-ceiling: one DEFAULT_ADMIN key (TimelockController) installs two
    /// attacker validators (one per committee) and the full custody is drained.
    function test_admin_timelock_can_install_validators_and_drain() public {
        address AT1 = address(0xA11CE1);
        address AT2 = address(0xA11CE2);
        (bytes32 bh, uint256 bn) = _recentBlockhash();

        // before the admin acts, the attacker keys are not signers
        uint256 nextId = BRIDGE_A.nextExecutionIndex();
        vm.prank(AT1);
        vm.expectRevert(abi.encodeWithSelector(IWrapLike.SignerNotActive.selector, AT1));
        BRIDGE_A.approveExecute(nextId, EX_USDT, 1e6, AT1, bh, bn);

        // DEFAULT_ADMIN (TimelockController; 4-day delay on mainnet) adds them
        vm.startPrank(ADMIN_ETH);
        BRIDGE_A.addValidator(AT1, true, AT1);
        BRIDGE_A.addValidator(AT2, false, AT2);
        vm.stopPrank();

        uint256 amount = USDT.balanceOf(address(BRIDGE_A));
        uint256 id = BRIDGE_A.nextExecutionIndex();
        vm.prank(AT1);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, AT1, bh, bn);
        vm.prank(AT2);
        BRIDGE_A.approveExecute(id, EX_USDT, amount, AT1, bh, bn);

        uint256 fee = (amount * 250) / 10_000;
        assertEq(USDT.balanceOf(AT1), amount - fee, "admin-installed quorum drains custody");
    }

    /// DoS surface: a single PAUSE EOA can stop the bridge; only the 2-of-3 Safe
    /// (WEAK_ADMIN) can unpause.
    function test_single_pause_key_can_stop_the_bridge() public {
        vm.prank(PAUSE_A);
        BRIDGE_A.pause();
        assertTrue(BRIDGE_A.paused());

        deal(address(WETH), ATTACKER, 1 ether);
        vm.startPrank(ATTACKER);
        WETH.approve(address(BRIDGE_A), 1 ether);
        vm.expectRevert(IWrapLike.ContractPaused.selector);
        BRIDGE_A.deposit(address(WETH), 1 ether, ATTACKER);
        vm.expectRevert();
        BRIDGE_A.unpause();
        vm.stopPrank();

        vm.prank(WEAK_ETH);
        BRIDGE_A.unpause();
        assertFalse(BRIDGE_A.paused());
    }
}
