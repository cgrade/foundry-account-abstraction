// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IAccount} from "lib/account-abstraction/contracts/interfaces/IAccount.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {SIG_VALIDATION_SUCCESS, SIG_VALIDATION_FAILED} from "lib/account-abstraction/contracts/core/Helpers.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

/**
 * @title MinimalAccount
 * @author Abraham Elijah (Mr. Grade)
 * @notice A minimal implementation of ERC-4337 account abstraction
 * @dev Implements core account abstraction functionality with owner-based validation
 */
contract MinimalAccount is IAccount, Ownable {
    /*//////////////////////////////////////////////////////////////
                                CUSTOM ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when a function restricted to EntryPoint is called by another address
    error MinimalAccount__NotFromEntryPoint(address caller);
    /// @notice Thrown when a function restricted to EntryPoint or owner is called by another address
    error MinimalAccount__NotFromEntryPointOrOwner(address caller);
    /// @notice Thrown when the execution of a transaction fails
    error MinimalAccount__ExecutionFailed(bytes result);
    /// @notice Thrown when a non-owner tries to perform an owner-only action
    error MinimalAccount__NotOwner();

    /*//////////////////////////////////////////////////////////////
                                STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @notice The EntryPoint contract reference
    IEntryPoint private immutable _entryPoint;

    /*//////////////////////////////////////////////////////////////
                                MODIFIERS
    //////////////////////////////////////////////////////////////*/
    /// @notice Ensures the caller is the EntryPoint
    modifier requireFromEntryPoint() {
        if (msg.sender != address(_entryPoint)) {
            revert MinimalAccount__NotFromEntryPoint(msg.sender);
        }
        _;
    }

    /// @notice Ensures the caller is either the EntryPoint or the owner
    modifier fromEntryPointOrOwner() {
        if (msg.sender != address(_entryPoint) && msg.sender != owner()) {
            revert MinimalAccount__NotFromEntryPointOrOwner(msg.sender);
        }
        _;
    }

    /*//////////////////////////////////////////////////////////////
                             FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Contract constructor
     * @param entryPoint The address of the EntryPoint contract
     */
    constructor(address entryPoint) Ownable(msg.sender) {
        _entryPoint = IEntryPoint(entryPoint);
    }

    /// @notice Allows the contract to receive ETH
    receive() external payable {}

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Executes a transaction from the account
     * @param target The address to call
     * @param value The amount of ETH to send
     * @param functionData The calldata for the transaction
     */
    function execute(address target, uint256 value, bytes calldata functionData) external fromEntryPointOrOwner {
        (bool success, bytes memory result) = target.call{value: value}(functionData);
        if (!success) revert MinimalAccount__ExecutionFailed(result);
    }

    /**
     * @notice Validates a UserOperation
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @param missingAccountFunds The amount of funds needed for gas
     * @return validationData Packed validation data (see ERC-4337)
     */
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

    /**
     * @notice Validates the signature of a UserOperation
     * @dev Uses EIP-191 signature scheme
     * @param userOp The UserOperation to validate
     * @param userOpHash The hash of the UserOperation
     * @return validationData 0 if valid, 1 if invalid
     */
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

    /**
     * @notice Pays the required prefund to the EntryPoint
     * @param missingAccountFunds The amount of funds needed
     */
    function _payPrefund(uint256 missingAccountFunds) internal {
        if (missingAccountFunds != 0) {
            (bool success,) = msg.sender.call{value: missingAccountFunds, gas: type(uint256).max}("");
            require(success, "Failed to send ETH to the account");
        }
    }

    /*//////////////////////////////////////////////////////////////
                                GETTERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Returns the address of the EntryPoint contract
     * @return The EntryPoint contract interface
     */
    function getEntryPoint() external view returns (IEntryPoint) {
        return _entryPoint;
    }
}
