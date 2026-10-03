// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.min_size_rule {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::point;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::pool;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::profile;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::stake;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000002::linked_table;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;

struct MinSizeRule has drop {
	dummy_field: bool
}

struct Config<phantom Ty0> has store, key {
	id: UID,
	pool_min_sizes: VecMap<ID, u64>
}

err_lower_than_min_size_after_stake() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

err_lower_than_min_size_after_unstake() {
B0:
	0: LdConst[0](u64: 0)
	1: Abort
}

public new_config<Ty0>(Arg0: &AdminCap<Ty0>, Arg1: &mut TxContext): Config<Ty0> {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Call vec_map::empty<ID, u64>(): VecMap<ID, u64>
	3: PackGeneric[0](Config<Ty0>)
	4: Ret
}

public create_config<Ty0>(Arg0: &AdminCap<Ty0>, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap<Ty0>)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call new_config<Ty0>(&AdminCap<Ty0>, &mut TxContext): Config<Ty0>
	3: Call transfer::share_object<Config<Ty0>>(Config<Ty0>)
	4: Ret
}

public set_min_size<Ty0>(Arg0: &mut Config<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: ID, Arg3: u64) {
B0:
	0: CopyLoc[0](Arg0: &mut Config<Ty0>)
	1: FreezeRef
	2: Call pool_min_sizes<Ty0>(&Config<Ty0>): &VecMap<ID, u64>
	3: ImmBorrowLoc[2](Arg2: ID)
	4: Call vec_map::contains<ID, u64>(&VecMap<ID, u64>, &ID): bool
	5: BrFalse(13)
B1:
	6: MoveLoc[3](Arg3: u64)
	7: MoveLoc[0](Arg0: &mut Config<Ty0>)
	8: MutBorrowFieldGeneric[0](Config.pool_min_sizes: VecMap<ID, u64>)
	9: ImmBorrowLoc[2](Arg2: ID)
	10: Call vec_map::get_mut<ID, u64>(&mut VecMap<ID, u64>, &ID): &mut u64
	11: WriteRef
	12: Branch(18)
B2:
	13: MoveLoc[0](Arg0: &mut Config<Ty0>)
	14: MutBorrowFieldGeneric[0](Config.pool_min_sizes: VecMap<ID, u64>)
	15: MoveLoc[2](Arg2: ID)
	16: MoveLoc[3](Arg3: u64)
	17: Call vec_map::insert<ID, u64>(&mut VecMap<ID, u64>, ID, u64)
B3:
	18: Ret
}

public check_stake_response<Ty0>(Arg0: &Config<Ty0>, Arg1: &PointCenter<Ty0>, Arg2: &mut StakeResponse<Ty0>) {
L3:	loc0: address
L4:	loc1: u64
L5:	loc2: u64
L6:	loc3: ID
B0:
	0: CopyLoc[2](Arg2: &mut StakeResponse<Ty0>)
	1: FreezeRef
	2: Call pool::stake_res_data<Ty0>(&StakeResponse<Ty0>): ID * address * u64 * TypeName
	3: Pop
	4: StLoc[4](loc1: u64)
	5: StLoc[3](loc0: address)
	6: StLoc[6](loc3: ID)
	7: MoveLoc[0](Arg0: &Config<Ty0>)
	8: ImmBorrowLoc[6](loc3: ID)
	9: Call min_size_of<Ty0>(&Config<Ty0>, &ID): u64
	10: StLoc[5](loc2: u64)
	11: MoveLoc[1](Arg1: &PointCenter<Ty0>)
	12: MoveLoc[3](loc0: address)
	13: ImmBorrowLoc[6](loc3: ID)
	14: Call current_size<Ty0>(&PointCenter<Ty0>, address, &ID): u64
	15: MoveLoc[4](loc1: u64)
	16: Add
	17: MoveLoc[5](loc2: u64)
	18: Lt
	19: BrFalse(21)
B1:
	20: Call err_lower_than_min_size_after_stake()
B2:
	21: MoveLoc[2](Arg2: &mut StakeResponse<Ty0>)
	22: LdFalse
	23: Pack[0](MinSizeRule)
	24: Call pool::stake_res_add_witness<Ty0, MinSizeRule>(&mut StakeResponse<Ty0>, MinSizeRule)
	25: Ret
}

