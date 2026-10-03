// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.pool {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::account;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::sheet;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::package;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;

struct DegenPool<phantom Ty0, phantom Ty1> has store, key {
	id: UID,
	balance: Balance<Ty1>,
	sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>
}

struct DEGEN_POOL<phantom Ty0> has drop {
	dummy_field: bool
}

struct StakeRequest<phantom Ty0> {
	pool_id: ID,
	account: address,
	amount: u64,
	asset_type: TypeName,
	witnesses: VecSet<TypeName>
}

struct UnstakeRequest<phantom Ty0> {
	pool_id: ID,
	account: address,
	amount: u64,
	asset_type: TypeName,
	witnesses: VecSet<TypeName>
}

struct StakeResponse<phantom Ty0> {
	pool_id: ID,
	account: address,
	amount: u64,
	asset_type: TypeName,
	witnesses: VecSet<TypeName>
}

struct UnstakeResponse<phantom Ty0> {
	pool_id: ID,
	account: address,
	amount: u64,
	asset_type: TypeName,
	witnesses: VecSet<TypeName>
}

struct POOL has drop {
	dummy_field: bool
}

err_stake_request_not_fulfilled() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_pool_balance_not_enough() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

err_invalid_debtor() {
B0:
	0: LdConst[2](u64: 2)
	1: Abort
}

err_request_already_handled() {
B0:
	0: LdConst[3](u64: 3)
	1: Abort
}

err_response_already_handled() {
B0:
	0: LdConst[4](u64: 4)
	1: Abort
}

err_wrong_pool_id() {
B0:
	0: LdConst[5](u64: 5)
	1: Abort
}

init(Arg0: POOL, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: POOL)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call package::claim_and_keep<POOL>(POOL, &mut TxContext)
	3: Ret
}

public(friend) new<Ty0, Ty1>(Arg0: &mut TxContext): DegenPool<Ty0, Ty1> {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call balance::zero<Ty1>(): Balance<Ty1>
	3: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	4: Call sheet::new<DEGEN_POOL<Ty0>, Ty1>(DEGEN_POOL<Ty0>): Sheet<DEGEN_POOL<Ty0>, Ty1>
	5: PackGeneric[0](DegenPool<Ty0, Ty1>)
	6: Ret
}

public(friend) destroy_stake_res<Ty0>(Arg0: StakeResponse<Ty0>): ID * address * u64 * TypeName {
B0:
	0: MoveLoc[0](Arg0: StakeResponse<Ty0>)
	1: UnpackGeneric[1](StakeResponse<Ty0>)
	2: Pop
	3: Ret
}

public(friend) destroy_unstake_res<Ty0>(Arg0: UnstakeResponse<Ty0>): ID * address * u64 * TypeName {
B0:
	0: MoveLoc[0](Arg0: UnstakeResponse<Ty0>)
	1: UnpackGeneric[2](UnstakeResponse<Ty0>)
	2: Pop
	3: Ret
}

public supply<Ty0, Ty1>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: Coin<Ty1>) {
B0:
	0: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	2: MoveLoc[1](Arg1: Coin<Ty1>)
	3: Call coin::into_balance<Ty1>(Coin<Ty1>): Balance<Ty1>
	4: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	5: Pop
	6: Ret
}

public request_stake<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>, Arg1: AccountRequest, Arg2: u64): StakeRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	2: MoveLoc[1](Arg1: AccountRequest)
	3: Call account::destroy(AccountRequest): address
	4: MoveLoc[2](Arg2: u64)
	5: Call type_name::get<Ty1>(): TypeName
	6: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	7: PackGeneric[3](StakeRequest<Ty0>)
	8: Ret
}

