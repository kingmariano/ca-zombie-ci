# Excerpt: mining/dividend math and constants
# Sources: vm/contracts/dex/fund_dividend.go 14-141, 194-207; vm/contracts/dex/fund_mine.go 15-136, 272-321;
#          vm/contracts/dex/fund_storage.go 94-135

func DoFeesDividend(db interfaces.VmDb, periodId uint64) (blocks []*ledger.AccountBlock, err error) {
	var (
		dexFeesByPeriodMap map[uint64]*DexFeesByPeriod
		vxSumFunds         *VxFunds
		ok                 bool
	)

	//allow divide history fees that not divided yet
	if dexFeesByPeriodMap = GetNotFinishDividendDexFeesByPeriodMap(db, periodId); len(dexFeesByPeriodMap) == 0 { // no fee to divide
		return
	}
	if vxSumFunds, ok = GetVxSumFundsWithForkCheck(db); !ok {
		return
	}
	foundVxSumFunds, vxSumAmtBytes, needUpdateVxSum, _ := MatchVxFundsByPeriod(vxSumFunds, periodId, false)
	//fmt.Printf("foundVxSumFunds %v, vxSumAmtBytes %s, needUpdateVxSum %v with periodId %d\n", foundVxSumFunds, new(big.Int).SetBytes(vxSumAmtBytes).String(), needUpdateVxSum, periodId)
	if !foundVxSumFunds { // not found vxSumFunds
		return
	}
	if needUpdateVxSum {
		SaveVxSumFundsWithForkCheck(db, vxSumFunds)
	}
	vxSumAmt := new(big.Int).SetBytes(vxSumAmtBytes)
	if vxSumAmt.Sign() <= 0 {
		return
	}
	// sum fees from multi period not divided
	feeSumMap := make(map[types.TokenTypeId]*big.Int)
	for pId, fee := range dexFeesByPeriodMap {
		for _, feeAccount := range fee.FeesForDividend {
			if tokenId, err := types.BytesToTokenTypeId(feeAccount.Token); err != nil {
				return nil, err
			} else {
				toDividendAmt, _ := splitDividendPool(feeAccount)
				if amt, ok := feeSumMap[tokenId]; !ok {
					feeSumMap[tokenId] = toDividendAmt
				} else {
					feeSumMap[tokenId] = amt.Add(amt, toDividendAmt)
				}
			}
		}
		MarkDexFeesFinishDividend(db, fee, pId)
	}
	blocks = tryBurnVite(db, feeSumMap)

	var (
		userVxFundKeyPrefix, userVxFundsKey, userVxFundsBytes []byte
	)
	if IsEarthFork(db) {
		userVxFundKeyPrefix = vxLockedFundsKeyPrefix
	} else {
		userVxFundKeyPrefix = vxFundKeyPrefix
	}
	iterator, err := db.NewStorageIterator(userVxFundKeyPrefix)
	if err != nil {
		panic(err)
	}
	defer iterator.Release()
	feeSumWithTokens := MapToAmountWithTokens(feeSumMap)

	feeSumLeavedMap := make(map[types.TokenTypeId]*big.Int)
	dividedVxAmtMap := make(map[types.TokenTypeId]*big.Int)
	for {
		if len(feeSumMap) == 0 {
			break
		}
		if !iterator.Next() {
			if iterator.Error() != nil {
				panic(iterator.Error())
			}
			break
		}

		userVxFundsKey = iterator.Key()
		userVxFundsBytes = iterator.Value()
		if len(userVxFundsBytes) == 0 {
			continue
		}

		addressBytes := userVxFundsKey[len(userVxFundKeyPrefix):]
		address := types.Address{}
		if err = address.SetBytes(addressBytes); err != nil {
			return
		}
		userVxFunds := &VxFunds{}
		if err = userVxFunds.DeSerialize(userVxFundsBytes); err != nil {
			return
		}

		var userFeeDividend = make(map[types.TokenTypeId]*big.Int)
		foundVxFunds, userVxAmtBytes, needUpdateVxFunds, needDeleteVxFunds := MatchVxFundsByPeriod(userVxFunds, periodId, true)
		if !foundVxFunds {
			continue
		}
		if needDeleteVxFunds {
			DeleteVxFundsWithForkCheck(db, address.Bytes())
		} else if needUpdateVxFunds {
			SaveVxFundsWithForkCheck(db, address.Bytes(), userVxFunds)
		}
		userVxAmount := new(big.Int).SetBytes(userVxAmtBytes)
		//fmt.Printf("address %s, userVxAmount %s, needDeleteVxFunds %v\n", string(address.Bytes()), userVxAmount.String(), needDeleteVxFunds)
		if !IsValidVxAmountForDividend(userVxAmount) { //skip vxAmount not valid for dividend
			continue
		}

		var finished bool
		for _, feeSumWtTk := range feeSumWithTokens {
			if feeSumWtTk.Deleted {
				continue
			}
			if _, ok = feeSumLeavedMap[feeSumWtTk.Token]; !ok {
				feeSumLeavedMap[feeSumWtTk.Token] = new(big.Int).Set(feeSumWtTk.Amount)
				dividedVxAmtMap[feeSumWtTk.Token] = big.NewInt(0)
			}
			//fmt.Printf("tokenId %s, address %s, vxSumAmt %s, userVxAmount %s, dividedVxAmt %s, toDivideFeeAmt %s, toDivideLeaveAmt %s\n", tokenId.String(), address.String(), vxSumAmt.String(), userVxAmount.String(), dividedVxAmtMap[tokenId], toDivideFeeAmt.String(), toDivideLeaveAmt.String())
			userFeeDividend[feeSumWtTk.Token], finished = DivideByProportion(vxSumAmt, userVxAmount, dividedVxAmtMap[feeSumWtTk.Token], feeSumWtTk.Amount, feeSumLeavedMap[feeSumWtTk.Token])
			if finished {
				feeSumWtTk.Deleted = true
				delete(feeSumMap, feeSumWtTk.Token)
			}
			AddFeeDividendEvent(db, address, feeSumWtTk.Token, userVxAmount, userFeeDividend[feeSumWtTk.Token])
		}
		if err = BatchUpdateFund(db, address, userFeeDividend); err != nil {
			return
		}
	}
	return
}