public check_unstake_response<Ty0>(Arg0: &Config<Ty0>, Arg1: &PointCenter<Ty0>, Arg2: &mut UnstakeResponse<Ty0>) {
L3:	loc0: bool
L4:	loc1: address
L5:	loc2: u64
L6:	loc3: u64
L7:	loc4: u64
L8:	loc5: u64
L9:	loc6: ID
B0:
	0: CopyLoc[2](Arg2: &mut UnstakeResponse<Ty0>)
	1: FreezeRef
	2: Call pool::unstake_res_data<Ty0>(&UnstakeResponse<Ty0>): ID * address * u64 * TypeName
	3: Pop
	4: StLoc[6](loc3: u64)
	5: StLoc[4](loc1: address)
	6: StLoc[9](loc6: ID)
	7: MoveLoc[0](Arg0: &Config<Ty0>)
	8: ImmBorrowLoc[9](loc6: ID)
	9: Call min_size_of<Ty0>(&Config<Ty0>, &ID): u64
	10: StLoc[8](loc5: u64)
	11: MoveLoc[1](Arg1: &PointCenter<Ty0>)
	12: MoveLoc[4](loc1: address)
	13: ImmBorrowLoc[9](loc6: ID)
	14: Call current_size<Ty0>(&PointCenter<Ty0>, address, &ID): u64
	15: StLoc[7](loc4: u64)
	16: CopyLoc[7](loc4: u64)
	17: CopyLoc[6](loc3: u64)
	18: Ge
	19: BrFalse(43)
B1:
	20: MoveLoc[7](loc4: u64)
	21: MoveLoc[6](loc3: u64)
	22: Sub
	23: StLoc[5](loc2: u64)
	24: CopyLoc[5](loc2: u64)
	25: LdU64(0)
	26: Neq
	27: BrFalse(33)
B2:
	28: MoveLoc[5](loc2: u64)
	29: MoveLoc[8](loc5: u64)
	30: Lt
	31: StLoc[3](loc0: bool)
	32: Branch(35)
B3:
	33: LdFalse
	34: StLoc[3](loc0: bool)
B4:
	35: MoveLoc[3](loc0: bool)
	36: BrFalse(38)
B5:
	37: Call err_lower_than_min_size_after_unstake()
B6:
	38: MoveLoc[2](Arg2: &mut UnstakeResponse<Ty0>)
	39: LdFalse
	40: Pack[0](MinSizeRule)
	41: Call pool::unstake_res_add_witness<Ty0, MinSizeRule>(&mut UnstakeResponse<Ty0>, MinSizeRule)
	42: Branch(45)
B7:
	43: MoveLoc[2](Arg2: &mut UnstakeResponse<Ty0>)
	44: Pop
B8:
	45: Ret
}

public current_size<Ty0>(Arg0: &PointCenter<Ty0>, Arg1: address, Arg2: &ID): u64 {
L3:	loc0: bool
L4:	loc1: u64
B0:
	0: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	1: Call point::user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	2: CopyLoc[1](Arg1: address)
	3: Call linked_table::contains<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): bool
	4: BrFalse(14)
B1:
	5: CopyLoc[0](Arg0: &PointCenter<Ty0>)
	6: Call point::user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	7: CopyLoc[1](Arg1: address)
	8: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	9: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	10: CopyLoc[2](Arg2: &ID)
	11: Call vec_map::contains<ID, Stake>(&VecMap<ID, Stake>, &ID): bool
	12: StLoc[3](loc0: bool)
	13: Branch(16)
B2:
	14: LdFalse
	15: StLoc[3](loc0: bool)
B3:
	16: MoveLoc[3](loc0: bool)
	17: BrFalse(28)
B4:
	18: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	19: Call point::user_profiles<Ty0>(&PointCenter<Ty0>): &LinkedTable<address, Profile<Ty0>>
	20: MoveLoc[1](Arg1: address)
	21: Call linked_table::borrow<address, Profile<Ty0>>(&LinkedTable<address, Profile<Ty0>>, address): &Profile<Ty0>
	22: Call profile::stakes<Ty0>(&Profile<Ty0>): &VecMap<ID, Stake>
	23: MoveLoc[2](Arg2: &ID)
	24: Call vec_map::get<ID, Stake>(&VecMap<ID, Stake>, &ID): &Stake
	25: Call stake::amount(&Stake): u64
	26: StLoc[4](loc1: u64)
	27: Branch(34)
B5:
	28: MoveLoc[2](Arg2: &ID)
	29: Pop
	30: MoveLoc[0](Arg0: &PointCenter<Ty0>)
	31: Pop
	32: LdU64(0)
	33: StLoc[4](loc1: u64)
B6:
	34: MoveLoc[4](loc1: u64)
	35: Ret
}

public pool_min_sizes<Ty0>(Arg0: &Config<Ty0>): &VecMap<ID, u64> {
B0:
	0: MoveLoc[0](Arg0: &Config<Ty0>)
	1: ImmBorrowFieldGeneric[0](Config.pool_min_sizes: VecMap<ID, u64>)
	2: Ret
}

public min_size_of<Ty0>(Arg0: &Config<Ty0>, Arg1: &ID): u64 {
L2:	loc0: u64
B0:
	0: CopyLoc[0](Arg0: &Config<Ty0>)
	1: Call pool_min_sizes<Ty0>(&Config<Ty0>): &VecMap<ID, u64>
	2: CopyLoc[1](Arg1: &ID)
	3: Call vec_map::contains<ID, u64>(&VecMap<ID, u64>, &ID): bool
	4: BrFalse(12)
B1:
	5: MoveLoc[0](Arg0: &Config<Ty0>)
	6: Call pool_min_sizes<Ty0>(&Config<Ty0>): &VecMap<ID, u64>
	7: MoveLoc[1](Arg1: &ID)
	8: Call vec_map::get<ID, u64>(&VecMap<ID, u64>, &ID): &u64
	9: ReadRef
	10: StLoc[2](loc0: u64)
	11: Branch(18)
B2:
	12: MoveLoc[1](Arg1: &ID)
	13: Pop
	14: MoveLoc[0](Arg0: &Config<Ty0>)
	15: Pop
	16: LdU64(0)
	17: StLoc[2](loc0: u64)
B3:
	18: MoveLoc[2](loc0: u64)
	19: Ret
}

Constants [
	0 => u64: 0
]
}
