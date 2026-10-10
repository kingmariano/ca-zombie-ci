// Move bytecode v6
module c7ab9b9353e23c6a3a15181eb51bf7145ddeff1a5642280394cd4d6a0d37d83b.stability_pool {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_field;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use c7ab9b9353e23c6a3a15181eb51bf7145ddeff1a5642280394cd4d6a0d37d83b::balance_number;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::memo;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::request;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::response;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::vault;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::linked_table;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::result;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

struct Deposit has copy, drop {
	amount: u64
}

struct Withdraw has copy, drop {
	amount: u64,
	for_liquidation: bool
}

struct Liquidation<phantom Ty0> has copy, drop {
	price_n: u64,
	price_m: u64,
	coll_amount: u64,
	debt_amount: u64,
	debtor: address
}

struct StabilityPoolRule has drop {
	dummy_field: bool
}

struct Position has store {
	vusd_balance: BalanceNumber,
	coll_balances: VecMap<TypeName, BalanceNumber>,
	timestamp: u64
}

struct PositionResponse {
	account: address,
	vusd_balance: u64,
	timestamp: u64,
	witnesses: VecSet<TypeName>
}

struct FunderRecipit<phantom Ty0> {
	funder: address,
	vusd_out: u64,
	update_req: UpdateRequest<Ty0>
}

struct StabilityPool has key {
	id: UID,
	vusd_balance: Balance<VUSD>,
	position_table: LinkedTable<address, Position>,
	liquidator: address,
	response_checklist: vector<TypeName>,
	fee_rate: Float,
	rebate_rate: Float
}

struct PositionData has copy, drop {
	account: address,
	vusd_balance: u64,
	coll_types: vector<TypeName>,
	coll_amounts: vector<u64>,
	timestamp: u64
}

struct PositionUpdateResponse {
	account: address,
	pool_vusd_balance_before: u64,
	pool_vusd_balance_after: u64,
	position_vusd_balance_before: u64,
	position_vusd_balance_after: u64,
	timestamp: u64,
	witnesses: VecSet<TypeName>
}

err_missing_response_witness() {
B0:
	0: LdConst[0](u64: 201)
	1: Abort
}

err_witness_already_exists() {
B0:
	0: LdConst[1](u64: 202)
	1: Abort
}

err_sender_not_liquidator() {
B0:
	0: LdConst[2](u64: 203)
	1: Abort
}

err_invalid_update_request() {
B0:
	0: LdConst[3](u64: 204)
	1: Abort
}

err_invalid_funder_recipit() {
B0:
	0: LdConst[4](u64: 205)
	1: Abort
}

err_cannot_instantly_withdraw() {
B0:
	0: LdConst[5](u64: 206)
	1: Abort
}

err_account_not_found() {
B0:
	0: LdConst[6](u64: 207)
	1: Abort
}

err_position_is_healthy() {
B0:
	0: LdConst[7](u64: 208)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call balance::zero<VUSD>(): Balance<VUSD>
	3: CopyLoc[0](Arg0: &mut TxContext)
	4: Call linked_table::new<address, Position>(&mut TxContext): LinkedTable<address, Position>
	5: MoveLoc[0](Arg0: &mut TxContext)
	6: FreezeRef
	7: Call tx_context::sender(&TxContext): address
	8: VecPack(51, 0)
	9: LdU8(2)
	10: Call float::from_percent(u8): Float
	11: LdU64(50)
	12: Call float::from_bps(u64): Float
	13: Pack[7](StabilityPool)
	14: Call transfer::share_object<StabilityPool>(StabilityPool)
	15: Ret
}

public set_liquidator(Arg0: &mut StabilityPool, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[2](Arg2: address)
	1: MoveLoc[0](Arg0: &mut StabilityPool)
	2: MutBorrowField[0](StabilityPool.liquidator: address)
	3: WriteRef
	4: Ret
}

public add_response_check<Ty0: drop>(Arg0: &mut StabilityPool, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut StabilityPool)
	3: ImmBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	4: ImmBorrowLoc[2](loc0: TypeName)
	5: Call vector::contains<TypeName>(&vector<TypeName>, &TypeName): bool
	6: Not
	7: BrFalse(13)
B1:
	8: MoveLoc[0](Arg0: &mut StabilityPool)
	9: MutBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	10: MoveLoc[2](loc0: TypeName)
	11: VecPushBack(51)
	12: Branch(15)
B2:
	13: MoveLoc[0](Arg0: &mut StabilityPool)
	14: Pop
B3:
	15: Ret
}

public remove_response_check<Ty0: drop>(Arg0: &mut StabilityPool, Arg1: &AdminCap) {
L2:	loc0: u64
L3:	loc1: Option<u64>
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: u64
L7:	loc5: Option<u64>
L8:	loc6: TypeName
L9:	loc7: u64
L10:	loc8: &vector<TypeName>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[8](loc6: TypeName)
	2: CopyLoc[0](Arg0: &mut StabilityPool)
	3: ImmBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	4: StLoc[10](loc8: &vector<TypeName>)
	5: CopyLoc[10](loc8: &vector<TypeName>)
	6: VecLen(51)
	7: StLoc[2](loc0: u64)
	8: LdU64(0)
	9: StLoc[4](loc2: u64)
	10: MoveLoc[2](loc0: u64)
	11: StLoc[9](loc7: u64)
B1:
	12: CopyLoc[4](loc2: u64)
	13: CopyLoc[9](loc7: u64)
	14: Lt
	15: BrFalse(35)
B2:
	16: CopyLoc[4](loc2: u64)
	17: StLoc[5](loc3: u64)
	18: CopyLoc[10](loc8: &vector<TypeName>)
	19: CopyLoc[5](loc3: u64)
	20: VecImmBorrow(51)
	21: ImmBorrowLoc[8](loc6: TypeName)
	22: Eq
	23: BrFalse(30)
B3:
	24: MoveLoc[10](loc8: &vector<TypeName>)
	25: Pop
	26: MoveLoc[5](loc3: u64)
	27: Call option::some<u64>(u64): Option<u64>
	28: StLoc[3](loc1: Option<u64>)
	29: Branch(39)
B4:
	30: MoveLoc[4](loc2: u64)
	31: LdU64(1)
	32: Add
	33: StLoc[4](loc2: u64)
	34: Branch(12)
B5:
	35: MoveLoc[10](loc8: &vector<TypeName>)
	36: Pop
	37: Call option::none<u64>(): Option<u64>
	38: StLoc[3](loc1: Option<u64>)
B6:
	39: MoveLoc[3](loc1: Option<u64>)
	40: StLoc[7](loc5: Option<u64>)
	41: ImmBorrowLoc[7](loc5: Option<u64>)
	42: Call option::is_some<u64>(&Option<u64>): bool
	43: BrFalse(53)
B7:
	44: MoveLoc[7](loc5: Option<u64>)
	45: Call option::destroy_some<u64>(Option<u64>): u64
	46: StLoc[6](loc4: u64)
	47: MoveLoc[0](Arg0: &mut StabilityPool)
	48: MutBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	49: MoveLoc[6](loc4: u64)
	50: Call vector::swap_remove<TypeName>(&mut vector<TypeName>, u64): TypeName
	51: Pop
	52: Branch(57)
B8:
	53: MoveLoc[0](Arg0: &mut StabilityPool)
	54: Pop
	55: MoveLoc[7](loc5: Option<u64>)
	56: Call option::destroy_none<u64>(Option<u64>)
B9:
	57: Ret
}

