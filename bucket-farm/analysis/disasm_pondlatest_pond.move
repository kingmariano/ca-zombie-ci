// Move bytecode v6
module ad4f4f73dc19dd2e28f380f287201a549215407db46acd7543e89443954d5eba.pond {
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::buck;
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::pipe;
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::strap;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::admin;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::point;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::pool;
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::wrapper;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::account;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive_v2;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive_v3;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::lending;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::logic;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::pool as 0pool;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::storage;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::account as 0account;
use a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8::sheet;
use ca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle;
use 0000000000000000000000000000000000000000000000000000000000000001::ascii;
use 0000000000000000000000000000000000000000000000000000000000000001::option;
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use 0000000000000000000000000000000000000000000000000000000000000001::vector;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::dynamic_field;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;

struct ClaimReward<phantom Ty0> has copy, drop {
	amount: u64
}

struct NAVI_POND has drop {
	dummy_field: bool
}

struct NaviPond has key {
	id: UID,
	navi_cap: AccountCap
}

struct AdminCap has store, key {
	id: UID
}

struct NAVI_UNI_POND has drop {
	dummy_field: bool
}

struct SurplusToCenter<phantom Ty0, phantom Ty1> has copy, drop {
	amount: u64
}

struct SurplusCollectCenter<phantom Ty0, phantom Ty1> has copy, drop {
	amount: u64
}

struct SurplusReceive<phantom Ty0, phantom Ty1, phantom Ty2> has copy, drop {
	amount: u64,
	current_debt: u64
}

struct SurplusRepay<phantom Ty0, phantom Ty1, phantom Ty2> has copy, drop {
	amount: u64,
	current_debt: u64
}

struct NaviReceive<phantom Ty0, phantom Ty1, phantom Ty2> has copy, drop {
	amount: u64,
	current_debt: u64
}

struct NaviRepay<phantom Ty0, phantom Ty1, phantom Ty2> has copy, drop {
	amount: u64,
	current_debt: u64
}

struct CenterPond<phantom Ty0> has key {
	id: UID,
	account: Account,
	navi_cap: AccountCap
}

struct Position<phantom Ty0> has store {
	strap: BottleStrap<Ty0>,
	surplus_sheet: Sheet<NAVI_POND, Ty0>,
	navi_sheet: Sheet<NAVI_UNI_POND, Ty0>
}

struct AccountSheet<phantom Ty0, phantom Ty1> has copy, drop {
	total_debt: u64,
	total_balance: u64
}

init(Arg0: &mut TxContext) {
B0:
	0: CopyLoc[0](Arg0: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: Pack[3](AdminCap)
	3: CopyLoc[0](Arg0: &mut TxContext)
	4: FreezeRef
	5: Call tx_context::sender(&TxContext): address
	6: Call transfer::transfer<AdminCap>(AdminCap, address)
	7: CopyLoc[0](Arg0: &mut TxContext)
	8: Call object::new(&mut TxContext): UID
	9: MoveLoc[0](Arg0: &mut TxContext)
	10: Call lending::create_account(&mut TxContext): AccountCap
	11: Pack[2](NaviPond)
	12: Call transfer::share_object<NaviPond>(NaviPond)
	13: Ret
}

public supply<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &mut Storage, Arg4: &mut Pool<Ty0>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: u64, Arg10: &mut TxContext) {
L11:	loc0: OutputCarrier<Ty0, NAVI_POND>
L12:	loc1: Coin<Ty0>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: MoveLoc[9](Arg9: u64)
	2: Call buck::output<Ty0, NAVI_POND>(&mut BucketProtocol, u64): OutputCarrier<Ty0, NAVI_POND>
	3: StLoc[11](loc0: OutputCarrier<Ty0, NAVI_POND>)
	4: LdFalse
	5: Pack[1](NAVI_POND)
	6: MoveLoc[11](loc0: OutputCarrier<Ty0, NAVI_POND>)
	7: Call pipe::destroy_output_carrier<Ty0, NAVI_POND>(NAVI_POND, OutputCarrier<Ty0, NAVI_POND>): Balance<Ty0>
	8: MoveLoc[10](Arg10: &mut TxContext)
	9: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	10: StLoc[12](loc1: Coin<Ty0>)
	11: MoveLoc[8](Arg8: &Clock)
	12: MoveLoc[3](Arg3: &mut Storage)
	13: MoveLoc[4](Arg4: &mut Pool<Ty0>)
	14: MoveLoc[5](Arg5: u8)
	15: MoveLoc[12](loc1: Coin<Ty0>)
	16: MoveLoc[6](Arg6: &mut Incentive)
	17: MoveLoc[7](Arg7: &mut Incentive)
	18: MoveLoc[1](Arg1: &mut NaviPond)
	19: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	20: Call incentive_v2::deposit_with_account_cap<Ty0>(&Clock, &mut Storage, &mut Pool<Ty0>, u8, Coin<Ty0>, &mut Incentive, &mut Incentive, &AccountCap)
	21: Ret
}

public supply_v3<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &mut Storage, Arg4: &mut Pool<Ty0>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: u64, Arg10: &mut TxContext) {
L11:	loc0: OutputCarrier<Ty0, NAVI_POND>
L12:	loc1: Coin<Ty0>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: MoveLoc[9](Arg9: u64)
	2: Call buck::output<Ty0, NAVI_POND>(&mut BucketProtocol, u64): OutputCarrier<Ty0, NAVI_POND>
	3: StLoc[11](loc0: OutputCarrier<Ty0, NAVI_POND>)
	4: LdFalse
	5: Pack[1](NAVI_POND)
	6: MoveLoc[11](loc0: OutputCarrier<Ty0, NAVI_POND>)
	7: Call pipe::destroy_output_carrier<Ty0, NAVI_POND>(NAVI_POND, OutputCarrier<Ty0, NAVI_POND>): Balance<Ty0>
	8: MoveLoc[10](Arg10: &mut TxContext)
	9: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	10: StLoc[12](loc1: Coin<Ty0>)
	11: MoveLoc[8](Arg8: &Clock)
	12: MoveLoc[3](Arg3: &mut Storage)
	13: MoveLoc[4](Arg4: &mut Pool<Ty0>)
	14: MoveLoc[5](Arg5: u8)
	15: MoveLoc[12](loc1: Coin<Ty0>)
	16: MoveLoc[6](Arg6: &mut Incentive)
	17: MoveLoc[7](Arg7: &mut Incentive)
	18: MoveLoc[1](Arg1: &mut NaviPond)
	19: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	20: Call incentive_v3::deposit_with_account_cap<Ty0>(&Clock, &mut Storage, &mut Pool<Ty0>, u8, Coin<Ty0>, &mut Incentive, &mut Incentive, &AccountCap)
	21: Ret
}

public supply_buck(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &mut Storage, Arg4: &mut Pool<BUCK>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: u64, Arg10: &mut TxContext) {
L11:	loc0: OutputCarrier<BUCK, NAVI_POND>
L12:	loc1: Coin<BUCK>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: MoveLoc[9](Arg9: u64)
	2: Call buck::output_buck<NAVI_POND>(&mut BucketProtocol, u64): OutputCarrier<BUCK, NAVI_POND>
	3: StLoc[11](loc0: OutputCarrier<BUCK, NAVI_POND>)
	4: LdFalse
	5: Pack[1](NAVI_POND)
	6: MoveLoc[11](loc0: OutputCarrier<BUCK, NAVI_POND>)
	7: Call pipe::destroy_output_carrier<BUCK, NAVI_POND>(NAVI_POND, OutputCarrier<BUCK, NAVI_POND>): Balance<BUCK>
	8: MoveLoc[10](Arg10: &mut TxContext)
	9: Call coin::from_balance<BUCK>(Balance<BUCK>, &mut TxContext): Coin<BUCK>
	10: StLoc[12](loc1: Coin<BUCK>)
	11: MoveLoc[8](Arg8: &Clock)
	12: MoveLoc[3](Arg3: &mut Storage)
	13: MoveLoc[4](Arg4: &mut Pool<BUCK>)
	14: MoveLoc[5](Arg5: u8)
	15: MoveLoc[12](loc1: Coin<BUCK>)
	16: MoveLoc[6](Arg6: &mut Incentive)
	17: MoveLoc[7](Arg7: &mut Incentive)
	18: MoveLoc[1](Arg1: &mut NaviPond)
	19: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	20: Call incentive_v2::deposit_with_account_cap<BUCK>(&Clock, &mut Storage, &mut Pool<BUCK>, u8, Coin<BUCK>, &mut Incentive, &mut Incentive, &AccountCap)
	21: Ret
}

public supply_buck_v3(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &mut Storage, Arg4: &mut Pool<BUCK>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: u64, Arg10: &mut TxContext) {
L11:	loc0: OutputCarrier<BUCK, NAVI_POND>
L12:	loc1: Coin<BUCK>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: MoveLoc[9](Arg9: u64)
	2: Call buck::output_buck<NAVI_POND>(&mut BucketProtocol, u64): OutputCarrier<BUCK, NAVI_POND>
	3: StLoc[11](loc0: OutputCarrier<BUCK, NAVI_POND>)
	4: LdFalse
	5: Pack[1](NAVI_POND)
	6: MoveLoc[11](loc0: OutputCarrier<BUCK, NAVI_POND>)
	7: Call pipe::destroy_output_carrier<BUCK, NAVI_POND>(NAVI_POND, OutputCarrier<BUCK, NAVI_POND>): Balance<BUCK>
	8: MoveLoc[10](Arg10: &mut TxContext)
	9: Call coin::from_balance<BUCK>(Balance<BUCK>, &mut TxContext): Coin<BUCK>
	10: StLoc[12](loc1: Coin<BUCK>)
	11: MoveLoc[8](Arg8: &Clock)
	12: MoveLoc[3](Arg3: &mut Storage)
	13: MoveLoc[4](Arg4: &mut Pool<BUCK>)
	14: MoveLoc[5](Arg5: u8)
	15: MoveLoc[12](loc1: Coin<BUCK>)
	16: MoveLoc[6](Arg6: &mut Incentive)
	17: MoveLoc[7](Arg7: &mut Incentive)
	18: MoveLoc[1](Arg1: &mut NaviPond)
	19: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	20: Call incentive_v3::deposit_with_account_cap<BUCK>(&Clock, &mut Storage, &mut Pool<BUCK>, u8, Coin<BUCK>, &mut Incentive, &mut Incentive, &AccountCap)
	21: Ret
}

public withdraw<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: u64) {
L11:	loc0: InputCarrier<Ty0, NAVI_POND>
L12:	loc1: Balance<Ty0>
B0:
	0: MoveLoc[9](Arg9: &Clock)
	1: MoveLoc[3](Arg3: &PriceOracle)
	2: MoveLoc[4](Arg4: &mut Storage)
	3: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	4: MoveLoc[6](Arg6: u8)
	5: MoveLoc[10](Arg10: u64)
	6: MoveLoc[7](Arg7: &mut Incentive)
	7: MoveLoc[8](Arg8: &mut Incentive)
	8: MoveLoc[1](Arg1: &mut NaviPond)
	9: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	10: Call incentive_v2::withdraw_with_account_cap<Ty0>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty0>
	11: StLoc[12](loc1: Balance<Ty0>)
	12: LdFalse
	13: Pack[1](NAVI_POND)
	14: MoveLoc[12](loc1: Balance<Ty0>)
	15: Call pipe::input<Ty0, NAVI_POND>(NAVI_POND, Balance<Ty0>): InputCarrier<Ty0, NAVI_POND>
	16: StLoc[11](loc0: InputCarrier<Ty0, NAVI_POND>)
	17: MoveLoc[2](Arg2: &mut BucketProtocol)
	18: MoveLoc[11](loc0: InputCarrier<Ty0, NAVI_POND>)
	19: Call buck::input<Ty0, NAVI_POND>(&mut BucketProtocol, InputCarrier<Ty0, NAVI_POND>)
	20: Ret
}

