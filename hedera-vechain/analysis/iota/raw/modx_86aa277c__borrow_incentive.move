// Move bytecode v6
module 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10.borrow_incentive {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::table;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::request;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::vault;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::double;
use 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10::admin_of_incentive;
use 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10::borrow_incentive_events;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::limited_supply;

struct VirtueBorrowIncentive has drop {
	dummy_field: bool
}

struct StakeData<phantom Ty0> has store {
	unit: Double,
	reward: Balance<Ty0>
}

struct VaultRewarderRegistry has key {
	id: UID,
	vault_rewarders: Table<ID, VecSet<ID>>,
	versions: VecSet<u16>,
	managers: VecSet<address>
}

struct VaultRewarder<phantom Ty0> has key {
	id: UID,
	vault_id: ID,
	source: Balance<Ty0>,
	pool: Balance<Ty0>,
	flow_rate: Double,
	stake_table: Table<address, StakeData<Ty0>>,
	unit: Double,
	timestamp: u64
}

struct RequestChecker<phantom Ty0> {
	vault_id: ID,
	rewarder_ids: VecSet<ID>,
	request: UpdateRequest<Ty0>
}

public package_version(): u16 {
B0:
	0: LdConst[0](u16: 1)
	1: Ret
}

err_invalid_rewarder() {
B0:
	0: LdConst[1](u64: 101)
	1: Abort
}

err_missing_rewarder_check() {
B0:
	0: LdConst[2](u64: 102)
	1: Abort
}

err_invalid_timestamp() {
B0:
	0: LdConst[3](u64: 103)
	1: Abort
}

err_wrong_vault() {
B0:
	0: LdConst[4](u64: 104)
	1: Abort
}

err_invalid_package_version() {
B0:
	0: LdConst[5](u64: 105)
	1: Abort
}

err_sender_is_not_manager() {
B0:
	0: LdConst[6](u64: 106)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: CopyLoc[0](Arg0: &mut TxContext)
	3: Call table::new<ID, VecSet<ID>>(&mut TxContext): Table<ID, VecSet<ID>>
	4: Call package_version(): u16
	5: Call vec_set::singleton<u16>(u16): VecSet<u16>
	6: MoveLoc[0](Arg0: &mut TxContext)
	7: FreezeRef
	8: Call tx_context::sender(&TxContext): address
	9: Call vec_set::singleton<address>(address): VecSet<address>
	10: Pack[2](VaultRewarderRegistry)
	11: Call transfer::share_object<VaultRewarderRegistry>(VaultRewarderRegistry)
	12: Ret
}

public create<Ty0, Ty1>(Arg0: &mut VaultRewarderRegistry, Arg1: &AdminCap, Arg2: &Vault<Ty0>, Arg3: u64, Arg4: u64, Arg5: u64, Arg6: &mut TxContext) {
L7:	loc0: Double
L8:	loc1: VaultRewarder<Ty1>
L9:	loc2: ID
L10:	loc3: ID
B0:
	0: CopyLoc[0](Arg0: &mut VaultRewarderRegistry)
	1: FreezeRef
	2: Call assert_valid_package_version(&VaultRewarderRegistry)
	3: MoveLoc[3](Arg3: u64)
	4: MoveLoc[4](Arg4: u64)
	5: Call double::from_fraction(u64, u64): Double
	6: StLoc[7](loc0: Double)
	7: CopyLoc[6](Arg6: &mut TxContext)
	8: Call object::new(&mut TxContext): UID
	9: CopyLoc[2](Arg2: &Vault<Ty0>)
	10: Call vault::id<Ty0>(&Vault<Ty0>): ID
	11: Call balance::zero<Ty1>(): Balance<Ty1>
	12: Call balance::zero<Ty1>(): Balance<Ty1>
	13: CopyLoc[7](loc0: Double)
	14: MoveLoc[6](Arg6: &mut TxContext)
	15: Call table::new<address, StakeData<Ty1>>(&mut TxContext): Table<address, StakeData<Ty1>>
	16: LdU64(0)
	17: Call double::from(u64): Double
	18: CopyLoc[5](Arg5: u64)
	19: PackGeneric[0](VaultRewarder<Ty1>)
	20: StLoc[8](loc1: VaultRewarder<Ty1>)
	21: ImmBorrowLoc[8](loc1: VaultRewarder<Ty1>)
	22: Call object::id<VaultRewarder<Ty1>>(&VaultRewarder<Ty1>): ID
	23: StLoc[9](loc2: ID)
	24: MoveLoc[8](loc1: VaultRewarder<Ty1>)
	25: Call transfer::share_object<VaultRewarder<Ty1>>(VaultRewarder<Ty1>)
	26: CopyLoc[2](Arg2: &Vault<Ty0>)
	27: Call vault::id<Ty0>(&Vault<Ty0>): ID
	28: StLoc[10](loc3: ID)
	29: CopyLoc[0](Arg0: &mut VaultRewarderRegistry)
	30: ImmBorrowField[0](VaultRewarderRegistry.vault_rewarders: Table<ID, VecSet<ID>>)
	31: CopyLoc[10](loc3: ID)
	32: Call table::contains<ID, VecSet<ID>>(&Table<ID, VecSet<ID>>, ID): bool
	33: BrFalse(41)
B1:
	34: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	35: MutBorrowField[0](VaultRewarderRegistry.vault_rewarders: Table<ID, VecSet<ID>>)
	36: MoveLoc[10](loc3: ID)
	37: Call table::borrow_mut<ID, VecSet<ID>>(&mut Table<ID, VecSet<ID>>, ID): &mut VecSet<ID>
	38: CopyLoc[9](loc2: ID)
	39: Call vec_set::insert<ID>(&mut VecSet<ID>, ID)
	40: Branch(47)
B2:
	41: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	42: MutBorrowField[0](VaultRewarderRegistry.vault_rewarders: Table<ID, VecSet<ID>>)
	43: MoveLoc[10](loc3: ID)
	44: CopyLoc[9](loc2: ID)
	45: Call vec_set::singleton<ID>(ID): VecSet<ID>
	46: Call table::add<ID, VecSet<ID>>(&mut Table<ID, VecSet<ID>>, ID, VecSet<ID>)
B3:
	47: MoveLoc[2](Arg2: &Vault<Ty0>)
	48: Call vault::id<Ty0>(&Vault<Ty0>): ID
	49: MoveLoc[9](loc2: ID)
	50: MoveLoc[5](Arg5: u64)
	51: MoveLoc[7](loc0: Double)
	52: Call double::to_scaled_val(Double): u256
	53: Call borrow_incentive_events::emit_rewarder_created<Ty0, Ty1>(ID, ID, u64, u256)
	54: Ret
}

public withdraw_from_source<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &AdminCap, Arg4: &Clock, Arg5: u64, Arg6: &mut TxContext): Coin<Ty1> {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	3: MoveLoc[2](Arg2: &Vault<Ty0>)
	4: MoveLoc[4](Arg4: &Clock)
	5: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	6: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	7: FreezeRef
	8: Call id<Ty1>(&VaultRewarder<Ty1>): ID
	9: CopyLoc[5](Arg5: u64)
	10: LdFalse
	11: Call borrow_incentive_events::emit_source_changed<Ty1>(ID, u64, bool)
	12: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	13: MutBorrowFieldGeneric[0](VaultRewarder.source: Balance<Ty1>)
	14: MoveLoc[5](Arg5: u64)
	15: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	16: MoveLoc[6](Arg6: &mut TxContext)
	17: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	18: Ret
}

