pragma solidity ^0.5.16;

contract BorrowedAgainstInterface {
    function commitBorrowedAgainstBorrow(address borrower, uint borrowAmount) external returns (uint);
    function commitBorrowedAgainstRepayBorrow(address borrower, uint repayBorrowAmount) external returns (uint);
    function borrowAllowedBorrowedAgainst(address borrower, address cTokenBorrow, uint borrowAmountUsd) external returns (uint, bool);
}
