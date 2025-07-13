// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {StableXCoin} from "./StableXCoin.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {console} from "forge-std/Test.sol";

/**
 * @title SXCEngine
 * @author Adebakin Olujimi
 * @notice Core contract for the StableXCoin (SXC) protocol, managing minting, burning, collateral deposits, withdrawals, and liquidations.
 * @dev Implements a decentralized, overcollateralized stablecoin pegged to $1, inspired by MakerDAO's DAI but without governance or fees.
 * @dev Ensures overcollateralization: total USD value of collateral must exceed total SXC in circulation.
 */
contract SXCEngine is ReentrancyGuard {
    ////////////////
    // Errors     //
    ////////////////

    /// @notice Reverts if an amount passed to a function is zero or negative
    error SXCEngine_NeedsMoreThanZero();
    /// @notice Reverts if token and price feed address arrays have different lengths
    error SXCEngine_TokenAddressesAndPriceFeedAddressesMustBeSameLength();
    /// @notice Reverts if the token is not an allowed collateral type
    error SXCEngine_NotAllowedToken();
    /// @notice Reverts if an ERC20 token transfer fails
    error SXCEngine_TransferFailed();
    /// @notice Reverts if the user's health factor falls below the minimum threshold
    error SXCEngine_BreakHealthFactor(uint256 healthFactor);
    /// @notice Reverts if minting SXC fails
    error SXCEngine_MintingFailed();
    /// @notice Reverts if the user's health factor is above the minimum threshold during liquidation
    error SXCEngine_HealthFactorOk(uint256 healthFactor);
    /// @notice Reverts if liquidation does not improve the user's health factor
    error SXCEngine_HealthFactorNotImproved(uint256 healthFactor);
    /// @notice Reverts if the user has insufficient collateral to redeem
    error SXCEngine_InsufficientCollateral();
    /// @notice Reverts if the user has insufficient SXC minted to burn
    error SXCEngine_InsufficientSxcMinted();
    /// @notice Reverts if the price feed returns an invalid (non-positive) price
    error SXCEngine_InvalidPrice();
    /// @notice Reverts if the price feed data is stale
    error SXCEngine_StalePrice();
    /// @notice Reverts if the user has insufficient ERC20 allowance
    error SXCEngine_InsufficientAllowance();
    /// @notice Reverts if arithmetic overflow occurs during calculations
    error SXCEngine_ArithmeticOverflow();

    ///////////////////////
    // State Variables   //
    ///////////////////////

    /// @notice Maps each collateral token to its Chainlink price feed address
    mapping(address token => address priceFeed) private s_priceFeeds;
    /// @notice Tracks the amount of each collateral token deposited by each user
    mapping(address user => mapping(address token => uint256 amount)) private s_collateralDeposited;
    /// @notice Tracks the amount of SXC minted by each user
    mapping(address user => uint256 amountSxcMinted) private s_SXCMinted;
    /// @notice Array of all allowed collateral token addresses
    address[] private s_collateralTokens;
    /// @notice Additional precision for price feed calculations (10^10)
    uint256 private constant ADDITIONAL_FEED_PRECISION = 1e10;
    /// @notice General precision for calculations (10^18)
    uint256 private constant PRECISION = 1e18;
    /// @notice Liquidation threshold (50% = 200% overcollateralization requirement)
    uint256 private constant LIQUIDATION_THRESHOLD = 50;
    /// @notice Precision for liquidation calculations (100)
    uint256 private constant LIQUIDATION_PRECISION = 100;
    /// @notice Minimum health factor for a safe position (1.0 in 10^18 precision)
    uint256 private constant MIN_HEALTH_FACTOR = 1e18;
    /// @notice Reference to the StableXCoin (SXC) contract instance
    StableXCoin private immutable i_sxc;
    /// @notice Bonus percentage for liquidators (10%)
    uint256 private constant LIQUIDATION_BONUS = 10;

    ////////////////
    // Events     //
    ////////////////

    /// @notice Emitted when a user deposits collateral
    /// @param user The address of the user depositing collateral
    /// @param token The address of the collateral token
    /// @param amount The amount of collateral deposited
    event CollateralDeposited(address indexed user, address indexed token, uint256 indexed amount);
    /// @notice Emitted when collateral is redeemed
    /// @param redeemedFrom The address from which collateral is redeemed
    /// @param redeemTo The address receiving the collateral
    /// @param token The address of the collateral token
    /// @param amount The amount of collateral redeemed
    event CollateralRedeemed(
        address indexed redeemedFrom, address indexed redeemTo, address indexed token, uint256 amount
    );
    /// @notice Emitted when a user burns SXC to reduce debt
    /// @param user The address of the user burning SXC
    /// @param amount The amount of SXC burned
    event SxcBurned(address indexed user, uint256 amount);
    /// @notice Emitted when a user's position is liquidated
    /// @param user The address of the user being liquidated
    /// @param liquidator The address of the liquidator
    /// @param token The address of the collateral token
    /// @param debtCovered The amount of SXC debt covered
    /// @param collateralRedeemed The amount of collateral redeemed
    event Liquidation(
        address indexed user,
        address indexed liquidator,
        address indexed token,
        uint256 debtCovered,
        uint256 collateralRedeemed
    );

    ////////////////
    // Modifiers  //
    ////////////////

    /// @notice Ensures the amount is greater than zero
    /// @param amount The amount to check
    modifier moreThanZero(uint256 amount) {
        if (amount <= 0) revert SXCEngine_NeedsMoreThanZero();
        _;
    }

    /// @notice Ensures the token is approved for use as collateral
    /// @param token The address of the token to check
    modifier isAllowedToken(address token) {
        if (s_priceFeeds[token] == address(0)) revert SXCEngine_NotAllowedToken();
        _;
    }

    ////////////////
    // Functions  //
    ////////////////

    /**
     * @notice Initializes the SXCEngine with collateral tokens and their price feeds
     * @param tokenAddresses Array of allowed collateral token addresses (e.g., WETH, WBTC)
     * @param priceFeedAddresses Array of corresponding Chainlink price feed addresses
     * @param sxcAddress The address of the deployed StableXCoin contract
     * @dev Reverts if token and price feed arrays have different lengths
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

    /**
     * @notice Deposits collateral and mints SXC in a single transaction
     * @param tokenCollateralAddress The address of the collateral token
     * @param amountCollateral The amount of collateral to deposit (in token's smallest unit)
     * @param amountSxcToMint The amount of SXC to mint (in 18 decimals)
     * @dev Calls depositCollateral and mintSxc; requires prior ERC20 approval
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
     * @param tokenCollateralAddress The address of the ERC20 token to deposit
     * @param amountCollateral The amount of tokens to deposit
     * @dev Updates collateral balance, emits an event, and transfers tokens
     * @dev Uses modifiers for non-zero amounts, allowed tokens, and non-reentrancy
     */
    function depositCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        isAllowedToken(tokenCollateralAddress)
        nonReentrant
    {
        if (IERC20(tokenCollateralAddress).allowance(msg.sender, address(this)) < amountCollateral) {
            revert SXCEngine_InsufficientAllowance();
        }
        s_collateralDeposited[msg.sender][tokenCollateralAddress] += amountCollateral;
        emit CollateralDeposited(msg.sender, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transferFrom(msg.sender, address(this), amountCollateral);
        if (!success) revert SXCEngine_TransferFailed();
    }

    /**
     * @notice Redeems collateral and burns SXC in a single transaction
     * @param tokenCollateralAddress The address of the collateral token
     * @param amountCollateral The amount of collateral to redeem
     * @param amountSxcToBurn The amount of SXC to burn
     * @dev Ensures health factor remains valid after burning and redeeming
     */
    function redeemCollateralForDsc(address tokenCollateralAddress, uint256 amountCollateral, uint256 amountSxcToBurn)
        external
    {
        _revertIfHealthFactorIsBroken(msg.sender);
        _burnSxc(amountSxcToBurn, msg.sender, msg.sender);
        redeemCollateral(tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Redeems collateral from the system
     * @param tokenCollateralAddress The address of the collateral token
     * @param amountCollateral The amount of collateral to redeem
     * @dev Updates collateral balance and checks health factor
     */
    function redeemCollateral(address tokenCollateralAddress, uint256 amountCollateral)
        public
        moreThanZero(amountCollateral)
        nonReentrant
    {
        _redeemCollateral(msg.sender, msg.sender, tokenCollateralAddress, amountCollateral);
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Burns SXC to reduce a user's debt
     * @param amount The amount of SXC to burn
     * @dev Calls internal _burnSxc and checks health factor
     */
    function burnDsc(uint256 amount) external moreThanZero(amount) {
        _burnSxc(amount, msg.sender, msg.sender);
        _revertIfHealthFactorIsBroken(msg.sender);
        emit SxcBurned(msg.sender, amount);
    }

    /**
     * @notice Mints SXC for the caller
     * @param amountSxcToMint The amount of SXC to mint
     * @dev Updates minted SXC balance, checks health factor, and mints tokens
     */
    function mintSxc(uint256 amountSxcToMint) public moreThanZero(amountSxcToMint) nonReentrant {
        s_SXCMinted[msg.sender] += amountSxcToMint;
        _revertIfHealthFactorIsBroken(msg.sender);
        bool minted = i_sxc.mint(msg.sender, amountSxcToMint);
        if (!minted) revert SXCEngine_MintingFailed();
    }

    /**
     * @notice Liquidates an undercollateralized user's position
     * @param collateral The address of the collateral token
     * @param user The address of the user to liquidate
     * @param debtToCover The amount of SXC debt to cover
     * @dev Burns SXC from the liquidator and transfers collateral with a bonus
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
        _burnSxc(debtToCover, user, msg.sender);
        emit Liquidation(user, msg.sender, collateral, debtToCover, totalCollateralToRedeem);
        uint256 endingHealthFactor = _healthFactor(user);
        if (endingHealthFactor <= startingUserHealthFactor) {
            revert SXCEngine_HealthFactorNotImproved(endingHealthFactor);
        }
        _revertIfHealthFactorIsBroken(msg.sender);
    }

    /**
     * @notice Burns SXC on behalf of a user
     * @param amountSXCToBurn The amount of SXC to burn
     * @param onBehalfOf The address of the user whose SXC is burned
     * @param sxcFrom The address from which SXC is transferred
     * @dev Updates minted balance and burns SXC tokens
     */
    function _burnSxc(uint256 amountSXCToBurn, address onBehalfOf, address sxcFrom) private nonReentrant {
        if (s_SXCMinted[onBehalfOf] < amountSXCToBurn) revert SXCEngine_InsufficientSxcMinted();
        s_SXCMinted[onBehalfOf] -= amountSXCToBurn;
        bool success = i_sxc.transferFrom(sxcFrom, address(this), amountSXCToBurn);
        if (!success) revert SXCEngine_TransferFailed();
        i_sxc.burn(amountSXCToBurn);
    }

    /**
     * @notice Redeems collateral from one address to another
     * @param from The address from which collateral is redeemed
     * @param to The address receiving the collateral
     * @param tokenCollateralAddress The address of the collateral token
     * @param amountCollateral The amount of collateral to redeem
     * @dev Updates collateral balance and transfers tokens
     */
    function _redeemCollateral(address from, address to, address tokenCollateralAddress, uint256 amountCollateral)
        private
        nonReentrant
    {
        if (s_collateralDeposited[from][tokenCollateralAddress] < amountCollateral) {
            revert SXCEngine_InsufficientCollateral();
        }
        s_collateralDeposited[from][tokenCollateralAddress] -= amountCollateral;
        emit CollateralRedeemed(from, to, tokenCollateralAddress, amountCollateral);
        bool success = IERC20(tokenCollateralAddress).transfer(to, amountCollateral);
        if (!success) revert SXCEngine_TransferFailed();
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
        totalSxcMinted = s_SXCMinted[user];
        collateralValueInUsd = getAccountCollateralValue(user);
    }

    /**
     * @notice Calculates the health factor for a user
     * @param user The address of the user to check
     * @return The health factor (scaled by 1e18)
     * @dev Returns type(uint256).max if no SXC is minted
     */
    function _healthFactor(address user) private view returns (uint256) {
        (uint256 totalSxcMinted, uint256 collateralValueInUsd) = _getAccountInformation(user);
        if (totalSxcMinted == 0) return type(uint256).max;
        uint256 collateralAdjustedForThreshold = (collateralValueInUsd * LIQUIDATION_THRESHOLD) / LIQUIDATION_PRECISION;
        return (collateralAdjustedForThreshold * PRECISION) / totalSxcMinted;
    }

    /**
     * @notice Reverts if the user's health factor is below the minimum threshold
     * @param user The address of the user to check
     */
    function _revertIfHealthFactorIsBroken(address user) internal view {
        uint256 userHealthFactor = _healthFactor(user);
        if (userHealthFactor < MIN_HEALTH_FACTOR) revert SXCEngine_BreakHealthFactor(userHealthFactor);
    }

    /**
     * @notice Calculates the total USD value of a user's collateral
     * @param user The address of the user to query
     * @return totalCollateralValueInUsd The total USD value of the user's collateral
     */
    function getAccountCollateralValue(address user) public view returns (uint256 totalCollateralValueInUsd) {
        for (uint256 i = 0; i < s_collateralTokens.length; i++) {
            address token = s_collateralTokens[i];
            uint256 amount = s_collateralDeposited[user][token];
            totalCollateralValueInUsd += getUsdValue(token, amount);
        }
        return totalCollateralValueInUsd;
    }

    /**
     * @notice Converts a token amount to its USD value using the Chainlink price feed
     * @param token The address of the collateral token
     * @param amount The amount of tokens to convert
     * @return The USD value of the specified token amount (in 18 decimals)
     * @dev Uses ADDITIONAL_FEED_PRECISION to adjust for Chainlink's 8-decimal price feeds
     */
    function getUsdValue(address token, uint256 amount) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (price <= 0) revert SXCEngine_InvalidPrice();
        if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) revert SXCEngine_StalePrice();
        uint8 feedDecimals = priceFeed.decimals();
        uint256 feedPrecision = 10 ** uint256(feedDecimals);
        console.log(
            "getUsdValue: token=%s, price=%s, feedPrecision=%s, amount=%s", token, uint256(price), feedPrecision, amount
        );
        if (amount > 0 && uint256(price) > type(uint256).max / (ADDITIONAL_FEED_PRECISION * amount)) {
            revert SXCEngine_ArithmeticOverflow();
        }
        return ((uint256(price) * ADDITIONAL_FEED_PRECISION) * amount) / PRECISION;
    }

    /**
     * @notice Converts a USD amount to the equivalent token amount
     * @param usdAmountInWei The USD amount in 18 decimals
     * @param token The address of the collateral token
     * @return The equivalent amount of the token (in its smallest unit)
     * @dev Uses ADDITIONAL_FEED_PRECISION to adjust for Chainlink's 8-decimal price feeds
     */
    function getTokenAmountFromUsd(uint256 usdAmountInWei, address token) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(s_priceFeeds[token]);
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        if (price <= 0) revert SXCEngine_InvalidPrice();
        if (updatedAt == 0 || updatedAt < block.timestamp - 1 hours) revert SXCEngine_StalePrice();
        uint8 feedDecimals = priceFeed.decimals();
        uint256 feedPrecision = 10 ** uint256(feedDecimals);
        console.log(
            "getTokenAmountFromUsd: token=%s, price=%s, feedPrecision=%s, usdAmountInWei=%s",
            token,
            uint256(price),
            feedPrecision,
            usdAmountInWei
        );
        if (usdAmountInWei > 0 && usdAmountInWei > type(uint256).max / PRECISION) {
            revert SXCEngine_ArithmeticOverflow();
        }
        uint256 denominator = uint256(price) * ADDITIONAL_FEED_PRECISION;
        if (denominator == 0) revert SXCEngine_ArithmeticOverflow();
        return (usdAmountInWei * PRECISION) / denominator;
    }
}
