// Move bytecode v6
module a90218c8ec02c619b2b4db3e3d32cfeb5c1cf762879ef75bae9f27020751d0f8.account {
use 0000000000000000000000000000000000000000000000000000000000000001::string;
use 0000000000000000000000000000000000000000000000000000000000000002::object;
use 0000000000000000000000000000000000000000000000000000000000000002::package;
use 0000000000000000000000000000000000000000000000000000000000000002::transfer;
use 0000000000000000000000000000000000000000000000000000000000000002::tx_context;

struct Account has store, key {
	id: UID,
	alias: String
}

struct AccountRequest {
	account: address
}

struct ACCOUNT has drop {
	dummy_field: bool
}

init(Arg0: ACCOUNT, Arg1: &mut TxContext) {
B0:
	0: MoveLoc[0](Arg0: ACCOUNT)
	1: MoveLoc[1](Arg1: &mut TxContext)
	2: Call package::claim_and_keep<ACCOUNT>(ACCOUNT, &mut TxContext)
	3: Ret
}

public new(Arg0: String, Arg1: &mut TxContext): Account {
B0:
	0: MoveLoc[1](Arg1: &mut TxContext)
	1: Call object::new(&mut TxContext): UID
	2: MoveLoc[0](Arg0: String)
	3: Pack[0](Account)
	4: Ret
}

public request(Arg0: &TxContext): AccountRequest {
B0:
	0: MoveLoc[0](Arg0: &TxContext)
	1: Call tx_context::sender(&TxContext): address
	2: Pack[1](AccountRequest)
	3: Ret
}

public request_with_account(Arg0: &Account): AccountRequest {
L1:	loc0: ID
B0:
	0: MoveLoc[0](Arg0: &Account)
	1: Call object::id<Account>(&Account): ID
	2: StLoc[1](loc0: ID)
	3: ImmBorrowLoc[1](loc0: ID)
	4: Call object::id_to_address(&ID): address
	5: Pack[1](AccountRequest)
	6: Ret
}

public destroy(Arg0: AccountRequest): address {
B0:
	0: MoveLoc[0](Arg0: AccountRequest)
	1: Unpack[1](AccountRequest)
	2: Ret
}

public receive<Ty0: store + key>(Arg0: &mut Account, Arg1: Receiving<Ty0>): Ty0 {
B0:
	0: MoveLoc[0](Arg0: &mut Account)
	1: MutBorrowField[0](Account.id: UID)
	2: MoveLoc[1](Arg1: Receiving<Ty0>)
	3: Call transfer::public_receive<Ty0>(&mut UID, Receiving<Ty0>): Ty0
	4: Ret
}

}
