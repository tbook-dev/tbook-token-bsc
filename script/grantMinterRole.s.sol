// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenImpl} from "../src/TBookToken.sol";

/// @notice 授权 Wormhole NTT Manager 合约 MINTER_ROLE
contract GrantMinterRole is Script {
    function run(address nttManager) public {
        // TBookToken Proxy 地址
        address tokenProxy = 0xeD50CA53711Ce8788CBf922637E1C3e3c9b1C362;
        
        TokenImpl token = TokenImpl(tokenProxy);
        bytes32 minterRole = token.MINTER_ROLE();

        vm.startBroadcast();

        // 授予 NTT Manager MINTER_ROLE
        token.grantRole(minterRole, nttManager);
        console.log("Granted MINTER_ROLE to:", nttManager);

        // 验证
        bool hasMinterRole = token.hasRole(minterRole, nttManager);
        console.log("Has MINTER_ROLE:", hasMinterRole);

        vm.stopBroadcast();
    }
}
