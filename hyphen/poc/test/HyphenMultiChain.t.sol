// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {IPool, IProviders, ILPToken, IExecutorManager, IERC20, Hyphen} from "../src/IHyphen.sol";

/// @notice Same gate checks on Polygon and Arbitrum forks. Skipped when the CI RPC env
///         vars are missing. Read-only; fork only.
contract HyphenMultiChainPoC is Test {
    address constant FRESH = address(0xF0E57);

    function _rpc(string memory key) internal view returns (string memory) {
        string memory v = vm.envOr(key, string(""));
        return v;
    }

    function test_POL_gates() public {
        string memory rpc = _rpc("POLYGON_RPC_URL");
        if (bytes(rpc).length == 0) { vm.skip(true); return; }
        vm.createSelectFork(rpc);
        IPool pool = IPool(Hyphen.POL_POOL);
        IProviders prov = IProviders(Hyphen.POL_PROVIDERS);
        ILPToken lp = ILPToken(0xc49B65e5a350292Afda1f239eBefE562668717c2);
        assertFalse(pool.paused(), "polygon pool paused");
        assertFalse(prov.paused(), "polygon prov paused");
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        pool.initialize(FRESH, FRESH, FRESH, FRESH, FRESH);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.sendFundsToUser(Hyphen.POL_PROVIDERS, 1e6, payable(FRESH), hex"aa", 0, 1);
        vm.expectRevert(bytes("Only liquidityProviders is allowed"));
        pool.transfer(Hyphen.POL_PROVIDERS, FRESH, 1);
        vm.expectRevert(bytes("ERR__TRANSACTOR_DOES_NOT_OWN_NFT"));
        prov.removeLiquidity(1, 1);
        vm.expectRevert(bytes("ERR_UNAUTHORIZED"));
        lp.mint(FRESH);
        vm.stopPrank();
        emit log_named_uint("polygon pool native", Hyphen.POL_POOL.balance);
    }

    function test_ARB_gates() public {
        string memory rpc = _rpc("ARB_RPC_URL");
        if (bytes(rpc).length == 0) { vm.skip(true); return; }
        vm.createSelectFork(rpc);
        IPool pool = IPool(Hyphen.ARB_POOL);
        IProviders prov = IProviders(Hyphen.ARB_PROVIDERS);
        ILPToken lp = ILPToken(0x126bE6a9ec71A1FeA19D2288Ba2Ce4cDC0faCB68);
        assertFalse(pool.paused(), "arb pool paused");
        assertFalse(prov.paused(), "arb prov paused");
        vm.startPrank(FRESH);
        vm.expectRevert(bytes("Initializable: contract is already initialized"));
        pool.initialize(FRESH, FRESH, FRESH, FRESH, FRESH);
        vm.expectRevert(bytes("Only executor is allowed"));
        pool.sendFundsToUser(Hyphen.ARB_PROVIDERS, 1e6, payable(FRESH), hex"aa", 0, 1);
        vm.expectRevert(bytes("Only liquidityProviders is allowed"));
        pool.transfer(Hyphen.ARB_PROVIDERS, FRESH, 1);
        vm.expectRevert(bytes("ERR__TRANSACTOR_DOES_NOT_OWN_NFT"));
        prov.removeLiquidity(1, 1);
        vm.expectRevert(bytes("ERR_UNAUTHORIZED"));
        lp.mint(FRESH);
        vm.stopPrank();
        // Arbitrum "trusted forwarder" is a self-call-only EIP712MetaTransaction contract.
        // It cannot call Hyphen, so _msgSender spoofing is impossible; the only external
        // call in its bytecode targets itself (verified by selector/disassembly analysis).
        (bool ok,) = 0x64CD353384109423a966dCd3Aa30D884C9b2E057.call(
            abi.encodeWithSignature("executeMetaTransaction(address,bytes,bytes32,bytes32,uint8)", FRESH, bytes(""), bytes32(0), bytes32(0), uint8(0))
        );
        assertFalse(ok, "arb forwarder forged meta-tx must revert");
        emit log_named_uint("arb pool native", Hyphen.ARB_POOL.balance);
    }
}