public fulfill_stake<Ty0, Ty1>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: StakeRequest<Ty0>, Arg2: Coin<Ty1>): StakeResponse<Ty0> {
L3:	loc0: address
L4:	loc1: u64
L5:	loc2: TypeName
L6:	loc3: ID
B0:
	0: MoveLoc[1](Arg1: StakeRequest<Ty0>)
	1: UnpackGeneric[3](StakeRequest<Ty0>)
	2: Pop
	3: StLoc[5](loc2: TypeName)
	4: StLoc[4](loc1: u64)
	5: StLoc[3](loc0: address)
	6: StLoc[6](loc3: ID)
	7: CopyLoc[6](loc3: ID)
	8: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	9: FreezeRef
	10: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	11: Neq
	12: BrFalse(14)
B1:
	13: Call err_wrong_pool_id()
B2:
	14: CopyLoc[4](loc1: u64)
	15: ImmBorrowLoc[2](Arg2: Coin<Ty1>)
	16: Call coin::value<Ty1>(&Coin<Ty1>): u64
	17: Neq
	18: BrFalse(20)
B3:
	19: Call err_stake_request_not_fulfilled()
B4:
	20: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	21: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	22: MoveLoc[2](Arg2: Coin<Ty1>)
	23: Call coin::into_balance<Ty1>(Coin<Ty1>): Balance<Ty1>
	24: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	25: Pop
	26: MoveLoc[6](loc3: ID)
	27: MoveLoc[3](loc0: address)
	28: MoveLoc[4](loc1: u64)
	29: MoveLoc[5](loc2: TypeName)
	30: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	31: PackGeneric[1](StakeResponse<Ty0>)
	32: Ret
}

public request_unstake<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>, Arg1: AccountRequest, Arg2: u64): UnstakeRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	2: MoveLoc[1](Arg1: AccountRequest)
	3: Call account::destroy(AccountRequest): address
	4: MoveLoc[2](Arg2: u64)
	5: Call type_name::get<Ty1>(): TypeName
	6: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	7: PackGeneric[4](UnstakeRequest<Ty0>)
	8: Ret
}

public fulfill_unstake<Ty0, Ty1>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: UnstakeRequest<Ty0>, Arg2: &mut TxContext): Coin<Ty1> * UnstakeResponse<Ty0> {
L3:	loc0: address
L4:	loc1: u64
L5:	loc2: TypeName
L6:	loc3: Coin<Ty1>
L7:	loc4: ID
L8:	loc5: UnstakeResponse<Ty0>
B0:
	0: MoveLoc[1](Arg1: UnstakeRequest<Ty0>)
	1: UnpackGeneric[4](UnstakeRequest<Ty0>)
	2: Pop
	3: StLoc[5](loc2: TypeName)
	4: StLoc[4](loc1: u64)
	5: StLoc[3](loc0: address)
	6: StLoc[7](loc4: ID)
	7: CopyLoc[7](loc4: ID)
	8: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	9: FreezeRef
	10: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	11: Neq
	12: BrFalse(14)
B1:
	13: Call err_wrong_pool_id()
B2:
	14: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	15: FreezeRef
	16: Call balance<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Balance<Ty1>
	17: Call balance::value<Ty1>(&Balance<Ty1>): u64
	18: CopyLoc[4](loc1: u64)
	19: Lt
	20: BrFalse(22)
B3:
	21: Call err_pool_balance_not_enough()
B4:
	22: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	23: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	24: CopyLoc[4](loc1: u64)
	25: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	26: MoveLoc[2](Arg2: &mut TxContext)
	27: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	28: StLoc[6](loc3: Coin<Ty1>)
	29: MoveLoc[7](loc4: ID)
	30: MoveLoc[3](loc0: address)
	31: MoveLoc[4](loc1: u64)
	32: MoveLoc[5](loc2: TypeName)
	33: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	34: PackGeneric[2](UnstakeResponse<Ty0>)
	35: StLoc[8](loc5: UnstakeResponse<Ty0>)
	36: MoveLoc[6](loc3: Coin<Ty1>)
	37: MoveLoc[8](loc5: UnstakeResponse<Ty0>)
	38: Ret
}

