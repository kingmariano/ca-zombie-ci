// Move bytecode v6
module d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f.vusd {
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_field;
use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_object_field;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::url;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::account;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::limited_supply;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::module_request;

struct Mint<phantom Ty0> has copy, drop {
	amount: u64,
	module_supply: u64,
	total_supply: u64
}

struct Burn<phantom Ty0> has copy, drop {
	amount: u64,
	module_supply: u64,
	total_supply: u64
}

struct Collect<phantom Ty0, phantom Ty1> has copy, drop {
	memo: String,
	amount: u64
}

struct Claim<phantom Ty0, phantom Ty1> has copy, drop {
	amount: u64
}

struct VUSD has drop {
	dummy_field: bool
}

struct CapKey has copy, drop, store {
	dummy_field: bool
}

struct Treasury has key {
	id: UID,
	module_supply_map: VecMap<TypeName, LimitedSupply>,
	module_versions_map: VecMap<TypeName, VecSet<u64>>,
	beneficiary: address
}

err_invalid_module() {
B0:
	0: LdConst[0](u64: 200)
	1: Abort
}

err_invalid_module_version() {
B0:
	0: LdConst[1](u64: 201)
	1: Abort
}

err_invalid_supply_limit() {
B0:
	0: LdConst[2](u64: 202)
	1: Abort
}

err_not_beneficiary() {
B0:
	0: LdConst[3](u64: 203)
	1: Abort
}

err_coin_type_not_found() {
B0:
	0: LdConst[4](u64: 204)
	1: Abort
}

init(Arg0: VUSD, Arg1: &mut TxContext) {
L2:	loc0: TreasuryCap<VUSD>
L3:	loc1: UID
L4:	loc2: CoinMetadata<VUSD>
B0:
	0: MoveLoc[0](Arg0: VUSD)
	1: Call decimal(): u8
	2: LdConst[5](vector<u8>: "VUS..)
	3: LdConst[6](vector<u8>: "Vir..)
	4: LdConst[7](vector<u8>: "the..)
	5: LdConst[8](vector<u8>: "htt..)
	6: Call url::new_unsafe_from_bytes(vector<u8>): Url
	7: Call option::some<Url>(Url): Option<Url>
	8: CopyLoc[1](Arg1: &mut TxContext)
	9: Call coin::create_currency<VUSD>(VUSD, u8, vector<u8>, vector<u8>, vector<u8>, Option<Url>, &mut TxContext): TreasuryCap<VUSD> * CoinMetadata<VUSD>
	10: StLoc[4](loc2: CoinMetadata<VUSD>)
	11: StLoc[2](loc0: TreasuryCap<VUSD>)
	12: MoveLoc[4](loc2: CoinMetadata<VUSD>)
	13: Call transfer::public_share_object<CoinMetadata<VUSD>>(CoinMetadata<VUSD>)
	14: CopyLoc[1](Arg1: &mut TxContext)
	15: Call object::new(&mut TxContext): UID
	16: StLoc[3](loc1: UID)
	17: MutBorrowLoc[3](loc1: UID)
	18: Call cap_key(): CapKey
	19: MoveLoc[2](loc0: TreasuryCap<VUSD>)
	20: Call dynamic_object_field::add<CapKey, TreasuryCap<VUSD>>(&mut UID, CapKey, TreasuryCap<VUSD>)
	21: MoveLoc[3](loc1: UID)
	22: Call vec_map::empty<TypeName, LimitedSupply>(): VecMap<TypeName, LimitedSupply>
	23: Call vec_map::empty<TypeName, VecSet<u64>>(): VecMap<TypeName, VecSet<u64>>
	24: MoveLoc[1](Arg1: &mut TxContext)
	25: FreezeRef
	26: Call tx_context::sender(&TxContext): address
	27: Pack[6](Treasury)
	28: Call transfer::share_object<Treasury>(Treasury)
	29: Ret
}

public set_beneficiary(Arg0: &mut Treasury, Arg1: &AdminCap, Arg2: address) {
B0:
	0: MoveLoc[2](Arg2: address)
	1: MoveLoc[0](Arg0: &mut Treasury)
	2: MutBorrowField[0](Treasury.beneficiary: address)
	3: WriteRef
	4: Ret
}

public set_supply_limit<Ty0: drop>(Arg0: &mut Treasury, Arg1: &AdminCap, Arg2: u64) {
L3:	loc0: LimitedSupply
L4:	loc1: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[4](loc1: TypeName)
	2: CopyLoc[0](Arg0: &mut Treasury)
	3: FreezeRef
	4: Call module_supply_map(&Treasury): &VecMap<TypeName, LimitedSupply>
	5: ImmBorrowLoc[4](loc1: TypeName)
	6: Call vec_map::contains<TypeName, LimitedSupply>(&VecMap<TypeName, LimitedSupply>, &TypeName): bool
	7: BrFalse(15)
B1:
	8: MoveLoc[0](Arg0: &mut Treasury)
	9: MutBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	10: ImmBorrowLoc[4](loc1: TypeName)
	11: Call vec_map::get_mut<TypeName, LimitedSupply>(&mut VecMap<TypeName, LimitedSupply>, &TypeName): &mut LimitedSupply
	12: MoveLoc[2](Arg2: u64)
	13: Call limited_supply::set_limit(&mut LimitedSupply, u64)
	14: Branch(23)
B2:
	15: MoveLoc[2](Arg2: u64)
	16: Call limited_supply::new(u64): LimitedSupply
	17: StLoc[3](loc0: LimitedSupply)
	18: MoveLoc[0](Arg0: &mut Treasury)
	19: MutBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	20: MoveLoc[4](loc1: TypeName)
	21: MoveLoc[3](loc0: LimitedSupply)
	22: Call vec_map::insert<TypeName, LimitedSupply>(&mut VecMap<TypeName, LimitedSupply>, TypeName, LimitedSupply)
B3:
	23: Ret
}

public add_version<Ty0: drop>(Arg0: &mut Treasury, Arg1: &AdminCap, Arg2: u64) {
L3:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Treasury)
	3: FreezeRef
	4: Call module_versions_map(&Treasury): &VecMap<TypeName, VecSet<u64>>
	5: ImmBorrowLoc[3](loc0: TypeName)
	6: Call vec_map::contains<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): bool
	7: BrFalse(15)
B1:
	8: MoveLoc[0](Arg0: &mut Treasury)
	9: MutBorrowField[2](Treasury.module_versions_map: VecMap<TypeName, VecSet<u64>>)
	10: ImmBorrowLoc[3](loc0: TypeName)
	11: Call vec_map::get_mut<TypeName, VecSet<u64>>(&mut VecMap<TypeName, VecSet<u64>>, &TypeName): &mut VecSet<u64>
	12: MoveLoc[2](Arg2: u64)
	13: Call vec_set::insert<u64>(&mut VecSet<u64>, u64)
	14: Branch(21)
B2:
	15: MoveLoc[0](Arg0: &mut Treasury)
	16: MutBorrowField[2](Treasury.module_versions_map: VecMap<TypeName, VecSet<u64>>)
	17: MoveLoc[3](loc0: TypeName)
	18: MoveLoc[2](Arg2: u64)
	19: Call vec_set::singleton<u64>(u64): VecSet<u64>
	20: Call vec_map::insert<TypeName, VecSet<u64>>(&mut VecMap<TypeName, VecSet<u64>>, TypeName, VecSet<u64>)
B3:
	21: Ret
}

public remove_version<Ty0: drop>(Arg0: &mut Treasury, Arg1: &AdminCap, Arg2: u64) {
L3:	loc0: bool
L4:	loc1: TypeName
L5:	loc2: &VecMap<TypeName, VecSet<u64>>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[4](loc1: TypeName)
	2: CopyLoc[0](Arg0: &mut Treasury)
	3: FreezeRef
	4: Call module_versions_map(&Treasury): &VecMap<TypeName, VecSet<u64>>
	5: StLoc[5](loc2: &VecMap<TypeName, VecSet<u64>>)
	6: CopyLoc[5](loc2: &VecMap<TypeName, VecSet<u64>>)
	7: ImmBorrowLoc[4](loc1: TypeName)
	8: Call vec_map::contains<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): bool
	9: BrFalse(17)
B1:
	10: MoveLoc[5](loc2: &VecMap<TypeName, VecSet<u64>>)
	11: ImmBorrowLoc[4](loc1: TypeName)
	12: Call vec_map::get<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): &VecSet<u64>
	13: ImmBorrowLoc[2](Arg2: u64)
	14: Call vec_set::contains<u64>(&VecSet<u64>, &u64): bool
	15: StLoc[3](loc0: bool)
	16: Branch(21)
B2:
	17: MoveLoc[5](loc2: &VecMap<TypeName, VecSet<u64>>)
	18: Pop
	19: LdFalse
	20: StLoc[3](loc0: bool)
B3:
	21: MoveLoc[3](loc0: bool)
	22: BrFalse(30)
B4:
	23: MoveLoc[0](Arg0: &mut Treasury)
	24: MutBorrowField[2](Treasury.module_versions_map: VecMap<TypeName, VecSet<u64>>)
	25: ImmBorrowLoc[4](loc1: TypeName)
	26: Call vec_map::get_mut<TypeName, VecSet<u64>>(&mut VecMap<TypeName, VecSet<u64>>, &TypeName): &mut VecSet<u64>
	27: ImmBorrowLoc[2](Arg2: u64)
	28: Call vec_set::remove<u64>(&mut VecSet<u64>, &u64)
	29: Branch(32)
B5:
	30: MoveLoc[0](Arg0: &mut Treasury)
	31: Pop
B6:
	32: Ret
}

public remove_module<Ty0: drop>(Arg0: &mut Treasury, Arg1: &AdminCap) {
L2:	loc0: TypeName
L3:	loc1: LimitedSupply
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Treasury)
	3: FreezeRef
	4: Call module_supply_map(&Treasury): &VecMap<TypeName, LimitedSupply>
	5: ImmBorrowLoc[2](loc0: TypeName)
	6: Call vec_map::contains<TypeName, LimitedSupply>(&VecMap<TypeName, LimitedSupply>, &TypeName): bool
	7: BrFalse(16)
B1:
	8: CopyLoc[0](Arg0: &mut Treasury)
	9: MutBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	10: ImmBorrowLoc[2](loc0: TypeName)
	11: Call vec_map::remove<TypeName, LimitedSupply>(&mut VecMap<TypeName, LimitedSupply>, &TypeName): TypeName * LimitedSupply
	12: StLoc[3](loc1: LimitedSupply)
	13: Pop
	14: MoveLoc[3](loc1: LimitedSupply)
	15: Call limited_supply::destroy(LimitedSupply)
B2:
	16: CopyLoc[0](Arg0: &mut Treasury)
	17: FreezeRef
	18: Call module_versions_map(&Treasury): &VecMap<TypeName, VecSet<u64>>
	19: ImmBorrowLoc[2](loc0: TypeName)
	20: Call vec_map::contains<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): bool
	21: BrFalse(29)
