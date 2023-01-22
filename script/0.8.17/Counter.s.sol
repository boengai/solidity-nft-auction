// SPDX-License-Identifier: GPL-3.0

pragma solidity ^0.8.17;

import "forge-std/Script.sol";

contract CounterScript is Script {
    function setUp() public {}

    function run() public {
        vm.broadcast();
    }
}
