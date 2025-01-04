# $ARDRIVE Process

Process State
```lua
Balances = {
   [WALLET_ADDRESS] = 10000000000000,
}
Denomination = 6
TotalSupply = TotalSupply or 10000000000000
Name = Name or 'ArDrive'
Ticker = Ticker or 'ARDRIVE'
Logo = Logo or 'KKmRbIfrc7wiLcG0zvY1etlO0NBx1926dSCksxCIN3A'
```

Handlers
`info` - read handler to get general process info like Name, Ticker and Logo

`balance` - read handler to get balance of a user

`balances` - read handler to get all balances

`paginatedBalances` - read handler to get all balances

`totalSupply` - read handler to get all balances

`transfer` - transfer tokens

`mint` - create new tokens, only by process or owner

`burn` - burn existing tokens


## TODOs

- [X] Setup initial Lua process files and unit tests
  - Create basic file structure
  - Add initial test files
  - Configure test runner

- [X] Setup initial test scaffolding 
  - Create test helpers and utilities
  - Add integration test framework
  - Setup mocking capabilities

- [ ] Setup GitHub for CD
  - Configure deployment pipeline
  - Add deployment environments
  - Setup release automation

- [ ] Setup GitHub for CI
  - Add GitHub Actions workflow
  - Configure test runners
  - Setup code quality checks
  - Add coverage reporting

- [ ] Use latest module binary for tests
  - Download latest stable release
  - Configure test environment to use correct version
  - Add version check to CI

- [ ] Ensure memory tags set to largest possible when spawning
  - Research memory tag limits
  - Implement memory optimization
  - Add memory monitoring

- [ ] Create process ID with team wallet
  - Setup secure wallet configuration
  - Generate unique process IDs for dARDRIVE, tARDRIVE and ARDRIVE
  - Link ID to team wallet
