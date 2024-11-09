// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {MinimalAccount} from "../src/ethereum/MinimalAccount.sol";
import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployMinimal is Script {
    // MinimalAccount public minimalAccount;
    function run() external {
        // minimalAccount = new deployMinimalAccount();
    }

    function deployMinimalAccount() public returns (MinimalAccount, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        vm.startBroadcast(config.account);
        MinimalAccount minimalAccount = new MinimalAccount(config.entryPoint);
        minimalAccount.transferOwnership(config.account);
        vm.stopBroadcast();
        return (minimalAccount, helperConfig);
    }
}
