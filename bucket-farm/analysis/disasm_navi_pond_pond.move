// Move bytecode v6
module ad4f4f73dc19dd2e28f380f287201a549215407db46acd7543e89443954d5eba.pond {
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::buck;
use ce7ff77a83ea0cb6fd39bd8748e2ec89a3f41e8efdc3f4eb123e0ca37b184db2::pipe;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::account;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::incentive_v2;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::lending;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::pool;
use d899cf7d2b5db716bd2cf55599fb0d5ee38a3061e7b6bb6eebf73fa5bc4c81ca::storage;
use ca441b44943c16be0e6e23c5a955bb971537ea3289ae8016fbf33fffe1fd210f::oracle;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::event;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

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

}
