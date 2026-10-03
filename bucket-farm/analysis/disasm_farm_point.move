// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.point {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::event;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::pool;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::profile;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::stake;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::state;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::account;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::float;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::linked_table;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::package;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;

struct PointCenter<phantom Ty0> has store, key {
	id: UID,
	cap: TreasuryCap<Ty0>,
	buffer: Balance<Ty0>,
	user_profiles: LinkedTable<address, Profile<Ty0>>,
	pool_states: VecMap<ID, PoolState>,
	claimable: bool,
	stake_policy: vector<TypeName>,
	unstake_policy: vector<TypeName>
}

struct POINT has drop {
	dummy_field: bool
}

struct AccountPoints has copy, drop {
	account: address,
	points: u64
}

struct AccountInfo has copy, drop {
	points: u64,
	pool_ids: vector<ID>,
	stake_vec: vector<u64>,
	cumulative_vec: vector<u64>
}

err_invalid_start_time() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_pool_not_exists() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

err_points_not_claimable() {
B0:
	0: LdConst[2](u64: 2)
	1: Abort
}

err_points_not_enough() {
B0:
	0: LdConst[3](u64: 3)
	1: Abort
}

err_account_not_found() {
B0:
	0: LdConst[4](u64: 4)
	1: Abort
}

err_stake_policy_not_fulfilled() {
B0:
	0: LdConst[5](u64: 5)
	1: Abort
}

err_unstake_policy_not_fulfilled() {
B0:
	0: LdConst[6](u64: 6)
	1: Abort
}

init(Arg0: POINT, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: POINT)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call package::claim_and_keep<POINT>(POINT, &mut TxContext)
	3: Ret
}

public new<Ty0>(Arg0: TreasuryCap<Ty0>, Arg1: bool, Arg2: &mut TxContext): PointCenter<Ty0> * AdminCap<Ty0> {
L3:	loc0: AdminCap<Ty0>
L4:	loc1: PointCenter<Ty0>
B0:
	0: CopyLoc[2](Arg2: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: MoveLoc[0](Arg0: TreasuryCap<Ty0>)
	3: Call balance::zero<Ty0>(): Balance<Ty0>
	4: CopyLoc[2](Arg2: &mut TxContext)
	5: Call linked_table::new<address, Profile<Ty0>>(&mut TxContext): LinkedTable<address, Profile<Ty0>>
	6: Call vec_map::empty<ID, PoolState>(): VecMap<ID, PoolState>
	7: MoveLoc[1](Arg1: bool)
	8: VecPack(49, 0)
	9: VecPack(49, 0)
	10: PackGeneric[0](PointCenter<Ty0>)
	11: StLoc[4](loc1: PointCenter<Ty0>)
	12: MoveLoc[2](Arg2: &mut TxContext)
	13: Call admin::new<Ty0>(&mut TxContext): AdminCap<Ty0>
	14: StLoc[3](loc0: AdminCap<Ty0>)
	15: ImmBorrowLoc[4](loc1: PointCenter<Ty0>)
	16: Call object::id<PointCenter<Ty0>>(&PointCenter<Ty0>): ID
	17: ImmBorrowLoc[3](loc0: AdminCap<Ty0>)
	18: Call object::id<AdminCap<Ty0>>(&AdminCap<Ty0>): ID
	19: Call event::emit_new_center<Ty0>(ID, ID)
	20: MoveLoc[4](loc1: PointCenter<Ty0>)
	21: MoveLoc[3](loc0: AdminCap<Ty0>)
	22: Ret
}

entry default<Ty0>(Arg0: TreasuryCap<Ty0>, Arg1: bool, Arg2: &mut TxContext) {
L3:	loc0: AdminCap<Ty0>
B0:
	0: MoveLoc[0](Arg0: TreasuryCap<Ty0>)
	1: MoveLoc[1](Arg1: bool)
	2: CopyLoc[2](Arg2: &mut TxContext)
	3: Call new<Ty0>(TreasuryCap<Ty0>, bool, &mut TxContext): PointCenter<Ty0> * AdminCap<Ty0>
	4: StLoc[3](loc0: AdminCap<Ty0>)
	5: Call transfer::share_object<PointCenter<Ty0>>(PointCenter<Ty0>)
	6: MoveLoc[3](loc0: AdminCap<Ty0>)
	7: MoveLoc[2](Arg2: &mut TxContext)
	8: FreezeRef
	9: Call tx_context::sender(&TxContext): address
	10: Call transfer::public_transfer<AdminCap<Ty0>>(AdminCap<Ty0>, address)
	11: Ret
}

public burn<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: Coin<Ty0>): u64 {
L2:	loc0: u64
L3:	loc1: u64
B0:
	0: ImmBorrowLoc[1](Arg1: Coin<Ty0>)
	1: Call coin::value<Ty0>(&Coin<Ty0>): u64
	2: StLoc[2](loc0: u64)
	3: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	4: MutBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	5: MoveLoc[1](Arg1: Coin<Ty0>)
	6: Call coin::burn<Ty0>(&mut TreasuryCap<Ty0>, Coin<Ty0>): u64
	7: StLoc[3](loc1: u64)
	8: CopyLoc[2](loc0: u64)
	9: MoveLoc[3](loc1: u64)
	10: Call option::none<TypeName>(): Option<TypeName>
	11: Call event::emit_burn<Ty0>(u64, u64, Option<TypeName>)
	12: MoveLoc[2](loc0: u64)
	13: Ret
}

public burn_with_witness<Ty0, Ty1: drop>(Arg0: &mut PointCenter<Ty0>, Arg1: Coin<Ty0>, Arg2: Ty1): u64 {
L3:	loc0: u64
L4:	loc1: u64
B0:
	0: ImmBorrowLoc[1](Arg1: Coin<Ty0>)
	1: Call coin::value<Ty0>(&Coin<Ty0>): u64
	2: StLoc[3](loc0: u64)
	3: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	4: MutBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	5: MoveLoc[1](Arg1: Coin<Ty0>)
	6: Call coin::burn<Ty0>(&mut TreasuryCap<Ty0>, Coin<Ty0>): u64
	7: StLoc[4](loc1: u64)
	8: CopyLoc[3](loc0: u64)
	9: MoveLoc[4](loc1: u64)
	10: Call type_name::get<Ty1>(): TypeName
	11: Call option::some<TypeName>(TypeName): Option<TypeName>
	12: Call event::emit_burn<Ty0>(u64, u64, Option<TypeName>)
	13: MoveLoc[3](loc0: u64)
	14: Ret
}

public new_pool<Ty0, Ty1>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &Clock, Arg3: Float, Arg4: u64, Arg5: &mut TxContext): DegenPool<Ty0, Ty1> {
L6:	loc0: DegenPool<Ty0, Ty1>
L7:	loc1: ID
L8:	loc2: PoolState
B0:
	0: CopyLoc[4](Arg4: u64)
	1: MoveLoc[2](Arg2: &Clock)
	2: Call clock::timestamp_ms(&Clock): u64
	3: Lt
	4: BrFalse(6)
B1:
	5: Call err_invalid_start_time()
B2:
	6: MoveLoc[5](Arg5: &mut TxContext)
	7: Call pool::new<Ty0, Ty1>(&mut TxContext): DegenPool<Ty0, Ty1>
	8: StLoc[6](loc0: DegenPool<Ty0, Ty1>)
	9: ImmBorrowLoc[6](loc0: DegenPool<Ty0, Ty1>)
	10: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	11: StLoc[7](loc1: ID)
	12: MoveLoc[3](Arg3: Float)
	13: MoveLoc[4](Arg4: u64)
	14: LdU64(0)
	15: Call float::from(u64): Float
	16: Call state::new<Ty1>(Float, u64, Float): PoolState
	17: StLoc[8](loc2: PoolState)
	18: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	19: MutBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	20: MoveLoc[7](loc1: ID)
	21: MoveLoc[8](loc2: PoolState)
	22: Call vec_map::insert<ID, PoolState>(&mut VecMap<ID, PoolState>, ID, PoolState)
	23: ImmBorrowLoc[6](loc0: DegenPool<Ty0, Ty1>)
	24: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	25: Call event::emit_new_pool<Ty0, Ty1>(ID)
	26: MoveLoc[6](loc0: DegenPool<Ty0, Ty1>)
	27: Ret
}

public create_pool<Ty0, Ty1>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &Clock, Arg3: u64, Arg4: u64, Arg5: u64, Arg6: &mut TxContext): ID {
L7:	loc0: Float
L8:	loc1: DegenPool<Ty0, Ty1>
L9:	loc2: ID
B0:
	0: MoveLoc[3](Arg3: u64)
	1: MoveLoc[4](Arg4: u64)
	2: Call float::from_fraction(u64, u64): Float
	3: StLoc[7](loc0: Float)
	4: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	5: MoveLoc[1](Arg1: &AdminCap<Ty0>)
	6: MoveLoc[2](Arg2: &Clock)
	7: MoveLoc[7](loc0: Float)
	8: MoveLoc[5](Arg5: u64)
	9: MoveLoc[6](Arg6: &mut TxContext)
	10: Call new_pool<Ty0, Ty1>(&mut PointCenter<Ty0>, &AdminCap<Ty0>, &Clock, Float, u64, &mut TxContext): DegenPool<Ty0, Ty1>
	11: StLoc[8](loc1: DegenPool<Ty0, Ty1>)
	12: ImmBorrowLoc[8](loc1: DegenPool<Ty0, Ty1>)
	13: Call object::id<DegenPool<Ty0, Ty1>>(&DegenPool<Ty0, Ty1>): ID
	14: StLoc[9](loc2: ID)
	15: MoveLoc[8](loc1: DegenPool<Ty0, Ty1>)
	16: Call transfer::public_share_object<DegenPool<Ty0, Ty1>>(DegenPool<Ty0, Ty1>)
	17: MoveLoc[9](loc2: ID)
	18: Ret
}

