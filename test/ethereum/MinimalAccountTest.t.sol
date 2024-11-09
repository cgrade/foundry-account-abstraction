// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "lib/forge-std/src/Test.sol";
import {MinimalAccount} from "../../src/ethereum/MinimalAccount.sol";
import {HelperConfig} from "../../script/HelperConfig.s.sol";
import {DeployMinimal} from "../../script/DeployMinimal.s.sol";
import {ERC20Mock} from "lib/openzeppelin-contracts/contracts/mocks/token/ERC20Mock.sol";
import {SendPackedUserOp} from "../../script/SendPackedUserOp.s.sol";
import {ECDSA} from "lib/openzeppelin-contracts/contracts/utils/cryptography/ECDSA.sol";
import {PackedUserOperation} from "lib/account-abstraction/contracts/interfaces/PackedUserOperation.sol";
import {MessageHashUtils} from "lib/openzeppelin-contracts/contracts/utils/cryptography/MessageHashUtils.sol";
import {IEntryPoint} from "lib/account-abstraction/contracts/interfaces/IEntryPoint.sol";

contract MinimalAccountTest is Test {
    using MessageHashUtils for bytes32;

    MinimalAccount public minimalAccount;
    HelperConfig public helperConfig;
    ERC20Mock public usdc;
    SendPackedUserOp public sendPackedUserOp;

    address randomUser = makeAddr("randomUser");

    uint256 public constant AMOUNT_OF_USDC = 1 ether;

    function setUp() public {
        DeployMinimal deployMinimal = new DeployMinimal();
        (minimalAccount, helperConfig) = deployMinimal.deployMinimalAccount();
        usdc = new ERC20Mock();
        sendPackedUserOp = new SendPackedUserOp();
    }

    // USDC Approval
    // msg.sener -> MinimalAccount
    // approve some amount
    // USDC contract
    // come from the entrypoint.

    function testOwnerCanExecuteCommands() public {
        // Arrange

        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT_OF_USDC);

        // Act
        vm.prank(minimalAccount.owner());
        minimalAccount.execute(target, value, functionData);
        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT_OF_USDC);
    }

    function testNonOwnerCannotExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT_OF_USDC);
        vm.prank(randomUser);
        vm.expectRevert(
            abi.encodeWithSelector(MinimalAccount.MinimalAccount__NotFromEntryPointOrOwner.selector, randomUser)
        );
        minimalAccount.execute(target, value, functionData);
    }

    function testRecoverSignedOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT_OF_USDC);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, target, value, functionData);
        PackedUserOperation memory packedUserOps =
            sendPackedUserOp.generateSignedUserOps(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);

        // Act
        address actualSigner = ECDSA.recover(userOperationHash.toEthSignedMessageHash(), packedUserOps.signature);
        // Assert
        assertEq(actualSigner, minimalAccount.owner());
    }

    // 1. Sign user ops
    // 2. call validateUserOp
    // 3. assert the result is valid
    function testValidationOfUserOp() public {
        // Arrange
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;
        uint256 missingAccountFunds = 0.1e18;
        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT_OF_USDC);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, target, value, functionData);
        PackedUserOperation memory packedUserOps =
            sendPackedUserOp.generateSignedUserOps(executeCallData, helperConfig.getConfig(), address(minimalAccount));
        bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);

        // Add more ETH to both EntryPoint and the account
        vm.deal(helperConfig.getConfig().entryPoint, 1 ether); // Increased amount
        vm.deal(address(minimalAccount), 1 ether); // Fund the account too

        // Log balances for debugging
        // console.log("EntryPoint balance:", address(helperConfig.getConfig().entryPoint).balance);
        // console.log("Account balance:", address(minimalAccount).balance);
        // console.log("Missing funds required:", missingAccountFunds);

        // Act
        vm.prank(helperConfig.getConfig().entryPoint);
        uint256 validationData = minimalAccount.validateUserOp(packedUserOps, userOperationHash, missingAccountFunds);

        // Assert
        assertEq(validationData, 0);
    }

    function testEntryPointCanExecuteCommands() public {
        assertEq(usdc.balanceOf(address(minimalAccount)), 0);
        address target = address(usdc);
        uint256 value = 0;

        bytes memory functionData =
            abi.encodeWithSelector(ERC20Mock.mint.selector, address(minimalAccount), AMOUNT_OF_USDC);
        bytes memory executeCallData =
            abi.encodeWithSelector(MinimalAccount.execute.selector, target, value, functionData);
        // bytes32 userOperationHash = IEntryPoint(helperConfig.getConfig().entryPoint).getUserOpHash(packedUserOps);

        // Increase gas limits in the UserOp
        PackedUserOperation memory packedUserOps =
            sendPackedUserOp.generateSignedUserOps(executeCallData, helperConfig.getConfig(), address(minimalAccount));

        // Add sufficient ETH to both EntryPoint and the account
        // vm.deal(helperConfig.getConfig().entryPoint, 100 ether); // Increased amount
        vm.deal(address(minimalAccount), 100 ether); // Increased amount

        PackedUserOperation[] memory ops = new PackedUserOperation[](1);
        ops[0] = packedUserOps;

        // Act
        vm.prank(randomUser);
        IEntryPoint(helperConfig.getConfig().entryPoint).handleOps(ops, payable(randomUser));

        // Assert
        assertEq(usdc.balanceOf(address(minimalAccount)), AMOUNT_OF_USDC);
    }
}
