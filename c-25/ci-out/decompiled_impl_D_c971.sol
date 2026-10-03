[38;5;8m# Palkeoramix decompiler. [0m

[95mdef [0m_fallback(?)[95m payable[0m: [38;5;8m# default function[0m
  revert

[95mdef [0munknown5b4a250f(uint256 [32m_param1[0m, uint256 [32m_param2[0m, uint256 [32m_param3[0m, array [32m_param4[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m128
  require [32m_param1[0m[1m == [0m[38;5;8muint8([0m[32m_param1[0m[38;5;8m)[0m
  require [32m_param3[0m[1m == [0m[38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m
  require [32m_param4[0m[1m <= [0mLOCK8605463013()
  require [32m_param4[0m + 35[1m <′ [0mcalldata.size
  if [32m_param4.length[0m[1m > [0mLOCK8605463013():
      revert with 0, 65
  if ceil32(ceil32([32m_param4.length[0m)) + 97[1m < [0m96[1m or [0mceil32(ceil32([32m_param4.length[0m)) + 97[1m > [0mLOCK8605463013():
      revert with 0, 65
  [95mmem[[0m96[95m][0m = [32m_param4.length[0m
  require [32m_param4[0m + [32m_param4.length[0m + 36[1m <= [0mcalldata.size
  [95mmem[[0m128[95m len [0m[32m_param4.length[0m[95m][0m = [32m_param4[[0mall[32m][0m
  [95mmem[[0m[32m_param4.length[0m + 128[95m][0m = 0
  if not [38;5;8muint8([0m[32m_param1[0m[38;5;8m)[0m - 1:
      revert with 0, 'connext protocol is deprecated'
  if [38;5;8muint8([0m[32m_param1[0m[38;5;8m)[0m - 2:
      if [38;5;8muint8([0m[32m_param1[0m[38;5;8m)[0m - 3:
          revert with 0, 'unknown protocol id'
      require [32m_param4.length[0m[1m >=′ [0m256
      if not [38;5;8mbool([0mceil32(ceil32([32m_param4.length[0m)) + 353[1m <= [0mLOCK8605463013()[38;5;8m)[0m:
          revert with 0, 65
      require [95mmem[[0m128[95m][0m[1m == [0m[95mmem[[0m140[95m len [0m20[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 97[95m][0m = [95mmem[[0m128[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m = [95mmem[[0m160[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 161[95m][0m = [95mmem[[0m192[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m = [95mmem[[0m224[95m][0m
      require [95mmem[[0m256[95m][0m[1m == [0m[95mmem[[0m268[95m len [0m20[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 225[95m][0m = [95mmem[[0m256[95m][0m
      require [95mmem[[0m288[95m][0m[1m == [0mbool([95mmem[[0m288[95m][0m)
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 257[95m][0m = [95mmem[[0m288[95m][0m
      require [95mmem[[0m320[95m][0m[1m == [0m[95mmem[[0m348[95m len [0m4[95m][0m
      if [32m_param2[0m:
          if not [38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m:
              revert with 0, 'entr fee collector required'
      if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 109[95m len [0m20[95m][0m != 0xeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee:
          if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m != call.value:
              revert with 0, 'deBridge: wrong msg.value'
          if eth.balance(this.address)[1m < [0m0:
              revert with 0, 'Address: insufficient balance for call'
      else:
          if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m[1m > [0m[32m_param2[0m + [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m:
              revert with 0, 17
          if 0[1m > [0m[95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m:
              revert with 0, 17
          if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m + [32m_param2[0m + [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m != call.value:
              revert with 0, 'deBridge: wrong msg.value'
          if [32m_param2[0m:
              call [38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m with:
                 value [32m_param2[0m [38;5;8mwei[0m
                   gas 2300 * is_zero(value) [38;5;8mwei[0m
              if not ext_call.success:
                  revert with ext_call.return_data[0 len return_data.size]
          if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m[1m > [0m[95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m + [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m:
              revert with 0, 17
  else:
      require [32m_param4.length[0m[1m >=′ [0m288
      if not [38;5;8mbool([0mceil32(ceil32([32m_param4.length[0m)) + 385[1m <= [0mLOCK8605463013()[38;5;8m)[0m:
          revert with 0, 65
      require [95mmem[[0m128[95m][0m[1m == [0m[95mmem[[0m156[95m len [0m4[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 97[95m][0m = [95mmem[[0m128[95m][0m
      require [95mmem[[0m160[95m][0m[1m == [0mbool([95mmem[[0m160[95m][0m)
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m = [95mmem[[0m160[95m][0m
      require [95mmem[[0m192[95m][0m[1m == [0m[95mmem[[0m204[95m len [0m20[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 161[95m][0m = [95mmem[[0m192[95m][0m
      require [95mmem[[0m224[95m][0m[1m == [0m[95mmem[[0m254[95m len [0m2[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 193[95m][0m = [95mmem[[0m224[95m][0m
      require [95mmem[[0m256[95m][0m[1m == [0m[95mmem[[0m286[95m len [0m2[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 225[95m][0m = [95mmem[[0m256[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 257[95m][0m = [95mmem[[0m288[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 289[95m][0m = [95mmem[[0m320[95m][0m
      require [95mmem[[0m352[95m][0m[1m == [0m[95mmem[[0m364[95m len [0m20[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 321[95m][0m = [95mmem[[0m352[95m][0m
      require [95mmem[[0m384[95m][0m[1m == [0m[95mmem[[0m404[95m len [0m12[95m][0m
      [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 353[95m][0m = [95mmem[[0m384[95m][0m
      if [32m_param2[0m:
          if not [38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m:
              revert with 0, 'entr fee collector required'
      if not [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 129[95m][0m:
          if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 373[95m len [0m12[95m][0m != call.value:
              revert with 0, 'wrong msg.value'
          if [32m_param2[0m:
              if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 257[95m][0m - [32m_param2[0m[1m > [0m[95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 257[95m][0m:
                  revert with 0, 17
              if [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 257[95m][0m - [32m_param2[0m[1m < [0m[95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 289[95m][0m:
                  revert with 0, 'min amount error'
      else:
          if call.value - [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 373[95m len [0m12[95m][0m[1m > [0mcall.value:
              revert with 0, 17
          if call.value - [95mmem[[0mceil32(ceil32([32m_param4.length[0m)) + 373[95m len [0m12[95m][0m != [32m_param2[0m:
              revert with 0, 'stargate: wrong msg.value'
          if [32m_param2[0m:
              call [38;5;8maddress([0m[32m_param3[0m[38;5;8m)[0m with:
                 value [32m_param2[0m [38;5;8mwei[0m
                   gas 2300 * is_zero(value) [38;5;8mwei[0m
              if not ext_call.success:
                  revert with ext_call.return_data[0 len return_data.size]
      if eth.balance(this.address)[1m < [0m0:
          revert with 0, 'Address: insufficient balance for call'
  [93m...[0m[38;5;8m  # Decompilation aborted, sorry: ("decompilation didn't finish",)[0m


