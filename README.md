# **StableXCoin: Decentralized Stablecoin Protocol** 💰

Dive into **StableXCoin**, a robust decentralized stablecoin protocol engineered for the Ethereum Virtual Machine. This project introduces a stable, USD-pegged cryptocurrency backed by **exogenous collateral** like WETH and WBTC. Inspired by the principles of overcollateralization and algorithmic stability, StableXCoin provides a secure and efficient way to interact with stable value within the decentralized finance landscape. 🛡️ It features a core engine for managing collateral, minting, burning, and a permissionless liquidation mechanism, all secured by Chainlink Price Feeds.

## 🚀 Installation

To get started with StableXCoin, you'll need the Foundry development toolchain installed. If you don't have it, follow the instructions on the official [Foundry Book](https://book.getfoundry.sh/getting-started/installation).

Once Foundry is set up, follow these steps:

*   **Clone the Repository**:
    ```bash
    git clone https://github.com/olujimiAdebakin/StableXCoin.git
    cd StableXCoin
    ```

*   **Install Dependencies**:
    The project uses Git submodules for external libraries like OpenZeppelin and Chainlink.
    ```bash
    forge install
    ```

*   **Build the Project**:
    Compile the smart contracts.
    ```bash
    forge build
    ```

*   **Run Tests (Optional but Recommended)**:
    Ensure everything is working as expected by running the included tests.
    ```bash
    forge test
    ```

## 🛠️ Usage

The StableXCoin protocol consists of two primary contracts: `StableXCoin.sol` (the ERC20 stablecoin itself) and `SXCEngine.sol` (the core logic for collateral management, minting, burning, and liquidation). The deployment process is handled by a Foundry script.

### Deploying to a Local Network (Anvil)

For local development and testing, you can deploy to a local Anvil instance.

1.  **Start an Anvil Node**:
    ```bash
    anvil
    ```
2.  **Deploy Contracts**:
    In a new terminal, with Anvil running, use the deployment script. This will automatically create mock price feeds and WETH/WBTC tokens for you.
    ```bash
    forge script script/DeploySXCEngine.s.sol --broadcast --fork-url http://localhost:8545
    ```
    This command will output the addresses of the deployed `StableXCoin` and `SXCEngine` contracts.

### Deploying to Sepolia Testnet

To deploy to Sepolia (or any other public testnet/mainnet), you'll need an RPC URL and a private key with funds.

1.  **Set Environment Variables**:
    Ensure your private key and Etherscan API key (for verification) are set as environment variables.
    ```bash
    export PRIVATE_KEY="0x..." # Your deployer private key
    export ETHERSCAN_API_KEY="..." # Your Etherscan API key for verification
    ```
2.  **Deploy Contracts**:
    ```bash
    forge script script/DeploySXCEngine.s.sol --rpc-url <YOUR_SEPOLIA_RPC_URL> --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_API_KEY
    ```
    Replace `<YOUR_SEPOLIA_RPC_URL>` with your actual Sepolia RPC endpoint (e.g., from Alchemy or Infura).

### Interacting with the Contracts

Once deployed, you can interact with the `SXCEngine` contract to:

*   **Deposit Collateral**: Deposit WETH or WBTC into the system.
*   **Mint SXC**: Generate StableXCoin by overcollateralizing your deposited assets.
*   **Burn SXC**: Repay your debt and reduce your minted SXC.
*   **Redeem Collateral**: Withdraw your collateral (after burning sufficient SXC).
*   **Liquidate Positions**: Anyone can liquidate undercollateralized positions to maintain system health.

You can use `cast` (Foundry's CLI tool), a dApp frontend, or a script to interact with the deployed contracts.

## ✨ Features

*   **Overcollateralized Stablecoin**: Backed by high-quality exogenous collateral assets (WETH, WBTC).
*   **Algorithmic Minting & Burning**: StableXCoin (SXC) can be minted against deposited collateral and burned to repay debt.
*   **Dynamic Health Factor Monitoring**: A robust system to calculate and monitor the collateralization health of user positions, ensuring system stability.
*   **Permissionless Liquidation Mechanism**: Allows anyone to liquidate undercollateralized positions, maintaining the protocol's solvency and offering a bounty to liquidators.
*   **Chainlink Price Feeds Integration**: Utilizes Chainlink's decentralized oracle networks for reliable and real-time asset pricing (ETH/USD, BTC/USD).
*   **Reentrancy Protection**: Employs OpenZeppelin's `ReentrancyGuard` to prevent common reentrancy attacks on critical functions.
*   **Modular Design**: Clear separation between the ERC20 token and the core engine logic for better maintainability and security.

## 💻 Technologies Used

| Category     | Technology          | Link                                                                      |
| :----------- | :------------------ | :------------------------------------------------------------------------ |
| **Language** | Solidity (0.8.24)   | [Solidity Docs](https://docs.soliditylang.org/)                           |
| **Framework**| Foundry             | [Foundry Book](https://book.getfoundry.sh/)                               |
| **Libraries**| OpenZeppelin        | [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/4.x/)    |
| **Oracles**  | Chainlink           | [Chainlink Docs](https://docs.chain.link/data-feeds/)                     |

## 👋 Contributing

Contributions are warmly welcomed! If you're interested in improving StableXCoin, please consider:

*   🐛 **Reporting Bugs**: Found an issue? Open a detailed issue on GitHub.
*   💡 **Suggesting Features**: Have an idea for a new feature or improvement? Let us know!
*   👨‍💻 **Submitting Pull Requests**:
    *   Fork the repository.
    *   Create a new branch for your feature or bug fix.
    *   Make your changes and write clear, concise commit messages.
    *   Ensure your code passes all tests (`forge test`) and builds successfully (`forge build`).
    *   Submit a pull request with a detailed description of your changes.

## 📄 License

This project is licensed under the **MIT License**. For more details, see the `LICENSE` file in the repository (if present) or refer to the SPDX-License-Identifier in the source code.

## 👤 Author Info

*   **Adebakin Olujimi**
    *   GitHub: [@olujimiAdebakin](https://github.com/olujimiAdebakin)
    *   LinkedIn: [Your LinkedIn Profile](https://linkedin.com/in/your_profile)
    *   Twitter: [@your_twitter_handle](https://twitter.com/your_twitter_handle)

---

[![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com/olujimiAdebakin/StableXCoin/actions)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen)](https://github.com/olujimiAdebakin/StableXCoin/actions)
![Solidity](https://img.shields.io/badge/Solidity-0.8.24-lightgrey?logo=solidity)
![Foundry](https://img.shields.io/badge/Made%20with-Foundry-blue?logo=foundry)
[![License](https://img.shields.io/badge/License-MIT-green)](https://opensource.org/licenses/MIT)

---

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)