// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {
    IERC20,
    Types,
    IEndpoint,
    IClearinghouse,
    IWithdrawPool,
    IVerifier,
    ISpotEngine,
    IPerpEngine,
    IOffchainExchange,
    IQuerier
} from "../src/Nado.sol";

/// @title Nado (Ink) — on-chain extraction-path fork tests (read-only over live code).
/// @notice Every test executes against a fork of Ink mainnet (chain 57073). No mainnet
///         transactions are ever sent; state is only mutated inside the fork.
///         Addresses and roles re-verified on-chain in test_live_state_and_role_wiring().
contract NadoForkTest is Test {
    // ------------------------------------------------------------------
    // Live Ink (57073) addresses (verified at block 58,133,941+; see REPORT.md)
    // ------------------------------------------------------------------
    address constant USDT0 = 0x0200C29006150606B650577BBE7B6248F58470c1; // Quote, 6dp
    address constant ENDPOINT = 0x05ec92D78ED421f3D3Ada77FFdE167106565974E;
    address constant CLEARINGHOUSE = 0xD218103918C19D0A10cf35300E4CfAfbD444c5fE;
    address constant WITHDRAWPOOL = 0x09fb495AA7859635f755E827d64c4C9A2e5b9651;
    address constant VERIFIER = 0x9aCdC66459A323Fbb6eB77C5AA96a30234feCf17;
    address constant SPOTENGINE = 0xFcD94770B95fd9Cc67143132BB172EB17A0907fE;
    address constant PERPENGINE = 0xF8599D58d1137fC56EcDd9C16ee139C8BDf96da1;
    address constant OFFCHAINEXCHANGE = 0x8373C3Aa04153aBc0cfD28901c3c971a946994ab;
    address constant QUERIER = 0x68798229F88251b31D534733D6C4098318c9dff8;

    address constant USDT0_WHALE = 0x2D27Bf7AD3303bDCF341C5890296Ad8B49D68829; // 5.47M USDT0 holder
    address constant EXPECTED_OWNER = 0x8e57461DFF61215643aCf28Ef1884EcC7443AD17;
    address constant EXPECTED_SEQUENCER = 0xA875966f05d2b4149CD889aAB7D93Fe8252C633A;

    uint256 constant SECP256K1_Q =
        0xFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFEBAAEDCE6AF48A03BBFD25E8CD0364141;
    uint256 constant SLOW_MODE_DELAY = 3 days;
    uint256 constant SLOW_MODE_FEE = 1e6; // $1.00 USDT0 (6dp)

    bytes32 constant DOMAIN_TYPEHASH =
        keccak256(
            "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
        );
    bytes32 constant SIGNED_TX_TYPEHASH =
        keccak256("SignedTransaction(uint64 idx,bytes transaction)");

    // IEndpoint.TransactionType ids
    uint8 constant T_DEPOSIT = 1;
    uint8 constant T_WITHDRAW = 2;
    uint8 constant T_DUMP_FEES = 9;
    uint8 constant T_WITHDRAW_INSURANCE = 18;
    uint8 constant T_WITHDRAW_V2 = 32;

    address alice;
    uint256 alicePk;
    address bob;
    uint256 bobPk;
    bytes32 aliceSub;
    bytes32 bobSub;

    function setUp() public {
        vm.createSelectFork(
            vm.envOr("INK_RPC_URL", string("https://rpc-gel.inkonchain.com"))
        );
        emit log_named_uint("fork_block", block.number);
        emit log_named_uint("fork_chainid", block.chainid);
        (alice, alicePk) = makeAddrAndKey("alice");
        (bob, bobPk) = makeAddrAndKey("bob");
        aliceSub = _sub(alice, "alice");
        bobSub = _sub(bob, "bob");
    }

    // ------------------------------------------------------------------
    // 1. Live state / role wiring / signer set
    // ------------------------------------------------------------------
    function test_live_state_and_role_wiring() public {
        assertGt(ENDPOINT.code.length, 0, "endpoint code");
        assertGt(CLEARINGHOUSE.code.length, 0, "clearinghouse code");
        assertGt(WITHDRAWPOOL.code.length, 0, "withdrawpool code");
        assertGt(VERIFIER.code.length, 0, "verifier code");
        assertGt(SPOTENGINE.code.length, 0, "spotengine code");
        assertGt(PERPENGINE.code.length, 0, "perpengine code");
        assertGt(OFFCHAINEXCHANGE.code.length, 0, "offchainexchange code");

        assertEq(IEndpoint(ENDPOINT).owner(), EXPECTED_OWNER, "endpoint owner");
        assertEq(IClearinghouse(CLEARINGHOUSE).owner(), EXPECTED_OWNER, "ch owner");
        assertEq(IWithdrawPool(WITHDRAWPOOL).owner(), EXPECTED_OWNER, "wp owner");
        assertEq(ISpotEngine(SPOTENGINE).owner(), EXPECTED_OWNER, "spot owner");
        assertEq(IPerpEngine(PERPENGINE).owner(), EXPECTED_OWNER, "perp owner");
        assertEq(IOffchainExchange(OFFCHAINEXCHANGE).owner(), EXPECTED_OWNER, "oe owner");
        assertEq(IVerifier(VERIFIER).owner(), EXPECTED_OWNER, "verifier owner");

        assertEq(IEndpoint(ENDPOINT).getSequencer(), EXPECTED_SEQUENCER, "sequencer");
        assertEq(IEndpoint(ENDPOINT).clearinghouse(), CLEARINGHOUSE, "ep->ch");
        assertEq(IClearinghouse(CLEARINGHOUSE).getEndpoint(), ENDPOINT, "ch->ep");
        assertEq(IClearinghouse(CLEARINGHOUSE).getWithdrawPool(), WITHDRAWPOOL, "ch->wp");
        assertEq(IClearinghouse(CLEARINGHOUSE).getQuote(), USDT0, "quote token");
        assertEq(ISpotEngine(SPOTENGINE).getEndpoint(), ENDPOINT, "spot->ep");
        assertEq(IPerpEngine(PERPENGINE).getEndpoint(), ENDPOINT, "perp->ep");

        // ECDSA signer set used by fast withdrawals (nSignatures == nSigner required)
        uint256 nSigners = 0;
        for (uint8 i = 0; i < 8; i++) {
            address s = IVerifier(VERIFIER).getEcdsaSigner(i);
            (uint256 px, uint256 py) = IVerifier(VERIFIER).getPubkey(i);
            if (px != 0 || py != 0) {
                nSigners++;
                assertTrue(s != address(0), "signer must be set");
                assertEq(s.code.length, 0, "signer must be EOA");
            }
            emit log_named_uint("signer_slot", i);
            emit log_named_address("ecdsa_signer", s);
        }
        emit log_named_uint("live_nSigner", nSigners);
        assertGt(nSigners, 0, "at least one signer provisioned");

        emit log_named_uint("nSubmissions", IEndpoint(ENDPOINT).nSubmissions());
        emit log_named_uint("withdrawPool_minIdx", IWithdrawPool(WITHDRAWPOOL).minIdx());
        emit log_named_int("withdrawPool_fees_quote", IWithdrawPool(WITHDRAWPOOL).fees(0));
        emit log_named_int("insurance_x18", IClearinghouse(CLEARINGHOUSE).getInsurance());
        (, uint64 upTo, uint64 count) = IEndpoint(ENDPOINT).getSlowModeTx(0);
        emit log_named_uint("slowMode_txUpTo", upTo);
        emit log_named_uint("slowMode_txCount", count);

        uint256 chQuote = IERC20(USDT0).balanceOf(CLEARINGHOUSE);
        uint256 wpQuote = IERC20(USDT0).balanceOf(WITHDRAWPOOL);
        emit log_named_uint("clearinghouse_USDT0_6dp", chQuote);
        emit log_named_uint("withdrawpool_USDT0_6dp", wpQuote);
        assertGt(chQuote, 25_000_000e6, "clearinghouse holds the TVL");
        assertLt(wpQuote, 5_000_000e6, "withdraw pool is the small hot buffer");

        // last processed withdrawal idx is marked (replay gate is live)
        uint64 m = IWithdrawPool(WITHDRAWPOOL).minIdx();
        assertTrue(IWithdrawPool(WITHDRAWPOOL).markedIdxs(m), "minIdx marked");
        emit log_named_uint("markedIdxs(minIdx)", 1);
    }

    // ------------------------------------------------------------------
    // 2. EIP-712 domain binding of the fast-withdraw (sequencer) digest
    // ------------------------------------------------------------------
    function test_fastWithdraw_digest_domain_binding() public {
        IVerifier v = IVerifier(VERIFIER);
        bytes memory txn = _signedWithdrawBlob(aliceSub, 0, 1e6, 0, "");
        uint64 idx = 424242;

        bytes32 structHash = keccak256(
            abi.encode(SIGNED_TX_TYPEHASH, idx, keccak256(txn))
        );
        bytes32 expected = _digest(VERIFIER, structHash);
        assertEq(v.txSignatureDigest(txn, idx), expected, "domain == (Nado,0.0.1,chain,verifier)");

        // chain binding
        bytes32 otherChain = _digestWithChain(VERIFIER, structHash, block.chainid + 1);
        assertTrue(otherChain != expected, "digest changes with chainid");

        // verifying-contract binding (Endpoint user domain != Verifier fast-withdraw domain)
        assertTrue(_digest(ENDPOINT, structHash) != expected, "digest changes with contract");

        // idx binding and payload binding
        assertTrue(v.txSignatureDigest(txn, idx + 1) != expected, "digest binds idx");
        assertTrue(
            v.txSignatureDigest(_signedWithdrawBlob(aliceSub, 0, 2e6, 0, ""), idx) != expected,
            "digest binds payload"
        );
    }

    // ------------------------------------------------------------------
    // 3. User signature semantics (validateSignature / compact / malleability)
    // ------------------------------------------------------------------
    function test_userSignature_validate_semantics() public {
        IVerifier v = IVerifier(VERIFIER);
        bytes32 digest = _digest(
            ENDPOINT,
            v.computeDigest(T_WITHDRAW, _signedWithdrawBody(aliceSub, 0, 4e6, 7, ""))
        ); // user path domain = Endpoint

        (uint8 vv, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);
        bytes memory sigAlice = abi.encodePacked(r, s, vv);

        // owner signs own subaccount -> ok
        v.validateSignature(aliceSub, address(0), digest, sigAlice);

        // wrong subaccount -> IS
        _expectError("IS");
        v.validateSignature(bobSub, address(0), digest, sigAlice);

        {
            // linked signer path (bob linked to alice's subaccount) -> ok
            (uint8 vvB, bytes32 rB, bytes32 sB) = vm.sign(bobPk, digest);
            bytes memory sigBob = abi.encodePacked(rB, sB, vvB);
            v.validateSignature(aliceSub, bob, digest, sigBob);

            // linked signer not enabled -> IS
            _expectError("IS");
            v.validateSignature(aliceSub, address(0), digest, sigBob);
        }

        // compact (EIP-2098) signature accepted
        bytes32 vs = bytes32((uint256(vv - 27) << 255) | uint256(s));
        v.validateCompactSignature(aliceSub, address(0), digest, Types.CompactSignature(r, vs));
    }

    function test_userSignature_malleability_rejected() public {
        IVerifier v = IVerifier(VERIFIER);
        bytes32 digest = _digest(
            ENDPOINT,
            v.computeDigest(T_WITHDRAW, _signedWithdrawBody(aliceSub, 0, 4e6, 8, ""))
        );
        (uint8 vv, bytes32 r, bytes32 s) = vm.sign(alicePk, digest);

        // malleated high-s version of the same signature is rejected (OZ low-s check)
        bytes32 sHigh = bytes32(SECP256K1_Q - uint256(s));
        _expectError("ECDSA: invalid signature 's' value");
        v.validateSignature(
            aliceSub,
            address(0),
            digest,
            abi.encodePacked(r, sHigh, vv == 27 ? uint8(28) : uint8(27))
        );
    }

    function test_userSignature_digest_binding() public {
        IVerifier v = IVerifier(VERIFIER);
        bytes32 structHash = v.computeDigest(
            T_WITHDRAW,
            _signedWithdrawBody(aliceSub, 0, 4e6, 9, "")
        );
        bytes32 digest = _digest(ENDPOINT, structHash);

        {
            // signature made for another chain's domain does not recover to the owner -> IS
            bytes32 wrongChainDigest = _digestWithChain(
                ENDPOINT,
                structHash,
                block.chainid + 1
            );
            (uint8 v2, bytes32 r2, bytes32 s2) = vm.sign(alicePk, wrongChainDigest);
            _expectError("IS");
            v.validateSignature(aliceSub, address(0), digest, abi.encodePacked(r2, s2, v2));
        }

        // V1 vs V2 type separation + sendTo binding (no digest collision / type confusion)
        bytes32 v1h = v.computeDigest(T_WITHDRAW, _signedWithdrawBody(aliceSub, 0, 4e6, 3, ""));
        bytes32 v2a = v.computeDigest(
            T_WITHDRAW_V2,
            _signedWithdrawV2Body(aliceSub, 0, 4e6, 3, alice)
        );
        bytes32 v2b = v.computeDigest(
            T_WITHDRAW_V2,
            _signedWithdrawV2Body(aliceSub, 0, 4e6, 3, bob)
        );
        assertTrue(v1h != v2a, "V1 != V2 digest");
        assertTrue(v2a != v2b, "sendTo is bound in V2 digest");
    }

    // ------------------------------------------------------------------
    // 4. Fast withdrawal (WithdrawPool) — quorum gate
    // ------------------------------------------------------------------
    function test_fastWithdraw_quorum_gate_reverts() public {
        IVerifier v = IVerifier(VERIFIER);
        uint64 idx = IWithdrawPool(WITHDRAWPOOL).minIdx() + 1;
        bytes memory txn = _signedWithdrawBlob(aliceSub, 0, 1e6, 0, "");

        {
            // no sequencer signatures at all
            bytes[] memory none = new bytes[](0);
            vm.prank(bob);
            _expectError("not enough signatures");
            IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(idx, txn, none);
        }

        {
            // three empty slots
            bytes[] memory empties = new bytes[](3);
            vm.prank(bob);
            _expectError("not enough signatures");
            IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(idx, txn, empties);
        }

        {
            // the *user's own* valid signature is not enough (slot 0 must be ecdsaSigners[0])
            (uint8 vv, bytes32 r, bytes32 s) = vm.sign(alicePk, v.txSignatureDigest(txn, idx));
            bytes[] memory one = new bytes[](1);
            one[0] = abi.encodePacked(r, s, vv);
            vm.prank(bob);
            _expectError("invalid signature");
            IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(idx, txn, one);

            // even 3 copies of a real ECDSA signature fail: positional match against provisioned keys
            bytes[] memory three = new bytes[](3);
            three[0] = one[0];
            three[1] = one[0];
            three[2] = one[0];
            vm.prank(bob);
            _expectError("invalid signature");
            IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(idx, txn, three);
        }

        // failed attempts do not consume the idx (no griefing of the idx space)
        assertFalse(IWithdrawPool(WITHDRAWPOOL).markedIdxs(idx), "idx not consumed on revert");
    }

    function test_fastWithdraw_idx_replay_gates() public {
        uint64 m = IWithdrawPool(WITHDRAWPOOL).minIdx();
        bytes memory txn = _signedWithdrawBlob(aliceSub, 0, 1e6, 0, "");
        bytes[] memory none = new bytes[](0);

        // already-processed idx is refused (replay protection)
        vm.prank(bob);
        _expectError("Withdrawal already submitted");
        IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(m, txn, none);

        // an unmarked idx <= minIdx is refused
        if (m > 1 && !IWithdrawPool(WITHDRAWPOOL).markedIdxs(m - 1)) {
            vm.prank(bob);
            _expectError("idx too small");
            IWithdrawPool(WITHDRAWPOOL).submitFastWithdrawal(m - 1, txn, none);
        }
    }

    // ------------------------------------------------------------------
    // 5. Other on-chain gates
    // ------------------------------------------------------------------
    function test_permissionless_gates_closed() public {
        // Clearinghouse.withdrawCollateral is endpoint-gated
        vm.prank(bob);
        _expectError("SequencerGated: caller is not the endpoint");
        IClearinghouse(CLEARINGHOUSE).withdrawCollateral(aliceSub, 0, 1e6, bob, 1);

        // WithdrawPool.submitWithdrawal is clearinghouse-gated
        vm.prank(bob);
        vm.expectRevert();
        IWithdrawPool(WITHDRAWPOOL).submitWithdrawal(IERC20(USDT0), bob, 1, 1);

        // SpotEngine mutators are gated
        vm.prank(bob);
        _expectError("U");
        ISpotEngine(SPOTENGINE).updateBalance(0, bobSub, 1);
        vm.prank(bob);
        _expectError("U");
        ISpotEngine(SPOTENGINE).updatePrice(0, 2e18);

        // Endpoint.submitTransactionsChecked is sequencer-gated
        uint64 idx = IEndpoint(ENDPOINT).nSubmissions();
        vm.prank(bob);
        vm.expectRevert();
        IEndpoint(ENDPOINT).submitTransactionsChecked(
            idx,
            new bytes[](0),
            bytes32(0),
            bytes32(0),
            0
        );

        // Endpoint.processSlowModeTransaction is self-gated
        vm.prank(bob);
        vm.expectRevert();
        IEndpoint(ENDPOINT).processSlowModeTransaction(bob, abi.encodePacked(T_DUMP_FEES));
    }

    function test_gasProbe_alwaysReverts() public {
        uint64 idx = IEndpoint(ENDPOINT).nSubmissions();
        vm.prank(bob);
        vm.expectRevert();
        IEndpoint(ENDPOINT).submitTransactionsCheckedWithGasLimit(
            idx,
            new bytes[](0),
            1_000_000_000
        );
    }

    function test_schnorr_sequencer_signature_gate() public {
        // 0x03 selects pubkeys 0 and 1 (quorum 2 of 3); random (e,s) cannot verify
        vm.expectRevert();
        IVerifier(VERIFIER).requireValidSignature(
            keccak256("subject"),
            bytes32(uint256(1)),
            bytes32(uint256(2)),
            0x03
        );
    }

    // ------------------------------------------------------------------
    // 6. Slow-mode (permissionless, delayed) path — the user self-service route
    // ------------------------------------------------------------------
    function test_slowMode_selfWithdraw_endToEnd() public {
        uint128 dep = 10e6; // $10
        _creditAlice(dep);

        Types.SpotBalance memory sb = IQuerier(QUERIER).getSpotBalance(aliceSub, 0);
        emit log_named_int("alice_spot_x18_after_deposit", sb.balance.amount);
        assertGt(sb.balance.amount, 0, "alice credited on-chain");
        assertGt(IEndpoint(ENDPOINT).getSubaccountId(aliceSub), 0, "subaccount registered");

        // alice withdraws 4 of her own collateral through the slow-mode queue
        uint128 w = 4e6;
        vm.startPrank(alice);
        IERC20(USDT0).approve(ENDPOINT, SLOW_MODE_FEE);
        IEndpoint(ENDPOINT).submitSlowModeTransaction(_withdrawBlob(aliceSub, 0, w, 0));
        vm.stopPrank();

        vm.warp(block.timestamp + SLOW_MODE_DELAY + 1);
        uint256 alice0 = IERC20(USDT0).balanceOf(alice);
        uint256 ch0 = IERC20(USDT0).balanceOf(CLEARINGHOUSE);
        uint256 wp0 = IERC20(USDT0).balanceOf(WITHDRAWPOOL);
        uint256 processed = _drainSlowQueue(30);
        emit log_named_uint("slow_txs_processed", processed);
        emit log_named_uint("withdrawpool_before", wp0);
        emit log_named_uint("withdrawpool_after", IERC20(USDT0).balanceOf(WITHDRAWPOOL));

        assertEq(IERC20(USDT0).balanceOf(alice) - alice0, w, "alice received withdrawal");
        assertEq(ch0 - IERC20(USDT0).balanceOf(CLEARINGHOUSE), w, "clearinghouse paid out");
        assertLt(
            IQuerier(QUERIER).getSpotBalance(aliceSub, 0).balance.amount,
            sb.balance.amount,
            "spot balance debited"
        );
    }

    function test_slowMode_thirdPartyWithdraw_rejected() public {
        _creditAlice(10e6);
        (, uint64 upTo0, ) = IEndpoint(ENDPOINT).getSlowModeTx(0);
        uint256 alice0 = IERC20(USDT0).balanceOf(alice);
        uint256 ch0 = IERC20(USDT0).balanceOf(CLEARINGHOUSE);
        int128 spot0 = IQuerier(QUERIER).getSpotBalance(aliceSub, 0).balance.amount;

        // bob funds the $1 slow-mode fee from his own wallet
        vm.prank(USDT0_WHALE);
        IERC20(USDT0).transfer(bob, 2e6);

        // bob enqueues a withdrawal for alice's subaccount (sender field = alice)
        vm.startPrank(bob);
        IERC20(USDT0).approve(ENDPOINT, SLOW_MODE_FEE);
        IEndpoint(ENDPOINT).submitSlowModeTransaction(_withdrawBlob(aliceSub, 0, 4e6, 0));
        vm.stopPrank();

        vm.warp(block.timestamp + SLOW_MODE_DELAY + 1);
        _drainSlowQueue(30);

        (, uint64 upTo1, ) = IEndpoint(ENDPOINT).getSlowModeTx(0);
        assertGt(upTo1, upTo0, "queue advanced past failed entry");
        assertEq(IERC20(USDT0).balanceOf(alice), alice0, "alice balance untouched");
        assertEq(IERC20(USDT0).balanceOf(CLEARINGHOUSE), ch0, "clearinghouse untouched");
        assertEq(
            IQuerier(QUERIER).getSpotBalance(aliceSub, 0).balance.amount,
            spot0,
            "alice spot unchanged"
        );
    }

    function test_slowMode_ownerOnlyTypes_rejected() public {
        bytes memory withdrawInsurance = abi.encodePacked(
            T_WITHDRAW_INSURANCE,
            abi.encode(uint128(1e6), bob)
        );
        vm.prank(bob);
        vm.expectRevert();
        IEndpoint(ENDPOINT).submitSlowModeTransaction(withdrawInsurance);

        vm.prank(bob);
        vm.expectRevert();
        IEndpoint(ENDPOINT).submitSlowModeTransaction(abi.encodePacked(T_DUMP_FEES));
    }

    function test_verifier_initializeV2_benign() public {
        bytes memory txn = _signedWithdrawBlob(aliceSub, 0, 1e6, 0, "");
        bytes32 digestBefore = IVerifier(VERIFIER).txSignatureDigest(txn, 1);
        // permissionless backfill of the EIP-712 domain (constant parameters)
        (bool ok, ) = VERIFIER.call(abi.encodeWithSignature("initializeV2()"));
        bytes32 digestAfter = IVerifier(VERIFIER).txSignatureDigest(txn, 1);
        assertEq(digestBefore, digestAfter, "initializeV2 cannot alter the domain");
        emit log_named_string("initializeV2_callable", ok ? "yes" : "no (already done)");
    }

    // ------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------
    function _sub(address owner, bytes12 name) internal pure returns (bytes32) {
        return bytes32((uint256(uint160(owner)) << 96) | uint256(uint96(name)));
    }

    /// @dev slow-mode WithdrawCollateral body: type byte + WithdrawCollateral struct
    function _withdrawBlob(
        bytes32 sender,
        uint32 productId,
        uint128 amount,
        uint64 nonce
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(T_WITHDRAW, abi.encode(sender, productId, amount, nonce));
    }

    /// @dev fast-withdraw SignedWithdrawCollateral body (dynamic struct: needs the
    ///      standard ABI outer offset word before the struct payload)
    function _signedWithdrawBody(
        bytes32 sender,
        uint32 productId,
        uint128 amount,
        uint64 nonce,
        bytes memory sig
    ) internal pure returns (bytes memory) {
        return
            abi.encodePacked(
                bytes32(uint256(0x20)),
                abi.encode(sender, productId, amount, nonce, sig)
            );
    }

    /// @dev fast-withdraw SignedWithdrawCollateral body: type byte + tx + user signature
    function _signedWithdrawBlob(
        bytes32 sender,
        uint32 productId,
        uint128 amount,
        uint64 nonce,
        bytes memory sig
    ) internal pure returns (bytes memory) {
        return abi.encodePacked(T_WITHDRAW, _signedWithdrawBody(sender, productId, amount, nonce, sig));
    }

    /// @dev SignedWithdrawCollateralV2 body: tx(6) + compact signature(2) + feeX18
    function _signedWithdrawV2Body(
        bytes32 sender,
        uint32 productId,
        uint128 amount,
        uint64 nonce,
        address sendTo
    ) internal pure returns (bytes memory) {
        return
            abi.encode(
                sender,
                productId,
                amount,
                nonce,
                sendTo,
                uint128(0), // appendix
                bytes32(0), // compact r
                bytes32(0), // compact vs
                int128(0) // feeX18
            );
    }

    function _digest(address verifyingContract, bytes32 structHash)
        internal
        view
        returns (bytes32)
    {
        return _digestWithChain(verifyingContract, structHash, block.chainid);
    }

    function _digestWithChain(
        address verifyingContract,
        bytes32 structHash,
        uint256 chainId
    ) internal pure returns (bytes32) {
        bytes32 domainSeparator = keccak256(
            abi.encode(
                DOMAIN_TYPEHASH,
                keccak256("Nado"),
                keccak256("0.0.1"),
                chainId,
                verifyingContract
            )
        );
        return keccak256(abi.encodePacked("\x19\x01", domainSeparator, structHash));
    }

    function _expectError(string memory reason) internal {
        vm.expectRevert(abi.encodeWithSignature("Error(string)", reason));
    }

    /// @dev fund an address from the USDT0 whale and make her on-chain deposit at the Endpoint
    function _creditAlice(uint128 dep) internal {
        // keep a wallet buffer for the $1 slow-mode fees
        vm.prank(USDT0_WHALE);
        IERC20(USDT0).transfer(alice, uint256(dep) + 5e6);

        vm.startPrank(alice);
        IERC20(USDT0).approve(ENDPOINT, type(uint256).max);
        IEndpoint(ENDPOINT).depositCollateral(bytes12("alice"), 0, dep);
        vm.stopPrank();

        // the deposit is queued as a slow-mode tx and credited after the queue delay
        vm.warp(block.timestamp + SLOW_MODE_DELAY + 1);
        _drainSlowQueue(30);
    }

    /// @dev permissionlessly crank the slow-mode queue head (skips defective entries)
    function _drainSlowQueue(uint256 maxIter) internal returns (uint256 processed) {
        for (uint256 i = 0; i < maxIter; i++) {
            (, uint64 upTo, uint64 count) = IEndpoint(ENDPOINT).getSlowModeTx(0);
            if (upTo >= count) return processed;
            IEndpoint(ENDPOINT).executeSlowModeTransaction();
            processed++;
        }
        return processed;
    }
}
