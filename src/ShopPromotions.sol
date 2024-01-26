// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

//Imports

/**
 * @title Smart Contract that manages promotions for local shops.
 * @author Carlos Alba
 */

contract ShopPromotion {
    //Interfaces, errores , librerías y contratos
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
    //Declaraciones de tipo

    //Variables generales
    address private immutable i_owner; //Wallet address from the Shop owner. The one who manages the contract
    Promotion[] private s_promotions;
    bytes32[] private s_namesOfPromotion;

    struct Promotion {
        bytes32 nameOfPromotion;
        bytes32 descriptionOfPromotion;
        uint256 expiringDate;
        uint256 numberOfMaxCustomers;
        uint256 numberOfMaxPromotionUses;
        address[] customerAddresses; //Only because we might need to get the addresses of customers
        mapping(address customerAddress => uint256 timesUsedPromotion) customerMapping;
    }

    modifier onlyShopPromotionOwner() {
        if (msg.sender != i_owner)
            revert ShopPromotion_NotOwnerOfShopPromotion();
        _;
    }

    modifier promotionChecked(uint256 _promotionindex) {
        if (
            s_promotions.length <= _promotionindex ||
            s_promotions[_promotionindex].nameOfPromotion == 0x00
        ) {
            revert ShopPromotion_PromotionNonexistent();
        }
        if (block.timestamp > s_promotions[_promotionindex].expiringDate) {
            revert ShopPromotion_PromotionEnded();
        }
        _;
    }

    //Se haría desde la app un getcustomerPromotions y se haría el for en la app para checkear la info
    //Se haría desde la app un getSellerPromotions y se haría el for en la app para checkear el índice de la promotion en el array

    function applyPromotionToCustomer(
        address _customer,
        uint256 _promotionindex
    ) public onlyShopPromotionOwner promotionChecked(_promotionindex) {
        Promotion storage promotion = s_promotions[_promotionindex];
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
        s_promotions[_promotionindex].customerMapping[_customer]++;
    }

    //I wanted to make a function that copies the array of customers from one to another
    //But it seems impossible to assign mappings
    /** 
    function copyArraysOfCustomers(
        uint256 _oldPromotionIndex,
        uint256 _newPromotionIndex
    ) public onlyShopPromotionOwner {
        if (
            s_promotions[_newPromotionIndex].numberOfMaxCustomers <
            s_promotions[_oldPromotionIndex].customerAddresses.length
        ) {
            revert ShopPromotion_MaxCustomersInPromotion();
        }
        s_promotions[_newPromotionIndex].customerMapping = s_promotions[
            _oldPromotionIndex
        ].customerMapping;
    }
    */

    function deleteCustomerFromPromotion(
        address _customer,
        uint256 _promotionIndex
    ) public onlyShopPromotionOwner promotionChecked(_promotionIndex) {
        if (!existsCustomerInPromotion(_customer, _promotionIndex)) {
            revert ShopPromotion_CustomerNotInPromotion();
        }
        s_promotions[_promotionIndex].customerMapping[_customer] = 0;
        address[] memory customerSearch = s_promotions[_promotionIndex]
            .customerAddresses;
        uint256 customerSearchLength = customerSearch.length;
        if (customerSearchLength > 1) {
            for (uint i = 0; i < customerSearchLength; i++) {
                if (customerSearch[i] == _customer) {
                    customerSearch[i] = customerSearch[
                        customerSearchLength - 1
                    ];
                }
            }
        }
        delete customerSearch[customerSearchLength - 1];
        s_promotions[_promotionIndex].customerAddresses = customerSearch;
    }

    function deletePromotion(
        uint256 _promotionindex
    ) public onlyShopPromotionOwner promotionChecked(_promotionindex) {
        bytes32[] memory namesOfPromotion = s_namesOfPromotion;
        s_promotions[_promotionindex].nameOfPromotion = 0x00;
        if (namesOfPromotion.length > 1) {
            namesOfPromotion[_promotionindex] = namesOfPromotion[
                namesOfPromotion.length - 1
            ];
        }
        delete namesOfPromotion[namesOfPromotion.length - 1];
        s_namesOfPromotion = namesOfPromotion;
    }

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

    function addPromotion(
        bytes32 _promotionName,
        bytes32 _descriptionOfPromotion,
        uint256 _expiringDate,
        uint256 _numberOfMaxCustomers,
        uint256 _numberOfMaxPromotionUses
    ) public onlyShopPromotionOwner {
        if (_promotionName == 0x00 || existsPromotion(_promotionName)) {
            revert ShopPromotion_PromotionExistent();
        }

        //NOTE: We do this unorthodox way of pushing because of the error:
        //"Storage arrays with nested mappings do not support .push(<arg>)"
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

    function getOwner() public view returns (address) {
        return i_owner;
    }

    function getPromotions() public view returns (bytes32[] memory) {
        return s_namesOfPromotion;
    }

    function getPromotionIndex(bytes32 _name) public view returns (int256) {
        bytes32[] memory namesOfPromotion = s_namesOfPromotion;
        for (uint i = 0; i < namesOfPromotion.length; i++) {
            if (namesOfPromotion[i] == _name) {
                return int256(i);
            }
        }
        return -1;
    }

    function getNumberOfPromotions() public view returns (uint256) {
        return s_namesOfPromotion.length;
    }

    function getNameOfPromotion(
        uint256 _promotionindex
    ) public view returns (bytes32) {
        return s_promotions[_promotionindex].nameOfPromotion;
    }

    function getDescriptionOfPromotion(
        uint256 _promotionindex
    ) public view returns (bytes32) {
        return s_promotions[_promotionindex].descriptionOfPromotion;
    }

    function getExpiringDateFromPromotion(
        uint256 _promotionindex
    ) public view returns (uint256) {
        return s_promotions[_promotionindex].expiringDate;
    }

    function getNumberOfCurrentCustomersFromPromotion(
        uint256 _promotionindex
    ) public view returns (uint256) {
        return s_promotions[_promotionindex].customerAddresses.length;
    }

    function getNumberOfMaxCustomersFromPromotion(
        uint256 _promotionindex
    ) public view returns (uint256) {
        return s_promotions[_promotionindex].numberOfMaxCustomers;
    }

    function getNumberOfMaxPromotionUsesFromPromotion(
        uint256 _promotionindex
    ) public view returns (uint256) {
        return s_promotions[_promotionindex].numberOfMaxPromotionUses;
    }

    function getCustomersFromPromotion(
        uint256 _promotionindex
    ) public view returns (address[] memory) {
        return s_promotions[_promotionindex].customerAddresses;
    }

    function getCustomerTimesUsedPromotion(
        uint256 _promotionindex,
        address _customer
    ) public view returns (uint256) {
        return s_promotions[_promotionindex].customerMapping[_customer];
    }
}
