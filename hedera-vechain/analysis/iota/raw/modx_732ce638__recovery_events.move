// Move bytecode v6
module 732ce63849c64d630f256f2a926c90b309ffbc6a9a6806239088e1649ff8c952.recovery_events {
use 0000000000000000000000000000000000000000000000000000000000000002::event;

struct RecoveryMint has copy, drop {
	beneficiary: address,
	amount: u64,
	position_vusd_balance: u64,
	pool_vusd_balance: u64
}

public(friend) emit_recovery_mint(Arg0: address, Arg1: u64, Arg2: u64, Arg3: u64) {
B0:
	0: MoveLoc[0](Arg0: address)
	1: MoveLoc[1](Arg1: u64)
	2: MoveLoc[2](Arg2: u64)
	3: MoveLoc[3](Arg3: u64)
	4: Pack[0](RecoveryMint)
	5: Call event::emit<RecoveryMint>(RecoveryMint)
	6: Ret
}

}
