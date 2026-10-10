import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(comptrollerAddr: Address, users: [Address]): {Address: [String; 3]} {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    var res: {Address: [String; 3]} = {}
    for u in users {
        res[u] = ref.getUserCrossMarketLiquidity(userAddr: u)
    }
    return res
}
