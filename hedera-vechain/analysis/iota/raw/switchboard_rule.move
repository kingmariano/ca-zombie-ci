// Move bytecode v6
module 39fb7adf0abd75b31868e17706b8600cc943bc27422fb582f6e14282029cd5f0.switchboard_rule {
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::u256;
use 0000000000000000000000000000000000000000000000000000000000000001::u64;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::aggregator;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::decimal;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::collector;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::listing;

struct SwitchboardRule has drop {
	dummy_field: bool
}

struct Config has key {
	id: UID,
	aggregator_id_map: VecMap<TypeName, ID>,
	feed_hash_map: VecMap<TypeName, vector<u8>>,
	min_oracles_map: VecMap<TypeName, u64>,
	tolerance_ms_map: VecMap<TypeName, u64>
}

struct AggregatorIdUpdated has copy, drop {
	coin_type: TypeName,
	aggregator_id: Option<ID>,
	feed_hash: Option<vector<u8>>,
	min_oracles: Option<u64>
}

struct ToleranceUpdated has copy, drop {
	coin_type: TypeName,
	tolerance_ms: u64
}

err_unsupported_coin_type() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_invalid_aggregator() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

err_invalid_tolerance() {
B0:
	0: LdConst[2](u64: 2)
	1: Abort
}

err_invalid_feed_hash() {
B0:
	0: LdConst[3](u64: 3)
	1: Abort
}

err_invalid_min_oracles() {
B0:
	0: LdConst[4](u64: 4)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_map::empty<TypeName, ID>(): VecMap<TypeName, ID>
	3: Call vec_map::empty<TypeName, vector<u8>>(): VecMap<TypeName, vector<u8>>
	4: Call vec_map::empty<TypeName, u64>(): VecMap<TypeName, u64>
	5: Call vec_map::empty<TypeName, u64>(): VecMap<TypeName, u64>
	6: Pack[1](Config)
	7: Call transfer::share_object<Config>(Config)
	8: Ret
}

public feed<Ty0>(Arg0: &mut PriceCollector<Ty0>, Arg1: &Config, Arg2: &Clock, Arg3: &Aggregator) {
L4:	loc0: u64
L5:	loc1: TypeName
L6:	loc2: &CurrentResult
L7:	loc3: Option<u64>
L8:	loc4: Option<Float>
L9:	loc5: u64
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[5](loc1: TypeName)
	2: CopyLoc[1](Arg1: &Config)
	3: ImmBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	4: ImmBorrowLoc[5](loc1: TypeName)
	5: Call vec_map::contains<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): bool
	6: Not
	7: BrFalse(9)
B1:
	8: Call err_unsupported_coin_type()
B2:
	9: CopyLoc[3](Arg3: &Aggregator)
	10: Call object::id<Aggregator>(&Aggregator): ID
	11: CopyLoc[1](Arg1: &Config)
	12: ImmBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	13: ImmBorrowLoc[5](loc1: TypeName)
	14: Call vec_map::get<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): &ID
	15: ReadRef
	16: Neq
	17: BrFalse(19)
B3:
	18: Call err_invalid_aggregator()
B4:
	19: CopyLoc[1](Arg1: &Config)
	20: ImmBorrowLoc[5](loc1: TypeName)
	21: CopyLoc[3](Arg3: &Aggregator)
	22: Call integrity_holds(&Config, &TypeName, &Aggregator): bool
	23: Not
	24: BrFalse(34)
B5:
	25: MoveLoc[1](Arg1: &Config)
	26: Pop
	27: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	28: Pop
	29: MoveLoc[2](Arg2: &Clock)
	30: Pop
	31: MoveLoc[3](Arg3: &Aggregator)
	32: Pop
	33: Ret
B6:
	34: MoveLoc[3](Arg3: &Aggregator)
	35: Call aggregator::current_result(&Aggregator): &CurrentResult
	36: StLoc[6](loc2: &CurrentResult)
	37: MoveLoc[1](Arg1: &Config)
	38: ImmBorrowField[1](Config.tolerance_ms_map: VecMap<TypeName, u64>)
	39: ImmBorrowLoc[5](loc1: TypeName)
	40: Call vec_map::try_get<TypeName, u64>(&VecMap<TypeName, u64>, &TypeName): Option<u64>
	41: StLoc[7](loc3: Option<u64>)
	42: ImmBorrowLoc[7](loc3: Option<u64>)
	43: Call option::is_some<u64>(&Option<u64>): bool
	44: BrFalse(49)
