// Move bytecode v6
module a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8.sheet {
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;

struct Credit<phantom Ty0> has store {
	pos0: u64
}

struct Debt<phantom Ty0> has store {
	pos0: u64
}

struct Creditor has copy, drop, store {
	pos0: TypeName
}

struct Debtor has copy, drop, store {
	pos0: TypeName
}

struct Sheet<phantom Ty0, phantom Ty1> has store {
	credits: VecMap<Debtor, Credit<Ty1>>,
	debts: VecMap<Creditor, Debt<Ty1>>
}

struct Loan<phantom Ty0, phantom Ty1, phantom Ty2> {
	balance: Balance<Ty2>,
	credit: Option<Credit<Ty2>>,
	debt: Option<Debt<Ty2>>
}

struct Repayment<phantom Ty0, phantom Ty1, phantom Ty2> {
	balance: Balance<Ty2>,
	credit: Option<Credit<Ty2>>,
	debt: Option<Debt<Ty2>>
}

struct Collector<phantom Ty0, phantom Ty1, phantom Ty2> {
	requirement: u64,
	repayment: Option<Repayment<Ty0, Ty1, Ty2>>
}

public new<Ty0: drop, Ty1>(Arg0: Ty0): Sheet<Ty0, Ty1> {
B0:
	0: Call vec_map::empty<Debtor, Credit<Ty1>>(): VecMap<Debtor, Credit<Ty1>>
	1: Call vec_map::empty<Creditor, Debt<Ty1>>(): VecMap<Creditor, Debt<Ty1>>
	2: PackGeneric[0](Sheet<Ty0, Ty1>)
	3: Ret
}

public loan<Ty0: drop, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty2>, Arg1: Balance<Ty2>, Arg2: Ty0): Loan<Ty0, Ty1, Ty2> {
L3:	loc0: u64
L4:	loc1: Loan<Ty0, Ty1, Ty2>
B0:
	0: ImmBorrowLoc[1](Arg1: Balance<Ty2>)
	1: Call balance::value<Ty2>(&Balance<Ty2>): u64
	2: StLoc[3](loc0: u64)
	3: MoveLoc[1](Arg1: Balance<Ty2>)
	4: CopyLoc[3](loc0: u64)
	5: PackGeneric[1](Credit<Ty2>)
	6: Call option::some<Credit<Ty2>>(Credit<Ty2>): Option<Credit<Ty2>>
	7: MoveLoc[3](loc0: u64)
	8: PackGeneric[2](Debt<Ty2>)
	9: Call option::some<Debt<Ty2>>(Debt<Ty2>): Option<Debt<Ty2>>
	10: PackGeneric[3](Loan<Ty0, Ty1, Ty2>)
	11: StLoc[4](loc1: Loan<Ty0, Ty1, Ty2>)
	12: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	13: MutBorrowLoc[4](loc1: Loan<Ty0, Ty1, Ty2>)
	14: Call record_loan<Ty0, Ty1, Ty2>(&mut Sheet<Ty0, Ty2>, &mut Loan<Ty0, Ty1, Ty2>): u64
	15: Pop
	16: MoveLoc[4](loc1: Loan<Ty0, Ty1, Ty2>)
	17: Ret
}

public receive<Ty0, Ty1: drop, Ty2>(Arg0: &mut Sheet<Ty1, Ty2>, Arg1: Loan<Ty0, Ty1, Ty2>, Arg2: Ty1): Balance<Ty2> {
L3:	loc0: Balance<Ty2>
L4:	loc1: Option<Credit<Ty2>>
L5:	loc2: Option<Debt<Ty2>>
B0:
	0: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	1: MutBorrowLoc[1](Arg1: Loan<Ty0, Ty1, Ty2>)
	2: Call record_receive<Ty0, Ty1, Ty2>(&mut Sheet<Ty1, Ty2>, &mut Loan<Ty0, Ty1, Ty2>): u64
	3: Pop
	4: MoveLoc[1](Arg1: Loan<Ty0, Ty1, Ty2>)
	5: UnpackGeneric[3](Loan<Ty0, Ty1, Ty2>)
	6: StLoc[5](loc2: Option<Debt<Ty2>>)
	7: StLoc[4](loc1: Option<Credit<Ty2>>)
	8: StLoc[3](loc0: Balance<Ty2>)
	9: MoveLoc[4](loc1: Option<Credit<Ty2>>)
	10: Call option::destroy_none<Credit<Ty2>>(Option<Credit<Ty2>>)
	11: MoveLoc[5](loc2: Option<Debt<Ty2>>)
	12: Call option::destroy_none<Debt<Ty2>>(Option<Debt<Ty2>>)
	13: MoveLoc[3](loc0: Balance<Ty2>)
	14: Ret
}

