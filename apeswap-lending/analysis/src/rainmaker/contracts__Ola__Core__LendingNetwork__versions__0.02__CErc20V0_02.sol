pragma solidity ^0.5.16;

import "../../OTokens/CToken.sol";
import "../0.01/CErc20V0_01.sol";

/**
 * @title Ola's CErc20 Contract V0.01
 * @notice CTokens which wrap an EIP-20 underlying
 * @author Ola
 * -- Changes form V0.01 : NONE
 */
contract CErc20V0_02 is CErc20V0_01, CErc20StorageV0_02 {
}
