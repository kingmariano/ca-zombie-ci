// Move bytecode v6
module 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1.aggregator {
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_set;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::u64;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::decimal;

struct CurrentResult has copy, drop, store {
	result: Decimal,
	timestamp_ms: u64,
	min_timestamp_ms: u64,
	max_timestamp_ms: u64,
	min_result: Decimal,
	max_result: Decimal,
	stdev: Decimal,
	range: Decimal,
	mean: Decimal
}

struct Update has copy, drop, store {
	result: Decimal,
	timestamp_ms: u64,
	oracle: ID
}

struct UpdateState has store {
	results: vector<Update>,
	curr_idx: u64
}

struct Aggregator has key {
	id: UID,
	queue: ID,
	created_at_ms: u64,
	name: String,
	authority: address,
	feed_hash: vector<u8>,
	min_sample_size: u64,
	max_staleness_seconds: u64,
	max_variance: u64,
	min_responses: u32,
	current_result: CurrentResult,
	update_state: UpdateState,
	version: u8
}

public has_authority(Arg0: &Aggregator, Arg1: &mut TxContext): bool {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[0](Aggregator.authority: address)
	2: ReadRef
	3: MoveLoc[1](Arg1: &mut TxContext)
	4: FreezeRef
	5: Call tx_context::sender(&TxContext): address
	6: Eq
	7: Ret
}

public id(Arg0: &Aggregator): ID {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[1](Aggregator.id: UID)
	2: Call object::uid_to_inner(&UID): ID
	3: Ret
}

public name(Arg0: &Aggregator): String {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[2](Aggregator.name: String)
	2: ReadRef
	3: Ret
}

public authority(Arg0: &Aggregator): address {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[0](Aggregator.authority: address)
	2: ReadRef
	3: Ret
}

public queue(Arg0: &Aggregator): ID {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[3](Aggregator.queue: ID)
	2: ReadRef
	3: Ret
}

public created_at_ms(Arg0: &Aggregator): u64 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[4](Aggregator.created_at_ms: u64)
	2: ReadRef
	3: Ret
}

public feed_hash(Arg0: &Aggregator): vector<u8> {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[5](Aggregator.feed_hash: vector<u8>)
	2: ReadRef
	3: Ret
}

public min_sample_size(Arg0: &Aggregator): u64 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[6](Aggregator.min_sample_size: u64)
	2: ReadRef
	3: Ret
}

public max_staleness_seconds(Arg0: &Aggregator): u64 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[7](Aggregator.max_staleness_seconds: u64)
	2: ReadRef
	3: Ret
}

public min_responses(Arg0: &Aggregator): u32 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[8](Aggregator.min_responses: u32)
	2: ReadRef
	3: Ret
}

public max_variance(Arg0: &Aggregator): u64 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[9](Aggregator.max_variance: u64)
	2: ReadRef
	3: Ret
}

public current_result(Arg0: &Aggregator): &CurrentResult {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[10](Aggregator.current_result: CurrentResult)
	2: Ret
}

public version(Arg0: &Aggregator): u8 {
B0:
	0: MoveLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[11](Aggregator.version: u8)
	2: ReadRef
	3: Ret
}

public result(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[12](CurrentResult.result: Decimal)
	2: Ret
}

public min_timestamp_ms(Arg0: &CurrentResult): u64 {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[13](CurrentResult.min_timestamp_ms: u64)
	2: ReadRef
	3: Ret
}

public max_timestamp_ms(Arg0: &CurrentResult): u64 {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[14](CurrentResult.max_timestamp_ms: u64)
	2: ReadRef
	3: Ret
}

public min_result(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[15](CurrentResult.min_result: Decimal)
	2: Ret
}

public max_result(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[16](CurrentResult.max_result: Decimal)
	2: Ret
}

public stdev(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[17](CurrentResult.stdev: Decimal)
	2: Ret
}

public range(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[18](CurrentResult.range: Decimal)
	2: Ret
}

public mean(Arg0: &CurrentResult): &Decimal {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[19](CurrentResult.mean: Decimal)
	2: Ret
}

public timestamp_ms(Arg0: &CurrentResult): u64 {
B0:
	0: MoveLoc[0](Arg0: &CurrentResult)
	1: ImmBorrowField[20](CurrentResult.timestamp_ms: u64)
	2: ReadRef
	3: Ret
}

