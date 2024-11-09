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
 * --------Lifecycle of a type 113 (0x71) transaction:--------------
 * 1. validateTransaction
 *     - the user sends the transaction to the "zkSync" API Client
 *     - the zkSync API Client checks to see the nonce is unique querying the NonceHolder system contract
 *     - the zkSync API client calls "validateTransaction" on the Account contract which must update the nonce.
 *     - The zkSync API client checks the nonce is updated.
 *     - The zkSync API client calls "payForTransaction, or prepareForPaymaster & validatePaymasterTransaction" on the Account contract.
 *     - the zkSync API client verifies that the bootloader gets paid.
 *
 * 2. executeTransaction
 *     - the zkSync API client calls "executeTransaction" on the Account contract.
 *     - the Account contract verifies the transaction is valid and then calls the callee.
 * 3. executeTransactionFromOutside
 */
contract ZkMinimalAccount is IAccount, Ownable {
    using MemoryTransactionHelper for Transaction;

    /*//////////////////////////////////////////////////////////////
                                 ERROR
    //////////////////////////////////////////////////////////////*/
    error ZkMinimalAccount__NotEnoughBalance();
    error ZkMinimalAccount__NotFromBootLoader();
    error ZkMinimalAccount__ExecutionFailed();
    error ZkMinimalAccount__FailedToPay();

    /*//////////////////////////////////////////////////////////////
                               MODIFIERS
    //////////////////////////////////////////////////////////////*/

    modifier requireFromBootloader() {
        if (msg.sender != BOOTLOADER_FORMAL_ADDRESS) {
            revert ZkMinimalAccount__NotFromBootLoader();
            _;
        }
    }
    /*//////////////////////////////////////////////////////////////
                           EXTERNAL FUNCTION
    //////////////////////////////////////////////////////////////*/

    constructor() Ownable(msg.sender) {}

    /**
     * @notice Must Increase the nonce.
     * @notice Must validate the transaction (check the owner signed the transaction)
     * @notice Also checkes to see if we have enough money in our account.
     * @param _txHash The hash of the transaction.
     * @param _suggestedSignedHash The suggested signed hash of the transaction.
     * @param _transaction The transaction to validate.
     * @return magic The magic value indicating the success of the transaction validation.
     */
    function validateTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
        returns (bytes4 magic)
    {
        _validateTransaction(_transaction);
    }

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

    function executeTransactionFromOutside(Transaction calldata _transaction) external payable {
        _validateTransaction(_transaction);
        bool success = _executeTransaction(_transaction);
        if (!success) {
            revert ZkMinimalAccount__ExecutionFailed();
        }
    }

    function payForTransaction(bytes32 _txHash, bytes32 _suggestedSignedHash, Transaction calldata _transaction)
        external
        payable
    {
        bool success = _transaction.payToTheBootloader();
        if (!success) {
            revert ZkMinimalAccount__FailedToPay();
        }
    }

    function prepareForPaymaster(bytes32 _txHash, bytes32 _possibleSignedHash, Transaction calldata _transaction)
        external
        payable
    {}

    /*//////////////////////////////////////////////////////////////
                           INTERNAL FUNCTIONS
    //////////////////////////////////////////////////////////////*/

    function _validateTransaction(Transaction calldata _transaction) internal returns (bytes4 magic) {
        // call nonceHolder
        // increment nonce
        // call(x, y, z) -> system contract call
        SystemContractsCaller.systemCallWithPropagatedRevert(
            uint32(gasleft()),
            address(NONCE_HOLDER_SYSTEM_CONTRACT),
            0,
            abi.encodeCall(INonceHolder.incrementMinNonceIfEquals, (_transaction.nonce))
        );

        // Check for Fee to Pay
        uint256 totalRequiredBlance = _transaction.totalRequiredBalance();
        if (totalRequiredBlance > address(this).balance) {
            revert ZkMinimalAccount__NotEnoughBalance();
        }

        // Check  the signature
        bytes32 txHash = _transaction.encodeHash();
        bytes32 convertedHash = MessageHashUtils.toEthSignedMessageHash(txHash);
        address signer = ECDSA.recover(convertedHash, _transaction.signature);
        bool isValidSigner = signer == owner();
        if (isValidSigner) {
            magic = ACCOUNT_VALIDATION_SUCCESS_MAGIC;
        } else {
            magic = bytes4(0);
        }
        return magic;
    }

    function _executeTransaction(Transaction calldata _transaction) internal returns (bool) {
        address to = address(uint160(_transaction.to));
        uint128 value = Utils.safeCastToU128(_transaction.value);
        bytes memory data = _transaction.data;
        if (to == address(DEPLOYER_SYSTEM_CONTRACT)) {
            uint32 gas = Utils.safeCastToU32(gasleft());
            SystemContractsCaller.systemCallWithPropagatedRevert(gas, to, value, data);
            return true;
        } else {
            bool success;
            assembly {
                success := call(gas(), to, value, add(data, 0x20), mload(data), 0, 0)
            }
            return success;
        }
    }
}
