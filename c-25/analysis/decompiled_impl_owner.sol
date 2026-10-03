[38;5;8m# Palkeoramix decompiler. [0m

[95mconst [0mFEATURE_VERSION = [1munknown10000000()[0m
[95mconst [0mFEATURE_NAME = [1m'Ownable', 0[0m

[32mdef [0mstorage:
  [32mowner[0m is address [38;5;8mat storage 0x300000000000000000000000000000000[0m[38;5;8m[0m
  [32mstor3000[0m is uint256 [38;5;8mat storage 0x300000000000000000000000000000000[0m[38;5;8m[0m

[95mdef [0mowner()[95m payable[0m: 
  return [38;5;8maddress([0m[32mowner[0m[38;5;8m)[0m

[38;5;8m#
#  Regular functions
#[0m

[95mdef [0m_fallback(?)[95m payable[0m: [38;5;8m# default function[0m
  revert

[95mdef [0mtransferOwnership(address [32mnewOwner[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m32
  require [32mnewOwner[0m[1m == [0m[32mnewOwner[0m
  require ext_code.size(this.address)
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with OnlyOwnerError([38;5;8maddress[0m _param1, [38;5;8maddress[0m _param2), caller, ext_call.return_data[12 len 20]
  if not [32mnewOwner[0m:
      revert with TransferOwnerToZeroError()
  [38;5;8maddress([0m[32mowner[0m[38;5;8m)[0m = [32mnewOwner[0m
  [38;5;8mlog OwnershipTransferred([0m
  [38;5;8m      address previousOwner=caller,[0m
  [38;5;8m      address newOwner=newOwner)[0m

[95mdef [0mbootstrap()[95m payable[0m: 
  [38;5;8maddress([0m[32mowner[0m[38;5;8m)[0m = this.address
  require ext_code.size(this.address)
  call this.address._extendSelf([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0xf2fde38b00000000000000000000000000000000000000000000000000000000, 0x88099fcf6acdcf530607874452e7ef6fadcef2eb
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address._extendSelf([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0x8da5cb5b00000000000000000000000000000000000000000000000000000000, 0x88099fcf6acdcf530607874452e7ef6fadcef2eb
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require ext_code.size(this.address)
  call this.address._extendSelf([38;5;8mbytes4[0m selector, [38;5;8maddress[0m impl) with:
       gas gas_remaining [38;5;8mwei[0m
      args 0x2b60990000000000000000000000000000000000000000000000000000000[1m * [0m3600, 0x88099fcf6acdcf530607874452e7ef6fadcef2eb
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  return 0xd150751b00000000000000000000000000000000000000000000000000000000

[95mdef [0mmigrate(address [32mtarget[0m, bytes [32mdata[0m, address [32mnewOwner[0m)[95m payable[0m: 
  require calldata.size - 4[1m >=′ [0m96
  require [32mtarget[0m[1m == [0m[32mtarget[0m
  require [32mdata[0m[1m <= [0mLOCK8605463013()
  require [32mdata[0m + 35[1m <′ [0mcalldata.size
  require [32mdata.length[0m[1m <= [0mLOCK8605463013()
  require [32mdata[0m + [32mdata.length[0m + 36[1m <= [0mcalldata.size
  require [32mnewOwner[0m[1m == [0m[32mnewOwner[0m
  require ext_code.size(this.address)
  static call this.address.owner() with:
          gas gas_remaining [38;5;8mwei[0m
  [95mmem[[0m96[95m][0m = ext_call.return_data[0]
  if not ext_call.success:
      revert with ext_call.return_data[0 len return_data.size]
  require return_data.size[1m >=′ [0m32
  require ext_call.return_data[0][1m == [0mext_call.return_data[12 len 20]
  if ext_call.return_data[12 len 20] != caller:
      revert with OnlyOwnerError([38;5;8maddress[0m _param1, [38;5;8maddress[0m _param2), caller, ext_call.return_data[12 len 20]
  if not [32mnewOwner[0m:
      revert with TransferOwnerToZeroError()
  [38;5;8muint256([0m[32mstor3000[0m[38;5;8m)[0m = this.address[1m or [0mMask(96, 160, [38;5;8muint256([0m[32mstor3000[0m[38;5;8m)[0m)
  [95mmem[[0mceil32(return_data.size) + 96[95m][0m = [32mdata.length[0m
  [95mmem[[0mceil32(return_data.size) + 128[95m len [0m[32mdata.length[0m[95m][0m = [32mdata[[0mall[32m][0m
  [95mmem[[0mceil32(return_data.size) + [32mdata.length[0m + 128[95m][0m = 0
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 128[95m len [0mceil32([32mdata.length[0m)[95m][0m = [32mdata[[0mall[32m][0m, [95mmem[[0mceil32(return_data.size) + [32mdata.length[0m + 128[95m len [0mceil32([32mdata.length[0m) - [32mdata.length[0m[95m][0m
  if ceil32([32mdata.length[0m)[1m > [0m[32mdata.length[0m:
      [95mmem[[0m[32mdata.length[0m + ceil32(return_data.size) + ceil32([32mdata.length[0m) + 128[95m][0m = 0
  [93mdelegate[0m [32mtarget[0m with:
     funct (Mask(32, -(8[1m * [0mceil32([32mdata.length[0m) + -[32mdata.length[0m + 4) + 256, 0)[1m >> [0m-(8[1m * [0mceil32([32mdata.length[0m) + -[32mdata.length[0m + 4) + 256)
       gas gas_remaining [38;5;8mwei[0m
      args [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 132[95m len [0m[32mdata.length[0m - 4[95m][0m
  if return_data.size:
      [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m len [0mreturn_data.size[95m][0m = ext_call.return_data[0 len return_data.size]
      if not delegate.return_code:
          revert with 0, 
                      [38;5;8maddress([0m[32mtarget[0m[38;5;8m)[0m,
                      64,
                      return_data.size,
                      ext_call.return_data[0 len return_data.size],
                      [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + return_data.size + 160[95m len [0mceil32(return_data.size) - return_data.size[95m][0m
      if return_data.size != 32:
          revert with 0, 
                      [38;5;8maddress([0m[32mtarget[0m[38;5;8m)[0m,
                      64,
                      return_data.size,
                      ext_call.return_data[0 len return_data.size],
                      [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + return_data.size + 160[95m len [0mceil32(return_data.size) - return_data.size[95m][0m
      require return_data.size[1m >=′ [0m32
      require [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m][0m[1m == [0mMask(32, 224, [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m][0m)
      if Mask(32, 224, [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m][0m) != 0x2c64c5ef00000000000000000000000000000000000000000000000000000000:
          revert with 0, 
                      [38;5;8maddress([0m[32mtarget[0m[38;5;8m)[0m,
                      64,
                      return_data.size,
                      ext_call.return_data[0 len return_data.size],
                      [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + return_data.size + 160[95m len [0mceil32(return_data.size) - return_data.size[95m][0m
      [38;5;8maddress([0m[32mowner[0m[38;5;8m)[0m = [32mnewOwner[0m
      [38;5;8mlog Migrated([0m
      [38;5;8m      address caller=caller,[0m
      [38;5;8m      address migrator=address(target),[0m
      [38;5;8m      address newOwner=newOwner)[0m
      stop
  if delegate.return_code:
      if 32[1m == [0mext_call.return_data[0]:
          require ext_call.return_data[0][1m >=′ [0m32
          require [95mmem[[0m128[95m][0m[1m == [0mMask(32, 224, [95mmem[[0m128[95m][0m)
          if Mask(32, 224, [95mmem[[0m128[95m][0m)[1m == [0m0x2c64c5ef00000000000000000000000000000000000000000000000000000000:
              [38;5;8maddress([0m[32mowner[0m[38;5;8m)[0m = [32mnewOwner[0m
              [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 128[95m][0m = caller
              [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m][0m = [32mtarget[0m
              [38;5;8mlog Migrated([0m
              [38;5;8m      address caller=Mask(8 * -ceil32(data.length) + data.length + 32, 0, 0),[0m
              [38;5;8m      address migrator=mem[ceil32(return_data.size) + data.length + 160 len ceil32(data.length) + -data.length + 32],[0m
              [38;5;8m      address newOwner=address(newOwner))[0m
              stop
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 164[95m][0m = [32mtarget[0m
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 196[95m][0m = 64
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 228[95m][0m = ext_call.return_data[0]
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 260[95m len [0mceil32(ext_call.return_data[0])[95m][0m = [95mmem[[0m128[95m len [0mceil32(ext_call.return_data[0])[95m][0m
  if ceil32(ext_call.return_data[0])[1m > [0mext_call.return_data[0]:
      [95mmem[[0mext_call.return_data[0] + ceil32(return_data.size) + ceil32([32mdata.length[0m) + 260[95m][0m = 0
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 128[95m][0m = ceil32(ext_call.return_data[0]) + 100
  [95mmem[[0mceil32(return_data.size) + ceil32([32mdata.length[0m) + 160[95m len [0m4[95m][0m = MigrateCallFailedError([38;5;8maddress[0m _param1, [38;5;8mbytes[0m _param2)
  revert with memory
    from ceil32(return_data.size) + ceil32([32mdata.length[0m) + 160
     [93mlen[0m Mask(8[1m * [0m-ceil32([32mdata.length[0m) + [32mdata.length[0m + 32, 0, 0), [95mmem[[0mceil32(return_data.size) + [32mdata.length[0m + 160[95m len [0m-[32mdata.length[0m + ceil32([32mdata.length[0m)[95m][0m