B3:
	22: MoveLoc[0](Arg0: &mut Treasury)
	23: MutBorrowField[2](Treasury.module_versions_map: VecMap<TypeName, VecSet<u64>>)
	24: ImmBorrowLoc[2](loc0: TypeName)
	25: Call vec_map::remove<TypeName, VecSet<u64>>(&mut VecMap<TypeName, VecSet<u64>>, &TypeName): TypeName * VecSet<u64>
	26: Pop
	27: Pop
	28: Branch(31)
B4:
	29: MoveLoc[0](Arg0: &mut Treasury)
	30: Pop
B5:
	31: Ret
}

public mint<Ty0: drop>(Arg0: &mut Treasury, Arg1: &ModuleRequest<Ty0>, Arg2: u64, Arg3: &mut TxContext): Coin<VUSD> {
L4:	loc0: Coin<VUSD>
L5:	loc1: u64
L6:	loc2: Coin<VUSD>
B0:
	0: CopyLoc[2](Arg2: u64)
	1: LdU64(0)
	2: Gt
	3: BrFalse(26)
B1:
	4: CopyLoc[0](Arg0: &mut Treasury)
	5: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	6: Call borrow_supply_mut<Ty0>(&mut Treasury, &ModuleRequest<Ty0>): &mut LimitedSupply
	7: CopyLoc[2](Arg2: u64)
	8: Call limited_supply::increase(&mut LimitedSupply, u64): u64
	9: StLoc[5](loc1: u64)
	10: CopyLoc[0](Arg0: &mut Treasury)
	11: Call borrow_cap_mut(&mut Treasury): &mut TreasuryCap<VUSD>
	12: CopyLoc[2](Arg2: u64)
	13: MoveLoc[3](Arg3: &mut TxContext)
	14: Call coin::mint<VUSD>(&mut TreasuryCap<VUSD>, u64, &mut TxContext): Coin<VUSD>
	15: StLoc[6](loc2: Coin<VUSD>)
	16: MoveLoc[2](Arg2: u64)
	17: MoveLoc[5](loc1: u64)
	18: MoveLoc[0](Arg0: &mut Treasury)
	19: FreezeRef
	20: Call total_supply(&Treasury): u64
	21: PackGeneric[0](Mint<Ty0>)
	22: Call event::emit<Mint<Ty0>>(Mint<Ty0>)
	23: MoveLoc[6](loc2: Coin<VUSD>)
	24: StLoc[4](loc0: Coin<VUSD>)
	25: Branch(33)
B2:
	26: MoveLoc[0](Arg0: &mut Treasury)
	27: Pop
	28: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	29: Pop
	30: MoveLoc[3](Arg3: &mut TxContext)
	31: Call coin::zero<VUSD>(&mut TxContext): Coin<VUSD>
	32: StLoc[4](loc0: Coin<VUSD>)
B3:
	33: MoveLoc[4](loc0: Coin<VUSD>)
	34: Ret
}

