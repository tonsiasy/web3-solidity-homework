// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Script, console2} from "forge-std/Script.sol";
import {BeggingContract} from "./BeggingContract.sol";

contract DeployBegging is Script {
    function run() external returns (BeggingContract) {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(deployerPrivateKey);
        BeggingContract begging = new BeggingContract();
        vm.stopBroadcast();

        console2.log("BeggingContract deployed at:", address(begging));
        console2.log("Owner address:", begging.owner());
        return begging;
    }
}
