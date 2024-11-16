// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {ETFHook} from "../src/EtfHook.sol";
import {HookMiner} from "../test/utils/HookMiner.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";

/// @notice Mines the address and deploys the EtfHook.sol Hook contract
contract EtfHookScript is Script, Constants {
    MockERC20 public token0;
    MockERC20 public token1;
    MockERC20 public token2;

    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.AFTER_REMOVE_LIQUIDITY_FLAG
        );

        vm.broadcast();
        token0 = new MockERC20("mockETH", "mockETH", 18);
        
        vm.broadcast();
        token1 = new MockERC20("mockWBTC", "mockWBTC", 18);
        
        vm.broadcast();
        token2 = new MockERC20("mockUSDC", "mockUSDC", 18);
        
        vm.broadcast();
        token0.mint(msg.sender, 1_000_000_000_000_000_000_000_000);
        
        vm.broadcast();
        token1.mint(msg.sender, 1_000_000_000_000_000_000_000_000);
        
        vm.broadcast();
        token2.mint(msg.sender, 1_000_000_000_000_000_000_000_000);
        address[2] memory TOKENS = [address(token0), address(token1)];
        uint256[2] memory WEIGHTS = [uint256(5000), uint256(5000)];
        uint256 REBALANCE_THRESHOLD = 100;
        address entropy = 0x41c9e39574F40Ad34c79f1C99B66A45eFB830d4c;

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(
            POOLMANAGER, TOKENS, WEIGHTS, REBALANCE_THRESHOLD, entropy
        );
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(ETFHook).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();

        ETFHook etfHook = new ETFHook{salt: salt}(
            IPoolManager(POOLMANAGER), TOKENS, WEIGHTS, REBALANCE_THRESHOLD, entropy
        );
        require(address(etfHook) == hookAddress, "EtfHookScript: hook address mismatch");
    }
}