public burn<Ty0: drop>(Arg0: &mut Treasury, Arg1: &ModuleRequest<Ty0>, Arg2: Coin<VUSD>) {
L3:	loc0: u64
L4:	loc1: u64
B0:
	0: ImmBorrowLoc[2](Arg2: Coin<VUSD>)
	1: Call coin::value<VUSD>(&Coin<VUSD>): u64
	2: StLoc[3](loc0: u64)
	3: CopyLoc[3](loc0: u64)
	4: LdU64(0)
	5: Gt
	6: BrFalse(26)
B1:
	7: CopyLoc[0](Arg0: &mut Treasury)
	8: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	9: Call borrow_supply_mut<Ty0>(&mut Treasury, &ModuleRequest<Ty0>): &mut LimitedSupply
	10: CopyLoc[3](loc0: u64)
	11: Call limited_supply::decrease(&mut LimitedSupply, u64): u64
	12: StLoc[4](loc1: u64)
	13: CopyLoc[0](Arg0: &mut Treasury)
	14: Call borrow_cap_mut(&mut Treasury): &mut TreasuryCap<VUSD>
	15: MoveLoc[2](Arg2: Coin<VUSD>)
	16: Call coin::burn<VUSD>(&mut TreasuryCap<VUSD>, Coin<VUSD>): u64
	17: Pop
	18: MoveLoc[3](loc0: u64)
	19: MoveLoc[4](loc1: u64)
	20: MoveLoc[0](Arg0: &mut Treasury)
	21: FreezeRef
	22: Call total_supply(&Treasury): u64
	23: PackGeneric[1](Burn<Ty0>)
	24: Call event::emit<Burn<Ty0>>(Burn<Ty0>)
	25: Branch(32)
B2:
	26: MoveLoc[0](Arg0: &mut Treasury)
	27: Pop
	28: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	29: Pop
	30: MoveLoc[2](Arg2: Coin<VUSD>)
	31: Call coin::destroy_zero<VUSD>(Coin<VUSD>)
B3:
	32: Ret
}

