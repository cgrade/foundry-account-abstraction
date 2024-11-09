# Account Abstraction Project

## Overview

This project implements account abstraction using the ERC-4337 standard and zkSync Era. It includes a minimal account implementation (`MinimalAccount`) and a zkSync-specific account implementation (`ZkMinimalAccount`). The project also contains test suites to ensure the functionality and security of the contracts.

## Contracts

### 1. MinimalAccount

- **Location**: `src/ethereum/MinimalAccount.sol`
- **Description**: A minimal implementation of ERC-4337 account abstraction. It allows the owner to execute transactions and validate user operations.
- **Key Features**:
  - Owner-based access control.
  - Transaction execution with ETH transfer.
  - User operation validation.

### 2. ZkMinimalAccount

- **Location**: `src/zksync/ZkMinimalAccount.sol`
- **Description**: A minimal implementation of a zkSync Era account abstraction contract. It handles transaction validation and execution in the zkSync environment.
- **Key Features**:
  - Supports zkSync transaction lifecycle.
  - Validates transactions and updates nonce.
  - Allows external execution of transactions.

## Tests

### 1. MinimalAccountTest

- **Location**: `test/ethereum/MinimalAccountTest.t.sol`
- **Description**: Test suite for the `MinimalAccount` contract.
- **Key Tests**:
  - Owner can execute commands.
  - Non-owner cannot execute commands.
  - Validates signed user operations.

### 2. ZkMinimalAccountTest

- **Location**: `test/zksync/ZkMinimalAccountTest.sol`
- **Description**: Test suite for the `ZkMinimalAccount` contract.
- **Key Tests**:
  - Owner can execute commands.
  - Validates transaction execution.
  - Tests transaction signing and validation.

## Installation

To get started with this project, follow these steps:

1. **Clone the repository**:

   ```bash
   git clone <repository-url>
   cd <repository-directory>
   ```

2. **Install dependencies**:
   Make sure you have [Foundry](https://book.getfoundry.sh/) installed. Then run:

   ```bash
   forge install
   ```

3. **Compile the contracts**:

   ```bash
   forge build
   ```

4. **Run the tests**:
   ```bash
   forge test
   ```

## Usage

- Deploy the contracts using the provided deployment scripts located in the `script` directory.
- Interact with the contracts through the deployed addresses using a web3 provider or a frontend application.

## Contributing

Contributions are welcome! Please feel free to submit a pull request or open an issue for any suggestions or improvements.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

## Author

- **Abraham Elijah (Mr. Grade)**
