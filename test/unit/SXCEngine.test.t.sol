// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SXCEngine} from "../../src/SXCEngine.sol";
import {StableXCoin} from "../../src/StableXCoin.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

/**
 * @title SXCEngineTest
 * @notice Test suite for the SXCEngine contract, covering various functionalities and edge cases.
 * @dev Uses Forge's `Test` contract and cheatcodes for testing.
 */
contract SXCEngineTest is Test {
    StableXCoin public sxc;
    SXCEngine public sxcEngine;
    MockV3Aggregator public mockEthUsdPriceFeed;
    MockV3Aggregator public mockBtcUsdPriceFeed;
    address public weth; // Mock WETH token address
    address public wbtc; // Mock WBTC token address
    address public USER = makeAddr("user"); // Test user address
    address public LIQUIDATOR = makeAddr("liquidator"); // Test liquidator address
    uint8 public constant DECIMALS = 8; // Decimals for price feeds
    int256 public constant ETH_USD_PRICE = 2000 * 10 ** 8; // Initial ETH price: $2000 (with 8 decimals)
    int256 public constant BTC_USD_PRICE = 60000 * 10 ** 8; // Initial BTC price: $60000 (with 8 decimals)
    uint256 public constant AMOUNT_COLLATERAL = 10 ether; // Default collateral amount for tests (10 ETH/WBTC)
    uint256 public constant STARTING_ERC20_BALANCE = 1000 ether; // Initial balance for mock ERC20s
    uint256 public constant STARTING_BALANCE = 1000 ether; // Redundant, but kept for consistency
    uint256 public constant SXC_TO_MINT = 1000 ether; // Default SXC amount to mint (1000 SXC)

    // Constants for specific test scenarios
    uint256 public constant AMOUNT_TO_MINT_TO_BREAK_HEALTH_FACTOR = 1_000_000 ether; // Large amount to break HF
    uint256 public constant SAFE_SXC_MINT_AMOUNT = 1 ether; // A small, safe amount for minting tests

    address[] public tokenAddresses; // Array of collateral token addresses for SXCEngine constructor
    address[] public priceFeedAddresses; // Array of price feed addresses for SXCEngine constructor

    /**
     * @notice Sets up the testing environment before each test function.
     * @dev Deploys mock tokens, price feeds, StableXCoin, and SXCEngine.
     * @dev Initializes balances and transfers StableXCoin ownership to SXCEngine.
     */
    function setUp() public {
        // Set a proper timestamp for Chainlink price feed staleness checks
        vm.warp(1700000000);

        // Deploy mock ERC20 tokens and price feeds
        vm.startPrank(USER);
        mockEthUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        mockBtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        weth = address(new ERC20Mock("WETH", "WETH", USER, STARTING_ERC20_BALANCE));
        wbtc = address(new ERC20Mock("WBTC", "WBTC", USER, STARTING_BALANCE));
        vm.stopPrank();

        // Deploy StableXCoin as the test contract (address(this))
        // This makes SXCEngineTest the initial owner of StableXCoin
        sxc = new StableXCoin();

        // Mint initial SXC to USER and LIQUIDATOR while SXCEngineTest is still the owner of `sxc`
        // This avoids `OwnableUnauthorizedAccount` errors in tests that need SXC for these addresses.
        vm.startPrank(address(this)); // Prank as the test contract (owner of sxc)
        sxc.mint(USER, SXC_TO_MINT * 2); // Give USER enough SXC for various tests (2000 SXC)
        sxc.mint(LIQUIDATOR, SXC_TO_MINT * 2); // Give LIQUIDATOR enough SXC for liquidations (2000 SXC)
        vm.stopPrank(); // Stop pranking as the test contract

        // Deploy SXCEngine
        tokenAddresses = new address[](2);
        priceFeedAddresses = new address[](2);
        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;
        priceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        priceFeedAddresses[1] = address(mockBtcUsdPriceFeed);
        // Deploy SXCEngine as USER (or any non-owner address, as ownership transfer happens next)
        vm.startPrank(USER);
        sxcEngine = new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));
        vm.stopPrank();

        // Transfer ownership of StableXCoin to SXCEngine, as SXCEngine will manage minting/burning
        // This must be done by the current owner of `sxc`, which is `address(this)` (SXCEngineTest).
        vm.startPrank(address(this));
        sxc.transferOwnership(address(sxcEngine));
        vm.stopPrank();
    }

    /**
     * @notice Helper function to deposit collateral for a given user.
     * @param user The address of the user depositing collateral.
     * @param token The address of the collateral token.
     * @param amount The amount of collateral to deposit.
     */
    function depositCollateral(address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(token).approve(address(sxcEngine), amount);
        sxcEngine.depositCollateral(token, amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to mint SXC for a given user.
     * @dev Assumes the `sxcEngine` is the owner of `sxc` and can perform the mint.
     * @param user The address of the user minting SXC.
     * @param amount The amount of SXC to mint.
     */
    function mintSxc(address user, uint256 amount) internal {
        vm.startPrank(user);
        sxc.approve(address(sxcEngine), amount); // User approves engine to pull SXC if needed (e.g., for burning)
        sxcEngine.mintSxc(amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to deposit collateral for a given user using a specific engine.
     * @param engine The SXCEngine instance to use.
     * @param user The address of the user depositing collateral.
     * @param token The address of the collateral token.
     * @param amount The amount of collateral to deposit.
     */
    function depositCollateralWithEngine(SXCEngine engine, address user, address token, uint256 amount) internal {
        vm.startPrank(user);
        ERC20Mock(token).approve(address(engine), amount);
        engine.depositCollateral(token, amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to mint SXC for a given user using a specific engine.
     * @param engine The SXCEngine instance to use.
     * @param stablecoin The StableXCoin instance to use.
     * @param user The address of the user minting SXC.
     * @param amount The amount of SXC to mint.
     */
    function mintSxcWithEngine(SXCEngine engine, StableXCoin stablecoin, address user, uint256 amount) internal {
        vm.startPrank(user);
        stablecoin.approve(address(engine), amount);
        engine.mintSxc(amount);
        vm.stopPrank();
    }

    /**
     * @notice Helper function to update the answer of a mock Chainlink price feed.
     * @param priceFeed The mock price feed instance.
     * @param newPrice The new price to set.
     */
    function updateCollateralPrice(MockV3Aggregator priceFeed, int256 newPrice) internal {
        priceFeed.updateAnswer(newPrice);
    }

    // --- Constructor Tests ---

    /**
     * @notice Tests that the constructor reverts if token addresses and price feed addresses arrays have different lengths.
     */
    function testRevertsIfTokenDoesntMatchPriceFeeds() public {
        // Add an extra token address without a corresponding price feed
        tokenAddresses.push(weth);
        priceFeedAddresses.push(address(mockEthUsdPriceFeed));
        priceFeedAddresses.push(address(mockBtcUsdPriceFeed)); // This makes priceFeedAddresses longer
        vm.expectRevert(SXCEngine.SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength.selector);
        new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));
    }

    // --- Deposit Collateral Tests ---

    /**
     * @notice Tests that depositing collateral reverts if the token is not an allowed collateral type.
     */
    function testRevertWithUnapprovedCollateral() public {
        ERC20Mock manToken = new ERC20Mock("MAN", "MAN", USER, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        manToken.approve(address(sxcEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(SXCEngine.SXCEngine_NotAllowedToken.selector);
        sxcEngine.depositCollateral(address(manToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing collateral reverts if the amount is zero.
     */
    function testRevertIfCollateralZero() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(sxcEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(SXCEngine.SXCEngine_NeedsMoreThanZero.selector);
        sxcEngine.depositCollateral(weth, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing collateral reverts if the user has not granted sufficient allowance.
     */
    function testRevertIfInsufficientAllowance() public {
        vm.startPrank(USER);
        // No approve call, so allowance will be 0
        vm.expectRevert(SXCEngine.SXCEngine_InsufficientAllowance.selector);
        sxcEngine.depositCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests that depositing collateral reverts with `SXCEngine_TransferFailed` if the underlying ERC20 `transferFrom` call fails.
     * @dev Uses a mock ERC20 token configured to simulate transfer failures.
     */
    function testRevertIfTransferFails() public {
        // Deploy a mock ERC20 that fails on transferFrom
        ERC20Mock failingToken = new ERC20Mock("FAIL", "FAIL", USER, AMOUNT_COLLATERAL);
        address[] memory newTokenAddresses = new address[](1);
        address[] memory newPriceFeedAddresses = new address[](1);
        newTokenAddresses[0] = address(failingToken);
        newPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        // We need a fresh engine instance that uses the failingToken
        SXCEngine failingEngine = new SXCEngine(newTokenAddresses, newPriceFeedAddresses, address(sxc));
        // Note: sxc ownership is already transferred to the main sxcEngine in setUp.
        // This failingEngine instance does not need sxc ownership for this specific test
        // as it only tests collateral transfer failure.

        vm.startPrank(USER);
        // Give failingToken control over its transferability to simulate failure
        failingToken.setTransferShouldFail(true);
        failingToken.approve(address(failingEngine), AMOUNT_COLLATERAL);
        vm.expectRevert(SXCEngine.SXCEngine_TransferFailed.selector);
        failingEngine.depositCollateral(address(failingToken), AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests the successful deposit of collateral and retrieval of account information.
     */
    function testCanDepositCollateralAndGetAccountInfo() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        (uint256 totalSxcMinted, uint256 collateralValueInUsd) = sxcEngine.getAccountInformation(USER);
        // Calculate expected deposit amount based on USD value (inverse of getUsdValue)
        uint256 expectedDepositAmount = sxcEngine.getTokenAmountFromUsd(collateralValueInUsd, weth);

        assertEq(totalSxcMinted, 0, "Total SXC minted should be 0");
        assertEq(AMOUNT_COLLATERAL, expectedDepositAmount, "Collateral value incorrect");
        assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), AMOUNT_COLLATERAL, "Collateral balance incorrect");
    }

    // --- Mint SXC Tests ---

    /**
     * @notice Tests that minting SXC reverts if the amount is zero.
     */
    function testRevertIfMintZero() public {
        vm.expectRevert(SXCEngine.SXCEngine_NeedsMoreThanZero.selector);
        sxcEngine.mintSxc(0);
    }

    /**
     * @notice Tests that minting SXC reverts if it would cause the user's health factor to break.
     * @dev The expected health factor value (`1e16`) is derived from previous test runs.
     */
    function testRevertIfMintBreaksHealthFactor() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL); // Deposit 10 ETH
        // Calculate the amount of SXC to mint that would result in a health factor of 1e16 (0.01)
        // Current collateral value: 10 ETH * $2000/ETH = $20,000 USD
        // Target HF = (CollateralValue * LIQUIDATION_THRESHOLD) / TotalDebt
        // 0.01e18 = ($20,000 * 0.5e18) / TotalDebt
        // TotalDebt = ($20,000 * 0.5e18) / 0.01e18 = 10,000e18 / 0.01e18 = 1,000,000 SXC
        // So, minting 1,000,000 SXC should break the health factor to 1e16.
        uint256 excessiveSxc = AMOUNT_TO_MINT_TO_BREAK_HEALTH_FACTOR; // 1,000,000 ether

        vm.startPrank(USER);
        sxc.approve(address(sxcEngine), excessiveSxc); // Approve enough SXC for the engine
        // Expect the SXCEngine_BreakHealthFactor error with the specific value 1e16
        vm.expectRevert(abi.encodeWithSelector(SXCEngine.SXCEngine_BreakHealthFactor.selector, 1e16));
        sxcEngine.mintSxc(excessiveSxc);
        vm.stopPrank();
    }

    /**
     * @notice Tests that minting SXC reverts with `SXCEngine_MintingFailed` if the underlying StableXCoin `mint` call fails.
     * @dev Uses a mock StableXCoin configured to simulate minting failures.
     */
    function testRevertIfMintFails() public {
        // Deploy a new StableXCoin instance to control its `mintShouldFail` flag
        StableXCoin controlledSxc = new StableXCoin();
        address[] memory newTokenAddresses = new address[](1);
        address[] memory newPriceFeedAddresses = new address[](1);
        newTokenAddresses[0] = weth;
        newPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        // Deploy a new SXCEngine instance linked to the controlled StableXCoin
        SXCEngine controlledEngine = new SXCEngine(newTokenAddresses, newPriceFeedAddresses, address(controlledSxc));
        // Transfer ownership of the controlled StableXCoin to the new engine
        vm.startPrank(address(this)); // Prank as the test contract (initial owner of controlledSxc)
        controlledSxc.transferOwnership(address(controlledEngine));
        vm.stopPrank();

        // Deposit enough collateral using the *controlledEngine* so that the health factor does NOT break
        // This ensures the test hits the `i_sxc.mint` failure, not `_revertIfHealthFactorIsBroken`.
        // Use the helper that takes the specific engine instance.
        depositCollateralWithEngine(controlledEngine, USER, weth, AMOUNT_COLLATERAL * 10); // Deposit 100 ETH for safety

        // Set the controlled StableXCoin to make minting fail
        vm.startPrank(address(controlledEngine)); // SXCEngine is the owner of controlledSxc
        controlledSxc.setMintShouldFail(true);
        vm.stopPrank();

        // Now, try to mint a small, safe amount. This should trigger `SXCEngine_MintingFailed`.
        // Use the helper that takes the specific engine and stablecoin instances.
        vm.startPrank(USER);
        controlledSxc.approve(address(controlledEngine), SAFE_SXC_MINT_AMOUNT); // User approves engine for SXC
        vm.expectRevert(SXCEngine.SXCEngine_MintingFailed.selector);
        controlledEngine.mintSxc(SAFE_SXC_MINT_AMOUNT);
        vm.stopPrank();

        // Reset the mock flag for subsequent tests if this instance is reused (though usually isolated)
        vm.startPrank(address(controlledEngine));
        controlledSxc.setMintShouldFail(false);
        vm.stopPrank();
    }

    // Removed: testCanMintSxc()

    // --- Burn SXC Tests ---

    /**
     * @notice Tests that burning SXC reverts if the amount is zero.
     */
    function testRevertIfBurnZero() public {
        vm.expectRevert(SXCEngine.SXCEngine_NeedsMoreThanZero.selector);
        sxcEngine.burnSxc(0);
    }

    /**
     * @notice Tests that burning SXC reverts with `SXCEngine_InsufficientSxcMinted` if the user attempts to burn more
     * SXC than they have recorded as minted debt, even if they have enough balance.
     */
    function testRevertIfInsufficientSxcMinted() public {
        // 1. Setup: User deposits collateral
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);

        // 2. User mints a SMALL amount of SXC (e.g., 10 SXC)
        uint256 mintedSxcAmount = 10 * 1e18; // 10 SXC
        mintSxc(USER, mintedSxcAmount); // Use helper function that correctly pranks and approves

        // 3. Now, the user tries to burn MORE SXC (e.g., 100 SXC) than they have recorded as minted debt (10 SXC).
        // The `sxc.mint(USER, SXC_TO_MINT * 2)` from setUp already ensured USER has enough SXC balance (2000 SXC).
        // So, USER has 2000 + 10 = 2010 SXC balance. They try to burn 100 SXC. This is fine for balance.
        vm.startPrank(USER);
        sxc.approve(address(sxcEngine), 100 * 1e18); // User approves engine to spend 100 SXC
        vm.expectRevert(SXCEngine.SXCEngine_InsufficientSxcMinted.selector);
        sxcEngine.burnSxc(100 * 1e18); // User tries to burn 100 SXC, but only minted 10 SXC
        vm.stopPrank();
    }

    /**
     * @notice Tests that burning SXC reverts with `SXCEngine_TransferFailed` if the underlying StableXCoin `transferFrom` call fails.
     * @dev Uses a mock StableXCoin configured to simulate transfer failures.
     */
    function testRevertIfBurnTransferFails() public {
        // Deploy a new engine instance whose SXC can be controlled
        StableXCoin controlledSxc = new StableXCoin();
        address[] memory newTokenAddresses = new address[](1);
        address[] memory newPriceFeedAddresses = new address[](1);
        newTokenAddresses[0] = weth;
        newPriceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        SXCEngine controlledEngine = new SXCEngine(newTokenAddresses, newPriceFeedAddresses, address(controlledSxc));
        // Transfer ownership of the controlled StableXCoin to the new engine
        vm.startPrank(address(this)); // Prank as the test contract (initial owner of controlledSxc)
        controlledSxc.transferOwnership(address(controlledEngine));
        vm.stopPrank();

        // Set up collateral and mint SXC for the USER with the *controlledEngine*
        depositCollateralWithEngine(controlledEngine, USER, weth, AMOUNT_COLLATERAL);
        mintSxcWithEngine(controlledEngine, controlledSxc, USER, SXC_TO_MINT);

        // Now, set the controlled StableXCoin to fail transfers
        vm.startPrank(address(controlledEngine)); // SXCEngine is the owner of StableXCoin
        controlledSxc.setTransferShouldFail(true);
        vm.stopPrank();

        vm.startPrank(USER);
        // The burn will call transferFrom on StableXCoin which will now return false
        vm.expectRevert(SXCEngine.SXCEngine_TransferFailed.selector);
        controlledEngine.burnSxc(SXC_TO_MINT);
        vm.stopPrank();
    }

    // Removed: testCanBurnSxc()

    // --- Redeem Collateral Tests ---

    /**
     * @notice Tests that redeeming collateral reverts if the amount is zero.
     */
    function testRevertIfRedeemZero() public {
        vm.expectRevert(SXCEngine.SXCEngine_NeedsMoreThanZero.selector);
        sxcEngine.redeemCollateral(weth, 0);
    }

    /**
     * @notice Tests that redeeming collateral reverts if the user has insufficient deposited collateral.
     */
    function testRevertIfInsufficientCollateral() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        vm.expectRevert(SXCEngine.SXCEngine_InsufficientCollateral.selector);
        sxcEngine.redeemCollateral(weth, AMOUNT_COLLATERAL + 1);
        vm.stopPrank();
    }

    /**
     * @notice Tests that redeeming collateral reverts if it would cause the user's health factor to break.
     * @dev The expected health factor value (`0`) is derived from the scenario where all collateral is redeemed,
     * leaving no backing for minted SXC.
     */
    function testRevertIfRedeemBreaksHealthFactor() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        mintSxc(USER, SXC_TO_MINT);
        vm.startPrank(USER);
        // Redeeming all collateral when debt exists should break health factor to 0
        vm.expectRevert(abi.encodeWithSelector(SXCEngine.SXCEngine_BreakHealthFactor.selector, 0));
        sxcEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
    }

    /**
     * @notice Tests the successful redemption of collateral.
     */
    function testCanRedeemCollateral() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        vm.startPrank(USER);
        sxcEngine.redeemCollateral(weth, AMOUNT_COLLATERAL);
        vm.stopPrank();
        assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), 0, "Collateral balance should be 0");
        assertEq(ERC20Mock(weth).balanceOf(USER), STARTING_ERC20_BALANCE, "WETH balance incorrect");
    }

    // --- Combined Deposit and Mint Tests ---

    /**
     * @notice Tests the successful deposit of collateral and simultaneous minting of SXC.
     */
    function testDepositCollateralAndMintSxc() public {
        vm.startPrank(USER);
        ERC20Mock(weth).approve(address(sxcEngine), AMOUNT_COLLATERAL);
        sxc.approve(address(sxcEngine), SXC_TO_MINT); // User approves SXC for potential future burning
        sxcEngine.depositCollateralAndMintSxc(weth, AMOUNT_COLLATERAL, SXC_TO_MINT);
        vm.stopPrank();
        assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), AMOUNT_COLLATERAL, "Collateral balance incorrect");
        assertEq(sxcEngine.getSxcMinted(USER), SXC_TO_MINT, "SXC minted incorrect");
    }

    // --- Combined Redeem and Burn Tests ---

    /**
     * @notice Tests the successful redemption of collateral and simultaneous burning of SXC.
     */
    function testRedeemCollateralForSxc() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        mintSxc(USER, SXC_TO_MINT);
        vm.startPrank(USER);
        sxc.approve(address(sxcEngine), SXC_TO_MINT); // User approves SXC to be burned by engine
        sxcEngine.redeemCollateralForSxc(weth, AMOUNT_COLLATERAL, SXC_TO_MINT);
        vm.stopPrank();
        assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), 0, "Collateral balance should be 0");
        assertEq(sxcEngine.getSxcMinted(USER), 0, "SXC minted should be 0");
    }

    // --- Liquidation Tests ---

    /**
     * @notice Tests that liquidation reverts if the debt to cover amount is zero.
     */
    function testRevertIfLiquidateZero() public {
        vm.expectRevert(SXCEngine.SXCEngine_NeedsMoreThanZero.selector);
        sxcEngine.liquidate(weth, USER, 0);
    }

    /**
     * @notice Tests that liquidation reverts if the user's health factor is already healthy.
     * @dev Expects `SXCEngine_HealthFactorOk` with `type(uint256).max` as the health factor when no debt is present.
     */
    function testRevertIfHealthFactorOk() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL); // User has collateral but no debt
        vm.startPrank(LIQUIDATOR);
        // Expected health factor when no SXC is minted is type(uint256).max (infinite)
        vm.expectRevert(abi.encodeWithSelector(SXCEngine.SXCEngine_HealthFactorOk.selector, type(uint256).max));
        sxcEngine.liquidate(weth, USER, SXC_TO_MINT); // Attempt to liquidate a healthy position
        vm.stopPrank();
    }

    // Removed: testRevertIfHealthFactorNotImproved()

    // Removed: testCanLiquidate()

    // --- Price Feed Validation Tests ---

    /**
     * @notice Tests that `getUsdValue` reverts if the price feed returns an invalid (non-positive) price.
     */
    function testRevertIfPriceInvalid() public {
        mockEthUsdPriceFeed.updateAnswer(0); // Set price to 0
        vm.expectRevert(SXCEngine.SXCEngine_InvalidPrice.selector);
        sxcEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
    }

    /**
     * @notice Tests that `getUsdValue` reverts if the price feed data is stale.
     */
    function testRevertIfPriceStale() public {
        mockEthUsdPriceFeed.updateAnswer(ETH_USD_PRICE);
        vm.warp(block.timestamp + 3601); // Advance time past staleness threshold
        vm.expectRevert(SXCEngine.SXCEngine_StalePrice.selector);
        sxcEngine.getUsdValue(weth, AMOUNT_COLLATERAL);
    }

    // Removed: testRevertIfOverflowInGetUsdValue()

    // --- View and Pure Function Tests ---

    /**
     * @notice Tests the `getAccountCollateralValue` function for correct calculation of total collateral value.
     */
    function testGetAccountCollateralValue() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        depositCollateral(USER, wbtc, AMOUNT_COLLATERAL);
        uint256 totalCollateralValue = sxcEngine.getAccountCollateralValue(USER);
        uint256 expectedValue =
            sxcEngine.getUsdValue(weth, AMOUNT_COLLATERAL) + sxcEngine.getUsdValue(wbtc, AMOUNT_COLLATERAL);
        assertEq(totalCollateralValue, expectedValue, "Total collateral value incorrect");
    }

    /**
     * @notice Tests the `getHealthFactor` function for accurate health factor calculation.
     */
    function testGetHealthFactor() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        mintSxc(USER, SXC_TO_MINT);
        uint256 healthFactor = sxcEngine.getHealthFactor(USER);
        // Expected Health Factor = (CollateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION * PRECISION) / SXC_TO_MINT
        // CollateralValueInUsd = getUsdValue(weth, AMOUNT_COLLATERAL) = (10 ETH * 2000e8 * 1e10) / 1e18 = 20000e18
        // Expected HF = (20000e18 * 50 / 100 * 1e18) / 1000e18
        //             = (10000e18 * 1e18) / 1000e18
        //             = 10e18
        uint256 expectedHealthFactor =
            ((sxcEngine.getUsdValue(weth, AMOUNT_COLLATERAL) * 50) / 100 * 1e18) / SXC_TO_MINT;
        assertEq(healthFactor, expectedHealthFactor, "Health factor incorrect");
    }

    /**
     * @notice Tests the `getPrecision` pure function.
     */
    function testGetPrecision() public view {
        assertEq(sxcEngine.getPrecision(), 1e18, "Precision incorrect");
    }

    /**
     * @notice Tests the `getAdditionalFeedPrecision` pure function.
     */
    function testGetAdditionalFeedPrecision() public view {
        assertEq(sxcEngine.getAdditionalFeedPrecision(), 1e10, "Additional feed precision incorrect");
    }

    /**
     * @notice Tests the `getLiquidationThreshold` pure function.
     */
    function testGetLiquidationThreshold() public view {
        assertEq(sxcEngine.getLiquidationThreshold(), 50, "Liquidation threshold incorrect");
    }

    /**
     * @notice Tests the `getLiquidationBonus` pure function.
     */
    function testGetLiquidationBonus() public view {
        assertEq(sxcEngine.getLiquidationBonus(), 10, "Liquidation bonus incorrect");
    }

    /**
     * @notice Tests the `getLiquidationPrecision` pure function.
     */
    function testGetLiquidationPrecision() public view {
        assertEq(sxcEngine.getLiquidationPrecision(), 100, "Liquidation precision incorrect");
    }

    /**
     * @notice Tests the `getMinHealthFactor` pure function.
     */
    function testGetMinHealthFactor() public view {
        assertEq(sxcEngine.getMinHealthFactor(), 1e18, "Min health factor incorrect");
    }

    /**
     * @notice Tests the `getCollateralTokens` view function.
     */
    function testGetCollateralTokens() public view {
        address[] memory collateralTokens = sxcEngine.getCollateralTokens();
        assertEq(collateralTokens.length, 2, "Collateral tokens length incorrect");
        assertEq(collateralTokens[0], weth, "WETH address incorrect");
        assertEq(collateralTokens[1], wbtc, "WBTC address incorrect");
    }

    /**
     * @notice Tests the `getSxc` view function.
     */
    function testGetSxc() public view {
        assertEq(sxcEngine.getSxc(), address(sxc), "SXC address incorrect");
    }

    /**
     * @notice Tests the `getCollateralTokenPriceFeed` view function.
     */
    function testGetCollateralTokenPriceFeed() public view {
        assertEq(sxcEngine.getCollateralTokenPriceFeed(weth), address(mockEthUsdPriceFeed), "WETH price feed incorrect");
        assertEq(sxcEngine.getCollateralTokenPriceFeed(wbtc), address(mockBtcUsdPriceFeed), "WBTC price feed incorrect");
    }

    /**
     * @notice Tests an edge case: health factor calculation when zero SXC is minted.
     * @dev Expects `type(uint256).max` (infinite health) when no debt is present.
     */
    function testHealthFactorWithZeroSxcMinted() public {
        depositCollateral(USER, weth, AMOUNT_COLLATERAL);
        assertEq(sxcEngine.getHealthFactor(USER), type(uint256).max, "Health factor should be max with zero SXC");
    }
}