public liquidate<Ty0>(Arg0: &mut StabilityPool, Arg1: &AccountRequest, Arg2: address, Arg3: u64, Arg4: &mut Vault<Ty0>, Arg5: &Treasury, Arg6: &Clock, Arg7: &PriceResult<Ty0>, Arg8: address, Arg9: &mut TxContext): PositionResponse * FunderRecipit<Ty0> {
L10:	loc0: PositionResponse
L11:	loc1: FunderRecipit<Ty0>
L12:	loc2: UpdateRequest<Ty0>
L13:	loc3: Coin<VUSD>
L14:	loc4: u64
B0:
	0: CopyLoc[0](Arg0: &mut StabilityPool)
	1: FreezeRef
	2: MoveLoc[1](Arg1: &AccountRequest)
	3: Call assert_sender_is_liquidator(&StabilityPool, &AccountRequest)
	4: MoveLoc[0](Arg0: &mut StabilityPool)
	5: CopyLoc[6](Arg6: &Clock)
	6: CopyLoc[2](Arg2: address)
	7: MoveLoc[3](Arg3: u64)
	8: LdTrue
	9: CopyLoc[9](Arg9: &mut TxContext)
	10: Call withdraw_internal(&mut StabilityPool, &Clock, address, u64, bool, &mut TxContext): Coin<VUSD> * PositionResponse
	11: StLoc[10](loc0: PositionResponse)
	12: StLoc[13](loc3: Coin<VUSD>)
	13: ImmBorrowLoc[13](loc3: Coin<VUSD>)
	14: Call coin::value<VUSD>(&Coin<VUSD>): u64
	15: StLoc[14](loc4: u64)
	16: MoveLoc[4](Arg4: &mut Vault<Ty0>)
	17: MoveLoc[5](Arg5: &Treasury)
	18: MoveLoc[6](Arg6: &Clock)
	19: CopyLoc[7](Arg7: &PriceResult<Ty0>)
	20: MoveLoc[8](Arg8: address)
	21: MoveLoc[13](loc3: Coin<VUSD>)
	22: LdFalse
	23: Pack[3](StabilityPoolRule)
	24: MoveLoc[9](Arg9: &mut TxContext)
	25: Call vault::liquidate<Ty0, StabilityPoolRule>(&mut Vault<Ty0>, &Treasury, &Clock, &PriceResult<Ty0>, address, Coin<VUSD>, StabilityPoolRule, &mut TxContext): UpdateRequest<Ty0>
	26: StLoc[12](loc2: UpdateRequest<Ty0>)
	27: MoveLoc[7](Arg7: &PriceResult<Ty0>)
	28: Call result::aggregated_price<Ty0>(&PriceResult<Ty0>): Float
	29: Call float::to_scaled_val(Float): u128
	30: CastU64
	31: Call float::wad(): u128
	32: CastU64
	33: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	34: Call request::withdraw_amount<Ty0>(&UpdateRequest<Ty0>): u64
	35: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	36: Call request::repay_amount<Ty0>(&UpdateRequest<Ty0>): u64
	37: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	38: Call request::account<Ty0>(&UpdateRequest<Ty0>): address
	39: PackGeneric[0](Liquidation<Ty0>)
	40: Call event::emit<Liquidation<Ty0>>(Liquidation<Ty0>)
	41: MoveLoc[2](Arg2: address)
	42: MoveLoc[14](loc4: u64)
	43: MoveLoc[12](loc2: UpdateRequest<Ty0>)
	44: PackGeneric[1](FunderRecipit<Ty0>)
	45: StLoc[11](loc1: FunderRecipit<Ty0>)
	46: MoveLoc[10](loc0: PositionResponse)
	47: MoveLoc[11](loc1: FunderRecipit<Ty0>)
	48: Ret
}

public payback<Ty0>(Arg0: &mut StabilityPool, Arg1: FunderRecipit<Ty0>, Arg2: &mut Vault<Ty0>, Arg3: &mut Treasury, Arg4: &Clock, Arg5: &mut TxContext): Coin<Ty0> * UpdateResponse<Ty0> {
L6:	loc0: Option<PriceResult<Ty0>>
L7:	loc1: &Clock
L8:	loc2: &mut Treasury
L9:	loc3: &mut Vault<Ty0>
L10:	loc4: u64
L11:	loc5: Coin<Ty0>
L12:	loc6: Balance<Ty0>
L13:	loc7: u64
L14:	loc8: address
L15:	loc9: Coin<Ty0>
L16:	loc10: u64
L17:	loc11: UpdateRequest<Ty0>
L18:	loc12: UpdateResponse<Ty0>
L19:	loc13: Coin<VUSD>
L20:	loc14: u64
B0:
	0: MoveLoc[1](Arg1: FunderRecipit<Ty0>)
	1: UnpackGeneric[1](FunderRecipit<Ty0>)
	2: StLoc[17](loc11: UpdateRequest<Ty0>)
	3: StLoc[20](loc14: u64)
	4: StLoc[14](loc8: address)
	5: ImmBorrowLoc[17](loc11: UpdateRequest<Ty0>)
	6: Call request::memo<Ty0>(&UpdateRequest<Ty0>): String
	7: Call memo::liquidate(): String
	8: Neq
	9: BrFalse(11)
B1:
	10: Call err_invalid_update_request()
B2:
	11: MoveLoc[20](loc14: u64)
	12: ImmBorrowLoc[17](loc11: UpdateRequest<Ty0>)
	13: Call request::repay_amount<Ty0>(&UpdateRequest<Ty0>): u64
	14: Neq
	15: BrFalse(17)
B3:
	16: Call err_invalid_funder_recipit()
B4:
	17: MoveLoc[2](Arg2: &mut Vault<Ty0>)
	18: StLoc[9](loc3: &mut Vault<Ty0>)
	19: CopyLoc[3](Arg3: &mut Treasury)
	20: StLoc[8](loc2: &mut Treasury)
	21: MoveLoc[4](Arg4: &Clock)
	22: StLoc[7](loc1: &Clock)
	23: Call option::none<PriceResult<Ty0>>(): Option<PriceResult<Ty0>>
	24: StLoc[6](loc0: Option<PriceResult<Ty0>>)
	25: MoveLoc[9](loc3: &mut Vault<Ty0>)
	26: MoveLoc[8](loc2: &mut Treasury)
	27: MoveLoc[7](loc1: &Clock)
	28: ImmBorrowLoc[6](loc0: Option<PriceResult<Ty0>>)
	29: MoveLoc[17](loc11: UpdateRequest<Ty0>)
	30: CopyLoc[5](Arg5: &mut TxContext)
	31: Call vault::update_position<Ty0>(&mut Vault<Ty0>, &mut Treasury, &Clock, &Option<PriceResult<Ty0>>, UpdateRequest<Ty0>, &mut TxContext): Coin<Ty0> * Coin<VUSD> * UpdateResponse<Ty0>
	32: StLoc[18](loc12: UpdateResponse<Ty0>)
	33: StLoc[19](loc13: Coin<VUSD>)
	34: StLoc[11](loc5: Coin<Ty0>)
	35: ImmBorrowLoc[11](loc5: Coin<Ty0>)
	36: Call coin::value<Ty0>(&Coin<Ty0>): u64
	37: StLoc[10](loc4: u64)
	38: CopyLoc[0](Arg0: &mut StabilityPool)
	39: ImmBorrowField[2](StabilityPool.fee_rate: Float)
	40: ReadRef
	41: CopyLoc[10](loc4: u64)
	42: Call float::mul_u64(Float, u64): Float
	43: Call float::ceil(Float): u64
	44: StLoc[13](loc7: u64)
	45: CopyLoc[0](Arg0: &mut StabilityPool)
	46: ImmBorrowField[3](StabilityPool.rebate_rate: Float)
	47: ReadRef
	48: MoveLoc[10](loc4: u64)
	49: Call float::mul_u64(Float, u64): Float
	50: Call float::ceil(Float): u64
	51: StLoc[16](loc10: u64)
	52: MutBorrowLoc[11](loc5: Coin<Ty0>)
	53: Call coin::balance_mut<Ty0>(&mut Coin<Ty0>): &mut Balance<Ty0>
	54: MoveLoc[13](loc7: u64)
	55: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	56: StLoc[12](loc6: Balance<Ty0>)
	57: MoveLoc[3](Arg3: &mut Treasury)
	58: LdFalse
	59: Pack[3](StabilityPoolRule)
	60: LdConst[8](vector<u8>: "liq..)
	61: Call string::utf8(vector<u8>): String
	62: MoveLoc[12](loc6: Balance<Ty0>)
	63: Call vusd::collect<Ty0, StabilityPoolRule>(&mut Treasury, StabilityPoolRule, String, Balance<Ty0>)
	64: MutBorrowLoc[11](loc5: Coin<Ty0>)
	65: MoveLoc[16](loc10: u64)
	66: MoveLoc[5](Arg5: &mut TxContext)
	67: Call coin::split<Ty0>(&mut Coin<Ty0>, u64, &mut TxContext): Coin<Ty0>
	68: StLoc[15](loc9: Coin<Ty0>)
	69: MoveLoc[19](loc13: Coin<VUSD>)
	70: Call coin::destroy_zero<VUSD>(Coin<VUSD>)
	71: MoveLoc[0](Arg0: &mut StabilityPool)
	72: MoveLoc[14](loc8: address)
	73: MoveLoc[11](loc5: Coin<Ty0>)
	74: Call deposit_coll<Ty0>(&mut StabilityPool, address, Coin<Ty0>)
	75: MoveLoc[15](loc9: Coin<Ty0>)
	76: MoveLoc[18](loc12: UpdateResponse<Ty0>)
	77: Ret
}

public deposit(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: address, Arg3: Coin<VUSD>): PositionResponse {
L4:	loc0: u64
L5:	loc1: &mut Position
B0:
	0: ImmBorrowLoc[3](Arg3: Coin<VUSD>)
	1: Call coin::value<VUSD>(&Coin<VUSD>): u64
	2: StLoc[4](loc0: u64)
	3: CopyLoc[0](Arg0: &mut StabilityPool)
	4: MutBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	5: MoveLoc[3](Arg3: Coin<VUSD>)
	6: Call coin::into_balance<VUSD>(Coin<VUSD>): Balance<VUSD>
	7: Call balance::join<VUSD>(&mut Balance<VUSD>, Balance<VUSD>): u64
	8: Pop
	9: MoveLoc[0](Arg0: &mut StabilityPool)
	10: CopyLoc[2](Arg2: address)
	11: Call borrow_position_mut(&mut StabilityPool, address): &mut Position
	12: StLoc[5](loc1: &mut Position)
	13: CopyLoc[5](loc1: &mut Position)
	14: MutBorrowField[5](Position.vusd_balance: BalanceNumber)
	15: CopyLoc[4](loc0: u64)
	16: Call balance_number::add(&mut BalanceNumber, u64): u64
	17: Pop
	18: MoveLoc[1](Arg1: &Clock)
	19: Call clock::timestamp_ms(&Clock): u64
	20: CopyLoc[5](loc1: &mut Position)
	21: MutBorrowField[6](Position.timestamp: u64)
	22: WriteRef
	23: MoveLoc[4](loc0: u64)
	24: Pack[0](Deposit)
	25: Call event::emit<Deposit>(Deposit)
	26: MoveLoc[5](loc1: &mut Position)
	27: FreezeRef
	28: MoveLoc[2](Arg2: address)
	29: Call new_response(&Position, address): PositionResponse
	30: Ret
}

public withdraw(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: &AccountRequest, Arg3: u64, Arg4: &mut TxContext): Coin<VUSD> * PositionResponse {
L5:	loc0: address
B0:
	0: MoveLoc[2](Arg2: &AccountRequest)
	1: Call account::request_address(&AccountRequest): address
	2: StLoc[5](loc0: address)
	3: MoveLoc[0](Arg0: &mut StabilityPool)
	4: MoveLoc[1](Arg1: &Clock)
	5: MoveLoc[5](loc0: address)
	6: MoveLoc[3](Arg3: u64)
	7: LdFalse
	8: MoveLoc[4](Arg4: &mut TxContext)
	9: Call withdraw_internal(&mut StabilityPool, &Clock, address, u64, bool, &mut TxContext): Coin<VUSD> * PositionResponse
	10: Ret
}

public claim<Ty0>(Arg0: &mut StabilityPool, Arg1: &AccountRequest, Arg2: &mut TxContext): Coin<Ty0> {
L3:	loc0: Coin<Ty0>
L4:	loc1: address
L5:	loc2: BalanceNumber
L6:	loc3: TypeName
L7:	loc4: &mut VecMap<TypeName, BalanceNumber>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[6](loc3: TypeName)
	2: MoveLoc[1](Arg1: &AccountRequest)
	3: Call account::request_address(&AccountRequest): address
	4: StLoc[4](loc1: address)
	5: CopyLoc[0](Arg0: &mut StabilityPool)
	6: MoveLoc[4](loc1: address)
	7: Call borrow_position_mut(&mut StabilityPool, address): &mut Position
	8: MutBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	9: StLoc[7](loc4: &mut VecMap<TypeName, BalanceNumber>)
	10: CopyLoc[7](loc4: &mut VecMap<TypeName, BalanceNumber>)
	11: FreezeRef
	12: ImmBorrowLoc[6](loc3: TypeName)
	13: Call vec_map::contains<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>, &TypeName): bool
	14: BrFalse(29)
B1:
	15: MoveLoc[7](loc4: &mut VecMap<TypeName, BalanceNumber>)
	16: ImmBorrowLoc[6](loc3: TypeName)
	17: Call vec_map::remove<TypeName, BalanceNumber>(&mut VecMap<TypeName, BalanceNumber>, &TypeName): TypeName * BalanceNumber
	18: StLoc[5](loc2: BalanceNumber)
	19: Pop
	20: MoveLoc[0](Arg0: &mut StabilityPool)
	21: Call borrow_balance_mut<Ty0>(&mut StabilityPool): &mut Balance<Ty0>
	22: MoveLoc[5](loc2: BalanceNumber)
	23: Call balance_number::destroy(BalanceNumber): u64
	24: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	25: MoveLoc[2](Arg2: &mut TxContext)
	26: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	27: StLoc[3](loc0: Coin<Ty0>)
	28: Branch(36)
B2:
	29: MoveLoc[0](Arg0: &mut StabilityPool)
	30: Pop
	31: MoveLoc[7](loc4: &mut VecMap<TypeName, BalanceNumber>)
	32: Pop
	33: MoveLoc[2](Arg2: &mut TxContext)
	34: Call coin::zero<Ty0>(&mut TxContext): Coin<Ty0>
	35: StLoc[3](loc0: Coin<Ty0>)
B3:
	36: MoveLoc[3](loc0: Coin<Ty0>)
	37: Ret
}

