// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {console} from "forge-std/console.sol";

/**
 * @title StorageSlotCalculator
 * @dev Utility contract to calculate and verify ERC7201 storage slots
 */
contract StorageSlotCalculator {
    /**
     * @dev Calculate the ERC7201 storage slot for a given identifier
     * @param identifier The storage identifier string
     * @return slot The calculated storage slot address
     */
    function calculateStorageSlot(string memory identifier) public pure returns (bytes32) {
        return keccak256(abi.encode(uint256(keccak256(abi.encode(identifier))) - 1)) & ~bytes32(uint256(0xff));
    }
    
    /**
     * @dev Calculate and log the storage slot for TokenImpl
     */
    function logTokenImplStorageSlot() public pure {
        bytes32 slot = calculateStorageSlot("TBook.BOOK.storage.TokenImpl");
        console.log("TokenImpl storage slot:");
        console.logBytes32(slot);
        console.log("Expected slot: 0xad8cb16239e9315845e8f3f0a5d4ff136eccb77eb6bc1811c5d92810f2d47d00");
    }
}