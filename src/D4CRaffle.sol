//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;
/**
*@title A sample Raffle contract
*@author D4C
*@notice This is a contract for creating a VRF raffle
*@dev Implements Chainlink VRFv2
 */
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

contract Raffle is VRFConsumerBaseV2 {
   error Raffle__NotEnoughSpent();
   error D4CRaffle__timeNotReached();
   error  Raffle_transferFailed();
   error Raffle_raffleStateNotOpen();
   error Raffle_UpkeepNotNeeded(uint256 currentBalance , uint256 numPlayers , uint256 raffleState);

   //TYPE DECLARATIONS//
   enum RaffleState {
    OPEN,
    CALCULATING
   }

   
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    uint256 private immutable i_enteranceFee;
    uint256 private immutable  i_interval;
    uint32 private immutable i_callBackGasLimit;
    bytes32 private immutable i_keyHash;
    uint64 private immutable i_subscriptionId;
    
    address payable[] private s_player;
    uint256 private s_lastTimeStamp;
    address private s_recentWinner;
    RaffleState private s_raffleState;
    
    /*Events*/
    event EnteredRaffle (address indexed player);
    event WinnerPicked(address indexed winner);
    event RequestedRaffleWinner(uint256 indexed requestId);

    constructor(
        uint256 enteranceFee,
        uint256 interval, 
        address vrfCoordinator, 
        bytes32 keyHash, 
        uint64 subscriptionId,
        uint32 callbackGasLimit
    )VRFConsumerBaseV2(vrfCoordinator) {
        i_enteranceFee = enteranceFee;
        i_interval = interval;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_keyHash = keyHash;
        i_subscriptionId =  subscriptionId;
        i_callBackGasLimit = callbackGasLimit;

        s_raffleState = RaffleState.OPEN;
        s_lastTimeStamp = block.timestamp;
    }
    
    function enterRaffle() external payable  {
       if (msg.value < i_enteranceFee){
        revert Raffle__NotEnoughSpent();
    }
    if (s_raffleState != RaffleState.OPEN){
        revert Raffle_raffleStateNotOpen();
    }
    s_player.push(payable(msg.sender));
    emit EnteredRaffle(msg.sender);
}
    /**Function for chainlink automation to perform upkeep
    * 1. The amount of time has passed between raffles
    * 2. The raffle is in OPEN state
    * 3. The contract has ETH (aka, players)
    * 4. The subscription is funded with LINK    
     */
    function checkUpkeep(
        bytes memory /* checkData */
     )  public view returns (bool upkeepNeeded, bytes memory /*performData*/){
            bool timeHasPassed = ( block.timestamp - s_lastTimeStamp) >= i_interval;
            bool isOpen = RaffleState.OPEN == s_raffleState;
            bool hasBalance = address(this).balance > 0;
            bool hasPlayers = s_player.length > 0;
            upkeepNeeded = (timeHasPassed && isOpen && hasBalance && hasPlayers);
            return (upkeepNeeded, "0x0");
        }
    function performUpkeep(bytes calldata /*performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle_UpkeepNotNeeded(
                address(this).balance,
                s_player.length,
                uint256(s_raffleState)
            );

        }

        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_keyHash,
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callBackGasLimit,
            NUM_WORDS
       );
       emit RequestedRaffleWinner(requestId);
    }

    //CEI: Checks, Effects, Interactions
    function fulfillRandomWords(
        uint256 /* requestId */,
        uint256[] memory randomWords

    ) internal override{
        // Checks
        //effects 
        uint256 indexOfWinner = randomWords[0] % s_player.length;
        address payable winner = s_player[indexOfWinner];
        s_recentWinner = winner;
        s_raffleState = RaffleState.OPEN;
        s_player = new address payable [](0);
        s_lastTimeStamp = block.timestamp;
        emit WinnerPicked(winner);
        //Interactions       
        (bool success,) = winner.call{value: address(this).balance}("");
        if (!success){
            revert Raffle_transferFailed();
        }
        
    }

    function getEnteranceFee()external view returns (uint256){
        return i_enteranceFee;
    }

    function getRaffleState()external view returns (RaffleState) {
        return s_raffleState;
    }

    function getPlayer(uint256 indexedPlayer) external view returns (address){
        return s_player[indexedPlayer];
    
    }
    function getRecentWinner()external view returns (address){
        return s_recentWinner;
    }
    function getLengthOfPlayers() external view returns(uint256){
        return s_player.length;
    }
    function getLastTimeStamp ()external view returns(uint256){
        return s_lastTimeStamp;
    }
}