public dun<Ty0: drop, Ty1, Ty2>(Arg0: u64, Arg1: Ty0): Collector<Ty0, Ty1, Ty2> {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: Call option::none<Repayment<Ty0, Ty1, Ty2>>(): Option<Repayment<Ty0, Ty1, Ty2>>
	2: PackGeneric[4](Collector<Ty0, Ty1, Ty2>)
	3: Ret
}

public repay<Ty0, Ty1: drop, Ty2>(Arg0: &mut Sheet<Ty1, Ty2>, Arg1: &mut Collector<Ty0, Ty1, Ty2>, Arg2: Balance<Ty2>, Arg3: Ty1) {
L4:	loc0: u64
L5:	loc1: Repayment<Ty0, Ty1, Ty2>
B0:
	0: CopyLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	1: ImmBorrowFieldGeneric[0](Collector.repayment: Option<Repayment<Ty0, Ty1, Ty2>>)
	2: Call option::is_none<Repayment<Ty0, Ty1, Ty2>>(&Option<Repayment<Ty0, Ty1, Ty2>>): bool
	3: BrFalse(5)
B1:
	4: Branch(11)
B2:
	5: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	6: Pop
	7: MoveLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	8: Pop
	9: LdU64(9223372457761570815)
	10: Abort
B3:
	11: ImmBorrowLoc[2](Arg2: Balance<Ty2>)
	12: Call balance::value<Ty2>(&Balance<Ty2>): u64
	13: StLoc[4](loc0: u64)
	14: MoveLoc[2](Arg2: Balance<Ty2>)
	15: CopyLoc[4](loc0: u64)
	16: PackGeneric[1](Credit<Ty2>)
	17: Call option::some<Credit<Ty2>>(Credit<Ty2>): Option<Credit<Ty2>>
	18: MoveLoc[4](loc0: u64)
	19: PackGeneric[2](Debt<Ty2>)
	20: Call option::some<Debt<Ty2>>(Debt<Ty2>): Option<Debt<Ty2>>
	21: PackGeneric[5](Repayment<Ty0, Ty1, Ty2>)
	22: StLoc[5](loc1: Repayment<Ty0, Ty1, Ty2>)
	23: CopyLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	24: MutBorrowFieldGeneric[0](Collector.repayment: Option<Repayment<Ty0, Ty1, Ty2>>)
	25: MoveLoc[5](loc1: Repayment<Ty0, Ty1, Ty2>)
	26: Call option::fill<Repayment<Ty0, Ty1, Ty2>>(&mut Option<Repayment<Ty0, Ty1, Ty2>>, Repayment<Ty0, Ty1, Ty2>)
	27: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	28: MoveLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	29: Call record_repay<Ty0, Ty1, Ty2>(&mut Sheet<Ty1, Ty2>, &mut Collector<Ty0, Ty1, Ty2>): u64
	30: Pop
	31: Ret
}

