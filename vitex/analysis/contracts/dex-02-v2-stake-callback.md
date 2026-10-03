# Excerpt: DexFund V2 (Earth) delegate-stake callbacks and Quota stake methods
# Sources: vm/contracts/contracts_dex_fund.go lines 823-1003; vm/contracts/contracts_quota.go lines 365-542
# Line 879: inverted failure check (bytes.Equal instead of !bytes.Equal) - compare line 938 (cancel path, correct polarity)

func (md MethodDexFundDelegateStakeCallbackV2) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) (blocks []*ledger.AccountBlock, err error) {
	var param = new(dex.ParamDelegateStakeCallbackV2)
	cabi.ABIDexFund.UnpackMethod(param, md.MethodName, sendBlock.Data)
	var (
		info *dex.DelegateStakeInfo
		ok   bool
	)
	if info, ok = dex.GetDelegateStakeInfo(db, param.Id.Bytes()); !ok {
		return handleDexReceiveErr(fundLogger, md.MethodName, dex.StakingInfoByIdNotExistsErr, sendBlock)
	}
	address, _ := types.BytesToAddress(info.Address)
	amount := new(big.Int).SetBytes(info.Amount)
	if param.Success {
		switch info.StakeType {
		case dex.StakeForMining:
			stakedAmount := dex.GetMiningStakedV2Amount(db, address)
			stakedAmount.Add(stakedAmount, amount)
			dex.SaveMiningStakedV2Amount(db, address, stakedAmount)
			if err = dex.OnMiningStakeSuccessV2(db, vm.ConsensusReader(), address, amount, stakedAmount); err != nil {
				return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
			}
		case dex.StakeForVIP:
			if vipStaking, ok := dex.GetVIPStaking(db, address); ok { //duplicate staking for vip
				vipStaking.StakedTimes = vipStaking.StakedTimes + 1
				vipStaking.StakingHashes = append(vipStaking.StakingHashes, param.Id.Bytes())
				dex.SaveVIPStaking(db, address, vipStaking)
				// duplicate staking for vip, cancel stake
				blocks, err = dex.DoRawCancelStakeV2(param.Id)
			} else {
				vipStaking.Timestamp = dex.GetTimestampInt64(db)
				vipStaking.StakedTimes = 1
				vipStaking.StakingHashes = append(vipStaking.StakingHashes, param.Id.Bytes())
				dex.SaveVIPStaking(db, address, vipStaking)
			}
		case dex.StakeForSuperVIP, dex.StakeForPrincipalSuperVIP:
			if info.StakeType == dex.StakeForPrincipalSuperVIP {
				address, _ = types.BytesToAddress(info.Principal) // principal
			}
			if superVIPStaking, ok := dex.GetSuperVIPStaking(db, address); ok { //duplicate staking for super vip
				superVIPStaking.StakedTimes = superVIPStaking.StakedTimes + 1
				superVIPStaking.StakingHashes = append(superVIPStaking.StakingHashes, param.Id.Bytes())
				dex.SaveSuperVIPStaking(db, address, superVIPStaking)
				// duplicate staking for vip, cancel stake
				blocks, err = dex.DoRawCancelStakeV2(param.Id)
			} else {
				superVIPStaking.Timestamp = dex.GetTimestampInt64(db)
				superVIPStaking.StakedTimes = 1
				superVIPStaking.StakingHashes = append(superVIPStaking.StakingHashes, param.Id.Bytes())
				dex.SaveSuperVIPStaking(db, address, superVIPStaking)
			}
		}
		serialNo := dex.SaveDelegateStakeAddressIndex(db, param.Id, info.StakeType, info.Address)
		dex.ConfirmDelegateStakeInfo(db, param.Id, info, serialNo)
	} else {
		switch info.StakeType {
		case dex.StakeForMining:
			if bytes.Equal(info.Amount, sendBlock.Amount.Bytes()) {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidAmountForStakeCallbackErr, sendBlock)
			}
		case dex.StakeForVIP:
			if dex.StakeForVIPAmount.Cmp(sendBlock.Amount) != 0 {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidAmountForStakeCallbackErr, sendBlock)
			}
		case dex.StakeForSuperVIP, dex.StakeForPrincipalSuperVIP:
			if dex.StakeForSuperVIPAmount.Cmp(sendBlock.Amount) != 0 {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidAmountForStakeCallbackErr, sendBlock)
			}
		}
		dex.DepositAccount(db, address, ledger.ViteTokenId, sendBlock.Amount)
		dex.DeleteDelegateStakeInfo(db, param.Id.Bytes())
	}
	return
}

type MethodDexFundCancelDelegateStakeCallbackV2 struct {
	MethodName string
}

