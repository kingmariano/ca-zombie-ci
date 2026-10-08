// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.17;

// Define custom interface for the comptroller
interface IComptroller {
    function getAllMarkets() external view returns (address[] memory);
    function _setMintPaused(address market, bool state) external;
    function _setBorrowPaused(address market, bool state) external;
    function _setTransferPaused(bool state) external;
    function _setSeizePaused(bool state) external;
}

contract PauseGuardian {
    IComptroller public constant comptroller = IComptroller(0x15F69897E6aEBE0463401345543C26d1Fd994abB);
    address public constant pauseGuardianMsig = 0x37C6C7c719DB93085678cE72981CDd96219C9B72;

    mapping(address => bool) public pauseGuardians;

    constructor() {
        // Initialize pause guardians
        pauseGuardians[pauseGuardianMsig] = true; // KineticPauseGuardian
        pauseGuardians[0x650a4D05Df3210fa5Fe8c82Af9811dB03808e5f3] = true; // hypernativePauseGuardian
        pauseGuardians[0x9C32CecE7a302631327fb9A35016bC70Bb6472E2] = true; // Shared pauser (RBL)
    }

    function pauseMintingAndBorrowingForAllMarkets() external onlyPauseGuardian {
        address[] memory markets = comptroller.getAllMarkets();

        uint256 nofMarkets = markets.length;
        for (uint256 i = 0; i < nofMarkets; ++i) {
            comptroller._setMintPaused(markets[i], true);
            comptroller._setBorrowPaused(markets[i], true);
        }
    }

    function pauseMintingAndBorrowingForMarket(address market) external onlyPauseGuardian {
        comptroller._setMintPaused(market, true);
        comptroller._setBorrowPaused(market, true);
    }

    function pauseMintingMarket(address market) external onlyPauseGuardian {
        comptroller._setMintPaused(market, true);
    }

    function pauseBorrowingMarket(address market) external onlyPauseGuardian {
        comptroller._setBorrowPaused(market, true);
    }

    function pauseTransfers() external onlyPauseGuardian {
        comptroller._setTransferPaused(true);
    }

    function pauseLiquidations() external onlyPauseGuardian {
        comptroller._setSeizePaused(true);
    }

    // Modifier to have multiple pause guardians
    modifier onlyPauseGuardian {
        require(pauseGuardians[msg.sender], "Not authorized");
        _;
    }
}