public collect<Ty0, Ty1: drop>(Arg0: &mut Treasury, Arg1: Ty1, Arg2: String, Arg3: Balance<Ty0>) {
L4:	loc0: u64
L5:	loc1: &mut VecMap<TypeName, Balance<Ty0>>
L6:	loc2: TypeName
L7:	loc3: TypeName
L8:	loc4: &mut UID
B0:
	0: ImmBorrowLoc[3](Arg3: Balance<Ty0>)
	1: Call balance::value<Ty0>(&Balance<Ty0>): u64
	2: StLoc[4](loc0: u64)
	3: CopyLoc[4](loc0: u64)
	4: LdU64(0)
	5: Gt
	6: BrFalse(49)
B1:
	7: MoveLoc[0](Arg0: &mut Treasury)
	8: MutBorrowField[3](Treasury.id: UID)
	9: StLoc[8](loc4: &mut UID)
	10: Call type_name::get<Ty0>(): TypeName
	11: StLoc[6](loc2: TypeName)
	12: CopyLoc[8](loc4: &mut UID)
	13: FreezeRef
	14: CopyLoc[6](loc2: TypeName)
	15: Call dynamic_field::exists_with_type<TypeName, VecMap<TypeName, Balance<Ty0>>>(&UID, TypeName): bool
	16: Not
	17: BrFalse(22)
B2:
	18: CopyLoc[8](loc4: &mut UID)
	19: CopyLoc[6](loc2: TypeName)
	20: Call vec_map::empty<TypeName, Balance<Ty0>>(): VecMap<TypeName, Balance<Ty0>>
	21: Call dynamic_field::add<TypeName, VecMap<TypeName, Balance<Ty0>>>(&mut UID, TypeName, VecMap<TypeName, Balance<Ty0>>)
B3:
	22: MoveLoc[8](loc4: &mut UID)
	23: MoveLoc[6](loc2: TypeName)
	24: Call dynamic_field::borrow_mut<TypeName, VecMap<TypeName, Balance<Ty0>>>(&mut UID, TypeName): &mut VecMap<TypeName, Balance<Ty0>>
	25: StLoc[5](loc1: &mut VecMap<TypeName, Balance<Ty0>>)
	26: Call type_name::get<Ty1>(): TypeName
	27: StLoc[7](loc3: TypeName)
	28: CopyLoc[5](loc1: &mut VecMap<TypeName, Balance<Ty0>>)
	29: FreezeRef
	30: ImmBorrowLoc[7](loc3: TypeName)
	31: Call vec_map::contains<TypeName, Balance<Ty0>>(&VecMap<TypeName, Balance<Ty0>>, &TypeName): bool
	32: Not
	33: BrFalse(38)
B4:
	34: CopyLoc[5](loc1: &mut VecMap<TypeName, Balance<Ty0>>)
	35: CopyLoc[7](loc3: TypeName)
	36: Call balance::zero<Ty0>(): Balance<Ty0>
	37: Call vec_map::insert<TypeName, Balance<Ty0>>(&mut VecMap<TypeName, Balance<Ty0>>, TypeName, Balance<Ty0>)
B5:
	38: MoveLoc[2](Arg2: String)
	39: MoveLoc[4](loc0: u64)
	40: PackGeneric[2](Collect<Ty0, Ty1>)
	41: Call event::emit<Collect<Ty0, Ty1>>(Collect<Ty0, Ty1>)
	42: MoveLoc[5](loc1: &mut VecMap<TypeName, Balance<Ty0>>)
	43: ImmBorrowLoc[7](loc3: TypeName)
	44: Call vec_map::get_mut<TypeName, Balance<Ty0>>(&mut VecMap<TypeName, Balance<Ty0>>, &TypeName): &mut Balance<Ty0>
	45: MoveLoc[3](Arg3: Balance<Ty0>)
	46: Call balance::join<Ty0>(&mut Balance<Ty0>, Balance<Ty0>): u64
	47: Pop
	48: Branch(53)
B6:
	49: MoveLoc[0](Arg0: &mut Treasury)
	50: Pop
	51: MoveLoc[3](Arg3: Balance<Ty0>)
	52: Call balance::destroy_zero<Ty0>(Balance<Ty0>)
B7:
	53: Ret
}