public add_version(Arg0: &mut VaultRewarderRegistry, Arg1: &AdminCap, Arg2: u16) {
B0:
	0: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	1: MutBorrowField[2](VaultRewarderRegistry.versions: VecSet<u16>)
	2: MoveLoc[2](Arg2: u16)
	3: Call vec_set::insert<u16>(&mut VecSet<u16>, u16)
	4: Ret
}

public remove_version(Arg0: &mut VaultRewarderRegistry, Arg1: &AdminCap, Arg2: u16) {
B0:
	0: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	1: MutBorrowField[2](VaultRewarderRegistry.versions: VecSet<u16>)
	2: ImmBorrowLoc[2](Arg2: u16)
	3: Call vec_set::remove<u16>(&mut VecSet<u16>, &u16)
	4: Ret
}

public add_manager(Arg0: &mut VaultRewarderRegistry, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	1: MutBorrowField[3](VaultRewarderRegistry.managers: VecSet<address>)
	2: MoveLoc[2](Arg2: address)
	3: Call vec_set::insert<address>(&mut VecSet<address>, address)
	4: Ret
}

public remove_manager(Arg0: &mut VaultRewarderRegistry, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[0](Arg0: &mut VaultRewarderRegistry)
	1: MutBorrowField[3](VaultRewarderRegistry.managers: VecSet<address>)
	2: ImmBorrowLoc[2](Arg2: address)
	3: Call vec_set::remove<address>(&mut VecSet<address>, &address)
	4: Ret
}

public update_flow_rate<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &Clock, Arg4: u64, Arg5: u64, Arg6: &AccountRequest) {
L7:	loc0: Double
B0:
	0: CopyLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	3: MoveLoc[6](Arg6: &AccountRequest)
	4: Call assert_sender_is_manager(&VaultRewarderRegistry, &AccountRequest)
	5: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	6: MoveLoc[2](Arg2: &Vault<Ty0>)
	7: MoveLoc[3](Arg3: &Clock)
	8: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	9: MoveLoc[4](Arg4: u64)
	10: MoveLoc[5](Arg5: u64)
	11: Call double::from_fraction(u64, u64): Double
	12: StLoc[7](loc0: Double)
	13: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	14: FreezeRef
	15: Call id<Ty1>(&VaultRewarder<Ty1>): ID
	16: CopyLoc[7](loc0: Double)
	17: Call double::to_scaled_val(Double): u256
	18: Call borrow_incentive_events::emit_flow_rate_changed<Ty0, Ty1>(ID, u256)
	19: MoveLoc[7](loc0: Double)
	20: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	21: MutBorrowFieldGeneric[1](VaultRewarder.flow_rate: Double)
	22: WriteRef
	23: Ret
}

public update_rewarder_timestamp<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &Clock, Arg4: u64, Arg5: &AccountRequest) {
B0:
	0: CopyLoc[4](Arg4: u64)
	1: CopyLoc[3](Arg3: &Clock)
	2: Call clock::timestamp_ms(&Clock): u64
	3: Lt
	4: BrFalse(6)
B1:
	5: Call err_invalid_timestamp()
B2:
	6: CopyLoc[0](Arg0: &VaultRewarderRegistry)
	7: Call assert_valid_package_version(&VaultRewarderRegistry)
	8: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	9: MoveLoc[5](Arg5: &AccountRequest)
	10: Call assert_sender_is_manager(&VaultRewarderRegistry, &AccountRequest)
	11: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	12: MoveLoc[2](Arg2: &Vault<Ty0>)
	13: MoveLoc[3](Arg3: &Clock)
	14: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	15: MoveLoc[4](Arg4: u64)
	16: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	17: MutBorrowFieldGeneric[2](VaultRewarder.timestamp: u64)
	18: WriteRef
	19: Ret
}

