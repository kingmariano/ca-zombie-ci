// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseAdapter.sol";

interface IBasketDAO {
    function burn(uint256 _amount) external;
}

/// @title BasketDAOAdapter
/// @notice Adapter for redeeming BasketDAO BDI tokens for underlying DeFi tokens
contract BasketDAOAdapter is BaseAdapter {
    constructor(address _router) BaseAdapter(_router) {}

    address public constant BDI = 0x0309c98B1bffA350bcb3F9fB9780970CA32a5060;

    function getExpectedOutputs(address) external pure override returns (address[] memory) {
        // BDI has 15 underlying tokens — hardcoded list
        address[] memory outputs = new address[](15);
        outputs[0]  = 0xE14d13d8B3b85aF791b2AADD661cDBd5E6097Db1; // yvYFI
        outputs[1]  = 0x70e36f6BF80a52b3B46b3aF8e106CC0ed743E8e4; // cCOMP
        outputs[2]  = 0xF29AE508698bDeF169B89834F76704C3B205aedf; // yvSNX
        outputs[3]  = 0x9f8F72aA9304c8B593d555F12eF6589cC3A579A2; // MKR
        outputs[4]  = 0x408e41876cCCDC0F92210600ef50372656052a38; // REN
        outputs[5]  = 0xdeFA4e8a7bcBA345F687a2f1456F5Edd9CE97202; // KNC
        outputs[6]  = 0xBBbbCA6A901c926F240b89EacB641d8Aec7AEafD; // LRC
        outputs[7]  = 0xba100000625a3754423978a60c9317c58a424e3D; // BAL
        outputs[8]  = 0xFBEB78a723b8087fD2ea7Ef1afEc93d35E8Bed42; // yvUNI
        outputs[9]  = 0x7Fc66500c84A76Ad7e9c93437bFc5Ac33E2DDaE9; // AAVE
        outputs[10] = 0x8798249c2E607446EfB7Ad49eC89dD1865Ff4272; // xSUSHI
        outputs[11] = 0x2ba592F78dB6436527729929AAf6c908497cB200; // CREAM
        outputs[12] = 0xf2db9a7c0ACd427A680D640F02d90f6186E71725; // yvCurve-LINK
        outputs[13] = 0x9d409a0A012CFbA9B15F6D4B36Ac57A46966Ab9a; // yvBOOST
        outputs[14] = 0xE41d2489571d322189246DaFA5ebDe1F4699F498; // ZRX
        return outputs;
    }

    function redeem(address, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IBasketDAO(BDI).burn(amount);
        _sweep(outputTokens);
    }
}
