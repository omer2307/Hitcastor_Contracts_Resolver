// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {Resolver} from "../src/Resolver.sol";

/**
 * @title Deploy Script
 * @notice Deploys the Resolver contract
 */
contract Deploy is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        console.log("Deploying contracts with account:", vm.addr(deployerPrivateKey));
        console.log("Account balance:", vm.addr(deployerPrivateKey).balance);
        
        // Deploy Resolver with factory address and 1-day dispute window
        address factoryAddress = 0x23057BF06D395e8f3Af646216a095F1788DE78A9; // MarketFactory on BSC Testnet
        uint256 disputeWindow = 24 * 60 * 60; // 1 day in seconds
        Resolver resolver = new Resolver(factoryAddress, disputeWindow);
        
        console.log("Resolver deployed at:", address(resolver));
        
        vm.stopBroadcast();
        
        console.log("");
        console.log("=== DEPLOYMENT SUMMARY ===");
        console.log("Resolver:", address(resolver));
        console.log("Owner:", resolver.owner());
        
        console.log("");
        console.log("=== NEXT STEPS ===");
        console.log("1. Set factory address: resolver.setFactory(factoryAddress)");
        console.log("2. Configure resolver in factory: factory.setResolver(resolverAddress)");
    }
}