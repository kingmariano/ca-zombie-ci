# Omm exploit postmortem | January 2023 (archive.org capture 2023-05-31)
Source: https://web.archive.org/web/20230531205512/https://forum.omm.finance/t/omm-exploit-postmortem-january-2023/266

- Jan 21 2023 07:06:37 UTC: attacker deployed malicious contract cx1b2de6436be55a2d83b0978d2fb6a4423686165e
- 18 malicious transactions; withdrew IUSDC, USDS, bnUSD collateral not theirs; supplied stolen USDS as collateral to borrow sICX
- Bug in Redeem function: takes address representing collateral being redeemed; external call injected bad smart contract -> redeem collateral without supplying any
- Attacker used Balanced to swap; Orbit Bridge to move IUSDC to ETH/Polygon
- Stolen: 6,743,265 sICX / 599,704 IUSDC / 342,898 USDS / 264,111 bnUSD = $1,891,477.80
- Main exploit wallet hxc35cffe7c582cb313820fa6838dd357027ad3d07
- Recovery Fund hx6d36daba20cf74d54ff6e863f7f6e0a2653ed8aa (ICON), 0x0Bb7e89613d6520856D4DE6fF97E65D1329A0497 (ETH)
- Response: deactivated all markets, 0 rates on stablecoin reserves, halted Balanced, Orbit halted IUSDC bridge, Stably disabled USDS issuance
- Feb 3 2023 update: fix identified; "accept the Reserve address as an input, verify that the Reserve address is part of the Omm reserve, and get the token address from there"; relaunch planned; 50% DAO Fund OMM + 50% future fees to make users whole
