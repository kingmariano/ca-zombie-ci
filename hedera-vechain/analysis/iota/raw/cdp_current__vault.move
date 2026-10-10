// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.vault {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::u64;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::events;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::memo;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::request;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::response;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::version;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::witness;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::double;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::linked_table;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::result;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::limited_supply;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::module_request;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

struct Position has copy, drop, store {
	timestamp: u64,
	coll_amount: u64,
	debt_amount: u64
}

struct Vault<phantom Ty0> has store, key {
	id: UID,
	decimal: u8,
	interest_rate: Double,
	limited_supply: LimitedSupply,
	min_collateral_ratio: Float,
	liquidation_rule: TypeName,
	request_checklist: vector<TypeName>,
	response_checklist: vector<TypeName>,
	position_table: LinkedTable<address, Position>,
	balance: Balance<Ty0>
}

struct PositionData has copy, drop {
	debtor: address,
	coll_amount: u64,
	debt_amount: u64
}

err_missing_request_witness() {
B0:
	0: LdConst[0](u64: 401)
	1: Abort
}

err_missing_response_witness() {
B0:
	0: LdConst[1](u64: 402)
	1: Abort
}

err_oracle_price_is_required() {
B0:
	0: LdConst[2](u64: 403)
	1: Abort
}

err_position_is_not_healthy() {
B0:
	0: LdConst[3](u64: 404)
	1: Abort
}

err_position_is_healthy() {
B0:
	0: LdConst[4](u64: 405)
	1: Abort
}

err_invalid_liquidation() {
B0:
	0: LdConst[5](u64: 406)
	1: Abort
}

err_debtor_not_found() {
B0:
	0: LdConst[6](u64: 407)
	1: Abort
}

err_repay_too_much() {
B0:
	0: LdConst[7](u64: 408)
	1: Abort
}

err_withdraw_too_much() {
B0:
	0: LdConst[8](u64: 409)
	1: Abort
}

err_wrong_vault_id() {
B0:
	0: LdConst[9](u64: 410)
	1: Abort
}

public new<Ty0, Ty1: drop>(Arg0: &Treasury, Arg1: &AdminCap, Arg2: u8, Arg3: Double, Arg4: u64, Arg5: Float, Arg6: &mut TxContext): Vault<Ty0> {
L7:	loc0: UID
L8:	loc1: LimitedSupply
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: CopyLoc[4](Arg4: u64)
	3: Call limited_supply::new(u64): LimitedSupply
	4: StLoc[8](loc1: LimitedSupply)
	5: CopyLoc[6](Arg6: &mut TxContext)
	6: Call object::new(&mut TxContext): UID
	7: StLoc[7](loc0: UID)
	8: ImmBorrowLoc[7](loc0: UID)
	9: Call object::uid_to_inner(&UID): ID
	10: CopyLoc[3](Arg3: Double)
	11: MoveLoc[4](Arg4: u64)
	12: CopyLoc[5](Arg5: Float)
	13: Call events::emit_vault_created<Ty0>(ID, Double, u64, Float)
	14: MoveLoc[7](loc0: UID)
	15: MoveLoc[2](Arg2: u8)
	16: MoveLoc[3](Arg3: Double)
	17: MoveLoc[8](loc1: LimitedSupply)
	18: MoveLoc[5](Arg5: Float)
	19: Call type_name::get<Ty1>(): TypeName
	20: VecPack(16, 0)
	21: VecPack(16, 0)
	22: MoveLoc[6](Arg6: &mut TxContext)
	23: Call linked_table::new<address, Position>(&mut TxContext): LinkedTable<address, Position>
	24: Call balance::zero<Ty0>(): Balance<Ty0>
	25: PackGeneric[0](Vault<Ty0>)
	26: Ret
}

entry create<Ty0, Ty1: drop>(Arg0: &Treasury, Arg1: &AdminCap, Arg2: u8, Arg3: u64, Arg4: u64, Arg5: u64, Arg6: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: MoveLoc[1](Arg1: &AdminCap)
	2: MoveLoc[2](Arg2: u8)
	3: MoveLoc[3](Arg3: u64)
	4: Call double::from_bps(u64): Double
	5: MoveLoc[4](Arg4: u64)
	6: MoveLoc[5](Arg5: u64)
	7: Call float::from_bps(u64): Float
	8: MoveLoc[6](Arg6: &mut TxContext)
	9: Call new<Ty0, Ty1>(&Treasury, &AdminCap, u8, Double, u64, Float, &mut TxContext): Vault<Ty0>
	10: Call transfer::share_object<Vault<Ty0>>(Vault<Ty0>)
	11: Ret
}

public set_supply_limit<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap, Arg2: u64) {
B0:
	0: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	1: FreezeRef
	2: Call object::id<Vault<Ty0>>(&Vault<Ty0>): ID
	3: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	4: FreezeRef
	5: Call limited_supply<Ty0>(&Vault<Ty0>): &LimitedSupply
	6: Call limited_supply::limit(&LimitedSupply): u64
	7: CopyLoc[2](Arg2: u64)
	8: Call events::emit_supply_limit_updated<Ty0>(ID, u64, u64)
	9: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	10: MutBorrowFieldGeneric[0](Vault.limited_supply: LimitedSupply)
	11: MoveLoc[2](Arg2: u64)
	12: Call limited_supply::set_limit(&mut LimitedSupply, u64)
	13: Ret
}

public set_liquidation_rule<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: FreezeRef
	4: Call object::id<Vault<Ty0>>(&Vault<Ty0>): ID
	5: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	6: FreezeRef
	7: Call liquidation_rule<Ty0>(&Vault<Ty0>): TypeName
	8: CopyLoc[2](loc0: TypeName)
	9: Call events::emit_liquidation_rule_updated<Ty0>(ID, TypeName, TypeName)
	10: MoveLoc[2](loc0: TypeName)
	11: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	12: MutBorrowFieldGeneric[1](Vault.liquidation_rule: TypeName)
	13: WriteRef
	14: Ret
}

public add_request_check<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: FreezeRef
	4: Call request_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vector::contains<TypeName>(&vector<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	10: MutBorrowFieldGeneric[2](Vault.request_checklist: vector<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: VecPushBack(16)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	15: Pop
B3:
	16: Ret
}

public remove_request_check<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap) {
L2:	loc0: u64
L3:	loc1: Option<u64>
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: u64
L7:	loc5: Option<u64>
L8:	loc6: u64
L9:	loc7: &vector<TypeName>
L10:	loc8: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[10](loc8: TypeName)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: FreezeRef
	4: Call request_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	5: StLoc[9](loc7: &vector<TypeName>)
	6: CopyLoc[9](loc7: &vector<TypeName>)
	7: VecLen(16)
	8: StLoc[2](loc0: u64)
	9: LdU64(0)
	10: StLoc[4](loc2: u64)
	11: MoveLoc[2](loc0: u64)
	12: StLoc[8](loc6: u64)
B1:
	13: CopyLoc[4](loc2: u64)
	14: CopyLoc[8](loc6: u64)
	15: Lt
	16: BrFalse(36)
B2:
	17: CopyLoc[4](loc2: u64)
	18: StLoc[5](loc3: u64)
	19: CopyLoc[9](loc7: &vector<TypeName>)
	20: CopyLoc[5](loc3: u64)
	21: VecImmBorrow(16)
	22: ImmBorrowLoc[10](loc8: TypeName)
	23: Eq
	24: BrFalse(31)
B3:
	25: MoveLoc[9](loc7: &vector<TypeName>)
	26: Pop
	27: MoveLoc[5](loc3: u64)
	28: Call option::some<u64>(u64): Option<u64>
	29: StLoc[3](loc1: Option<u64>)
	30: Branch(40)
B4:
	31: MoveLoc[4](loc2: u64)
	32: LdU64(1)
	33: Add
	34: StLoc[4](loc2: u64)
	35: Branch(13)
B5:
	36: MoveLoc[9](loc7: &vector<TypeName>)
	37: Pop
	38: Call option::none<u64>(): Option<u64>
	39: StLoc[3](loc1: Option<u64>)
B6:
	40: MoveLoc[3](loc1: Option<u64>)
	41: StLoc[7](loc5: Option<u64>)
	42: ImmBorrowLoc[7](loc5: Option<u64>)
	43: Call option::is_some<u64>(&Option<u64>): bool
	44: BrFalse(54)
B7:
	45: MoveLoc[7](loc5: Option<u64>)
	46: Call option::destroy_some<u64>(Option<u64>): u64
	47: StLoc[6](loc4: u64)
	48: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	49: MutBorrowFieldGeneric[2](Vault.request_checklist: vector<TypeName>)
	50: MoveLoc[6](loc4: u64)
	51: Call vector::swap_remove<TypeName>(&mut vector<TypeName>, u64): TypeName
	52: Pop
	53: Branch(58)
B8:
	54: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	55: Pop
	56: MoveLoc[7](loc5: Option<u64>)
	57: Call option::destroy_none<u64>(Option<u64>)
B9:
	58: Ret
}

