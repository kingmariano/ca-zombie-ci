// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface ISetToken {
    function getComponents() external view returns (address[] memory);
}

interface IBasicIssuanceModule {
    function redeem(address _setToken, uint256 _quantity, address _to) external;
}

/// @title IndexCoopAdapter
/// @notice Adapter for redeeming Index Coop Set tokens (DPI, MVI, BED, DATA) for underlying
contract IndexCoopAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    address public constant INDEX_MODULE = 0xd8EF3cACe8b4907117a45B0b125c68560532F94D;

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        return ISetToken(inputToken).getComponents();
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IERC20(inputToken).forceApprove(INDEX_MODULE, amount);
        IBasicIssuanceModule(INDEX_MODULE).redeem(inputToken, amount, address(this));
        _sweep(outputTokens);
    }
}
