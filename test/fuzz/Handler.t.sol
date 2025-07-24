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
import {ERC20Mock} from "@openzeppelin/contracts/mocks/token/ERC20Mock.sol";

contract Handler is Test {
    // ========================
    // STATE VARIABLES
    // ========================

    SXCEngine public engine;
    StableXCoin public sxc;

    ERC20Mock public weth;
    ERC20Mock public wbtc;

    uint256 MAX_DEPOSIT_SIZE = type(uint96).max;

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
    uint256 clampedAmount = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

    vm.startPrank(msg.sender);
    collateral.mint(msg.sender, clampedAmount);
    collateral.approve(address(engine), clampedAmount);
    engine.depositCollateral(address(collateral), clampedAmount);
    vm.stopPrank();
}


/// @notice Attempts to mint StableXCoin (SXC) for the caller based on their collateral value
/// @dev This function is used during fuzz testing to simulate minting. It ensures the user can only mint
///      up to 50% of their collateral value in USD to maintain overcollateralization (e.g., 200% collateral ratio).
///      If the user has already minted the maximum or has insufficient collateral, the function exits safely.
/// @param amount The amount of StableXCoin (SXC) the user attempts to mint. This is bounded internally.
/// @custom:invariant The function avoids minting if it would violate the collateralization ratio.
function minSxc(uint256 amount) public {
    // Clamp the initial amount to prevent unrealistic fuzzing input
    amount = bound(amount, 1, MAX_DEPOSIT_SIZE);

    // Get how much SXC the user has minted and how much collateral (in USD) they have deposited
    (uint256 totalSxcMinted, uint256 collateralValueInUsd) = engine.getAccountInformation(msg.sender);

    // Calculate the maximum amount of SXC the user is allowed to mint (200% collateralization ratio)
    int256 maxSxcToMint = (int256(collateralValueInUsd) / 2) - int256(totalSxcMinted);

    // If the user is over their mint limit, exit safely
    if (maxSxcToMint < 0) {
        return;
    }

    // Clamp the mint amount to not exceed what they're allowed to mint
    amount = bound(amount, 0, uint256(maxSxcToMint));

    // If the result is 0, skip the minting
    if (amount == 0) {
        return;
    }

    // Simulate a user calling mint on the engine
    vm.startPrank(msg.sender);
    engine.minSxc(amount);
    vm.stopPrank();
}


//     function depositCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
//         ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//         amountCollateral = bound(amountCollateral, 1, MAX_DEPOSIT_SIZE);

//         // Mint tokens to the caller so they can deposit
//         collateral.mint(address(this), amountCollateral);

//         // Approve and deposit to the engine
//         collateral.approve(address(engine), amountCollateral);
//         engine.depositCollateral(address(collateral), amountCollateral);
//     }

// function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral){
//       ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);
//       uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);
//       amountCollateral = bound(amountCollateral, 1, maxCollateralToRedeem);
//       if (amountCollateral == 0 ){
//             return;
//       }
//       engine.redeemCollateral(address(colateral), amountCollateral);
// }



/// @notice Simulates redeeming collateral (WETH or WBTC) from the SXCEngine by the caller
/// @dev Used during fuzz testing to simulate user withdrawals. The function ensures that the user
///      only attempts to redeem an amount they have deposited (tracked by the engine).
///      If the user has no redeemable balance or attempts to redeem zero, the function exits gracefully.
/// @param collateralSeed Determines which collateral token to use (e.g., even = WETH, odd = WBTC)
/// @param amountCollateral The amount of collateral to attempt to redeem. Bounded internally to a safe range.
/// @custom:invariant The function avoids redeeming more than the user's tracked collateral balance in the engine.
function redeemCollateral(uint256 collateralSeed, uint256 amountCollateral) public {
    // Get WETH or WBTC based on the seed value
    ERC20Mock collateral = _getCollateralFromSeed(collateralSeed);

    // Query the max amount of this token the user has in the engine
    uint256 maxCollateralToRedeem = engine.getCollateralBalanceOfUser(address(collateral), msg.sender);

    // Clamp the amount to a valid, redeemable range
    uint256 clampedAmount = bound(amountCollateral, 1, maxCollateralToRedeem);

    // If they have nothing to redeem or fuzzed to 0, exit early
    if (clampedAmount == 0) return;

    // Simulate the user calling redeem
    vm.startPrank(msg.sender);
    engine.redeemCollateral(address(collateral), clampedAmount);
    vm.stopPrank();
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