public check_response(Arg0: &StabilityPool, Arg1: PositionResponse) {
L2:	loc0: u64
L3:	loc1: bool
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: &TypeName
L7:	loc5: u64
L8:	loc6: &vector<TypeName>
L9:	loc7: VecSet<TypeName>
B0:
	0: MoveLoc[1](Arg1: PositionResponse)
	1: Unpack[5](PositionResponse)
	2: StLoc[9](loc7: VecSet<TypeName>)
	3: Pop
	4: Pop
	5: Pop
	6: MoveLoc[0](Arg0: &StabilityPool)
	7: ImmBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	8: StLoc[8](loc6: &vector<TypeName>)
	9: CopyLoc[8](loc6: &vector<TypeName>)
	10: VecLen(51)
	11: StLoc[2](loc0: u64)
	12: LdU64(0)
	13: StLoc[5](loc3: u64)
	14: MoveLoc[2](loc0: u64)
	15: StLoc[7](loc5: u64)
B1:
	16: CopyLoc[5](loc3: u64)
	17: CopyLoc[7](loc5: u64)
	18: Lt
	19: BrFalse(41)
B2:
	20: CopyLoc[5](loc3: u64)
	21: StLoc[4](loc2: u64)
	22: CopyLoc[8](loc6: &vector<TypeName>)
	23: MoveLoc[4](loc2: u64)
	24: VecImmBorrow(51)
	25: StLoc[6](loc4: &TypeName)
	26: ImmBorrowLoc[9](loc7: VecSet<TypeName>)
	27: MoveLoc[6](loc4: &TypeName)
	28: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	29: Not
	30: BrFalse(36)
B3:
	31: MoveLoc[8](loc6: &vector<TypeName>)
	32: Pop
	33: LdFalse
	34: StLoc[3](loc1: bool)
	35: Branch(45)
B4:
	36: MoveLoc[5](loc3: u64)
	37: LdU64(1)
	38: Add
	39: StLoc[5](loc3: u64)
	40: Branch(16)
B5:
	41: MoveLoc[8](loc6: &vector<TypeName>)
	42: Pop
	43: LdTrue
	44: StLoc[3](loc1: bool)
B6:
	45: MoveLoc[3](loc1: bool)
	46: Not
	47: BrFalse(50)
B7:
	48: Call err_missing_response_witness()
	49: Branch(50)
B8:
	50: Ret
}

public add_witness<Ty0: drop>(Arg0: &mut PositionResponse, Arg1: Ty0) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut PositionResponse)
	3: FreezeRef
	4: Call witnesses(&PositionResponse): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_witness_already_exists()
B2:
	9: MoveLoc[0](Arg0: &mut PositionResponse)
	10: MutBorrowField[8](PositionResponse.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Ret
}

public pool_balance(Arg0: &StabilityPool): u64 {
B0:
	0: MoveLoc[0](Arg0: &StabilityPool)
	1: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	2: Call balance::value<VUSD>(&Balance<VUSD>): u64
	3: Ret
}

public position_exists(Arg0: &StabilityPool, Arg1: address): bool {
B0:
	0: MoveLoc[0](Arg0: &StabilityPool)
	1: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	2: MoveLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	4: Ret
}

