// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenImpl} from "../src/TBookToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract DeployProxyWithDebug is Script {
    function run() public returns (address proxy, address implementation) {
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
        
        console.log("Init data length:", initData.length);
        console.log("Function selector:", vm.toString(abi.encodeWithSelector(TokenImpl.initialize.selector)));

        // 3. 部署 ERC1967Proxy
        ERC1967Proxy proxyContract = new ERC1967Proxy(
            address(tokenImpl),
            initData
        );
        console.log("Proxy deployed at:", address(proxyContract));

        // 4. 验证初始化结果
        console.log("=== INITIALIZATION VERIFICATION ===");
        console.log("Proxy name:", TokenImpl(address(proxyContract)).name());
        console.log("Proxy symbol:", TokenImpl(address(proxyContract)).symbol());
        console.log("Proxy totalSupply:", TokenImpl(address(proxyContract)).totalSupply());
        
        // 检查角色是否正确分配
        console.log("Deployer has DEFAULT_ADMIN_ROLE:", 
            TokenImpl(address(proxyContract)).hasRole(
                TokenImpl(address(proxyContract)).DEFAULT_ADMIN_ROLE(), 
                deployer
            )
        );

        vm.stopBroadcast();

        return (address(proxyContract), address(tokenImpl));
    }
}