public claim<Ty0, Ty1: drop>(Arg0: &mut Treasury, Arg1: &AccountRequest, Arg2: &mut TxContext): Option<Coin<Ty0>> {
L3:	loc0: &mut VecMap<TypeName, Balance<Ty0>>
L4:	loc1: TypeName
L5:	loc2: TypeName
L6:	loc3: Coin<Ty0>
L7:	loc4: &mut UID
B0:
	0: CopyLoc[0](Arg0: &mut Treasury)
	1: FreezeRef
	2: Call beneficiary(&Treasury): address
	3: MoveLoc[1](Arg1: &AccountRequest)
	4: Call account::request_address(&AccountRequest): address
	5: Neq
	6: BrFalse(8)
B1:
	7: Call err_not_beneficiary()
B2:
	8: MoveLoc[0](Arg0: &mut Treasury)
	9: MutBorrowField[3](Treasury.id: UID)
	10: StLoc[7](loc4: &mut UID)
	11: Call type_name::get<Ty0>(): TypeName
	12: StLoc[4](loc1: TypeName)
	13: CopyLoc[7](loc4: &mut UID)
	14: FreezeRef
	15: CopyLoc[4](loc1: TypeName)
	16: Call dynamic_field::exists_with_type<TypeName, VecMap<TypeName, Balance<Ty0>>>(&UID, TypeName): bool
	17: Not
	18: BrFalse(25)
B3:
	19: MoveLoc[7](loc4: &mut UID)
	20: Pop
	21: MoveLoc[2](Arg2: &mut TxContext)
	22: Pop
	23: Call option::none<Coin<Ty0>>(): Option<Coin<Ty0>>
	24: Ret
B4:
	25: MoveLoc[7](loc4: &mut UID)
	26: MoveLoc[4](loc1: TypeName)
	27: Call dynamic_field::borrow_mut<TypeName, VecMap<TypeName, Balance<Ty0>>>(&mut UID, TypeName): &mut VecMap<TypeName, Balance<Ty0>>
	28: StLoc[3](loc0: &mut VecMap<TypeName, Balance<Ty0>>)
	29: Call type_name::get<Ty1>(): TypeName
	30: StLoc[5](loc2: TypeName)
	31: CopyLoc[3](loc0: &mut VecMap<TypeName, Balance<Ty0>>)
	32: FreezeRef
	33: ImmBorrowLoc[5](loc2: TypeName)
	34: Call vec_map::contains<TypeName, Balance<Ty0>>(&VecMap<TypeName, Balance<Ty0>>, &TypeName): bool
	35: Not
	36: BrFalse(43)
B5:
	37: MoveLoc[2](Arg2: &mut TxContext)
	38: Pop
	39: MoveLoc[3](loc0: &mut VecMap<TypeName, Balance<Ty0>>)
	40: Pop
	41: Call option::none<Coin<Ty0>>(): Option<Coin<Ty0>>
	42: Ret
B6:
	43: MoveLoc[3](loc0: &mut VecMap<TypeName, Balance<Ty0>>)
	44: ImmBorrowLoc[5](loc2: TypeName)
	45: Call vec_map::get_mut<TypeName, Balance<Ty0>>(&mut VecMap<TypeName, Balance<Ty0>>, &TypeName): &mut Balance<Ty0>
	46: Call balance::withdraw_all<Ty0>(&mut Balance<Ty0>): Balance<Ty0>
	47: MoveLoc[2](Arg2: &mut TxContext)
	48: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	49: StLoc[6](loc3: Coin<Ty0>)
	50: ImmBorrowLoc[6](loc3: Coin<Ty0>)
	51: Call coin::value<Ty0>(&Coin<Ty0>): u64
	52: LdU64(0)
	53: Gt
	54: BrFalse(59)
B7:
	55: ImmBorrowLoc[6](loc3: Coin<Ty0>)
	56: Call coin::value<Ty0>(&Coin<Ty0>): u64
	57: PackGeneric[3](Claim<Ty0, Ty1>)
	58: Call event::emit<Claim<Ty0, Ty1>>(Claim<Ty0, Ty1>)
B8:
	59: MoveLoc[6](loc3: Coin<Ty0>)
	60: Call option::some<Coin<Ty0>>(Coin<Ty0>): Option<Coin<Ty0>>
	61: Ret
}