public set_flow_rate<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &Clock, Arg3: &ID, Arg4: u64, Arg5: u64) {
L6:	loc0: Float
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: MoveLoc[2](Arg2: &Clock)
	2: CopyLoc[3](Arg3: &ID)
	3: Call update_pool_state<Ty0>(&mut PointCenter<Ty0>, &Clock, &ID)
	4: MoveLoc[4](Arg4: u64)
	5: MoveLoc[5](Arg5: u64)
	6: Call float::from_fraction(u64, u64): Float
	7: StLoc[6](loc0: Float)
	8: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	9: MutBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	10: MoveLoc[3](Arg3: &ID)
	11: Call vec_map::get_mut<ID, PoolState>(&mut VecMap<ID, PoolState>, &ID): &mut PoolState
	12: MoveLoc[6](loc0: Float)
	13: Call state::set_flow_rate(&mut PoolState, Float)
	14: Ret
}

public end_pool<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &Clock, Arg3: &ID) {
B0:
	0: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: MoveLoc[1](Arg1: &AdminCap<Ty0>)
	2: MoveLoc[2](Arg2: &Clock)
	3: MoveLoc[3](Arg3: &ID)
	4: LdU64(0)
	5: LdU64(1)
	6: Call set_flow_rate<Ty0>(&mut PointCenter<Ty0>, &AdminCap<Ty0>, &Clock, &ID, u64, u64)
	7: Ret
}

public end_all_pools<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &Clock) {
L3:	loc0: ID
L4:	loc1: vector<ID>
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	3: Call vec_map::keys<ID, PoolState>(&VecMap<ID, PoolState>): vector<ID>
	4: StLoc[4](loc1: vector<ID>)
	5: MutBorrowLoc[4](loc1: vector<ID>)
	6: Call vector::reverse<ID>(&mut vector<ID>)
B1:
	7: ImmBorrowLoc[4](loc1: vector<ID>)
	8: VecLen(10)
	9: LdU64(0)
	10: Neq
	11: BrFalse(22)
B2:
	12: Branch(13)
B3:
	13: MutBorrowLoc[4](loc1: vector<ID>)
	14: VecPopBack(10)
	15: StLoc[3](loc0: ID)
	16: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	17: CopyLoc[1](Arg1: &AdminCap<Ty0>)
	18: CopyLoc[2](Arg2: &Clock)
	19: ImmBorrowLoc[3](loc0: ID)
	20: Call end_pool<Ty0>(&mut PointCenter<Ty0>, &AdminCap<Ty0>, &Clock, &ID)
	21: Branch(7)
B4:
	22: MoveLoc[2](Arg2: &Clock)
	23: Pop
	24: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	25: Pop
	26: MoveLoc[1](Arg1: &AdminCap<Ty0>)
	27: Pop
	28: MoveLoc[4](loc1: vector<ID>)
	29: VecUnpack(10, 0)
	30: Ret
}

public toggle_claimable<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>) {
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call claimable<Ty0>(&PointCenter<Ty0>): bool
	3: Not
	4: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	5: MutBorrowFieldGeneric[2](PointCenter.claimable: bool)
	6: WriteRef
	7: Ret
}

public borrow_treasury_cap<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &AdminCap<Ty0>): &TreasuryCap<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	2: Ret
}

public add_rule<Ty0, Ty1>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: bool) {
L3:	loc0: TypeName
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: MoveLoc[2](Arg2: bool)
	3: BrFalse(19)
B1:
	4: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	5: FreezeRef
	6: Call stake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	7: ImmBorrowLoc[3](loc0: TypeName)
	8: Call vector::contains<TypeName>(&vector<TypeName>, &TypeName): bool
	9: Not
	10: BrFalse(16)
B2:
	11: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	12: MutBorrowFieldGeneric[3](PointCenter.stake_policy: vector<TypeName>)
	13: MoveLoc[3](loc0: TypeName)
	14: VecPushBack(49)
	15: Branch(33)
B3:
	16: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	17: Pop
	18: Branch(33)
B4:
	19: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	20: FreezeRef
	21: Call unstake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	22: ImmBorrowLoc[3](loc0: TypeName)
	23: Call vector::contains<TypeName>(&vector<TypeName>, &TypeName): bool
	24: Not
	25: BrFalse(31)
B5:
	26: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	27: MutBorrowFieldGeneric[4](PointCenter.unstake_policy: vector<TypeName>)
	28: MoveLoc[3](loc0: TypeName)
	29: VecPushBack(49)
	30: Branch(33)
B6:
	31: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	32: Pop
B7:
	33: Ret
}

public remove_rule<Ty0, Ty1>(Arg0: &mut PointCenter<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: bool) {
L3:	loc0: u64
L4:	loc1: u64
L5:	loc2: Option<u64>
L6:	loc3: Option<u64>
L7:	loc4: u64
L8:	loc5: u64
L9:	loc6: u64
L10:	loc7: u64
L11:	loc8: Option<u64>
L12:	loc9: Option<u64>
L13:	loc10: TypeName
L14:	loc11: u64
L15:	loc12: u64
L16:	loc13: &vector<TypeName>
L17:	loc14: &vector<TypeName>
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[13](loc10: TypeName)
	2: MoveLoc[2](Arg2: bool)
	3: BrFalse(58)
B1:
	4: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	5: FreezeRef
	6: Call stake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	7: StLoc[16](loc13: &vector<TypeName>)
	8: CopyLoc[16](loc13: &vector<TypeName>)
	9: VecLen(49)
	10: StLoc[4](loc1: u64)
	11: LdU64(0)
	12: StLoc[9](loc6: u64)
	13: MoveLoc[4](loc1: u64)
	14: StLoc[15](loc12: u64)
B2:
	15: CopyLoc[9](loc6: u64)
	16: CopyLoc[15](loc12: u64)
	17: Lt
	18: BrFalse(38)
B3:
	19: CopyLoc[9](loc6: u64)
	20: StLoc[10](loc7: u64)
	21: CopyLoc[16](loc13: &vector<TypeName>)
	22: CopyLoc[10](loc7: u64)
	23: VecImmBorrow(49)
	24: ImmBorrowLoc[13](loc10: TypeName)
	25: Eq
	26: BrFalse(33)
B4:
	27: MoveLoc[16](loc13: &vector<TypeName>)
	28: Pop
	29: MoveLoc[10](loc7: u64)
	30: Call option::some<u64>(u64): Option<u64>
	31: StLoc[5](loc2: Option<u64>)
	32: Branch(42)
B5:
	33: MoveLoc[9](loc6: u64)
	34: LdU64(1)
	35: Add
	36: StLoc[9](loc6: u64)
	37: Branch(15)
B6:
	38: MoveLoc[16](loc13: &vector<TypeName>)
	39: Pop
	40: Call option::none<u64>(): Option<u64>
	41: StLoc[5](loc2: Option<u64>)
B7:
	42: MoveLoc[5](loc2: Option<u64>)
	43: StLoc[11](loc8: Option<u64>)
	44: ImmBorrowLoc[11](loc8: Option<u64>)
	45: Call option::is_some<u64>(&Option<u64>): bool
	46: BrFalse(55)
B8:
	47: Branch(48)
B9:
	48: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	49: MutBorrowFieldGeneric[3](PointCenter.stake_policy: vector<TypeName>)
	50: MoveLoc[11](loc8: Option<u64>)
	51: Call option::destroy_some<u64>(Option<u64>): u64
	52: Call vector::swap_remove<TypeName>(&mut vector<TypeName>, u64): TypeName
	53: Pop
	54: Branch(110)
B10:
	55: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	56: Pop
	57: Branch(110)
B11:
	58: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	59: FreezeRef
	60: Call unstake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	61: StLoc[17](loc14: &vector<TypeName>)
	62: CopyLoc[17](loc14: &vector<TypeName>)
	63: VecLen(49)
	64: StLoc[3](loc0: u64)
	65: LdU64(0)
	66: StLoc[7](loc4: u64)
	67: MoveLoc[3](loc0: u64)
	68: StLoc[14](loc11: u64)
B12:
	69: CopyLoc[7](loc4: u64)
	70: CopyLoc[14](loc11: u64)
	71: Lt
	72: BrFalse(92)
B13:
	73: CopyLoc[7](loc4: u64)
	74: StLoc[8](loc5: u64)
	75: CopyLoc[17](loc14: &vector<TypeName>)
	76: CopyLoc[8](loc5: u64)
	77: VecImmBorrow(49)
	78: ImmBorrowLoc[13](loc10: TypeName)
	79: Eq
	80: BrFalse(87)
B14:
	81: MoveLoc[17](loc14: &vector<TypeName>)
	82: Pop
	83: MoveLoc[8](loc5: u64)
	84: Call option::some<u64>(u64): Option<u64>
	85: StLoc[6](loc3: Option<u64>)
	86: Branch(96)
B15:
	87: MoveLoc[7](loc4: u64)
	88: LdU64(1)
	89: Add
	90: StLoc[7](loc4: u64)
	91: Branch(69)
B16:
	92: MoveLoc[17](loc14: &vector<TypeName>)
	93: Pop
	94: Call option::none<u64>(): Option<u64>
	95: StLoc[6](loc3: Option<u64>)
B17:
	96: MoveLoc[6](loc3: Option<u64>)
	97: StLoc[12](loc9: Option<u64>)
	98: ImmBorrowLoc[12](loc9: Option<u64>)
	99: Call option::is_some<u64>(&Option<u64>): bool
	100: BrFalse(108)
B18:
	101: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	102: MutBorrowFieldGeneric[4](PointCenter.unstake_policy: vector<TypeName>)
	103: MoveLoc[12](loc9: Option<u64>)
	104: Call option::destroy_some<u64>(Option<u64>): u64
	105: Call vector::swap_remove<TypeName>(&mut vector<TypeName>, u64): TypeName
	106: Pop
	107: Branch(110)
B19:
	108: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	109: Pop
B20:
	110: Ret
}

