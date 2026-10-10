import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(comptrollerAddr: Address): {String: AnyStruct} {
    let ref = getAccount(comptrollerAddr).capabilities.borrow<&{LendingInterfaces.ComptrollerPublic}>(LendingConfig.ComptrollerPublicPath)
        ?? panic("no comptroller cap")
    let markets = ref.getAllMarkets()
    var infos: {Address: {String: AnyStruct}} = {}
    for m in markets {
        infos[m] = ref.getMarketInfo(poolAddr: m)
    }
    return {"markets": markets, "infos": infos}
}
