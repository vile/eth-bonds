// SPDX-License-Identifier: MIT
pragma solidity 0.8.25;

import {Test} from "forge-std/Test.sol";
import {Ownable} from "@solady/auth/Ownable.sol";

import {Bond} from "../src/Bond.sol";

import {BadRecipient} from "./mocks/BadRecipient.sol";
import {BadWallet} from "./mocks/BadWallet.sol";

contract BondTest is Test {
    address private ZERO_ADDRESS = address(0);
    address private OWNER = makeAddr("owner");
    address private BENEFICIARY = makeAddr("beneficiary");
    address private USER_ONE = makeAddr("userOne");
    address private USER_TWO = makeAddr("userTwo");
    uint256 private constant BOND_PRICE = 0.5 ether;
    uint8 private constant SHOULD_BURN_BONDS_TRUE = 1;
    uint8 private constant SHOULD_BURN_BONDS_FALSE = 2;

    Bond public bond;

    /*
     * ----------- Modifiers -----------
     */

    /// @dev Not used in deployment tests.
    /// @notice Deploy a Bond contract.
    /// @param shouldBurnBonds Whether or not bonds should be burned when rejected.
    modifier deployBond(bool shouldBurnBonds) {
        uint8 burnBonds;
        shouldBurnBonds ? burnBonds = SHOULD_BURN_BONDS_TRUE : burnBonds = SHOULD_BURN_BONDS_FALSE;
        vm.prank(OWNER);
        bond = new Bond(BENEFICIARY, BOND_PRICE, burnBonds);
        _;
    }

    /// @notice Prank and purchase a single bond.
    /// @param user The user to purchase a bond.
    modifier purchaseBond(address user) {
        vm.deal(user, BOND_PRICE);
        vm.prank(user);
        bond.buyBond{value: BOND_PRICE}();
        _;
    }

    /// @notice Prank and purchase bonds as two seperate users.
    /// @param userOne The first user to purchase a bond.
    /// @param userTwo The second user to purchase a bond.
    modifier purchaseBondMultiple(address userOne, address userTwo) {
        vm.deal(userOne, BOND_PRICE);
        vm.deal(userTwo, BOND_PRICE);
        vm.prank(userOne);
        bond.buyBond{value: BOND_PRICE}();
        vm.prank(userTwo);
        bond.buyBond{value: BOND_PRICE}();
        _;
    }

    /*
     * ----------- Setup -----------
     */

    function setUp() public {}

    /*
     * ----------- Deployment Tests -----------
     */

    /// @dev Assert not able to deploy with `_beneficiary` as the zero address.
    function test_deployWithBeneficiaryZero() public {
        vm.expectRevert(Bond.Bond__ZeroAddress.selector);
        bond = new Bond(ZERO_ADDRESS, BOND_PRICE, SHOULD_BURN_BONDS_TRUE);
    }

    /// @dev Assert not able to deploy with `_bondPrice` as 0.
    function test_deployWithZeroBondPrice() public {
        uint256 zeroBondPrice = 0 ether;
        vm.expectRevert(Bond.Bond__InvalidBondPrice.selector);
        bond = new Bond(OWNER, zeroBondPrice, SHOULD_BURN_BONDS_TRUE);
    }

    /// @dev [Fuzz]
    /// @dev Assert not able to deploy with a `_shouldBurnBonds` number other than 1 or 2 (true or false).
    function test_deployWithBadBurnsNumber(uint8 shouldBurnBonds) public {
        vm.assume(shouldBurnBonds != SHOULD_BURN_BONDS_TRUE);
        vm.assume(shouldBurnBonds != SHOULD_BURN_BONDS_FALSE);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__IncorrectBurnBondsNumber.selector, shouldBurnBonds));
        bond = new Bond(OWNER, BOND_PRICE, shouldBurnBonds);
    }

    /// @dev Assert the contract owner is set to the deployer.
    function test_deployerIsOwner() public {
        vm.expectEmit(true, true, false, true);
        emit Ownable.OwnershipTransferred(address(0), address(this));
        bond = new Bond(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS_TRUE);

        assertEq(address(this), bond.owner());
    }

    /// @dev Assert all immutables are set after deployment.
    function test_deployAllImmutablesSet() public {
        bond = new Bond(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS_TRUE);

        assertEq(BENEFICIARY, bond.getBeneficiary());
        assertEq(BOND_PRICE, bond.getBondPrice());
        assertEq(SHOULD_BURN_BONDS_TRUE, bond.getShouldBurnBonds());
    }

    /// @dev Assert deployment event is emitted.
    function test_deployEventEmitted() public {
        vm.expectEmit(true, true, true, true);
        emit Bond.BondInitialized(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS_TRUE);
        bond = new Bond(BENEFICIARY, BOND_PRICE, SHOULD_BURN_BONDS_TRUE);
    }

    /*
     * ----------- buyBond Tests -----------
     */

    /// @dev Assert a user can buy a bond.
    function test_userCanPurchaseBond() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);

        vm.startPrank(USER_ONE);
        uint256 activeBondsBefore = bond.getNumActiveBonds();
        bond.buyBond{value: BOND_PRICE}();
        uint256 activeBondsAfter = bond.getNumActiveBonds();
        vm.stopPrank();

        assertTrue(bond.userHasBond(address(USER_ONE)));
        assertEq(activeBondsAfter, activeBondsBefore + 1);
        assertEq(address(bond).balance, BOND_PRICE);
    }

    /// @dev Assert bond purchase event is emitted.
    function test_userBondPurchaseEventEmitted() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.expectEmit(true, false, false, false);
        emit Bond.BondBought(address(USER_ONE));

        vm.startPrank(USER_ONE);
        bond.buyBond{value: BOND_PRICE}();
        vm.stopPrank();
    }

    /// @dev Expect revert purchasing bond with wrong amount of ETH.
    function test_userCantPurchaseBondWithWrongAmount() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.prank(USER_ONE);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__IncorrectAmountOfETH.selector, BOND_PRICE, 0));
        bond.buyBond{value: 0 ether}();
    }

    /// @dev Expect revert purchasing a bond when user already has a bond.
    function test_userCantPurchaseMultipleBonds() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE * 2);
        vm.startPrank(USER_ONE);
        bond.buyBond{value: BOND_PRICE}();
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__UserAlreadyHasBond.selector, address(USER_ONE)));
        bond.buyBond{value: BOND_PRICE}();
        vm.stopPrank();
    }

    /// @dev Assert that a bond can be bought on behalf of another user.
    function test_userCanPurchaseBondOnBehalfOf() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.prank(USER_ONE);
        bond.buyBondOnBehalfOf{value: BOND_PRICE}(USER_TWO);

        assertTrue(bond.userHasBond(USER_TWO));
        assertEq(address(bond).balance, BOND_PRICE);
        assertEq(address(USER_ONE).balance, 0 ether);
        assertEq(address(USER_TWO).balance, 0 ether);
    }

    /// @dev Expect revert purchasing bond on behalf of with wrong amount of ETH.
    function test_userCantPurchaseBondOnBehalfOfWithWrongAmount() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.prank(USER_ONE);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__IncorrectAmountOfETH.selector, BOND_PRICE, 0));
        bond.buyBondOnBehalfOf{value: 0 ether}(USER_TWO);
    }

    /// @dev Expect revert purchasing bond on behalf of with wrong amount of ETH.
    function test_userCantPurchaseMultipleBondsOnBehalfOf() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE * 2);
        vm.startPrank(USER_ONE);
        bond.buyBondOnBehalfOf{value: BOND_PRICE}(USER_TWO);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__UserAlreadyHasBond.selector, address(USER_TWO)));
        bond.buyBondOnBehalfOf{value: BOND_PRICE}(USER_TWO);
        vm.stopPrank();
    }

    /*
     * ----------- acceptBond (onlyOwner) Tests -----------
     */

    /// @dev Assert that a bond can be accepted, Ether is returned to the bond purchaser, and state is updated.
    function test_ownerCanAcceptBond() public deployBond(true) purchaseBond(USER_ONE) {
        vm.startPrank(OWNER);
        uint256 activeBondsBefore = bond.getNumActiveBonds();
        bond.acceptBond(USER_ONE);
        uint256 activeBondsAfter = bond.getNumActiveBonds();
        vm.stopPrank();

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(USER_ONE).balance, BOND_PRICE);
        assertEq(activeBondsBefore, activeBondsAfter + 1);
        assertFalse(bond.userHasBond(USER_ONE));
    }

    /// @dev Expect revert when attempting to accept a bond for a user that does not have a bond.
    function test_ownerAcceptRevertsWhenNoBond() public deployBond(true) {
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__UserDoesNotHaveBond.selector, USER_ONE));
        bond.acceptBond(USER_ONE);
    }

    /// @dev Assert bond accepted event is emitted.
    function test_ownerAcceptBondEmitsEvent() public deployBond(true) purchaseBond(USER_ONE) {
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit Bond.BondAccepted(USER_ONE);
        bond.acceptBond(USER_ONE);
    }

    /// @dev Assert that a batch of bonds can be accepted, and that ETH is returned to bond purchasers.
    function test_ownerCanAcceptBatch() public deployBond(true) purchaseBondMultiple(USER_ONE, USER_TWO) {
        assertEq(address(bond).balance, BOND_PRICE * 2);
        assertEq(address(USER_ONE).balance, 0 ether);
        assertEq(address(USER_TWO).balance, 0 ether);

        address[] memory users = new address[](2);
        users[0] = USER_ONE;
        users[1] = USER_TWO;
        vm.prank(OWNER);
        bond.acceptBondBatch(users);

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(USER_ONE).balance, BOND_PRICE);
        assertEq(address(USER_TWO).balance, BOND_PRICE);
    }

    /// @dev Assert that transfers to "bad" bond purchasers reverts.
    function test_ownerAcceptRevertsWithBadBondOwner() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.startPrank(USER_ONE);
        BadWallet badWallet = new BadWallet(bond);
        badWallet.purchaseBond{value: BOND_PRICE}();
        vm.stopPrank();

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__TransferFailed.selector, address(badWallet)));
        bond.acceptBond(address(badWallet));
    }

    /*
     * ----------- rescueBond (onlyOwner) Tests -----------
     */

    /// @dev Assert that bonds can be rescued.
    function test_ownerCanRescueBond() public deployBond(true) {
        vm.deal(USER_ONE, BOND_PRICE);
        vm.prank(USER_ONE);
        BadWallet badWallet = new BadWallet(bond);

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__UserDoesNotHaveBond.selector, address(badWallet)));
        bond.acceptBond(address(badWallet));

        vm.prank(USER_ONE);
        badWallet.purchaseBond{value: BOND_PRICE}();

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__TransferFailed.selector, address(badWallet)));
        bond.acceptBond(address(badWallet));

        vm.prank(OWNER);
        bond.rescueBond(address(badWallet), USER_ONE);

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(USER_ONE).balance, BOND_PRICE);
    }

    /*
     * ----------- rejectBond (onlyOwner) Tests -----------
     */

    /// @dev Assert that bonds can be rejected, and that ETH is sent to the beneficiary.
    function test_ownerCanRejectBondBeneficiary() public deployBond(false) purchaseBond(USER_ONE) {
        vm.startPrank(OWNER);
        uint256 activeBondsBefore = bond.getNumActiveBonds(); // 1
        bond.rejectBond(USER_ONE);
        uint256 activeBondsAfter = bond.getNumActiveBonds(); // 0
        vm.stopPrank();

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(BENEFICIARY).balance, BOND_PRICE);
        assertEq(activeBondsAfter, activeBondsBefore - 1); //0 == 1 - 1
        assertFalse(bond.userHasBond(USER_ONE));
    }

    /// @dev Expect revert when attempting to reject a bond for a user that does not have a bond.
    function test_ownerRejectRevertsWhenNoBond() public deployBond(false) {
        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__UserDoesNotHaveBond.selector, USER_ONE));
        bond.rejectBond(USER_ONE);
    }

    /// @dev It is expected that the deployer will act properly and deploy with an acceptable `_beneficiary`, however:
    /// @dev Expect revert when attempting to reject a bond and send ETH to a bad beneficiary.
    function test_ownerRejectRevertWhenBadRecipient() public {
        vm.startPrank(OWNER);
        BadRecipient badRecipient = new BadRecipient();
        bond = new Bond(address(badRecipient), BOND_PRICE, SHOULD_BURN_BONDS_FALSE);
        vm.stopPrank();

        vm.deal(USER_ONE, BOND_PRICE);
        vm.prank(USER_ONE);
        bond.buyBond{value: BOND_PRICE}();

        vm.prank(OWNER);
        vm.expectRevert(abi.encodeWithSelector(Bond.Bond__TransferFailed.selector, address(badRecipient)));
        bond.rejectBond(USER_ONE);
    }

    /// @dev Assert bond rejected event is emitted.
    function test_ownerRejectBondEmitsEvent() public deployBond(false) purchaseBond(USER_ONE) {
        vm.prank(OWNER);
        vm.expectEmit(true, false, false, true);
        emit Bond.BondRejected(USER_ONE);
        bond.rejectBond(USER_ONE);
    }

    /// @dev Assert that a batch of bonds can be rejected, and that ETH is sent to the beneficiary.
    function test_ownerCanRejectBatchBeneficiary() public deployBond(false) purchaseBondMultiple(USER_ONE, USER_TWO) {
        assertEq(address(bond).balance, BOND_PRICE * 2);
        assertEq(address(USER_ONE).balance, 0 ether);
        assertEq(address(USER_TWO).balance, 0 ether);

        address[] memory users = new address[](2);
        users[0] = USER_ONE;
        users[1] = USER_TWO;
        vm.prank(OWNER);
        bond.rejectBondBatch(users);

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(BENEFICIARY).balance, BOND_PRICE * 2);
        assertFalse(bond.userHasBond(USER_ONE));
        assertFalse(bond.userHasBond(USER_TWO));
    }

    /// @dev Assert that bonds can be rejected, and that ETH is burned.
    function test_ownerCanRejectBondAreBurned() public deployBond(true) purchaseBond(USER_ONE) {
        vm.startPrank(OWNER);
        uint256 activeBondsBefore = bond.getNumActiveBonds(); // 1
        bond.rejectBond(USER_ONE);
        uint256 activeBondsAfter = bond.getNumActiveBonds(); // 0
        vm.stopPrank();

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(ZERO_ADDRESS).balance, BOND_PRICE);
        assertEq(activeBondsAfter, activeBondsBefore - 1); // 0 == 1 - 1
        assertFalse(bond.userHasBond(USER_ONE));
    }

    /// @dev Assert that a batch of bonds can be rejected, and that ETH is burned.
    function test_ownerCanRejectBatchBeneficiaryAreBurned()
        public
        deployBond(true)
        purchaseBondMultiple(USER_ONE, USER_TWO)
    {
        assertEq(address(bond).balance, BOND_PRICE * 2);
        assertEq(address(USER_ONE).balance, 0 ether);
        assertEq(address(USER_TWO).balance, 0 ether);

        address[] memory users = new address[](2);
        users[0] = USER_ONE;
        users[1] = USER_TWO;
        vm.prank(OWNER);
        bond.rejectBondBatch(users);

        assertEq(address(bond).balance, 0 ether);
        assertEq(address(BENEFICIARY).balance, 0 ether);
        assertEq(address(ZERO_ADDRESS).balance, BOND_PRICE * 2);
        assertFalse(bond.userHasBond(USER_ONE));
        assertFalse(bond.userHasBond(USER_TWO));
    }
}
