// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {ETFManager} from "./EtfToken.sol";

contract ETFHook is ETFManager, BaseHook {
    address[2] public tokens; // the underlying tokens will be stored in this hook contract
    uint256[2] public weights;
    uint256 public rebalanceThreshold;

    uint256[2] public tokenBalances;

    constructor(
        IPoolManager _poolManager,
        address[2] memory _tokens, // only two tokens are supported for now
        uint256[2] memory _weights,
        uint256 _rebalanceThreshold
    ) BaseHook(_poolManager) ETFManager("ETF Token", "ETF") { // TODO: name the ETF token as f"{token0.symbol} + {token1.symbol} ETF"
        tokens = _tokens;
        weights = _weights;
        rebalanceThreshold = _rebalanceThreshold;
        for (uint256 i= 0; i < 2; i++) {
            tokenBalances[i] = 0;
        }
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: true,
            beforeRemoveLiquidity: true,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        return (BaseHook.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    function beforeAddLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        mintETFToken(0);
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        burnETFToken();
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    // returns each token prices from oracle
    function getPrices() public returns (uint256[2] memory prices) {
        // TODO: use chainlink, pyth, chronicle
        return prices;
    }

    function checkIfRebalanceNeeded() private returns (bool) {
    uint256[2] memory prices = getPrices();
    
    // Calculate current value of each token
    uint256[2] memory tokenValues;
    for (uint256 i = 0; i < 2; i++) {
        tokenValues[i] = prices[i] * tokenBalances[i];
    }
    
    // Calculate total portfolio value
    uint256 totalValue = tokenValues[0] + tokenValues[1];
    if (totalValue == 0) return false;
    
    // Calculate current weights (in basis points - 10000 = 100%)
    uint256[2] memory currentWeights;
    for (uint256 i = 0; i < 2; i++) {
        currentWeights[i] = (tokenValues[i] * 10000) / totalValue;
    }
    
    // Check if any weight deviates more than the threshold
    for (uint256 i = 0; i < 2; i++) {
        if (currentWeights[i] > weights[i]) {
            if (currentWeights[i] - weights[i] > rebalanceThreshold) return true;
        } else {
            if (weights[i] - currentWeights[i] > rebalanceThreshold) return true;
        }
    }
        
        return false;
    }

    function rebalance() private {
        uint256[2] memory prices = getPrices();
        
        // Calculate current value of each token
        uint256[2] memory tokenValues;
        for (uint256 i = 0; i < 2; i++) {
            tokenValues[i] = prices[i] * tokenBalances[i];
        }
        
        // Calculate total portfolio value
        uint256 totalValue = tokenValues[0] + tokenValues[1];
        if (totalValue == 0) return;
        
        // Calculate target values for each token
        uint256[2] memory targetValues;
        for (uint256 i = 0; i < 2; i++) {
            targetValues[i] = (totalValue * weights[i]) / 10000;
        }
        
        // Determine which token to sell and which to buy
        if (tokenValues[0] > targetValues[0]) {
            // Token 0 is overweight, sell token 0 for token 1
            uint256 token0ToSell = (tokenValues[0] - targetValues[0]) / prices[0];
            // Execute swap through Uniswap pool
            // TODO: Implement swap logic using poolManager
        } else {
            // Token 1 is overweight, sell token 1 for token 0
            uint256 token1ToSell = (tokenValues[1] - targetValues[1]) / prices[1];
            // Execute swap through Uniswap pool
            // TODO: Implement swap logic using poolManager
        }
    }

    function mintETFToken(uint256 etfAmount) private {
        // transfer tokens to ETF pool contract
        // update token balances
        // mint ETF token to msg.sender
    }

    function burnETFToken() private {
        // transfer tokens to msg.sender
        // update token balances
        // burn ETF token from msg.sender
    }
}