func (md *MethodDexFundCancelDelegateStakeCallbackV2) GetFee(block *ledger.AccountBlock) (*big.Int, error) {
	return big.NewInt(0), nil
}

func (md *MethodDexFundCancelDelegateStakeCallbackV2) GetRefundData(sendBlock *ledger.AccountBlock, sbHeight uint64) ([]byte, bool) {
	return []byte{}, false
}

func (md *MethodDexFundCancelDelegateStakeCallbackV2) GetSendQuota(data []byte, gasTable *util.QuotaTable) (uint64, error) {
	return util.RequestQuotaCost(data, gasTable)
}

func (md *MethodDexFundCancelDelegateStakeCallbackV2) GetReceiveQuota(gasTable *util.QuotaTable) uint64 {
	return gasTable.DexFundDelegateCancelStakeCallbackV2Quota
}

func (md *MethodDexFundCancelDelegateStakeCallbackV2) DoSend(db interfaces.VmDb, block *ledger.AccountBlock) error {
	if block.AccountAddress != types.AddressQuota {
		return dex.InvalidSourceAddressErr
	}
	return cabi.ABIDexFund.UnpackMethod(new(dex.ParamDelegateStakeCallbackV2), md.MethodName, block.Data)
}

func (md MethodDexFundCancelDelegateStakeCallbackV2) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	var param = new(dex.ParamDelegateStakeCallbackV2)
	cabi.ABIDexFund.UnpackMethod(param, md.MethodName, sendBlock.Data)
	var (
		info *dex.DelegateStakeInfo
		ok   bool
	)
	if info, ok = dex.GetDelegateStakeInfo(db, param.Id.Bytes()); !ok {
		return handleDexReceiveErr(fundLogger, md.MethodName, dex.StakingInfoByIdNotExistsErr, sendBlock)
	}
	address, _ := types.BytesToAddress(info.Address)
	if param.Success {
		switch info.StakeType {
		case dex.StakeForMining:
			if !bytes.Equal(info.Amount, sendBlock.Amount.Bytes()) {
				panic(dex.InvalidAmountForStakeCallbackErr)
			}
			stakedAmount := dex.GetMiningStakedV2Amount(db, address)
			leaved := new(big.Int).Sub(stakedAmount, sendBlock.Amount)
			if leaved.Sign() < 0 {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.InvalidAmountForStakeCallbackErr, sendBlock)
			} else if leaved.Sign() == 0 {
				dex.DeleteMiningStakedV2Amount(db, address)
			} else {
				dex.SaveMiningStakedV2Amount(db, address, leaved)
			}
			if err := dex.OnCancelMiningStakeSuccessV2(db, vm.ConsensusReader(), address, sendBlock.Amount, leaved); err != nil {
				return handleDexReceiveErr(fundLogger, md.MethodName, err, sendBlock)
			}
		case dex.StakeForVIP:
			if dex.StakeForVIPAmount.Cmp(sendBlock.Amount) != 0 {
				panic(dex.InvalidAmountForStakeCallbackErr)
			}
			if vipStaking, ok := dex.GetVIPStaking(db, address); ok {
				vipStaking.StakedTimes = vipStaking.StakedTimes - 1
				if vipStaking.StakedTimes == 0 {
					dex.DeleteVIPStaking(db, address)
				} else {
					if ok = dex.ReduceVipStakingHash(vipStaking, param.Id); !ok {
						panic(dex.InvalidIdForStakeCallbackErr)
					}
					dex.SaveVIPStaking(db, address, vipStaking)
				}
			} else {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.VIPStakingNotExistsErr, sendBlock)
			}
		case dex.StakeForSuperVIP, dex.StakeForPrincipalSuperVIP:
			if info.StakeType == dex.StakeForPrincipalSuperVIP {
				address, _ = types.BytesToAddress(info.Principal) // principal
			}
			if dex.StakeForSuperVIPAmount.Cmp(sendBlock.Amount) != 0 {
				panic(dex.InvalidAmountForStakeCallbackErr)
			}
			if superVIPStaking, ok := dex.GetSuperVIPStaking(db, address); ok {
				superVIPStaking.StakedTimes = superVIPStaking.StakedTimes - 1
				if superVIPStaking.StakedTimes == 0 {
					dex.DeleteSuperVIPStaking(db, address)
				} else {
					if ok = dex.ReduceVipStakingHash(superVIPStaking, param.Id); !ok {
						panic(dex.InvalidIdForStakeCallbackErr)
					}
					dex.SaveSuperVIPStaking(db, address, superVIPStaking)
				}
			} else {
				return handleDexReceiveErr(fundLogger, md.MethodName, dex.SuperVIPStakingNotExistsErr, sendBlock)
			}
		}
		if info.StakeType == dex.StakeForPrincipalSuperVIP {
			stakeAddress, _ := types.BytesToAddress(info.Address) // address
			dex.DepositAccount(db, stakeAddress, ledger.ViteTokenId, sendBlock.Amount)
		} else if info.StakeType == dex.StakeForMining {
			dex.ScheduleCancelStake(db, address, sendBlock.Amount)
		} else {
			dex.DepositAccount(db, address, ledger.ViteTokenId, sendBlock.Amount)
		}
		dex.DeleteDelegateStakeInfo(db, param.Id.Bytes())
		dex.DeleteDelegateStakeAddressIndex(db, info.Address, info.SerialNo)
	}
	return nil, nil
}

