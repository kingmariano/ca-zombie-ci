// SPDX-License-Identifier: MIT
pragma solidity 0.7.5;

interface IDYSON {
    function wrap( uint _amount ) external returns ( uint );
    function unwrap( uint _amount ) external returns ( uint );
}