public loan_by_admin<Ty0, Ty1, Ty2>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: &AdminCap<Ty0>, Arg2: u64): Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>> {
L3:	loc0: Balance<Ty1>
L4:	loc1: Debtor
B0:
	0: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	2: MoveLoc[2](Arg2: u64)
	3: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	4: StLoc[3](loc0: Balance<Ty1>)
	5: Call sheet::debtor<Ty2>(): Debtor
	6: StLoc[4](loc1: Debtor)
	7: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	8: FreezeRef
	9: Call sheet<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1>
	10: Call sheet::credits<DEGEN_POOL<Ty0>, Ty1>(&Sheet<DEGEN_POOL<Ty0>, Ty1>): &VecMap<Debtor, Credit<Ty1>>
	11: ImmBorrowLoc[4](loc1: Debtor)
	12: Call vec_map::contains<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): bool
	13: Not
	14: BrFalse(19)
B1:
	15: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	16: MutBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	17: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	18: Call sheet::add_debtor<DEGEN_POOL<Ty0>, Ty1, Ty2>(&mut Sheet<DEGEN_POOL<Ty0>, Ty1>, DEGEN_POOL<Ty0>)
B2:
	19: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	20: MutBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	21: MoveLoc[3](loc0: Balance<Ty1>)
	22: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	23: Call sheet::loan<DEGEN_POOL<Ty0>, Ty2, Ty1>(&mut Sheet<DEGEN_POOL<Ty0>, Ty1>, Balance<Ty1>, DEGEN_POOL<Ty0>): Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>
	24: Call option::some<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>): Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	25: Ret
}