public add_response_check<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap) {
L2:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: FreezeRef
	4: Call response_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vector::contains<TypeName>(&vector<TypeName>, &TypeName): bool
	7: Not
	8: BrFalse(14)
B1:
	9: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	10: MutBorrowFieldGeneric[3](Vault.response_checklist: vector<TypeName>)
	11: MoveLoc[2](loc0: TypeName)
	12: VecPushBack(16)
	13: Branch(16)
B2:
	14: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	15: Pop
B3:
	16: Ret
}

public remove_response_check<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &AdminCap) {
L2:	loc0: u64
L3:	loc1: Option<u64>
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: u64
L7:	loc5: Option<u64>
L8:	loc6: u64
L9:	loc7: &vector<TypeName>
L10:	loc8: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[10](loc8: TypeName)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: FreezeRef
	4: Call response_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	5: StLoc[9](loc7: &vector<TypeName>)
	6: CopyLoc[9](loc7: &vector<TypeName>)
	7: VecLen(16)
	8: StLoc[2](loc0: u64)
	9: LdU64(0)
	10: StLoc[4](loc2: u64)
	11: MoveLoc[2](loc0: u64)
	12: StLoc[8](loc6: u64)
B1:
	13: CopyLoc[4](loc2: u64)
	14: CopyLoc[8](loc6: u64)
	15: Lt
	16: BrFalse(36)
B2:
	17: CopyLoc[4](loc2: u64)
	18: StLoc[5](loc3: u64)
	19: CopyLoc[9](loc7: &vector<TypeName>)
	20: CopyLoc[5](loc3: u64)
	21: VecImmBorrow(16)
	22: ImmBorrowLoc[10](loc8: TypeName)
	23: Eq
	24: BrFalse(31)
B3:
	25: MoveLoc[9](loc7: &vector<TypeName>)
	26: Pop
	27: MoveLoc[5](loc3: u64)
	28: Call option::some<u64>(u64): Option<u64>
	29: StLoc[3](loc1: Option<u64>)
	30: Branch(40)
B4:
	31: MoveLoc[4](loc2: u64)
	32: LdU64(1)
	33: Add
	34: StLoc[4](loc2: u64)
	35: Branch(13)
B5:
	36: MoveLoc[9](loc7: &vector<TypeName>)
	37: Pop
	38: Call option::none<u64>(): Option<u64>
	39: StLoc[3](loc1: Option<u64>)
B6:
	40: MoveLoc[3](loc1: Option<u64>)
	41: StLoc[7](loc5: Option<u64>)
	42: ImmBorrowLoc[7](loc5: Option<u64>)
	43: Call option::is_some<u64>(&Option<u64>): bool
	44: BrFalse(54)
B7:
	45: MoveLoc[7](loc5: Option<u64>)
	46: Call option::destroy_some<u64>(Option<u64>): u64
	47: StLoc[6](loc4: u64)
	48: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	49: MutBorrowFieldGeneric[3](Vault.response_checklist: vector<TypeName>)
	50: MoveLoc[6](loc4: u64)
	51: Call vector::swap_remove<TypeName>(&mut vector<TypeName>, u64): TypeName
	52: Pop
	53: Branch(58)
B8:
	54: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	55: Pop
	56: MoveLoc[7](loc5: Option<u64>)
	57: Call option::destroy_none<u64>(Option<u64>)
B9:
	58: Ret
}