public decimal(): u8 {
B0:
	0: LdU8(6)
	1: Ret
}

public total_supply(Arg0: &Treasury): u64 {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: Call borrow_cap(&Treasury): &TreasuryCap<VUSD>
	2: Call coin::total_supply<VUSD>(&TreasuryCap<VUSD>): u64
	3: Ret
}

public module_supply_map(Arg0: &Treasury): &VecMap<TypeName, LimitedSupply> {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: ImmBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	2: Ret
}

public module_versions_map(Arg0: &Treasury): &VecMap<TypeName, VecSet<u64>> {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: ImmBorrowField[2](Treasury.module_versions_map: VecMap<TypeName, VecSet<u64>>)
	2: Ret
}

public beneficiary(Arg0: &Treasury): address {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: ImmBorrowField[0](Treasury.beneficiary: address)
	2: ReadRef
	3: Ret
}

public claimable_map<Ty0>(Arg0: &Treasury): &VecMap<TypeName, Balance<Ty0>> {
L1:	loc0: TypeName
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[1](loc0: TypeName)
	2: CopyLoc[0](Arg0: &Treasury)
	3: ImmBorrowField[3](Treasury.id: UID)
	4: MoveLoc[1](loc0: TypeName)
	5: Call dynamic_field::exists_with_type<TypeName, VecMap<TypeName, Balance<Ty0>>>(&UID, TypeName): bool
	6: Not
	7: BrFalse(9)
B1:
	8: Call err_coin_type_not_found()
B2:
	9: MoveLoc[0](Arg0: &Treasury)
	10: ImmBorrowField[3](Treasury.id: UID)
	11: Call type_name::get<Ty0>(): TypeName
	12: Call dynamic_field::borrow<TypeName, VecMap<TypeName, Balance<Ty0>>>(&UID, TypeName): &VecMap<TypeName, Balance<Ty0>>
	13: Ret
}

