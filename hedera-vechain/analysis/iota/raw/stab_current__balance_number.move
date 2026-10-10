// Move bytecode v6
module c7ab9b9353e23c6a3a15181eb51bf7145ddeff1a5642280394cd4d6a0d37d83b.balance_number {

struct BalanceNumber has store {
	value: u64
}

err_balance_not_enough() {
B0:
	0: LdConst[0](u64: 101)
	1: Abort
}

public new(Arg0: u64): BalanceNumber {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: Pack[0](BalanceNumber)
	2: Ret
}

public add(Arg0: &mut BalanceNumber, Arg1: u64): u64 {
B0:
	0: CopyLoc[0](Arg0: &mut BalanceNumber)
	1: ImmBorrowField[0](BalanceNumber.value: u64)
	2: ReadRef
	3: MoveLoc[1](Arg1: u64)
	4: Add
	5: CopyLoc[0](Arg0: &mut BalanceNumber)
	6: MutBorrowField[0](BalanceNumber.value: u64)
	7: WriteRef
	8: MoveLoc[0](Arg0: &mut BalanceNumber)
	9: ImmBorrowField[0](BalanceNumber.value: u64)
	10: ReadRef
	11: Ret
}

public sub(Arg0: &mut BalanceNumber, Arg1: u64): u64 {
B0:
	0: CopyLoc[0](Arg0: &mut BalanceNumber)
	1: ImmBorrowField[0](BalanceNumber.value: u64)
	2: ReadRef
	3: CopyLoc[1](Arg1: u64)
	4: Lt
	5: BrFalse(7)
B1:
	6: Call err_balance_not_enough()
B2:
	7: CopyLoc[0](Arg0: &mut BalanceNumber)
	8: ImmBorrowField[0](BalanceNumber.value: u64)
	9: ReadRef
	10: MoveLoc[1](Arg1: u64)
	11: Sub
	12: CopyLoc[0](Arg0: &mut BalanceNumber)
	13: MutBorrowField[0](BalanceNumber.value: u64)
	14: WriteRef
	15: MoveLoc[0](Arg0: &mut BalanceNumber)
	16: ImmBorrowField[0](BalanceNumber.value: u64)
	17: ReadRef
	18: Ret
}

public destroy(Arg0: BalanceNumber): u64 {
B0:
	0: MoveLoc[0](Arg0: BalanceNumber)
	1: Unpack[0](BalanceNumber)
	2: Ret
}

public value(Arg0: &BalanceNumber): u64 {
B0:
	0: MoveLoc[0](Arg0: &BalanceNumber)
	1: ImmBorrowField[0](BalanceNumber.value: u64)
	2: ReadRef
	3: Ret
}

Constants [
	0 => u64: 101
]
}
