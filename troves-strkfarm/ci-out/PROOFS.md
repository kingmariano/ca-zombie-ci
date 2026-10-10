# C2-51 proof suite output

Starknet blocks: 16153961 .. 16154023

## Live balances (raw units)
- AutoCompounding_STRK: class=0xb9901f375d6a56d374c3334440148f55839e865d1151e4d3c297cd9498c166 owner=['0x3495dd1e4838aa06666aac236036d86e81a6553e222fc02e70c2cbc0062e8d0'] paused=None
    - STRK: 1820347260628658109906
    - USDC_bridged: 2224
    - ETH: 695226216340
    - zSTRK: 13333420501663099793562
- AutoCompounding_USDC: class=0xb9901f375d6a56d374c3334440148f55839e865d1151e4d3c297cd9498c166 owner=['0x3495dd1e4838aa06666aac236036d86e81a6553e222fc02e70c2cbc0062e8d0'] paused=None
    - STRK: 101316082243415336
    - USDC_bridged: 44700301
    - ETH: 1644741594860
    - zUSDC: 7244883992
- Sensei_STRK: class=0x24b350501cd8e28a29c6b3faa986e124f3b03ac93a8cfc7c511d820949e96a3 owner=['0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e'] paused=['0x1']
    - STRK: 33042740046053251936324
    - ETH: 15070051320789
    - zSTRK: 318231510792772475332048
- Sensei_USDC: class=0x24b350501cd8e28a29c6b3faa986e124f3b03ac93a8cfc7c511d820949e96a3 owner=['0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e'] paused=['0x1']
    - STRK: 6141504273593602841
    - USDC_bridged: 15439491752
    - ETH: 133704737451239
    - zUSDC: 1003975351255
- Sensei_ETH: class=0x24b350501cd8e28a29c6b3faa986e124f3b03ac93a8cfc7c511d820949e96a3 owner=['0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e'] paused=['0x1']
    - STRK: 8702659894630220657
    - USDC_bridged: 404187
    - ETH: 2314722700600251759
    - zETH: 615305241570673313447
- Sensei_ETH_XL: class=0x610d2859724fa01a6a19efdc2212c8bdd8801aa8ac0c245b42f73d67550fdbe owner=['0x55d39827894c40f04fe3a314ad013bf9bc5220f7eb6cd8863212dcba6c0e16e'] paused=['0x1']
    - STRK: 652766234181172723
    - USDC_bridged: 235851947
    - ETH: 353174814102697550
    - zUSDC: 104515413062

## Claim batches (token, amount raw)
- AutoCompounding_STRK batch 1: token=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d amount=1820304434693731561080
- AutoCompounding_USDC batch 1: token=0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 amount=44695038
- Sensei_STRK batch 1: token=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d amount=15323928054097447225208
- Sensei_STRK batch 2: token=0x4718f5a0fc34cc1af16a1cdee98ffb20c31f5cd61d6ab07201858f4287c938d amount=2273130085664901617803
- Sensei_USDC batch 1: token=0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 amount=3270257730
- Sensei_USDC batch 2: token=0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 amount=2646641490
- Sensei_ETH batch 1: token=0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 amount=216086153053522236
- Sensei_ETH batch 2: token=0x49d36570d4e46f48e99674bd3fcc84644ddd6b96f7c741b1562b82f9e004dc7 amount=973194592276040970
- Sensei_ETH_XL batch 1: token=0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 amount=67501497
- Sensei_ETH_XL batch 2: token=0x53c91253bc9682c04929ca02ed00b3e423f6710d2ee7e0d5ebb06f3ecf368a8 amount=168350450

## Simulations
- nonholder_AC_STRK_withdraw_zklend: SUCCESS transfers=[none] calls=4
- nonholder_S_STRK_withdraw_zklend: SUCCESS transfers=[none] calls=8
- receiver_basis_S_STRK_random_caller_AC_owner_receiver: SUCCESS transfers=[none] calls=8
- single_claim_S_STRK_AC_owner: SUCCESS transfers=[0x4718f5a0fc->0x3495dd1e48 amount=826786388187987] calls=9
- double_claim_S_STRK_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x1, 0x5a6b6c656e643a3a416c726561647920636c61696d6564 ('Zklend::Already claimed')
- single_claim_S_USDC_AC_owner: SUCCESS transfers=[0x53c91253bc->0x3495dd1e48 amount=2368] calls=9
- claim_zklend_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- set_batch_amount_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- transfer_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- swap_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- unwind_dapp2_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- withdraw_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x5061757361626c653a20706175736564 ('Pausable: paused'), 0x454e54525950
- rebalance_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x5061757361626c653a20706175736564 ('Pausable: paused'), 0x454e54525950
- unpause_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- register_zklend_forged_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
- harvest_S_USDC_AC_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x5061757361626c653a20706175736564 ('Pausable: paused'), 0x454e54525950
- harvest_AC_STRK_S_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x52656d6f766564 ('Removed'), 0x454e545259504f494e545f4641494c4544 ('EN
- claim_zklend_AC_STRK_S_owner: REVERTED (0x617267656e742f6d756c746963616c6c2d6661696c6564 ('argent/multicall-failed'), 0x0 (''), 0x43616c6c6572206973206e6f7420746865206f776e6572 ('Caller is not the ow
