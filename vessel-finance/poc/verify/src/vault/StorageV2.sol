/*
Copyright 2024 Vessel Team.

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
License. You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an
"AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific
language governing permissions and limitations under the License.
*/
// SPDX-License-Identifier: Apache-2.0
pragma solidity 0.8.19;

import { Initializable } from "lib/openzeppelin-contracts/contracts/proxy/utils/Initializable.sol";
import { ReentrancyGuard } from "lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import { MessageQueueEncoder } from "../affiliate/MessageQueueEncoder.sol";
import { Constants } from "./Constants.sol";
import { StorageV1 } from "./StorageV1.sol";

// solhint-disable-next-line max-states-count
contract StorageV2 is
    Constants,
    Initializable,
    StorageV1,
    ReentrancyGuard
{
    /// @dev used by fast-withdraw feature
    mapping(address account => bool isExitManager) internal exitManagers;
    mapping(address userAddress => mapping(uint256 nonce => bool used)) internal fastExitUserNonce;
    address public wethAddress;

    // @dev affiliate components
    MessageQueueEncoder public mqEncoder;
}