public loan_by_stake_res<Ty0, Ty1, Ty2>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: &mut StakeResponse<Ty0>): Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>> {
L2:	loc0: Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>
L3:	loc1: Balance<Ty1>
L4:	loc2: Debtor
L5:	loc3: TypeName
B0:
	0: Call type_name::get<DEGEN_POOL<Ty0>>(): TypeName
	1: StLoc[5](loc3: TypeName)
	2: CopyLoc[1](Arg1: &mut StakeResponse<Ty0>)
	3: FreezeRef
	4: Call stake_res_witness<Ty0>(&StakeResponse<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[5](loc3: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_response_already_handled()
B2:
	9: CopyLoc[1](Arg1: &mut StakeResponse<Ty0>)
	10: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	11: Call stake_res_add_witness<Ty0, DEGEN_POOL<Ty0>>(&mut StakeResponse<Ty0>, DEGEN_POOL<Ty0>)
	12: Call sheet::debtor<Ty2>(): Debtor
	13: StLoc[4](loc2: Debtor)
	14: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	15: FreezeRef
	16: Call sheet<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1>
	17: Call sheet::credits<DEGEN_POOL<Ty0>, Ty1>(&Sheet<DEGEN_POOL<Ty0>, Ty1>): &VecMap<Debtor, Credit<Ty1>>
	18: ImmBorrowLoc[4](loc2: Debtor)
	19: Call vec_map::contains<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): bool
	20: Not
	21: BrFalse(23)
B3:
	22: Call err_invalid_debtor()
B4:
	23: CopyLoc[1](Arg1: &mut StakeResponse<Ty0>)
	24: ImmBorrowFieldGeneric[2](StakeResponse.amount: u64)
	25: ReadRef
	26: LdU64(10)
	27: Gt
	28: BrFalse(44)
B5:
	29: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	30: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	31: MoveLoc[1](Arg1: &mut StakeResponse<Ty0>)
	32: ImmBorrowFieldGeneric[2](StakeResponse.amount: u64)
	33: ReadRef
	34: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	35: StLoc[3](loc1: Balance<Ty1>)
	36: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	37: MutBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	38: MoveLoc[3](loc1: Balance<Ty1>)
	39: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	40: Call sheet::loan<DEGEN_POOL<Ty0>, Ty2, Ty1>(&mut Sheet<DEGEN_POOL<Ty0>, Ty1>, Balance<Ty1>, DEGEN_POOL<Ty0>): Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>
	41: Call option::some<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>): Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	42: StLoc[2](loc0: Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	43: Branch(50)
B6:
	44: MoveLoc[1](Arg1: &mut StakeResponse<Ty0>)
	45: Pop
	46: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	47: Pop
	48: Call option::none<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>(): Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	49: StLoc[2](loc0: Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
B7:
	50: MoveLoc[2](loc0: Option<Loan<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	51: Ret
}

public dun_by_admin<Ty0, Ty1, Ty2>(Arg0: &AdminCap<Ty0>, Arg1: u64): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>> {
B0:
	0: MoveLoc[1](Arg1: u64)
	1: LdFalse
	2: PackGeneric[5](DEGEN_POOL<Ty0>)
	3: Call sheet::dun<DEGEN_POOL<Ty0>, Ty2, Ty1>(u64, DEGEN_POOL<Ty0>): Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>
	4: Call option::some<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	5: Ret
}

public dun_by_unstake_req<Ty0, Ty1, Ty2>(Arg0: &DegenPool<Ty0, Ty1>, Arg1: &mut UnstakeRequest<Ty0>): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>> {
L2:	loc0: bool
L3:	loc1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>
L4:	loc2: Debtor
L5:	loc3: u64
L6:	loc4: TypeName
B0:
	0: Call type_name::get<DEGEN_POOL<Ty0>>(): TypeName
	1: StLoc[6](loc4: TypeName)
	2: CopyLoc[1](Arg1: &mut UnstakeRequest<Ty0>)
	3: FreezeRef
	4: Call unstake_req_witness<Ty0>(&UnstakeRequest<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[6](loc4: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_request_already_handled()
B2:
	9: CopyLoc[1](Arg1: &mut UnstakeRequest<Ty0>)
	10: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	11: Call unstake_req_add_witness<Ty0, DEGEN_POOL<Ty0>>(&mut UnstakeRequest<Ty0>, DEGEN_POOL<Ty0>)
	12: CopyLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	13: Call balance<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Balance<Ty1>
	14: Call balance::value<Ty1>(&Balance<Ty1>): u64
	15: CopyLoc[1](Arg1: &mut UnstakeRequest<Ty0>)
	16: ImmBorrowFieldGeneric[3](UnstakeRequest.amount: u64)
	17: ReadRef
	18: Ge
	19: BrFalse(26)
B3:
	20: MoveLoc[1](Arg1: &mut UnstakeRequest<Ty0>)
	21: Pop
	22: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	23: Pop
	24: Call option::none<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	25: Ret
B4:
	26: MoveLoc[1](Arg1: &mut UnstakeRequest<Ty0>)
	27: ImmBorrowFieldGeneric[3](UnstakeRequest.amount: u64)
	28: ReadRef
	29: CopyLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	30: Call balance<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Balance<Ty1>
	31: Call balance::value<Ty1>(&Balance<Ty1>): u64
	32: Sub
	33: StLoc[5](loc3: u64)
	34: Call sheet::debtor<Ty2>(): Debtor
	35: StLoc[4](loc2: Debtor)
	36: CopyLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	37: Call sheet<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1>
	38: Call sheet::credits<DEGEN_POOL<Ty0>, Ty1>(&Sheet<DEGEN_POOL<Ty0>, Ty1>): &VecMap<Debtor, Credit<Ty1>>
	39: ImmBorrowLoc[4](loc2: Debtor)
	40: Call vec_map::contains<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): bool
	41: BrFalse(52)
B5:
	42: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	43: Call sheet<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1>
	44: Call sheet::credits<DEGEN_POOL<Ty0>, Ty1>(&Sheet<DEGEN_POOL<Ty0>, Ty1>): &VecMap<Debtor, Credit<Ty1>>
	45: ImmBorrowLoc[4](loc2: Debtor)
	46: Call vec_map::get<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): &Credit<Ty1>
	47: Call sheet::credit_value<Ty1>(&Credit<Ty1>): u64
	48: CopyLoc[5](loc3: u64)
	49: Ge
	50: StLoc[2](loc0: bool)
	51: Branch(56)
B6:
	52: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	53: Pop
	54: LdFalse
	55: StLoc[2](loc0: bool)
B7:
	56: MoveLoc[2](loc0: bool)
	57: BrFalse(64)
B8:
	58: MoveLoc[5](loc3: u64)
	59: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	60: Call sheet::dun<DEGEN_POOL<Ty0>, Ty2, Ty1>(u64, DEGEN_POOL<Ty0>): Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>
	61: Call option::some<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	62: StLoc[3](loc1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	63: Branch(66)
B9:
	64: Call option::none<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(): Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>
	65: StLoc[3](loc1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
B10:
	66: MoveLoc[3](loc1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	67: Ret
}

public collect<Ty0, Ty1, Ty2>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>) {
L2:	loc0: Balance<Ty1>
L3:	loc1: Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>
B0:
	0: ImmBorrowLoc[1](Arg1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	1: Call option::is_some<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(&Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>): bool
	2: BrFalse(18)
B1:
	3: MoveLoc[1](Arg1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	4: Call option::destroy_some<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>): Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>
	5: StLoc[3](loc1: Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>)
	6: CopyLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	7: MutBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	8: MoveLoc[3](loc1: Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>)
	9: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	10: Call sheet::collect<DEGEN_POOL<Ty0>, Ty2, Ty1>(&mut Sheet<DEGEN_POOL<Ty0>, Ty1>, Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>, DEGEN_POOL<Ty0>): Balance<Ty1>
	11: StLoc[2](loc0: Balance<Ty1>)
	12: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	13: MutBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	14: MoveLoc[2](loc0: Balance<Ty1>)
	15: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	16: Pop
	17: Branch(22)
B2:
	18: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	19: Pop
	20: MoveLoc[1](Arg1: Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
	21: Call option::destroy_none<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>(Option<Collector<DEGEN_POOL<Ty0>, Ty2, Ty1>>)
B3:
	22: Ret
}

public remove_debtor<Ty0, Ty1, Ty2>(Arg0: &mut DegenPool<Ty0, Ty1>, Arg1: &AdminCap<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: &mut DegenPool<Ty0, Ty1>)
	1: MutBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	2: Call stamp<Ty0>(): DEGEN_POOL<Ty0>
	3: Call sheet::remove_debtor<DEGEN_POOL<Ty0>, Ty1, Ty2>(&mut Sheet<DEGEN_POOL<Ty0>, Ty1>, DEGEN_POOL<Ty0>)
	4: Ret
}

public stake_req_add_witness<Ty0, Ty1: drop>(Arg0: &mut StakeRequest<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut StakeRequest<Ty0>)
	3: FreezeRef
	4: Call stake_req_witness<Ty0>(&StakeRequest<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut StakeRequest<Ty0>)
	10: MutBorrowFieldGeneric[4](StakeRequest.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut StakeRequest<Ty0>)
	15: Pop
B3:
	16: Ret
}

public stake_req_witness<Ty0>(Arg0: &StakeRequest<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &StakeRequest<Ty0>)
	1: ImmBorrowFieldGeneric[4](StakeRequest.witnesses: VecSet<TypeName>)
	2: Ret
}

public unstake_req_add_witness<Ty0, Ty1: drop>(Arg0: &mut UnstakeRequest<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut UnstakeRequest<Ty0>)
	3: FreezeRef
	4: Call unstake_req_witness<Ty0>(&UnstakeRequest<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut UnstakeRequest<Ty0>)
	10: MutBorrowFieldGeneric[5](UnstakeRequest.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut UnstakeRequest<Ty0>)
	15: Pop
B3:
	16: Ret
}

public unstake_req_witness<Ty0>(Arg0: &UnstakeRequest<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &UnstakeRequest<Ty0>)
	1: ImmBorrowFieldGeneric[5](UnstakeRequest.witnesses: VecSet<TypeName>)
	2: Ret
}

public stake_res_add_witness<Ty0, Ty1: drop>(Arg0: &mut StakeResponse<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut StakeResponse<Ty0>)
	3: FreezeRef
	4: Call stake_res_witness<Ty0>(&StakeResponse<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut StakeResponse<Ty0>)
	10: MutBorrowFieldGeneric[6](StakeResponse.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut StakeResponse<Ty0>)
	15: Pop
B3:
	16: Ret
}

public stake_res_witness<Ty0>(Arg0: &StakeResponse<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &StakeResponse<Ty0>)
	1: ImmBorrowFieldGeneric[6](StakeResponse.witnesses: VecSet<TypeName>)
	2: Ret
}

