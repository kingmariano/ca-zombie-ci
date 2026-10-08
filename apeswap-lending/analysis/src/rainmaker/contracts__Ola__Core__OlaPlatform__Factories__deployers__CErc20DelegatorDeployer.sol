pragma solidity ^0.5.16;

import "../../../LendingNetwork/Delegators/CErc20Delegator.sol";
import "../../../LendingNetwork/Comptroller/ComptrollerInterface.sol";

contract CErc20DelegatorDeployer {
    function deployODelegator(
        address underlying_,
        ComptrollerInterface comptroller_,
        InterestRateModel interestRateModel_,
        uint initialExchangeRateMantissa_,
        string calldata name_,
        string calldata symbol_,
        uint8 decimals_,
        address payable admin_,
        bytes calldata becomeImplementationData
    ) external returns (address) {
        CErc20Delegator cErc20Delegator = new CErc20Delegator(underlying_, comptroller_, interestRateModel_, initialExchangeRateMantissa_, name_, symbol_, decimals_, admin_, becomeImplementationData);
        address cErc20DelegatorAddress = address(cErc20Delegator);

        return cErc20DelegatorAddress;
    }
}