// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

import './libraries/SafeMath.sol';
import './libraries/SafeERC20.sol';
import './interfaces/IWETH.sol';
import './interfaces/IDYSON.sol';
import './interfaces/IDEXPair.sol';
import './interfaces/IUniswapV2Router02.sol';
import './libraries/DaoOwnable.sol';

contract SphereZap is DaoOwnable{
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint;

    address private constant WMATIC = 0x0d500B1d8E8eF31E21C99d1Db9A6444d3ADf1270;
    address private constant FRAX = 0x45c32fA6DF82ead1e2EF74d17b76547EDdFaFF89;
    address private constant USDT = 0xc2132D05D31c914a87C6611C10748AEb04B58e8F;
    address private constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
    address private constant DAI = 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063;
    address private constant MAI = 0xa3Fa99A148fA48D14Ed51d610c367C61876997F1;
    address private constant Sphere = 0x8D546026012bF75073d8A586f24A5d5ff75b9716;
    address private constant DYSON = 0x991B73fB44a6B618EfBF3403924C09530EE4D5Dc;
    IUniswapV2Router02 private constant ROUTER = IUniswapV2Router02(0xa5E0829CaCEd8fFDD4De3c43696c57F7D7A678ff);

    mapping(address => bool) private HasApprovedRouter;
    address[] public supportTokens;

    // === management functions starts ===

    function approveForRouter(address token) public onlyManager{
        if(HasApprovedRouter[token]) return;
        IERC20(token).approve(address(ROUTER), uint(-1));
        HasApprovedRouter[token] = true;
        supportTokens.push(token);
    }

    function rescueToken(address[] calldata tokens) external onlyManager {
        for (uint i=0; i < tokens.length; i++){
            IERC20 token = IERC20(tokens[i]);
            uint amount = token.balanceOf(address(this));
            token.safeTransfer(manager(), amount);
        }
    }

    function sweep() external onlyManager {
        for (uint i = 0; i < supportTokens.length; i++) {
            address token = supportTokens[i];
            if (token == address(0) || token == WMATIC) continue;
            uint amount = IERC20(token).balanceOf(address(this));
            if (amount > 0) {
                _swapDirect(token, amount, WMATIC);
            }
        }
        IWETH(WMATIC).withdraw(IERC20(WMATIC).balanceOf(address(this)));
        payable(manager()).transfer(payable(address(this)).balance);
    }

    receive() external payable {} // allow receiving BNB

    // === manage functions ends ===

    constructor(){
        require(ROUTER.WETH() == WMATIC);
        approveForRouter(WMATIC);
        approveForRouter(FRAX);
        approveForRouter(USDT);
        approveForRouter(USDC);
        approveForRouter(DAI);
        approveForRouter(MAI);
        approveForRouter(Sphere);
        IERC20(Sphere).approve(address(DYSON), uint(-1)); // allow for SPHERE -> DYSON
    }

    function uint2str(uint _i) internal pure returns (string memory _uintAsString) {
        // convert uint to string, used in revert message
        if (_i == 0) {
            return "0";
        }
        uint j = _i;
        uint len;
        while (j != 0) {
            len++;
            j /= 10;
        }
        bytes memory bstr = new bytes(len);
        uint k = len;
        while (_i != 0) {
            k = k-1;
            uint8 temp = (48 + uint8(_i - _i / 10 * 10));
            bytes1 b1 = bytes1(temp);
            bstr[k] = b1;
            _i /= 10;
        }
        return string(bstr);
    }

    function _swapDirect(address _from, uint amount, address _to) internal returns (uint){
        if(_from == _to) return amount; // no need to swap
        address[] memory path;
        path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        uint[] memory amounts = ROUTER.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
        return amounts[amounts.length - 1];
    }

    // === ZapAndStake starts ===
    // user input a token or MATIC, swap it to SPHERE (direct or byPath)

    event Zap(address indexed, uint256);

    function _Zap(address token, uint256 amount, uint256 minOutAmount) internal{
        uint256 SphereAmount;
        if(token != Sphere){
            SphereAmount = _swapDirect(token, amount, Sphere);
        }else{
            SphereAmount = amount;
        }
        require(SphereAmount >= minOutAmount, string(abi.encodePacked("slippage exceeds, can only receive ", uint2str(SphereAmount))));
        emit Zap(msg.sender, SphereAmount);
    }

    function zap(address token, uint256 amount, uint256 minOutAmount) public {
        IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
        return _Zap(token, amount, minOutAmount);
    }

    function MATICZap(uint256 minOutAmount) external payable{
        uint256 amount = msg.value;
        IWETH(WMATIC).deposit{value: amount}();
        return _Zap(WMATIC, amount, minOutAmount);
    }

    function _swapByPath(address[] calldata path, uint amount) internal returns (uint){
        if(path.length==1) return amount; // no need to swap
        uint[] memory amounts = ROUTER.swapExactTokensForTokens(amount, 0, path, address(this), block.timestamp);
        return amounts[amounts.length - 1];
    }

    function _ZapAndStakeByPath(address[] calldata path, uint256 amount, uint256 minOutAmount) public {
        require(path[path.length - 1]== Sphere, "path should end with Sphere");
        uint256 sphereAmount = _swapByPath(path, amount);
        require(sphereAmount >= minOutAmount, string(abi.encodePacked("slippage exceeds, can only receive ", uint2str(sphereAmount))));
    }

    function ZapAndStakeByPath(address[] calldata path, uint256 amount, uint256 minOutAmount) external {
        address token = path[0];
        return IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
    }

    function MATICZapAndStakeByPath(address[] calldata path, uint256 minOutAmount) external payable{
        uint256 amount = msg.value;
        IWETH(WMATIC).deposit{value: amount}();
        require(path[0]== WMATIC, "path should start with WBNB");
        return _ZapAndStakeByPath(path, amount, minOutAmount);
    }

    // === ZapAndStake ends ===
}