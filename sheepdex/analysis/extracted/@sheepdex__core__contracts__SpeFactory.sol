
pragma solidity =0.7.6;





contract SpeFactory is ISpeFactory, NoDelegateCall {
    struct Parameters {
        address factory;
        address token0;
        address token1;
        uint24 fee;
        int24 tickSpacing;
    }

    Parameters public override parameters;

    ISwapDirector public swapDirector;
    mapping(address => uint24) private _addressFees;
    mapping(address => mapping(address => mapping(uint24 => address))) public override getPool;

    constructor(address driectorAddress) {
        swapDirector = ISwapDirector(driectorAddress);
    }

    function deploy(
        address factory,
        address token0,
        address token1,
        uint24 fee,
        int24 tickSpacing
    ) internal returns (address pool) {
        parameters = Parameters({factory : factory, token0 : token0, token1 : token1, fee : fee, tickSpacing : tickSpacing});
        pool = address(new SpePool{salt : keccak256(abi.encode(token0, token1, fee))}());
        delete parameters;
    }

    function createPool(
        address tokenA,
        address tokenB,
        uint24 fee
    ) external override noDelegateCall returns (address pool) {
        require(tokenA != tokenB);
        (address token0, address token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0));
        int24 tickSpacing = swapDirector.feeAmountTickSpacing(fee);
        require(tickSpacing != 0);
        require(getPool[token0][token1][fee] == address(0));
        pool = deploy(address(this), token0, token1, fee, tickSpacing);
        getPool[token0][token1][fee] = pool;

        getPool[token1][token0][fee] = pool;
        emit PoolCreated(token0, token1, fee, tickSpacing, pool);
    }

    function operator() external view override returns (address) {
        return swapDirector.operator();
    }

    function setFee(address _address, uint24 _fee) external {
        require(msg.sender == swapDirector.operator());
        require(_fee > 0 && _fee <= 3000);
        _addressFees[_address] = _fee;
    }

    function swapFee(address addr, uint24 originalFee) external view override returns (uint24 fee) {
        uint24 _fee = _addressFees[addr];
        if (_fee > 0) {
            return _fee;
        }
        return originalFee;
    }
}