public deposit_to_source<Ty0>(Arg0: &mut VaultRewarder<Ty0>, Arg1: Coin<Ty0>) {
B0:
	0: CopyLoc[0](Arg0: &mut VaultRewarder<Ty0>)
	1: FreezeRef
	2: Call id<Ty0>(&VaultRewarder<Ty0>): ID
	3: ImmBorrowLoc[1](Arg1: Coin<Ty0>)
	4: Call coin::value<Ty0>(&Coin<Ty0>): u64
	5: LdTrue
	6: Call borrow_incentive_events::emit_source_changed<Ty0>(ID, u64, bool)
	7: MoveLoc[0](Arg0: &mut VaultRewarder<Ty0>)
	8: MutBorrowFieldGeneric[3](VaultRewarder.source: Balance<Ty0>)
	9: MoveLoc[1](Arg1: Coin<Ty0>)
	10: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	11: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	12: Pop
	13: Ret
}

public deposit_to_pool<Ty0>(Arg0: &mut VaultRewarder<Ty0>, Arg1: Coin<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: &mut VaultRewarder<Ty0>)
	1: MutBorrowFieldGeneric[4](VaultRewarder.pool: Balance<Ty0>)
	2: MoveLoc[1](Arg1: Coin<Ty0>)
	3: Call coin::into_balance<Ty0>(Coin<Ty0>): Balance<Ty0>
	4: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	5: Pop
	6: Ret
}

public new_checker<Ty0>(Arg0: &VaultRewarderRegistry, Arg1: UpdateRequest<Ty0>): RequestChecker<Ty0> {
L2:	loc0: VecSet<ID>
L3:	loc1: VecSet<ID>
L4:	loc2: ID
B0:
	0: CopyLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: ImmBorrowLoc[1](Arg1: UpdateRequest<Ty0>)
	3: Call request::vault_id<Ty0>(&UpdateRequest<Ty0>): ID
	4: StLoc[4](loc2: ID)
	5: CopyLoc[0](Arg0: &VaultRewarderRegistry)
	6: ImmBorrowField[0](VaultRewarderRegistry.vault_rewarders: Table<ID, VecSet<ID>>)
	7: CopyLoc[4](loc2: ID)
	8: Call table::contains<ID, VecSet<ID>>(&Table<ID, VecSet<ID>>, ID): bool
	9: BrFalse(17)
B1:
	10: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	11: ImmBorrowField[0](VaultRewarderRegistry.vault_rewarders: Table<ID, VecSet<ID>>)
	12: CopyLoc[4](loc2: ID)
	13: Call table::borrow<ID, VecSet<ID>>(&Table<ID, VecSet<ID>>, ID): &VecSet<ID>
	14: ReadRef
	15: StLoc[2](loc0: VecSet<ID>)
	16: Branch(21)
B2:
	17: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	18: Pop
	19: Call vec_set::empty<ID>(): VecSet<ID>
	20: StLoc[2](loc0: VecSet<ID>)
B3:
	21: MoveLoc[2](loc0: VecSet<ID>)
	22: StLoc[3](loc1: VecSet<ID>)
	23: MoveLoc[4](loc2: ID)
	24: MoveLoc[3](loc1: VecSet<ID>)
	25: MoveLoc[1](Arg1: UpdateRequest<Ty0>)
	26: PackGeneric[1](RequestChecker<Ty0>)
	27: Ret
}

public update<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut RequestChecker<Ty0>, Arg2: &Vault<Ty0>, Arg3: &mut VaultRewarder<Ty1>, Arg4: &Clock) {
L5:	loc0: ID
L6:	loc1: &mut VecSet<ID>
L7:	loc2: address
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: CopyLoc[1](Arg1: &mut RequestChecker<Ty0>)
	3: FreezeRef
	4: CopyLoc[3](Arg3: &mut VaultRewarder<Ty1>)
	5: FreezeRef
	6: Call assert_unchecked_rewarder<Ty0, Ty1>(&RequestChecker<Ty0>, &VaultRewarder<Ty1>)
	7: CopyLoc[3](Arg3: &mut VaultRewarder<Ty1>)
	8: CopyLoc[2](Arg2: &Vault<Ty0>)
	9: CopyLoc[4](Arg4: &Clock)
	10: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	11: CopyLoc[1](Arg1: &mut RequestChecker<Ty0>)
	12: ImmBorrowFieldGeneric[5](RequestChecker.request: UpdateRequest<Ty0>)
	13: Call request::account<Ty0>(&UpdateRequest<Ty0>): address
	14: StLoc[7](loc2: address)
	15: CopyLoc[3](Arg3: &mut VaultRewarder<Ty1>)
	16: MoveLoc[2](Arg2: &Vault<Ty0>)
	17: MoveLoc[7](loc2: address)
	18: MoveLoc[4](Arg4: &Clock)
	19: Call settle_reward<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, address, &Clock): u64
	20: Pop
	21: MoveLoc[1](Arg1: &mut RequestChecker<Ty0>)
	22: MutBorrowFieldGeneric[6](RequestChecker.rewarder_ids: VecSet<ID>)
	23: StLoc[6](loc1: &mut VecSet<ID>)
	24: MoveLoc[3](Arg3: &mut VaultRewarder<Ty1>)
	25: FreezeRef
	26: Call id<Ty1>(&VaultRewarder<Ty1>): ID
	27: StLoc[5](loc0: ID)
	28: MoveLoc[6](loc1: &mut VecSet<ID>)
	29: ImmBorrowLoc[5](loc0: ID)
	30: Call vec_set::remove<ID>(&mut VecSet<ID>, &ID)
	31: Ret
}

