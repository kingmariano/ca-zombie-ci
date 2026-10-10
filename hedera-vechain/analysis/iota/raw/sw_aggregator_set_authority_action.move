// Move bytecode v6
module 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1.aggregator_set_authority_action {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 8650249db8ffcffe8eb08b0696a8cb71e325f2afb9abc646f45344077b073ba1::aggregator;

struct AggregatorAuthorityUpdated has copy, drop {
	aggregator_id: ID,
	existing_authority: address,
	new_authority: address
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
	10: LdU64(9223372122754318340)
	11: Abort
B3:
	12: MoveLoc[0](Arg0: &Aggregator)
	13: MoveLoc[1](Arg1: &mut TxContext)
	14: Call aggregator::has_authority(&Aggregator, &mut TxContext): bool
	15: BrFalse(17)
B4:
	16: Branch(19)
B5:
	17: LdU64(9223372127049154562)
	18: Abort
B6:
	19: Ret
}

actuate(Arg0: &mut Aggregator, Arg1: address) {
L2:	loc0: AggregatorAuthorityUpdated
B0:
	0: CopyLoc[0](Arg0: &mut Aggregator)
	1: FreezeRef
	2: Call aggregator::id(&Aggregator): ID
	3: CopyLoc[0](Arg0: &mut Aggregator)
	4: FreezeRef
	5: Call aggregator::authority(&Aggregator): address
	6: CopyLoc[1](Arg1: address)
	7: Pack[0](AggregatorAuthorityUpdated)
	8: StLoc[2](loc0: AggregatorAuthorityUpdated)
	9: MoveLoc[0](Arg0: &mut Aggregator)
	10: MoveLoc[1](Arg1: address)
	11: Call aggregator::set_authority(&mut Aggregator, address)
	12: MoveLoc[2](loc0: AggregatorAuthorityUpdated)
	13: Call event::emit<AggregatorAuthorityUpdated>(AggregatorAuthorityUpdated)
	14: Ret
}

entry public run(Arg0: &mut Aggregator, Arg1: address, Arg2: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut Aggregator)
	1: FreezeRef
	2: MoveLoc[2](Arg2: &mut TxContext)
	3: Call validate(&Aggregator, &mut TxContext)
	4: MoveLoc[0](Arg0: &mut Aggregator)
	5: MoveLoc[1](Arg1: address)
	6: Call actuate(&mut Aggregator, address)
	7: Ret
}

Constants [
	0 => u8: 1
	1 => vector<u8>: "EInvalidAuthority" // interpreted as UTF8 string
	2 => vector<u8>: "Invalid authority" // interpreted as UTF8 string
	3 => vector<u8>: "EInvalidAggregatorVersion" // interpreted as UTF8 string
	4 => vector<u8>: "Invalid aggregator version" // interpreted as UTF8 string
]
}
