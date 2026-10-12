// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// Yield Millionaire — Base vault (0xD4F3Ba2F...) unprivileged-extraction PoC.
//
// All tests are FORK-ONLY (read-only simulation of mainnet state). No mainnet
// transactions are ever sent. The fork RPC is a PUBLIC endpoint (no secrets).
// Deployed interfaces below mirror the Etherscan-verified sources, which are
// byte-identical to the project repo HEAD (ZetaChain-Venture-Studio/
// yieldmillionaire-, commits 316a753 AaveVault v1.2.1 / 05153e5 EVMEntry v1.3.0).
// ---------------------------------------------------------------------------

interface IERC20M {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
}

struct CallContext {
    uint256 targetChain;
    uint8 protocol; // enum Protocol { Aave = 0 }
    address sender;
    address to;
    address token;
    uint256 amount;
    uint256 gasLimit;
    uint256 nonce;
    uint256 destinationChain;
    uint256 deadline;
    bytes signature;
}

struct MessageContext {
    address sender;
}

interface IVaultM {
    error NotEVMEntry();
    error NotGateway();
    error NotGuardian();
    error NotOwner();
    error NotYieldMil();
    error InvalidSignature();
    error ZeroAssets();
    error VaultIsNotPaused();
    error WithdrawIsForbidden();
    error DepositIsForbidden();

    function VERSION() external view returns (string memory);
    function ASSET() external view returns (address);
    function TOKEN() external view returns (address);
    function GATEWAY() external view returns (address);
    function YIELDMIL() external view returns (address);
    function EVMENTRY() external view returns (address);
    function getOwner() external view returns (address);
    function getPool() external view returns (address);
    function getFee() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalAssets() external view returns (uint256);
    function getAccumulatedFees() external view returns (uint256);
    function getLastVaultBalance() external view returns (uint256);
    function getNonce(address) external view returns (uint256);
    function getAssetsAndShares(address) external view returns (uint256, uint256);
    function isGuardian(address) external view returns (bool);
    function deposit(bytes calldata) external returns (uint256);
    function withdraw(bytes calldata) external;
    function onCall(MessageContext calldata, bytes calldata) external payable returns (bytes memory);
    function pauseDeposit() external;
    function pauseWithdraw() external;
    function setFee(uint256) external payable;
    function updateGuardian(address, bool) external payable;
    function rescueFunds(address, address, uint256) external payable;
}

interface IEVMEntryM {
    error InvalidContext();

    function deposit(CallContext calldata) external returns (uint256);
    function withdraw(CallContext calldata) external payable;
    function getVault(uint8, address) external view returns (address);
    function getOwner() external view returns (address);
}