public destroy_checker<Ty0>(Arg0: &VaultRewarderRegistry, Arg1: RequestChecker<Ty0>): UpdateRequest<Ty0> {
L2:	loc0: UpdateRequest<Ty0>
L3:	loc1: VecSet<ID>
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: MoveLoc[1](Arg1: RequestChecker<Ty0>)
	3: UnpackGeneric[1](RequestChecker<Ty0>)
	4: StLoc[2](loc0: UpdateRequest<Ty0>)
	5: StLoc[3](loc1: VecSet<ID>)
	6: Pop
	7: ImmBorrowLoc[3](loc1: VecSet<ID>)
	8: Call vec_set::is_empty<ID>(&VecSet<ID>): bool
	9: Not
	10: BrFalse(12)
B1:
	11: Call err_missing_rewarder_check()
B2:
	12: MutBorrowLoc[2](loc0: UpdateRequest<Ty0>)
	13: LdFalse
	14: Pack[0](VirtueBorrowIncentive)
	15: Call request::add_witness<Ty0, VirtueBorrowIncentive>(&mut UpdateRequest<Ty0>, VirtueBorrowIncentive)
	16: MoveLoc[2](loc0: UpdateRequest<Ty0>)
	17: Ret
}

public claim<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &AccountRequest, Arg4: &Clock, Arg5: &mut TxContext): Coin<Ty1> {
L6:	loc0: address
L7:	loc1: Coin<Ty1>
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: MoveLoc[3](Arg3: &AccountRequest)
	3: Call account::request_address(&AccountRequest): address
	4: StLoc[6](loc0: address)
	5: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	6: MoveLoc[2](Arg2: &Vault<Ty0>)
	7: CopyLoc[6](loc0: address)
	8: MoveLoc[4](Arg4: &Clock)
	9: Call settle_reward<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, address, &Clock): u64
	10: Pop
	11: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	12: MutBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	13: CopyLoc[6](loc0: address)
	14: Call table::borrow_mut<address, StakeData<Ty1>>(&mut Table<address, StakeData<Ty1>>, address): &mut StakeData<Ty1>
	15: MutBorrowFieldGeneric[8](StakeData.reward: Balance<Ty1>)
	16: Call balance::withdraw_all<Ty1>(&mut Balance<Ty1>): Balance<Ty1>
	17: MoveLoc[5](Arg5: &mut TxContext)
	18: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	19: StLoc[7](loc1: Coin<Ty1>)
	20: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	21: FreezeRef
	22: Call id<Ty1>(&VaultRewarder<Ty1>): ID
	23: MoveLoc[6](loc0: address)
	24: ImmBorrowLoc[7](loc1: Coin<Ty1>)
	25: Call coin::value<Ty1>(&Coin<Ty1>): u64
	26: Call borrow_incentive_events::emit_claim_reward<Ty0, Ty1>(ID, address, u64)
	27: MoveLoc[7](loc1: Coin<Ty1>)
	28: Ret
}

public airdrop<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: address, Arg4: &Clock, Arg5: Coin<Ty1>) {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	3: MoveLoc[2](Arg2: &Vault<Ty0>)
	4: CopyLoc[3](Arg3: address)
	5: MoveLoc[4](Arg4: &Clock)
	6: Call settle_reward<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, address, &Clock): u64
	7: Pop
	8: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	9: MutBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	10: MoveLoc[3](Arg3: address)
	11: Call table::borrow_mut<address, StakeData<Ty1>>(&mut Table<address, StakeData<Ty1>>, address): &mut StakeData<Ty1>
	12: MutBorrowFieldGeneric[8](StakeData.reward: Balance<Ty1>)
	13: MoveLoc[5](Arg5: Coin<Ty1>)
	14: Call coin::into_balance<Ty1>(Coin<Ty1>): Balance<Ty1>
	15: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	16: Pop
	17: Ret
}

public id<Ty0>(Arg0: &VaultRewarder<Ty0>): ID {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarder<Ty0>)
	1: Call object::id<VaultRewarder<Ty0>>(&VaultRewarder<Ty0>): ID
	2: Ret
}

public stake_exists<Ty0>(Arg0: &VaultRewarder<Ty0>, Arg1: address): bool {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarder<Ty0>)
	1: ImmBorrowFieldGeneric[9](VaultRewarder.stake_table: Table<address, StakeData<Ty0>>)
	2: MoveLoc[1](Arg1: address)
	3: Call table::contains<address, StakeData<Ty0>>(&Table<address, StakeData<Ty0>>, address): bool
	4: Ret
}

