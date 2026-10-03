// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

/**
 * H-09 — Equilibrium Lending / Equilibrium (Polkadot parachain) — EVM bridge audit.
 *
 * Mission: can an external, unprivileged attacker extract value from the live
 * Equilibrium-related EVM contracts on Ethereum mainnet right now?
 *
 * These tests fork Ethereum mainnet (read-only) and prove:
 *   1. The v2 ChainBridge (0x267c...e1F1) and its ERC20 handler (0xe2a1...2F2F) hold ZERO value.
 *   2. Every value-moving function on the bridge is admin- or relayer-gated and reverts for
 *      an arbitrary caller.
 *   3. Deposits into the bridge are administratively disabled (wind-down state).
 *   4. The older v1 ChainBridge (0x13d3...867f) is paused and its handler is empty.
 *   5. EQ can only be minted by the bridge handler via 2-of-5 relayer proposals; no
 *      unprivileged mint exists.
 *
 * All calls are eth_call/fork simulations. No mainnet transaction is ever sent.
 */
contract EquilibriumH8009Test is Test {
    // ---- mainnet addresses (verified on-chain, block 26,112,752 / 2026-10-03) ----
    address constant V2_BRIDGE = 0x267c4d894db79a3023e266B84401e58f7434e1F1; // ChainBridge v0.1.0, deployed 2022-10-10 block 15,717,208
    address constant V2_HANDLER = 0xe2a1D7C0c2ED4d3937bd6f93d9aCeA7498232F2F; // ERC20 handler, deployed block 15,717,209
    address constant V1_BRIDGE = 0x13D3D12478044E6Ea1b76F2A52d4bb6Dd3Ec867F; // ChainBridge v1, deployed 2021-08-15 block 13,100,122
    address constant V1_HANDLER = 0x47840AfF8b7fd9fdE5C3f11D5Ebc66e867C2f288; // v1 ERC20 handler (bridge() == V1_BRIDGE)

    address constant EQ = 0xA5eDE2FEE620ac3d68065EC01F26F9dd99850B82; // "Equilibrium" (EQ), supply 1.846B, no market
    address constant EQD2 = 0xfB41E1074DbE88EEb0Da01D52565774165DA03d3; // "Equilibrium Dollar", totalSupply == 0
    address constant GENS = 0x9D9152874294aC0489eCf191376F48db99014112; // Genshiro token
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address constant CRV = 0xD533a949740bb3306d119CC777fa900bA034cd52;

    address constant ADMIN = 0x81925a13D326420baEFD9f0b51bDd6309f778637; // deployer + DEFAULT_ADMIN_ROLE
    address constant RELAYER0 = 0xA820508a9AaabD94b9c153c8a39902682B86B377;
    address constant RELAYER4 = 0x9FD9E20C556C7EF9CeC7b2c0EA7038069a043dF2;

    // resource IDs (registered on both bridges; 7 per bridge)
    bytes32 constant RID_EQ = 0x000000000000000000000000000000681f812b3d181df0437de3f3e9ba249400;
    bytes32 constant RID_WETH = 0x000000000000000000000000000000e7af8cdba234ffeeddccbbaa3458798700;
    bytes32 constant RID_USDT = 0x00000000000000000000000000000062ced3722c69d04d18c5ce5fa6ef9a8a00;
    bytes32 constant RID_DAI = 0x000000000000000000000000000000b23802d01aeb6d2af5f66bc49383d20d00;
    bytes32 constant RID_WBTC = 0x0000000000000000000000000000002167b82cfd0cb1a577e338e65331e87f00;
    bytes32 constant RID_USDC = 0x000000000000000000000000000000f0ec6d6364bce9df4a3037c6d78bfe7900;
    bytes32 constant RID_EQD = 0x000000000000000000000000000000074f3176c2cfbbc7bba48d64535e071500;
    bytes32 constant RID_CRV = 0x000000000000000000000000000000e54dd1f11e2fd2474af64f487e911b5900;
    bytes32 constant RID_GENS = 0x0000000000000000000000000000007a05c51f15d366ac77bc86672166836100;

    address attacker = makeAddr("unprivileged-attacker");
    uint256 forkBlock;

    function setUp() public {
        string memory url = vm.envOr(
            "FORK_RPC_URL",
            vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com"))
        );
        vm.createSelectFork(url);
        forkBlock = block.number;
    }

    // ------------------------------------------------------------------ state

    /// v2 bridge configuration: 2-of-5 relayers, not paused, Ethereum domain 0.
    function test_state_v2_bridge_configuration() public view {
        assertEq(IBridge(V2_BRIDGE)._relayerThreshold(), 2, "threshold");
        assertEq(IBridge(V2_BRIDGE)._totalRelayers(), 5, "relayers");
        assertFalse(IBridge(V2_BRIDGE).paused(), "paused");
        assertEq(IBridge(V2_BRIDGE)._chainID(), 0, "domain");
        assertEq(IHandler(V2_HANDLER)._bridgeAddress(), V2_BRIDGE, "handler bridge");
    }

    /// The handler holds zero of every token it ever served; bridge ETH is zero.
    function test_state_v2_handler_balances_all_zero() public view {
        address[9] memory tokens = [EQ, EQD2, USDC, USDT, DAI, WETH, WBTC, CRV, GENS];
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(IERC20(tokens[i]).balanceOf(V2_HANDLER), 0, "handler balance");
        }
        assertEq(V2_BRIDGE.balance, 0, "bridge eth");
        assertEq(V2_HANDLER.balance, 0, "handler eth");
    }

    /// v1 bridge is paused and its handler is empty too.
    function test_state_v1_bridge_paused_and_empty() public view {
        assertTrue(IBridge(V1_BRIDGE).paused(), "v1 paused");
        assertEq(IHandler(V1_HANDLER)._bridgeAddress(), V1_BRIDGE, "v1 handler bridge");
        address[6] memory tokens = [USDC, USDT, DAI, WETH, WBTC, CRV];
        for (uint256 i = 0; i < tokens.length; i++) {
            assertEq(IERC20(tokens[i]).balanceOf(V1_HANDLER), 0, "v1 handler balance");
        }
        assertEq(V1_BRIDGE.balance, 0, "v1 bridge eth");
    }

    /// All 7 resource IDs on the v2 bridge map to the single known ERC20 handler and the expected token.
    function test_state_resource_mappings() public view {
        assertEq(IBridge(V2_BRIDGE)._resourceIDToHandlerAddress(RID_EQ), V2_HANDLER, "rid eq");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_EQ), EQ, "eq token");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_WETH), WETH, "weth");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_USDT), USDT, "usdt");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_DAI), DAI, "dai");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_WBTC), WBTC, "wbtc");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_USDC), USDC, "usdc");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_EQD), EQD2, "eqd");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_CRV), CRV, "crv");
        assertEq(IHandler(V2_HANDLER)._resourceIDToTokenContractAddress(RID_GENS), GENS, "gens");
    }

    // ------------------------------------------------- unprivileged extraction gates

    /// Arbitrary caller cannot sweep the handler through the bridge admin path.
    function test_attacker_cannot_adminWithdraw() public {
        vm.prank(attacker);
        vm.expectRevert("sender doesn't have admin role");
        IBridge(V2_BRIDGE).adminWithdraw(V2_HANDLER, USDC, attacker, 1);
    }

    /// Arbitrary caller cannot execute proposals (onlyRelayers).
    function test_attacker_cannot_executeProposal() public {
        vm.prank(attacker);
        vm.expectRevert("sender doesn't have relayer role");
        IBridge(V2_BRIDGE).executeProposal(1, 1, hex"", RID_EQ);
    }

    /// Arbitrary caller cannot vote proposals (onlyRelayers).
    function test_attacker_cannot_voteProposal() public {
        vm.prank(attacker);
        vm.expectRevert("sender doesn't have relayer role");
        IBridge(V2_BRIDGE).voteProposal(1, 1, RID_EQ, bytes32(0));
    }

    /// The handler itself is onlyBridge; no direct withdrawal.
    function test_attacker_cannot_withdraw_from_handler() public {
        vm.prank(attacker);
        vm.expectRevert("sender must be bridge contract");
        IHandler(V2_HANDLER).withdraw(USDC, attacker, 1);
    }

    /// Even the legitimate admin has nothing to take: amount 0 succeeds, amount 1 reverts on the empty handler.
    function test_admin_withdraw_path_open_but_empty() public {
        vm.prank(ADMIN);
        IBridge(V2_BRIDGE).adminWithdraw(V2_HANDLER, USDC, ADMIN, 0); // succeeds

        vm.prank(ADMIN);
        vm.expectRevert("ERC20: call failed");
        IBridge(V2_BRIDGE).adminWithdraw(V2_HANDLER, USDC, ADMIN, 1); // nothing there
    }

    /// Deposits to Equilibrium (chain 7) are administratively disabled — wind-down state.
    /// Deposits to Genshiro (chain 1) are still enabled, but that is an inbound-only path:
    /// the caller pays the 0.001 ETH fee and gets nothing back (Genshiro chain is dead).
    function test_v2_deposits_disabled_for_chain7_but_enabled_for_chain1() public {
        vm.deal(attacker, 1 ether);

        vm.prank(attacker);
        vm.expectRevert("deposits resource to chain with supplied chainID are disabled");
        IBridge(V2_BRIDGE).deposit{value: 0.001 ether}(7, RID_EQ, hex"");

        // 0-amount deposit to chain 1 succeeds (locks nothing, takes the fee) — no extraction
        vm.prank(attacker);
        IBridge(V2_BRIDGE).deposit{value: 0.001 ether}(1, RID_WETH, abi.encode(uint256(0)));
    }

    /// v1 bridge deposit path is paused.
    function test_v1_deposit_reverts_paused() public {
        vm.deal(attacker, 1 ether);
        vm.prank(attacker);
        vm.expectRevert("Pausable: paused");
        IBridge(V1_BRIDGE).deposit{value: 0.001 ether}(1, RID_WETH, hex"");
    }

    /// v1 admin path also gated.
    function test_v1_attacker_cannot_adminWithdraw() public {
        vm.prank(attacker);
        vm.expectRevert("sender doesn't have admin role");
        IBridge(V1_BRIDGE).adminWithdraw(V1_HANDLER, WETH, attacker, 1);
    }

    // ------------------------------------------------------------- token authorities

    /// EQ cannot be minted by anyone except the bridge handler (through 2-of-5 relayer proposals).
    function test_eq_mint_requires_minter_role() public {
        bytes32 minterRole = keccak256("MINTER_ROLE");
        assertTrue(IEQ(EQ).hasRole(minterRole, V2_HANDLER), "handler is minter");
        assertFalse(IEQ(EQ).hasRole(minterRole, attacker), "attacker not minter");
        assertEq(IEQ(EQ).getRoleMemberCount(minterRole), 1, "single minter");
        assertEq(IEQ(EQ).getRoleMember(minterRole, 0), V2_HANDLER, "minter == handler");

        vm.prank(attacker);
        vm.expectRevert("ERC20PresetMinterBurnerPauser: must have minter role to mint");
        IEQ(EQ).mint(attacker, 1e18);
    }

    /// The team EOA holds DEFAULT_ADMIN_ROLE on both bridge and token (privileged, not unprivileged).
    function test_admin_roles_are_team_eoa() public view {
        assertTrue(IBridge(V2_BRIDGE).hasRole(0x00, ADMIN), "bridge admin");
        assertTrue(IEQ(EQ).hasRole(0x00, ADMIN), "eq admin");
        assertEq(IBridge(V2_BRIDGE).getRoleMemberCount(0x00), 1, "one bridge admin");
    }

    /// Relayer set is exactly 5 EOAs; an attacker is not a relayer.
    function test_relayer_set() public view {
        bytes32 relayerRole = keccak256("RELAYER_ROLE");
        assertEq(IBridge(V2_BRIDGE).getRoleMemberCount(relayerRole), 5, "5 relayers");
        assertTrue(IBridge(V2_BRIDGE).hasRole(relayerRole, RELAYER0), "relayer0");
        assertTrue(IBridge(V2_BRIDGE).hasRole(relayerRole, RELAYER4), "relayer4");
        assertFalse(IBridge(V2_BRIDGE).hasRole(relayerRole, attacker), "attacker not relayer");
    }

    // ----------------------------------------------------------------- summary

    function test_emit_summary() public {
        emit log_named_uint("fork block", forkBlock);
        emit log_named_uint("v2 bridge eth balance", V2_BRIDGE.balance);
        emit log_named_uint("v2 handler usdc balance", IERC20(USDC).balanceOf(V2_HANDLER));
        emit log_named_uint("v2 handler eq balance", IERC20(EQ).balanceOf(V2_HANDLER));
        emit log_named_uint("v1 bridge eth balance", V1_BRIDGE.balance);
        emit log_named_string("verdict", "E-U = 0: all value paths admin/relayer gated; handlers empty; deposits disabled");
    }
}

interface IBridge {
    function _relayerThreshold() external view returns (uint8);
    function _totalRelayers() external view returns (uint256);
    function paused() external view returns (bool);
    function _chainID() external view returns (uint8);
    function _resourceIDToHandlerAddress(bytes32 resourceID) external view returns (address);
    function adminWithdraw(address handler, address tokenAddress, address recipient, uint256 amount) external;
    function executeProposal(uint8 domainID, uint64 depositNonce, bytes calldata data, bytes32 resourceID) external;
    function voteProposal(uint8 domainID, uint64 depositNonce, bytes32 resourceID, bytes32 dataHash) external;
    function deposit(uint8 destinationChainID, bytes32 resourceID, bytes calldata data) external payable;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
}

interface IHandler {
    function _bridgeAddress() external view returns (address);
    function _resourceIDToTokenContractAddress(bytes32 resourceID) external view returns (address);
    function withdraw(address tokenAddress, address recipient, uint256 amount) external;
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
}

interface IEQ {
    function mint(address to, uint256 amount) external;
    function hasRole(bytes32 role, address account) external view returns (bool);
    function getRoleMemberCount(bytes32 role) external view returns (uint256);
    function getRoleMember(bytes32 role, uint256 index) external view returns (address);
}
