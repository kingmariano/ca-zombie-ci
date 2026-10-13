// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

/* ------------------------------------------------------------------ */
/* Minimal interfaces (Ethereum mainnet InsureDAO v1 deployment)       */
/* ------------------------------------------------------------------ */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IVault {
    function token() external view returns (address);
    function controller() external view returns (address);
    function registry() external view returns (address);
    function ownership() external view returns (address);
    function keeper() external view returns (address);
    function balance() external view returns (uint256);
    function totalDebt() external view returns (uint256);
    function totalAttributions() external view returns (uint256);
    function valueAll() external view returns (uint256);
    function available() external view returns (uint256);
    function attributions(address) external view returns (uint256);
    function debts(address) external view returns (uint256);
    function withdrawValue(uint256, address) external returns (uint256);
    function withdrawAttribution(uint256, address) external returns (uint256);
    function withdrawAllAttribution(address) external returns (uint256);
    function transferValue(uint256, address) external returns (uint256);
    function transferAttribution(uint256, address) external;
    function borrowValue(uint256, address) external;
    function offsetDebt(uint256, address) external returns (uint256);
    function repayDebt(uint256, address) external;
    function utilize() external returns (uint256);
    function withdrawRedundant(address, address) external;
    function setController(address) external;
    function setKeeper(address) external;
}

interface IPool {
    function deposit(uint256) external returns (uint256);
    function requestWithdraw(uint256) external;
    function withdraw(uint256) external returns (uint256);
    function redeem(uint256, uint256, bytes32[] calldata) external;
    function applyCover(uint256, uint256, uint256, uint256, bytes32, string calldata, string calldata) external;
    function applyBounty(uint256, address, uint256[] calldata) external;
    function resume() external;
    function unlock(uint256) external;
    function unlockBatch(uint256[] calldata) external;
    function registerIndex(uint256) external;
    function allocateCredit(uint256) external returns (uint256);
    function withdrawCredit(uint256) external returns (uint256);
    function setPaused(bool) external;
    function marketStatus() external view returns (uint8);
    function paused() external view returns (bool);
    function totalSupply() external view returns (uint256);
    function originalLiquidity() external view returns (uint256);
    function totalLiquidity() external view returns (uint256);
    function lockedAmount() external view returns (uint256);
    function pendingEnd() external view returns (uint256);
    function indexList(uint256) external view returns (address);
    function indices(address) external view returns (uint256, uint256, uint256, bool);
    function insurances(uint256)
        external
        view
        returns (uint256, uint48, uint48, uint256, bytes32, address, address, bool);
    function valueOfUnderlying(address) external view returns (uint256);
}

interface IIndex {
    function compensate(uint256) external returns (uint256);
    function set(uint256, uint256, address, uint256) external;
    function setLeverage(uint256) external;
    function adjustAlloc() external;
    function resume() external;
    function lock() external;
    function locked() external view returns (bool);
    function paused() external view returns (bool);
    function totalLiquidity() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function allocPoints(address) external view returns (uint256);
    function targetLev() external view returns (uint256);
    function pendingPremium(address) external view returns (uint256);
}

interface ICDS {
    function deposit(uint256) external returns (uint256);
    function fund(uint256) external;
    function defund(address, uint256) external;
    function requestWithdraw(uint256) external;
    function withdraw(uint256) external returns (uint256);
    function compensate(uint256) external returns (uint256);
    function setPaused(bool) external;
    function paused() external view returns (bool);
    function crowdPool() external view returns (uint256);
    function surplusPool() external view returns (uint256);
    function totalSupply() external view returns (uint256);
}

interface IFactory {
    function createMarket(
        address,
        string calldata,
        uint256[] calldata,
        address[] calldata
    ) external returns (address);
    function templates(address) external view returns (bool, bool, bool);
    function reflist(address, uint256, address) external view returns (bool);
    function conditionlist(address, uint256) external view returns (uint256);
}

interface IRegistry {
    function isListed(address) external view returns (bool);
    function getAllMarkets() external view returns (address[] memory);
    function factory() external view returns (address);
}