public collect<Ty0: drop, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty2>, Arg1: Collector<Ty0, Ty1, Ty2>, Arg2: Ty0): Balance<Ty2> {
L3:	loc0: Balance<Ty2>
L4:	loc1: Option<Credit<Ty2>>
L5:	loc2: Option<Debt<Ty2>>
L6:	loc3: Option<Repayment<Ty0, Ty1, Ty2>>
L7:	loc4: u64
B0:
	0: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	1: MutBorrowLoc[1](Arg1: Collector<Ty0, Ty1, Ty2>)
	2: Call record_collect<Ty0, Ty1, Ty2>(&mut Sheet<Ty0, Ty2>, &mut Collector<Ty0, Ty1, Ty2>): u64
	3: Pop
	4: MoveLoc[1](Arg1: Collector<Ty0, Ty1, Ty2>)
	5: UnpackGeneric[4](Collector<Ty0, Ty1, Ty2>)
	6: StLoc[6](loc3: Option<Repayment<Ty0, Ty1, Ty2>>)
	7: StLoc[7](loc4: u64)
	8: ImmBorrowLoc[6](loc3: Option<Repayment<Ty0, Ty1, Ty2>>)
	9: Call option::is_some<Repayment<Ty0, Ty1, Ty2>>(&Option<Repayment<Ty0, Ty1, Ty2>>): bool
	10: BrFalse(12)
B1:
	11: Branch(14)
B2:
	12: LdU64(9223372535070982143)
	13: Abort
B3:
	14: MoveLoc[6](loc3: Option<Repayment<Ty0, Ty1, Ty2>>)
	15: Call option::destroy_some<Repayment<Ty0, Ty1, Ty2>>(Option<Repayment<Ty0, Ty1, Ty2>>): Repayment<Ty0, Ty1, Ty2>
	16: UnpackGeneric[5](Repayment<Ty0, Ty1, Ty2>)
	17: StLoc[5](loc2: Option<Debt<Ty2>>)
	18: StLoc[4](loc1: Option<Credit<Ty2>>)
	19: StLoc[3](loc0: Balance<Ty2>)
	20: MoveLoc[4](loc1: Option<Credit<Ty2>>)
	21: Call option::destroy_none<Credit<Ty2>>(Option<Credit<Ty2>>)
	22: MoveLoc[5](loc2: Option<Debt<Ty2>>)
	23: Call option::destroy_none<Debt<Ty2>>(Option<Debt<Ty2>>)
	24: MoveLoc[7](loc4: u64)
	25: ImmBorrowLoc[3](loc0: Balance<Ty2>)
	26: Call balance::value<Ty2>(&Balance<Ty2>): u64
	27: Eq
	28: BrFalse(30)
B4:
	29: Branch(32)
B5:
	30: LdU64(9223372569430720511)
	31: Abort
B6:
	32: MoveLoc[3](loc0: Balance<Ty2>)
	33: Ret
}

record_loan<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty2>, Arg1: &mut Loan<Ty0, Ty1, Ty2>): u64 {
L2:	loc0: Credit<Ty2>
L3:	loc1: Debtor
B0:
	0: MoveLoc[1](Arg1: &mut Loan<Ty0, Ty1, Ty2>)
	1: MutBorrowFieldGeneric[1](Loan.credit: Option<Credit<Ty2>>)
	2: Call option::extract<Credit<Ty2>>(&mut Option<Credit<Ty2>>): Credit<Ty2>
	3: StLoc[2](loc0: Credit<Ty2>)
	4: Call debtor<Ty1>(): Debtor
	5: StLoc[3](loc1: Debtor)
	6: CopyLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	7: ImmBorrowFieldGeneric[2](Sheet.credits: VecMap<Debtor, Credit<Ty2>>)
	8: ImmBorrowLoc[3](loc1: Debtor)
	9: Call vec_map::contains<Debtor, Credit<Ty2>>(&VecMap<Debtor, Credit<Ty2>>, &Debtor): bool
	10: Not
	11: BrFalse(14)
B1:
	12: CopyLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	13: Call add_debtor<Ty0, Ty2, Ty1>(&mut Sheet<Ty0, Ty2>)
B2:
	14: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	15: MutBorrowFieldGeneric[2](Sheet.credits: VecMap<Debtor, Credit<Ty2>>)
	16: ImmBorrowLoc[3](loc1: Debtor)
	17: Call vec_map::get_mut<Debtor, Credit<Ty2>>(&mut VecMap<Debtor, Credit<Ty2>>, &Debtor): &mut Credit<Ty2>
	18: MoveLoc[2](loc0: Credit<Ty2>)
	19: Call add_credit<Ty2>(&mut Credit<Ty2>, Credit<Ty2>): u64
	20: Ret
}

