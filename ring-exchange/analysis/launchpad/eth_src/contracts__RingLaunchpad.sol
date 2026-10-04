// SPDX-License-Identifier: MIT
pragma solidity =0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import './interfaces/IFewFactory.sol';
import './interfaces/IFewWrappedToken.sol';
import "./interfaces/IUniswapV2Router02.sol";
import './interfaces/IWETH.sol';

contract RingLaunchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct Creator {
        address origin;
        address sender;
    }
    mapping(address => Creator) public creators;

    uint256 public constant MAX_THRESHOLD = 1000 ether;
    uint256 public constant TOTAL_SUPPLY = 1e27;

    address public immutable uniswapRouter;
    address public immutable weth;
    address public immutable wrappedWETH;
    address public immutable wrappingFactory;
    uint256 public threshold;

    event TokenDeployed(
        address indexed creator,
        address indexed token,
        address indexed wrappedToken,
        uint256 pairAmount
    );
    event ThresholdUpdated(address indexed owner, uint256 threshold);

    error InvalidParameters();
    error InvalidRecipient();

    constructor(
        address _uniswapRouter,
        address _weth,
        address _wrappedWETH,
        address _wrappingFactory
    ) Ownable(msg.sender) {
        uniswapRouter = _uniswapRouter;
        weth = _weth;
        wrappedWETH = _wrappedWETH;
        wrappingFactory = _wrappingFactory;
        threshold = 10 ether;
    }

    function deploy(
        string memory name,
        string memory symbol,
        uint256 pairAmount
    ) public virtual nonReentrant returns (address token, address wrappedToken) {
        if (bytes(name).length == 0 ||
            bytes(name).length > 32 ||
            bytes(symbol).length == 0 ||
            bytes(symbol).length > 16 ||
            pairAmount == 0 ||
            pairAmount > threshold) {
            revert InvalidParameters();
        }

        IFewWrappedToken(wrappedWETH).mint(address(this), pairAmount);

        token = address(new Token(name, symbol));
        wrappedToken = IFewFactory(wrappingFactory).createToken(token);

        IERC20(token).approve(wrappedToken, TOTAL_SUPPLY);
        IFewWrappedToken(wrappedToken).wrap(TOTAL_SUPPLY);

        IERC20(wrappedWETH).approve(uniswapRouter, pairAmount);
        IERC20(wrappedToken).approve(uniswapRouter, TOTAL_SUPPLY);

        IUniswapV2Router02(uniswapRouter).addLiquidity(
            wrappedWETH,
            wrappedToken,
            pairAmount,
            TOTAL_SUPPLY,
            pairAmount,
            TOTAL_SUPPLY,
            address(this),
            block.timestamp
        );

        Creator memory creator = Creator({
            origin: tx.origin,
            sender: msg.sender
        });
        creators[token] = creator;

        emit TokenDeployed(msg.sender, token, wrappedToken, pairAmount);
    }

    function deployWETH(
        string calldata name,
        string calldata symbol,
        uint256 pairAmount,
        uint256 buyAmount,
        address recipient
    ) external virtual returns (address token, address wrappedToken) {
        (token, wrappedToken) = deploy(name, symbol, pairAmount);

        if (buyAmount > 0) {
            IERC20(weth).safeTransferFrom(msg.sender, address(this), buyAmount);
            _buyTokens(recipient, wrappedToken, buyAmount);
        }
    }

    function deployETH(
        string calldata name,
        string calldata symbol,
        uint256 pairAmount,
        address recipient
    ) external payable virtual returns (address token, address wrappedToken) {
        (token, wrappedToken) = deploy(name, symbol, pairAmount);

        if (msg.value > 0) {
            IWETH(weth).deposit{value: msg.value}();
            _buyTokens(recipient, wrappedToken, msg.value);
        }
    }

    function _buyTokens(
        address recipient,
        address wrappedToken,
        uint256 amount
    ) private nonReentrant {
        if (recipient == address(0)) revert InvalidRecipient();

        IERC20(weth).approve(wrappedWETH, amount);
        IFewWrappedToken(wrappedWETH).wrap(amount);

        IERC20(wrappedWETH).approve(uniswapRouter, amount);

        address[] memory path = new address[](2);
        path[0] = wrappedWETH;
        path[1] = wrappedToken;

        IUniswapV2Router02(uniswapRouter).swapExactTokensForTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 wrappedTokenBalance = IERC20(wrappedToken).balanceOf(address(this));
        IFewWrappedToken(wrappedToken).unwrapTo(wrappedTokenBalance, recipient);
    }

    function setThreshold(uint256 _threshold) external onlyOwner {
        if (_threshold > MAX_THRESHOLD) revert InvalidParameters();
        threshold = _threshold;
        emit ThresholdUpdated(msg.sender, threshold);
    }

    receive() external payable {}
}

contract Token is ERC20 {
    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) {
        _mint(msg.sender, 1e27);
    }
}