public realtime_reward_amount<Ty0, Ty1>(Arg0: &VaultRewarder<Ty1>, Arg1: &Vault<Ty0>, Arg2: address, Arg3: &Clock): u64 {
L4:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	1: CopyLoc[2](Arg2: address)
	2: Call stake_exists<Ty1>(&VaultRewarder<Ty1>, address): bool
	3: BrFalse(12)
B1:
	4: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	5: ImmBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	6: CopyLoc[2](Arg2: address)
	7: Call table::borrow<address, StakeData<Ty1>>(&Table<address, StakeData<Ty1>>, address): &StakeData<Ty1>
	8: ImmBorrowFieldGeneric[8](StakeData.reward: Balance<Ty1>)
	9: Call balance::value<Ty1>(&Balance<Ty1>): u64
	10: StLoc[4](loc0: u64)
	11: Branch(14)
B2:
	12: LdU64(0)
	13: StLoc[4](loc0: u64)
B3:
	14: MoveLoc[4](loc0: u64)
	15: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	16: MoveLoc[1](Arg1: &Vault<Ty0>)
	17: MoveLoc[2](Arg2: address)
	18: MoveLoc[3](Arg3: &Clock)
	19: Call unsettled_reward_amount<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>, address, &Clock): u64
	20: Add
	21: Ret
}

public withdraw_from_source_to<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &AdminCap, Arg4: &Clock, Arg5: u64, Arg6: address, Arg7: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	2: MoveLoc[2](Arg2: &Vault<Ty0>)
	3: MoveLoc[3](Arg3: &AdminCap)
	4: MoveLoc[4](Arg4: &Clock)
	5: MoveLoc[5](Arg5: u64)
	6: MoveLoc[7](Arg7: &mut TxContext)
	7: Call withdraw_from_source<Ty0, Ty1>(&VaultRewarderRegistry, &mut VaultRewarder<Ty1>, &Vault<Ty0>, &AdminCap, &Clock, u64, &mut TxContext): Coin<Ty1>
	8: MoveLoc[6](Arg6: address)
	9: Call transfer::public_transfer<Coin<Ty1>>(Coin<Ty1>, address)
	10: Ret
}

public deposit_to_source_and_set_flow_rate<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &Clock, Arg4: Coin<Ty1>, Arg5: u64, Arg6: &TxContext) {
L7:	loc0: AccountRequest
L8:	loc1: u64
L9:	loc2: u64
L10:	loc3: &Clock
L11:	loc4: &Vault<Ty0>
L12:	loc5: &mut VaultRewarder<Ty1>
L13:	loc6: &VaultRewarderRegistry
L14:	loc7: u64
B0:
	0: ImmBorrowLoc[4](Arg4: Coin<Ty1>)
	1: Call coin::value<Ty1>(&Coin<Ty1>): u64
	2: StLoc[14](loc7: u64)
	3: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	4: MoveLoc[4](Arg4: Coin<Ty1>)
	5: Call deposit_to_source<Ty1>(&mut VaultRewarder<Ty1>, Coin<Ty1>)
	6: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	7: StLoc[13](loc6: &VaultRewarderRegistry)
	8: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	9: StLoc[12](loc5: &mut VaultRewarder<Ty1>)
	10: MoveLoc[2](Arg2: &Vault<Ty0>)
	11: StLoc[11](loc4: &Vault<Ty0>)
	12: MoveLoc[3](Arg3: &Clock)
	13: StLoc[10](loc3: &Clock)
	14: MoveLoc[14](loc7: u64)
	15: StLoc[9](loc2: u64)
	16: MoveLoc[5](Arg5: u64)
	17: StLoc[8](loc1: u64)
	18: MoveLoc[6](Arg6: &TxContext)
	19: Call account::request(&TxContext): AccountRequest
	20: StLoc[7](loc0: AccountRequest)
	21: MoveLoc[13](loc6: &VaultRewarderRegistry)
	22: MoveLoc[12](loc5: &mut VaultRewarder<Ty1>)
	23: MoveLoc[11](loc4: &Vault<Ty0>)
	24: MoveLoc[10](loc3: &Clock)
	25: MoveLoc[9](loc2: u64)
	26: MoveLoc[8](loc1: u64)
	27: ImmBorrowLoc[7](loc0: AccountRequest)
	28: Call update_flow_rate<Ty0, Ty1>(&VaultRewarderRegistry, &mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock, u64, u64, &AccountRequest)
	29: Ret
}

public set_flow_rate<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &Clock, Arg4: u64, Arg5: u64, Arg6: &TxContext) {
L7:	loc0: AccountRequest
L8:	loc1: u64
L9:	loc2: u64
L10:	loc3: &Clock
L11:	loc4: &Vault<Ty0>
L12:	loc5: &mut VaultRewarder<Ty1>
L13:	loc6: &VaultRewarderRegistry
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: StLoc[13](loc6: &VaultRewarderRegistry)
	2: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	3: StLoc[12](loc5: &mut VaultRewarder<Ty1>)
	4: MoveLoc[2](Arg2: &Vault<Ty0>)
	5: StLoc[11](loc4: &Vault<Ty0>)
	6: MoveLoc[3](Arg3: &Clock)
	7: StLoc[10](loc3: &Clock)
	8: MoveLoc[4](Arg4: u64)
	9: StLoc[9](loc2: u64)
	10: MoveLoc[5](Arg5: u64)
	11: StLoc[8](loc1: u64)
	12: MoveLoc[6](Arg6: &TxContext)
	13: Call account::request(&TxContext): AccountRequest
	14: StLoc[7](loc0: AccountRequest)
	15: MoveLoc[13](loc6: &VaultRewarderRegistry)
	16: MoveLoc[12](loc5: &mut VaultRewarder<Ty1>)
	17: MoveLoc[11](loc4: &Vault<Ty0>)
	18: MoveLoc[10](loc3: &Clock)
	19: MoveLoc[9](loc2: u64)
	20: MoveLoc[8](loc1: u64)
	21: ImmBorrowLoc[7](loc0: AccountRequest)
	22: Call update_flow_rate<Ty0, Ty1>(&VaultRewarderRegistry, &mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock, u64, u64, &AccountRequest)
	23: Ret
}

