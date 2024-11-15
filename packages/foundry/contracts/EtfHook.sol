// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

contract ETFHook is BaseHook {
    address[] public tokens; // the underlying tokens will be stored in this hook contract
    uint256[] public weights;
    uint256 public rebalanceThreshold;

    uint256[] public tokenBalances;

    constructor(
        IPoolManager _poolManager,
        address[] memory _tokens,
        uint256[] memory _weights,
        uint256[] memory _rebalanceThreshold
    ) BaseHook(_poolManager) {
        tokens = _tokens;
        weights = _weights;
        rebalanceThreshold = _rebalanceThreshold;
        for (int = 0; i < len(_tokens); i++) {
            tokenBalances[i] = 0;
        }
    }

    function getHooksCalls() public pure override returns (Hooks.Calls memory) {
        return
            Hooks.Calls({
                beforeInitialize: false,
                afterInitialize: false,
                beforeAddLiquidity: true, // rebalance ETF, mints ETF token
                afterAddLiquidity: true, // rebalance ETF, burns ETF token
                beforeModifyPosition: false,
                afterModifyPosition: false,
                beforeSwap: true, // rebalance ETF
                afterSwap: false,
                beforeDonate: false,
                afterDonate: false
            });
    }

    function beforeSwap(
        address sender,
        IPoolManager.PoolKey calldata,
        IPoolManager.SwapParams calldata
    ) external override returns (bytes4) {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        return BaseHook.beforeSwap.selector;
    }

    function beforeAddLiquidity(
        address sender,
        IPoolManager.PoolKey calldata,
        IPoolManager.AddLiquidityParams calldata
    ) external override returns (bytes4) {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        mintETFToken();
        return BaseHook.beforeAddLiquidity.selector;
    }

    function beforeRemoveLiquidity(
        address sender,
        IPoolManager.PoolKey calldata,
        IPoolManager.AddLiquidityParams calldata
    ) external override returns (bytes4) {
        if (checkIfRebalanceNeeded()) {
            rebalance();
        }
        burnETFToken();
        return BaseHook.beforeRemoveLiquidity.selector;
    }

    // returns each token prices from oracle
    function getPrices() public returns (uint256[] prices) {
        // TODO: use chainlink, pyth, chronicle
        return;
    }

    function checkIfRebalanceNeeded() private returns (bool) {
        // check chainlink if we need to rebalance (check if rebalanceThreshold is reached)
        // return true if rebalance needed
        uint256[] memory prices = getPrices();
    }

    function rebalance() private {
        // sell A & buy B through specified uniswap pool
    }

    function mintETFToken() private {
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
