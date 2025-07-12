// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {DeploySXCEngine} from "../../script/DeploySXCEngine.s.sol";
import {SXCEngine} from "../../src/SXCEngine.sol";
import {StableXCoin} from "../../src/StableXCoin.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

/// @title SXCEngineTest
/// @notice Test suite for the SXCEngine contract
/// @dev Tests price calculations using HelperConfig and MockV3Aggregator
contract SXCEngineTest is Test {
    DeploySXCEngine public deployer;
    StableXCoin public sxc;
    SXCEngine public sxcEngine;
    HelperConfig public helperConfig;
    MockV3Aggregator public mockEthUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public ethUsdPriceFeed;
    address public btcUsdPriceFeed;

    address public USER = makeAddr("user");
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000e8;
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    uint256 public constant STARTING_BALANCE = 10 ether;

    /// @notice Sets up the test environment by deploying contracts
    function setUp() public {
        deployer = new DeploySXCEngine();
        (sxc, sxcEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        // Deploy a fresh ERC20Mock for WBTC to avoid invalid address
        // Deploy a fresh ERC20Mock for WBTC with constructor arguments
        wbtc = address(new ERC20Mock("Wrapped Bitcoin", "WBTC", USER, 0));
        console.log("Deployed WBTC Mock at:", wbtc);

        console.log("Deployed SXCEngine at:", address(sxcEngine));
        console.log("Deployed StableXCoin at:", address(sxc));
        console.log("WETH address:", weth);
        console.log("ETH/USD Price Feed address:", ethUsdPriceFeed);
        console.log("BTC/USD Price Feed address:", btcUsdPriceFeed);

        // Deploy a fresh MockV3Aggregator for direct testing
        mockEthUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        console.log("Mock ETH/USD Price Feed deployed at:", address(mockEthUsdPriceFeed));

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_BALANCE);
        vm.deal(USER, 10 ether);
    }

    /////////////////////////
    /// Constructor Test ////
    ////////////////////////

    

    /// @notice Logs debugging information for price and amount calculations in tests.
    /// @dev Used in Foundry tests to output price, ETH amount, and USD value comparisons to the console.
    /// @param label A string label to identify the context of the logged data.
    /// @param price The price of the asset (in signed integer form, typically from an oracle).
    /// @param ethAmount The amount of ETH involved in the calculation (in wei).
    /// @param expectedUsd The expected USD value of the transaction or calculation.
    /// @param actualUsd The actual USD value calculated, for comparison with the expected value.
    function logPriceDebugInfo(
        string memory label,
        int256 price,
        uint256 ethAmount,
        uint256 expectedUsd,
        uint256 actualUsd
    ) internal pure {
        console.log("%s", label);
        console.log("Price: %s", uint256(price));
        console.log("ETH Amount: %s", ethAmount);
        console.log("Expected USD: %s", expectedUsd);
        console.log("Actual USD: %s", actualUsd);
    }

    /////////////////////////////////
    //////      Price Tests   ///////
    /////////////////////////////////

    /// @notice Tests that getUsdValue returns the correct USD value for WETH using HelperConfig
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15 ETH
        uint256 expectedUsdValue = 30000e18; // 15 ETH * $2000 = $30,000 (18 decimals)

        // Log price feed value for debugging
        (, int256 price,,,) = AggregatorV3Interface(ethUsdPriceFeed).latestRoundData();
        uint256 actualUsdValue = sxcEngine.getUsdValue(weth, ethAmount);
        logPriceDebugInfo("HelperConfig Feed", price, ethAmount, expectedUsdValue, actualUsdValue);

        assertEq(actualUsdValue, expectedUsdValue, "USD value calculation is incorrect");
    }

    /// @notice Tests that getUsdValue returns the correct USD value using a fresh MockV3Aggregator
    function testGetUsdValueWithMock() public {
        // Deploy a new SXCEngine with the mock price feed
        address[] memory tokenAddresses = new address[](1);
        address[] memory priceFeedAddresses = new address[](1);
        tokenAddresses[0] = weth;
        priceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        SXCEngine mockSxcEngine = new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));
        console.log("Mock SXCEngine deployed at:", address(mockSxcEngine));

        uint256 ethAmount = 15e18; // 15 ETH
        uint256 expectedUsdValue = 30000e18; // 15 ETH * $2000 = $30,000 (18 decimals)

        // Log price feed value for debugging
        (, int256 price,,,) = mockEthUsdPriceFeed.latestRoundData();
        uint256 actualUsdValue = mockSxcEngine.getUsdValue(weth, ethAmount);
        logPriceDebugInfo("Mock Feed", price, ethAmount, expectedUsdValue, actualUsdValue);

        assertEq(actualUsdValue, expectedUsdValue, "USD value calculation with mock is incorrect");
    }
}
