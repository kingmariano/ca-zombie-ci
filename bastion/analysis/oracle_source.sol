// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.15;

import { IOracle } from "./Adapter/IOracle.sol";
import { UniswapAnchoredView, PriceData } from "./UniswapAnchoredView.sol";

interface Comptroller {
    function oracle() external view returns (address);
}

/**
 * @title BastionAuriOracle
 * @author Bastion
 * @notice Oracle that returns the price of auriToken
 */
contract BastionAuriOracle is UniswapAnchoredView {
    mapping(address => address) public cTokensToAuTokens;

    address immutable auriComptroller;

    constructor(
        address _auriComptroller,
        uint256 anchorToleranceMantissa_,
        uint256 anchorPeriod_,
        TokenConfig[] memory configs
    ) UniswapAnchoredView(anchorToleranceMantissa_, anchorPeriod_, configs) {
        auriComptroller = _auriComptroller;
    }

    function getReporterPrice(TokenConfig memory config) internal view override returns (uint256) {
        address oracle = Comptroller(auriComptroller).oracle();
        return (IOracle(oracle).getUnderlyingPrice(config.reporter) * config.baseUnit) / 1e30;
    }
}