interface IParameters {
    function getOwner() external view returns (address);
    function getVault(address) external view returns (address);
    function getLockup(address) external view returns (uint256);
    function getWithdrawable(address) external view returns (uint256);
    function getGrace(address) external view returns (uint256);
}

interface IPoolProxy {
    function ownership_admin() external view returns (address);
    function parameter_admin() external view returns (address);
    function emergency_admin() external view returns (address);
    function default_reporting_admin() external view returns (address);
    function reporting_admin(address) external view returns (address);
    function get_reporter(address) external view returns (address);
    function withdraw_admin_fee(address) external;
    function distribute(address, uint256) external;
    function n_distributors(address) external view returns (uint256);
    function distributor_weight(address, uint256) external view returns (uint256);
    function distributable(address, uint256) external view returns (uint256);
    function distributor_kill() external view returns (bool);
}

/* ------------------------------------------------------------------ */

contract InsureDAOTest is Test {
    /* ---------------- addresses (Ethereum mainnet) ---------------- */
    address constant VAULT = 0x131fb74C6fEdE6D6710FF224E07cE0eD8123f144;
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant REGISTRY = 0xA035Dfd0D16F238493b374a1743B77448D9C8524;
    address constant FACTORY = 0x01e6916CcFe3630364b4538d0f8C1c22E20d0F6b;
    address constant PARAMETERS = 0xdDAA6ee776B701a7729D72BBd0d4FBe4bBb66476;
    address constant OWNERSHIP = 0xf4dB9926aE02469D730A25AD7422764BBD45d36F;
    address constant POOLPROXY = 0xF4d046D8FaC6dc37b5eAFAdd34407b19De3Ba350;
    address constant SAFE_ADMIN = 0x54bE2f27E95BdAA5104960aAE7816554C0e3F056;
    address constant OPEN_TEMPLATE = 0x1dcd35cFfF8a9B44aECc4087c7847Fb7A5BE56F9; // PoolTemplate (isOpen=true)
    address constant INDEX_IMPL = 0x2B16Be3caCAeA56A6FBE613031C0F6b641DF828E;   // IndexTemplate
    address constant CDS_IMPL = 0x99f790AdA7FA1BDC2a6B976293273EE51f10a10e;     // CDSTemplate

    // funded markets
    address constant POOL_DFDF = 0xDFdFcFEdb96e0979825C6B463cb8a971fE367d5D; // $10,000 (sole EOA holder)
    address constant POOL_2245 = 0x22453153978D0C25f86010c0fd405527feD9764b; // $16,018 (100% gauge)
    address constant POOL_8C49 = 0x8c4943100bEc96e3381a544Da82B91713a4BC062; // $10,778 (gauge+EOA), locked 11,820
    address constant POOL_1CF1 = 0x1CF1195aFB01DD115647E4989e63AfE6DdD65030; // $6,600
    address constant POOL_0A3F = 0x0a3f739246846fC024F7f8dd5CBe7E0adf77760F; // $100
    address constant POOL_5880 = 0x58803187E676b180eD12b4F7d79b94cA011f4b8e; // locked 210
    address constant POOL_BDB0 = 0xbDB009e6C9dd3F77d6A7f507A4F817133677257c;
    address constant POOL_641B = 0x641BE011738C65AAc8FF3f5d4e6dedbBD7411f47;
    address constant POOL_7A18 = 0x7a1815401D91307c883eb987C1Ec16D9812aC8dc; // no index slots
    address constant INDEX_DAEA = 0xDAea5b1B6b12Ac4c4f51aB12649e96ab3aB98C3A; // $5,295
    address constant INDEX_D5F1 = 0xd5f1Ab3c61eF3a6a6f1AA6141256Aa008D2fb5A1; // $1,555
    address constant INDEX_7E08 = 0x7E08daB409Ad1bCeBc5bE5674CB2C0f3540A4d3d; // $1,200
    address constant CDS = 0x86c82E8cD8A865f01A8CeBed870Af5d58e69a439;        // $59,793

    address constant ITOKEN_HOLDER = 0xC8819c553Ff1781E017897800d75d82539A79aA2; // 100% of POOL_DFDF iTokens
    address constant LP_TOKEN = 0x1b459aec393D604Ae6468Ae3f7D7422eFA2Af1ca;     // INSURE/WETH UNI-V2
    address constant INSURE = 0xd83AE04c9eD29d6D3E6Bf720C71bc7BeB424393E;
    address constant VLINSURE = 0xA12ab76a82D118e33682AcB242180B4cc0d19E29;

    uint256 constant FORK_BLOCK = 26_185_000;

    address attacker = address(0xA11CE);
    address attacker2 = address(0xB0B);

    IVault vault = IVault(VAULT);
    IERC20 usdc = IERC20(USDC);

    function setUp() public {
        string memory rpc = vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
        vm.createSelectFork(rpc);
    }

    /* ---------------------------------------------------------------- */
    /* 1. Live state                                                     */
    /* ---------------------------------------------------------------- */
    function test_01_live_state() public view {
        assertEq(vault.token(), USDC, "vault token");
        assertEq(vault.controller(), address(0), "controller is zero");
        assertEq(vault.registry(), REGISTRY, "registry");
        assertEq(vault.ownership(), OWNERSHIP, "ownership");
        // exact state is documented at block 26,185,000; tolerate small drift at head
        assertApproxEqRel(vault.valueAll(), 122_292_300_439, 0.005e18, "valueAll");
        assertEq(vault.valueAll(), vault.balance(), "balance==valueAll");
        assertEq(vault.totalAttributions(), vault.valueAll(), "shares==value");
        assertEq(vault.totalDebt(), 0, "totalDebt");
        assertApproxEqRel(usdc.balanceOf(VAULT), 122_292_300_439, 0.005e18, "USDC in vault");
        // largest holders of attributions
        assertApproxEqRel(vault.attributions(CDS), 59_793_841_027, 0.01e18, "CDS attribution");
        assertApproxEqRel(vault.attributions(POOL_2245), 16_018_872_339, 0.01e18, "pool2245 attribution");
        assertGt(vault.attributions(POOLPROXY), 3_000_000, "PoolProxy fee attribution > 3 USDC");
        // parameters owner = PoolProxy
        assertEq(IParameters(PARAMETERS).getOwner(), POOLPROXY, "params owner");
        assertEq(IParameters(PARAMETERS).getVault(USDC), VAULT, "params getVault");
        // registry lists 29 markets
        address[] memory ms = IRegistry(REGISTRY).getAllMarkets();
        assertEq(ms.length, 29, "markets");
        assertTrue(IRegistry(REGISTRY).isListed(CDS), "cds listed");
        assertTrue(IRegistry(REGISTRY).isListed(POOL_2245), "pool listed");
        // PoolProxy admin = 3-of-5 Safe; no reporting admin set anywhere
        assertEq(IPoolProxy(POOLPROXY).ownership_admin(), SAFE_ADMIN, "admin");
        assertEq(IPoolProxy(POOLPROXY).default_reporting_admin(), address(0), "no default reporter");
        for (uint256 i = 0; i < ms.length; i++) {
            assertEq(IPoolProxy(POOLPROXY).reporting_admin(ms[i]), address(0), "no reporter");
            assertEq(IPoolProxy(POOLPROXY).get_reporter(ms[i]), address(0), "get_reporter=0");
        }
        // all markets Trading, none paused
        assertEq(IPool(POOL_2245).marketStatus(), 0, "trading");
        assertEq(IPool(POOL_2245).paused(), false, "not paused");
        assertEq(IPool(POOL_8C49).marketStatus(), 0, "trading");
        assertEq(ICDS(CDS).paused(), false, "cds not paused");
    }

    /* ---------------------------------------------------------------- */
    /* 2. Fresh attacker cannot move vault funds                         */
    /* ---------------------------------------------------------------- */
    function test_02_attacker_vault_paths_revert() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("WITHDRAW-VALUE_BADCONDITIONS"));
        vault.withdrawValue(1e6, attacker);
        vm.expectRevert(bytes("WITHDRAW-ATTRIBUTION_BADCONS"));
        vault.withdrawAttribution(1e6, attacker);
        vm.expectRevert(bytes("TRANSFER-VALUE_BADCONDITIONS"));
        vault.transferValue(1e6, attacker);
        vm.expectRevert(bytes("ERROR_REPAY_DEBT_BADCONDITIONS"));
        vault.offsetDebt(1e6, POOL_2245);
        vm.expectRevert(bytes("ERROR_ONLY_MARKET"));
        vault.borrowValue(1e6, attacker);
        vm.expectRevert(bytes("ERROR_CONTROLLER_NOT_SET"));
        vault.utilize();
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        vault.withdrawRedundant(USDC, attacker);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        vault.setController(attacker);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        vault.setKeeper(attacker);
        vm.stopPrank();
        // withdrawAllAttribution with 0 attributions is a no-op (transfers 0)
        uint256 b0 = usdc.balanceOf(attacker);
        vm.prank(attacker);
        vault.withdrawAllAttribution(attacker);
        assertEq(usdc.balanceOf(attacker), b0, "no funds received");
    }

    /* ---------------------------------------------------------------- */
    /* 3. Market admin/owner paths unreachable for fresh attacker        */
    /* ---------------------------------------------------------------- */
    function test_03_market_owner_paths_revert() public {
        bytes32 root = bytes32(uint256(1));
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IPool(POOL_2245).applyCover(0, 1, 1, block.timestamp - 1, root, "", "");
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IPool(POOL_2245).applyBounty(1e6, attacker, new uint256[](0));
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IPool(POOL_2245).setPaused(true);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        ICDS(CDS).defund(attacker, 1e6);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        ICDS(CDS).setPaused(true);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IIndex(INDEX_DAEA).set(0, 0, POOL_2245, 1);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IIndex(INDEX_DAEA).setLeverage(2e6);
        vm.stopPrank();
    }

    /* ---------------------------------------------------------------- */
    /* 4. Claim / resume / compensate gates                              */
    /* ---------------------------------------------------------------- */
    function test_04_claim_paths_dead() public {
        vm.startPrank(attacker);
        vm.expectRevert(bytes("ERROR_UNABLE_TO_RESUME"));
        IPool(POOL_2245).resume();
        vm.expectRevert(bytes("ERROR: NO_APPLICABLE_INCIDENT"));
        IPool(POOL_2245).redeem(0, 0, new bytes32[](0));
        // CDS.compensate: only registered markets
        vm.expectRevert(bytes("ERROR:UNREGISTERED"));
        ICDS(CDS).compensate(1e6);
        // Index.compensate: only pools with allocPoints
        vm.expectRevert(bytes("COMPENSATE_UNAUTHORIZED_CALLER"));
        IIndex(INDEX_DAEA).compensate(1e6);
        vm.stopPrank();
        // a listed market without allocPoints on the index also fails
        vm.prank(POOL_7A18);
        vm.expectRevert(bytes("COMPENSATE_UNAUTHORIZED_CALLER"));
        IIndex(INDEX_DAEA).compensate(1e6);
    }

    /* ---------------------------------------------------------------- */
    /* 5. The "open template" attack surface is real but inert           */
    /* ---------------------------------------------------------------- */
    function test_05_open_template_market_creation() public {
        // 1) open template is open to everyone
        (bool approval, bool isOpen, bool dup) = IFactory(FACTORY).templates(OPEN_TEMPLATE);
        assertTrue(approval && isOpen && !dup, "template open");
        assertEq(IFactory(FACTORY).conditionlist(OPEN_TEMPLATE, 0), 1e9, "min initial deposit");
        assertEq(IFactory(FACTORY).conditionlist(OPEN_TEMPLATE, 1), 0, "no forced initial");
        // allowed references: any target token, USDC, real registry, real parameters
        assertTrue(IFactory(FACTORY).reflist(OPEN_TEMPLATE, 0, address(0)), "target free");
        assertTrue(IFactory(FACTORY).reflist(OPEN_TEMPLATE, 1, USDC), "USDC underlying");
        assertTrue(IFactory(FACTORY).reflist(OPEN_TEMPLATE, 2, REGISTRY), "registry");
        assertTrue(IFactory(FACTORY).reflist(OPEN_TEMPLATE, 3, PARAMETERS), "parameters");

        // 2) attacker creates a listed market with 1,000 USDC
        deal(USDC, attacker, 1_000e6);
        address[] memory refs = new address[](4);
        refs[0] = address(0x000000000000000000000000000000000000dEaD); // arbitrary target id
        refs[1] = USDC;
        refs[2] = REGISTRY;
        refs[3] = PARAMETERS;
        uint256[] memory conds = new uint256[](2);
        conds[0] = 1e9;
        conds[1] = 1e9;
        vm.startPrank(attacker);
        usdc.approve(VAULT, 1e9);
        address m = IFactory(FACTORY).createMarket(OPEN_TEMPLATE, "poc-market", conds, refs);
        vm.stopPrank();
        assertTrue(IRegistry(REGISTRY).isListed(m), "new market is listed");
        assertEq(vault.attributions(m), 1e9, "deposit credited");
        assertEq(IERC20(m).balanceOf(attacker), 1e9, "iTokens minted 1:1");

        // 3) but the market has no code path that pays a third party:
        vm.startPrank(attacker);
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IPool(m).applyBounty(1e9, attacker, new uint256[](0));
        vm.expectRevert(bytes("ERROR: NO_APPLICABLE_INCIDENT"));
        IPool(m).redeem(0, 0, new bytes32[](0));
        // cannot steal others' funds via its own accounting
        vm.expectRevert(bytes("Caller is not allowed to operate"));
        IPool(m).applyCover(0, 1, 1, block.timestamp - 1, bytes32(0), "", "");
        vm.stopPrank();

        // 4) it can register as an index on funded pools but captures nothing
        vm.startPrank(m);
        IPool(POOL_8C49).registerIndex(1); // free slot
        IPool(POOL_8C49).allocateCredit(1e15); // fake credit (increases totalCredit)
        uint256 pending = IPool(POOL_8C49).withdrawCredit(1e15);
        assertEq(pending, 0, "no premium for fresh index");
        vm.stopPrank();
        assertEq(vault.attributions(m), 1e9, "attribution unchanged");
        assertEq(usdc.balanceOf(m), 0, "market holds no USDC");
    }

    /* ---------------------------------------------------------------- */
    /* 6. Latent (privileged) paths: documented, not attacker-reachable  */
    /* ---------------------------------------------------------------- */
    function test_06_latent_listed_market_borrow() public {
        // A LISTED market that could be induced to call borrowValue would
        // drain the vault. Today only PoolTemplate clones are listed and
        // their only borrowValue callers are owner/Payingout-gated.
        uint256 before = usdc.balanceOf(attacker);
        vm.prank(POOL_2245); // pretend the listed market executes borrowValue
        vault.borrowValue(1_000e6, attacker);
        assertEq(usdc.balanceOf(attacker), before + 1_000e6, "listed-market borrow moves funds");
        assertEq(vault.debts(POOL_2245), 1_000e6, "debt recorded");
    }

    function test_07_cds_compensate_latent() public {
        uint256 cdsAttribBefore = vault.attributions(CDS);
        // only a registered market can pull from the CDS
        vm.prank(POOL_2245);
        ICDS(CDS).compensate(1_000e6);
        assertEq(vault.attributions(CDS), cdsAttribBefore - 1_000e6, "CDS attribution pulled");
        // but no outsider can invoke it: the only listed contracts that call
        // compensate are pools, and their _liquidation is owner/resume-gated.
    }

    /* ---------------------------------------------------------------- */
    /* 8. Honest LP withdrawal works (H-O proof)                         */
    /* ---------------------------------------------------------------- */
    function test_08_honest_lp_withdraw() public {
        uint256 amount = 10_000e6;
        assertEq(IERC20(POOL_DFDF).balanceOf(ITOKEN_HOLDER), amount, "sole holder");
        vm.prank(ITOKEN_HOLDER);
        IPool(POOL_DFDF).requestWithdraw(amount);
        vm.warp(block.timestamp + 14 days + 1);
        uint256 before = usdc.balanceOf(ITOKEN_HOLDER);
        vm.prank(ITOKEN_HOLDER);
        IPool(POOL_DFDF).withdraw(amount);
        assertEq(usdc.balanceOf(ITOKEN_HOLDER), before + amount, "LP received full value");
        assertEq(vault.attributions(POOL_DFDF), 0, "market attribution burned");
    }

    /* ---------------------------------------------------------------- */
    /* 9. Permissionless fee sweep to PoolProxy (no attacker profit)     */
    /* ---------------------------------------------------------------- */
    function test_09_admin_fee_sweep_is_permissionless_but_not_profitable() public {
        uint256 proxyBefore = usdc.balanceOf(POOLPROXY);
        uint256 safeBefore = usdc.balanceOf(SAFE_ADMIN);
        vm.prank(attacker, attacker);
        IPoolProxy(POOLPROXY).withdraw_admin_fee(USDC);
        uint256 swept = usdc.balanceOf(POOLPROXY) - proxyBefore;
        assertGt(swept, 3_000_000, "fees swept (>3 USDC)");
        assertEq(IPoolProxy(POOLPROXY).distributable(USDC, 0), swept / 4, "id0 25%");
        assertEq(IPoolProxy(POOLPROXY).distributable(USDC, 1), swept / 2, "id1 50%");
        assertEq(IPoolProxy(POOLPROXY).distributable(USDC, 2), swept / 4, "id2 25%");
        // distribution attempts: attacker cannot redirect the money
        vm.startPrank(attacker, attacker);
        try IPoolProxy(POOLPROXY).distribute(USDC, 0) {} catch {}
        try IPoolProxy(POOLPROXY).distribute(USDC, 1) {} catch {}
        try IPoolProxy(POOLPROXY).distribute(USDC, 2) {} catch {}
        vm.stopPrank();
        assertEq(usdc.balanceOf(attacker), 0, "attacker gained nothing");
        assertEq(usdc.balanceOf(SAFE_ADMIN), safeBefore, "safe gained nothing via missing distribute");
    }

    /* ---------------------------------------------------------------- */
    /* 10. Expired policies can be unlocked by anyone (helps LPs only)   */
    /* ---------------------------------------------------------------- */
    function test_10_unlock_expired_policy() public {
        uint256 lockedBefore = IPool(POOL_8C49).lockedAmount();
        assertEq(lockedBefore, 11_820_670_000, "stale lock");
        (, uint48 start, uint48 end,,,,, bool status) = IPool(POOL_8C49).insurances(0);
        assertTrue(status, "policy still marked active");
        assertLt(uint256(start), uint256(end), "sane policy window");
        assertLt(uint256(end) + IParameters(PARAMETERS).getGrace(POOL_8C49), block.timestamp, "long expired");
        vm.prank(attacker);
        IPool(POOL_8C49).unlock(0);
        assertEq(IPool(POOL_8C49).lockedAmount(), 0, "lock cleared");
        (, , , , , , , bool status2) = IPool(POOL_8C49).insurances(0);
        assertFalse(status2, "policy closed");
    }

    /* ---------------------------------------------------------------- */
    /* 11. Index premium accounting is not capturable by fresh addresses */
    /* ---------------------------------------------------------------- */
    function test_11_index_premiums() public {
        // existing index holds credit in the pool with attributionDebt
        (uint256 credit,, , bool exist) = IPool(POOL_8C49).indices(INDEX_DAEA);
        assertTrue(exist);
        assertGt(credit, 0, "real index has credit");
        assertGt(IPool(POOL_8C49).totalLiquidity() - IPool(POOL_8C49).originalLiquidity(), 0, "credit present");
        // pending premium of the real index (H-O: claimable by the index itself)
        uint256 pp = IIndex(INDEX_DAEA).pendingPremium(POOL_8C49);
        emit log_named_uint("index pendingPremium (raw)", pp);
    }

    /* ---------------------------------------------------------------- */
    /* 12. Staking side: vlINSURE has no unprivileged exit               */
    /* ---------------------------------------------------------------- */
    function test_12_staking_side() public view {
        // vlINSURE holds 10.75m INSURE + its veINSURE lock; no public withdraw path
        assertEq(IERC20(INSURE).balanceOf(VLINSURE), 10_754_075_278_565_549_245_000_000);
        // INSURE has no price feed (DefiLlama coins:{}), realizable value ~0
        // LP gauge holds ~100% of the INSURE/WETH LP (0.52 WETH side)
    }
}
