// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Test,console} from "forge-std/Test.sol";
import {Deploy} from "script/DeployRaffle.s.sol";
import {Raffle} from "src/Raffle.sol";
import {helperConfig} from "script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {CodeConstants} from "script/HelperConfig.s.sol";
contract RaffleTest is Test,CodeConstants{
    Raffle public raffle;
    helperConfig public HelperConfig;
    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_PLAYER_BALANCE = 10 ether;
    uint256 enterancefee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gaslane;
    uint256 subscriptionId;
    uint32 callbackgaslimit;
    
    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed player);
        

    function setUp() external {
        Deploy deployer = new Deploy();
        (raffle,HelperConfig)=deployer.deployContract();
        helperConfig.NetworkConfig memory config = HelperConfig.getConfig();
        enterancefee = config.entranceFee;
        interval = config.interval;
        vrfCoordinator = config.vrfCoordinator;
        gaslane = config.gaslane;
        subscriptionId = config.subscriptionId;
        callbackgaslimit = config.callbackgaslimit;
        vm.deal(PLAYER,STARTING_PLAYER_BALANCE);

    }

    function testRaffleIntitiallizesINOpenState() public view{
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        console.log("Raffle state is open");

    }
    function testRaffleRevertsWhenYouDontPayEnough() public {
        vm.prank(PLAYER);
        vm.expectRevert(Raffle.Raffle__NotEnoughETHSent.selector);
        raffle.enterRaffle();
    } 

    function testRaffleRecordsPlayersWhenTheyEnter() public {
        vm.prank(PLAYER);

        raffle.enterRaffle{value: enterancefee +1}();
        address playerRecorded = raffle.getPlayers(0);
        assert(playerRecorded == PLAYER);
    }

    function testEnteringRaffleEmitsEvent() public {
        vm.prank(PLAYER);

        vm.expectEmit(true,false,false,false,address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();

    }

    function testDontAllowPlayersWhenLotteryHasEnded() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.RaffleClosed.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();


    }

    //CheckUp Keep test below
    function testCheckUpKeepReturnsFalseIfItHasNoBalance() public {
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);  

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);  
    } 

    function testCheckUpkeepReturnsFalseIfRaffleIsntOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

    }

    function testCheckupKeepReturnsFalseifEnoughTimeHasntPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assert(!upkeepNeeded);

    }



    // Perform upKeep tests

    function testPerformUpKeepCanOnlyRunIfCheckUpKeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        
        raffle.performUpkeep("");

    }

    function testPerformUpkeepRevertsIfCheckUpKeepIsFalse() public {
        uint256 currentbalance = 0;
        uint256 players = 0;
        Raffle.RaffleState rstate = raffle.getRaffleState();

        vm.expectRevert(
            abi.encodeWithSelector(Raffle.Raffle_noUpkeepneeded.selector,currentbalance,players,rstate)
        );
        raffle.performUpkeep("");

    }


    //getting data from events
    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee + 1}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //the first log that will be emitted is by vrf coordinator ours will come after
        bytes32 requestId = entries[1].topics[1];

        Raffle.RaffleState rafflestate = raffle.getRaffleState();
        assert(uint256(requestId) > 0);
        assert(uint256(rafflestate) == 1);


    }
    // got this time a bit late lol
    modifier raffleEntered() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enterancefee +1}();
        vm.warp(block.timestamp + interval +1);
        vm.roll(block.number+1);
        _;
    }


    // Test for fullfilling random words below

    modifier skipFork() {
        if(block.chainid != LOCAL_CHAIN_ID){
            return;
            
        }_;

    }

    function testFulFillRandomWordsCanOnlyBeCalledAfterPerformUpKeep(uint256 randomRequestId) public raffleEntered skipFork {
        // one way to perform this test
        // vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(0,address(raffle));

        // vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        // VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(1,address(raffle));

        // bettter way:
        vm.expectRevert(VRFCoordinatorV2_5Mock.InvalidRequest.selector);
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(randomRequestId,address(raffle));



    }

    function testFulFillsrandomWordsPicksAWinnerResetsAndSendsMoney() public raffleEntered skipFork{
        uint256 additionalEntrants = 3; //4 total one is being added by the modifier
        uint256 startingIndex = 1;
        address expectedWinner = address(1);
        

        for(uint256 i = startingIndex;i < startingIndex + additionalEntrants;i++){
            address newPlayer = address(uint160(i));
            hoax(newPlayer,1 ether);
            raffle.enterRaffle{value: enterancefee + 1}();

        }
        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 winnerStartingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        //the first log that will be emitted is by vrf coordinator ours will come after
        bytes32 requestId = entries[1].topics[1];
        VRFCoordinatorV2_5Mock(vrfCoordinator).fulfillRandomWords(uint256(requestId),address(raffle));
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = (enterancefee +1) * (additionalEntrants + 1);

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0 );
        assert(winnerBalance == winnerStartingBalance + prize);
        assert(endingTimeStamp > startingTimeStamp);







    }



}