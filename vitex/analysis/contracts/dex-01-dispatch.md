# Excerpt: built-in contract dispatch table + fork selection (go-vite 429c2442 = v2.14.0, final master)
# Source: vm/contracts/contracts.go lines 101-150 (dex + agent), 201-250 (earth->cross), 252-285 (selector)

func newDexContracts() map[types.Address]*builtinContract {
	contracts := newSimpleContracts()
	contracts[types.AddressQuota].m[cabi.MethodNameDelegateStake] = &MethodDelegateStake{cabi.MethodNameDelegateStake}
	contracts[types.AddressQuota].m[cabi.MethodNameCancelDelegateStake] = &MethodCancelDelegateStake{cabi.MethodNameCancelDelegateStake}
	contracts[types.AddressAsset].m[cabi.MethodNameGetTokenInfo] = &MethodGetTokenInfo{cabi.MethodNameGetTokenInfo}
	contracts[types.AddressDexFund] = &builtinContract{
		map[string]BuiltinContractMethod{
			cabi.MethodNameDexFundUserDeposit:          &MethodDexFundDeposit{cabi.MethodNameDexFundUserDeposit},
			cabi.MethodNameDexFundUserWithdraw:         &MethodDexFundWithdraw{cabi.MethodNameDexFundUserWithdraw},
			cabi.MethodNameDexFundNewMarket:            &MethodDexFundOpenNewMarket{cabi.MethodNameDexFundNewMarket},
			cabi.MethodNameDexFundNewOrder:             &MethodDexFundPlaceOrder{cabi.MethodNameDexFundNewOrder},
			cabi.MethodNameDexFundSettleOrders:         &MethodDexFundSettleOrders{cabi.MethodNameDexFundSettleOrders},
			cabi.MethodNameDexFundPeriodJob:            &MethodDexFundTriggerPeriodJob{cabi.MethodNameDexFundPeriodJob},
			cabi.MethodNameDexFundPledgeForVx:          &MethodDexFundStakeForMining{cabi.MethodNameDexFundPledgeForVx},
			cabi.MethodNameDexFundPledgeForVip:         &MethodDexFundStakeForVIP{cabi.MethodNameDexFundPledgeForVip},
			cabi.MethodNameDexFundPledgeCallback:       &MethodDexFundDelegateStakeCallback{cabi.MethodNameDexFundPledgeCallback},
			cabi.MethodNameDexFundCancelPledgeCallback: &MethodDexFundCancelDelegateStakeCallback{cabi.MethodNameDexFundCancelPledgeCallback},
			cabi.MethodNameDexFundGetTokenInfoCallback: &MethodDexFundGetTokenInfoCallback{cabi.MethodNameDexFundGetTokenInfoCallback},
			cabi.MethodNameDexFundOwnerConfig:          &MethodDexFundDexAdminConfig{cabi.MethodNameDexFundOwnerConfig},
			cabi.MethodNameDexFundOwnerConfigTrade:     &MethodDexFundTradeAdminConfig{cabi.MethodNameDexFundOwnerConfigTrade},
			cabi.MethodNameDexFundMarketOwnerConfig:    &MethodDexFundMarketAdminConfig{cabi.MethodNameDexFundMarketOwnerConfig},
			cabi.MethodNameDexFundTransferTokenOwner:   &MethodDexFundTransferTokenOwnership{cabi.MethodNameDexFundTransferTokenOwner},
			cabi.MethodNameDexFundNotifyTime:           &MethodDexFundNotifyTime{cabi.MethodNameDexFundNotifyTime},
			cabi.MethodNameDexFundNewInviter:           &MethodDexFundCreateNewInviter{cabi.MethodNameDexFundNewInviter},
			cabi.MethodNameDexFundBindInviteCode:       &MethodDexFundBindInviteCode{cabi.MethodNameDexFundBindInviteCode},
			cabi.MethodNameDexFundEndorseVxMinePool:    &MethodDexFundEndorseVx{cabi.MethodNameDexFundEndorseVxMinePool},
			cabi.MethodNameDexFundSettleMakerMinedVx:   &MethodDexFundSettleMakerMinedVx{cabi.MethodNameDexFundSettleMakerMinedVx},
		},
		cabi.ABIDexFund,
	}
	contracts[types.AddressDexTrade] = &builtinContract{
		map[string]BuiltinContractMethod{
			cabi.MethodNameDexTradeNewOrder:          &MethodDexTradePlaceOrder{cabi.MethodNameDexTradeNewOrder},
			cabi.MethodNameDexTradeCancelOrder:       &MethodDexTradeCancelOrder{cabi.MethodNameDexTradeCancelOrder},
			cabi.MethodNameDexTradeNotifyNewMarket:   &MethodDexTradeSyncNewMarket{cabi.MethodNameDexTradeNotifyNewMarket},
			cabi.MethodNameDexTradeCleanExpireOrders: &MethodDexTradeClearExpiredOrders{cabi.MethodNameDexTradeCleanExpireOrders},
		},
		cabi.ABIDexTrade,
	}
	return contracts
}

