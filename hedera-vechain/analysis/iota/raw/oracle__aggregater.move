// Move bytecode v6
module 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf.aggregater {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::collector;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::listing;
use 7eebbee92f64ba2912bdbfba1864a362c463879fc5b3eacc735c1dcb255cc2cf::result;

struct NewAggregater has copy, drop {
	id: ID,
	coin_type: TypeName,
	weight_threshold: u64
}

struct WeightUpdated<phantom Ty0> has copy, drop {
	id: ID,
	rule_type: TypeName,
	weight: u8
}

struct ThresholdUpdated<phantom Ty0> has copy, drop {
	id: ID,
	weight_threshold: u64
}

struct PriceAggregated<phantom Ty0> has copy, drop {
	id: ID,
	sources: vector<TypeName>,
	prices: vector<u128>,
	weights: vector<u8>,
	current_threshold: u64,
	result: u128
}

struct PriceAggregater<phantom Ty0> has store, key {
	id: UID,
	weights: VecMap<TypeName, u8>,
	weight_threshold: u64
}

err_total_weight_not_enough() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_invalid_weight() {
B0:
	0: LdConst[1](u64: 1)
	1: Abort
}

err_invalid_threshold() {
B0:
	0: LdConst[2](u64: 2)
	1: Abort
}

public new<Ty0>(Arg0: &mut ListingCap, Arg1: u64, Arg2: &mut TxContext): PriceAggregater<Ty0> {
L3:	loc0: PriceAggregater<Ty0>
L4:	loc1: ID
L5:	loc2: TypeName
L6:	loc3: UID
B0:
	0: CopyLoc[1](Arg1: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_invalid_threshold()
B2:
	5: MoveLoc[2](Arg2: &mut TxContext)
	6: Call object::new(&mut TxContext): UID
	7: StLoc[6](loc3: UID)
	8: ImmBorrowLoc[6](loc3: UID)
	9: Call object::uid_to_inner(&UID): ID
	10: StLoc[4](loc1: ID)
	11: MoveLoc[6](loc3: UID)
	12: Call vec_map::empty<TypeName, u8>(): VecMap<TypeName, u8>
	13: CopyLoc[1](Arg1: u64)
	14: PackGeneric[0](PriceAggregater<Ty0>)
	15: StLoc[3](loc0: PriceAggregater<Ty0>)
	16: MoveLoc[0](Arg0: &mut ListingCap)
	17: CopyLoc[4](loc1: ID)
	18: Call listing::register<Ty0>(&mut ListingCap, ID): TypeName
	19: StLoc[5](loc2: TypeName)
	20: MoveLoc[4](loc1: ID)
	21: MoveLoc[5](loc2: TypeName)
	22: MoveLoc[1](Arg1: u64)
	23: Pack[0](NewAggregater)
	24: Call event::emit<NewAggregater>(NewAggregater)
	25: MoveLoc[3](loc0: PriceAggregater<Ty0>)
	26: Ret
}

entry create<Ty0>(Arg0: &mut ListingCap, Arg1: u64, Arg2: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &mut ListingCap)
	1: MoveLoc[1](Arg1: u64)
	2: MoveLoc[2](Arg2: &mut TxContext)
	3: Call new<Ty0>(&mut ListingCap, u64, &mut TxContext): PriceAggregater<Ty0>
	4: Call transfer::share_object<PriceAggregater<Ty0>>(PriceAggregater<Ty0>)
	5: Ret
}

public set_rule_weight<Ty0, Ty1>(Arg0: &mut PriceAggregater<Ty0>, Arg1: &ListingCap, Arg2: u8) {
L3:	loc0: TypeName
L4:	loc1: &mut VecMap<TypeName, u8>
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: StLoc[3](loc0: TypeName)
	2: CopyLoc[0](Arg0: &mut PriceAggregater<Ty0>)
	3: MutBorrowFieldGeneric[0](PriceAggregater.weights: VecMap<TypeName, u8>)
	4: StLoc[4](loc1: &mut VecMap<TypeName, u8>)
	5: CopyLoc[4](loc1: &mut VecMap<TypeName, u8>)
	6: FreezeRef
	7: ImmBorrowLoc[3](loc0: TypeName)
	8: Call vec_map::contains<TypeName, u8>(&VecMap<TypeName, u8>, &TypeName): bool
	9: BrFalse(26)
B1:
	10: CopyLoc[2](Arg2: u8)
	11: LdU8(0)
	12: Gt
	13: BrFalse(20)
B2:
	14: CopyLoc[2](Arg2: u8)
	15: MoveLoc[4](loc1: &mut VecMap<TypeName, u8>)
	16: ImmBorrowLoc[3](loc0: TypeName)
	17: Call vec_map::get_mut<TypeName, u8>(&mut VecMap<TypeName, u8>, &TypeName): &mut u8
	18: WriteRef
	19: Branch(38)
B3:
	20: MoveLoc[4](loc1: &mut VecMap<TypeName, u8>)
	21: ImmBorrowLoc[3](loc0: TypeName)
	22: Call vec_map::remove<TypeName, u8>(&mut VecMap<TypeName, u8>, &TypeName): TypeName * u8
	23: Pop
	24: Pop
	25: Branch(38)
B4:
	26: CopyLoc[2](Arg2: u8)
	27: LdU8(0)
	28: Gt
	29: BrFalse(35)
B5:
	30: MoveLoc[4](loc1: &mut VecMap<TypeName, u8>)
	31: CopyLoc[3](loc0: TypeName)
	32: CopyLoc[2](Arg2: u8)
	33: Call vec_map::insert<TypeName, u8>(&mut VecMap<TypeName, u8>, TypeName, u8)
	34: Branch(38)
B6:
	35: MoveLoc[4](loc1: &mut VecMap<TypeName, u8>)
	36: Pop
	37: Call err_invalid_weight()
B7:
	38: MoveLoc[0](Arg0: &mut PriceAggregater<Ty0>)
	39: FreezeRef
	40: Call object::id<PriceAggregater<Ty0>>(&PriceAggregater<Ty0>): ID
	41: MoveLoc[3](loc0: TypeName)
	42: MoveLoc[2](Arg2: u8)
	43: PackGeneric[1](WeightUpdated<Ty0>)
	44: Call event::emit<WeightUpdated<Ty0>>(WeightUpdated<Ty0>)
	45: Ret
}

public set_weight_threshold<Ty0>(Arg0: &mut PriceAggregater<Ty0>, Arg1: &ListingCap, Arg2: u64) {
B0:
	0: CopyLoc[2](Arg2: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_invalid_threshold()
B2:
	5: CopyLoc[2](Arg2: u64)
	6: CopyLoc[0](Arg0: &mut PriceAggregater<Ty0>)
	7: MutBorrowFieldGeneric[1](PriceAggregater.weight_threshold: u64)
	8: WriteRef
	9: MoveLoc[0](Arg0: &mut PriceAggregater<Ty0>)
	10: FreezeRef
	11: Call object::id<PriceAggregater<Ty0>>(&PriceAggregater<Ty0>): ID
	12: MoveLoc[2](Arg2: u64)
	13: PackGeneric[2](ThresholdUpdated<Ty0>)
	14: Call event::emit<ThresholdUpdated<Ty0>>(ThresholdUpdated<Ty0>)
	15: Ret
}

public aggregate<Ty0>(Arg0: &PriceAggregater<Ty0>, Arg1: PriceCollector<Ty0>): PriceResult<Ty0> {
L2:	loc0: u64
L3:	loc1: u64
L4:	loc2: u8
L5:	loc3: bool
L6:	loc4: u8
L7:	loc5: u64
L8:	loc6: Float
L9:	loc7: Float
L10:	loc8: TypeName
L11:	loc9: TypeName
L12:	loc10: u64
L13:	loc11: u64
L14:	loc12: Option<u8>
L15:	loc13: Option<u8>
L16:	loc14: Float
L17:	loc15: vector<u128>
L18:	loc16: TypeName
L19:	loc17: TypeName
L20:	loc18: vector<TypeName>
L21:	loc19: vector<TypeName>
L22:	loc20: u64
L23:	loc21: u64
L24:	loc22: u64
L25:	loc23: Float
L26:	loc24: u64
L27:	loc25: vector<TypeName>
L28:	loc26: vector<TypeName>
L29:	loc27: vector<TypeName>
L30:	loc28: vector<TypeName>
L31:	loc29: u8
L32:	loc30: u8
L33:	loc31: vector<u8>
B0:
	0: ImmBorrowLoc[1](Arg1: PriceCollector<Ty0>)
	1: Call collector::contents<Ty0>(&PriceCollector<Ty0>): &VecMap<TypeName, Float>
	2: Call vec_map::keys<TypeName, Float>(&VecMap<TypeName, Float>): vector<TypeName>
	3: StLoc[20](loc18: vector<TypeName>)
	4: CopyLoc[20](loc18: vector<TypeName>)
	5: StLoc[27](loc25: vector<TypeName>)
	6: LdU64(0)
	7: StLoc[7](loc5: u64)
	8: MoveLoc[27](loc25: vector<TypeName>)
	9: StLoc[30](loc28: vector<TypeName>)
	10: MutBorrowLoc[30](loc28: vector<TypeName>)
	11: Call vector::reverse<TypeName>(&mut vector<TypeName>)
	12: ImmBorrowLoc[30](loc28: vector<TypeName>)
	13: VecLen(19)
	14: StLoc[3](loc1: u64)
	15: LdU64(0)
	16: StLoc[12](loc10: u64)
	17: MoveLoc[3](loc1: u64)
	18: StLoc[22](loc20: u64)
B1:
	19: CopyLoc[12](loc10: u64)
	20: CopyLoc[22](loc20: u64)
	21: Lt
	22: BrFalse(60)
B2:
	23: CopyLoc[12](loc10: u64)
	24: Pop
	25: MutBorrowLoc[30](loc28: vector<TypeName>)
	26: VecPopBack(19)
	27: StLoc[10](loc8: TypeName)
	28: MoveLoc[7](loc5: u64)
	29: StLoc[24](loc22: u64)
	30: MoveLoc[10](loc8: TypeName)
	31: StLoc[18](loc16: TypeName)
	32: CopyLoc[0](Arg0: &PriceAggregater<Ty0>)
	33: Call weights<Ty0>(&PriceAggregater<Ty0>): &VecMap<TypeName, u8>
	34: ImmBorrowLoc[18](loc16: TypeName)
	35: Call vec_map::try_get<TypeName, u8>(&VecMap<TypeName, u8>, &TypeName): Option<u8>
	36: StLoc[14](loc12: Option<u8>)
	37: ImmBorrowLoc[14](loc12: Option<u8>)
	38: Call option::is_some<u8>(&Option<u8>): bool
	39: BrFalse(44)
B3:
	40: MoveLoc[14](loc12: Option<u8>)
	41: Call option::destroy_some<u8>(Option<u8>): u8
	42: StLoc[4](loc2: u8)
	43: Branch(48)
B4:
	44: MoveLoc[14](loc12: Option<u8>)
	45: Call option::destroy_none<u8>(Option<u8>)
	46: LdU8(0)
	47: StLoc[4](loc2: u8)
B5:
	48: MoveLoc[4](loc2: u8)
	49: StLoc[31](loc29: u8)
	50: MoveLoc[24](loc22: u64)
	51: MoveLoc[31](loc29: u8)
	52: CastU64
	53: Add
	54: StLoc[7](loc5: u64)
	55: MoveLoc[12](loc10: u64)
	56: LdU64(1)
	57: Add
	58: StLoc[12](loc10: u64)
	59: Branch(19)
B6:
	60: MoveLoc[30](loc28: vector<TypeName>)
	61: VecUnpack(19, 0)
	62: MoveLoc[7](loc5: u64)
	63: StLoc[26](loc24: u64)
	64: CopyLoc[26](loc24: u64)
	65: LdU64(0)
	66: Eq
	67: BrFalse(72)
B7:
	68: Branch(69)
B8:
	69: LdTrue
	70: StLoc[5](loc3: bool)
	71: Branch(77)
B9:
	72: CopyLoc[26](loc24: u64)
	73: CopyLoc[0](Arg0: &PriceAggregater<Ty0>)
	74: Call weight_threshold<Ty0>(&PriceAggregater<Ty0>): u64
	75: Lt
	76: StLoc[5](loc3: bool)
B10:
	77: MoveLoc[5](loc3: bool)
	78: BrFalse(80)
B11:
	79: Call err_total_weight_not_enough()
B12:
	80: VecPack(19, 0)
	81: StLoc[21](loc19: vector<TypeName>)
	82: LdConst[3](vector<u128>: 00)
	83: StLoc[17](loc15: vector<u128>)
	84: LdConst[4](vector<u8>: "" /..)
	85: StLoc[33](loc31: vector<u8>)
	86: MoveLoc[20](loc18: vector<TypeName>)
	87: StLoc[28](loc26: vector<TypeName>)
	88: LdU64(0)
	89: Call float::from(u64): Float
	90: StLoc[8](loc6: Float)
	91: MoveLoc[28](loc26: vector<TypeName>)
	92: StLoc[29](loc27: vector<TypeName>)
	93: MutBorrowLoc[29](loc27: vector<TypeName>)
	94: Call vector::reverse<TypeName>(&mut vector<TypeName>)
	95: ImmBorrowLoc[29](loc27: vector<TypeName>)
	96: VecLen(19)
	97: StLoc[2](loc0: u64)
	98: LdU64(0)
	99: StLoc[13](loc11: u64)
	100: MoveLoc[2](loc0: u64)
	101: StLoc[23](loc21: u64)
B13:
	102: CopyLoc[13](loc11: u64)
	103: CopyLoc[23](loc21: u64)
	104: Lt
	105: BrFalse(165)
B14:
	106: CopyLoc[13](loc11: u64)
	107: Pop
	108: MutBorrowLoc[29](loc27: vector<TypeName>)
	109: VecPopBack(19)
	110: StLoc[11](loc9: TypeName)
	111: MoveLoc[8](loc6: Float)
	112: StLoc[25](loc23: Float)
	113: MoveLoc[11](loc9: TypeName)
	114: StLoc[19](loc17: TypeName)
	115: ImmBorrowLoc[1](Arg1: PriceCollector<Ty0>)
	116: Call collector::contents<Ty0>(&PriceCollector<Ty0>): &VecMap<TypeName, Float>
	117: ImmBorrowLoc[19](loc17: TypeName)
	118: Call vec_map::get<TypeName, Float>(&VecMap<TypeName, Float>, &TypeName): &Float
	119: ReadRef
	120: StLoc[16](loc14: Float)
	121: CopyLoc[0](Arg0: &PriceAggregater<Ty0>)
	122: Call weights<Ty0>(&PriceAggregater<Ty0>): &VecMap<TypeName, u8>
	123: ImmBorrowLoc[19](loc17: TypeName)
	124: Call vec_map::try_get<TypeName, u8>(&VecMap<TypeName, u8>, &TypeName): Option<u8>
	125: StLoc[15](loc13: Option<u8>)
	126: ImmBorrowLoc[15](loc13: Option<u8>)
	127: Call option::is_some<u8>(&Option<u8>): bool
	128: BrFalse(133)
B15:
	129: MoveLoc[15](loc13: Option<u8>)
	130: Call option::destroy_some<u8>(Option<u8>): u8
	131: StLoc[6](loc4: u8)
	132: Branch(137)
B16:
	133: MoveLoc[15](loc13: Option<u8>)
	134: Call option::destroy_none<u8>(Option<u8>)
	135: LdU8(0)
	136: StLoc[6](loc4: u8)
B17:
	137: MoveLoc[6](loc4: u8)
	138: StLoc[32](loc30: u8)
	139: CopyLoc[32](loc30: u8)
	140: LdU8(0)
	141: Gt
	142: BrFalse(153)
B18:
	143: MutBorrowLoc[21](loc19: vector<TypeName>)
	144: MoveLoc[19](loc17: TypeName)
	145: VecPushBack(19)
	146: MutBorrowLoc[17](loc15: vector<u128>)
	147: CopyLoc[16](loc14: Float)
	148: Call float::to_scaled_val(Float): u128
	149: VecPushBack(45)
	150: MutBorrowLoc[33](loc31: vector<u8>)
	151: CopyLoc[32](loc30: u8)
	152: VecPushBack(40)
B19:
	153: MoveLoc[25](loc23: Float)
	154: MoveLoc[16](loc14: Float)
	155: MoveLoc[32](loc30: u8)
	156: CastU64
	157: Call float::mul_u64(Float, u64): Float
	158: Call float::add(Float, Float): Float
	159: StLoc[8](loc6: Float)
	160: MoveLoc[13](loc11: u64)
	161: LdU64(1)
	162: Add
	163: StLoc[13](loc11: u64)
	164: Branch(102)
B20:
	165: MoveLoc[29](loc27: vector<TypeName>)
	166: VecUnpack(19, 0)
	167: MoveLoc[8](loc6: Float)
	168: MoveLoc[26](loc24: u64)
	169: Call float::div_u64(Float, u64): Float
	170: StLoc[9](loc7: Float)
	171: CopyLoc[0](Arg0: &PriceAggregater<Ty0>)
	172: Call object::id<PriceAggregater<Ty0>>(&PriceAggregater<Ty0>): ID
	173: MoveLoc[21](loc19: vector<TypeName>)
	174: MoveLoc[17](loc15: vector<u128>)
	175: MoveLoc[33](loc31: vector<u8>)
	176: MoveLoc[0](Arg0: &PriceAggregater<Ty0>)
	177: ImmBorrowFieldGeneric[1](PriceAggregater.weight_threshold: u64)
	178: ReadRef
	179: CopyLoc[9](loc7: Float)
	180: Call float::to_scaled_val(Float): u128
	181: PackGeneric[3](PriceAggregated<Ty0>)
	182: Call event::emit<PriceAggregated<Ty0>>(PriceAggregated<Ty0>)
	183: MoveLoc[9](loc7: Float)
	184: Call result::new<Ty0>(Float): PriceResult<Ty0>
	185: Ret
}

public weights<Ty0>(Arg0: &PriceAggregater<Ty0>): &VecMap<TypeName, u8> {
B0:
	0: MoveLoc[0](Arg0: &PriceAggregater<Ty0>)
	1: ImmBorrowFieldGeneric[0](PriceAggregater.weights: VecMap<TypeName, u8>)
	2: Ret
}

public weight_threshold<Ty0>(Arg0: &PriceAggregater<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &PriceAggregater<Ty0>)
	1: ImmBorrowFieldGeneric[1](PriceAggregater.weight_threshold: u64)
	2: ReadRef
	3: Ret
}

Constants [
	0 => u64: 0
	1 => u64: 1
	2 => u64: 2
	3 => vector<u128>: 00
	4 => vector<u8>: "" // interpreted as UTF8 string
]
}
