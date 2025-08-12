# ArDrive Process Deployment Guide

## Summary

Your ArDrive Process is now ready for testnet deployment with the following features implemented:
- ✅ Token transfer and balance management (based on AR.IO patterns)
- ✅ Minting and burning capabilities (owner-restricted)
- ✅ Vault system with time-locking capabilities
- ✅ Vault operations: Create, Transfer, Extend, Increase, Revoke
- ✅ Automatic vault pruning on message processing
- ✅ Comprehensive event logging and security measures
- ✅ Supply tracking (circulating vs locked)

## Files Ready for Deployment

- **Process Bundle**: `dist/process.lua` (compiled from source)
- **Source Code**: All Lua modules in `/src` directory
- **Configuration**: Token name, ticker, and supply configured in `main.lua`

## Deployment Options

### Option 1: Using AOS CLI (Recommended for Testing)

1. Install AOS CLI:
```bash
npm i -g https://get_ao.g8way.io
```

2. Start AOS and create a new process:
```bash
aos testnet-ardrive --module=GYrbbe0VbHim_7Hi6zrOpHQXrSQz07XNtwCnfbFo2I0
```

3. Load your process code:
```aos
.load dist/process.lua
```

4. Test basic operations:
```aos
Send({ Target = ao.id, Action = "Info" })
Send({ Target = ao.id, Action = "Balance", Address = ao.id })
```

### Option 2: Direct Deployment with aoconnect

1. Create a deployment script `deploy.mjs`:
```javascript
import { readFileSync } from 'fs';
import { connect } from '@permaweb/aoconnect';
import { createDataItemSigner } from '@permaweb/aoconnect/node';

const wallet = JSON.parse(readFileSync('./wallet.json', 'utf-8'));
const signer = createDataItemSigner(wallet);
const ao = connect();

// Deploy new process
const processId = await ao.spawn({
  module: 'GYrbbe0VbHim_7Hi6zrOpHQXrSQz07XNtwCnfbFo2I0', // AOS module
  scheduler: '_GQ33BkPtZrqxA84vM8Zk-N2aO0toNNu_C-l-rawrBA', // Default scheduler
  signer,
  tags: [
    { name: 'App-Name', value: 'ArDrive-Process' },
    { name: 'Version', value: '1.0.0' },
    { name: 'Network', value: 'Testnet' }
  ],
  data: readFileSync('./dist/process.lua', 'utf-8')
});

console.log('Process deployed:', processId);
```

2. Run deployment:
```bash
node deploy.mjs
```

### Option 3: Using AR.IO SDK (For Production)

Use the existing `evolve.mjs` as a template to create a deployment script that:
1. Creates a new process instead of evolving
2. Sets initial token distribution
3. Configures process metadata

## Environment Variables Needed

Create a `.env` file with:
```
WALLET=<your-arweave-wallet-json>
AO_CU_URL=https://cu.ao-testnet.xyz
NETWORK=testnet
```

## Testing After Deployment

### Basic Token Operations
```lua
-- Check info
Send({ Target = "<process-id>", Action = "Info" })

-- Check balance
Send({ Target = "<process-id>", Action = "Balance" })

-- Transfer tokens
Send({ 
  Target = "<process-id>", 
  Action = "Transfer",
  Recipient = "<recipient-address>",
  Quantity = "1000000"
})
```

### Vault Operations
```lua
-- Create vault
Send({ 
  Target = "<process-id>", 
  Action = "Create-Vault",
  Quantity = "1000000",
  Lock-Length = "1209600000", -- 14 days in ms
  Vault-Id = "test-vault-1"
})

-- Check vault
Send({ 
  Target = "<process-id>", 
  Action = "Vault",
  Address = ao.id,
  Vault-Id = "test-vault-1"
})
```

## Next Steps

1. **Deploy to Testnet**: Use one of the options above to deploy your process
2. **Record Process ID**: Save the generated process ID for future reference
3. **Initial Testing**: Run basic operations to verify deployment
4. **Integration Testing**: Test vault operations and pruning
5. **Monitor Events**: Check process logs for event emissions

## Configuration for Different Networks

For different deployments, update in `src/main.lua`:
- **Testnet**: Name = "Testnet ARDRIVE", Ticker = "tARDRIVE"
- **Development**: Name = "Dev ARDRIVE", Ticker = "dARDRIVE"  
- **Production**: Name = "ArDrive", Ticker = "ARDRIVE"

## Important Notes

- The process owner (deployer wallet) receives the initial token supply
- Minting is restricted to the process owner
- Vault minimum lock time: 14 days
- Vault maximum lock time: 200 years
- All quantities must be integers (no decimals)

## Support

For issues or questions:
- Check the test files in `/tests` for usage examples
- Review the AR.IO Network process for reference patterns
- Ensure wallet has sufficient AR for deployment fees