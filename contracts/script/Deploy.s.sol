// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "forge-std/Script.sol";
import "../src/ArcToken.sol";
import "../src/ProjectPool.sol";
import "../src/Marketplace.sol";
import "../src/Reserve.sol";

contract DeployScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        address usdc = vm.envAddress("USDC_ADDRESS");
        address treasury = vm.envOr("TREASURY_ADDRESS", deployer);

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ARC Token
        ArcToken arcToken = new ArcToken(deployer);
        console.log("ArcToken deployed at:", address(arcToken));

        // Deploy Project Pool
        ProjectPool projectPool = new ProjectPool(deployer, "https://api.arcexchange.io/metadata/");
        console.log("ProjectPool deployed at:", address(projectPool));

        // Deploy Marketplace with 2% platform fee
        Marketplace marketplace = new Marketplace(
            address(projectPool),
            usdc,
            treasury,
            deployer,
            200 // 2% platform fee in basis points
        );
        console.log("Marketplace deployed at:", address(marketplace));

        // Grant minter role to marketplace
        projectPool.grantRole(projectPool.MINTER_ROLE(), address(marketplace));
        console.log("Granted MINTER_ROLE to Marketplace");

        // Deploy Reserve
        Reserve reserve = new Reserve(
            address(projectPool),
            usdc,
            deployer
        );
        console.log("Reserve deployed at:", address(reserve));

        vm.stopBroadcast();

        // Log summary
        console.log("\n=== Deployment Summary ===");
        console.log("Deployer:", deployer);
        console.log("ArcToken:", address(arcToken));
        console.log("ProjectPool:", address(projectPool));
        console.log("Marketplace:", address(marketplace));
        console.log("Reserve:", address(reserve));
        console.log("USDC:", usdc);
        console.log("Treasury:", treasury);
    }
}
