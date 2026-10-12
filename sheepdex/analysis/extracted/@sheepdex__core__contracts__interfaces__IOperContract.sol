

pragma solidity =0.7.6;

interface IOperContract {
    function operator() external view returns (address);

    function owner() external view returns (address);
}

