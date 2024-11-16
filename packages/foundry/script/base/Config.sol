// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";

/// @notice Shared configuration between scripts
contract Config {
    /// @dev populated with default anvil addresses
    
    // change order of tokens 
    IERC20 constant mockETHToken = IERC20(address(0x558b4319fC92EA1D3e8E9873a74Eb1212a1771A2));
    IERC20 constant mockWBTCToken = IERC20(address(0x96Ea69EaE0619309f9f758CFD060888412321438));
    IERC20 constant mockUSDCToken = IERC20(address(0x64D9794A3b3ddf369FFfa3d11695fF3863776cAb));
    
    IHooks constant hookContract = IHooks(address(0xDAe08C98194FB8E92B6893e3AC30a78Fc8F4C980));
    IERC20 constant etfToken = IERC20(address(0xa920301D5da78F06c1b53B73EcDBF0A5D8F4d1C2));

    Currency constant mockETH = Currency.wrap(address(mockETHToken));
    Currency constant mockWBTC = Currency.wrap(address(mockWBTCToken));
    Currency constant mockUSDC = Currency.wrap(address(mockUSDCToken));

}