public get_position_data(Arg0: &StabilityPool, Arg1: address): u64 * VecMap<TypeName, u64> * u64 {
L2:	loc0: u64
L3:	loc1: u64
L4:	loc2: &mut vector<u64>
L5:	loc3: vector<u64>
L6:	loc4: TypeName
L7:	loc5: vector<TypeName>
L8:	loc6: VecMap<TypeName, u64>
L9:	loc7: TypeName
L10:	loc8: u64
L11:	loc9: &Position
L12:	loc10: vector<u64>
L13:	loc11: u64
L14:	loc12: vector<TypeName>
L15:	loc13: vector<TypeName>
B0:
	0: CopyLoc[0](Arg0: &StabilityPool)
	1: CopyLoc[1](Arg1: address)
	2: Call position_exists(&StabilityPool, address): bool
	3: Not
	4: BrFalse(6)
B1:
	5: Call err_account_not_found()
B2:
	6: MoveLoc[0](Arg0: &StabilityPool)
	7: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	8: MoveLoc[1](Arg1: address)
	9: Call linked_table::borrow<address, Position>(&LinkedTable<address, Position>, address): &Position
	10: StLoc[11](loc9: &Position)
	11: CopyLoc[11](loc9: &Position)
	12: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	13: Call vec_map::keys<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>): vector<TypeName>
	14: StLoc[7](loc5: vector<TypeName>)
	15: CopyLoc[7](loc5: vector<TypeName>)
	16: StLoc[14](loc12: vector<TypeName>)
	17: LdConst[9](vector<u64>: 00)
	18: StLoc[12](loc10: vector<u64>)
	19: MoveLoc[14](loc12: vector<TypeName>)
	20: StLoc[15](loc13: vector<TypeName>)
	21: MutBorrowLoc[15](loc13: vector<TypeName>)
	22: Call vector::reverse<TypeName>(&mut vector<TypeName>)
	23: ImmBorrowLoc[15](loc13: vector<TypeName>)
	24: VecLen(51)
	25: StLoc[2](loc0: u64)
	26: LdU64(0)
	27: StLoc[10](loc8: u64)
	28: MoveLoc[2](loc0: u64)
	29: StLoc[13](loc11: u64)
B3:
	30: CopyLoc[10](loc8: u64)
	31: CopyLoc[13](loc11: u64)
	32: Lt
	33: BrFalse(57)
B4:
	34: CopyLoc[10](loc8: u64)
	35: Pop
	36: MutBorrowLoc[15](loc13: vector<TypeName>)
	37: VecPopBack(51)
	38: StLoc[9](loc7: TypeName)
	39: MutBorrowLoc[12](loc10: vector<u64>)
	40: StLoc[4](loc2: &mut vector<u64>)
	41: MoveLoc[9](loc7: TypeName)
	42: StLoc[6](loc4: TypeName)
	43: CopyLoc[11](loc9: &Position)
	44: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	45: ImmBorrowLoc[6](loc4: TypeName)
	46: Call vec_map::get<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>, &TypeName): &BalanceNumber
	47: Call balance_number::value(&BalanceNumber): u64
	48: StLoc[3](loc1: u64)
	49: MoveLoc[4](loc2: &mut vector<u64>)
	50: MoveLoc[3](loc1: u64)
	51: VecPushBack(17)
	52: MoveLoc[10](loc8: u64)
	53: LdU64(1)
	54: Add
	55: StLoc[10](loc8: u64)
	56: Branch(30)
B5:
	57: MoveLoc[15](loc13: vector<TypeName>)
	58: VecUnpack(51, 0)
	59: MoveLoc[12](loc10: vector<u64>)
	60: StLoc[5](loc3: vector<u64>)
	61: MoveLoc[7](loc5: vector<TypeName>)
	62: MoveLoc[5](loc3: vector<u64>)
	63: Call vec_map::from_keys_values<TypeName, u64>(vector<TypeName>, vector<u64>): VecMap<TypeName, u64>
	64: StLoc[8](loc6: VecMap<TypeName, u64>)
	65: CopyLoc[11](loc9: &Position)
	66: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	67: Call balance_number::value(&BalanceNumber): u64
	68: MoveLoc[8](loc6: VecMap<TypeName, u64>)
	69: MoveLoc[11](loc9: &Position)
	70: ImmBorrowField[6](Position.timestamp: u64)
	71: ReadRef
	72: Ret
}

public update_req<Ty0>(Arg0: &FunderRecipit<Ty0>): &UpdateRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &FunderRecipit<Ty0>)
	1: ImmBorrowFieldGeneric[0](FunderRecipit.update_req: UpdateRequest<Ty0>)
	2: Ret
}

public update_req_mut<Ty0>(Arg0: &mut FunderRecipit<Ty0>): &mut UpdateRequest<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &mut FunderRecipit<Ty0>)
	1: MutBorrowFieldGeneric[0](FunderRecipit.update_req: UpdateRequest<Ty0>)
	2: Ret
}

public account(Arg0: &PositionResponse): address {
B0:
	0: MoveLoc[0](Arg0: &PositionResponse)
	1: ImmBorrowField[11](PositionResponse.account: address)
	2: ReadRef
	3: Ret
}

public vusd_balance(Arg0: &PositionResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionResponse)
	1: ImmBorrowField[12](PositionResponse.vusd_balance: u64)
	2: ReadRef
	3: Ret
}

public timestamp(Arg0: &PositionResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionResponse)
	1: ImmBorrowField[13](PositionResponse.timestamp: u64)
	2: ReadRef
	3: Ret
}

public witnesses(Arg0: &PositionResponse): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &PositionResponse)
	1: ImmBorrowField[8](PositionResponse.witnesses: VecSet<TypeName>)
	2: Ret
}

public get_positions(Arg0: &StabilityPool, Arg1: Option<address>, Arg2: u64): vector<PositionData> * Option<address> {
L3:	loc0: bool
L4:	loc1: address
L5:	loc2: vector<u64>
L6:	loc3: VecMap<TypeName, u64>
L7:	loc4: vector<TypeName>
L8:	loc5: u64
L9:	loc6: vector<PositionData>
L10:	loc7: &LinkedTable<address, Position>
L11:	loc8: u64
L12:	loc9: u64
B0:
	0: VecPack(108, 0)
	1: StLoc[9](loc6: vector<PositionData>)
	2: CopyLoc[0](Arg0: &StabilityPool)
	3: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	4: StLoc[10](loc7: &LinkedTable<address, Position>)
	5: ImmBorrowLoc[1](Arg1: Option<address>)
	6: Call option::is_none<address>(&Option<address>): bool
	7: BrFalse(12)
B1:
	8: CopyLoc[10](loc7: &LinkedTable<address, Position>)
	9: Call linked_table::front<address, Position>(&LinkedTable<address, Position>): &Option<address>
	10: ReadRef
	11: StLoc[1](Arg1: Option<address>)
B2:
	12: LdU64(0)
	13: StLoc[8](loc5: u64)
B3:
	14: ImmBorrowLoc[1](Arg1: Option<address>)
	15: Call option::is_some<address>(&Option<address>): bool
	16: BrFalse(22)
B4:
	17: CopyLoc[8](loc5: u64)
	18: CopyLoc[2](Arg2: u64)
	19: Lt
	20: StLoc[3](loc0: bool)
	21: Branch(24)
B5:
	22: LdFalse
	23: StLoc[3](loc0: bool)
B6:
	24: MoveLoc[3](loc0: bool)
	25: BrFalse(58)
B7:
	26: ImmBorrowLoc[1](Arg1: Option<address>)
	27: Call option::borrow<address>(&Option<address>): &address
	28: ReadRef
	29: StLoc[4](loc1: address)
	30: CopyLoc[0](Arg0: &StabilityPool)
	31: CopyLoc[4](loc1: address)
	32: Call get_position_data(&StabilityPool, address): u64 * VecMap<TypeName, u64> * u64
	33: StLoc[11](loc8: u64)
	34: StLoc[6](loc3: VecMap<TypeName, u64>)
	35: StLoc[12](loc9: u64)
	36: MoveLoc[6](loc3: VecMap<TypeName, u64>)
	37: Call vec_map::into_keys_values<TypeName, u64>(VecMap<TypeName, u64>): vector<TypeName> * vector<u64>
	38: StLoc[5](loc2: vector<u64>)
	39: StLoc[7](loc4: vector<TypeName>)
	40: MutBorrowLoc[9](loc6: vector<PositionData>)
	41: CopyLoc[4](loc1: address)
	42: MoveLoc[12](loc9: u64)
	43: MoveLoc[7](loc4: vector<TypeName>)
	44: MoveLoc[5](loc2: vector<u64>)
	45: MoveLoc[11](loc8: u64)
	46: Pack[8](PositionData)
	47: VecPushBack(108)
	48: MoveLoc[8](loc5: u64)
	49: LdU64(1)
	50: Add
	51: StLoc[8](loc5: u64)
	52: CopyLoc[10](loc7: &LinkedTable<address, Position>)
	53: MoveLoc[4](loc1: address)
	54: Call linked_table::next<address, Position>(&LinkedTable<address, Position>, address): &Option<address>
	55: ReadRef
	56: StLoc[1](Arg1: Option<address>)
	57: Branch(14)
B8:
	58: MoveLoc[10](loc7: &LinkedTable<address, Position>)
	59: Pop
	60: MoveLoc[0](Arg0: &StabilityPool)
	61: Pop
	62: MoveLoc[9](loc6: vector<PositionData>)
	63: MoveLoc[1](Arg1: Option<address>)
	64: Ret
}

