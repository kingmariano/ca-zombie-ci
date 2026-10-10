// Move bytecode v6
module 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10.pool_incentive {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::table;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use c7ab9b9353e23c6a3a15181eb51bf7145ddeff1a5642280394cd4d6a0d37d83b::stability_pool;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::double;
use 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10::admin_of_incentive;
use 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10::pool_incentive_events;

struct VirtuePoolIncentive has drop {
	dummy_field: bool
}

struct StakeData<phantom Ty0> has store {
	unit: Double,
	reward: Balance<Ty0>
}

struct PoolRewarderRegistry has key {
	id: UID,
	pool_rewarders: VecSet<ID>,
	versions: VecSet<u16>,
	managers: VecSet<address>
}

struct PoolRewarder<phantom Ty0> has key {
	id: UID,
	source: Balance<Ty0>,
	pool: Balance<Ty0>,
	flow_rate: Double,
	stake_table: Table<address, StakeData<Ty0>>,
	unit: Double,
	timestamp: u64
}

struct ResponseChecker {
	rewarder_ids: VecSet<ID>,
	response: PositionUpdateResponse
}

public package_version(): u16 {
B0:
	0: LdConst[0](u16: 1)
	1: Ret
}

err_invalid_rewarder() {
B0:
	0: LdConst[1](u64: 201)
	1: Abort
}

err_missing_rewarder_check() {
B0:
	0: LdConst[2](u64: 202)
	1: Abort
}

err_invalid_timestamp() {
B0:
	0: LdConst[3](u64: 203)
	1: Abort
}

err_invalid_package_version() {
B0:
	0: LdConst[4](u64: 204)
	1: Abort
}

err_sender_is_not_manager() {
B0:
	0: LdConst[5](u64: 205)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_set::empty<ID>(): VecSet<ID>
	3: Call package_version(): u16
	4: Call vec_set::singleton<u16>(u16): VecSet<u16>
	5: MoveLoc[0](Arg0: &mut TxContext)
	6: FreezeRef
	7: Call tx_context::sender(&TxContext): address
	8: Call vec_set::singleton<address>(address): VecSet<address>
	9: Pack[2](PoolRewarderRegistry)
	10: Call transfer::share_object<PoolRewarderRegistry>(PoolRewarderRegistry)
	11: Ret
}

public create<Ty0>(Arg0: &mut PoolRewarderRegistry, Arg1: &AdminCap, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: &mut TxContext) {
L6:	loc0: Double
L7:	loc1: PoolRewarder<Ty0>
L8:	loc2: ID
B0:
	0: CopyLoc[0](Arg0: &mut PoolRewarderRegistry)
	1: FreezeRef
	2: Call assert_valid_package_version(&PoolRewarderRegistry)
	3: MoveLoc[2](Arg2: u64)
	4: MoveLoc[3](Arg3: u64)
	5: Call double::from_fraction(u64, u64): Double
	6: StLoc[6](loc0: Double)
	7: CopyLoc[5](Arg5: &mut TxContext)
	8: Call object::new(&mut TxContext): UID
	9: Call balance::zero<Ty0>(): Balance<Ty0>
	10: Call balance::zero<Ty0>(): Balance<Ty0>
	11: CopyLoc[6](loc0: Double)
	12: MoveLoc[5](Arg5: &mut TxContext)
	13: Call table::new<address, StakeData<Ty0>>(&mut TxContext): Table<address, StakeData<Ty0>>
	14: LdU64(0)
	15: Call double::from(u64): Double
	16: CopyLoc[4](Arg4: u64)
	17: PackGeneric[0](PoolRewarder<Ty0>)
	18: StLoc[7](loc1: PoolRewarder<Ty0>)
	19: ImmBorrowLoc[7](loc1: PoolRewarder<Ty0>)
	20: Call object::id<PoolRewarder<Ty0>>(&PoolRewarder<Ty0>): ID
	21: StLoc[8](loc2: ID)
	22: MoveLoc[0](Arg0: &mut PoolRewarderRegistry)
	23: MutBorrowField[0](PoolRewarderRegistry.pool_rewarders: VecSet<ID>)
	24: CopyLoc[8](loc2: ID)
	25: Call vec_set::insert<ID>(&mut VecSet<ID>, ID)
	26: MoveLoc[7](loc1: PoolRewarder<Ty0>)
	27: Call transfer::share_object<PoolRewarder<Ty0>>(PoolRewarder<Ty0>)
	28: MoveLoc[8](loc2: ID)
	29: MoveLoc[4](Arg4: u64)
	30: MoveLoc[6](loc0: Double)
	31: Call double::to_scaled_val(Double): u256
	32: Call pool_incentive_events::emit_rewarder_created<Ty0>(ID, u64, u256)
	33: Ret
}

public withdraw_from_source<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &AdminCap, Arg4: &Clock, Arg5: u64, Arg6: &mut TxContext): Coin<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	3: MoveLoc[2](Arg2: &StabilityPool)
	4: Call stability_pool::pool_balance(&StabilityPool): u64
	5: MoveLoc[4](Arg4: &Clock)
	6: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	7: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	8: FreezeRef
	9: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	10: CopyLoc[5](Arg5: u64)
	11: LdFalse
	12: Call pool_incentive_events::emit_source_changed<Ty0>(ID, u64, bool)
	13: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	14: MutBorrowFieldGeneric[0](PoolRewarder.source: Balance<Ty0>)
	15: MoveLoc[5](Arg5: u64)
	16: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	17: MoveLoc[6](Arg6: &mut TxContext)
	18: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	19: Ret
}

