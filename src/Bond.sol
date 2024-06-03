// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

/*
 *        _ _
 * /\   /(_) | ___
 * \ \ / / | |/ _ \
 *  \ V /| | |  __/
 *   \_/ |_|_|\___| -  https://github.com/Vile
 */

import {Ownable} from "@solady/auth/Ownable.sol";

/// @author Vile (https://x.com/vile92797)
/// @title ETH Bond Contract
/// @notice A simple permissioned contract for managing on-chain "bonds," quoted in ETH.
contract Bond is Ownable {
    /// @dev Limit the amount of gas provided for `call`s.
    uint16 private constant PROVIDED_GAS_FOR_CALL = 2_300;
    uint8 private constant UINT8_TRUE = 1;
    uint8 private constant UINT8_FALSE = 2;

    /// @notice The recipient of rejected bond's ETH, if bonds are not burned.
    address private immutable i_beneficiary;
    /// @notice The price of a bond (e.g. 0.5 Ether).
    uint256 private immutable i_bondPrice;
    /// @dev 1 = true; 2 = false
    /// @notice If `1`, bonds will be sent to the zero address otherwise, `2`, send bonds to the owner.
    uint8 private immutable i_shouldBurnBonds;

    /// @dev 1 = true; 2 = false
    /// @notice Keep track of what users actively have bonds.
    mapping(address user => uint8 hasBond) private s_bonds;
    /// @notice How many users currently have bonds.
    uint256 private s_numActiveBonds;

    /// @notice The Bond contract has been successfully initialized
    event BondInitialized(address indexed beneficiary, uint256 indexed bondPrice, uint8 indexed shouldBurnBonds);
    /// @notice A bond was rejected and ETH bond amount has either been burned or sent to the contract owner.
    event BondRejected(address indexed user);
    /// @notice A bond was accepted and ETH bond amount has been returned to the purchaser.
    event BondAccepted(address indexed user);
    /// @notice A bond has been successfully bought.
    event BondBought(address indexed user);

    error Bond__IncorrectAmountOfETH(uint256 expectedAmount, uint256 providedAmount);
    error Bond__IncorrectBurnBondsNumber(uint8 providedNumber);
    error Bond__InvalidBondPrice();
    error Bond__TransferFailed(address to);
    error Bond__UserAlreadyHasBond(address user);
    error Bond__UserDoesNotHaveBond(address user);
    error Bond__ZeroAddress();

    /// @dev Constructor is marked `payable` to reduce gas.
    /// @param _beneficiary The recipient of rejected bonds (if not burned).
    /// @param _bondPrice The ETH price of the bond, denominated in Wei.
    /// @param _shouldBurnBonds Whether or not bonds should be burned if they are rejected, if they are not burned, the underlying ETH is sent to _beneficiary (1 or 2; true or false).
    constructor(address _beneficiary, uint256 _bondPrice, uint8 _shouldBurnBonds) payable {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(shl(96, _beneficiary)) {
                mstore(0x00, 0xe1fe2893) // `Bond__ZeroAddress()`
                revert(0x1c, 0x04)
            }
            if iszero(_bondPrice) {
                mstore(0x00, 0x0df17592) // `Bond__InvalidBondPrice()`
                revert(0x1c, 0x04)
            }
        }
        // if (_beneficiary == address(0)) revert Bond__ZeroAddress();
        // if (_bondPrice == 0) revert Bond__InvalidBondPrice();
        if (_shouldBurnBonds != UINT8_TRUE && _shouldBurnBonds != UINT8_FALSE) {
            revert Bond__IncorrectBurnBondsNumber(_shouldBurnBonds);
        }

        _initializeOwner(msg.sender);
        i_beneficiary = _beneficiary;
        i_bondPrice = _bondPrice;
        i_shouldBurnBonds = _shouldBurnBonds;

        emit BondInitialized(_beneficiary, _bondPrice, _shouldBurnBonds);
    }

    /// @notice Buy a bond.
    function buyBond() external payable {
        _buyBond(msg.sender);
    }

    /// @notice Buy a bond on behalf of someone else. The bond's ETH will be returned, if accepted, to the wallet it is purchased for, not the caller.
    /// @param behalfOf The user to purchase a bond for.
    function buyBondOnBehalfOf(address behalfOf) external payable {
        _buyBond(behalfOf);
    }

    /// @dev [onlyOwner]
    /// @dev "acceptBond" bond instead of "returnBond" to reduce similarity to "rejectBond".
    /// @notice Returns a user's bonds to them.
    /// @param user The user whose bond should be returned.
    function acceptBond(address user) external payable onlyOwner {
        _acceptBond(user, user);
    }

    /// @dev [onlyOwner]
    /// @dev The entire call with revert if a single ETH transfer fails.
    /// @notice Returns users' bonds to them.
    /// @param users The users whose bonds should be returned.
    function acceptBondBatch(address[] calldata users) external payable onlyOwner {
        uint256 usersLength = users.length;

        for (uint256 i; i < usersLength;) {
            _acceptBond(users[i], users[i]);
            unchecked { i = i + 1; }// forgefmt: disable-line
        }
    }

    /// @dev [onlyOwner]
    /// @notice Accept a bond and send the ETH to an alternative address.
    /// @param user The users whose bonds should be returned.
    /// @param rescueRecipient An alternative address to send the bond's ETH to.
    function rescueBond(address user, address rescueRecipient) external payable onlyOwner {
        _acceptBond(user, rescueRecipient);
    }

    /// @dev [onlyOwner]
    /// @dev Function is not `nonReentrant` as the contract assumes the owner will act in good faith.
    /// @dev In addition to the above, the owner could simply repeatedly call `rejectBond`.
    /// @notice Rejects a user's bond, either burn the bond or send the bond's value to the contract beneficiary.
    /// @param user The user whose bond should be rejected.
    function rejectBond(address user) external payable onlyOwner {
        _rejectBond(user);
    }

    /// @dev [onlyOwner]
    /// @dev The entire call with revert if a single ETH transfer fails.
    /// @notice Reject a batch of users' bonds, either burn the bonds or send the bonds' value to the contract beneficiary.
    /// @param users The list of users whose bond should be rejected.
    function rejectBondBatch(address[] calldata users) external payable onlyOwner {
        uint256 usersLength = users.length;

        for (uint256 i; i < usersLength;) {
            _rejectBond(users[i]);
            unchecked { i = i + 1; }// forgefmt: disable-line
        }
    }

    /// @dev `recipient` allows the owner to "rescue" bonds incase a wallet is not able to receive ETH.
    /// @notice Accept a user's bond.
    /// @param bondOwner The user whose bond should be accepted.
    /// @param recipient The user to send ETH to.
    function _acceptBond(address bondOwner, address recipient) private {
        if (!userHasBond(bondOwner)) revert Bond__UserDoesNotHaveBond(bondOwner);

        s_bonds[bondOwner] = UINT8_FALSE;
        unchecked { s_numActiveBonds = s_numActiveBonds - 1; }// forgefmt: disable-line
        emit BondAccepted(bondOwner);

        // slither-disable-next-line low-level-calls
        (bool succ,) = payable(recipient).call{value: i_bondPrice, gas: PROVIDED_GAS_FOR_CALL}("");
        if (!succ) revert Bond__TransferFailed(bondOwner);
    }

    /// @notice Reject a user's bond.
    /// @param user The user whose bond should be rejected.
    function _rejectBond(address user) private {
        if (!userHasBond(user)) revert Bond__UserDoesNotHaveBond(user);

        s_bonds[user] = UINT8_FALSE;
        unchecked { s_numActiveBonds = s_numActiveBonds - 1; }// forgefmt: disable-line
        emit BondRejected(user);

        /// @dev Defaults to the zero address, but we explicitly set for clarity.
        address recipient;
        i_shouldBurnBonds == UINT8_TRUE ? recipient = address(0) : recipient = i_beneficiary;

        // slither-disable-next-line low-level-calls
        (bool succ,) = payable(recipient).call{value: i_bondPrice, gas: PROVIDED_GAS_FOR_CALL}("");
        if (!succ) revert Bond__TransferFailed(recipient);
    }

    /// @notice Buys a bond for a user (either for the sender or on the behalf of someone else).
    /// @param user The user to purchase a bond for.
    function _buyBond(address user) private {
        if (msg.value != i_bondPrice) revert Bond__IncorrectAmountOfETH(i_bondPrice, msg.value);
        if (userHasBond(user)) revert Bond__UserAlreadyHasBond(user);

        s_bonds[user] = UINT8_TRUE;
        unchecked { s_numActiveBonds = s_numActiveBonds + 1; }// forgefmt: disable-line

        emit BondBought(user);
    }

    /// @notice Check if a user currently has a bond.
    /// @param user The user to check.
    /// @return hasBond Whether or not the user has an active bond.
    function userHasBond(address user) public view returns (bool hasBond) {
        hasBond = s_bonds[user] == UINT8_TRUE;
    }

    /// @notice Get `s_numActiveBonds`
    /// @return numActiveBonds The current number of active bonds.
    function getNumActiveBonds() external view returns (uint256 numActiveBonds) {
        numActiveBonds = s_numActiveBonds;
    }

    /// @notice Get `i_beneficiary`
    /// @return beneficiary The beneficiary address.
    function getBeneficiary() external view returns (address beneficiary) {
        beneficiary = i_beneficiary;
    }

    /// @notice Get `i_bondPrice`
    /// @return bondPrice The current ETH price of a bond, denominated in Wei.
    function getBondPrice() external view returns (uint256 bondPrice) {
        bondPrice = i_bondPrice;
    }

    /// @notice Get `i_shouldBurnBonds`
    /// @return shouldBurnBonds Whether or not bonds should be burned when rejected.
    function getShouldBurnBonds() external view returns (uint8 shouldBurnBonds) {
        shouldBurnBonds = i_shouldBurnBonds;
    }
}
