// SPDX-License-Identifier:MIT

pragma solidity ^0.8.17;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/Raffle.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {CreateSubscription, FundSubscription, AddConsumer} from "./Interactions.s.sol";

contract DeployLottery is Script {
    function run() external returns (Raffle, HelperConfig) {
        // code outside vm.broadcast is not runned. it is simulated
        HelperConfig helperConfig = new HelperConfig();

        // For price feed ETH/USD
        //address ethToUsd = helperConfig.activeNetwork();

        //constructor lottery
        (
            uint256 entranceFee,
            uint256 interval,
            //uint256 lastTimeStamp,
            address vrfCoordinator,
            bytes32 gaslane,
            uint64 subscriptionId,
            uint32 callbackGasLimit,
            address link,
            uint256 deployerKey
        ) = helperConfig.activeNetwork();

        if (subscriptionId == 0) {
            CreateSubscription createSubscription = new CreateSubscription();
            subscriptionId = createSubscription.createSubscription(vrfCoordinator, deployerKey);

            FundSubscription fundSubscription = new FundSubscription();
            fundSubscription.fund(vrfCoordinator, subscriptionId, link, deployerKey);
        }
        vm.startBroadcast();

        Raffle raffle = new Raffle(
            entranceFee,
            interval,
            vrfCoordinator,
            gaslane,
            subscriptionId,
            callbackGasLimit
        );

        vm.stopBroadcast();
        AddConsumer addConsumer = new AddConsumer();
        addConsumer.addConsumer(address(raffle), vrfCoordinator, subscriptionId, deployerKey);
        return (raffle, helperConfig);
    }
}