public add_version(Arg0: &mut PoolRewarderRegistry, Arg1: &AdminCap, Arg2: u16) {
B0:
	0: MoveLoc[0](Arg0: &mut PoolRewarderRegistry)
	1: MutBorrowField[2](PoolRewarderRegistry.versions: VecSet<u16>)
	2: MoveLoc[2](Arg2: u16)
	3: Call vec_set::insert<u16>(&mut VecSet<u16>, u16)
	4: Ret
}

public remove_version(Arg0: &mut PoolRewarderRegistry, Arg1: &AdminCap, Arg2: u16) {
B0:
	0: MoveLoc[0](Arg0: &mut PoolRewarderRegistry)
	1: MutBorrowField[2](PoolRewarderRegistry.versions: VecSet<u16>)
	2: ImmBorrowLoc[2](Arg2: u16)
	3: Call vec_set::remove<u16>(&mut VecSet<u16>, &u16)
	4: Ret
}

public add_manager(Arg0: &mut PoolRewarderRegistry, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[0](Arg0: &mut PoolRewarderRegistry)
	1: MutBorrowField[3](PoolRewarderRegistry.managers: VecSet<address>)
	2: MoveLoc[2](Arg2: address)
	3: Call vec_set::insert<address>(&mut VecSet<address>, address)
	4: Ret
}

public remove_manager(Arg0: &mut PoolRewarderRegistry, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[0](Arg0: &mut PoolRewarderRegistry)
	1: MutBorrowField[3](PoolRewarderRegistry.managers: VecSet<address>)
	2: ImmBorrowLoc[2](Arg2: address)
	3: Call vec_set::remove<address>(&mut VecSet<address>, &address)
	4: Ret
}

public update_flow_rate<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &Clock, Arg4: u64, Arg5: u64, Arg6: &AccountRequest) {
L7:	loc0: Double
B0:
	0: CopyLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	3: MoveLoc[6](Arg6: &AccountRequest)
	4: Call assert_sender_is_manager(&PoolRewarderRegistry, &AccountRequest)
	5: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	6: MoveLoc[2](Arg2: &StabilityPool)
	7: Call stability_pool::pool_balance(&StabilityPool): u64
	8: MoveLoc[3](Arg3: &Clock)
	9: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	10: MoveLoc[4](Arg4: u64)
	11: MoveLoc[5](Arg5: u64)
	12: Call double::from_fraction(u64, u64): Double
	13: StLoc[7](loc0: Double)
	14: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	15: FreezeRef
	16: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	17: CopyLoc[7](loc0: Double)
	18: Call double::to_scaled_val(Double): u256
	19: Call pool_incentive_events::emit_flow_rate_changed<Ty0>(ID, u256)
	20: MoveLoc[7](loc0: Double)
	21: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	22: MutBorrowFieldGeneric[1](PoolRewarder.flow_rate: Double)
	23: WriteRef
	24: Ret
}

public update_rewarder_timestamp<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &Clock, Arg4: u64, Arg5: &AccountRequest) {
B0:
	0: CopyLoc[4](Arg4: u64)
	1: CopyLoc[3](Arg3: &Clock)
	2: Call clock::timestamp_ms(&Clock): u64
	3: Lt
	4: BrFalse(6)
B1:
	5: Call err_invalid_timestamp()
B2:
	6: CopyLoc[0](Arg0: &PoolRewarderRegistry)
	7: Call assert_valid_package_version(&PoolRewarderRegistry)
	8: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	9: MoveLoc[5](Arg5: &AccountRequest)
	10: Call assert_sender_is_manager(&PoolRewarderRegistry, &AccountRequest)
	11: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	12: MoveLoc[2](Arg2: &StabilityPool)
	13: Call stability_pool::pool_balance(&StabilityPool): u64
	14: MoveLoc[3](Arg3: &Clock)
	15: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	16: MoveLoc[4](Arg4: u64)
	17: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	18: MutBorrowFieldGeneric[2](PoolRewarder.timestamp: u64)
	19: WriteRef
	20: Ret
}

public deposit_to_source<Ty0>(Arg0: &mut PoolRewarder<Ty0>, Arg1: Coin<Ty0>) {
B0:
	0: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	1: FreezeRef
	2: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	3: ImmBorrowLoc[1](Arg1: Coin<Ty0>)
	4: Call coin::value<Ty0>(&Coin<Ty0>): u64
	5: LdTrue
	6: Call pool_incentive_events::emit_source_changed<Ty0>(ID, u64, bool)
	7: MoveLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	8: MutBorrowFieldGeneric[0](PoolRewarder.source: Balance<Ty0>)
	9: MoveLoc[1](Arg1: Coin<Ty0>)
	10: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	11: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	12: Pop
	13: Ret
}

