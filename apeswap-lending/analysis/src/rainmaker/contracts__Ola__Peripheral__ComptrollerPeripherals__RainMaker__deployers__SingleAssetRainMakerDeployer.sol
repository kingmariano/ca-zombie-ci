pragma solidity ^0.5.16;

import "../SingleAssetRainMaker.sol";

contract SingleAssetRainMakerDeployer {
    function deploy(address _comptroller, address _admin) external returns (address) {
        SingleAssetRainMaker singleAssetRainMaker = new SingleAssetRainMaker(_comptroller, _admin);

        return address(singleAssetRainMaker);
    }
}