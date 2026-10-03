// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./BaseAdapter.sol";

interface IEMP {
    function settleExpired() external returns (uint256);
    function collateralCurrency() external view returns (address);
}

/// @title DegenerativeAdapter
/// @notice Adapter for redeeming Degenerative/Yam UMA EMP synth tokens (uSTONKS) for collateral
/// @dev The synth token and the EMP contract are separate — settleExpired() and collateralCurrency()
///      live on the EMP, not the synth token. This adapter maps synth → EMP.
contract DegenerativeAdapter is BaseAdapter {
    using SafeERC20 for IERC20;

    constructor(address _router) BaseAdapter(_router) {}

    // uSTONKS_APR21 synth → ExpiringMultiParty contract
    address private constant USTONKS = 0xEC58d3aefc9AAa2E0036FA65F70d569f49D9d1ED;
    address private constant USTONKS_EMP = 0x4F1424Cef6AcE40c0ae4fc64d74B734f1eAF153C;

    error UnsupportedToken(address token);

    function _getEMP(address inputToken) internal pure returns (address) {
        if (inputToken == USTONKS) return USTONKS_EMP;
        revert UnsupportedToken(inputToken);
    }

    function getExpectedOutputs(address inputToken) external view override returns (address[] memory) {
        address emp = _getEMP(inputToken);
        address[] memory outputs = new address[](1);
        outputs[0] = IEMP(emp).collateralCurrency();
        return outputs;
    }

    function redeem(address inputToken, uint256 amount, address[] calldata outputTokens) external override onlyRouter {
        address emp = _getEMP(inputToken);
        IERC20(inputToken).forceApprove(emp, amount);
        IEMP(emp).settleExpired();
        _sweep(outputTokens);
    }
}
