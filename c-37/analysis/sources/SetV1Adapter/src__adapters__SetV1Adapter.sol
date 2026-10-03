// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface ISetV1Module {
    function redeemRebalancingSet(
        address _rebalancingSetAddress,
        uint256 _rebalancingSetQuantity,
        bool _keepChangeInVault
    ) external;
}

/// @title SetV1Adapter
/// @notice Adapter for redeeming Set Protocol V1 tokens (ETH20SMACO, etc.)
contract SetV1Adapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    address public constant SET_V1_MODULE = 0xcEDA8318522D348f1d1aca48B24629b8FbF09020;

    /// @notice Accept ETH from Set Protocol redemptions
    receive() external payable {}

    function getExpectedOutputs(address) external pure override returns (address[] memory) {
        // Outputs vary per set token — frontend uses simulation
        return new address[](0);
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        IERC20(inputToken).forceApprove(SET_V1_MODULE, amount);
        ISetV1Module(SET_V1_MODULE).redeemRebalancingSet(inputToken, amount, false);
        _sweep(outputTokens);
        _sweepETH();
    }
}
