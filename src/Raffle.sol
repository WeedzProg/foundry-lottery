// Layout of Contract:
// version
// imports
// errors
// interfaces, libraries, contracts
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

//SPDX-License-Identifier: MIT

pragma solidity ^0.8.18;

/**
 * @title Raffle
 * @author Me
 * @notice Contract for a raffle
 * @dev Implements chainlink VRFv2
 */

/* solhint-disable */
import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/* solhint-enable */

//import {VRFCoordinatorV2Interface} from "../lib/chainlink-brownie-contracts/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";

contract Raffle is VRFConsumerBaseV2 {
    error Raffle__NotEnoughToEnter();
    //error Raffle__NotEnoughTimedPassed();
    error Raffle__TransferToWinnerFailed();
    error Raffle__RaffleNotOpen();
    error Raffle__UpkeepNeededCheckWentWrong(
        uint256 currentBalance,
        uint256 NumberOfPlayers,
        uint256 LotteryEnumState
    );

    //lottery states
    enum LotteryState {
        OPEN,
        //CLOSED,
        CALCULATING_WINNER
    }

    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;

    LotteryState private s_lotteryState;
    uint256 private immutable i_entranceFee;
    address payable[] private s_players;

    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    address private s_winner;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gaslane;
    uint64 private immutable i_subscriptionId;
    uint32 private immutable i_callbackGasLimit;
    address private s_recentWinner;

    event EnterRaffle(address indexed player, uint256 indexed value, string message);
    event WinnerPicked(address indexed player, string message);
    event StartRequestingWinner(uint256 indexed requestId);

    constructor(
        uint256 entranceFee,
        uint256 interval,
        //uint256 lastTimeStamp,
        address vrfCoordinator,
        bytes32 gaslane,
        uint64 subscriptionId,
        uint32 callbackGasLimit
    ) VRFConsumerBaseV2(vrfCoordinator) {
        i_entranceFee = entranceFee;
        i_interval = interval;
        s_lastTimeStamp = block.timestamp;
        i_gaslane = gaslane;
        i_subscriptionId = subscriptionId;
        i_vrfCoordinator = VRFCoordinatorV2Interface(vrfCoordinator);
        i_callbackGasLimit = callbackGasLimit;
        s_lotteryState = LotteryState.OPEN;
    }

    function enterRaffle() public payable {
        //require(msg.value >= i_entranceFee, "Not enough ETH to enter raffle");
        if (msg.value < i_entranceFee) {
            revert Raffle__NotEnoughToEnter();
        }
        if (s_lotteryState != LotteryState.OPEN) {
            revert Raffle__RaffleNotOpen();
        }

        // push players address to array
        s_players.push(payable(msg.sender));

        //emit event after entering raffle
        emit EnterRaffle(msg.sender, msg.value, "New player Entered the Raffle");
    }

    function checkUpkeep(
        bytes memory /*checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /*performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp >= i_interval);
        bool isOpen = (s_lotteryState == LotteryState.OPEN);
        bool hasEther = (address(this).balance > 0);
        bool hasPlayers = (s_players.length > 0);

        upkeepNeeded = (timeHasPassed && isOpen && hasEther && hasPlayers);

        return (upkeepNeeded, "0x00");
    }

    function performUpkeep(bytes calldata /*performData */) public {
        (bool upkeepNeeded, ) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNeededCheckWentWrong(
                address(this).balance,
                s_players.length,
                uint256(s_lotteryState)
            );
        }

        s_lotteryState = LotteryState.CALCULATING_WINNER;

        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gaslane, //gas lane, max gas to spend,depends of the chain
            i_subscriptionId, // vrf ID
            REQUEST_CONFIRMATIONS, // number of blocks
            i_callbackGasLimit, // max gas for receiving the random number
            NUM_WORDS // number of random number to request
        );
        emit StartRequestingWinner(requestId);
    }

    //function pickWinner() public {
    //block.timestamp is in seconds
    // if (block.timestamp - s_lastTimeStamp >= i_interval) {
    //     revert Raffle__NotEnoughTimedPassed();
    // }
    //        s_lotteryState = LotteryState.CALCULATING_WINNER;

    //uint256 requestId = i_vrfCoordinator.requestRandomWords(
    //i_gaslane, //gas lane, max gas to spend,depends of the chain
    //i_subscriptionId, // vrf ID
    //REQUEST_CONFIRMATIONS, // number of blocks
    //  i_callbackGasLimit, // max gas for receiving the random number
    //    NUM_WORDS // number of random number to request
    //  );
    //}

    function fulfillRandomWords(
        uint256 /*requestId*/,
        uint256[] memory randomWords
    ) internal override {
        bool sent;
        uint256 index = randomWords[0] % s_players.length;
        s_winner = s_players[index];
        s_recentWinner = s_winner;
        // (bool success, ) = s_winner.call{value: address(this).balance}("");
        // if (!success) {
        //     revert Raffle__TransferToWinnerFailed();
        // }
        s_players = new address payable[](0);
        s_lotteryState = LotteryState.OPEN;
        s_lastTimeStamp = block.timestamp;

        emit WinnerPicked(s_recentWinner, "Winner has been picked");
        (bool success, ) = s_recentWinner.call{value: address(this).balance}("");
        unchecked {
            sent = success;
        }
        if (!success) {
            revert Raffle__TransferToWinnerFailed();
        }
    }

    function getEntranceFee() public view returns (uint256) {
        return i_entranceFee;
    }

    function getPlayers(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getPlayersNumber() public view returns (uint256) {
        return s_players.length;
    }

    function getLotteryState() public view returns (LotteryState) {
        return s_lotteryState;
    }

    function getNumWords() public pure returns (uint256) {
        return NUM_WORDS;
    }

    function getRequestConfirmations() public pure returns (uint256) {
        return REQUEST_CONFIRMATIONS;
    }

    function getRecentWinner() public view returns (address) {
        return s_recentWinner;
    }

    function getLastTimeStamp() public view returns (uint256) {
        return i_interval;
    }

    receive() external payable {
        enterRaffle();
    }

    fallback() external payable {
        enterRaffle();
    }
}