public deposit_to_pool<Ty0>(Arg0: &mut PoolRewarder<Ty0>, Arg1: Coin<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	1: MutBorrowFieldGeneric[3](PoolRewarder.pool: Balance<Ty0>)
	2: MoveLoc[1](Arg1: Coin<Ty0>)
	3: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	4: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	5: Pop
	6: Ret
}

public new_checker(Arg0: &PoolRewarderRegistry, Arg1: PositionUpdateResponse): ResponseChecker {
B0:
	0: CopyLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	3: ImmBorrowField[0](PoolRewarderRegistry.pool_rewarders: VecSet<ID>)
	4: ReadRef
	5: MoveLoc[1](Arg1: PositionUpdateResponse)
	6: Pack[4](ResponseChecker)
	7: Ret
}

public update<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut ResponseChecker, Arg2: &mut PoolRewarder<Ty0>, Arg3: &Clock) {
L4:	loc0: ID
L5:	loc1: &mut VecSet<ID>
L6:	loc2: address
L7:	loc3: u64
L8:	loc4: u64
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: CopyLoc[1](Arg1: &mut ResponseChecker)
	3: FreezeRef
	4: CopyLoc[2](Arg2: &mut PoolRewarder<Ty0>)
	5: FreezeRef
	6: Call assert_unchecked_rewarder<Ty0>(&ResponseChecker, &PoolRewarder<Ty0>)
	7: CopyLoc[1](Arg1: &mut ResponseChecker)
	8: ImmBorrowField[7](ResponseChecker.response: PositionUpdateResponse)
	9: Call stability_pool::pool_vusd_balance_before(&PositionUpdateResponse): u64
	10: StLoc[7](loc3: u64)
	11: CopyLoc[1](Arg1: &mut ResponseChecker)
	12: ImmBorrowField[7](ResponseChecker.response: PositionUpdateResponse)
	13: Call stability_pool::position_vusd_balance_before(&PositionUpdateResponse): u64
	14: StLoc[8](loc4: u64)
	15: CopyLoc[2](Arg2: &mut PoolRewarder<Ty0>)
	16: CopyLoc[7](loc3: u64)
	17: CopyLoc[3](Arg3: &Clock)
	18: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	19: CopyLoc[1](Arg1: &mut ResponseChecker)
	20: ImmBorrowField[7](ResponseChecker.response: PositionUpdateResponse)
	21: Call stability_pool::account_address(&PositionUpdateResponse): address
	22: StLoc[6](loc2: address)
	23: CopyLoc[2](Arg2: &mut PoolRewarder<Ty0>)
	24: MoveLoc[7](loc3: u64)
	25: MoveLoc[8](loc4: u64)
	26: MoveLoc[6](loc2: address)
	27: MoveLoc[3](Arg3: &Clock)
	28: Call settle_reward<Ty0>(&mut PoolRewarder<Ty0>, u64, u64, address, &Clock): u64
	29: Pop
	30: MoveLoc[1](Arg1: &mut ResponseChecker)
	31: MutBorrowField[8](ResponseChecker.rewarder_ids: VecSet<ID>)
	32: StLoc[5](loc1: &mut VecSet<ID>)
	33: MoveLoc[2](Arg2: &mut PoolRewarder<Ty0>)
	34: FreezeRef
	35: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	36: StLoc[4](loc0: ID)
	37: MoveLoc[5](loc1: &mut VecSet<ID>)
	38: ImmBorrowLoc[4](loc0: ID)
	39: Call vec_set::remove<ID>(&mut VecSet<ID>, &ID)
	40: Ret
}

public destroy_checker(Arg0: &PoolRewarderRegistry, Arg1: ResponseChecker): PositionUpdateResponse {
L2:	loc0: PositionUpdateResponse
L3:	loc1: VecSet<ID>
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: MoveLoc[1](Arg1: ResponseChecker)
	3: Unpack[4](ResponseChecker)
	4: StLoc[2](loc0: PositionUpdateResponse)
	5: StLoc[3](loc1: VecSet<ID>)
	6: ImmBorrowLoc[3](loc1: VecSet<ID>)
	7: Call vec_set::is_empty<ID>(&VecSet<ID>): bool
	8: Not
	9: BrFalse(11)
B1:
	10: Call err_missing_rewarder_check()
B2:
	11: MutBorrowLoc[2](loc0: PositionUpdateResponse)
	12: LdFalse
	13: Pack[0](VirtuePoolIncentive)
	14: Call stability_pool::insert_witness<VirtuePoolIncentive>(&mut PositionUpdateResponse, VirtuePoolIncentive)
	15: MoveLoc[2](loc0: PositionUpdateResponse)
	16: Ret
}

