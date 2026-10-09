# Solend v1 (Save) — oracle account decode and reserve refreshability

- Snapshot: slot **454765873**, blockTime **1791522002**, fetchedAt **1791521997** (public RPC, read-only)
- Decoded oracle accounts: **289** — 142 switchboard-v2, 73 switchboard-on-demand, 35 pyth-receiver, 29 pyth-legacy, 9 missing, 1 null-placeholder
- Accounts passing the deployed program's gates: **17**
- Gates implemented from `solana-program-library` @ `d04ce00b` (branch `mainnet`), i.e. the deployed Solend program's `token-lending/oracles/src/`.

| oracle type | freshness gate | confidence gate |
|---|---|---|
| legacy Pyth | `get_price_no_older_than(clock, 240 slots)` (agg Trading if age<=240, else prev if age<=240) | `conf*10 <= price`; EMA >= 0 |
| Pyth receiver (pull) | verification=Full, `publish_time + 120s >= now` | `conf*10 <= price`; EMA >= 0 |
| Switchboard v2 | `240 > current_slot - round_open_slot` | `min_oracle_results <= num_success` except sliding-resolution feeds (0.1.18 returns the latest round unconditionally); mantissa >= 0 |
| Switchboard on-demand | `240 > current_slot - result.slot` | value >= 0; range >= 0; `range*10 <= value` |

Refresh order in `refresh_reserve` / `get_price`: **main Pyth oracle tried first; if it errors, the switchboard oracle is tried**. Extra oracle (if configured) is an independent unchecked gate that must also succeed.

## Oracle account table

