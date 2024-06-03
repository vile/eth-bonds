// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

contract BadRecipient {
    function doSomething() external payable {
        (bool succ,) = payable(msg.sender).call{value: msg.value}("");
        if (!succ) revert();
    }

    /// @dev No receive/fallback, so the contract is unable to accept ETH transfers.
    // receive() external payable {}
}
