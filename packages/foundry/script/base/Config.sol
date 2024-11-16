// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    
    // change order of tokens 
    IERC20 constant mockETHToken = IERC20(address(0x00072cf517031907e46e885f630ace2bf2ce9a3adf));
    IERC20 constant mockWBTCToken = IERC20(address(0x009a008944603cd27743abd114395b4e39c45ce578));
    IERC20 constant mockUSDCToken = IERC20(address(0x0069b597aee6607a38180970984d005e14112dc7ad));
    
    IHooks constant hookContract = IHooks(address(0xfc07c3b8fc7e264041060eE5963d1cecb6a5C980));
    IERC20 constant etfToken = IERC20(address(0xb4f884e8357f0424e3571b8A35BC9473fA115553));

    Currency constant mockETH = Currency.wrap(address(mockETHToken));
    Currency constant mockWBTC = Currency.wrap(address(mockWBTCToken));
    Currency constant mockUSDC = Currency.wrap(address(mockUSDCToken));

}
