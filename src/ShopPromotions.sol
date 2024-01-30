// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

/**
 * @title Smart Contract that manages promotions for local shops.
 * @author Carlos Alba
 * @notice This contract allows to manage promotions. It was intended to serve for local shops
 * to create a bigger link with customers.
 */

contract ShopPromotion {
    error ShopPromotion_NotOwnerOfShopPromotion();
    error ShopPromotion_NotOwnerOfBusiness();
    error ShopPromotion_NotEnoughETH();
    error ShopPromotion_ForbiddenAccess();
    error ShopPromotion_PromotionEnded();
    error ShopPromotion_PromotionNonexistent();
    error ShopPromotion_PromotionExistent();
    error ShopPromotion_MaxCustomersInPromotion();
    error ShopPromotion_CustomerMaxPromotionUsage();
    error ShopPromotion_CustomerNotInPromotion();

    /**
     * @dev i_owner is the address from the Shop owner. The one who manages the promotions
     */
    address private immutable i_owner;
    Promotion[] private s_promotions;
    bytes32[] private s_namesOfPromotion;

    /**
     * @dev customerAddresses helps in checking if customer exists in promotion and
     * the quantity of current customers
     */

    struct Promotion {
        bytes32 nameOfPromotion;
        bytes32 descriptionOfPromotion;
        uint256 expiringDate;
        uint256 numberOfMaxCustomers;
        uint256 numberOfMaxPromotionUses;
        address[] customerAddresses;
        mapping(address customerAddress => uint256 timesUsedPromotion) customerMapping;
    }

    constructor() {
        i_owner = msg.sender;
    }

    /**
     * @notice This modifier allows only the contract owner (shop owner) to access some
     * functionality
     */
    modifier onlyShopPromotionOwner() {
        if (msg.sender != i_owner) {
            revert ShopPromotion_NotOwnerOfShopPromotion();
        }
        _;
    }

    /**
     * @notice This modifier checks if the promotion exists or is expired
     * @param _promotionIndex is the index of the promotion wanted to be checked
     */

    modifier promotionChecked(uint256 _promotionIndex) {
        if (
            s_promotions.length <= _promotionIndex ||
            s_promotions[_promotionIndex].nameOfPromotion == 0x00
        ) {
            revert ShopPromotion_PromotionNonexistent();
        }
        if (block.timestamp > s_promotions[_promotionIndex].expiringDate) {
            revert ShopPromotion_PromotionEnded();
        }
        _;
    }

    /**
     * @notice This function applies a promotion to costumer, checking if the costumer is new and max Customers are reached
     * or costumer has reached the max amount of Promotion usage. If both are false, checks if the costumer is new and adds him
     * to customer list and adds 1 usage to its mapping
     * @param _customer is the customer the promotion will be applied to
     * @param _promotionIndex is the index of the promotion wanted to be applied
     */

    function applyPromotionToCustomer(
        address _customer,
        uint256 _promotionIndex
    ) external onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        Promotion storage promotion = s_promotions[_promotionIndex];
        if (
            promotion.customerMapping[_customer] == 0 &&
            promotion.customerAddresses.length == promotion.numberOfMaxCustomers
        ) {
            revert ShopPromotion_MaxCustomersInPromotion();
        }
        if (
            promotion.customerMapping[_customer] ==
            promotion.numberOfMaxPromotionUses
        ) {
            revert ShopPromotion_CustomerMaxPromotionUsage();
        }
        if (promotion.customerMapping[_customer] == 0) {
            promotion.customerAddresses.push(_customer);
        }
        s_promotions[_promotionIndex].customerMapping[_customer]++;
    }

    /**
     * @notice This function deletes costumer, checking if the costumer is in the promotion.
     * Then puts to 0 promotion usage, eliminates it from the array of customers
     * @param _customer is the customer the promotion will be applied to
     * @param _promotionIndex is the index of the promotion wanted to be applied
     */

    function deleteCustomerFromPromotion(
        address _customer,
        uint256 _promotionIndex
    ) external onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        if (!existsCustomerInPromotion(_customer, _promotionIndex)) {
            revert ShopPromotion_CustomerNotInPromotion();
        }
        s_promotions[_promotionIndex].customerMapping[_customer] = 0;
        address[] memory customerSearch = s_promotions[_promotionIndex]
            .customerAddresses;
        if (customerSearch.length > 1) {
            for (uint i = 0; i < customerSearch.length; i++) {
                if (customerSearch[i] == _customer) {
                    customerSearch[i] = customerSearch[
                        customerSearch.length - 1
                    ];
                }
            }
        }
        delete customerSearch[customerSearch.length - 1];
        s_promotions[_promotionIndex].customerAddresses = customerSearch;
    }

    /**
     * @notice This function deletes a promotion, checking if the promotion exists.
     * Then puts to 0x00 as promotion name, eliminates it from the array of promotions
     * @param _promotionIndex is the index of the promotion wanted to be applied
     */

    function deletePromotion(
        uint256 _promotionIndex
    ) external onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        bytes32[] memory namesOfPromotion = s_namesOfPromotion;
        s_promotions[_promotionIndex].nameOfPromotion = 0x00;
        if (namesOfPromotion.length > 1) {
            namesOfPromotion[_promotionIndex] = namesOfPromotion[
                namesOfPromotion.length - 1
            ];
        }
        delete namesOfPromotion[namesOfPromotion.length - 1];
        s_namesOfPromotion = namesOfPromotion;
    }

    /**
     * @notice This function checks if the promotion exists.
     * @param _promotionName is the name of the promotion wanted to be applied
     */

    function existsPromotion(
        bytes32 _promotionName
    ) public view returns (bool) {
        bytes32[] memory namesOfPromotion = s_namesOfPromotion;
        for (uint i = 0; i < namesOfPromotion.length; i++) {
            if (namesOfPromotion[i] == _promotionName) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice This function checks if the costumer is in the promotion.
     * Returns true if exists and false if it doesn't
     * @param _customer is the customer the promotion will be applied to
     * @param _promotionIndex is the index of the promotion wanted to be applied
     */

    function existsCustomerInPromotion(
        address _customer,
        uint256 _promotionIndex
    ) public view returns (bool) {
        address[] memory namesOfCustomers = s_promotions[_promotionIndex]
            .customerAddresses;
        for (uint i = 0; i < namesOfCustomers.length; i++) {
            if (namesOfCustomers[i] == _customer) {
                return true;
            }
        }
        return false;
    }

    /**
     * @notice This function adds a promotion.
     */

    function addPromotion(
        bytes32 _promotionName,
        bytes32 _descriptionOfPromotion,
        uint256 _expiringDate,
        uint256 _numberOfMaxCustomers,
        uint256 _numberOfMaxPromotionUses
    ) external onlyShopPromotionOwner {
        if (_promotionName == 0x00 || existsPromotion(_promotionName)) {
            revert ShopPromotion_PromotionExistent();
        }
        uint256 idx = s_promotions.length;
        s_promotions.push();
        Promotion storage promotion = s_promotions[idx];
        promotion.nameOfPromotion = _promotionName;
        promotion.descriptionOfPromotion = _descriptionOfPromotion;
        promotion.expiringDate = _expiringDate;
        promotion.numberOfMaxCustomers = _numberOfMaxCustomers;
        promotion.numberOfMaxPromotionUses = _numberOfMaxPromotionUses;
        s_namesOfPromotion.push(_promotionName);
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    function getPromotions() external view returns (bytes32[] memory) {
        return s_namesOfPromotion;
    }

    /**
     * @notice This function gets promotion's index if exists.
     * @param _name is the name of the promotion wanted to be applied
     */

    function getPromotionIndex(bytes32 _name) external view returns (int256) {
        if (existsPromotion(_name)) {
            bytes32[] memory namesOfPromotion = s_namesOfPromotion;
            for (uint i = 0; i < namesOfPromotion.length; i++) {
                if (namesOfPromotion[i] == _name) {
                    return int256(i);
                }
            }
        }
        return -1;
    }

    function getNumberOfPromotions() external view returns (uint256) {
        return s_namesOfPromotion.length;
    }

    function getNameOfPromotion(
        uint256 _promotionIndex
    ) external view returns (bytes32) {
        return s_promotions[_promotionIndex].nameOfPromotion;
    }

    function getDescriptionOfPromotion(
        uint256 _promotionIndex
    ) external view returns (bytes32) {
        return s_promotions[_promotionIndex].descriptionOfPromotion;
    }

    function getExpiringDateFromPromotion(
        uint256 _promotionIndex
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].expiringDate;
    }

    function getNumberOfCurrentCustomersFromPromotion(
        uint256 _promotionIndex
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].customerAddresses.length;
    }

    function getNumberOfMaxCustomersFromPromotion(
        uint256 _promotionIndex
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].numberOfMaxCustomers;
    }

    function getNumberOfMaxPromotionUsesFromPromotion(
        uint256 _promotionIndex
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].numberOfMaxPromotionUses;
    }

    function getCustomersFromPromotion(
        uint256 _promotionIndex
    ) external view returns (address[] memory) {
        return s_promotions[_promotionIndex].customerAddresses;
    }

    function getCustomerTimesUsedPromotion(
        uint256 _promotionIndex,
        address _customer
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].customerMapping[_customer];
    }
}