public withdraw_v3<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: u64) {
L11:	loc0: InputCarrier<Ty0, NAVI_POND>
L12:	loc1: Balance<Ty0>
B0:
	0: MoveLoc[9](Arg9: &Clock)
	1: MoveLoc[3](Arg3: &PriceOracle)
	2: MoveLoc[4](Arg4: &mut Storage)
	3: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	4: MoveLoc[6](Arg6: u8)
	5: MoveLoc[10](Arg10: u64)
	6: MoveLoc[7](Arg7: &mut Incentive)
	7: MoveLoc[8](Arg8: &mut Incentive)
	8: MoveLoc[1](Arg1: &mut NaviPond)
	9: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	10: Call incentive_v3::withdraw_with_account_cap<Ty0>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty0>
	11: StLoc[12](loc1: Balance<Ty0>)
	12: LdFalse
	13: Pack[1](NAVI_POND)
	14: MoveLoc[12](loc1: Balance<Ty0>)
	15: Call pipe::input<Ty0, NAVI_POND>(NAVI_POND, Balance<Ty0>): InputCarrier<Ty0, NAVI_POND>
	16: StLoc[11](loc0: InputCarrier<Ty0, NAVI_POND>)
	17: MoveLoc[2](Arg2: &mut BucketProtocol)
	18: MoveLoc[11](loc0: InputCarrier<Ty0, NAVI_POND>)
	19: Call buck::input<Ty0, NAVI_POND>(&mut BucketProtocol, InputCarrier<Ty0, NAVI_POND>)
	20: Ret
}

public withdraw_buck(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<BUCK>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: u64) {
L11:	loc0: InputCarrier<BUCK, NAVI_POND>
L12:	loc1: Balance<BUCK>
B0:
	0: MoveLoc[9](Arg9: &Clock)
	1: MoveLoc[3](Arg3: &PriceOracle)
	2: MoveLoc[4](Arg4: &mut Storage)
	3: MoveLoc[5](Arg5: &mut Pool<BUCK>)
	4: MoveLoc[6](Arg6: u8)
	5: MoveLoc[10](Arg10: u64)
	6: MoveLoc[7](Arg7: &mut Incentive)
	7: MoveLoc[8](Arg8: &mut Incentive)
	8: MoveLoc[1](Arg1: &mut NaviPond)
	9: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	10: Call incentive_v2::withdraw_with_account_cap<BUCK>(&Clock, &PriceOracle, &mut Storage, &mut Pool<BUCK>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<BUCK>
	11: StLoc[12](loc1: Balance<BUCK>)
	12: LdFalse
	13: Pack[1](NAVI_POND)
	14: MoveLoc[12](loc1: Balance<BUCK>)
	15: Call pipe::input<BUCK, NAVI_POND>(NAVI_POND, Balance<BUCK>): InputCarrier<BUCK, NAVI_POND>
	16: StLoc[11](loc0: InputCarrier<BUCK, NAVI_POND>)
	17: MoveLoc[2](Arg2: &mut BucketProtocol)
	18: MoveLoc[11](loc0: InputCarrier<BUCK, NAVI_POND>)
	19: Call buck::input_buck<NAVI_POND>(&mut BucketProtocol, InputCarrier<BUCK, NAVI_POND>)
	20: Ret
}

public withdraw_buck_v3(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<BUCK>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: u64) {
L11:	loc0: InputCarrier<BUCK, NAVI_POND>
L12:	loc1: Balance<BUCK>
B0:
	0: MoveLoc[9](Arg9: &Clock)
	1: MoveLoc[3](Arg3: &PriceOracle)
	2: MoveLoc[4](Arg4: &mut Storage)
	3: MoveLoc[5](Arg5: &mut Pool<BUCK>)
	4: MoveLoc[6](Arg6: u8)
	5: MoveLoc[10](Arg10: u64)
	6: MoveLoc[7](Arg7: &mut Incentive)
	7: MoveLoc[8](Arg8: &mut Incentive)
	8: MoveLoc[1](Arg1: &mut NaviPond)
	9: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	10: Call incentive_v3::withdraw_with_account_cap<BUCK>(&Clock, &PriceOracle, &mut Storage, &mut Pool<BUCK>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<BUCK>
	11: StLoc[12](loc1: Balance<BUCK>)
	12: LdFalse
	13: Pack[1](NAVI_POND)
	14: MoveLoc[12](loc1: Balance<BUCK>)
	15: Call pipe::input<BUCK, NAVI_POND>(NAVI_POND, Balance<BUCK>): InputCarrier<BUCK, NAVI_POND>
	16: StLoc[11](loc0: InputCarrier<BUCK, NAVI_POND>)
	17: MoveLoc[2](Arg2: &mut BucketProtocol)
	18: MoveLoc[11](loc0: InputCarrier<BUCK, NAVI_POND>)
	19: Call buck::input_buck<NAVI_POND>(&mut BucketProtocol, InputCarrier<BUCK, NAVI_POND>)
	20: Ret
}

public claim<Ty0>(Arg0: &AdminCap, Arg1: &NaviPond, Arg2: &BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: &mut TxContext): Coin<Ty0> {
L11:	loc0: ID
L12:	loc1: address
L13:	loc2: u64
L14:	loc3: u64
B0:
	0: MoveLoc[2](Arg2: &BucketProtocol)
	1: Call buck::borrow_pipe<Ty0, NAVI_POND>(&BucketProtocol): &Pipe<Ty0, NAVI_POND>
	2: Call pipe::output_volume<Ty0, NAVI_POND>(&Pipe<Ty0, NAVI_POND>): u64
	3: StLoc[14](loc3: u64)
	4: CopyLoc[1](Arg1: &NaviPond)
	5: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	6: Call object::id<AccountCap>(&AccountCap): ID
	7: StLoc[11](loc0: ID)
	8: ImmBorrowLoc[11](loc0: ID)
	9: Call object::id_to_address(&ID): address
	10: StLoc[12](loc1: address)
	11: CopyLoc[4](Arg4: &mut Storage)
	12: CopyLoc[6](Arg6: u8)
	13: MoveLoc[12](loc1: address)
	14: Call logic::user_collateral_balance(&mut Storage, u8, address): u256
	15: CastU64
	16: MoveLoc[14](loc3: u64)
	17: Sub
	18: StLoc[13](loc2: u64)
	19: CopyLoc[13](loc2: u64)
	20: PackGeneric[0](ClaimReward<Ty0>)
	21: Call event::emit<ClaimReward<Ty0>>(ClaimReward<Ty0>)
	22: MoveLoc[9](Arg9: &Clock)
	23: MoveLoc[3](Arg3: &PriceOracle)
	24: MoveLoc[4](Arg4: &mut Storage)
	25: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	26: MoveLoc[6](Arg6: u8)
	27: MoveLoc[13](loc2: u64)
	28: MoveLoc[7](Arg7: &mut Incentive)
	29: MoveLoc[8](Arg8: &mut Incentive)
	30: MoveLoc[1](Arg1: &NaviPond)
	31: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	32: Call incentive_v2::withdraw_with_account_cap<Ty0>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty0>
	33: MoveLoc[10](Arg10: &mut TxContext)
	34: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	35: Ret
}

public claim_v3<Ty0>(Arg0: &AdminCap, Arg1: &NaviPond, Arg2: &BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: &mut TxContext): Coin<Ty0> {
L11:	loc0: ID
L12:	loc1: address
L13:	loc2: u64
L14:	loc3: u64
B0:
	0: MoveLoc[2](Arg2: &BucketProtocol)
	1: Call buck::borrow_pipe<Ty0, NAVI_POND>(&BucketProtocol): &Pipe<Ty0, NAVI_POND>
	2: Call pipe::output_volume<Ty0, NAVI_POND>(&Pipe<Ty0, NAVI_POND>): u64
	3: StLoc[14](loc3: u64)
	4: CopyLoc[1](Arg1: &NaviPond)
	5: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	6: Call object::id<AccountCap>(&AccountCap): ID
	7: StLoc[11](loc0: ID)
	8: ImmBorrowLoc[11](loc0: ID)
	9: Call object::id_to_address(&ID): address
	10: StLoc[12](loc1: address)
	11: CopyLoc[4](Arg4: &mut Storage)
	12: CopyLoc[6](Arg6: u8)
	13: MoveLoc[12](loc1: address)
	14: Call logic::user_collateral_balance(&mut Storage, u8, address): u256
	15: CastU64
	16: MoveLoc[14](loc3: u64)
	17: Sub
	18: StLoc[13](loc2: u64)
	19: CopyLoc[13](loc2: u64)
	20: PackGeneric[0](ClaimReward<Ty0>)
	21: Call event::emit<ClaimReward<Ty0>>(ClaimReward<Ty0>)
	22: MoveLoc[9](Arg9: &Clock)
	23: MoveLoc[3](Arg3: &PriceOracle)
	24: MoveLoc[4](Arg4: &mut Storage)
	25: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	26: MoveLoc[6](Arg6: u8)
	27: MoveLoc[13](loc2: u64)
	28: MoveLoc[7](Arg7: &mut Incentive)
	29: MoveLoc[8](Arg8: &mut Incentive)
	30: MoveLoc[1](Arg1: &NaviPond)
	31: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	32: Call incentive_v3::withdraw_with_account_cap<Ty0>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty0>
	33: MoveLoc[10](Arg10: &mut TxContext)
	34: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	35: Ret
}

entry claim_to<Ty0>(Arg0: &AdminCap, Arg1: &NaviPond, Arg2: &BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: address, Arg11: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &NaviPond)
	2: MoveLoc[2](Arg2: &BucketProtocol)
	3: MoveLoc[3](Arg3: &PriceOracle)
	4: MoveLoc[4](Arg4: &mut Storage)
	5: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	6: MoveLoc[6](Arg6: u8)
	7: MoveLoc[7](Arg7: &mut Incentive)
	8: MoveLoc[8](Arg8: &mut Incentive)
	9: MoveLoc[9](Arg9: &Clock)
	10: MoveLoc[11](Arg11: &mut TxContext)
	11: Call claim<Ty0>(&AdminCap, &NaviPond, &BucketProtocol, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, &mut Incentive, &mut Incentive, &Clock, &mut TxContext): Coin<Ty0>
	12: MoveLoc[10](Arg10: address)
	13: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	14: Ret
}

entry claim_to_v3<Ty0>(Arg0: &AdminCap, Arg1: &NaviPond, Arg2: &BucketProtocol, Arg3: &PriceOracle, Arg4: &mut Storage, Arg5: &mut Pool<Ty0>, Arg6: u8, Arg7: &mut Incentive, Arg8: &mut Incentive, Arg9: &Clock, Arg10: address, Arg11: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &NaviPond)
	2: MoveLoc[2](Arg2: &BucketProtocol)
	3: MoveLoc[3](Arg3: &PriceOracle)
	4: MoveLoc[4](Arg4: &mut Storage)
	5: MoveLoc[5](Arg5: &mut Pool<Ty0>)
	6: MoveLoc[6](Arg6: u8)
	7: MoveLoc[7](Arg7: &mut Incentive)
	8: MoveLoc[8](Arg8: &mut Incentive)
	9: MoveLoc[9](Arg9: &Clock)
	10: MoveLoc[11](Arg11: &mut TxContext)
	11: Call claim_v3<Ty0>(&AdminCap, &NaviPond, &BucketProtocol, &PriceOracle, &mut Storage, &mut Pool<Ty0>, u8, &mut Incentive, &mut Incentive, &Clock, &mut TxContext): Coin<Ty0>
	12: MoveLoc[10](Arg10: address)
	13: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	14: Ret
}

public claim_reward<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut Storage, Arg3: &mut IncentiveFundsPool<Ty0>, Arg4: u8, Arg5: u8, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut TxContext): Coin<Ty0> {
L9:	loc0: Balance<Ty0>
B0:
	0: MoveLoc[7](Arg7: &Clock)
	1: MoveLoc[6](Arg6: &mut Incentive)
	2: MoveLoc[3](Arg3: &mut IncentiveFundsPool<Ty0>)
	3: MoveLoc[2](Arg2: &mut Storage)
	4: MoveLoc[4](Arg4: u8)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[1](Arg1: &mut NaviPond)
	7: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	8: Call incentive_v2::claim_reward_with_account_cap<Ty0>(&Clock, &mut Incentive, &mut IncentiveFundsPool<Ty0>, &mut Storage, u8, u8, &AccountCap): Balance<Ty0>
	9: StLoc[9](loc0: Balance<Ty0>)
	10: ImmBorrowLoc[9](loc0: Balance<Ty0>)
	11: Call balance::value<Ty0>(&Balance<Ty0>): u64
	12: PackGeneric[0](ClaimReward<Ty0>)
	13: Call event::emit<ClaimReward<Ty0>>(ClaimReward<Ty0>)
	14: MoveLoc[9](loc0: Balance<Ty0>)
	15: MoveLoc[8](Arg8: &mut TxContext)
	16: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	17: Ret
}

