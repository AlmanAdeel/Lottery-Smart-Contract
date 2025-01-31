// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "src/Raffle.sol";
//note to myself the thing written in {} brackets is name of contract not file
import {helperConfig} from "script/HelperConfig.s.sol";
import {CreateSubscription,FundSubscription,AddConsumer} from "script/interaction.s.sol";

contract Deploy is Script{
    function run() public {
        deployContract();
    }




    function deployContract() public returns(Raffle,helperConfig){
        helperConfig HELPERconfig = new helperConfig();
        helperConfig.NetworkConfig memory config = HELPERconfig.getConfig();

        if (config.subscriptionId == 0){
            CreateSubscription subscriptioncontract = new CreateSubscription();
            (config.subscriptionId,config.vrfCoordinator) = subscriptioncontract.createSubscription(config.vrfCoordinator,config.account);


        FundSubscription fundSubscription = new FundSubscription();
        //one of these is a function in interaction file
        fundSubscription.fundSubscription(config.vrfCoordinator,config.subscriptionId,config.link,config.account);

        }

        vm.startBroadcast(config.account);
        Raffle raffle = new Raffle(
            config.enterancefee,
            config.interval,
            config.vrfCoordinator,
            config.gaslane,
            config.subscriptionId,
            config.callbackgaslimit
        );
        vm.stopBroadcast();
        // dont need to broadcast bec we already did it in the interaction file in the contract
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle),config.vrfCoordinator,config.subscriptionId,config.account);
        return (raffle, HELPERconfig );

    }

}