public update_position<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: &mut Treasury, Arg2: &Clock, Arg3: &Option<PriceResult<Ty0>>, Arg4: UpdateRequest<Ty0>, Arg5: &mut TxContext): Coin<Ty0> * Coin<VUSD> * UpdateResponse<Ty0> {
L6:	loc0: u64
L7:	loc1: bool
L8:	loc2: bool
L9:	loc3: bool
L10:	loc4: bool
L11:	loc5: bool
L12:	loc6: Coin<VUSD>
L13:	loc7: Balance<VUSD>
L14:	loc8: Position
L15:	loc9: u64
L16:	loc10: Option<address>
L17:	loc11: bool
L18:	loc12: u64
L19:	loc13: u64
L20:	loc14: address
L21:	loc15: u64
L22:	loc16: u64
L23:	loc17: u64
L24:	loc18: Float
L25:	loc19: u64
L26:	loc20: Coin<Ty0>
L27:	loc21: Float
L28:	loc22: bool
L29:	loc23: u64
L30:	loc24: u64
L31:	loc25: Float
L32:	loc26: address
L33:	loc27: Coin<Ty0>
L34:	loc28: u64
L35:	loc29: u64
L36:	loc30: u64
L37:	loc31: Balance<VUSD>
L38:	loc32: Balance<VUSD>
L39:	loc33: Balance<VUSD>
L40:	loc34: u64
L41:	loc35: u64
L42:	loc36: String
L43:	loc37: Option<address>
L44:	loc38: Option<address>
L45:	loc39: &mut LinkedTable<address, Position>
L46:	loc40: Position
L47:	loc41: Position
L48:	loc42: Coin<VUSD>
L49:	loc43: UpdateResponse<Ty0>
L50:	loc44: &TypeName
L51:	loc45: u64
L52:	loc46: u64
L53:	loc47: &vector<TypeName>
L54:	loc48: u64
L55:	loc49: Coin<VUSD>
L56:	loc50: Coin<VUSD>
L57:	loc51: Coin<VUSD>
L58:	loc52: u64
L59:	loc53: VecSet<TypeName>
L60:	loc54: Float
B0:
	0: CopyLoc[1](Arg1: &mut Treasury)
	1: FreezeRef
	2: Call version::assert_valid_package(&Treasury)
	3: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	4: Call request::account<Ty0>(&UpdateRequest<Ty0>): address
	5: StLoc[32](loc26: address)
	6: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	7: MutBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	8: StLoc[45](loc39: &mut LinkedTable<address, Position>)
	9: CopyLoc[45](loc39: &mut LinkedTable<address, Position>)
	10: FreezeRef
	11: CopyLoc[32](loc26: address)
	12: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	13: BrFalse(38)
B1:
	14: CopyLoc[45](loc39: &mut LinkedTable<address, Position>)
	15: FreezeRef
	16: CopyLoc[32](loc26: address)
	17: Call linked_table::next<address, Position>(&LinkedTable<address, Position>, address): &Option<address>
	18: ReadRef
	19: StLoc[43](loc37: Option<address>)
	20: MoveLoc[45](loc39: &mut LinkedTable<address, Position>)
	21: CopyLoc[32](loc26: address)
	22: Call linked_table::remove<address, Position>(&mut LinkedTable<address, Position>, address): Position
	23: StLoc[46](loc40: Position)
	24: MutBorrowLoc[46](loc40: Position)
	25: CopyLoc[2](Arg2: &Clock)
	26: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	27: ImmBorrowFieldGeneric[5](Vault.interest_rate: Double)
	28: ReadRef
	29: Call accrue_interest(&mut Position, &Clock, Double): u64
	30: StLoc[40](loc34: u64)
	31: MoveLoc[46](loc40: Position)
	32: MoveLoc[40](loc34: u64)
	33: MoveLoc[43](loc37: Option<address>)
	34: StLoc[16](loc10: Option<address>)
	35: StLoc[15](loc9: u64)
	36: StLoc[14](loc8: Position)
	37: Branch(50)
B2:
	38: MoveLoc[45](loc39: &mut LinkedTable<address, Position>)
	39: Pop
	40: CopyLoc[2](Arg2: &Clock)
	41: Call clock::timestamp_ms(&Clock): u64
	42: LdU64(0)
	43: LdU64(0)
	44: Pack[0](Position)
	45: LdU64(0)
	46: Call option::none<address>(): Option<address>
	47: StLoc[16](loc10: Option<address>)
	48: StLoc[15](loc9: u64)
	49: StLoc[14](loc8: Position)
B3:
	50: MoveLoc[14](loc8: Position)
	51: MoveLoc[15](loc9: u64)
	52: MoveLoc[16](loc10: Option<address>)
	53: StLoc[44](loc38: Option<address>)
	54: StLoc[41](loc35: u64)
	55: StLoc[47](loc41: Position)
	56: ImmBorrowLoc[47](loc41: Position)
	57: ImmBorrowField[6](Position.coll_amount: u64)
	58: ReadRef
	59: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	60: Call request::deposit_amount<Ty0>(&UpdateRequest<Ty0>): u64
	61: Add
	62: MutBorrowLoc[47](loc41: Position)
	63: MutBorrowField[6](Position.coll_amount: u64)
	64: WriteRef
	65: ImmBorrowLoc[47](loc41: Position)
	66: ImmBorrowField[7](Position.debt_amount: u64)
	67: ReadRef
	68: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	69: Call request::borrow_amount<Ty0>(&UpdateRequest<Ty0>): u64
	70: Add
	71: MutBorrowLoc[47](loc41: Position)
	72: MutBorrowField[7](Position.debt_amount: u64)
	73: WriteRef
	74: ImmBorrowLoc[47](loc41: Position)
	75: ImmBorrowField[7](Position.debt_amount: u64)
	76: ReadRef
	77: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	78: Call request::repay_amount<Ty0>(&UpdateRequest<Ty0>): u64
	79: Lt
	80: BrFalse(82)
B4:
	81: Call err_repay_too_much()
B5:
	82: ImmBorrowLoc[47](loc41: Position)
	83: ImmBorrowField[7](Position.debt_amount: u64)
	84: ReadRef
	85: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	86: Call request::repay_amount<Ty0>(&UpdateRequest<Ty0>): u64
	87: Sub
	88: MutBorrowLoc[47](loc41: Position)
	89: MutBorrowField[7](Position.debt_amount: u64)
	90: WriteRef
	91: ImmBorrowLoc[47](loc41: Position)
	92: ImmBorrowField[6](Position.coll_amount: u64)
	93: ReadRef
	94: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	95: Call request::withdraw_amount<Ty0>(&UpdateRequest<Ty0>): u64
	96: Lt
	97: BrFalse(99)
B6:
	98: Call err_withdraw_too_much()
B7:
	99: ImmBorrowLoc[47](loc41: Position)
	100: ImmBorrowField[6](Position.coll_amount: u64)
	101: ReadRef
	102: ImmBorrowLoc[4](Arg4: UpdateRequest<Ty0>)
	103: Call request::withdraw_amount<Ty0>(&UpdateRequest<Ty0>): u64
	104: Sub
	105: MutBorrowLoc[47](loc41: Position)
	106: MutBorrowField[6](Position.coll_amount: u64)
	107: WriteRef
	108: ImmBorrowLoc[47](loc41: Position)
	109: ImmBorrowField[6](Position.coll_amount: u64)
	110: ReadRef
	111: LdU64(0)
	112: Eq
	113: BrFalse(121)
B8:
	114: ImmBorrowLoc[47](loc41: Position)
	115: ImmBorrowField[7](Position.debt_amount: u64)
	116: ReadRef
	117: LdU64(0)
	118: Eq
	119: StLoc[17](loc11: bool)
	120: Branch(123)
B9:
	121: LdFalse
	122: StLoc[17](loc11: bool)
B10:
	123: MoveLoc[17](loc11: bool)
	124: BrFalse(137)
B11:
	125: MoveLoc[2](Arg2: &Clock)
	126: Pop
	127: MoveLoc[47](loc41: Position)
	128: Unpack[0](Position)
	129: StLoc[29](loc23: u64)
	130: StLoc[22](loc16: u64)
	131: Pop
	132: MoveLoc[22](loc16: u64)
	133: MoveLoc[29](loc23: u64)
	134: StLoc[19](loc13: u64)
	135: StLoc[18](loc12: u64)
	136: Branch(150)
B12:
	137: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	138: MutBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	139: MoveLoc[44](loc38: Option<address>)
	140: CopyLoc[32](loc26: address)
	141: MoveLoc[47](loc41: Position)
	142: Call linked_table::insert_front<address, Position>(&mut LinkedTable<address, Position>, Option<address>, address, Position)
	143: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	144: FreezeRef
	145: CopyLoc[32](loc26: address)
	146: MoveLoc[2](Arg2: &Clock)
	147: Call get_position_data<Ty0>(&Vault<Ty0>, address, &Clock): u64 * u64
	148: StLoc[19](loc13: u64)
	149: StLoc[18](loc12: u64)
B13:
	150: MoveLoc[18](loc12: u64)
	151: MoveLoc[19](loc13: u64)
	152: StLoc[30](loc24: u64)
	153: StLoc[23](loc17: u64)
	154: MoveLoc[4](Arg4: UpdateRequest<Ty0>)
	155: Call request::destroy<Ty0>(UpdateRequest<Ty0>): ID * address * Coin<Ty0> * u64 * Coin<VUSD> * u64 * VecSet<TypeName> * String
	156: StLoc[42](loc36: String)
	157: StLoc[59](loc53: VecSet<TypeName>)
	158: StLoc[58](loc52: u64)
	159: StLoc[48](loc42: Coin<VUSD>)
	160: StLoc[21](loc15: u64)
	161: StLoc[33](loc27: Coin<Ty0>)
	162: StLoc[20](loc14: address)
	163: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	164: FreezeRef
	165: Call id<Ty0>(&Vault<Ty0>): ID
	166: Neq
	167: BrFalse(169)
B14:
	168: Call err_wrong_vault_id()
B15:
	169: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	170: FreezeRef
	171: Call request_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	172: StLoc[53](loc47: &vector<TypeName>)
	173: CopyLoc[53](loc47: &vector<TypeName>)
	174: VecLen(16)
	175: StLoc[6](loc0: u64)
	176: LdU64(0)
	177: StLoc[36](loc30: u64)
	178: MoveLoc[6](loc0: u64)
	179: StLoc[51](loc45: u64)
B16:
	180: CopyLoc[36](loc30: u64)
	181: CopyLoc[51](loc45: u64)
	182: Lt
	183: BrFalse(205)
B17:
	184: CopyLoc[36](loc30: u64)
	185: StLoc[35](loc29: u64)
	186: CopyLoc[53](loc47: &vector<TypeName>)
	187: MoveLoc[35](loc29: u64)
	188: VecImmBorrow(16)
	189: StLoc[50](loc44: &TypeName)
	190: ImmBorrowLoc[59](loc53: VecSet<TypeName>)
	191: MoveLoc[50](loc44: &TypeName)
	192: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	193: Not
	194: BrFalse(200)
B18:
	195: MoveLoc[53](loc47: &vector<TypeName>)
	196: Pop
	197: LdFalse
	198: StLoc[7](loc1: bool)
	199: Branch(209)
B19:
	200: MoveLoc[36](loc30: u64)
	201: LdU64(1)
	202: Add
	203: StLoc[36](loc30: u64)
	204: Branch(180)
B20:
	205: MoveLoc[53](loc47: &vector<TypeName>)
	206: Pop
	207: LdTrue
	208: StLoc[7](loc1: bool)
B21:
	209: MoveLoc[7](loc1: bool)
	210: Not
	211: BrFalse(213)
B22:
	212: Call err_missing_request_witness()
B23:
	213: CopyLoc[42](loc36: String)
	214: Call memo::manage(): String
	215: Eq
	216: BrFalse(240)
B24:
	217: CopyLoc[21](loc15: u64)
	218: LdU64(0)
	219: Gt
	220: BrFalse(224)
B25:
	221: LdTrue
	222: StLoc[9](loc3: bool)
	223: Branch(237)
B26:
	224: CopyLoc[58](loc52: u64)
	225: LdU64(0)
	226: Gt
	227: BrFalse(233)
B27:
	228: CopyLoc[30](loc24: u64)
	229: LdU64(0)
	230: Gt
	231: StLoc[10](loc4: bool)
	232: Branch(235)
B28:
	233: LdFalse
	234: StLoc[10](loc4: bool)
B29:
	235: MoveLoc[10](loc4: bool)
	236: StLoc[9](loc3: bool)
B30:
	237: MoveLoc[9](loc3: bool)
	238: StLoc[8](loc2: bool)
	239: Branch(242)
B31:
	240: LdFalse
	241: StLoc[8](loc2: bool)
B32:
	242: MoveLoc[8](loc2: bool)
	243: StLoc[28](loc22: bool)
	244: CopyLoc[28](loc22: bool)
	245: BrFalse(250)
B33:
	246: CopyLoc[3](Arg3: &Option<PriceResult<Ty0>>)
	247: Call option::is_none<PriceResult<Ty0>>(&Option<PriceResult<Ty0>>): bool
	248: StLoc[11](loc5: bool)
	249: Branch(252)
B34:
	250: LdFalse
	251: StLoc[11](loc5: bool)
B35:
	252: MoveLoc[11](loc5: bool)
	253: BrFalse(255)
B36:
	254: Call err_oracle_price_is_required()
B37:
	255: LdU64(10)
	256: StLoc[52](loc46: u64)
	257: LdU64(0)
	258: Call float::from(u64): Float
	259: StLoc[60](loc54: Float)
	260: CopyLoc[52](loc46: u64)
	261: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	262: FreezeRef
	263: Call decimal<Ty0>(&Vault<Ty0>): u8
	264: Call u64::pow(u64, u8): u64
	265: StLoc[25](loc19: u64)
	266: MoveLoc[52](loc46: u64)
	267: Call vusd::decimal(): u8
	268: Call u64::pow(u64, u8): u64
	269: StLoc[54](loc48: u64)
	270: MoveLoc[28](loc22: bool)
	271: BrFalse(300)
B38:
	272: MoveLoc[3](Arg3: &Option<PriceResult<Ty0>>)
	273: Call option::borrow<PriceResult<Ty0>>(&Option<PriceResult<Ty0>>): &PriceResult<Ty0>
	274: Call result::aggregated_price<Ty0>(&PriceResult<Ty0>): Float
	275: StLoc[27](loc21: Float)
	276: CopyLoc[23](loc17: u64)
	277: MoveLoc[25](loc19: u64)
	278: Call float::from_fraction(u64, u64): Float
	279: StLoc[24](loc18: Float)
	280: CopyLoc[30](loc24: u64)
	281: MoveLoc[54](loc48: u64)
	282: Call float::from_fraction(u64, u64): Float
	283: StLoc[31](loc25: Float)
	284: CopyLoc[31](loc25: Float)
	285: MoveLoc[60](loc54: Float)
	286: Call float::gt(Float, Float): bool
	287: BrFalse(302)
B39:
	288: MoveLoc[24](loc18: Float)
	289: MoveLoc[27](loc21: Float)
	290: Call float::mul(Float, Float): Float
	291: MoveLoc[31](loc25: Float)
	292: Call float::div(Float, Float): Float
	293: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	294: FreezeRef
	295: Call min_collateral_ratio<Ty0>(&Vault<Ty0>): Float
	296: Call float::lt(Float, Float): bool
	297: BrFalse(302)
B40:
	298: Call err_position_is_not_healthy()
	299: Branch(302)
B41:
	300: MoveLoc[3](Arg3: &Option<PriceResult<Ty0>>)
	301: Pop
B42:
	302: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	303: FreezeRef
	304: Call object::id<Vault<Ty0>>(&Vault<Ty0>): ID
	305: MoveLoc[20](loc14: address)
	306: ImmBorrowLoc[33](loc27: Coin<Ty0>)
	307: Call coin::value<Ty0>(&Coin<Ty0>): u64
	308: CopyLoc[21](loc15: u64)
	309: ImmBorrowLoc[48](loc42: Coin<VUSD>)
	310: Call coin::value<VUSD>(&Coin<VUSD>): u64
	311: CopyLoc[58](loc52: u64)
	312: CopyLoc[41](loc35: u64)
	313: CopyLoc[23](loc17: u64)
	314: CopyLoc[30](loc24: u64)
	315: MoveLoc[42](loc36: String)
	316: Call events::emit_position_updated<Ty0>(ID, address, u64, u64, u64, u64, u64, u64, u64, String)
	317: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	318: MutBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	319: MoveLoc[33](loc27: Coin<Ty0>)
	320: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	321: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	322: Pop
	323: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	324: MutBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	325: MoveLoc[58](loc52: u64)
	326: CopyLoc[5](Arg5: &mut TxContext)
	327: Call coin::take<Ty0>(&mut Balance<Ty0>, u64, &mut TxContext): Coin<Ty0>
	328: StLoc[26](loc20: Coin<Ty0>)
	329: CopyLoc[21](loc15: u64)
	330: CopyLoc[41](loc35: u64)
	331: Add
	332: ImmBorrowLoc[48](loc42: Coin<VUSD>)
	333: Call coin::value<VUSD>(&Coin<VUSD>): u64
	334: Gt
	335: BrFalse(362)
B43:
	336: MoveLoc[21](loc15: u64)
	337: CopyLoc[41](loc35: u64)
	338: Add
	339: ImmBorrowLoc[48](loc42: Coin<VUSD>)
	340: Call coin::value<VUSD>(&Coin<VUSD>): u64
	341: Sub
	342: StLoc[34](loc28: u64)
	343: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	344: CopyLoc[1](Arg1: &mut Treasury)
	345: MoveLoc[34](loc28: u64)
	346: MoveLoc[5](Arg5: &mut TxContext)
	347: Call mint_vusd<Ty0>(&mut Vault<Ty0>, &mut Treasury, u64, &mut TxContext): Coin<VUSD>
	348: StLoc[55](loc49: Coin<VUSD>)
	349: MutBorrowLoc[55](loc49: Coin<VUSD>)
	350: MoveLoc[48](loc42: Coin<VUSD>)
	351: Call coin::join<VUSD>(&mut Coin<VUSD>, Coin<VUSD>)
	352: MutBorrowLoc[55](loc49: Coin<VUSD>)
	353: Call coin::balance_mut<VUSD>(&mut Coin<VUSD>): &mut Balance<VUSD>
	354: CopyLoc[41](loc35: u64)
	355: Call balance::split<VUSD>(&mut Balance<VUSD>, u64): Balance<VUSD>
	356: StLoc[37](loc31: Balance<VUSD>)
	357: MoveLoc[55](loc49: Coin<VUSD>)
	358: MoveLoc[37](loc31: Balance<VUSD>)
	359: StLoc[13](loc7: Balance<VUSD>)
	360: StLoc[12](loc6: Coin<VUSD>)
	361: Branch(388)
B44:
	362: MutBorrowLoc[48](loc42: Coin<VUSD>)
	363: MoveLoc[21](loc15: u64)
	364: MoveLoc[5](Arg5: &mut TxContext)
	365: Call coin::split<VUSD>(&mut Coin<VUSD>, u64, &mut TxContext): Coin<VUSD>
	366: StLoc[56](loc50: Coin<VUSD>)
	367: MutBorrowLoc[48](loc42: Coin<VUSD>)
	368: Call coin::balance_mut<VUSD>(&mut Coin<VUSD>): &mut Balance<VUSD>
	369: CopyLoc[41](loc35: u64)
	370: Call balance::split<VUSD>(&mut Balance<VUSD>, u64): Balance<VUSD>
	371: StLoc[38](loc32: Balance<VUSD>)
	372: ImmBorrowLoc[48](loc42: Coin<VUSD>)
	373: Call coin::value<VUSD>(&Coin<VUSD>): u64
	374: LdU64(0)
	375: Gt
	376: BrFalse(382)
B45:
	377: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	378: CopyLoc[1](Arg1: &mut Treasury)
	379: MoveLoc[48](loc42: Coin<VUSD>)
	380: Call burn_vusd<Ty0>(&mut Vault<Ty0>, &mut Treasury, Coin<VUSD>)
	381: Branch(384)
B46:
	382: MoveLoc[48](loc42: Coin<VUSD>)
	383: Call coin::destroy_zero<VUSD>(Coin<VUSD>)
B47:
	384: MoveLoc[56](loc50: Coin<VUSD>)
	385: MoveLoc[38](loc32: Balance<VUSD>)
	386: StLoc[13](loc7: Balance<VUSD>)
	387: StLoc[12](loc6: Coin<VUSD>)
B48:
	388: MoveLoc[12](loc6: Coin<VUSD>)
	389: MoveLoc[13](loc7: Balance<VUSD>)
	390: StLoc[39](loc33: Balance<VUSD>)
	391: StLoc[57](loc51: Coin<VUSD>)
	392: MoveLoc[1](Arg1: &mut Treasury)
	393: Call witness::witness(): VirtueCDP
	394: Call memo::interest(): String
	395: MoveLoc[39](loc33: Balance<VUSD>)
	396: Call vusd::collect<VUSD, VirtueCDP>(&mut Treasury, VirtueCDP, String, Balance<VUSD>)
	397: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	398: FreezeRef
	399: Call id<Ty0>(&Vault<Ty0>): ID
	400: MoveLoc[32](loc26: address)
	401: MoveLoc[23](loc17: u64)
	402: MoveLoc[30](loc24: u64)
	403: MoveLoc[41](loc35: u64)
	404: Call response::new<Ty0>(ID, address, u64, u64, u64): UpdateResponse<Ty0>
	405: StLoc[49](loc43: UpdateResponse<Ty0>)
	406: MoveLoc[26](loc20: Coin<Ty0>)
	407: MoveLoc[57](loc51: Coin<VUSD>)
	408: MoveLoc[49](loc43: UpdateResponse<Ty0>)
	409: Ret
}

