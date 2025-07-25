# **StableXCoin Protocol** 💲

StableXCoin is a robust, decentralized, and overcollateralized stablecoin protocol designed to maintain a stable peg to the US Dollar. Inspired by the resilience and mechanics of systems like MakerDAO, StableXCoin empowers users to mint synthetic USD-pegged tokens (SXC) by depositing approved crypto assets as collateral. This project emphasizes security, transparency, and a clear liquidation mechanism, aiming to provide a reliable on-chain stable asset without the complexities of governance or recurring fees.

## ✨ **Key Features**

*   **Overcollateralized Stablecoin**: Users mint `SXC` against a higher value of deposited collateral, ensuring robust backing and stability.
*   **Multi-Collateral Support**: Currently supports WETH and WBTC as collateral types, with extensibility to include more assets.
*   **Dynamic Health Factor**: Continuously monitors the collateralization ratio of user positions, providing real-time insights into risk levels.
*   **Automated Liquidation Mechanism**: Positions falling below a predefined health factor are subject to liquidation, maintaining protocol solvency and stability.
*   **Chainlink Price Feeds**: Leverages Chainlink decentralized oracle networks for accurate and up-to-date collateral asset pricing, including stale price checks.
*   **Secure Arithmetic Operations**: Integrates a custom `SafeMath` library to prevent common Solidity arithmetic vulnerabilities like overflows and underflows.
*   **Reentrancy Guard**: Utilizes OpenZeppelin's `ReentrancyGuard` to protect critical functions from reentrancy attacks.
*   **Permissioned Minting/Burning**: `StableXCoin` is governed by `SXCEngine`, centralizing control over `SXC` supply to maintain peg stability.

## 🚀 **Technologies Used**