public fulfill_stake<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock, Arg2: StakeResponse<Ty0>) {
L3:	loc0: u64
L4:	loc1: bool
L5:	loc2: u64
L6:	loc3: address
L7:	loc4: u64
L8:	loc5: TypeName
L9:	loc6: u64
L10:	loc7: u64
L11:	loc8: u64
L12:	loc9: ID
L13:	loc10: Float
L14:	loc11: &TypeName
L15:	loc12: Stake
L16:	loc13: &mut VecMap<ID, Stake>
L17:	loc14: u64
L18:	loc15: &vector<TypeName>
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call stake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	3: StLoc[18](loc15: &vector<TypeName>)
	4: CopyLoc[18](loc15: &vector<TypeName>)
	5: VecLen(49)
	6: StLoc[3](loc0: u64)
	7: LdU64(0)
	8: StLoc[11](loc8: u64)
	9: MoveLoc[3](loc0: u64)
	10: StLoc[17](loc14: u64)
B1:
	11: CopyLoc[11](loc8: u64)
	12: CopyLoc[17](loc14: u64)
	13: Lt
	14: BrFalse(37)
B2:
	15: CopyLoc[11](loc8: u64)
	16: StLoc[10](loc7: u64)
	17: CopyLoc[18](loc15: &vector<TypeName>)
	18: MoveLoc[10](loc7: u64)
	19: VecImmBorrow(49)
	20: StLoc[14](loc11: &TypeName)
	21: ImmBorrowLoc[2](Arg2: StakeResponse<Ty0>)
	22: Call pool::stake_res_witness<Ty0>(&StakeResponse<Ty0>): &VecSet<TypeName>
	23: MoveLoc[14](loc11: &TypeName)
	24: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	25: Not
	26: BrFalse(32)
B3:
	27: MoveLoc[18](loc15: &vector<TypeName>)
	28: Pop
	29: LdFalse
	30: StLoc[4](loc1: bool)
	31: Branch(41)
B4:
	32: MoveLoc[11](loc8: u64)
	33: LdU64(1)
	34: Add
	35: StLoc[11](loc8: u64)
	36: Branch(11)
B5:
	37: MoveLoc[18](loc15: &vector<TypeName>)
	38: Pop
	39: LdTrue
	40: StLoc[4](loc1: bool)
B6:
	41: MoveLoc[4](loc1: bool)
	42: Not
	43: BrFalse(46)
B7:
	44: Call err_stake_policy_not_fulfilled()
	45: Branch(46)
B8:
	46: MoveLoc[2](Arg2: StakeResponse<Ty0>)
	47: Call pool::destroy_stake_res<Ty0>(StakeResponse<Ty0>): ID * address * u64 * TypeName
	48: StLoc[8](loc5: TypeName)
	49: StLoc[7](loc4: u64)
	50: StLoc[6](loc3: address)
	51: StLoc[12](loc9: ID)
	52: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	53: MoveLoc[1](Arg1: &Clock)
	54: CopyLoc[6](loc3: address)
	55: Call settle_user_points<Ty0>(&mut PointCenter<Ty0>, &Clock, address): u64
	56: Pop
	57: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	58: FreezeRef
	59: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	60: ImmBorrowLoc[12](loc9: ID)
	61: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	62: Call state::unit(&PoolState): Float
	63: StLoc[13](loc10: Float)
	64: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	65: MutBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	66: ImmBorrowLoc[12](loc9: ID)
	67: Call vec_map::get_mut<ID, PoolState>(&mut VecMap<ID, PoolState>, &ID): &mut PoolState
	68: CopyLoc[7](loc4: u64)
	69: Call state::stake(&mut PoolState, u64): u64
	70: Pop
	71: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	72: FreezeRef
	73: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	74: CopyLoc[6](loc3: address)
	75: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	76: Not
	77: BrFalse(83)
B9:
	78: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	79: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	80: CopyLoc[6](loc3: address)
	81: Call profile::new<Ty0>(): Profile<Ty0>
	82: Call linked_table::push_back<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address, Profile<Ty0>)
B10:
	83: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	84: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	85: CopyLoc[6](loc3: address)
	86: Call linked_table::borrow_mut<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address): &mut Profile<Ty0>
	87: Call profile::stakes_mut<Ty0>(&mut Profile<Ty0>): &mut VecMap<ID, Stake>
	88: StLoc[16](loc13: &mut VecMap<ID, Stake>)
	89: CopyLoc[16](loc13: &mut VecMap<ID, Stake>)
	90: FreezeRef
	91: ImmBorrowLoc[12](loc9: ID)
	92: Call vec_map::contains<ID, Stake>(&VecMap<ID, Stake>, &ID): bool
	93: BrFalse(101)
B11:
	94: MoveLoc[16](loc13: &mut VecMap<ID, Stake>)
	95: ImmBorrowLoc[12](loc9: ID)
	96: Call vec_map::get_mut<ID, Stake>(&mut VecMap<ID, Stake>, &ID): &mut Stake
	97: CopyLoc[7](loc4: u64)
	98: Call stake::add(&mut Stake, u64): u64
	99: StLoc[5](loc2: u64)
	100: Branch(111)
B12:
	101: CopyLoc[7](loc4: u64)
	102: MoveLoc[13](loc10: Float)
	103: Call stake::new(u64, Float): Stake
	104: StLoc[15](loc12: Stake)
	105: MoveLoc[16](loc13: &mut VecMap<ID, Stake>)
	106: CopyLoc[12](loc9: ID)
	107: MoveLoc[15](loc12: Stake)
	108: Call vec_map::insert<ID, Stake>(&mut VecMap<ID, Stake>, ID, Stake)
	109: CopyLoc[7](loc4: u64)
	110: StLoc[5](loc2: u64)
B13:
	111: MoveLoc[5](loc2: u64)
	112: StLoc[9](loc6: u64)
	113: MoveLoc[12](loc9: ID)
	114: MoveLoc[8](loc5: TypeName)
	115: MoveLoc[6](loc3: address)
	116: MoveLoc[7](loc4: u64)
	117: MoveLoc[9](loc6: u64)
	118: Call event::emit_stake<Ty0>(ID, TypeName, address, u64, u64)
	119: Ret
}