public destroy_response<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: &Treasury, Arg2: UpdateResponse<Ty0>) {
L3:	loc0: u64
L4:	loc1: bool
L5:	loc2: u64
L6:	loc3: u64
L7:	loc4: &TypeName
L8:	loc5: u64
L9:	loc6: &vector<TypeName>
L10:	loc7: VecSet<TypeName>
B0:
	0: MoveLoc[1](Arg1: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: MoveLoc[2](Arg2: UpdateResponse<Ty0>)
	3: Call response::destroy<Ty0>(UpdateResponse<Ty0>): ID * address * u64 * u64 * u64 * VecSet<TypeName>
	4: StLoc[10](loc7: VecSet<TypeName>)
	5: Pop
	6: Pop
	7: Pop
	8: Pop
	9: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	10: FreezeRef
	11: Call id<Ty0>(&Vault<Ty0>): ID
	12: Neq
	13: BrFalse(15)
B1:
	14: Call err_wrong_vault_id()
B2:
	15: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	16: FreezeRef
	17: Call response_checklist<Ty0>(&Vault<Ty0>): &vector<TypeName>
	18: StLoc[9](loc6: &vector<TypeName>)
	19: CopyLoc[9](loc6: &vector<TypeName>)
	20: VecLen(16)
	21: StLoc[3](loc0: u64)
	22: LdU64(0)
	23: StLoc[6](loc3: u64)
	24: MoveLoc[3](loc0: u64)
	25: StLoc[8](loc5: u64)
B3:
	26: CopyLoc[6](loc3: u64)
	27: CopyLoc[8](loc5: u64)
	28: Lt
	29: BrFalse(51)
B4:
	30: CopyLoc[6](loc3: u64)
	31: StLoc[5](loc2: u64)
	32: CopyLoc[9](loc6: &vector<TypeName>)
	33: MoveLoc[5](loc2: u64)
	34: VecImmBorrow(16)
	35: StLoc[7](loc4: &TypeName)
	36: ImmBorrowLoc[10](loc7: VecSet<TypeName>)
	37: MoveLoc[7](loc4: &TypeName)
	38: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	39: Not
	40: BrFalse(46)
B5:
	41: MoveLoc[9](loc6: &vector<TypeName>)
	42: Pop
	43: LdFalse
	44: StLoc[4](loc1: bool)
	45: Branch(55)
B6:
	46: MoveLoc[6](loc3: u64)
	47: LdU64(1)
	48: Add
	49: StLoc[6](loc3: u64)
	50: Branch(26)
B7:
	51: MoveLoc[9](loc6: &vector<TypeName>)
	52: Pop
	53: LdTrue
	54: StLoc[4](loc1: bool)
B8:
	55: MoveLoc[4](loc1: bool)
	56: Not
	57: BrFalse(59)
B9:
	58: Call err_missing_response_witness()
B10:
	59: Ret
}

public liquidate<Ty0, Ty1: drop>(Arg0: &mut Vault<Ty0>, Arg1: &Treasury, Arg2: &Clock, Arg3: &PriceResult<Ty0>, Arg4: address, Arg5: Coin<VUSD>, Arg6: Ty1, Arg7: &mut TxContext): UpdateRequest<Ty0> {
L8:	loc0: u64
L9:	loc1: Float
L10:	loc2: u64
L11:	loc3: Float
L12:	loc4: u64
L13:	loc5: Float
L14:	loc6: u64
L15:	loc7: u64
L16:	loc8: u64
L17:	loc9: Float
B0:
	0: MoveLoc[1](Arg1: &Treasury)
	1: Call version::assert_valid_package(&Treasury)
	2: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	3: ImmBorrowFieldGeneric[1](Vault.liquidation_rule: TypeName)
	4: ReadRef
	5: Call type_name::get<Ty1>(): TypeName
	6: Neq
	7: BrFalse(9)
B1:
	8: Call err_invalid_liquidation()
B2:
	9: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	10: FreezeRef
	11: CopyLoc[4](Arg4: address)
	12: MoveLoc[2](Arg2: &Clock)
	13: Call get_position_data<Ty0>(&Vault<Ty0>, address, &Clock): u64 * u64
	14: StLoc[12](loc4: u64)
	15: StLoc[8](loc0: u64)
	16: LdU64(10)
	17: StLoc[14](loc6: u64)
	18: LdU64(0)
	19: Call float::from(u64): Float
	20: StLoc[17](loc9: Float)
	21: CopyLoc[14](loc6: u64)
	22: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	23: FreezeRef
	24: Call decimal<Ty0>(&Vault<Ty0>): u8
	25: Call u64::pow(u64, u8): u64
	26: StLoc[10](loc2: u64)
	27: MoveLoc[14](loc6: u64)
	28: Call vusd::decimal(): u8
	29: Call u64::pow(u64, u8): u64
	30: StLoc[15](loc7: u64)
	31: CopyLoc[8](loc0: u64)
	32: MoveLoc[10](loc2: u64)
	33: Call float::from_fraction(u64, u64): Float
	34: StLoc[9](loc1: Float)
	35: CopyLoc[12](loc4: u64)
	36: MoveLoc[15](loc7: u64)
	37: Call float::from_fraction(u64, u64): Float
	38: StLoc[13](loc5: Float)
	39: CopyLoc[13](loc5: Float)
	40: MoveLoc[17](loc9: Float)
	41: Call float::eq(Float, Float): bool
	42: BrFalse(44)
B3:
	43: Call err_position_is_healthy()
B4:
	44: MoveLoc[3](Arg3: &PriceResult<Ty0>)
	45: Call result::aggregated_price<Ty0>(&PriceResult<Ty0>): Float
	46: StLoc[11](loc3: Float)
	47: MoveLoc[9](loc1: Float)
	48: MoveLoc[11](loc3: Float)
	49: Call float::mul(Float, Float): Float
	50: MoveLoc[13](loc5: Float)
	51: Call float::div(Float, Float): Float
	52: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	53: ImmBorrowFieldGeneric[7](Vault.min_collateral_ratio: Float)
	54: ReadRef
	55: Call float::gte(Float, Float): bool
	56: BrFalse(58)
B5:
	57: Call err_position_is_healthy()
B6:
	58: ImmBorrowLoc[5](Arg5: Coin<VUSD>)
	59: Call coin::value<VUSD>(&Coin<VUSD>): u64
	60: CopyLoc[12](loc4: u64)
	61: Gt
	62: BrFalse(64)
B7:
	63: Call err_invalid_liquidation()
B8:
	64: ImmBorrowLoc[5](Arg5: Coin<VUSD>)
	65: Call coin::value<VUSD>(&Coin<VUSD>): u64
	66: Call double::from(u64): Double
	67: CopyLoc[8](loc0: u64)
	68: Call double::mul_u64(Double, u64): Double
	69: MoveLoc[12](loc4: u64)
	70: Call double::div_u64(Double, u64): Double
	71: Call double::floor(Double): u64
	72: StLoc[16](loc8: u64)
	73: CopyLoc[16](loc8: u64)
	74: CopyLoc[8](loc0: u64)
	75: Gt
	76: BrFalse(79)
B9:
	77: MoveLoc[8](loc0: u64)
	78: StLoc[16](loc8: u64)
B10:
	79: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	80: FreezeRef
	81: Call id<Ty0>(&Vault<Ty0>): ID
	82: MoveLoc[4](Arg4: address)
	83: MoveLoc[7](Arg7: &mut TxContext)
	84: Call coin::zero<Ty0>(&mut TxContext): Coin<Ty0>
	85: LdU64(0)
	86: MoveLoc[5](Arg5: Coin<VUSD>)
	87: MoveLoc[16](loc8: u64)
	88: Call memo::liquidate(): String
	89: Call request::request_internal<Ty0>(ID, address, Coin<Ty0>, u64, Coin<VUSD>, u64, String): UpdateRequest<Ty0>
	90: Ret
}

public decimal<Ty0>(Arg0: &Vault<Ty0>): u8 {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[8](Vault.decimal: u8)
	2: ReadRef
	3: Ret
}

public interest_rate<Ty0>(Arg0: &Vault<Ty0>): Double {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[5](Vault.interest_rate: Double)
	2: ReadRef
	3: Ret
}

public limited_supply<Ty0>(Arg0: &Vault<Ty0>): &LimitedSupply {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[0](Vault.limited_supply: LimitedSupply)
	2: Ret
}

public min_collateral_ratio<Ty0>(Arg0: &Vault<Ty0>): Float {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[7](Vault.min_collateral_ratio: Float)
	2: ReadRef
	3: Ret
}

public liquidation_rule<Ty0>(Arg0: &Vault<Ty0>): TypeName {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[1](Vault.liquidation_rule: TypeName)
	2: ReadRef
	3: Ret
}

public request_checklist<Ty0>(Arg0: &Vault<Ty0>): &vector<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[2](Vault.request_checklist: vector<TypeName>)
	2: Ret
}

