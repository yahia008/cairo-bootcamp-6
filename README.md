# StarkNet Restricted ERC-20 Token

A secure ERC-20 token implementation on StarkNet with administrative controls, transfer restrictions, and burn functionality.


File-path yahia008/blockheader_test
File-path yahia008/assignment_1
file-path yahia008/assignment_2
File-path yahia008/av2_pro

## Overview

This contract extends standard ERC-20 behavior with admin-managed safeguards. It is designed for cases where token movement must follow configurable rules, while still supporting the usual transfer and allowance flows.

## Features

### Core ERC-20 Functionality

- Standard token operations: `transfer`, `approve`, and `transfer_from`
- Balance tracking and allowance management
- Token metadata: `name`, `symbol`, `decimals`, and `total_supply`

### Admin Controls

- Transfer limit management: the admin can update the maximum transfer amount
- Global transfer toggle: the admin can disable or re-enable all transfers
- Burn mechanism: the admin can burn tokens from any address
- Spender revocation: the admin can revoke specific spenders from using allowances

### Security Features

- Maximum transfer limit enforcement
- Zero-address validation
- Insufficient balance checks
- Allowance validation
- Revoked spender tracking
- Admin-only privileged functions

## Contract Architecture

### Interfaces

#### `IERC20`

Standard ERC-20 interface with the required functions:

- `get_name()`
- `get_symbol()`
- `get_decimals()`
- `get_total_supply()`
- `balance_of()`
- `allowance()`
- `transfer()`
- `transfer_from()`
- `approve()`
- `increase_allowance()`
- `decrease_allowance()`

#### `IAdminRestricted`

Admin-specific functions:

- `set_transfer_limit()` - Updates the maximum transfer amount
- `burn()` - Burns tokens from any account
- `revoke_transfers()` - Disables all transfers
- `enable_transfers()` - Re-enables transfers
- `admin_revoke_spender()` - Revokes a specific spender

### Storage Variables

```rust
name: felt252
symbol: felt252
decimals: u8
total_supply: u256
balances: Map<ContractAddress, u256>
allowances: Map<(ContractAddress, ContractAddress), u256>
revoked_user: Map<ContractAddress, bool>
admin: ContractAddress
transfer_limit: u256
transfers_enabled: bool
```

### Events

- `Transfer` - Emitted on token transfers
- `Approval` - Emitted on allowance changes
- `TransferLimitUpdated` - Emitted when the admin updates the transfer limit
- `TransfersRevoked` / `TransfersEnabled` - Emitted when global transfer status changes
- `Burn` - Emitted when tokens are burned

## Deployment

### Constructor Parameters

```rust
fn constructor(
    recipient: ContractAddress,
    name: felt252,
    decimals: u8,
    initial_supply: u256,
    symbol: felt252,
    admin: ContractAddress
)
```

Parameter summary:

- `recipient` - Initial token recipient
- `name` - Token name
- `decimals` - Token decimals
- `initial_supply` - Initial amount to mint
- `symbol` - Token symbol
- `admin` - Admin address

### Example Deployment

```cairo
let token = erc20::constructor(
    recipient: 0x123...,
    name: 'Restricted Token',
    decimals: 18,
    initial_supply: 1000000_u256,
    symbol: 'RST',
    admin: 0x456...
);
```

## Usage Examples

### Transfer Validation

The following transfer will fail if:

- The amount exceeds `transfer_limit`
- The sender has insufficient balance
- Global transfers are disabled
- A zero address is used

```cairo
token.transfer(recipient, 5000_u256);   // Works
token.transfer(recipient, 15000_u256);  // Fails: exceeds limit
```

### Admin Operations

```cairo
// Update transfer limit
token.set_transfer_limit(20000_u256);

// Burn tokens from any address
token.burn(account_address, 1000_u256);

// Emergency stop all transfers
token.revoke_transfers();
token.transfer(recipient, 1000_u256); // Fails: transfers disabled

// Re-enable transfers
token.enable_transfers();

// Revoke a specific spender
token.admin_revoke_spender(owner, spender);
```

## Error Codes

| Error | Description |
| --- | --- |
| `ERC20: not admin` | Caller is not the contract admin |
| `ERC20: transfers disabled` | Global transfers are currently disabled |
| `ERC20: exceeds max limit` | Transfer amount exceeds the current limit |
| `ERC20: insufficient balance` | Sender has insufficient tokens |
| `ERC20: insufficient allowance` | Insufficient allowance for `transfer_from` |
| `ERC20: spender revoked` | Spender has been revoked by the admin |
| `ERC20: limit must be >0` | Transfer limit must be positive |
| `ERC20: zero address` | Zero address is not allowed for the operation |
| `ERC20: approve to 0` | Cannot approve the zero address |
| `ERC20: burn amount >0` | Burn amount must be positive |
