// Move bytecode v6
module 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b.double {

struct Double has copy, drop, store {
	value: u256
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

public from(Arg0: u64): Double {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU256
	2: LdConst[2](u256: 1000..)
	3: Mul
	4: Pack[0](Double)
	5: Ret
}

public from_percent(Arg0: u8): Double {
B0:
	0: MoveLoc[0](Arg0: u8)
	1: CastU256
	2: LdConst[2](u256: 1000..)
	3: Mul
	4: LdU256(100)
	5: Div
	6: Pack[0](Double)
	7: Ret
}

public from_percent_u64(Arg0: u64): Double {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU256
	2: LdConst[2](u256: 1000..)
	3: Mul
	4: LdU256(100)
	5: Div
	6: Pack[0](Double)
	7: Ret
}

public from_bps(Arg0: u64): Double {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: CastU256
	2: LdConst[2](u256: 1000..)
	3: Mul
	4: LdU256(10000)
	5: Div
	6: Pack[0](Double)
	7: Ret
}

public from_fraction(Arg0: u64, Arg1: u64): Double {
B0:
	0: CopyLoc[1](Arg1: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_divided_by_zero()
B2:
	5: MoveLoc[0](Arg0: u64)
	6: CastU256
	7: LdConst[2](u256: 1000..)
	8: Mul
	9: MoveLoc[1](Arg1: u64)
	10: CastU256
	11: Div
	12: Pack[0](Double)
	13: Ret
}

public from_scaled_val(Arg0: u256): Double {
B0:
	0: MoveLoc[0](Arg0: u256)
	1: Pack[0](Double)
	2: Ret
}

public to_scaled_val(Arg0: Double): u256 {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: Ret
}

public add(Arg0: Double, Arg1: Double): Double {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Add
	7: Pack[0](Double)
	8: Ret
}

public sub(Arg0: Double, Arg1: Double): Double {
B0:
	0: ImmBorrowLoc[1](Arg1: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[0](Arg0: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Gt
	7: BrFalse(9)
B1:
	8: Call err_subtrahend_too_large()
B2:
	9: ImmBorrowLoc[0](Arg0: Double)
	10: ImmBorrowField[0](Double.value: u256)
	11: ReadRef
	12: ImmBorrowLoc[1](Arg1: Double)
	13: ImmBorrowField[0](Double.value: u256)
	14: ReadRef
	15: Sub
	16: Pack[0](Double)
	17: Ret
}

public saturating_sub(Arg0: Double, Arg1: Double): Double {
L2:	loc0: Double
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Lt
	7: BrFalse(12)
B1:
	8: LdU256(0)
	9: Pack[0](Double)
	10: StLoc[2](loc0: Double)
	11: Branch(21)
B2:
	12: ImmBorrowLoc[0](Arg0: Double)
	13: ImmBorrowField[0](Double.value: u256)
	14: ReadRef
	15: ImmBorrowLoc[1](Arg1: Double)
	16: ImmBorrowField[0](Double.value: u256)
	17: ReadRef
	18: Sub
	19: Pack[0](Double)
	20: StLoc[2](loc0: Double)
B3:
	21: MoveLoc[2](loc0: Double)
	22: Ret
}

public mul(Arg0: Double, Arg1: Double): Double {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Mul
	7: LdConst[2](u256: 1000..)
	8: Div
	9: Pack[0](Double)
	10: Ret
}

public div(Arg0: Double, Arg1: Double): Double {
B0:
	0: CopyLoc[1](Arg1: Double)
	1: Call to_scaled_val(Double): u256
	2: LdU256(0)
	3: Eq
	4: BrFalse(6)
B1:
	5: Call err_divided_by_zero()
B2:
	6: ImmBorrowLoc[0](Arg0: Double)
	7: ImmBorrowField[0](Double.value: u256)
	8: ReadRef
	9: LdConst[2](u256: 1000..)
	10: Mul
	11: ImmBorrowLoc[1](Arg1: Double)
	12: ImmBorrowField[0](Double.value: u256)
	13: ReadRef
	14: Div
	15: Pack[0](Double)
	16: Ret
}

public add_u64(Arg0: Double, Arg1: u64): Double {
B0:
	0: MoveLoc[0](Arg0: Double)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Double
	3: Call add(Double, Double): Double
	4: Ret
}

public sub_u64(Arg0: Double, Arg1: u64): Double {
B0:
	0: MoveLoc[0](Arg0: Double)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Double
	3: Call sub(Double, Double): Double
	4: Ret
}

public saturating_sub_u64(Arg0: Double, Arg1: u64): Double {
B0:
	0: MoveLoc[0](Arg0: Double)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Double
	3: Call saturating_sub(Double, Double): Double
	4: Ret
}

public mul_u64(Arg0: Double, Arg1: u64): Double {
B0:
	0: MoveLoc[0](Arg0: Double)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Double
	3: Call mul(Double, Double): Double
	4: Ret
}

public div_u64(Arg0: Double, Arg1: u64): Double {
B0:
	0: MoveLoc[0](Arg0: Double)
	1: MoveLoc[1](Arg1: u64)
	2: Call from(u64): Double
	3: Call div(Double, Double): Double
	4: Ret
}

public pow(Arg0: Double, Arg1: u64): Double {
L2:	loc0: Double
L3:	loc1: Double
B0:
	0: MoveLoc[0](Arg0: Double)
	1: StLoc[2](loc0: Double)
	2: LdU64(1)
	3: Call from(u64): Double
	4: StLoc[3](loc1: Double)
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
	16: MoveLoc[3](loc1: Double)
	17: CopyLoc[2](loc0: Double)
	18: Call mul(Double, Double): Double
	19: StLoc[3](loc1: Double)
B5:
	20: CopyLoc[2](loc0: Double)
	21: MoveLoc[2](loc0: Double)
	22: Call mul(Double, Double): Double
	23: StLoc[2](loc0: Double)
	24: MoveLoc[1](Arg1: u64)
	25: LdU64(2)
	26: Div
	27: StLoc[1](Arg1: u64)
	28: Branch(5)
B6:
	29: MoveLoc[3](loc1: Double)
	30: Ret
}

public floor(Arg0: Double): u64 {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: LdConst[2](u256: 1000..)
	4: Div
	5: CastU64
	6: Ret
}

public ceil(Arg0: Double): u64 {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: LdConst[2](u256: 1000..)
	4: Add
	5: LdU256(1)
	6: Sub
	7: LdConst[2](u256: 1000..)
	8: Div
	9: CastU64
	10: Ret
}

public eq(Arg0: Double, Arg1: Double): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Eq
	7: Ret
}

public gt(Arg0: Double, Arg1: Double): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Gt
	7: Ret
}

public gte(Arg0: Double, Arg1: Double): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Ge
	7: Ret
}

public lt(Arg0: Double, Arg1: Double): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Lt
	7: Ret
}

public lte(Arg0: Double, Arg1: Double): bool {
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Le
	7: Ret
}

public min(Arg0: Double, Arg1: Double): Double {
L2:	loc0: Double
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Lt
	7: BrFalse(11)
B1:
	8: MoveLoc[0](Arg0: Double)
	9: StLoc[2](loc0: Double)
	10: Branch(13)
B2:
	11: MoveLoc[1](Arg1: Double)
	12: StLoc[2](loc0: Double)
B3:
	13: MoveLoc[2](loc0: Double)
	14: Ret
}

public max(Arg0: Double, Arg1: Double): Double {
L2:	loc0: Double
B0:
	0: ImmBorrowLoc[0](Arg0: Double)
	1: ImmBorrowField[0](Double.value: u256)
	2: ReadRef
	3: ImmBorrowLoc[1](Arg1: Double)
	4: ImmBorrowField[0](Double.value: u256)
	5: ReadRef
	6: Gt
	7: BrFalse(11)
B1:
	8: MoveLoc[0](Arg0: Double)
	9: StLoc[2](loc0: Double)
	10: Branch(13)
B2:
	11: MoveLoc[1](Arg1: Double)
	12: StLoc[2](loc0: Double)
B3:
	13: MoveLoc[2](loc0: Double)
	14: Ret
}

public wad(): u256 {
B0:
	0: LdConst[2](u256: 1000..)
	1: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u256: 1000000000000000000
]
}
