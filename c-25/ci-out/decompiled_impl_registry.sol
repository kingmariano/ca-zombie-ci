[38;5;8m# Palkeoramix decompiler. [0m

[95mconst [0mFEATURE_VERSION = [1munknown10000000()[0m
[95mconst [0mFEATURE_NAME = [1m'SimpleFunctionRegistry', 0[0m

[32mdef [0mstorage:
  [32mstor340282366920938463463374607431768211456[0m is mapping of address [38;5;8mat storage 0x100000000000000000000000000000000[0m
  [32mrollbackEntryAtIndex[0m is array of address [38;5;8mat storage 0x200000000000000000000000000000000[0m

[95mdef [0mgetRollbackEntryAtIndex(bytes4 [32mselector[0m, uint256 [32midx[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m64
  require [32mselector[0m[1m == [0mMask(32, 224, [32mselector[0m)
  require [32midx[0m[1m < [0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m
  return [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[32m[[0m[32midx[0m[32m][0m[38;5;8m)[0m

[95mdef [0mgetRollbackLength(bytes4 [32mselector[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m32
  require [32mselector[0m[1m == [0mMask(32, 224, [32mselector[0m)
  return [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m

[38;5;8m#
#  Regular functions
#[0m

[95mdef [0m_fallback(?)[95m payable[0m: [38;5;8m# default function[0m
  revert

[95mdef [0m_extendSelf(bytes4 [32mselector[0m, address [32mimpl[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m64
  require [32mselector[0m[1m == [0mMask(32, 224, [32mselector[0m)
  require [32mimpl[0m[1m == [0m[32mimpl[0m
  if caller != this.address:
      revert with OnlyCallableBySelfError([38;5;8maddress[0m _param1), caller
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m
  [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m = [32mimpl[0m
  [38;5;8mlog ProxyFunctionUpdated([0m
  [38;5;8m      bytes4 selector=stor1000[Mask(32, 224, selector)],[0m
  [38;5;8m      address oldImpl=impl,[0m
  [38;5;8m      address newImpl=Mask(32, 224, selector))[0m

[95mdef [0mextend(bytes4 [32mselector[0m, address [32mimpl[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m64
  require [32mselector[0m[1m == [0mMask(32, 224, [32mselector[0m)
  require [32mimpl[0m[1m == [0m[32mimpl[0m
  require ext_code.size(this.address)
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with OnlyOwnerError([38;5;8maddress[0m _param1, [38;5;8maddress[0m _param2), caller, ext_call.return_data[12 len 20]
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m
  [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m = [32mimpl[0m
  [38;5;8mlog ProxyFunctionUpdated([0m
  [38;5;8m      bytes4 selector=stor1000[Mask(32, 224, selector)],[0m
  [38;5;8m      address oldImpl=impl,[0m
  [38;5;8m      address newImpl=Mask(32, 224, selector))[0m

[95mdef [0mrollback(bytes4 [32mselector[0m, address [32mtargetImpl[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m64
  require [32mselector[0m[1m == [0mMask(32, 224, [32mselector[0m)
  require [32mtargetImpl[0m[1m == [0m[32mtargetImpl[0m
  require ext_code.size(this.address)
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with OnlyOwnerError([38;5;8maddress[0m _param1, [38;5;8maddress[0m _param2), caller, ext_call.return_data[12 len 20]
  if [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[1m == [0m[32mtargetImpl[0m:
      stop
  [95mmem[[0m0[95m][0m = Mask(32, 224, [32mselector[0m)
  [94midx[0m = [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m[95mmem[[0m0[95m][0m[32m][0m[38;5;8m)[0m
  [32mwhile [0m[94midx[0m[32m:[0m
      require [94midx[0m - 1[1m < [0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m
      require [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m
      [95mmem[[0m0[95m][0m = sha3(Mask(32, 224, [32mselector[0m), 0x200000000000000000000000000000000)
      [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = 0
      [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[38;5;8m)[0m--
      if [32mtargetImpl[0m != [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m[32m[[0m[94midx[0m[32m][0m[38;5;8m)[0m:
          [94midx[0m = [94midx[0m - 1
          [32mcontinue [0m
      if not [94midx[0m:
          revert with 0xa0425c2d00000000000000000000000000000000000000000000000000000000[1m or [0mMask(32, 224, [32mselector[0m)[1m >> [0m32, 0, [32mtargetImpl[0m
      [32mstor1000[0m[32m[[0mMask(32, 224, [32mselector[0m)[32m][0m = [32mtargetImpl[0m
      [38;5;8mlog ProxyFunctionUpdated([0m
      [38;5;8m      bytes4 selector=stor1000[Mask(32, 224, selector)],[0m
      [38;5;8m      address oldImpl=targetImpl,[0m
      [38;5;8m      address newImpl=Mask(32, 224, selector))[0m
      stop
  revert with NotInRollbackHistoryError([38;5;8mbytes4[0m _param1, [38;5;8maddress[0m _param2), Mask(32, 224, [32mselector[0m)[1m >> [0m32, 0, [32mtargetImpl[0m

[95mdef [0mbootstrap()[95m payable[0m: 
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6eb224cb00000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6eb224cb00000000000000000000000000000000000000000000000000000000[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6eb224cb00000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0m0x6eb224cb00000000000000000000000000000000000000000000000000000000[32m][0m
  [32mstor1000[0m[32m[[0m0x6eb224cb00000000000000000000000000000000000000000000000000000000[32m][0m = 0x6831d0e09460e123f80219e0cdf11ffef99b89c1
  [38;5;8mlog ProxyFunctionUpdated(bytes4 selector, address oldImpl, address newImpl):[0m
  [38;5;8m                         stor1000[0x6eb224cb00000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                         0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8mlog extend([0m
  [38;5;8m      bytes4 selector=stor1000[0x6eb224cb00000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m      address impl=0x6831d0e09460e123f80219e0cdf11ffef99b89c1)[0m
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xee8be1b00000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xee8be1b00000000000000000000000000000000000000000000000000000000[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xee8be1b00000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0m0xee8be1b00000000000000000000000000000000000000000000000000000000[32m][0m
  [32mstor1000[0m[32m[[0m0xee8be1b00000000000000000000000000000000000000000000000000000000[32m][0m = 0x6831d0e09460e123f80219e0cdf11ffef99b89c1
  [38;5;8mlog ProxyFunctionUpdated(bytes4 selector, address oldImpl, address newImpl):[0m
  [38;5;8m                         stor1000[0xee8be1b00000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                         0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8mlog _extendSelf([0m
  [38;5;8m      bytes4 selector=stor1000[0xee8be1b00000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m      address impl=0x6831d0e09460e123f80219e0cdf11ffef99b89c1)[0m
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x9db64a4000000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x9db64a4000000000000000000000000000000000000000000000000000000000[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x9db64a4000000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0m0x9db64a4000000000000000000000000000000000000000000000000000000000[32m][0m
  [32mstor1000[0m[32m[[0m0x9db64a4000000000000000000000000000000000000000000000000000000000[32m][0m = 0x6831d0e09460e123f80219e0cdf11ffef99b89c1
  [38;5;8mlog ProxyFunctionUpdated(bytes4 selector, address oldImpl, address newImpl):[0m
  [38;5;8m                         stor1000[0x9db64a4000000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                         0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8mlog rollback([0m
  [38;5;8m      bytes4 selector=stor1000[0x9db64a4000000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m      address targetImpl=0x6831d0e09460e123f80219e0cdf11ffef99b89c1)[0m
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xdfd0074900000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xdfd0074900000000000000000000000000000000000000000000000000000000[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0xdfd0074900000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0m0xdfd0074900000000000000000000000000000000000000000000000000000000[32m][0m
  [32mstor1000[0m[32m[[0m0xdfd0074900000000000000000000000000000000000000000000000000000000[32m][0m = 0x6831d0e09460e123f80219e0cdf11ffef99b89c1
  [38;5;8mlog ProxyFunctionUpdated(bytes4 selector, address oldImpl, address newImpl):[0m
  [38;5;8m                         stor1000[0xdfd0074900000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                         0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8mlog getRollbackLength(bytes4 selector):[0m
  [38;5;8m                      stor1000[0xdfd0074900000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                      0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6ba6bbc200000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m++
  [38;5;8maddress([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6ba6bbc200000000000000000000000000000000000000000000000000000000[32m][0m[32m[[0m[38;5;8muint256([0m[32mrollbackEntryAtIndex[0m[32m[[0m0x6ba6bbc200000000000000000000000000000000000000000000000000000000[32m][0m[38;5;8m)[0m[32m][0m[38;5;8m)[0m = [32mstor1000[0m[32m[[0m0x6ba6bbc200000000000000000000000000000000000000000000000000000000[32m][0m
  [32mstor1000[0m[32m[[0m0x6ba6bbc200000000000000000000000000000000000000000000000000000000[32m][0m = 0x6831d0e09460e123f80219e0cdf11ffef99b89c1
  [38;5;8mlog ProxyFunctionUpdated(bytes4 selector, address oldImpl, address newImpl):[0m
  [38;5;8m                         stor1000[0x6ba6bbc200000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m                         0x6831d0e09460e123f80219e0cdf11ffef99b89c1,[0m
  [38;5;8mlog getRollbackEntryAtIndex([0m
  [38;5;8m      bytes4 selector=stor1000[0x6ba6bbc200000000000000000000000000000000000000000000000000000000],[0m
  [38;5;8m      uint256 idx=0x6831d0e09460e123f80219e0cdf11ffef99b89c1)[0m
  return 0xd150751b00000000000000000000000000000000000000000000000000000000


