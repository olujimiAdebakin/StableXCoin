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

// import {ISXCEngine} from "./Interfaces/ISXCEngine.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableXCoin} from "./StableXCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

contract SXCEngine is ReentrancyGuard {
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
    error SXCEngine_HealthFactorOk(uint256 healthFactor);
    error SXCEngine_HealthFactorNotImproved(uint256 healthFactor);
    error SXCEngine_InsufficientCollateral();
    error SXCEngine_InsufficientSxcMinted();
    error SXCEngine_InvalidPrice();
    error SXCEngine_StalePrice();
    error SXCEngine_InsufficientAllowance();

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
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    /// @notice Constant for general precision in calculations (1e18)
    uint256 private constant PRECISION = 1e18;
    /// @notice Reference to the liquidation threshold
    uint256 private constant LIQUIDATION_THRESHOLD = 50; //meaning you have to be 200% overcollateralized
    uint256 private constant LIQUIDATION_PRECISION = 100;
    uint256 private constant MIN_HEALTH_FACTOR = 1e18; // 1e18 means 1.0, which is the minimum health factor for a safe position
    /// @notice Reference to the StableXCoin (SXC) contract instance
    StableXCoin private immutable i_sxc;
    uint256 private constant LIQUIDATION_BONUS = 10; // 10% bonus for liquidators

    ///////////////////
    //   Events      //
    //////////////////

    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount
    );
    /// @notice Emitted when a user burns SXC to reduce debt
    event SxcBurned(address indexed user, uint256 amount);
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        address indexed token,
        uint256 debtCovered,
        uint256 collateralRedeemed
    );
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

    /**
     * @notice Deposits collateral and mints StableXCoin (SXC) in a single transaction
     * @dev This function first deposits the specified collateral and then mints SXC against it.
     * It assumes that the caller has approved the collateral transfer beforehand.
     * @param tokenCollateralAddress The address of the collateral token (e.g., WETH, WBTC)
     * @param amountCollateral The amount of collateral to deposit (in token's smallest unit)
     * @param amountSxcToMint The amount of SXC to mint (in 18 decimals)
     */
    function depositCollateralAndMintDsc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountSxcToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintSxc(amountSxcToMint);
    }

    /**
     * @notice Deposits approved collateral into the system
     * @param tokenCollateralAddress The address of the ERC20 token being deposited
     * @param amountCollateral The amount of tokens to deposit
     * @dev Updates the user's collateral balance, emits an event, and transfers tokens
     * @dev Uses modifiers to enforce non-zero amounts, allowed tokens, and non-reentrancy
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        // checking for allowance before calling transferFrom
        if (IERC20(tokenCollateralAddress).allowance(msg.sender, address(this)) < amountCollateral) {
            revert SXCEngine_InsufficientAllowance();
        }
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

    /// @notice Redeem collateral and burn SXC in a single transaction
    /// @dev This helps users efficiently reduce their debt and retrieve collateral at once
    /// @param tokenCollateralAddress The address of the token to redeem as collateral
    /// @param amountCollateral The amount of collateral to redeem
    /// @param amountSxcToBurn The amount of SXC to burn (reduce debt)
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountSxcToBurn)
        external
    {
        _revertIfHealthFactorIsBroken(msg.sender); //check health factor first before burning
        _burnSxc(amountSxcToBurn, msg.sender, msg.sender);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender); // check again
    }

    /// @notice Redeem only collateral (likely in excess position)
    // CEI check effects interaction
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /// @notice Burn DSC to reduce debt position
    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnSxc(amount, msg.sender, msg.sender); // private view function
        _revertIfHealthFactorIsBroken(msg.sender);

        //  uint256 newHealthFactor = _healthFactor(msg.sender);
        emit SxcBurned(msg.sender, amount);
    }

    /**
     * @notice Code follows CEI
     * @notice Mints SXC for the caller
     * @param amountSxcToMint The amount of SXC to mint
     * @dev Updates the user's minted SXC balance and checks the health factor
     * @dev Uses modifiers to enforce non-zero amounts and non-reentrancy
     */
    function mintSxc(uint256 amountSxcToMint) public moreThanZero(amountSxcToMint) nonReentrant {
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

    /**
     * @notice Allows a third party (liquidator) to liquidate a user's undercollateralized position.
     * @dev Checks if the user's health factor is below the required minimum.
     * Burns the SXC from the liquidator to cover the user's debt and transfers equivalent collateral + bonus.
     * @param collateral The address of the ERC-20 collateral token.
     * @param user The address of the borrower whose position is being liquidated.
     * @param debtToCover The amount of SXC debt the liquidator wants to cover (in 18 decimal precision).
     * Requirements:
     * - The user's health factor must be below `MIN_HEALTH_FACTOR`.
     * - `debtToCover` must be greater than 0.
     * - Function is protected against reentrancy via `nonReentrant`.
     */
    function liquidate(address collateral, address user, uint256 debtToCover)
        external
        moreThanZero(debtToCover)
        nonReentrant
    {
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SXCEngine_HealthFactorOk(startingUserHealthFactor);
        }

        uint256 tokenAmountFromDebtCovered = getTokenAmountFromUsd(debtToCover, collateral);

        uint256 bonusCollateral = (tokenAmountFromDebtCovered * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;

        uint256 totalCollateralToRedeem = tokenAmountFromDebtCovered + bonusCollateral;

        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        // we need to burn the debt from the liquidator

        _burnSxc(debtToCover, user, msg.sender);
        emit Liquidation(user, msg.sender, collateral, debtToCover, totalCollateralToRedeem);

        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingUserHealthFactor) {
            revert SXCEngine_HealthFactorNotImproved(endingHealthFactor);
        }

        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /// @notice Get the health factor of a user/account
    // function getHealthFactor() external view returns (uint256){};

    ///////////////////////////////////////
    // Private & Internal View Functions //
    ///////////////////////////////////////

    // low level functions that are not exposed to the outside world
    function _burnSxc(uint256 amountSXCToBurn, address onBehalfOf, address sxcFrom) private nonReentrant {
        // Update the user's minted SXC balance
        if (s_SXCMinted[onBehalfOf] < amountSXCToBurn) {
            revert SXCEngine_InsufficientSxcMinted();
        }
        // Burn the SXC tokens from the user's balance
        bool success = i_sxc.transferFrom(sxcFrom, address(this), amountSXCToBurn);
        if (!success) {
            revert SXCEngine_TransferFailed();
        }
        i_sxc.burn(amountSXCToBurn);
    }

    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
        nonReentrant
    {
        // Update the user's collateral balance
        if (s_collateralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert SXCEngine_InsufficientCollateral();
        }
        // Emit an event for the redemption
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        // Transfer the collateral tokens from this contract to the specified address
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) {
            revert SXCEngine_TransferFailed();
        }
    }

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

    //   /**
    //  * @notice Converts a USD amount (in 18 decimals) to the equivalent token amount
    //  * @dev Uses Chainlink price feed to get the token/USD exchange rate.
    //  * @param usdAmountInWei The USD amount in 18 decimal precision (like wei).
    //  * @param token The ERC-20 token address whose amount is to be calculated.
    //  * @return The equivalent amount of the token (in its smallest unit).
    //  */
    // function getTokenAmountFromUsd(uint256 usdAmountInWei, address token) public view returns (uint256) {
    //     // Get the price feed for the token
    //     AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);

    //     // Get the latest price from the price feed
    //     (, int256 price,,,) = priceFeed.latestRoundData();

    //     // applying validation preventing stale or negative price from price feed
    //     if (price <= 0) {
    //     revert SXCEngine_InvalidPrice();
    // }
    // if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) {
    //     revert SXCEngine_StalePrice();
    // }

    // // Query the price feed’s decimals() function to dynamically adjust precision
    // uint256 feedPrecision = 10 ** uint256(decimals);
    //     // Calculate and return the amount of tokens needed to match the USD amount
    //     return (usdAmountInWei * PRECISION) / (uint256(price) * ADDITIONAL_FEED_PRECISION);
    // }

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

    /// @notice Converts a token amount to its USD value using the Chainlink price feed
    /// @param token The address of the collateral token
    /// @param amount The amount of tokens to convert
    /// @return The USD value of the specified token amount
    /// @dev Handles price feed precision and validates price and freshness
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert SXCEngine_InvalidPrice();
        }
        if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) {
            revert SXCEngine_StalePrice();
        }
        uint8 feedDecimals = priceFeed.decimals();
        uint256 feedPrecision = 10 ** uint256(feedDecimals);
        return ((uint256(price) * feedPrecision) * amount) / PRECISION;
    }

    /// @notice Converts a USD amount (in 18 decimals) to the equivalent token amount
    /// @dev Uses Chainlink price feed to get the token/USD exchange rate.
    /// @param usdAmountInWei The USD amount in 18 decimal precision (like wei).
    /// @param token The ERC-20 token address whose amount is to be calculated.
    /// @return The equivalent amount of the token (in its smallest unit).
    function getTokenAmountFromUsd(uint256 usdAmountInWei, address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (price <= 0) {
            revert SXCEngine_InvalidPrice();
        }
        if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) {
            revert SXCEngine_StalePrice();
        }
        uint8 feedDecimals = priceFeed.decimals();
        uint256 feedPrecision = 10 ** uint256(feedDecimals);
        return (usdAmountInWei * PRECISION) / (uint256(price) * feedPrecision);
    }

    //     /**
    //      * @notice Converts a token amount to its USD value using the Chainlink price feed
    //      * @param token The address of the collateral token
    //      * @param amount The amount of tokens to convert
    //      * @return The USD value of the specified token amount
    //      * @dev Handles price feed precision and returns the USD value
    //      */
    //     function getUsdValue(address token, uint256 amount) public view returns (uint256) {
    //         // Get the Chainlink price feed for the token
    //         AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
    //         // Get the latest price from the price feed
    //         (, int256 price,,,) = priceFeed.latestRoundData();

    //        // applying validation preventing stale or negative price from price feed
    //         if (price <= 0) {
    //         revert SXCEngine_InvalidPrice();
    //     }
    //     if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) {
    //         revert SXCEngine_StalePrice();
    //     }
    //         // 1 ETH = $1000
    //         // The returned value from CL will be 1 ETH = 1000 = 10^8
    //         // Calculate USD value: (price * additional precision * amount) / general precision
    //         // Query the price feed’s decimals() function to dynamically adjust precision
    //     uint256 feedPrecision = 10 ** uint256(decimals);
    //         return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION; // (1000 * 1e8) * 1000 * 1e18;
    //     }
}
