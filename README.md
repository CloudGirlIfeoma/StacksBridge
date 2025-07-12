# StacksBridge DEX

A decentralized exchange protocol built on Stacks that facilitates seamless trading between Bitcoin Layer 2 tokens and Stacks-based assets using an Automated Market Maker (AMM) model.

## Overview

StacksBridge DEX is a smart contract-based decentralized exchange that bridges the gap between Bitcoin Layer 2 ecosystems and the Stacks blockchain. It provides efficient token swapping, liquidity provision, and cross-layer asset management through a proven AMM mechanism.

## Features

### Core Trading Features
- **Automated Market Maker (AMM)**: Constant product formula (x * y = k) for efficient price discovery
- **Token Swapping**: Direct token-to-token exchanges with minimal slippage
- **Liquidity Pools**: Permissionless pool creation for any token pair
- **Fee Structure**: 0.3% trading fees distributed to liquidity providers
- **Slippage Protection**: Built-in safeguards against unfavorable price movements

### Cross-Layer Functionality
- **Layer 2 Integration**: Native support for Bitcoin Layer 2 tokens
- **Bridge Operations**: Secure cross-layer asset transfers
- **Multi-Asset Support**: Seamless trading between L2 and Stacks assets
- **Token Registry**: Comprehensive asset management system

### Advanced Features
- **Precision Handling**: 6-decimal precision for accurate calculations
- **Liquidity Mining**: LP token system for reward distribution
- **Admin Controls**: Protocol governance and fee management
- **Event Logging**: Comprehensive transaction tracking

## Smart Contract Architecture

### Core Contracts
- **Main Exchange Contract**: Primary trading and liquidity logic
- **Pool Management**: Liquidity pool creation and maintenance
- **Bridge Interface**: Cross-layer asset transfer handling
- **Token Registry**: Supported asset management

### Key Data Structures

#### Pools
```clarity
{
  reserve-a: uint,      // Token A reserves
  reserve-b: uint,      // Token B reserves  
  total-supply: uint,   // Total LP tokens
  fee-to: (optional principal) // Fee recipient
}
```

#### User Liquidity
```clarity
{
  liquidity-tokens: uint // User's LP token balance
}
```

#### Supported Tokens
```clarity
{
  name: (string-ascii 32),
  symbol: (string-ascii 8),
  decimals: uint,
  is-layer2: bool
}
```

## Installation & Setup

### Prerequisites
- Clarinet CLI installed
- Node.js 16+ 
- Stacks wallet for testnet/mainnet interaction

### Local Development Setup

## Usage Guide

### For Traders

#### Token Swapping
```clarity
;; Swap 1000 Token A for Token B with 5% slippage tolerance
(contract-call? .stacksbridge-dex swap-tokens 
  'SP1...tokenA 
  'SP2...tokenB 
  u1000000 
  u950000) ;; minimum output
```

#### Preview Swap Output
```clarity
;; Calculate expected output before swapping
(contract-call? .stacksbridge-dex calculate-swap-output 
  'SP1...tokenA 
  'SP2...tokenB 
  u1000000)
```

### For Liquidity Providers

#### Create New Pool
```clarity
;; Create a new trading pair with initial liquidity
(contract-call? .stacksbridge-dex create-pool 
  'SP1...tokenA 
  'SP2...tokenB 
  u1000000  ;; 1M Token A
  u2000000) ;; 2M Token B
```

#### Add Liquidity
```clarity
;; Add liquidity to existing pool
(contract-call? .stacksbridge-dex add-liquidity 
  'SP1...tokenA 
  'SP2...tokenB 
  u500000   ;; Token A amount
  u1000000  ;; Token B amount
  u700000)  ;; Minimum LP tokens
```

#### Remove Liquidity
```clarity
;; Remove liquidity and claim tokens
(contract-call? .stacksbridge-dex remove-liquidity 
  'SP1...tokenA 
  'SP2...tokenB 
  u500000   ;; LP tokens to burn
  u450000   ;; Min Token A out
  u900000)  ;; Min Token B out
```

