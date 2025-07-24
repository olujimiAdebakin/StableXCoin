# StableX Protocol: A Decentralized Collateralized Stablecoin 🪙

Welcome to the StableX Protocol, an innovative and robust decentralized stablecoin system designed to maintain a soft peg to the US Dollar. Inspired by the principles of overcollateralization found in leading DeFi protocols, StableX provides a secure and transparent way to mint, manage, and redeem a stable digital asset, SXC (StableXCoin), backed by crypto-native collateral like WETH and WBTC.

This project showcases a foundational smart contract architecture for a fully algorithmic stablecoin, emphasizing security, capital efficiency, and a clear liquidation mechanism. It's built with Foundry, ensuring a modern and efficient development workflow.

## Table of Contents

*   [Overview](#stablex-protocol-a-decentralized-collateralized-stablecoin-)
*   [Key Features](#key-features)
*   [Technologies Used](#technologies-used)
*   [Installation](#installation)
*   [Usage](#usage)
*   [Contributing](#contributing)
*   [License](#license)
*   [Author Info](#author-info)
*   [Badges](#badges)

## Key Features

*   **Overcollateralized Stablecoin (SXC)**: Issues SXC tokens backed by a higher value of deposited collateral (e.g., WETH, WBTC) than the value of minted SXC, providing a robust safety margin.
*   **Dual-Token System**: Features the StableXCoin (SXC) as the stable token and a core SXCEngine contract managing the entire protocol logic.
*   **Multiple Collateral Support**: Integrates with Chainlink Price Feeds to enable diverse collateral types (WETH, WBTC) with real-time price accuracy.
*   **Dynamic Health Factor**: Continuously assesses the collateralization ratio of user positions, flagging undercollateralized positions for potential liquidation.
*   **Automated Liquidation Mechanism**: Allows liquidators to repay a portion of unhealthy debt in exchange for discounted collateral plus a bonus, maintaining protocol solvency.
*   **Atomic Operations**: Supports combined deposit/mint and redeem/burn transactions for user convenience and capital efficiency.
*   **Reentrancy Protection**: Employs OpenZeppelin's `ReentrancyGuard` to prevent common reentrancy attacks.
*   **Robust Error Handling**: Comprehensive custom error messages for improved debugging and user experience.
*   **Modular Design**: Separates the ERC20 stablecoin logic from the core financial engine for clarity and maintainability.

## Technologies Used

| Category         | Technology                 | Description                                    |
| :--------------- | :------------------------- | :--------------------------------------------- |
| **Smart Contracts** | [Solidity](https://soliditylang.org/) | The primary language for smart contract development. |
| **Development Framework** | [Foundry](https://getfoundry.sh/) | A blazing fast, portable, and modular toolkit for Ethereum application development. |
| **Oracles**      | [Chainlink](https://chain.link/) | Decentralized oracle networks providing real-world data to smart contracts. |
| **Libraries**    | [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/4.x/) | Secure and audited smart contract libraries for common functionalities. |
| **Utilities**    | [SafeMath](https://docs.openzeppelin.com/contracts/2.x/api/math#SafeMath) | A custom implementation for safe arithmetic operations, preventing overflows/underflows. |

## Installation

To set up the StableX Protocol locally and interact with its smart contracts, follow these steps:

### 1. Clone the Repository

First, clone the project repository to your local machine:

```bash
git clone https://github.com/olujimiAdebakin/StableXCoin.git
cd StableXCoin
```

### 2. Install Foundry

If you don't have Foundry installed, use the following command:

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

This will install `forge` and `cast`, the Foundry command-line tools.

### 3. Install Dependencies

The project uses git submodules for external libraries like OpenZeppelin and Chainlink. Initialize and update them:

```bash
forge install
```

### 4. Build the Project

Compile the smart contracts:

```bash
forge build
```

### 5. Run Tests

To ensure everything is working correctly and to understand the contract's behavior, run the tests:

```bash
forge test
```

You can also run a more detailed coverage report to see which parts of the code are covered by tests:

```bash
forge coverage
```

## Usage

Interacting with the StableX Protocol involves deploying the `StableXCoin` and `SXCEngine` contracts and then calling their respective functions. For development, you'll typically interact with a local Anvil instance.

### 1. Start a Local Blockchain (Anvil)

Open a new terminal and start an Anvil instance:

```bash
anvil
```

This will run a local blockchain on `http://127.0.0.1:8545` with some default funded accounts.

### 2. Deploy Contracts

The `DeploySXCEngine.s.sol` script handles the deployment of `StableXCoin` and `SXCEngine`, setting up mock price feeds and transferring ownership.

To deploy on your local Anvil instance:

```bash
forge script script/DeploySXCEngine.s.sol --broadcast --rpc-url http://127.0.0.1:8545 --private-key YOUR_PRIVATE_KEY
```

Replace `YOUR_PRIVATE_KEY` with one of the private keys provided by Anvil (e.g., `0xac0974...`). The script will output the deployed contract addresses.

### 3. Interact with the Contracts (Example Flow)

Once deployed, you can interact with the `SXCEngine` and `StableXCoin` contracts. Here's a simplified example flow using `cast`, Foundry's CLI tool for EVM interactions:

*   **Get Contract Addresses**:
    After deployment, note down the `SXCEngine` and `StableXCoin` addresses from the console output. Let's assume:
    `SXCEngineAddress = 0x...`
    `StableXCoinAddress = 0x...`
    `WETHMockAddress = 0x...` (one of your collateral tokens)

*   **Approve Collateral**:
    Before depositing WETH, you need to approve the `SXCEngine` contract to spend your WETH tokens.

    ```bash
    cast send --rpc-url http://127.0.0.1:8545 --private-key YOUR_PRIVATE_KEY \
        $WETHMockAddress "approve(address,uint256)" $SXCEngineAddress $(cast --to-wei 1000 ether)
    ```

*   **Deposit Collateral and Mint SXC**:
    Deposit, say, 1000 WETH and mint 5000 SXC (adjust amounts based on mock prices and desired collateralization ratio).

    ```bash
    cast send --rpc-url http://127.0.0.1:8545 --private-key YOUR_PRIVATE_KEY \
        $SXCEngineAddress "depositCollateralAndMintSxc(address,uint256,uint256)" \
        $WETHMockAddress $(cast --to-wei 1000 ether) $(cast --to-wei 5000 ether)
    ```

*   **Check Your Health Factor**:
    Ensure your position is healthy after minting. A value above `1e18` (1.0) is healthy.

    ```bash
    cast call --rpc-url http://127.0.0.1:8545 \
        $SXCEngineAddress "getHealthFactor(address)" $YOUR_ADDRESS
    ```

*   **Burn SXC and Redeem Collateral**:
    To reduce your debt and retrieve collateral, you can burn SXC. First, approve the `SXCEngine` to spend your SXC.

    ```bash
    cast send --rpc-url http://127.0.0.1:8545 --private-key YOUR_PRIVATE_KEY \
        $StableXCoinAddress "approve(address,uint256)" $SXCEngineAddress $(cast --to-wei 1000 ether)
    ```

    Then, redeem collateral and burn SXC. (Note: the `redeemCollateralForSxc` function does the burning and redeeming in one go).

    ```bash
    cast send --rpc-url http://127.0.0.1:8545 --private-key YOUR_PRIVATE_KEY \
        $SXCEngineAddress "redeemCollateralForSxc(address,uint256,uint256)" \
        $WETHMockAddress $(cast --to-wei 500 ether) $(cast --to-wei 1000 ether)
    ```

*   **Liquidate an Unhealthy Position**:
    If a position becomes unhealthy (health factor < 1.0), a liquidator can cover some of the debt and receive discounted collateral. This requires an account different from the one with the unhealthy position.

    1.  **Make a position unhealthy** (e.g., simulate a price crash of WETH by calling `updateAnswer` on the mock WETH price feed).
    2.  **Liquidator approves SXC spending** to the SXCEngine.
    3.  **Liquidator calls `liquidate`**.

    ```bash
    cast send --rpc-url http://127.0.0.1:8545 --private-key LIQUIDATOR_PRIVATE_KEY \
        $SXCEngineAddress "liquidate(address,address,uint256)" \
        $WETHMockAddress $UNHEALTHY_USER_ADDRESS $(cast --to-wei 500 ether)
    ```

This provides a basic outline. For more in-depth interactions, you would typically build a decentralized application (DApp) frontend or write more complex scripts.

## Contributing

We welcome contributions to the StableX Protocol! Whether it's reporting bugs, suggesting new features, or submitting code, your input is highly valued.

Here's how you can contribute:

1.  ✨ **Fork the repository**: Start by forking the `StableXCoin` repository on GitHub.
2.  🌱 **Clone your fork**: Clone your forked repository to your local machine.
3.  🌿 **Create a new branch**: For each contribution, create a new branch from `main` with a descriptive name (e.g., `feature/add-new-collateral`, `fix/health-factor-bug`).
4.  💻 **Make your changes**: Implement your features or bug fixes.
5.  ✅ **Write and run tests**: Ensure your changes are well-tested. Run `forge test` to verify existing functionality and add new tests for your contributions.
6.  📝 **Format your code**: Maintain consistency using Foundry's formatter: `forge fmt`.
7.  💬 **Commit your changes**: Write clear and concise commit messages.
8.  🚀 **Push to your branch**: Push your local branch to your forked repository.
9.  🔄 **Open a Pull Request**: Submit a pull request from your branch to the `main` branch of the original `StableXCoin` repository. Provide a detailed description of your changes.

## License

This project is licensed under the [MIT License](https://spdx.org/licenses/MIT.html).

## Author Info

👋 Hi, I'm Adebakin Olujimi, the author of the StableX Protocol. I'm passionate about building robust and secure decentralized systems.

Feel free to connect with me!

*   LinkedIn: [Your LinkedIn Profile](https://linkedin.com/in/your-username)
*   Twitter: [Your Twitter Handle](https://twitter.com/your-username)

## Badges

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-lightgrey)](https://getfoundry.sh/)
[![Solidity v0.8.24](https://img.shields.io/badge/Solidity-0.8.24-blue)](https://soliditylang.org/)
[![Chainlink Oracles](https://img.shields.io/badge/Powered%20By-Chainlink-green)](https://chain.link/)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)