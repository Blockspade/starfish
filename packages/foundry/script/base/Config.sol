// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    
    // change order of tokens 
    IERC20 constant mockETHToken = IERC20(address(0x1bda2B87464EE964D35F53a98f03d7985B983Bb3));
    IERC20 constant mockWBTCToken = IERC20(address(0x2D08fc34b87FC70f9a4D9AF820a3EEa43F9749A3));
    IERC20 constant mockUSDCToken = IERC20(address(0x6A6c16456999C5A3EcCa6249b19F32F95aCeA858));
    
    IHooks constant hookContract = IHooks(address(0x4419fa62199a514201A459130fa046c3D8E40980));
    IERC20 constant etfToken = IERC20(address(0x271bf25B33c6ba22cF73a5c861FbfFf28c96e5e0));

    Currency constant mockETH = Currency.wrap(address(mockETHToken));
    Currency constant mockWBTC = Currency.wrap(address(mockWBTCToken));
    Currency constant mockUSDC = Currency.wrap(address(mockUSDCToken));

}
