// Move bytecode v6
module db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23.profile {
use 0db143afbc91b84a37c4bad1b9da19ca7a7b4afd0c594d618e1cb9b4bcf49a23::stake;
use 0000000000000000000000000000000000000000000000000000000000000002::balance;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::vec_map;

struct Profile<phantom Ty0> has store {
	points: Balance<Ty0>,
	stakes: VecMap<ID, Stake>
}

public new<Ty0>(): Profile<Ty0> {
B0:
	0: Call balance::zero<Ty0>(): Balance<Ty0>
	1: Call vec_map::empty<ID, Stake>(): VecMap<ID, Stake>
	2: PackGeneric[0](Profile<Ty0>)
	3: Ret
}

public points<Ty0>(Arg0: &Profile<Ty0>): &Balance<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &Profile<Ty0>)
	1: ImmBorrowFieldGeneric[0](Profile.points: Balance<Ty0>)
	2: Ret
}

public points_mut<Ty0>(Arg0: &mut Profile<Ty0>): &mut Balance<Ty0> {
B0:
	0: MoveLoc[0](Arg0: &mut Profile<Ty0>)
	1: MutBorrowFieldGeneric[0](Profile.points: Balance<Ty0>)
	2: Ret
}

public stakes<Ty0>(Arg0: &Profile<Ty0>): &VecMap<ID, Stake> {
B0:
	0: MoveLoc[0](Arg0: &Profile<Ty0>)
	1: ImmBorrowFieldGeneric[1](Profile.stakes: VecMap<ID, Stake>)
	2: Ret
}

public stakes_mut<Ty0>(Arg0: &mut Profile<Ty0>): &mut VecMap<ID, Stake> {
B0:
	0: MoveLoc[0](Arg0: &mut Profile<Ty0>)
	1: MutBorrowFieldGeneric[1](Profile.stakes: VecMap<ID, Stake>)
	2: Ret
}

}
