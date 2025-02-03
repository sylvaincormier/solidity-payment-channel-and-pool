# Payment Channel & Liquidity Pool Smart Contracts

This project implements two smart contracts:
1. A Unidirectional Payment Channel for off-chain Ether transfers
2. A Minimal Liquidity Pool AMM (Automated Market Maker)

## 🛠 Technology Stack

- Solidity ^0.8.20
- Foundry (for testing and development)
- OpenZeppelin Contracts (for standard implementations and security)

## 📋 Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- Git

## 🚀 Quick Start

```bash
# Clone the repository
git clone <repository-url>
cd solidity-payment-channel-and-pool

# Install dependencies
forge install

# Build the project
forge build

# Run tests
forge test

# Run tests with verbosity (to see logs)
forge test -vv

# Run specific test
forge test --match-test testChannelDeployment -vv
```

## 💡 No Test Network Required

This project uses Foundry's built-in EVM for testing. You don't need to run or connect to a testnet. Foundry provides:
- Local blockchain simulation
- Account management (test addresses)
- Transaction management
- Block manipulation

## 📝 Contract Details

### Payment Channel
Located in `src/PaymentChannel.sol`

Features:
- Off-chain signature-based payments
- Channel extension mechanism
- Timeout-based refunds
- Double-spend prevention

Key Functions:
```solidity
constructor(address _receiver, uint256 _expiration) payable
function extend(uint256 newExpiration) external
function claimPayment(uint256 amount, bytes memory signature) external
function refund() external
```

### Liquidity Pool
Located in `src/LiquidityPool.sol`

Features:
- Constant product AMM (x * y = k)
- LP token rewards
- Flash loan protection
- 0.3% swap fee

Key Functions:
```solidity
function addLiquidity(uint256 amountADesired, uint256 amountBDesired) external
function removeLiquidity(uint256 liquidity) external
function swap(uint256 amountIn, bool isAtoB) external
```

## 🧪 Testing

Tests are organized in two files:
- `test/PaymentChannelTest.sol`
- `test/LiquidityPoolTest.sol`

Run specific test suites:
```bash
# Payment Channel tests
forge test --match-path test/PaymentChannelTest.sol -vv

# Liquidity Pool tests
forge test --match-path test/LiquidityPoolTest.sol -vv
```

### Test Coverage
- Payment Channel: 7 tests
  - Basic functionality
  - Channel extension
  - Payment claiming
  - Refund mechanism
  - Security checks

- Liquidity Pool: 11 tests
  - Liquidity provisioning
  - Token swaps
  - Flash loan prevention
  - K-value protection
  - Fee mechanisms

## 🔒 Security Features

### Payment Channel
- Signature verification using ecrecover
- Timeout mechanism
- Single-use claiming
- Proper access control

### Liquidity Pool
- ReentrancyGuard implementation
- Flash loan prevention
- K-value preservation
- Maximum swap limits
- Minimum liquidity requirements

## ⛽ Gas Optimization

Key metrics:
```
Payment Channel:
- Deployment: ~27k gas
- Channel Extension: ~23k gas
- Payment Claim: ~104k gas
- Refund: ~58k gas

Liquidity Pool:
- Initial Liquidity: ~240k gas
- Swap: ~298k gas
- Remove Liquidity: ~264k gas
```

## 📈 Performance Considerations

The contracts are optimized for:
- Minimal storage operations
- Efficient math calculations
- Gas-efficient function ordering
- Memory vs. storage trade-offs

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to your branch
5. Create a Pull Request

## 📄 License

MIT License

## ✨ Acknowledgments

- OpenZeppelin for secure contract implementations
- Foundry for development framework
- Uniswap V2 for AMM inspiration
