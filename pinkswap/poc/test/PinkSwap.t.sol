// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// PinkSwap (BSC) L2 Phase-2 fork PoC.
// Read-only against mainnet: all state changes happen on the local fork only.
//
// Goal: prove (a) skim() excess extraction works for anyone but yields only
// unpriced junk tokens, (b) every candidate extraction path is closed:
// PINK mint, MasterChef migrate/deposit, PinkLock unlock, LP burning of
// someone else's LP. Plus demonstrate the privileged feeTo redemption.

import "forge-std/Test.sol";

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
}

interface IPinkToken is IERC20 {
    function mint(address, uint256) external;
    function owner() external view returns (address);
}

interface IPair is IERC20 {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function skim(address) external;
    function sync() external;
    function burn(address) external returns (uint256, uint256);
    function factory() external view returns (address);
}

interface IFactory {
    function allPairsLength() external view returns (uint256);
    function allPairs(uint256) external view returns (address);
    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);
}

interface IMasterChef {
    function owner() external view returns (address);
    function migrator() external view returns (address);
    function poolLength() external view returns (uint256);
    function pinksPerBlock() external view returns (uint256);
    function totalPinksReward() external view returns (uint256);
    function totalAllocPoint() external view returns (uint256);
    function deposit(uint256, uint256) external;
    function withdraw(uint256, uint256) external;
    function emergencyWithdraw(uint256) external;
    function migrate(uint256) external;
    function updatePool(uint256) external;
    function poolInfo(uint256) external view returns (address, uint256, uint256, uint256);
}

interface IPinkLock {
    function unlock(uint256) external;
    function getTotalLockCount() external view returns (uint256);
}

