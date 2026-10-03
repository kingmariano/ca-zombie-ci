// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.stake {
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::float;

struct Stake has copy, drop, store {
	amount: u64,
	unit: Float,
	cumulant: u64
}

err_not_enough_to_unstake() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

public new(Arg0: u64, Arg1: Float): Stake {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: MoveLoc[1](Arg1: Float)
	2: LdU64(0)
	3: Pack[0](Stake)
	4: Ret
}

public add(Arg0: &mut Stake, Arg1: u64): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut Stake)
	1: FreezeRef
	2: Call amount(&Stake): u64
	3: MoveLoc[1](Arg1: u64)
	4: Add
	5: StLoc[2](loc0: u64)
	6: CopyLoc[2](loc0: u64)
	7: MoveLoc[0](Arg0: &mut Stake)
	8: MutBorrowField[0](Stake.amount: u64)
	9: WriteRef
	10: MoveLoc[2](loc0: u64)
	11: Ret
}

public sub(Arg0: &mut Stake, Arg1: u64): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut Stake)
	1: FreezeRef
	2: Call amount(&Stake): u64
	3: CopyLoc[1](Arg1: u64)
	4: Lt
	5: BrFalse(7)
B1:
	6: Call err_not_enough_to_unstake()
B2:
	7: CopyLoc[0](Arg0: &mut Stake)
	8: FreezeRef
	9: Call amount(&Stake): u64
	10: MoveLoc[1](Arg1: u64)
	11: Sub
	12: StLoc[2](loc0: u64)
	13: CopyLoc[2](loc0: u64)
	14: MoveLoc[0](Arg0: &mut Stake)
	15: MutBorrowField[0](Stake.amount: u64)
	16: WriteRef
	17: MoveLoc[2](loc0: u64)
	18: Ret
}

public set_unit(Arg0: &mut Stake, Arg1: Float) {
B0:
	0: MoveLoc[1](Arg1: Float)
	1: MoveLoc[0](Arg0: &mut Stake)
	2: MutBorrowField[1](Stake.unit: Float)
	3: WriteRef
	4: Ret
}

public cumulate(Arg0: &mut Stake, Arg1: u64): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut Stake)
	1: FreezeRef
	2: Call cumulant(&Stake): u64
	3: MoveLoc[1](Arg1: u64)
	4: Add
	5: StLoc[2](loc0: u64)
	6: CopyLoc[2](loc0: u64)
	7: MoveLoc[0](Arg0: &mut Stake)
	8: MutBorrowField[2](Stake.cumulant: u64)
	9: WriteRef
	10: MoveLoc[2](loc0: u64)
	11: Ret
}

public amount(Arg0: &Stake): u64 {
B0:
	0: MoveLoc[0](Arg0: &Stake)
	1: ImmBorrowField[0](Stake.amount: u64)
	2: ReadRef
	3: Ret
}

public unit(Arg0: &Stake): Float {
B0:
	0: MoveLoc[0](Arg0: &Stake)
	1: ImmBorrowField[1](Stake.unit: Float)
	2: ReadRef
	3: Ret
}

public cumulant(Arg0: &Stake): u64 {
B0:
	0: MoveLoc[0](Arg0: &Stake)
	1: ImmBorrowField[2](Stake.cumulant: u64)
	2: ReadRef
	3: Ret
}

Constants [
	0 => u64: 0
]
}