public fulfill_unstake<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock, Arg2: UnstakeResponse<Ty0>) {
L3:	loc0: u64
L4:	loc1: bool
L5:	loc2: bool
L6:	loc3: address
L7:	loc4: u64
L8:	loc5: TypeName
L9:	loc6: u64
L10:	loc7: u64
L11:	loc8: u64
L12:	loc9: ID
L13:	loc10: &LinkedTable<address, Profile<Ty0>>
L14:	loc11: &TypeName
L15:	loc12: u64
L16:	loc13: &vector<TypeName>
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call unstake_policy<Ty0>(&PointCenter<Ty0>): &vector<TypeName>
	3: StLoc[16](loc13: &vector<TypeName>)
	4: CopyLoc[16](loc13: &vector<TypeName>)
	5: VecLen(49)
	6: StLoc[3](loc0: u64)
	7: LdU64(0)
	8: StLoc[11](loc8: u64)
	9: MoveLoc[3](loc0: u64)
	10: StLoc[15](loc12: u64)
B1:
	11: CopyLoc[11](loc8: u64)
	12: CopyLoc[15](loc12: u64)
	13: Lt
	14: BrFalse(37)
B2:
	15: CopyLoc[11](loc8: u64)
	16: StLoc[10](loc7: u64)
	17: CopyLoc[16](loc13: &vector<TypeName>)
	18: MoveLoc[10](loc7: u64)
	19: VecImmBorrow(49)
	20: StLoc[14](loc11: &TypeName)
	21: ImmBorrowLoc[2](Arg2: UnstakeResponse<Ty0>)
	22: Call pool::unstake_res_witness<Ty0>(&UnstakeResponse<Ty0>): &VecSet<TypeName>
	23: MoveLoc[14](loc11: &TypeName)
	24: Call vec_set::contains<TypeName>(&VecSet<TypeName>, &TypeName): bool
	25: Not
	26: BrFalse(32)
B3:
	27: MoveLoc[16](loc13: &vector<TypeName>)
	28: Pop
	29: LdFalse
	30: StLoc[4](loc1: bool)
	31: Branch(41)
B4:
	32: MoveLoc[11](loc8: u64)
	33: LdU64(1)
	34: Add
	35: StLoc[11](loc8: u64)
	36: Branch(11)
B5:
	37: MoveLoc[16](loc13: &vector<TypeName>)
	38: Pop
	39: LdTrue
	40: StLoc[4](loc1: bool)
B6:
	41: MoveLoc[4](loc1: bool)
	42: Not
	43: BrFalse(46)
B7:
	44: Call err_unstake_policy_not_fulfilled()
	45: Branch(46)
B8:
	46: MoveLoc[2](Arg2: UnstakeResponse<Ty0>)
	47: Call pool::destroy_unstake_res<Ty0>(UnstakeResponse<Ty0>): ID * address * u64 * TypeName
	48: StLoc[8](loc5: TypeName)
	49: StLoc[7](loc4: u64)
	50: StLoc[6](loc3: address)
	51: StLoc[12](loc9: ID)
	52: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	53: FreezeRef
	54: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	55: StLoc[13](loc10: &LinkedTable<address, Profile<Ty0>>)
	56: CopyLoc[13](loc10: &LinkedTable<address, Profile<Ty0>>)
	57: CopyLoc[6](loc3: address)
	58: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	59: Not
	60: BrFalse(66)
B9:
	61: MoveLoc[13](loc10: &LinkedTable<address, Profile<Ty0>>)
	62: Pop
	63: LdTrue
	64: StLoc[5](loc2: bool)
	65: Branch(74)
B10:
	66: MoveLoc[13](loc10: &LinkedTable<address, Profile<Ty0>>)
	67: CopyLoc[6](loc3: address)
	68: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	69: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	70: ImmBorrowLoc[12](loc9: ID)
	71: Call vec_map::contains<ID, Stake>(&VecMap<ID, Stake>, &ID): bool
	72: Not
	73: StLoc[5](loc2: bool)
B11:
	74: MoveLoc[5](loc2: bool)
	75: BrFalse(77)
B12:
	76: Call err_account_not_found()
B13:
	77: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	78: MoveLoc[1](Arg1: &Clock)
	79: CopyLoc[6](loc3: address)
	80: Call settle_user_points<Ty0>(&mut PointCenter<Ty0>, &Clock, address): u64
	81: Pop
	82: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	83: MutBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	84: ImmBorrowLoc[12](loc9: ID)
	85: Call vec_map::get_mut<ID, PoolState>(&mut VecMap<ID, PoolState>, &ID): &mut PoolState
	86: CopyLoc[7](loc4: u64)
	87: Call state::unstake(&mut PoolState, u64): u64
	88: Pop
	89: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	90: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	91: CopyLoc[6](loc3: address)
	92: Call linked_table::borrow_mut<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address): &mut Profile<Ty0>
	93: Call profile::stakes_mut<Ty0>(&mut Profile<Ty0>): &mut VecMap<ID, Stake>
	94: ImmBorrowLoc[12](loc9: ID)
	95: Call vec_map::get_mut<ID, Stake>(&mut VecMap<ID, Stake>, &ID): &mut Stake
	96: CopyLoc[7](loc4: u64)
	97: Call stake::sub(&mut Stake, u64): u64
	98: StLoc[9](loc6: u64)
	99: MoveLoc[12](loc9: ID)
	100: MoveLoc[8](loc5: TypeName)
	101: MoveLoc[6](loc3: address)
	102: MoveLoc[7](loc4: u64)
	103: MoveLoc[9](loc6: u64)
	104: Call event::emit_unstake<Ty0>(ID, TypeName, address, u64, u64)
	105: Ret
}

public claim<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock, Arg2: AccountRequest, Arg3: u64, Arg4: &mut TxContext): Coin<Ty0> {
L5:	loc0: address
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call claimable<Ty0>(&PointCenter<Ty0>): bool
	3: Not
	4: BrFalse(6)
B1:
	5: Call err_points_not_claimable()
B2:
	6: MoveLoc[2](Arg2: AccountRequest)
	7: Call account::destroy(AccountRequest): address
	8: StLoc[5](loc0: address)
	9: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	10: MoveLoc[1](Arg1: &Clock)
	11: CopyLoc[5](loc0: address)
	12: Call settle_user_points<Ty0>(&mut PointCenter<Ty0>, &Clock, address): u64
	13: CopyLoc[3](Arg3: u64)
	14: Lt
	15: BrFalse(17)
B3:
	16: Call err_points_not_enough()
B4:
	17: CopyLoc[5](loc0: address)
	18: CopyLoc[3](Arg3: u64)
	19: Call event::emit_claim<Ty0>(address, u64)
	20: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	21: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	22: MoveLoc[5](loc0: address)
	23: Call linked_table::borrow_mut<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address): &mut Profile<Ty0>
	24: Call profile::points_mut<Ty0>(&mut Profile<Ty0>): &mut Balance<Ty0>
	25: MoveLoc[3](Arg3: u64)
	26: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	27: MoveLoc[4](Arg4: &mut TxContext)
	28: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	29: Ret
}

public supply<Ty0>(Arg0: &PointCenter<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	2: Call coin::total_supply<Ty0>(&TreasuryCap<Ty0>): u64
	3: Ret
}

public unsettled_supply<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &Clock): u64 {
L2:	loc0: u64
L3:	loc1: vector<ID>
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: &mut vector<u64>
L7:	loc5: u64
L8:	loc6: u64
L9:	loc7: &ID
L10:	loc8: u64
L11:	loc9: u64
L12:	loc10: u64
L13:	loc11: u64
L14:	loc12: &ID
L15:	loc13: vector<u64>
L16:	loc14: u64
L17:	loc15: u64
L18:	loc16: &vector<ID>
L19:	loc17: vector<u64>
L20:	loc18: vector<u64>
L21:	loc19: &vector<ID>
B0:
	0: MoveLoc[1](Arg1: &Clock)
	1: Call clock::timestamp_ms(&Clock): u64
	2: StLoc[8](loc6: u64)
	3: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	4: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	5: Call vec_map::keys<ID, PoolState>(&VecMap<ID, PoolState>): vector<ID>
	6: StLoc[3](loc1: vector<ID>)
	7: ImmBorrowLoc[3](loc1: vector<ID>)
	8: StLoc[18](loc16: &vector<ID>)
	9: LdConst[7](vector<u64>: 00)
	10: StLoc[15](loc13: vector<u64>)
	11: MoveLoc[18](loc16: &vector<ID>)
	12: StLoc[21](loc19: &vector<ID>)
	13: CopyLoc[21](loc19: &vector<ID>)
	14: VecLen(10)
	15: StLoc[2](loc0: u64)
	16: LdU64(0)
	17: StLoc[12](loc10: u64)
	18: MoveLoc[2](loc0: u64)
	19: StLoc[16](loc14: u64)
B1:
	20: CopyLoc[12](loc10: u64)
	21: CopyLoc[16](loc14: u64)
	22: Lt
	23: BrFalse(64)
B2:
	24: CopyLoc[12](loc10: u64)
	25: StLoc[11](loc9: u64)
	26: CopyLoc[21](loc19: &vector<ID>)
	27: MoveLoc[11](loc9: u64)
	28: VecImmBorrow(10)
	29: StLoc[9](loc7: &ID)
	30: MutBorrowLoc[15](loc13: vector<u64>)
	31: StLoc[6](loc4: &mut vector<u64>)
	32: MoveLoc[9](loc7: &ID)
	33: StLoc[14](loc12: &ID)
	34: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	35: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	36: CopyLoc[14](loc12: &ID)
	37: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	38: Call state::total_stake(&PoolState): u64
	39: LdU64(0)
	40: Gt
	41: BrFalse(50)
B3:
	42: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	43: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	44: MoveLoc[14](loc12: &ID)
	45: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	46: CopyLoc[8](loc6: u64)
	47: Call state::get_release_amount(&PoolState, u64): u64
	48: StLoc[5](loc3: u64)
	49: Branch(54)
B4:
	50: MoveLoc[14](loc12: &ID)
	51: Pop
	52: LdU64(0)
	53: StLoc[5](loc3: u64)
B5:
	54: MoveLoc[5](loc3: u64)
	55: StLoc[4](loc2: u64)
	56: MoveLoc[6](loc4: &mut vector<u64>)
	57: MoveLoc[4](loc2: u64)
	58: VecPushBack(5)
	59: MoveLoc[12](loc10: u64)
	60: LdU64(1)
	61: Add
	62: StLoc[12](loc10: u64)
	63: Branch(20)
B6:
	64: MoveLoc[21](loc19: &vector<ID>)
	65: Pop
	66: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	67: Pop
	68: MoveLoc[15](loc13: vector<u64>)
	69: StLoc[19](loc17: vector<u64>)
	70: LdU64(0)
	71: StLoc[7](loc5: u64)
	72: MoveLoc[19](loc17: vector<u64>)
	73: StLoc[20](loc18: vector<u64>)
	74: MutBorrowLoc[20](loc18: vector<u64>)
	75: Call vector::reverse<u64>(&mut vector<u64>)
B7:
	76: ImmBorrowLoc[20](loc18: vector<u64>)
	77: VecLen(5)
	78: LdU64(0)
	79: Neq
	80: BrFalse(93)
B8:
	81: MutBorrowLoc[20](loc18: vector<u64>)
	82: VecPopBack(5)
	83: StLoc[10](loc8: u64)
	84: MoveLoc[7](loc5: u64)
	85: StLoc[17](loc15: u64)
	86: MoveLoc[10](loc8: u64)
	87: StLoc[13](loc11: u64)
	88: MoveLoc[17](loc15: u64)
	89: MoveLoc[13](loc11: u64)
	90: Add
	91: StLoc[7](loc5: u64)
	92: Branch(76)
B9:
	93: MoveLoc[20](loc18: vector<u64>)
	94: VecUnpack(5, 0)
	95: MoveLoc[7](loc5: u64)
	96: Ret
}

public realtime_supply<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &Clock): u64 {
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call supply<Ty0>(&PointCenter<Ty0>): u64
	2: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	3: MoveLoc[1](Arg1: &Clock)
	4: Call unsettled_supply<Ty0>(&PointCenter<Ty0>, &Clock): u64
	5: Add
	6: Ret
}

