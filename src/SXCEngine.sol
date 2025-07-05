// SPDX-License-Identifier: MIT

// This is considered an Exogenous, Decentralized, Anchored (pegged), Crypto Collateralized low volatility coin

// Layout of Contract:
// version
// imports
// interfaces, libraries, contracts
// errors
// Type declarations
// State variables
// Events
// Modifiers
// Functions

// Layout of Functions:
// constructor
// receive function (if exists)
// fallback function (if exists)
// external
// public
// internal
// private
// view & pure functions

/**
 * @title SXCEngine
 * @author Adebakin Olujimi
 *
 * @notice This contract is the core of the StableXCoin (SXC) protocol — a decentralized, overcollateralized stablecoin system.
 * It manages all logic for minting and burning SXC, as well as handling collateral deposits, withdrawals, and liquidations.
 *
 * @dev The system is intentionally minimal and is designed to maintain a soft peg of 1 SXC = $1 at all times.
 *
 * Key Properties:
 * - Exogenously Collateralized (backed by crypto like WETH and WBTC)
 * - Pegged to the U.S. Dollar
 * - Algorithmically Stable (no central authority, no fees, no governance)
 *
 * The system is similar to MakerDAO's DAI, but without governance tokens, stability fees, or multi-collateral complexity.
 *
 * At all times, the system must remain **overcollateralized**:
 * The total USD value of all collateral must always be **greater than** the total SXC in circulation.
 * @notice Core contract for the StableXCoin (SXC) stablecoin system.
 * @dev Handles collateral deposits and price feed mapping. All logic enforcing collateralization lives here.
 */
pragma solidity 0.8.24;

