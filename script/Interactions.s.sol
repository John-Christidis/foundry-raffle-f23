// SPDX-License-Identifier: MIT

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";
import {DevOpsTools} from "@foundry-devops/DevOpsTools.sol";

pragma solidity 0.8.19;

contract CreateSubscription is Script {
    function createSubscriptionUsingConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, address vrfCoordinator, , , , ) = helperConfig.activeVRFConfig();
        (, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on ChainId: ", block.chainid);
        vm.startBroadcast(deployerKey);
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator)
            .createSubscription();

        vm.stopBroadcast();
        console.log("SubscriptionId : ", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return createSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script {
    uint96 public constant FUND_AMOUNT = 12 ether;

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address linkTokenContractAddress
        ) = helperConfig.activeVRFConfig();
        (, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        fundSubscription(
            vrfCoordinator,
            subId,
            linkTokenContractAddress,
            deployerKey
        );
    }

    function fundSubscription(
        address vrfCoordinator,
        uint64 subId,
        address linkTokenContractAddress,
        uint256 deployerKey
    ) public {
        console.log("Funding subscription on subId: ", subId);
        if (block.chainid == 31337) {
            //If we are on anvil chain
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(
                subId,
                FUND_AMOUNT
            );
            vm.stopBroadcast();
        } else {
            vm.startBroadcast();
            LinkToken(linkTokenContractAddress).transferAndCall(
                vrfCoordinator,
                FUND_AMOUNT,
                abi.encode(subId)
            );
            vm.stopBroadcast();
        }
    }

    function run() external {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address raffleContractAddress) public {
        HelperConfig helperConfig = new HelperConfig();
        (, address vrfCoordinator, , uint64 subId, , ) = helperConfig
            .activeVRFConfig();
        (, uint256 deployerKey) = helperConfig.activeNetworkConfig();
        addConsumer(vrfCoordinator, subId, raffleContractAddress, deployerKey);
    }

    function addConsumer(
        address vrfCoordinator,
        uint64 subId,
        address raffleContractAddress,
        uint256 deployerKey
    ) public {
        console.log("Adding Consumer on subId: ", subId);
        //If we are on anvil chain
        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(
            subId,
            raffleContractAddress
        );
        vm.stopBroadcast();
    }

    function run() external {
        address raffleContractAddress = DevOpsTools.get_most_recent_deployment(
            "Raffle",
            block.chainid
        );
        addConsumerUsingConfig(raffleContractAddress);
    }
}
