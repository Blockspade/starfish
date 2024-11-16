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
import {ERC20} from "solmate/src/tokens/ERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";


// Copied from [chronicle-std](https://github.com/chronicleprotocol/chronicle-std/blob/main/src/IChronicle.sol).
interface IChronicle {
    /*
     * @notice Returns the oracle's current value.
     * @dev Reverts if no value set.
     * @return value The oracle's current value.
     */
    function read() external view returns (uint256 value);
}


interface ISelfKisser {
    /// @notice Kisses caller on oracle `oracle`.
    function selfKiss(address oracle) external;
}

contract ETFHook is BaseHook ,ETFManager, IEntropyConsumer {
    IEntropy public entropy;
    bytes32 private latestRandomNumber;
    bool private isRandomNumberReady;

    address[2] public tokens; // the underlying tokens will be stored in this hook contract
    uint256[2] public weights;
    uint256 public rebalanceThreshold;
    // chronicle oracle addresses
    address public Chronicle_BTC_USD_3 =0xdc3ef3E31AdAe791d9D5054B575f7396851Fa432;
    address public Chronicle_ETH_USD_3 =0xdd6D76262Fd7BdDe428dcfCd94386EbAe0151603;

    // Chainlink oracle addresses
    address public Chainlink_ETH_USD = 0x694AA1769357215DE4FAC081bf1f309aDC325306;
    address public Chainlink_BTC_USD = 0x1b44F3514812d835EB1BDB0acB33d3fA3351Ee43;

    // token balances
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

        // This allows the contract to read from the chronicle oracle.
        ISelfKisser(Chronicle_BTC_USD_3).selfKiss(address(this));
        ISelfKisser(Chronicle_ETH_USD_3).selfKiss(address(this));
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

    function selectOracle() internal returns (bool) {
        if (!isRandomNumberReady) {
            requestRandomNumber();
            return chainlinkOracle; // Default to Chainlink if random number not ready
        }
        
        uint256 randomValue = uint256(latestRandomNumber) % 2;
        emit OracleSelected(randomValue);
        return randomValue;
    }

    // Hook permissions
    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: true,
            beforeSwap: true,
            afterSwap: false,
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
        
        if (!selectedOracle) {
            return getChainlinkPrices();
        } else {
            return getChroniclePrices();
        }
    }

    function getChainlinkPrices() internal view returns (uint256[2] memory prices) {
        // TODO: Implement Chainlink price fetching
       (, int256 answerETH, , ,) = AggregatorV3Interface(Chainlink_ETH_USD).latestRoundData();
        (, int256 answerBTC, , ,) = AggregatorV3Interface(Chainlink_BTC_USD).latestRoundData();
        return [uint256(answerETH), uint256(answerBTC)];
    }

    function getChroniclePrices() internal view returns (uint256[2] memory prices) {
        // TODO: Implement Pyth price fetching
        return [IChronicle(Chronicle_ETH_USD_3).read(), IChronicle(Chronicle_BTC_USD_3).read()];
    }


    // Hook callbacks
    function beforeSwap(address sender, PoolKey calldata key, IPoolManager.SwapParams calldata, bytes calldata)
        external
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        (bool needed, uint256[2] memory prices) = checkIfRebalanceNeeded();
        if (needed) {
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
        (bool needed, uint256[2] memory prices) = checkIfRebalanceNeeded();
        if (needed) {
            rebalance();
        }
        // how many etf tokens to mint
        mintETFToken(0, prices); // TODO
        return BaseHook.beforeAddLiquidity.selector;
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata key,
        IPoolManager.ModifyLiquidityParams calldata,
        bytes calldata
    ) external override returns (bytes4) {
        (bool needed, uint256[2] memory prices) = checkIfRebalanceNeeded();
        if (needed) {
            rebalance();
        }
        burnETFToken(0, prices); // TODO
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    // Your existing functions
    function checkIfRebalanceNeeded() private returns (bool needed, uint256[2] memory prices) {
        prices = getPrices();
        
        uint256[2] memory tokenValues;
        for (uint256 i = 0; i < 2; i++) {
            tokenValues[i] = prices[i] * tokenBalances[i];
        }
        
        uint256 totalValue = tokenValues[0] + tokenValues[1];
        if (totalValue == 0) return (false, prices);
        
        uint256[2] memory currentWeights;
        for (uint256 i = 0; i < 2; i++) {
            currentWeights[i] = (tokenValues[i] * 10000) / totalValue;
        }
        
        for (uint256 i = 0; i < 2; i++) {
            if (currentWeights[i] > weights[i]) {
                if (currentWeights[i] - weights[i] > rebalanceThreshold) return (true, prices);
            } else {
                if (weights[i] - currentWeights[i] > rebalanceThreshold) return (true, prices);
            }
        }
        
        return (false, prices);
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

    // 1 etf = 1 token0 + x token1 (x is calculated based on the weights and prices)
    function mintETFToken(uint256 etfAmount, uint256[2] memory prices) private {
        uint256 token0Amount = etfAmount;
        uint256 token1Amount = etfAmount * prices[0] / prices[1] * weights[1] / weights[0];
        // transfer tokens to ETF pool contract
        ERC20(tokens[0]).transferFrom(msg.sender, address(this), token0Amount);
        ERC20(tokens[1]).transferFrom(msg.sender, address(this), token1Amount);
        //
        mint(msg.sender, etfAmount);
        tokenBalances[0] += token0Amount;
        tokenBalances[1] += token1Amount;
    }

    function burnETFToken(uint256 etfAmount, uint256[2] memory prices) private {
        uint256 token0Amount = etfAmount;
        uint256 token1Amount = etfAmount * prices[0] / prices[1] * weights[1] / weights[0];
        // transfer tokens to ETF pool contract
        ERC20(tokens[0]).transfer(msg.sender, token0Amount);
        ERC20(tokens[1]).transfer(msg.sender, token1Amount);
        //
        burn(msg.sender, etfAmount);
        tokenBalances[0] -= token0Amount;
        tokenBalances[1] -= token1Amount;
    }
}