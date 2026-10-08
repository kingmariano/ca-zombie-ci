pragma solidity ^0.5.16;

import "../../../LendingNetwork/Comptroller/ComptrollerInterface.sol";
import "../../../LendingNetwork/Delegators/ONativeDelegator.sol";

contract ONativeDelegatorDeployer {
    function deployODelegator(
        // Unused, just to keep the signature
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
        ONativeDelegator oNativeDelegator = new ONativeDelegator(
                comptroller_,
                interestRateModel_,
                initialExchangeRateMantissa_,
                name_,
                symbol_,
                decimals_,
                admin_,
                becomeImplementationData);
        address oNativeDelegatorAddress = address(oNativeDelegator);

        return oNativeDelegatorAddress;
    }
}