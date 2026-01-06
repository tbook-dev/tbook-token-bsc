// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenImpl} from "../src/TBookToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxy is Script {
    function run() public returns (address proxy, address implementation) {
        // 支持两种方式：
        // 1. 环境变量: export PRIVATE_KEY=0x...
        // 2. 命令行: --private-key 0x...
        address deployer = msg.sender;

        vm.startBroadcast();

        // 1. 部署实现合约
        TokenImpl tokenImpl = new TokenImpl();
        console.log("Implementation deployed at:", address(tokenImpl));

        // 2. 编码初始化调用数据
        bytes memory initData = abi.encodeWithSelector(
            TokenImpl.initialize.selector,
            "TBook Token", "BOOK"
        );

        // 3. 部署 ERC1967Proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(tokenImpl),
            initData
        );
        console.log("Proxy deployed at:", address(proxyContract));

        vm.stopBroadcast();

        return (address(proxyContract), address(tokenImpl));
    }
}
