pragma solidity ^0.5.16;

import "../SingleAssetDynamicRainMaker.sol";

contract SingleAssetDynamicRainMakerDeployer {
    function deploy(address _comptroller, address _admin) external returns (address) {
        SingleAssetDynamicRainMaker singleAssetDynamicRainMaker = new SingleAssetDynamicRainMaker(_comptroller, _admin);

        return address(singleAssetDynamicRainMaker);
    }
}