func newDexAgentContracts() map[types.Address]*builtinContract {
	contracts := newDexContracts()
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundStakeForSuperVip] = &MethodDexFundStakeForSVIP{cabi.MethodNameDexFundStakeForSuperVip}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundConfigMarketsAgent] = &MethodDexFundConfigMarketAgents{cabi.MethodNameDexFundConfigMarketsAgent}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundNewAgentOrder] = &MethodDexFundPlaceAgentOrder{cabi.MethodNameDexFundNewAgentOrder}
	contracts[types.AddressDexTrade].m[cabi.MethodNameDexTradeCancelOrderByHash] = &MethodDexTradeCancelOrderByTransactionHash{cabi.MethodNameDexTradeCancelOrderByHash}
	return contracts
}

func newEarthContracts() map[types.Address]*builtinContract {
	contracts := newLeafContracts()
	contracts[types.AddressAsset].m[cabi.MethodNameGetTokenInfoV3] = &MethodGetTokenInfo{cabi.MethodNameGetTokenInfoV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameRegisterV3] = &MethodRegister{cabi.MethodNameRegisterV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameUpdateBlockProducintAddressV3] = &MethodUpdateBlockProducingAddress{cabi.MethodNameUpdateBlockProducintAddressV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameUpdateSBPRewardWithdrawAddress] = &MethodUpdateRewardWithdrawAddress{cabi.MethodNameUpdateSBPRewardWithdrawAddress}
	contracts[types.AddressGovernance].m[cabi.MethodNameRevokeV3] = &MethodRevoke{cabi.MethodNameRevokeV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameWithdrawRewardV3] = &MethodWithdrawReward{cabi.MethodNameWithdrawRewardV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameVoteV3] = &MethodVote{cabi.MethodNameVoteV3}
	contracts[types.AddressGovernance].m[cabi.MethodNameCancelVoteV3] = &MethodCancelVote{cabi.MethodNameCancelVoteV3}

	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundLockVxForDividend] = &MethodDexFundLockVxForDividend{cabi.MethodNameDexFundLockVxForDividend}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundSwitchConfig] = &MethodDexFundSwitchConfig{cabi.MethodNameDexFundSwitchConfig}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundStakeForPrincipalSVIP] = &MethodDexFundStakeForPrincipalSVIP{cabi.MethodNameDexFundStakeForPrincipalSVIP}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundCancelStakeById] = &MethodDexFundCancelStakeById{cabi.MethodNameDexFundCancelStakeById}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundDelegateStakeCallbackV2] = &MethodDexFundDelegateStakeCallbackV2{cabi.MethodNameDexFundDelegateStakeCallbackV2}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundCancelDelegateStakeCallbackV2] = &MethodDexFundCancelDelegateStakeCallbackV2{cabi.MethodNameDexFundCancelDelegateStakeCallbackV2}

	contracts[types.AddressQuota].m[cabi.MethodNameStakeV3] = &MethodStakeV3{cabi.MethodNameStakeV3}
	contracts[types.AddressQuota].m[cabi.MethodNameCancelStakeV3] = &MethodCancelStakeV3{cabi.MethodNameCancelStakeV3}
	contracts[types.AddressQuota].m[cabi.MethodNameStakeWithCallback] = &MethodStakeV3{cabi.MethodNameStakeWithCallback}
	contracts[types.AddressQuota].m[cabi.MethodNameCancelStakeWithCallback] = &MethodCancelStakeV3{cabi.MethodNameCancelStakeWithCallback}
	return contracts
}

