// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./BaseAdapter.sol";

interface IAToken {
    function underlyingAssetAddress() external view returns (address);
    function redeem(uint256 _amount) external;
}

interface IWETH {
    function deposit() external payable;
}

/// @title AaveV1Adapter
/// @notice Adapter for redeeming Aave V1 aTokens for underlying assets
/// @dev Wraps native ETH to WETH so the Router handles pure ERC20
contract AaveV1Adapter is BaseAdapter {
    constructor(address _router) BaseAdapter(_router) {}

    address private constant ETH_ADDRESS = 0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Accept ETH from aToken redemptions (aETH returns native ETH)
    receive() external payable {}

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        address underlying = IAToken(inputToken).underlyingAssetAddress();
        address[] memory outputs = new address[](1);
        outputs[0] = underlying == ETH_ADDRESS ? WETH : underlying;
        return outputs;
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IAToken(inputToken).redeem(amount);

        // If ETH was received, wrap to WETH
        if (address(this).balance > 0) {
            IWETH(WETH).deposit{value: address(this).balance}();
        }

        _sweep(outputTokens);
    }
}
