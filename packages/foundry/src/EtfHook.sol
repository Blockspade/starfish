// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {BaseHook} from "v4-periphery/src/base/hooks/BaseHook.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {IEntropyConsumer} from "@pythnetwork/entropy-sdk-solidity/IEntropyConsumer.sol";
import {IEntropy} from "@pythnetwork/entropy-sdk-solidity/IEntropy.sol";
import {ETFManager} from "./EtfToken.sol";

contract ETFHook is BaseHook ,ETFManager, IEntropyConsumer {
    IEntropy public entropy;
    bytes32 private latestRandomNumber;
    bool private isRandomNumberReady;

    address[2] public tokens;
    uint256[2] public weights;
    uint256 public rebalanceThreshold;
    uint256[2] public tokenBalances;

    // Oracle addresses
    address public chainlinkOracle;
    address public pythOracle;
    address public api3Oracle;

    // Events
    event RandomNumberReceived(bytes32 randomNumber);
    event OracleSelected(uint256 indexed oracleIndex);

    constructor(
        IPoolManager _poolManager,
        address[2] memory _tokens,
        uint256[2] memory _weights,
        uint256 _rebalanceThreshold,
        address entropyAddress,
        address _chainlinkOracle,
        address _pythOracle,
        address _api3Oracle
    ) BaseHook(_poolManager) ETFManager("ETF Token", "ETF") {
        entropy = IEntropy(entropyAddress);
        tokens = _tokens;
        weights = _weights;
        rebalanceThreshold = _rebalanceThreshold;
        chainlinkOracle = _chainlinkOracle;
        pythOracle = _pythOracle;
        api3Oracle = _api3Oracle;
        
        for (uint256 i = 0; i < 2; i++) {
            tokenBalances[i] = 0;
        }
    }

    // Entropy Implementation
    function requestRandomNumber() internal {
        bytes32 userRandomNumber = keccak256(abi.encodePacked(block.timestamp, msg.sender));
        address entropyProvider = entropy.getDefaultProvider();
        uint256 fee = entropy.getFee(entropyProvider);
        
        entropy.requestWithCallback{value: fee}(
            entropyProvider,
            userRandomNumber
        );
        
        isRandomNumberReady = false;
    }

    function entropyCallback(
        uint64 sequenceNumber,
        address provider,
        bytes32 randomNumber
    ) internal override {
        latestRandomNumber = randomNumber;
        isRandomNumberReady = true;
        emit RandomNumberReceived(randomNumber);
    }

    function getEntropy() internal view override returns (address) {
        return address(entropy);
    }

    function selectOracle() internal returns (address) {
        if (!isRandomNumberReady) {
            requestRandomNumber();
            return chainlinkOracle; // Default to Chainlink if random number not ready
        }
        
        uint256 randomValue = uint256(latestRandomNumber) % 3;
        emit OracleSelected(randomValue);
        
        if (randomValue == 0) return chainlinkOracle;
        if (randomValue == 1) return pythOracle;
        return api3Oracle;
    }

    // Hook permissions
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

    // Price fetching functions
    function getPrices() internal returns (uint256[2] memory prices) {
        address selectedOracle = selectOracle();
        
        if (selectedOracle == chainlinkOracle) {
            return getChainlinkPrices();
        } else if (selectedOracle == pythOracle) {
            return getPythPrices();
        } else {
            return getAPI3Prices();
        }
    }

    function getChainlinkPrices() internal view returns (uint256[2] memory prices) {
        // TODO: Implement Chainlink price fetching
        return prices;
    }

    function getPythPrices() internal view returns (uint256[2] memory prices) {
        // TODO: Implement Pyth price fetching
        return prices;
    }

    function getAPI3Prices() internal view returns (uint256[2] memory prices) {
        // TODO: Implement API3 price fetching
        return prices;
    }

    // Hook callbacks
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

    // Your existing functions
    function checkIfRebalanceNeeded() private returns (bool) {
        uint256[2] memory prices = getPrices();
        
        uint256[2] memory tokenValues;
        for (uint256 i = 0; i < 2; i++) {
            tokenValues[i] = prices[i] * tokenBalances[i];
        }
        
        uint256 totalValue = tokenValues[0] + tokenValues[1];
        if (totalValue == 0) return false;
        
        uint256[2] memory currentWeights;
        for (uint256 i = 0; i < 2; i++) {
            currentWeights[i] = (tokenValues[i] * 10000) / totalValue;
        }
        
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
        
        uint256[2] memory tokenValues;
        for (uint256 i = 0; i < 2; i++) {
            tokenValues[i] = prices[i] * tokenBalances[i];
        }
        
        uint256 totalValue = tokenValues[0] + tokenValues[1];
        if (totalValue == 0) return;
        
        uint256[2] memory targetValues;
        for (uint256 i = 0; i < 2; i++) {
            targetValues[i] = (totalValue * weights[i]) / 10000;
        }
        
        if (tokenValues[0] > targetValues[0]) {
            uint256 token0ToSell = (tokenValues[0] - targetValues[0]) / prices[0];
            // TODO: Implement swap logic
        } else {
            uint256 token1ToSell = (tokenValues[1] - targetValues[1]) / prices[1];
            // TODO: Implement swap logic
        }
    }

    function mintETFToken(uint256 etfAmount) private {
        // TODO: Implement minting logic
    }

    function burnETFToken() private {
        // TODO: Implement burning logic
    }
}