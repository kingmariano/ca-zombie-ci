
pragma solidity =0.7.6;


interface ISwapDirector is IOperContract {
    function feeAmountTickSpacing(uint24 fee) external view returns (int24);
}

