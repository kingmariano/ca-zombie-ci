// Move bytecode v6
module 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1.aggregator_delete_action {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::aggregator;

struct AggregatorDeleted has copy, drop {
	aggregator_id: ID
}

public validate(Arg0: &Aggregator, Arg1: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &Aggregator)
	1: Call aggregator::version(&Aggregator): u8
	2: LdConst[0](u8: 1)
	3: Eq
	4: BrFalse(6)
B1:
	5: Branch(12)
B2:
	6: MoveLoc[1](Arg1: &mut TxContext)
	7: Pop
	8: MoveLoc[0](Arg0: &Aggregator)
	9: Pop
	10: LdU64(9223372114164383748)
	11: Abort
B3:
	12: MoveLoc[0](Arg0: &Aggregator)
	13: MoveLoc[1](Arg1: &mut TxContext)
	14: Call aggregator::has_authority(&Aggregator, &mut TxContext): bool
	15: BrFalse(17)
B4:
	16: Branch(19)
B5:
	17: LdU64(9223372118459219970)
	18: Abort
B6:
	19: Ret
}

actuate(Arg0: Aggregator) {
L1:	loc0: AggregatorDeleted
B0:
	0: ImmBorrowLoc[0](Arg0: Aggregator)
	1: Call aggregator::id(&Aggregator): ID
	2: Pack[0](AggregatorDeleted)
	3: StLoc[1](loc0: AggregatorDeleted)
	4: MoveLoc[0](Arg0: Aggregator)
	5: Call aggregator::delete(Aggregator)
	6: MoveLoc[1](loc0: AggregatorDeleted)
	7: Call event::emit<AggregatorDeleted>(AggregatorDeleted)
	8: Ret
}

entry public run(Arg0: Aggregator, Arg1: &mut TxContext) {
B0:
	0: ImmBorrowLoc[0](Arg0: Aggregator)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call validate(&Aggregator, &mut TxContext)
	3: MoveLoc[0](Arg0: Aggregator)
	4: Call actuate(Aggregator)
	5: Ret
}

Constants [
	0 => u8: 1
	1 => vector<u8>: "EInvalidAuthority" // interpreted as UTF8 string
	2 => vector<u8>: "Invalid authority" // interpreted as UTF8 string
	3 => vector<u8>: "EInvalidAggregatorVersion" // interpreted as UTF8 string
	4 => vector<u8>: "Invalid aggregator version" // interpreted as UTF8 string
]
}
