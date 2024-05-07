// SPDX-License-Identifier: MIT

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {Raffle} from "../src/Raffle.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

pragma solidity 0.8.19;

contract DeployRaffle is Script {
    Raffle private raffle;

    function run() external returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        (
            uint256 interval,
            address vrfCoordinator,
            bytes32 gasLane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address linkTokenContractAddress
        ) = helperConfig.activeVRFConfig();

        (uint256 entranceFee, uint256 deployerKey) = helperConfig
            .activeNetworkConfig();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(
                vrfCoordinator,
                deployerKey
            );
        }

        FundSubscription fundSubscription = new FundSubscription();
        fundSubscription.fundSubscription(
            vrfCoordinator,
            subscriptionId,
            linkTokenContractAddress,
            deployerKey
        );

        vm.startBroadcast();
        raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gasLane,
            subscriptionId,
            callbackGasLimit
        );
        vm.stopBroadcast();

        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(
            vrfCoordinator,
            subscriptionId,
            address(raffle),
            deployerKey
        );
        return (raffle, helperConfig);
    }
}