B7:
	45: MoveLoc[7](loc3: Option<u64>)
	46: Call option::destroy_some<u64>(Option<u64>): u64
	47: StLoc[4](loc0: u64)
	48: Branch(53)
B8:
	49: MoveLoc[7](loc3: Option<u64>)
	50: Call option::destroy_none<u64>(Option<u64>)
	51: LdConst[5](u64: 60000)
	52: StLoc[4](loc0: u64)
B9:
	53: MoveLoc[4](loc0: u64)
	54: StLoc[9](loc5: u64)
	55: MoveLoc[2](Arg2: &Clock)
	56: Call clock::timestamp_ms(&Clock): u64
	57: CopyLoc[6](loc2: &CurrentResult)
	58: Call aggregator::min_timestamp_ms(&CurrentResult): u64
	59: MoveLoc[9](loc5: u64)
	60: Call is_fresh(u64, u64, u64): bool
	61: Not
	62: BrFalse(68)
B10:
	63: MoveLoc[6](loc2: &CurrentResult)
	64: Pop
	65: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	66: Pop
	67: Ret
B11:
	68: MoveLoc[6](loc2: &CurrentResult)
	69: Call aggregator::result(&CurrentResult): &Decimal
	70: Call to_float(&Decimal): Option<Float>
	71: StLoc[8](loc4: Option<Float>)
	72: ImmBorrowLoc[8](loc4: Option<Float>)
	73: Call option::is_none<Float>(&Option<Float>): bool
	74: BrFalse(78)
B12:
	75: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	76: Pop
	77: Ret
B13:
	78: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	79: LdFalse
	80: Pack[0](SwitchboardRule)
	81: MoveLoc[8](loc4: Option<Float>)
	82: Call option::destroy_some<Float>(Option<Float>): Float
	83: Call collector::collect<Ty0, SwitchboardRule>(&mut PriceCollector<Ty0>, SwitchboardRule, Float)
	84: Ret
}

public aggregator_id<Ty0>(Arg0: &Config): Option<ID> {
L1:	loc0: TypeName
L2:	loc1: &VecMap<TypeName, ID>
B0:
	0: MoveLoc[0](Arg0: &Config)
	1: ImmBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	2: StLoc[2](loc1: &VecMap<TypeName, ID>)
	3: Call type_name::get<Ty0>(): TypeName
	4: StLoc[1](loc0: TypeName)
	5: MoveLoc[2](loc1: &VecMap<TypeName, ID>)
	6: ImmBorrowLoc[1](loc0: TypeName)
	7: Call vec_map::try_get<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): Option<ID>
	8: Ret
}

public feed_hash<Ty0>(Arg0: &Config): Option<vector<u8>> {
L1:	loc0: TypeName
L2:	loc1: &VecMap<TypeName, vector<u8>>
B0:
	0: MoveLoc[0](Arg0: &Config)
	1: ImmBorrowField[2](Config.feed_hash_map: VecMap<TypeName, vector<u8>>)
	2: StLoc[2](loc1: &VecMap<TypeName, vector<u8>>)
	3: Call type_name::get<Ty0>(): TypeName
	4: StLoc[1](loc0: TypeName)
	5: MoveLoc[2](loc1: &VecMap<TypeName, vector<u8>>)
	6: ImmBorrowLoc[1](loc0: TypeName)
	7: Call vec_map::try_get<TypeName, vector<u8>>(&VecMap<TypeName, vector<u8>>, &TypeName): Option<vector<u8>>
	8: Ret
}

public min_oracles<Ty0>(Arg0: &Config): Option<u64> {
L1:	loc0: TypeName
L2:	loc1: &VecMap<TypeName, u64>
B0:
	0: MoveLoc[0](Arg0: &Config)
	1: ImmBorrowField[3](Config.min_oracles_map: VecMap<TypeName, u64>)
	2: StLoc[2](loc1: &VecMap<TypeName, u64>)
	3: Call type_name::get<Ty0>(): TypeName
	4: StLoc[1](loc0: TypeName)
	5: MoveLoc[2](loc1: &VecMap<TypeName, u64>)
	6: ImmBorrowLoc[1](loc0: TypeName)
	7: Call vec_map::try_get<TypeName, u64>(&VecMap<TypeName, u64>, &TypeName): Option<u64>
	8: Ret
}

