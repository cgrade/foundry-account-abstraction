// SPDX-License-Identifier: MIT

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {HelperConfig} from "./HelperConfig.s.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

contract SendPackedUserOp is Script {
    using MessageHashUtils for bytes32;

    function run() external {}

    function generateSignedUserOps(
        bytes memory functionData,
        HelperConfig.NetworkConfig memory config,
        address minimalAccount
    ) public view returns (PackedUserOperation memory) {
        // Add validation for EntryPoint address
        // require(config.entryPoint != address(0), "EntryPoint address cannot be zero");

        //1. Generate the unsigned userOps
        uint256 nonce = vm.getNonce(minimalAccount) - 1;
        PackedUserOperation memory userOp = _generateUnsignedUserOps(functionData, address(minimalAccount), nonce);

        // Get the userOp Hash
        bytes32 userOpHash = IEntryPoint(config.entryPoint).getUserOpHash(userOp);
        bytes32 digest = userOpHash.toEthSignedMessageHash();

        //2. Sign the userOps
        uint8 v;
        bytes32 r;
        bytes32 s;
        uint256 ANVIL_DEFAULT_KEY = 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
        if (block.chainid == 31337) {
            (v, r, s) = vm.sign(ANVIL_DEFAULT_KEY, digest);
        } else {
            (v, r, s) = vm.sign(config.account, digest);
        }
        userOp.signature = abi.encodePacked(r, s, v);

        //3. Return the signed userOps
        return userOp;
    }

    function _generateUnsignedUserOps(bytes memory functionData, address sender, uint256 nonce)
        internal
        pure
        returns (PackedUserOperation memory)
    {
        // Set more reasonable gas limits
        uint128 verificationGasLimit = 16777216;
        uint128 callGasLimit = verificationGasLimit; // Add explicit call gas limit
        uint128 maxPriorityFeePerGas = 256; // 0.1 gwei
        uint128 maxFeePerGas = maxPriorityFeePerGas;
        bytes32 gasLimits = bytes32((uint256(verificationGasLimit) << 128) | uint256(callGasLimit));

        return PackedUserOperation({
            sender: sender,
            nonce: nonce,
            initCode: hex"",
            callData: functionData,
            accountGasLimits: gasLimits, // Combined verification and call gas limits
            preVerificationGas: verificationGasLimit, // Standard transaction base cost
            gasFees: bytes32(uint256(maxPriorityFeePerGas) << 128 | uint256(maxFeePerGas)),
            paymasterAndData: hex"",
            signature: hex""
        });
    }
}
