// Move bytecode v6
module cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1.version {
use 0000000000000000000000000000000000000000000000000000000000000001::type_name;
use cdeeb40cd7ffd7c3b741f40a8e11cb784a5c9b588ce993d4ab86479072386ba1::witness;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::module_request;
use d3b63e603a78786facf65ff22e79701f3e824881a12fa3268d62a75530fe904f::vusd;

public package_version(): u64 {
B0:
	0: LdConst[0](u64: 1)
	1: Ret
}

public(friend) assert_valid_package(Arg0: &Treasury) {
L1:	loc0: ModuleRequest<VirtueCDP>
B0:
	0: Call witness::witness(): VirtueCDP
	1: Call package_version(): u64
	2: Call module_request::new<VirtueCDP>(VirtueCDP, u64): ModuleRequest<VirtueCDP>
	3: StLoc[1](loc0: ModuleRequest<VirtueCDP>)
	4: MoveLoc[0](Arg0: &Treasury)
	5: ImmBorrowLoc[1](loc0: ModuleRequest<VirtueCDP>)
	6: Call vusd::assert_valid_module<VirtueCDP>(&Treasury, &ModuleRequest<VirtueCDP>): TypeName
	7: Pop
	8: Ret
}

Constants [
	0 => u64: 1
]
}
