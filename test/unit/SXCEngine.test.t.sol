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

/**
 * @title SXCEngineTest
 * @author Adebakin Olujimi
 * @notice Test suite for the SXCEngine contract, verifying price calculations, collateral management, and edge cases
 * @dev Uses Foundry’s testing framework with mock Chainlink price feeds and ERC20 tokens
 */
contract SXCEngineTest is Test {
    ////////////////
    // State Variables
    ////////////////

    /// @notice Deployer contract for SXCEngine and StableXCoin
    DeploySXCEngine public deployer;
    /// @notice StableXCoin contract instance
    StableXCoin public sxc;
    /// @notice SXCEngine contract instance
    SXCEngine public sxcEngine;
    /// @notice Helper configuration for network-specific settings
    HelperConfig public helperConfig;
    /// @notice Mock Chainlink price feed for ETH/USD
    MockV3Aggregator public mockEthUsdPriceFeed;
    /// @notice Address of the WETH token
    address public weth;
    /// @notice Address of the WBTC token
    address public wbtc;
    /// @notice Address of the ETH/USD price feed
    address public ethUsdPriceFeed;
    /// @notice Address of the BTC/USD price feed
    address public btcUsdPriceFeed;
    /// @notice Test user address
    address public USER = makeAddr("user");
    /// @notice Decimals for Chainlink price feeds (8)
    uint8 public constant DECIMALS = 8;
    /// @notice ETH/USD price (2000 * 10^8 = $2000)
    int256 public constant ETH_USD_PRICE = 2000e8;
    /// @notice Amount of collateral to deposit (10 ETH)
    uint256 public constant AMOUNT_COLLATERAL = 10 ether;
    /// @notice Starting ERC20 balance for users (10 ETH)
    uint256 public constant STARTING_ERC20_BALANCE = 10 ether;
    /// @notice Starting native balance for users (10 ETH)
    uint256 public constant STARTING_BALANCE = 10 ether;
    /// @notice Array of token addresses for constructor tests
    address[] public tokenAddresses;
    /// @notice Array of price feed addresses for constructor tests
    address[] public priceFeedAddresses;

    /**
     * @notice Sets up the test environment by deploying contracts and initializing mocks
     * @dev Deploys SXCEngine, StableXCoin, and mocks; mints tokens for the test user
     */
    function setUp() public {
        deployer = new DeploySXCEngine();
        (sxc, sxcEngine, helperConfig) = deployer.run();
        (ethUsdPriceFeed, btcUsdPriceFeed, weth,,) = helperConfig.activeNetworkConfig();

        wbtc = address(new ERC20Mock("Wrapped Bitcoin", "WBTC", USER, 0));
        console.log("Deployed WBTC Mock at:", wbtc);
        console.log("Deployed SXCEngine at:", address(sxcEngine));
        console.log("Deployed StableXCoin at:", address(sxc));
        console.log("WETH address:", weth);
        console.log("ETH/USD Price Feed address:", ethUsdPriceFeed);
        console.log("BTC/USD Price Feed address:", btcUsdPriceFeed);

        mockEthUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        vm.mockCall(
            address(mockEthUsdPriceFeed),
            abi.encodeWithSelector(AggregatorV3Interface.latestRoundData.selector),
            abi.encode(1, ETH_USD_PRICE, 0, block.timestamp, 1)
        );
        console.log("Mock ETH/USD Price Feed deployed at:", address(mockEthUsdPriceFeed));

        ERC20Mock(weth).mint(USER, STARTING_ERC20_BALANCE);
        ERC20Mock(wbtc).mint(USER, STARTING_BALANCE);
        vm.deal(USER, 10 ether);
    }

    /**
     * @notice Logs debugging information for price and amount calculations
     * @param label A string to identify the context of the logged data
     * @param price The price from the Chainlink price feed
     * @param inputAmount The input amount (USD or token)
     * @param expectedOutput The expected output value
     * @param actualOutput The actual output value
     * @param updatedAt The timestamp of the price feed data
     */
    function logPriceDebugInfo(
        string memory label,
        int256 price,
        uint256 inputAmount,
        uint256 expectedOutput,
        uint256 actualOutput,
        uint256 updatedAt
    ) internal pure {
        console.log("%s", label);
        console.log("Price: %s", uint256(price));
        console.log("Input Amount: %s", inputAmount);
        console.log("Expected Output: %s", expectedOutput);
        console.log("Actual Output: %s", actualOutput);
        console.log("Updated At: %s", updatedAt);
    }

    /////////////////////////
    // Constructor Tests //
    /////////////////////////

    /**
     * @notice Tests that the constructor reverts if token and price feed arrays have different lengths
     */
    function testRevertsIfTokenDoesntMatchPriceFeeds() public {
        tokenAddresses.push(weth);
        priceFeedAddresses.push(ethUsdPriceFeed);
        priceFeedAddresses.push(btcUsdPriceFeed);

        vm.expectRevert(SXCEngine.SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));
    }

    /////////////////////////
    // Price Tests        //
    /////////////////////////

    /**
     * @notice Tests that getUsdValue returns the correct USD value for WETH
     * @dev Uses HelperConfig price feed with ETH_USD_PRICE = 2000e8
     */
    function testGetUsdValue() public view {
        uint256 ethAmount = 15e18; // 15 ETH
        (, int256 price,, uint256 updatedAt,) = AggregatorV3Interface(ethUsdPriceFeed).latestRoundData();
        uint256 expectedUsdValue = (uint256(price) * 1e10 * ethAmount) / 1e18; // 15 ETH * $2000 = $30,000 (18 decimals)
        uint256 actualUsdValue = sxcEngine.getUsdValue(weth, ethAmount);
        logPriceDebugInfo("HelperConfig Feed", price, ethAmount, expectedUsdValue, actualUsdValue, updatedAt);
        assertEq(actualUsdValue, expectedUsdValue, "USD value calculation is incorrect");
    }

    /**
     * @notice Tests that getTokenAmountFromUsd returns the correct WETH amount for a USD value
     * @dev Uses HelperConfig price feed with ETH_USD_PRICE = 2000e8
     */
    function testGetTokenAmountFromUsd() public view {
        uint256 usdAmount = 100 ether; // $100
        (, int256 price,, uint256 updatedAt,) = AggregatorV3Interface(ethUsdPriceFeed).latestRoundData();
        uint256 expectedWeth = (usdAmount * 1e18) / (uint256(price) * 1e10); // $100 / $2000 = 0.05 WETH
        uint256 amountWeth = sxcEngine.getTokenAmountFromUsd(usdAmount, weth);
        logPriceDebugInfo("HelperConfig Feed", price, usdAmount, expectedWeth, amountWeth, updatedAt);
        assertEq(amountWeth, expectedWeth, "Token amount calculation is incorrect");
    }

    /////////////////////////
    // Mock Tests         //
    /////////////////////////

    /**
     * @notice Tests that getUsdValue returns the correct USD value using a mock price feed
     * @dev Deploys a new SXCEngine with mockEthUsdPriceFeed
     */
    function testGetUsdValueWithMock() public {
        address[] memory mockTokenAddresses = new address[](1);
        address[] memory mockPriceFeedAddresses = new address[](1);
        mockTokenAddresses[0] = weth;
        mockPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        SXCEngine mockSxcEngine = new SXCEngine(mockTokenAddresses, mockPriceFeedAddresses, address(sxc));
        console.log("Mock SXCEngine deployed at:", address(mockSxcEngine));

        uint256 ethAmount = 15e18; // 15 ETH
        (, int256 price,, uint256 updatedAt,) = mockEthUsdPriceFeed.latestRoundData();
        uint256 expectedUsdValue = (uint256(price) * 1e10 * ethAmount) / 1e18; // 15 ETH * $2000 = $30,000
        uint256 actualUsdValue = mockSxcEngine.getUsdValue(weth, ethAmount);
        logPriceDebugInfo("Mock Feed", price, ethAmount, expectedUsdValue, actualUsdValue, updatedAt);
        assertEq(actualUsdValue, expectedUsdValue, "USD value calculation with mock is incorrect");
    }

    /**
     * @notice Tests that getTokenAmountFromUsd returns the correct WETH amount using a mock price feed
     * @dev Deploys a new SXCEngine with mockEthUsdPriceFeed
     */
    function testGetTokenAmountFromUsdWithMock() public {
        address[] memory mockTokenAddresses = new address[](1);
        address[] memory mockPriceFeedAddresses = new address[](1);
        mockTokenAddresses[0] = weth;
        mockPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        SXCEngine mockSxcEngine = new SXCEngine(mockTokenAddresses, mockPriceFeedAddresses, address(sxc));

        uint256 usdAmount = 100 ether; // $100
        (, int256 price,, uint256 updatedAt,) = mockEthUsdPriceFeed.latestRoundData();
        uint256 expectedWeth = (usdAmount * 1e18) / (uint256(price) * 1e10); // $100 / $2000 = 0.05 WETH
        uint256 amountWeth = mockSxcEngine.getTokenAmountFromUsd(usdAmount, weth);
        logPriceDebugInfo("Mock Feed", price, usdAmount, expectedWeth, amountWeth, updatedAt);
        assertEq(amountWeth, expectedWeth, "Token amount calculation with mock is incorrect");
    }

    /////////////////////////
    // Edge Case Tests    //
    /////////////////////////

    /**
     * @notice Tests that getTokenAmountFromUsd reverts on arithmetic overflow
     * @dev Uses a maximum USD amount to trigger SXCEngine_ArithmeticOverflow
     */
    function testGetTokenAmountFromUsdRevertsOnOverflow() public {
        address[] memory mockTokenAddresses = new address[](1);
        address[] memory mockPriceFeedAddresses = new address[](1);
        mockTokenAddresses[0] = weth;
        mockPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        SXCEngine mockSxcEngine = new SXCEngine(mockTokenAddresses, mockPriceFeedAddresses, address(sxc));

        uint256 usdAmount = type(uint256).max;
        vm.expectRevert(SXCEngine.SXCEngine_ArithmeticOverflow.selector);
        mockSxcEngine.getTokenAmountFromUsd(usdAmount, weth);
    }

    /**
     * @notice Tests that depositCollateral reverts for an unapproved token
     * @dev Attempts to deposit a non-allowed token (MAN)
     */
    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock manToken = new ERC20Mock("MAN", "MAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        manToken.approve(address(sxcEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(SXCEngine.SXCEngine_NotAllowedToken.selector);
        sxcEngine.depositCollateral(address(manToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }
}