public tolerance_ms<Ty0>(Arg0: &Config): u64 {
L1:	loc0: TypeName
L2:	loc1: &VecMap<TypeName, u64>
L3:	loc2: u64
L4:	loc3: Option<u64>
B0:
	0: MoveLoc[0](Arg0: &Config)
	1: ImmBorrowField[1](Config.tolerance_ms_map: VecMap<TypeName, u64>)
	2: StLoc[2](loc1: &VecMap<TypeName, u64>)
	3: Call type_name::get<Ty0>(): TypeName
	4: StLoc[1](loc0: TypeName)
	5: MoveLoc[2](loc1: &VecMap<TypeName, u64>)
	6: ImmBorrowLoc[1](loc0: TypeName)
	7: Call vec_map::try_get<TypeName, u64>(&VecMap<TypeName, u64>, &TypeName): Option<u64>
	8: StLoc[4](loc3: Option<u64>)
	9: ImmBorrowLoc[4](loc3: Option<u64>)
	10: Call option::is_some<u64>(&Option<u64>): bool
	11: BrFalse(16)
B1:
	12: MoveLoc[4](loc3: Option<u64>)
	13: Call option::destroy_some<u64>(Option<u64>): u64
	14: StLoc[3](loc2: u64)
	15: Branch(20)
B2:
	16: MoveLoc[4](loc3: Option<u64>)
	17: Call option::destroy_none<u64>(Option<u64>)
	18: LdConst[5](u64: 60000)
	19: StLoc[3](loc2: u64)
B3:
	20: MoveLoc[3](loc2: u64)
	21: Ret
}

public set_aggregator_id<Ty0>(Arg0: &mut Config, Arg1: &ListingCap, Arg2: ID, Arg3: vector<u8>, Arg4: u64) {
L5:	loc0: TypeName
B0:
	0: ImmBorrowLoc[3](Arg3: vector<u8>)
	1: VecLen(43)
	2: LdConst[6](u64: 32)
	3: Neq
	4: BrFalse(6)
B1:
	5: Call err_invalid_feed_hash()
B2:
	6: CopyLoc[4](Arg4: u64)
	7: LdU64(0)
	8: Eq
	9: BrFalse(11)
B3:
	10: Call err_invalid_min_oracles()
B4:
	11: Call type_name::get<Ty0>(): TypeName
	12: StLoc[5](loc0: TypeName)
	13: CopyLoc[0](Arg0: &mut Config)
	14: ImmBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	15: ImmBorrowLoc[5](loc0: TypeName)
	16: Call vec_map::contains<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): bool
	17: BrFalse(37)
B5:
	18: CopyLoc[2](Arg2: ID)
	19: CopyLoc[0](Arg0: &mut Config)
	20: MutBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	21: ImmBorrowLoc[5](loc0: TypeName)
	22: Call vec_map::get_mut<TypeName, ID>(&mut VecMap<TypeName, ID>, &TypeName): &mut ID
	23: WriteRef
	24: CopyLoc[3](Arg3: vector<u8>)
	25: CopyLoc[0](Arg0: &mut Config)
	26: MutBorrowField[2](Config.feed_hash_map: VecMap<TypeName, vector<u8>>)
	27: ImmBorrowLoc[5](loc0: TypeName)
	28: Call vec_map::get_mut<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, &TypeName): &mut vector<u8>
	29: WriteRef
	30: CopyLoc[4](Arg4: u64)
	31: MoveLoc[0](Arg0: &mut Config)
	32: MutBorrowField[3](Config.min_oracles_map: VecMap<TypeName, u64>)
	33: ImmBorrowLoc[5](loc0: TypeName)
	34: Call vec_map::get_mut<TypeName, u64>(&mut VecMap<TypeName, u64>, &TypeName): &mut u64
	35: WriteRef
	36: Branch(52)
