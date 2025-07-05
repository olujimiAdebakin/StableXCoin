// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Script} from "forge-std/Script.sol";
import {SXCEngine} from "../src/SXCEngine.sol";
import {StableXCoin} from "../src/StableXCoin.sol";
import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

/// @title DeploySXCEngine
/// @notice A script to deploy the StableXCoin and SXCEngine contracts with network-specific configurations
/// @dev Uses Foundry's Script contract to handle deployment and ownership transfer
contract DeploySXCEngine is Script {
    /// @notice Arrays to store collateral token and price feed addresses
    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    /// @notice Deploys the StableXCoin and SXCEngine contracts
    /// @dev Configures SXCEngine with collateral tokens and price feeds from HelperConfig
    /// @return sxc The deployed StableXCoin contract instance
    /// @return sxc_engine The deployed SXCEngine contract instance
    /// @return helperConfig The HelperConfig instance with network configuration
    function run() external returns (StableXCoin, SXCEngine, HelperConfig) {
        // Instantiate HelperConfig to retrieve network-specific addresses
        HelperConfig helperConfig = new HelperConfig();

        // Retrieve network configuration (price feeds, tokens, and deployer key)
        (address wethUsdPriceFeed, address wbtcUsdPriceFeed, address weth, address wbtc, uint256 deployerKey) =
            helperConfig.activeNetworkConfig();

        // Populate arrays for SXCEngine constructor
        tokenAddresses = [weth, wbtc];
        priceFeedAddresses = [wethUsdPriceFeed, wbtcUsdPriceFeed];

        // Start broadcasting transactions using the deployer key
        vm.startBroadcast(deployerKey);

        // Deploy the StableXCoin contract
        // This is the ERC20 implementation of the stablecoin system
        // It is governed by SXCEngine
        // Collateral: Exogenous (ETH & BTC)
        // Minting: Algorithmic
        // Relative Stability: Pegged to USD
        StableXCoin sxc = new StableXCoin();

        // Deploy the SXCEngine contract with token addresses, price feeds, and SXC address
        SXCEngine sxc_engine = new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));

        // Transfer ownership of StableXCoin to SXCEngine to allow minting and burning
        sxc.transferOwnership(address(sxc_engine));

        // Note: The following line is commented out as SXCEngine does not inherit Ownable
        // Transfer ownership of the SXCEngine to the deployer
        // sxc_engine.transferOwnership(deployerKey);

        // Stop broadcasting transactions
        vm.stopBroadcast();

        // Return the deployed contract instances and HelperConfig
        return (sxc, sxc_engine, helperConfig);
    }
}
