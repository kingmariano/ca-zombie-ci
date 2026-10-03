// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface IiToken {
    function redeem(address _from, uint256 _redeemiToken) external;
    function underlying() external view returns (address);
}

interface IWETH {
    function deposit() external payable;
}

/// @title dForceAdapter
/// @notice Adapter for redeeming dForce Lending iTokens (iwstETH, iUSDT, iETH) for underlying
/// @dev iETH returns native ETH which is wrapped to WETH before sweeping
contract dForceAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @notice Accept ETH from iETH redemption
    receive() external payable {}

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        address[] memory outputs = new address[](1);
        address underlying = IiToken(inputToken).underlying();
        outputs[0] = underlying == address(0) ? WETH : underlying;
        return outputs;
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IiToken(inputToken).redeem(address(this), amount);
        // Wrap any native ETH received (from iETH) to WETH
        if (address(this).balance > 0) {
            IWETH(WETH).deposit{value: address(this).balance}();
        }
        _sweep(outputTokens);
    }
}
