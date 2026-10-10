import LendingPool from 0x67539e86cbe9b261

access(all) fun main(): String {
    let c <- create LendingPool.PoolCertificate()
    destroy c
    return "CREATED"
}
