// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {
    IAccount,
    ACCOUNT_VALIDATION_SUCCESS_MAGIC
} from "lib/foundry-era-contracts/src/system-contracts/contracts/interfaces/IAccount.sol";
import {
    Transaction,
    MemoryTransactionHelper
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";
import {
    SystemContractsCaller,
    Utils
} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/SystemContractsCaller.sol";
import {
    NONCE_HOLDER_SYSTEM_CONTRACT,
    BOOTLOADER_FORMAL_ADDRESS,
    DEPLOYER_SYSTEM_CONTRACT
} from "lib/foundry-era-contracts/src/system-contracts/contracts/Constants.sol";
import {INonceHolder} from "lib/foundry-era-contracts/src/system-contracts/contracts/Interfaces/INonceHolder.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {Ownable} from "lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";

/**
 * @title ZkMinimalAccount
 * @author Abraham Elijah (Mr. Grade)
 * @notice A minimal implementation of a zkSync Era account abstraction contract
 * @dev Implements type 113 (0x71) transaction lifecycle:
 * 1. validateTransaction
 *     - User sends transaction to zkSync API Client
 *     - API Client verifies nonce uniqueness via NonceHolder system contract
 *     - API Client calls validateTransaction on Account contract to update nonce
 *     - API Client verifies nonce update
 *     - API Client calls payForTransaction or prepareForPaymaster & validatePaymasterTransaction
 *     - API Client verifies bootloader payment
 *
 * 2. executeTransaction
 *     - API Client calls executeTransaction on Account contract
 *     - Account contract validates and executes the transaction
 *
 * 3. executeTransactionFromOutside
 *     - External entry point for direct transaction execution
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    /*//////////////////////////////////////////////////////////////
                                 ERRORS
    //////////////////////////////////////////////////////////////*/
    /// @notice Thrown when account balance is insufficient for transaction
    error ZkMinimalAccount__NotEnoughBalance();
    /// @notice Thrown when caller is not the bootloader
    error ZkMinimalAccount__NotFromBootLoader();
    /// @notice Thrown when transaction execution fails
    error ZkMinimalAccount__ExecutionFailed();
    /// @notice Thrown when payment to bootloader fails
    error ZkMinimalAccount__FailedToPay();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Ensures the caller is the bootloader
    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
            _;
        }
    }

    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /// @notice Initializes the contract with the deployer as owner
    constructor() Ownable(msg.sender) {}

    /**
     * @notice Validates a transaction by checking signature and updating nonce
     * @dev Must increase nonce and validate owner signature
     * @param _txHash Transaction hash
     * @param _suggestedSignedHash Suggested signed hash
     * @param _transaction Transaction to validate
     * @return magic Success validation magic value
     */
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        returns (bytes4 magic)
    {
        _validateTransaction(_transaction);
    }

    /**
     * @notice Executes a validated transaction
     * @param _txHash Transaction hash (unused)
     * @param _suggestedSignedHash Suggested signed hash (unused)
     * @param _transaction Transaction to execute
     */
    function executeTransaction(
        bytes32, /* _txHash */
        bytes32, /*_suggestedSignedHash*/
        Transaction calldata _transaction
    ) external payable {
        bool success = _executeTransaction(_transaction);
        if (!success) {
            revert ZkMinimalAccount__ExecutionFailed();
        }
    }

    /**
     * @notice Allows external execution of transactions
     * @param _transaction Transaction to execute
     */
    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(_transaction);
        bool success = _executeTransaction(_transaction);
        if (!success) {
            revert ZkMinimalAccount__ExecutionFailed();
        }
    }

    /**
     * @notice Handles payment for transaction execution
     * @param _txHash Transaction hash
     * @param _suggestedSignedHash Suggested signed hash
     * @param _transaction Transaction to pay for
     */
    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    /**
     * @notice Prepares transaction for paymaster
     * @param _txHash Transaction hash
     * @param _possibleSignedHash Possible signed hash
     * @param _transaction Transaction to prepare
     */
    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Internal transaction validation logic
     * @dev Validates nonce, balance, and signature
     * @param _transaction Transaction to validate
     * @return magic Validation success magic value
     */
    function _validateTransaction(Transaction calldata _transaction) internal returns (bytes4 magic) {
        // Increment nonce in NonceHolder system contract
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Verify sufficient balance
        uint256 totalRequiredBlance = _transaction.totalRequiredBalance();
        if (totalRequiredBlance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Verify signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(convertedHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        
        return isValidSigner ? ACCOUNT_VALIDATION_SUCCESS_MAGIC : bytes4(0);
    }

    /**
     * @notice Internal transaction execution logic
     * @dev Handles both system contract and regular calls
     * @param _transaction Transaction to execute
     * @return success Whether the execution was successful
     */
    function _executeTransaction(Transaction calldata _transaction) internal returns (bool) {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;

        // Special handling for deployer system contract
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
            return true;
        } else {
            // Regular transaction execution
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            return success;
        }
    }
}