public(friend) new(Arg0: ID, Arg1: String, Arg2: address, Arg3: vector<u8>, Arg4: u64, Arg5: u64, Arg6: u64, Arg7: u32, Arg8: u64, Arg9: &mut TxContext): ID {
L10:	loc0: UID
L11:	loc1: u64
L12:	loc2: Decimal
L13:	loc3: Decimal
L14:	loc4: Decimal
L15:	loc5: Decimal
L16:	loc6: Decimal
L17:	loc7: Decimal
L18:	loc8: ID
L19:	loc9: CurrentResult
L20:	loc10: UpdateState
L21:	loc11: String
L22:	loc12: address
L23:	loc13: vector<u8>
L24:	loc14: u64
L25:	loc15: u64
L26:	loc16: u64
L27:	loc17: u32
L28:	loc18: ID
L29:	loc19: UID
B0:
	0: MoveLoc[9](Arg9: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: StLoc[29](loc19: UID)
	3: ImmBorrowLoc[29](loc19: UID)
	4: Call object::uid_as_inner(&UID): &ID
	5: ReadRef
	6: StLoc[28](loc18: ID)
	7: MoveLoc[29](loc19: UID)
	8: StLoc[10](loc0: UID)
	9: MoveLoc[0](Arg0: ID)
	10: StLoc[18](loc8: ID)
	11: MoveLoc[1](Arg1: String)
	12: StLoc[21](loc11: String)
	13: MoveLoc[2](Arg2: address)
	14: StLoc[22](loc12: address)
	15: MoveLoc[3](Arg3: vector<u8>)
	16: StLoc[23](loc13: vector<u8>)
	17: MoveLoc[4](Arg4: u64)
	18: StLoc[24](loc14: u64)
	19: MoveLoc[5](Arg5: u64)
	20: StLoc[25](loc15: u64)
	21: MoveLoc[6](Arg6: u64)
	22: StLoc[26](loc16: u64)
	23: MoveLoc[7](Arg7: u32)
	24: StLoc[27](loc17: u32)
	25: MoveLoc[8](Arg8: u64)
	26: StLoc[11](loc1: u64)
	27: Call decimal::zero(): Decimal
	28: StLoc[12](loc2: Decimal)
	29: Call decimal::zero(): Decimal
	30: StLoc[13](loc3: Decimal)
	31: Call decimal::zero(): Decimal
	32: StLoc[14](loc4: Decimal)
	33: Call decimal::zero(): Decimal
	34: StLoc[15](loc5: Decimal)
	35: Call decimal::zero(): Decimal
	36: StLoc[16](loc6: Decimal)
	37: Call decimal::zero(): Decimal
	38: StLoc[17](loc7: Decimal)
	39: MoveLoc[12](loc2: Decimal)
	40: LdU64(0)
	41: LdU64(0)
	42: LdU64(0)
	43: MoveLoc[13](loc3: Decimal)
	44: MoveLoc[14](loc4: Decimal)
	45: MoveLoc[15](loc5: Decimal)
	46: MoveLoc[16](loc6: Decimal)
	47: MoveLoc[17](loc7: Decimal)
	48: Pack[0](CurrentResult)
	49: StLoc[19](loc9: CurrentResult)
	50: VecPack(38, 0)
	51: LdU64(0)
	52: Pack[2](UpdateState)
	53: StLoc[20](loc10: UpdateState)
	54: MoveLoc[10](loc0: UID)
	55: MoveLoc[18](loc8: ID)
	56: MoveLoc[11](loc1: u64)
	57: MoveLoc[21](loc11: String)
	58: MoveLoc[22](loc12: address)
	59: MoveLoc[23](loc13: vector<u8>)
	60: MoveLoc[24](loc14: u64)
	61: MoveLoc[25](loc15: u64)
	62: MoveLoc[26](loc16: u64)
	63: MoveLoc[27](loc17: u32)
	64: MoveLoc[19](loc9: CurrentResult)
	65: MoveLoc[20](loc10: UpdateState)
	66: LdConst[1](u8: 1)
	67: Pack[3](Aggregator)
	68: Call transfer::share_object<Aggregator>(Aggregator)
	69: MoveLoc[28](loc18: ID)
	70: Ret
}

public(friend) set_authority(Arg0: &mut Aggregator, Arg1: address) {
B0:
	0: MoveLoc[1](Arg1: address)
	1: MoveLoc[0](Arg0: &mut Aggregator)
	2: MutBorrowField[0](Aggregator.authority: address)
	3: WriteRef
	4: Ret
}

public(friend) set_configs(Arg0: &mut Aggregator, Arg1: vector<u8>, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u32) {
B0:
	0: MoveLoc[1](Arg1: vector<u8>)
	1: CopyLoc[0](Arg0: &mut Aggregator)
	2: MutBorrowField[5](Aggregator.feed_hash: vector<u8>)
	3: WriteRef
	4: MoveLoc[2](Arg2: u64)
	5: CopyLoc[0](Arg0: &mut Aggregator)
	6: MutBorrowField[6](Aggregator.min_sample_size: u64)
	7: WriteRef
	8: MoveLoc[3](Arg3: u64)
	9: CopyLoc[0](Arg0: &mut Aggregator)
	10: MutBorrowField[7](Aggregator.max_staleness_seconds: u64)
	11: WriteRef
	12: MoveLoc[4](Arg4: u64)
	13: CopyLoc[0](Arg0: &mut Aggregator)
	14: MutBorrowField[9](Aggregator.max_variance: u64)
	15: WriteRef
	16: MoveLoc[5](Arg5: u32)
	17: MoveLoc[0](Arg0: &mut Aggregator)
	18: MutBorrowField[8](Aggregator.min_responses: u32)
	19: WriteRef
	20: Ret
}

public(friend) add_result(Arg0: &mut Aggregator, Arg1: Decimal, Arg2: u64, Arg3: ID, Arg4: &Clock) {
L5:	loc0: Option<CurrentResult>
L6:	loc1: u64
B0:
	0: MoveLoc[4](Arg4: &Clock)
	1: Call clock::timestamp_ms(&Clock): u64
	2: StLoc[6](loc1: u64)
	3: CopyLoc[0](Arg0: &mut Aggregator)
	4: MutBorrowField[21](Aggregator.update_state: UpdateState)
	5: MoveLoc[1](Arg1: Decimal)
	6: MoveLoc[3](Arg3: ID)
	7: MoveLoc[2](Arg2: u64)
	8: Call set_update(&mut UpdateState, Decimal, ID, u64)
	9: CopyLoc[0](Arg0: &mut Aggregator)
	10: FreezeRef
	11: MoveLoc[6](loc1: u64)
	12: Call compute_current_result(&Aggregator, u64): Option<CurrentResult>
	13: StLoc[5](loc0: Option<CurrentResult>)
	14: ImmBorrowLoc[5](loc0: Option<CurrentResult>)
	15: Call option::is_some<CurrentResult>(&Option<CurrentResult>): bool
	16: BrFalse(23)
B1:
	17: MutBorrowLoc[5](loc0: Option<CurrentResult>)
	18: Call option::extract<CurrentResult>(&mut Option<CurrentResult>): CurrentResult
	19: MoveLoc[0](Arg0: &mut Aggregator)
	20: MutBorrowField[10](Aggregator.current_result: CurrentResult)
	21: WriteRef
	22: Branch(25)
B2:
	23: MoveLoc[0](Arg0: &mut Aggregator)
	24: Pop
B3:
	25: Ret
}

public(friend) delete(Arg0: Aggregator) {
L1:	loc0: UID
L2:	loc1: UpdateState
B0:
	0: MoveLoc[0](Arg0: Aggregator)
	1: Unpack[3](Aggregator)
	2: Pop
	3: StLoc[2](loc1: UpdateState)
	4: Pop
	5: Pop
	6: Pop
	7: Pop
	8: Pop
	9: Pop
	10: Pop
	11: Pop
	12: Pop
	13: Pop
	14: StLoc[1](loc0: UID)
	15: MoveLoc[2](loc1: UpdateState)
	16: Unpack[2](UpdateState)
	17: Pop
	18: Pop
	19: MoveLoc[1](loc0: UID)
	20: Call object::delete(UID)
	21: Ret
}

set_update(Arg0: &mut UpdateState, Arg1: Decimal, Arg2: ID, Arg3: u64) {
L4:	loc0: u64
L5:	loc1: &mut Update
L6:	loc2: u64
L7:	loc3: &Update
L8:	loc4: &mut vector<Update>
B0:
	0: CopyLoc[0](Arg0: &mut UpdateState)
	1: MutBorrowField[22](UpdateState.results: vector<Update>)
	2: StLoc[8](loc4: &mut vector<Update>)
	3: CopyLoc[0](Arg0: &mut UpdateState)
	4: ImmBorrowField[23](UpdateState.curr_idx: u64)
	5: ReadRef
	6: StLoc[6](loc2: u64)
	7: CopyLoc[6](loc2: u64)
	8: LdU64(1)
	9: Add
	10: LdConst[0](u64: 16)
	11: Mod
	12: StLoc[4](loc0: u64)
	13: CopyLoc[8](loc4: &mut vector<Update>)
	14: FreezeRef
	15: VecLen(38)
	16: LdU64(0)
	17: Eq
	18: BrFalse(28)
B1:
	19: MoveLoc[0](Arg0: &mut UpdateState)
	20: Pop
	21: MoveLoc[8](loc4: &mut vector<Update>)
	22: MoveLoc[1](Arg1: Decimal)
	23: MoveLoc[3](Arg3: u64)
	24: MoveLoc[2](Arg2: ID)
	25: Pack[1](Update)
	26: VecPushBack(38)
	27: Ret
B2:
	28: CopyLoc[8](loc4: &mut vector<Update>)
	29: FreezeRef
	30: VecLen(38)
	31: LdU64(0)
	32: Gt
	33: BrFalse(50)
B3:
	34: CopyLoc[8](loc4: &mut vector<Update>)
	35: FreezeRef
	36: MoveLoc[6](loc2: u64)
	37: VecImmBorrow(38)
	38: StLoc[7](loc3: &Update)
	39: CopyLoc[3](Arg3: u64)
	40: MoveLoc[7](loc3: &Update)
	41: ImmBorrowField[24](Update.timestamp_ms: u64)
	42: ReadRef
	43: Lt
	44: BrFalse(50)
B4:
	45: MoveLoc[0](Arg0: &mut UpdateState)
	46: Pop
	47: MoveLoc[8](loc4: &mut vector<Update>)
	48: Pop
	49: Ret
B5:
	50: CopyLoc[8](loc4: &mut vector<Update>)
	51: FreezeRef
	52: VecLen(38)
	53: LdConst[0](u64: 16)
	54: Lt
	55: BrFalse(63)
B6:
	56: MoveLoc[8](loc4: &mut vector<Update>)
	57: MoveLoc[1](Arg1: Decimal)
	58: MoveLoc[3](Arg3: u64)
	59: MoveLoc[2](Arg2: ID)
	60: Pack[1](Update)
	61: VecPushBack(38)
	62: Branch(79)
B7:
	63: MoveLoc[8](loc4: &mut vector<Update>)
	64: CopyLoc[4](loc0: u64)
	65: VecMutBorrow(38)
	66: StLoc[5](loc1: &mut Update)
	67: MoveLoc[1](Arg1: Decimal)
	68: CopyLoc[5](loc1: &mut Update)
	69: MutBorrowField[25](Update.result: Decimal)
	70: WriteRef
	71: MoveLoc[3](Arg3: u64)
	72: CopyLoc[5](loc1: &mut Update)
	73: MutBorrowField[24](Update.timestamp_ms: u64)
	74: WriteRef
	75: MoveLoc[2](Arg2: ID)
	76: MoveLoc[5](loc1: &mut Update)
	77: MutBorrowField[26](Update.oracle: ID)
	78: WriteRef
B8:
	79: MoveLoc[4](loc0: u64)
	80: MoveLoc[0](Arg0: &mut UpdateState)
	81: MutBorrowField[23](UpdateState.curr_idx: u64)
	82: WriteRef
	83: Ret
}

compute_current_result(Arg0: &Aggregator, Arg1: u64): Option<CurrentResult> {
L2:	loc0: u64
L3:	loc1: u64
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: Decimal
L7:	loc5: Decimal
L8:	loc6: Decimal
L9:	loc7: Decimal
L10:	loc8: Decimal
L11:	loc9: Decimal
L12:	loc10: u64
L13:	loc11: u64
L14:	loc12: Decimal
L15:	loc13: Decimal
L16:	loc14: Decimal
L17:	loc15: Decimal
L18:	loc16: Decimal
L19:	loc17: Decimal
L20:	loc18: u64
L21:	loc19: u128
L22:	loc20: u128
L23:	loc21: u128
L24:	loc22: bool
L25:	loc23: bool
L26:	loc24: u64
L27:	loc25: u64
L28:	loc26: &u64
L29:	loc27: u256
L30:	loc28: bool
L31:	loc29: Decimal
L32:	loc30: u64
L33:	loc31: u128
L34:	loc32: bool
L35:	loc33: Decimal
L36:	loc34: u64
L37:	loc35: Decimal
L38:	loc36: Decimal
L39:	loc37: Decimal
L40:	loc38: u128
L41:	loc39: u64
L42:	loc40: u128
L43:	loc41: u64
L44:	loc42: u64
L45:	loc43: &Update
L46:	loc44: vector<u64>
L47:	loc45: &UpdateState
L48:	loc46: &vector<Update>
L49:	loc47: &vector<u64>
L50:	loc48: u128
L51:	loc49: bool
B0:
	0: CopyLoc[0](Arg0: &Aggregator)
	1: ImmBorrowField[21](Aggregator.update_state: UpdateState)
	2: StLoc[47](loc45: &UpdateState)
	3: CopyLoc[47](loc45: &UpdateState)
	4: ImmBorrowField[22](UpdateState.results: vector<Update>)
	5: StLoc[48](loc46: &vector<Update>)
	6: CopyLoc[47](loc45: &UpdateState)
	7: CopyLoc[0](Arg0: &Aggregator)
	8: ImmBorrowField[7](Aggregator.max_staleness_seconds: u64)
	9: ReadRef
	10: LdU64(1000)
	11: Mul
	12: MoveLoc[1](Arg1: u64)
	13: Call valid_update_indices(&UpdateState, u64, u64): vector<u64>
	14: StLoc[46](loc44: vector<u64>)
	15: ImmBorrowLoc[46](loc44: vector<u64>)
	16: VecLen(6)
	17: MoveLoc[0](Arg0: &Aggregator)
	18: ImmBorrowField[6](Aggregator.min_sample_size: u64)
	19: ReadRef
	20: Lt
	21: BrFalse(28)
B1:
	22: MoveLoc[48](loc46: &vector<Update>)
	23: Pop
	24: MoveLoc[47](loc45: &UpdateState)
	25: Pop
	26: Call option::none<CurrentResult>(): Option<CurrentResult>
	27: Ret
B2:
	28: ImmBorrowLoc[46](loc44: vector<u64>)
	29: VecLen(6)
	30: LdU64(1)
	31: Eq
	32: BrFalse(82)
B3:
	33: MoveLoc[47](loc45: &UpdateState)
	34: MutBorrowLoc[46](loc44: vector<u64>)
	35: Call median_result(&UpdateState, &mut vector<u64>): Decimal * u64
	36: StLoc[43](loc41: u64)
	37: StLoc[38](loc36: Decimal)
	38: CopyLoc[48](loc46: &vector<Update>)
	39: ImmBorrowLoc[46](loc44: vector<u64>)
	40: LdU64(0)
	41: VecImmBorrow(6)
	42: ReadRef
	43: VecImmBorrow(38)
	44: ImmBorrowField[24](Update.timestamp_ms: u64)
	45: ReadRef
	46: StLoc[3](loc1: u64)
	47: MoveLoc[48](loc46: &vector<Update>)
	48: ImmBorrowLoc[46](loc44: vector<u64>)
	49: LdU64(0)
	50: VecImmBorrow(6)
	51: ReadRef
	52: VecImmBorrow(38)
	53: ImmBorrowField[24](Update.timestamp_ms: u64)
	54: ReadRef
	55: StLoc[13](loc11: u64)
	56: CopyLoc[38](loc36: Decimal)
	57: StLoc[14](loc12: Decimal)
	58: CopyLoc[38](loc36: Decimal)
	59: StLoc[15](loc13: Decimal)
	60: Call decimal::zero(): Decimal
	61: StLoc[16](loc14: Decimal)
	62: CopyLoc[38](loc36: Decimal)
	63: StLoc[17](loc15: Decimal)
	64: Call decimal::zero(): Decimal
	65: StLoc[18](loc16: Decimal)
	66: MoveLoc[38](loc36: Decimal)
	67: StLoc[19](loc17: Decimal)
	68: MoveLoc[43](loc41: u64)
	69: StLoc[20](loc18: u64)
	70: MoveLoc[17](loc15: Decimal)
	71: MoveLoc[20](loc18: u64)
	72: MoveLoc[3](loc1: u64)
	73: MoveLoc[13](loc11: u64)
	74: MoveLoc[14](loc12: Decimal)
	75: MoveLoc[15](loc13: Decimal)
	76: MoveLoc[18](loc16: Decimal)
	77: MoveLoc[16](loc14: Decimal)
	78: MoveLoc[19](loc17: Decimal)
	79: Pack[0](CurrentResult)
	80: Call option::some<CurrentResult>(CurrentResult): Option<CurrentResult>
	81: Ret
B4:
	82: LdU128(0)
	83: StLoc[42](loc40: u128)
	84: Call decimal::max_value(): Decimal
	85: StLoc[35](loc33: Decimal)
	86: Call decimal::zero(): Decimal
	87: StLoc[31](loc29: Decimal)
	88: LdU64(18446744073709551615)
	89: StLoc[36](loc34: u64)
	90: LdU64(0)
	91: StLoc[32](loc30: u64)
	92: LdU128(0)
	93: StLoc[33](loc31: u128)
	94: LdFalse
	95: StLoc[34](loc32: bool)
	96: LdU256(0)
	97: StLoc[29](loc27: u256)
	98: LdFalse
	99: StLoc[30](loc28: bool)
	100: LdU128(0)
	101: StLoc[21](loc19: u128)
	102: ImmBorrowLoc[46](loc44: vector<u64>)
	103: StLoc[49](loc47: &vector<u64>)
	104: CopyLoc[49](loc47: &vector<u64>)
	105: VecLen(6)
	106: StLoc[2](loc0: u64)
	107: LdU64(0)
	108: StLoc[27](loc25: u64)
	109: MoveLoc[2](loc0: u64)
	110: StLoc[41](loc39: u64)
B5:
	111: CopyLoc[27](loc25: u64)
	112: CopyLoc[41](loc39: u64)
	113: Lt
	114: BrFalse(205)
B6:
	115: CopyLoc[27](loc25: u64)
	116: StLoc[26](loc24: u64)
	117: CopyLoc[49](loc47: &vector<u64>)
	118: MoveLoc[26](loc24: u64)
	119: VecImmBorrow(6)
	120: StLoc[28](loc26: &u64)
	121: CopyLoc[48](loc46: &vector<Update>)
	122: MoveLoc[28](loc26: &u64)
	123: ReadRef
	124: VecImmBorrow(38)
	125: StLoc[45](loc43: &Update)
	126: CopyLoc[45](loc43: &Update)
	127: ImmBorrowField[25](Update.result: Decimal)
	128: Call decimal::value(&Decimal): u128
	129: StLoc[50](loc48: u128)
	130: CopyLoc[45](loc43: &Update)
	131: ImmBorrowField[25](Update.result: Decimal)
	132: Call decimal::neg(&Decimal): bool
	133: StLoc[51](loc49: bool)
	134: MoveLoc[21](loc19: u128)
	135: LdU128(1)
	136: Add
	137: StLoc[21](loc19: u128)
	138: CopyLoc[50](loc48: u128)
	139: CopyLoc[51](loc49: bool)
	140: CopyLoc[33](loc31: u128)
	141: CopyLoc[34](loc32: bool)
	142: Call sub_i128(u128, bool, u128, bool): u128 * bool
	143: StLoc[25](loc23: bool)
	144: StLoc[22](loc20: u128)
	145: MoveLoc[33](loc31: u128)
	146: MoveLoc[34](loc32: bool)
	147: CopyLoc[22](loc20: u128)
	148: CopyLoc[21](loc19: u128)
	149: Div
	150: CopyLoc[25](loc23: bool)
	151: Call add_i128(u128, bool, u128, bool): u128 * bool
	152: StLoc[34](loc32: bool)
	153: StLoc[33](loc31: u128)
	154: CopyLoc[50](loc48: u128)
	155: MoveLoc[51](loc49: bool)
	156: CopyLoc[33](loc31: u128)
	157: CopyLoc[34](loc32: bool)
	158: Call sub_i128(u128, bool, u128, bool): u128 * bool
	159: StLoc[24](loc22: bool)
	160: StLoc[23](loc21: u128)
	161: MoveLoc[29](loc27: u256)
	162: MoveLoc[30](loc28: bool)
	163: MoveLoc[22](loc20: u128)
	164: CastU256
	165: MoveLoc[23](loc21: u128)
	166: CastU256
	167: Mul
	168: MoveLoc[25](loc23: bool)
	169: MoveLoc[24](loc22: bool)
	170: Neq
	171: Call add_i256(u256, bool, u256, bool): u256 * bool
	172: StLoc[30](loc28: bool)
	173: StLoc[29](loc27: u256)
	174: MoveLoc[42](loc40: u128)
	175: MoveLoc[50](loc48: u128)
	176: Add
	177: StLoc[42](loc40: u128)
	178: ImmBorrowLoc[35](loc33: Decimal)
	179: CopyLoc[45](loc43: &Update)
	180: ImmBorrowField[25](Update.result: Decimal)
	181: Call decimal::min(&Decimal, &Decimal): Decimal
	182: StLoc[35](loc33: Decimal)
	183: ImmBorrowLoc[31](loc29: Decimal)
	184: CopyLoc[45](loc43: &Update)
	185: ImmBorrowField[25](Update.result: Decimal)
	186: Call decimal::max(&Decimal, &Decimal): Decimal
	187: StLoc[31](loc29: Decimal)
	188: MoveLoc[36](loc34: u64)
	189: CopyLoc[45](loc43: &Update)
	190: ImmBorrowField[24](Update.timestamp_ms: u64)
	191: ReadRef
	192: Call u64::min(u64, u64): u64
	193: StLoc[36](loc34: u64)
	194: MoveLoc[32](loc30: u64)
	195: MoveLoc[45](loc43: &Update)
	196: ImmBorrowField[24](Update.timestamp_ms: u64)
	197: ReadRef
	198: Call u64::max(u64, u64): u64
	199: StLoc[32](loc30: u64)
	200: MoveLoc[27](loc25: u64)
	201: LdU64(1)
	202: Add
	203: StLoc[27](loc25: u64)
	204: Branch(111)
B7:
	205: MoveLoc[49](loc47: &vector<u64>)
	206: Pop
	207: MoveLoc[48](loc46: &vector<Update>)
	208: Pop
	209: MoveLoc[29](loc27: u256)
	210: MoveLoc[21](loc19: u128)
	211: LdU128(1)
	212: Sub
	213: CastU256
	214: Div
	215: Call sqrt(u256): u128
	216: StLoc[40](loc38: u128)
	217: ImmBorrowLoc[31](loc29: Decimal)
	218: ImmBorrowLoc[35](loc33: Decimal)
	219: Call decimal::sub(&Decimal, &Decimal): Decimal
	220: StLoc[37](loc35: Decimal)
	221: MoveLoc[47](loc45: &UpdateState)
	222: MutBorrowLoc[46](loc44: vector<u64>)
	223: Call median_result(&UpdateState, &mut vector<u64>): Decimal * u64
	224: StLoc[44](loc42: u64)
	225: StLoc[39](loc37: Decimal)
	226: MoveLoc[36](loc34: u64)
	227: StLoc[4](loc2: u64)
	228: MoveLoc[32](loc30: u64)
	229: StLoc[5](loc3: u64)
	230: MoveLoc[35](loc33: Decimal)
	231: StLoc[6](loc4: Decimal)
	232: MoveLoc[31](loc29: Decimal)
	233: StLoc[7](loc5: Decimal)
	234: MoveLoc[37](loc35: Decimal)
	235: StLoc[8](loc6: Decimal)
	236: MoveLoc[39](loc37: Decimal)
	237: StLoc[9](loc7: Decimal)
	238: MoveLoc[40](loc38: u128)
	239: LdFalse
	240: Call decimal::new(u128, bool): Decimal
	241: StLoc[10](loc8: Decimal)
	242: MoveLoc[33](loc31: u128)
	243: LdFalse
	244: Call decimal::new(u128, bool): Decimal
	245: StLoc[11](loc9: Decimal)
	246: MoveLoc[44](loc42: u64)
	247: StLoc[12](loc10: u64)
	248: MoveLoc[9](loc7: Decimal)
	249: MoveLoc[12](loc10: u64)
	250: MoveLoc[4](loc2: u64)
	251: MoveLoc[5](loc3: u64)
	252: MoveLoc[6](loc4: Decimal)
	253: MoveLoc[7](loc5: Decimal)
	254: MoveLoc[10](loc8: Decimal)
	255: MoveLoc[8](loc6: Decimal)
	256: MoveLoc[11](loc9: Decimal)
	257: Pack[0](CurrentResult)
	258: Call option::some<CurrentResult>(CurrentResult): Option<CurrentResult>
	259: Ret
}

public sqrt(Arg0: u256): u128 {
L1:	loc0: u256
L2:	loc1: u256
L3:	loc2: u256
B0:
	0: CopyLoc[0](Arg0: u256)
	1: LdU256(0)
	2: Eq
	3: BrFalse(6)
B1:
	4: LdU128(0)
	5: Ret
B2:
	6: CopyLoc[0](Arg0: u256)
	7: StLoc[3](loc2: u256)
	8: LdU256(1)
	9: StLoc[1](loc0: u256)
	10: CopyLoc[3](loc2: u256)
	11: LdU256(340282366920938463463374607431768211456)
	12: Ge
	13: BrFalse(22)
B3:
	14: MoveLoc[3](loc2: u256)
	15: LdU8(128)
	16: Shr
	17: StLoc[3](loc2: u256)
	18: MoveLoc[1](loc0: u256)
	19: LdU8(64)
	20: Shl
	21: StLoc[1](loc0: u256)
B4:
	22: CopyLoc[3](loc2: u256)
	23: LdU256(18446744073709551616)
	24: Ge
	25: BrFalse(34)
B5:
	26: MoveLoc[3](loc2: u256)
	27: LdU8(64)
	28: Shr
	29: StLoc[3](loc2: u256)
	30: MoveLoc[1](loc0: u256)
	31: LdU8(32)
	32: Shl
	33: StLoc[1](loc0: u256)
B6:
	34: CopyLoc[3](loc2: u256)
	35: LdU256(4294967296)
	36: Ge
	37: BrFalse(46)
B7:
	38: MoveLoc[3](loc2: u256)
	39: LdU8(32)
	40: Shr
	41: StLoc[3](loc2: u256)
	42: MoveLoc[1](loc0: u256)
	43: LdU8(16)
	44: Shl
	45: StLoc[1](loc0: u256)
B8:
	46: CopyLoc[3](loc2: u256)
	47: LdU256(65536)
	48: Ge
	49: BrFalse(58)
B9:
	50: MoveLoc[3](loc2: u256)
	51: LdU8(16)
	52: Shr
	53: StLoc[3](loc2: u256)
	54: MoveLoc[1](loc0: u256)
	55: LdU8(8)
	56: Shl
	57: StLoc[1](loc0: u256)
B10:
	58: CopyLoc[3](loc2: u256)
	59: LdU256(256)
	60: Ge
	61: BrFalse(70)
B11:
	62: MoveLoc[3](loc2: u256)
	63: LdU8(8)
	64: Shr
	65: StLoc[3](loc2: u256)
	66: MoveLoc[1](loc0: u256)
	67: LdU8(4)
	68: Shl
	69: StLoc[1](loc0: u256)
B12:
	70: CopyLoc[3](loc2: u256)
	71: LdU256(16)
	72: Ge
	73: BrFalse(82)
B13:
	74: MoveLoc[3](loc2: u256)
	75: LdU8(4)
	76: Shr
	77: StLoc[3](loc2: u256)
	78: MoveLoc[1](loc0: u256)
	79: LdU8(2)
	80: Shl
	81: StLoc[1](loc0: u256)
B14:
	82: MoveLoc[3](loc2: u256)
	83: LdU256(8)
	84: Ge
	85: BrFalse(90)
B15:
	86: MoveLoc[1](loc0: u256)
	87: LdU8(1)
	88: Shl
	89: StLoc[1](loc0: u256)
B16:
	90: CopyLoc[1](loc0: u256)
	91: CopyLoc[0](Arg0: u256)
	92: MoveLoc[1](loc0: u256)
	93: Div
	94: Add
	95: LdU8(1)
	96: Shr
	97: StLoc[1](loc0: u256)
	98: CopyLoc[1](loc0: u256)
	99: CopyLoc[0](Arg0: u256)
	100: MoveLoc[1](loc0: u256)
	101: Div
	102: Add
	103: LdU8(1)
	104: Shr
	105: StLoc[1](loc0: u256)
	106: CopyLoc[1](loc0: u256)
	107: CopyLoc[0](Arg0: u256)
	108: MoveLoc[1](loc0: u256)
	109: Div
	110: Add
	111: LdU8(1)
	112: Shr
	113: StLoc[1](loc0: u256)
	114: CopyLoc[1](loc0: u256)
	115: CopyLoc[0](Arg0: u256)
	116: MoveLoc[1](loc0: u256)
	117: Div
	118: Add
	119: LdU8(1)
	120: Shr
	121: StLoc[1](loc0: u256)
	122: CopyLoc[1](loc0: u256)
	123: CopyLoc[0](Arg0: u256)
	124: MoveLoc[1](loc0: u256)
	125: Div
	126: Add
	127: LdU8(1)
	128: Shr
	129: StLoc[1](loc0: u256)
	130: CopyLoc[1](loc0: u256)
	131: CopyLoc[0](Arg0: u256)
	132: MoveLoc[1](loc0: u256)
	133: Div
	134: Add
	135: LdU8(1)
	136: Shr
	137: StLoc[1](loc0: u256)
	138: CopyLoc[1](loc0: u256)
	139: CopyLoc[0](Arg0: u256)
	140: MoveLoc[1](loc0: u256)
	141: Div
	142: Add
	143: LdU8(1)
	144: Shr
	145: StLoc[1](loc0: u256)
	146: MoveLoc[0](Arg0: u256)
	147: CopyLoc[1](loc0: u256)
	148: Div
	149: StLoc[2](loc1: u256)
	150: CopyLoc[1](loc0: u256)
	151: CopyLoc[2](loc1: u256)
	152: Lt
	153: BrFalse(157)
B17:
	154: MoveLoc[1](loc0: u256)
	155: CastU128
	156: Ret
B18:
	157: MoveLoc[2](loc1: u256)
	158: CastU128
	159: Ret
}

add_i256(Arg0: u256, Arg1: bool, Arg2: u256, Arg3: bool): u256 * bool {
L4:	loc0: bool
L5:	loc1: bool
L6:	loc2: bool
B0:
	0: CopyLoc[1](Arg1: bool)
	1: BrFalse(5)
B1:
	2: CopyLoc[3](Arg3: bool)
	3: StLoc[4](loc0: bool)
	4: Branch(7)
B2:
	5: LdFalse
	6: StLoc[4](loc0: bool)
B3:
	7: MoveLoc[4](loc0: bool)
	8: BrFalse(14)
B4:
	9: MoveLoc[0](Arg0: u256)
	10: MoveLoc[2](Arg2: u256)
	11: Add
	12: LdTrue
	13: Ret
B5:
	14: CopyLoc[1](Arg1: bool)
	15: Not
	16: BrFalse(20)
B6:
	17: CopyLoc[3](Arg3: bool)
	18: StLoc[5](loc1: bool)
	19: Branch(22)
B7:
	20: LdFalse
	21: StLoc[5](loc1: bool)
B8:
	22: MoveLoc[5](loc1: bool)
	23: BrFalse(38)
B9:
	24: CopyLoc[0](Arg0: u256)
	25: CopyLoc[2](Arg2: u256)
	26: Lt
	27: BrFalse(33)
B10:
	28: MoveLoc[2](Arg2: u256)
	29: MoveLoc[0](Arg0: u256)
	30: Sub
	31: LdTrue
	32: Ret
B11:
	33: MoveLoc[0](Arg0: u256)
	34: MoveLoc[2](Arg2: u256)
	35: Sub
	36: LdFalse
	37: Ret
B12:
	38: MoveLoc[1](Arg1: bool)
	39: BrFalse(44)
B13:
	40: MoveLoc[3](Arg3: bool)
	41: Not
	42: StLoc[6](loc2: bool)
	43: Branch(46)
B14:
	44: LdFalse
	45: StLoc[6](loc2: bool)
B15:
	46: MoveLoc[6](loc2: bool)
	47: BrFalse(62)
B16:
	48: CopyLoc[0](Arg0: u256)
	49: CopyLoc[2](Arg2: u256)
	50: Lt
	51: BrFalse(57)
B17:
	52: MoveLoc[2](Arg2: u256)
	53: MoveLoc[0](Arg0: u256)
	54: Sub
	55: LdFalse
	56: Ret
B18:
	57: MoveLoc[0](Arg0: u256)
	58: MoveLoc[2](Arg2: u256)
	59: Sub
	60: LdTrue
	61: Ret
B19:
	62: MoveLoc[0](Arg0: u256)
	63: MoveLoc[2](Arg2: u256)
	64: Add
	65: LdFalse
	66: Ret
}

add_i128(Arg0: u128, Arg1: bool, Arg2: u128, Arg3: bool): u128 * bool {
L4:	loc0: bool
L5:	loc1: bool
L6:	loc2: bool
B0:
	0: CopyLoc[1](Arg1: bool)
	1: BrFalse(5)
B1:
	2: CopyLoc[3](Arg3: bool)
	3: StLoc[4](loc0: bool)
	4: Branch(7)
B2:
	5: LdFalse
	6: StLoc[4](loc0: bool)
B3:
	7: MoveLoc[4](loc0: bool)
	8: BrFalse(14)
B4:
	9: MoveLoc[0](Arg0: u128)
	10: MoveLoc[2](Arg2: u128)
	11: Add
	12: LdTrue
	13: Ret
B5:
	14: CopyLoc[1](Arg1: bool)
	15: Not
	16: BrFalse(20)
B6:
	17: CopyLoc[3](Arg3: bool)
	18: StLoc[5](loc1: bool)
	19: Branch(22)
B7:
	20: LdFalse
	21: StLoc[5](loc1: bool)
B8:
	22: MoveLoc[5](loc1: bool)
	23: BrFalse(38)
B9:
	24: CopyLoc[0](Arg0: u128)
	25: CopyLoc[2](Arg2: u128)
	26: Lt
	27: BrFalse(33)
B10:
	28: MoveLoc[2](Arg2: u128)
	29: MoveLoc[0](Arg0: u128)
	30: Sub
	31: LdTrue
	32: Ret
B11:
	33: MoveLoc[0](Arg0: u128)
	34: MoveLoc[2](Arg2: u128)
	35: Sub
	36: LdFalse
	37: Ret
B12:
	38: MoveLoc[1](Arg1: bool)
	39: BrFalse(44)
B13:
	40: MoveLoc[3](Arg3: bool)
	41: Not
	42: StLoc[6](loc2: bool)
	43: Branch(46)
B14:
	44: LdFalse
	45: StLoc[6](loc2: bool)
B15:
	46: MoveLoc[6](loc2: bool)
	47: BrFalse(62)
B16:
	48: CopyLoc[0](Arg0: u128)
	49: CopyLoc[2](Arg2: u128)
	50: Lt
	51: BrFalse(57)
B17:
	52: MoveLoc[2](Arg2: u128)
	53: MoveLoc[0](Arg0: u128)
	54: Sub
	55: LdFalse
	56: Ret
B18:
	57: MoveLoc[0](Arg0: u128)
	58: MoveLoc[2](Arg2: u128)
	59: Sub
	60: LdTrue
	61: Ret
B19:
	62: MoveLoc[0](Arg0: u128)
	63: MoveLoc[2](Arg2: u128)
	64: Add
	65: LdFalse
	66: Ret
}

sub_i128(Arg0: u128, Arg1: bool, Arg2: u128, Arg3: bool): u128 * bool {
B0:
	0: MoveLoc[0](Arg0: u128)
	1: MoveLoc[1](Arg1: bool)
	2: MoveLoc[2](Arg2: u128)
	3: MoveLoc[3](Arg3: bool)
	4: Not
	5: Call add_i128(u128, bool, u128, bool): u128 * bool
	6: Ret
}

median_result(Arg0: &UpdateState, Arg1: &mut vector<u64>): Decimal * u64 {
L2:	loc0: u64
L3:	loc1: u64
L4:	loc2: u64
L5:	loc3: u64
L6:	loc4: u64
L7:	loc5: u64
L8:	loc6: u64
L9:	loc7: &vector<Update>
B0:
	0: MoveLoc[0](Arg0: &UpdateState)
	1: ImmBorrowField[22](UpdateState.results: vector<Update>)
	2: StLoc[9](loc7: &vector<Update>)
	3: CopyLoc[1](Arg1: &mut vector<u64>)
	4: FreezeRef
	5: VecLen(6)
	6: StLoc[7](loc5: u64)
	7: CopyLoc[7](loc5: u64)
	8: LdU64(2)
	9: Div
	10: StLoc[6](loc4: u64)
	11: LdU64(0)
	12: StLoc[5](loc3: u64)
	13: MoveLoc[7](loc5: u64)
	14: LdU64(1)
	15: Sub
	16: StLoc[2](loc0: u64)
B1:
	17: CopyLoc[5](loc3: u64)
	18: CopyLoc[2](loc0: u64)
	19: Lt
	20: BrFalse(87)
B2:
	21: Branch(22)
B3:
	22: CopyLoc[1](Arg1: &mut vector<u64>)
	23: FreezeRef
	24: CopyLoc[2](loc0: u64)
	25: VecImmBorrow(6)
	26: ReadRef
	27: StLoc[8](loc6: u64)
	28: CopyLoc[5](loc3: u64)
	29: StLoc[3](loc1: u64)
	30: CopyLoc[5](loc3: u64)
	31: StLoc[4](loc2: u64)
B4:
	32: CopyLoc[4](loc2: u64)
	33: CopyLoc[2](loc0: u64)
	34: Lt
	35: BrFalse(64)
B5:
	36: Branch(37)
B6:
	37: CopyLoc[9](loc7: &vector<Update>)
	38: CopyLoc[1](Arg1: &mut vector<u64>)
	39: FreezeRef
	40: CopyLoc[4](loc2: u64)
	41: VecImmBorrow(6)
	42: ReadRef
	43: VecImmBorrow(38)
	44: ImmBorrowField[25](Update.result: Decimal)
	45: CopyLoc[9](loc7: &vector<Update>)
	46: CopyLoc[8](loc6: u64)
	47: VecImmBorrow(38)
	48: ImmBorrowField[25](Update.result: Decimal)
	49: Call decimal::lt(&Decimal, &Decimal): bool
	50: BrFalse(59)
B7:
	51: CopyLoc[1](Arg1: &mut vector<u64>)
	52: CopyLoc[3](loc1: u64)
	53: CopyLoc[4](loc2: u64)
	54: VecSwap(6)
	55: MoveLoc[3](loc1: u64)
	56: LdU64(1)
	57: Add
	58: StLoc[3](loc1: u64)
B8:
	59: MoveLoc[4](loc2: u64)
	60: LdU64(1)
	61: Add
	62: StLoc[4](loc2: u64)
	63: Branch(32)
B9:
	64: CopyLoc[1](Arg1: &mut vector<u64>)
	65: CopyLoc[3](loc1: u64)
	66: CopyLoc[2](loc0: u64)
	67: VecSwap(6)
	68: CopyLoc[3](loc1: u64)
	69: CopyLoc[6](loc4: u64)
	70: Eq
	71: BrFalse(73)
B10:
	72: Branch(87)
B11:
	73: CopyLoc[3](loc1: u64)
	74: CopyLoc[6](loc4: u64)
	75: Lt
	76: BrFalse(82)
B12:
	77: MoveLoc[3](loc1: u64)
	78: LdU64(1)
	79: Add
	80: StLoc[5](loc3: u64)
	81: Branch(17)
B13:
	82: MoveLoc[3](loc1: u64)
	83: LdU64(1)
	84: Sub
	85: StLoc[2](loc0: u64)
	86: Branch(17)
B14:
	87: CopyLoc[9](loc7: &vector<Update>)
	88: CopyLoc[1](Arg1: &mut vector<u64>)
	89: FreezeRef
	90: CopyLoc[6](loc4: u64)
	91: VecImmBorrow(6)
	92: ReadRef
	93: VecImmBorrow(38)
	94: ImmBorrowField[25](Update.result: Decimal)
	95: ReadRef
	96: MoveLoc[9](loc7: &vector<Update>)
	97: MoveLoc[1](Arg1: &mut vector<u64>)
	98: FreezeRef
	99: MoveLoc[6](loc4: u64)
	100: VecImmBorrow(6)
	101: ReadRef
	102: VecImmBorrow(38)
	103: ImmBorrowField[24](Update.timestamp_ms: u64)
	104: ReadRef
	105: Ret
}

valid_update_indices(Arg0: &UpdateState, Arg1: u64, Arg2: u64): vector<u64> {
L3:	loc0: bool
L4:	loc1: u64
L5:	loc2: ID
L6:	loc3: u64
L7:	loc4: &vector<Update>
L8:	loc5: VecSet<ID>
L9:	loc6: vector<u64>
B0:
	0: CopyLoc[0](Arg0: &UpdateState)
	1: ImmBorrowField[22](UpdateState.results: vector<Update>)
	2: StLoc[7](loc4: &vector<Update>)
	3: VecPack(6, 0)
	4: StLoc[9](loc6: vector<u64>)
	5: Call vec_set::empty<ID>(): VecSet<ID>
	6: StLoc[8](loc5: VecSet<ID>)
	7: MoveLoc[0](Arg0: &UpdateState)
	8: ImmBorrowField[23](UpdateState.curr_idx: u64)
	9: ReadRef
	10: StLoc[4](loc1: u64)
	11: LdConst[0](u64: 16)
	12: CopyLoc[7](loc4: &vector<Update>)
	13: VecLen(38)
	14: Call u64::min(u64, u64): u64
	15: StLoc[6](loc3: u64)
	16: CopyLoc[6](loc3: u64)
	17: LdU64(0)
	18: Eq
	19: BrFalse(24)
B1:
	20: MoveLoc[7](loc4: &vector<Update>)
	21: Pop
	22: MoveLoc[9](loc6: vector<u64>)
	23: Ret
B2:
	24: CopyLoc[6](loc3: u64)
	25: LdU64(0)
	26: Eq
	27: BrFalse(31)
B3:
	28: LdTrue
	29: StLoc[3](loc0: bool)
	30: Branch(42)
B4:
	31: CopyLoc[7](loc4: &vector<Update>)
	32: CopyLoc[4](loc1: u64)
	33: VecImmBorrow(38)
	34: ImmBorrowField[24](Update.timestamp_ms: u64)
	35: ReadRef
	36: CopyLoc[1](Arg1: u64)
	37: Add
	38: CopyLoc[2](Arg2: u64)
	39: Lt
	40: StLoc[3](loc0: bool)
	41: Branch(42)
B5:
	42: MoveLoc[3](loc0: bool)
	43: BrFalse(45)
B6:
	44: Branch(81)
B7:
	45: CopyLoc[7](loc4: &vector<Update>)
	46: CopyLoc[4](loc1: u64)
	47: VecImmBorrow(38)
	48: ImmBorrowField[26](Update.oracle: ID)
	49: ReadRef
	50: StLoc[5](loc2: ID)
	51: ImmBorrowLoc[8](loc5: VecSet<ID>)
	52: ImmBorrowLoc[5](loc2: ID)
	53: Call vec_set::contains<ID>(&VecSet<ID>, &ID): bool
	54: Not
	55: BrFalse(62)
B8:
	56: MutBorrowLoc[8](loc5: VecSet<ID>)
	57: MoveLoc[5](loc2: ID)
	58: Call vec_set::insert<ID>(&mut VecSet<ID>, ID)
	59: MutBorrowLoc[9](loc6: vector<u64>)
	60: CopyLoc[4](loc1: u64)
	61: VecPushBack(6)
B9:
	62: CopyLoc[4](loc1: u64)
	63: LdU64(0)
	64: Eq
	65: BrFalse(72)
B10:
	66: CopyLoc[7](loc4: &vector<Update>)
	67: VecLen(38)
	68: LdU64(1)
	69: Sub
	70: StLoc[4](loc1: u64)
	71: Branch(76)
B11:
	72: MoveLoc[4](loc1: u64)
	73: LdU64(1)
	74: Sub
	75: StLoc[4](loc1: u64)
B12:
	76: MoveLoc[6](loc3: u64)
	77: LdU64(1)
	78: Sub
	79: StLoc[6](loc3: u64)
	80: Branch(24)
B13:
	81: MoveLoc[7](loc4: &vector<Update>)
	82: Pop
	83: MoveLoc[9](loc6: vector<u64>)
	84: Ret
}

Constants [
	0 => u64: 16
	1 => u8: 1
]
}
