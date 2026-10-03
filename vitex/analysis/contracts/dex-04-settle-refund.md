# Excerpt: settlement, refund and fee-cap math; Withdraw ignoring attached send amount
# Sources: vm/contracts/dex/fund_settle.go 16-75; vm/contracts/dex/matcher.go 255-274, 312-347, 597-635;
#          vm/contracts/contracts_dex_fund.go 95-126; vm/vm.go 521-575 (receive+refund)

func DoSettleFund(db interfaces.VmDb, reader util.ConsensusReader, action *dexproto.FundSettle, marketInfo *MarketInfo, fundLogger log15.Logger) error {
	address := types.Address{}
	address.SetBytes([]byte(action.Address))
	dexFund, _ := GetFund(db, address)
	for _, accountSettle := range action.AccountSettles {
		var token []byte
		if accountSettle.IsTradeToken {
			token = marketInfo.TradeToken
		} else {
			token = marketInfo.QuoteToken
		}
		if tokenId, err := types.BytesToTokenTypeId(token); err != nil {
			return err
		} else {
			if _, ok := GetTokenInfo(db, tokenId); !ok {
				panic(InvalidTokenErr)
			}
			account, exists := GetAccountByToken(dexFund, tokenId)
			var (
				exceed    bool
				actualSub []byte
			)
			//fmt.Printf("origin account for :address %s, tokenId %s, available %s, locked %s\n", address.String(), tokenId.String(), new(big.Int).SetBytes(account.Available).String(), new(big.Int).SetBytes(account.Locked).String())
			if CmpToBigZero(accountSettle.ReduceLocked) != 0 {
				if account.Locked, _, exceed = SafeSubBigInt(account.Locked, accountSettle.ReduceLocked); exceed {
					if IsDexFeeFork(db) {
						fundLogger.Error(cabi.MethodNameDexFundSettleOrdersV2+" DoSettleFund exceed for reduceLocked", "locked", new(big.Int).SetBytes(account.Locked).String(), "reduceLocked", new(big.Int).SetBytes(accountSettle.ReduceLocked).String())
					} else {
						panic(ExceedFundLockedErr)
					}
				}
			}
			if CmpToBigZero(accountSettle.ReleaseLocked) != 0 {
				if account.Locked, actualSub, exceed = SafeSubBigInt(account.Locked, accountSettle.ReleaseLocked); exceed {
					if IsDexFeeFork(db) {
						fundLogger.Error(cabi.MethodNameDexFundSettleOrdersV2+" DoSettleFund exceed for releaseLocked", "locked", new(big.Int).SetBytes(account.Locked).String(), "releaseLocked", new(big.Int).SetBytes(accountSettle.ReleaseLocked).String())
					} else {
						panic(ExceedFundLockedErr)
					}
				}
				account.Available = AddBigInt(account.Available, actualSub)
			}
			if CmpToBigZero(accountSettle.IncAvailable) != 0 {
				account.Available = AddBigInt(account.Available, accountSettle.IncAvailable)
			}
			if !exists {
				dexFund.Accounts = append(dexFund.Accounts, account)
			}
			// must do after account updated by settle
			if bytes.Equal(token, VxTokenId.Bytes()) {
				if err = OnSettleVx(db, reader, action.Address, accountSettle, account); err != nil {
					return err
				}
			}
			//fmt.Printf("settle for :address %s, tokenId %s, ReduceLocked %s, ReleaseLocked %s, IncAvailable %s\n", address.String(), tokenId.String(), new(big.Int).SetBytes(action.ReduceLocked).String(), new(big.Int).SetBytes(action.ReleaseLocked).String(), new(big.Int).SetBytes(action.IncAvailable).String())
		}
	}
	SaveFund(db, address, dexFund)
	return nil
}

func (mc *Matcher) handleRefund(order *Order) {
	if order.Status == FullyExecuted || order.Status == Cancelled {
		switch order.Side {
		case false: //buy
			order.RefundToken = mc.MarketInfo.QuoteToken
			refundAmount := SubBigIntAbs(order.Amount, order.ExecutedAmount)
			refundFee := SubBigIntAbs(SubBigIntAbs(order.LockedBuyFee, order.ExecutedBaseFee), order.ExecutedOperatorFee)
			order.RefundQuantity = AddBigInt(refundAmount, refundFee)
		case true:
			order.RefundToken = mc.MarketInfo.TradeToken
			order.RefundQuantity = SubBigIntAbs(order.Quantity, order.ExecutedQuantity)
		}
		if CmpToBigZero(order.RefundQuantity) > 0 {
			mc.updateFundSettle(order.Address, proto.AccountSettle{IsTradeToken: order.Side, ReleaseLocked: order.RefundQuantity})
		} else {
			order.RefundToken = nil
			order.RefundQuantity = nil
		}
	}
}