| Technology       | Description                                                                                                                                                                                                                                                                                               | Link                                                                  |
| :--------------- | :-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :-------------------------------------------------------------------- |
| **Solidity**     | The primary programming language for smart contracts, version 0.8.24, ensuring modern syntax and security features.                                                                                                                                                                                          | [Solidity Docs](https://docs.soliditylang.org/en/latest/)             |
| **Foundry**      | A blazing fast, portable, and modular toolkit for Ethereum application development, written in Rust. Used for testing, deployment, and scripting.                                                                                                                                                          | [Foundry Book](https://book.getfoundry.sh/)                           |
| **Chainlink**    | Decentralized oracle network that provides real-world data to smart contracts, crucial for collateral price feeds.                                                                                                                                                                                        | [Chainlink Docs](https://docs.chain.link/data-feeds/)                 |
| **OpenZeppelin** | A library of battle-tested smart contracts for secure development, including ERC20, Ownable, and ReentrancyGuard, enhancing the reliability and security of the protocol.                                                                                                                                   | [OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/5.x/) |
| **Git**          | Distributed version control system used for managing source code history and collaboration, with submodules for external dependencies.                                                                                                                                                                  | [Git Docs](https://git-scm.com/doc)                                   |

## 🛠️ **Installation**

To get a copy of this project up and running on your local machine, follow these simple steps.

### Prerequisites

Before you begin, ensure you have the following installed:

*   **Git**: For cloning the repository.
*   **Foundry**: The development toolkit used for this project. Follow the installation instructions [here](https://book.getfoundry.sh/getting-started/installation).

### Step-by-step Guide

1.  **Clone the Repository**:
    Begin by cloning the project repository to your local machine using Git:

    ```bash
    git clone https://github.com/olujimiAdebakin/StableXCoin.git
    cd StableXCoin
    ```

2.  **Install Foundry Dependencies**:
    This project uses Foundry's submodule functionality for external libraries. Initialize and update these submodules:

    ```bash
    forge update
    ```
    This command will fetch `forge-std`, `openzeppelin-contracts`, and `chainlink` libraries.

3.  **Build the Project**:
    Compile the smart contracts to ensure everything is set up correctly:

    ```bash
    forge build
    ```

    If the build is successful, you're ready to interact with the contracts!

## 💡 **Usage**

Interacting with the StableXCoin protocol typically involves deploying the contracts and then executing various functions.

### Local Development and Testing

For rapid development and testing, Foundry's local `anvil` chain is incredibly useful.

1.  **Start a Local Anvil Node**:
    Open a new terminal and run:

    ```bash
    anvil
    ```
    This will start a local blockchain instance on `http://127.0.0.1:8545`. Keep this terminal running.

2.  **Run Tests**:
    In another terminal, you can execute all the project tests:

    ```bash
    forge test
    ```
    To get a more detailed output, including traces, use:
    ```bash
    forge test -vvvv
    ```

### Deploying Contracts

The `DeploySXCEngine.s.sol` script handles the deployment of `StableXCoin` and `SXCEngine`. It uses `HelperConfig.s.sol` to fetch network-specific addresses (Chainlink price feeds, WETH/WBTC) or deploy mocks on a local development chain.

**To deploy locally (e.g., to Anvil):**

```bash
forge script script/DeploySXCEngine.s.sol --broadcast --rpc-url http://127.0.0.1:8545
```

This command will deploy the `StableXCoin` and `SXCEngine` contracts to your local Anvil instance. The script will output the deployed contract addresses.

**To deploy to a public testnet (e.g., Sepolia):**

First, ensure your `PRIVATE_KEY` environment variable is set. For example:
```bash
export PRIVATE_KEY=<YOUR_PRIVATE_KEY>
```
Then, execute the deployment script, specifying the Sepolia RPC URL:
```bash
forge script script/DeploySXCEngine.s.sol --rpc-url https://rpc.sepolia.org --broadcast --verify --etherscan-api-key <YOUR_ETHERSCAN_API_KEY> -vvvv
```
Remember to replace `<YOUR_ETHERSCAN_API_KEY>` with your actual Etherscan API key for contract verification.

### Interacting with the Deployed Protocol

Once deployed, you can interact with the `SXCEngine` and `StableXCoin` contracts. Here's a conceptual flow of how a user would interact:

1.  **Acquire Collateral Tokens (e.g., WETH, WBTC)**:
    On a testnet, you'd get testnet WETH/WBTC. On Anvil, `HelperConfig` deploys mock tokens and mints some to the deployer.

2.  **Approve `SXCEngine` to Spend Collateral**:
    Before depositing, you must approve the `SXCEngine` contract to transfer your collateral tokens.
    ```solidity
    IERC20(WETH_ADDRESS).approve(address(SXCEngine_ADDRESS), AMOUNT_TO_APPROVE);
    ```

3.  **Deposit Collateral and Mint SXC**:
    Users can deposit collateral and simultaneously mint `SXC`.
    ```solidity
    SXCEngine_ADDRESS.depositCollateralAndMintSxc(WETH_ADDRESS, AMOUNT_WETH, AMOUNT_SXC_TO_MINT);
    ```
    Alternatively, deposit first:
    ```solidity
    SXCEngine_ADDRESS.depositCollateral(WETH_ADDRESS, AMOUNT_WETH);
    ```
    Then mint:
    ```solidity
    SXCEngine_ADDRESS.mintSxc(AMOUNT_SXC_TO_MINT);
    ```

4.  **Check Your Health Factor**:
    Monitor the safety of your position. A healthy position has a health factor `>= 1e18` (or 1.0).
    ```solidity
    uint256 healthFactor = SXCEngine_ADDRESS.getHealthFactor(YOUR_ADDRESS);
    ```

5.  **Burn SXC to Reduce Debt**:
    To reduce your `SXC` debt, you can burn `SXC` tokens. This improves your health factor.
    ```solidity
    // Approve SXCEngine to burn your SXC first if not already done
    SXC_ADDRESS.approve(address(SXCEngine_ADDRESS), AMOUNT_SXC_TO_BURN);
    SXCEngine_ADDRESS.burnSxc(AMOUNT_SXC_TO_BURN);
    ```

6.  **Redeem Collateral**:
    If your position is overcollateralized or you've burned enough `SXC`, you can withdraw deposited collateral.
    ```solidity
    SXCEngine_ADDRESS.redeemCollateral(WETH_ADDRESS, AMOUNT_WETH_TO_REDEEM);
    ```
    Or redeem collateral and burn `SXC` atomically:
    ```solidity
    SXCEngine_ADDRESS.redeemCollateralForSxc(WETH_ADDRESS, AMOUNT_WETH_TO_REDEEM, AMOUNT_SXC_TO_BURN);
    ```

7.  **Liquidate an Unhealthy Position**:
    If a user's health factor drops below the minimum threshold, anyone can liquidate their position by covering a portion of their debt in `SXC` and receiving discounted collateral.
    ```solidity
    // Liquidator must have SXC and approve SXCEngine to spend it
    SXC_ADDRESS.approve(address(SXCEngine_ADDRESS), DEBT_TO_COVER);
    SXCEngine_ADDRESS.liquidate(COLLATERAL_ADDRESS_OF_UNHEALTHY_USER, UNHEALTHY_USER_ADDRESS, DEBT_TO_COVER);
    ```

## 🤝 **Contributing**

Contributions are warmly welcomed! If you're passionate about decentralized finance and robust stablecoin mechanisms, here's how you can help improve StableXCoin:

1.  ✨ **Fork the Repository**: Start by forking the `StableXCoin` repository to your GitHub account.
2.  🌿 **Create a New Branch**: Create a dedicated branch for your feature or bug fix. Use descriptive names like `feat/add-new-collateral` or `fix/health-factor-bug`.
3.  ✍️ **Make Your Changes**: Implement your changes, ensuring code quality and adherence to existing patterns.
4.  🧪 **Write Tests**: Add or update tests to cover your new features or bug fixes. Comprehensive testing is crucial for smart contracts.
5.  ✅ **Ensure All Tests Pass**: Before submitting, run `forge test` to confirm all existing and new tests pass successfully.
6.  📜 **Update Documentation**: If your changes affect the protocol's functionality or usage, please update the relevant documentation.
7.  ✉️ **Submit a Pull Request**: Push your changes to your fork and open a pull request against the `main` branch of the original repository. Clearly describe your changes and their purpose.

We appreciate your effort in making StableXCoin more secure and functional for everyone!

## 📄 **License**

This project is licensed under the MIT License. While an explicit `LICENSE` file is not included in this repository's root, the SPDX license identifier `MIT` is specified within the source code files. This indicates that the code is free to be used, modified, and distributed, provided the original copyright and license notice are included.

## ✍️ **Author Info**

**Adebakin Olujimi**

*   **LinkedIn**: [My LinkedIn Profile]((https://www.linkedin.com/in/adebakin-olujimi-25446331b/))
*   **Twitter**: [My Twitter Handle](https://x.com/olujimi_the_dev)
*   **Portfolio**: [My Personal Website/Portfolio](https://olujimidevapp.vercel.app/)

Feel free to connect or reach out to me!

---

[![Solidity 0.8.24](https://img.shields.io/badge/Solidity-0.8.24-lightgrey)](https://docs.soliditylang.org/en/latest/080-breaking-changes.html)
[![Built with Foundry](https://img.shields.io/badge/Built%20with-Foundry-darkgreen)](https://getfoundry.sh/)
[![Chainlink Oracles](https://img.shields.io/badge/Oracles-Chainlink-blue)](https://chain.link/)
[![Tests Passing](https://img.shields.io/badge/Tests-Passing-brightgreen)](https://github.com/olujimiAdebakin/StableXCoin/actions/workflows/ci.yml)
[![Code Coverage](https://img.shields.io/badge/Coverage-In%20Progress-orange)](https://github.com/olujimiAdebakin/StableXCoin/blob/main/lcov.info)

[![Readme was generated by Dokugen](https://img.shields.io/badge/Readme%20was%20generated%20by-Dokugen-brightgreen)](https://www.npmjs.com/package/dokugen)