// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.event {
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::event as 1event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;

struct NewCenterEvent has copy, drop {
	point_type: String,
	id: ID,
	admin_id: ID
}

struct NewPoolEvent<phantom Ty0> has copy, drop {
	asset_type: String,
	id: ID
}

struct StakeEvent<phantom Ty0> has copy, drop {
	pool_id: ID,
	asset_type: String,
	account: address,
	amount: u64,
	balance: u64
}

struct UnstakeEvent<phantom Ty0> has copy, drop {
	pool_id: ID,
	asset_type: String,
	account: address,
	amount: u64,
	balance: u64
}

struct CumulateEvent<phantom Ty0> has copy, drop {
	pool_id: ID,
	asset_type: String,
	account: address,
	points: u64,
	cumulant: u64
}

struct ClaimEvent<phantom Ty0> has copy, drop {
	account: address,
	amount: u64
}

struct MintEvent<phantom Ty0> has copy, drop {
	pool_id: ID,
	asset_type: String,
	amount: u64,
	supply: u64
}

struct BurnEvent<phantom Ty0> has copy, drop {
	points: u64,
	supply: u64,
	origin: Option<String>
}

public(friend) emit_new_center<Ty0>(Arg0: ID, Arg1: ID) {
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: Call type_name::into_string(TypeName): String
	2: MoveLoc[0](Arg0: ID)
	3: MoveLoc[1](Arg1: ID)
	4: Pack[0](NewCenterEvent)
	5: Call 1event::emit<NewCenterEvent>(NewCenterEvent)
	6: Ret
}

public(friend) emit_new_pool<Ty0, Ty1>(Arg0: ID) {
B0:
	0: Call type_name::get<Ty1>(): TypeName
	1: Call type_name::into_string(TypeName): String
	2: MoveLoc[0](Arg0: ID)
	3: PackGeneric[0](NewPoolEvent<Ty0>)
	4: Call 1event::emit<NewPoolEvent<Ty0>>(NewPoolEvent<Ty0>)
	5: Ret
}

public(friend) emit_stake<Ty0>(Arg0: ID, Arg1: TypeName, Arg2: address, Arg3: u64, Arg4: u64) {
L5:	loc0: String
B0:
	0: MoveLoc[1](Arg1: TypeName)
	1: Call type_name::into_string(TypeName): String
	2: StLoc[5](loc0: String)
	3: MoveLoc[0](Arg0: ID)
	4: MoveLoc[5](loc0: String)
	5: MoveLoc[2](Arg2: address)
	6: MoveLoc[3](Arg3: u64)
	7: MoveLoc[4](Arg4: u64)
	8: PackGeneric[1](StakeEvent<Ty0>)
	9: Call 1event::emit<StakeEvent<Ty0>>(StakeEvent<Ty0>)
	10: Ret
}

public(friend) emit_unstake<Ty0>(Arg0: ID, Arg1: TypeName, Arg2: address, Arg3: u64, Arg4: u64) {
L5:	loc0: String
B0:
	0: MoveLoc[1](Arg1: TypeName)
	1: Call type_name::into_string(TypeName): String
	2: StLoc[5](loc0: String)
	3: MoveLoc[0](Arg0: ID)
	4: MoveLoc[5](loc0: String)
	5: MoveLoc[2](Arg2: address)
	6: MoveLoc[3](Arg3: u64)
	7: MoveLoc[4](Arg4: u64)
	8: PackGeneric[2](UnstakeEvent<Ty0>)
	9: Call 1event::emit<UnstakeEvent<Ty0>>(UnstakeEvent<Ty0>)
	10: Ret
}

public(friend) emit_cumulate<Ty0>(Arg0: &ID, Arg1: String, Arg2: address, Arg3: u64, Arg4: u64) {
B0:
	0: MoveLoc[0](Arg0: &ID)
	1: ReadRef
	2: MoveLoc[1](Arg1: String)
	3: MoveLoc[2](Arg2: address)
	4: MoveLoc[3](Arg3: u64)
	5: MoveLoc[4](Arg4: u64)
	6: PackGeneric[3](CumulateEvent<Ty0>)
	7: Call 1event::emit<CumulateEvent<Ty0>>(CumulateEvent<Ty0>)
	8: Ret
}

public(friend) emit_claim<Ty0>(Arg0: address, Arg1: u64) {
B0:
	0: MoveLoc[0](Arg0: address)
	1: MoveLoc[1](Arg1: u64)
	2: PackGeneric[4](ClaimEvent<Ty0>)
	3: Call 1event::emit<ClaimEvent<Ty0>>(ClaimEvent<Ty0>)
	4: Ret
}

public(friend) emit_mint<Ty0>(Arg0: &ID, Arg1: String, Arg2: u64, Arg3: u64) {
B0:
	0: MoveLoc[0](Arg0: &ID)
	1: ReadRef
	2: MoveLoc[1](Arg1: String)
	3: MoveLoc[2](Arg2: u64)
	4: MoveLoc[3](Arg3: u64)
	5: PackGeneric[5](MintEvent<Ty0>)
	6: Call 1event::emit<MintEvent<Ty0>>(MintEvent<Ty0>)
	7: Ret
}

public(friend) emit_burn<Ty0>(Arg0: u64, Arg1: u64, Arg2: Option<TypeName>) {
L3:	loc0: Option<String>
L4:	loc1: Option<TypeName>
L5:	loc2: Option<String>
B0:
	0: MoveLoc[2](Arg2: Option<TypeName>)
	1: StLoc[4](loc1: Option<TypeName>)
	2: ImmBorrowLoc[4](loc1: Option<TypeName>)
	3: Call option::is_some<TypeName>(&Option<TypeName>): bool
	4: BrFalse(11)
B1:
	5: MoveLoc[4](loc1: Option<TypeName>)
	6: Call option::destroy_some<TypeName>(Option<TypeName>): TypeName
	7: Call type_name::into_string(TypeName): String
	8: Call option::some<String>(String): Option<String>
	9: StLoc[3](loc0: Option<String>)
	10: Branch(15)
B2:
	11: MoveLoc[4](loc1: Option<TypeName>)
	12: Call option::destroy_none<TypeName>(Option<TypeName>)
	13: Call option::none<String>(): Option<String>
	14: StLoc[3](loc0: Option<String>)
B3:
	15: MoveLoc[3](loc0: Option<String>)
	16: StLoc[5](loc2: Option<String>)
	17: MoveLoc[0](Arg0: u64)
	18: MoveLoc[1](Arg1: u64)
	19: MoveLoc[5](loc2: Option<String>)
	20: PackGeneric[6](BurnEvent<Ty0>)
	21: Call 1event::emit<BurnEvent<Ty0>>(BurnEvent<Ty0>)
	22: Ret
}

}