public pool_states<Ty0>(Arg0: &PointCenter<Ty0>): &VecMap<ID, PoolState> {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	2: Ret
}

public user_profiles<Ty0>(Arg0: &PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>> {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	2: Ret
}

public claimable<Ty0>(Arg0: &PointCenter<Ty0>): bool {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[2](PointCenter.claimable: bool)
	2: ReadRef
	3: Ret
}

public unsettled_points_by_pool_id<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address, Arg2: &ID, Arg3: &Clock): u64 {
L4:	loc0: bool
L5:	loc1: u64
L6:	loc2: u64
L7:	loc3: u64
L8:	loc4: Float
L9:	loc5: &PoolState
L10:	loc6: &Stake
L11:	loc7: u64
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	2: CopyLoc[2](Arg2: &ID)
	3: Call vec_map::contains<ID, PoolState>(&VecMap<ID, PoolState>, &ID): bool
	4: Not
	5: BrFalse(7)
B1:
	6: Call err_pool_not_exists()
B2:
	7: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	8: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	9: CopyLoc[1](Arg1: address)
	10: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	11: BrFalse(21)
B3:
	12: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	13: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	14: CopyLoc[1](Arg1: address)
	15: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	16: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	17: CopyLoc[2](Arg2: &ID)
	18: Call vec_map::contains<ID, Stake>(&VecMap<ID, Stake>, &ID): bool
	19: StLoc[4](loc0: bool)
	20: Branch(23)
B4:
	21: LdFalse
	22: StLoc[4](loc0: bool)
B5:
	23: MoveLoc[4](loc0: bool)
	24: BrFalse(78)
B6:
	25: MoveLoc[3](Arg3: &Clock)
	26: Call clock::timestamp_ms(&Clock): u64
	27: StLoc[7](loc3: u64)
	28: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	29: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	30: CopyLoc[2](Arg2: &ID)
	31: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	32: StLoc[9](loc5: &PoolState)
	33: CopyLoc[9](loc5: &PoolState)
	34: Call state::total_stake(&PoolState): u64
	35: StLoc[11](loc7: u64)
	36: CopyLoc[11](loc7: u64)
	37: LdU64(0)
	38: Gt
	39: BrFalse(67)
B7:
	40: CopyLoc[9](loc5: &PoolState)
	41: MoveLoc[7](loc3: u64)
	42: Call state::get_release_amount(&PoolState, u64): u64
	43: MoveLoc[11](loc7: u64)
	44: Call float::from_fraction(u64, u64): Float
	45: StLoc[8](loc4: Float)
	46: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	47: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	48: MoveLoc[1](Arg1: address)
	49: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	50: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	51: MoveLoc[2](Arg2: &ID)
	52: Call vec_map::get<ID, Stake>(&VecMap<ID, Stake>, &ID): &Stake
	53: StLoc[10](loc6: &Stake)
	54: MoveLoc[9](loc5: &PoolState)
	55: Call state::unit(&PoolState): Float
	56: MoveLoc[8](loc4: Float)
	57: Call float::add(Float, Float): Float
	58: CopyLoc[10](loc6: &Stake)
	59: Call stake::unit(&Stake): Float
	60: Call float::sub(Float, Float): Float
	61: MoveLoc[10](loc6: &Stake)
	62: Call stake::amount(&Stake): u64
	63: Call float::mul_u64(Float, u64): Float
	64: Call float::ceil(Float): u64
	65: StLoc[5](loc1: u64)
	66: Branch(75)
B8:
	67: MoveLoc[9](loc5: &PoolState)
	68: Pop
	69: MoveLoc[2](Arg2: &ID)
	70: Pop
	71: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	72: Pop
	73: LdU64(0)
	74: StLoc[5](loc1: u64)
B9:
	75: MoveLoc[5](loc1: u64)
	76: StLoc[6](loc2: u64)
	77: Branch(86)
B10:
	78: MoveLoc[2](Arg2: &ID)
	79: Pop
	80: MoveLoc[3](Arg3: &Clock)
	81: Pop
	82: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	83: Pop
	84: LdU64(0)
	85: StLoc[6](loc2: u64)
B11:
	86: MoveLoc[6](loc2: u64)
	87: Ret
}

public realtime_cumulative_points_by_pool_id<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address, Arg2: &ID, Arg3: &Clock): u64 {
L4:	loc0: Option<Stake>
L5:	loc1: Option<u64>
L6:	loc2: Option<u64>
L7:	loc3: u64
L8:	loc4: u64
L9:	loc5: &Option<Stake>
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	4: BrFalse(43)
B1:
	5: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	6: CopyLoc[1](Arg1: address)
	7: CopyLoc[2](Arg2: &ID)
	8: MoveLoc[3](Arg3: &Clock)
	9: Call unsettled_points_by_pool_id<Ty0>(&PointCenter<Ty0>, address, &ID, &Clock): u64
	10: StLoc[7](loc3: u64)
	11: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	12: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	13: MoveLoc[1](Arg1: address)
	14: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	15: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	16: MoveLoc[2](Arg2: &ID)
	17: Call vec_map::try_get<ID, Stake>(&VecMap<ID, Stake>, &ID): Option<Stake>
	18: StLoc[4](loc0: Option<Stake>)
	19: ImmBorrowLoc[4](loc0: Option<Stake>)
	20: StLoc[9](loc5: &Option<Stake>)
	21: CopyLoc[9](loc5: &Option<Stake>)
	22: Call option::is_some<Stake>(&Option<Stake>): bool
	23: BrFalse(30)
B2:
	24: MoveLoc[9](loc5: &Option<Stake>)
	25: Call option::borrow<Stake>(&Option<Stake>): &Stake
	26: Call stake::cumulant(&Stake): u64
	27: Call option::some<u64>(u64): Option<u64>
	28: StLoc[5](loc1: Option<u64>)
	29: Branch(34)
B3:
	30: MoveLoc[9](loc5: &Option<Stake>)
	31: Pop
	32: Call option::none<u64>(): Option<u64>
	33: StLoc[5](loc1: Option<u64>)
B4:
	34: MoveLoc[5](loc1: Option<u64>)
	35: StLoc[6](loc2: Option<u64>)
	36: MoveLoc[7](loc3: u64)
	37: ImmBorrowLoc[6](loc2: Option<u64>)
	38: LdU64(0)
	39: Call option::get_with_default<u64>(&Option<u64>, u64): u64
	40: Add
	41: StLoc[8](loc4: u64)
	42: Branch(51)
B5:
	43: MoveLoc[2](Arg2: &ID)
	44: Pop
	45: MoveLoc[3](Arg3: &Clock)
	46: Pop
	47: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	48: Pop
	49: LdU64(0)
	50: StLoc[8](loc4: u64)
B6:
	51: MoveLoc[8](loc4: u64)
	52: Ret
}

public settled_points<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	4: BrFalse(13)
B1:
	5: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	6: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	7: MoveLoc[1](Arg1: address)
	8: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	9: Call profile::points<Ty0>(&Profile<Ty0>): &Balance<Ty0>
	10: Call balance::value<Ty0>(&Balance<Ty0>): u64
	11: StLoc[2](loc0: u64)
	12: Branch(17)
B2:
	13: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	14: Pop
	15: LdU64(0)
	16: StLoc[2](loc0: u64)
B3:
	17: MoveLoc[2](loc0: u64)
	18: Ret
}