public response_checklist<Ty0>(Arg0: &Vault<Ty0>): &vector<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[3](Vault.response_checklist: vector<TypeName>)
	2: Ret
}

public position_table<Ty0>(Arg0: &Vault<Ty0>): &LinkedTable<address, Position> {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	2: Ret
}

public position_exists<Ty0>(Arg0: &Vault<Ty0>, Arg1: address): bool {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: Call position_table<Ty0>(&Vault<Ty0>): &LinkedTable<address, Position>
	2: MoveLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	4: Ret
}

public get_position_data<Ty0>(Arg0: &Vault<Ty0>, Arg1: address, Arg2: &Clock): u64 * u64 {
L3:	loc0: Double
L4:	loc1: &Position
B0:
	0: CopyLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	4: Not
	5: BrFalse(7)
B1:
	6: Call err_debtor_not_found()
B2:
	7: CopyLoc[0](Arg0: &Vault<Ty0>)
	8: ImmBorrowFieldGeneric[5](Vault.interest_rate: Double)
	9: ReadRef
	10: StLoc[3](loc0: Double)
	11: MoveLoc[0](Arg0: &Vault<Ty0>)
	12: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	13: MoveLoc[1](Arg1: address)
	14: Call linked_table::borrow<address, Position>(&LinkedTable<address, Position>, address): &Position
	15: StLoc[4](loc1: &Position)
	16: CopyLoc[4](loc1: &Position)
	17: ImmBorrowField[6](Position.coll_amount: u64)
	18: ReadRef
	19: CopyLoc[4](loc1: &Position)
	20: ImmBorrowField[7](Position.debt_amount: u64)
	21: ReadRef
	22: MoveLoc[4](loc1: &Position)
	23: MoveLoc[2](Arg2: &Clock)
	24: MoveLoc[3](loc0: Double)
	25: Call interest_amount(&Position, &Clock, Double): u64
	26: Add
	27: Ret
}

