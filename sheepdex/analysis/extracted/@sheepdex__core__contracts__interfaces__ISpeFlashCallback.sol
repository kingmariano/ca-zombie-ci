
pragma solidity =0.7.6;

interface ISpeFlashCallback {
    function flashCallback(
        uint256 fee0,
        uint256 fee1,
        bytes calldata data
    ) external;
}

