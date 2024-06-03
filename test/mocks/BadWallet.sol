// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Bond} from "../../src/Bond.sol";

contract BadWallet {
    Bond private immutable i_bond;

    constructor(Bond bond) {
        i_bond = bond;
    }

    function purchaseBond() external payable {
        i_bond.buyBond{value: msg.value}();
    }

    /// @dev No receive/fallback, so the contract is unable to accept ETH transfers.
    // receive() external payable {}
}
