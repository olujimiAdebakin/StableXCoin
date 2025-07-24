// // SPDX-License-Identifier: MIT

// pragma solidity 0.8.24;

// import {Test, console} from "forge-std/Test.sol";
// import {StdInvariant} from "forge-std/StdInvariant.sol";
// import {StableXCoin} from "../../src/StableXCoin.sol";
// import {DeploySXCEngine} from "../../script/DeploySXCEngine.s.sol";
// import {SXCEngine} from "../../src/SXCEngine.sol";
// import {HelperConfig} from "../../script/HelperConfig.s.sol";
// import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// /// @title OpenInvariantTest Contract
// /// @author Adebakin Olujimi
// /// @notice Fuzz testing with invariants for the SXCEngine stablecoin protocol
// /// @dev Uses Foundry's StdInvariant utilities for property-based testing
// contract OpenInvariantTest is StdInvariant, Test {
//     /// @notice Deployment script for setting up the engine, stablecoin, and config
//     DeploySXCEngine deployer;

//     /// @notice SXCEngine contract under test
//     SXCEngine engine;

//     /// @notice StableXCoin token instance (the stablecoin being minted and burned)
//     StableXCoin sxc;

//     /// @notice Configuration helper that gives access to network-specific contract addresses
//     HelperConfig config;

//     /// @notice WETH token used as collateral
//     IERC20 weth;

//     /// @notice WBTC token used as collateral
//     IERC20 wbtc;

//     /// @notice Set up the fuzz testing environment
//     /// @dev Deploys contracts and assigns necessary addresses before running invariants
//     function setUp() public {
//         // 1. Instantiate the deployment script
//         deployer = new DeploySXCEngine();

//         // 2. Run the deployment and retrieve key deployed contracts
//         (sxc, engine, config) = deployer.run();

//         // 3. Extract network-specific token addresses from the config
//         (,, address _weth, address _wbtc,) = config.activeNetworkConfig();

//         // 4. Cast retrieved addresses to IERC20 interface
//         weth = IERC20(_weth);
//         wbtc = IERC20(_wbtc);

//         // 5. Tell Foundry to fuzz test this contract with invariant checking
//         targetContract(address(engine));
//     }

//     function invariant_protocolMustHaveValueThanTotalSupply() public view {
//         uint256 totalSupply = sxc.totalSupply();
//         uint256 totalWethDeposited = weth.balanceOf(address(engine));
//         uint256 totalBtcDeposited = wbtc.balanceOf(address(engine));

//         uint256 wethValue = engine.getUsdValue(address(weth), totalWethDeposited);
//         uint256 wbtcValue = engine.getUsdValue(address(wbtc), totalBtcDeposited);

//         console.log("weth value", wethValue);
//         console.log("wbtc value", wbtcValue);
//         console.log("total supply", totalSupply);

//         assert(wethValue + wbtcValue >= totalSupply);
//     }
// }
