// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title ERC20Mock
 * @notice A mock ERC20 token for testing purposes, allowing controlled minting, burning, and simulated transfer failures.
 * @dev Inherits from OpenZeppelin's ERC20.
 */
contract ERC20Mock is ERC20 {
    /// @notice Flag to control whether `transfer` and `transferFrom` functions should simulate failure.
    bool public transferShouldFail;

    /**
     * @notice Constructs a new ERC20Mock token.
     * @param name The name of the token.
     * @param symbol The symbol of the token.
     * @param initialAccount The address to which initial tokens will be minted.
     * @param initialBalance The amount of tokens to mint to `initialAccount` upon deployment.
     */
    constructor(string memory name, string memory symbol, address initialAccount, uint256 initialBalance)
        payable
        ERC20(name, symbol)
    {
        _mint(initialAccount, initialBalance);
    }

    /**
     * @notice Mints `amount` tokens to `account`.
     * @param account The address to receive the minted tokens.
     * @param amount The amount of tokens to mint.
     */
    function mint(address account, uint256 amount) public {
        _mint(account, amount);
    }

    /**
     * @notice Burns `amount` tokens from `account`.
     * @param account The address from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address account, uint256 amount) public {
        _burn(account, amount);
    }

    /**
     * @notice Internal transfer function for testing purposes.
     * @dev Directly calls the ERC20 `_transfer` internal function.
     * @param from The sender's address.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     */
    function transferInternal(address from, address to, uint256 value) public {
        _transfer(from, to, value);
    }

    /**
     * @notice Internal approve function for testing purposes.
     * @dev Directly calls the ERC20 `_approve` internal function.
     * @param owner The owner's address.
     * @param spender The spender's address.
     * @param value The amount to approve.
     */
    function approveInternal(address owner, address spender, uint256 value) public {
        _approve(owner, spender, value);
    }

    /**
     * @notice Sets the `transferShouldFail` flag.
     * @dev When `true`, subsequent calls to `transfer` and `transferFrom` will return `false`.
     * @param _shouldFail A boolean indicating whether transfers should fail (`true`) or succeed (`false`).
     */
    function setTransferShouldFail(bool _shouldFail) public {
        transferShouldFail = _shouldFail;
    }

    /**
     * @notice Overrides the standard ERC20 `transfer` function to optionally simulate failure.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     * @return A boolean indicating if the transfer was successful. Returns `false` if `transferShouldFail` is `true`.
     */
    function transfer(address to, uint256 value) public override returns (bool) {
        if (transferShouldFail) return false;
        return super.transfer(to, value);
    }

    /**
     * @notice Overrides the standard ERC20 `transferFrom` function to optionally simulate failure.
     * @param from The sender's address.
     * @param to The recipient's address.
     * @param value The amount to transfer.
     * @return A boolean indicating if the transfer was successful. Returns `false` if `transferShouldFail` is `true`.
     */
    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        if (transferShouldFail) return false;
        return super.transferFrom(from, to, value);
    }
}
