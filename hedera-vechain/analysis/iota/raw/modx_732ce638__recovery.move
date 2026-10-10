// Move bytecode v6
module 732ce63849c64d630f256f2a926c90b309ffbc6a9a6806239088e1649ff8c952.recovery {
use 0000000000000000000000000000000000000000000000000000000000000002::clock;
use 0000000000000000000000000000000000000000000000000000000000000002::coin;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;
use c7ab9b9353e23c6a3a15181eb51bf7145ddeff1a5642280394cd4d6a0d37d83b::stability_pool;
use 732ce63849c64d630f256f2a926c90b309ffbc6a9a6806239088e1649ff8c952::recovery_events;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::admin;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::module_request;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

struct VirtueRecovery has drop {
	dummy_field: bool
}

err_zero_amount() {
B0:
	0: LdConst[1](u64: 501)
	1: Abort
}

public mint(Arg0: &mut Treasury, Arg1: &mut StabilityPool, Arg2: &Clock, Arg3: &AdminCap, Arg4: address, Arg5: u64, Arg6: &mut TxContext): PositionResponse {
L7:	loc0: Coin<VUSD>
L8:	loc1: ModuleRequest<VirtueRecovery>
L9:	loc2: PositionResponse
B0:
	0: CopyLoc[5](Arg5: u64)
	1: LdU64(0)
	2: Eq
	3: BrFalse(5)
B1:
	4: Call err_zero_amount()
B2:
	5: LdFalse
	6: Pack[0](VirtueRecovery)
	7: LdConst[0](u64: 1)
	8: Call module_request::new<VirtueRecovery>(VirtueRecovery, u64): ModuleRequest<VirtueRecovery>
	9: StLoc[8](loc1: ModuleRequest<VirtueRecovery>)
	10: MoveLoc[0](Arg0: &mut Treasury)
	11: ImmBorrowLoc[8](loc1: ModuleRequest<VirtueRecovery>)
	12: CopyLoc[5](Arg5: u64)
	13: MoveLoc[6](Arg6: &mut TxContext)
	14: Call vusd::mint<VirtueRecovery>(&mut Treasury, &ModuleRequest<VirtueRecovery>, u64, &mut TxContext): Coin<VUSD>
	15: StLoc[7](loc0: Coin<VUSD>)
	16: CopyLoc[1](Arg1: &mut StabilityPool)
	17: MoveLoc[2](Arg2: &Clock)
	18: CopyLoc[4](Arg4: address)
	19: MoveLoc[7](loc0: Coin<VUSD>)
	20: Call stability_pool::deposit(&mut StabilityPool, &Clock, address, Coin<VUSD>): PositionResponse
	21: StLoc[9](loc2: PositionResponse)
	22: MoveLoc[4](Arg4: address)
	23: MoveLoc[5](Arg5: u64)
	24: ImmBorrowLoc[9](loc2: PositionResponse)
	25: Call stability_pool::vusd_balance(&PositionResponse): u64
	26: MoveLoc[1](Arg1: &mut StabilityPool)
	27: FreezeRef
	28: Call stability_pool::pool_balance(&StabilityPool): u64
	29: Call recovery_events::emit_recovery_mint(address, u64, u64, u64)
	30: MoveLoc[9](loc2: PositionResponse)
	31: Ret
}

public burn(Arg0: &mut Treasury, Arg1: &AdminCap, Arg2: Coin<VUSD>) {
L3:	loc0: ModuleRequest<VirtueRecovery>
B0:
	0: ImmBorrowLoc[2](Arg2: Coin<VUSD>)
	1: Call coin::value<VUSD>(&Coin<VUSD>): u64
	2: LdU64(0)
	3: Eq
	4: BrFalse(6)
B1:
	5: Call err_zero_amount()
B2:
	6: LdFalse
	7: Pack[0](VirtueRecovery)
	8: LdConst[0](u64: 1)
	9: Call module_request::new<VirtueRecovery>(VirtueRecovery, u64): ModuleRequest<VirtueRecovery>
	10: StLoc[3](loc0: ModuleRequest<VirtueRecovery>)
	11: MoveLoc[0](Arg0: &mut Treasury)
	12: ImmBorrowLoc[3](loc0: ModuleRequest<VirtueRecovery>)
	13: MoveLoc[2](Arg2: Coin<VUSD>)
	14: Call vusd::burn<VirtueRecovery>(&mut Treasury, &ModuleRequest<VirtueRecovery>, Coin<VUSD>)
	15: Ret
}

public package_version(): u64 {
B0:
	0: LdConst[0](u64: 1)
	1: Ret
}

Constants [
	0 => u64: 1
	1 => u64: 501
]
}