func newDexRobotContracts() map[types.Address]*builtinContract {
	contracts := newEarthContracts()
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundCancelOrderBySendHash] = &MethodDexCancelOrderBySendHash{cabi.MethodNameDexFundCancelOrderBySendHash}
	contracts[types.AddressDexTrade].m[cabi.MethodNameDexTradeInnerCancelOrderBySendHash] = &MethodDexTradeInnerCancelOrderBySendHash{cabi.MethodNameDexTradeInnerCancelOrderBySendHash}
	return contracts
}

func newDexStableMarketContracts() map[types.Address]*builtinContract {
	contracts := newDexRobotContracts()
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundCommonAdminConfig] = &MethodDexCommonAdminConfig{cabi.MethodNameDexFundCommonAdminConfig}
	return contracts
}

func newDexEnrichOrderContracts() map[types.Address]*builtinContract {
	contracts := newDexStableMarketContracts()
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundTransfer] = &MethodDexTransfer{cabi.MethodNameDexFundTransfer}
	return contracts
}

func newDexCrossTransferContracts() map[types.Address]*builtinContract {
	contracts := newDexEnrichOrderContracts()
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundAgentDeposit] = &MethodDexAgentDeposit{cabi.MethodNameDexFundAgentDeposit}
	contracts[types.AddressDexFund].m[cabi.MethodNameDexFundAssignedWithdraw] = &MethodDexAssignedWithdraw{cabi.MethodNameDexFundAssignedWithdraw}
	return contracts
}

// GetBuiltinContractMethod finds method instance of built-in contract method by address and method id
func GetBuiltinContractMethod(addr types.Address, methodSelector []byte, sbHeight uint64) (BuiltinContractMethod, bool, error) {
	var contractsMap map[types.Address]*builtinContract
	if upgrade.IsVersionXUpgrade(sbHeight) {
		contractsMap = dexCrossTransferContracts
	} else if upgrade.IsVersion11Upgrade(sbHeight) {
		contractsMap = dexEnrichOrderContracts
	} else if upgrade.IsDexStableMarketUpgrade(sbHeight) {
		contractsMap = dexStableMarketContracts
	} else if upgrade.IsDexRobotUpgrade(sbHeight) {
		contractsMap = dexRobotContracts
	} else if upgrade.IsEarthUpgrade(sbHeight) {
		contractsMap = earthContracts
	} else if upgrade.IsLeafUpgrade(sbHeight) {
		contractsMap = leafContracts
	} else if upgrade.IsStemUpgrade(sbHeight) {
		contractsMap = dexAgentContracts
	} else if upgrade.IsDexUpgrade(sbHeight) {
		contractsMap = dexContracts
	} else {
		contractsMap = simpleContracts
	}
	p, addrExists := contractsMap[addr]
	if addrExists {
		if method, err := p.abi.MethodById(methodSelector); err == nil {
			c, methodExists := p.m[method.Name]
			if methodExists {
				return c, methodExists, nil
			}
		}
		return nil, addrExists, util.ErrAbiMethodNotFound
	}
	return nil, addrExists, nil
}
