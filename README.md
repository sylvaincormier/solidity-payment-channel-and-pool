# Payment Channel & Liquidity Pool Smart Contracts

Implementation of a Unidirectional Payment Channel and Minimal Liquidity Pool AMM.

## Technology Stack
- Solidity ^0.8.20
- Foundry
- OpenZeppelin Contracts

## Installation
```bash
git clone <repository-url>
cd solidity-payment-channel-and-pool

# Dependencies
forge install OpenZeppelin/openzeppelin-contracts@v4.9.0 --no-commit
forge install foundry-rs/forge-std

# Remappings
echo 'openzeppelin-contracts/=lib/openzeppelin-contracts/contracts/' > remappings.txt

# Build & Test
forge build
forge test -vv
```

## Project Structure
```
src/
├─ LiquidityPool.sol    # AMM implementation
├─ PaymentChannel.sol   # Payment channel implementation
├─ LPToken.sol         # Liquidity token
├─ TestTokens.sol      # Test ERC20 tokens
test/
├─ LiquidityPoolTest.sol
└─ PaymentChannelTest.sol
```

## Core Features

### Payment Channel
- Off-chain signature-based payments
- Channel extension
- Timeout-based refunds
- Double-spend prevention

Functions:
```solidity
constructor(address _receiver, uint256 _expiration) payable
function extend(uint256 newExpiration) external
function claimPayment(uint256 amount, bytes memory signature) external
function refund() external
```

### Liquidity Pool
- Constant product AMM (x * y = k)
- LP token rewards
- Flash loan protection
- 0.3% swap fee

Functions:
```solidity
function addLiquidity(uint256 amountADesired, uint256 amountBDesired) external
function removeLiquidity(uint256 liquidity) external
function swap(uint256 amountIn, bool isAtoB) external
```

## Testing
```bash
# All tests
forge test -vv

# Specific suites
forge test --match-path test/PaymentChannelTest.sol -vv
forge test --match-path test/LiquidityPoolTest.sol -vv
```

### Coverage
- Payment Channel: 7 tests
- Liquidity Pool: 11 tests

## Gas Metrics
```
Payment Channel:
- Deployment: ~27k
- Extension: ~23k
- Claim: ~104k
- Refund: ~58k

Liquidity Pool:
- Initial Liquidity: ~221k
- Swap: ~299k
- Remove Liquidity: ~265k
```

## License
MIT