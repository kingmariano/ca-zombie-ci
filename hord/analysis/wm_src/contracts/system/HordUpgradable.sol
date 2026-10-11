// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

import "../interfaces/IMaintainersRegistry.sol";

/**
 * HordUpgradables contract.
 * @author Nikola Madjarevic
 * Date created: 8.5.21.
 * Github: madjarevicn
 */
contract HordUpgradable {

    address public hordCongress;
    IMaintainersRegistry public maintainersRegistry;

    event MaintainersRegistrySet(address maintainersRegistry);
    event CongressAndMaintainersSet(address hordCongress, address maintainersRegistry);

    // Only maintainer modifier
    modifier onlyMaintainer {
        require(maintainersRegistry.isMaintainer(msg.sender), "Hord: Restricted only to Maintainer");
        _;
    }

    // Only chainport congress modifier
    modifier onlyHordCongress {
        require(msg.sender == hordCongress, "Hord: Restricted only to HordCongress");
        _;
    }

    modifier onlyHordCongressOrMaintainer {
        require(msg.sender == hordCongress || maintainersRegistry.isMaintainer(msg.sender),
            "Hord: Only Congress or Maintainer."
        );
        _;
    }

    function setCongressAndMaintainers(
        address _hordCongress,
        address _maintainersRegistry
    )
    internal
    {
        require(_hordCongress != address(0), "HordCongress can not be 0x0 address");
        require(_maintainersRegistry != address(0), "MaintainersRegistry can not be 0x0 address");

        hordCongress = _hordCongress;
        maintainersRegistry = IMaintainersRegistry(_maintainersRegistry);

        emit CongressAndMaintainersSet(hordCongress, address(maintainersRegistry));
    }

}