assert_sender_is_liquidator(Arg0: &StabilityPool, Arg1: &AccountRequest) {
B0:
	0: MoveLoc[0](Arg0: &StabilityPool)
	1: ImmBorrowField[0](StabilityPool.liquidator: address)
	2: ReadRef
	3: MoveLoc[1](Arg1: &AccountRequest)
	4: Call account::request_address(&AccountRequest): address
	5: Neq
	6: BrFalse(8)
B1:
	7: Call err_sender_not_liquidator()
B2:
	8: Ret
}

borrow_position_mut(Arg0: &mut StabilityPool, Arg1: address): &mut Position {
B0:
	0: CopyLoc[0](Arg0: &mut StabilityPool)
	1: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	4: Not
	5: BrFalse(15)
B1:
	6: CopyLoc[0](Arg0: &mut StabilityPool)
	7: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	8: CopyLoc[1](Arg1: address)
	9: LdU64(0)
	10: Call balance_number::new(u64): BalanceNumber
	11: Call vec_map::empty<TypeName, BalanceNumber>(): VecMap<TypeName, BalanceNumber>
	12: LdU64(0)
	13: Pack[4](Position)
	14: Call linked_table::push_back<address, Position>(&mut LinkedTable<address, Position>, address, Position)
B2:
	15: MoveLoc[0](Arg0: &mut StabilityPool)
	16: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	17: MoveLoc[1](Arg1: address)
	18: Call linked_table::borrow_mut<address, Position>(&mut LinkedTable<address, Position>, address): &mut Position
	19: Ret
}

new_response(Arg0: &Position, Arg1: address): PositionResponse {
L2:	loc0: u64
L3:	loc1: address
L4:	loc2: u64
L5:	loc3: VecSet<TypeName>
L6:	loc4: u64
L7:	loc5: TypeName
L8:	loc6: VecMap<TypeName, u64>
L9:	loc7: u64
L10:	loc8: u64
L11:	loc9: vector<TypeName>
B0:
	0: Call vec_map::empty<TypeName, u64>(): VecMap<TypeName, u64>
	1: StLoc[8](loc6: VecMap<TypeName, u64>)
	2: CopyLoc[0](Arg0: &Position)
	3: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	4: Call vec_map::keys<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>): vector<TypeName>
	5: StLoc[11](loc9: vector<TypeName>)
	6: MutBorrowLoc[11](loc9: vector<TypeName>)
	7: Call vector::reverse<TypeName>(&mut vector<TypeName>)
	8: ImmBorrowLoc[11](loc9: vector<TypeName>)
	9: VecLen(51)
	10: StLoc[2](loc0: u64)
	11: LdU64(0)
	12: StLoc[9](loc7: u64)
	13: MoveLoc[2](loc0: u64)
	14: StLoc[10](loc8: u64)
B1:
	15: CopyLoc[9](loc7: u64)
	16: CopyLoc[10](loc8: u64)
	17: Lt
	18: BrFalse(37)
B2:
	19: CopyLoc[9](loc7: u64)
	20: Pop
	21: MutBorrowLoc[11](loc9: vector<TypeName>)
	22: VecPopBack(51)
	23: StLoc[7](loc5: TypeName)
	24: MutBorrowLoc[8](loc6: VecMap<TypeName, u64>)
	25: CopyLoc[7](loc5: TypeName)
	26: CopyLoc[0](Arg0: &Position)
	27: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	28: ImmBorrowLoc[7](loc5: TypeName)
	29: Call vec_map::get<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>, &TypeName): &BalanceNumber
	30: Call balance_number::value(&BalanceNumber): u64
	31: Call vec_map::insert<TypeName, u64>(&mut VecMap<TypeName, u64>, TypeName, u64)
	32: MoveLoc[9](loc7: u64)
	33: LdU64(1)
	34: Add
	35: StLoc[9](loc7: u64)
	36: Branch(15)
B3:
	37: MoveLoc[11](loc9: vector<TypeName>)
	38: VecUnpack(51, 0)
	39: MoveLoc[1](Arg1: address)
	40: StLoc[3](loc1: address)
	41: CopyLoc[0](Arg0: &Position)
	42: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	43: Call balance_number::value(&BalanceNumber): u64
	44: StLoc[4](loc2: u64)
	45: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	46: StLoc[5](loc3: VecSet<TypeName>)
	47: MoveLoc[0](Arg0: &Position)
	48: ImmBorrowField[6](Position.timestamp: u64)
	49: ReadRef
	50: StLoc[6](loc4: u64)
	51: MoveLoc[3](loc1: address)
	52: MoveLoc[4](loc2: u64)
	53: MoveLoc[6](loc4: u64)
	54: MoveLoc[5](loc3: VecSet<TypeName>)
	55: Pack[5](PositionResponse)
	56: Ret
}

withdraw_internal(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: address, Arg3: u64, Arg4: bool, Arg5: &mut TxContext): Coin<VUSD> * PositionResponse {
L6:	loc0: bool
L7:	loc1: bool
L8:	loc2: VecMap<TypeName, BalanceNumber>
L9:	loc3: u64
L10:	loc4: Position
L11:	loc5: PositionResponse
L12:	loc6: Coin<VUSD>
B0:
	0: CopyLoc[0](Arg0: &mut StabilityPool)
	1: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	2: Call balance::value<VUSD>(&Balance<VUSD>): u64
	3: StLoc[9](loc3: u64)
	4: CopyLoc[0](Arg0: &mut StabilityPool)
	5: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	6: CopyLoc[2](Arg2: address)
	7: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	8: Not
	9: BrFalse(11)
B1:
	10: Call err_account_not_found()
B2:
	11: CopyLoc[0](Arg0: &mut StabilityPool)
	12: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	13: CopyLoc[2](Arg2: address)
	14: Call linked_table::remove<address, Position>(&mut LinkedTable<address, Position>, address): Position
	15: StLoc[10](loc4: Position)
	16: MoveLoc[9](loc3: u64)
	17: LdU64(0)
	18: Gt
	19: BrFalse(28)
B3:
	20: ImmBorrowLoc[10](loc4: Position)
	21: ImmBorrowField[6](Position.timestamp: u64)
	22: ReadRef
	23: CopyLoc[1](Arg1: &Clock)
	24: Call clock::timestamp_ms(&Clock): u64
	25: Eq
	26: StLoc[6](loc0: bool)
	27: Branch(30)
B4:
	28: LdFalse
	29: StLoc[6](loc0: bool)
B5:
	30: MoveLoc[6](loc0: bool)
	31: BrFalse(33)
B6:
	32: Call err_cannot_instantly_withdraw()
B7:
	33: MutBorrowLoc[10](loc4: Position)
	34: MutBorrowField[5](Position.vusd_balance: BalanceNumber)
	35: CopyLoc[3](Arg3: u64)
	36: Call balance_number::sub(&mut BalanceNumber, u64): u64
	37: Pop
	38: MoveLoc[1](Arg1: &Clock)
	39: Call clock::timestamp_ms(&Clock): u64
	40: MutBorrowLoc[10](loc4: Position)
	41: MutBorrowField[6](Position.timestamp: u64)
	42: WriteRef
	43: ImmBorrowLoc[10](loc4: Position)
	44: CopyLoc[2](Arg2: address)
	45: Call new_response(&Position, address): PositionResponse
	46: StLoc[11](loc5: PositionResponse)
	47: ImmBorrowLoc[10](loc4: Position)
	48: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	49: Call balance_number::value(&BalanceNumber): u64
	50: LdU64(0)
	51: Eq
	52: BrFalse(58)
B8:
	53: ImmBorrowLoc[10](loc4: Position)
	54: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	55: Call vec_map::is_empty<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>): bool
	56: StLoc[7](loc1: bool)
	57: Branch(60)