public unstake_res_add_witness<Ty0, Ty1: drop>(Arg0: &mut UnstakeResponse<Ty0>, Arg1: Ty1) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut UnstakeResponse<Ty0>)
	3: FreezeRef
	4: Call unstake_res_witness<Ty0>(&UnstakeResponse<Ty0>): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut UnstakeResponse<Ty0>)
	10: MutBorrowFieldGeneric[7](UnstakeResponse.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut UnstakeResponse<Ty0>)
	15: Pop
B3:
	16: Ret
}

public unstake_res_witness<Ty0>(Arg0: &UnstakeResponse<Ty0>): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &UnstakeResponse<Ty0>)
	1: ImmBorrowFieldGeneric[7](UnstakeResponse.witnesses: VecSet<TypeName>)
	2: Ret
}

public stake_req_data<Ty0>(Arg0: &StakeRequest<Ty0>): ID * address * u64 * TypeName {
B0:
	0: CopyLoc[0](Arg0: &StakeRequest<Ty0>)
	1: ImmBorrowFieldGeneric[8](StakeRequest.pool_id: ID)
	2: ReadRef
	3: CopyLoc[0](Arg0: &StakeRequest<Ty0>)
	4: ImmBorrowFieldGeneric[9](StakeRequest.account: address)
	5: ReadRef
	6: CopyLoc[0](Arg0: &StakeRequest<Ty0>)
	7: ImmBorrowFieldGeneric[10](StakeRequest.amount: u64)
	8: ReadRef
	9: MoveLoc[0](Arg0: &StakeRequest<Ty0>)
	10: ImmBorrowFieldGeneric[11](StakeRequest.asset_type: TypeName)
	11: ReadRef
	12: Ret
}

