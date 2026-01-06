// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {StorageSlotCalculator} from "../test_storage_slot.sol";

/**
 * @title CalculateStorageSlot
 * @dev Script to calculate and verify the ERC7201 storage slot for TokenImpl
 */
contract CalculateStorageSlot is Script {
    function setUp() public {}
    
    function run() public {
        vm.startBroadcast();
        
        StorageSlotCalculator calculator = new StorageSlotCalculator();
        calculator.logTokenImplStorageSlot();
        
        vm.stopBroadcast();
    }
}