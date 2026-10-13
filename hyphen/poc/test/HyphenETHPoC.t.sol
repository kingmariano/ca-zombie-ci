// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IPool, IProviders, ILPToken, IExecutorManager, IERC20, IBiconomyForwarder, LpTokenMetadata, Hyphen} from "../src/IHyphen.sol";

/// @title Hyphen (Biconomy) live extraction PoC - Ethereum mainnet fork
/// @notice Read-only analysis: every test runs on a local fork. No mainnet tx is ever sent.
///         E-U  = extractable by an external unprivileged attacker (fresh address, no roles)
///         H-O  = recoverable by existing LP NFT holders (legacy positions)
///         P    = privileged only (owner / executor / proxy admin)
///         S    = stuck (no code path moves it)
contract HyphenETHPoC is Test {
    address constant POOL = Hyphen.ETH_POOL;
    address constant PROVIDERS = Hyphen.ETH_PROVIDERS;
    address constant LPTOKEN = Hyphen.ETH_LPTOKEN;
    address constant EXEC_MGR = Hyphen.ETH_EXEC_MGR;
    address constant FORWARDER = Hyphen.ETH_FORWARDER;
    address constant USDC = Hyphen.ETH_USDC;
    address constant USDT = Hyphen.ETH_USDT;
    address constant BICO = Hyphen.ETH_BICO;
    address constant NATIVE = Hyphen.NATIVE;

    address constant FRESH = address(0xF0E57); // fresh unprivileged attacker
    address constant EXECUTOR = 0xEEFD474e80B6CAEA43F212D964409c473684E3fe; // live executor EOA

    IPool pool = IPool(POOL);
    IProviders providers = IProviders(PROVIDERS);
    ILPToken lpToken = ILPToken(LPTOKEN);

    function setUp() public {
        vm.createSelectFork(vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))));
    }

    // ---------------------------------------------------------------- state
    function test_A_live_state() public {
        emit log_named_uint("block", block.number);
        emit log_named_uint("pool native wei", POOL.balance);
        emit log_named_uint("providers native wei", PROVIDERS.balance);
        emit log_named_uint("USDC pool balance", IERC20(USDC).balanceOf(POOL));
        emit log_named_uint("USDC totalReserve", providers.totalReserve(USDC));
        emit log_named_uint("USDC currentLiquidity", providers.currentLiquidity(USDC));
        emit log_named_uint("USDT pool balance", IERC20(USDT).balanceOf(POOL));
        emit log_named_uint("USDT totalReserve", providers.totalReserve(USDT));
        emit log_named_uint("BICO pool balance", IERC20(BICO).balanceOf(POOL));
        emit log_named_uint("BICO totalReserve", providers.totalReserve(BICO));
        emit log_named_uint("LP NFT totalSupply", lpToken.totalSupply());
        emit log_named_address("pool owner", pool.owner());
        emit log_named_address("providers owner", providers.owner());
        emit log_named_address("lptoken owner", lpToken.owner());
        assertEq(pool.paused(), false, "pool paused");
        assertEq(providers.paused(), false, "providers paused");
        assertEq(lpToken.paused(), false, "lptoken paused");
        assertEq(pool.owner(), providers.owner(), "same owner");
        assertGt(POOL.balance, 0, "pool holds ETH");
        assertEq(PROVIDERS.balance, 8 ether, "providers holds exactly 8 ETH");
    }

    // ------------------------------------------------------------ E-U gates
    function test_B_EU_initialize_reverts() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        pool.initialize(FRESH, FRESH, FRESH, FRESH, FRESH);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        providers.initialize(FRESH, FRESH, FRESH, FRESH);
        vm.stopPrank();
    }

    function test_C_EU_executor_gates() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.sendFundsToUser(USDC, 100e6, payable(FRESH), hex"deadbeef", 0, 137);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.sendFundsToUserV2(USDC, 100e6, payable(FRESH), hex"deadbeef", 1e18, 137, 0);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.withdrawErc20GasFee(USDC);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.withdrawNativeGasFee();
        vm.stopPrank();
    }

    function test_D_EU_providers_only_transfer() public {
        vm.prank(FRESH);
        vm.expectRevert(bytes("Only liquidityProviders is allowed"));
        pool.transfer(USDC, FRESH, 1);
        vm.prank(FRESH);
        vm.expectRevert(bytes("Only liquidityProviders is allowed"));
        pool.transfer(NATIVE, FRESH, 1);
    }

    function test_E_EU_owner_gates() public {
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setLiquidityProviders(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setExecutorManager(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setTokenManager(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setCurrentLiquidity(USDC);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setSwapAdaptor("x", FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        pool.setBaseGas(1);
        vm.expectRevert(bytes("Only pauser is allowed to perform this operation"));
        pool.pause();
        vm.stopPrank();
    }

    function test_F_EU_lp_nft_gates() public {
        vm.startPrank(FRESH);
        // No NFT at all
        vm.expectRevert(bytes("ERR__TRANSACTOR_DOES_NOT_OWN_NFT"));
        providers.removeLiquidity(1, 1);
        vm.expectRevert(bytes("ERR__TRANSACTOR_DOES_NOT_OWN_NFT"));
        providers.claimFee(1);
        // Cannot mint / forge metadata
        vm.expectRevert(bytes("ERR_UNAUTHORIZED"));
        lpToken.mint(FRESH);
        vm.expectRevert(bytes("ERR_UNAUTHORIZED"));
        lpToken.updateTokenMetadata(7, LpTokenMetadata({token: NATIVE, suppliedLiquidity: 1e30, shares: 1e40}));
        // Cannot call provider-internal accounting
        vm.expectRevert(bytes("ERR__UNAUTHORIZED"));
        providers.addLPFee(USDC, 1e6);
        vm.expectRevert(bytes("ERR__UNAUTHORIZED"));
        providers.increaseCurrentLiquidity(USDC, 1e6);
        vm.expectRevert(bytes("ERR__UNAUTHORIZED"));
        providers.decreaseCurrentLiquidity(USDC, 1e6);
        vm.expectRevert(bytes("ERR__UNAUTHORIZED"));
        providers.setCurrentLiquidity(USDC, 1e6);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        providers.setLiquidityPool(FRESH);
        vm.expectRevert(bytes("Ownable: caller is not the owner"));
        providers.setLpToken(FRESH);
        vm.stopPrank();
        assertEq(EXEC_MGR.code.length > 0 ? 1 : 0, 1, "exec mgr is a contract");
    }

    function test_G_EU_forwarder_forgery_reverts() public {
        // A fresh attacker tries to spoof _msgSender() = victim through the trusted
        // forwarder with a garbage signature. The forwarder must reject it.
        IBiconomyForwarder.ERC20ForwardRequest memory req = IBiconomyForwarder.ERC20ForwardRequest({
            from: address(0xBEEF),
            to: POOL,
            token: address(0),
            txGas: 500000,
            tokenGasPrice: 0,
            batchId: 0,
            batchNonce: 0,
            deadline: 0,
            data: abi.encodeWithSignature("transfer(address,address,uint256)", USDC, FRESH, 1)
        });
        vm.prank(FRESH);
        (bool ok,) = FORWARDER.call(
            abi.encodeWithSignature(
                "executePersonalSign((address,address,address,uint256,uint256,uint256,uint256,uint256,bytes),bytes)",
                req, new bytes(65)
            )
        );
        assertFalse(ok, "forged forwarder request must revert");
        // direct call to pool from fresh is already proven to revert (test D)
    }

    // ------------------------------------------ E-U accounting (no free lunch)
    function test_H_EU_roundtrip_no_profit() public {
        deal(USDC, FRESH, 100e6);
        uint256 start = IERC20(USDC).balanceOf(FRESH);
        uint256 poolBefore = IERC20(USDC).balanceOf(POOL);
        uint256 reserveBefore = providers.totalReserve(USDC);

        vm.startPrank(FRESH);
        IERC20(USDC).approve(PROVIDERS, type(uint256).max);
        providers.addTokenLiquidity(USDC, 10e6);
        uint256 nftId = lpToken.totalSupply(); // id of the freshly minted NFT
        (address tok, uint256 supplied, uint256 shares) = lpToken.tokenMetadata(nftId);
        emit log_named_uint("new nft id", nftId);
        emit log_named_uint("supplied", supplied);
        emit log_named_uint("shares", shares);
        assertEq(tok, USDC, "nft token");
        providers.removeLiquidity(nftId, 10e6);
        vm.stopPrank();

        uint256 endBal = IERC20(USDC).balanceOf(FRESH);
        emit log_named_uint("start USDC", start);
        emit log_named_uint("end   USDC", endBal);
        emit log_named_uint("pool USDC before", poolBefore);
        emit log_named_uint("pool USDC after ", IERC20(USDC).balanceOf(POOL));
        emit log_named_uint("reserve before", reserveBefore);
        emit log_named_uint("reserve after ", providers.totalReserve(USDC));
        // Round trip must not create value for a fresh attacker.
        assertLe(endBal, start, "round trip must not profit");
    }

    function test_I_EU_excess_float_not_claimable() public {
        // The pool holds more USDC than totalReserve (bridged-in float). A fresh LP
        // must not be able to touch that excess.
        uint256 reserve = providers.totalReserve(USDC);
        uint256 bal = IERC20(USDC).balanceOf(POOL);
        assertGt(bal, reserve, "expected excess float");
        emit log_named_uint("excess float", bal - reserve);

        deal(USDC, FRESH, 100e6);
        uint256 start = IERC20(USDC).balanceOf(FRESH);
        vm.startPrank(FRESH);
        IERC20(USDC).approve(PROVIDERS, type(uint256).max);
        providers.addTokenLiquidity(USDC, 50e6);
        uint256 nftId = lpToken.totalSupply();
        providers.removeLiquidity(nftId, 50e6);
        vm.stopPrank();
        assertLe(IERC20(USDC).balanceOf(FRESH), start, "excess float not claimable");
    }

    // --------------------------------------------------- H-O: real NFT owner
    function _findLiveNft(address token, uint256 minSupplied) internal view returns (uint256 id) {
        for (uint256 i = 1; i <= 80; i++) {
            (address tok, uint256 supplied, uint256 shares) = lpToken.tokenMetadata(i);
            if (tok == token && supplied >= minSupplied && shares > 0) return i;
        }
        revert("no live NFT found");
    }

    function test_J_HO_legacy_nft_owner_can_withdraw() public {
        // Native position: an existing NFT owner can still withdraw from the pool.
        uint256 nftId = _findLiveNft(NATIVE, 0.05 ether);
        address owner = lpToken.ownerOf(nftId);
        (address tok, uint256 supplied,) = lpToken.tokenMetadata(nftId);
        emit log_named_uint("native nft id", nftId);
        emit log_named_uint("supplied wei", supplied);
        emit log_named_address("owner", owner);

        uint256 ownerBefore = owner.balance;
        uint256 poolBefore = POOL.balance;
        uint256 provBefore = PROVIDERS.balance;

        vm.prank(owner);
        providers.removeLiquidity(nftId, 0.05 ether);

        emit log_named_uint("owner gained wei", owner.balance - ownerBefore);
        emit log_named_uint("pool lost wei", poolBefore - POOL.balance);
        assertGt(owner.balance, ownerBefore, "owner received native");
        assertLt(POOL.balance, poolBefore, "pool paid");
        assertEq(PROVIDERS.balance, provBefore, "providers balance untouched");
    }

    function test_K_HO_usdc_nft_owner_can_withdraw() public {
        uint256 nftId = _findLiveNft(USDC, 1e6);
        address owner = lpToken.ownerOf(nftId);
        uint256 before = IERC20(USDC).balanceOf(owner);
        vm.prank(owner);
        providers.removeLiquidity(nftId, 1e6);
        assertGt(IERC20(USDC).balanceOf(owner), before, "owner received USDC");
    }

    // --------------------------------------------------------- P: executors
    function test_L_P_executor_can_pay_out() public {
        // The 4 executor EOAs can move pool funds to any receiver (within per-tx caps).
        // This is privileged (P), not E-U.
        assertTrue(IExecutorManager(EXEC_MGR).getExecutorStatus(EXECUTOR), "executor live");
        uint256 before = IERC20(USDC).balanceOf(FRESH);
        vm.prank(EXECUTOR);
        pool.sendFundsToUser(USDC, 100e6, payable(FRESH), hex"c0ffee01", 0, 137);
        uint256 gained = IERC20(USDC).balanceOf(FRESH) - before;
        emit log_named_uint("receiver gained USDC", gained);
        assertGt(gained, 99e6, "executor paid out ~100 USDC");
    }

    // ------------------------------------------- S: stranded 8 ETH in provider
    function test_M_S_providers_eth_has_no_path() public {
        // The providers proxy holds 8 ETH that is NOT part of any LP reserve.
        assertEq(PROVIDERS.balance, 8 ether, "8 ETH stranded");
        assertGt(providers.totalReserve(NATIVE), 3 ether, "native reserve is ~3.5 ETH");
        assertLt(providers.totalReserve(NATIVE), 4 ether, "native reserve is ~3.5 ETH");
        // Reserve claims are paid from the POOL balance, not from the providers.
        uint256 provBefore = PROVIDERS.balance;
        uint256 poolBefore = POOL.balance;
        uint256 nftId = _findLiveNft(NATIVE, 0.05 ether);
        address owner = lpToken.ownerOf(nftId);
        vm.prank(owner);
        providers.removeLiquidity(nftId, 0.05 ether);
        assertEq(PROVIDERS.balance, provBefore, "providers ETH untouched by LP withdrawal");
        assertLt(POOL.balance, poolBefore, "pool paid the withdrawal");
        uint256 poolAfterRemoval = POOL.balance;

        // Deposits only forward msg.value; they never move the pre-existing balance.
        vm.deal(FRESH, 1 ether);
        vm.prank(FRESH);
        providers.addNativeLiquidity{value: 1 ether}();
        assertEq(PROVIDERS.balance, provBefore, "providers still 8 ETH after deposit");
        assertEq(POOL.balance, poolAfterRemoval + 1 ether, "pool got exactly the deposit");
    }
}
