// Move bytecode v6
module 86aa277cf34776edba2ccf29b2c61a1b49d652a34c5a2321e787ca717412fd10.borrow_incentive_events {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct RewarderCreated has copy, drop {
	vault_id: ID,
	rewarder_id: ID,
	asset_type: String,
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
	asset_type: String,
	reward_type: String,
	flow_rate: u256
}

struct ClaimReward has copy, drop {
	rewarder_id: ID,
	account: address,
	asset_type: String,
	reward_type: String,
	amount: u64
}

struct AirdropReward has copy, drop {
	rewarder_id: ID,
	account: address,
	asset_type: String,
	reward_type: String,
	amount: u64
}

public(friend) emit_rewarder_created<Ty0, Ty1>(Arg0: ID, Arg1: ID, Arg2: u64, Arg3: u256) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: ID)
	2: Call type_name::get<Ty0>(): TypeName
	3: Call type_name::into_string(TypeName): String
	4: Call type_name::get<Ty1>(): TypeName
	5: Call type_name::into_string(TypeName): String
	6: MoveLoc[2](Arg2: u64)
	7: MoveLoc[3](Arg3: u256)
	8: Pack[0](RewarderCreated)
	9: Call event::emit<RewarderCreated>(RewarderCreated)
	10: Ret
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

public(friend) emit_flow_rate_changed<Ty0, Ty1>(Arg0: ID, Arg1: u256) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: Call type_name::into_string(TypeName): String
	3: Call type_name::get<Ty1>(): TypeName
	4: Call type_name::into_string(TypeName): String
	5: MoveLoc[1](Arg1: u256)
	6: Pack[2](FlowRateChanged)
	7: Call event::emit<FlowRateChanged>(FlowRateChanged)
	8: Ret
}

public(friend) emit_claim_reward<Ty0, Ty1>(Arg0: ID, Arg1: address, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: Call type_name::get<Ty0>(): TypeName
	3: Call type_name::into_string(TypeName): String
	4: Call type_name::get<Ty1>(): TypeName
	5: Call type_name::into_string(TypeName): String
	6: MoveLoc[2](Arg2: u64)
	7: Pack[3](ClaimReward)
	8: Call event::emit<ClaimReward>(ClaimReward)
	9: Ret
}

public(friend) emit_airdrop_reward<Ty0, Ty1>(Arg0: ID, Arg1: address, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: MoveLoc[1](Arg1: address)
	2: Call type_name::get<Ty0>(): TypeName
	3: Call type_name::into_string(TypeName): String
	4: Call type_name::get<Ty1>(): TypeName
	5: Call type_name::into_string(TypeName): String
	6: MoveLoc[2](Arg2: u64)
	7: Pack[4](AirdropReward)
	8: Call event::emit<AirdropReward>(AirdropReward)
	9: Ret
}

}