public set_rewarder_timestamp<Ty0, Ty1>(Arg0: &VaultRewarderRegistry, Arg1: &mut VaultRewarder<Ty1>, Arg2: &Vault<Ty0>, Arg3: &Clock, Arg4: u64, Arg5: &TxContext) {
L6:	loc0: AccountRequest
L7:	loc1: &VaultRewarderRegistry
B0:
	0: CopyLoc[0](Arg0: &VaultRewarderRegistry)
	1: Call assert_valid_package_version(&VaultRewarderRegistry)
	2: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	3: StLoc[7](loc1: &VaultRewarderRegistry)
	4: MoveLoc[5](Arg5: &TxContext)
	5: Call account::request(&TxContext): AccountRequest
	6: StLoc[6](loc0: AccountRequest)
	7: MoveLoc[7](loc1: &VaultRewarderRegistry)
	8: ImmBorrowLoc[6](loc0: AccountRequest)
	9: Call assert_sender_is_manager(&VaultRewarderRegistry, &AccountRequest)
	10: CopyLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	11: MoveLoc[2](Arg2: &Vault<Ty0>)
	12: MoveLoc[3](Arg3: &Clock)
	13: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	14: MoveLoc[4](Arg4: u64)
	15: MoveLoc[1](Arg1: &mut VaultRewarder<Ty1>)
	16: MutBorrowFieldGeneric[2](VaultRewarder.timestamp: u64)
	17: WriteRef
	18: Ret
}

realtime_rewarder_release_and_unit<Ty0, Ty1>(Arg0: &VaultRewarder<Ty1>, Arg1: &Vault<Ty0>, Arg2: &Clock): u64 * Double * bool {
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
	3: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	4: ImmBorrowFieldGeneric[2](VaultRewarder.timestamp: u64)
	5: ReadRef
	6: StLoc[10](loc7: u64)
	7: CopyLoc[8](loc5: u64)
	8: CopyLoc[10](loc7: u64)
	9: Gt
	10: BrFalse(18)
B1:
	11: CopyLoc[1](Arg1: &Vault<Ty0>)
	12: Call vault::limited_supply<Ty0>(&Vault<Ty0>): &LimitedSupply
	13: Call limited_supply::supply(&LimitedSupply): u64
	14: LdU64(0)
	15: Gt
	16: StLoc[3](loc0: bool)
	17: Branch(20)
B2:
	18: LdFalse
	19: StLoc[3](loc0: bool)
B3:
	20: MoveLoc[3](loc0: bool)
	21: BrFalse(60)
B4:
	22: MoveLoc[8](loc5: u64)
	23: MoveLoc[10](loc7: u64)
	24: Sub
	25: StLoc[12](loc9: u64)
	26: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	27: ImmBorrowFieldGeneric[1](VaultRewarder.flow_rate: Double)
	28: ReadRef
	29: MoveLoc[12](loc9: u64)
	30: Call double::mul_u64(Double, u64): Double
	31: Call double::floor(Double): u64
	32: StLoc[7](loc4: u64)
	33: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	34: ImmBorrowFieldGeneric[0](VaultRewarder.source: Balance<Ty1>)
	35: Call balance::value<Ty1>(&Balance<Ty1>): u64
	36: StLoc[11](loc8: u64)
	37: CopyLoc[7](loc4: u64)
	38: CopyLoc[11](loc8: u64)
	39: Gt
	40: BrFalse(43)
B5:
	41: MoveLoc[11](loc8: u64)
	42: StLoc[7](loc4: u64)
B6:
	43: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	44: ImmBorrowFieldGeneric[10](VaultRewarder.unit: Double)
	45: ReadRef
	46: CopyLoc[7](loc4: u64)
	47: MoveLoc[1](Arg1: &Vault<Ty0>)
	48: Call vault::limited_supply<Ty0>(&Vault<Ty0>): &LimitedSupply
	49: Call limited_supply::supply(&LimitedSupply): u64
	50: Call double::from_fraction(u64, u64): Double
	51: Call double::add(Double, Double): Double
	52: StLoc[9](loc6: Double)
	53: MoveLoc[7](loc4: u64)
	54: MoveLoc[9](loc6: Double)
	55: LdTrue
	56: StLoc[6](loc3: bool)
	57: StLoc[5](loc2: Double)
	58: StLoc[4](loc1: u64)
	59: Branch(70)
B7:
	60: MoveLoc[1](Arg1: &Vault<Ty0>)
	61: Pop
	62: LdU64(0)
	63: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	64: ImmBorrowFieldGeneric[10](VaultRewarder.unit: Double)
	65: ReadRef
	66: LdFalse
	67: StLoc[6](loc3: bool)
	68: StLoc[5](loc2: Double)
	69: StLoc[4](loc1: u64)
B8:
	70: MoveLoc[4](loc1: u64)
	71: MoveLoc[5](loc2: Double)
	72: MoveLoc[6](loc3: bool)
	73: Ret
}