public assert_valid_module<Ty0>(Arg0: &Treasury, Arg1: &ModuleRequest<Ty0>): TypeName {
L2:	loc0: u64
L3:	loc1: &VecSet<u64>
L4:	loc2: TypeName
L5:	loc3: &VecMap<TypeName, VecSet<u64>>
B0:
	0: CopyLoc[1](Arg1: &ModuleRequest<Ty0>)
	1: Call module_request::module_type<Ty0>(&ModuleRequest<Ty0>): TypeName
	2: StLoc[4](loc2: TypeName)
	3: CopyLoc[0](Arg0: &Treasury)
	4: Call module_versions_map(&Treasury): &VecMap<TypeName, VecSet<u64>>
	5: StLoc[5](loc3: &VecMap<TypeName, VecSet<u64>>)
	6: CopyLoc[5](loc3: &VecMap<TypeName, VecSet<u64>>)
	7: ImmBorrowLoc[4](loc2: TypeName)
	8: Call vec_map::contains<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): bool
	9: Not
	10: BrFalse(12)
B1:
	11: Call err_invalid_module()
B2:
	12: MoveLoc[5](loc3: &VecMap<TypeName, VecSet<u64>>)
	13: ImmBorrowLoc[4](loc2: TypeName)
	14: Call vec_map::get<TypeName, VecSet<u64>>(&VecMap<TypeName, VecSet<u64>>, &TypeName): &VecSet<u64>
	15: StLoc[3](loc1: &VecSet<u64>)
	16: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	17: Call module_request::version<Ty0>(&ModuleRequest<Ty0>): u64
	18: StLoc[2](loc0: u64)
	19: MoveLoc[3](loc1: &VecSet<u64>)
	20: ImmBorrowLoc[2](loc0: u64)
	21: Call vec_set::contains<u64>(&VecSet<u64>, &u64): bool
	22: Not
	23: BrFalse(25)