public unstake_req_data<Ty0>(Arg0: &UnstakeRequest<Ty0>): ID * address * u64 * TypeName {
B0:
	0: CopyLoc[0](Arg0: &UnstakeRequest<Ty0>)
	1: ImmBorrowFieldGeneric[12](UnstakeRequest.pool_id: ID)
	2: ReadRef
	3: CopyLoc[0](Arg0: &UnstakeRequest<Ty0>)
	4: ImmBorrowFieldGeneric[13](UnstakeRequest.account: address)
	5: ReadRef
	6: CopyLoc[0](Arg0: &UnstakeRequest<Ty0>)
	7: ImmBorrowFieldGeneric[3](UnstakeRequest.amount: u64)
	8: ReadRef
	9: MoveLoc[0](Arg0: &UnstakeRequest<Ty0>)
	10: ImmBorrowFieldGeneric[14](UnstakeRequest.asset_type: TypeName)
	11: ReadRef
	12: Ret
}

public stake_res_data<Ty0>(Arg0: &StakeResponse<Ty0>): ID * address * u64 * TypeName {
B0:
	0: CopyLoc[0](Arg0: &StakeResponse<Ty0>)
	1: ImmBorrowFieldGeneric[15](StakeResponse.pool_id: ID)
	2: ReadRef
	3: CopyLoc[0](Arg0: &StakeResponse<Ty0>)
	4: ImmBorrowFieldGeneric[16](StakeResponse.account: address)
	5: ReadRef
	6: CopyLoc[0](Arg0: &StakeResponse<Ty0>)
	7: ImmBorrowFieldGeneric[2](StakeResponse.amount: u64)
	8: ReadRef
	9: MoveLoc[0](Arg0: &StakeResponse<Ty0>)
	10: ImmBorrowFieldGeneric[17](StakeResponse.asset_type: TypeName)
	11: ReadRef
	12: Ret
}

