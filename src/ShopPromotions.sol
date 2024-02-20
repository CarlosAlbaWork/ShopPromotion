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
    uint256 private numberOfPromotions = 1;
    mapping(uint256 index => Promotion) s_promotions;
    mapping(bytes32 names => int index) s_namesToIndex;

    event PromotionAdded(
        bytes32 indexed promotionName,
        uint256 indexed promotionIndex
    );
    event PromotionDeleted(
        bytes32 indexed promotionName,
        uint256 indexed promotionIndex
    );
    event CustomerRemoved(
        address indexed customer,
        uint256 indexed promotionIndex
    );
    event PromotionAppliedToCustomer(
        address indexed customer,
        uint256 indexed promotionIndex,
        int256 indexed totalTimesApplied
    );

    /**
     * @dev customerAddresses helps in checking if customer has ever been in a promotion
     */

    struct Promotion {
        bytes32 nameOfPromotion;
        bytes32 descriptionOfPromotion;
        uint256 expiringDate;
        uint256 numberOfMaxCustomers;
        uint256 numberOfCurrentCustomers;
        int256 numberOfMaxPromotionUses;
        address[] customerAddresses;
        mapping(address customerAddress => int256 timesUsedPromotion) customerMapping;
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
        if (s_promotions[_promotionIndex].nameOfPromotion == 0x00) {
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
            promotion.customerMapping[_customer] <= 0 &&
            promotion.numberOfCurrentCustomers == promotion.numberOfMaxCustomers
        ) {
            revert ShopPromotion_MaxCustomersInPromotion();
        }
        if (
            promotion.customerMapping[_customer] ==
            promotion.numberOfMaxPromotionUses
        ) {
            revert ShopPromotion_CustomerMaxPromotionUsage();
        }
        //If the customer has never been in the promotion
        if (promotion.customerMapping[_customer] <= 0) {
            unchecked {
                promotion.numberOfCurrentCustomers++;
            }

            if (promotion.customerMapping[_customer] == 0) {
                promotion.customerAddresses.push(_customer);
            } else {
                s_promotions[_promotionIndex].customerMapping[_customer] = 0;
            }
        }

        unchecked {
            s_promotions[_promotionIndex].customerMapping[_customer]++;
        }

        emit PromotionAppliedToCustomer(
            _customer,
            _promotionIndex,
            s_promotions[_promotionIndex].customerMapping[_customer]
        );
    }

    /**
     * @notice This function deletes costumer, checking if the costumer is in the promotion.
     * Then sets the usage number to -1
     * @param _customer is the customer the that will be deleted
     * @param _promotionIndex is the index of the promotion that will be deleted
     */

    function deleteCustomerFromPromotion(
        address _customer,
        uint256 _promotionIndex
    ) external onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        if (!existsCustomerInPromotion(_customer, _promotionIndex)) {
            revert ShopPromotion_CustomerNotInPromotion();
        }
        s_promotions[_promotionIndex].customerMapping[_customer] = -1;
        s_promotions[_promotionIndex].numberOfCurrentCustomers--;
        emit CustomerRemoved(_customer, _promotionIndex);
    }

    /**
     * @notice This function deletes a promotion, checking if the promotion exists.
     * Then puts to 0x00 as promotion name, eliminates it from the array of promotions
     * @param _promotionIndex is the index of the promotion wanted to be applied
     */

    function deletePromotion(
        uint256 _promotionIndex
    ) external onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        bytes32 nameOfDeletedPromotion = s_promotions[_promotionIndex]
            .nameOfPromotion;
        s_promotions[_promotionIndex].nameOfPromotion = 0x00;
        s_namesToIndex[nameOfDeletedPromotion] = -1;
        emit PromotionDeleted(nameOfDeletedPromotion, _promotionIndex);
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
        if (s_promotions[_promotionIndex].customerMapping[_customer] <= 0) {
            return false;
        }
        return true;
    }

    /**
     * @notice This function adds a promotion.
     */

    function addPromotion(
        bytes32 _promotionName,
        bytes32 _descriptionOfPromotion,
        uint256 _expiringDate,
        uint256 _numberOfMaxCustomers,
        int256 _numberOfMaxPromotionUses
    ) external onlyShopPromotionOwner {
        if (_promotionName == 0x00 || existsPromotion(_promotionName)) {
            revert ShopPromotion_PromotionExistent();
        }
        uint256 idx = numberOfPromotions;
        Promotion storage promotion = s_promotions[idx];
        promotion.nameOfPromotion = _promotionName;
        promotion.descriptionOfPromotion = _descriptionOfPromotion;
        promotion.expiringDate = _expiringDate;
        promotion.numberOfMaxCustomers = _numberOfMaxCustomers;
        promotion.numberOfMaxPromotionUses = _numberOfMaxPromotionUses;
        s_namesToIndex[_promotionName] = int256(idx);

        unchecked {
            numberOfPromotions++;
        }

        emit PromotionAdded(_promotionName, idx);
    }

    function getOwner() external view returns (address) {
        return i_owner;
    }

    /**
     * @notice This function checks if the promotion exists.
     * @param _promotionName is the name of the promotion wanted to be applied
     */

    function existsPromotion(
        bytes32 _promotionName
    ) public view returns (bool) {
        int256 index = s_namesToIndex[_promotionName];
        if (index > 0) {
            return true;
        }
        return false;
    }

    /**
     * @notice This function gets promotion's index if exists.
     * @param _name is the name of the promotion wanted to be applied
     */

    function getPromotionIndex(bytes32 _name) external view returns (uint256) {
        int256 index = s_namesToIndex[_name];
        if (s_namesToIndex[_name] > 0) {
            return uint256(index);
        }
        return 0;
    }

    function getNumberOfPromotions() external view returns (uint256) {
        return numberOfPromotions - 1;
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
        return s_promotions[_promotionIndex].numberOfCurrentCustomers;
    }

    function getNumberOfMaxCustomersFromPromotion(
        uint256 _promotionIndex
    ) external view returns (uint256) {
        return s_promotions[_promotionIndex].numberOfMaxCustomers;
    }

    function getNumberOfMaxPromotionUsesFromPromotion(
        uint256 _promotionIndex
    ) external view returns (int256) {
        return s_promotions[_promotionIndex].numberOfMaxPromotionUses;
    }

    function getCustomersFromPromotion(
        uint256 _promotionIndex
    ) external view returns (address[] memory) {
        //Can return past users deleted! Use "existsCustomerInPromotion" to check!
        return s_promotions[_promotionIndex].customerAddresses;
    }

    function getCustomerTimesUsedPromotion(
        uint256 _promotionIndex,
        address _customer
    ) external view returns (int256) {
        return s_promotions[_promotionIndex].customerMapping[_customer];
    }
}
