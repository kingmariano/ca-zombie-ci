[Skip Navigation](#skip-link)

[![Code4rena Logo](/logos/c4/c4-logo.svg)](/)

- For Wardens

- [Support](/help)

- [Log in](/login)

## Login

[![login icon](/images/sign-out.svg)Log in / Register](/login)

[![Code4rena Logo](/logos/c4/c4-logo.svg)](/)

![Hybra Finance](/_next/image?url=https%3A%2F%2Fcode4-api-v0-public-storage.s3.us-east-1.amazonaws.com%2Fupload-BrxEwXizRhk&w=3840&q=75)

# Hybra Finance  
Findings & Analysis Report

#### 2025-11-20

## Table of contents

- [Overview](#overview)

  - [About C4](#about-c4)

- [Summary](#summary)

- [Scope](#scope)

- [Severity Criteria](#severity-criteria)

- [High Risk Findings (1)](#high-risk-findings-1)

  - [\[H-01\] Assets deposited before calculating shares amount to mint will cause users to mint less shares](#h-01-assets-deposited-before-calculating-shares-amount-to-mint-will-cause-users-to-mint-less-shares)

- [Medium Risk Findings (9)](#medium-risk-findings-9)

  - [\[M-01\] `CLFactory` ignores dynamic fees above 10% and silently falls back to default](#m-01-clfactory-ignores-dynamic-fees-above-10-and-silently-falls-back-to-default)

  - [\[M-02\] Users emergency withdrawing will lose all past accrued rewards](#m-02-users-emergency-withdrawing-will-lose-all-past-accrued-rewards)

  - [\[M-03\] First depositor attack possible through multiple attack paths because the deposit function does not check 0 shares received](#m-03-first-depositor-attack-possible-through-multiple-attack-paths-because-the-deposit-function-does-not-check-0-shares-received)

  - [\[M-04\] Dust vote on one pool prevents `poke()`](#m-04-dust-vote-on-one-pool-prevents-poke)

  - [\[M-05\] Rollover rewards are permanently lost due to flawed `rewardRate` calculation](#m-05-rollover-rewards-are-permanently-lost-due-to-flawed-rewardrate-calculation)

  - [\[M-06\] `ClaimFees` steals staking rewards](#m-06-claimfees-steals-staking-rewards)

  - [\[M-07\] Claiming rewards in `GovernanceHYBR` will always revert](#m-07-claiming-rewards-in-governancehybr-will-always-revert)

  - [\[M-08\] Incorrect voting power calculation when `create_lock` and `increase_amount` are called in the same transaction](#m-08-incorrect-voting-power-calculation-when-create_lock-and-increase_amount-are-called-in-the-same-transaction)

  - [\[M-09\] CL gauge accepts unverified pools, allowing malicious pool to brick distribution](#m-09-cl-gauge-accepts-unverified-pools-allowing-malicious-pool-to-brick-distribution)

- [Low Risk and Non-Critical Issues](#low-risk-and-non-critical-issues)

  - [QA report by rayss](#qa-report-by-rayss)

- [Mitigation Review](#mitigation-review)

  - [Introduction](#introduction)

  - [Mitigation Review Scope & Summary](#mitigation-review-scope--summary)

  - [Mitigation of M-09: Unmitigated](#mitigation-of-m-09-unmitigated)

  - [Mitigation of S-470: Unmitigated](#mitigation-of-s-470-unmitigated)

  - [\[MR M-01\] Deposit in `GovernanceHYBR` can Be DOSed for users](#mr-m-01-deposit-in-governancehybr-can-be-dosed-for-users)

  - [Step By Step Proof of Concept](#step-by-step-proof-of-concept)

  - [Recommended mitigation steps](#recommended-mitigation-steps-6)

- [Disclosures](#disclosures)

# [](#overview)Overview

## [](#about-c4)About C4

Code4rena (C4) is a competitive audit platform where security researchers, referred to as Wardens, review, audit, and analyze codebases for security vulnerabilities in exchange for bounties provided by sponsoring projects.

During the audit outlined in this document, C4 conducted an analysis of the Hybra Finance smart contract system. The audit took place from October 06 to October 16, 2025\.

Following the C4 audit, 3 wardens ([niffylord](https://code4rena.com/@niffylord), [rayss](https://code4rena.com/@rayss), and [ZanyBonzy](https://code4rena.com/@ZanyBonzy)) reviewed the mitigations for all sponsor-confirmed issues; the [mitigation review report](#mitigation-review) is appended below the audit report.

Final report assembled by Code4rena.

# [](#summary)Summary

The C4 analysis yielded an aggregated total of 10 unique vulnerabilities. Of these vulnerabilities, 1 received a risk rating in the category of HIGH severity and 9 received a risk rating in the category of MEDIUM severity.

Additionally, C4 analysis included 45 reports detailing issues with a risk rating of LOW severity or non-critical.

All of the issues presented here are linked back to their original finding, which may include relevant context from the judge and Hybra Finance team.

Considering the number of issues identified, it is statistically likely that there are more complex bugs still present that could not be identified given the time-boxed nature of this engagement. It is recommended that a follow-up audit and development of a more complex stateful test suite be undertaken prior to continuing to deploy significant monetary capital to production.

# [](#scope)Scope

The code under review can be found within the [C4 Hybra Finance repository](https://github.com/code-423n4/2025-10-hybra-finance), and is composed of 14 smart contracts written in the Solidity programming language and includes 3,846 lines of Solidity code.

The code in C4’s Hybra Finance repository was pulled from:

- Repository: [https://github.com/hybra-finance/hybra-finance](https://github.com/hybra-finance/hybra-finance)

- Commit hash: `480cb4ee6e604bdc9169f89094499bbc774f3dfa`

# [](#severity-criteria)Severity Criteria

C4 assesses the severity of disclosed vulnerabilities based on three primary risk categories: high, medium, and low/non-critical.

High-level considerations for vulnerabilities span the following key areas when conducting assessments:

- Malicious Input Handling

- Escalation of privileges

- Arithmetic

- Gas use

For more information regarding the severity criteria referenced throughout the submission review process, please refer to the documentation provided on [the C4 website](https://code4rena.com), specifically our section on [Severity Categorization](https://docs.code4rena.com/awarding/judging-criteria/severity-categorization).

# [](#high-risk-findings-1)High Risk Findings (1)

## [](#h-01-assets-deposited-before-calculating-shares-amount-to-mint-will-cause-users-to-mint-less-shares)[\[H-01\] Assets deposited before calculating shares amount to mint will cause users to mint less shares](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-321)

*Submitted by [asui](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-321), also found by [0xauditagent](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-760), [0xBugSlayer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-613), [0xJason](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-220), [0xnija](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-875), [0xRaz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-439), [Albert](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-715), [axelot](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-925), [ayden](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-312), [Boy2000](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-579), [classic-k](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-758), [dee24](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-382), [EtherEngineer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-685), [harry](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-570), [InvarianteX](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-266), [itsravin0x](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-779), [kjc](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-461), [KKKKK](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-243), [kmkm](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-520), [KuwaTakushi](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-546), [LhoussainePh](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-600), [luncy](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-780), [mbuba666](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-209), [oct0pwn](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-840), [Olami978355](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-399), [OnyxAudits](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-373), [piki](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-160), [silver\_eth](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-502), [Sourav\_DEV](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-803), [testnate](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-686), [the\_haritz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-870), [Vagner](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-507), [ZanyBonzy](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-460), and [zcai](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-666)*

`GovernanceHYBR.sol` [\#L137-L144](https://github.com/code-423n4/2025-10-hybra-finance/blob/66c42f3c9754f1b38942c69ebc0d3e4c0f8fdeb2/ve33/contracts/GovernanceHYBR.sol#L137-L144)

### [](#summary-1)Summary

```
        } else {
            // Add to existing veNFT
            IERC20(HYBR).approve(votingEscrow, amount);
            IVotingEscrow(votingEscrow).deposit_for(veTokenId, amount);

            // Extend lock to maximum duration
            _extendLockToMax();
        }
        
        // Calculate shares to mint based on current totalAssets
        uint256 shares = calculateShares(amount);
        
        // Mint gHYBR shares
        _mint(recipient, shares);
```

As we can see, the `GovernanceHYBR::deposit` function first deposits the HYBR into the votingEscrow before calculating and minting shares.

This will deposit the tokens first increasing the `totalAssets()` and the new `totalAssets()` will be used in `shares = calculateShares(amount)`

This results in incorrect calculation of shares for the users beause their deposits are treated as rewards and they are minted shares with the new rate and will suffer slippage from their own tokens.

Example:

- Initially Bob has a deposit of 100 gHYBR : 100 HYBR, ie.. 1:1 shares to asset ratio

- Alice also enter with 100 assets(HYBR),

- In an ideal condition, Alice is expected to recieve 100 shares because the ratio is 1:1 at the time of deposit

- but because deposit is done first before calculating shares,

- Alice will get, `shares = 100 * 100 / (100 +100)` i.e. only 50 shares

### [](#impact)Impact

Loss of assets for users by minting less shares.

### [](#recommended-mitigation-steps)Recommended mitigation steps

Make sure that the ratio at the time of deposit must be used to calculate the shares to mint:

```
        IERC20(HYBR).transferFrom(msg.sender, address(this), amount);
+       uint256 shares = calculateShares(amount);
        
        // Initialize veNFT on first deposit
        if (veTokenId == 0) {
            _initializeVeNFT(amount);
        } else {
            // Add to existing veNFT
            IERC20(HYBR).approve(votingEscrow, amount);
            IVotingEscrow(votingEscrow).deposit_for(veTokenId, amount);

            // Extend lock to maximum duration
            _extendLockToMax();
        }
        
        // Calculate shares to mint based on current totalAssets
-       uint256 shares = calculateShares(amount);
```

Proof of concept

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> S-321 calculating shares use the pool ratio at the time of deposit S-352 check share is zero S- 101 too many locks check

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-1).

---

# [](#medium-risk-findings-9)Medium Risk Findings (9)

## [](#m-01-clfactory-ignores-dynamic-fees-above-10-and-silently-falls-back-to-default)[\[M-01\] `CLFactory` ignores dynamic fees above 10% and silently falls back to default](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-133)

*Submitted by [niffylord](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-133), also found by [JuggerNaut63](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-477), [ljj](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-81), [Nexarion](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-146), and [ZanyBonzy](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-657)*

`CLFactory.sol` \[#L176-L189\[([https://github.com/code-423n4/2025-10-hybra-finance/blob/main/cl/contracts/core/CLFactory.sol#L176-L189](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/cl/contracts/core/CLFactory.sol#L176-L189))

### [](#summary-2)Summary

Governance can configure `DynamicSwapFeeModule` with fees up to 50%, but `CLFactory.getSwapFee` discards any value above 100\_000 ppm (10%) and falls back to the tick-spacing default (often 500 ppm = 0\.05%) without reverting or logging. Operators see the module reporting 20%, yet users continue paying the tiny default fee. The silent fallback misleads governance into believing higher fees are active.

### [](#impact-1)Impact

- Governance believes a protective high fee is set (e.g., during launch anti-MEV), but the effective fee drops back to the default (e.g., 0\.05%).

- Traders are charged far less than intended, defeating protective or revenue objectives.

- The misconfiguration has no on-chain signal, so the mistake can persist unnoticed.

### [](#root-cause)Root Cause

- `getSwapFee` checks `fee <= 100_000`; larger values are ignored and the function returns `tickSpacingToFee`.

- The module itself allows `feeCap` up to 500\_000 (50%), so governance can set a value the factory immediately discards in favor of the default.

Reference: [`cl/contracts/core/CLFactory.sol#L176-L189`](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/cl/contracts/core/CLFactory.sol#L176-L189)

### [](#mitigation)Mitigation

- Either revert when the module returns \> 100\_000 or raise the factory ceiling to match the module’s cap.

- Emit events or add admin tooling to surface out-of-range configurations so operators can correct them.

Proof of concept

\`\`\`bash cd cl forge test \--match-path test/PoC\_DynamicFee\_ClampToDefault.t.sol \-vvv \`\`\` The PoC lifts the module cap, sets a 20% custom fee, and shows that \`DynamicSwapFeeModule.getFee\` returns 200\_000 while \`CLFactory.getSwapFee\` still returns the base 500 ppm.

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> Added setMaxFee() function to make the fee cap configurable by the owner (up to 50%). This replaces the hardcoded limit and allows governance to adjust the maximum dynamic fee when needed.

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-2).

---

## [](#m-02-users-emergency-withdrawing-will-lose-all-past-accrued-rewards)[\[M-02\] Users emergency withdrawing will lose all past accrued rewards](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-80)

*Submitted by [Huntoor](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-80), also found by [ayden](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-307), [dee24](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-380), [kimnoic](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-113), [Nyxaris](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-344), [Olami978355](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-229), [rayss](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-306)*

*This issue was also [found](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-935) by [V12](https://v12.zellic.io).*

[https://github.com/code-423n4/2025-10-hybra-finance/blob/6299bfbc089158221e5c645d4aaceceea474f5be/ve33/contracts/GaugeV2.sol#L270-L281](https://github.com/code-423n4/2025-10-hybra-finance/blob/6299bfbc089158221e5c645d4aaceceea474f5be/ve33/contracts/GaugeV2.sol#L270-L281)

### [](#summary-3)Summary

in the `GaugeV2` contract, if the contract was emergency activated, users calling `emergencyWithdraw()` will lose all past accrued rewards that didn’t have `updateReward()` called on it previously

for a user to earn rewards, he gets his mappings updated here

```
    modifier updateReward(address account) {
        rewardPerTokenStored = rewardPerToken();
        lastUpdateTime = lastTimeRewardApplicable();
        if (account != address(0)) {
            rewards[account] = earned(account);
            userRewardPerTokenPaid[account] = rewardPerTokenStored;
        }
        _;
    }
```

as we see above, rewards mapping is registered as the return data from `earned()`, and when we look at it we see

```
    function earned(address account) public view returns (uint256) {
        return rewards[account] + _balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18;  
    }
```

we see that it returns old rewards \+ current balance of the user multiplied by the rewardPerToken (abstractly)

so what happen will be as follows:

1. User stake 100e18 tokens

2. emergency activated

3. he had already earnt before the emergency 10e18 tokens not registered on his rewards mapping since he didn’t call deposit/withdraw/getRewards to update his rewards

4. call emergencyWithdraw and his balance now is 0\.

5. now `earned()` function return 0 rewards since his balance is 0 \* rewardPerToken = 0

also the left-off rewards tokens are stuck in the contract forever.

Impact: Loss of rewards for users and stuck reward tokens in the contract

### [](#recommended-mitigation-steps-1)Recommended mitigation steps

Add the `updateReward` modifier to the `emergencyWithdraw()` call

Proof of concept

paste in \`ve33/test/C4PoC.t.sol\`

**Hybra Finance disputed this finding.**

---

## [](#m-03-first-depositor-attack-possible-through-multiple-attack-paths-because-the-deposit-function-does-not-check-0-shares-received)[\[M-03\] First depositor attack possible through multiple attack paths because the deposit function does not check 0 shares received](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-352)

*Submitted by [asui](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-352), also found by [0xBugSlayer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-617), [0xDemon](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-475), [0xPSB](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-837), [Almanax](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-457), [ayden](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-311), [blokfrank](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-474), [classic-k](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-804), [CoheeYang](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-755), [EtherEngineer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-597), [fullstop](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-345), [Huntoor](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-464), [ibrahimatix0x01](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-25), [IzuMan](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-855), [kestyvickky](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-11), [khaye26](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-899), [MoZi](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-432), [odeili](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-82), [osok](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-429), [piki](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-236), [queen](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-836), [reidnerFM](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-272), [rzizah](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-882), [Sancybars](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-604), [Sejin](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-304), [shieldrey](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-343), [silver\_eth](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-538), [the\_haritz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-897), [zoox](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-626), and [zubyoz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-383)*

- `GovernanceHYBR.sol` [\#L144](https://github.com/code-423n4/2025-10-hybra-finance/blob/66c42f3c9754f1b38942c69ebc0d3e4c0f8fdeb2/ve33/contracts/GovernanceHYBR.sol#L144)

- `GovernanceHYBR.sol` [\#L492-L509](https://github.com/code-423n4/2025-10-hybra-finance/blob/66c42f3c9754f1b38942c69ebc0d3e4c0f8fdeb2/ve33/contracts/GovernanceHYBR.sol#L492-L509)

- `GovernanceHYBR.sol` [\#L238](https://github.com/code-423n4/2025-10-hybra-finance/blob/66c42f3c9754f1b38942c69ebc0d3e4c0f8fdeb2/ve33/contracts/GovernanceHYBR.sol#L238)

### [](#summary-4)Summary

The gHYBR contract is just another veNFT position holder from the perspective of votingEscrow contract, while the gHYBR contract acts as a vault.

And the deposit does not ensure that we mint at least one gHYBR share. This can lead to a contdition where the first depositor attacks another user.

Example:

- Alice deposits dust shares, 1 share : 1 asset

- Alice donates 1000e18 assets before Bob deposits, through `deposit_for`, and he increased the ratio by `1 shares : 1000e18 assets`

- Bob deposits 100e18 assets, the shares calculation goes `100e18 * 1 / 1000e18` and rounds down to 0

- Receives 0 shares

- All bob’s deposit is captured by Alice’s shares

- Bob deposits 100e18 assets and receives 0 shares

- Alice has 1 share worth `1000e18 + 100e18(bob's) assets`

The entry points the attacker can use to perform this attack are:

1. The votingEscrow contract allows anyone to deposit assets for any position through its public `deposit_for(uint _tokenId, uint _value) external nonreentrant` function.

2. The `receivePenaltyReward` function in `GovernanceHYBR` contract lacks access controll, which allows an attacker to donate to increase totalAssets.

3. Attacker can utilize multiSplit through withdraw, by first depositing 1000:1000 and withdrawing so that the leftover is 1:1 ratio dust.

### [](#recommended-mitigation-steps-2)Recommended mitigation steps

My best suggestion is to require `share > 0` in the deposit function in the `GovernanceHYBR` contract, and also add access control for the `receivePenaltyReward` function.

Proof of concept

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> Added setMaxFee() function to make the fee cap configurable by the owner (up to 50%). This replaces the hardcoded limit and allows governance to adjust the maximum dynamic fee when needed.

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-3).

---

## [](#m-04-dust-vote-on-one-pool-prevents-poke)[\[M-04\] Dust vote on one pool prevents `poke()`](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-118)

*Submitted by [Huntoor](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-118), also found by [0xDjango](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-789), [OpaBatyo](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-435), and [Vagner](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-331)*

`VoterV3.sol` [\#L208-L211](https://github.com/code-423n4/2025-10-hybra-finance/blob/6299bfbc089158221e5c645d4aaceceea474f5be/ve33/contracts/VoterV3.sol#L208-L211)

### [](#summary-5)Summary

before describing the vulnerability, we should know that in ve3.3 systems, `poke` is important to make anyone reflect the decaying vote weight to prevent users from being inactive on votes to have their full weight votes on a pool.

in `VoterV3` users chose what pools they want to vote for and the contract retrieve their `ve` weight upon doing so

```
        uint256 _weight = IVotingEscrow(_ve).balanceOfNFT(_tokenId);
```

and upon voting for a pool, that weight affect the claimable share distribution of that pool compared to other pools

```
File: GaugeManager.sol
376:         uint256 _supplied = IVoter(voter).weights(_pool);
377: 
378:         if (_supplied > 0) {
379:             uint256 _supplyIndex = supplyIndex[_gauge];
380:             uint256 _index = index; // get global index0 for accumulated distro
381:             // SupplyIndex will be updated for Killed Gauges as well so we don't need to udpate index while reviving gauge.
382:             supplyIndex[_gauge] = _index; // update _gauge current position to global position
383:             uint256 _delta = _index - _supplyIndex; // see if there is any difference that need to be accrued
384:             if (_delta > 0) {
385:                 uint256 _share = _supplied * _delta / 1e18; // add accrued difference for each supplied token
386:                 if (isAlive[_gauge]) {
387:                     claimable[_gauge] += _share;
```

since now we now the importance of the voting weight, and since ve NFT weight decay with time, there is a poke function to update the voting weight made on a pool previously to the decayed weight of than NFT

The `poke()` function is guarded to be called by the owner or through the `ve` contract which can have any one depositing for a user or increasing his locked value even by `1wei` to poke him to reflect his new decayed weight on the voted pools

An attacker can do the following:

1. vote his full weight \- `1wei`on a dedicated pool

2. vote 1 wei on another pool

3. time passes with inactivity from his side \- his `ve` decay but is not reflected on voted pools

4. users try to `poke()` him through known functions of the `ve` contract

5. `poke()` function revert here

```
File: VoterV3.sol
208:                 uint256 _poolWeight = _weights[i] * _weight / _totalVoteWeight;
209: 
210:                 require(votes[_tokenId][_pool] == 0, "ZV");
211:                 require(_poolWeight != 0, "ZV");
```

since the `1wei` vote multiplied by the decayed weight divided by totalVoteWeight round down to 0, hence this users become unpokable.

### [](#impact-2)Impact

the voted for pool will have inflated rewards distributed to him compared to other pools that have pokable users. thinking of this attack at scale

the user will have advantage of having full voting weight if he vote immediately like having permanent lock weight without actually locking his balance permanently. preventing any one from preserving this invariant `A single veNFT’s total vote allocation ≤ its available voting power.` on his vote balance too

### [](#recommended-mitigation-steps-3)Recommended mitigation steps

Change the require statement to `if` statement such that

```
if (_poolWeight = 0) continue;
```

so we neglect the dust voted pool.

Proof of concept

The following lines were commented during test setup, but they are irrelevant to the bug. \`\`\`solidity File: VoterV3.sol 160: if (\_timestamp \<= HybraTimeLibrary.epochVoteStart(\_timestamp)){ 161: revert("DW"); 162: } \`\`\` and \`\`\`solidity File: VoterV3.sol 235: if (HybraTimeLibrary.epochStart(block.timestamp) \<= lastVoted\[\_tokenId\]) revert("VOTED"); 236: if (block.timestamp \<= HybraTimeLibrary.epochVoteStart(block.timestamp)) revert("DW"); \`\`\`

**Hybra Finance disputed this issue.**

---

## [](#m-05-rollover-rewards-are-permanently-lost-due-to-flawed-rewardrate-calculation)[\[M-05\] Rollover rewards are permanently lost due to flawed `rewardRate` calculation](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-356)

*Submitted by [osok](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-356), also found by [Ibukun](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-318), [odeili](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-171)*

*This issue was also [found](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-629) by [V12](https://v12.zellic.io).*

`GaugeCL.sol` [\#L256](https://github.com/code-423n4/2025-10-hybra-finance/blob/66c42f3c9754f1b38942c69ebc0d3e4c0f8fdeb2/ve33/contracts/CLGauge/GaugeCL.sol#L256)

### [](#summary-6)Summary

The `notifyRewardAmount()` function miscalculates the `rewardRate` when a new epoch begins, causing `rollover` rewards from previous epochs to be permanently lost.

When `block.timestamp >= _periodFinish`, the function adds both the new `rewardAmount` and the previous epoch’s `clPool.rollover()` to form the `totalRewardAmount`. However, the `rewardRate` is derived only from `rewardAmount`, ignoring the rollover portion:

```
// @audit The total amount to be reserved includes rollover...
uint256 totalRewardAmount = rewardAmount + clPool.rollover();
if (block.timestamp >= _periodFinish) {
    // @audit but the rate calculation completely ignores the rollover.
    rewardRate = rewardAmount / epochTimeRemaining;
    
    // @audit The pool is synced with a CORRECT reserve but an INCORRECTLY LOW rate.
    clPool.syncReward({
        rewardRate: rewardRate,
        rewardReserve: totalRewardAmount, // Correct total
        periodFinish: epochEndTimestamp
    });
}
```

This mismatch means the pool receives the full reserve (new \+ rollover) but emits rewards too slowly to deplete it. The rollover portion remains stranded, and when the next epoch begins, it is overwritten and effectively erased. The logic in the `else` branch fails to correct this issue; instead, it perpetuates the error. The updated rate is calculated using the old, already flawed `rewardRate`, ensuring that once `rollover` funds are stranded, they can never be reclaimed through subsequent reward notifications.

### [](#impact-3)Impact

1. Permanent Loss of Funds: Unclaimed rollover rewards are locked in the contract and cannot be recovered.

2. Reduced LP Yields: Liquidity providers earn less than intended, as part of their entitled rewards never distribute.

3. Protocol Resource Waste: Tokens from the treasury or partners are effectively burned, wasting incentive funds.

### [](#recommended-mitigation-steps-4)Recommended mitigation steps

The `rewardRate` calculation should include the `rollover` amount to ensure the emission rate matches the total rewards available for distribution. This change guarantees that all `rollover` rewards are correctly accounted for and eventually distributed. In `GaugeCL.sol`:

```
-   rewardRate = rewardAmount / epochTimeRemaining;
+   rewardRate = totalRewardAmount / epochTimeRemaining;
    clPool.syncReward({
        rewardRate: rewardRate,
        rewardReserve: totalRewardAmount,
        periodFinish: epochEndTimestamp })
```

### [](#proof-of-concept)Proof of concept

*Please refer to the [original submission](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-356) to view the coded proof of concept.*

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> fix \- S-36 ClaimFees Steals Staking Rewards fix \- S-841 rollover rewardRate calcuate fix \- S-645 Missing unchecked block in Gauge Dependent Library Will Cause Freezing of Reward Calculations

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-21).

---

## [](#m-06-claimfees-steals-staking-rewards)[\[M-06\] `ClaimFees` steals staking rewards](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-36)

*Submitted by [0xSeer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-36), also found by [EtherEngineer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-730), [hecker\_trieu\_tien](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-288), [ibrahimatix0x01](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-63), [maze](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-365), [piki](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-58), [saraswati](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-526), [Xander](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-167), and [zcai](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-672)*

`CLGauge/GaugeCL.sol` [\#L304-L335](https://github.com/code-423n4/2025-10-hybra-finance/blob/6299bfbc089158221e5c645d4aaceceea474f5be/ve33/contracts/CLGauge/GaugeCL.sol#L304-L335)

### [](#description)Description

The `_claimFees` function is designed to collect accrued trading fees from the underlying concentrated liquidity pool and transfer them to a designated `internal_bribe` contract. The function determines the amount of fees to transfer by checking the gauge’s *entire* token balance for `token0` and `token1` after calling `clPool.collectFees()`.

The critical vulnerability lies in this assumption. The contract has another mechanism to receive tokens: the `notifyRewardAmount` function, which is called by the `DISTRIBUTION` contract to fund the gauge with `rewardToken` for stakers.

If the `rewardToken` is the same as either `token0` or `token1` of the pool (a common scenario in DeFi, e.g., rewarding a WETH/USDC pool with WETH), the `claimFees` function will incorrectly identify the staking rewards as trading fees. Because `claimFees` is a public function with no access control, anyone can call it right after rewards are deposited, causing all reward funds to be swept to the `internal_bribe` contract.

### [](#impact-4)Impact

This vulnerability leads to a direct loss of funds for users who have staked their NFTs in the gauge. All `rewardToken`s intended for stakers during an epoch can be permanently redirected and stolen from them. This breaks the core incentive mechanism of the gauge.

Furthermore, the gauge’s internal accounting for rewards (`rewardRate`, `_periodFinish`) becomes completely desynchronized from its actual token balance. This can lead to a secondary Denial-of-Service (DoS) condition, as future calls to `notifyRewardAmount` may fail on the `require(rewardRate <= contractBalance / epochTimeRemaining, ...)` check, preventing the gauge from being funded for subsequent epochs.

### [](#attack-scenario)Attack Scenario

1. A gauge is set up for a WETH/USDC pool, with WETH as the `rewardToken`.

2. The `DISTRIBUTION` contract calls `notifyRewardAmount`, transferring 10 WETH to the gauge as staking rewards for the upcoming week.

3. An attacker immediately calls the public `claimFees()` function.

4. The function calls `clPool.collectFees()`, which might transfer a small amount of WETH fees (e.g., 0\.1 WETH) to the gauge.

5. The function then reads the gauge’s total WETH balance, which is now 10\.1 WETH (10 WETH from rewards \+ 0\.1 WETH from fees).

6. It proceeds to transfer the entire 10\.1 WETH to the `internal_bribe` contract.

7. The 10 WETH in rewards are now lost to the stakers. The gauge has no funds to pay out the promised rewards.

### [](#recommendation)Recommendation

The `_claimFees` function must be modified to only transfer the fees that are explicitly collected by the `clPool.collectFees()` call, rather than sweeping the contract’s entire balance. This can be achieved by measuring the contract’s balance of `token0` and `token1` immediately before and after the `collectFees()` call and only transferring the difference.

```
function _claimFees() internal returns (uint256 claimed0, uint256 claimed1) {
    if (!isForPair) {
        return (0, 0);
    }
    
    address _token0 = clPool.token0();
    address _token1 = clPool.token1();

    uint256 balance0Before = IERC20(_token0).balanceOf(address(this));
    uint256 balance1Before = IERC20(_token1).balanceOf(address(this));

    clPool.collectFees();

    uint256 balance0After = IERC20(_token0).balanceOf(address(this));
    uint256 balance1After = IERC20(_token1).balanceOf(address(this));

    claimed0 = balance0After - balance0Before;
    claimed1 = balance1After - balance1Before;

    if (claimed0 > 0) {
        IERC20(_token0).safeApprove(internal_bribe, 0);
        IERC20(_token0).safeApprove(internal_bribe, claimed0);
        IBribe(internal_bribe).notifyRewardAmount(_token0, claimed0);
    } 
    if (claimed1 > 0) {
        IERC20(_token1).safeApprove(internal_bribe, 0);
        IERC20(_token1).safeApprove(internal_bribe, claimed1);
        IBribe(internal_bribe).notifyRewardAmount(_token1, claimed1);
    } 
    
    if (claimed0 > 0 || claimed1 > 0) {
        emit ClaimFees(msg.sender, claimed0, claimed1);
    }
}
```

Additionally, consider adding access control to the `claimFees` function (e.g., `onlyOwner` or a dedicated keeper role) to prevent potential griefing attacks and ensure it is called under intended conditions.

Proof of concept

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> fix \- S-36 ClaimFees Steals Staking Rewards fix \- S-841 rollover rewardRate calcuate fix \- S-645 Missing unchecked block in Gauge Dependent Library Will Cause Freezing of Reward Calculations

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-32).

---

## [](#m-07-claiming-rewards-in-governancehybr-will-always-revert)[\[M-07\] Claiming rewards in `GovernanceHYBR` will always revert](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-448)

*Submitted by [OpaBatyo](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-448), also found by [0xvd](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-742) and [harry](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-610)*

`GovernanceHYBR.sol` [\#L370](https://github.com/code-423n4/2025-10-hybra-finance/blob/74c2b93e8a4796c1d41e1fbaa07e40b426944c44/ve33/contracts/GovernanceHYBR.sol#L370)

### [](#details)Details

When the operator [claims rewards](https://github.com/code-423n4/2025-10-hybra-finance/blob/74c2b93e8a4796c1d41e1fbaa07e40b426944c44/ve33/contracts/GovernanceHYBR.sol#L359-L415) in `GovernanceHYBR.sol`, the function attempts to fetch the voted pools aray from the voter contract:

```
    // Claim bribes from voted pools
    address[] memory votedPools = IVoter(voter).poolVote(veTokenId);
```

This line will always revert and the function is broken. It attempts to fetch the addresses array from a mapping in `VoterV3.sol`:

```
    mapping(uint256 => address[]) public poolVote;
```

This will not work \- the way solidity auto-generates a getter for a mapping is using an id and index. Although this exists in the [interface](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/interfaces/IVoter.sol), it is not used correctly in the function to claim itself:

```
    function poolVote(uint id, uint _index) external view returns(address _pair); // correct way to be fetched
```

But the way it’s fetched in `claimRewards()` will not work since solidity cannot return an addresses array using only the `tokenId` of the mapping.

### [](#impact-5)Impact

Function is completely broken.

### [](#mitigation-1)Mitigation

Add a getter function in `VoterV3.sol` that returns an array of addresses and use that instead when claiming rewards:

```
    function getPoolVote(uint tokenId) external view returns (address[] memory) {
        return poolVote[tokenId];
    }
```

Proof of concept

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> fixed Claiming rewards in GovernanceHYBR

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-13).

---

## [](#m-08-incorrect-voting-power-calculation-when-create_lock-and-increase_amount-are-called-in-the-same-transaction)[\[M-08\] Incorrect voting power calculation when `create_lock` and `increase_amount` are called in the same transaction](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-635)

*Submitted by [dreamcoder](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-635), also found by [fullstop](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-328)*

`VotingEscrow.sol` [\#L760](https://github.com/code-423n4/2025-10-hybra-finance/blob/74c2b93e8a4796c1d41e1fbaa07e40b426944c44/ve33/contracts/VotingEscrow.sol#L760)

### [](#summary-7)Summary

In `VotingEscrow.sol`:

```
function _checkpoint(
        uint _tokenId,
        IVotingEscrow.LockedBalance memory old_locked,
        IVotingEscrow.LockedBalance memory new_locked
    ) internal {

    // ...

    if (_tokenId != 0) {

        // ...
        uint user_epoch = votingBalanceLogicData.user_point_epoch[_tokenId] + 1;

        votingBalanceLogicData.user_point_epoch[_tokenId] = user_epoch;
        u_new.ts = block.timestamp;
        u_new.blk = block.number;
        votingBalanceLogicData.user_point_history[_tokenId][user_epoch] = u_new;

    }

}
```

If the second \_checkpoint runs in the same transaction as the first \_checkpoint, the function creates a new epoch even though both locks has the same timestamp. As a result, when calculating balanceOfNFT, the second lock is ignored. This means the voting power is computed using the old lock amount, and the newly added amount is not included.

Therefore, voting power is calculated incorrectly and users will lose rewards when the functions that call *checkpoint (increase*amount, deposit*for, create*lock, merge, split etc) are executed within the same transaction.

### [](#recommended-mitigation-steps-5)Recommended mitigation steps

```
function _checkpoint(
        uint _tokenId,
        IVotingEscrow.LockedBalance memory old_locked,
        IVotingEscrow.LockedBalance memory new_locked
    ) internal {

    // ...

    if (_tokenId != 0) {

        // ...
-        uint user_epoch = votingBalanceLogicData.user_point_epoch[_tokenId] + 1;
-        votingBalanceLogicData.user_point_epoch[_tokenId] = user_epoch;
-        u_new.ts = block.timestamp;
-        u_new.blk = block.number;
-        votingBalanceLogicData.user_point_history[_tokenId][user_epoch] = u_new;

+        uint user_epoch = votingBalanceLogicData.user_point_epoch[_tokenId];
+        if (user_epoch > 0 && votingBalanceLogicData.user_point_history[_tokenId][user_epoch].ts == block.timestamp) {
      // overwrite the latest point (same timestamp)
+            u_new.ts = block.timestamp;
+            u_new.blk = block.number;
+            votingBalanceLogicData.user_point_history[_tokenId][user_epoch] = u_new;
+         } else {
      // append new point
+            user_epoch = user_epoch + 1;
+            votingBalanceLogicData.user_point_epoch[_tokenId] = user_epoch;
+            u_new.ts = block.timestamp;
+            u_new.blk = block.number;
+            votingBalanceLogicData.user_point_history[_tokenId][user_epoch] = u_new;
         }
    }

}
```

Proof of concept

In \`/ve33/test/C4PoC.t.sol\`:

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> S-635 Fix voting power when create*lock \+ increase*amount in same tx Ensure correct voting power calculation when create*lock and increase*amount are called in the same transaction. S-470 Penalty Mechanism for PartnerNFT

**Status:** Mitigation confirmed. Full details in the [mitigation review reports from niffylord, rayss, and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-17).

---

## [](#m-09-cl-gauge-accepts-unverified-pools-allowing-malicious-pool-to-brick-distribution)[\[M-09\] CL gauge accepts unverified pools, allowing malicious pool to brick distribution](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-66)

*Submitted by [niffylord](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-66), also found by [adriansham99](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-143), [blokfrank](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-55), [ChainSentry](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-184), [freescore](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-285), [InvarianteX](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-367), [mbuba666](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-330), [Nyxaris](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-219), [omeiza](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-52), [piki](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-124), [PotEater](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-249), [Vagner](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-190), [Waze](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-313), [whiterabbit](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-48), and [Wojack](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-221)*

*This issue was also [found](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-631) by [V12](https://v12.zellic.io).*

- `GaugeManager.sol` [\#L165-L189](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/GaugeManager.sol#L165-L189)

- `GaugeManager.sol` [\#L185-L189](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/GaugeManager.sol#L185-L189)

- `GaugeManager.sol` [\#L197-L201](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/GaugeManager.sol#L197-L201)

- `GaugeCL.sol` [\#L239-L246](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/CLGauge/GaugeCL.sol#L239-L246)

### [](#summary-8)Summary

When creating concentrated-liquidity (CL) gauges, `GaugeManager._createGauge()` never verifies that the provided pool address is a genuine CL pool deployed by the trusted factory. Any contract that exposes `token0()`/`token1()` and passes token whitelist checks is accepted. GaugeCL later calls untrusted pool methods (e.g., `updateRewardsGrowthGlobal()`), so a malicious “pool” can revert and permanently brick emissions distribution once voted.

### [](#impact-6)Impact

- Unprivileged actor creates a fake CL pool and a gauge for it. When any veNFT votes for the pool, `GaugeManager.distribute*()` reverts via `GaugeCL.notifyRewardAmount()`, halting rewards for all pools until governance kills the malicious gauge.

- Operational liveness risk; automation for distribution breaks. Emissions accounting stalls and requires manual intervention.

### [](#root-cause-1)Root Cause

The vulnerability exists at line 181-184 of GaugeManager.sol where CL pools bypass factory verification:

```
if(_gaugeType == 0){
    isPair = IPairFactory(_factory).isPair(_pool);  // ✅ Standard pairs ARE verified
} 
if(_gaugeType == 1) {
    // removed due to code size
    // require(_pool_hyper == _pool_factory, 'wrong tokens');    
    isPair = true;  // ❌ CL pools NOT verified - just set to true!
}
```

**Critical Evidence**: The inline comment `// removed due to code size` reveals that developers were **aware** that proper validation should exist but deliberately removed it to save bytecode. The commented-out code shows the intended check was comparing pool addresses from factory.

This creates a dangerous inconsistency:

- **Standard pairs (\_gaugeType == 0)**: Properly validated via `IPairFactory.isPair(_pool)`

- **CL pools (\_gaugeType == 1)**: Accept ANY contract implementing `token0()`/`token1()` \- no factory verification

Detailed locations:

- GaugeManager accepts any `_pool` for `_gaugeType == 1` and sets `isPair = true` without validation: [https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/GaugeManager.sol#L165-L189](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/GaugeManager.sol#L165-L189)

- GaugeCL trusts the pool and calls into it on distribution: [https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/CLGauge/GaugeCL.sol#L239-L246](https://github.com/code-423n4/2025-10-hybra-finance/blob/main/ve33/contracts/CLGauge/GaugeCL.sol#L239-L246)

### [](#recommended-mitigation)Recommended Mitigation

- Enforce provenance: require `_pool` to originate from the approved CL factory (e.g., `ICLFactory(_pairFactoryCL).getPool(token0, token1, tickSpacing) == _pool`) before gauge creation.

- Alternatively, restrict CL gauge creation to governance and only for pools discovered via the factory.

- Optionally, quarantine failing gauges in `distribute*` via try/catch and return their claimable emissions to the minter to preserve global liveness.

Proof of concept

Run the included Foundry test, which deploys a malicious CL pool that reverts in \`updateRewardsGrowthGlobal()\` and shows distribution bricking after voting.

**[Hybra Finance mitigated](https://github.com/code-423n4/2025-11-hybra-finance-mitigation?tab=readme-ov-file#mitigations-of-high--medium-severity-issues):**

> Added access control: only the GaugeManager can call the GaugeFactory to create gauges.

**Status:** Unmitigated. Full details in the [mitigation review reports from niffylord and ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-38).

---

# [](#low-risk-and-non-critical-issues)Low Risk and Non-Critical Issues

For this audit, 45 reports were submitted by wardens detailing low risk and non-critical issues. The [report highlighted below](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-916) by **rayss** received the top score from the judge.

*The following wardens also submitted reports: [0xkhwarix](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-165), [0xki](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-424), [0xnija](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-932), [0xsai](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-832), [albahaca](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-353), [Almanax](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-656), [ARMoh](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-862), [asotu3](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-700), [baccarat](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-127), [Bale](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-879), [cheatc0d3](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-903), [ciphermalware](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-145), [dee24](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-420), [dmdg321](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-893), [EtherEngineer](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-825), [francoHacker](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-909), [freescore](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-391), [fromeo\_016](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-713), [Gujarati07](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-562), [Harisuthan](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-129), [hypna](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-15), [IvanAlexandur](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-905), [jerry0422](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-931), [johnyfwesh](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-889), [K42](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-292), [kmkm](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-534), [Mathriel](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-401), [maze](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-337), [mbuba666](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-368), [newspacexyz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-727), [niffylord](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-70), [oct0pwn](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-851), [osok](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-707), [PolarizedLight](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-729), [psyone](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-323), [reidnerFM](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-506), [Sancybars](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-823), [Silverwind](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-791), [Sourav\_DEV](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-928), [Sparrow](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-922), [valarislife](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-595), [winnerz](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-651), [ZanyBonzy](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-901), and [zcai](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-680).*

## [](#qa-report-by-rayss)QA report by rayss

*The report consists of low-severity risk issues and a few non-critical issues in the end.*

### [](#findings-overview)Findings Overview

| Label | Description | Severity |
| --- | --- | --- |
| L‑01 | Permanent Denial of Service in collectAllProtocolFees() | Low |
| L‑02 | It is Possible to Create a Gauge with rewardToken = 0x0 and Can Permanently Lock User’s Nft | Low |
| L‑03 | Protocol loss: Unrecoverable Dust Locked Due to Incorrect Decrement Before Transfer | Low |
| L‑04 | Incorrect Time Constants in Withdrawal Window Logic | Low |
| L‑05 | Split Restriction Bypass via NFT Transfer to Allowed User | Low |
| L‑06 | transferFrom() breaks erc20 compliance | Low |
| L‑07 | previewAvailable() view function can be dosed | Low |
| L‑08 | User’s rewards are slowly depleted on ever deposit/getReward function called in GaugeV2 | Low |
| I‑01 | OnReward() does not exist | Informational |
| NC‑01 | Incorrect require statement in setInternalBribe() | Non-Critical |
| NC‑02 | Redundant maturity check in \_withdraw() | Non-Critical |

### [](#l-01-permanent-denial-of-service-in-collectallprotocolfees)L-01: Permanent Denial of Service in collectAllProtocolFees()

In the CLFactory contract,

The collectAllProtocolFees() function is vulnerable to a potential permanent denial of service (DoS) condition. Since pool creation is permissionless, any user can repeatedly call createPool() to add an arbitrary number of pools to the global allPools array. When collectAllProtocolFees() iterates over this unbounded list, the loop can easily exceed the gas limit, causing the transaction to revert and effectively disabling the function permanently.

```
 function collectAllProtocolFees() external  { 
        require(msg.sender == owner);

        for (uint256 i = 0; i < allPools.length; i++) {
            CLPool(allPools[i]).collectProtocolFees(msg.sender);
        }
    }
```

**Impact**

- Denial of service: Owner’s single-call fee sweep can be blocked or made impractically expensive by mass pool creation.

**Recommended mitigation steps**

Stop relying on a single global loop: add collectFeesBatch(start, end) so collections are done in gas-bounded chunks.

### [](#l-02-it-is-possible-to-create-a-gauge-with-rewardtoken--0x0-and-can-permanently-lock-users-nft)L-02: It is Possible to Create a Gauge with rewardToken = 0x0 and Can Permanently Lock User’s Nft

Anyone can create a gauge its permissionless, any user can create a gauge with rewardToken set as 0x0 address, users who interact(deposit their nft) with that faulty gauge can permanently lock their nft inside the contract

**Impact**

In `_getReward` safe approve will always fail, SO this mean when a user deposits he can never withdraw, because inside the withdraw function \_getReward is called and it will always revert so users deposited funds are locked in the contract.

**Mitigation**

Add a require(rewardToken!=address(0x0)) in the createGauge function in the GaugeFactoryCL contract

### [](#l-03-protocol-loss-unrecoverable-dust-locked-due-to-incorrect-decrement-before-transfer)L-03: Protocol loss: Unrecoverable Dust Locked Due to Incorrect Decrement Before Transfer

In the `CLPool` contract, the `collectProtocolFees()` function, the contract clears the `protocolFees` slot to zero and then performs —amount before transferring tokens:

```
protocolFees.token0 = 0;
TransferHelper.safeTransfer(token0, recipient, --amount0);
protocolFees.token1 = 0;
TransferHelper.safeTransfer(token1, recipient, --amount1);
```

This results in 2 wei of each token being permanently locked in the contract. Since the fee slot is already reset to zero, this residual amount is no longer accounted for and cannot be recovered, leading to silent value loss over multiple calls.

You can see in the function just above it collectFees(), they have not cleared the slot but rather set it to 1, however in the collectProtocolFees() they have cleared the slot hence the `--` operator will just make 2 wei stuck on every call.

Here’s a clear example:

- If protocolFees.token0 = 100: protocolFees.token1 = 100;

- The code sets it to 0 for both the tokens

- The code decrement amount0 and amount1 to 99

- The code transfers 99 tokens

The contract’s balance still contains 2 wei, but protocolFees.token0 and protocolFees.token0 no longer tracks it

That 2 wei is orphaned — it’s not assigned to fees and the protocol has no function to recover it.

**Impact**

This small value can slowly accumulate and lead to a large value, hence loss of the protocol.

**Recommended mitigation steps**

Remove the ”—” from amount0 and amount1, heres the updated code:

```
    function collectProtocolFees(address recipient) external  lock  returns (uint128 amount0, uint128 amount1) {
        require(msg.sender == factory);
        amount0 = protocolFees.token0;
        amount1 = protocolFees.token1;
        if (amount0 > 0) {
            protocolFees.token0 = 0;
            TransferHelper.safeTransfer(token0, recipient, amount0);
        }
        if (amount1 > 0) {
            protocolFees.token1 = 0;
            TransferHelper.safeTransfer(token1, recipient, amount1);
        }
        // emit CollectProtocolFees(recipient, amount0, amount1);
    }
```

### [](#l-04-incorrect-time-constants-in-withdrawal-window-logic)L-04: Incorrect Time Constants in Withdrawal Window Logic

The variables head*not*withdraw*time and tail*not*withdraw*time are incorrectly set to 1200 and 300, while the comments indicate they should represent 5 days and 1 day respectively. This mismatch causes the withdrawal restriction window to last only minutes instead of days.

**Impact**

Users can withdraw prematurely—within minutes of an epoch start—bypassing the intended cooldown or restriction period.

**Recommended mitigation steps:**

Update constants to reflect intended durations:

```
uint256 public head_not_withdraw_time = 5 days;
uint256 public tail_not_withdraw_time = 1 days;
```

or use equivalent second values (432000 and 86400).

### [](#l-05-split-restriction-bypass-via-nft-transfer-to-allowed-user)L-05: Split Restriction Bypass via NFT Transfer to Allowed User

The splitAllowed modifier is meant to restrict multiSplit() actions to team-approved users. However, since NFTs can be freely transferred, a non-allowed user can transfer their NFT to an allowed user, who then performs multiSplit and returns the resulting NFTs — effectively bypassing the intended restriction.

**Impact**

- Bypass of a key constraint

- This allows non-approved users to indirectly perform multiSplit, undermining the access control enforced by splitAllowed. It nullifies the team’s intended control over who can split NFTs, potentially enabling abuse.

**Recommended mitigation steps**

Enforce ownership-based restriction by validating the original owner or source of the NFT in multiSplit, or implement an immutable flag within each NFT recording whether it was originally owned by an approved splitter.

### [](#l-06-transferfrom-breaks-erc20-compliance)L-06: transferFrom() breaks erc20 compliance

In `HYBR.sol`, the `transferFrom` function is responsible for allowing a spender to transfer tokens on behalf of an owner within an approved allowance. In the current implementation, there is no check to ensure the spender does not exceed their allowed amount.

**Impact**

This breaks the erc20 compliance since it expects to revert.

**Mitigation**

Add a check before decrementing the allowance:

```
require(allowed_from >= _value, "ERC20: transfer amount exceeds allowance");
```

### [](#l-07-previewavailable-view-function-can-be-dosed)L-07: previewAvailable() view function can be dosed

The `previewAvailable()` view function can be dosed by any attacker via depositing dust amounts, during a deposit a lock is created and this function loops through all of the locks ever created for that user.

Due to gas exhaustion this function can be dosed.

**Impact**

This function was made for users to see their balance, but under this attack vector the user is permanently dosed from using this functionality.

**Mitigation**

Remove the recipient logic from the deposit function.

### [](#l-08-users-rewards-are-slowly-depleted-on-ever-depositgetreward-function-called-in-gaugev2)L-08: User’s rewards are slowly depleted on ever deposit/getReward function called in GaugeV2

The earned function calculates user rewards using integer math:

```
rewards[account] + _balanceOf(account) * (rewardPerToken() - userRewardPerTokenPaid[account]) / 1e18
```

Repeated deposits trigger updates to the rewards of the user which causes small rounding errors.

Integer division takes place twice, once in earned() and another in rewardPerToken()

**Impact**

- This small rounded values can gradually accumulate to a larger value.

- Leading to slow and gradual loss of rewards

- Every time an function with the updateReward modifier is called, user faces this loss.

**Mitigation**

Protocol can potentially use higher precision to avoid such rounding down or consider storing rewards in a fixed-point library or using SafeMath for intermediate steps to minimize rounding loss.

### [](#i-01-onreward-does-not-exist)I-01: OnReward() does not exist

In the provided repo, none of the contracts has the OnReward function defined, The `OnReward` function was present in the `GaugeExtraRewarder` contract from blackhole but it seems the contract has been removed from the repo(mabye because the protocol no longer decides to use it), `OnReward()` has been used in many functions, in `gaugeV2`, `OnReward` is used in`deposit()`, `_withdraw()` and in `getReward()`.

However this remains informational as the functionality is used optionally:

Example:

```
    if (gaugeRewarder != address(0)) {
            IRewarder(gaugeRewarder).onReward(msg.sender, msg.sender, _balanceOf(msg.sender));
        }
```

**Impact**

gaugeRewarder will eventually be set by the protocol if required, so does not posses much impact, This is just highlighted to make the protocol aware that the contract in which OnReward() is suppose to be there is not present.

**Recommended mitigation steps**

Define a contract with the `OnReward()` functionality

### [](#nc-01-incorrect-require-statement-in-setinternalbribe)NC-01: Incorrect require statement in setInternalBribe()

In the `GaugeCl` contract, the `setInternalBribe()` function performs an incorrect validation check using `require(_int >= address(0))`, which always passes since all Ethereum addresses are greater than or equal to `address(0)`. This effectively allows setting the internal\_bribe address to the zero address.

```
 ///@notice set new internal bribe contract (where to send fees)
    function setInternalBribe(address _int) external onlyOwner {
        require(_int >= address(0), "zero");
        internal_bribe = _int;
    }
```

**Impact**

This incorrect check allows 0x0 addresses too

**Mitigation**

Change the operator sign from `>=` to `!=`

```
 ///@notice set new internal bribe contract (where to send fees)
    function setInternalBribe(address _int) external onlyOwner {
        require(_int != address(0), "zero");
        internal_bribe = _int;
    }
```

### [](#nc-02-redundant-maturity-check-in-_withdraw)NC-02: Redundant maturity check in \_withdraw()

In the `GaugeV2.sol` contract, the `_withdraw` function includes the following check:

```
require(block.timestamp >= maturityTime[msg.sender], "!MATURE");
```

This validation is redundant in the current context. It appears to be leftover from a fork of the Blackhole contract, where it was originally intended to prevent users from immediately withdrawing after calling depositGenesis. Since Hybra no longer implements the genesis functionality, this maturity check serves no purpose and can be safely removed.

**Impact**

Takes up storage and gas

**Recommended mitigation steps**

Remove the require check from `_withdraw`

# [](#mitigation-review)[Mitigation Review](#mitigation-review)

## [](#introduction)Introduction

Following the C4 audit, 3 wardens ([niffylord](https://code4rena.com/@niffylord), [rayss](https://code4rena.com/@rayss), and [ZanyBonzy](https://code4rena.com/@ZanyBonzy)) reviewed the mitigations for all sponsor-confirmed issues.

Additional details can be found within the Hybra Finance mitigation review repositories:

- [Round 1](https://github.com/code-423n4/2025-11-hybra-finance-mitigation)

- [Round 2](https://github.com/code-423n4/2025-11-hybra-finance-mitigation-round2)

## [](#mitigation-review-scope--summary)Mitigation Review Scope & Summary

During the mitigation review, the wardens determined that 2 in-scope findings from the original audit were not fully mitigated. They also surfaced several new issues (1 Medium severity and 5 Low severity); the new Medium severity issue was consequently mitigated and reviewed by the participating wardens.

The table below provides details regarding the status of each in-scope vulnerability from the original audit, followed by full details on the new Medium severity finding, and in-scope vulnerabilities that were not fully mitigated.

| Original Issue | Status | Mitigation URL |
| --- | --- | --- |
| [H-01](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-321) | 🟢 Mitigation Confirmed | [ve33: PR 4](https://github.com/hybra-finance/hybra-finance-ve33/pull/4) |
| [M-01](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-133) | 🟢 Mitigation Confirmed | [cl: PR 1](https://github.com/hybra-finance/hybra-finance-cl/pull/1) |
| [M-03](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-352) | 🟢 Mitigation Confirmed | [ve33: PR 4](https://github.com/hybra-finance/hybra-finance-ve33/pull/4) |
| [M-05](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-356) | 🟢 Mitigation Confirmed | [ve33: PR 3](https://github.com/hybra-finance/hybra-finance-ve33/pull/3) |
| [M-06](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-36) | 🟢 Mitigation Confirmed | \[[ve33: PR 3](https://github.com/hybra-finance/hybra-finance-ve33/pull/3) |
| [M-07](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-448) | 🟢 Mitigation Confirmed | [ve33: PR 5](https://github.com/hybra-finance/hybra-finance-ve33/pull/5) |
| [M-08](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-635) | 🟢 Mitigation Confirmed | [ve33: PR 6](https://github.com/hybra-finance/hybra-finance-ve33/pull/6) |
| [M-09](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-66) | 🔴 Unmitigated | [ve33: PR 1](https://github.com/hybra-finance/hybra-finance-ve33/pull/1) |
| [S-861](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-861) (Low) | 🟢 Mitigation Confirmed | [ve33: PR 2](https://github.com/hybra-finance/hybra-finance-ve33/pull/2) |
| [S-101](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-101) (Low) | 🟢 Mitigation Confirmed | [ve33: PR 4](https://github.com/hybra-finance/hybra-finance-ve33/pull/4) |
| [S-470](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-470) (Low) | 🔴 Unmitigated | [ve33: PR 6](https://github.com/hybra-finance/hybra-finance-ve33/pull/6) |

---

## [](#mitigation-of-m-09-unmitigated)[Mitigation of M-09: Unmitigated](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-38)

*Submitted by ZanyBonzy; also submitted by [niffylord](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-8)*

`GaugeManager.sol` [\#L138-L211](https://github.com/hybra-finance/hybra-finance-ve33/blob/7ba37493c901509e28643b0e60f159dea1d436e2/contracts/GaugeManager.sol#L138-L211)

CL gauge accepts unverified pools, allowing malicious pool to brick distribution

### [](#finding-description-and-impact)Finding description and impact

[M-09/S-66](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-66) is unmitigated. The provided [fix](https://github.com/hybra-finance/hybra-finance-ve33/pull/1/files) doesn’t address the core issue. Adding access control to the GaugeFactory doesn’t completely fix the issue.

There are two issues.

1. Creation with fake cl pools

2. Creation with multple pools to cause dos. None is fixed

A malicious user can still call `createGauges` in the GaugeManager which will call `createGauge` in the GaugeFactory making the fix ineffective. The same impacts will still be present.

Proof of Concept

**Status:** [Hybra Finance disputed.](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-38?commentParent=yZ3FtbxBo52)

## [](#mitigation-of-s-470-unmitigated)[Mitigation of S-470: Unmitigated](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-10)

*Submitted by niffylord; also found by [ZanyBonzy](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-36) and [rayss](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-39)*

`VotingEscrow.sol` [\#L199-L424](https://github.com/hybra-finance/hybra-finance-ve33/blob/main/contracts/VotingEscrow.sol#L982-L1006,https://github.com/hybra-finance/hybra-finance-ve33/blob/main/contracts/VotingEscrow.sol#L199-L424)

- [`contracts/VotingEscrow.sol`](https://github.com/hybra-finance/hybra-finance-ve33/blob/main/contracts/VotingEscrow.sol#L982-L1006) leaves `withdraw` unchanged, so partner veNFT holders can still exit their full balance without proving they met the bribing requirement.

- The new partner tooling ([`contracts/VotingEscrow.sol`](https://github.com/hybra-finance/hybra-finance-ve33/blob/main/contracts/VotingEscrow.sol#L199-L424)) only lets the team mint and manually revoke partner veNFTs; it does not tie withdrawal rights to bribe activity or track compliance on-chain.

- Because enforcement remains off-chain and partners can withdraw before any manual revocation, the original guarantee (“melt unless you bribe”) is still unrealised.

**Status:** Unmitigated

## [](#mr-m-01-deposit-in-governancehybr-can-be-dosed-for-users)[\[MR M-01\] Deposit in `GovernanceHYBR` can Be DOSed for users](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review/submissions/S-34)

**Severity: Medium**

`GovernanceHYBR.sol` [\#L270-L281](https://github.com/hybra-finance/hybra-finance-ve33/blob/7ba37493c901509e28643b0e60f159dea1d436e2/contracts/GovernanceHYBR.sol#L270-L281)

The issue [S-101](https://code4rena.com/audits/2025-10-hybra-finance/submissions/S-101) is now fixed by limiting the number of deposits to 50\.

The fix however introduces a new issue.

Malicious users can spend as little as 50 wei of token to dos deposits for a user for the next 24 hours or however long the `transferLockPeriod` parameter is set to (minimum of 12 hours).

`_addTransferLock` reverts if the user has 50 or more locks.

```
    function _addTransferLock(address user, uint256 amount) internal {
        uint256 len = userLocks[user].length;
        // gas optimization
        require(len < 50, "too many locks"); //<=====1
        
        uint256 unlockTime = block.timestamp + transferLockPeriod;
        userLocks[user].push(UserLock({
            amount: amount,
            unlockTime: unlockTime
        }));
        lockedBalance[user] += amount;
    }
```

So when the 51st lock is about to be created, the `require(len < 50, "too many locks");` will revert the transaction halting deposit until the first lock expires.

In a more dedicated attack, as soon as the first lock expires, the malicious user can frontrun and create a new deposit before the actual owner is able to deposit, pushing the DOS attack to the next 24 hours.

## [](#step-by-step-proof-of-concept)Step By Step Proof of Concept

1. User is about to deposit into the contract.

2. Attacker sees this and creates 50 deposits of 1 wei each on behalf of the user.

3. The user’s deposit transaction reverts with “too many locks” error.

4. The user is forced to wait for the locks to expire before being able to deposit.

5. The user may be able to withdraw after the wait but the amount to withdraw is too insigificant to be useful.

## [](#recommended-mitigation-steps-6)Recommended mitigation steps

A potential fix is to prevent users from depositing on other users’ behalf. If the fucntionality is needed, an approved user mechanism can be implemented.

Otherwise, introduce a substantial minimum deposit amount to make the attack significantly more expensive for the attacker.

### [](#recommended-mitigation-steps-7)Recommended mitigation steps

Add access control to the `_createGauge` function in the GaugeManager.

**Status: Mitigation of S-101 [confirmed](https://code4rena.com/audits/2025-11-hybra-finance-mitigation-review-round-2/submissions/S-1) after further review by wardens niffylord, rayss, and ZanyBonzy.**

---

# [](#disclosures)Disclosures

C4 audits incentivize the discovery of exploits, vulnerabilities, and bugs in smart contracts. Security researchers are rewarded at an increasing rate for finding higher-risk issues. Audit submissions are judged by a knowledgeable security researcher and disclosed to sponsoring developers. C4 does not conduct formal verification regarding the provided code but instead provides final verification.

C4 does not provide any guarantee or warranty regarding the security of this project. All smart contract software should be used at the sole risk and responsibility of users.

Top

- [Twitter](https://twitter.com/code4rena)

- [Discord](https://discord.gg/code4rena)

- [Terms](https://docs.code4rena.com/legal/terms-of-service)

- [Privacy](https://docs.code4rena.com/legal/privacy-policy)