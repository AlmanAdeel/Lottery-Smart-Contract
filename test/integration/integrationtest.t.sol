// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "script/interaction.s.sol";
import {Raffle} from "src/Raffle.sol";
import {Deploy} from "script/DeployRaffle.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/linktoken.sol";
import {helperConfig} from "script/HelperConfig.s.sol";

contract IntegrationTest is Test {
    Raffle public raffle;
    helperConfig public config;
    VRFCoordinatorV2_5Mock public vrfCoordinator;
    LinkToken public linkToken;
    
    uint256 public subId;
    address public account;
    uint256 public constant FUND_AMOUNT = 3 ether;

    function setUp() public {
        config = new helperConfig();
        helperConfig.NetworkConfig memory configData = config.getConfig();


        address _vrfCoordinator = configData.vrfCoordinator;
        address _linkToken = configData.link;
        account = configData.account;

        vrfCoordinator = VRFCoordinatorV2_5Mock(_vrfCoordinator);
        linkToken = LinkToken(_linkToken);

        // Create Subscription
        CreateSubscription createSub = new CreateSubscription();
        (subId,) = createSub.createSubscription(address(vrfCoordinator), account);

        // Fund Subscription
        FundSubscription fundSub = new FundSubscription();
        fundSub.fundSubscription(
            address(vrfCoordinator),
            subId,
            address(linkToken),
            account
        );

        // Deploy Raffle
        Deploy deployer = new Deploy();
        (Raffle deployedRaffle, ) = deployer.run();
        raffle = deployedRaffle;




        // Add Consumer
        AddConsumer addCons = new AddConsumer();
        addCons.addConsumer(
            address(raffle),
            address(vrfCoordinator),
            subId,
            account
        );
    }

    function testSubscriptionCreated() public  view{
        ( , , , address owner, ) = vrfCoordinator.getSubscription(subId);
        assertEq(owner, account, "Subscription owner should match configured account");


        assertEq(owner, account, "Subscription owner should match configured account");
    }


    function testSubscriptionFunded() public view {
        (uint96 balance,,,,) = vrfCoordinator.getSubscription(subId);
        uint256 expectedBalance = block.chainid == 31337 
            ? FUND_AMOUNT * 100 
            : FUND_AMOUNT;
        assertEq(balance, expectedBalance, "Subscription balance incorrect");
    }

    function testConsumerAdded() public view {
        (,,,, address[] memory consumers) = vrfCoordinator.getSubscription(subId);
        assertEq(consumers.length, 1, "Consumer count mismatch");
        assertEq(consumers[0], address(raffle), "Raffle not registered as consumer");
    }

    function testFullWorkflow() public {
        // Verify all components work together
        testSubscriptionCreated();
        testSubscriptionFunded();
        testConsumerAdded();
        
        // Additional checks for Raffle initialization
        assertEq(raffle.getEntranceFee(), config.getConfig().entranceFee, "Entrance fee mismatch");
        assertEq(raffle.getLastTimeStamp(), config.getConfig().interval, "Interval mismatch");
    }

      // New test function to test createSubscriptionUsingConfig()
    function testCreateSubscriptionUsingConfig() public {
        CreateSubscription createSubTest = new CreateSubscription();
        (uint256 testSubId, address testCoordinator) = createSubTest.createSubscriptionUsingConfig();
        
        // Assert that the subscription ID is greater than zero.
        assertGt(testSubId, 0, "Subscription ID should be greater than zero");
        
        // Assert that the coordinator address is not zero.
        assertTrue(testCoordinator != address(0), "VRF Coordinator should not be the zero address");
    }
}