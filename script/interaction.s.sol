// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script,console} from "forge-std/Script.sol";
import {helperConfig,CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/linktoken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script{

    function createSubscriptionUsingConfig() public returns(uint256,address) {
        helperConfig HelperConfig = new helperConfig();
        address vrfCoordinator = HelperConfig.getConfig().vrfCoordinator;
        address account = HelperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator,account);
        return(subId,vrfCoordinator);


    }


    function createSubscription(address vrfCoordinator,address account) public returns(uint256,address) {
      //  console.log("creating subscription on chainid", block.chainid);
        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
       // console.log("your subscription id: ", subId);
        //console.log("please update the subscription id in your helperConfig.s.sol");
        return(subId,vrfCoordinator);


    }


    function run() public{
        createSubscriptionUsingConfig();
    }


}

contract FundSubscription is Script,CodeConstants{
    uint256 public constant FUND_AMOUNT = 3 ether; // 3 LINK
    function fundSubscriptionUsingConfig() public {
        helperConfig HelperConfig = new helperConfig();
        address vrfCoordinator = HelperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionid = HelperConfig.getConfig().subscriptionId;
        address linkToken = HelperConfig.getConfig().link;
        address account = HelperConfig.getConfig().account;
        fundSubscription(vrfCoordinator,subscriptionid,linkToken,account);
    }

    function fundSubscription(address vrfCoordinator,uint256 subid,address link,address account) public {
        console.log("Funding subscription: ",subid);
        console.log("Using vrfCoordinator: ",vrfCoordinator);
        console.log("On chainId: ",block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID){
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subid,FUND_AMOUNT * 100);
            vm.stopBroadcast();

        }else{
            vm.startBroadcast(account);
            LinkToken(link).transferAndCall(vrfCoordinator,FUND_AMOUNT,abi.encode(subid));
            vm.stopBroadcast();

        }

    } 
    
    
    
    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script{
    
    function addConsumerUsingConfig(address mostrecentdeployed) public {
        helperConfig HelperConfig = new helperConfig();
        uint256 subid = HelperConfig.getConfig().subscriptionId;
        address vrfCoordinator = HelperConfig.getConfig().vrfCoordinator;
        address account = HelperConfig.getConfig().account;
        addConsumer(mostrecentdeployed,vrfCoordinator,subid,account);
    }

    function addConsumer(address contracttoAddtoVrf,address vrfCoordinator,uint256 subid,address account) public {
        console.log("Adding consumer contract: ", contracttoAddtoVrf);
        console.log("Adding consumer to vrfCoordinator: ", vrfCoordinator);
        console.log("on chainid: ",block.chainid);
        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subid,contracttoAddtoVrf);
        vm.stopBroadcast();



    }
    
    
    
    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle",block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
     }
}