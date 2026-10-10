import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(pools: [Address]): {Address: {String: AnyStruct}} {
    var res: {Address: {String: AnyStruct}} = {}
    for p in pools {
        let ref = getAccount(p).capabilities.borrow<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath)!
        res[p] = {
            "fullType": ref.getUnderlyingAssetType(),
            "flashloanRateBps": ref.getFlashloanRateBps(),
            "cashScaled": ref.getPoolCash(),
            "reservesScaled": ref.getPoolTotalReservesScaled()
        }
    }
    return res
}
