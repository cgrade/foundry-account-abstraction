// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {ZkMinimalAccount} from "../../src/zksync/ZkminimalAccount.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {Transaction} from "lib/foundry-era-contracts/src/system-contracts/contracts/libraries/MemoryTransactionHelper.sol";

/**
 * @title ZkMinimalAccountTest
 * @author Abraham Elijah (Mr. Grade)
 * @notice Test suite for ZkMinimalAccount contract
 * @dev Contains tests for transaction execution and validation on zkSync Era
 */
contract ZkMinimalAccountTest is Test {
    /*//////////////////////////////////////////////////////////////
                            STATE VARIABLES
    //////////////////////////////////////////////////////////////*/
    /// @dev Instance of the account contract being tested
    ZkMinimalAccount minimalAccount;
    /// @dev Mock ERC20 token for testing transactions
    ERC20Mock usdc;

    /// @dev Standard amount used in tests (1 token with 18 decimals)
    uint256 constant AMOUNT = 1e18;
    /// @dev Empty bytes32 value used for unused parameters
    bytes32 constant EMPTY_BYTES32 = bytes32(0);

    /*//////////////////////////////////////////////////////////////
                              SETUP
    //////////////////////////////////////////////////////////////*/
    
    /// @notice Setup function called before each test
    /// @dev Deploys fresh instances of ZkMinimalAccount and ERC20Mock
    function setUp() public {
        minimalAccount = new ZkMinimalAccount();
        usdc = new ERC20Mock();
    }

    /*//////////////////////////////////////////////////////////////
                              TESTS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Test that the owner can execute commands through the account
     * @dev Tests minting USDC tokens through the account
     */
    function testZkOwnerCanExecuteCommands() public {
        // Arrange
        address dest = address(usdc);
        uint256 value = 0;
        bytes memory functionData = abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT);

        Transaction memory transaction = _createUnsignedTransaction(
            minimalAccount.owner(),
            113, // zkSync Era transaction type
            dest,
            value,
            functionData
        );

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.executeTransaction(EMPTY_BYTES32, EMPTY_BYTES32, transaction);

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT);
    }

    /**
     * @notice Test transaction validation
     * @dev TODO: Implement validation tests
     */
    function testZkValidateTransaction() public {
        // TODO: Implement validation tests
    }

    /*//////////////////////////////////////////////////////////////
                                HELPERS
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Signs a transaction with the given account
     * @dev TODO: Implement transaction signing logic
     * @param transaction Transaction to sign
     * @param account Account to sign with
     */
    function _signTransaction(Transaction memory transaction, address account) internal view {
        // TODO: Implement signing logic
    }

    /**
     * @notice Creates an unsigned transaction with the given parameters
     * @dev Sets up a transaction with zkSync Era specific parameters
     * @param from Address initiating the transaction
     * @param transactionType Type of zkSync transaction (usually 113)
     * @param to Destination address
     * @param value ETH value to send
     * @param data Transaction calldata
     * @return Transaction memory Unsigned transaction struct
     */
    function _createUnsignedTransaction(
        address from,
        uint8 transactionType,
        address to,
        uint256 value,
        bytes memory data
    ) internal view returns (Transaction memory) {
        uint256 nonce = vm.getNonce(address(minimalAccount));
        bytes32[] memory factoryDeps = new bytes32[](0);

        return Transaction({
            txType: transactionType,
            from: uint256(uint160(from)),
            to: uint256(uint160(to)),
            gasLimit: 167777216,
            gasPerPubdataByteLimit: 163738383,
            maxFeePerGas: 161181919,
            maxPriorityFeePerGas: 1687798987,
            paymaster: 0,
            nonce: nonce,
            value: value,
            reserved: [uint256(0), uint256(0), uint256(0), uint256(0)],
            data: data,
            signature: hex"",
            factoryDeps: factoryDeps,
            paymasterInput: hex"",
            reservedDynamic: hex""
        });
    }
}