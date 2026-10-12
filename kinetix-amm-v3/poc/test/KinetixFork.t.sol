// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "forge-std/Test.sol";

// Kinetix AMM V3 (Kava + Base) — read-only fork verification.
// All checks are view/call-only on live state; nothing is broadcast.

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

interface IPool {
    function liquidity() external view returns (uint128);
    function protocolFees() external view returns (uint128, uint128);
    function collect(address recipient, int24 tickLower, int24 tickUpper, uint128 amount0Requested, uint128 amount1Requested)
        external returns (uint128, uint128);
    function collectProtocol(address recipient, uint128 amount0Requested, uint128 amount1Requested)
        external returns (uint128, uint128);
}

interface IFactory {
    function owner() external view returns (address);
    function getPool(address, address, uint24) external view returns (address);
}

interface INPM {
    struct DecreaseLiquidityParams { uint256 tokenId; uint128 liquidity; uint256 amount0Min; uint256 amount1Min; uint256 deadline; }
    struct CollectParams { uint256 tokenId; address recipient; uint128 amount0Max; uint128 amount1Max; }
    function ownerOf(uint256) external view returns (address);
    function balanceOf(address) external view returns (uint256);
    function factory() external view returns (address);
    function decreaseLiquidity(DecreaseLiquidityParams calldata) external payable returns (uint256, uint256);
    function collect(CollectParams calldata) external payable returns (uint256, uint256);
    function transferFrom(address, address, uint256) external;
}

interface IStaker {
    function nonfungiblePositionManager() external view returns (address);
    function deposits(uint256) external view returns (address, uint128, address, address, int24, int24);
}

interface IArrakisVault {
    function withdraw(uint256 burnAmount, address receiver, address owner, uint256[4] calldata minAmounts) external;
}

