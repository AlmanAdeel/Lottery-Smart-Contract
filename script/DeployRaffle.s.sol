// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
import {helperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/interaction.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";

contract Deploy is Script, CodeConstants {
    function run() public returns (Raffle, helperConfig) {
        return deployContract();
    }

    function deployContract() public returns (Raffle, helperConfig) {
        helperConfig HELPERconfig = new helperConfig();
        helperConfig.NetworkConfig memory config = HELPERconfig.getConfig();

        // Handle subscription setup
        if (config.subscriptionId == 0) {
            if (block.chainid == LOCAL_CHAIN_ID) {
                // Local network flow
                vm.startBroadcast(config.account);
                uint256 subId = VRFCoordinatorV2_5Mock(config.vrfCoordinator).createSubscription();
                vm.stopBroadcast();
                config.subscriptionId = subId;

                // FUND LOCAL SUBSCRIPTION
                FundSubscription fundSub = new FundSubscription();
                fundSub.fundSubscription(
                    config.vrfCoordinator,
                    config.subscriptionId,
                    config.link,
                    config.account
                );
            } else {
                // Live network flow
                CreateSubscription subCreator = new CreateSubscription();
                (config.subscriptionId, config.vrfCoordinator) = subCreator.createSubscription(
                    config.vrfCoordinator,
                    config.account
                );

                FundSubscription fundSub = new FundSubscription();
                fundSub.fundSubscription(
                    config.vrfCoordinator,
                    config.subscriptionId,
                    config.link,
                    config.account
                );
            }
        }

        // Deploy Raffle
        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.entranceFee,
            config.interval,
            config.vrfCoordinator,
            config.gaslane,
            config.subscriptionId,
            config.callbackgaslimit
        );
        vm.stopBroadcast();

        // Add consumer
        AddConsumer consumerAdder = new AddConsumer();
        consumerAdder.addConsumer(
            address(raffle),
            config.vrfCoordinator,
            config.subscriptionId,
            config.account
        );

        return (raffle, HELPERconfig);
    }
}