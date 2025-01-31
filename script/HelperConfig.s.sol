// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/linktoken.sol";

abstract contract CodeConstants {
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant LOCAL_CHAIN_ID = 31337;    
    
}


contract helperConfig is Script,CodeConstants{
    /**VRF mock constants */
    uint96 public MOCK_BASEFEE = 0.25 ether;
    uint96 public MOCK_GAS_PRICE_Link = 1e9;
    int256 public MOCK_WEI_PER_UINT_LINK = 4e15;
    
    error INVALID_ChainId();    
    struct  NetworkConfig {
        uint256 enterancefee;
        uint256 interval;
        address vrfCoordinator;
        bytes32 gaslane;
        uint256 subscriptionId;
        uint32 callbackgaslimit;
        address link;
        address account;
        
    }

    NetworkConfig public localNetworkConfig;
    mapping (uint256 chainid =>NetworkConfig )public networkConfig;
    constructor(){
        networkConfig[ETH_SEPOLIA_CHAIN_ID] = getSepliaETHConfig();

    
    }

    function getConfigByChainId(uint256 chainid) public returns(NetworkConfig memory){
        if(networkConfig[chainid].vrfCoordinator != address(0)){
            return networkConfig[chainid];
        }else if (chainid == LOCAL_CHAIN_ID){
            return GetOrCreateAnvilEThConfig();

        }else{
            revert INVALID_ChainId();
        }
    }

    function getConfig() public returns(NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }


    function getSepliaETHConfig() public pure returns(NetworkConfig memory){
        return NetworkConfig({
            enterancefee: 0.01 ether,
            interval: 30, //30 sec
            vrfCoordinator: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
            callbackgaslimit: 500000,
            subscriptionId: 0,
            link: 0x779877A7B0D9E8603169DdbD7836e478b4624789,
            account: 0xf91879dB3681e26aDE8bfe9e8BD272496e91f43a

        });
    }

    function GetOrCreateAnvilEThConfig() public returns(NetworkConfig memory){
        if(localNetworkConfig.vrfCoordinator != address(0)){
            return localNetworkConfig;
        }

    //deploy mocks
    vm.startBroadcast();
    VRFCoordinatorV2_5Mock vrfCoordinatorMock = new VRFCoordinatorV2_5Mock(MOCK_BASEFEE,MOCK_GAS_PRICE_Link,MOCK_WEI_PER_UINT_LINK);
    LinkToken linkToken = new LinkToken();
    vm.stopBroadcast();

    localNetworkConfig = NetworkConfig({
        enterancefee: 0.01 ether,
        interval: 30, //30 sec
        vrfCoordinator: address(vrfCoordinatorMock),
        // doesnt matter
        gaslane: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae,
        callbackgaslimit: 500000,
        subscriptionId: 0,
        link: address(linkToken),
        account: 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38
    });
    return localNetworkConfig;



    }







}