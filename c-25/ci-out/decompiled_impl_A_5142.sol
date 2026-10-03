[38;5;8m# Palkeoramix decompiler. [0m

[95mconst [0mFEATURE_VERSION = [1munknown10000000()[0m
[95mconst [0mFEATURE_NAME = [1m'SailUniswapFeature', 0[0m

[38;5;8m#
#  Regular functions
#[0m

[95mdef [0m_fallback(?)[95m payable[0m: [38;5;8m# default function[0m
  revert

[95mdef [0munknown171a2517(array [32m_param1[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m256
  require [32m_param1[0m[1m <= [0mLOCK8605463013()
  require [32m_param1[0m + 35[1m <′ [0mcalldata.size
  require [32m_param1.length[0m[1m <= [0mLOCK8605463013()
  require (32[1m * [0m[32m_param1.length[0m) + 128[1m <= [0mLOCK8605463013()[1m and [0m(32[1m * [0m[32m_param1.length[0m) + 128[1m >= [0m96
  require calldata.size[1m >= [0m[32m_param1[0m + (32[1m * [0m[32m_param1.length[0m) + 36
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m

[95mdef [0munknown78a9f28b(array [32m_param1[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m320
  require [32m_param1[0m[1m <= [0mLOCK8605463013()
  require [32m_param1[0m + 35[1m <′ [0mcalldata.size
  require [32m_param1.length[0m[1m <= [0mLOCK8605463013()
  require (32[1m * [0m[32m_param1.length[0m) + 128[1m <= [0mLOCK8605463013()[1m and [0m(32[1m * [0m[32m_param1.length[0m) + 128[1m >= [0m96
  require calldata.size[1m >= [0m[32m_param1[0m + (32[1m * [0m[32m_param1.length[0m) + 36
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m

[95mdef [0muniswapV3SwapCallback(int256 [32mamount0Delta[0m, int256 [32mamount1Delta[0m, bytes [32mdata[0m): [38;5;8m# not payable[0m
  require calldata.size - 4[1m >=′ [0m96
  require [32mdata[0m[1m <= [0mLOCK8605463013()
  require [32mdata[0m + 35[1m <′ [0mcalldata.size
  require [32mdata.length[0m[1m <= [0mLOCK8605463013()
  require [32mdata[0m + [32mdata.length[0m + 36[1m <= [0mcalldata.size
  static call caller.token0() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  static call caller.token1() with:
          gas gas_remaining [38;5;8mwei[0m
  static call caller.fee() with:
          gas gas_remaining [38;5;8mwei[0m
  if [38;5;8maddress([0msha3(1204786273842544410698595, sha3(ext_call.return_data[0], ext_call.return_data[0], ext_call.return_data[0]), 0xe34f199b19b2b4f47f68442619d555527d244f78a3297ea89325f843f87b8b54)[38;5;8m)[0m != caller:
      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a2062616420706f6f6c
  if [32mamount0Delta[0m[1m <=′ [0m0:
      if [32mamount1Delta[0m[1m <=′ [0m0:
          stop
  if eth.balance(this.address)[1m < [0m0:
      revert with 0, 'Address: insufficient balance for call'
  if not ext_code.size([38;5;8maddress([0mext_call.return_data[0][38;5;8m)[0m):
      revert with 0, 'Address: call to non-contract'
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m

[95mdef [0munknown1770400e(array [32m_param1[0m, uint256 [32m_param2[0m, uint256 [32m_param3[0m, uint256 [32m_param4[0m, bool [32m_param5[0m, uint256 [32m_param6[0m, array [32m_param7[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m256
  require [32m_param1[0m[1m <= [0mLOCK8605463013()
  require [32m_param1[0m + 35[1m <′ [0mcalldata.size
  require [32m_param1.length[0m[1m <= [0mLOCK8605463013()
  require [32m_param1[0m + (32[1m * [0m[32m_param1.length[0m) + 36[1m <= [0mcalldata.size
  require [32m_param2[0m[1m == [0m[38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m
  require [32m_param3[0m[1m == [0m[38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m
  require [32m_param4[0m[1m == [0m[38;5;8maddress([0m[32m_param4[0m[38;5;8m)[0m
  require [32m_param6[0m[1m == [0m[38;5;8maddress([0m[32m_param6[0m[38;5;8m)[0m
  require [32m_param7[0m[1m <= [0mLOCK8605463013()
  require [32m_param7[0m + 35[1m <′ [0mcalldata.size
  require [32m_param7.length[0m[1m <= [0mLOCK8605463013()
  require [32m_param7[0m + (32[1m * [0m[32m_param7.length[0m) + 36[1m <= [0mcalldata.size
  if [32m_param7.length[0m != [32m_param1.length[0m:
      revert with 0, 'UNI: length mismatch'
  if [38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m != 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee:
      if call.value:
          revert with 0, 'UNI: msg.value > 0'
      if [32m_param5[0m:
          if eth.balance(this.address)[1m < [0m0:
              revert with 0, 'Address: insufficient balance for call'
          if not ext_code.size([38;5;8maddress([0m[32m_param2[0m[38;5;8m)[0m):
              revert with 0, 'Address: call to non-contract'
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m

[95mdef [0mmigrate(): [38;5;8m# not payable[0m
  require ext_code.size(this.address)
  call this.address.extend([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0xe2a7c86f00000000000000000000000000000000000000000000000000000000, 0x51429f2e88533de64d86fb86edabadac962c1743
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address.extend([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0x1770400e00000000000000000000000000000000000000000000000000000000, 0x51429f2e88533de64d86fb86edabadac962c1743
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address.extend([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0x171a251700000000000000000000000000000000000000000000000000000000, 0x51429f2e88533de64d86fb86edabadac962c1743
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address.extend([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0x78a9f28b00000000000000000000000000000000000000000000000000000000, 0x51429f2e88533de64d86fb86edabadac962c1743
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address.extend([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0xfa461e3300000000000000000000000000000000000000000000000000000000, 0x51429f2e88533de64d86fb86edabadac962c1743
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  return 0x2c64c5ef00000000000000000000000000000000000000000000000000000000

[95mdef [0munknowne2a7c86f()[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m160
  require cd[4][1m <= [0mLOCK8605463013()
  require cd[4] + 35[1m <′ [0mcalldata.size
  require [32m('cd', 4).length[0m[1m <= [0mLOCK8605463013()
  require cd[4] + (32[1m * [0m[32m('cd', 4).length[0m) + 36[1m <= [0mcalldata.size
  require cd[68][1m == [0m[38;5;8maddress([0mcd[68][38;5;8m)[0m
  require cd[100][1m == [0m[38;5;8maddress([0mcd[100][38;5;8m)[0m
  require cd[132][1m <= [0mLOCK8605463013()
  require cd[132] + 35[1m <′ [0mcalldata.size
  require [32m('cd', 132).length[0m[1m <= [0mLOCK8605463013()
  require cd[132] + (32[1m * [0m[32m('cd', 132).length[0m) + 36[1m <= [0mcalldata.size
  if [32m('cd', 132).length[0m != [32m('cd', 4).length[0m:
      revert with 0, 'UNI: length mismatch'
  require [32m('cd', 132).length[0m
  require [32m('cd', 132)[0][0m[1m <′ [0mcalldata.size + -cd[132] - 67
  require cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0mLOCK8605463013()
  require cd[132] + [32m('cd', 132)[0][0m + 68[1m <=′ [0mcalldata.size - (32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)])
  require 0[1m < [0m[32m('cd', 132).length[0m
  require [32m('cd', 132)[0][0m[1m <′ [0mcalldata.size + -cd[132] - 67
  require cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0mLOCK8605463013()
  require cd[132] + [32m('cd', 132)[0][0m + 68[1m <=′ [0mcalldata.size - (32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)])
  require cd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1[1m < [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]
  if not call.value:
      if [38;5;8maddress([0mcd[100][38;5;8m)[0m:
          if 0[1m >= [0m[32m('cd', 132).length[0m:
              if 0[1m < [0mcd[36]:
                  revert with 0, 'UNI: min return'
              if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                  require ext_code.size(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2)
                  call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.withdraw([38;5;8muint256[0m amount) with:
                       gas gas_remaining [38;5;8mwei[0m
                      args 0
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  call [38;5;8maddress([0mcd[100][38;5;8m)[0m with:
                       gas gas_remaining [38;5;8mwei[0m
                  return 0
              else:
                  return 0
          require 0[1m < [0m[32m('cd', 4).length[0m
          require 0[1m < [0m[32m('cd', 132).length[0m
          require [32m('cd', 132)[0][0m[1m <′ [0mcalldata.size + -cd[132] - 67
          require cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0mLOCK8605463013()
          require cd[132] + [32m('cd', 132)[0][0m + 68[1m <=′ [0mcalldata.size - (32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)])
          [95mmem[[0m128[95m len [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)][95m][0m = call.data[cd[132] + [32m('cd', 132)[0][0m + 68 len 32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]]
          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0
          if call.value:
              if call.value:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                      [94m_58[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if [95mmem[[0m128[95m][0m[1m and [0m'@':
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                              else:
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                          else:
                              if not [95mmem[[0m160[95m][0m[1m or [0mnot '@':
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                              else:
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], [38;5;8maddress([0m[95mmem[[0m160[95m][0m[38;5;8m)[0m, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_58[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_58[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [94m_58[0m):
                                      call [94m_58[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_58[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [94m_58[0m):
                                          call [94m_58[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_58[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_58[0m):
                                      call [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [38;5;8maddress([0m[94m_58[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                  else:
                      [94m_75[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, cd[100], 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_75[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_75[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_75[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_75[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_75[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_75[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_75[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_75[0m):
                                      call [38;5;8maddress([0m[94m_75[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
              else:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                      [94m_61[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if [95mmem[[0m128[95m][0m[1m and [0m'@':
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                              else:
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                          else:
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                          else:
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                          else:
                              if not [95mmem[[0m160[95m][0m[1m or [0mnot '@':
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                              else:
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], [38;5;8maddress([0m[95mmem[[0m160[95m][0m[38;5;8m)[0m, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_61[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_61[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [94m_61[0m):
                                          call [94m_61[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_61[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [94m_61[0m):
                                              call [94m_61[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_61[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [94m_61[0m):
                                          call [94m_61[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_61[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [94m_61[0m):
                                              call [94m_61[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_61[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_61[0m):
                                      call [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [38;5;8maddress([0m[94m_61[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                  else:
                      [94m_78[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, cd[100], 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_78[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_78[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_78[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_78[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_78[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_78[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_78[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_78[0m):
                                      call [38;5;8maddress([0m[94m_78[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
          else:
              if call.value:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                      [94m_64[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if [95mmem[[0m128[95m][0m[1m and [0m'@':
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                              else:
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                          else:
                              if not [95mmem[[0m160[95m][0m[1m or [0mnot '@':
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                              else:
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], [38;5;8maddress([0m[95mmem[[0m160[95m][0m[38;5;8m)[0m, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_64[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_64[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [94m_64[0m):
                                      call [94m_64[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_64[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [94m_64[0m):
                                          call [94m_64[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_64[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_64[0m):
                                      call [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [38;5;8maddress([0m[94m_64[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                  else:
                      [94m_81[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, cd[100], 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_81[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_81[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_81[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_81[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_81[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_81[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_81[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_81[0m):
                                      call [38;5;8maddress([0m[94m_81[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
              else:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                      [94m_67[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if [95mmem[[0m128[95m][0m[1m and [0m'@':
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                              else:
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                          else:
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                          if not ext_call.success:
                                              revert with ext_call.return_data[0 len return_data.size]
                                      else:
                                          if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                          else:
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                                              if not ext_call.success:
                                                  revert with ext_call.return_data[0 len return_data.size]
                          else:
                              if not [95mmem[[0m160[95m][0m[1m or [0mnot '@':
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                              else:
                                  if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                      if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                  else:
                                      static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                              gas gas_remaining [38;5;8mwei[0m
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                      if 96 != return_data.size:
                                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], [38;5;8maddress([0m[95mmem[[0m160[95m][0m[38;5;8m)[0m, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_67[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_67[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [94m_67[0m):
                                          call [94m_67[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_67[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [94m_67[0m):
                                              call [94m_67[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_67[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [94m_67[0m):
                                          call [94m_67[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_67[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [94m_67[0m):
                                              call [94m_67[0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [94m_67[0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_67[0m):
                                      call [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [38;5;8maddress([0m[94m_67[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                  else:
                      [94m_84[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mcd[100][38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, cd[100], 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_84[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_84[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_84[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_84[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_84[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_84[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_84[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_84[0m):
                                      call [38;5;8maddress([0m[94m_84[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], cd[100], 128, 0
      else:
          if 0[1m >= [0m[32m('cd', 132).length[0m:
              if 0[1m < [0mcd[36]:
                  revert with 0, 'UNI: min return'
              if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m > [0m0:
                  require ext_code.size(0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2)
                  call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.withdraw([38;5;8muint256[0m amount) with:
                       gas gas_remaining [38;5;8mwei[0m
                      args 0
                  if not ext_call.success:
                      revert with ext_call.return_data[0 len return_data.size]
                  call caller with:
                       gas gas_remaining [38;5;8mwei[0m
                  return 0
              else:
                  return 0
          require 0[1m < [0m[32m('cd', 4).length[0m
          require 0[1m < [0m[32m('cd', 132).length[0m
          require [32m('cd', 132)[0][0m[1m <′ [0mcalldata.size + -cd[132] - 67
          require cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0mLOCK8605463013()
          require cd[132] + [32m('cd', 132)[0][0m + 68[1m <=′ [0mcalldata.size - (32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)])
          [95mmem[[0m128[95m len [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)][95m][0m = call.data[cd[132] + [32m('cd', 132)[0][0m + 68 len 32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]]
          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0
          if call.value:
              if call.value:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m <= [0m0:
                      [94m_103[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [95mmem[[0m128[95m][0m):
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], caller, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_103[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_103[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_103[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_103[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if [94m_103[0m[1m and [0m'@':
                                  static call [38;5;8maddress([0m[94m_103[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if return_data.size[1m == [0m96:
                  else:
                      [94m_89[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_89[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_89[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_89[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_89[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_89[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_89[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_89[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_89[0m):
                                      call [38;5;8maddress([0m[94m_89[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
              else:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m <= [0m0:
                      [94m_106[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [95mmem[[0m128[95m][0m):
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], caller, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_106[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_106[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_106[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_106[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if [94m_106[0m[1m and [0m'@':
                                  static call [38;5;8maddress([0m[94m_106[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if return_data.size[1m == [0m96:
                  else:
                      [94m_92[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_92[0m[38;5;8m)[0m
                          call 0xc02aaa39b223fe8d0a0e5c4f27ead9083c756cc2.transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_92[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_92[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_92[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_92[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_92[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_92[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_92[0m):
                                      call [38;5;8maddress([0m[94m_92[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
          else:
              if call.value:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m <= [0m0:
                      [94m_109[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [95mmem[[0m128[95m][0m):
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], caller, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_109[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_109[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_109[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_109[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if [94m_109[0m[1m and [0m'@':
                                  static call [38;5;8maddress([0m[94m_109[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if return_data.size[1m == [0m96:
                  else:
                      [94m_95[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                  else:
                                      if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = this.address
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_95[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args this.address, [38;5;8maddress([0m[94m_95[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_95[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_95[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_95[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_95[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_95[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_95[0m):
                                      call [38;5;8maddress([0m[94m_95[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
              else:
                  if cd[((32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] - 1) + cd[132] + [32m('cd', 132)[0][0m + 68)][1m and [0m' '[1m <= [0m0:
                      [94m_112[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [95mmem[[0m128[95m][0m):
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], caller, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_112[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_112[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m >= [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_112[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_112[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if [94m_112[0m[1m and [0m'@':
                                  static call [38;5;8maddress([0m[94m_112[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if return_data.size[1m == [0m96:
                  else:
                      [94m_98[0m = [95mmem[[0m128[95m][0m
                      if cd[(cd[132] + [32m('cd', 132)[0][0m + 36)][1m <= [0m0:
                          revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, 
                                      ' ',
                                      0x10554e493a20656d70747920706f6f6c73000000000000000000000000
                      if [95mmem[[0m128[95m][0m[1m and [0m'@' != '@':
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [95mmem[[0m128[95m][0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if [32m('cd', 4)[0][0m[1m == [0m[32m('cd', 4)[0][0m[1m == [0m1:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, caller
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, caller
                                  else:
                                      if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                          call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                               gas gas_remaining [38;5;8mwei[0m
                                              args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 4295128740, 160, 32, this.address
                                      else:
                                          if Mask(1, 255, [95mmem[[0m128[95m][0m):
                                              call [95mmem[[0m128[95m][0m.swap([38;5;8maddress[0m recipient, [38;5;8mbool[0m zeroForOne, [38;5;8mint256[0m amountSpecified, [38;5;8muint160[0m sqrtPriceLimitX96, [38;5;8mbytes[0m data) with:
                                                   gas gas_remaining [38;5;8mwei[0m
                                                  args [38;5;8maddress([0mthis.address[38;5;8m)[0m, not Mask(1, 255, [95mmem[[0m128[95m][0m)[1m << [0m248, [32m('cd', 4)[0][0m, 0xfffd8963efd1fc6a506488495d951d5263988d25, 160, 32, this.address
                              else:
                                  static call [95mmem[[0m140[95m len [0m20[95m][0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [95mmem[[0m128[95m][0m):
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
                                      if not ext_call.success:
                                          revert with ext_call.return_data[0 len return_data.size]
                                  else:
                                      call [95mmem[[0m140[95m len [0m20[95m][0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0[1m / [0m10^9[1m * [0mext_call.return_data[32], 0, this.address, 128, 0
                      else:
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 128[95m][0m = 0x23b872dd00000000000000000000000000000000000000000000000000000000
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 132[95m][0m = caller
                          [95mmem[[0m(32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)]) + 164[95m][0m = [38;5;8maddress([0m[94m_98[0m[38;5;8m)[0m
                          call cd[68].transferFrom([38;5;8maddress[0m sender, [38;5;8maddress[0m recipient, [38;5;8muint256[0m amount) with:
                               gas gas_remaining [38;5;8mwei[0m
                              args caller, [38;5;8maddress([0m[94m_98[0m[38;5;8m)[0m, [32m('cd', 4)[0][0m
                          if not ext_call.success:
                              revert with ext_call.return_data[0 len return_data.size]
                          if 64[1m < [0m32[1m * [0mcd[(cd[132] + [32m('cd', 132)[0][0m + 36)] + 1:
                              if not [94m_98[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                              else:
                                  static call [38;5;8maddress([0m[94m_98[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                          else:
                              if not [94m_98[0m[1m or [0mnot '@':
                                  if [32m('cd', 4)[0][0m[1m >= [0m0x8000000000000000000000000000000000000000000000000000000000000000:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x10554e495633523a206f766572666c6f77
                                  if Mask(1, 255, [94m_98[0m):
                              else:
                                  static call [38;5;8maddress([0m[94m_98[0m[38;5;8m)[0m.getReserves() with:
                                          gas gas_remaining [38;5;8mwei[0m
                                  if not ext_call.success:
                                      revert with ext_call.return_data[0 len return_data.size]
                                  if 96 != return_data.size:
                                      revert with 0x8c379a000000000000000000000000000000000000000000000000000000000, ' ', 0x1b554e4956323a2072657365727665732063616c6c20
                                  if not Mask(1, 255, [94m_98[0m):
                                      call [38;5;8maddress([0m[94m_98[0m[38;5;8m)[0m.swap([38;5;8muint256[0m amount0Out, [38;5;8muint256[0m amount1Out, [38;5;8maddress[0m to, [38;5;8mbytes[0m data) with:
                                           gas gas_remaining [38;5;8mwei[0m
                                          args 0, 0[1m / [0m10^9[1m * [0mext_call.return_data[0], this.address, 128, 0
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m