| account | type | owner | price USD | staleness | gates | valid | refs |
|---|---|---|---|---|---|---|---|
| `3NBReDRTLKMQEKiLD5tGcx4kXbTf88b7f2xLS9UuGjym` | missing | `-` | - | - | missing | no | pyth |
| `4Dg6nQ1tcEsQ1U3bzQJ6UepNBFo11wEZXnQTphAutNLm` | missing | `-` | - | - | missing | no | sb |
| `7QKyBR3zLRhoEH5UMjcG8emDD2J2CCDmkxv3qsa2Mqif` | missing | `-` | - | - | missing | no | sb |
| `7ii9gKAMW2T7rNvKN5rkkwc4J9n3JxibrvDY39C2V21b` | missing | `-` | - | - | missing | no | sb |
| `8o8gN6VnW45R8pPfQzUJUwJi2adFmsWwfGcFNmicWt61` | missing | `-` | - | - | missing | no | sb |
| `9xYBiDWYsh2fHzpsz3aaCnNHCKWBNtfEDLtU6kS4aFD9` | missing | `-` | - | - | missing | no | pyth |
| `BTWdcU1yxn3CFnhcoVngcLNQwCcNbJhf8KqhDx5LuLFS` | missing | `-` | - | - | missing | no | sb |
| `CZx29wKMUxaJDq6aLVQTdViPL754tTR64NAgQBUGxxHb` | missing | `-` | - | - | missing | no | sb |
| `DAUfBuoKvBzJxjgSdqpBkrisVmxCU3ezek9Sqgde2hPn` | missing | `-` | - | - | missing | no | sb |
| `nu11111111111111111111111111111111111111111` | null-placeholder | `-` | - | - | null | no | - |
| `2H6gWKxJuoFjBS4REqNm4XRa7uVFf9n9yKEowpwh7LML` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 158.29602 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `3vxLXJqLqF3JG5TCbYycbKWRBbCJQLxQmBGCkyqEEefL` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.0002186 | 168205596 slots | FAIL: stale: newest pub slot 286560277 is 168205596 slots old (limit 240); agg status != Trading (0) | no | extra,pyth |
| `45rTB9ezDcTX5tMZx2uJUBbBEqAWDhXykYbBfaSWUXvD` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.10100803 | 155707397 slots | FAIL: stale: newest pub slot 299058476 is 155707397 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `4ivThkX8uRxBpHsdWSqyXYihzKF3zpRGAUCqyuagnLoV` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.5767903 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `4o4CUwzFwLqCvmA5x1G4VzoZkAhAcbiuiYyjWX1CVbY2` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.1196863 | 155707396 slots | FAIL: stale: newest pub slot 299058477 is 155707396 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `5HRrdmghsnU3i2u5StaKaydS7eq3vnKVKwXMzCNKsc4C` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.46002999 | 155707396 slots | FAIL: stale: newest pub slot 299058477 is 155707396 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `6ABgrEZk8urs6kJ1JNdC1sspH5zKXRqxy8sg3ZG2cQps` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.1750228 | 170493926 slots | FAIL: stale: newest pub slot 284271947 is 170493926 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `79wm3jjcPr6RaNQ4DGvP5KxG1mNd3gEBsg6FsNVFezK4` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.015825 | 168204101 slots | FAIL: stale: newest pub slot 286561772 is 168204101 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `7moA1i5vQUpfDwSpK6Pw9s56ahB7WFGidtbL2ujWrVvm` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 3.9213192 | 168204087 slots | FAIL: stale: newest pub slot 286561786 is 168204087 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `7yyaeuJ1GGtVBLT2z2xub5ZWYKaNhF28mj1RdV4VDFVk` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 134.68909 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `8EPnK3QRsikTkyaijaKikB5kkkzPBLzFQfTN2TGvwqo2` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.00073112 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `8ihFLu5FimgTQ1Unh4dVyEHUGodJ5gJQCrQf4KUVB9bN` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.69214e-05 | 155707392 slots | FAIL: stale: newest pub slot 299058481 is 155707392 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `AFrYBhb5wKQtxRS9UA9YRS4V3dwFm7SqmS6DHKq6YVgo` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 137.17853 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `AnLf8tVYCM816gmBjiy8n53eXKKEDydT5piYjjQDPgTB` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.3713521 | 155707389 slots | FAIL: stale: newest pub slot 299058484 is 155707389 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `Bt1hEbY62aMriY1SyQqbeZbm8VmSbQVGBFzSzMuVNWzN` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 142.95204 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `CQzPyC5xVhkuBfWFJiPCvPEnBshmRium4xxUxnX1ober` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1.09356 | 168204085 slots | FAIL: stale: newest pub slot 286561788 is 168204085 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `CtJ8EkqLmeYyGB8s4jevpeNsvmD4dxVR2krfsDLcvV8Y` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.99974848 | 155707389 slots | FAIL: stale: newest pub slot 299058484 is 155707389 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `DZYZkJcFJThN9nZy4nK3hrHra1LaWeiyoZ9SMdLFEFpY` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.09019201 | 168204085 slots | FAIL: stale: newest pub slot 286561788 is 168204085 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `E4v1BBgoso9s64TQvmyownAVJbhbEPGyzA3qn4n46qj9` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 144.20913 | 168204087 slots | FAIL: stale: newest pub slot 286561786 is 168204087 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `ETp9eKXVv1dWwHSpsXRUuXHmw24PwRkttCGVgpZEY9zF` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.19054293 | 168204085 slots | FAIL: stale: newest pub slot 286561788 is 168204085 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `GKMnwKMJS97DZHQS9mBquF15cEbgNKHvoayz8uamBp1T` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0 | 454765873 slots | FAIL: stale: newest pub slot 0 is 454765873 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `GVXRSBjFk6e6J3NbVPXohDJetcTjaeeuykUpbQF8UoMU` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 52326.911 | 168204085 slots | FAIL: stale: newest pub slot 286561788 is 168204085 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `Gnt27xtC473ZT2Mw5u8wZ68Z3gULkSTb5DuxJy7eJotD` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 1 | 168205596 slots | FAIL: stale: newest pub slot 286560277 is 168205596 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `H6ARHf6YXhGYeQfUzQNGk6rDNnLBQKrenN712K4AQJEG` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 119.23378 | 155707389 slots | FAIL: stale: newest pub slot 299058484 is 155707389 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `H8DvrfSaRfUyP1Ytse1exGf7VSinLWtmKNNaBhA4as9P` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.01267671 | 155707389 slots | FAIL: stale: newest pub slot 299058484 is 155707389 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `HkGEau5xY1e8REXUFbwvWWvyJGywkgiAZZFpryyraWqJ` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.62533343 | 168728418 slots | FAIL: stale: newest pub slot 286037455 is 168728418 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `JBu1AL4obBcCMqKBBxhpWCNUt136ijcuMZLFvTP7iWdB` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 2304.0875 | 168204094 slots | FAIL: stale: newest pub slot 286561779 is 168204094 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `Q8VX3mWPydnjA2VRFuT6QsnMzdQXJQVQGTWgwuau7si` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0 | 171991571 slots | FAIL: stale: newest pub slot 282774302 is 171991571 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `g6eRCbboSwK4tSWngn773RCMexr1APQr4uA9bGZBYfo` | pyth-legacy | `FsJ3A3u2vn5cTVofAjvy6y5kwABJAqYWpe4975bi2epH` | 0.71840073 | 168728423 slots | FAIL: stale: newest pub slot 286037450 is 168728423 slots old (limit 240); agg status != Trading (0) | no | pyth |
| `27zzC5wXCeZeuJ3h9uAJzV5tGn6r5Tzo98S1ZceYKEb8` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.00658518 | 4345972 s | FAIL: stale: publish_time 1787176030 is 4345972s old (limit 120s) | no | pyth |
| `2TTGSRSezqFzeLUH8JwRUbtN66XLLaymfYsWRTMjfiMw` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 4.6476819 | 25 s | PASS | yes | pyth |
| `2cfmeuVBf7bvBJcjKBQgAwfvpUvdZV7K8NZxUEuccrub` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.08614857 | 34259688 s | FAIL: stale: publish_time 1757262314 is 34259688s old (limit 120s) | no | pyth |
| `2d6huLjzdgpD3C2mLv2jUQPJvVLDj4aEpvhuhbvwLRgh` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.06491983 | 6722609 s | FAIL: stale: publish_time 1784799393 is 6722609s old (limit 120s) | no | pyth |
| `2eUVzcYccqXzsDU1iBuatUaDCbRKBjegEaPPeChzfocG` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.00033652 | 10991811 s | FAIL: stale: publish_time 1780530191 is 10991811s old (limit 120s) | no | pyth |
| `42amVS4KgzR9rA28tkVYqVXjq9Qa8dcZQMbH5EYFX6XC` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 2485.4237 | 25 s | PASS | yes | pyth |
| `4BfpDD8WdPqjSiosGNtiFdDVYdmjWnf6n7DmvAVz8yka` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 762.68686 | 925613 s | FAIL: stale: publish_time 1790596389 is 925613s old (limit 120s) | no | pyth |
| `4CBshVeNBEXz24GZpoj8SrqP5L7VGG3qjGd6tCST1pND` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 1.0501871 | 4471728 s | FAIL: stale: publish_time 1787050274 is 4471728s old (limit 120s) | no | pyth |
| `4cSM2e6rvbGQUFiJbqytoVMi5GgghSMr8LwVrT9VPSPo` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 82182.5 | 25 s | PASS | yes | pyth |
| `6B23K3tkb51vLZA14jcEQVCA1pfHptzEHFA93V5dYwbT` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.21215 | 25 s | PASS | yes | pyth |
| `6GujNybsWYw5uWfP9LvWTkjEkT8rMr35XGzYQv1BCvb4` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 1.1784643 | 925609 s | FAIL: stale: publish_time 1790596393 is 925609s old (limit 120s) | no | pyth |
| `6vPfd6612huknxXaDapfj6cVmB8NvCwKm3BHKFxzo1EZ` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.32787427 | 43450528 s | FAIL: stale: publish_time 1748071474 is 43450528s old (limit 120s) | no | pyth |
| `7UVimffxr9ow1uXYxsr4LHAcV58mLzhmwaeKvJ1pjLiE` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 109.82772 | 19 s | PASS | yes | pyth |
| `7ajR2zA4MGMMTqRAVjghTKqPPn4kbrj3pYkAVRVwTGzP` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.5207923 | 35 s | PASS | yes | pyth |
| `7dbob1psH1iZBS7qPsm3Kwbf5DzSXK8Jyg31CTgTnxH5` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.35190918 | 25 s | PASS | yes | pyth |
| `8vjchtMuJNY4oFQdTi8yCe6mhCaNBFaUbktT482TpLPS` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.08255815 | 19 s | PASS | yes | pyth |
| `9vNb2tQoZ8bB4vzMbQLWViGwNaDJVtct13AGgno1wazp` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 1.8448944 | 46 s | PASS | yes | pyth |
| `AZTG45CfCVrfc6DdWRsJZT5rt5Nh3ck8SwF7pWd2FVCq` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 1.540684 | 65122615 s | FAIL: stale: publish_time 1726399387 is 65122615s old (limit 120s) | no | pyth |
| `ArjngUHXrQPr1wH9Bqrji9hdDQirM6ijbzc1Jj1fXUk7` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.01887504 | 4372050 s | FAIL: stale: publish_time 1787149952 is 4372050s old (limit 120s) | no | pyth |
| `AxaxyeDT8JnWERSaTKvFXvPKkEdxnamKSqpWbsSjYg1g` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 143.32948 | 46 s | PASS | yes | pyth |
| `BEMsCSQEGi2kwPA4mKnGjxnreijhMki7L4eeb96ypzF9` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.01635633 | 41 s | PASS | yes | pyth |
| `C2Y1BNWe994KLsRmc11qcckaYTvSycKQ3S9xMZcMZ7iJ` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.00231089 | 6081835 s | FAIL: stale: publish_time 1785440167 is 6081835s old (limit 120s) | no | pyth |
| `CsG7wXoqZKNxx4UnFtvozfwXQ9RgpKe7zSJa4LWh5MT9` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 4.221e-06 | 4287000 s | FAIL: stale: publish_time 1787235002 is 4287000s old (limit 120s) | no | pyth |
| `DBE3N8uNjhKPRHfANdwGvCZghWXyLPdqdSbEW2XFwBiX` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 3.3324e-06 | 25 s | PASS | yes | pyth |
| `Dpw1EAVrSB1ibxiDQyTAW6Zip3J4Btk2x4SgApQCeFbX` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.99986509 | 19 s | PASS | yes | pyth |
| `DyYBBWEi9xZvgNAeMDCiFnmC1U9gqgVsJDXkL5WETpoX` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.99991511 | 3768576 s | FAIL: stale: publish_time 1787753426 is 3768576s old (limit 120s) | no | pyth |
| `EF6U755BdHMXim8RBw6XSC6Yk6XaouTKpwcBZ7QkcanB` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.0004692 | 19 s | PASS | yes | pyth |
| `F3nJLLMbNz9MJhiQ4So2Y5SgsRPhgpyfEsfqSw3nCAs4` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 6.1028932 | 65122615 s | FAIL: stale: publish_time 1726399387 is 65122615s old (limit 120s) | no | pyth |
| `FFv5yoCGhEgWv6mXhwv4KX8A2dYcVAzi88a6Yu8Tf3iB` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.00012407 | 24082771 s | FAIL: stale: publish_time 1767439231 is 24082771s old (limit 120s) | no | pyth |
| `Fm8a8nif7Ls9MzBonTm1MoqGpYG5sELyA2SyQseQjKcB` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.07886812 | 4992113 s | FAIL: stale: publish_time 1786529889 is 4992113s old (limit 120s) | no | pyth |
| `GHKcxocPyzSjy7tWApQjKRkDNuVXd4Kk624zhuaR7xhC` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.02672498 | 3 s | PASS | yes | pyth |
| `HT2PLQBcG5EiCcNSaMHAjSgd9F98ecpATbk4Sk5oYuM` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.999155 | 25 s | PASS | yes | pyth |
| `Hhipna3EoWR7u8pDruUg8RxhP5F6XLh6SEHMVDmZhWi8` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 2.0375488 | 1265510 s | FAIL: stale: publish_time 1790256492 is 1265510s old (limit 120s) | no | pyth |
| `HyBsZY1UiGttbQ3ppBmnFVss9rmDAEvEbtYxdfjNAqBZ` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 1.12261 | 41 s | PASS | yes | pyth |
| `Jvg1x164Kx8UGfWt82HPxeydieZRoYCwXRQb6r5rWLQ` | pyth-receiver | `rec5EKMGg6MxZYaMdyBfgwp4d5rB9T1VQH5pJv5LtFJ` | 0.0930656 | 925613 s | FAIL: stale: publish_time 1790596389 is 925613s old (limit 120s) | no | pyth |
| `13YLq66Z6PRXzsjURn2T92FPcGLiXRrPckKmMH9iFUAr` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 5.0459637e-07 | 37948744 slots | FAIL: stale: result.slot 416817129 is 37948744 slots old (limit 240) | no | sb |
| `1EmSj4vtivmjvH2hoEqDoZbHm5fn7AZTfU3Vv9eN5je` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.015344665 | 13805539 slots | FAIL: stale: result.slot 440960334 is 13805539 slots old (limit 240) | no | sb |
| `22zLMmP5ar69eMeArhUQLbMDfFN5C25eiLyLZTDBeEbn` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.26783888 | 30271899 slots | FAIL: stale: result.slot 424493974 is 30271899 slots old (limit 240) | no | sb |
| `2Dv72h14k6ynrUvQ8mhu5ihwrk1Kte6Aj2tpKhXLsHrR` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.99986 | 97269749 slots | FAIL: stale: result.slot 357496124 is 97269749 slots old (limit 240) | no | sb |
| `2Uv89odB5tH2Z6a3wv7WbhYXMhv1vZvyCNv8oraq4xiH` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.01208 | 96543349 slots | FAIL: stale: result.slot 358222524 is 96543349 slots old (limit 240) | no | sb |
| `2gyXLjhfZ9NL6j2Lg4jAtCEsNUQT7DHrMKVkSs1CKkpG` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00018927106 | 56356362 slots | FAIL: stale: result.slot 398409511 is 56356362 slots old (limit 240) | no | sb |
| `2myWdbcbDup7MxVyAYoWqGZGnLu4xLDUJqKwB7KuHQsM` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00557224 | 110779197 slots | FAIL: stale: result.slot 343986676 is 110779197 slots old (limit 240) | no | sb |
| `3ADLueMZzNfaaT4AShmpxB3BTLLtPnjLviC5y1EfjANP` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.027136711 | 37948773 slots | FAIL: stale: result.slot 416817100 is 37948773 slots old (limit 240) | no | sb |
| `3YaCes4FxxbkeC7fsdPBmBtmhV17rAmtNTYUrq98vExQ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00033772854 | 140555628 slots | FAIL: stale: result.slot 314210245 is 140555628 slots old (limit 240) | no | sb |
| `3cEZZqK3ECB9J5zDTVqfcrvxiewi1ocxy7BFwhCtg3BQ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 1622.7117 | 89849047 slots | FAIL: stale: result.slot 364916826 is 89849047 slots old (limit 240) | no | sb |
| `3debacuzYgV8GmvarcP6AU7F6rBMgE1z7wuWy5vHXEJy` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 191.4907 | 11247627 slots | FAIL: stale: result.slot 443518246 is 11247627 slots old (limit 240) | no | sb |
| `3pQ5Aec1JrmfDtgrwpTQQrRVAGrEPkGLPAfCGwZPDQmH` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.015137078 | 35110913 slots | FAIL: stale: result.slot 419654960 is 35110913 slots old (limit 240) | no | sb |
| `56PpAg9fHx2yHEwdTkvCH5R5x2PAsDoNANUhdbvLXLM6` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 157.3636 | 111008589 slots | FAIL: stale: result.slot 343757284 is 111008589 slots old (limit 240) | no | sb |
| `576Y2aMvXaLQEq7K4srxpEYM6wiyZbtjXqgieRtiZS9J` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0016971562 | 68943705 slots | FAIL: stale: result.slot 385822168 is 68943705 slots old (limit 240) | no | sb |
| `5FWVcePyDK5jF6ZqFgmEMyu9qu5qdsswwvMd7GvRmfFW` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.041172631 | 30272380 slots | FAIL: stale: result.slot 424493493 is 30272380 slots old (limit 240) | no | sb |
| `6SGfHMoUWv5TNzN35KoS2pNwxChjZ7xUoaEyzGN9VYWK` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.075135091 | 71890257 slots | FAIL: stale: result.slot 382875616 is 71890257 slots old (limit 240) | no | sb |
| `6USvryJSNcdZUH1REsaKZwDWTKL5FwcPbE8q3EWZgjZX` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 724.97563 | 121054176 slots | FAIL: stale: result.slot 333711697 is 121054176 slots old (limit 240) | no | sb |
| `6WufZdzpf67GPifHQKsJPHo3hzvA4hgQya13i3y3iD9q` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.000361915 | 111008589 slots | FAIL: stale: result.slot 343757284 is 111008589 slots old (limit 240) | no | sb |
| `6ZsHzJK7uXiMNEvSR5HnQnMu8MA2LbnNkq4TnExYdT17` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 1.1676176e-05 | 138521663 slots | FAIL: stale: result.slot 316244210 is 138521663 slots old (limit 240) | no | sb |
| `75q6G8k7zPYhyN2BFavHeAywq8hU6H4xatJ52wfKsJEx` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.000564451 | 47653501 slots | FAIL: stale: result.slot 407112372 is 47653501 slots old (limit 240) | no | sb |
| `7czWHLuVnLF3Y4RPyGBV3MoWC3hfP2Dp3GVZX9SWr5sj` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 6.1410694e-05 | 18106198 slots | FAIL: stale: result.slot 436659675 is 18106198 slots old (limit 240) | no | sb |
| `7kHnDm29TotLRh91RrLkzBd2ja8RfFTq365ANyQ2i8qs` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 3.6471713e-05 | 76579012 slots | FAIL: stale: result.slot 378186861 is 76579012 slots old (limit 240) | no | sb |
| `7q3FjYMSZzqZanakrjVKrcfSoV1WvenSba7Ddy3EFH2x` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0050632224 | 44479257 slots | FAIL: stale: result.slot 410286616 is 44479257 slots old (limit 240) | no | sb |
| `7t7mZ2TPFUbY3WH7KF3QyqFBgrwjtVFH727ZdknoixSd` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00075353601 | 68941526 slots | FAIL: stale: result.slot 385824347 is 68941526 slots old (limit 240) | no | sb |
| `873iWtUSkWJvgAfrrMF1KKKt8Lm3MNAFm1QbUecFMmNN` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0018632421 | 10493226 slots | FAIL: stale: result.slot 444272647 is 10493226 slots old (limit 240) | no | sb |
| `8G2KrSMdpLe6vCf2XfQFMqXG7SrHiDTpwfKf16VFdH91` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0018404558 | 134148561 slots | FAIL: stale: result.slot 320617312 is 134148561 slots old (limit 240) | no | sb |
| `8NHREDu3X2UxVsECE8x4uwoFiAsxmU7X1AnJEWjcanPT` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 1e-10 | 4417329 slots | FAIL: stale: result.slot 450348544 is 4417329 slots old (limit 240) | no | sb |
| `8PAQbJw9s2Uk7bojL9KF8nrqN6DPzCeGqDBQrDkYtGrb` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 106.42128 | 10177135 slots | FAIL: stale: result.slot 444588738 is 10177135 slots old (limit 240) | no | sb |
| `8bRsgrrQjMA1ZbBvTddt47KyHNTXUxEsau1D8V8M49WJ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.071587151 | 64975000 slots | FAIL: stale: result.slot 389790873 is 64975000 slots old (limit 240) | no | sb |
| `8i4AUdrTJU91XrMP27s1PhqkySMSxjijVbn5qoviXbXy` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00919849 | 18587992 slots | FAIL: stale: result.slot 436177881 is 18587992 slots old (limit 240) | no | sb |
| `8o433d9u47rQ3F84pXSdCQDFU62KnP4tycHKZKMcnyQd` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.015505336 | 68931100 slots | FAIL: stale: result.slot 385834773 is 68931100 slots old (limit 240) | no | sb |
| `924NX6vqEgxe9E2AyZxSehyw6urWGcSxnqTATrYXyGYt` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 156.1268 | 128374854 slots | FAIL: stale: result.slot 326391019 is 128374854 slots old (limit 240) | no | sb |
| `9bED8Z7oBnKxQiQ4PrksW7QzjxZ5HuwzwbcBeMhCzbSJ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0069712706 | 17012345 slots | FAIL: stale: result.slot 437753528 is 17012345 slots old (limit 240) | no | sb |
| `9jjD5JNAU2sA2krMGhkKJEAZKawzJsyCTYCFVXnbewqr` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 6.3040196e-05 | 68969107 slots | FAIL: stale: result.slot 385796766 is 68969107 slots old (limit 240) | no | sb |
| `9oFebZ81mttsc8bguz54uPb19y6xBq1HbsLs9KR1rAjG` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.004711 | 19979095 slots | FAIL: stale: result.slot 434786778 is 19979095 slots old (limit 240) | no | sb |
| `A2KV1PxyNfG6uXEZPNTk3DgvrjKL4AVp6DQV2W6tszuQ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00029547841 | 68931100 slots | FAIL: stale: result.slot 385834773 is 68931100 slots old (limit 240) | no | sb |
| `B32Wk5SEGhuKxy7nyuRxWbmqy88K8W5WV49oyHEqNSCj` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 2.15 | 10234079 slots | FAIL: stale: result.slot 444531794 is 10234079 slots old (limit 240) | no | sb |
| `BDCJWttUkD97q8CthqpfFK5bv2cVjZg9GKrYPJnLm9Ur` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 160.78514 | 35573217 slots | FAIL: stale: result.slot 419192656 is 35573217 slots old (limit 240) | no | sb |
| `BFakhNowrMBPcEZ4pwhiLEc9RCRUPsms7XGbcowHP575` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0022918935 | 133820533 slots | FAIL: stale: result.slot 320945340 is 133820533 slots old (limit 240) | no | sb |
| `BFzqZ8zrkdy2eJco1jTyt6eRrk6prsuBB4teDUnTuLfE` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 4.6424547 | 140027576 slots | FAIL: stale: result.slot 314738297 is 140027576 slots old (limit 240) | no | sb |
| `BrFsAHEU2XPiRVgeKUmidw5iWwreeniFx5qNyNrLruQ3` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.171327 | 10177135 slots | FAIL: stale: result.slot 444588738 is 10177135 slots old (limit 240) | no | sb |
| `C8Wh4Zy8cn3GNdFH6cVjgxuXNucpwYhNBXEzfJdtUuLD` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 166.11128 | 4723441 slots | FAIL: stale: result.slot 450042432 is 4723441 slots old (limit 240) | no | sb |
| `CNBzimU1XSfVLHvZswyRongdnYxNFhq3VXzDHRu9gy11` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 3.7021068 | 44740109 slots | FAIL: stale: result.slot 410025764 is 44740109 slots old (limit 240) | no | sb |
| `Ceveqpim1FJZfx9DPeFDVDSz2HJavUqPPEJtZ2osNEmS` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 76.48 | 19310408 slots | FAIL: stale: result.slot 435455465 is 19310408 slots old (limit 240) | no | sb |
| `ChZSZoniuKC5CqHQNgFjqdtKZoUzFA66wxzyent6Eun7` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0 | 454765873 slots | FAIL: no result (result.slot == 0) | no | sb |
| `Cn9jrMqmRnPNqwwo8vJiHfQFasvKEehxro1HEWposgAa` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0048340071 | 68947751 slots | FAIL: stale: result.slot 385818122 is 68947751 slots old (limit 240) | no | sb |
| `CxMq1H7YkdqEBt2bqd8EcN8mQaqg5T9HfHMwX92sT7dx` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 2.59312e-05 | 126400396 slots | FAIL: stale: result.slot 328365477 is 126400396 slots old (limit 240) | no | sb |
| `D7JAL8dBQiqAKDr2h6E7MwHZFc1AGc6VBs9VhW3knKXR` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.99967141 | 44719726 slots | FAIL: stale: result.slot 410046147 is 44719726 slots old (limit 240) | no | sb |
| `DN2oVjaxZ3G4mUafnBWnqKEPExUEC7onsSnfRNzyBfK5` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.1099346 | 68940226 slots | FAIL: stale: result.slot 385825647 is 68940226 slots old (limit 240) | no | sb |
| `DQxiaBxU5oDRPbUCp4FELcT9UYGsq95nkAoYGQfHLokM` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0756 | 112667113 slots | FAIL: stale: result.slot 342098760 is 112667113 slots old (limit 240) | no | sb |
| `DbnjejPoEij6YiQBNgLjX3zyhfHm42wD5HaqbzxMmRGG` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00038528664 | 68968982 slots | FAIL: stale: result.slot 385796891 is 68968982 slots old (limit 240) | no | sb |
| `DdXZEu5gfz7Q28ifcL1Ds658rqBCoTYW7tLnXLjbnVXE` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0063195024 | 68943396 slots | FAIL: stale: result.slot 385822477 is 68943396 slots old (limit 240) | no | sb |
| `DiCe2cwiitzKzhiwMmFDCnk1H8h6ChMotwiQ7LAGJwBP` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 5.4110794e-05 | 68940265 slots | FAIL: stale: result.slot 385825608 is 68940265 slots old (limit 240) | no | sb |
| `DksamX1tdXxHij4wxVjAV7ahT6KKQqp5dtmu9ejKNHoc` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0033003618 | 68931100 slots | FAIL: stale: result.slot 385834773 is 68931100 slots old (limit 240) | no | sb |
| `E2q9pZDjFFeXgJQfgKnxKtFupM1Uvh7sQkxcpQW3UBp7` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.12272367 | 138198063 slots | FAIL: stale: result.slot 316567810 is 138198063 slots old (limit 240) | no | sb |
| `E8TLLh5jkYDvSXfAES7qe3s8Cfjj4hyvjksuvUHe8NEw` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 148.8312 | 119507074 slots | FAIL: stale: result.slot 335258799 is 119507074 slots old (limit 240) | no | sb |
| `EEoQp9GwnwNyAmKPCLhCE6GPCZ6eRHHZd4cnWpvShgV1` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.20259285 | 4150904 slots | FAIL: stale: result.slot 450614969 is 4150904 slots old (limit 240) | no | sb |
| `EKSoEGkY1cidLbfvYpPQ2WQJuVG5mGJP8RBQbsgsS171` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 106.73823 | 122754163 slots | FAIL: stale: result.slot 332011710 is 122754163 slots old (limit 240) | no | sb |
| `ERTeG1ZDFZhuuGCvEAJA7KDLa8KsPowSyrVwc1gBfw8W` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.026725394 | 68932457 slots | FAIL: stale: result.slot 385833416 is 68932457 slots old (limit 240) | no | sb |
| `Ei8degiKXH4L6hJCv16MAZuEzQMbhAV3q793RDPg1yLf` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.0003895965 | 16327616 slots | FAIL: stale: result.slot 438438257 is 16327616 slots old (limit 240) | no | sb |
| `Es7UJMJTsNx9QfYngiM5xTrPQd9nqxZ8scFfMESEDHSB` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.99998108 | 120908596 slots | FAIL: stale: result.slot 333857277 is 120908596 slots old (limit 240) | no | sb |
| `EtAQgJykbpyEEJz32cppXzjxcdqAiPwYphjoNRc6aBmQ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.091988889 | 68939963 slots | FAIL: stale: result.slot 385825910 is 68939963 slots old (limit 240) | no | sb |
| `FHujndoJzTeXut9RCCPBmevsnge2mThUt3fsxsDp6jGQ` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 5.8503642e-05 | 68936879 slots | FAIL: stale: result.slot 385828994 is 68936879 slots old (limit 240) | no | sb |
| `FZnb8BX834rjVsa98MSUnFeBQNT39Jhx63Gv9bATfAXA` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0 | 454765873 slots | FAIL: no result (result.slot == 0) | no | sb |
| `GCXacAVHrdMctDZnGgCHUqRsbuyPysVJjeFUkUcqJhEh` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.2131 | 13070199 slots | FAIL: stale: result.slot 441695674 is 13070199 slots old (limit 240) | no | sb |
| `GMoGPv33SRDFFvhK9Kboi7tf4iJVeJXyrSTjFxHuhpas` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.034045755 | 13226870 slots | FAIL: stale: result.slot 441539003 is 13226870 slots old (limit 240) | no | sb |
| `GcwQCzpZokAByMtSecPmWezrru5ueMUSdu2sDnEjGMoT` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.033043365 | 50679828 slots | FAIL: stale: result.slot 404086045 is 50679828 slots old (limit 240) | no | sb |
| `GoyYzxQy65ChEeq48TenATCXfnEyv6b3Yc735aLbVF1E` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.056609177 | 58690025 slots | FAIL: stale: result.slot 396075848 is 58690025 slots old (limit 240) | no | sb |
| `HX5WM3qzogAfRCjBUWwnniLByMfFrjm1b5yo4KoWGR27` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 90.14495 | 25015043 slots | FAIL: stale: result.slot 429750830 is 25015043 slots old (limit 240) | no | sb |
| `HffvJvBpoyiuNLBKq3YDD2m5KvXMpCCuvm9HszYSBQoG` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00045987579 | 29996911 slots | FAIL: stale: result.slot 424768962 is 29996911 slots old (limit 240) | no | sb |
| `J9WqPkVuQvy5vNL7892u1KadtmBD16TEQURaThHWefyk` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00096079917 | 68939583 slots | FAIL: stale: result.slot 385826290 is 68939583 slots old (limit 240) | no | sb |
| `ZZYHqScCpGDe436ddcLZfJG8U4Z6K3WFteeqyTn6UXe` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 0.00097998506 | 17012345 slots | FAIL: stale: result.slot 437753528 is 17012345 slots old (limit 240) | no | sb |
| `fDK8TbmQ1CuFgAjsQgAAwLMgmpB1WMQrUyDVGFquCjs` | switchboard-on-demand | `SBondMDrcV3K4kxZR1HNVT7osZxAHVHgYXL5Ze1oMUv` | 3.177474e-08 | 68952427 slots | FAIL: stale: result.slot 385813446 is 68952427 slots old (limit 240) | no | sb |
| `1qwLbiecwo49YEycThyLhGtNa46qCy4ZPuor5Np1Snv` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 219.16179 | 143223287 slots | FAIL: stale: round_open_slot 311542586 is 143223287 slots old (limit 240) | no | sb |
| `234oAERsti3gMYH8DNXxawKm7jGLwqgSsGB5Cz72KeXU` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.0616363 | 149599193 slots | FAIL: stale: round_open_slot 305166680 is 149599193 slots old (limit 240) | no | sb |
| `24mXtPznWVnrpEZQUYV8tcUQzGMPpq5cG2rQbg4mVK5Q` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.060154931 | 216585338 slots | FAIL: stale: round_open_slot 238180535 is 216585338 slots old (limit 240) | no | sb |
| `2EU8d2ohBgKBYnHUFQL3oqQWX2jFkZiKBPmaDAbZMRdP` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 178.99175 | 158895111 slots | FAIL: stale: round_open_slot 295870762 is 158895111 slots old (limit 240) | no | sb |
| `2K6g2cBmhS12HEV9LZpsWueC61dQJNEh2dRZmgzv7s44` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.001344 | 185934496 slots | FAIL: stale: round_open_slot 268831377 is 185934496 slots old (limit 240) | no | sb |
| `2KfZ8fqE3bSUxPbYfZWMVXjipge9xKCbitz2iJdJKAcR` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.007001591 | 178109098 slots | FAIL: stale: round_open_slot 276656775 is 178109098 slots old (limit 240) | no | sb |
| `2Qo6j9agGiLAxQeujWKqFYeEvi4qTjztJZ2pgwUgz7Ae` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00072468349 | 179657612 slots | FAIL: stale: round_open_slot 275108261 is 179657612 slots old (limit 240) | no | sb |
| `2kHb4hcMcGTpKzyqp4p3sUKhZ3Rjfir6ziNJxWMvBwnY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.066461097 | 175788546 slots | FAIL: stale: round_open_slot 278977327 is 175788546 slots old (limit 240) | no | sb |
| `2oALNZVi5czyHvKbnjE4Jf2gR7dNp1FBpEGaq4PzVAf7` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 5.68373 | 140336519 slots | FAIL: stale: round_open_slot 314429354 is 140336519 slots old (limit 240) | no | sb |
| `2tt1wNhYCP2d4XVh9VoyWU85UTsQxGsjFNrZac9sxE9b` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.0154699 | 209783180 slots | FAIL: stale: round_open_slot 244982693 is 209783180 slots old (limit 240) | no | sb |
| `32fwSSUwcjREuTczhCx5vFiUxKtASiWmyKj5FqLGFEam` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0012983123 | 179657546 slots | FAIL: stale: round_open_slot 275108327 is 179657546 slots old (limit 240) | no | sb |
| `3JA2Mo3EHpvLNZrciTZHiLAshzv5brHhYmqTxtCMmG4N` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.0672616 | 220845870 slots | FAIL: stale: round_open_slot 233920003 is 220845870 slots old (limit 240) | no | sb |
| `3THUHo2pfqLyKBv25aH7MNDeFv3ntoA7Jnfsnk1zukDg` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 4.3345027e-05 | 154321154 slots | FAIL: stale: round_open_slot 300444719 is 154321154 slots old (limit 240) | no | sb |
| `3Z6ifuWaQikJkZvZiPGTcMRxRwzYcHdt9edqBdRpJ4q1` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.771778 | 282601231 slots | FAIL: stale: round_open_slot 172164642 is 282601231 slots old (limit 240) | no | sb |
| `3btrKtRBCdgbEWQciFDbVa741WQovdWZJqRJhEPvCPja` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.71407294 | 310302061 slots | FAIL: stale: round_open_slot 144463812 is 310302061 slots old (limit 240) | no | sb |
| `3igYhyg9sj4YrzQbeUmC1J1Gs5aT4sidBBpAi18rGMke` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 4.2717183e-06 | 179657512 slots | FAIL: stale: round_open_slot 275108361 is 179657512 slots old (limit 240) | no | sb |
| `3r2PsQJ6PHAUrxxiJ8PcWKPo5pRAvHTrfEH6hS6np6kq` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.25728346 | 179657536 slots | FAIL: stale: round_open_slot 275108337 is 179657536 slots old (limit 240) | no | sb |
| `4EznFNgMa5FhyVDrQ8LjmoomBQ377SgRUZEJH6RSQVaE` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 5.5771747 | 200117647 slots | FAIL: stale: round_open_slot 254648226 is 200117647 slots old (limit 240) | no | sb |
| `4SZ1qb4MtSUrZcoeaeQ3BDzVCyqxw3VwSFpPiMTmn4GE` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.3699153e-05 | 218562236 slots | FAIL: stale: round_open_slot 236203637 is 218562236 slots old (limit 240) | no | sb |
| `4VUFxa6GSLbYdrekvCN6ptiziLT1Z12SpkcCDP9TiBB7` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00363 | 221267327 slots | FAIL: stale: round_open_slot 233498546 is 221267327 slots old (limit 240) | no | sb |
| `4aUbjcFqQNxMVjsgnuxAAmtPZHyyZBsLeJjBM8LYrkFX` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 157.00276 | 172299204 slots | FAIL: stale: round_open_slot 282466669 is 172299204 slots old (limit 240) | no | sb |
| `4bndUJsFxkyvGiUTZxajLxhdMEdj5uvCkNPGzQUDpSH2` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.94118398 | 198336899 slots | FAIL: stale: round_open_slot 256428974 is 198336899 slots old (limit 240) | no | sb |
| `4puRw78QsrsFmWZvoxKXNcb2WtfU7MnsYL9pC3oRrkr6` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00040099746 | 210577187 slots | FAIL: stale: round_open_slot 244188686 is 210577187 slots old (limit 240) | no | sb |
| `4wTSg7J1hyuuvSY5egUCx9Lyan4i5XACEyaPF6YirWSv` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.5720134 | 172963381 slots | FAIL: stale: round_open_slot 281802492 is 172963381 slots old (limit 240) | no | sb |
| `4wv7S1M1pxex1xaAy6HUDnsQ37TF152nmqiuktssJWt9` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.99760111 | 279902538 slots | FAIL: stale: round_open_slot 174863335 is 279902538 slots old (limit 240) | no | sb |
| `4yphXfNK1PZyABHkEF7577MiQuYRZyj3qF7PAQJGnNt5` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 6.0397476e-08 | 156815347 slots | FAIL: stale: round_open_slot 297950526 is 156815347 slots old (limit 240) | no | sb |
| `57EF89YgEUUcxtm8upPFmi7rHVzfJDMVsm2BHgtVM3yR` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.428253 | 140336519 slots | FAIL: stale: round_open_slot 314429354 is 140336519 slots old (limit 240) | no | sb |
| `5BPAg8gvyMkSwDnYBYjkStveiV7tGLVJ4YZm9dQaqder` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.3740782 | 275889391 slots | FAIL: stale: round_open_slot 178876482 is 275889391 slots old (limit 240) | no | sb |
| `5E6KYeVhf7vykgKPZpfevh74ZJ1J8P9SJsCN89k5ehYC` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.009051 | 278189615 slots | FAIL: stale: round_open_slot 176576258 is 278189615 slots old (limit 240) | no | sb |
| `5UgyUStmKT4vnhSD75iRfnVA6bs3Mqe9nkkDg8Uyrjha` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.130371 | 221874651 slots | FAIL: stale: round_open_slot 232891222 is 221874651 slots old (limit 240) | no | sb |
| `5VHHh8dtoUnAkv79dLZDKZsfwdXC7G1ZEjKDgvVHMSNd` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 5.9e-05 | 175709066 slots | FAIL: stale: round_open_slot 279056807 is 175709066 slots old (limit 240) | no | sb |
| `5o7Rxp5MjJncGtEwMDRGodBwiLjrQDT9rnSaTZajYVyT` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.99829733 | 172559412 slots | FAIL: stale: round_open_slot 282206461 is 172559412 slots old (limit 240) | no | sb |
| `5zEWAjPGTWc96rWWDVbS46t27PtiCSLEc33NGyWBwfh1` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 165.89483 | 162506661 slots | FAIL: stale: round_open_slot 292259212 is 162506661 slots old (limit 240) | no | sb |
| `64bMFcmwoPmsqwSwBGb6S4j3hU8v6qZ9bEYVe8YFXjiB` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 132.11936 | 149623461 slots | FAIL: stale: round_open_slot 305142412 is 149623461 slots old (limit 240) | no | sb |
| `6AQHz9mpGNjyVafcWdqzzgsJq14Cs8gG6MiQKmdAgCuP` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 168.59865 | 156815358 slots | FAIL: stale: round_open_slot 297950515 is 156815358 slots old (limit 240) | no | sb |
| `6DP1pWBMf27r5qanwz41Bfdti6aHTySg6LyKp4kRHJ6Z` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.9e-05 | 208350846 slots | FAIL: stale: round_open_slot 246415027 is 208350846 slots old (limit 240) | no | sb |
| `6FeoHRkoW4pDeiGdH7bNfv9iaTvzVUbTNjDyQGeo3Wr7` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.01 | 193359188 slots | FAIL: stale: round_open_slot 261406685 is 193359188 slots old (limit 240) | no | sb |
| `6JMxpWd9ZT5eEzzmRo3yg1t2DeXbSrasbeeu1ratGdLh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 168.65834 | 179657512 slots | FAIL: stale: round_open_slot 275108361 is 179657512 slots old (limit 240) | no | sb |
| `6Poy9LnEkQBLumyS6yYpaxTt5RSqbxrzdP54hPSxwMUt` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 269.11932 | 147876198 slots | FAIL: stale: round_open_slot 306889675 is 147876198 slots old (limit 240) | no | sb |
| `6WKPYCufWrYxuBxSusK8QoQJxdyqWodC1DCty7kvdQ1Y` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.27565 | 199182879 slots | FAIL: stale: round_open_slot 255582994 is 199182879 slots old (limit 240) | no | sb |
| `6nKbZfyVtLy7UDBVdcJRsqnAFUG2uAo7xGwD17Evf8kg` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0039074883 | 208343284 slots | FAIL: stale: round_open_slot 246422589 is 208343284 slots old (limit 240) | no | sb |
| `6qBqGAYmoZw2r4fda7671NSUbcDWE4XicJdJoWqK8aTe` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.9093224e-05 | 140337695 slots | FAIL: stale: round_open_slot 314428178 is 140337695 slots old (limit 240) | no | sb |
| `6zXsYiTRoqWmZdS9uKBjQn8q2N17qQLHgmf5FRp1qXBm` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0014772326 | 182861561 slots | FAIL: stale: round_open_slot 271904312 is 182861561 slots old (limit 240) | no | sb |
| `78zWxe9YStzGAM9c64yY21VG6Mr6A4hj3jSUdecqx2BR` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 270.59321 | 148013870 slots | FAIL: stale: round_open_slot 306752003 is 148013870 slots old (limit 240) | no | sb |
| `7Aza5rGtZgRUzJMkeMoyNGP8JdfM5snBinDf5gTRRYUd` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 157.6452 | 169318567 slots | FAIL: stale: round_open_slot 285447306 is 169318567 slots old (limit 240) | no | sb |
| `7Cfyymx49ipGsgEsCA2XygAB2DUsan4C6Cyb5c8oR5st` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.56899893 | 176050862 slots | FAIL: stale: round_open_slot 278715011 is 176050862 slots old (limit 240) | no | sb |
| `7JeJwsrs79cWsBwMzMWh59PuefrwrSzEB4jhoWm9WBuY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.951001 | 179657716 slots | FAIL: stale: round_open_slot 275108157 is 179657716 slots old (limit 240) | no | sb |
| `7LU1Gc96WLoLKqBDqkp5PALzTRzKNctFVcuqMGwqiRfm` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0024549857 | 220911968 slots | FAIL: stale: round_open_slot 233853905 is 220911968 slots old (limit 240) | no | sb |
| `7MryWiYCFRJs5EexVW6U7LGc3RgErPZVEUWw86xNYAD` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.3544774 | 250449465 slots | FAIL: stale: round_open_slot 204316408 is 250449465 slots old (limit 240) | no | sb |
| `7NcifXvTzt3iGZT25XHZ1w9evNpNwAsFkkbQfAf2LM5b` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.010953583 | 179657788 slots | FAIL: stale: round_open_slot 275108085 is 179657788 slots old (limit 240) | no | sb |
| `7UVktChRurRRdyN9u62MpdJwcr1cyPPz5FghqKDCqkuk` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.2415582 | 162046797 slots | FAIL: stale: round_open_slot 292719076 is 162046797 slots old (limit 240) | no | sb |
| `7bEjAXVd6ug8T8kbYKxCuoDHZzYK4CTAW9WVPVGLz2or` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00054397502 | 179657536 slots | FAIL: stale: round_open_slot 275108337 is 179657536 slots old (limit 240) | no | sb |
| `7or1bhoEUuYSuFNLbw6RXEdEbo43LXe127LsVAv1xdRV` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0018051136 | 226922513 slots | FAIL: stale: round_open_slot 227843360 is 226922513 slots old (limit 240) | no | sb |
| `7ySvXU4NSxBuuQZj3pG5qwqNTepMFa8XQNLGivM4qkEy` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.2269702 | 175916528 slots | FAIL: stale: round_open_slot 278849345 is 175916528 slots old (limit 240) | no | sb |
| `81muJBhUKQmiRbRrATu5GEaKpeXsFLcFAdaknVDZvE6p` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 155.90334 | 164164048 slots | FAIL: stale: round_open_slot 290601825 is 164164048 slots old (limit 240) | no | sb |
| `84h6Ln5qsxgMcnVtoieHoMMJQ8kPBJUw1y83rjbxFt9k` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3.7118445 | 235115552 slots | FAIL: stale: round_open_slot 219650321 is 235115552 slots old (limit 240) | no | sb |
| `8LxP1juSh9RPMECQiTocqk8bZcrhhtqgUEk76y4AmE2K` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.13351569 | 167149735 slots | FAIL: stale: round_open_slot 287616138 is 167149735 slots old (limit 240) | no | sb |
| `8SXvChNYFhRq4EZuZvnhjrB3jJRQCv4k3P4W6hesH3Ee` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 100489.88 | 140336491 slots | FAIL: stale: round_open_slot 314429382 is 140336491 slots old (limit 240) | no | sb |
| `8fsomfuZvQHeVCNeVHUQReCSDAfoodTiYL2xsk72LNGg` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.0003401 | 220846305 slots | FAIL: stale: round_open_slot 233919568 is 220846305 slots old (limit 240) | no | sb |
| `8hhBZDLeWD5XMzUTPuAES1U6HvXfYT2vB7PvgkpB9jwh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.99962109 | 179657574 slots | FAIL: stale: round_open_slot 275108299 is 179657574 slots old (limit 240) | no | sb |
| `8n3QYCX6HTBo5Po4dUagoRCzq2guXK6Y9fNtAyXSDrYA` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 165.79528 | 179657595 slots | FAIL: stale: round_open_slot 275108278 is 179657595 slots old (limit 240) | no | sb |
| `96iMV5tdC2QKqhBWFk65fywZeHU6TCakuYjB73UAEpBh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.1069725 | 156815372 slots | FAIL: stale: round_open_slot 297950501 is 156815372 slots old (limit 240) | no | sb |
| `974zYbzQnM3fFHUEWStPcrpQSsUoEtza1jFMHHpQCnGZ` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0032429529 | 252374065 slots | FAIL: stale: round_open_slot 202391808 is 252374065 slots old (limit 240) | no | sb |
| `9EY7Wy7h22bZAg8QtgQQL3o79rmps1QwrNu6kTia1MRC` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 205.67184 | 157925376 slots | FAIL: stale: round_open_slot 296840497 is 157925376 slots old (limit 240) | no | sb |
| `9LNYQZLJG5DAyeACCTzBFG6H3sDhehP5xtYLdhrZtQkA` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 253.82787 | 140336519 slots | FAIL: stale: round_open_slot 314429354 is 140336519 slots old (limit 240) | no | sb |
| `9R4pFHTrTJFg24tVDiDEFYA3byDbTEqzYUuAp1TY5Dzw` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.64 | 303915630 slots | FAIL: stale: round_open_slot 150850243 is 303915630 slots old (limit 240) | no | sb |
| `9Rr9UxAdHpiRvqjuKN563iDgt8dfK38FEa684ANnsza9` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 316.93108 | 151447751 slots | FAIL: stale: round_open_slot 303318122 is 151447751 slots old (limit 240) | no | sb |
| `9RvUJNzSVk5NJpUFzbdWNyHiLa4CGUfrPwKfSYKH1oyw` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.039157425 | 206281185 slots | FAIL: stale: round_open_slot 248484688 is 206281185 slots old (limit 240) | no | sb |
| `9aNNzf1EyuLQ9EGU1UKxJkusjGsQ9HxH71cHAty4Kjb8` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0049977052 | 256632658 slots | FAIL: stale: round_open_slot 198133215 is 256632658 slots old (limit 240) | no | sb |
| `9bmfWwTUsah3TLr8yU3cLarCjBF5KyvZZT3hWqtpZQCY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00050950554 | 166937449 slots | FAIL: stale: round_open_slot 287828424 is 166937449 slots old (limit 240) | no | sb |
| `9gdEhaVUzrvjGM6Vb8cCc5mRXWH738Xz3gRdkAaTaSfK` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 234.76465 | 174457024 slots | FAIL: stale: round_open_slot 280308849 is 174457024 slots old (limit 240) | no | sb |
| `A19E1f2NTQfPZkatpiteLMqxUGKuh4JtrJUezuy54kF2` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0069763183 | 170969541 slots | FAIL: stale: round_open_slot 283796332 is 170969541 slots old (limit 240) | no | sb |
| `A2E8Vu8iW5bgVFTvR6sEzanWAQi8p5BWaLS4DTjCSq7K` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.5696501 | 235148500 slots | FAIL: stale: round_open_slot 219617373 is 235148500 slots old (limit 240) | no | sb |
| `AKp55LbpDZSEjJVXjWWYvqF3KiktSvFNKk6YojdPJ9zN` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.91777628 | 193326286 slots | FAIL: stale: round_open_slot 261439587 is 193326286 slots old (limit 240) | no | sb |
| `APaudjcBM3h4hCvBbvnsz4KBsDpJdoGMtwM4tUYTSpoY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.3094861 | 207902695 slots | FAIL: stale: round_open_slot 246863178 is 207902695 slots old (limit 240) | no | sb |
| `ARXKK2gw7zpjonHbmcqYj7pQzwAxAa49Yy7kh5P44Aek` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.8769405 | 179657846 slots | FAIL: stale: round_open_slot 275108027 is 179657846 slots old (limit 240) | no | sb |
| `AV6G4vx21JXyu68q8nJVF6aStKXvPPE1f8B9Xrq2FhTR` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.20183337 | 221347879 slots | FAIL: stale: round_open_slot 233417994 is 221347879 slots old (limit 240) | no | sb |
| `AhmY4z7M6vscxyhUZfuZtuPZ3VqqAV5fieqjREZXt7uJ` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00564 | 220507877 slots | FAIL: stale: round_open_slot 234257996 is 220507877 slots old (limit 240) | no | sb |
| `AmQunu75SLZjDQS9KkRNjAUWHp2ReSzfNiWVDURzeZTi` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.019863963 | 220797005 slots | FAIL: stale: round_open_slot 233968868 is 220797005 slots old (limit 240) | no | sb |
| `Arp8JGxts4QG9DhhA8fXPkCu2PZ6wgd5B1tcZcUCzMuV` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.023758 | 280205590 slots | FAIL: stale: round_open_slot 174560283 is 280205590 slots old (limit 240) | no | sb |
| `B3dwdQZMTVb48Vrqm1YRi17AXc7zEXP9zKU3Mv6ApTT9` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00012476853 | 208353652 slots | FAIL: stale: round_open_slot 246412221 is 208353652 slots old (limit 240) | no | sb |
| `B6YEdQwjLdP1wx1GSxaTKkeqEKa5ittyTNAi8Q8xPRCU` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.22882217 | 221345902 slots | FAIL: stale: round_open_slot 233419971 is 221345902 slots old (limit 240) | no | sb |
| `B9PHbXEEXZtSJrDoyganYavfqfKFQXPVjovipQSmrqeD` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.20421223 | 171845280 slots | FAIL: stale: round_open_slot 282920593 is 171845280 slots old (limit 240) | no | sb |
| `BErjJGzawur2fuCcx7hGgWu1CKcnHzvdsifA5LVN25B3` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.01065855 | 230520403 slots | FAIL: stale: round_open_slot 224245470 is 230520403 slots old (limit 240) | no | sb |
| `BH47iVRkTv4ngf1bFWdPnxhqUh54wk5HB7Q4YE1na5zN` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3.76977e-06 | 208364069 slots | FAIL: stale: round_open_slot 246401804 is 208364069 slots old (limit 240) | no | sb |
| `BV9J7XofUmVYo7r2J5HVu6kQqpfq91Nm4HmKTAzjuv7n` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.98987053 | 278185105 slots | FAIL: stale: round_open_slot 176580768 is 278185105 slots old (limit 240) | no | sb |
| `BWnkvRt96D3LLUZPur8xm2Ht1ADcW5mjpEMigXQQov1g` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00024494287 | 208348599 slots | FAIL: stale: round_open_slot 246417274 is 208348599 slots old (limit 240) | no | sb |
| `BcEhqvKNfx27K9MyMPntm9uG9wLgL6YcbJys3BooBwDy` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.043989604 | 195998729 slots | FAIL: stale: round_open_slot 258767144 is 195998729 slots old (limit 240) | no | sb |
| `Bfz5q3cDywSSjnWb9oXeQZqYzHwqFGp75mm34eYCPNEA` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0001020774 | 156841490 slots | FAIL: stale: round_open_slot 297924383 is 156841490 slots old (limit 240) | no | sb |
| `BjUgj6YCnFBZ49wF54ddBVA9qu8TeqkFtkbqmZcee8uW` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.99961988 | 140336579 slots | FAIL: stale: round_open_slot 314429294 is 140336579 slots old (limit 240) | no | extra,sb |
| `BnT7954eT3UT4XX5zf9Zwfdrag5h3YmzG8LBRwmXo5Bi` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0040576249 | 140336844 slots | FAIL: stale: round_open_slot 314429029 is 140336844 slots old (limit 240) | no | sb |
| `Bu59m5vDZk4yHuWiHPeyY4B11amRtSWV52UrYnsBcFUn` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.13895557 | 180880566 slots | FAIL: stale: round_open_slot 273885307 is 180880566 slots old (limit 240) | no | sb |
| `BvgzRgwPanJcGoAzYrZAjSEGt2uWLpcweowkdRYfzBSV` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.53048563 | 177247219 slots | FAIL: stale: round_open_slot 277518654 is 177247219 slots old (limit 240) | no | sb |
| `Bys1SNouEqVdbUWj93GfpqwY1bsWjYVYtNZG1QdV5Y1B` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.19384244 | 150967234 slots | FAIL: stale: round_open_slot 303798639 is 150967234 slots old (limit 240) | no | sb |
| `C1zLTQb7pQ11LLKfkfaZjZ5UQrbLP6MWrLGngRJMiZJS` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00020229266 | 252890231 slots | FAIL: stale: round_open_slot 201875642 is 252890231 slots old (limit 240) | no | sb |
| `C5M3Srb9F4LrTyVWDmPQoFmUNAvgYwh1pA65myGuUFtP` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.002881116 | 153771923 slots | FAIL: stale: round_open_slot 300993950 is 153771923 slots old (limit 240) | no | sb |
| `C5tuUPi7xJHBHZGZX6wWYf1Svm6jtTVwYrYrBCiEVejK` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.61294422 | 206435560 slots | FAIL: stale: round_open_slot 248330313 is 206435560 slots old (limit 240) | no | sb |
| `CGsmoUtKmUhA1NehvJC3jkoHX5aED5HtpKwRpNWE45M7` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 175.32595 | 173821487 slots | FAIL: stale: round_open_slot 280944386 is 173821487 slots old (limit 240) | no | sb |
| `CUgoqwiQ4wCt6Tthkrgx5saAEpLBjPCdHshVa4Pbfcx2` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.0353 | 140336491 slots | FAIL: stale: round_open_slot 314429382 is 140336491 slots old (limit 240) | no | sb |
| `CZS9UkVfxvMmiXBx9pbEGnxbkFb1DkM77Kcm47SZaRb` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.034085327 | 265412681 slots | FAIL: stale: round_open_slot 189353192 is 265412681 slots old (limit 240) | no | sb |
| `CdznYotJgeszFkEy3p22JtX49EnZaFGZLqLoUgVzHHuh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 9.5483936e-05 | 169876737 slots | FAIL: stale: round_open_slot 284889136 is 169876737 slots old (limit 240) | no | sb |
| `Cn6jgQAsetVmx8DXRUpvcd9vrY1G5qJ6zk8E3aZLVZjW` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00016639012 | 220426019 slots | FAIL: stale: round_open_slot 234339854 is 220426019 slots old (limit 240) | no | sb |
| `D4HWDb4MFbp8u3wBkXy5Dk8sDiy3XrgchvxAd9vLn25d` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 164.13779 | 160292936 slots | FAIL: stale: round_open_slot 294472937 is 160292936 slots old (limit 240) | no | sb |
| `Do1cyiQRNffUX9YkeJswtJbhcTsd2oqwSJw5VWgiW4AF` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.6907707 | 170675585 slots | FAIL: stale: round_open_slot 284090288 is 170675585 slots old (limit 240) | no | sb |
| `E4D4C5waNBADKqrqLWDVBbJ7tDUY1hLZPjcch9CvUBdj` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3000 | 172656192 slots | FAIL: stale: round_open_slot 282109681 is 172656192 slots old (limit 240) | no | sb |
| `E84zPU7Ms2n2pV7GWStmup2FZrxPz1qurXXjrWRQx56v` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00023915617 | 256604157 slots | FAIL: stale: round_open_slot 198161716 is 256604157 slots old (limit 240) | no | sb |
| `EPw1Vb9YFu6TcasVKaj5mEUtvtz3G18iBdByqzigbzUG` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 199.38126 | 156882246 slots | FAIL: stale: round_open_slot 297883627 is 156882246 slots old (limit 240) | no | sb |
| `EQTddDTozT19vvKz8782RQti9xTJeQn7wohhpfrqFmGd` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.8368605e-05 | 169699566 slots | FAIL: stale: round_open_slot 285066307 is 169699566 slots old (limit 240) | no | sb |
| `ETAaeeuQBwsh9mC2gCov9WdhJENZuffRMXY2HgjCcSL9` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.999 | 140336519 slots | FAIL: stale: round_open_slot 314429354 is 140336519 slots old (limit 240) | no | sb |
| `EaoDyo6tEN8s9pwYHXbJP9GRX5mdbgUiwjcEPVHG2jSY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.004497 | 172964065 slots | FAIL: stale: round_open_slot 281801808 is 172964065 slots old (limit 240) | no | sb |
| `EdcnopM6K9BThkGxtcLHSdhL8eK1ctq4veeaamohNHrD` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.017670545 | 178412213 slots | FAIL: stale: round_open_slot 276353660 is 178412213 slots old (limit 240) | no | sb |
| `EeuaqXm4tY331ipWVHRY8foboWPehzBGAwHBs362MMJV` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.00502 | 304038468 slots | FAIL: stale: round_open_slot 150727405 is 304038468 slots old (limit 240) | no | sb |
| `EpyTdkD8muAwqbW7nbKqKfEq63iuhUdQrjJVbTojdGMY` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.03807 | 186651690 slots | FAIL: stale: round_open_slot 268114183 is 186651690 slots old (limit 240) | no | sb |
| `EsQkrtuJdRnDp6JvAcmRiYGoQbWL668TEZDW8VmrNcm3` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.010727114 | 170323300 slots | FAIL: stale: round_open_slot 284442573 is 170323300 slots old (limit 240) | no | sb |
| `EwwB6cSF5zgYPMLsSZDQ7YcMF8wGksEw38mmiUgT1jAh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.01359698 | 230520287 slots | FAIL: stale: round_open_slot 224245586 is 230520287 slots old (limit 240) | no | sb |
| `ExaSzwc3FmDyNuYG6mZ95kZyWkYVyDxtEQQRDtGxqptd` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.53886146 | 179657710 slots | FAIL: stale: round_open_slot 275108163 is 179657710 slots old (limit 240) | no | sb |
| `EzBoEHzYSx37RULrQCh756kNcA7iLrmGesxqpzSwo4v3` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.9345104 | 179657722 slots | FAIL: stale: round_open_slot 275108151 is 179657722 slots old (limit 240) | no | sb |
| `FaEXa4kxB7q4MfZhyBsvnmvFVT5ZV5LCMjtQvW9ejuVz` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.0744285e-05 | 211334086 slots | FAIL: stale: round_open_slot 243431787 is 211334086 slots old (limit 240) | no | sb |
| `FcSmdsdWks75YdyCGegRqXdt5BiNGQKxZywyzb8ckD7D` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.0001925 | 166459324 slots | FAIL: stale: round_open_slot 288306549 is 166459324 slots old (limit 240) | no | sb |
| `FdUyXNThsQxX4QKytZgR6J671GffdgLVntutzg1NJpbK` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 163.52223 | 158214141 slots | FAIL: stale: round_open_slot 296551732 is 158214141 slots old (limit 240) | no | sb |
| `Fph6dvJuWagAqcgQhyjqtt2Efmcy2ngGQFkHyckbE1hL` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3.247872 | 156815346 slots | FAIL: stale: round_open_slot 297950527 is 156815346 slots old (limit 240) | no | sb |
| `FwUp9ka9aANDxnKSXCRbLLwhsYPnqz12xcMBmd9kWH61` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 2.2536942e-05 | 157590180 slots | FAIL: stale: round_open_slot 297175693 is 157590180 slots old (limit 240) | no | sb |
| `FwYfsmj5x8YZXtQBNo2Cz8TE7WRCMFqA6UTffK4xQKMH` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.9999 | 148034073 slots | FAIL: stale: round_open_slot 306731800 is 148034073 slots old (limit 240) | no | sb |
| `G6VU3ktYLrBworVyFgnMVTr3LtKJvT2X1aRmDUUfZGEa` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 168.33619 | 162004228 slots | FAIL: stale: round_open_slot 292761645 is 162004228 slots old (limit 240) | no | sb |
| `GAQcjeUfeNzEoAcQHYs8a7RBhCcmX4Zn56cCAVBXu9eJ` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.042679 | 242715371 slots | FAIL: stale: round_open_slot 212050502 is 242715371 slots old (limit 240) | no | sb |
| `GHGKB6FxuQzFWNEPfN1vevnAYMAb6LeV4La5fhCea8U8` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.21783267 | 221253769 slots | FAIL: stale: round_open_slot 233512104 is 221253769 slots old (limit 240) | no | sb |
| `GPhiB59B2xKdPw7JNvd2GLsR3TgxcLWQfyLxwo7czE8f` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.000405 | 175630634 slots | FAIL: stale: round_open_slot 279135239 is 175630634 slots old (limit 240) | no | sb |
| `GayQym7GYT8C4z7Te37ZiqZUHRpBYotChMV5JRYJxdcQ` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.00027126285 | 159585053 slots | FAIL: stale: round_open_slot 295180820 is 159585053 slots old (limit 240) | no | sb |
| `GeKKsopLtKy6dUWfJTHJSSjFTuMagFmKyuq2FHUWDkhU` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.01009843 | 230520446 slots | FAIL: stale: round_open_slot 224245427 is 230520446 slots old (limit 240) | no | sb |
| `GfNrivZnvjxSi3oaVyj58F9vxZVaC4bxEC9KgtWbfofc` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 1.146e-05 | 295262973 slots | FAIL: stale: round_open_slot 159502900 is 295262973 slots old (limit 240) | no | sb |
| `GnGbhoGJgpoYEMFJncw7at8bfxZtEo3ggcPnXinMsq8b` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 168.41656 | 173775603 slots | FAIL: stale: round_open_slot 280990270 is 173775603 slots old (limit 240) | no | sb |
| `GvDMxPzN1sCj7L26YDK2HnMRXEQmQ2aemov8YBtPS7vR` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 214.02847 | 140336491 slots | FAIL: stale: round_open_slot 314429382 is 140336491 slots old (limit 240) | no | sb |
| `GvWB8uQFmuwdCEdHNKhUFZHeMnsCNj7rFJkQJbbkrgS6` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 263.44251 | 147855734 slots | FAIL: stale: round_open_slot 306910139 is 147855734 slots old (limit 240) | no | sb |
| `H96wZvruxyUa6eSBGswhSbAqs5Eg7YXUvDmczN6qeBcr` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.871999 | 275971622 slots | FAIL: stale: round_open_slot 178794251 is 275971622 slots old (limit 240) | no | sb |
| `HNStfhaLnqwF2ZtJUizaA9uHDAVB976r2AgTUx9LrdEo` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3350.9271 | 140336519 slots | FAIL: stale: round_open_slot 314429354 is 140336519 slots old (limit 240) | no | sb |
| `HR1mmjm2GeTRvdaN9VCy3wyx35h8Pimjv5wyzZ5NJmxE` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 3.4834434 | 157752166 slots | FAIL: stale: round_open_slot 297013707 is 157752166 slots old (limit 240) | no | sb |
| `HWAVEpmTjEj3K9RjMtAuL85uUdjnmFp6kmzTAgiyrvMG` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 233.35737 | 146084057 slots | FAIL: stale: round_open_slot 308681816 is 146084057 slots old (limit 240) | no | sb |
| `HyqfPF92YgJrrmnJQ6DsN8yN2o25rpCbVgdcvwGYe6x9` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 0.011668018 | 277438361 slots | FAIL: stale: round_open_slot 177327512 is 277438361 slots old (limit 240) | no | sb |
| `JBLjg2Q94FFjovuEjsDtmsDyKYFePqsqKQdi5HwcrL5D` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 160.60702 | 158258551 slots | FAIL: stale: round_open_slot 296507322 is 158258551 slots old (limit 240) | no | sb |
| `VVV8RKuJ7aAQuyEnnBrRSAGHjkehfPxNKqiB1u5w6Kh` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 81.20705 | 209912229 slots | FAIL: stale: round_open_slot 244853644 is 209912229 slots old (limit 240) | no | sb |
| `exHF7kMzCpJoxrWQXVcTftEsYxwoCPgr1xR4iXdTSDe` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 198.63135 | 156815350 slots | FAIL: stale: round_open_slot 297950523 is 156815350 slots old (limit 240) | no | sb |
| `qQcShWi6opRSuFcTfrjUePcjR6XzhPftztddhb5K7G5` | switchboard-v2 | `SW1TCH7qEPTdLsDHRgPuMQjbQxKdH2aBStViMFnt64f` | 194.4943 | 179657782 slots | FAIL: stale: round_open_slot 275108091 is 179657782 slots old (limit 240) | no | sb |

