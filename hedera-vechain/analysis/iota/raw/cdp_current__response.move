// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.response {
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct UpdateResponse<phantom Ty0> {
	vault_id: ID,
	account: address,
	coll_amount: u64,
	debt_amount: u64,
	interest_amount: u64,
	witnesses: VecSet<TypeName>
}

err_witness_already_exists() {
B0:
	0: LdConst[0](u64: 301)
	1: Abort
}

public(friend) new<Ty0>(Arg0: ID, Arg1: address, Arg2: u64, Arg3: u64, Arg4: u64): UpdateResponse<Ty0> {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: MoveLoc[2](Arg2: u64)
	3: MoveLoc[3](Arg3: u64)
	4: MoveLoc[4](Arg4: u64)
	5: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	6: PackGeneric[0](UpdateResponse<Ty0>)
	7: Ret
}

public(friend) destroy<Ty0>(Arg0: UpdateResponse<Ty0>): ID * address * u64 * u64 * u64 * VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: UpdateResponse<Ty0>)
	1: UnpackGeneric[0](UpdateResponse<Ty0>)
	2: Ret
}

public add_witness<Ty0, Ty1: drop>(Arg0: &mut UpdateResponse<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut UpdateResponse<Ty0>)
	3: FreezeRef
	4: Call witnesses<Ty0>(&UpdateResponse<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_witness_already_exists()
B2:
	9: MoveLoc[0](Arg0: &mut UpdateResponse<Ty0>)
	10: MutBorrowFieldGeneric[0](UpdateResponse.witnesses: VecSet<TypeName>)
	11: Call type_name::get<Ty1>(): TypeName
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Ret
}

public vault_id<Ty0>(Arg0: &UpdateResponse<Ty0>): ID {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[1](UpdateResponse.vault_id: ID)
	2: ReadRef
	3: Ret
}

public account<Ty0>(Arg0: &UpdateResponse<Ty0>): address {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[2](UpdateResponse.account: address)
	2: ReadRef
	3: Ret
}

public coll_amount<Ty0>(Arg0: &UpdateResponse<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[3](UpdateResponse.coll_amount: u64)
	2: ReadRef
	3: Ret
}

public debt_amount<Ty0>(Arg0: &UpdateResponse<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[4](UpdateResponse.debt_amount: u64)
	2: ReadRef
	3: Ret
}

public interest_amount<Ty0>(Arg0: &UpdateResponse<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[5](UpdateResponse.interest_amount: u64)
	2: ReadRef
	3: Ret
}

public witnesses<Ty0>(Arg0: &UpdateResponse<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &UpdateResponse<Ty0>)
	1: ImmBorrowFieldGeneric[0](UpdateResponse.witnesses: VecSet<TypeName>)
	2: Ret
}

Constants [
	0 => u64: 301
]
}
