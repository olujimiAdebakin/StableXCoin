**StableX: A Decentralized Stablecoin Protocol 🪙**

StableX is a robust, decentralized, and overcollateralized stablecoin system built on the Ethereum blockchain. It's designed to maintain a soft peg to the U.S. Dollar (USD), offering a reliable and censorship-resistant digital currency. Think of it as a streamlined, self-contained version of systems like MakerDAO, but with a focus on simplicity: no complex governance tokens or variable stability fees.

This protocol ensures that at all times, the total USD value of all deposited collateral (like WETH and WBTC) significantly exceeds the total supply of StableXCoin (SXC) in circulation. This overcollateralization is key to maintaining the system's stability and security.

## Installation

Getting StableX up and running on your local machine is straightforward. Here’s how you can do it:

### Prerequisites

Before you begin, ensure you have [Foundry](https://getfoundry.sh/) installed. Foundry is a blazing-fast, portable, and modular toolkit for Ethereum application development written in Rust.

```bash
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### Clone the Repository

Start by cloning the StableX repository to your local machine:

```bash
git clone https://github.com/olujimiAdebakin/StableXCoin.git
cd StableXCoin
```

### Install Dependencies

StableX leverages several external libraries for secure and efficient smart contract operations. Use Forge to install them:

```bash
forge update
```

### Compile the Contracts

Once dependencies are in place, compile the Solidity contracts:

```bash
forge build
```

And just like that, you're ready to dive into the StableX protocol!

## Usage

StableX is a powerful financial primitive, and here’s how you can interact with its core functionalities:

### Running Tests

To ensure the integrity and reliability of the StableX protocol, comprehensive unit and integration tests are included. You can run them using Forge:

```bash
forge test
```

This command will execute all test cases defined in the `test/` directory, providing confidence in the contract's logic and behavior.

### Deploying to a Local Network (Anvil)

For local development and testing, you can deploy the contracts to an Anvil instance (Foundry's local blockchain):

1.  **Start Anvil**: Open a new terminal and run:
    ```bash
    anvil
    ```
    This will start a local blockchain and display its RPC URL and default private keys.

2.  **Deploy Contracts**: In your project directory, execute the deployment script. The `HelperConfig.s.sol` script intelligently uses mock Chainlink feeds and ERC20 tokens for local networks, or real Sepolia addresses when deployed there.

    ```bash
    forge script script/DeploySXCEngine.s.sol:DeploySXCEngine --rpc-url http://127.0.0.1:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d --broadcast
    ```
    *(Note: The private key shown here is Anvil's default deployer key. For real networks, you would use an environment variable.)*

### Interacting with Deployed Contracts

Once deployed, you can interact with the `SXCEngine` and `StableXCoin` contracts using `cast` (Foundry's CLI tool) or any web3 library (e.g., Ethers.js, Web3.js).

For example, to check a user's health factor after deployment:

```bash
# First, get the deployed SXCEngine address from your deployment output
# Let's assume SXCE_ENGINE_ADDRESS is the address you obtained
# And USER_ADDRESS is the address you want to query

cast call $SXCE_ENGINE_ADDRESS "getHealthFactor()(uint256)" --from $USER_ADDRESS --rpc-url http://127.0.0.1:8545
```

This allows for seamless testing of all deposit, mint, redeem, burn, and liquidation functionalities.

## Features

StableX offers a secure and efficient mechanism for decentralized stablecoin operations:

*   🌐 **Overcollateralized Debt Positions**: Ensures that the value of collateral always surpasses the minted SXC, providing a robust peg.
*   🔗 **Dynamic Price Feeds**: Integrates Chainlink's reliable oracle networks to fetch real-time, decentralized price data for collateral assets (WETH, WBTC).
*   🛡️ **Liquidation Mechanism**: Features an automated liquidation process for undercollateralized positions, maintaining the system's health.
*   💰 **ERC-20 Compliant Stablecoin**: The StableXCoin (SXC) token adheres to the ERC-20 standard, ensuring broad compatibility across the Ethereum ecosystem.
*   ⚙️ **Simplified Design**: By excluding governance tokens and complex fee structures, StableX focuses on core stablecoin functionality.
*   🔄 **Automated Minting & Burning**: The SXCEngine programmatically handles the issuance and destruction of SXC based on user deposits and debt repayment.

## Technologies Used

| Technology     | Description                                                                                             |
| :------------- | :------------------------------------------------------------------------------------------------------ |
| Solidity       | The primary programming language for writing smart contracts on the Ethereum blockchain.                |
| Foundry        | A modern, fast, and feature-rich toolkit for Ethereum development, including `forge` and `cast`.        |
| Chainlink      | Provides decentralized oracle networks, essential for fetching reliable real-world asset prices.        |
| OpenZeppelin   | Offers battle-tested, secure, and community-audited smart contract libraries, enhancing security.       |

## Contributing

We welcome contributions to the StableX project! If you're interested in improving this protocol, here's how you can get started:

🌱 **Fork the Repository**: Begin by forking the StableXCoin repository to your GitHub account.

👯 **Clone Your Fork**: Clone your forked repository to your local machine.

🚀 **Create a New Branch**: Always create a new branch for your features or bug fixes. Use descriptive names (e.g., `feature/add-new-collateral`, `fix/health-factor-bug`).

💡 **Implement Your Changes**: Write clean, well-documented code that adheres to the existing style.

🧪 **Write Tests**: Ensure your changes are covered by comprehensive unit and integration tests. All new features or bug fixes should come with corresponding tests.

✅ **Run Tests**: Before submitting, run all tests (`forge test`) to make sure everything passes.

📝 **Commit Your Changes**: Write clear and concise commit messages.

⬆️ **Push to Your Fork**: Push your new branch to your forked repository.

🔄 **Open a Pull Request**: Submit a pull request to the `main` branch of the original repository. Please describe your changes thoroughly and reference any relevant issues.

We appreciate your efforts in making StableX even better!

## License

This project is licensed under the MIT License. For more details, please refer to the SPDX license identifier at the top of the source files.

## Author Info

**Adebakin Olujimi**

Connect with me and see more of my work:

*   🐦 [Twitter](https://twitter.com/your_twitter_handle)
*   🐙 [GitHub](https://github.com/olujimiAdebakin)
*   💼 [LinkedIn](https://www.linkedin.com/in/your_linkedin_profile)

---

[![Solidity](https://img.shields.io/badge/Solidity-0.8.24-lightgrey)](https://soliditylang.org/)
[![Foundry](https://img.shields.io/badge/Powered%20by-Foundry-blue)](https://getfoundry.sh/)
[![Tests](https://img.shields.io/badge/Tests-Passing-brightgreen)](https://getfoundry.sh/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](https://opensource.org/licenses/MIT)
[![Last Commit](https://img.shields.io/github/last-commit/olujimiAdebakin/StableXCoin?color=yellow)](https://github.com/olujimiAdebakin/StableXCoin)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)