public claim_reward_v3<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut Storage, Arg3: &mut RewardFund<Ty0>, Arg4: vector<String>, Arg5: vector<address>, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut TxContext): Coin<Ty0> {
L9:	loc0: Balance<Ty0>
B0:
	0: MoveLoc[7](Arg7: &Clock)
	1: MoveLoc[6](Arg6: &mut Incentive)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut RewardFund<Ty0>)
	4: MoveLoc[4](Arg4: vector<String>)
	5: MoveLoc[5](Arg5: vector<address>)
	6: MoveLoc[1](Arg1: &mut NaviPond)
	7: ImmBorrowField[0](NaviPond.navi_cap: AccountCap)
	8: Call incentive_v3::claim_reward_with_account_cap<Ty0>(&Clock, &mut Incentive, &mut Storage, &mut RewardFund<Ty0>, vector<String>, vector<address>, &AccountCap): Balance<Ty0>
	9: StLoc[9](loc0: Balance<Ty0>)
	10: ImmBorrowLoc[9](loc0: Balance<Ty0>)
	11: Call balance::value<Ty0>(&Balance<Ty0>): u64
	12: PackGeneric[0](ClaimReward<Ty0>)
	13: Call event::emit<ClaimReward<Ty0>>(ClaimReward<Ty0>)
	14: MoveLoc[9](loc0: Balance<Ty0>)
	15: MoveLoc[8](Arg8: &mut TxContext)
	16: Call coin::from_balance<Ty0>(Balance<Ty0>, &mut TxContext): Coin<Ty0>
	17: Ret
}

entry claim_reward_to<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut Storage, Arg3: &mut IncentiveFundsPool<Ty0>, Arg4: u8, Arg5: u8, Arg6: &mut Incentive, Arg7: &Clock, Arg8: address, Arg9: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &mut NaviPond)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut IncentiveFundsPool<Ty0>)
	4: MoveLoc[4](Arg4: u8)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &Clock)
	8: MoveLoc[9](Arg9: &mut TxContext)
	9: Call claim_reward<Ty0>(&AdminCap, &mut NaviPond, &mut Storage, &mut IncentiveFundsPool<Ty0>, u8, u8, &mut Incentive, &Clock, &mut TxContext): Coin<Ty0>
	10: MoveLoc[8](Arg8: address)
	11: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	12: Ret
}

public claim_reward_to_v3<Ty0>(Arg0: &AdminCap, Arg1: &mut NaviPond, Arg2: &mut Storage, Arg3: &mut RewardFund<Ty0>, Arg4: vector<String>, Arg5: vector<address>, Arg6: &mut Incentive, Arg7: &Clock, Arg8: address, Arg9: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &mut NaviPond)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut RewardFund<Ty0>)
	4: MoveLoc[4](Arg4: vector<String>)
	5: MoveLoc[5](Arg5: vector<address>)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &Clock)
	8: MoveLoc[9](Arg9: &mut TxContext)
	9: Call claim_reward_v3<Ty0>(&AdminCap, &mut NaviPond, &mut Storage, &mut RewardFund<Ty0>, vector<String>, vector<address>, &mut Incentive, &Clock, &mut TxContext): Coin<Ty0>
	10: MoveLoc[8](Arg8: address)
	11: Call transfer::public_transfer<Coin<Ty0>>(Coin<Ty0>, address)
	12: Ret
}

err_unsupported_asset() {
B0:
	0: LdConst[0](u64: 1)
	1: Abort
}

public create_center<Ty0>(Arg0: &AdminCap, Arg1: &mut TxContext) {
L2:	loc0: String
B0:
	0: LdConst[1](vector<u8>: "Cen..)
	1: Call string::utf8(vector<u8>): String
	2: StLoc[2](loc0: String)
	3: CopyLoc[1](Arg1: &mut TxContext)
	4: Call object::new(&mut TxContext): UID
	5: MoveLoc[2](loc0: String)
	6: CopyLoc[1](Arg1: &mut TxContext)
	7: Call 0account::new(String, &mut TxContext): Account
	8: MoveLoc[1](Arg1: &mut TxContext)
	9: Call lending::create_account(&mut TxContext): AccountCap
	10: PackGeneric[1](CenterPond<Ty0>)
	11: Call transfer::share_object<CenterPond<Ty0>>(CenterPond<Ty0>)
	12: Ret
}

public add_bucket_position<Ty0, Ty1>(Arg0: &mut CenterPond<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &mut TxContext) {
L3:	loc0: Sheet<NAVI_UNI_POND, Ty1>
L4:	loc1: Position<Ty1>
L5:	loc2: BottleStrap<Ty1>
L6:	loc3: Sheet<NAVI_POND, Ty1>
B0:
	0: MoveLoc[2](Arg2: &mut TxContext)
	1: Call strap::new<Ty1>(&mut TxContext): BottleStrap<Ty1>
	2: StLoc[5](loc2: BottleStrap<Ty1>)
	3: Call stamp(): NAVI_POND
	4: Call sheet::new<NAVI_POND, Ty1>(NAVI_POND): Sheet<NAVI_POND, Ty1>
	5: StLoc[6](loc3: Sheet<NAVI_POND, Ty1>)
	6: Call uni_stamp(): NAVI_UNI_POND
	7: Call sheet::new<NAVI_UNI_POND, Ty1>(NAVI_UNI_POND): Sheet<NAVI_UNI_POND, Ty1>
	8: StLoc[3](loc0: Sheet<NAVI_UNI_POND, Ty1>)
	9: MoveLoc[5](loc2: BottleStrap<Ty1>)
	10: MoveLoc[6](loc3: Sheet<NAVI_POND, Ty1>)
	11: MoveLoc[3](loc0: Sheet<NAVI_UNI_POND, Ty1>)
	12: PackGeneric[2](Position<Ty1>)
	13: StLoc[4](loc1: Position<Ty1>)
	14: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	15: MutBorrowFieldGeneric[0](CenterPond.id: UID)
	16: Call type_name::with_defining_ids<Ty1>(): TypeName
	17: MoveLoc[4](loc1: Position<Ty1>)
	18: Call dynamic_field::add<TypeName, Position<Ty1>>(&mut UID, TypeName, Position<Ty1>)
	19: Ret
}

public deposit_to_center<Ty0, Ty1>(Arg0: &mut CenterPond<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &mut BucketProtocol, Arg3: &mut PointCenter<Ty0>, Arg4: &mut DegenPool<Ty0, Ty1>, Arg5: &Clock, Arg6: u64, Arg7: &mut TxContext) {
L8:	loc0: OutputCarrier<Ty1, NAVI_POND>
L9:	loc1: Balance<Ty1>
L10:	loc2: Coin<Ty1>
L11:	loc3: u64
L12:	loc4: AccountRequest
L13:	loc5: StakeResponse<Ty0>
L14:	loc6: StakeRequestWrapper<Ty0, Ty1>
B0:
	0: MoveLoc[2](Arg2: &mut BucketProtocol)
	1: CopyLoc[6](Arg6: u64)
	2: Call buck::output<Ty1, NAVI_POND>(&mut BucketProtocol, u64): OutputCarrier<Ty1, NAVI_POND>
	3: StLoc[8](loc0: OutputCarrier<Ty1, NAVI_POND>)
	4: Call stamp(): NAVI_POND
	5: MoveLoc[8](loc0: OutputCarrier<Ty1, NAVI_POND>)
	6: Call pipe::destroy_output_carrier<Ty1, NAVI_POND>(NAVI_POND, OutputCarrier<Ty1, NAVI_POND>): Balance<Ty1>
	7: StLoc[9](loc1: Balance<Ty1>)
	8: ImmBorrowLoc[9](loc1: Balance<Ty1>)
	9: Call balance::value<Ty1>(&Balance<Ty1>): u64
	10: StLoc[11](loc3: u64)
	11: MoveLoc[9](loc1: Balance<Ty1>)
	12: MoveLoc[7](Arg7: &mut TxContext)
	13: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	14: StLoc[10](loc2: Coin<Ty1>)
	15: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	16: ImmBorrowFieldGeneric[1](CenterPond.account: Account)
	17: Call 0account::request_with_account(&Account): AccountRequest
	18: StLoc[12](loc4: AccountRequest)
	19: CopyLoc[4](Arg4: &mut DegenPool<Ty0, Ty1>)
	20: FreezeRef
	21: MoveLoc[12](loc4: AccountRequest)
	22: MoveLoc[6](Arg6: u64)
	23: Call pool::request_stake<Ty0, Ty1>(&DegenPool<Ty0, Ty1>, AccountRequest, u64): StakeRequest<Ty0>
	24: Call wrapper::wrap_stake_request<Ty0, Ty1>(StakeRequest<Ty0>): StakeRequestWrapper<Ty0, Ty1>
	25: StLoc[14](loc6: StakeRequestWrapper<Ty0, Ty1>)
	26: MoveLoc[4](Arg4: &mut DegenPool<Ty0, Ty1>)
	27: MoveLoc[14](loc6: StakeRequestWrapper<Ty0, Ty1>)
	28: MoveLoc[10](loc2: Coin<Ty1>)
	29: Call wrapper::fulfill_stake<Ty0, Ty1>(&mut DegenPool<Ty0, Ty1>, StakeRequestWrapper<Ty0, Ty1>, Coin<Ty1>): StakeResponse<Ty0>
	30: StLoc[13](loc5: StakeResponse<Ty0>)
	31: MoveLoc[3](Arg3: &mut PointCenter<Ty0>)
	32: MoveLoc[5](Arg5: &Clock)
	33: MoveLoc[13](loc5: StakeResponse<Ty0>)
	34: Call point::fulfill_stake<Ty0>(&mut PointCenter<Ty0>, &Clock, StakeResponse<Ty0>)
	35: MoveLoc[11](loc3: u64)
	36: PackGeneric[3](SurplusToCenter<Ty0, Ty1>)
	37: Call event::emit<SurplusToCenter<Ty0, Ty1>>(SurplusToCenter<Ty0, Ty1>)
	38: Ret
}

public withdraw_from_center<Ty0, Ty1>(Arg0: &mut CenterPond<Ty0>, Arg1: &AdminCap<Ty0>, Arg2: &mut BucketProtocol, Arg3: &mut PointCenter<Ty0>, Arg4: &mut DegenPool<Ty0, Ty1>, Arg5: &Clock, Arg6: u64, Arg7: &mut TxContext) {
L8:	loc0: InputCarrier<Ty1, NAVI_POND>
L9:	loc1: Coin<Ty1>
L10:	loc2: u64
L11:	loc3: AccountRequest
L12:	loc4: UnstakeResponse<Ty0>
L13:	loc5: UnstakeRequestWrapper<Ty0, Ty1>
B0:
	0: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	1: ImmBorrowFieldGeneric[1](CenterPond.account: Account)
	2: Call 0account::request_with_account(&Account): AccountRequest
	3: StLoc[11](loc3: AccountRequest)
	4: CopyLoc[4](Arg4: &mut DegenPool<Ty0, Ty1>)
	5: FreezeRef
	6: MoveLoc[11](loc3: AccountRequest)
	7: MoveLoc[6](Arg6: u64)
	8: Call pool::request_unstake<Ty0, Ty1>(&DegenPool<Ty0, Ty1>, AccountRequest, u64): UnstakeRequest<Ty0>
	9: Call wrapper::wrap_unstake_request<Ty0, Ty1>(UnstakeRequest<Ty0>): UnstakeRequestWrapper<Ty0, Ty1>
	10: StLoc[13](loc5: UnstakeRequestWrapper<Ty0, Ty1>)
	11: MoveLoc[4](Arg4: &mut DegenPool<Ty0, Ty1>)
	12: MoveLoc[13](loc5: UnstakeRequestWrapper<Ty0, Ty1>)
	13: MoveLoc[7](Arg7: &mut TxContext)
	14: Call wrapper::fulfill_unstake<Ty0, Ty1>(&mut DegenPool<Ty0, Ty1>, UnstakeRequestWrapper<Ty0, Ty1>, &mut TxContext): Coin<Ty1> * UnstakeResponse<Ty0>
	15: StLoc[12](loc4: UnstakeResponse<Ty0>)
	16: StLoc[9](loc1: Coin<Ty1>)
	17: ImmBorrowLoc[9](loc1: Coin<Ty1>)
	18: Call coin::value<Ty1>(&Coin<Ty1>): u64
	19: StLoc[10](loc2: u64)
	20: Call stamp(): NAVI_POND
	21: MoveLoc[9](loc1: Coin<Ty1>)
	22: Call coin::into_balance<Ty1>(Coin<Ty1>): Balance<Ty1>
	23: Call pipe::input<Ty1, NAVI_POND>(NAVI_POND, Balance<Ty1>): InputCarrier<Ty1, NAVI_POND>
	24: StLoc[8](loc0: InputCarrier<Ty1, NAVI_POND>)
	25: MoveLoc[2](Arg2: &mut BucketProtocol)
	26: MoveLoc[8](loc0: InputCarrier<Ty1, NAVI_POND>)
	27: Call buck::input<Ty1, NAVI_POND>(&mut BucketProtocol, InputCarrier<Ty1, NAVI_POND>)
	28: MoveLoc[3](Arg3: &mut PointCenter<Ty0>)
	29: MoveLoc[5](Arg5: &Clock)
	30: MoveLoc[12](loc4: UnstakeResponse<Ty0>)
	31: Call point::fulfill_unstake<Ty0>(&mut PointCenter<Ty0>, &Clock, UnstakeResponse<Ty0>)
	32: MoveLoc[10](loc2: u64)
	33: PackGeneric[4](SurplusCollectCenter<Ty0, Ty1>)
	34: Call event::emit<SurplusCollectCenter<Ty0, Ty1>>(SurplusCollectCenter<Ty0, Ty1>)
	35: Ret
}

public add_creditor<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &AdminCap<Ty0>) {
B0:
	0: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	1: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	2: MutBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	3: Call stamp(): NAVI_POND
	4: Call sheet::add_creditor<NAVI_POND, Ty1, Ty2>(&mut Sheet<NAVI_POND, Ty1>, NAVI_POND)
	5: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	6: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	7: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	8: Call uni_stamp(): NAVI_UNI_POND
	9: Call sheet::add_creditor<NAVI_UNI_POND, Ty1, Ty2>(&mut Sheet<NAVI_UNI_POND, Ty1>, NAVI_UNI_POND)
	10: Ret
}

