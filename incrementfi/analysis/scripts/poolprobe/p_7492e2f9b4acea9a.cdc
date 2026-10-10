import LendingPool from 0x7492e2f9b4acea9a
import LendingInterfaces from 0x2df970b6cdee5735
import LendingConfig from 0x2df970b6cdee5735

access(all) fun main(): {String: AnyStruct} {
    let ref = getAccount(0x7492e2f9b4acea9a).capabilities.borrow<&{LendingInterfaces.PoolPublic}>(LendingConfig.PoolPublicPublicPath)
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
