# ARDRIVE Token Process

## Overview

The ARDRIVE token is a Lua-based smart contract for the AO blockchain platform with advanced features including token vaulting, stake-weighted tipping, and comprehensive balance management.

## Process State

```lua
-- Core Token State
Name = Name or "Testnet ARDRIVE"  
Ticker = Ticker or "tARDRIVE"
Logo = Logo or "KKmRbIfrc7wiLcG0zvY1etlO0NBx1926dSCksxCIN3A"
Denomination = 6
TotalSupply = 10000000000000 -- 10 million ARDRIVE

-- Balance State
Balances = {
   [WALLET_ADDRESS] = amount_in_mARDRIVE,
}

-- Vaulting State
Vaults = {
   [OWNER_ADDRESS] = {
      [VAULT_ID] = {
         balance = amount,
         startTimestamp = timestamp,
         endTimestamp = timestamp,
         controller = optional_controller_address -- for revokable vaults
      }
   }
}

-- Supply Tracking
LastKnownLockedSupply = amount_in_vaults
LastKnownCirculatingSupply = total_supply - locked_supply
```

## Token Operations

### Basic Token Actions

#### `Info`
Get general process information
```lua
Send({ Target = PROCESS_ID, Action = "Info" })
-- Returns: Name, Ticker, Logo, Denomination, TotalSupply, etc.
```

#### `Balance`
Get balance of a specific address
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Balance",
   Address = "wallet_address" -- optional, defaults to sender
})
```

#### `Balances`
Get all token balances
```lua
Send({ Target = PROCESS_ID, Action = "Balances" })
```

#### `Paginated-Balances`
Get paginated list of balances
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Paginated-Balances",
   Cursor = "optional_cursor",
   Limit = "100",
   Sort-By = "balance", -- balance, address
   Sort-Order = "desc" -- asc, desc
})
```

#### `Total-Supply`
Get the total token supply
```lua
Send({ Target = PROCESS_ID, Action = "Total-Supply" })
```

#### `Transfer`
Transfer tokens to another address
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Transfer",
   Recipient = "recipient_address",
   Quantity = "1000000000", -- in mARDRIVE (1000 ARDRIVE)
   ["Allow-Unsafe-Addresses"] = "false" -- optional
})
```

#### `Transfer-With-Tip`
Transfer tokens with automatic tip distribution to stakers
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Transfer-With-Tip",
   Recipient = "service_provider_address",
   Quantity = "100000000", -- minimum 100 ARDRIVE required
   ["Tip-Amount"] = "15000000" -- optional, defaults to 15% of quantity
})
```
- Minimum transfer: 100 ARDRIVE
- Tips distributed to random stakers weighted by vault duration
- Vault multipliers: 1.0x (14 days) to 3.0x (365+ days)

#### `Mint`
Create new tokens (Owner only)
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Mint",
   Recipient = "recipient_address", -- optional, defaults to sender
   Quantity = "1000000000000"
})
```

#### `Burn`
Destroy tokens from your balance
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Burn",
   Quantity = "1000000000"
})
```

### Vaulting Operations

#### `Create-Vault`
Lock tokens for a specified duration
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Create-Vault",
   Quantity = "100000000", -- minimum 100 ARDRIVE
   ["Lock-Length"] = "1209600000", -- in milliseconds (14 days minimum)
   ["Vault-Id"] = "optional_custom_id" -- defaults to message ID
})
```
- Minimum vault: 100 ARDRIVE
- Lock duration: 14 days to 200 years
- Auto-unlocks after expiration

#### `Vaulted-Transfer`
Transfer tokens directly into a vault for recipient
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Vaulted-Transfer",
   Recipient = "recipient_address",
   Quantity = "100000000", -- minimum 100 ARDRIVE
   ["Lock-Length"] = "1209600000",
   Revokable = "true", -- optional, allows sender to revoke
   ["Vault-Id"] = "optional_custom_id"
})
```

#### `Extend-Vault`
Extend the lock period of an existing vault
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Extend-Vault",
   ["Vault-Id"] = "vault_id",
   ["Extend-Length"] = "1209600000" -- additional time in ms
})
```

#### `Increase-Vault`
Add more tokens to an existing vault
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Increase-Vault",
   ["Vault-Id"] = "vault_id",
   Quantity = "100000000"
})
```