public add_debtor<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &AdminCap<Ty0>) {
B0:
	0: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	1: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	2: MutBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	3: Call stamp(): NAVI_POND
	4: Call sheet::add_debtor<NAVI_POND, Ty1, Ty2>(&mut Sheet<NAVI_POND, Ty1>, NAVI_POND)
	5: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	6: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	7: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	8: Call uni_stamp(): NAVI_UNI_POND
	9: Call sheet::add_debtor<NAVI_UNI_POND, Ty1, Ty2>(&mut Sheet<NAVI_UNI_POND, Ty1>, NAVI_UNI_POND)
	10: Ret
}

public account_request<Ty0>(Arg0: &CenterPond<Ty0>, Arg1: &AdminCap<Ty0>): AccountRequest {
B0:
	0: MoveLoc[0](Arg0: &CenterPond<Ty0>)
	1: ImmBorrowFieldGeneric[1](CenterPond.account: Account)
	2: Call 0account::request_with_account(&Account): AccountRequest
	3: Ret
}

public claim_center_reward<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: &mut Storage, Arg3: &mut IncentiveFundsPool<Ty1>, Arg4: u8, Arg5: u8, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut TxContext): Coin<Ty1> {
L9:	loc0: Balance<Ty1>
B0:
	0: MoveLoc[7](Arg7: &Clock)
	1: MoveLoc[6](Arg6: &mut Incentive)
	2: MoveLoc[3](Arg3: &mut IncentiveFundsPool<Ty1>)
	3: MoveLoc[2](Arg2: &mut Storage)
	4: MoveLoc[4](Arg4: u8)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	7: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	8: Call incentive_v2::claim_reward_with_account_cap<Ty1>(&Clock, &mut Incentive, &mut IncentiveFundsPool<Ty1>, &mut Storage, u8, u8, &AccountCap): Balance<Ty1>
	9: StLoc[9](loc0: Balance<Ty1>)
	10: ImmBorrowLoc[9](loc0: Balance<Ty1>)
	11: Call balance::value<Ty1>(&Balance<Ty1>): u64
	12: PackGeneric[5](ClaimReward<Ty1>)
	13: Call event::emit<ClaimReward<Ty1>>(ClaimReward<Ty1>)
	14: MoveLoc[9](loc0: Balance<Ty1>)
	15: MoveLoc[8](Arg8: &mut TxContext)
	16: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	17: Ret
}

public claim_center_reward_v3<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: &mut Storage, Arg3: &mut RewardFund<Ty1>, Arg4: vector<String>, Arg5: vector<address>, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut TxContext): Coin<Ty1> {
L9:	loc0: Balance<Ty1>
B0:
	0: MoveLoc[7](Arg7: &Clock)
	1: MoveLoc[6](Arg6: &mut Incentive)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut RewardFund<Ty1>)
	4: MoveLoc[4](Arg4: vector<String>)
	5: MoveLoc[5](Arg5: vector<address>)
	6: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	7: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	8: Call incentive_v3::claim_reward_with_account_cap<Ty1>(&Clock, &mut Incentive, &mut Storage, &mut RewardFund<Ty1>, vector<String>, vector<address>, &AccountCap): Balance<Ty1>
	9: StLoc[9](loc0: Balance<Ty1>)
	10: ImmBorrowLoc[9](loc0: Balance<Ty1>)
	11: Call balance::value<Ty1>(&Balance<Ty1>): u64
	12: PackGeneric[5](ClaimReward<Ty1>)
	13: Call event::emit<ClaimReward<Ty1>>(ClaimReward<Ty1>)
	14: MoveLoc[9](loc0: Balance<Ty1>)
	15: MoveLoc[8](Arg8: &mut TxContext)
	16: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	17: Ret
}

public claim_center_interest<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &CenterPond<Ty0>, Arg2: &PriceOracle, Arg3: &mut Storage, Arg4: &mut Pool<Ty1>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: &mut TxContext): Coin<Ty1> {
L10:	loc0: u64
L11:	loc1: u64
L12:	loc2: vector<Creditor>
L13:	loc3: u64
L14:	loc4: &mut vector<u64>
L15:	loc5: ID
L16:	loc6: u64
L17:	loc7: address
L18:	loc8: u64
L19:	loc9: &Creditor
L20:	loc10: u64
L21:	loc11: &Creditor
L22:	loc12: u64
L23:	loc13: u64
L24:	loc14: u64
L25:	loc15: u64
L26:	loc16: vector<u64>
L27:	loc17: u64
L28:	loc18: u64
L29:	loc19: u64
L30:	loc20: u64
L31:	loc21: &vector<Creditor>
L32:	loc22: vector<u64>
L33:	loc23: vector<u64>
L34:	loc24: &vector<Creditor>
B0:
	0: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	1: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	2: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	3: Call vec_map::keys<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>): vector<Creditor>
	4: StLoc[12](loc2: vector<Creditor>)
	5: ImmBorrowLoc[12](loc2: vector<Creditor>)
	6: StLoc[31](loc21: &vector<Creditor>)
	7: LdConst[2](vector<u64>: 00)
	8: StLoc[26](loc16: vector<u64>)
	9: MoveLoc[31](loc21: &vector<Creditor>)
	10: StLoc[34](loc24: &vector<Creditor>)
	11: CopyLoc[34](loc24: &vector<Creditor>)
	12: VecLen(137)
	13: StLoc[11](loc1: u64)
	14: LdU64(0)
	15: StLoc[25](loc15: u64)
	16: MoveLoc[11](loc1: u64)
	17: StLoc[28](loc18: u64)
B1:
	18: CopyLoc[25](loc15: u64)
	19: CopyLoc[28](loc18: u64)
	20: Lt
	21: BrFalse(47)
B2:
	22: CopyLoc[25](loc15: u64)
	23: StLoc[23](loc13: u64)
	24: CopyLoc[34](loc24: &vector<Creditor>)
	25: MoveLoc[23](loc13: u64)
	26: VecImmBorrow(137)
	27: StLoc[21](loc11: &Creditor)
	28: MutBorrowLoc[26](loc16: vector<u64>)
	29: StLoc[14](loc4: &mut vector<u64>)
	30: MoveLoc[21](loc11: &Creditor)
	31: StLoc[19](loc9: &Creditor)
	32: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	33: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	34: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	35: MoveLoc[19](loc9: &Creditor)
	36: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	37: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	38: StLoc[13](loc3: u64)
	39: MoveLoc[14](loc4: &mut vector<u64>)
	40: MoveLoc[13](loc3: u64)
	41: VecPushBack(84)
	42: MoveLoc[25](loc15: u64)
	43: LdU64(1)
	44: Add
	45: StLoc[25](loc15: u64)
	46: Branch(18)
B3:
	47: MoveLoc[34](loc24: &vector<Creditor>)
	48: Pop
	49: MoveLoc[26](loc16: vector<u64>)
	50: StLoc[32](loc22: vector<u64>)
	51: LdU64(0)
	52: StLoc[16](loc6: u64)
	53: MoveLoc[32](loc22: vector<u64>)
	54: StLoc[33](loc23: vector<u64>)
	55: MutBorrowLoc[33](loc23: vector<u64>)
	56: Call vector::reverse<u64>(&mut vector<u64>)
	57: ImmBorrowLoc[33](loc23: vector<u64>)
	58: VecLen(84)
	59: StLoc[10](loc0: u64)
	60: LdU64(0)
	61: StLoc[24](loc14: u64)
	62: MoveLoc[10](loc0: u64)
	63: StLoc[27](loc17: u64)
B4:
	64: CopyLoc[24](loc14: u64)
	65: CopyLoc[27](loc17: u64)
	66: Lt
	67: BrFalse(86)
B5:
	68: CopyLoc[24](loc14: u64)
	69: Pop
	70: MutBorrowLoc[33](loc23: vector<u64>)
	71: VecPopBack(84)
	72: StLoc[22](loc12: u64)
	73: MoveLoc[16](loc6: u64)
	74: StLoc[29](loc19: u64)
	75: MoveLoc[22](loc12: u64)
	76: StLoc[20](loc10: u64)
	77: MoveLoc[29](loc19: u64)
	78: MoveLoc[20](loc10: u64)
	79: Add
	80: StLoc[16](loc6: u64)
	81: MoveLoc[24](loc14: u64)
	82: LdU64(1)
	83: Add
	84: StLoc[24](loc14: u64)
	85: Branch(64)
B6:
	86: MoveLoc[33](loc23: vector<u64>)
	87: VecUnpack(84, 0)
	88: MoveLoc[16](loc6: u64)
	89: StLoc[30](loc20: u64)
	90: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	91: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	92: Call object::id<AccountCap>(&AccountCap): ID
	93: StLoc[15](loc5: ID)
	94: ImmBorrowLoc[15](loc5: ID)
	95: Call object::id_to_address(&ID): address
	96: StLoc[17](loc7: address)
	97: CopyLoc[3](Arg3: &mut Storage)
	98: CopyLoc[5](Arg5: u8)
	99: MoveLoc[17](loc7: address)
	100: Call logic::user_collateral_balance(&mut Storage, u8, address): u256
	101: CastU64
	102: MoveLoc[30](loc20: u64)
	103: Sub
	104: StLoc[18](loc8: u64)
	105: CopyLoc[18](loc8: u64)
	106: PackGeneric[5](ClaimReward<Ty1>)
	107: Call event::emit<ClaimReward<Ty1>>(ClaimReward<Ty1>)
	108: MoveLoc[8](Arg8: &Clock)
	109: MoveLoc[2](Arg2: &PriceOracle)
	110: MoveLoc[3](Arg3: &mut Storage)
	111: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	112: MoveLoc[5](Arg5: u8)
	113: MoveLoc[18](loc8: u64)
	114: MoveLoc[6](Arg6: &mut Incentive)
	115: MoveLoc[7](Arg7: &mut Incentive)
	116: MoveLoc[1](Arg1: &CenterPond<Ty0>)
	117: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	118: Call incentive_v2::withdraw_with_account_cap<Ty1>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty1>
	119: MoveLoc[9](Arg9: &mut TxContext)
	120: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	121: Ret
}

