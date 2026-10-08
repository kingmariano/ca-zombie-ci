pragma solidity ^0.5.16;

import "../../Ola/Core/OlaPlatform/Registry/RegistryStorage.sol";
import "../../Ola/Core/OlaPlatform/Registry/RegistryInterface.sol";


import "../../Ola/Core/OlaPlatform/versions/0/RegistryV0.sol";

/**
 * @title Ola's Test Registry Contract
 * @author Ola
 */
contract TestRegistry is RegistryV0 {
    // DEV_NOTE : A field that will indicate that this is indeed the test contract
    bool public isTestRegistry;

    function _become(Ministry ministry) public {


        super._become(ministry);
    }

    function setTestFlags() public {

        isTestRegistry = true;
    }
}
