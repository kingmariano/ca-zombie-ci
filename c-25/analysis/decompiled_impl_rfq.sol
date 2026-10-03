[38;5;8m# Palkeoramix decompiler. [0m

[95mconst [0munknown637fec51 = [1m0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744[0m
[95mconst [0munknown7179a12c = [1m0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774[0m
[95mconst [0munknown94be834d = [1m120[0m
[95mconst [0munknownb9e7bce6 = [1m100[0m

[32mdef [0mstorage:
  [32mstor4083388403051261561560495289181218537472[0m is mapping of uint8 [38;5;8mat storage 0xc00000000000000000000000000000000[0m
  [32munknown5df4fd38[0m is mapping of uint32 [38;5;8mat storage 0xc00000000000000000000000000000001[0m
  [32mstor4083388403051261561560495289181218537474[0m is mapping of uint8 [38;5;8mat storage 0xc00000000000000000000000000000002[0m
  [32mstor4083388403051261561560495289181218537475[0m is mapping of address [38;5;8mat storage 0xc00000000000000000000000000000003[0m
  [32mstorC000[0m is address [38;5;8mat storage 0xc00000000000000000000000000000004[0m[38;5;8m[0m
  [32mstorC000[0m is address [38;5;8mat storage 0xc00000000000000000000000000000005[0m[38;5;8m[0m

[95mdef [0munknown5d4d8fe7(uint256 [32m_param1[0m, uint256 [32m_param2[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
  return bool([32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m)

[95mdef [0munknown5df4fd38(uint256 [32m_param1[0m, uint256 [32m_param2[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  return [32munknown5df4fd38[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m[32m[[0m[32m_param2[0m[32m][0m

[38;5;8m#
#  Regular functions
#[0m

[95mdef [0m_fallback(?)[95m payable[0m: [38;5;8m# default function[0m
  revert

[95mdef [0munknown9227b794(): [38;5;8m# not payable[0m
  return [32mstorC000[0m, [32mstorC000[0m

[95mdef [0misSupportedToken(address [32mtoken[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m32
  require [32mtoken[0m[1m == [0m[32mtoken[0m
  return bool([32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32mtoken[0m[38;5;8m)[0m[32m][0m), [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32mtoken[0m[38;5;8m)[0m[32m][0m

[95mdef [0mregisterAllowedOrderSigner(address [32msigner[0m, bool [32mallowed[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require [32msigner[0m[1m == [0m[32msigner[0m
  require [32mallowed[0m[1m == [0m[32mallowed[0m
  [32mstorC000[0m[32m[[0mcaller[32m][0m[32m[[0m[38;5;8maddress([0m[32msigner[0m[38;5;8m)[0m[32m][0m = [38;5;8muint8([0m[32mallowed[0m[38;5;8m)[0m

[95mdef [0munknown01e480ab(uint256 [32m_param1[0m, uint256 [32m_param2[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with 0, 'Rfq: ownerFetchFailed'
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with 0, 'Rfq: onlyOwner'
  [32mstorC000[0m = [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  [32mstorC000[0m = [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m

[95mdef [0munknown2ba8d939(uint256 [32m_param1[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m32
  require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with 0, 'Rfq: ownerFetchFailed'
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with 0, 'Rfq: onlyOwner'
  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m:
      revert with 0, 'Rfq: address not registered'
  [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m = 0
  [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m = 0

[95mdef [0munknown06c1f431(): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require cd[4][1m <= [0mLOCK8605463013()
  require calldata.size[1m >′ [0mcd[4] + 35
  if [32m('cd', 4).length[0m[1m > [0mLOCK8605463013():
      revert with 0, 65
  if ceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[1m < [0m96[1m or [0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[1m > [0mLOCK8605463013():
      revert with 0, 65
  [95mmem[[0m96[95m][0m = [32m('cd', 4).length[0m
  require cd[4] + (32[1m * [0m[32m('cd', 4).length[0m) + 36[1m <= [0mcalldata.size
  [94ms[0m = 128
  [94midx[0m = cd[4] + 36
  [32mwhile [0m[94midx[0m[1m < [0mcd[4] + (32[1m * [0m[32m('cd', 4).length[0m) + 36[32m:[0m
      [95mmem[[0m[94ms[0m[95m][0m = cd[[94midx[0m]
      [94ms[0m = [94ms[0m + 32
      [94midx[0m = [94midx[0m + 32
      [32mcontinue [0m
  require cd[36][1m == [0m[38;5;8maddress([0mcd[36][38;5;8m)[0m
  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0mcd[36][38;5;8m)[0m[32m][0m[32m[[0mcaller[32m][0m:
      revert with 0, 'Rfq: OnlyOrderMakerAllowed'
  [94midx[0m = 0
  [32mwhile [0m[94midx[0m[1m < [0m[32m('cd', 4).length[0m[32m:[0m
      if [94midx[0m[1m >= [0m[95mmem[[0m96[95m][0m:
          revert with 0, 50
      [95mmem[[0m0[95m][0m = [95mmem[[0m(32[1m * [0m[94midx[0m) + 128[95m][0m
      [95mmem[[0m32[95m][0m = sha3(caller, 0xc00000000000000000000000000000001)
      [32munknown5df4fd38[0m[32m[[0mcaller[32m][0m[32m[[0m[95mmem[[0m(32[1m * [0m[94midx[0m) + 128[95m][0m[32m][0m = 2147483652
      if [94midx[0m[1m >= [0m[95mmem[[0m96[95m][0m:
          revert with 0, 50
      [95mmem[[0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[95m][0m = [95mmem[[0m(32[1m * [0m[94midx[0m) + 128[95m][0m
      [38;5;8mlog 0xaf63b720: mem[ceil32(32 * ('cd', 4).length) + 97], caller[0m
      if not [94midx[0m + 1:
          revert with 0, 17
      [94midx[0m = [94midx[0m + 1
      [32mcontinue [0m

[95mdef [0munknowndcbbc8d4(): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m64
  require cd[4][1m <= [0mLOCK8605463013()
  require cd[4] + 35[1m <′ [0mcalldata.size
  if [32m('cd', 4).length[0m[1m > [0mLOCK8605463013():
      revert with 0, 65
  if ceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[1m < [0m96[1m or [0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[1m > [0mLOCK8605463013():
      revert with 0, 65
  [95mmem[[0m96[95m][0m = [32m('cd', 4).length[0m
  require cd[4] + (32[1m * [0m[32m('cd', 4).length[0m) + 36[1m <= [0mcalldata.size
  [94midx[0m = cd[4] + 36
  [94ms[0m = 128
  [32mwhile [0m[94midx[0m[1m < [0mcd[4] + (32[1m * [0m[32m('cd', 4).length[0m) + 36[32m:[0m
      require cd[[94midx[0m][1m == [0m[38;5;8maddress([0mcd[[94midx[0m][38;5;8m)[0m
      [95mmem[[0m[94ms[0m[95m][0m = cd[[94midx[0m]
      [94midx[0m = [94midx[0m + 32
      [94ms[0m = [94ms[0m + 32
      [32mcontinue [0m
  require cd[36][1m <= [0mLOCK8605463013()
  require cd[36] + 35[1m <′ [0mcalldata.size
  if [32m('cd', 36).length[0m[1m > [0mLOCK8605463013():
      revert with 0, 65
  if ceil32(32[1m * [0m[32m('cd', 36).length[0m) + 98[1m < [0m97[1m or [0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + ceil32(32[1m * [0m[32m('cd', 36).length[0m) + 98[1m > [0mLOCK8605463013():
      revert with 0, 65
  [95mmem[[0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + 97[95m][0m = [32m('cd', 36).length[0m
  require cd[36] + (32[1m * [0m[32m('cd', 36).length[0m) + 36[1m <= [0mcalldata.size
  [94midx[0m = cd[36] + 36
  [94ms[0m = ceil32(32[1m * [0m[32m('cd', 4).length[0m) + 129
  [32mwhile [0m[94midx[0m[1m < [0mcd[36] + (32[1m * [0m[32m('cd', 36).length[0m) + 36[32m:[0m
      require cd[[94midx[0m][1m == [0m[38;5;8maddress([0mcd[[94midx[0m][38;5;8m)[0m
      [95mmem[[0m[94ms[0m[95m][0m = cd[[94midx[0m]
      [94midx[0m = [94midx[0m + 32
      [94ms[0m = [94ms[0m + 32
      [32mcontinue [0m
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  [95mmem[[0mceil32(32[1m * [0m[32m('cd', 4).length[0m) + ceil32(32[1m * [0m[32m('cd', 36).length[0m) + 98[95m][0m = ext_call.return_data[0]
  if not ext_call.success:
      revert with 0, 'Rfq: ownerFetchFailed'
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with 0, 'Rfq: onlyOwner'
  if [32m('cd', 4).length[0m != [32m('cd', 36).length[0m:
      revert with 0, 'Rfq: length mismatch'
  [94midx[0m = 0
  [32mwhile [0m[94midx[0m[1m < [0m[32m('cd', 4).length[0m[32m:[0m
      if [94midx[0m[1m >= [0m[32m('cd', 4).length[0m:
          revert with 0, 50
      [32mstorC000[0m[32m[[0m[95mmem[[0m(32[1m * [0m[94midx[0m) + 140[95m len [0m20[95m][0m[32m][0m = 1
      if [94midx[0m[1m >= [0m[32m('cd', 36).length[0m:
          revert with 0, 50
      if [94midx[0m[1m >= [0m[32m('cd', 4).length[0m:
          revert with 0, 50
      [95mmem[[0m0[95m][0m = [95mmem[[0m(32[1m * [0m[94midx[0m) + 140[95m len [0m20[95m][0m
      [95mmem[[0m32[95m][0m = 0xc00000000000000000000000000000003
      [32mstorC000[0m[32m[[0m[95mmem[[0m(32[1m * [0m[94midx[0m) + 140[95m len [0m20[95m][0m[32m][0m = [95mmem[[0m(32[1m * [0m[94midx[0m) + ceil32(32[1m * [0m[32m('cd', 4).length[0m) + 141[95m len [0m20[95m][0m
      if not [94midx[0m + 1:
          revert with 0, 17
      [94midx[0m = [94midx[0m + 1
      [32mcontinue [0m

[95mdef [0munknowncbfd8657(uint256 [32m_param1[0m, uint256 [32m_param2[0m, uint256 [32m_param3[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m96
  require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
  require [32m_param2[0m[1m == [0m[38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m
  require [32m_param3[0m[1m == [0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m
  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m:
      revert with 0, 'Rfq: notSupportedToken'
  static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size[1m >=′ [0m160
  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
  if [38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[1m > [0m255:
      revert with 0, 17
  if not [38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m:
      if [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
          revert with 0, 17
      return ([38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])
  if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
      if [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
          revert with 0, 17
      if not 10^[38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m:
          revert with 0, 18
      return ([38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m)
  [94ms[0m = 10
  [94mt[0m = 1
  [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0m[32m_param3[0m[38;5;8m)[0m + 2[38;5;8m)[0m
  [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
      if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
          revert with 0, 17
      if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
          [94mt[0m = [94mt[0m
          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
          [32mcontinue [0m
      [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
      [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
      [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
      [32mcontinue [0m
  if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
      revert with 0, 17
  if [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
      revert with 0, 17
  if not [94ms[0m[1m * [0m[94mt[0m:
      revert with 0, 18
  return ([38;5;8muint128([0m[32m_param2[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m[94ms[0m[1m * [0m[94mt[0m)

[95mdef [0munknown4112e1c2(uint256 [32m_param1[0m, uint256 [32m_param2[0m, uint256 [32m_param3[0m, uint256 [32m_param4[0m, uint256 [32m_param5[0m, uint256 [32m_param6[0m, uint256 [32m_param7[0m, uint256 [32m_param8[0m, uint256 [32m_param9[0m, uint256 [32m_param10[0m, uint256 [32m_param11[0m, uint256 [32m_param12[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m384
  require calldata.size - 4[1m >=′ [0m256
  require calldata.size - 260[1m >=′ [0m128
  require [32m_param12[0m[1m == [0m[38;5;8muint8([0m[32m_param12[0m[38;5;8m)[0m
  if -[38;5;8muint8([0m[32m_param12[0m[38;5;8m)[0m + 2:
      require [32m_param12[0m[1m == [0m[38;5;8muint8([0m[32m_param12[0m[38;5;8m)[0m
      if -[38;5;8muint8([0m[32m_param12[0m[38;5;8m)[0m + 3:
          revert with 0, 'Rfq: undefinedSignatureType'
      require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
      require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
      require [32m_param3[0m[1m == [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m
      require [32m_param4[0m[1m == [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m
      require [32m_param5[0m[1m == [0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m
      require [32m_param6[0m[1m == [0m[38;5;8maddress([0m[32m_param6[0m[38;5;8m)[0m
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      require [32m_param9[0m[1m == [0m[38;5;8muint8([0m[32m_param9[0m[38;5;8m)[0m
      [94msigner[0m = erecover(sha3('\x19Ethereum Signed Message:\n32', sha3([38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m, [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m, [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m, [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m, [38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m, [38;5;8maddress([0m[32m_param6[0m[38;5;8m)[0m, [38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m, [32m_param8[0m)), [32m_param9[0m[1m << [0m248, [32m_param10[0m, [32m_param11[0m) [38;5;8m# precompiled[0m
      if not erecover.result:
          revert with ext_call.return_data[0 len return_data.size]
      require [32m_param5[0m[1m == [0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m
      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m[32m][0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3('\x19Ethereum Signed Message:\n32', sha3(address(_param1), address(_param2), uint128(_param3), uint128(_param4), address(_param5), address(_param6), uint64(_param7), _param8)), 2147483904[0m
          revert with 0, 'Rfq: notAllowedMaker'
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      if block.timestamp[1m > [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3('\x19Ethereum Signed Message:\n32', sha3(address(_param1), address(_param2), uint128(_param3), uint128(_param4), address(_param5), address(_param6), uint64(_param7), _param8)), 2147483649[0m
          revert with 0, 'Rfq: expired'
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      if block.timestamp[1m > [0mblock.timestamp + 120:
          revert with 0, 17
      if block.timestamp + 120[1m < [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3('\x19Ethereum Signed Message:\n32', sha3(address(_param1), address(_param2), uint128(_param3), uint128(_param4), address(_param5), address(_param6), uint64(_param7), _param8)), 2147483649[0m
          revert with 0, 'Rfq: unexpectedExpiry'
      if [32munknown5df4fd38[0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m[32m[[0m[32m_param8[0m[32m][0m:
          if [32munknown5df4fd38[0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m[32m[[0m[32m_param8[0m[32m][0m - 2147483652:
              [38;5;8mlog 0xfe345684: _param8, address(signer), sha3('\x19Ethereum Signed Message:\n32', sha3(address(_param1), address(_param2), uint128(_param3), uint128(_param4), address(_param5), address(_param6), uint64(_param7), _param8)), 2147483653[0m
              revert with 0, 'Rfq: reusedSalt'
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3('\x19Ethereum Signed Message:\n32', sha3(address(_param1), address(_param2), uint128(_param3), uint128(_param4), address(_param5), address(_param6), uint64(_param7), _param8)), unknown5df4fd38[address(signer)][_param8][0m
          revert with 0, 'Rfq: canceledOrder'
      require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
      require [32m_param3[0m[1m == [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m
      require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
      require [32m_param4[0m[1m == [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m
      if [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m - [32mstorC000[0m:
          static call [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m.decimals() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m32
          require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
          if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m:
              revert with 0, 'Rfq: notSupportedToken'
          static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m160
          require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
          require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
          if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
              revert with 0, 17
          if [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m - [32mstorC000[0m:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                              revert with 0, 17
                      else:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                              revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
          else:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                      else:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [32mstorC000[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                              revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
      else:
          static call [32mstorC000[0m.decimals() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m32
          require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
          if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
              revert with 0, 'Rfq: notSupportedToken'
          static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m160
          require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
          require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
          if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
              revert with 0, 17
          if not [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m - [32mstorC000[0m:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                      else:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [32mstorC000[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                              revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
          else:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                      else:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                              revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
  else:
      require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
      require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
      require [32m_param3[0m[1m == [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m
      require [32m_param4[0m[1m == [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m
      require [32m_param5[0m[1m == [0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m
      require [32m_param6[0m[1m == [0m[38;5;8maddress([0m[32m_param6[0m[38;5;8m)[0m
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      require [32m_param9[0m[1m == [0m[38;5;8muint8([0m[32m_param9[0m[38;5;8m)[0m
      [94msigner[0m = erecover(sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m, [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m, [32m_param3[0m[1m << [0m128, [32m_param4[0m[1m << [0m128, [38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m, [38;5;8maddress([0m[32m_param6[0m[38;5;8m)[0m, [32m_param7[0m[1m << [0m192, [32m_param8[0m)), [32m_param9[0m[1m << [0m248, [32m_param10[0m, [32m_param11[0m) [38;5;8m# precompiled[0m
      if not erecover.result:
          revert with ext_call.return_data[0 len return_data.size]
      require [32m_param5[0m[1m == [0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m
      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param5[0m[38;5;8m)[0m[32m][0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147483904[0m
          revert with 0, 'Rfq: notAllowedMaker'
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      if block.timestamp[1m > [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147483649[0m
          revert with 0, 'Rfq: expired'
      require [32m_param7[0m[1m == [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m
      if block.timestamp[1m > [0mblock.timestamp + 120:
          revert with 0, 17
      if block.timestamp + 120[1m < [0m[38;5;8muint64([0m[32m_param7[0m[38;5;8m)[0m:
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147483649[0m
          revert with 0, 'Rfq: unexpectedExpiry'
      if [32munknown5df4fd38[0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m[32m[[0m[32m_param8[0m[32m][0m:
          if [32munknown5df4fd38[0m[32m[[0m[38;5;8maddress([0m[94msigner[0m[38;5;8m)[0m[32m][0m[32m[[0m[32m_param8[0m[32m][0m - 2147483652:
              [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147483653[0m
              revert with 0, 'Rfq: reusedSalt'
          [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), unknown5df4fd38[address(signer)][_param8][0m
          revert with 0, 'Rfq: canceledOrder'
      require [32m_param1[0m[1m == [0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m
      require [32m_param3[0m[1m == [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m
      require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
      require [32m_param4[0m[1m == [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m
      if not [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m - [32mstorC000[0m:
          static call [32mstorC000[0m.decimals() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m32
          require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
          if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
              revert with 0, 'Rfq: notSupportedToken'
          static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m160
          require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
          require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
          if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
              revert with 0, 17
          if [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m - [32mstorC000[0m:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <= [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                                  revert with 0, 17
                      else:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
                          else:
                              if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147549184[0m
                      revert with 0, 'Rfq: priceLoss'
                  if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
          else:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
                              if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                                  revert with 0, 17
                      else:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
                          else:
                              if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [32mstorC000[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147549184[0m
                      revert with 0, 'Rfq: priceLoss'
                  if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
      else:
          static call [38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m.decimals() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m32
          require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
          if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m:
              revert with 0, 'Rfq: notSupportedToken'
          static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param1[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                  gas gas_remaining [38;5;8mwei[0m
          if not ext_call.success:
              revert with ext_call.return_data[0 len return_data.size]
          require return_data.size[1m >=′ [0m160
          require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
          require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
          if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
              revert with 0, 17
          if not [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m - [32mstorC000[0m:
              if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [32mstorC000[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <= [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                                  revert with 0, 17
                      else:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
                          else:
                              if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
              else:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [32mstorC000[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[32mstorC000[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147549184[0m
                      revert with 0, 'Rfq: priceLoss'
                  if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
          else:
              if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                      revert with 0, 17
                  static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m32
                  require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                  if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                      revert with 0, 'Rfq: notSupportedToken'
                  static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                          gas gas_remaining [38;5;8mwei[0m
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  require return_data.size[1m >=′ [0m160
                  require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                  require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                  if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                      revert with 0, 17
                  if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                          if (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <=′ [0m100:
                              [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m
                      [38;5;8mlog 0xfe345684: _param8, address(signer), sha3(0, 0xa4d80e3cd2aa6cf42ef8028f5adea3f05ca71f2cef487c03752ffacc5f401744, sha3(0x46e59923f17b5627646501951ad18c29fa5dd0c85596ac8820a64eaa2574d774, address(_param1), address(_param2), _param3 << 128, _param4 << 128, address(_param5), address(_param6), _param7 << 192, _param8)), 2147549184[0m
                      revert with 0, 'Rfq: priceLoss'
                  if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                          revert with 0, 17
                      if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
                      else:
                          if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              revert with 0, 18
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                              revert with 0, 17
              else:
                  if not [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m[1m and [0mnot [38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m:
                      [94ms[0m = 10
                      [94mt[0m = 1
                      [94midx[0m = [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m
                      [32mwhile [0m[94midx[0m[1m > [0m1[32m:[0m
                          if [94ms[0m[1m > [0m-1[1m / [0m[94ms[0m:
                              revert with 0, 17
                          if not [38;5;8mbool([0m[94midx[0m[38;5;8m)[0m:
                              [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                              [94mt[0m = [94mt[0m
                              [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                              [32mcontinue [0m
                          [94ms[0m = [94ms[0m[1m * [0m[94ms[0m
                          [94mt[0m = [94ms[0m[1m * [0m[94mt[0m
                          [94midx[0m = [38;5;8muint255([0m[94midx[0m[38;5;8m)[0m[1m * [0m0.5
                          [32mcontinue [0m
                      if [94mt[0m[1m > [0m-1[1m / [0m[94ms[0m:
                          revert with 0, 17
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not [94ms[0m[1m * [0m[94mt[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                  else:
                      if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                          revert with 0, 17
                      if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          revert with 0, 18
                      static call [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m.decimals() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m32
                      require ext_call.return_data[0][1m == [0mext_call.return_data[31 len 1]
                      if not [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m:
                          revert with 0, 'Rfq: notSupportedToken'
                      static call [32mstorC000[0m[32m[[0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m[32m][0m.latestRoundData() with:
                              gas gas_remaining [38;5;8mwei[0m
                      if not ext_call.success:
                          revert with ext_call.return_data[0 len return_data.size]
                      require return_data.size[1m >=′ [0m160
                      require ext_call.return_data[0][1m == [0mext_call.return_data[22 len 10]
                      require ext_call.return_data[128][1m == [0mext_call.return_data[150 len 10]
                      if [38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[1m > [0m255:
                          revert with 0, 17
                      if not [38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m >=′ [0m0:
                              revert with 0, 17
                          if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m /′ [0m10000:
                              revert with 0, 17
                          if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                              if not [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
                          else:
                              if not [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32]:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m == [0m-1[1m and [0m(10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32])[1m == [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                  revert with 0, 17
                      else:
                          if bool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m78[38;5;8m)[0m)[1m or [0mbool([38;5;8mbool([0m[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m < [0m32[38;5;8m)[0m):
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m != [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0mext_call.return_data[32][1m and [0mext_call.return_data[32]:
                                  revert with 0, 17
                              if not 10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  revert with 0, 18
                              if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m <′ [0m0[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m <′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m or [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m >′ [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m and [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m >=′ [0m0:
                                  revert with 0, 17
                              if True[1m and [0m([38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - ([38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) != (10000[1m * [0m[38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m) - (10000[1m * [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m)[1m /′ [0m10000:
                                  revert with 0, 17
                              if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m[1m > [0m[38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                                  if [38;5;8muint128([0m[32m_param3[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
                              else:
                                  if [38;5;8muint128([0m[32m_param4[0m[38;5;8m)[0m[1m * [0mext_call.return_data[32][1m / [0m10^[38;5;8muint8([0m[38;5;8muint8([0mext_call.return_data[0][38;5;8m)[0m + 2[38;5;8m)[0m:
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m


