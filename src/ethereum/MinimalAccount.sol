// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount} from "account-abstraction/interfaces/IAccount.sol";
import {PackedUserOperation} from "account-abstraction/interfaces/PackedUserOperation.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {MessageHashUtils} from "openzeppelin/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "openzeppelin/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "account-abstraction/core/Helpers.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    IEntryPoint private immutable _entryPoint;

    modifier requireFromEntryPoint() {
        if (msg.sender != address(_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint(msg.sender);
        }
        _;
    }

    constructor(address entryPoint) Ownable(msg.sender) {
        _entryPoint = IEntryPoint(entryPoint);
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    // A signature is valid if it's the MinimalAccount Owner
    function validateUserOp(PackedUserOperation calldata userOp, bytes32 userOpHash, uint256 missingAccountFunds)
        external
        returns (uint256 validationData)
    {
        validationData = _validateSignature(userOp, userOpHash);

        _payPrefund(missingAccountFunds);
    }

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    //EIP - 191 version of the signed hashed
    function _validateSignature(PackedUserOperation calldata userOp, bytes32 userOpHash)
        internal
        view
        returns (uint256 validationData)
    {
        bytes32 ethSignedMessageHash = MessageHashUtils.toEthSignedMessageHash(userOpHash);
        address signer = ECDSA.recover(ethSignedMessageHash, userOp.signature);
        if (owner() != signer) {
            return SIG_VALIDATION_FAILED;
        }
        return SIG_VALIDATION_SUCCESS;
    }

    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = msg.sender.call{value: missingAccountFunds, gas: type(uint256).max}("");
            require(success, "Failed to send ETH to the account");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    function entryPoint() external view returns (IEntryPoint) {
        return _entryPoint;
    }
}