public try_get_position_data<Ty0>(Arg0: &Vault<Ty0>, Arg1: address, Arg2: &Clock): u64 * u64 {
L3:	loc0: u64
L4:	loc1: u64
L5:	loc2: Double
L6:	loc3: &Position
B0:
	0: CopyLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	4: BrFalse(28)
B1:
	5: CopyLoc[0](Arg0: &Vault<Ty0>)
	6: ImmBorrowFieldGeneric[5](Vault.interest_rate: Double)
	7: ReadRef
	8: StLoc[5](loc2: Double)
	9: MoveLoc[0](Arg0: &Vault<Ty0>)
	10: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	11: MoveLoc[1](Arg1: address)
	12: Call linked_table::borrow<address, Position>(&LinkedTable<address, Position>, address): &Position
	13: StLoc[6](loc3: &Position)
	14: CopyLoc[6](loc3: &Position)
	15: ImmBorrowField[6](Position.coll_amount: u64)
	16: ReadRef
	17: CopyLoc[6](loc3: &Position)
	18: ImmBorrowField[7](Position.debt_amount: u64)
	19: ReadRef
	20: MoveLoc[6](loc3: &Position)
	21: MoveLoc[2](Arg2: &Clock)
	22: MoveLoc[5](loc2: Double)
	23: Call interest_amount(&Position, &Clock, Double): u64
	24: Add
	25: StLoc[4](loc1: u64)
	26: StLoc[3](loc0: u64)
	27: Branch(36)
B2:
	28: MoveLoc[0](Arg0: &Vault<Ty0>)
	29: Pop
	30: MoveLoc[2](Arg2: &Clock)
	31: Pop
	32: LdU64(0)
	33: LdU64(0)
	34: StLoc[4](loc1: u64)
	35: StLoc[3](loc0: u64)
B3:
	36: MoveLoc[3](loc0: u64)
	37: MoveLoc[4](loc1: u64)
	38: Ret
}

