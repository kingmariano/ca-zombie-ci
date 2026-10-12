// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "../../../../interfaces/Blast/IERC20Rebasing.sol";
import "./Blast/BlastPointsManager.sol";

contract HyperWETH is ERC4626, BlastPointsManager {

    constructor(address _WETH) ERC4626(IERC20(_WETH)) ERC20("Hyper WETH", "hWETH") {
        IERC20Rebasing(_WETH).configure(YieldMode.AUTOMATIC);
    }

}