record_receive<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty1, Ty2>, Arg1: &mut Loan<Ty0, Ty1, Ty2>): u64 {
L2:	loc0: Creditor
L3:	loc1: Debt<Ty2>
B0:
	0: MoveLoc[1](Arg1: &mut Loan<Ty0, Ty1, Ty2>)
	1: MutBorrowFieldGeneric[3](Loan.debt: Option<Debt<Ty2>>)
	2: Call option::extract<Debt<Ty2>>(&mut Option<Debt<Ty2>>): Debt<Ty2>
	3: StLoc[3](loc1: Debt<Ty2>)
	4: Call creditor<Ty0>(): Creditor
	5: StLoc[2](loc0: Creditor)
	6: CopyLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	7: ImmBorrowFieldGeneric[4](Sheet.debts: VecMap<Creditor, Debt<Ty2>>)
	8: ImmBorrowLoc[2](loc0: Creditor)
	9: Call vec_map::contains<Creditor, Debt<Ty2>>(&VecMap<Creditor, Debt<Ty2>>, &Creditor): bool
	10: Not
	11: BrFalse(14)
B1:
	12: CopyLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	13: Call add_creditor<Ty1, Ty2, Ty0>(&mut Sheet<Ty1, Ty2>)
B2:
	14: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	15: MutBorrowFieldGeneric[4](Sheet.debts: VecMap<Creditor, Debt<Ty2>>)
	16: ImmBorrowLoc[2](loc0: Creditor)
	17: Call vec_map::get_mut<Creditor, Debt<Ty2>>(&mut VecMap<Creditor, Debt<Ty2>>, &Creditor): &mut Debt<Ty2>
	18: MoveLoc[3](loc1: Debt<Ty2>)
	19: Call add_debt<Ty2>(&mut Debt<Ty2>, Debt<Ty2>): u64
	20: Ret
}

record_repay<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty1, Ty2>, Arg1: &mut Collector<Ty0, Ty1, Ty2>): u64 {
L2:	loc0: Creditor
L3:	loc1: Debt<Ty2>
B0:
	0: MoveLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	1: MutBorrowFieldGeneric[0](Collector.repayment: Option<Repayment<Ty0, Ty1, Ty2>>)
	2: Call option::borrow_mut<Repayment<Ty0, Ty1, Ty2>>(&mut Option<Repayment<Ty0, Ty1, Ty2>>): &mut Repayment<Ty0, Ty1, Ty2>
	3: MutBorrowFieldGeneric[5](Repayment.debt: Option<Debt<Ty2>>)
	4: Call option::extract<Debt<Ty2>>(&mut Option<Debt<Ty2>>): Debt<Ty2>
	5: StLoc[3](loc1: Debt<Ty2>)
	6: Call creditor<Ty0>(): Creditor
	7: StLoc[2](loc0: Creditor)
	8: CopyLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	9: ImmBorrowFieldGeneric[4](Sheet.debts: VecMap<Creditor, Debt<Ty2>>)
	10: ImmBorrowLoc[2](loc0: Creditor)
	11: Call vec_map::contains<Creditor, Debt<Ty2>>(&VecMap<Creditor, Debt<Ty2>>, &Creditor): bool
	12: BrFalse(14)
B1:
	13: Branch(18)
B2:
	14: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	15: Pop
	16: LdU64(9223372728344510463)
	17: Abort
B3:
	18: MoveLoc[0](Arg0: &mut Sheet<Ty1, Ty2>)
	19: MutBorrowFieldGeneric[4](Sheet.debts: VecMap<Creditor, Debt<Ty2>>)
	20: ImmBorrowLoc[2](loc0: Creditor)
	21: Call vec_map::get_mut<Creditor, Debt<Ty2>>(&mut VecMap<Creditor, Debt<Ty2>>, &Creditor): &mut Debt<Ty2>
	22: MoveLoc[3](loc1: Debt<Ty2>)
	23: Call sub_debt<Ty2>(&mut Debt<Ty2>, Debt<Ty2>): u64
	24: Ret
}

