// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockV3Aggregator} from "../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../test/mocks/ERC20Mock.sol";
import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    /// @notice Struct to hold network configuration data
    struct NetworkConfig {
        address wethUsdPriceFeed;
        address wbtcUsdPriceFeed;
        address weth;
        address wbtc;
        uint256 deployerKey;
    }

    /// @notice Active network configuration
    NetworkConfig public activeNetworkConfig;

    /// @notice Number of decimals for mock price feeds
    uint8 public constant DECIMALS = 8;
    /// @notice Initial ETH/USD price for mock feeds (2000 USD)
    int256 public constant ETH_USD_PRICE = 2000e8;
    /// @notice Initial BTC/USD price for mock feeds (1000 USD)
    int256 public constant BTC_USD_PRICE = 1000e8;

    /// @notice Default private key for Anvil deployment
    uint256 public constant DEFAULT_ANVIL_PRIVATE_KEY =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    /// @notice Constructor that sets the network configuration based on chain ID
    constructor() {
        if (block.chainid == 11155111) {
            activeNetworkConfig = getSepoliaEthConfig();
        } else {
            activeNetworkConfig = getOrCreateAnvilEthConfig();
        }
    }

    /// @notice Retrieves Sepolia testnet configuration
    /// @return sepoliaNetworkConfig The network configuration with corrected token and price feed addresses
    function getSepoliaEthConfig() public view returns (NetworkConfig memory sepoliaNetworkConfig) {
        sepoliaNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x694AA1769357215DE4FAC081bf1f309aDC325306, // ETH/USD
            wbtcUsdPriceFeed: 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43, // BTC/USD
            weth: 0x7b79995e5f793A07Bc00c21412e50Ecae098E7f9,
            wbtc: 0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063,
            deployerKey: vm.envUint("PRIVATE_KEY")
        });
        // Note: Replace wbtc with a mock ERC20 address if deploying on Sepolia
    }

    /// @notice Creates or retrieves Anvil configuration with mock tokens and price feeds
    /// @return anvilNetworkConfig The network configuration with mock addresses
    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory anvilNetworkConfig) {
        // Return existing config if already set
        if (activeNetworkConfig.wethUsdPriceFeed != address(0)) {
            return activeNetworkConfig;
        }

        // Deploy mock contracts
        vm.startBroadcast();
        MockV3Aggregator ethUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        ERC20Mock wethMock = new ERC20Mock("WETH", "WETH", msg.sender, 1000e8);
        MockV3Aggregator btcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        ERC20Mock wbtcMock = new ERC20Mock("WBTC", "WBTC", msg.sender, 1000e8);
        vm.stopBroadcast();

        anvilNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: address(ethUsdPriceFeed),
            wbtcUsdPriceFeed: address(btcUsdPriceFeed),
            weth: address(wethMock),
            wbtc: address(wbtcMock),
            deployerKey: DEFAULT_ANVIL_PRIVATE_KEY
        });
    }

    /// @notice Retrieves Mainnet configuration (optional, for future use)
    /// @return mainnetNetworkConfig The network configuration for Mainnet
    function getMainnetEthConfig() public pure returns (NetworkConfig memory mainnetNetworkConfig) {
        mainnetNetworkConfig = NetworkConfig({
            wethUsdPriceFeed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419, // ETH/USD
            wbtcUsdPriceFeed: 0xF4030086522a5bEEa4988F8cA5B36dbC97BeE88c, // BTC/USD
            weth: 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2, // WETH
            wbtc: 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599, // WBTC
            deployerKey: 0 // Wil be Set via environment variable for Mainnet
        });
    }
}
