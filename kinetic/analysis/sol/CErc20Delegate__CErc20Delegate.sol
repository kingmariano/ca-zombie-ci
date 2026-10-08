pragma solidity 0.5.17;

import "./CErc20.sol";
import "./IApprovalAllowList.sol";

/**
 * @title Protocol's CErc20Delegate Contract
 * @notice CTokens which wrap an EIP-20 underlying and are delegated to
 */
contract CErc20Delegate is CErc20, ProtocolTokenDelegateInterface {
    address internal approvalAllowList_;

    event NewApprovalAllowList(address oldApprovalAllowList, address newApprovalAllowList);

    /**
     * @notice Construct an empty delegate
     */
    constructor() public {}

    function approvalAllowList() external view returns (address) {
        return approvalAllowList_;
    }

    function approve(address spender, uint256 amount) external returns (bool) {
        require(amount == 0 || approvalAllowList_ != address(0), "AAL");
        require(amount == 0 || IApprovalAllowList(approvalAllowList_).allowed(spender), "SNA");

        address src = msg.sender;
        transferAllowances[src][spender] = amount;
        emit Approval(src, spender, amount);
        return true;
    }

    function _setApprovalAllowList(address newApprovalAllowList) external {
        require(msg.sender == admin, "OA");
        require(newApprovalAllowList != address(0), "AAL0");

        address oldApprovalAllowList = approvalAllowList_;
        approvalAllowList_ = newApprovalAllowList;

        emit NewApprovalAllowList(oldApprovalAllowList, newApprovalAllowList);
    }

    /**
     * @notice Called by the delegator on a delegate to initialize it for duty
     * @param data The encoded bytes data for any initialization
     */
    function _becomeImplementation(bytes memory data) public {
        // Shh -- currently unused
        data;

        // Shh -- we don't ever want this hook to be marked pure
        if (false) {
            implementation = address(0);
        }

        require(msg.sender == admin, "only the admin may call _becomeImplementation");
    }

    /**
     * @notice Called by the delegator on a delegate to forfeit its responsibility
     */
    function _resignImplementation() public {
        // Shh -- we don't ever want this hook to be marked pure
        if (false) {
            implementation = address(0);
        }

        require(msg.sender == admin, "only the admin may call _resignImplementation");
    }
}

contract CErc20DelegateV2 is CErc20Delegate{
    function fixState(uint amount) public {
        require(msg.sender == admin, "only the admin may call");

        require(accrueInterest() == uint(Error.NO_ERROR), "accrue interest failed");

        uint transferedAmount = doTransferIn(msg.sender, amount);

        require(transferedAmount == amount, "invalid amount");

        totalBorrows = sub_(totalBorrows, transferedAmount);
    }
}
