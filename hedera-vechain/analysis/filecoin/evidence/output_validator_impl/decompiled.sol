// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

/// @title            Decompiled Contract
/// @author           Jonathan Becker <jonathan@jbecker.dev>
/// @custom:version   heimdall-rs v0.9.2
///
/// @notice           This contract was decompiled using the heimdall-rs decompiler.
///                     It was generated directly by tracing the EVM opcodes from this contract.
///                     As a result, it may not compile or even be valid solidity code.
///                     Despite this, it should be obvious what each function does. Overall
///                     logic should have been preserved throughout decompiling.
///
/// @custom:github    You can find the open-source decompiler here:
///                       https://heimdall.rs

contract DecompiledContract {
    uint256 public constant tenThousand = 10000;
    
    uint256 public operator;
    uint256 public unresolved_1bd1923f;
    uint256 public unresolved_8698f6cb;
    uint256 public unresolved_058d7a3f;
    address public unresolved_700a116a;
    address public governance;
    address public owner;
    address public unresolved_68f7fdd7;
    address public liquidStaking;
    uint256 public unresolved_409b9c96;
    address public unresolved_45e86736;
    uint256 public nodeId;
    uint256 public unresolved_152d4e5f;
    uint256 public unresolved_784c7f3a;
    
    event Claims(uint256, uint256, uint256);
    event OwnershipTransferred(address, address);
    
    /// @custom:selector    0x879bc1e6
    /// @custom:signature   setKingHashVault(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setKingHashVault(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        unresolved_68f7fdd7 = (address(arg0)) | (uint96(unresolved_68f7fdd7));
    }
    
    /// @custom:selector    0xabd19037
    /// @custom:signature   depositFil(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function depositFil(uint256 arg0, uint256 arg1) public payable {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(!(arg0 == operator), "address to not allow");
        require(arg0 == operator, "address to not allow");
        uint256 var_b = arg1;
        require(address(liquidStaking).code.length);
        (bool success, bytes memory ret0) = address(liquidStaking).{ value: 0 ether }Unresolved_a3603ca6(var_b); // call
        require(!(unresolved_409b9c96 > (arg1 + unresolved_409b9c96)), "address to not allow");
        unresolved_409b9c96 = var_b + unresolved_409b9c96;
        require(operator > 0, "address to not allow");
    }
    
    /// @custom:selector    0x1a99caed
    /// @custom:signature   Unresolved_1a99caed(uint256 arg0) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_1a99caed(uint256 arg0) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) > 0xffffffffffffffff));
        var_c = 0x40 + var_c;
        require(!0x01 > (var_i + 0x01));
        require(!(var_i + 0x01) > 0xffffffffffffffff);
        var_c = var_c + (0x20 + (uint248(0x1f + (var_k + 0x01))));
        require(!var_i + 0x01);
        require(!var_l);
        require(0x02);
        var_c = 0x40 + var_c;
        var_c = 0x40 + var_c;
        require(0x20);
        require(!0);
        require(0x20);
        require(!0x20 > 0x20);
        require(!0x40 > 0x60);
        require(!((0x60 + var_c) + 0x20) < var_c);
        require(0x01 > 0x17);
        require(0x01 > 0xff);
        require(0x01 > 0xffff);
        require(0x01 > 0xffffffff);
        require(!0x01 > (var_y + 0x01));
        require(var_y < (var_o));
        require((var_y + 0x01) == (((var_y + 0x01) * 0x02) / 0x02) | !0x02);
        var_c = 0x40 + var_c;
        require(0x20);
        require(!((var_y + 0x01) * 0x02) % 0x20);
        require(!((((var_y + 0x01) * 0x02) + var_c) + 0x20) < var_c);
        require(!var_y > var_y);
        require(!var_y > (var_y + var_y));
        require(!(var_y + var_y) > (var_o));
        require((var_y + var_y) == (((var_y + var_y) * 0x02) / 0x02) | !0x02);
        var_c = 0x40 + var_c;
        require(0x20);
        require(!((var_y + var_y) * 0x02) % 0x20);
        require(0x20);
        require(!(0x20 - (((var_y + var_y) * 0x02) % 0x20)) > 0x20);
        require(!((var_y + var_y) * 0x02) > ((0x20 - (((var_y + var_y) * 0x02) % 0x20)) + ((var_y + var_y) * 0x02)));
        require(!(((0x20 - (((var_y + var_y) * 0x02) % 0x20)) + ((var_y + var_y) * 0x02) + var_c) + 0x20) < var_c);
        require(!var_y > var_y);
        require(!var_y > (var_y + var_y));
        require(!(var_y + var_y) > (var_o));
        require((var_y + var_y) == (((var_y + var_y) * 0x02) / 0x02) | !0x02);
        var_c = 0x40 + var_c;
        require(0x20);
        require(!((var_y + var_y) * 0x02) % 0x20);
        require(0x20);
        require(!(0x20 - (((var_y + var_y) * 0x02) % 0x20)) > 0x20);
        require(!((var_y + var_y) * 0x02) > ((0x20 - (((var_y + var_y) * 0x02) % 0x20)) + ((var_y + var_y) * 0x02)));
        require(!(((0x20 - (((var_y + var_y) * 0x02) % 0x20)) + ((var_y + var_y) * 0x02) + var_c) + 0x20) < var_c);
        require(!var_y > var_y);
        if (!var_y > (var_y + var_y)) {
            if (!(var_y + var_y) > (var_o)) {
                require(!var_y > (var_y + var_y));
                require(!(var_y + var_y) > (var_o));
                require((var_y + var_y) == (((var_y + var_y) * 0x02) / 0x02) | !0x02);
                require(0x20);
                require(!((var_y + var_y) * 0x02) % 0x20);
                require(0x20);
                require(!(0x20 - (((var_y + var_y) * 0x02) % 0x20)) > 0x20);
                require(!((var_y + var_y) * 0x02) > ((0x20 - (((var_y + var_y) * 0x02) % 0x20)) + ((var_y + var_y) * 0x02)));
            }
            require(!(var_y + var_y) > var_y);
        }
    }
    
    /// @custom:selector    0x8bf13688
    /// @custom:signature   setLiquidStakingRewardAddress(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setLiquidStakingRewardAddress(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        unresolved_45e86736 = (address(arg0)) | (uint96(unresolved_45e86736));
    }
    
    /// @custom:selector    0xab033ea9
    /// @custom:signature   setGovernance(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setGovernance(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        governance = (address(arg0)) | (uint96(governance));
    }
    
    /// @custom:selector    0xc303ad80
    /// @custom:signature   Unresolved_c303ad80(uint256 arg0, uint256 arg1) public pure
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_c303ad80(uint256 arg0, uint256 arg1) public pure {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0) > 0xffffffffffffffff);
        require(!((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) > 0xffffffffffffffff));
        require(!arg1 > 0xffffffffffffffff);
    }
    
    /// @custom:selector    0x432e4714
    /// @custom:signature   Unresolved_432e4714(address arg0) public pure
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function Unresolved_432e4714(address arg0) public pure {
        require(arg0 == (address(arg0)));
    }
    
    /// @custom:selector    0xa9634214
    /// @custom:signature   setOperatorAndNode(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setOperatorAndNode(uint256 arg0, uint256 arg1) public payable {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        operator = arg0;
        nodeId = arg1;
    }
    
    /// @custom:selector    0x4f604921
    /// @custom:signature   setVaultPer(uint256 arg0, uint256 arg1) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function setVaultPer(uint256 arg0, uint256 arg1) public payable {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(!(arg1 > 0x2710), "_operatoVaultPer must <= 10000");
        require(!(arg0 > 0x2710), "_liquidStakingPer must <= 10000");
        unresolved_784c7f3a = arg0;
        unresolved_1bd1923f = arg1;
    }
    
    /// @custom:selector    0x08211be5
    /// @custom:signature   setLiquidStaking(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setLiquidStaking(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        liquidStaking = (address(arg0)) | (uint96(liquidStaking));
    }
    
    /// @custom:selector    0x15ada11c
    /// @custom:signature   Unresolved_15ada11c(uint256 arg0, uint256 arg1) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function Unresolved_15ada11c(uint256 arg0, uint256 arg1) public view {
        require(!arg1 > 0xffffffffffffffff);
        require(!(arg1) > 0xffffffffffffffff);
        require(arg0 > 0, "amount must > 0");
        var_a = var_a + 0x20;
        require(0, "amount must > 0");
    }
    
    /// @custom:selector    0xcdc4444c
    /// @custom:signature   withdrawBalanceFil() public payable
    function withdrawBalanceFil() public payable {
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(address(this).balance > 0, "amount must > 0");
        require(address(liquidStaking / 0x01).code.length);
        (bool success, bytes memory ret0) = address(liquidStaking / 0x01).{ value: address(this).balance }repayment(); // call
        if (!(unresolved_409b9c96 - address(this).balance) > unresolved_409b9c96) {
            unresolved_409b9c96 = unresolved_409b9c96 - address(this).balance;
        }
    }
    
    /// @custom:selector    0x52d00876
    /// @custom:signature   setOperatoVault(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function setOperatoVault(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        unresolved_700a116a = (address(arg0)) | (uint96(unresolved_700a116a));
    }
    
    /// @custom:selector    0xf919801d
    /// @custom:signature   Unresolved_f919801d(uint256 arg0) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_f919801d(uint256 arg0) public view {
        require(!arg0 > 0xffffffffffffffff);
        require(!(arg0 > 0xffffffffffffffff), "caller is not allow");
        require(!(((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) < var_c) | ((var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f))) > 0xffffffffffffffff)), "caller is not allow");
        uint256 var_c = var_c + (uint248((0x20 + (0x1f + (arg0))) + 0x1f));
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(0);
    }
    
    /// @custom:selector    0xf2fde38b
    /// @custom:signature   transferOwnership(address arg0) public payable
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function transferOwnership(address arg0) public payable {
        require(arg0 == (address(arg0)));
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        require(address(arg0), "Ownable: new owner is the zero address");
        owner = (address(arg0)) | (uint96(owner));
        emit OwnershipTransferred(address(owner), address(arg0));
    }
    
    /// @custom:selector    0xd1f3bf5c
    /// @custom:signature   Unresolved_d1f3bf5c(uint256 arg0) public payable
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function Unresolved_d1f3bf5c(uint256 arg0) public payable {
        require(arg0 == arg0);
        require(address(owner) == msg.sender, "caller is not allow");
        require(msg.sender == (address(governance)), "caller is not allow");
        require(address(this).balance > 0, "amount must > 0");
        require((unresolved_1bd1923f == ((unresolved_1bd1923f * address(this).balance) / address(this).balance)) | !address(this).balance);
        require(0x2710);
        require(!(address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710)) > address(this).balance);
        require((unresolved_784c7f3a == ((unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710)))) | (!address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710)));
        require(0x2710);
        require(!(address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710) - ((unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / 0x2710)) > (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710)));
        require(!(address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710)) - ((unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / 0x2710));
        require(!(unresolved_1bd1923f * address(this).balance) / 0x2710);
        require(address(unresolved_700a116a));
        require(!unresolved_8698f6cb > (((unresolved_1bd1923f * address(this).balance) / 0x2710) + unresolved_8698f6cb));
        unresolved_8698f6cb = ((unresolved_1bd1923f * address(this).balance) / 0x2710) + unresolved_8698f6cb;
        uint256 var_b = arg0;
        require(address(unresolved_700a116a).code.length);
        (bool success, bytes memory ret0) = address(unresolved_700a116a).{ value: (unresolved_1bd1923f * address(this).balance) / 0x2710 }Unresolved_0e6878a3(var_b); // call
        require(!((unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / 0x2710), "liquidStakingRewardAddress is zero");
        require(address(unresolved_45e86736), "liquidStakingRewardAddress is zero");
        emit Claims(address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710) - ((unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / 0x2710), (unresolved_1bd1923f * address(this).balance) / 0x2710, (unresolved_784c7f3a * (address(this).balance - ((unresolved_1bd1923f * address(this).balance) / 0x2710))) / 0x2710);
        require(address(unresolved_68f7fdd7), "kingHashVault is zero");
    }
    
    /// @custom:selector    0x951e01b1
    /// @custom:signature   Unresolved_951e01b1(uint256 arg0, uint256 arg1, uint256 arg2) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    /// @param              arg2 ["uint256", "bytes32", "int256"]
    function Unresolved_951e01b1(uint256 arg0, uint256 arg1, uint256 arg2) public view {
        require(arg0 == arg0);
        require(!arg2 > 0xffffffffffffffff);
        require(!(arg2) > 0xffffffffffffffff);
        require(arg1 > 0, "_amount must > 0");
        var_a = var_a + 0x20;
        require(0, "_amount must > 0");
    }
    
    /// @custom:selector    0x715018a6
    /// @custom:signature   renounceOwnership() public payable
    function renounceOwnership() public payable {
        require(msg.sender == (address(owner)), "Ownable: caller is not the owner");
        owner = 0 | (uint96(owner));
        emit OwnershipTransferred(address(owner), 0);
    }
}