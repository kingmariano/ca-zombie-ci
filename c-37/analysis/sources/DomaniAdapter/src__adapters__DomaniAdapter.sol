// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface IDomaniSetToken {
    function getComponents() external view returns (address[] memory);
}

interface IDomaniModule {
    function redeem(address _setToken, uint256 _quantity, address _to) external;
}

/// @title DomaniAdapter
/// @notice Adapter for redeeming Domani (DEXTF) Set V2 fork tokens for underlying
contract DomaniAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    address public constant DOMANI_MODULE = 0xBa1030459e75f6041F938c5470F4E0f6468d5253;

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        return IDomaniSetToken(inputToken).getComponents();
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IERC20(inputToken).forceApprove(DOMANI_MODULE, amount);
        IDomaniModule(DOMANI_MODULE).redeem(inputToken, amount, address(this));
        _sweep(outputTokens);
    }
}
