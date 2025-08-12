# ArDrive Process Testing Guide

## Test Coverage Summary

### Unit Tests (Lua with Busted)
- **143 unit tests** across 31 test suites
- **Vaults Module**: 27 tests covering all vault operations
- **Balances Module**: 11 tests for transfers, minting, burning
- **Utils Module**: 105 tests with comprehensive edge cases
- **Main Process**: 0 tests (needs implementation)

### Integration Tests (Node.js)
- **19+ integration tests** for end-to-end functionality
- Tests run against compiled process in WASM environment
- Cover transfers, balances, minting/burning, and vault operations

## Running Unit Tests in WSL

### Setup WSL Environment

1. **Open WSL terminal** and navigate to project:
```bash
cd /mnt/c/Source/ardrive-process
```

2. **Install Lua and LuaRocks**:
```bash
# Ubuntu/Debian
sudo apt-get update
sudo apt-get install lua5.3 luarocks

# Or for newer Lua
sudo apt-get install lua5.4 luarocks
```

3. **Install Busted testing framework**:
```bash
sudo luarocks install busted
```

4. **Run unit tests**:
```bash
busted .
# Or for verbose output
busted . -v

# Run specific test file
busted spec/vaults_spec.lua
busted spec/balances_spec.lua
busted spec/utils_spec.lua
```

### Expected Unit Test Results

When all tests pass, you should see:
```
●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●●
143 successes / 0 failures / 0 errors / 0 pending : X.XXX seconds
```

## Running Integration Tests (Windows/WSL/Linux)

### On Windows (PowerShell/CMD):
```bash
npm run test:integration
```

### Current Test Status:
- ✅ **Balances**: 3/3 tests passing
- ✅ **Token Minting/Burning**: 10/10 tests passing  
- ✅ **Transfers**: 6/6 tests passing
- ⚠️ **Vaults**: 14 tests need fixes (helper function issues)

## Test Coverage Analysis

### Well-Tested Areas (80%+ coverage):
1. **Utility Functions** - Comprehensive edge case testing
2. **Balance Operations** - All core operations tested
3. **Address Validation** - Both Arweave and Ethereum formats
4. **Vault Core Logic** - All vault operations have unit tests

### Areas Needing Tests:
1. **Main Process Handlers** - No tests for message routing
2. **Event System** - ARDRIVEEvent and logging not tested
3. **Error Recovery** - Critical error handling paths
4. **Integration Scenarios** - Multi-operation workflows

## Quick Test Commands

```bash
# Run all tests (unit + integration)
npm run test:all

# Run only unit tests (requires WSL/Linux)
npm run test:unit

# Run only integration tests
npm run test:integration

# Run specific integration test
node --test --experimental-wasm-memory64 tests/balances.test.mjs

# Build and test
npm run build && npm run test:integration
```

## Fixing Vault Integration Tests

The vault integration tests need helper function updates:
1. Fix return format in `tests/helpers.mjs`
2. Ensure proper memory passing between tests
3. Add missing helper functions for vault operations

## Test-Driven Development Workflow

1. **Before making changes**: Run tests to establish baseline
2. **Write unit test first**: Add test in appropriate spec file
3. **Implement feature**: Write code to make test pass
4. **Run integration test**: Verify end-to-end functionality
5. **Build and verify**: `npm run build && npm run test:integration`

## Coverage Goals

Current coverage: ~60% of functionality
Target coverage: 80%+ for production

Priority areas for new tests:
1. Main process message handlers
2. Event logging and emission
3. Complex vault scenarios
4. Error conditions and edge cases