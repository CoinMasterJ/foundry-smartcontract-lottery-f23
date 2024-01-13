///SPDX-License-Identifier:MIT

pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2Mock} from "@chainlink/contracts/src/v0.8/mocks/VRFCoordinatorV2Mock.sol";
import {LinkToken} from "../test/Mocks/LinkToken.sol";

contract HelperConfig is Script {
    NetworkConfig public activeNetworkConfig;
    
    struct NetworkConfig {
        uint256 enteranceFee;
        uint256 interval; 
        address vrfCoordinator; 
        bytes32 keyHash;
        uint64 subscriptionId;
        uint32 callbackGasLimit;
        address link;
        uint256 deployerKey;
    }
    
    uint256 public constant ANVIL_PRIVATE_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;

    constructor() {
        if (block.chainid == 43113) {
            activeNetworkConfig = getAvaxFujiConfig();
        }else{
            activeNetworkConfig  = getorCreateAnvilEthConfig();
        }
    }
    function getAvaxFujiConfig ()public view returns(NetworkConfig memory) {
        return NetworkConfig({
            enteranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: 0x2eD832Ba664535e5886b75D64C46EB9a228C2610,
            keyHash: 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61,
            subscriptionId: 891,//Update this with our SubId
            callbackGasLimit: 500000, 
            link: 0x0b9d5D9136855f6FEc3c0993feE6E9CE8a297846, 
            deployerKey: vm.envUint("PRIVATE_KEY")


        });
    }
    function getorCreateAnvilEthConfig() public returns(NetworkConfig memory){
        if (activeNetworkConfig.vrfCoordinator != address(0)){
            return activeNetworkConfig;
        }
        uint96 baseFee = 0.25 ether; // .25 Link
        uint96 gasPriceLink = 1e9; //1 gwei in Link

        vm.startBroadcast(ANVIL_PRIVATE_KEY);
        VRFCoordinatorV2Mock vrfCoordinatorV2Mock = new VRFCoordinatorV2Mock (
            baseFee, 
            gasPriceLink
        );
        LinkToken link = new LinkToken();
        
        vm.stopBroadcast();
        return NetworkConfig({
            enteranceFee: 0.01 ether,
            interval: 30,
            vrfCoordinator: address(vrfCoordinatorV2Mock),
            keyHash: 0x354d2f95da55398f44b7cff77da56283d9c6c829a4bdf1bbcaf2ad6a4d081f61,
            subscriptionId: 0,//Script will add this value
            callbackGasLimit: 500000,
            link: address(link),
            deployerKey: ANVIL_PRIVATE_KEY
            
        });
    }
}