public claim_center_interest_v3<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &CenterPond<Ty0>, Arg2: &PriceOracle, Arg3: &mut Storage, Arg4: &mut Pool<Ty1>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: &mut TxContext): Coin<Ty1> {
L10:	loc0: u64
L11:	loc1: u64
L12:	loc2: vector<Creditor>
L13:	loc3: u64
L14:	loc4: &mut vector<u64>
L15:	loc5: ID
L16:	loc6: u64
L17:	loc7: address
L18:	loc8: u64
L19:	loc9: &Creditor
L20:	loc10: u64
L21:	loc11: &Creditor
L22:	loc12: u64
L23:	loc13: u64
L24:	loc14: u64
L25:	loc15: u64
L26:	loc16: vector<u64>
L27:	loc17: u64
L28:	loc18: u64
L29:	loc19: u64
L30:	loc20: u64
L31:	loc21: &vector<Creditor>
L32:	loc22: vector<u64>
L33:	loc23: vector<u64>
L34:	loc24: &vector<Creditor>
B0:
	0: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	1: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	2: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	3: Call vec_map::keys<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>): vector<Creditor>
	4: StLoc[12](loc2: vector<Creditor>)
	5: ImmBorrowLoc[12](loc2: vector<Creditor>)
	6: StLoc[31](loc21: &vector<Creditor>)
	7: LdConst[2](vector<u64>: 00)
	8: StLoc[26](loc16: vector<u64>)
	9: MoveLoc[31](loc21: &vector<Creditor>)
	10: StLoc[34](loc24: &vector<Creditor>)
	11: CopyLoc[34](loc24: &vector<Creditor>)
	12: VecLen(137)
	13: StLoc[11](loc1: u64)
	14: LdU64(0)
	15: StLoc[25](loc15: u64)
	16: MoveLoc[11](loc1: u64)
	17: StLoc[28](loc18: u64)
B1:
	18: CopyLoc[25](loc15: u64)
	19: CopyLoc[28](loc18: u64)
	20: Lt
	21: BrFalse(47)
B2:
	22: CopyLoc[25](loc15: u64)
	23: StLoc[23](loc13: u64)
	24: CopyLoc[34](loc24: &vector<Creditor>)
	25: MoveLoc[23](loc13: u64)
	26: VecImmBorrow(137)
	27: StLoc[21](loc11: &Creditor)
	28: MutBorrowLoc[26](loc16: vector<u64>)
	29: StLoc[14](loc4: &mut vector<u64>)
	30: MoveLoc[21](loc11: &Creditor)
	31: StLoc[19](loc9: &Creditor)
	32: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	33: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	34: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	35: MoveLoc[19](loc9: &Creditor)
	36: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	37: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	38: StLoc[13](loc3: u64)
	39: MoveLoc[14](loc4: &mut vector<u64>)
	40: MoveLoc[13](loc3: u64)
	41: VecPushBack(84)
	42: MoveLoc[25](loc15: u64)
	43: LdU64(1)
	44: Add
	45: StLoc[25](loc15: u64)
	46: Branch(18)
B3:
	47: MoveLoc[34](loc24: &vector<Creditor>)
	48: Pop
	49: MoveLoc[26](loc16: vector<u64>)
	50: StLoc[32](loc22: vector<u64>)
	51: LdU64(0)
	52: StLoc[16](loc6: u64)
	53: MoveLoc[32](loc22: vector<u64>)
	54: StLoc[33](loc23: vector<u64>)
	55: MutBorrowLoc[33](loc23: vector<u64>)
	56: Call vector::reverse<u64>(&mut vector<u64>)
	57: ImmBorrowLoc[33](loc23: vector<u64>)
	58: VecLen(84)
	59: StLoc[10](loc0: u64)
	60: LdU64(0)
	61: StLoc[24](loc14: u64)
	62: MoveLoc[10](loc0: u64)
	63: StLoc[27](loc17: u64)
B4:
	64: CopyLoc[24](loc14: u64)
	65: CopyLoc[27](loc17: u64)
	66: Lt
	67: BrFalse(86)
B5:
	68: CopyLoc[24](loc14: u64)
	69: Pop
	70: MutBorrowLoc[33](loc23: vector<u64>)
	71: VecPopBack(84)
	72: StLoc[22](loc12: u64)
	73: MoveLoc[16](loc6: u64)
	74: StLoc[29](loc19: u64)
	75: MoveLoc[22](loc12: u64)
	76: StLoc[20](loc10: u64)
	77: MoveLoc[29](loc19: u64)
	78: MoveLoc[20](loc10: u64)
	79: Add
	80: StLoc[16](loc6: u64)
	81: MoveLoc[24](loc14: u64)
	82: LdU64(1)
	83: Add
	84: StLoc[24](loc14: u64)
	85: Branch(64)
B6:
	86: MoveLoc[33](loc23: vector<u64>)
	87: VecUnpack(84, 0)
	88: MoveLoc[16](loc6: u64)
	89: StLoc[30](loc20: u64)
	90: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	91: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	92: Call object::id<AccountCap>(&AccountCap): ID
	93: StLoc[15](loc5: ID)
	94: ImmBorrowLoc[15](loc5: ID)
	95: Call object::id_to_address(&ID): address
	96: StLoc[17](loc7: address)
	97: CopyLoc[3](Arg3: &mut Storage)
	98: CopyLoc[5](Arg5: u8)
	99: MoveLoc[17](loc7: address)
	100: Call logic::user_collateral_balance(&mut Storage, u8, address): u256
	101: CastU64
	102: MoveLoc[30](loc20: u64)
	103: Sub
	104: StLoc[18](loc8: u64)
	105: CopyLoc[18](loc8: u64)
	106: PackGeneric[5](ClaimReward<Ty1>)
	107: Call event::emit<ClaimReward<Ty1>>(ClaimReward<Ty1>)
	108: MoveLoc[8](Arg8: &Clock)
	109: MoveLoc[2](Arg2: &PriceOracle)
	110: MoveLoc[3](Arg3: &mut Storage)
	111: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	112: MoveLoc[5](Arg5: u8)
	113: MoveLoc[18](loc8: u64)
	114: MoveLoc[6](Arg6: &mut Incentive)
	115: MoveLoc[7](Arg7: &mut Incentive)
	116: MoveLoc[1](Arg1: &CenterPond<Ty0>)
	117: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	118: Call incentive_v3::withdraw_with_account_cap<Ty1>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty1>
	119: MoveLoc[9](Arg9: &mut TxContext)
	120: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	121: Ret
}

public receive<Ty0, Ty1: store + key>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: Receiving<Ty1>): Ty1 {
B0:
	0: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	1: MutBorrowFieldGeneric[1](CenterPond.account: Account)
	2: MoveLoc[2](Arg2: Receiving<Ty1>)
	3: Call 0account::receive<Ty1>(&mut Account, Receiving<Ty1>): Ty1
	4: Ret
}