source_to_pool<Ty0, Ty1>(Arg0: &mut VaultRewarder<Ty1>, Arg1: &Vault<Ty0>, Arg2: &Clock) {
L3:	loc0: u64
L4:	loc1: Double
L5:	loc2: Balance<Ty1>
L6:	loc3: bool
B0:
	0: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	1: FreezeRef
	2: CopyLoc[1](Arg1: &Vault<Ty0>)
	3: Call assert_correct_vault<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>)
	4: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	5: FreezeRef
	6: MoveLoc[1](Arg1: &Vault<Ty0>)
	7: CopyLoc[2](Arg2: &Clock)
	8: Call realtime_rewarder_release_and_unit<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>, &Clock): u64 * Double * bool
	9: StLoc[6](loc3: bool)
	10: StLoc[4](loc1: Double)
	11: StLoc[3](loc0: u64)
	12: MoveLoc[6](loc3: bool)
	13: BrFalse(20)
B1:
	14: MoveLoc[2](Arg2: &Clock)
	15: Call clock::timestamp_ms(&Clock): u64
	16: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	17: MutBorrowFieldGeneric[2](VaultRewarder.timestamp: u64)
	18: WriteRef
	19: Branch(22)
B2:
	20: MoveLoc[2](Arg2: &Clock)
	21: Pop
B3:
	22: MoveLoc[4](loc1: Double)
	23: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	24: MutBorrowFieldGeneric[10](VaultRewarder.unit: Double)
	25: WriteRef
	26: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	27: MutBorrowFieldGeneric[0](VaultRewarder.source: Balance<Ty1>)
	28: MoveLoc[3](loc0: u64)
	29: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	30: StLoc[5](loc2: Balance<Ty1>)
	31: MoveLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	32: MutBorrowFieldGeneric[11](VaultRewarder.pool: Balance<Ty1>)
	33: MoveLoc[5](loc2: Balance<Ty1>)
	34: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	35: Pop
	36: Ret
}

unsettled_reward_amount<Ty0, Ty1>(Arg0: &VaultRewarder<Ty1>, Arg1: &Vault<Ty0>, Arg2: address, Arg3: &Clock): u64 {
L4:	loc0: Double
L5:	loc1: u64
L6:	loc2: Double
L7:	loc3: u64
L8:	loc4: Double
B0:
	0: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	1: CopyLoc[1](Arg1: &Vault<Ty0>)
	2: Call assert_correct_vault<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>)
	3: CopyLoc[1](Arg1: &Vault<Ty0>)
	4: CopyLoc[2](Arg2: address)
	5: Call vault::position_exists<Ty0>(&Vault<Ty0>, address): bool
	6: BrFalse(47)
B1:
	7: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	8: CopyLoc[1](Arg1: &Vault<Ty0>)
	9: MoveLoc[3](Arg3: &Clock)
	10: Call realtime_rewarder_release_and_unit<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>, &Clock): u64 * Double * bool
	11: Pop
	12: StLoc[8](loc4: Double)
	13: Pop
	14: CopyLoc[0](Arg0: &VaultRewarder<Ty1>)
	15: CopyLoc[2](Arg2: address)
	16: Call stake_exists<Ty1>(&VaultRewarder<Ty1>, address): bool
	17: BrFalse(26)
B2:
	18: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	19: ImmBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	20: CopyLoc[2](Arg2: address)
	21: Call table::borrow<address, StakeData<Ty1>>(&Table<address, StakeData<Ty1>>, address): &StakeData<Ty1>
	22: ImmBorrowFieldGeneric[12](StakeData.unit: Double)
	23: ReadRef
	24: StLoc[4](loc0: Double)
	25: Branch(31)
B3:
	26: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	27: Pop
	28: LdU64(0)
	29: Call double::from(u64): Double
	30: StLoc[4](loc0: Double)
B4:
	31: MoveLoc[4](loc0: Double)
	32: StLoc[6](loc2: Double)
	33: MoveLoc[1](Arg1: &Vault<Ty0>)
	34: MoveLoc[2](Arg2: address)
	35: Call vault::get_raw_position_data<Ty0>(&Vault<Ty0>, address): u64 * u64 * u64
	36: Pop
	37: StLoc[7](loc3: u64)
	38: Pop
	39: MoveLoc[8](loc4: Double)
	40: MoveLoc[6](loc2: Double)
	41: Call double::sub(Double, Double): Double
	42: MoveLoc[7](loc3: u64)
	43: Call double::mul_u64(Double, u64): Double
	44: Call double::floor(Double): u64
	45: StLoc[5](loc1: u64)
	46: Branch(55)
B5:
	47: MoveLoc[1](Arg1: &Vault<Ty0>)
	48: Pop
	49: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	50: Pop
	51: MoveLoc[3](Arg3: &Clock)
	52: Pop
	53: LdU64(0)
	54: StLoc[5](loc1: u64)
B6:
	55: MoveLoc[5](loc1: u64)
	56: Ret
}