func DivideByProportion(totalReferAmt, partReferAmt, dividedReferAmt, toDivideTotalAmt, toDivideLeaveAmt *big.Int) (proportionAmt *big.Int, finished bool) {
	dividedReferAmt.Add(dividedReferAmt, partReferAmt)
	proportion := new(big.Float).SetPrec(bigFloatPrec).Quo(new(big.Float).SetPrec(bigFloatPrec).SetInt(partReferAmt), new(big.Float).SetPrec(bigFloatPrec).SetInt(totalReferAmt))
	proportionAmt = RoundAmount(new(big.Float).SetPrec(bigFloatPrec).Mul(new(big.Float).SetPrec(bigFloatPrec).SetInt(toDivideTotalAmt), proportion))
	toDivideLeaveNewAmt := new(big.Int).Sub(toDivideLeaveAmt, proportionAmt)
	if toDivideLeaveNewAmt.Sign() <= 0 || dividedReferAmt.Cmp(totalReferAmt) >= 0 {
		proportionAmt.Set(toDivideLeaveAmt)
		finished = true
		toDivideLeaveAmt.SetInt64(0)
	} else {
		toDivideLeaveAmt.Set(toDivideLeaveNewAmt)
	}
	return proportionAmt, finished
}

func DoMineVxForFee(db interfaces.VmDb, reader util.ConsensusReader, periodId uint64, amtForMarkets map[int32]*big.Int, fundLogger log15.Logger) (*big.Int, error) {
	var (
		dexFeesByPeriod       *DexFeesByPeriod
		feeSumMap             = make(map[int32]*big.Int) // quoteTokenType -> amount
		dividedFeeMap         = make(map[int32]*big.Int)
		toDivideVxLeaveAmtMap = make(map[int32]*big.Int)
		mineThresholdMap      = make(map[int32]*big.Int)
		err                   error
		ok                    bool
	)
	if len(amtForMarkets) == 0 {
		return nil, nil
	}
	if dexFeesByPeriod, ok = GetDexFeesByPeriodId(db, periodId); !ok {
		return AccumulateAmountFromMap(amtForMarkets), nil
	}
	for _, feeForMine := range dexFeesByPeriod.FeesForMine {
		feeSumMap[feeForMine.QuoteTokenType] = new(big.Int).SetBytes(AddBigInt(feeForMine.BaseAmount, feeForMine.InviteBonusAmount))
		dividedFeeMap[feeForMine.QuoteTokenType] = big.NewInt(0)
	}
	for i := ViteTokenType; i <= UsdTokenType; i++ {
		mineThresholdMap[int32(i)] = GetMineThreshold(db, int32(i))
		toDivideVxLeaveAmtMap[int32(i)] = new(big.Int).Set(amtForMarkets[int32(i)])
	}

	MarkDexFeesFinishMine(db, dexFeesByPeriod, periodId)
	var (
		userFeesKey, userFeesBytes []byte
	)

	iterator, err := db.NewStorageIterator(userFeeKeyPrefix)
	if err != nil {
		panic(err)
	}
	defer iterator.Release()
	for {
		if !iterator.Next() {
			if iterator.Error() != nil {
				panic(iterator.Error())
			}
			break
		}
		userFeesKey = iterator.Key()
		userFeesBytes = iterator.Value()
		if len(userFeesBytes) == 0 {
			continue
		}

		addressBytes := userFeesKey[len(userFeeKeyPrefix):]
		address := types.Address{}
		if err = address.SetBytes(addressBytes); err != nil {
			panic(err)
		}
		userFees := &UserFees{}
		if err = userFees.DeSerialize(userFeesBytes); err != nil {
			panic(err)
		}

		truncated := TruncateUserFeesToPeriod(userFees, periodId)
		if truncated {
			if len(userFees.Fees) == 0 {
				DeleteUserFees(db, addressBytes)
				continue
			} else if userFees.Fees[0].Period != periodId {
				SaveUserFees(db, addressBytes, userFees)
				continue
			}
		}
		if userFees.Fees[0].Period != periodId {
			continue
		}
		if len(userFees.Fees[0].Fees) > 0 {
			var vxMinedForBase = big.NewInt(0)
			var vxMinedForInvite = big.NewInt(0)
			for _, feeAccount := range userFees.Fees[0].Fees {
				if !IsValidFeeForMine(feeAccount, mineThresholdMap[feeAccount.QuoteTokenType]) {
					continue
				}
				if feeSumAmt, ok := feeSumMap[feeAccount.QuoteTokenType]; !ok { //no counter part in feeSum for userFees
					// TODO change to continue after test
					fundLogger.Error("DoMineVxForFee", "encounter err", "user with valid feeAccount, but no valid feeSum",
						"periodId", periodId, "address", address.String(), "quoteTokenType", feeAccount.QuoteTokenType,
						"baseFee", new(big.Int).SetBytes(feeAccount.BaseAmount), "inviteFee", new(big.Int).SetBytes(feeAccount.InviteBonusAmount))
					continue
				} else {
					var vxDividend, vxDividendForInvite *big.Int
					var finished, finishedForInvite bool
					if len(feeAccount.BaseAmount) > 0 {
						vxDividend, finished = DivideByProportion(feeSumAmt, new(big.Int).SetBytes(feeAccount.BaseAmount), dividedFeeMap[feeAccount.QuoteTokenType], amtForMarkets[feeAccount.QuoteTokenType], toDivideVxLeaveAmtMap[feeAccount.QuoteTokenType])
						vxMinedForBase.Add(vxMinedForBase, vxDividend)
						AddMinedVxForTradeFeeEvent(db, address, feeAccount.QuoteTokenType, feeAccount.BaseAmount, vxDividend)
					}
					if finished {
						delete(feeSumMap, feeAccount.QuoteTokenType)
					} else {
						if len(feeAccount.InviteBonusAmount) > 0 {
							vxDividendForInvite, finishedForInvite = DivideByProportion(feeSumAmt, new(big.Int).SetBytes(feeAccount.InviteBonusAmount), dividedFeeMap[feeAccount.QuoteTokenType], amtForMarkets[feeAccount.QuoteTokenType], toDivideVxLeaveAmtMap[feeAccount.QuoteTokenType])
							vxMinedForInvite.Add(vxMinedForInvite, vxDividendForInvite)
							AddMinedVxForInviteeFeeEvent(db, address, feeAccount.QuoteTokenType, feeAccount.InviteBonusAmount, vxDividendForInvite)
							if finishedForInvite {
								delete(feeSumMap, feeAccount.QuoteTokenType)
							}
						}
					}
				}
			}
			minedAmt := new(big.Int).Add(vxMinedForBase, vxMinedForInvite)
			if minedAmt.Sign() > 0 {
				if err = OnVxMined(db, reader, address, minedAmt); err != nil {
					return nil, err
				}
			}
		}
		if len(userFees.Fees) == 1 {
			DeleteUserFees(db, addressBytes)
		} else {
			userFees.Fees = userFees.Fees[1:]
			SaveUserFees(db, addressBytes, userFees)
		}
	}
	return AccumulateAmountFromMap(toDivideVxLeaveAmtMap), nil
}