B6:
	37: CopyLoc[0](Arg0: &mut Config)
	38: MutBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	39: CopyLoc[5](loc0: TypeName)
	40: CopyLoc[2](Arg2: ID)
	41: Call vec_map::insert<TypeName, ID>(&mut VecMap<TypeName, ID>, TypeName, ID)
	42: CopyLoc[0](Arg0: &mut Config)
	43: MutBorrowField[2](Config.feed_hash_map: VecMap<TypeName, vector<u8>>)
	44: CopyLoc[5](loc0: TypeName)
	45: CopyLoc[3](Arg3: vector<u8>)
	46: Call vec_map::insert<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, TypeName, vector<u8>)
	47: MoveLoc[0](Arg0: &mut Config)
	48: MutBorrowField[3](Config.min_oracles_map: VecMap<TypeName, u64>)
	49: CopyLoc[5](loc0: TypeName)
	50: CopyLoc[4](Arg4: u64)
	51: Call vec_map::insert<TypeName, u64>(&mut VecMap<TypeName, u64>, TypeName, u64)
B7:
	52: MoveLoc[5](loc0: TypeName)
	53: MoveLoc[2](Arg2: ID)
	54: Call option::some<ID>(ID): Option<ID>
	55: MoveLoc[3](Arg3: vector<u8>)
	56: Call option::some<vector<u8>>(vector<u8>): Option<vector<u8>>
	57: MoveLoc[4](Arg4: u64)
	58: Call option::some<u64>(u64): Option<u64>
	59: Pack[2](AggregatorIdUpdated)
	60: Call event::emit<AggregatorIdUpdated>(AggregatorIdUpdated)
	61: Ret
}

public remove_aggregator_id<Ty0>(Arg0: &mut Config, Arg1: &ListingCap) {
L2:	loc0: TypeName
L3:	loc1: &mut VecMap<TypeName, ID>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[2](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut Config)
	3: MutBorrowField[0](Config.aggregator_id_map: VecMap<TypeName, ID>)
	4: StLoc[3](loc1: &mut VecMap<TypeName, ID>)
	5: CopyLoc[3](loc1: &mut VecMap<TypeName, ID>)
	6: FreezeRef
	7: ImmBorrowLoc[2](loc0: TypeName)
	8: Call vec_map::contains<TypeName, ID>(&VecMap<TypeName, ID>, &TypeName): bool
	9: BrFalse(34)
B1:
	10: MoveLoc[3](loc1: &mut VecMap<TypeName, ID>)
	11: ImmBorrowLoc[2](loc0: TypeName)
	12: Call vec_map::remove<TypeName, ID>(&mut VecMap<TypeName, ID>, &TypeName): TypeName * ID
	13: Pop
	14: Pop
	15: CopyLoc[0](Arg0: &mut Config)
	16: MutBorrowField[2](Config.feed_hash_map: VecMap<TypeName, vector<u8>>)
	17: ImmBorrowLoc[2](loc0: TypeName)
	18: Call vec_map::remove<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, &TypeName): TypeName * vector<u8>
	19: Pop
	20: Pop
	21: MoveLoc[0](Arg0: &mut Config)
	22: MutBorrowField[3](Config.min_oracles_map: VecMap<TypeName, u64>)
	23: ImmBorrowLoc[2](loc0: TypeName)
	24: Call vec_map::remove<TypeName, u64>(&mut VecMap<TypeName, u64>, &TypeName): TypeName * u64
	25: Pop
	26: Pop
	27: MoveLoc[2](loc0: TypeName)
	28: Call option::none<ID>(): Option<ID>
	29: Call option::none<vector<u8>>(): Option<vector<u8>>
	30: Call option::none<u64>(): Option<u64>
	31: Pack[2](AggregatorIdUpdated)
	32: Call event::emit<AggregatorIdUpdated>(AggregatorIdUpdated)
	33: Branch(38)
B2:
	34: MoveLoc[3](loc1: &mut VecMap<TypeName, ID>)
	35: Pop
	36: MoveLoc[0](Arg0: &mut Config)
	37: Pop
B3:
	38: Ret
}

