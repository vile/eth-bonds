// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Script} from "forge-std/Script.sol";

import {Bond} from "../src/Bond.sol";

contract DeployBondDry is Script {
    address BENEFICIARY;
    uint256 BOND_PRICE;
    uint8 SHOULD_BURN_BONDS;

    Bond s_bond;

    /// @dev Grab deployment params from .env.
    constructor() {
        BENEFICIARY = vm.envAddress("DEPLOY_BENEFICIARY");
        BOND_PRICE = vm.envUint("DEPLOY_BOND_PRICE");
        SHOULD_BURN_BONDS = uint8(vm.envUint("DEPLOY_SHOULD_BURN_BONDS"));
    }

    modifier broadcast() {
        vm.startBroadcast();
        _;
        vm.stopBroadcast();
    }

    function run() public {
        s_bond = deploy();
        test();
    }

    function deploy() private /* broadcast */ returns (Bond bond) {
        bond = new Bond(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS);
    }

    function test() private view returns (bool) {
        return BENEFICIARY == s_bond.getBeneficiary();
    }
}
