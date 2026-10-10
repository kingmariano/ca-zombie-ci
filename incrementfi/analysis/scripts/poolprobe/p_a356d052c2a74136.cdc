import LendingPool from 0xa356d052c2a74136
import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(): {String: AnyStruct} {
    let ref = getAccount(0xa356d052c2a74136).capabilities.borrow<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath)
        ?? panic("no pool cap")
    return {
        "pool": LendingPool.poolAddress,
        "comptroller": LendingPool.comptrollerAddress,
        "underlying": ref.getUnderlyingTypeString(),
        "cashScaled": ref.getPoolCash(),
        "totalSupplyScaled": ref.getPoolTotalSupplyScaled(),
        "totalBorrowsScaled": ref.getPoolTotalBorrowsScaled(),
        "totalReservesScaled": ref.getPoolTotalReservesScaled(),
        "supplierCount": ref.getPoolSupplierCount(),
        "borrowerCount": ref.getPoolBorrowerCount(),
        "certType": ref.getPoolCertificateType().identifier
    }
}
