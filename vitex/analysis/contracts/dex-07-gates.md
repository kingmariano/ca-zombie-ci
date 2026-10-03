# Excerpt: admin/privileged gates
# Sources: vm/contracts/dex/fund_storage.go 1745-1751, 1833-1839, 1882-1933;
#          vm/contracts/contracts_dex_fund.go 1096-1124, 1250-1291; vm/contracts/contracts_dex_trade.go 308-337

func IsOwner(db interfaces.VmDb, address types.Address) bool {
	if storeOwner := getValueFromDb(db, ownerKey); len(storeOwner) == types.AddressSize {
		return bytes.Equal(storeOwner, address.Bytes())
	} else {
		return address == initOwner
	}
}

func IsMakerMiningAdmin(db interfaces.VmDb, addr types.Address) bool {
	if mmpBytes := getValueFromDb(db, makerMiningAdminKey); len(mmpBytes) == types.AddressSize {
		return bytes.Equal(addr.Bytes(), mmpBytes)
	} else {
		return false
	}
}

func IsDexStopped(db interfaces.VmDb) bool {
	stopped := getValueFromDb(db, dexStoppedKey)
	return len(stopped) > 0
}

func SaveDexStopped(db interfaces.VmDb, isStopDex bool) {
	if isStopDex {
		setValueToDb(db, dexStoppedKey, []byte{1})
	} else {
		setValueToDb(db, dexStoppedKey, nil)
	}
}

func ValidTimeOracle(db interfaces.VmDb, address types.Address) bool {
	if timeOracleBytes := getValueFromDb(db, timeOracleKey); len(timeOracleBytes) == types.AddressSize {
		return bytes.Equal(timeOracleBytes, address.Bytes())
	}
	return false
}

func GetTimeOracle(db interfaces.VmDb) *types.Address {
	if timeOracleBytes := getValueFromDb(db, timeOracleKey); len(timeOracleBytes) == types.AddressSize {
		address, _ := types.BytesToAddress(timeOracleBytes)
		return &address
	} else {
		return nil
	}
}

func SetTimeOracle(db interfaces.VmDb, address types.Address) {
	setValueToDb(db, timeOracleKey, address.Bytes())
}

func ValidTriggerAddress(db interfaces.VmDb, address types.Address) bool {
	if triggerAddressBytes := getValueFromDb(db, periodJobTriggerKey); len(triggerAddressBytes) == types.AddressSize {
		return bytes.Equal(triggerAddressBytes, address.Bytes())
	}
	return false
}

func GetPeriodJobTrigger(db interfaces.VmDb) *types.Address {
	if triggerAddressBytes := getValueFromDb(db, periodJobTriggerKey); len(triggerAddressBytes) == types.AddressSize {
		address, _ := types.BytesToAddress(triggerAddressBytes)
		return &address
	} else {
		return nil
	}
}

func SetPeriodJobTrigger(db interfaces.VmDb, address types.Address) {
	setValueToDb(db, periodJobTriggerKey, address.Bytes())
}

func (md MethodDexFundDexAdminConfig) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	var err error
	var param = new(dex.ParamDexAdminConfig)
	if err = cabi.ABIDexFund.UnpackMethod(param, md.MethodName, sendBlock.Data); err != nil {
		return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
	}
	if dex.IsOwner(db, sendBlock.AccountAddress) {
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigOwner) {
			dex.SetOwner(db, param.Owner)
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigTimeOracle) {
			dex.SetTimeOracle(db, param.TimeOracle)
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigPeriodJobTrigger) {
			dex.SetPeriodJobTrigger(db, param.PeriodJobTrigger)
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigStopDex) {
			dex.SaveDexStopped(db, param.StopDex)
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigMakerMiningAdmin) {
			dex.SaveMakerMiningAdmin(db, param.MakerMiningAdmin)
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.AdminConfigMaintainer) {
			dex.SaveMaintainer(db, param.Maintainer)
		}
	} else {
		return handleDexReceiveErr(fundLogger, md.MethodName, dex.OnlyOwnerAllowErr, sendBlock)
	}
	return nil, nil

func (md MethodDexFundMarketAdminConfig) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	var (
		err        error
		marketInfo *dex.MarketInfo
		ok         bool
	)
	var param = new(dex.ParamMarketAdminConfig)
	if err = cabi.ABIDexFund.UnpackMethod(param, md.MethodName, sendBlock.Data); err != nil {
		return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
	}
	if marketInfo, ok = dex.GetMarketInfo(db, param.TradeToken, param.QuoteToken); !ok || !marketInfo.Valid {
		return handleDexReceiveErr(fundLogger, md.MethodName, dex.TradeMarketNotExistsErr, sendBlock)
	}
	if bytes.Equal(sendBlock.AccountAddress.Bytes(), marketInfo.Owner) {
		if param.OperationCode == 0 {
			return nil, nil
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.MarketOwnerTransferOwner) {
			marketInfo.Owner = param.MarketOwner.Bytes()
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.MarketOwnerConfigTakerRate) {
			if !dex.ValidOperatorFeeRate(param.TakerFeeRate) {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidOperatorFeeRateErr, sendBlock)
			}
			marketInfo.TakerOperatorFeeRate = param.TakerFeeRate
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.MarketOwnerConfigMakerRate) {
			if !dex.ValidOperatorFeeRate(param.MakerFeeRate) {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidOperatorFeeRateErr, sendBlock)
			}
			marketInfo.MakerOperatorFeeRate = param.MakerFeeRate
		}
		if dex.IsOperationValidWithMask(param.OperationCode, dex.MarketOwnerStopMarket) {
			marketInfo.Stopped = param.StopMarket
		}
		dex.SaveMarketInfo(db, marketInfo, param.TradeToken, param.QuoteToken)
		dex.AddMarketEvent(db, marketInfo)
	} else {
		return handleDexReceiveErr(fundLogger, md.MethodName, dex.OnlyOwnerAllowErr, sendBlock)
	}
	return nil, nil
}

func handleCancelOrderById(db interfaces.VmDb, orderId []byte, operator types.Address, method string, block, sendBlock *ledger.AccountBlock) ([]*ledger.AccountBlock, error) {
	var (
		order        *dex.Order
		marketId     int32
		matcher      *dex.Matcher
		appendBlocks []*ledger.AccountBlock
		err          error
	)
	if marketId, _, _, _, err = dex.DeComposeOrderId(orderId); err != nil {
		return handleDexReceiveErr(tradeLogger, method, dex.InvalidOrderIdErr, sendBlock)
	}
	if matcher, err = dex.NewMatcher(db, marketId); err != nil {
		return handleDexReceiveErr(tradeLogger, method, err, sendBlock)
	}
	if order, err = matcher.GetOrderById(orderId); err != nil {
		return handleDexReceiveErr(tradeLogger, method, err, sendBlock)
	}
	if !bytes.Equal(operator.Bytes(), order.Address) && !bytes.Equal(operator.Bytes(), order.Agent) {
		return handleDexReceiveErr(tradeLogger, method, dex.CancelOrderOwnerInvalidErr, sendBlock)
	}
	if order.Status != dex.Pending && order.Status != dex.PartialExecuted {
		return handleDexReceiveErr(tradeLogger, method, dex.CancelOrderInvalidStatusErr, sendBlock)
	}
	matcher.CancelOrderById(order)
	if appendBlocks, err = handleSettleActions(db, block, matcher.GetFundSettles(), nil, matcher.MarketInfo); err != nil {
		return handleDexReceiveErr(tradeLogger, method, err, sendBlock)
	} else {
		return appendBlocks, nil
	}
}
