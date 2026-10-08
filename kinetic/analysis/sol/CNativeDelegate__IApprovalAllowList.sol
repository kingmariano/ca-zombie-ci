pragma solidity 0.5.17;

interface IApprovalAllowList {
    function allowed(address account) external view returns (bool);
}