public claim<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &AccountRequest, Arg4: &Clock, Arg5: &mut TxContext): Coin<Ty0> {
L6:	loc0: address
L7:	loc1: u64
L8:	loc2: Coin<Ty0>
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: MoveLoc[3](Arg3: &AccountRequest)
	3: Call account::request_address(&AccountRequest): address
	4: StLoc[6](loc0: address)
	5: CopyLoc[2](Arg2: &StabilityPool)
	6: CopyLoc[6](loc0: address)
	7: Call stability_pool::try_get_position_balance(&StabilityPool, address): u64
	8: StLoc[7](loc1: u64)
	9: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	10: MoveLoc[2](Arg2: &StabilityPool)
	11: Call stability_pool::pool_balance(&StabilityPool): u64
	12: MoveLoc[7](loc1: u64)
	13: CopyLoc[6](loc0: address)
	14: MoveLoc[4](Arg4: &Clock)
	15: Call settle_reward<Ty0>(&mut PoolRewarder<Ty0>, u64, u64, address, &Clock): u64
	16: Pop
	17: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	18: MutBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	19: CopyLoc[6](loc0: address)
	20: Call table::borrow_mut<address, StakeData<Ty0>>(&mut Table<address, StakeData<Ty0>>, address): &mut StakeData<Ty0>
	21: MutBorrowFieldGeneric[5](StakeData.reward: Balance<Ty0>)
	22: Call balance::withdraw_all<Ty0>(&mut Balance<Ty0>): Balance<Ty0>
	23: MoveLoc[5](Arg5: &mut TxContext)
	24: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	25: StLoc[8](loc2: Coin<Ty0>)
	26: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	27: FreezeRef
	28: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	29: MoveLoc[6](loc0: address)
	30: ImmBorrowLoc[8](loc2: Coin<Ty0>)
	31: Call coin::value<Ty0>(&Coin<Ty0>): u64
	32: Call pool_incentive_events::emit_claim_reward<Ty0>(ID, address, u64)
	33: MoveLoc[8](loc2: Coin<Ty0>)
	34: Ret
}

public airdrop<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: address, Arg4: &Clock, Arg5: Coin<Ty0>) {
L6:	loc0: u64
L7:	loc1: u64
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: CopyLoc[2](Arg2: &StabilityPool)
	3: Call stability_pool::pool_balance(&StabilityPool): u64
	4: StLoc[6](loc0: u64)
	5: MoveLoc[2](Arg2: &StabilityPool)
	6: CopyLoc[3](Arg3: address)
	7: Call stability_pool::try_get_position_balance(&StabilityPool, address): u64
	8: StLoc[7](loc1: u64)
	9: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	10: MoveLoc[6](loc0: u64)
	11: MoveLoc[7](loc1: u64)
	12: CopyLoc[3](Arg3: address)
	13: MoveLoc[4](Arg4: &Clock)
	14: Call settle_reward<Ty0>(&mut PoolRewarder<Ty0>, u64, u64, address, &Clock): u64
	15: Pop
	16: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	17: MutBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	18: MoveLoc[3](Arg3: address)
	19: Call table::borrow_mut<address, StakeData<Ty0>>(&mut Table<address, StakeData<Ty0>>, address): &mut StakeData<Ty0>
	20: MutBorrowFieldGeneric[5](StakeData.reward: Balance<Ty0>)
	21: MoveLoc[5](Arg5: Coin<Ty0>)
	22: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	23: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	24: Pop
	25: Ret
}

public id<Ty0>(Arg0: &PoolRewarder<Ty0>): ID {
B0:
	0: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	1: Call object::id<PoolRewarder<Ty0>>(&PoolRewarder<Ty0>): ID
	2: Ret
}

public stake_exists<Ty0>(Arg0: &PoolRewarder<Ty0>, Arg1: address): bool {
B0:
	0: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	1: ImmBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	2: MoveLoc[1](Arg1: address)
	3: Call table::contains<address, StakeData<Ty0>>(&Table<address, StakeData<Ty0>>, address): bool
	4: Ret
}

public realtime_reward_amount<Ty0>(Arg0: &PoolRewarder<Ty0>, Arg1: &StabilityPool, Arg2: address, Arg3: &Clock): u64 {
L4:	loc0: u64
L5:	loc1: u64
L6:	loc2: u64
B0:
	0: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	1: CopyLoc[2](Arg2: address)
	2: Call stake_exists<Ty0>(&PoolRewarder<Ty0>, address): bool
	3: BrFalse(12)
B1:
	4: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	5: ImmBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	6: CopyLoc[2](Arg2: address)
	7: Call table::borrow<address, StakeData<Ty0>>(&Table<address, StakeData<Ty0>>, address): &StakeData<Ty0>
	8: ImmBorrowFieldGeneric[5](StakeData.reward: Balance<Ty0>)
	9: Call balance::value<Ty0>(&Balance<Ty0>): u64
	10: StLoc[4](loc0: u64)
	11: Branch(14)
B2:
	12: LdU64(0)
	13: StLoc[4](loc0: u64)
B3:
	14: MoveLoc[4](loc0: u64)
	15: StLoc[6](loc2: u64)
	16: CopyLoc[1](Arg1: &StabilityPool)
	17: CopyLoc[2](Arg2: address)
	18: Call stability_pool::try_get_position_balance(&StabilityPool, address): u64
	19: StLoc[5](loc1: u64)
	20: MoveLoc[6](loc2: u64)
	21: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	22: MoveLoc[1](Arg1: &StabilityPool)
	23: Call stability_pool::pool_balance(&StabilityPool): u64
	24: MoveLoc[5](loc1: u64)
	25: MoveLoc[2](Arg2: address)
	26: MoveLoc[3](Arg3: &Clock)
	27: Call unsettled_reward_amount<Ty0>(&PoolRewarder<Ty0>, u64, u64, address, &Clock): u64
	28: Add
	29: Ret
}