B9:
	58: LdFalse
	59: StLoc[7](loc1: bool)
B10:
	60: MoveLoc[7](loc1: bool)
	61: BrFalse(71)
B11:
	62: MoveLoc[10](loc4: Position)
	63: Unpack[4](Position)
	64: Pop
	65: StLoc[8](loc2: VecMap<TypeName, BalanceNumber>)
	66: Call balance_number::destroy(BalanceNumber): u64
	67: Pop
	68: MoveLoc[8](loc2: VecMap<TypeName, BalanceNumber>)
	69: Call vec_map::destroy_empty<TypeName, BalanceNumber>(VecMap<TypeName, BalanceNumber>)
	70: Branch(76)
B12:
	71: CopyLoc[0](Arg0: &mut StabilityPool)
	72: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	73: MoveLoc[2](Arg2: address)
	74: MoveLoc[10](loc4: Position)
	75: Call linked_table::push_back<address, Position>(&mut LinkedTable<address, Position>, address, Position)
B13:
	76: MoveLoc[0](Arg0: &mut StabilityPool)
	77: MutBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	78: CopyLoc[3](Arg3: u64)
	79: Call balance::split<VUSD>(&mut Balance<VUSD>, u64): Balance<VUSD>
	80: MoveLoc[5](Arg5: &mut TxContext)
	81: Call coin::from_balance<VUSD>(Balance<VUSD>, &mut TxContext): Coin<VUSD>
	82: StLoc[12](loc6: Coin<VUSD>)
	83: MoveLoc[3](Arg3: u64)
	84: MoveLoc[4](Arg4: bool)
	85: Pack[1](Withdraw)
	86: Call event::emit<Withdraw>(Withdraw)
	87: MoveLoc[12](loc6: Coin<VUSD>)
	88: MoveLoc[11](loc5: PositionResponse)
	89: Ret
}

borrow_balance_mut<Ty0>(Arg0: &mut StabilityPool): &mut Balance<Ty0> {
L1:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[1](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut StabilityPool)
	3: ImmBorrowField[14](StabilityPool.id: UID)
	4: CopyLoc[1](loc0: TypeName)
	5: Call dynamic_field::exists_with_type<TypeName, Balance<Ty0>>(&UID, TypeName): bool
	6: Not
	7: BrFalse(13)
B1:
	8: CopyLoc[0](Arg0: &mut StabilityPool)
	9: MutBorrowField[14](StabilityPool.id: UID)
	10: CopyLoc[1](loc0: TypeName)
	11: Call balance::zero<Ty0>(): Balance<Ty0>
	12: Call dynamic_field::add<TypeName, Balance<Ty0>>(&mut UID, TypeName, Balance<Ty0>)
B2:
	13: MoveLoc[0](Arg0: &mut StabilityPool)
	14: MutBorrowField[14](StabilityPool.id: UID)
	15: MoveLoc[1](loc0: TypeName)
	16: Call dynamic_field::borrow_mut<TypeName, Balance<Ty0>>(&mut UID, TypeName): &mut Balance<Ty0>
	17: Ret
}

deposit_coll<Ty0>(Arg0: &mut StabilityPool, Arg1: address, Arg2: Coin<Ty0>) {
L3:	loc0: TypeName
L4:	loc1: &mut VecMap<TypeName, BalanceNumber>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut StabilityPool)
	3: MoveLoc[1](Arg1: address)
	4: Call borrow_position_mut(&mut StabilityPool, address): &mut Position
	5: MutBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	6: StLoc[4](loc1: &mut VecMap<TypeName, BalanceNumber>)
	7: CopyLoc[4](loc1: &mut VecMap<TypeName, BalanceNumber>)
	8: FreezeRef
	9: ImmBorrowLoc[3](loc0: TypeName)
	10: Call vec_map::contains<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>, &TypeName): bool
	11: BrFalse(20)
B1:
	12: MoveLoc[4](loc1: &mut VecMap<TypeName, BalanceNumber>)
	13: ImmBorrowLoc[3](loc0: TypeName)
	14: Call vec_map::get_mut<TypeName, BalanceNumber>(&mut VecMap<TypeName, BalanceNumber>, &TypeName): &mut BalanceNumber
	15: ImmBorrowLoc[2](Arg2: Coin<Ty0>)
	16: Call coin::value<Ty0>(&Coin<Ty0>): u64
	17: Call balance_number::add(&mut BalanceNumber, u64): u64
	18: Pop
	19: Branch(26)
B2:
	20: MoveLoc[4](loc1: &mut VecMap<TypeName, BalanceNumber>)
	21: MoveLoc[3](loc0: TypeName)
	22: ImmBorrowLoc[2](Arg2: Coin<Ty0>)
	23: Call coin::value<Ty0>(&Coin<Ty0>): u64
	24: Call balance_number::new(u64): BalanceNumber
	25: Call vec_map::insert<TypeName, BalanceNumber>(&mut VecMap<TypeName, BalanceNumber>, TypeName, BalanceNumber)
B3:
	26: MoveLoc[0](Arg0: &mut StabilityPool)
	27: Call borrow_balance_mut<Ty0>(&mut StabilityPool): &mut Balance<Ty0>
	28: MoveLoc[2](Arg2: Coin<Ty0>)
	29: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	30: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	31: Pop
	32: Ret
}

public account_address(Arg0: &PositionUpdateResponse): address {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[15](PositionUpdateResponse.account: address)
	2: ReadRef
	3: Ret
}

public pool_vusd_balance_before(Arg0: &PositionUpdateResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[16](PositionUpdateResponse.pool_vusd_balance_before: u64)
	2: ReadRef
	3: Ret
}

public pool_vusd_balance_after(Arg0: &PositionUpdateResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[17](PositionUpdateResponse.pool_vusd_balance_after: u64)
	2: ReadRef
	3: Ret
}

public position_vusd_balance_before(Arg0: &PositionUpdateResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[18](PositionUpdateResponse.position_vusd_balance_before: u64)
	2: ReadRef
	3: Ret
}

public position_vusd_balance_after(Arg0: &PositionUpdateResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[19](PositionUpdateResponse.position_vusd_balance_after: u64)
	2: ReadRef
	3: Ret
}

public update_timestamp(Arg0: &PositionUpdateResponse): u64 {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[20](PositionUpdateResponse.timestamp: u64)
	2: ReadRef
	3: Ret
}

public witness_set(Arg0: &PositionUpdateResponse): &VecSet<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &PositionUpdateResponse)
	1: ImmBorrowField[21](PositionUpdateResponse.witnesses: VecSet<TypeName>)
	2: Ret
}

