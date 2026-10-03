// SPDX-License-Identifier: AGPL-3.0-or-later
pragma solidity 0.7.5;

import './interfaces/ISphereToken.sol';
import './libraries/SafeMath.sol';
import './libraries/SafeERC20.sol';
import './libraries/Address.sol';
import './types/ERC20.sol';

contract wSPHEREERC20 is ERC20 {
    using SafeERC20 for ERC20;
    using Address for address;
    using SafeMath for uint256;

    address public immutable SPHERE;

    constructor(address _SPHERE) ERC20('Wrapped SPHERE', 'DYSON', 18) {
        require(_SPHERE != address(0));
        SPHERE = _SPHERE;
    }

    /**
        @notice wrap SPHERE
        @param _amount uint
        @return uint
     */
    function wrap(uint256 _amount) external returns (uint256) {
        IERC20(SPHERE).transferFrom(msg.sender, address(this), _amount);

        uint256 value = SPHEREtoDYSON(_amount);
        _mint(msg.sender, value);
        return value;
    }

    /**
        @notice unwrap to SPHERE
        @param _amount uint
        @return uint
     */
    function unwrap(uint256 _amount) external returns (uint256) {
        _burn(msg.sender, _amount);

        uint256 value = DYSONToSPHERE(_amount);
        IERC20(SPHERE).transfer(msg.sender, value);
        return value;
    }

    /**
        @notice converts DYSON amount to SPHERE
        @param _amount uint
        @return uint
     */
    function DYSONToSPHERE(uint256 _amount) public view returns (uint256) {
        return
            _amount.mul(ISphereToken(SPHERE).currentIndex()).div(
                10**decimals()
            );
    }

    /**
        @notice converts SPHERE amount to DYSON
        @param _amount uint
        @return uint
     */
    function SPHEREtoDYSON(uint256 _amount) public view returns (uint256) {
        return
            _amount.mul(10**decimals()).div(
                ISphereToken(SPHERE).currentIndex()
            );
    }

    function currentIndex() internal view returns (uint256) {
        return ISphereToken(SPHERE).currentIndex();
    }

    //@TODO: do calculation of address and returns amount of Sphere
    //calculates how many DYSON tokens user has and converts them to Sphere
    //used for dynamic tax bracket
    function balanceOfSphere(address _address) external view returns (uint256) {
        return
            balanceOf(_address).mul(currentIndex()).div(
                10**decimals()
            );
    }

    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }

    function transfer(address recipient, uint256 amount)
    public
    virtual
    override
    returns (bool)
    {
        bool f = false;
        require(f,
            'trading is disabled'
        );
        return false;
    }
}
