#!/usr/bin/env python3
"""Brute-force identify oracle selectors against plausible signatures."""
from Crypto.Hash import keccak
import itertools

cands = ["0x078dfbe7","0x08390a9d","0x34df5a6a","0x4300080b","0x455bf0b6","0x66331bba",
         "0x8dd09cac","0x9ca568a6","0x9eef6d74","0xe30c3978","0xf1c03adb","0x4e71e0c8",
         "0x6ab49b14","0xec3115f9","0x8da5cb5b","0xfc57d4df","0x48a1371b"]

def sel(sig):
    h=keccak.new(digest_bits=256); h.update(sig.encode()); return "0x"+h.hexdigest()[:8]

known = {
 "0x4e71e0c8": "Panic(uint256)",
 "0x8da5cb5b": "owner()",
 "0xfc57d4df": "getUnderlyingPrice(address)",
 "0x48a1371b": "getUnderlyingPrices(address[])",
 "0xec3115f9": "setPrices(address[],uint256[])",
}
# from OZ / common patterns
names = ["pendingOwner()","setPendingOwner(address)","transferOwnership(address)","claimOwnership()",
 "getUnderlyingDecimals(address)","setUnderlyingDecimals(address,uint8)","underlyingDecimals(address)",
 "setPrices(address[],uint256[])","setPrice(address,uint256)","setPriceSetter(address)","priceSetter()",
 "setKeeper(address)","keeper()","setOracle(address)","oracle()","poke()","pokePrices(address[])",
 "setPricesInEther(address[],uint256[])","getUnderlyingPriceInEther(address)","underlyingDecimals()",
 "getPrice(address)","prices(address)","setAssetPrice(address,uint256)","setUnderlyingPrice(address,uint256)",
 "setTokenPrice(address,uint256)","priceSetterAddress()","setPriceUpdater(address)","priceUpdater()",
 "getValue(address)","isPriceSetter(address)","setPriceSetter(address,bool)","setKeeper(address,bool)",
 "removePriceSetter(address)","addPriceSetter(address)","priceOf(address)","underlyingPrice(address)",
 "updatePrice(address,uint256)","updatePrices(address[],uint256[])","setPrices(address[],uint256)",
 "price(address)","getPrices(address[])","getUnderlyingPrices(address[])","setPrice(address,uint256,bool)",
 "decimals(address)","getDecimals(address)","setDecimals(address,uint8)","assetDecimals(address)",
 "setAssetDecimals(address,uint8)","setUnderlyingDecimal(address,uint8)","underlyingDecimal(address)",
 "initialize(address)","initialize(address,address)","name()","symbol()","decimals()","DOMAIN_SEPARATOR()",
 "acceptOwnership()","renounceOwnership()","setOwner(address)","setAdmin(address)","admin()","paused()",
 "setPaused(bool)","freeze()","unfreeze()","withdraw(address,uint256)","withdrawToken(address,uint256)",
 "setMaxPrice(address,uint256)","setMinPrice(address,uint256)","setPriceDeviation(uint256)",
 "setTimelock(uint256)","getUnderlyingPrice(address,address)","getUnderlyingPrice(address[])",
 "getUnderlyingPriceInUSD(address)","priceDecimals(address)","setPriceDecimals(address,uint8)",
 "setTokenDecimals(address,uint8)","setDecimals(address,uint8,uint8)","getPriceInETH(address)",
 "pokePrice(address)","pokePrices(address[])","setPricesInUsd(address[],uint256[])",
 "setPricesInUSD(address[],uint256[])","getUnderlyingPrices()","getUnderlyingPrice()",
 "operator()","setOperator(address)","feeReceiver()","setFeeReceiver(address)",
 "setPriceSetterAddress(address)","setPriceSetters(address[],bool[])","priceSetters(address)",
 "ownerPrice()","setOwnerPrice(address,uint256)","price52week(address)","prices0(address)",
 "getUnderlyingDecimals()","setUnderlyingDecimals(address[])","setUnderlyingDecimals(address)",
 "setUnderlyingDecimal()","setUnderlyingDecimals(address[],uint8[])","assetTeacher()",
 "setAssetTeacher(address)","teacher()","getTokenDecimals(address)","setTokenDecimals(address,uint8)",
 "isKeeper(address)","setIsKeeper(address,bool)","keepers(address)","priceSetter(address)",
 "getPrices(address[],address[])","setPriceBatch(address[],uint256[])","setPricesBatch(address[],uint256[])",
]
m = {sel(n): n for n in names}
for c in cands:
    print(c, "=>", known.get(c) or m.get(c) or "??")
print()
# also try 0x08390a9d etc with variations
extra = ["getUnderlyingPriceBatch(address[])","setPrice(address[],uint256[])","setUnderlyingPrice(address[],uint256[])",
 "getUnderlyingPrices(address[],address)","priceOfAsset(address)","getAssetPrice(address)",
 "setAssetPrice(address,uint256,bool)","assetPrice(address)","prices(address,address)",
 "getPrice(address,address)","setPrices(address[],uint256[],uint8[])","batchSetPrices(address[],uint256[])"]
m2 = {sel(n): n for n in extra}
for c in cands:
    if m2.get(c): print("EXTRA", c, "=>", m2[c])