public deposit_to_surplus<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &mut BucketProtocol, Arg2: Option<Loan<Ty2, NAVI_POND, Ty1>>, Arg3: &mut TxContext) {
L4:	loc0: Balance<Ty1>
L5:	loc1: u64
L6:	loc2: Creditor
L7:	loc3: Loan<Ty2, NAVI_POND, Ty1>
L8:	loc4: &mut Position<Ty1>
B0:
	0: ImmBorrowLoc[2](Arg2: Option<Loan<Ty2, NAVI_POND, Ty1>>)
	1: Call option::is_some<Loan<Ty2, NAVI_POND, Ty1>>(&Option<Loan<Ty2, NAVI_POND, Ty1>>): bool
	2: BrFalse(36)
B1:
	3: MoveLoc[2](Arg2: Option<Loan<Ty2, NAVI_POND, Ty1>>)
	4: Call option::destroy_some<Loan<Ty2, NAVI_POND, Ty1>>(Option<Loan<Ty2, NAVI_POND, Ty1>>): Loan<Ty2, NAVI_POND, Ty1>
	5: StLoc[7](loc3: Loan<Ty2, NAVI_POND, Ty1>)
	6: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	7: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	8: StLoc[8](loc4: &mut Position<Ty1>)
	9: CopyLoc[8](loc4: &mut Position<Ty1>)
	10: MutBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	11: MoveLoc[7](loc3: Loan<Ty2, NAVI_POND, Ty1>)
	12: Call stamp(): NAVI_POND
	13: Call sheet::receive<Ty2, NAVI_POND, Ty1>(&mut Sheet<NAVI_POND, Ty1>, Loan<Ty2, NAVI_POND, Ty1>, NAVI_POND): Balance<Ty1>
	14: StLoc[4](loc0: Balance<Ty1>)
	15: ImmBorrowLoc[4](loc0: Balance<Ty1>)
	16: Call balance::value<Ty1>(&Balance<Ty1>): u64
	17: StLoc[5](loc1: u64)
	18: MoveLoc[1](Arg1: &mut BucketProtocol)
	19: MoveLoc[4](loc0: Balance<Ty1>)
	20: CopyLoc[8](loc4: &mut Position<Ty1>)
	21: ImmBorrowFieldGeneric[5](Position.strap: BottleStrap<Ty1>)
	22: MoveLoc[3](Arg3: &mut TxContext)
	23: Call buck::deposit_surplus_with_strap<Ty1>(&mut BucketProtocol, Balance<Ty1>, &BottleStrap<Ty1>, &mut TxContext)
	24: Call sheet::creditor<Ty2>(): Creditor
	25: StLoc[6](loc2: Creditor)
	26: MoveLoc[5](loc1: u64)
	27: MoveLoc[8](loc4: &mut Position<Ty1>)
	28: ImmBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	29: Call sheet::debts<NAVI_POND, Ty1>(&Sheet<NAVI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	30: ImmBorrowLoc[6](loc2: Creditor)
	31: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	32: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	33: PackGeneric[6](SurplusReceive<Ty0, Ty1, Ty2>)
	34: Call event::emit<SurplusReceive<Ty0, Ty1, Ty2>>(SurplusReceive<Ty0, Ty1, Ty2>)
	35: Branch(44)
B2:
	36: MoveLoc[1](Arg1: &mut BucketProtocol)
	37: Pop
	38: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	39: Pop
	40: MoveLoc[3](Arg3: &mut TxContext)
	41: Pop
	42: MoveLoc[2](Arg2: Option<Loan<Ty2, NAVI_POND, Ty1>>)
	43: Call option::destroy_none<Loan<Ty2, NAVI_POND, Ty1>>(Option<Loan<Ty2, NAVI_POND, Ty1>>)
B3:
	44: Ret
}

public withdraw_from_surplus<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &mut BucketProtocol, Arg2: &mut Option<Collector<Ty2, NAVI_POND, Ty1>>, Arg3: &mut TxContext) {
L4:	loc0: Balance<Ty1>
L5:	loc1: &mut Collector<Ty2, NAVI_POND, Ty1>
L6:	loc2: Creditor
L7:	loc3: &mut Position<Ty1>
L8:	loc4: Balance<Ty1>
L9:	loc5: u64
L10:	loc6: u64
B0:
	0: CopyLoc[2](Arg2: &mut Option<Collector<Ty2, NAVI_POND, Ty1>>)
	1: FreezeRef
	2: Call option::is_some<Collector<Ty2, NAVI_POND, Ty1>>(&Option<Collector<Ty2, NAVI_POND, Ty1>>): bool
	3: BrFalse(50)
B1:
	4: MoveLoc[2](Arg2: &mut Option<Collector<Ty2, NAVI_POND, Ty1>>)
	5: Call option::borrow_mut<Collector<Ty2, NAVI_POND, Ty1>>(&mut Option<Collector<Ty2, NAVI_POND, Ty1>>): &mut Collector<Ty2, NAVI_POND, Ty1>
	6: StLoc[5](loc1: &mut Collector<Ty2, NAVI_POND, Ty1>)
	7: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	8: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	9: StLoc[7](loc3: &mut Position<Ty1>)
	10: CopyLoc[5](loc1: &mut Collector<Ty2, NAVI_POND, Ty1>)
	11: FreezeRef
	12: Call sheet::requirement<Ty2, NAVI_POND, Ty1>(&Collector<Ty2, NAVI_POND, Ty1>): u64
	13: StLoc[10](loc6: u64)
	14: CopyLoc[1](Arg1: &mut BucketProtocol)
	15: CopyLoc[7](loc3: &mut Position<Ty1>)
	16: ImmBorrowFieldGeneric[5](Position.strap: BottleStrap<Ty1>)
	17: Call buck::withdraw_surplus_with_strap<Ty1>(&mut BucketProtocol, &BottleStrap<Ty1>): Balance<Ty1>
	18: StLoc[4](loc0: Balance<Ty1>)
	19: MutBorrowLoc[4](loc0: Balance<Ty1>)
	20: MoveLoc[10](loc6: u64)
	21: Call balance::split<Ty1>(&mut Balance<Ty1>, u64): Balance<Ty1>
	22: StLoc[8](loc4: Balance<Ty1>)
	23: ImmBorrowLoc[8](loc4: Balance<Ty1>)
	24: Call balance::value<Ty1>(&Balance<Ty1>): u64
	25: StLoc[9](loc5: u64)
	26: MoveLoc[1](Arg1: &mut BucketProtocol)
	27: MoveLoc[4](loc0: Balance<Ty1>)
	28: CopyLoc[7](loc3: &mut Position<Ty1>)
	29: ImmBorrowFieldGeneric[5](Position.strap: BottleStrap<Ty1>)
	30: MoveLoc[3](Arg3: &mut TxContext)
	31: Call buck::deposit_surplus_with_strap<Ty1>(&mut BucketProtocol, Balance<Ty1>, &BottleStrap<Ty1>, &mut TxContext)
	32: CopyLoc[7](loc3: &mut Position<Ty1>)
	33: MutBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	34: MoveLoc[5](loc1: &mut Collector<Ty2, NAVI_POND, Ty1>)
	35: MoveLoc[8](loc4: Balance<Ty1>)
	36: Call stamp(): NAVI_POND
	37: Call sheet::repay<Ty2, NAVI_POND, Ty1>(&mut Sheet<NAVI_POND, Ty1>, &mut Collector<Ty2, NAVI_POND, Ty1>, Balance<Ty1>, NAVI_POND)
	38: Call sheet::creditor<Ty2>(): Creditor
	39: StLoc[6](loc2: Creditor)
	40: MoveLoc[9](loc5: u64)
	41: MoveLoc[7](loc3: &mut Position<Ty1>)
	42: ImmBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	43: Call sheet::debts<NAVI_POND, Ty1>(&Sheet<NAVI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	44: ImmBorrowLoc[6](loc2: Creditor)
	45: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	46: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	47: PackGeneric[7](SurplusRepay<Ty0, Ty1, Ty2>)
	48: Call event::emit<SurplusRepay<Ty0, Ty1, Ty2>>(SurplusRepay<Ty0, Ty1, Ty2>)
	49: Branch(58)
B2:
	50: MoveLoc[1](Arg1: &mut BucketProtocol)
	51: Pop
	52: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	53: Pop
	54: MoveLoc[3](Arg3: &mut TxContext)
	55: Pop
	56: MoveLoc[2](Arg2: &mut Option<Collector<Ty2, NAVI_POND, Ty1>>)
	57: Pop
B3:
	58: Ret
}

public deposit_to_navi<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &mut Storage, Arg2: &mut Pool<Ty1>, Arg3: u8, Arg4: &mut Incentive, Arg5: &mut Incentive, Arg6: &Clock, Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>, Arg8: &mut TxContext) {
L9:	loc0: Creditor
L10:	loc1: &VecMap<Creditor, Debt<Ty1>>
L11:	loc2: u64
L12:	loc3: Balance<Ty1>
L13:	loc4: u64
L14:	loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>
B0:
	0: ImmBorrowLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	1: Call option::is_some<Loan<Ty2, NAVI_UNI_POND, Ty1>>(&Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>): bool
	2: BrFalse(45)
B1:
	3: MoveLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	4: Call option::destroy_some<Loan<Ty2, NAVI_UNI_POND, Ty1>>(Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>): Loan<Ty2, NAVI_UNI_POND, Ty1>
	5: StLoc[14](loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>)
	6: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	7: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	8: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	9: MoveLoc[14](loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>)
	10: Call uni_stamp(): NAVI_UNI_POND
	11: Call sheet::receive<Ty2, NAVI_UNI_POND, Ty1>(&mut Sheet<NAVI_UNI_POND, Ty1>, Loan<Ty2, NAVI_UNI_POND, Ty1>, NAVI_UNI_POND): Balance<Ty1>
	12: StLoc[12](loc3: Balance<Ty1>)
	13: ImmBorrowLoc[12](loc3: Balance<Ty1>)
	14: Call balance::value<Ty1>(&Balance<Ty1>): u64
	15: StLoc[13](loc4: u64)
	16: MoveLoc[6](Arg6: &Clock)
	17: MoveLoc[1](Arg1: &mut Storage)
	18: MoveLoc[2](Arg2: &mut Pool<Ty1>)
	19: MoveLoc[3](Arg3: u8)
	20: MoveLoc[12](loc3: Balance<Ty1>)
	21: MoveLoc[8](Arg8: &mut TxContext)
	22: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	23: MoveLoc[4](Arg4: &mut Incentive)
	24: MoveLoc[5](Arg5: &mut Incentive)
	25: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	26: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	27: Call incentive_v2::deposit_with_account_cap<Ty1>(&Clock, &mut Storage, &mut Pool<Ty1>, u8, Coin<Ty1>, &mut Incentive, &mut Incentive, &AccountCap)
	28: MoveLoc[13](loc4: u64)
	29: StLoc[11](loc2: u64)
	30: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	31: FreezeRef
	32: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	33: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	34: StLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	35: Call sheet::creditor<Ty2>(): Creditor
	36: StLoc[9](loc0: Creditor)
	37: MoveLoc[11](loc2: u64)
	38: MoveLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	39: ImmBorrowLoc[9](loc0: Creditor)
	40: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	41: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	42: PackGeneric[8](NaviReceive<Ty0, Ty1, Ty2>)
	43: Call event::emit<NaviReceive<Ty0, Ty1, Ty2>>(NaviReceive<Ty0, Ty1, Ty2>)
	44: Branch(61)
B2:
	45: MoveLoc[1](Arg1: &mut Storage)
	46: Pop
	47: MoveLoc[2](Arg2: &mut Pool<Ty1>)
	48: Pop
	49: MoveLoc[5](Arg5: &mut Incentive)
	50: Pop
	51: MoveLoc[4](Arg4: &mut Incentive)
	52: Pop
	53: MoveLoc[8](Arg8: &mut TxContext)
	54: Pop
	55: MoveLoc[6](Arg6: &Clock)
	56: Pop
	57: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	58: Pop
	59: MoveLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	60: Call option::destroy_none<Loan<Ty2, NAVI_UNI_POND, Ty1>>(Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
B3:
	61: Ret
}

public deposit_to_navi_v3<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &mut Storage, Arg2: &mut Pool<Ty1>, Arg3: u8, Arg4: &mut Incentive, Arg5: &mut Incentive, Arg6: &Clock, Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>, Arg8: &mut TxContext) {
L9:	loc0: Creditor
L10:	loc1: &VecMap<Creditor, Debt<Ty1>>
L11:	loc2: u64
L12:	loc3: Balance<Ty1>
L13:	loc4: u64
L14:	loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>
B0:
	0: ImmBorrowLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	1: Call option::is_some<Loan<Ty2, NAVI_UNI_POND, Ty1>>(&Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>): bool
	2: BrFalse(45)
B1:
	3: MoveLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	4: Call option::destroy_some<Loan<Ty2, NAVI_UNI_POND, Ty1>>(Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>): Loan<Ty2, NAVI_UNI_POND, Ty1>
	5: StLoc[14](loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>)
	6: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	7: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	8: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	9: MoveLoc[14](loc5: Loan<Ty2, NAVI_UNI_POND, Ty1>)
	10: Call uni_stamp(): NAVI_UNI_POND
	11: Call sheet::receive<Ty2, NAVI_UNI_POND, Ty1>(&mut Sheet<NAVI_UNI_POND, Ty1>, Loan<Ty2, NAVI_UNI_POND, Ty1>, NAVI_UNI_POND): Balance<Ty1>
	12: StLoc[12](loc3: Balance<Ty1>)
	13: ImmBorrowLoc[12](loc3: Balance<Ty1>)
	14: Call balance::value<Ty1>(&Balance<Ty1>): u64
	15: StLoc[13](loc4: u64)
	16: MoveLoc[6](Arg6: &Clock)
	17: MoveLoc[1](Arg1: &mut Storage)
	18: MoveLoc[2](Arg2: &mut Pool<Ty1>)
	19: MoveLoc[3](Arg3: u8)
	20: MoveLoc[12](loc3: Balance<Ty1>)
	21: MoveLoc[8](Arg8: &mut TxContext)
	22: Call coin::from_balance<Ty1>(Balance<Ty1>, &mut TxContext): Coin<Ty1>
	23: MoveLoc[4](Arg4: &mut Incentive)
	24: MoveLoc[5](Arg5: &mut Incentive)
	25: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	26: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	27: Call incentive_v3::deposit_with_account_cap<Ty1>(&Clock, &mut Storage, &mut Pool<Ty1>, u8, Coin<Ty1>, &mut Incentive, &mut Incentive, &AccountCap)
	28: MoveLoc[13](loc4: u64)
	29: StLoc[11](loc2: u64)
	30: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	31: FreezeRef
	32: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	33: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	34: StLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	35: Call sheet::creditor<Ty2>(): Creditor
	36: StLoc[9](loc0: Creditor)
	37: MoveLoc[11](loc2: u64)
	38: MoveLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	39: ImmBorrowLoc[9](loc0: Creditor)
	40: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	41: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	42: PackGeneric[8](NaviReceive<Ty0, Ty1, Ty2>)
	43: Call event::emit<NaviReceive<Ty0, Ty1, Ty2>>(NaviReceive<Ty0, Ty1, Ty2>)
	44: Branch(61)
B2:
	45: MoveLoc[1](Arg1: &mut Storage)
	46: Pop
	47: MoveLoc[2](Arg2: &mut Pool<Ty1>)
	48: Pop
	49: MoveLoc[5](Arg5: &mut Incentive)
	50: Pop
	51: MoveLoc[4](Arg4: &mut Incentive)
	52: Pop
	53: MoveLoc[8](Arg8: &mut TxContext)
	54: Pop
	55: MoveLoc[6](Arg6: &Clock)
	56: Pop
	57: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	58: Pop
	59: MoveLoc[7](Arg7: Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
	60: Call option::destroy_none<Loan<Ty2, NAVI_UNI_POND, Ty1>>(Option<Loan<Ty2, NAVI_UNI_POND, Ty1>>)
B3:
	61: Ret
}

public withdraw_from_navi<Ty0, Ty1, Ty2>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: &PriceOracle, Arg3: &mut Storage, Arg4: &mut Pool<Ty1>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>) {
L10:	loc0: Creditor
L11:	loc1: &VecMap<Creditor, Debt<Ty1>>
L12:	loc2: u64
L13:	loc3: Balance<Ty1>
L14:	loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
L15:	loc5: u64
B0:
	0: CopyLoc[9](Arg9: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	1: FreezeRef
	2: Call option::is_some<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): bool
	3: BrFalse(47)
B1:
	4: MoveLoc[9](Arg9: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	5: Call option::borrow_mut<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
	6: StLoc[14](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	7: CopyLoc[14](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	8: FreezeRef
	9: Call sheet::requirement<Ty2, NAVI_UNI_POND, Ty1>(&Collector<Ty2, NAVI_UNI_POND, Ty1>): u64
	10: StLoc[15](loc5: u64)
	11: MoveLoc[8](Arg8: &Clock)
	12: MoveLoc[2](Arg2: &PriceOracle)
	13: MoveLoc[3](Arg3: &mut Storage)
	14: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	15: MoveLoc[5](Arg5: u8)
	16: CopyLoc[15](loc5: u64)
	17: MoveLoc[6](Arg6: &mut Incentive)
	18: MoveLoc[7](Arg7: &mut Incentive)
	19: CopyLoc[1](Arg1: &mut CenterPond<Ty0>)
	20: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	21: Call incentive_v2::withdraw_with_account_cap<Ty1>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty1>
	22: StLoc[13](loc3: Balance<Ty1>)
	23: CopyLoc[1](Arg1: &mut CenterPond<Ty0>)
	24: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	25: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	26: MoveLoc[14](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	27: MoveLoc[13](loc3: Balance<Ty1>)
	28: Call uni_stamp(): NAVI_UNI_POND
	29: Call sheet::repay<Ty2, NAVI_UNI_POND, Ty1>(&mut Sheet<NAVI_UNI_POND, Ty1>, &mut Collector<Ty2, NAVI_UNI_POND, Ty1>, Balance<Ty1>, NAVI_UNI_POND)
	30: MoveLoc[15](loc5: u64)
	31: StLoc[12](loc2: u64)
	32: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	33: FreezeRef
	34: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	35: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	36: StLoc[11](loc1: &VecMap<Creditor, Debt<Ty1>>)
	37: Call sheet::creditor<Ty2>(): Creditor
	38: StLoc[10](loc0: Creditor)
	39: MoveLoc[12](loc2: u64)
	40: MoveLoc[11](loc1: &VecMap<Creditor, Debt<Ty1>>)
	41: ImmBorrowLoc[10](loc0: Creditor)
	42: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	43: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	44: PackGeneric[9](NaviRepay<Ty0, Ty1, Ty2>)
	45: Call event::emit<NaviRepay<Ty0, Ty1, Ty2>>(NaviRepay<Ty0, Ty1, Ty2>)
	46: Branch(63)
B2:
	47: MoveLoc[3](Arg3: &mut Storage)
	48: Pop
	49: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	50: Pop
	51: MoveLoc[2](Arg2: &PriceOracle)
	52: Pop
	53: MoveLoc[7](Arg7: &mut Incentive)
	54: Pop
	55: MoveLoc[6](Arg6: &mut Incentive)
	56: Pop
	57: MoveLoc[9](Arg9: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	58: Pop
	59: MoveLoc[8](Arg8: &Clock)
	60: Pop
	61: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	62: Pop
B3:
	63: Ret
}

public withdraw_from_navi_v2<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &PriceOracle, Arg2: &mut Storage, Arg3: &mut Pool<Ty1>, Arg4: u8, Arg5: &mut Incentive, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>) {
L9:	loc0: Creditor
L10:	loc1: &VecMap<Creditor, Debt<Ty1>>
L11:	loc2: u64
L12:	loc3: Balance<Ty1>
L13:	loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
L14:	loc5: u64
B0:
	0: CopyLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	1: FreezeRef
	2: Call option::is_some<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): bool
	3: BrFalse(47)
B1:
	4: MoveLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	5: Call option::borrow_mut<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
	6: StLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	7: CopyLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	8: FreezeRef
	9: Call sheet::requirement<Ty2, NAVI_UNI_POND, Ty1>(&Collector<Ty2, NAVI_UNI_POND, Ty1>): u64
	10: StLoc[14](loc5: u64)
	11: MoveLoc[7](Arg7: &Clock)
	12: MoveLoc[1](Arg1: &PriceOracle)
	13: MoveLoc[2](Arg2: &mut Storage)
	14: MoveLoc[3](Arg3: &mut Pool<Ty1>)
	15: MoveLoc[4](Arg4: u8)
	16: CopyLoc[14](loc5: u64)
	17: MoveLoc[5](Arg5: &mut Incentive)
	18: MoveLoc[6](Arg6: &mut Incentive)
	19: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	20: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	21: Call incentive_v2::withdraw_with_account_cap<Ty1>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty1>
	22: StLoc[12](loc3: Balance<Ty1>)
	23: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	24: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	25: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	26: MoveLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	27: MoveLoc[12](loc3: Balance<Ty1>)
	28: Call uni_stamp(): NAVI_UNI_POND
	29: Call sheet::repay<Ty2, NAVI_UNI_POND, Ty1>(&mut Sheet<NAVI_UNI_POND, Ty1>, &mut Collector<Ty2, NAVI_UNI_POND, Ty1>, Balance<Ty1>, NAVI_UNI_POND)
	30: MoveLoc[14](loc5: u64)
	31: StLoc[11](loc2: u64)
	32: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	33: FreezeRef
	34: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	35: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	36: StLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	37: Call sheet::creditor<Ty2>(): Creditor
	38: StLoc[9](loc0: Creditor)
	39: MoveLoc[11](loc2: u64)
	40: MoveLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	41: ImmBorrowLoc[9](loc0: Creditor)
	42: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	43: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	44: PackGeneric[9](NaviRepay<Ty0, Ty1, Ty2>)
	45: Call event::emit<NaviRepay<Ty0, Ty1, Ty2>>(NaviRepay<Ty0, Ty1, Ty2>)
	46: Branch(63)
B2:
	47: MoveLoc[2](Arg2: &mut Storage)
	48: Pop
	49: MoveLoc[3](Arg3: &mut Pool<Ty1>)
	50: Pop
	51: MoveLoc[1](Arg1: &PriceOracle)
	52: Pop
	53: MoveLoc[6](Arg6: &mut Incentive)
	54: Pop
	55: MoveLoc[5](Arg5: &mut Incentive)
	56: Pop
	57: MoveLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	58: Pop
	59: MoveLoc[7](Arg7: &Clock)
	60: Pop
	61: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	62: Pop
B3:
	63: Ret
}

public withdraw_from_navi_v3<Ty0, Ty1, Ty2>(Arg0: &mut CenterPond<Ty0>, Arg1: &PriceOracle, Arg2: &mut Storage, Arg3: &mut Pool<Ty1>, Arg4: u8, Arg5: &mut Incentive, Arg6: &mut Incentive, Arg7: &Clock, Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>) {
L9:	loc0: Creditor
L10:	loc1: &VecMap<Creditor, Debt<Ty1>>
L11:	loc2: u64
L12:	loc3: Balance<Ty1>
L13:	loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
L14:	loc5: u64
B0:
	0: CopyLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	1: FreezeRef
	2: Call option::is_some<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): bool
	3: BrFalse(47)
B1:
	4: MoveLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	5: Call option::borrow_mut<Collector<Ty2, NAVI_UNI_POND, Ty1>>(&mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>): &mut Collector<Ty2, NAVI_UNI_POND, Ty1>
	6: StLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	7: CopyLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	8: FreezeRef
	9: Call sheet::requirement<Ty2, NAVI_UNI_POND, Ty1>(&Collector<Ty2, NAVI_UNI_POND, Ty1>): u64
	10: StLoc[14](loc5: u64)
	11: MoveLoc[7](Arg7: &Clock)
	12: MoveLoc[1](Arg1: &PriceOracle)
	13: MoveLoc[2](Arg2: &mut Storage)
	14: MoveLoc[3](Arg3: &mut Pool<Ty1>)
	15: MoveLoc[4](Arg4: u8)
	16: CopyLoc[14](loc5: u64)
	17: MoveLoc[5](Arg5: &mut Incentive)
	18: MoveLoc[6](Arg6: &mut Incentive)
	19: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	20: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	21: Call incentive_v3::withdraw_with_account_cap<Ty1>(&Clock, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, u64, &mut Incentive, &mut Incentive, &AccountCap): Balance<Ty1>
	22: StLoc[12](loc3: Balance<Ty1>)
	23: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	24: Call position_mut<Ty0, Ty1>(&mut CenterPond<Ty0>): &mut Position<Ty1>
	25: MutBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	26: MoveLoc[13](loc4: &mut Collector<Ty2, NAVI_UNI_POND, Ty1>)
	27: MoveLoc[12](loc3: Balance<Ty1>)
	28: Call uni_stamp(): NAVI_UNI_POND
	29: Call sheet::repay<Ty2, NAVI_UNI_POND, Ty1>(&mut Sheet<NAVI_UNI_POND, Ty1>, &mut Collector<Ty2, NAVI_UNI_POND, Ty1>, Balance<Ty1>, NAVI_UNI_POND)
	30: MoveLoc[14](loc5: u64)
	31: StLoc[11](loc2: u64)
	32: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	33: FreezeRef
	34: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	35: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	36: StLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	37: Call sheet::creditor<Ty2>(): Creditor
	38: StLoc[9](loc0: Creditor)
	39: MoveLoc[11](loc2: u64)
	40: MoveLoc[10](loc1: &VecMap<Creditor, Debt<Ty1>>)
	41: ImmBorrowLoc[9](loc0: Creditor)
	42: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	43: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	44: PackGeneric[9](NaviRepay<Ty0, Ty1, Ty2>)
	45: Call event::emit<NaviRepay<Ty0, Ty1, Ty2>>(NaviRepay<Ty0, Ty1, Ty2>)
	46: Branch(63)
B2:
	47: MoveLoc[2](Arg2: &mut Storage)
	48: Pop
	49: MoveLoc[3](Arg3: &mut Pool<Ty1>)
	50: Pop
	51: MoveLoc[1](Arg1: &PriceOracle)
	52: Pop
	53: MoveLoc[6](Arg6: &mut Incentive)
	54: Pop
	55: MoveLoc[5](Arg5: &mut Incentive)
	56: Pop
	57: MoveLoc[8](Arg8: &mut Option<Collector<Ty2, NAVI_UNI_POND, Ty1>>)
	58: Pop
	59: MoveLoc[7](Arg7: &Clock)
	60: Pop
	61: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	62: Pop
B3:
	63: Ret
}

entry claim_center_reward_to<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: &mut Storage, Arg3: &mut IncentiveFundsPool<Ty1>, Arg4: u8, Arg5: u8, Arg6: &mut Incentive, Arg7: &Clock, Arg8: address, Arg9: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut IncentiveFundsPool<Ty1>)
	4: MoveLoc[4](Arg4: u8)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &Clock)
	8: MoveLoc[9](Arg9: &mut TxContext)
	9: Call claim_center_reward<Ty0, Ty1>(&AdminCap, &mut CenterPond<Ty0>, &mut Storage, &mut IncentiveFundsPool<Ty1>, u8, u8, &mut Incentive, &Clock, &mut TxContext): Coin<Ty1>
	10: MoveLoc[8](Arg8: address)
	11: Call transfer::public_transfer<Coin<Ty1>>(Coin<Ty1>, address)
	12: Ret
}