record_collect<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty2>, Arg1: &mut Collector<Ty0, Ty1, Ty2>): u64 {
L2:	loc0: Credit<Ty2>
L3:	loc1: Debtor
B0:
	0: MoveLoc[1](Arg1: &mut Collector<Ty0, Ty1, Ty2>)
	1: MutBorrowFieldGeneric[0](Collector.repayment: Option<Repayment<Ty0, Ty1, Ty2>>)
	2: Call option::borrow_mut<Repayment<Ty0, Ty1, Ty2>>(&mut Option<Repayment<Ty0, Ty1, Ty2>>): &mut Repayment<Ty0, Ty1, Ty2>
	3: MutBorrowFieldGeneric[6](Repayment.credit: Option<Credit<Ty2>>)
	4: Call option::extract<Credit<Ty2>>(&mut Option<Credit<Ty2>>): Credit<Ty2>
	5: StLoc[2](loc0: Credit<Ty2>)
	6: Call debtor<Ty1>(): Debtor
	7: StLoc[3](loc1: Debtor)
	8: CopyLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	9: ImmBorrowFieldGeneric[2](Sheet.credits: VecMap<Debtor, Credit<Ty2>>)
	10: ImmBorrowLoc[3](loc1: Debtor)
	11: Call vec_map::contains<Debtor, Credit<Ty2>>(&VecMap<Debtor, Credit<Ty2>>, &Debtor): bool
	12: BrFalse(14)
B1:
	13: Branch(18)
B2:
	14: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	15: Pop
	16: LdU64(9223372775589150719)
	17: Abort
B3:
	18: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty2>)
	19: MutBorrowFieldGeneric[2](Sheet.credits: VecMap<Debtor, Credit<Ty2>>)
	20: ImmBorrowLoc[3](loc1: Debtor)
	21: Call vec_map::get_mut<Debtor, Credit<Ty2>>(&mut VecMap<Debtor, Credit<Ty2>>, &Debtor): &mut Credit<Ty2>
	22: MoveLoc[2](loc0: Credit<Ty2>)
	23: Call sub_credit<Ty2>(&mut Credit<Ty2>, Credit<Ty2>): u64
	24: Ret
}

add_debtor<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty1>) {
B0:
	0: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[7](Sheet.credits: VecMap<Debtor, Credit<Ty1>>)
	2: Call debtor<Ty2>(): Debtor
	3: LdU64(0)
	4: PackGeneric[6](Credit<Ty1>)
	5: Call vec_map::insert<Debtor, Credit<Ty1>>(&mut VecMap<Debtor, Credit<Ty1>>, Debtor, Credit<Ty1>)
	6: Ret
}

add_creditor<Ty0, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty1>) {
B0:
	0: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[8](Sheet.debts: VecMap<Creditor, Debt<Ty1>>)
	2: Call creditor<Ty2>(): Creditor
	3: LdU64(0)
	4: PackGeneric[7](Debt<Ty1>)
	5: Call vec_map::insert<Creditor, Debt<Ty1>>(&mut VecMap<Creditor, Debt<Ty1>>, Creditor, Debt<Ty1>)
	6: Ret
}

public remove_debtor<Ty0: drop, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty1>, Arg1: Ty0) {
L2:	loc0: Credit<Ty1>
L3:	loc1: Debtor
B0:
	0: Call debtor<Ty2>(): Debtor
	1: StLoc[3](loc1: Debtor)
	2: CopyLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	3: ImmBorrowFieldGeneric[7](Sheet.credits: VecMap<Debtor, Credit<Ty1>>)
	4: ImmBorrowLoc[3](loc1: Debtor)
	5: Call vec_map::contains<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): bool
	6: BrFalse(8)
B1:
	7: Branch(12)
B2:
	8: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	9: Pop
	10: LdU64(9223372848603594751)
	11: Abort
B3:
	12: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	13: MutBorrowFieldGeneric[7](Sheet.credits: VecMap<Debtor, Credit<Ty1>>)
	14: ImmBorrowLoc[3](loc1: Debtor)
	15: Call vec_map::remove<Debtor, Credit<Ty1>>(&mut VecMap<Debtor, Credit<Ty1>>, &Debtor): Debtor * Credit<Ty1>
	16: StLoc[2](loc0: Credit<Ty1>)
	17: Pop
	18: MoveLoc[2](loc0: Credit<Ty1>)
	19: Call destroy_credit<Ty1>(Credit<Ty1>)
	20: Ret
}

public remove_creditor<Ty0: drop, Ty1, Ty2>(Arg0: &mut Sheet<Ty0, Ty1>, Arg1: Ty0) {
L2:	loc0: Creditor
L3:	loc1: Debt<Ty1>
B0:
	0: Call creditor<Ty2>(): Creditor
	1: StLoc[2](loc0: Creditor)
	2: CopyLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	3: ImmBorrowFieldGeneric[8](Sheet.debts: VecMap<Creditor, Debt<Ty1>>)
	4: ImmBorrowLoc[2](loc0: Creditor)
	5: Call vec_map::contains<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): bool
	6: BrFalse(8)
B1:
	7: Branch(12)
B2:
	8: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	9: Pop
	10: LdU64(9223372891553267711)
	11: Abort
