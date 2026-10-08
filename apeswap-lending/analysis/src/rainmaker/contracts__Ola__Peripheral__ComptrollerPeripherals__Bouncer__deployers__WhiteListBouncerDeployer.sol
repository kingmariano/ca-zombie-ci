pragma solidity ^0.5.16;

import "../WhiteListBouncer.sol";

contract WhiteListBouncerDeployer {
    function deploy(address _comptroller, address _admin) external returns (address) {
        WhiteListBouncer whitelistBouncer = new WhiteListBouncer(_comptroller, _admin);

        return address(whitelistBouncer);
    }
}