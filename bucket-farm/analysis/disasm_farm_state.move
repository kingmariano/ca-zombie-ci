// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.state {
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::float;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct PoolState has copy, drop, store {
	asset_type: String,
	flow_rate: Float,
	timestamp: u64,
	total_stake: u64,
	unit: Float
}

err_not_enough_to_unstake() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

public new<Ty0>(Arg0: Float, Arg1: u64, Arg2: Float): PoolState {
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: Call type_name::into_string(TypeName): String
	2: MoveLoc[0](Arg0: Float)
	3: MoveLoc[1](Arg1: u64)
	4: LdU64(0)
	5: MoveLoc[2](Arg2: Float)
	6: Pack[0](PoolState)
	7: Ret
}

public set_flow_rate(Arg0: &mut PoolState, Arg1: Float) {
B0:
	0: MoveLoc[1](Arg1: Float)
	1: MoveLoc[0](Arg0: &mut PoolState)
	2: MutBorrowField[0](PoolState.flow_rate: Float)
	3: WriteRef
	4: Ret
}

public set_timestamp(Arg0: &mut PoolState, Arg1: u64) {
B0:
	0: MoveLoc[1](Arg1: u64)
	1: MoveLoc[0](Arg0: &mut PoolState)
	2: MutBorrowField[1](PoolState.timestamp: u64)
	3: WriteRef
	4: Ret
}

public add_unit(Arg0: &mut PoolState, Arg1: Float) {
B0:
	0: CopyLoc[0](Arg0: &mut PoolState)
	1: FreezeRef
	2: Call unit(&PoolState): Float
	3: MoveLoc[1](Arg1: Float)
	4: Call float::add(Float, Float): Float
	5: MoveLoc[0](Arg0: &mut PoolState)
	6: MutBorrowField[2](PoolState.unit: Float)
	7: WriteRef
	8: Ret
}

public stake(Arg0: &mut PoolState, Arg1: u64): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut PoolState)
	1: FreezeRef
	2: Call total_stake(&PoolState): u64
	3: MoveLoc[1](Arg1: u64)
	4: Add
	5: StLoc[2](loc0: u64)
	6: CopyLoc[2](loc0: u64)
	7: MoveLoc[0](Arg0: &mut PoolState)
	8: MutBorrowField[3](PoolState.total_stake: u64)
	9: WriteRef
	10: MoveLoc[2](loc0: u64)
	11: Ret
}

public unstake(Arg0: &mut PoolState, Arg1: u64): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut PoolState)
	1: FreezeRef
	2: Call total_stake(&PoolState): u64
	3: CopyLoc[1](Arg1: u64)
	4: Lt
	5: BrFalse(7)
B1:
	6: Call err_not_enough_to_unstake()
B2:
	7: CopyLoc[0](Arg0: &mut PoolState)
	8: FreezeRef
	9: Call total_stake(&PoolState): u64
	10: MoveLoc[1](Arg1: u64)
	11: Sub
	12: StLoc[2](loc0: u64)
	13: CopyLoc[2](loc0: u64)
	14: MoveLoc[0](Arg0: &mut PoolState)
	15: MutBorrowField[3](PoolState.total_stake: u64)
	16: WriteRef
	17: MoveLoc[2](loc0: u64)
	18: Ret
}

public asset_type(Arg0: &PoolState): String {
B0:
	0: MoveLoc[0](Arg0: &PoolState)
	1: ImmBorrowField[4](PoolState.asset_type: String)
	2: ReadRef
	3: Ret
}

public flow_rate(Arg0: &PoolState): Float {
B0:
	0: MoveLoc[0](Arg0: &PoolState)
	1: ImmBorrowField[0](PoolState.flow_rate: Float)
	2: ReadRef
	3: Ret
}

public timestamp(Arg0: &PoolState): u64 {
B0:
	0: MoveLoc[0](Arg0: &PoolState)
	1: ImmBorrowField[1](PoolState.timestamp: u64)
	2: ReadRef
	3: Ret
}

public total_stake(Arg0: &PoolState): u64 {
B0:
	0: MoveLoc[0](Arg0: &PoolState)
	1: ImmBorrowField[3](PoolState.total_stake: u64)
	2: ReadRef
	3: Ret
}

public unit(Arg0: &PoolState): Float {
B0:
	0: MoveLoc[0](Arg0: &PoolState)
	1: ImmBorrowField[2](PoolState.unit: Float)
	2: ReadRef
	3: Ret
}

public get_release_amount(Arg0: &PoolState, Arg1: u64): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: CopyLoc[1](Arg1: u64)
	1: CopyLoc[0](Arg0: &PoolState)
	2: Call timestamp(&PoolState): u64
	3: Gt
	4: BrFalse(17)
B1:
	5: MoveLoc[1](Arg1: u64)
	6: CopyLoc[0](Arg0: &PoolState)
	7: Call timestamp(&PoolState): u64
	8: Sub
	9: StLoc[3](loc1: u64)
	10: MoveLoc[0](Arg0: &PoolState)
	11: Call flow_rate(&PoolState): Float
	12: MoveLoc[3](loc1: u64)
	13: Call float::mul_u64(Float, u64): Float
	14: Call float::ceil(Float): u64
	15: StLoc[2](loc0: u64)
	16: Branch(21)
B2:
	17: MoveLoc[0](Arg0: &PoolState)
	18: Pop
	19: LdU64(0)
	20: StLoc[2](loc0: u64)
B3:
	21: MoveLoc[2](loc0: u64)
	22: Ret
}

Constants [
	0 => u64: 0
]
}
