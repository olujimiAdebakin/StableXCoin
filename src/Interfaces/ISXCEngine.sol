// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/**
 * @title ISXCEngine
 * @notice Interface for the SXC Engine contract that governs minting, burning, collateral deposits, and liquidation logic for StableXCoin.
 */
interface ISXCEngine {
    /// @notice Deposit collateral and immediately mint DSC
    // function depositCollateralAndMintDsc() external;

    /// @notice Deposit collateral only
    function depositCollateral() external;

    /// @notice Redeem collateral and burn DSC in a single transaction
    function redeemCollateralForDsc() external;

    /// @notice Redeem only collateral (likely in excess position)
    function redeemCollateral() external;

    /// @notice Mint DSC from posted collateral
    function mintSxc() external;

    /// @notice Burn DSC to reduce debt position
    function burnDsc() external;

    /// @notice Liquidate an unhealthy position
    function liquidate() external;

    /// @notice Get the health factor of a user/account
    function getHealthFactor() external view returns (uint256);
}