public liquidate_and_update<Ty0>(Arg0: &mut StabilityPool, Arg1: &AccountRequest, Arg2: address, Arg3: u64, Arg4: &mut Vault<Ty0>, Arg5: &Treasury, Arg6: &Clock, Arg7: &PriceResult<Ty0>, Arg8: address, Arg9: &mut TxContext): PositionUpdateResponse * FunderRecipit<Ty0> {
L10:	loc0: PositionUpdateResponse
L11:	loc1: FunderRecipit<Ty0>
L12:	loc2: UpdateRequest<Ty0>
L13:	loc3: Coin<VUSD>
L14:	loc4: u64
B0:
	0: CopyLoc[0](Arg0: &mut StabilityPool)
	1: FreezeRef
	2: MoveLoc[1](Arg1: &AccountRequest)
	3: Call assert_sender_is_liquidator(&StabilityPool, &AccountRequest)
	4: CopyLoc[4](Arg4: &mut Vault<Ty0>)
	5: FreezeRef
	6: CopyLoc[8](Arg8: address)
	7: CopyLoc[6](Arg6: &Clock)
	8: CopyLoc[7](Arg7: &PriceResult<Ty0>)
	9: Call vault::position_is_healthy<Ty0>(&Vault<Ty0>, address, &Clock, &PriceResult<Ty0>): bool
	10: BrFalse(12)
B1:
	11: Call err_position_is_healthy()
B2:
	12: MoveLoc[0](Arg0: &mut StabilityPool)
	13: CopyLoc[6](Arg6: &Clock)
	14: CopyLoc[2](Arg2: address)
	15: MoveLoc[3](Arg3: u64)
	16: LdTrue
	17: CopyLoc[9](Arg9: &mut TxContext)
	18: Call withdraw_and_update_internal(&mut StabilityPool, &Clock, address, u64, bool, &mut TxContext): Coin<VUSD> * PositionUpdateResponse
	19: StLoc[10](loc0: PositionUpdateResponse)
	20: StLoc[13](loc3: Coin<VUSD>)
	21: ImmBorrowLoc[13](loc3: Coin<VUSD>)
	22: Call coin::value<VUSD>(&Coin<VUSD>): u64
	23: StLoc[14](loc4: u64)
	24: MoveLoc[4](Arg4: &mut Vault<Ty0>)
	25: MoveLoc[5](Arg5: &Treasury)
	26: MoveLoc[6](Arg6: &Clock)
	27: CopyLoc[7](Arg7: &PriceResult<Ty0>)
	28: MoveLoc[8](Arg8: address)
	29: MoveLoc[13](loc3: Coin<VUSD>)
	30: LdFalse
	31: Pack[3](StabilityPoolRule)
	32: MoveLoc[9](Arg9: &mut TxContext)
	33: Call vault::liquidate<Ty0, StabilityPoolRule>(&mut Vault<Ty0>, &Treasury, &Clock, &PriceResult<Ty0>, address, Coin<VUSD>, StabilityPoolRule, &mut TxContext): UpdateRequest<Ty0>
	34: StLoc[12](loc2: UpdateRequest<Ty0>)
	35: MoveLoc[7](Arg7: &PriceResult<Ty0>)
	36: Call result::aggregated_price<Ty0>(&PriceResult<Ty0>): Float
	37: Call float::to_scaled_val(Float): u128
	38: CastU64
	39: Call float::wad(): u128
	40: CastU64
	41: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	42: Call request::withdraw_amount<Ty0>(&UpdateRequest<Ty0>): u64
	43: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	44: Call request::repay_amount<Ty0>(&UpdateRequest<Ty0>): u64
	45: ImmBorrowLoc[12](loc2: UpdateRequest<Ty0>)
	46: Call request::account<Ty0>(&UpdateRequest<Ty0>): address
	47: PackGeneric[0](Liquidation<Ty0>)
	48: Call event::emit<Liquidation<Ty0>>(Liquidation<Ty0>)
	49: MoveLoc[2](Arg2: address)
	50: MoveLoc[14](loc4: u64)
	51: MoveLoc[12](loc2: UpdateRequest<Ty0>)
	52: PackGeneric[1](FunderRecipit<Ty0>)
	53: StLoc[11](loc1: FunderRecipit<Ty0>)
	54: MoveLoc[10](loc0: PositionUpdateResponse)
	55: MoveLoc[11](loc1: FunderRecipit<Ty0>)
	56: Ret
}

public deposit_and_update(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: &AccountRequest, Arg3: Coin<VUSD>): PositionUpdateResponse {
L4:	loc0: address
L5:	loc1: u64
L6:	loc2: u64
L7:	loc3: u64
L8:	loc4: &mut Position
L9:	loc5: u64
B0:
	0: MoveLoc[2](Arg2: &AccountRequest)
	1: Call account::request_address(&AccountRequest): address
	2: StLoc[4](loc0: address)
	3: ImmBorrowLoc[3](Arg3: Coin<VUSD>)
	4: Call coin::value<VUSD>(&Coin<VUSD>): u64
	5: StLoc[5](loc1: u64)
	6: CopyLoc[0](Arg0: &mut StabilityPool)
	7: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	8: Call balance::value<VUSD>(&Balance<VUSD>): u64
	9: StLoc[7](loc3: u64)
	10: CopyLoc[0](Arg0: &mut StabilityPool)
	11: MutBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	12: MoveLoc[3](Arg3: Coin<VUSD>)
	13: Call coin::into_balance<VUSD>(Coin<VUSD>): Balance<VUSD>
	14: Call balance::join<VUSD>(&mut Balance<VUSD>, Balance<VUSD>): u64
	15: Pop
	16: CopyLoc[0](Arg0: &mut StabilityPool)
	17: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	18: Call balance::value<VUSD>(&Balance<VUSD>): u64
	19: StLoc[6](loc2: u64)
	20: MoveLoc[0](Arg0: &mut StabilityPool)
	21: CopyLoc[4](loc0: address)
	22: Call borrow_position_mut(&mut StabilityPool, address): &mut Position
	23: StLoc[8](loc4: &mut Position)
	24: CopyLoc[8](loc4: &mut Position)
	25: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	26: Call balance_number::value(&BalanceNumber): u64
	27: StLoc[9](loc5: u64)
	28: CopyLoc[8](loc4: &mut Position)
	29: MutBorrowField[5](Position.vusd_balance: BalanceNumber)
	30: CopyLoc[5](loc1: u64)
	31: Call balance_number::add(&mut BalanceNumber, u64): u64
	32: Pop
	33: MoveLoc[1](Arg1: &Clock)
	34: Call clock::timestamp_ms(&Clock): u64
	35: CopyLoc[8](loc4: &mut Position)
	36: MutBorrowField[6](Position.timestamp: u64)
	37: WriteRef
	38: MoveLoc[5](loc1: u64)
	39: Pack[0](Deposit)
	40: Call event::emit<Deposit>(Deposit)
	41: MoveLoc[4](loc0: address)
	42: MoveLoc[7](loc3: u64)
	43: MoveLoc[6](loc2: u64)
	44: MoveLoc[9](loc5: u64)
	45: CopyLoc[8](loc4: &mut Position)
	46: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	47: Call balance_number::value(&BalanceNumber): u64
	48: MoveLoc[8](loc4: &mut Position)
	49: ImmBorrowField[6](Position.timestamp: u64)
	50: ReadRef
	51: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	52: Pack[9](PositionUpdateResponse)
	53: Ret
}

public withdraw_and_update(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: &AccountRequest, Arg3: u64, Arg4: &mut TxContext): Coin<VUSD> * PositionUpdateResponse {
L5:	loc0: address
B0:
	0: MoveLoc[2](Arg2: &AccountRequest)
	1: Call account::request_address(&AccountRequest): address
	2: StLoc[5](loc0: address)
	3: MoveLoc[0](Arg0: &mut StabilityPool)
	4: MoveLoc[1](Arg1: &Clock)
	5: MoveLoc[5](loc0: address)
	6: MoveLoc[3](Arg3: u64)
	7: LdFalse
	8: MoveLoc[4](Arg4: &mut TxContext)
	9: Call withdraw_and_update_internal(&mut StabilityPool, &Clock, address, u64, bool, &mut TxContext): Coin<VUSD> * PositionUpdateResponse
	10: Ret
}

public check_update_response(Arg0: &StabilityPool, Arg1: PositionUpdateResponse) {
L2:	loc0: u64
L3:	loc1: bool
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: &TypeName
L7:	loc5: u64
L8:	loc6: &vector<TypeName>
L9:	loc7: VecSet<TypeName>
B0:
	0: MoveLoc[1](Arg1: PositionUpdateResponse)
	1: Unpack[9](PositionUpdateResponse)
	2: StLoc[9](loc7: VecSet<TypeName>)
	3: Pop
	4: Pop
	5: Pop
	6: Pop
	7: Pop
	8: Pop
	9: MoveLoc[0](Arg0: &StabilityPool)
	10: ImmBorrowField[1](StabilityPool.response_checklist: vector<TypeName>)
	11: StLoc[8](loc6: &vector<TypeName>)
	12: CopyLoc[8](loc6: &vector<TypeName>)
	13: VecLen(51)
	14: StLoc[2](loc0: u64)
	15: LdU64(0)
	16: StLoc[5](loc3: u64)
	17: MoveLoc[2](loc0: u64)
	18: StLoc[7](loc5: u64)
B1:
	19: CopyLoc[5](loc3: u64)
	20: CopyLoc[7](loc5: u64)
	21: Lt
	22: BrFalse(44)
B2:
	23: CopyLoc[5](loc3: u64)
	24: StLoc[4](loc2: u64)
	25: CopyLoc[8](loc6: &vector<TypeName>)
	26: MoveLoc[4](loc2: u64)
	27: VecImmBorrow(51)
	28: StLoc[6](loc4: &TypeName)
	29: ImmBorrowLoc[9](loc7: VecSet<TypeName>)
	30: MoveLoc[6](loc4: &TypeName)
	31: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	32: Not
	33: BrFalse(39)
B3:
	34: MoveLoc[8](loc6: &vector<TypeName>)
	35: Pop
	36: LdFalse
	37: StLoc[3](loc1: bool)
	38: Branch(48)
B4:
	39: MoveLoc[5](loc3: u64)
	40: LdU64(1)
	41: Add
	42: StLoc[5](loc3: u64)
	43: Branch(19)
B5:
	44: MoveLoc[8](loc6: &vector<TypeName>)
	45: Pop
	46: LdTrue
	47: StLoc[3](loc1: bool)
B6:
	48: MoveLoc[3](loc1: bool)
	49: Not
	50: BrFalse(53)
B7:
	51: Call err_missing_response_witness()
	52: Branch(53)
B8:
	53: Ret
}

