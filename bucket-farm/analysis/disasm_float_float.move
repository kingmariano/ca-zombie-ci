// Move bytecode v6
module a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8.float {

struct Float has copy, drop, store {
	value: u128
}

err_divided_by_zero() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_subtrahend_too_large() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

public from(Arg0: u64): Float {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU128
	2: LdConst[2](u128: 1000..)
	3: Mul
	4: Pack[0](Float)
	5: Ret
}

public from_percent(Arg0: u8): Float {
B0:
	0: MoveLoc[0](Arg0: u8)
	1: CastU128
	2: LdConst[2](u128: 1000..)
	3: Mul
	4: LdU128(100)
	5: Div
	6: Pack[0](Float)
	7: Ret
}

public from_percent_u64(Arg0: u64): Float {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU128
	2: LdConst[2](u128: 1000..)
	3: Mul
	4: LdU128(100)
	5: Div
	6: Pack[0](Float)
	7: Ret
}

public from_bps(Arg0: u64): Float {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU128
	2: LdConst[2](u128: 1000..)
	3: Mul
	4: LdU128(10000)
	5: Div
	6: Pack[0](Float)
	7: Ret
}

public from_fraction(Arg0: u64, Arg1: u64): Float {
B0:
	0: CopyLoc[1](Arg1: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_divided_by_zero()
B2:
	5: MoveLoc[0](Arg0: u64)
	6: CastU128
	7: LdConst[2](u128: 1000..)
	8: Mul
	9: MoveLoc[1](Arg1: u64)
	10: CastU128
	11: Div
	12: Pack[0](Float)
	13: Ret
}

public from_scaled_val(Arg0: u128): Float {
B0:
	0: MoveLoc[0](Arg0: u128)
	1: Pack[0](Float)
	2: Ret
}

public to_scaled_val(Arg0: Float): u128 {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: Ret
}

public add(Arg0: Float, Arg1: Float): Float {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Add
	7: Pack[0](Float)
	8: Ret
}

public sub(Arg0: Float, Arg1: Float): Float {
B0:
	0: ImmBorrowLoc[1](Arg1: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[0](Arg0: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Gt
	7: BrFalse(9)
B1:
	8: Call err_subtrahend_too_large()
B2:
	9: ImmBorrowLoc[0](Arg0: Float)
	10: ImmBorrowField[0](Float.value: u128)
	11: ReadRef
	12: ImmBorrowLoc[1](Arg1: Float)
	13: ImmBorrowField[0](Float.value: u128)
	14: ReadRef
	15: Sub
	16: Pack[0](Float)
	17: Ret
}

public saturating_sub(Arg0: Float, Arg1: Float): Float {
L2:	loc0: Float
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Lt
	7: BrFalse(12)
B1:
	8: LdU128(0)
	9: Pack[0](Float)
	10: StLoc[2](loc0: Float)
	11: Branch(21)
B2:
	12: ImmBorrowLoc[0](Arg0: Float)
	13: ImmBorrowField[0](Float.value: u128)
	14: ReadRef
	15: ImmBorrowLoc[1](Arg1: Float)
	16: ImmBorrowField[0](Float.value: u128)
	17: ReadRef
	18: Sub
	19: Pack[0](Float)
	20: StLoc[2](loc0: Float)
B3:
	21: MoveLoc[2](loc0: Float)
	22: Ret
}

public mul(Arg0: Float, Arg1: Float): Float {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Mul
	7: LdConst[2](u128: 1000..)
	8: Div
	9: Pack[0](Float)
	10: Ret
}

public div(Arg0: Float, Arg1: Float): Float {
B0:
	0: CopyLoc[1](Arg1: Float)
	1: Call to_scaled_val(Float): u128
	2: LdU128(0)
	3: Eq
	4: BrFalse(6)
B1:
	5: Call err_divided_by_zero()
B2:
	6: ImmBorrowLoc[0](Arg0: Float)
	7: ImmBorrowField[0](Float.value: u128)
	8: ReadRef
	9: LdConst[2](u128: 1000..)
	10: Mul
	11: ImmBorrowLoc[1](Arg1: Float)
	12: ImmBorrowField[0](Float.value: u128)
	13: ReadRef
	14: Div
	15: Pack[0](Float)
	16: Ret
}

public add_u64(Arg0: Float, Arg1: u64): Float {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Float
	3: Call add(Float, Float): Float
	4: Ret
}

public sub_u64(Arg0: Float, Arg1: u64): Float {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Float
	3: Call sub(Float, Float): Float
	4: Ret
}

public saturating_sub_u64(Arg0: Float, Arg1: u64): Float {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Float
	3: Call saturating_sub(Float, Float): Float
	4: Ret
}

public mul_u64(Arg0: Float, Arg1: u64): Float {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Float
	3: Call mul(Float, Float): Float
	4: Ret
}

public div_u64(Arg0: Float, Arg1: u64): Float {
B0:
	0: MoveLoc[0](Arg0: Float)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Float
	3: Call div(Float, Float): Float
	4: Ret
}

public pow(Arg0: Float, Arg1: u64): Float {
L2:	loc0: Float
L3:	loc1: Float
B0:
	0: MoveLoc[0](Arg0: Float)
	1: StLoc[2](loc0: Float)
	2: LdU64(1)
	3: Call from(u64): Float
	4: StLoc[3](loc1: Float)
B1:
	5: CopyLoc[1](Arg1: u64)
	6: LdU64(0)
	7: Gt
	8: BrFalse(29)
B2:
	9: Branch(10)
B3:
	10: CopyLoc[1](Arg1: u64)
	11: LdU64(2)
	12: Mod
	13: LdU64(1)
	14: Eq
	15: BrFalse(20)
B4:
	16: MoveLoc[3](loc1: Float)
	17: CopyLoc[2](loc0: Float)
	18: Call mul(Float, Float): Float
	19: StLoc[3](loc1: Float)
B5:
	20: CopyLoc[2](loc0: Float)
	21: MoveLoc[2](loc0: Float)
	22: Call mul(Float, Float): Float
	23: StLoc[2](loc0: Float)
	24: MoveLoc[1](Arg1: u64)
	25: LdU64(2)
	26: Div
	27: StLoc[1](Arg1: u64)
	28: Branch(5)
B6:
	29: MoveLoc[3](loc1: Float)
	30: Ret
}

public floor(Arg0: Float): u64 {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: LdConst[2](u128: 1000..)
	4: Div
	5: CastU64
	6: Ret
}

public ceil(Arg0: Float): u64 {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: LdConst[2](u128: 1000..)
	4: Add
	5: LdU128(1)
	6: Sub
	7: LdConst[2](u128: 1000..)
	8: Div
	9: CastU64
	10: Ret
}

public eq(Arg0: Float, Arg1: Float): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Eq
	7: Ret
}

public ge(Arg0: Float, Arg1: Float): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Ge
	7: Ret
}

public gt(Arg0: Float, Arg1: Float): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Gt
	7: Ret
}

public le(Arg0: Float, Arg1: Float): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Le
	7: Ret
}