public withdraw_from_source_to<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &AdminCap, Arg4: &Clock, Arg5: u64, Arg6: address, Arg7: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	2: MoveLoc[2](Arg2: &StabilityPool)
	3: MoveLoc[3](Arg3: &AdminCap)
	4: MoveLoc[4](Arg4: &Clock)
	5: MoveLoc[5](Arg5: u64)
	6: MoveLoc[7](Arg7: &mut TxContext)
	7: Call withdraw_from_source<Ty0>(&PoolRewarderRegistry, &mut PoolRewarder<Ty0>, &StabilityPool, &AdminCap, &Clock, u64, &mut TxContext): Coin<Ty0>
	8: MoveLoc[6](Arg6: address)
	9: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	10: Ret
}

public deposit_to_source_and_set_flow_rate<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &Clock, Arg4: Coin<Ty0>, Arg5: u64, Arg6: &TxContext) {
L7:	loc0: AccountRequest
L8:	loc1: u64
L9:	loc2: u64
L10:	loc3: &Clock
L11:	loc4: &StabilityPool
L12:	loc5: &mut PoolRewarder<Ty0>
L13:	loc6: &PoolRewarderRegistry
L14:	loc7: u64
B0:
	0: ImmBorrowLoc[4](Arg4: Coin<Ty0>)
	1: Call coin::value<Ty0>(&Coin<Ty0>): u64
	2: StLoc[14](loc7: u64)
	3: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	4: MoveLoc[4](Arg4: Coin<Ty0>)
	5: Call deposit_to_source<Ty0>(&mut PoolRewarder<Ty0>, Coin<Ty0>)
	6: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	7: StLoc[13](loc6: &PoolRewarderRegistry)
	8: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	9: StLoc[12](loc5: &mut PoolRewarder<Ty0>)
	10: MoveLoc[2](Arg2: &StabilityPool)
	11: StLoc[11](loc4: &StabilityPool)
	12: MoveLoc[3](Arg3: &Clock)
	13: StLoc[10](loc3: &Clock)
	14: MoveLoc[14](loc7: u64)
	15: StLoc[9](loc2: u64)
	16: MoveLoc[5](Arg5: u64)
	17: StLoc[8](loc1: u64)
	18: MoveLoc[6](Arg6: &TxContext)
	19: Call account::request(&TxContext): AccountRequest
	20: StLoc[7](loc0: AccountRequest)
	21: MoveLoc[13](loc6: &PoolRewarderRegistry)
	22: MoveLoc[12](loc5: &mut PoolRewarder<Ty0>)
	23: MoveLoc[11](loc4: &StabilityPool)
	24: MoveLoc[10](loc3: &Clock)
	25: MoveLoc[9](loc2: u64)
	26: MoveLoc[8](loc1: u64)
	27: ImmBorrowLoc[7](loc0: AccountRequest)
	28: Call update_flow_rate<Ty0>(&PoolRewarderRegistry, &mut PoolRewarder<Ty0>, &StabilityPool, &Clock, u64, u64, &AccountRequest)
	29: Ret
}

public set_flow_rate<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &Clock, Arg4: u64, Arg5: u64, Arg6: &TxContext) {
L7:	loc0: AccountRequest
L8:	loc1: u64
L9:	loc2: u64
L10:	loc3: &Clock
L11:	loc4: &StabilityPool
L12:	loc5: &mut PoolRewarder<Ty0>
L13:	loc6: &PoolRewarderRegistry
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: StLoc[13](loc6: &PoolRewarderRegistry)
	2: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	3: StLoc[12](loc5: &mut PoolRewarder<Ty0>)
	4: MoveLoc[2](Arg2: &StabilityPool)
	5: StLoc[11](loc4: &StabilityPool)
	6: MoveLoc[3](Arg3: &Clock)
	7: StLoc[10](loc3: &Clock)
	8: MoveLoc[4](Arg4: u64)
	9: StLoc[9](loc2: u64)
	10: MoveLoc[5](Arg5: u64)
	11: StLoc[8](loc1: u64)
	12: MoveLoc[6](Arg6: &TxContext)
	13: Call account::request(&TxContext): AccountRequest
	14: StLoc[7](loc0: AccountRequest)
	15: MoveLoc[13](loc6: &PoolRewarderRegistry)
	16: MoveLoc[12](loc5: &mut PoolRewarder<Ty0>)
	17: MoveLoc[11](loc4: &StabilityPool)
	18: MoveLoc[10](loc3: &Clock)
	19: MoveLoc[9](loc2: u64)
	20: MoveLoc[8](loc1: u64)
	21: ImmBorrowLoc[7](loc0: AccountRequest)
	22: Call update_flow_rate<Ty0>(&PoolRewarderRegistry, &mut PoolRewarder<Ty0>, &StabilityPool, &Clock, u64, u64, &AccountRequest)
	23: Ret
}