B3:
	12: MoveLoc[0](Arg0: &mut Sheet<Ty0, Ty1>)
	13: MutBorrowFieldGeneric[8](Sheet.debts: VecMap<Creditor, Debt<Ty1>>)
	14: ImmBorrowLoc[2](loc0: Creditor)
	15: Call vec_map::remove<Creditor, Debt<Ty1>>(&mut VecMap<Creditor, Debt<Ty1>>, &Creditor): Creditor * Debt<Ty1>
	16: StLoc[3](loc1: Debt<Ty1>)
	17: Pop
	18: MoveLoc[3](loc1: Debt<Ty1>)
	19: Call destroy_debt<Ty1>(Debt<Ty1>)
	20: Ret
}

public loan_balance<Ty0, Ty1, Ty2>(Arg0: &Loan<Ty0, Ty1, Ty2>): &Balance<Ty2> {
B0:
	0: MoveLoc[0](Arg0: &Loan<Ty0, Ty1, Ty2>)
	1: ImmBorrowFieldGeneric[9](Loan.balance: Balance<Ty2>)
	2: Ret
}

public repayment_balance<Ty0, Ty1, Ty2>(Arg0: &Repayment<Ty0, Ty1, Ty2>): &Balance<Ty2> {
B0:
	0: MoveLoc[0](Arg0: &Repayment<Ty0, Ty1, Ty2>)
	1: ImmBorrowFieldGeneric[10](Repayment.balance: Balance<Ty2>)
	2: Ret
}

public repayment<Ty0, Ty1, Ty2>(Arg0: &Collector<Ty0, Ty1, Ty2>): &Option<Repayment<Ty0, Ty1, Ty2>> {
B0:
	0: MoveLoc[0](Arg0: &Collector<Ty0, Ty1, Ty2>)
	1: ImmBorrowFieldGeneric[0](Collector.repayment: Option<Repayment<Ty0, Ty1, Ty2>>)
	2: Ret
}

public requirement<Ty0, Ty1, Ty2>(Arg0: &Collector<Ty0, Ty1, Ty2>): u64 {
B0:
	0: MoveLoc[0](Arg0: &Collector<Ty0, Ty1, Ty2>)
	1: ImmBorrowFieldGeneric[11](Collector.requirement: u64)
	2: ReadRef
	3: Ret
}

public credits<Ty0, Ty1>(Arg0: &Sheet<Ty0, Ty1>): &VecMap<Debtor, Credit<Ty1>> {
B0:
	0: MoveLoc[0](Arg0: &Sheet<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[7](Sheet.credits: VecMap<Debtor, Credit<Ty1>>)
	2: Ret
}

public debts<Ty0, Ty1>(Arg0: &Sheet<Ty0, Ty1>): &VecMap<Creditor, Debt<Ty1>> {
B0:
	0: MoveLoc[0](Arg0: &Sheet<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[8](Sheet.debts: VecMap<Creditor, Debt<Ty1>>)
	2: Ret
}

public credit_value<Ty0>(Arg0: &Credit<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &Credit<Ty0>)
	1: ImmBorrowFieldGeneric[12](Credit.pos0: u64)
	2: ReadRef
	3: Ret
}

public debt_value<Ty0>(Arg0: &Debt<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &Debt<Ty0>)
	1: ImmBorrowFieldGeneric[13](Debt.pos0: u64)
	2: ReadRef
	3: Ret
}

public creditor<Ty0>(): Creditor {
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: Pack[2](Creditor)
	2: Ret
}

public debtor<Ty0>(): Debtor {
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: Pack[3](Debtor)
	2: Ret
}

add_credit<Ty0>(Arg0: &mut Credit<Ty0>, Arg1: Credit<Ty0>): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: MoveLoc[1](Arg1: Credit<Ty0>)
	1: UnpackGeneric[8](Credit<Ty0>)
	2: StLoc[3](loc1: u64)
	3: CopyLoc[0](Arg0: &mut Credit<Ty0>)
	4: ImmBorrowFieldGeneric[12](Credit.pos0: u64)
	5: ReadRef
	6: MoveLoc[3](loc1: u64)
	7: Add
	8: StLoc[2](loc0: u64)
	9: CopyLoc[2](loc0: u64)
	10: MoveLoc[0](Arg0: &mut Credit<Ty0>)
	11: MutBorrowFieldGeneric[12](Credit.pos0: u64)
	12: WriteRef
	13: MoveLoc[2](loc0: u64)
	14: Ret
}

