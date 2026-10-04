// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";

interface IErc20Vault {
    function pegOut(address payable tokenRecipient, address tokenAddress, uint256 tokenAmount) external returns (bool);
    function adminWithdraw(address asset) external;
    function PNETWORK() external view returns (address);
    function initialize(address weth, address[] memory tokensToSupport, bytes4 originChainId) external;
}

interface IPToken {
    function mint(address recipient, uint256 value) external returns (bool);
    function redeem(uint256 amount, string calldata underlyingAssetRecipient, bytes4 destinationChainId) external returns (bool);
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function hasRole(bytes32 role, address account) external view returns (bool);
}

interface IPNetworkHub {
    function isLockedDown() external view returns (bool);
    function protocolQueueOperation(bytes calldata operation) external payable;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function decimals() external view returns (uint8);
}

/// @title pNetwork H-18 closed-path verification (fork only, read-only against mainnet)
contract PnetworkClosedPathsTest is Test {
    // Ethereum
    address constant VAULT = 0x112334f50Cb6efcff4e35Ae51A022dBE41a48135; // pNetwork Erc20Vault (v1)
    address constant VAULT_PNETWORK = 0xDffE7AC6B538B4A7Fd81c98C5fba0415d63fB132;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant PBTC = 0x62199B909FB8B8cf870f97BEf2cE6783493c4908; // pTokens BTC (v2, proxy)
    bytes32 constant MINTER_ROLE = keccak256("MINTER_ROLE");
    address constant V3_HUB = 0x09D286748DbE6fD1316dE765C748f4685352F50c; // v3 PNetworkHub (dead)

    // BSC
    address constant PGALA = 0x419C44C48Cd346C0b0933ba243BE02af46607c9B;
    address constant PGALA_OWNER = 0x2161Ba0493b02b5e207C38C013ff82DF006D0d54;

    address attacker = address(0xA11CE);

    function ethRpc() internal view returns (string memory) {
        return vm.envOr("FORK_RPC_URL", vm.envOr("RPC_URL", string("https://ethereum-rpc.publicnode.com")));
    }

    function bscRpc() internal view returns (string memory) {
        return vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed1.binance.org"));
    }

    /* ---------------------------------------------------------------- ETH ---- */

    function test_EU_vault_pegOut_reverts_for_unprivileged() public {
        vm.createSelectFork(ethRpc());
        uint256 vaultDai = IERC20(DAI).balanceOf(VAULT);
        assertGt(vaultDai, 0, "vault holds DAI collateral");
        vm.prank(attacker);
        vm.expectRevert();
        IErc20Vault(VAULT).pegOut(payable(attacker), DAI, vaultDai);
        // nothing moved
        assertEq(IERC20(DAI).balanceOf(VAULT), vaultDai);
    }

    function test_P_vault_pegOut_allowed_for_PNETWORK_EOA() public {
        vm.createSelectFork(ethRpc());
        uint256 vaultDai = IERC20(DAI).balanceOf(VAULT);
        assertGt(vaultDai, 0);
        vm.prank(VAULT_PNETWORK);
        IErc20Vault(VAULT).pegOut(payable(VAULT_PNETWORK), DAI, 1); // 1 wei proof only
        assertEq(IERC20(DAI).balanceOf(VAULT), vaultDai - 1);
    }

    function test_EU_vault_adminWithdraw_reverts_for_unprivileged() public {
        vm.createSelectFork(ethRpc());
        vm.prank(attacker);
        vm.expectRevert();
        IErc20Vault(VAULT).adminWithdraw(DAI);
    }

    function test_EU_vault_initialize_already_spent() public {
        vm.createSelectFork(ethRpc());
        address[] memory tokens = new address[](1);
        tokens[0] = DAI;
        vm.prank(attacker);
        vm.expectRevert();
        IErc20Vault(VAULT).initialize(address(0), tokens, bytes4(0));
        assertEq(IErc20Vault(VAULT).PNETWORK(), VAULT_PNETWORK);
    }

    function test_EU_ptoken_mint_reverts_for_unprivileged() public {
        vm.createSelectFork(ethRpc());
        assertFalse(IPToken(PBTC).hasRole(MINTER_ROLE, attacker));
        vm.prank(attacker);
        vm.expectRevert();
        IPToken(PBTC).mint(attacker, 1e18);
    }

    function test_EU_ptoken_redeem_cannot_burn_foreign_balance() public {
        vm.createSelectFork(ethRpc());
        assertEq(IPToken(PBTC).balanceOf(attacker), 0);
        vm.prank(attacker);
        vm.expectRevert();
        IPToken(PBTC).redeem(1, "", bytes4(0x005fe7f9));
    }

    function test_EU_v3_hub_is_dead() public {
        vm.createSelectFork(ethRpc());
        vm.expectRevert();
        IPNetworkHub(V3_HUB).isLockedDown();
        vm.prank(attacker);
        vm.expectRevert();
        IPNetworkHub(V3_HUB).protocolQueueOperation{value: 0}(hex"");
    }

    /* ---------------------------------------------------------------- BSC ---- */

    function test_EU_bsc_ptoken_mint_reverts_for_unprivileged() public {
        vm.createSelectFork(bscRpc());
        // pGALA (new, post-2022 incident) — unprivileged mint must fail regardless of impl version
        vm.prank(attacker);
        (bool ok, ) = PGALA.call(abi.encodeWithSignature("mint(address,uint256)", attacker, 1e18));
        assertFalse(ok, "unprivileged mint must revert");
        (bool ok2, bytes memory ret) = PGALA.staticcall(abi.encodeWithSignature("balanceOf(address)", attacker));
        assertTrue(ok2);
        assertEq(abi.decode(ret, (uint256)), 0);
    }

    function test_P_bsc_ptoken_owner_is_eoa() public {
        vm.createSelectFork(bscRpc());
        // documentation: owner is a pNetwork EOA (no code); minting requires its key
        uint256 size;
        address owner = PGALA_OWNER;
        assembly { size := extcodesize(owner) }
        assertEq(size, 0, "owner is EOA");
        (bool ok, bytes memory ret) = PGALA.staticcall(abi.encodeWithSignature("owner()"));
        assertTrue(ok, "owner() exists");
        assertEq(abi.decode(ret, (address)), PGALA_OWNER);
    }
}
