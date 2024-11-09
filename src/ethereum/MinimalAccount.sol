// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    error MinimalAccount__NotFromEntryPoint(address);
    error MinimalAccount__NotFromEntryPointOrOwner(address);
    error MinimalAccount__ExecutionFailed(bytes);
    error MinimalAccount__NotOwner();

    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    IEntryPoint private immutable _entryPoint;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    modifier requireFromEntryPoint() {
        if (msg.sender != address(_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint(msg.sender);
        }
        _;
    }

    modifier fromEntryPointOrOwner() {
        if (msg.sender != address(_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    constructor(address entryPoint) Ownable(msg.sender) {
        _entryPoint = IEntryPoint(entryPoint);
    }

    receive() external payable {}
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function execute(address target, uint256 value, bytes calldata functionData) external fromEntryPointOrOwner {
        (bool success, bytes memory result) = target.call{value: value}(functionData);
        if (!success) revert MinimalAccount__ExecutionFailed(result);
    }

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

    function getEntryPoint() external view returns (IEntryPoint) {
        return _entryPoint;
    }
}