_Note: staleness is measured against snapshot slot 454765873 / unix 1791522002. Only Pyth receiver feeds with publish_time <= 120s old pass; the three other types are all stale in this snapshot (see below)._

## Per-reserve refreshability

**156 / 603 reserves are refreshable** (156 via main Pyth, 0 via Switchboard); **447 are NOT refreshable** with the currently on-chain oracle state.

A reserve is refreshable iff its best path passes: main Pyth if it passes, otherwise switchboard; plus the extra-oracle unchecked gate where one is configured.

### main — `4UpD2fh7xH3VP9QQaXtsS1YY3bxzWhtfpks7FatyKvdY`

89 reserves: **40 refreshable**, **49 NOT refreshable** (stored value $110,547,950.24)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `JMBiQLjvqrKkBApAFKT1WkGY5qphQzqu4NutEkU99KK` | RETARDIO | null | stale (10493226 slots old) | - | switchboard 873iWt.. stale (10493226 slots old) |
| `25PaiqNrpTPDydjN7xehiQiWqN97AJURDg8ej5jkbKWk` | SAMO | stale (10991811s old) | null | - | pyth 2eUVzc.. stale (10991811s old) |
| `2Mi3nAbpro5xqdi52ZbFbQ9cXyCdXrRGsKfVSTZG79zW` | WOLF | null | stale (68940265 slots old) | - | switchboard DiCe2c.. stale (68940265 slots old) |
| `2dC4V23zJxuv521iYQj8c471jrxYLNQFaGS6YPwtTHMd` | soFTT | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `35zqJiVKtEBec7XD9BG7USrLvAGTbio11Eua2Rfg2YfB` | WAP | null | stale (68936879 slots old) | - | switchboard FHujnd.. stale (68936879 slots old) |
| `3Mfk1tnEy2ffK2o4tboh7PqRDyhnhJb173V7rg887R4E` | META | null | stale (89849047 slots old) | - | switchboard 3cEZZq.. stale (89849047 slots old) |
| `4yGuczMxEKz17jtyeH2b7t7Mo9FaCRj2XJ79x3CxgW7G` | GIGA | null | stale (68947751 slots old) | - | switchboard Cn9jrM.. stale (68947751 slots old) |
| `564qbQPZZwAc1qU7dFne7f5JhPXbpoHkyv6yJy45FcBu` | Neiro | null | stale (68931100 slots old) | - | switchboard A2KV1P.. stale (68931100 slots old) |
| `5Sb6wDpweg6mtYksPJ2pfGbSyikrhR8Ut8GszcULQ83A` | MER | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `5f1MuRu5ANsN8m94vbZwptN7aX9xKGq7S9YWeAFzhNgd` | LAYER | stale (6722609s old) | null | - | pyth 2d6huL.. stale (6722609s old) |
| `5qrzqv35edbdjRiyRptxwdCbs8xQrrmTscySKdjyfcnQ` | BILLY | null | stale (29996911 slots old) | - | switchboard HffvJv.. stale (29996911 slots old) |
| `5suXmvdbKQ98VonxGCXqViuWRu8k4zgZRxndYKsH2fJg` | SRM | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `6SVtJkr1GcwPAxuoKQXaNfp9QKPECxXqQEucHJjniMDH` | PONKE | null | stale (37948773 slots old) | - | switchboard 3ADLue.. stale (37948773 slots old) |
| `6VttAuytifopBq9DTozKNEQsHSbq4JNZzzfLShypdm4p` | CHILLGUY | null | stale (18587992 slots old) | - | switchboard 8i4AUd.. stale (18587992 slots old) |
| `7PYtmaMEaTkpRvFT2TnyDfd83pFum95uy7vmKLD5kJRm` | HAMMY | null | stale (68968982 slots old) | - | switchboard Dbnjej.. stale (68968982 slots old) |
| `7ZpPKWQdiaQQkwLyKq2MQQeNKXLtBkQ59Xdbr5GpUnMZ` | PENGU | stale (4345972s old) | null | - | pyth 27zzC5.. stale (4345972s old) |
| `83W8WZNJhoujm5u4tRwakRBfhFiB6BTBqQkUs7aS9JGQ` | DEGOD | null | stale (133820533 slots old) | - | switchboard BFakhN.. stale (133820533 slots old) |
| `8YC6boJoPR6mT8GheRbTqydYjpoCqYwYvWtYbdcUwz59` | DADDY | null | stale (68931100 slots old) | - | switchboard 8o433d.. stale (68931100 slots old) |
| `8aRJW9C4vxkVuK7MfsKSnmR4HzcGcpdAnNEaqfiKCwtp` | SPX | null | stale (30271899 slots old) | - | switchboard 22zLMm.. stale (30271899 slots old) |
| `8bDyV3N7ctLKoaSVqUoEwUzw6msS2F65yyNPgAVUisKm` | FTT | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `8oht6TZ6XB8aWmBtXyXwfCdaHMDqt6E3PAmsBuHcvup7` | BOME | null | stale (68941526 slots old) | - | switchboard 7t7mZ2.. stale (68941526 slots old) |
| `9MNU28Kog3j5oNkQDeMHbVQqaGSxh6T6VBHvWKXoB8zj` | BOBAOPPA | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `9jC8My4C9WCNWHmBnnAGqpCbbNU1FVEs2B7PNbQPb1U6` | WEN | stale (4287000s old) | null | - | pyth CsG7wX.. stale (4287000s old) |
| `9n2exoMQwMTzfw6NFoFFujxYPndWVLtKREJePssrKb36` | RAY | stale (1265510s old) | null | - | pyth Hhipna.. stale (1265510s old) |
| `A97Jhqn4itgsDaKfuCAbtMFWZ5CVe4SJJsyZLS2nzS8H` | XBG | null | stale (71890257 slots old) | - | switchboard 6SGfHM.. stale (71890257 slots old) |
| `AU4ZFhkz8rnWMtCgiHVZ6eCrjG6QBH4exV1XjUx8KV6d` | PNUT | null | stale (64975000 slots old) | - | switchboard 8bRsgr.. stale (64975000 slots old) |
| `Ab48bKsiEzdm481mGaNVmv9m9DmXsWWxcYHM588M59Yd` | UST | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `AypJfTkds5DwzFUHzZgx13ivT86jyFxQDaQgjnMLjRtN` | ZEUS | stale (6081835s old) | null | - | pyth C2Y1BN.. stale (6081835s old) |
| `BHYzuqNawczsvrDTPNS6JFQtCVPyYJv79XJB9FyNNsr8` | JASON | null | stale (68969107 slots old) | - | switchboard 9jjD5J.. stale (68969107 slots old) |
| `BJ9qkhzr1FKUoa2vDQ5yVhwEH4XwyMnt6NJ9KtAGC4bs` | CTAN | null | stale (68939583 slots old) | - | switchboard J9WqPk.. stale (68939583 slots old) |
| `BJXPu3yB7D35jC1kg3KdAZvam5bnb8hL1iY1h9kNJwik` | GOAT | null | stale (13805539 slots old) | - | switchboard 1EmSj4.. stale (13805539 slots old) |
| `BTzJ9wLyHAZFAqGoWRAwZetRiGRgkpBuL85wXKXZF8Hx` | POPCAT | null | stale (30272380 slots old) | - | switchboard 5FWVce.. stale (30272380 slots old) |
| `C7A8b6267KpbxA89ZhpEbtBPkj6iXXAD5sasqc3NfuoK` | MICHI | null | stale (68943396 slots old) | - | switchboard DdXZEu.. stale (68943396 slots old) |
| `CviGNzD2C9ZCMmjDt5DKCce5cLV4Emrcm3NFvwudBFKA` | SLND | null | stale (4150904 slots old) | - | switchboard EEoQp9.. stale (4150904 slots old) |
| `DzmAjVBZXhtk4g2N7UoEbgFQhBsyYzo6Bviqw18ibQ1y` | MUMU | null | stale (37948744 slots old) | - | switchboard 13YLq6.. stale (37948744 slots old) |
| `EnvTk9Spv57WfBoSiU3vq2gCuHGLatA9WbsFVwiC2cjS` | MAGA | null | stale (58690025 slots old) | - | switchboard GoyYzx.. stale (58690025 slots old) |
| `EvPrRUmgz74QDiiSunUn7t1PwUv9ambsqwdm9wcJg6Bu` | MOODENG | null | stale (68939963 slots old) | - | switchboard EtAQgJ.. stale (68939963 slots old) |
| `FKZTsydxPShJ8baThobis6qFxTjALMkVC49EA88wqvm7` | ORCA | stale (4471728s old) | stale (175916528 slots old) | - | pyth 4CBshV.. stale (4471728s old); switchboard 7ySvXU.. stale (175916528 slots old) |
| `FXAZzNMU6PBK3MX2yDhLNmRh74PkDj8iPJtJGKo867N2` | POX | null | stale (68943705 slots old) | - | switchboard 576Y2a.. stale (68943705 slots old) |
| `G7seqaHu2vNiZcxHewynUjeaUcrf38j6yQTbACF4sWqL` | BLZE | stale (24082771s old) | stale (18106198 slots old) | - | pyth FFv5yo.. stale (24082771s old); switchboard 7czWHL.. stale (18106198 slots old) |
| `GYzjMCXTDue12eUGKKWAqtF5jcBYNmewr6Db6LaguEaX` | BTC | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `Gi4cANbdscEhwSw5wSfdB2EJ6CGSx89yxVRYCXNoWZDp` | MAD | null | stale (138521663 slots old) | - | switchboard 6ZsHzJ.. stale (138521663 slots old) |
| `GmJ5E5S38dR1MbiWHdaZrFeBtsrNu329WX6Ls119ePnp` | GIKO | null | stale (68940226 slots old) | - | switchboard DN2oVj.. stale (68940226 slots old) |
| `Gn5CSJeXoyXhG2pK5P2CUnedcRSejB7beQDWwiihTGG3` | FWOG | null | stale (44479257 slots old) | - | switchboard 7q3FjY.. stale (44479257 slots old) |
| `GqnTPten6D1w3LTYkcXNUbsyzpZ3kFZNwRLBhBoMeUf8` | WUF | null | stale (68952427 slots old) | - | switchboard fDK8Tb.. stale (68952427 slots old) |
| `HcMZxFXrjc48sCarcH37DYABVDsMPbrPd9bpPA5q7zBt` | SCF | null | stale (16327616 slots old) | - | switchboard Ei8deg.. stale (16327616 slots old) |
| `Hq52CTcTUUo69PFJVX7orgENxyKNipxGkHQVBtr3sV3C` | SLERF | null | stale (68932457 slots old) | - | switchboard ERTeG1.. stale (68932457 slots old) |
| `Hthrt4Lab21Yz1Dx9Q4sFW4WVihdBUTtWRQBjPsYHCor` | SBR | null | stale (4417329 slots old) | - | switchboard 8NHRED.. stale (4417329 slots old) |
| `HwGvPLgDpRcghpbRcUz3bfwvWiHRYdT4Czt8NgB55aRF` | MOTHER | null | stale (68931100 slots old) | - | switchboard DksamX.. stale (68931100 slots old) |

