// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableXCoin} from "./StableXCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

import "../utils/SafeMath.sol"; // Assuming SafeMath is correctly implemented and available

/**
 * @title SXCEngine
 * @author Adebakin Olujimi
 * @notice Core contract for the StableXCoin (SXC) protocol, managing minting, burning, collateral deposits, withdrawals, and liquidations.
 * @dev Implements a decentralized, overcollateralized stablecoin pegged to $1, inspired by MakerDAO's DAI but without governance or fees.
 * @dev Ensures overcollateralization: total USD value of collateral must exceed total SXC in circulation.
 */
contract SXCEngine is ReentrancyGuard {
    ////////////////
    // Errors //
    ////////////////

    /// @notice Reverts if an amount passed to a function is zero or negative.
    error SXCEngine_NeedsMoreThanZero();
    /// @notice Reverts if token and price feed address arrays have different lengths during initialization.
    error SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    /// @notice Reverts if the provided token is not an allowed collateral type.
    error SXCEngine_NotAllowedToken();
    /// @notice Reverts if an ERC20 token transfer operation fails.
    error SXCEngine_TransferFailed();
    /// @notice Reverts if the user's health factor falls below the minimum threshold, indicating undercollateralization.
    /// @param healthFactor The calculated health factor of the user's position.
    error SXCEngine_BreakHealthFactor(uint256 healthFactor);
    /// @notice Reverts if minting SXC fails (e.g., due to underlying StableXCoin contract issues).
    error SXCEngine_MintingFailed();
    /// @notice Reverts if a liquidation attempt is made on a position that is already healthy.
    /// @param healthFactor The calculated health factor of the user's position.
    error SXCEngine_HealthFactorOk(uint256 healthFactor);
    /// @notice Reverts if a liquidation does not sufficiently improve the user's health factor to a healthy state.
    /// @param healthFactor The calculated health factor of the user's position after liquidation attempt.
    error SXCEngine_HealthFactorNotImproved(uint256 healthFactor);
    /// @notice Reverts if the user attempts to redeem more collateral than they have deposited.
    error SXCEngine_InsufficientCollateral();
    /// @notice Reverts if the user has insufficient SXC minted to burn.
    error SXCEngine_InsufficientSxcMinted();
    /// @notice Reverts if the price feed returns an invalid (non-positive) price.
    error SXCEngine_InvalidPrice();
    /// @notice Reverts if the price feed data is stale (older than `PRICE_STALENESS_THRESHOLD`).
    error SXCEngine_StalePrice();
    /// @notice Reverts if the user has insufficient ERC20 allowance.
    error SXCEngine_InsufficientAllowance();
    /// @notice Reverts if an arithmetic overflow occurs during calculations, typically in price conversions.
    error SXCEngine_ArithmeticOverflow();
    /// @notice Reverts if a user attempts an action requiring debt when they have none.
    error SXCEngine_NoDebt();
    /// @notice Reverts if a user attempts to burn an amount of SXC that is too large.
    error SXCEngine_TooMuchToBurn();
    /// @notice Reverts if the collateral amount available for liquidation is insufficient.
    error SXCEngine_NotEnoughCollateralForLiquidation();

    ///////////////////////////
    // Type Declarations //
    ///////////////////////////
    using SafeMath for uint256; // Assuming SafeMath provides functions like `mul`, `div`, `add`, `sub` with overflow checks.

    ///////////////////////
    // State Variables //
    ///////////////////////
    /// @notice Maps each collateral token address to its corresponding Chainlink price feed address.
    mapping(address token => address priceFeed) private s_priceFeeds;
    /// @notice Tracks the amount of each collateral token deposited by each user.
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// @notice Tracks the total amount of SXC minted by each user (their outstanding debt).
    mapping(address user => uint256 amountSxcMinted) private s_SXCMinted;
    /// @notice Array of all allowed collateral token addresses.
    address[] private s_collateralTokens;

    ///////////////////////
    // Constants //
    ///////////////////////
    /// @notice Additional precision factor for Chainlink price feed results (10^10).
    /// Used to scale prices to 18 decimals for consistent calculations.
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    /// @notice Standard precision for calculations, equivalent to 18 decimal places (10^18).
    uint256 private constant PRECISION = 1e18;
    /// @notice Liquidation threshold (50%). A position is undercollateralized if its value falls below this percentage of the debt.
    /// Represents 200% overcollateralization requirement (100 / 50 = 2).
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    /// @notice Precision for liquidation calculations, typically 100 for percentage calculations.
    uint256 private constant LIQUIDATION_PRECISION = 100;
    /// @notice Minimum health factor for a safe position (1.0 in 10^18 precision).
    /// A position with a health factor below this value is subject to liquidation.
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    /// @notice Bonus percentage offered to liquidators (10%).
    uint256 private constant LIQUIDATION_BONUS = 10;
    /// @notice Price feed staleness threshold (1 hour).
    uint256 private constant PRICE_STALENESS_THRESHOLD = 3600;

    ///////////////////////
    // Immutable //
    ///////////////////////
    /// @notice Reference to the StableXCoin (SXC) contract instance.
    StableXCoin private immutable i_sxc;

    ////////////////
    // Events //
    ////////////////

    /// @notice Emitted when a user successfully deposits collateral.
    /// @param user The address of the user who deposited collateral.
    /// @param token The address of the collateral token deposited.
    /// @param amount The amount of collateral tokens deposited.
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    /// @notice Emitted when collateral is successfully redeemed by a user.
    /// @param redeemedFrom The address from which collateral was redeemed (typically the user).
    /// @param redeemTo The address to which collateral was sent.
    /// @param token The address of the collateral token redeemed.
    /// @param amount The amount of collateral tokens redeemed.
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount
    );
    /// @notice Emitted when a user successfully burns SXC to reduce their debt.
    /// @param user The address of the user who burned SXC.
    /// @param amount The amount of SXC tokens burned.
    event SxcBurned(address indexed user, uint256 amount);
    /// @notice Emitted upon a successful liquidation of an undercollateralized position.
    /// @param user The address of the user whose position was liquidated.
    /// @param liquidator The address of the liquidator.
    /// @param token The address of the collateral token involved in the liquidation.
    /// @param debtCovered The amount of SXC debt covered by the liquidator.
    /// @param collateralRedeemed The total amount of collateral tokens received by the liquidator (including bonus).
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        address indexed token,
        uint256 debtCovered,
        uint256 collateralRedeemed
    );

    ////////////////
    // Modifiers //
    ////////////////

    /// @notice Ensures the provided amount is strictly greater than zero.
    /// @param amount The amount to check.
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert SXCEngine_NeedsMoreThanZero();
        _;
    }

    /// @notice Ensures the provided token address is an allowed collateral type.
    /// @param token The address of the token to check.
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert SXCEngine_NotAllowedToken();
        _;
    }

    ////////////////
    // Functions //
    ////////////////

    /**
     * @notice Initializes the SXCEngine with allowed collateral tokens, their price feed addresses, and the StableXCoin contract address.
     * @param tokenAddresses Array of allowed collateral token addresses (e.g., WETH, WBTC).
     * @param priceFeedAddresses Array of corresponding Chainlink price feed addresses.
     * @param sxcAddress The address of the deployed StableXCoin contract.
     */
    constructor(address[] memory tokenAddresses, address[] memory priceFeedAddresses, address sxcAddress) {
        if (tokenAddresses.length != priceFeedAddresses.length) {
            revert SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
        }
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            s_priceFeeds[tokenAddresses[i]] = priceFeedAddresses[i];
            s_collateralTokens.push(tokenAddresses[i]);
        }
        i_sxc = StableXCoin(sxcAddress);
    }

    ////////////////////////////
    // External Functions //
    ////////////////////////////

    /**
     * @notice Allows a user to deposit collateral and mint SXC in a single atomic transaction.
     * @param tokenCollateralAddress The address of the collateral token to deposit.
     * @param amountCollateral The amount of collateral tokens to deposit.
     * @param amountSxcToMint The amount of SXC tokens to mint.
     */
    function depositCollateralAndMintSxc(
        address tokenCollateralAddress,
        uint256 amountCollateral,
        uint256 amountSxcToMint
    ) external {
        depositCollateral(tokenCollateralAddress, amountCollateral);
        mintSxc(amountSxcToMint);
    }

    /**
     * @notice Allows a user to redeem collateral and burn SXC in a single atomic transaction.
     * @dev This function ensures that the user's health factor remains healthy after the operation.
     * @param tokenCollateralAddress The address of the collateral token to redeem.
     * @param amountCollateral The amount of collateral tokens to redeem.
     * @param amountSxcToBurn The amount of SXC tokens to burn.
     */
    function redeemCollateralForSxc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountSxcToBurn)
        external
        moreThanZero(amountCollateral)
        moreThanZero(amountSxcToBurn)
    {
        _burnSxc(amountSxcToBurn, msg.sender, msg.sender);
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender); // Check health factor after both operations
    }

    /**
     * @notice Allows a liquidator to liquidate an undercollateralized user's position.
     * @dev The liquidator covers a portion of the user's debt in SXC and receives collateral plus a bonus.
     * @param collateral The address of the collateral token to be liquidated.
     * @param user The address of the user whose position is being liquidated.
     * @param debtToCover The amount of SXC debt the liquidator wishes to cover.
     */
    function liquidate(
        address collateral,
        address user,
        uint256 debtToCover // Changed from uint252 to uint256
    ) external moreThanZero(debtToCover) nonReentrant {
        // 1. Initial health factor check: Position must be unhealthy to be liquidated.
        uint256 startingUserHealthFactor = _healthFactor(user);
        if (startingUserHealthFactor >= MIN_HEALTH_FACTOR) {
            revert SXCEngine_HealthFactorOk(startingUserHealthFactor);
        }

        // 2. Calculate collateral to be taken and bonus for liquidator.
        uint256 collateralToLiquidate = getTokenAmountFromUsd(debtToCover, collateral);
        uint256 bonusCollateral = (collateralToLiquidate * LIQUIDATION_BONUS) / LIQUIDATION_PRECISION;
        uint256 totalCollateralToRedeem = collateralToLiquidate + bonusCollateral;

        // Ensure the user has enough collateral to be liquidated
        if (s_collateralDeposited[user][collateral] < totalCollateralToRedeem) {
            revert SXCEngine_NotEnoughCollateralForLiquidation();
        }

        // 3. Liquidator pays debt: `msg.sender` (liquidator) burns their SXC to reduce `user`'s recorded debt.
        // The liquidator must have approved the SXCEngine to spend `debtToCover` amount of SXC.
        _burnSxc(debtToCover, user, msg.sender);

        // 4. Transfer collateral (with bonus) from `user` to `msg.sender` (liquidator).
        _redeemCollateral(user, msg.sender, collateral, totalCollateralToRedeem);

        // 5. Final health factor check: User's position must be healthy after liquidation.
        uint256 endingHealthFactor = _healthFactor(user);
        // If the health factor is still below MIN_HEALTH_FACTOR, the liquidation wasn't enough.
        if (endingHealthFactor < MIN_HEALTH_FACTOR) {
            revert SXCEngine_HealthFactorNotImproved(endingHealthFactor);
        }
        // No need for _revertIfHealthFactorIsBroken(msg.sender) here, as the liquidator's HF is not directly impacted
        // in a way that should break it by performing a liquidation, and the user's HF is checked above.

        // 6. Emit Liquidation event.
        emit Liquidation(user, msg.sender, collateral, debtToCover, totalCollateralToRedeem);
    }

    ////////////////////////////
    // Public Functions //
    ////////////////////////////

    /**
     * @notice Deposits approved collateral into the system.
     * @dev Transfers `amountCollateral` from `msg.sender` to the `SXCEngine` contract.
     * @param tokenCollateralAddress The address of the ERC20 token to deposit.
     * @param amountCollateral The amount of tokens to deposit.
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        _checkSufficientAllowance(tokenCollateralAddress, amountCollateral);
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert SXCEngine_TransferFailed();
    }

    /**
     * @notice Redeems collateral from the system back to the caller.
     * @dev This function ensures that the user's health factor remains healthy after the redemption.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param amountCollateral The amount of collateral to redeem.
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender); // Check health factor after redemption
    }

    /**
     * @notice Mints new StableXCoin (SXC) tokens for the caller.
     * @dev This function checks if minting the specified amount would break the caller's health factor.
     * @param amountSxcToMint The amount of SXC tokens to mint.
     */
    function mintSxc(uint256 amountSxcToMint) public moreThanZero(amountSxcToMint) nonReentrant {
        // Temporarily increase the user's minted SXC to check the health factor
        s_SXCMinted[msg.sender] += amountSxcToMint;
        // Revert if the new minted amount breaks the health factor
        _revertIfHealthFactorIsBroken(msg.sender);
        // If health factor is fine, proceed with minting via the StableXCoin contract
        bool minted = i_sxc.mint(msg.sender, amountSxcToMint);
        if (!minted) {
            // If the underlying mint operation fails (e.g., returns false), revert.
            // Note: If i_sxc.mint reverts with a specific error, that error will propagate.
            revert SXCEngine_MintingFailed();
        }
    }

    /**
     * @notice Burns StableXCoin (SXC) tokens to reduce a user's debt.
     * @dev The `amount` of SXC is transferred from `msg.sender` to the `SXCEngine` and then burned.
     * @param amount The amount of SXC tokens to burn.
     */
    function burnSxc(uint256 amount) public moreThanZero(amount) {
        // Call the internal burn function, where `msg.sender` is both the one burning and on whose behalf.
        _burnSxc(amount, msg.sender, msg.sender);
        // Check health factor after burning SXC. It should improve or stay healthy.
        _revertIfHealthFactorIsBroken(msg.sender); // This check ensures the user doesn't burn too much collateral
            // if it would make their *remaining* position unhealthy.
        emit SxcBurned(msg.sender, amount);
    }

    ////////////////////////////
    // Private Functions //
    ////////////////////////////

    /**
     * @notice Internal function to burn SXC tokens.
     * @dev Handles the `transferFrom` of SXC to the engine and updates the user's minted SXC record.
     * @param amountSXCToBurn The amount of SXC tokens to burn.
     * @param onBehalfOf The address of the user whose SXC debt (recorded in `s_SXCMinted`) is being reduced.
     * @param sxcFrom The address from which SXC tokens are transferred (e.g., `msg.sender` for self-burn, or liquidator).
     */
    function _burnSxc(uint256 amountSXCToBurn, address onBehalfOf, address sxcFrom) private {
        // Transfer SXC from `sxcFrom` (the one paying for the burn) to the SXCEngine contract.
        bool success = i_sxc.transferFrom(sxcFrom, address(this), amountSXCToBurn);
        if (!success) revert SXCEngine_TransferFailed();

        // Check if the user (`onBehalfOf`) has enough recorded SXC debt to burn this amount.
        // This prevents burning more debt than was actually minted.
        if (s_SXCMinted[onBehalfOf] < amountSXCToBurn) {
            revert SXCEngine_InsufficientSxcMinted();
        }

        // Reduce the user's recorded SXC debt.
        s_SXCMinted[onBehalfOf] -= amountSXCToBurn;

        // Burn the SXC tokens from the SXCEngine contract's balance.
        i_sxc.burn(amountSXCToBurn);
    }

    /**
     * @notice Internal function to redeem collateral tokens.
     * @dev Transfers `amountCollateral` from `from` (user's deposited collateral) to `to` (recipient).
     * @param from The address from which collateral is redeemed (the user whose collateral is held).
     * @param to The address receiving the collateral tokens.
     * @param tokenCollateralAddress The address of the collateral token.
     * @param amountCollateral The amount of collateral tokens to redeem.
     */
    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
    {
        // Check if the user (`from`) has enough deposited collateral to redeem.
        if (s_collateralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert SXCEngine_InsufficientCollateral();
        }
        // Decrease the user's recorded deposited collateral.
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        // Transfer the actual collateral tokens from the SXCEngine to the recipient.
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) revert SXCEngine_TransferFailed();
    }

    /**
     * @notice Checks if user has sufficient ERC20 allowance for the SXCEngine.
     * @param token The address of the ERC20 token.
     * @param amount The amount of tokens to check allowance for.
     */
    function _checkSufficientAllowance(address token, uint256 amount) private view {
        if (IERC20(token).allowance(msg.sender, address(this)) < amount) {
            revert SXCEngine_InsufficientAllowance();
        }
    }

    /**
     * @notice Validates price feed data for staleness and validity.
     * @dev Reverts if price is non-positive or if `updatedAt` is too old.
     * @param price The price value from the Chainlink price feed.
     * @param updatedAt The timestamp when the price was last updated.
     */
    function _validatePriceData(int256 price, uint256 updatedAt) private view {
        if (price <= 0) revert SXCEngine_InvalidPrice();
        if (updatedAt == 0 || updatedAt < block.timestamp - PRICE_STALENESS_THRESHOLD) {
            revert SXCEngine_StalePrice();
        }
    }

    /**
     * @notice Checks for arithmetic overflow during multiplication.
     * @dev Used in `getUsdValue` and `getTokenAmountFromUsd` to prevent overflow before multiplication.
     * @param value1 The first operand.
     * @param value2 The second operand.
     */
    function _checkOverflow(uint256 value1, uint256 value2) private pure {
        // This check prevents overflow for `value1 * value2`.
        // If value2 is zero, no overflow is possible unless value1 is already max.
        // If value1 is max and value2 > 1, it will overflow.
        // The SafeMath library should handle this, but this explicit check adds a specific error.
        if (value2 > 0 && value1 > type(uint256).max / value2) {
            revert SXCEngine_ArithmeticOverflow();
        }
    }

    ////////////////////////////
    // Private View Functions //
    ////////////////////////////

    /**
     * @notice Retrieves the total SXC minted by a user and the USD value of their collateral.
     * @param user The address of the user to query.
     * @return totalSxcMinted The total amount of SXC tokens minted by the user (their outstanding debt).
     * @return collateralValueInUsd The total USD value of the user's deposited collateral.
     */
    function _getAccountInformation(address user)
        private
        view
        returns (uint256 totalSxcMinted, uint256 collateralValueInUsd)
    {
        totalSxcMinted = s_SXCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Calculates the health factor for a given user.
     * @dev The health factor indicates the safety of a user's position. A value below `MIN_HEALTH_FACTOR` is unhealthy.
     * @param user The address of the user to check.
     * @return The user's health factor, scaled by `PRECISION` (1e18). Returns `type(uint256).max` if no SXC is minted.
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSxcMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        return _calculateHealthFactor(totalSxcMinted, collateralValueInUsd);
    }

    /**
     * @notice Calculates the health factor based on provided total minted SXC and collateral value.
     * @param totalSxcMinted Total SXC tokens minted by the user.
     * @param collateralValueInUsd Total USD value of the user's collateral.
     * @return The calculated health factor, scaled by `PRECISION` (1e18). Returns `type(uint256).max` if `totalSxcMinted` is zero.
     */
    function _calculateHealthFactor(uint256 totalSxcMinted, uint256 collateralValueInUsd)
        private
        pure
        returns (uint256)
    {
        if (totalSxcMinted == 0) return type(uint256).max; // If no debt, health factor is considered infinite.

        // Calculate the thresholded collateral value: collateralValueInUsd * LIQUIDATION_THRESHOLD / LIQUIDATION_PRECISION
        // (e.g., collateral * 0.5)
        uint256 collateralAdjustedForThreshold =
            (collateralValueInUsd.mul(LIQUIDATION_THRESHOLD)).div(LIQUIDATION_PRECISION);

        // Health factor = (adjusted collateral * PRECISION) / totalSxcMinted
        // This scales the health factor to 1e18 for consistent calculations.
        return (collateralAdjustedForThreshold.mul(PRECISION)).div(totalSxcMinted);
    }

    /**
     * @notice Reverts if the user's health factor is below the minimum threshold (`MIN_HEALTH_FACTOR`).
     * @param user The address of the user to check.
     */
    function _revertIfHealthFactorIsBroken(address user) private view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) revert SXCEngine_BreakHealthFactor(userHealthFactor);
    }

    ////////////////////////////
    // Public View Functions //
    ////////////////////////////

    /**
     * @notice Calculates the total USD value of all collateral deposited by a specific user.
     * @param user The address of the user to query.
     * @return totalCollateralValueInUsd The total USD value of the user's collateral, in 18 decimals.
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd = totalCollateralValueInUsd.add(getUsdValue(token, amount));
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice Converts a given amount of a collateral token to its equivalent USD value using its Chainlink price feed.
     * @param token The address of the collateral token.
     * @param amount The amount of tokens to convert.
     * @return The USD value of the specified token amount, in 18 decimals.
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        _validatePriceData(price, updatedAt); // Validate price and staleness
        uint256 priceUint = uint256(price);

        // Calculate priceAdjusted: priceUint * ADDITIONAL_FEED_PRECISION
        _checkOverflow(priceUint, ADDITIONAL_FEED_PRECISION);
        uint256 priceAdjusted = priceUint * ADDITIONAL_FEED_PRECISION; // Use standard multiplication here

        // Calculate numerator: amount * priceAdjusted
        _checkOverflow(amount, priceAdjusted);
        uint256 numerator = amount * priceAdjusted; // Use standard multiplication here

        return numerator / PRECISION; // Use standard division, assuming PRECISION is not zero
    }

    /**
     * @notice Converts a given USD amount to the equivalent amount of a specified collateral token.
     * @param usdAmountInWei The USD amount, in 18 decimals.
     * @param token The address of the collateral token.
     * @return The equivalent amount of the token, in its smallest unit (e.g., wei for ETH).
     */
    function getTokenAmountFromUsd(uint256 usdAmountInWei, address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        _validatePriceData(price, updatedAt); // Validate price and staleness
        uint256 priceUint = uint256(price);

        // Scale price to 18 decimals
        _checkOverflow(priceUint, ADDITIONAL_FEED_PRECISION); // Check before multiplication
        uint256 priceAdjusted = priceUint * ADDITIONAL_FEED_PRECISION; // Use standard multiplication here

        if (priceAdjusted == 0) revert SXCEngine_InvalidPrice(); // Prevent division by zero, changed error to InvalidPrice

        // Check for overflow before multiplying usdAmountInWei by PRECISION
        _checkOverflow(usdAmountInWei, PRECISION); // ADDED THIS LINE
        uint256 numerator = usdAmountInWei * PRECISION; // Use standard multiplication here

        return numerator / priceAdjusted; // Use standard division
    }

    /**
     * @notice Gets account information for a user.
     * @param user The user address.
     * @return totalSxcMinted Total SXC minted by the user.
     * @return collateralValueInUsd Total collateral value in USD.
     */
    function getAccountInformation(address user)
        external
        view
        returns (uint256 totalSxcMinted, uint256 collateralValueInUsd)
    {
        return _getAccountInformation(user);
    }

    /**
     * @notice Gets the current health factor for a user.
     * @param user The user address.
     * @return The user's health factor, scaled by `PRECISION` (1e18).
     */
    function getHealthFactor(address user) external view returns (uint256) {
        return _healthFactor(user);
    }

    /**
     * @notice Gets the amount of a specific collateral token deposited by a user.
     * @param user The user address.
     * @param token The address of the collateral token.
     * @return The amount of collateral deposited by the user.
     */
    function getCollateralBalanceOfUser(address user, address token) external view returns (uint256) {
        return s_collateralDeposited[user][token];
    }

    /**
     * @notice Gets the total amount of SXC tokens minted by a user (their outstanding debt).
     * @param user The user address.
     * @return The amount of SXC tokens minted by the user.
     */
    function getSxcMinted(address user) external view returns (uint256) {
        return s_SXCMinted[user];
    }

    ////////////////////////////
    // Pure Functions //
    ////////////////////////////

    /**
     * @notice Returns the standard precision constant (1e18).
     * @return The PRECISION constant.
     */
    function getPrecision() external pure returns (uint256) {
        return PRECISION;
    }

    /**
     * @notice Returns the additional feed precision constant (1e10).
     * @return The ADDITIONAL_FEED_PRECISION constant.
     */
    function getAdditionalFeedPrecision() external pure returns (uint256) {
        return ADDITIONAL_FEED_PRECISION;
    }

    /**
     * @notice Returns the liquidation threshold constant (50).
     * @return The LIQUIDATION_THRESHOLD constant.
     */
    function getLiquidationThreshold() external pure returns (uint256) {
        return LIQUIDATION_THRESHOLD;
    }

    /**
     * @notice Returns the liquidation bonus constant (10).
     * @return The LIQUIDATION_BONUS constant.
     */
    function getLiquidationBonus() external pure returns (uint256) {
        return LIQUIDATION_BONUS;
    }

    /**
     * @notice Returns the liquidation precision constant (100).
     * @return The LIQUIDATION_PRECISION constant.
     */
    function getLiquidationPrecision() external pure returns (uint256) {
        return LIQUIDATION_PRECISION;
    }

    /**
     * @notice Returns the minimum health factor constant (1e18).
     * @return The MIN_HEALTH_FACTOR constant.
     */
    function getMinHealthFactor() external pure returns (uint256) {
        return MIN_HEALTH_FACTOR;
    }

    /**
     * @notice Returns an array of all allowed collateral token addresses.
     * @return An array containing the addresses of allowed collateral tokens.
     */
    function getCollateralTokens() external view returns (address[] memory) {
        return s_collateralTokens;
    }

    /**
     * @notice Returns the address of the StableXCoin (SXC) contract.
     * @return The address of the SXC token.
     */
    function getSxc() external view returns (address) {
        return address(i_sxc);
    }

    /**
     * @notice Returns the Chainlink price feed address for a given collateral token.
     * @param token The address of the collateral token.
     * @return The address of the associated price feed.
     */
    function getCollateralTokenPriceFeed(address token) external view returns (address) {
        return s_priceFeeds[token];
    }
}
