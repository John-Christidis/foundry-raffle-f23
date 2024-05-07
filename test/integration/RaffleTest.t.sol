// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

import {Test, console} from "forge-std/Test.sol";
import {Raffle} from "../../src/Raffle.sol";
import {DeployRaffle} from "../../script/DeployRaffle.s.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";

contract RaffleTest is Test {
    //Events
    event RaffleEntered(address indexed _player);

    Raffle raffle;
    HelperConfig helperConfig;

    uint256 entranceFee;
    uint256 interval;
    address vrfCoordinator;
    bytes32 gasLane;
    uint64 subscriptionId;
    uint32 callbackGasLimit;
    address linkTokenContractAddress;
    uint256 deployerKey;

    address public PLAYER = makeAddr("player");
    uint256 public STARTING_PLAYER_BALANCE = 10 ether;
    uint256 public ENTRANCE_FEE = 0.01 ether;

    function setUp() external {
        DeployRaffle deployRaffle = new DeployRaffle();
        (raffle, helperConfig) = deployRaffle.run();
        (
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit,
            linkTokenContractAddress
        ) = helperConfig.activeVRFConfig();
        (entranceFee, deployerKey) = helperConfig.activeNetworkConfig();

        vm.deal(PLAYER, STARTING_PLAYER_BALANCE);
    }

    function test_RaffleInitializesInOpenState() public view {
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
    }

    //enterRaffle Tests

    function test_RaffleRevertsWhenLessEtherIsSent() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectRevert(Raffle.Raffle__NotEnoughEthSent.selector);
        raffle.enterRaffle{value: ENTRANCE_FEE - 1}();
    }

    function test_RaffleRecordsPlayerUponEntering() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        //Assert
        assertEq(raffle.getPlayer(0), PLAYER);
    }

    function test_RaffleEnterRevertsWhenCalculating() public {
        //Arrange
        vm.prank(PLAYER);
        //Act
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Assert
        vm.expectRevert(Raffle.Raffle__StateNotOpen.selector);
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    function test_RaffleEmitsEvent_RaffleEntered() public {
        //Arrange
        vm.prank(PLAYER);
        //Act / Assert
        vm.expectEmit(true, false, false, false, address(raffle));
        emit RaffleEntered(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
    }

    //CheckUpkeep Tests
    function test_CheckUpkeepFailsIfRaffleHasNoBalance() public {
        //Arrange
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepFailsIfTimeHasNotPassed() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepFailsIfRaffleIsNotOpen() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        raffle.performUpkeep("");
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepFailsIfRaffleHasNoPlayers() public {
        //Arrange
        deal(address(raffle), 1 ether);
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(!upkeepNeeded);
    }

    function test_CheckUpkeepSucceedsIfAllConditionsAreTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        (bool upkeepNeeded, ) = raffle.checkUpkeep("");
        //Assert
        assert(upkeepNeeded);
    }

    //PerformUpkeep Tests
    function test_PerformUpkeepCanOnlyRunIfCheckUpkeepIsTrue() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act/Assert
        raffle.performUpkeep("");
    }

    //PerformUpkeep Tests
    function test_PerformUpkeepCanNotRunIfCheckUpkeepIsFalse() public {
        //Arrange
        uint256 raffleCurrentBalance = 0;
        uint256 numberOfPlayers = 0;
        uint256 raffleCurrentState = 0;
        //Assert/Act
        vm.expectRevert(
            abi.encodeWithSelector(
                Raffle.Raffle__UpkeepNotNeeded.selector,
                raffleCurrentBalance,
                numberOfPlayers,
                raffleCurrentState
            )
        );
        raffle.performUpkeep("");
    }

    function test_PerformUpkeepUpdatesRaffleState() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        raffle.performUpkeep("");
        //Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.CALCULATING);
    }

    function test_RaffleEmitsEvent_RandomWinnerRequested() public {
        //Arrange
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        //Act
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];
        //Assert
        assert(uint256(requestId) > 0);
    }

    function test_fulfillRandomWordsCanOnlyBeCalledAfterPerformUpkeep(
        uint256 randomRequestId
    ) public raffleEnteredAndTimePassed skipFork {
        //Arrange / Act / Assert
        vm.expectRevert("nonexistent request");
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            randomRequestId,
            address(raffle)
        );
    }

    function test_fulfillRandomWordsPicksWinnerResetsAndSendsMoney()
        public
        raffleEnteredAndTimePassed
        skipFork
    {
        //Arrange
        uint256 numberOfNewEntrances = 5;
        uint256 startingIndex = 1;
        for (uint256 i = startingIndex; i <= numberOfNewEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, STARTING_PLAYER_BALANCE);
            raffle.enterRaffle{value: ENTRANCE_FEE}();
        }
        //Act
        uint256 prize = entranceFee * (numberOfNewEntrances + 1);
        // --Pretend to be VRF
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();
        bytes32 requestId = entries[1].topics[1];

        uint256 previousTimeStamp = raffle.getLastTimeStamp();
        VRFCoordinatorV2Mock(vrfCoordinator).fulfillRandomWords(
            uint256(requestId),
            address(raffle)
        );

        //Assert
        assert(raffle.getRaffleState() == Raffle.RaffleState.OPEN);
        assertEq(raffle.getNumberOfPlayers(), 0);
        assert(raffle.getRecentWinner() != address(0));
        assert(raffle.getLastTimeStamp() > previousTimeStamp);
        assert(
            raffle.getRecentWinner().balance ==
                STARTING_PLAYER_BALANCE + prize - ENTRANCE_FEE
        );
        assert(address(raffle).balance == 0);
    }

    modifier raffleEnteredAndTimePassed() {
        vm.prank(PLAYER);
        raffle.enterRaffle{value: ENTRANCE_FEE}();
        vm.warp(block.timestamp + interval + 1);
        vm.roll(block.number + 1);
        _;
    }

    modifier skipFork() {
        if (block.chainid != 31337) {
            return;
        }
        _;
    }
}