Refreshable: `CCpirWrg..`(mSOL,pyth), `2MwiTp5o..`(JSOL,pyth), `2p3cnirf..`(bbSOL,pyth), `3B29sQsg..`(tBTC,pyth), `3DjAsrew..`(bSOL,pyth), `3PArRsZQ..`(soETH,pyth), `47kDoVo8..`(saveSOL,pyth), `4d5aycKF..`(wstETH,pyth), `4rS8X6uw..`(WIF,pyth), `5Pf253eB..`(BONK,pyth), `5sjkv6HD..`(stSOL,pyth), `6TyNRszA..`(SOL-bSOL MLP,pyth), `6ve8XyEL..`(mSOL-SOL,pyth), `7ED1Yofz..`(sSOL,pyth), `7ZedNeKC..`(SOL-mSOL MLP,pyth), `8K9WC8xo..`(USDT,pyth), `8Pbodeao..`(SOL,pyth), `8i58uNEa..`(saveSOL,pyth), `9UueaExT..`(hSOL,pyth), `9mZsd1b9..`(USDT-USDC,pyth), `9mpAoYdK..`(raSOL,pyth), `ASR6ULAZ..`(JTO,pyth), `AfsmTSxA..`(PYTH,pyth), `Ag7UiqS5..`(cbBTC,pyth), `Aj3MjwEe..`(JupSOL,pyth), `BRsz1xVQ..`(JitoSOL,pyth), `BgxfHJDz..`(USDC,pyth), `Bvdjsmab..`(W,pyth), `CFM2QsDj..`(MEW,pyth), `CPDiKagf..`(ETH,pyth), `CyW6wS3h..`(bonkSOL,pyth), `DUExYJG5..`(INF,pyth), `DdJBpSXj..`(BNSOL,pyth), `FbmGHM3d..`(TRUMP,pyth), `Fopbwd7w..`(MNDE,pyth), `GhNvGen7..`(PYUSD,pyth), `H5znFbw5..`(haSOL,pyth), `HPDFoSZs..`(JUP,pyth), `HQDViv8g..`(zBTC,pyth), `HUL7GeHE..`(USDS,pyth)

### ScarCoin — `E2PfMAjUWkTZG81nWY9bm1DRi72uZkfL79RWrRxVWw6s`

