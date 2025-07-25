# **StableXCoin Protocol: Decentralized Stablecoin Engine 💰**

Welcome to the StableXCoin Protocol, a robust and secure decentralized stablecoin system! Inspired by the foundational principles of MakerDAO, this project introduces an overcollateralized stablecoin, SXC, designed to maintain its peg to the US Dollar. It achieves stability through a sophisticated engine that manages collateral deposits, SXC minting and burning, and a rigorous liquidation mechanism.

At its core, StableXCoin aims to provide a reliable and transparent digital asset, backed by exogenous collateral such as WETH and WBTC, ensuring algorithmic stability without relying on centralized governance or incurring operational fees.

## 🚀 Installation

Getting the StableXCoin Protocol up and running on your local machine is straightforward. Follow these steps to set up your development environment and interact with the contracts.

1.  **Clone the Repository**:
    Begin by cloning the project repository from GitHub:

    ```bash
    git clone https://github.com/olujimiAdebakin/StableXCoin.git
    cd StableXCoin
    ```

2.  **Install Foundry**:
    This project is built using [Foundry](https://getfoundry.sh/), a blazing fast, portable, and modular toolkit for Ethereum application development. If you don't have it installed, run:

    ```bash
    curl -L https://foundry.paradigm.xyz | bash
    foundryup
    ```

3.  **Install Dependencies**:
    The project leverages submodules for external libraries like OpenZeppelin and Chainlink. Initialize and update them:

    ```bash
    forge update
    ```

4.  **Build the Project**:
    Compile the smart contracts to ensure everything is set up correctly:

    ```bash
    forge build
    ```

## 🛠️ Usage

Interacting with the StableXCoin Protocol involves deploying the contracts and then using Foundry's `cast` or scripting capabilities to perform operations.

### Running Local Blockchain (Anvil)

To test and interact locally, you'll need a local blockchain. [Anvil](https://book.getfoundry.sh/anvil/) comes with Foundry and is perfect for this.

```bash
anvil
```

This will start a local Ethereum network on `http://127.0.0.1:8545`. Keep this terminal open.

### Deploying Contracts

In a new terminal, deploy the `StableXCoin` and `SXCEngine` contracts to your Anvil instance. The `DeploySXCEngine.s.sol` script handles this, including setting up mock price feeds and transferring ownership of `StableXCoin` to `SXCEngine`.

```bash
# Ensure your PRIVATE_KEY environment variable is set for Anvil's default private key
# export PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bac478cbed5ef604757088667ad1c59
# (The HelperConfig.s.sol uses DEFAULT_ANVIL_PRIVATE_KEY for Anvil, so no explicit env var needed if using that)

forge script script/DeploySXCEngine.s.sol --rpc-url http://localhost:8545 --broadcast --private-key <YOUR_ANVIL_PRIVATE_KEY_HERE>
```

Replace `<YOUR_ANVIL_PRIVATE_KEY_HERE>` with a private key from your Anvil output (e.g., `0xac0974bec39a17e36ba4a6b4d238ff945389dc9e86dae88c7a8412f4603b6b78690d`). The deployment output will provide the deployed addresses for `StableXCoin` and `SXCEngine`.

### Interacting with the Protocol

Once deployed, you can interact with the `SXCEngine` to manage collateral and SXC tokens.

#### 1. Deposit Collateral and Mint SXC

First, you'll need to approve the `SXCEngine` to spend your collateral tokens (e.g., WETH, WBTC). Then you can deposit them and mint SXC.

Example (using `cast` for interaction):

```bash
# Assuming you have the contract addresses from deployment output
# SXC_ENGINE_ADDRESS=0x...
# WETH_MOCK_ADDRESS=0x...
# WBTC_MOCK_ADDRESS=0x...
# Your own address (the one used for deployment)

# Approve SXCEngine to spend WETH
cast send $WETH_MOCK_ADDRESS "approve(address,uint256)" $SXC_ENGINE_ADDRESS 1000000000000000000000 # 1000 WETH, adjust as needed

# Deposit WETH and mint SXC (example: deposit 1 WETH, mint 100 SXC)
# You'll need to adjust amounts based on the mock price feeds set in HelperConfig
cast send $SXC_ENGINE_ADDRESS "depositCollateralAndMintSxc(address,uint256,uint256)" $WETH_MOCK_ADDRESS 1000000000000000000 # 1 WETH
100000000000000000000 # 100 SXC
```

#### 2. Burn SXC and Redeem Collateral

To reduce your debt or withdraw collateral, you can burn SXC.

```bash
# Approve SXCEngine to spend your SXC
cast send $(cast call $SXC_ENGINE_ADDRESS "getSxc()(address)") "approve(address,uint256)" $SXC_ENGINE_ADDRESS 50000000000000000000 # 50 SXC

# Burn 50 SXC and redeem some WETH (example: redeem 0.25 WETH)
cast send $SXC_ENGINE_ADDRESS "redeemCollateralForSxc(address,uint256,uint256)" $WETH_MOCK_ADDRESS 250000000000000000 # 0.25 WETH
50000000000000000000 # 50 SXC
```

#### 3. Check Health Factor

You can always check the health of your position:

```bash
cast call $SXC_ENGINE_ADDRESS "getHealthFactor(address)" <YOUR_ACCOUNT_ADDRESS>
```

#### 4. Run Tests

To ensure the protocol functions as expected, run the comprehensive test suite:

```bash
forge test -vvv
```

This will execute all unit and integration tests, providing detailed output.

## ✨ Features

The StableXCoin Protocol incorporates several key features to ensure a robust and secure stablecoin system:

*   **Overcollateralized Stablecoin (SXC)**: SXC is backed by more value in collateral than the amount minted, providing a strong buffer against price fluctuations.
*   **Multi-Collateral Support**: Accepts various approved ERC20 tokens (initially WETH and WBTC) as collateral, providing flexibility for users.
*   **Dynamic Health Factor Calculation**: Continuously monitors the collateralization ratio of user positions, ensuring they remain healthy and solvent.
*   **Algorithmic Minting & Burning**: SXC supply is adjusted programmatically based on collateral value and user demand, eliminating centralized control.
*   **Liquidation Mechanism**: Features an automated liquidation process for undercollateralized positions, maintaining the protocol's solvency and offering a bonus to liquidators.
*   **Secure Price Feeds**: Integrates Chainlink Price Feeds to get reliable, real-time prices for collateral assets, with built-in staleness checks to prevent attacks from outdated data.
*   **Robust Error Handling**: Comprehensive error messages and custom Solidity errors enhance debugging and user experience.
*   **SafeMath Integration**: Utilizes a `SafeMath` library to prevent common arithmetic overflow/underflow vulnerabilities, ensuring secure calculations.
*   **Reentrancy Protection**: Implements OpenZeppelin's `ReentrancyGuard` to prevent reentrancy attacks on critical functions.

## 💻 Technologies Used

This project leverages cutting-edge tools and frameworks in the blockchain development space:

| Technology         | Category           | Link                                                                        |
| :----------------- | :----------------- | :-------------------------------------------------------------------------- |
| **Solidity**       | Smart Contract     | [Solidity Lang](https://soliditylang.org/)                                  |
| **Foundry**        | Dev Toolchain      | [Foundry Book](https://book.getfoundry.sh/)                                 |
| **Forge**          | EVM Testing/Dev    | [Forge](https://book.getfoundry.sh/forge/)                                  |
| **Anvil**          | Local EVM          | [Anvil](https://book.getfoundry.sh/anvil/)                                  |
| **OpenZeppelin**   | Smart Contract Lib | [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/4.x/)      |
| **Chainlink**      | Oracles            | [Chainlink Docs](https://docs.chain.link/data-feeds/price-feeds/)           |
| **Hardhat**        | (Not used for dev, for future test) | [Hardhat](https://hardhat.org/)                                             |

## 🤝 Contributing

We welcome contributions to the StableXCoin Protocol! Whether it's reporting a bug, suggesting an enhancement, or submitting a pull request, your input is valuable.

*   🐛 **Bug Reports**: If you find any issues, please open an issue on GitHub with a clear description and steps to reproduce.
*   💡 **Feature Suggestions**: Have an idea for a new feature or improvement? Open an issue to discuss it.
*   🛠️ **Code Contributions**:
    *   Fork the repository.
    *   Create a new branch (`git checkout -b feature/your-feature-name`).
    *   Make your changes, ensuring code quality and adherence to existing patterns.
    *   Write or update tests to cover your changes.
    *   Ensure all tests pass (`forge test`).
    *   Commit your changes (`git commit -m 'feat: Add new awesome feature'`).
    *   Push to your fork (`git push origin feature/your-feature-name`).
    *   Open a pull request to the `main` branch, providing a detailed explanation of your changes.

Let's build the future of decentralized finance together!

## 📜 License

No license file was provided in the project context. Please add a `LICENSE` file if you intend to specify one.

## ✍️ Author Info

**Adebakin Olujimi**
*   LinkedIn: [https://linkedin.com/in/YOUR_LINKEDIN_USERNAME](https://linkedin.com/in/YOUR_LINKEDIN_USERNAME)
*   Twitter: [https://twitter.com/YOUR_TWITTER_USERNAME](https://twitter.com/YOUR_TWITTER_USERNAME)
*   Website: [https://YOUR_PERSONAL_WEBSITE.com](https://YOUR_PERSONAL_WEBSITE.com)

---

### Badges

![Solidity](https://img.shields.io/badge/Solidity-0.8.24-lightgrey?logo=solidity)
![Foundry](https://img.shields.io/badge/Tools-Foundry-blue?logo=foundry&logoColor=white)
![Build Status](https://img.shields.io/badge/Build-Passing-brightgreen?logo=github-actions&logoColor=white)

---
[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)