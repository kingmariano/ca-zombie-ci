// SPDX-License-Identifier: GPL-3.0
pragma solidity 0.8.23;

import {BounceBitToken} from "./BounceBitToken.sol";

contract BBUSD is BounceBitToken {
    function initialize(
        address _initialOwner,
        address _blacklist,
        address[] memory _minterList,
        address[] memory _burnerList
    ) public initializer {
        __BounceBitToken_init("BounceBit USD", "BBUSD", _initialOwner, _blacklist, _minterList, _burnerList);
    }
}
