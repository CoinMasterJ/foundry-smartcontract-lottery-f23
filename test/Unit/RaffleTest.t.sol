//SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {Raffle} from "../../src/D4CRaffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {CreateSubscription} from "../../script/Interactions.s.sol";
import {Vm} from "forge-std/Vm.sol";



contract RaffleTest is Test {
    //EVENT

    event EnteredRaffle(address indexed player);

    Raffle raffle;
    HelperConfig helperConfig; 
    
    

    uint256 enteranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 keyHash;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    uint256 deployerKey;
    

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 10 ether;

    function setUp ()external {
        DeployRaffle deployer = new DeployRaffle();
        (raffle, helperConfig) = deployer.run();
        (
            enteranceFee,
            interval,
            vrfCoordinator, 
            keyHash,
            subscriptionId,
            callbackGasLimit,
            ,//link,
            //deployerKey
        ) =helperConfig.activeNetworkConfig();
        vm.deal(PLAYER,STARTING_USER_BALANCE);
     }
     function testRaffleIntilizeinOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
     }

     function testCheckForEnoughFundsTransacted()public {
//Arrange
        vm.prank(PLAYER);
 //Act
        vm.expectRevert(Raffle.Raffle__NotEnoughSpent.selector);
 //Assert
        raffle.enterRaffle();
     }

     function testRaffleRecordsPlayerBeingEntered() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        address playerRecorded = raffle.getPlayer(0);
        assert(playerRecorded == PLAYER);
     }
     function testEmitsOnEvent () public {
        vm.prank(PLAYER);
        vm.expectEmit(true, false, false, false, address(raffle));
        emit EnteredRaffle(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();

     }
     function testCantEnterWenCalculating() public{
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
        vm.warp(block.timestamp + interval + 1 );
        vm.roll(block.number + 1 );
        raffle.performUpkeep("");

        vm.expectRevert(Raffle.Raffle_raffleStateNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: enteranceFee}();
     }

      ////////////////////
      ////CHECK UPKEEP////
      ////////////////////
      modifier raffleEnteredAndTimePassed (){
         vm.prank(PLAYER);
         raffle.enterRaffle{value: enteranceFee}();
         vm.warp(block.timestamp + interval + 1);
         vm.roll(block.number + 1);
         _;
      }
      
      function testCheckUpkeepFalseEnoughtBalance()public {
         //Arrange
         vm.warp(block.timestamp + interval + 1);
         vm.roll(block.number + 1);

         //Act
         (bool upkeepNeeded, ) = raffle.checkUpkeep("");

         //Assert
         assert (!upkeepNeeded);

      }

      function testCheckUpKeepFalseRaffleNotOpen() public raffleEnteredAndTimePassed{
        //Arrange
         
         raffle.performUpkeep("");
         Raffle.RaffleState raffleState = raffle.getRaffleState();
        //Act
         (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
         assert (raffleState == Raffle.RaffleState.CALCULATING);     
         assert (!upkeepNeeded);

      }
      
   //   function testCheckUpkeepReturnsFalseIfNotEnoughTime() public {
         //arrange
   //      vm.prank(PLAYER);
   //      raffle.enterRaffle{value: enteranceFee}();
   //      vm.warp(block.timestamp + interval + 1);
   //      vm.roll(block.number + 1);
   //      raffle.performUpkeep("");
         
         //act
   //      (bool upkeepNeeded, ) = raffle.checkUpkeep("");
         
         //assert
   //      assert(upkeepNeeded);
   //   }

      function testCheckUpkeepReturnsTrueWithParamatersMet() public raffleEnteredAndTimePassed{
         raffle.performUpkeep("");
         (bool upkeepNeeded,) = raffle.checkUpkeep("");
         
         
         assert(!upkeepNeeded);
         
      }

      /////////////////
      //PerformUpKeep//
      /////////////////
      

      function testPerformUpkeepCanOnlyRunIfCheckUpKeepIsTrue() 
      public 
      raffleEnteredAndTimePassed{
        

         raffle.performUpkeep("");

      }

      function testPerformUpkeepRevertIfCheckUpKeepIsFalse() public{
         uint256 currentBalance = 0;
         uint256 numPlayers = 0;
         uint256 raffleState = 0;
         vm.expectRevert(abi.encodeWithSelector(
            Raffle.Raffle_UpkeepNotNeeded.selector,
            currentBalance, 
            numPlayers, 
            raffleState
            )
         );
         raffle.performUpkeep("");
      }
      
      function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
      public 
      raffleEnteredAndTimePassed { 
      
         vm.recordLogs();
         raffle.performUpkeep("");// emits requestId
         Vm.Log[] memory entries = vm.getRecordedLogs();
         bytes32 requestId = entries [1].topics[1];

         Raffle.RaffleState rState = raffle.getRaffleState();
         
         assert(uint256(requestId)> 0);
         assert(uint256(rState) == 1);
         }
   
      modifier skipFork(){
         if (block.chainid != 31337){
            return;
            
         }
         _;
      }

      function testFulfillRandomWordsCanOnlyBeFilledAfterPerformUpkeep(
         uint256 randomRequestId
      )  public
         raffleEnteredAndTimePassed skipFork{ 
         
         vm.expectRevert("nonexistent request");
         VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
       

      }
      
      function testFulfillRandomWordsPicksWinnerAndSendsFunds()
      public 
      raffleEnteredAndTimePassed skipFork{
         uint256 additionalEntrants = 5;
         uint256 startingIndex = 1;
         for( 
            uint256 i = startingIndex;
            i < startingIndex + additionalEntrants; 
            i++
         ){
            address player = address(uint160(i));
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: enteranceFee}();
         }
         uint256 prize = enteranceFee * (additionalEntrants + 1);

         vm.recordLogs();
         raffle.performUpkeep("");// emits requestId
         Vm.Log[] memory entries = vm.getRecordedLogs();
         bytes32 requestId = entries [1].topics[1];

         uint256 previousTimeStamp = raffle.getLastTimeStamp();

        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
         uint256(requestId), 
         address(raffle)
        ); 
         console.log(raffle.getRecentWinner().balance);
         console.log(prize + STARTING_USER_BALANCE);
         assert(uint256(raffle.getRaffleState()) == 0);
         assert(raffle.getRecentWinner() != address(0));
         assert(raffle.getLengthOfPlayers() == 0);
         assert(previousTimeStamp < raffle.getLastTimeStamp());
         assert(raffle.getRecentWinner().balance == STARTING_USER_BALANCE + prize - enteranceFee);

      }
}

      
         