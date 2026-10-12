// SPDX-License-Identifier: MIT
pragma solidity 0.6.5;

interface ICurvePool {
    function add_liquidity(uint256[4] calldata amounts, uint256 min_mint_amount) external;
    function remove_liquidity(uint256 amount, uint256[4] calldata min_amounts) external;
    function exchange(int128 i, int128 j, uint256 dx, uint256 min_dy) external;
}

interface IERC20 {
    function balanceOf(address) external view returns (uint256);
}

// Probe contract executed under eth_call state-override (code injected at an arbitrary address).
// All token funding/allowances are injected via state overrides by the caller.
contract SwerveChildAProbe {
    address constant POOL = 0x329239599afB305DA0A2eC69c58F8a6697F9F88d;
    address constant LP   = 0x77C6E4a580c0dCE4E5c7a17d0bc077188a83A059;

    function tok(uint256 k) internal pure returns (address) {
        if (k == 0) return 0x6B175474E89094C44Da98b954EedeAC495271d0F; // DAI
        if (k == 1) return 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // USDC
        if (k == 2) return 0xdAC17F958D2ee523a2206206994597C13D831ec7; // USDT
        return 0x0000000000085d4780B73119b644AE5ecd22b376;             // TUSD
    }

    // add_liquidity(amounts) then remove_liquidity(all minted LP); return [minted, final token balances x4]
    function roundtrip(uint256[4] calldata amounts) external returns (uint256[5] memory out) {
        ICurvePool(POOL).add_liquidity(amounts, 0);
        uint256 minted = IERC20(LP).balanceOf(address(this));
        out[0] = minted;
        ICurvePool(POOL).remove_liquidity(minted, [uint256(0), 0, 0, 0]);
        for (uint256 k = 0; k < 4; k++) out[k + 1] = IERC20(tok(k)).balanceOf(address(this));
    }

    // execute three swaps i->j->k->i with given first dx; return final token balances + [dy1, dy2, dy3]
    function triple(int128 i, int128 j, int128 k, uint256 dx) external returns (uint256[7] memory out) {
        uint256 b0 = IERC20(tok(uint256(uint128(j)))).balanceOf(address(this));
        uint256 c0 = IERC20(tok(uint256(uint128(k)))).balanceOf(address(this));
        ICurvePool(POOL).exchange(i, j, dx, 0);
        uint256 d1 = IERC20(tok(uint256(uint128(j)))).balanceOf(address(this)) - b0;
        ICurvePool(POOL).exchange(j, k, d1, 0);
        uint256 d2 = IERC20(tok(uint256(uint128(k)))).balanceOf(address(this)) - c0;
        ICurvePool(POOL).exchange(k, i, d2, 0);
        for (uint256 m = 0; m < 4; m++) out[m] = IERC20(tok(m)).balanceOf(address(this));
        out[4] = d1; out[5] = d2; out[6] = IERC20(tok(uint256(uint128(i)))).balanceOf(address(this));
    }

    // single swap i->j, return all four balances + input balance before
    function single(int128 i, int128 j, uint256 dx) external returns (uint256[5] memory out) {
        uint256 in0 = IERC20(tok(uint256(uint128(i)))).balanceOf(address(this));
        ICurvePool(POOL).exchange(i, j, dx, 0);
        for (uint256 m = 0; m < 4; m++) out[m] = IERC20(tok(m)).balanceOf(address(this));
        out[4] = in0;
    }
}
