# Excerpt: Quota contract open entry points (DelegateStake / StakeWithCallback / CancelStakeWithCallback)
# Source: vm/contracts/contracts_quota.go lines 199-363 and 365-542
# Note: DoSend for DelegateStake has NO sender restriction (line 221-235); callback always goes to sendBlock.AccountAddress

type MethodDelegateStake struct {
	MethodName string
}

func (p *MethodDelegateStake) GetFee(block *ledger.AccountBlock) (*big.Int, error) {
	return big.NewInt(0), nil
}

func (p *MethodDelegateStake) GetRefundData(sendBlock *ledger.AccountBlock, sbHeight uint64) ([]byte, bool) {
	param := new(abi.ParamDelegateStake)
	abi.ABIQuota.UnpackMethod(param, p.MethodName, sendBlock.Data)
	callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, param.StakeAddress, param.Beneficiary, sendBlock.Amount, param.Bid, false)
	return callbackData, true
}

func (p *MethodDelegateStake) GetSendQuota(data []byte, gasTable *util.QuotaTable) (uint64, error) {
	return gasTable.DelegateStakeQuota, nil
}
func (p *MethodDelegateStake) GetReceiveQuota(gasTable *util.QuotaTable) uint64 {
	return 0
}

func (p *MethodDelegateStake) DoSend(db interfaces.VmDb, block *ledger.AccountBlock) error {
	if !util.IsViteToken(block.TokenId) ||
		block.Amount.Cmp(stakeAmountMin) < 0 {
		return util.ErrInvalidMethodParam
	}
	param := new(abi.ParamDelegateStake)
	if err := abi.ABIQuota.UnpackMethod(param, p.MethodName, block.Data); err != nil {
		return util.ErrInvalidMethodParam
	}
	if param.StakeHeight < nodeConfig.params.StakeHeight || param.StakeHeight > stakeHeightMax {
		return util.ErrInvalidMethodParam
	}
	block.Data, _ = abi.ABIQuota.PackMethod(p.MethodName, param.StakeAddress, param.Beneficiary, param.Bid, param.StakeHeight)
	return nil
}
func (p *MethodDelegateStake) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	param := new(abi.ParamDelegateStake)
	abi.ABIQuota.UnpackMethod(param, p.MethodName, sendBlock.Data)
	stakeInfoKey, oldStakeInfo := getStakeInfo(db, param.StakeAddress, param.Beneficiary, delegate, sendBlock.AccountAddress, param.Bid, block.Height)
	var amount *big.Int
	oldExpirationHeight := uint64(0)
	if oldStakeInfo != nil {
		amount = oldStakeInfo.Amount
		oldExpirationHeight = oldStakeInfo.ExpirationHeight
	} else {
		amount = big.NewInt(0)
	}
	amount.Add(amount, sendBlock.Amount)
	stakeInfo, _ := abi.ABIQuota.PackVariable(abi.VariableNameStakeInfo, amount, helper.Max(oldExpirationHeight, getStakeExpirationHeight(vm, param.StakeHeight)), param.Beneficiary, delegate, sendBlock.AccountAddress, param.Bid)
	util.SetValue(db, stakeInfoKey, stakeInfo)

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

	callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, param.StakeAddress, param.Beneficiary, sendBlock.Amount, param.Bid, true)
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

type MethodCancelDelegateStake struct {
	MethodName string
}

func (p *MethodCancelDelegateStake) GetFee(block *ledger.AccountBlock) (*big.Int, error) {
	return big.NewInt(0), nil
}

func (p *MethodCancelDelegateStake) GetRefundData(sendBlock *ledger.AccountBlock, sbHeight uint64) ([]byte, bool) {
	param := new(abi.ParamCancelDelegateStake)
	abi.ABIQuota.UnpackMethod(param, p.MethodName, sendBlock.Data)
	callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, param.StakeAddress, param.Beneficiary, param.Amount, param.Bid, false)
	return callbackData, true
}

func (p *MethodCancelDelegateStake) GetSendQuota(data []byte, gasTable *util.QuotaTable) (uint64, error) {
	return gasTable.CancelDelegateStakeQuota, nil
}

