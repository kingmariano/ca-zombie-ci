import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(comptrollerAddr: Address, users: [Address], pools: [Address]): {Address: {Address: {String: AnyStruct}}} {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    var res: {Address: {Address: {String: AnyStruct}}} = {}
    for u in users {
        var m: {Address: {String: AnyStruct}} = {}
        for p in pools {
            m[p] = ref.getUserMarketInfo(userAddr: u, poolAddr: p)
        }
        res[u] = m
    }
    return res
}