B3:
	24: Call err_invalid_module_version()
B4:
	25: MoveLoc[0](Arg0: &Treasury)
	26: ImmBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	27: ImmBorrowLoc[4](loc2: TypeName)
	28: Call vec_map::contains<TypeName, LimitedSupply>(&VecMap<TypeName, LimitedSupply>, &TypeName): bool
	29: Not
	30: BrFalse(32)
B5:
	31: Call err_invalid_supply_limit()
B6:
	32: MoveLoc[4](loc2: TypeName)
	33: Ret
}

cap_key(): CapKey {
B0:
	0: LdFalse
	1: Pack[5](CapKey)
	2: Ret
}

borrow_cap_mut(Arg0: &mut Treasury): &mut TreasuryCap<VUSD> {
B0:
	0: MoveLoc[0](Arg0: &mut Treasury)
	1: MutBorrowField[3](Treasury.id: UID)
	2: Call cap_key(): CapKey
	3: Call dynamic_object_field::borrow_mut<CapKey, TreasuryCap<VUSD>>(&mut UID, CapKey): &mut TreasuryCap<VUSD>
	4: Ret
}

borrow_cap(Arg0: &Treasury): &TreasuryCap<VUSD> {
B0:
	0: MoveLoc[0](Arg0: &Treasury)
	1: ImmBorrowField[3](Treasury.id: UID)
	2: Call cap_key(): CapKey
	3: Call dynamic_object_field::borrow<CapKey, TreasuryCap<VUSD>>(&UID, CapKey): &TreasuryCap<VUSD>
	4: Ret
}

borrow_supply_mut<Ty0>(Arg0: &mut Treasury, Arg1: &ModuleRequest<Ty0>): &mut LimitedSupply {
L2:	loc0: TypeName
B0:
	0: CopyLoc[0](Arg0: &mut Treasury)
	1: FreezeRef
	2: MoveLoc[1](Arg1: &ModuleRequest<Ty0>)
	3: Call assert_valid_module<Ty0>(&Treasury, &ModuleRequest<Ty0>): TypeName
	4: StLoc[2](loc0: TypeName)
	5: MoveLoc[0](Arg0: &mut Treasury)
	6: MutBorrowField[1](Treasury.module_supply_map: VecMap<TypeName, LimitedSupply>)
	7: ImmBorrowLoc[2](loc0: TypeName)
	8: Call vec_map::get_mut<TypeName, LimitedSupply>(&mut VecMap<TypeName, LimitedSupply>, &TypeName): &mut LimitedSupply
	9: Ret
}

Constants [
	0 => u64: 200
	1 => u64: 201
	2 => u64: 202
	3 => u64: 203
	4 => u64: 204
	5 => vector<u8>: "VUSD" // interpreted as UTF8 string
	6 => vector<u8>: "Virtue USD" // interpreted as UTF8 string
	7 => vector<u8>: "the stablecoin minted by https://virtue.money" // interpreted as UTF8 string
	8 => vector<u8>: "https://aqua-natural-grasshopper-705.mypinata.cloud/ipfs/bafkreidw4fvazp2uotvg3lxeat4c5l4aphdwtzhek73ry7hbca7wuaezmy" // interpreted as UTF8 string
]
}
