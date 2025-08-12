# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

ArDrive Process is a Lua-based smart contract for the AO blockchain platform implementing the ARDRIVE token system with vaulting capabilities. The project uses Lua for core logic and Node.js tooling for testing and bundling.

## Essential Commands

### Build & Development
```bash
npm run build          # Bundle Lua sources into dist/process.lua
npm run lint           # Lint Lua code with luacheck
npm run format         # Format JavaScript/TypeScript files with Prettier
npm run evolve         # Build and evolve the process
```

### Testing
```bash
npm run test:integration  # Run Node.js integration tests using AO loader
npm run test:unit        # Run Lua unit tests with Busted
npm test                 # Run all tests (unit + integration)

# Run specific integration test
npm run test:integration -- --grep "specific test name"

# Run specific Lua unit test
busted spec/specific_spec.lua
```

## Architecture Overview

### Core Process Structure
The AO process implements a handler-based architecture where incoming messages trigger specific handlers:

- **Token Operations**: Transfer, TransferWithTip, Mint, Burn handlers in `src/main.lua`
- **Balance Management**: Core logic in `src/balances.lua` handles debit/credit operations  
- **Vaulting System**: Token locking functionality in `src/vaults.lua` for time-locked deposits
- **Tips System**: Stake-weighted tip distribution in `src/tips.lua` with vault multipliers
- **Event System**: Structured logging via `src/ardrive_event.lua` and `src/ao_event.lua`
- **State Variables**: Global state (Balances, Vaults, TotalSupply, Name, Ticker) managed across handlers

### Message Flow Pattern
1. Message arrives with Action tag (e.g., "Transfer", "Create-Vault")
2. Handler validates inputs and addresses via `assertAndSanitizeInputs`
3. Core operation performed (balance update, vault creation, mint, burn)
4. Events logged for monitoring and analytics
5. Notifications sent to affected parties (Credit-Notice, Debit-Notice)

### Vaulting Architecture
- **Vault Operations**: CreateVault, VaultedTransfer, ExtendVault, IncreaseVault, RevokeVault
- **Vault State**: Tracked in global `Vaults` table indexed by owner and vault ID
- **Lock Constraints**: 14 days minimum to 200 years maximum
- **Minimum Vault Size**: 100 ARDRIVE to prevent state bloat
- **Auto-Pruning**: Expired vaults automatically unlocked on every message
- **Supply Tracking**: LastKnownLockedSupply and LastKnownCirculatingSupply for metrics

### Testing Architecture
- **Integration Tests** (`/tests/*.test.mjs`): Test bundled process using AO loader with WASM runtime
- **Unit Tests** (`/spec/*_spec.lua`): Test individual Lua modules using Busted framework
- **Test Helpers** (`/tests/helpers.mjs`): Shared utilities for loading AO process and assertions
- Tests maintain memory state across operations to simulate real AO environment

### Tips System Architecture (Transfer-With-Tip)
- **Weighted Distribution**: Tips distributed to random stakers based on vault-weighted balances
- **Vault Multipliers**: Linear scaling from 1.0x to 3.0x based on lock duration (14 days to 365+ days)
- **Random Selection**: Uses crypto module for deterministic randomness
- **Suggested Tips**: 15% of transfer amount
- **Minimum Transfer**: 100 ARDRIVE required for Transfer-With-Tip only
- **Batch Processing**: Processes up to 100 vaults per recipient for efficiency

### Key Implementation Details
- All quantities must be integers (validated via `utils.isInteger`)
- Addresses normalized via `utils.formatAddress` (lowercase for Arweave, checksummed for Ethereum)
- Critical handlers use `CRITICAL` flag to discard memory on error
- X-* message tags are forwarded in notifications for custom metadata
- Process owner has exclusive mint privileges
- Timestamps tracked via LastKnownMessageTimestamp for ordering
- Minimum vault size: 100 ARDRIVE (100 * 10^6 mARDRIVE)
- Minimum for Transfer-With-Tip: 100 ARDRIVE (regular transfers have no minimum)

### Bundle System
The `tools/bundle-aos.mjs` script combines all Lua sources into a single deployable file using `lua-bundler.mjs`. Module loading order matters - utilities and constants load first, then core logic (balances, vaults), finally main handlers.

## Development Workflow

When modifying the process:
1. Always run both unit and integration tests after changes
2. Ensure bundle builds successfully before testing
3. Check luacheck for Lua style violations
4. Integration tests simulate real AO environment - trust their results
5. Balance operations must maintain consistency (debits = credits)
6. Vault operations must validate lock periods and balance availability
7. Event logging is critical for debugging and monitoring