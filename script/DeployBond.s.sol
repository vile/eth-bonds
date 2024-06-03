// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";

import {Bond} from "../src/Bond.sol";

contract DeployBond is Script {
    address private constant BENEFICIARY = address(1);
    uint256 private constant BOND_PRICE = 0.5 ether;
    uint8 private constant SHOULD_BURN_BONDS = 2;

    function setUp() public {}

    function run() public returns (address bond) {
        bond = address(new Bond(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS));
    }
}
