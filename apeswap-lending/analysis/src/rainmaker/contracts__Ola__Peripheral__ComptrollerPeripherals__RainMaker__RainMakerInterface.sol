pragma solidity ^0.5.16;

import "../../../Core/LendingNetwork/OTokens/CToken.sol";

contract RainMakerInterface {
    bool public isRainMaker = true;
    bytes32 public contractNameHash;

    /*** Market support ***/
    function _supportMarket(address cToken) external;

    /*** Comp Distribution ***/
    function updateCompSupplyIndex(address cToken) external;
    function updateCompBorrowIndex(address cToken, uint marketBorrowIndex_) external;
    function distributeSupplierComp(address cToken, address supplier) external;
    function distributeBorrowerComp(address cToken, address borrower, uint marketBorrowIndex_) external;
}

contract SingleAssetRainMakerInterface is RainMakerInterface {
    /*** Comp claiming ***/
    function claimComp(address holder) external;
    function claimComp(address holder, CToken[] calldata cTokens) external;
    function claimComp(address[] calldata holders, CToken[] calldata cTokens, bool borrowers, bool suppliers) external;
}