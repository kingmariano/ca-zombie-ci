// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "../../../../interfaces/Blast/IERC20Rebasing.sol";
import "./Blast/BlastPointsManager.sol";

contract HyperUSDB is ERC4626, BlastPointsManager {

    constructor(address _USDB) ERC4626(IERC20(_USDB)) ERC20("Hyper USDB", "hUSDB") {
        IERC20Rebasing(_USDB).configure(YieldMode.AUTOMATIC);
    }

}