func (mc *Matcher) handleTxFundSettle(tx OrderTx) {
	takerInSettle := proto.AccountSettle{}
	takerOutSettle := proto.AccountSettle{}
	makerInSettle := proto.AccountSettle{}
	makerOutSettle := proto.AccountSettle{}
	switch tx.TakerSide {
	case false: //buy
		takerInSettle.IsTradeToken = true
		takerInSettle.IncAvailable = tx.Quantity
		makerOutSettle.IsTradeToken = true
		makerOutSettle.ReduceLocked = tx.Quantity

		takerOutSettle.IsTradeToken = false
		takerOutSettle.ReduceLocked = AddBigInt(tx.Amount, AddBigInt(tx.TakerFee, tx.TakerOperatorFee))
		makerInSettle.IsTradeToken = false
		makerInSettle.IncAvailable = SubBigIntAbs(tx.Amount, AddBigInt(tx.MakerFee, tx.MakerOperatorFee))

	case true: //sell
		takerInSettle.IsTradeToken = false
		takerInSettle.IncAvailable = SubBigIntAbs(tx.Amount, AddBigInt(tx.TakerFee, tx.TakerOperatorFee))
		makerOutSettle.IsTradeToken = false
		makerOutSettle.ReduceLocked = AddBigInt(tx.Amount, AddBigInt(tx.MakerFee, tx.MakerOperatorFee))

		takerOutSettle.IsTradeToken = true
		takerOutSettle.ReduceLocked = tx.Quantity
		makerInSettle.IsTradeToken = true
		makerInSettle.IncAvailable = tx.Quantity
	}
	mc.updateFundSettle(tx.takerAddress, takerInSettle)
	mc.updateFundSettle(tx.takerAddress, takerOutSettle)
	mc.updateFundSettle(tx.makerAddress, makerInSettle)
	mc.updateFundSettle(tx.makerAddress, makerOutSettle)

	mc.updateFee(tx.takerAddress, tx.TakerFee, tx.TakerOperatorFee)
	mc.updateFee(tx.makerAddress, tx.MakerFee, tx.MakerOperatorFee)
}

func CalculateFeeAndExecutedFee(order *Order, amount []byte, feeRate, operatorFeeRate int32, heightPoint upgrade.HeightPoint) (incBaseFee, executedBaseFee, incOperatorFee, executedOperatorFee []byte) {
	var leaved bool
	if incBaseFee, executedBaseFee, leaved = calculateExecutedFee(amount, feeRate, order.Side, order.ExecutedBaseFee, order.LockedBuyFee, order.ExecutedBaseFee, order.ExecutedOperatorFee); leaved {
		incOperatorFee, executedOperatorFee, _ = calculateExecutedFee(amount, operatorFeeRate, order.Side, order.ExecutedOperatorFee, order.LockedBuyFee, executedBaseFee, order.ExecutedOperatorFee)
	} else if heightPoint.IsDexFeeUpgrade() {
		executedOperatorFee = order.ExecutedOperatorFee
	}
	return
}

func calculateExecutedFee(amount []byte, feeRate int32, side bool, originExecutedFee, totalLockedAmount []byte, usedAmounts ...[]byte) (incFee, newExecutedFee []byte, leaved bool) {
	if feeRate == 0 {
		return nil, originExecutedFee, true
	}
	incFee = CalculateAmountForRate(amount, feeRate)
	switch side {
	case false:
		var totalUsedAmount []byte
		for _, usedAmt := range usedAmounts {
			totalUsedAmount = AddBigInt(totalUsedAmount, usedAmt)
		}
		if CmpForBigInt(totalLockedAmount, totalUsedAmount) <= 0 {
			incFee = nil
			newExecutedFee = originExecutedFee
		} else {
			totalUsedAmountNew := AddBigInt(totalUsedAmount, incFee)
			if CmpForBigInt(totalLockedAmount, totalUsedAmountNew) <= 0 {
				incFee = SubBigIntAbs(totalLockedAmount, totalUsedAmount)
			} else {
				leaved = true
			}
			newExecutedFee = AddBigInt(originExecutedFee, incFee)
		}
	case true:
		newExecutedFee = AddBigInt(originExecutedFee, incFee)
		leaved = true
	}
	return
}

func (md *MethodDexFundWithdraw) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	param := new(dex.ParamWithdraw)
	var (
		acc *dexproto.Account
		err error
	)
	if err = cabi.ABIDexFund.UnpackMethod(param, md.MethodName, sendBlock.Data); err != nil {
		return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
	}
	if acc, err = dex.ReduceAccount(db, sendBlock.AccountAddress, param.Token.Bytes(), param.Amount); err != nil {
		return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
	} else {
		if param.Token == dex.VxTokenId {
			if err = dex.OnWithdrawVx(db, vm.ConsensusReader(), sendBlock.AccountAddress, param.Amount, acc); err != nil {
				return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
			}
		}
	}
	if dex.IsVersion11AddTransferAssetEvent(db) {
		dex.AddTransferAssetEvent(db, dex.TransferAssetWithdraw, types.AddressDexFund, sendBlock.AccountAddress, param.Token, param.Amount, nil)
	}
	return []*ledger.AccountBlock{
		{
			AccountAddress: types.AddressDexFund,
			ToAddress:      sendBlock.AccountAddress,
			BlockType:      ledger.BlockTypeSendCall,
			Amount:         param.Amount,
			TokenId:        param.Token,
			Data:           []byte{},
		},
	}, nil
}
