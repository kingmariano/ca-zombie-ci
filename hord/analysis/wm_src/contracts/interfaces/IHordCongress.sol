// "SPDX-License-Identifier: UNLICENSED"
pragma solidity 0.7.5;

/**
 * IHordCongress contract.
 * @author Srdjan Simonovic
 * Date created: 18.04.23.
 * Github: s2imonoivc
 */
interface IHordCongress {
    function getMembersRegistry() external view returns (address);
}