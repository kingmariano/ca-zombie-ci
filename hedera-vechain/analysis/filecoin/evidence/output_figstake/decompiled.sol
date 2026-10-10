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
    uint256 public constant _token = 1144645269372312478464541741969565754055487956404;
    
    mapping(bytes32 => bytes32) storage_map_f;
    mapping(bytes32 => bytes32) storage_map_w;
    mapping(bytes32 => bytes32) storage_map_ay;
    mapping(bytes32 => bytes32) storage_map_ao;
    mapping(bytes32 => bytes32) storage_map_am;
    mapping(bytes32 => bytes32) storage_map_ak;
    uint256 public accumulatedStake;
    mapping(bytes32 => bytes32) storage_map_af;
    mapping(bytes32 => bytes32) storage_map_bh;
    mapping(bytes32 => bytes32) storage_map_ac;
    mapping(bytes32 => bytes32) storage_map_ar;
    bytes32 store_l;
    mapping(bytes32 => bytes32) storage_map_o;
    mapping(bytes32 => bytes32) storage_map_ah;
    mapping(bytes32 => bytes32) storage_map_v;
    mapping(bytes32 => bytes32) storage_map_d;
    uint256 public accumulatedPower;
    mapping(bytes32 => bytes32) storage_map_au;
    mapping(bytes32 => bytes32) storage_map_h;
    mapping(bytes32 => bytes32) storage_map_g;
    mapping(bytes32 => bytes32) storage_map_aq;
    mapping(bytes32 => bytes32) storage_map_t;
    mapping(bytes32 => bytes32) storage_map_aa;
    mapping(bytes32 => bytes32) storage_map_y;
    uint256 public getBonusNum;
    mapping(bytes32 => bytes32) storage_map_m;
    mapping(bytes32 => bytes32) storage_map_ag;
    mapping(bytes32 => bytes32) storage_map_be;
    mapping(bytes32 => bytes32) storage_map_bd;
    mapping(bytes32 => bytes32) storage_map_bc;
    mapping(bytes32 => bytes32) storage_map_c;
    mapping(bytes32 => bytes32) storage_map_bf;
    uint256 public accumulatedWithdrawn;
    mapping(bytes32 => bytes32) storage_map_q;
    mapping(bytes32 => bytes32) storage_map_al;
    mapping(bytes32 => bytes32) storage_map_s;
    mapping(bytes32 => bytes32) storage_map_av;
    mapping(bytes32 => bytes32) storage_map_aw;
    mapping(bytes32 => bytes32) storage_map_ap;
    mapping(bytes32 => bytes32) storage_map_az;
    mapping(bytes32 => bytes32) storage_map_j;
    mapping(bytes32 => bytes32) storage_map_bb;
    mapping(bytes32 => bytes32) storage_map_an;
    mapping(bytes32 => bytes32) storage_map_b;
    mapping(bytes32 => bytes32) storage_map_e;
    bytes32 store_i;
    mapping(bytes32 => bytes32) storage_map_ae;
    uint256 public accumulatedBonus;
    mapping(bytes32 => bytes32) storage_map_at;
    mapping(bytes32 => bytes32) storage_map_z;
    mapping(bytes32 => bytes32) storage_map_ba;
    mapping(bytes32 => bytes32) storage_map_ab;
    mapping(bytes32 => bytes32) storage_map_a;
    mapping(bytes32 => bytes32) storage_map_as;
    mapping(bytes32 => bytes32) storage_map_bg;
    mapping(bytes32 => bytes32) storage_map_r;
    bytes32 store_aj;
    mapping(bytes32 => bytes32) storage_map_p;
    mapping(bytes32 => bytes32) storage_map_u;
    mapping(bytes32 => bytes32) storage_map_ax;
    
    
    /// @custom:selector    0x7612f53c
    /// @custom:signature   getUserStakeAmount(address arg0) public view returns (uint256)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function getUserStakeAmount(address arg0) public view returns (uint256) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        return storage_map_a[var_a];
    }
    
    /// @custom:selector    0xce325bf8
    /// @custom:signature   getStake(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getStake(uint256 arg0) public view returns (bytes memory) {
        require(!0 > 0x03);
        uint256 var_h = arg0;
        var_a = var_a + 0xe0;
        require(!(bytes1(storage_map_h[var_h])) > 0x03);
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(bytes1(storage_map_h[var_h])) > 0x03);
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(var_ad < 0x04);
        return abi.encodePacked(address(var_a.length), var_af, var_ag, var_ah, var_ai, var_aj, var_ak);
    }
    
    /// @custom:selector    0x2e9f411e
    /// @custom:signature   staking(uint256 arg0, uint256 arg1) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    /// @param              arg1 ["uint256", "bytes32", "int256"]
    function staking(uint256 arg0, uint256 arg1) public {
        require(store_i - 0x02, "ReentrancyGuard: reentrant call");
        store_i = 0x02;
        require(!arg0 < 0x8ac7230489e80000);
        address var_b = address(msg.sender);
        (bool success, bytes memory ret0) = address(0xc87fab479b450993e8a7b498c631adf81f3ca5b4).Unresolved_70a08231(var_b); // staticcall
        uint256 var_e = var_e + (uint248(ret0.length + 0x1f));
        require(!(((var_e + ret0.length) - var_e) < 0x20), "Insufficient balance");
        require(!(var_e.length < arg0), "Insufficient balance");
        var_c = 0x20;
        address var_h = address(msg.sender);
        var_e = var_c + (var_e + (0x20 * storage_map_b[var_h]));
        require(!storage_map_b[var_h], "User stakes overflow");
        var_h = keccak256(var_h);
        require((var_e + 0x20) + (0x20 * storage_map_b[var_h]) > (0x20 + (var_e + 0x20)), "User stakes overflow");
        require(!(var_e.length > 0xffffffffffffffff), "User stakes overflow");
        var_e = var_e + (0x20 + (0x20 * var_e.length));
        require(!var_e.length, "User stakes overflow");
        var_e = 0xe0 + var_e;
        require(!(0 > 0x03), "User stakes overflow");
        require(var_e.length - 0x01, "User stakes overflow");
        var_h = var_s;
        var_e = var_e + 0xe0;
        require(!(bytes1(storage_map_h[var_h]) > 0x03), "User stakes overflow");
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(bytes1(storage_map_h[var_h]) > 0x03), "User stakes overflow");
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0x01, "User stakes overflow");
        require(var_e.length < 0x14, "User stakes overflow");
        require(!arg1 > 0x03);
        require(!arg1 > 0x03);
        require(!arg1 > 0x03);
        var_h = arg1;
        require((arg0 == ((arg0 * (storage_map_j[var_h])) / (storage_map_j[var_h]))) | (!storage_map_j[var_h]));
        var_h = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!accumulatedPower > ((arg0 * (storage_map_j[var_h])) + accumulatedPower));
        require(!0 > 0x03);
    }
    
    /// @custom:selector    0xe4235ba8
    /// @custom:signature   getTotalStakeList() public view returns (bytes memory)
    function getTotalStakeList() public view returns (bytes memory) {
        uint256 var_a = var_a + (0x20 + (0x20 * store_l));
        if (!store_l) {
            var_c = 0x08;
            if ((0x20 + var_a) + (0x20 * store_l) > (0x20 + (0x20 + var_a))) {
                return abi.encodePacked(0x20, var_a.length);
            }
        }
    }
    
    /// @custom:selector    0x2027f265
    /// @custom:signature   getFactor(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getFactor(uint256 arg0) public view returns (bytes memory) {
        require(!arg0 > 0x03);
        require(!arg0 > 0x03);
        require(!arg0 > 0x03);
        uint256 var_d = arg0;
        var_a = 0x40 + var_a;
        return abi.encodePacked(var_a.length, var_l);
    }
    
    /// @custom:selector    0x3ccfd60b
    /// @custom:signature   withdraw() public returns (uint256)
    function withdraw() public returns (uint256) {
        require(store_i - 0x02, "ReentrancyGuard: reentrant call");
        var_b = 0x20;
        store_i = 0x02;
        address var_e = address(msg.sender);
        address var_g = var_b + (var_g + (0x20 * storage_map_q[var_e]));
        if (!storage_map_q[var_e]) {
            var_e = keccak256(var_e);
            require(!storage_map_q[var_e], "Invalid withdraw amount");
            require((var_g + 0x20) + (0x20 * storage_map_q[var_e]) > (0x20 + (var_g + 0x20)), "Invalid withdraw amount");
            var_g = var_g + (0x20 + (0x20 * var_g.length));
            require(!(var_g.length > 0xffffffffffffffff), "Invalid withdraw amount");
            var_g = 0xe0 + var_g;
            require(!var_g.length, "Invalid withdraw amount");
            require(!(0 > 0x03), "Invalid withdraw amount");
            var_e = var_q;
            var_g = var_g + 0xe0;
            require(var_g.length - 0x01, "Invalid withdraw amount");
            var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_w[var_e]) > 0x03), "Invalid withdraw amount");
            var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_w[var_e]) > 0x03), "Invalid withdraw amount");
            require(0x01, "Invalid withdraw amount");
            require(!(var_z < getBonusNum), "Invalid withdraw amount");
            var_e = 0x02;
            var_g = var_g + 0x80;
            require(var_z < getBonusNum, "Invalid withdraw amount");
            require(!(var_aa > 0x03), "Invalid withdraw amount");
            var_e = keccak256(var_e);
            require(var_aa < storage_map_q[var_e], "Invalid withdraw amount");
            require(0 - (storage_map_ac[var_e]), "Invalid withdraw amount");
            require(!(block.number > (var_ab)), "Invalid withdraw amount");
            require(!(block.number > (var_ac)), "Invalid withdraw amount");
            require(!(block.number > (var_ac)), "Invalid withdraw amount");
            require(var_z + 0x01, "Invalid withdraw amount");
            var_e = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(var_ad == (var_ad * (storage_map_ac[var_e]) / (storage_map_ac[var_e])) | (!storage_map_ac[var_e]), "Invalid withdraw amount");
            require(0x0f4240, "Invalid withdraw amount");
            require(!(var_ab - (var_ac) > (var_ab)), "Invalid withdraw amount");
            require(!((block.number - (var_ae)) > block.number), "Invalid withdraw amount");
        }
        require(!(var_g.length < (var_af)), "Invalid withdraw amount");
        require(!0);
        (bool success, bytes memory ret0) = address(msg.sender).transfer(0);
        store_i = 0x01;
        return 0;
        store_i = 0x01;
        return 0;
        if (!0 > 0x03) {
        }
    }
    
    /// @custom:selector    0xe133fa34
    /// @custom:signature   getBonusRewards(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getBonusRewards(uint256 arg0) public view returns (bytes memory) {
        uint256 var_a = arg0;
        uint256 var_c = 0x20 + (var_c + (0x20 * storage_map_a[var_a]));
        require(!storage_map_a[var_a]);
        var_a = keccak256(var_a);
        require((var_c + 0x20) + (0x20 * storage_map_a[var_a]) > (0x20 + (var_c + 0x20)));
        return abi.encodePacked(0x20, var_c.length);
    }
    
    /// @custom:selector    0x4aa66b28
    /// @custom:signature   getBonus(uint256 arg0) public view returns (bytes memory)
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function getBonus(uint256 arg0) public view returns (bytes memory) {
        require(arg0 < getBonusNum);
        var_f = 0x02;
        var_a = 0x80 + var_a;
        return abi.encodePacked(var_a.length, var_r, var_s, var_t);
    }
    
    /// @custom:selector    0xab786827
    /// @custom:signature   createBonus() public
    function createBonus() public {
        require(store_i - 0x02, "Invalid transfer");
        store_i = 0x02;
        require(accumulatedPower, "Invalid transfer");
        require(!((accumulatedBonus - store_aj) > accumulatedBonus), "Invalid transfer");
        require(!(address(this).balance > (accumulatedWithdrawn + address(this).balance)), "Invalid transfer");
    }
    
    /// @custom:selector    0xf2f31a50
    /// @custom:signature   avaiableFil() public view
    function avaiableFil() public view {
        if (!(accumulatedBonus - store_aj) > accumulatedBonus) {
            if (!address(this).balance > (accumulatedWithdrawn + address(this).balance)) {
            }
        }
    }
    
    /// @custom:selector    0x842e2981
    /// @custom:signature   getUserStakes(address arg0) public view returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function getUserStakes(address arg0) public view returns (bytes memory) {
        require(arg0 == (address(arg0)));
        address var_a = address(arg0);
        address var_c = 0x20 + (var_c + (0x20 * storage_map_a[var_a]));
        require(!storage_map_a[var_a]);
        var_a = keccak256(var_a);
        require((var_c + 0x20) + (0x20 * storage_map_a[var_a]) > (0x20 + (var_c + 0x20)));
        require(!var_c.length > 0xffffffffffffffff);
        var_c = var_c + (0x20 + (0x20 * var_c.length));
        require(!var_c.length);
        var_c = 0xe0 + var_c;
        require(!0 > 0x03);
        require(var_c.length - 0x01);
        var_a = var_n;
        var_c = var_c + 0xe0;
        require(!(bytes1(storage_map_ap[var_a])) > 0x03);
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(bytes1(storage_map_ap[var_a])) > 0x03);
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(0x01);
        require(var_ac < 0x04);
        return abi.encodePacked(0x20, var_c.length);
        require(!0 > 0x03);
    }
    
    /// @custom:selector    0x5f5f93b1
    /// @custom:signature   stakeBonus(uint256 arg0) public view
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function stakeBonus(uint256 arg0) public view {
        uint256 var_c = arg0;
        if (!(storage_map_av[var_c]) > 0x03) {
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_av[var_c]) > 0x03), "Invalid withdraw amount");
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_av[var_c]) > 0x03), "Invalid withdraw amount");
            require(!(var_m < getBonusNum), "Invalid withdraw amount");
            var_c = 0x02;
            var_a = var_a + 0x80;
            require(var_m < getBonusNum, "Invalid withdraw amount");
            require(!(var_r > 0x03), "Invalid withdraw amount");
            var_c = keccak256(var_c);
            require(var_r < storage_map_m[var_c], "Invalid withdraw amount");
            require(0 - (storage_map_ba[var_c]), "Invalid withdraw amount");
            require(!(block.number > (var_s)), "Invalid withdraw amount");
            require(!(block.number > (var_t)), "Invalid withdraw amount");
            require(!(block.number > (var_t)), "Invalid withdraw amount");
            require(var_m + 0x01, "Invalid withdraw amount");
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(var_t == (var_t * (storage_map_ba[var_c]) / (storage_map_ba[var_c])) | (!storage_map_ba[var_c]), "Invalid withdraw amount");
            require(0x0f4240, "Invalid withdraw amount");
            require(!(var_s - (var_t) > (var_s)), "Invalid withdraw amount");
            require(!((block.number - (var_u)) > block.number), "Invalid withdraw amount");
        }
        require(!(var_a.length < (var_v)), "Invalid withdraw amount");
    }
    
    /// @custom:selector    0x19262d30
    /// @custom:signature   canWithdraw(address arg0) public view returns (bytes memory)
    /// @param              arg0 ["address", "uint160", "bytes20", "int160"]
    function canWithdraw(address arg0) public view returns (bytes memory) {
        require(arg0 == (address(arg0)));
        address var_c = address(arg0);
        var_a = 0x20 + (var_a + (0x20 * storage_map_m[var_c]));
        if (!storage_map_m[var_c]) {
            var_c = keccak256(var_c);
            require(!storage_map_m[var_c], "Invalid withdraw amount");
            require((var_a + 0x20) + (0x20 * storage_map_m[var_c]) > (0x20 + (var_a + 0x20)), "Invalid withdraw amount");
            var_a = var_a + (0x20 + (0x20 * var_a.length));
            require(!(var_a.length > 0xffffffffffffffff), "Invalid withdraw amount");
            var_a = 0xe0 + var_a;
            require(!var_a.length, "Invalid withdraw amount");
            require(!(0 > 0x03), "Invalid withdraw amount");
            var_c = var_o;
            var_a = var_a + 0xe0;
            require(var_a.length - 0x01, "Invalid withdraw amount");
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_av[var_c]) > 0x03), "Invalid withdraw amount");
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(!(bytes1(storage_map_av[var_c]) > 0x03), "Invalid withdraw amount");
            require(0x01, "Invalid withdraw amount");
            require(!(var_w < getBonusNum), "Invalid withdraw amount");
            var_c = 0x02;
            var_a = var_a + 0x80;
            require(var_w < getBonusNum, "Invalid withdraw amount");
            require(!(var_x > 0x03), "Invalid withdraw amount");
            var_c = keccak256(var_c);
            require(var_x < storage_map_m[var_c], "Invalid withdraw amount");
            require(0 - (storage_map_bf[var_c]), "Invalid withdraw amount");
            require(!(block.number > (var_y)), "Invalid withdraw amount");
            require(!(block.number > (var_z)), "Invalid withdraw amount");
            require(!(block.number > (var_z)), "Invalid withdraw amount");
            require(var_w + 0x01, "Invalid withdraw amount");
            var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
            require(var_aa == (var_aa * (storage_map_bf[var_c]) / (storage_map_bf[var_c])) | (!storage_map_bf[var_c]), "Invalid withdraw amount");
            require(0x0f4240, "Invalid withdraw amount");
            require(!(var_y - (var_z) > (var_y)), "Invalid withdraw amount");
            require(!((block.number - (var_ab)) > block.number), "Invalid withdraw amount");
        }
        require(!(var_a.length < (var_ac)), "Invalid withdraw amount");
        var_c = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!0 < 0x02);
        return abi.encodePacked(address(storage_map_m[var_c]), storage_map_aq[var_c]);
        require(!0 > 0x03);
    }
    
    /// @custom:selector    0x5d3eea91
    /// @custom:signature   unStake(uint256 arg0) public
    /// @param              arg0 ["uint256", "bytes32", "int256"]
    function unStake(uint256 arg0) public {
        require(store_i - 0x02, "Invalid staker");
        store_i = 0x02;
        uint256 var_a = arg0;
        uint256 var_c = var_c + 0xe0;
        require(!(bytes1(storage_map_ap[var_a]) > 0x03), "Invalid staker");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(!(bytes1(storage_map_ap[var_a]) > 0x03), "Invalid staker");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(msg.sender == (address(var_c.length)), "Invalid staker");
        require(!(var_p > 0x03), "Stake end not reached");
        require(!(var_p > 0x03), "Stake end not reached");
        var_a = var_p;
        require(!(var_q > (storage_map_bg[var_a] + (var_q))), "Stake end not reached");
        var_a = 0x4e487b7100000000000000000000000000000000000000000000000000000000;
        require(storage_map_bg[var_a] + (var_q) < block.number, "Stake end not reached");
        require(!(var_p > 0x03), "ReentrancyGuard: reentrant call");
        require(!(var_p > 0x03), "ReentrancyGuard: reentrant call");
        var_a = var_p;
        require(var_s == (var_s * (var_t) / (var_t)) | (!var_t), "ReentrancyGuard: reentrant call");
        require(!((accumulatedPower - (var_s * (var_t))) > accumulatedPower), "ReentrancyGuard: reentrant call");
    }
}