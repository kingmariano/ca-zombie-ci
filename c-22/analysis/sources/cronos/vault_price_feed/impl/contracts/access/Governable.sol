// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

pragma solidity ^0.8.0;

abstract contract Governable is Initializable {
    address public gov;

    event UpdateGov(address gov);

    function __Governable_init() internal onlyInitializing {
        gov = msg.sender;
    }

    modifier onlyGov() {
        require(msg.sender == gov, "Governable: forbidden");
        _;
    }

    function setGov(address _gov) external onlyGov {
        require(_gov != address(0), "Governable: zero address");
        gov = _gov;
        emit UpdateGov(gov);
    }
}