contract PinkSwapPhase2Test is Test {
    address constant FACTORY = 0x7D2Ce25C28334E40f37b2A068ec8d5a59F11Ea54;
    address constant MASTERCHEF = 0xe981676633dCf0256Aa512f4923A7e8DA180C595;
    address constant PINK = 0x702b3f41772e321aacCdea91e1FCEF682D21125D;
    address constant FEE_TO = 0xCF6A864b0d705242BF1B916Bf8c097aE503BC4d5;
    address constant PINKLOCK2 = 0x407993575c91ce7643a4d4cCACc9A98c36eE1BBE;

    address constant WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address constant USDT = 0x55d398326f99059fF775485246999027B3197955;
    address constant ETH = 0x2170Ed0880ac9A755fd29B2688956BD959F933F8;
    address constant BTCB = 0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c;

    address constant TOP_PAIR = 0xB9eFbD2Bb41f7A2136BF2B21e8B26641651adef9;   // PinkE/WBNB
    address constant PINKS_WBNB = 0x61c960D0337f1EfE46BC7B1110bA8C4e60DD2017; // PinkS/WBNB (feeTo holds ~19% LP)

    address constant ATTACKER = address(0xBEEF); // unprivileged

    address[12] EXCESS_PAIRS = [
        0xB9eFbD2Bb41f7A2136BF2B21e8B26641651adef9, // PinkE/WBNB
        0x9a4682cf610D49688D520e32996cF6cdfB14B0C8, // PinkS/PinkE
        0x030ebC2465d4003D52841043D47E636beEb07Ce0, // PinkE/BUSD
        0xD948D34Ce937d9D6B7d54741e33030d4dae3F700, // PinkM/WBNB
        0x4E5F1Ae9ffCA3dD201fe1A222abF35441e265788, // SFT/WBNB
        0x05E80920Cc8a51d0E3f98983C954A9611667d67a, // TRIII/WBNB
        0x299C91fC4Ff0cc596Be7EcE2AaB676E7B7c21246, // SAFEMOON/WBNB
        0x510FA68A99bD3CA6845d4394F16ED8A75c764d77, // PinkE/COG
        0xb15365734227A96F8C61d64E5DD1040dDaA3fCDd, // PinkS/COG
        0x76f33B7b2AF0BA9Af6Cd59c6873f031D1933B58a, // COG/SAFEHOLD
        0xa4890C45BE913c7Fe9967543b07Dfe753e459Fa6, // WBNB/COG
        0x6C723ba7991895741DE4aC537D64F469D0b4Eac2  // WBNB/WB3
    ];

    IFactory factory;
    IMasterChef chef;
    IPinkToken pink;

    function setUp() public {
        string memory url = vm.envOr("BSC_RPC_URL", vm.envOr("FORK_RPC_URL", string("https://bsc-rpc.publicnode.com")));
        vm.createSelectFork(url);
        factory = IFactory(FACTORY);
        chef = IMasterChef(MASTERCHEF);
        pink = IPinkToken(PINK);
        vm.deal(ATTACKER, 100 ether);
        vm.label(ATTACKER, "attacker");
        console2.log("fork block", block.number);
    }

    // ---- helpers ----
    function isPriced(address t) internal pure returns (bool) {
        return t == WBNB || t == BUSD || t == USDT || t == ETH || t == BTCB;
    }

    // ---- 1. top pair: skim yields zero WBNB ----
    function test_skim_top_pair_yields_no_wbnb() public {
        IPair pair = IPair(TOP_PAIR);
        address t0 = pair.token0();
        address t1 = pair.token1();
        assertEq(t1, WBNB, "token1 is WBNB");
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 b0 = IERC20(t0).balanceOf(TOP_PAIR);
        uint256 b1 = IERC20(t1).balanceOf(TOP_PAIR);
        uint256 ex0 = b0 > r0 ? b0 - r0 : 0;
        uint256 ex1 = b1 > r1 ? b1 - r1 : 0;
        console2.log("top pair reserve WBNB wei", uint256(r1));
        console2.log("top pair excess t0", ex0, "excess t1 (WBNB)", ex1);

        uint256 wbnbBefore = IERC20(WBNB).balanceOf(ATTACKER);
        uint256 t0Before = IERC20(t0).balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        pair.skim(ATTACKER);
        uint256 wbnbGot = IERC20(WBNB).balanceOf(ATTACKER) - wbnbBefore;
        uint256 t0Got = IERC20(t0).balanceOf(ATTACKER) - t0Before;

        assertEq(wbnbGot, 0, "attacker extracted 0 WBNB via skim");
        assertEq(IERC20(WBNB).balanceOf(TOP_PAIR), r1, "pair WBNB balance == reserve after skim");
        assertLe(t0Got, ex0, "attacker got at most the t0 excess");
        console2.log("attacker got t0 (junk token) wei", t0Got);
        console2.log("attacker got WBNB wei", wbnbGot);
    }

    // ---- 2. all flagged excess pairs: skim works, but no priced token is ever extracted ----
    function test_skim_all_excess_pairs_no_priced_tokens() public {
        uint256 pricedGot = 0;
        uint256 pairsWithExcess = 0;
        uint256 skimReverted = 0;
        for (uint256 i = 0; i < EXCESS_PAIRS.length; i++) {
            IPair pair = IPair(EXCESS_PAIRS[i]);
            address t0 = pair.token0();
            address t1 = pair.token1();
            (uint112 r0, uint112 r1,) = pair.getReserves();
            uint256 ex0 = IERC20(t0).balanceOf(EXCESS_PAIRS[i]) > r0 ? IERC20(t0).balanceOf(EXCESS_PAIRS[i]) - r0 : 0;
            uint256 ex1 = IERC20(t1).balanceOf(EXCESS_PAIRS[i]) > r1 ? IERC20(t1).balanceOf(EXCESS_PAIRS[i]) - r1 : 0;
            if (ex0 == 0 && ex1 == 0) continue;
            pairsWithExcess++;
            uint256 b0Before = IERC20(t0).balanceOf(ATTACKER);
            uint256 b1Before = IERC20(t1).balanceOf(ATTACKER);
            vm.prank(ATTACKER);
            try pair.skim(ATTACKER) {
                uint256 got0 = IERC20(t0).balanceOf(ATTACKER) - b0Before;
                uint256 got1 = IERC20(t1).balanceOf(ATTACKER) - b1Before;
                assertLe(got0, ex0, "skim got <= excess0");
                assertLe(got1, ex1, "skim got <= excess1");
                if (isPriced(t0)) pricedGot += got0;
                if (isPriced(t1)) pricedGot += got1;
                // pair balances stay >= reserves (FoT tokens can leave a slightly larger balance)
                assertGe(IERC20(t0).balanceOf(EXCESS_PAIRS[i]), r0, "pair t0 >= reserve");
                assertGe(IERC20(t1).balanceOf(EXCESS_PAIRS[i]), r1, "pair t1 >= reserve");
            } catch {
                // token itself blocks transfer (e.g. COG/SAFEHOLD pair) -> excess is stuck, not extractable
                skimReverted++;
            }
        }
        console2.log("pairs with live excess:", pairsWithExcess);
        console2.log("pairs where skim reverted (stuck junk):", skimReverted);
        assertEq(pricedGot, 0, "zero priced tokens extractable via skim");
    }

    // ---- 3. full 167-pair scan: no priced-token excess exists anywhere ----
    function test_full_factory_scan_no_priced_excess() public {
        uint256 n = factory.allPairsLength();
        uint256 pricedExcess = 0;
        uint256 excessPairs = 0;
        for (uint256 i = 0; i < n; i++) {
            IPair pair = IPair(factory.allPairs(i));
            address t0 = pair.token0();
            address t1 = pair.token1();
            (uint112 r0, uint112 r1,) = pair.getReserves();
            uint256 b0 = IERC20(t0).balanceOf(address(pair));
            uint256 b1 = IERC20(t1).balanceOf(address(pair));
            uint256 ex0 = b0 > r0 ? b0 - r0 : 0;
            uint256 ex1 = b1 > r1 ? b1 - r1 : 0;
            if (ex0 > 0 || ex1 > 0) {
                excessPairs++;
                if (isPriced(t0)) pricedExcess += ex0;
                if (isPriced(t1)) pricedExcess += ex1;
            }
        }
        console2.log("pairs scanned:", n);
        console2.log("pairs with any excess:", excessPairs);
        console2.log("priced-token excess wei:", pricedExcess);
        assertEq(pricedExcess, 0, "no WBNB/BUSD/USDT/ETH/BTCB excess anywhere");
    }

    // ---- 4. PINK mint is owner-only (owner == MasterChef) ----
    function test_pink_mint_not_public() public {
        assertEq(pink.owner(), MASTERCHEF, "PINK owner is MasterChef");
        vm.prank(ATTACKER);
        vm.expectRevert();
        pink.mint(ATTACKER, 1 ether);
    }

    // ---- 5. MasterChef migrate() closed (migrator == 0) ----
    function test_masterchef_migrate_closed() public {
        assertEq(chef.migrator(), address(0), "migrator unset");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("migrate: no migrator"));
        chef.migrate(0);
    }

    // ---- 6. deposits blocked (emission cap reached) + updatePool gives caller nothing ----
    function test_masterchef_cap_reached_no_caller_gain() public {
        assertGe(pink.totalSupply(), chef.totalPinksReward(), "cap reached");
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Masterchief no more rewards"));
        chef.deposit(0, 1);

        uint256 supplyBefore = pink.totalSupply();
        uint256 mcBefore = pink.balanceOf(MASTERCHEF);
        uint256 attackerBefore = pink.balanceOf(ATTACKER);
        vm.prank(ATTACKER);
        chef.updatePool(0);
        assertEq(pink.totalSupply(), supplyBefore, "no new PINK minted at cap");
        assertEq(pink.balanceOf(MASTERCHEF), mcBefore, "MasterChef PINK unchanged");
        assertEq(pink.balanceOf(ATTACKER), attackerBefore, "attacker gained nothing");
    }

    // ---- 7. PinkLock02 unlock is owner-gated ----
    function test_pinklock_unlock_gated() public {
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("You are not the owner of this lock"));
        IPinkLock(PINKLOCK2).unlock(1112062); // MEV/WBNB LP lock
    }

    // ---- 8. feeTo redemption is privileged-only (P), attacker cannot burn others' LP ----
    function test_feeTo_redeem_privileged_only() public {
        IPair pair = IPair(PINKS_WBNB);
        address t0 = pair.token0();
        address t1 = pair.token1();
        uint256 feeToLP = pair.balanceOf(FEE_TO);
        assertGt(feeToLP, 0, "feeTo has accrued LP");

        // attacker cannot burn LP they do not hold
        vm.prank(ATTACKER);
        vm.expectRevert(bytes("Pinkswap: INSUFFICIENT_LIQUIDITY_BURNED"));
        pair.burn(ATTACKER);

        // privileged redemption on the fork: feeTo redeems its accrued LP
        (uint112 r0, uint112 r1,) = pair.getReserves();
        uint256 supply = pair.totalSupply();
        uint256 expWbnb = feeToLP * uint256(r1) / supply;
        vm.startPrank(FEE_TO);
        pair.transfer(address(pair), feeToLP);
        (uint256 a0, uint256 a1) = pair.burn(FEE_TO);
        vm.stopPrank();
        console2.log("feeTo redeemed t0", a0, "t1", a1);
        assertGt(a1, 0, "feeTo received WBNB");
        assertApproxEqRel(a1, expWbnb, 0.2e18, "matches pro-rata WBNB (within mint-fee dilution)");
    }
}
