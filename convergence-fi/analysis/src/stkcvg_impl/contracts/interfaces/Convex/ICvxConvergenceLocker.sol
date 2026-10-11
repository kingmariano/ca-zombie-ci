// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../ICommonStruct.sol";

interface ICvxConvergenceLocker is IERC20 {
    function mintFees() external view returns (uint256);

    function mint(address account, uint256 amount, bool isLock) external;

    function pullRewards(address processor) external returns (ICommonStruct.TokenAmount[] memory);

    function depositLp(uint256 amountLp, bool isLock, address receiver) external returns (uint256);

    function depositLpAssets(
        uint256[2] memory amounts,
        uint256 minLpAmount,
        bool isLock,
        address receiver
    ) external returns (uint256);

    function depositLpAssetUnderlying(
        uint256[3] memory amounts, //ex: [0] => eUSD / [1] => FRAX / [2] => USDC
        uint256 minLpUnderlyingAmount,
        uint256 minLpAmount,
        bool isLock,
        address receiver
    ) external returns (uint256);
}
