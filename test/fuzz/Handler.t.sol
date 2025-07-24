// // SPDX-License-Identifier:MIT

// // handler is going to narrow down the way we call function


// pragma solidity 0.8.24;

// import {Test} from "forge-std/Test.sol";
// import {SXCEngine} from "../../src/SXCEngine.sol";
// import {StableXCoin} from "../../src/StableXCoin.sol";
// import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

// contract Handler is Test {

//       SXCEngine engine;
//       StableXCoin sxc;

//       ERC20Mock weth;
//       ERC20Mock wbtc;

//       constructor(SXCEngine _engine, StableXCoin _sxc){
//             engine = _engine;
//             _sxc = sxc;

//             address[] memory collateralTokens = engine.getCollateralTokens();
//             weth = ERC20Mock(collateralTokens[0]);
//             wbtc = ERC20Mock(collateralTokens[1]);
//       }


//       // redeem collateral

//       function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//             ERC20Mock collateral = _getCollateralFromSeed(collateral);
//             engine.depositCollateral(address(collateral), amountCollateral);
//       }

//       // helper Function
//       function _getCollateralFromUsd(uint256 collateralSeed) private view returns(ERC20Mock) {
//             if (collateralSeed % 2 == 0){
//                   return weth;
//             }
//             return wbtc
//       }


//     /// @notice Fuzz test invariant that the total supply of StableXCoin remains constant
//     /// @dev This is a property-based test that checks if the total supply of the stablecoin
//     ///      remains unchanged after a series of operations
//     function invariant_totalSupplyUnchanged() public view {
//         assertEq(sxc.totalSupply(), 0);
//     }
// }


// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Handler Contract for SXCEngine Invariant Testing
/// @author Adebakin Olujimi
/// @notice Used in fuzz testing to call selected functions in controlled ways
/// @dev This contract is used alongside Foundry's invariant fuzzing tools

import {Test} from "forge-std/Test.sol";
import {SXCEngine} from "../../src/SXCEngine.sol";
import {StableXCoin} from "../../src/StableXCoin.sol";
import {ERC20Mock} from "@openzeppelin/contracts/mocks/ERC20Mock.sol";

contract Handler is Test {
    // ========================
    // STATE VARIABLES
    // ========================

    SXCEngine public engine;
    StableXCoin public sxc;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    /// @notice Initializes the handler with the deployed engine and stablecoin
    /// @param _engine The SXCEngine contract to be tested
    /// @param _sxc The StableXCoin token contract
    constructor(SXCEngine _engine, StableXCoin _sxc) {
        engine = _engine;
        sxc = _sxc;

        // Get collateral tokens from the engine (WETH, WBTC)
        address[] memory collateralTokens = engine.getCollateralTokens();
        weth = ERC20Mock(collateralTokens[0]);
        wbtc = ERC20Mock(collateralTokens[1]);
    }

    // ========================
    // TEST ACTIONS
    // ========================

    /// @notice Deposits a certain amount of collateral to the SXCEngine
    /// @param collateralSeed Determines which token to use (WETH or WBTC)
    /// @param amountCollateral Amount of tokens to deposit
    function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
        ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

        // Mint tokens to the caller so they can deposit
        collateral.mint(address(this), amountCollateral);

        // Approve and deposit to the engine
        collateral.approve(address(engine), amountCollateral);
        engine.depositCollateral(address(collateral), amountCollateral);
    }

    // ========================
    // HELPERS
    // ========================

    /// @notice Selects WETH or WBTC based on the seed value
    /// @param collateralSeed A fuzzed seed used to determine the token
    /// @return The ERC20Mock token to use for deposit
    function _getCollateralFromSeed(uint256 collateralSeed) private view returns (ERC20Mock) {
        if (collateralSeed % 2 == 0) {
            return weth;
        }
        return wbtc;
    }

    // ========================
    // INVARIANTS
    // ========================

    /// @notice Invariant test to ensure the stablecoin supply remains zero
    /// @dev This ensures that no minting is done during fuzzing (e.g., via deposit)
    function invariant_totalSupplyUnchanged() public view {
        assertEq(sxc.totalSupply(), 0);
    }
}
