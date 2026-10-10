// Move bytecode v6
module d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f.limited_supply {

struct LimitedSupply has store {
	limit: u64,
	supply: u64
}

err_destroy_non_empty_supply() {
B0:
	0: LdConst[0](u64: 100)
	1: Abort
}

err_exceed_limit() {
B0:
	0: LdConst[1](u64: 101)
	1: Abort
}

err_supply_not_enough() {
B0:
	0: LdConst[2](u64: 102)
	1: Abort
}

public new(Arg0: u64): LimitedSupply {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: LdU64(0)
	2: Pack[0](LimitedSupply)
	3: Ret
}

public destroy(Arg0: LimitedSupply) {
L1:	loc0: u64
B0:
	0: MoveLoc[0](Arg0: LimitedSupply)
	1: Unpack[0](LimitedSupply)
	2: StLoc[1](loc0: u64)
	3: Pop
	4: MoveLoc[1](loc0: u64)
	5: LdU64(0)
	6: Gt
	7: BrFalse(9)
B1:
	8: Call err_destroy_non_empty_supply()
B2:
	9: Ret
}

public increase(Arg0: &mut LimitedSupply, Arg1: u64): u64 {
B0:
	0: CopyLoc[0](Arg0: &mut LimitedSupply)
	1: FreezeRef
	2: Call supply(&LimitedSupply): u64
	3: MoveLoc[1](Arg1: u64)
	4: Add
	5: CopyLoc[0](Arg0: &mut LimitedSupply)
	6: MutBorrowField[0](LimitedSupply.supply: u64)
	7: WriteRef
	8: CopyLoc[0](Arg0: &mut LimitedSupply)
	9: FreezeRef
	10: Call supply(&LimitedSupply): u64
	11: CopyLoc[0](Arg0: &mut LimitedSupply)
	12: FreezeRef
	13: Call limit(&LimitedSupply): u64
	14: Gt
	15: BrFalse(17)
B1:
	16: Call err_exceed_limit()
B2:
	17: MoveLoc[0](Arg0: &mut LimitedSupply)
	18: FreezeRef
	19: Call supply(&LimitedSupply): u64
	20: Ret
}

public decrease(Arg0: &mut LimitedSupply, Arg1: u64): u64 {
B0:
	0: CopyLoc[0](Arg0: &mut LimitedSupply)
	1: FreezeRef
	2: Call supply(&LimitedSupply): u64
	3: CopyLoc[1](Arg1: u64)
	4: Lt
	5: BrFalse(7)
B1:
	6: Call err_supply_not_enough()
B2:
	7: CopyLoc[0](Arg0: &mut LimitedSupply)
	8: FreezeRef
	9: Call supply(&LimitedSupply): u64
	10: MoveLoc[1](Arg1: u64)
	11: Sub
	12: CopyLoc[0](Arg0: &mut LimitedSupply)
	13: MutBorrowField[0](LimitedSupply.supply: u64)
	14: WriteRef
	15: MoveLoc[0](Arg0: &mut LimitedSupply)
	16: FreezeRef
	17: Call supply(&LimitedSupply): u64
	18: Ret
}

public set_limit(Arg0: &mut LimitedSupply, Arg1: u64) {
B0:
	0: MoveLoc[1](Arg1: u64)
	1: MoveLoc[0](Arg0: &mut LimitedSupply)
	2: MutBorrowField[1](LimitedSupply.limit: u64)
	3: WriteRef
	4: Ret
}

public limit(Arg0: &LimitedSupply): u64 {
B0:
	0: MoveLoc[0](Arg0: &LimitedSupply)
	1: ImmBorrowField[1](LimitedSupply.limit: u64)
	2: ReadRef
	3: Ret
}

public supply(Arg0: &LimitedSupply): u64 {
B0:
	0: MoveLoc[0](Arg0: &LimitedSupply)
	1: ImmBorrowField[0](LimitedSupply.supply: u64)
	2: ReadRef
	3: Ret
}

Constants [
	0 => u64: 100
	1 => u64: 101
	2 => u64: 102
]
}
