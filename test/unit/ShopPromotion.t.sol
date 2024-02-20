// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Test, console2} from "forge-std/Test.sol";
import {ShopPromotion} from "../../src/ShopPromotions.sol";
import {DeployPromotionShop} from "../../script/DeployShop.s.sol";

contract ShopPromotionTest is Test {
    ShopPromotion public shopPromotion;
    bytes32 constant nameOfPromotion =
        keccak256(abi.encodePacked("Test Of Promotion"));
    bytes32 constant descriptionOfPromotion =
        keccak256(abi.encodePacked("Test Of Promotion Description"));
    uint256 constant expiringDate = 20000;
    uint256 constant numberOfMaxCustomers = 3;
    int256 constant numberOfMaxPromotionUses = 3;

    address constant customer1 = address(1);
    address constant customer2 = address(2);
    address constant customer3 = address(3);
    address constant customer4 = address(4);
    address[] testArrayCustomers;
    bytes32[] testArrayPromotions;
    uint256 indexOfPromotion;

    function setUp() public {
        DeployPromotionShop deployer = new DeployPromotionShop();
        (shopPromotion) = deployer.run();
    }

    modifier promotionCreated() {
        vm.startPrank(shopPromotion.getOwner());
        shopPromotion.addPromotion(
            nameOfPromotion,
            descriptionOfPromotion,
            expiringDate,
            numberOfMaxCustomers,
            numberOfMaxPromotionUses
        );
        indexOfPromotion = shopPromotion.getPromotionIndex(nameOfPromotion);
        console2.log(indexOfPromotion);
        _;
    }

    //Modifier Tests

    function testModifierOnlyOwner() public {
        vm.expectRevert(
            ShopPromotion.ShopPromotion_NotOwnerOfShopPromotion.selector
        );
        shopPromotion.deletePromotion(1);
    }

    function testModifierPromotionCheckedRevertDeleted()
        public
        promotionCreated
    {
        shopPromotion.deletePromotion(1);
        vm.expectRevert(
            ShopPromotion.ShopPromotion_PromotionNonexistent.selector
        );
        shopPromotion.deletePromotion(1);
        vm.stopPrank();
    }

    function testModifierPromotionCheckedRevertNeverExisted()
        public
        promotionCreated
    {
        vm.expectRevert(
            ShopPromotion.ShopPromotion_PromotionNonexistent.selector
        );
        shopPromotion.deletePromotion(2);
        vm.stopPrank();
    }

    function testModifierPromotionCheckedRevertTime() public promotionCreated {
        vm.warp(block.timestamp + expiringDate + 1);
        vm.roll(block.number + 1);
        vm.expectRevert(ShopPromotion.ShopPromotion_PromotionEnded.selector);
        shopPromotion.deletePromotion(1);
        vm.stopPrank();
    }

    //AddPromotion Tests

    function testAddPromotionRevertsIfNoNameGiven() public {
        vm.startPrank(shopPromotion.getOwner());
        vm.expectRevert(ShopPromotion.ShopPromotion_PromotionExistent.selector);
        shopPromotion.addPromotion(
            0x00,
            descriptionOfPromotion,
            expiringDate,
            numberOfMaxCustomers,
            numberOfMaxPromotionUses
        );
        vm.stopPrank();
    }

    function testAddPromotionRevertsIfExistent() public promotionCreated {
        vm.expectRevert(ShopPromotion.ShopPromotion_PromotionExistent.selector);
        shopPromotion.addPromotion(
            nameOfPromotion,
            descriptionOfPromotion,
            expiringDate,
            numberOfMaxCustomers,
            numberOfMaxPromotionUses
        );
        vm.stopPrank();
    }

    function testAddPromotionWorks() public promotionCreated {
        vm.stopPrank();
        assertEq(
            nameOfPromotion,
            shopPromotion.getNameOfPromotion(indexOfPromotion)
        );
        assertEq(
            descriptionOfPromotion,
            shopPromotion.getDescriptionOfPromotion(indexOfPromotion)
        );
        assertEq(
            expiringDate,
            shopPromotion.getExpiringDateFromPromotion(indexOfPromotion)
        );
        assertEq(
            numberOfMaxCustomers,
            shopPromotion.getNumberOfMaxCustomersFromPromotion(indexOfPromotion)
        );
        assertEq(
            numberOfMaxPromotionUses,
            shopPromotion.getNumberOfMaxPromotionUsesFromPromotion(
                indexOfPromotion
            )
        );
        assertEq(
            0,
            shopPromotion.getNumberOfCurrentCustomersFromPromotion(
                indexOfPromotion
            )
        );
    }

    /// Apply Promotion Test

    function testApplyPromotionToCustomerWorks() public promotionCreated {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        vm.stopPrank();
        assertEq(
            shopPromotion.getCustomerTimesUsedPromotion(
                indexOfPromotion,
                customer1
            ),
            1
        );
    }

    function testApplyPromotionToCustomerRevertsIfMaxUses()
        public
        promotionCreated
    {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        vm.expectRevert(
            ShopPromotion.ShopPromotion_CustomerMaxPromotionUsage.selector
        );
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        vm.stopPrank();
    }

    function testApplyPromotionToCustomerRevertsIfMaxPeople()
        public
        promotionCreated
    {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer2, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer3, indexOfPromotion);
        vm.expectRevert(
            ShopPromotion.ShopPromotion_MaxCustomersInPromotion.selector
        );
        shopPromotion.applyPromotionToCustomer(customer4, indexOfPromotion);
        vm.stopPrank();
    }

    //delete customer tests

    function testDeleteCustomerRevertsIfCustomerNonexistent()
        public
        promotionCreated
    {
        vm.expectRevert(
            ShopPromotion.ShopPromotion_CustomerNotInPromotion.selector
        );
        shopPromotion.deleteCustomerFromPromotion(customer1, indexOfPromotion);
        vm.stopPrank();
    }

    function testDeleteCustomerRevertsWorkswithOneCustomer()
        public
        promotionCreated
    {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.deleteCustomerFromPromotion(customer1, indexOfPromotion);
        vm.stopPrank();
    }

    function testDeleteCustomerRevertsWorks() public promotionCreated {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer2, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer3, indexOfPromotion);
        shopPromotion.deleteCustomerFromPromotion(customer1, indexOfPromotion);
        vm.expectRevert(
            ShopPromotion.ShopPromotion_CustomerNotInPromotion.selector
        );
        shopPromotion.deleteCustomerFromPromotion(customer1, indexOfPromotion);
        vm.stopPrank();
    }

    // Delete Promotion tests

    function testDeletePromotionWorks() public promotionCreated {
        shopPromotion.addPromotion(
            keccak256(abi.encodePacked("Test Promotion for Delete test ")),
            keccak256(
                abi.encodePacked("Test Promotion Description for Delete test ")
            ),
            expiringDate,
            numberOfMaxCustomers,
            numberOfMaxPromotionUses
        );

        shopPromotion.deletePromotion(indexOfPromotion);
        vm.stopPrank();
        assertEq(false, shopPromotion.existsPromotion(nameOfPromotion));
    }

    // Not used yet Getters yet
    // getNumberOfPromotions existsCustomerInPromotion

    function testGetCustomersFromPromotion() public promotionCreated {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer2, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer3, indexOfPromotion);
        testArrayCustomers.push(customer1);
        testArrayCustomers.push(customer2);
        testArrayCustomers.push(customer3);
        address[] memory customersPromo = shopPromotion
            .getCustomersFromPromotion(indexOfPromotion);
        vm.stopPrank();
        assertEq(testArrayCustomers.length, customersPromo.length);
        assertEq(testArrayCustomers[0], customersPromo[0]);
        assertEq(testArrayCustomers[1], customersPromo[1]);
        assertEq(testArrayCustomers[2], customersPromo[2]);
    }

    function testGetnumberOfPromotions() public promotionCreated {
        vm.stopPrank();
        assertEq(1, shopPromotion.getNumberOfPromotions());
    }

    function testExistsCustomerInPromotion() public promotionCreated {
        shopPromotion.applyPromotionToCustomer(customer1, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer2, indexOfPromotion);
        shopPromotion.applyPromotionToCustomer(customer3, indexOfPromotion);
        shopPromotion.deleteCustomerFromPromotion(customer1, indexOfPromotion);
        vm.stopPrank();
        assertEq(
            false,
            shopPromotion.existsCustomerInPromotion(customer1, indexOfPromotion)
        );
    }
}