import {ISXCEngine} from "./Interfaces/ISXCEngine.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableXCoin} from "./StableXCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SXCEngine is ISXCEngine, ReentrancyGuard {
    ///////////////////
    //   Errors   //
    ///////////////////

    /// @notice Reverts if an amount passed to a function is zero or negative
    error SXCEngine_NeedsMoreThanZero();
    /// @notice Reverts if the token and price feed address arrays have different lengths
    error SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLenght();
    /// @notice Reverts if the token is not an allowed collateral type
    error SXCEngine_NotAllowedToken();
    /// @notice Reverts if the ERC20 token transfer fails
    error SXCEngine_TransferFailed();
    error SXCEngine_BreakHealthFactor(uint256 healthFactor);
    error SXCEngine_MintingFailed();

    ////////////////////////
    //   State Variables //
    ///////////////////////

    /// @notice Maps each collateral token address to its corresponding Chainlink price feed address
    mapping(address token => address priceFeed) private s_priceFeeds;
    /// @notice Tracks the amount of each collateral token deposited by each user
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// @notice Tracks the amount of SXC minted by each user
    mapping(address user => uint256 amountSxcMinted) private s_SXCMinted;
    /// @notice Array of all allowed collateral token addresses
    address[] private s_collateralTokens;
    /// @notice Constant for additional precision used in price feed calculations (1e18)
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e18;
    /// @notice Constant for general precision in calculations (1e18)
    uint256 private constant PRECISION = 1e18;
    /// @notice Reference to the liquidation threshold
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //meaning you have to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1;
    /// @notice Reference to the StableXCoin (SXC) contract instance
    StableXCoin private immutable i_sxc;

    ///////////////////
    //   Events      //
    //////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 amount);

    ///////////////////
    //   Modifiers   //
    ///////////////////

    /// @notice Ensures the amount is greater than zero
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) {
            revert SXCEngine_NeedsMoreThanZero();
        }
        _;
    }

    /// @notice Ensures the token is approved for use as collateral
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) {
            revert SXCEngine_NotAllowedToken();
        }
        _;
    }
    ///////////////////
    //   Functions   //
    ///////////////////

    /**
     * @notice Initializes the SXCEngine with collateral tokens and their price feeds
     * @param tokenAddresses Array of allowed collateral token addresses (e.g., WETH, WBTC)
     * @param priceFeedAddresses Array of corresponding Chainlink price feed addresses
     * @param sxcAddress The address of the deployed StableXCoin contract
     * @dev Ensures token and price feed arrays are of equal length and sets up mappings
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address sxcAddress) {
        // Check that token and price feed arrays have the same length
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLenght();
        }

        // Map each token to its price feed and store token addresses
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        // Initialize the StableXCoin contract instance
        i_sxc = StableXCoin(sxcAddress);
    }

    ////////////////////////
    // External Functions //
    ////////////////////////

    // function depositCollateralAndMintDsc() external {}

    /**
     * @notice Deposits approved collateral into the system
     * @param tokenCollateralAddress The address of the ERC20 token being deposited
     * @param amountCollateral The amount of tokens to deposit
     * @dev Updates the user's collateral balance, emits an event, and transfers tokens
     * @dev Uses modifiers to enforce non-zero amounts, allowed tokens, and non-reentrancy
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        external
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // Update the user's collateral balance
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        // Emit an event for the deposit
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        // Transfer the collateral tokens from the user to this contract
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) {
            revert SXCEngine_TransferFailed();
        }
    }

    /**
     * @notice Code follows CEI
     * @notice Mints SXC for the caller
     * @param amountSxcToMint The amount of SXC to mint
     * @dev Updates the user's minted SXC balance and checks the health factor
     * @dev Uses modifiers to enforce non-zero amounts and non-reentrancy
     */
    function mintSxc(uint256 amountSxcToMint) external moreThanZero(amountSxcToMint) nonReentrant {
        // Update the user's minted SXC balance
        s_SXCMinted[msg.sender] += amountSxcToMint;

        // if they mined too much
        // Check if the user's health factor is broken (i.e., undercollateralized)
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_sxc.mint(msg.sender, amountSxcToMint);
        if (!minted) {
            revert SXCEngine_MintingFailed();
        }
    }

    ///////////////////////////////////////
    // Private & Internal View Functions //
    ///////////////////////////////////////

    /**
     * @notice Retrieves the total SXC minted and collateral value for a user
     * @param user The address of the user to query
     * @return totalSxcMinted The total amount of SXC minted by the user
     * @return collateralValueInUsd The total USD value of the user's collateral
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSxcMinted, uint256 collateralValueInUsd)
    {
        // Get the total SXC minted by the user
        totalSxcMinted = s_SXCMinted[user];
        // Calculate the USD value of the user's collateral
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Calculates the health factor for a user
     * @dev A health factor >= 1 means the user's position is safe; < 1 means it can be liquidated.
     * @param user The address of the user to check
     * @return The health factor, scaled by 1e18 (WAD-style)
     */
    function _healthFactor(address user) private view returns (uint256) {
        // 1. Get how much SXC the user has minted and how much their collateral is worth in USD
        (uint256 totalSxcMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);

        // Edge case: if user hasn't minted anything, their position is perfectly safe
        if (totalSxcMinted == 0) {
            return type(uint256).max; // return the highest possible value (fully safe)
        }

        // 2. Adjust collateral value by the liquidation threshold (e.g., 50%)
        //    This gives us the "effective collateral" after risk adjustment
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;

        // 3. Health Factor = (adjusted collateral) / (debt)
        //    If result < 1 → liquidation is possible
        return (collateralAdjustedForThreshold * PRECISION) / totalSxcMinted;
    }

    /**
     * @notice Checks if the user's health factor is broken and reverts if so
     * @param user The address of the user to check
     * @dev Placeholder for health factor validation logic
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        // 1. Check health factor (do they have enough collateral?)
        // 2. Revert if they dont
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) {
            revert SXCEngine_BreakHealthFactor(userHealthFactor);
        }
    }

    /////////////////////////////////////////
    //   Public & External View Functions  //
    /////////////////////////////////////////

    /**
     * @notice Calculates the total USD value of a user's collateral
     * @param user The address of the user to query
     * @return totalCollateralValueInUsd The total USD value of the user's collateral
     * @dev Iterates through all collateral tokens to sum their USD values
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        // loop through collateral token, get the amount they have deposited, and map it to
        // the price, to get the USD value

        // Loop through all allowed collateral tokens
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            // Get the amount of this token deposited by the user
            uint256 amount = s_collateralDeposited[user][token];
            // Add the USD value of this token to the total
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }

        return totalCollateralValueInUsd;
    }

    /**
     * @notice Converts a token amount to its USD value using the Chainlink price feed
     * @param token The address of the collateral token
     * @param amount The amount of tokens to convert
     * @return The USD value of the specified token amount
     * @dev Handles price feed precision and returns the USD value
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        // Get the Chainlink price feed for the token
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        // Get the latest price from the price feed
        (, int256 price,,,) = priceFeed.latestRoundData();
        // 1 ETH = $1000
        // The returned value from CL will be 1 ETH = 1000 = 10^8
        // Calculate USD value: (price * additional precision * amount) / general precision
        return (uint256(price) * ADDITIONAL_FEED_PRECISION) * amount / PRECISION; // (1000 * 1e8) * 1000 * 1e18;
    }
}