public lt(Arg0: Float, Arg1: Float): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Lt
	7: Ret
}

public min(Arg0: Float, Arg1: Float): Float {
L2:	loc0: Float
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Lt
	7: BrFalse(11)
B1:
	8: MoveLoc[0](Arg0: Float)
	9: StLoc[2](loc0: Float)
	10: Branch(13)
B2:
	11: MoveLoc[1](Arg1: Float)
	12: StLoc[2](loc0: Float)
B3:
	13: MoveLoc[2](loc0: Float)
	14: Ret
}

public max(Arg0: Float, Arg1: Float): Float {
L2:	loc0: Float
B0:
	0: ImmBorrowLoc[0](Arg0: Float)
	1: ImmBorrowField[0](Float.value: u128)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Float)
	4: ImmBorrowField[0](Float.value: u128)
	5: ReadRef
	6: Gt
	7: BrFalse(11)
B1:
	8: MoveLoc[0](Arg0: Float)
	9: StLoc[2](loc0: Float)
	10: Branch(13)
B2:
	11: MoveLoc[1](Arg1: Float)
	12: StLoc[2](loc0: Float)
B3:
	13: MoveLoc[2](loc0: Float)
	14: Ret
}

public wad(): u128 {
B0:
	0: LdConst[2](u128: 1000..)
	1: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u128: 1000000000
]
}
