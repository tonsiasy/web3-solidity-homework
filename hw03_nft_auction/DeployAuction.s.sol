// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {MyNFT} from "./MyNFT.sol";
import {AuctionMarket} from "./AuctionMarket.sol";

/**
 * @title DeployAuction
 * @dev 部署 MyNFT 及基于 UUPS 代理架构的 AuctionMarket 至 Sepolia 测试网
 */
contract DeployAuction is Script {
    // Sepolia 官方 Chainlink ETH / USD 喂价地址
    address public constant SEPOLIA_CHAINLINK_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;

    function run() external returns (address nftAddr, address proxyAddr, address implAddr) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);

        console2.log("=== Starting HW03 Auction Market Deployment ===");
        console2.log("Deployer Address:", deployer);
        console2.log("Chainlink ETH/USD Feed:", SEPOLIA_CHAINLINK_ETH_USD);

        vm.startBroadcast(deployerPrivateKey);

        // 1. 获取或部署 MyNFT 合约
        address existingNft = vm.envOr("NFT_ADDRESS", address(0));
        if (existingNft != address(0)) {
            nftAddr = existingNft;
            console2.log("1. Reusing existing MyNFT at:", nftAddr);
        } else {
            MyNFT nft = new MyNFT("Web3Lab Auction NFT", "W3ANFT");
            nftAddr = address(nft);
            console2.log("1. MyNFT deployed at:", nftAddr);
        }

        // 2. 部署 AuctionMarket 逻辑实现合约
        AuctionMarket implementation = new AuctionMarket();
        implAddr = address(implementation);
        console2.log("2. AuctionMarket Implementation deployed at:", implAddr);

        // 3. 构造初始化调用的 calldata
        bytes memory initData = abi.encodeCall(AuctionMarket.initialize, (SEPOLIA_CHAINLINK_ETH_USD));

        // 4. 部署 ERC1967 代理合约并指向逻辑合约
        ERC1967Proxy proxy = new ERC1967Proxy(implAddr, initData);
        proxyAddr = address(proxy);
        console2.log("3. AuctionMarket ERC1967Proxy deployed at:", proxyAddr);

        vm.stopBroadcast();

        // 5. 校验部署后代理状态
        AuctionMarket market = AuctionMarket(payable(proxyAddr));
        console2.log("Proxy Owner:", market.owner());
        console2.log("Configured Feed:", address(market.ethUsdPriceFeed()));
        console2.log("=== Deployment Completed Successfully ===");
    }
}
