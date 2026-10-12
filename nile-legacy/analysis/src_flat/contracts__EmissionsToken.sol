// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import "solmate/src/tokens/ERC20.sol";

contract EmissionsToken is ERC20 {
    address public minter;

    constructor(address _minter) ERC20("NILE Token", "NILE", 18) {
        minter = _minter;
    }

    /// @notice to be set to the epoch emission's minter
    function setMinter(address _minter) external {
        require(msg.sender == minter, "!MINTER");
        minter = _minter;
    }
    /// @notice called by epoch minter
    function mint(address account, uint256 amount) external {
        require(msg.sender == minter, "!MINTER");
        _mint(account, amount);
    }
    /// @notice regular burn function
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}