#### `Revoke-Vault`
Revoke a revokable vault (controller only)
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Revoke-Vault",
   Recipient = "vault_owner_address",
   ["Vault-Id"] = "vault_id"
})
```

#### `Vault`
Get details of a specific vault
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Vault",
   Address = "owner_address",
   ["Vault-Id"] = "vault_id"
})
```

#### `Vaults`
Get all vaults for an address
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Vaults",
   Address = "owner_address" -- optional, defaults to sender
})
```

#### `Paginated-Vaults`
Get paginated list of vaults
```lua
Send({ 
   Target = PROCESS_ID, 
   Action = "Paginated-Vaults",
   Address = "owner_address", -- optional for all vaults
   Cursor = "optional_cursor",
   Limit = "100",
   ["Sort-By"] = "balance", -- balance, startTimestamp, endTimestamp, vaultId
   ["Sort-Order"] = "desc"
})
```

## Key Features

### Units and Denominations
- 1 ARDRIVE = 1,000,000 mARDRIVE (micro-ARDRIVE)
- All quantities in messages use mARDRIVE (smallest unit)
- Denomination = 6 (6 decimal places)

### Automatic Vault Pruning
- Expired vaults automatically unlock on any message
- Released tokens return to owner's liquid balance
- No manual unlock required

### Stake-Weighted Tips
- Transfer-With-Tip distributes tips to random stakers
- Vault duration increases weight (1x to 3x multiplier)
- Supports network participation incentives

### Address Validation
- Supports Arweave addresses (43 characters)
- Supports Ethereum addresses (42 characters with 0x)
- Optional unsafe address support for custom implementations

### Event Forwarding
- X-* tagged messages forwarded in notifications
- Enables custom metadata propagation
- Useful for application-specific data


## Development

### Prerequisites
- Node.js 18+
- Lua 5.3+
- Busted (Lua testing framework)

### Build & Test
```bash
# Install dependencies
npm install

# Build the bundled process
npm run build

# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests only
npm run test:integration

# Lint Lua code
npm run lint

# Format JavaScript/TypeScript
npm run format
```

### Project Structure
```
src/
├── main.lua           # Main process handlers and entry point
├── balances.lua       # Balance management logic
├── vaults.lua         # Vaulting system implementation
├── tips.lua           # Stake-weighted tip distribution
├── constants.lua      # Configuration constants
├── utils.lua          # Utility functions
├── ardrive_event.lua  # Event logging system
└── ao_event.lua       # AO event integration

tests/
├── *.test.mjs         # Integration tests (Node.js)
└── helpers.mjs        # Test utilities

spec/
└── *_spec.lua         # Unit tests (Lua/Busted)

dist/
└── process.lua        # Bundled output for deployment
```

### Deployment

#### Deploy to AO
1. Build the process: `npm run build`
2. Deploy `dist/process.lua` to AO using aos CLI or deployment tools
3. Note the process ID for interaction

#### Current Deployments
- **Testnet**: `hba1FKUY93jNhQ8qjPi0hFD88ADIj8w-Jb-UutL_6eU` (tARDRIVE)
- **Mainnet**: TBD (ARDRIVE)

## Configuration

### Constants (src/constants.lua)
- `totalTokenSupply`: 10,000,000 ARDRIVE
- `MIN_VAULT_SIZE`: 100 ARDRIVE
- `MIN_TOKEN_LOCK_TIME_MS`: 14 days
- `MAX_TOKEN_LOCK_TIME_MS`: 200 years

### Process Metadata
- `Name`: "Testnet ARDRIVE" (configurable)
- `Ticker`: "tARDRIVE" (configurable)
- `Logo`: Transaction ID of logo image
- `Denomination`: 6 (fixed)

## Security Considerations

- Only process owner can mint new tokens
- Minimum vault size prevents state bloat
- Address validation prevents accidental burns
- Revokable vaults require controller authorization
- Critical handlers discard memory on error
- All quantities validated as positive integers

## Contributing

See CLAUDE.md for detailed development guidelines and architecture documentation.

## License

[License information to be added]