public unsettled_points<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address, Arg2: &Clock): u64 {
L3:	loc0: u64
L4:	loc1: vector<ID>
L5:	loc2: u64
L6:	loc3: &mut vector<u64>
L7:	loc4: u64
L8:	loc5: u64
L9:	loc6: &ID
L10:	loc7: u64
L11:	loc8: u64
L12:	loc9: u64
L13:	loc10: u64
L14:	loc11: &ID
L15:	loc12: vector<u64>
L16:	loc13: u64
L17:	loc14: u64
L18:	loc15: &vector<ID>
L19:	loc16: vector<u64>
L20:	loc17: vector<u64>
L21:	loc18: &vector<ID>
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	4: BrFalse(89)
B1:
	5: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	6: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	7: CopyLoc[1](Arg1: address)
	8: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	9: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	10: Call vec_map::keys<ID, Stake>(&VecMap<ID, Stake>): vector<ID>
	11: StLoc[4](loc1: vector<ID>)
	12: ImmBorrowLoc[4](loc1: vector<ID>)
	13: StLoc[18](loc15: &vector<ID>)
	14: LdConst[7](vector<u64>: 00)
	15: StLoc[15](loc12: vector<u64>)
	16: MoveLoc[18](loc15: &vector<ID>)
	17: StLoc[21](loc18: &vector<ID>)
	18: CopyLoc[21](loc18: &vector<ID>)
	19: VecLen(10)
	20: StLoc[3](loc0: u64)
	21: LdU64(0)
	22: StLoc[12](loc9: u64)
	23: MoveLoc[3](loc0: u64)
	24: StLoc[16](loc13: u64)
B2:
	25: CopyLoc[12](loc9: u64)
	26: CopyLoc[16](loc13: u64)
	27: Lt
	28: BrFalse(53)
B3:
	29: CopyLoc[12](loc9: u64)
	30: StLoc[11](loc8: u64)
	31: CopyLoc[21](loc18: &vector<ID>)
	32: MoveLoc[11](loc8: u64)
	33: VecImmBorrow(10)
	34: StLoc[9](loc6: &ID)
	35: MutBorrowLoc[15](loc12: vector<u64>)
	36: StLoc[6](loc3: &mut vector<u64>)
	37: MoveLoc[9](loc6: &ID)
	38: StLoc[14](loc11: &ID)
	39: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	40: CopyLoc[1](Arg1: address)
	41: MoveLoc[14](loc11: &ID)
	42: CopyLoc[2](Arg2: &Clock)
	43: Call unsettled_points_by_pool_id<Ty0>(&PointCenter<Ty0>, address, &ID, &Clock): u64
	44: StLoc[5](loc2: u64)
	45: MoveLoc[6](loc3: &mut vector<u64>)
	46: MoveLoc[5](loc2: u64)
	47: VecPushBack(5)
	48: MoveLoc[12](loc9: u64)
	49: LdU64(1)
	50: Add
	51: StLoc[12](loc9: u64)
	52: Branch(25)
B4:
	53: MoveLoc[21](loc18: &vector<ID>)
	54: Pop
	55: MoveLoc[2](Arg2: &Clock)
	56: Pop
	57: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	58: Pop
	59: MoveLoc[15](loc12: vector<u64>)
	60: StLoc[19](loc16: vector<u64>)
	61: LdU64(0)
	62: StLoc[8](loc5: u64)
	63: MoveLoc[19](loc16: vector<u64>)
	64: StLoc[20](loc17: vector<u64>)
	65: MutBorrowLoc[20](loc17: vector<u64>)
	66: Call vector::reverse<u64>(&mut vector<u64>)
B5:
	67: ImmBorrowLoc[20](loc17: vector<u64>)
	68: VecLen(5)
	69: LdU64(0)
	70: Neq
	71: BrFalse(84)
B6:
	72: MutBorrowLoc[20](loc17: vector<u64>)
	73: VecPopBack(5)
	74: StLoc[10](loc7: u64)
	75: MoveLoc[8](loc5: u64)
	76: StLoc[17](loc14: u64)
	77: MoveLoc[10](loc7: u64)
	78: StLoc[13](loc10: u64)
	79: MoveLoc[17](loc14: u64)
	80: MoveLoc[13](loc10: u64)
	81: Add
	82: StLoc[8](loc5: u64)
	83: Branch(67)
B7:
	84: MoveLoc[20](loc17: vector<u64>)
	85: VecUnpack(5, 0)
	86: MoveLoc[8](loc5: u64)
	87: StLoc[7](loc4: u64)
	88: Branch(95)
B8:
	89: MoveLoc[2](Arg2: &Clock)
	90: Pop
	91: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	92: Pop
	93: LdU64(0)
	94: StLoc[7](loc4: u64)
B9:
	95: MoveLoc[7](loc4: u64)
	96: Ret
}

public realtime_points<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address, Arg2: &Clock): u64 {
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: CopyLoc[1](Arg1: address)
	2: Call settled_points<Ty0>(&PointCenter<Ty0>, address): u64
	3: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	4: MoveLoc[1](Arg1: address)
	5: MoveLoc[2](Arg2: &Clock)
	6: Call unsettled_points<Ty0>(&PointCenter<Ty0>, address, &Clock): u64
	7: Add
	8: Ret
}

public stake_policy<Ty0>(Arg0: &PointCenter<Ty0>): &vector<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[3](PointCenter.stake_policy: vector<TypeName>)
	2: Ret
}

public unstake_policy<Ty0>(Arg0: &PointCenter<Ty0>): &vector<TypeName> {
B0:
	0: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[4](PointCenter.unstake_policy: vector<TypeName>)
	2: Ret
}

public multi_get_account_points<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &Clock, Arg2: Option<address>, Arg3: u64, Arg4: u64): vector<AccountPoints> * Option<address> {
L5:	loc0: bool
L6:	loc1: address
L7:	loc2: u64
L8:	loc3: u64
L9:	loc4: vector<AccountPoints>
B0:
	0: ImmBorrowLoc[2](Arg2: Option<address>)
	1: Call option::is_none<address>(&Option<address>): bool
	2: BrFalse(8)
B1:
	3: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	4: ImmBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	5: Call linked_table::front<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>): &Option<address>
	6: ReadRef
	7: StLoc[2](Arg2: Option<address>)
B2:
	8: ImmBorrowLoc[2](Arg2: Option<address>)
	9: Call option::is_none<address>(&Option<address>): bool
	10: BrFalse(18)
B3:
	11: MoveLoc[1](Arg1: &Clock)
	12: Pop
	13: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	14: Pop
	15: VecPack(126, 0)
	16: Call option::none<address>(): Option<address>
	17: Ret
B4:
	18: LdU64(0)
	19: StLoc[7](loc2: u64)
	20: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	21: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	22: ImmBorrowLoc[2](Arg2: Option<address>)
	23: Call option::borrow<address>(&Option<address>): &address
	24: ReadRef
	25: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	26: Not
	27: BrFalse(29)
B5:
	28: Call err_account_not_found()
B6:
	29: VecPack(126, 0)
	30: StLoc[9](loc4: vector<AccountPoints>)
B7:
	31: ImmBorrowLoc[2](Arg2: Option<address>)
	32: Call option::is_some<address>(&Option<address>): bool
	33: BrFalse(39)
B8:
	34: CopyLoc[7](loc2: u64)
	35: CopyLoc[4](Arg4: u64)
	36: Lt
	37: StLoc[5](loc0: bool)
	38: Branch(41)
B9:
	39: LdFalse
	40: StLoc[5](loc0: bool)
B10:
	41: MoveLoc[5](loc0: bool)
	42: BrFalse(74)
B11:
	43: Branch(44)
B12:
	44: MutBorrowLoc[2](Arg2: Option<address>)
	45: Call option::extract<address>(&mut Option<address>): address
	46: StLoc[6](loc1: address)
	47: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	48: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	49: CopyLoc[6](loc1: address)
	50: Call linked_table::next<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Option<address>
	51: ReadRef
	52: StLoc[2](Arg2: Option<address>)
	53: CopyLoc[7](loc2: u64)
	54: CopyLoc[3](Arg3: u64)
	55: Mod
	56: LdU64(0)
	57: Eq
	58: BrFalse(69)
B13:
	59: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	60: CopyLoc[6](loc1: address)
	61: CopyLoc[1](Arg1: &Clock)
	62: Call realtime_points<Ty0>(&PointCenter<Ty0>, address, &Clock): u64
	63: StLoc[8](loc3: u64)
	64: MutBorrowLoc[9](loc4: vector<AccountPoints>)
	65: MoveLoc[6](loc1: address)
	66: MoveLoc[8](loc3: u64)
	67: Pack[2](AccountPoints)
	68: VecPushBack(126)
B14:
	69: MoveLoc[7](loc2: u64)
	70: LdU64(1)
	71: Add
	72: StLoc[7](loc2: u64)
	73: Branch(31)
B15:
	74: MoveLoc[1](Arg1: &Clock)
	75: Pop
	76: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	77: Pop
	78: MoveLoc[9](loc4: vector<AccountPoints>)
	79: MoveLoc[2](Arg2: Option<address>)
	80: Ret
}

