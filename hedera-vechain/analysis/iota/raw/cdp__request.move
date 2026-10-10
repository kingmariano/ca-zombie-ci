// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.request {
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::memo;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::version;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

struct RequestRules has key {
	id: UID,
	inner: VecSet<TypeName>
}

struct UpdateRequest<phantom Ty0> {
	vault_id: ID,
	account: address,
	deposit: Coin<Ty0>,
	borrow_amount: u64,
	repayment: Coin<VUSD>,
	withdraw_amount: u64,
	witnesses: VecSet<TypeName>,
	memo: String
}

err_witness_already_exists() {
B0:
	0: LdConst[0](u64: 201)
	1: Abort
}

err_invalid_request_rule() {
B0:
	0: LdConst[1](u64: 202)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	3: Pack[0](RequestRules)
	4: Call transfer::share_object<RequestRules>(RequestRules)
	5: Ret
}

public add_rule<Ty0: drop>(Arg0: &mut RequestRules, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut RequestRules)
	3: FreezeRef
	4: Call inner(&RequestRules): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut RequestRules)
	10: MutBorrowField[0](RequestRules.inner: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut RequestRules)
	15: Pop
B3:
	16: Ret
}

public remove_rule<Ty0: drop>(Arg0: &mut RequestRules, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut RequestRules)
	3: FreezeRef
	4: Call inner(&RequestRules): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(13)
B1:
	8: MoveLoc[0](Arg0: &mut RequestRules)
	9: MutBorrowField[0](RequestRules.inner: VecSet<TypeName>)
	10: ImmBorrowLoc[2](loc0: TypeName)
	11: Call vec_set::remove<TypeName>(&mut VecSet<TypeName>, &TypeName)
	12: Branch(15)
B2:
	13: MoveLoc[0](Arg0: &mut RequestRules)
	14: Pop
B3:
	15: Ret
}

public debtor_request<Ty0>(Arg0: &AccountRequest, Arg1: &Treasury, Arg2: ID, Arg3: Coin<Ty0>, Arg4: u64, Arg5: Coin<VUSD>, Arg6: u64): UpdateRequest<Ty0> {
B0:
	0: MoveLoc[1](Arg1: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: MoveLoc[2](Arg2: ID)
	3: MoveLoc[0](Arg0: &AccountRequest)
	4: Call account::request_address(&AccountRequest): address
	5: MoveLoc[3](Arg3: Coin<Ty0>)
	6: MoveLoc[4](Arg4: u64)
	7: MoveLoc[5](Arg5: Coin<VUSD>)
	8: MoveLoc[6](Arg6: u64)
	9: Call memo::manage(): String
	10: Call request_internal<Ty0>(ID, address, Coin<Ty0>, u64, Coin<VUSD>, u64, String): UpdateRequest<Ty0>
	11: Ret
}

public donor_request<Ty0>(Arg0: &Treasury, Arg1: ID, Arg2: address, Arg3: Coin<Ty0>, Arg4: Coin<VUSD>): UpdateRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: MoveLoc[1](Arg1: ID)
	3: MoveLoc[2](Arg2: address)
	4: MoveLoc[3](Arg3: Coin<Ty0>)
	5: LdU64(0)
	6: MoveLoc[4](Arg4: Coin<VUSD>)
	7: LdU64(0)
	8: Call memo::donate(): String
	9: Call request_internal<Ty0>(ID, address, Coin<Ty0>, u64, Coin<VUSD>, u64, String): UpdateRequest<Ty0>
	10: Ret
}

