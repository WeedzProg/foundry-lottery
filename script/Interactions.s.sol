// SPDX-License-Identifier:MIT

pragma solidity ^0.8.17;

import {Script, console} from "forge-std/Script.sol";
import {DeployLottery} from "../script/DeployLottery.s.sol";
import {DevOpsTools} from "../lib/foundry-devops/src/DevOpsTools.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../mocks/LinkToken.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionConfig() public returns (uint64) {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , , , , uint256 deployerKey) = helperConfig.activeNetwork();
        return createSubscription(vrfCoordinator, deployerKey);
    }

    function createSubscription(
        address vrfCoordinator,
        uint256 deployerKey
    ) public returns (uint64) {
        console.log("Creating subscription on chainID: ", block.chainid);

        vm.startBroadcast(deployerKey);

        // Create a subscription
        uint64 subId = VRFCoordinatorV2Mock(vrfCoordinator).createSubscription();

        vm.stopBroadcast();

        console.log("Created subscription %s", subId);
        return subId;
    }

    function run() external returns (uint64) {
        return CreateSubscriptionConfig();
    }
}

contract FundSubscription is Script {
    uint96 private constant AMOUNT = 2 ether;

    function FundSubscriptionConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        (
            ,
            ,
            address vrfCoordinator,
            ,
            uint64 subId,
            ,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetwork();
        fund(vrfCoordinator, subId, link, deployerKey);
    }

    function fund(address vrfCoordinator, uint64 subId, address link, uint256 deployerKey) public {
        console.log("Funding Subscription Id number: ", subId);
        console.log("Using vrfCoordinator ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);

        if (block.chainid == 31337) {
            vm.startBroadcast(deployerKey);
            VRFCoordinatorV2Mock(vrfCoordinator).fundSubscription(subId, AMOUNT);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(deployerKey);
            LinkToken(link).transferAndCall(vrfCoordinator, AMOUNT, abi.encode(subId));
            vm.stopBroadcast();
        }
    }

    function run() external {
        FundSubscriptionConfig();
    }
}

contract AddConsumer is Script {
    function AddConsumerConfig(address raffle) public {
        HelperConfig helperConfig = new HelperConfig();
        (, , address vrfCoordinator, , uint64 subId, , , uint256 deployerKey) = helperConfig
            .activeNetwork();
        addConsumer(raffle, vrfCoordinator, subId, deployerKey);
    }

    function addConsumer(
        address raffle,
        address vrfCoordinator,
        uint64 subId,
        uint256 deployerKey
    ) public {
        console.log("Adding consumer to the VRF Coordinator: ", raffle);
        console.log("Using VrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId: ", block.chainid);
        //console.log("Using deployerKey: ", deployerKey);

        vm.startBroadcast(deployerKey);
        VRFCoordinatorV2Mock(vrfCoordinator).addConsumer(subId, raffle);
        vm.stopBroadcast();
    }

    function run() external {
        address raffle = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        AddConsumerConfig(raffle);
    }
}
