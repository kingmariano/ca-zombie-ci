// Move bytecode v6
module 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10.pool_incentive_events {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct RewarderCreated has copy, drop {
	rewarder_id: ID,
	reward_type: String,
	start_timestamp: u64,
	flow_rate: u256
}

struct SourceChanged has copy, drop {
	rewarder_id: ID,
	reward_type: String,
	amount: u64,
	is_deposit: bool
}

struct FlowRateChanged has copy, drop {
	rewarder_id: ID,
	reward_type: String,
	flow_rate: u256
}

struct ClaimReward has copy, drop {
	rewarder_id: ID,
	account: address,
	reward_type: String,
	amount: u64
}

struct AirdropReward has copy, drop {
	rewarder_id: ID,
	account: address,
	reward_type: String,
	amount: u64
}

public(friend) emit_rewarder_created<Ty0>(Arg0: ID, Arg1: u64, Arg2: u256) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: Call type_name::into_string(TypeName): String
	3: MoveLoc[1](Arg1: u64)
	4: MoveLoc[2](Arg2: u256)
	5: Pack[0](RewarderCreated)
	6: Call event::emit<RewarderCreated>(RewarderCreated)
	7: Ret
}

public(friend) emit_source_changed<Ty0>(Arg0: ID, Arg1: u64, Arg2: bool) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: Call type_name::into_string(TypeName): String
	3: MoveLoc[1](Arg1: u64)
	4: MoveLoc[2](Arg2: bool)
	5: Pack[1](SourceChanged)
	6: Call event::emit<SourceChanged>(SourceChanged)
	7: Ret
}

public(friend) emit_flow_rate_changed<Ty0>(Arg0: ID, Arg1: u256) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: Call type_name::into_string(TypeName): String
	3: MoveLoc[1](Arg1: u256)
	4: Pack[2](FlowRateChanged)
	5: Call event::emit<FlowRateChanged>(FlowRateChanged)
	6: Ret
}

public(friend) emit_claim_reward<Ty0>(Arg0: ID, Arg1: address, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: Call type_name::get<Ty0>(): TypeName
	3: Call type_name::into_string(TypeName): String
	4: MoveLoc[2](Arg2: u64)
	5: Pack[3](ClaimReward)
	6: Call event::emit<ClaimReward>(ClaimReward)
	7: Ret
}

public(friend) emit_airdrop_reward<Ty0>(Arg0: ID, Arg1: address, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: Call type_name::get<Ty0>(): TypeName
	3: Call type_name::into_string(TypeName): String
	4: MoveLoc[2](Arg2: u64)
	5: Pack[4](AirdropReward)
	6: Call event::emit<AirdropReward>(AirdropReward)
	7: Ret
}

}