entry claim_center_reward_to_v3<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &mut CenterPond<Ty0>, Arg2: &mut Storage, Arg3: &mut RewardFund<Ty1>, Arg4: vector<String>, Arg5: vector<address>, Arg6: &mut Incentive, Arg7: &Clock, Arg8: address, Arg9: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &mut CenterPond<Ty0>)
	2: MoveLoc[2](Arg2: &mut Storage)
	3: MoveLoc[3](Arg3: &mut RewardFund<Ty1>)
	4: MoveLoc[4](Arg4: vector<String>)
	5: MoveLoc[5](Arg5: vector<address>)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &Clock)
	8: MoveLoc[9](Arg9: &mut TxContext)
	9: Call claim_center_reward_v3<Ty0, Ty1>(&AdminCap, &mut CenterPond<Ty0>, &mut Storage, &mut RewardFund<Ty1>, vector<String>, vector<address>, &mut Incentive, &Clock, &mut TxContext): Coin<Ty1>
	10: MoveLoc[8](Arg8: address)
	11: Call transfer::public_transfer<Coin<Ty1>>(Coin<Ty1>, address)
	12: Ret
}

entry claim_center_interest_to<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &CenterPond<Ty0>, Arg2: &PriceOracle, Arg3: &mut Storage, Arg4: &mut Pool<Ty1>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: address, Arg10: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &CenterPond<Ty0>)
	2: MoveLoc[2](Arg2: &PriceOracle)
	3: MoveLoc[3](Arg3: &mut Storage)
	4: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &mut Incentive)
	8: MoveLoc[8](Arg8: &Clock)
	9: MoveLoc[10](Arg10: &mut TxContext)
	10: Call claim_center_interest<Ty0, Ty1>(&AdminCap, &CenterPond<Ty0>, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, &mut Incentive, &mut Incentive, &Clock, &mut TxContext): Coin<Ty1>
	11: MoveLoc[9](Arg9: address)
	12: Call transfer::public_transfer<Coin<Ty1>>(Coin<Ty1>, address)
	13: Ret
}