entry set_rewarder_timestamp<Ty0>(Arg0: &PoolRewarderRegistry, Arg1: &mut PoolRewarder<Ty0>, Arg2: &StabilityPool, Arg3: &Clock, Arg4: u64, Arg5: &TxContext) {
L6:	loc0: AccountRequest
L7:	loc1: &PoolRewarderRegistry
B0:
	0: CopyLoc[0](Arg0: &PoolRewarderRegistry)
	1: Call assert_valid_package_version(&PoolRewarderRegistry)
	2: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	3: StLoc[7](loc1: &PoolRewarderRegistry)
	4: MoveLoc[5](Arg5: &TxContext)
	5: Call account::request(&TxContext): AccountRequest
	6: StLoc[6](loc0: AccountRequest)
	7: MoveLoc[7](loc1: &PoolRewarderRegistry)
	8: ImmBorrowLoc[6](loc0: AccountRequest)
	9: Call assert_sender_is_manager(&PoolRewarderRegistry, &AccountRequest)
	10: CopyLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	11: MoveLoc[2](Arg2: &StabilityPool)
	12: Call stability_pool::pool_balance(&StabilityPool): u64
	13: MoveLoc[3](Arg3: &Clock)
	14: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	15: MoveLoc[4](Arg4: u64)
	16: MoveLoc[1](Arg1: &mut PoolRewarder<Ty0>)
	17: MutBorrowFieldGeneric[2](PoolRewarder.timestamp: u64)
	18: WriteRef
	19: Ret
}

realtime_rewarder_release_and_unit<Ty0>(Arg0: &PoolRewarder<Ty0>, Arg1: u64, Arg2: &Clock): u64 * Double * bool {
L3:	loc0: bool
L4:	loc1: u64
L5:	loc2: Double
L6:	loc3: bool
L7:	loc4: u64
L8:	loc5: u64
L9:	loc6: Double
L10:	loc7: u64
L11:	loc8: u64
L12:	loc9: u64
B0:
	0: MoveLoc[2](Arg2: &Clock)
	1: Call clock::timestamp_ms(&Clock): u64
	2: StLoc[8](loc5: u64)
	3: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	4: ImmBorrowFieldGeneric[2](PoolRewarder.timestamp: u64)
	5: ReadRef
	6: StLoc[10](loc7: u64)
	7: CopyLoc[8](loc5: u64)
	8: CopyLoc[10](loc7: u64)
	9: Gt
	10: BrFalse(16)
B1:
	11: CopyLoc[1](Arg1: u64)
	12: LdU64(0)
	13: Gt
	14: StLoc[3](loc0: bool)
	15: Branch(18)
B2:
	16: LdFalse
	17: StLoc[3](loc0: bool)
B3:
	18: MoveLoc[3](loc0: bool)
	19: BrFalse(56)
B4:
	20: MoveLoc[8](loc5: u64)
	21: MoveLoc[10](loc7: u64)
	22: Sub
	23: StLoc[12](loc9: u64)
	24: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	25: ImmBorrowFieldGeneric[1](PoolRewarder.flow_rate: Double)
	26: ReadRef
	27: MoveLoc[12](loc9: u64)
	28: Call double::mul_u64(Double, u64): Double
	29: Call double::floor(Double): u64
	30: StLoc[7](loc4: u64)
	31: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	32: ImmBorrowFieldGeneric[0](PoolRewarder.source: Balance<Ty0>)
	33: Call balance::value<Ty0>(&Balance<Ty0>): u64
	34: StLoc[11](loc8: u64)
	35: CopyLoc[7](loc4: u64)
	36: CopyLoc[11](loc8: u64)
	37: Gt
	38: BrFalse(41)
B5:
	39: MoveLoc[11](loc8: u64)
	40: StLoc[7](loc4: u64)
B6:
	41: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	42: ImmBorrowFieldGeneric[6](PoolRewarder.unit: Double)
	43: ReadRef
	44: CopyLoc[7](loc4: u64)
	45: MoveLoc[1](Arg1: u64)
	46: Call double::from_fraction(u64, u64): Double
	47: Call double::add(Double, Double): Double
	48: StLoc[9](loc6: Double)
	49: MoveLoc[7](loc4: u64)
	50: MoveLoc[9](loc6: Double)
	51: LdTrue
	52: StLoc[6](loc3: bool)
	53: StLoc[5](loc2: Double)
	54: StLoc[4](loc1: u64)
	55: Branch(64)
B7:
	56: LdU64(0)
	57: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	58: ImmBorrowFieldGeneric[6](PoolRewarder.unit: Double)
	59: ReadRef
	60: LdFalse
	61: StLoc[6](loc3: bool)
	62: StLoc[5](loc2: Double)
	63: StLoc[4](loc1: u64)
B8:
	64: MoveLoc[4](loc1: u64)
	65: MoveLoc[5](loc2: Double)
	66: MoveLoc[6](loc3: bool)
	67: Ret
}