public get_raw_position_data<Ty0>(Arg0: &Vault<Ty0>, Arg1: address): u64 * u64 * u64 {
L2:	loc0: &Position
L3:	loc1: &LinkedTable<address, Position>
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: Call position_table<Ty0>(&Vault<Ty0>): &LinkedTable<address, Position>
	2: StLoc[3](loc1: &LinkedTable<address, Position>)
	3: CopyLoc[3](loc1: &LinkedTable<address, Position>)
	4: CopyLoc[1](Arg1: address)
	5: Call linked_table::contains<address, Position>(&LinkedTable<address, Position>, address): bool
	6: Not
	7: BrFalse(9)
B1:
	8: Call err_debtor_not_found()
B2:
	9: MoveLoc[3](loc1: &LinkedTable<address, Position>)
	10: MoveLoc[1](Arg1: address)
	11: Call linked_table::borrow<address, Position>(&LinkedTable<address, Position>, address): &Position
	12: StLoc[2](loc0: &Position)
	13: CopyLoc[2](loc0: &Position)
	14: ImmBorrowField[6](Position.coll_amount: u64)
	15: ReadRef
	16: CopyLoc[2](loc0: &Position)
	17: ImmBorrowField[7](Position.debt_amount: u64)
	18: ReadRef
	19: MoveLoc[2](loc0: &Position)
	20: ImmBorrowField[11](Position.timestamp: u64)
	21: ReadRef
	22: Ret
}

public position_is_healthy<Ty0>(Arg0: &Vault<Ty0>, Arg1: address, Arg2: &Clock, Arg3: &PriceResult<Ty0>): bool {
L4:	loc0: bool
L5:	loc1: u64
L6:	loc2: Float
L7:	loc3: u64
L8:	loc4: Float
L9:	loc5: u64
L10:	loc6: Float
L11:	loc7: u64
L12:	loc8: u64
B0:
	0: CopyLoc[0](Arg0: &Vault<Ty0>)
	1: MoveLoc[1](Arg1: address)
	2: MoveLoc[2](Arg2: &Clock)
	3: Call get_position_data<Ty0>(&Vault<Ty0>, address, &Clock): u64 * u64
	4: StLoc[9](loc5: u64)
	5: StLoc[5](loc1: u64)
	6: CopyLoc[9](loc5: u64)
	7: LdU64(0)
	8: Gt
	9: BrFalse(43)
B1:
	10: LdU64(10)
	11: StLoc[11](loc7: u64)
	12: CopyLoc[11](loc7: u64)
	13: CopyLoc[0](Arg0: &Vault<Ty0>)
	14: Call decimal<Ty0>(&Vault<Ty0>): u8
	15: Call u64::pow(u64, u8): u64
	16: StLoc[7](loc3: u64)
	17: MoveLoc[11](loc7: u64)
	18: Call vusd::decimal(): u8
	19: Call u64::pow(u64, u8): u64
	20: StLoc[12](loc8: u64)
	21: MoveLoc[5](loc1: u64)
	22: MoveLoc[7](loc3: u64)
	23: Call float::from_fraction(u64, u64): Float
	24: StLoc[6](loc2: Float)
	25: MoveLoc[9](loc5: u64)
	26: MoveLoc[12](loc8: u64)
	27: Call float::from_fraction(u64, u64): Float
	28: StLoc[10](loc6: Float)
	29: MoveLoc[3](Arg3: &PriceResult<Ty0>)
	30: Call result::aggregated_price<Ty0>(&PriceResult<Ty0>): Float
	31: StLoc[8](loc4: Float)
	32: MoveLoc[6](loc2: Float)
	33: MoveLoc[8](loc4: Float)
	34: Call float::mul(Float, Float): Float
	35: MoveLoc[10](loc6: Float)
	36: Call float::div(Float, Float): Float
	37: MoveLoc[0](Arg0: &Vault<Ty0>)
	38: ImmBorrowFieldGeneric[7](Vault.min_collateral_ratio: Float)
	39: ReadRef
	40: Call float::gte(Float, Float): bool
	41: StLoc[4](loc0: bool)
	42: Branch(49)
B2:
	43: MoveLoc[0](Arg0: &Vault<Ty0>)
	44: Pop
	45: MoveLoc[3](Arg3: &PriceResult<Ty0>)
	46: Pop
	47: LdTrue
	48: StLoc[4](loc0: bool)
B3:
	49: MoveLoc[4](loc0: bool)
	50: Ret
}

public id<Ty0>(Arg0: &Vault<Ty0>): ID {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: Call object::id<Vault<Ty0>>(&Vault<Ty0>): ID
	2: Ret
}

public balance<Ty0>(Arg0: &Vault<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &Vault<Ty0>)
	1: ImmBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	2: Call balance::value<Ty0>(&Balance<Ty0>): u64
	3: Ret
}

public get_positions<Ty0>(Arg0: &Vault<Ty0>, Arg1: &Clock, Arg2: Option<address>, Arg3: u64): vector<PositionData> * Option<address> {
L4:	loc0: bool
L5:	loc1: u64
L6:	loc2: u64
L7:	loc3: u64
L8:	loc4: address
L9:	loc5: vector<PositionData>
L10:	loc6: &LinkedTable<address, Position>
B0:
	0: VecPack(102, 0)
	1: StLoc[9](loc5: vector<PositionData>)
	2: CopyLoc[0](Arg0: &Vault<Ty0>)
	3: ImmBorrowFieldGeneric[4](Vault.position_table: LinkedTable<address, Position>)
	4: StLoc[10](loc6: &LinkedTable<address, Position>)
	5: ImmBorrowLoc[2](Arg2: Option<address>)
	6: Call option::is_none<address>(&Option<address>): bool
	7: BrFalse(12)
B1:
	8: CopyLoc[10](loc6: &LinkedTable<address, Position>)
	9: Call linked_table::front<address, Position>(&LinkedTable<address, Position>): &Option<address>
	10: ReadRef
	11: StLoc[2](Arg2: Option<address>)
B2:
	12: LdU64(0)
	13: StLoc[6](loc2: u64)
B3:
	14: ImmBorrowLoc[2](Arg2: Option<address>)
	15: Call option::is_some<address>(&Option<address>): bool
	16: BrFalse(22)
B4:
	17: CopyLoc[6](loc2: u64)
	18: CopyLoc[3](Arg3: u64)
	19: Lt
	20: StLoc[4](loc0: bool)
	21: Branch(24)
B5:
	22: LdFalse
	23: StLoc[4](loc0: bool)
B6:
	24: MoveLoc[4](loc0: bool)
	25: BrFalse(52)
B7:
	26: ImmBorrowLoc[2](Arg2: Option<address>)
	27: Call option::borrow<address>(&Option<address>): &address
	28: ReadRef
	29: StLoc[8](loc4: address)
	30: CopyLoc[0](Arg0: &Vault<Ty0>)
	31: CopyLoc[8](loc4: address)
	32: CopyLoc[1](Arg1: &Clock)
	33: Call get_position_data<Ty0>(&Vault<Ty0>, address, &Clock): u64 * u64
	34: StLoc[7](loc3: u64)
	35: StLoc[5](loc1: u64)
	36: MutBorrowLoc[9](loc5: vector<PositionData>)
	37: CopyLoc[8](loc4: address)
	38: MoveLoc[5](loc1: u64)
	39: MoveLoc[7](loc3: u64)
	40: Pack[2](PositionData)
	41: VecPushBack(102)
	42: MoveLoc[6](loc2: u64)
	43: LdU64(1)
	44: Add
	45: StLoc[6](loc2: u64)
	46: CopyLoc[10](loc6: &LinkedTable<address, Position>)
	47: MoveLoc[8](loc4: address)
	48: Call linked_table::next<address, Position>(&LinkedTable<address, Position>, address): &Option<address>
	49: ReadRef
	50: StLoc[2](Arg2: Option<address>)
	51: Branch(14)
B8:
	52: MoveLoc[0](Arg0: &Vault<Ty0>)
	53: Pop
	54: MoveLoc[10](loc6: &LinkedTable<address, Position>)
	55: Pop
	56: MoveLoc[1](Arg1: &Clock)
	57: Pop
	58: MoveLoc[9](loc5: vector<PositionData>)
	59: MoveLoc[2](Arg2: Option<address>)
	60: Ret
}