contract YieldMillionairePoC is Test {
    // --- Base mainnet addresses (chain id 8453) ---
    address constant VAULT     = 0xD4F3Ba2Fe4183c32A498Ad1ecF9Fc55308FcC029;
    address constant EVMENTRY  = 0xCB513DB80C6C76593770Fc4a1827d5Ab8186b0cD;
    address constant USDC      = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913;
    address constant AUSDC     = 0x4e65fE4DbA92790696d040ac24Aa414708F5c0AB; // Aave V3 aUSDC
    address constant GATEWAY   = 0x48B9AACC350b20147001f88821d31731Ba4C30ed; // ZetaChain GatewayEVM
    address constant YIELDMIL  = 0xE65eEe518A897618cBEe25898f80200E7988c81e; // zEVM router (v1.4.2)
    address constant POOL      = 0xA238Dd80C259a72e81d7e4664a9801593F98d1c5; // Aave V3 Base Pool
    address constant SAFE      = 0xCe246ef822210467C94bC1269EcFd8760DffE61C; // owner + proxy admin (Safe 1.4.1, th=1)
    address constant TOPHOLDER = 0xa8e3ef3b73Cef1fFeFaa7072F7294215D2190FF3; // largest share holder
    address constant ATTACKER  = address(0xA77ACC);

    // EIP-7201 slot of AaveVaultStorage; +5 packs isDepositPaused/isWithdrawPaused
    bytes32 constant VAULT_STORAGE_SLOT =
        0xe86928725d42611a4d97f5379bd85d7fa4997f3070cc0d523b2643f8c6d82d00;

    IVaultM vault;
    IEVMEntryM evmEntry;
    IERC20M usdc;
    IERC20M ausdc;

    function setUp() public {
        string memory rpc =
            vm.envOr("BASE_FORK_URL", string("https://base-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        vault = IVaultM(VAULT);
        evmEntry = IEVMEntryM(EVMENTRY);
        usdc = IERC20M(USDC);
        ausdc = IERC20M(AUSDC);
        emit log_named_uint("Base fork block", block.number);
    }

    function _ethSigned(bytes32 h) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", h));
    }

    function _digest(
        address sender,
        address to,
        uint256 shares,
        uint256 destinationChain,
        uint256 nonce,
        uint256 deadline
    ) internal pure returns (bytes32) {
        return _ethSigned(
            keccak256(
                abi.encode(
                    sender, to, shares, destinationChain, nonce, uint256(8453), deadline, VAULT
                )
            )
        );
    }

    /// @notice Live state of the target: everything the headline rests on.
    function test_live_state_current() public {
        assertEq(vault.VERSION(), "1.2.1", "impl version");
        assertEq(vault.ASSET(), AUSDC);
        assertEq(vault.TOKEN(), USDC);
        assertEq(vault.GATEWAY(), GATEWAY);
        assertEq(vault.YIELDMIL(), YIELDMIL);
        assertEq(vault.EVMENTRY(), EVMENTRY);
        assertEq(vault.getPool(), POOL);
        assertEq(vault.getOwner(), SAFE);
        assertEq(evmEntry.getOwner(), SAFE);
        assertEq(evmEntry.getVault(0, USDC), VAULT, "EVMEntry vault mapping");
        assertEq(vault.getFee(), 200, "2% fee");

        uint256 av = ausdc.balanceOf(VAULT);
        uint256 fees = vault.getAccumulatedFees();
        uint256 ta = vault.totalAssets();
        uint256 ts = vault.totalSupply();

        assertEq(ta, av - fees, "totalAssets == aUSDC balance - fees");
        assertGt(av, 100_000e6, "vault aUSDC > 100k");
        assertGt(ts, 100_000e6, "share supply > 100k");

        bytes32 pauseSlot = vm.load(VAULT, bytes32(uint256(VAULT_STORAGE_SLOT) + 5));
        assertEq(uint256(pauseSlot), 0, "neither deposit nor withdraw paused");

        (uint256 hAssets, uint256 hShares) = vault.getAssetsAndShares(TOPHOLDER);
        assertGt(hShares, 10_000e6, "top holder > 10k shares");
        assertGt(hAssets, hShares, "share price > 1.0 (yield accrued)");

        emit log_named_uint("vault aUSDC balance (1e6)", av);
        emit log_named_uint("totalAssets USDC (1e6)", ta);
        emit log_named_uint("totalSupply shares (1e6)", ts);
        emit log_named_uint("accumulatedFees USDC (1e6)", fees);
        emit log_named_uint("top holder shares (1e6)", hShares);
        emit log_named_uint("top holder assets (1e6)", hAssets);
        emit log_named_uint("top holder nonce", vault.getNonce(TOPHOLDER));
    }

    /// @notice Direct calls to the value-moving functions from an EOA all revert.
    function test_direct_unprivileged_calls_revert() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert(IVaultM.NotEVMEntry.selector);
        vault.deposit(abi.encode(ATTACKER, ATTACKER, uint256(1e6), uint256(8453)));
        vm.expectRevert(IVaultM.NotEVMEntry.selector);
        vault.withdraw(abi.encode(ATTACKER, ATTACKER, uint256(1e6), uint256(8453)));
        vm.expectRevert(IVaultM.NotGateway.selector);
        vault.onCall(MessageContext({sender: ATTACKER}), hex"02");
        vm.expectRevert(IVaultM.NotGuardian.selector);
        vault.pauseDeposit();
        vm.expectRevert(IVaultM.NotOwner.selector);
        vault.setFee(1);
        vm.expectRevert(IVaultM.NotOwner.selector);
        vault.rescueFunds(ATTACKER, AUSDC, 1);
        vm.stopPrank();
    }

    /// @notice An attacker cannot withdraw a victim's shares, with any signature form.
    function test_unprivileged_cannot_withdraw_victim_shares() public {
        (, uint256 victimShares) = vault.getAssetsAndShares(TOPHOLDER);
        assertGt(victimShares, 0);
        uint256 deadline = block.timestamp + 1 days;

        CallContext memory ctx = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: TOPHOLDER,
            to: ATTACKER,
            token: USDC,
            amount: victimShares,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: deadline,
            signature: new bytes(65)
        });

        // 65-byte garbage signature
        vm.prank(ATTACKER);
        vm.expectRevert(IVaultM.InvalidSignature.selector);
        evmEntry.withdraw(ctx);

        // 66-byte signature (exercises the `signature.length > 65` ERC-1271 branch)
        ctx.signature = new bytes(66);
        vm.prank(ATTACKER);
        vm.expectRevert(IVaultM.InvalidSignature.selector);
        evmEntry.withdraw(ctx);

        // attacker's own valid key, but over a victim-bound digest -> recovered != sender
        (, uint256 atkPk) = makeAddrAndKey("attackerKey");
        bytes32 d = _digest(TOPHOLDER, ATTACKER, victimShares, 8453, vault.getNonce(TOPHOLDER), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(atkPk, d);
        ctx.signature = abi.encodePacked(r, s, v);
        vm.prank(ATTACKER);
        vm.expectRevert(IVaultM.InvalidSignature.selector);
        evmEntry.withdraw(ctx);
    }

    /// @notice Bounded fuzz: random signatures never pass verification.
    function test_bounded_fuzz_garbage_sigs_always_revert() public {
        (, uint256 victimShares) = vault.getAssetsAndShares(TOPHOLDER);
        for (uint256 i = 0; i < 16; ++i) {
            bytes memory sig = new bytes(65);
            for (uint256 j = 0; j < 65; ++j) {
                sig[j] = bytes1(uint8(uint256(keccak256(abi.encode(i, j, "ym"))) % 256));
            }
            CallContext memory ctx = CallContext({
                targetChain: 8453,
                protocol: 0,
                sender: TOPHOLDER,
                to: ATTACKER,
                token: USDC,
                amount: victimShares,
                gasLimit: 0,
                nonce: 0,
                destinationChain: 8453,
                deadline: block.timestamp + 1 days,
                signature: sig
            });
            vm.prank(ATTACKER);
            vm.expectRevert(IVaultM.InvalidSignature.selector);
            evmEntry.withdraw(ctx);
        }
    }

    /// @notice Even the authenticated cross-chain path cannot drain without a signature.
    function test_onCall_cross_chain_paths_cannot_drain() public {
        MessageContext memory asYieldMil = MessageContext({sender: YIELDMIL});
        MessageContext memory asAttacker = MessageContext({sender: ATTACKER});

        // (a) only the registered zEVM router is accepted as sender
        vm.prank(GATEWAY);
        vm.expectRevert(IVaultM.NotYieldMil.selector);
        vault.onCall(asAttacker, hex"02");

        // (b) even as YIELDMIL, withdraw requires the share owner's signature
        (, uint256 victimShares) = vault.getAssetsAndShares(TOPHOLDER);
        CallContext memory c = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: TOPHOLDER,
            to: ATTACKER,
            token: USDC,
            amount: victimShares,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: block.timestamp + 1 days,
            signature: new bytes(65)
        });
        vm.prank(GATEWAY);
        vm.expectRevert(IVaultM.InvalidSignature.selector);
        vault.onCall(asYieldMil, abi.encodePacked(hex"02", abi.encode(c)));

        // (c) forged deposit needs gateway token balance AND allowance to the vault;
        //     a bare YIELDMIL-sender deposit mints nothing out of thin air
        bytes memory dep =
            abi.encodePacked(hex"01", abi.encode(ATTACKER, ATTACKER, uint256(10_000e6), uint256(137)));
        vm.prank(GATEWAY);
        vm.expectRevert(); // gateway holds no USDC
        vault.onCall(asYieldMil, dep);

        // fund the gateway externally -> still no allowance to the vault
        vm.prank(AUSDC);
        usdc.transfer(GATEWAY, 10_000e6);
        assertEq(usdc.balanceOf(GATEWAY), 10_000e6);
        vm.prank(GATEWAY);
        vm.expectRevert(); // allowance == 0
        vault.onCall(asYieldMil, dep);

        // Documented precondition: the mint only works if the gateway BOTH holds the
        // tokens AND approves the vault. On the live system that state is created only
        // by GatewayEVM.executeWithERC20 (TSS-driven), scoped to a real cross-chain
        // transfer and reset in the same transaction — not attacker-reachable.
        vm.prank(GATEWAY);
        usdc.approve(VAULT, 10_000e6);
        vm.prank(GATEWAY);
        vault.onCall(asYieldMil, dep);
        (, uint256 atkShares) = vault.getAssetsAndShares(ATTACKER);
        assertGt(atkShares, 0, "mint succeeds ONLY with gateway balance+allowance");
    }

    /// @notice Deposits require payment; zero-share accounts cannot extract anything.
    function test_no_free_money() public {
        CallContext memory dep = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: ATTACKER,
            to: ATTACKER,
            token: USDC,
            amount: 1e6,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: block.timestamp + 1 days,
            signature: new bytes(0)
        });
        vm.prank(ATTACKER);
        vm.expectRevert(); // direct transferFrom: no USDC
        evmEntry.deposit(dep);

        dep.signature = new bytes(65); // permit2 path with garbage signature
        vm.prank(ATTACKER);
        vm.expectRevert();
        evmEntry.deposit(dep);

        // amount 0 is rejected at the entry point
        (address atk, uint256 pk) = makeAddrAndKey("zeroUser");
        CallContext memory zero = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: atk,
            to: atk,
            token: USDC,
            amount: 0,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: block.timestamp + 1 days,
            signature: new bytes(0)
        });
        vm.prank(atk);
        vm.expectRevert(IEVMEntryM.InvalidContext.selector);
        evmEntry.withdraw(zero);

        // valid signature by a share-less account: burn underflows -> arithmetic panic
        uint256 deadline = block.timestamp + 1 days;
        bytes32 d = _digest(atk, atk, 1, 8453, 0, deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, d);
        zero.amount = 1;
        zero.signature = abi.encodePacked(r, s, v);
        vm.prank(atk);
        vm.expectRevert(stdError.arithmeticError);
        evmEntry.withdraw(zero);
    }

    /// @notice Positive control: a holder can deposit and exit; replay is blocked.
    function test_holder_roundtrip_and_replay_blocked() public {
        (address u, uint256 pk) = makeAddrAndKey("liveUser");
        uint256 amount = 100e6;

        // fund from the Aave aUSDC contract (holds ~16.7M idle USDC) via impersonation
        vm.prank(AUSDC);
        usdc.transfer(u, amount);

        vm.startPrank(u);
        usdc.approve(EVMENTRY, amount);
        CallContext memory dep = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: u,
            to: u,
            token: USDC,
            amount: amount,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: block.timestamp + 1 days,
            signature: new bytes(0)
        });
        uint256 shares = evmEntry.deposit(dep);
        vm.stopPrank();
        assertGt(shares, 0, "shares minted");
        assertEq(vault.getNonce(u), 0, "fresh nonce");

        uint256 deadline = block.timestamp + 1 days;
        bytes32 d = _digest(u, u, shares, 8453, vault.getNonce(u), deadline);
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(pk, d);
        CallContext memory wd = CallContext({
            targetChain: 8453,
            protocol: 0,
            sender: u,
            to: u,
            token: USDC,
            amount: shares,
            gasLimit: 0,
            nonce: 0,
            destinationChain: 8453,
            deadline: deadline,
            signature: abi.encodePacked(r, s, v)
        });

        uint256 balBefore = usdc.balanceOf(u);
        vm.prank(ATTACKER); // anyone may relay the holder's signed request
        evmEntry.withdraw(wd);
        uint256 gained = usdc.balanceOf(u) - balBefore;

        assertEq(vault.getNonce(u), 1, "nonce consumed");
        assertGe(gained, amount - 1000, "holder recovered ~100% (rounding down)");
        assertLe(gained, amount, "never more than principal at 1:1");

        // replay of the exact same signed context must fail (nonce advanced)
        vm.prank(ATTACKER);
        vm.expectRevert(IVaultM.InvalidSignature.selector);
        evmEntry.withdraw(wd);

        emit log_named_uint("shares minted", shares);
        emit log_named_uint("USDC recovered (1e6)", gained);
    }

    /// @notice Privileged-path demonstration (category P, NOT unprivileged):
    ///         the 1-of-2 Safe owner can self-appoint as guardian, pause both flows
    ///         and rescue the whole vault. Shown on a fork only; no mainnet action.
    function test_privileged_path_owner_can_pause_and_rescue() public {
        uint256 av0 = ausdc.balanceOf(VAULT); // evaluate BEFORE prank/expectRevert
        vm.prank(SAFE);
        vm.expectRevert(IVaultM.VaultIsNotPaused.selector);
        vault.rescueFunds(SAFE, AUSDC, av0);

        vm.startPrank(SAFE);
        vault.updateGuardian(SAFE, true);
        vault.pauseDeposit();
        vault.pauseWithdraw();
        uint256 av = ausdc.balanceOf(VAULT);
        assertGt(av, 100_000e6);
        vault.rescueFunds(SAFE, AUSDC, av);
        vm.stopPrank();

        assertEq(ausdc.balanceOf(VAULT), 0, "vault swept by privileged Safe");
        assertEq(ausdc.balanceOf(SAFE), av);
        emit log_named_uint("amount swept by owner (1e6)", av);
    }
}
