// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20, ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title StableXCoin
 * @notice ERC20 implementation of a stablecoin pegged to USD, governed by SXCEngine.
 * @dev Inherits burnable functionality and ownership control. Minting restricted to owner.
 * Collateral: Exogenous (ETH & BTC)
 * Minting: Algorithmic
 * Stability: Pegged to USD
 */
contract StableXCoin is ERC20Burnable, Ownable {
    /// @notice Error thrown when trying to mint or burn an amount less than or equal to 0.
    error StableXCoin_MUSTBeMoreThanZero();

    /// @notice Error thrown when trying to burn more tokens than the account's balance.
    error StableXCoin_BurnAmountExceedsBalance();

    /// @notice Error thrown when a zero address is used in a restricted context (e.g., minting to address(0)).
    error StableXCoin_NotZeroAddress();

    /// @notice Flag to control whether `transferFrom` function should simulate failure for testing.
    bool public transferShouldFail;

    /// @notice Flag to control whether `mint` function should simulate failure for testing.
    bool public mintShouldFail;

    /**
     * @notice Constructor that initializes the token with name "StableXCoin", symbol "SXC",
     * and sets the deployer as the initial owner.
     */
    constructor() ERC20("StableXCoin", "SXC") Ownable(msg.sender) {}

    /**
     * @notice Sets the `transferShouldFail` flag.
     * @dev Only the contract owner can call this. When `true`, subsequent calls to `transferFrom` will return `false`.
     * @param _shouldFail A boolean indicating whether `transferFrom` should fail (`true`) or succeed (`false`).
     */
    function setTransferShouldFail(bool _shouldFail) public onlyOwner {
        transferShouldFail = _shouldFail;
    }

    /**
     * @notice Overrides the standard ERC20 `transferFrom` function to optionally simulate failure.
     * @param from The sender's address.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     * @return A boolean indicating if the transfer was successful. Returns `false` if `transferShouldFail` is `true`.
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (transferShouldFail) return false; // Simulate failure
        return super.transferFrom(from, to, value);
    }

    /**
     * @notice Burns `_amount` tokens from the caller’s account.
     * @dev Only the contract owner can call this. Checks for positive amount and sufficient balance.
     * @param _amount The amount of tokens to burn.
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
     * @notice Sets the `mintShouldFail` flag.
     * @dev Only the contract owner can call this. When `true`, subsequent calls to `mint` will return `false`.
     * @param _shouldFail A boolean indicating whether `mint` should fail (`true`) or succeed (`false`).
     */
    function setMintShouldFail(bool _shouldFail) public onlyOwner {
        mintShouldFail = _shouldFail;
    }

    /**
     * @notice Mints new tokens to the specified address.
     * @dev Only the contract owner can call this. Prevents minting to the zero address and zero amount.
     * @param _to The address to receive the newly minted tokens.
     * @param _amount The amount of tokens to mint.
     * @return success A boolean indicating if the mint was successful. Returns `false` if `mintShouldFail` is `true`.
     */
    function mint(address _to, uint256 _amount) external onlyOwner returns (bool success) {
        if (mintShouldFail) return false; // Simulate failure

        if (_to == address(0)) {
            revert StableXCoin_NotZeroAddress();
        }

        if (_amount <= 0) {
            revert StableXCoin_MUSTBeMoreThanZero();
        }

        _mint(_to, _amount);
        return true;
    }
}