func GetVxAmountsForEqualItems(db interfaces.VmDb, periodId uint64, vxPool *big.Int, mr mineRate) (amountForItems map[int32]*big.Int, vxAmtLeaved *big.Int, success bool) {
	if vxPool.Sign() > 0 {
		success = true
		toDivideTotal := GetVxToMineByPeriodId(db, periodId)
		toDivideTotalF := new(big.Float).SetPrec(bigFloatPrec).SetInt(toDivideTotal)
		proportion, _ := new(big.Float).SetPrec(bigFloatPrec).SetString(mr.totalRate)
		amountSum := RoundAmount(new(big.Float).SetPrec(bigFloatPrec).Mul(toDivideTotalF, proportion))
		var notEnough bool
		if amountSum.Cmp(vxPool) > 0 {
			amountSum.Set(vxPool)
			notEnough = true
		}
		amount := new(big.Int).Div(amountSum, big.NewInt(int64(mr.total)))
		amountForItems = make(map[int32]*big.Int)
		vxAmtLeaved = new(big.Int).Set(vxPool)
		for _, field := range mr.fields {
			targetAmount := big.NewInt(0).Mul(amount, big.NewInt(int64(field.rate)))
			if vxAmtLeaved.Cmp(targetAmount) >= 0 {
				amountForItems[field.field] = new(big.Int).Set(targetAmount)
			} else {
				amountForItems[field.field] = new(big.Int).Set(vxAmtLeaved)
			}
			vxAmtLeaved.Sub(vxAmtLeaved, amountForItems[field.field])
		}
		if notEnough || vxAmtLeaved.Cmp(vxMineDust) <= 0 {
			amountForItems[mr.fields[0].field].Add(amountForItems[mr.fields[0].field], vxAmtLeaved)
			vxAmtLeaved.SetInt64(0)
		}
	}
	return
}

