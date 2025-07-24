// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test, console} from "forge-std/Test.sol";
import {SXCEngine} from "../../src/SXCEngine.sol";
import {StableXCoin} from "../../src/StableXCoin.sol";
import {MockV3Aggregator} from "../../test/mocks/MockV3Aggregator.sol";
import {ERC20Mock} from "../../test/mocks/ERC20Mock.sol";

/**
 * @title SXCEngineFuzz
 * @notice Fuzz test suite for the SXCEngine contract.
 * @dev Uses Foundry's `Test` framework and includes invariant testing.
 */
contract SXCEngineFuzz is Test {
    StableXCoin public sxc;
    SXCEngine public sxcEngine;
    MockV3Aggregator public mockEthUsdPriceFeed;
    MockV3Aggregator public mockBtcUsdPriceFeed;
    address public weth;
    address public wbtc;
    address public USER = makeAddr("user");
    address public LIQUIDATOR = makeAddr("liquidator");
    uint8 public constant DECIMALS = 8;
    int256 public constant ETH_USD_PRICE = 2000 * 10 ** 8;
    int256 public constant BTC_USD_PRICE = 60000 * 10 ** 8;
    uint256 public constant STARTING_ERC20_BALANCE = 1000 ether;

    address[] public tokenAddresses;
    address[] public priceFeedAddresses;

    address[] private _activeUsers;
    mapping(address => bool) private _isUserActive;

    // ------------------------------------
    // Internal Utility Helpers
    // ------------------------------------

    /**
     * @notice Registers an address as active if not already tracked.
     * @param user The address to track.
     */
    function _addActiveUser(address user) private {
        if (!_isUserActive[user]) {
            _isUserActive[user] = true;
            _activeUsers.push(user);
        }
    }

    /**
     * @notice Extracts the 4-byte selector from revert data.
     * @param _data The raw revert data bytes.
     * @return The 4-byte selector.
     */
    function _getSelectorFromRevertData(bytes memory _data) private pure returns (bytes4) {
        if (_data.length < 4) {
            return bytes4(0x00000000);
        }
        bytes4 selector;
        assembly {
            selector := mload(add(_data, 0x20))
        }
        return selector;
    }

    /**
     * @notice Safely decodes a revert reason from low-level data, falling back to generic message.
     * @param revertData Raw revert data bytes from catch block.
     * @return A human-readable string message.
     */
    function _getRevertMessage(bytes memory revertData) internal pure returns (string memory) {
        if (revertData.length < 4) {
            return "Revert: No reason provided";
        }

        bytes4 selector;
        assembly {
            selector := mload(add(revertData, 0x20))
        }

        // Standard Error(string) selector
        if (selector == bytes4(0x08c379a0)) {
            assembly {
                revertData := add(revertData, 0x24) // skip selector and offset
            }
            string memory decodedReason = abi.decode(revertData, (string));
            require(bytes(decodedReason).length != 0, "Revert: Failed to decode reason");
            return decodedReason;
        }

        return "Revert: Unknown error selector";
    }
    // ------------------------------------
    // Setup
    // ------------------------------------

    /**
     * @notice Deploys and configures test environment before each fuzz test.
     */
    function setUp() public {
        vm.warp(1700000000); // Set timestamp

        vm.startPrank(USER);
        mockEthUsdPriceFeed = new MockV3Aggregator(DECIMALS, ETH_USD_PRICE);
        mockBtcUsdPriceFeed = new MockV3Aggregator(DECIMALS, BTC_USD_PRICE);
        weth = address(new ERC20Mock("WETH", "WETH", USER, STARTING_ERC20_BALANCE * 100));
        wbtc = address(new ERC20Mock("WBTC", "WBTC", USER, STARTING_ERC20_BALANCE * 100));
        vm.stopPrank();

        sxc = new StableXCoin();

        tokenAddresses = new address[](2);
        priceFeedAddresses = new address[](2);
        tokenAddresses[0] = weth;
        tokenAddresses[1] = wbtc;
        priceFeedAddresses[0] = address(mockEthUsdPriceFeed);
        priceFeedAddresses[1] = address(mockBtcUsdPriceFeed);

        vm.startPrank(USER);
        sxcEngine = new SXCEngine(tokenAddresses, priceFeedAddresses, address(sxc));
        vm.stopPrank();

        sxc.transferOwnership(address(sxcEngine));

        _addActiveUser(USER);
        _addActiveUser(LIQUIDATOR);
        _addActiveUser(address(this));
        _addActiveUser(address(sxcEngine));
    }

    // ------------------------------------
    // Helper Functions
    // ------------------------------------

    function _depositCollateral(address _user, address _token, uint256 _amount) internal {
        _addActiveUser(_user);
        vm.startPrank(_user);
        ERC20Mock(_token).approve(address(sxcEngine), _amount);
        sxcEngine.depositCollateral(_token, _amount);
        vm.stopPrank();
    }

    function _mintSxc(address _user, uint256 _amount) internal {
        _addActiveUser(_user);
        vm.startPrank(_user);
        sxc.approve(address(sxcEngine), _amount);
        sxcEngine.mintSxc(_amount);
        vm.stopPrank();
    }

    // ------------------------------------
    // Fuzz Tests
    // ------------------------------------

    function testFuzz_DepositCollateralAndMintSxc(uint256 _amountCollateral, uint256 _amountSxcToMint) public {
        vm.assume(_amountCollateral > 0 && _amountCollateral < 1000 ether);
        vm.assume(_amountSxcToMint > 0 && _amountSxcToMint < 1000 ether);

        uint256 initialUserWethBalance = ERC20Mock(weth).balanceOf(USER);
        uint256 initialEngineWethBalance = ERC20Mock(weth).balanceOf(address(sxcEngine));
        uint256 initialUserSxcBalance = sxc.balanceOf(USER);
        uint256 initialUserSxcMinted = sxcEngine.getSxcMinted(USER);

        try sxcEngine.depositCollateralAndMintSxc(weth, _amountCollateral, _amountSxcToMint) {
            assertEq(ERC20Mock(weth).balanceOf(USER), initialUserWethBalance - _amountCollateral);
            assertEq(ERC20Mock(weth).balanceOf(address(sxcEngine)), initialEngineWethBalance + _amountCollateral);
            assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), _amountCollateral);
            assertEq(sxcEngine.getSxcMinted(USER), initialUserSxcMinted + _amountSxcToMint);
            assertEq(sxc.balanceOf(USER), initialUserSxcBalance + _amountSxcToMint);
            assertGe(sxcEngine.getHealthFactor(USER), sxcEngine.getMinHealthFactor());
        } catch Error(string memory reason) {
            revert(reason);
        } catch (bytes memory lowLevelData) {
            bytes4 selector = _getSelectorFromRevertData(lowLevelData);
            if (selector == SXCEngine.SXCEngine_BreakHealthFactor.selector) {
                // Expected revert
            } else {
                revert(_getRevertMessage(lowLevelData));
            }
        }
    }

    function testFuzz_Liquidate(uint256 _collateralAmount, uint256 _sxcMintAmount, uint256 _debtToCover) public {
        vm.assume(_collateralAmount > 1 ether && _collateralAmount < 50 ether);
        vm.assume(_sxcMintAmount > 1 ether && _sxcMintAmount < 2000 ether);
        vm.assume(_debtToCover > 0 && _debtToCover <= _sxcMintAmount);

        _depositCollateral(USER, weth, _collateralAmount);
        _mintSxc(USER, _sxcMintAmount);

        int256 newPrice = ETH_USD_PRICE / 5;
        vm.assume(newPrice > 0);
        mockEthUsdPriceFeed.updateAnswer(newPrice);
        vm.assume(sxcEngine.getHealthFactor(USER) < sxcEngine.getMinHealthFactor());

        uint256 liquidatorCollateralNeeded = sxcEngine.getTokenAmountFromUsd(_debtToCover * 2, weth);
        _depositCollateral(LIQUIDATOR, weth, liquidatorCollateralNeeded);
        _mintSxc(LIQUIDATOR, _debtToCover);

        uint256 expectedCollateralToLiquidate = sxcEngine.getTokenAmountFromUsd(_debtToCover, weth);
        uint256 expectedBonus =
            (expectedCollateralToLiquidate * sxcEngine.getLiquidationBonus()) / sxcEngine.getLiquidationPrecision();
        uint256 totalExpected = expectedCollateralToLiquidate + expectedBonus;
        vm.assume(sxcEngine.getCollateralBalanceOfUser(USER, weth) >= totalExpected);

        uint256 initialUserSxcMinted = sxcEngine.getSxcMinted(USER);
        uint256 initialUserCollateral = sxcEngine.getCollateralBalanceOfUser(USER, weth);
        uint256 initialLiqWeth = ERC20Mock(weth).balanceOf(LIQUIDATOR);
        uint256 initialLiqSxc = sxc.balanceOf(LIQUIDATOR);
        uint256 initialEngineSxc = sxc.balanceOf(address(sxcEngine));

        try sxcEngine.liquidate(weth, USER, _debtToCover) {
            assertEq(sxcEngine.getSxcMinted(USER), initialUserSxcMinted - _debtToCover);
            assertEq(sxcEngine.getCollateralBalanceOfUser(USER, weth), initialUserCollateral - totalExpected);
            assertEq(ERC20Mock(weth).balanceOf(LIQUIDATOR), initialLiqWeth + totalExpected);
            assertEq(sxc.balanceOf(LIQUIDATOR), initialLiqSxc - _debtToCover);
            assertEq(sxc.balanceOf(address(sxcEngine)), initialEngineSxc - _debtToCover);
            assertGe(sxcEngine.getHealthFactor(USER), sxcEngine.getMinHealthFactor());
        } catch (bytes memory lowLevelData) {
            bytes4 selector = _getSelectorFromRevertData(lowLevelData);
            if (
                selector == SXCEngine.SXCEngine_HealthFactorOk.selector
                    || selector == SXCEngine.SXCEngine_HealthFactorNotImproved.selector
                    || selector == SXCEngine.SXCEngine_NotEnoughCollateralForLiquidation.selector
            ) {
                // Expected revert
            } else {
                revert(_getRevertMessage(lowLevelData));
            }
        }
    }

    // ------------------------------------
    // Invariant Tests
    // ------------------------------------

    function invariant_TotalCollateralMatchesDeposits() public view {
        for (uint256 i = 0; i < tokenAddresses.length; i++) {
            address token = tokenAddresses[i];
            uint256 sum = 0;
            for (uint256 j = 0; j < _activeUsers.length; j++) {
                sum += sxcEngine.getCollateralBalanceOfUser(_activeUsers[j], token);
            }
            assertEq(ERC20Mock(token).balanceOf(address(sxcEngine)), sum);
        }
    }

    function invariant_TotalSxcMintedMatchesSupply() public view {
        uint256 totalDebt = 0;
        for (uint256 i = 0; i < _activeUsers.length; i++) {
            totalDebt += sxcEngine.getSxcMinted(_activeUsers[i]);
        }
        assertEq(sxc.totalSupply(), totalDebt);
    }
}