type MethodStakeV3 struct {
	MethodName string
}

func (p *MethodStakeV3) GetFee(block *ledger.AccountBlock) (*big.Int, error) {
	return big.NewInt(0), nil
}

func (p *MethodStakeV3) GetRefundData(sendBlock *ledger.AccountBlock, sbHeight uint64) ([]byte, bool) {
	if p.MethodName == abi.MethodNameStakeWithCallback {
		callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, sendBlock.Hash, false)
		return callbackData, true
	} else {
		return []byte{}, false
	}
}

func (p *MethodStakeV3) GetSendQuota(data []byte, gasTable *util.QuotaTable) (uint64, error) {
	if p.MethodName == abi.MethodNameStakeWithCallback {
		return gasTable.DelegateStakeQuota, nil
	}
	return gasTable.StakeQuota, nil
}
func (p *MethodStakeV3) GetReceiveQuota(gasTable *util.QuotaTable) uint64 {
	return 0
}

func (p *MethodStakeV3) DoSend(db interfaces.VmDb, block *ledger.AccountBlock) error {
	if !util.IsViteToken(block.TokenId) ||
		block.Amount.Cmp(stakeAmountMin) < 0 {
		return util.ErrInvalidMethodParam
	}
	param := new(abi.ParamStakeV3)
	if err := abi.ABIQuota.UnpackMethod(param, p.MethodName, block.Data); err != nil {
		return util.ErrInvalidMethodParam
	}
	if p.MethodName == abi.MethodNameStakeWithCallback {
		if param.StakeHeight < nodeConfig.params.StakeHeight || param.StakeHeight > stakeHeightMax {
			return util.ErrInvalidMethodParam
		}
		block.Data, _ = abi.ABIQuota.PackMethod(p.MethodName, param.Beneficiary, param.StakeHeight)
	} else {
		block.Data, _ = abi.ABIQuota.PackMethod(p.MethodName, param.Beneficiary)
	}
	return nil
}
func (p *MethodStakeV3) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	param := new(abi.ParamDelegateStake)
	abi.ABIQuota.UnpackMethod(param, p.MethodName, sendBlock.Data)
	stakeInfoKey := getNextStakeInfoKey(db, sendBlock.AccountAddress, block.Height)
	var stakeHeight uint64
	if p.MethodName == abi.MethodNameStakeWithCallback {
		stakeHeight = param.StakeHeight
	} else {
		stakeHeight = nodeConfig.params.StakeHeight
	}
	stakeInfo, _ := abi.ABIQuota.PackVariable(abi.VariableNameStakeInfoV2, sendBlock.Amount, getStakeExpirationHeight(vm, stakeHeight), param.Beneficiary, sendBlock.Hash)
	util.SetValue(db, stakeInfoKey, stakeInfo)
	util.SetValue(db, sendBlock.Hash.Bytes(), stakeInfoKey)

	beneficialKey := abi.GetStakeBeneficialKey(param.Beneficiary)
	oldBeneficialData := util.GetValue(db, beneficialKey)
	var beneficialAmount *big.Int
	if len(oldBeneficialData) > 0 {
		oldBeneficial := new(abi.VariableStakeBeneficial)
		abi.ABIQuota.UnpackVariable(oldBeneficial, abi.VariableNameStakeBeneficial, oldBeneficialData)
		beneficialAmount = oldBeneficial.Amount
	} else {
		beneficialAmount = big.NewInt(0)
	}
	beneficialAmount.Add(beneficialAmount, sendBlock.Amount)
	beneficialData, _ := abi.ABIQuota.PackVariable(abi.VariableNameStakeBeneficial, beneficialAmount)
	util.SetValue(db, beneficialKey, beneficialData)
	if p.MethodName == abi.MethodNameStakeWithCallback {
		callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, sendBlock.Hash, true)
		return []*ledger.AccountBlock{
			{
				AccountAddress: block.AccountAddress,
				ToAddress:      sendBlock.AccountAddress,
				BlockType:      ledger.BlockTypeSendCall,
				Amount:         big.NewInt(0),
				TokenId:        ledger.ViteTokenId,
				Data:           callbackData,
			},
		}, nil
	}
	return nil, nil
}