source_to_pool<Ty0>(Arg0: &mut PoolRewarder<Ty0>, Arg1: u64, Arg2: &Clock) {
L3:	loc0: u64
L4:	loc1: Double
L5:	loc2: Balance<Ty0>
L6:	loc3: bool
B0:
	0: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	1: FreezeRef
	2: MoveLoc[1](Arg1: u64)
	3: CopyLoc[2](Arg2: &Clock)
	4: Call realtime_rewarder_release_and_unit<Ty0>(&PoolRewarder<Ty0>, u64, &Clock): u64 * Double * bool
	5: StLoc[6](loc3: bool)
	6: StLoc[4](loc1: Double)
	7: StLoc[3](loc0: u64)
	8: MoveLoc[6](loc3: bool)
	9: BrFalse(16)
B1:
	10: MoveLoc[2](Arg2: &Clock)
	11: Call clock::timestamp_ms(&Clock): u64
	12: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	13: MutBorrowFieldGeneric[2](PoolRewarder.timestamp: u64)
	14: WriteRef
	15: Branch(18)
B2:
	16: MoveLoc[2](Arg2: &Clock)
	17: Pop
B3:
	18: MoveLoc[4](loc1: Double)
	19: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	20: MutBorrowFieldGeneric[6](PoolRewarder.unit: Double)
	21: WriteRef
	22: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	23: MutBorrowFieldGeneric[0](PoolRewarder.source: Balance<Ty0>)
	24: MoveLoc[3](loc0: u64)
	25: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	26: StLoc[5](loc2: Balance<Ty0>)
	27: MoveLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	28: MutBorrowFieldGeneric[3](PoolRewarder.pool: Balance<Ty0>)
	29: MoveLoc[5](loc2: Balance<Ty0>)
	30: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	31: Pop
	32: Ret
}

unsettled_reward_amount<Ty0>(Arg0: &PoolRewarder<Ty0>, Arg1: u64, Arg2: u64, Arg3: address, Arg4: &Clock): u64 {
L5:	loc0: Double
L6:	loc1: Double
L7:	loc2: Double
B0:
	0: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	1: MoveLoc[1](Arg1: u64)
	2: MoveLoc[4](Arg4: &Clock)
	3: Call realtime_rewarder_release_and_unit<Ty0>(&PoolRewarder<Ty0>, u64, &Clock): u64 * Double * bool
	4: Pop
	5: StLoc[7](loc2: Double)
	6: Pop
	7: CopyLoc[0](Arg0: &PoolRewarder<Ty0>)
	8: CopyLoc[3](Arg3: address)
	9: Call stake_exists<Ty0>(&PoolRewarder<Ty0>, address): bool
	10: BrFalse(19)
B1:
	11: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	12: ImmBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	13: MoveLoc[3](Arg3: address)
	14: Call table::borrow<address, StakeData<Ty0>>(&Table<address, StakeData<Ty0>>, address): &StakeData<Ty0>
	15: ImmBorrowFieldGeneric[7](StakeData.unit: Double)
	16: ReadRef
	17: StLoc[5](loc0: Double)
	18: Branch(24)
B2:
	19: MoveLoc[0](Arg0: &PoolRewarder<Ty0>)
	20: Pop
	21: LdU64(0)
	22: Call double::from(u64): Double
	23: StLoc[5](loc0: Double)
B3:
	24: MoveLoc[5](loc0: Double)
	25: StLoc[6](loc1: Double)
	26: MoveLoc[7](loc2: Double)
	27: MoveLoc[6](loc1: Double)
	28: Call double::sub(Double, Double): Double
	29: MoveLoc[2](Arg2: u64)
	30: Call double::mul_u64(Double, u64): Double
	31: Call double::floor(Double): u64
	32: Ret
}