public get_account_info<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: &Clock, Arg2: address): Option<AccountInfo> {
L3:	loc0: u64
L4:	loc1: u64
L5:	loc2: u64
L6:	loc3: &mut vector<u64>
L7:	loc4: u64
L8:	loc5: &mut vector<u64>
L9:	loc6: Option<AccountInfo>
L10:	loc7: vector<u64>
L11:	loc8: &ID
L12:	loc9: &ID
L13:	loc10: u64
L14:	loc11: u64
L15:	loc12: u64
L16:	loc13: u64
L17:	loc14: u64
L18:	loc15: &ID
L19:	loc16: &ID
L20:	loc17: vector<ID>
L21:	loc18: vector<u64>
L22:	loc19: vector<u64>
L23:	loc20: vector<u64>
L24:	loc21: &VecMap<ID, Stake>
L25:	loc22: u64
L26:	loc23: u64
L27:	loc24: &vector<ID>
L28:	loc25: &vector<ID>
L29:	loc26: &vector<ID>
L30:	loc27: &vector<ID>
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	2: CopyLoc[2](Arg2: address)
	3: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	4: BrFalse(122)
B1:
	5: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	6: CopyLoc[2](Arg2: address)
	7: CopyLoc[1](Arg1: &Clock)
	8: Call realtime_points<Ty0>(&PointCenter<Ty0>, address, &Clock): u64
	9: StLoc[17](loc14: u64)
	10: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	11: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	12: CopyLoc[2](Arg2: address)
	13: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	14: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	15: StLoc[24](loc21: &VecMap<ID, Stake>)
	16: CopyLoc[24](loc21: &VecMap<ID, Stake>)
	17: Call vec_map::keys<ID, Stake>(&VecMap<ID, Stake>): vector<ID>
	18: StLoc[20](loc17: vector<ID>)
	19: ImmBorrowLoc[20](loc17: vector<ID>)
	20: StLoc[27](loc24: &vector<ID>)
	21: LdConst[7](vector<u64>: 00)
	22: StLoc[21](loc18: vector<u64>)
	23: MoveLoc[27](loc24: &vector<ID>)
	24: StLoc[30](loc27: &vector<ID>)
	25: CopyLoc[30](loc27: &vector<ID>)
	26: VecLen(10)
	27: StLoc[4](loc1: u64)
	28: LdU64(0)
	29: StLoc[16](loc13: u64)
	30: MoveLoc[4](loc1: u64)
	31: StLoc[26](loc23: u64)
B2:
	32: CopyLoc[16](loc13: u64)
	33: CopyLoc[26](loc23: u64)
	34: Lt
	35: BrFalse(59)
B3:
	36: CopyLoc[16](loc13: u64)
	37: StLoc[13](loc10: u64)
	38: CopyLoc[30](loc27: &vector<ID>)
	39: MoveLoc[13](loc10: u64)
	40: VecImmBorrow(10)
	41: StLoc[11](loc8: &ID)
	42: MutBorrowLoc[21](loc18: vector<u64>)
	43: StLoc[6](loc3: &mut vector<u64>)
	44: MoveLoc[11](loc8: &ID)
	45: StLoc[18](loc15: &ID)
	46: CopyLoc[24](loc21: &VecMap<ID, Stake>)
	47: MoveLoc[18](loc15: &ID)
	48: Call vec_map::get<ID, Stake>(&VecMap<ID, Stake>, &ID): &Stake
	49: Call stake::amount(&Stake): u64
	50: StLoc[5](loc2: u64)
	51: MoveLoc[6](loc3: &mut vector<u64>)
	52: MoveLoc[5](loc2: u64)
	53: VecPushBack(5)
	54: MoveLoc[16](loc13: u64)
	55: LdU64(1)
	56: Add
	57: StLoc[16](loc13: u64)
	58: Branch(32)
B4:
	59: MoveLoc[30](loc27: &vector<ID>)
	60: Pop
	61: MoveLoc[24](loc21: &VecMap<ID, Stake>)
	62: Pop
	63: MoveLoc[21](loc18: vector<u64>)
	64: StLoc[23](loc20: vector<u64>)
	65: ImmBorrowLoc[20](loc17: vector<ID>)
	66: StLoc[28](loc25: &vector<ID>)
	67: LdConst[7](vector<u64>: 00)
	68: StLoc[22](loc19: vector<u64>)
	69: MoveLoc[28](loc25: &vector<ID>)
	70: StLoc[29](loc26: &vector<ID>)
	71: CopyLoc[29](loc26: &vector<ID>)
	72: VecLen(10)
	73: StLoc[3](loc0: u64)
	74: LdU64(0)
	75: StLoc[14](loc11: u64)
	76: MoveLoc[3](loc0: u64)
	77: StLoc[25](loc22: u64)
B5:
	78: CopyLoc[14](loc11: u64)
	79: CopyLoc[25](loc22: u64)
	80: Lt
	81: BrFalse(106)
B6:
	82: CopyLoc[14](loc11: u64)
	83: StLoc[15](loc12: u64)
	84: CopyLoc[29](loc26: &vector<ID>)
	85: MoveLoc[15](loc12: u64)
	86: VecImmBorrow(10)
	87: StLoc[12](loc9: &ID)
	88: MutBorrowLoc[22](loc19: vector<u64>)
	89: StLoc[8](loc5: &mut vector<u64>)
	90: MoveLoc[12](loc9: &ID)
	91: StLoc[19](loc16: &ID)
	92: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	93: CopyLoc[2](Arg2: address)
	94: MoveLoc[19](loc16: &ID)
	95: CopyLoc[1](Arg1: &Clock)
	96: Call realtime_cumulative_points_by_pool_id<Ty0>(&PointCenter<Ty0>, address, &ID, &Clock): u64
	97: StLoc[7](loc4: u64)
	98: MoveLoc[8](loc5: &mut vector<u64>)
	99: MoveLoc[7](loc4: u64)
	100: VecPushBack(5)
	101: MoveLoc[14](loc11: u64)
	102: LdU64(1)
	103: Add
	104: StLoc[14](loc11: u64)
	105: Branch(78)
B7:
	106: MoveLoc[29](loc26: &vector<ID>)
	107: Pop
	108: MoveLoc[1](Arg1: &Clock)
	109: Pop
	110: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	111: Pop
	112: MoveLoc[22](loc19: vector<u64>)
	113: StLoc[10](loc7: vector<u64>)
	114: MoveLoc[17](loc14: u64)
	115: MoveLoc[20](loc17: vector<ID>)
	116: MoveLoc[23](loc20: vector<u64>)
	117: MoveLoc[10](loc7: vector<u64>)
	118: Pack[3](AccountInfo)
	119: Call option::some<AccountInfo>(AccountInfo): Option<AccountInfo>
	120: StLoc[9](loc6: Option<AccountInfo>)
	121: Branch(128)
B8:
	122: MoveLoc[1](Arg1: &Clock)
	123: Pop
	124: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	125: Pop
	126: Call option::none<AccountInfo>(): Option<AccountInfo>
	127: StLoc[9](loc6: Option<AccountInfo>)
B9:
	128: MoveLoc[9](loc6: Option<AccountInfo>)
	129: Ret
}

update_pool_state<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock, Arg2: &ID) {
L3:	loc0: String
L4:	loc1: u64
L5:	loc2: Balance<Ty0>
L6:	loc3: u64
L7:	loc4: &mut PoolState
L8:	loc5: u64
L9:	loc6: u64
L10:	loc7: Float
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: ImmBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	2: CopyLoc[2](Arg2: &ID)
	3: Call vec_map::contains<ID, PoolState>(&VecMap<ID, PoolState>, &ID): bool
	4: Not
	5: BrFalse(7)
B1:
	6: Call err_pool_not_exists()
B2:
	7: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	8: MutBorrowFieldGeneric[1](PointCenter.pool_states: VecMap<ID, PoolState>)
	9: CopyLoc[2](Arg2: &ID)
	10: Call vec_map::get_mut<ID, PoolState>(&mut VecMap<ID, PoolState>, &ID): &mut PoolState
	11: StLoc[7](loc4: &mut PoolState)
	12: CopyLoc[7](loc4: &mut PoolState)
	13: FreezeRef
	14: Call state::asset_type(&PoolState): String
	15: StLoc[3](loc0: String)
	16: CopyLoc[7](loc4: &mut PoolState)
	17: FreezeRef
	18: Call state::total_stake(&PoolState): u64
	19: StLoc[9](loc6: u64)
	20: MoveLoc[1](Arg1: &Clock)
	21: Call clock::timestamp_ms(&Clock): u64
	22: StLoc[4](loc1: u64)
	23: CopyLoc[4](loc1: u64)
	24: CopyLoc[7](loc4: &mut PoolState)
	25: FreezeRef
	26: Call state::timestamp(&PoolState): u64
	27: Gt
	28: BrFalse(83)
B3:
	29: CopyLoc[9](loc6: u64)
	30: LdU64(0)
	31: Gt
	32: BrFalse(75)
B4:
	33: CopyLoc[7](loc4: &mut PoolState)
	34: FreezeRef
	35: CopyLoc[4](loc1: u64)
	36: Call state::get_release_amount(&PoolState, u64): u64
	37: StLoc[6](loc3: u64)
	38: CopyLoc[6](loc3: u64)
	39: LdU64(0)
	40: Gt
	41: BrFalse(70)
B5:
	42: CopyLoc[6](loc3: u64)
	43: MoveLoc[9](loc6: u64)
	44: Call float::from_fraction(u64, u64): Float
	45: StLoc[10](loc7: Float)
	46: CopyLoc[7](loc4: &mut PoolState)
	47: MoveLoc[10](loc7: Float)
	48: Call state::add_unit(&mut PoolState, Float)
	49: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	50: MutBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	51: Call coin::supply_mut<Ty0>(&mut TreasuryCap<Ty0>): &mut Supply<Ty0>
	52: CopyLoc[6](loc3: u64)
	53: Call balance::increase_supply<Ty0>(&mut Supply<Ty0>, u64): Balance<Ty0>
	54: StLoc[5](loc2: Balance<Ty0>)
	55: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	56: MutBorrowFieldGeneric[6](PointCenter.buffer: Balance<Ty0>)
	57: MoveLoc[5](loc2: Balance<Ty0>)
	58: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	59: Pop
	60: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	61: ImmBorrowFieldGeneric[0](PointCenter.cap: TreasuryCap<Ty0>)
	62: Call coin::total_supply<Ty0>(&TreasuryCap<Ty0>): u64
	63: StLoc[8](loc5: u64)
	64: MoveLoc[2](Arg2: &ID)
	65: MoveLoc[3](loc0: String)
	66: MoveLoc[6](loc3: u64)
	67: MoveLoc[8](loc5: u64)
	68: Call event::emit_mint<Ty0>(&ID, String, u64, u64)
	69: Branch(79)
B6:
	70: MoveLoc[2](Arg2: &ID)
	71: Pop
	72: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	73: Pop
	74: Branch(79)
B7:
	75: MoveLoc[2](Arg2: &ID)
	76: Pop
	77: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	78: Pop
B8:
	79: MoveLoc[7](loc4: &mut PoolState)
	80: MoveLoc[4](loc1: u64)
	81: Call state::set_timestamp(&mut PoolState, u64)
	82: Branch(89)
B9:
	83: MoveLoc[7](loc4: &mut PoolState)
	84: Pop
	85: MoveLoc[2](Arg2: &ID)
	86: Pop
	87: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	88: Pop
B10:
	89: Ret
}