5 reserves: **0 refreshable**, **5 NOT refreshable** (stored value $98,836,931.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7MpyjrvzpFATwSy981an9ek2jkt3sEdduYRpjffz2BMH` | STCC | null | stale (179657612 slots old) | - | switchboard 2Qo6j9.. stale (179657612 slots old) |
| `7mYFEmyPHVxaGY929Y3HW7jWpX4fWXm6wNrbXGcaTpsv` | STCC | null | stale (140336519 slots old) | - | switchboard ETAaee.. stale (140336519 slots old) |
| `9wXKZmEwNoUZ4phqNpdtSVL6UWhiJZQicedygefPuvYE` | USDC | null | stale (140336579 slots old) | - | switchboard BjUgj6.. stale (140336579 slots old) |
| `CQ9BztAzDdo5P5mnn3HDgQfPSHVHjBW6cKCxnXqCsXzs` | USDC | null | stale (140336579 slots old) | - | switchboard BjUgj6.. stale (140336579 slots old) |
| `H6sqZmV95bwhR3mBSnKDmFPYva5nzhaKgBfzwrm4Wvbc` | STCC | null | stale (140336519 slots old) | - | switchboard ETAaee.. stale (140336519 slots old) |

### Star Atlas Puri — `2Ao1JGyr6kBqmUkLQPFRaXuXJW5Sz14RHku6FNwxCRPp`

5 reserves: **2 refreshable**, **3 NOT refreshable** (stored value $8,120,050.71)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2XpwPdQibi9ePmG6zhNHXrTn26uumiYmb4r9uEy9XVCJ` | POLIS | null | stale (35110913 slots old) | - | switchboard 3pQ5Ae.. stale (35110913 slots old) |
| `Efzu5frwXKdHhkkEiB6i1mDpjkzquRdaP6Q4nupgYAdF` | ATLAS | null | stale (56356362 slots old) | - | switchboard 2gyXLj.. stale (56356362 slots old) |
| `GwnNZ6JCR1V2Lrdv5MEGYC3kkQGZCeqKaJ3NzmjX97EH` | Puri | null | INVALID (no result (result.slot == 0)) | - | switchboard FZnb8B.. INVALID (no result (result.slot == 0)) |

Refreshable: `4hQfnKBd..`(SOL,pyth), `5ZXGXFDm..`(USDC,pyth)

### LST — `xpP9zdDE7mVgXM1nc3nQq2gqQE5B5QfF6zFA8sLTinq`

6 reserves: **2 refreshable**, **4 NOT refreshable** (stored value $8,044,549.31)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2SQWynnxNUCXuGxS5moZ8pcVZNbdFW3bNgxuWRAxDfqN` | JupSOL | null | stale (158214141 slots old) | - | switchboard FdUyXN.. stale (158214141 slots old) |
| `7o7RnwQj19z73JbWEEBKvxkej8o8Rn4ghtoneABS4kSJ` | USDT | null | stale (186651690 slots old) | - | switchboard EpyTdk.. stale (186651690 slots old) |
| `DgHnkU21Z9AKeBx9wcNBrRCEVwmjPo8VWnU6tfYjQbUR` | INF | null | stale (156815358 slots old) | - | switchboard 6AQHz9.. stale (156815358 slots old) |
| `J429uoTV1SUQPaRApxUKPsL1Qgx1gB2KAGs5weoCRfVy` | DAI | null | stale (185934496 slots old) | - | switchboard 2K6g2c.. stale (185934496 slots old) |

Refreshable: `7TMy8PxH..`(SOL,pyth), `EmNEYvcb..`(USDC,pyth)

### stacc eco — `Bq6E2J79XnbD2Tn7h4PvELTdtGmiEfT36sSMYaJASt9w`

25 reserves: **11 refreshable**, **14 NOT refreshable** (stored value $7,609,661.64)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2ZWWd389sB3KwMMDVE8r7poxMsHoJX9sKRAQcitJKbRj` | SLA | null | missing | - | switchboard DAUfBu.. missing |
| `2iEtbLBdxkmMhbiirwbk43Ad9KfiYXn3sDkBDKZidkaX` | myst | null | missing | - | switchboard 4Dg6nQ.. missing |
| `3Tj9Gy1n6esfN5fXzqJKyuM85ohJWSomrqPWbuPoGxGY` | Manifesto | null | missing | - | switchboard 7ii9gK.. missing |
| `4wUZQtjCgFHG88A4yGkEqw2WXZLL7bqZ66B4VN8THZ1X` | SAMO | stale (10991811s old) | null | - | pyth 2eUVzc.. stale (10991811s old) |
| `5isQhKQShQ2TUVL9ctjKgcgR7eskJeoigWucP4q3DUXV` | orca | null | missing | - | switchboard 4Dg6nQ.. missing |
| `5s4wKNDtW5yEUTaskoba8x5csEN5Ae1dZv5GkzP5Nq3H` | fomo3d.fun | null | stale (111008589 slots old) | - | switchboard 56PpAg.. stale (111008589 slots old) |
| `6MPvh9dmg1cjMUs592oBRQ4Mn5tY7zSjPcyEMJWeg4e9` | SOL | null | stale (19310408 slots old) | - | switchboard Ceveqp.. stale (19310408 slots old) |
| `6Ych6n3LuX9akkjeepRH3tYtqk7KMVQKtzSXrYhmWvLy` | WEN | stale (4287000s old) | null | - | pyth CsG7wX.. stale (4287000s old) |
| `7NrcTDUSWaKkjPVobuJAZPkjQnPsuZcw6u2yUmTVwdsk` | PENGU | stale (4345972s old) | null | - | pyth 27zzC5.. stale (4345972s old) |
| `8GAmKkwbbmRC9vP8EBXBQj8uCw7mJSrd6e129CAqaCuF` | SAMO | stale (10991811s old) | null | - | pyth 2eUVzc.. stale (10991811s old) |
| `91caaGF5cUZHLqYjCm6vwGD4FCkd7koj38DNJNTZLhyN` | WEN | stale (4287000s old) | null | - | pyth CsG7wX.. stale (4287000s old) |
| `BqPP8YxnqeT1fAXXs1Ph5sKE61Yi4uchnFFRX5cEMKZC` | SLND | stale (43450528s old) | null | - | pyth 6vPfd6.. stale (43450528s old) |
| `CsMnZwSiRXfCn7hi7w5qejqUpwxrN4XiQb2ibwMyM57k` | myst | null | missing | - | switchboard 4Dg6nQ.. missing |
| `HYE7NSmWw1hhscE678ZHENXGYQ91zTnkE5WHXvVKoV4i` | myst | null | missing | - | switchboard 4Dg6nQ.. missing |

Refreshable: `JaMrq8ja..`(JTO,pyth), `4B8i7n8E..`(PYTH,pyth), `4EKRwWaQ..`(BONK,pyth), `5G7LWq7M..`(WIF,pyth), `6qYDw3oh..`(JTO,pyth), `7LAt2Qqi..`(BONK,pyth), `A7Uzo9WT..`(MEW,pyth), `ALTEHzu5..`(WIF,pyth), `BReW46zx..`(W,pyth), `DEzQ1zFZ..`(MEW,pyth), `HEh8qB3H..`(W,pyth)

### GNME / USDC — `EX8Zp5L13fu2oq5vRzh1y5CYwKNqfR3E98Bj2hNUw7VH`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $6,855,319.33)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2Uwu6EmBVfamrdpywmRsuA5XYGSpZxo4maZJU39GPmh2` | GNME | null | stale (19979095 slots old) | - | switchboard 9oFebZ.. stale (19979095 slots old) |

Refreshable: `GYWUemgm..`(USDC,pyth)

### TRUNK/USDC  — `616Kxm68sCsFJTzKfqJYt1o2Na5qrujgfhrhUJsSPXHx`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $5,297,140.74)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `9SdGVn594S8fk8ZU3xcvZ1Cd4fjJgNxCN32upHhFZgJu` | TRUNK | null | stale (13226870 slots old) | - | switchboard GMoGPv.. stale (13226870 slots old) |

Refreshable: `8nXn5zEX..`(USDC,pyth)

### cool — `Ckya2fwCXDqTUg9fnWbajR6YLcSfQmPxxy5MyAoZXgyb`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $5,000,003.16)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `CxLkG25ybMCUcu5CVtYm9Bn7x9Lcr96wstxAtb53Xrcr` | SLND | stale (168728418 slots old) | missing | - | pyth HkGEau.. stale (168728418 slots old); switchboard 7QKyBR.. missing |
| `DWmAv5wMun4AHxigbwuJygfmXBBe9WofXAtrMCRJExfb` | COOL | stale (168205596 slots old) | missing | - | pyth Gnt27x.. stale (168205596 slots old); switchboard CZx29w.. missing |

### KHAI — `bQYiravAGVmvBzX8VjaSvMNmiKXcS7q6sDjutQLAQs3`

4 reserves: **3 refreshable**, **1 NOT refreshable** (stored value $4,004,948.58)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5xG23Q45e2ALbTaVn7nkv1KX2sgCY5x5b133bPJKUmV3` | KHAI | null | stale (112667113 slots old) | - | switchboard DQxiaB.. stale (112667113 slots old) |

Refreshable: `5FfGfaxP..`(SOL,pyth), `B6TjRpJg..`(USDC,pyth), `GzNxnSd3..`(USDT,pyth)

### FLAME — `4AtgvKEUnVzfnhGhfWdCbMt1ziV1E3Gk237JHP8g9TCv`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $932,541.85)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2b2MWtQR9tKJtXcuL1iE5Bw9FAi8N6pu4Ua3DDfakNYU` | SOL | null | stale (140336491 slots old) | - | switchboard GvDMxP.. stale (140336491 slots old) |
| `5JLy3Xpki1thBZfshvGhhw6fSzcwHcJwJxy5peUrVCSH` | FLAME | null | stale (156815347 slots old) | - | switchboard 4yphXf.. stale (156815347 slots old) |
| `7vkzJegSxoRRWcTNWKK3tidzcTXsVWnpaCYH5ptQNFCT` | FLAME | null | stale (159585053 slots old) | - | switchboard GayQym.. stale (159585053 slots old) |
| `F4L35cxj6VXL2zQn8w6ee8J3rv1Ymt2PFapwmjQuENbu` | USDC | null | stale (140336579 slots old) | - | switchboard BjUgj6.. stale (140336579 slots old) |

### TURBO SOL — `7RCz8wb6WXxUhAigok9ttgrVgDFFFbibcirECzWSBauM`

2 reserves: **2 refreshable**, **0 NOT refreshable** (stored value $716,376.83)

Refreshable: `UTABCRXi..`(SOL,pyth), `EjUgEaPp..`(USDC,pyth)

### TPX — `7ADCUpQcrh19kVzhJTNC7VpDKoGSU93JhCbxQa4BynBU`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $417,055.43)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7WwV8yLKetA7P4659s23bu2JHpi6MhkfU5825ZSdTiHV` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `AnBGhuJkgxCEBXZhEBA2t7GrkHiq2fHGxwRUPraZHPcx` | TPX | null | stale (200117647 slots old) | - | switchboard 4EznFN.. stale (200117647 slots old) |
| `Gp63pCHC12SJJZwvNXpbzq8mWZaKYe6DYXNThkQ4HR8M` | SOL | stale (155707389 slots old) | stale (195998729 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard BcEhqv.. stale (195998729 slots old) |

### Helium SubDAO's — `9bjYtKqKCXVjucU3KPi9hNs2ia5DCCinQxvVBtRKZoqL`

6 reserves: **0 refreshable**, **6 NOT refreshable** (stored value $135,111.60)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `vjmsYM5LdY9QBD9cfnt5MZJATg2ZBa8HSNMjmseVsd5` | SLND | stale (168728418 slots old) | stale (310302061 slots old) | - | pyth HkGEau.. stale (168728418 slots old); switchboard 3btrKt.. stale (310302061 slots old) |
| `286ex339z3Ud3oECStmBHamundDQRgaozJJ7a4kbmiWV` | MOBILE | null | stale (179657536 slots old) | - | switchboard 7bEjAX.. stale (179657536 slots old) |
| `4Upv3qpt6KfMwP2BewPVL8AQy6ycMvfrrxZCVQAW4L7A` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `A6SaxkdoyoY2mQ2DCorqMPQQvBJm2vX2XdPG1KSwM1fL` | HNT | stale (168204087 slots old) | stale (250449465 slots old) | - | pyth 7moA1i.. stale (168204087 slots old); switchboard 7MryWi.. stale (250449465 slots old) |
| `CaPLPbM3PQvZjnvZm8W2hFGooogGUTE78iKs5Pbxt6fr` | IOT | stale (168728418 slots old) | null | - | pyth 8EPnK3.. stale (168728418 slots old) |
| `DCnLD1Mx3pvANxTqmJW3kUWyb2BJ9xdMsHkS1D4qbL53` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### JLP — `7XttJ7hp83u5euzT7ybC5zsjdgKA4WPbQHVS27CATAJH`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $120,965.53)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `CKqi88U4nuuU5THsELnc4vtycLLc3W3rdCWZg7VCi88T` | USDS | stale (3768576s old) | null | - | pyth DyYBBW.. stale (3768576s old) |

Refreshable: `8dj84nco..`(JLP,pyth), `BJfY2E6T..`(USDC,pyth)

### ISC — `HeVhqRY3i22om5a7WGYftAJ2NjJJ3Cg5jnmMCsfFhRG8`

6 reserves: **2 refreshable**, **4 NOT refreshable** (stored value $116,991.45)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `76bdhBbAsqkUV9NmVpt2VVyZ8NWBw593pNTJ8jcD2pXN` | JUP | null | stale (13070199 slots old) | - | switchboard GCXacA.. stale (13070199 slots old) |
| `8T25kW4pHhr6mNYYa3NPN62GVNRkzZ9PRkiXgRbKLGDr` | ISC | null | stale (10234079 slots old) | - | switchboard B32Wk5.. stale (10234079 slots old) |
| `FewrTs5PrbpWMXwoBuu9qiUASF3GgwxdNfXwNdqusxnV` | CLOUD | null | stale (50679828 slots old) | - | switchboard GcwQCz.. stale (50679828 slots old) |
| `GYPjtZ2PaMZV7R4funNGagpKdnGs9PZhJ6TXar3oyvnt` | INF | null | stale (4723441 slots old) | - | switchboard C8Wh4Z.. stale (4723441 slots old) |

Refreshable: `4fmVtGRD..`(JupSOL,pyth), `5chXNBwr..`(JLP,pyth)

### Staked SOL — `HPzmDcPDCXAarsAxx3qXPG7aWx447XUVYwYsW4awUSPy`

7 reserves: **0 refreshable**, **7 NOT refreshable** (stored value $114,378.49)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `kfTnH3RDCrBne9T8LuxFbfeutFS3krDJj3ncdniVrj1` | INF | null | stale (151447751 slots old) | - | switchboard 9Rr9Ux.. stale (151447751 slots old) |
| `tgw9BySPKhqYkCoJoUU33JAardTgkcZ8YBCfDDn9YnU` | laineSOL | null | stale (158895111 slots old) | - | switchboard 2EU8d2.. stale (158895111 slots old) |
| `2kSRmH4Dovfy2sDSyuDmN3HgQiFpqxRJging7pMWEXe2` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `6syytYcS12YoRyXg5eD2HasvVK1XL9VC4bR62Tr77Mfp` | stSOL | stale (168728418 slots old) | stale (140336519 slots old) | - | pyth Bt1hEb.. stale (168728418 slots old); switchboard 9LNYQZ.. stale (140336519 slots old) |
| `AHJAfVNs28geGYTdocU5eN8Z89G9YmZMWpQYvqTaJWLk` | bSOL | null | stale (156882246 slots old) | - | switchboard EPw1Vb.. stale (156882246 slots old) |
| `Bb7fx2HRTaCdVN8SDZ98FDZ6TaExgCVGo4YZvbKL7k32` | mSOL | stale (168204087 slots old) | stale (146084057 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard HWAVEp.. stale (146084057 slots old) |
| `Duwgx5cLg5htp3ujTTf8n1KJYFfubqpQSekX81EUtrhL` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### JLP/SOL/USDC — `ErM46rCeAtGtEKjvZ3tuGrzL6L5nVq6pFuXukocbKqGX`

3 reserves: **3 refreshable**, **0 NOT refreshable** (stored value $114,210.39)

Refreshable: `5KgLA216..`(JLP,pyth), `8kd8cDJE..`(SOL,pyth), `GShhnkfb..`(USDC,pyth)

### REdao — `4BbFBSYCRs11goyTVUsSnFuMydyV9vvZkH9aqakTdKyb`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $113,268.15)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `GWhc29nWdLX9Zvex7q7r6WzKFBQAWXHz773dLabmqdyz` | $RE | stale (4372050s old) | null | - | pyth ArjngU.. stale (4372050s old) |

Refreshable: `B7Kvg7bR..`(SOL,pyth)

### Stable — `GktVYgkstojYd8nVXGXKJHi7SstvgZ6pkQqQhUPD7y7Q`

9 reserves: **3 refreshable**, **6 NOT refreshable** (stored value $90,099.41)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `NoTf6a9khWa5cCh6v5RRronH7YuatY7gDWmdKUPoBhM` | USDH | null | stale (179657716 slots old) | - | switchboard 7JeJws.. stale (179657716 slots old) |
| `27YJsVpHWvjS8BKaz7Gd8unSFJAMrh6gPEFjqhYxn9AE` | UXD | null | stale (179657574 slots old) | - | switchboard 8hhBZD.. stale (179657574 slots old) |
| `3M4dCjjzu822JShmzpATSm57Fo1oUHysYTh1D7WrLHbP` | DAI | stale (155707389 slots old) | stale (220846305 slots old) | - | pyth CtJ8Ek.. stale (155707389 slots old); switchboard 8fsomf.. stale (220846305 slots old) |
| `A57FVdDgcyz1NserCSMSWaWDyfWZw77ikfXvE2cwPF18` | UST | stale (155707389 slots old) | missing | - | pyth H8Dvrf.. stale (155707389 slots old); switchboard 8o8gN6.. missing |
| `DyJZX45rgh9nADa19tsFeSV69ZwvX4UqPoPP39mdBiDq` | PAI | null | stale (193359188 slots old) | - | switchboard 6FeoHR.. stale (193359188 slots old) |
| `HZ75yaVXYA4buymgZhzkLoPPyWyRGskg6hWTgkcnsWwL` | USH | null | stale (193326286 slots old) | - | switchboard AKp55L.. stale (193326286 slots old) |

Refreshable: `aMyCaGf7..`(USDT,pyth), `ECNduHkb..`(EURC,pyth), `JCRDg9T5..`(USDC,pyth)

### GRAPE/SOL/USDC — `9Lyjw7CuNVxj9wDaCANZ3ReYAosegF4K7yw4HpGQn8n1`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $61,914.56)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5asHUa8yJUciGwZcBDMpZaXcZRZCHBc16KsvUmN4318i` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `7PqAg8MVYUPKzyprmjkFzLFY9Z3wmSwh9tyGbZ4Xuz8D` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `Gb6kjj4zKLtvbTM6EtUJkvc8jSG3yFC1B7LJxhLp71us` | GC | null | stale (175709066 slots old) | - | switchboard 5VHHh8.. stale (175709066 slots old) |

### Jupiter LP — `76iPEpJxr7p89FDe4GzD43dv7skhb9aH3Fh8cCrQrKUs`

5 reserves: **0 refreshable**, **5 NOT refreshable** (stored value $60,090.11)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2QbLKT4MmTQvTkX6qHvi2DufHTt2xEHkFZjgWDcQS1EX` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `4TdRfD77qA7GLPF3y4HqeWBK9XFt9HwN3bu6jXw1UAg4` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `ACk4Qcwp6AxhSXsnjhUcHFZrUmPhh37z3ZpdaNTvT77c` | JLP | null | stale (179657722 slots old) | - | switchboard EzBoEH.. stale (179657722 slots old) |
| `AwGnKfsHvvYdi2tAaUze1B1Cz26bnetRWdMZkBxJuv7z` | USDT | null | stale (140336519 slots old) | - | switchboard 57EF89.. stale (140336519 slots old) |
| `D4G9wUCDD8SJcfw521fw4YzaD615zdg5igiCqW7pzuuU` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### BLOCKASSET <> BLOCKBET — `C3L8Ntcjj6zUbCoBxNUyLGrTTDzDt6DdYLLbVMd3gFJ7`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $39,813.69)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `B7gbJBiaUKwf5g4xt6XrEDU4ho5DNEtADaaTVXTTkzgz` | BLOCK | null | stale (96543349 slots old) | - | switchboard 2Uv89o.. stale (96543349 slots old) |

Refreshable: `6ik7qv9W..`(USDC,pyth)

### BONK — `GnCfohzaT8uCYsn4ybcsfUZJ8BUuz9F82VivJSW9NMnj`

4 reserves: **4 refreshable**, **0 NOT refreshable** (stored value $21,771.97)

Refreshable: `5mxaL7hQ..`(BONK,pyth), `ATaWrUs2..`(SOL,pyth), `AzNRYsUp..`(USDT,pyth), `HXyXfwv8..`(USDC,pyth)

### Kamino USDH — `Epa6Sy5rhxCxEdmYu6iKKoFjJamJUJw8myjxuhfX2YJi`

9 reserves: **4 refreshable**, **5 NOT refreshable** (stored value $20,704.28)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3aj1pmAjWcSPEbkUDrZn7hotrZeQSfW1VVN5ULMTuCot` | kUSDH-USDC | null | stale (230520446 slots old) | - | switchboard GeKKso.. stale (230520446 slots old) |
| `6e72R9KbYrc1RZiXd6ToF7fMyjGLrAf2itqApQyWGWWn` | USDH | null | stale (179657716 slots old) | - | switchboard 7JeJws.. stale (179657716 slots old) |
| `8VsVMnhLQoELpCbu5zJN8yosahsEZefQ9mSnoywmzqtE` | kUSDC-USDT | null | stale (230520287 slots old) | - | switchboard EwwB6c.. stale (230520287 slots old) |
| `CxkBnZ1QFrRE4BYFWQSwkh5CoAvcwLxU5U1FLo96c8bh` | kUXD-USDC | null | stale (230520403 slots old) | - | switchboard BErjJG.. stale (230520403 slots old) |
| `FF7aibncMqk4SFGgDck2uQ5Y5gJAmYjqTD4Ardw4Pjiv` | BTC | null | stale (172656192 slots old) | - | switchboard E4D4C5.. stale (172656192 slots old) |

Refreshable: `3i9Vjr7u..`(USDC,pyth), `8UNK5B1y..`(ETH,pyth), `FcMXW4jY..`(SOL,pyth), `GvRfzwYy..`(mSOL,pyth)

### NFT — `29yTiqjGdoNiRLMVc7ZoqFpbW3gkmefwMG9SUiMMD4J9`

5 reserves: **2 refreshable**, **3 NOT refreshable** (stored value $18,140.35)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5jcT4WkHE3JCXD5GjZ8hjvXgWd8DmwEHLSf9BjZqkp1z` | svtSMB | null | stale (209912229 slots old) | - | switchboard VVV8RK.. stale (209912229 slots old) |
| `5mrrZ1rZmKZtzNdoCojfHqQzzf89k3PdJnkiq1ano7ti` | DAPE | null | missing | - | switchboard BTWdcU.. missing |
| `EpZipddM7X7TofTzypVaz9GkjBziWgZZCgPz9HhGAB1t` | SMBD | null | stale (209912229 slots old) | - | switchboard VVV8RK.. stale (209912229 slots old) |

Refreshable: `8WpwDA1q..`(USDC,pyth), `8xogd14b..`(SOL,pyth)

### Step — `DxdnNmdWHcW6RGTYiD5ms5f7LNZBaA7Kd1nMfASnzwdY`

4 reserves: **2 refreshable**, **2 NOT refreshable** (stored value $16,921.59)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `C5ozcRb4PJeJvakPeGgm9bgwcL6rPcKPfV95d2owW86C` | STEP | null | stale (216585338 slots old) | - | switchboard 24mXtP.. stale (216585338 slots old) |
| `HH9Aig5MAvMNcivGfAbWU5Da9nfiTwBaYJBK2KZyZppn` | xSTEP | null | stale (175788546 slots old) | - | switchboard 2kHb4h.. stale (175788546 slots old) |

Refreshable: `7trBAMkV..`(SOL,pyth), `FCU2wpx3..`(USDC,pyth)

### Coin98 — `7tiNvRHSjYDfc6usrWnSNPyuN68xQfKs1ZG2oqtR5F46`

7 reserves: **1 refreshable**, **6 NOT refreshable** (stored value $16,255.82)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3eDDvVgyxZ7aWLjLmKDYpeGHidCH7jkfHXcCXtpGqNKg` | USDH | null | stale (179657716 slots old) | - | switchboard 7JeJws.. stale (179657716 slots old) |
| `46Lh1P2XmTNG8Gnt4zkTdG1BXi2V18NggfYTbXpSzAYy` | UXD | null | stale (179657574 slots old) | - | switchboard 8hhBZD.. stale (179657574 slots old) |
| `5twXA9pwa6P3pmKz5NRiviffgGT1bqmf5d1dXVxJL895` | USH | null | stale (193326286 slots old) | - | switchboard AKp55L.. stale (193326286 slots old) |
| `9bVRrxPjXBxM6rEyTLcR2opvdA2UGhdDwL8CLLm1b8KP` | C98 | stale (155707397 slots old) | stale (221347879 slots old) | - | pyth 45rTB9.. stale (155707397 slots old); switchboard AV6G4v.. stale (221347879 slots old) |
| `A3cQwWXzsaC5nfLDf7cbakZeBAJFGf1qMxvnf4yDRUUJ` | PAI | null | stale (193359188 slots old) | - | switchboard 6FeoHR.. stale (193359188 slots old) |
| `B5513y5wt161CxLX5U2o5cGFHYbcGMuTKc6yu1ni3AbC` | UST | stale (155707389 slots old) | missing | - | pyth H8Dvrf.. stale (155707389 slots old); switchboard 8o8gN6.. missing |

Refreshable: `GdJd6a8Z..`(USDC,pyth)

### Magic Internet Cat Fund — `5KqCWtLhXs33ebzjPDgP5QZeFzZD1sceg4oCCRznJBgz`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $12,993.12)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2NDi89hqXAF32Hh71aGGdGVbBjMM3u7dthhDAH76UtV2` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `2z8LvedPz3BthGNTtXDLmAkdVybk8ZpdfZYuw6rc9JtG` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### ISC Launch — `FDbd5VaPKWuEKuBKLbV8pCg4PNnqsV6zW6V1yZ8Z94Kj`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $10,874.35)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `DeDU2m8Xfv4kir3NnLk4euAWCAaJ6mAr8dq9zSy7Fytd` | ISC | null | stale (10234079 slots old) | - | switchboard B32Wk5.. stale (10234079 slots old) |

Refreshable: `FrAtqNXh..`(JTO,pyth), `H7ZxDRCu..`(PYTH,pyth)

### Peepo — `hzwcnmFYxgvx1S2u1m9LBefKr3ikqdrhfAHgv7oBaU8`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $10,013.30)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4kMphMNWD3dNA8LFaD7mq3s1McrNKKcpUpTnYTR88vqd` | PEEP | null | stale (157590180 slots old) | - | switchboard FwUp9k.. stale (157590180 slots old) |
| `A5Jexc3i5u5NsFbErSFnWNtogMrVuasVhftN3T5ZqcyC` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `Ee7W5oxivwvuMW5a1ENkW9JKB5rjunhR55B8e6tDvVCc` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### Jungle Defi — `7gZNNa7Nq6RtsorUB3G4561iTW34kR1tKGpsPn8uFZEn`

5 reserves: **0 refreshable**, **5 NOT refreshable** (stored value $8,730.04)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `6XYpvicJjUgMrNk3GmdKXePJV8t4znQd9XnatmG6hbrk` | JFI | null | stale (172964065 slots old) | - | switchboard EaoDyo.. stale (172964065 slots old) |
| `E2dfakTqojipaezjb4Skn4czJdwEXvzFLHFbqzjqAEpH` | J-RAY | null | stale (172963381 slots old) | - | switchboard 4wTSg7.. stale (172963381 slots old) |
| `FoZXT4LF774hUgx54J2VD9GJmBMLYD4jeTEbcMWpQ5XN` | RAY | stale (155707389 slots old) | stale (170675585 slots old) | - | pyth AnLf8t.. stale (155707389 slots old); switchboard Do1cyi.. stale (170675585 slots old) |
| `HTnpkd1b1v3i4cpLAobLQgs3Hqz2zo6uxrHPcCVcRqxJ` | J-JFI | null | stale (242715371 slots old) | - | switchboard GAQcje.. stale (242715371 slots old) |
| `J8JXXhz3YtD4adJiU212jMwAxLtuuyxLxiTsc5bSjQZi` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### TURBO LST — `2BCyWyhuHEVha8X4oWHZXrYBofG4K737FT9Suk3SvvuM`

10 reserves: **0 refreshable**, **10 NOT refreshable** (stored value $7,232.28)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2eJoojfUWzEtMSbfzF71ozwaVRPKPM4i7XCBmhACFXHq` | USDT | null | stale (178109098 slots old) | - | switchboard 2KfZ8f.. stale (178109098 slots old) |
| `3Qa7bcxrKuF1FAsNqcoXMEYPnDNzXxCKvRS16oSFfEBC` | INF | null | stale (156815358 slots old) | - | switchboard 6AQHz9.. stale (156815358 slots old) |
| `4m36AgtYxhjqySKaFwZrobZ9yeCpjZZWip2WxmZYt7mQ` | JitoSOL | null | stale (147855734 slots old) | - | switchboard GvWB8u.. stale (147855734 slots old) |
| `6NB4RVguQ7r3GogG1xDyqtUT6DAqYzNvh2QYWrGArsr8` | USDT | null | stale (178109098 slots old) | - | switchboard 2KfZ8f.. stale (178109098 slots old) |
| `9x4j2o9zvthLSEqwkTs1ZY7SByz7RnScPQCdTERhpTtE` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `BkP3MWQJ3QPzqbwJm22PVAJXxKidEnjEgthfiDZr9mCu` | bonkSOL | null | stale (162004228 slots old) | - | switchboard G6VU3k.. stale (162004228 slots old) |
| `DKY7LKLRCxt6WLR19fu9tcrrzzQr8tRjZn45D9XdDNYV` | JupSOL | null | stale (169318567 slots old) | - | switchboard 7Aza5r.. stale (169318567 slots old) |
| `F1uFiNe6vt6YYak2EAwZghvrq5YgZkDzxFDeu84dCiMU` | bSOL | null | stale (147876198 slots old) | - | switchboard 6Poy9L.. stale (147876198 slots old) |
| `HDBD86XYwit1ftDBmEG1Wq8QuVXfpJ9eX31q5XexTjXs` | picoSOL | null | stale (162506661 slots old) | - | switchboard 5zEWAj.. stale (162506661 slots old) |
| `HjtA8evVGGwaxEaR6Jyjv8NP5uAkbJNvgRhK5eF5jiX9` | mSOL | stale (168204087 slots old) | stale (148013870 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard 78zWxe.. stale (148013870 slots old) |

### Star Atlas — `99S4iReDsyxKDViKdXQKWDcB6C3waDmfPWWyb5HAbcZF`

3 reserves: **1 refreshable**, **2 NOT refreshable** (stored value $7,185.62)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `29Znf6g5qmRfTdnbyRQUWvMt94Gzn2KPCzY2ixxY9Mnt` | POLIS | null | stale (138198063 slots old) | - | switchboard E2q9pZ.. stale (138198063 slots old) |
| `8RX5oDxnydPPsA92epWnyXrrM26w7JgAQoVVt9kbiZwq` | ATLAS | null | stale (134148561 slots old) | - | switchboard 8G2KrS.. stale (134148561 slots old) |

Refreshable: `5hVVs474..`(USDC,pyth)

### UXD — `HCuEqcXaGeioiJf5vNMTyQC7HMPqJm5aZPkSjA2qceDS`

10 reserves: **0 refreshable**, **10 NOT refreshable** (stored value $6,922.99)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2dhdZBcvJfXhvZSjsuyr7tpEPBBiCPMzYpKfuBjiSwZU` | mSOL | stale (168204087 slots old) | stale (164164048 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard 81muJB.. stale (164164048 slots old) |
| `3x4swTGLgBkCDmxXYQRP96J1evCgy3ZsnUf9YJzVPtNy` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `8W2FhdvEh419M31DYTktAhowkmVrLUxYFQ5xGY85uMuj` | JitoSOL | null | stale (140336491 slots old) | - | switchboard GvDMxP.. stale (140336491 slots old) |
| `9JXW8WPjNWRLrMSrRs1BUMHGDe5hG7awCM5jb9uwugLD` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `Br6ucRrPNrJXPMa31FGBqS9WH86YGMQvu8Lv4dma8R5k` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `BvZwsK3v8gqHqhNMDnGsD7z2V83bGzw82o2vrqU3kvBC` | UXP | null | stale (170323300 slots old) | - | switchboard EsQkrt.. stale (170323300 slots old) |
| `DG7SEMDmEv1HqaUvMebf7D7xCAk1e6j5UJiTJqVGzBoY` | UXD-USDC | null | stale (304038468 slots old) | - | switchboard EeuaqX.. stale (304038468 slots old) |
| `GGuvnxSwRV56hgNEXHE1GXpszYqiay3hcuoc6FwLG8Bf` | stSOL | stale (168728418 slots old) | stale (140336519 slots old) | - | pyth Bt1hEb.. stale (168728418 slots old); switchboard 9LNYQZ.. stale (140336519 slots old) |
| `GNpVY38QB2RgTEKRkfBK61zjs1aAFGg7SSvkDJ8Y1DbJ` | bSOL | null | stale (140336491 slots old) | - | switchboard GvDMxP.. stale (140336491 slots old) |
| `GseYnT313pSLAVidDwKWzo48QRFMmaoF2QLk3fK8DpZU` | UXD | stale (168205596 slots old) | stale (166459324 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard FcSmds.. stale (166459324 slots old) |

### Hades — `3mWajMqh51CFghqZSKrCKRZpvBwv13HNjNePgy99xRHV`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $6,289.84)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3vJnwDN5rjszRGELZuqThRtGTHpKpLPVjfkioAqqxWWE` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `GgWBN7tq6DK4th5ZZia1yHdFekJWGrstQeXiM9No98qY` | HADES | null | stale (275889391 slots old) | - | switchboard 5BPAg8.. stale (275889391 slots old) |

### Star Atlas — `3Crn1bBn3BifjzMuTwnCfTtaxX8NBdjK4g1GKsnYyXF4`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $4,641.86)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3VmWaXM8RWtwDFYg1WSPyiVXubgAgwin57iitXPmxZXo` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `4t4nASoBVcMExCiHiwyqaE5saeUya3pSEbMdoJt645M2` | POLIS | null | stale (162046797 slots old) | - | switchboard 7UVktC.. stale (162046797 slots old) |
| `8xqBEAVWHZbs6J3HD7YTfCh3y4sKfsFsX6B9KDpxNRby` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `G2UpsxWywyUjtD2q8ZyXr4BUXhJKiMiGVvTbg4nWeKAG` | ATLAS | null | stale (153771923 slots old) | - | switchboard C5M3Sr.. stale (153771923 slots old) |

### Synatra ySOL — `Hx2b7UN5fg2YGui2ZA8zxuiHEvrtEe5sTvwH19qWNYfh`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $3,834.03)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4ZdJcuc1m3dEy9VECQdy59ZZ7gpkvLazBNkSjSgEH5AX` | ySOL | null | stale (11247627 slots old) | - | switchboard 3debac.. stale (11247627 slots old) |

Refreshable: `49WAmdEp..`(SOL,pyth)

### Shadow — `Foo9vqN6fj1NyymHmD1gwZkgVgEqzNSrwyeqyoLYGe7j`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $3,826.92)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `27wbnZxrA8Gq7UMYaRFJPP4ijr6HuWZZNXAovEHrG6Pn` | SHDW | null | stale (177247219 slots old) | - | switchboard BvgzRg.. stale (177247219 slots old) |

Refreshable: `4JvgJDxB..`(USDC,pyth)

### edgeSOL — `2THvza62KhM3P9eSP43nTNRfdCGhdNMaP9kZ77Akv5gs`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $3,458.21)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `B298L98bt7KYfQmaHuJpzqGPqGJzvxfvGBo41fpBHWRw` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `D56iHz98tehLV67WE9F4dXKVomxnu6NWjs9HGGexRDUW` | edgeSOL | null | stale (156815350 slots old) | - | switchboard exHF7k.. stale (156815350 slots old) |
| `EPQCqozXntJKBcqRF7G8wyVaiWWBU3WTqReqtTgLjr4d` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `Hmy4ahWuYQ8iaxXhTGTBNekGdvw1hrP3opsRBQ6shRNR` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### FUMoney — `CX1GCNCgkyPu45tqiiCqjqiaukzzEizMHHvqQNNqyk5g`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $3,409.62)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2gnR1K1odL6KkLXQXxxZPd4WdLV8FR3ocaiomAoaoeJL` | FUM | null | stale (169876737 slots old) | - | switchboard CdznYo.. stale (169876737 slots old) |

### FartStrategy's Fartcoin Lending — `C598EMzva4z2LMz5BBibbGWh1m7LFYDzBNw67A2eWTZb`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $3,338.69)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `84mKTigipafRaHWG9WfCm7Zt3dSqGSVHEYB41XU4aqg5` | SOL | null | stale (10177135 slots old) | - | switchboard 8PAQbJ.. stale (10177135 slots old) |
| `Ap4fYse5QA49Sy71uJQHpdZypioafZNQ3Mvsd2JMzC4c` | Fartcoin  | null | stale (10177135 slots old) | - | switchboard BrFsAH.. stale (10177135 slots old) |

### Aurory — `7Sy8M8cXZFyyyHRDyiLi1WumPcgpnYUviuPm1Dp3XFmb`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $3,228.88)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `H1hpwRQsWXpx18D7uCFgnqj1oAesgLC8H1cDu5oYdrpa` | AURY | null | stale (209783180 slots old) | - | switchboard 2tt1wN.. stale (209783180 slots old) |

Refreshable: `2ZzkFjFj..`(USDC,pyth)

### Cropper — `MAf6kDoQ4Gfj9m7zHhABPifFiXQhFHGaDLGaNXMZkQ4`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $2,885.76)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4Uzuzwuh1CAV4y6cg9BeQc6U3GU8dHPSJN6dfjmBwuu8` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `7xW8MBuRgys1bxaS6sLzUdAQhrrfw6QpLmT1ikmEUF1B` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `CiS2rat4VVCwe8QEVaXm1T5LqbKx6var4mazBrxwg7iE` | CRP | null | stale (220507877 slots old) | - | switchboard AhmY4z.. stale (220507877 slots old) |

### Clone — `7dA8PMT6bhopvRkDmJAeQT74NyDkGvi4isYoiYd8pES`

8 reserves: **2 refreshable**, **6 NOT refreshable** (stored value $2,604.64)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `PyXB5DzV4PtmnhWq3cxQtn8xFAnFfgNnKxbLXWbuhPj` | clDOGE | stale (925613s old) | null | - | pyth Jvg1x1.. stale (925613s old) |
| `6dGZmkvG7q3Bjb3m8jBik8hKifcGFW52w1Q2b5BWcEwt` | clARB | stale (4992113s old) | null | - | pyth Fm8a8n.. stale (4992113s old) |
| `7HZGMJGDQrTDTyKaHRCMcHszpTcHT2eEfyHJvDJJN7zk` | clOP | stale (65122615s old) | null | - | pyth AZTG45.. stale (65122615s old) |
| `9a18jAGWfTjeng5csbDQHFx2nivBeUNQmF2dS361Yf1L` | clSUI | stale (925609s old) | null | - | pyth 6GujNy.. stale (925609s old) |
| `Dkw568vRzHji4Bzi56WReq9QBNE7tbDQuUha7PtSQn8p` | clBNB | stale (925613s old) | null | - | pyth 4BfpDD.. stale (925613s old) |
| `EqRSVXDfrM5cH9gR5dB4M9ZDrbBLEsEYZyu9psk9FQdA` | clAPT | stale (65122615s old) | null | - | pyth F3nJLL.. stale (65122615s old) |

Refreshable: `Aw6yESTf..`(USDC,pyth), `FNDYHVzP..`(SOL,pyth)

### Dog — `HASr6hiYVoRcVXk3GttC4PjBBPQ3sGYDzE7HSPJdcke6`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $2,515.68)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5VuBkDYXcV1svRm1BKShA2wqKsszYWjPwoT4Q32YXcp3` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `HwZSKqyo2QQ2YCzF282ZrpH4JRQWf3Qad1fWHtKCDZjx` | SAMO | null | stale (170969541 slots old) | - | switchboard A19E1f.. stale (170969541 slots old) |

### Spot Margin — `HPQPAnzLpFJVSvn1nsMK58xKikoELvdzjpfy8pJwyX87`

6 reserves: **6 refreshable**, **0 NOT refreshable** (stored value $2,367.88)

Refreshable: `14Pv4mbk..`(MEW,pyth), `q6hxqvpU..`(WIF,pyth), `6LRNkS4A..`(USDC,pyth), `EDM5iSbg..`(JUP,pyth), `GfSTLyTs..`(BONK,pyth), `Hh3QFZem..`(JTO,pyth)

### Nitro soBTC — `5stEcEZRtYth8AGa4dHJ1iNt5bu1dqRvV86QCQEihTuY`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $2,280.72)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BxNt9SspAyuTfR4ZQPrRfWyqJiLp5sHbq2Kn27hwD68i` | BTC | stale (168204085 slots old) | stale (140336491 slots old) | - | pyth GVXRSB.. stale (168204085 slots old); switchboard 8SXvCh.. stale (140336491 slots old) |

### STEPN — `BjsAGLZzAgBUsiaTTDQv7PWDUDL9dQfKvYwb4q6FoDuD`

3 reserves: **1 refreshable**, **2 NOT refreshable** (stored value $2,193.54)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BqYvhari2P9mXYLqcgJv41kRUvLhBfGoQXGWHnw26UJw` | GMT | null | stale (17012345 slots old) | - | switchboard 9bED8Z.. stale (17012345 slots old) |
| `CaacWq72hHubpwi92UUVsoE4xDNKqr1MhRwYeqH3YPAU` | GST | null | stale (17012345 slots old) | - | switchboard ZZYHqS.. stale (17012345 slots old) |

Refreshable: `DxdbG2Yw..`(USDC,pyth)

### ISC Stable — `24FVbp6yRxP7qNNiVXHjAjwUabdvVfbJtDb3aJ5zCWwy`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $1,905.62)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `GdjAFNML83jdrGotSUiBi6oDSDFvV83hCM6865LmPF9d` | ISC | null | stale (10234079 slots old) | - | switchboard B32Wk5.. stale (10234079 slots old) |

Refreshable: `56v2DrnH..`(USDC,pyth), `AQTzHsJ5..`(USDT,pyth)

### Invictus — `5i8SzwX2LjpGUxLZRJ8EiYohpuKgW2FYDFhVjhGj66P1`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $1,888.61)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7MymBKwTPPMC4A9Ktwc1F2V5Xw7Kj3DqvRYUvLk2SF4h` | UST | stale (155707389 slots old) | missing | - | pyth H8Dvrf.. stale (155707389 slots old); switchboard 8o8gN6.. missing |

Refreshable: `4XYbgZJi..`(lsIN,pyth), `AuT5vA4b..`(USDC,pyth)

### Basis — `93fqxupYFmvXWWB9ptSp5pyAV9b7kgUpooqc5hWtaXYz`

3 reserves: **1 refreshable**, **2 NOT refreshable** (stored value $1,573.68)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2MtLN8tZdwsN9iuXW2sJyJGtvh2G6frFFdf6MWYKPBYk` | BASIS | null | stale (220911968 slots old) | - | switchboard 7LU1Gc.. stale (220911968 slots old) |
| `7ij8ELbdvbgmJo6ibFVvME9cUJe3JTBc1SaUH4QHrSvE` | rBASIS | null | stale (252374065 slots old) | - | switchboard 974zYb.. stale (252374065 slots old) |

Refreshable: `3WvnsQF3..`(USDC,pyth)

### Turbo mSOL/SOL — `7x3hNWGPNjSZMH54rGWpx74hdVgZZJY2u3XqdL42G4b6`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $1,471.15)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3csx7zsNWT139JgnvQzL3y3UNqjzdZjQRcfBZJo7X6FP` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `4S5TTM7Eig5y8zZPCxiw3GEu8zeDDuHNrUrEE6hHz1rc` | mSOL | stale (168204087 slots old) | stale (146084057 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard HWAVEp.. stale (146084057 slots old) |

### Jupiter ZEROBOIS — `4sbdHZE1hMiNXEmmcmzdgd5J6RqNJcm969BuuxVhtBtN`

8 reserves: **0 refreshable**, **8 NOT refreshable** (stored value $1,267.72)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2opTezhSxmym7uD9k2KocEvr43EuneHn4fAMpkSKANsS` | JUP | stale (168728423 slots old) | stale (199182879 slots old) | - | pyth g6eRCb.. stale (168728423 slots old); switchboard 6WKPYC.. stale (199182879 slots old) |
| `4SJynJvt7kW1saps3BV73Tc1qhxqCN3twseLUxtPJPaE` | WEN | null | stale (156841490 slots old) | - | switchboard Bfz5q3.. stale (156841490 slots old) |
| `6Gzm5ghYcAVNvPiMzaSSA6vCwiEBgMhtgesJ5EmEGg1Q` | mockMEME | null | stale (208348599 slots old) | - | switchboard BWnkvR.. stale (208348599 slots old) |
| `7Y7GNcBQvgTHre3vTggG3ddpoZxz7PEgZaXPEeSMyg3p` | mockUSDC | null | stale (208353652 slots old) | - | switchboard B3dwdQ.. stale (208353652 slots old) |
| `7aqFcZ287eUBguacWBvgxdPesXPKwyGEyPAXYzTJvwxa` | mockW | null | stale (208364069 slots old) | - | switchboard BH47iV.. stale (208364069 slots old) |
| `7awLkmQp1uEia8K5ptjpVks9sV2usEuLwjVA5vFuhLsL` | JRK | null | stale (208350846 slots old) | - | switchboard 6DP1pW.. stale (208350846 slots old) |
| `8AQrAuAhGSZ6C5tgPkGvri4uNAeg8Fd4FDuvvJoeAMt9` | mockJUP | null | stale (208343284 slots old) | - | switchboard 6nKbZf.. stale (208343284 slots old) |
| `C4hP1tabjDQN3tpwhC6Ze1HY4UB3J3xzNM2SDr88d6WM` | JLP | null | stale (156815346 slots old) | - | switchboard Fph6dv.. stale (156815346 slots old) |

### zippySOL — `B6jWiB73F6X6x8fp1pw1PGLQphN15r4ZZWPNggA1M9bS`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $1,137.77)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2kvPGtKrhm6HLC9XvRXBNPtxfMKLZsKZ3K23UyjmXEKx` | JUP | null | stale (179657846 slots old) | - | switchboard ARXKK2.. stale (179657846 slots old) |
| `9pTsPiSAajvVftTJYExoA7hJUiBzTRihnx5wCuFDBuzg` | SOL | stale (155707389 slots old) | null | - | pyth H6ARHf.. stale (155707389 slots old) |
| `Ac7xDdF5LCWSb7ZSQYg8YhRowU6r6pcpZvGHXgbDfZVz` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `HAJiVypogUBExPjsq3WYXoQmMWNmh58BFnnuiEGnEsPj` | zippySOL | null | stale (173821487 slots old) | - | switchboard CGsmoU.. stale (173821487 slots old) |

### Lending — `C3VQi4sKNXVsG36zhUnvNasXPhzGmWWVpaeSPv5Tf2AB`

8 reserves: **1 refreshable**, **7 NOT refreshable** (stored value $994.30)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3CVBpNtXxvq41G4PR5YERXub7aBBusB9yd8NPk1W49Zk` | PORT | null | stale (140336844 slots old) | - | switchboard BnT795.. stale (140336844 slots old) |
| `42RuM1MaCoRAnYz2oonS7qiBvgBb9MBkJSp2Hu4ZHMHm` | LARIX | null | stale (210577187 slots old) | - | switchboard 4puRw7.. stale (210577187 slots old) |
| `7vm1J3CFRahCRP6jrEffocWS27XFJLC6hXRcZEBj9g1x` | SLND | stale (43450528s old) | stale (179657710 slots old) | - | pyth 6vPfd6.. stale (43450528s old); switchboard ExaSzw.. stale (179657710 slots old) |
| `86LCGMKTjDLhZsGcZjFAG8NeLwYF2xtWX2mMi75NKng1` | TULIP | null | stale (220845870 slots old) | - | switchboard 3JA2Mo.. stale (220845870 slots old) |
| `EXw94GGEMGj2YLfGY3wTixVXkDWoTF9vytB3Ly26yCTN` | MNGO | null | stale (220797005 slots old) | - | switchboard AmQunu.. stale (220797005 slots old) |
| `Eb1zsacwpPdyJNz6VN6VKL387nMSHQ3QY9nhGChrHxNB` | APT | null | stale (252890231 slots old) | - | switchboard C1zLTQ.. stale (252890231 slots old) |
| `EbkWi1t68PtDe4MLHcnzo28RBdY8GNMLkUoYLt9gNzaz` | JET | null | stale (221267327 slots old) | - | switchboard 4VUFxa.. stale (221267327 slots old) |

Refreshable: `HD9guSF4..`(USDC,pyth)

### Helium — `84xdQ3ayRePh2Me6TFs39aHSsttHn9BmG9uXwzHZDjcX`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $928.22)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BtpPWdHRrB6DVktAhRceGdAvwaoi9dx7vrpJbxmDPsYu` | HNT | stale (168204087 slots old) | null | - | pyth 7moA1i.. stale (168204087 slots old) |
| `G8Az57xuJAwHWjo7PqEFytuMrk89cEWZfnPwxiPF11k2` | USDC | stale (168205596 slots old) | null | - | pyth Gnt27x.. stale (168205596 slots old) |

### Bonfida — `91taAt3bocVZwcChVgZTTaQYt2WpBVE3M9PkWekFQx4J`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $881.15)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `A3ZhKMuwHygRqjXiMDqM2PyeT35Z1LiDUqwrtjiHn89M` | FIDA | stale (34259688s old) | stale (221345902 slots old) | - | pyth 2cfmeu.. stale (34259688s old); switchboard B6YEdQ.. stale (221345902 slots old) |

Refreshable: `3WPYWiZt..`(SOL,pyth), `EBRtjgHJ..`(USDC,pyth)

### AMM — `Au3S1ZSkGwm1fo7g3WFhkD1rcPoUXj7h5ubsGsUFqbLX`

7 reserves: **2 refreshable**, **5 NOT refreshable** (stored value $782.14)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2ToiSp1DBwwmsjFkSgvpf25gKAYV2Cn4ij2U4YVMuYzZ` | RAY | stale (1265510s old) | stale (140336519 slots old) | - | pyth Hhipna.. stale (1265510s old); switchboard 2oALNZ.. stale (140336519 slots old) |
| `2iTv6eAq1BUyUQA8jYu5iE39eepBcsPoSj43F1ZkXMoM` | LFNTY | null | stale (207902695 slots old) | - | switchboard APaudj.. stale (207902695 slots old) |
| `2xydNZJz9XE2ccEfD9eT2TGndFpe5sUdrr5VXmuuRgXQ` | ORCA | null | stale (175916528 slots old) | - | switchboard 7ySvXU.. stale (175916528 slots old) |
| `3LE48upFRQZ7YtpG7Cn5BHCQkV5T9CdrsZNxzfGMMvJE` | SRM | missing | stale (140336491 slots old) | - | pyth 3NBReD.. missing; switchboard CUgoqw.. stale (140336491 slots old) |
| `4UvekRzs3Qn8sXfi9MhdzsjGAY8F1hBnMmB7SRmN6ZE4` | STEP | null | stale (216585338 slots old) | - | switchboard 24mXtP.. stale (216585338 slots old) |

Refreshable: `6nb1odSY..`(RIN,pyth), `HmH5kEnw..`(USDC,pyth)

### WEN — `3zV7v68Bdz4a9pZt3RYqJryov1EtUegwSkMj28FPffDj`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $738.56)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7CyRxtUb4HqMw8JoarpMgk7SQa8hvc58bZzkmkiDbCpg` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `8M77Xp9HjWfTiKy4pCtkmvdCBfCqrykCK4M4vv89iMR2` | WEN | stale (4287000s old) | null | - | pyth CsG7wX.. stale (4287000s old) |
| `D2LQmtgtLaWPQSaLbZ1zsz3rpfGEhktXuue4X4QV8cJd` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### NFT Lend/Borrow — `225akup6NNHS33XYZL8pudLTi5yjfkZ3jZ7Dggm58Cjm`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $735.51)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `8Nqoi5HzD1wjW94CPe7hDgacSzQDBqJF8ZPyGNoJbkTF` | USDC | null | stale (140336579 slots old) | - | switchboard BjUgj6.. stale (140336579 slots old) |
| `CvZDVH66xB5PH7Mw8xKnoSy4Jqzww75XH4z64cR5Nv6f` | SOL | null | stale (140336491 slots old) | - | switchboard GvDMxP.. stale (140336491 slots old) |
| `Hs4ofND5HuqYjz9RcupW2Zk9ELRmCMgnjNtDwCpZjosb` | OVOL | null | stale (180880566 slots old) | - | switchboard Bu59m5.. stale (180880566 slots old) |

### mSOL-SOL — `JA4X5eGXYPHDbKGsarBhPPBX6btdaeevQSU2ydCECSKK`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $711.47)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `91UPLYhPkw95qY9PKf2DAN5bJyTSr5vE1z5hPMLLxgA9` | mSOL | stale (168204087 slots old) | stale (164164048 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard 81muJB.. stale (164164048 slots old) |
| `F5ur9UxyVG9pDJoeBhkupkSYdLNEYcofeBGGuMkZnWUV` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### JLP — `Auz2XgwiuCZfCjPzMrbUNXqurda8PNoC3pv1PJGoDRE`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $554.46)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `pNoTyMUKbWprG2JSEdM4ncEhCdqUTBYVknh44Zz6YC7` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `3BJiKchbxrhW9qFn6YQUx1MgDm7ff2iQMfJCYheEdW8t` | JLP | null | stale (179657722 slots old) | - | switchboard EzBoEH.. stale (179657722 slots old) |

### blue — `FZv8oqxpDVsxSTJrp79qA3UNQmQYjMfPUJ8N55PEdhuz`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $528.53)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `AVsymEnwaCFbnvgD1en4DYjvcvTk9Zv8ZQeLRd4JXUC4` | coffeeSOL | null | stale (128374854 slots old) | - | switchboard 924NX6.. stale (128374854 slots old) |

Refreshable: `wvVPXSYW..`(USDC,pyth)

### 🟦Lionz and Gazellez — `CGvj1BFgynvE42raw8AaNmWz1biumKaqUdHsQ19SYwWj`

3 reserves: **3 refreshable**, **0 NOT refreshable** (stored value $484.83)

Refreshable: `5wQyM4Vi..`(SOL,pyth), `BUMaLnJx..`(JitoSOL,pyth), `GbiJTmxb..`(ETH,pyth)

### Solana Solend Raydium Orca & Stablecoins USDC USDT — `EX4mFJiWbzSoX2aT4YAjXHdcgB4LLh5LR8e8v52JbjiX`

6 reserves: **0 refreshable**, **6 NOT refreshable** (stored value $415.27)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `JSLBbDvFxwdJxXWoPxY1FrYsp2k68Uk6zmaZj2ydNqM` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `T2C2kQ1n7vKH2xtzdNcJ2tvNLJrExDTazhSzFkyRp8C` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `51dz2oriyh5NANnWhXPaLEuNdKgUGgSKGdNBZ2H68vA9` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `7jGkZTSgND4paoTKdyPsV7xJtqPcG4Arhy5nYZve8E72` | RAY | stale (155707389 slots old) | stale (170675585 slots old) | - | pyth AnLf8t.. stale (155707389 slots old); switchboard Do1cyi.. stale (170675585 slots old) |
| `8g4v8Rcgz8ifiFG2WRLbDReu9hjUTEVgyDfvnuRb6K3n` | ORCA | null | stale (175916528 slots old) | - | switchboard 7ySvXU.. stale (175916528 slots old) |
| `9rUfA98qJDRoH669mGvvUR7aaWJqN5DA4cyD9HNBKP33` | SLND | stale (168728418 slots old) | stale (310302061 slots old) | - | pyth HkGEau.. stale (168728418 slots old); switchboard 3btrKt.. stale (310302061 slots old) |

### soBTC Ramp — `ATbXhciS6uoHKeXg6BdxEfYA9HtjRzzzW4Pd5ggJcNGt`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $404.32)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `zF4GkpGGcNUKAzYDnyA3M3K4isY2sd4Uq1Ypm6i1hot` | BTC | stale (168204085 slots old) | stale (140336491 slots old) | - | pyth GVXRSB.. stale (168204085 slots old); switchboard 8SXvCh.. stale (140336491 slots old) |
| `4svhbg4cKNd2i8xsXuD7CoEmzdzPPwwKGFHsfS5p7PMB` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Nazare Stablecoin — `3HGyDbSY5JJRcx1ZXJ2xqxqXJHcKEjBhLmks8th36fQ9`

7 reserves: **2 refreshable**, **5 NOT refreshable** (stored value $398.99)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `B7mhAMjbu87TG8CbFCwgEcV8Kcfw8H6rEZcoyB32evFA` | nUSH/USDC | null | stale (256604157 slots old) | - | switchboard E84zPU.. stale (256604157 slots old) |
| `F8vkeEm3uoZJoystwW3bQDWKcmmMxdvasEFYHATFb7WZ` | USH | null | stale (193326286 slots old) | - | switchboard AKp55L.. stale (193326286 slots old) |
| `FbvxxBovZDyLuTgcuAoYoVY55evgKq3wRRPagyteUhiS` | nUSDC/USDT | null | stale (226922513 slots old) | - | switchboard 7or1bh.. stale (226922513 slots old) |
| `GFBRLDrscdQt6Kx5sjEmKrSnzBvQvecWDhsWKVekN5G1` | UXD | null | stale (179657574 slots old) | - | switchboard 8hhBZD.. stale (179657574 slots old) |
| `GojC8BTCCWH6DhJqHP4WBUjNYLXuz47hZNzprL4NqCh5` | nUXD/USDC | null | stale (256632658 slots old) | - | switchboard 9aNNzf.. stale (256632658 slots old) |

Refreshable: `ACXQ2Jk9..`(USDC,pyth), `CtVcJLg9..`(USDT,pyth)

### Bing-Bong — `Gpx8drm3ufChjWnoYFbTovqVQExcrwo9BtUux3Ti85q1`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $301.98)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `CWhxaQqEiW57pYV15j9eXw4epKQvH42SRSybP3hYQtKi` | BONK | stale (155707392 slots old) | stale (140337695 slots old) | - | pyth 8ihFLu.. stale (155707392 slots old); switchboard 6qBqGA.. stale (140337695 slots old) |
| `DHrRVvDHX5yAxETZoEffALSnTQoJ4dqNPc7HQpcBL2Dg` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Solcasinos — `27NJL2yDGEVCTGDtrNi27CosmAknPgq4zBAVzxv5tNSs`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $248.05)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4UJuhnyEMVf5j471nxM7NJTkRDjKpF3GhiKGwzhUoJxZ` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `7fUxx47vbivGHnNkQwHRGsJxoinsUmhQcdK5GW8sAXCd` | JitoSOL | null | stale (179657595 slots old) | - | switchboard 8n3QYC.. stale (179657595 slots old) |
| `DdeYFbJbtyrGtt62age5Hz6ny9D5vwE9JuknAoQNEvKi` | SCS | null | stale (179657788 slots old) | - | switchboard 7NcifX.. stale (179657788 slots old) |

### TURBO JLP — `Gr6uHdNuWdqCZpEJiL2N1XCyCZG2Z3QAyHv2XNijEaxN`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $222.57)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2NHH8GxpCoGhhhBp6pcacwvyiQDsaSmL3NLAFzbhKHfh` | JLP | null | stale (179657722 slots old) | - | switchboard EzBoEH.. stale (179657722 slots old) |
| `AbepQJSwNAqc5wwZk1tGvxPfEhdkGoif2hPb6Zjyqp33` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Memecoin — `4HnDK5hwy88bWjnZTojUJ7RRB6zU5xVKZxbn1hHvurSN`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $213.97)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3T6RJKeDTvoP4EeTMFY5WFNxB6d6GdmcHCqDSmK4tmnr` | BONK | null | stale (218562236 slots old) | - | switchboard 4SZ1qb.. stale (218562236 slots old) |
| `7kahhufbgSpHT5BRX2Wy2TgzW2k8hhEhcb2f6CkR6G9R` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `8EsnWfpxJjHWpnK8V7C9zKjr3wQJZ9eTAKZxENJbUVhK` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `Grb5sA5bQSgjJxb7UnGNQPKswcTF9SD6GwKiYvws276G` | SAMO | null | stale (170969541 slots old) | - | switchboard A19E1f.. stale (170969541 slots old) |

### Collaterize POOL — `4HM4uNgoyKsoZx4QDmJcihWngeQ6EtSAwZbquRpA1kKL`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $206.57)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `Efh8Yyg8wAuRocn7ynCR7qkt1wTBTVrn6oDx8qxiMu31` | $COLLAT | null | stale (111008589 slots old) | - | switchboard 6WufZd.. stale (111008589 slots old) |

Refreshable: `13QLZWYq..`(USDC,pyth), `5ZNzkUDm..`(SOL,pyth)

### DePool — `5BoNV2bbsZFcA13se73EuF8tBfkCFbsMnW5q18TD4Mzn`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $202.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `R1MGtytnkZqHVJFKwG6HzhUuDbhgLorojGRcdyrGoEL` | DUST | null | stale (206435560 slots old) | - | switchboard C5tuUP.. stale (206435560 slots old) |
| `H2d9j9CHZRXUQE2cHpkvnfgg7vMw8ysyALX5dTeT6CQk` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Blocksmith Labs FORGE/USDC — `9qHFpV9qurVJbhommBmKxcr3KPvMVgzo1KHHVQF7XH6c`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $188.22)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `AtXL3Q4FyESEDbtNwhMM9zNDhbewV7p4jhnez2pYXan7` | FORGE | null | stale (303915630 slots old) | - | switchboard 9R4pFH.. stale (303915630 slots old) |
| `CHxrRzmExDyDBpkvgEtCeAdKegDkyExyRiHSg4wFe2D6` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### yellow — `4YUN4N5x3wd25GLBFXKLuyVFukhaJ1KmkRn6TyDLNhvH`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $172.14)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `ANqYR8Wwp9Mj3Vp2gzntzJQxAzg3Etd9pNAKkwLEG6jf` | ClearSOL | stale (168204087 slots old) | null | - | pyth E4v1BB.. stale (168204087 slots old) |

Refreshable: `9GRSPeKF..`(USDC,pyth), `BC95TYoC..`(SOL,pyth)

### SolDust — `934YC75EW32bWdN2gxq7Qsi6LH9VYBxDrLy2hjcSrNtE`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $146.29)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `96cejWqBSf2VojrEqJV7yyHSh7frvYcsJBjF1eLR3Hvu` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `BRnJFznuWEuqMZTHGKyWjYijugcj8wtb3oiLMyu2Tj4R` | USDH | null | stale (179657716 slots old) | - | switchboard 7JeJws.. stale (179657716 slots old) |
| `CzFTn9cnfNQP5u2NLe5HqGrhedLZ7LHFthEb3YPc4xaL` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `Hp3eVasH9m9DjsBgpHV8LfBvmSWGNDg3gQg6iQ5S5CpM` | DUST | null | stale (282601231 slots old) | - | switchboard 3Z6ifu.. stale (282601231 slots old) |

### xLPFi Governance — `CdgPPHLv3wKqZEBYF5jFepq63k526bP5HHU1Z9ZEmiLu`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $129.09)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `9zqNE1dwtR6ddmKLrsi2wWJWnJeHeFcjRg6KTxB9eFaA` | LPFi | null | stale (265412681 slots old) | - | switchboard CZS9Uk.. stale (265412681 slots old) |
| `H16KXyrhDXM8N5RAskiwDNxpFrMqjQyPibBLV6UvnHYS` | xLPFi | null | stale (265412681 slots old) | - | switchboard CZS9Uk.. stale (265412681 slots old) |

### HADES — `C4aUmdq1g97pZEDfbTGKTzY42Qyj2apzEJg8gB9YJh4w`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $106.95)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2ZfZLRuB1nibFdBzY9ecZPaJxhLbUE3miHjZkNWL4YJ3` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `AMBEb1KcBrCX5jyXGKaxzVinhe87e3uKAiTz1hydU6ho` | HADES | null | stale (206281185 slots old) | - | switchboard 9RvUJN.. stale (206281185 slots old) |
| `BnDARrhbjgmNKvrkF985jQAhuABv1mNhq9yeR9vUyhT4` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### xSOL Governance — `9k5GQxz1HWEsKkyMBHynQzAFUf6ZCSByebL4G1jBGptA`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $86.08)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `66JmFDE5Cq739oWui9yvxcY2zXk6YLXyycRQH59FyVJR` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `BAvkxTLavdYgUYiCfqis2GJP6dkiUkuVdfNFvFsDjGfL` | MNDE | null | stale (156815372 slots old) | - | switchboard 96iMV5.. stale (156815372 slots old) |
| `G7rDSEY8RrW7PoRvbvuiWBbpH1PEDAsKLPWrbcu5GBfT` | LDO | null | stale (172559412 slots old) | - | switchboard 5o7Rxp.. stale (172559412 slots old) |

### Turbo JLP containing BTC, ETH, SOL — `4ESBZjtCU7NusjJpc5EaNufSZytV23UexuGAWZLa7Sgd`

6 reserves: **0 refreshable**, **6 NOT refreshable** (stored value $71.91)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7uCp1cWFxvHWFBMGHA4YX8NVdBpdaMyLARZzTsmafgM4` | JLP | null | stale (157752166 slots old) | - | switchboard HR1mmj.. stale (157752166 slots old) |
| `9WoL842LRMDwrJh7LEYU8DsoWQfLGYUnZngGmT3EkZAB` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `9kdPCjdGkjWTYjA8KVofsdzn3n9WrgE7ifdqSQu3QvNz` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `Cor9AVaFJUpfdTKk95tSaGPPuh17JzHkEpQiPgwR93JG` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `G7Xd43RtBAWzzB1YAzFqtAUh62x5qXBfMrCR3RX5hoJ5` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `HEM7L9E1ZrduGYe4dWeRRq34C9M8s4QQPWrpeTrppWo2` | ETH | stale (168204094 slots old) | stale (140336519 slots old) | - | pyth JBu1AL.. stale (168204094 slots old); switchboard HNStfh.. stale (140336519 slots old) |

### SMAN (Sol Man) — `67SaV8bLxQpasYSgw66ojvMEyRkLPXAEzHWbffRSVqzk`

3 reserves: **1 refreshable**, **2 NOT refreshable** (stored value $54.34)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `83coGKkwe8hwgyXvbRcjQCqT6BAfL1JfrkHFJYLJKkMS` | JLP | null | stale (44740109 slots old) | - | switchboard CNBzim.. stale (44740109 slots old) |
| `C6tYsTxdZY3XpUvH3k6uwpgNqXDzhrgefGqS7a1RFCrd` | Sman | null | stale (126400396 slots old) | - | switchboard CxMq1H.. stale (126400396 slots old) |

Refreshable: `D22ku6ym..`(USDC,pyth)

### SRLY — `2JcZW744Tr1dEApCgyNXvCYTESB4euFqoQe6TfPQNrJC`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $52.38)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2eWJ8yRiwDjtL6ypLbd7KNG6mv2b483NaZgfvAq3rBRs` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `BdzWJdY3nWbeQ7Usmb3rcXhPaiXmdcFvostK6PRrFno1` | sRLY | null | stale (277438361 slots old) | - | switchboard HyqfPF.. stale (277438361 slots old) |

### Staked SOL — `2BkaPHTw69wQ9FuzagD8mUc7mtXb31HVXBUedNEbVMxw`

5 reserves: **0 refreshable**, **5 NOT refreshable** (stored value $45.60)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `8L8f5xBttJz4x5ViYWtyY5KxYURx1HaMJbB8uouNjeuZ` | JitoSOL | null | stale (160292936 slots old) | - | switchboard D4HWDb.. stale (160292936 slots old) |
| `Ci5UY9iEp8F4zL8nAD25xSy9v2szpM3SzHQjk8ANNFsB` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `E6xPJa8n98PQMkjCfBW6uxg88FiUHAptLzjTCkrTjKtt` | bSOL | null | stale (179657512 slots old) | - | switchboard 6JMxpW.. stale (179657512 slots old) |
| `EH5gHAuZg3KTyzSJs3igoc9HAL4Mf3MbofSRRrijeUiP` | mSOL | stale (168204087 slots old) | stale (157925376 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard 9EY7Wy.. stale (157925376 slots old) |
| `Gwuh6Cm2NdkvrCfH6bm99b73vuncD19KdUDXSYnzeq51` | USDT | null | stale (198336899 slots old) | - | switchboard 4bndUJ.. stale (198336899 slots old) |

### LOAFCAT — `mVU1ukU8Rj5u5P4KnKavqtzmgQtrnjbjXtrCtrmVDLK`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $38.98)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7ktUPKfd1dxBTotUj6E5Ea92MAaWzCuGNxTL7cYM5rzi` | LOAFCAT | null | stale (154321154 slots old) | - | switchboard 3THUHo.. stale (154321154 slots old) |

Refreshable: `AFPj7eUY..`(SOL,pyth), `Byi5XjSx..`(USDC,pyth)

### Wrapped Algo — `FyTqD3fAsEnZ1k1rK88RyzWJy43xDRfDckPRyRqZB5iW`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $24.51)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `AQQrafZbqHh3eC6FQxrxwufbos7Ajh1D2YtjFhEAj4VE` | xALGO | null | stale (221253769 slots old) | - | switchboard GHGKB6.. stale (221253769 slots old) |
| `AnWFTpwYiTW6HcpyDbGe8APSD9UZcmKkLKKi6oHZ4okz` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### stacSOL.app — `DqkaYui7ueWwcxs76GQMGtDU9GYsx85jZA6hxv75F6aG`

4 reserves: **3 refreshable**, **1 NOT refreshable** (stored value $21.17)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `9EN6P6dG5xXZTXFEDQSnR1HWp6VwKpwKuTRuwX1fPxki` | wstacSOL | null | stale (35573217 slots old) | - | switchboard BDCJWt.. stale (35573217 slots old) |

Refreshable: `4JCXE5Xz..`(USDC,pyth), `57yDcje5..`(USDC,pyth), `98XcoiM9..`(SOL,pyth)

### Cope — `9QxPT2xEHn56kREPF83uAhrMXo1UtPL1hS2FfXS9sdpo`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $14.85)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `F9bLuLiemmokX42gd9HdtRpeMVA7eUh21VLycd66wCW` | COPE | null | stale (280205590 slots old) | - | switchboard Arp8JG.. stale (280205590 slots old) |
| `FjgNkV5dtTsN4hXYoWgLqNDYyEThCpx9MapnFvQwBTuY` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### USDY — `B2hNFZsMRgh54jpZdkUn23vQGtFpB1DoVw7oaNa8PMWH`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $14.64)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `6Fr9QAG89XEnyM7dQrSp4GqQkmB7fMSQqdjMtVqKrFMJ` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `DGYGBx58WQfnh3dcpF53Hpo2tmsSMtRTcW6vq8KDCs65` | USDY | stale (454765873 slots old) | stale (149599193 slots old) | - | pyth GKMnwK.. stale (454765873 slots old); switchboard 234oAE.. stale (149599193 slots old) |
| `FM6nsuyh6VKj6Dj44xo9xtTXijBJNLKXpLuNWugo96sP` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `HSPTWWDYxpKfxUruzSn7DNp6fjWTBVxRQBujcCTiqjCd` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Kin — `DFUWem82zWTm5waK9oRVpdBwU3UnaqFWR8e3LUVZTVYF`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $14.26)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5oBnTqxcWmQQ3UMU6yy9MQaMxPdSC8mja1Dw1suSS4ig` | KIN | null | stale (295262973 slots old) | - | switchboard GfNriv.. stale (295262973 slots old) |
| `6nHs2qdo1FVXDi7gDzCkqNrhBGesuGXLx7WTMoy62axz` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Zeus Stable Yield — `4ST5CorFaDmJ96XtN2TtxkNv3KnWkRTEMZJgA3Sm2LR6`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $10.27)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2uPyZQWjBpBCGV7MkgHNJdxqBUwR5eWbAYd949BLLBXX` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `CyJ5YuEcG2Tskd4EPTdsFQQAwaFTSTd2mwAVkJLGU9tu` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `GaYXkj83NMCYzgThoVDDnumQHuex4yGqd4Qkphk8UENc` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `HdAMvykxFmep97hYAF1UrtS2sh155iXPUXjc6fYcWtsY` | ZEUS | null | stale (171845280 slots old) | - | switchboard B9PHbX.. stale (171845280 slots old) |

### Tensor Stable Leverage — `9ntBtQfvJamdJjrivy1sBUe5gzLZ6QxXCdRXUjaUHgZA`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $10.23)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `38bRa9igLgxkcnM6S2b3B8zLzJFEvb5ZHRJyjMSXeWqZ` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `6CrhK6HJ4dKCwU4Uma6bzgVjCRYyxjStfWcvbihso9Cg` | TNSR | stale (171991571 slots old) | stale (176050862 slots old) | - | pyth Q8VX3m.. stale (171991571 slots old); switchboard 7Cfyym.. stale (176050862 slots old) |
| `7we6qnnfKqeJtR5gzeBPRQBY4ufhj1JLmdYXgF6EQwRh` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Limited USDC Debt — `14KjwAAkbgNdSmCHgNkW6bDhUDF4zbpdS5zPPkxYPmK6`

2 reserves: **2 refreshable**, **0 NOT refreshable** (stored value $9.78)

Refreshable: `27aa3o8g..`(USDC,pyth), `BTQJkUKA..`(JLP,pyth)

### <3 $MPLX — `3nPBKE56fHhLVfNf8HZSTQubkqbm8ohQoZF2p6fPfqb9`

17 reserves: **0 refreshable**, **17 NOT refreshable** (stored value $8.27)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `QXF68eaE8FTDusKE3rGHuktSk4VriZSXofdbZwpSpkC` | None | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `2uYsstyKBppj3z335ASVY8aU1kSoVZtaEeQ8xY1zkRQf` | None | stale (168728418 slots old) | stale (156882246 slots old) | - | pyth AFrYBh.. stale (168728418 slots old); switchboard EPw1Vb.. stale (156882246 slots old) |
| `37b1PVcbZa9mYmSN43Quav6EHwuZR9yYide7mwMbUnz8` | FREN | null | stale (235148500 slots old) | - | switchboard A2E8Vu.. stale (235148500 slots old) |
| `4CyxDoUoWs65Uk1rAh3mrJ2sYwwB6nNKoyBKg1zu9Uns` | FREN | null | stale (235115552 slots old) | - | switchboard 84h6Ln.. stale (235115552 slots old) |
| `7xRjpsMN1Rgh8ScB76mqg4rxRW3RbYBtfRAVCLh5Fj52` | JitoSOL | stale (168728418 slots old) | stale (179657595 slots old) | - | pyth 7yyaeu.. stale (168728418 slots old); switchboard 8n3QYC.. stale (179657595 slots old) |
| `B99kzZajCZJhjLfJL3rmhxrrnBubQRAiGUjmwa8P6TW1` | USDr | null | stale (275971622 slots old) | - | switchboard H96wZv.. stale (275971622 slots old) |
| `CGHpbA9hkBjePxgqpNa4pQG71z7CK6TwAfdS2nhLEYCz` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `CHyeS1oYvNDGAkrtFfk5KhcqJRMsF1ZGvDNvga9uBpg1` | BONK | null | stale (140337695 slots old) | - | switchboard 6qBqGA.. stale (140337695 slots old) |
| `EHYKMca8skYMBpJMrPhM1EN32KMziq1Vg9Jvo6YE4YEj` | bSOL | stale (168728418 slots old) | stale (156882246 slots old) | - | pyth AFrYBh.. stale (168728418 slots old); switchboard EPw1Vb.. stale (156882246 slots old) |
| `Earmo1Uiysms1t4JLFRNHngPR2hEfRTyf3gqAA15GzvF` | xUSD | null | stale (278189615 slots old) | - | switchboard 5E6KYe.. stale (278189615 slots old) |
| `Ehfqs6VfnG41oDW7j3amggyc18u4zSUVAAt1UMVwBT7k` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `FBv3snxMHnnLnBzSmXuGf2jn55weLULcrYB6LhvkWHLt` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `FnNdRdc42x6fExefKr6936cSqfy6617NStv41xrerxa3` | USH | null | stale (278185105 slots old) | - | switchboard BV9J7X.. stale (278185105 slots old) |
| `Gh9CBq7VW8sVWR9RoMkenH72iUCeyBq3CV6AA5QkhPP2` | None | stale (168728418 slots old) | stale (179657595 slots old) | - | pyth 7yyaeu.. stale (168728418 slots old); switchboard 8n3QYC.. stale (179657595 slots old) |
| `GonhXN39z4u4mUV22H5TXJN32EWvP5ZSEjBoahv8BKcd` | META | null | stale (221874651 slots old) | - | switchboard 5UgyUS.. stale (221874651 slots old) |
| `HYgybuXPbk2ZFk42RsobmGXEJgdT7LtmudskaTC11Kxu` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `J85gSAR97zxoW4D9qopwGyuCTUpTTLrYKmtap5nkPqgS` | None | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### LABS — `J68CaDEkSNKaHomtoScfLpF33rG6ZF4iwh4pWapGr5zm`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $8.25)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `6ETHUUnUzhMoPGDUWuQVqtjkiAp4R6QzwgnYa35jTazz` | LABS | null | stale (110779197 slots old) | - | switchboard 2myWdb.. stale (110779197 slots old) |
| `Cz5MtxbPtBZbdU4TMtzEWoFzrevjhcAKzD1MVmzwqVTq` | SOL | null | stale (19310408 slots old) | - | switchboard Ceveqp.. stale (19310408 slots old) |
| `HsVF5Xd851J2BuPuDmzKAs7MbUyMbh7N9uphCRb4NXJe` | USDC | null | stale (120908596 slots old) | - | switchboard Es7UJM.. stale (120908596 slots old) |

### BONK SOL — `GW6Tr58KuiZvniLFU7HpJJgnsphTXAXQnmdwKXQ8wqzc`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $5.62)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BUf2EF7KSqy86TRmXCCpWKjsNrZVKzo5PApcUjjLNM25` | BONK | null | stale (211334086 slots old) | - | switchboard FaEXa4.. stale (211334086 slots old) |

### Rollbit — `3XDS3wTDqBs2RETry5h3HbsBxToueTPWKFZksCFJXjPV`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $5.05)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5K8esq4W6R2hjXbMEdgextnwvay6hWXZYKQZ6MBoEg7D` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `7C9NEUfgdbE3TSQV67QJrMVzXZUR7ujfyNDCWArRBnML` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Solana Capital Markets  — `71abN22xE5NMRCefA6miVXKN9JKvUmbyF91H3e7MhvkF`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $4.02)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2X59kbmjddKVsK4sQZP947HRrapfWTp5cmnXWC3fWTx3` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `A1tNWfp3dor2YFnwd6V7XPuUmaR9cFi651MzrRUuNHnE` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Blocksmith Forge — `GBnQBJKqgn9jYp3rrdDw45APDh1Rsu22NDNMkDfeh5XX`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $2.37)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BtSVbETgaoNouyqZtfmoRA7Di9whY9v7tTGwefYEZvdD` | FORGE | null | stale (303915630 slots old) | - | switchboard 9R4pFH.. stale (303915630 slots old) |

### Stable Steroid — `6saXeFHDAVmhMvGxz1v8KBG9ta1ZsuDssCR6hNHq9YDi`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $2.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `RxKi4tLmWXVrcDyubRTQPoBSmGeHk3yxG95dU2pvod1` | USDH | null | stale (279902538 slots old) | - | switchboard 4wv7S1.. stale (279902538 slots old) |
| `xQXzDto4fGZtx3HAeBMAkVe1d43Eu69uQPzrLv3cWFV` | UXD | null | stale (166459324 slots old) | - | switchboard FcSmds.. stale (166459324 slots old) |
| `6vak5SzAApBFmMt5bhpn4WCd6iPspzkhbSMmdSkVyxNX` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `9rL9NxxpDVLE5oh5pHswprHMvU9zN7YxtDYmEBQpuJZh` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |

### LST — `5mTjkczMbAYAm9eUYXyoJkWxmCzSZzjdMK4hLp7t1G1w`

13 reserves: **0 refreshable**, **13 NOT refreshable** (stored value $1.73)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `NMhH2K3KBYA8RDmJjKqUSUwUEV8eBTw8AK81b1Ft5ee` | LST | stale (168728418 slots old) | stale (179657782 slots old) | - | pyth 2H6gWK.. stale (168728418 slots old); switchboard qQcShW.. stale (179657782 slots old) |
| `4wYEcsdbG3kj4FcwKEkiK4Z8Fb4qFidgDPYoxyeuBgqN` | vSOL | null | stale (143223287 slots old) | - | switchboard 1qwLbi.. stale (143223287 slots old) |
| `6EkWxzEeRvdtk5T1fpt5wyV5ctLx7ut1eLU5s652d5HD` | bonkSOL | null | stale (162004228 slots old) | - | switchboard G6VU3k.. stale (162004228 slots old) |
| `9cFupDfEMvhYqTmoVNRFikdfU11jnybkS65H9uK2AXNd` | bSOL | stale (168728418 slots old) | stale (147876198 slots old) | - | pyth AFrYBh.. stale (168728418 slots old); switchboard 6Poy9L.. stale (147876198 slots old) |
| `9jd5ah2EvtdLoTZ2LVL2mWZ5bMHDMq21U6vZrTsT9sGX` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `AB8qGTDUJFdgPjTF94ZKTifBEbgBZ9W7R2YkXuTDbasY` | compassSOL | null | stale (173775603 slots old) | - | switchboard GnGbho.. stale (173775603 slots old) |
| `CjGyFzpe6JrnTYZAhZzaJVG68oFCY2BVfnV2uYAexrwL` | mSOL | stale (168204087 slots old) | stale (148013870 slots old) | - | pyth E4v1BB.. stale (168204087 slots old); switchboard 78zWxe.. stale (148013870 slots old) |
| `E731ooqhWFeCWNcykW1M7urBYYDyi5h9AonrVJ7oEfgT` | picoSOL | null | stale (162506661 slots old) | - | switchboard 5zEWAj.. stale (162506661 slots old) |
| `G2dNMT8s74XXomVWV5GuaxBrLVuLZKacZUcJJfmnZH5Q` | JupSOL | null | stale (158214141 slots old) | - | switchboard FdUyXN.. stale (158214141 slots old) |
| `GEuX23gKpiARsntk76h5NSWfNzGmETGyHyB3sWYMcB6G` | JitoSOL | stale (168728418 slots old) | stale (147855734 slots old) | - | pyth 7yyaeu.. stale (168728418 slots old); switchboard GvWB8u.. stale (147855734 slots old) |
| `HF4XcAsWELgmRbLPS7gqQkh8ts5G7xFfqYB3KXURarGu` | hSOL | null | stale (158258551 slots old) | - | switchboard JBLjg2.. stale (158258551 slots old) |
| `HZUY2nib4GGZZosgE9Dnz2WzD8aKF8adk4HQkm5ptM1m` | INF | null | stale (174457024 slots old) | - | switchboard 9gdEha.. stale (174457024 slots old) |
| `HpmugbNn4oueFe2Hjuzn72ExhEg8QqB9H7fCPcCCGWZi` | compassSOL | null | stale (173775603 slots old) | - | switchboard GnGbho.. stale (173775603 slots old) |

### JLP Leverage — `5wKiTRUs2uku6JGPFowXnkx9Trgujd9T4kJaDYvr2YLF`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $1.70)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5KqwogfXrJqyTkHdWF6aAHQLNsN93evDcwMQSUwLZDVH` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `6R2aTYmeZtqFvFh4CAJb87xK9wRD2BxiMC6j93d8oS7K` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `CB4A7yrhcvn9ez3vW5CQ5KUPSitZGvB5C5HvGTaScKYn` | JLP | null | stale (157752166 slots old) | - | switchboard HR1mmj.. stale (157752166 slots old) |

### soBTC — `8NrVrU52Mj5nFjvTbHGWCiMo1CfhFps74h5ED9oVrTtk`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $1.57)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4wwDNDqYBLNcubMs4P518PvghgXMtU5xG928ScBwTUmR` | BTC | stale (168204085 slots old) | stale (140336491 slots old) | - | pyth GVXRSB.. stale (168204085 slots old); switchboard 8SXvCh.. stale (140336491 slots old) |

### $QUIT 🛑 — `3Qzr2ef3396dcqDrvbi945XdQ7ZkTDSqAWHrR2aGZb4T`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $1.27)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `35fT48ZRcX1yjsNjeHyQxh2D2crTnyGLr3PPHRmyWRir` | SOL | null | stale (172299204 slots old) | - | switchboard 4aUbjc.. stale (172299204 slots old) |
| `3Uk8Gcgf4hZbr2iZGnjcf1cKQ82KCwoaguT4oBaxDcSm` | USDC | null | stale (148034073 slots old) | - | switchboard FwYfsm.. stale (148034073 slots old) |
| `FuSZrP8z1iNBTuwDzijpMP5hkn2syL3r6MJPtQ2Tk6ad` | SOL | null | stale (172299204 slots old) | - | switchboard 4aUbjc.. stale (172299204 slots old) |
| `GnHnoXRVaM2shmqRvb6SuwE7ub34aoTr11UrMdiu18Jd` | quit | null | stale (175630634 slots old) | - | switchboard GPhiB5.. stale (175630634 slots old) |

### SLERF — `CH1yHzRgs6Wx123LmZo9JqsoaJU8YomAFjmy1v67tdWe`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.93)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `24FQ9i9SXn2ibwyycFxKhXssRw9hK5Z22QQiGG5ZJqCR` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `85oPGmdJJNqQmKCTWMGCDnPzsJDgHLDWQY5c8tXqgtWS` | SLERF | null | stale (179657536 slots old) | - | switchboard 3r2PsQ.. stale (179657536 slots old) |

### Blocksmith Labs FORGE — `7REN47mgHozfnnetmUfWd1uqr6fj85hCzDF55e1y9bJG`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $0.90)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BHzw1P7av1jDkctv2hF1JYqJEbp7dRopjRRFVuBKE9B5` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### PumpSwap — `4QYw8FbGBYqRnEWACZCBu1zHpMoYhnAHcqSKZZMv95RK`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $0.67)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `CVszJmsprmmbvBnGdsj4fKxMjYNfGUYes9NuuKXAkQKn` | (USDC-WSOL) LP | null | stale (121054176 slots old) | - | switchboard 6USvry.. stale (121054176 slots old) |

Refreshable: `BjHhXpFR..`(USDC,pyth), `EooVR9x4..`(SOL,pyth)

### Symmetry — `DQArSfEHYPaaJWn2ftV15JYFc2uPkLctUqRS3WYMk874`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.50)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `CESQ9JQdtr7WUamwrPeZUQEqGpzYbgjGbuvjxTTpsjd8` | beyondLST | null | stale (149623461 slots old) | - | switchboard 64bMFc.. stale (149623461 slots old) |
| `Ctiiq61aC7ToFgi1TUACbJrHtbdHRrXZpnyT7Y65XQp2` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Risklol — `7AvvBmbTuEXdNwi6NeCteAEwaBULPseKJ5x6TemGzPGt`

14 reserves: **0 refreshable**, **14 NOT refreshable** (stored value $0.42)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2TWLwLcPkT4kPRaRTwzEfPX9wz5RESmxLJMQ8EeB4Fdf` | USDC | stale (168205596 slots old) | null | - | pyth Gnt27x.. stale (168205596 slots old) |
| `2gF6m3iZsezu8dbqmDYEVp49NvMiFqwn9kyPjJsMVEfP` | SLND | stale (168728418 slots old) | null | - | pyth HkGEau.. stale (168728418 slots old) |
| `4VJgyXt2XierRe8GQbnXEMHxZJzw6YrY1dVy8dG9vf7Q` | ETH | stale (168204094 slots old) | null | - | pyth JBu1AL.. stale (168204094 slots old) |
| `5eBHBTUY833pyiKXuRiLE3rmVnZ3mwYiMSus7LhY7JC1` | COPE | missing | null | - | pyth 9xYBiD.. missing |
| `6St5TeB8k6gFbSEhruBCtUkJE6p16RmYGxTyB7WpRbU7` | ORCA | stale (168728418 slots old) | null | - | pyth 4ivThk.. stale (168728418 slots old) |
| `6em7SiLo5juBo9fiwAPenxX9cCNrvsd5SG64bi4i8AEi` | SRM | missing | null | - | pyth 3NBReD.. missing |
| `7nsJmdmJdaxw9eabUMwWtGTPj1r1u4ef5KG5EeHMtmhb` | mSOL | stale (168204087 slots old) | null | - | pyth E4v1BB.. stale (168204087 slots old) |
| `9gwpwPHT6hzNgByYAVFYbVgEMiviF23XB5DVYQHCEF3P` | SOL | stale (155707389 slots old) | null | - | pyth H6ARHf.. stale (155707389 slots old) |
| `E7vmMJ8Wr51E8KgtW8eQvpcFbB5hUD3Rem48kSoAmgAG` | C98 | stale (155707397 slots old) | null | - | pyth 45rTB9.. stale (155707397 slots old) |
| `EmrmenfLQ7eJaDeSWnLEWmYSkza14gaiV1ad7cEMx5LM` | RAY | stale (155707389 slots old) | null | - | pyth AnLf8t.. stale (155707389 slots old) |
| `EmvMjjurjbUAtcRc4ZkjsrtAadEURoRykU2g32taRtXM` | stSOL | stale (168728418 slots old) | null | - | pyth Bt1hEb.. stale (168728418 slots old) |
| `FR7ja34m5RB5jKpQAgAn8vQXkCmrxQ2TW6siFhf9cePR` | FIDA | stale (168204085 slots old) | null | - | pyth ETp9eK.. stale (168204085 slots old) |
| `Fss8WMvhC3SyfnHcd5SLeqzrYVeYoABwPtus8oSmEEsm` | MNGO | stale (168204101 slots old) | null | - | pyth 79wm3j.. stale (168204101 slots old) |
| `GoUCdbbaHX3MZbu1wVJfHoVuztz2xKBeargp3bgx1JR1` | GMT | stale (168204085 slots old) | null | - | pyth DZYZkJ.. stale (168204085 slots old) |

### fPHX Lending — `Ay7sWYC5vAfo8PTYmUtYmdAWVmuk8vMgGE7b2JYHvz3y`

4 reserves: **3 refreshable**, **1 NOT refreshable** (stored value $0.24)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7jaTJ6qn7pke6bXFYYp1EanMu4FjBfKA6PB9i2J4sN2m` | fPHX | null | stale (76579012 slots old) | - | switchboard 7kHnDm.. stale (76579012 slots old) |

Refreshable: `6JgM3C15..`(USDC,pyth), `AWBSETzo..`(SOL,pyth), `CNnwDd6r..`(JupSOL,pyth)

### EUROe — `Hs5f8ymzu8TTBMY6te5AkwBztSs48UCoeUJC498GwPm1`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.14)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3WwFn1yd3A3k9RqDBFr2ByCLiBPrBQ8YrkzVmwm36f6y` | EUROe | stale (168204085 slots old) | null | - | pyth CQzPyC.. stale (168204085 slots old) |
| `8sChaK6bda3p5iokzb9egXcUdwvfwp4G5FaXUqPgdsdj` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### MBC — `G8RHnATcdsD1pFqK77dqgaXwHZkfqw7wgHGCD6nvkpLu`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.06)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `4K326tZ97PezD6dCQ6n7QaUbMjtnuPxo7H83R2mrancg` | BEAR | null | stale (220426019 slots old) | - | switchboard Cn6jgQ.. stale (220426019 slots old) |
| `5YHHvLhySn5UgCfcVmPLGAL7tRy6ChwNdkKnNex3mdcU` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### EARN USDC — `AUdZAhcpYfhv859hfNZUqtRJxqR81hgLiVqvTHuTCAnD`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.04)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `AgkkB2T6r4ECpQ4eG7hghqyPe3eUC9Nu9gjeaHjTkiSi` | USDC | null | stale (140336579 slots old) | - | switchboard BjUgj6.. stale (140336579 slots old) |
| `HdZdtGpkNYj9EG2wv4ufShxaqSNSDE9oQWCZrvTpr9Ke` | EARN | null | INVALID (no result (result.slot == 0)) | - | switchboard ChZSZo.. INVALID (no result (result.slot == 0)) |

### NANA token — `4qbXzSKFcyizMWXUzZGf9UqZGuzaqSLdZsHPQe1LcW8X`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $0.03)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5UoJC9iUEcinZd3kAjqFEZFoFrZtfc8Rcq7TG9b3FbBp` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `7omKTXCsukodKUDCzBQwtxi6qp7rmCr9TFahK8SdU1gZ` | NANA | null | stale (179657546 slots old) | - | switchboard 32fwSS.. stale (179657546 slots old) |
| `84EnY1UfR6UmLsWvrCEDWCEVmVyW3u8nM4XUS3oHP1uW` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `C8CLfCM4B15M6vr31n9c19hiJQ8T6qnGqJqXbtisSBTA` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### Wobbo — `9SvSG6dJ682BLUzg8E7ncrHfGWb7m6GSZutXL7QVAXkX`

1 reserves: **1 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `CpK2CM2m..`(SOL,pyth)

### test test2 — `EiZNeNEPPmbrNMW4CzoVD6J7HwTHTWDTeqNu3eiP4r32`

4 reserves: **2 refreshable**, **2 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `3HguwQwepepfWNG9rJJZnvj5GpLH1yL6u3BgrUjFXmDd` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `63sofTZ7wfxK363BSuUt73HDWdzPgU4X32BE6kGDR2i5` | LABS | null | stale (166937449 slots old) | - | switchboard 9bmfWw.. stale (166937449 slots old) |

Refreshable: `4v5E2t6q..`(USDC,pyth), `66WivatY..`(mSOL,pyth)

### PT Assets — `52cGq9oPoSe2u6xXEAFZHoTLdt8RsdJVAscB2og3tUof`

3 reserves: **2 refreshable**, **1 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `36eWoXkc2CLNBteyuhaxUhNaB2QEuMahm8xYg8wB17Cj` | PT-fragSOL | null | stale (122754163 slots old) | - | switchboard EKSoEG.. stale (122754163 slots old) |

Refreshable: `Buo6z2NK..`(SOL,pyth), `D59A1Rgt..`(USDC,pyth)

### FART Lending — `8W6HtChtUN34oeJob8dJ6rcjHDpj97RmfSLTSB3Q2oFo`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `5nSZoAfhZjMarRqnQR3JEn72u1WfuPrq1pfCeYEykG2Z` | SOL | null | stale (10177135 slots old) | - | switchboard 8PAQbJ.. stale (10177135 slots old) |
| `HRwbrxqTa9xHrRkHUEjPfEveSdG13dBt36xSw7VWsoMp` | Fartcoin  | null | stale (10177135 slots old) | - | switchboard BrFsAH.. stale (10177135 slots old) |

### Turbo SOL-UXD — `HG87MN878GwrLkBN2gZXxbSkcJmtKLcLjPhgZyf64rEx`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `Cp1MMXGnVJTzxv5Yoo7yCdEEzQX6tXLG7KYyn1bUUMyH` | UXD | null | stale (166459324 slots old) | - | switchboard FcSmds.. stale (166459324 slots old) |
| `FikncwPEco2dxMf5ZXLN3yXjzqveRPF6yCSDX4TGQTia` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### Symmetry — `6GbXyMk3cyxV9koMPRCKYM12X4CKynptfNMZSytdPHRQ`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2XeKjZDHmVTt6pXXTRtZCNXdXMdEoHeDE5wejVHGnDzf` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `8k1BPidZYAMoxvMRroBVF5UTntKTEKoGmzQzGBNHe64D` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `CgXWtNkRjoK8cZFKkZaMWXsP64nEZgbU9KvLQydbaztU` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### ULTRA DEGEN MAFIA — `4HoeVutADhj6pe1UyugRqdECJ4nPzZAagPVY3iK6Uhmb`

6 reserves: **0 refreshable**, **6 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `FWb6yeePaP6x9TzZh9ZgFixxj6ENMCj2o3KmAL8KYaL` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `62q7CzE8CYVGMigmKhaKnmksmaYmGZSFHocwmirnkZBN` | SOL | stale (155707389 slots old) | null | - | pyth H6ARHf.. stale (155707389 slots old) |
| `6WhqwkMoXGvJz5DNbFtUYYwZQ1eHHE3ZYirXPmiCJSn4` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `DkwxG4k6MyQHGaYXW2YTmxtdsogw3HRNbpJRALLiQ421` | HARAMBE | null | stale (178412213 slots old) | - | switchboard Edcnop.. stale (178412213 slots old) |
| `FY5VxBBMzGoydSztTosTsSLwxeV9HGbSQvgQSKeB5Yev` | SOL | stale (155707389 slots old) | null | - | pyth H6ARHf.. stale (155707389 slots old) |
| `GLEdXXZkoaQMqxZUQ5QQ9yUNgNZMHFc1BjpTwX325tzc` | WIF | stale (170493926 slots old) | null | - | pyth 6ABgrE.. stale (170493926 slots old) |

### TOKE — `CVoqf74LyKefeLDWjEZPSkM8YqArCWQ53WJdZzE747CK`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2FYpNMUxwnpJYcraPB6U9zstC1G76JspekUUSjNYhm9u` | TOKE | null | stale (182861561 slots old) | - | switchboard 6zXsYi.. stale (182861561 slots old) |
| `BRpaMskirBk5fNoFHCVeTtMNc8KhXLkJfhwYXZYEwuAS` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### WIF — `ChFPm8ZuBMM3r6UNyjpvuzFGBq2g7kQysjA58efRvMs5`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `2EkYVxW8r1ev9cnyisxLJkLVvZbNm2G7DaJCLW9qsJ18` | WIF | stale (170493926 slots old) | null | - | pyth 6ABgrE.. stale (170493926 slots old) |
| `Ay4ut1u8sScgr5tAwWGeZZaqvLaESKRzQrpwoJUMBFYE` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `FjkoMgZU7WqBbuGveF6x1VtdqVqa72Ji8BktFqcVkksr` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |

### JLP Yield  — `3T1FcrhsL9FmMFfZyNHxohEQvBUzeWYQzE7rk7bubXxp`

4 reserves: **0 refreshable**, **4 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `67AMy1UtuWoyYdpfWbiZkVTHtJWjsp1Yfi8iomSavfw` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `2p943vZA1e4aV1LvM8VtXzQKC8KaU1wNev6WPnkdceDf` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |
| `8kWs9EtCwNFJuDXWgx5aEphAe9ACVG1iYPG7cKgsgJbs` | USDT | stale (168205596 slots old) | stale (140336519 slots old) | - | pyth 3vxLXJ.. stale (168205596 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `DbtvTedtEvnZSXFQAucjAthQ599f3p5T3qvxa9Gp1Yfj` | JLP | null | stale (179657722 slots old) | - | switchboard EzBoEH.. stale (179657722 slots old) |

### Slerf it up — `GpbKSCJxmmkg3SV7X2du1XnRX3MNgdkunhUCGkdZLAuk`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `31NUJ2FLusPUa2kxYDHyCwKAi427H4xkurdGk3MqYfGo` | SOL | stale (155707389 slots old) | stale (140336491 slots old) | - | pyth H6ARHf.. stale (155707389 slots old); switchboard GvDMxP.. stale (140336491 slots old) |
| `EiqnCmUJbCcXgtMSjjS3i196G6V2ksjH25vjD41XWyEy` | SLERF | null | stale (167149735 slots old) | - | switchboard 8LxP1j.. stale (167149735 slots old) |
| `GVF2k4pKPmcAUgTxRzMdHYf8YZrWDbESnz62JNGhXM3r` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### REdao Pool  — `6vDQ8gGhCy3XJFTrzwQMDmgpmJiFDwmMxikVh89qiFYy`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `27hJjgYJtQJgDpoqdc8BohL4qR3fdJkpAH73o7vLumJn` | $RE | null | stale (179657512 slots old) | - | switchboard 3igYhy.. stale (179657512 slots old) |
| `4DTJtwtxnUw9gRKnEo5aShbtjqCzYUNcFjkyedUxe5nc` | SOL | null | stale (140336491 slots old) | - | switchboard GvDMxP.. stale (140336491 slots old) |
| `659Zadby13CSk812BsripLqbb9LTE8FRDJG4zP4XEZ91` | $RE | null | stale (179657512 slots old) | - | switchboard 3igYhy.. stale (179657512 slots old) |

### sadfdsaf — `CoVGNiqThDaqQyL5vBer4A73Q4jkpbYQJ96d74W6W7HN`

6 reserves: **6 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `5CcVkEE3..`(USDC,pyth), `7PNNMtTx..`(USDC,pyth), `AS1VtNRp..`(USDC,pyth), `ByTFAtS5..`(USDC,pyth), `EaZpzii6..`(Fartcoin ,pyth), `EyvcC7ce..`(USDC,pyth)

### Leverage Trade Jup/USDC!  — `7zEA6PvYnLdBvBuJxmPme3D4JxTRqMFqrma1H3cHqPAW`

6 reserves: **6 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `2HiM4rUW..`(USDC,pyth), `4YxNHHG1..`(USDC,pyth), `9aAN4Z5M..`(USDC,pyth), `CcBeh1RV..`(JUP,pyth), `DmMSEorb..`(USDC,pyth), `FtuwwnGM..`(USDC,pyth)

### dell — `rU5S6tx2y96TSCsoXEvuiutaftpdNCoqPrnVMJex4mN`

2 reserves: **1 refreshable**, **1 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `9M22xh1xnF99KMfCRgwuGbDypEJDuJNi3aJsbSkP151h` | SRM | missing | stale (140336491 slots old) | - | pyth 3NBReD.. missing; switchboard CUgoqw.. stale (140336491 slots old) |

Refreshable: `DFTdsR4c..`(USDC,pyth)

### zzz123 — `EuiWA7MJc2HgDm1GcRFyLJ36auKvAwxQhALGsP7iQmZF`

1 reserves: **1 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `HpBJHsDG..`(USDC,pyth)

### JLP plus — `7Apke1REW9fdaKQ4N8cYhSP6Pipa7kPF2Q5ULFViHncf`

1 reserves: **1 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `GVEZFZ7j..`(USDC,pyth)

### zxcvzxcv — `HcJ2ZT5u1BEvpVuy3gsSYNvE2zbfcJNYQhgDsifmJoHQ`

1 reserves: **1 refreshable**, **0 NOT refreshable** (stored value $0.00)

Refreshable: `At12t65c..`(USDC,pyth)

### Clone — `2QRcHJgV7chRBr8FEwZ4XmMhCrWPxJ9yWhTFNNzVxwe9`

3 reserves: **0 refreshable**, **3 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `6ktP31No38uH3FbctNPJq9rAnB8Z5jdyfhRUXSDoXwLJ` | clARB | stale (155707396 slots old) | stale (140336519 slots old) | - | pyth 5HRrdm.. stale (155707396 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `99Er1hkhZtwFwKeiVcktH5eYrDQCbgm5SZwaAJh3TKcG` | clOP | stale (155707396 slots old) | stale (140336519 slots old) | - | pyth 4o4CUw.. stale (155707396 slots old); switchboard ETAaee.. stale (140336519 slots old) |
| `GvkF5oaMBqTxJmrHJ1KqKS6TW86GjrtsP8YkbwKQ9qcF` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### StepN Dual Token Pool: GST/GMT — `Ce86XqTxRQ2pBCqkyFT3zFaKZsd4m23o9rfKCEv5zfPB`

2 reserves: **0 refreshable**, **2 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `7KyfK6B9oHscDQ7aUZ9zhcgGxL6qmrSwRmD3yvpGSPiv` | GMT | stale (168204085 slots old) | stale (150967234 slots old) | - | pyth DZYZkJ.. stale (168204085 slots old); switchboard Bys1SN.. stale (150967234 slots old) |
| `BtcofmywW4Rab7piWvCx65puUNWeEkrggg4HSLn3EsFq` | USDC | stale (168205596 slots old) | stale (140336579 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard BjUgj6.. stale (140336579 slots old) |

### Uncollateralized Loan — `73ob5s2bjX3gcwf62js8SG2jNwDY6F1xiGcMH1mfhxik`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `BXs6h1DZJ7yAcFLn43MuCuWWv7fSaGcSgmkrnR419wtp` | USDC | stale (168205596 slots old) | stale (148034073 slots old) | - | pyth Gnt27x.. stale (168205596 slots old); switchboard FwYfsm.. stale (148034073 slots old) |

### sdafsdffdaf — `FV82WJG8Pym22qt8niognc65iodoScssmyhqmfuFbt6W`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `F6QwH7zX9zqXrXMhKmss5vmBHP3UWpin2MwWrcsp1oVr` | JMoney | null | stale (47653501 slots old) | - | switchboard 75q6G8.. stale (47653501 slots old) |

### Jupiter Mock ZEROBOIS — `GXtqrEhQUCrbXCh1LEKnqTv6uL7rL9WNaLBoRpmqm3HQ`

5 reserves: **0 refreshable**, **5 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `XXU8LyMLXodHUo2Xm4gMP4WB3a8YFM9stKFjtFB4rXn` | mockW | null | stale (208364069 slots old) | - | switchboard BH47iV.. stale (208364069 slots old) |
| `3Q5Aa4Q4iUMe9KZW64AvUMEeSQZsA8zQEgrGj6vXfJ7y` | JRK | null | stale (208350846 slots old) | - | switchboard 6DP1pW.. stale (208350846 slots old) |
| `8m1YkqrMH843ycvsKncrxwhAX2TsUed1Goi9Y6t5Rk2Q` | mockMEME | null | stale (208348599 slots old) | - | switchboard BWnkvR.. stale (208348599 slots old) |
| `A1GXwaQaBY9K2ud4ny8MpuG3SNv1eVCCVXXjG7udf6oU` | mockJUP | null | stale (208343284 slots old) | - | switchboard 6nKbZf.. stale (208343284 slots old) |
| `HW5d3XesK4LMJaCCvMNcwF2jRnV7w5iNvtQYxDc4wP8H` | mockUSDC | null | stale (208353652 slots old) | - | switchboard B3dwdQ.. stale (208353652 slots old) |

### Vicky — `EYXAeBDoP2aPZ17G4W639QRRJfAA5ZFW8SU12h1oZ4yB`

1 reserves: **0 refreshable**, **1 NOT refreshable** (stored value $0.00)

| reserve | symbol | pyth | switchboard | extra | why not refreshable |
|---|---|---|---|---|---|
| `9ZRVcVzf6h1S9qgi5EHy846pkRJXzDiDhxxU4hJzrnj4` | Vicky | null | stale (140555628 slots old) | - | switchboard 3YaCes.. stale (140555628 slots old) |

## Validation

- Main-market USDC reserve `BgxfHJDz..` oracle `Dpw1EAVrSB1ibxiDQyTAW6Zip3J4Btk2x4SgApQCeFbX` decodes to **0.99986509** (stored $0.99983633) — expected ~$1.00 ✓
- Pyth receiver SOL/USD feed `7UVimffxr9ow1uXYxsr4LHAcV58mLzhmwaeKvJ1pjLiE` decodes to **$109.8277** (19s old, gates=True)
- Switchboard v2 SOL/USD `GvDMxPzN1sCj7L26YDK2HnMRXEQmQ2aemov8YBtPS7vR` decodes to **$214.0285** (round 140336491 slots old — deprecated feed)

Stored reserve price (reserves.json) vs freshly decoded oracle price (recently-refreshed reserves, no scaled-price offset):

| reserve | symbol | stored $ | decoded $ | diff % | reserve refreshed at slot |
|---|---|---|---|---|---|
| `8Pbodeao..` | SOL | 110.17949257 | 109.82771951 | 0.319% | 454761465 |
| `8K9WC8xo..` | USDT | 0.99921022 | 0.99915500 | 0.006% | 454761273 |
| `BgxfHJDz..` | USDC | 0.99983633 | 0.99986509 | 0.003% | 454752483 |
| `UTABCRXi..` | SOL | 109.96891293 | 109.82771951 | 0.128% | 454746287 |
| `EjUgEaPp..` | USDC | 0.99985222 | 0.99986509 | 0.001% | 454746287 |
| `Ag7UiqS5..` | cbBTC | 82054.56286988 | 82182.50000000 | 0.156% | 454736757 |
| `HUL7GeHE..` | USDS | 0.99985319 | 0.99986509 | 0.001% | 454725622 |
| `4d5aycKF..` | wstETH | 2470.10115040 | 2485.42366153 | 0.620% | 454716732 |
| `CPDiKagf..` | ETH | 2470.10115040 | 2485.42366153 | 0.620% | 454716732 |
| `5wQyM4Vi..` | SOL | 108.75767345 | 109.82771951 | 0.984% | 454716338 |
| `BUMaLnJx..` | JitoSOL | 141.91997000 | 143.32947720 | 0.993% | 454716338 |
| `GbiJTmxb..` | ETH | 2470.49996215 | 2485.42366153 | 0.604% | 454716338 |

Time-consistent end-to-end check (reserve refreshed within 240 slots after the oracle's own last update, so decoded value must equal the stored reserve price):

| oracle type | pairs | max diff % |
|---|---|---|
| switchboard-on-demand | 16 | 0.0282% |
| switchboard-v2 | 1 | 0.0000% |

