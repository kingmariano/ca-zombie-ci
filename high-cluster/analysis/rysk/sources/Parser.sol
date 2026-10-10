/**
 * SPDX-License-Identifier: UNLICENSED
 */
pragma solidity ^0.8.22;

import "./Actions.sol";
import "./MMarketOperations.sol";

library Parser {

  enum OperationType {
		GAMMA,
		MMARKET
	}

	struct Quote {
		address assetAddress; // underlying
		uint256 chainId;
		bool isPut;
		uint256 strike; // e8
		uint64 expiry;
		address maker;
		uint64 nonce;
		uint256 price; // e18
		uint256 quantity; // e18
		bool isTakerBuy;
		uint64 validUntil;
		address usd;
		address collateralAsset;
	}

	struct Confirmation {
		address maker;
		address assetAddress;
		uint256 chainId; 
		uint64 expiry;
		bool isPut;
		uint64 nonce;
		uint256 price; // e18
		uint256 quantity; // e18
		uint64 quoteNonce; 
		bytes quoteSignature; 
		uint256 strike; // e8
		address taker;
		bool isTakerBuy;
		address usd;
		address collateralAsset;
		uint256 collateralAmount; // collateralAsset decimals
		uint256 gasFee; // usd decimals
	}

	struct Transfer {
		address user;
		address asset;
		uint256 chainId;
		uint256 amount; // asset decimals
		bool isDeposit;
		uint64 nonce;
	}

	struct OTCTrade {
		uint256 chainId;
		address user1;
		address user2;
		address asset1;
		address asset2;
		uint256 amount1; // asset1 decimals
		uint256 amount2; // asset2 decimals
		uint64 nonce;
	}


	/// @notice Parse a packed payload into both Quote and Confirmation structs
	/// @dev Parses variable-length payload into Quote + Confirmation + sigs for both
	/// @dev also returns additional data needed to create an option position
	/// @dev confSig length is encoded as uint16 at byte offset 162, supporting variable-size
	/// @dev signatures (e.g. Safe multisig wallets with multiple signers)
	function parseQuoteAndConfirmation(bytes memory payload)
		public view
		returns (
			Quote memory q,
			Confirmation memory c,
			bytes memory quoteSig,
			bytes memory confSig,
			uint256 fee
    )
	{
		// Read confSig length (mask all but 2 bytes at offset 162) to determine how many signatures are included in the confirmation
		uint256 confSigLen;                                                                                                                                                                    
    assembly {                                                                                                                                                                             
    	confSigLen := and(mload(add(payload, 164)), 0xFFFF)                                                                                                                                  
    } 
		// expected length:
		// 20 (maker) + 20 (asset) + 8 (expiry) +
		// 1 (isPut) + 8 (confirmationNonce) + 16 (price) +
		// 16 (quantity) + 8 (quoteNonce) + 65 (quoteSig) +
		// 2 (confSigLen) + confSigLen (confSig) + 16 (strike) + 20 (taker) +
		// 1 (isTakerBuy) + 8 (validUntil) + 20 (usd) +
		// 20 (collateralAsset) + 16 (collateralAmount) + 16 (gasFee) +
		// 16 (fee)
		// = 297 + confSigLen bytes total
		require(payload.length == 297 + confSigLen, "Invalid payload length");

		quoteSig = new bytes(65);
		confSig = new bytes(confSigLen);

		assembly {
			let qPtr := q
			let cPtr := c

			// Data offset where fields after confSig begin
			let postConf := add(164, confSigLen)

			// --- Confirmation fields ---
			mstore(cPtr, mload(add(payload, 20)))                              // maker
			mstore(add(cPtr, 0x20), mload(add(payload, 40)))                  // assetAddress
			mstore(add(cPtr, 0x40), chainid())                                // chainId
			mstore(add(cPtr, 0x60), mload(add(payload, 48)))                  // expiry
			mstore(add(cPtr, 0x80), and(mload(add(payload, 49)), 0xFF))       // isPut (mask all but last byte)
			mstore(add(cPtr, 0xA0), mload(add(payload, 57)))                  // nonce (confirmationNonce)
			mstore(add(cPtr, 0xC0), mload(add(payload, 73)))                  // price
			mstore(add(cPtr, 0xE0), mload(add(payload, 89)))                  // quantity
			mstore(add(cPtr, 0x100), mload(add(payload, 97)))                 // quoteNonce
			mstore(add(cPtr, 0x120), quoteSig)                                // quoteSignature pointer
			mstore(add(cPtr, 0x140), mload(add(payload, add(postConf, 16))))  // strike
			mstore(add(cPtr, 0x160), mload(add(payload, add(postConf, 36))))  // taker
			mstore(add(cPtr, 0x180), and(mload(add(payload, add(postConf, 37))), 0xFF)) // isTakerBuy (mask all but last byte)
			mstore(add(cPtr, 0x1A0), mload(add(payload, add(postConf, 65))))  // usd
			mstore(add(cPtr, 0x1C0), mload(add(payload, add(postConf, 85))))  // collateralAsset
			mstore(add(cPtr, 0x1E0), mload(add(payload, add(postConf, 101)))) // collateralAmount
			mstore(add(cPtr, 0x200), mload(add(payload, add(postConf, 117)))) // gasFee

			// --- Quote fields ---
			mstore(qPtr, mload(add(payload, 40)))                              // assetAddress
			mstore(add(qPtr, 0x20), chainid())                                // chainId
			mstore(add(qPtr, 0x40), and(mload(add(payload, 49)), 0xFF))      // isPut (mask all but last byte)
			mstore(add(qPtr, 0x60), mload(add(payload, add(postConf, 16))))   // strike
			mstore(add(qPtr, 0x80), mload(add(payload, 48)))                  // expiry
			mstore(add(qPtr, 0xA0), mload(add(payload, 20)))                  // maker
			mstore(add(qPtr, 0xC0), mload(add(payload, 97)))                  // nonce = quoteNonce
			mstore(add(qPtr, 0xE0), mload(add(payload, 73)))                  // price
			mstore(add(qPtr, 0x100), mload(add(payload, 89)))                 // quantity
			mstore(add(qPtr, 0x120), and(mload(add(payload, add(postConf, 37))), 0xFF)) // isTakerBuy (mask all but last byte)
			mstore(add(qPtr, 0x140), mload(add(payload, add(postConf, 45))))  // validUntil
			mstore(add(qPtr, 0x160), mload(add(payload, add(postConf, 65))))  // usd
			mstore(add(qPtr, 0x180), mload(add(payload, add(postConf, 85))))  // collateralAsset

			// --- Extract Quote signature (65 bytes at data offset 97) ---
			mstore(add(quoteSig, 32), mload(add(payload, 129))) // bytes 0-31
			mstore(add(quoteSig, 64), mload(add(payload, 161))) // bytes 32-63
			mstore8(add(quoteSig, 96), byte(0, mload(add(payload, 193)))) // byte 64

			// --- Extract fee ---
			fee := mload(add(payload, add(postConf, 133)))
		}

		// --- Extract Confirmation signature (confSigLen bytes at data offset 164) ---
		for (uint256 i = 0; i < confSigLen; i++) {
			confSig[i] = payload[164 + i];
		}

		// --- Cast uint128 → uint256 outside assembly ---
		q.strike = uint256(uint128(q.strike));
		q.price = uint256(uint128(q.price));
		q.quantity = uint256(uint128(q.quantity));

		c.strike = uint256(uint128(c.strike));
		c.price = uint256(uint128(c.price));
		c.quantity = uint256(uint128(c.quantity));
		c.collateralAmount = uint256(uint128(c.collateralAmount));
		c.gasFee = uint256(uint128(c.gasFee));

		fee = uint256(uint128(fee));
	}

	/// @notice Parse a packed payload into a Transfer struct and its signature
	/// @dev Parses 130-byte payload into Transfer + signature
	function parseTransfer(bytes memory payload) 
    public 
    view 
    returns (Transfer memory t, bytes memory sig) 
	{

		// expected length:
		// 20 (asset) + 16 (amount) + 1 (isDeposit) + 8 (nonce) + 65 (sig) +
		// 20 (user)
		// = 130 bytes total
		require(payload.length == 130, "Invalid payload length");

		sig = new bytes(65);

		assembly {
			let tPtr := t

			// --- Transfer fields ---
			mstore(tPtr, mload(add(payload, 130))) // user (last 20 bytes of payload)
			mstore(add(tPtr, 0x20), mload(add(payload, 20))) // asset
			mstore(add(tPtr, 0x40), chainid()) // chainid
			mstore(add(tPtr, 0x60), mload(add(payload, 36))) // amount
			mstore(add(tPtr, 0x80), and(mload(add(payload, 37)), 0xFF)) // isDeposit (mask all but last byte)
			mstore(add(tPtr, 0xA0), mload(add(payload, 45))) // nonce

			// --- Extract signature ---
			mstore(add(sig, 32), mload(add(payload, 77)))  // bytes 0–31
			mstore(add(sig, 64), mload(add(payload, 109)))  // bytes 32–63
			mstore8(add(sig, 96), byte(0, mload(add(payload, 141)))) // byte 64
		}

		// Cast uint128 → uint256 for amount
		t.amount = uint256(uint128(t.amount));
	}

	function parseOTCTrade(bytes memory payload)
		public view
		returns (OTCTrade memory t, bytes memory sig)
	{
		// expected length:
		// 20 (user1) + 20 (user2) +
		// 20 (asset1) + 20 (asset2) +
		// 16 (amount1) + 16 (amount2) +
		// 8 (nonce) + 65 (sig)
		// = 185 bytes total

		require(payload.length == 185, "Invalid payload length");

		sig = new bytes(65);

		assembly {
			let tPtr := t

			// --- OTCTrade fields ---
			mstore(tPtr, chainid())                   // chainId
			mstore(add(tPtr, 0x20), mload(add(payload, 20)))   // user1
			mstore(add(tPtr, 0x40), mload(add(payload, 40)))   // user2
			mstore(add(tPtr, 0x60), mload(add(payload, 60)))   // asset1
			mstore(add(tPtr, 0x80), mload(add(payload, 80)))   // asset2
			mstore(add(tPtr, 0xA0), mload(add(payload, 96)))   // amount1
			mstore(add(tPtr, 0xC0), mload(add(payload, 112)))  // amount2
			mstore(add(tPtr, 0xE0), mload(add(payload, 120)))  // nonce

			// --- Extract signature ---
			mstore(add(sig, 32), mload(add(payload, 152)))  // bytes 0-31
			mstore(add(sig, 64), mload(add(payload, 184)))  // bytes 32-63
			mstore8(add(sig, 96), byte(0, mload(add(payload, 216)))) // byte 64
		}

		// --- Cast uint128 → uint256 outside assembly ---
		t.amount1 = uint256(uint128(t.amount1));
		t.amount2 = uint256(uint128(t.amount2));
	}

	/// @notice Parse a packed batch payload into OTCTrade[] and a single batch signature
	/// @dev Layout: [trade1(120 bytes)][trade2(120 bytes)]...[tradeN(120 bytes)][batchSig(65 bytes)]
	/// Each trade: 20 (user1) + 20 (user2) + 20 (asset1) + 20 (asset2) + 16 (amount1) + 16 (amount2) + 8 (nonce) = 120 bytes
	function parseOTCTradeBatch(bytes memory payload)
		public view
		returns (OTCTrade[] memory trades, bytes memory sig)
	{
		require(payload.length > 65, "Invalid batch payload length");
		uint256 tradesBytes = payload.length - 65;
		require(tradesBytes % 120 == 0, "Invalid batch payload length");
		uint256 numTrades = tradesBytes / 120;

		trades = new OTCTrade[](numTrades);
		sig = new bytes(65);

		for (uint256 i = 0; i < numTrades; i++) {
			uint256 offset = 120 * i;
			assembly {
				let tPtr := mload(add(add(trades, 0x20), mul(i, 0x20)))  // write: first trade struct starts at offset 32, each struct is 32 bytes in memory
				let base := add(payload, offset) // read: location of start of the current trade's data in the payload

				mstore(tPtr, chainid())                                    // chainId
				mstore(add(tPtr, 0x20), mload(add(base, 20)))              // user1
				mstore(add(tPtr, 0x40), mload(add(base, 40)))              // user2
				mstore(add(tPtr, 0x60), mload(add(base, 60)))              // asset1
				mstore(add(tPtr, 0x80), mload(add(base, 80)))              // asset2
				mstore(add(tPtr, 0xA0), mload(add(base, 96)))              // amount1
				mstore(add(tPtr, 0xC0), mload(add(base, 112)))             // amount2
				mstore(add(tPtr, 0xE0), mload(add(base, 120)))             // nonce
			}
			trades[i].amount1 = uint256(uint128(trades[i].amount1));
			trades[i].amount2 = uint256(uint128(trades[i].amount2));
		}

		// Extract batch signature (last 65 bytes)
		uint256 sigOffset = tradesBytes;
		assembly {
			let base := add(payload, sigOffset)
			mstore(add(sig, 32), mload(add(base, 32))) // bytes 0-31
			mstore(add(sig, 64), mload(add(base, 64))) // bytes 32-63
			mstore8(add(sig, 96), byte(0, mload(add(base, 96)))) // byte 64
		}
	}
}