update_all_pool_states<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock) {
L2:	loc0: u64
L3:	loc1: vector<ID>
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: &ID
L7:	loc5: u64
L8:	loc6: &vector<ID>
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: FreezeRef
	2: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	3: Call vec_map::keys<ID, PoolState>(&VecMap<ID, PoolState>): vector<ID>
	4: StLoc[3](loc1: vector<ID>)
	5: ImmBorrowLoc[3](loc1: vector<ID>)
	6: StLoc[8](loc6: &vector<ID>)
	7: CopyLoc[8](loc6: &vector<ID>)
	8: VecLen(10)
	9: StLoc[2](loc0: u64)
	10: LdU64(0)
	11: StLoc[4](loc2: u64)
	12: MoveLoc[2](loc0: u64)
	13: StLoc[7](loc5: u64)
B1:
	14: CopyLoc[4](loc2: u64)
	15: CopyLoc[7](loc5: u64)
	16: Lt
	17: BrFalse(33)
B2:
	18: CopyLoc[4](loc2: u64)
	19: StLoc[5](loc3: u64)
	20: CopyLoc[8](loc6: &vector<ID>)
	21: MoveLoc[5](loc3: u64)
	22: VecImmBorrow(10)
	23: StLoc[6](loc4: &ID)
	24: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	25: CopyLoc[1](Arg1: &Clock)
	26: MoveLoc[6](loc4: &ID)
	27: Call update_pool_state<Ty0>(&mut PointCenter<Ty0>, &Clock, &ID)
	28: MoveLoc[4](loc2: u64)
	29: LdU64(1)
	30: Add
	31: StLoc[4](loc2: u64)
	32: Branch(14)
B3:
	33: MoveLoc[8](loc6: &vector<ID>)
	34: Pop
	35: MoveLoc[1](Arg1: &Clock)
	36: Pop
	37: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	38: Pop
	39: Ret
}

settle_user_points<Ty0>(Arg0: &mut PointCenter<Ty0>, Arg1: &Clock, Arg2: address): u64 {
L3:	loc0: u64
L4:	loc1: vector<ID>
L5:	loc2: u64
L6:	loc3: &mut vector<u64>
L7:	loc4: u64
L8:	loc5: u64
L9:	loc6: u64
L10:	loc7: Balance<Ty0>
L11:	loc8: String
L12:	loc9: u64
L13:	loc10: &ID
L14:	loc11: u64
L15:	loc12: u64
L16:	loc13: u64
L17:	loc14: u64
L18:	loc15: &ID
L19:	loc16: &PoolState
L20:	loc17: vector<u64>
L21:	loc18: &mut Stake
L22:	loc19: Float
L23:	loc20: u64
L24:	loc21: &vector<ID>
L25:	loc22: vector<u64>
L26:	loc23: vector<u64>
L27:	loc24: &vector<ID>
L28:	loc25: u64
L29:	loc26: u64
B0:
	0: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	1: CopyLoc[1](Arg1: &Clock)
	2: Call update_all_pool_states<Ty0>(&mut PointCenter<Ty0>, &Clock)
	3: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	4: FreezeRef
	5: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	6: CopyLoc[2](Arg2: address)
	7: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	8: BrFalse(141)
B1:
	9: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	10: FreezeRef
	11: Call user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	12: CopyLoc[2](Arg2: address)
	13: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	14: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	15: Call vec_map::keys<ID, Stake>(&VecMap<ID, Stake>): vector<ID>
	16: StLoc[4](loc1: vector<ID>)
	17: ImmBorrowLoc[4](loc1: vector<ID>)
	18: StLoc[24](loc21: &vector<ID>)
	19: LdConst[7](vector<u64>: 00)
	20: StLoc[20](loc17: vector<u64>)
	21: MoveLoc[24](loc21: &vector<ID>)
	22: StLoc[27](loc24: &vector<ID>)
	23: CopyLoc[27](loc24: &vector<ID>)
	24: VecLen(10)
	25: StLoc[3](loc0: u64)
	26: LdU64(0)
	27: StLoc[16](loc13: u64)
	28: MoveLoc[3](loc0: u64)
	29: StLoc[23](loc20: u64)
B2:
	30: CopyLoc[16](loc13: u64)
	31: CopyLoc[23](loc20: u64)
	32: Lt
	33: BrFalse(94)
B3:
	34: CopyLoc[16](loc13: u64)
	35: StLoc[15](loc12: u64)
	36: CopyLoc[27](loc24: &vector<ID>)
	37: MoveLoc[15](loc12: u64)
	38: VecImmBorrow(10)
	39: StLoc[13](loc10: &ID)
	40: MutBorrowLoc[20](loc17: vector<u64>)
	41: StLoc[6](loc3: &mut vector<u64>)
	42: MoveLoc[13](loc10: &ID)
	43: StLoc[18](loc15: &ID)
	44: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	45: FreezeRef
	46: Call pool_states<Ty0>(&PointCenter<Ty0>): &VecMap<ID, PoolState>
	47: CopyLoc[18](loc15: &ID)
	48: Call vec_map::get<ID, PoolState>(&VecMap<ID, PoolState>, &ID): &PoolState
	49: StLoc[19](loc16: &PoolState)
	50: CopyLoc[19](loc16: &PoolState)
	51: Call state::unit(&PoolState): Float
	52: StLoc[22](loc19: Float)
	53: MoveLoc[19](loc16: &PoolState)
	54: Call state::asset_type(&PoolState): String
	55: StLoc[11](loc8: String)
	56: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	57: FreezeRef
	58: CopyLoc[2](Arg2: address)
	59: CopyLoc[18](loc15: &ID)
	60: CopyLoc[1](Arg1: &Clock)
	61: Call unsettled_points_by_pool_id<Ty0>(&PointCenter<Ty0>, address, &ID, &Clock): u64
	62: StLoc[17](loc14: u64)
	63: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	64: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	65: CopyLoc[2](Arg2: address)
	66: Call linked_table::borrow_mut<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address): &mut Profile<Ty0>
	67: Call profile::stakes_mut<Ty0>(&mut Profile<Ty0>): &mut VecMap<ID, Stake>
	68: CopyLoc[18](loc15: &ID)
	69: Call vec_map::get_mut<ID, Stake>(&mut VecMap<ID, Stake>, &ID): &mut Stake
	70: StLoc[21](loc18: &mut Stake)
	71: CopyLoc[21](loc18: &mut Stake)
	72: MoveLoc[22](loc19: Float)
	73: Call stake::set_unit(&mut Stake, Float)
	74: MoveLoc[21](loc18: &mut Stake)
	75: CopyLoc[17](loc14: u64)
	76: Call stake::cumulate(&mut Stake, u64): u64
	77: StLoc[12](loc9: u64)
	78: MoveLoc[18](loc15: &ID)
	79: MoveLoc[11](loc8: String)
	80: CopyLoc[2](Arg2: address)
	81: CopyLoc[17](loc14: u64)
	82: MoveLoc[12](loc9: u64)
	83: Call event::emit_cumulate<Ty0>(&ID, String, address, u64, u64)
	84: MoveLoc[17](loc14: u64)
	85: StLoc[5](loc2: u64)
	86: MoveLoc[6](loc3: &mut vector<u64>)
	87: MoveLoc[5](loc2: u64)
	88: VecPushBack(5)
	89: MoveLoc[16](loc13: u64)
	90: LdU64(1)
	91: Add
	92: StLoc[16](loc13: u64)
	93: Branch(30)
B4:
	94: MoveLoc[27](loc24: &vector<ID>)
	95: Pop
	96: MoveLoc[1](Arg1: &Clock)
	97: Pop
	98: MoveLoc[20](loc17: vector<u64>)
	99: StLoc[25](loc22: vector<u64>)
	100: LdU64(0)
	101: StLoc[8](loc5: u64)
	102: MoveLoc[25](loc22: vector<u64>)
	103: StLoc[26](loc23: vector<u64>)
	104: MutBorrowLoc[26](loc23: vector<u64>)
	105: Call vector::reverse<u64>(&mut vector<u64>)
B5:
	106: ImmBorrowLoc[26](loc23: vector<u64>)
	107: VecLen(5)
	108: LdU64(0)
	109: Neq
	110: BrFalse(123)
B6:
	111: MutBorrowLoc[26](loc23: vector<u64>)
	112: VecPopBack(5)
	113: StLoc[14](loc11: u64)
	114: MoveLoc[8](loc5: u64)
	115: StLoc[28](loc25: u64)
	116: MoveLoc[14](loc11: u64)
	117: StLoc[29](loc26: u64)
	118: MoveLoc[28](loc25: u64)
	119: MoveLoc[29](loc26: u64)
	120: Add
	121: StLoc[8](loc5: u64)
	122: Branch(106)
B7:
	123: MoveLoc[26](loc23: vector<u64>)
	124: VecUnpack(5, 0)
	125: MoveLoc[8](loc5: u64)
	126: StLoc[9](loc6: u64)
	127: CopyLoc[0](Arg0: &mut PointCenter<Ty0>)
	128: MutBorrowFieldGeneric[6](PointCenter.buffer: Balance<Ty0>)
	129: MoveLoc[9](loc6: u64)
	130: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	131: StLoc[10](loc7: Balance<Ty0>)
	132: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	133: MutBorrowFieldGeneric[5](PointCenter.user_profiles: LinkedTable<address, Profile<Ty0>>)
	134: MoveLoc[2](Arg2: address)
	135: Call linked_table::borrow_mut<address, Profile<Ty0>>(&mut LinkedTable<address, Profile<Ty0>>, address): &mut Profile<Ty0>
	136: Call profile::points_mut<Ty0>(&mut Profile<Ty0>): &mut Balance<Ty0>
	137: MoveLoc[10](loc7: Balance<Ty0>)
	138: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	139: StLoc[7](loc4: u64)
	140: Branch(147)
B8:
	141: MoveLoc[1](Arg1: &Clock)
	142: Pop
	143: MoveLoc[0](Arg0: &mut PointCenter<Ty0>)
	144: Pop
	145: LdU64(0)
	146: StLoc[7](loc4: u64)
B9:
	147: MoveLoc[7](loc4: u64)
	148: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u64: 2
	3 => u64: 3
	4 => u64: 4
	5 => u64: 5
	6 => u64: 6
	7 => vector<u64>: 00
]
}
