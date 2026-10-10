// Move bytecode v6
module 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1.aggregator_set_configs_action {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::aggregator;

struct AggregatorConfigsUpdated has copy, drop {
	aggregator_id: ID,
	feed_hash: vector<u8>,
	min_sample_size: u64,
	max_staleness_seconds: u64,
	max_variance: u64,
	min_responses: u32
}

public validate(Arg0: &Aggregator, Arg1: vector<u8>, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u32, Arg6: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &Aggregator)
	1: Call aggregator::version(&Aggregator): u8
	2: LdConst[0](u8: 1)
	3: Eq
	4: BrFalse(6)
B1:
	5: Branch(12)
B2:
	6: MoveLoc[6](Arg6: &mut TxContext)
	7: Pop
	8: MoveLoc[0](Arg0: &Aggregator)
	9: Pop
	10: LdU64(9223372212949286926)
	11: Abort
B3:
	12: MoveLoc[0](Arg0: &Aggregator)
	13: MoveLoc[6](Arg6: &mut TxContext)
	14: Call aggregator::has_authority(&Aggregator, &mut TxContext): bool
	15: BrFalse(17)
B4:
	16: Branch(19)
B5:
	17: LdU64(9223372217243467778)
	18: Abort
B6:
	19: MoveLoc[2](Arg2: u64)
	20: LdU64(0)
	21: Gt
	22: BrFalse(24)
B7:
	23: Branch(26)
B8:
	24: LdU64(9223372221538566148)
	25: Abort
B9:
	26: MoveLoc[4](Arg4: u64)
	27: LdU64(0)
	28: Gt
	29: BrFalse(31)
B10:
	30: Branch(33)
B11:
	31: LdU64(9223372225833664518)
	32: Abort
B12:
	33: ImmBorrowLoc[1](Arg1: vector<u8>)
	34: VecLen(5)
	35: LdU64(32)
	36: Eq
	37: BrFalse(39)
B13:
	38: Branch(41)
B14:
	39: LdU64(9223372230128762888)
	40: Abort
B15:
	41: MoveLoc[5](Arg5: u32)
	42: LdU32(0)
	43: Gt
	44: BrFalse(46)
B16:
	45: Branch(48)
B17:
	46: LdU64(9223372234423861258)
	47: Abort
B18:
	48: MoveLoc[3](Arg3: u64)
	49: LdU64(0)
	50: Gt
	51: BrFalse(53)
B19:
	52: Branch(55)
B20:
	53: LdU64(9223372238718959628)
	54: Abort
B21:
	55: Ret
}

actuate(Arg0: &mut Aggregator, Arg1: vector<u8>, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u32) {
B0:
	0: CopyLoc[0](Arg0: &mut Aggregator)
	1: CopyLoc[1](Arg1: vector<u8>)
	2: CopyLoc[2](Arg2: u64)
	3: CopyLoc[3](Arg3: u64)
	4: CopyLoc[4](Arg4: u64)
	5: CopyLoc[5](Arg5: u32)
	6: Call aggregator::set_configs(&mut Aggregator, vector<u8>, u64, u64, u64, u32)
	7: MoveLoc[0](Arg0: &mut Aggregator)
	8: FreezeRef
	9: Call aggregator::id(&Aggregator): ID
	10: MoveLoc[1](Arg1: vector<u8>)
	11: MoveLoc[2](Arg2: u64)
	12: MoveLoc[3](Arg3: u64)
	13: MoveLoc[4](Arg4: u64)
	14: MoveLoc[5](Arg5: u32)
	15: Pack[0](AggregatorConfigsUpdated)
	16: Call event::emit<AggregatorConfigsUpdated>(AggregatorConfigsUpdated)
	17: Ret
}

entry public run(Arg0: &mut Aggregator, Arg1: vector<u8>, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u32, Arg6: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut Aggregator)
	1: FreezeRef
	2: CopyLoc[1](Arg1: vector<u8>)
	3: CopyLoc[2](Arg2: u64)
	4: CopyLoc[3](Arg3: u64)
	5: CopyLoc[4](Arg4: u64)
	6: CopyLoc[5](Arg5: u32)
	7: MoveLoc[6](Arg6: &mut TxContext)
	8: Call validate(&Aggregator, vector<u8>, u64, u64, u64, u32, &mut TxContext)
	9: MoveLoc[0](Arg0: &mut Aggregator)
	10: MoveLoc[1](Arg1: vector<u8>)
	11: MoveLoc[2](Arg2: u64)
	12: MoveLoc[3](Arg3: u64)
	13: MoveLoc[4](Arg4: u64)
	14: MoveLoc[5](Arg5: u32)
	15: Call actuate(&mut Aggregator, vector<u8>, u64, u64, u64, u32)
	16: Ret
}

Constants [
	0 => u8: 1
	1 => vector<u8>: "EInvalidAuthority" // interpreted as UTF8 string
	2 => vector<u8>: "Invalid authority" // interpreted as UTF8 string
	3 => vector<u8>: "EInvalidMinSampleSize" // interpreted as UTF8 string
	4 => vector<u8>: "Invalid min_sample_size" // interpreted as UTF8 string
	5 => vector<u8>: "EInvalidMaxVariance" // interpreted as UTF8 string
	6 => vector<u8>: "Invalid max_variance" // interpreted as UTF8 string
	7 => vector<u8>: "EInvalidFeedHash" // interpreted as UTF8 string
	8 => vector<u8>: "Invalid feed_hash" // interpreted as UTF8 string
	9 => vector<u8>: "EInvalidMinResponses" // interpreted as UTF8 string
	10 => vector<u8>: "Invalid min_responses" // interpreted as UTF8 string
	11 => vector<u8>: "EInvalidMaxStalenessSeconds" // interpreted as UTF8 string
	12 => vector<u8>: "Invalid max_staleness_seconds" // interpreted as UTF8 string
	13 => vector<u8>: "EInvalidAggregatorVersion" // interpreted as UTF8 string
	14 => vector<u8>: "Invalid aggregator version" // interpreted as UTF8 string
]
}