public insert_witness<Ty0: drop>(Arg0: &mut PositionUpdateResponse, Arg1: Ty0) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut PositionUpdateResponse)
	3: FreezeRef
	4: Call witness_set(&PositionUpdateResponse): &VecSet<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	7: BrFalse(9)
B1:
	8: Call err_witness_already_exists()
B2:
	9: MoveLoc[0](Arg0: &mut PositionUpdateResponse)
	10: MutBorrowField[21](PositionUpdateResponse.witnesses: VecSet<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: Call vec_set::insert<TypeName>(&mut VecSet<TypeName>, TypeName)
	13: Ret
}

withdraw_and_update_internal(Arg0: &mut StabilityPool, Arg1: &Clock, Arg2: address, Arg3: u64, Arg4: bool, Arg5: &mut TxContext): Coin<VUSD> * PositionUpdateResponse {
L6:	loc0: bool
L7:	loc1: bool
L8:	loc2: VecMap<TypeName, BalanceNumber>
L9:	loc3: u64
L10:	loc4: Position
L11:	loc5: u64
L12:	loc6: u64
L13:	loc7: PositionUpdateResponse
L14:	loc8: Coin<VUSD>
B0:
	0: CopyLoc[0](Arg0: &mut StabilityPool)
	1: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	2: Call balance::value<VUSD>(&Balance<VUSD>): u64
	3: StLoc[9](loc3: u64)
	4: CopyLoc[0](Arg0: &mut StabilityPool)
	5: ImmBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	6: CopyLoc[2](Arg2: address)
	7: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	8: Not
	9: BrFalse(11)
B1:
	10: Call err_account_not_found()
B2:
	11: CopyLoc[0](Arg0: &mut StabilityPool)
	12: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	13: CopyLoc[2](Arg2: address)
	14: Call linked_table::remove<address, Position>(&mut LinkedTable<address, Position>, address): Position
	15: StLoc[10](loc4: Position)
	16: CopyLoc[9](loc3: u64)
	17: LdU64(0)
	18: Gt
	19: BrFalse(28)
B3:
	20: ImmBorrowLoc[10](loc4: Position)
	21: ImmBorrowField[6](Position.timestamp: u64)
	22: ReadRef
	23: CopyLoc[1](Arg1: &Clock)
	24: Call clock::timestamp_ms(&Clock): u64
	25: Eq
	26: StLoc[6](loc0: bool)
	27: Branch(30)
B4:
	28: LdFalse
	29: StLoc[6](loc0: bool)
B5:
	30: MoveLoc[6](loc0: bool)
	31: BrFalse(33)
B6:
	32: Call err_cannot_instantly_withdraw()
B7:
	33: ImmBorrowLoc[10](loc4: Position)
	34: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	35: Call balance_number::value(&BalanceNumber): u64
	36: StLoc[12](loc6: u64)
	37: MutBorrowLoc[10](loc4: Position)
	38: MutBorrowField[5](Position.vusd_balance: BalanceNumber)
	39: CopyLoc[3](Arg3: u64)
	40: Call balance_number::sub(&mut BalanceNumber, u64): u64
	41: Pop
	42: ImmBorrowLoc[10](loc4: Position)
	43: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	44: Call balance_number::value(&BalanceNumber): u64
	45: StLoc[11](loc5: u64)
	46: CopyLoc[1](Arg1: &Clock)
	47: Call clock::timestamp_ms(&Clock): u64
	48: MutBorrowLoc[10](loc4: Position)
	49: MutBorrowField[6](Position.timestamp: u64)
	50: WriteRef
	51: ImmBorrowLoc[10](loc4: Position)
	52: ImmBorrowField[5](Position.vusd_balance: BalanceNumber)
	53: Call balance_number::value(&BalanceNumber): u64
	54: LdU64(0)
	55: Eq
	56: BrFalse(62)
B8:
	57: ImmBorrowLoc[10](loc4: Position)
	58: ImmBorrowField[7](Position.coll_balances: VecMap<TypeName, BalanceNumber>)
	59: Call vec_map::is_empty<TypeName, BalanceNumber>(&VecMap<TypeName, BalanceNumber>): bool
	60: StLoc[7](loc1: bool)
	61: Branch(64)
B9:
	62: LdFalse
	63: StLoc[7](loc1: bool)
B10:
	64: MoveLoc[7](loc1: bool)
	65: BrFalse(75)
B11:
	66: MoveLoc[10](loc4: Position)
	67: Unpack[4](Position)
	68: Pop
	69: StLoc[8](loc2: VecMap<TypeName, BalanceNumber>)
	70: Call balance_number::destroy(BalanceNumber): u64
	71: Pop
	72: MoveLoc[8](loc2: VecMap<TypeName, BalanceNumber>)
	73: Call vec_map::destroy_empty<TypeName, BalanceNumber>(VecMap<TypeName, BalanceNumber>)
	74: Branch(80)
B12:
	75: CopyLoc[0](Arg0: &mut StabilityPool)
	76: MutBorrowField[9](StabilityPool.position_table: LinkedTable<address, Position>)
	77: CopyLoc[2](Arg2: address)
	78: MoveLoc[10](loc4: Position)
	79: Call linked_table::push_back<address, Position>(&mut LinkedTable<address, Position>, address, Position)
B13:
	80: CopyLoc[0](Arg0: &mut StabilityPool)
	81: MutBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	82: CopyLoc[3](Arg3: u64)
	83: Call balance::split<VUSD>(&mut Balance<VUSD>, u64): Balance<VUSD>
	84: MoveLoc[5](Arg5: &mut TxContext)
	85: Call coin::from_balance<VUSD>(Balance<VUSD>, &mut TxContext): Coin<VUSD>
	86: StLoc[14](loc8: Coin<VUSD>)
	87: MoveLoc[2](Arg2: address)
	88: MoveLoc[9](loc3: u64)
	89: MoveLoc[0](Arg0: &mut StabilityPool)
	90: ImmBorrowField[4](StabilityPool.vusd_balance: Balance<VUSD>)
	91: Call balance::value<VUSD>(&Balance<VUSD>): u64
	92: MoveLoc[12](loc6: u64)
	93: MoveLoc[11](loc5: u64)
	94: MoveLoc[1](Arg1: &Clock)
	95: Call clock::timestamp_ms(&Clock): u64
	96: Call vec_set::empty<TypeName>(): VecSet<TypeName>
	97: Pack[9](PositionUpdateResponse)
	98: StLoc[13](loc7: PositionUpdateResponse)
	99: MoveLoc[3](Arg3: u64)
	100: MoveLoc[4](Arg4: bool)
	101: Pack[1](Withdraw)
	102: Call event::emit<Withdraw>(Withdraw)
	103: MoveLoc[14](loc8: Coin<VUSD>)
	104: MoveLoc[13](loc7: PositionUpdateResponse)
	105: Ret
}

public try_get_position_balance(Arg0: &StabilityPool, Arg1: address): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &StabilityPool)
	1: CopyLoc[1](Arg1: address)
	2: Call position_exists(&StabilityPool, address): bool
	3: BrFalse(11)
B1:
	4: MoveLoc[0](Arg0: &StabilityPool)
	5: MoveLoc[1](Arg1: address)
	6: Call get_position_data(&StabilityPool, address): u64 * VecMap<TypeName, u64> * u64
	7: Pop
	8: Pop
	9: StLoc[2](loc0: u64)
	10: Branch(15)
B2:
	11: MoveLoc[0](Arg0: &StabilityPool)
	12: Pop
	13: LdU64(0)
	14: StLoc[2](loc0: u64)
B3:
	15: MoveLoc[2](loc0: u64)
	16: Ret
}

Constants [
	0 => u64: 201
	1 => u64: 202
	2 => u64: 203
	3 => u64: 204
	4 => u64: 205
	5 => u64: 206
	6 => u64: 207
	7 => u64: 208
	8 => vector<u8>: "liquidation_fee" // interpreted as UTF8 string
	9 => vector<u64>: 00
]
}
