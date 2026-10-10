// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.events {
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::double;
use 7400af41a9b9d7e4502bc77991dbd1171f90855564fd28afa172a5057beb083b::float;

struct VaultCreated has copy, drop {
	vault_id: ID,
	coll_type: TypeName,
	interest_rate: u256,
	supply_limit: u64,
	min_collateral_ratio: u128
}

struct SupplyLimitUpdated has copy, drop {
	vault_id: ID,
	coll_type: TypeName,
	before: u64,
	after: u64
}

struct LiquidationRuleUpdated has copy, drop {
	vault_id: ID,
	coll_type: TypeName,
	before: TypeName,
	after: TypeName
}

struct PositionUpdated has copy, drop {
	vault_id: ID,
	coll_type: TypeName,
	debtor: address,
	deposit: u64,
	borrow: u64,
	withdraw: u64,
	repay: u64,
	interest: u64,
	current_coll: u64,
	current_debt: u64,
	memo: String
}

public(friend) emit_vault_created<Ty0>(Arg0: ID, Arg1: Double, Arg2: u64, Arg3: Float) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: MoveLoc[1](Arg1: Double)
	3: Call double::to_scaled_val(Double): u256
	4: MoveLoc[2](Arg2: u64)
	5: MoveLoc[3](Arg3: Float)
	6: Call float::to_scaled_val(Float): u128
	7: Pack[0](VaultCreated)
	8: Call event::emit<VaultCreated>(VaultCreated)
	9: Ret
}

public(friend) emit_supply_limit_updated<Ty0>(Arg0: ID, Arg1: u64, Arg2: u64) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: MoveLoc[1](Arg1: u64)
	3: MoveLoc[2](Arg2: u64)
	4: Pack[1](SupplyLimitUpdated)
	5: Call event::emit<SupplyLimitUpdated>(SupplyLimitUpdated)
	6: Ret
}

public(friend) emit_liquidation_rule_updated<Ty0>(Arg0: ID, Arg1: TypeName, Arg2: TypeName) {
B0:
	0: MoveLoc[0](Arg0: ID)
	1: Call type_name::get<Ty0>(): TypeName
	2: MoveLoc[1](Arg1: TypeName)
	3: MoveLoc[2](Arg2: TypeName)
	4: Pack[2](LiquidationRuleUpdated)
	5: Call event::emit<LiquidationRuleUpdated>(LiquidationRuleUpdated)
	6: Ret
}

public(friend) emit_position_updated<Ty0>(Arg0: ID, Arg1: address, Arg2: u64, Arg3: u64, Arg4: u64, Arg5: u64, Arg6: u64, Arg7: u64, Arg8: u64, Arg9: String) {
L10:	loc0: ID
L11:	loc1: u64
L12:	loc2: String
L13:	loc3: address
L14:	loc4: TypeName
L15:	loc5: u64
L16:	loc6: u64
L17:	loc7: u64
L18:	loc8: u64
L19:	loc9: u64
L20:	loc10: u64
B0:
	0: MoveLoc[0](Arg0: ID)
	1: StLoc[10](loc0: ID)
	2: MoveLoc[1](Arg1: address)
	3: StLoc[13](loc3: address)
	4: Call type_name::get<Ty0>(): TypeName
	5: StLoc[14](loc4: TypeName)
	6: MoveLoc[2](Arg2: u64)
	7: StLoc[15](loc5: u64)
	8: MoveLoc[3](Arg3: u64)
	9: StLoc[16](loc6: u64)
	10: MoveLoc[4](Arg4: u64)
	11: StLoc[17](loc7: u64)
	12: MoveLoc[5](Arg5: u64)
	13: StLoc[18](loc8: u64)
	14: MoveLoc[6](Arg6: u64)
	15: StLoc[19](loc9: u64)
	16: MoveLoc[7](Arg7: u64)
	17: StLoc[20](loc10: u64)
	18: MoveLoc[8](Arg8: u64)
	19: StLoc[11](loc1: u64)
	20: MoveLoc[9](Arg9: String)
	21: StLoc[12](loc2: String)
	22: MoveLoc[10](loc0: ID)
	23: MoveLoc[14](loc4: TypeName)
	24: MoveLoc[13](loc3: address)
	25: MoveLoc[15](loc5: u64)
	26: MoveLoc[16](loc6: u64)
	27: MoveLoc[18](loc8: u64)
	28: MoveLoc[17](loc7: u64)
	29: MoveLoc[19](loc9: u64)
	30: MoveLoc[20](loc10: u64)
	31: MoveLoc[11](loc1: u64)
	32: MoveLoc[12](loc2: String)
	33: Pack[3](PositionUpdated)
	34: Call event::emit<PositionUpdated>(PositionUpdated)
	35: Ret
}

}
