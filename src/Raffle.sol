// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {VRFConsumerBaseV2Plus} from "@chainlink/contracts/src/v0.8/vrf/dev/VRFConsumerBaseV2Plus.sol";
import {VRFV2PlusClient} from "@chainlink/contracts/src/v0.8/vrf/dev/libraries/VRFV2PlusClient.sol";

/**
 * @title Raffle contract
 * @author Alman Adeel
 * @notice This is contract is for a lottery/raffle contract
 * @dev implements chainlink VRFv2.5
 */
contract Raffle is VRFConsumerBaseV2Plus {
    /* Errors */
    error Raffle__NotEnoughETHSent();
    error TransferFailed();
    error RaffleClosed();
    error Raffle_noUpkeepneeded(uint256 balance,uint256 playerlength,uint256 raffleState);

    /**Type Decleration */
    enum RaffleState{
        OPEN,CALCULATING
    }

    /**State Variables */
    uint32 private constant NUM_WORDS = 1;
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint256 private immutable i_enterncefee;
    uint256 private immutable i_interval;
    bytes32 private immutable i_keyhash;
    uint32 private immutable i_callbackgaslimit;
    address payable[] private s_players;
    uint256 private immutable i_subscriptionId;
    uint256 private s_lastTimeStamp;
    address private s_RecentWinner;
    RaffleState private s_rafflestate;

    event RaffleEntered(address indexed player);
    event WinnerPicked(address indexed player);
    event RequestedRaffleWinner(uint256 indexed requestid);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        address vrfCoordinator,
        bytes32 gaslane,
        uint256 subscriptionId,
        uint32 callbackgaslimit
    ) VRFConsumerBaseV2Plus(vrfCoordinator) {
        i_enterncefee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_keyhash = gaslane;
        i_subscriptionId = subscriptionId;
        i_callbackgaslimit = callbackgaslimit;
        s_rafflestate = RaffleState.OPEN;
    }

    function enterRaffle() external payable {
        //i couldve done this but since i found something more gas efficient i didnt use it
        // require(msg.value>= i_enterncefee,"not enough ether to enter the raffle");
        if (msg.value <= i_enterncefee) {
            revert Raffle__NotEnoughETHSent();
        }
        if (s_rafflestate != RaffleState.OPEN){
            revert RaffleClosed();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    /**
     * @dev "This is the function that will be called by chainlink nodes to check if the 
     * lottery is ready to have a winner picked"
     * the following should be true for upkeepNeeded to be true;
     * 1.the time interval has passed between raffle runs
     * 2.the lottery is open
     * 3.the contract has ETH
     * 4.Implicitly you subscription has LINK 
     * @param -ignored
     * @return upkeepNeeded -true if it's time to restart the lottery
     * @return -ignored
     */
    function checkUpkeep(bytes memory /**checkData */) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed =  ((block.timestamp - s_lastTimeStamp) >= i_interval);
        bool isOpen = s_rafflestate == RaffleState.OPEN;
        bool hasBalance = address(this).balance > 0;
        bool hasPlayers = s_players.length > 0;
        upkeepNeeded = timeHasPassed && isOpen && hasBalance && hasPlayers;
        /**Although not required to write return but i am writing it for the sake of simplicty and better understanding */
        return(upkeepNeeded,"0x0");


    }


    function performUpkeep(bytes calldata /* performData */) external{
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded){
            revert Raffle_noUpkeepneeded(address(this).balance,s_players.length,uint256(s_rafflestate));
        }
        s_rafflestate = RaffleState.CALCULATING;
        uint256 requestId = s_vrfCoordinator.requestRandomWords(
            VRFV2PlusClient.RandomWordsRequest({
                keyHash: i_keyhash,
                subId: i_subscriptionId,
                requestConfirmations: REQUEST_CONFIRMATIONS,
                callbackGasLimit: i_callbackgaslimit,
                numWords: NUM_WORDS,
                extraArgs: VRFV2PlusClient._argsToBytes(
                    // Set nativePayment to true to pay for VRF requests with Sepolia ETH instead of LINK
                    VRFV2PlusClient.ExtraArgsV1({nativePayment: false})
                )
            })
        );
        // we didnt need to write this request as vrfcoor. is already emitting one in its own file but for testing purposes i am writing here
        emit RequestedRaffleWinner(requestId);
    }

     function fulfillRandomWords(uint256 requestId,uint256[] calldata randomWords) internal override{
        uint256 index0fWinner = randomWords[0] % s_players.length;
        address payable recentWinner = s_players[index0fWinner];
        s_RecentWinner = recentWinner;
        s_rafflestate = RaffleState.OPEN;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(s_RecentWinner);

        (bool success,) = recentWinner.call{value: address(this).balance}("");
        if (!success){
            revert TransferFailed();
        }
        

     }

    /**
     * Getter functions below
     */
    function getEntranceFee() external view returns (uint256) {
        return i_enterncefee;
    }

    function getRaffleState() external view returns(RaffleState){
        return s_rafflestate;
    }

    function getPlayers(uint256 indexOfplayer) external view returns(address){
        return s_players[indexOfplayer];

    }

    function getLastTimeStamp() external view returns(uint256){
        return s_lastTimeStamp;
    }

    function getRecentWinner() external view returns(address){
        return s_RecentWinner;
    }
   
}
