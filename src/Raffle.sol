// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {VRFCoordinatorV2Interface} from "@chainlink/contracts/src/v0.8/interfaces/VRFCoordinatorV2Interface.sol";
import {VRFConsumerBaseV2} from "@chainlink/contracts/src/v0.8/VRFConsumerBaseV2.sol";

/**
 * @title A sample Raffle Contract
 * @author John Christidis
 * @notice Originally taken by the courses of Cyfrin Updraft by Patrick Collins
 */

contract Raffle is VRFConsumerBaseV2 {
    //Errors
    error Raffle__NotEnoughEthSent();
    error Raffle__NotEnoughTimePassedSinceLastInterval();
    error Raffle__TransferFailed();
    error Raffle__StateNotOpen();
    error Raffle__UpkeepNotNeeded(
        uint256 _contractBalance,
        uint256 _numberOfPlayers,
        uint256 _stateOfRaffle
    );

    //Type Declarations
    enum RaffleState {
        OPEN,
        CALCULATING
    }
    //State Variables

    //Chainlink VRF Coordinator parameters
    uint16 private constant REQUEST_CONFIRMATIONS = 3;
    uint32 private constant NUM_WORDS = 1;
    VRFCoordinatorV2Interface private immutable i_vrfCoordinator;
    bytes32 private immutable i_gasLane;
    uint32 private immutable i_callbackGasLimit;
    uint64 private immutable i_subscriptionId;

    //Raffle Variables
    uint256 private immutable i_interval;
    uint256 private s_lastTimeStamp;
    uint256 private s_entranceFee;
    address payable[] private s_players;
    address payable s_recentWinner;
    RaffleState private s_raffleState;

    //Events
    event RaffleEntered(address indexed _player);
    event WinnerPicked(address indexed _winner);
    event RandomWinnerRequested(uint256 indexed _requestId);

    //Functions

    //Constructor
    constructor(
        uint256 _entranceFee,
        uint256 _interval,
        address _vrfCoordinator,
        bytes32 _gasLane,
        uint64 _subscriptionId,
        uint32 _callbackGasLimit
    ) VRFConsumerBaseV2(_vrfCoordinator) {
        i_vrfCoordinator = VRFCoordinatorV2Interface(_vrfCoordinator);
        i_gasLane = _gasLane;
        i_subscriptionId = _subscriptionId;
        i_callbackGasLimit = _callbackGasLimit;

        i_interval = _interval;

        s_lastTimeStamp = block.timestamp;
        s_entranceFee = _entranceFee;
        s_raffleState = RaffleState.OPEN;
    }

    //External
    //Enter Raffle
    function enterRaffle() external payable {
        if (msg.value < s_entranceFee) {
            revert Raffle__NotEnoughEthSent();
        }
        if (s_raffleState != RaffleState.OPEN) {
            revert Raffle__StateNotOpen();
        }
        s_players.push(payable(msg.sender));
        emit RaffleEntered(msg.sender);
    }

    //Automation Chainlink
    /**
     * @dev This is the function that the Chainlink Keeper nodes call
     * they look for `upkeepNeeded` to return True.
     * the following should be true for this to return true:
     * 1. The time interval has passed between raffle runs.
     * 2. The lottery is open.
     * 3. The contract has ETH.
     * 4. Subscription MUST be funded with LINK.
     */
    function checkUpkeep(
        bytes memory /* checkData */
    ) public view returns (bool upkeepNeeded, bytes memory /* performData */) {
        bool timeHasPassed = (block.timestamp - s_lastTimeStamp) >= i_interval;
        bool raffleIsOpen = s_raffleState == RaffleState.OPEN;
        bool raffleHasBalance = address(this).balance > 0;
        bool raffleHasPlayers = s_players.length > 0;
        upkeepNeeded = (timeHasPassed &&
            raffleIsOpen &&
            raffleHasBalance &&
            raffleHasPlayers);
        return (upkeepNeeded, "0x0");
    }

    function performUpkeep(bytes calldata /* performData */) external {
        (bool upkeepNeeded, ) = checkUpkeep(""); //check if memory is fine here <---
        if (!upkeepNeeded) {
            revert Raffle__UpkeepNotNeeded(
                address(this).balance,
                s_players.length,
                uint256(s_raffleState)
            );
        }
        pickWinner();
    }

    //Pick Winner
    function pickWinner() internal {
        s_raffleState = RaffleState.CALCULATING;
        uint256 requestId = i_vrfCoordinator.requestRandomWords(
            i_gasLane, //gas lane
            i_subscriptionId,
            REQUEST_CONFIRMATIONS,
            i_callbackGasLimit,
            NUM_WORDS
        );
        emit RandomWinnerRequested(requestId);
    }

    function fulfillRandomWords(
        uint256 /*_requestId*/,
        uint256[] memory _randomWords
    ) internal override {
        uint256 indexOfWinner = _randomWords[0] % s_players.length;
        address payable winner = s_players[indexOfWinner];
        s_recentWinner = winner;
        s_players = new address payable[](0);
        s_lastTimeStamp = block.timestamp;
        s_raffleState = RaffleState.OPEN;
        emit WinnerPicked(winner);
        (bool callSuccess, ) = winner.call{value: address(this).balance}("");
        if (!callSuccess) {
            revert Raffle__TransferFailed();
        }
    }

    //View
    function getEntranceFee() public view returns (uint256) {
        return s_entranceFee;
    }

    function getRaffleState() public view returns (RaffleState) {
        return s_raffleState;
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

    function getPlayer(uint256 index) public view returns (address) {
        return s_players[index];
    }

    function getLastTimeStamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getInterval() public view returns (uint256) {
        return i_interval;
    }

    function getNumberOfPlayers() public view returns (uint256) {
        return s_players.length;
    }
}