entry claim_center_interest_to_v3<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &CenterPond<Ty0>, Arg2: &PriceOracle, Arg3: &mut Storage, Arg4: &mut Pool<Ty1>, Arg5: u8, Arg6: &mut Incentive, Arg7: &mut Incentive, Arg8: &Clock, Arg9: address, Arg10: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: &AdminCap)
	1: MoveLoc[1](Arg1: &CenterPond<Ty0>)
	2: MoveLoc[2](Arg2: &PriceOracle)
	3: MoveLoc[3](Arg3: &mut Storage)
	4: MoveLoc[4](Arg4: &mut Pool<Ty1>)
	5: MoveLoc[5](Arg5: u8)
	6: MoveLoc[6](Arg6: &mut Incentive)
	7: MoveLoc[7](Arg7: &mut Incentive)
	8: MoveLoc[8](Arg8: &Clock)
	9: MoveLoc[10](Arg10: &mut TxContext)
	10: Call claim_center_interest_v3<Ty0, Ty1>(&AdminCap, &CenterPond<Ty0>, &PriceOracle, &mut Storage, &mut Pool<Ty1>, u8, &mut Incentive, &mut Incentive, &Clock, &mut TxContext): Coin<Ty1>
	11: MoveLoc[9](Arg9: address)
	12: Call transfer::public_transfer<Coin<Ty1>>(Coin<Ty1>, address)
	13: Ret
}

public surplus_sheet<Ty0, Ty1>(Arg0: &CenterPond<Ty0>): &Sheet<NAVI_POND, Ty1> {
L1:	loc0: Option<TypeName>
B0:
	0: CopyLoc[0](Arg0: &CenterPond<Ty0>)
	1: Call try_get_asset_name<Ty0, Ty1>(&CenterPond<Ty0>): Option<TypeName>
	2: StLoc[1](loc0: Option<TypeName>)
	3: ImmBorrowLoc[1](loc0: Option<TypeName>)
	4: Call option::is_none<TypeName>(&Option<TypeName>): bool
	5: BrFalse(7)
B1:
	6: Call err_unsupported_asset()
B2:
	7: MoveLoc[0](Arg0: &CenterPond<Ty0>)
	8: ImmBorrowFieldGeneric[0](CenterPond.id: UID)
	9: MoveLoc[1](loc0: Option<TypeName>)
	10: Call option::destroy_some<TypeName>(Option<TypeName>): TypeName
	11: Call dynamic_field::borrow<TypeName, Position<Ty1>>(&UID, TypeName): &Position<Ty1>
	12: ImmBorrowFieldGeneric[2](Position.surplus_sheet: Sheet<NAVI_POND, Ty1>)
	13: Ret
}

public navi_sheet<Ty0, Ty1>(Arg0: &CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1> {
L1:	loc0: Option<TypeName>
B0:
	0: CopyLoc[0](Arg0: &CenterPond<Ty0>)
	1: Call try_get_asset_name<Ty0, Ty1>(&CenterPond<Ty0>): Option<TypeName>
	2: StLoc[1](loc0: Option<TypeName>)
	3: ImmBorrowLoc[1](loc0: Option<TypeName>)
	4: Call option::is_none<TypeName>(&Option<TypeName>): bool
	5: BrFalse(7)
B1:
	6: Call err_unsupported_asset()
B2:
	7: MoveLoc[0](Arg0: &CenterPond<Ty0>)
	8: ImmBorrowFieldGeneric[0](CenterPond.id: UID)
	9: MoveLoc[1](loc0: Option<TypeName>)
	10: Call option::destroy_some<TypeName>(Option<TypeName>): TypeName
	11: Call dynamic_field::borrow<TypeName, Position<Ty1>>(&UID, TypeName): &Position<Ty1>
	12: ImmBorrowFieldGeneric[3](Position.navi_sheet: Sheet<NAVI_UNI_POND, Ty1>)
	13: Ret
}

public try_get_asset_name<Ty0, Ty1>(Arg0: &CenterPond<Ty0>): Option<TypeName> {
L1:	loc0: Option<TypeName>
L2:	loc1: TypeName
B0:
	0: Call type_name::with_defining_ids<Ty1>(): TypeName
	1: StLoc[2](loc1: TypeName)
	2: MoveLoc[0](Arg0: &CenterPond<Ty0>)
	3: ImmBorrowFieldGeneric[0](CenterPond.id: UID)
	4: CopyLoc[2](loc1: TypeName)
	5: Call dynamic_field::exists_<TypeName>(&UID, TypeName): bool
	6: BrFalse(11)
B1:
	7: MoveLoc[2](loc1: TypeName)
	8: Call option::some<TypeName>(TypeName): Option<TypeName>
	9: StLoc[1](loc0: Option<TypeName>)
	10: Branch(13)
B2:
	11: Call option::none<TypeName>(): Option<TypeName>
	12: StLoc[1](loc0: Option<TypeName>)
B3:
	13: MoveLoc[1](loc0: Option<TypeName>)
	14: Ret
}

public emit_cap_balance<Ty0, Ty1>(Arg0: &AdminCap, Arg1: &CenterPond<Ty0>, Arg2: &mut Storage, Arg3: u8) {
L4:	loc0: u64
L5:	loc1: u64
L6:	loc2: vector<Creditor>
L7:	loc3: u64
L8:	loc4: &mut vector<u64>
L9:	loc5: u64
L10:	loc6: &Creditor
L11:	loc7: u64
L12:	loc8: &Creditor
L13:	loc9: u64
L14:	loc10: u64
L15:	loc11: u64
L16:	loc12: u64
L17:	loc13: vector<u64>
L18:	loc14: u64
L19:	loc15: u64
L20:	loc16: u64
L21:	loc17: u64
L22:	loc18: u64
L23:	loc19: &vector<Creditor>
L24:	loc20: vector<u64>
L25:	loc21: vector<u64>
L26:	loc22: &vector<Creditor>
B0:
	0: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	1: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	2: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	3: Call vec_map::keys<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>): vector<Creditor>
	4: StLoc[6](loc2: vector<Creditor>)
	5: ImmBorrowLoc[6](loc2: vector<Creditor>)
	6: StLoc[23](loc19: &vector<Creditor>)
	7: LdConst[2](vector<u64>: 00)
	8: StLoc[17](loc13: vector<u64>)
	9: MoveLoc[23](loc19: &vector<Creditor>)
	10: StLoc[26](loc22: &vector<Creditor>)
	11: CopyLoc[26](loc22: &vector<Creditor>)
	12: VecLen(137)
	13: StLoc[5](loc1: u64)
	14: LdU64(0)
	15: StLoc[16](loc12: u64)
	16: MoveLoc[5](loc1: u64)
	17: StLoc[19](loc15: u64)
B1:
	18: CopyLoc[16](loc12: u64)
	19: CopyLoc[19](loc15: u64)
	20: Lt
	21: BrFalse(47)
B2:
	22: CopyLoc[16](loc12: u64)
	23: StLoc[14](loc10: u64)
	24: CopyLoc[26](loc22: &vector<Creditor>)
	25: MoveLoc[14](loc10: u64)
	26: VecImmBorrow(137)
	27: StLoc[12](loc8: &Creditor)
	28: MutBorrowLoc[17](loc13: vector<u64>)
	29: StLoc[8](loc4: &mut vector<u64>)
	30: MoveLoc[12](loc8: &Creditor)
	31: StLoc[10](loc6: &Creditor)
	32: CopyLoc[1](Arg1: &CenterPond<Ty0>)
	33: Call navi_sheet<Ty0, Ty1>(&CenterPond<Ty0>): &Sheet<NAVI_UNI_POND, Ty1>
	34: Call sheet::debts<NAVI_UNI_POND, Ty1>(&Sheet<NAVI_UNI_POND, Ty1>): &VecMap<Creditor, Debt<Ty1>>
	35: MoveLoc[10](loc6: &Creditor)
	36: Call vec_map::get<Creditor, Debt<Ty1>>(&VecMap<Creditor, Debt<Ty1>>, &Creditor): &Debt<Ty1>
	37: Call sheet::debt_value<Ty1>(&Debt<Ty1>): u64
	38: StLoc[7](loc3: u64)
	39: MoveLoc[8](loc4: &mut vector<u64>)
	40: MoveLoc[7](loc3: u64)
	41: VecPushBack(84)
	42: MoveLoc[16](loc12: u64)
	43: LdU64(1)
	44: Add
	45: StLoc[16](loc12: u64)
	46: Branch(18)
B3:
	47: MoveLoc[26](loc22: &vector<Creditor>)
	48: Pop
	49: MoveLoc[17](loc13: vector<u64>)
	50: StLoc[24](loc20: vector<u64>)
	51: LdU64(0)
	52: StLoc[9](loc5: u64)
	53: MoveLoc[24](loc20: vector<u64>)
	54: StLoc[25](loc21: vector<u64>)
	55: MutBorrowLoc[25](loc21: vector<u64>)
	56: Call vector::reverse<u64>(&mut vector<u64>)
	57: ImmBorrowLoc[25](loc21: vector<u64>)
	58: VecLen(84)
	59: StLoc[4](loc0: u64)
	60: LdU64(0)
	61: StLoc[15](loc11: u64)
	62: MoveLoc[4](loc0: u64)
	63: StLoc[18](loc14: u64)
B4:
	64: CopyLoc[15](loc11: u64)
	65: CopyLoc[18](loc14: u64)
	66: Lt
	67: BrFalse(86)
B5:
	68: CopyLoc[15](loc11: u64)
	69: Pop
	70: MutBorrowLoc[25](loc21: vector<u64>)
	71: VecPopBack(84)
	72: StLoc[13](loc9: u64)
	73: MoveLoc[9](loc5: u64)
	74: StLoc[20](loc16: u64)
	75: MoveLoc[13](loc9: u64)
	76: StLoc[11](loc7: u64)
	77: MoveLoc[20](loc16: u64)
	78: MoveLoc[11](loc7: u64)
	79: Add
	80: StLoc[9](loc5: u64)
	81: MoveLoc[15](loc11: u64)
	82: LdU64(1)
	83: Add
	84: StLoc[15](loc11: u64)
	85: Branch(64)
B6:
	86: MoveLoc[25](loc21: vector<u64>)
	87: VecUnpack(84, 0)
	88: MoveLoc[9](loc5: u64)
	89: StLoc[22](loc18: u64)
	90: MoveLoc[2](Arg2: &mut Storage)
	91: MoveLoc[3](Arg3: u8)
	92: MoveLoc[1](Arg1: &CenterPond<Ty0>)
	93: ImmBorrowFieldGeneric[4](CenterPond.navi_cap: AccountCap)
	94: Call account::account_owner(&AccountCap): address
	95: Call logic::user_collateral_balance(&mut Storage, u8, address): u256
	96: CastU64
	97: StLoc[21](loc17: u64)
	98: MoveLoc[22](loc18: u64)
	99: MoveLoc[21](loc17: u64)
	100: PackGeneric[10](AccountSheet<Ty0, Ty1>)
	101: Call event::emit<AccountSheet<Ty0, Ty1>>(AccountSheet<Ty0, Ty1>)
	102: Ret
}

position_mut<Ty0, Ty1>(Arg0: &mut CenterPond<Ty0>): &mut Position<Ty1> {
L1:	loc0: Option<TypeName>
B0:
	0: CopyLoc[0](Arg0: &mut CenterPond<Ty0>)
	1: FreezeRef
	2: Call try_get_asset_name<Ty0, Ty1>(&CenterPond<Ty0>): Option<TypeName>
	3: StLoc[1](loc0: Option<TypeName>)
	4: ImmBorrowLoc[1](loc0: Option<TypeName>)
	5: Call option::is_none<TypeName>(&Option<TypeName>): bool
	6: BrFalse(8)
B1:
	7: Call err_unsupported_asset()
B2:
	8: MoveLoc[0](Arg0: &mut CenterPond<Ty0>)
	9: MutBorrowFieldGeneric[0](CenterPond.id: UID)
	10: MoveLoc[1](loc0: Option<TypeName>)
	11: Call option::destroy_some<TypeName>(Option<TypeName>): TypeName
	12: Call dynamic_field::borrow_mut<TypeName, Position<Ty1>>(&mut UID, TypeName): &mut Position<Ty1>
	13: Ret
}

stamp(): NAVI_POND {
B0:
	0: LdFalse
	1: Pack[1](NAVI_POND)
	2: Ret
}

uni_stamp(): NAVI_UNI_POND {
B0:
	0: LdFalse
	1: Pack[4](NAVI_UNI_POND)
	2: Ret
}

Constants [
	0 => u64: 1
	1 => vector<u8>: "CenterPond" // interpreted as UTF8 string
	2 => vector<u64>: 00
]
}