public unstake_res_data<Ty0>(Arg0: &UnstakeResponse<Ty0>): ID * address * u64 * TypeName {
B0:
	0: CopyLoc[0](Arg0: &UnstakeResponse<Ty0>)
	1: ImmBorrowFieldGeneric[18](UnstakeResponse.pool_id: ID)
	2: ReadRef
	3: CopyLoc[0](Arg0: &UnstakeResponse<Ty0>)
	4: ImmBorrowFieldGeneric[19](UnstakeResponse.account: address)
	5: ReadRef
	6: CopyLoc[0](Arg0: &UnstakeResponse<Ty0>)
	7: ImmBorrowFieldGeneric[20](UnstakeResponse.amount: u64)
	8: ReadRef
	9: MoveLoc[0](Arg0: &UnstakeResponse<Ty0>)
	10: ImmBorrowFieldGeneric[21](UnstakeResponse.asset_type: TypeName)
	11: ReadRef
	12: Ret
}

public balance<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>): &Balance<Ty1> {
B0:
	0: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[0](DegenPool.balance: Balance<Ty1>)
	2: Ret
}

public sheet<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1> {
B0:
	0: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: ImmBorrowFieldGeneric[1](DegenPool.sheet: Sheet<DEGEN_POOL<Ty0>, Ty1>)
	2: Ret
}

public credit_value<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>): u64 {
L1:	loc0: u64
L2:	loc1: u64
L3:	loc2: vector<Debtor>
L4:	loc3: u64
L5:	loc4: &mut vector<u64>
L6:	loc5: u64
L7:	loc6: &VecMap<Debtor, Credit<Ty1>>
L8:	loc7: &Debtor
L9:	loc8: &Debtor
L10:	loc9: u64
L11:	loc10: u64
L12:	loc11: u64
L13:	loc12: u64
L14:	loc13: vector<u64>
L15:	loc14: u64
L16:	loc15: u64
L17:	loc16: u64
L18:	loc17: &vector<Debtor>
L19:	loc18: vector<u64>
L20:	loc19: vector<u64>
L21:	loc20: u64
L22:	loc21: &vector<Debtor>
B0:
	0: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: Call sheet<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Sheet<DEGEN_POOL<Ty0>, Ty1>
	2: Call sheet::credits<DEGEN_POOL<Ty0>, Ty1>(&Sheet<DEGEN_POOL<Ty0>, Ty1>): &VecMap<Debtor, Credit<Ty1>>
	3: StLoc[7](loc6: &VecMap<Debtor, Credit<Ty1>>)
	4: CopyLoc[7](loc6: &VecMap<Debtor, Credit<Ty1>>)
	5: Call vec_map::keys<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>): vector<Debtor>
	6: StLoc[3](loc2: vector<Debtor>)
	7: ImmBorrowLoc[3](loc2: vector<Debtor>)
	8: StLoc[18](loc17: &vector<Debtor>)
	9: LdConst[6](vector<u64>: 00)
	10: StLoc[14](loc13: vector<u64>)
	11: MoveLoc[18](loc17: &vector<Debtor>)
	12: StLoc[22](loc21: &vector<Debtor>)
	13: CopyLoc[22](loc21: &vector<Debtor>)
	14: VecLen(61)
	15: StLoc[2](loc1: u64)
	16: LdU64(0)
	17: StLoc[13](loc12: u64)
	18: MoveLoc[2](loc1: u64)
	19: StLoc[16](loc15: u64)
B1:
	20: CopyLoc[13](loc12: u64)
	21: CopyLoc[16](loc15: u64)
	22: Lt
	23: BrFalse(47)