public rule_request<Ty0, Ty1: drop>(Arg0: &RequestRules, Arg1: Ty1, Arg2: &Treasury, Arg3: ID, Arg4: address, Arg5: Coin<Ty0>, Arg6: u64, Arg7: Coin<VUSD>, Arg8: u64, Arg9: String): UpdateRequest<Ty0> {
L10:	loc0: TypeName
B0:
	0: MoveLoc[2](Arg2: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: Call type_name::get<Ty1>(): TypeName
	3: StLoc[10](loc0: TypeName)
	4: MoveLoc[0](Arg0: &RequestRules)
	5: ImmBorrowField[0](RequestRules.inner: VecSet<TypeName>)
	6: ImmBorrowLoc[10](loc0: TypeName)
	7: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	8: Not
	9: BrFalse(11)
B1:
	10: Call err_invalid_request_rule()
B2:
	11: MoveLoc[3](Arg3: ID)
	12: MoveLoc[4](Arg4: address)
	13: MoveLoc[5](Arg5: Coin<Ty0>)
	14: MoveLoc[6](Arg6: u64)
	15: MoveLoc[7](Arg7: Coin<VUSD>)
	16: MoveLoc[8](Arg8: u64)
	17: MoveLoc[9](Arg9: String)
	18: Call request_internal<Ty0>(ID, address, Coin<Ty0>, u64, Coin<VUSD>, u64, String): UpdateRequest<Ty0>
	19: Ret
}

public add_witness<Ty0, Ty1: drop>(Arg0: &mut UpdateRequest<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut UpdateRequest<Ty0>)
	3: FreezeRef
	4: Call witnesses<Ty0>(&UpdateRequest<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_witness_already_exists()
B2:
	9: MoveLoc[0](Arg0: &mut UpdateRequest<Ty0>)
	10: MutBorrowFieldGeneric[0](UpdateRequest.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Ret
}

public(friend) destroy<Ty0>(Arg0: UpdateRequest<Ty0>): ID * address * Coin<Ty0> * u64 * Coin<VUSD> * u64 * VecSet<TypeName> * String {
B0:
	0: MoveLoc[0](Arg0: UpdateRequest<Ty0>)
	1: UnpackGeneric[0](UpdateRequest<Ty0>)
	2: Ret
}

public(friend) request_internal<Ty0>(Arg0: ID, Arg1: address, Arg2: Coin<Ty0>, Arg3: u64, Arg4: Coin<VUSD>, Arg5: u64, Arg6: String): UpdateRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: MoveLoc[2](Arg2: Coin<Ty0>)
	3: MoveLoc[3](Arg3: u64)
	4: MoveLoc[4](Arg4: Coin<VUSD>)
	5: MoveLoc[5](Arg5: u64)
	6: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	7: MoveLoc[6](Arg6: String)
	8: PackGeneric[0](UpdateRequest<Ty0>)
	9: Ret
}

public inner(Arg0: &RequestRules): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &RequestRules)
	1: ImmBorrowField[0](RequestRules.inner: VecSet<TypeName>)
	2: Ret
}

public vault_id<Ty0>(Arg0: &UpdateRequest<Ty0>): ID {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[1](UpdateRequest.vault_id: ID)
	2: ReadRef
	3: Ret
}

public account<Ty0>(Arg0: &UpdateRequest<Ty0>): address {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[2](UpdateRequest.account: address)
	2: ReadRef
	3: Ret
}

public deposit_amount<Ty0>(Arg0: &UpdateRequest<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[3](UpdateRequest.deposit: Coin<Ty0>)
	2: Call coin::value<Ty0>(&Coin<Ty0>): u64
	3: Ret
}

public repay_amount<Ty0>(Arg0: &UpdateRequest<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[4](UpdateRequest.repayment: Coin<VUSD>)
	2: Call coin::value<VUSD>(&Coin<VUSD>): u64
	3: Ret
}

public borrow_amount<Ty0>(Arg0: &UpdateRequest<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[5](UpdateRequest.borrow_amount: u64)
	2: ReadRef
	3: Ret
}

public withdraw_amount<Ty0>(Arg0: &UpdateRequest<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[6](UpdateRequest.withdraw_amount: u64)
	2: ReadRef
	3: Ret
}

public memo<Ty0>(Arg0: &UpdateRequest<Ty0>): String {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[7](UpdateRequest.memo: String)
	2: ReadRef
	3: Ret
}

public witnesses<Ty0>(Arg0: &UpdateRequest<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &UpdateRequest<Ty0>)
	1: ImmBorrowFieldGeneric[0](UpdateRequest.witnesses: VecSet<TypeName>)
	2: Ret
}

Constants [
	0 => u64: 201
	1 => u64: 202
]
}