public set_tolerance_ms<Ty0>(Arg0: &mut Config, Arg1: &ListingCap, Arg2: u64) {
L3:	loc0: TypeName
L4:	loc1: &mut VecMap<TypeName, u64>
B0:
	0: CopyLoc[2](Arg2: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_invalid_tolerance()
B2:
	5: Call type_name::get<Ty0>(): TypeName
	6: StLoc[3](loc0: TypeName)
	7: MoveLoc[0](Arg0: &mut Config)
	8: MutBorrowField[1](Config.tolerance_ms_map: VecMap<TypeName, u64>)
	9: StLoc[4](loc1: &mut VecMap<TypeName, u64>)
	10: CopyLoc[4](loc1: &mut VecMap<TypeName, u64>)
	11: FreezeRef
	12: ImmBorrowLoc[3](loc0: TypeName)
	13: Call vec_map::contains<TypeName, u64>(&VecMap<TypeName, u64>, &TypeName): bool
	14: BrFalse(21)
B3:
	15: CopyLoc[2](Arg2: u64)
	16: MoveLoc[4](loc1: &mut VecMap<TypeName, u64>)
	17: ImmBorrowLoc[3](loc0: TypeName)
	18: Call vec_map::get_mut<TypeName, u64>(&mut VecMap<TypeName, u64>, &TypeName): &mut u64
	19: WriteRef
	20: Branch(25)
B4:
	21: MoveLoc[4](loc1: &mut VecMap<TypeName, u64>)
	22: CopyLoc[3](loc0: TypeName)
	23: CopyLoc[2](Arg2: u64)
	24: Call vec_map::insert<TypeName, u64>(&mut VecMap<TypeName, u64>, TypeName, u64)
B5:
	25: MoveLoc[3](loc0: TypeName)
	26: MoveLoc[2](Arg2: u64)
	27: Pack[3](ToleranceUpdated)
	28: Call event::emit<ToleranceUpdated>(ToleranceUpdated)
	29: Ret
}

integrity_holds(Arg0: &Config, Arg1: &TypeName, Arg2: &Aggregator): bool {
L3:	loc0: vector<u8>
L4:	loc1: u64
L5:	loc2: bool
L6:	loc3: u64
L7:	loc4: Option<vector<u8>>
L8:	loc5: Option<u64>
B0:
	0: CopyLoc[0](Arg0: &Config)
	1: ImmBorrowField[2](Config.feed_hash_map: VecMap<TypeName, vector<u8>>)
	2: CopyLoc[1](Arg1: &TypeName)
	3: Call vec_map::try_get<TypeName, vector<u8>>(&VecMap<TypeName, vector<u8>>, &TypeName): Option<vector<u8>>
	4: StLoc[7](loc4: Option<vector<u8>>)
	5: ImmBorrowLoc[7](loc4: Option<vector<u8>>)
	6: Call option::is_some<vector<u8>>(&Option<vector<u8>>): bool
	7: BrFalse(12)
B1:
	8: MoveLoc[7](loc4: Option<vector<u8>>)
	9: Call option::destroy_some<vector<u8>>(Option<vector<u8>>): vector<u8>
	10: StLoc[3](loc0: vector<u8>)
	11: Branch(16)
B2:
	12: MoveLoc[7](loc4: Option<vector<u8>>)
	13: Call option::destroy_none<vector<u8>>(Option<vector<u8>>)
	14: LdConst[8](vector<u8>: "" /..)
	15: StLoc[3](loc0: vector<u8>)
B3:
	16: MoveLoc[3](loc0: vector<u8>)
	17: CopyLoc[2](Arg2: &Aggregator)
	18: Call aggregator::feed_hash(&Aggregator): vector<u8>
	19: Neq
	20: BrFalse(29)
B4:
	21: MoveLoc[0](Arg0: &Config)
	22: Pop
	23: MoveLoc[1](Arg1: &TypeName)
	24: Pop
	25: MoveLoc[2](Arg2: &Aggregator)
	26: Pop
	27: LdFalse
	28: Ret
B5:
	29: MoveLoc[0](Arg0: &Config)
	30: ImmBorrowField[3](Config.min_oracles_map: VecMap<TypeName, u64>)
	31: MoveLoc[1](Arg1: &TypeName)
	32: Call vec_map::try_get<TypeName, u64>(&VecMap<TypeName, u64>, &TypeName): Option<u64>
	33: StLoc[8](loc5: Option<u64>)
	34: ImmBorrowLoc[8](loc5: Option<u64>)
	35: Call option::is_some<u64>(&Option<u64>): bool
	36: BrFalse(41)
B6:
	37: MoveLoc[8](loc5: Option<u64>)
	38: Call option::destroy_some<u64>(Option<u64>): u64
	39: StLoc[4](loc1: u64)
	40: Branch(45)
B7:
	41: MoveLoc[8](loc5: Option<u64>)
	42: Call option::destroy_none<u64>(Option<u64>)
	43: LdU64(0)
	44: StLoc[4](loc1: u64)
B8:
	45: MoveLoc[4](loc1: u64)
	46: StLoc[6](loc3: u64)
	47: CopyLoc[2](Arg2: &Aggregator)
	48: Call aggregator::min_sample_size(&Aggregator): u64
	49: CopyLoc[6](loc3: u64)
	50: Ge
	51: BrFalse(59)
B9:
	52: MoveLoc[2](Arg2: &Aggregator)
	53: Call aggregator::min_responses(&Aggregator): u32
	54: CastU64
	55: MoveLoc[6](loc3: u64)
	56: Ge
	57: StLoc[5](loc2: bool)
	58: Branch(63)
B10:
	59: MoveLoc[2](Arg2: &Aggregator)
	60: Pop
	61: LdFalse
	62: StLoc[5](loc2: bool)
B11:
	63: MoveLoc[5](loc2: bool)
	64: Ret
}

is_fresh(Arg0: u64, Arg1: u64, Arg2: u64): bool {
B0:
	0: MoveLoc[0](Arg0: u64)
	1: MoveLoc[1](Arg1: u64)
	2: Call u64::diff(u64, u64): u64
	3: MoveLoc[2](Arg2: u64)
	4: Le
	5: Ret
}

to_float(Arg0: &Decimal): Option<Float> {
L1:	loc0: u8
L2:	loc1: u256
L3:	loc2: u128
L4:	loc3: u128
B0:
	0: CopyLoc[0](Arg0: &Decimal)
	1: Call decimal::neg(&Decimal): bool
	2: BrFalse(7)
B1:
	3: MoveLoc[0](Arg0: &Decimal)
	4: Pop
	5: Call option::none<Float>(): Option<Float>
	6: Ret
B2:
	7: CopyLoc[0](Arg0: &Decimal)
	8: Call decimal::value(&Decimal): u128
	9: StLoc[3](loc2: u128)
	10: CopyLoc[3](loc2: u128)
	11: LdU128(0)
	12: Eq
	13: BrFalse(18)
B3:
	14: MoveLoc[0](Arg0: &Decimal)
	15: Pop
	16: Call option::none<Float>(): Option<Float>
	17: Ret
B4:
	18: MoveLoc[0](Arg0: &Decimal)
	19: Call decimal::dec(&Decimal): u8
	20: StLoc[1](loc0: u8)
	21: CopyLoc[1](loc0: u8)
	22: LdConst[7](u8: 38)
	23: Gt
	24: BrFalse(27)
B5:
	25: Call option::none<Float>(): Option<Float>
	26: Ret
B6:
	27: Call float::wad(): u128
	28: StLoc[4](loc3: u128)
	29: MoveLoc[3](loc2: u128)
	30: CastU256
	31: CopyLoc[4](loc3: u128)
	32: CastU256
	33: Mul
	34: LdU256(10)
	35: MoveLoc[1](loc0: u8)
	36: Call u256::pow(u256, u8): u256
	37: Div
	38: StLoc[2](loc1: u256)
	39: CopyLoc[2](loc1: u256)
	40: LdU256(0)
	41: Eq
	42: BrFalse(45)
B7:
	43: Call option::none<Float>(): Option<Float>
	44: Ret
B8:
	45: CopyLoc[2](loc1: u256)
	46: LdU256(18446744073709551615)
	47: MoveLoc[4](loc3: u128)
	48: CastU256
	49: Mul
	50: Gt
	51: BrFalse(54)
B9:
	52: Call option::none<Float>(): Option<Float>
	53: Ret
B10:
	54: MoveLoc[2](loc1: u256)
	55: CastU128
	56: Call float::from_scaled_val(u128): Float
	57: Call option::some<Float>(Float): Option<Float>
	58: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u64: 2
	3 => u64: 3
	4 => u64: 4
	5 => u64: 60000
	6 => u64: 32
	7 => u8: 38
	8 => vector<u8>: "" // interpreted as UTF8 string
]
}