### Cross-Layer Operations

#### Bridge Assets to Layer 2
```clarity
;; Bridge tokens to Bitcoin Layer 2
(contract-call? .stacksbridge-dex initiate-l2-bridge 
  'SP1...l2token 
  u1000000 
  0x1234...l2address)
```

### Administrative Functions

#### Register New Token
```clarity
;; Add support for new token (admin only)
(contract-call? .stacksbridge-dex add-supported-token 
  'SP1...newtoken 
  "New Token" 
  "NEW" 
  u8 
  true) ;; is Layer 2 token
```

#### Set Fee Recipient
```clarity
;; Configure fee collection (admin only)
(contract-call? .stacksbridge-dex set-fee-recipient 
  'SP1...tokenA 
  'SP2...tokenB 
  'SP3...feeRecipient)
```

## API Reference

### Public Functions

#### Core Trading
- `swap-tokens(token-in, token-out, amount-in, min-amount-out)` - Execute token swap
- `create-pool(token-a, token-b, amount-a, amount-b)` - Create new liquidity pool
- `add-liquidity(token-a, token-b, amount-a, amount-b, min-liquidity)` - Add pool liquidity
- `remove-liquidity(token-a, token-b, liquidity, min-amount-a, min-amount-b)` - Remove pool liquidity

#### Cross-Layer Bridge
- `initiate-l2-bridge(token, amount, l2-address)` - Bridge assets to Layer 2

#### Administrative
- `add-supported-token(token, name, symbol, decimals, is-layer2)` - Register new token
- `set-fee-recipient(token-a, token-b, recipient)` - Configure fee collection

### Read-Only Functions

#### Pool Information
- `get-pool-info(token-a, token-b)` - Retrieve pool reserves and metadata
- `get-user-liquidity(user, token-a, token-b)` - Get user's LP token balance
- `calculate-swap-output(token-in, token-out, amount-in)` - Preview swap output

#### Token Information
- `get-supported-token(token)` - Check if token is supported and get metadata

## Testing

### Unit Tests
```bash
# Run all tests
clarinet test

# Run specific test file
clarinet test tests/stacksbridge-dex_test.ts

# Run with coverage
clarinet test --coverage
```

### Integration Tests
```bash
# Start local devnet for integration testing
clarinet integrate

# Deploy contracts to devnet
clarinet deploy --devnet
```

### Test Coverage Areas
- Pool creation and management
- Token swapping mechanics
- Liquidity provision and removal
- Cross-layer bridge operations
- Access control and permissions
- Edge cases and error handling

## Security Considerations

### Smart Contract Security
- **Reentrancy Protection**: All external calls properly secured
- **Integer Overflow**: SafeMath operations throughout
- **Access Control**: Admin functions restricted to contract owner
- **Input Validation**: Comprehensive parameter checking

### Economic Security
- **Slippage Protection**: User-defined minimum output amounts
- **Fee Validation**: Reasonable fee rates with caps
- **Reserve Validation**: Pool balance integrity checks
- **Precision Handling**: Scaled arithmetic for accuracy

### Audit Recommendations
- Independent security audit before mainnet deployment
- Formal verification of critical mathematical operations
- Stress testing with large transaction volumes
- Multi-signature admin controls for production

## Gas Optimization

### Efficient Operations
- Batch operations where possible
- Optimized storage patterns
- Minimal external contract calls
- Cached calculation results

### Cost Estimates
- Pool creation: ~50,000 gas
- Token swap: ~35,000 gas
- Add liquidity: ~40,000 gas
- Remove liquidity: ~40,000 gas

## Deployment Guide

### Testnet Deployment
```bash
# Configure testnet in Clarinet.toml
clarinet deploy --testnet

# Verify deployment
clarinet call get-pool-info --testnet
```

### Mainnet Deployment
```bash
# Final security checks
npm run audit
clarinet test --coverage

# Deploy to mainnet
clarinet deploy --mainnet

# Initialize with supported tokens
clarinet call add-supported-token --mainnet
```
