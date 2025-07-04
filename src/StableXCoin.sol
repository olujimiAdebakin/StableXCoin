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

pragma solidity 0.8.24;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/*
 * @title: StableXCoin
 * @notice: This is the ERC20 implementation of StableXCoin, a stablecoin system
 * @author: Adebakin Olujimi
 * @dev: This contract is meant to be governed by SXCEngine.
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Relative Stability: Pegged to USD
 *
 * This is the contract meant to be governed by SXCEngine. This contract is just the ERC20 implementation of our stablecoin system.
 */
/**
 * @title StableXCoin
 * @notice ERC20 implementation of a stablecoin pegged to USD, governed by SXCEngine.
 * @dev Inherits burnable functionality and ownership control. Minting restricted to owner.
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Stability: Pegged to USD
 */
contract StableXCoin is ERC20Burnable, Ownable {
    /// @notice Error thrown when trying to mint or burn an amount <= 0
    error StableXCoin_MUSTBeMoreThanZero();

    /// @notice Error thrown when trying to burn more tokens than balance
    error StableXCoin_BurnAmountExceedsBalance();

    /// @notice Error thrown when a zero address is used in a restricted context
    error StableXCoin_NotZeroAddress();

    /**
     * @notice Constructor that initializes the token with name and symbol
     */
    constructor() ERC20("StableXCoin", "SXC") Ownable(msg.sender) {}

    /**
     * @notice Burns tokens from the caller’s account
     * @param _amount The amount of tokens to burn
     * @dev Only the contract owner can call this. Checks for positive amount and sufficient balance.
     */
    function burn(uint256 _amount) public override onlyOwner {
        uint256 balance = balanceOf(msg.sender);

        if (_amount <= 0) {
            revert StableXCoin_MUSTBeMoreThanZero();
        }

        if (balance < _amount) {
            revert StableXCoin_BurnAmountExceedsBalance();
        }

        super.burn(_amount);
    }

    /**
     * @notice Mints new tokens to the specified address
     * @param _to The address to receive the newly minted tokens
     * @param _amount The amount of tokens to mint
     * @return success A boolean indicating the mint was successful
     * @dev Only the contract owner can call this. Prevents minting to the zero address and zero amount.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool success) {
        if (_to == address(0)) {
            revert StableXCoin_NotZeroAddress();
        }

        if (_amount <= 0) {
            revert StableXCoin_MUSTBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }

     function mintSxc() external{

     };
}
