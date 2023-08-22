//SPDX-License-Identifier: MIT

pragma solidity ^0.8.17;

import {DeployLottery} from "../../script/DeployLottery.s.sol";
import {Raffle} from "../../src/Raffle.sol";
import {Test, console} from "forge-std/Test.sol";
import {StdCheats} from "forge-std/StdCheats.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    event EnterRaffle(address indexed player, uint256 indexed value, string message);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    address vrfCoordinator;
    uint256 interval;
    bytes32 gaslane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address link;
    //uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public constant STARTING_USER_BALANCE = 100 ether;

    function setUp() external {
        DeployLottery deployLottery = new DeployLottery();
        (raffle, helperConfig) = deployLottery.run();
        (
            entranceFee,
            interval,
            vrfCoordinator,
            gaslane,
            subscriptionId,
            callbackGasLimit,
            link,
            //deployerKey

        ) = helperConfig.activeNetwork();
        vm.deal(PLAYER, STARTING_USER_BALANCE);
    }

    //////////////////
    // Test Getters //
    /////////////////

    function testLotteryInitialOpenState() public view {
        assert(raffle.getLotteryState() == Raffle.LotteryState.OPEN);
    }

    function testEntranceFee() public view {
        uint256 entranceFeeTest = 0.01 ether;
        assert(raffle.getEntranceFee() == entranceFeeTest);
    }

    function testLotteryRevertIfNotEnoughAtEntry() public {
        vm.prank(PLAYER);

        vm.expectRevert(Raffle.Raffle__NotEnoughToEnter.selector);
        raffle.enterRaffle();
    }

    function testRecordsWhenPlayerEnterTheRaffle() public returns (uint256) {
        assert(raffle.getPlayersNumber() == 0);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayersNumber() == 1);

        return raffle.getPlayersNumber();
    }

    function testEnteredPlayerAddressesByIndex() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
        assert(raffle.getPlayers(0) == PLAYER);
    }

    function testGetNumWords() public {
        assert(raffle.getNumWords() == 1);
    }

    function testRequestConfirmations() public {
        assert(raffle.getRequestConfirmations() == 3);
    }

    function testInterval() public {
        // 30sec for anvil, setting in helperConfig
        assert(raffle.getLastTimeStamp() == 30);
    }

    function testRecentWinnerWithoutPlayer() public {
        console.log("Winner view function without players: ", raffle.getRecentWinner());
        assert(raffle.getRecentWinner() == address(0x0000000000000000000000000000000000000000));
    }

    function testRecentWinnerWithPlayer() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);

        //allowing to call perform upkeep
        raffle.performUpkeep("");

        //fulffill random words call to select winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(1, address(raffle));

        assert(raffle.getRecentWinner() == address(PLAYER));
    }

    //////////////////////////////
    // Test FallBack & Receive //
    /////////////////////////////
    function testTransfertEthToContractAddress() public {
        // revert transfert
        vm.expectRevert();
        vm.prank(PLAYER);
        payable(address(raffle)).transfer(0.01 ether);
    }

    function testCallEthToContractAddress() public {
        // redirect call to entering raffle
        vm.prank(PLAYER);

        payable(address(raffle)).call{value: 0.01 ether}("");
        assert(raffle.getPlayersNumber() == 1);
    }

    /////////////////////////
    // Test Main Functions //
    /////////////////////////

    function testEmitEventWhenenteringRaffle() public {
        //test events. indexed parameters / Topics = true, rest is false and the end is the emitter address
        // then redefine the event in the test contract at top, write the expected test
        // make the transaction that should emit the expected event result
        vm.prank(PLAYER);
        vm.expectEmit(true, true, false, false, address(raffle));
        emit EnterRaffle(PLAYER, entranceFee, "New player Entered the Raffle");
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCantEnterRaffleWhenCalculating() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);

        //allowing to call perform upkeep
        raffle.performUpkeep("");
        vm.expectRevert(Raffle.Raffle__RaffleNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();
    }

    function testCheckupkeepReturnsFalseIfNotOpen() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        assert(upkeepNeeded != true);
    }

    function testCheckupkeepReturnsFalseIfNotEnoughTimeHasPassed() public {
        //uint256 currentBalance = 0;
        // uint256 playerLenght = raffle.getPlayersNumber();
        // uint256 lotteryState = uint256(raffle.getLotteryState());

        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp);
        // vm.expectRevert(
        //     abi.encodeWithSelector(
        //         Raffle.Raffle__UpkeepNeededCheckWentWrong.selector,
        //         entranceFee, //as player, entered raffle balance of the contract is the same amount as the entranceFee. only 1 player paid
        //         playerLenght,
        //         lotteryState
        //     )
        // );
        raffle.performUpkeep("");
    }

    //
    //testTrueWhenParameterAreGood
    //
    function testCheckupkeepReturnsTrueIfEnoughTimeHasPassed() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        // assert(upkeepNeeded == true);
    }

    function testPerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);

        raffle.performUpkeep("");
    }

    function testPerformUpkeepIfCheckUpkeepIsFalse() public {
        uint256 currentBalance = 0;
        uint256 playerLenght = raffle.getPlayersNumber();
        uint256 lotteryState = uint256(raffle.getLotteryState());

        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNeededCheckWentWrong.selector,
                currentBalance,
                playerLenght,
                lotteryState
            )
        );
        raffle.performUpkeep("");
    }

    //Test output of an event
    //added an event to perform upkeep emitting a requestId
    // the added event is redundant because a similar event is also emitted when calling vrfCoordinator to get a randomWord
    // at the requestRandomWords function of it.

    function testPerformUpkeepUpdatesRaffleStateAndEmitsRequestId()
        public
        raffleEnteredAndTimePassed
    {
        // record emitted logs in a data structure
        // require "Vm" to be imported (with a capital "V")
        vm.recordLogs();
        raffle.performUpkeep("");

        //Vm.Log[] is a special array type of foundry. The data structure to put recorded logs into.
        Vm.Log[] memory entries = vm.getRecordedLogs();
        // all logs are recorded as byte32 in foundry
        bytes32 requestId = entries[1].topics[1];
        //in perform up keep this is the second event, so entrie is 1
        // topic[0] is the whole event, topic[1] is the first place contents

        assert(uint256(requestId) > 0);
        // assert(requestId > 0);
        assert(raffle.getLotteryState() == Raffle.LotteryState.CALCULATING_WINNER);
    }

    //////////////////
    // Fuzz Testing //
    //////////////////

    //instead of testing all combinaison of a requestId amounts we are going to do a fuzz test on it to test plenty of combinaisons.
    // so our test need an input parameter, that will reach or requestId number position, and the test will be called from a fuzz test functions automaticaly in foundry, just need to run the test.
    function testFulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipWhenTestnet {
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(randomRequestId, address(raffle));
    }

    function testFulfillRandomWordsPicksAWinnerAndResetPlayerArrayAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipWhenTestnet
    {
        address expectedWinner = address(1);

        uint256 additionalPlayers = 3;
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i < startingIndex + additionalPlayers; i++) {
            address player = address(uint160(i)); //cast number to uint160 = ox address created
            hoax(player, STARTING_USER_BALANCE);
            raffle.enterRaffle{value: entranceFee}();
        }

        uint256 startingTimeStamp = raffle.getLastTimeStamp();
        uint256 startingBalance = expectedWinner.balance;

        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        // Mock a chainlink node and Use VRFCoordinator to pretend be the winner
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        address recentWinner = raffle.getRecentWinner();
        Raffle.LotteryState raffleState = raffle.getLotteryState();
        uint256 winnerBalance = recentWinner.balance;
        uint256 endingTimeStamp = raffle.getLastTimeStamp();
        uint256 prize = entranceFee * (additionalPlayers + 1);

        console.log("Recent winner and expected winner: ", recentWinner, expectedWinner);
        // 0x0000000000000000000000000000000000000005
        // 0x0000000000000000000000000000000000000005

        //console.log("raffle state: ", uint256(raffleState));
        // 0

        // console.log(
        //     "winner starting balance and prize, then added: ",
        //     STARTING_USER_BALANCE,
        //     prize,
        //     winnerBalance
        // );
        // 100000000000000000000
        // 60000000000000000
        // 1050000000000000000

        console.log("Timestamps Start and Ending: ", startingTimeStamp, endingTimeStamp);
        // 30
        // 30

        assert(recentWinner == expectedWinner);
        assert(uint256(raffleState) == 0);
        assert(winnerBalance == (STARTING_USER_BALANCE + prize) - entranceFee);
        assert(endingTimeStamp == startingTimeStamp);
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: entranceFee}();

        // forward blocks.timestamp
        vm.warp(block.timestamp + interval + 1);
        // set the blockNumber
        vm.roll(block.number + 1);
        _;
    }

    modifier skipWhenTestnet() {
        if (block.chainid == 31337) {
            return;
        }
        _;
    }
}
