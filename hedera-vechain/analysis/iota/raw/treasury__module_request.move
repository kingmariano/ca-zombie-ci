// Move bytecode v6
module d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f.module_request {
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;

struct ModuleRequest<phantom Ty0> has drop {
	version: u64
}

public new<Ty0: drop>(Arg0: Ty0, Arg1: u64): ModuleRequest<Ty0> {
B0:
	0: MoveLoc[1](Arg1: u64)
	1: PackGeneric[0](ModuleRequest<Ty0>)
	2: Ret
}

public module_type<Ty0>(Arg0: &ModuleRequest<Ty0>): TypeName {
B0:
	0: Call type_name::get<Ty0>(): TypeName
	1: Ret
}

public version<Ty0>(Arg0: &ModuleRequest<Ty0>): u64 {
B0:
	0: MoveLoc[0](Arg0: &ModuleRequest<Ty0>)
	1: ImmBorrowFieldGeneric[0](ModuleRequest.version: u64)
	2: ReadRef
	3: Ret
}

}