B2:
	24: CopyLoc[13](loc12: u64)
	25: StLoc[11](loc10: u64)
	26: CopyLoc[22](loc21: &vector<Debtor>)
	27: MoveLoc[11](loc10: u64)
	28: VecImmBorrow(61)
	29: StLoc[9](loc8: &Debtor)
	30: MutBorrowLoc[14](loc13: vector<u64>)
	31: StLoc[5](loc4: &mut vector<u64>)
	32: MoveLoc[9](loc8: &Debtor)
	33: StLoc[8](loc7: &Debtor)
	34: CopyLoc[7](loc6: &VecMap<Debtor, Credit<Ty1>>)
	35: MoveLoc[8](loc7: &Debtor)
	36: Call vec_map::get<Debtor, Credit<Ty1>>(&VecMap<Debtor, Credit<Ty1>>, &Debtor): &Credit<Ty1>
	37: Call sheet::credit_value<Ty1>(&Credit<Ty1>): u64
	38: StLoc[4](loc3: u64)
	39: MoveLoc[5](loc4: &mut vector<u64>)
	40: MoveLoc[4](loc3: u64)
	41: VecPushBack(34)
	42: MoveLoc[13](loc12: u64)
	43: LdU64(1)
	44: Add
	45: StLoc[13](loc12: u64)
	46: Branch(20)
B3:
	47: MoveLoc[22](loc21: &vector<Debtor>)
	48: Pop
	49: MoveLoc[7](loc6: &VecMap<Debtor, Credit<Ty1>>)
	50: Pop
	51: MoveLoc[14](loc13: vector<u64>)
	52: StLoc[19](loc18: vector<u64>)
	53: LdU64(0)
	54: StLoc[6](loc5: u64)
	55: MoveLoc[19](loc18: vector<u64>)
	56: StLoc[20](loc19: vector<u64>)
	57: MutBorrowLoc[20](loc19: vector<u64>)
	58: Call vector::reverse<u64>(&mut vector<u64>)
	59: ImmBorrowLoc[20](loc19: vector<u64>)
	60: VecLen(34)
	61: StLoc[1](loc0: u64)
	62: LdU64(0)
	63: StLoc[12](loc11: u64)
	64: MoveLoc[1](loc0: u64)
	65: StLoc[15](loc14: u64)
B4:
	66: CopyLoc[12](loc11: u64)
	67: CopyLoc[15](loc14: u64)
	68: Lt
	69: BrFalse(88)
B5:
	70: CopyLoc[12](loc11: u64)
	71: Pop
	72: MutBorrowLoc[20](loc19: vector<u64>)
	73: VecPopBack(34)
	74: StLoc[10](loc9: u64)
	75: MoveLoc[6](loc5: u64)
	76: StLoc[17](loc16: u64)
	77: MoveLoc[10](loc9: u64)
	78: StLoc[21](loc20: u64)
	79: MoveLoc[17](loc16: u64)
	80: MoveLoc[21](loc20: u64)
	81: Add
	82: StLoc[6](loc5: u64)
	83: MoveLoc[12](loc11: u64)
	84: LdU64(1)
	85: Add
	86: StLoc[12](loc11: u64)
	87: Branch(66)
B6:
	88: MoveLoc[20](loc19: vector<u64>)
	89: VecUnpack(34, 0)
	90: MoveLoc[6](loc5: u64)
	91: Ret
}

public total_value<Ty0, Ty1>(Arg0: &DegenPool<Ty0, Ty1>): u64 {
B0:
	0: CopyLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	1: Call balance<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): &Balance<Ty1>
	2: Call balance::value<Ty1>(&Balance<Ty1>): u64
	3: MoveLoc[0](Arg0: &DegenPool<Ty0, Ty1>)
	4: Call credit_value<Ty0, Ty1>(&DegenPool<Ty0, Ty1>): u64
	5: Add
	6: Ret
}

stamp<Ty0>(): DEGEN_POOL<Ty0> {
B0:
	0: LdFalse
	1: PackGeneric[5](DEGEN_POOL<Ty0>)
	2: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u64: 2
	3 => u64: 3
	4 => u64: 4
	5 => u64: 5
	6 => vector<u64>: 00
]
}