sub_credit<Ty0>(Arg0: &mut Credit<Ty0>, Arg1: Credit<Ty0>): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: MoveLoc[1](Arg1: Credit<Ty0>)
	1: UnpackGeneric[8](Credit<Ty0>)
	2: StLoc[3](loc1: u64)
	3: CopyLoc[0](Arg0: &mut Credit<Ty0>)
	4: ImmBorrowFieldGeneric[12](Credit.pos0: u64)
	5: ReadRef
	6: CopyLoc[3](loc1: u64)
	7: Ge
	8: BrFalse(10)
B1:
	9: Branch(14)
B2:
	10: MoveLoc[0](Arg0: &mut Credit<Ty0>)
	11: Pop
	12: LdU64(9223373149251305471)
	13: Abort
B3:
	14: CopyLoc[0](Arg0: &mut Credit<Ty0>)
	15: ImmBorrowFieldGeneric[12](Credit.pos0: u64)
	16: ReadRef
	17: MoveLoc[3](loc1: u64)
	18: Sub
	19: StLoc[2](loc0: u64)
	20: CopyLoc[2](loc0: u64)
	21: MoveLoc[0](Arg0: &mut Credit<Ty0>)
	22: MutBorrowFieldGeneric[12](Credit.pos0: u64)
	23: WriteRef
	24: MoveLoc[2](loc0: u64)
	25: Ret
}

add_debt<Ty0>(Arg0: &mut Debt<Ty0>, Arg1: Debt<Ty0>): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: MoveLoc[1](Arg1: Debt<Ty0>)
	1: UnpackGeneric[9](Debt<Ty0>)
	2: StLoc[3](loc1: u64)
	3: CopyLoc[0](Arg0: &mut Debt<Ty0>)
	4: ImmBorrowFieldGeneric[13](Debt.pos0: u64)
	5: ReadRef
	6: MoveLoc[3](loc1: u64)
	7: Add
	8: StLoc[2](loc0: u64)
	9: CopyLoc[2](loc0: u64)
	10: MoveLoc[0](Arg0: &mut Debt<Ty0>)
	11: MutBorrowFieldGeneric[13](Debt.pos0: u64)
	12: WriteRef
	13: MoveLoc[2](loc0: u64)
	14: Ret
}

sub_debt<Ty0>(Arg0: &mut Debt<Ty0>, Arg1: Debt<Ty0>): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: MoveLoc[1](Arg1: Debt<Ty0>)
	1: UnpackGeneric[9](Debt<Ty0>)
	2: StLoc[3](loc1: u64)
	3: CopyLoc[0](Arg0: &mut Debt<Ty0>)
	4: ImmBorrowFieldGeneric[13](Debt.pos0: u64)
	5: ReadRef
	6: CopyLoc[3](loc1: u64)
	7: Ge
	8: BrFalse(10)
B1:
	9: Branch(14)
B2:
	10: MoveLoc[0](Arg0: &mut Debt<Ty0>)
	11: Pop
	12: LdU64(9223373213675814911)
	13: Abort
B3:
	14: CopyLoc[0](Arg0: &mut Debt<Ty0>)
	15: ImmBorrowFieldGeneric[13](Debt.pos0: u64)
	16: ReadRef
	17: MoveLoc[3](loc1: u64)
	18: Sub
	19: StLoc[2](loc0: u64)
	20: CopyLoc[2](loc0: u64)
	21: MoveLoc[0](Arg0: &mut Debt<Ty0>)
	22: MutBorrowFieldGeneric[13](Debt.pos0: u64)
	23: WriteRef
	24: MoveLoc[2](loc0: u64)
	25: Ret
}

destroy_credit<Ty0>(Arg0: Credit<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: Credit<Ty0>)
	1: UnpackGeneric[8](Credit<Ty0>)
	2: LdU64(0)
	3: Eq
	4: BrFalse(6)
B1:
	5: Branch(8)
B2:
	6: LdU64(9223373248035553279)
	7: Abort
B3:
	8: Ret
}

destroy_debt<Ty0>(Arg0: Debt<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: Debt<Ty0>)
	1: UnpackGeneric[9](Debt<Ty0>)
	2: LdU64(0)
	3: Eq
	4: BrFalse(6)
B1:
	5: Branch(8)
B2:
	6: LdU64(9223373269510389759)
	7: Abort
B3:
	8: Ret
}

}
