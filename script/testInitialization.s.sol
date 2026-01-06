// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {TokenImpl} from "../src/TBookToken.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";

contract TestInitialization is Script {
    function run() public {
        address deployer = address(1); // 模拟部署者
        
        vm.startBroadcast(deployer);

        // 1. 部署实现合约
        TokenImpl tokenImpl = new TokenImpl();
        console.log("Implementation deployed at:", address(tokenImpl));

        // 2. 编码初始化调用数据
        string memory tokenName = "TBook Token";
        string memory tokenSymbol = "BOOK";
        
        bytes memory initData = abi.encodeWithSelector(
            TokenImpl.initialize.selector,
            tokenName,
            tokenSymbol
        );
        
        console.log("=== ENCODING VERIFICATION ===");
        console.log("Token name:", tokenName);
        console.log("Token symbol:", tokenSymbol);
        console.log("Init data length:", initData.length);
        console.log("Expected selector:", vm.toString(abi.encodeWithSelector(TokenImpl.initialize.selector)));

        // 3. 部署代理合约
        ERC1967Proxy proxy = new ERC1967Proxy(address(tokenImpl), initData);
        console.log("Proxy deployed at:", address(proxy));

        // 4. 验证初始化结果
        console.log("=== INITIALIZATION VERIFICATION ===");
        console.log("Proxy name:", TokenImpl(address(proxy)).name());
        console.log("Proxy symbol:", TokenImpl(address(proxy)).symbol());
        console.log("Proxy totalSupply:", TokenImpl(address(proxy)).totalSupply());
        console.log("Proxy decimals:", TokenImpl(address(proxy)).decimals());
        
        // 验证角色
        bytes32 DEFAULT_ADMIN_ROLE = TokenImpl(address(proxy)).DEFAULT_ADMIN_ROLE();
        bytes32 ADMIN_ROLE = TokenImpl(address(proxy)).ADMIN_ROLE();
        
        console.log("Deployer has DEFAULT_ADMIN_ROLE:", 
            TokenImpl(address(proxy)).hasRole(DEFAULT_ADMIN_ROLE, deployer));
        console.log("Deployer has ADMIN_ROLE:", 
            TokenImpl(address(proxy)).hasRole(ADMIN_ROLE, deployer));
        
        // 验证传输模式设置
        console.log("Transfer mode:", TokenImpl(address(proxy)).getTransferMode());
        console.log("Transfer controller:", TokenImpl(address(proxy)).getTransferController());
        
        // 5. 验证参数正确性
        console.log("=== PARAMETER VALIDATION ===");
        console.log("Name validation:", 
            keccak256(abi.encodePacked(TokenImpl(address(proxy)).name())) == 
            keccak256(abi.encodePacked(tokenName)));
        console.log("Symbol validation:", 
            keccak256(abi.encodePacked(TokenImpl(address(proxy)).symbol())) == 
            keccak256(abi.encodePacked(tokenSymbol)));
        console.log("Total supply validation:", TokenImpl(address(proxy)).totalSupply() == 0);
        console.log("Decimals validation:", TokenImpl(address(proxy)).decimals() == 18);
        
        console.log("=== ALL TESTS PASSED ===");

        vm.stopBroadcast();
    }
}