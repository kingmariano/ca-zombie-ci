# Excerpt: fee-period roll panic + dex timestamp/period roll
# Source: vm/contracts/dex/fund_storage.go lines 1108-1213 and 2159-2197

//get all dexFeeses that not divided yet
func GetNotFinishDividendDexFeesByPeriodMap(db interfaces.VmDb, periodId uint64) map[uint64]*DexFeesByPeriod {
	var (
		dexFeesByPeriods = make(map[uint64]*DexFeesByPeriod)
		dexFeesByPeriod  *DexFeesByPeriod
		ok, everFound    bool
	)
	for {
		if dexFeesByPeriod, ok = GetDexFeesByPeriodId(db, periodId); !ok { // found first valid period
			if periodId > 0 && !everFound {
				periodId--
				continue
			} else { // lastValidPeriod is delete
				return dexFeesByPeriods
			}
		} else {
			everFound = true
			if !dexFeesByPeriod.FinishDividend {
				dexFeesByPeriods[periodId] = dexFeesByPeriod
			} else {
				return dexFeesByPeriods
			}
		}
		periodId = dexFeesByPeriod.LastValidPeriod
		if periodId == 0 {
			return dexFeesByPeriods
		}
	}
}

func SaveDexFeesByPeriodId(db interfaces.VmDb, periodId uint64, dexFeesByPeriod *DexFeesByPeriod) {
	serializeToDb(db, GetDexFeesKeyByPeriodId(periodId), dexFeesByPeriod)
}

//dexFees used both by fee dividend and mined vx dividend
func MarkDexFeesFinishDividend(db interfaces.VmDb, dexFeesByPeriod *DexFeesByPeriod, periodId uint64) {
	if dexFeesByPeriod.FinishMine {
		setValueToDb(db, GetDexFeesKeyByPeriodId(periodId), nil)
	} else {
		dexFeesByPeriod.FinishDividend = true
		serializeToDb(db, GetDexFeesKeyByPeriodId(periodId), dexFeesByPeriod)
	}
}

func RollAndGentNewDexFeesByPeriod(db interfaces.VmDb, periodId uint64) (rolledDexFeesByPeriod *DexFeesByPeriod) {
	formerId := GetDexFeesLastPeriodIdForRoll(db)
	rolledDexFeesByPeriod = &DexFeesByPeriod{}
	if formerId > 0 {
		if formerDexFeesByPeriod, ok := GetDexFeesByPeriodId(db, formerId); !ok { // lastPeriod has been deleted on fee dividend
			panic(NoDexFeesFoundForValidPeriodErr)
		} else {
			rolledDexFeesByPeriod.LastValidPeriod = formerId
			for _, formerFeeForDividend := range formerDexFeesByPeriod.FeesForDividend {
				rolledFee := &dexproto.FeeForDividend{}
				rolledFee.Token = formerFeeForDividend.Token
				if bytes.Equal(rolledFee.Token, ledger.ViteTokenId.Bytes()) && IsEarthFork(db) {
					rolledFee.NotRoll = true
				}
				_, rolledAmount := splitDividendPool(formerFeeForDividend) //when former pool is NotRoll, rolledAmount is nil
				rolledFee.DividendPoolAmount = rolledAmount.Bytes()
				rolledDexFeesByPeriod.FeesForDividend = append(rolledDexFeesByPeriod.FeesForDividend, rolledFee)
			}
		}
	} else {
		// On startup, save one empty dividendPool for vite to diff db storage empty for serialize result
		rolledFee := &dexproto.FeeForDividend{}
		rolledFee.Token = ledger.ViteTokenId.Bytes()
		rolledDexFeesByPeriod.FeesForDividend = append(rolledDexFeesByPeriod.FeesForDividend, rolledFee)
	}
	SaveDexFeesLastPeriodIdForRoll(db, periodId)
	return
}

func MarkDexFeesFinishMine(db interfaces.VmDb, dexFeesByPeriod *DexFeesByPeriod, periodId uint64) {
	if dexFeesByPeriod.FinishDividend {
		setValueToDb(db, GetDexFeesKeyByPeriodId(periodId), nil)
	} else {
		dexFeesByPeriod.FinishMine = true
		serializeToDb(db, GetDexFeesKeyByPeriodId(periodId), dexFeesByPeriod)
	}
	if dexFeesByPeriod.LastValidPeriod > 0 {
		markFormerDexFeesFinishMine(db, dexFeesByPeriod.LastValidPeriod)
	}
}

func markFormerDexFeesFinishMine(db interfaces.VmDb, periodId uint64) {
	if dexFeesByPeriod, ok := GetDexFeesByPeriodId(db, periodId); ok {
		MarkDexFeesFinishMine(db, dexFeesByPeriod, periodId)
	}
}

func GetDexFeesKeyByPeriodId(periodId uint64) []byte {
	return append(dexFeesKeyPrefix, Uint64ToBytes(periodId)...)
}

func GetDexFeesLastPeriodIdForRoll(db interfaces.VmDb) uint64 {
	if lastPeriodIdBytes := getValueFromDb(db, lastDexFeesPeriodIdKey); len(lastPeriodIdBytes) == 8 {
		return BytesToUint64(lastPeriodIdBytes)
	} else {
		return 0
	}
}

func SaveDexFeesLastPeriodIdForRoll(db interfaces.VmDb, periodId uint64) {
	setValueToDb(db, lastDexFeesPeriodIdKey, Uint64ToBytes(periodId))
}

func GetTimestampInt64(db interfaces.VmDb) int64 {
	timestamp := GetDexTimestamp(db)
	if timestamp == 0 {
		panic(NotSetTimestampErr)
	} else {
		return timestamp
	}
}

func SetDexTimestamp(db interfaces.VmDb, timestamp int64, reader util.ConsensusReader) error {
	oldTime := GetDexTimestamp(db)
	if timestamp > oldTime {
		oldPeriod := GetPeriodIdByTimestamp(reader, oldTime)
		newPeriod := GetPeriodIdByTimestamp(reader, timestamp)
		if newPeriod != oldPeriod {
			if newPeriod-oldPeriod > 1 && IsDexRobotFork(db) && oldTime > 0 {
				return OracleTimestampExceedPeriodGapErr
			}
			doRollPeriod(db, newPeriod)
		}
		setValueToDb(db, dexTimestampKey, Uint64ToBytes(uint64(timestamp)))
		return nil
	} else {
		return InvalidTimestampFromTimeOracleErr
	}
}

func doRollPeriod(db interfaces.VmDb, newPeriodId uint64) {
	newDexFeesByPeriod := RollAndGentNewDexFeesByPeriod(db, newPeriodId)
	SaveDexFeesByPeriodId(db, newPeriodId, newDexFeesByPeriod)
}

func GetDexTimestamp(db interfaces.VmDb) int64 {
	if bs := getValueFromDb(db, dexTimestampKey); len(bs) == 8 {
		return int64(BytesToUint64(bs))
	} else {
		return 0
	}
}
