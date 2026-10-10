// Move bytecode v6
module 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1.aggregator_init_action {
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::aggregator;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::queue;

struct AggregatorCreated has copy, drop {
	aggregator_id: ID,
	name: String
}

public validate(Arg0: &Queue, Arg1: vector<u8>, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u32) {
B0:
	0: MoveLoc[0](Arg0: &Queue)
	1: Call queue::version(&Queue): u8
	2: LdConst[0](u8: 1)
	3: Eq
	4: BrFalse(6)
B1:
	5: Branch(8)
B2:
	6: LdU64(9223372195769286668)
	7: Abort
B3:
	8: MoveLoc[2](Arg2: u64)
	9: LdU64(0)
	10: Gt
	11: BrFalse(13)
B4:
	12: Branch(15)
B5:
	13: LdU64(9223372200063598594)
	14: Abort
B6:
	15: MoveLoc[4](Arg4: u64)
	16: LdU64(0)
	17: Gt
	18: BrFalse(20)
B7:
	19: Branch(22)
B8:
	20: LdU64(9223372204358696964)
	21: Abort
B9:
	22: ImmBorrowLoc[1](Arg1: vector<u8>)
	23: VecLen(5)
	24: LdU64(32)
	25: Eq
	26: BrFalse(28)
B10:
	27: Branch(30)
B11:
	28: LdU64(9223372208653795334)
	29: Abort
B12:
	30: MoveLoc[5](Arg5: u32)
	31: LdU32(0)
	32: Gt
	33: BrFalse(35)
B13:
	34: Branch(37)
B14:
	35: LdU64(9223372212948893704)
	36: Abort
B15:
	37: MoveLoc[3](Arg3: u64)
	38: LdU64(0)
	39: Gt
	40: BrFalse(42)
B16:
	41: Branch(44)
B17:
	42: LdU64(9223372217243992074)
	43: Abort
B18:
	44: Ret
}

actuate(Arg0: address, Arg1: &Queue, Arg2: String, Arg3: vector<u8>, Arg4: u64, Arg5: u64, Arg6: u64, Arg7: u32, Arg8: &Clock, Arg9: &mut TxContext) {
B0:
	0: MoveLoc[1](Arg1: &Queue)
	1: Call queue::id(&Queue): ID
	2: CopyLoc[2](Arg2: String)
	3: MoveLoc[0](Arg0: address)
	4: MoveLoc[3](Arg3: vector<u8>)
	5: MoveLoc[4](Arg4: u64)
	6: MoveLoc[5](Arg5: u64)
	7: MoveLoc[6](Arg6: u64)
	8: MoveLoc[7](Arg7: u32)
	9: MoveLoc[8](Arg8: &Clock)
	10: Call clock::timestamp_ms(&Clock): u64
	11: MoveLoc[9](Arg9: &mut TxContext)
	12: Call aggregator::new(ID, String, address, vector<u8>, u64, u64, u64, u32, u64, &mut TxContext): ID
	13: MoveLoc[2](Arg2: String)
	14: Pack[0](AggregatorCreated)
	15: Call event::emit<AggregatorCreated>(AggregatorCreated)
	16: Ret
}

entry public run(Arg0: &Queue, Arg1: address, Arg2: String, Arg3: vector<u8>, Arg4: u64, Arg5: u64, Arg6: u64, Arg7: u32, Arg8: &Clock, Arg9: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &Queue)
	1: CopyLoc[3](Arg3: vector<u8>)
	2: CopyLoc[4](Arg4: u64)
	3: CopyLoc[5](Arg5: u64)
	4: CopyLoc[6](Arg6: u64)
	5: CopyLoc[7](Arg7: u32)
	6: Call validate(&Queue, vector<u8>, u64, u64, u64, u32)
	7: MoveLoc[1](Arg1: address)
	8: MoveLoc[0](Arg0: &Queue)
	9: MoveLoc[2](Arg2: String)
	10: MoveLoc[3](Arg3: vector<u8>)
	11: MoveLoc[4](Arg4: u64)
	12: MoveLoc[5](Arg5: u64)
	13: MoveLoc[6](Arg6: u64)
	14: MoveLoc[7](Arg7: u32)
	15: MoveLoc[8](Arg8: &Clock)
	16: MoveLoc[9](Arg9: &mut TxContext)
	17: Call actuate(address, &Queue, String, vector<u8>, u64, u64, u64, u32, &Clock, &mut TxContext)
	18: Ret
}

Constants [
	0 => u8: 1
	1 => vector<u8>: "EInvalidMinSampleSize" // interpreted as UTF8 string
	2 => vector<u8>: "Invalid min_sample_size" // interpreted as UTF8 string
	3 => vector<u8>: "EInvalidMaxVariance" // interpreted as UTF8 string
	4 => vector<u8>: "Invalid max_variance" // interpreted as UTF8 string
	5 => vector<u8>: "EInvalidFeedHash" // interpreted as UTF8 string
	6 => vector<u8>: "Invalid feed_hash" // interpreted as UTF8 string
	7 => vector<u8>: "EInvalidMinResponses" // interpreted as UTF8 string
	8 => vector<u8>: "Invalid min_responses" // interpreted as UTF8 string
	9 => vector<u8>: "EInvalidMaxStalenessSeconds" // interpreted as UTF8 string
	10 => vector<u8>: "Invalid max_staleness_seconds" // interpreted as UTF8 string
	11 => vector<u8>: "EInvalidQueueVersion" // interpreted as UTF8 string
	12 => vector<u8>: "Invalid queue version" // interpreted as UTF8 string
]
}