func (p *MethodCancelDelegateStake) GetReceiveQuota(gasTable *util.QuotaTable) uint64 {
	return 0
}

func (p *MethodCancelDelegateStake) DoSend(db interfaces.VmDb, block *ledger.AccountBlock) error {
	if block.Amount.Sign() > 0 {
		return util.ErrInvalidMethodParam
	}
	param := new(abi.ParamCancelDelegateStake)
	if err := abi.ABIQuota.UnpackMethod(param, p.MethodName, block.Data); err != nil {
		return util.ErrInvalidMethodParam
	}
	if param.Amount.Cmp(stakeAmountMin) < 0 {
		return util.ErrInvalidMethodParam
	}
	block.Data, _ = abi.ABIQuota.PackMethod(p.MethodName, param.StakeAddress, param.Beneficiary, param.Amount, param.Bid)
	return nil
}

func (p *MethodCancelDelegateStake) DoReceive(db interfaces.VmDb, block *ledger.AccountBlock, sendBlock *ledger.AccountBlock, vm vmEnvironment) ([]*ledger.AccountBlock, error) {
	param := new(abi.ParamCancelDelegateStake)
	abi.ABIQuota.UnpackMethod(param, p.MethodName, sendBlock.Data)
	stakeInfoKey, oldStakeInfo := getStakeInfo(db, param.StakeAddress, param.Beneficiary, delegate, sendBlock.AccountAddress, param.Bid, block.Height)
	if oldStakeInfo == nil || stakeNotDue(oldStakeInfo, vm) || oldStakeInfo.Amount.Cmp(param.Amount) < 0 || oldStakeInfo.Id != nil {
		return nil, util.ErrInvalidMethodParam
	}
	oldStakeInfo.Amount.Sub(oldStakeInfo.Amount, param.Amount)
	if oldStakeInfo.Amount.Sign() != 0 && oldStakeInfo.Amount.Cmp(stakeAmountMin) < 0 {
		return nil, util.ErrInvalidMethodParam
	}

	oldBeneficial := new(abi.VariableStakeBeneficial)
	beneficialKey := abi.GetStakeBeneficialKey(param.Beneficiary)
	v := util.GetValue(db, beneficialKey)
	err := abi.ABIQuota.UnpackVariable(oldBeneficial, abi.VariableNameStakeBeneficial, v)
	if err != nil || oldBeneficial.Amount.Cmp(param.Amount) < 0 {
		return nil, util.ErrInvalidMethodParam
	}
	oldBeneficial.Amount.Sub(oldBeneficial.Amount, param.Amount)

	if oldStakeInfo.Amount.Sign() == 0 {
		util.SetValue(db, stakeInfoKey, nil)
	} else {
		stakeInfo, _ := abi.ABIQuota.PackVariable(abi.VariableNameStakeInfo, oldStakeInfo.Amount, oldStakeInfo.ExpirationHeight, oldStakeInfo.Beneficiary, delegate, oldStakeInfo.DelegateAddress, param.Bid)
		util.SetValue(db, stakeInfoKey, stakeInfo)
	}

	if oldBeneficial.Amount.Sign() == 0 {
		util.SetValue(db, beneficialKey, nil)
	} else {
		stakeBeneficialAmount, _ := abi.ABIQuota.PackVariable(abi.VariableNameStakeBeneficial, oldBeneficial.Amount)
		util.SetValue(db, beneficialKey, stakeBeneficialAmount)
	}

	callbackData, _ := abi.ABIQuota.PackCallback(p.MethodName, param.StakeAddress, param.Beneficiary, param.Amount, param.Bid, true)
	return []*ledger.AccountBlock{
		{
			AccountAddress: block.AccountAddress,
			ToAddress:      sendBlock.AccountAddress,
			BlockType:      ledger.BlockTypeSendCall,
			Amount:         param.Amount,
			TokenId:        ledger.ViteTokenId,
			Data:           callbackData,
		},
	}, nil
}