public position_data(Arg0: &PositionData): address * u64 * u64 {
B0:
	0: CopyLoc[0](Arg0: &PositionData)
	1: ImmBorrowField[12](PositionData.debtor: address)
	2: ReadRef
	3: CopyLoc[0](Arg0: &PositionData)
	4: ImmBorrowField[13](PositionData.coll_amount: u64)
	5: ReadRef
	6: MoveLoc[0](Arg0: &PositionData)
	7: ImmBorrowField[14](PositionData.debt_amount: u64)
	8: ReadRef
	9: Ret
}

mint_vusd<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: &mut Treasury, Arg2: u64, Arg3: &mut TxContext): Coin<VUSD> {
L4:	loc0: ModuleRequest<VirtueCDP>
B0:
	0: Call witness::witness(): VirtueCDP
	1: Call version::package_version(): u64
	2: Call module_request::new<VirtueCDP>(VirtueCDP, u64): ModuleRequest<VirtueCDP>
	3: StLoc[4](loc0: ModuleRequest<VirtueCDP>)
	4: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	5: MutBorrowFieldGeneric[0](Vault.limited_supply: LimitedSupply)
	6: CopyLoc[2](Arg2: u64)
	7: Call limited_supply::increase(&mut LimitedSupply, u64): u64
	8: Pop
	9: MoveLoc[1](Arg1: &mut Treasury)
	10: ImmBorrowLoc[4](loc0: ModuleRequest<VirtueCDP>)
	11: MoveLoc[2](Arg2: u64)
	12: MoveLoc[3](Arg3: &mut TxContext)
	13: Call vusd::mint<VirtueCDP>(&mut Treasury, &ModuleRequest<VirtueCDP>, u64, &mut TxContext): Coin<VUSD>
	14: Ret
}

burn_vusd<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: &mut Treasury, Arg2: Coin<VUSD>) {
L3:	loc0: ModuleRequest<VirtueCDP>
B0:
	0: Call witness::witness(): VirtueCDP
	1: Call version::package_version(): u64
	2: Call module_request::new<VirtueCDP>(VirtueCDP, u64): ModuleRequest<VirtueCDP>
	3: StLoc[3](loc0: ModuleRequest<VirtueCDP>)
	4: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	5: MutBorrowFieldGeneric[0](Vault.limited_supply: LimitedSupply)
	6: ImmBorrowLoc[2](Arg2: Coin<VUSD>)
	7: Call coin::value<VUSD>(&Coin<VUSD>): u64
	8: Call limited_supply::decrease(&mut LimitedSupply, u64): u64
	9: Pop
	10: MoveLoc[1](Arg1: &mut Treasury)
	11: ImmBorrowLoc[3](loc0: ModuleRequest<VirtueCDP>)
	12: MoveLoc[2](Arg2: Coin<VUSD>)
	13: Call vusd::burn<VirtueCDP>(&mut Treasury, &ModuleRequest<VirtueCDP>, Coin<VUSD>)
	14: Ret
}

interest_amount(Arg0: &Position, Arg1: &Clock, Arg2: Double): u64 {
L3:	loc0: u64
B0:
	0: MoveLoc[1](Arg1: &Clock)
	1: Call clock::timestamp_ms(&Clock): u64
	2: CopyLoc[0](Arg0: &Position)
	3: ImmBorrowField[11](Position.timestamp: u64)
	4: ReadRef
	5: Sub
	6: StLoc[3](loc0: u64)
	7: MoveLoc[2](Arg2: Double)
	8: MoveLoc[3](loc0: u64)
	9: Call double::mul_u64(Double, u64): Double
	10: Call one_year(): u64
	11: Call double::div_u64(Double, u64): Double
	12: MoveLoc[0](Arg0: &Position)
	13: ImmBorrowField[7](Position.debt_amount: u64)
	14: ReadRef
	15: Call double::mul_u64(Double, u64): Double
	16: Call double::ceil(Double): u64
	17: Ret
}

accrue_interest(Arg0: &mut Position, Arg1: &Clock, Arg2: Double): u64 {
L3:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &mut Position)
	1: FreezeRef
	2: CopyLoc[1](Arg1: &Clock)
	3: MoveLoc[2](Arg2: Double)
	4: Call interest_amount(&Position, &Clock, Double): u64
	5: StLoc[3](loc0: u64)
	6: CopyLoc[0](Arg0: &mut Position)
	7: ImmBorrowField[7](Position.debt_amount: u64)
	8: ReadRef
	9: CopyLoc[3](loc0: u64)
	10: Add
	11: CopyLoc[0](Arg0: &mut Position)
	12: MutBorrowField[7](Position.debt_amount: u64)
	13: WriteRef
	14: MoveLoc[1](Arg1: &Clock)
	15: Call clock::timestamp_ms(&Clock): u64
	16: MoveLoc[0](Arg0: &mut Position)
	17: MutBorrowField[11](Position.timestamp: u64)
	18: WriteRef
	19: MoveLoc[3](loc0: u64)
	20: Ret
}

one_year(): u64 {
B0:
	0: LdU64(31536000000)
	1: Ret
}

err_not_enough_for_flashloan() {
B0:
	0: LdConst[10](u64: 411)
	1: Abort
}

public(friend) split<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: u64): Balance<Ty0> {
B0:
	0: CopyLoc[1](Arg1: u64)
	1: CopyLoc[0](Arg0: &mut Vault<Ty0>)
	2: ImmBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	3: Call balance::value<Ty0>(&Balance<Ty0>): u64
	4: Gt
	5: BrFalse(7)
B1:
	6: Call err_not_enough_for_flashloan()
B2:
	7: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	8: MutBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	9: MoveLoc[1](Arg1: u64)
	10: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	11: Ret
}

public(friend) join<Ty0>(Arg0: &mut Vault<Ty0>, Arg1: Balance<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: &mut Vault<Ty0>)
	1: MutBorrowFieldGeneric[6](Vault.balance: Balance<Ty0>)
	2: MoveLoc[1](Arg1: Balance<Ty0>)
	3: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	4: Pop
	5: Ret
}

Constants [
	0 => u64: 401
	1 => u64: 402
	2 => u64: 403
	3 => u64: 404
	4 => u64: 405
	5 => u64: 406
	6 => u64: 407
	7 => u64: 408
	8 => u64: 409
	9 => u64: 410
	10 => u64: 411
]
}
