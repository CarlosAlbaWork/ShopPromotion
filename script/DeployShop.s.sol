// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import {Script, console2} from "forge-std/Script.sol";
import {ShopPromotion} from "../src/ShopPromotions.sol";

contract DeployPromotionShop is Script {
    function run() public returns (ShopPromotion) {
        vm.startBroadcast();
        ShopPromotion shopPromotion = new ShopPromotion();
        vm.stopBroadcast();
        return shopPromotion;
    }
}
