// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface ICookFinanceModule {
    function redeem(address _ckToken, uint256 _quantity, address _to) external;
}

/// @title CookFinanceAdapter
/// @notice Adapter for redeeming Cook Finance CLI tokens for underlying (WBTC + WETH)
contract CookFinanceAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    address public constant CLI = 0xA6156492fC79616035F644C71b01e3099819F8EC;
    address public constant COOK_MODULE = 0x59E799B58f1F4bc778E126B0D1D2774Ae05432B7;

    // Cook Finance CLI outputs
    address private constant WBTC = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    function getExpectedOutputs(address) external pure override returns (address[] memory) {
        address[] memory outputs = new address[](2);
        outputs[0] = WBTC;
        outputs[1] = WETH;
        return outputs;
    }

    function redeem(address, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IERC20(CLI).forceApprove(COOK_MODULE, amount);
        ICookFinanceModule(COOK_MODULE).redeem(CLI, amount, address(this));
        _sweep(outputTokens);
    }
}
