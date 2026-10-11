// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces + canonical addresses for the Hord (hETH) zombie assessment.
/// All addresses are mainnet, read-only research.

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function transfer(address, uint256) external returns (bool);
    function approve(address, uint256) external returns (bool);
    function allowance(address, address) external view returns (uint256);
}

interface IHordStakingManager {
    // HETH (ERC20 + staking manager, TransparentUpgradeableProxy)
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function totalSupply() external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
    function paused() external view returns (bool);
    function hordCongress() external view returns (address);
    function maintainersRegistry() external view returns (address);
    function hordETHStakingWithdrawalManager() external view returns (address);
    function totalBalanceETHInValidators() external view returns (uint256);
    function totalETHDeposited() external view returns (uint256);
    function totalETHOnContractRecorded() external view returns (uint256);
    function amountTakenFromBuffer() external view returns (uint256);
    function getAmountOfHETHforETH(uint256, bool, uint256) external view returns (uint256);
    function userDepositETH() external payable;
    function burn(address, uint256) external;
    function unpause() external;
    function pause() external;
    function setValidatorStats(uint256, uint256, uint256) external;
    function mintProtocolFees() external;
    function appropriateReservesToPayDebt(uint256, uint256, uint256) external;
    function moveETHToAssuredBalance(uint256) external;
    function launchNewValidator(bool, bytes calldata, bytes calldata, bytes calldata, bytes32) external;
}

interface IHordWithdrawalManager {
    function paused() external view returns (bool);
    function unAllocatedBuffer() external view returns (uint256);
    function assuredClaimsBalance() external view returns (uint256);
    function totalPendingDebt() external view returns (uint256);
    function amountTakenFromBuffer() external view returns (uint256);
    function totalAmountAddedByOrgForBuffer() external view returns (uint256);
    function totalAmountReturnedToOrg() external view returns (uint256);
    function withdrawalDebtsLength() external view returns (uint256);
    function totalETHReservesForPayingDebt() external view returns (uint256);
    function usersWithdrawals(address) external view returns (
        address requestOwner,
        uint256 withdrawalNonce,
        uint256 currHETHRedeemed,
        uint256 currETHToWithdraw,
        uint256 pendingDebt,
        uint256 unlockingTime,
        uint256 requestTime,
        uint256 finalizedTime,
        uint256 totalETHWithdrawn,
        uint256 totalHETHRedeemed
    );
    function requestWithdraw(uint256) external;
    function withdraw() external;
    function unpause() external;
    function transferETHtoFinance() external;
    function withdrawOrganizationFunds(uint256) external;
    function payOfDebtFromOrganization(uint256, uint256, uint256) external;
    function payOfDebtFromValidatorsFunds(uint256, uint256) external payable;
    function correctWithdrawalRequests() external;
}

interface IEigenPod {
    function podOwner() external view returns (address);
}

library Hord {
    // Ethereum mainnet addresses (verified on-chain at block 26,170,355)
    address constant HETH            = 0x5bBe36152d3CD3eB7183A82470b39b29EedF068B; // hETH token + HordETHStakingManager proxy
    address constant HETH_IMPL       = 0xd98B050d2c5A3562b19a791f88F6Ef9A7aa93F27; // unverified impl (set 2026-02-07, block 24411920)
    address constant WM              = 0x4FdC295580287b1e3C8fa8875f0fbDc688d8e8A5; // HordETHStakingWithdrawalManager proxy
    address constant WM_IMPL         = 0x11E45e691feeC37E224ee1764311509f6B691107; // impl (set 2026-07-23, block 25590926)
    address constant PROXY_ADMIN     = 0x96B90F7065e5FD7251dd1b649DE20918Ae0F3aB7; // owns hETH proxy
    address constant CONGRESS        = 0x086A6d9FD61758096CF4F394AE7C1F9B6b4EEC14; // HordCongress (also ProxyAdmin owner)
    address constant MAINTAINERS     = 0x8B7819135Fe97aBFDc0c88596509c00FA727eaDc; // MaintainersRegistry proxy
    address constant STAKING_CONFIG  = 0x51B2f83aac13adB9Ed826C4cdb593C88e6B61C92; // StakingConfiguration proxy
    address constant FINANCE         = 0x918B80ce545ca1b8651686B705E0d42bc9190912; // financeAddress() - already received 11.83 ETH
    address constant POD             = 0xb1d6Eb8893e74fd42BFd48A1007aA3F3ec064EE0; // EigenPod (5 validators), owner = restaking mgr
    address constant RESTAKING_MGR   = 0x72B8669dC62746e27073C726E55d9062005AB45D; // HordRestakingManager
    address constant HETH_WETH_POOL  = 0x4F2cBf76a491240764d3Fe4E96e48C5062075F32; // UniV3 hETH/WETH 0.3%
    address constant MAINTAINER_1    = 0x37be0a40A0d2493872e4e4b27C5147B76B554665; // active maintainer
    address constant MAINTAINER_2    = 0x6aCB6B451aAf8a411E2FD68d0497A02Ec43421f3; // active maintainer

    // Selectors added by the Feb-2026 staking-manager impl (not in the Apr-2024 verified impl)
    bytes4 constant SEL_TRANSFER_ETH   = 0xef300f40; // transferETH(address,uint256) - onlyHordCongress
    bytes4 constant SEL_SSV_WITHDRAW   = 0xf4f4b531; // SSV withdrawal wrapper (uint64[],uint256,Cluster) - onlyMaintainer
}
