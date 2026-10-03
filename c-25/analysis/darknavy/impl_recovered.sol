// SPDX-License-Identifier: UNLICENSED
// Recovered by Decompiler Agent — NOT verified source code
// Contract: 0x88eb28009351fb414a5746f5d8ca91cdc02760d8
// Method: agent-native decompilation from disassembly and exploit trace context
// Confidence: medium
// Selectors covered: 2/2 (0xea7faa61, 0x4112e1c2)

pragma solidity ^0.8.0; // approximate

interface IERC20Like {
    function decimals() external view returns (uint8);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IAggregatorV3Like {
    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

contract Recovered_88eb2800 {
    address private _owner;                 // selector 0x8da5cb5b
    uint256 private _maxExpiry;             // selector 0x94be834d
    mapping(address => bool) private _allowedOrderSigner;
    mapping(address => bool) private _supportedToken;
    mapping(address => mapping(bytes32 => uint256)) private _orderStatus; // selector 0x5df4fd38

    // Hardcoded feed addresses visible in the exploit trace.
    address private constant USDC_USD = 0x8FfFfd4AfB6115b954Bd326cbe7B4BA576818f6;
    address private constant USDT_USD = 0x3E7d1eAB13ad0104d2750B8863b489D65364e32D;
    address private constant WBTC_USD = 0xF4030086522a5bEEa4988F8ca5B36dbC97BeE88c;
    address private constant ETH_USD  = 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419;

    function owner() external view returns (address) {
        return _owner;
    }

    function maxExpiry() external view returns (uint256) {
        return _maxExpiry;
    }

    function isSupportedToken(address token) external view returns (bool) {
        return _supportedToken[token];
    }

    function getOrderStatus(address signer, bytes32 orderHash) external view returns (uint256) {
        return _orderStatus[signer][orderHash];
    }

    // selector 0xea7faa61
    // signature from 4byte: registerAllowedOrderSigner(address,bool)
    function registerAllowedOrderSigner(address signer, bool allowed) external {
        // The exploit trace shows an attacker-created helper contract successfully reaching this
        // path through the proxy and mutating signer authorization without any observable owner-only
        // gate before the corresponding SSTORE.
        _allowedOrderSigner[signer] = allowed;
    }

    // selector 0x4112e1c2
    // Signature unresolved; behavior inferred from trace and surrounding dispatcher selectors.
    function func_0x4112e1c2(
        address payer,
        address receiver,
        address signer,
        address sellToken,
        uint256 sellAmount,
        address quoteToken,
        uint256 quoteAmount,
        uint256 expiry,
        bytes calldata orderData,
        bytes calldata signature,
        bytes32 orderHash
    ) external {
        require(expiry <= _maxExpiry || _maxExpiry == 0, "expiry");
        require(_supportedToken[sellToken], "unsupported sell token");
        require(_supportedToken[quoteToken] || quoteToken == address(0), "unsupported quote token");

        // Signature/authentication path seen in trace:
        //   - STATICCALL to precompile 0x01 with varying 4-byte digests
        //   - owner()/order status checks
        //   - branch into signer allowlist mutated by registerAllowedOrderSigner
        if (!_allowedOrderSigner[signer]) {
            address recovered = _recoverSigner(orderHash, signature);
            require(recovered == signer, "bad signature");
        }

        // Oracle and decimals lookups observed on every drain iteration.
        _readTokenDecimalsAndPrice(sellToken);
        _readTokenDecimalsAndPrice(quoteToken);

        // Core draining action observed in trace: the proxy context pulls approved victim balances
        // with ERC20.transferFrom and routes assets to the attacker-controlled helper receiver.
        IERC20Like(sellToken).transferFrom(payer, receiver, sellAmount);
        if (quoteToken != address(0) && quoteAmount != 0) {
            IERC20Like(quoteToken).transferFrom(payer, receiver, quoteAmount);
        }

        _orderStatus[signer][orderHash] = 1;
        _consumeOrderState(orderData);
    }

    function _readTokenDecimalsAndPrice(address token) internal view {
        if (token == address(0)) return;
        IERC20Like(token).decimals();

        if (token == 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48) {
            IAggregatorV3Like(USDC_USD).latestRoundData();
            IAggregatorV3Like(ETH_USD).latestRoundData();
        } else if (token == 0xdAC17F958D2ee523a2206206994597C13D831ec7) {
            IAggregatorV3Like(USDT_USD).latestRoundData();
            IAggregatorV3Like(ETH_USD).latestRoundData();
        } else if (token == 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599) {
            IAggregatorV3Like(WBTC_USD).latestRoundData();
            IAggregatorV3Like(ETH_USD).latestRoundData();
        }
    }

    function _recoverSigner(bytes32 digest, bytes calldata signature) internal view returns (address signer) {
        // STATICCALL to precompile 0x01 is visible in each exploit iteration.
        // unresolved: exact calldata packing for ecrecover and domain-separated order hash.
        digest;
        signature;
        signer = address(0);
    }

    function _consumeOrderState(bytes calldata orderData) internal pure {
        // unresolved: storage writes beyond the signer allowlist / order status mapping.
        orderData;
    }

    // Additional dispatcher entries seen in bytecode but not exercised by this transaction.
    function func_0x637fec51() external view returns (bytes memory) {}
    function func_0x7179a12c() external view returns (bytes memory) {}
    function func_0x9227b794() external view returns (bytes memory) {}
    function func_0xb9e7bce6() external view returns (bytes memory) {}
    function func_0xcbfd8657() external view returns (bytes memory) {}
    function func_0xdcbbc8d4() external view returns (bytes memory) {}
    function func_0x01e480ab() external view returns (bytes memory) {}
    function func_0x06c1f431() external view returns (bytes memory) {}
    function removeTokenSupport(address token) external { token; }
    function func_0x5d4d8fe7() external view returns (bytes memory) {}
    function func_0x3fabe5a3() external view returns (bytes memory) {}
}
