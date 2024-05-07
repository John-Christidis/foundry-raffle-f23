// SPDX-License-Identifier: MIT

import {Script, console} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/mocks/LinkToken.sol";

pragma solidity 0.8.19;

contract HelperConfig is Script {
    struct VRFConfig {
        uint256 interval;
        address vrfCoordinator;
        bytes32 gasLane;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address linkTokenContractAddress;
    }

    struct NetworkConfig {
        uint256 entranceFee;
        uint256 deployerKey;
    }

    VRFConfig public activeVRFConfig;
    NetworkConfig public activeNetworkConfig;

    // MOCK Variables
    uint96 BASE_FEE = 0.25 ether; // = 0.25 LINK
    uint96 GAS_PRICE_LINK = 1e9; // 1 gwei LINK
    uint256 constant DEFAULT_ANVIL_KEY =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        //Sepolia
        if (block.chainid == 11155111) {
            (activeNetworkConfig, activeVRFConfig) = getSepoliaEthConfig();
        } else {
            (
                activeNetworkConfig,
                activeVRFConfig
            ) = getOrCreateAnvilEthConfig();
        }
    }

    function getSepoliaEthConfig()
        public
        view
        returns (NetworkConfig memory, VRFConfig memory)
    {
        VRFConfig memory sepoliaVRFConfig = VRFConfig({
            interval: 30,
            vrfCoordinator: 0x8103B0A8A00be2DDC778e6e7eaa21791Cd364625, //0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B V2.5
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, //V2 id: 11577
            callbackGasLimit: 500000,
            linkTokenContractAddress: 0x779877A7B0D9E8603169DdbD7836e478b4624789
        });

        NetworkConfig memory sepoliaNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            deployerKey: vm.envUint("SEPOLIA_PRIVATE_KEY")
        });

        return (sepoliaNetworkConfig, sepoliaVRFConfig);
    }

    function getOrCreateAnvilEthConfig()
        public
        returns (NetworkConfig memory, VRFConfig memory)
    {
        if (activeVRFConfig.vrfCoordinator != address(0)) {
            return (activeNetworkConfig, activeVRFConfig);
        }
        vm.startBroadcast();
        VRFCoordinatorV2Mock mockVRFCoordinator = new VRFCoordinatorV2Mock(
            //uint96 _baseFee, uint96 _gasPriceLink
            BASE_FEE,
            GAS_PRICE_LINK
        );
        LinkToken linkToken = new LinkToken();
        vm.stopBroadcast();
        console.log(address(mockVRFCoordinator));
        NetworkConfig memory anvilNetworkConfig = NetworkConfig({
            entranceFee: 0.01 ether,
            deployerKey: DEFAULT_ANVIL_KEY
        });

        VRFConfig memory anvilVRFConfig = VRFConfig({
            interval: 30,
            vrfCoordinator: address(mockVRFCoordinator),
            gasLane: 0x474e34a077df58807dbe9c96d3c009b23b3c6d0cce433e59bbf5b34f823bc56c,
            subscriptionId: 0, // our script will add this
            callbackGasLimit: 500000,
            linkTokenContractAddress: address(linkToken)
        });

        return (anvilNetworkConfig, anvilVRFConfig);
    }
}
