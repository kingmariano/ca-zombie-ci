// SPDX-License-Identifier: MIT

pragma solidity 0.8.13;

interface ISphereToken {

  // *** STRUCTS ***

  struct Withdrawal {
    uint256 timestamp;
    uint256 withdrawAmount;
  }

  struct InvestorInfo {
    uint256 totalInvestableExchanged;
    Withdrawal[] withdrawHistory;
  }

  // *** EVENTS ***

  event SetPartyTime(bool indexed state, uint256 indexed time);

  event SetTaxBracketFeeMultiplier(
    uint256 indexed state,
    bool indexed _isTaxBracketEnabled,
    uint256 indexed time
  );

  event ClearStuckBalance(
    uint256 indexed amount,
    address indexed receiver,
    uint256 indexed time
  );

  event RescueToken(
    address indexed tokenAddress,
    address indexed sender,
    uint256 indexed tokens,
    uint256 time
  );

  event SetAutoRebase(bool indexed value, uint256 indexed time);

  event SetGoDeflationary(bool indexed value, uint256 indexed time);

  event SetRebaseFrequency(uint256 indexed frequency, uint256 indexed time);

  event SetRewardYield(
    uint256 indexed rewardYield,
    uint256 indexed frequency,
    uint256 indexed time,
    address setter
  );

  event SetNextRebase(uint256 indexed value, uint256 indexed time);

  event SetMaxTransactionAmount(
    uint256 indexed sell,
    uint256 indexed buy,
    uint256 indexed time
  );

  event SetWallDivisor(uint256 indexed _wallDivisor, bool indexed _isWall);

  event SetSwapBackSettings(
    bool indexed enabled,
    uint256 indexed num,
    uint256 indexed denum
  );

  event LogRebase(uint256 indexed epoch, uint256 totalSupply);
  event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
  event SetInitialDistribution(bool indexed value);
  event SetInvestRemovalDelay(uint256 indexed value);
  event SetMaxInvestRemovablePerPeriod(uint256 indexed value);
  event SetMoveBalance(bool indexed value);
  event SetIsLiquidityEnabled(bool indexed value);
  event SetPartyListDivisor(uint256 indexed value);
  event SetHourlyLimit(bool indexed value);
  event SetContractToChange(address indexed value);
  event SetTotalFeeExempt(address indexed addy, bool indexed value);
  event SetBuyFeeExempt(address indexed addy, bool indexed value);
  event SetSellFeeExempt(address indexed addy, bool indexed value);
  event SetRebaseWhitelist(
    address indexed addy,
    bool indexed value,
    uint256 indexed _type
  );
  event SetSubContracts(address indexed pair, bool indexed value);
  event SetLPContracts(address indexed pair, bool indexed value);
  event SetPartyAddresses(address indexed pair, bool indexed value);
  event SetSphereGamesAddresses(address indexed pair, bool indexed value);
  event GenericErrorEvent(string reason);
  event SetRouter(address indexed _address);
  event MoveBalance(address from, address to);

}