contract KinetixForkTest is Test {
    // canonical Uniswap V3 pool init code hash (v3-core v1.0.0, solc 0.7.6, runs 800, bytecodeHash none)
    bytes32 constant INIT_HASH = 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54;

    address constant KAVA_FACTORY = 0x2dBB6254231C5569B6A4313c6C1F5Fe1340b35C2;
    address constant BASE_FACTORY = 0xdDF5a3259a88Ab79D5530eB3eB14c1C92CD97FCf;
    address constant NFPM = 0x8dB08eD2b460643974C64BE42087903470Df6a54;
    address constant STAKER = 0x011C835aBF4BCeD2ECb51C466E157f467F6dB5AD;
    address constant OWNER_EOA = 0xD6F5c0737026E0E662E514eE0e08cCE6B2Bf5c4a;
    address constant SAFE = 0x7D5CEA2e5fBDFecca8CcfbFe85AC021C817a7f38;
    address constant WAGMI_POOL = 0xc81Fde7F51e432EA173e87BB3d0c5670fC7b7FF9;
    address constant USDT_WKAVA_POOL = 0x91098391cD135A95f775752F8cBf59286729a948;
    address constant WKAVA = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b;
    address constant USDT_KAVA = 0x919C1c267BC06a7039e03fcc2eF738525769109c;

    uint256 constant POS_SAFE = 511;
    uint256 constant POS_USER = 849;
    address constant POS_USER_OWNER = 0x9A2EeDd3FadD57563e20aA608Ef8F07916eD23D9;
    uint128 constant POS_USER_LIQ = 24431246865836;

    string constant KAVA_RPC = "https://kava-evm-rpc.publicnode.com";
    string constant KAVA_RPC2 = "https://rpc.ankr.com/kava_evm";
    string constant BASE_RPC = "https://base-rpc.publicnode.com";

    function _fork(string memory a, string memory b) internal {
        try vm.createSelectFork(a) {} catch {
            vm.createSelectFork(b);
        }
    }

    function _kava() internal { _fork(vm.envOr("KAVA_RPC_URL", KAVA_RPC), KAVA_RPC2); }

    function _create2(address factory, address t0, address t1, uint24 fee) internal pure returns (address) {
        bytes32 salt = keccak256(abi.encode(t0, t1, fee));
        return address(uint160(uint256(keccak256(abi.encodePacked(hex"ff", factory, salt, INIT_HASH)))));
    }

    // ------------------------------------------------------------------
    // 1. live state (Kava)
    // ------------------------------------------------------------------
    function test_kava_live_state() public {
        _kava();
        console.log("kava block", block.number);
        IFactory f = IFactory(KAVA_FACTORY);
        address owner = f.owner();
        assertEq(owner, OWNER_EOA, "factory owner");
        assertEq(owner.code.length, 0, "owner must be an EOA");
        assertEq(INPM(NFPM).factory(), KAVA_FACTORY, "NFPM factory");
        assertEq(IStaker(STAKER).nonfungiblePositionManager(), NFPM, "staker NFPM");
        uint256 wkavaBal = IERC20(WKAVA).balanceOf(WAGMI_POOL);
        uint256 usdtBal = IERC20(USDT_KAVA).balanceOf(USDT_WKAVA_POOL);
        console.log("WAGMI/WKAVA pool WKAVA", wkavaBal);
        console.log("USDt/WKAVA pool USDt", usdtBal);
        assertGt(wkavaBal, 1_200_000e18, "top pool holds >1.2M WKAVA");
        assertGt(usdtBal, 500e6, "USDt/WKAVA pool holds >500 USDt");
        (uint128 pf0, uint128 pf1) = IPool(WAGMI_POOL).protocolFees();
        console.log("protocolFees WAGMI", pf0);
        console.log("protocolFees WKAVA", pf1);
    }

    // ------------------------------------------------------------------
    // 2. all Kava pools sit at canonical Uniswap V3 CREATE2 addresses
    // ------------------------------------------------------------------
    function test_kava_create2_canonical_all_pools() public {
        _kava();
        (address[] memory t0, address[] memory t1, uint24[] memory fee, address[] memory pool) = kavaPools();
        console.log("kava pools checked", pool.length);
        IFactory f = IFactory(KAVA_FACTORY);
        for (uint256 i = 0; i < pool.length; i++) {
            assertEq(_create2(KAVA_FACTORY, t0[i], t1[i], fee[i]), pool[i], "create2 mismatch");
            assertEq(f.getPool(t0[i], t1[i], fee[i]), pool[i], "factory getPool mismatch");
        }
    }

    // ------------------------------------------------------------------
    // 3. all Base pools also canonical
    // ------------------------------------------------------------------
    function test_base_create2_canonical_all_pools() public {
        _fork(vm.envOr("BASE_RPC_URL", BASE_RPC), "https://base-rpc.publicnode.com");
        (address[] memory t0, address[] memory t1, uint24[] memory fee, address[] memory pool) = basePools();
        console.log("base pools checked", pool.length);
        IFactory f = IFactory(BASE_FACTORY);
        for (uint256 i = 0; i < pool.length; i++) {
            assertEq(_create2(BASE_FACTORY, t0[i], t1[i], fee[i]), pool[i], "create2 mismatch");
            assertEq(f.getPool(t0[i], t1[i], fee[i]), pool[i], "factory getPool mismatch");
        }
    }

    // ------------------------------------------------------------------
    // 4. attacker cannot touch LP value
    // ------------------------------------------------------------------
    function test_kava_attacker_cannot_take_lp_value() public {
        _kava();
        address attacker = makeAddr("attacker");
        INPM nfpm = INPM(NFPM);
        IPool pool = IPool(WAGMI_POOL);
        address posOwner = nfpm.ownerOf(POS_SAFE);
        assertEq(posOwner, SAFE, "position 511 owner");
        assertGt(posOwner.code.length, 0, "owner is the Gnosis Safe contract");

        uint256 aWkavaBefore = IERC20(WKAVA).balanceOf(attacker);
        uint256 pWkavaBefore = IERC20(WKAVA).balanceOf(WAGMI_POOL);

        // direct pool.collect with the position's tick range: attacker owns no pool position -> 0,0
        vm.prank(attacker);
        (uint128 c0, uint128 c1) = pool.collect(attacker, -86000, -9400, type(uint128).max, type(uint128).max);
        assertEq(c0, 0, "no token0 out");
        assertEq(c1, 0, "no token1 out");

        // protocol fees: attacker is not the factory owner
        vm.prank(attacker);
        vm.expectRevert();
        pool.collectProtocol(attacker, type(uint128).max, type(uint128).max);

        // NFPM actions on someone else's position
        vm.startPrank(attacker);
        vm.expectRevert();
        nfpm.decreaseLiquidity(INPM.DecreaseLiquidityParams(POS_SAFE, 1, 0, 0, block.timestamp));
        vm.expectRevert();
        nfpm.collect(INPM.CollectParams(POS_SAFE, attacker, type(uint128).max, type(uint128).max));
        vm.expectRevert();
        nfpm.transferFrom(SAFE, attacker, POS_SAFE);
        vm.stopPrank();

        assertEq(IERC20(WKAVA).balanceOf(attacker), aWkavaBefore, "attacker balance unchanged");
        assertEq(IERC20(WKAVA).balanceOf(WAGMI_POOL), pWkavaBefore, "pool balance unchanged");
    }

    // ------------------------------------------------------------------
    // 5. position holder self-service (H-O) still works
    // ------------------------------------------------------------------
    function test_kava_holder_self_service_works() public {
        _kava();
        INPM nfpm = INPM(NFPM);
        address holder = nfpm.ownerOf(POS_USER);
        assertEq(holder, POS_USER_OWNER, "position 849 owner");
        uint256 before = IERC20(USDT_KAVA).balanceOf(holder) + IERC20(WKAVA).balanceOf(holder);
        vm.startPrank(holder);
        (uint256 amt0, uint256 amt1) = nfpm.decreaseLiquidity(
            INPM.DecreaseLiquidityParams(POS_USER, POS_USER_LIQ / 2, 0, 0, block.timestamp)
        );
        (uint256 col0, uint256 col1) = nfpm.collect(
            INPM.CollectParams(POS_USER, holder, type(uint128).max, type(uint128).max)
        );
        vm.stopPrank();
        console.log("decreased", amt0, amt1);
        console.log("collected", col0, col1);
        uint256 afterBal = IERC20(USDT_KAVA).balanceOf(holder) + IERC20(WKAVA).balanceOf(holder);
        assertGt(afterBal, before, "holder received tokens (self-service works)");
    }

    // ------------------------------------------------------------------
    // 6. protocol fees are owner-only (P)
    // ------------------------------------------------------------------
    function test_kava_protocol_fees_owner_only() public {
        _kava();
        address owner = IFactory(KAVA_FACTORY).owner();
        (uint128 pf0, uint128 pf1) = IPool(WAGMI_POOL).protocolFees();
        assertGt(uint256(pf0) + uint256(pf1), 0, "protocol fees accrued");
        vm.prank(owner);
        (uint128 got0, uint128 got1) = IPool(WAGMI_POOL).collectProtocol(owner, type(uint128).max, type(uint128).max);
        console.log("owner collected protocol fees", got0, got1);
        assertGt(uint256(got0) + uint256(got1), 0, "owner can collect protocol fees");
    }

    // ------------------------------------------------------------------
    // 7. staker holds nothing; no staked positions exist
    // ------------------------------------------------------------------
    function test_kava_staker_empty() public {
        _kava();
        assertEq(INPM(NFPM).balanceOf(STAKER), 0, "staker owns no position NFTs");
        // deployed staker returns a 4-word deposit tuple (older staker variant); decode shape-agnostically:
        (bool ok, bytes memory ret) = STAKER.staticcall(abi.encodeWithSignature("deposits(uint256)", POS_SAFE));
        assertTrue(ok, "deposits() call ok");
        console.log("deposits(511) return bytes", ret.length);
        for (uint256 i = 0; i < ret.length; i++) {
            assertEq(uint8(ret[i]), 0, "empty deposit entry");
        }
    }

    // ------------------------------------------------------------------
    // 8. third-party vault in a Kinetix pool: attacker without shares cannot withdraw
    // ------------------------------------------------------------------
    function test_kava_thirdparty_vault_attacker_withdraw_reverts() public {
        _kava();
        address attacker = makeAddr("attacker2");
        IArrakisVault vault = IArrakisVault(0xDb7608614dfdD9feBFC1b82A7609420fa7B3Bc34); // "xUSDT-WKAVA" Arrakis-style vault
        uint256[4] memory mins;
        vm.prank(attacker);
        vm.expectRevert();
        vault.withdraw(1, attacker, attacker, mins);
    }

    function kavaPools() internal pure returns (address[] memory t0, address[] memory t1, uint24[] memory fee, address[] memory pool) {
        t0 = new address[](155);
        t1 = new address[](155);
        fee = new uint24[](155);
        pool = new address[](155);
        t0[0] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[0] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[0] = 10000; pool[0] = 0x62046814cf1B90Acb28eb22d3dc229f59b0BC560;
        t0[1] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[1] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[1] = 500; pool[1] = 0x91098391cD135A95f775752F8cBf59286729a948;
        t0[2] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[2] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[2] = 500; pool[2] = 0x82aE208c257E9e615C87bC7F6C7D7aFbEa0a54f7;
        t0[3] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[3] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[3] = 500; pool[3] = 0x40f45CC3DeC7C843C6f7c8B478fF53ADF7Aa7488;
        t0[4] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; t1[4] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[4] = 500; pool[4] = 0x112C4f94deB8Ba95668712c46E35f3e10cB95026;
        t0[5] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[5] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[5] = 500; pool[5] = 0xF08A8cc4F3e1883e41177cb956E577d389B43FDd;
        t0[6] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[6] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[6] = 500; pool[6] = 0xED72131197b6DFb3F1862299ac4a6b0a0379168F;
        t0[7] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[7] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[7] = 500; pool[7] = 0xA11Df70789c4fe546fe347F2a9705f6fCcBC05Ca;
        t0[8] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[8] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[8] = 500; pool[8] = 0x9E1b951156EC830F1bb7925777Ec3491C201ecf7;
        t0[9] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[9] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[9] = 100; pool[9] = 0xB5D2Bc223cb96B61133A363f33535a9E0bAcE781;
        t0[10] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[10] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[10] = 100; pool[10] = 0x2c0b777dBa715e41E40b2A784706c3aD9ce72684;
        t0[11] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[11] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[11] = 100; pool[11] = 0x14D87d5925F9f014ce3A5DA36e9F8E74DDd38Bdd;
        t0[12] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[12] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[12] = 3000; pool[12] = 0xF3dD2Ef9FCDAcCF8D3634ee1953cEd8A19004B7E;
        t0[13] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[13] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[13] = 3000; pool[13] = 0x2b4809aA34beA65Dd426EEcDfBb91854Af3e2fD6;
        t0[14] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[14] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[14] = 3000; pool[14] = 0xDd6B35fAD6E868c779574890D9dD4d39E31396E1;
        t0[15] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; t1[15] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[15] = 500; pool[15] = 0x2568C313383b8B3dCffE01FbD22Ee2f7b272CF31;
        t0[16] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[16] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[16] = 500; pool[16] = 0x5498d64A1cF9f94a7932C939aFc66Aea62877734;
        t0[17] = 0x9d9682577CA889c882412056669bd936894663fd; t1[17] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[17] = 10000; pool[17] = 0x3BBD1f0C549914e72A7d9F6be01d304cE9AeAC3E;
        t0[18] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[18] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[18] = 3000; pool[18] = 0x033dA095f5B711aB2bF0B49E41ED887195253C45;
        t0[19] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[19] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[19] = 100; pool[19] = 0xb1B887c088293D85fF598B86F923721B240cFA47;
        t0[20] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[20] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[20] = 100; pool[20] = 0xD8acab50519644A05e63D5e0e8096d9680CaB52F;
        t0[21] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[21] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[21] = 500; pool[21] = 0x4eC0C5bcc73E67224C6A79c2574Fe8E92e890cbE;
        t0[22] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[22] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[22] = 500; pool[22] = 0x4E49faEA43C089eEC13499070F989E688cBf5ED1;
        t0[23] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[23] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[23] = 500; pool[23] = 0x5C92A9f204885408b6F49554ACdbB6e56E16e019;
        t0[24] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[24] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[24] = 500; pool[24] = 0xBE7eEb9D7BFEeD573aA13659af0d695DDba084a9;
        t0[25] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[25] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[25] = 500; pool[25] = 0x5Ab16173E4A22E9708fdC4d34A1848f2d3D1A145;
        t0[26] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[26] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[26] = 3000; pool[26] = 0x1c7fed18Ce55EC2F8A02Db59EF3be6aBb2B3449E;
        t0[27] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; t1[27] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[27] = 3000; pool[27] = 0x64F9DBbd8f8CD2455f655b6b629169e6c067F7DA;
        t0[28] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[28] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[28] = 3000; pool[28] = 0x63898910F04a5ADDA178012249F4A3FDE509262A;
        t0[29] = 0xb51eFaF2f7aFb8a2F5Be0b730281E414FB487636; t1[29] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[29] = 100; pool[29] = 0x768AcEa16a2D7f5Cb236B53c3fc5F961b38e4e35;
        t0[30] = 0xb51eFaF2f7aFb8a2F5Be0b730281E414FB487636; t1[30] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[30] = 500; pool[30] = 0xE12AE7F498Bc2eABd0250A889EC7462509f7Fe70;
        t0[31] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[31] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[31] = 10000; pool[31] = 0x12c4C0d23a863e5C197ECF891f27CbE6CB8E72eF;
        t0[32] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[32] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[32] = 10000; pool[32] = 0x4ec7927386cc6f1b78251e7799b9C7326E6BDB11;
        t0[33] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; t1[33] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[33] = 3000; pool[33] = 0x55C3F065610E005a3985e527ae0e9B2Be50413f3;
        t0[34] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[34] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[34] = 500; pool[34] = 0xe89997A72423345958453CEac6Bc671a3E1dbea4;
        t0[35] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[35] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[35] = 3000; pool[35] = 0x6E583E3e7F2c3C79E29a0Ae25C80dA6ED3c93b62;
        t0[36] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[36] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[36] = 100; pool[36] = 0xf436ea653F7FD69CFc298b44982033c319C45614;
        t0[37] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; t1[37] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[37] = 10000; pool[37] = 0xc81Fde7F51e432EA173e87BB3d0c5670fC7b7FF9;
        t0[38] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[38] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[38] = 500; pool[38] = 0xAb3B5982A9d654CBdcF71040C84e7b8edC364D94;
        t0[39] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[39] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[39] = 500; pool[39] = 0x54276D2f498bE539510718155011861285D8e8Fc;
        t0[40] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[40] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[40] = 3000; pool[40] = 0x3791aF2b9c77d44d2ccCaB511751A8Ce84f48698;
        t0[41] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[41] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[41] = 3000; pool[41] = 0x4437a2068156e8C6F4fb9dE433FC87E89DB6B178;
        t0[42] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[42] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[42] = 3000; pool[42] = 0x1c79443c656493a933BdD57ff14435939B662E02;
        t0[43] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[43] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[43] = 3000; pool[43] = 0x095632AF4c27d83DC141484F3B2c2d8Cf57d146E;
        t0[44] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[44] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[44] = 10000; pool[44] = 0x023c056295e2dDcbb7b9ee8E6Ec2ae1A383eDc38;
        t0[45] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; t1[45] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[45] = 10000; pool[45] = 0x158dCa03A3aBf5fbe621ca8b9503fa01F384a812;
        t0[46] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[46] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[46] = 10000; pool[46] = 0xb3EdB28Bc01e51B9361586bb09F4bAfbfa856b8b;
        t0[47] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[47] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[47] = 10000; pool[47] = 0x1c3f9fC8dfd097CBb06e8F3F5F3d78A88742B28C;
        t0[48] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[48] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[48] = 100; pool[48] = 0x29e8bAd98B22DfFaBD4C5D9Bf06C87FFD6C482c6;
        t0[49] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[49] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[49] = 100; pool[49] = 0xe5A86Ea0Fd2d1827aaBe9567F0876722102E0F55;
        t0[50] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[50] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[50] = 100; pool[50] = 0x775BBAEB0aD4f2D3B36B951F728E109b27A41cD6;
        t0[51] = 0x18719D2e1e57A1A64708e4550fF3DEF9d1074621; t1[51] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[51] = 500; pool[51] = 0x267D86d36dae2320D9dd5F8C109649D0f1f28ecF;
        t0[52] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[52] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[52] = 500; pool[52] = 0x9d5904A8229DEF46B60D5485bF19d57e8f089c0B;
        t0[53] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[53] = 0xe33a84cE0079C7Fe5F0E96E98572C27EB65eC29a; fee[53] = 10000; pool[53] = 0x8CdD8694a575bf0980EbB6D7B984A8b84692ef08;
        t0[54] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[54] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[54] = 500; pool[54] = 0x5b0854A3842F8064EDC70f3F6FcEf2b1533C6B79;
        t0[55] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[55] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[55] = 10000; pool[55] = 0xDED80C580CFBa109C76F564b062e16894B4Fa69f;
        t0[56] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; t1[56] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[56] = 500; pool[56] = 0xe304f1FA2c218b64711112D916011568AD690685;
        t0[57] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[57] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[57] = 100; pool[57] = 0xaf8b49bEF99BE4d69a1D582056a0a42a3fc246aD;
        t0[58] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[58] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; fee[58] = 500; pool[58] = 0xbD5639d4A76f9d0a036E9Ea7D9D4891388C905c8;
        t0[59] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[59] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[59] = 500; pool[59] = 0xc3c9b98a98511192b8C65f3fd8615Cf8Da19D72e;
        t0[60] = 0x2267a510E78a36F3b0ef61Aab47f103B079C36E9; t1[60] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[60] = 500; pool[60] = 0xF4fba3cD43007a82ce40a9e6280A54A48E928c6F;
        t0[61] = 0xb61c7093B827F114B85bF14B99E623842Dc042E9; t1[61] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[61] = 10000; pool[61] = 0x0d3eEA522f544230ea87252eC5c5ecee45B05344;
        t0[62] = 0x6dAE38e39F80c1F6D1D40224f79150AECc73f987; t1[62] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[62] = 500; pool[62] = 0x3B8Fe7E701F8642E47D531845C0fa59D1e65eAb6;
        t0[63] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[63] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[63] = 500; pool[63] = 0x2839d353507b483F58C3e4Adae5943306Cd7d791;
        t0[64] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[64] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[64] = 10000; pool[64] = 0x79fA4eEc2D90c7Ec88cA77736946Fb19c838b229;
        t0[65] = 0x47a663C082926d0d913cAcB89240c3f4bc409a88; t1[65] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[65] = 100; pool[65] = 0x5C42182025E60B91Cb4b8B4FDFd300d82B9163C4;
        t0[66] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[66] = 0xAd44fd3d2647BB561c5dcF38868e08a2781A6007; fee[66] = 100; pool[66] = 0x3F928e22f111FDCCfe6B60558e4D9BC6EEfd5Ec1;
        t0[67] = 0xb5c4423a65B953905949548276654C96fcaE6992; t1[67] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; fee[67] = 3000; pool[67] = 0xB1Cca7948AA745A9800DD55Ad4b6973fe5982E50;
        t0[68] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[68] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[68] = 3000; pool[68] = 0x22FD50D9BE73960331dC6fa7AE51936Ef70E3E88;
        t0[69] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[69] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[69] = 100; pool[69] = 0x74666C0b7b5120EB432BEB98946Aa1e5d92AdD94;
        t0[70] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[70] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[70] = 10000; pool[70] = 0x32b26654E5731cd3873a4B020B38339f4d7Efe29;
        t0[71] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[71] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[71] = 10000; pool[71] = 0x6983CfFf4A0cE3DDF9e22dB92275Aee3b43cA658;
        t0[72] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[72] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[72] = 500; pool[72] = 0x5736E5318d64283dD9f90f621057e98DA6Fa7660;
        t0[73] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[73] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[73] = 3000; pool[73] = 0xb38E35e1D0DDC73B8de9272F2BCF9Bc93432459C;
        t0[74] = 0x0b93109d05Ef330acD2c75148891cc61D20C3EF1; t1[74] = 0x31f8d38df6514b6cc3C360ACE3a2EFA7496214f6; fee[74] = 10000; pool[74] = 0x7dE14d2Af321D7b04625f5803CcA2e24f80B3eF6;
        t0[75] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[75] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[75] = 10000; pool[75] = 0x0f0ce7e982a8e969227b7A4F4C1264882d1a657A;
        t0[76] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[76] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[76] = 3000; pool[76] = 0x040BB0F0Dd598FfD74092A28B0043017dee97B2e;
        t0[77] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[77] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[77] = 500; pool[77] = 0x9BED0Fb3050352F8f7034F1938CF3D8461E2FcF8;
        t0[78] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[78] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[78] = 10000; pool[78] = 0x8dC4A3df6AE668E3CD2D813D5A3B4dD6f9c8135C;
        t0[79] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[79] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[79] = 500; pool[79] = 0xf790e8DF1780625a208E9e63595F3903eE5A3945;
        t0[80] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[80] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[80] = 500; pool[80] = 0x58A0bd846026EAb40C6B7FA63986D7AE14789472;
        t0[81] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[81] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[81] = 100; pool[81] = 0xd750FCc5a91F206455aF1B348A4988bE8Afc6973;
        t0[82] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[82] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[82] = 3000; pool[82] = 0x295a4e2b5e8157E72E2102b9bB3aCc31b7044B41;
        t0[83] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; t1[83] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[83] = 500; pool[83] = 0xd25ECC9fEF2aF28c9dd7D975317753Ed558247b6;
        t0[84] = 0xb5c4423a65B953905949548276654C96fcaE6992; t1[84] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[84] = 500; pool[84] = 0xF197A6BF357a9759E3A21610Dbb436aa67CDc1A9;
        t0[85] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[85] = 0xCe82db637A2D750380ef27063518eAa263fbe10E; fee[85] = 10000; pool[85] = 0xC48da87CB9Ca48aee675fe74300AD07435B8D0D7;
        t0[86] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[86] = 0xf3C091ed43de9c270593445163a41A876A0bb3dd; fee[86] = 500; pool[86] = 0x381435Df5Cf8e18dFbb0502B2Bf5174bb709b2EA;
        t0[87] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[87] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[87] = 100; pool[87] = 0x2be5D5C00C354ddf65D662C34501c2E6F2A40420;
        t0[88] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[88] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[88] = 10000; pool[88] = 0x8Fb816716Cba23B5CafD5b5ec521D653d4a48312;
        t0[89] = 0x7f5373AE26c3E8FfC4c77b7255DF7eC1A9aF52a6; t1[89] = 0xEB466342C4d449BC9f53A865D5Cb90586f405215; fee[89] = 3000; pool[89] = 0xa5E0d9B999fe102fE96903788468012dC4D468D5;
        t0[90] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[90] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[90] = 100; pool[90] = 0xFe8bCa3b8eCa76804Ae5E4aC7C0938ca6A342ACD;
        t0[91] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[91] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[91] = 100; pool[91] = 0xDda7C501A171896657971766aE02df224419dfd3;
        t0[92] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[92] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; fee[92] = 3000; pool[92] = 0x27C52E029da3467dA6A8195E351230BDEdb438b2;
        t0[93] = 0x0018D96C579121a94307249d47F053E2D687b5e7; t1[93] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[93] = 10000; pool[93] = 0xfDAEF2c3e8C53C8A7aa9592E20aC13aD4a036C9F;
        t0[94] = 0x0018D96C579121a94307249d47F053E2D687b5e7; t1[94] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; fee[94] = 10000; pool[94] = 0xc0135341D5aa2Cfcc9d7edF082CFe8fc00B162f3;
        t0[95] = 0x0018D96C579121a94307249d47F053E2D687b5e7; t1[95] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[95] = 10000; pool[95] = 0xD0289611F90f288643076D9aAC9452c59780E010;
        t0[96] = 0x0018D96C579121a94307249d47F053E2D687b5e7; t1[96] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[96] = 500; pool[96] = 0x13Ae0d148011504B0B67a83e46Cd9Ba01378e3Ea;
        t0[97] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[97] = 0xCe82db637A2D750380ef27063518eAa263fbe10E; fee[97] = 10000; pool[97] = 0xa6913a8D6da32A5c84e452E5DCD3786e81439071;
        t0[98] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[98] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; fee[98] = 10000; pool[98] = 0xA2D8585a36BE1Dd844690ABbdd10A007cBCd4f89;
        t0[99] = 0x061BeA4a986906E4FD7450158D0FbF7c0d3e7128; t1[99] = 0x0c3B74Fbc76b477813ca3747f193eD3384d640e2; fee[99] = 3000; pool[99] = 0x9d068116721f16bFAA1a988ae6E9a7F131EcD1aB;
        t0[100] = 0x2112d1998a042b55755e7d6604ed3ff62C4168EF; t1[100] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[100] = 10000; pool[100] = 0xc8ef293b4C9027Fa4349a41FB57a627C8Fe00c05;
        t0[101] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; t1[101] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; fee[101] = 100; pool[101] = 0xbb4b12a7025834c20C9c7e814DC52a3bc27CE188;
        t0[102] = 0x471EE749bA270eb4c1165B5AD95E614947f6fCeb; t1[102] = 0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D; fee[102] = 500; pool[102] = 0xA8119181796f3425cec285057A60E99CCa18B17a;
        t0[103] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; t1[103] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[103] = 10000; pool[103] = 0xbe3739D59DFc3d634405e7161f0865980863EF2E;
        t0[104] = 0x31f8d38df6514b6cc3C360ACE3a2EFA7496214f6; t1[104] = 0xC421df773e7b8B79ced7353585D6E3D98D8aeC3e; fee[104] = 100; pool[104] = 0x9c6684aE52afB145C42Ab0Ccfc55eFbE9eD1a53c;
        t0[105] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[105] = 0xC421df773e7b8B79ced7353585D6E3D98D8aeC3e; fee[105] = 100; pool[105] = 0x64757D5db31c62BD9791767A7d25Fe0899D4b1D3;
        t0[106] = 0xC421df773e7b8B79ced7353585D6E3D98D8aeC3e; t1[106] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[106] = 100; pool[106] = 0x2001A2FDB61EEB4F63FF7cc4a11FE86dc2F71311;
        t0[107] = 0x0b93109d05Ef330acD2c75148891cc61D20C3EF1; t1[107] = 0xC421df773e7b8B79ced7353585D6E3D98D8aeC3e; fee[107] = 100; pool[107] = 0x47410475A463D301Cf179232537a5F78143E4932;
        t0[108] = 0x0b93109d05Ef330acD2c75148891cc61D20C3EF1; t1[108] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[108] = 100; pool[108] = 0xF2Ce7541a03Eb8f90EA7BD9c76681B9DfD7b1872;
        t0[109] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[109] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[109] = 500; pool[109] = 0x521bEB144ED7f4c1b21748B2dF64b779d74445DF;
        t0[110] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; t1[110] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[110] = 3000; pool[110] = 0x8b43fF74494257618b13C5c82D98c89a87C4DEe5;
        t0[111] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[111] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; fee[111] = 10000; pool[111] = 0xef1dcab5c9e74f436e87DF19b7C6D8a487B8Be51;
        t0[112] = 0x52369B1539EA8F4e1eadEEF18D85462Dcf9a3658; t1[112] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; fee[112] = 10000; pool[112] = 0x152590d76C28109fa889cf4D2aAF5D218D686BB5;
        t0[113] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[113] = 0xCe82db637A2D750380ef27063518eAa263fbe10E; fee[113] = 3000; pool[113] = 0x394b231008883ed902a160B2A399096e9A9e7AAa;
        t0[114] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[114] = 0xaf20f5f19698f1D19351028cd7103B63D30DE7d7; fee[114] = 3000; pool[114] = 0x1F41dFb1136926130A46D0376c17BF98ca86fD77;
        t0[115] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[115] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[115] = 10000; pool[115] = 0xe8E701406051821A06319C19A987B8D980e5Ba4b;
        t0[116] = 0xb5c4423a65B953905949548276654C96fcaE6992; t1[116] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[116] = 10000; pool[116] = 0xa08bd8c10e37485C2Dbe7c6d4A8429b1bb47a82b;
        t0[117] = 0x23A6486099f740B7688A0bb7AED7C912015cA2F0; t1[117] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[117] = 10000; pool[117] = 0xAda0e0A04537264c8e55e5f70e109F021664B0E8;
        t0[118] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[118] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[118] = 10000; pool[118] = 0xa4a0C009a21b7451F6C3A178465A3F720745BD3D;
        t0[119] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[119] = 0xb5c4423a65B953905949548276654C96fcaE6992; fee[119] = 100; pool[119] = 0xA235091338aa3A71e8Ba1BDF07aE02cfdC802C48;
        t0[120] = 0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D; t1[120] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[120] = 500; pool[120] = 0xC0b779B0d4C0C638cce2e63Bfa00C98bCd6C5e7C;
        t0[121] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[121] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; fee[121] = 3000; pool[121] = 0x8c4379f0d0513a89d9320eebD0F98DA9Ed844365;
        t0[122] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[122] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; fee[122] = 10000; pool[122] = 0xa2Acc499cC89806d12BF1E80Eeda8f19A19f1226;
        t0[123] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; t1[123] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[123] = 500; pool[123] = 0x2aaD84b24C1f0a9945f55994C5a783F61966665B;
        t0[124] = 0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D; t1[124] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[124] = 100; pool[124] = 0x9Ed71Dd21DeaE6556a8BBa6CD180ec55a1cdf221;
        t0[125] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[125] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[125] = 3000; pool[125] = 0xF31bBbf003bE44a5438c6C8C3c34B350247bd502;
        t0[126] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[126] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[126] = 3000; pool[126] = 0x590Ca9994c810b2D0fB184fcE85d714aC9458bD8;
        t0[127] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[127] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[127] = 3000; pool[127] = 0xd23c0efBe7d908F20e33087C6D75672e46708e1F;
        t0[128] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[128] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; fee[128] = 3000; pool[128] = 0x3e3eaaca3D5Bb0EC183d4D3678FfEC1c698c347D;
        t0[129] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[129] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[129] = 100; pool[129] = 0x5992fEF5330f623c4a5bfD1E9A031A667133B06F;
        t0[130] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; t1[130] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[130] = 100; pool[130] = 0x227Af32b72D6DFA0355C4F8B48Aec57e02A45d6d;
        t0[131] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[131] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[131] = 100; pool[131] = 0xD4B98533A7E9cf7EB951bCc2fdEdce04e77b10c7;
        t0[132] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; t1[132] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[132] = 500; pool[132] = 0xf3237C02fe3e430d94E278b38F7524D0fc868758;
        t0[133] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; t1[133] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; fee[133] = 500; pool[133] = 0x7B4A9CCa38aAC3d4731Af91DE4B464355295a7d0;
        t0[134] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; t1[134] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[134] = 500; pool[134] = 0x19C15a047F927cB3E664a5EbAA25328858E4D15d;
        t0[135] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[135] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[135] = 500; pool[135] = 0x6D5f7230d5aB089690AE4828c1b9eAc7ceFC5A97;
        t0[136] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[136] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; fee[136] = 500; pool[136] = 0xA516C105691f33034728E3e5b658D841b37870Dc;
        t0[137] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[137] = 0xE3F5a90F9cb311505cd691a46596599aA1A0AD7D; fee[137] = 10000; pool[137] = 0x21B4b1bE702c02b8a17d6513883344e4D36756BC;
        t0[138] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; t1[138] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[138] = 10000; pool[138] = 0xe45Be23197e3eDDC11b66cb104cA796feCd2C828;
        t0[139] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[139] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[139] = 10000; pool[139] = 0xca00762F7B919782c8527b93247abbe8C328F491;
        t0[140] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[140] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; fee[140] = 10000; pool[140] = 0xFCf27f5B7d5EC677048F0185eCCe9C76414A1CBf;
        t0[141] = 0x75C5f6D32d8Ef3a4f0F43F7792Aa08e8678972F9; t1[141] = 0x818ec0A7Fe18Ff94269904fCED6AE3DaE6d6dC0b; fee[141] = 10000; pool[141] = 0x90bc8A5Ff3b62b675F857B29b9067E49Fc2cD22D;
        t0[142] = 0x923979a96860e99876Aff8fa82d9B0320a35C285; t1[142] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[142] = 100; pool[142] = 0xD03DD80ce1998928a434Cb84342AEaE775935121;
        t0[143] = 0xb5c4423a65B953905949548276654C96fcaE6992; t1[143] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[143] = 10000; pool[143] = 0x4Da2eF593D5bF2F5448336017F13D11600BAa6EB;
        t0[144] = 0x004C1f7d2c30eDEB3d64dDB37568AddaDE24c93c; t1[144] = 0xDb0E1e86B01c4ad25241b1843E407Efc4D615248; fee[144] = 500; pool[144] = 0x103c9106d40a57d454Ab7f08B2Aef76284BD7C09;
        t0[145] = 0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D; t1[145] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[145] = 500; pool[145] = 0xE3F469670AD64a212B74390605F83A75e4ac9E32;
        t0[146] = 0x7C598c96D02398d89FbCb9d41Eab3DF0C16F227D; t1[146] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[146] = 10000; pool[146] = 0x15Daeb4C7F5D393c887cBd15F06A8b16F6DC0c88;
        t0[147] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[147] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; fee[147] = 10000; pool[147] = 0x7b14D7d590A7Cc45881BDb798Dc82d17daAed733;
        t0[148] = 0x919C1c267BC06a7039e03fcc2eF738525769109c; t1[148] = 0xB44a9B6905aF7c801311e8F4E76932ee959c663C; fee[148] = 10000; pool[148] = 0x5bF21A97F3158cD9F9DAAfD50d7628296F64766D;
        t0[149] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; t1[149] = 0xfA9343C3897324496A05fC75abeD6bAC29f8A40f; fee[149] = 3000; pool[149] = 0xe0070dcfB0C7B3091c869877e1036391EFbB7eC6;
        t0[150] = 0xb5c4423a65B953905949548276654C96fcaE6992; t1[150] = 0xc86c7C0eFbd6A49B35E8714C5f59D99De09A225b; fee[150] = 3000; pool[150] = 0xcE9a35ccf1C043740841ed8DB593F42D3EFf241e;
        t0[151] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[151] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[151] = 3000; pool[151] = 0x997669f1F85fd9C25089c62152c4647F4d2B2Dd9;
        t0[152] = 0x15932E26f5BD4923d46a2b205191C4b5d5f43FE3; t1[152] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; fee[152] = 10000; pool[152] = 0x09FAe04548E479D582C9869FDC3539C5308b4a0F;
        t0[153] = 0xb829b68f57CC546dA7E5806A929e53bE32a4625D; t1[153] = 0xC19281F22A075E0F10351cd5D6Ea9f0AC63d4327; fee[153] = 10000; pool[153] = 0x8E0Fa1481627304aBcCf47d3d95F9508C662dB45;
        t0[154] = 0x2DfD4dE5AE386Cd3f4fC8e2cb39240852E47F5E8; t1[154] = 0xC19281F22A075E0F10351cd5D6Ea9f0AC63d4327; fee[154] = 10000; pool[154] = 0x7FaBF921B9dD4F2d7e7c42b9b78F91A51dd88e9c;
    }

    function basePools() internal pure returns (address[] memory t0, address[] memory t1, uint24[] memory fee, address[] memory pool) {
        t0 = new address[](21);
        t1 = new address[](21);
        fee = new uint24[](21);
        pool = new address[](21);
        t0[0] = 0x4200000000000000000000000000000000000006; t1[0] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[0] = 100; pool[0] = 0x2a3a35552660Abfd34b74FCCd178A77861E60710;
        t0[1] = 0x65a2508C429a6078a7BC2f7dF81aB575BD9D9275; t1[1] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[1] = 500; pool[1] = 0xF64F81a06F7FE9f911F153699105BE07F9E38b5A;
        t0[2] = 0x4200000000000000000000000000000000000006; t1[2] = 0x65a2508C429a6078a7BC2f7dF81aB575BD9D9275; fee[2] = 100; pool[2] = 0x81DE48Ee3636708f1f69fA0f1D68c5A0C1A1A06B;
        t0[3] = 0x4621b7A9c75199271F773Ebd9A499dbd165c3191; t1[3] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[3] = 100; pool[3] = 0x8217D73A234bDF415505fe97641216b41dEA7416;
        t0[4] = 0x4200000000000000000000000000000000000006; t1[4] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[4] = 3000; pool[4] = 0x1Fb5a42B94e7063806A24Fef7dff04a588288058;
        t0[5] = 0x4200000000000000000000000000000000000006; t1[5] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA; fee[5] = 3000; pool[5] = 0x7F013367226e39e28B7aB5a0C562E818Cd6a4b09;
        t0[6] = 0x4200000000000000000000000000000000000006; t1[6] = 0xc1CBa3fCea344f92D9239c08C0568f6F2F0ee452; fee[6] = 3000; pool[6] = 0x88116969b61Db9D2FCaba9CfEA024Bb46678f240;
        t0[7] = 0x2Ae3F1Ec7F1F5012CFEab0185bfc7aa3cf0DEc22; t1[7] = 0x4200000000000000000000000000000000000006; fee[7] = 3000; pool[7] = 0x60149eB52bBc77efabcfbb00dcf857A71fBeef15;
        t0[8] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[8] = 0x4200000000000000000000000000000000000006; fee[8] = 3000; pool[8] = 0x039D94E45FB975bde441E33c38eC85DdC8A260Ca;
        t0[9] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[9] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA; fee[9] = 3000; pool[9] = 0x50d977b5Ec10A820EE46e1202dD4503C195f6407;
        t0[10] = 0x1a35EE4640b0A3B87705B0A4B45D227Ba60Ca2ad; t1[10] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[10] = 3000; pool[10] = 0xB158f9605e634c0979803a8C0adA704962541292;
        t0[11] = 0x4200000000000000000000000000000000000006; t1[11] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[11] = 500; pool[11] = 0xA4D9B5f9f19aCa8453e2ec6b51EAf353AEde4c9e;
        t0[12] = 0x4200000000000000000000000000000000000006; t1[12] = 0x50c5725949A6F0c72E6C4a641F24049A917DB0Cb; fee[12] = 500; pool[12] = 0xc7e9f0826c2894561C3f9a153A3D527171cbDb67;
        t0[13] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; t1[13] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA; fee[13] = 500; pool[13] = 0x4462a52c997a49aa4eFa2cFaF15826Bc2131B935;
        t0[14] = 0x4200000000000000000000000000000000000006; t1[14] = 0x940181a94A35A4569E4529A3CDfB74e38FD98631; fee[14] = 500; pool[14] = 0x146Edc9Fb76Acb2552Af2c202602b1A45A77dcd5;
        t0[15] = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b; t1[15] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[15] = 3000; pool[15] = 0xfc0CedafBFe0B699578e4B5C0C82A9fCcdb23f7f;
        t0[16] = 0x236aa50979D5f3De3Bd1Eeb40E81137F22ab794b; t1[16] = 0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913; fee[16] = 500; pool[16] = 0x788273F05B7DEc28264574407f1873E7f008B677;
        t0[17] = 0x4200000000000000000000000000000000000006; t1[17] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA; fee[17] = 500; pool[17] = 0x4c901EF2CEF6312BAB996354f1Cb12B7759c452D;
        t0[18] = 0x65a2508C429a6078a7BC2f7dF81aB575BD9D9275; t1[18] = 0xDE5ed76E7c05eC5e4572CfC88d1ACEA165109E44; fee[18] = 500; pool[18] = 0x300D6F07532E99C71648FD78232B050B41438cB7;
        t0[19] = 0x4200000000000000000000000000000000000006; t1[19] = 0xd9aAEc86B65D86f6A7B5B1b0c42FFA531710b6CA; fee[19] = 100; pool[19] = 0x6094AE5e9Bca8365fb51c59EC86219042e7b5724;
        t0[20] = 0x4200000000000000000000000000000000000006; t1[20] = 0x5d57C29768f054821603462Cef420adaF7E0eF2c; fee[20] = 10000; pool[20] = 0xF1DA39bf32DFE4188B91c533878B3bf005340516;
    }

}