func GetVxAmountToMine(db interfaces.VmDb, periodId uint64, vxPool *big.Int, rate string) (amount, vxAmtLeaved *big.Int, success bool) {
	if vxPool.Sign() > 0 {
		success = true
		toDivideTotal := GetVxToMineByPeriodId(db, periodId)
		toDivideTotalF := new(big.Float).SetPrec(bigFloatPrec).SetInt(toDivideTotal)
		proportion, _ := new(big.Float).SetPrec(bigFloatPrec).SetString(rate)
		amount = RoundAmount(new(big.Float).SetPrec(bigFloatPrec).Mul(toDivideTotalF, proportion))
		if amount.Cmp(vxPool) > 0 {
			amount.Set(vxPool)
		}
		vxAmtLeaved = new(big.Int).Sub(vxPool, amount)
		if vxAmtLeaved.Sign() > 0 && vxAmtLeaved.Cmp(vxMineDust) <= 0 {
			amount.Add(amount, vxAmtLeaved)
			vxAmtLeaved.SetInt64(0)
		}
	}
	return
}

	VxTokenId, _             = types.HexToTokenTypeId("tti_564954455820434f494e69b5")
	PreheatMinedAmtPerPeriod = new(big.Int).Mul(commonTokenPow, big.NewInt(10000))
	VxMinedAmtFirstPeriod    = new(big.Int).Mul(new(big.Int).Exp(helper.Big10, new(big.Int).SetUint64(uint64(13)), nil), big.NewInt(47703236213)) // 477032.36213

	VxDividendThreshold      = new(big.Int).Mul(commonTokenPow, big.NewInt(10))
	NewMarketFeeAmount       = new(big.Int).Mul(commonTokenPow, big.NewInt(10000))
	NewMarketFeeMineAmount   = new(big.Int).Mul(commonTokenPow, big.NewInt(1000))
	NewMarketFeeDonateAmount = new(big.Int).Mul(commonTokenPow, big.NewInt(4000))
	NewMarketFeeBurnAmount   = new(big.Int).Mul(commonTokenPow, big.NewInt(5000))
	NewInviterFeeAmount      = new(big.Int).Mul(commonTokenPow, big.NewInt(1000))
	// 1000 -> 100 in version 10
	NewInviterFeeAmountForVersion10 = new(big.Int).Mul(commonTokenPow, big.NewInt(100))

	VxLockThreshold = new(big.Int).Set(commonTokenPow)
	SchedulePeriods = 7 // T+7 schedule

	StakeForMiningMinAmount = new(big.Int).Mul(commonTokenPow, big.NewInt(134))
	StakeForVIPAmount       = new(big.Int).Mul(commonTokenPow, big.NewInt(10000))
	StakeForMiningThreshold = new(big.Int).Mul(commonTokenPow, big.NewInt(134))
	StakeForSuperVIPAmount  = new(big.Int).Mul(commonTokenPow, big.NewInt(1000000))

	viteMinAmount    = new(big.Int).Mul(commonTokenPow, big.NewInt(100)) // 100 VITE
	ethMinAmount     = new(big.Int).Div(commonTokenPow, big.NewInt(100)) // 0.01 ETH
	bitcoinMinAmount = big.NewInt(50000)                                 // 0.0005 BTC
	usdMinAmount     = big.NewInt(1000000)                               // 1 USD

	viteMineThreshold    = new(big.Int).Mul(commonTokenPow, big.NewInt(2))    // 2 VITE
	ethMineThreshold     = new(big.Int).Div(commonTokenPow, big.NewInt(5000)) // 0.0002 ETH
	bitcoinMineThreshold = big.NewInt(1000)                                   // 0.00001 BTC
	usdMineThreshold     = big.NewInt(20000)                                  // 0.02USD

	viteMarketOrderAmtThreshold    = new(big.Int).Mul(commonTokenPow, big.NewInt(8e6)) // 8,000,000 VITE
	ethMarketOrderAmtThreshold     = new(big.Int).Mul(commonTokenPow, big.NewInt(200)) // 200 ETH
	bitcoinMarketOrderAmtThreshold = big.NewInt(10e8)                                  // 10 BTC
	usdMarketOrderAmtThreshold     = big.NewInt(100000e6)                              // 100,000 USD

	// RateSumForFeeMine                = "0.6" // 15% * 4
	RateForStakingMine = "0.2" // 20%
	RateForStakingMineVersion12 = "0.1" // 10%
	// RateSumForMakerAndMaintainerMine = "0.2" // 10% + 10%

	rateSumForFeeMineArr = mineRate{