settle_reward<Ty0, Ty1>(Arg0: &mut VaultRewarder<Ty1>, Arg1: &Vault<Ty0>, Arg2: address, Arg3: &Clock): u64 {
L4:	loc0: u64
L5:	loc1: Balance<Ty1>
L6:	loc2: u64
L7:	loc3: &mut StakeData<Ty1>
L8:	loc4: StakeData<Ty1>
L9:	loc5: u64
B0:
	0: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	1: CopyLoc[1](Arg1: &Vault<Ty0>)
	2: CopyLoc[3](Arg3: &Clock)
	3: Call source_to_pool<Ty0, Ty1>(&mut VaultRewarder<Ty1>, &Vault<Ty0>, &Clock)
	4: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	5: FreezeRef
	6: MoveLoc[1](Arg1: &Vault<Ty0>)
	7: CopyLoc[2](Arg2: address)
	8: MoveLoc[3](Arg3: &Clock)
	9: Call unsettled_reward_amount<Ty0, Ty1>(&VaultRewarder<Ty1>, &Vault<Ty0>, address, &Clock): u64
	10: StLoc[9](loc5: u64)
	11: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	12: MutBorrowFieldGeneric[11](VaultRewarder.pool: Balance<Ty1>)
	13: MoveLoc[9](loc5: u64)
	14: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	15: StLoc[5](loc1: Balance<Ty1>)
	16: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	17: FreezeRef
	18: CopyLoc[2](Arg2: address)
	19: Call stake_exists<Ty1>(&VaultRewarder<Ty1>, address): bool
	20: BrFalse(38)
B1:
	21: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	22: MutBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	23: MoveLoc[2](Arg2: address)
	24: Call table::borrow_mut<address, StakeData<Ty1>>(&mut Table<address, StakeData<Ty1>>, address): &mut StakeData<Ty1>
	25: StLoc[7](loc3: &mut StakeData<Ty1>)
	26: MoveLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	27: ImmBorrowFieldGeneric[10](VaultRewarder.unit: Double)
	28: ReadRef
	29: CopyLoc[7](loc3: &mut StakeData<Ty1>)
	30: MutBorrowFieldGeneric[12](StakeData.unit: Double)
	31: WriteRef
	32: MoveLoc[7](loc3: &mut StakeData<Ty1>)
	33: MutBorrowFieldGeneric[8](StakeData.reward: Balance<Ty1>)
	34: MoveLoc[5](loc1: Balance<Ty1>)
	35: Call balance::join<Ty1>(&mut Balance<Ty1>, Balance<Ty1>): u64
	36: StLoc[4](loc0: u64)
	37: Branch(54)
B2:
	38: ImmBorrowLoc[5](loc1: Balance<Ty1>)
	39: Call balance::value<Ty1>(&Balance<Ty1>): u64
	40: StLoc[6](loc2: u64)
	41: CopyLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	42: ImmBorrowFieldGeneric[10](VaultRewarder.unit: Double)
	43: ReadRef
	44: MoveLoc[5](loc1: Balance<Ty1>)
	45: PackGeneric[2](StakeData<Ty1>)
	46: StLoc[8](loc4: StakeData<Ty1>)
	47: MoveLoc[0](Arg0: &mut VaultRewarder<Ty1>)
	48: MutBorrowFieldGeneric[7](VaultRewarder.stake_table: Table<address, StakeData<Ty1>>)
	49: MoveLoc[2](Arg2: address)
	50: MoveLoc[8](loc4: StakeData<Ty1>)
	51: Call table::add<address, StakeData<Ty1>>(&mut Table<address, StakeData<Ty1>>, address, StakeData<Ty1>)
	52: MoveLoc[6](loc2: u64)
	53: StLoc[4](loc0: u64)
B3:
	54: MoveLoc[4](loc0: u64)
	55: Ret
}

assert_unchecked_rewarder<Ty0, Ty1>(Arg0: &RequestChecker<Ty0>, Arg1: &VaultRewarder<Ty1>) {
L2:	loc0: ID
L3:	loc1: &VecSet<ID>
B0:
	0: MoveLoc[0](Arg0: &RequestChecker<Ty0>)
	1: ImmBorrowFieldGeneric[6](RequestChecker.rewarder_ids: VecSet<ID>)
	2: StLoc[3](loc1: &VecSet<ID>)
	3: MoveLoc[1](Arg1: &VaultRewarder<Ty1>)
	4: Call id<Ty1>(&VaultRewarder<Ty1>): ID
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

assert_correct_vault<Ty0, Ty1>(Arg0: &VaultRewarder<Ty1>, Arg1: &Vault<Ty0>) {
B0:
	0: MoveLoc[0](Arg0: &VaultRewarder<Ty1>)
	1: ImmBorrowFieldGeneric[13](VaultRewarder.vault_id: ID)
	2: ReadRef
	3: MoveLoc[1](Arg1: &Vault<Ty0>)
	4: Call vault::id<Ty0>(&Vault<Ty0>): ID
	5: Neq
	6: BrFalse(8)
B1:
	7: Call err_wrong_vault()
B2:
	8: Ret
}

assert_valid_package_version(Arg0: &VaultRewarderRegistry) {
L1:	loc0: u16
L2:	loc1: &VecSet<u16>
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: ImmBorrowField[2](VaultRewarderRegistry.versions: VecSet<u16>)
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

assert_sender_is_manager(Arg0: &VaultRewarderRegistry, Arg1: &AccountRequest) {
L2:	loc0: address
L3:	loc1: &VecSet<address>
B0:
	0: MoveLoc[0](Arg0: &VaultRewarderRegistry)
	1: ImmBorrowField[3](VaultRewarderRegistry.managers: VecSet<address>)
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
	1 => u64: 101
	2 => u64: 102
	3 => u64: 103
	4 => u64: 104
	5 => u64: 105
	6 => u64: 106
]
}