settle_reward<Ty0>(Arg0: &mut PoolRewarder<Ty0>, Arg1: u64, Arg2: u64, Arg3: address, Arg4: &Clock): u64 {
L5:	loc0: u64
L6:	loc1: Balance<Ty0>
L7:	loc2: u64
L8:	loc3: &mut StakeData<Ty0>
L9:	loc4: StakeData<Ty0>
L10:	loc5: u64
B0:
	0: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	1: CopyLoc[1](Arg1: u64)
	2: CopyLoc[4](Arg4: &Clock)
	3: Call source_to_pool<Ty0>(&mut PoolRewarder<Ty0>, u64, &Clock)
	4: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	5: FreezeRef
	6: MoveLoc[1](Arg1: u64)
	7: MoveLoc[2](Arg2: u64)
	8: CopyLoc[3](Arg3: address)
	9: MoveLoc[4](Arg4: &Clock)
	10: Call unsettled_reward_amount<Ty0>(&PoolRewarder<Ty0>, u64, u64, address, &Clock): u64
	11: StLoc[10](loc5: u64)
	12: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	13: MutBorrowFieldGeneric[3](PoolRewarder.pool: Balance<Ty0>)
	14: MoveLoc[10](loc5: u64)
	15: Call balance::split<Ty0>(&mut Balance<Ty0>, u64): Balance<Ty0>
	16: StLoc[6](loc1: Balance<Ty0>)
	17: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	18: FreezeRef
	19: CopyLoc[3](Arg3: address)
	20: Call stake_exists<Ty0>(&PoolRewarder<Ty0>, address): bool
	21: BrFalse(39)
B1:
	22: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	23: MutBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	24: MoveLoc[3](Arg3: address)
	25: Call table::borrow_mut<address, StakeData<Ty0>>(&mut Table<address, StakeData<Ty0>>, address): &mut StakeData<Ty0>
	26: StLoc[8](loc3: &mut StakeData<Ty0>)
	27: MoveLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	28: ImmBorrowFieldGeneric[6](PoolRewarder.unit: Double)
	29: ReadRef
	30: CopyLoc[8](loc3: &mut StakeData<Ty0>)
	31: MutBorrowFieldGeneric[7](StakeData.unit: Double)
	32: WriteRef
	33: MoveLoc[8](loc3: &mut StakeData<Ty0>)
	34: MutBorrowFieldGeneric[5](StakeData.reward: Balance<Ty0>)
	35: MoveLoc[6](loc1: Balance<Ty0>)
	36: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	37: StLoc[5](loc0: u64)
	38: Branch(55)
B2:
	39: ImmBorrowLoc[6](loc1: Balance<Ty0>)
	40: Call balance::value<Ty0>(&Balance<Ty0>): u64
	41: StLoc[7](loc2: u64)
	42: CopyLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	43: ImmBorrowFieldGeneric[6](PoolRewarder.unit: Double)
	44: ReadRef
	45: MoveLoc[6](loc1: Balance<Ty0>)
	46: PackGeneric[1](StakeData<Ty0>)
	47: StLoc[9](loc4: StakeData<Ty0>)
	48: MoveLoc[0](Arg0: &mut PoolRewarder<Ty0>)
	49: MutBorrowFieldGeneric[4](PoolRewarder.stake_table: Table<address, StakeData<Ty0>>)
	50: MoveLoc[3](Arg3: address)
	51: MoveLoc[9](loc4: StakeData<Ty0>)
	52: Call table::add<address, StakeData<Ty0>>(&mut Table<address, StakeData<Ty0>>, address, StakeData<Ty0>)
	53: MoveLoc[7](loc2: u64)
	54: StLoc[5](loc0: u64)
B3:
	55: MoveLoc[5](loc0: u64)
	56: Ret
}

assert_unchecked_rewarder<Ty0>(Arg0: &ResponseChecker, Arg1: &PoolRewarder<Ty0>) {
L2:	loc0: ID
L3:	loc1: &VecSet<ID>
B0:
	0: MoveLoc[0](Arg0: &ResponseChecker)
	1: ImmBorrowField[8](ResponseChecker.rewarder_ids: VecSet<ID>)
	2: StLoc[3](loc1: &VecSet<ID>)
	3: MoveLoc[1](Arg1: &PoolRewarder<Ty0>)
	4: Call id<Ty0>(&PoolRewarder<Ty0>): ID
	5: StLoc[2](loc0: ID)
	6: MoveLoc[3](loc1: &VecSet<ID>)
	7: ImmBorrowLoc[2](loc0: ID)
	8: Call vec_set::contains<ID>(&VecSet<ID>, &ID): bool
	9: Not
	10: BrFalse(12)
B1:
	11: Call err_invalid_rewarder()
B2:
	12: Ret
}

assert_valid_package_version(Arg0: &PoolRewarderRegistry) {
L1:	loc0: u16
L2:	loc1: &VecSet<u16>
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: ImmBorrowField[2](PoolRewarderRegistry.versions: VecSet<u16>)
	2: StLoc[2](loc1: &VecSet<u16>)
	3: Call package_version(): u16
	4: StLoc[1](loc0: u16)
	5: MoveLoc[2](loc1: &VecSet<u16>)
	6: ImmBorrowLoc[1](loc0: u16)
	7: Call vec_set::contains<u16>(&VecSet<u16>, &u16): bool
	8: Not
	9: BrFalse(11)
B1:
	10: Call err_invalid_package_version()
B2:
	11: Ret
}

assert_sender_is_manager(Arg0: &PoolRewarderRegistry, Arg1: &AccountRequest) {
L2:	loc0: address
L3:	loc1: &VecSet<address>
B0:
	0: MoveLoc[0](Arg0: &PoolRewarderRegistry)
	1: ImmBorrowField[3](PoolRewarderRegistry.managers: VecSet<address>)
	2: StLoc[3](loc1: &VecSet<address>)
	3: MoveLoc[1](Arg1: &AccountRequest)
	4: Call account::request_address(&AccountRequest): address
	5: StLoc[2](loc0: address)
	6: MoveLoc[3](loc1: &VecSet<address>)
	7: ImmBorrowLoc[2](loc0: address)
	8: Call vec_set::contains<address>(&VecSet<address>, &address): bool
	9: Not
	10: BrFalse(12)
B1:
	11: Call err_sender_is_not_manager()
B2:
	12: Ret
}

Constants [
	0 => u16: 1
	1 => u64: 201
	2 => u64: 202
	3 => u64: 203
	4 => u64: 204
	5 => u64: 205
]
}
