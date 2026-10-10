// Move bytecode v6
module ed5a8dac2ca41ae9bdc1c7f778b0949d3e26c18c51ed284c4cfa4030d0bb64c2.pyth_rule {
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 7792c84e1f8683dac893126712f7cf3ba5fcc82450839f0a481215f60199769f::i64;
use 7792c84e1f8683dac893126712f7cf3ba5fcc82450839f0a481215f60199769f::price;
use 7792c84e1f8683dac893126712f7cf3ba5fcc82450839f0a481215f60199769f::price_info;
use 7792c84e1f8683dac893126712f7cf3ba5fcc82450839f0a481215f60199769f::pyth;
use 7792c84e1f8683dac893126712f7cf3ba5fcc82450839f0a481215f60199769f::state;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::u64;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::collector;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::listing;

struct PythRule has drop {
	dummy_field: bool
}

struct Config has key {
	id: UID,
	identifier_map: VecMap<TypeName, vector<u8>>
}

err_unsupported_coin_type() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_invalid_price_info_object() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

init(Arg0: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_map::empty<TypeName, vector<u8>>(): VecMap<TypeName, vector<u8>>
	3: Pack[1](Config)
	4: Call transfer::share_object<Config>(Config)
	5: Ret
}

public feed<Ty0>(Arg0: &mut PriceCollector<Ty0>, Arg1: &Config, Arg2: &Clock, Arg3: &State, Arg4: &PriceInfoObject) {
L5:	loc0: vector<u8>
L6:	loc1: TypeName
L7:	loc2: u64
L8:	loc3: ID
L9:	loc4: I64
L10:	loc5: I64
L11:	loc6: Float
L12:	loc7: ID
L13:	loc8: u64
L14:	loc9: u64
L15:	loc10: Price
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[6](loc1: TypeName)
	2: CopyLoc[1](Arg1: &Config)
	3: ImmBorrowField[0](Config.identifier_map: VecMap<TypeName, vector<u8>>)
	4: ImmBorrowLoc[6](loc1: TypeName)
	5: Call vec_map::contains<TypeName, vector<u8>>(&VecMap<TypeName, vector<u8>>, &TypeName): bool
	6: Not
	7: BrFalse(9)
B1:
	8: Call err_unsupported_coin_type()
B2:
	9: MoveLoc[1](Arg1: &Config)
	10: ImmBorrowField[0](Config.identifier_map: VecMap<TypeName, vector<u8>>)
	11: ImmBorrowLoc[6](loc1: TypeName)
	12: Call vec_map::get<TypeName, vector<u8>>(&VecMap<TypeName, vector<u8>>, &TypeName): &vector<u8>
	13: ReadRef
	14: StLoc[5](loc0: vector<u8>)
	15: CopyLoc[4](Arg4: &PriceInfoObject)
	16: Call object::id<PriceInfoObject>(&PriceInfoObject): ID
	17: StLoc[12](loc7: ID)
	18: CopyLoc[3](Arg3: &State)
	19: MoveLoc[5](loc0: vector<u8>)
	20: Call state::get_price_info_object_id(&State, vector<u8>): ID
	21: StLoc[8](loc3: ID)
	22: MoveLoc[12](loc7: ID)
	23: MoveLoc[8](loc3: ID)
	24: Neq
	25: BrFalse(27)
B3:
	26: Call err_invalid_price_info_object()
B4:
	27: MoveLoc[3](Arg3: &State)
	28: MoveLoc[4](Arg4: &PriceInfoObject)
	29: MoveLoc[2](Arg2: &Clock)
	30: Call pyth::get_price(&State, &PriceInfoObject, &Clock): Price
	31: StLoc[15](loc10: Price)
	32: ImmBorrowLoc[15](loc10: Price)
	33: Call price::get_price(&Price): I64
	34: StLoc[10](loc5: I64)
	35: ImmBorrowLoc[15](loc10: Price)
	36: Call price::get_expo(&Price): I64
	37: StLoc[9](loc4: I64)
	38: ImmBorrowLoc[10](loc5: I64)
	39: Call i64::get_magnitude_if_positive(&I64): u64
	40: StLoc[14](loc9: u64)
	41: ImmBorrowLoc[9](loc4: I64)
	42: Call i64::get_magnitude_if_negative(&I64): u64
	43: StLoc[7](loc2: u64)
	44: LdU64(10)
	45: MoveLoc[7](loc2: u64)
	46: CastU8
	47: Call u64::pow(u64, u8): u64
	48: StLoc[13](loc8: u64)
	49: MoveLoc[14](loc9: u64)
	50: MoveLoc[13](loc8: u64)
	51: Call float::from_fraction(u64, u64): Float
	52: StLoc[11](loc6: Float)
	53: MoveLoc[0](Arg0: &mut PriceCollector<Ty0>)
	54: LdFalse
	55: Pack[0](PythRule)
	56: MoveLoc[11](loc6: Float)
	57: Call collector::collect<Ty0, PythRule>(&mut PriceCollector<Ty0>, PythRule, Float)
	58: Ret
}

public set_identifier<Ty0>(Arg0: &mut Config, Arg1: &ListingCap, Arg2: vector<u8>) {
L3:	loc0: TypeName
L4:	loc1: &mut VecMap<TypeName, vector<u8>>
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: MoveLoc[0](Arg0: &mut Config)
	3: MutBorrowField[0](Config.identifier_map: VecMap<TypeName, vector<u8>>)
	4: StLoc[4](loc1: &mut VecMap<TypeName, vector<u8>>)
	5: ImmBorrowLoc[2](Arg2: vector<u8>)
	6: Call vector::is_empty<u8>(&vector<u8>): bool
	7: BrFalse(14)
B1:
	8: MoveLoc[4](loc1: &mut VecMap<TypeName, vector<u8>>)
	9: ImmBorrowLoc[3](loc0: TypeName)
	10: Call vec_map::remove<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, &TypeName): TypeName * vector<u8>
	11: Pop
	12: Pop
	13: Branch(29)
B2:
	14: CopyLoc[4](loc1: &mut VecMap<TypeName, vector<u8>>)
	15: FreezeRef
	16: ImmBorrowLoc[3](loc0: TypeName)
	17: Call vec_map::contains<TypeName, vector<u8>>(&VecMap<TypeName, vector<u8>>, &TypeName): bool
	18: BrFalse(25)
B3:
	19: MoveLoc[2](Arg2: vector<u8>)
	20: MoveLoc[4](loc1: &mut VecMap<TypeName, vector<u8>>)
	21: ImmBorrowLoc[3](loc0: TypeName)
	22: Call vec_map::get_mut<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, &TypeName): &mut vector<u8>
	23: WriteRef
	24: Branch(29)
B4:
	25: MoveLoc[4](loc1: &mut VecMap<TypeName, vector<u8>>)
	26: MoveLoc[3](loc0: TypeName)
	27: MoveLoc[2](Arg2: vector<u8>)
	28: Call vec_map::insert<TypeName, vector<u8>>(&mut VecMap<TypeName, vector<u8>>, TypeName, vector<u8>)
B5:
	29: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
]
}
